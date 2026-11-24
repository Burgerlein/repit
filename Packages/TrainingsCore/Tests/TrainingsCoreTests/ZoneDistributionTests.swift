import Foundation
import Testing
@testable import TrainingsCore

@Suite("Zonenverteilung")
struct ZoneDistributionTests {

    /// HFmax 205, Ruhepuls 62 als Beispiel. Nach Karvonen ergibt das
    /// Zone 1 = 134–148, Zone 2 = 148–162, Zone 3 = 162–176, Zone 4 = 176–191,
    /// Zone 5 = 191–205. Die Pulswerte unten sind an diesen Grenzen gewählt.
    private var zoning: HeartRateZoning { HeartRateZones.zoning(hrMax: 205, hrRest: 62) }

    private func run(_ minutes: Double, avgHR: Int?,
                     kind: WorkoutKind = .running) -> WorkoutSample {
        WorkoutSample(id: UUID(), start: Date(timeIntervalSince1970: 1_791_000_000),
                      kind: kind, minutes: minutes, avgHR: avgHR)
    }

    @Test("Jeder Lauf landet mit seiner vollen Zeit in einer Zone")
    func minutesLandInOneZone() {
        // 180 liegt in Zone 4.
        let shares = ZoneDistribution.shares([run(60, avgHR: 180)], zoning: zoning)
        #expect(shares.reduce(0) { $0 + $1.minutes } == 60)
        #expect(shares.filter { $0.minutes > 0 }.count == 1)
    }

    @Test("Ein lockerer und ein harter Lauf verteilen sich auf zwei Zonen")
    func twoRunsTwoZones() {
        // 155 liegt in Zone 2, 185 in Zone 4.
        let shares = ZoneDistribution.shares([run(40, avgHR: 155),
                                              run(20, avgHR: 185)], zoning: zoning)
        #expect(shares.reduce(0) { $0 + $1.minutes } == 60)
        #expect(shares.filter { $0.minutes > 0 }.count == 2)
    }

    @Test("Ein Puls unter Zone 1 landet in Zone null")
    func belowZoneOne() {
        // Zone 1 beginnt bei 134.
        let shares = ZoneDistribution.shares([run(30, avgHR: 90)], zoning: zoning)
        #expect(shares.first { $0.zone == 0 }?.minutes == 30)
    }

    // Review Focus 5: Als 0 bpm geführt sähe die Verteilung umso lockerer aus,
    // je weniger gemessen wurde.
    @Test("Ein Lauf ohne Puls zählt gar nicht mit")
    func runWithoutHeartRateIsIgnored() {
        let shares = ZoneDistribution.shares([run(30, avgHR: nil),
                                              run(30, avgHR: 155)], zoning: zoning)
        #expect(shares.reduce(0) { $0 + $1.minutes } == 30)
        #expect(shares.first { $0.zone == 0 }?.minutes == 0)
    }

    @Test("Nur Läufe zählen, kein Krafttraining")
    func onlyRunsAreCounted() {
        let shares = ZoneDistribution.shares([run(60, avgHR: 120, kind: .strength),
                                              run(30, avgHR: 155)], zoning: zoning)
        #expect(shares.reduce(0) { $0 + $1.minutes } == 30)
    }

    @Test("Der lockere Anteil sind Zone 1 und 2 zusammen")
    func easyShareIsZoneOneAndTwo() throws {
        // 80 Minuten in Zone 2 (155), 20 Minuten in Zone 4 (190) → 0,8.
        let shares = ZoneDistribution.shares([run(80, avgHR: 155),
                                              run(20, avgHR: 190)], zoning: zoning)
        let easy = try #require(ZoneDistribution.easyShare(shares))
        #expect(abs(easy - 0.8) < 0.001)
    }

    @Test("Ohne Läufe gibt es keinen Anteil")
    func noRunsNoShare() {
        #expect(ZoneDistribution.easyShare(ZoneDistribution.shares([], zoning: zoning)) == nil)
    }

    @Test("Es gibt immer sechs Einträge, auch leere")
    func alwaysSixEntries() {
        #expect(ZoneDistribution.shares([], zoning: zoning).count == 6)
        #expect(ZoneDistribution.shares([], zoning: zoning).map(\.zone) == [0, 1, 2, 3, 4, 5])
    }
}
