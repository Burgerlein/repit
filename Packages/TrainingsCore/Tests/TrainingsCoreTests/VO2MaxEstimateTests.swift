import Testing
@testable import TrainingsCore

@Suite("Eigene VO₂max-Schätzung aus einer Laufleistung")
struct VO2MaxEstimateTests {

    // Gegenprobe gegen die Daniels-Tabelle, die der Plan ohnehin nutzt:
    // VDOT 34 entspricht dort 127,3 min auf dem Halbmarathon.
    @Test("Ein Halbmarathon in 127,3 min ergibt rund VDOT 34")
    func matchesDanielsTableAt34() {
        let v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 127.3)
        #expect(v != nil)
        #expect(abs(v! - 34) < 0.5)
    }

    @Test("Ein Halbmarathon in 111 min ergibt rund VDOT 40")
    func matchesDanielsTableAt40() {
        let v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 111.0)
        #expect(abs(v! - 40) < 0.5)
    }

    @Test("Halbmarathon in 2:10 entspricht etwa VDOT 33")
    func targetTimeIsAroundThirtyThree() {
        let v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 130)
        #expect(abs(v! - 33.2) < 0.6)
    }

    @Test("Schneller laufen ergibt einen höheren Wert")
    func fasterIsHigher() {
        let slow = VO2MaxEstimate.fromRun(km: 10, minutes: 60)!
        let fast = VO2MaxEstimate.fromRun(km: 10, minutes: 50)!
        #expect(fast > slow)
    }

    @Test("Unsinnige Eingaben ergeben nichts")
    func rejectsNonsense() {
        #expect(VO2MaxEstimate.fromRun(km: 0, minutes: 30) == nil)
        #expect(VO2MaxEstimate.fromRun(km: 5, minutes: 0) == nil)
        #expect(VO2MaxEstimate.fromRun(km: -5, minutes: 30) == nil)
    }

    // Zu kurze Läufe lässt Daniels bewusst aus: unter rund 3 min dominiert
    // die anaerobe Leistung und die Formel überschätzt grob.
    @Test("Sehr kurze Läufe werden abgelehnt")
    func rejectsVeryShortRuns() {
        #expect(VO2MaxEstimate.fromRun(km: 0.4, minutes: 1.2) == nil)
    }
}
