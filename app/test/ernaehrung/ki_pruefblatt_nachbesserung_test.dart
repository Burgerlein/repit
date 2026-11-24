import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Nachbesserungen am **Prüfblatt der Foto-Schätzung** nach Tims Befunden
/// auf dem iPhone (04.11.2026). Geprüft an der ganzen App auf einem
/// Telefon (393 × 852 Punkte) wie `ki_pruefblatt_aufbau_test.dart`:
/// (+) → Kamera → „KI" → Auslöser → Prüfblatt. Gemini ist ein
/// `MockClient`; alle Schlüssel, Lebensmittel und Zahlen sind **erfunden**.
///
/// ## #353 — das Foto im Format der Aufnahme
///
/// Das Foto stand breit beschnitten in einer festen Höhe. Es behält jetzt
/// das **Seitenverhältnis der übergebenen Bilddaten**: volle Breite, Höhe
/// aus dem Verhältnis, ganz zu sehen. Ein Hochkantfoto bleibt hochkant.
///
/// Gemessen wird am `Image` im Prüfblatt — welches Widget das Verhältnis
/// herstellt (`AspectRatio`, eine aus dem Bildkopf gerechnete Höhe, die
/// Eigengröße des Bildes), schreibt der Test nicht vor. Bevor gemessen
/// wird, dekodiert der Test das Bild wirklich (`precacheImage` in
/// `runAsync`), damit auch eine Lösung, die erst nach dem Dekodieren
/// misst, ihre Größe hat. Und: Die Form steht schon, **während** geschätzt
/// wird — kommt der Vorschlag, springt das Bild nicht.
///
/// ## #354 — kein leerer Hinweiskasten
///
/// Unter „Zeile hinzufügen" stand ein leerer gelber Kasten. **Ursache:**
/// Der Kasten unter der Vorschlagskarte trägt die Notiz der KI (`note` der
/// Antwort, Entwurf `erfassen.js`, Zustand `foto-ergebnis`: „Der Kasten
/// trägt die Notiz der KI zu dem, was ihr unsicher war"). Gemini schickt
/// `"note": ""`, wenn es nichts anzumerken gibt; das Prüfblatt zeigte den
/// Kasten bei jeder Notiz, die nicht `null` war — also auch leer.
///
/// **Festlegung dieses Agenten, nicht von Tim:** Eine leere oder nur aus
/// Leerraum bestehende Notiz ist **keine Notiz**. Der Kasten fällt dann
/// ganz weg, genau wie bei fehlender `note` — er bekommt keinen Ersatztext.
/// Begründung:
///
/// - Der Kasten ist kein fester Teil der Form, sondern Inhalt der Antwort.
///   Der Entwurf zeichnet den Vorschlag einmal mit Notiz (`foto-ergebnis`)
///   und mit eigenem Text nach dem Ändern (`foto-geaendert`); fehlt die
///   Notiz, stand schon vor #354 kein Kasten da.
/// - Ein stehender Ersatztext („Die KI hat nichts angemerkt") legte der KI
///   eine Aussage in den Mund, die sie nicht gemacht hat.
/// - **Es springt nichts:** Ob der Kasten steht, entscheidet die Antwort,
///   und sie kommt zusammen mit der Liste, deren Höhe ohnehin mit der Zahl
///   der Posten wächst (#349: der Vorschlag trägt keine Mindesthöhe).
///   Innerhalb eines Vorschlags wechselt er nicht. Eine leere Notiz sieht
///   deshalb **genau** aus wie eine fehlende — gleicher Abstand zwischen
///   „Zeile hinzufügen" und dem Hinweisfeld.
///
/// ## #355 — Hinweise gibt es erst im Prüfblatt
///
/// Ohne das Blatt „Noch etwas dazu?" ist „Hinweis an die KI" im Prüfblatt
/// der **einzige** Weg, der KI etwas mitzugeben. Die erste Anfrage geht
/// ohne Hinweis; „Neu berechnen" schickt mit, was im Feld steht.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const schluessel = 'erfunden-schluessel-nach';

  Map<String, Object?> posten(String name, int gramm, int kcal) => {
    'name': name,
    'grams': gramm,
    'kcal': kcal,
    'proteinG': kcal / 16,
    'carbsG': kcal / 16,
    'fatG': kcal / 36,
    'confident': true,
  };

  final zweiPosten = [
    posten('Erfundenes A', 140, 231),
    posten('Erfundenes B', 180, 234),
  ];

  /// Eine 200-Antwort von `generateContent`. [mitNotiz] `false` lässt
  /// `note` ganz weg; sonst steht [notiz] darin, auch `null`.
  http.Response antwort(
    List<Map<String, Object?>> liste, {
    Object? notiz,
    bool mitNotiz = true,
  }) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'isFood': true,
                  'title': 'Erfundener Teller',
                  'items': liste,
                  if (mitNotiz) 'note': notiz,
                }),
              },
            ],
          },
        },
      ],
      'usageMetadata': {
        'promptTokenCount': 100,
        'candidatesTokenCount': 20,
        'thoughtsTokenCount': 0,
      },
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );

  /// Ein echtes JPEG in [breite] × [hoehe] — erfundener Inhalt, eine Farbe.
  List<int> jpeg(int breite, int hoehe) => img.encodeJpg(
    img.Image(width: breite, height: hoehe)..clear(img.ColorRgb8(90, 110, 70)),
  );

  /// Öffnet das Prüfblatt. Die Antworten auf `generateContent` kommen der
  /// Reihe nach aus [antworten]; die Anfragen landen in der Rückgabe.
  Future<List<http.Request>> oeffnePruefblatt(
    WidgetTester tester, {
    required List<Future<http.Response> Function()> antworten,
    List<int>? bild,
  }) async {
    // Ein Telefon: 393 × 852 Punkte.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final speicher = AttrappenSchluesselSpeicher();
    await speicher.schreibe(schluessel);
    final foto = TestFotoKamera();
    if (bild != null) foto.bild = bild;
    final anfragen = <http.Request>[];
    final gemini = MockClient((anfrage) async {
      if (anfrage.method == 'GET') {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.6-flash',
                'displayName': 'gemini-3.6-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      anfragen.add(anfrage);
      if (antworten.isEmpty) {
        fail('unerwartete Anfrage an Gemini: ${anfrage.url.path}');
      }
      return antworten.removeAt(0)();
    });
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(
          OffClient(
            client: MockClient((a) async => fail('kein OFF erwartet: $a')),
          ),
        ),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        fotoKameraProvider.overrideWithValue(foto),
        kiSchluesselProvider.overrideWithValue(speicher),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: RootView(router: AppRouter())),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in ['erfassen-knopf', 'kamera-modus-ki', 'ki-ausloeser']) {
      await tester.tap(find.byKey(Key(key)));
      await ruhe(tester);
    }
    expect(
      find.byKey(const Key('ki-hinweis-blatt')),
      findsNothing,
      reason: '#355: kein Hinweisblatt zwischen Auslöser und Schätzung',
    );
    expect(find.byKey(const Key('ki-pruefblatt')), findsOneWidget);
    return anfragen;
  }

  // ═════════════════════════════════════════════════════════════════════
  group('#353 — das Foto im Format der Aufnahme', () {
    Finder bildIm() => find.descendant(
      of: find.byKey(const Key('ki-pruefblatt')),
      matching: find.byType(Image),
    );

    /// Dekodiert jedes Bild im Prüfblatt wirklich und lässt danach Bilder
    /// laufen — eine Lösung, die erst nach dem Dekodieren misst, hat dann
    /// ihre Größe.
    Future<void> dekodiere(WidgetTester tester) async {
      expect(bildIm(), findsWidgets, reason: 'das Foto steht im Prüfblatt');
      await tester.runAsync(() async {
        for (final element in bildIm().evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await ruhe(tester);
    }

    /// Die volle Breite des Inhalts — so breit wie der Schätzungshinweis,
    /// der in jedem Zustand unter dem Bild steht.
    double volleBreite(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('ki-pruef-schaetzung'))).width;

    for (final (name, breite, hoehe) in const [
      ('Hochkant (3 : 4)', 600, 800),
      ('Quer (4 : 3)', 800, 600),
      ('Hochkant (9 : 16)', 576, 1024),
    ]) {
      testWidgets('$name: volle Breite, Höhe aus dem Seitenverhältnis — und '
          'die Form steht schon, während geschätzt wird', (tester) async {
        final halt = Completer<http.Response>();
        await oeffnePruefblatt(
          tester,
          antworten: [() => halt.future],
          bild: jpeg(breite, hoehe),
        );
        await dekodiere(tester);

        final waehrend = tester.getRect(bildIm().first);
        expect(
          waehrend.width,
          moreOrLessEquals(volleBreite(tester), epsilon: 1),
          reason: 'das Foto nimmt die volle Breite ein',
        );
        expect(
          waehrend.height / waehrend.width,
          moreOrLessEquals(hoehe / breite, epsilon: 0.01),
          reason:
              'Seitenverhältnis der Aufnahme $breite × $hoehe, gezeigt '
              '${waehrend.width.toStringAsFixed(1)} × '
              '${waehrend.height.toStringAsFixed(1)} — nicht beschnitten',
        );

        halt.complete(antwort(zweiPosten));
        await ruhe(tester);
        expect(find.byKey(const Key('ki-pruef-zeile-0')), findsOneWidget);
        expect(
          tester.getRect(bildIm().first),
          waehrend,
          reason: 'kommt der Vorschlag, springt das Bild nicht',
        );
      });
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  group('#354 — kein Hinweiskasten ohne Text', () {
    /// Der Abstand zwischen „Zeile hinzufügen" und dem Hinweisfeld.
    double luecke(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('ki-pruef-hinweis'))).top -
        tester.getRect(find.byKey(const Key('ki-pruef-zeile-dazu'))).bottom;

    Future<double> lueckeMit(
      WidgetTester tester,
      http.Response Function() erzeuge,
    ) async {
      await oeffnePruefblatt(tester, antworten: [() async => erzeuge()]);
      expect(find.byKey(const Key('ki-pruef-zeile-0')), findsOneWidget);
      return luecke(tester);
    }

    testWidgets('ohne `note`: kein Kasten unter „Zeile hinzufügen"', (
      tester,
    ) async {
      final ohne = await lueckeMit(
        tester,
        () => antwort(zweiPosten, mitNotiz: false),
      );
      expect(
        ohne,
        lessThanOrEqualTo(24),
        reason: 'Kartenrand und 10 Punkte Abstand, kein Kasten dazwischen',
      );
    });

    for (final (name, notiz) in const [
      ('leere `note` ("")', ''),
      ('`note` nur aus Leerraum', '  \n '),
      ('`note: null`', null),
    ]) {
      testWidgets('$name: kein Kasten — derselbe Abstand wie ohne `note`', (
        tester,
      ) async {
        final mit = await lueckeMit(
          tester,
          () => antwort(zweiPosten, notiz: notiz),
        );
        expect(
          mit,
          lessThanOrEqualTo(24),
          reason:
              'zwischen „Zeile hinzufügen" und dem Hinweisfeld stehen '
              '${mit.toStringAsFixed(0)} Punkte — dort steht ein Kasten '
              'ohne Text',
        );
      });
    }

    testWidgets('mit Text steht die Notiz der KI zwischen Karte und '
        'Hinweisfeld (Gegenprobe)', (tester) async {
      const notiz = 'Erfundene Notiz: Soße schlecht zu erkennen.';
      final mit = await lueckeMit(
        tester,
        () => antwort(zweiPosten, notiz: notiz),
      );
      final text = find.textContaining(notiz);
      expect(text, findsOneWidget);
      final wo = tester.getRect(text);
      expect(
        wo.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('ki-pruef-zeile-dazu'))).bottom,
        ),
      );
      expect(
        wo.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('ki-pruef-hinweis'))).top,
        ),
      );
      expect(mit, greaterThan(24), reason: 'der Kasten nimmt Platz ein');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('#355 — der Hinweis an die KI kommt aus dem Prüfblatt', () {
    testWidgets('die erste Anfrage geht ohne Hinweis; „Neu berechnen" '
        'schickt mit, was im Feld steht', (tester) async {
      const hinweis = 'erfunden: halbe Portion';
      final anfragen = await oeffnePruefblatt(
        tester,
        antworten: [
          () async => antwort(zweiPosten),
          () async => antwort(zweiPosten),
        ],
      );
      expect(anfragen, hasLength(1));
      expect(
        anfragen.single.body,
        isNot(contains(hinweis)),
        reason: 'vor dem Prüfblatt gibt es keinen Ort für einen Hinweis',
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('ki-pruef-hinweis')),
          matching: find.byType(EditableText),
        ),
        hinweis,
      );
      await tester.pump();
      // Seit Makros und Summe im Blatt stehen, liegt der Knopf auf dem
      // Testschirm unter der Tab-Leiste — erst hinscrollen, dann tippen.
      await tester.ensureVisible(
        find.byKey(const Key('ki-pruef-neu-berechnen')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ki-pruef-neu-berechnen')));
      await ruhe(tester);

      expect(anfragen, hasLength(2));
      expect(anfragen[1].body, contains(hinweis));
    });
  });
}

/// Lässt Zeit vergehen, ohne auf Ruhe zu warten — ein drehender Indikator
/// ließe `pumpAndSettle` sonst ins Zeitlimit laufen.
Future<void> ruhe(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _StilleQuelle extends HealthReadingAttrappe {}
