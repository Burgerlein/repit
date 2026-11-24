import Foundation
import Testing
@testable import TrainingsCore

@Suite("VO₂max und Rennprognose")
struct RacePredictionTests {

    @Test("Die Einordnung folgt den Grenzen der Spec")
    func ratingFollowsTheSpec() {
        #expect(VO2MaxRating.rating(35.9) == .belowAverage)
        #expect(VO2MaxRating.rating(36) == .average)
        #expect(VO2MaxRating.rating(41.9) == .average)
        #expect(VO2MaxRating.rating(42) == .good)
        #expect(VO2MaxRating.rating(47.9) == .good)
        #expect(VO2MaxRating.rating(48) == .veryGood)
        #expect(VO2MaxRating.rating(52.9) == .veryGood)
        #expect(VO2MaxRating.rating(53) == .excellent)
    }

    @Test("Stützstellen der Tabelle werden genau getroffen")
    func tableValuesAreExact() {
        #expect(RacePrediction.halfMarathonMinutes(vdot: 40) == 111.0)
        #expect(RacePrediction.halfMarathonMinutes(vdot: 30) == 141.1)
        #expect(RacePrediction.halfMarathonMinutes(vdot: 60) == 78.4)
    }

    @Test("Zwischen den Stützstellen wird linear interpoliert")
    func valuesBetweenAreInterpolated() {
        // Mitte zwischen 40 (111,0) und 42 (106,5) ist 108,75.
        #expect(abs(RacePrediction.halfMarathonMinutes(vdot: 41) - 108.75) < 0.001)
        // Ein Viertel über 38 (115,9) Richtung 40 (111,0): 115,9 − 0,25·4,9 = 114,675
        #expect(abs(RacePrediction.halfMarathonMinutes(vdot: 38.5) - 114.675) < 0.001)
    }

    @Test("Eine höhere VO₂max ergibt nie eine langsamere Zeit")
    func higherVO2maxIsNeverSlower() {
        var previous = Double.infinity
        for step in stride(from: 28.0, through: 62.0, by: 0.5) {
            let minutes = RacePrediction.halfMarathonMinutes(vdot: step)
            #expect(minutes <= previous)
            previous = minutes
        }
    }

    // Review Focus 4: Eine fortgesetzte Gerade ergäbe irgendwann negative
    // Laufzeiten — und belegt ist die Tabelle dort ohnehin nicht.
    @Test("Außerhalb der Tabelle gelten die Randwerte")
    func outsideTheTableUsesTheEdges() {
        #expect(RacePrediction.halfMarathonMinutes(vdot: 10) == 141.1)
        #expect(RacePrediction.halfMarathonMinutes(vdot: 0) == 141.1)
        #expect(RacePrediction.halfMarathonMinutes(vdot: 99) == 78.4)
    }

    @Test("Die realistische Zeit ist das Potenzial mal 1,12")
    func realisticIsTwelvePercentSlower() {
        let potential = RacePrediction.halfMarathonMinutes(vdot: 39.2)
        let realistic = RacePrediction.realisticMinutes(vdot: 39.2)
        #expect(abs(realistic - potential * 1.12) < 0.001)
        #expect(realistic > potential)
    }
}
