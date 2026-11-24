import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/erfassen_kacheln.dart';
import 'package:repit/ernaehrung/erfassen_weg.dart';
import 'package:repit/ernaehrung/kamera_bausteine.dart';
import 'package:repit/ernaehrung/kamera_seite.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';

/// Die **Kachelreihe der Wege** und der **Kopf mit Zähler** in Sucher und
/// Suche (#439, Schnitt 2 von #385) — Plan
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Task 10;
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Entscheidung 9, V20–V23 und „Erfassen: Kachelreihe und „+"";
/// Entwurf `docs/screens/screens/erfassen.js` (`KACHELN`, `MAHLZEIT_KOPF`,
/// Zustände `vorschlag-suche` und `vorschlag-kamera`).
///
/// Geprüft an der **ganzen** App (`RootView`) auf einer Datenbank im
/// Speicher, wie `mahlzeit_kamera_test.dart`: Ein Wechsel zwischen Kamera
/// und Suche, der im Einzeltest geht und in der App an einem fehlenden
/// `router` hängt, ist genau der Fehler, um den es hier geht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Für Widget-Tests genügt ein Agent, solange der Test
/// zuerst entsteht, einmal rot gesehen und committet wird, bevor die
/// Implementierung anfängt. Danach darf diese Datei ausgeführt, aber nicht
/// verändert werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// - `lib/ernaehrung/erfassen_kacheln.dart` mit
///   `enum ErfassenWeg { barcode, ki, suchen, nurKcal }`,
///   `ErfassenKacheln({required ErfassenWeg aktiv, required bool dunkel,
///   required void Function(ErfassenWeg) aufWeg})` und
///   `ErfassenKopf({required int gebucht, required String titel,
///   required VoidCallback aufAbbrechen, required bool dunkel})`.
/// - `oeffneKamera(router, {…, KameraModus modus = KameraModus.barcode,
///   int gebucht = 0})` und `oeffneSuche(router, {…, int gebucht = 0})`.
///
/// ### Die Schlüssel
///
/// - an den Kacheln, **in Sucher und Suche dieselben**:
///   `Key('kamera-modus-barcode')`, `Key('kamera-modus-ki')`,
///   `Key('kamera-suchen')` (V21: bleiben an den Kacheln im Sucher) und
///   `Key('kamera-nur-kcal')`. *Dass die Suche dieselben Schlüssel trägt
///   und „Nur kcal" `kamera-nur-kcal` heißt, legt der Test-Agent von #439
///   fest, nicht Tim* — die Spec nennt nur die drei im Sucher. Eine Reihe,
///   ein Satz Schlüssel.
/// - im Kopf: `Key('erfassen-zaehler')`, `Key('erfassen-titel')`,
///   `Key('erfassen-abbrechen')` in der Suche; im Sucher behält
///   „Abbrechen" `Key('kamera-abbrechen')` (Spec, „Erfassen").
/// - `Key('erfassen-suchfeld')`, `Key('kamera')`, `Key('ki-sucher')`,
///   `Key('erfassen-knopf')` gelten wie bisher.
///
/// ### Vorlesetexte
///
/// - „Nur kcal, noch nicht verfügbar" (V20)
/// - der Zähler „2 gebucht" (Spec, „Vorlesetexte")
///
/// Nicht geprüft: Layout und Beschriftung (`CLAUDE.md`) — außer **wo** die
/// Reihe steht (unten im Sucher, oben in der Suche), weil genau das die
/// Anforderung ist, und dem Wortlaut des Suchfelds (V23), weil er die
/// Mahlzeit nennt, auf die gebucht wird.
///
/// Alle Namen und Strichcodes hier sind **erfunden**; kein Test geht ins
/// Netz.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2) — die Uhr ergibt
  // Mittag. Jede ausdrücklich vorgewählte Mahlzeit weicht davon ab.
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // Gemini antwortet nur auf die Modellliste — ohne Schlüssel wird ohnehin
    // nichts geschätzt.
    final gemini = MockClient((anfrage) async {
      if (anfrage.method != 'GET') {
        fail('unerwartete Anfrage an Gemini: ${anfrage.url.path}');
      }
      return http.Response(
        jsonEncode({'models': <Object>[]}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(
          OffClient(client: MockClient((_) async => http.Response('', 500))),
        ),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        fotoKameraProvider.overrideWithValue(TestFotoKamera()),
        kiSchluesselProvider.overrideWithValue(AttrappenSchluesselSpeicher()),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, router: AppRouter());
  }

  Future<({ProviderContainer container, AppRouter router})> starte(
    WidgetTester tester,
  ) async {
    final h = behaelter();
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
    return h;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> plus(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('erfassen-knopf')));

  Future<void> zumErnaehrungsTab(WidgetTester tester) => tippe(
    tester,
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.byIcon(Symbole.aufloesen('fork.knife')),
    ),
  );

  /// Eine Kachel der Reihe — gesucht **in** der Reihe, nicht irgendwo.
  Finder kachel(String schluessel) => find.descendant(
    of: find.byType(ErfassenKacheln),
    matching: find.byKey(Key(schluessel)),
  );

  ErfassenKacheln reihe(WidgetTester tester) =>
      tester.widget<ErfassenKacheln>(find.byType(ErfassenKacheln));

  /// Wie viele Kameras im Baum stehen, auch verdeckte.
  int kameras(WidgetTester tester) =>
      find.byType(KameraSeite, skipOffstage: false).evaluate().length;

  /// Der Text unter einem Schlüssel des Kopfs, der Schlüssel selbst
  /// eingeschlossen.
  Finder imKopf(String schluessel, String text) => find.descendant(
    of: find.byKey(Key(schluessel)),
    matching: find.text(text),
    matchRoot: true,
  );

  Future<void> oeffneSucheMit(
    WidgetTester tester,
    AppRouter router, {
    Mahlzeit? mahlzeit,
    int gebucht = 0,
  }) async {
    oeffneSuche(router, mahlzeit: mahlzeit, gebucht: gebucht);
    await tester.pumpAndSettle();
    expect(find.byType(SucheView), findsOneWidget);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Im Sucher', () {
    testWidgets('die Reihe steht unten, Barcode ist aktiv, und oben rechts '
        'gibt es kein „Suchen" mehr', (tester) async {
      await starte(tester);
      await plus(tester);

      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(find.byType(ErfassenKacheln), findsOneWidget);
      for (final schluessel in const [
        'kamera-modus-barcode',
        'kamera-modus-ki',
        'kamera-suchen',
        'kamera-nur-kcal',
      ]) {
        expect(kachel(schluessel), findsOneWidget, reason: schluessel);
      }
      expect(reihe(tester).aktiv, ErfassenWeg.barcode);
      expect(reihe(tester).dunkel, isTrue, reason: 'auf dem schwarzen Sucher');

      expect(
        tester.getRect(find.byType(ErfassenKacheln)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(SucherFenster)).bottom),
        reason: 'im Sucher unten, wo der Umschalter stand (Daumen)',
      );
      expect(
        find.descendant(
          of: find.byType(ErfassenKopf),
          matching: find.text('Suchen'),
        ),
        findsNothing,
        reason: '„Suchen" ist jetzt eine Kachel (Entscheidung 9)',
      );
    });

    testWidgets('KI-Foto wechselt in den KI-Sucher auf derselben Seite, '
        'Barcode zurück', (tester) async {
      await starte(tester);
      await plus(tester);

      await tippe(tester, kachel('kamera-modus-ki'));
      expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(kameras(tester), 1, reason: 'kein zweiter Schirm');
      expect(find.byType(SucheView), findsNothing);
      expect(reihe(tester).aktiv, ErfassenWeg.ki);

      await tippe(tester, kachel('kamera-modus-barcode'));
      expect(find.byKey(const Key('ki-sucher')), findsNothing);
      expect(kameras(tester), 1);
      expect(reihe(tester).aktiv, ErfassenWeg.barcode);
    });

    testWidgets('Suchen schließt die Kamera und öffnet die Suche — statt '
        'der Kamera, nicht über ihr (V21)', (tester) async {
      await starte(tester);
      await plus(tester);

      await tippe(tester, kachel('kamera-suchen'));

      expect(find.byType(SucheView), findsOneWidget);
      expect(
        kameras(tester),
        0,
        reason: 'unter der Suche liegt keine Kamera mehr',
      );
      expect(reihe(tester).aktiv, ErfassenWeg.suchen);

      await tippe(tester, find.byKey(const Key('erfassen-abbrechen')));
      expect(find.byType(SucheView), findsNothing);
      expect(kameras(tester), 0);
      expect(find.byType(HeuteView), findsOneWidget);
    });

    testWidgets('ein Tipp auf den Weg, auf dem man ist, tut nichts', (
      tester,
    ) async {
      await starte(tester);
      await plus(tester);

      await tippe(tester, kachel('kamera-modus-barcode'));

      expect(kameras(tester), 1);
      expect(find.byKey(const Key('ki-sucher')), findsNothing);
      expect(find.byType(SucheView), findsNothing);
      expect(reihe(tester).aktiv, ErfassenWeg.barcode);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('In der Suche', () {
    testWidgets('die Reihe steht oben, über dem Suchfeld, Suchen ist aktiv', (
      tester,
    ) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      expect(find.byType(ErfassenKacheln), findsOneWidget);
      for (final schluessel in const [
        'kamera-modus-barcode',
        'kamera-modus-ki',
        'kamera-suchen',
        'kamera-nur-kcal',
      ]) {
        expect(kachel(schluessel), findsOneWidget, reason: schluessel);
      }
      expect(reihe(tester).aktiv, ErfassenWeg.suchen);
      expect(reihe(tester).dunkel, isFalse);
      expect(
        tester.getRect(find.byType(ErfassenKacheln)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('erfassen-suchfeld'))).top,
        ),
        reason: 'in der Suche oben — unten liegt die Tastatur',
      );
      expect(
        tester.getRect(find.byType(ErfassenKacheln)).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ErfassenKopf)).bottom),
        reason: 'unter dem Kopf',
      );
    });

    testWidgets('Barcode schließt die Suche und öffnet die Kamera im '
        'Barcode-Modus', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      await tippe(tester, kachel('kamera-modus-barcode'));

      expect(find.byType(SucheView, skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(kameras(tester), 1);
      expect(find.byKey(const Key('ki-sucher')), findsNothing);
      expect(reihe(tester).aktiv, ErfassenWeg.barcode);
    });

    testWidgets('KI-Foto schließt die Suche und öffnet die Kamera im '
        'KI-Modus', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      await tippe(tester, kachel('kamera-modus-ki'));

      expect(find.byType(SucheView, skipOffstage: false), findsNothing);
      expect(kameras(tester), 1);
      expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
      expect(reihe(tester).aktiv, ErfassenWeg.ki);
    });

    testWidgets('ein Tipp auf Suchen tut in der Suche nichts', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      await tippe(tester, kachel('kamera-suchen'));

      expect(find.byType(SucheView, skipOffstage: false), findsOneWidget);
      expect(kameras(tester), 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('„Nur kcal" steht da und tut nichts (V20)', () {
    testWidgets('im Sucher', (tester) async {
      final semantik = tester.ensureSemantics();
      await starte(tester);
      await plus(tester);

      expect(
        find.bySemanticsLabel(RegExp('Nur kcal, noch nicht verfügbar')),
        findsOneWidget,
      );

      await tippe(tester, kachel('kamera-nur-kcal'));

      expect(kameras(tester), 1);
      expect(find.byType(SucheView), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(CupertinoPopupSurface), findsNothing);
      expect(reihe(tester).aktiv, ErfassenWeg.barcode);
      semantik.dispose();
    });

    testWidgets('in der Suche', (tester) async {
      final semantik = tester.ensureSemantics();
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      expect(
        find.bySemanticsLabel(RegExp('Nur kcal, noch nicht verfügbar')),
        findsOneWidget,
      );

      await tippe(tester, kachel('kamera-nur-kcal'));

      expect(find.byType(SucheView), findsOneWidget);
      expect(kameras(tester), 0);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(CupertinoPopupSurface), findsNothing);
      expect(reihe(tester).aktiv, ErfassenWeg.suchen);
      semantik.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Kopf (V22)', () {
    testWidgets('in der Suche: Zähler 0 beim Öffnen, Titel aus der Uhr, '
        '„Abbrechen" schließt', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      expect(find.byType(ErfassenKopf), findsOneWidget);
      expect(imKopf('erfassen-zaehler', '0'), findsOneWidget);
      expect(
        imKopf('erfassen-titel', 'Mittag'),
        findsOneWidget,
        reason: 'ohne Vorwahl die Mahlzeit, die das Blatt um 12:00 wählt',
      );
      expect(
        tester.getRect(find.byKey(const Key('erfassen-zaehler'))).center.dx,
        lessThan(tester.getRect(find.byKey(const Key('erfassen-titel'))).left),
        reason: 'der Zähler links',
      );
      expect(
        tester.getRect(find.byKey(const Key('erfassen-abbrechen'))).left,
        greaterThan(tester.getRect(find.byKey(const Key('erfassen-titel'))).center.dx),
        reason: '„Abbrechen" rechts',
      );

      await tippe(tester, find.byKey(const Key('erfassen-abbrechen')));
      expect(find.byType(SucheView), findsNothing);
      expect(find.byType(HeuteView), findsOneWidget);
    });

    testWidgets('in der Suche: mit Vorwahl die vorgewählte Mahlzeit', (
      tester,
    ) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router, mahlzeit: Mahlzeit.abend);

      expect(imKopf('erfassen-titel', 'Abend'), findsOneWidget);
    });

    testWidgets('im Sucher: Zähler 0, Titel aus der Uhr, „Abbrechen" '
        '(kamera-abbrechen) im Kopf schließt', (tester) async {
      await starte(tester);
      await plus(tester);

      expect(find.byType(ErfassenKopf), findsOneWidget);
      expect(reihe(tester).dunkel, isTrue);
      expect(imKopf('erfassen-zaehler', '0'), findsOneWidget);
      expect(imKopf('erfassen-titel', 'Mittag'), findsOneWidget);
      final abbrechen = find.descendant(
        of: find.byType(ErfassenKopf),
        matching: find.byKey(const Key('kamera-abbrechen')),
      );
      expect(abbrechen, findsOneWidget);

      await tippe(tester, abbrechen);
      expect(kameras(tester), 0);
      expect(find.byType(HeuteView), findsOneWidget);
    });

    testWidgets('das „+" einer Mahlzeitenzeile: der Sucher trägt diese '
        'Mahlzeit, und die Suche danach auch', (tester) async {
      await starte(tester);
      await zumErnaehrungsTab(tester);
      await tippe(
        tester,
        find.byKey(const Key('ernaehrung-mahlzeit-plus-abend')),
      );
      expect(kameras(tester), 1);
      expect(imKopf('erfassen-titel', 'Abend'), findsOneWidget);

      await tippe(tester, kachel('kamera-suchen'));
      expect(find.byType(SucheView), findsOneWidget);
      expect(imKopf('erfassen-titel', 'Abend'), findsOneWidget);
    });

    testWidgets('der Zähler sagt vorgelesen „2 gebucht"', (tester) async {
      final semantik = tester.ensureSemantics();
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router, gebucht: 2);

      expect(find.bySemanticsLabel(RegExp('^2 gebucht')), findsOneWidget);
      semantik.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Zähler wandert mit (V21)', () {
    testWidgets('Suche mit 2 → Kamera zeigt 2 → zurück in die Suche, '
        'weiter 2', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router, gebucht: 2);
      expect(imKopf('erfassen-zaehler', '2'), findsOneWidget);

      await tippe(tester, kachel('kamera-modus-barcode'));
      expect(kameras(tester), 1);
      expect(imKopf('erfassen-zaehler', '2'), findsOneWidget);

      await tippe(tester, kachel('kamera-suchen'));
      expect(find.byType(SucheView), findsOneWidget);
      expect(imKopf('erfassen-zaehler', '2'), findsOneWidget);
    });

    testWidgets('Kamera mit 3 → Suche zeigt 3 → KI-Foto zeigt 3', (
      tester,
    ) async {
      final h = await starte(tester);
      oeffneKamera(h.router, gebucht: 3);
      await tester.pumpAndSettle();
      expect(kameras(tester), 1);
      expect(imKopf('erfassen-zaehler', '3'), findsOneWidget);

      await tippe(tester, kachel('kamera-suchen'));
      expect(imKopf('erfassen-zaehler', '3'), findsOneWidget);

      await tippe(tester, kachel('kamera-modus-ki'));
      expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
      expect(imKopf('erfassen-zaehler', '3'), findsOneWidget);
    });

    testWidgets('oeffneKamera mit Modus KI öffnet gleich den KI-Sucher', (
      tester,
    ) async {
      final h = await starte(tester);
      oeffneKamera(h.router, modus: KameraModus.ki);
      await tester.pumpAndSettle();

      expect(kameras(tester), 1);
      expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
      expect(reihe(tester).aktiv, ErfassenWeg.ki);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Nur eine Kamera (#326)', () {
    testWidgets('ein (+) bei offener Kamera tut weiter nichts', (
      tester,
    ) async {
      await starte(tester);
      await plus(tester);
      expect(kameras(tester), 1);

      await plus(tester);

      expect(kameras(tester), 1);
    });

    testWidgets('auch nachdem die Kamera aus der Suche heraus geöffnet '
        'wurde', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);
      await tippe(tester, kachel('kamera-modus-barcode'));
      expect(kameras(tester), 1);

      await plus(tester);

      expect(kameras(tester), 1);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Das Suchfeld fragt nach der Mahlzeit (V23)', () {
    String platzhalter(WidgetTester tester) => tester
        .widget<CupertinoSearchTextField>(
          find.byKey(const Key('erfassen-suchfeld')),
        )
        .placeholder!;

    for (final (mahlzeit, frage) in const [
      (Mahlzeit.fruehstueck, 'Was hattest du zum Frühstück?'),
      (Mahlzeit.mittag, 'Was hattest du zu Mittag?'),
      (Mahlzeit.abend, 'Was hattest du zu Abend?'),
      (Mahlzeit.snack, 'Was hattest du als Snack?'),
    ]) {
      testWidgets('${mahlzeit.name}: „$frage"', (tester) async {
        final h = await starte(tester);
        await oeffneSucheMit(tester, h.router, mahlzeit: mahlzeit);

        expect(platzhalter(tester), frage);
      });
    }

    testWidgets('ohne Vorwahl die Mahlzeit aus der Uhr', (tester) async {
      final h = await starte(tester);
      await oeffneSucheMit(tester, h.router);

      expect(platzhalter(tester), 'Was hattest du zu Mittag?');
    });
  });
}

class _StilleQuelle extends HealthReadingAttrappe {}
