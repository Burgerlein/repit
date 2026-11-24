import Foundation
import Testing
@testable import TrainingsCore

@Suite("Schlaf-Score")
struct SleepScoringTests {

    // MARK: - Nacht aus dem Prototyp

    /// Mittel genau 305 Minuten, also 23:05.
    private let fourteenNights: [Double] = [295, 300, 305, 310, 315, 300, 305,
                                            310, 300, 315, 295, 310, 305, 305]

    /// Sechs Wachphasen liegen seit der Neukalibrierung unter der Grenze und
    /// kosten nichts mehr; der Prototyp zeigt für dieselbe Nacht noch 76.
    @Test("Die Nacht aus dem Prototyp ergibt 79 von 100 Punkten")
    func prototypeNight() {
        let s = SleepScoring.score(asleepHours: 5.583, goalHours: 8,
                                   bedtimeMinutes: 323, recentBedtimeMinutes: fourteenNights,
                                   awakeMinutes: 7, wakeCount: 6)
        #expect(s.duration == 35)
        #expect(s.regularity == 24)
        #expect(s.interruptions == 20)
        #expect(s.total == 79)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .good)
    }

    // MARK: - Festwerte

    @Test("Die Regelmäßigkeit schaut auf vierzehn Nächte")
    func regularityWindowIsFourteen() {
        #expect(SleepScoring.regularityWindow == 14)
    }

    // MARK: - Dauer

