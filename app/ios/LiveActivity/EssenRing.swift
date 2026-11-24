import SwiftUI

/// Farben der Live-Aktivität — bewusst Apple-Blau und System-Grau statt der
/// Palette der App: Die Karte liegt auf dem Sperrbildschirm neben
/// System-Elementen, nicht in der App (`live.js`).
enum LiveFarbe {
    static let karte = Color(red: 0x0C / 255, green: 0x0C / 255, blue: 0x0E / 255)
    static let blau = Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255)
    /// Die Runden eines Rings mit Anteil, jede weitere heller (V15,
    /// `LIVE_RUNDEN` in `docs/screens/components.js`). Nie Rot.
    static let runden: [Color] = [
        blau,
        Color(red: 0x5E / 255, green: 0xAE / 255, blue: 0xFF / 255),
        Color(red: 0x9C / 255, green: 0xCD / 255, blue: 0xFF / 255),
    ]
    static let grau = Color(red: 0x98 / 255, green: 0x98 / 255, blue: 0x9F / 255)
    static let serie = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
    static let spur = Color.white.opacity(0.14)
    static let trenner = Color.white.opacity(0.16)
    /// 22 % Weiß über der Kartenfarbe, vorab gemischt. Durchscheinend
    /// stünde der Ring unter dem Abzeichen sichtbar durch.
    static let abzeichenRuhig = Color(red: 0.257, green: 0.257, blue: 0.263)
}

/// Wie ein Ring steht. Gelesen aus `eintrag` und `mahlzeit == "snack"`,
/// nicht entschieden: Die Rechnung liegt im Kern.
enum RingStand: Hashable {
    /// Hauptmahlzeit ohne Eintrag — eine Aufgabe. Steht hell.
    case offen
    /// Snack ohne Eintrag — keine Aufgabe. Plus, aber grau.
    case ruhig
    /// Mit Eintrag. Steht grau, mit Haken.
    case erledigt
}

/// Was ein Ring zeigt.
struct RingInhalt: Hashable {
    let emoji: String
    let name: String
    let stand: RingStand
    /// `nil` heißt „kein Wert" und steht als „–", nie als „0 kcal".
    let kcal: Int?
    /// Gegessen durch Ziel der Mahlzeit; `nil` heißt „kein Ziel" (V2).
    let anteil: Double?

    /// Wie viele Runden höchstens — dieselbe Deckelung wie im Kern
    /// (`rundenHoechstens`, V6).
    static let rundenHoechstens = 3

    /// Das kleinste Stück, das ein Ring mit Eintrag zeigt, als Anteil eines
    /// Umlaufs — derselbe Wert wie `MahlzeitRing.mindestausschlag` in der
    /// App. Sonst sähe „2 von 450 kcal gegessen" aus wie „nichts
    /// eingetragen". Darstellung, keine Rechnung: Der Anteil bleibt, wie
    /// der Kern ihn schickt.
    static let mindestausschlag = 0.03

    /// Die Runden, die der Ring zeichnet, je eine Zahl von 0 bis 1.
    ///
    /// - Ohne Eintrag: keine, nur die Spur — auch wenn ein Anteil dabei
    ///   wäre. Hell, ruhig und erledigt hängen am Eintrag (V15).
    /// - Mit Eintrag, ohne Anteil: V2, eine volle Runde.
    /// - Mit Eintrag und Anteil: dieselbe Regel wie `anteilRunden` im Kern
    ///   (hier nachgebaut, die Extension kennt den Dart-Kern nicht), höchstens
    ///   drei, mit Mindestausschlag.
    var runden: [Double] {
        guard stand == .erledigt else { return [] }
        guard let anteil else { return [1] }
        var rest = anteil.isFinite ? min(anteil, Double(Self.rundenHoechstens)) : 0
        var runden: [Double] = []
        while rest > 0, runden.count < Self.rundenHoechstens {
            runden.append(min(rest, 1))
            rest -= 1
        }
        if runden.isEmpty { return [Self.mindestausschlag] }
        if runden.count == 1, runden[0] < Self.mindestausschlag {
            return [Self.mindestausschlag]
        }
        return runden
    }
}

