import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/ki/ki_zugang_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

import '../health/health_reading_attrappe.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für das **Prüfblatt der Foto-Schätzung** (#341) — Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 10; Spec
/// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Foto-Schätzung
/// als erste Aktion", Schritte 4–7, und „Verbrauch und Limit"; Entwurf
/// `docs/screens/screens/erfassen.js`, Zustände `foto-schaetzt`,
/// `foto-ergebnis`, `foto-geaendert`, `foto-unbrauchbar`, `foto-fehler`,
/// `foto-schluessel`, `foto-kontingent`, und `mahlzeit.js`, Zustand
/// `ki-eintraege`.
///
/// Geprüft an der **ganzen** App (`RootView`), wie `ki_sucher_test.dart`:
/// (+) → Kamera → „KI" → Auslöser → Prüfblatt (seit #355 ohne das
/// Hinweisblatt „Noch etwas dazu?" dazwischen). Gemini ist ein
/// `MockClient`; kein Test geht ins Netz, keiner trägt einen echten
/// Schlüssel.
///
/// **Rollen** (Plan, „Global Constraints"): Widget-Test — ein Agent, der
/// Test entsteht zuerst, wird rot gesehen und **vor der Implementierung
/// committet**. Danach darf diese Datei ausgeführt, aber nicht verändert
/// werden (`.githooks/pre-commit`).
///
/// ## Die Naht — Festlegung des Agenten von #341, **nicht von Tim**
///
/// `kiSchaetzungStartenProvider` (`ki_sucher.dart`) wird hier **nicht**
/// ersetzt: Seine echte Fassung öffnet das Prüfblatt. Der Zustand liegt in
/// `lib/ernaehrung/ki_schaetzung_provider.dart` (`SchaetzungZustand`:
/// `Laeuft`, `Vorschlag`, `NichtsErkannt`, `Gescheitert`); dieser Test
/// prüft ihn nur über das, was auf dem Schirm steht, über die Datenbank
/// und über `kiFotoProvider`.
///
/// ## Die Schlüssel
///
/// - `Key('ki-pruefblatt')` — das Prüfblatt, in jedem Zustand
/// - `Key('ki-pruef-schaetzung')` — „Schätzung, keine exakten Werte …",
///   in jedem Zustand
/// - `Key('ki-pruef-grund')` — der Grund in der Ergebnisfläche (nichts
///   erkannt, Fehler); **nie** während die Schätzung läuft
/// - `Key('ki-pruef-zeile-<i>')` — die i-te Zeile des Vorschlags, ab 0, in
///   der Reihenfolge der Antwort
/// - `Key('ki-pruef-buchen')` — ein `CupertinoButton`, „N Einträge
///   buchen"; ohne Wirkung (`onPressed == null`), solange nichts zu buchen
///   ist
/// - `Key('ki-pruef-abbrechen')` — „Abbrechen", während die Schätzung läuft
/// - `Key('ki-pruef-neu-berechnen')` — „Neu berechnen"
/// - `Key('ki-pruef-nochmal')` — „Nochmal versuchen"
/// - `Key('ki-pruef-suchen')` — „Stattdessen suchen"
/// - `Key('ki-pruef-zugang')` — „Zum KI-Zugang"
/// - `Key('ki-pruef-neues-foto')` — „Neues Foto"
/// - Zeile antippen → Aktionsblatt mit „Menge ändern", „Lebensmittel
///   austauschen", „Streichen"; „Menge ändern" → Dialog mit
///   `Key('ki-pruef-menge-feld')` und `Key('ki-pruef-menge-ok')`
///
/// Alle Schlüssel, Lebensmittel und Zahlen hier sind **erfunden**.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2) — Mittagessen.
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  // Erfunden, ohne das Präfix echter Schlüssel.
  const schluessel = 'erfunden-schluessel-wxyz';

  /// Ein Teller: drei sichere Posten und eine Soße ohne Menge.
  const teller = {
    'isFood': true,
    'title': 'Hähnchen mit Reis und Brokkoli',
    'items': [
      {
        'name': 'Hähnchenbrust, gegrillt',
        'grams': 140,
        'kcal': 231,
        'proteinG': 43.4,
        'carbsG': 0,
        'fatG': 5.0,
        'confident': true,
      },
      {
        'name': 'Reis, gekocht',
        'grams': 180,
        'kcal': 234,
        'proteinG': 4.9,
        'carbsG': 51,
        'fatG': 0.5,
        'confident': true,
      },
      {
        'name': 'Brokkoli',
        'grams': 120,
        'kcal': 41,
        'proteinG': 3.4,
        'carbsG': 4.3,
        'fatG': 0.5,
        'confident': true,
      },
      {
        'name': 'Soße',
        'grams': null,
        'kcal': null,
        'proteinG': null,
        'carbsG': null,
        'fatG': null,
        'confident': false,
      },
    ],
    'note': 'Soße: Fett auf dem Bild kaum erkennbar',
  };

  /// Eine 200-Antwort von `generateContent` mit [inhalt] als Text.
  http.Response antwort(Object inhalt, {bool alsJson = true}) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': alsJson ? jsonEncode(inhalt) : inhalt},
            ],
          },
        },
      ],
      'usageMetadata': {
        'promptTokenCount': 1200,
        'candidatesTokenCount': 300,
        'thoughtsTokenCount': 40,
      },
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );

  ({
    ProviderContainer container,
    AppCache db,
    AppRouter router,
    TestFotoKamera foto,
    List<http.Request> anfragen,
    List<Future<http.Response> Function()> antworten,
  })
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final foto = TestFotoKamera();
    final speicher = AttrappenSchluesselSpeicher();
    final anfragen = <http.Request>[];
    final antworten = <Future<http.Response> Function()>[];

    final gemini = MockClient((anfrage) async {
      // Der Nachlauf des KI-Zugangs: die Modellliste.
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
    final off = MockClient((anfrage) async {
      fail('unerwartete Anfrage an Open Food Facts: ${anfrage.url}');
    });

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: off)),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        fotoKameraProvider.overrideWithValue(foto),
        kiSchluesselProvider.overrideWithValue(speicher),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
      ],
    );
    addTearDown(container.dispose);
    // Der Schlüssel liegt, bevor die App startet.
    unawaited(speicher.schreibe(schluessel));
    return (
      container: container,
      db: db,
      router: AppRouter(),
      foto: foto,
      anfragen: anfragen,
      antworten: antworten,
    );
  }

  Future<void> starte(
    WidgetTester tester,
    ({
      ProviderContainer container,
      AppCache db,
      AppRouter router,
      TestFotoKamera foto,
      List<http.Request> anfragen,
      List<Future<http.Response> Function()> antworten,
    })
    h,
  ) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: h.container,
        child: CupertinoApp(home: RootView(router: h.router)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lässt Zeit vergehen, ohne auf Ruhe zu warten — ein drehender
  /// Indikator ließe `pumpAndSettle` sonst ins Zeitlimit laufen.
  Future<void> ruhe(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await ruhe(tester);
  }

  /// (+) → Kamera → „KI" → Auslöser — bis das Prüfblatt steht. Seit #355
  /// geht das Foto ohne Hinweisblatt direkt in die Schätzung.
  Future<void> schaetze(WidgetTester tester) async {
    await tippe(tester, find.byKey(const Key('erfassen-knopf')));
    await tippe(tester, find.byKey(const Key('kamera-modus-ki')));
    await tippe(tester, find.byKey(const Key('ki-ausloeser')));
    expect(find.byKey(const Key('ki-hinweis-blatt')), findsNothing);
    expect(
      find.byKey(const Key('ki-pruefblatt')),
      findsOneWidget,
      reason: 'nach dem Auslöser steht das Prüfblatt',
    );
  }

  VoidCallback? buchen(WidgetTester tester) => tester
      .widget<CupertinoButton>(find.byKey(const Key('ki-pruef-buchen')))
      .onPressed;

  String textVon(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' ');

  Future<List<EintragRow>> eintraege(AppCache db) =>
      db.select(db.eintraege).get();

  Future<List<KiAnfrageRow>> protokoll(AppCache db) =>
      db.select(db.kiAnfragen).get();

  // ═════════════════════════════════════════════════════════════════════
  group('Während die Schätzung läuft', () {
    testWidgets('steht nie ein Grund da — kein Fehler, kein „nichts '
        'erkannt" (`01`) — und „Buchen" ist da, aber aus', (tester) async {
      final h = behaelter();
      final halt = Completer<http.Response>();
      h.antworten.add(() => halt.future);
      await starte(tester, h);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsNothing);
      expect(find.text('Nichts erkannt'), findsNothing);
      expect(find.text('Hat nicht geklappt'), findsNothing);
      expect(find.byKey(const Key('ki-pruef-schaetzung')), findsOneWidget);
      expect(
        textVon(tester, find.byKey(const Key('ki-pruef-schaetzung'))),
        contains('Schätzung, keine exakten Werte'),
      );
      expect(find.byKey(const Key('ki-pruef-buchen')), findsOneWidget);
      expect(buchen(tester), isNull, reason: 'noch nichts zu buchen');
      expect(find.byKey(const Key('ki-pruef-abbrechen')), findsOneWidget);
      expect(h.anfragen, hasLength(1));

      halt.complete(antwort(teller));
      await ruhe(tester);
    });

    testWidgets('„Abbrechen" schließt das Blatt und verwirft das Foto', (
      tester,
    ) async {
      final h = behaelter();
      final halt = Completer<http.Response>();
      h.antworten.add(() => halt.future);
      await starte(tester, h);
      final abo = h.container.listen(kiFotoProvider, (_, _) {});
      addTearDown(abo.close);
      await schaetze(tester);

      await tippe(tester, find.byKey(const Key('ki-pruef-abbrechen')));

      expect(find.byKey(const Key('ki-pruefblatt')), findsNothing);
      expect(abo.read(), isNull);
      expect(
        find.byKey(const Key('ki-ausloeser')),
        findsOneWidget,
        reason: 'zurück im Sucher, bereit für das nächste Foto',
      );

      halt.complete(antwort(teller));
      await ruhe(tester);
      expect(await eintraege(h.db), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Vorschlag', () {
    testWidgets('ein unsicherer Posten ist nicht vorab übernommen; der Knopf '
        'zählt nur übernommene', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);

      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('ki-pruef-zeile-$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('ki-pruef-grund')), findsNothing);
      expect(
        textVon(tester, find.byKey(const Key('ki-pruef-zeile-3'))),
        contains('–/–'),
        reason: 'ohne Menge keine Kalorien — `null` bleibt `null`, nie 0',
      );
      expect(
        textVon(tester, find.byKey(const Key('ki-pruef-buchen'))),
        contains('3 Einträge buchen'),
      );
      expect(buchen(tester), isNotNull);
      expect(
        textVon(tester, find.byKey(const Key('ki-pruef-schaetzung'))),
        contains('Schätzung, keine exakten Werte'),
      );
    });

    testWidgets('Menge ändern → die Zeile heißt „von dir", die Kalorien '
        'skalieren', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);

      await tippe(tester, find.byKey(const Key('ki-pruef-zeile-0')));
      await tippe(tester, find.text('Menge ändern'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('ki-pruef-menge-feld')),
          matching: find.byType(EditableText),
        ),
        '280',
      );
      await tester.pump();
      await tippe(tester, find.byKey(const Key('ki-pruef-menge-ok')));

      final zeile = textVon(tester, find.byKey(const Key('ki-pruef-zeile-0')));
      expect(zeile, contains('von dir'));
      expect(zeile, contains('462'), reason: '231 kcal für 140 g → 280 g');
      expect(zeile, contains('280'));
      expect(
        h.anfragen,
        hasLength(1),
        reason: 'neu berechnet wird nur auf Tipp',
      );
    });

    testWidgets('„Neu berechnen" schickt dasselbe Foto mit der geänderten '
        'Zeile als Vorgabe — und die Antwort überschreibt sie nicht', (
      tester,
    ) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      h.antworten.add(
        () async => antwort({
          'isFood': true,
          'title': 'Hähnchen mit Reis',
          'items': [
            {
              'name': 'Hähnchenbrust, gegrillt',
              'grams': 150,
              'kcal': 248,
              'proteinG': 46.5,
              'carbsG': 0,
              'fatG': 5.4,
              'confident': true,
            },
            {
              'name': 'Reis, gekocht',
              'grams': 200,
              'kcal': 260,
              'proteinG': 5.4,
              'carbsG': 56.7,
              'fatG': 0.6,
              'confident': true,
            },
          ],
        }),
      );
      await starte(tester, h);
      await schaetze(tester);

      await tippe(tester, find.byKey(const Key('ki-pruef-zeile-0')));
      await tippe(tester, find.text('Menge ändern'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('ki-pruef-menge-feld')),
          matching: find.byType(EditableText),
        ),
        '280',
      );
      await tester.pump();
      await tippe(tester, find.byKey(const Key('ki-pruef-menge-ok')));
      await tippe(tester, find.byKey(const Key('ki-pruef-neu-berechnen')));

      expect(h.anfragen, hasLength(2));
      expect(h.foto.aufnahmen, 1, reason: 'kein neues Foto');
      Map<String, Object?> bild(http.Request r) {
        final json = jsonDecode(r.body) as Map<String, Object?>;
        final teile =
            ((json['contents']! as List).first as Map)['parts'] as List;
        return (teile.firstWhere(
          (t) => (t as Map).containsKey('inline_data'),
        ) as Map).cast<String, Object?>();
      }

      expect(bild(h.anfragen[1]), bild(h.anfragen[0]), reason: 'dasselbe Foto');
      expect(h.anfragen[1].body, contains('Hähnchenbrust, gegrillt, 280 g'));

      final texte = [
        for (var i = 0; i < 3; i++)
          if (find.byKey(Key('ki-pruef-zeile-$i')).evaluate().isNotEmpty)
            textVon(tester, find.byKey(Key('ki-pruef-zeile-$i'))),
      ];
      expect(
        texte.where((t) => t.contains('Hähnchenbrust')),
        hasLength(1),
        reason: 'die Vorgabe steht einmal da, nicht doppelt',
      );
      final haehnchen = texte.firstWhere((t) => t.contains('Hähnchenbrust'));
      expect(haehnchen, contains('280'));
      expect(haehnchen, contains('462'));
      expect(haehnchen, contains('von dir'));
      expect(texte.any((t) => t.contains('Reis') && t.contains('260')), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Buchen', () {
    testWidgets('genau N Einträge mit Herkunft — und keiner vor dem Tipp', (
      tester,
    ) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);

      expect(await eintraege(h.db), isEmpty, reason: 'nichts vor dem Tipp');

      await tippe(tester, find.byKey(const Key('ki-pruef-buchen')));

      final gebucht = await eintraege(h.db);
      expect(gebucht, hasLength(3), reason: 'die Soße ohne Menge nicht');
      for (final e in gebucht) {
        expect(e.vorschlag, isNotNull);
        expect(e.vorschlag, contains('gemini'));
        expect(e.tagesSchluessel, heute);
      }
      expect(
        gebucht.map((e) => e.name),
        containsAll(['Hähnchenbrust, gegrillt', 'Reis, gekocht', 'Brokkoli']),
      );
    });

    testWidgets('danach hält kein Provider das Foto, Blatt und Kamera sind '
        'zu (Review Focus 6)', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      final abo = h.container.listen(kiFotoProvider, (_, _) {});
      addTearDown(abo.close);
      await schaetze(tester);
      expect(abo.read(), isNotNull);

      await tippe(tester, find.byKey(const Key('ki-pruef-buchen')));

      expect(abo.read(), isNull);
      expect(find.byKey(const Key('ki-pruefblatt')), findsNothing);
      expect(find.byKey(const Key('kamera')), findsNothing);
    });

    testWidgets('die gebuchten Zeilen tragen „KI-Schätzung" in der Mahlzeit', (
      tester,
    ) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);
      await tippe(tester, find.byKey(const Key('ki-pruef-buchen')));

      h.router.open(AppTarget.ernaehrung());
      await ruhe(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-mittag')));

      expect(find.text('KI-Schätzung'), findsNWidgets(3));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Wenn es nicht klappt', () {
    testWidgets('nichts erkannt: der Grund steht da, gebucht werden kann '
        'nichts, „Neues Foto" führt zurück', (tester) async {
      final h = behaelter();
      h.antworten.add(
        () async => antwort({'isFood': false, 'items': <Object?>[]}),
      );
      await starte(tester, h);
      final abo = h.container.listen(kiFotoProvider, (_, _) {});
      addTearDown(abo.close);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsOneWidget);
      expect(find.byKey(const Key('ki-pruef-zeile-0')), findsNothing);
      expect(find.byKey(const Key('ki-pruef-neu-berechnen')), findsOneWidget);

      await tippe(tester, find.byKey(const Key('ki-pruef-neues-foto')));
      expect(find.byKey(const Key('ki-pruefblatt')), findsNothing);
      expect(abo.read(), isNull);
      expect(find.byKey(const Key('ki-ausloeser')), findsOneWidget);
      expect(await eintraege(h.db), isEmpty);
    });

    testWidgets('kein Netz → „Nochmal versuchen" mit demselben Foto, ohne '
        'neue Aufnahme', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => throw http.ClientException('erfunden'));
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsOneWidget);
      expect(find.byKey(const Key('ki-pruef-zugang')), findsNothing);
      expect(buchen(tester), isNull);

      await tippe(tester, find.byKey(const Key('ki-pruef-nochmal')));

      expect(h.foto.aufnahmen, 1);
      expect(h.anfragen, hasLength(2));
      expect(find.byKey(const Key('ki-pruef-grund')), findsNothing);
      expect(find.byKey(const Key('ki-pruef-zeile-0')), findsOneWidget);
      expect(buchen(tester), isNotNull);
    });

    testWidgets('Schlüssel abgelehnt → kein „Nochmal versuchen", aber der Weg '
        'in den KI-Zugang', (tester) async {
      final h = behaelter();
      h.antworten.add(
        () async => http.Response(
          jsonEncode({
            'error': {
              'code': 400,
              'status': 'INVALID_ARGUMENT',
              'details': [
                {
                  '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                  'reason': 'API_KEY_INVALID',
                },
              ],
            },
          }),
          400,
          headers: const {'content-type': 'application/json'},
        ),
      );
      await starte(tester, h);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsOneWidget);
      expect(find.byKey(const Key('ki-pruef-nochmal')), findsNothing);
      expect(buchen(tester), isNull);

      await tippe(tester, find.byKey(const Key('ki-pruef-zugang')));
      expect(find.byType(KiZugangSeite), findsOneWidget);
    });

    testWidgets('Google-Kontingent → kein sofortiges „Nochmal", „Stattdessen '
        'suchen" führt in die Suche', (tester) async {
      final h = behaelter();
      h.antworten.add(
        () async => http.Response(
          jsonEncode({
            'error': {'code': 429, 'status': 'RESOURCE_EXHAUSTED'},
          }),
          429,
          headers: const {'content-type': 'application/json'},
        ),
      );
      await starte(tester, h);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsOneWidget);
      expect(find.byKey(const Key('ki-pruef-nochmal')), findsNothing);

      await tippe(tester, find.byKey(const Key('ki-pruef-suchen')));
      expect(find.byType(SucheView), findsOneWidget);
      expect(find.byKey(const Key('kamera')), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Jede Antwort wird gezählt', () {
    testWidgets('eine Schätzung → eine Zeile in `ki_anfragen`', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);

      final zeilen = await protokoll(h.db);
      expect(zeilen, hasLength(1));
      final z = zeilen.single;
      expect(z.zweck, 'foto');
      expect(z.modell, 'gemini-3.6-flash');
      expect(z.eingabeToken, 1200);
      expect(z.ausgabeToken, 300);
      expect(z.denkToken, 40);
      expect(z.kostenUsd, isNotNull, reason: 'für das Modell ist ein Preis da');
    });

    testWidgets('auch eine unbrauchbare Antwort mit Zählern', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => antwort('kein JSON', alsJson: false));
      await starte(tester, h);
      await schaetze(tester);

      expect(find.byKey(const Key('ki-pruef-grund')), findsOneWidget);
      expect(await protokoll(h.db), hasLength(1));
    });

    testWidgets('ohne Netz gibt es nichts zu zählen', (tester) async {
      final h = behaelter();
      h.antworten.add(() async => throw http.ClientException('erfunden'));
      await starte(tester, h);
      await schaetze(tester);

      expect(await protokoll(h.db), isEmpty);
    });

    testWidgets('„Neu berechnen" ist eine zweite Antwort, eine zweite Zeile', (
      tester,
    ) async {
      final h = behaelter();
      h.antworten.add(() async => antwort(teller));
      h.antworten.add(() async => antwort(teller));
      await starte(tester, h);
      await schaetze(tester);
      await tippe(tester, find.byKey(const Key('ki-pruef-neu-berechnen')));

      expect(await protokoll(h.db), hasLength(2));
    });
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
