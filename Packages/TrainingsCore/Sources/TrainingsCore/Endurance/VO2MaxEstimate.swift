import Foundation

/// Eigene VO₂max-Schätzung aus einer tatsächlich gelaufenen Leistung.
///
/// Ergänzt den Wert der Apple Watch, ersetzt ihn nicht. Die Watch schätzt nur
/// bei Aktivitäten draußen mit GPS und reagiert träge; diese Schätzung entsteht
/// aus jedem Lauf, dessen Distanz und Dauer bekannt sind.
///
/// Verfahren nach Daniels und Gilbert. Beide Werte sind Schätzungen, kein
/// Labortest — die Laufökonomie geht nicht ein, und bei Einsteigern fällt sie
/// stark ins Gewicht.
public enum VO2MaxEstimate {

    /// Unter dieser Laufdauer dominiert die anaerobe Leistung und die Formel
    /// überschätzt grob.
    public static let minimumMinutes: Double = 3

    /// - Parameters:
    ///   - km: gelaufene Distanz in Kilometern
    ///   - minutes: benötigte Zeit in Minuten
    /// - Returns: geschätzte VO₂max in ml/kg/min, oder `nil` bei unbrauchbarer Eingabe.
    public static func fromRun(km: Double, minutes: Double) -> Double? {
        guard km > 0, minutes >= minimumMinutes else { return nil }

        let metersPerMinute = km * 1_000 / minutes

        // Sauerstoffaufnahme bei dieser Geschwindigkeit
        let oxygenCost = -4.60
            + 0.182_258 * metersPerMinute
            + 0.000_104 * metersPerMinute * metersPerMinute

        // Anteil der VO₂max, den man über diese Dauer halten kann
        let fraction = 0.8
            + 0.189_439_3 * exp(-0.012_778 * minutes)
            + 0.298_955_8 * exp(-0.193_260_5 * minutes)

        guard fraction > 0 else { return nil }
        let vdot = oxygenCost / fraction
        guard vdot.isFinite, vdot > 0 else { return nil }
        return (vdot * 10).rounded() / 10
    }
}
