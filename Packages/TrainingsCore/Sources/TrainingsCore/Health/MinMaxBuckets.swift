import Foundation

public struct QuantitySample: Equatable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct MinMaxBucket: Equatable, Sendable, Identifiable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public let min: Double
    public let max: Double
    public let count: Int

    public init(start: Date, end: Date, min: Double, max: Double, count: Int) {
        self.start = start
        self.end = end
        self.min = min
        self.max = max
        self.count = count
    }
}

/// Herz- und Atemfrequenz im Schlaf als Spanne je Zeitabschnitt — die
/// Darstellung aus Apple Health. Eine Linie aus Einzelmessungen wäre bei
/// unregelmäßigen Messzeitpunkten irreführend.
public enum MinMaxBuckets {

    public static func buckets(of samples: [QuantitySample], from: Date, through: Date,
                               count: Int) -> [MinMaxBucket] {
        guard count > 0, through > from else { return [] }

        let span = through.timeIntervalSince(from)
        let length = span / Double(count)
        var collected: [Int: (min: Double, max: Double, count: Int)] = [:]

        for sample in samples {
            let offset = sample.date.timeIntervalSince(from)
            guard offset >= 0, offset <= span else { continue }
            // Ein Wert genau auf einer inneren Grenze gehört in den späteren
            // Abschnitt, einer genau am Ende in den letzten.
            let index = Swift.min(Int(offset / length), count - 1)
            if let existing = collected[index] {
                collected[index] = (Swift.min(existing.min, sample.value),
                                    Swift.max(existing.max, sample.value),
                                    existing.count + 1)
            } else {
                collected[index] = (sample.value, sample.value, 1)
            }
        }

        return collected.keys.sorted().map { index in
            let start = from.addingTimeInterval(length * Double(index))
            return MinMaxBucket(start: start,
                                end: start.addingTimeInterval(length),
                                min: collected[index]!.min,
                                max: collected[index]!.max,
                                count: collected[index]!.count)
        }
    }
}
