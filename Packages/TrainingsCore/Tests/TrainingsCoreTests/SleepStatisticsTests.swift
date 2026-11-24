import Foundation
import Testing
@testable import TrainingsCore

/// Dieselbe Schreibweise für Datum und Abschnitt wie in `SleepSessionTests`.
private enum Fixture {

    static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    static func segment(_ stage: SleepStage, _ from: String, _ to: String) -> SleepSegment {
        SleepSegment(stage: stage, start: date(from), end: date(to))
    }

    static func day(_ iso: String) -> Date { BerlinCalendar.startOfDay(date(iso)) }

    static func night(_ iso: String,
                      _ segments: [SleepSegment],
                      naps: [SleepSession] = []) -> SleepNight {
        SleepNight(date: day(iso), session: SleepSession(segments: segments), naps: naps)
    }

    // MARK: - Nächte

    /// Alle vier Phasen: 23:00 bis 06:00, 415 Schlafminuten, fünf Minuten wach.
    /// Kern 300, Tief 50, REM 65, Wach 5 — Summe der vier Phasen 420.
    /// Einschlafen 300, Aufwachen 720 Minuten seit 18 Uhr.
    static let fullNight = night("2026-10-12T12:00:00+02:00", [
        segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T00:30:00+02:00"),
        segment(.deep, "2026-10-12T00:30:00+02:00", "2026-10-12T01:20:00+02:00"),
        segment(.awake, "2026-10-12T01:20:00+02:00", "2026-10-12T01:25:00+02:00"),
        segment(.rem, "2026-10-12T01:25:00+02:00", "2026-10-12T02:30:00+02:00"),
        segment(.core, "2026-10-12T02:30:00+02:00", "2026-10-12T06:00:00+02:00"),
    ])

    /// 23:00 bis 05:00, sechs Stunden. Einschlafen 300, Aufwachen 660.
    static let nightFromElevenToFive = night("2026-10-12T12:00:00+02:00", [
        segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T05:00:00+02:00"),
    ])

    /// 01:00 bis 05:00, vier Stunden. Einschlafen 420, Aufwachen 660.
    static let nightFromOneToFive = night("2026-10-13T12:00:00+02:00", [
        segment(.core, "2026-10-13T01:00:00+02:00", "2026-10-13T05:00:00+02:00"),
    ])

    /// Die Nacht aus dem Prototyp: 23:23 bis 04:58, 328 Schlafminuten,
    /// 30 Wachminuten. Einschlafen 323, Aufwachen 658.
    static let prototypeNight = night("2026-10-12T12:00:00+02:00", [
        segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:23:00+02:00"),
        segment(.core, "2026-10-11T23:23:00+02:00", "2026-10-12T01:00:00+02:00"),
        segment(.deep, "2026-10-12T01:00:00+02:00", "2026-10-12T01:50:00+02:00"),
        segment(.awake, "2026-10-12T01:50:00+02:00", "2026-10-12T01:53:00+02:00"),
        segment(.rem, "2026-10-12T01:53:00+02:00", "2026-10-12T02:50:00+02:00"),
        segment(.awake, "2026-10-12T02:50:00+02:00", "2026-10-12T02:54:00+02:00"),
        segment(.core, "2026-10-12T02:54:00+02:00", "2026-10-12T04:58:00+02:00"),
    ])

    /// Nach Mitternacht eingeschlafen: 00:30 bis 04:58.
    /// Einschlafen 390, Aufwachen 658.
    static let nightAfterMidnight = night("2026-10-13T12:00:00+02:00", [
        segment(.core, "2026-10-13T00:30:00+02:00", "2026-10-13T04:58:00+02:00"),
    ])

    /// Eine ältere Uhr liefert nur unbestimmten Schlaf: 410 Schlafminuten,
    /// zehn Wachminuten, keine Phasendaten.
    static let unspecifiedNight = night("2026-10-16T12:00:00+02:00", [
        segment(.unspecified, "2026-10-15T23:00:00+02:00", "2026-10-16T02:00:00+02:00"),
        segment(.awake, "2026-10-16T02:00:00+02:00", "2026-10-16T02:10:00+02:00"),
        segment(.unspecified, "2026-10-16T02:10:00+02:00", "2026-10-16T06:00:00+02:00"),
    ])

