// Widget-Tests für den Schritte-Schirm (#84, Umgestaltung #15) — Zustände
// und Übergänge, nicht Layout und Beschriftung (`CLAUDE.md`, „Tests").
//
// **Wer Tests schreibt, schreibt nicht die Implementierung.** Diese Datei
// entstand vor dem Schirm, aus dem Entwurf `docs/screens/screens/schritte.js`
// (Commit fd43877), der Schirm-Karte #84 und `docs/SPEC.md` 4.6. Die
// Implementierung darf sie ausführen, aber nicht verändern.
//
// ## Was diese Datei verbindlich vorgibt
//
// - `lib/koerper/schritte_view.dart` mit `SchritteSeite` (Gerüst + Leiste
//   „Schritte"), `SchritteView` (ohne Gerüst, besorgt seine Daten selbst)
//   und `oeffneSchritte(AppRouter)` — derselbe Schnitt wie beim Verlauf je
//   Maß (#479).
// - `stundenSchritteProvider` /
//   `StundenSchritteNotifier extends AsyncNotifier<Messwert<List<QuantitySample>>>`
//   in `lib/health/health_provider.dart` — die Stundenschritte hinter der
//   Stufe `T`, als `Messwert`, weil sie aus Apple Health kommen.
// - `schritteTagesziel` in `lib/data/ziele.dart` — die **eine** Stelle, an
//   der das Schritteziel aus `docs/SPEC.md` 3 steht (8.000; der Wert wird
//   hier bewusst nicht wiederholt, sondern über die Konstante geprüft).
// - Die Schlüssel `schritte-kachel-gestern`, `schritte-kachel-schnitt7`,
//   `schritte-kachel-schnitt30`, `schritte-kachel-ziel`, `schritte-leer`,
//   `schritte-fehler`.
// - **Ein** Diagramm mit der Leiste `T W M 6M J`, Startstufe `T`
//   (Schirm-Karte #84: „die erste Stufe ist zugleich die Startstufe").
//
// ## Die Pflichtfälle aus `CLAUDE.md`
//
// 1. Während des Ladens steht nie ein „keine Daten"-Grund (`01`).
// 2. Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da
//    (`32`).
//
// Dazu aus dem Entwurf: Der Stufenwechsel T→W ändert die Fußnote, und auf
// `T` gibt es keine Ziellinie und keine Einfärbung — „das Ziel ist ein
// Tagesziel, eine Stunde daran zu messen hieße, jede Stunde für gescheitert
// zu erklären" (`schritte.js`, Variante `tag`).
//
// ## Was hier bewusst **nicht** geprüft wird
//
// - Zahlen aus `docs/screens/` — sie sind erfunden und dürfen nie
//   Erwartungswert sein. Die Fixturen hier sind eigene.
// - Schriftgrößen, Farben, Dynamic Type.
// - Die Kern-Rechnung selbst — `StepStatistics` hat seine Tests in
//   `Packages/trainings_core/test/step_stats_test.dart`. Hier wird nur
//   geprüft, dass der Schirm ihre Ergebnisse zeigt.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/koerper/schritte_view.dart';
import 'package:repit/shell/router.dart';

