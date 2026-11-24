import Testing
@testable import TrainingsCore

@Suite("Übungskatalog")
struct ExerciseCatalogTests {

    @Test("Jedes Workout hat die in der Spec genannte Anzahl Übungen")
    func workoutSizes() {
        #expect(ExerciseCatalog.exercises(for: .a).count == 7)
        #expect(ExerciseCatalog.exercises(for: .b).count == 8)
        #expect(ExerciseCatalog.exercises(for: .c).count == 7)
        #expect(ExerciseCatalog.exercises(for: .d).count == 7)
        #expect(ExerciseCatalog.exercises(for: .push).count == 7)
        #expect(ExerciseCatalog.exercises(for: .pull).count == 7)
        #expect(ExerciseCatalog.exercises(for: .legs).count == 7)
    }

    @Test("Jedes Workout führt Übungen, und jede steht im Katalog")
    func everyWorkoutIsBuiltFromTheCatalog() {
        for workout in Workout.allCases {
            let exercises = ExerciseCatalog.exercises(for: workout)
            #expect(!exercises.isEmpty, "\(workout.rawValue): kein einziger Eintrag")
            for exercise in exercises {
                #expect(ExerciseCatalog.all[exercise.id] != nil,
                        "\(workout.rawValue)/\(exercise.id): nicht im Katalog")
            }
        }
    }

    @Test("Kein Workout nennt dieselbe Übung zweimal")
    func noWorkoutRepeatsAnExercise() {
        for workout in Workout.allCases {
            let ids = ExerciseCatalog.exercises(for: workout).map(\.id)
            #expect(Set(ids).count == ids.count,
                    "\(workout.rawValue): doppelt in \(ids)")
        }
    }

    /// `Exercise.sets` hängt an der Übung, nicht am Workout. Geteilte Übungen
    /// — Wadenheben stehend in B und Legs, Kabel-Flys in B und Push — tragen
    /// deshalb überall dieselben Zahlen. Hätte die Spec an zwei Stellen
    /// verschiedene, fände der Katalog das nicht, sondern entschiede still.
    @Test("Eine Übung trägt in jedem Workout dieselben Sätze und Bereiche")
    func sharedExercisesAreIdenticalEverywhere() throws {
        for workout in Workout.allCases {
            for exercise in ExerciseCatalog.exercises(for: workout) {
                let catalogEntry = try #require(ExerciseCatalog.all[exercise.id])
                #expect(exercise == catalogEntry,
                        "\(workout.rawValue)/\(exercise.id): weicht vom Katalog ab")
            }
        }
    }

    @Test("Ausgemusterte Übungen bleiben im Katalog, stehen aber in keinem Workout")
    func retiredExercisesStayResolvable() {
        // Der gespeicherte Verlauf zeigt auf diese IDs. Wer sie löscht,
        // macht alte Sätze namenlos — und die Muskelkarte zählt sie nicht
        // mehr mit.
        let retired = ["hipThrust", "calfRaiseSeated"]
        for id in retired {
            #expect(ExerciseCatalog.all[id] != nil, "\(id) fehlt im Katalog")
        }
        let inWorkouts = Set(Workout.allCases
            .flatMap { ExerciseCatalog.exercises(for: $0) }
            .map(\.id))
        for id in retired {
            #expect(!inWorkouts.contains(id), "\(id) steht noch in einem Workout")
        }
    }

    @Test("Außer den ausgemusterten kommt jede Übung in mindestens einem Workout vor")
    func everyOtherExerciseIsUsed() {
        let inWorkouts = Set(Workout.allCases
            .flatMap { ExerciseCatalog.exercises(for: $0) }
            .map(\.id))
        let unused = Set(ExerciseCatalog.all.keys).subtracting(inWorkouts)
        #expect(unused == ["hipThrust", "calfRaiseSeated"],
                "Ohne Workout: \(unused.sorted())")
    }

    @Test("Zehenheben an der Wand steht unter seiner alten ID im Katalog")
    func tibialisRaiseKeepsItsID() throws {
        // Umbenannt, aber nicht umgezogen: Die ID steht im gespeicherten
        // Verlauf, der Name nur auf dem Bildschirm.
        let e = try #require(ExerciseCatalog.all["tibialisRaise"])
        #expect(e.name == "Zehenheben an der Wand")
        #expect(e.muscles == [.tibialis: 1])
    }

    @Test("Bankdrücken steht mit den Werten aus der Spec im Katalog")
    func benchPressMatchesSpec() throws {
        let e = try #require(ExerciseCatalog.all["benchPress"])
        #expect(e.name == "Bankdrücken Langhantel")
        #expect(e.sets == 4)
        #expect(e.repLow == 6)
        #expect(e.repHigh == 10)
        #expect(e.increment == 2.5)
        #expect(e.allowsAssist == false)
        #expect(e.muscles[.chest] == 1)
        #expect(e.muscles[.frontDelt] == 0.5)
        #expect(e.muscles[.triceps] == 0.5)
    }

    @Test("Dips und Klimmzüge erlauben Unterstützung, sonst niemand")
    func onlyBodyweightExercisesAllowAssist() {
        let assisting = ExerciseCatalog.all.values.filter(\.allowsAssist).map(\.id).sorted()
        #expect(assisting == ["dips", "pullUp"])
    }

    @Test("Der Seitstütz ist die einzige Zeitübung")
    func onlyPlankIsTimed() {
        let timed = ExerciseCatalog.all.values.filter(\.isTimed).map(\.id)
        #expect(timed == ["sidePlank"])
    }

    @Test("Jede Übung hat drei Schritte, einen Fehler und einen Suchbegriff")
    func everyExerciseIsDocumented() {
        for e in ExerciseCatalog.all.values {
            #expect(e.howTo.count == 3, "\(e.id): \(e.howTo.count) Schritte statt 3")
            #expect(!e.commonMistake.isEmpty, "\(e.id): kein häufiger Fehler")
            #expect(!e.youTubeQuery.isEmpty, "\(e.id): kein Suchbegriff")
            #expect(!e.cue.isEmpty, "\(e.id): kein Technik-Hinweis")
        }
    }

    @Test("Jede Übung trifft mindestens einen Muskel, und zwar mit 1 oder 0,5")
    func muscleMappingIsPlausible() {
        for e in ExerciseCatalog.all.values {
            #expect(!e.muscles.isEmpty, "\(e.id): keine Muskelzuordnung")
            for (muscle, factor) in e.muscles {
                #expect(factor == 1 || factor == 0.5,
                        "\(e.id)/\(muscle): Faktor \(factor), erlaubt sind 1 und 0,5")
            }
            #expect(e.muscles.values.contains(1), "\(e.id): kein Hauptmuskel")
        }
    }

    @Test("Wiederholungsbereiche sind aufsteigend und Steigerungen positiv")
    func rangesAreSane() {
        for e in ExerciseCatalog.all.values {
            #expect(e.repLow < e.repHigh, "\(e.id): \(e.repLow)–\(e.repHigh)")
            #expect(e.increment > 0, "\(e.id): Steigerung \(e.increment)")
            #expect(e.sets >= 1, "\(e.id): \(e.sets) Sätze")
        }
    }

    @Test("Die schweren Beinübungen sind die beiden aus der Spec")
    func heavyLegExercises() {
        // Hip Thrust steht in keinem Workout mehr und kann deshalb auch in
        // keiner „leicht“-Variante entfallen.
        #expect(ExerciseCatalog.heavyLegIDs == ["splitSquat", "romanianDeadlift"])
    }

    @Test("Jeder Muskel hat einen Zielbereich aus der Spec")
    func muscleTargets() {
        #expect(Muscle.chest.target == 10...20)
        #expect(Muscle.frontDelt.target == 4...12)
        #expect(Muscle.lowerBack.target == 2...8)
        #expect(Muscle.calves.target == 6...14)
        for m in Muscle.allCases {
            #expect(m.target.lowerBound < m.target.upperBound, "\(m)")
            #expect(!m.german.isEmpty, "\(m)")
        }
    }
}
