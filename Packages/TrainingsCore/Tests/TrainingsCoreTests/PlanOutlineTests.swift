import Testing
@testable import TrainingsCore

@Suite("Plan-Überblick")
struct PlanOutlineTests {

    private func week(_ number: Int, _ phase: TrainingPhase, km: Double = 0,
                      gym: Int = 0, deload: Bool = false) -> PlanWeekOutline {
        PlanWeekOutline(number: number, phase: phase, plannedKm: km,
                        gymSessions: gym, isDeload: deload)
    }

    private func isClose(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 0.0001
    }

    /// 38 Wochen: beforeSurgery 3, recovery 2, base 8, build 7,
    /// raceSpecific 6, taper 1, raceWeek 1, regeneration 1, summer 9.
    private var fullSeason: [PlanWeekOutline] {
        let layout: [(TrainingPhase, Int)] = [
            (.beforeSurgery, 3), (.recovery, 2), (.base, 8), (.build, 7),
            (.raceSpecific, 6), (.taper, 1), (.raceWeek, 1),
            (.regeneration, 1), (.summer, 9)
        ]
        var weeks: [PlanWeekOutline] = []
        var number = 1
        for (phase, count) in layout {
            for _ in 0..<count {
                weeks.append(week(number, phase, km: Double(number), gym: 2))
                number += 1
            }
        }
        return weeks
    }

    // MARK: - phaseBlocks

    @Test("Ohne Wochen gibt es keine Blöcke")
    func noWeeksMeansNoBlocks() {
        #expect(PlanOutline.phaseBlocks(for: []).isEmpty)
    }

    @Test("Eine einzelne Woche ergibt einen Block mit einer Woche")
    func singleWeekMakesOneBlock() {
        let blocks = PlanOutline.phaseBlocks(for: [week(1, .base, km: 30)])
        #expect(blocks.count == 1)
        #expect(blocks.first?.phase == .base)
        #expect(blocks.first?.weekCount == 1)
        #expect(blocks.first?.firstWeek == 1)
        #expect(blocks.first?.lastWeek == 1)
    }

    @Test("Aufeinanderfolgende Wochen derselben Phase bilden einen Block")
    func sameRunBecomesOneBlock() {
        let weeks = [week(1, .base), week(2, .base), week(3, .base)]
        let blocks = PlanOutline.phaseBlocks(for: weeks)
        #expect(blocks.count == 1)
        #expect(blocks[0].weekCount == 3)
        #expect(blocks[0].weeks == weeks)
    }

    @Test("Eine später erneut auftretende Phase ergibt einen eigenen zweiten Block")
    func repeatedPhaseGetsItsOwnBlock() {
        let weeks = [week(1, .base), week(2, .base), week(3, .build), week(4, .base)]
        let blocks = PlanOutline.phaseBlocks(for: weeks)
        #expect(blocks.count == 3)
        #expect(blocks.map(\.phase) == [.base, .build, .base])
        #expect(blocks.map(\.weekCount) == [2, 1, 1])
        #expect(blocks.map(\.firstWeek) == [1, 3, 4])
        #expect(blocks.map(\.lastWeek) == [2, 3, 4])
        #expect(blocks[0].weeks == [weeks[0], weeks[1]])
        #expect(blocks[1].weeks == [weeks[2]])
        #expect(blocks[2].weeks == [weeks[3]])
    }

    @Test("Die Eingabereihenfolge bleibt erhalten, es wird nicht sortiert")
    func inputOrderIsKept() {
        let weeks = [week(5, .base), week(3, .base), week(9, .build), week(1, .build)]
        let blocks = PlanOutline.phaseBlocks(for: weeks)
        #expect(blocks.count == 2)
        #expect(blocks[0].weeks.map(\.number) == [5, 3])
        #expect(blocks[0].firstWeek == 5)
        #expect(blocks[0].lastWeek == 3)
        #expect(blocks[1].weeks.map(\.number) == [9, 1])
        #expect(blocks[1].firstWeek == 9)
        #expect(blocks[1].lastWeek == 1)
    }

    // MARK: - plannedKmRange

