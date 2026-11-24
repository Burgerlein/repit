import Foundation
import Testing
@testable import TrainingsCore

/// Beim Antippen eines Muskels soll die Muskelkarte sagen, woher seine Sätze
/// kommen. Die Rechnung dahinter ist dieselbe wie in `MuscleVolume.weeklySets`,
/// nur nicht auf den Muskel zusammengefasst, sondern nach Übung aufgeschlüsselt.
/// Die wichtigste Zusicherung steht deshalb unten: Die Summe der Quellen ist
/// exakt der Wert, den die Karte anzeigt.
@Suite("Muskelquellen")
struct MuscleSourcesTests {

    private let now = Date(timeIntervalSince1970: 1_791_000_000)  // 03.10.2026, 06:00 Berliner Zeit

    private func date(_ daysAgo: Int) -> Date {
        BerlinCalendar.calendar.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    private func set(_ daysAgo: Int, _ id: String) -> TrainedSet {
        TrainedSet(date: date(daysAgo), exerciseID: id)
    }

    private func close(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 0.001
    }

    // MARK: - Leere und unpassende Eingaben

    @Test("Ohne Sätze gibt es keine Quellen")
    func noSetsYieldNoSources() {
        #expect(MuscleVolume.sources(for: .chest, sets: [], window: 7, now: now).isEmpty)
    }

    // Seitheben trifft nur die seitliche Schulter, Zehenheben an der Wand nur
    // das Schienbein. Keine der beiden darf unter der Brust auftauchen.
    @Test("Nur Übungen, die den Muskel treffen, erscheinen")
    func onlyExercisesHittingTheMuscleAppear() {
        let sets = [set(1, "benchPress"), set(1, "lateralRaise"), set(2, "tibialisRaise")]
        let chest = MuscleVolume.sources(for: .chest, sets: sets, window: 7, now: now)
        #expect(chest.map(\.exerciseID) == ["benchPress"])

        let sideDelt = MuscleVolume.sources(for: .sideDelt, sets: sets, window: 7, now: now)
        #expect(sideDelt.map(\.exerciseID) == ["lateralRaise"])
    }

    @Test("Eine unbekannte Übung wird übergangen, der Rest bleibt stehen")
    func unknownExerciseIsSkippedWithoutLosingTheRest() {
        let sets = [set(1, "zumba"), set(1, "benchPress"), set(2, "zumba")]
        let sources = MuscleVolume.sources(for: .chest, sets: sets, window: 7, now: now)
        #expect(sources.count == 1)
        #expect(sources.first?.exerciseID == "benchPress")
        #expect(sources.first?.setCount == 1)
        #expect(close(sources.first?.weeklySets ?? 0, 1))
    }

    // MARK: - Fenster

    // Dieselbe Grenze wie `weeklySets`: Das Fenster beginnt am Anfang des Tages,
    // der `days - 1` Tage zurückliegt. Bei sieben Tagen zählt der Satz von vor
    // sechs Tagen noch, der von vor sieben nicht mehr.
    @Test("Der älteste zählende Tag ist drin, der nächste fällt heraus")
    func windowEdgeMatchesWeeklySets() {
        let sources = MuscleVolume.sources(
            for: .chest, sets: [set(6, "benchPress"), set(7, "benchPress")],
            window: 7, now: now)
        #expect(sources.count == 1)
        #expect(sources.first?.setCount == 1)
        #expect(sources.first?.lastDate == date(6))
    }

    @Test("Eine Übung, die nur außerhalb des Fensters vorkommt, fehlt ganz")
    func exerciseOnlyOutsideTheWindowIsAbsent() {
        let sets = [set(1, "benchPress"), set(7, "cableFly"), set(20, "cableFly")]
        let sources = MuscleVolume.sources(for: .chest, sets: sets, window: 7, now: now)
        #expect(sources.map(\.exerciseID) == ["benchPress"])
    }

    @Test("Ein Satz von heute zählt mit")
    func todayCounts() {
        let sources = MuscleVolume.sources(for: .chest, sets: [set(0, "benchPress")],
                                           window: 7, now: now)
        #expect(sources.count == 1)
        #expect(sources.first?.lastDate == date(0))
    }

    @Test("Ein Fenster von null oder negativ ergibt keine Quellen")
    func nonPositiveWindowYieldsNothing() {
        let sets = [set(0, "benchPress"), set(1, "benchPress")]
        #expect(MuscleVolume.sources(for: .chest, sets: sets, window: 0, now: now).isEmpty)
        #expect(MuscleVolume.sources(for: .chest, sets: sets, window: -7, now: now).isEmpty)
    }

    // MARK: - Zählung

    // Bankdrücken trägt Trizeps mit 0,5. Drei Sätze in einem 14-Tage-Fenster:
    // 3 × 0,5 = 1,5 gewichtete Sätze, geteilt durch 14/7 = 2 Wochen → 0,75 pro
    // Woche. Die ungewichtete Zahl bleibt davon unberührt: drei Sätze sind drei.
    @Test("setCount zählt roh, weeklySets gewichtet und auf die Woche gemittelt")
    func secondaryMuscleIsHalfWeightedAndAveraged() {
        let sets = [set(1, "benchPress"), set(5, "benchPress"), set(12, "benchPress")]
        let sources = MuscleVolume.sources(for: .triceps, sets: sets, window: 14, now: now)
        #expect(sources.count == 1)
        #expect(sources.first?.setCount == 3)
        #expect(close(sources.first?.weeklySets ?? 0, 0.75))

        // Für den Hauptmuskel derselben Übung: 3 × 1 / 2 Wochen = 1,5.
        let chest = MuscleVolume.sources(for: .chest, sets: sets, window: 14, now: now)
        #expect(close(chest.first?.weeklySets ?? 0, 1.5))
        #expect(chest.first?.setCount == 3)
    }

    @Test("Mehrere Sätze derselben Übung werden zu einem Eintrag zusammengefasst")
    func repeatedExerciseIsFoldedIntoOneEntry() {
        let sets = [set(5, "cableFly"), set(1, "cableFly"), set(3, "cableFly")]
        let sources = MuscleVolume.sources(for: .chest, sets: sets, window: 7, now: now)
        #expect(sources.count == 1)
        #expect(sources.first?.exerciseID == "cableFly")
        #expect(sources.first?.setCount == 3)
        #expect(close(sources.first?.weeklySets ?? 0, 3))
        #expect(sources.first?.lastDate == date(1))
    }

    @Test("Jede Übung kommt höchstens einmal vor")
    func everyExerciseAppearsAtMostOnce() {
        let sets = [set(0, "benchPress"), set(1, "benchPress"), set(2, "dips"),
                    set(3, "dips"), set(4, "closeGripBench")]
        let ids = MuscleVolume.sources(for: .triceps, sets: sets, window: 7, now: now)
            .map(\.exerciseID)
        #expect(ids.count == Set(ids).count)
        #expect(Set(ids) == ["benchPress", "dips", "closeGripBench"])
    }

    // MARK: - Die Summe muss stimmen

    // Wenn die Aufschlüsselung und die Karte auseinanderlaufen, erklärt die
    // Aufschlüsselung eine Zahl, die nirgends steht. Gemischter Datensatz:
    // mehrere Übungen, mehrere Tage, eine unbekannte ID und ein Satz außerhalb
    // des Fensters.
    @Test("Die Summe aller Quellen ist genau der Wert der Muskelkarte")
    func sourcesSumUpToTheMuscleCardValue() {
        let sets = [
            set(0, "benchPress"), set(2, "benchPress"), set(2, "benchPress"),
            set(1, "cableFly"), set(4, "closeGripBench"), set(4, "dips"),
            set(3, "lateralRaise"), set(5, "hammerCurl"), set(6, "pullUp"),
            set(2, "romanianDeadlift"), set(6, "sidePlank"),
            set(9, "benchPress"),     // außerhalb des Fensters
            set(1, "zumba")           // nicht im Katalog
        ]
        let volume = MuscleVolume.weeklySets(sets, window: 7, now: now)

        for muscle in Muscle.allCases {
            let sum = MuscleVolume.sources(for: muscle, sets: sets, window: 7, now: now)
                .reduce(0) { $0 + $1.weeklySets }
            #expect(close(sum, volume[muscle] ?? 0),
                    "Quellen und Karte laufen bei \(muscle.rawValue) auseinander")
        }
    }

