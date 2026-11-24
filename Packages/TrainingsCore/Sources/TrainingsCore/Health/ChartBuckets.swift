import Foundation

public enum ChartRange: String, CaseIterable, Sendable {
    case day, week, month, halfYear, year
}

public struct ChartSample: Equatable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct ChartPoint: Equatable, Sendable, Identifiable {
    public var id: Date { start }
    public let start: Date
    public let value: Double
    /// Wie viele gemessene Tage hinter dem Punkt stecken.
    public let dayCount: Int

    public init(start: Date, value: Double, dayCount: Int) {
        self.start = start
        self.value = value
        self.dayCount = dayCount
    }
}

public enum SnapDirection: Sendable { case nearest, forward, backward }

/// Der gemeinsame Unterbau aller Zeitdiagramme: Balken bilden, Rastgrenzen
/// finden, Fensterbreite nennen. Jede Grenze läuft über `BerlinCalendar` —
/// am 29.03.2026 hat der Tag 23 Stunden, am 25.10.2026 25.
public enum ChartBuckets {

    public static func points(_ samples: [ChartSample], for range: ChartRange) -> [ChartPoint] {
        let sorted = samples.sorted { $0.date < $1.date }
        switch range {
        case .day, .week, .month:
            // Die Schirme liefern bereits Stunden- bzw. Tageswerte; hier wird
            // nichts verdichtet, auch nicht bei mehreren Werten je Tag.
            return sorted.map { ChartPoint(start: $0.date, value: $0.value, dayCount: 1) }
        case .halfYear, .year:
            return monthlyAverages(sorted)
        }
    }

    public static func snap(_ date: Date, for range: ChartRange,
                            _ direction: SnapDirection) -> Date {
        guard let interval = BerlinCalendar.calendar.dateInterval(of: component(for: range),
                                                                  for: date) else { return date }
        let earlier = interval.start
        // Ein Zeitpunkt, der schon auf einer Grenze liegt, ist in jeder
        // Richtung seine eigene Antwort.
        let later = date == earlier ? date : interval.end
        switch direction {
        case .backward:
            return earlier
        case .forward:
            return later
        case .nearest:
            // Abstand in verstrichenen Sekunden, nicht in Wanduhrzeit. Bei
            // Gleichstand gewinnt die frühere Grenze.
            return date.timeIntervalSince(earlier) <= later.timeIntervalSince(date) ? earlier : later
        }
    }

    /// Fensterbreite für `.chartXVisibleDomain(length:)`. Über Monatslängen
    /// und Sommerzeitgrenzen hinweg nur angenähert — die Größe bestimmt die
    /// Breite des Fensters, nicht die Zuordnung der Werte.
    public static func visibleLength(for range: ChartRange) -> TimeInterval {
        let day: TimeInterval = 24 * 60 * 60
        switch range {
        case .day: return day
        case .week: return 7 * day
        case .month: return 31 * day
        case .halfYear: return 183 * day
        case .year: return 366 * day
        }
    }

    /// Der Kalenderabschnitt, in dem `date` liegt. `start` gehört dazu, `end`
    /// ist die Grenze zum nächsten Abschnitt: Ein Zeitpunkt, der genau auf
    /// einer Grenze liegt, beginnt seinen eigenen Abschnitt und beendet nicht
    /// den vorigen — sonst blättert ein Diagramm an der Kante eine Seite zu
    /// weit zurück.
    ///
    /// Alle Grenzen kommen aus `BerlinCalendar`, nie aus einer Rechnung mit
    /// `+ 86400`: Am 29.03.2026 hat der Tag 23 Stunden, am 25.10.2026 25, und
    /// die Woche davor entsprechend 167 statt 169. Nur der Kalender kennt die
    /// Umstellung; in Sekunden gerechnet schneidet die Grenze mitten in den
    /// Montag.
    public static func window(containing date: Date, for range: ChartRange) -> DateInterval {
        let calendar = BerlinCalendar.calendar
        guard range != .halfYear else { return halfYearWindow(containing: date, calendar) }
        guard let interval = calendar.dateInterval(of: component(for: range), for: date) else {
            // Kann der Kalender den Abschnitt nicht nennen, ist ein leerer
            // Abschnitt auf dem Datum ehrlicher als eine geratene Grenze.
            return DateInterval(start: date, end: date)
        }
        return interval
    }

