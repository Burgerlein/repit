import Foundation
import Testing
@testable import TrainingsCore

/// Importierte und eingetippte Umfänge liegen in zwei Quellen: Die Importdatei
/// gehört dem Dashboard, die eingetippten Werte der App. Zusammengeführt wird
/// erst beim Lesen — alle Zahlen hier sind erfunden.
@Suite("Umfänge aus zwei Quellen")
struct CircumferenceMergeTests {

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      hour: Int = 0, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute)
        return BerlinCalendar.calendar.date(from: components) ?? .distantPast
    }

    @Test("Ohne Quellen kommt nichts heraus")
    func emptyStaysEmpty() {
        #expect(CircumferenceMerge.entries(imported: [], manual: []).isEmpty)
    }

    @Test("Ohne eingetippte Werte bleibt der Import stehen")
    func keepsImportedAlone() {
        let imported = [CircumferenceEntry(date: date(2026, 10, 4, hour: 9),
                                           values: [.waist: 79.0, .neck: 37.5])]
        let merged = CircumferenceMerge.entries(imported: imported, manual: [])
        #expect(merged.count == 1)
        #expect(merged.first?.values == [.waist: 79.0, .neck: 37.5])
        #expect(merged.first?.date == BerlinCalendar.startOfDay(date(2026, 10, 4)))
    }

    @Test("Ohne Import bleiben die eingetippten Werte stehen")
    func keepsManualAlone() {
        let manual = [CircumferenceEntry(date: date(2026, 10, 4, hour: 21),
                                         values: [.chest: 96.5])]
        let merged = CircumferenceMerge.entries(imported: [], manual: manual)
        #expect(merged.count == 1)
        #expect(merged.first?.values == [.chest: 96.5])
    }

    @Test("Am selben Tag gewinnt der eingetippte Wert je Maß")
    func manualWinsPerMeasure() {
        // Maßweise und nicht eintragsweise: Wer abends nur die Taille
        // nachträgt, löscht damit nicht Hals und Brust vom Morgen.
        let imported = [CircumferenceEntry(date: date(2026, 10, 4, hour: 8),
                                           values: [.waist: 79.0, .neck: 37.5,
                                                    .chest: 96.5])]
        let manual = [CircumferenceEntry(date: date(2026, 10, 4, hour: 20),
                                         values: [.waist: 78.2])]
        let merged = CircumferenceMerge.entries(imported: imported, manual: manual)
        #expect(merged.count == 1)
        #expect(merged.first?.values == [.waist: 78.2, .neck: 37.5, .chest: 96.5])
    }

    @Test("Verschiedene Uhrzeiten desselben Tages ergeben einen Eintrag")
    func sameDayDifferentTimesCollapse() {
        // Der Import trägt die Uhrzeit des Exports, das Formular die des
        // Tippens. Ohne `startOfDay` stünden zwei Zeilen für denselben Tag.
        let imported = [CircumferenceEntry(date: date(2026, 10, 4, hour: 7, minute: 30),
                                           values: [.waist: 79.0]),
                        CircumferenceEntry(date: date(2026, 10, 4, hour: 19, minute: 45),
                                           values: [.neck: 37.5])]
        let manual = [CircumferenceEntry(date: date(2026, 10, 4, hour: 22, minute: 10),
                                         values: [.chest: 96.5])]
        let merged = CircumferenceMerge.entries(imported: imported, manual: manual)
        #expect(merged.count == 1)
        #expect(merged.first?.date == BerlinCalendar.startOfDay(date(2026, 10, 4)))
        #expect(merged.first?.values == [.waist: 79.0, .neck: 37.5, .chest: 96.5])
    }

    @Test("Das Ergebnis steht aufsteigend nach Datum")
    func resultIsAscending() {
        let imported = [CircumferenceEntry(date: date(2026, 10, 11), values: [.waist: 78.0]),
                        CircumferenceEntry(date: date(2026, 9, 6), values: [.waist: 80.0])]
        let manual = [CircumferenceEntry(date: date(2026, 10, 4), values: [.waist: 79.0]),
                      CircumferenceEntry(date: date(2026, 8, 2), values: [.waist: 81.0])]
        let merged = CircumferenceMerge.entries(imported: imported, manual: manual)
        #expect(merged.count == 4)
        #expect(merged.map(\.date) == [date(2026, 8, 2), date(2026, 9, 6),
                                       date(2026, 10, 4), date(2026, 10, 11)]
            .map(BerlinCalendar.startOfDay))
        #expect(merged.map { $0.values[.waist] } == [81.0, 80.0, 79.0, 78.0])
    }

    @Test("Ein Eintrag ohne Werte taucht nicht auf")
    func entryWithoutValuesIsDropped() {
        // Ein leerer Tag ist keine Messung. In der Liste „Alle Messungen"
        // stünde sonst eine Zeile mit null Werten.
        let imported = [CircumferenceEntry(date: date(2026, 10, 4), values: [:])]
        let manual = [CircumferenceEntry(date: date(2026, 10, 11), values: [:]),
                      CircumferenceEntry(date: date(2026, 10, 12), values: [.waist: 79.0])]
        let merged = CircumferenceMerge.entries(imported: imported, manual: manual)
        #expect(merged.count == 1)
        #expect(merged.first?.date == BerlinCalendar.startOfDay(date(2026, 10, 12)))
    }
}