    @Test("Die Kilometerspanne reicht vom kleinsten zum größten Wert des Blocks")
    func kmRangeSpansBlock() {
        let weeks = [week(1, .base, km: 32), week(2, .base, km: 45.5), week(3, .base, km: 38)]
        let range = PlanOutline.phaseBlocks(for: weeks).first?.plannedKmRange
        #expect(isClose(range?.lowerBound, 32))
        #expect(isClose(range?.upperBound, 45.5))
    }

    @Test("Ein Block ganz ohne geplante Läufe hat keine Kilometerspanne")
    func kmRangeIsNilWithoutRuns() {
        let weeks = [week(1, .recovery, km: 0), week(2, .recovery, km: 0)]
        #expect(PlanOutline.phaseBlocks(for: weeks).first?.plannedKmRange == nil)
    }

    @Test("Eine einzige Laufwoche ergibt eine Spanne mit gleicher Unter- und Obergrenze")
    func kmRangeOfSingleRunWeekIsDegenerate() {
        let weeks = [week(1, .build, km: 41.25)]
        let range = PlanOutline.phaseBlocks(for: weeks).first?.plannedKmRange
        #expect(isClose(range?.lowerBound, 41.25))
        #expect(isClose(range?.upperBound, 41.25))
    }

    @Test("Wochen ohne Lauf ziehen die Untergrenze nicht auf null")
    func zeroWeeksDoNotLowerTheRange() {
        let weeks = [week(1, .base, km: 0), week(2, .base, km: 28), week(3, .base, km: 0),
                     week(4, .base, km: 36)]
        let range = PlanOutline.phaseBlocks(for: weeks).first?.plannedKmRange
        #expect(isClose(range?.lowerBound, 28))
        #expect(isClose(range?.upperBound, 36))
    }

    // MARK: - gymSessions

    @Test("Gleiche Krafteinheiten im ganzen Block ergeben den gemeinsamen Wert")
    func uniformGymSessions() {
        let weeks = [week(1, .base, gym: 3), week(2, .base, gym: 3), week(3, .base, gym: 3)]
        #expect(PlanOutline.phaseBlocks(for: weeks).first?.gymSessions == 3)
    }

    @Test("Uneinheitliche Krafteinheiten ergeben keinen gemeinsamen Wert")
    func mixedGymSessionsHaveNoCommonValue() {
        let weeks = [week(1, .build, gym: 3), week(2, .build, gym: 2)]
        #expect(PlanOutline.phaseBlocks(for: weeks).first?.gymSessions == nil)
    }

    // MARK: - keyFigures

    @Test("Ohne Wochen sind alle Kennzahlen leer")
    func keyFiguresOfEmptyPlan() {
        let figures = PlanOutline.keyFigures(for: [])
        #expect(figures.peakWeek == nil)
        #expect(isClose(figures.peakKm, 0))
        #expect(isClose(figures.totalPlannedKm, 0))
        #expect(figures.deloadWeeks == 0)
    }

    @Test("Die Gesamtkilometer sind die ungerundete Summe")
    func totalKmIsUnroundedSum() {
        let weeks = [week(1, .base, km: 30.3), week(2, .base, km: 40.4), week(3, .base, km: 10.1)]
        #expect(isClose(PlanOutline.keyFigures(for: weeks).totalPlannedKm, 80.8))
    }

    @Test("Die Spitzenwoche ist die Woche mit den meisten Kilometern")
    func peakWeekIsTheLongestWeek() {
        let weeks = [week(1, .base, km: 30), week(2, .build, km: 52.5), week(3, .build, km: 44)]
        let figures = PlanOutline.keyFigures(for: weeks)
        #expect(figures.peakWeek == 2)
        #expect(isClose(figures.peakKm, 52.5))
    }

    @Test("Bei Gleichstand zählt die frühere Woche als Spitzenwoche")
    func firstWeekWinsOnTie() {
        let weeks = [week(1, .base, km: 30), week(2, .build, km: 52), week(3, .build, km: 52)]
        #expect(PlanOutline.keyFigures(for: weeks).peakWeek == 2)
    }

    @Test("Bei Gleichstand zählt die Eingabereihenfolge, nicht die Wochennummer")
    func tieFollowsInputOrder() {
        let weeks = [week(9, .build, km: 52), week(4, .build, km: 52)]
        #expect(PlanOutline.keyFigures(for: weeks).peakWeek == 9)
    }

