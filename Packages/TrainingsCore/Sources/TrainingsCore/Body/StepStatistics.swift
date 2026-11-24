import Foundation

public struct StepStats: Equatable, Sendable {
    public let yesterday: Int?
    public let average7: Int?
    /// Veränderung des Sieben-Tage-Schnitts gegen die sieben Tage davor,
    /// in Prozent. `nil`, wenn es die Vorwoche nicht gibt.
    public let trendPercent: Double?
    public let average30: Int?
    public let goalReached: Int
    /// Nenner für „Ziel erreicht x von y". Nicht 30: Tage ohne Messung sind
    /// keine Tage mit null Schritten.
    public let daysWithData: Int
    public let best: Int?

    public init(yesterday: Int?, average7: Int?, trendPercent: Double?,
                average30: Int?, goalReached: Int, daysWithData: Int, best: Int?) {
        self.yesterday = yesterday
        self.average7 = average7
        self.trendPercent = trendPercent
        self.average30 = average30
        self.goalReached = goalReached
        self.daysWithData = daysWithData
        self.best = best
    }
}

public enum StepStatistics {

    /// Fenster ist gestern rückwärts. Der laufende Tag bleibt außen vor — er
    /// ist noch nicht vorbei und zöge jeden Durchschnitt nach unten.
    public static func make(_ daily: [DailyMetrics], goal: Int,
                            now: Date) -> StepStats {
        let calendar = BerlinCalendar.calendar
        let today = BerlinCalendar.startOfDay(now)

        /// Schritte je Tagesabstand: 1 ist gestern.
        var byOffset: [Int: Int] = [:]
        for entry in daily {
            guard let steps = entry.steps else { continue }
            let day = BerlinCalendar.startOfDay(entry.date)
            guard let offset = calendar.dateComponents([.day], from: day,
                                                       to: today).day,
                  offset >= 1
            else { continue }
            byOffset[offset] = steps
        }

        func values(_ range: ClosedRange<Int>) -> [Int] {
            range.compactMap { byOffset[$0] }
        }
        func average(_ list: [Int]) -> Int? {
            guard !list.isEmpty else { return nil }
            return Int((Double(list.reduce(0, +)) / Double(list.count)).rounded())
        }

        let lastWeek = values(1...7)
        let weekBefore = values(8...14)
        let month = values(1...30)

        var trend: Double?
        if let now7 = average(lastWeek), let before = average(weekBefore), before > 0 {
            trend = (Double(now7) - Double(before)) / Double(before) * 100
        }

        return StepStats(
            yesterday: byOffset[1],
            average7: average(lastWeek),
            trendPercent: trend,
            average30: average(month),
            goalReached: month.filter { $0 >= goal }.count,
            daysWithData: month.count,
            best: month.max())
    }
}
