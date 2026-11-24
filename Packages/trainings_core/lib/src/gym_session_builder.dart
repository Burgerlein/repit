// Aus eingetippten Feldern wird eine Sitzung, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymSessionBuilder.swift`
// (#91).

import 'exercise.dart';
import 'exercise_library.dart';
import 'gym_session.dart';
import 'gym_session_order.dart';
import 'progression.dart';
import 'warm_up.dart';

/// Ein eingetippter Satz, so wie er im Formular steht — noch Text, noch nicht
/// geprüft.
///
/// Die Umwandlung in Zahlen gehört in den Kern und nicht in die Ansicht: Sie
/// entscheidet, was ein gültiger Satz ist, und das ist Fachlogik.
///
/// [==] vergleicht den **Text**, nicht die Zahl: `'42,5'` und `'42.5'` sind
/// dasselbe Gewicht, aber nicht dieselbe Eingabe. Was hier verglichen wird,
/// ist der Zustand des Formulars.
final class RawSet {
  const RawSet({required this.weight, required this.reps, this.recordedAt});

  final String weight;
  final String reps;

  /// Der Zeitpunkt der Eingabe, `null` wenn keiner erfasst wurde — siehe
  /// [CompletedSet.recordedAt].
  ///
  /// Er steht schon hier und nicht erst am fertigen Satz, damit er die
  /// 1,5-Sekunden-Ablage des Entwurfs übersteht: Die Sitzung entsteht erst
  /// beim Abschließen, der Zeitpunkt aber beim Eintippen (Spec 11.1).
  ///
  /// Er geht in [==] ein, weil er zum Zustand des Formulars gehört: Ein
  /// Satz, der geleert und neu gefüllt wird, ist ein neuer Satz — auch
  /// dann, wenn am Ende wieder derselbe Text dasteht.
  final DateTime? recordedAt;

  @override
  bool operator ==(Object other) =>
      other is RawSet &&
      other.weight == weight &&
      other.reps == reps &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(weight, reps, recordedAt);

  @override
  String toString() => recordedAt == null
      ? 'RawSet($weight, $reps)'
      : 'RawSet($weight, $reps, $recordedAt)';
}

abstract final class GymSessionBuilder {
  /// Wandelt eingetippte Sätze in eine Sitzung.
  ///
  /// Gibt `null` zurück, wenn keine einzige Übung einen brauchbaren Satz
  /// hat. Ein leeres Training abzulegen hieße, in „Letzte Trainings" eine
  /// Zeile ohne Inhalt zu führen — und im Verlauf einen Punkt bei null.
  ///
  /// [date] wird **samt Uhrzeit** durchgereicht: Zwei Trainings an einem Tag
  /// sollen sich unterscheiden lassen. Siehe [ImportedSession.date].
  ///
  /// [assist] schaltet je Übungs-ID auf Unterstützung um; der Schalter steht
  /// an der Übungszeile, nicht am Training.
  ///
  /// [warmUp] wird unverändert durchgereicht, auch `WarmUpSkipped` —
  /// „übersprungen" ist eine Antwort und darf nicht zu `null` einebnen.
  /// **Aufwärmen allein macht aus einer leeren Sitzung keine gültige:** Zehn
  /// Minuten Rad sind kein Training, und eine Sitzung ohne einen einzigen
  /// brauchbaren Satz bliebe eine Zeile ohne Inhalt in „Letzte Trainings".
  ///
  /// [workout] ist `null` für ein Training ohne Enum-Fall; dann kommt es über
  /// [trainingId] in die Sitzung. [trainingId] und [trainingName] werden
  /// **unverändert durchgereicht**, auch neben einem [workout] — der Name
  /// friert beim Abschließen ein (Spec 4.6). Wer [trainingId] neben einem
  /// Enum-Workout setzt, bekommt eine Sitzung, die der Lesepfad der Ablage
  /// so nie liefert; erzwungen wird das hier nicht.
  ///
  /// [trainingOrder] ist die Übungsreihenfolge des Trainings und gilt statt
  /// der des Katalogs für [workout] (`GymSessionOrder.ordered`). Ohne sie
  /// bleibt alles wie bisher.
  static ImportedSession? session({
    required String id,
    required DateTime date,
    required Workout? workout,
    int? minutes,
    String? note,
    required Map<String, List<RawSet>> entries,
    Map<String, bool> assist = const {},
    WarmUp? warmUp,
    String? trainingId,
    String? trainingName,
    List<String>? trainingOrder,
  }) {
    final byExerciseId = <String, List<CompletedSet>>{};
    for (final eintrag in entries.entries) {
      // Eine Übung, die die Bibliothek nicht kennt, wird übergangen statt
      // geraten. Sie hätte weder Muskeln noch Zielbereiche.
      if (!ExerciseLibrary.all.containsKey(eintrag.key)) continue;

      final assisted = assist[eintrag.key] ?? false;
      final sets = <CompletedSet>[
        for (final raw in eintrag.value)
          ?_completedSet(raw, assisted: assisted),
      ];
      if (sets.isNotEmpty) byExerciseId[eintrag.key] = sets;
    }
    if (byExerciseId.isEmpty) return null;

    return ImportedSession(
      id: id,
      date: date,
      workout: workout,
      minutes: minutes,
      // Eine leere Notiz wird nichts, keine leere Zeichenkette — sonst
      // zeichnet die Ansicht eine leere Notizzeile unter das Training.
      note: (note == null || note.isEmpty) ? null : note,
      exercises: [
        for (final exerciseId in GymSessionOrder.ordered(
          byExerciseId.keys,
          workout,
          trainingOrder: trainingOrder,
        ))
          ImportedExercise(
            exerciseId: exerciseId,
            sets: byExerciseId[exerciseId]!,
          ),
      ],
      warmUp: warmUp,
      trainingId: trainingId,
      trainingName: trainingName,
    );
  }

