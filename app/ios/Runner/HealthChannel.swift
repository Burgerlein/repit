import Flutter
import Foundation
import HealthKit
import TrainingsCore

/// Platform-Channel zu HealthKit. Kanalname `de.rosenbach.repit/health`.
///
/// Spec 8.2 entscheidet, dass der echte `HKHealthStore`-Adapter der alten
/// App (`HealthKitReading`, `HealthTypeCatalog`, `QueryTimings`, portiert aus
/// `Sources/Health/`) nach `ios/Runner` wandert — `TrainingsCore` liefert
/// weiterhin die Typen, der Kanal kopiert sie nicht neu.
///
/// Task 7 hat hier nur `dailyMetrics` als Durchstich verdrahtet, mit einem
/// Platzhalter für die übrigen sechs Methoden. **Task 12 schließt den Port
/// ab:** Alle sieben Methoden von `HealthReading` laufen jetzt über den
/// echten Adapter, der Platzhalter ist verschwunden.
///
/// **Der wichtigste Vertrag:** jedes `alsMap(_:)` lässt ein `nil`-Feld aus
/// der Map vollständig weg — nicht `NSNull`, nicht `0`. Eine echte `0`
/// erscheint als `0`. Siehe `HealthChannelTests.swift`,
/// `HealthChannelExtendedCodecTests.swift` und Spec 8.2.
final class HealthChannel {

    static let channelName = "de.rosenbach.repit/health"

    /// ISO-Tagesschlüssel, identisch zu `BerlinCalendar.dayKey(...)` auf der
    /// Dart-Seite (`Packages/trainings_core/lib/src/berlin_calendar.dart`).
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    private let reading: HealthReading

    /// Die Schreibseite (#270) — ein **eigenes** Protokoll, weil
    /// `HealthReading` in `Packages/TrainingsCore` liegt und auch der
    /// eingefrorenen App gehört (siehe `HealthWeightWriting.swift`).
    ///
    /// Optional, damit ein Test den Kanal weiterhin mit einer reinen
    /// Lesequelle bauen kann. Fehlt sie, antwortet die Schreibseite mit
    /// `FlutterMethodNotImplemented` statt mit einem erfundenen Erfolg.
    private let writing: HealthWeightWriting?

    /// Die Ernährung (#283) — ebenfalls ein eigenes Protokoll, aus demselben
    /// Grund. Fehlt sie, antworten ihre Methoden mit
    /// `FlutterMethodNotImplemented`, auch `nutritionEntries`: Der alte Weg
    /// über `HealthReading.nutritionEntries` machte aus fehlenden Werten
    /// `0` (#232) und wird nicht mehr benutzt.
    private let nutrition: HealthNutritionWriting?
    private let channel: FlutterMethodChannel