    /// Phasen und unbestimmter Schlaf gemischt: Kern 60, unbestimmt 60, REM 60.
    static let mixedNight = night("2026-10-19T12:00:00+02:00", [
        segment(.core, "2026-10-18T23:00:00+02:00", "2026-10-19T00:00:00+02:00"),
        segment(.unspecified, "2026-10-19T00:00:00+02:00", "2026-10-19T01:00:00+02:00"),
        segment(.rem, "2026-10-19T01:00:00+02:00", "2026-10-19T02:00:00+02:00"),
    ])

    /// Kurze Nacht mit halb REM, halb Kern: je 60 Minuten.
    static let shortHalfRemNight = night("2026-10-17T12:00:00+02:00", [
        segment(.rem, "2026-10-17T00:00:00+02:00", "2026-10-17T01:00:00+02:00"),
        segment(.core, "2026-10-17T01:00:00+02:00", "2026-10-17T02:00:00+02:00"),
    ])

    /// Lange Nacht mit viel Kern: REM 60, Kern 360.
    static let longCoreNight = night("2026-10-18T12:00:00+02:00", [
        segment(.rem, "2026-10-17T22:00:00+02:00", "2026-10-17T23:00:00+02:00"),
        segment(.core, "2026-10-17T23:00:00+02:00", "2026-10-18T05:00:00+02:00"),
    ])

    // MARK: - Nächte am Rand der Abendskala

    /// Der gemeldete Fall vom 13.10.2026: Eine Schlafphase beginnt um **16:45**,
    /// also vor 18 Uhr. `EveningClock` zählt sie zum Abend davor und gibt ihr
    /// 1365 Minuten — auf der Skala der größte mögliche Ausschlag, auf dem
    /// Kreis dagegen eine Viertelstunde vor der Naht.
    /// Einschlafen 1365, Aufwachen 390 (00:30).
    static let nightFromQuarterToFive = night("2026-10-14T12:00:00+02:00", [
        segment(.core, "2026-10-13T16:45:00+02:00", "2026-10-14T00:30:00+02:00"),
    ])

    /// Zehn Minuten **vor** der Naht eingeschlafen: 17:50 bis 23:50.
    /// Einschlafen 1430, Aufwachen 350.
    static let nightFromTenToSix = night("2026-10-20T12:00:00+02:00", [
        segment(.core, "2026-10-20T17:50:00+02:00", "2026-10-20T23:50:00+02:00"),
    ])

    /// Zehn Minuten **nach** der Naht eingeschlafen: 18:10 bis 02:10.
    /// Einschlafen 10, Aufwachen 490.
    static let nightFromTenPastSix = night("2026-10-22T12:00:00+02:00", [
        segment(.core, "2026-10-21T18:10:00+02:00", "2026-10-22T02:10:00+02:00"),
    ])

    /// Zwanzig Minuten nach der Naht eingeschlafen: 18:20 bis 02:20.
    /// Einschlafen 20, Aufwachen 500.
    static let nightFromTwentyPastSix = night("2026-10-24T12:00:00+02:00", [
        segment(.core, "2026-10-23T18:20:00+02:00", "2026-10-24T02:20:00+02:00"),
    ])

    /// Drei Nächte, deren Einschlafzeiten den Kreis in drei gleiche Teile
    /// schneiden: 18:00 (0), 02:00 (480), 10:00 (960). Jede dauert genau sechs
    /// Stunden, damit auch die Aufwachzeiten gleichmäßig liegen: 00:00 (360),
    /// 08:00 (840), 16:00 (1320). Konstruiert, nicht gemessen — die Summe der
    /// drei Einheitsvektoren ist null, und eine Richtung hat sie nicht.
    ///
    /// Die Daten liegen im September, weil Ende Oktober die Sommerzeit endet:
    /// Am 25.10.2026 wäre „08:00+02:00" in Berlin sieben Uhr, und die
    /// gleichmäßige Verteilung wäre dahin.
    static let thirdsOfTheClock = [
        night("2026-09-22T12:00:00+02:00", [
            segment(.core, "2026-09-21T18:00:00+02:00", "2026-09-22T00:00:00+02:00"),
        ]),
        night("2026-09-23T12:00:00+02:00", [
            segment(.core, "2026-09-23T02:00:00+02:00", "2026-09-23T08:00:00+02:00"),
        ]),
        night("2026-09-24T12:00:00+02:00", [
            segment(.core, "2026-09-24T10:00:00+02:00", "2026-09-24T16:00:00+02:00"),
        ]),
    ]

    static let emptyNight = night("2026-10-14T12:00:00+02:00", [])

