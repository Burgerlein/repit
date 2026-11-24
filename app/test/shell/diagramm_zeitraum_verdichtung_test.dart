import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/shell/diagramm_zeitraum.dart';

/// Tests für die **Verdichtungsart** von `diagrammPunkte` (#93, Unterkarte
/// #13) — `lib/shell/diagramm_zeitraum.dart`. Die Rechnung selbst steht im
/// Kern (`Packages/trainings_core/test/chart_buckets_maximum_test.dart`);
/// hier geht es um den **Durchgriff**: dass die Shell-Funktion die Art an
/// `ChartBuckets` weiterreicht und dabei nichts nachrechnet.
///
/// `diagramm_zeitraum_test.dart` bleibt unverändert und muss grün bleiben —
/// diese Datei ergänzt es, ersetzt es nicht.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// List<DiagrammPunkt> diagrammPunkte({
///   required List<({DateTime tag, double wert})> werte,
///   required DiagrammStufe stufe,
///   /// Vorgabe: [ChartAggregation.mean] — das heutige Verhalten.
///   ChartAggregation verdichtung = ChartAggregation.mean,
/// });
/// ```
///
/// Der Grund steht in `docs/SPEC.md` 4.4: Kraftreihen werden über das
/// Monats*maximum* verdichtet, nicht über das Mittel. Schritte, Gewicht und
/// Schlaf behalten das Mittel — deshalb ein Parameter und keine neue Regel
/// für alle.
///
/// Alle Daten sind erfunden.
void main() {
  DateTime tag(int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tagImMonat));

  ({DateTime tag, double wert}) wert(DateTime t, double w) => (tag: t, wert: w);

  final einMonat = [wert(tag(3, 2), 60), wert(tag(3, 28), 70)];

  group('Das Maximum je Monat', () {
    test('60 und 70 im selben Monat ergeben 70 — nicht 65', () {
      for (final stufe in [DiagrammStufe.halbjahr, DiagrammStufe.jahr]) {
        final punkte = diagrammPunkte(
          werte: einMonat,
          stufe: stufe,
          verdichtung: ChartAggregation.max,
        );
        expect(punkte, hasLength(1), reason: '$stufe');
        expect(punkte.single.wert, 70.0, reason: '$stufe');
        expect(punkte.single.beginn, tag(3, 1), reason: '$stufe');
        expect(punkte.single.tage, 2, reason: '$stufe');
      }
    });

    test('ohne Angabe bleibt es das Mittel', () {
      final punkte = diagrammPunkte(
        werte: einMonat,
        stufe: DiagrammStufe.halbjahr,
      );
      expect(punkte.single.wert, 65.0);
    });

    test('ein Zeitpunkt mitten am Tag zählt zu seinem Berliner Tag', () {
      // 22:30 UTC am 31.03. ist 00:30 am 01.04. Berliner Zeit (MESZ): schon
      // April. Die Shell zieht auf den Tagesbeginn, bevor sie verdichtet.
      final punkte = diagrammPunkte(
        werte: [
          (tag: DateTime.utc(2026, 3, 31, 21, 30), wert: 50.0),
          (tag: DateTime.utc(2026, 3, 31, 22, 30), wert: 100.0),
        ],
        stufe: DiagrammStufe.halbjahr,
        verdichtung: ChartAggregation.max,
      );
      expect(punkte.map((p) => p.beginn), [tag(3, 1), tag(4, 1)]);
      expect(punkte.map((p) => p.wert), [50.0, 100.0]);
    });

    test('bei Unterstützung (negativ) ist das Maximum der Wert näher an '
        'null', () {
      final punkte = diagrammPunkte(
        werte: [
          wert(tag(3, 2), -27),
          wert(tag(3, 16), -24.5),
          wert(tag(3, 23), -26),
        ],
        stufe: DiagrammStufe.halbjahr,
        verdichtung: ChartAggregation.max,
      );
      expect(punkte.single.wert, -24.5);
    });
  });

  group('Wo nichts verdichtet wird', () {
    test('`woche` und `monat` reichen durch, gleich welche Art', () {
      final tage = [
        wert(tag(3, 2), 60),
        wert(tag(3, 9), 62.5),
        wert(tag(3, 16), 70),
      ];
      for (final stufe in [DiagrammStufe.woche, DiagrammStufe.monat]) {
        expect(
          diagrammPunkte(
            werte: tage,
            stufe: stufe,
            verdichtung: ChartAggregation.max,
          ),
          diagrammPunkte(werte: tage, stufe: stufe),
          reason: '$stufe: je Training ein Punkt',
        );
      }
    });
  });
}
