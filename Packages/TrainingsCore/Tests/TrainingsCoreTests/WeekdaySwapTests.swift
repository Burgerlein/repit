import Foundation
import Testing
@testable import TrainingsCore

/// Die Tausche aus dem Plan-Tab, übersetzt auf die Wochentage des Gym-Plans.
/// 1 ist Sonntag, 2 Montag — wie im gregorianischen Kalender.
@Suite("Tagestausch auf Wochentagen")
struct WeekdaySwapTests {

    private let so = 1, mo = 2, di = 3, mi = 4, `do` = 5, fr = 6, sa = 7

    /// Mo A, Mi B, Do C — der Plan aus SPEC 4.4.
    private let plan = [PlannedGym(workout: .a, weekday: 2),
                        PlannedGym(workout: .b, weekday: 4),
                        PlannedGym(workout: .c, weekday: 5)]

    // MARK: - Nichts zu tun

    @Test("Ohne Tauschvorgänge bleibt der Plan, wie er ist")
    func emptySwapsChangeNothing() {
        #expect(PlanSwaps.apply([], to: plan) == plan)
    }

    @Test("Ohne geplante Einheiten bleibt das Ergebnis leer")
    func emptyPlanStaysEmpty() {
        #expect(PlanSwaps.apply([WeekdaySwap(first: 2, second: 7)], to: []).isEmpty)
        #expect(PlanSwaps.apply([], to: []).isEmpty)
    }

    @Test("Ein Tausch auf sich selbst ändert nichts")
    func swapOntoItselfChangesNothing() {
        #expect(PlanSwaps.apply([WeekdaySwap(first: mi, second: mi)], to: plan) == plan)
    }

    @Test("Ein Tausch zweier unbelegter Tage ändert nichts")
    func swapOfTwoEmptyDaysChangesNothing() {
        // Di und Sa tragen keine Einheit.
        #expect(PlanSwaps.apply([WeekdaySwap(first: di, second: sa)], to: plan) == plan)
    }

    @Test("Ein Tausch, der keinen geplanten Tag betrifft, lässt alles stehen")
    func swapOfUnplannedDaysLeavesEverything() {
        let swaps = [WeekdaySwap(first: fr, second: sa),
                     WeekdaySwap(first: so, second: di)]
        #expect(PlanSwaps.apply(swaps, to: plan) == plan)
    }

    // MARK: - Ein einzelner Tausch

