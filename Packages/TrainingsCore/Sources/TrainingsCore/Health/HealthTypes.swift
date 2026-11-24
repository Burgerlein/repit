import Foundation

public struct DailyMetrics: Equatable, Sendable {
    public let date: Date
    public let steps: Int?
    public let activeKcal: Int?
    public let basalKcal: Int?
    public let restingHR: Int?
    public let hrvMs: Double?
    public let respRate: Double?
    public let vo2max: Double?
    public let weightKg: Double?
    public let bodyFatPct: Double?
    public let leanKg: Double?
    /// Trainingsminuten für den Trainieren-Ring.
    public let exerciseMinutes: Double?
    /// Stunden, in denen mindestens eine Minute gestanden wurde — der Steh-Ring.
    public let standHours: Int?
    /// Puls-Abfall eine Minute nach Belastungsende. Höher ist besser.
    /// Pro Tag der höchste gemessene Wert; ein lockeres Training soll den
    /// Tageswert nicht nach unten ziehen.
    public let recoveryHRDrop: Int?
    /// Alkoholische Getränke des Tages, kumulativ (#125).
    ///
    /// **Eine Zahl, keine Menge.** HealthKit hat keinen Nährwert Alkohol;
    /// der einzige Tagebuch-Typ ist
    /// `HKQuantityTypeIdentifierNumberOfAlcoholicBeverages` mit der Einheit
    /// `count`. Umgerechnet wird nichts — „ein Getränk sind soundso viel
    /// Gramm" wäre erfunden.
    ///
    /// Nicht ganzzahlig: Ein Tagebuch darf 0,5 eintragen, und auf `Int` zu
    /// runden hieße, einen halben Abend verschwinden zu lassen.
    ///
    /// `nil` heißt „kein Wert" und **nie** „nichts getrunken". Apple verrät
    /// den Lesestatus nicht; an einem Tag ohne Eintrag kann die Freigabe
    /// fehlen.
    public let alcoholicDrinks: Double?

    public init(date: Date, steps: Int? = nil, activeKcal: Int? = nil,
                basalKcal: Int? = nil, restingHR: Int? = nil, hrvMs: Double? = nil,
                respRate: Double? = nil, vo2max: Double? = nil, weightKg: Double? = nil,
                bodyFatPct: Double? = nil, leanKg: Double? = nil,
                exerciseMinutes: Double? = nil, standHours: Int? = nil,
                recoveryHRDrop: Int? = nil, alcoholicDrinks: Double? = nil) {
        self.date = date
        self.steps = steps
        self.activeKcal = activeKcal
        self.basalKcal = basalKcal
        self.restingHR = restingHR
        self.hrvMs = hrvMs
        self.respRate = respRate
        self.vo2max = vo2max
        self.weightKg = weightKg
        self.bodyFatPct = bodyFatPct
        self.leanKg = leanKg
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.recoveryHRDrop = recoveryHRDrop
        self.alcoholicDrinks = alcoholicDrinks
    }

    /// Ganztägige Watch-Daten erkennt die App am Grundumsatz. Siehe SPEC 4.8.
    public var hasFullDayWatchData: Bool { (basalKcal ?? 0) >= 1_400 }
}

public enum WorkoutKind: String, Equatable, Sendable, CaseIterable {
    case running, walking, cycling, strength, swimming, soccer, other
}

public struct WorkoutSample: Equatable, Sendable {
    public let id: UUID
    public let start: Date
    public let kind: WorkoutKind
    public let minutes: Double
    public let km: Double?
    public let avgHR: Int?
    public let maxHR: Int?
    public let wasUserEntered: Bool

    public init(id: UUID, start: Date, kind: WorkoutKind, minutes: Double,
                km: Double? = nil, avgHR: Int? = nil, maxHR: Int? = nil,
                wasUserEntered: Bool = false) {
        self.id = id
        self.start = start
        self.kind = kind
        self.minutes = minutes
        self.km = km
        self.avgHR = avgHR
        self.maxHR = maxHR
        self.wasUserEntered = wasUserEntered
    }
}

public struct NutritionEntry: Equatable, Sendable {
    public let time: Date
    public let name: String
    public let kcal: Int
    public let proteinG: Double
    public let carbsG: Double
    public let fatG: Double

    public init(time: Date, name: String, kcal: Int,
                proteinG: Double, carbsG: Double, fatG: Double) {
        self.time = time
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}
