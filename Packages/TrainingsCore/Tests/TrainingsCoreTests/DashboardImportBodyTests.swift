import Foundation
import Testing
@testable import TrainingsCore

/// Waagenwerte und Umfänge aus der Exportdatei des alten Web-Dashboards.
///
/// Alle Zahlen hier sind erfunden. Die echte Exportdatei enthält Gesundheits-
/// und Tagebuchdaten und gehört nicht ins Repository — die Fixtures stehen
/// deshalb als String-Literale in dieser Datei.
@Suite("Dashboard-Import: Körperwerte")
struct DashboardImportBodyTests {

    private func parse(_ json: String) throws -> ImportedData {
        try DashboardImport.parse(Data(json.utf8))
    }

    @Test("Waagenwerte werden gelesen, neueste zuerst")
    func measurementsAreNewestFirst() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "bodyMeasurements": [
            { "date": "2026-02-01", "weightKg": 70.0, "bodyFatPct": 15.0,
              "muscleKg": 58.0, "musclePct": 82.9 },
            { "date": "2026-03-01", "weightKg": 71.5 }
          ] }
        """#
        let data = try parse(json)
        #expect(data.measurements.count == 2)
        // Die Datei führt den älteren Eintrag zuerst; die Liste dreht das um.
        let first = try #require(data.measurements.first)
        #expect(first.weightKg == 71.5)
        #expect(first.bodyFatPct == nil)
        #expect(first.muscleKg == nil)
        let c = BerlinCalendar.calendar.dateComponents([.year, .month, .day],
                                                       from: first.date)
        #expect(c.month == 3 && c.day == 1)
        #expect(data.measurements[1].musclePct == 82.9)
    }

    @Test("Ein Eintrag ohne Datum wird übersprungen")
    func measurementWithoutDateIsSkipped() throws {
        // Ohne Datum lässt sich der Wert nirgends einordnen. Ihn auf heute zu
        // setzen wäre schlimmer als ihn wegzulassen.
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "bodyMeasurements": [ { "weightKg": 70.0 },
                                { "date": "2026-03-01", "weightKg": 71.5 } ] }
        """#
        let data = try parse(json)
        #expect(data.measurements.count == 1)
    }

    @Test("Umfänge werden auf die Maße der App umgeschlüsselt")
    func circumferencesAreMapped() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "circumferences": [
            { "date": "2026-10-04", "armR": 33.8, "armRf": 36.2, "armL": 33.4,
              "armLf": 35.7, "chest": 96.5, "shoulder": 113.0, "waist": 79.0,
              "neck": 37.5, "hip": 93.0, "thigh": 55.4, "calf": 37.8 } ] }
        """#
        let data = try parse(json)
        let entry = try #require(data.circumferences.first)
        #expect(entry.values.count == 11)
        // Die Kürzel des Dashboards heißen anders als die Maße der App —
        // „shoulder" ist Einzahl, „hip" ebenso.
        #expect(entry.values[.upperArmRightRelaxed] == 33.8)
        #expect(entry.values[.upperArmRightFlexed] == 36.2)
        #expect(entry.values[.upperArmLeftRelaxed] == 33.4)
        #expect(entry.values[.upperArmLeftFlexed] == 35.7)
        #expect(entry.values[.shoulders] == 113.0)
        #expect(entry.values[.waist] == 79.0)
        #expect(entry.values[.hips] == 93.0)
    }

    @Test("Oberschenkel und Wade werden nach Seiten getrennt gelesen")
    func thighAndCalfAreReadPerSide() throws {
        // Das Dashboard kennt nur `thigh` und `calf` und meint damit rechts.
        // `thighL` und `calfL` stehen nur in einer von Hand ergänzten Datei —
        // deshalb lernen beide Schlüssel dazu, ohne dass die alten wandern.
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "circumferences": [
            { "date": "2026-10-04", "thigh": 55.4, "calf": 37.8,
              "thighL": 54.9, "calfL": 37.5 } ] }
        """#
        let data = try parse(json)
        let entry = try #require(data.circumferences.first)
        #expect(entry.values == [.thighRight: 55.4, .thighLeft: 54.9,
                                 .calfRight: 37.8, .calfLeft: 37.5])
    }

    @Test("Leere Felder werden nicht gespeichert")
    func emptyFieldsAreNotStored() throws {
        // Das Dashboard schreibt für nicht gemessene Stellen `null` oder eine
        // leere Zeichenkette. Als 0 cm übernommen wären das elf Nullwerte im
        // Verlauf.
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "circumferences": [ { "date": "2026-10-04", "waist": 79.0,
                                "neck": null, "chest": "" } ] }
        """#
        let data = try parse(json)
        let entry = try #require(data.circumferences.first)
        #expect(entry.values == [.waist: 79.0])
    }

    @Test("Ein unbekanntes Kürzel wird übergangen, nicht geraten")
    func unknownKeysAreIgnored() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "circumferences": [ { "date": "2026-10-04", "waist": 79.0,
                                "ellbogen": 28.0 } ] }
        """#
        let data = try parse(json)
        let entry = try #require(data.circumferences.first)
        #expect(entry.values == [.waist: 79.0])
    }

    @Test("Fehlende Abschnitte ergeben leere Listen, keinen Fehler")
    func missingSectionsAreEmpty() throws {
        // Ältere Exportdateien kennen die beiden Abschnitte noch nicht.
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1, "gymLogs": [] }
        """#
        let data = try parse(json)
        #expect(data.measurements.isEmpty)
        #expect(data.circumferences.isEmpty)
    }

    @Test("Die Gym-Trainings bleiben davon unberührt")
    func gymLogsStillWork() throws {
        let json = #"""
        { "format": "dashboard-manual-export", "version": 1,
          "gymLogs": [ { "date": "2026-02-17", "wo": "A", "id": "aaa111",
                         "ex": { "bench": [[40,8]] } } ],
          "bodyMeasurements": [ { "date": "2026-02-01", "weightKg": 70.0 } ] }
        """#
        let data = try parse(json)
        #expect(data.sessions.count == 1)
        #expect(data.measurements.count == 1)
    }
}
