import Foundation

/// Die Hülle, die die eingefrorene Swift-App herausgibt, damit die Flutter-App
/// den Stand übernehmen kann.
///
/// Reine Struktur: kein `FileManager`, kein Dateizugriff. Das Einsammeln der
/// sechs Stände liegt in der Ansicht, die die Stores kennt — hier steht nur,
/// welche Gestalt die Datei hat.
///
/// Alle Spiegel sind **geschachtelt und hängen an keinem anderen Typ des
/// Kerns**. Das ist Absicht: Die Hülle ist ein Austauschformat. Änderte sich
/// `ImportedSession` oder `CompletedSet`, änderte sich sonst stillschweigend
/// die Datei, die auf der Gegenseite gelesen wird.
public struct AppExport: Codable, Equatable, Sendable {

    /// Immer `"trainingsexport"`. **Ohne Anfangswert**, damit das Feld beim
    /// Einlesen wirklich gelesen wird: Ein `let format = "trainingsexport"`
    /// ließe Swift beim Decodieren aus, und eine Datei ohne Formatangabe
    /// käme als gültige Hülle zurück.
    public let format: String

    /// Immer `2`. Aus demselben Grund ohne Anfangswert — eine Datei mit
    /// `"version": 1` darf nicht als Fassung 2 zurückkommen.
    public let version: Int

    public let generated: Date

    /// Zeitzone des Geräts, etwa `"Europe/Berlin"`. Die Daten tragen einen
    /// Zeitpunkt, keinen Tag; ohne die Zone kann die Gegenseite den Tag nicht
    /// zurückrechnen.
    public let timezone: String

    /// Die sechs Stände. **Nicht optional und ohne Vorgabewert**: Sonst liefe
    /// eine vollständige Datei der Fassung 1, die diesen Block nicht kennt,
    /// als leere Fassung 2 durch und sähe aus wie „nie trainiert".
    public let app: State

    public init(generated: Date, timezone: String, app: State) {
        self.format = Self.formatName
        self.version = Self.currentVersion
        self.generated = generated
        self.timezone = timezone
        self.app = app
    }

    public static let formatName = "trainingsexport"
    public static let currentVersion = 2

    // MARK: - Die sechs Stände

    /// Jeder Stand ist eine Liste und nie `nil`. „Nichts da" ist überall `[]`,
    /// damit die Gegenseite nirgends zwischen leer und fehlend unterscheiden
    /// muss.
    public struct State: Codable, Equatable, Sendable {
        public var sessions: [Session]
        public var circumferences: [CircumferenceSample]
        public var swaps: [Swap]
        public var drafts: [Draft]
        /// Der Betrachtungszeitraum als Schlüssel-Wert-Paare statt als Block
        /// mit drei Feldern: So sieht „nichts eingestellt" genauso aus wie bei
        /// den anderen fünf Ständen, nämlich `[]`.
        public var dataWindow: [Setting]
        /// Höchstens ein Eintrag. Es gibt nur eine Übernahme, aber als
        /// optionaler Block hieße „nie importiert" wieder `null`.
        public var dashboardImport: [ImportRecord]

        public init(sessions: [Session], circumferences: [CircumferenceSample],
                    swaps: [Swap], drafts: [Draft], dataWindow: [Setting],
                    dashboardImport: [ImportRecord]) {
            self.sessions = sessions
            self.circumferences = circumferences
            self.swaps = swaps
            self.drafts = drafts
            self.dataWindow = dataWindow
            self.dashboardImport = dashboardImport
        }
    }

    // MARK: - Trainings

    public struct Session: Codable, Equatable, Sendable {
        public var id: String
        public var date: Date
        /// `nil`, wenn die Quelle kein oder ein unbekanntes Workout führt. Auf
        /// eines zu raten wäre schlimmer als die Lücke.
        public var workout: String?
        public var minutes: Int?
        public var note: String?
        public var exercises: [Exercise]

        public init(id: String, date: Date, workout: String?, minutes: Int?,
                    note: String?, exercises: [Exercise]) {
            self.id = id
            self.date = date
            self.workout = workout
            self.minutes = minutes
            self.note = note
            self.exercises = exercises
        }
    }

    public struct Exercise: Codable, Equatable, Sendable {
        public var exerciseID: String
        public var sets: [ExerciseSet]

        public init(exerciseID: String, sets: [ExerciseSet]) {
            self.exerciseID = exerciseID
            self.sets = sets
        }
    }

