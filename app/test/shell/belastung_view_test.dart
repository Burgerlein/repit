import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/belastung_view.dart';
import 'package:repit/shell/belastung_zustand.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;

/// Tests für die **Oberfläche** des Belastungs-Schirms (#94) —
/// `lib/shell/belastung_view.dart`. Der Zustand darunter liegt in
/// `belastung_zustand_test.dart`.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/belastung_view.dart
///
/// /// Öffnet den Schirm auf dem Stapel des **aktuell gewählten** Tabs.
/// void oeffneBelastung(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [BelastungView].
/// class BelastungSeite extends StatelessWidget {
///   const BelastungSeite({super.key});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class BelastungView extends ConsumerWidget {
///   const BelastungView({super.key});
/// }
///
/// // lib/design/zeitdiagramm.dart
///
/// /// Die Zeitraumleiste über jedem Diagramm.
/// class Zeitraumleiste extends StatelessWidget {
///   const Zeitraumleiste({
///     super.key,
///     required List<DiagrammStufe> stufen,
///     required DiagrammStufe gewaehlt,
///     required ValueChanged<DiagrammStufe> onWaehle,
///   });
/// }
///
/// /// Eine waagerechte Linie im Diagramm (Ziel, Median, Schwelle).
/// @immutable
/// class Ziellinie {
///   const Ziellinie({
///     required String name,
///     required double wert,
///     required CupertinoDynamicColor farbe,
///   });
/// }
///
/// /// Leiste, Kopfzeile, Graph und Fußzeile in einem.
/// ///
/// /// Die Kopfzeile steht unter `Key('diagramm-kopfzeile')`, die Fußzeile
/// /// unter `Key('diagramm-fussnote')` — beide tragen Regeln, die geprüft
/// /// werden.
/// class Zeitdiagramm extends StatefulWidget {
///   const Zeitdiagramm({
///     super.key,
///     required List<({DateTime tag, double wert})> reihe,
///     required List<DiagrammStufe> stufen,
///     required String Function(DiagrammStufe stufe) fussnote,
///     bool alsBalken = true,
///     List<Ziellinie> linien = const [],
///   });
/// }
/// ```
///
/// ## Warum `Zeitdiagramm` ein eigener Baustein ist
///
/// Beide Schirme dieses Tickets zeigen dasselbe: Leiste, Kopfzeile, Graph,
/// Fußzeile. In Swift ist das `Sources/DesignSystem/TimeChart.swift` (598
/// Zeilen), und die Entwurfs-Spec
/// `2026-10-13-graphen-zeitraum-und-ablesen-design.md` ist ausdrücklich „die
/// Entscheidung für alle" — jeder Schirm, der seine eigene Zeitraumlogik
/// mitbringt, bekommt auch seine eigene Bedienung.
///
/// **Was dieser Baustein hier noch nicht kann, steht im Bericht:** Blättern
/// in die Vergangenheit und das Ablesen eines einzelnen Balkens sind Gesten
/// und brauchen eine eigene Aufgabe. Geprüft wird, was den beiden Schirmen
/// ihre Aussage gibt: welche Stufen angeboten werden, auf welcher aufgemacht
/// wird (**#7**), und dass die Fußzeile die Verdichtung nennt, sobald sie
/// eine ist.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Layout, Abstände, Beschriftungen von Knöpfen.** `CLAUDE.md`: nur
///   Zustände und Übergänge. Wo ein Text eine **Regel** trägt (Herkunft der
///   Minuten, „—" statt „0", beide Möglichkeiten bei fehlenden Daten, die
///   Verdichtung ab `6M`), wird die Regel geprüft, nie der ganze Satz.
/// - **Pixel des Graphen.** Golden-Tests gibt es im Flutter-Zweig nicht; die
///   Rechnung dahinter steht in `diagramm_zeitraum_test.dart`.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? trainingsminuten = 20,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: 13,
    exerciseMinutes: trainingsminuten,
  );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, tag, 4);
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: const [],
    );
  }

  /// **Die Trainingsminuten kommen als Testdaten herein, nicht aus der
  /// Fixture.** `health_mock.dart` liest `exerciseMinutes` gar nicht — das
  /// `trainingsexport`-Format kennt sie nicht. Wer diesen Schirm gegen den
  /// Demo-Datensatz prüft, sieht **immer** einen leeren Schirm, und das ist
  /// kein Fehler des Schirms.
  List<DailyMetrics> tage({double? heute = 60, double? vorwoche = 20}) => [
    for (var t = 5; t <= 11; t++) tagwert(t, trainingsminuten: vorwoche),
    tagwert(12, trainingsminuten: heute),
  ];

  List<SleepNight> naechte({double heuteStunden = 7}) => [
    for (var t = 5; t <= 11; t++) nachtVon(t),
    nachtVon(12, stunden: heuteStunden),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.** Der Zustand wandert mit — ein gescheiterter Tageslauf
  /// bedeutet hier auch einen gescheiterten Nachtlauf.
  Messwert<Map<String, NightVitals>> nachtwerteAus(
    Messwert<List<DailyMetrics>> tageswerte,
  ) => switch (tageswerte) {
    Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in wert)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: stand, laeuft: laeuft),
    NochNie<List<DailyMetrics>>() => const NochNie<Map<String, NightVitals>>(),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
      LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<Map<String, NightVitals>>(
        fehler: fehler,
        gelaufen: gelaufen,
      ),
  };

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    Ziele ziele = Ziele.vorbelegung,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(() => _Tageswerte(tagesWert)),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster. Ohne diese Überschreibung liefe ein Widget-Test in
        // die echte drift-Datenbank — und die drei Werte blieben leer.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(tagesWert)),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  naechte(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(ziele)),
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
              // Entspricht der durchscheinenden Navigations- und Tableiste:
              // Nur mit echten Rändern hat `GlasAbstand` etwas zu tun.
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: mitSeite ? const BelastungSeite() : const BelastungView(),
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

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  Zeitraumleiste leiste(WidgetTester tester) =>
      tester.widget<Zeitraumleiste>(find.byType(Zeitraumleiste));

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
          of: find.byType(BelastungView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
        reason:
            'Den Stapel stellt der Gastgeber. Eine gepushte Ansicht, die '
            'ihren eigenen Navigator mitbringt, schließt sich sofort wieder',
      );
    });

    testWidgets('die Seite bringt beides mit', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(BelastungView), findsOneWidget);
    });

    testWidgets('der Abstand kommt aus `GlasAbstand`', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(BelastungView),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final erwartet = GlasAbstand.of(
        tester.element(find.byType(BelastungView)),
      );
      expect(
        erwartet.top,
        greaterThan(0),
        reason: 'sonst prüft dieser Test gar nichts',
      );
      final padding = scroll.padding! as EdgeInsets;
      expect(padding.top, erwartet.top);
      expect(padding.bottom, greaterThanOrEqualTo(erwartet.bottom));
    });

    testWidgets('der Schirm besorgt seine Daten selbst', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        alleTexte(tester).contains('60'),
        isTrue,
        reason:
            'Niemand darf sich darauf verlassen, dass vorher eine Übersicht '
            'geladen hat — jeder Schirm ist aus jedem Tab erreichbar',
      );
    });

    testWidgets('`oeffneBelastung` schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      oeffneBelastung(h.router);
      final befehl = h.router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(
        befehl.tab,
        tabVorher,
        reason:
            'Ein Detailziel wechselt nie von sich aus den Tab — sonst führte '
            '„zurück" in ein Menü, das der Nutzer nie geöffnet hat',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BelastungView), findsOneWidget);
    });
  });

  group('Die vier Zustände', () {
    testWidgets(
      'während des Ladens steht nirgends ein „keine Daten"-Grund '
      '(docs/todo/01)',
      (tester) async {
        final h = harness(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        );
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        for (final verboten in const [
          'keine werte',
          'nichts aufgezeichnet',
          'nicht freigegeben',
          'darf den wert nicht lesen',
        ]) {
          expect(
            texte.contains(verboten),
            isFalse,
            reason:
                '„$verboten" gehört zu einem fertigen Lauf ohne Treffer, '
                'nicht zu einem laufenden',
          );
        }
        expect(find.byKey(const Key('belastung-laden')), findsOneWidget);
      },
    );

    testWidgets('ein fertiger Lauf ohne Treffer nennt beide Möglichkeiten', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(
        texte.contains('aufgezeichnet'),
        isTrue,
        reason: 'die eine Möglichkeit: die Uhr hat nichts aufgezeichnet',
      );
      expect(
        texte.contains('lesen') || texte.contains('freigegeben'),
        isTrue,
        reason:
            'die andere: der Lesezugriff fehlt. Apple verrät den Unterschied '
            'nicht, also müssen beide dastehen',
      );
      expect(
        texte.contains('0 min'),
        isFalse,
        reason:
            'Eine gemessene Null behauptete, du hättest dich nicht bewegt',
      );
    });

    testWidgets('ein gescheiterter Lauf sagt nicht, es gäbe keine Daten', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
        schlaf: Fehlgeschlagen<List<SleepNight>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte.contains('nicht geladen') || texte.contains('geklappt'),
          isTrue);
      expect(
        texte.contains('nichts aufgezeichnet'),
        isFalse,
        reason: 'Ein Fehler ist keine Aussage über die Datenlage',
      );
    });

    testWidgets(
      'ein gescheiterter Nachlauf nimmt den sichtbaren Wert nicht weg (#32)',
      (tester) async {
        final h = harness(
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
        );
        await zeige(tester, h.app);

        expect(
          textUnter(tester, const Key('belastung-kopf')).contains('60'),
          isTrue,
          reason: 'Tims Beschwerde ist, dass Werte verschwinden',
        );
      },
    );
  });

  group('Die Kopfzeile', () {
    testWidgets('Minuten, Ziel und Anteil stehen dort', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final kopf = textUnter(tester, const Key('belastung-kopf'));
      expect(kopf, contains('60'));
      expect(kopf, contains('210'));
      expect(
        kopf,
        contains('29'),
        reason: '60 von 210 Minuten sind 29 % — gerundet, nicht abgeschnitten',
      );
    });

    testWidgets('das Wochenziel kommt aus den Zielen, nicht aus dem Schirm', (
      tester,
    ) async {
      final h = harness(
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 140),
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('140'));
      expect(
        texte.contains('210'),
        isFalse,
        reason:
            'Steht die Zahl ein zweites Mal im Quelltext, ändert ein '
            'geändertes Tagesziel die Kopfzeile nicht mit',
      );
    });

    testWidgets('ohne Aufzeichnung steht „—", nie „0 min"', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: null),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final kopf = textUnter(tester, const Key('belastung-kopf'));
      expect(kopf, contains('—'));
      expect(
        kopf.contains('0 min'),
        isFalse,
        reason:
            'Eine gemessene Null behauptete, du hättest dich diese Woche '
            'nicht bewegt — das weiß niemand, wenn nichts aufgezeichnet wurde',
      );
      expect(
        alleTexte(tester).contains('aufgezeichnet'),
        isTrue,
        reason: 'der Grund gehört dazu, nicht nur der Strich',
      );
    });

    testWidgets('eine echte Null bleibt „0"', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: 0),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final kopf = textUnter(tester, const Key('belastung-kopf'));
      expect(kopf, contains('0'));
      expect(kopf.contains('—'), isFalse);
    });
  });

  group('Die Vorwoche', () {
    testWidgets('Summe und Veränderung stehen dort', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final vorwoche = textUnter(tester, const Key('belastung-vorwoche'));
      expect(vorwoche, contains('140'));
      expect(
        vorwoche,
        contains('57'),
        reason: '60 gegen 140 Minuten ist ein Rückgang um 57 %',
      );
    });

    testWidgets('ohne Vorwoche fällt der Abschnitt ganz weg', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(vorwoche: null),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('belastung-vorwoche')),
        findsNothing,
        reason:
            'Eine Vorwoche ohne Aufzeichnung ist keine Vorwoche mit 0 '
            'Minuten — statt einer erfundenen Zahl steht dort nichts',
      );
    });
  });

  group('Das Diagramm', () {
    testWidgets('die Leiste trägt W M 6M — kein J', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(leiste(tester).stufen, belastungsStufen);
      expect(
        leiste(tester).stufen.contains(DiagrammStufe.jahr),
        isFalse,
        reason:
            'Der Store lädt 31 Tage. Wer „überall dieselben Stufen" '
            'vereinheitlicht, erzeugt ein leeres Jahr',
      );
    });

    testWidgets('beim Aufschlagen ist die erste Stufe gewählt (#7)', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        leiste(tester).gewaehlt,
        belastungsStufen.first,
        reason:
            'Die Hausregel aus `TimeChart.swift:80–85`: Die erste Stufe ist '
            'die Startstufe. Genau das greift in Swift nicht zuverlässig — '
            'das ist #7, und hier wird es gelöst statt abgeschrieben',
      );
    });

    testWidgets('ein Tipp auf eine andere Stufe wechselt sie', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(leiste(tester).gewaehlt, DiagrammStufe.halbjahr);
    });

    testWidgets('ab 6M nennt die Fußzeile den Tagesdurchschnitt', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('diagramm-fussnote')).toLowerCase(),
        isNot(contains('durchschnitt')),
        reason: 'auf W ist ein Balken ein Tag, da gibt es nichts zu verdichten',
      );

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      final fuss = textUnter(
        tester,
        const Key('diagramm-fussnote'),
      ).toLowerCase();
      expect(
        fuss,
        contains('durchschnitt'),
        reason:
            'Monatsbalken sind Tagesdurchschnitte, und ab `6M` muss das in '
            'der Fußnote stehen (`LoadDetailView.swift:79–81`)',
      );
    });

    testWidgets('das Tagesziel steht als Linie im Diagramm', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final diagramm = tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));
      expect(diagramm.linien, hasLength(1));
      expect(
        diagramm.linien.single.wert,
        closeTo(210 / DateTime.daysPerWeek, 1e-9),
        reason:
            'Das Tagesziel ist das Wochenziel durch sieben, nicht die 30 aus '
            'dem Quelltext — ändert sich das eine, ändert sich das andere mit '
            '(`belastung.js:14`)',
      );
    });

    testWidgets('das Diagramm zeichnet Balken, keine Linie', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm)).alsBalken,
        isTrue,
      );
    });
  });

  group('Die Einordnung', () {
    testWidgets('ohne Warnsignal trägt sich die Belastung', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('belastung-einordnung')).toLowerCase(),
        contains('keine warnsignale'),
      );
    });

    testWidgets('ab zwei Warnsignalen steht dort etwas anderes', (
      tester,
    ) async {
      final mitZwei = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          [for (var t = 5; t <= 11; t++) tagwert(t), tagwert(12, hrv: 20)],
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechte(heuteStunden: 4),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, mitZwei.app);
      final zwei = textUnter(tester, const Key('belastung-einordnung'));

      final ruhig = harness();
      await zeige(tester, ruhig.app);
      final keins = textUnter(tester, const Key('belastung-einordnung'));

      expect(
        zwei,
        isNot(keins),
        reason:
            'Die Kombination ist der Hinweis, nicht die Zahl allein — viel '
            'Belastung bei guter Erholung ist Training',
      );
      expect(zwei.toLowerCase(), isNot(contains('keine warnsignale')));
    });
  });

  group('Die Fußnote', () {
    testWidgets('sie sagt, dass die Minuten aus Apple Health kommen', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('apple health'));
      expect(
        texte.contains('erhöhtem puls'),
        isTrue,
        reason:
            'Die Uhr zählt jede Minute mit erhöhtem Puls — auch '
            'Treppensteigen, auch Radfahren zur Arbeit. Ohne diesen Satz '
            'wundert man sich über Minuten an Tagen ohne Training '
            '(`belastung.js:8–12`)',
      );
    });

    testWidgets('und sie ist keine Diagnose', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        alleTexte(tester).contains('medizinisch') ||
            alleTexte(tester).contains('schätzung') ||
            alleTexte(tester).contains('orientierung'),
        isTrue,
        reason:
            '`CLAUDE.md`: Jeder Trainings-, Ernährungs- und Gesundheitswert '
            'ist als allgemeine Empfehlung oder Schätzung zu kennzeichnen',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