    @Test("Ein Plan ohne geplante Läufe hat keine Spitzenwoche")
    func noRunsMeansNoPeakWeek() {
        let weeks = [week(1, .recovery, km: 0), week(2, .recovery, km: 0)]
        let figures = PlanOutline.keyFigures(for: weeks)
        #expect(figures.peakWeek == nil)
        #expect(isClose(figures.peakKm, 0))
        #expect(isClose(figures.totalPlannedKm, 0))
    }

    @Test("Die Entlastungswochen werden gezählt")
    func deloadWeeksAreCounted() {
        let weeks = [week(1, .base, km: 30), week(2, .base, km: 20, deload: true),
                     week(3, .build, km: 40), week(4, .build, km: 25, deload: true),
                     week(5, .build, km: 45)]
        #expect(PlanOutline.keyFigures(for: weeks).deloadWeeks == 2)
    }

    // MARK: - upcoming

    @Test("Die kommenden Wochen beginnen mit der laufenden Woche")
    func upcomingStartsWithCurrentWeek() {
        let weeks = (1...10).map { week($0, .base, km: Double($0)) }
        let next = PlanOutline.upcoming(weeks, from: 4, limit: 3)
        #expect(next.map(\.number) == [4, 5, 6])
    }

    @Test("Sind weniger Wochen übrig als gefordert, kommen eben weniger zurück")
    func upcomingReturnsWhatIsLeft() {
        let weeks = (1...10).map { week($0, .base) }
        #expect(PlanOutline.upcoming(weeks, from: 9, limit: 4).map(\.number) == [9, 10])
    }

    @Test("Hinter der letzten Woche gibt es nichts mehr")
    func upcomingAfterTheLastWeekIsEmpty() {
        let weeks = (1...10).map { week($0, .base) }
        #expect(PlanOutline.upcoming(weeks, from: 11, limit: 3).isEmpty)
        #expect(PlanOutline.upcoming(weeks, from: 99, limit: 3).isEmpty)
    }

    @Test("Ein Limit von null oder weniger liefert nichts")
    func upcomingWithoutLimitIsEmpty() {
        let weeks = (1...10).map { week($0, .base) }
        #expect(PlanOutline.upcoming(weeks, from: 1, limit: 0).isEmpty)
        #expect(PlanOutline.upcoming(weeks, from: 1, limit: -3).isEmpty)
    }

    @Test("Die kommenden Wochen behalten die Eingabereihenfolge")
    func upcomingKeepsInputOrder() {
        let weeks = [week(7, .build), week(2, .base), week(9, .build), week(5, .base)]
        #expect(PlanOutline.upcoming(weeks, from: 5, limit: 10).map(\.number) == [7, 9, 5])
    }

    // MARK: - Vollständige Saison

    @Test("Die 38-Wochen-Saison zerfällt in neun Blöcke")
    func fullSeasonHasNineBlocks() {
        let blocks = PlanOutline.phaseBlocks(for: fullSeason)
        #expect(blocks.count == 9)
        #expect(blocks.map(\.phase) == [.beforeSurgery, .recovery, .base, .build,
                                        .raceSpecific, .taper, .raceWeek,
                                        .regeneration, .summer])
        #expect(blocks.map(\.weekCount) == [3, 2, 8, 7, 6, 1, 1, 1, 9])
    }

    @Test("Die Blöcke der Saison decken die Wochen 1 bis 38 lückenlos ab")
    func fullSeasonCoversEveryWeek() {
        let blocks = PlanOutline.phaseBlocks(for: fullSeason)
        #expect(blocks.flatMap(\.weeks).map(\.number) == Array(1...38))
        #expect(blocks.first?.firstWeek == 1)
        #expect(blocks.last?.lastWeek == 38)
        for i in 1..<blocks.count {
            #expect(blocks[i - 1].lastWeek + 1 == blocks[i].firstWeek)
        }
    }

    @Test("Die Kennzahlen der Saison nennen die letzte Woche als Spitze")
    func fullSeasonKeyFigures() {
        let figures = PlanOutline.keyFigures(for: fullSeason)
        #expect(figures.peakWeek == 38)
        #expect(isClose(figures.peakKm, 38))
        #expect(isClose(figures.totalPlannedKm, 741))   // 38 · 39 / 2
        #expect(figures.deloadWeeks == 0)
    }
}
