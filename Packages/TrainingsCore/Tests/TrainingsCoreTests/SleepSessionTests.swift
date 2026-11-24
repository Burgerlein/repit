import Foundation
import Testing
@testable import TrainingsCore

@Suite("Schlafabschnitte")
struct SleepSessionTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func segment(_ stage: SleepStage, _ from: String, _ to: String) -> SleepSegment {
        SleepSegment(stage: stage, start: date(from), end: date(to))
    }

    /// Eine Nacht mit Wachliegen davor, zwei Wachphasen mittendrin und
    /// Wachliegen danach. Schlaf von 23:00 bis 02:10.
    private var night: SleepSession {
        SleepSession(segments: [
            segment(.awake, "2026-10-11T22:30:00+02:00", "2026-10-11T23:00:00+02:00"),
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-11T23:40:00+02:00"),
            segment(.deep, "2026-10-11T23:40:00+02:00", "2026-10-12T00:10:00+02:00"),
            segment(.awake, "2026-10-12T00:10:00+02:00", "2026-10-12T00:15:00+02:00"),
            segment(.rem, "2026-10-12T00:15:00+02:00", "2026-10-12T01:00:00+02:00"),
            segment(.unspecified, "2026-10-12T01:00:00+02:00", "2026-10-12T01:10:00+02:00"),
            segment(.awake, "2026-10-12T01:10:00+02:00", "2026-10-12T01:15:00+02:00"),
            segment(.core, "2026-10-12T01:15:00+02:00", "2026-10-12T02:10:00+02:00"),
            segment(.awake, "2026-10-12T02:10:00+02:00", "2026-10-12T02:30:00+02:00"),
        ])
    }

    // MARK: - Phasen

    @Test("Alles außer wach gilt als Schlaf")
    func stagesThatCountAsSleep() {
        #expect(SleepStage.awake.isAsleep == false)
        #expect(SleepStage.rem.isAsleep)
        #expect(SleepStage.core.isAsleep)
        #expect(SleepStage.deep.isAsleep)
        #expect(SleepStage.unspecified.isAsleep)
    }

    @Test("Die Phasen sind in der Reihenfolge des Vertrags aufgezählt")
    func stageOrder() {
        #expect(SleepStage.allCases == [.awake, .rem, .core, .deep, .unspecified])
    }

    @Test("Die Phasen tragen ihre eigenen Namen")
    func stageRawValues() {
        #expect(SleepStage.deep.rawValue == "deep")
        #expect(SleepStage.unspecified.rawValue == "unspecified")
    }

    // MARK: - Einzelner Abschnitt

    @Test("Ein Abschnitt zählt seine Minuten")
    func segmentMinutes() {
        let s = segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T00:30:00+02:00")
        #expect(s.minutes == 90)
    }

    @Test("Ein Abschnitt ohne Dauer hat null Minuten")
    func segmentWithoutDuration() {
        let s = segment(.deep, "2026-10-11T23:00:00+02:00", "2026-10-11T23:00:00+02:00")
        #expect(s.minutes == 0)
    }

    @Test("Ein Abschnitt, der vor seinem Beginn endet, hat null Minuten")
    func segmentEndingBeforeItStarts() {
        let s = segment(.rem, "2026-10-12T01:00:00+02:00", "2026-10-11T23:00:00+02:00")
        #expect(s.minutes == 0)
    }

    @Test("Ein Abschnitt zählt auch halbe Minuten")
    func segmentWithPartialMinute() {
        let s = segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:00:30+02:00")
        #expect(s.minutes == 0.5)
    }

    // MARK: - Leere Nacht

    @Test("Ohne Abschnitte ist die Nacht leer")
    func emptySession() {
        let s = SleepSession(segments: [])
        #expect(s.isEmpty)
        #expect(s.start == nil)
        #expect(s.end == nil)
        #expect(s.asleepMinutes == 0)
        #expect(s.asleepHours == 0)
        #expect(s.awakeMinutes == 0)
        #expect(s.wakeCount == 0)
        #expect(s.minutes(.deep) == 0)
        #expect(s.minutes(.awake) == 0)
    }

    @Test("Eine Nacht nur aus Wachliegen ist keine Nacht")
    func onlyAwakeIsNoNight() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.awake, "2026-10-12T00:00:00+02:00", "2026-10-12T00:20:00+02:00"),
        ])
        #expect(s.isEmpty == false)
        #expect(s.start == nil)
        #expect(s.end == nil)
        #expect(s.asleepMinutes == 0)
        #expect(s.asleepHours == 0)
        #expect(s.awakeMinutes == 0)
        #expect(s.wakeCount == 0)
    }

    @Test("Auch ohne Schlaf werden die Wachminuten je Phase gezählt")
    func onlyAwakeStillSumsItsStage() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.awake, "2026-10-12T00:00:00+02:00", "2026-10-12T00:20:00+02:00"),
        ])
        #expect(s.minutes(.awake) == 50)
        #expect(s.minutes(.deep) == 0)
    }

    // MARK: - Sortierung

    @Test("Unsortierte Abschnitte kommen sortiert heraus")
    func segmentsAreSorted() {
        let first = segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-11T23:40:00+02:00")
        let second = segment(.deep, "2026-10-11T23:40:00+02:00", "2026-10-12T00:10:00+02:00")
        let third = segment(.rem, "2026-10-12T00:10:00+02:00", "2026-10-12T01:00:00+02:00")
        let s = SleepSession(segments: [third, first, second])
        #expect(s.segments == [first, second, third])
    }

    @Test("Die Reihenfolge der Eingabe ändert die Nacht nicht")
    func inputOrderDoesNotMatter() {
        let shuffled = SleepSession(segments: night.segments.reversed())
        #expect(shuffled == night)
    }

    // MARK: - Beginn und Ende

    @Test("Die Nacht beginnt mit dem ersten Schlafabschnitt")
    func startSkipsLeadingAwake() {
        #expect(night.start == date("2026-10-11T23:00:00+02:00"))
    }

    @Test("Die Nacht endet mit dem letzten Schlafabschnitt")
    func endSkipsTrailingAwake() {
        #expect(night.end == date("2026-10-12T02:10:00+02:00"))
    }

    @Test("Ein einziger Schlafabschnitt ist Beginn und Ende zugleich")
    func singleAsleepSegment() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T22:00:00+02:00", "2026-10-11T23:00:00+02:00"),
            segment(.deep, "2026-10-11T23:00:00+02:00", "2026-10-12T01:00:00+02:00"),
            segment(.awake, "2026-10-12T01:00:00+02:00", "2026-10-12T01:30:00+02:00"),
        ])
        #expect(s.start == date("2026-10-11T23:00:00+02:00"))
        #expect(s.end == date("2026-10-12T01:00:00+02:00"))
    }

    @Test("Ein unbestimmter Abschnitt eröffnet die Nacht ebenfalls")
    func unspecifiedOpensTheNight() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T22:00:00+02:00", "2026-10-11T22:30:00+02:00"),
            segment(.unspecified, "2026-10-11T22:30:00+02:00", "2026-10-11T23:00:00+02:00"),
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T00:00:00+02:00"),
        ])
        #expect(s.start == date("2026-10-11T22:30:00+02:00"))
        #expect(s.end == date("2026-10-12T00:00:00+02:00"))
    }

    // MARK: - Schlafzeit

    @Test("Geschlafen ist alles außer wach")
    func asleepMinutesCountEverythingButAwake() {
        #expect(night.asleepMinutes == 180)
    }

    @Test("Die Schlafstunden sind die Schlafminuten durch sechzig")
    func asleepHours() {
        #expect(night.asleepHours == 3)
    }

    @Test("Unbestimmte Abschnitte zählen als Schlaf")
    func unspecifiedCountsAsSleep() {
        let s = SleepSession(segments: [
            segment(.unspecified, "2026-10-11T23:00:00+02:00", "2026-10-12T00:30:00+02:00"),
        ])
        #expect(s.asleepMinutes == 90)
        #expect(s.asleepHours == 1.5)
    }

    // MARK: - Wachphasen

    @Test("Nur das Wachliegen innerhalb der Nacht zählt")
    func awakeMinutesOnlyInsideTheNight() {
        #expect(night.awakeMinutes == 10)
    }

    @Test("Die Wachphasen innerhalb der Nacht werden gezählt")
    func wakeCountOnlyInsideTheNight() {
        #expect(night.wakeCount == 2)
    }

    @Test("Wachliegen vor dem Einschlafen und nach dem Aufwachen zählt nicht mit")
    func awakeOutsideTheNightIsIgnored() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T21:00:00+02:00", "2026-10-11T23:00:00+02:00"),
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T05:00:00+02:00"),
            segment(.awake, "2026-10-12T05:00:00+02:00", "2026-10-12T06:00:00+02:00"),
        ])
        #expect(s.awakeMinutes == 0)
        #expect(s.wakeCount == 0)
        #expect(s.asleepMinutes == 360)
    }

    // MARK: - Minuten je Phase

    @Test("Jede Phase wird einzeln summiert")
    func minutesPerStage() {
        #expect(night.minutes(.core) == 95)
        #expect(night.minutes(.deep) == 30)
        #expect(night.minutes(.rem) == 45)
        #expect(night.minutes(.unspecified) == 10)
    }

    @Test("Die Wachminuten je Phase zählen auch vor und nach der Nacht")
    func minutesOfAwakeIncludesTheEdges() {
        #expect(night.minutes(.awake) == 60)
    }

    // MARK: - Überlappungen

    @Test("Überlappende Abschnitte werden nicht zusammengefasst")
    func overlappingSegmentsAreKept() {
        let s = SleepSession(segments: [
            segment(.deep, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.core, "2026-10-11T23:15:00+02:00", "2026-10-11T23:45:00+02:00"),
        ])
        #expect(s.segments.count == 2)
        #expect(s.minutes(.deep) == 30)
        #expect(s.minutes(.core) == 30)
    }

    @Test("Überlappende Abschnitte addieren ihre Minuten")
    func overlappingSegmentsAddUp() {
        let s = SleepSession(segments: [
            segment(.deep, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.core, "2026-10-11T23:15:00+02:00", "2026-10-11T23:45:00+02:00"),
        ])
        #expect(s.asleepMinutes == 60)
        #expect(s.start == date("2026-10-11T23:00:00+02:00"))
        #expect(s.end == date("2026-10-11T23:45:00+02:00"))
    }

    // MARK: - Nacht aus dem Prototyp

    @Test("Die Nacht aus dem Prototyp dauert von 23:23 bis 04:58")
    func prototypeNight() {
        let s = SleepSession(segments: [
            segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:23:00+02:00"),
            segment(.core, "2026-10-11T23:23:00+02:00", "2026-10-12T01:00:00+02:00"),
            segment(.deep, "2026-10-12T01:00:00+02:00", "2026-10-12T01:50:00+02:00"),
            segment(.awake, "2026-10-12T01:50:00+02:00", "2026-10-12T01:53:00+02:00"),
            segment(.rem, "2026-10-12T01:53:00+02:00", "2026-10-12T02:50:00+02:00"),
            segment(.awake, "2026-10-12T02:50:00+02:00", "2026-10-12T02:54:00+02:00"),
            segment(.core, "2026-10-12T02:54:00+02:00", "2026-10-12T04:58:00+02:00"),
        ])
        #expect(s.start == date("2026-10-11T23:23:00+02:00"))
        #expect(s.end == date("2026-10-12T04:58:00+02:00"))
        #expect(s.awakeMinutes == 7)
        #expect(s.wakeCount == 2)
        #expect(s.asleepMinutes == 328)
    }
}