    @Test("Das erreichte Ziel gibt die volle Punktzahl")
    func durationAtGoal() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 50)
    }

    @Test("Das halbe Ziel gibt die halbe Punktzahl")
    func durationAtHalfGoal() {
        let s = SleepScoring.score(asleepHours: 4, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 25)
    }

    @Test("Mehr als das Ziel gibt nicht mehr als fünfzig Punkte")
    func durationIsCappedAtFifty() {
        let s = SleepScoring.score(asleepHours: 11, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 50)
    }

    @Test("Ohne Schlaf gibt es keine Punkte für die Dauer")
    func durationWithoutSleep() {
        let s = SleepScoring.score(asleepHours: 0, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 0)
    }

    @Test("Ohne Ziel gibt es keine Punkte für die Dauer")
    func durationWithoutGoal() {
        let s = SleepScoring.score(asleepHours: 7, goalHours: 0, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 0)
    }

    @Test("Ein negatives Ziel gibt keine Punkte für die Dauer")
    func durationWithNegativeGoal() {
        let s = SleepScoring.score(asleepHours: 7, goalHours: -1, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 0)
    }

    @Test("Die Dauer wird kaufmännisch gerundet")
    func durationRoundsHalfUp() {
        let s = SleepScoring.score(asleepHours: 5.2, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.duration == 33)
    }

    // MARK: - Regelmäßigkeit

    @Test("Die übliche Einschlafzeit gibt die volle Punktzahl")
    func regularityWithoutDeviation() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 30)
    }

    @Test("Eine Viertelstunde Abweichung kostet fünf Punkte")
    func regularityWithFifteenMinutes() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 315,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 25)
    }

    @Test("Früher einschlafen kostet genauso viel wie später")
    func regularityUsesTheAbsoluteDeviation() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 285,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 25)
    }

    @Test("Neunzig Minuten Abweichung kosten alle Punkte")
    func regularityAtZero() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 390,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 0)
    }

    @Test("Noch mehr Abweichung geht nicht unter null")
    func regularityIsCappedAtZero() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 420,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 0)
    }

    @Test("Wenige frühere Nächte reichen als Referenz")
    func regularityWithShortHistory() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 305,
                                   recentBedtimeMinutes: [280, 290, 300],
                                   awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 25)
    }

    @Test("Eine einzige frühere Nacht ist schon eine Grundlage")
    func regularityWithASingleNight() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 315,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity != nil)
        #expect(s.maxTotal == 100)
    }

    // Review Focus: nur die letzten vierzehn Einträge zählen.
    @Test("Nur die letzten vierzehn Nächte zählen als Referenz")
    func regularityUsesOnlyTheLastFourteen() {
        let recent = Array(repeating: 0.0, count: 6) + Array(repeating: 300.0, count: 14)
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: recent, awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 30)
    }

    @Test("Genau vierzehn Nächte ergeben ihr Mittel")
    func regularityWithExactlyFourteen() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 305,
                                   recentBedtimeMinutes: fourteenNights,
                                   awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 30)
    }

    @Test("Einschlafen nach Mitternacht rechnet weiter hoch")
    func regularityAfterMidnight() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 390,
                                   recentBedtimeMinutes: [330], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 10)
    }

    @Test("Die Regelmäßigkeit wird kaufmännisch gerundet")
    func regularityRoundsHalfUp() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 315,
                                   recentBedtimeMinutes: [300, 303],
                                   awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == 26)
    }

    // MARK: - Fehlende Grundlage für die Regelmäßigkeit

    @Test("Ohne Einschlafzeit entfällt die Regelmäßigkeit")
    func regularityWithoutBedtime() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: fourteenNights,
                                   awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == nil)
        #expect(s.duration == 50)
        #expect(s.interruptions == 20)
    }

    @Test("Ohne frühere Nächte entfällt die Regelmäßigkeit")
    func regularityWithoutHistory() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == nil)
        #expect(s.duration == 50)
        #expect(s.interruptions == 20)
    }

    @Test("Fehlen beide Grundlagen, entfällt die Regelmäßigkeit ebenso")
    func regularityWithoutBedtimeAndWithoutHistory() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 0, wakeCount: 0)
        #expect(s.regularity == nil)
    }

    // Review Focus: eine entfallene Regelmäßigkeit zählt nicht als null mit.
    @Test("Die entfallene Regelmäßigkeit zählt nicht in der Summe mit")
    func totalSkipsTheMissingPart() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 30, wakeCount: 4)
        #expect(s.regularity == nil)
        #expect(s.duration == 50)
        #expect(s.interruptions == 10)
        #expect(s.total == 60)
        #expect(s.total == s.duration + s.interruptions)
    }

    @Test("Ohne Regelmäßigkeit sind nur siebzig Punkte erreichbar")
    func maxTotalWithoutRegularity() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 0, wakeCount: 0)
        #expect(s.maxTotal == 70)
    }

    @Test("Mit Regelmäßigkeit sind hundert Punkte erreichbar")
    func maxTotalWithRegularity() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.maxTotal == 100)
    }

    @Test("Die beste Nacht ohne Grundlage ergibt siebzig von siebzig Punkten")
    func perfectNightWithoutRegularity() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 0, wakeCount: 0)
        #expect(s.total == 70)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .veryGood)
    }

    @Test("Die schlechteste Nacht ohne Grundlage ergibt null von siebzig Punkten")
    func worstNightWithoutRegularity() {
        let s = SleepScoring.score(asleepHours: 0, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 100, wakeCount: 20)
        #expect(s.duration == 0)
        #expect(s.regularity == nil)
        #expect(s.interruptions == 0)
        #expect(s.total == 0)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .low)
    }

    // MARK: - Unterbrechungen

    @Test("Eine durchgeschlafene Nacht gibt die volle Punktzahl")
    func interruptionsWithoutAnyWaking() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.interruptions == 20)
    }

    @Test("Zehn Wachminuten und zehn Wachphasen sind noch straffrei")
    func interruptionsAtTheFreeLimit() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 10, wakeCount: 10)
        #expect(s.interruptions == 20)
    }

    @Test("Unter der Grenze gibt es keinen Bonus")
    func interruptionsBelowTheFreeLimit() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 9, wakeCount: 9)
        #expect(s.interruptions == 20)
    }

    // Review Focus: die alte Grenze von vier Phasen kostet nichts mehr.
    @Test("Sechs Wachphasen kosten nach der Neukalibrierung nichts")
    func interruptionsIgnoreSixWakePhases() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 10, wakeCount: 6)
        #expect(s.interruptions == 20)
    }

    @Test("Jede Wachminute über zehn kostet einen halben Punkt")
    func interruptionsCountAwakeMinutes() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 30, wakeCount: 4)
        #expect(s.interruptions == 10)
    }

    @Test("Die elfte Wachphase kostet einen Punkt")
    func interruptionsCountTheEleventhWakePhase() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 10, wakeCount: 11)
        #expect(s.interruptions == 19)
    }

    @Test("Jede Wachphase über zehn kostet einen Punkt")
    func interruptionsCountWakePhases() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 10, wakeCount: 16)
        #expect(s.interruptions == 14)
    }

    /// Das 90. Perzentil der gemessenen Nächte: dreizehn kurze Abschnitte,
    /// zusammen fünfzehn Wachminuten. 20 − 0,5·5 − 1,0·3 = 14,5.
    @Test("Eine echte Nacht mit dreizehn kurzen Abschnitten behält fünfzehn Punkte")
    func interruptionsOfATypicalMeasuredNight() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 15, wakeCount: 13)
        #expect(s.interruptions == 15)
    }

    @Test("Wachminuten und Wachphasen ziehen beide ab")
    func interruptionsCombineBothPenalties() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 30, wakeCount: 15)
        #expect(s.interruptions == 5)
    }

    @Test("Eine sehr unruhige Nacht geht nicht unter null")
    func interruptionsAreCappedAtZero() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 70, wakeCount: 20)
        #expect(s.interruptions == 0)
    }

    @Test("Die Unterbrechungen werden kaufmännisch gerundet")
    func interruptionsRoundHalfUp() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 11, wakeCount: 4)
        #expect(s.interruptions == 20)
    }

    @Test("Auch der abgerundete Fall wird kaufmännisch gerundet")
    func interruptionsRoundAnotherHalfUp() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 13, wakeCount: 4)
        #expect(s.interruptions == 19)
    }

    // MARK: - Summe

    @Test("Die Summe ist die Summe der vorhandenen Teile")
    func totalIsTheSumOfItsParts() throws {
        let s = SleepScoring.score(asleepHours: 5.583, goalHours: 8,
                                   bedtimeMinutes: 323, recentBedtimeMinutes: fourteenNights,
                                   awakeMinutes: 7, wakeCount: 6)
        let regularity = try #require(s.regularity)
        #expect(s.total == s.duration + regularity + s.interruptions)
    }

    // Review Focus: jeder Teil wird für sich gerundet, nicht die Summe.
    @Test("Jeder Teil wird für sich gerundet")
    func eachPartIsRoundedOnItsOwn() {
        let s = SleepScoring.score(asleepHours: 5.5, goalHours: 8, bedtimeMinutes: 301.5,
                                   recentBedtimeMinutes: [300], awakeMinutes: 11, wakeCount: 4)
        #expect(s.duration == 34)
        #expect(s.regularity == 30)
        #expect(s.interruptions == 20)
        #expect(s.total == 84)
    }

    @Test("Die beste Nacht ergibt hundert Punkte")
    func perfectNight() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 0, wakeCount: 0)
        #expect(s.total == 100)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .veryGood)
    }

    @Test("Die schlechteste Nacht ergibt null Punkte")
    func worstNight() {
        let s = SleepScoring.score(asleepHours: 0, goalHours: 8, bedtimeMinutes: 390,
                                   recentBedtimeMinutes: [300], awakeMinutes: 100, wakeCount: 20)
        #expect(s.duration == 0)
        #expect(s.regularity == 0)
        #expect(s.interruptions == 0)
        #expect(s.total == 0)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .low)
    }

    // MARK: - Bewertung über hundert erreichbare Punkte

    @Test("Genau 85 Punkte sind sehr gut")
    func ratingExactlyVeryGood() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 40, wakeCount: 4)
        #expect(s.total == 85)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .veryGood)
    }

    @Test("Knapp unter 85 Punkten ist nur noch gut")
    func ratingJustBelowVeryGood() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 300,
                                   recentBedtimeMinutes: [300], awakeMinutes: 42, wakeCount: 4)
        #expect(s.total == 84)
        #expect(s.rating == .good)
    }

    @Test("Genau 70 Punkte sind gut")
    func ratingExactlyGood() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 330,
                                   recentBedtimeMinutes: [300], awakeMinutes: 50, wakeCount: 4)
        #expect(s.total == 70)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .good)
    }

    @Test("Knapp unter 70 Punkten ist nur noch okay")
    func ratingJustBelowGood() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 333,
                                   recentBedtimeMinutes: [300], awakeMinutes: 50, wakeCount: 4)
        #expect(s.total == 69)
        #expect(s.rating == .okay)
    }

    @Test("Genau 55 Punkte sind okay")
    func ratingExactlyOkay() {
        let s = SleepScoring.score(asleepHours: 5.6, goalHours: 8, bedtimeMinutes: 330,
                                   recentBedtimeMinutes: [300], awakeMinutes: 50, wakeCount: 4)
        #expect(s.total == 55)
        #expect(s.maxTotal == 100)
        #expect(s.rating == .okay)
    }

    @Test("Knapp unter 55 Punkten ist niedrig")
    func ratingJustBelowOkay() {
        let s = SleepScoring.score(asleepHours: 5.44, goalHours: 8, bedtimeMinutes: 330,
                                   recentBedtimeMinutes: [300], awakeMinutes: 50, wakeCount: 4)
        #expect(s.total == 54)
        #expect(s.rating == .low)
    }

    // MARK: - Bewertung über siebzig erreichbare Punkte

    /// 85 % von 70 sind 59,5 — erreicht wird die Schwelle erst mit 60 Punkten.
    @Test("60 von 70 Punkten sind sehr gut")
    func ratingVeryGoodOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 30, wakeCount: 4)
        #expect(s.total == 60)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .veryGood)
    }

    @Test("59 von 70 Punkten sind nur noch gut")
    func ratingJustBelowVeryGoodOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 32, wakeCount: 4)
        #expect(s.total == 59)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .good)
    }

    /// 70 % von 70 sind genau 49 Punkte.
    @Test("49 von 70 Punkten sind gut")
    func ratingGoodOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 5.6, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 22, wakeCount: 4)
        #expect(s.total == 49)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .good)
    }

    @Test("48 von 70 Punkten sind nur noch okay")
    func ratingJustBelowGoodOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 5.6, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 24, wakeCount: 4)
        #expect(s.total == 48)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .okay)
    }

    /// 55 % von 70 sind 38,5 — erreicht wird die Schwelle erst mit 39 Punkten.
    @Test("39 von 70 Punkten sind okay")
    func ratingOkayOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 5.6, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 42, wakeCount: 4)
        #expect(s.total == 39)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .okay)
    }

    @Test("38 von 70 Punkten sind niedrig")
    func ratingJustBelowOkayOutOfSeventy() {
        let s = SleepScoring.score(asleepHours: 5.6, goalHours: 8, bedtimeMinutes: nil,
                                   recentBedtimeMinutes: [], awakeMinutes: 44, wakeCount: 4)
        #expect(s.total == 38)
        #expect(s.maxTotal == 70)
        #expect(s.rating == .low)
    }

    // Review Focus: derselbe Punktestand bewertet sich je nach erreichbarer Summe anders.
    @Test("Derselbe Punktestand bewertet sich je nach erreichbarer Summe anders")
    func sameTotalRatesDifferently() {
        let withoutBasis = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: nil,
                                              recentBedtimeMinutes: [], awakeMinutes: 30, wakeCount: 4)
        let withBasis = SleepScoring.score(asleepHours: 8, goalHours: 8, bedtimeMinutes: 360,
                                           recentBedtimeMinutes: [300], awakeMinutes: 50, wakeCount: 4)
        #expect(withoutBasis.total == 60)
        #expect(withBasis.total == 60)
        #expect(withoutBasis.rating == .veryGood)
        #expect(withBasis.rating == .okay)
    }
}

