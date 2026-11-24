import Foundation

/// Was beim Lesen der Dashboard-Datei schiefgehen kann. Alle drei Fälle
/// bedeuten: Der Nutzer hat die falsche Datei gewählt. Deshalb tragen sie
/// den gefundenen Wert mit — ohne ihn kann die Ansicht nicht sagen, was
/// stattdessen da war.
public enum DashboardImportError: Error, Equatable {
    case notJSON
    case wrongFormat(String)
    case unsupportedVersion(Int)
}

/// Die Sätze einer Übung innerhalb einer Sitzung, bereits auf die App-ID
/// umgeschlüsselt.
public struct ImportedExercise: Equatable, Sendable, Codable {
    public let exerciseID: String
    public let sets: [CompletedSet]

    public init(exerciseID: String, sets: [CompletedSet]) {
        self.exerciseID = exerciseID
        self.sets = sets
    }
}

/// Ein abgeschlossenes Gym-Training aus dem Dashboard.
public struct ImportedSession: Equatable, Sendable, Identifiable, Codable {
    public let id: String
    /// Berliner Tagesbeginn.
    public let date: Date
    /// `nil`, wenn das Dashboard kein oder ein unbekanntes Workout führt.
    public let workout: Workout?
    public let minutes: Int?
    public let note: String?
    public let exercises: [ImportedExercise]

    public init(id: String, date: Date, workout: Workout?, minutes: Int?,
                note: String?, exercises: [ImportedExercise]) {
        self.id = id
        self.date = date
        self.workout = workout
        self.minutes = minutes
        self.note = note
        self.exercises = exercises
    }

    public var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    /// Tonnage nach der Rechnung des Dashboards: Summe aus `max(0, kg) ×
    /// Wiederholungen`. Unterstützte Sätze tragen nichts bei — negatives
    /// Gewicht ist Hilfe der Maschine, keine Last. Was dort tatsächlich
    /// bewegt wurde, wäre Körpergewicht minus Hilfe; das Dashboard rechnet
    /// so nicht, und zwei verschiedene Zahlen für dieselbe Sitzung wären
    /// schlimmer als eine vorsichtige.
    public var volumeKg: Double {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + max(0, $1.weight) * Double($1.reps) }
        }
    }
}

/// Eine Waagenmessung aus dem Dashboard.
public struct ImportedMeasurement: Equatable, Sendable {
    public let date: Date
    public let weightKg: Double?
    public let bodyFatPct: Double?
    public let muscleKg: Double?
    public let musclePct: Double?

    public init(date: Date, weightKg: Double?, bodyFatPct: Double?,
                muscleKg: Double?, musclePct: Double?) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPct = bodyFatPct
        self.muscleKg = muscleKg
        self.musclePct = musclePct
    }
}

/// Das Ergebnis eines Imports.
public struct ImportedData: Equatable, Sendable {
    /// Neueste Sitzung zuerst.
    public let sessions: [ImportedSession]
    /// Dashboard-IDs ohne Entsprechung im Katalog, sortiert und ohne
    /// Dubletten. Sie werden gemeldet statt verschluckt: Eine Übung, die
    /// lautlos verschwindet, fällt erst Monate später auf.
    public let unknownExerciseIDs: [String]
    /// App-ID auf die Satzlisten, neueste Sitzung zuerst — genau die Form,
    /// die `Progression.suggest` erwartet.
    public let history: [String: [[CompletedSet]]]
    /// Waagenwerte, neueste zuerst.
    public let measurements: [ImportedMeasurement]
    /// Umfangsmessungen, neueste zuerst.
    public let circumferences: [CircumferenceEntry]

    /// Die beiden letzten Parameter haben Vorgabewerte, damit Aufrufer, die
    /// nur Trainings kennen, unverändert übersetzen.
    public init(sessions: [ImportedSession], unknownExerciseIDs: [String],
                history: [String: [[CompletedSet]]],
                measurements: [ImportedMeasurement] = [],
                circumferences: [CircumferenceEntry] = []) {
        self.sessions = sessions
        self.unknownExerciseIDs = unknownExerciseIDs
        self.history = history
        self.measurements = measurements
        self.circumferences = circumferences
    }

    public static let empty = ImportedData(sessions: [], unknownExerciseIDs: [], history: [:])
}

/// Liest die Exportdatei des alten Web-Dashboards.
///
/// Die Datei enthält weit mehr als Gym-Trainings — Waagenwerte, Tagesgefühl,
/// Auszeiten, Rezepte. Übernommen wird hier nur `gymLogs`; alles andere
/// braucht eigene Modelle und kommt mit M7. Was ignoriert wird, verschwindet
/// nicht: Die Datei bleibt beim Nutzer und kann erneut gelesen werden.
public enum DashboardImport {

    public static func parse(_ data: Data) throws -> ImportedData {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw DashboardImportError.notJSON
        }

        let format = root["format"] as? String ?? ""
        guard format == "dashboard-manual-export" else {
            throw DashboardImportError.wrongFormat(format)
        }

        let version = root["version"] as? Int ?? 0
        guard version == 1 else {
            throw DashboardImportError.unsupportedVersion(version)
        }

        let logs = root["gymLogs"] as? [[String: Any]] ?? []

        var unknown: Set<String> = []
        var sessions: [ImportedSession] = []