    @Test("Die Summe stimmt auch im 30-Tage-Fenster")
    func sumHoldsInTheThirtyDayWindow() {
        let sets = (0...40).map { day -> TrainedSet in
            let ids = ["benchPress", "cableFly", "dips", "pullUp", "ezCurl"]
            return set(day, ids[day % ids.count])
        }
        let volume = MuscleVolume.weeklySets(sets, window: 30, now: now)

        for muscle in Muscle.allCases {
            let sum = MuscleVolume.sources(for: muscle, sets: sets, window: 30, now: now)
                .reduce(0) { $0 + $1.weeklySets }
            #expect(close(sum, volume[muscle] ?? 0),
                    "Quellen und Karte laufen bei \(muscle.rawValue) auseinander")
        }
    }

    // MARK: - Sortierung

    // Erste Stufe: der größte Beitrag steht oben. Trizeps-Beiträge im
    // 7-Tage-Fenster: Trizeps über Kopf 3 × 1 = 3, enges Bankdrücken 2 × 1 = 2,
    // Bankdrücken 2 × 0,5 = 1.
    @Test("Sortierung: der größte Beitrag steht oben")
    func sortedByWeeklySetsDescending() {
        let sets = [set(1, "overheadTriceps"), set(2, "overheadTriceps"),
                    set(3, "overheadTriceps"),
                    set(1, "closeGripBench"), set(4, "closeGripBench"),
                    set(2, "benchPress"), set(5, "benchPress")]
        let sources = MuscleVolume.sources(for: .triceps, sets: sets, window: 7, now: now)
        #expect(sources.map(\.exerciseID) == ["overheadTriceps", "closeGripBench", "benchPress"])
        #expect(close(sources[0].weeklySets, 3))
        #expect(close(sources[1].weeklySets, 2))
        #expect(close(sources[2].weeklySets, 1))
    }

    // Zweite Stufe: Bei gleichem Beitrag steht das jüngere Training oben.
    @Test("Sortierung: bei Gleichstand entscheidet das jüngere Datum")
    func tiesAreBrokenByMostRecentDate() {
        let sets = [set(5, "overheadTriceps"), set(1, "tricepsPushdown")]
        let sources = MuscleVolume.sources(for: .triceps, sets: sets, window: 7, now: now)
        #expect(close(sources[0].weeklySets, sources[1].weeklySets))
        #expect(sources.map(\.exerciseID) == ["tricepsPushdown", "overheadTriceps"])
        #expect(sources[0].lastDate == date(1))
    }

    // Dritte Stufe: Gleicher Beitrag, gleicher Tag — dann entscheidet die ID,
    // damit die Reihenfolge nicht von der Laune des Dictionarys abhängt.
    @Test("Sortierung: bei gleichem Datum entscheidet die Übungs-ID")
    func furtherTiesAreBrokenByExerciseID() {
        let sets = [set(2, "tricepsPushdown"), set(2, "overheadTriceps")]
        let sources = MuscleVolume.sources(for: .triceps, sets: sets, window: 7, now: now)
        #expect(close(sources[0].weeklySets, sources[1].weeklySets))
        #expect(sources[0].lastDate == sources[1].lastDate)
        #expect(sources.map(\.exerciseID) == ["overheadTriceps", "tricepsPushdown"])
    }

    // Alle drei Stufen in einem Durchlauf. Trizeps im 7-Tage-Fenster:
    // Trizeps über Kopf 3 × 1 = 3 — führt über die erste Stufe.
    // Trizepsdrücken, enges Bankdrücken und Dips liegen mit je 1 × 1 = 1
    // gleichauf; Trizepsdrücken ist von vorgestern und zieht über die zweite
    // Stufe vor. Enges Bankdrücken und Dips teilen sich denselben Tag, also
    // entscheidet die dritte Stufe: closeGripBench vor dips.
    @Test("Sortierung: alle drei Stufen greifen nacheinander")
    func allThreeSortingStagesApply() {
        let sets = [
            set(1, "overheadTriceps"), set(2, "overheadTriceps"), set(3, "overheadTriceps"),
            set(1, "tricepsPushdown"),
            set(4, "closeGripBench"),
            set(4, "dips")
        ]
        let sources = MuscleVolume.sources(for: .triceps, sets: sets, window: 7, now: now)
        #expect(sources.map(\.exerciseID)
                == ["overheadTriceps", "tricepsPushdown", "closeGripBench", "dips"])
        #expect(close(sources[0].weeklySets, 3))
        #expect(sources[0].setCount == 3)
        #expect(close(sources[1].weeklySets, 1))
        #expect(close(sources[2].weeklySets, 1))
        #expect(close(sources[3].weeklySets, 1))
        #expect(sources[1].lastDate == date(1))
        #expect(sources[2].lastDate == date(4))
        #expect(sources[3].lastDate == date(4))
    }
}
