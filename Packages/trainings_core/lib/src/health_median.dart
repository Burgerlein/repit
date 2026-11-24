/// Der eigene Normalbereich ist ein Median, kein Durchschnitt: Eine einzelne
/// durchzechte Nacht soll die Schwelle der nächsten vier Wochen nicht
/// verschieben.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RecoveryBaseline+Median.swift`.
abstract final class HealthMedian {
  /// Wie viele der **jüngsten** Werte zählen. Gemeint sind Werte, nicht
  /// Kalendertage — die Lücken sind vorher heraus (siehe
  /// `RecoveryBaseline.from`).
  static const int defaultWindow = 30;

  /// Darunter gibt es keinen Median, sondern `null`. Vier Nächte sind kein
  /// Normalbereich, und eine Schwelle aus zwei Werten wäre eine Behauptung.
  static const int defaultMinimumSamples = 5;

  /// Der Median der letzten `window` Werte, oder `null`, wenn weniger als
  /// `minimumSamples` übrig bleiben.
  ///
  /// Die **jüngsten** Werte stehen am Ende der Liste; geschnitten wird
  /// deshalb vorne. Bei gerader Anzahl gewinnt der **obere** der beiden
  /// mittleren — dieselbe Regel wie in `RestingHeartRate`, damit zwei
  /// Stellen der App nicht verschieden runden.
  static double? value(
    List<double> samples, {
    int window = defaultWindow,
    int minimumSamples = defaultMinimumSamples,
  }) {
    final recent = samples.length > window
        ? samples.sublist(samples.length - window)
        : samples;
    if (recent.length < minimumSamples) return null;
    final sorted = [...recent]..sort();
    return sorted[sorted.length ~/ 2];
  }
}