    init(reading: HealthReading,
         writing: HealthWeightWriting? = nil,
         nutrition: HealthNutritionWriting? = nil,
         messenger: FlutterBinaryMessenger) {
        self.reading = reading
        self.writing = writing
        self.nutrition = nutrition
        self.channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    /// Registriert den Kanal. Aufgerufen aus `AppDelegate`.
    @discardableResult
    static func register(with messenger: FlutterBinaryMessenger) -> HealthChannel {
        // Dieselbe Instanz in beiden Rollen: Ein zweiter `HKHealthStore`
        // wäre ein zweiter Freigabestand.
        let adapter = HealthKitReading()
        return HealthChannel(reading: adapter, writing: adapter,
                             nutrition: adapter, messenger: messenger)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            handleRequestAuthorization(result: result)
        case "dailyMetrics":
            handleDailyMetrics(call, result: result)
        case "sleepSessions":
            handleSleepSessions(call, result: result)
        case "workouts":
            handleWorkouts(call, result: result)
        case "quantitySamples":
            handleQuantitySamples(call, result: result)
        case "hourlySteps":
            handleHourlySteps(call, result: result)
        case "nutritionEntries":
            handleNutritionEntries(call, result: result)
        case "requestWeightWriteAuthorization":
            handleRequestWeightWriteAuthorization(result: result)
        case "writeWeight":
            handleWriteWeight(call, result: result)
        case "deleteWeight":
            handleDeleteWeight(call, result: result)
        case "weightSamples":
            handleWeightSamples(call, result: result)
        case "requestNutritionWriteAuthorization":
            handleRequestNutritionWriteAuthorization(result: result)
        case "writeMeal":
            handleWriteMeal(call, result: result)
        case "deleteMeal":
            handleDeleteMeal(call, result: result)
        case "bodyCharacteristics":
            handleBodyCharacteristics(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - requestAuthorization

    private func handleRequestAuthorization(result: @escaping FlutterResult) {
        Task {
            do {
                try await reading.requestAuthorization()
                result(nil)
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - dailyMetrics

    private func handleDailyMetrics(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let (from, through) = Self.fromThrough(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let metrics = try await reading.dailyMetrics(from: from, through: through)
                result(metrics.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - sleepSessions

    private func handleSleepSessions(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let (from, through) = Self.fromThrough(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let nights = try await reading.sleepSessions(from: from, through: through)
                result(nights.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - workouts

    private func handleWorkouts(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let (from, through) = Self.fromThrough(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let workouts = try await reading.workouts(from: from, through: through)
                result(workouts.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - quantitySamples

    private func handleQuantitySamples(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let kindRaw = args["kind"] as? String,
            let kind = Self.vitalKind(kindRaw),
            let (from, through) = Self.fromThrough(call.arguments)
        else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let samples = try await reading.quantitySamples(kind, from: from, through: through)
                result(samples.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - hourlySteps

    private func handleHourlySteps(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let (from, through) = Self.fromThrough(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let samples = try await reading.hourlySteps(from: from, through: through)
                result(samples.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - nutritionEntries

    private func handleNutritionEntries(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard
            let args = call.arguments as? [String: Any],
            let dayMillis = args["day"] as? Double
        else {
            result(Self.badArgs()); return
        }
        guard let nutrition else { result(FlutterMethodNotImplemented); return }
        let day = Date(timeIntervalSince1970: dayMillis / 1000)
        Task {
            do {
                // Schon gefiltert: eigene Proben fehlen (Quellenfilter).
                let meals = try await nutrition.nutritionMeals(on: day)
                result(meals.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - Gewicht von Hand eintragen (#270)

    private func handleRequestWeightWriteAuthorization(result: @escaping FlutterResult) {
        guard let writing else { result(FlutterMethodNotImplemented); return }
        Task {
            do {
                let status = try await writing.requestWeightWriteAuthorization()
                result(Self.writeAuthorization(status))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    private func handleWriteWeight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let writing else { result(FlutterMethodNotImplemented); return }
        guard let (kg, at) = Self.writeWeightArgs(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let id = try await writing.writeWeight(kg: kg, at: at)
                result(id.uuidString)
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    private func handleDeleteWeight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let writing else { result(FlutterMethodNotImplemented); return }
        guard let id = Self.deleteWeightArgs(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                try await writing.deleteWeight(id: id)
                result(nil)
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    private func handleWeightSamples(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let writing else { result(FlutterMethodNotImplemented); return }
        guard let (from, through) = Self.fromThrough(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let proben = try await writing.weightSamples(from: from, through: through)
                result(proben.map(Self.alsMap))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - Ernährung nach Health schreiben (#283)

    private func handleRequestNutritionWriteAuthorization(result: @escaping FlutterResult) {
        guard let nutrition else { result(FlutterMethodNotImplemented); return }
        Task {
            do {
                let status = try await nutrition.requestNutritionWriteAuthorization()
                result(Self.writeAuthorization(status))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    private func handleWriteMeal(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let nutrition else { result(FlutterMethodNotImplemented); return }
        guard let (name, at, nutrients) = Self.writeMealArgs(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                let id = try await nutrition.writeMeal(name: name, at: at, nutrients: nutrients)
                result(id.uuidString)
            } catch {
                result(Self.writeError(error))
            }
        }
    }

    private func handleDeleteMeal(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let nutrition else { result(FlutterMethodNotImplemented); return }
        guard let id = Self.deleteMealArgs(call.arguments) else {
            result(Self.badArgs()); return
        }
        Task {
            do {
                try await nutrition.deleteMeal(id: id)
                result(nil)
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - bodyCharacteristics

    /// Körpergröße und Geburtsjahr (#306). Ein Merkmal hat kein
    /// Zeitfenster, also hat dieser Aufruf keine Argumente.
    ///
    /// **Eine Quelle ohne Merkmale ist ein Normalfall, kein Absturz.**
    /// `reading` ist ein `HealthReading`; das zweite Protokoll kommt über
    /// `as?` dazu. Kann die Quelle es nicht, kommt eine leere Map zurück —
    /// drüben sind dann beide Felder `nil`, und das ist genau dieselbe
    /// Auskunft wie „in Health nicht hinterlegt".
    private func handleBodyCharacteristics(result: @escaping FlutterResult) {
        guard let merkmalsquelle = reading as? BodyCharacteristicsReading else {
            result([String: Any]()); return
        }
        Task {
            do {
                let merkmale = try await merkmalsquelle.bodyCharacteristics()
                result(Self.alsMap(merkmale))
            } catch {
                result(Self.healthError(error))
            }
        }
    }

    // MARK: - Argument-Hilfsmittel

    /// Nimmt `call.arguments` und nicht den `FlutterMethodCall`: Das
    /// Auslesen von Argumenten ist eine reine Funktion und braucht kein
    /// Flutter-Objekt — erst dadurch ist es prüfbar, ohne einen Kanal
    /// aufzubauen. Zwei Überladungen nebeneinander wären mehrdeutig, weil
    /// jeder `FlutterMethodCall` auch ein `Any?` ist.
    ///
    /// Nicht privat: `HealthChannelWeightTests` prüft sie.
    static func fromThrough(_ arguments: Any?) -> (from: Date, through: Date)? {
        guard
            let args = arguments as? [String: Any],
            let fromMillis = args["from"] as? Double,
            let throughMillis = args["through"] as? Double
        else { return nil }
        return (Date(timeIntervalSince1970: fromMillis / 1000),
                Date(timeIntervalSince1970: throughMillis / 1000))
    }

    /// `kg` und `at` für `writeWeight`.
    ///
    /// Ein fehlendes Feld wird `nil` und damit `badArgs` — **nie** eine
    /// erfundene `0` oder ein stilles „jetzt". Ein Eintrag mit erfundenem
    /// Datum landete am falschen Tag, und niemand sähe, warum.
    static func writeWeightArgs(_ arguments: Any?) -> (kg: Double, at: Date)? {
        guard
            let args = arguments as? [String: Any],
            let kg = args["kg"] as? Double,
            let atMillis = args["at"] as? Double
        else { return nil }
        return (kg, Date(timeIntervalSince1970: atMillis / 1000))
    }

    /// Die UUID für `deleteWeight`.
    ///
    /// Gibt `UUID?` zurück, nicht `String?`: Eine Zeichenkette, die keine
    /// UUID ist, findet in HealthKit nichts zu löschen. Das ist `badArgs`
    /// und kein stiller Fehlschlag — der hieße „gilt als gelöscht und ist
    /// es nicht".
    static func deleteWeightArgs(_ arguments: Any?) -> UUID? {
        guard
            let args = arguments as? [String: Any],
            let roh = args["id"] as? String
        else { return nil }
        return UUID(uuidString: roh)
    }

    /// `name`, `at` und die vorhandenen Nährwerte für `writeMeal`.
    ///
    /// `nil` — und damit `badArgs` — bei fehlendem Namen oder Zeitpunkt,
    /// bei **einem** falsch getypten Feld und wenn kein einziger Nährwert
    /// dabei ist. Ein falscher Typ wird nie still zu `nil`: Dann fehlte der
    /// Wert in Health, und niemand sähe, warum. Ein fehlender Schlüssel
    /// bleibt `nil` und wird nie `0`.
    static func writeMealArgs(_ arguments: Any?)
        -> (name: String, at: Date, nutrients: MealNutrients)? {
        guard
            let args = arguments as? [String: Any],
            let name = args["name"] as? String,
            let atRoh = args["at"],
            let atMillis = zahl(atRoh)
        else { return nil }
        var nutrients = MealNutrients()
        for field in HealthNutrition.fields {
            guard let roh = args[field.channelKey] else { continue }
            guard let wert = zahl(roh) else { return nil }
            nutrients[keyPath: field.keyPath] = wert
        }
        guard nutrients.hasAnyValue else { return nil }
        return (name, Date(timeIntervalSince1970: atMillis / 1000), nutrients)
    }

    /// Die Mahlzeit-Kennung für `deleteMeal` — dieselbe Form wie
    /// [deleteWeightArgs].
    static func deleteMealArgs(_ arguments: Any?) -> UUID? {
        deleteWeightArgs(arguments)
    }

    /// Eine Zahl aus dem Standard-Codec — `NSNumber`, gleich ob Ganz- oder
    /// Kommazahl. **Ein Wahrheitswert ist keine Zahl:** Über den Codec kommt
    /// `true` ebenfalls als `NSNumber` an und würde sonst still zu `1`.
    private static func zahl(_ roh: Any) -> Double? {
        guard let nummer = roh as? NSNumber,
              CFGetTypeID(nummer) != CFBooleanGetTypeID()
        else { return nil }
        return nummer.doubleValue
    }

    /// `HKAuthorizationStatus` → die drei Namen der Dart-Seite.
    ///
    /// Buchstabengleich zu `WriteAuthorization` in
    /// `app/lib/health/health_types.dart`: `byName` wirft drüben bei allem
    /// anderen, und das ist gewollt — ein unbekannter Name ist ein
    /// Programmierfehler im Kanal, keine Aussage Apples.
    ///
    /// **Ein unbekannter Status wird nie `granted`.** Apple kann die
    /// Aufzählung erweitern; alles, was wir nicht kennen, ist im Zweifel
    /// keine Erlaubnis.
    static func writeAuthorization(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized: "granted"
        case .sharingDenied: "denied"
        case .notDetermined: "notDetermined"
        @unknown default: "denied"
        }
    }

    /// Nicht privat: `HealthVitalKindTests` prüft die Zuordnung. Die
    /// Zeichenketten sind buchstabengleich zu `VitalKind` auf der Dart-Seite
    /// (`app/lib/health/health_types.dart`), weil `health_channel.dart`
    /// `kind.name` schickt. Unbekanntes wird `nil` und landet in `badArgs`,
    /// statt still auf eine Art zu fallen.
    static func vitalKind(_ raw: String) -> VitalKind? {
        switch raw {
        case "heartRate": .heartRate
        case "respiratoryRate": .respiratoryRate
        case "heartRateVariability": .heartRateVariability
        default: nil
        }
    }

    private static func badArgs() -> FlutterError {
        FlutterError(code: "bad_args",
                    message: "Argumente fehlen oder haben den falschen Typ", details: nil)
    }

    /// Ein Schreibfehler: endgültig (`write_rejected`, drüben
    /// `HealthWriteRejected` und damit `nicht_moeglich`) oder alles andere
    /// (`health_error`, der Eintrag bleibt `offen`). Die Zuordnung steht in
    /// `HealthNutrition.isPermanentWriteRejection`.
    private static func writeError(_ error: Error) -> FlutterError {
        guard HealthNutrition.isPermanentWriteRejection(error) else {
            return healthError(error)
        }
        return FlutterError(code: "write_rejected",
                            message: error.localizedDescription, details: nil)
    }

    private static func healthError(_ error: Error) -> FlutterError {
        FlutterError(code: "health_error", message: error.localizedDescription, details: nil)
    }

    private static func millis(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 * 1000).rounded())
    }

    // MARK: - Codec: DailyMetrics
    //
    // Ein `nil`-Feld fehlt in der Map vollständig. Eine echte `0` erscheint
    // als `0`. Kein Feld wird jemals auf `NSNull` oder `0` abgebildet, nur
    // weil es fehlt — das ist der ganze Zweck dieses Durchstichs.

    static func alsMap(_ metrics: DailyMetrics) -> [String: Any] {
        var map: [String: Any] = [
            "tag": dayKeyFormatter.string(from: metrics.date)
        ]
        if let steps = metrics.steps { map["steps"] = steps }
        if let activeKcal = metrics.activeKcal { map["activeKcal"] = activeKcal }
        if let basalKcal = metrics.basalKcal { map["basalKcal"] = basalKcal }
        if let restingHR = metrics.restingHR { map["restingHR"] = restingHR }
        if let hrvMs = metrics.hrvMs { map["hrvMs"] = hrvMs }
        if let respRate = metrics.respRate { map["respRate"] = respRate }
        if let vo2max = metrics.vo2max { map["vo2max"] = vo2max }
        if let weightKg = metrics.weightKg { map["weightKg"] = weightKg }
        if let bodyFatPct = metrics.bodyFatPct { map["bodyFatPct"] = bodyFatPct }
        if let leanKg = metrics.leanKg { map["leanKg"] = leanKg }
        if let exerciseMinutes = metrics.exerciseMinutes { map["exerciseMinutes"] = exerciseMinutes }
        if let standHours = metrics.standHours { map["standHours"] = standHours }
        if let recoveryHRDrop = metrics.recoveryHRDrop { map["recoveryHRDrop"] = recoveryHRDrop }
        if let alcoholicDrinks = metrics.alcoholicDrinks { map["alcoholicDrinks"] = alcoholicDrinks }
        return map
    }

    // MARK: - Codec: WorkoutSample
    //
    // `id` als UUID-String, `start` als Millisekunden seit 1970, `kind` als
    // `WorkoutKind.rawValue`, `minutes` als `Double`, `km`/`avgHR`/`maxHR` nur
    // wenn gesetzt, `wasUserEntered` immer (kein Optional in
    // `HealthTypes.swift`). Siehe `HealthChannelExtendedCodecTests.swift`.

    static func alsMap(_ sample: WorkoutSample) -> [String: Any] {
        var map: [String: Any] = [
            "id": sample.id.uuidString,
            "start": millis(sample.start),
            "kind": sample.kind.rawValue,
            "minutes": sample.minutes,
            "wasUserEntered": sample.wasUserEntered
        ]
        if let km = sample.km { map["km"] = km }
        if let avgHR = sample.avgHR { map["avgHR"] = avgHR }
        if let maxHR = sample.maxHR { map["maxHR"] = maxHR }
        return map
    }

    // MARK: - Codec: SleepNight / SleepSession / SleepSegment
    //
    // Keine optionalen numerischen Felder (siehe Dateikopf von
    // `HealthChannelExtendedCodecTests.swift`) — hier geht es nur um ein
    // konsistentes Format zwischen Swift und Dart, nicht um den
    // nil-wird-nie-0-Vertrag.

    static func alsMap(_ night: SleepNight) -> [String: Any] {
        [
            "tag": dayKeyFormatter.string(from: night.date),
            "segments": night.session.segments.map(alsMap),
            "naps": night.naps.map { ["segments": $0.segments.map(alsMap)] }
        ]
    }

    static func alsMap(_ segment: SleepSegment) -> [String: Any] {
        [
            "stage": segment.stage.rawValue,
            "start": millis(segment.start),
            "end": millis(segment.end)
        ]
    }

    // MARK: - Codec: QuantitySample (gemeinsam für quantitySamples/hourlySteps)

    static func alsMap(_ sample: QuantitySample) -> [String: Any] {
        [
            "date": millis(sample.date),
            "value": sample.value
        ]
    }

    // MARK: - Codec: BodyCharacteristics
    //
    // Derselbe Vertrag wie überall: Ein `nil`-Feld fehlt in der Map
    // vollständig — kein Wert ist kein Nullwert, eine 0 hier hiesse „0 cm
    // gross". Eine **echte** 0 bleibt dagegen stehen; der Codec urteilt
    // nicht über Plausibilität, er bildet ab, was drüben stand. Dass eine 0
    // nie als eingetragene Körpergröße in der Stammdaten-Tabelle landet,
    // ist die Zusage der Dart-Seite (`stammdatenAusHealthProvider`).
    //
    // `heightCm` bleibt krumm: Gerundet wird genau einmal, drüben beim
    // Ablegen in `Stammdaten.groesseCm` (ein `Int`). `birthYear` geht als
    // `Int` — ein Jahrgang ist eine Ganzzahl, als `Double` käme drüben
    // 1899.0 an.

    static func alsMap(_ merkmale: BodyCharacteristics) -> [String: Any] {
        var map: [String: Any] = [:]
        if let heightCm = merkmale.heightCm { map["heightCm"] = heightCm }
        if let birthYear = merkmale.birthYear { map["birthYear"] = birthYear }
        return map
    }

    // MARK: - Codec: NutritionMeal (#283, #232)
    //
    // `time` (ms), `name`, und je **vorhandenem** Nährwert sein Schlüssel.
    // Fehlt ein Wert, fehlt der Schlüssel — vorher stand hier jeder der vier
    // Werte immer drin, und ein fehlender kam als `0` an (#232). Die Quelle
    // geht nicht mit: Gefiltert ist schon auf dieser Seite.

    static func alsMap(_ meal: NutritionMeal) -> [String: Any] {
        var map: [String: Any] = [
            "time": millis(meal.time),
            "name": meal.name
        ]
        for field in HealthNutrition.fields {
            if let wert = meal.nutrients[keyPath: field.keyPath] {
                map[field.channelKey] = wert
            }
        }
        return map
    }

    // MARK: - Codec: WeightSample
    //
    // Vier Schlüssel, alle vier immer da — keiner ist optional, weil alle
    // vier an jeder `HKQuantitySample` vorliegen. Ein fehlendes Feld wäre
    // hier ein Vertragsbruch und keine Datenlage, und die Dart-Seite wirft
    // entsprechend (`WeightSample.ausMap`).
    //
    // Besonders `wasUserEntered`: Ein weggelassenes Feld nähme der Zeile
    // drüben still ihre Tür, und „von Hand eingetragen" sähe aus wie „von
    // der Waage".

    static func alsMap(_ sample: WeightSample) -> [String: Any] {
        [
            "id": sample.id.uuidString,
            "date": millis(sample.date),
            "kg": sample.kg,
            "wasUserEntered": sample.wasUserEntered
        ]
    }
}
