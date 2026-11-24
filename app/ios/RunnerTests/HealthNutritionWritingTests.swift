import Foundation
import HealthKit
import Testing
@testable import Runner

/// Die Swift-Hälfte des Ernährungs-Kanals (#283, mit #232) — Quellenfilter,
/// fehlende Nährwerte, Schreibkatalog, Argumentprüfung und der Wächter aus
/// #317.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest — wie jede Testdatei dieses Projekts außer
/// dem unveränderten `flutter create`-Gerüst `RunnerTests.swift`.
///
/// ## Woher die Regeln kommen
///
/// - Ticket #283 und #232 (Board), „Fertig, wenn": eine eigene Probe wird
///   beim Lesen übersprungen, eine fremde mit derselben Uhrzeit nicht, ein
///   fehlender Nährwert kommt als fehlendes Feld zurück statt als `0`.
/// - `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Task 5 und
///   „Review Focus" 2 und 5.
/// - `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, Abschnitte
///   „Quellen — der Schutz gegen Doppelzählung", „Apple Health — die
///   Kopie", „Wenn die Schreibfreigabe fehlt", „Löschen".
/// - `CLAUDE.md`, Datenschicht: „`nil` darf auf dem Weg durch den Kanal
///   niemals zu `0` werden" und „Ein falscher Typ wirft, statt still null
///   zu werden".
/// - Commit `ea1a6d6` (#317): Eine Schreibanfrage mit `read: []` kostete
///   die App ihr Leserecht.
///
/// ## Korrelation oder Einzelproben — diese Datei legt es nicht fest
///
/// Ob `HKCorrelationTypeIdentifierFood` geschrieben werden darf, entscheidet
/// ein Versuch des Implementierenden im Simulator (Plan, Task 5, Step 1).
/// Die Schnittstelle unten trägt **beide** Wege: [HealthNutrition
/// .quantitySamples] liefert die Einzelproben einer Mahlzeit; wer eine
/// Korrelation schreibt, packt genau diese Proben hinein, wer Einzelproben
/// schreibt, speichert sie mit gemeinsamen Metadaten. Geprüft wird nur,
/// **welche** Proben entstehen — nie, ob sie in einer Korrelation stecken.
///
/// ## Erwartete neue API, die es ohne diese Datei nicht gäbe
///
/// Alles in `app/ios/Runner/` — **nichts** in `Packages/TrainingsCore`. Das
/// Paket ist eingefroren, und `TrainingsCore.NutritionEntry` mit seinen
/// nicht-optionalen Feldern gehört der eingefrorenen App; ihn optional zu
/// machen wäre eine neue Funktion dort. Der Kanal bekommt deshalb einen
/// eigenen Transporttyp.
///
/// ```swift
/// /// Die acht Nährwerte, die geschrieben und gelesen werden. Jedes Feld
/// /// optional, `nil` heißt „keine Angabe" und nie „0".
/// struct MealNutrients: Equatable {
///     var kcal: Double?          // HKQuantityTypeIdentifierDietaryEnergyConsumed, kcal
///     var proteinG: Double?      // …DietaryProtein, g
///     var carbsG: Double?        // …DietaryCarbohydrates, g
///     var fatG: Double?          // …DietaryFatTotal, g
///     var saturatedFatG: Double? // …DietaryFatSaturated, g
///     var sugarG: Double?        // …DietarySugar, g
///     var fiberG: Double?        // …DietaryFiber, g
///     var waterMl: Double?       // …DietaryWater, ml
///     init(kcal: Double? = nil, proteinG: Double? = nil, carbsG: Double? = nil,
///          fatG: Double? = nil, saturatedFatG: Double? = nil,
///          sugarG: Double? = nil, fiberG: Double? = nil, waterMl: Double? = nil)
/// }
///
/// /// Eine Mahlzeit, wie der Kanal sie liest. Ersetzt auf dem Kanal
/// /// `TrainingsCore.NutritionEntry`; die eingefrorene App behält ihren Typ.
/// struct NutritionMeal {
///     let time: Date
///     let name: String
///     /// Die Quelle — bleibt auf der Swift-Seite und geht NICHT über den
///     /// Kanal (Spec: „dann wäre sie ein Transporttyp mehr, der eine
///     /// Rechnung trägt").
///     let sourceBundleID: String
///     let nutrients: MealNutrients
/// }
///
/// /// Die reinen Funktionen hinter Lesen und Schreiben — prüfbar ohne
/// /// HKHealthStore.
/// enum HealthNutrition {
///     /// Die Einzelproben einer Mahlzeit: je vorhandenem Nährwert genau
///     /// eine, für einen fehlenden keine. Weitere Parameter (Metadaten)
///     /// sind erlaubt, solange sie einen Standardwert haben.
///     static func quantitySamples(for nutrients: MealNutrients,
///                                 at date: Date) -> [HKQuantitySample]
///
///     /// Eine gelesene Food-Korrelation als Mahlzeit. Die Quelle kommt als
///     /// Argument, weil ein nicht gespeichertes Objekt keine hat.
///     static func meal(from food: HKCorrelation,
///                      sourceBundleID: String) -> NutritionMeal
///
///     /// Der Quellenfilter: alles, dessen Quelle NICHT genau `ownBundleID`
///     /// ist.
///     static func foreignMeals(_ meals: [NutritionMeal],
///                              ownBundleID: String) -> [NutritionMeal]
///
///     /// Ob ein Schreibfehler endgültig ist (→ `nicht_moeglich`) oder
///     /// einen späteren Versuch verdient (→ bleibt `offen`).
///     static func isPermanentWriteRejection(_ error: Error) -> Bool
/// }
///
/// /// Neben `HealthWeightWriting`, aus demselben Grund nicht in
/// /// `HealthReading` (Spec, „Der Weg existiert schon").
/// protocol HealthNutritionWriting {
///     func requestNutritionWriteAuthorization() async throws -> HKAuthorizationStatus
///     func writeMeal(name: String, at date: Date,
///                    nutrients: MealNutrients) async throws -> UUID
///     func deleteMeal(id: UUID) async throws
///     func nutritionMeals(on day: Date) async throws -> [NutritionMeal]  // schon gefiltert
/// }
///
/// extension HealthChannel {
///     /// `time` (ms), `name`, und je vorhandenem Nährwert sein Schlüssel.
///     /// Fehlt ein Wert, fehlt der Schlüssel. Kein Schlüssel für die Quelle.
///     static func alsMap(_ meal: NutritionMeal) -> [String: Any]
///
///     /// `name` (String), `at` (ms), dazu die Nährwertschlüssel wie oben.
///     /// nil bei fehlendem `name`/`at`, bei einem falsch getypten Feld und
///     /// wenn **kein einziger** Nährwert dabei ist.
///     static func writeMealArgs(_ arguments: Any?)
///         -> (name: String, at: Date, nutrients: MealNutrients)?
///
///     /// `id` als UUID-Zeichenkette — dieselbe Form wie `deleteWeightArgs`.
///     static func deleteMealArgs(_ arguments: Any?) -> UUID?
/// }
/// ```
///
/// Dazu im Kanal drei neue Fallunterscheidungen
/// (`requestNutritionWriteAuthorization`, `writeMeal`, `deleteMeal`) und
/// für einen endgültigen Schreibfehler der Fehlercode `write_rejected` —
/// die Dart-Seite macht daraus `HealthWriteRejected`
/// (`app/test/ernaehrung/health_schreiben_kanal_test.dart`).
///
/// ### Die Schlüssel sind buchstabengleich zur Dart-Seite
///
/// `kcal`, `proteinG`, `carbsG`, `fatG`, `saturatedFatG`, `sugarG`,
/// `fiberG`, `waterMl` — die ersten vier wie bisher bei `NutritionEntry`,
/// die übrigen vier in derselben Bauart. Die Dart-Seite prüft dieselben
/// Wörter unabhängig.
///
/// ## Festlegungen dieser Datei — nicht von Tim freigegeben
///
/// - **Eine echte `0` wird als Probe mit `0` geschrieben.** Ein Glas Wasser
///   hat 0 g Zucker, und das ist eine Angabe. Nur `nil` heißt „keine
///   Probe". Folgt aus der Hausregel „eine echte 0 bleibt 0", ist aber
///   meine Lesart.
/// - **Eine Mahlzeit ohne einen einzigen Nährwert ist `badArgs`.** Eine
///   leere Korrelation oder null Einzelproben wären ein Eintrag in Health,
///   der nichts trägt. Die Dart-Seite schickt so etwas gar nicht erst ab.
/// - **Endgültig ist nur `errorInvalidArgument`.** Fehlende oder entzogene
///   Freigabe (`errorAuthorizationDenied`, `…NotDetermined`) ist genau der
///   Fall, den der Nachlauf später nachholt — das ist `offen`, nicht
///   `nicht_moeglich`. Ein gesperrtes Gerät (`errorDatabaseInaccessible`)
///   geht vorüber. Ein unbekannter Fehler gilt als vorübergehend:
///   `nicht_moeglich` wird nie erneut versucht, und lieber einmal zu oft
///   schreiben als eine Kopie für immer aufgeben. Weitere HealthKit-Codes
///   ordnet der Implementierende zu und begründet sie am Code.
/// - **Der Quellenfilter vergleicht auf Gleichheit, nicht auf Präfix.** Die
///   Spec sagt „gleich der eigenen Bundle-ID"; eine fremde App, deren
///   Kennung mit unserer beginnt, ist trotzdem fremd.
///
/// ## Was hier absichtlich nicht geprüft wird
///
/// - **Ein echter `HKHealthStore`-Zugriff** — derselbe Grund wie in
///   `HealthChannelWeightTests.swift`: Im Simulator lässt sich keine
///   Schreibfreigabe erteilen, und der Store ist dauerhaft leer.
/// - **Ob die Korrelation in `toShare` durchgeht.** Das ist der Versuch aus
///   Step 1, kein Test.
/// - **Die Verdrahtung auf der Dart-Seite** (Buchen, Ändern, Löschen,
///   Nachlauf) — `app/test/ernaehrung/health_schreiben_test.dart`.
///
/// ## Erfundene Zahlen
///
/// Jeder Nährwert, jede Kennung und jeder Zeitpunkt hier ist ausgedacht
/// (`CLAUDE.md`: keine echten Gesundheitswerte im Quelltext).
@Suite("Der Ernaehrungs-Kanal: Quellen, fehlende Werte, Schreibkatalog")
struct HealthNutritionWritingTests {

