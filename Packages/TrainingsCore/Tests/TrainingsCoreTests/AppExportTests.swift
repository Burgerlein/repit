import Foundation
import Testing
@testable import TrainingsCore

// MARK: - Die Gestalt, gegen die hier geprüft wird
//
// `AppExport` ist die Hülle, die die eingefrorene Swift-App herausgibt, damit
// die Flutter-App den Stand übernehmen kann (Issue #70). Sie liegt in
// `Packages/TrainingsCore/Sources/TrainingsCore/Export/AppExport.swift` und ist
// **reine Struktur**: kein `FileManager`, kein Dateizugriff. Das Einsammeln der
// sechs Stände liegt in der View.
//
// Alle Spiegel sind **in `AppExport` geschachtelt und hängen an keinem anderen
// Typ des Kerns**. Das ist Absicht: Die Hülle ist ein Austauschformat. Änderte
// sich `ImportedSession` oder `CompletedSet`, änderte sich sonst stillschweigend
// die Datei, die auf der Gegenseite gelesen wird. Die Typen der App-Seite
// (`StoredCircumferences`, `StoredGymDraft`) liegen ohnehin im App-Target und
// dürfen hier nicht auftauchen — `TrainingsCore` importiert nur Foundation.
//
// ```
// AppExport: Codable, Equatable, Sendable
//   format: String          // "trainingsexport"
//   version: Int            // 2
//   generated: Date
//   timezone: String        // z. B. "Europe/Berlin"
//   app: AppExport.State
//   init(generated: Date, timezone: String, app: State)   // setzt format/version
//   static let encoder: JSONEncoder   // .iso8601
//   static let decoder: JSONDecoder   // .iso8601
//
// AppExport.State            // die sechs Stände, alle [] und nie nil
//   sessions:         [Session]
//   circumferences:   [CircumferenceSample]
//   swaps:            [Swap]
//   drafts:           [Draft]
//   dataWindow:       [Setting]
//   dashboardImport:  [ImportRecord]
//
// AppExport.Session            id: String, date: Date, workout: String?,
//                              minutes: Int?, note: String?, exercises: [Exercise]
// AppExport.Exercise           exerciseID: String, sets: [ExerciseSet]
// AppExport.ExerciseSet        weight: Double, reps: Int
//                              (negatives Gewicht = Unterstützung der Maschine)
// AppExport.CircumferenceSample date: Date, values: [String: Double]
//                              (Rohwerte von `Circumference`, als Zeichenkette —
//                               wie in `StoredCircumferences.Entry`)
// AppExport.Swap               week: Int, first: String, second: String
// AppExport.Draft              workout: String, date: Date, duration: String,
//                              note: String, entries: [String: [DraftSet]],
//                              assist: [String: Bool], savedAt: Date
// AppExport.DraftSet           weight: String, reps: String, done: Bool
//                              (Zeichenketten, weil ein Entwurf das Getippte
//                               hält, nicht das Gerechnete — wie `StoredGymDraft`)
// AppExport.Setting            key: String, bool: Bool?, date: Date?, text: String?
//                              (genau eines der drei ist gesetzt)
// AppExport.ImportRecord       importedAt: Date?, sessions: [Session],
//                              scales: [ScaleSample],
//                              circumferences: [CircumferenceSample]
// AppExport.ScaleSample        date: Date, weightKg: Double?, bodyFatPct: Double?,
//                              muscleKg: Double?, musclePct: Double?
// ```
//
// Zwei Entscheidungen, die man begründen muss:
//
// 1. `dataWindow` ist eine **Liste von Schlüssel-Wert-Paaren**, nicht ein Block
//    mit drei Feldern. Der Betrachtungszeitraum steht in `UserDefaults` unter
//    `data.window.enabled`, `data.window.start` und `app.firstLaunch`; als Liste
//    sieht „nichts eingestellt" genauso aus wie bei den anderen fünf Ständen,
//    nämlich `[]`.
// 2. `dashboardImport` ist eine Liste mit **höchstens einem** Eintrag. Es gibt
//    nur eine Übernahme, aber als optionaler Block hieße „nie importiert"
//    wieder `null` — und genau das soll die Gegenseite nirgends sehen. Abgelegt
//    wird, was in der Datei stand, nicht was daraus gerechnet wurde:
//    `history` und `unknownExerciseIDs` von `ImportedData` sind abgeleitet und
//    gehören nicht in einen Export.
//
// Alle Zahlen und Daten in dieser Datei sind erfunden.

@Suite("App-Export")
struct AppExportTests {

    // MARK: - Erfundene Werte

