// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'health_types.dart';

/// Einzige Schnittstelle zu Gesundheitsdaten. Views rufen niemals direkt
/// `HealthChannel` auf, sonst ist eine Mock-Implementierung wertlos
/// (Hausregel, siehe `CLAUDE.md`).
///
/// Dart-Gegenstück zum Swift-Protokoll `HealthReading`
/// (`Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthReading.swift`).
///
/// **Task 12 schließt das Protokoll ab:** Alle sieben Methoden stehen jetzt
/// hier, dazu `earliestPermittedDate`. Letzteres zählt bewusst nicht zu den
/// „sieben Methoden über den Kanal" (siehe `HealthChannel.earliestPermittedDate`
/// und `task-12-brief.md`) — es ist eine Eigenschaft, keine asynchrone
/// Abfrage, und läuft deshalb nie über den Platform-Channel.
abstract class HealthReading {
  /// Das Älteste, was die Quelle überhaupt hergibt. Weiter zurück zu fragen
  /// bringt nichts und kostet nur Zeit. Ohne Grenze fragt die App ab hier.
  DateTime get earliestPermittedDate;

  Future<void> requestAuthorization();

  /// Tageswerte für jeden Kalendertag zwischen `from` und `through`
  /// (beide einschließlich).
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through);

  /// Nächte, aufsteigend. Jede Nacht zählt zu dem Tag, an dem man aufwacht.
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through);

  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through);

  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  );

  /// Schritte je Stunde — die Reihe hinter der Stufe „Tag". Ein eigener
  /// Aufruf, weil `dailyMetrics` in Tagesschritten rechnet.
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through);

  Future<List<NutritionEntry>> nutritionEntries(DateTime day);

  // ── Gewicht von Hand eintragen (#270) ────────────────────────────────
  //
  // Der erste Fall, in dem die App nach HealthKit **schreibt**. Auf der
  // Swift-Seite liegt das nicht im Protokoll `HealthReading` aus
  // `Packages/TrainingsCore`: Das gehört auch der eingefrorenen App, und
  // eine neue Protokollmethode zwänge sie zur Implementierung. Dort trägt
  // ein eigenes, kleines Protokoll allein in `app/ios/Runner/`.
  //
  // Hier in Dart gibt es diese Trennung nicht — `HealthReading` ist die
  // einzige Schnittstelle, die Views und Provider kennen, und eine zweite
  // daneben hieße, dass es zwei Stellen gäbe, an denen ein Mock vollständig
  // sein muss.

  /// Fragt die **Schreib**freigabe für Gewicht an und sagt, was dabei
  /// herauskam. Sie ist von der Lesefreigabe getrennt und umfasst **nur**
  /// `HKQuantityTypeIdentifierBodyMass`.
  ///
  /// Eine Methode, nicht zwei: Anfragen und Status sind auf dem Weg durch
  /// den Kanal eine Bewegung. `requestAuthorization(toShare:)` gibt selbst
  /// keine Auskunft, `authorizationStatus(for:)` unmittelbar danach schon;
  /// zwei Kanalmethoden ließen dazwischen einen Zustand zu, den es nicht
  /// gibt.
  Future<WriteAuthorization> requestWeightWriteAuthorization();

  /// Schreibt eine Gewichtsprobe und liefert ihre HealthKit-UUID.
  Future<String> writeWeight({required double kg, required DateTime at});

  /// Löscht eine Probe, die diese App geschrieben hat. Fremde gibt Apple
  /// nicht frei.
  Future<void> deleteWeight(String id);

  /// Die Gewichtsproben im Zeitraum — mit Uhrzeit, UUID und Kennzeichen.
  ///
  /// Die **zusätzliche** Abfrage neben `DailyMetrics.weightKg`, die
  /// unverändert bleibt: Jene kommt aus einer Statistik und trägt keines
  /// der drei Dinge, die „Letzte Messungen" braucht.
  Future<List<WeightSample>> weightSamples(DateTime from, DateTime through);

  // ── Ernährung nach Health schreiben (#283) ───────────────────────────
  //
  // Dieselbe Bauart wie das Gewicht und **in demselben Protokoll**: Eine
  // zweite Schnittstelle hieße zwei Stellen, an denen ein Mock vollständig
  // sein muss. Die eigene Tabelle ist die Wahrheit; Health bekommt eine
  // Kopie.

  /// Fragt die **Schreib**freigabe für die acht Ernährungstypen an und
  /// sagt, was dabei herauskam — ein eigener Dialog, getrennt von Lesen und
  /// Gewicht. Er erscheint beim ersten Buchen, nicht beim Start.
  Future<WriteAuthorization> requestNutritionWriteAuthorization();

  /// Schreibt eine Mahlzeit und liefert ihre Kennung. Geschrieben werden
  /// nur die acht benannten Werte aus [werte], und nur die vorhandenen —
  /// ein fehlender wird nie als `0` geschrieben. `Naehrwerte.extra` geht
  /// nicht mit; Mikronährstoffe stehen nicht im Schreibkatalog.
  ///
  /// Wirft [HealthWriteRejected], wenn HealthKit die Mahlzeit endgültig
  /// ablehnt; jeder andere Fehler ist vorübergehend.
  Future<String> writeMeal({
    required Naehrwerte werte,
    required String name,
    required DateTime at,
  });

  /// Löscht eine Mahlzeit, die diese App geschrieben hat.
  Future<void> deleteMeal(String id);
}

/// Die beiden Körpermerkmale aus Apple Health (#306) — ein **zweites**
/// Protokoll neben [HealthReading], keine achte Methode an ihm.
///
/// **Warum getrennt.** In Dart muss eine Klasse mit `implements` jedes
/// Mitglied selbst stellen, auch wenn das Protokoll einen Rumpf mitbringt;
/// in `app/test/` liegen über zwanzig Attrappen der Form
/// `class … implements HealthReading`, und eine achte Methode machte sie
/// alle auf einen Schlag rot. Der Schnitt ist aber auch der ehrlichere:
/// Ein Merkmal (`HKCharacteristicType`) ist kein Sample. Die sieben
/// Methoden von [HealthReading] nehmen alle `from`/`through` —
/// [bodyCharacteristics] nimmt nichts.
///
/// **Die Hausregel bleibt gewahrt:** Auch das zweite Protokoll ist ein
/// Protokoll, und `MockHealthReading` erfüllt es. Views rufen weiterhin
/// niemals den Platform-Channel direkt auf.
///
/// Eine Quelle, die dieses Protokoll **nicht** erfüllt, ist ein zulässiger
/// Normalfall: Wer Merkmale braucht, holt sie sich über
/// `as? BodyCharacteristicsReading` und kommt ohne sie zurecht.
abstract class BodyCharacteristicsReading {
  /// Körpergröße und Geburtsjahr, soweit hinterlegt **und** freigegeben.
  ///
  /// „Nicht hinterlegt" und „Lesen verweigert" sind nicht unterscheidbar
  /// (Apple verrät den Lesestatus nicht) — beides kommt als `null` zurück,
  /// niemals als `0` und niemals als geschätzte Zahl.
  Future<BodyCharacteristics> bodyCharacteristics();
}