@Suite("Minuten seit 18 Uhr")
struct EveningClockTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    @Test("23:23 sind 323 Minuten")
    func lateEvening() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-11T23:23:00+02:00")) == 323)
    }

    @Test("22:30 sind 270 Minuten")
    func halfPastTen() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-11T22:30:00+02:00")) == 270)
    }

    @Test("00:30 sind 390 Minuten")
    func afterMidnight() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-12T00:30:00+02:00")) == 390)
    }

    @Test("04:58 sind 658 Minuten")
    func earlyMorning() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-12T04:58:00+02:00")) == 658)
    }

    @Test("17:59 sind 1439 Minuten — die letzte Minute des Abends davor")
    func lastMinuteBeforeSix() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-12T17:59:00+02:00")) == 1439)
    }

    @Test("18:00 beginnt den neuen Abend bei null")
    func sixInTheEvening() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-12T18:00:00+02:00")) == 0)
    }

    @Test("Gerechnet wird in Berliner Zeit, nicht in UTC")
    func usesBerlinTime() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-11T21:23:00Z")) == 323)
    }

    // Review Focus: die Uhrzeit auf der Uhr zählt, nicht die verstrichene Zeit.
    @Test("Am Tag der Zeitumstellung zählt die Uhrzeit auf der Uhr")
    func springForwardKeepsTheWallClock() {
        #expect(EveningClock.minutesSinceEvening(date("2027-03-28T04:58:00+02:00")) == 658)
    }

    @Test("In der doppelten Stunde im Herbst zählt beide Male dieselbe Uhrzeit")
    func fallBackHourIsAmbiguousButEqual() {
        #expect(EveningClock.minutesSinceEvening(date("2026-10-25T02:30:00+02:00")) == 510)
        #expect(EveningClock.minutesSinceEvening(date("2026-10-25T02:30:00+01:00")) == 510)
    }
}