/// Dieselbe Schreibweise für Datum und Abschnitt wie in der Suite oben, von
/// den beiden folgenden Suiten geteilt.
private enum Fixture {

    static func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    static func segment(_ stage: SleepStage, _ from: String, _ to: String) -> SleepSegment {
        SleepSegment(stage: stage, start: date(from), end: date(to))
    }

    /// Eine gewöhnliche Nacht: Schlaf von 23:00 bis 06:00, fünf Minuten wach
    /// mittendrin, 415 Schlafminuten.
    static let nightSegments: [SleepSegment] = [
        segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T00:30:00+02:00"),
        segment(.deep, "2026-10-12T00:30:00+02:00", "2026-10-12T01:20:00+02:00"),
        segment(.awake, "2026-10-12T01:20:00+02:00", "2026-10-12T01:25:00+02:00"),
        segment(.rem, "2026-10-12T01:25:00+02:00", "2026-10-12T02:30:00+02:00"),
        segment(.core, "2026-10-12T02:30:00+02:00", "2026-10-12T06:00:00+02:00"),
    ]

    /// Mittagsschlaf desselben Tages, 35 Minuten.
    static let napSegment = segment(.unspecified,
                                    "2026-10-12T13:40:00+02:00",
                                    "2026-10-12T14:15:00+02:00")
}

