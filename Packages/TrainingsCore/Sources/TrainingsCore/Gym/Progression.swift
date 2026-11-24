import Foundation

public struct CompletedSet: Equatable, Sendable, Codable {
    /// Negativ bedeutet Unterstützung: −27 sind 27 kg Hilfe von der Maschine.
    public let weight: Double
    /// Bei Zeitübungen Sekunden.
    public let reps: Int

    public init(weight: Double, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
}

/// Der Vorschlag trägt nur Zahlen. Wie er formuliert wird, entscheidet die
/// Ansicht — in TrainingsCore stehen keine Nutzertexte.
public enum Suggestion: Equatable, Sendable {
    case firstTime(targetReps: Int)
    case increase(toWeight: Double, by: Double, targetReps: Int)
    case hold(atWeight: Double, targetReps: Int)
    case deload(toWeight: Double, fromWeight: Double, targetReps: Int)
    case increaseTime(toSeconds: Int)
    case harderVariant
}

/// Double Progression nach SPEC 4.4.
public enum Progression {

    /// - Parameter history: Sitzungen, **neueste zuerst**. Sätze mit null
    ///   Wiederholungen gelten als nicht ausgeführt und werden verworfen.
    public static func suggest(_ exercise: Exercise, history: [[CompletedSet]]) -> Suggestion {
        let sessions = history.map { $0.filter { $0.reps > 0 } }.filter { !$0.isEmpty }
        guard let last = sessions.first else {
            return exercise.isTimed
                ? .increaseTime(toSeconds: exercise.repLow)
                : .firstTime(targetReps: exercise.repLow)
        }

        if exercise.isTimed {
            let shortest = last.map(\.reps).min() ?? exercise.repLow
            if shortest >= exercise.repHigh { return .harderVariant }
            let next = min(shortest + Int(exercise.increment), exercise.repHigh)
            return .increaseTime(toSeconds: next)
        }

        // Der schwerste Satz. Bei Unterstützung ist der näher an null, und
        // genau das leistet max() auch für negative Werte: −24,5 > −27.
        let top = last.map(\.weight).max() ?? 0
        let atTop = last.filter { $0.weight == top }

        if last.allSatisfy({ $0.reps >= exercise.repHigh }) {
            return .increase(toWeight: top + exercise.increment,
                             by: exercise.increment,
                             targetReps: exercise.repLow)
        }

        if atTop.contains(where: { $0.reps < exercise.repLow }),
           belowLow(sessions.dropFirst().first, exercise: exercise) {
            return .deload(toWeight: deloadWeight(from: top, increment: exercise.increment),
                           fromWeight: top,
                           targetReps: exercise.repLow)
        }

        // Halten und eine Wiederholung mehr anstreben, gedeckelt auf die
        // obere Grenze.
        let weakest = atTop.map(\.reps).min() ?? exercise.repLow
        return .hold(atWeight: top, targetReps: min(weakest + 1, exercise.repHigh))
    }

    private static func belowLow(_ session: [CompletedSet]?, exercise: Exercise) -> Bool {
        guard let session, !session.isEmpty else { return false }
        guard let top = session.map(\.weight).max() else { return false }
        return session.contains { $0.weight == top && $0.reps < exercise.repLow }
    }

    /// Zehn Prozent leichter. Bei Unterstützung heißt leichter: **mehr**
    /// Hilfe, der Betrag wächst also. 0,9 auf einen negativen Wert anzuwenden
    /// würde die Übung schwerer machen — genau falsch herum.
    private static func deloadWeight(from weight: Double, increment: Double) -> Double {
        let factor = weight >= 0 ? 0.9 : 1.1
        return round(weight * factor, to: increment)
    }

    private static func round(_ value: Double, to increment: Double) -> Double {
        guard increment > 0 else { return value }
        return (value / increment).rounded() * increment
    }
}
