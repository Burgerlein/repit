import Testing
@testable import TrainingsCore

/// Zweite, unabhängig aus SPEC 4.4 abgeschriebene Tabelle. Die
/// Plausibilitätstests in `ExerciseCatalogTests` finden Unsinn, aber keinen
/// Zahlendreher — ein vertauschtes 12–15 statt 15–20 oder ein vergessener
/// Nebenmuskel bliebe unbemerkt, weil Code und Test aus derselben Quelle
/// stammen. Zwei Abschriften gehen nur bei identischem Fehler gemeinsam daneben.
@Suite("Übungskatalog gegen die Spec, Zahl für Zahl")
struct ExerciseCatalogValuesTests {

    private typealias Row = (id: String, sets: Int, lo: Int, hi: Int,
                             inc: Double, muscles: [Muscle: Double])

    private let expected: [Row] = [
        // Gym A — Oberkörper Push + Arme
        ("benchPress", 4, 6, 10, 2.5, [.chest: 1, .frontDelt: 0.5, .triceps: 0.5]),
        ("inclineDumbbellPress", 3, 8, 12, 2, [.chest: 1, .frontDelt: 0.5, .triceps: 0.5]),
        ("shoulderPressDumbbell", 3, 8, 12, 2, [.frontDelt: 1, .sideDelt: 0.5, .triceps: 0.5]),
        ("dips", 3, 6, 12, 2.5, [.triceps: 1, .chest: 0.5, .frontDelt: 0.5]),
        ("lateralRaise", 4, 12, 20, 1, [.sideDelt: 1]),
        ("overheadTriceps", 3, 10, 15, 2.5, [.triceps: 1]),
        ("bicepsCurl", 3, 8, 12, 1, [.biceps: 1, .forearms: 0.5]),
        // Gym B — Läufer-Kraft + Brust
        ("splitSquat", 3, 8, 12, 2, [.quads: 1, .glutes: 1]),
        ("romanianDeadlift", 3, 8, 10, 2.5, [.hamstrings: 1, .glutes: 0.5, .lowerBack: 0.5]),
        ("legCurl", 3, 10, 15, 2.5, [.hamstrings: 1]),
        ("hipAbduction", 3, 12, 20, 5, [.glutes: 1]),
        ("calfRaiseStanding", 6, 12, 15, 2, [.calves: 1]),
        ("tibialisRaise", 3, 15, 25, 1, [.tibialis: 1]),
        ("cableFly", 3, 12, 15, 2.5, [.chest: 1]),
        ("sidePlank", 3, 30, 45, 5, [.core: 1]),
        // Gym C — Oberkörper Pull + Arme
        ("pullUp", 4, 6, 10, 2.5, [.lats: 1, .biceps: 0.5, .rearDelt: 0.5]),
        ("oneArmRow", 3, 8, 12, 2, [.lats: 1, .upperBack: 0.5, .biceps: 0.5, .rearDelt: 0.5]),
        ("cableRowClose", 3, 10, 12, 2.5, [.upperBack: 1, .lats: 0.5, .biceps: 0.5]),
        ("facePull", 3, 12, 20, 2.5, [.rearDelt: 1, .upperBack: 0.5]),
        ("ezCurl", 3, 8, 12, 2.5, [.biceps: 1, .forearms: 0.5]),
        ("hammerCurl", 3, 10, 12, 1, [.biceps: 1, .forearms: 1]),
        ("tricepsPushdown", 3, 10, 15, 2.5, [.triceps: 1]),
        // Gym D — Arme + Schultern
        ("closeGripBench", 3, 6, 10, 2.5, [.triceps: 1, .chest: 0.5]),
        ("shoulderPressMachine", 3, 8, 12, 2.5, [.frontDelt: 1, .sideDelt: 0.5, .triceps: 0.5]),
        ("reverseFly", 3, 12, 15, 1, [.rearDelt: 1, .upperBack: 0.5]),
        ("inclineCurl", 3, 10, 12, 1, [.biceps: 1]),
        // Pull — Rücken, hintere Schulter, Bizeps. Nur die Übungen, die in
        // A–D nicht vorkommen; der Rest steht schon oben.
        ("barbellRow", 4, 8, 12, 2.5,
         [.upperBack: 1, .lats: 0.5, .biceps: 0.5, .lowerBack: 0.5]),
        ("straightArmPulldown", 3, 12, 15, 2.5, [.lats: 1]),
        ("backExtension", 3, 12, 15, 2.5, [.lowerBack: 1, .glutes: 0.5, .hamstrings: 0.5]),
        // Legs — Beine komplett
        ("legPress", 4, 8, 12, 5, [.quads: 1, .glutes: 0.5]),
        ("legExtension", 3, 12, 15, 2.5, [.quads: 1]),
        // Ausgemustert: steht in keinem Workout mehr, bleibt aber im Katalog,
        // damit der gespeicherte Verlauf die Übung weiter auflösen kann.
        ("hipThrust", 3, 8, 12, 5, [.glutes: 1, .hamstrings: 0.5]),
        ("calfRaiseSeated", 3, 15, 20, 5, [.calves: 1])
    ]

