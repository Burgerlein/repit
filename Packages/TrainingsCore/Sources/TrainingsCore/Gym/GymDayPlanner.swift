import Foundation

/// Ein Workout mit seinem festen Wochentag. 2 ist Montag, wie im
/// gregorianischen Kalender.
public struct PlannedGym: Equatable, Sendable {
    public let workout: Workout
    public let weekday: Int

    public init(workout: Workout, weekday: Int) {
        self.workout = workout
        self.weekday = weekday
    }
}

/// Ein angefangenes, noch nicht abgeschlossenes Training.
public struct GymDraft: Equatable, Sendable {
    public let workout: Workout
    public let doneExercises: Int
    public let totalExercises: Int

    public init(workout: Workout, doneExercises: Int, totalExercises: Int) {
        self.workout = workout
        self.doneExercises = doneExercises
        self.totalExercises = totalExercises
    }
}

public enum GymSlotStatus: Equatable, Sendable {
    case done(Date)
    case running
    case today
    case open
    case overdue
    case paused
}

public struct GymSlot: Equatable, Sendable {
    public let workout: Workout
    /// Kein fester Tag im Plan — etwa Gym D, das nur nachgeholt wird.
    public let weekday: Int?
    public let status: GymSlotStatus
}

/// Was die Fokus-Karte zeigt. Trägt nur Zahlen und Fälle; wie das formuliert
/// wird, entscheidet die Ansicht.
public enum GymFocus: Equatable, Sendable {
    case inProgress(workout: Workout, done: Int, total: Int)
    case planned(workout: Workout)
    case rest(next: Workout?, inDays: Int?, overdue: Workout?)
    case recovery(dayAfterSurgery: Int, earliestReturn: Date)
}

public struct GymDay: Equatable, Sendable {
    public let focus: GymFocus
    public let week: [GymSlot]

    /// Wie viele Einheiten dieser Woche abgeschlossen sind.
    ///
    /// Gezählt werden **Plätze**, nicht Trainings: In `week` steht je Workout
    /// genau ein Platz, und `status(for:)` setzt ihn nur dann auf `.done`,
    /// wenn das Abschlussdatum in derselben Woche liegt wie heute. Die
    /// Beschränkung auf die laufende Woche steckt damit schon in den Plätzen
    /// — eine Zählung über `completed` zählte Wochen davor mit.
    ///
    /// Wer dasselbe Workout zweimal in einer Woche macht, hat einen Platz
    /// gefüllt, nicht zwei.
    public var doneThisWeek: Int {
        week.count { if case .done = $0.status { true } else { false } }
    }
}

/// Leitet aus Plan, erledigten Trainings und Entwurf ab, was der Gym-Tab
/// heute zeigt. Die Erholung nach der OP hat Vorrang vor allem anderen.
public enum GymDayPlanner {

    public static func day(today: Date,
                           planned: [PlannedGym],
                           completed: [Workout: Date],
                           overdue: [Workout],
                           draft: GymDraft?,
                           surgery: Date?,
                           pauseDays: Int = 14) -> GymDay {
        let cal = BerlinCalendar.calendar
        let start = BerlinCalendar.startOfDay(today)
        let slots = sorted(planned)
        // Frei wählbare Workouts haben keinen Tag, also auch keine Frist.
        // Hier abzuschneiden statt an jeder Auswertungsstelle: Sonst stünde
        // „Push nachholen" in der Fokus-Karte, obwohl Push nie fällig war.
        let overdue = overdue.filter { Workout.rotation.contains($0) }

        if let surgery, let recovery = recovery(start: start, surgery: surgery,
                                                pauseDays: pauseDays, cal: cal) {
            return GymDay(focus: recovery,
                          week: slots.map { GymSlot(workout: $0.workout,
                                                    weekday: $0.weekday,
                                                    status: .paused) })
        }

        let week = slots.map { entry in
            GymSlot(workout: entry.workout, weekday: entry.weekday,
                    status: status(for: entry, start: start, completed: completed,
                                   overdue: overdue, draft: draft, cal: cal))
        }

        if let draft, draft.doneExercises > 0 {
            return GymDay(focus: .inProgress(workout: draft.workout,
                                             done: draft.doneExercises,
                                             total: draft.totalExercises),
                          week: week)
        }

        let weekday = cal.component(.weekday, from: start)
        if let entry = slots.first(where: { $0.weekday == weekday }),
           !isDone(entry.workout, on: start, completed: completed, cal: cal) {
            return GymDay(focus: .planned(workout: entry.workout), week: week)
        }

        // Workouts ohne festen Tag kommen hier nie in Frage — „als Nächstes"
        // braucht einen Tag, sonst stünde dort eine Zahl ohne Bedeutung.
        let upcoming = slots
            .compactMap { entry -> (workout: Workout, inDays: Int)? in
                guard let plannedDay = entry.weekday, plannedDay > weekday,
                      !isSameWeekDone(entry.workout, start: start,
                                      completed: completed, cal: cal) else { return nil }
                return (entry.workout, plannedDay - weekday)
            }
            .min { $0.inDays < $1.inDays }

        return GymDay(focus: .rest(next: upcoming?.workout,
                                   inDays: upcoming?.inDays,
                                   overdue: overdue.first),
                      week: week)
    }

