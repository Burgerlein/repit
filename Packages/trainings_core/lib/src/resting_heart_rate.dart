/// Ruhepuls als Grundlage der Zonenberechnung, SPEC 4.7 („Median der letzten
/// 30 Werte oder manuell").
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RestingHeartRate.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht"). Die Medianregel (Fenster 30, mindestens 5 Werte, bei gerader
/// Anzahl der obere der beiden mittleren) ist dieselbe wie in `HealthMedian`
/// — zwei Stellen der App sollen nicht verschieden runden.
library;

/// Woher der Wert stammt — die Oberfläche muss das benennen können.
///
/// Ein sealed-Typ, damit der switch vollständig prüfbar ist; der Median
/// trägt die Zahl der Werte, aus denen er entstand. Alle drei vergleichen
/// nach Wert (== und hashCode) — der Wert landet als Provider-Abhängigkeit
/// in der App (`CLAUDE.md`, Datenschicht).
sealed class RestingHeartRateSource {
  const RestingHeartRateSource();
}

/// Von Hand eingetragen.
final class RestingManual extends RestingHeartRateSource {
  const RestingManual();

  @override
  bool operator ==(Object other) => other is RestingManual;

  @override
  int get hashCode => (RestingManual).hashCode;

  @override
  String toString() => 'RestingManual()';
}

/// Median aus [sampleCount] Messwerten.
final class RestingMedian extends RestingHeartRateSource {
  const RestingMedian(this.sampleCount);

  final int sampleCount;

  @override
  bool operator ==(Object other) =>
      other is RestingMedian && other.sampleCount == sampleCount;

  @override
  int get hashCode => Object.hash(RestingMedian, sampleCount);

  @override
  String toString() => 'RestingMedian($sampleCount)';
}

/// Allgemeine Annahme, kein Messwert — greift, solange zu wenige Messwerte
/// vorliegen.
final class RestingEstimate extends RestingHeartRateSource {
  const RestingEstimate();

  @override
  bool operator ==(Object other) => other is RestingEstimate;

  @override
  int get hashCode => (RestingEstimate).hashCode;

  @override
  String toString() => 'RestingEstimate()';
}

abstract final class RestingHeartRate {
  /// Greift, solange zu wenige Messwerte vorliegen. Eine allgemeine Annahme,
  /// kein Messwert — die Quelle [RestingEstimate] sagt das.
  static const int fallbackBpm = 64;

  static const int _minimumSamples = 5;
  static const int _window = 30;

  /// [manual] gewinnt, wenn er gesetzt und > 0 ist. Sonst der Median der
  /// letzten 30 Werte aus [recent] (jüngste am Ende, geschnitten wird vorn),
  /// sofern mindestens 5 übrig bleiben — sonst [fallbackBpm]. Bei gerader
  /// Anzahl gewinnt der obere der beiden mittleren.
  static (int bpm, RestingHeartRateSource source) value({
    int? manual,
    required List<int> recent,
  }) {
    if (manual != null && manual > 0) {
      return (manual, const RestingManual());
    }
    final samples = recent.length > _window
        ? recent.sublist(recent.length - _window)
        : recent;
    if (samples.length < _minimumSamples) {
      return (fallbackBpm, const RestingEstimate());
    }
    final sorted = [...samples]..sort();
    return (sorted[sorted.length ~/ 2], RestingMedian(sorted.length));
  }
}
