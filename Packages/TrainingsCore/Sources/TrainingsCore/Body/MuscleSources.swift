import Foundation

/// Woher die Sätze eines Muskels kommen: eine Übung, ihr Beitrag und wann sie
/// zuletzt dran war. Die Karte zeigt eine Zahl je Muskel — das hier ist
/// dieselbe Zahl, nur nach Übung aufgeschlüsselt.
public struct MuscleSource: Equatable, Sendable {
    public let exerciseID: String
    /// Gewichteter Beitrag dieser Übung, gemittelt auf die Woche. Die Summe
    /// über alle Quellen eines Muskels ist genau sein Wert aus `weeklySets`.
    public let weeklySets: Double
    /// Ungewichtet: drei Sätze sind drei, auch wenn der Muskel nur mithilft.
    public let setCount: Int
    /// Der jüngste Satz dieser Übung im Fenster, mit der Uhrzeit des Satzes.
    public let lastDate: Date

    public init(exerciseID: String, weeklySets: Double, setCount: Int, lastDate: Date) {
        self.exerciseID = exerciseID
        self.weeklySets = weeklySets
        self.setCount = setCount
        self.lastDate = lastDate
    }
}

extension MuscleVolume {

    /// Die Übungen, die den Muskel im Fenster getroffen haben, mit dem
    /// größten Beitrag oben. Fenstergrenze, Gewichtung und Mittelung sind
    /// dieselben wie in `weeklySets` — es ist dieselbe Rechnung, nur nicht
    /// auf den Muskel zusammengefasst.
    ///
    /// Bei gleichem Beitrag steht das jüngere Training oben, bei gleichem
    /// Datum die kleinere Übungs-ID: Sonst hinge die Reihenfolge von der
    /// Laune des Dictionarys ab und sprünge bei jedem Aufruf.
    public static func sources(for muscle: Muscle, sets: [TrainedSet],
                               window days: Int, now: Date) -> [MuscleSource] {
        guard let cutoff = windowStart(days: days, now: now) else { return [] }

        var weighted: [String: Double] = [:]
        var counts: [String: Int] = [:]
        var lastDates: [String: Date] = [:]

        for set in sets {
            // Unbekannte Übungen werden übergangen wie in `weeklySets`:
            // Ein Satz, dessen Gewichte niemand kennt, zählt nirgends mit.
            guard BerlinCalendar.startOfDay(set.date) >= cutoff,
                  let exercise = ExerciseCatalog.all[set.exerciseID],
                  let weight = exercise.muscles[muscle]
            else { continue }
            weighted[set.exerciseID, default: 0] += weight
            counts[set.exerciseID, default: 0] += 1
            lastDates[set.exerciseID] = max(lastDates[set.exerciseID] ?? set.date, set.date)
        }

        let weeks = Double(days) / 7
        return weighted.compactMap { id, sum -> MuscleSource? in
            guard let lastDate = lastDates[id] else { return nil }
            return MuscleSource(exerciseID: id, weeklySets: sum / weeks,
                                setCount: counts[id] ?? 0, lastDate: lastDate)
        }
        .sorted { a, b in
            if a.weeklySets != b.weeklySets { return a.weeklySets > b.weeklySets }
            if a.lastDate != b.lastDate { return a.lastDate > b.lastDate }
            return a.exerciseID < b.exerciseID
        }
    }
}