    static let awakeOnlyNight = night("2026-10-15T12:00:00+02:00", [
        segment(.awake, "2026-10-14T23:00:00+02:00", "2026-10-14T23:30:00+02:00"),
        segment(.awake, "2026-10-15T00:00:00+02:00", "2026-10-15T00:20:00+02:00"),
    ])

    /// 35 Minuten Mittagsschlaf.
    static let nap = SleepSession(segments: [
        segment(.unspecified, "2026-10-12T13:40:00+02:00", "2026-10-12T14:15:00+02:00"),
    ])
}

/// Gleitkommazahlen werden mit Toleranz verglichen, auch wenn sie fehlen
/// dürfen: Zwei fehlende Werte gelten als gleich.
private func nearly(_ value: Double?, _ expected: Double?, _ tolerance: Double = 1e-9) -> Bool {
    switch (value, expected) {
    case (nil, nil): return true
    case let (value?, expected?): return abs(value - expected) <= tolerance
    default: return false
    }
}

/// Uhrzeiten werden auf dem Kreis verglichen. Direkt an der 18-Uhr-Naht
/// bezeichnen 0 und 1440 − ε denselben Augenblick; ob die Vektorsumme im
/// letzten Bit nach oben oder nach unten fällt, darf kein Test entscheiden.
/// Zwei Werte, die auf der Skala 1440 Minuten auseinanderliegen, liegen auf
/// dem Kreis aufeinander — 720 und 0 trennt der Vergleich weiterhin.
private func nearlyOnTheClock(_ value: Double?,
                              _ expected: Double?,
                              _ tolerance: Double = 1e-6) -> Bool {
    switch (value, expected) {
    case (nil, nil): return true
    case let (value?, expected?):
        let gap = (value - expected).truncatingRemainder(dividingBy: 1440)
        return min(abs(gap), 1440 - abs(gap)) <= tolerance
    default: return false
    }
}

@Suite("Schlaf-Statistiken über mehrere Nächte")
struct SleepStatisticsTests {

    // MARK: - Ohne Grundlage

    @Test("Ohne Nächte gibt es keine Statistik")
    func noNightsNoStats() {
        #expect(SleepStatistics.over([]) == nil)
    }

    @Test("Eine leere Nacht ergibt keine Statistik")
    func emptyNightYieldsNoStats() {
        #expect(SleepStatistics.over([Fixture.emptyNight]) == nil)
    }

    @Test("Eine Nacht nur aus Wachliegen ergibt keine Statistik")
    func awakeOnlyNightYieldsNoStats() {
        #expect(SleepStatistics.over([Fixture.awakeOnlyNight]) == nil)
    }

    @Test("Mehrere Nächte ohne Schlaf ergeben zusammen keine Statistik")
    func severalNightsWithoutSleepYieldNoStats() {
        #expect(SleepStatistics.over([Fixture.emptyNight, Fixture.awakeOnlyNight]) == nil)
    }

    @Test("Eine Nacht ohne Schlaf zählt auch mit Tagschlaf nicht")
    func nightWithoutSleepButWithNapYieldsNoStats() {
        let night = SleepNight(date: Fixture.day("2026-10-14T12:00:00+02:00"),
                               session: SleepSession(segments: []),
                               naps: [Fixture.nap])
        #expect(SleepStatistics.over([night]) == nil)
    }

    // MARK: - Eine einzelne Nacht

