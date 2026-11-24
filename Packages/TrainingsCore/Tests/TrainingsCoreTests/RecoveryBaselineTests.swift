import Foundation
import Testing
@testable import TrainingsCore

@Suite("Normalbereich aus Medianen")
struct RecoveryBaselineTests {

    private func day(_ index: Int, restingHR: Int? = nil, hrvMs: Double? = nil,
                     respRate: Double? = nil) -> DailyMetrics {
        DailyMetrics(date: Date(timeIntervalSince1970: Double(index) * 86_400),
                     restingHR: restingHR, hrvMs: hrvMs, respRate: respRate)
    }

    // MARK: - Median

    @Test("Fünf Werte ergeben den mittleren")
    func medianOfFiveSamples() {
        #expect(HealthMedian.value(of: [60, 61, 62, 63, 90]) == 62)
    }

    @Test("Unter fünf Werten gibt es keinen Median")
    func belowMinimumSamples() {
        #expect(HealthMedian.value(of: [60, 61, 62, 63]) == nil)
    }

    @Test("Ohne Werte gibt es keinen Median")
    func noSamples() {
        #expect(HealthMedian.value(of: []) == nil)
    }

    @Test("Bei gerader Anzahl gilt der obere der beiden mittleren Werte")
    func evenCountTakesUpperMiddle() {
        #expect(HealthMedian.value(of: [1, 2, 3, 4, 5, 6]) == 4)
    }

    @Test("Unsortierte Werte werden vorher sortiert")
    func unsortedSamples() {
        #expect(HealthMedian.value(of: [90, 60, 63, 61, 62]) == 62)
    }

    @Test("Ein einzelner Ausreißer verschiebt den Median nicht")
    func outlierDoesNotMoveTheMedian() {
        #expect(HealthMedian.value(of: [50, 51, 52, 53, 54, 55, 500]) == 53)
    }

    @Test("Nur die letzten dreißig Werte zählen")
    func windowKeepsTheLastThirty() {
        #expect(HealthMedian.value(of: (1...40).map(Double.init)) == 26)
    }

    @Test("Genau dreißig Werte passen vollständig ins Fenster")
    func exactlyThirtySamples() {
        #expect(HealthMedian.value(of: (1...30).map(Double.init)) == 16)
    }

    @Test("Das Fenster lässt sich enger stellen")
    func customWindow() {
        #expect(HealthMedian.value(of: [10, 20, 30], window: 2, minimumSamples: 2) == 30)
    }

    @Test("Die Mindestzahl lässt sich höher stellen")
    func customMinimumSamples() {
        #expect(HealthMedian.value(of: [10, 20, 30, 40, 50], minimumSamples: 6) == nil)
    }

    @Test("Das Fenster greift vor der Mindestzahl")
    func windowAppliesBeforeMinimum() {
        #expect(HealthMedian.value(of: (1...40).map(Double.init), window: 3, minimumSamples: 5) == nil)
    }

    // MARK: - Normalbereich aus Tageswerten

    @Test("Alle vier Mediane entstehen aus den Tageswerten")
    func allFourMedians() {
        let days = [
            day(1, restingHR: 58, hrvMs: 40, respRate: 11),
            day(2, restingHR: 59, hrvMs: 42, respRate: 12),
            day(3, restingHR: 60, hrvMs: 44, respRate: 13),
            day(4, restingHR: 61, hrvMs: 46, respRate: 14),
            day(5, restingHR: 90, hrvMs: 48, respRate: 15),
        ]
        let b = RecoveryBaseline.from(days: days, sleepHours: [7, 7.5, 8, 6, 9])
        #expect(b.restingHeartRate == 60)
        #expect(b.hrv == 44)
        #expect(b.respiratoryRate == 13)
        #expect(b.sleepHours == 7.5)
    }

