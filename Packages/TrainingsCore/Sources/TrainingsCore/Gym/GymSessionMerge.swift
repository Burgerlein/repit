import Foundation

public enum GymSessionMerge {

    /// Eigene Trainings und übernommene zusammenführen, neueste zuerst.
    ///
    /// Treffen beide auf denselben Tag **und** dasselbe Workout, gewinnt das
    /// eigene: Es ist der neuere Stand. Das ist genau der Fall, der beim
    /// Nachtragen eines Trainings entsteht, das schon im Dashboard stand —
    /// ohne diese Regel stünde es zweimal da, mit verschiedenen Zahlen.
    ///
    /// „Kein Workout" ist ein eigener Schlüssel und nicht dasselbe wie Gym A.
    /// Der Dashboard-Import erzeugt solche Sitzungen, und sie einem Workout
    /// zuzuschlagen hieße raten.
    public static func merge(logged: [ImportedSession],
                             imported: [ImportedSession]) -> [ImportedSession] {
        var byKey: [String: ImportedSession] = [:]
        for session in imported { byKey[key(session)] = session }
        for session in logged { byKey[key(session)] = session }

        return byKey.values.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            // Gleicher Zeitstempel, verschiedene Workouts: feste Reihenfolge,
            // damit die Liste nicht bei jedem Start anders aussieht.
            return ($0.workout?.rawValue ?? "") < ($1.workout?.rawValue ?? "")
        }
    }

    private static func key(_ session: ImportedSession) -> String {
        let day = BerlinCalendar.startOfDay(session.date).timeIntervalSince1970
        return "\(Int(day))-\(session.workout?.rawValue ?? "?")"
    }

    /// App-ID auf die Satzlisten, neueste Sitzung zuerst — die Form, die
    /// `Progression.suggest` erwartet.
    public static func history(_ sessions: [ImportedSession])
    -> [String: [[CompletedSet]]] {
        var out: [String: [[CompletedSet]]] = [:]
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            for exercise in session.exercises {
                out[exercise.exerciseID, default: []].append(exercise.sets)
            }
        }
        return out
    }
}
