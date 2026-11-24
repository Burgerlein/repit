import Foundation
import HealthKit

/// Ernährung nach Apple Health schreiben (#283) — und beim Lesen die eigene
/// Kopie wieder herausfiltern, damit keine Mahlzeit doppelt zählt.
///
/// **Warum das nicht im Protokoll `HealthReading` steht:** derselbe Grund
/// wie bei `HealthWeightWriting` — jenes liegt in `Packages/TrainingsCore`
/// und gehört auch der eingefrorenen App.
///
/// ## Korrelation oder Einzelproben — im Simulator ausprobiert
///
/// **Versuch vom 04.11.2026** (Simulator iPhone 17 Pro, iOS 26.1, Plan
/// `2026-11-03-ernaehrung.md`, Task 5, Step 1): Eine Schreibanfrage, deren
/// `toShare`-Satz `HKCorrelationType(.food)` enthält (Lesesatz leer),
/// beendet die App sofort mit
/// `NSInvalidArgumentException: Authorization to share the following types
/// is disallowed: HKCorrelationTypeIdentifierFood` — dieselbe Ausnahme wie
/// in der Leseanfrage, geworfen in
/// `-[HKHealthStoreImplementation _throwIfAuthorizationDisallowedForSharing:types:]`.
///
/// Nach der vorab festgelegten Regel heißt das: **Einzelproben mit
/// gemeinsamen Metadaten.** Jede Mahlzeit wird zu je einer
/// `HKQuantitySample` je vorhandenem Nährwert; alle tragen
/// `HKMetadataKeyFoodType` (der Name) und [HealthNutrition.mealIDKey]
/// (eine eigene Kennung je Mahlzeit). Über diese Kennung löscht
/// [HealthNutritionWriting.deleteMeal] genau die Proben einer Mahlzeit.
/// Der Ring stimmt genauso; nur gruppiert die Health-App die Werte nicht
/// unter dem Namen.
///
/// *Nicht geprüft* wurde, ob eine Food-Korrelation gespeichert werden
/// kann, wenn nur die enthaltenen Mengentypen freigegeben sind — dafür
/// hätte der Freigabedialog im Simulator angetippt werden müssen, und die
/// Fernsteuerung erreichte das Simulatorfenster nicht. Die Regel aus dem
/// Plan fragt nach `toShare`, und dort ist die Antwort eindeutig.
protocol HealthNutritionWriting {

    /// Fragt die **Schreib**freigabe für die acht Ernährungstypen an und
    /// sagt, was dabei herauskam. Eine Bewegung, nicht zwei — siehe
    /// `HealthWeightWriting.requestWeightWriteAuthorization`.
    func requestNutritionWriteAuthorization() async throws -> HKAuthorizationStatus

    /// Schreibt eine Mahlzeit und liefert ihre Kennung — die Mahlzeit-
    /// Kennung aus den Metadaten, nicht die UUID einer einzelnen Probe.
    func writeMeal(name: String, at date: Date,
                   nutrients: MealNutrients) async throws -> UUID

    /// Löscht alle Proben einer Mahlzeit, die **diese App** geschrieben hat.
    func deleteMeal(id: UUID) async throws

    /// Die Mahlzeiten eines Berliner Tages — **schon gefiltert**: Was diese
    /// App selbst geschrieben hat, fehlt.
    func nutritionMeals(on day: Date) async throws -> [NutritionMeal]
}

/// Die acht Nährwerte, die geschrieben und gelesen werden. `nil` heißt
/// „keine Angabe" und nie „0"; eine echte `0` bleibt `0`.
///
/// Ein eigener Transporttyp statt `TrainingsCore.NutritionEntry`: Jener hat
/// nicht-optionale Felder und gehört der eingefrorenen App.
struct MealNutrients: Equatable {
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var saturatedFatG: Double?
    var sugarG: Double?
    var fiberG: Double?
    var waterMl: Double?

    init(kcal: Double? = nil, proteinG: Double? = nil, carbsG: Double? = nil,
         fatG: Double? = nil, saturatedFatG: Double? = nil,
         sugarG: Double? = nil, fiberG: Double? = nil, waterMl: Double? = nil) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.saturatedFatG = saturatedFatG
        self.sugarG = sugarG
        self.fiberG = fiberG
        self.waterMl = waterMl
    }

    /// Ob überhaupt ein Wert da ist. Eine Mahlzeit ohne einen einzigen wäre
    /// ein Eintrag in Health, der nichts trägt.
    var hasAnyValue: Bool {
        HealthNutrition.fields.contains { self[keyPath: $0.keyPath] != nil }
    }
}

/// Eine Mahlzeit, wie der Kanal sie liest.
struct NutritionMeal {
    let time: Date
    let name: String

    /// Die Quelle — bleibt auf der Swift-Seite und geht **nicht** über den
    /// Kanal. Der Filter sitzt hier, weil nur hier die Quelle bekannt ist.
    let sourceBundleID: String

    let nutrients: MealNutrients
}

/// Die reinen Funktionen hinter Lesen und Schreiben — prüfbar ohne
/// `HKHealthStore` (`HealthNutritionWritingTests.swift`).
enum HealthNutrition {

