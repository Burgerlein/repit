import 'package:flutter/services.dart';
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'health_reading.dart';
import 'health_types.dart';

/// Platform-Channel zu HealthKit (iOS) — Dart-Hälfte des Adapters.
/// Kanalname identisch zur Swift-Seite, `app/ios/Runner/HealthChannel.swift`.
///
/// Wandelt die rohen `Map`s vom Standard-Codec über die `ausMap`-Konstruktoren
/// der einzelnen Typen in Dart-Typen um. Fehlende Felder bleiben `null`,
/// siehe dort.
///
/// **Task 7** hat hier nur `dailyMetrics` verdrahtet (Durchstich). **Task 12**
/// schließt die übrigen sechs Methoden des Protokolls ab.
class HealthChannel implements HealthReading, BodyCharacteristicsReading {
  HealthChannel({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('de.rosenbach.repit/health');

  final MethodChannel _channel;

  /// Siehe `HealthReading.earliestPermittedDate`: zählt bewusst nicht zu den
  /// „sieben Methoden über den Kanal" aus `task-12-brief.md` — eine
  /// Eigenschaft, keine asynchrone Abfrage. `HKHealthStore.
  /// earliestPermittedSampleDate()` braucht auf der echten Quelle ohnehin
  /// keinen HealthKit-Zugriff, der eine Fehlerbehandlung bräuchte (liefert in
  /// der Praxis denselben Wert wie diese Drei-Jahres-Faustregel, siehe
  /// `MockHealthReading.earliestPermittedDate` und die alte
  /// `EmptyHealthReading.swift`-Vorlage, die exakt dieselbe Regel verwendet).
  @override
  DateTime get earliestPermittedDate =>
      DateTime.now().subtract(const Duration(days: 365 * 3));

  @override
  Future<void> requestAuthorization() async {
    await _channel.invokeMethod<void>('requestAuthorization');
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'dailyMetrics',
      _zeitraumArgs(from, through),
    );
    return _liste(rohdaten, DailyMetrics.ausMap);
  }

  @override
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'sleepSessions',
      _zeitraumArgs(from, through),
    );
    return _liste(rohdaten, SleepNight.ausMap);
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'workouts',
      _zeitraumArgs(from, through),
    );
    return _liste(rohdaten, WorkoutSample.ausMap);
  }

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'quantitySamples',
      {'kind': kind.name, ..._zeitraumArgs(from, through)},
    );
    return _liste(rohdaten, QuantitySample.ausMap);
  }

  @override
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'hourlySteps',
      _zeitraumArgs(from, through),
    );
    return _liste(rohdaten, QuantitySample.ausMap);
  }

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'nutritionEntries',
      {'day': day.millisecondsSinceEpoch},
    );
    return _liste(rohdaten, NutritionEntry.ausMap);
  }

  // ── Gewicht von Hand eintragen (#270) ────────────────────────────────

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async {
    final roh = await _channel.invokeMethod<String>(
      'requestWeightWriteAuthorization',
    );
    // Kein `?? denied`: Ein unbekannter Name ist ein Programmierfehler im
    // Kanal und keine Datenlage — `byName` wirft, und das ist richtig so.
    // Still auf `denied` zu fallen hieße, einen Kanalfehler als Aussage
    // Apples auszugeben.
    return WriteAuthorization.values.byName(roh!);
  }

  @override
  Future<String> writeWeight({
    required double kg,
    required DateTime at,
  }) async {
    final id = await _channel.invokeMethod<String>('writeWeight', {
      'kg': kg,
      'at': at.millisecondsSinceEpoch,
    });
    return id!;
  }

  @override
  Future<void> deleteWeight(String id) async {
    await _channel.invokeMethod<void>('deleteWeight', {'id': id});
  }

  @override
  Future<List<WeightSample>> weightSamples(
    DateTime from,
    DateTime through,
  ) async {
    final rohdaten = await _channel.invokeMethod<List<Object?>>(
      'weightSamples',
      _zeitraumArgs(from, through),
    );
    return _liste(rohdaten, WeightSample.ausMap);
  }

  // ── Ernährung nach Health schreiben (#283) ───────────────────────────

  @override
  Future<WriteAuthorization> requestNutritionWriteAuthorization() async {
    final roh = await _channel.invokeMethod<String>(
      'requestNutritionWriteAuthorization',
    );
    // Kein `?? denied` — derselbe Grund wie beim Gewicht.
    return WriteAuthorization.values.byName(roh!);
  }

  @override
  Future<String> writeMeal({
    required Naehrwerte werte,
    required String name,
    required DateTime at,
  }) async {
    try {
      final id = await _channel.invokeMethod<String>('writeMeal', {
        'name': name,
        'at': at.millisecondsSinceEpoch,
        ...naehrwerteArgs(werte),
      });
      return id!;
    } on PlatformException catch (fehler) {
      // Nur dieser eine Code ist endgültig. Alles andere bleibt, was es
      // ist — sonst setzte ein gesperrtes Gerät den Eintrag für immer auf
      // `nicht_moeglich`.
      if (fehler.code == 'write_rejected') {
        throw HealthWriteRejected(fehler.message);
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _channel.invokeMethod<void>('deleteMeal', {'id': id});
  }

  /// Körpergröße und Geburtsjahr (#306). Ein Merkmal hat kein Zeitfenster,
  /// also hat dieser Aufruf keine Argumente.
  ///
  /// **Eine leere Antwort ist eine gültige Antwort.** Liefert die
  /// Swift-Seite gar nichts, sind beide Felder `null` — „nicht hinterlegt"
  /// und „Lesen verweigert" sehen gleich aus, und beides heißt „kein Wert".
  @override
  Future<BodyCharacteristics> bodyCharacteristics() async {
    final rohdaten = await _channel.invokeMapMethod<Object?, Object?>(
      'bodyCharacteristics',
    );
    return BodyCharacteristics.ausMap(rohdaten ?? const {});
  }

  Map<String, Object> _zeitraumArgs(DateTime from, DateTime through) => {
    'from': from.millisecondsSinceEpoch,
    'through': through.millisecondsSinceEpoch,
  };

  List<T> _liste<T>(
    List<Object?>? rohdaten,
    T Function(Map<Object?, Object?>) ausMap,
  ) {
    return (rohdaten ?? const <Object?>[])
        .map((eintrag) => ausMap(eintrag! as Map<Object?, Object?>))
        .toList();
  }
}

/// Die acht Nährwertschlüssel des Kanals, **nur die vorhandenen** — ein
/// fehlender Wert fehlt in der Map, er steht weder als `0` noch als `null`
/// drin. Buchstabengleich zu `HealthNutrition.fields` auf der Swift-Seite.
/// `Naehrwerte.extra` geht nicht mit.
Map<String, double> naehrwerteArgs(Naehrwerte werte) => {
  'kcal': ?werte.kcal,
  'proteinG': ?werte.eiweissG,
  'carbsG': ?werte.kohlenhydrateG,
  'fatG': ?werte.fettG,
  'saturatedFatG': ?werte.gesaettigtG,
  'sugarG': ?werte.zuckerG,
  'fiberG': ?werte.ballaststoffeG,
  'waterMl': ?werte.wasserMl,
};