    @Test("Ohne Tage und ohne Schlaf bleibt der Normalbereich leer")
    func emptyInput() {
        let b = RecoveryBaseline.from(days: [], sleepHours: [])
        #expect(b.restingHeartRate == nil)
        #expect(b.hrv == nil)
        #expect(b.respiratoryRate == nil)
        #expect(b.sleepHours == nil)
    }

    @Test("Zu wenige Werte lassen nur ihr eigenes Feld leer")
    func tooFewSamplesAffectOnlyItsOwnField() {
        let days = [
            day(1, restingHR: 58, hrvMs: 40, respRate: 11),
            day(2, restingHR: 59, hrvMs: nil, respRate: 12),
            day(3, restingHR: 60, hrvMs: 44, respRate: 13),
            day(4, restingHR: 61, hrvMs: 46, respRate: 14),
            day(5, restingHR: 90, hrvMs: 48, respRate: 15),
        ]
        let b = RecoveryBaseline.from(days: days, sleepHours: [7, 7.5, 8, 6])
        #expect(b.restingHeartRate == 60)
        #expect(b.hrv == nil)
        #expect(b.respiratoryRate == 13)
        #expect(b.sleepHours == nil)
    }

    @Test("Ein Tag ganz ohne Werte zählt nirgends mit")
    func emptyDayCountsNowhere() {
        let days = [
            day(1, restingHR: 58, hrvMs: 40, respRate: 11),
            day(2),
            day(3, restingHR: 60, hrvMs: 44, respRate: 13),
            day(4, restingHR: 61, hrvMs: 46, respRate: 14),
            day(5, restingHR: 90, hrvMs: 48, respRate: 15),
        ]
        let b = RecoveryBaseline.from(days: days, sleepHours: [])
        #expect(b.restingHeartRate == nil)
        #expect(b.hrv == nil)
        #expect(b.respiratoryRate == nil)
    }

    // Review Focus: erst filtern, dann das Fenster anlegen.
    @Test("Fehlende Werte fallen vor dem Fenster heraus")
    func gapsAreRemovedBeforeTheWindow() {
        let days = (1...32).map { i in
            day(i, hrvMs: (i == 20 || i == 21) ? nil : Double(i))
        }
        let b = RecoveryBaseline.from(days: days, sleepHours: [])
        #expect(b.hrv == 16)
    }

    @Test("Ohne Lücken endet das Fenster bei den letzten dreißig Tagen")
    func windowWithoutGaps() {
        let days = (1...32).map { day($0, hrvMs: Double($0)) }
        let b = RecoveryBaseline.from(days: days, sleepHours: [])
        #expect(b.hrv == 18)
    }

    @Test("Der Ruhepuls kommt aus dem Tageswert, nicht aus HRV oder Atemfrequenz")
    func restingHeartRateComesFromItsOwnField() {
        let days = (1...5).map { day($0, restingHR: 50 + $0, hrvMs: 100, respRate: 20) }
        let b = RecoveryBaseline.from(days: days, sleepHours: [])
        #expect(b.restingHeartRate == 53)
        #expect(b.hrv == 100)
        #expect(b.respiratoryRate == 20)
    }

    @Test("Fenster und Mindestzahl lassen sich auch hier setzen")
    func customWindowAndMinimum() {
        let days = [day(1, restingHR: 60), day(2, restingHR: 70), day(3, restingHR: 80)]
        let b = RecoveryBaseline.from(days: days, sleepHours: [6, 7, 8],
                                      window: 2, minimumSamples: 2)
        #expect(b.restingHeartRate == 80)
        #expect(b.sleepHours == 8)
    }

    @Test("Der Schlaf kommt aus dem übergebenen Feld, nicht aus den Tagen")
    func sleepComesFromItsOwnArray() {
        let days = (1...5).map { day($0, restingHR: 60) }
        let b = RecoveryBaseline.from(days: days, sleepHours: [])
        #expect(b.sleepHours == nil)
        #expect(b.restingHeartRate == 60)
    }
}
