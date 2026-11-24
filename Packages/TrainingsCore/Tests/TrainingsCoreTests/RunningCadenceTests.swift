import Testing
@testable import TrainingsCore

@Suite("Laufkadenz")
struct RunningCadenceTests {

    @Test("Aus Schritten und Dauer")
    func fromStepsAndDuration() {
        #expect(RunningCadence.stepsPerMinute(steps: 5_200, minutes: 30) == 173.3)
    }

    // Tims Zielkorridor laut SPEC 4.9: 165–175 Schritte pro Minute.
    @Test("Aus Geschwindigkeit und Schrittlänge")
    func fromSpeedAndStride() {
        // 2,7 m/s bei 0,95 m Schrittlänge
        let c = RunningCadence.stepsPerMinute(speedMetersPerSecond: 2.7,
                                              strideLengthMeters: 0.95)
        #expect(c != nil)
        #expect(abs(c! - 170.5) < 0.2)
    }

    @Test("Ohne Schrittlänge kein Ergebnis")
    func rejectsZeroStride() {
        #expect(RunningCadence.stepsPerMinute(speedMetersPerSecond: 2.7,
                                              strideLengthMeters: 0) == nil)
    }

    @Test("Ohne Dauer kein Ergebnis")
    func rejectsZeroDuration() {
        #expect(RunningCadence.stepsPerMinute(steps: 5_000, minutes: 0) == nil)
    }

    @Test("Einordnung gegen den Zielkorridor 165 bis 175")
    func ratesAgainstTargetRange() {
        #expect(RunningCadence.rating(170) == .inRange)
        #expect(RunningCadence.rating(158) == .tooLow)
        #expect(RunningCadence.rating(182) == .aboveRange)
    }
}
