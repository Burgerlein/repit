import Testing
@testable import TrainingsCore

@Suite("Leere Antworten aus HealthKit")
struct DataStateTests {

    // Review Focus 1
    @Test("Eine leere Liste ist nicht dasselbe wie null Schritte")
    func emptyIsAmbiguous() {
        let empty: [Int] = []
        #expect(empty.dataState == DataState<[Int]>.emptyOrUnauthorized)
    }

    @Test("Eine gefüllte Liste wird durchgereicht")
    func filledIsData() {
        #expect([1, 2].dataState == DataState<[Int]>.data([1, 2]))
    }
}
