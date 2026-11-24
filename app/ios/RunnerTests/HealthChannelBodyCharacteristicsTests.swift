import Foundation
import HealthKit
import Testing
import TrainingsCore
@testable import Runner

/// Körpergröße und Geburtsjahr auf dem Weg durch den Kanal (#306).
///
/// Beide Typen stehen seit der Installation im Lesekatalog und wurden nie
/// abgefragt: `HKQuantityTypeIdentifierHeight` und
/// `HKCharacteristicTypeIdentifierDateOfBirth`. Ohne sie rechnet
/// `kalorienziel` aus `trainings_core` **nichts** — Mifflin-St Jeor braucht
/// Gewicht, Größe und Alter, und ein geschätztes Alter wäre eine stille
/// Falschauskunft.
///
/// Die Dart-Seite liegt in `app/test/health/koerpermerkmale_test.dart` und
/// `app/test/data/stammdaten_aus_health_test.dart`.
///
/// Swift Testing, nicht XCTest — wie überall sonst in diesem Projekt.
/// **Alle Zahlen sind erfunden**; echte Gesundheitsdaten stehen nie im
/// Quelltext. 1899 ist bewusst kein Geburtsjahr eines lebenden Menschen.
///
/// ## Ein Merkmal ist kein Sample
///
/// `HKCharacteristicTypeIdentifierDateOfBirth` wird nicht abgefragt, sondern
/// abgelesen: `store.dateOfBirthComponents()` ist synchron, hat kein
/// Zeitfenster, keine Statistik und keine Quelle, die zusammenzuführen wäre
/// — und **wirft**, wenn nichts hinterlegt oder nichts freigegeben ist.
/// Genau deshalb hängen die sieben Methoden von `HealthReading` (alle mit
/// `from`/`through`) hier nicht mit drin.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Alles neu, alles in `app/ios/Runner/` — **nichts** in
/// `Packages/TrainingsCore`: Das Paket ist eingefroren, und ein
/// Transporttyp gehört ohnehin nicht in den Kern (`CLAUDE.md`).
///
/// ```swift
/// struct BodyCharacteristics {
///     let heightCm: Double?
///     let birthYear: Int?
/// }
///
/// protocol BodyCharacteristicsReading {
///     func bodyCharacteristics() async throws -> BodyCharacteristics
/// }
///
/// extension HealthKitReading: BodyCharacteristicsReading { … }
///
/// extension HealthChannel {
///     static func alsMap(_ merkmale: BodyCharacteristics) -> [String: Any]
/// }
/// ```
///
/// **Ein zweites Protokoll statt einer achten Methode an `HealthReading`.**
/// `HealthReading` liegt in `Packages/TrainingsCore` und ist eingefroren;
/// eine Methode dazuzunehmen wäre dort eine neue Funktion. Auf der
/// Dart-Seite gibt es denselben Schnitt aus einem zweiten Grund (zwanzig
/// bestehende Testattrappen, Begründung in `koerpermerkmale_test.dart`).
/// `HealthChannel` hält sein `reading` als `HealthReading` und holt sich das
/// Merkmal über `as? BodyCharacteristicsReading` dazu — der Fall „Quelle
/// kann keine Merkmale" ist damit ein Normalfall und kein Absturz.
///
/// ## Zwei Nähte, damit ohne HealthKit-Store geprüft werden kann
///
/// Kein Test in `RunnerTests` fasst bisher einen `HKHealthStore` an, und das
/// soll so bleiben: Der Store des Simulators ist dauerhaft leer, und ein
/// Test, der auf eine Abfrage wartet, prüft am Ende die Laufzeit statt die
/// Rechnung. Die beiden Stellen, an denen in diesem Ticket überhaupt etwas
/// zu entscheiden ist, sind deshalb als reine Funktionen zu bauen:
///
/// ```swift
/// extension HealthKitReading {
///     /// HealthKit liefert eine Länge als `HKQuantity`. Die Umrechnung
///     /// läuft über `HKUnit`, nicht über ein handgeschriebenes `* 100`.
///     static func heightCm(from quantity: HKQuantity) -> Double
///
///     /// Das Geburtsjahr. `lesen` ist in der echten App
///     /// `store.dateOfBirthComponents`; wirft sie, ist das Merkmal nicht
///     /// hinterlegt oder nicht freigegeben — beides heißt hier „fehlt".
///     static func birthYear(lesen: () throws -> DateComponents) -> Int?
/// }
/// ```
///
/// Der letzte Fall unten prüft trotzdem einmal gegen den echten Store, dass
/// `bodyCharacteristics()` diese Nähte auch benutzt: Ein ungenutzter Fänger
/// wäre toter Code, und der Absturz fiele erst auf Tims Gerät auf.
@Suite("Koerpergroesse und Geburtsjahr gehen durch den Kanal")
struct HealthChannelBodyCharacteristicsTests {

