import Foundation

public enum Workout: String, CaseIterable, Sendable, Hashable, Codable {
    case a = "A", b = "B", c = "C", d = "D"
    case push = "Push", pull = "Pull", legs = "Legs"

    /// Die Workouts der geplanten Wochenrotation. Nur diese bekommen einen
    /// Platz in der Wochenleiste und können „heute" oder überfällig werden.
    public static let rotation: [Workout] = [.a, .b, .c, .d]

    /// Workouts ohne festen Tag, die man sich nimmt, wenn Zeit ist.
    ///
    /// Bewusst **neben** der Rotation und nicht in ihr: Ein Platz in der
    /// Woche, der nie fällig wird, wäre eine Kachel, die dauerhaft „offen"
    /// sagt — und nach drei Wochen glaubt man ihr nicht mehr.
    public static let freelyChosen: [Workout] = [.push, .pull, .legs]

    public var title: String {
        switch self {
        case .a: "Oberkörper Push + Arme"
        case .b: "Läufer-Kraft + Brust"
        case .c: "Oberkörper Pull + Arme"
        case .d: "Arme + Schultern"
        case .push: "Brust, Schultern, Trizeps"
        case .pull: "Rücken, hintere Schulter, Bizeps"
        case .legs: "Beine komplett"
        }
    }

    /// Ungefähre Dauer in Minuten.
    public var minutes: Int {
        switch self {
        case .a, .c, .push, .pull: 70
        case .b: 65
        case .d, .legs: 60
        }
    }

    /// Wie die Ansicht das Workout benennt. „Gym A" trägt den Buchstaben
    /// allein nicht — „Push" dagegen schon, und „Gym Push" läse sich falsch.
    ///
    /// Zusammen mit `title` ergibt das überall dieselbe Form:
    /// „Gym A — Oberkörper Push + Arme" und „Push — Brust, Schultern,
    /// Trizeps". Deshalb wiederholt `title` den Namen nicht.
    public var label: String {
        Workout.rotation.contains(self) ? "Gym \(rawValue)" : rawValue
    }
}

public struct Exercise: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let sets: Int
    public let repLow: Int
    public let repHigh: Int
    /// Schrittweite in kg; bei Zeitübungen in Sekunden.
    public let increment: Double
    /// Sekunden statt Wiederholungen — betrifft nur den Seitstütz.
    public let isTimed: Bool
    /// Umschalter Zusatzgewicht/Unterstützung. Unterstützung wird negativ
    /// gespeichert: −27 bedeutet 27 kg Hilfe von der Maschine.
    public let allowsAssist: Bool
    public let cue: String
    public let howTo: [String]
    public let commonMistake: String
    public let youTubeQuery: String
    public let muscles: [Muscle: Double]

    public init(id: String, name: String, sets: Int, repLow: Int, repHigh: Int,
                increment: Double, isTimed: Bool = false, allowsAssist: Bool = false,
                cue: String, howTo: [String], commonMistake: String,
                youTubeQuery: String, muscles: [Muscle: Double]) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repLow = repLow
        self.repHigh = repHigh
        self.increment = increment
        self.isTimed = isTimed
        self.allowsAssist = allowsAssist
        self.cue = cue
        self.howTo = howTo
        self.commonMistake = commonMistake
        self.youTubeQuery = youTubeQuery
        self.muscles = muscles
    }

    /// Adresse der YouTube-Suche. Die App bettet nichts ein, sie öffnet nur.
    public var youTubeSearchURL: URL? {
        var c = URLComponents(string: "https://www.youtube.com/results")
        c?.queryItems = [URLQueryItem(name: "search_query", value: youTubeQuery)]
        return c?.url
    }
}
