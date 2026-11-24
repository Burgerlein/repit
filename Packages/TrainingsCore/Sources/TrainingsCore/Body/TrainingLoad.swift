import Foundation

/// Trainingsminuten der Woche. Sie stehen neben der Erholung, weil erst
/// beide zusammen etwas sagen.
public enum TrainingLoad {

    public static func weekMinutes(days: [DailyMetrics], containing day: Date) -> Double {
        let bounds = weekBounds(containing: day)
        return days
            .filter { $0.date >= bounds.start && $0.date < bounds.end }
            .compactMap(\.exerciseMinutes)
            .reduce(0, +)
    }

    /// Montag 00:00 bis zum darauffolgenden Montag 00:00.
    public static func weekBounds(containing day: Date) -> (start: Date, end: Date) {
        let calendar = BerlinCalendar.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: day)?.start
            ?? BerlinCalendar.startOfDay(day)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }
}