    // MARK: - Der Typenkatalog

    @Test("Der Katalog fragt die Koerpergroesse mit an")
    func katalogEnthaeltKoerpergroesse() {
        #expect(
            HealthTypeCatalog.allReadableTypeIdentifiers
                .contains("HKQuantityTypeIdentifierHeight"),
            "es gibt genau einen Berechtigungsdialog je Installation — was hier fehlt, kostet eine Neuinstallation"
        )
    }

    @Test("Der Katalog fragt das Geburtsdatum mit an")
    func katalogEnthaeltGeburtsdatum() {
        #expect(
            HealthTypeCatalog.allReadableTypeIdentifiers
                .contains("HKCharacteristicTypeIdentifierDateOfBirth")
        )
    }

    @Test("Beide Bezeichner landen als Typ in der Leseanfrage")
    func beideSindLesbareTypen() {
        let groesse = HKObjectType.quantityType(forIdentifier: .height)
        let geburtstag = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)
        #expect(groesse != nil)
        #expect(geburtstag != nil)
        #expect(HealthTypeCatalog.allReadableTypes.contains(groesse!))
        #expect(
            HealthTypeCatalog.allReadableTypes.contains(geburtstag!),
            "ein Merkmal braucht dieselbe Freigabe wie ein Sample — ohne sie wirft dateOfBirthComponents() fuer immer"
        )
    }

    // MARK: - Die Umrechnung in Zentimeter

    @Test("Aus Metern werden Zentimeter")
    func meterWerdenZentimeter() {
        let gemessen = HealthKitReading.heightCm(
            from: HKQuantity(unit: .meter(), doubleValue: 1.81)
        )
        #expect(abs(gemessen - 181) < 0.0001)
    }

    @Test("Auch eine glatte Zahl wird umgerechnet")
    func glatteZahlWirdUmgerechnet() {
        // Faengt den Fehler ab, bei dem jemand den Wert durchreicht, weil er
        // „schon in cm aussieht": 2 Meter sind 200 cm, nicht 2.
        let gemessen = HealthKitReading.heightCm(
            from: HKQuantity(unit: .meter(), doubleValue: 2)
        )
        #expect(abs(gemessen - 200) < 0.0001)
    }

    @Test("Eine Groesse in Fuss kommt ebenfalls in Zentimetern an")
    func fussWirdZentimeter() {
        // Der Beleg, dass die Umrechnung ueber HKUnit laeuft und nicht ueber
        // ein handgeschriebenes `* 100`. Welche Einheit in der Probe steckt,
        // entscheidet die App nicht — ein von einem US-Geraet uebernommener
        // Wert kaeme sonst hundertfach zu klein an.
        let gemessen = HealthKitReading.heightCm(
            from: HKQuantity(unit: .foot(), doubleValue: 6)
        )
        #expect(abs(gemessen - 182.88) < 0.0001)
    }

    // MARK: - Das Geburtsjahr

    @Test("Wirft das Merkmal, fehlt das Geburtsjahr — es stuerzt nichts ab")
    func wurfWirdZuFehlt() {
        // `dateOfBirthComponents()` wirft, wenn nichts hinterlegt ist. Das
        // ist der Normalfall eines leeren Health, kein Programmierfehler —
        // und es ist nicht unterscheidbar von „Lesen verweigert".
        struct NichtsHinterlegt: Error {}

        let jahr = HealthKitReading.birthYear(lesen: { throw NichtsHinterlegt() })

        #expect(jahr == nil)
    }

    @Test("Ohne Jahresangabe fehlt das Geburtsjahr")
    func ohneJahrFehltDasJahr() {
        // `DateComponents` kann auch ohne Wurf unvollstaendig sein.
        let jahr = HealthKitReading.birthYear(lesen: { DateComponents() })

        #expect(jahr == nil, "kein Jahr ist kein Jahrgang 0")
    }

    @Test("Ein hinterlegtes Jahr kommt durch")
    func hinterlegtesJahrKommtDurch() {
        let jahr = HealthKitReading.birthYear(lesen: { DateComponents(year: 1899) })

        #expect(jahr == 1899)
    }

    @Test("Vom vollen Geburtsdatum bleibt nur das Jahr")
    func nurDasJahrBleibt() {
        // `Stammdaten` traegt bewusst kein volles Geburtsdatum: Mifflin-St
        // Jeor braucht das Alter in Jahren, und ein Datum waere eine Angabe
        // mehr, als die Formel traegt — und eine Angabe mehr, die in jedes
        // Geraetebackup mitwandert.
        let jahr = HealthKitReading.birthYear(
            lesen: { DateComponents(year: 1899, month: 2, day: 29) }
        )

        #expect(jahr == 1899)
    }

    // MARK: - Der Codec

    @Test("Fehlen beide Merkmale, ist die Map leer")
    func fehlendeMerkmaleFehlenInDerMap() {
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: nil, birthYear: nil)
        )

        #expect(
            !map.keys.contains("heightCm"),
            "kein Wert ist kein Nullwert — eine 0 hier hiesse „0 cm gross\""
        )
        #expect(!map.keys.contains("birthYear"))
    }

    @Test("Fehlt nur die Groesse, steht nur das Geburtsjahr in der Map")
    func nurDasVorhandeneStehtInDerMap() {
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: nil, birthYear: 1899)
        )

        #expect(!map.keys.contains("heightCm"))
        #expect(map["birthYear"] as? Int == 1899)
    }

    @Test("Fehlt nur das Geburtsjahr, steht nur die Groesse in der Map")
    func fehlendesJahrFehltAllein() {
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: 181, birthYear: nil)
        )

        #expect(map["heightCm"] as? Double == 181)
        #expect(!map.keys.contains("birthYear"))
    }

    @Test("Eine krumme Groesse bleibt krumm")
    func krummeGroesseBleibtKrumm() {
        // Gerundet wird genau einmal, und zwar drueben beim Ablegen in
        // `Stammdaten.groesseCm` (ein `Int`). Wer hier schon rundet, hat zwei
        // Stellen, an denen ein halber Zentimeter verschwinden kann.
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: 180.6, birthYear: nil)
        )

        #expect(map["heightCm"] as? Double == 180.6)
    }

    @Test("Eine echte 0 bleibt in der Map stehen")
    func echteNullBleibtInDerMap() {
        // Der Codec urteilt nicht ueber Plausibilitaet, er bildet ab, was
        // drueben stand. Dass eine 0 nie als eingetragene Koerpergroesse in
        // der Stammdaten-Tabelle landet, ist die Zusage der Dart-Seite
        // (`stammdaten_aus_health_test.dart`). Beides zusammen ergibt den
        // Vertrag: nil wird nie 0, und 0 wird nie ein eingetragener Wert.
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: 0, birthYear: nil)
        )

        #expect(map.keys.contains("heightCm"))
        #expect(map["heightCm"] as? Double == 0)
    }

    @Test("Beide Merkmale stehen mit ihrem Typ in der Map")
    func beideMerkmaleStehenInDerMap() {
        let map = HealthChannel.alsMap(
            BodyCharacteristics(heightCm: 181.5, birthYear: 1899)
        )

        #expect(map["heightCm"] as? Double == 181.5)
        #expect(
            map["birthYear"] as? Int == 1899,
            "ein Jahrgang ist eine Ganzzahl — als Double kaeme drueben 1899.0 an"
        )
    }

    // MARK: - Der echte Adapter

    @Test("Der echte Adapter kann Merkmale lesen")
    func adapterErfuelltDasProtokoll() {
        // `HealthChannel` holt sich das Merkmal ueber
        // `as? BodyCharacteristicsReading`. Faellt die Konformitaet weg,
        // bleibt der Kanal stumm, ohne dass irgendetwas scheitert — der
        // Fehler waere erst auf dem Geraet zu sehen.
        #expect((HealthKitReading() as Any) is BodyCharacteristicsReading)
    }

    @Test("Ein leerer Store liefert zweimal nichts, statt zu werfen",
          .timeLimit(.minutes(1)))
    func leererStoreWirftNicht() async throws {
        // Der HealthKit-Store des Simulators ist dauerhaft leer, und
        // freigegeben ist hier gar nichts: `dateOfBirthComponents()` wirft
        // also, und die Groessenabfrage kommt leer zurueck. Genau der
        // Zustand, in dem die App nicht abstuerzen darf.
        //
        // Der einzige Fall in dieser Datei, der einen echten `HKHealthStore`
        // anfasst — und er ist noetig: Ohne ihn koennte `bodyCharacteristics()`
        // die beiden geprueften Naehte oben ignorieren und `try
        // store.dateOfBirthComponents()` ungefangen aufrufen. Tote
        // Hilfsfunktionen bestehen jeden Test.
        guard let adapter = HealthKitReading() as? BodyCharacteristicsReading else {
            Issue.record("HealthKitReading erfuellt BodyCharacteristicsReading nicht")
            return
        }

        let merkmale = try await adapter.bodyCharacteristics()

        #expect(merkmale.heightCm == nil)
        #expect(
            merkmale.birthYear == nil,
            "ein geworfenes Merkmal ist „fehlt\", kein Absturz und keine geschaetzte Zahl"
        )
    }
}
