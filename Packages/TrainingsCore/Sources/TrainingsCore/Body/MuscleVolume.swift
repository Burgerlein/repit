import Foundation

/// Ein einzelner absolvierter Satz, reduziert auf das, was die Muskelkarte
/// braucht. Bewusst nicht `ImportedSession`: Mit M2 kommen die Sätze aus
/// SwiftData, und diese Rechnung soll davon nichts merken.
public struct TrainedSet: Equatable, Sendable {
    public let date: Date
    public let exerciseID: String

    public init(date: Date, exerciseID: String) {
        self.date = date
        self.exerciseID = exerciseID
    }
}

/// Wie ein Muskel zu seinem Zielbereich steht. Farben wählt die Ansicht.
public enum MuscleStatus: Equatable, Sendable {
    case priority   // unter der halben Untergrenze
    case low        // unter dem Ziel
    case ok
    case high       // über dem Ziel
}

public enum MuscleVolume {

    /// Anfang des Fensters: der Tagesbeginn des Tages, der `days - 1` Tage
    /// zurückliegt. Bei sieben Tagen zählt der Satz von vor sechs Tagen also
    /// noch mit, der von vor sieben nicht mehr. Ohne Fenster (`days <= 0`)
    /// gibt es keine Grenze und damit nichts zu zählen.
    ///
    /// Die Aufschlüsselung in `sources(for:sets:window:now:)` rechnet mit
    /// derselben Grenze. Liefen die beiden auseinander, erklärte die
    /// Aufschlüsselung eine Zahl, die auf der Karte nirgends steht.
    static func windowStart(days: Int, now: Date) -> Date? {
        guard days > 0 else { return nil }
        return BerlinCalendar.calendar.date(
            byAdding: .day, value: -(days - 1), to: BerlinCalendar.startOfDay(now))
    }

    /// Harte Sätze pro Woche je Muskel, gemittelt über das Fenster.
    /// Hauptmuskel 1, Nebenmuskel 0,5 — die Gewichte stehen im Übungskatalog.
    public static func weeklySets(_ sets: [TrainedSet], window days: Int,
                                  now: Date) -> [Muscle: Double] {
        var total = Dictionary(uniqueKeysWithValues: Muscle.allCases.map { ($0, 0.0) })
        guard let cutoff = windowStart(days: days, now: now) else { return total }

        for set in sets {
            guard BerlinCalendar.startOfDay(set.date) >= cutoff,
                  let exercise = ExerciseCatalog.all[set.exerciseID]
            else { continue }
            for (muscle, weight) in exercise.muscles {
                total[muscle, default: 0] += weight
            }
        }

        let weeks = Double(days) / 7
        return total.mapValues { $0 / weeks }
    }

    public static func status(_ muscle: Muscle, sets: Double) -> MuscleStatus {
        let target = muscle.target
        if sets > target.upperBound { return .high }
        if sets >= target.lowerBound { return .ok }
        return sets >= target.lowerBound / 2 ? .low : .priority
    }

    /// Dringendste zuerst: rot, gelb, blau, grün. Innerhalb einer Gruppe
    /// entscheidet der Abstand zur Untergrenze, damit die Reihenfolge nicht
    /// von der Laune des Dictionarys abhängt.
    public static func sortedByNeed(_ volume: [Muscle: Double]) -> [Muscle] {
        func rank(_ status: MuscleStatus) -> Int {
            switch status {
            case .priority: 0
            case .low: 1
            case .high: 2
            case .ok: 3
            }
        }
        return Muscle.allCases.sorted { a, b in
            let va = volume[a] ?? 0, vb = volume[b] ?? 0
            let ra = rank(status(a, sets: va)), rb = rank(status(b, sets: vb))
            if ra != rb { return ra < rb }
            let qa = va / a.target.lowerBound, qb = vb / b.target.lowerBound
            if qa != qb { return qa < qb }
            return a.rawValue < b.rawValue
        }
    }
}