    /// Ein Workout mit optionalem Tag. `PlannedGym` verlangt einen Tag;
    /// innerhalb der Rechnung braucht es aber auch die Workouts ohne.
    private struct Entry {
        let workout: Workout
        let weekday: Int?
    }

    /// Workouts ohne festen Tag hängen hinten an, sonst nach Wochentag.
    private static func sorted(_ planned: [PlannedGym]) -> [Entry] {
        // Auch hier filtern und nicht nur bei `overdue`: Ein frei wählbares
        // Workout mit Wochentag wäre ein Widerspruch in sich, und die
        // Wochenleiste zeigte dann doch einen Platz für Push. Was von außen
        // kommt, darf die Zusage nicht aushebeln.
        let scheduled = planned
            .filter { Workout.rotation.contains($0.workout) }
            .sorted { $0.weekday < $1.weekday }
            .map { Entry(workout: $0.workout, weekday: $0.weekday) }
        // Nur die Rotation füllt die Wochenleiste auf. Push, Pull und Legs
        // bekämen sonst je eine Kachel, die auf ewig „offen" sagt.
        let missing = Workout.rotation
            .filter { w in !planned.contains { $0.workout == w } }
            .map { Entry(workout: $0, weekday: nil) }
        return scheduled + missing
    }

    private static func recovery(start: Date, surgery: Date, pauseDays: Int,
                                 cal: Calendar) -> GymFocus? {
        let opDay = BerlinCalendar.startOfDay(surgery)
        guard start >= opDay,
              let back = earliestReturn(after: opDay, pauseDays: pauseDays, cal: cal),
              start < back else { return nil }
        let days = cal.dateComponents([.day], from: opDay, to: start).day ?? 0
        return .recovery(dayAfterSurgery: days, earliestReturn: back)
    }

    /// Erster Montag ab OP plus Pause. Fällt das Ende der Pause selbst auf
    /// einen Montag, ist das der Tag.
    private static func earliestReturn(after opDay: Date, pauseDays: Int,
                                       cal: Calendar) -> Date? {
        guard var cursor = cal.date(byAdding: .day, value: pauseDays, to: opDay) else { return nil }
        while cal.component(.weekday, from: cursor) != 2 {
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
        }
        return cursor
    }

    private static func status(for entry: Entry, start: Date,
                               completed: [Workout: Date], overdue: [Workout],
                               draft: GymDraft?, cal: Calendar) -> GymSlotStatus {
        if let draft, draft.workout == entry.workout, draft.doneExercises > 0 { return .running }
        if let done = completed[entry.workout],
           cal.isDate(done, equalTo: start, toGranularity: .weekOfYear) {
            return .done(BerlinCalendar.startOfDay(done))
        }
        if overdue.contains(entry.workout) { return .overdue }

        // Ab hier entscheidet allein der Kalender. Ohne festen Tag gibt er
        // nichts her: ein Workout wie Gym D ist nie „heute" und wird auch
        // nie von selbst überfällig. Dass es trotzdem als „nachholen"
        // erscheinen kann, liegt an der `overdue`-Liste weiter oben — die
        // kommt von außen und wiegt schwerer als jede Ableitung aus dem Tag.
        let weekday = cal.component(.weekday, from: start)
        guard let plannedDay = entry.weekday else { return .open }
        if plannedDay == weekday { return .today }
        return plannedDay > weekday ? .open : .overdue
    }

    private static func isDone(_ workout: Workout, on start: Date,
                               completed: [Workout: Date], cal: Calendar) -> Bool {
        guard let done = completed[workout] else { return false }
        return cal.isDate(done, inSameDayAs: start)
    }

    private static func isSameWeekDone(_ workout: Workout, start: Date,
                                       completed: [Workout: Date], cal: Calendar) -> Bool {
        guard let done = completed[workout] else { return false }
        return cal.isDate(done, equalTo: start, toGranularity: .weekOfYear)
    }
}