    @Test("Eine einzelne Nacht liefert ihre eigenen Werte")
    func singleNight() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight]))
        #expect(stats.nights == 1)
        #expect(nearly(stats.averageAsleepHours, 415.0 / 60))
        #expect(nearly(stats.averageBedtimeMinutes, 300))
        #expect(nearly(stats.averageWakeMinutes, 720))
    }

    @Test("Eine gezählte Nacht hat immer eine Einschlaf- und eine Aufwachzeit")
    func countedNightsAlwaysHaveTimes() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight,
                                                       Fixture.unspecifiedNight]))
        #expect(stats.averageBedtimeMinutes != nil)
        #expect(stats.averageWakeMinutes != nil)
    }

    // MARK: - Mittlere Schlafdauer

    @Test("Die Schlafdauer ist das arithmetische Mittel der Nächte")
    func averageAsleepHoursIsTheArithmeticMean() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight,
                                                       Fixture.nightFromOneToFive]))
        #expect(stats.nights == 2)
        #expect(nearly(stats.averageAsleepHours, (415.0 + 240) / 2 / 60))
    }

    @Test("Nächte ohne Schlaf verschieben kein einziges Mittel")
    func nightsWithoutSleepDoNotCount() throws {
        let stats = try #require(SleepStatistics.over([Fixture.nightFromElevenToFive,
                                                       Fixture.emptyNight,
                                                       Fixture.awakeOnlyNight,
                                                       Fixture.nightFromOneToFive]))
        #expect(stats.nights == 2)
        #expect(nearly(stats.averageAsleepHours, 5))
        #expect(nearly(stats.averageBedtimeMinutes, 360))
        #expect(nearly(stats.averageWakeMinutes, 660))
    }

    @Test("Unbestimmter Schlaf zählt bei der Dauer voll mit")
    func unspecifiedSleepCountsTowardsDuration() throws {
        let stats = try #require(SleepStatistics.over([Fixture.unspecifiedNight]))
        #expect(stats.nights == 1)
        #expect(nearly(stats.averageAsleepHours, 410.0 / 60))
    }

    // MARK: - Uhrzeiten

    @Test("Das Mittel aus 23:00 und 01:00 ist Mitternacht, nicht Vormittag")
    func bedtimeMeanCrossesMidnight() throws {
        let stats = try #require(SleepStatistics.over([Fixture.nightFromElevenToFive,
                                                       Fixture.nightFromOneToFive]))
        #expect(nearly(stats.averageBedtimeMinutes, 360))
    }

    @Test("Die Aufwachzeiten werden genauso gemittelt")
    func wakeTimesAreAveraged() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight,
                                                       Fixture.nightFromElevenToFive]))
        #expect(nearly(stats.averageBedtimeMinutes, 300))
        #expect(nearly(stats.averageWakeMinutes, 690))
    }

    @Test("Die Uhrzeiten zählen Minuten seit 18 Uhr")
    func timesAreMinutesSinceEvening() throws {
        let prototype = try #require(SleepStatistics.over([Fixture.prototypeNight]))
        #expect(nearly(prototype.averageBedtimeMinutes, 323))
        #expect(nearly(prototype.averageWakeMinutes, 658))

        let afterMidnight = try #require(SleepStatistics.over([Fixture.nightAfterMidnight]))
        #expect(nearly(afterMidnight.averageBedtimeMinutes, 390))
        #expect(nearly(afterMidnight.averageWakeMinutes, 658))
    }

    // MARK: - Uhrzeiten auf dem 24-Stunden-Kreis

    @Test("Eine Nacht ab 16:45 zieht das Mittel nicht in den Vormittag")
    func anAfternoonStartDoesNotDragTheMeanForward() throws {
        // Der gemeldete Fall: 22:00 (240) und 16:45 (1365). Der gewöhnliche
        // Durchschnitt ergäbe 802,5 — also 07:22 vormittags, als Einschlafzeit
        // Unsinn. Auf dem Kreis liegen die beiden Zeiten 78,75° auseinander,
        // und ihre Winkelhalbierende zeigt auf 20,625°: 82,5 Minuten nach
        // 18 Uhr, also 19:22:30.
        let stats = try #require(SleepStatistics.over([Fixture.longCoreNight,
                                                       Fixture.nightFromQuarterToFive]))
        #expect(stats.nights == 2)
        #expect(nearly(stats.averageBedtimeMinutes, 82.5))
        #expect(!nearly(stats.averageBedtimeMinutes, 802.5, 1))

        // Die Aufwachzeiten liegen beieinander (05:00 und 00:30); dort ändert
        // der Kreis nichts.
        #expect(nearly(stats.averageWakeMinutes, 525))
    }

    @Test("Zehn Minuten vor und nach 18 Uhr mitteln sich zu 18 Uhr, nicht zu 06 Uhr")
    func timesAroundTheSeamMeanToSixInTheEvening() throws {
        let stats = try #require(SleepStatistics.over([Fixture.nightFromTenToSix,
                                                       Fixture.nightFromTenPastSix]))
        #expect(stats.nights == 2)
        #expect(nearlyOnTheClock(stats.averageBedtimeMinutes, 0))
        #expect(!nearly(stats.averageBedtimeMinutes, 720, 1))

        // 23:50 (350) und 02:10 (490) — ohne Naht, Mittel 01:00.
        #expect(nearly(stats.averageWakeMinutes, 420))
    }

    @Test("Liegt das Mittel knapp hinter der Naht, bleibt es knapp hinter der Naht")
    func aMeanJustPastTheSeamStaysThere() throws {
        // 17:50 (1430) und 18:20 (20): Die Winkelhalbierende zeigt auf
        // 1,25°, das sind fünf Minuten nach 18 Uhr.
        let stats = try #require(SleepStatistics.over([Fixture.nightFromTenToSix,
                                                       Fixture.nightFromTwentyPastSix]))
        #expect(nearly(stats.averageBedtimeMinutes, 5))
        #expect(nearly(stats.averageWakeMinutes, 425))
    }

    @Test("Eine einzelne Nacht behält ihre Uhrzeit auch kurz vor der Naht")
    func aSingleNightKeepsItsTimeEvenNextToTheSeam() throws {
        let nextToTheSeam = try #require(SleepStatistics.over([Fixture.nightFromTenToSix]))
        #expect(nearly(nextToTheSeam.averageBedtimeMinutes, 1430))
        #expect(nearly(nextToTheSeam.averageWakeMinutes, 350))

        let afternoon = try #require(SleepStatistics.over([Fixture.nightFromQuarterToFive]))
        #expect(nearly(afternoon.averageBedtimeMinutes, 1365))
        #expect(nearly(afternoon.averageWakeMinutes, 390))

        // Und in der Mitte der Skala, wo der Kreis bei 720 Minuten seinen
        // Gegenpunkt zur Naht hat.
        let middle = try #require(SleepStatistics.over([Fixture.fullNight]))
        #expect(nearly(middle.averageBedtimeMinutes, 300))
        #expect(nearly(middle.averageWakeMinutes, 720))
    }

    @Test("Drei gleichmäßig über den Kreis verteilte Zeiten haben kein Mittel")
    func threeTimesSpreadEvenlyHaveNoMean() throws {
        // 18:00, 02:00 und 10:00 heben sich als Vektoren auf. Eine Richtung
        // gibt es nicht, und jede ausgegebene Uhrzeit wäre erfunden — also
        // keine. Die Dauer bleibt davon unberührt, sie ist weiter ein
        // gewöhnliches Mittel.
        let stats = try #require(SleepStatistics.over(Fixture.thirdsOfTheClock))
        #expect(stats.nights == 3)
        #expect(nearly(stats.averageAsleepHours, 6))
        #expect(stats.averageBedtimeMinutes == nil)
        #expect(stats.averageWakeMinutes == nil)
    }

    @Test("Zwei gegenüberliegende Zeiten haben ebenfalls kein Mittel")
    func twoOppositeTimesHaveNoMean() throws {
        // 18:10 (10) und 06:10 (730) liegen einander genau gegenüber. Beide
        // Winkelhalbierenden wären gleich gut, also gilt dasselbe wie bei
        // drei verteilten Zeiten.
        let opposite = Fixture.night("2026-09-26T12:00:00+02:00", [
            Fixture.segment(.core, "2026-09-26T06:10:00+02:00", "2026-09-26T12:10:00+02:00"),
        ])
        let stats = try #require(SleepStatistics.over([Fixture.nightFromTenPastSix, opposite]))
        #expect(stats.nights == 2)
        #expect(stats.averageBedtimeMinutes == nil)
    }

    @Test("Das Mittel liegt immer zwischen 0 und 1440 Minuten")
    func theMeanAlwaysStaysOnTheScale() throws {
        let sets: [[SleepNight]] = [
            [Fixture.nightFromTenToSix],
            [Fixture.nightFromQuarterToFive],
            [Fixture.nightFromTenToSix, Fixture.nightFromTenPastSix],
            [Fixture.nightFromTenToSix, Fixture.nightFromTwentyPastSix],
            [Fixture.longCoreNight, Fixture.nightFromQuarterToFive],
            [Fixture.nightFromQuarterToFive, Fixture.nightFromTenToSix, Fixture.fullNight],
            [Fixture.nightFromQuarterToFive, Fixture.prototypeNight],
            Array(Fixture.thirdsOfTheClock.prefix(2)),
        ]
        for nights in sets {
            let stats = try #require(SleepStatistics.over(nights))
            if let bedtime = stats.averageBedtimeMinutes {
                #expect(bedtime >= 0)
                #expect(bedtime < 1440)
            }
            if let wake = stats.averageWakeMinutes {
                #expect(wake >= 0)
                #expect(wake < 1440)
            }
        }
    }

    // MARK: - Anteile der Phasen

    @Test("Die Anteile einer Nacht verteilen ihre vier Phasen")
    func sharesOfASingleNight() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight]))
        #expect(stats.shares.count == 4)
        #expect(nearly(stats.shares[.core], 300.0 / 420))
        #expect(nearly(stats.shares[.deep], 50.0 / 420))
        #expect(nearly(stats.shares[.rem], 65.0 / 420))
        #expect(nearly(stats.shares[.awake], 5.0 / 420))
    }

    @Test("Unbestimmter Schlaf kommt in den Anteilen nicht vor")
    func unspecifiedIsNoShare() throws {
        let stats = try #require(SleepStatistics.over([Fixture.mixedNight]))
        #expect(nearly(stats.averageAsleepHours, 3))
        #expect(stats.shares[.unspecified] == nil)
        #expect(nearly(stats.shares[.core], 0.5))
        #expect(nearly(stats.shares[.rem], 0.5))
        #expect(nearly(stats.shares.values.reduce(0, +), 1))
    }

    @Test("Eine Nacht ohne Phasendaten bleibt bei den Anteilen außen vor")
    func nightWithoutStagesIsLeftOutOfTheShares() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight,
                                                       Fixture.unspecifiedNight]))
        #expect(stats.nights == 2)
        #expect(nearly(stats.averageAsleepHours, (415.0 + 410) / 2 / 60))
        #expect(stats.shares.count == 4)
        #expect(nearly(stats.shares[.core], 300.0 / 420))
        #expect(nearly(stats.shares[.deep], 50.0 / 420))
        #expect(nearly(stats.shares[.rem], 65.0 / 420))
        #expect(nearly(stats.shares[.awake], 5.0 / 420))
    }

    @Test("Ohne eine einzige Nacht mit Phasendaten sind die Anteile leer")
    func noStageDataNoShares() throws {
        let stats = try #require(SleepStatistics.over([Fixture.unspecifiedNight]))
        #expect(stats.shares.isEmpty)
    }

    @Test("Die Anteile summieren sich auf eins")
    func sharesAddUpToOne() throws {
        let stats = try #require(SleepStatistics.over([Fixture.fullNight,
                                                       Fixture.prototypeNight,
                                                       Fixture.unspecifiedNight,
                                                       Fixture.emptyNight]))
        #expect(nearly(stats.shares.values.reduce(0, +), 1))
    }

    @Test("Die Anteile rechnen über die Minuten aller Nächte, nicht über deren Mittel")
    func sharesPoolMinutesAcrossNights() throws {
        let stats = try #require(SleepStatistics.over([Fixture.longCoreNight,
                                                       Fixture.shortHalfRemNight]))
        #expect(stats.nights == 2)
        #expect(nearly(stats.shares[.rem], 120.0 / 540))
        #expect(nearly(stats.shares[.core], 420.0 / 540))
        #expect(nearly(stats.shares.values.reduce(0, +), 1))
    }

    // MARK: - Tagschlaf und Reihenfolge

    @Test("Tagschlaf geht in die Statistik nicht ein")
    func napsAreIgnored() throws {
        let withNap = SleepNight(date: Fixture.fullNight.date,
                                 session: Fixture.fullNight.session,
                                 naps: [Fixture.nap])
        let plain = try #require(SleepStatistics.over([Fixture.fullNight]))
        let napped = try #require(SleepStatistics.over([withNap]))
        #expect(napped.nights == plain.nights)
        #expect(nearly(napped.averageAsleepHours, plain.averageAsleepHours))
        #expect(nearly(napped.averageBedtimeMinutes, plain.averageBedtimeMinutes))
        #expect(nearly(napped.averageWakeMinutes, plain.averageWakeMinutes))
        for stage in SleepStage.allCases {
            #expect(nearly(napped.shares[stage], plain.shares[stage]))
        }
    }

    @Test("Die Reihenfolge der Eingabe ändert die Statistik nicht")
    func inputOrderDoesNotMatter() throws {
        let nights = [Fixture.fullNight,
                      Fixture.nightFromElevenToFive,
                      Fixture.nightFromOneToFive,
                      Fixture.unspecifiedNight,
                      Fixture.emptyNight]
        let forward = try #require(SleepStatistics.over(nights))
        let backward = try #require(SleepStatistics.over(nights.reversed()))
        #expect(forward.nights == backward.nights)
        #expect(nearly(forward.averageAsleepHours, backward.averageAsleepHours))
        #expect(nearly(forward.averageBedtimeMinutes, backward.averageBedtimeMinutes))
        #expect(nearly(forward.averageWakeMinutes, backward.averageWakeMinutes))
        for stage in SleepStage.allCases {
            #expect(nearly(forward.shares[stage], backward.shares[stage]))
        }
    }
}
