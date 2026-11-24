import Foundation

/// Werte, die als einzelne Messpunkte gebraucht werden — für die Spannen
/// im Schlaf und für die Nachtwerte (#193). Alles andere kommt als
/// Tageswert.
///
/// Die HRV steht hier, obwohl `DailyMetrics.hrvMs` sie auch führt: Das ist
/// Apples Tagesmittel, und genau daran hängt der Fehler aus #193. Der
/// Nachtwert braucht die Einzelproben im Schlaffenster.
///
/// **Welcher HealthKit-Typ und welche Einheit zu einer Art gehören, steht
/// nicht hier**, sondern in `app/ios/Runner/HealthKitReading.swift`: Dieses
/// Paket importiert nur Foundation und darf `HealthKit` nicht kennen.
///
/// `CaseIterable`, damit ein später hinzukommender Fall auffällt, statt eine
/// Zuordnung still unvollständig zu lassen.
public enum VitalKind: Sendable, CaseIterable {
    case heartRate, respiratoryRate, heartRateVariability
}

/// Einzige Schnittstelle zu Gesundheitsdaten. Views sprechen nie direkt mit
/// HealthKit, sonst wäre die Mock-Implementierung wertlos.
public protocol HealthReading: Sendable {
    /// Das Älteste, was die Quelle überhaupt hergibt. Weiter zurück zu fragen
    /// bringt nichts und kostet nur Zeit. Ohne Grenze fragt die App ab hier.
    var earliestPermittedDate: Date { get }
    func requestAuthorization() async throws
    func dailyMetrics(from: Date, through: Date) async throws -> [DailyMetrics]
    /// Nächte, aufsteigend. Jede Nacht zählt zu dem Tag, an dem man aufwacht.
    func sleepSessions(from: Date, through: Date) async throws -> [SleepNight]
    func workouts(from: Date, through: Date) async throws -> [WorkoutSample]
    func quantitySamples(_ kind: VitalKind, from: Date,
                         through: Date) async throws -> [QuantitySample]
    /// Schritte je Stunde — die Reihe hinter der Stufe „Tag“. Ein eigener
    /// Lauf, weil `dailyMetrics` in Tagesschritten rechnet. Bewusst **ohne**
    /// Vorgabewert in einer Protokollerweiterung: Wer das Protokoll erfüllt,
    /// soll sich entscheiden müssen, statt stillschweigend nichts zu liefern.
    func hourlySteps(from: Date, through: Date) async throws -> [QuantitySample]
    func nutritionEntries(on day: Date) async throws -> [NutritionEntry]
}
