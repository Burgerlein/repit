import Foundation
import Testing
@testable import TrainingsCore

@Suite("Tagesgrenzen in Europe/Berlin")
struct BerlinCalendarTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    // Review Focus 2
    @Test("Der Tag der Zeitumstellung hat 23 Stunden")
    func dstDayIsShort() {
        let inside = date("2027-03-28T12:00:00+02:00")
        let bounds = BerlinCalendar.dayBounds(of: inside)
        let hours = bounds.end.timeIntervalSince(bounds.start) / 3600
        #expect(hours == 23)
    }

    @Test("Ein gewöhnlicher Tag hat 24 Stunden")
    func normalDayIsFull() {
        let inside = date("2026-10-12T12:00:00+02:00")
        let bounds = BerlinCalendar.dayBounds(of: inside)
        #expect(bounds.end.timeIntervalSince(bounds.start) / 3600 == 24)
    }

    @Test("Über die Zeitumstellung hinweg wird kein Tag verschluckt")
    func dayCountSurvivesDst() {
        let from = date("2027-03-26T12:00:00+01:00")
        let through = date("2027-03-30T12:00:00+02:00")
        #expect(BerlinCalendar.days(from: from, through: through).count == 5)
    }
}
