import Foundation

/// Umfänge kommen aus zwei Quellen: Die Importdatei gehört dem Dashboard, die
/// eingetippten Werte der App. Zusammengeführt wird erst beim Lesen, damit
/// keine der beiden Dateien zwei Besitzer bekommt.
public enum CircumferenceMerge {

    /// Tagweise und **maßweise** zusammengeführt: Steht ein Maß in beiden
    /// Quellen, gilt der eingetippte Wert. Maßweise und nicht eintragsweise,
    /// damit ein abends nachgetragenes Einzelmaß nicht den Rest des Tages
    /// löscht.
    public static func entries(imported: [CircumferenceEntry],
                               manual: [CircumferenceEntry]) -> [CircumferenceEntry] {
        var byDay: [Date: [Circumference: Double]] = [:]

        // Import zuerst, eingetippt danach: Die zweite Runde überschreibt je
        // Maß. Beide Quellen können mehrere Einträge desselben Tages führen —
        // der Import trägt die Uhrzeit des Exports, das Formular die des
        // Tippens.
        for entry in imported + manual {
            let day = BerlinCalendar.startOfDay(entry.date)
            byDay[day, default: [:]].merge(entry.values) { _, new in new }
        }

        return byDay
            // Ein leerer Tag ist keine Messung und gehört in keine Liste.
            .filter { !$0.value.isEmpty }
            .map { CircumferenceEntry(date: $0.key, values: $0.value) }
            .sorted { $0.date < $1.date }
    }
}
