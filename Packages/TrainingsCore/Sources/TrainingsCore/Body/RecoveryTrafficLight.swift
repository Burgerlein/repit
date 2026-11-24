import Foundation

/// Die vier Werte einer Nacht. `nil` heißt „kein Wert“ — ob nichts
/// aufgezeichnet wurde oder der Lesezugriff fehlt, verrät HealthKit nicht.
public struct RecoveryReading: Equatable, Sendable {
    public var sleepHours: Double?
    public var restingHeartRate: Double?
    public var hrv: Double?
    public var respiratoryRate: Double?

    public init(sleepHours: Double? = nil, restingHeartRate: Double? = nil,
                hrv: Double? = nil, respiratoryRate: Double? = nil) {
        self.sleepHours = sleepHours
        self.restingHeartRate = restingHeartRate
        self.hrv = hrv
        self.respiratoryRate = respiratoryRate
    }
}

/// Der eigene Normalbereich: Mediane der letzten 30 Tage.
public struct RecoveryBaseline: Equatable, Sendable {
    public var sleepHours: Double?
    public var restingHeartRate: Double?
    public var hrv: Double?
    public var respiratoryRate: Double?

    public init(sleepHours: Double? = nil, restingHeartRate: Double? = nil,
                hrv: Double? = nil, respiratoryRate: Double? = nil) {
        self.sleepHours = sleepHours
        self.restingHeartRate = restingHeartRate
        self.hrv = hrv
        self.respiratoryRate = respiratoryRate
    }
}

public enum RecoveryMetric: String, CaseIterable, Sendable {
    case sleep, restingHeartRate, hrv, respiratoryRate
}

public enum RecoveryVerdict: Equatable, Sendable {
    /// kein Warnsignal
    case calm
    /// genau ein Warnsignal
    case watch
    /// zwei oder mehr Warnsignale
    case stressed
    /// keiner der vier Werte liegt vor
    case noData
    /// Erholung nach der OP: es wird nicht bewertet
    case postOperative
}

public struct RecoveryEvaluation: Equatable, Sendable {
    public let verdict: RecoveryVerdict
    /// Immer in der Reihenfolge Schlaf, Ruhepuls, HRV, Atemfrequenz.
    public let signals: [RecoveryMetric]
    /// Wie viele der vier Werte vorliegen.
    public let measuredCount: Int

    public init(verdict: RecoveryVerdict, signals: [RecoveryMetric], measuredCount: Int) {
        self.verdict = verdict
        self.signals = signals
        self.measuredCount = measuredCount
    }
}

/// Vergleicht die Nacht mit dem eigenen Median der letzten 30 Tage.
/// Grobe Orientierung, keine medizinische Bewertung — die Schwellen stehen
/// in `docs/SPEC.md`, Abschnitt 4.6.
public enum RecoveryTrafficLight {

    /// Feste Schwelle, unabhängig vom Median und vom Schlafziel.
    public static let minimumSleepHours = 6.0
    public static let restingHeartRateMargin = 5.0
    public static let hrvDropShare = 0.2
    public static let respiratoryRateMargin = 1.5

    public static func evaluate(reading: RecoveryReading,
                                baseline: RecoveryBaseline,
                                isPostOperative: Bool = false) -> RecoveryEvaluation {
        let measured = [reading.sleepHours, reading.restingHeartRate,
                        reading.hrv, reading.respiratoryRate].compactMap { $0 }.count

        guard !isPostOperative else {
            return RecoveryEvaluation(verdict: .postOperative, signals: [], measuredCount: measured)
        }
        guard measured > 0 else {
            return RecoveryEvaluation(verdict: .noData, signals: [], measuredCount: 0)
        }

        var signals: [RecoveryMetric] = []
        if let sleep = reading.sleepHours, sleep < minimumSleepHours {
            signals.append(.sleep)
        }
        if let value = reading.restingHeartRate, let median = baseline.restingHeartRate,
           value >= median + restingHeartRateMargin {
            signals.append(.restingHeartRate)
        }
        if let value = reading.hrv, let median = baseline.hrv,
           value <= median * (1 - hrvDropShare) {
            signals.append(.hrv)
        }
        if let value = reading.respiratoryRate, let median = baseline.respiratoryRate,
           value >= median + respiratoryRateMargin {
            signals.append(.respiratoryRate)
        }

        let verdict: RecoveryVerdict = switch signals.count {
        case 0: .calm
        case 1: .watch
        default: .stressed
        }
        return RecoveryEvaluation(verdict: verdict, signals: signals, measuredCount: measured)
    }
}
