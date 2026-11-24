import Foundation
import Testing
@testable import TrainingsCore

@Suite("Trainingsminuten der Woche")
struct TrainingLoadTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func day(_ iso: String, _ minutes: Double?) -> DailyMetrics {
        DailyMetrics(date: date(iso), exerciseMinutes: minutes)
    }

    /// Montag, 12.10.2026 bis Sonntag, 18.10.2026 — eine Woche ohne Zeitumstellung.
    private var week: [DailyMetrics] {
        [day("2026-10-12T07:00:00+02:00", 30),
         day("2026-10-13T07:00:00+02:00", 0),
         day("2026-10-14T07:00:00+02:00", 45),
         day("2026-10-15T07:00:00+02:00", nil),
         day("2026-10-16T07:00:00+02:00", 60),
         day("2026-10-17T07:00:00+02:00", 90),
         day("2026-10-18T07:00:00+02:00", 15)]
    }

    // MARK: - Wochengrenzen

    @Test("Ein Montag beginnt seine eigene Woche")
    func boundsForAMonday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-12T09:00:00+02:00"))
        #expect(b.start == date("2026-10-12T00:00:00+02:00"))
        #expect(b.end == date("2026-10-19T00:00:00+02:00"))
    }

    @Test("Montag null Uhr gehört schon zur neuen Woche")
    func boundsAtMidnightOnMonday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-12T00:00:00+02:00"))
        #expect(b.start == date("2026-10-12T00:00:00+02:00"))
        #expect(b.end == date("2026-10-19T00:00:00+02:00"))
    }

    @Test("Ein Mittwoch liegt mitten in derselben Woche")
    func boundsForAWednesday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-14T12:00:00+02:00"))
        #expect(b.start == date("2026-10-12T00:00:00+02:00"))
        #expect(b.end == date("2026-10-19T00:00:00+02:00"))
    }

    // Review Focus: die Woche endet am Sonntag, sie beginnt nicht mit ihm.
    @Test("Ein Sonntag gehört noch zur Woche davor")
    func boundsForASunday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-18T23:30:00+02:00"))
        #expect(b.start == date("2026-10-12T00:00:00+02:00"))
        #expect(b.end == date("2026-10-19T00:00:00+02:00"))
    }

    @Test("Die letzte Sekunde des Sonntags gehört noch zur Woche")
    func boundsAtTheLastSecondOfSunday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-18T23:59:59+02:00"))
        #expect(b.start == date("2026-10-12T00:00:00+02:00"))
    }

    @Test("Der folgende Montag beginnt die nächste Woche")
    func boundsForTheNextMonday() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-19T00:00:00+02:00"))
        #expect(b.start == date("2026-10-19T00:00:00+02:00"))
        #expect(b.end == date("2026-10-26T00:00:00+01:00"))
    }

    @Test("Eine gewöhnliche Woche dauert sieben mal vierundzwanzig Stunden")
    func normalWeekLength() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-14T12:00:00+02:00"))
        #expect(b.end.timeIntervalSince(b.start) == 604_800)
    }

    // Review Focus: niemals mit sieben mal 86400 rechnen.
    @Test("Die Woche der Zeitumstellung hat trotzdem sieben Tage")
    func dstWeekStillHasSevenDays() {
        let b = TrainingLoad.weekBounds(containing: date("2026-10-25T12:00:00+01:00"))
        #expect(b.start == date("2026-10-19T00:00:00+02:00"))
        #expect(b.end == date("2026-10-26T00:00:00+01:00"))
        #expect(b.end.timeIntervalSince(b.start) == 608_400)
        #expect(BerlinCalendar.days(from: b.start, through: date("2026-10-25T12:00:00+01:00")).count == 7)
    }

    @Test("In der doppelten Stunde im Herbst gilt dieselbe Woche")
    func dstAmbiguousHourStaysInTheSameWeek() {
        let early = TrainingLoad.weekBounds(containing: date("2026-10-25T02:30:00+02:00"))
        let late = TrainingLoad.weekBounds(containing: date("2026-10-25T02:30:00+01:00"))
        #expect(early.start == date("2026-10-19T00:00:00+02:00"))
        #expect(late.start == date("2026-10-19T00:00:00+02:00"))
        #expect(early.end == late.end)
    }

    @Test("Die Woche der Umstellung im Frühjahr hat ebenfalls sieben Tage")
    func springForwardWeekStillHasSevenDays() {
        let b = TrainingLoad.weekBounds(containing: date("2027-03-28T12:00:00+02:00"))
        #expect(b.start == date("2027-03-22T00:00:00+01:00"))
        #expect(b.end == date("2027-03-29T00:00:00+02:00"))
        #expect(b.end.timeIntervalSince(b.start) == 601_200)
    }

    // MARK: - Summe

    @Test("Ohne Tage gibt es keine Minuten")
    func emptyInput() {
        #expect(TrainingLoad.weekMinutes(days: [], containing: date("2026-10-14T12:00:00+02:00")) == 0)
    }

    @Test("Die Minuten der Woche werden summiert")
    func sumOfTheWeek() {
        #expect(TrainingLoad.weekMinutes(days: week,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 240)
    }

    @Test("Der Montag liefert dieselbe Summe wie der Mittwoch")
    func mondayMatchesWednesday() {
        #expect(TrainingLoad.weekMinutes(days: week,
                                         containing: date("2026-10-12T06:00:00+02:00")) == 240)
    }

    @Test("Der Sonntag liefert dieselbe Summe wie der Montag")
    func sundayMatchesMonday() {
        #expect(TrainingLoad.weekMinutes(days: week,
                                         containing: date("2026-10-18T22:00:00+02:00")) == 240)
    }

    @Test("Tage ohne Wert zählen null")
    func missingMinutesCountAsZero() {
        let days = [day("2026-10-12T07:00:00+02:00", nil),
                    day("2026-10-13T07:00:00+02:00", nil),
                    day("2026-10-14T07:00:00+02:00", 20)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 20)
    }

    @Test("Eine Woche ganz ohne Werte ergibt null")
    func weekWithoutAnyMinutes() {
        let days = [day("2026-10-12T07:00:00+02:00", nil),
                    day("2026-10-15T07:00:00+02:00", nil)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 0)
    }

    @Test("Halbe Minuten werden mitgerechnet")
    func fractionalMinutes() {
        let days = [day("2026-10-12T07:00:00+02:00", 42.5),
                    day("2026-10-14T07:00:00+02:00", 7.25)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 49.75)
    }

    // MARK: - Tage außerhalb der Woche

    @Test("Der Sonntag davor zählt nicht mit")
    func theSundayBeforeDoesNotCount() {
        let days = [day("2026-10-11T23:59:59+02:00", 99),
                    day("2026-10-12T07:00:00+02:00", 30)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 30)
    }

    @Test("Der folgende Montag zählt nicht mit")
    func theNextMondayDoesNotCount() {
        let days = [day("2026-10-18T07:00:00+02:00", 30),
                    day("2026-10-19T00:00:00+02:00", 99)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 30)
    }

    // Review Focus: der Beginn gehört dazu, das Ende nicht mehr.
    @Test("Genau an den Grenzen zählt nur der Beginn der Woche")
    func exactlyAtTheBounds() {
        let days = [day("2026-10-11T23:59:59+02:00", 99),
                    day("2026-10-12T00:00:00+02:00", 10),
                    day("2026-10-18T23:59:59+02:00", 20),
                    day("2026-10-19T00:00:00+02:00", 99)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 30)
    }

    @Test("Weit entfernte Wochen zählen nicht mit")
    func distantWeeksDoNotCount() {
        let days = week + [day("2026-09-14T07:00:00+02:00", 500),
                           day("2026-11-16T07:00:00+01:00", 500)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-14T12:00:00+02:00")) == 240)
    }

    @Test("Eine andere Woche liefert ihre eigene Summe")
    func anotherWeekHasItsOwnSum() {
        let days = week + [day("2026-10-19T07:00:00+02:00", 11),
                           day("2026-10-20T07:00:00+02:00", 22)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-20T12:00:00+02:00")) == 33)
    }

    // MARK: - Woche der Zeitumstellung

    @Test("Die Woche über die Zeitumstellung summiert alle sieben Tage")
    func dstWeekSumsSevenDays() {
        let days = [day("2026-10-19T07:00:00+02:00", 30),
                    day("2026-10-20T07:00:00+02:00", 30),
                    day("2026-10-21T07:00:00+02:00", 30),
                    day("2026-10-22T07:00:00+02:00", 30),
                    day("2026-10-23T07:00:00+02:00", 30),
                    day("2026-10-24T07:00:00+02:00", 30),
                    day("2026-10-25T07:00:00+01:00", 30),
                    day("2026-10-26T07:00:00+01:00", 99)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-21T12:00:00+02:00")) == 210)
    }

    @Test("Auch vom Sonntag der Zeitumstellung aus gesehen sind es sieben Tage")
    func dstWeekSeenFromItsSunday() {
        let days = [day("2026-10-19T07:00:00+02:00", 30),
                    day("2026-10-20T07:00:00+02:00", 30),
                    day("2026-10-21T07:00:00+02:00", 30),
                    day("2026-10-22T07:00:00+02:00", 30),
                    day("2026-10-23T07:00:00+02:00", 30),
                    day("2026-10-24T07:00:00+02:00", 30),
                    day("2026-10-25T07:00:00+01:00", 30),
                    day("2026-10-26T07:00:00+01:00", 99)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-25T20:00:00+01:00")) == 210)
    }

    @Test("Ein Tag in der doppelten Stunde zählt zur Woche davor")
    func dayInTheAmbiguousHourCounts() {
        let days = [day("2026-10-25T02:30:00+02:00", 40),
                    day("2026-10-25T02:30:00+01:00", 20)]
        #expect(TrainingLoad.weekMinutes(days: days,
                                         containing: date("2026-10-21T12:00:00+02:00")) == 60)
    }
}