    /// Die Startzeitpunkte aller Abschnitte, von dem der `first` enthält bis
    /// zu dem der `last` enthält — aufsteigend und lückenlos.
    ///
    /// **Verglichen werden die Abschnitte, nicht die Zeitpunkte.** Liegen
    /// `first` und `last` im selben Abschnitt, kommt genau dieser eine zurück,
    /// gleich in welcher Reihenfolge sie stehen. Leer wird das Ergebnis erst,
    /// wenn der Abschnitt von `last` vor dem von `first` beginnt. So bekommt
    /// ein Diagramm, dessen Messwerte alle in eine Woche fallen, eine Seite
    /// statt keine.
    public static func windows(from first: Date, to last: Date, for range: ChartRange) -> [Date] {
        let calendar = BerlinCalendar.calendar
        let firstStart = window(containing: first, for: range).start
        let lastStart = window(containing: last, for: range).start
        guard firstStart <= lastStart else { return [] }

        // Weitergezählt wird in Kalendereinheiten, nicht in Sekunden: Ein
        // Schritt von einem Abschnittsanfang aus landet wieder auf 00:00
        // Ortszeit, auch über eine Zeitumstellung oder die Jahresgrenze hinweg.
        let step = step(for: range)
        var starts: [Date] = []
        var cursor = firstStart
        while cursor <= lastStart {
            starts.append(cursor)
            guard let next = calendar.date(byAdding: step.component,
                                           value: step.value,
                                           to: cursor),
                  next > cursor else { break }
            cursor = next
        }
        return starts
    }

    /// Das Halbjahr ist der einzige Abschnitt, den `dateInterval(of:for:)`
    /// nicht kennt — es gibt keine Kalendereinheit dafür. Also vom
    /// Jahresanfang aus gerechnet, um null oder sechs Monate versetzt; der
    /// Monat des Datums sagt, welche Hälfte gemeint ist.
    private static func halfYearWindow(containing date: Date, _ calendar: Calendar) -> DateInterval {
        guard let yearStart = calendar.dateInterval(of: .year, for: date)?.start else {
            return DateInterval(start: date, end: date)
        }
        let offset = calendar.component(.month, from: date) <= 6 ? 0 : 6
        guard let start = calendar.date(byAdding: .month, value: offset, to: yearStart),
              let end = calendar.date(byAdding: .month, value: 6, to: start) else {
            return DateInterval(start: yearStart, end: yearStart)
        }
        return DateInterval(start: start, end: end)
    }

    /// Ein Schritt von einem Abschnitt zum nächsten. Das Halbjahr zählt in
    /// sechs Monaten, weil es keine eigene Einheit hat.
    private static func step(for range: ChartRange) -> (component: Calendar.Component, value: Int) {
        switch range {
        case .day: return (.day, 1)
        case .week: return (.weekOfYear, 1)
        case .month: return (.month, 1)
        case .halfYear: return (.month, 6)
        case .year: return (.year, 1)
        }
    }

    /// `.halfYear` rastet auf den Monatsanfang: sechs Monate sind das
    /// Fenster, der Monat die Grenze.
    private static func component(for range: ChartRange) -> Calendar.Component {
        switch range {
        case .day: return .day
        case .week: return .weekOfYear
        case .month, .halfYear: return .month
        case .year: return .year
        }
    }

    private static func monthlyAverages(_ sorted: [ChartSample]) -> [ChartPoint] {
        let calendar = BerlinCalendar.calendar
        var order: [Date] = []
        var byMonth: [Date: (sum: Double, count: Int, days: Set<Date>)] = [:]

        for sample in sorted {
            guard let month = calendar.dateInterval(of: .month, for: sample.date)?.start else { continue }
            let day = calendar.startOfDay(for: sample.date)
            if var entry = byMonth[month] {
                entry.sum += sample.value
                entry.count += 1
                entry.days.insert(day)
                byMonth[month] = entry
            } else {
                order.append(month)
                byMonth[month] = (sample.value, 1, [day])
            }
        }

        // Das Mittel läuft über die Messwerte, `dayCount` über die
        // verschiedenen Kalendertage. Monate ohne Messung fehlen — eine Lücke
        // bleibt eine Lücke.
        return order.map { month in
            let entry = byMonth[month]!
            return ChartPoint(start: month,
                              value: entry.sum / Double(entry.count),
                              dayCount: entry.days.count)
        }
    }
}