@Suite("Schlafphasen")
struct SleepPhaseTests {

    private func date(_ iso: String) -> Date { Fixture.date(iso) }

    private func segment(_ stage: SleepStage, _ from: String, _ to: String) -> SleepSegment {
        Fixture.segment(stage, from, to)
    }

    // MARK: - Festwert

    @Test("Eine neue Phase beginnt nach vier Stunden Pause")
    func gapIsFourHours() {
        #expect(SleepSession.nightGapHours == 4)
    }

    // MARK: - Zerlegung

    @Test("Eine durchgehende Nacht bleibt eine einzige Phase")
    func continuousNightStaysOnePhase() {
        let phases = SleepSession.phases(from: Fixture.nightSegments)
        #expect(phases.count == 1)
        #expect(phases[0].start == date("2026-10-11T23:00:00+02:00"))
        #expect(phases[0].end == date("2026-10-12T06:00:00+02:00"))
        #expect(phases[0].asleepMinutes == 415)
    }

    @Test("Nacht und Mittagsschlaf werden zwei Phasen")
    func nightAndNapBecomeTwoPhases() {
        let phases = SleepSession.phases(from: Fixture.nightSegments + [Fixture.napSegment])
        #expect(phases.count == 2)
        #expect(phases[0].end == date("2026-10-12T06:00:00+02:00"))
        #expect(phases[0].asleepMinutes == 415)
        #expect(phases[1].start == date("2026-10-12T13:40:00+02:00"))
        #expect(phases[1].asleepMinutes == 35)
    }

