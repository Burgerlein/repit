import Foundation

public enum SleepStage: String, CaseIterable, Sendable {
    case awake, rem, core, deep, unspecified

    /// Alles außer `awake`. „Unspecified" liefern ältere Uhren und das iPhone,
    /// es ist Schlaf ohne Phasenangabe.
    public var isAsleep: Bool { self != .awake }
}

public struct SleepSegment: Equatable, Sendable {
    public let stage: SleepStage
    public let start: Date
    public let end: Date

    public init(stage: SleepStage, start: Date, end: Date) {
        self.stage = stage
        self.start = start
        self.end = end
    }

    public var minutes: Double { max(0, end.timeIntervalSince(start)) / 60 }
}

/// Eine Nacht als Folge von Abschnitten. Wachliegen am Anfang und am Ende
/// gehört nicht zur Nacht — gezählt wird vom ersten bis zum letzten
/// Schlafabschnitt.
public struct SleepSession: Equatable, Sendable {

    public let segments: [SleepSegment]

    public init(segments: [SleepSegment]) {
        self.segments = segments.sorted { $0.start < $1.start }
    }

    public var isEmpty: Bool { segments.isEmpty }

    private var asleepSegments: [SleepSegment] { segments.filter { $0.stage.isAsleep } }

    public var start: Date? { asleepSegments.first?.start }

    public var end: Date? { asleepSegments.map(\.end).max() }

    public var asleepMinutes: Double { asleepSegments.map(\.minutes).reduce(0, +) }

    public var asleepHours: Double { asleepMinutes / 60 }

    /// Nur das Wachliegen zwischen erstem und letztem Schlafabschnitt.
    private var interruptions: [SleepSegment] {
        guard let start, let end else { return [] }
        return segments.filter { $0.stage == .awake && $0.start >= start && $0.end <= end }
    }

    public var awakeMinutes: Double { interruptions.map(\.minutes).reduce(0, +) }

    public var wakeCount: Int { interruptions.count }

    /// Summe über alle Abschnitte dieser Phase, auch vor `start` und nach `end`.
    public func minutes(_ stage: SleepStage) -> Double {
        segments.filter { $0.stage == stage }.map(\.minutes).reduce(0, +)
    }
}

/// Eine Nacht mit dem Tag, zu dem sie zählt: dem Tag des Aufwachens.
public struct SleepNight: Equatable, Sendable {
    public let date: Date
    public let session: SleepSession
    /// Tagschlaf desselben Kalendertags — eingeordnet nach seinem Beginn
    /// (#209). Zählt nicht in `session`.
    public let naps: [SleepSession]

    public init(date: Date, session: SleepSession, naps: [SleepSession] = []) {
        self.date = date
        self.session = session
        self.naps = naps
    }
}

public extension SleepSession {

    /// Höchstens so lange darf die Pause zwischen zwei Schlafabschnitten sein,
    /// damit sie noch zur selben Phase gehören. Vier Stunden sind an 124
    /// eigenen Nächten gemessen: Bei drei zerfällt eine real gestörte Nacht,
    /// bei sechs verschmilzt der einzige echte Mittagsschlaf mit der Nacht.
    static let nightGapHours = 4.0

    /// Zerlegt rohe HealthKit-Abschnitte in Schlafphasen. HealthKit kennt
    /// keinen Nickerchen-Typ, also entscheidet allein die Lücke.
    static func phases(from segments: [SleepSegment],
                       gapHours: Double = nightGapHours) -> [SleepSession] {
        SleepGrouping.phases(from: segments, gapHours: gapHours)
    }

    /// Je Tag eine Nacht und ihren Tagschlaf. Der Tag **der Nacht** kommt vom
    /// Aufwachen, nicht vom Kalender — eine Nacht läuft über Mitternacht. Ein
    /// Nickerchen tut das nicht und zählt deshalb nach dem Kalendertag, an dem
    /// es beginnt (#209).
    static func nights(from segments: [SleepSegment],
                       gapHours: Double = nightGapHours) -> [SleepNight] {
        SleepGrouping.nights(from: segments, gapHours: gapHours)
    }
}

/// Die Gruppierung roher Abschnitte zu Phasen, Nächten und Tagschlaf.
/// Eigener Typ, damit `SleepSession` die Auswertung einer einzelnen Nacht
/// bleibt und nicht auch noch deren Abgrenzung.
enum SleepGrouping {

    /// Ab dieser Stunde zählt eine **Nacht** zum Folgetag. Wer abends
    /// einschläft, meint die kommende Nacht.
    ///
    /// **Nur für Nächte** (#209, Tims Entscheidung vom 03.11.2026). Die Regel
    /// beantwortet „zu welcher Nacht gehört diese Phase"; ein Nickerchen
    /// läuft über keine Mitternacht und braucht sie nicht. Es zählt nach dem
    /// Kalendertag, an dem es stattfindet — ein Nickerchen von 19 bis 20 Uhr
    /// am Montag ist eines vom Montag, nicht vom Dienstag.
    private static let nextDayHour = 18

