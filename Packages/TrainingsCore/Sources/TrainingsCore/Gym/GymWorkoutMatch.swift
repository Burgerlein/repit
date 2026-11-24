import Foundation

/// Welches Apple-Training zu einer Gym-Sitzung gehört.
///
/// Eine Sitzung kennt nur ihren Tag — weder die Dashboard-Übernahme noch die
/// eigene Erfassung hält eine Uhrzeit fest. Das Zeitfenster für den Puls
/// stammt deshalb vollständig aus HealthKit, und diese Regel entscheidet,
/// welches Training gemeint ist.
public enum GymWorkoutMatch {

    /// Das Krafttraining des Tages, oder `nil`.
    ///
    /// Läufe und Spaziergänge kommen nicht in Frage, auch nicht als einziges
    /// Training des Tages: Der Puls eines Laufs unter einer Gym-Sitzung wäre
    /// schlicht falsch. Bei mehreren Krafttrainings gewinnt das längere; bei
    /// gleicher Dauer das frühere, damit die Antwort nicht von der
    /// Reihenfolge abhängt, in der HealthKit die Stichproben liefert.
    public static func match(day: Date, workouts: [WorkoutSample]) -> WorkoutSample? {
        let wanted = BerlinCalendar.startOfDay(day)
        return workouts
            .filter { $0.kind == .strength && BerlinCalendar.startOfDay($0.start) == wanted }
            .min { left, right in
                left.minutes != right.minutes
                    ? left.minutes > right.minutes
                    : left.start < right.start
            }
    }
}
