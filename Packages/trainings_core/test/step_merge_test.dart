import 'package:test/test.dart';

import 'package:trainings_core/src/step_merge.dart';

/// Tests für `StepMerge`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/StepMerge.swift`.
///
/// Direkter Import der Implementierungsdatei statt des Barrel-Files, aus
/// demselben Grund wie bei `data_window_test.dart`: `lib/src/step_merge.dart`
/// existiert noch nicht, und dieser Import schlägt deshalb fehl — das ist
/// der erwartete RED-Zustand.
///
/// Die Vorlage in einem Satz: "Trägt man iPhone und Watch, zählen beide. Es
/// gilt der höhere Wert, nicht die Summe. Siehe SPEC 4.6." Der Schlüssel ist
/// laut Schnittstelle der ISO-Tagesstring aus `BerlinCalendar.dayKey`
/// (`yyyy-MM-dd`) — `StepMerge` selbst rechnet nicht mit Daten, sondern nur
/// mit diesen bereits gebildeten Schlüsseln. Ein eigener Import von
/// `BerlinCalendar` ist deshalb hier nicht nötig: die Schlüssel werden in
/// den Tests als literale ISO-Strings vorgegeben, genau wie im Pflichtfall
/// aus dem Task-Brief.
void main() {
  group('Pflichtfälle aus dem Task-Brief (Werte wörtlich übernommen)', () {
    test(
      'iPhone und Watch werden nicht summiert, es gilt der hoehere Wert',
      () {
        final merged = StepMerge.daily([
          {'2026-10-23': 8000},
          {'2026-10-23': 9500},
        ]);
        // 9500, nicht 17500: das ist der ganze Zweck von StepMerge (SPEC
        // 4.6) — eine Summe würde doppelt gezählte Schritte vortäuschen.
        expect(merged['2026-10-23'], 9500);
      },
    );

    test('Tage, die nur eine Quelle kennt, bleiben erhalten', () {
      final merged = StepMerge.daily([
        {'2026-10-20': 5000, '2026-10-21': 6000},
        {'2026-10-21': 7000, '2026-10-22': 3000},
      ]);
      // 10-20 kennt nur die erste Quelle, 10-22 nur die zweite — beide
      // müssen im Ergebnis auftauchen, nicht nur der gemeinsame Tag 10-21
      // (dort gewinnt wie im ersten Pflichtfall der höhere Wert, 7000).
      expect(merged, {
        '2026-10-20': 5000,
        '2026-10-21': 7000,
        '2026-10-22': 3000,
      });
    });
  });

  group('Rand- und Mehrquellen-Faelle', () {
    test('leere Quellenliste ergibt eine leere Abbildung, keinen Absturz', () {
      expect(StepMerge.daily([]), isEmpty);
    });

    test(
      'eine Quelle mit leerer Tagesabbildung traegt nichts bei und stoert '
      'die anderen Quellen nicht',
      () {
        final merged = StepMerge.daily([
          {},
          {'2026-10-23': 4000},
          {},
        ]);
        expect(merged, {'2026-10-23': 4000});
      },
    );

    test('eine einzelne Quelle wird unveraendert uebernommen', () {
      final merged = StepMerge.daily([
        {'2026-10-23': 4200, '2026-10-24': 1000},
      ]);
      expect(merged, {'2026-10-23': 4200, '2026-10-24': 1000});
    });

    test(
      'drei Quellen statt zwei: der hoechste Wert gewinnt, unabhaengig von '
      'seiner Position in der Liste',
      () {
        // Das Maximum steht absichtlich in der Mitte, nicht am Rand — eine
        // Implementierung, die nur erste und letzte Quelle vergleicht (statt
        // wirklich über alle zu falten), fiele hier auf.
        final merged = StepMerge.daily([
          {'2026-10-23': 3000},
          {'2026-10-23': 9000},
          {'2026-10-23': 5000},
        ]);
        expect(merged['2026-10-23'], 9000);
      },
    );

    test(
      'eine Quelle mit 0 gegen eine Quelle mit echtem Wert: der echte Wert '
      'gewinnt, unabhaengig von der Reihenfolge',
      () {
        // 0 ist ein echter, gemeldeter Wert (z. B. Watch nicht getragen),
        // keine fehlende Angabe — er darf den höheren Wert der anderen
        // Quelle nicht verdraengen, und zwar unabhaengig davon, ob die
        // 0-Quelle zuerst oder zuletzt in der Liste steht. Eine
        // Implementierung, die faelschlich den *letzten* statt den
        // *hoechsten* Wert behielte, würde genau hier in einer der beiden
        // Reihenfolgen durchfallen.
        final nullZuerst = StepMerge.daily([
          {'2026-10-23': 0},
          {'2026-10-23': 6500},
        ]);
        expect(nullZuerst['2026-10-23'], 6500);

        final nullZuletzt = StepMerge.daily([
          {'2026-10-23': 6500},
          {'2026-10-23': 0},
        ]);
        expect(nullZuletzt['2026-10-23'], 6500);
      },
    );

    test(
      'mehrere Tage ueber mehrere Quellen hinweg werden unabhaengig '
      'voneinander gemergt',
      () {
        final merged = StepMerge.daily([
          {'2026-10-20': 1000, '2026-10-21': 8000, '2026-10-22': 2000},
          {'2026-10-20': 1500, '2026-10-21': 7000, '2026-10-23': 6000},
        ]);
        expect(merged, {
          '2026-10-20': 1500, // Maximum von 1000/1500
          '2026-10-21': 8000, // Maximum von 8000/7000
          '2026-10-22': 2000, // nur in Quelle 1
          '2026-10-23': 6000, // nur in Quelle 2
        });
      },
    );
  });
}
