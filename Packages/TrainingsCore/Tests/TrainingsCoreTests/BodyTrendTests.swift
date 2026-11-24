import Foundation
import Testing
@testable import TrainingsCore

@Suite("Gewichtstrend und Eiweißziel")
struct BodyTrendTests {

    private let now = Date(timeIntervalSince1970: 1_791_000_000)  // 03.10.2026, 06:00 Berliner Zeit

    private func point(_ daysAgo: Int, _ kg: Double) -> MeasurementPoint {
        MeasurementPoint(date: BerlinCalendar.calendar.date(byAdding: .day,
                                                            value: -daysAgo, to: now)!,
                         value: kg)
    }

    @Test("Ein halbes Kilo in sieben Tagen sind 0,5 kg pro Woche")
    func slopeIsPerWeek() throws {
        let trend = try #require(BodyTrend.perWeek([point(0, 71.0), point(7, 70.5)],
                                                   now: now))
        #expect(abs(trend - 0.5) < 0.001)
    }

    @Test("Abnehmen ergibt eine negative Steigung")
    func losingWeightIsNegative() throws {
        let trend = try #require(BodyTrend.perWeek([point(0, 70.0), point(14, 71.0)],
                                                   now: now))
        #expect(abs(trend - (-0.5)) < 0.001)
    }

    @Test("Die Regression mittelt Ausreißer heraus")
    func regressionSmoothsOutliers() throws {
        // Gerade von 70,0 auf 71,2 in 28 Tagen = 0,3 kg/Woche, mit einem
        // Ausreißer, der die Steigung nicht umwerfen darf.
        let points = [point(0, 71.2), point(7, 70.9), point(14, 70.0),
                      point(21, 70.3), point(28, 70.0)]
        let trend = try #require(BodyTrend.perWeek(points, now: now))
        #expect(trend > 0.1 && trend < 0.45)
    }

    // Review Focus 1
    @Test("Ein einzelner Messpunkt ergibt keinen Trend")
    func onePointHasNoTrend() {
        #expect(BodyTrend.perWeek([point(0, 71.0)], now: now) == nil)
        #expect(BodyTrend.perWeek([], now: now) == nil)
    }

    // Senkrechte Punktwolke: die Steigung wäre unendlich, also gibt es keine.
    @Test("Mehrere Messungen am selben Tag ergeben keinen Trend")
    func sameDayMeasurementsHaveNoTrend() {
        #expect(BodyTrend.perWeek([point(0, 71.0), point(0, 71.4)], now: now) == nil)
    }

    @Test("Messungen außerhalb des Fensters zählen nicht")
    func oldPointsAreOutsideTheWindow() {
        // Nur ein Punkt liegt in den letzten 6 Wochen, der andere weit davor.
        #expect(BodyTrend.perWeek([point(0, 71.0), point(90, 60.0)], now: now) == nil)
    }

    @Test("Die Bewertung folgt dem Zielbereich der Spec")
    func ratingFollowsTheSpec() {
        #expect(BodyTrend.rating(-0.1) == .losing)
        #expect(BodyTrend.rating(0.0) == .slow)
        #expect(BodyTrend.rating(0.09) == .slow)
        #expect(BodyTrend.rating(0.1) == .good)
        #expect(BodyTrend.rating(0.25) == .good)
        #expect(BodyTrend.rating(0.26) == .fast)
    }

    @Test("Das Eiweißziel sind 1,6 bis 2,0 Gramm je Kilo")
    func proteinTargetIsPerKilo() throws {
        let range = try #require(ProteinTarget.grams(weightKg: 71.2))
        #expect(range == 114...142)
    }

    @Test("Ohne sinnvolles Gewicht gibt es kein Eiweißziel")
    func proteinTargetNeedsAWeight() {
        #expect(ProteinTarget.grams(weightKg: 0) == nil)
        #expect(ProteinTarget.grams(weightKg: -5) == nil)
    }
}
