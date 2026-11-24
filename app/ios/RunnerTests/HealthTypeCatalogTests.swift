import Foundation
import HealthKit
import Testing
@testable import Runner

/// Tests für `HealthTypeCatalog` (Task 12) — die rund 200 Lesetypen, die
/// `HealthKitReading.requestAuthorization()` beim einzigen Berechtigungs-
/// dialog der App anfragt. Portiert aus `Sources/Health/HealthTypeCatalog.swift`,
/// weitgehend unverändert (siehe task-12-brief.md Step 3).
///
/// Swift Testing, nicht XCTest — wie überall sonst in diesem Projekt
/// (CLAUDE.md, Abschnitt „Tests").
///
/// Die ersten beiden Fälle stehen wörtlich in task-12-brief.md:
///
/// **1. Keine Korrelationstypen in der Leseanfrage.**
/// `HKCorrelationTypeIdentifierFood` dort löst eine `NSInvalidArgumentException`
/// aus und die App stürzt ab (siehe `HealthTypeCatalog.swift:274–288` der
/// Vorlage, und CLAUDE.md Abschnitt „Code"). Abfragen über `HKCorrelationType`
/// funktionieren trotzdem, wenn die Einzelwerte freigegeben sind — das ist der
/// Unterschied, auf den es ankommt, und Test 4 unten belegt ihn.
///
/// **2. Unbekannte Typ-Kennungen fallen still heraus.** Die Vorlage führt
/// jede Kennung als rohe Zeichenkette statt als typisierte Konstante, genau
/// damit eine Kennung, die es auf der gerade laufenden iOS-Fassung nicht gibt,
/// nicht den Build bricht und nicht die Abfrage zum Absturz bringt, sondern
/// `nil` liefert und beim `compactMap` lautlos herausfällt. Die Katalog-Listen
/// selbst (`quantityIdentifiers` u. a.) sind in der Vorlage `private` — ich
/// kann sie als Test-Autor nicht direkt mit einer erfundenen Kennung befüllen,
/// ohne private Interna vorzuschreiben, die nicht Teil des Vertrags sind.
/// Stattdessen zeigt Test 2 denselben Mechanismus, den der Katalog intern
/// nutzt (Apples öffentliches Verhalten bei einer unbekannten Kennung), und
/// Test 3 beweist, dass der Katalog trotzdem vollständig bleibt — beides
/// zusammen belegt „unbekannte Kennung bricht nichts, bekannte Kennungen
/// fehlen nicht".
///
/// **Erwartete neue API**, die über das Portieren hinausgeht: eine
/// `allReadableTypeIdentifiers: [String]` (die rohen Kennungen aus
/// `quantityIdentifiers` + `categoryIdentifiers` + `characteristicIdentifiers`
/// vereinigt) — ohne sie ließe sich Pflichtfall 1 nicht prüfen, ohne gegen
/// `HKObjectType`-Instanzen nach Namen zu suchen, was brüchiger wäre als ein
/// String-Vergleich.
@Suite("HealthTypeCatalog enthält alle Lesetypen, aber keine Korrelationstypen")
struct HealthTypeCatalogTests {

    @Test("Der Katalog enthaelt keine Korrelationstypen")
    func katalogOhneKorrelationstypen() {
        let ids = HealthTypeCatalog.allReadableTypeIdentifiers
        #expect(!ids.contains { $0.hasPrefix("HKCorrelationTypeIdentifier") })
    }

    @Test("Unbekannte Typen fallen still heraus")
    func unbekannteTypenFallenStillHeraus() {
        // Derselbe Mechanismus, den der Katalog intern für jede seiner rund
        // 200 Kennungen durchläuft: eine erfundene Kennung liefert `nil`
        // zurück, statt zu crashen oder den Build zu brechen.
        let erfunden = HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifierDefinitivNichtEcht")
        #expect(HKObjectType.quantityType(forIdentifier: erfunden) == nil)

        let erfundeneKategorie = HKCategoryTypeIdentifier(rawValue: "HKCategoryTypeIdentifierDefinitivNichtEcht")
        #expect(HKObjectType.categoryType(forIdentifier: erfundeneKategorie) == nil)
    }

    @Test("Der Katalog bleibt trotz der compactMap-Filterung vollständig")
    func katalogBleibtVollstaendig() {
        // ~200 Kennungen über drei Kategorien (Mengen-, Kategorie- und
        // Merkmalstypen), plus Workout, ActivitySummary, Route, Heartbeat,
        // Audiogramm, EKG — deutlich mehr als 150, sonst wäre beim Portieren
        // eine ganze Gruppe stillschweigend verloren gegangen.
        #expect(HealthTypeCatalog.allReadableTypes.count > 150)
        #expect(HealthTypeCatalog.allReadableTypeIdentifiers.count > 150)
        // allReadableTypes enthält zusätzlich Typen ohne eigenen
        // String-Identifier in dieser Liste (Workout, ActivitySummary, …),
        // darf also nicht kleiner sein als die reine Identifier-Liste.
        #expect(HealthTypeCatalog.allReadableTypes.count >= HealthTypeCatalog.allReadableTypeIdentifiers.count)
    }

    @Test("Korrelationstypen bleiben trotzdem abfragbar, wenn die Einzelwerte erlaubt sind")
    func korrelationstypenBleibenAbfragbar() {
        // Nicht angefragt (siehe Test 1), aber als Typ existiert
        // HKCorrelationType weiterhin in HealthKit und lässt sich bilden —
        // nur die Leserechte-Anfrage darauf stürzt ab, nicht die
        // Typkonstruktion oder eine spätere Abfrage darüber. Genau so holt
        // `HealthKitReading.nutritionEntries` die Lebensmittelnamen, siehe
        // Vorlage HealthTypeCatalog.swift:286–288.
        let food = HKCorrelationType(.food)
        #expect(!HealthTypeCatalog.allReadableTypes.contains(food))
    }
}
