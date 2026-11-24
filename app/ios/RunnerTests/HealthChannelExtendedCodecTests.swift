import Foundation
import Testing
import TrainingsCore
@testable import Runner

/// Prüft den nil-Vertrag aus Spec 8.2 / CLAUDE.md für die durch Task 12 neu
/// hinzukommenden Kanal-Methoden — denselben, den `HealthChannelTests.swift`
/// (Task 7) bereits für `dailyMetrics` beweist: **ein fehlendes Feld fehlt in
/// der Map, eine echte 0 steht drin.**
///
/// **Warum hier nur `WorkoutSample` und nicht sechsmal dieselbe Prüfung:**
/// `HealthReading` hat sieben Methoden; `dailyMetrics` ist durch Task 7
/// abgedeckt. Von den fünf übrigen Rückgabetypen hat nur `WorkoutSample`
/// überhaupt Felder, bei denen „fehlt" und „ist 0" verschiedene Aussagen
/// wären:
///
/// - `WorkoutSample.km`/`avgHR`/`maxHR` sind optional (`HealthTypes.swift`) —
///   ein Spaziergang ohne GPS hat kein `km`, ein Training ohne
///   Herzfrequenzmessung kein `avgHR`/`maxHR`. Genau das prüft diese Datei.
/// - `QuantitySample` (Rückgabetyp von **beiden** `quantitySamples` **und**
///   `hourlySteps` — derselbe Typ, also auch keine zweite Prüfung für die
///   zweite Methode nötig) hat nur `date`/`value`, beide nicht optional.
/// - `NutritionEntry` hat `kcal`/`proteinG`/`carbsG`/`fatG`, aber alle vier
///   nicht optional — ein fehlender Nährwert wird schon in
///   `HealthKitReading.nutritionEntries` auf `0` normalisiert
///   (`.reduce(0, +)` über eine möglicherweise leere Liste), bevor der Kanal
///   ihn überhaupt sieht. Der Kanal selbst hat an dieser Stelle keine
///   nil-Entscheidung mehr zu treffen.
/// - `SleepSegment`/`SleepSession`/`SleepNight` haben keine optionalen
///   numerischen Felder.
///
/// Eine weitere Kopie derselben Prüfung auf einem dieser Typen würde nichts
/// Neues belegen — wie schon `channel_codec_test.dart` für den
/// Typfehler-Fall begründet (siehe dort, Gruppe „Falscher Typ").
///
/// **Erwartete neue API:** eine Überladung `HealthChannel.alsMap(_: WorkoutSample)
/// -> [String: Any]`, parallel zu `alsMap(_ metrics: DailyMetrics)` aus
/// Task 7. Encodierung: `id` als UUID-String, `start` als
/// Millisekunden seit 1970 (`Int`, dieselbe Einheit wie die `from`/`through`-
/// Argumente des Kanals), `kind` als `WorkoutKind.rawValue`, `minutes` als
/// `Double`, `km`/`avgHR`/`maxHR` nur wenn gesetzt, `wasUserEntered` immer
/// (kein Optional in `HealthTypes.swift`).
@Suite("Nil-Vertrag für die erweiterte Kanal-Methode workouts (Task 12)")
struct HealthChannelExtendedCodecTests {

    private let start = Date(timeIntervalSince1970: 1_792_195_200)

    @Test("ein WorkoutSample ohne km/avgHR/maxHR laesst diese Felder in der Map weg")
    func fehlendeWorkoutFelderLandenNichtInDerMap() {
        let sample = WorkoutSample(id: UUID(), start: start, kind: .walking, minutes: 54)
        let map = HealthChannel.alsMap(sample)
        #expect(!map.keys.contains("km"))
        #expect(!map.keys.contains("avgHR"))
        #expect(!map.keys.contains("maxHR"))
        #expect(map["minutes"] as? Double == 54)
        #expect(map["wasUserEntered"] as? Bool == false)
    }

    @Test("ein WorkoutSample mit avgHR/maxHR von 0 behaelt die 0 statt sie wegzulassen")
    func echteNullBeiAvgHRBleibtInDerMap() {
        let sample = WorkoutSample(id: UUID(), start: start, kind: .strength,
                                   minutes: 12, avgHR: 0, maxHR: 0)
        let map = HealthChannel.alsMap(sample)
        #expect(map.keys.contains("avgHR"), "eine echte 0 ist ein Messwert, kein fehlender")
        #expect(map.keys.contains("maxHR"))
        #expect(map["avgHR"] as? Int == 0)
        #expect(map["maxHR"] as? Int == 0)
    }

    @Test("gesetzte Felder erscheinen vollstaendig mit ihrem Wert")
    func gesetzteWorkoutFelderErscheinenMitWert() {
        let id = UUID()
        let sample = WorkoutSample(id: id, start: start, kind: .running,
                                   minutes: 32.5, km: 5.1, avgHR: 142, maxHR: 168,
                                   wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)
        #expect(map["id"] as? String == id.uuidString)
        #expect(map["start"] as? Int == 1_792_195_200_000)
        #expect(map["kind"] as? String == "running")
        #expect(map["minutes"] as? Double == 32.5)
        #expect(map["km"] as? Double == 5.1)
        #expect(map["avgHR"] as? Int == 142)
        #expect(map["maxHR"] as? Int == 168)
        #expect(map["wasUserEntered"] as? Bool == true)
    }

    // Rundlauf (simuliert, ohne Gerät) — Teil Swift: dieselben gemischten
    // Werte (gesetzt/fehlend/eine echte 0), die workout_codec_test.dart in
    // der Gruppe „Rundlauf … Teil Dart" von Hand nachbaut und in
    // `WorkoutSample.ausMap` gibt. Stimmen beide Seiten unabhängig überein,
    // ist der Vertrag an der Kanalgrenze bewiesen — der tatsächliche
    // Kanaltransport nicht, siehe `HealthChannelTests.swift` (Task 7) für
    // dieselbe Einschränkung bei `dailyMetrics`.
    @Test("Rundlauf — Teil Swift")
    func rundlaufTeilSwift() {
        let id = UUID(uuidString: "5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03")!
        let sample = WorkoutSample(id: id, start: start, kind: .strength,
                                   minutes: 64, avgHR: 112, maxHR: 158)
        let map = HealthChannel.alsMap(sample)

        #expect(map["id"] as? String == id.uuidString)
        #expect(map["start"] as? Int == 1_792_195_200_000)
        #expect(map["kind"] as? String == "strength")
        #expect(map["minutes"] as? Double == 64)
        #expect(map["avgHR"] as? Int == 112)
        #expect(map["maxHR"] as? Int == 158)
        #expect(map["wasUserEntered"] as? Bool == false)
        #expect(!map.keys.contains("km"), "kein GPS bei einem Krafttraining — km fehlt, ist nicht 0")
    }
}
