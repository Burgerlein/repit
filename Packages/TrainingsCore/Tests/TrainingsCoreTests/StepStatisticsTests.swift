import Foundation
import Testing
@testable import TrainingsCore

@Suite("Schritt-Kennzahlen")
struct StepStatisticsTests {

    /// Samstag, 03.10.2026, 06:00 Berliner Zeit. Ein fester Zeitpunkt, damit
    /// das Fenster nicht vom Tag des Testlaufs abhängt. Die 30 Tage davor
    /// liegen vollständig in der Sommerzeit — die Umstellung am 25.10.2026
    /// fällt also in keinen der Abstände hinein.
    private let now = Date(timeIntervalSince1970: 1_791_000_000)

    private func day(_ daysAgo: Int, _ steps: Int?) -> DailyMetrics {
        DailyMetrics(date: BerlinCalendar.calendar.date(byAdding: .day,
                                                        value: -daysAgo, to: now)!,
                     steps: steps)
    }

    @Test("Gestern ist der Wert von gestern, nicht der von heute")
    func yesterdayIsYesterday() {
        let stats = StepStatistics.make([day(0, 2_000), day(1, 10_613)],
                                        goal: 8_000, now: now)
        #expect(stats.yesterday == 10_613)
    }

    @Test("Der Sieben-Tage-Schnitt mittelt die letzten sieben Tage ohne heute")
    func sevenDayAverageExcludesToday() {
        // Gestern bis vor sieben Tagen je 7.000, heute 100. Der laufende Tag
        // ist noch nicht vorbei und zöge jeden Durchschnitt nach unten.
        var days = [day(0, 100)]
        days += (1...7).map { day($0, 7_000) }
        let stats = StepStatistics.make(days, goal: 8_000, now: now)
        #expect(stats.average7 == 7_000)
    }

    @Test("Fehlende Tage drücken den Schnitt nicht")
    func missingDaysDoNotLowerTheAverage() {
        // Drei Tage mit 9.000, vier Tage ohne Wert. Ein Tag ohne Messung ist
        // kein Tag mit null Schritten — die Uhr war aus, mehr nicht.
        var days = (1...3).map { day($0, 9_000) }
        days += (4...7).map { day($0, nil) }
        let stats = StepStatistics.make(days, goal: 8_000, now: now)
        #expect(stats.average7 == 9_000)
    }

    @Test("Fehlende Tage zählen nicht als verfehltes Ziel")
    func missingDaysAreNotMissedGoals() {
        var days = (1...3).map { day($0, 9_000) }
        days += (4...30).map { day($0, nil) }
        let stats = StepStatistics.make(days, goal: 8_000, now: now)
        #expect(stats.goalReached == 3)
        // Nenner für „Ziel erreicht x von y" ist die Zahl der Tage mit Daten,
        // nicht 30.
        #expect(stats.daysWithData == 3)
    }

    @Test("Genau das Ziel gilt als erreicht")
    func exactlyTheGoalCounts() {
        let stats = StepStatistics.make([day(1, 8_000)], goal: 8_000, now: now)
        #expect(stats.goalReached == 1)
    }

    @Test("Der Trend vergleicht die letzten sieben Tage mit den sieben davor")
    func trendComparesTwoWeeks() throws {
        var days = (1...7).map { day($0, 8_480) }     // letzte Woche
        days += (8...14).map { day($0, 8_000) }       // Woche davor
        let stats = StepStatistics.make(days, goal: 8_000, now: now)
        // (8.480 − 8.000) / 8.000 = 0,06
        let trend = try #require(stats.trendPercent)
        #expect(abs(trend - 6.0) < 0.001)
    }

    @Test("Ohne Vorwoche gibt es keinen Trend")
    func noPreviousWeekMeansNoTrend() {
        // Kein Vergleichswert heißt kein Trend — und nicht „0 Prozent".
        let days = (1...7).map { day($0, 8_480) }
        #expect(StepStatistics.make(days, goal: 8_000, now: now).trendPercent == nil)
    }

    @Test("Der beste Tag ist der höchste Wert im Fenster")
    func bestIsTheHighestInTheWindow() {
        var days = (1...30).map { day($0, 7_000) }
        days[12] = day(13, 14_902)      // Feld 12 ist der Tag mit Abstand 13.
        let stats = StepStatistics.make(days, goal: 8_000, now: now)
        #expect(stats.best == 14_902)
    }

    @Test("Ganz ohne Daten bleibt alles leer statt null")
    func noDataLeavesEverythingEmpty() {
        let stats = StepStatistics.make([], goal: 8_000, now: now)
        #expect(stats.yesterday == nil)
        #expect(stats.average7 == nil)
        #expect(stats.average30 == nil)
        #expect(stats.trendPercent == nil)
        #expect(stats.best == nil)
        #expect(stats.goalReached == 0)
        #expect(stats.daysWithData == 0)
    }

    @Test("Tage älter als 30 Tage zählen nicht mehr")
    func olderThanThirtyDaysIsOutside() {
        // Abstand 31 liegt außerhalb; das Fenster ist Abstand 1 bis 30.
        let stats = StepStatistics.make([day(31, 20_000), day(1, 5_000)],
                                        goal: 8_000, now: now)
        #expect(stats.best == 5_000)
        #expect(stats.daysWithData == 1)
    }
}
