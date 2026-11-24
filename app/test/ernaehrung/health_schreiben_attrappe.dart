// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';

/// Eine steuerbare Health-Quelle für die Ernährungs-Kopie (#283) —
/// **Testhilfe, kein Test.** Benutzt von `health_schreiben_test.dart` und
/// `health_streichen_test.dart`.
///
/// Implementiert [HealthReading] mit den drei Methoden, die der Plan
/// (Task 5, „Interfaces") dort vorgibt. Bis die Implementierung sie in
/// `lib/health/health_reading.dart` einträgt, sind sie hier zusätzliche
/// Methoden (Warnung `override_on_non_overriding_member`, kein Fehler);
/// rot sind bis dahin die Fälle, die sie über das Protokoll aufrufen.
///
/// Bewusst `implements` und nicht `extends HealthReadingAttrappe`
/// (`test/health/health_reading_attrappe.dart`, #320): Diese Attrappe
/// beantwortet die Ernährungsmethoden selbst und soll für den Rest nie
/// werfen — auch dann nicht, wenn die Basis ihre Stümpfe ändert.
///
/// Alle Kennungen sind erfunden.
class SchreibAttrappe implements HealthReading {
  SchreibAttrappe({this.freigabe = WriteAuthorization.granted});

  /// Was `requestNutritionWriteAuthorization` antwortet. Darf zwischen zwei
  /// Schritten eines Falls umgestellt werden — so wird die Freigabe
  /// „später erteilt".
  WriteAuthorization freigabe;

  /// Wirft `requestNutritionWriteAuthorization` statt zu antworten
  /// (z. B. HealthKit auf dem Gerät nicht verfügbar).
  Object? anfrageFehler;

  /// Wirft `writeMeal` für eine Mahlzeit dieses Namens. Nicht genannte
  /// Namen werden geschrieben.
  final Map<String, Object> schreibFehlerFuer = {};

  /// Wirft `deleteMeal` — etwa, weil die Probe in der Health-App schon
  /// gelöscht wurde.
  Object? loeschFehler;

  /// Wie oft die Freigabe angefragt wurde.
  int anfragen = 0;

  /// Was erfolgreich geschrieben wurde, in Reihenfolge, mit der vergebenen
  /// Kennung.
  final List<({String id, Naehrwerte werte, String name, DateTime at})>
  geschrieben = [];

  /// Jeder Schreibversuch, auch die gescheiterten.
  final List<String> schreibVersuche = [];

  /// Jeder Löschversuch, auch die gescheiterten.
  final List<String> loeschVersuche = [];

  int _naechste = 1;

  /// Kennungen in UUID-Form, fortlaufend und erkennbar erfunden.
  String _neueKennung() {
    final nummer = (_naechste++).toString().padLeft(12, '0');
    return 'C0FFEE00-0000-0000-0000-$nummer';
  }

  // ── Die drei neuen Methoden (Plan, Task 5) ────────────────────────────

  @override
  Future<WriteAuthorization> requestNutritionWriteAuthorization() async {
    anfragen++;
    final fehler = anfrageFehler;
    if (fehler != null) throw fehler;
    return freigabe;
  }

  @override
  Future<String> writeMeal({
    required Naehrwerte werte,
    required String name,
    required DateTime at,
  }) async {
    schreibVersuche.add(name);
    final fehler = schreibFehlerFuer[name];
    if (fehler != null) throw fehler;
    final id = _neueKennung();
    geschrieben.add((id: id, werte: werte, name: name, at: at));
    return id;
  }

  @override
  Future<void> deleteMeal(String id) async {
    loeschVersuche.add(id);
    final fehler = loeschFehler;
    if (fehler != null) throw fehler;
  }

  // ── Der Rest des Protokolls: leer, nie werfend ────────────────────────

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2020);

  @override
  Future<void> requestAuthorization() async {}

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) async =>
      const [];

  @override
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through) async =>
      const [];

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
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) async =>
      const [];

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) async => const [];

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async =>
      WriteAuthorization.denied;

  @override
  Future<String> writeWeight({required double kg, required DateTime at}) =>
      throw UnimplementedError('Gewicht gehört nicht in diese Tests');

  @override
  Future<void> deleteWeight(String id) =>
      throw UnimplementedError('Gewicht gehört nicht in diese Tests');

  @override
  Future<List<WeightSample>> weightSamples(DateTime from, DateTime through) async =>
      const [];
}
