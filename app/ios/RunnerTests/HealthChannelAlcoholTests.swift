import Foundation
import HealthKit
import Testing
import TrainingsCore
@testable import Runner

/// Alkohol auf dem Weg durch den Kanal (#125).
///
/// Die Verlaufszeile „Alkohol-Tage" soll sich von selbst füllen, statt
/// eingetippt zu werden. Dafür muss ein Alkoholwert als Tageswert ankommen.
///
/// ## Welcher Typ — und warum nicht der aus dem Ticket
///
/// #125 nennt `dietaryAlcohol` als „eigenen Nährwert" in Apple Health.
/// **Den gibt es nicht.** HealthKit kennt im iOS-26.1-SDK genau zwei
/// Alkoholtypen (`HKTypeIdentifiers.h`, Zeilen 136 und 140):
///
/// | Bezeichner | Einheit |
/// |---|---|
/// | `HKQuantityTypeIdentifierBloodAlcoholContent` | %, diskret — ein Messgerät, kein Tagebuch |
/// | `HKQuantityTypeIdentifierNumberOfAlcoholicBeverages` | **count, kumulativ** — ab iOS 15 |
///
/// Unter den 38 `HKQuantityTypeIdentifierDietary…`-Typen ist keiner für
/// Alkohol. Gelesen wird deshalb die **Zahl der Getränke**, nicht Gramm —
/// und eine Umrechnung „ein Getränk sind soundso viel Gramm" findet nicht
/// statt, die wäre erfunden.
///
/// **Beide Typen stehen bereits im Katalog.** Der Berechtigungsdialog
/// braucht also keinen neuen Eintrag, und die Neuinstallation, die Tim dafür
/// in Kauf genommen hätte, entfällt. Der erste Fall unten hält genau das
/// fest: Fiele der Eintrag je aus dem Katalog, bliebe die Zeile stumm und
/// niemand wüsste warum.
///
/// ## Der Vertrag des Kanals
///
/// `nil` darf auf dem Weg durch den Kanal niemals zu `0` werden (Spec 8.2,
/// `CLAUDE.md`) — ein fehlendes Feld fehlt in der Map, es steht nicht mit
/// Nullwert drin. Bei Alkohol wiegt das schwerer als anderswo: Eine
/// erfundene `0` wäre eine Behauptung über das Verhalten des Nutzers, die
/// auf einer fehlenden Freigabe beruhen kann. Apple verrät den Lesestatus
/// nicht.
///
/// **Keine Korrelationstypen.** `HKCorrelationTypeIdentifierFood` in der
/// Leseanfrage löst eine `NSInvalidArgumentException` aus und die App
/// stürzt ab. `NumberOfAlcoholicBeverages` ist ein `HKQuantityType` und
/// damit unbedenklich; der letzte Katalogfall hält fest, dass der Katalog
/// frei von Korrelationstypen bleibt.
///
/// Swift Testing, nicht XCTest — wie überall sonst in diesem Projekt.
/// Alle Zahlen sind erfunden; echte Gesundheitsdaten stehen nie im Quelltext.
@Suite("Alkohol geht als Tageswert durch den Kanal")
struct HealthChannelAlcoholTests {

    /// 23.10.2026, 00:00 UTC. Wie in `HealthChannelTests.swift`: Der genaue
    /// Zeitpunkt ist für diese Fälle ohne Bedeutung.
    private let tag = Date(timeIntervalSince1970: 1_792_195_200)

    // MARK: - Der Typenkatalog

    @Test("Der Katalog fragt die Zahl der alkoholischen Getraenke mit an")
    func katalogEnthaeltGetraenkezahl() {
        #expect(
            HealthTypeCatalog.allReadableTypeIdentifiers
                .contains("HKQuantityTypeIdentifierNumberOfAlcoholicBeverages"),
            "es gibt genau einen Berechtigungsdialog je Installation — was hier fehlt, kostet eine Neuinstallation"
        )
    }

    @Test("Der Bezeichner ist echt und landet als Typ in der Leseanfrage")
    func getraenkezahlIstLesbarerTyp() {
        let typ = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)
        #expect(typ != nil)
        #expect(HealthTypeCatalog.allReadableTypes.contains(typ!))
    }

    @Test("Einen Naehrwert Alkohol gibt es in HealthKit nicht")
    func keinNaehrwertAlkohol() {
        // Die Begründung dafür, dass oben die Getränkezahl steht und nicht
        // der Nährwert aus #125. Schafft Apple den Typ später an, fällt
        // dieser Fall um und die Entscheidung kommt noch einmal auf den
        // Tisch — genau dann, wenn sie es soll.
        let erfunden = HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifierDietaryAlcohol")
        #expect(
            HKObjectType.quantityType(forIdentifier: erfunden) == nil,
            "gaebe es ihn, waere er die bessere Quelle — er traegt eine Menge statt einer Zahl"
        )
    }

    @Test("Der Katalog bleibt frei von Korrelationstypen")
    func katalogBleibtOhneKorrelationstypen() {
        let ids = HealthTypeCatalog.allReadableTypeIdentifiers
        #expect(!ids.contains { $0.hasPrefix("HKCorrelationTypeIdentifier") })
    }

    // MARK: - Der Codec

    @Test("Ein fehlender Alkoholwert fehlt in der Map")
    func fehlenderAlkoholwertFehltInDerMap() {
        let metrics = DailyMetrics(date: tag)
        let map = HealthChannel.alsMap(metrics)
        #expect(
            !map.keys.contains("alcoholicDrinks"),
            "kein Wert ist kein Nullwert — sonst hiesse jeder unfreigegebene Tag „nichts getrunken\""
        )
    }

    @Test("Ein gesetzter Alkoholwert erscheint unveraendert")
    func gesetzterAlkoholwertErscheintUnveraendert() {
        let metrics = DailyMetrics(date: tag, alcoholicDrinks: 2)
        let map = HealthChannel.alsMap(metrics)
        #expect(map["alcoholicDrinks"] as? Double == 2)
    }

    @Test("Ein halbes Getraenk bleibt ein halbes Getraenk")
    func halbesGetraenkBleibtHalb() {
        // `count` ist in HealthKit kein Ganzzahltyp; ein Tagebuch darf 0,5
        // eintragen. Auf `Int` zu runden hiesse, einen halben Abend
        // verschwinden zu lassen.
        let metrics = DailyMetrics(date: tag, alcoholicDrinks: 0.5)
        let map = HealthChannel.alsMap(metrics)
        #expect(map["alcoholicDrinks"] as? Double == 0.5)
    }

    @Test("Eine echte 0 bleibt in der Map stehen")
    func echteNullBleibtInDerMap() {
        let metrics = DailyMetrics(date: tag, alcoholicDrinks: 0)
        let map = HealthChannel.alsMap(metrics)
        #expect(
            map.keys.contains("alcoholicDrinks"),
            "0 Getraenke ist ein gemessener Wert und etwas anderes als gar kein Wert"
        )
        #expect(map["alcoholicDrinks"] as? Double == 0.0)
    }

    @Test("Alkohol nimmt den uebrigen Feldern nichts weg")
    func alkoholNimmtDenUebrigenFeldernNichts() {
        let metrics = DailyMetrics(date: tag, steps: 0, hrvMs: 42.5, alcoholicDrinks: 3)
        let map = HealthChannel.alsMap(metrics)
        #expect(map["steps"] as? Int == 0)
        #expect(map["hrvMs"] as? Double == 42.5)
        #expect(map["alcoholicDrinks"] as? Double == 3)
        #expect(!map.keys.contains("restingHR"))
    }
}