    @Test("Drei Phasen an einem Tag werden einzeln geführt")
    func threePhasesInOneDay() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T05:00:00+02:00"),
            segment(.core, "2026-10-12T10:00:00+02:00", "2026-10-12T10:30:00+02:00"),
            segment(.rem, "2026-10-12T15:00:00+02:00", "2026-10-12T15:40:00+02:00"),
        ])
        #expect(phases.count == 3)
        #expect(phases.map(\.asleepMinutes) == [360, 30, 40])
    }

    // MARK: - Die Grenze

    @Test("Genau vier Stunden Pause bleiben dieselbe Phase")
    func exactlyFourHoursStaysTogether() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T06:00:00+02:00", "2026-10-12T07:00:00+02:00"),
        ])
        #expect(phases.count == 1)
        #expect(phases[0].start == date("2026-10-11T23:00:00+02:00"))
        #expect(phases[0].end == date("2026-10-12T07:00:00+02:00"))
    }

    @Test("Eine Minute über vier Stunden beginnt eine neue Phase")
    func oneMinuteOverFourHoursSplits() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T06:01:00+02:00", "2026-10-12T07:00:00+02:00"),
        ])
        #expect(phases.count == 2)
        #expect(phases[0].end == date("2026-10-12T02:00:00+02:00"))
        #expect(phases[1].start == date("2026-10-12T06:01:00+02:00"))
    }

    @Test("Knapp unter vier Stunden Pause bleibt dieselbe Phase")
    func justUnderFourHoursStaysTogether() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T05:59:00+02:00", "2026-10-12T07:00:00+02:00"),
        ])
        #expect(phases.count == 1)
    }

    @Test("Gemessen wird die Pause, nicht der Abstand der Anfänge")
    func gapIsMeasuredFromEndToStart() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T22:00:00+02:00", "2026-10-12T03:00:00+02:00"),
            segment(.core, "2026-10-12T06:30:00+02:00", "2026-10-12T08:00:00+02:00"),
        ])
        #expect(phases.count == 1)
    }

    @Test("Die Grenze lässt sich für den Aufruf verschieben")
    func gapCanBeOverridden() {
        let segments = [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T05:00:00+02:00", "2026-10-12T07:00:00+02:00"),
        ]
        #expect(SleepSession.phases(from: segments).count == 1)
        #expect(SleepSession.phases(from: segments, gapHours: 2).count == 2)
    }

    // MARK: - Reihenfolge und leere Eingabe

    @Test("Die Reihenfolge der Eingabe ändert die Phasen nicht")
    func inputOrderDoesNotMatter() {
        let segments = Fixture.nightSegments + [Fixture.napSegment]
        #expect(SleepSession.phases(from: segments.reversed())
                == SleepSession.phases(from: segments))
    }

    @Test("Ohne Abschnitte gibt es keine Phase")
    func noSegmentsNoPhase() {
        #expect(SleepSession.phases(from: []).isEmpty)
    }

    @Test("Nur Wachliegen ergibt keine Phase")
    func onlyAwakeYieldsNoPhase() {
        let phases = SleepSession.phases(from: [
            segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.awake, "2026-10-12T09:00:00+02:00", "2026-10-12T09:20:00+02:00"),
        ])
        #expect(phases.isEmpty)
    }

    // MARK: - Wachabschnitte

    @Test("Ein Wachabschnitt innerhalb einer Phase bleibt in ihr")
    func awakeInsideAPhaseStays() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T01:00:00+02:00"),
            segment(.awake, "2026-10-12T01:00:00+02:00", "2026-10-12T01:10:00+02:00"),
            segment(.core, "2026-10-12T01:10:00+02:00", "2026-10-12T06:00:00+02:00"),
        ])
        #expect(phases.count == 1)
        #expect(phases[0].awakeMinutes == 10)
        #expect(phases[0].wakeCount == 1)
        #expect(phases[0].asleepMinutes == 410)
    }

    @Test("Ein Wachabschnitt allein in der Pause gehört zu keiner Phase")
    func awakeAloneInTheGapIsDropped() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T06:00:00+02:00"),
            segment(.awake, "2026-10-12T08:00:00+02:00", "2026-10-12T08:30:00+02:00"),
            segment(.core, "2026-10-12T13:40:00+02:00", "2026-10-12T14:15:00+02:00"),
        ])
        #expect(phases.count == 2)
        #expect(phases[0].segments.count == 1)
        #expect(phases[0].minutes(.awake) == 0)
        #expect(phases[1].segments.count == 1)
        #expect(phases[1].minutes(.awake) == 0)
    }

    @Test("Langes Wachliegen überbrückt die Pause nicht")
    func longAwakeDoesNotBridgeTheGap() {
        let phases = SleepSession.phases(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.awake, "2026-10-12T02:00:00+02:00", "2026-10-12T06:30:00+02:00"),
            segment(.core, "2026-10-12T06:30:00+02:00", "2026-10-12T08:00:00+02:00"),
        ])
        #expect(phases.count == 2)
        #expect(phases[0].end == date("2026-10-12T02:00:00+02:00"))
        #expect(phases[0].asleepMinutes == 180)
        #expect(phases[1].start == date("2026-10-12T06:30:00+02:00"))
        #expect(phases[1].asleepMinutes == 90)
    }
}