        for log in logs {
            guard let date = day(log["date"] as? String) else { continue }

            let raw = log["ex"] as? [String: Any] ?? [:]
            var byAppID: [String: [CompletedSet]] = [:]
            for (dashboardID, value) in raw {
                guard let appID = exerciseIDs[dashboardID] else {
                    unknown.insert(dashboardID)
                    continue
                }
                let sets = completedSets(from: value)
                // Eine Übung, von der kein Satz übrig bleibt, wurde
                // abgebrochen. Sie als leeren Eintrag zu führen sähe nach
                // einem Fehler des Importers aus.
                if !sets.isEmpty { byAppID[appID] = sets }
            }

            let workout = (log["wo"] as? String).flatMap(Workout.init(rawValue:))
            let note = (log["note"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            sessions.append(ImportedSession(
                id: log["id"] as? String ?? UUID().uuidString,
                date: date,
                workout: workout,
                minutes: log["dur"] as? Int,
                note: note,
                exercises: order(byAppID, for: workout)))
        }

        // Gleiches Datum behält die Reihenfolge der Datei; `sorted` allein
        // gibt das nicht her.
        sessions = sessions.enumerated()
            .sorted { ($0.element.date, $1.offset) > ($1.element.date, $0.offset) }
            .map(\.element)

        var history: [String: [[CompletedSet]]] = [:]
        for session in sessions {
            for exercise in session.exercises {
                history[exercise.exerciseID, default: []].append(exercise.sets)
            }
        }

        let measurements = (root["bodyMeasurements"] as? [[String: Any]] ?? [])
            .compactMap { entry -> ImportedMeasurement? in
                guard let date = day(entry["date"] as? String) else { return nil }
                return ImportedMeasurement(date: date,
                                           weightKg: entry["weightKg"] as? Double,
                                           bodyFatPct: entry["bodyFatPct"] as? Double,
                                           muscleKg: entry["muscleKg"] as? Double,
                                           musclePct: entry["musclePct"] as? Double)
            }
            .sorted { $0.date > $1.date }

        let circumferences = (root["circumferences"] as? [[String: Any]] ?? [])
            .compactMap { entry -> CircumferenceEntry? in
                guard let date = day(entry["date"] as? String) else { return nil }
                var values: [Circumference: Double] = [:]
                for (key, measure) in circumferenceKeys {
                    // `as? Double` lässt null und Zeichenketten durchfallen —
                    // leere Felder werden nicht gespeichert.
                    if let value = entry[key] as? Double { values[measure] = value }
                }
                return CircumferenceEntry(date: date, values: values)
            }
            .sorted { $0.date > $1.date }

        return ImportedData(sessions: sessions,
                            unknownExerciseIDs: unknown.sorted(),
                            history: history,
                            measurements: measurements,
                            circumferences: circumferences)
    }

    /// Reihenfolge des Workouts zuerst, Fremdübungen alphabetisch dahinter.
    /// Ohne bekanntes Workout bleibt nur die alphabetische Ordnung — ein
    /// Dictionary hat keine, und eine Ansicht, die bei jedem Start anders
    /// aussieht, ist kaputt.
    private static func order(_ byAppID: [String: [CompletedSet]],
                             for workout: Workout?) -> [ImportedExercise] {
        let planned: [String]
        if let workout {
            planned = ExerciseCatalog.exercises(for: workout).map(\.id)
                .filter { byAppID[$0] != nil }
        } else {
            planned = []
        }
        let rest = byAppID.keys.filter { !planned.contains($0) }.sorted()
        return (planned + rest).compactMap { id in
            byAppID[id].map { ImportedExercise(exerciseID: id, sets: $0) }
        }
    }

    /// `[[kg, Wiederholungen], …]`. Beim Seitstütz stehen an zweiter Stelle
    /// Sekunden — dieselbe Struktur, deshalb keine Sonderbehandlung.
    private static func completedSets(from value: Any) -> [CompletedSet] {
        guard let pairs = value as? [Any] else { return [] }
        return pairs.compactMap { pair in
            guard let pair = pair as? [Any], pair.count == 2,
                  let weight = pair[0] as? Double,
                  let reps = pair[1] as? Int,
                  // Das Dashboard zeigt Sätze ohne Wiederholungen nicht an.
                  // Sie hier zu zählen ergäbe andere Zahlen als dort.
                  reps > 0
            else { return nil }
            return CompletedSet(weight: weight, reps: reps)
        }
    }

    private static func day(_ text: String?) -> Date? {
        guard let text else { return nil }
        let f = DateFormatter()
        f.calendar = BerlinCalendar.calendar
        f.timeZone = BerlinCalendar.calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text).map(BerlinCalendar.startOfDay)
    }

    /// Dashboard-Kürzel auf die Umfangsmaße der App.
    /// Quelle: dashboard-reference.html, Zeile 2001.
    private static let circumferenceKeys: [String: Circumference] = [
        "armR": .upperArmRightRelaxed, "armRf": .upperArmRightFlexed,
        "armL": .upperArmLeftRelaxed, "armLf": .upperArmLeftFlexed,
        "chest": .chest, "shoulder": .shoulders, "waist": .waist,
        "neck": .neck, "hip": .hips,
        // `thigh` und `calf` meinen im Dashboard die rechte Seite. `thighL`
        // und `calfL` kennt es nicht — die stehen nur in einer von Hand
        // ergänzten Exportdatei.
        "thigh": .thighRight, "thighL": .thighLeft,
        "calf": .calfRight, "calfL": .calfLeft
    ]

    /// Dashboard-ID auf App-ID. Vollständig in `docs/uebungs-id-zuordnung.md`
    /// begründet. `lat` ist Seitheben, nicht Latziehen — eine Verwechslung
    /// importierte 4-kg-Sätze als Klimmzüge.
    public static let exerciseIDs: [String: String] = [
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
}
