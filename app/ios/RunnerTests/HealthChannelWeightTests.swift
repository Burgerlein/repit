import Foundation
import HealthKit
import Testing
@testable import Runner

/// Die Swift-Hälfte des Gewichts-Kanals (#270) — Codec, Freigabestatus,
/// Argumentprüfung und Schreibkatalog.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest — wie jede Testdatei dieses Projekts außer
/// dem unveränderten `flutter create`-Gerüst `RunnerTests.swift`.
///
/// ## Was diese Datei verbindlich festlegt, und warum
///
/// Dies ist der erste Fall, in dem die App nach HealthKit **schreibt**
/// (`docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md`). Die
/// Dart-Seite liegt bereits committet vor und ist damit der Vertrag: Sie
/// legt Kanalnamen, Argumentnamen und Map-Schlüssel fest
/// (`app/lib/health/health_channel.dart`, `app/lib/health/health_types.dart`).
/// Diese Datei schreibt die Swift-Gegenstücke so fest, dass sie
/// buchstabengleich dazu passen — ein abweichender Schlüssel oder ein
/// abweichender Enum-Name fällt hier auf und nicht erst auf dem Gerät, wo
/// `WriteAuthorization.values.byName(...)` drüben werfen würde.
///
/// ### Erwartete neue API, die es ohne diese Datei nicht gäbe
///
/// ```swift
/// // Transporttyp, in `app/ios/Runner/` — NICHT in Packages/TrainingsCore.
/// // Die Spec verbietet das ausdrücklich: Der Kern gehört auch der
/// // eingefrorenen Swift-App, und ein neuer Typ dort wäre eine neue
/// // Funktion in einer eingefrorenen App.
/// struct WeightSample {
///     let id: UUID            // wie WorkoutSample.id, nicht String
///     let date: Date          // start == end bei einer Probe
///     let kg: Double
///     let wasUserEntered: Bool
///     init(id: UUID, date: Date, kg: Double, wasUserEntered: Bool)
/// }
///
/// extension HealthChannel {
///     /// Die vier Schlüssel `id`, `date`, `kg`, `wasUserEntered`.
///     /// Alle vier immer da, keiner optional.
///     static func alsMap(_ sample: WeightSample) -> [String: Any]
///
///     /// HKAuthorizationStatus -> die drei Namen von `WriteAuthorization`
///     /// auf der Dart-Seite. Nicht privat, sonst reicht
///     /// `@testable import` nicht heran — dieselbe Begründung wie bei
///     /// `HealthChannel.vitalKind(_:)`.
///     static func writeAuthorization(_ status: HKAuthorizationStatus) -> String
///
///     /// **Geändert:** nimmt `call.arguments` statt des `FlutterMethodCall`
///     /// und ist nicht mehr privat. Der Grund ist nicht der Test allein:
///     /// Das Auslesen von Argumenten ist eine reine Funktion und braucht
///     /// kein Flutter-Objekt. Die bisherige Fassung
///     /// `fromThrough(_ call: FlutterMethodCall)` entfällt dabei — zwei
///     /// Überladungen nebeneinander wären mehrdeutig, weil jeder
///     /// `FlutterMethodCall` auch ein `Any?` ist.
///     static func fromThrough(_ arguments: Any?) -> (from: Date, through: Date)?
///
///     /// `kg` als Zahl, `at` als Millisekunden seit 1970.
///     static func writeWeightArgs(_ arguments: Any?) -> (kg: Double, at: Date)?
///
///     /// `id` als UUID-Zeichenkette. Eine Zeichenkette, die keine UUID
///     /// ist, wird `nil` — HealthKit findet ohne UUID nichts zu löschen.
///     static func deleteWeightArgs(_ arguments: Any?) -> UUID?
/// }
///
/// extension HealthTypeCatalog {
///     /// Enthält `HKQuantityType(.bodyMass)`. Seit #283 dazu die acht
///     /// Ernährungstypen (`HealthNutritionWritingTests.swift`).
///     static var writableTypes: Set<HKSampleType>
/// }
/// ```
///
/// ## Warum NSNumber in den Argument-Tests steht
///
/// Der Standard-Codec von Flutter liefert Zahlen als `NSNumber`, nicht als
/// native Swift-Zahlen. Das ist kein Detail: `(1 as Any) as? Double` ist in
/// Swift `nil`, `(NSNumber(value: 1) as Any) as? Double` ist `1.0`. Der
/// vorhandene Kanal liest Millisekunden deshalb mit `as? Double`
/// (`HealthChannel.fromThrough`), und das trägt nur, weil drüben eine
/// `NSNumber` ankommt. Die Tests unten bauen die Argumente genauso.
///
/// **Absichtlich offen gelassen:** ob eine native Swift-`Int` als
/// Millisekunden angenommen wird. Aus dem Kanal kommt sie nie, und eine
/// Festlegung hier zwänge den Implementierenden auf `as? Int` oder `as?
/// Double`, ohne dass eine der beiden Antworten richtiger wäre.
///
/// ## Was hier absichtlich nicht geprüft wird
///
/// - **Ein echter `HKHealthStore`-Zugriff.** Der Store des Simulators ist
///   dauerhaft leer (`CLAUDE.md`, „Prüfen im Simulator"), und eine
///   Schreibfreigabe lässt sich dort nicht erteilen. Ein Lauf gegen ihn
///   könnte „nicht erlaubt" nicht von „keine Daten" unterscheiden. Geprüft
///   werden die reinen Funktionen und der Codec — genau die Grenze, die
///   `HealthChannelTests.swift` und `HealthVitalKindTests.swift` auch ziehen.
/// - **Der tatsächliche `MethodChannel`-Transport.** Wie in den
///   Nachbardateien: Beide Seiten prüfen unabhängig gegen dieselben Wörter,
///   die Serialisierung selbst nicht.
/// - **Die Reihenfolge „erst schreiben, dann löschen"** beim Ändern eines
///   Eintrags (Spec, „Was beim Sichern passiert", Punkt 3). Sie liegt in der
///   Dart-Seite, nicht im Kanal.
///
/// ## Erfundene Zahlen
///
/// Jedes Gewicht, jede UUID und jeder Zeitpunkt hier ist ausgedacht
/// (`CLAUDE.md`: keine echten Gesundheitswerte im Quelltext).
@Suite("Der Gewichts-Kanal: Codec, Freigabe, Argumente")
struct HealthChannelWeightTests {

