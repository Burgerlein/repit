import Foundation

/// Die Abschnitte, in die der Plan zerfällt. Nur die Fälle — wie sie heißen
/// und welche Farbe sie tragen, entscheidet die Oberfläche.
public enum TrainingPhase: String, CaseIterable, Sendable {
    case beforeSurgery, recovery, base, build, raceSpecific
    case taper, raceWeek, regeneration, summer
}

/// Eine Woche, so weit der Überblick sie braucht: Phase, Umfang, Gym-Zahl.
/// Was genau an welchem Tag ansteht, steht hier bewusst nicht.
public struct PlanWeekOutline: Equatable, Sendable {
    public let number: Int
    public let phase: TrainingPhase
    /// 0 bedeutet: in dieser Woche ist kein Lauf geplant.
    public let plannedKm: Double
    public let gymSessions: Int
    public let isDeload: Bool

    public init(number: Int, phase: TrainingPhase, plannedKm: Double,
                gymSessions: Int, isDeload: Bool = false) {
        self.number = number
        self.phase = phase
        self.plannedKm = plannedKm
        self.gymSessions = gymSessions
        self.isDeload = isDeload
    }
}

/// Ein zusammenhängender Lauf gleicher Phase. Tritt dieselbe Phase später
/// erneut auf, ist das ein zweiter Block — kein gemeinsamer.
public struct PlanPhaseBlock: Equatable, Sendable {
    public let phase: TrainingPhase
    /// Nie leer, in der Reihenfolge der Eingabe.
    public let weeks: [PlanWeekOutline]

    public init(phase: TrainingPhase, weeks: [PlanWeekOutline]) {
        self.phase = phase
        self.weeks = weeks
    }

    public var firstWeek: Int { weeks.first?.number ?? 0 }
    public var lastWeek: Int { weeks.last?.number ?? 0 }
    public var weekCount: Int { weeks.count }

    /// Spanne über die Wochen mit geplanten Läufen. Wochen ohne Lauf ziehen
    /// die Untergrenze nicht auf null — sonst stünde an jeder Entlastungsphase
    /// „0–35 km". Ohne jeden Lauf gibt es keine Spanne.
    public var plannedKmRange: ClosedRange<Double>? {
        let running = weeks.map(\.plannedKm).filter { $0 > 0 }
        guard let low = running.min(), let high = running.max() else { return nil }
        return low...high
    }

    /// Der gemeinsame Wert, wenn alle Wochen gleich viele Gym-Einheiten haben.
    /// Sonst nil — ein Mittelwert wäre hier eine Erfindung.
    public var gymSessions: Int? {
        guard let first = weeks.first?.gymSessions else { return nil }
        return weeks.allSatisfy { $0.gymSessions == first } ? first : nil
    }
}

/// Die Zahlen für den Kopf des Plan-Screens.
public struct PlanKeyFigures: Equatable, Sendable {
    public let peakWeek: Int?
    public let peakKm: Double
    public let totalPlannedKm: Double
    public let deloadWeeks: Int

    public init(peakWeek: Int?, peakKm: Double, totalPlannedKm: Double, deloadWeeks: Int) {
        self.peakWeek = peakWeek
        self.peakKm = peakKm
        self.totalPlannedKm = totalPlannedKm
        self.deloadWeeks = deloadWeeks
    }
}

/// Fasst die Wochen eines Plans zusammen. Reine Rechnung, keine Daten, keine
/// Texte — die Wochen kommen von außen herein.
public enum PlanOutline {

    public static func phaseBlocks(for weeks: [PlanWeekOutline]) -> [PlanPhaseBlock] {
        var blocks: [PlanPhaseBlock] = []
        var run: [PlanWeekOutline] = []

        for week in weeks {
            if let open = run.first, open.phase != week.phase {
                blocks.append(PlanPhaseBlock(phase: open.phase, weeks: run))
                run = []
            }
            run.append(week)
        }
        if let open = run.first {
            blocks.append(PlanPhaseBlock(phase: open.phase, weeks: run))
        }
        return blocks
    }

    public static func keyFigures(for weeks: [PlanWeekOutline]) -> PlanKeyFigures {
        let peakKm = weeks.map(\.plannedKm).max() ?? 0
        // Ein Plan ohne geplante Läufe hat keine Spitzenwoche. Die erste
        // Null-Woche als Spitze auszugeben wäre schlicht falsch.
        let peakWeek = peakKm > 0 ? weeks.first { $0.plannedKm == peakKm }?.number : nil

        return PlanKeyFigures(
            peakWeek: peakWeek,
            peakKm: peakKm,
            totalPlannedKm: weeks.reduce(0) { $0 + $1.plannedKm },
            deloadWeeks: weeks.count { $0.isDeload }
        )
    }

    /// Die laufende Woche und die darauf folgenden, höchstens `limit` Stück.
    /// Die Reihenfolge der Eingabe bleibt erhalten.
    public static func upcoming(_ weeks: [PlanWeekOutline],
                                from currentWeek: Int, limit: Int) -> [PlanWeekOutline] {
        guard limit > 0 else { return [] }
        return Array(weeks.filter { $0.number >= currentWeek }.prefix(limit))
    }
}
