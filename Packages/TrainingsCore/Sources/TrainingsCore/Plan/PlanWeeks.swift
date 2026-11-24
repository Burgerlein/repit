import Foundation

/// In welche Planwoche ein Datum fällt. Gerechnet wird in ganzen Tagen ab
/// Tagesbeginn, nie in Sekunden — sonst verschöbe eine Zeitumstellung die
/// Wochengrenze um einen Tag.
public enum PlanWeeks {

    /// Die 1-basierte Nummer der Planwoche, in die `date` fällt.
    ///
    /// `nil` vor dem Planbeginn, ab dem ersten Tag nach der letzten Woche und
    /// bei `weeks <= 0`. Die Uhrzeit von `date` und `start` zählt nicht; über
    /// den Tag entscheidet die Zeitzone des übergebenen Kalenders.
    public static func number(of date: Date, start: Date, weeks: Int,
                              calendar: Calendar = BerlinCalendar.calendar) -> Int? {
        guard weeks > 0 else { return nil }
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return nil }
        guard days >= 0, days < weeks * 7 else { return nil }
        return days / 7 + 1
    }

    /// Der 1-basierte Tag im Plan. Tag 1 ist der Starttag selbst.
    ///
    /// Dieselben Grenzen wie `number`: `nil` vor dem Start, ab dem ersten Tag
    /// nach der letzten Woche und bei `weeks <= 0`. Gerechnet wird wie dort in
    /// ganzen Tagen ab Tagesbeginn, damit eine Zeitumstellung nichts
    /// verschiebt.
    public static func dayOfPlan(on date: Date, start: Date, weeks: Int,
                                 calendar: Calendar = BerlinCalendar.calendar) -> Int? {
        guard weeks > 0 else { return nil }
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return nil }
        guard days >= 0, days < weeks * 7 else { return nil }
        return days + 1
    }
}
