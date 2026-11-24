import Foundation

/// Trägt man iPhone und Watch, zählen beide. Es gilt der höhere Wert,
/// nicht die Summe. Siehe SPEC 4.6.
public enum StepMerge {
    /// `perSource` ist je eine Tageszuordnung pro Datenquelle.
    public static func daily(perSource: [[Date: Int]]) -> [Date: Int] {
        perSource.reduce(into: [:]) { merged, source in
            for (day, value) in source {
                merged[day] = max(merged[day] ?? 0, value)
            }
        }
    }
}
