/// Schritte pro Minute beim Laufen.
///
/// HealthKit kennt keinen Kadenz-Typ. Sie wird entweder aus Schrittzahl und
/// Dauer im Workout-Zeitraum gerechnet oder aus Geschwindigkeit und
/// Schrittlänge, die die Watch bei Outdoor-Läufen aufzeichnet.
///
/// Warum das zählt: Zu lange Schritte bei zu niedriger Kadenz belasten Waden
/// und Schienbein stärker. Zielkorridor laut SPEC: 165 bis 175.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/RunningCadence.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht"). Swift überlädt `stepsPerMinute` zweimal; Dart kennt keine
/// Überladung, deshalb zwei Namen.
library;

/// Einordnung gegen den Zielkorridor. Top-Level, weil Dart keine in Klassen
/// geschachtelten Enums kennt (Swift: `RunningCadence.Rating`).
enum CadenceRating { tooLow, inRange, aboveRange }

abstract final class RunningCadence {
  /// Zielkorridor 165–175, beide Grenzen einschließlich.
  static const double targetLowerBound = 165;
  static const double targetUpperBound = 175;

  /// Aus Schrittzahl und Dauer, auf eine Nachkommastelle gerundet
  /// (kaufmännisch, wie Swifts `rounded()`).
  /// `null` bei steps ≤ 0 oder minutes ≤ 0.
  static double? stepsPerMinute({required int steps, required double minutes}) {
    if (steps <= 0 || minutes <= 0) return null;
    return (steps / minutes * 10).round() / 10;
  }

  /// Aus Geschwindigkeit und Schrittlänge der Watch, auf eine
  /// Nachkommastelle gerundet. `null`, wenn eine der beiden ≤ 0 ist.
  static double? stepsPerMinuteFromStride({
    required double speedMetersPerSecond,
    required double strideLengthMeters,
  }) {
    if (speedMetersPerSecond <= 0 || strideLengthMeters <= 0) return null;
    return (speedMetersPerSecond / strideLengthMeters * 60 * 10).round() / 10;
  }

  static CadenceRating rating(double cadence) {
    if (cadence < targetLowerBound) return CadenceRating.tooLow;
    if (cadence > targetUpperBound) return CadenceRating.aboveRange;
    return CadenceRating.inRange;
  }
}
