import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/icon_row.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/mess_abschnitte.dart'
    show datumZumAnzeigen;
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Die **drei Türen** zum Schirm „Umfänge messen" (#477 unter #88,
/// Scheibe 2): `Mehr › Umfänge messen`, die Umfänge-Kachel und die
/// Umfänge-Zeile auf dem Körper-Schirm. Bis hierher führten alle drei auf
/// einen Platzhaltertext.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// `docs/superpowers/plans/2026-11-11-umfaenge.md`, Task 2.3: „Die
/// Platzhaltertexte fliegen raus. Sprünge über `AppRouter`, geschoben auf
/// den Stapel des Tabs, in dem man gerade ist."
///
/// ## Die beiden Türen führen verschieden weit
///
/// - **`Körper › Umfänge`** — Kachel und Zeile — öffnet die **Übersicht**.
///   Wer dort nachsieht, will wissen, wie es steht.
/// - **`Mehr › Umfänge messen`** öffnet unmittelbar das **Formular**. Wer
///   das wählt, hat das Maßband in der Hand und will nicht erst eine
///   Übersicht durchqueren.
///
/// So steht es seit dem 11.11.2026 im Plan
/// (`docs/superpowers/plans/2026-11-11-umfaenge.md`, Task 2.4) und im
/// Entwurf (`umfaenge.js`, `umfaenge-eintragen.js`).
///
/// **Die Umfänge-Kachel auf dem Körper-Schirm zeigt das Datum der jüngsten
/// Messung**, keinen Zählerstand. Bis hierher stand dort fest „noch keine
/// Messung eingetragen" — ein Satz, der falsch wird, sobald Tim zum ersten
/// Mal misst. Ein Zählerstand („15 Maße") wäre dagegen eine Zahl über den
/// Katalog und nicht über seine Daten. Liegt keine Messung vor, bleibt die
/// Kachel ungefüllt und sagt das; sie verschwindet nicht (`CLAUDE.md`,
/// „Eine Anzeige, die es gibt, hat genau eine Form"). **Das ist die
/// Festlegung des Test-Agenten, Tim hat sie nicht gesehen.**
///
/// ## Nachtrag (11.11.2026): von „beide ins Formular" auf „zwei Ziele"
///
/// Die erste Fassung dieser Datei ließ **alle** Türen unmittelbar das
/// Formular öffnen, weil es die Übersicht noch nicht gab. Das hat sich
/// erledigt: Tim am 11.11.2026 — „ich muss irgendwo gespeicherte
/// Datensätze andrücken und bearbeiten können" — zieht die Übersicht in
/// Scheibe 2 vor, und ohne sie gäbe es keinen Ort, an dem Messungen als
/// Liste stehen. **Die Türentscheidung hat Tim gesehen; diese Testfassung
/// nicht.**
///
/// Gedreht sind damit die drei Körper-Fälle: Sie erwarten jetzt
/// `umfaenge-uebersicht` statt `umfaenge-eintragen`. Die beiden Mehr-Fälle
/// bleiben, wie sie waren.
///
/// ## Was hier geprüft wird — und was nicht
///
/// Geprüft wird, **wohin** die Türen führen und **wie** sie schieben (auf
/// den Stapel des aktuellen Tabs, nicht in einen fremden). Was die beiden
/// Schirme dann tun, prüfen `umfaenge_eintragen_test.dart` und
/// `umfaenge_uebersicht_test.dart`; dort stehen auch ihre Schlüssel. Diese
/// Datei kennt davon zwei: `umfaenge-eintragen` und `umfaenge-uebersicht`,
/// die Schirme selbst.
///
/// Nicht geprüft werden Symbol, Akzentfarbe und der Wortlaut der
/// Untertitel.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099.
void main() {
  final jetzt = DateTime.utc(2099, 3, 15, 11);
  const vorwoche = '2099-03-08';

  final formular = find.byKey(const Key('umfaenge-eintragen'));
  final uebersicht = find.byKey(const Key('umfaenge-uebersicht'));
  final kachel = find.byKey(const Key('koerper-kachel-umfaenge'));
  final koerperZeile = find.byKey(const Key('koerper-bereich-umfaenge'));

  /// Das Muster eines angezeigten Datums („08.03." oder „08.03.2099").
  final datumsMuster = RegExp(r'\b\d{2}\.\d{2}\.');

  late AppCache db;

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

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_Quelle()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> grosseFlaeche(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Zeigt [kind] mit einem Behälter und gibt den Router zurück, der dabei
  /// benutzt wurde. [tab] ist der Reiter, in dem der Nutzer gerade steckt.
  Future<AppRouter> zeige(
    WidgetTester tester,
    Widget Function(AppRouter router) kind, {
    Tab tab = Tab.heute,
  }) async {
    await grosseFlaeche(tester);

    final router = AppRouter();
    // Ein reiner Tab-Wechsel trägt keinen Baubefehl, hinterlässt also
    // nichts, was `nimmBefehl()` später fälschlich zurückgäbe.
    router.open(switch (tab) {
      Tab.heute => AppTarget.heute(),
      Tab.ernaehrung => AppTarget.ernaehrung(),
      Tab.gym => AppTarget.gym(),
      Tab.mehr => AppTarget.mehr(),
    });
    expect(router.nimmBefehl(), isNull, reason: 'Vorbedingung: nichts offen.');
    expect(router.tab, tab);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: behaelter(),
        child: CupertinoApp(home: kind(router)),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    expect(ziel, findsOneWidget);
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  /// Baut, was der Befehl beschreibt, und prüft, dass es [ziel] ist.
  Future<void> erwarteSchirm(
    WidgetTester tester,
    AppRouterBefehl? befehl, {
    required Tab imTab,
    required Finder ziel,
  }) async {
    expect(befehl, isNotNull, reason: 'Die Tür muss irgendwohin führen.');
    expect(
      befehl!.ersetztStapel,
      isFalse,
      reason:
          'Geschoben (`AppTarget.aktuell`), nicht ersetzt — sonst fiele der '
          'Weg zurück weg, den der Nutzer gekommen ist',
    );
    expect(
      befehl.tab,
      imTab,
      reason:
          'Der Schirm wird auf den Stapel des Tabs geschoben, in dem man '
          'gerade ist — nicht in den Tab, unter dem er im Menü einsortiert '
          'ist. Sonst führt „zurück" in ein Menü, das der Nutzer nie '
          'geöffnet hat (`CLAUDE.md`)',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: behaelter(),
        child: CupertinoApp(home: Builder(builder: befehl.builder)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      ziel,
      findsOneWidget,
      reason:
          'Die Tür führt auf ihren Schirm, nicht mehr auf einen '
          'Platzhaltertext (Plan, Task 2.4)',
    );
    expect(
      find.textContaining('noch nicht gebaut'),
      findsNothing,
      reason: 'Der Platzhaltertext ist weg.',
    );
    expect(
      find.byType(Navigator),
      findsOneWidget,
      reason:
          'Ein geschobener Schirm bringt keinen eigenen Navigator mit '
          '(`CLAUDE.md`)',
    );
  }

  String textUnter(WidgetTester tester, Finder wurzel) => tester
      .widgetList<Text>(
        find.descendant(of: wurzel, matching: find.byType(Text), matchRoot: true),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  // ───────────────────────────────────────────────────────────────────────

  group('Mehr › Umfänge messen', () {
    testWidgets('die Zeile ist aktiv und nicht mehr abgeblendet', (
      tester,
    ) async {
      await zeige(tester, (router) => MehrView(router: router));

      final zeile = find.widgetWithText(IconRow, 'Umfänge messen');
      expect(
        tester.widget<IconRow>(zeile).onTap,
        isNotNull,
        reason: 'Die Zeile führt jetzt irgendwohin (Plan, Task 2.3).',
      );

      final opazitaet = tester
          .widgetList<Opacity>(
            find.ancestor(of: zeile, matching: find.byType(Opacity)),
          )
          .fold<double>(1, (bisher, o) => bisher * o.opacity);
      expect(
        opazitaet,
        1.0,
        reason:
            'Abgeblendet heißt „gibt es noch nicht" — das stimmt nicht mehr',
      );
      expect(
        textUnter(tester, zeile),
        isNot(contains('folgt in einer späteren Aufgabe')),
        reason: 'Die Ankündigung ist eingelöst.',
      );
    });

    testWidgets('und schiebt auf den Stapel des Tabs, in dem man gerade '
        'ist', (tester) async {
      // Der Nutzer steckt im Gym-Tab und ruft das Menü von dort auf.
      final router = await zeige(
        tester,
        (router) => MehrView(router: router),
        tab: Tab.gym,
      );

      await tippe(tester, find.widgetWithText(IconRow, 'Umfänge messen'));

      expect(
        router.tab,
        Tab.gym,
        reason: 'Ein Menüpunkt wechselt nie den Tab (`CLAUDE.md`).',
      );
      await erwarteSchirm(
        tester,
        router.nimmBefehl(),
        imTab: Tab.gym,
        ziel: formular,
      );
      expect(
        uebersicht,
        findsNothing,
        reason:
            'Wer „Umfänge messen" wählt, hat das Maßband in der Hand — eine '
            'Übersicht dazwischen wäre ein Umweg (Plan, Task 2.4)',
      );
    });
  });

  group('Körper › Umfänge', () {
    testWidgets('die Kachel führt auf die Übersicht', (tester) async {
      final router = await zeige(
        tester,
        (router) => KoerperView(router: router),
        tab: Tab.mehr,
      );

      await tippe(tester, kachel);
      await erwarteSchirm(
        tester,
        router.nimmBefehl(),
        imTab: Tab.mehr,
        ziel: uebersicht,
      );
      expect(
        formular,
        findsNothing,
        reason:
            'Wer auf Körper nachsieht, will wissen, wie es steht — nicht '
            'sofort fünfzehn leere Felder (Plan, Task 2.4)',
      );
    });

    testWidgets('die Zeile „Umfänge" ebenfalls', (tester) async {
      final router = await zeige(
        tester,
        (router) => KoerperView(router: router),
        tab: Tab.mehr,
      );

      await tippe(tester, koerperZeile);
      await erwarteSchirm(
        tester,
        router.nimmBefehl(),
        imTab: Tab.mehr,
        ziel: uebersicht,
      );
    });

    testWidgets('und beide bleiben im Tab, aus dem heraus geöffnet wurde', (
      tester,
    ) async {
      // Körper ist im Mehr-Menü einsortiert, erreichbar ist er aus jedem
      // Tab — ein Sprung nach „Mehr" führte zurück in ein Menü, das der
      // Nutzer nie geöffnet hat.
      final router = await zeige(
        tester,
        (router) => KoerperView(router: router),
        tab: Tab.ernaehrung,
      );

      await tippe(tester, kachel);
      expect(router.tab, Tab.ernaehrung);
      await erwarteSchirm(
        tester,
        router.nimmBefehl(),
        imTab: Tab.ernaehrung,
        ziel: uebersicht,
      );
    });
  });

  group('Die Umfänge-Kachel sagt, wann zuletzt gemessen wurde', () {
    testWidgets('ohne Messung steht dort kein Datum und keine Zahl', (
      tester,
    ) async {
      await zeige(tester, (router) => KoerperView(router: router));

      final text = textUnter(tester, kachel);
      expect(
        datumsMuster.hasMatch(text),
        isFalse,
        reason:
            'Es gibt keine Messung — ein Datum hier wäre erfunden. '
            'Gefunden: „$text"',
      );
      expect(
        text.toLowerCase(),
        contains('keine'),
        reason:
            'Leer heißt leer, und die Kachel sagt es, statt zu '
            'verschwinden. Gefunden: „$text"',
      );
      expect(
        kachel,
        findsOneWidget,
        reason:
            'Dieselbe Form wie mit Wert: Eine Kachel, die ohne Daten '
            'wegfällt, lässt die übrigen den Platz neu aufteilen',
      );
    });

    testWidgets('mit Messung steht ihr Tag da, über den gemeinsamen '
        'Formatierer', (tester) async {
      await lege(vorwoche, {Umfang.taille: 84.0, Umfang.brust: 103.5});
      await zeige(tester, (router) => KoerperView(router: router));

      final text = textUnter(tester, kachel);
      expect(
        text,
        contains(Format.tagMonat(datumZumAnzeigen(vorwoche))),
        reason:
            'Der Tag der jüngsten Messung, und zwar über `Format` — '
            '`DateTime.formatted` nähme die Sprache des Geräts '
            '(`CLAUDE.md`). Gefunden: „$text"',
      );
      expect(
        text,
        isNot(contains('15')),
        reason:
            'Kein Zählerstand: „15 Maße" ist eine Zahl über den Katalog, '
            'nicht über Tims Daten. Gefunden: „$text"',
      );
    });
  });
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
    DailyMetrics(tag: '2099-03-14', steps: 7200, weightKg: 77.3),
    DailyMetrics(tag: '2099-03-15', steps: 410),
  ];
}
