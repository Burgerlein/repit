// Wie ein Training heißt: Kurzname und die dreistufige Auflösung des Namens
// einer Sitzung (#532, Spec 4.6 und 5.8).

import 'exercise.dart';
import 'gym_session.dart';

/// Benennung von Trainings und Sitzungen.
///
/// Keine Nutzertexte im Sinne von Beschriftungen: Die Namen sind Fachinhalt
/// (die der Katalog-Workouts) oder vom Nutzer getippt. Was die Ansicht
/// schreibt, wenn es keinen Namen gibt („Training"), steht nicht hier.
abstract final class WorkoutNaming {
  /// Das Trennzeichen zwischen Kurzname und Beschreibung: ein Gedankenstrich
  /// (U+2014) **mit** Leerzeichen davor und danach.
  static const String _separator = ' — ';

  /// Der Kurzname: der Teil vor dem ersten `' — '`, sonst der ganze Name.
  ///
  /// `Gym A — Oberkörper Push + Arme` ergibt `Gym A`, das ist [Workout.label];
  /// Verlauf und Wochenleiste zeigen für die Katalog-Workouts damit dasselbe
  /// wie vor den eigenen Trainings. `Kurzhantel zuhause` bleibt ganz.
  ///
  /// Ein Bindestrich, ein Gedankenstrich ohne Leerzeichen und ein
  /// Gedankenstrich mit nur einem Leerzeichen trennen nicht — wer sie tippt,
  /// meint den ganzen Namen.
  static String shortName(String name) {
    final index = name.indexOf(_separator);
    return index < 0 ? name : name.substring(0, index);
  }

  /// Der Name eines Katalog-Workouts, wie ihn die Schirme setzen:
  /// `'${label} — ${title}'`.
  ///
  /// Die eine Stelle, an der das zusammengesetzt wird — Stufe 2 von [title]
  /// und die Startbefüllung der Templates nehmen beide diese Zeichenkette,
  /// damit sie nicht auseinanderlaufen.
  static String workoutName(Workout workout) =>
      '${workout.label}$_separator${workout.title}';

  /// Der Name, unter dem die Sitzung geführt wird, in drei Stufen:
  ///
  /// 1. [ImportedSession.trainingName], wenn er da ist — der eingefrorene
  ///    Name zum Zeitpunkt der Sitzung. **Er geht auch einem `workout` vor**:
  ///    Ein später umbenanntes Template verändert keine Karte im Verlauf.
  /// 2. Sonst, wenn [ImportedSession.workout] gesetzt ist: [workoutName].
  /// 3. Sonst `null`; die Ansicht schreibt „Training".
  ///
  /// Eine Kennung allein ist kein Name. **Ein leerer `trainingName` zählt als
  /// nicht gesetzt** und fällt auf die nächste Stufe — eine Zeile ohne
  /// lesbaren Titel wäre die schlechtere Antwort. Geschrieben wird er
  /// ohnehin nie leer.
  static String? title(ImportedSession session) {
    final name = session.trainingName;
    if (name != null && name.isNotEmpty) return name;
    final workout = session.workout;
    return workout == null ? null : workoutName(workout);
  }

  /// Der Kurzname der Sitzung: [shortName] des Titels, bei Stufe 2 das
  /// [Workout.label]. `null`, wo [title] `null` ist.
  static String? shortTitle(ImportedSession session) {
    final titel = title(session);
    return titel == null ? null : shortName(titel);
  }
}
