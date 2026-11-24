import Testing
@testable import TrainingsCore

@Suite("Geschätztes Einwiederholungsmaximum")
struct OneRepMaxTests {

    @Test("Epley: 50 kg mal 10 Wiederholungen ergibt rund 66,7 kg")
    func epleyExample() {
        let v = OneRepMax.epley(weight: 50, reps: 10)
        #expect(v != nil)
        #expect(abs(v! - 66.7) < 0.05)
    }

    // Ein Satz mit einer Wiederholung *ist* das Maximum — gemessen, nicht
    // geschätzt. Die Formel ergäbe hier 62 und läge damit 3,3 % über einem
    // tatsächlich bewegten Gewicht. Das ist der einzige Fall, in dem die
    // Schätzung überprüfbar ist, und ausgerechnet dort wäre sie daneben.
    @Test("Eine einzelne Wiederholung ist das Gewicht selbst")
    func singleRepIsTheWeight() {
        #expect(OneRepMax.epley(weight: 60, reps: 1) == 60)
    }

    // Bei Unterstützung ist das Gewicht negativ; was tatsächlich gehoben wird,
    // hinge vom Körpergewicht ab. Lieber nichts sagen als raten.
    @Test("Bei Unterstützung gibt es keine Schätzung")
    func assistedHasNoEstimate() {
        #expect(OneRepMax.epley(weight: -27, reps: 10) == nil)
    }

    @Test("Null Wiederholungen oder null Gewicht ergeben nichts")
    func rejectsEmpty() {
        #expect(OneRepMax.epley(weight: 50, reps: 0) == nil)
        #expect(OneRepMax.epley(weight: 0, reps: 10) == nil)
    }

    @Test("Aus einer Sitzung zählt der beste Satz")
    func bestOfSession() {
        let session = [CompletedSet(weight: 50, reps: 10),
                       CompletedSet(weight: 55, reps: 6)]
        // 50·(1+10/30) = 66,67 gegen 55·(1+6/30) = 66,0
        let v = OneRepMax.best(in: session)
        #expect(abs(v! - 66.7) < 0.05)
    }

    @Test("Vier Trainings ohne Anstieg sind ein Plateau")
    func plateauDetected() {
        let flat = [[CompletedSet(weight: 50, reps: 10)],
                    [CompletedSet(weight: 50, reps: 10)],
                    [CompletedSet(weight: 50, reps: 10)],
                    [CompletedSet(weight: 50, reps: 10)]]
        #expect(OneRepMax.isPlateau(flat))
    }

    @Test("Mit Anstieg ist es kein Plateau")
    func risingIsNoPlateau() {
        let rising = [[CompletedSet(weight: 55, reps: 10)],
                      [CompletedSet(weight: 52.5, reps: 10)],
                      [CompletedSet(weight: 50, reps: 10)],
                      [CompletedSet(weight: 50, reps: 9)]]
        #expect(OneRepMax.isPlateau(rising) == false)
    }

    @Test("Unter vier Trainings wird kein Plateau gemeldet")
    func needsFourSessions() {
        let three = [[CompletedSet(weight: 50, reps: 10)],
                     [CompletedSet(weight: 50, reps: 10)],
                     [CompletedSet(weight: 50, reps: 10)]]
        #expect(OneRepMax.isPlateau(three) == false)
    }
}
