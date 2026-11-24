import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Laufkadenz** aus Ticket #95 — `docs/SPEC.md` 4.7
/// („Laufkadenz in Schritten pro Minute, aus Geschwindigkeit und
/// Schrittlänge der Watch oder aus Schrittzahl und Dauer. Zielkorridor
/// 165–175").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/RunningCadence.swift`
/// samt `Tests/TrainingsCoreTests/RunningCadenceTests.swift` — die Doppelung
/// Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist Absicht").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Swift überlädt `stepsPerMinute` zweimal; Dart kennt keine Überladung,
/// deshalb zwei Namen:
///
/// ```dart
/// /// Einordnung gegen den Zielkorridor. Top-Level, weil Dart keine in
/// /// Klassen geschachtelten Enums kennt (Swift: `RunningCadence.Rating`).
/// enum CadenceRating { tooLow, inRange, aboveRange }
///
/// abstract final class RunningCadence {
///   /// Zielkorridor 165–175, beide Grenzen einschließlich.
///   static const double targetLowerBound = 165;
///   static const double targetUpperBound = 175;
///
///   /// Aus Schrittzahl und Dauer, auf eine Nachkommastelle gerundet.
///   /// `null` bei steps ≤ 0 oder minutes ≤ 0.
///   static double? stepsPerMinute({required int steps, required double minutes});
///
///   /// Aus Geschwindigkeit und Schrittlänge der Watch, auf eine
///   /// Nachkommastelle gerundet. `null`, wenn eine der beiden ≤ 0 ist.
///   static double? stepsPerMinuteFromStride({
///     required double speedMetersPerSecond,
///     required double strideLengthMeters,
///   });
///
///   static CadenceRating rating(double cadence);
/// }
/// ```
///
/// **Alle Zahlen sind erfunden** — keine Werte aus Tims Läufen.
void main() {
  group('Aus Schritten und Dauer', () {
    test('5.200 Schritte in 30 Minuten sind 173,3', () {
      expect(RunningCadence.stepsPerMinute(steps: 5200, minutes: 30), 173.3);
    });

    test('das Ergebnis trägt genau eine Nachkommastelle', () {
      // 4.000 / 25 = 160,0 — glatt, aber als gerundeter Wert.
      final c = RunningCadence.stepsPerMinute(steps: 4000, minutes: 25);
      expect(c, isNotNull);
      expect(c!, closeTo(160.0, 1e-9));
    });

    test('ohne Dauer kein Ergebnis', () {
      expect(RunningCadence.stepsPerMinute(steps: 5000, minutes: 0), isNull);
    });

    test('ohne Schritte kein Ergebnis', () {
      expect(RunningCadence.stepsPerMinute(steps: 0, minutes: 30), isNull);
      expect(RunningCadence.stepsPerMinute(steps: -100, minutes: 30), isNull);
    });
  });

  group('Aus Geschwindigkeit und Schrittlänge', () {
    test('2,7 m/s bei 0,95 m Schrittlänge sind 170,5', () {
      // 2,7 / 0,95 · 60 = 170,526… → eine Nachkommastelle: 170,5.
      final c = RunningCadence.stepsPerMinuteFromStride(
        speedMetersPerSecond: 2.7,
        strideLengthMeters: 0.95,
      );
      expect(c, isNotNull);
      expect(c!, closeTo(170.5, 1e-9));
    });

    test('ohne Schrittlänge kein Ergebnis', () {
      expect(
        RunningCadence.stepsPerMinuteFromStride(
          speedMetersPerSecond: 2.7,
          strideLengthMeters: 0,
        ),
        isNull,
      );
    });

    test('ohne Geschwindigkeit kein Ergebnis', () {
      expect(
        RunningCadence.stepsPerMinuteFromStride(
          speedMetersPerSecond: 0,
          strideLengthMeters: 0.95,
        ),
        isNull,
      );
    });
  });

  group('Einordnung gegen den Zielkorridor 165 bis 175', () {
    test('mitten im Korridor', () {
      expect(RunningCadence.rating(170), CadenceRating.inRange);
    });

    test('darunter und darüber', () {
      expect(RunningCadence.rating(158), CadenceRating.tooLow);
      expect(RunningCadence.rating(182), CadenceRating.aboveRange);
    });

    test('die Grenzen selbst liegen im Korridor', () {
      // Swift nutzt einen ClosedRange — 165 und 175 gehören dazu.
      expect(RunningCadence.rating(165), CadenceRating.inRange);
      expect(RunningCadence.rating(175), CadenceRating.inRange);
    });

    test('knapp außerhalb der Grenzen kippt die Einordnung', () {
      expect(RunningCadence.rating(164.9), CadenceRating.tooLow);
      expect(RunningCadence.rating(175.1), CadenceRating.aboveRange);
    });

    test('der Korridor ist als Konstanten benannt', () {
      expect(RunningCadence.targetLowerBound, 165);
      expect(RunningCadence.targetUpperBound, 175);
    });
  });
}
