import Foundation
import Testing
@testable import TrainingsCore

@Suite("Min-Max-Abschnitte")
struct MinMaxBucketsTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func sample(_ iso: String, _ value: Double) -> QuantitySample {
        QuantitySample(date: date(iso), value: value)
    }

    /// Die Spanne für die meisten Fälle: 22:00 bis 06:00, also acht Stunden.
    /// Mit acht Abschnitten ist jeder genau eine Stunde lang.
    private var spanStart: Date { date("2026-10-11T22:00:00+02:00") }
    private var spanEnd: Date { date("2026-10-12T06:00:00+02:00") }

    // MARK: - Leeres Ergebnis

    @Test("Ohne Abschnitte gibt es kein Ergebnis")
    func zeroBuckets() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-11T23:00:00+02:00", 60)],
                                      from: spanStart, through: spanEnd, count: 0)
        #expect(b.isEmpty)
    }

    @Test("Eine negative Anzahl ergibt kein Ergebnis")
    func negativeBucketCount() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-11T23:00:00+02:00", 60)],
                                      from: spanStart, through: spanEnd, count: -3)
        #expect(b.isEmpty)
    }

    @Test("Eine Spanne ohne Länge ergibt kein Ergebnis")
    func emptySpan() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-11T22:00:00+02:00", 60)],
                                      from: spanStart, through: spanStart, count: 8)
        #expect(b.isEmpty)
    }

    @Test("Eine rückwärts laufende Spanne ergibt kein Ergebnis")
    func reversedSpan() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-11T23:00:00+02:00", 60)],
                                      from: spanEnd, through: spanStart, count: 8)
        #expect(b.isEmpty)
    }

    @Test("Ohne Messwerte gibt es keine Abschnitte")
    func noSamples() {
        let b = MinMaxBuckets.buckets(of: [], from: spanStart, through: spanEnd, count: 8)
        #expect(b.isEmpty)
    }

    // MARK: - Grenzen der Spanne

    @Test("Messwerte vor dem Beginn zählen nicht")
    func samplesBeforeStartAreIgnored() {
        let samples = [sample("2026-10-11T21:59:00+02:00", 99),
                       sample("2026-10-11T22:30:00+02:00", 60)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(b[0].end == date("2026-10-11T23:00:00+02:00"))
        #expect(b[0].min == 60)
        #expect(b[0].max == 60)
        #expect(b[0].count == 1)
    }

    @Test("Messwerte nach dem Ende zählen nicht")
    func samplesAfterEndAreIgnored() {
        let samples = [sample("2026-10-12T05:30:00+02:00", 55),
                       sample("2026-10-12T06:01:00+02:00", 99)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-12T05:00:00+02:00"))
        #expect(b[0].end == date("2026-10-12T06:00:00+02:00"))
        #expect(b[0].min == 55)
        #expect(b[0].max == 55)
        #expect(b[0].count == 1)
    }

    @Test("Ein Wert genau auf dem Beginn gehört zum ersten Abschnitt")
    func sampleExactlyAtStart() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-11T22:00:00+02:00", 50)],
                                      from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(b[0].end == date("2026-10-11T23:00:00+02:00"))
        #expect(b[0].min == 50)
        #expect(b[0].count == 1)
    }

    // Review Focus: eine innere Grenze gehört nach hinten, das Ende nach vorne.
    @Test("Ein Wert genau auf einer inneren Grenze gehört zum späteren Abschnitt")
    func sampleOnInnerBoundaryBelongsToTheLaterBucket() {
        let samples = [sample("2026-10-11T22:30:00+02:00", 60),
                       sample("2026-10-11T23:00:00+02:00", 70)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 2)
        #expect(b[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(b[0].min == 60)
        #expect(b[0].max == 60)
        #expect(b[0].count == 1)
        #expect(b[1].start == date("2026-10-11T23:00:00+02:00"))
        #expect(b[1].end == date("2026-10-12T00:00:00+02:00"))
        #expect(b[1].min == 70)
        #expect(b[1].max == 70)
        #expect(b[1].count == 1)
    }

    @Test("Ein Wert genau auf dem Ende gehört zum letzten Abschnitt")
    func sampleExactlyAtEndBelongsToTheLastBucket() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-12T06:00:00+02:00", 50)],
                                      from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-12T05:00:00+02:00"))
        #expect(b[0].end == date("2026-10-12T06:00:00+02:00"))
        #expect(b[0].min == 50)
        #expect(b[0].max == 50)
        #expect(b[0].count == 1)
    }

    // MARK: - Grenzen der Abschnitte

    // Review Focus: die Grenzen kommen aus dem Raster, nicht aus den Messwerten.
    @Test("Die Grenzen eines Abschnitts sind die des Rasters, nicht die der Messwerte")
    func bucketBoundsComeFromTheGrid() {
        let samples = [sample("2026-10-11T22:17:00+02:00", 64),
                       sample("2026-10-11T22:49:00+02:00", 58)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(b[0].end == date("2026-10-11T23:00:00+02:00"))
        #expect(b[0].min == 58)
        #expect(b[0].max == 64)
        #expect(b[0].count == 2)
    }

    @Test("Der Beginn des Abschnitts ist seine Kennung")
    func idIsTheStart() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-12T01:30:00+02:00", 61)],
                                      from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].id == b[0].start)
        #expect(b[0].id == date("2026-10-12T01:00:00+02:00"))
    }

    // MARK: - Einzelne Messwerte

    @Test("Ein einzelner Messwert ergibt einen Abschnitt mit gleichem Minimum und Maximum")
    func singleSample() {
        let b = MinMaxBuckets.buckets(of: [sample("2026-10-12T01:30:00+02:00", 61.5)],
                                      from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-12T01:00:00+02:00"))
        #expect(b[0].end == date("2026-10-12T02:00:00+02:00"))
        #expect(b[0].min == 61.5)
        #expect(b[0].max == 61.5)
        #expect(b[0].count == 1)
    }

    @Test("Je Abschnitt zählen der kleinste und der größte Wert")
    func minAndMaxPerBucket() {
        let samples = [sample("2026-10-11T22:05:00+02:00", 62),
                       sample("2026-10-11T22:20:00+02:00", 58),
                       sample("2026-10-11T22:55:00+02:00", 71)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].min == 58)
        #expect(b[0].max == 71)
        #expect(b[0].count == 3)
    }

    @Test("Alle Werte im selben Abschnitt ergeben einen einzigen Abschnitt")
    func allSamplesInOneBucket() {
        let samples = [sample("2026-10-12T03:01:00+02:00", 50),
                       sample("2026-10-12T03:30:00+02:00", 48),
                       sample("2026-10-12T03:59:00+02:00", 53)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].start == date("2026-10-12T03:00:00+02:00"))
        #expect(b[0].end == date("2026-10-12T04:00:00+02:00"))
        #expect(b[0].min == 48)
        #expect(b[0].max == 53)
        #expect(b[0].count == 3)
    }

    // MARK: - Sortierung

    @Test("Unsortierte Eingaben liefern dasselbe Ergebnis wie sortierte")
    func unsortedInputMatchesSorted() {
        let sorted = [sample("2026-10-11T22:30:00+02:00", 60),
                      sample("2026-10-11T23:30:00+02:00", 65),
                      sample("2026-10-12T02:30:00+02:00", 70)]
        let shuffled = [sorted[2], sorted[0], sorted[1]]
        let fromSorted = MinMaxBuckets.buckets(of: sorted, from: spanStart, through: spanEnd, count: 8)
        let fromShuffled = MinMaxBuckets.buckets(of: shuffled, from: spanStart, through: spanEnd, count: 8)
        #expect(fromSorted == fromShuffled)
        #expect(fromShuffled.count == 3)
        #expect(fromShuffled[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(fromShuffled[1].start == date("2026-10-11T23:00:00+02:00"))
        #expect(fromShuffled[2].start == date("2026-10-12T02:00:00+02:00"))
    }

    @Test("Auch innerhalb eines Abschnitts spielt die Reihenfolge keine Rolle")
    func unsortedInputWithinOneBucket() {
        let samples = [sample("2026-10-11T22:55:00+02:00", 71),
                       sample("2026-10-11T22:05:00+02:00", 62),
                       sample("2026-10-11T22:20:00+02:00", 58)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].min == 58)
        #expect(b[0].max == 71)
        #expect(b[0].count == 3)
    }

    @Test("Das Ergebnis ist aufsteigend sortiert")
    func resultIsSortedAscending() {
        let samples = [sample("2026-10-12T04:30:00+02:00", 52),
                       sample("2026-10-11T22:30:00+02:00", 60),
                       sample("2026-10-12T01:30:00+02:00", 55)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.map(\.start) == [date("2026-10-11T22:00:00+02:00"),
                                   date("2026-10-12T01:00:00+02:00"),
                                   date("2026-10-12T04:00:00+02:00")])
    }

    // MARK: - Werte

    @Test("Negative Werte sind erlaubt")
    func negativeValues() {
        let samples = [sample("2026-10-11T22:30:00+02:00", -5),
                       sample("2026-10-11T22:40:00+02:00", -1)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].min == -5)
        #expect(b[0].max == -1)
        #expect(b[0].count == 2)
    }

    @Test("Nullwerte sind erlaubt")
    func zeroValues() {
        let samples = [sample("2026-10-11T22:30:00+02:00", 0),
                       sample("2026-10-11T22:40:00+02:00", 0)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].min == 0)
        #expect(b[0].max == 0)
        #expect(b[0].count == 2)
    }

    @Test("Negativ und null im selben Abschnitt ergeben die richtige Spanne")
    func negativeAndZeroTogether() {
        let samples = [sample("2026-10-11T22:30:00+02:00", -3),
                       sample("2026-10-11T22:40:00+02:00", 0),
                       sample("2026-10-11T22:50:00+02:00", 2)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 1)
        #expect(b[0].min == -3)
        #expect(b[0].max == 2)
        #expect(b[0].count == 3)
    }

    // MARK: - Lücken

    // Review Focus: leere Abschnitte fallen weg, die übrigen behalten ihr Raster.
    @Test("Leere Abschnitte fallen weg, die übrigen behalten ihre Grenzen")
    func gapsDropEmptyBuckets() {
        let samples = [sample("2026-10-11T22:30:00+02:00", 60),
                       sample("2026-10-11T23:30:00+02:00", 61),
                       sample("2026-10-12T03:30:00+02:00", 58),
                       sample("2026-10-12T04:30:00+02:00", 59)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 4)
        #expect(b.map(\.start) == [date("2026-10-11T22:00:00+02:00"),
                                   date("2026-10-11T23:00:00+02:00"),
                                   date("2026-10-12T03:00:00+02:00"),
                                   date("2026-10-12T04:00:00+02:00")])
        #expect(b.map(\.end) == [date("2026-10-11T23:00:00+02:00"),
                                 date("2026-10-12T00:00:00+02:00"),
                                 date("2026-10-12T04:00:00+02:00"),
                                 date("2026-10-12T05:00:00+02:00")])
        #expect(b.map(\.min) == [60, 61, 58, 59])
        #expect(b.map(\.count) == [1, 1, 1, 1])
    }

    @Test("Eine Lücke mitten in der Nacht verschiebt die späteren Abschnitte nicht")
    func gapDoesNotShiftLaterBuckets() {
        let samples = [sample("2026-10-11T22:30:00+02:00", 60),
                       sample("2026-10-12T05:30:00+02:00", 50)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 8)
        #expect(b.count == 2)
        #expect(b[1].start == date("2026-10-12T05:00:00+02:00"))
        #expect(b[1].end == date("2026-10-12T06:00:00+02:00"))
    }

    // MARK: - Anzahl der Abschnitte

    @Test("Ein einziger Abschnitt umfasst die ganze Spanne")
    func singleBucketCoversTheWholeSpan() {
        let samples = [sample("2026-10-11T22:30:00+02:00", 60),
                       sample("2026-10-12T03:00:00+02:00", 80),
                       sample("2026-10-12T05:59:00+02:00", 55)]
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 1)
        #expect(b.count == 1)
        #expect(b[0].start == spanStart)
        #expect(b[0].end == spanEnd)
        #expect(b[0].min == 55)
        #expect(b[0].max == 80)
        #expect(b[0].count == 3)
    }

    @Test("Gleichmäßig verteilte Werte füllen alle sechzehn Abschnitte")
    func sixteenBucketsEvenlyFilled() {
        // Acht Stunden durch sechzehn: jeder Abschnitt ist eine halbe Stunde.
        // Je ein Messwert fünf Minuten nach Beginn des Abschnitts.
        let samples = (0..<16).map {
            QuantitySample(date: spanStart.addingTimeInterval(Double($0) * 1_800 + 300),
                           value: 60 + Double($0))
        }
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 16)
        #expect(b.count == 16)
        #expect(b[0].start == date("2026-10-11T22:00:00+02:00"))
        #expect(b[0].end == date("2026-10-11T22:30:00+02:00"))
        #expect(b[0].min == 60)
        #expect(b[0].max == 60)
        #expect(b[0].count == 1)
        #expect(b[7].start == date("2026-10-12T01:30:00+02:00"))
        #expect(b[7].end == date("2026-10-12T02:00:00+02:00"))
        #expect(b[7].min == 67)
        #expect(b[15].start == date("2026-10-12T05:30:00+02:00"))
        #expect(b[15].end == date("2026-10-12T06:00:00+02:00"))
        #expect(b[15].min == 75)
        #expect(b[15].max == 75)
    }

    @Test("Zwei Werte je Abschnitt ergeben eine echte Spanne")
    func sixteenBucketsWithTwoSamplesEach() {
        let samples = (0..<16).flatMap { i -> [QuantitySample] in
            let base = spanStart.addingTimeInterval(Double(i) * 1_800)
            return [QuantitySample(date: base.addingTimeInterval(300), value: 60 + Double(i)),
                    QuantitySample(date: base.addingTimeInterval(1_200), value: 50 + Double(i))]
        }
        let b = MinMaxBuckets.buckets(of: samples, from: spanStart, through: spanEnd, count: 16)
        #expect(b.count == 16)
        #expect(b[0].min == 50)
        #expect(b[0].max == 60)
        #expect(b[0].count == 2)
        #expect(b[15].min == 65)
        #expect(b[15].max == 75)
        #expect(b[15].count == 2)
    }

    // MARK: - Eine echte Nacht

    /// 23:23 bis 04:58 sind 335 Minuten. Durch sechzehn geteilt ist ein
    /// Abschnitt 1256,25 Sekunden lang — also keine runde Minute.
    private var nightStart: Date { date("2026-10-11T23:23:00+02:00") }
    private var nightEnd: Date { date("2026-10-12T04:58:00+02:00") }

    @Test("Eine Nacht von 23:23 bis 04:58 füllt sechzehn Abschnitte")
    func realisticNight() {
        let width = 1_256.25
        let samples = (0..<16).map {
            QuantitySample(date: nightStart.addingTimeInterval(width * Double($0) + 600),
                           value: 58 + Double($0))
        }
        let b = MinMaxBuckets.buckets(of: samples, from: nightStart, through: nightEnd, count: 16)
        #expect(b.count == 16)
        #expect(b[0].start == nightStart)
        #expect(b[0].end == nightStart.addingTimeInterval(width))
        #expect(b[0].min == 58)
        #expect(b[0].max == 58)
        #expect(b[0].count == 1)
        #expect(b[8].start == nightStart.addingTimeInterval(width * 8))
        #expect(b[8].end == nightStart.addingTimeInterval(width * 9))
        #expect(b[8].min == 66)
        #expect(b[15].start == nightStart.addingTimeInterval(width * 15))
        #expect(b[15].end == nightEnd)
        #expect(b[15].min == 73)
        #expect(b[15].max == 73)
    }

    @Test("Die Abschnitte dieser Nacht stoßen lückenlos aneinander")
    func realisticNightBucketsTouch() {
        let width = 1_256.25
        let samples = (0..<16).map {
            QuantitySample(date: nightStart.addingTimeInterval(width * Double($0) + 600),
                           value: 58 + Double($0))
        }
        let b = MinMaxBuckets.buckets(of: samples, from: nightStart, through: nightEnd, count: 16)
        #expect(b.count == 16)
        #expect(b.first?.start == nightStart)
        #expect(b.last?.end == nightEnd)
        #expect(zip(b, b.dropFirst()).allSatisfy { $0.end == $1.start })
    }

    @Test("Eine echte Nacht mit Lücken liefert nur die gefüllten Abschnitte")
    func realisticNightWithGaps() {
        let width = 1_256.25
        let samples = [QuantitySample(date: nightStart.addingTimeInterval(600), value: 62),
                       QuantitySample(date: nightStart.addingTimeInterval(width * 3 + 600), value: 54),
                       QuantitySample(date: nightStart.addingTimeInterval(width * 3 + 900), value: 51),
                       QuantitySample(date: nightEnd, value: 66)]
        let b = MinMaxBuckets.buckets(of: samples, from: nightStart, through: nightEnd, count: 16)
        #expect(b.count == 3)
        #expect(b[0].start == nightStart)
        #expect(b[0].min == 62)
        #expect(b[0].count == 1)
        #expect(b[1].start == nightStart.addingTimeInterval(width * 3))
        #expect(b[1].min == 51)
        #expect(b[1].max == 54)
        #expect(b[1].count == 2)
        #expect(b[2].start == nightStart.addingTimeInterval(width * 15))
        #expect(b[2].end == nightEnd)
        #expect(b[2].min == 66)
        #expect(b[2].count == 1)
    }
}
