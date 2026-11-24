import Testing
@testable import TrainingsCore

@Suite("Double Progression")
struct ProgressionTests {

    private var bench: Exercise { ExerciseCatalog.all["benchPress"]! }   // 4×6–10, +2,5
    private var dips: Exercise { ExerciseCatalog.all["dips"]! }          // 3×6–12, +2,5, Unterstützung
    private var plank: Exercise { ExerciseCatalog.all["sidePlank"]! }    // 3×30–45 s, +5

    private func sets(_ weight: Double, _ reps: [Int]) -> [CompletedSet] {
        reps.map { CompletedSet(weight: weight, reps: $0) }
    }

    // Review Focus 1
    @Test("Ohne Verlauf nennt der Vorschlag den unteren Zielbereich")
    func firstTimeHasNoWeight() {
        #expect(Progression.suggest(bench, history: []) == .firstTime(targetReps: 6))
    }

    @Test("Alle Sätze an der oberen Grenze heißt steigern")
    func allAtTopMeansIncrease() {
        let h = [sets(52.5, [10, 10, 10, 11])]
        #expect(Progression.suggest(bench, history: h)
                == .increase(toWeight: 55, by: 2.5, targetReps: 6))
    }

    @Test("Ein Satz unter der oberen Grenze heißt halten")
    func oneBelowTopMeansHold() {
        let h = [sets(52.5, [10, 10, 9, 10])]
        #expect(Progression.suggest(bench, history: h) == .hold(atWeight: 52.5, targetReps: 10))
    }

    @Test("Einmal unter der unteren Grenze heißt noch halten")
    func onceBelowLowStillHolds() {
        let h = [sets(52.5, [5, 6, 6, 6]), sets(52.5, [8, 8, 7, 7])]
        #expect(Progression.suggest(bench, history: h) == .hold(atWeight: 52.5, targetReps: 6))
    }

    @Test("Zweimal hintereinander unter der unteren Grenze heißt reduzieren")
    func twiceBelowLowMeansDeload() {
        let h = [sets(52.5, [5, 5, 4, 4]), sets(52.5, [5, 6, 5, 5])]
        // 52,5 · 0,9 = 47,25 → auf 2,5 gerundet 47,5
        #expect(Progression.suggest(bench, history: h)
                == .deload(toWeight: 47.5, fromWeight: 52.5, targetReps: 6))
    }

    // Review Focus 4
    @Test("Nicht ausgefüllte Sätze lösen keinen Deload aus")
    func emptySetsAreIgnored() {
        let h = [[CompletedSet(weight: 52.5, reps: 9), CompletedSet(weight: 52.5, reps: 0)],
                 [CompletedSet(weight: 52.5, reps: 9), CompletedSet(weight: 52.5, reps: 0)]]
        #expect(Progression.suggest(bench, history: h) == .hold(atWeight: 52.5, targetReps: 10))
    }

    // Review Focus 2
    @Test("Steigern bei Unterstützung bewegt den Wert Richtung null")
    func increaseWithAssistMovesTowardZero() {
        let h = [sets(-27, [12, 12, 12])]
        #expect(Progression.suggest(dips, history: h)
                == .increase(toWeight: -24.5, by: 2.5, targetReps: 6))
    }

    // Review Focus 3
    @Test("Reduzieren bei Unterstützung bewegt den Wert von null weg")
    func deloadWithAssistMovesAwayFromZero() {
        let h = [sets(-27, [4, 4, 3]), sets(-27, [5, 5, 4])]
        // Betrag 10 % größer: 27 · 1,1 = 29,7 → auf 2,5 gerundet 30
        #expect(Progression.suggest(dips, history: h)
                == .deload(toWeight: -30, fromWeight: -27, targetReps: 6))
    }

    @Test("Bei mehreren Gewichten zählt der schwerste Satz")
    func topWeightWins() {
        let h = [[CompletedSet(weight: 40, reps: 12),
                  CompletedSet(weight: 52.5, reps: 10),
                  CompletedSet(weight: 52.5, reps: 10),
                  CompletedSet(weight: 52.5, reps: 10)]]
        #expect(Progression.suggest(bench, history: h)
                == .increase(toWeight: 55, by: 2.5, targetReps: 6))
    }

    // Review Focus 5
    @Test("Die Zeitübung steigert Sekunden statt Gewicht")
    func timedExerciseAddsSeconds() {
        let h = [sets(0, [35, 35, 35])]
        #expect(Progression.suggest(plank, history: h) == .increaseTime(toSeconds: 40))
    }

    @Test("Ist die Obergrenze erreicht, braucht die Zeitübung eine schwerere Variante")
    func timedExerciseAtCeiling() {
        let h = [sets(0, [45, 45, 46])]
        #expect(Progression.suggest(plank, history: h) == .harderVariant)
    }
}
