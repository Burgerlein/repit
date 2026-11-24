// Der Stand des Erfassen-Schirms (#78): der Entwurf und alles, was um ihn
// herum wahr ist — wird er noch gelesen, wird er gerade geschrieben, wann
// wurde zuletzt gespeichert, läuft schon ein anderes Training, was ist
// schiefgegangen.
//
// **Kein `Messwert<T>`** (`CLAUDE.md`): Der Entwurf sind Tims eigene Daten,
// es gibt keinen Lauf, der leer ausgehen kann. Aber auch hier darf „wird
// gerade gelesen" nicht wie „nichts eingetragen" aussehen (Spec 9.3,
// Fehler `01`) — dafür trägt der Stand [GymLogStand.laedt], nach dem
// Muster von `GymTag.laedt`.
import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

import 'gym_log_entwurf.dart';

/// Was dem Nutzer **gesagt** werden muss. Genau eins zugleich — das jüngste.
///
/// Der Wortlaut steht in `gym_log_texte.dart` ([gymHinweisText]); hier nur
/// die Fälle, damit der `switch` vollständig sein muss.
enum GymLogHinweis {
  /// Der gespeicherte Zwischenstand ließ sich nicht lesen und wurde
  /// verworfen (Spec 10.2: „verworfen, und der Schirm sagt es").
  entwurfUnlesbar,

  /// Die Datenbank ließ sich beim Öffnen nicht lesen. Der Zwischenstand
  /// kann noch da sein — **deshalb wird nichts geschrieben**, bis der
  /// Schirm neu geöffnet wird: Ein Schreiben bei unbekanntem Stand
  /// überschriebe ihn.
  entwurfNichtGelesen,

  /// Der Zwischenstand ließ sich nicht schreiben. Der Haken fehlt dann zu
  /// Recht.
  zwischenspeichernFehlgeschlagen,

  /// Das Training ließ sich nicht ablegen. **Der Zwischenstand bleibt
  /// stehen** (Tim, 10.11.2026) — die alte App löscht ihn trotzdem, das
  /// wird nicht portiert.
  ablegenFehlgeschlagen,

  /// Der Zwischenstand ließ sich nicht löschen und taucht beim nächsten
  /// Öffnen wieder auf.
  verwerfenFehlgeschlagen,
}

/// Wie „Training abschließen" ausging.
enum GymAbschluss {
  /// Abgelegt, der Zwischenstand ist weg. Der Schirm darf schließen.
  abgelegt,

  /// Kein einziger Satz zählt. **Nichts abgelegt, nichts gelöscht** — der
  /// Zwischenstand steht noch da und lässt sich vervollständigen
  /// (Swift: `complete()` gibt `false` zurück). Der Knopf ist in diesem
  /// Fall ohnehin abgeblendet; das hier ist die zweite Sicherung.
  nichtsZuAblegen,

  /// Das Ablegen ist gescheitert; [GymLogStand.hinweis] sagt es und der
  /// Zwischenstand bleibt.
  fehlgeschlagen,
}

/// Ein **anderes** Training, das schon läuft — der Anlass der Rückfrage
/// (Tim, 10.11.2026: „Ein Entwurf, nicht sieben").
///
/// Die Ablage kennt genau einen Entwurf. Wer ein zweites Training anfängt,
/// bekommt eine Rückfrage; schreiben tut der Notifier erst, nachdem sie
/// beantwortet ist (`GymLogNotifier.ersetzeLaufendes`).
@immutable
class GymLaufendes {
  const GymLaufendes({
    this.workout,
    this.trainingId,
    this.name,
    required this.saetze,
  }) : assert(
         workout != null || trainingId != null,
         'Ein laufendes Training hat einen Enum-Fall oder eine Kennung',
       );

  /// Das Workout, dessen Zwischenstand in der Ablage liegt — `null` bei einem
  /// Training ohne Enum-Fall (Spec 27 Nr. 4).
  final Workout? workout;

  /// Die Kennung eines laufenden Trainings **ohne** Enum-Fall.
  final String? trainingId;

  /// Der Name des laufenden Trainings ohne Enum-Fall, wie er in der Ablage
  /// steht; `null`, wenn es ihn nicht (mehr) gibt.
  final String? name;

  /// Wie viele Sätze darin zählen — das, was beim Ersetzen verloren geht.
  final int saetze;

  @override
  bool operator ==(Object other) =>
      other is GymLaufendes &&
      other.workout == workout &&
      other.trainingId == trainingId &&
      other.name == name &&
      other.saetze == saetze;

  @override
  int get hashCode => Object.hash(workout, trainingId, name, saetze);

  @override
  String toString() =>
      'GymLaufendes(${workout?.code ?? trainingId}, $saetze Sätze)';
}

