import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den **Verlauf je Maß** (#479 unter #88) — den Schirm,
/// den jede Maß-Zeile der Übersicht öffnet.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn; die
/// Entscheidung trifft Tim oder der Test-Agent.
///
/// ## Woher die Anforderung kommt
///
/// `docs/superpowers/specs/2026-10-13-umfaenge-fortschritt-design.md`,
/// „Der Detailschirm je Maß" und „Erste Messung und leere Zustände";
/// `docs/superpowers/plans/2026-11-11-umfaenge.md`, Scheibe 3 und die
/// Tabelle „Keine-Daten-Ansichten"; Entwurf
/// `docs/screens/screens/umfang-detail.js`; Swift-Vorlage
/// `Sources/Features/Body/CircumferenceDetailView.swift`.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Die fünf Zusagen:
///
/// 1. **Jede Zeile trägt ihr Maß mit.** Ohne das öffnen alle fünfzehn
///    Zeilen denselben Schirm — der Grund, aus dem es den Entwurf
///    überhaupt gibt (`umfang-detail.js`, Kopf).
/// 2. **Die Gegenseite liegt als zweite, blasse Linie im Diagramm**
///    (`Umfang.partner`). Maße ohne Partner zeigen eine Linie — und der
///    Schirm sieht deswegen nicht anders aus.
/// 3. **Ein Punkt ist kein Verlauf**, und „noch nie gemessen" ist etwas
///    anderes als „erst einmal gemessen": zwei verschiedene Texte, und in
///    beiden Fällen dieselbe Geometrie.
/// 4. **Drei Lagen, drei unterscheidbare Auskünfte** (`laedt`, `unlesbar`,
///    `gelesen`). Während des Lesens behauptet nichts etwas über Tims
///    Daten (`01`), und „Lesen gescheitert" sieht nicht aus wie „lädt"
///    (#489).
/// 5. **Bei der Taille ist weniger der Fortschritt** — und die Hüfte ist
///    keine zweite Taille.
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `umfang-detail-<schluessel>` | der Schirm selbst, **mit seinem Maß** |
/// | `umfang-detail-diagramm` | die Diagrammfläche |
/// | `umfang-detail-partner` | der Hinweis auf die blasse Gegenlinie |
/// | `umfang-detail-trend` | die Veränderung zur vorigen Messung, eingefärbt |
/// | `umfang-detail-werte` | „Alle Messungen" dieses Maßes |
/// | `umfang-detail-messhinweis` | die Messanleitung **dieses** Maßes |
/// | `umfang-detail-leer` | „noch nie gemessen" |
/// | `umfang-detail-erste` | „ein Punkt ist noch kein Verlauf" |
/// | `umfang-detail-unlesbar` | „Lesen gescheitert" |
///
/// **`umfang-detail-<schluessel>` trägt den stabilen Schlüssel des Maßes**,
/// nicht einen laufenden Index und nicht den deutschen Namen. Das ist
/// Zusage 1, in einen Schlüssel gegossen: Ein Schirm, der sein Maß nicht
/// kennt, ist der Schirm eines anderen Maßes.
///
/// **`umfang-detail-trend` sitzt auf dem Text der Veränderung**, nicht auf
/// der ganzen Karte — sonst ließe sich „die Taille ist grün, wenn sie
/// fällt" nicht aussprechen, ohne über die Farbe der Überschrift
/// mitzuentscheiden. Dieselbe Begründung wie bei `umfaenge-trend-…` in
/// `umfaenge_uebersicht_test.dart`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Der Weg auf den Schirm läuft über `Körper › Umfänge` und eine
///   Maß-Zeile**, nicht über eine `oeffne…`-Funktion. So legt diese Datei
///   weder Klassennamen noch Konstruktor des Verlaufsschirms fest — und
///   prüft genau den Weg, um den es geht.
/// - **Die Diagrammfläche bleibt in jeder Lage stehen**, auch bei einem
///   einzigen Punkt und bei gar keinem. So steht es im Plan („Verlauf |
///   Diagrammfläche in Grau, `–/–`, Vorlesetext ‚keine Werte'") und so
///   verlangt es `CLAUDE.md` („Eine Anzeige, die es gibt, hat genau eine
///   Form"). **Die Swift-Vorlage macht es anders** — sie ersetzt das
///   Diagramm unter zwei Punkten durch eine `NoteBox`. Gemeldet; hier gilt
///   der Plan, weil er der jüngere und der ausdrücklichere ist.
/// - **Wo die Kennzahlen stehen, ist frei** — in der Karte „Veränderung"
///   wie im Entwurf oder als Kacheln wie in Swift. Geprüft wird nur,
///   **dass** sie dastehen, und zwar gegen die Rechnungen des Kerns
///   (`UmfangsFortschritt`), nicht gegen abgeschriebene Zahlen.
/// - **Der Partner-Hinweis steht nur, wenn der Partner Werte hat.** Eine
///   leere zweite Linie wäre eine Legende ohne Inhalt (Swift-Vorlage,
///   `partnerSeries`).
/// - **Zurück geht es über die Leiste** (`tester.pageBack()`): Ein
///   geschobener Schirm, von dem kein Weg zurückführt, ist eine Sackgasse.
///   In den Schleifen wird dagegen über den Navigator ausgestiegen, damit
///   ein Fehler dort nicht fünfzehnmal als derselbe Fehler erscheint.
///
/// ## Was hier absichtlich **nicht** geprüft wird
///
/// - **Dass die zweite Linie wirklich blass und gestrichelt gezeichnet
///   wird.** Das liegt im `CustomPainter` und wäre nur über einen
///   Pixelvergleich aussprechbar. Geprüft wird stattdessen das, woran der
///   Fehler hängt: Der Partner steht als **eigene** Reihe da und wird
///   nicht in die eigene gekippt — acht Punkte in einer Linie wären eine
///   Kurve, die es nie gab.
/// - **Wortlaut von Überschriften, Hinweisen und Knöpfen**, Farben als
///   Zahlen, Abstände, Schriftgrößen.
/// - **Die Zahlen aus `docs/screens/`.** Sie sind erfunden und wären als
///   Erwartungswert ein Scheinbeweis.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099.
/// Keine Zahl stammt aus `docs/screens/`, keine aus `Exporte/`.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);
  const tag1 = '2099-01-05';
  const tag2 = '2099-01-19';
  const tag3 = '2099-02-02';
  const tag4 = '2099-02-16';

  /// Wonach eine Aussage über Tims Datenlage klingt. Während gelesen wird
  /// und nachdem das Lesen gescheitert ist, darf nichts davon dastehen.
  final leerBehauptung = RegExp(
    r'noch nicht gemessen|noch nie gemessen|noch keine messung|'
    r'noch kein verlauf|erste messung|nichts gemessen|keine werte',
    caseSensitive: false,
  );

  /// Wonach „es läuft noch" klingt. Nach einem gescheiterten Lauf läuft
  /// nichts mehr.
  final ladeBehauptung = RegExp(
    r'wird gelesen|wird geladen|lädt',
    caseSensitive: false,
  );

  final kachel = find.byKey(const Key('koerper-kachel-umfaenge'));
  final uebersicht = find.byKey(const Key('umfaenge-uebersicht'));
  final diagramm = find.byKey(const Key('umfang-detail-diagramm'));
  final partnerHinweis = find.byKey(const Key('umfang-detail-partner'));
  final trend = find.byKey(const Key('umfang-detail-trend'));
  final werte = find.byKey(const Key('umfang-detail-werte'));
  final messhinweis = find.byKey(const Key('umfang-detail-messhinweis'));
  final leer = find.byKey(const Key('umfang-detail-leer'));
  final erste = find.byKey(const Key('umfang-detail-erste'));
  final unlesbar = find.byKey(const Key('umfang-detail-unlesbar'));

  Finder schirm(Umfang mass) =>
      find.byKey(Key('umfang-detail-${mass.schluessel}'));
  Finder massZeile(Umfang mass) =>
      find.byKey(Key('umfaenge-mass-${mass.schluessel}'));

  late AppCache db;
  late GlobalKey<NavigatorState> navigator;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> lege(String tag, Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: tag, werte: werte);

  /// Vier Messtage über sechs Wochen — die realistische Dichte bei „alle
  /// zwei bis vier Wochen".
  ///
  /// **Oberarm rechts und links** wachsen beide, mit verschiedenen Zahlen:
  /// So fällt auf, wenn die Partnerreihe in die eigene Linie gekippt wird.
  /// **Die Taille fällt, Brust und Hüfte steigen** — alle drei sind
  /// Fortschritt. **Der Oberschenkel rechts** hat zwei Punkte und keinen
  /// Partner mit Werten, **der Hals** genau einen, **die Wade links**
  /// keinen.
  Future<void> vierMesstage() async {
    await lege(tag1, {
      Umfang.oberarmRechtsAngespannt: 36.4,
      Umfang.oberarmLinksAngespannt: 35.9,
      Umfang.brust: 101.0,
      Umfang.taille: 86.0,
      Umfang.huefte: 97.0,
    });
    await lege(tag2, {
      Umfang.oberarmRechtsAngespannt: 37.1,
      Umfang.oberarmLinksAngespannt: 36.5,
      Umfang.brust: 101.8,
      Umfang.taille: 85.4,
      Umfang.huefte: 97.4,
    });
    await lege(tag3, {
      Umfang.oberarmRechtsAngespannt: 37.9,
      Umfang.oberarmLinksAngespannt: 37.0,
      Umfang.brust: 102.6,
      Umfang.taille: 84.7,
      Umfang.huefte: 97.9,
      Umfang.oberschenkelRechts: 58.0,
    });
    await lege(tag4, {
      Umfang.oberarmRechtsAngespannt: 38.6,
      Umfang.oberarmLinksAngespannt: 37.8,
      Umfang.brust: 103.5,
      Umfang.taille: 84.0,
      Umfang.huefte: 98.5,
      Umfang.oberschenkelRechts: 58.6,
      Umfang.hals: 39.5,
    });
  }

  /// Die Messungen, wie der Kern sie sieht — für Erwartungswerte, die
  /// gerechnet und nicht abgeschrieben sind.
  Future<List<Umfangsmessung>> ausDerAblage() =>
      UmfaengeRepository(db, uhr: () => jetzt).messungen();

  ProviderContainer behaelter({UmfaengeRepository? repo}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_Quelle()),
        if (repo != null) umfaengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Eine Sekunde in Zehntelschritten — für die Fälle, in denen nichts zur
  /// Ruhe kommen darf: Ein hängendes Lesen brächte `pumpAndSettle` zum
  /// Überlaufen.
  Future<void> pumpe(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> ruhe(WidgetTester tester, {required bool warte}) async {
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      await pumpe(tester);
    }
  }

  /// Der Gastgeber: der Körper-Schirm auf einem Navigator, der jeden Befehl
  /// des [AppRouter] schiebt — wie `RootView` es für den Stapel eines Tabs
  /// tut. Danach steht die Übersicht auf dem Stapel.
  Future<void> zeigeUebersicht(
    WidgetTester tester, {
    UmfaengeRepository? repo,
    bool warte = true,
  }) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    navigator = GlobalKey<NavigatorState>();
    final router = AppRouter();
    void schiebe() {
      final befehl = router.nimmBefehl();
      if (befehl == null) return;
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: befehl.builder),
      );
    }

    router.addListener(schiebe);
    addTearDown(() => router.removeListener(schiebe));

    await tester.pumpWidget(
      BehaelterImBaum(
        container: behaelter(repo: repo),
        child: CupertinoApp(
          navigatorKey: navigator,
          home: CupertinoPageScaffold(child: KoerperView(router: router)),
        ),
      ),
    );
    await ruhe(tester, warte: warte);

    await tester.ensureVisible(kachel);
    await ruhe(tester, warte: warte);
    await tester.tap(kachel);
    await ruhe(tester, warte: warte);

    expect(
      uebersicht,
      findsOneWidget,
      reason: 'Körper › Umfänge führt auf die Übersicht (Plan, Task 2.4).',
    );
  }

  /// Von der Übersicht aus das Maß antippen — der Weg, um den es geht.
  Future<void> oeffne(
    WidgetTester tester,
    Umfang mass, {
    bool warte = true,
  }) async {
    final zeile = massZeile(mass);
    expect(
      zeile,
      findsOneWidget,
      reason:
          '${mass.schluessel}: Alle fünfzehn Zeilen stehen in jeder Lage da '
          '(`umfaenge_uebersicht_test.dart`).',
    );
    await tester.ensureVisible(zeile);
    await ruhe(tester, warte: warte);
    await tester.tap(zeile);
    await ruhe(tester, warte: warte);

    // **Hier und nicht erst im Fall.** Ohne diese Zusicherung bestünde
    // jeder Fall, der ein Fehlen prüft („der Partner-Hinweis steht nicht
    // da"), auch dann, wenn der Schirm gar nicht aufgegangen ist — ein
    // Test, der nichts gesehen hat und zufrieden ist.
    expect(
      schirm(mass),
      findsOneWidget,
      reason:
          '${mass.schluessel}: Die Zeile öffnet den Verlauf **ihres** Maßes '
          '(#479). Geöffnet hat sie: '
          '${Umfang.values.where((m) => schirm(m).evaluate().isNotEmpty).map((m) => m.schluessel)}',
    );
  }

  /// Der ganze Weg in einem: Übersicht zeigen, Maß öffnen.
  Future<void> zeigeVerlauf(
    WidgetTester tester,
    Umfang mass, {
    UmfaengeRepository? repo,
    bool warte = true,
  }) async {
    await zeigeUebersicht(tester, repo: repo, warte: warte);
    await oeffne(tester, mass, warte: warte);
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  String textUnter(WidgetTester tester, Finder wurzel) => tester
      .widgetList<Text>(
        find.descendant(
          of: wurzel,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Das Diagramm des Verlaufsschirms — als Widget, nicht als Pixel.
  Zeitdiagramm diagrammVon(WidgetTester tester, Umfang mass) =>
      tester.widget<Zeitdiagramm>(
        find.descendant(of: schirm(mass), matching: find.byType(Zeitdiagramm)),
      );

  /// Die gerenderte Farbe der Veränderungszeile.
  Color? trendFarbe(WidgetTester tester) => tester
      .widget<RichText>(
        find
            .descendant(
              of: trend,
              matching: find.byType(RichText),
              matchRoot: true,
            )
            .first,
      )
      .text
      .style
      ?.color;

  /// Eine Zahl, wie sie auf dem Schirm steht — ohne Vorzeichen, damit kein
  /// Fall an „−" gegen „-" hängt.
  String zahl(double wert) => formatNumber(wert.abs(), nachkommastellen: 1);

  // ───────────────────────────────────────────────────────────────────────
  // Jede Zeile trägt ihr Maß mit
  // ───────────────────────────────────────────────────────────────────────

  group('Jede Maß-Zeile öffnet den Verlauf **ihres** Maßes', () {
    testWidgets('alle fünfzehn führen auf ihren eigenen Schirm', (
      tester,
    ) async {
      // Der Fehler, gegen den das geschrieben ist: Alle Zeilen öffnen
      // denselben Schirm — zum Beispiel immer den des ersten Maßes. Das
      // sieht man dem Schirm nicht an, wenn man nur eine Zeile antippt.
      await vierMesstage();
      await zeigeUebersicht(tester);

      for (final mass in Umfang.values) {
        await oeffne(tester, mass);

        expect(
          schirm(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel}: „Jede Zeile führt hierher und trägt mit, '
              'welches Maß gemeint ist — sonst öffnete jede Zeile denselben '
              'Schirm" (`umfang-detail.js`, Kopf)',
        );
        for (final anderes in Umfang.values) {
          if (anderes == mass) continue;
          expect(
            schirm(anderes),
            findsNothing,
            reason:
                '${mass.schluessel} angetippt, ${anderes.schluessel} '
                'geöffnet',
          );
        }

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('und der Schirm nennt die Messanleitung dieses Maßes', (
      tester,
    ) async {
      await vierMesstage();
      await zeigeUebersicht(tester);

      final gesehen = <Umfang, String>{};
      for (final mass in [
        Umfang.oberarmRechtsAngespannt,
        Umfang.oberarmLinksAngespannt,
        Umfang.taille,
        Umfang.wadeLinks,
      ]) {
        await oeffne(tester, mass);

        expect(messhinweis, findsOneWidget, reason: mass.schluessel);
        expect(
          textUnter(tester, messhinweis),
          contains(mass.messhinweis),
          reason:
              '${mass.schluessel}: „Hier gehört er hin und nicht in einen '
              'Sammelabsatz, den man beim Messen nicht liest" (Spec, '
              'Detailschirm Punkt 5). Rechts und links unterscheiden sich '
              'gerade darin, welches Bein belastet ist',
        );
        gesehen[mass] = textUnter(tester, messhinweis);

        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }

      expect(
        gesehen.values.toSet(),
        hasLength(gesehen.length),
        reason: 'Je Maß ein eigener Satz, nicht viermal derselbe',
      );
    });

    testWidgets('die Zeile trägt jetzt einen Winkel — der Winkel folgt der '
        'Tür', (tester) async {
      await vierMesstage();
      await zeigeUebersicht(tester);

      for (final mass in Umfang.values) {
        expect(
          find.descendant(
            of: massZeile(mass),
            matching: find.byIcon(CupertinoIcons.chevron_right),
          ),
          findsOneWidget,
          reason:
              '${mass.schluessel}: Seit Scheibe 3 führt die Zeile wirklich '
              'irgendwohin. Tims Regel vom 27.10.2026 gilt in beide '
              'Richtungen — ohne Winkel sieht die Tür aus wie reine '
              'Anzeige',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Diagramm: Stufen, eigene Reihe, Lücken
  // ───────────────────────────────────────────────────────────────────────

  group('Das Diagramm', () {
    testWidgets('bietet M, 6M und J an — und keine Stufe „Alles"', (
      tester,
    ) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberarmRechtsAngespannt);

      final stufen = diagrammVon(tester, Umfang.oberarmRechtsAngespannt).stufen;
      expect(
        stufen,
        const [DiagrammStufe.monat, DiagrammStufe.halbjahr, DiagrammStufe.jahr],
        reason:
            'Tim am 26.10.2026: Es bleibt bei den fünf Stufen, eine sechste '
            '„Alles" ginge quer durch alle neun Diagramme. Am Maßband misst '
            'man alle zwei bis vier Wochen — T und W zeigten leere Fenster',
      );
      expect(
        startStufe(stufen),
        DiagrammStufe.monat,
        reason: 'Die Startstufe ist die kleinste angebotene (#7)',
      );
    });

    testWidgets('trägt die Punkte dieses Maßes — und nur sie', (tester) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberarmRechtsAngespannt);

      final reihe = diagrammVon(tester, Umfang.oberarmRechtsAngespannt).reihe;
      expect(
        reihe.map((punkt) => punkt.wert).toSet(),
        {36.4, 37.1, 37.9, 38.6},
        reason: 'die vier Messungen von Oberarm rechts, angespannt',
      );
      expect(
        reihe,
        hasLength(4),
        reason:
            'Der Partner gehört als **zweite** Reihe ins Diagramm, nicht in '
            'diese. Acht Punkte in einer Linie wären eine Kurve, die es nie '
            'gab — links und rechts abwechselnd',
      );
    });

    testWidgets('Lücken bleiben Lücken: ein Tag ohne dieses Maß ist kein '
        'Punkt', (tester) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberschenkelRechts);

      final reihe = diagrammVon(tester, Umfang.oberschenkelRechts).reihe;
      expect(
        reihe,
        hasLength(2),
        reason:
            'Vier Messtage, aber der Oberschenkel wurde nur an zweien '
            'gemessen. „Ein Tag, an dem nur die Taille nachgemessen wurde, '
            'ist für den Oberschenkel keine Messung" '
            '(`umfangs_fortschritt.dart`)',
      );
      expect(
        reihe.map((punkt) => punkt.wert),
        isNot(contains(0.0)),
        reason:
            'Eine Lücke wird nicht mit `0` gefüllt — ein Umfang von null '
            'Zentimetern wäre eine Behauptung (`CLAUDE.md`)',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Gegenseite
  // ───────────────────────────────────────────────────────────────────────

  group('Die Gegenseite liegt als zweite Linie daneben', () {
    testWidgets('bei einem Maß mit Partner steht sie da', (tester) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberarmRechtsAngespannt);

      expect(
        partnerHinweis,
        findsOneWidget,
        reason:
            '„Die Seitendifferenz ist die Zahl, die man sonst im Kopf '
            'ausrechnet" (Swift-Vorlage, Zeilen 4–10). Im Entwurf fehlt sie '
            '— das ist eine Lücke im Entwurf, kein Verzicht (#479)',
      );
      expect(
        textUnter(tester, partnerHinweis),
        contains(Umfang.oberarmLinksAngespannt.deutsch),
        reason:
            'Der Hinweis nennt, welche Gegenseite gemeint ist. Locker und '
            'angespannt desselben Arms sind kein Paar (`umfang.dart`)',
      );
    });

    testWidgets('ein Maß ohne Partner zeigt eine Linie — und sieht sonst '
        'nicht anders aus', (tester) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.brust);

      expect(
        partnerHinweis,
        findsNothing,
        reason:
            'Brust, Schultern, Taille, Hals und Hüfte gibt es nur einmal am '
            'Körper (`umfang.dart`, `partner`)',
      );
      for (final teil in [diagramm, trend, werte, messhinweis]) {
        expect(
          teil,
          findsOneWidget,
          reason:
              'Alles übrige steht genauso da wie bei einem Maß mit Partner '
              '— „Eine Anzeige, die es gibt, hat genau eine Form"',
        );
      }
    });

    testWidgets('und ohne Werte auf der Gegenseite bleibt sie weg', (
      tester,
    ) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberschenkelRechts);

      expect(
        Umfang.oberschenkelRechts.partner,
        Umfang.oberschenkelLinks,
        reason: 'Vorbedingung: Der Oberschenkel hat ein Gegenstück',
      );
      expect(
        partnerHinweis,
        findsNothing,
        reason:
            'Der linke Oberschenkel ist nie gemessen worden. Eine leere '
            'zweite Linie wäre eine Legende ohne Inhalt (Swift-Vorlage, '
            '`partnerSeries`)',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Kennzahlen kommen aus dem Kern
  // ───────────────────────────────────────────────────────────────────────

  group('Veränderung, seit Start, pro Monat und Spanne', () {
    testWidgets('stehen da, und zwar so, wie der Kern sie rechnet', (
      tester,
    ) async {
      await vierMesstage();
      final messungen = await ausDerAblage();
      const mass = Umfang.oberarmRechtsAngespannt;

      final veraenderung = UmfangsFortschritt.veraenderung(mass, messungen)!;
      final seitStart = UmfangsFortschritt.seitStart(mass, messungen)!;
      final proMonat = UmfangsFortschritt.proMonat(mass, messungen)!;
      final spanne = UmfangsFortschritt.spanne(mass, messungen)!;

      await zeigeVerlauf(tester, mass);
      final texte = alleTexte(tester);

      expect(
        textUnter(tester, trend),
        contains(zahl(veraenderung.delta)),
        reason: 'Veränderung zur vorigen Messung (Spec, Detailschirm Punkt 1)',
      );
      expect(
        texte,
        contains(zahl(seitStart)),
        reason: 'Veränderung seit der ersten Messung (ebenda)',
      );
      expect(
        texte,
        contains(zahl(proMonat)),
        reason:
            'Pro Monat, nicht pro Woche — „in einer Woche bewegt sich am '
            'Maßband nichts Messbares" (Spec, Detailschirm Punkt 3)',
      );
      expect(
        texte,
        contains(zahl(spanne.$1)),
        reason: 'kleinster Wert (ebenda)',
      );
      expect(
        texte,
        contains(zahl(spanne.$2)),
        reason: 'größter Wert (ebenda)',
      );
    });

    testWidgets('„Alle Messungen" listet jede Messung dieses Maßes', (
      tester,
    ) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.oberarmRechtsAngespannt);

      final liste = textUnter(tester, werte);
      for (final wert in [36.4, 37.1, 37.9, 38.6]) {
        expect(
          liste,
          contains(zahl(wert)),
          reason:
              '$wert fehlt. „Alle Werte dieses Maßes als Liste, neueste '
              'zuerst" (Spec, Detailschirm Punkt 4)',
        );
      }
      expect(
        liste,
        isNot(contains(zahl(35.9))),
        reason:
            'Die Liste gehört diesem Maß. Der Wert der Gegenseite steht im '
            'Diagramm, nicht zwischen den eigenen Messungen',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ein Punkt ist kein Verlauf — und nie gemessen ist etwas anderes
  // ───────────────────────────────────────────────────────────────────────

  group('Noch nie gemessen und erst einmal gemessen', () {
    testWidgets('sind zwei verschiedene Texte', (tester) async {
      await vierMesstage();

      await zeigeVerlauf(tester, Umfang.wadeLinks);
      expect(
        leer,
        findsOneWidget,
        reason:
            '„Dieses Maß ist noch nie gemessen worden" — die Wade links '
            'steht in keiner der vier Messungen',
      );
      expect(erste, findsNothing);
      final nieGemessen = alleTexte(tester);

      await zeigeVerlauf(tester, Umfang.hals);
      expect(
        erste,
        findsOneWidget,
        reason:
            '„Ein Punkt ist noch kein Verlauf. Ab der zweiten Messung steht '
            'hier ein Diagramm" — der Hals ist genau einmal gemessen '
            '(Spec, „Erste Messung und leere Zustände")',
      );
      expect(leer, findsNothing);

      expect(
        alleTexte(tester),
        isNot(nieGemessen),
        reason:
            '„Noch nie gemessen" ist etwas anderes als „erst einmal '
            'gemessen" — zwei verschiedene Texte (Plan, Scheibe 3)',
      );
    });

    testWidgets('die Diagrammfläche bleibt in beiden Fällen stehen', (
      tester,
    ) async {
      await vierMesstage();

      for (final mass in [Umfang.wadeLinks, Umfang.hals]) {
        await zeigeVerlauf(tester, mass);

        expect(
          diagramm,
          findsOneWidget,
          reason:
              '${mass.schluessel}: „Das Diagramm wird nicht weggelassen, '
              'sein Platz wird erklärt" (Spec) — und der Plan nennt für den '
              'Verlauf ausdrücklich „Diagrammfläche in Grau, –/–"',
        );
        for (final teil in [trend, werte, messhinweis]) {
          expect(teil, findsOneWidget, reason: mass.schluessel);
        }
      }
    });

    testWidgets('mit einem Punkt steht keine Null als Veränderung da', (
      tester,
    ) async {
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.hals);

      final text = textUnter(tester, trend).toLowerCase();
      expect(
        text,
        isNot(contains('unverändert')),
        reason:
            '„Unverändert" behauptete einen Vergleich, den es nicht gab '
            '(`UmfangsFortschritt.veraenderung` gibt hier `null`)',
      );
      expect(
        RegExp(r'0,0').hasMatch(text),
        isFalse,
        reason:
            '„Erste Messung" ist kein „±0,0". Die Veränderung gibt es, ihr '
            'fehlt nur der zweite Punkt',
      );
    });

    testWidgets('der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
    ) async {
      // **Kein eigenes `tester.ensureSemantics()`** — `testWidgets`
      // schaltet die Semantik selbst ein und zählt offene Handles am Ende
      // des Testrumpfs, also vor den `addTearDown`-Rückrufen. Ein über
      // `addTearDown` aufgeräumtes Handle lässt den Fall scheitern, ohne
      // dass eine Zusicherung fehlschlägt (`heute_view_test.dart:867`).
      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.wadeLinks);

      final beschriftung = tester.getSemantics(diagramm).label.toLowerCase();
      expect(
        beschriftung,
        contains('keine'),
        reason:
            'Der Vorlesetext nennt den Zustand in Worten (`CLAUDE.md`, '
            '„Der Vorlesetext nennt den Zustand, nicht das Zeichen"). '
            'Gefunden: „$beschriftung"',
      );
      expect(
        beschriftung,
        isNot(contains('–')),
        reason:
            '„–/–" ergibt vorgelesen „Strich Schrägstrich Strich". '
            'Gefunden: „$beschriftung"',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Drei Lagen, drei unterscheidbare Auskünfte (#489)
  // ───────────────────────────────────────────────────────────────────────

  group('Lädt, unlesbar und gelesen', () {
    testWidgets('während des Lesens behauptet nichts etwas über Tims Daten', (
      tester,
    ) async {
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeVerlauf(
        tester,
        Umfang.taille,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );

      expect(
        schirm(Umfang.taille),
        findsOneWidget,
        reason:
            'Die Zeile ist in jeder Lage eine Tür — auch während gelesen '
            'wird',
      );
      final texte = alleTexte(tester);
      expect(
        leerBehauptung.hasMatch(texte),
        isFalse,
        reason:
            'Ob dieses Maß je gemessen wurde, weiß die App jetzt nicht. '
            'Genau das war `01`. Gefunden in: „$texte"',
      );
      expect(leer, findsNothing);
      expect(erste, findsNothing);
      expect(unlesbar, findsNothing);

      antwort.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('ist der Lauf durch, darf die Auskunft kommen', (
      tester,
    ) async {
      // Die Gegenprobe: Der Fall oben darf sich nicht dadurch erledigen
      // lassen, dass die Auskunft ganz verschwindet.
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeVerlauf(
        tester,
        Umfang.taille,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );
      antwort.complete(const []);
      await tester.pumpAndSettle();

      expect(
        leer,
        findsOneWidget,
        reason:
            'Jetzt ist bekannt, dass dieses Maß nie gemessen wurde — und '
            'jetzt gehört es auch dagestanden',
      );
    });

    testWidgets('ein gescheitertes Lesen benennt sich', (tester) async {
      await zeigeVerlauf(tester, Umfang.taille, repo: _KaputtesRepo(db));

      expect(
        unlesbar,
        findsOneWidget,
        reason:
            'Der sealed-Zustand hat drei Fälle. Wird der dritte mit '
            '`is … ? … : null` eingeebnet, trägt er nichts mehr — in dieser '
            'Scheibe war das schon zweimal das Loch (#489)',
      );

      final texte = alleTexte(tester);
      expect(
        ladeBehauptung.hasMatch(texte),
        isFalse,
        reason:
            'Ein gescheitertes Lesen läuft nicht mehr. „Wird gelesen …" '
            'stünde dort für immer. Gefunden in: „$texte"',
      );
      expect(
        leerBehauptung.hasMatch(texte),
        isFalse,
        reason:
            '„Keine Daten" und „nicht lesbar" sind zwei verschiedene '
            'Auskünfte. Gefunden in: „$texte"',
      );
      expect(leer, findsNothing);
      expect(erste, findsNothing);
    });

    testWidgets('und die drei Auskünfte unterscheiden sich', (tester) async {
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeVerlauf(
        tester,
        Umfang.taille,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );
      final beimLaden = alleTexte(tester);
      antwort.complete(const []);
      await tester.pumpAndSettle();

      await zeigeVerlauf(tester, Umfang.taille, repo: _KaputtesRepo(db));
      final beimFehler = alleTexte(tester);

      await vierMesstage();
      await zeigeVerlauf(tester, Umfang.taille);
      final mitWerten = alleTexte(tester);

      expect(beimFehler, isNot(beimLaden));
      expect(beimFehler, isNot(mitWerten));
      expect(beimLaden, isNot(mitWerten));
    });

    testWidgets('die Geometrie bleibt in jeder Lage dieselbe', (tester) async {
      await zeigeVerlauf(tester, Umfang.taille, repo: _KaputtesRepo(db));

      for (final teil in [diagramm, trend, werte, messhinweis]) {
        expect(
          teil,
          findsOneWidget,
          reason:
              'Dass die Tabelle sich nicht lesen ließ, nimmt dem Schirm '
              'keine Anzeige weg — nur ihre Füllung (`CLAUDE.md`)',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Keine Diagnose
  // ───────────────────────────────────────────────────────────────────────

  testWidgets('der Maßband-Hinweis steht auf dem Schirm', (tester) async {
    await vierMesstage();
    await zeigeVerlauf(tester, Umfang.taille);

    expect(
      alleTexte(tester).toLowerCase(),
      contains('maßband'),
      reason:
          '„Keine Diagnose" (`CLAUDE.md`): Ein halber Zentimeter kann auch '
          'an der Stelle oder der Spannung des Maßbands liegen — erst der '
          'Verlauf über mehrere Messungen sagt etwas',
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ein Vorzeichen allein färbt nichts ein
  // ───────────────────────────────────────────────────────────────────────

  group('Bei der Taille ist weniger der Fortschritt', () {
    testWidgets('fallende Taille und steigende Brust sind beides '
        'Fortschritt', (tester) async {
      await vierMesstage();

      await zeigeVerlauf(tester, Umfang.taille);
      final taille = trendFarbe(tester);

      await zeigeVerlauf(tester, Umfang.brust);
      final brust = trendFarbe(tester);

      expect(
        taille,
        brust,
        reason:
            'Die Taille fällt um 0,7 cm, die Brust steigt um 0,9 cm — '
            'beides ist Fortschritt. Wer nach `delta > 0` färbt, malt Tims '
            'bestes Ergebnis rot an (`wenigerIstBesser`)',
      );
    });

    testWidgets('und die Hüfte zählt nicht zur Taille', (tester) async {
      await vierMesstage();

      await zeigeVerlauf(tester, Umfang.huefte);
      final huefte = trendFarbe(tester);

      await zeigeVerlauf(tester, Umfang.brust);
      final brust = trendFarbe(tester);

      expect(
        Umfang.huefte.wenigerIstBesser,
        isFalse,
        reason:
            'Vorbedingung: Die Hüfte misst mit, was am Gesäß aufgebaut wird '
            '(`umfang.dart`)',
      );
      expect(
        huefte,
        brust,
        reason:
            'Beide wachsen, beide sind Fortschritt. Die Hüfte als zweite '
            'Taille zu behandeln färbte Aufbau als Rückschritt — sie ist '
            'das Maß, bei dem „weniger ist besser" leicht einmal zu breit '
            'eingebaut wird',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Zurück (`32`)
  // ───────────────────────────────────────────────────────────────────────

  testWidgets('ein Wert, der dastand, steht nach dem Zurücknavigieren wieder '
      'da', (tester) async {
    await vierMesstage();
    await zeigeVerlauf(tester, Umfang.taille);

    expect(
      diagrammVon(tester, Umfang.taille).reihe,
      hasLength(4),
      reason: 'Vorbedingung: Der Verlauf steht da',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      uebersicht,
      findsOneWidget,
      reason:
          'Der geschobene Schirm hat einen Weg zurück — ohne ihn wäre er '
          'eine Sackgasse',
    );
    expect(
      alleTexte(tester),
      contains(zahl(84.0)),
      reason:
          'Die Übersicht zeigt den Wert der Taille wieder, ohne einen '
          'zweiten Lauf abzuwarten (`32`)',
    );

    await oeffne(tester, Umfang.taille);
    expect(
      diagrammVon(tester, Umfang.taille).reihe,
      hasLength(4),
      reason:
          'Und beim zweiten Öffnen steht der Verlauf wieder da — nicht erst '
          'ein Ladezustand, der schon einmal durch war',
    );
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt — die
/// Lage „lädt".
class _HaengendesRepo extends UmfaengeRepository {
  _HaengendesRepo(super.db, this.antwort);

  final Completer<List<Umfangsmessung>> antwort;

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) =>
      antwort.future;

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Ein Repository, dessen Lesen scheitert — die Lage „unlesbar".
class _KaputtesRepo extends UmfaengeRepository {
  _KaputtesRepo(super.db);

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) =>
      Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Eine Quelle mit erfundenen Tageswerten, damit der Körper-Schirm nicht im
/// Ladezustand stehen bleibt. Die Umfänge kommen nicht von hier, sondern
/// aus der Tabelle.
class _Quelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => [
    DailyMetrics(tag: '2099-02-15', steps: 7200, weightKg: 77.3),
    DailyMetrics(tag: '2099-02-16', steps: 410),
  ];
}
