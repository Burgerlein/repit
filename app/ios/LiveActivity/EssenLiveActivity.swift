import ActivityKit
import SwiftUI
import WidgetKit

/// Die Essen-Fassung der Live-Aktivität: Sperrbildschirm und Dynamic Island
/// (#365, Spec `2026-11-05-live-aktivitaet-design.md`, „Die Extension";
/// Entwurf `docs/screens/screens/live.js`).
///
/// Die Ansicht entscheidet nichts. Welche Mahlzeit offen ist, liest sie aus
/// `eintrag` und `mahlzeit == "snack"`, das Symbol der Insel aus
/// `ersteOffene`. Gerechnet wird im Kern (`essenKarte`).
struct EssenLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EssenAttributes.self) { context in
            EssenKarte(zustand: context.state, veraltet: context.isStale)
                .activityBackgroundTint(LiveFarbe.karte)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(EssenLink.mahlzeitEintragen)
        } dynamicIsland: { context in
            let ansicht = EssenAnsicht(context.state, veraltet: context.isStale)
            return DynamicIsland {
                // V4: aufgeklappt dieselben vier Ringe wie auf dem
                // Sperrbildschirm.
                DynamicIslandExpandedRegion(.bottom) {
                    RingReihe(ringe: ansicht.ringe)
                        .padding(.top, 4)
                }
            } compactLeading: {
                InselSymbol(emoji: ansicht.inselEmoji)
            } compactTrailing: {
                SerieAnzeige(tage: ansicht.serie)
            } minimal: {
                InselSymbol(emoji: ansicht.inselEmoji)
            }
            .widgetURL(EssenLink.mahlzeitEintragen)
        }
    }
}

/// Der einzige Tippziel-Link (Entscheidung 2): Die ganze Karte öffnet
/// „Mahlzeit eintragen" (V9).
enum EssenLink {
    static let mahlzeitEintragen = URL(string: "repit://mahlzeit-eintragen")
}

/// Was die Karte zeigt — aus dem Zustand gelesen, nicht gerechnet.
struct EssenAnsicht {
    /// Frühstück, Mittagessen, Abendessen, Snacks — die Reihenfolge des
    /// Sperrbildschirms, nicht die des Kanals.
    let ringe: [RingInhalt]
    let serie: Int
    /// Emoji der ersten offenen Hauptmahlzeit, `nil` heißt: keine offen.
    let inselEmoji: String?

    private static let reihenfolge = ["fruehstueck", "mittag", "abend", "snack"]

    init(_ zustand: EssenAttributes.ContentState, veraltet: Bool) {
        // Veraltet (ab 04:00, `staleDate`) ist der leere Morgen: Die Einträge
        // gehören zum Vortag, die Serie ab morgen hat die App schon
        // mitgeschickt.
        ringe = Self.reihenfolge.map { schluessel in
            let eintrag = veraltet ? nil : zustand.mahlzeiten.first { $0.mahlzeit == schluessel }
            let hatEintrag = eintrag?.eintrag ?? false
            let stand: RingStand =
                hatEintrag ? .erledigt : (schluessel == "snack" ? .ruhig : .offen)
            return RingInhalt(
                emoji: Self.emoji(schluessel),
                name: Self.name(schluessel),
                stand: stand,
                kcal: eintrag?.kcal,
                // Veraltet ist `eintrag` hier `nil`: Der leere Morgen liest
                // den Anteil nicht.
                anteil: eintrag?.anteil
            )
        }
        serie = veraltet ? zustand.serieAbMorgen : zustand.serie
        inselEmoji = veraltet
            ? Self.emoji("fruehstueck")
            : zustand.ersteOffene.map(Self.emoji)
    }

    static func emoji(_ mahlzeit: String) -> String {
        switch mahlzeit {
        case "fruehstueck": return "☕️"
        case "mittag": return "🍜"
        case "abend": return "🥗"
        default: return "🍎"
        }
    }

    static func name(_ mahlzeit: String) -> String {
        switch mahlzeit {
        case "fruehstueck": return "Frühstück"
        case "mittag": return "Mittagessen"
        case "abend": return "Abendessen"
        default: return "Snacks"
        }
    }
}

/// Der Sperrbildschirm: Serie oben rechts, darunter die vier Ringe.
struct EssenKarte: View {
    let zustand: EssenAttributes.ContentState
    let veraltet: Bool

    var body: some View {
        let ansicht = EssenAnsicht(zustand, veraltet: veraltet)
        RingReihe(ringe: ansicht.ringe)
            .padding(.top, 22)
            .overlay(alignment: .topTrailing) {
                SerieAnzeige(tage: ansicht.serie)
                    .offset(x: 2, y: -4)
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 18))
    }
}

