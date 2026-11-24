import Testing
@testable import TrainingsCore

/// Die Workouts zerfallen in zwei Gruppen, und die Trennung trägt die ganze
/// Logik des Gym-Tabs: `rotation` bekommt Wochentage, Fristen und Plätze in
/// der Wochenleiste, `freelyChosen` nichts davon. Wer ein Workout in die
/// falsche Gruppe legt, baut entweder eine Kachel, die ewig „offen" sagt,
/// oder nimmt einem geplanten Workout seine Frist.
@Suite("Workouts")
struct WorkoutTests {

    @Test("Rotation und frei wählbare ergeben zusammen genau alle Workouts")
    func bothGroupsCoverEveryWorkout() {
        #expect(Set(Workout.rotation).union(Workout.freelyChosen)
                == Set(Workout.allCases))
        #expect(Workout.rotation.count + Workout.freelyChosen.count
                == Workout.allCases.count)
    }

    @Test("Kein Workout steht in beiden Gruppen")
    func groupsDoNotOverlap() {
        #expect(Set(Workout.rotation).intersection(Workout.freelyChosen).isEmpty)
    }

    @Test("Die Wochenrotation ist A bis D, die frei wählbaren sind Push, Pull und Legs")
    func groupsHaveTheExpectedMembers() {
        #expect(Workout.rotation == [.a, .b, .c, .d])
        #expect(Workout.freelyChosen == [.push, .pull, .legs])
    }

    @Test("Keine Gruppe nennt ein Workout zweimal")
    func groupsHaveNoDuplicates() {
        #expect(Set(Workout.rotation).count == Workout.rotation.count)
        #expect(Set(Workout.freelyChosen).count == Workout.freelyChosen.count)
    }

    // Der Rohwert steht im gespeicherten Verlauf und im Dashboard-Export.
    // Wer ihn ändert, macht alte Trainings namenlos.
    @Test("Die Rohwerte sind die Bezeichner aus der Spec")
    func rawValues() {
        #expect(Workout.a.rawValue == "A")
        #expect(Workout.b.rawValue == "B")
        #expect(Workout.c.rawValue == "C")
        #expect(Workout.d.rawValue == "D")
        #expect(Workout.push.rawValue == "Push")
        #expect(Workout.pull.rawValue == "Pull")
        #expect(Workout.legs.rawValue == "Legs")
    }

    @Test("Jeder Rohwert findet sein Workout wieder")
    func rawValuesRoundTrip() {
        for workout in Workout.allCases {
            #expect(Workout(rawValue: workout.rawValue) == workout)
        }
    }

    @Test("Die Titel stehen so in der Spec")
    func titles() {
        #expect(Workout.a.title == "Oberkörper Push + Arme")
        #expect(Workout.b.title == "Läufer-Kraft + Brust")
        #expect(Workout.c.title == "Oberkörper Pull + Arme")
        #expect(Workout.d.title == "Arme + Schultern")
        #expect(Workout.push.title == "Brust, Schultern, Trizeps")
        #expect(Workout.pull.title == "Rücken, hintere Schulter, Bizeps")
        #expect(Workout.legs.title == "Beine komplett")
    }

    /// Die Ansichten setzen überall `"\(label) — \(title)"` zusammen. Trüge
    /// der Titel den Namen noch einmal, stünde dort „Push — Push — Brust…".
    @Test("Kein Titel wiederholt den Namen des frei wählbaren Workouts")
    func titlesDoNotRepeatTheLabel() {
        // Nur für Push, Pull und Legs prüfbar: „Arme" in Gym A enthält
        // zwangsläufig das A, ohne dass sich etwas doppelte.
        for workout in Workout.freelyChosen {
            #expect(!workout.title.contains(workout.rawValue),
                    "\(workout.rawValue): Titel \(workout.title) nennt den Namen erneut")
        }
        for workout in Workout.allCases {
            #expect(!workout.title.contains("—"),
                    "\(workout.rawValue): Titel \(workout.title) trägt schon einen Gedankenstrich")
        }
    }

    @Test("Die Rotation heißt Gym A bis Gym D, die frei wählbaren nur beim Namen")
    func labels() {
        #expect(Workout.a.label == "Gym A")
        #expect(Workout.b.label == "Gym B")
        #expect(Workout.c.label == "Gym C")
        #expect(Workout.d.label == "Gym D")
        #expect(Workout.push.label == "Push")
        #expect(Workout.pull.label == "Pull")
        #expect(Workout.legs.label == "Legs")
    }

    @Test("Die Beschriftung folgt der Gruppe, nicht dem Einzelfall")
    func labelFollowsTheGroup() {
        for workout in Workout.rotation {
            #expect(workout.label == "Gym \(workout.rawValue)")
        }
        for workout in Workout.freelyChosen {
            #expect(workout.label == workout.rawValue)
        }
    }

    @Test("Die ungefähre Dauer steht so in der Spec")
    func minutes() {
        #expect(Workout.a.minutes == 70)
        #expect(Workout.b.minutes == 65)
        #expect(Workout.c.minutes == 70)
        #expect(Workout.d.minutes == 60)
        #expect(Workout.push.minutes == 70)
        #expect(Workout.pull.minutes == 70)
        #expect(Workout.legs.minutes == 60)
    }

    @Test("Jedes Workout dauert eine plausible Zeit")
    func minutesArePlausible() {
        for workout in Workout.allCases {
            #expect(workout.minutes >= 30 && workout.minutes <= 120,
                    "\(workout.rawValue): \(workout.minutes) min")
            #expect(!workout.title.isEmpty, "\(workout.rawValue): kein Titel")
            #expect(!workout.label.isEmpty, "\(workout.rawValue): keine Beschriftung")
        }
    }
}
