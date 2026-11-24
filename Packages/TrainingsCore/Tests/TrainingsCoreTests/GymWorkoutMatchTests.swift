import Foundation
import Testing
@testable import TrainingsCore

/// Zu einer Gym-Sitzung gehört oft ein von der Watch mitgeschriebenes
/// Krafttraining. `GymWorkoutMatch` sucht dieses eine Apple-Workout zu einem
/// Tag heraus — damit die Sitzung Dauer und Puls zeigen kann, ohne zu raten.
///
/// Alle Zahlen hier sind erfunden. Echte Gesundheitsdaten gehören nicht ins
/// Repository.
@Suite("Apple-Krafttraining zur Gym-Sitzung")
struct GymWorkoutMatchTests {

    // MARK: - Werkzeug

    /// Ein Zeitpunkt in Berliner Zeit. Niemals über `timeIntervalSince1970`
    /// mit gerechnetem Versatz — sonst prüft der Test die Zeitzone des
    /// Rechners mit, auf dem er läuft.
    private func time(_ year: Int, _ month: Int, _ dayOfMonth: Int,
                      _ hour: Int, _ minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: dayOfMonth,
                                        hour: hour, minute: minute)
        return BerlinCalendar.calendar.date(from: components) ?? .distantPast
    }

    /// Der Berliner Tagesbeginn — so wie ihn die Sitzung mitbringt.
    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
        BerlinCalendar.startOfDay(time(year, month, dayOfMonth, 12))
    }

    private func workout(_ start: Date, _ kind: WorkoutKind,
                         _ minutes: Double) -> WorkoutSample {
        WorkoutSample(id: UUID(), start: start, kind: kind, minutes: minutes)
    }

    // MARK: - Der einfache Fall

    @Test("Ein Krafttraining am selben Tag wird gefunden")
    func strengthOnTheSameDayIsFound() {
        let strength = workout(time(2026, 10, 12, 18, 30), .strength, 58)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [strength]) == strength)
    }

    @Test("Ohne Workouts gibt es nichts zu finden")
    func emptyListIsNil() {
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12), workouts: []) == nil)
    }

    // MARK: - Nur Krafttraining zählt

    @Test("Ein Lauftraining am selben Tag wird übergangen")
    func runOnTheSameDayIsIgnored() {
        // Ein Lauf ist kein Gym-Training. Ihn der Sitzung zuzuschlagen hieße,
        // fremde Minuten und einen fremden Puls als ihre auszugeben.
        let run = workout(time(2026, 10, 12, 7, 15), .running, 52)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12), workouts: [run]) == nil)
    }

    @Test("Jede andere Trainingsart wird übergangen, auch als einzige des Tages")
    func everyOtherKindIsIgnored() {
        for kind in WorkoutKind.allCases where kind != .strength {
            let other = workout(time(2026, 10, 12, 17, 0), kind, 45)

            #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                          workouts: [other]) == nil,
                    "\(kind.rawValue) darf nicht als Krafttraining gelten")
        }
    }

    // Prüfschwerpunkt: erst die Art aussortieren, dann die längste Dauer
    // suchen — nicht umgekehrt.
    @Test("Ein längeres Lauftraining schlägt das kürzere Krafttraining nicht")
    func longerRunDoesNotBeatShorterStrength() {
        let run = workout(time(2026, 10, 12, 7, 15), .running, 95)
        let strength = workout(time(2026, 10, 12, 18, 30), .strength, 41)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [run, strength]) == strength)
    }

    // MARK: - Nur dieser Tag zählt

    @Test("Krafttraining am Vortag und am Folgetag wird nicht gefunden")
    func strengthOnNeighbouringDaysIsNotFound() {
        let before = workout(time(2026, 10, 11, 18, 30), .strength, 60)
        let after = workout(time(2026, 10, 13, 18, 30), .strength, 60)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [before, after]) == nil)

        // Gegenprobe: an ihren eigenen Tagen werden beide gefunden.
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 11),
                                      workouts: [before, after]) == before)
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 13),
                                      workouts: [before, after]) == after)
    }

    @Test("Ein Tag mit Uhrzeit findet dasselbe Training wie der Tagesbeginn")
    func dayWithTimeOfDayMatchesStartOfDay() {
        // Mancher Aufrufer reicht ein Datum mit Uhrzeit herein. Dass davon
        // das Ergebnis abhängt, wäre ein stiller Fehler.
        let strength = workout(time(2026, 10, 12, 18, 30), .strength, 58)

        #expect(GymWorkoutMatch.match(day: time(2026, 10, 12, 15),
                                      workouts: [strength]) == strength)
        #expect(GymWorkoutMatch.match(day: time(2026, 10, 12, 15), workouts: [strength])
                == GymWorkoutMatch.match(day: day(2026, 10, 12), workouts: [strength]))
    }

    // MARK: - Die Tagesgrenze liegt in Berlin, nicht in UTC

    // Prüfschwerpunkt: 00:10 Berliner Zeit ist in UTC noch der Vortag. Wer die
    // Tage in UTC vergleicht, schiebt dieses Training einen Tag zurück.
    @Test("Ein Training um 00:10 gehört zum neuen Tag")
    func justAfterMidnightBelongsToTheNewDay() {
        let strength = workout(time(2026, 10, 12, 0, 10), .strength, 35)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [strength]) == strength)
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 11), workouts: [strength]) == nil)
    }

    // Prüfschwerpunkt: 23:50 gehört zu seinem eigenen Tag, nicht zum nächsten.
    @Test("Ein Training um 23:50 gehört zu seinem eigenen Tag")
    func lateEveningBelongsToItsOwnDay() {
        let strength = workout(time(2026, 10, 12, 23, 50), .strength, 20)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [strength]) == strength)
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 13), workouts: [strength]) == nil)
    }

    @Test("Auch in der Winterzeit gehört 23:50 zu seinem eigenen Tag")
    func lateEveningInWinterBelongsToItsOwnDay() {
        // Im Januar ist Berlin UTC+1, im Oktober UTC+2. Eine fest verdrahtete
        // Verschiebung trifft höchstens eine der beiden Jahreszeiten.
        let strength = workout(time(2027, 1, 14, 23, 50), .strength, 20)

        #expect(GymWorkoutMatch.match(day: day(2027, 1, 14),
                                      workouts: [strength]) == strength)
        #expect(GymWorkoutMatch.match(day: day(2027, 1, 15), workouts: [strength]) == nil)
    }

    @Test("Am Tag der Zeitumstellung bleiben die Grenzen die des kurzen Tages")
    func shortDstDayKeepsItsOwnBounds() {
        // Der 28.03.2027 hat 23 Stunden. Wer 24 Stunden auf den Tagesbeginn
        // addiert, zieht das Training des 29. mit herein.
        let short = workout(time(2027, 3, 28, 23, 50), .strength, 30)
        let next = workout(time(2027, 3, 29, 0, 10), .strength, 30)

        #expect(GymWorkoutMatch.match(day: day(2027, 3, 28),
                                      workouts: [short, next]) == short)
        #expect(GymWorkoutMatch.match(day: day(2027, 3, 29),
                                      workouts: [short, next]) == next)
    }

    // MARK: - Mehrere Krafttrainings an einem Tag

    @Test("Von zwei Krafttrainings gewinnt das längere")
    func longerStrengthWins() {
        // Wer morgens kurz an die Hantel geht und abends das eigentliche
        // Training macht, meint das abendliche.
        let shortOne = workout(time(2026, 10, 12, 7, 30), .strength, 18)
        let longOne = workout(time(2026, 10, 12, 18, 30), .strength, 62)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [shortOne, longOne]) == longOne)
        // Die Reihenfolge der Eingabe darf nichts ändern.
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [longOne, shortOne]) == longOne)
    }

    @Test("Bei gleicher Dauer gewinnt das frühere")
    func equalMinutesEarlierWins() {
        // Zwei gleich lange Einheiten an einem Tag sind selten, aber das
        // Ergebnis darf nicht von der Reihenfolge der Liste abhängen.
        let earlier = workout(time(2026, 10, 12, 7, 30), .strength, 45)
        let later = workout(time(2026, 10, 12, 18, 30), .strength, 45)

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [earlier, later]) == earlier)
        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12),
                                      workouts: [later, earlier]) == earlier)
    }

    @Test("Aus einem gemischten Tag mit Nachbartagen kommt das richtige Training")
    func picksFromAMixedList() {
        // Der tatsächliche Fall: eine Woche Workouts am Stück, darunter Läufe,
        // und gesucht ist das lange Krafttraining vom Montag.
        let runBefore = workout(time(2026, 10, 11, 9, 0), .running, 110)
        let strengthBefore = workout(time(2026, 10, 11, 19, 0), .strength, 70)
        let runSameDay = workout(time(2026, 10, 12, 6, 45), .running, 48)
        let shortStrength = workout(time(2026, 10, 12, 12, 10), .strength, 22)
        let mainStrength = workout(time(2026, 10, 12, 18, 20), .strength, 64)
        let strengthAfter = workout(time(2026, 10, 13, 18, 0), .strength, 90)
        let all = [runBefore, strengthBefore, runSameDay,
                   shortStrength, mainStrength, strengthAfter]

        #expect(GymWorkoutMatch.match(day: day(2026, 10, 12), workouts: all) == mainStrength)
    }
}
