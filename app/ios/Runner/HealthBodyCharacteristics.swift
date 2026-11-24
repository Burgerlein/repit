import Foundation

/// Körpergröße und Geburtsjahr aus Apple Health (#306) — ein **zweites**
/// Protokoll neben `HealthReading`, keine achte Methode an ihm.
///
/// **Warum das nicht im Protokoll `HealthReading` steht.** Jenes liegt in
/// `Packages/TrainingsCore` und gehört auch der eingefrorenen Swift-App;
/// eine neue Protokollmethode zwänge sie zur Implementierung, und das wäre
/// eine neue Funktion in einer App, die eingefroren ist (`CLAUDE.md`, „Die
/// eingefrorene Swift-App"). Dieses Protokoll liegt deshalb allein in
/// `app/ios/Runner/` und wird allein vom Flutter-Kanal benutzt — dieselbe
/// Aufteilung wie bei `HealthWeightWriting`.
///
/// **Der Schnitt ist auch der ehrlichere: Ein Merkmal ist kein Sample.**
/// `HKCharacteristicTypeIdentifierDateOfBirth` wird nicht abgefragt,
/// sondern abgelesen — `store.dateOfBirthComponents()` ist synchron, hat
/// kein Zeitfenster, keine Statistik und keine Quelle, die
/// zusammenzuführen wäre. Die sieben Methoden von `HealthReading` nehmen
/// alle `from`/`through`; diese eine nimmt nichts.
///
/// Auf der Dart-Seite gibt es denselben Schnitt aus einem zweiten Grund:
/// Dort müsste jede der über zwanzig bestehenden Testattrappen eine achte
/// Methode nachliefern (Begründung in
/// `app/test/health/koerpermerkmale_test.dart`).
///
/// Verbindlich festgelegt durch
/// `app/ios/RunnerTests/HealthChannelBodyCharacteristicsTests.swift`.
protocol BodyCharacteristicsReading {

    /// Körpergröße und Geburtsjahr, soweit hinterlegt **und** freigegeben.
    ///
    /// „Nicht hinterlegt" und „Lesen verweigert" sind nicht unterscheidbar
    /// — Apple verrät den Lesestatus nicht. Beides kommt als `nil` zurück,
    /// niemals als `0` und niemals als geschätzte Zahl.
    func bodyCharacteristics() async throws -> BodyCharacteristics
}

/// Die beiden Angaben, ohne die `kalorienziel` aus `trainings_core`
/// **nichts** rechnet: Mifflin-St Jeor braucht Gewicht, Größe und Alter.
///
/// Liegt neben dem Protokoll und nicht in `Packages/TrainingsCore` — aus
/// demselben Grund, und weil es ein Transporttyp ist, der keine Rechnung
/// trägt (`CLAUDE.md`, „Transporttypen gehören nicht in den Kern").
struct BodyCharacteristics {

    /// Körpergröße in Zentimetern, **ungerundet**. HealthKit liefert eine
    /// Länge als `HKQuantity`; 1,806 m sind 180,6 cm. Gerundet wird genau
    /// einmal, drüben beim Ablegen in `Stammdaten.groesseCm` (ein `Int`).
    /// Wer hier schon rundet, hat zwei Stellen, an denen ein halber
    /// Zentimeter verschwinden kann.
    let heightCm: Double?

    /// Das Geburts**jahr**, nicht das Geburtsdatum. `Stammdaten` trägt
    /// bewusst keines: Mifflin-St Jeor braucht das Alter in Jahren, und
    /// ein Datum wäre eine Angabe mehr, als die Formel trägt — und eine
    /// Angabe mehr, die in jedes Gerätebackup mitwandert.
    let birthYear: Int?

    init(heightCm: Double?, birthYear: Int?) {
        self.heightCm = heightCm
        self.birthYear = birthYear
    }
}
