import Foundation
import Testing
import TrainingsCore
@testable import Runner

/// Tests für `HealthChannel.alsMap(_:)` (Task 7) — die Swift-Hälfte des
/// Platform-Channel-Durchstichs zu HealthKit.
///
/// Swift Testing, nicht XCTest — wie alle anderen Testdateien dieses
/// Projekts (siehe `CLAUDE.md`). `app/ios/RunnerTests/RunnerTests.swift` ist
/// unverändertes `flutter create`-Gerüst auf XCTest-Basis und bleibt
/// unangetastet; diese Datei richtet sich nicht danach.
///
/// **Worum es geht:** Spec 8.2 in
/// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md` verlangt,
/// dass `nil` auf dem Weg durch den Kanal niemals zu `0` wird — Fehlende
/// Felder fehlen in der Map, sie stehen nicht mit Nullwert drin. Das ist die
/// andere Hälfte des Vertrags, den `channel_codec_test.dart` auf der
/// Dart-Seite prüft: Dort wird vorausgesetzt, dass ein fehlender Schlüssel
/// ankommt; hier wird geprüft, dass `alsMap` einen fehlenden Schlüssel auch
/// tatsächlich erzeugt, statt `NSNull` oder `0` einzutragen.
///
/// `DailyMetrics` ist bewusst die echte Struktur aus
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthTypes.swift`
/// — Spec 8.2 verbietet ausdrücklich eine zweite, handgepflegte Swift-Kopie
/// dieser Typen im Kanal, sie würde unbemerkt wegdriften. `HealthChannel`
/// wandelt sie direkt in die rohe `Map` fürs Standard-Codec um.
///
/// Geprüft wird in M0 ausschließlich `dailyMetrics`/`alsMap` — die übrigen
/// sechs Methoden des Protokolls `HealthReading` kommen laut Aufgabenstellung
/// erst in Task 12.
///
/// **Was hier absichtlich nicht geprüft wird:** wie `date` im Kanal kodiert
/// wird (als welcher Schlüssel, in welchem Stringformat) — das ist eine
/// Entscheidung der Implementierung und nicht Teil des
/// Null-bleibt-null-Vertrags, um den es in diesem Task geht; keiner der
/// Tests unten fragt die Map nach einem Datums-Schlüssel. Ebenso ungeprüft:
/// der tatsächliche `MethodChannel`-Transport (Standard-Codec-Serialisierung,
/// `AppDelegate`-Registrierung, ein echter Aufruf im Simulator) — das läuft
/// laut Aufgabenstellung „ohne Gerät"; die letzte Gruppe unten bildet den
/// Rundlauf nur **simuliert** nach, siehe dort.
@Suite("HealthChannel.alsMap macht nil nie zu Null")
struct HealthChannelTests {

    /// 23.10.2026, 00:00 UTC. Der genaue Zeitpunkt ist für diese Tests
    /// irrelevant — `DailyMetrics` braucht ein `date`, aber keiner der
    /// Tests fragt die Map danach (siehe Dateikopf).
    private let tag = Date(timeIntervalSince1970: 1_792_195_200)

    @Test("Pflichtfall aus task-7-brief.md: ein fehlender Wert landet nicht in der Map")
    func fehlenderWertLandetNichtInDerMap() {
        let metrics = DailyMetrics(date: tag, steps: 9500)
        let map = HealthChannel.alsMap(metrics)
        #expect(map["steps"] as? Int == 9500)
        #expect(map["restingHR"] == nil)
        #expect(!map.keys.contains("restingHR"))
        #expect(!map.keys.contains("vo2max"))
    }

    @Test("ein gesetztes double-Feld erscheint mit seinem Wert")
    func gesetztesDoubleFeldErscheintMitWert() {
        let metrics = DailyMetrics(date: tag, hrvMs: 42.5)
        let map = HealthChannel.alsMap(metrics)
        #expect(map["hrvMs"] as? Double == 42.5)
        #expect(!map.keys.contains("steps"))
    }

    @Test("eine echte 0 erscheint in der Map und wird nicht weggelassen")
    func echteNullErscheintInDerMap() {
        let metrics = DailyMetrics(date: tag, steps: 0)
        let map = HealthChannel.alsMap(metrics)
        #expect(
            map.keys.contains("steps"),
            "eine echte 0 ist ein Messwert und darf nicht wie ein fehlender behandelt werden"
        )
        #expect(map["steps"] as? Int == 0)
    }

    @Test("alle 13 nullbaren Felder fehlen in der Map, wenn DailyMetrics nur das Datum trägt")
    func alleFelderFehlenBeiLeerenDailyMetrics() {
        let metrics = DailyMetrics(date: tag)
        let map = HealthChannel.alsMap(metrics)
        let erwarteteSchluessel: Set<String> = [
            "steps", "activeKcal", "basalKcal", "restingHR", "hrvMs",
            "respRate", "vo2max", "weightKg", "bodyFatPct", "leanKg",
            "exerciseMinutes", "standHours", "recoveryHRDrop"
        ]
        for schluessel in erwarteteSchluessel {
            #expect(
                !map.keys.contains(schluessel),
                "\(schluessel) darf nicht in der Map stehen, wenn DailyMetrics dafür nil trägt"
            )
        }
    }

    @Test("echte 0 bleibt für int- und double-Felder gleichermaßen in der Map")
    func echteNullBleibtFuerAlleFeldtypen() {
        let metrics = DailyMetrics(
            date: tag, steps: 0, activeKcal: 0, basalKcal: 0, restingHR: 0,
            hrvMs: 0.0, respRate: 0.0, vo2max: 0.0, weightKg: 0.0,
            bodyFatPct: 0.0, leanKg: 0.0, exerciseMinutes: 0.0,
            standHours: 0, recoveryHRDrop: 0
        )
        let map = HealthChannel.alsMap(metrics)
        #expect(map["steps"] as? Int == 0)
        #expect(map["activeKcal"] as? Int == 0)
        #expect(map["basalKcal"] as? Int == 0)
        #expect(map["restingHR"] as? Int == 0)
        #expect(map["standHours"] as? Int == 0)
        #expect(map["recoveryHRDrop"] as? Int == 0)
        #expect(map["hrvMs"] as? Double == 0.0)
        #expect(map["respRate"] as? Double == 0.0)
        #expect(map["vo2max"] as? Double == 0.0)
        #expect(map["weightKg"] as? Double == 0.0)
        #expect(map["bodyFatPct"] as? Double == 0.0)
        #expect(map["leanKg"] as? Double == 0.0)
        #expect(map["exerciseMinutes"] as? Double == 0.0)
    }

    // Rundlauf (simuliert, ohne Gerät) — Teil Swift: dieselben gemischten
    // Werte (gesetzt/fehlend/eine echte 0), die channel_codec_test.dart in
    // der Gruppe "Rundlauf ... Teil Dart" von Hand nachbaut und in ausMap
    // gibt. Stimmen beide Seiten unabhängig überein, ist der Vertrag an der
    // Kanalgrenze bewiesen — der tatsächliche Kanaltransport nicht, siehe
    // Dateikopf.
    @Test("Rundlauf — Teil Swift")
    func rundlaufTeilSwift() {
        let metrics = DailyMetrics(date: tag, steps: 0, restingHR: 48, hrvMs: 42.5)
        let map = HealthChannel.alsMap(metrics)

        #expect(map["steps"] as? Int == 0, "echte 0, nicht fehlend")
        #expect(map["restingHR"] as? Int == 48)
        #expect(map["hrvMs"] as? Double == 42.5)

        let fehlendeSchluessel: Set<String> = [
            "activeKcal", "basalKcal", "respRate", "vo2max", "weightKg",
            "bodyFatPct", "leanKg", "exerciseMinutes", "standHours",
            "recoveryHRDrop"
        ]
        for schluessel in fehlendeSchluessel {
            #expect(!map.keys.contains(schluessel))
        }
    }
}
