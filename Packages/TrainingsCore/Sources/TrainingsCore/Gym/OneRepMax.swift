import Foundation

/// Geschätztes Einwiederholungsmaximum nach Epley. Schätzung, kein
/// Maximalversuch — und mit steigender Wiederholungszahl ungenauer.
public enum OneRepMax {

    /// Nur für positive Gewichte. Bei Unterstützung wäre das tatsächlich
    /// bewegte Gewicht vom Körpergewicht abhängig; eine Schätzung darauf
    /// wäre eine Schätzung auf einer Schätzung.
    public static func epley(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps > 0 else { return nil }
        // Eine Wiederholung ist das Maximum, gemessen statt geschätzt. Die
        // Formel ergäbe 1,033 · Gewicht und läge damit über einem tatsächlich
        // bewegten Gewicht — der einzige Fall, in dem die Schätzung
        // überprüfbar ist.
        guard reps > 1 else { return weight }
        let value = weight * (1 + Double(reps) / 30)
        return (value * 10).rounded() / 10
    }

    public static func best(in session: [CompletedSet]) -> Double? {
        session.compactMap { epley(weight: $0.weight, reps: $0.reps) }.max()
    }

    /// Kein Anstieg des geschätzten 1RM über vier Trainings. `sessions`
    /// neueste zuerst.
    public static func isPlateau(_ sessions: [[CompletedSet]]) -> Bool {
        let values = sessions.prefix(4).compactMap { best(in: $0) }
        guard values.count == 4 else { return false }
        // Ein Prozent Luft, damit Messrauschen kein Plateau verhindert.
        return values.first! <= values.last! * 1.01
    }
}
