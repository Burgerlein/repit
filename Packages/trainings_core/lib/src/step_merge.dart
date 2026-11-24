/// If you wear both an iPhone and a Watch, both count steps. The higher
/// value wins, not the sum. See SPEC 4.6.
///
/// Dart counterpart to
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/StepMerge.swift`.
abstract final class StepMerge {
  /// `perSource` is one day-to-step-count mapping per data source. Keys are
  /// the ISO day string (`yyyy-MM-dd`) from `BerlinCalendar.dayKey`.
  static Map<String, int> daily(List<Map<String, int>> perSource) {
    final merged = <String, int>{};
    for (final source in perSource) {
      for (final entry in source.entries) {
        final current = merged[entry.key];
        if (current == null || entry.value > current) {
          merged[entry.key] = entry.value;
        }
      }
    }
    return merged;
  }
}
