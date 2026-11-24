import Foundation

/// Was mehrere Nächte zusammen sagen. Siehe `docs/SPEC.md` 4.6.
public struct SleepStats: Equatable, Sendable {

    /// Zahl der Nächte mit Schlaf, die eingegangen sind.
    public let nights: Int
    public let averageAsleepHours: Double

    /// Mittel der Einschlafzeiten in **Minuten seit 18 Uhr**, zirkulär
    /// gerechnet: jede Uhrzeit als Winkel auf dem 24-Stunden-Kreis.
    ///
    /// `nil` hat zwei Gründe. Der eine ist formal — `SleepSession.start` ist
    /// optional, auch wenn eine gezählte Nacht heute immer eine Startzeit hat.
    /// Der andere ist echt: Liegen die Zeiten gleichmäßig über den Kreis
    /// verteilt oder genau gegenüber, zeigt die Vektorsumme ins Nichts und es
    /// gibt **kein** Mittel. Eine erfundene Uhrzeit wäre schlechter als keine.
    public let averageBedtimeMinutes: Double?
    public let averageWakeMinutes: Double?

    /// Anteil je Phase an der Zeit im Bett, 0…1, über alle Nächte **gepoolt**:
    /// Summe der Minuten je Phase geteilt durch die Summe aller vier. Nicht
    /// das Mittel der nächtlichen Anteile — eine kurze Nacht wöge dort so
    /// schwer wie eine lange, und ein Zeitraum zeigt Zeit.
    ///
    /// Leer, wenn keine Nacht Phasendaten hat: Eine ältere Uhr liefert nur
    /// `unspecified`, und daraus ist kein Tiefschlafanteil zu gewinnen.
    public let shares: [SleepStage: Double]

    public init(nights: Int, averageAsleepHours: Double,
                averageBedtimeMinutes: Double?, averageWakeMinutes: Double?,
                shares: [SleepStage: Double]) {
        self.nights = nights
        self.averageAsleepHours = averageAsleepHours
        self.averageBedtimeMinutes = averageBedtimeMinutes
        self.averageWakeMinutes = averageWakeMinutes
        self.shares = shares
    }
}

public enum SleepStatistics {

    /// Die Phasen, die in die Anteile eingehen. `unspecified` fehlt mit
    /// Absicht: Es ist Schlaf ohne Phasenangabe und würde als eigener
    /// „Anteil" eine Messung vortäuschen, die nicht stattgefunden hat.
    private static let sharedStages: [SleepStage] = [.awake, .rem, .core, .deep]

    /// `nil`, wenn keine Nacht Schlaf enthält — eine Statistik über null
    /// Nächte ist keine Null, sondern keine Statistik.
    public static func over(_ nights: [SleepNight]) -> SleepStats? {
        let counted = nights.map(\.session).filter { $0.asleepMinutes > 0 }
        guard !counted.isEmpty else { return nil }

        let bedtimes = counted.compactMap { $0.start.map(EveningClock.minutesSinceEvening) }
        let wakes = counted.compactMap { $0.end.map(EveningClock.minutesSinceEvening) }

        // Nur Nächte, für die die Uhr überhaupt Phasen geliefert hat. Eine
        // Nacht aus `unspecified` plus Wachliegen gehört nicht dazu — sonst
        // zählte ihr Wachanteil mit, ihr Schlaf aber nicht, und die Anteile
        // kippten.
        let staged = counted.filter { session in
            [.rem, .core, .deep].contains { session.minutes($0) > 0 }
        }
        var minutes: [SleepStage: Double] = [:]
        for stage in sharedStages {
            let sum = staged.map { $0.minutes(stage) }.reduce(0, +)
            if sum > 0 { minutes[stage] = sum }
        }
        let total = minutes.values.reduce(0, +)

        return SleepStats(
            nights: counted.count,
            averageAsleepHours: counted.map(\.asleepHours).reduce(0, +) / Double(counted.count),
            averageBedtimeMinutes: mean(bedtimes),
            averageWakeMinutes: mean(wakes),
            shares: total > 0 ? minutes.mapValues { $0 / total } : [:])
    }

    /// Volle Umdrehung in Minuten — `EveningClock` liefert 0 bis unter 1440.
    private static let fullTurn = 1440.0

    /// Ab dieser Länge der Vektorsumme gilt ein Mittel als bestimmt.
    ///
    /// Nicht `== 0` prüfen: Bei drei gleichmäßig verteilten Zeiten kommt in
    /// `Double` nicht null heraus, sondern etwa 4e-16. Der kleinste echte Wert
    /// liegt dagegen in der Größenordnung 0,5 — zwischen beiden liegen fünfzehn
    /// Zehnerpotenzen, die Schwelle ist also unkritisch.
    private static let resultantFloor = 1e-9

    /// Zirkuläres Mittel von Uhrzeiten.
    ///
    /// Ein gewöhnlicher Durchschnitt taugt hier nicht: `EveningClock` rechnet
    /// 16:45 zu 1365 Minuten, und zusammen mit einer Nacht ab 22:00 (240)
    /// ergibt das linear 802 — halb neun am Morgen. Auf dem Kreis liegen die
    /// beiden dagegen nebeneinander, und das Mittel landet bei 19:22.
    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        var sine = 0.0, cosine = 0.0
        for value in values {
            let angle = 2 * .pi * value / fullTurn
            sine += Foundation.sin(angle)
            cosine += Foundation.cos(angle)
        }
        guard hypot(sine, cosine) >= resultantFloor else { return nil }
        let minutes = atan2(sine, cosine) * fullTurn / (2 * .pi)
        return minutes < 0 ? minutes + fullTurn : minutes
    }
}
