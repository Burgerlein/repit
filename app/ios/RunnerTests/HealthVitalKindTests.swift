import Foundation
import HealthKit
import Testing
import TrainingsCore
@testable import Runner

/// Tests für Stufe 2 von #193 — die HRV als **einzelne Messreihe** über den
/// Platform-Channel (`docs/superpowers/specs/2026-11-02-193-nachtwerte.md`,
/// Abschnitt „Stufe 2 — HRV über den Kanal").
///
/// Swift Testing, nicht XCTest — wie alle Testdateien dieses Projekts außer
/// dem unveränderten `flutter create`-Gerüst `RunnerTests.swift`
/// (`CLAUDE.md`, Abschnitt „Tests").
///
/// **Die Einheit ist der eigentliche Gegenstand.** `quantitySamples` setzte
/// bisher für beide Arten fest `HKUnit.count().unitDivided(by: .minute())`.
/// SDNN ist aber eine **Zeit**, gemessen in Millisekunden. Eine Pulseinheit
/// auf eine SDNN-Probe angewandt wirft nicht und meldet nichts — sie liefert
/// stillschweigend eine um Größenordnungen falsche Zahl, und die Dart-Seite
/// sieht davon nur noch eine plausible Zahl ohne Vorzeichen eines Fehlers.
/// Deshalb hängt die Einheit an der **Art**, nicht an der Methode, und
/// deshalb wird genau das hier geprüft.
///
/// **Die Zeichenketten sind der zweite Gegenstand.**
/// `app/lib/health/health_channel.dart` schickt `kind.name`; der Dart-Name
/// und die hier erwartete Zeichenkette müssen deshalb buchstabengleich sein.
/// Die Dart-Hälfte desselben Vertrags steht in
/// `app/test/health/hrv_kanal_test.dart`; beide Seiten prüfen unabhängig
/// gegen dasselbe Wort, wie schon bei `channel_codec_test.dart` /
/// `HealthChannelTests.swift`.
///
/// **Was hier absichtlich nicht geprüft wird:** ein echter
/// `HKHealthStore`-Lauf. Der Simulator-Store ist dauerhaft leer
/// (`CLAUDE.md`, „Prüfen im Simulator"); eine Abfrage dort liefert in jedem
/// Fall nichts und könnte eine falsche Einheit nicht von „keine Daten"
/// unterscheiden. Geprüft wird die Zuordnung, nicht die Abfrage.
///
/// **Erwartete neue API**, die der Test voraussetzt und die es ohne ihn nicht
/// gäbe:
/// - `HealthChannel.vitalKind(_:)` ist nicht mehr `private` (sonst reicht
///   `@testable import` nicht heran),
/// - `VitalKind.quantityTypeIdentifier` und `VitalKind.unit` liegen als
///   Erweiterung in `app/ios/Runner/HealthKitReading.swift` — **nicht** im
///   Kern: `Packages/TrainingsCore` importiert nur Foundation und darf
///   `HealthKit` nicht kennen (`CLAUDE.md`, „Aufbau", durchgesetzt von
///   `ImportBoundaryTests`).
@Suite("Die HRV ist eine eigene Messreihe, mit eigener Einheit")
struct HealthVitalKindTests {

    private let bpm = HKUnit.count().unitDivided(by: .minute())

    // MARK: - Die Zeichenketten

    @Test("vitalKind bildet alle drei Zeichenketten auf ihre Art ab")
    func vitalKindBildetAlleDreiAb() {
        #expect(HealthChannel.vitalKind("heartRate") == .heartRate)
        #expect(HealthChannel.vitalKind("respiratoryRate") == .respiratoryRate)
        #expect(HealthChannel.vitalKind("heartRateVariability") == .heartRateVariability)
    }

    @Test("Eine unbekannte Zeichenkette wird nil, nicht stillschweigend eine Art")
    func unbekannteZeichenketteWirdNil() {
        #expect(HealthChannel.vitalKind("hrv") == nil)
        #expect(HealthChannel.vitalKind("") == nil)
        #expect(
            HealthChannel.vitalKind("heartratevariability") == nil,
            "die Zuordnung ist buchstabengleich, nicht ungefaehr"
        )
        #expect(
            HealthChannel.vitalKind("heartRateVariabilitySDNN") == nil,
            "die Dart-Seite schickt den Enum-Namen, nicht die HealthKit-Kennung"
        )
    }

    @Test("Es gibt genau drei Arten")
    func esGibtGenauDreiArten() {
        #expect(
            VitalKind.allCases.count == 3,
            "kommt eine vierte Art dazu, braucht sie eine Zeichenkette in vitalKind, eine Kennung und eine Einheit"
        )
    }

    // MARK: - Die Einheit

    @Test("Puls und Atmung bleiben bei Zaehlung je Minute")
    func pulsUndAtmungZaehlenJeMinute() {
        #expect(VitalKind.heartRate.unit == bpm)
        #expect(VitalKind.respiratoryRate.unit == bpm)
    }

    @Test("Die HRV wird in Millisekunden gelesen, nicht in Schlaegen je Minute")
    func hrvInMillisekunden() {
        #expect(VitalKind.heartRateVariability.unit == HKUnit.secondUnit(with: .milli))
        #expect(
            VitalKind.heartRateVariability.unit != bpm,
            "eine Pulseinheit auf SDNN wirft nicht — sie liefert still eine um Groessenordnungen falsche Zahl"
        )
    }

    @Test("Die Einheit ist mit dem HealthKit-Typ vertraeglich")
    func einheitPasstZumTyp() {
        for art in VitalKind.allCases {
            let typ = HKQuantityType(art.quantityTypeIdentifier)
            #expect(
                typ.`is`(compatibleWith: art.unit),
                "\(art) traegt eine Einheit, die HealthKit fuer diesen Typ nicht annimmt"
            )
        }
    }

    // MARK: - Der HealthKit-Typ

    @Test("Jede Art zeigt auf ihren HealthKit-Typ")
    func jedeArtZeigtAufIhrenTyp() {
        #expect(VitalKind.heartRate.quantityTypeIdentifier == .heartRate)
        #expect(VitalKind.respiratoryRate.quantityTypeIdentifier == .respiratoryRate)
        #expect(VitalKind.heartRateVariability.quantityTypeIdentifier == .heartRateVariabilitySDNN)
    }

    @Test("Die SDNN-Kennung steht im Lesekatalog")
    func sdnnStehtImLesekatalog() {
        // Es gibt genau einen Berechtigungsdialog je Installation. Fehlte die
        // Kennung dort, waere die Abfrage dauerhaft leer und eine
        // Neuinstallation noetig (CLAUDE.md, Abschnitt „Code").
        #expect(
            HealthTypeCatalog.allReadableTypeIdentifiers
                .contains("HKQuantityTypeIdentifierHeartRateVariabilitySDNN")
        )
    }

    @Test("Der Lesekatalog traegt weiterhin keine Korrelationstypen")
    func lesekatalogOhneKorrelationstypen() {
        // `HKCorrelationTypeIdentifierFood` in der Leseanfrage wirft eine
        // NSInvalidArgumentException und bringt die App zum Absturz.
        #expect(
            !HealthTypeCatalog.allReadableTypeIdentifiers
                .contains { $0.hasPrefix("HKCorrelationTypeIdentifier") }
        )
    }
}
