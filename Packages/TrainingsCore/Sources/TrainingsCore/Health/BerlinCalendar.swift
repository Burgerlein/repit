import Foundation

/// Alle Tagesgrenzen laufen über diesen Kalender. Niemals mit `+ 86400`
/// rechnen — am 28.03.2027 hat der Tag 23 Stunden.
public enum BerlinCalendar {

    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        c.locale = Locale(identifier: "de_DE")
        c.firstWeekday = 2
        return c
    }

    public static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func dayBounds(of date: Date) -> (start: Date, end: Date) {
        let start = startOfDay(date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    /// Obere Grenze für Abfragen, die den ganzen Tag einschließen sollen:
    /// die Mitternacht des Folgetags. Der Grenzzeitpunkt selbst gehört noch
    /// dazu, alles danach nicht mehr.
    public static func endOfDay(_ date: Date) -> Date {
        dayBounds(of: date).end
    }

    /// Beide Grenzen einschließlich.
    public static func days(from: Date, through: Date) -> [Date] {
        var out: [Date] = []
        var cursor = startOfDay(from)
        let last = startOfDay(through)
        while cursor <= last {
            out.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }
}
