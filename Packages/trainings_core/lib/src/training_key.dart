// Der Schlüssel eines Trainings, damit die Erfassung ein Training starten
// kann, das keinen Enum-Fall hat (#532, Spec 3.1).

import 'exercise.dart';

/// Wie ein Training adressiert wird: über seine Kennung.
///
/// [Workout] implementiert die Schnittstelle (die Kennung ist der gespeicherte
/// `code`), eigene Trainings tragen ihre UUID in [CustomTrainingKey]. So bleibt
/// jeder bestehende Aufruf mit einem `Workout` gültig, und eine Familie von
/// Providern kann über beide Arten dieselbe Schlüsselform führen.
///
/// **Für eine Kennung gibt es genau einen Schlüssel.** [fromId] liefert den
/// Enum-Fall, wo es einen gibt, sonst einen [CustomTrainingKey] — nie beides.
/// Wer einen [CustomTrainingKey] von Hand mit dem Code eines Enum-Falls baut,
/// umgeht das: Die beiden sind dann **nicht gleich**, und die Familie hielte
/// zwei Provider für ein Training. Erzwungen wird das hier nicht; der Weg
/// über [fromId] ist der richtige.
abstract interface class TrainingKey {
  /// Die Kennung: bei einem [Workout] sein `code`, sonst die UUID des
  /// Trainings.
  String get id;

  /// Der Schlüssel zu einer Kennung: [Workout.fromCode], wo es einen Fall
  /// gibt, sonst [CustomTrainingKey].
  ///
  /// Unterscheidet Groß- und Kleinschreibung wie [Workout.fromCode]: `'a'`
  /// ist der Name des Dart-Falls, nicht der gespeicherte Code.
  static TrainingKey fromId(String id) =>
      Workout.fromCode(id) ?? CustomTrainingKey(id);
}

/// Der Schlüssel eines Trainings ohne Enum-Fall.
///
/// Werttyp mit [==] und [hashCode] über die Kennung — genau so benutzt
/// Riverpod den Schlüssel einer Familie.
final class CustomTrainingKey implements TrainingKey {
  const CustomTrainingKey(this.id);

  @override
  final String id;

  @override
  bool operator ==(Object other) =>
      other is CustomTrainingKey && other.id == id;

  @override
  int get hashCode => Object.hash(CustomTrainingKey, id);

  @override
  String toString() => 'CustomTrainingKey($id)';
}
