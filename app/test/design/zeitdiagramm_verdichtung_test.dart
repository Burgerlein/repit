import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/design/zeitdiagramm_zeichnung.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

import 'support.dart' show huelle, textOf;

/// Tests für die **Verdichtungsart** und die **zweite Reihe** des gemeinsamen
/// Diagramm-Bauteils (#93, Unterkarte #13) — `lib/design/zeitdiagramm.dart`.
/// Die Rechnung steht im Kern (`chart_buckets_maximum_test.dart`) und in
/// `test/shell/diagramm_zeitraum_verdichtung_test.dart`; das Bauteil
/// `zeitdiagramm_test.dart` bleibt unverändert und muss grün bleiben.
///
/// Grundlage: `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`,
/// Abschnitt 5, und `docs/SPEC.md` 4.4 („Kraftreihen werden über das
/// Monats*maximum* verdichtet").
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Zwei neue, **optionale** Parameter an `Zeitdiagramm`; ohne sie verhält
/// sich das Bauteil wie bisher:
///
/// ```dart
/// Zeitdiagramm(
///   ...,
///   /// Wie die Messwerte eines Monats in `6M` und `J` zu einem Punkt
///   /// werden. Vorgabe: das Mittel.
///   ChartAggregation verdichtung = ChartAggregation.mean,
///   /// Eine zweite Reihe in derselben Form wie `reihe`, gestrichelt, auf
///   /// derselben Skala; verdichtet wird sie **ebenso** (Spec 5). Vorgabe:
///   /// keine.
///   List<({DateTime tag, double wert})> zweiteReihe = const [],
/// );
/// ```
///
/// Dazu die Startstufe, die der Schirm vorgibt statt `startStufe(stufen)`
/// — wie sie heißt, legt dieser Test nicht fest; geprüft wird sie über
/// `Zeitraumleiste.gewaehlt` in `gym_fortschritt_view_test.dart`.
///
/// ## Wie ein Widget-Test das sehen kann
///
/// Der Maler trägt, was das Bauteil ihm übergibt (`ZeitdiagrammPainter.balken`,
/// derselbe Griff wie in `zeitdiagramm_test.dart`). Was dort steht, ist, was im
/// Bild landet.
///
/// Alle Daten sind erfunden.
void main() {
  DateTime tag(int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tagImMonat));

  ({DateTime tag, double wert}) punkt(DateTime t, double wert) =>
      (tag: t, wert: wert);

  Widget diagramm({
    required List<({DateTime tag, double wert})> reihe,
    required List<DiagrammStufe> stufen,
    ChartAggregation verdichtung = ChartAggregation.mean,
    List<({DateTime tag, double wert})> zweiteReihe = const [],
  }) => Zeitdiagramm(
    reihe: reihe,
    stufen: stufen,
    fussnote: (_) => 'fuss',
    alsBalken: false,
    einheit: 'kg',
    verdichtung: verdichtung,
    zweiteReihe: zweiteReihe,
  );

  Future<void> zeige(WidgetTester tester, Widget kind) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Erst leeren: Jeder Aufruf beginnt mit einem frischen Zustand, damit
    // der Test nicht davon abhängt, ob das Bauteil auf einen geänderten
    // Parameter mit Neurechnen antwortet.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      huelle(SizedBox(width: 360, height: 400, child: kind)),
    );
    await tester.pumpAndSettle();
  }

  ZeitdiagrammPainter maler(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(Zeitdiagramm),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((anstrich) => anstrich.painter)
      .whereType<ZeitdiagrammPainter>()
      .single;

  List<double> gezeichnet(WidgetTester tester) {
    final balken = [...maler(tester).balken]
      ..sort((a, b) => a.platz.compareTo(b.platz));
    return [for (final b in balken) b.wert];
  }

  String kopf(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('diagramm-kopfzeile')),
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ');

  // Januar: 60 und 50, Februar: 70 und 30. Mittel: 55 und 50. Maximum: 60
  // und 70 — und das Maximum steigt, wo das Mittel fällt.
  final zweiMonate = [
    punkt(tag(1, 5), 60),
    punkt(tag(1, 26), 50),
    punkt(tag(2, 3), 70),
    punkt(tag(2, 24), 30),
  ];

  group('Verdichtung', () {
    testWidgets('ohne Angabe bleibt es das Mittel', (tester) async {
      // Bewusst **ohne** die neuen Parameter gebaut: So rufen alle
      // bestehenden Schirme das Bauteil auf.
      await zeige(
        tester,
        Zeitdiagramm(
          reihe: zweiMonate,
          stufen: const [DiagrammStufe.halbjahr],
          fussnote: (_) => 'fuss',
          alsBalken: false,
          einheit: 'kg',
        ),
      );
      expect(gezeichnet(tester), [55.0, 50.0]);
    });

    testWidgets('mit „Maximum" zeigt jeder Monat sein Maximum', (tester) async {
      for (final stufe in [DiagrammStufe.halbjahr, DiagrammStufe.jahr]) {
        await zeige(
          tester,
          diagramm(
            reihe: zweiMonate,
            stufen: [stufe],
            verdichtung: ChartAggregation.max,
          ),
        );
        expect(
          gezeichnet(tester),
          [60.0, 70.0],
          reason:
              '$stufe: Ein Höchstgewicht ist das Gewicht, das auf der '
              'Stange lag, kein Mittel',
        );
      }
    });

    testWidgets('wo nichts verdichtet wird, ändert „Maximum" nichts', (
      tester,
    ) async {
      final tage = [
        punkt(tag(3, 2), 60),
        punkt(tag(3, 9), 62.5),
        punkt(tag(3, 16), 70),
      ];
      await zeige(
        tester,
        diagramm(reihe: tage, stufen: const [DiagrammStufe.monat]),
      );
      final ohne = gezeichnet(tester);

      await zeige(
        tester,
        diagramm(
          reihe: tage,
          stufen: const [DiagrammStufe.monat],
          verdichtung: ChartAggregation.max,
        ),
      );
      expect(gezeichnet(tester), ohne);
      expect(ohne, [60.0, 62.5, 70.0]);
    });

    testWidgets('die Kopfzeile über einem einzigen Monat nennt das Maximum, '
        'nicht 65', (tester) async {
      final reihe = [punkt(tag(3, 2), 60), punkt(tag(3, 28), 70)];

      await zeige(
        tester,
        Zeitdiagramm(
          reihe: reihe,
          stufen: const [DiagrammStufe.halbjahr],
          fussnote: (_) => 'fuss',
          alsBalken: false,
          einheit: 'kg',
        ),
      );
      expect(kopf(tester), contains('65'), reason: 'Das Mittel, wie bisher');

      await zeige(
        tester,
        diagramm(
          reihe: reihe,
          stufen: const [DiagrammStufe.halbjahr],
          verdichtung: ChartAggregation.max,
        ),
      );
      expect(kopf(tester), contains('70'));
      expect(
        kopf(tester),
        isNot(contains('65')),
        reason: 'Mit einem Punkt im Fenster ist jede Kopfzahl dieser Punkt',
      );
    });
  });

  group('Zweite Reihe', () {
    testWidgets('ändert weder die erste Reihe noch die Kopfzeile', (
      tester,
    ) async {
      final reihe = [punkt(tag(3, 2), 60), punkt(tag(3, 28), 70)];
      await zeige(
        tester,
        diagramm(
          reihe: reihe,
          stufen: const [DiagrammStufe.halbjahr],
          verdichtung: ChartAggregation.max,
        ),
      );
      final balkenOhne = gezeichnet(tester);
      final kopfOhne = kopf(tester);

      await zeige(
        tester,
        diagramm(
          reihe: reihe,
          stufen: const [DiagrammStufe.halbjahr],
          verdichtung: ChartAggregation.max,
          zweiteReihe: [punkt(tag(3, 2), 80), punkt(tag(3, 28), 84)],
        ),
      );

      expect(gezeichnet(tester), balkenOhne);
      expect(
        kopf(tester),
        kopfOhne,
        reason:
            'Die Kopfzeile gehört zur ersten Reihe, dem Höchstgewicht; das '
            '1RM hat seine Kachel',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('eine leere zweite Reihe ist keine Reihe', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: zweiMonate,
          stufen: const [DiagrammStufe.halbjahr],
          verdichtung: ChartAggregation.max,
          zweiteReihe: const [],
        ),
      );
      expect(gezeichnet(tester), [60.0, 70.0]);
      expect(tester.takeException(), isNull);
    });
  });
}