    /// 18.10.2026, 05:20 UTC — derselbe Zeitpunkt, den
    /// `app/test/health/weight_sample_codec_test.dart` auf der Dart-Seite
    /// benutzt (`DateTime.utc(2026, 10, 18, 5, 20)`). Eine Uhrzeit mit
    /// Minuten, weil genau sie der Grund ist, warum eine Statistik für
    /// „Letzte Messungen" nicht reicht.
    private let gemessenMillis = 1_792_300_800_000
    private var gemessen: Date { Date(timeIntervalSince1970: 1_792_300_800) }

    /// Dieselbe erfundene UUID wie auf der Dart-Seite.
    private var probenId: UUID { UUID(uuidString: "A1B2C3D4-0000-0000-0000-000000000001")! }

    // MARK: - A) Der Codec

    @Test("Die vier Schluessel stehen vollstaendig und mit ihrem Wert in der Map")
    func vierSchluesselStehenInDerMap() {
        let sample = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                  wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)

        #expect(map["id"] as? String == probenId.uuidString)
        #expect(map["date"] as? Int == gemessenMillis)
        #expect(map["kg"] as? Double == 58.6)
        #expect(map["wasUserEntered"] as? Bool == true)
    }

    @Test("Die Map traegt genau diese vier Schluessel und keinen fuenften")
    func mapTraegtGenauVierSchluessel() {
        let sample = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                  wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)

        #expect(
            Set(map.keys) == ["id", "date", "kg", "wasUserEntered"],
            "WeightSample.ausMap auf der Dart-Seite liest genau diese vier; ein fuenfter waere eine Festlegung, die niemand getroffen hat"
        )
    }

    @Test("Kein Feld faellt weg, auch nicht wenn es false oder 0 traegt")
    func keinFeldFaelltWeg() {
        // Der nil-wird-nie-0-Vertrag hat hier eine zweite Richtung: Bei
        // DailyMetrics faellt ein fehlendes Feld weg. Hier ist kein Feld
        // optional, also darf auch keines wegfallen — ein fehlendes
        // `wasUserEntered` laesst `WeightSample.ausMap` drueben werfen, und
        // ein `?? false` dort naehme der Zeile still ihre Tuer.
        let vonDerWaage = WeightSample(id: probenId, date: gemessen, kg: 0,
                                       wasUserEntered: false)
        let map = HealthChannel.alsMap(vonDerWaage)

        #expect(map.keys.contains("wasUserEntered"))
        #expect(map["wasUserEntered"] as? Bool == false,
                "false ist die Aussage, dass der Wert von der Waage kommt, und kein fehlender Wert")
        #expect(map.keys.contains("kg"))
        #expect(map["kg"] as? Double == 0)
    }

    @Test("Die UUID geht als Zeichenkette ueber den Kanal, nicht als Objekt")
    func uuidGehtAlsZeichenkette() {
        let sample = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                  wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)

        #expect(map["id"] as? String == "A1B2C3D4-0000-0000-0000-000000000001")
        #expect(map["id"] as? UUID == nil,
                "der Standard-Codec kennt keine UUID; sie muss vorher zur Zeichenkette werden")
    }

    @Test("Das Datum geht in Millisekunden, nicht in Sekunden")
    func datumInMillisekunden() {
        let sample = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                  wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)

        #expect(map["date"] as? Int == 1_792_300_800_000)
        #expect(map["date"] as? Int != 1_792_300_800,
                "DateTime.fromMillisecondsSinceEpoch drueben laege sonst im Jahr 1970")
    }

    @Test("Die Uhrzeit ueberlebt den Codec, nicht nur der Tag")
    func uhrzeitUeberlebtDenCodec() {
        // Genau das kann eine HKStatisticsCollectionQuery nicht, und genau
        // deshalb gibt es diesen Typ neben DailyMetrics.weightKg.
        let frueh = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                 wasUserEntered: true)
        let spaet = WeightSample(id: probenId,
                                 date: gemessen.addingTimeInterval(13 * 3600),
                                 kg: 58.9, wasUserEntered: true)

        #expect(HealthChannel.alsMap(frueh)["date"] as? Int
                != HealthChannel.alsMap(spaet)["date"] as? Int)
    }

    // Rundlauf (simuliert, ohne Geraet) — Teil Swift. Dieselbe Probe, die
    // `app/test/health/weight_sample_codec_test.dart` in seiner `volleMap`
    // von Hand nachbaut und in `WeightSample.ausMap` gibt. Stimmen beide
    // Seiten unabhaengig ueberein, ist der Vertrag an der Kanalgrenze
    // bewiesen — der tatsaechliche Kanaltransport nicht, siehe Dateikopf.
    @Test("Rundlauf — Teil Swift")
    func rundlaufTeilSwift() {
        let sample = WeightSample(id: probenId, date: gemessen, kg: 58.6,
                                  wasUserEntered: true)
        let map = HealthChannel.alsMap(sample)

        #expect(map["id"] as? String == "A1B2C3D4-0000-0000-0000-000000000001")
        #expect(map["date"] as? Int == 1_792_300_800_000)
        #expect(map["kg"] as? Double == 58.6)
        #expect(map["wasUserEntered"] as? Bool == true)
    }

    // MARK: - B) Der Schreibstatus

    @Test("Die drei Status werden auf die drei Dart-Namen abgebildet")
    func dreiStatusDreiNamen() {
        // Buchstabengleich zu `enum WriteAuthorization { granted, denied,
        // notDetermined }` in `app/lib/health/health_types.dart`. Drueben
        // steht `WriteAuthorization.values.byName(roh!)` — ohne `?? denied`,
        // also wirft jeder andere Name.
        #expect(HealthChannel.writeAuthorization(.sharingAuthorized) == "granted")
        #expect(HealthChannel.writeAuthorization(.sharingDenied) == "denied")
        #expect(HealthChannel.writeAuthorization(.notDetermined) == "notDetermined")
    }

    @Test("Die drei Namen sind verschieden und genau die drei der Dart-Seite")
    func dieDreiNamenSindGenauDieDrei() {
        let namen = Set([
            HealthChannel.writeAuthorization(.sharingAuthorized),
            HealthChannel.writeAuthorization(.sharingDenied),
            HealthChannel.writeAuthorization(.notDetermined)
        ])

        #expect(
            namen == ["granted", "denied", "notDetermined"],
            "faellt ein Status mit einem anderen zusammen, kann das Blatt den weggewischten Dialog nicht mehr vom abgelehnten unterscheiden — und nur der erste laesst sich noch einmal fragen"
        )
    }

    @Test("notDetermined bleibt notDetermined und wird nicht zu denied gerundet")
    func notDeterminedBleibtEigenstaendig() {
        // Die Spec: Beide Faelle behandelt das Blatt gleich, aber sie
        // bleiben getrennt, weil nur einer von ihnen durch Nachfragen noch
        // zu `granted` werden kann.
        #expect(HealthChannel.writeAuthorization(.notDetermined) != "denied")
    }

    @Test("Ein unbekannter Status wird niemals granted")
    func unbekannterStatusIstNieGranted() {
        guard let unbekannt = HKAuthorizationStatus(rawValue: 99) else {
            // Swift importiert HKAuthorizationStatus als NS_ENUM; laesst
            // sich hier kein unbekannter Rohwert bilden, kann der Fall auch
            // nicht eintreten und es gibt nichts zu pruefen.
            return
        }
        #expect(
            HealthChannel.writeAuthorization(unbekannt) != "granted",
            "lieber gar nicht gesichert als scheinbar gesichert (Spec, Anti-Ziele)"
        )
    }

    // MARK: - C) Die Argumentpruefung

    /// Millisekunden so, wie der Standard-Codec sie liefert: als `NSNumber`.
    private func millis(_ wert: Int) -> NSNumber { NSNumber(value: Int64(wert)) }

    @Test("writeWeightArgs liest kg und at aus vollstaendigen Argumenten")
    func writeWeightArgsLiestVollstaendigeArgumente() {
        let args: [String: Any] = ["kg": 58.6, "at": millis(gemessenMillis)]
        let gelesen = HealthChannel.writeWeightArgs(args)

        #expect(gelesen?.kg == 58.6)
        #expect(gelesen?.at == gemessen)
    }

    @Test("writeWeightArgs nimmt kg auch als NSNumber")
    func writeWeightArgsNimmtNSNumber() {
        // Der Codec liefert einen Dart-`double` als NSNumber. Beide
        // Schreibweisen muessen durchgehen, damit die Pruefung nicht an der
        // Bruecke scheitert statt an den Daten.
        let args: [String: Any] = ["kg": NSNumber(value: 58.6),
                                   "at": millis(gemessenMillis)]

        #expect(HealthChannel.writeWeightArgs(args)?.kg == 58.6)
    }

    @Test("writeWeightArgs wird nil, wenn kg fehlt")
    func writeWeightArgsOhneKg() {
        let args: [String: Any] = ["at": millis(gemessenMillis)]

        #expect(
            HealthChannel.writeWeightArgs(args) == nil,
            "ein fehlendes kg muss badArgs werden und darf nicht zu einer erfundenen 0 werden"
        )
    }

    @Test("writeWeightArgs wird nil, wenn at fehlt")
    func writeWeightArgsOhneAt() {
        let args: [String: Any] = ["kg": 58.6]

        #expect(
            HealthChannel.writeWeightArgs(args) == nil,
            "ein fehlendes Datum darf nicht stillschweigend zu jetzt werden — der Eintrag landete sonst am falschen Tag"
        )
    }

    @Test("writeWeightArgs wird nil bei falsch getyptem kg")
    func writeWeightArgsFalschGetyptesKg() {
        let args: [String: Any] = ["kg": "achtundfuenfzig",
                                   "at": millis(gemessenMillis)]

        #expect(HealthChannel.writeWeightArgs(args) == nil)
    }

    @Test("writeWeightArgs wird nil bei falsch getyptem at")
    func writeWeightArgsFalschGetyptesAt() {
        let args: [String: Any] = ["kg": 58.6, "at": "jetzt"]

        #expect(HealthChannel.writeWeightArgs(args) == nil)
    }

    @Test("writeWeightArgs wird nil ohne Argumente und bei fremder Gestalt")
    func writeWeightArgsOhneArgumente() {
        #expect(HealthChannel.writeWeightArgs(nil) == nil)
        #expect(HealthChannel.writeWeightArgs([58.6, gemessenMillis] as [Any]) == nil,
                "eine Liste ist keine Argumentkarte")
        #expect(HealthChannel.writeWeightArgs([String: Any]()) == nil)
    }

    @Test("deleteWeightArgs liest die UUID aus der Zeichenkette")
    func deleteWeightArgsLiestUuid() {
        let args: [String: Any] = ["id": "A1B2C3D4-0000-0000-0000-000000000001"]

        #expect(HealthChannel.deleteWeightArgs(args) == probenId)
    }

    @Test("deleteWeightArgs wird nil, wenn id fehlt")
    func deleteWeightArgsOhneId() {
        #expect(HealthChannel.deleteWeightArgs([String: Any]()) == nil)
        #expect(HealthChannel.deleteWeightArgs(nil) == nil)
    }

    @Test("deleteWeightArgs wird nil bei einer Zeichenkette, die keine UUID ist")
    func deleteWeightArgsOhneEchteUuid() {
        let args: [String: Any] = ["id": "eine-probe"]

        #expect(
            HealthChannel.deleteWeightArgs(args) == nil,
            "HealthKit findet ohne UUID nichts zu loeschen; das ist badArgs und kein stiller Fehlschlag"
        )
    }

    @Test("deleteWeightArgs wird nil bei falsch getypter id")
    func deleteWeightArgsFalschGetypteId() {
        let args: [String: Any] = ["id": millis(42)]

        #expect(HealthChannel.deleteWeightArgs(args) == nil)
    }

    @Test("fromThrough liest den Zeitraum fuer weightSamples aus NSNumber-Millisekunden")
    func fromThroughLiestZeitraum() {
        let args: [String: Any] = ["from": millis(gemessenMillis),
                                   "through": millis(gemessenMillis + 86_400_000)]
        let zeitraum = HealthChannel.fromThrough(args)

        #expect(zeitraum?.from == gemessen)
        #expect(zeitraum?.through == gemessen.addingTimeInterval(86_400))
    }

    @Test("fromThrough wird nil, wenn eine der beiden Grenzen fehlt oder nicht passt")
    func fromThroughWirdNilBeiLueckenhaftenArgumenten() {
        #expect(HealthChannel.fromThrough(["from": millis(gemessenMillis)] as [String: Any]) == nil)
        #expect(HealthChannel.fromThrough(["through": millis(gemessenMillis)] as [String: Any]) == nil)
        #expect(HealthChannel.fromThrough(["from": "gestern", "through": "heute"] as [String: Any]) == nil)
        #expect(HealthChannel.fromThrough(nil) == nil)
    }

    // MARK: - D) Der Schreibkatalog

    @Test("Der Schreibkatalog traegt das Koerpergewicht und daneben nur Ernaehrungstypen")
    func schreibkatalogTraegtGenauBodyMass() {
        // Bis #283 war das Gewicht der einzige Typ. Seitdem waechst der
        // Katalog um die acht Ernaehrungstypen — den genauen Satz legt
        // `HealthNutritionWritingTests.schreibkatalogGenau` fest. Hier
        // bleibt der Gewichts-Teil: bodyMass ist drin, und was sonst drin
        // ist, ist ausschliesslich Ernaehrung (`HKQuantityTypeIdentifierDietary…`).
        #expect(
            HealthTypeCatalog.writableTypes.contains(HKQuantityType(.bodyMass)),
            "die Spec zu #270: der Schreibdialog fragt HKQuantityTypeIdentifierBodyMass ab"
        )
        let uebrige = HealthTypeCatalog.writableTypes
            .subtracting([HKQuantityType(.bodyMass)])
        for typ in uebrige {
            #expect(
                typ.identifier.hasPrefix("HKQuantityTypeIdentifierDietary"),
                "\(typ.identifier) steht im Schreibkatalog, ist aber weder Gewicht noch Ernaehrung"
            )
        }
    }

    @Test("Koerperfett und fettfreie Masse stehen nicht im Schreibkatalog")
    func keinKoerperfettImSchreibkatalog() {
        // Nicht-Ziel der Spec: „jede Waage misst da anders". Beide schaetzt
        // eine Waage ueber Bioimpedanz; ein fremder Punkt verbiegt diese
        // Reihen staerker, als eine Luecke ihnen schadet.
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.bodyFatPercentage)))
        #expect(!HealthTypeCatalog.writableTypes.contains(HKQuantityType(.leanBodyMass)))
    }

    @Test("Der Schreibkatalog traegt keinen Trainingstyp")
    func keinWorkoutImSchreibkatalog() {
        // Der Gym-Rueckschreiber aus SPEC 4.4 kommt eigenstaendig und
        // bringt seine eigene Freigabe mit (Spec, Nicht-Ziele).
        #expect(!HealthTypeCatalog.writableTypes.contains(HKObjectType.workoutType()))
    }

    @Test("Der Lesekatalog bleibt vom Schreiben unberuehrt")
    func lesekatalogBleibtUnberuehrt() {
        // Es gibt genau einen Lesedialog je Installation; was dort fehlt,
        // fehlt spaeter rueckwirkend (CLAUDE.md, „Code"). Der Schreibdialog
        // kommt daneben, er ersetzt nichts.
        #expect(HealthTypeCatalog.allReadableTypeIdentifiers
            .contains("HKQuantityTypeIdentifierBodyMass"))
    }

    // MARK: - Die vier Methoden sind im Kanal verdrahtet

    /// Textuelle Pruefung des Quelltexts, nicht des Verhaltens — dieselbe
    /// Bauart und dieselbe Begruendung wie in
    /// `HealthChannelPortedTests.swift`: Keiner der Tests oben wuerde
    /// bemerken, wenn Codec und Hilfsfunktionen zwar stuenden, die
    /// Fallunterscheidung in `handle(_:result:)` aber fehlte. Der Aufruf
    /// liefe dann ins `FlutterMethodNotImplemented`, und auf der Dart-Seite
    /// sieht das wie ein Kanalfehler aus, nicht wie eine vergessene Zeile.
    private var healthChannelSource: String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let healthChannelSwift = thisFile
            .deletingLastPathComponent()   // -> .../ios/RunnerTests/
            .deletingLastPathComponent()   // -> .../ios/
            .appendingPathComponent("Runner")
            .appendingPathComponent("HealthChannel.swift")
        return (try? String(contentsOf: healthChannelSwift, encoding: .utf8)) ?? ""
    }

    @Test("HealthChannel.swift konnte zum Pruefen gelesen werden")
    func quelltextIstLesbar() {
        #expect(!healthChannelSource.isEmpty,
                "ist die Zeichenkette leer, ist der Test darunter bedeutungslos")
    }

    @Test("Alle vier neuen Kanalmethoden sind als Fallunterscheidung verdrahtet")
    func vierNeueMethodenVerdrahtet() {
        // Buchstabengleich zu `_channel.invokeMethod(...)` in
        // `app/lib/health/health_channel.dart`.
        let methoden = [
            "requestWeightWriteAuthorization",
            "writeWeight",
            "deleteWeight",
            "weightSamples"
        ]
        for methode in methoden {
            #expect(
                healthChannelSource.contains("\"\(methode)\""),
                "\(methode) fehlt als Fallunterscheidung im Kanal — der Aufruf liefe ins FlutterMethodNotImplemented statt zum Adapter"
            )
        }
    }
}
