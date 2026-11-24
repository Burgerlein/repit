import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Verdichtungsart** von `ChartBuckets` — Ticket #93 (und
/// dessen Unterkarte #13), Spec
/// `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`, Abschnitt 5,
/// dazu `docs/SPEC.md` 4.4: „Kraftreihen werden über das Monats*maximum*
/// verdichtet, nicht über das Monatsmittel."
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert. Die Datei ergänzt `chart_buckets_test.dart`, ersetzt sie
/// nicht — dort steht das Mittel, hier das Maximum.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Additiv zu `lib/src/chart_buckets.dart`; bestehende Aufrufe ändern ihr
/// Verhalten nicht:
///
/// ```dart
/// /// Wie `ChartBuckets.points` die Messwerte eines Kalendermonats zu einem
/// /// Punkt zusammenfasst (nur `halfYear` und `year`).
/// enum ChartAggregation { mean, max }
///
/// abstract final class ChartBuckets {
///   static List<ChartPoint> points({
///     required List<ChartSample> samples,
///     required ChartRange range,
///     /// Vorgabe: [ChartAggregation.mean] — das heutige Verhalten.
///     ChartAggregation aggregation = ChartAggregation.mean,
///   });
/// }
/// ```
///
/// ## Warum das ein Kernthema ist
///
/// Eine Reihe, die „Höchstgewicht" heißt, darf nicht den Durchschnitt der
/// Höchstgewichte zeigen: 60 kg am 2. und 70 kg am 28. ergäben 65 — ein
/// Gewicht, das nie auf der Stange lag. Das war ein echter Fehler der alten
/// App (Board-Nr. 18), entschieden am 26.10.2026. Schritte, Körpergewicht
/// und Schlaf behalten das Mittel; deshalb ist es eine **Verdichtungsart je
/// Aufruf** und keine neue Regel für alle.
///
/// Alle Daten sind erfunden.
void main() {
  // Berliner Tagesbeginn als UTC-Zeitpunkt, wie überall im Paket.
  DateTime tag(int jahr, int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tagImMonat));

  ChartSample messwert(DateTime zeitpunkt, double wert) =>
      ChartSample(date: zeitpunkt, value: wert);

  List<double> werte(List<ChartPoint> punkte) =>
      punkte.map((p) => p.value).toList();
  List<DateTime> starts(List<ChartPoint> punkte) =>
      punkte.map((p) => p.start).toList();
  List<int> tageZahlen(List<ChartPoint> punkte) =>
      punkte.map((p) => p.dayCount).toList();

  group('Der Vertrag der Aufzählung', () {
    test('ChartAggregation kennt genau Mittel und Maximum', () {
      expect(ChartAggregation.values, [
        ChartAggregation.mean,
        ChartAggregation.max,
      ]);
    });
  });

  group('Ohne Angabe bleibt es das Mittel', () {
    final proben = [
      messwert(tag(2026, 3, 2), 60),
      messwert(tag(2026, 3, 28), 70),
    ];

    test('die Vorgabe ist das Mittel — kein bestehender Aufrufer ändert '
        'sich', () {
      final ohne = ChartBuckets.points(
        samples: proben,
        range: ChartRange.halfYear,
      );
      expect(werte(ohne), [65.0]);
    });

    test('ausdrücklich `mean` ergibt dasselbe wie die Vorgabe', () {
      for (final stufe in ChartRange.values) {
        expect(
          ChartBuckets.points(
            samples: proben,
            range: stufe,
            aggregation: ChartAggregation.mean,
          ),
          ChartBuckets.points(samples: proben, range: stufe),
          reason: '$stufe',
        );
      }
    });
  });

  group('Das Maximum je Kalendermonat', () {
    test('60 kg am 2. und 70 kg am 28. ergeben 70 — nicht 65', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 3, 2), 60),
          messwert(tag(2026, 3, 28), 70),
        ],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );

      expect(punkte, hasLength(1));
      expect(
        punkte.single.value,
        70.0,
        reason:
            'Ein Höchstgewicht ist das Gewicht, das auf der Stange lag. '
            '65 lag nie darauf (`docs/SPEC.md` 4.4, Board-Nr. 18)',
      );
    });

    test('das Maximum ist nicht der letzte Wert des Monats', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 3, 2), 70),
          messwert(tag(2026, 3, 28), 60),
        ],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );
      expect(
        werte(punkte),
        [70.0],
        reason:
            'Wer am Monatsende leichter trainiert hat, hat sein Maximum '
            'trotzdem erreicht',
      );
    });

    test('das Maximum ist nicht der erste Wert des Monats', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 3, 2), 60),
          messwert(tag(2026, 3, 14), 72.5),
          messwert(tag(2026, 3, 28), 65),
        ],
        range: ChartRange.year,
        aggregation: ChartAggregation.max,
      );
      expect(werte(punkte), [72.5]);
    });

    test('jeder Monat bekommt sein eigenes Maximum, aufsteigend', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 2, 3), 70),
          messwert(tag(2026, 1, 5), 60),
          messwert(tag(2026, 2, 24), 30),
          messwert(tag(2026, 1, 26), 50),
        ],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );

      expect(starts(punkte), [tag(2026, 1, 1), tag(2026, 2, 1)]);
      expect(werte(punkte), [60.0, 70.0]);
    });

    test('der Punkt liegt auf dem Berliner Monatsersten', () {
      final punkte = ChartBuckets.points(
        samples: [messwert(tag(2026, 3, 17), 60)],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );
      expect(punkte.single.start, tag(2026, 3, 1));
    });

    test('ein Monat ohne Messung fehlt — eine Lücke bleibt eine Lücke', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 1, 12), 60),
          messwert(tag(2026, 3, 9), 65),
        ],
        range: ChartRange.year,
        aggregation: ChartAggregation.max,
      );
      expect(starts(punkte), [tag(2026, 1, 1), tag(2026, 3, 1)]);
    });

    test('`dayCount` zählt verschiedene Kalendertage, nicht Messwerte', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 3, 2), 60),
          messwert(tag(2026, 3, 2).add(const Duration(hours: 5)), 62.5),
          messwert(tag(2026, 3, 9), 65),
        ],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );
      expect(tageZahlen(punkte), [2]);
      expect(werte(punkte), [65.0]);
    });

    test(
      'bei negativen Werten ist das Maximum der, der näher an null liegt',
      () {
        // Unterstützung wird negativ geführt: −24,5 ist schwerer als −27.
        final punkte = ChartBuckets.points(
          samples: [
            messwert(tag(2026, 3, 2), -27),
            messwert(tag(2026, 3, 16), -24.5),
            messwert(tag(2026, 3, 23), -26),
          ],
          range: ChartRange.halfYear,
          aggregation: ChartAggregation.max,
        );
        expect(werte(punkte), [-24.5]);
      },
    );

    test('der Monat wird nach Berliner Zeit bestimmt, nicht nach UTC', () {
      // 31.03.2026 21:30 UTC = 23:30 Berliner Zeit (MESZ, +2) — noch März.
      // 31.03.2026 22:30 UTC = 01.04. 00:30 Berliner Zeit — schon April.
      final punkte = ChartBuckets.points(
        samples: [
          messwert(DateTime.utc(2026, 3, 31, 21, 30), 50),
          messwert(DateTime.utc(2026, 3, 31, 22, 30), 100),
        ],
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );

      expect(starts(punkte), [tag(2026, 3, 1), tag(2026, 4, 1)]);
      expect(
        werte(punkte),
        [50.0, 100.0],
        reason:
            'Die 100 gehört dem Berliner April; als UTC-März gerechnet '
            'stünde sie im falschen Monat',
      );
    });

    test('die Eingabe darf unsortiert sein und wird nicht verändert', () {
      final eingabe = [
        messwert(tag(2026, 3, 28), 70),
        messwert(tag(2026, 1, 5), 60),
        messwert(tag(2026, 3, 2), 55),
      ];
      final kopie = List<ChartSample>.of(eingabe);

      final punkte = ChartBuckets.points(
        samples: eingabe,
        range: ChartRange.halfYear,
        aggregation: ChartAggregation.max,
      );

      expect(werte(punkte), [60.0, 70.0]);
      expect(eingabe, kopie, reason: 'Der Aufruf hat keine Nebenwirkung');
    });

    test('ohne Messwerte keine Punkte', () {
      expect(
        ChartBuckets.points(
          samples: const [],
          range: ChartRange.halfYear,
          aggregation: ChartAggregation.max,
        ),
        isEmpty,
      );
    });
  });

  group('Wo nichts verdichtet wird, ändert das Maximum nichts', () {
    final proben = [
      messwert(tag(2026, 3, 2), 60),
      messwert(tag(2026, 3, 2).add(const Duration(hours: 5)), 62.5),
      messwert(tag(2026, 3, 28), 70),
    ];

    test('`day`, `week` und `month` reichen die Messwerte unverändert '
        'durch', () {
      for (final stufe in [ChartRange.day, ChartRange.week, ChartRange.month]) {
        final mitMax = ChartBuckets.points(
          samples: proben,
          range: stufe,
          aggregation: ChartAggregation.max,
        );
        expect(
          mitMax,
          ChartBuckets.points(samples: proben, range: stufe),
          reason:
              '$stufe: je Training ein Punkt — verdichtet wird erst ab '
              '`halfYear`',
        );
        expect(werte(mitMax), [60.0, 62.5, 70.0], reason: '$stufe');
      }
    });
  });
}
