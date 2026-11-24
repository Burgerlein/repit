import Testing
@testable import TrainingsCore

@Suite("Pausenempfehlung")
struct RestGuidanceTests {

    /// Eine Übung, die nur für die Grenzfälle existiert. Alles außer
    /// `repHigh` und `isTimed` ist für die Empfehlung ohne Belang.
    private static func probe(repHigh: Int, isTimed: Bool = false) -> Exercise {
        Exercise(id: "probe\(repHigh)\(isTimed ? "Timed" : "")",
                 name: "Prüfübung",
                 sets: 3,
                 repLow: 1,
                 repHigh: repHigh,
                 increment: 2.5,
                 isTimed: isTimed,
                 cue: "Nur für den Test.",
                 howTo: ["Schritt", "Schritt", "Schritt"],
                 commonMistake: "Keiner.",
                 youTubeQuery: "Prüfübung",
                 muscles: [.chest: 1])
    }

    @Test("Die vier Stufen stehen an echten Katalog-Übungen fest",
          arguments: [("benchPress", 150),
                      ("inclineDumbbellPress", 90),
                      ("lateralRaise", 60),
                      ("sidePlank", 45)])
    func stufenAmKatalog(id: String, expected: Int) throws {
        let exercise = try #require(ExerciseCatalog.all[id], "\(id) fehlt im Katalog")
        #expect(RestGuidance.seconds(for: exercise) == expected,
                "\(id): \(RestGuidance.seconds(for: exercise)) s statt \(expected) s")
    }

    @Test("Zehn Wiederholungen liegen auf der schweren Stufe, nicht auf der mittleren")
    func grenzfallZehn() {
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 10)) == 150)
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 11)) == 90)
    }

    @Test("Fünfzehn Wiederholungen liegen auf der mittleren Stufe, nicht auf der leichten")
    func grenzfallFuenfzehn() {
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 15)) == 90)
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 16)) == 60)
    }

    @Test("Eine Zeitübung bekommt 45 Sekunden, egal wie hoch ihr Wert steht")
    func zeituebungVorDenZahlen() {
        // Der Seitstütz hält 45 Sekunden. Wer `isTimed` erst nach den
        // Wiederholungen prüft, landet bei 60 s.
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 45, isTimed: true)) == 45)
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 8, isTimed: true)) == 45)
        #expect(RestGuidance.seconds(for: Self.probe(repHigh: 12, isTimed: true)) == 45)
    }

    @Test("Der Seitstütz fällt nicht in die Gewichts-Stufen")
    func seitstuetzIstKeineGewichtsuebung() throws {
        let plank = try #require(ExerciseCatalog.all["sidePlank"])
        #expect(plank.isTimed)
        #expect(plank.repHigh == 45)
        #expect(RestGuidance.seconds(for: plank) == 45)
    }

    @Test("Jede Übung des Katalogs bekommt eine Pause aus der Tabelle")
    func keinLochInDerTabelle() {
        for exercise in ExerciseCatalog.all.values {
            let seconds = RestGuidance.seconds(for: exercise)
            #expect(seconds > 0, "\(exercise.id): \(seconds) s")
            #expect([45, 60, 90, 150].contains(seconds),
                    "\(exercise.id): \(seconds) s ist keine der vier Stufen")
        }
    }
}
