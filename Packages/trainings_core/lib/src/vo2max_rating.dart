/// Einordnung für Männer 20–29 nach SPEC 4.7. Die Zahl der Watch ist eine
/// Schätzung mit mehreren Punkten Spielraum; aussagekräftig ist der Trend.
/// Die Namen sind Fachbegriffe, keine Nutzertexte — was der Schirm daraus
/// macht, entscheidet die View.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/VO2MaxRating.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
enum VO2MaxRating {
  belowAverage,
  average,
  good,
  veryGood,
  excellent;

  /// Die Grenzen aus SPEC 4.7: < 36 unterdurchschnittlich, < 42
  /// durchschnittlich, < 48 gut, < 53 sehr gut, sonst hervorragend —
  /// jede Grenze gehört zur oberen Stufe.
  static VO2MaxRating rating(double vo2max) {
    if (vo2max < 36) return belowAverage;
    if (vo2max < 42) return average;
    if (vo2max < 48) return good;
    if (vo2max < 53) return veryGood;
    return excellent;
  }
}