    /// Erster Schlafbeginn bis spätestes Schlafende, plus die Abschnitte.
    private struct Phase {
        var start: Date
        var end: Date
        var segments: [SleepSegment]
    }

    static func phases(from segments: [SleepSegment], gapHours: Double) -> [SleepSession] {
        let asleep = segments.filter { $0.stage.isAsleep }.sorted { $0.start < $1.start }
        guard !asleep.isEmpty else { return [] }

        let gap = gapHours * 3600
        var phases: [Phase] = []
        for segment in asleep {
            // Gemessen wird gegen das späteste Ende der Phase, nicht gegen das
            // des letzten Abschnitts — Abschnitte dürfen sich überlappen.
            if var current = phases.last, segment.start.timeIntervalSince(current.end) <= gap {
                current.end = max(current.end, segment.end)
                current.segments.append(segment)
                phases[phases.count - 1] = current
            } else {
                phases.append(Phase(start: segment.start, end: segment.end, segments: [segment]))
            }
        }

        // Wachliegen direkt vor dem Einschlafen und nach dem Aufwachen gehört
        // zur Phase, das Hypnogramm zeigt es. Ein Wachblock, der die ganze
        // Pause füllt, berührt beide Nachbarn und gehört zu keinem von beiden —
        // sonst bläht er eine Phase um Stunden auf, die niemand geschlafen hat.
        for awake in segments where awake.stage == .awake {
            let touched = phases.indices.filter {
                awake.start <= phases[$0].end && awake.end >= phases[$0].start
            }
            guard touched.count == 1 else { continue }
            phases[touched[0]].segments.append(awake)
        }

        return phases.map { SleepSession(segments: $0.segments) }
    }

    /// Je Tag eine Nacht und ihren Tagschlaf.
    ///
    /// **Zwei verschiedene Tagesfragen** (#209): Welche Phase die Nacht eines
    /// Tages ist, entscheidet sich auf der 18-Uhr-Skala — dort gehören das
    /// Einschlafen am Abend und das Aufwachen am Morgen zusammen. Jede andere
    /// Phase ist ein Nickerchen und zählt nach dem Kalendertag, an dem sie
    /// **beginnt**. Beides in einem Schritt zu beantworten ging nicht: Ein
    /// Nickerchen um 19 Uhr landete über die 18-Uhr-Regel beim Folgetag, der
    /// von Hand eingetragene Tagschlaf desselben Schlafs aber beim heutigen —
    /// dieselbe Stunde, zwei Tage.
    ///
    /// Ein Tag, der dadurch nur Nickerchen bekommt, entsteht **trotzdem** —
    /// mit einer Nacht ohne Abschnitte. Sonst fiele das Nickerchen heraus,
    /// und das wäre Datenverlust statt einer Zuordnung.
    static func nights(from segments: [SleepSegment], gapHours: Double) -> [SleepNight] {
        var byDay: [Date: [SleepSession]] = [:]
        for phase in phases(from: segments, gapHours: gapHours) {
            guard let end = phase.end else { continue }
            byDay[day(ofPhaseEndingAt: end), default: []].append(phase)
        }

        var nightOf: [Date: SleepSession] = [:]
        var napsOf: [Date: [SleepSession]] = [:]
        for (date, sessions) in byDay {
            // Die meistgeschlafene Phase ist die Nacht, bei Gleichstand die
            // frühere. Nicht die längste Spanne: Eine kurze Nacht mit viel
            // Wachliegen ist kein Nickerchen.
            let ranked = sessions.sorted { lhs, rhs in
                lhs.asleepMinutes == rhs.asleepMinutes
                    ? start(of: lhs) < start(of: rhs)
                    : lhs.asleepMinutes > rhs.asleepMinutes
            }
            nightOf[date] = ranked[0]
            for nap in ranked.dropFirst() {
                napsOf[day(ofNapStartingAt: start(of: nap)), default: []].append(nap)
            }
        }

        let dates = Set(nightOf.keys).union(napsOf.keys).sorted()
        return dates.map { date in
            SleepNight(date: date,
                       session: nightOf[date] ?? SleepSession(segments: []),
                       naps: napsOf[date, default: []].sorted { start(of: $0) < start(of: $1) })
        }
    }

    /// Jede Phase hat einen Schlafabschnitt, also auch einen Beginn.
    private static func start(of session: SleepSession) -> Date {
        session.start ?? .distantPast
    }

    private static func day(ofPhaseEndingAt end: Date) -> Date {
        let calendar = BerlinCalendar.calendar
        let day = BerlinCalendar.startOfDay(end)
        guard calendar.component(.hour, from: end) >= nextDayHour else { return day }
        return calendar.date(byAdding: .day, value: 1, to: day) ?? day
    }

    /// Der Kalendertag, an dem das Nickerchen beginnt — ohne 18-Uhr-Regel
    /// (#209). Über [BerlinCalendar], nicht über eine selbst gepaarte
    /// UTC-Zeit: Die Tagesgrenze verschiebt sich zweimal im Jahr.
    private static func day(ofNapStartingAt start: Date) -> Date {
        BerlinCalendar.startOfDay(start)
    }
}