    private static let generatedText = "2026-03-01T09:15:00Z"
    private static let generated = ISO8601DateFormatter().date(from: generatedText)!

    /// Ein fester Tag, `offset` Tage nach dem Zeitpunkt der Ausgabe.
    private func tag(_ offset: Int) -> Date {
        Self.generated.addingTimeInterval(Double(offset) * 86_400)
    }

    private var leererStand: AppExport.State {
        AppExport.State(sessions: [], circumferences: [], swaps: [],
                        drafts: [], dataWindow: [], dashboardImport: [])
    }

    /// Ein Stand mit mindestens einem Eintrag in jedem der sechs Felder.
    private var vollerStand: AppExport.State {
        AppExport.State(
            sessions: [
                AppExport.Session(
                    id: "2026-02-20-gym-a",
                    date: tag(-9),
                    workout: "gymA",
                    minutes: 52,
                    note: "Erfundener Eintrag",
                    exercises: [
                        AppExport.Exercise(
                            exerciseID: "bankdruecken",
                            sets: [AppExport.ExerciseSet(weight: 42.5, reps: 10),
                                   AppExport.ExerciseSet(weight: 42.5, reps: 8)]),
                        // Negatives Gewicht ist Unterstützung der Maschine und
                        // muss das Vorzeichen behalten.
                        AppExport.Exercise(
                            exerciseID: "klimmzug_assistiert",
                            sets: [AppExport.ExerciseSet(weight: -27, reps: 6)])
                    ])
            ],
            circumferences: [
                AppExport.CircumferenceSample(
                    date: tag(-7),
                    values: ["chest": 101.5, "waist": 84, "thigh": 58.5])
            ],
            swaps: [
                AppExport.Swap(week: 3, first: "Di", second: "Do")
            ],
            drafts: [
                AppExport.Draft(
                    workout: "gymC",
                    date: tag(-1),
                    duration: "35",
                    note: "halb fertig",
                    entries: [
                        "rudern": [
                            AppExport.DraftSet(weight: "35", reps: "12", done: true),
                            AppExport.DraftSet(weight: "35", reps: "", done: false)
                        ]
                    ],
                    assist: ["klimmzug_assistiert": true],
                    savedAt: tag(-1))
            ],
            dataWindow: [
                AppExport.Setting(key: "data.window.enabled", bool: true,
                                  date: nil, text: nil),
                AppExport.Setting(key: "data.window.start", bool: nil,
                                  date: tag(-60), text: nil),
                AppExport.Setting(key: "app.firstLaunch", bool: nil,
                                  date: tag(-90), text: nil)
            ],
            dashboardImport: [
                AppExport.ImportRecord(
                    importedAt: tag(-3),
                    sessions: [
                        AppExport.Session(
                            id: "dash-2025-11-04",
                            date: tag(-120),
                            workout: nil,
                            minutes: nil,
                            note: nil,
                            exercises: [
                                AppExport.Exercise(
                                    exerciseID: "kniebeuge",
                                    sets: [AppExport.ExerciseSet(weight: 60, reps: 5)])
                            ])
                    ],
                    scales: [
                        AppExport.ScaleSample(date: tag(-120), weightKg: 79.4,
                                              bodyFatPct: 18.2, muscleKg: nil,
                                              musclePct: nil)
                    ],
                    circumferences: [
                        AppExport.CircumferenceSample(date: tag(-120),
                                                      values: ["waist": 86])
                    ])
            ])
    }

    private func rundlauf(_ export: AppExport) throws -> AppExport {
        let data = try AppExport.encoder.encode(export)
        return try AppExport.decoder.decode(AppExport.self, from: data)
    }

    // MARK: - Kopf

    @Test("Die Hülle trägt Format und Fassung zwei")
    func kopfTraegtFormatUndFassung() {
        let export = AppExport(generated: Self.generated,
                               timezone: "Europe/Berlin",
                               app: leererStand)
        #expect(export.format == "trainingsexport")
        #expect(export.version == 2)
    }

