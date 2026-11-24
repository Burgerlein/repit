import ActivityKit
import Foundation

/// Die Essen-Fassung der Live-Aktivität (#276, #365).
///
/// Gehört zu **beiden** Zielen, Runner und LiveActivity: ActivityKit findet
/// eine Aktivität über ihren Typ, also muss die App denselben Typ kennen wie
/// die Extension, die ihn zeichnet.
///
/// Statische Attribute gibt es keine. Alles steht im `ContentState`, den der
/// Kern rechnet (`essenKarte` in `trainings_core`) und die App über den Kanal
/// `de.rosenbach.repit/live` schickt. Die Kodierung aus der
/// Kanal-Map kommt mit #366 (Task 4); hier steht nur der Typ.
struct EssenAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {

        struct Mahlzeit: Codable, Hashable {
            /// `"fruehstueck"`, `"mittag"`, `"snack"` oder `"abend"`.
            let mahlzeit: String
            /// Ob es zu dieser Mahlzeit einen Eintrag gibt.
            let eintrag: Bool
            /// Gerundete Kilokalorien. `nil` heißt: kein Wert, nie `0`.
            let kcal: Int?
            /// Gegessen durch Ziel der Mahlzeit, gedeckelt auf 3,0 (V6, V15
            /// in `2026-11-10-mahlzeiten-aufteilung-design.md`). Nur bei
            /// Eintrag und Ziel gesetzt; `nil` heißt „kein Ziel", und die
            /// Karte zeichnet V2 (voll bei Eintrag). Ein `0` bleibt `0`.
            ///
            /// Optional mit Vorgabe `nil`: Ein Zustand, den ActivityKit vor
            /// #374 abgelegt hat, kennt den Schlüssel nicht und dekodiert
            /// trotzdem (`decodeIfPresent` der synthetisierten Kodierung).
            let anteil: Double?

            init(mahlzeit: String, eintrag: Bool, kcal: Int?, anteil: Double? = nil) {
                self.mahlzeit = mahlzeit
                self.eintrag = eintrag
                self.kcal = kcal
                self.anteil = anteil
            }
        }

        /// Immer vier, in der Reihenfolge `fruehstueck`, `mittag`, `snack`,
        /// `abend` (`Mahlzeit.values` im Kern).
        let mahlzeiten: [Mahlzeit]
        /// Die erste Hauptmahlzeit ohne Eintrag, `nil`, wenn keine offen ist.
        let ersteOffene: String?
        /// Esstage am Stück mit mindestens einem Eintrag, Stand heute.
        let serie: Int
        /// Die Serie, die ab dem nächsten Esstag gilt. Die Karte zeigt sie,
        /// sobald sie um 04:00 veraltet.
        let serieAbMorgen: Int
    }
}
