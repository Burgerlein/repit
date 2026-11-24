import Foundation
import Testing
@testable import TrainingsCore

/// Einmalige Datenübernahme aus der Exportdatei des alten Web-Dashboards.
///
/// Alle Zahlen hier sind erfunden. Die echte Exportdatei enthält Gesundheits-
/// und Tagebuchdaten und gehört nicht ins Repository — die Fixtures stehen
/// deshalb als String-Literale in dieser Datei.
@Suite("Dashboard-Import")
struct DashboardImportTests {

    private func parse(_ json: String) throws -> ImportedData {
        try DashboardImport.parse(Data(json.utf8))
    }

    private func set(_ weight: Double, _ reps: Int) -> CompletedSet {
        CompletedSet(weight: weight, reps: reps)
    }

    // MARK: - Kopfdaten der Datei

    @Test("Bytes, die kein JSON sind, werden als solche gemeldet")
    func notJSON() {
        #expect(throws: DashboardImportError.notJSON) {
            try DashboardImport.parse(Data("das ist kein JSON, nur Text".utf8))
        }
    }

    @Test("Ein fremdes Format wird mit dem gefundenen Wert abgelehnt")
    func wrongFormatIsReported() {
        let trainingsexport = #"""
        { "format": "trainingsexport", "version": 1, "gymLogs": [] }
        """#
        #expect(throws: DashboardImportError.wrongFormat("trainingsexport")) {
            try DashboardImport.parse(Data(trainingsexport.utf8))
        }

        let fremd = #"""
        { "format": "irgendwas-anderes", "version": 1, "gymLogs": [] }
        """#
        #expect(throws: DashboardImportError.wrongFormat("irgendwas-anderes")) {
            try DashboardImport.parse(Data(fremd.utf8))
        }
    }

    @Test("Eine andere Version wird mit der gefundenen Zahl abgelehnt")
    func unsupportedVersionIsReported() {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 2, "gymLogs": [] }
        """#
        #expect(throws: DashboardImportError.unsupportedVersion(2)) {
            try DashboardImport.parse(Data(json.utf8))
        }
    }

    @Test("Fehlender gymLogs-Schlüssel ergibt ein leeres Ergebnis, keinen Fehler")
    func missingGymLogsIsEmpty() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1, "exportedAt": "2026-03-01",
          "settings": { "hrMax": 190 } }
        """#
        let data = try parse(json)
        #expect(data.sessions.isEmpty)
        #expect(data.unknownExerciseIDs.isEmpty)
        #expect(data.history.isEmpty)
    }

    @Test("Leere gymLogs ergeben ein leeres Ergebnis")
    func emptyGymLogsIsEmpty() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1, "gymLogs": [] }
        """#
        let data = try parse(json)
        #expect(data.sessions.isEmpty)
        #expect(data.unknownExerciseIDs.isEmpty)
        #expect(data.history.isEmpty)
    }

    // MARK: - Eine Sitzung

    @Test("Eine Sitzung übernimmt Kennung, Workout, Dauer, Notiz und Sätze")
    func singleSessionIsReadCompletely() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "dur": 72, "id": "aaa111",
              "note": "Testnotiz",
              "ex": { "bench": [[40,8],[40,7]], "lat": [[6,15]] } }
          ] }
        """#
        let data = try parse(json)
        #expect(data.sessions.count == 1)
        let s = try #require(data.sessions.first)
        #expect(s.id == "aaa111")
        #expect(s.workout == .a)
        #expect(s.minutes == 72)
        #expect(s.note == "Testnotiz")
        #expect(s.exercises.map(\.exerciseID) == ["benchPress", "lateralRaise"])
        #expect(s.exercises.first?.sets == [set(40, 8), set(40, 7)])
        #expect(s.setCount == 3)
        // 40·8 + 40·7 + 6·15 = 690
        #expect(s.volumeKg == 690)
    }

    @Test("Das Datum ist der Berliner Tagesbeginn")
    func dateIsBerlinStartOfDay() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "bench": [[40,8]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        let c = BerlinCalendar.calendar.dateComponents([.year, .month, .day], from: s.date)
        #expect(c.year == 2026)
        #expect(c.month == 2)
        #expect(c.day == 17)
        #expect(BerlinCalendar.startOfDay(s.date) == s.date)
    }

    @Test("Fehlende Dauer und fehlende Notiz werden zu nil")
    func missingDurationAndNoteAreNil() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "bench": [[40,8]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.minutes == nil)
        #expect(s.note == nil)
    }

    @Test("Eine leere Notiz wird zu nil, nicht zu einer leeren Zeichenkette")
    func emptyNoteBecomesNil() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "dur": 55, "id": "aaa111", "note": "",
              "ex": { "bench": [[40,8]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.minutes == 55)
        #expect(s.note == nil)
    }

    // MARK: - Sätze

    @Test("Sätze ohne Wiederholungen werden verworfen")
    func setsWithoutRepsAreDropped() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "bench": [[50,10],[50,0],[50,-3],[55,4]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.exercises.first?.sets == [set(50, 10), set(55, 4)])
        #expect(s.setCount == 2)
        // 50·10 + 55·4 = 720
        #expect(s.volumeKg == 720)
    }

    @Test("Das Volumen zählt nur positives Gewicht, unterstützte Sätze steuern null bei")
    func volumeIgnoresAssistedAndZeroWeight() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "bench": [[50,10]], "dips": [[-30,8]], "lat": [[0,12]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        // 50·10 + max(0,−30)·8 + 0·12 = 500
        #expect(s.volumeKg == 500)
        // Die unterstützten und die Null-Sätze zählen trotzdem als Sätze.
        #expect(s.setCount == 3)
    }

    @Test("Negatives Gewicht bleibt negativ erhalten")
    func assistedWeightKeepsItsSign() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "C", "id": "aaa111",
              "ex": { "pull": [[-27,9],[-27,8]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.exercises.first?.exerciseID == "pullUp")
        #expect(s.exercises.first?.sets == [set(-27, 9), set(-27, 8)])
        #expect(s.volumeKg == 0)
    }

    @Test("Kaputte Satz-Einträge werden übersprungen, die übrigen Sätze bleiben")
    func brokenSetEntriesAreSkipped() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "bench": [[40,8],[],[40],[40,8,2],["viel",8],[40,"acht"],[45,6]] } }
          ] }
        """#
        let data = try parse(json)
        let s = try #require(data.sessions.first)
        #expect(s.exercises.first?.sets == [set(40, 8), set(45, 6)])
        #expect(s.setCount == 2)
        // 40·8 + 45·6 = 590
        #expect(s.volumeKg == 590)
    }

    // MARK: - Reihenfolge

    @Test("Sitzungen kommen neueste zuerst, unabhängig von der Dateireihenfolge")
    func sessionsAreNewestFirst() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-10", "wo": "A", "id": "alt",
              "ex": { "bench": [[40,8]] } },
            { "date": "2026-02-24", "wo": "A", "id": "neu",
              "ex": { "bench": [[45,8]] } },
            { "date": "2026-02-17", "wo": "A", "id": "mitte",
              "ex": { "bench": [[42.5,8]] } }
          ] }
        """#
        let data = try parse(json)
        #expect(data.sessions.map(\.id) == ["neu", "mitte", "alt"])
    }

    @Test("Übungen stehen in der Reihenfolge des Workouts, Fremdübungen danach")
    func exercisesFollowWorkoutOrder() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "A", "id": "aaa111",
              "ex": { "lat": [[6,15]], "pull": [[-20,8]], "bench": [[40,8]],
                      "dbCurl": [[12,10]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        // Workout A: benchPress … lateralRaise … bicepsCurl; pullUp gehört zu C
        // und hängt hinten an.
        #expect(s.exercises.map(\.exerciseID)
                == ["benchPress", "lateralRaise", "bicepsCurl", "pullUp"])
    }

    @Test("Ohne wo gibt es kein Workout und die Übungen stehen alphabetisch nach App-ID")
    func missingWorkoutSortsAlphabetically() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "id": "aaa111",
              "ex": { "lat": [[6,15]], "ohTri": [[20,12]], "dbCurl": [[12,10]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.workout == nil)
        // Workout A hätte lateralRaise, overheadTriceps, bicepsCurl ergeben.
        #expect(s.exercises.map(\.exerciseID)
                == ["bicepsCurl", "lateralRaise", "overheadTriceps"])
    }

    @Test("Ein unbekanntes wo verhält sich wie ein fehlendes")
    func unknownWorkoutBehavesLikeMissing() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-17", "wo": "Z", "id": "aaa111",
              "ex": { "lat": [[6,15]], "ohTri": [[20,12]], "dbCurl": [[12,10]] } }
          ] }
        """#
        let s = try #require(try parse(json).sessions.first)
        #expect(s.workout == nil)
        #expect(s.exercises.map(\.exerciseID)
                == ["bicepsCurl", "lateralRaise", "overheadTriceps"])
    }

    // MARK: - Unbekannte Übungen

    @Test("Unbekannte Dashboard-IDs werden gemeldet und erzeugen keine Übung")
    func unknownExerciseIDsAreCollected() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-10", "wo": "A", "id": "alt",
              "ex": { "zumba": [[10,10]], "bench": [[40,8]] } },
            { "date": "2026-02-12", "wo": "C", "id": "neu",
              "ex": { "zumba": [[10,10]], "abs": [[0,30]], "pull": [[-20,8]] } }
          ] }
        """#
        let data = try parse(json)
        #expect(data.unknownExerciseIDs == ["abs", "zumba"])
        #expect(data.sessions.map(\.id) == ["neu", "alt"])
        #expect(data.sessions[0].exercises.map(\.exerciseID) == ["pullUp"])
        #expect(data.sessions[1].exercises.map(\.exerciseID) == ["benchPress"])
        #expect(data.history["zumba"] == nil)
        #expect(data.history["abs"] == nil)
    }

    // MARK: - Verlauf

    @Test("Der Verlauf führt je App-ID die Sitzungen, neueste zuerst")
    func historyIsNewestFirstPerExercise() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [
            { "date": "2026-02-10", "wo": "A", "id": "alt",
              "ex": { "bench": [[40,8],[40,7]] } },
            { "date": "2026-02-17", "wo": "A", "id": "neu",
              "ex": { "bench": [[42.5,7]], "lat": [[6,15]] } }
          ] }
        """#
        let data = try parse(json)
        #expect(data.history.count == 2)
        #expect(data.history["benchPress"] == [[set(42.5, 7)], [set(40, 8), set(40, 7)]])
        #expect(data.history["lateralRaise"] == [[set(6, 15)]])
    }

    // MARK: - Zuordnungstabelle

    @Test("Die Zuordnung hat 26 Paare, lat ist Seitheben und pull ist Latziehen")
    func mappingHasKnownEntries() {
        #expect(DashboardImport.exerciseIDs.count == 26)
        #expect(DashboardImport.exerciseIDs["lat"] == "lateralRaise")
        #expect(DashboardImport.exerciseIDs["pull"] == "pullUp")
    }

    @Test("Die Zuordnung entspricht der Tabelle aus docs/uebungs-id-zuordnung.md")
    func mappingMatchesDocumentedTable() {
        let expected: [String: String] = [
            "bbCurl": "ezCurl",
            "bench": "benchPress",
            "bss": "splitSquat",
            "cableRow": "cableRowClose",
            "calfB": "calfRaiseSeated",
            "calfS": "calfRaiseStanding",
            "close": "closeGripBench",
            "dbCurl": "bicepsCurl",
            "dips": "dips",
            "face": "facePull",
            "fly": "cableFly",
            "hammer": "hammerCurl",
            "hip": "hipThrust",
            "inclCurl": "inclineCurl",
            "inclDb": "inclineDumbbellPress",
            "lat": "lateralRaise",
            "ohTri": "overheadTriceps",
            "ohpDb": "shoulderPressDumbbell",
            "ohpM": "shoulderPressMachine",
            "pull": "pullUp",
            "push": "tricepsPushdown",
            "rdl": "romanianDeadlift",
            "rear": "reverseFly",
            "row1": "oneArmRow",
            "side": "sidePlank",
            "tib": "tibialisRaise"
        ]
        #expect(DashboardImport.exerciseIDs == expected)
    }

    @Test("Jede App-ID der Zuordnung steht im Katalog und kommt nur einmal vor")
    func mappingTargetsAreUniqueCatalogEntries() {
        let targets = DashboardImport.exerciseIDs.values.sorted()
        for id in targets {
            #expect(ExerciseCatalog.all[id] != nil, "\(id) steht nicht im Übungskatalog")
        }
        #expect(Set(targets).count == targets.count,
                "Zwei Dashboard-IDs zeigen auf dieselbe App-ID")
    }

    @Test("Ohne Dashboard-Kürzel sind genau die sieben neuen Übungen")
    func onlyTheNewExercisesLackADashboardKey() {
        // Das Dashboard ist ein abgeschlossener Export von früher. Die
        // Übungen aus der erweiterten SPEC 4.4 wurden dort nie mitgeschrieben
        // und können deshalb kein Kürzel haben. Jede andere Lücke wäre eine
        // vergessene Zeile und löschte beim Import stillschweigend Trainings.
        let targets = Set(DashboardImport.exerciseIDs.values)
        let ohneKuerzel = Set(ExerciseCatalog.all.keys).subtracting(targets)
        #expect(ohneKuerzel == ["barbellRow", "straightArmPulldown", "backExtension",
                                "legPress", "legCurl", "hipAbduction", "legExtension"],
                "ohne Kürzel: \(ohneKuerzel.sorted())")
    }
}
