import 'berlin_calendar.dart';
import 'recovery_input.dart';

/// Die Wochenlast: Trainingsminuten der laufenden Woche, Montag bis Sonntag.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/TrainingLoad.swift`.
abstract final class TrainingLoad {
  /// Montag 00:00 bis zum darauffolgenden Montag 00:00, beides Berliner
  /// Zeit, zurückgegeben als UTC-Zeitpunkte wie bei [BerlinCalendar].
  ///
  /// Beide Grenzen laufen über den Kalender, **nie** über eine feste Dauer:
  /// Die Woche ab 23.03.2026 hat 167 Stunden, die ab 19.10.2026 hat 169.
  /// Wer sieben Mal 24 Stunden addiert, trifft in beiden Fällen die falsche
  /// Mitternacht — im Oktober fiele der Montagvormittag in die Vorwoche.
  static (DateTime start, DateTime end) weekBounds({
    required DateTime containing,
  }) {
    final start = BerlinCalendar.addDays(
      containing,
      DateTime.monday - BerlinCalendar.weekday(containing),
    );
    return (start, BerlinCalendar.addDays(start, DateTime.daysPerWeek));
  }

  /// Summe der Trainingsminuten im halboffenen Fenster
  /// `date >= start && date < end`.
  ///
  /// Tage ohne `exerciseMinutes` zählen nicht mit — und schon gar nicht als
  /// Null: Ein Tag ohne Wert ist kein Tag ohne Training.
  static double weekMinutes({
    required List<RecoveryDay> days,
    required DateTime containing,
  }) {
    final (start, end) = weekBounds(containing: containing);
    var total = 0.0;
    for (final day in days) {
      if (day.date.isBefore(start) || !day.date.isBefore(end)) continue;
      total += day.exerciseMinutes ?? 0;
    }
    return total;
  }
}
