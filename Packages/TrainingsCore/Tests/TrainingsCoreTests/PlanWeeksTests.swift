import Foundation
import Testing
@testable import TrainingsCore

/// Welche Planwoche ein Datum trifft. Gerechnet wird in ganzen Tagen ab
/// Tagesbeginn — die Uhrzeit darf nie etwas verschieben.
@Suite("Planwoche eines Datums")
struct PlanWeeksTests {

    private let cal = BerlinCalendar.calendar

    private func date(_ y: Int, _ m: Int, _ d: Int,
                      _ h: Int = 9, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d,
                                      hour: h, minute: min))!
    }

    /// Montag, 5.10.2026. Vier Wochen reichen bis Sonntag, 1.11.2026.
    private var start: Date { date(2026, 10, 5) }

    private func nummer(_ d: Date, weeks: Int = 4) -> Int? {
        PlanWeeks.number(of: d, start: start, weeks: weeks)
    }

    // MARK: - Die ersten Tage

    @Test("Der Starttag selbst ist Woche 1")
    func startDayIsWeekOne() {
        #expect(nummer(date(2026, 10, 5)) == 1)
    }

    @Test("Sechs Tage nach dem Start ist es noch Woche 1")
    func sixthDayIsStillWeekOne() {
        #expect(nummer(date(2026, 10, 11)) == 1)
    }

    @Test("Sieben Tage nach dem Start beginnt Woche 2")
    func seventhDayIsWeekTwo() {
        #expect(nummer(date(2026, 10, 12)) == 2)
    }

    @Test("Jede Woche umfasst genau sieben Tage")
    func everyWeekSpansSevenDays() {
        #expect(nummer(date(2026, 10, 18)) == 2)   // Tag 13
        #expect(nummer(date(2026, 10, 19)) == 3)   // Tag 14
        #expect(nummer(date(2026, 10, 25)) == 3)   // Tag 20
        #expect(nummer(date(2026, 10, 26)) == 4)   // Tag 21
    }

    // MARK: - Vor dem Planbeginn

    @Test("Der Tag vor dem Start liegt außerhalb des Plans")
    func dayBeforeStartIsNil() {
        #expect(nummer(date(2026, 10, 4)) == nil)
    }

    @Test("Auch der späte Abend vor dem Start zählt noch nicht")
    func lateEveningBeforeStartIsNil() {
        #expect(nummer(date(2026, 10, 4, 23, 59)) == nil)
    }

    @Test("Ein Datum weit vor dem Start liegt außerhalb des Plans")
    func longBeforeStartIsNil() {
        #expect(nummer(date(2026, 1, 1)) == nil)
    }

    // MARK: - Nach der letzten Woche

    @Test("Der letzte Tag der letzten Woche gehört noch dazu")
    func lastDayOfLastWeekIsCounted() {
        // Tag 27 nach dem Start: Sonntag, 1.11.2026.
        #expect(nummer(date(2026, 11, 1)) == 4)
    }

    @Test("Der erste Tag nach der letzten Woche liegt außerhalb")
    func firstDayAfterTheLastWeekIsNil() {
        #expect(nummer(date(2026, 11, 2)) == nil)
        #expect(nummer(date(2026, 11, 2, 0, 1)) == nil)
    }

    @Test("Ein Plan über eine einzige Woche endet nach sieben Tagen")
    func singleWeekPlanEndsAfterSevenDays() {
        #expect(nummer(date(2026, 10, 5), weeks: 1) == 1)
        #expect(nummer(date(2026, 10, 11), weeks: 1) == 1)
        #expect(nummer(date(2026, 10, 12), weeks: 1) == nil)
    }

    @Test("Auch ein langer Plan hat seine Grenze am richtigen Tag")
    func longPlanEndsOnTheRightDay() {
        // 20 Wochen ab Mo 5.10.2026: Tag 139 ist Sonntag, 21.2.2027.
        #expect(nummer(date(2027, 2, 21), weeks: 20) == 20)
        #expect(nummer(date(2027, 2, 22), weeks: 20) == nil)
    }

    // MARK: - Keine Wochen

    @Test("Ein Plan ohne Wochen trifft kein Datum")
    func zeroWeeksIsNil() {
        #expect(nummer(date(2026, 10, 5), weeks: 0) == nil)
        #expect(nummer(date(2026, 10, 12), weeks: 0) == nil)
    }

    @Test("Eine negative Wochenzahl trifft ebenfalls kein Datum")
    func negativeWeeksIsNil() {
        #expect(nummer(date(2026, 10, 5), weeks: -3) == nil)
    }

    // MARK: - Die Uhrzeit zählt nicht

    @Test("Später Abend und früher Morgen desselben Tages ergeben dieselbe Woche")
    func timeOfDayDoesNotMatter() {
        let frueh = date(2026, 10, 12, 0, 1)
        let spaet = date(2026, 10, 12, 23, 59)
        #expect(nummer(frueh) == 2)
        #expect(nummer(spaet) == 2)
        #expect(nummer(frueh) == nummer(spaet))
    }

    @Test("Auch am letzten Tag der Woche zählt die Uhrzeit nicht")
    func timeOfDayDoesNotMatterAtTheWeekEnd() {
        #expect(nummer(date(2026, 10, 11, 0, 1)) == 1)
        #expect(nummer(date(2026, 10, 11, 23, 59)) == 1)
    }

    @Test("Die Uhrzeit des Planbeginns verschiebt nichts")
    func timeOfDayOfStartDoesNotMatter() {
        let frueherStart = date(2026, 10, 5, 0, 30)
        let spaeterStart = date(2026, 10, 5, 23, 30)
        let tag7 = date(2026, 10, 12, 8)
        #expect(PlanWeeks.number(of: tag7, start: frueherStart, weeks: 4) == 2)
        #expect(PlanWeeks.number(of: tag7, start: spaeterStart, weeks: 4) == 2)
        // Der Starttag bleibt Woche 1, egal wann am Tag der Plan beginnt.
        #expect(PlanWeeks.number(of: date(2026, 10, 5, 0, 1),
                                 start: spaeterStart, weeks: 4) == 1)
    }

    // MARK: - Kalender und Zeitzone

    @Test("Die Zeitumstellung verschiebt die Wochengrenze nicht")
    func dstDoesNotShiftTheWeek() {
        // 28.3.2027 hat in Berlin nur 23 Stunden. Gerechnet wird in Tagen,
        // nicht in Sekunden — sonst rutschte Tag 7 auf Woche 1 zurück.
        let fruehling = date(2027, 3, 22)
        #expect(PlanWeeks.number(of: date(2027, 3, 28), start: fruehling, weeks: 4) == 1)
        #expect(PlanWeeks.number(of: date(2027, 3, 29), start: fruehling, weeks: 4) == 2)
        // 25.10.2026 hat 25 Stunden.
        #expect(nummer(date(2026, 10, 25)) == 3)
        #expect(nummer(date(2026, 10, 26)) == 4)
    }

    @Test("Ohne eigenen Kalender wird der Berliner genommen")
    func defaultCalendarIsBerlin() {
        let tag = date(2026, 10, 12, 0, 30)
        #expect(PlanWeeks.number(of: tag, start: start, weeks: 4)
                == PlanWeeks.number(of: tag, start: start, weeks: 4,
                                    calendar: BerlinCalendar.calendar))
    }

    @Test("Die Zeitzone des übergebenen Kalenders entscheidet über den Tag")
    func calendarTimeZoneDecidesTheDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // 12.10.2026 00:30 in Berlin ist 11.10.2026 22:30 in UTC — in Berlin
        // schon Tag 7 und damit Woche 2, in UTC noch Tag 6 und Woche 1.
        let kurzNachMitternacht = date(2026, 10, 12, 0, 30)
        #expect(PlanWeeks.number(of: kurzNachMitternacht, start: start, weeks: 4) == 2)
        #expect(PlanWeeks.number(of: kurzNachMitternacht, start: start, weeks: 4,
                                 calendar: utc) == 1)
    }
}

