import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/design/inset_card.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_repository.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/ki/ki_zugang_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für den **KI-Sucher** (#340) — Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 9; Spec
/// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Foto-Schätzung
/// als erste Aktion", Schritte 1–3; Entwurf `docs/screens/screens/erfassen.js`,
/// Zustände `foto`, `foto-ohne-schluessel`, `foto-limit`.
///
/// **Umgestellt mit #355 (Tim, 04.11.2026, auf dem iPhone):** Nach dem Foto
/// kommt **kein** Hinweisblatt („Noch etwas dazu?") mehr — das Foto geht
/// direkt in die Schätzung. Hinweise an die KI gibt Tim erst im Prüfblatt,
/// über „Hinweis an die KI" und „Neu berechnen". Das löst die frühere
/// Festlegung „Der Hinweis an die KI steht schon vor der Schätzung" (Tim,
/// 27.10.2026; Spec, „Wer was entschieden hat") ab. Der Satz zum Datenweg,
/// der im Hinweisblatt stand, steht jetzt im Fuß des Suchers — geprüft in
/// `ki_sucher_fuss_test.dart`.
///
/// Geprüft an der **ganzen** App (`RootView`), wie
/// `barcode_kamera_test.dart`: Der Weg in den KI-Zugang ist ein Sprung über
/// den Router, und der hängt nur in der echten Hülle.
///
/// **Rollen** (Plan, „Global Constraints"): Widget-Tests — ein Agent, der
/// Test entsteht zuerst, wird rot gesehen und **vor der Implementierung
/// committet**. Danach darf diese Datei ausgeführt, aber nicht verändert
/// werden (`.githooks/pre-commit`).
///
/// ## Die Naht zur Fotokamera — Festlegung des Agenten von #340
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben.** Der Plan nennt nur
/// `FotoAufnahme.nimmAuf()`; eine Aufnahme braucht aber eine laufende
/// Vorschau, und die gehört — wie beim `StrichcodeLeser` — dem Schirm, der
/// sie zeigt. Deshalb in **`lib/ernaehrung/ki_sucher.dart`**:
///
/// ```dart
/// abstract interface class FotoAufnahme {
///   /// Nimmt ein Foto auf und liefert es **verkleinert** (≤ 1.024 Punkte,
///   /// JPEG-Qualität 80). Die Temp-Datei der Kamera ist danach gelöscht.
///   Future<List<int>> nimmAuf();
/// }
///
/// abstract interface class FotoKamera {
///   /// Die Vorschau. Meldet über [aufBereit], sobald aufgenommen werden
///   /// kann, und eine verweigerte Freigabe über [aufVerweigert].
///   Widget sucher({
///     required ValueChanged<FotoAufnahme> aufBereit,
///     required VoidCallback aufVerweigert,
///   });
/// }
///
/// final fotoKameraProvider = Provider<FotoKamera>(…);
///
/// /// Das Foto zwischen Aufnahme und Buchen — **der einzige Ort, an dem es
/// /// liegt**. `null` heißt: keins.
/// final kiFotoProvider = …; // Wert: List<int>?
///
/// /// Der Übergabepunkt an das Prüfblatt (#341).
/// typedef KiSchaetzungStarten =
///     Future<void> Function(BuildContext context, KiAuftrag auftrag);
/// final kiSchaetzungStartenProvider = Provider<KiSchaetzungStarten>(…);
///
/// class KiAuftrag { String tagesSchluessel; Mahlzeit? mahlzeit; }
/// // `hinweis` stand hier bis #355; ohne Hinweisblatt schreibt dieser
/// // Test kein solches Feld mehr vor.
///
/// List<int> verkleinere(List<int> jpeg);
/// ```
///
/// Warum so:
///
/// - **Das Foto liegt in genau einem Provider**, nicht im Zustand eines
///   Widgets. Nur so lässt sich prüfen, dass nach „Neues Foto" und nach
///   dem Buchen (beides im Prüfblatt, #341) **kein Zustand mehr Bytes hält** (Spec, Review
///   Focus 6). Der Auftrag trägt das Foto deshalb nicht noch einmal.
/// - **Der Übergabepunkt ist ein Provider**, damit dieser Test ihn ersetzen
///   kann, bevor es das Prüfblatt gibt. Task 10 setzt die echte Fassung ein.
/// - `nimmAuf` liefert schon verkleinert: Die Attrappe gibt erfundene
///   Bytes zurück, kein echtes JPEG; `verkleinere` ist eigens geprüft.
///
/// ## Die Schlüssel
///
/// - `Key('kamera-modus-barcode')`, `Key('kamera-modus-ki')` — der Umschalter
///   (seit #439 die Kacheln „Barcode" und „KI-Foto" der Kachelreihe)
/// - `Key('ki-sucher')` — der Sucher im KI-Modus
/// - `Key('ki-ausloeser')` — der Auslöser
/// - `Key('ki-ohne-schluessel')` — statt des Auslösers: Weg in den KI-Zugang
/// - `Key('ki-limit')` — statt des Auslösers: Monatslimit erreicht
/// - `Key('ki-hinweis-blatt')` — „Noch etwas dazu?" — **gibt es seit #355
///   nicht mehr**; geprüft wird, dass es nie erscheint
///
/// `Key('kamera')`, `Key('kamera-verweigert')` und `Key('erfassen-knopf')`
/// gelten wie in `barcode_kamera_test.dart`.
///
/// Alle Schlüssel, Produkte und Strichcodes hier sind **erfunden**; kein
/// Test geht ins Netz, keiner trägt einen echten Gemini-Schlüssel.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  // Erfunden, ohne das Präfix echter Schlüssel.
  const schluessel = 'erfunden-schluessel-wxyz';
  const codeEigen = '0000000004242';

  ({
    ProviderContainer container,
    AppCache db,
    AppRouter router,
    TestLeser leser,
    TestFotoKamera foto,
    AttrappenSchluesselSpeicher speicher,
    List<KiAuftrag> auftraege,
  })
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final leser = TestLeser();
    final foto = TestFotoKamera();
    final speicher = AttrappenSchluesselSpeicher();
    final auftraege = <KiAuftrag>[];

    // Gemini antwortet auf die Modellliste — der Nachlauf des KI-Zugangs.
    // Alles andere wäre ein Fehler dieses Tests.
    final gemini = MockClient((anfrage) async {
      if (anfrage.method != 'GET') {
        fail('unerwartete Anfrage an Gemini: ${anfrage.url.path}');
      }
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
    });
    // Open Food Facts wird hier nie gefragt: Der eine Code steht in der
    // eigenen Tabelle.
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
        strichcodeLeserProvider.overrideWithValue(leser),
        fotoKameraProvider.overrideWithValue(foto),
        kiSchluesselProvider.overrideWithValue(speicher),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
        kiSchaetzungStartenProvider.overrideWithValue(
          (context, auftrag) async => auftraege.add(auftrag),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      db: db,
      router: AppRouter(),
      leser: leser,
      foto: foto,
      speicher: speicher,
      auftraege: auftraege,
    );
  }

  Future<void> starte(
    WidgetTester tester,
    ({
      ProviderContainer container,
      AppCache db,
      AppRouter router,
      TestLeser leser,
      TestFotoKamera foto,
      AttrappenSchluesselSpeicher speicher,
      List<KiAuftrag> auftraege,
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

  /// Die Karte im Verweis, nicht der Verweis selbst: Der Schlüssel sitzt
  /// auf dem ganzen, fest hohen Fuß, die Karte nur oben darin. Ein Tipp auf
  /// die Mitte des Schlüssels traf sie bisher nur, weil der Rand sie knapp
  /// über die Mitte reichen ließ (#384).
  Finder verweisKarte(String schluessel) => find.descendant(
    of: find.byKey(Key(schluessel)),
    matching: find.byType(InsetCard),
  );

  /// (+) → Kamera → „KI".
  Future<void> zurKi(WidgetTester tester) async {
    await tippe(tester, find.byKey(const Key('erfassen-knopf')));
    expect(find.byKey(const Key('kamera')), findsOneWidget);
    await tippe(tester, find.byKey(const Key('kamera-modus-ki')));
    expect(
      find.byKey(const Key('ki-sucher')),
      findsOneWidget,
      reason: 'ein Tipp auf „KI" schaltet um — derselbe Schirm (`foto`)',
    );
  }

  /// Ein Foto aufnehmen — es geht ohne Zwischenblatt in die Schätzung
  /// (#355).
  Future<void> nimmAuf(WidgetTester tester) async {
    await tippe(tester, find.byKey(const Key('ki-ausloeser')));
    expect(
      find.byKey(const Key('ki-hinweis-blatt')),
      findsNothing,
      reason:
          'seit #355 steht zwischen Auslöser und Anfrage kein „Noch '
          'etwas dazu?" mehr',
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Ein Sucher, zwei Modi', () {
    testWidgets(
      'Barcode → KI → Barcode: die Fotokamera läuft nur im KI-Modus, der '
      'Barcode-Leser danach wieder',
      (tester) async {
        final h = behaelter();
        await h.speicher.schreibe(schluessel);
        await LebensmittelRepository(h.db).legeAn(
          const LebensmittelVorlage(
            name: 'Prüfmüsli',
            je100g: Naehrwerte.je100g(kcal: 360, eiweissG: 11, fettG: 6),
            barcode: codeEigen,
          ),
        );
        await starte(tester, h);

        await tippe(tester, find.byKey(const Key('erfassen-knopf')));
        expect(h.leser.laeuft, isTrue);
        expect(
          h.foto.laeuft,
          isFalse,
          reason: 'Barcode-Modus: keine Fotokamera',
        );

        await tippe(tester, find.byKey(const Key('kamera-modus-ki')));
        expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
        expect(
          h.leser.laeuft,
          isFalse,
          reason: '„KI" gibt den Barcode-Leser frei — eine Kamera, ein Nutzer',
        );
        expect(h.foto.laeuft, isTrue);

        await tippe(tester, find.byKey(const Key('kamera-modus-barcode')));
        expect(find.byKey(const Key('ki-sucher')), findsNothing);
        expect(h.foto.laeuft, isFalse);
        expect(h.leser.laeuft, isTrue);

        // Und er wertet wieder aus.
        h.leser.erkenne(codeEigen);
        await ruhe(tester);
        expect(find.byType(BuchungsBlatt), findsOneWidget);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Kein Auslöser, der scheitert', () {
    testWidgets(
      'ohne Schlüssel: kein Auslöser, stattdessen der Weg in den KI-Zugang',
      (tester) async {
        final h = behaelter();
        await starte(tester, h);
        await zurKi(tester);

        expect(find.byKey(const Key('ki-ausloeser')), findsNothing);
        expect(find.byKey(const Key('ki-limit')), findsNothing);
        expect(find.byKey(const Key('ki-ohne-schluessel')), findsOneWidget);

        await tippe(tester, verweisKarte('ki-ohne-schluessel'));
        expect(find.byType(KiZugangSeite), findsOneWidget);
      },
    );

    testWidgets(
      'Monatslimit erreicht: kein Auslöser, stattdessen der Verweis aufs Limit',
      (tester) async {
        final h = behaelter();
        await h.speicher.schreibe(schluessel);
        final repo = KiRepository(h.db);
        await repo.setzeLimit(1);
        await repo.protokolliere(
          zeitpunkt: jetzt.subtract(const Duration(hours: 1)),
          modell: 'gemini-3.6-flash',
          zweck: 'foto',
          verbrauch: const KiVerbrauch(eingabe: 1000, ausgabe: 200, denken: 0),
          kosten: 1.5,
        );
        await starte(tester, h);
        await zurKi(tester);

        expect(find.byKey(const Key('ki-ausloeser')), findsNothing);
        expect(find.byKey(const Key('ki-ohne-schluessel')), findsNothing);
        expect(find.byKey(const Key('ki-limit')), findsOneWidget);

        await tippe(tester, verweisKarte('ki-limit'));
        expect(find.byType(KiZugangSeite), findsOneWidget);
      },
    );

    testWidgets('mit Schlüssel und unter dem Limit steht der Auslöser da', (
      tester,
    ) async {
      final h = behaelter();
      await h.speicher.schreibe(schluessel);
      await starte(tester, h);
      await zurKi(tester);

      expect(find.byKey(const Key('ki-ausloeser')), findsOneWidget);
      expect(find.byKey(const Key('ki-ohne-schluessel')), findsNothing);
      expect(find.byKey(const Key('ki-limit')), findsNothing);
    });

    testWidgets(
      'ohne Kamerafreigabe: kein Auslöser, der Weg in die Einstellungen',
      (tester) async {
        final h = behaelter();
        await h.speicher.schreibe(schluessel);
        await starte(tester, h);
        await zurKi(tester);

        h.foto.verweigere();
        await ruhe(tester);

        expect(find.byKey(const Key('kamera-verweigert')), findsOneWidget);
        expect(find.byKey(const Key('ki-ausloeser')), findsNothing);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // Umgestellt mit #355: Früher kam nach der Aufnahme „Noch etwas dazu?",
  // und erst „Schätzen" übergab. Jetzt übergibt der Auslöser selbst. Was
  // die alten Fälle über das Foto sagten — es liegt nach der Aufnahme im
  // Arbeitsspeicher, genau einmal aufgenommen, der Auftrag trägt es nicht
  // —, gilt weiter. Dass „Neues Foto" und „Abbrechen" das Foto verwerfen,
  // prüft `ki_pruefblatt_test.dart` am Prüfblatt; das Blatt, in dem
  // „Neues Foto" hier stand, gibt es nicht mehr.
  group('Aufnahme — direkt in die Schätzung (#355)', () {
    testWidgets('Doppeltipp auf den Auslöser → genau eine Aufnahme, genau '
        'eine Schätzung', (tester) async {
      final h = behaelter();
      await h.speicher.schreibe(schluessel);
      await starte(tester, h);
      await zurKi(tester);

      final sperre = Completer<void>();
      h.foto.sperre = sperre;

      await tester.tap(find.byKey(const Key('ki-ausloeser')));
      await tester.pump();
      // Der Auslöser ist während der Aufnahme gesperrt — womöglich nimmt
      // er gar keine Berührung an; dann ist die Warnung erwünscht.
      await tester.tap(
        find.byKey(const Key('ki-ausloeser')),
        warnIfMissed: false,
      );
      await tester.pump();

      sperre.complete();
      await ruhe(tester);

      expect(h.foto.aufnahmen, 1);
      expect(h.auftraege, hasLength(1));
      expect(find.byKey(const Key('ki-hinweis-blatt')), findsNothing);
    });

    testWidgets(
      'nach der Aufnahme kommt kein Hinweisblatt — das Foto geht mit dem '
      'offenen Tag direkt in die Schätzung',
      (tester) async {
        final h = behaelter();
        await h.speicher.schreibe(schluessel);
        await starte(tester, h);
        await zurKi(tester);

        await nimmAuf(tester);

        expect(
          h.auftraege,
          hasLength(1),
          reason: 'der Auslöser selbst startet die Schätzung',
        );
        expect(h.auftraege.single.tagesSchluessel, heute);
      },
    );

    testWidgets('nach der Übergabe liegt das Foto im Speicher, genau einmal '
        'aufgenommen', (tester) async {
      final h = behaelter();
      await h.speicher.schreibe(schluessel);
      await starte(tester, h);
      final abo = h.container.listen(kiFotoProvider, (_, _) {});
      addTearDown(abo.close);
      await zurKi(tester);
      expect(abo.read(), isNull, reason: 'vor der Aufnahme: kein Foto');

      await nimmAuf(tester);

      expect(h.auftraege, hasLength(1));
      expect(
        abo.read(),
        h.foto.bild,
        reason:
            'die Schätzung (#341) braucht das Foto; verworfen wird nach '
            'dem Buchen',
      );
      expect(h.foto.aufnahmen, 1);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('verkleinere', () {
    List<int> jpeg(int breite, int hoehe) => img.encodeJpg(
      img.Image(width: breite, height: hoehe)
        ..clear(img.ColorRgb8(180, 120, 60)),
    );

    img.Image lies(List<int> bytes) {
      final bild = img.decodeJpg(Uint8List.fromList(bytes));
      expect(bild, isNotNull, reason: 'heraus kommt ein lesbares JPEG');
      return bild!;
    }

    test('ein Querformat wird auf 1.024 Punkte Kantenlänge verkleinert', () {
      final klein = lies(verkleinere(jpeg(3000, 2000)));
      expect(klein.width, 1024);
      expect(klein.height, closeTo(683, 1));
    });

    test('ein Hochformat ebenso — die lange Kante zählt', () {
      final klein = lies(verkleinere(jpeg(1500, 4000)));
      expect(klein.height, 1024);
      expect(klein.width, closeTo(384, 1));
    });

    test('ein kleines Bild wird nicht vergrößert', () {
      final klein = lies(verkleinere(jpeg(800, 600)));
      expect(klein.width, 800);
      expect(klein.height, 600);
    });
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