@Suite("Nächte und Nickerchen")
struct SleepNightTests {

    private func date(_ iso: String) -> Date { Fixture.date(iso) }

    private func segment(_ stage: SleepStage, _ from: String, _ to: String) -> SleepSegment {
        Fixture.segment(stage, from, to)
    }

    private func day(_ iso: String) -> Date { BerlinCalendar.startOfDay(Fixture.date(iso)) }

    // MARK: - Der Fall aus der Praxis

    @Test("Der Mittagsschlaf verlängert die Nacht nicht")
    func napDoesNotExtendTheNight() {
        let nights = SleepSession.nights(from: Fixture.nightSegments + [Fixture.napSegment])
        #expect(nights.count == 1)
        let night = nights[0]
        #expect(night.date == day("2026-10-12T12:00:00+02:00"))
        #expect(night.session.start == date("2026-10-11T23:00:00+02:00"))
        #expect(night.session.end == date("2026-10-12T06:00:00+02:00"))
        #expect(night.session.asleepMinutes == 415)
        #expect(night.session.asleepHours == 415.0 / 60)
        #expect(night.session.awakeMinutes == 5)
        #expect(night.naps.count == 1)
        #expect(night.naps[0].start == date("2026-10-12T13:40:00+02:00"))
        #expect(night.naps[0].end == date("2026-10-12T14:15:00+02:00"))
        #expect(night.naps[0].asleepMinutes == 35)
    }

    // MARK: - Der Tag einer Phase