/// Ein Mahlzeiten-Ring: Fortschritt außen, Symbol innen, unten rechts das
/// Abzeichen, darunter Name und Kalorien (`mealRing` in
/// `docs/screens/components.js`).
///
/// **Eine Form für alle Zustände.** Offen, ruhig und erledigt haben dieselbe
/// Höhe und Breite; „–" und „1.126 kcal" stehen in derselben Zeile, und
/// keine Zeile fällt weg.
struct EssenRing: View {
    let inhalt: RingInhalt

    private static let durchmesser: CGFloat = 62
    private static let strich: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            ring
            Text(inhalt.name)
                .font(.system(size: 13, weight: inhalt.stand == .offen ? .bold : .semibold))
                .foregroundStyle(inhalt.stand == .offen ? Color.white : LiveFarbe.grau)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 7)
            Text(kcalText)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(inhalt.stand == .offen ? Color.white : LiveFarbe.grau)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(vorlesetext)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(LiveFarbe.spur, lineWidth: Self.strich)
            // Ab 12 Uhr im Uhrzeigersinn. Mit Anteil bis zu drei Runden,
            // jede heller, über 1 nie rot (V15); ohne Anteil V2, voll mit
            // Eintrag, leer ohne.
            ForEach(Array(inhalt.runden.enumerated()), id: \.offset) { k, runde in
                Circle()
                    .inset(by: Self.strich / 2)
                    .trim(from: 0, to: runde)
                    .stroke(
                        LiveFarbe.runden[min(k, LiveFarbe.runden.count - 1)],
                        style: StrokeStyle(lineWidth: Self.strich, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Text(inhalt.emoji)
                .font(.system(size: 25))
        }
        .frame(width: Self.durchmesser, height: Self.durchmesser)
        .overlay(alignment: .bottomTrailing) {
            abzeichen.offset(x: 3, y: 1)
        }
    }

    private var abzeichen: some View {
        Image(systemName: inhalt.stand == .erledigt ? "checkmark" : "plus")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 23, height: 23)
            .background(
                Circle().fill(inhalt.stand == .ruhig ? LiveFarbe.abzeichenRuhig : LiveFarbe.blau)
            )
            .background(Circle().fill(LiveFarbe.karte).padding(-3))
    }

    private var kcalText: String {
        guard let kcal = inhalt.kcal else { return "–" }
        return Zahl.kcal(kcal)
    }

    /// Nennt den Zustand, nicht das Zeichen: nie „Strich".
    private var vorlesetext: String {
        if let kcal = inhalt.kcal {
            return "\(inhalt.name), \(Zahl.ganz(kcal)) Kilokalorien"
        }
        switch inhalt.stand {
        case .offen: return "\(inhalt.name), noch kein Eintrag"
        case .ruhig: return "\(inhalt.name), keine Werte"
        case .erledigt: return "\(inhalt.name), eingetragen, keine Werte"
        }
    }
}

/// Die Serie: 🔥 und die Zahl. Auch 0 steht so da (V11).
struct SerieAnzeige: View {
    let tage: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("🔥")
            Text(Zahl.ganz(tage)).monospacedDigit()
        }
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(LiveFarbe.serie)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Serie \(Zahl.ganz(tage)) \(tage == 1 ? "Tag" : "Tage")")
    }
}

/// Zahlen mit fester deutscher Formatierung — nie `formatted()` ohne
/// Sprache, sonst steht auf einem englisch eingestellten Gerät „1,126".
enum Zahl {
    private static let format: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    static func ganz(_ n: Int) -> String {
        format.string(from: NSNumber(value: n)) ?? String(n)
    }

    static func kcal(_ n: Int) -> String {
        "\(ganz(n)) kcal"
    }
}
