import Foundation
import HealthKit

/// Gewicht von Hand eintragen (#270) — der erste Fall, in dem die App nach
/// HealthKit **schreibt**.
///
/// **Warum das nicht im Protokoll `HealthReading` steht.** Jenes liegt in
/// `Packages/TrainingsCore` und gehört auch der eingefrorenen Swift-App;
/// eine neue Protokollmethode zwänge sie zur Implementierung, und das wäre
/// eine neue Funktion in einer App, die eingefroren ist (`CLAUDE.md`, „Die
/// eingefrorene Swift-App"). Dieses Protokoll liegt deshalb allein in
/// `app/ios/Runner/` und wird allein vom Flutter-Kanal benutzt.
///
/// Auf der Dart-Seite gibt es die Trennung nicht: Dort ist `HealthReading`
/// die einzige Schnittstelle, die Views und Provider kennen, und eine
/// zweite daneben hieße, dass ein Mock an zwei Stellen vollständig sein
/// müsste.
protocol HealthWeightWriting {

    /// Fragt die **Schreib**freigabe an und sagt, was dabei herauskam.
    ///
    /// Eine Methode, nicht zwei: `requestAuthorization(toShare:)` gibt
    /// selbst keine Auskunft, `authorizationStatus(for:)` unmittelbar
    /// danach schon. Zwei Kanalmethoden ließen dazwischen einen Zustand zu,
    /// den es nicht gibt.
    func requestWeightWriteAuthorization() async throws -> HKAuthorizationStatus

    /// Schreibt eine Gewichtsprobe und liefert ihre UUID.
    func writeWeight(kg: Double, at date: Date) async throws -> UUID

    /// Löscht eine Probe, die **diese App** geschrieben hat. Fremde gibt
    /// Apple nicht frei; der Versuch wirft.
    func deleteWeight(id: UUID) async throws

    /// Die Gewichtsproben im Zeitraum — mit Uhrzeit, UUID und Kennzeichen.
    ///
    /// Die zusätzliche Abfrage neben `DailyMetrics.weightKg`: Jene kommt
    /// aus einer `HKStatisticsCollectionQuery` und trägt keines der drei.
    func weightSamples(from: Date, through: Date) async throws -> [WeightSample]
}

/// Eine einzelne Wägung, so wie HealthKit sie führt.
///
/// Liegt neben dem Protokoll und nicht in `Packages/TrainingsCore` — aus
/// demselben Grund, und weil es ein Transporttyp ist, der keine Rechnung
/// trägt (`CLAUDE.md`, „Transporttypen gehören nicht in den Kern").
///
/// Verbindlich festgelegt durch
/// `app/ios/RunnerTests/HealthChannelWeightTests.swift`.
struct WeightSample {

    /// Die HealthKit-UUID. Als `UUID`, nicht als `String` — hier ist der
    /// Typ bekannt, und erst der Codec macht eine Zeichenkette daraus
    /// (dieselbe Form wie `WorkoutSample.id`).
    let id: UUID

    /// Der Zeitpunkt der Wägung. `start == end` bei einer Probe.
    let date: Date

    let kg: Double

    /// `HKMetadataKeyWasUserEntered` — **nicht** unsere Buchhaltung. Damit
    /// trägt das Kennzeichen auch für Werte, die direkt in der Health-App
    /// eingetragen wurden, und eine Waage, die über ihre eigene App
    /// schreibt, bekommt es nicht.
    let wasUserEntered: Bool

    init(id: UUID, date: Date, kg: Double, wasUserEntered: Bool) {
        self.id = id
        self.date = date
        self.kg = kg
        self.wasUserEntered = wasUserEntered
    }
}