/// Nächte für die Reihe am Stück. September 2026 hat keine Zeitumstellung,
/// also verschiebt kein Tag die Abendskala.
private enum Fixture {

    static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private static func padded(_ day: Int) -> String {
        day < 10 ? "0\(day)" : "\(day)"
    }

    /// 18 Uhr dieses Tages — der Nullpunkt der Abendskala.
    private static func eveningOf(_ day: Int) -> Date {
        date("2026-09-\(padded(day))T18:00:00+02:00")
    }

    static func dayStart(_ day: Int) -> Date {
        BerlinCalendar.startOfDay(date("2026-09-\(padded(day))T12:00:00+02:00"))
    }

    /// Eine Nacht in Minuten beschrieben: Einschlafen `bedtime` Minuten nach
    /// 18 Uhr am Vorabend, `asleep` Schlafminuten, dazwischen `wakes`
    /// Wachblöcke von zusammen `awake` Minuten. Der Schlaf wird dazu in
    /// `wakes + 1` gleiche Abschnitte zerlegt.
    static func night(wakingOn day: Int, bedtime: Double, asleep: Double,
                      awake: Double = 0, wakes: Int = 0,
                      naps: [SleepSession] = []) -> SleepNight {
        let chunk = asleep / Double(wakes + 1)
        let gap = wakes > 0 ? awake / Double(wakes) : 0

        var segments: [SleepSegment] = []
        var cursor = eveningOf(day - 1).addingTimeInterval(bedtime * 60)
        for index in 0...wakes {
            let slept = cursor.addingTimeInterval(chunk * 60)
            segments.append(SleepSegment(stage: .core, start: cursor, end: slept))
            cursor = slept
            guard index < wakes else { break }
            let woken = cursor.addingTimeInterval(gap * 60)
            segments.append(SleepSegment(stage: .awake, start: cursor, end: woken))
            cursor = woken
        }

        return SleepNight(date: dayStart(day),
                          session: SleepSession(segments: segments),
                          naps: naps)
    }

