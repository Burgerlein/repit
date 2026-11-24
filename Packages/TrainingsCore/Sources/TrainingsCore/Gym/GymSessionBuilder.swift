import Foundation

/// Ein eingetippter Satz, so wie er im Formular steht — noch Text, noch nicht
/// geprüft. Die Umwandlung in Zahlen gehört hierher und nicht in die Ansicht:
/// Sie entscheidet, was ein gültiger Satz ist, und das ist Fachlogik.
public struct RawSet: Equatable, Sendable {
    public let weight: String
    public let reps: String

    public init(weight: String, reps: String) {
        self.weight = weight
        self.reps = reps
    }
}

public enum GymSessionBuilder {

    /// Wandelt eingetippte Sätze in eine Sitzung.
    ///
    /// Gibt `nil` zurück, wenn keine einzige Übung einen brauchbaren Satz hat.
    /// Ein leeres Training abzulegen hieße, in „Letzte Trainings" eine Zeile
    /// ohne Inhalt zu führen — und im Verlauf einen Punkt bei null.
    public static func session(id: String, date: Date, workout: Workout,
                               minutes: Int?, note: String?,
                               entries: [String: [RawSet]],
                               assist: [String: Bool] = [:]) -> ImportedSession? {
        var byExerciseID: [String: [CompletedSet]] = [:]
        for (exerciseID, raw) in entries {
            // Eine Übung, die der Katalog nicht kennt, wird übergangen statt
            // geraten. Sie hätte weder Muskeln noch Zielbereiche.
            guard ExerciseCatalog.all[exerciseID] != nil else { continue }
            let sets = raw.compactMap {
                completedSet($0, assisted: assist[exerciseID] ?? false)
            }
            if !sets.isEmpty { byExerciseID[exerciseID] = sets }
        }
        guard !byExerciseID.isEmpty else { return nil }

        return ImportedSession(
            id: id,
            // Die Uhrzeit bleibt stehen. Zwei Trainings an einem Tag sollen
            // sich unterscheiden lassen.
            date: date,
            workout: workout,
            minutes: minutes,
            note: note.flatMap { $0.isEmpty ? nil : $0 },
            exercises: GymSessionOrder.ordered(byExerciseID, for: workout))
    }

    /// Ein Satz zählt, wenn er Wiederholungen hat. Alles andere ist ein leeres
    /// Feld, das jemand übersprungen hat.
    private static func completedSet(_ raw: RawSet, assisted: Bool) -> CompletedSet? {
        let repsText = raw.reps.trimmingCharacters(in: .whitespaces)
        guard let reps = Int(repsText), reps > 0 else { return nil }

        let weightText = raw.weight.trimmingCharacters(in: .whitespaces)
        let weight: Double
        if weightText.isEmpty {
            // Dips und Klimmzüge am eigenen Körpergewicht sind gültige Sätze.
            weight = 0
        } else {
            // Komma und Punkt beide annehmen: Auf der Zehnertastatur liegt je
            // nach Region das eine oder das andere.
            guard let value = Double(weightText.replacingOccurrences(of: ",", with: "."))
            else { return nil }
            weight = value
        }

        // Unterstützung wird negativ gespeichert. `-abs` statt `-`, damit ein
        // schon negativ eingetipptes Gewicht nicht zurück ins Positive kippt.
        return CompletedSet(weight: assisted ? -abs(weight) : weight, reps: reps)
    }
}

/// Die Reihenfolge der Übungen innerhalb einer Sitzung.
///
/// Dieselbe Regel für übernommene und eigene Trainings — sonst stünde dieselbe
/// Sitzung je nach Herkunft anders da. Ein Dictionary hat keine Reihenfolge,
/// und eine Ansicht, die bei jedem Start anders aussieht, ist kaputt.
enum GymSessionOrder {

    static func ordered(_ byExerciseID: [String: [CompletedSet]],
                        for workout: Workout?) -> [ImportedExercise] {
        let planned: [String]
        if let workout {
            planned = ExerciseCatalog.exercises(for: workout).map(\.id)
                .filter { byExerciseID[$0] != nil }
        } else {
            planned = []
        }
        let rest = byExerciseID.keys.filter { !planned.contains($0) }.sorted()
        return (planned + rest).compactMap { id in
            byExerciseID[id].map { ImportedExercise(exerciseID: id, sets: $0) }
        }
    }
}
