import Foundation
import Testing
@testable import TrainingsCore

@Suite("Schritte aus mehreren Quellen")
struct StepMergeTests {

    private let day = Date(timeIntervalSince1970: 1_760_227_200)
    private let other = Date(timeIntervalSince1970: 1_760_313_600)

    // Review Focus 5
    @Test("Für denselben Tag zählt der höhere Wert, nicht die Summe")
    func takesHigherNotSum() {
        let merged = StepMerge.daily(perSource: [[day: 8_000], [day: 10_613]])
        #expect(merged[day] == 10_613)
    }

    @Test("Auch bei drei Quellen gilt der höchste Wert")
    func takesHighestOfThree() {
        let merged = StepMerge.daily(perSource: [[day: 8_000], [day: 10_613], [day: 9_400]])
        #expect(merged[day] == 10_613)
    }

    @Test("Ein Tag nur in einer Quelle bleibt erhalten")
    func keepsSingleSourceDay() {
        let merged = StepMerge.daily(perSource: [[day: 8_000], [other: 10_613]])
        #expect(merged[day] == 8_000)
        #expect(merged[other] == 10_613)
    }

    @Test("Ohne Quellen kommt nichts heraus")
    func emptyStaysEmpty() {
        #expect(StepMerge.daily(perSource: []).isEmpty)
    }
}