    /// Ein Tag, an dem die Uhr gar nichts aufgezeichnet hat.
    static func emptyNight(wakingOn day: Int) -> SleepNight {
        SleepNight(date: dayStart(day), session: SleepSession(segments: []))
    }

    /// Ein Tag mit Abschnitten, aber ohne eine einzige Schlafminute.
    static func awakeOnlyNight(wakingOn day: Int) -> SleepNight {
        let evening = eveningOf(day - 1)
        return SleepNight(date: dayStart(day), session: SleepSession(segments: [
            SleepSegment(stage: .awake,
                         start: evening.addingTimeInterval(300 * 60),
                         end: evening.addingTimeInterval(380 * 60)),
        ]))
    }

    /// Eine Stunde Mittagsschlaf am 3. September.
    static let hourLongNap = SleepSession(segments: [
        SleepSegment(stage: .unspecified,
                     start: date("2026-09-03T13:00:00+02:00"),
                     end: date("2026-09-03T14:00:00+02:00")),
    ])

    /// Achtzehn Nächte am Stück, Einschlafzeiten in Minuten seit 18 Uhr.
    ///
    /// Die Zeiten sind so gelegt, dass das Fenster der siebzehnten Nacht
    /// sichtbar abschneidet:
    ///
    /// - Die **ersten beiden** Nächte gehen um 21 Uhr ins Bett (180) und
    ///   liegen außerhalb des Fensters der siebzehnten.
    /// - Die **dritte bis sechzehnte** Nacht sind genau vierzehn und haben
    ///   im Mittel 300 Minuten, also 23:00 — dieselbe Zeit wie die
    ///   siebzehnte Nacht selbst.
    /// - Die dritte Nacht fällt mit 360 (00:00) aus der Reihe, damit auch
    ///   auffällt, wenn eine Nacht ohne Schlaf ihr den Platz im Fenster
    ///   nimmt.
    static let eighteenNights: [SleepNight] = [
        night(wakingOn: 2, bedtime: 180, asleep: 480),
        night(wakingOn: 3, bedtime: 180, asleep: 450, awake: 12, wakes: 3),
        night(wakingOn: 4, bedtime: 360, asleep: 420, awake: 20, wakes: 4),
        night(wakingOn: 5, bedtime: 290, asleep: 400, awake: 15, wakes: 5),
        night(wakingOn: 6, bedtime: 300, asleep: 465, awake: 10, wakes: 2),
        night(wakingOn: 7, bedtime: 295, asleep: 330, awake: 36, wakes: 12),
        night(wakingOn: 8, bedtime: 305, asleep: 480),
        night(wakingOn: 9, bedtime: 285, asleep: 300, awake: 60, wakes: 15),
        night(wakingOn: 10, bedtime: 310, asleep: 435, awake: 8, wakes: 2),
        night(wakingOn: 11, bedtime: 300, asleep: 390, awake: 25, wakes: 5),
        night(wakingOn: 12, bedtime: 290, asleep: 510, awake: 14, wakes: 7),
        night(wakingOn: 13, bedtime: 300, asleep: 360, awake: 30, wakes: 6),
        night(wakingOn: 14, bedtime: 295, asleep: 445, awake: 11, wakes: 11),
        night(wakingOn: 15, bedtime: 305, asleep: 420, awake: 18, wakes: 9),
        night(wakingOn: 16, bedtime: 280, asleep: 405, awake: 22, wakes: 11),
        night(wakingOn: 17, bedtime: 285, asleep: 470, awake: 6, wakes: 3),
        night(wakingOn: 18, bedtime: 300, asleep: 450, awake: 10, wakes: 10),
        night(wakingOn: 19, bedtime: 305, asleep: 425, awake: 13, wakes: 13),
    ]

