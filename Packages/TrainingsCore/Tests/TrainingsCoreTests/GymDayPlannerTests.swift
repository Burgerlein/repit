import Foundation
import Testing
@testable import TrainingsCore

@Suite("Tageszustand im Gym")
struct GymDayPlannerTests {

    private let cal = BerlinCalendar.calendar

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    /// Mo A, Mi B, Do C — der Plan aus SPEC 4.4 vor der OP.
    private let schedule = [PlannedGym(workout: .a, weekday: 2),
                            PlannedGym(workout: .b, weekday: 4),
                            PlannedGym(workout: .c, weekday: 5)]

    private func day(_ today: Date,
                     completed: [Workout: Date] = [:],
                     overdue: [Workout] = [],
                     draft: GymDraft? = nil,
                     surgery: Date? = nil) -> GymDay {
        GymDayPlanner.day(today: today, planned: schedule, completed: completed,
                          overdue: overdue, draft: draft, surgery: surgery)
    }

    @Test("Ein angefangenes Training steht im Vordergrund")
    func draftWins() {
        let d = day(date(2026, 10, 12),
                    draft: GymDraft(workout: .a, doneExercises: 2, totalExercises: 7))
        #expect(d.focus == .inProgress(workout: .a, done: 2, total: 7))
    }

    // Prüfschwerpunkt 1
    @Test("Ein Entwurf ohne erfasste Übung gilt als geplant, nicht als angefangen")
    func emptyDraftIsNotInProgress() {
        let d = day(date(2026, 10, 12),
                    draft: GymDraft(workout: .a, doneExercises: 0, totalExercises: 7))
        #expect(d.focus == .planned(workout: .a))
    }

    @Test("Am Montag ohne Entwurf ist Gym A geplant")
    func plannedToday() {
        #expect(day(date(2026, 10, 12)).focus == .planned(workout: .a))
    }

    @Test("Am Dienstag ist Ruhetag, als Nächstes kommt Gym B am Mittwoch")
    func restDayNamesNext() {
        let d = day(date(2026, 10, 13), completed: [.a: date(2026, 10, 12)])
        #expect(d.focus == .rest(next: .b, inDays: 1, overdue: nil))
    }

    @Test("Ein liegen gebliebenes Workout wird am Ruhetag genannt")
    func restDayNamesOverdue() {
        let d = day(date(2026, 10, 13), completed: [.a: date(2026, 10, 12)], overdue: [.d])
        #expect(d.focus == .rest(next: .b, inDays: 1, overdue: .d))
    }

    // Prüfschwerpunkt 2
    @Test("Ist die Woche durch, bleibt der Ruhetag ohne nächstes und ohne offenes Workout")
    func nothingLeftThisWeek() {
        let done: [Workout: Date] = [.a: date(2026, 10, 12), .b: date(2026, 10, 14),
                                     .c: date(2026, 10, 15)]
        let d = day(date(2026, 10, 16), completed: done)
        #expect(d.focus == .rest(next: nil, inDays: nil, overdue: nil))
        // Nur die Rotation füllt die Wochenleiste — Push, Pull und Legs
        // haben keinen Platz darin.
        #expect(d.week.count == Workout.rotation.count)
    }

