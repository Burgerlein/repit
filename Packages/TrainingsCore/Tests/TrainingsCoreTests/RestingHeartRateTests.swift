import Testing
@testable import TrainingsCore

@Suite("Ruhepuls")
struct RestingHeartRateTests {

    @Test("Ein manuell gesetzter Wert hat Vorrang")
    func manualWins() {
        let r = RestingHeartRate.value(manual: 58, recent: [70, 71, 72, 73, 74])
        #expect(r.bpm == 58)
        #expect(r.source == .manual)
    }

    @Test("Der Median der letzten Werte wird genommen")
    func usesMedian() {
        let r = RestingHeartRate.value(manual: nil, recent: [60, 61, 62, 63, 90])
        #expect(r.bpm == 62)
        #expect(r.source == .median(5))
    }

    // Review Focus 3
    @Test("Unter fünf Werten gilt der Rückfallwert")
    func fallsBackBelowFiveSamples() {
        let r = RestingHeartRate.value(manual: nil, recent: [60, 61, 62, 63])
        #expect(r.bpm == 64)
        #expect(r.source == .estimate)
    }
}
