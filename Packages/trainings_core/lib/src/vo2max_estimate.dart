import 'dart:math';

/// Eigene VO₂max-Schätzung aus einer tatsächlich gelaufenen Leistung.
///
/// Ergänzt den Wert der Apple Watch, ersetzt ihn nicht. Die Watch schätzt nur
/// bei Aktivitäten draußen mit GPS und reagiert träge; diese Schätzung
/// entsteht aus jedem Lauf, dessen Distanz und Dauer bekannt sind.
///
/// Verfahren nach Daniels und Gilbert. Beide Werte sind Schätzungen, kein
/// Labortest — die Laufökonomie geht nicht ein, und bei Einsteigern fällt sie
/// stark ins Gewicht.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/VO2MaxEstimate.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
abstract final class VO2MaxEstimate {
  /// Unter dieser Laufdauer dominiert die anaerobe Leistung und die Formel
  /// überschätzt grob.
  static const double minimumMinutes = 3;

  /// Geschätzte VO₂max in ml/kg/min aus [km] und [minutes], auf eine
  /// Nachkommastelle gerundet (kaufmännisch, wie Swifts `rounded()`).
  /// `null` bei km ≤ 0 oder minutes < [minimumMinutes].
  static double? fromRun({required double km, required double minutes}) {
    if (km <= 0 || minutes < minimumMinutes) return null;

    final metersPerMinute = km * 1000 / minutes;

    // Sauerstoffaufnahme bei dieser Geschwindigkeit.
    final oxygenCost = -4.60 +
        0.182258 * metersPerMinute +
        0.000104 * metersPerMinute * metersPerMinute;

    // Anteil der VO₂max, den man über diese Dauer halten kann.
    final fraction = 0.8 +
        0.1894393 * exp(-0.012778 * minutes) +
        0.2989558 * exp(-0.1932605 * minutes);

    if (fraction <= 0) return null;
    final vdot = oxygenCost / fraction;
    if (!vdot.isFinite || vdot <= 0) return null;
    return (vdot * 10).round() / 10;
  }
}