void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie
  // in `koerper_view_test.dart`.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  /// Vierzehn gemessene Tage: gestern 9.215, die Tage 2–14 je 8.000.
  /// Daraus folgt mit `StepStatistics.make` (Kern, dort getestet):
  /// Ø 7 = 8.174, Vorwoche = 8.000, Trend +2,175 %, Ø 30 = 8.087,
  /// Ziel erreicht 14 / 14 (bei einem Ziel von 8.000), Top 9.215,
  /// 16 Tage ohne Messung.
  List<DailyMetrics> tageMitWerten() => [
    DailyMetrics(tag: schluesselVor(1), steps: 9215),
    for (var abstand = 2; abstand <= 14; abstand++)
      DailyMetrics(tag: schluesselVor(abstand), steps: 8000),
  ];

  /// Zwei Stunden des heutigen Tages — 08:00 und 09:00 Berliner Zeit.
  /// Die Zeitpunkte sind Stundenbeginne, wie `hourlySteps` sie liefert.
  List<QuantitySample> stundenHeute() => [
    QuantitySample(date: DateTime.utc(2026, 10, 12, 6), value: 500),
    QuantitySample(date: DateTime.utc(2026, 10, 12, 7), value: 700),
  ];

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<QuantitySample>>? stunden,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>(
                  tageMitWerten(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        stundenSchritteProvider.overrideWith(
          () => _Stunden(
            stunden ??
                Bekannt<List<QuantitySample>>(
                  stundenHeute(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: mitSeite ? const SchritteSeite() : const SchritteView(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String textOf(Text text) => text.data ?? text.textSpan!.toPlainText();

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  Zeitdiagramm diagramm(WidgetTester tester) =>
      tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));

  String fussnote(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('diagramm-fussnote')),
          matching: find.byType(Text),
        ),
      )
      .map(textOf)
      .join(' ');

  Future<void> stufe(WidgetTester tester, String beschriftung) async {
    await tester.tap(
      find.descendant(
        of: find.byType(Zeitraumleiste),
        matching: find.text(beschriftung),
      ),
    );
    await tester.pumpAndSettle();
  }

  const kacheln = [
    Key('schritte-kachel-gestern'),
    Key('schritte-kachel-schnitt7'),
    Key('schritte-kachel-schnitt30'),
    Key('schritte-kachel-ziel'),
  ];

  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets('der Schirm bringt weder Gerüst noch Leiste mit', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SchritteView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
        reason:
            'Eine gepushte Ansicht bringt niemals ihren eigenen '
            'Navigationsstapel mit (`CLAUDE.md`)',
      );
    });

    testWidgets('die Seite bringt beides mit und heißt „Schritte"', (
      tester,
    ) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CupertinoNavigationBar),
          matching: find.text('Schritte'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('`oeffneSchritte` schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      oeffneSchritte(h.router);
      final befehl = h.router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(
        befehl!.tab,
        tabVorher,
        reason:
            'Gepusht wird in den Stapel des Tabs, aus dem man kommt — sonst '
            'führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat',
      );
      expect(befehl.ersetztStapel, isFalse);
    });
  });

  group('Während des Ladens steht nie ein „keine Daten"-Grund (`01`)', () {
    testWidgets('NochNie zeigt graue Formen, keinen Grund', (tester) async {
      final h = harness(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        stunden: const NochNie<List<QuantitySample>>(),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schritte-leer')), findsNothing);
      expect(find.byKey(const Key('schritte-fehler')), findsNothing);

      final texte = alleTexte(tester);
      expect(
        texte,
        isNot(contains('aufgezeichnet')),
        reason:
            'Ob nichts aufgezeichnet oder nichts freigegeben ist, weiß die '
            'App während des Laufs nicht (`01`)',
      );
      expect(texte, isNot(contains('nicht lesen')));
      expect(texte, isNot(contains('keine messung')));

      expect(
        find.byType(Platzhalter),
        findsWidgets,
        reason: 'Der Ladeplatzhalter gehört in `NochNie` — und nur dorthin',
      );
    });

    testWidgets('die Geometrie ist dieselbe wie mit Werten', (tester) async {
      final h = harness(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        stunden: const NochNie<List<QuantitySample>>(),
      );
      await zeige(tester, h.app);

      for (final key in kacheln) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              '$key: Eine Anzeige, die es gibt, hat genau eine Form — sie '
              'verschwindet nicht, weil ihr Wert fehlt',
        );
      }
      expect(
        find.byType(Zeitdiagramm),
        findsOneWidget,
        reason: 'Die Diagrammfläche bleibt stehen, nur ungefüllt',
      );
    });
  });

  group('Gelesen und nichts gefunden (`LeerNachLauf`)', () {
    testWidgets('der Kasten nennt beide Gründe und den Health-Pfad', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        stunden: LeerNachLauf<List<QuantitySample>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schritte-leer')), findsOneWidget);
      final kasten = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('schritte-leer')),
              matching: find.byType(Text),
            ),
          )
          .map(textOf)
          .join(' ')
          .toLowerCase();
      expect(
        kasten,
        contains('aufgezeichnet'),
        reason: 'der erste der beiden Gründe',
      );
      expect(
        kasten,
        contains('lesen'),
        reason: 'der zweite — Apple verrät den Lesestatus nicht',
      );
      expect(kasten, contains('health'), reason: 'der Prüfpfad');
    });

    testWidgets('Kacheln und Diagramm bleiben in ihrer Form stehen', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        stunden: LeerNachLauf<List<QuantitySample>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      for (final key in kacheln) {
        expect(find.byKey(key), findsOneWidget);
      }
      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(
        find.byType(Platzhalter),
        findsNothing,
        reason: 'Die graue Form gehört allein in `NochNie`',
      );
    });
  });

  group('Ein gescheiterter Lauf ohne Cache (`Fehlgeschlagen`)', () {
    testWidgets('zeigt eine Warnung und keinen „keine Daten"-Grund', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: StateError('Kanal kaputt'),
          gelaufen: jetzt,
        ),
        stunden: Fehlgeschlagen<List<QuantitySample>>(
          fehler: StateError('Kanal kaputt'),
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schritte-fehler')), findsOneWidget);
      expect(
        find.byKey(const Key('schritte-leer')),
        findsNothing,
        reason: '„gescheitert" ist nicht „nichts gefunden"',
      );
      for (final key in kacheln) {
        expect(find.byKey(key), findsOneWidget);
      }
      expect(find.byType(Zeitdiagramm), findsOneWidget);
    });
  });

  group('Mit Werten', () {
    testWidgets('die vier Kacheln zeigen die Kern-Ergebnisse', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      // Gestern — der Wert von Abstand 1, deutsch gruppiert.
      expect(find.text('9.215'), findsWidgets);
      // Ø 7 Tage mit Trend zur Vorwoche (+2,175 %, gerundet 2).
      expect(find.text('8.174'), findsOneWidget);
      expect(find.textContaining('2 %'), findsOneWidget);
      expect(find.textContaining('Vorwoche'), findsOneWidget);
      // Ø 30 Tage.
      expect(find.text('8.087'), findsOneWidget);
      // Ziel erreicht: gegen die **gemessenen** Tage, nicht gegen 30 —
      // und die Tage ohne Messung werden genannt statt mitgezählt.
      expect(find.text('14 / 14'), findsOneWidget);
      expect(find.textContaining('16 Tage ohne Messung'), findsOneWidget);
      expect(find.textContaining('Top 9.215'), findsOneWidget);

      expect(find.byKey(const Key('schritte-leer')), findsNothing);
      expect(find.byKey(const Key('schritte-fehler')), findsNothing);
      expect(find.byType(Platzhalter), findsNothing);
    });
  });

  group('Die Stufen', () {
// T-Stufe wartet auf Tims Entscheidung (#92, #538); von Tim am
    // 19.11.2026 bis dahin stillgelegt, nicht gelöscht.
    testWidgets('die Leiste trägt T W M 6M J und startet auf T',
        skip: true, (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final leiste = find.byType(Zeitraumleiste);
      for (final beschriftung in const ['T', 'W', 'M', '6M', 'J']) {
        expect(
          find.descendant(of: leiste, matching: find.text(beschriftung)),
          findsOneWidget,
        );
      }

      // Startstufe T: die Fußnote ist die der Stundenwerte, und sie sagt
      // ihre 30-Tage-Grenze, statt dass die Kurve stillschweigend flach
      // wird (Schirm-Karte #84).
      final fuss = fussnote(tester).toLowerCase();
      expect(fuss, contains('stunde'));
      expect(fuss, contains('30 tage'));
    });

// T-Stufe wartet auf Tims Entscheidung (#92, #538); von Tim am
    // 19.11.2026 bis dahin stillgelegt, nicht gelöscht.
    testWidgets('auf T gibt es keine Ziellinie, und die Einheit ist die '
        'Stunde', skip: true, (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        diagramm(tester).linien,
        isEmpty,
        reason:
            'Das Ziel ist ein Tagesziel — eine Stunde daran zu messen '
            'hieße, jede Stunde für gescheitert zu erklären',
      );
      expect(diagramm(tester).einheit, 'Schritte / Stunde');
    });

// T-Stufe wartet auf Tims Entscheidung (#92, #538); von Tim am
    // 19.11.2026 bis dahin stillgelegt, nicht gelöscht.
    testWidgets('T zeigt den heutigen Tag', skip: true, (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final kopf = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('diagramm-kopfzeile')),
              matching: find.byType(Text),
            ),
          )
          .map(textOf)
          .join(' ');
      expect(
        kopf,
        contains('12.10.'),
        reason:
            'Das Startfenster endet am jüngsten Stundenwert — die Fixtur '
            'hat Stunden am heutigen 12.10.',
      );
    });

    testWidgets('T → W wechselt Fußnote, Ziellinie und Einheit', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await stufe(tester, 'W');

      final fuss = fussnote(tester).toLowerCase();
      expect(fuss, contains('tageswerte'));
      expect(fuss, isNot(contains('stundenwerte')));

      final linien = diagramm(tester).linien;
      expect(
        linien.map((linie) => linie.wert),
        contains(schritteTagesziel.toDouble()),
        reason: 'die Ziellinie aus `docs/SPEC.md` 3, über die Konstante',
      );
      expect(
        linien.map((linie) => linie.wert),
        contains(8174.0),
        reason: 'die Ø-7-Linie (SPEC 4.6)',
      );
      expect(diagramm(tester).einheit, 'Schritte / Tag');
    });

    testWidgets('6M trägt nur die Ziellinie', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await stufe(tester, '6M');

      final linien = diagramm(tester).linien;
      expect(linien, hasLength(1));
      expect(linien.single.wert, schritteTagesziel.toDouble());
    });
  });

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('über einen gepushten Schirm hin und zurück', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.text('9.215'), findsWidgets);

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SchritteView), findsNothing);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('9.215'), findsWidgets);
      expect(
        find.byType(Platzhalter),
        findsNothing,
        reason:
            'Zurück heißt nicht „noch einmal von vorn" — ein Platzhalter, '
            'der hier aufblitzt, ist genau das Flackern aus `CLAUDE.md`',
      );
    });
  });
}

/// Steuerbarer Ableger des echten Notifiers — siehe `koerper_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

/// Dasselbe für die Stundenschritte der Stufe `T`.
class _Stunden extends StundenSchritteNotifier {
  _Stunden(this.wert);

  final Messwert<List<QuantitySample>> wert;

  @override
  Future<Messwert<List<QuantitySample>>> build() async => wert;
}