    /// Ein Nährwert: wo er im Transporttyp steht, wie er über den Kanal
    /// heißt, welcher HealthKit-Typ und welche Einheit ihn tragen.
    struct Field {
        let keyPath: WritableKeyPath<MealNutrients, Double?>
        let channelKey: String
        let type: HKQuantityTypeIdentifier
        let unit: HKUnit
    }

    /// Die acht — die Schlüssel buchstabengleich zur Dart-Seite
    /// (`app/lib/health/health_channel.dart`).
    static let fields: [Field] = [
        Field(keyPath: \.kcal, channelKey: "kcal",
              type: .dietaryEnergyConsumed, unit: .kilocalorie()),
        Field(keyPath: \.proteinG, channelKey: "proteinG",
              type: .dietaryProtein, unit: .gram()),
        Field(keyPath: \.carbsG, channelKey: "carbsG",
              type: .dietaryCarbohydrates, unit: .gram()),
        Field(keyPath: \.fatG, channelKey: "fatG",
              type: .dietaryFatTotal, unit: .gram()),
        Field(keyPath: \.saturatedFatG, channelKey: "saturatedFatG",
              type: .dietaryFatSaturated, unit: .gram()),
        Field(keyPath: \.sugarG, channelKey: "sugarG",
              type: .dietarySugar, unit: .gram()),
        Field(keyPath: \.fiberG, channelKey: "fiberG",
              type: .dietaryFiber, unit: .gram()),
        Field(keyPath: \.waterMl, channelKey: "waterMl",
              type: .dietaryWater, unit: .literUnit(with: .milli)),
    ]

    /// Die eigene Metadaten-Kennung, die alle Proben einer Mahlzeit
    /// zusammenhält. Beginnt nicht mit `HK` — das ist Apples Namensraum.
    static let mealIDKey = "de.rosenbach.repit.mahlzeit"

    /// Die Einzelproben einer Mahlzeit: je **vorhandenem** Nährwert genau
    /// eine, für einen fehlenden keine. Eine echte `0` wird geschrieben —
    /// 0 g Zucker ist eine Angabe.
    static func quantitySamples(for nutrients: MealNutrients,
                                at date: Date,
                                metadata: [String: Any]? = nil) -> [HKQuantitySample] {
        fields.compactMap { field in
            guard let wert = nutrients[keyPath: field.keyPath] else { return nil }
            return HKQuantitySample(type: HKQuantityType(field.type),
                                    quantity: HKQuantity(unit: field.unit, doubleValue: wert),
                                    start: date, end: date,
                                    metadata: metadata)
        }
    }

    /// Eine gelesene Food-Korrelation als Mahlzeit.
    ///
    /// **#232:** Ein Typ ohne Probe bleibt `nil`. Vorher stand hier
    /// `.reduce(0, +)` über eine möglicherweise leere Liste, und eine
    /// Mahlzeit, die nur Eiweiß trug, erschien mit 0 kcal. Mehrere Proben
    /// desselben Typs werden summiert.
    static func meal(from food: HKCorrelation, sourceBundleID: String) -> NutritionMeal {
        var nutrients = MealNutrients()
        for field in fields {
            let werte = food.objects(for: HKQuantityType(field.type))
                .compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: field.unit) }
            guard !werte.isEmpty else { continue }
            nutrients[keyPath: field.keyPath] = werte.reduce(0, +)
        }
        // „Mahlzeit" ist kein erfundener Wert, sondern der Name, den die
        // Health-App für eine Korrelation ohne Lebensmittelnamen zeigt —
        // ein Name ist Pflicht im Kanal, ein Nährwert nicht.
        let name = food.metadata?[HKMetadataKeyFoodType] as? String ?? "Mahlzeit"
        return NutritionMeal(time: food.startDate, name: name,
                             sourceBundleID: sourceBundleID, nutrients: nutrients)
    }

    /// Der Quellenfilter: alles, dessen Quelle **nicht genau** `ownBundleID`
    /// ist. Verglichen wird die Quelle, nicht Uhrzeit oder UUID, und auf
    /// Gleichheit, nicht auf Präfix — eine fremde App, deren Kennung mit
    /// unserer beginnt, bleibt fremd.
    static func foreignMeals(_ meals: [NutritionMeal],
                             ownBundleID: String) -> [NutritionMeal] {
        meals.filter { $0.sourceBundleID != ownBundleID }
    }

    /// Ob ein Schreibfehler endgültig ist (→ `nicht_moeglich`) oder einen
    /// späteren Versuch verdient (→ bleibt `offen`).
    ///
    /// Endgültig ist **nur** `errorInvalidArgument`: HealthKit hat den Wert
    /// selbst abgelehnt, und derselbe Wert scheitert beim nächsten Mal
    /// wieder. Alles andere gilt als vorübergehend — fehlende oder
    /// entzogene Freigabe holt der Nachlauf nach, ein gesperrtes Gerät
    /// geht vorüber. Auch `errorHealthDataRestricted` (Geräteverwaltung)
    /// und `errorHealthDataUnavailable` bleiben vorübergehend: Beides
    /// betrifft das Gerät, nicht den Eintrag, und `nicht_moeglich` wird nie
    /// wieder versucht. Lieber einmal zu oft schreiben als eine Kopie für
    /// immer aufgeben.
    static func isPermanentWriteRejection(_ error: Error) -> Bool {
        guard let hk = error as? HKError else { return false }
        return hk.code == .errorInvalidArgument
    }
}
