import Foundation
import Testing
@testable import TrainingsCore

@Suite("Diagramm-Abschnitte")
struct ChartBucketsTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func sample(_ iso: String, _ value: Double) -> ChartSample {
        ChartSample(date: date(iso), value: value)
    }

    // MARK: - Leere Eingabe

    @Test("Ohne Messwerte gibt es keine Punkte")
    func noSamples() {
        for range in ChartRange.allCases {
            #expect(ChartBuckets.points([], for: range).isEmpty)
        }
    }

    // MARK: - Tag, Woche, Monat reichen durch

    @Test("Tag, Woche und Monat reichen die Messwerte unverändert durch")
    func passThroughKeepsSamples() {
        // Bewusst unsortiert hinein: das Ergebnis ist trotzdem aufsteigend.
        let samples = [sample("2026-10-03T00:00:00+02:00", 9000),
                       sample("2026-10-01T00:00:00+02:00", 7000),
                       sample("2026-10-02T00:00:00+02:00", 8000)]
        for range in [ChartRange.day, .week, .month] {
            let p = ChartBuckets.points(samples, for: range)
            #expect(p.count == 3)
            #expect(p.map(\.start) == [date("2026-10-01T00:00:00+02:00"),
                                       date("2026-10-02T00:00:00+02:00"),
                                       date("2026-10-03T00:00:00+02:00")])
            #expect(p.map(\.value) == [7000, 8000, 9000])
            #expect(p.map(\.dayCount) == [1, 1, 1])
        }
    }

    @Test("Mehrere Messwerte am selben Tag werden nicht zusammengefasst")
    func passThroughKeepsSeveralSamplesPerDay() {
        let samples = [sample("2026-10-01T12:00:00+02:00", 4000),
                       sample("2026-10-01T06:00:00+02:00", 2000)]
        let p = ChartBuckets.points(samples, for: .day)
        #expect(p.count == 2)
        #expect(p.map(\.start) == [date("2026-10-01T06:00:00+02:00"),
                                   date("2026-10-01T12:00:00+02:00")])
        #expect(p.map(\.value) == [2000, 4000])
        #expect(p.map(\.dayCount) == [1, 1])
    }

    @Test("Der Beginn eines Punkts ist seine Kennung")
    func idIsTheStart() {
        let p = ChartBuckets.points([sample("2026-10-01T00:00:00+02:00", 7000)], for: .month)
        #expect(p.count == 1)
        #expect(p[0].id == p[0].start)
        #expect(p[0].id == date("2026-10-01T00:00:00+02:00"))
    }

    // MARK: - Monatsmittel ab einem halben Jahr

    // Review Focus: Der Teiler ist die Zahl der gemessenen Tage, nicht die
    // Länge des Monats. Durch 28 geteilt kämen hier 321,43 heraus statt 3000 —
    // ein Monat mit wenigen Messungen sähe aus wie ein fauler Monat.
    @Test("Ab einem halben Jahr ist ein Punkt der Tagesdurchschnitt des Monats")
    func halfYearAveragesPerMonth() {
        let samples = [sample("2026-02-03T00:00:00+01:00", 1000),
                       sample("2026-02-17T00:00:00+01:00", 2000),
                       sample("2026-02-28T00:00:00+01:00", 6000)]
        let p = ChartBuckets.points(samples, for: .halfYear)
        #expect(p.count == 1)
        #expect(p[0].start == date("2026-02-01T00:00:00+01:00"))
        #expect(p[0].value == 3000)
        #expect(p[0].dayCount == 3)
    }

    @Test("Das Jahr rechnet dasselbe Monatsmittel wie das halbe Jahr")
    func yearAveragesPerMonth() {
        let samples = [sample("2026-02-03T00:00:00+01:00", 1000),
                       sample("2026-02-17T00:00:00+01:00", 2000),
                       sample("2026-02-28T00:00:00+01:00", 6000)]
        #expect(ChartBuckets.points(samples, for: .year)
                == ChartBuckets.points(samples, for: .halfYear))
    }

    @Test("Der Beginn eines Monatspunkts ist der Monatserste um Mitternacht")
    func monthPointsStartOnTheFirst() {
        // Unsortiert hinein, und der März liegt hinter der Sommerzeitgrenze:
        // der 1. April beginnt um 00:00 +02:00, der 1. März um 00:00 +01:00.
        let samples = [sample("2026-04-10T00:00:00+02:00", 5000),
                       sample("2026-01-05T00:00:00+01:00", 8000),
                       sample("2026-03-02T00:00:00+01:00", 4000),
                       sample("2026-03-30T00:00:00+02:00", 6000),
                       sample("2026-01-20T00:00:00+01:00", 12000)]
        let p = ChartBuckets.points(samples, for: .year)
        #expect(p.count == 3)
        #expect(p.map(\.start) == [date("2026-01-01T00:00:00+01:00"),
                                   date("2026-03-01T00:00:00+01:00"),
                                   date("2026-04-01T00:00:00+02:00")])
        #expect(p.map(\.value) == [10000, 5000, 5000])
        #expect(p.map(\.dayCount) == [2, 2, 1])
    }

    @Test("Ein Monat ohne jede Messung kommt im Ergebnis nicht vor")
    func monthsWithoutSamplesAreMissing() {
        let samples = [sample("2026-01-15T00:00:00+01:00", 9000),
                       sample("2026-03-15T00:00:00+01:00", 11000)]
        let p = ChartBuckets.points(samples, for: .halfYear)
        #expect(p.count == 2)
        #expect(p.map(\.start) == [date("2026-01-01T00:00:00+01:00"),
                                   date("2026-03-01T00:00:00+01:00")])
        #expect(p.map(\.value) == [9000, 11000])
        #expect(p.map(\.dayCount) == [1, 1])
    }

    // MARK: - Rastgrenzen

    @Test("Der Tag rastet auf den Tagesbeginn")
    func snapToStartOfDay() {
        let d = date("2026-05-16T17:20:00+02:00")
        #expect(ChartBuckets.snap(d, for: .day, .backward) == date("2026-05-16T00:00:00+02:00"))
        #expect(ChartBuckets.snap(d, for: .day, .forward) == date("2026-05-17T00:00:00+02:00"))
        #expect(ChartBuckets.snap(d, for: .day, .nearest) == date("2026-05-17T00:00:00+02:00"))
    }

    @Test("Die Woche rastet auf den Montag")
    func snapToMonday() {
        // Der 13.05.2026 ist ein Mittwoch, der 11.05. der Montag davor.
        let d = date("2026-05-13T10:00:00+02:00")
        #expect(ChartBuckets.snap(d, for: .week, .backward) == date("2026-05-11T00:00:00+02:00"))
        #expect(ChartBuckets.snap(d, for: .week, .forward) == date("2026-05-18T00:00:00+02:00"))
        #expect(ChartBuckets.snap(d, for: .week, .nearest) == date("2026-05-11T00:00:00+02:00"))
    }

    @Test("Monat und halbes Jahr rasten auf den Monatsersten")
    func snapToFirstOfMonth() {
        let d = date("2026-05-16T17:20:00+02:00")
        for range in [ChartRange.month, .halfYear] {
            #expect(ChartBuckets.snap(d, for: range, .backward) == date("2026-05-01T00:00:00+02:00"))
            #expect(ChartBuckets.snap(d, for: range, .forward) == date("2026-06-01T00:00:00+02:00"))
        }
    }

    @Test("Das Jahr rastet auf den 1. Januar")
    func snapToFirstOfJanuary() {
        let d = date("2026-05-16T17:20:00+02:00")
        #expect(ChartBuckets.snap(d, for: .year, .backward) == date("2026-01-01T00:00:00+01:00"))
        #expect(ChartBuckets.snap(d, for: .year, .forward) == date("2027-01-01T00:00:00+01:00"))
        #expect(ChartBuckets.snap(d, for: .year, .nearest) == date("2026-01-01T00:00:00+01:00"))
    }

    // MARK: - Grenzen bleiben stehen

    @Test("Vorwärts und rückwärts lassen einen Zeitpunkt auf der Grenze stehen")
    func snapKeepsExactBoundaries() {
        let cases: [(Date, ChartRange)] = [
            (date("2026-05-16T00:00:00+02:00"), .day),
            (date("2026-05-11T00:00:00+02:00"), .week),
            (date("2026-05-01T00:00:00+02:00"), .month),
            (date("2026-05-01T00:00:00+02:00"), .halfYear),
            (date("2026-01-01T00:00:00+01:00"), .year)
        ]
        for (d, range) in cases {
            #expect(ChartBuckets.snap(d, for: range, .backward) == d)
            #expect(ChartBuckets.snap(d, for: range, .forward) == d)
        }
    }

    @Test("Auch eine Grenze hinter der Sommerzeitumstellung bleibt stehen")
    func snapKeepsExactBoundaryAcrossDST() {
        // Montag, 30.03.2026, 00:00 — der Tag davor hatte 23 Stunden.
        let monday = date("2026-03-30T00:00:00+02:00")
        #expect(ChartBuckets.snap(monday, for: .week, .backward) == monday)
        #expect(ChartBuckets.snap(monday, for: .week, .forward) == monday)
        #expect(ChartBuckets.snap(monday, for: .day, .backward) == monday)
        #expect(ChartBuckets.snap(monday, for: .day, .forward) == monday)
    }

    // MARK: - Gleicher Abstand

    // Review Focus: bei exakt gleichem Abstand gewinnt die frühere Grenze.
    @Test("Bei gleichem Abstand nimmt die nächste Grenze die frühere")
    func nearestPrefersTheEarlierBoundaryOnATie() {
        // Mitte eines Tages ohne Umstellung: genau zwölf Stunden in beide Richtungen.
        #expect(ChartBuckets.snap(date("2026-05-16T12:00:00+02:00"), for: .day, .nearest)
                == date("2026-05-16T00:00:00+02:00"))
        // Mitte einer Woche ohne Umstellung: Donnerstag 12:00, je 84 Stunden.
        #expect(ChartBuckets.snap(date("2026-05-14T12:00:00+02:00"), for: .week, .nearest)
                == date("2026-05-11T00:00:00+02:00"))
    }

    // MARK: - Über die Sommerzeitgrenze

    // Review Focus: der wichtigste Test der Datei. Am 29.03.2026 hat der Tag
    // 23 Stunden. Wer mit `+ 86400` statt mit BerlinCalendar rechnet, landet
    // hinter der Umstellung um 01:00 statt um 00:00 — und die Woche begänne
    // am Sonntag.
    @Test("Die Umstellung auf Sommerzeit verschiebt keine Rastgrenze")
    func snapAcrossSpringForward() {
        // Sonntag, 29.03.2026, nach der Umstellung auf +02:00.
        let sunday = date("2026-03-29T13:45:00+02:00")
        #expect(ChartBuckets.snap(sunday, for: .day, .backward) == date("2026-03-29T00:00:00+01:00"))
        #expect(ChartBuckets.snap(sunday, for: .day, .forward) == date("2026-03-30T00:00:00+02:00"))
        #expect(ChartBuckets.snap(sunday, for: .week, .backward) == date("2026-03-23T00:00:00+01:00"))
        #expect(ChartBuckets.snap(sunday, for: .week, .forward) == date("2026-03-30T00:00:00+02:00"))
        #expect(ChartBuckets.snap(sunday, for: .month, .backward) == date("2026-03-01T00:00:00+01:00"))
        #expect(ChartBuckets.snap(sunday, for: .month, .forward) == date("2026-04-01T00:00:00+02:00"))

        // Eine halbe Stunde nach dem Montagsbeginn: Wer die verlorene Stunde
        // nicht kennt, rechnet die Grenze auf 01:00 und wirft diesen Zeitpunkt
        // noch in die Vorwoche.
        let earlyMonday = date("2026-03-30T00:30:00+02:00")
        #expect(ChartBuckets.snap(earlyMonday, for: .week, .backward) == date("2026-03-30T00:00:00+02:00"))
        #expect(ChartBuckets.snap(earlyMonday, for: .day, .backward) == date("2026-03-30T00:00:00+02:00"))
    }

    // Review Focus: die Gegenprobe. Am 25.10.2026 hat der Tag 25 Stunden,
    // und 02:30 gibt es zweimal — einmal mit +02:00, einmal mit +01:00.
    // Beide gehören zum selben Tag und zur selben Woche.
    @Test("Die Umstellung auf Winterzeit verschiebt keine Rastgrenze")
    func snapAcrossFallBack() {
        // Sonntag, 25.10.2026, nach der Umstellung auf +01:00.
        let sunday = date("2026-10-25T13:45:00+01:00")
        #expect(ChartBuckets.snap(sunday, for: .day, .backward) == date("2026-10-25T00:00:00+02:00"))
        #expect(ChartBuckets.snap(sunday, for: .day, .forward) == date("2026-10-26T00:00:00+01:00"))
        #expect(ChartBuckets.snap(sunday, for: .week, .backward) == date("2026-10-19T00:00:00+02:00"))
        #expect(ChartBuckets.snap(sunday, for: .week, .forward) == date("2026-10-26T00:00:00+01:00"))

        let firstPass = date("2026-10-25T02:30:00+02:00")
        let secondPass = date("2026-10-25T02:30:00+01:00")
        #expect(firstPass != secondPass)
        #expect(ChartBuckets.snap(firstPass, for: .day, .backward) == date("2026-10-25T00:00:00+02:00"))
        #expect(ChartBuckets.snap(secondPass, for: .day, .backward) == date("2026-10-25T00:00:00+02:00"))
        #expect(ChartBuckets.snap(firstPass, for: .week, .backward) == date("2026-10-19T00:00:00+02:00"))
        #expect(ChartBuckets.snap(secondPass, for: .week, .backward) == date("2026-10-19T00:00:00+02:00"))
    }

    // MARK: - Fensterbreite

    @Test("Die sichtbare Fensterbreite ist 24 Stunden, 7, 31, 183 und 366 Tage")
    func visibleLengths() {
        let day: TimeInterval = 24 * 60 * 60
        #expect(ChartBuckets.visibleLength(for: .day) == day)
        #expect(ChartBuckets.visibleLength(for: .week) == 7 * day)
        #expect(ChartBuckets.visibleLength(for: .month) == 31 * day)
        #expect(ChartBuckets.visibleLength(for: .halfYear) == 183 * day)
        #expect(ChartBuckets.visibleLength(for: .year) == 366 * day)
    }

    // MARK: - Abschnitt eines Datums

    @Test("Der Tagesabschnitt reicht von Mitternacht bis Mitternacht")
    func windowOfDay() {
        let w = ChartBuckets.window(containing: date("2026-05-16T17:20:00+02:00"), for: .day)
        #expect(w.start == date("2026-05-16T00:00:00+02:00"))
        #expect(w.end == date("2026-05-17T00:00:00+02:00"))
    }

    @Test("Der Wochenabschnitt reicht von Montag bis Montag")
    func windowOfWeek() {
        // Der 13.05.2026 ist ein Mittwoch, der 11.05. der Montag davor.
        let w = ChartBuckets.window(containing: date("2026-05-13T10:00:00+02:00"), for: .week)
        #expect(w.start == date("2026-05-11T00:00:00+02:00"))
        #expect(w.end == date("2026-05-18T00:00:00+02:00"))
    }

    @Test("Der Sonntag gehört noch zur Woche davor")
    func windowOfWeekKeepsSunday() {
        // Mit Montag als erstem Wochentag ist der Sonntag der letzte Tag,
        // nicht der erste einer neuen Woche.
        let w = ChartBuckets.window(containing: date("2026-05-17T23:59:00+02:00"), for: .week)
        #expect(w.start == date("2026-05-11T00:00:00+02:00"))
        #expect(w.end == date("2026-05-18T00:00:00+02:00"))
    }

    @Test("Der Monatsabschnitt reicht vom Ersten bis zum Ersten des Folgemonats")
    func windowOfMonth() {
        let w = ChartBuckets.window(containing: date("2026-05-16T17:20:00+02:00"), for: .month)
        #expect(w.start == date("2026-05-01T00:00:00+02:00"))
        #expect(w.end == date("2026-06-01T00:00:00+02:00"))
    }

    @Test("Der Jahresabschnitt reicht vom 1. Januar bis zum 1. Januar")
    func windowOfYear() {
        let w = ChartBuckets.window(containing: date("2026-05-16T17:20:00+02:00"), for: .year)
        #expect(w.start == date("2026-01-01T00:00:00+01:00"))
        #expect(w.end == date("2027-01-01T00:00:00+01:00"))
    }

    // MARK: - Halbjahre

    @Test("Ein Datum in der ersten Jahreshälfte landet im Januar-Abschnitt")
    func windowOfFirstHalfYear() {
        // Der 30. Juni ist der letzte Tag der ersten Hälfte.
        let w = ChartBuckets.window(containing: date("2026-06-30T23:00:00+02:00"), for: .halfYear)
        #expect(w.start == date("2026-01-01T00:00:00+01:00"))
        #expect(w.end == date("2026-07-01T00:00:00+02:00"))
    }

    @Test("Ein Datum in der zweiten Jahreshälfte landet im Juli-Abschnitt")
    func windowOfSecondHalfYear() {
        let w = ChartBuckets.window(containing: date("2026-09-15T08:00:00+02:00"), for: .halfYear)
        #expect(w.start == date("2026-07-01T00:00:00+02:00"))
        #expect(w.end == date("2027-01-01T00:00:00+01:00"))
    }

    @Test("Der 31. Dezember gehört noch in den Juli-Abschnitt desselben Jahres")
    func windowOfSecondHalfYearAtTheEnd() {
        let w = ChartBuckets.window(containing: date("2026-12-31T23:59:00+01:00"), for: .halfYear)
        #expect(w.start == date("2026-07-01T00:00:00+02:00"))
        #expect(w.end == date("2027-01-01T00:00:00+01:00"))
    }

    // MARK: - Ein Datum genau auf der Grenze

    // Review Focus: Ein Zeitpunkt auf einer Grenze beginnt seinen Abschnitt,
    // er beendet nicht den vorigen. Wer `end` einschließend behandelt, liefert
    // hier den Abschnitt davor und blättert eine Seite zu weit zurück.
    @Test("Ein Datum genau auf der Grenze beginnt seinen Abschnitt")
    func windowStartsAtAnExactBoundary() {
        let cases: [(Date, ChartRange, Date)] = [
            (date("2026-05-16T00:00:00+02:00"), .day, date("2026-05-17T00:00:00+02:00")),
            (date("2026-05-11T00:00:00+02:00"), .week, date("2026-05-18T00:00:00+02:00")),
            (date("2026-05-01T00:00:00+02:00"), .month, date("2026-06-01T00:00:00+02:00")),
            (date("2026-07-01T00:00:00+02:00"), .halfYear, date("2027-01-01T00:00:00+01:00")),
            (date("2026-01-01T00:00:00+01:00"), .halfYear, date("2026-07-01T00:00:00+02:00")),
            (date("2026-01-01T00:00:00+01:00"), .year, date("2027-01-01T00:00:00+01:00"))
        ]
        for (boundary, range, expectedEnd) in cases {
            let w = ChartBuckets.window(containing: boundary, for: range)
            #expect(w.start == boundary)
            #expect(w.end == expectedEnd)
        }
    }

    // MARK: - Zeitumstellung

    // Review Focus: Am 29.03.2026 beginnt die Sommerzeit. Die Woche vom
    // 23.03. hat 167 Stunden, nicht 168 — wer mit `+ 7 * 86400` rechnet,
    // landet als Ende auf Sonntag, dem 29.03., 23:00 Ortszeit und schneidet
    // den Montag an.
    @Test("Die Woche über die Sommerzeitgrenze endet am Montag um Mitternacht")
    func windowOfWeekAcrossSpringForward() {
        let w = ChartBuckets.window(containing: date("2026-03-29T13:45:00+02:00"), for: .week)
        #expect(w.start == date("2026-03-23T00:00:00+01:00"))
        #expect(w.end == date("2026-03-30T00:00:00+02:00"))
        // 167 Stunden verstrichene Zeit, aber sieben Kalendertage.
        #expect(w.end.timeIntervalSince(w.start) == 167 * 3600)
        #expect(dayCount(w) == 7)
    }

    @Test("Der 29.03.2026 hat als Tagesabschnitt 23 Stunden")
    func windowOfDayAcrossSpringForward() {
        let w = ChartBuckets.window(containing: date("2026-03-29T13:45:00+02:00"), for: .day)
        #expect(w.start == date("2026-03-29T00:00:00+01:00"))
        #expect(w.end == date("2026-03-30T00:00:00+02:00"))
        #expect(w.end.timeIntervalSince(w.start) == 23 * 3600)
    }

    // Review Focus: die Gegenprobe. Am 25.10.2026 endet die Sommerzeit, die
    // Woche vom 19.10. hat 169 Stunden.
    @Test("Die Woche über die Winterzeitgrenze endet am Montag um Mitternacht")
    func windowOfWeekAcrossFallBack() {
        let w = ChartBuckets.window(containing: date("2026-10-25T13:45:00+01:00"), for: .week)
        #expect(w.start == date("2026-10-19T00:00:00+02:00"))
        #expect(w.end == date("2026-10-26T00:00:00+01:00"))
        #expect(w.end.timeIntervalSince(w.start) == 169 * 3600)
        #expect(dayCount(w) == 7)
    }

    @Test("Der 25.10.2026 hat als Tagesabschnitt 25 Stunden")
    func windowOfDayAcrossFallBack() {
        let w = ChartBuckets.window(containing: date("2026-10-25T13:45:00+01:00"), for: .day)
        #expect(w.start == date("2026-10-25T00:00:00+02:00"))
        #expect(w.end == date("2026-10-26T00:00:00+01:00"))
        #expect(w.end.timeIntervalSince(w.start) == 25 * 3600)
    }

    @Test("Die doppelte Stunde am 25.10.2026 liegt in einem einzigen Abschnitt")
    func windowOfAmbiguousHour() {
        // 02:30 gibt es zweimal: einmal mit +02:00, einmal mit +01:00.
        let firstPass = date("2026-10-25T02:30:00+02:00")
        let secondPass = date("2026-10-25T02:30:00+01:00")
        #expect(firstPass != secondPass)
        for range in [ChartRange.day, .week] {
            #expect(ChartBuckets.window(containing: firstPass, for: range)
                    == ChartBuckets.window(containing: secondPass, for: range))
        }
    }

    // MARK: - Monatslängen

    // Review Focus: Der Abschnitt ist so lang wie der Monat, nicht pauschal
    // 31 Tage wie `visibleLength(for: .month)`. Der Oktober ist der Sonderfall:
    // 31 Kalendertage, aber 745 Stunden verstrichene Zeit.
    @Test("Jeder Monatsabschnitt ist genau so lang wie sein Monat")
    func windowOfMonthMatchesTheMonthLength() {
        let cases: [(String, String, String, Int)] = [
            // Februar 2027: 28 Tage, kein Schaltjahr.
            ("2027-02-14T12:00:00+01:00", "2027-02-01T00:00:00+01:00", "2027-03-01T00:00:00+01:00", 28),
            // Februar 2028: 29 Tage, Schaltjahr.
            ("2028-02-14T12:00:00+01:00", "2028-02-01T00:00:00+01:00", "2028-03-01T00:00:00+01:00", 29),
            // April 2026: 30 Tage, ganz in der Sommerzeit.
            ("2026-04-15T12:00:00+02:00", "2026-04-01T00:00:00+02:00", "2026-05-01T00:00:00+02:00", 30),
            // Oktober 2026: 31 Tage, mit der Umstellung auf Winterzeit darin.
            ("2026-10-15T12:00:00+02:00", "2026-10-01T00:00:00+02:00", "2026-11-01T00:00:00+01:00", 31)
        ]
        for (inside, start, end, days) in cases {
            let w = ChartBuckets.window(containing: date(inside), for: .month)
            #expect(w.start == date(start))
            #expect(w.end == date(end))
            #expect(dayCount(w) == days)
        }
    }

    @Test("Der 29. Februar 2028 liegt im Februar-Abschnitt")
    func windowOfLeapDay() {
        let w = ChartBuckets.window(containing: date("2028-02-29T23:30:00+01:00"), for: .month)
        #expect(w.start == date("2028-02-01T00:00:00+01:00"))
        #expect(w.end == date("2028-03-01T00:00:00+01:00"))
    }

    // MARK: - Reihe von Abschnitten

    @Test("Tage über die Sommerzeitgrenze kommen lückenlos hintereinander")
    func windowsOfDaysAcrossSpringForward() {
        let starts = ChartBuckets.windows(from: date("2026-03-28T06:00:00+01:00"),
                                          to: date("2026-03-31T22:00:00+02:00"),
                                          for: .day)
        #expect(starts == [date("2026-03-28T00:00:00+01:00"),
                           date("2026-03-29T00:00:00+01:00"),
                           date("2026-03-30T00:00:00+02:00"),
                           date("2026-03-31T00:00:00+02:00")])
    }

    @Test("Wochen über die Winterzeitgrenze kommen lückenlos hintereinander")
    func windowsOfWeeksAcrossFallBack() {
        let starts = ChartBuckets.windows(from: date("2026-10-21T09:00:00+02:00"),
                                          to: date("2026-11-03T09:00:00+01:00"),
                                          for: .week)
        #expect(starts == [date("2026-10-19T00:00:00+02:00"),
                           date("2026-10-26T00:00:00+01:00"),
                           date("2026-11-02T00:00:00+01:00")])
    }

    // Review Focus: Über die Jahresgrenze darf der Monatszähler nicht auf
    // Monat 13 laufen.
    @Test("Monate über die Jahresgrenze ergeben vier Abschnitte")
    func windowsOfMonthsAcrossTheYearBoundary() {
        let starts = ChartBuckets.windows(from: date("2026-11-15T12:00:00+01:00"),
                                          to: date("2027-02-10T12:00:00+01:00"),
                                          for: .month)
        #expect(starts == [date("2026-11-01T00:00:00+01:00"),
                           date("2026-12-01T00:00:00+01:00"),
                           date("2027-01-01T00:00:00+01:00"),
                           date("2027-02-01T00:00:00+01:00")])
    }

    @Test("Halbjahre laufen über anderthalb Jahre in vier Abschnitten")
    func windowsOfHalfYears() {
        let starts = ChartBuckets.windows(from: date("2026-03-05T12:00:00+01:00"),
                                          to: date("2027-08-10T12:00:00+02:00"),
                                          for: .halfYear)
        #expect(starts == [date("2026-01-01T00:00:00+01:00"),
                           date("2026-07-01T00:00:00+02:00"),
                           date("2027-01-01T00:00:00+01:00"),
                           date("2027-07-01T00:00:00+02:00")])
    }

    @Test("Jahre ergeben einen Abschnitt je Kalenderjahr")
    func windowsOfYears() {
        let starts = ChartBuckets.windows(from: date("2026-05-16T12:00:00+02:00"),
                                          to: date("2028-02-01T12:00:00+01:00"),
                                          for: .year)
        #expect(starts == [date("2026-01-01T00:00:00+01:00"),
                           date("2027-01-01T00:00:00+01:00"),
                           date("2028-01-01T00:00:00+01:00")])
    }

    // MARK: - Randfälle der Reihe

    @Test("Zwei Zeitpunkte im selben Abschnitt ergeben einen Eintrag")
    func windowsWithinOneWindow() {
        let expected: [ChartRange: Date] = [
            .day: date("2026-05-16T00:00:00+02:00"),
            .week: date("2026-05-11T00:00:00+02:00"),
            .month: date("2026-05-01T00:00:00+02:00"),
            .halfYear: date("2026-01-01T00:00:00+01:00"),
            .year: date("2026-01-01T00:00:00+01:00")
        ]
        for range in ChartRange.allCases {
            let starts = ChartBuckets.windows(from: date("2026-05-16T06:00:00+02:00"),
                                              to: date("2026-05-16T22:00:00+02:00"),
                                              for: range)
            #expect(starts == [expected[range]!])
        }
    }

    @Test("Derselbe Zeitpunkt zweimal ergibt einen Eintrag")
    func windowsWithIdenticalBounds() {
        let d = date("2026-05-16T06:00:00+02:00")
        for range in ChartRange.allCases {
            let starts = ChartBuckets.windows(from: d, to: d, for: range)
            #expect(starts == [ChartBuckets.window(containing: d, for: range).start])
        }
    }

    @Test("Liegt das Ende vor dem Anfang, gibt es keine Abschnitte")
    func windowsWithReversedBounds() {
        // Für jede Stufe liegt `last` einen ganzen Abschnitt vor `first`.
        let cases: [(ChartRange, String, String)] = [
            (.day, "2026-05-16T06:00:00+02:00", "2026-05-15T06:00:00+02:00"),
            (.week, "2026-05-13T06:00:00+02:00", "2026-05-06T06:00:00+02:00"),
            (.month, "2026-05-16T06:00:00+02:00", "2026-03-20T06:00:00+01:00"),
            (.halfYear, "2026-09-16T06:00:00+02:00", "2026-03-20T06:00:00+01:00"),
            (.year, "2027-05-16T06:00:00+02:00", "2026-03-20T06:00:00+01:00")
        ]
        for (range, first, last) in cases {
            #expect(ChartBuckets.windows(from: date(first), to: date(last), for: range).isEmpty)
        }
    }

    // MARK: - Lückenlosigkeit

    // Review Focus: Das Ende eines Abschnitts ist der Anfang des nächsten.
    // Fehlt oder doppelt sich dazwischen eine Stunde, hängt das Diagramm
    // beim Blättern zwischen zwei Seiten fest.
    @Test("Jeder Abschnitt endet dort, wo der nächste beginnt")
    func windowsAreContiguous() {
        // Spannen, die jeweils beide Zeitumstellungen und eine Jahresgrenze
        // einschließen.
        let spans: [(ChartRange, String, String)] = [
            (.day, "2026-03-27T12:00:00+01:00", "2026-04-02T12:00:00+02:00"),
            (.day, "2026-10-23T12:00:00+02:00", "2026-10-29T12:00:00+01:00"),
            (.day, "2026-12-29T12:00:00+01:00", "2027-01-03T12:00:00+01:00"),
            (.week, "2026-03-02T12:00:00+01:00", "2026-11-30T12:00:00+01:00"),
            (.week, "2026-12-14T12:00:00+01:00", "2027-01-25T12:00:00+01:00"),
            (.month, "2026-01-15T12:00:00+01:00", "2028-03-15T12:00:00+01:00"),
            (.halfYear, "2026-02-15T12:00:00+01:00", "2029-08-15T12:00:00+02:00"),
            (.year, "2024-02-15T12:00:00+01:00", "2029-08-15T12:00:00+02:00")
        ]
        for (range, first, last) in spans {
            let starts = ChartBuckets.windows(from: date(first), to: date(last), for: range)
            #expect(starts.count >= 2)
            #expect(starts == starts.sorted())
            for i in starts.indices.dropLast() {
                #expect(ChartBuckets.window(containing: starts[i], for: range).end == starts[i + 1])
            }
            // Der letzte Eintrag deckt den Endzeitpunkt noch ab.
            let lastWindow = ChartBuckets.window(containing: starts[starts.count - 1], for: range)
            #expect(lastWindow.start <= date(last))
            #expect(lastWindow.end > date(last))
        }
    }

    @Test("Jeder Eintrag der Reihe ist selbst ein Abschnittsanfang")
    func windowsReturnsWindowStarts() {
        for range in ChartRange.allCases {
            let starts = ChartBuckets.windows(from: date("2026-01-05T12:00:00+01:00"),
                                              to: date("2026-11-05T12:00:00+01:00"),
                                              for: range)
            for start in starts {
                #expect(ChartBuckets.window(containing: start, for: range).start == start)
            }
        }
    }

    // MARK: - Hilfsmittel

    /// Länge eines Abschnitts in Kalendertagen — nicht in Sekunden, sonst
    /// zählt der Oktober 2026 wegen der gewonnenen Stunde 31 Tage und eine
    /// Stunde.
    private func dayCount(_ interval: DateInterval) -> Int {
        BerlinCalendar.calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? -1
    }
}
