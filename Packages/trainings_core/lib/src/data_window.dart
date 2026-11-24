import 'berlin_calendar.dart';

/// From when the app looks at data.
///
/// Two jobs in one value: it says from when to **query**, and it clips what
/// gets **computed and drawn**. Both must be the same boundary, or a chart
/// would show days that no calculation knows about.
///
/// The boundary is day-precise, not second-precise. A date the user picked
/// means the whole day — a reading from 06:40 must not fall out just
/// because the setting was made at 23:30. Every day boundary therefore goes
/// through [BerlinCalendar], never through arithmetic with a fixed 24-hour
/// duration: on 2026-03-29 the day has 23 hours, on 2026-10-25 it has 25.
///
/// Dart counterpart to
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/DataWindow.swift`.
final class DataWindow {
  /// Normalizes immediately to the start of day. After that, no call site
  /// can accidentally compare against the time of day the user never meant
  /// — and two boundaries on the same calendar day are equal.
  DataWindow({DateTime? start})
    : start = start == null ? null : BerlinCalendar.startOfDay(start);

  /// `null` means: no boundary.
  final DateTime? start;

  static final DataWindow unlimited = DataWindow(start: null);

  /// Is the day of this moment within the window? Day starts are compared,
  /// not moments.
  bool contains(DateTime date) {
    final start = this.start;
    if (start == null) return true;
    return !BerlinCalendar.startOfDay(date).isBefore(start);
  }

  /// Clips any list that carries a date — daily metrics, sleep nights,
  /// workout samples, measurement points, circumference entries. The date
  /// accessor is passed in as a function rather than a fixed field, because
  /// the date field is named differently across those types.
  ///
  /// This is the **one** place that enforces the boundary: applied right
  /// after fetching, before anything derived. After that, no formula needs
  /// to know about the boundary, and no screen can forget it.
  List<T> clip<T>(List<T> items, DateTime Function(T item) datum) {
    final start = this.start;
    if (start == null) return items;
    return items.where((item) => contains(datum(item))).toList();
  }

  /// From when to query. `floor` is the oldest the source can give; asking
  /// further back than that brings nothing.
  DateTime queryStart({required DateTime floor}) {
    final start = this.start;
    if (start == null) return floor;
    return start.isAfter(floor) ? start : floor;
  }

  /// How many days the boundary spans, boundary day and end day included.
  /// `null` without a boundary — then there is no number that would be
  /// correct.
  int? dayCount({DateTime? through}) {
    final start = this.start;
    if (start == null) return null;
    final end = through ?? DateTime.now();
    // A boundary after the end day is not an error, but the case "stored
    // date lies in the future". Zero days, no crash.
    if (start.isAfter(end)) return 0;
    return BerlinCalendar.days(from: start, through: end).length;
  }

  // The app keeps `DataWindow` in a Riverpod provider; derived providers
  // only recompute when their dependency compares unequal. Without value
  // equality, every freshly constructed `DataWindow` would be unequal to
  // every other one, no matter how equal its day is — the bug this rebuild
  // is built against (see #56). `hashCode` must agree with `==`,
  // since the boundary is normalized to the start of day in the
  // constructor, comparing `start` alone is enough for both.
  @override
  bool operator ==(Object other) => other is DataWindow && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'DataWindow(start: $start)';
}
