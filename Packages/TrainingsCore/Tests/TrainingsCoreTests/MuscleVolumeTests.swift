import Foundation
import Testing
@testable import TrainingsCore

@Suite("Muskelvolumen")
struct MuscleVolumeTests {

    private let now = Date(timeIntervalSince1970: 1_791_000_000)  // 03.10.2026, 06:00 Berliner Zeit

    private func set(_ daysAgo: Int, _ id: String) -> TrainedSet {
        TrainedSet(date: BerlinCalendar.calendar.date(byAdding: .day, value: -daysAgo,
                                                      to: now)!,
                   exerciseID: id)
    }

    // Hauptmuskel 1, Nebenmuskel 0,5 — die Gewichte stehen im Übungskatalog,
    // nicht in dieser Rechnung. Bankdrücken trägt Brust 1, vordere Schulter 0,5
    // und Trizeps 0,5.
    @Test("Ein Satz Bankdrücken zählt Brust 1, vordere Schulter und Trizeps je 0,5")
    func oneSetCountsMainAndSecondary() {
        let v = MuscleVolume.weeklySets([set(1, "benchPress")], window: 7, now: now)
        #expect(v[.chest] == 1)
        #expect(v[.frontDelt] == 0.5)
        #expect(v[.triceps] == 0.5)
    }

    @Test("Im 30-Tage-Fenster wird auf eine Woche heruntergerechnet")
    func thirtyDayWindowIsScaledToOneWeek() {
        // Zwölf Sätze Bankdrücken in 30 Tagen sind 12 / (30/7) = 2,8 pro Woche.
        let sets = (1...12).map { set($0, "benchPress") }
        let v = MuscleVolume.weeklySets(sets, window: 30, now: now)
        #expect(abs((v[.chest] ?? 0) - 2.8) < 0.001)
    }

    @Test("Sätze außerhalb des Fensters zählen nicht")
    func setsOutsideTheWindowAreIgnored() {
        let v = MuscleVolume.weeklySets([set(1, "benchPress"), set(9, "benchPress")],
                                        window: 7, now: now)
        #expect(v[.chest] == 1)
    }

    // Das Fenster endet am heutigen Tag, nicht an der Uhrzeit — ein Satz von
    // heute Morgen darf nicht durchs Raster fallen.
    @Test("Ein Satz von heute zählt mit")
    func todayCounts() {
        let v = MuscleVolume.weeklySets([set(0, "benchPress")], window: 7, now: now)
        #expect(v[.chest] == 1)
    }

    // Hip Thrust und Wadenheben sitzend stehen in keinem Workout mehr. Im
    // gespeicherten Verlauf stehen sie weiter — und müssen dort zählen,
    // sonst fällt rückwirkend Volumen aus der Muskelkarte.
    @Test("Ein alter Satz einer ausgemusterten Übung zählt weiter mit")
    func retiredExercisesStillCount() {
        let hip = MuscleVolume.weeklySets([set(1, "hipThrust")], window: 7, now: now)
        #expect(hip[.glutes] == 1)
        #expect(hip[.hamstrings] == 0.5)

        let calf = MuscleVolume.weeklySets([set(2, "calfRaiseSeated")], window: 7, now: now)
        #expect(calf[.calves] == 1)
    }

    @Test("Die neuen Beinübungen zählen auf ihre Muskeln")
    func newLegExercisesCount() {
        let v = MuscleVolume.weeklySets([set(1, "legPress"), set(1, "legCurl"),
                                         set(1, "hipAbduction"), set(1, "legExtension")],
                                        window: 7, now: now)
        #expect(v[.quads] == 2)        // Beinpresse 1 + Beinstrecker 1
        #expect(v[.glutes] == 1.5)     // Beinpresse 0,5 + Abduktoren 1
        #expect(v[.hamstrings] == 1)   // Beinbeuger 1
    }

    // Eine Übung, die der Katalog nicht kennt, hat keine Muskelzuordnung.
    // Raten hieße, eine Zahl zu erfinden.
    @Test("Eine unbekannte Übung wird übergangen, nicht geraten")
    func unknownExerciseIsIgnored() {
        let v = MuscleVolume.weeklySets([set(1, "zumba")], window: 7, now: now)
        #expect(v.values.allSatisfy { $0 == 0 })
    }

    // Review Focus 3
    @Test("Ohne Training steht jeder Muskel bei null und deutlich unter Ziel")
    func noTrainingYieldsZero() {
        let v = MuscleVolume.weeklySets([], window: 7, now: now)
        #expect(v.count == Muscle.allCases.count)
        for muscle in Muscle.allCases {
            #expect(v[muscle] == 0)
            #expect(MuscleVolume.status(muscle, sets: 0) == .priority)
        }
        #expect(MuscleVolume.sortedByNeed(v).count == Muscle.allCases.count)
    }

    @Test("Der Zustand folgt dem Zielbereich aus der Spec")
    func statusFollowsTarget() {
        // Brust: Ziel 10 bis 20.
        #expect(MuscleVolume.status(.chest, sets: 4) == .priority)   // unter 5
        #expect(MuscleVolume.status(.chest, sets: 5) == .low)        // halbe Untergrenze
        #expect(MuscleVolume.status(.chest, sets: 9.9) == .low)
        #expect(MuscleVolume.status(.chest, sets: 10) == .ok)
        #expect(MuscleVolume.status(.chest, sets: 20) == .ok)
        #expect(MuscleVolume.status(.chest, sets: 20.1) == .high)
    }

    @Test("Die Liste führt die dringendsten Muskeln zuerst")
    func sortingPutsTheNeediestFirst() {
        var v = Dictionary(uniqueKeysWithValues: Muscle.allCases.map { ($0, 12.0) })
        v[.chest] = 0          // rot
        v[.biceps] = 7         // gelb
        v[.lats] = 25          // blau
        v[.triceps] = 15       // grün
        let order = MuscleVolume.sortedByNeed(v)
        #expect(order.first == .chest)
        #expect(order.firstIndex(of: .biceps)! < order.firstIndex(of: .lats)!)
        #expect(order.firstIndex(of: .lats)! < order.firstIndex(of: .triceps)!)
    }
}