/// Alles, was der Erfassen-Schirm und das Vollbild zeigen.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymLogStand {
  const GymLogStand({
    required this.entwurf,
    this.training,
    this.laedt = false,
    this.speichert = false,
    this.gespeichertAm,
    this.laufendes,
    this.hinweis,
  });

  /// Der Stand beim Öffnen, bevor die Ablage geantwortet hat.
  const GymLogStand.laedt(this.entwurf, {this.training})
    : laedt = true,
      speichert = false,
      gespeichertAm = null,
      laufendes = null,
      hinweis = null;

  /// Das Training. **Solange [laedt] gesetzt ist, ist das nur die
  /// Vorbelegung** — leere Zeilen in der Geometrie des Workouts, damit der
  /// Platzhalter dieselbe Form hat wie der Inhalt. Sie sind nicht
  /// „nichts eingetragen"; nachgesehen wurde noch nicht.
  final GymLogEntwurf entwurf;

  /// Die Definition des Trainings, nach der dieser Entwurf gebaut ist: Name,
  /// Übungen in ihrer Reihenfolge, Sätze und Wiederholungsbereich **des
  /// Trainings** (Spec 15.2) — daraus rechnen Titel, Vorschlag und Dauer.
  ///
  /// Bei einem Enum-Fall von Anfang an da (die Zeile oder, wo es keine gibt,
  /// `WorkoutTemplates.fromEnum`); bei einem Training ohne Enum-Fall `null`,
  /// bis die Ablage geantwortet hat — **und danach, wenn es das Training
  /// nicht (mehr) gibt**.
  final WorkoutDefinition? training;

  /// `true`, bis die Ablage geantwortet hat (Spec 9.3).
  ///
  /// Solange es gesetzt ist, steht auf dem Schirm **weder** „0 / n Sätze"
  /// **noch** „Erstes Mal — …" **noch** „–" als Platzhalter, sondern die
  /// graue Form in derselben Geometrie. **Und Eingaben werden nicht
  /// angenommen:** Sie würden vom Eintreffen des gespeicherten Zwischenstands
  /// überschrieben; der Schirm darf in dieser Zeit keine Felder anbieten.
  final bool laedt;

  /// `true` zwischen einer Eingabe und dem Ende des Schreibens — der kleine
  /// Ladeanzeiger neben dem Haken (Spec 3.1: dieselbe Stelle, dieselbe
  /// Größe).
  final bool speichert;

  /// Wann zuletzt zwischengespeichert wurde, `null` wenn noch nie oder wenn
  /// es nichts zu speichern gibt. Der Haken steht, wenn es gesetzt ist.
  final DateTime? gespeichertAm;

  /// Läuft ein anderes Training? Dann schreibt der Notifier nichts, bis die
  /// Rückfrage beantwortet ist.
  final GymLaufendes? laufendes;

  /// Was dem Nutzer gesagt werden muss, `null` wenn nichts.
  final GymLogHinweis? hinweis;

  /// Ob der Notifier schreiben darf. Nicht, solange gelesen wird, nicht
  /// über ein fremdes Training und nicht über einen ungelesenen Stand.
  bool get darfSchreiben =>
      !laedt &&
      laufendes == null &&
      hinweis != GymLogHinweis.entwurfNichtGelesen;

  GymLogStand copyWith({
    GymLogEntwurf? entwurf,
    Object? training = _unveraendert,
    bool? laedt,
    bool? speichert,
    Object? gespeichertAm = _unveraendert,
    Object? laufendes = _unveraendert,
    Object? hinweis = _unveraendert,
  }) => GymLogStand(
    entwurf: entwurf ?? this.entwurf,
    training: identical(training, _unveraendert)
        ? this.training
        : training as WorkoutDefinition?,
    laedt: laedt ?? this.laedt,
    speichert: speichert ?? this.speichert,
    gespeichertAm: identical(gespeichertAm, _unveraendert)
        ? this.gespeichertAm
        : gespeichertAm as DateTime?,
    laufendes: identical(laufendes, _unveraendert)
        ? this.laufendes
        : laufendes as GymLaufendes?,
    hinweis: identical(hinweis, _unveraendert)
        ? this.hinweis
        : hinweis as GymLogHinweis?,
  );

  @override
  bool operator ==(Object other) =>
      other is GymLogStand &&
      other.entwurf == entwurf &&
      other.training == training &&
      other.laedt == laedt &&
      other.speichert == speichert &&
      other.gespeichertAm == gespeichertAm &&
      other.laufendes == laufendes &&
      other.hinweis == hinweis;

  @override
  int get hashCode => Object.hash(
    entwurf,
    training,
    laedt,
    speichert,
    gespeichertAm,
    laufendes,
    hinweis,
  );

  @override
  String toString() =>
      'GymLogStand($entwurf, laedt: $laedt, speichert: $speichert, '
      'gespeichertAm: $gespeichertAm, laufendes: $laufendes, '
      'hinweis: $hinweis)';
}

/// Unterscheidet „nicht angegeben" von „auf null setzen" in
/// [GymLogStand.copyWith].
const Object _unveraendert = Object();