    /// 14.07.2026, 06:30 UTC — ein erfundenes Frühstück.
    private let gegessenMillis = 1_784_010_600_000
    private var gegessen: Date { Date(timeIntervalSince1970: 1_784_010_600) }

    private let eigeneKennung = "de.example.eigene-app"
    private let fremdeKennung = "com.example.fremde-app"

    private var probenId: UUID { UUID(uuidString: "B1B2C3D4-0000-0000-0000-000000000002")! }

    /// Millisekunden so, wie der Standard-Codec sie liefert: als `NSNumber`
    /// (Begründung in `HealthChannelWeightTests.swift`).
    private func millis(_ wert: Int) -> NSNumber { NSNumber(value: Int64(wert)) }

    private func mahlzeit(quelle: String,
                          name: String = "Testbrei",
                          zeit: Date? = nil,
                          naehrwerte: MealNutrients = MealNutrients(kcal: 300, proteinG: 10))
        -> NutritionMeal {
        NutritionMeal(time: zeit ?? gegessen, name: name,
                      sourceBundleID: quelle, nutrients: naehrwerte)
    }

    private func probe(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit,
                       _ wert: Double) -> HKQuantitySample {
        HKQuantitySample(type: HKQuantityType(id),
                         quantity: HKQuantity(unit: unit, doubleValue: wert),
                         start: gegessen, end: gegessen)
    }