/// Der 1-basierte Tag im Plan. Dieselben Grenzen wie bei der Planwoche, und
/// dieselbe Regel: gerechnet wird in ganzen Tagen ab Tagesbeginn, nie in
/// Sekunden.
@Suite("Plantag eines Datums")
struct PlanDayTests {

    private let cal = BerlinCalendar.calendar

    private func date(_ y: Int, _ m: Int, _ d: Int,
                      _ h: Int = 9, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d,
                                      hour: h, minute: min))!
    }

    /// Montag, 5.10.2026. Vier Wochen reichen bis Sonntag, 1.11.2026.
    private var start: Date { date(2026, 10, 5) }

    private func tag(_ d: Date, weeks: Int = 4) -> Int? {
        PlanWeeks.dayOfPlan(on: d, start: start, weeks: weeks)
    }

    // MARK: - Die ersten Tage

    @Test("Der Starttag selbst ist Tag 1")
    func startDayIsDayOne() {
        #expect(tag(date(2026, 10, 5)) == 1)
    }

    @Test("Jeder Kalendertag zählt genau einen weiter")
    func everyCalendarDayCountsOne() {
        #expect(tag(date(2026, 10, 6)) == 2)
        #expect(tag(date(2026, 10, 7)) == 3)
        #expect(tag(date(2026, 10, 11)) == 7)
        #expect(tag(date(2026, 10, 12)) == 8)
    }

    @Test("Bei Start am 5.10.2026 ist der 13.10.2026 Tag 9")
    func thirteenthOfOctoberIsDayNine() {
        #expect(tag(date(2026, 10, 13)) == 9)
    }

    // MARK: - Vor dem Planbeginn

    @Test("Der Tag vor dem Start liegt außerhalb des Plans")
    func dayBeforeStartIsNil() {
        #expect(tag(date(2026, 10, 4)) == nil)
        #expect(tag(date(2026, 10, 4, 23, 59)) == nil)
    }

    @Test("Ein Datum weit vor dem Start liegt außerhalb des Plans")
    func longBeforeStartIsNil() {
        #expect(tag(date(2026, 1, 1)) == nil)
    }

    // MARK: - Nach der letzten Woche

    @Test("Der letzte gültige Tag ist die Wochenzahl mal sieben")
    func lastValidDayIsWeeksTimesSeven() {
        // Vier Wochen ab Mo 5.10.2026: Tag 28 ist Sonntag, 1.11.2026.
        #expect(tag(date(2026, 11, 1)) == 28)
    }

    @Test("Der erste Tag nach der letzten Woche liegt außerhalb")
    func firstDayAfterTheLastWeekIsNil() {
        #expect(tag(date(2026, 11, 2)) == nil)
        #expect(tag(date(2026, 11, 2, 0, 1)) == nil)
    }

    @Test("Ein Plan über eine einzige Woche endet nach sieben Tagen")
    func singleWeekPlanEndsAfterSevenDays() {
        #expect(tag(date(2026, 10, 11), weeks: 1) == 7)
        #expect(tag(date(2026, 10, 12), weeks: 1) == nil)
    }

    @Test("Auch ein langer Plan hat seine Grenze am richtigen Tag")
    func longPlanEndsOnTheRightDay() {
        // 20 Wochen ab Mo 5.10.2026: Tag 140 ist Sonntag, 21.2.2027.
        #expect(tag(date(2027, 2, 21), weeks: 20) == 140)
        #expect(tag(date(2027, 2, 22), weeks: 20) == nil)
    }

    // MARK: - Keine Wochen

    @Test("Ein Plan ohne Wochen trifft kein Datum")
    func zeroWeeksIsNil() {
        #expect(tag(date(2026, 10, 5), weeks: 0) == nil)
        #expect(tag(date(2026, 10, 12), weeks: 0) == nil)
    }

    @Test("Eine negative Wochenzahl trifft ebenfalls kein Datum")
    func negativeWeeksIsNil() {
        #expect(tag(date(2026, 10, 5), weeks: -3) == nil)
    }

    // MARK: - Die Uhrzeit zählt nicht

    @Test("Später Abend und früher Morgen desselben Tages ergeben denselben Tag")
    func timeOfDayDoesNotMatter() {
        let spaet = date(2026, 10, 12, 23, 45)
        let frueh = date(2026, 10, 12, 0, 15)
        #expect(tag(spaet) == 8)
        #expect(tag(frueh) == 8)
        #expect(tag(spaet) == tag(frueh))
    }

    @Test("Über Mitternacht hinweg wechselt der Plantag")
    func midnightMovesToTheNextDay() {
        #expect(tag(date(2026, 10, 12, 23, 45)) == 8)
        #expect(tag(date(2026, 10, 13, 0, 15)) == 9)
    }

    @Test("Die Uhrzeit des Planbeginns verschiebt nichts")
    func timeOfDayOfStartDoesNotMatter() {
        let frueherStart = date(2026, 10, 5, 0, 30)
        let spaeterStart = date(2026, 10, 5, 23, 30)
        let dreizehnter = date(2026, 10, 13, 8)
        #expect(PlanWeeks.dayOfPlan(on: dreizehnter, start: frueherStart, weeks: 4) == 9)
        #expect(PlanWeeks.dayOfPlan(on: dreizehnter, start: spaeterStart, weeks: 4) == 9)
        // Der Starttag bleibt Tag 1, egal wann am Tag der Plan beginnt.
        #expect(PlanWeeks.dayOfPlan(on: date(2026, 10, 5, 0, 1),
                                    start: spaeterStart, weeks: 4) == 1)
    }

    // MARK: - Zeitumstellung

    @Test("Die Zeitumstellung Ende Oktober verschiebt den Plantag nicht")
    func autumnDstDoesNotShiftTheDay() {
        // 25.10.2026 hat in Berlin 25 Stunden. Gerechnet wird in Tagen, nicht
        // in Sekunden — sonst rutschte alles danach um einen Tag zurück.
        #expect(tag(date(2026, 10, 24)) == 20)
        #expect(tag(date(2026, 10, 25)) == 21)
        #expect(tag(date(2026, 10, 26)) == 22)
        // Auch mit einem Start unmittelbar vor der Umstellung.
        let kurzDavor = date(2026, 10, 24)
        #expect(PlanWeeks.dayOfPlan(on: date(2026, 10, 25), start: kurzDavor, weeks: 4) == 2)
        #expect(PlanWeeks.dayOfPlan(on: date(2026, 10, 26), start: kurzDavor, weeks: 4) == 3)
    }

    @Test("Auch die Umstellung im Frühjahr verschiebt den Plantag nicht")
    func springDstDoesNotShiftTheDay() {
        // 28.3.2027 hat in Berlin nur 23 Stunden.
        let fruehling = date(2027, 3, 22)
        #expect(PlanWeeks.dayOfPlan(on: date(2027, 3, 28), start: fruehling, weeks: 4) == 7)
        #expect(PlanWeeks.dayOfPlan(on: date(2027, 3, 29), start: fruehling, weeks: 4) == 8)
    }

    // MARK: - Kalender und Zeitzone

    @Test("Ohne eigenen Kalender wird der Berliner genommen")
    func defaultCalendarIsBerlin() {
        let d = date(2026, 10, 13, 0, 30)
        #expect(PlanWeeks.dayOfPlan(on: d, start: start, weeks: 4)
                == PlanWeeks.dayOfPlan(on: d, start: start, weeks: 4,
                                       calendar: BerlinCalendar.calendar))
    }

    @Test("Die Zeitzone des übergebenen Kalenders entscheidet über den Tag")
    func calendarTimeZoneDecidesTheDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // 13.10.2026 00:30 in Berlin ist 12.10.2026 22:30 in UTC — in Berlin
        // schon Tag 9, in UTC noch Tag 8.
        let kurzNachMitternacht = date(2026, 10, 13, 0, 30)
        #expect(PlanWeeks.dayOfPlan(on: kurzNachMitternacht, start: start, weeks: 4) == 9)
        #expect(PlanWeeks.dayOfPlan(on: kurzNachMitternacht, start: start, weeks: 4,
                                    calendar: utc) == 8)
    }

    // MARK: - Tag und Woche passen zusammen

    @Test("Der Plantag und die Planwoche beschreiben denselben Plan")
    func dayAndWeekAgree() {
        for versatz in 0..<28 {
            let d = cal.date(byAdding: .day, value: versatz, to: start)!
            let plantag = PlanWeeks.dayOfPlan(on: d, start: start, weeks: 4)
            let woche = PlanWeeks.number(of: d, start: start, weeks: 4)
            #expect(plantag == versatz + 1)
            #expect(woche == versatz / 7 + 1)
            #expect(plantag.map { ($0 - 1) / 7 + 1 } == woche)
        }
    }

    @Test("Außerhalb des Plans schweigen Tag und Woche gemeinsam")
    func bothAreNilOutsideThePlan() {
        for d in [date(2026, 10, 4), date(2026, 11, 2), date(2027, 1, 1)] {
            #expect(PlanWeeks.dayOfPlan(on: d, start: start, weeks: 4) == nil)
            #expect(PlanWeeks.number(of: d, start: start, weeks: 4) == nil)
        }
    }
}
