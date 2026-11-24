// Die beiden Trägertypen einer Gym-Sitzung, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Import/DashboardImport.swift`
// (Zeilen 14–58, #91). Der Dashboard-Parser selbst bleibt bei #59 — hier
// kommen nur die Typen mit, weil `GymSessionBuilder` und `GymSessionMerge`
// sie als Ein- und Ausgabe führen und sie eigene Rechnungen tragen.

import 'exercise.dart';
import 'progression.dart';
import 'warm_up.dart';

/// Die Sätze einer Übung innerhalb einer Sitzung, bereits auf die App-ID
/// umgeschlüsselt.
///
/// Werttyp mit [==] und [hashCode]; die Satzliste wird **inhaltlich** und in
/// ihrer Reihenfolge verglichen (`CLAUDE.md`, Fehler `03`). Erst 8
/// Wiederholungen und dann 6 ist ein anderer Verlauf als umgekehrt.
final class ImportedExercise {
  const ImportedExercise({required this.exerciseId, required this.sets});

  /// Die [Exercise.id] aus dem Katalog.
  final String exerciseId;

  /// Die Sätze in der Reihenfolge, in der sie gemacht wurden.
  final List<CompletedSet> sets;

  @override
  bool operator ==(Object other) =>
      other is ImportedExercise &&
      other.exerciseId == exerciseId &&
      _gleicheSaetze(other.sets, sets);

  @override
  int get hashCode => Object.hash(exerciseId, Object.hashAll(sets));

  @override
  String toString() => 'ImportedExercise($exerciseId, ${sets.length} Sätze)';
}

/// Ein abgeschlossenes Gym-Training.
///
/// Der Name bleibt `ImportedSession`, obwohl auch die selbst erfassten
/// Trainings diese Form haben — so heißt er in Swift, und zwei Namen für
/// dieselbe Sache kosten mehr als ein ungenauer.
final class ImportedSession {
  const ImportedSession({
    required this.id,
    required this.date,
    required this.workout,
    required this.minutes,
    required this.note,
    required this.exercises,
    this.warmUp,
    this.trainingId,
    this.trainingName,
  });

  final String id;

  /// Wann das Training stattfand — **und das heißt je nach Herkunft etwas
  /// anderes.**
  ///
  /// - Beim **Dashboard-Import** der Berliner Tagesbeginn: Die Exportdatei
  ///   kennt nur ein Tagesdatum, eine Uhrzeit gäbe es dort nicht zu holen.
  /// - Beim **eigenen Training** der Zeitpunkt des Abschlusses, samt
  ///   Uhrzeit. `GymSessionBuilder` reicht ihn ausdrücklich durch, damit
  ///   zwei Trainings an einem Tag sich unterscheiden lassen.
  ///
  /// Der Swift-Kommentar an `DashboardImport.swift:28` sagt nur die erste
  /// Hälfte; das ist für `GymSessionBuilder` schlicht falsch. **Erzwungen
  /// wird keine der beiden Lesarten** — `date` nimmt, was hereingereicht
  /// wird. Wer hier einen Tagesvergleich braucht, rechnet ihn über
  /// `BerlinCalendar`, statt sich auf den Tagesbeginn zu verlassen.
  ///
  /// Wie überall im Paket ein UTC-Zeitpunkt, der eine Berliner Wanduhrzeit
  /// bezeichnet.
  final DateTime date;

  /// `null`, wenn kein oder ein unbekanntes Workout geführt wird. Das
  /// erzeugt der Dashboard-Import; einem Workout zuzuschlagen hieße raten.
  /// Es entsteht auch bei einem eigenen Training, das keinen Enum-Fall hat —
  /// dann steht seine Kennung in [trainingId].
  final Workout? workout;

  /// Die Kennung des Trainings, **nur für Trainings ohne Enum-Fall**
  /// (Spec 4.6). Bei jeder Sitzung mit einem [workout] bleibt sie `null` —
  /// so ist jede bestehende Sitzung gleich sich selbst.
  ///
  /// **Erzwungen wird das hier nicht:** Der Kern nimmt hinein, was
  /// hereingereicht wird, und führt es in [==] und [hashCode]. Wer sie setzt,
  /// ist Sache des Lesers der Ablage und des `GymSessionBuilder`-Aufrufers.
  final String? trainingId;