    private func korrelation(_ proben: [HKQuantitySample],
                             name: String? = "Testbrei") -> HKCorrelation {
        HKCorrelation(type: HKCorrelationType(.food),
                      start: gegessen, end: gegessen,
                      objects: Set(proben),
                      metadata: name.map { [HKMetadataKeyFoodType: $0] })
    }

    // MARK: - 1) Der Quellenfilter (Review Focus 5)

    @Test("Eine Mahlzeit der eigenen App wird uebersprungen, eine fremde mit derselben Uhrzeit nicht")
    func eigeneUebersprungenFremdeNicht() {
        // Dieselbe Mahlzeit zweimal in HealthKit: unsere Kopie und eine aus
        // einer anderen App, gleiche Uhrzeit, gleicher Name, gleiche Werte.
        // Nur die fremde zaehlt — sonst steht jede gebuchte Mahlzeit
        // doppelt im Ring.
        let eigene = mahlzeit(quelle: eigeneKennung)
        let fremde = mahlzeit(quelle: fremdeKennung)

        let gefiltert = HealthNutrition.foreignMeals([eigene, fremde],
                                                      ownBundleID: eigeneKennung)

        #expect(gefiltert.count == 1)
        #expect(gefiltert.first?.sourceBundleID == fremdeKennung)
        #expect(gefiltert.first?.time == gegessen,
                "die Uhrzeit allein entscheidet nichts — verglichen wird die Quelle")
    }

    @Test("Die Reihenfolge der fremden Mahlzeiten bleibt erhalten")
    func reihenfolgeBleibt() {
        let frueh = mahlzeit(quelle: fremdeKennung, name: "Erste")
        let eigene = mahlzeit(quelle: eigeneKennung, name: "Unsere")
        let spaet = mahlzeit(quelle: "org.example.dritte-app", name: "Zweite",
                             zeit: gegessen.addingTimeInterval(3600))

        let gefiltert = HealthNutrition.foreignMeals([frueh, eigene, spaet],
                                                      ownBundleID: eigeneKennung)

        #expect(gefiltert.map(\.name) == ["Erste", "Zweite"])
    }

    @Test("Nur eigene Mahlzeiten ergeben eine leere Liste")
    func nurEigeneErgibtLeer() {
        let gefiltert = HealthNutrition.foreignMeals(
            [mahlzeit(quelle: eigeneKennung), mahlzeit(quelle: eigeneKennung, name: "Noch eine")],
            ownBundleID: eigeneKennung)

        #expect(gefiltert.isEmpty)
    }

    @Test("Verglichen wird auf Gleichheit, nicht auf Praefix")
    func gleichheitNichtPraefix() {
        // Festlegung dieser Datei, siehe Kopf.
        let aehnlich = mahlzeit(quelle: eigeneKennung + ".andere")

        let gefiltert = HealthNutrition.foreignMeals([aehnlich],
                                                      ownBundleID: eigeneKennung)

        #expect(gefiltert.count == 1,
                "eine Kennung, die mit unserer beginnt, ist trotzdem eine fremde App")
    }

    @Test("Der Lesepfad wendet den Quellenfilter an")
    func lesepfadFiltert() {
        // Textuelle Pruefung, dieselbe Bauart wie in
        // `HealthChannelPortedTests.swift`: Keiner der Tests oben merkte,
        // wenn `foreignMeals` zwar stuende, beim Lesen aber nie aufgerufen
        // wuerde. Gezaehlt wird ueber alle Quelldateien: neben der
        // Definition muss mindestens ein Aufruf stehen.
        let vorkommen = runnerQuellen
            .map { $0.inhalt.components(separatedBy: "foreignMeals(").count - 1 }
            .reduce(0, +)
        let definitionen = runnerQuellen
            .map { $0.inhalt.components(separatedBy: "func foreignMeals(").count - 1 }
            .reduce(0, +)

        #expect(definitionen == 1)
        #expect(vorkommen - definitionen >= 1,
                "foreignMeals wird nirgends aufgerufen — dann zaehlt jede eigene Mahlzeit doppelt")
    }

    // MARK: - 2) Ein fehlender Naehrwert ist ein fehlendes Feld (#232, Review Focus 2)

    @Test("Eine Korrelation nur mit Eiweiss hat keine Kalorien, nicht 0 kcal")
    func nurEiweissHatKeineKalorien() {
        // Genau #232: `.reduce(0, +)` ueber eine leere Liste machte aus
        // „keine Angabe" eine 0, und die Mahlzeit stand mit 0 kcal da.
        let food = korrelation([probe(.dietaryProtein, .gram(), 25)])

        let gelesen = HealthNutrition.meal(from: food, sourceBundleID: fremdeKennung)

        #expect(gelesen.nutrients.proteinG == 25)
        #expect(gelesen.nutrients.kcal == nil)
        #expect(gelesen.nutrients.carbsG == nil)
        #expect(gelesen.nutrients.fatG == nil)
        #expect(gelesen.nutrients.saturatedFatG == nil)
        #expect(gelesen.nutrients.sugarG == nil)
        #expect(gelesen.nutrients.fiberG == nil,
                "eine Mahlzeit ohne Ballaststoffangabe darf die Tagessumme nicht auf 0 ziehen")
        #expect(gelesen.nutrients.waterMl == nil)
    }

    @Test("Eine echte 0 bleibt beim Lesen 0")
    func echteNullBleibtNull() {
        let food = korrelation([probe(.dietaryEnergyConsumed, .kilocalorie(), 0),
                                probe(.dietarySugar, .gram(), 0)])

        let gelesen = HealthNutrition.meal(from: food, sourceBundleID: fremdeKennung)

        #expect(gelesen.nutrients.kcal == 0)
        #expect(gelesen.nutrients.sugarG == 0)
        #expect(gelesen.nutrients.proteinG == nil)
    }

    @Test("Mehrere Proben desselben Typs werden summiert")
    func mehrereProbenSummiert() {
        let food = korrelation([probe(.dietaryEnergyConsumed, .kilocalorie(), 200),
                                probe(.dietaryEnergyConsumed, .kilocalorie(), 150)])

        let gelesen = HealthNutrition.meal(from: food, sourceBundleID: fremdeKennung)

        #expect(gelesen.nutrients.kcal == 350)
    }

    @Test("Alle acht Naehrwerte werden in ihrer Einheit gelesen")
    func alleAchtGelesen() {
        let food = korrelation([
            probe(.dietaryEnergyConsumed, .kilocalorie(), 420),
            probe(.dietaryProtein, .gram(), 21),
            probe(.dietaryCarbohydrates, .gram(), 55),
            probe(.dietaryFatTotal, .gram(), 12),
            probe(.dietaryFatSaturated, .gram(), 4),
            probe(.dietarySugar, .gram(), 9),
            probe(.dietaryFiber, .gram(), 7),
            probe(.dietaryWater, .literUnit(with: .milli), 250)
        ])

        let gelesen = HealthNutrition.meal(from: food, sourceBundleID: fremdeKennung)

        #expect(gelesen.nutrients == MealNutrients(kcal: 420, proteinG: 21, carbsG: 55,
                                                   fatG: 12, saturatedFatG: 4, sugarG: 9,
                                                   fiberG: 7, waterMl: 250))
    }

    @Test("Uhrzeit, Name und Quelle kommen aus der Korrelation und dem Argument")
    func uhrzeitNameQuelle() {
        let food = korrelation([probe(.dietaryProtein, .gram(), 25)], name: "Testquark")

        let gelesen = HealthNutrition.meal(from: food, sourceBundleID: fremdeKennung)

        #expect(gelesen.time == gegessen)
        #expect(gelesen.name == "Testquark")
        #expect(gelesen.sourceBundleID == fremdeKennung)
    }

    @Test("Im Kanal fehlt ein fehlender Naehrwert, statt als 0 dazustehen")
    func kanalLaesstFehlendesWeg() {
        let nurEiweiss = mahlzeit(quelle: fremdeKennung,
                                  naehrwerte: MealNutrients(proteinG: 25))
        let map = HealthChannel.alsMap(nurEiweiss)

        #expect(map["proteinG"] as? Double == 25)
        for schluessel in ["kcal", "carbsG", "fatG", "saturatedFatG",
                           "sugarG", "fiberG", "waterMl"] {
            #expect(!map.keys.contains(schluessel),
                    "\(schluessel) fehlt drueben und darf hier nicht als 0 oder NSNull stehen")
        }
    }

    @Test("Im Kanal bleibt eine echte 0 eine 0")
    func kanalBehaeltEchteNull() {
        let wasser = mahlzeit(quelle: fremdeKennung, name: "Testwasser",
                              naehrwerte: MealNutrients(kcal: 0, sugarG: 0, waterMl: 500))
        let map = HealthChannel.alsMap(wasser)

        #expect(map["kcal"] as? Double == 0)
        #expect(map["sugarG"] as? Double == 0)
        #expect(map["waterMl"] as? Double == 500)
    }

    @Test("Im Kanal stehen Zeit in Millisekunden, Name und alle acht Schluessel")
    func kanalVollstaendig() {
        let voll = mahlzeit(quelle: fremdeKennung, name: "Testteller",
                            naehrwerte: MealNutrients(kcal: 420, proteinG: 21, carbsG: 55,
                                                      fatG: 12, saturatedFatG: 4, sugarG: 9,
                                                      fiberG: 7, waterMl: 250))
        let map = HealthChannel.alsMap(voll)

        #expect(map["time"] as? Int == gegessenMillis)
        #expect(map["name"] as? String == "Testteller")
        #expect(map["kcal"] as? Double == 420)
        #expect(map["proteinG"] as? Double == 21)
        #expect(map["carbsG"] as? Double == 55)
        #expect(map["fatG"] as? Double == 12)
        #expect(map["saturatedFatG"] as? Double == 4)
        #expect(map["sugarG"] as? Double == 9)
        #expect(map["fiberG"] as? Double == 7)
        #expect(map["waterMl"] as? Double == 250)
    }

    @Test("Die Quelle geht nicht ueber den Kanal")
    func quelleBleibtDrueben() {
        // Spec: Der Filter sitzt auf der Swift-Seite. Kaeme die Quelle mit,
        // waere sie ein Transporttyp mehr, der eine Rechnung traegt.
        let map = HealthChannel.alsMap(mahlzeit(quelle: fremdeKennung))

        #expect(Set(map.keys).isSubset(of: ["time", "name", "kcal", "proteinG", "carbsG",
                                            "fatG", "saturatedFatG", "sugarG", "fiberG",
                                            "waterMl"]))
        #expect(!map.values.contains { ($0 as? String) == fremdeKennung })
    }

    // MARK: - 3) Ein falscher Typ wirft, statt still nil zu werden

    private func vollstaendigeArgs() -> [String: Any] {
        ["name": "Testbrei", "at": millis(gegessenMillis),
         "kcal": 300.0, "proteinG": 10.0]
    }

    @Test("writeMealArgs liest Name, Zeitpunkt und die vorhandenen Naehrwerte")
    func writeMealArgsLiest() {
        let gelesen = HealthChannel.writeMealArgs(vollstaendigeArgs())

        #expect(gelesen?.name == "Testbrei")
        #expect(gelesen?.at == gegessen)
        #expect(gelesen?.nutrients == MealNutrients(kcal: 300, proteinG: 10))
    }

    @Test("writeMealArgs liest alle acht Schluessel, auch als NSNumber")
    func writeMealArgsAlleAcht() {
        let args: [String: Any] = [
            "name": "Testteller", "at": millis(gegessenMillis),
            "kcal": NSNumber(value: 420.0), "proteinG": NSNumber(value: 21.0),
            "carbsG": NSNumber(value: 55.0), "fatG": NSNumber(value: 12.0),
            "saturatedFatG": NSNumber(value: 4.0), "sugarG": NSNumber(value: 9.0),
            "fiberG": NSNumber(value: 7.0), "waterMl": NSNumber(value: 250.0)
        ]

        #expect(HealthChannel.writeMealArgs(args)?.nutrients
                == MealNutrients(kcal: 420, proteinG: 21, carbsG: 55, fatG: 12,
                                 saturatedFatG: 4, sugarG: 9, fiberG: 7, waterMl: 250))
    }

    @Test("Ein fehlender Naehrwert bleibt nil und wird nicht 0")
    func writeMealArgsFehlendBleibtNil() {
        let gelesen = HealthChannel.writeMealArgs(vollstaendigeArgs())

        #expect(gelesen?.nutrients.fiberG == nil)
        #expect(gelesen?.nutrients.sugarG == nil)
        #expect(gelesen?.nutrients.waterMl == nil)
    }

    @Test("Ein falsch getypter Naehrwert macht die Argumente ungueltig, statt still zu fehlen")
    func falscherTypIstBadArgs() {
        var args = vollstaendigeArgs()
        args["fiberG"] = "viel"

        #expect(HealthChannel.writeMealArgs(args) == nil,
                "ein Text, wo eine Zahl stehen muss, ist ein Programmierfehler im Kanal — wuerde er still zu nil, fehlte der Wert in Health, und niemand saehe warum")
    }

    @Test("Auch ein falsch getyptes kcal macht die Argumente ungueltig")
    func falscherTypKcal() {
        var args = vollstaendigeArgs()
        args["kcal"] = true

        #expect(HealthChannel.writeMealArgs(args) == nil)
    }

    @Test("writeMealArgs wird nil ohne Name, ohne Zeitpunkt oder bei falsch getyptem Zeitpunkt")
    func writeMealArgsPflichtfelder() {
        var ohneName = vollstaendigeArgs(); ohneName["name"] = nil
        var ohneZeit = vollstaendigeArgs(); ohneZeit["at"] = nil
        var zeitAlsText = vollstaendigeArgs(); zeitAlsText["at"] = "jetzt"

        #expect(HealthChannel.writeMealArgs(ohneName) == nil)
        #expect(HealthChannel.writeMealArgs(ohneZeit) == nil,
                "ein fehlender Zeitpunkt darf nicht still zu jetzt werden — die Mahlzeit landete am falschen Tag")
        #expect(HealthChannel.writeMealArgs(zeitAlsText) == nil)
        #expect(HealthChannel.writeMealArgs(nil) == nil)
        #expect(HealthChannel.writeMealArgs(["Testbrei"] as [Any]) == nil)
    }

    @Test("Eine Mahlzeit ganz ohne Naehrwert ist keine schreibbare Mahlzeit")
    func ohneNaehrwertBadArgs() {
        // Festlegung dieser Datei, siehe Kopf.
        let args: [String: Any] = ["name": "Testbrei", "at": millis(gegessenMillis)]

        #expect(HealthChannel.writeMealArgs(args) == nil)
    }

    @Test("deleteMealArgs liest die UUID und lehnt alles andere ab")
    func deleteMealArgs() {
        #expect(HealthChannel.deleteMealArgs(["id": probenId.uuidString]) == probenId)
        #expect(HealthChannel.deleteMealArgs(["id": "eine-mahlzeit"]) == nil)
        #expect(HealthChannel.deleteMealArgs(["id": millis(42)]) == nil)
        #expect(HealthChannel.deleteMealArgs([String: Any]()) == nil)
        #expect(HealthChannel.deleteMealArgs(nil) == nil)
    }

    // MARK: - 6) Ein fehlender Naehrwert wird nicht als 0-Probe geschrieben

    @Test("Ein fehlender Naehrwert erzeugt keine Probe")
    func fehlendErzeugtKeineProbe() {
        let proben = HealthNutrition.quantitySamples(
            for: MealNutrients(kcal: 300, proteinG: 10), at: gegessen)

        let typen = Set(proben.map(\.quantityType))
        #expect(typen == [HKQuantityType(.dietaryEnergyConsumed),
                          HKQuantityType(.dietaryProtein)],
                "genau die zwei vorhandenen Werte, keine 0-Probe fuer die sechs fehlenden")
        #expect(proben.count == 2)
    }

    @Test("Keine Probe traegt eine erfundene 0")
    func keineErfundeneNull() {
        let proben = HealthNutrition.quantitySamples(
            for: MealNutrients(kcal: 300, proteinG: 10), at: gegessen)

        for probe in proben {
            let wert = probe.quantityType == HKQuantityType(.dietaryEnergyConsumed)
                ? probe.quantity.doubleValue(for: .kilocalorie())
                : probe.quantity.doubleValue(for: .gram())
            #expect(wert != 0)
        }
    }

    @Test("Eine echte 0 wird als Probe geschrieben")
    func echteNullWirdGeschrieben() {
        // Festlegung dieser Datei, siehe Kopf: 0 g Zucker ist eine Angabe.
        let proben = HealthNutrition.quantitySamples(
            for: MealNutrients(sugarG: 0, waterMl: 500), at: gegessen)

        let zucker = proben.first { $0.quantityType == HKQuantityType(.dietarySugar) }
        #expect(zucker?.quantity.doubleValue(for: .gram()) == 0)
        #expect(proben.count == 2)
    }

    @Test("Alle acht Werte werden mit Typ, Einheit und Zeitpunkt geschrieben")
    func alleAchtGeschrieben() {
        let proben = HealthNutrition.quantitySamples(
            for: MealNutrients(kcal: 420, proteinG: 21, carbsG: 55, fatG: 12,
                               saturatedFatG: 4, sugarG: 9, fiberG: 7, waterMl: 250),
            at: gegessen)

        func wert(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
            proben.first { $0.quantityType == HKQuantityType(id) }?
                .quantity.doubleValue(for: unit)
        }

        #expect(proben.count == 8)
        #expect(wert(.dietaryEnergyConsumed, .kilocalorie()) == 420)
        #expect(wert(.dietaryProtein, .gram()) == 21)
        #expect(wert(.dietaryCarbohydrates, .gram()) == 55)
        #expect(wert(.dietaryFatTotal, .gram()) == 12)
        #expect(wert(.dietaryFatSaturated, .gram()) == 4)
        #expect(wert(.dietarySugar, .gram()) == 9)
        #expect(wert(.dietaryFiber, .gram()) == 7)
        #expect(wert(.dietaryWater, .literUnit(with: .milli)) == 250,
                "Wasser in Millilitern, nicht in Litern")
        for probe in proben {
            #expect(probe.startDate == gegessen)
            #expect(probe.endDate == gegessen)
        }
    }

    @Test("Jeder geschriebene Typ steht im Schreibkatalog")
    func geschriebeneTypenSindErlaubt() {
        // Eine Probe eines Typs ausserhalb von `toShare` wirft beim
        // Speichern — der Katalog und der Schreibweg muessen zusammenpassen.
        let proben = HealthNutrition.quantitySamples(
            for: MealNutrients(kcal: 1, proteinG: 1, carbsG: 1, fatG: 1,
                               saturatedFatG: 1, sugarG: 1, fiberG: 1, waterMl: 1),
            at: gegessen)

        for probe in proben {
            #expect(HealthTypeCatalog.writableTypes.contains(probe.quantityType))
        }
    }

    // MARK: - 4) Der Schreibkatalog — nicht gespiegelt

    private var ernaehrungsTypen: Set<HKSampleType> {
        [HKQuantityType(.dietaryEnergyConsumed),
         HKQuantityType(.dietaryProtein),
         HKQuantityType(.dietaryCarbohydrates),
         HKQuantityType(.dietaryFatTotal),
         HKQuantityType(.dietaryFatSaturated),
         HKQuantityType(.dietarySugar),
         HKQuantityType(.dietaryFiber),
         HKQuantityType(.dietaryWater)]
    }

    @Test("Der Schreibkatalog traegt genau Gewicht und die acht Ernaehrungstypen")
    func schreibkatalogGenau() {
        let erwartet = ernaehrungsTypen.union([HKQuantityType(.bodyMass)])

        #expect(
            HealthTypeCatalog.writableTypes == erwartet,
            "Spec: writableTypes waechst um genau die Ernaehrungstypen, die gebucht werden — nicht mehr (Tim, 03.11.2026)"
        )
    }

    @Test("Der Schreibkatalog spiegelt den Lesekatalog nicht")
    func nichtGespiegelt() {
        #expect(HealthTypeCatalog.writableTypes.count == 9)
        // Stichproben aus dem Lesekatalog, die gebucht werden koennten,
        // es aber nicht werden: Mikronaehrstoffe kommen mit dem
        // Vitamin-Schirm und bringen ihren eigenen Dialog.
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.dietarySodium)))
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.dietaryCaffeine)))
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.dietaryVitaminC)))
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.dietaryCholesterol)))
    }

    @Test("Kein Korrelationstyp im Schreibkatalog")
    func keineKorrelationImSchreibkatalog() {
        // Fuer eine Korrelation fragt man die enthaltenen Mengentypen an,
        // nicht die Korrelation selbst — unabhaengig davon, welchen Weg
        // der Versuch aus Step 1 ergibt.
        #expect(!HealthTypeCatalog.writableTypes.contains(HKCorrelationType(.food)))
    }

    @Test("Der Lesekatalog behaelt die Ernaehrungstypen")
    func lesekatalogUnberuehrt() {
        let lesbar = Set(HealthTypeCatalog.allReadableTypeIdentifiers)
        for typ in ernaehrungsTypen {
            #expect(lesbar.contains(typ.identifier),
                    "\(typ.identifier) muss lesbar bleiben — ohne ihn sieht der Ring die fremden Mahlzeiten nicht")
        }
    }

    // MARK: - 5) Die Schreibanfrage gibt den Lesekatalog mit (#317)

    /// Alle Swift-Quelldateien in `app/ios/Runner/`.
    private var runnerQuellen: [(name: String, inhalt: String)] {
        let runner = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // -> .../ios/RunnerTests/
            .deletingLastPathComponent()   // -> .../ios/
            .appendingPathComponent("Runner")
        let namen = (try? FileManager.default.contentsOfDirectory(atPath: runner.path)) ?? []
        return namen
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .compactMap { name in
                let url = runner.appendingPathComponent(name)
                guard let inhalt = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                return (name, inhalt)
            }
    }

    /// Jeder Aufruf `requestAuthorization(toShare: …, read: …)` in den
    /// Runner-Quellen, mit seinen beiden Argumenten.
    private var anfragen: [(datei: String, toShare: String, read: String)] {
        let muster = #"requestAuthorization\(\s*toShare:\s*(.+?),\s*read:\s*(.+?)\)"#
        guard let regex = try? NSRegularExpression(
            pattern: muster, options: [.dotMatchesLineSeparators]) else { return [] }
        var treffer: [(String, String, String)] = []
        for quelle in runnerQuellen {
            let text = quelle.inhalt as NSString
            for m in regex.matches(in: quelle.inhalt,
                                   range: NSRange(location: 0, length: text.length)) {
                let teilen = text.substring(with: m.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let lesen = text.substring(with: m.range(at: 2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                treffer.append((quelle.name, teilen, lesen))
            }
        }
        return treffer
    }

    @Test("Die Runner-Quellen konnten zum Pruefen gelesen werden")
    func quellenLesbar() {
        #expect(runnerQuellen.contains { $0.name == "HealthKitReading.swift" },
                "ohne die Quellen sind die Pruefungen darunter bedeutungslos")
        #expect(!anfragen.isEmpty,
                "keine einzige requestAuthorization-Anfrage gefunden — dann prueft der Waechter nichts")
    }

    @Test("Die Ernaehrungs-Schreibfreigabe ist im Runner implementiert")
    func ernaehrungsAnfrageExistiert() {
        #expect(runnerQuellen.contains { $0.inhalt.contains("func requestNutritionWriteAuthorization") })
    }

    @Test("Keine Schreibanfrage schickt einen leeren oder verkuerzten Lesekatalog")
    func keineSchreibanfrageOhneLesekatalog() {
        // #317, im Simulator gemessen: Mit `read: []` verlor die App ihr
        // Leserecht, sobald sie das Schreibrecht bekam, und HealthKit
        // lieferte danach leer ohne Fehler. Gilt fuer jede Schreibanfrage —
        // die des Gewichts und die der Ernaehrung.
        //
        // Erlaubt sind nur die Ausdruecke, die den vollstaendigen
        // Lesekatalog meinen. Ein Teilkatalog waere derselbe Fehler fuer
        // alle Typen, die er auslaesst.
        let vollerKatalog: Set<String> = [
            "Self.readTypes",
            "HealthKitReading.readTypes",
            "HealthTypeCatalog.allReadableTypes"
        ]
        let schreibanfragen = anfragen.filter { $0.toShare != "[]" }

        #expect(!schreibanfragen.isEmpty, "keine Schreibanfrage gefunden")
        for anfrage in schreibanfragen {
            #expect(
                vollerKatalog.contains(anfrage.read),
                "\(anfrage.datei): requestAuthorization(toShare: \(anfrage.toShare), read: \(anfrage.read)) — der Lesekatalog muss vollstaendig mit (#317)"
            )
        }
    }

    // MARK: - Endgueltig oder voruebergehend

    @Test("Ein von HealthKit abgelehnter Wert ist endgueltig")
    func ungueltigesArgumentIstEndgueltig() {
        #expect(HealthNutrition.isPermanentWriteRejection(HKError(.errorInvalidArgument)))
    }

    @Test("Fehlende oder entzogene Freigabe ist nicht endgueltig — dafuer gibt es den Nachlauf")
    func freigabeIstNichtEndgueltig() {
        #expect(!HealthNutrition.isPermanentWriteRejection(HKError(.errorAuthorizationDenied)))
        #expect(!HealthNutrition.isPermanentWriteRejection(HKError(.errorAuthorizationNotDetermined)))
    }

    @Test("Ein gesperrtes Geraet und ein unbekannter Fehler sind nicht endgueltig")
    func voruebergehendeFehler() {
        #expect(!HealthNutrition.isPermanentWriteRejection(HKError(.errorDatabaseInaccessible)))
        #expect(!HealthNutrition.isPermanentWriteRejection(
            NSError(domain: "de.example.test", code: 1)))
    }

    // MARK: - Verdrahtung im Kanal

    private var healthChannelSource: String {
        runnerQuellen.first { $0.name == "HealthChannel.swift" }?.inhalt ?? ""
    }

    @Test("Die drei neuen Kanalmethoden sind als Fallunterscheidung verdrahtet")
    func dreiMethodenVerdrahtet() {
        // Buchstabengleich zu `app/lib/health/health_channel.dart`.
        #expect(!healthChannelSource.isEmpty)
        for methode in ["requestNutritionWriteAuthorization", "writeMeal", "deleteMeal"] {
            #expect(
                healthChannelSource.contains("\"\(methode)\""),
                "\(methode) fehlt als Fallunterscheidung im Kanal — der Aufruf liefe ins FlutterMethodNotImplemented"
            )
        }
    }

    @Test("Der Kanal kennt den Fehlercode fuer einen endgueltigen Schreibfehler")
    func fehlercodeVerdrahtet() {
        // Die Dart-Seite macht aus genau diesem Code `HealthWriteRejected`
        // und daraus `nicht_moeglich`. Jeder andere Fehler laesst den
        // Eintrag `offen`.
        #expect(healthChannelSource.contains("\"write_rejected\""))
    }
}