    @Test("Sätze, Bereiche, Steigerungen und Muskeln stimmen mit SPEC 4.4")
    func everyValueMatchesSpec() throws {
        for row in expected {
            let e = try #require(ExerciseCatalog.all[row.id], "\(row.id) fehlt im Katalog")
            #expect(e.sets == row.sets, "\(row.id): \(e.sets) Sätze statt \(row.sets)")
            #expect(e.repLow == row.lo, "\(row.id): untere Grenze \(e.repLow) statt \(row.lo)")
            #expect(e.repHigh == row.hi, "\(row.id): obere Grenze \(e.repHigh) statt \(row.hi)")
            #expect(e.increment == row.inc, "\(row.id): Steigerung \(e.increment) statt \(row.inc)")
            #expect(e.muscles == row.muscles, "\(row.id): Muskelzuordnung weicht ab")
        }
    }

    @Test("Die Tabelle deckt jede Übung des Katalogs ab")
    func tableIsComplete() {
        let covered = Set(expected.map(\.id))
        let all = Set(ExerciseCatalog.all.keys)
        #expect(all.subtracting(covered).isEmpty,
                "Nicht geprüft: \(all.subtracting(covered).sorted())")
    }

    @Test("Die Reihenfolge je Workout stimmt mit der Spec")
    func workoutOrder() {
        #expect(ExerciseCatalog.exercises(for: .a).map(\.id)
                == ["benchPress", "inclineDumbbellPress", "shoulderPressDumbbell",
                    "dips", "lateralRaise", "overheadTriceps", "bicepsCurl"])
        #expect(ExerciseCatalog.exercises(for: .b).map(\.id)
                == ["splitSquat", "romanianDeadlift", "legCurl", "hipAbduction",
                    "calfRaiseStanding", "tibialisRaise", "cableFly", "sidePlank"])
        #expect(ExerciseCatalog.exercises(for: .c).map(\.id)
                == ["pullUp", "oneArmRow", "cableRowClose", "facePull",
                    "ezCurl", "hammerCurl", "tricepsPushdown"])
        #expect(ExerciseCatalog.exercises(for: .d).map(\.id)
                == ["closeGripBench", "shoulderPressMachine", "lateralRaise",
                    "reverseFly", "overheadTriceps", "ezCurl", "inclineCurl"])
    }

    @Test("Die Reihenfolge der frei wählbaren Workouts stimmt mit der Spec")
    func freelyChosenWorkoutOrder() {
        #expect(ExerciseCatalog.exercises(for: .push).map(\.id)
                == ["benchPress", "inclineDumbbellPress", "shoulderPressMachine",
                    "cableFly", "lateralRaise", "tricepsPushdown", "overheadTriceps"])
        #expect(ExerciseCatalog.exercises(for: .pull).map(\.id)
                == ["pullUp", "barbellRow", "cableRowClose", "straightArmPulldown",
                    "facePull", "backExtension", "hammerCurl"])
        #expect(ExerciseCatalog.exercises(for: .legs).map(\.id)
                == ["legPress", "romanianDeadlift", "splitSquat", "legCurl",
                    "hipAbduction", "calfRaiseStanding", "legExtension"])
    }

    /// `Exercise.sets` ist eine Zahl pro Übung, nicht pro Workout. Wadenheben
    /// stehend steht in B und in Legs — stünde in der Spec an einer Stelle 6
    /// und an der anderen 4, ließe sich das gar nicht abbilden, und der
    /// Katalog entschiede still für eine der beiden Zahlen.
    @Test("Wadenheben stehend hat in Gym B und in Legs dieselben sechs Sätze")
    func calfRaiseIsTheSameInBothWorkouts() throws {
        let inB = try #require(ExerciseCatalog.exercises(for: .b)
            .first { $0.id == "calfRaiseStanding" })
        let inLegs = try #require(ExerciseCatalog.exercises(for: .legs)
            .first { $0.id == "calfRaiseStanding" })
        #expect(inB.sets == 6)
        #expect(inB == inLegs)
    }

    @Test("Die umbenannte Übung heißt Zehenheben an der Wand und behält ihre ID")
    func tibialisRaiseKeepsItsID() throws {
        // Die ID steht im gespeicherten Verlauf. Wer sie mit dem Namen
        // ändert, verliert jeden alten Satz dieser Übung.
        let e = try #require(ExerciseCatalog.all["tibialisRaise"])
        #expect(e.name == "Zehenheben an der Wand")
        #expect(e.youTubeQuery != "Tibialis Raises")
    }

    @Test("Die neuen Übungen tragen die Namen aus der Spec")
    func newExerciseNames() throws {
        let expected = ["barbellRow": "Langhantelrudern vorgebeugt",
                        "straightArmPulldown": "Überzüge am Kabel mit gestreckten Armen",
                        "backExtension": "Rückenstrecken",
                        "legPress": "Beinpresse",
                        "legCurl": "Beinbeuger-Maschine liegend",
                        "hipAbduction": "Abduktoren-Maschine",
                        "legExtension": "Beinstrecker-Maschine"]
        for (id, name) in expected {
            let e = try #require(ExerciseCatalog.all[id], "\(id) fehlt im Katalog")
            #expect(e.name == name, "\(id): \(e.name) statt \(name)")
        }
    }
}