    @Test("Ein Tausch vertauscht genau die beiden Wochentage")
    func oneSwapExchangesTwoOccupiedDays() {
        // Mo ↔ Mi: A zieht auf Mittwoch, B auf Montag, C bleibt am Donnerstag.
        #expect(PlanSwaps.apply([WeekdaySwap(first: mo, second: mi)], to: plan)
                == [PlannedGym(workout: .a, weekday: mi),
                    PlannedGym(workout: .b, weekday: mo),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    @Test("Das Workout eines Eintrags ändert sich nie, nur sein Wochentag")
    func workoutsNeverChange() {
        let swaps = [WeekdaySwap(first: mo, second: sa),
                     WeekdaySwap(first: mi, second: so),
                     WeekdaySwap(first: sa, second: fr)]
        let danach = PlanSwaps.apply(swaps, to: plan)
        #expect(danach.map(\.workout) == plan.map(\.workout))
    }

    @Test("Die Reihenfolge der Einträge bleibt erhalten, es wird nicht sortiert")
    func inputOrderIsKept() {
        let unsortiert = [PlannedGym(workout: .c, weekday: `do`),
                          PlannedGym(workout: .a, weekday: mo),
                          PlannedGym(workout: .b, weekday: mi)]
        // Die Stellen bleiben, nur die Tage wechseln.
        #expect(PlanSwaps.apply([WeekdaySwap(first: mo, second: `do`)], to: unsortiert)
                == [PlannedGym(workout: .c, weekday: mo),
                    PlannedGym(workout: .a, weekday: `do`),
                    PlannedGym(workout: .b, weekday: mi)])
    }

    @Test("Die Richtung des Tausches spielt keine Rolle")
    func swapIsSymmetric() {
        let hin = [WeekdaySwap(first: mo, second: sa)]
        let her = [WeekdaySwap(first: sa, second: mo)]
        #expect(PlanSwaps.apply(hin, to: plan) == PlanSwaps.apply(her, to: plan))
    }

    @Test("Derselbe Tausch zweimal ergibt wieder den Ausgangsplan")
    func swapTwiceIsIdentity() {
        let swaps = [WeekdaySwap(first: mo, second: mi),
                     WeekdaySwap(first: mo, second: mi)]
        #expect(PlanSwaps.apply(swaps, to: plan) == plan)
    }

    // MARK: - Einseitiger Umzug auf einen leeren Tag

    @Test("Ist nur ein Tag belegt, zieht die Einheit auf den anderen um")
    func swapWithEmptyDayMovesTheUnit() {
        // Fr trägt keine Einheit — A zieht vom Montag auf den Freitag.
        #expect(PlanSwaps.apply([WeekdaySwap(first: mo, second: fr)], to: plan)
                == [PlannedGym(workout: .a, weekday: fr),
                    PlannedGym(workout: .b, weekday: mi),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    @Test("Der einseitige Umzug gilt in beide Richtungen")
    func oneSidedMoveWorksFromBothSides() {
        #expect(PlanSwaps.apply([WeekdaySwap(first: fr, second: mo)], to: plan)
                == [PlannedGym(workout: .a, weekday: fr),
                    PlannedGym(workout: .b, weekday: mi),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    @Test("Ein einseitiger Umzug lässt sich mit demselben Tausch zurücknehmen")
    func oneSidedMoveIsReversible() {
        let swaps = [WeekdaySwap(first: mo, second: fr),
                     WeekdaySwap(first: mo, second: fr)]
        #expect(PlanSwaps.apply(swaps, to: plan) == plan)
    }

    // MARK: - Mehrere Tauschvorgänge

    @Test("Zwei Tauschvorgänge wirken nacheinander, nicht gleichzeitig")
    func chainedSwapsApplyOneAfterAnother() {
        let swaps = [WeekdaySwap(first: mo, second: mi),
                     WeekdaySwap(first: mi, second: sa)]
        // [A@Mo, B@Mi, C@Do] --(Mo↔Mi)--> [A@Mi, B@Mo, C@Do]
        //                    --(Mi↔Sa)--> [A@Sa, B@Mo, C@Do]
        // Gleichzeitig angewandt bliebe A am Mittwoch — das wäre falsch.
        #expect(PlanSwaps.apply(swaps, to: plan)
                == [PlannedGym(workout: .a, weekday: sa),
                    PlannedGym(workout: .b, weekday: mo),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    @Test("Die Reihenfolge der Tauschvorgänge ist erheblich")
    func orderOfSwapsMatters() {
        let vorwaerts = [WeekdaySwap(first: mo, second: mi),
                         WeekdaySwap(first: mi, second: sa)]
        let rueckwaerts = [WeekdaySwap(first: mi, second: sa),
                           WeekdaySwap(first: mo, second: mi)]
        // [A@Mo, B@Mi, C@Do] --(Mi↔Sa)--> [A@Mo, B@Sa, C@Do]
        //                    --(Mo↔Mi)--> [A@Mi, B@Sa, C@Do]
        #expect(PlanSwaps.apply(rueckwaerts, to: plan)
                == [PlannedGym(workout: .a, weekday: mi),
                    PlannedGym(workout: .b, weekday: sa),
                    PlannedGym(workout: .c, weekday: `do`)])
        #expect(PlanSwaps.apply(vorwaerts, to: plan) != PlanSwaps.apply(rueckwaerts, to: plan))
    }

    @Test("Tauschvorgänge auf unbeteiligten Tagen stören einander nicht")
    func independentSwapsCoexist() {
        let swaps = [WeekdaySwap(first: mo, second: di),
                     WeekdaySwap(first: `do`, second: fr)]
        #expect(PlanSwaps.apply(swaps, to: plan)
                == [PlannedGym(workout: .a, weekday: di),
                    PlannedGym(workout: .b, weekday: mi),
                    PlannedGym(workout: .c, weekday: fr)])
    }

    @Test("Ein verketteter Umzug führt eine Einheit über zwei leere Tage")
    func chainedMoveCarriesAUnitOverEmptyDays() {
        let swaps = [WeekdaySwap(first: mo, second: di),
                     WeekdaySwap(first: di, second: sa)]
        #expect(PlanSwaps.apply(swaps, to: plan)
                == [PlannedGym(workout: .a, weekday: sa),
                    PlannedGym(workout: .b, weekday: mi),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    // MARK: - Doppelt belegte Tage

    @Test("Zwei Einheiten dürfen auf demselben Tag landen")
    func twoUnitsMayShareADay() {
        // Gewollt: der Kern entscheidet nicht, ob ein Tag doppelt belegt sein darf.
        let doppelt = [PlannedGym(workout: .a, weekday: mo),
                       PlannedGym(workout: .b, weekday: mo),
                       PlannedGym(workout: .c, weekday: `do`)]
        #expect(PlanSwaps.apply([WeekdaySwap(first: mo, second: fr)], to: doppelt)
                == [PlannedGym(workout: .a, weekday: fr),
                    PlannedGym(workout: .b, weekday: fr),
                    PlannedGym(workout: .c, weekday: `do`)])
    }

    // MARK: - Gleichheit

    @Test("Zwei Tauschvorgänge sind nur bei gleichen Tagen in gleicher Lage gleich")
    func equalityCoversBothDays() {
        let a = WeekdaySwap(first: mo, second: sa)
        #expect(a == WeekdaySwap(first: 2, second: 7))
        #expect(a != WeekdaySwap(first: sa, second: mo))
        #expect(a != WeekdaySwap(first: mo, second: so))
    }
}