  /// Ein Satz zählt, wenn er Wiederholungen hat. Alles andere ist ein leeres
  /// Feld, das jemand übersprungen hat.
  ///
  /// **Das Gewicht wird strenger gelesen als in Swift** (Spec zu #91,
  /// Abweichung 7). `double.tryParse` liefert für `'Infinity'` und `'NaN'`
  /// tatsächlich `∞` bzw. `NaN`; beide werden hier über [double.isFinite]
  /// verworfen. Ein unendliches oder undefiniertes Gewicht vergiftet
  /// [ImportedSession.volumeKg] lautlos, und die Zahl auf der Karte sieht
  /// hinterher normal aus. `'0x10'` liest Swift als 16, Dart gar nicht —
  /// auch das bleibt abgelehnt. Aus einem Zahlen-Textfeld kommt keiner
  /// dieser Werte; wer sie tippt, hat sich vertippt.
  static CompletedSet? _completedSet(RawSet raw, {required bool assisted}) {
    final reps = int.tryParse(raw.reps.trim());
    if (reps == null || reps <= 0) return null;

    final weightText = raw.weight.trim();
    final double weight;
    if (weightText.isEmpty) {
      // Dips und Klimmzüge am eigenen Körpergewicht sind gültige Sätze.
      weight = 0;
    } else {
      // Komma und Punkt beide annehmen: Auf der Zehnertastatur liegt je nach
      // Region das eine oder das andere. Steht dagegen etwas Unlesbares da,
      // fällt der ganze Satz weg — es als null Kilo zu buchen hieße raten.
      final gelesen = double.tryParse(weightText.replaceAll(',', '.'));
      if (gelesen == null || !gelesen.isFinite) return null;
      weight = gelesen;
    }

    // Unterstützung wird negativ gespeichert. `-abs` statt `-`, damit ein
    // schon negativ eingetipptes Gewicht nicht zurück ins Positive kippt.
    // Der Zeitpunkt wird durchgereicht, nicht erfunden: weder „jetzt" noch
    // das Abschlussdatum. Was keinen hat, bekommt auch keinen vom Nachbarn
    // geliehen.
    return CompletedSet(
      weight: assisted ? -weight.abs() : weight,
      reps: reps,
      recordedAt: raw.recordedAt,
    );
  }
}
