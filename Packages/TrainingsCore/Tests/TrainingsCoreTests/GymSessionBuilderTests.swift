import Foundation
import Testing
@testable import TrainingsCore

/// Ein im Gym mitgeschriebenes Training wird beim Abschließen aus den
/// eingetippten Feldern zu einer Sitzung und liegt danach neben den aus dem
/// Dashboard übernommenen Trainings.
///
/// Zwei Bausteine: `GymSessionBuilder` macht aus Zeichenketten Zahlen,
/// `GymSessionMerge` führt eigene und übernommene Sitzungen zusammen.
///
/// Alle Zahlen hier sind erfunden. Echte Trainingsdaten gehören nicht ins
/// Repository.
@Suite("Eigene Gym-Trainings")
struct GymSessionBuilderTests {

    // MARK: - Werkzeug

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      hour: Int = 0, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute)
        return BerlinCalendar.calendar.date(from: components) ?? .distantPast
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        BerlinCalendar.startOfDay(date(year, month, dayOfMonth))
    }

    private func set(_ weight: Double, _ reps: Int) -> CompletedSet {
        CompletedSet(weight: weight, reps: reps)
    }

    /// Eine fertige Sitzung von Hand, für die Zusammenführung.
    private func session(_ id: String, _ when: Date, _ workout: Workout?,
                         _ exercises: [ImportedExercise] = []) -> ImportedSession {
        ImportedSession(id: id, date: when, workout: workout, minutes: nil,
                        note: nil, exercises: exercises)
    }

    // MARK: - Aus Feldern werden Sätze

    @Test("Gewicht und Wiederholungen werden zu einem Satz")
    func plainSetIsRead() {
        let result = GymSessionBuilder.session(
            id: "eigen-1", date: date(2026, 9, 21, hour: 18, minute: 30),
            workout: .a, minutes: 62, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: "8")]])

        #expect(result?.exercises.count == 1)
        #expect(result?.exercises.first?.exerciseID == "benchPress")
        #expect(result?.exercises.first?.sets == [set(40, 8)])
    }

    @Test("Komma und Punkt bedeuten dasselbe Gewicht")
    func commaAndPointAreBothAccepted() {
        // Auf der Zehnertastatur liegt je nach Region das eine oder das
        // andere Trennzeichen. Wer 42,5 kg auflegt, hat nicht 425 kg bewegt.
        let result = GymSessionBuilder.session(
            id: "eigen-2", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["benchPress": [RawSet(weight: "42,5", reps: "6"),
                                     RawSet(weight: "42.5", reps: "5")]])

        #expect(result?.exercises.first?.sets == [set(42.5, 6), set(42.5, 5)])
    }

    @Test("Sätze ohne brauchbare Wiederholungen fallen weg")
    func setsWithoutRepsAreDropped() {
        // Ein leeres Feld ist ein Satz, der nie stattgefunden hat. Ihn mit
        // null Wiederholungen zu speichern verfälscht Tonnage und Vorschlag.
        let result = GymSessionBuilder.session(
            id: "eigen-3", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: ""),
                                     RawSet(weight: "40", reps: "   "),
                                     RawSet(weight: "40", reps: "0"),
                                     RawSet(weight: "40", reps: "acht"),
                                     RawSet(weight: "40", reps: "8")]])

        #expect(result?.exercises.first?.sets == [set(40, 8)])
    }

    @Test("Ein Satz ohne Gewicht zählt als null Kilo")
    func missingWeightCountsAsZero() {
        // Dips am eigenen Körpergewicht sind ein gültiger Satz, kein
        // unvollständiges Formular.
        let result = GymSessionBuilder.session(
            id: "eigen-4", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["dips": [RawSet(weight: "", reps: "10")]])

        #expect(result?.exercises.first?.exerciseID == "dips")
        #expect(result?.exercises.first?.sets == [set(0, 10)])
    }

    @Test("Unterstützung macht das Gewicht negativ")
    func assistTurnsWeightNegative() {
        // −27 heißt: 27 kg Hilfe von der Maschine. So liest es die
        // Progression, so rechnet die Tonnage.
        let result = GymSessionBuilder.session(
            id: "eigen-5", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["dips": [RawSet(weight: "27", reps: "6")]],
            assist: ["dips": true])

        #expect(result?.exercises.first?.sets == [set(-27, 6)])

        // Ohne Schalter bleibt dieselbe Eingabe Zusatzgewicht.
        let added = GymSessionBuilder.session(
            id: "eigen-6", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["dips": [RawSet(weight: "27", reps: "6")]])

        #expect(added?.exercises.first?.sets == [set(27, 6)])
    }

    @Test("Ein schon negativ eingetipptes Gewicht wird nicht noch einmal gedreht")
    func assistDoesNotFlipTwice() {
        // Sonst würde aus 27 kg Hilfe plötzlich 27 kg Zusatzlast.
        let result = GymSessionBuilder.session(
            id: "eigen-7", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["dips": [RawSet(weight: "-27", reps: "6"),
                               RawSet(weight: "-24,5", reps: "5")]],
            assist: ["dips": true])

        #expect(result?.exercises.first?.sets == [set(-27, 6), set(-24.5, 5)])
    }

    @Test("Eine Übung ohne übrig gebliebenen Satz taucht nicht auf")
    func exerciseWithoutSetsIsOmitted() {
        // Ein leerer Eintrag sähe in „Letzte Trainings" nach einem Fehler
        // aus — die Übung wurde schlicht nicht gemacht.
        let result = GymSessionBuilder.session(
            id: "eigen-8", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: "8")],
                      "dips": [RawSet(weight: "30", reps: "0")],
                      "lateralRaise": []])

        #expect(result?.exercises.count == 1)
        #expect(result?.exercises.map(\.exerciseID) == ["benchPress"])
    }

    @Test("Bleibt nichts übrig, entsteht keine Sitzung")
    func nothingLeftMeansNoSession() {
        // Wer das Formular öffnet und nichts einträgt, hat nicht trainiert.
        let empty = GymSessionBuilder.session(
            id: "eigen-9", date: date(2026, 9, 21), workout: .a,
            minutes: 60, note: "Nur kurz reingeschaut",
            entries: [:])
        #expect(empty == nil)

        let unusable = GymSessionBuilder.session(
            id: "eigen-10", date: date(2026, 9, 21), workout: .a,
            minutes: 60, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: "")],
                      "dips": []])
        #expect(unusable == nil)
    }

    @Test("Die Übungen stehen in der Reihenfolge des Workouts, Fremdes alphabetisch dahinter")
    func exercisesFollowWorkoutOrder() {
        // Dieselbe Regel wie beim Dashboard-Import: Ein Dictionary hat keine
        // Reihenfolge, und eine Ansicht, die bei jedem Start anders aussieht,
        // ist kaputt.
        let result = GymSessionBuilder.session(
            id: "eigen-11", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["lateralRaise": [RawSet(weight: "12", reps: "15")],
                      "benchPress": [RawSet(weight: "40", reps: "8")],
                      "dips": [RawSet(weight: "0", reps: "9")],
                      "pullUp": [RawSet(weight: "0", reps: "7")],
                      "facePull": [RawSet(weight: "18", reps: "14")]])

        // Gym A: benchPress, inclineDumbbellPress, shoulderPressDumbbell,
        // dips, lateralRaise, overheadTriceps, bicepsCurl — davon vorhanden
        // sind drei. pullUp und facePull gehören zu Gym C und hängen
        // alphabetisch nach App-ID hinten an.
        #expect(result?.exercises.map(\.exerciseID)
                == ["benchPress", "dips", "lateralRaise", "facePull", "pullUp"])
    }

    @Test("Eine unbekannte Übungs-ID wird übergangen")
    func unknownExerciseIDIsSkipped() {
        // Nicht raten: Eine ID, die der Katalog nicht kennt, hat keine
        // Muskelzuordnung und keinen Wiederholungsbereich.
        let result = GymSessionBuilder.session(
            id: "eigen-12", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: "8")],
                      "einhornheben": [RawSet(weight: "99", reps: "3")]])

        #expect(result?.exercises.map(\.exerciseID) == ["benchPress"])

        // Bleibt nur Unbekanntes, entsteht keine Sitzung.
        let onlyUnknown = GymSessionBuilder.session(
            id: "eigen-13", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: nil,
            entries: ["einhornheben": [RawSet(weight: "99", reps: "3")]])
        #expect(onlyUnknown == nil)
    }

    @Test("ID, Workout, Dauer und Notiz werden unverändert durchgereicht")
    func headerValuesArePassedThrough() {
        let result = GymSessionBuilder.session(
            id: "eigen-14", date: date(2026, 9, 21), workout: .c,
            minutes: 73, note: "Schulter hat gezwickt",
            entries: ["pullUp": [RawSet(weight: "0", reps: "7")]])

        #expect(result?.id == "eigen-14")
        #expect(result?.workout == .c)
        #expect(result?.minutes == 73)
        #expect(result?.note == "Schulter hat gezwickt")

        // Keine Dauer eingetragen heißt keine Dauer, nicht null Minuten.
        let withoutMinutes = GymSessionBuilder.session(
            id: "eigen-15", date: date(2026, 9, 21), workout: .c,
            minutes: nil, note: nil,
            entries: ["pullUp": [RawSet(weight: "0", reps: "7")]])
        #expect(withoutMinutes?.minutes == nil)
        #expect(withoutMinutes?.note == nil)
    }

    @Test("Ein frei wählbares Workout wird wie jedes andere eingetragen")
    func freelyChosenWorkoutIsLoggedLikeAnyOther() {
        // Push, Pull und Legs haben keinen festen Tag — beim Eintragen
        // macht das keinen Unterschied. Alle Zahlen erfunden.
        let result = GymSessionBuilder.session(
            id: "eigen-18", date: date(2026, 9, 23, hour: 18), workout: .legs,
            minutes: 58, note: nil,
            entries: ["legPress": [RawSet(weight: "80", reps: "10")],
                      "legCurl": [RawSet(weight: "30", reps: "12")]])

        #expect(result?.workout == .legs)
        #expect(result?.minutes == 58)
        #expect(result?.exercises.count == 2)
        // Reihenfolge des Workouts, nicht die der Eingabe.
        #expect(result?.exercises.map(\.exerciseID) == ["legPress", "legCurl"])
    }

    @Test("Eine leere Notiz wird nil, keine leere Zeichenkette")
    func emptyNoteBecomesNil() {
        // Sonst zeichnet die Ansicht eine leere Notizzeile unter das Training.
        let result = GymSessionBuilder.session(
            id: "eigen-16", date: date(2026, 9, 21), workout: .a,
            minutes: nil, note: "",
            entries: ["benchPress": [RawSet(weight: "40", reps: "8")]])

        #expect(result?.note == nil)
    }

    @Test("Das Datum behält die Uhrzeit des Trainings")
    func dateKeepsTimeOfDay() {
        // Anders als beim Import, der nur ein Tagesdatum kennt: Wer um 19:45
        // abschließt, soll das später auch sehen.
        let stamp = date(2026, 9, 21, hour: 19, minute: 45)
        let result = GymSessionBuilder.session(
            id: "eigen-17", date: stamp, workout: .a,
            minutes: nil, note: nil,
            entries: ["benchPress": [RawSet(weight: "40", reps: "8")]])

        #expect(result?.date == stamp)
        #expect(result?.date != BerlinCalendar.startOfDay(stamp))
    }

    // MARK: - Eigene und übernommene Trainings zusammenführen

    @Test("Beide Listen stehen zusammen, neueste zuerst")
    func mergeSortsNewestFirst() {
        let logged = [session("eigen", date(2026, 9, 20, hour: 18), .a)]
        let imported = [session("import-neu", day(2026, 9, 22), .c),
                        session("import-alt", day(2026, 9, 18), .b)]

        let merged = GymSessionMerge.merge(logged: logged, imported: imported)

        #expect(merged.map(\.id) == ["import-neu", "eigen", "import-alt"])
    }

    @Test("Am selben Tag und beim selben Workout gewinnt das eigene Training")
    func loggedWinsOverImportedSameDayAndWorkout() {
        // Beide Quellen beschreiben dieselbe Einheit: Der Nutzer hat sie in
        // der App abgeschlossen und später die alte Exportdatei eingelesen.
        // Der eigene Eintrag ist der neuere Stand — zwei Zeilen für ein
        // Training wären schlicht falsch.
        let logged = [session("eigen", date(2026, 9, 20, hour: 18, minute: 30), .a,
                              [ImportedExercise(exerciseID: "benchPress",
                                                sets: [set(42.5, 8)])])]
        let imported = [session("import", day(2026, 9, 20), .a,
                                [ImportedExercise(exerciseID: "benchPress",
                                                  sets: [set(40, 8)])])]

        let merged = GymSessionMerge.merge(logged: logged, imported: imported)

        #expect(merged.count == 1)
        #expect(merged.first?.id == "eigen")
        #expect(merged.first?.exercises.first?.sets == [set(42.5, 8)])
    }

    @Test("Zwei verschiedene Workouts am selben Tag bleiben beide stehen")
    func differentWorkoutsOnSameDayBothSurvive() {
        // Gym A morgens und Gym C abends ist zulässig und darf nicht zu
        // einem Training zusammenfallen.
        let logged = [session("eigen-a", date(2026, 9, 20, hour: 19), .a)]
        let imported = [session("import-c", day(2026, 9, 20), .c)]

        let merged = GymSessionMerge.merge(logged: logged, imported: imported)

        #expect(merged.count == 2)
        #expect(Set(merged.map(\.id)) == ["eigen-a", "import-c"])
    }

    @Test("Ein übernommenes Training ohne Workout bleibt neben dem eigenen stehen")
    func importedWithoutWorkoutSurvives() {
        // Das Dashboard führt nicht zu jedem Eintrag ein Workout. „Kein
        // Workout" ist nicht dasselbe wie Gym A — wegwerfen hieße raten.
        let logged = [session("eigen-a", date(2026, 9, 20, hour: 19), .a)]
        let imported = [session("import-ohne", day(2026, 9, 20), nil)]

        let merged = GymSessionMerge.merge(logged: logged, imported: imported)

        #expect(merged.count == 2)
        #expect(Set(merged.map(\.id)) == ["eigen-a", "import-ohne"])
    }

    @Test("Leere Listen auf einer oder beiden Seiten ergeben kein Problem")
    func mergeHandlesEmptyLists() {
        #expect(GymSessionMerge.merge(logged: [], imported: []).isEmpty)

        let only = session("import", day(2026, 9, 20), .b)
        #expect(GymSessionMerge.merge(logged: [], imported: [only]).map(\.id) == ["import"])

        let own = session("eigen", date(2026, 9, 20, hour: 18), .b)
        #expect(GymSessionMerge.merge(logged: [own], imported: []).map(\.id) == ["eigen"])
    }

    // MARK: - Verlauf pro Übung

    @Test("Der Verlauf bildet App-ID auf die Satzlisten ab, neueste Sitzung zuerst")
    func historyMapsExerciseToSets() {
        // Genau die Form, die `Progression.suggest` erwartet — sonst
        // schlägt der Vorschlag die alte Last vor.
        let sessions = [
            session("neu", date(2026, 9, 21, hour: 18), .a, [
                ImportedExercise(exerciseID: "benchPress", sets: [set(50, 6), set(50, 5)]),
                ImportedExercise(exerciseID: "lateralRaise", sets: [set(12, 15)])
            ]),
            session("alt", day(2026, 9, 14), .a, [
                ImportedExercise(exerciseID: "benchPress", sets: [set(47.5, 8)])
            ])
        ]

        let history = GymSessionMerge.history(sessions)

        #expect(history["benchPress"] == [[set(50, 6), set(50, 5)], [set(47.5, 8)]])
        #expect(history["lateralRaise"] == [[set(12, 15)]])
        // Was nie trainiert wurde, steht nicht im Verlauf.
        #expect(history["pullUp"] == nil)
    }

    @Test("Eine Übung aus zwei Sitzungen hat zwei Einträge")
    func historyKeepsOneEntryPerSession() {
        let sessions = [
            session("neu", date(2026, 9, 21, hour: 18), .c, [
                ImportedExercise(exerciseID: "pullUp", sets: [set(0, 8)])
            ]),
            session("alt", day(2026, 9, 14), .c, [
                ImportedExercise(exerciseID: "pullUp", sets: [set(0, 6)])
            ])
        ]

        let history = GymSessionMerge.history(sessions)

        #expect(history["pullUp"]?.count == 2)
        #expect(history["pullUp"] == [[set(0, 8)], [set(0, 6)]])
        #expect(history.keys.count == 1)
    }

    @Test("Zusammengeführt und ausgewertet ergibt den Verlauf beider Quellen")
    func mergeThenHistory() {
        // Der tatsächliche Weg: eigenes Training abschließen, Dashboard-Daten
        // daneben, Vorschlag aus beidem.
        let logged = GymSessionBuilder.session(
            id: "eigen", date: date(2026, 9, 21, hour: 18, minute: 15), workout: .a,
            minutes: 64, note: nil,
            entries: ["benchPress": [RawSet(weight: "50", reps: "6")]])

        let imported = [session("import", day(2026, 9, 14), .a, [
            ImportedExercise(exerciseID: "benchPress", sets: [set(47.5, 8)])
        ])]

        let merged = GymSessionMerge.merge(logged: [logged].compactMap { $0 },
                                           imported: imported)
        let history = GymSessionMerge.history(merged)

        #expect(merged.map(\.id) == ["eigen", "import"])
        #expect(history["benchPress"] == [[set(50, 6)], [set(47.5, 8)]])
    }
}