    @Test("Format und Fassung überleben den Rundlauf")
    func kopfUeberlebtDenRundlauf() throws {
        let export = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: leererStand))
        #expect(export.format == "trainingsexport")
        #expect(export.version == 2)
    }

    @Test("Zeitzone und Zeitpunkt überleben den Rundlauf")
    func zeitzoneUndZeitpunktUeberlebenDenRundlauf() throws {
        let export = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: leererStand))
        #expect(export.timezone == "Europe/Berlin")
        #expect(export.generated == Self.generated)
    }

    @Test("Der Zeitpunkt steht als ISO-8601 in der Datei")
    func zeitpunktStehtAlsISO8601() throws {
        let data = try AppExport.encoder.encode(
            AppExport(generated: Self.generated, timezone: "Europe/Berlin",
                      app: leererStand))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(Self.generatedText),
                "Datumsangaben müssen als ISO-8601 geschrieben werden wie in Fassung 1, nicht als Zahl")
    }

    // MARK: - Leer heißt leere Liste, nicht fehlend

    @Test("Leere Stände ergeben nach dem Rundlauf sechs leere Listen")
    func leereStaendeBleibenLeereListen() throws {
        let export = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: leererStand))
        #expect(export.app.sessions.count == 0)
        #expect(export.app.circumferences.count == 0)
        #expect(export.app.swaps.count == 0)
        #expect(export.app.drafts.count == 0)
        #expect(export.app.dataWindow.count == 0)
        #expect(export.app.dashboardImport.count == 0)
    }

    @Test("Auch ein leerer Stand schreibt alle sechs Schlüssel in die Datei")
    func leererStandSchreibtAlleSechsSchluessel() throws {
        let data = try AppExport.encoder.encode(
            AppExport(generated: Self.generated, timezone: "Europe/Berlin",
                      app: leererStand))
        let text = String(decoding: data, as: UTF8.self)

        #expect(text.contains("\"app\""))
        for schluessel in ["sessions", "circumferences", "swaps", "drafts",
                           "dataWindow", "dashboardImport"] {
            #expect(text.contains("\"\(schluessel)\""),
                    "Der Schlüssel \(schluessel) fehlt im JSON — ein fehlender Stand ist eine leere Liste, kein fehlendes Feld")
        }
    }

    // MARK: - Rundlauf mit allen sechs Ständen

    @Test("Was in alle sechs Stände hineingeht, kommt gleich wieder heraus")
    func rundlaufMitAllenSechsStaenden() throws {
        let hinein = AppExport(generated: Self.generated,
                               timezone: "Europe/Berlin",
                               app: vollerStand)
        let heraus = try rundlauf(hinein)
        #expect(heraus == hinein)
    }

    @Test("Jeder der sechs Stände trägt nach dem Rundlauf seinen Eintrag")
    func jederStandTraegtSeinenEintrag() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        #expect(heraus.app.sessions.count == 1)
        #expect(heraus.app.circumferences.count == 1)
        #expect(heraus.app.swaps.count == 1)
        #expect(heraus.app.drafts.count == 1)
        #expect(heraus.app.dataWindow.count == 3)
        #expect(heraus.app.dashboardImport.count == 1)
    }

    @Test("Ein Training behält Übungen, Sätze und das Vorzeichen der Unterstützung")
    func trainingBehaeltSaetze() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let session = try #require(heraus.app.sessions.first)
        #expect(session.id == "2026-02-20-gym-a")
        #expect(session.workout == "gymA")
        #expect(session.minutes == 52)
        #expect(session.exercises.count == 2)
        #expect(session.exercises[0].sets.count == 2)
        #expect(session.exercises[0].sets[0].weight == 42.5)
        #expect(session.exercises[0].sets[0].reps == 10)
        #expect(session.exercises[1].sets[0].weight == -27)
    }

    @Test("Ein Umfang behält Datum und Rohwerte als Zeichenkette")
    func umfangBehaeltRohwerte() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let umfang = try #require(heraus.app.circumferences.first)
        #expect(umfang.date == tag(-7))
        #expect(umfang.values["chest"] == 101.5)
        #expect(umfang.values["thigh"] == 58.5)
        #expect(umfang.values.count == 3)
    }

    @Test("Ein Tausch behält Woche und beide Tagesmarken")
    func tauschBehaeltTage() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let tausch = try #require(heraus.app.swaps.first)
        #expect(tausch.week == 3)
        #expect(tausch.first == "Di")
        #expect(tausch.second == "Do")
    }

    @Test("Ein Entwurf behält das Getippte, auch den leeren Satz")
    func entwurfBehaeltDasGetippte() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let entwurf = try #require(heraus.app.drafts.first)
        #expect(entwurf.workout == "gymC")
        #expect(entwurf.duration == "35")
        #expect(entwurf.note == "halb fertig")
        #expect(entwurf.savedAt == tag(-1))
        let saetze = try #require(entwurf.entries["rudern"])
        #expect(saetze.count == 2)
        #expect(saetze[0].done == true)
        // Ein angefangener Satz hat ein leeres Feld. Es darf nicht zu `nil`
        // oder zu einer Null werden — der Entwurf hält das Getippte.
        #expect(saetze[1].reps == "")
        #expect(saetze[1].done == false)
        #expect(entwurf.assist["klimmzug_assistiert"] == true)
    }

    @Test("Die Übernahme aus dem Dashboard behält Zeitpunkt, Trainings und Messwerte")
    func dashboardUebernahmeBleibtVollstaendig() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let uebernahme = try #require(heraus.app.dashboardImport.first)
        #expect(uebernahme.importedAt == tag(-3))
        #expect(uebernahme.sessions.count == 1)
        // Ein Dashboard-Training ohne bekanntes Workout bleibt ohne Workout,
        // statt auf irgendeines zu raten.
        #expect(uebernahme.sessions[0].workout == nil)
        #expect(uebernahme.sessions[0].minutes == nil)
        #expect(uebernahme.scales.count == 1)
        #expect(uebernahme.scales[0].weightKg == 79.4)
        #expect(uebernahme.scales[0].muscleKg == nil)
        #expect(uebernahme.circumferences.count == 1)
    }

    // MARK: - Betrachtungszeitraum

    @Test("Der Betrachtungszeitraum trägt den Schlüssel app.firstLaunch")
    func dataWindowTraegtDenErstenStart() throws {
        let heraus = try rundlauf(AppExport(generated: Self.generated,
                                            timezone: "Europe/Berlin",
                                            app: vollerStand))
        let ersterStart = try #require(
            heraus.app.dataWindow.first { $0.key == "app.firstLaunch" })
        #expect(ersterStart.date == tag(-90))

        let grenze = try #require(
            heraus.app.dataWindow.first { $0.key == "data.window.enabled" })
        #expect(grenze.bool == true)
        #expect(grenze.date == nil)
    }

    @Test("Der Schlüssel app.firstLaunch steht wörtlich in der Datei")
    func ersterStartStehtWoertlichInDerDatei() throws {
        let data = try AppExport.encoder.encode(
            AppExport(generated: Self.generated, timezone: "Europe/Berlin",
                      app: vollerStand))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("app.firstLaunch"))
    }

    // MARK: - Fassung 1 darf nicht durchrutschen

    /// Erfundene Werte, keine echten Gesundheitsdaten.
    private static let fassungEins = #"""
    {
      "format": "trainingsexport",
      "version": 1,
      "generated": "2026-03-01T09:15:00Z",
      "timezone": "Europe/Berlin",
      "from": "2026-02-28",
      "to": "2026-03-01",
      "days": [],
      "meals": [],
      "workouts": [],
      "sleep": []
    }
    """#

    @Test("Eine Datei der Fassung 1 geht nicht als leere Fassung 2 durch")
    func fassungEinsIstKeineLeereFassungZwei() {
        // Der Block `app` fehlt. Würde er als leer eingelesen, sähe eine
        // vollständige Datei des alten Formats auf der Gegenseite aus wie
        // „nie trainiert" — und niemand käme darauf, dass nur der Block fehlt.
        #expect(throws: DecodingError.self) {
            try AppExport.decoder.decode(AppExport.self,
                                         from: Data(Self.fassungEins.utf8))
        }
    }

    @Test("Die Fassungsnummer wird gelesen, nicht gesetzt")
    func fassungsnummerWirdGelesen() {
        // Gefahr: `public let version = 2` wird zwar geschrieben, aber nie
        // gelesen — eine Datei mit `"version": 1` käme dann als Fassung 2
        // zurück. Entweder sie wird abgewiesen oder sie behält ihre 1.
        let json = #"""
        {
          "format": "trainingsexport",
          "version": 1,
          "generated": "2026-03-01T09:15:00Z",
          "timezone": "Europe/Berlin",
          "app": {
            "sessions": [], "circumferences": [], "swaps": [],
            "drafts": [], "dataWindow": [], "dashboardImport": []
          }
        }
        """#
        let gelesen = try? AppExport.decoder.decode(AppExport.self,
                                                    from: Data(json.utf8))
        #expect(gelesen?.version != 2,
                "Eine Datei mit \"version\": 1 darf nicht als Fassung 2 zurückkommen")
    }

    @Test("Eine Datei ohne Formatangabe geht nicht durch")
    func dateiOhneFormatangabeGehtNichtDurch() {
        let json = #"""
        { "generated": "2026-03-01T09:15:00Z", "timezone": "Europe/Berlin" }
        """#
        #expect(throws: DecodingError.self) {
            try AppExport.decoder.decode(AppExport.self, from: Data(json.utf8))
        }
    }
}