    /// Dieselben sechzehn Nächte, dann ein Tag ohne Aufzeichnung, dann die
    /// Zielnacht um 23:00. Ihr Fenster muss dieselben vierzehn Nächte
    /// umfassen wie das der siebzehnten Nacht oben.
    static let sixteenNightsThenAGap: [SleepNight] = Array(eighteenNights.prefix(16)) + [
        emptyNight(wakingOn: 18),
        night(wakingOn: 19, bedtime: 300, asleep: 450, awake: 10, wakes: 10),
    ]
}

@Suite("Schlaf-Score über eine Reihe von Nächten")
struct SleepScoreSeriesTests {

    private let goal = 8.0

    /// Dieselbe Rechnung wie `RecoverySnapshot.score(of:goalHours:earlier:)`:
    /// eine Nacht, die Nächte davor als Vergleich.
    private func single(_ night: SleepNight, earlier: [SleepNight]) -> SleepScore {
        SleepScoring.score(
            asleepHours: night.session.asleepHours, goalHours: goal,
            bedtimeMinutes: night.session.start.map(EveningClock.minutesSinceEvening),
            recentBedtimeMinutes: earlier.compactMap {
                $0.session.start.map(EveningClock.minutesSinceEvening)
            },
            awakeMinutes: night.session.awakeMinutes,
            wakeCount: night.session.wakeCount)
    }

    // MARK: - Die Vorgabe der Reihe

    // Review Focus: steht die Reihe nicht so, wie sie beschrieben ist, sind
    // die Festwerte weiter unten wertlos.
    @Test("Die Reihe liegt so, wie ihre Beschreibung es sagt")
    func fixtureMatchesItsDescription() {
        let nights = Fixture.eighteenNights
        #expect(nights.count == 18)

        let bedtimes = nights.compactMap {
            $0.session.start.map(EveningClock.minutesSinceEvening)
        }
        #expect(bedtimes.count == 18)
        #expect(bedtimes[0] == 180)
        #expect(bedtimes[1] == 180)
        #expect(bedtimes[2] == 360)
        #expect(bedtimes[16] == 300)

        // Die vierzehn Nächte vor der siebzehnten liegen im Mittel auf 23:00.
        let window = bedtimes[2...15]
        #expect(window.count == SleepScoring.regularityWindow)
        #expect(abs(window.reduce(0, +) / Double(window.count) - 300) < 0.001)

        // Zählten die beiden frühen Nächte mit, läge das Mittel darunter.
        let all = bedtimes[0...15]
        #expect(abs(all.reduce(0, +) / Double(all.count) - 285) < 0.001)

        #expect(abs(nights[0].session.asleepHours - 8) < 0.001)
        #expect(nights.allSatisfy { $0.session.start != nil })
    }

