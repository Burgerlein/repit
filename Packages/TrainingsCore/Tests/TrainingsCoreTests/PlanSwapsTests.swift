import Foundation
import Testing
@testable import TrainingsCore

@Suite("Tagestausch im Plan")
struct PlanSwapsTests {

    private let woche = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    // MARK: - Nichts zu tun

    @Test("Ohne Tauschvorgänge bleiben die Tage, wie sie sind")
    func emptySwapsChangeNothing() {
        #expect(PlanSwaps.apply([], week: 1, to: woche) == woche)
    }

    @Test("Ohne Tage bleibt das Ergebnis leer")
    func emptyDaysStayEmpty() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: []).isEmpty)
        #expect(PlanSwaps.apply([], week: 1, to: []).isEmpty)
    }

    @Test("Ein Tausch auf sich selbst ändert nichts")
    func swapOntoItselfChangesNothing() {
        let swaps = [PlanSwap(week: 1, first: "Mi", second: "Mi")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: woche) == woche)
    }

    // MARK: - Ein einzelner Tausch

    @Test("Ein Tausch vertauscht genau die beiden Beschriftungen")
    func oneSwapExchangesExactlyTwoLabels() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: woche)
                == ["Sa", "Di", "Mi", "Do", "Fr", "Mo", "So"])
    }

    @Test("Die Reihenfolge der Eingabe bleibt erhalten, es wird nicht sortiert")
    func inputOrderIsKept() {
        let days = ["Sa", "Mo", "Mi"]
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa")]
        // Die Stellen bleiben, nur die Beschriftungen wechseln.
        #expect(PlanSwaps.apply(swaps, week: 1, to: days) == ["Mo", "Sa", "Mi"])
    }

    @Test("Die Richtung des Tausches spielt keine Rolle")
    func swapIsSymmetric() {
        let hin = [PlanSwap(week: 1, first: "Mo", second: "Sa")]
        let her = [PlanSwap(week: 1, first: "Sa", second: "Mo")]
        #expect(PlanSwaps.apply(hin, week: 1, to: woche)
                == PlanSwaps.apply(her, week: 1, to: woche))
    }

    @Test("Derselbe Tausch zweimal ergibt wieder den Ausgangszustand")
    func swapTwiceIsIdentity() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa"),
                     PlanSwap(week: 1, first: "Mo", second: "Sa")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: woche) == woche)
    }

    // MARK: - Mehrere Tauschvorgänge

    @Test("Zwei Tauschvorgänge wirken nacheinander, nicht gleichzeitig")
    func swapsApplyOneAfterAnother() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa"),
                     PlanSwap(week: 1, first: "Sa", second: "So")]
        // ["Mo","Sa","So"] --(Mo↔Sa)--> ["Sa","Mo","So"] --(Sa↔So)--> ["So","Mo","Sa"]
        // Gleichzeitig angewandt käme ["Sa","So","Sa"] heraus — das wäre falsch.
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Sa", "So"])
                == ["So", "Mo", "Sa"])
    }

    @Test("Die Reihenfolge der Tauschvorgänge ist erheblich")
    func orderOfSwapsMatters() {
        let vorwaerts = [PlanSwap(week: 1, first: "Mo", second: "Sa"),
                         PlanSwap(week: 1, first: "Sa", second: "So")]
        let rueckwaerts = [PlanSwap(week: 1, first: "Sa", second: "So"),
                           PlanSwap(week: 1, first: "Mo", second: "Sa")]
        // ["Mo","Sa","So"] --(Sa↔So)--> ["Mo","So","Sa"] --(Mo↔Sa)--> ["Sa","So","Mo"]
        #expect(PlanSwaps.apply(rueckwaerts, week: 1, to: ["Mo", "Sa", "So"])
                == ["Sa", "So", "Mo"])
        #expect(PlanSwaps.apply(vorwaerts, week: 1, to: ["Mo", "Sa", "So"])
                != PlanSwaps.apply(rueckwaerts, week: 1, to: ["Mo", "Sa", "So"]))
    }

    @Test("Tauschvorgänge auf unbeteiligten Tagen stören einander nicht")
    func independentSwapsCoexist() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Di"),
                     PlanSwap(week: 1, first: "Sa", second: "So")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: woche)
                == ["Di", "Mo", "Mi", "Do", "Fr", "So", "Sa"])
    }

    // MARK: - Wochenzugehörigkeit

    @Test("Tauschvorgänge anderer Wochen werden übergangen")
    func swapsOfOtherWeeksAreIgnored() {
        let swaps = [PlanSwap(week: 2, first: "Mo", second: "Sa")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: woche) == woche)
        #expect(PlanSwaps.apply(swaps, week: 2, to: woche)
                == ["Sa", "Di", "Mi", "Do", "Fr", "Mo", "So"])
    }

    @Test("Aus einer gemischten Liste wirkt nur die gefragte Woche")
    func onlyTheAskedWeekIsApplied() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Di"),
                     PlanSwap(week: 3, first: "Mi", second: "Do"),
                     PlanSwap(week: 2, first: "Sa", second: "So")]
        #expect(PlanSwaps.apply(swaps, week: 3, to: woche)
                == ["Mo", "Di", "Do", "Mi", "Fr", "Sa", "So"])
    }

    @Test("Eine Woche ohne eigene Tauschvorgänge bleibt unberührt")
    func weekWithoutSwapsIsUntouched() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Di"),
                     PlanSwap(week: 2, first: "Sa", second: "So")]
        #expect(PlanSwaps.apply(swaps, week: 4, to: woche) == woche)
    }

    // MARK: - Einseitiger Umzug auf einen leeren Tag

    @Test("Ein Tausch mit einem fehlenden Tag benennt den vorhandenen um")
    func swapWithAbsentDayRenamesTheOtherOne() {
        // "Fr" trägt keine Einheit und steht deshalb nicht in `days`.
        // Die Einheit vom Mo zieht auf den leeren Fr um, alles andere bleibt.
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Fr")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Mi", "Sa"])
                == ["Fr", "Mi", "Sa"])
    }

    @Test("Der einseitige Umzug gilt in beide Richtungen")
    func oneSidedMoveWorksFromBothSides() {
        let swaps = [PlanSwap(week: 1, first: "Fr", second: "Mo")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Mi", "Sa"])
                == ["Fr", "Mi", "Sa"])
    }

    @Test("Kommt keiner der beiden Tage vor, ändert sich nichts")
    func swapOfTwoAbsentDaysChangesNothing() {
        let swaps = [PlanSwap(week: 1, first: "Di", second: "Fr")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Mi", "Sa"])
                == ["Mo", "Mi", "Sa"])
    }

    @Test("Ein einseitiger Umzug lässt sich mit demselben Tausch zurücknehmen")
    func oneSidedMoveIsReversible() {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Fr"),
                     PlanSwap(week: 1, first: "Mo", second: "Fr")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Mi", "Sa"])
                == ["Mo", "Mi", "Sa"])
    }

    @Test("Ein Umzug kann zwei Einheiten auf denselben Tag führen")
    func oneSidedMoveCanCollide() {
        // Gewollt: der Kern entscheidet nicht, ob ein Tag doppelt belegt sein darf.
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Mi")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Mo", "Sa"])
                == ["Mi", "Mi", "Sa"])
    }

    // MARK: - Tage sind undurchsichtige Zeichenketten

    @Test("Der Kern kennt keine Wochentagsreihenfolge")
    func daysAreOpaqueStrings() {
        let days = ["Zebra", "Anton", "", "😀"]
        let swaps = [PlanSwap(week: 1, first: "Zebra", second: "😀"),
                     PlanSwap(week: 1, first: "", second: "Berta")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: days)
                == ["😀", "Anton", "Berta", "Zebra"])
    }

    @Test("Groß- und Kleinschreibung werden unterschieden")
    func labelsAreComparedExactly() {
        let swaps = [PlanSwap(week: 1, first: "mo", second: "Sa")]
        #expect(PlanSwaps.apply(swaps, week: 1, to: ["Mo", "Sa"]) == ["Mo", "mo"])
    }

    // MARK: - Ablage als JSON

    @Test("Ein Tausch übersteht eine Runde durch JSON unverändert")
    func swapSurvivesJSONRoundTrip() throws {
        let swap = PlanSwap(week: 7, first: "Mo", second: "Sa")
        let data = try JSONEncoder().encode(swap)
        #expect(try JSONDecoder().decode(PlanSwap.self, from: data) == swap)
    }

    @Test("Eine Liste von Tauschvorgängen übersteht die Runde in ihrer Reihenfolge")
    func swapListSurvivesJSONRoundTrip() throws {
        let swaps = [PlanSwap(week: 1, first: "Mo", second: "Sa"),
                     PlanSwap(week: 1, first: "Sa", second: "So"),
                     PlanSwap(week: 12, first: "Di", second: "Do")]
        let data = try JSONEncoder().encode(swaps)
        let zurueck = try JSONDecoder().decode([PlanSwap].self, from: data)
        #expect(zurueck == swaps)
        #expect(PlanSwaps.apply(zurueck, week: 1, to: ["Mo", "Sa", "So"])
                == ["So", "Mo", "Sa"])
    }

    @Test("Zwei Tauschvorgänge sind nur bei gleicher Woche und gleichen Tagen gleich")
    func equalityCoversAllFields() {
        let a = PlanSwap(week: 1, first: "Mo", second: "Sa")
        #expect(a == PlanSwap(week: 1, first: "Mo", second: "Sa"))
        #expect(a != PlanSwap(week: 2, first: "Mo", second: "Sa"))
        #expect(a != PlanSwap(week: 1, first: "Sa", second: "Mo"))
    }
}
