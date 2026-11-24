import Foundation

/// Ein getauschtes Tagespaar einer Woche. Welche Tage es gibt und in welcher
/// Reihenfolge sie stehen, weiß der Kern nicht — `first` und `second` sind
/// Beschriftungen, die er nur vergleicht.
public struct PlanSwap: Codable, Equatable, Sendable {
    public let week: Int
    public let first: String
    public let second: String

    public init(week: Int, first: String, second: String) {
        self.week = week
        self.first = first
        self.second = second
    }
}

/// Wendet Tagestausche auf eine Woche an. Reine Rechnung: Tage rein, Tage raus.
public enum PlanSwaps {

    /// Die Tausche der gefragten Woche, der Reihe nach auf `days` angewandt.
    ///
    /// Jeder Tausch ist eine Abbildung je Element: `first` wird zu `second`,
    /// `second` zu `first`, alles andere bleibt. Dass nacheinander statt
    /// gleichzeitig abgebildet wird, ist Absicht — zwei Tausche mit einem
    /// gemeinsamen Tag sollen aufeinander aufbauen.
    ///
    /// Die Reihenfolge von `days` bleibt erhalten; sortiert wird nicht. Steht
    /// nur einer der beiden Tage in `days`, zieht die Einheit auf den anderen
    /// um. Ob dabei zwei Einheiten auf demselben Tag landen, entscheidet der
    /// Kern nicht.
    public static func apply(_ swaps: [PlanSwap], week: Int, to days: [String]) -> [String] {
        swaps.reduce(days) { current, swap in
            guard swap.week == week else { return current }
            return current.map { day in
                switch day {
                case swap.first: swap.second
                case swap.second: swap.first
                default: day
                }
            }
        }
    }
}

/// Ein getauschtes Tagespaar auf Wochentagen. 1 ist Sonntag, 2 Montag — wie im
/// gregorianischen Kalender. Der Kern prüft die Zahlen nicht, er vergleicht sie
/// nur; was außerhalb von 1…7 liegt, trifft schlicht keinen geplanten Tag.
public struct WeekdaySwap: Equatable, Sendable {
    public let first: Int
    public let second: Int

    public init(first: Int, second: Int) {
        self.first = first
        self.second = second
    }
}

extension PlanSwaps {

    /// Die Tausche der Reihe nach auf die Wochentage von `planned` angewandt.
    ///
    /// Dieselbe Rechnung wie bei den Tagesmarken, nur auf Zahlen: Jeder Tausch
    /// ist eine Abbildung je Eintrag — `first` wird zu `second`, `second` zu
    /// `first`, alles andere bleibt. Nacheinander statt gleichzeitig, damit
    /// zwei Tausche mit einem gemeinsamen Tag aufeinander aufbauen.
    ///
    /// Die Reihenfolge von `planned` bleibt erhalten; sortiert wird nicht. Das
    /// `workout` ändert sich nie, nur der Wochentag. Ist nur einer der beiden
    /// Tage belegt, zieht die Einheit auf den anderen um; ob dabei zwei
    /// Einheiten auf demselben Tag landen, entscheidet der Kern nicht.
    public static func apply(_ swaps: [WeekdaySwap], to planned: [PlannedGym]) -> [PlannedGym] {
        swaps.reduce(planned) { current, swap in
            current.map { entry in
                switch entry.weekday {
                case swap.first:
                    PlannedGym(workout: entry.workout, weekday: swap.second)
                case swap.second:
                    PlannedGym(workout: entry.workout, weekday: swap.first)
                default:
                    entry
                }
            }
        }
    }
}