    // MARK: - Die Reihe ist keine zweite Wahrheit

    // Review Focus: die Reihe darf nirgends von der Einzelrechnung abweichen.
    @Test("Jede Nacht der Reihe stimmt mit der Einzelrechnung überein")
    func seriesMatchesTheSingleNightCalculation() {
        let nights = Fixture.eighteenNights
        let result = SleepScoring.series(of: nights, goalHours: goal)
        #expect(result.count == 18)

        for (index, night) in nights.enumerated() {
            let expected = single(night, earlier: Array(nights.prefix(index)))
            #expect(result[night.date] == expected, "Nacht \(index + 1)")
        }
    }

    @Test("Der Schlüssel ist das Datum der Nacht")
    func keysAreTheNightDates() {
        let result = SleepScoring.series(of: Fixture.eighteenNights, goalHours: goal)
        #expect(Set(result.keys) == Set(Fixture.eighteenNights.map(\.date)))
    }

    // MARK: - Das Fenster liegt vor der eigenen Nacht

    @Test("Die älteste Nacht hat keine Vergleichsnacht und damit keine Regelmäßigkeit")
    func oldestNightHasNoRegularity() throws {
        let result = SleepScoring.series(of: Fixture.eighteenNights, goalHours: goal)
        let oldest = try #require(result[Fixture.eighteenNights[0].date])
        #expect(oldest.regularity == nil)
        #expect(oldest.maxTotal == 70)
        #expect(oldest.duration == 50)
        #expect(oldest.interruptions == 20)
    }

    @Test("Die zweite Nacht hat schon eine Vergleichsnacht")
    func secondNightHasRegularity() throws {
        let result = SleepScoring.series(of: Fixture.eighteenNights, goalHours: goal)
        let second = try #require(result[Fixture.eighteenNights[1].date])
        #expect(second.regularity != nil)
        #expect(second.maxTotal == 100)
    }

    // Review Focus: die eigene Einschlafzeit darf nicht in ihren eigenen
    // Vergleich einfließen — sonst hätte jede Nacht eine Regelmäßigkeit.
    @Test("Die siebzehnte Nacht vergleicht nur die vierzehn Nächte davor")
    func windowStopsAfterFourteenNights() throws {
        let nights = Fixture.eighteenNights
        let result = SleepScoring.series(of: nights, goalHours: goal)
        let seventeenth = try #require(result[nights[16].date])

        // Mittel der dritten bis sechzehnten Nacht: 300, wie die eigene Zeit.
        // Zählten die beiden Nächte um 21 Uhr mit, läge das Mittel auf 285
        // und es gäbe 25 Punkte.
        #expect(seventeenth.regularity == 30)
        #expect(seventeenth.regularity != 25)
    }

    // MARK: - Nächte ohne Schlaf

    @Test("Eine Nacht ohne Aufzeichnung fehlt im Ergebnis")
    func nightsWithoutSleepAreMissing() {
        let nights = [
            Fixture.night(wakingOn: 2, bedtime: 300, asleep: 450),
            Fixture.emptyNight(wakingOn: 3),
            Fixture.awakeOnlyNight(wakingOn: 4),
            Fixture.night(wakingOn: 5, bedtime: 315, asleep: 420),
        ]
        let result = SleepScoring.series(of: nights, goalHours: goal)

        #expect(result.count == 2)
        #expect(result[Fixture.dayStart(3)] == nil)
        #expect(result[Fixture.dayStart(4)] == nil)
        #expect(result[Fixture.dayStart(2)] != nil)
        #expect(result[Fixture.dayStart(5)] != nil)
    }

    @Test("Eine Reihe aus lauter Nächten ohne Schlaf ergibt nichts")
    func onlyNightsWithoutSleep() {
        let nights = [Fixture.emptyNight(wakingOn: 2), Fixture.awakeOnlyNight(wakingOn: 3)]
        #expect(SleepScoring.series(of: nights, goalHours: goal).isEmpty)
    }