    @Test("Eine Nacht über Mitternacht zählt zum Tag des Aufwachens")
    func nightOverMidnightCountsToTheWakingDay() {
        let nights = SleepSession.nights(from: Fixture.nightSegments)
        #expect(nights.count == 1)
        #expect(nights[0].date == day("2026-10-12T12:00:00+02:00"))
    }

    @Test("Eine Phase, die um 17:59 endet, zählt zu diesem Tag")
    func phaseEndingBeforeSixPmCountsToTheSameDay() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-12T15:00:00+02:00", "2026-10-12T17:59:00+02:00"),
        ])
        #expect(nights.count == 1)
        #expect(nights[0].date == day("2026-10-12T12:00:00+02:00"))
    }

    @Test("Eine Phase, die um 18 Uhr endet, zählt zum nächsten Tag")
    func phaseEndingAtSixPmCountsToTheNextDay() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-12T15:00:00+02:00", "2026-10-12T18:00:00+02:00"),
        ])
        #expect(nights.count == 1)
        #expect(nights[0].date == day("2026-10-13T12:00:00+02:00"))
    }

    // MARK: - Welche Phase die Nacht ist

    @Test("Die Phase mit den meisten Schlafminuten ist die Nacht")
    func mostAsleepMinutesWinsNotTheLongerSpan() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-12T01:00:00+02:00", "2026-10-12T01:50:00+02:00"),
            segment(.awake, "2026-10-12T01:50:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T02:00:00+02:00", "2026-10-12T02:10:00+02:00"),
            segment(.core, "2026-10-12T10:00:00+02:00", "2026-10-12T11:05:00+02:00"),
        ])
        #expect(nights.count == 1)
        #expect(nights[0].session.start == date("2026-10-12T10:00:00+02:00"))
        #expect(nights[0].session.asleepMinutes == 65)
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].start == date("2026-10-12T01:00:00+02:00"))
        #expect(nights[0].naps[0].asleepMinutes == 60)
    }

    @Test("Bei gleicher Schlafzeit gewinnt die frühere Phase")
    func tieGoesToTheEarlierPhase() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-12T01:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T10:00:00+02:00", "2026-10-12T11:00:00+02:00"),
        ])
        #expect(nights.count == 1)
        #expect(nights[0].session.start == date("2026-10-12T01:00:00+02:00"))
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].start == date("2026-10-12T10:00:00+02:00"))
    }

    @Test("Die Nacht bleibt die Nacht, auch wenn das Nickerchen früher beginnt")
    func napBeforeTheNightIsStillTheNap() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-11T18:00:00+02:00", "2026-10-11T18:30:00+02:00"),
        ] + Fixture.nightSegments)
        // Die Nacht ist weiterhin die Nacht — aber sie und das Nickerchen
        // zählen zu verschiedenen Tagen (#209, Tim am 03.11.2026): die Nacht
        // nach ihrem Ende, das Nickerchen nach seinem Beginn.
        #expect(nights.count == 2)
        #expect(nights.map(\.date) == [day("2026-10-11T12:00:00+02:00"),
                                      day("2026-10-12T12:00:00+02:00")])

        #expect(nights[0].session.isEmpty)
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].start == date("2026-10-11T18:00:00+02:00"))
        #expect(nights[0].naps[0].asleepMinutes == 30)

        #expect(nights[1].session.start == date("2026-10-11T23:00:00+02:00"))
        #expect(nights[1].session.asleepMinutes == 415)
        #expect(nights[1].naps.isEmpty)
    }

    // MARK: - Der Tag eines Nickerchens (#209)

    /// Tims Befund vom 03.11.2026: Er schlief abends von 19 bis 20 Uhr,
    /// zusätzlich zur Nacht um 23 Uhr — und das Nickerchen tauchte am
    /// falschen Tag auf. Die 18-Uhr-Regel beantwortet „zu welcher Nacht
    /// gehört diese Phase"; ein Nickerchen läuft über keine Mitternacht und
    /// braucht sie nicht.
    ///
    /// **Die Dart-Seite prüft denselben Tag für den von Hand eingetragenen
    /// Tagschlaf** (`app/test/shell/erholung_tagschlaf_eintrag_test.dart`,
    /// Abendschlaf am 12.10.2026): Beide müssen am 12. landen, nicht am 13.
    ///
    /// Die Uhrzeiten hier halten die Vier-Stunden-Pause ein
    /// (`SleepSession.nightGapHours`) — ohne sie wären Nickerchen und Nacht
    /// gar keine zwei Phasen, und der Test prüfte etwas anderes, als er
    /// behauptet.
    @Test("Ein Nickerchen am Abend zählt zu dem Tag, an dem es beginnt")
    func eveningNapCountsToTheDayItStartsOn() {
        let nights = SleepSession.nights(from: Fixture.nightSegments + [
            // Das Nickerchen: 12.10., 18:30–19:30.
            segment(.core, "2026-10-12T18:30:00+02:00", "2026-10-12T19:30:00+02:00"),
            // Die Nacht danach: 12.10. 23:45 bis 13.10. 06:00.
            segment(.core, "2026-10-12T23:45:00+02:00", "2026-10-13T06:00:00+02:00"),
        ])
        #expect(nights.count == 2)
        #expect(nights.map(\.date) == [day("2026-10-12T12:00:00+02:00"),
                                      day("2026-10-13T12:00:00+02:00")])

        // Das Nickerchen gehört zum 12., nicht zur Nacht des 13.
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].start == date("2026-10-12T18:30:00+02:00"))
        #expect(nights[0].naps[0].asleepMinutes == 60)
        #expect(nights[0].session.asleepMinutes == 415)

        #expect(nights[1].naps.isEmpty)
        #expect(nights[1].session.asleepMinutes == 375)
    }

    @Test("Ein Nickerchen ohne Nacht bekommt trotzdem seinen Tag")
    func napWithoutANightStillGetsItsDay() {
        let nights = SleepSession.nights(from: [
            // 11.10., 19:00–20:00 — an diesem Tag hat die Uhr sonst nichts
            // gesehen. Ohne eigenen Tag fiele das Nickerchen heraus.
            segment(.core, "2026-10-11T19:00:00+02:00", "2026-10-11T20:00:00+02:00"),
            segment(.core, "2026-10-12T00:30:00+02:00", "2026-10-12T07:00:00+02:00"),
        ])
        #expect(nights.count == 2)
        #expect(nights[0].date == day("2026-10-11T12:00:00+02:00"))
        #expect(nights[0].session.isEmpty)
        #expect(nights[0].session.asleepMinutes == 0)
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].asleepMinutes == 60)

        #expect(nights[1].date == day("2026-10-12T12:00:00+02:00"))
        #expect(nights[1].session.asleepMinutes == 390)
        #expect(nights[1].naps.isEmpty)
    }

    @Test("Die Nacht selbst zählt weiter nach ihrem Ende, nicht nach ihrem Beginn")
    func theNightItselfStillCountsByItsEnd() {
        // Beginn 11.10. 23:00, Ende 12.10. 06:00 — der Tag ist der 12.
        let nights = SleepSession.nights(from: Fixture.nightSegments)
        #expect(nights.count == 1)
        #expect(nights[0].date == day("2026-10-12T12:00:00+02:00"))
    }

    @Test("Zwei Nickerchen verschiedener Tage landen nicht im selben Topf")
    func napsOfTwoDaysStayApart() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-11T19:00:00+02:00", "2026-10-11T19:40:00+02:00"),
            segment(.core, "2026-10-12T00:30:00+02:00", "2026-10-12T07:00:00+02:00"),
            segment(.core, "2026-10-12T19:00:00+02:00", "2026-10-12T19:20:00+02:00"),
            segment(.core, "2026-10-13T00:30:00+02:00", "2026-10-13T07:00:00+02:00"),
        ])
        #expect(nights.map(\.date) == [day("2026-10-11T12:00:00+02:00"),
                                      day("2026-10-12T12:00:00+02:00"),
                                      day("2026-10-13T12:00:00+02:00")])
        #expect(nights[0].naps.map(\.asleepMinutes) == [40])
        #expect(nights[1].naps.map(\.asleepMinutes) == [20])
        #expect(nights[2].naps.isEmpty)
    }

    // MARK: - Reihenfolge

    @Test("Mehrere Nickerchen stehen nach Startzeit sortiert")
    func napsAreSortedByStart() {
        let early = segment(.core, "2026-10-12T11:00:00+02:00", "2026-10-12T11:30:00+02:00")
        let late = segment(.rem, "2026-10-12T16:00:00+02:00", "2026-10-12T16:40:00+02:00")
        let nights = SleepSession.nights(from: [late] + Fixture.nightSegments + [early])
        #expect(nights.count == 1)
        #expect(nights[0].session.asleepMinutes == 415)
        #expect(nights[0].naps.count == 2)
        #expect(nights[0].naps[0].start == date("2026-10-12T11:00:00+02:00"))
        #expect(nights[0].naps[1].start == date("2026-10-12T16:00:00+02:00"))
    }

    @Test("Die Nächte stehen älteste zuerst")
    func nightsAreSortedOldestFirst() {
        let first = segment(.core, "2026-10-09T23:00:00+02:00", "2026-10-10T06:00:00+02:00")
        let second = segment(.core, "2026-10-10T23:00:00+02:00", "2026-10-11T06:00:00+02:00")
        let third = segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T06:00:00+02:00")
        let nights = SleepSession.nights(from: [third, first, second])
        #expect(nights.map(\.date) == [day("2026-10-10T12:00:00+02:00"),
                                      day("2026-10-11T12:00:00+02:00"),
                                      day("2026-10-12T12:00:00+02:00")])
        #expect(nights.allSatisfy { $0.naps.isEmpty })
    }

    // MARK: - Nichts und nur Wachliegen

    @Test("Eine Nacht ohne Nickerchen hat eine leere Liste")
    func nightWithoutNapsHasNoNaps() {
        let nights = SleepSession.nights(from: Fixture.nightSegments)
        #expect(nights.count == 1)
        #expect(nights[0].naps.isEmpty)
    }

    @Test("Ohne Abschnitte gibt es keine Nacht")
    func noSegmentsNoNight() {
        #expect(SleepSession.nights(from: []).isEmpty)
    }

    @Test("Nur Wachliegen ergibt keine Nacht")
    func onlyAwakeYieldsNoNight() {
        let nights = SleepSession.nights(from: [
            segment(.awake, "2026-10-11T23:00:00+02:00", "2026-10-11T23:30:00+02:00"),
            segment(.awake, "2026-10-12T09:00:00+02:00", "2026-10-12T09:20:00+02:00"),
        ])
        #expect(nights.isEmpty)
    }

    @Test("Ein Wachabschnitt in der Pause geht in keine Nacht ein")
    func awakeInTheGapBelongsNowhere() {
        let nights = SleepSession.nights(from: [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T06:00:00+02:00"),
            segment(.awake, "2026-10-12T08:00:00+02:00", "2026-10-12T08:30:00+02:00"),
            Fixture.napSegment,
        ])
        #expect(nights.count == 1)
        #expect(nights[0].session.segments.count == 1)
        #expect(nights[0].session.minutes(.awake) == 0)
        #expect(nights[0].naps.count == 1)
        #expect(nights[0].naps[0].segments.count == 1)
        #expect(nights[0].naps[0].minutes(.awake) == 0)
    }

    // MARK: - Die Grenze

    @Test("Die Grenze lässt sich auch für Nächte verschieben")
    func gapCanBeOverriddenForNights() {
        let segments = [
            segment(.core, "2026-10-11T23:00:00+02:00", "2026-10-12T02:00:00+02:00"),
            segment(.core, "2026-10-12T05:00:00+02:00", "2026-10-12T07:00:00+02:00"),
        ]
        let whole = SleepSession.nights(from: segments)
        #expect(whole.count == 1)
        #expect(whole[0].session.asleepMinutes == 300)
        #expect(whole[0].naps.isEmpty)

        let split = SleepSession.nights(from: segments, gapHours: 2)
        #expect(split.count == 1)
        #expect(split[0].session.asleepMinutes == 180)
        #expect(split[0].naps.count == 1)
        #expect(split[0].naps[0].asleepMinutes == 120)
    }

    // MARK: - Der Bau einer Nacht

    @Test("Eine Nacht lässt sich ohne Nickerchen bauen")
    func nightIsConstructibleWithoutNaps() {
        let night = SleepNight(date: day("2026-10-12T12:00:00+02:00"),
                               session: SleepSession(segments: Fixture.nightSegments))
        #expect(night.naps.isEmpty)
        #expect(night.session.asleepMinutes == 415)
    }
}
