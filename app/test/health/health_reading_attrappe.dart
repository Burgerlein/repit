// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';

/// Die gemeinsame Basis aller Testattrappen von [HealthReading] (#320) —
/// **Testhilfe, kein Test.**
///
/// Eine Attrappe schreibt `extends HealthReadingAttrappe` und überschreibt
/// nur, was sie wirklich beantworten will. Bis zum 04.11.2026 stand in
/// rund 36 Testdateien `class … implements HealthReading`; jede neue
/// Methode am Protokoll machte sie alle auf einmal rot, und weil der
/// Implementierende Testdateien nicht ändern darf, kostete das jedes Mal
/// einen eigenen Durchgang. Jetzt wird **diese eine Datei** rot.
///
/// ## Was die Basis antwortet
///
/// Für die zwölf bisherigen Methoden genau das, was die Mehrheit der
/// Attrappen schon für „hier nicht benutzt" geantwortet hat — wortgleich
/// übernommen, nicht neu erfunden: leere Listen, eine Lesefreigabe ohne
/// Wirkung, Gewichts-Schreibfreigabe `denied`, werfende Stümpfe für
/// Gewicht schreiben und löschen. Wer anders antwortete, behält seinen
/// Override.
///
/// Die drei Ernährungsmethoden (#283) **werfen**, wie `writeWeight`: Ein
/// Test, der sie braucht, sagt das ausdrücklich. Ein stiller Rückgabewert
/// verdeckte einen Aufruf, den der Test nicht erwartet hat.
///
/// ## Die Abwägung (#320)
///
/// Eine Basis mit Stümpfen verbirgt, wenn ein Test eine Methode aufruft,
/// die er nicht überschreibt — er bekommt dann die Antwort der Basis statt
/// eines Kompilierfehlers. Bei den werfenden Stümpfen bleibt der Fehler
/// laut; bei den leeren Listen ist er so leise wie vorher, denn genau das
/// stand vorher in jeder einzelnen Datei.
///
/// Die drei Ernährungsmethoden stehen hier, **bevor** `HealthReading` sie
/// trägt (Plan `2026-11-03-ernaehrung.md`, Task 5). Bis dahin meldet der
/// Analyzer an ihnen `override_on_non_overriding_member` — eine Warnung,
/// kein Fehler; die Datei kompiliert und alle Attrappen laufen. Sobald das
/// Protokoll sie hat, verschwindet die Warnung von selbst.
class HealthReadingAttrappe implements HealthReading {
  const HealthReadingAttrappe();

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2020);

  @override
  Future<void> requestAuthorization() async {}

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => const [];

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async => const [];

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async =>
      const [];

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async => const [];

  @override
  Future<List<QuantitySample>> hourlySteps(
    DateTime from,
    DateTime through,
  ) async => const [];

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) async => const [];

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async =>
      WriteAuthorization.denied;

  @override
  Future<String> writeWeight({required double kg, required DateTime at}) async =>
      throw UnimplementedError('kein Schreiben in diesem Test');

  @override
  Future<void> deleteWeight(String id) async =>
      throw UnimplementedError('kein Löschen in diesem Test');

  @override
  Future<List<WeightSample>> weightSamples(
    DateTime from,
    DateTime through,
  ) async => const [];

  // ── Ernährung nach Health schreiben (#283) ────────────────────────────

  @override
  Future<WriteAuthorization> requestNutritionWriteAuthorization() async =>
      throw UnimplementedError('keine Ernährungs-Freigabe in diesem Test');

  @override
  Future<String> writeMeal({
    required Naehrwerte werte,
    required String name,
    required DateTime at,
  }) async => throw UnimplementedError('kein Schreiben in diesem Test');

  @override
  Future<void> deleteMeal(String id) async =>
      throw UnimplementedError('kein Löschen in diesem Test');
}