    @Test("Eine Nacht ohne Schlaf setzt den Vergleich nicht zurück")
    func gapDoesNotResetTheHistory() throws {
        let nights = [
            Fixture.night(wakingOn: 2, bedtime: 300, asleep: 450),
            Fixture.emptyNight(wakingOn: 3),
            Fixture.awakeOnlyNight(wakingOn: 4),
            Fixture.night(wakingOn: 5, bedtime: 315, asleep: 420),
        ]
        let result = SleepScoring.series(of: nights, goalHours: goal)
        let last = try #require(result[Fixture.dayStart(5)])

        // Verglichen wird mit 23:00 aus der ersten Nacht: eine Viertelstunde
        // später kostet fünf Punkte.
        #expect(last.regularity == 25)
    }

    // Review Focus: eine Nacht ohne Einschlafzeit darf keinen Platz im
    // Fenster belegen.
    @Test("Eine Nacht ohne Schlaf verschiebt das Fenster nicht")
    func gapDoesNotShiftTheWindow() throws {
        let nights = Fixture.sixteenNightsThenAGap
        let result = SleepScoring.series(of: nights, goalHours: goal)

        #expect(result.count == 17)
        #expect(result[Fixture.dayStart(18)] == nil)

        // Dasselbe Fenster wie bei der siebzehnten Nacht der langen Reihe:
        // Mittel 300, also volle Punktzahl. Belegte der Tag ohne
        // Aufzeichnung einen Platz, fiele die Nacht um 00:00 heraus und es
        // gäbe nur 28 Punkte.
        let last = try #require(result[Fixture.dayStart(19)])
        #expect(last.regularity == 30)
        #expect(last.regularity != 28)
    }

    // MARK: - Reihenfolge der Eingabe

    @Test("Die Reihenfolge der Eingabe ist gleichgültig")
    func orderOfInputDoesNotMatter() {
        let nights = Fixture.eighteenNights
        let sorted = SleepScoring.series(of: nights, goalHours: goal)

        #expect(SleepScoring.series(of: Array(nights.reversed()), goalHours: goal) == sorted)

        let evenFirst = nights.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
            + nights.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
        #expect(SleepScoring.series(of: evenFirst, goalHours: goal) == sorted)

        let lastFirst = Array(nights.suffix(5)) + Array(nights.prefix(13))
        #expect(SleepScoring.series(of: lastFirst, goalHours: goal) == sorted)
    }

    // MARK: - Leere Eingabe

    @Test("Eine leere Eingabe ergibt ein leeres Ergebnis")
    func emptyInput() {
        #expect(SleepScoring.series(of: [], goalHours: goal).isEmpty)
    }

    // MARK: - Fehlendes Ziel

    @Test("Ohne Ziel gibt es in der ganzen Reihe keine Punkte für die Dauer")
    func withoutGoal() {
        let result = SleepScoring.series(of: Fixture.eighteenNights, goalHours: 0)
        #expect(result.count == 18)
        #expect(result.values.allSatisfy { $0.duration == 0 })
        #expect(result.values.contains { $0.regularity != nil })
    }

    @Test("Ein negatives Ziel gibt ebenso keine Punkte für die Dauer")
    func withNegativeGoal() {
        let result = SleepScoring.series(of: Fixture.eighteenNights, goalHours: -1)
        #expect(result.count == 18)
        #expect(result.values.allSatisfy { $0.duration == 0 })
    }

    // MARK: - Tagschlaf

    // Review Focus: in den Score geht nur die Nacht ein, nicht der Tagschlaf.
    @Test("Der Tagschlaf einer Nacht zählt nicht in ihren Score")
    func napsDoNotCount() throws {
        let first = Fixture.night(wakingOn: 2, bedtime: 300, asleep: 450)
        let withNap = Fixture.night(wakingOn: 3, bedtime: 300, asleep: 420,
                                    naps: [Fixture.hourLongNap])
        let withoutNap = Fixture.night(wakingOn: 3, bedtime: 300, asleep: 420)

        let withNaps = SleepScoring.series(of: [first, withNap], goalHours: goal)
        let without = SleepScoring.series(of: [first, withoutNap], goalHours: goal)
        #expect(withNaps == without)

        // Sieben Stunden Nacht geben 44 Punkte. Zählte die Stunde Tagschlaf
        // mit, wären es acht Stunden und damit die volle Punktzahl.
        let scored = try #require(withNaps[Fixture.dayStart(3)])
        #expect(scored.duration == 44)
        #expect(scored.duration != 50)
        #expect(scored.regularity == 30)
        #expect(scored.interruptions == 20)
        #expect(scored.total == 94)
    }
}