  /// Der Name des Trainings **zu dem Zeitpunkt, als die Sitzung entstand**,
  /// `null` bei Sitzungen, die ihn nie bekamen (alle aus der Übernahme).
  ///
  /// Er friert ein: Umbenennen und Löschen des Trainings schreiben ihn nicht
  /// um. Wie daraus ein Titel wird, regelt `WorkoutNaming.title`.
  final String? trainingName;

  /// Dauer in Minuten, `null` wenn keine eingetragen wurde. Nicht `0` —
  /// „nicht erfasst" ist nicht „null Minuten".
  final int? minutes;

  /// Freitext, `null` wenn keiner da ist. Eine leere Zeichenkette gibt es
  /// nicht: Sie zeichnete eine leere Notizzeile unter das Training.
  final String? note;

  /// Die Übungen in ihrer festgelegten Reihenfolge, siehe
  /// `GymSessionOrder.ordered`. Die Reihenfolge gehört zur Sitzung und geht
  /// deshalb in [==] ein.
  final List<ImportedExercise> exercises;

  /// Das Aufwärmen am Trainingsanfang (#40), `null` wenn nichts eingetragen
  /// wurde.
  ///
  /// **Drei Zustände, nicht zwei:** `null` ist „nichts eingetragen" — so
  /// kommt alles herein, was die Übernahme aus der alten App (#59) bringt —,
  /// [WarmUpSkipped] ist „übersprungen" und damit eine gegebene Antwort.
  /// Ein erfundenes „übersprungen" behauptete eine Antwort, die niemand
  /// gegeben hat.
  ///
  /// Trägt zu [setCount] und [volumeKg] **nichts** bei: Aufwärmen ist kein
  /// Satz, und zehn Minuten Rad sind keine Last. Seine Dauer steht neben
  /// [minutes], nicht darin.
  final WarmUp? warmUp;

  /// Wie viele Sätze insgesamt gemacht wurden.
  ///
  /// Zählt Sätze, nicht Last: Ein Satz am eigenen Körpergewicht und ein
  /// unterstützter Satz zählen mit, obwohl sie zu [volumeKg] nichts
  /// beitragen. „Hat stattgefunden" ist eine andere Frage als „wie schwer".
  int get setCount =>
      exercises.fold<int>(0, (summe, exercise) => summe + exercise.sets.length);

  /// Tonnage nach der Rechnung des Dashboards: Summe aus
  /// `max(0, kg) × Wiederholungen`.
  ///
  /// **Unterstützte Sätze tragen nichts bei** — negatives Gewicht ist Hilfe
  /// der Maschine, keine Last. Das ist kein vergessener Sonderfall, sondern
  /// eine bewusst vorsichtige Zahl: Was dort tatsächlich bewegt wurde, wäre
  /// Körpergewicht minus Hilfe, und das Körpergewicht steht hier nicht zur
  /// Verfügung. Das Dashboard rechnet so nicht, und zwei verschiedene Zahlen
  /// für dieselbe Sitzung wären schlimmer als eine vorsichtige.
  ///
  /// Als allgemeine Schätzung zu verstehen, keine Messung.
  double get volumeKg => exercises.fold<double>(
    0,
    (summe, exercise) =>
        summe +
        exercise.sets.fold<double>(
          0,
          (teil, satz) =>
              teil + (satz.weight > 0 ? satz.weight : 0) * satz.reps,
        ),
  );

  @override
  bool operator ==(Object other) =>
      other is ImportedSession &&
      other.id == id &&
      other.date == date &&
      other.workout == workout &&
      other.minutes == minutes &&
      other.note == note &&
      other.warmUp == warmUp &&
      other.trainingId == trainingId &&
      other.trainingName == trainingName &&
      _gleicheUebungen(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
    id,
    date,
    workout,
    minutes,
    note,
    Object.hashAll(exercises),
    warmUp,
    trainingId,
    trainingName,
  );

  @override
  String toString() =>
      'ImportedSession($id, ${workout?.code ?? '?'}, ${exercises.length} Übungen)';
}

/// Inhaltlicher Vergleich zweier Satzlisten — die Reihenfolge zählt.
///
/// Von Hand geschrieben statt über `package:collection`: Der Kern importiert
/// nur `dart:core` und `dart:math` (`test/import_boundary_test.dart`).
bool _gleicheSaetze(List<CompletedSet> a, List<CompletedSet> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Inhaltlicher Vergleich zweier Übungslisten — die Reihenfolge zählt.
bool _gleicheUebungen(List<ImportedExercise> a, List<ImportedExercise> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