    public struct ExerciseSet: Codable, Equatable, Sendable {
        /// Negativ bedeutet Unterstützung der Maschine: −27 sind 27 kg Hilfe.
        /// Das Vorzeichen bleibt stehen.
        public var weight: Double
        /// Bei Zeitübungen Sekunden.
        public var reps: Int

        public init(weight: Double, reps: Int) {
            self.weight = weight
            self.reps = reps
        }
    }

    // MARK: - Umfänge

    public struct CircumferenceSample: Codable, Equatable, Sendable {
        public var date: Date
        /// Rohwerte des Maßes als Zeichenkette — `thigh`, nicht `thighRight`.
        /// Gespiegelt wird, was auf der Platte steht, nicht was das Enum
        /// daraus macht.
        public var values: [String: Double]

        public init(date: Date, values: [String: Double]) {
            self.date = date
            self.values = values
        }
    }

    // MARK: - Plan

    public struct Swap: Codable, Equatable, Sendable {
        public var week: Int
        public var first: String
        public var second: String

        public init(week: Int, first: String, second: String) {
            self.week = week
            self.first = first
            self.second = second
        }
    }

    // MARK: - Angefangene Trainings

    public struct Draft: Codable, Equatable, Sendable {
        public var workout: String
        public var date: Date
        public var duration: String
        public var note: String
        /// Übungs-ID auf ihre Sätze.
        public var entries: [String: [DraftSet]]
        /// Übungs-ID auf „Unterstützung statt Zusatzgewicht".
        public var assist: [String: Bool]
        public var savedAt: Date

        public init(workout: String, date: Date, duration: String, note: String,
                    entries: [String: [DraftSet]], assist: [String: Bool],
                    savedAt: Date) {
            self.workout = workout
            self.date = date
            self.duration = duration
            self.note = note
            self.entries = entries
            self.assist = assist
            self.savedAt = savedAt
        }
    }

    /// Zeichenketten, weil ein Entwurf das Getippte hält, nicht das
    /// Gerechnete. Ein halb ausgefülltes Feld ist `""` und darf weder `nil`
    /// noch `0` werden — beides behauptete etwas, das niemand eingetippt hat.
    public struct DraftSet: Codable, Equatable, Sendable {
        public var weight: String
        public var reps: String
        public var done: Bool

        public init(weight: String, reps: String, done: Bool) {
            self.weight = weight
            self.reps = reps
            self.done = done
        }
    }

    // MARK: - Einstellungen

    /// Ein Wert aus den Einstellungen. Genau eines der drei Felder ist gesetzt.
    public struct Setting: Codable, Equatable, Sendable {
        public var key: String
        public var bool: Bool?
        public var date: Date?
        public var text: String?

        public init(key: String, bool: Bool? = nil, date: Date? = nil,
                    text: String? = nil) {
            self.key = key
            self.bool = bool
            self.date = date
            self.text = text
        }
    }

    // MARK: - Übernahme aus dem Dashboard

    /// Abgelegt wird, was in der übernommenen Datei stand, nicht was daraus
    /// gerechnet wurde: `history` und `unknownExerciseIDs` sind abgeleitet und
    /// gehören nicht in einen Export.
    public struct ImportRecord: Codable, Equatable, Sendable {
        public var importedAt: Date?
        public var sessions: [Session]
        public var scales: [ScaleSample]
        public var circumferences: [CircumferenceSample]

        public init(importedAt: Date?, sessions: [Session],
                    scales: [ScaleSample],
                    circumferences: [CircumferenceSample]) {
            self.importedAt = importedAt
            self.sessions = sessions
            self.scales = scales
            self.circumferences = circumferences
        }
    }

    public struct ScaleSample: Codable, Equatable, Sendable {
        public var date: Date
        public var weightKg: Double?
        public var bodyFatPct: Double?
        public var muscleKg: Double?
        public var musclePct: Double?

        public init(date: Date, weightKg: Double?, bodyFatPct: Double?,
                    muscleKg: Double?, musclePct: Double?) {
            self.date = date
            self.weightKg = weightKg
            self.bodyFatPct = bodyFatPct
            self.muscleKg = muscleKg
            self.musclePct = musclePct
        }
    }

    // MARK: - Codierer

    /// ISO-8601 wie in Fassung 1 und wie in allen Stores. Eine Zahl stünde
    /// zwar auch in der Datei, wäre aber von Hand nicht lesbar und auf der
    /// Gegenseite ein stiller Umrechnungsfehler.
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys,
                                    .withoutEscapingSlashes]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