    // Prüfschwerpunkt 3
    @Test("In der Erholung zählt weder Entwurf noch geplantes Workout")
    func recoveryBeatsEverything() {
        let d = day(date(2026, 11, 6),
                    draft: GymDraft(workout: .a, doneExercises: 3, totalExercises: 7),
                    surgery: date(2026, 10, 28))
        #expect(d.focus == .recovery(
            dayAfterSurgery: 9,
            earliestReturn: BerlinCalendar.startOfDay(date(2026, 11, 16))))
        #expect(d.week.allSatisfy { $0.status == .paused })
    }

    @Test("Der Wiedereinstieg ist der erste Montag ab OP plus Pause")
    func returnIsFirstMondayAfterPause() {
        // OP Mi 28.10., 14 Tage Pause endet Mi 11.11. — Wiedereinstieg Mo 16.11.
        let d = day(date(2026, 10, 29), surgery: date(2026, 10, 28))
        guard case .recovery(_, let back) = d.focus else {
            Issue.record("Erwartet wurde der Erholungszustand"); return
        }
        #expect(cal.component(.weekday, from: back) == 2)
        #expect(back == BerlinCalendar.startOfDay(date(2026, 11, 16)))
    }

    @Test("Der erste Tag nach dem Pausenfenster ist wieder normaler Betrieb")
    func pauseWindowEnds() {
        let d = day(date(2026, 11, 16), surgery: date(2026, 10, 28))
        #expect(d.focus == .planned(workout: .a))
    }

    @Test("Die Woche nennt erledigt, laufend, heute, offen und überfällig")
    func weekStatuses() {
        let d = day(date(2026, 10, 14),
                    completed: [.a: date(2026, 10, 12)],
                    overdue: [.d],
                    draft: GymDraft(workout: .b, doneExercises: 1, totalExercises: 8))
        #expect(d.week.map(\.workout) == [.a, .b, .c, .d])
        #expect(d.week[0].status == .done(BerlinCalendar.startOfDay(date(2026, 10, 12))))
        #expect(d.week[1].status == .running)
        #expect(d.week[2].status == .open)
        #expect(d.week[3].status == .overdue)
    }

    @Test("Ein in dieser Woche verpasstes Workout gilt als überfällig")
    func missedEarlierThisWeekIsOverdue() {
        let d = day(date(2026, 10, 14))
        #expect(d.week[0].status == .overdue)
        #expect(d.week[1].status == .today)
    }

    @Test("Workouts ohne festen Tag stehen am Ende der Woche")
    func unscheduledLast() {
        #expect(day(date(2026, 10, 12)).week.last?.workout == .d)
        #expect(day(date(2026, 10, 12)).week.last?.weekday == nil)
    }

    // MARK: - Frei wählbare Workouts

    /// Push, Pull und Legs haben keinen festen Tag. Ein Platz in der Woche,
    /// der nie fällig wird, säße dort auf Dauer als Kachel, die „offen“
    /// sagt — und nach drei Wochen glaubt ihr niemand mehr.
    @Test("Die Wochenleiste führt allein die Rotation")
    func weekHoldsOnlyTheRotation() {
        let d = day(date(2026, 10, 12))
        #expect(d.week.map(\.workout) == [.a, .b, .c, .d])
        for workout in Workout.freelyChosen {
            #expect(!d.week.contains { $0.workout == workout },
                    "\(workout.rawValue) hat einen Platz in der Woche")
        }
    }

    @Test("Auch ein frei wählbares Workout im Plan bekommt keinen Platz")
    func freelyChosenInThePlanGetsNoSlot() {
        // Der Plan führt sie nicht — stünde eines doch darin, bliebe die
        // Wochenleiste trotzdem bei A bis D.
        let d = GymDayPlanner.day(today: date(2026, 10, 12),
                                  planned: schedule + [PlannedGym(workout: .push, weekday: 2)],
                                  completed: [:], overdue: [], draft: nil, surgery: nil)
        #expect(d.week.map(\.workout) == [.a, .b, .c, .d])
        #expect(d.focus == .planned(workout: .a))
    }

    @Test("Ein frei wählbares Workout wird nie heute und nie überfällig")
    func freelyChosenIsNeverTodayOrOverdue() {
        // Jeder Wochentag einmal durch: An keinem darf Push, Pull oder Legs
        // in der Woche auftauchen, geschweige denn fällig werden.
        for tag in 12...18 {
            let d = day(date(2026, 10, tag), overdue: Workout.freelyChosen)
            for slot in d.week {
                #expect(Workout.rotation.contains(slot.workout),
                        "\(slot.workout.rawValue) steht am \(tag). in der Woche")
            }
        }
    }

    @Test("Ein hineingereichtes Push gilt nicht als nachzuholen")
    func freelyChosenHandedInAsOverdueIsIgnored() {
        // `overdue` kommt von außen und wiegt sonst schwerer als jede
        // Ableitung aus dem Tag. Für Push, Pull und Legs gilt das nicht:
        // Was nie fällig war, kann nicht liegen bleiben.
        let d = day(date(2026, 10, 13), completed: [.a: date(2026, 10, 12)],
                    overdue: [.push])
        #expect(d.focus == .rest(next: .b, inDays: 1, overdue: nil))
    }

    @Test("Neben einem frei wählbaren bleibt das echte überfällige Workout stehen")
    func realOverdueSurvivesNextToAFreelyChosenOne() {
        let d = day(date(2026, 10, 13), completed: [.a: date(2026, 10, 12)],
                    overdue: [.legs, .d])
        #expect(d.focus == .rest(next: .b, inDays: 1, overdue: .d))
    }

    @Test("Ein angefangenes Push steht trotzdem im Vordergrund")
    func freelyChosenDraftStillWins() {
        // Nicht fällig heißt nicht unsichtbar: Wer Push angefangen hat,
        // soll es wiederfinden — nur eben nicht als Platz in der Woche.
        let d = day(date(2026, 10, 12),
                    draft: GymDraft(workout: .push, doneExercises: 2, totalExercises: 7))
        #expect(d.focus == .inProgress(workout: .push, done: 2, total: 7))
        #expect(!d.week.contains { $0.workout == .push })
    }

    @Test("Ein erledigtes Push füllt keinen Platz der Woche")
    func completedFreelyChosenFillsNoSlot() {
        let d = day(date(2026, 10, 13),
                    completed: [.a: date(2026, 10, 12), .push: date(2026, 10, 13)])
        #expect(d.week.map(\.workout) == [.a, .b, .c, .d])
        #expect(d.doneThisWeek == 1)
    }

    // MARK: - Erledigte Einheiten der Woche

    /// Eine Woche aus fertigen Plätzen. Der Fokus steht hier nie zur Debatte;
    /// `doneThisWeek` liest allein die Woche.
    private func woche(_ slots: [GymSlot]) -> GymDay {
        GymDay(focus: .rest(next: nil, inDays: nil, overdue: nil), week: slots)
    }

    private func slot(_ workout: Workout, _ weekday: Int?,
                      _ status: GymSlotStatus) -> GymSlot {
        GymSlot(workout: workout, weekday: weekday, status: status)
    }

    @Test("Eine Woche ohne erledigte Einheit ergibt null")
    func emptyWeekCountsZero() {
        let w = woche([slot(.a, 2, .today), slot(.b, 4, .open),
                       slot(.c, 5, .open), slot(.d, nil, .open)])
        #expect(w.doneThisWeek == 0)
    }

    @Test("Eine Woche ganz ohne Plätze ergibt null")
    func weekWithoutSlotsCountsZero() {
        #expect(woche([]).doneThisWeek == 0)
    }

    @Test("Gezählt werden allein die Plätze mit Status erledigt")
    func onlyDoneSlotsCount() {
        let w = woche([slot(.a, 2, .done(date(2026, 10, 12))),
                       slot(.b, 4, .done(date(2026, 10, 14))),
                       slot(.c, 5, .today),
                       slot(.d, nil, .open)])
        #expect(w.doneThisWeek == 2)
    }

    @Test("Offen, heute und überfällig zählen nicht mit")
    func openTodayAndOverdueDoNotCount() {
        let w = woche([slot(.a, 2, .overdue), slot(.b, 4, .today),
                       slot(.c, 5, .open), slot(.d, nil, .overdue)])
        #expect(w.doneThisWeek == 0)
    }

    @Test("Ein laufendes Training zählt erst, wenn es abgeschlossen ist")
    func runningDoesNotCount() {
        let laufend = woche([slot(.a, 2, .running), slot(.b, 4, .open),
                             slot(.c, 5, .open), slot(.d, nil, .open)])
        #expect(laufend.doneThisWeek == 0)
        let fertig = woche([slot(.a, 2, .done(date(2026, 10, 12))),
                            slot(.b, 4, .open), slot(.c, 5, .open),
                            slot(.d, nil, .open)])
        #expect(fertig.doneThisWeek == 1)
    }

    @Test("In der Erholung ist nichts erledigt")
    func pausedDoesNotCount() {
        let w = woche([slot(.a, 2, .paused), slot(.b, 4, .paused),
                       slot(.c, 5, .paused), slot(.d, nil, .paused)])
        #expect(w.doneThisWeek == 0)
        // Dasselbe über den Planer: nach der OP steht die ganze Woche still.
        let d = day(date(2026, 11, 6), surgery: date(2026, 10, 28))
        #expect(d.doneThisWeek == 0)
    }

    @Test("Ein nachgeholtes Gym D ohne festen Wochentag zählt mit")
    func unscheduledWorkoutCountsWhenDone() {
        let w = woche([slot(.a, 2, .done(date(2026, 10, 12))),
                       slot(.b, 4, .open), slot(.c, 5, .open),
                       slot(.d, nil, .done(date(2026, 10, 17)))])
        #expect(w.doneThisWeek == 2)
    }

    @Test("Sind alle Plätze erledigt, zählt die Woche jeden einzeln")
    func allSlotsDoneCountsAll() {
        let w = woche([slot(.a, 2, .done(date(2026, 10, 12))),
                       slot(.b, 4, .done(date(2026, 10, 14))),
                       slot(.c, 5, .done(date(2026, 10, 15))),
                       slot(.d, nil, .done(date(2026, 10, 17)))])
        #expect(w.doneThisWeek == 4)
    }

    @Test("Das Datum des Abschlusses ändert die Zahl nicht")
    func completionDateDoesNotChangeTheCount() {
        let frueh = woche([slot(.a, 2, .done(date(2026, 10, 12)))])
        let spaet = woche([slot(.a, 2, .done(date(2026, 10, 18)))])
        #expect(frueh.doneThisWeek == spaet.doneThisWeek)
        #expect(frueh.doneThisWeek == 1)
    }

    @Test("Dasselbe Workout zweimal in der Woche füllt einen Platz, nicht zwei")
    func sameWorkoutTwiceFillsOneSlot() {
        // Gym A am Montag und noch einmal am Freitag. `completed` trägt je
        // Workout nur ein Datum — gezählt werden Plätze, nicht Trainings.
        let d = day(date(2026, 10, 16), completed: [.a: date(2026, 10, 16)])
        let erledigt = d.week.filter { slot in
            if case .done = slot.status { return true }
            return false
        }
        #expect(erledigt.count == 1)
        #expect(d.doneThisWeek == 1)
    }
}