/// Drei Hauptmahlzeiten, ein Haarstrich, die Snacks.
struct RingReihe: View {
    let ringe: [RingInhalt]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(ringe.prefix(3), id: \.name) { EssenRing(inhalt: $0) }
            // Snacks stehen abgesetzt: Sie sind keine Mahlzeit in der
            // Reihenfolge des Tages, sondern das, was dazwischen passiert.
            Rectangle()
                .fill(LiveFarbe.trenner)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 6)
                .accessibilityHidden(true)
            ForEach(ringe.dropFirst(3), id: \.name) { EssenRing(inhalt: $0) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kompakt links und minimal: das Emoji der ersten offenen Hauptmahlzeit,
/// ein blauer Haken, wenn keine offen ist (V4).
struct InselSymbol: View {
    let emoji: String?

    var body: some View {
        Group {
            if let emoji {
                Text(emoji)
                    .font(.system(size: 17))
                    .accessibilityLabel("\(EssenAnsicht.nameZumEmoji(emoji)) offen")
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LiveFarbe.blau)
                    .accessibilityLabel("Alle Mahlzeiten eingetragen")
            }
        }
    }
}

extension EssenAnsicht {
    static func nameZumEmoji(_ emoji: String) -> String {
        reihenfolge.first { Self.emoji($0) == emoji }.map(name) ?? "Mahlzeit"
    }
}

// MARK: - Vorschau (erfundene Werte, keine echten Gesundheitsdaten)

extension EssenAttributes.ContentState {
    fileprivate static let offen = Self(
        mahlzeiten: [
            .init(mahlzeit: "fruehstueck", eintrag: true, kcal: 686),
            .init(mahlzeit: "mittag", eintrag: true, kcal: 813),
            .init(mahlzeit: "snack", eintrag: true, kcal: 168),
            .init(mahlzeit: "abend", eintrag: false, kcal: nil),
        ],
        ersteOffene: "abend",
        serie: 10,
        serieAbMorgen: 11
    )

    fileprivate static let fertig = Self(
        mahlzeiten: [
            .init(mahlzeit: "fruehstueck", eintrag: true, kcal: 686),
            .init(mahlzeit: "mittag", eintrag: true, kcal: 813),
            .init(mahlzeit: "snack", eintrag: true, kcal: 168),
            .init(mahlzeit: "abend", eintrag: true, kcal: 1126),
        ],
        ersteOffene: nil,
        serie: 10,
        serieAbMorgen: 11
    )

    /// Ringe als Anteil (#374, V15) — die erfundenen Zahlen aus
    /// `ESSEN_ANTEIL` in `live.js`: Ziele 600, 840, 720 und 240 kcal.
    /// Frühstück 686 / 600 läuft eine zweite Runde, Abend ist offen.
    fileprivate static let anteilOffen = Self(
        mahlzeiten: [
            .init(mahlzeit: "fruehstueck", eintrag: true, kcal: 686, anteil: 1.14),
            .init(mahlzeit: "mittag", eintrag: true, kcal: 813, anteil: 0.97),
            .init(mahlzeit: "snack", eintrag: true, kcal: 168, anteil: 0.7),
            .init(mahlzeit: "abend", eintrag: false, kcal: nil),
        ],
        ersteOffene: "abend",
        serie: 10,
        serieAbMorgen: 11
    )

    /// Abends eingetragen, 1.126 / 720: zweite Runde, nicht rot.
    fileprivate static let anteilFertig = Self(
        mahlzeiten: [
            .init(mahlzeit: "fruehstueck", eintrag: true, kcal: 686, anteil: 1.14),
            .init(mahlzeit: "mittag", eintrag: true, kcal: 813, anteil: 0.97),
            .init(mahlzeit: "snack", eintrag: true, kcal: 168, anteil: 0.7),
            .init(mahlzeit: "abend", eintrag: true, kcal: 1126, anteil: 1.56),
        ],
        ersteOffene: nil,
        serie: 10,
        serieAbMorgen: 11
    )
}

#Preview("Essen — offen", as: .content, using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.offen
}

#Preview("Essen — fertig", as: .content, using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.fertig
}

#Preview("Essen — Ringe als Anteil", as: .content, using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.anteilOffen
}

#Preview("Essen — Anteil, Tag vollständig", as: .content, using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.anteilFertig
}

/// `isStale` lässt sich in der Vorschau nicht setzen; deshalb steht hier die
/// Karte selbst, mit `veraltet: true`.
#Preview("Essen — veraltet (ab 04:00)") {
    EssenKarte(zustand: .offen, veraltet: true)
        .background(LiveFarbe.karte)
}

#Preview("Insel — kompakt", as: .dynamicIsland(.compact), using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.offen
    EssenAttributes.ContentState.fertig
}

#Preview("Insel — aufgeklappt", as: .dynamicIsland(.expanded), using: EssenAttributes()) {
    EssenLiveActivity()
} contentStates: {
    EssenAttributes.ContentState.offen
}
