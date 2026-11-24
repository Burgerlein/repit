// Die Sätze der Trainings-Übersicht und des Trainings-Details (#533 unter
// #531, Spec 7 und 8) — an **einer** Stelle, wie `gym_fokus_texte.dart`:
// Ein Schirm, der sich seine Sätze selbst zusammenbaut, läuft beim ersten
// Wortlautwechsel auseinander.
//
// **Alle Wortlaute sind Vorschläge der Spec**, die Entwürfe
// (`docs/screens/screens/gym-trainings.js`, `gym-training-detail.js`) sind die
// Vorlage. Die Tests prüfen Stichwörter und die Abwesenheit bestimmter
// Aussagen, nie einen ganzen Satz.
//
// **Der Vorlesetext nennt den Zustand, nicht das Zeichen** (`CLAUDE.md`):
// „keine Dauer", nicht „Strich". **Kein Satz verspricht, was kommt** — die
// Bedienelemente ohne Ziel tragen nur ihre Beschriftung (Plan, Lücke 7).
import 'package:trainings_core/trainings_core.dart';

import '../design/muskel_figur.dart';
import 'gym_trainings_provider.dart' show TrainingKachel;

// --- Übersicht -------------------------------------------------------------

const String gymTrainingsKicker = 'Gym';
const String gymTrainingsTitel = 'Trainings';
const String gymTrainingsGruppeTemplates = 'Templates';
const String gymTrainingsGruppeEigene = 'Eigene';
const String gymTrainingsChipAlle = 'Alle';
const String gymTrainingsAnlegen = 'Eigenes Training anlegen';

/// Der Satz, wenn **gelesen** wurde und es keine Eigenen gibt (ungefiltert).
const String gymTrainingsLeerEigene =
    'Noch keine eigenen Trainings. Lege eins an — oder öffne ein Template und '
    'tippe „Bearbeiten": Das legt eine Kopie hier ab, das Template bleibt '
    'unverändert.';

/// „Alle Templates gelöscht" — nur, wenn gelesen wurde und kein Filter steht.
const String gymTrainingsLeerTemplates =
    'Du hast alle Templates gelöscht. Sie kommen nicht von selbst wieder.';

const String gymTrainingsLeerGefiltertTemplates =
    'Kein Template trägt diesen Tag.';
const String gymTrainingsLeerGefiltertEigene =
    'Kein eigenes Training trägt diesen Tag.';

/// Wenn schon das **erste** Lesen gescheitert ist: ein Satz über das Lesen,
/// keiner über die Datenlage — „keine Trainings" wäre eine Behauptung, wo nur
/// nicht gelesen werden konnte (Fehler `01`).
const String gymTrainingsNichtLesbar =
    'Die Trainings lassen sich gerade nicht lesen.';

/// Der Name der Kachel. Ein Entwurf ohne Namen heißt „Ohne Namen" (Spec 7.3,
/// Vorschlag) — eine Kachel ohne Titel ließe sich nicht lesen.
String gymTrainingsKachelName(TrainingKachel kachel) =>
    kachel.name.trim().isEmpty ? 'Ohne Namen' : kachel.name;

/// Die Dauerzeile der Kachel.
///
/// - Entwurf: „Entwurf — noch nicht fertig" (Spec 7.3).
/// - Keine Dauer (ein Training ohne bekannte Übung): „–", **nie 0**.
/// - Sonst „ca. 70 min" — „ca." steht vor **jeder** Dauer, eingetragen oder
///   geschätzt (Spec 7.2, 12 Nr. 4).
String gymTrainingsDauer(TrainingKachel kachel) {
  if (kachel.isDraft) return 'Entwurf — noch nicht fertig';
  final minuten = kachel.minutes;
  return minuten == null ? '–' : 'ca. $minuten min';
}

/// „7 Übungen", „1 Übung", „keine Übung" — **keine Null**.
String gymTrainingsAnzahl(int anzahl) => switch (anzahl) {
  0 => 'keine Übung',
  1 => '1 Übung',
  _ => '$anzahl Übungen',
};

/// Der Vorlesetext der Kachel (Spec 7.8): Name, Dauer in Worten, Übungen,
/// Entwurf, Tags. **Nennt den Zustand, nicht das Zeichen.**
String gymTrainingsKachelVorlesetext(TrainingKachel kachel) {
  final dauer = kachel.isDraft
      ? 'Entwurf, noch nicht fertig'
      : kachel.minutes == null
      ? 'keine Dauer'
      : 'ca. ${kachel.minutes} Minuten';
  return [
    gymTrainingsKachelName(kachel),
    dauer,
    gymTrainingsAnzahl(kachel.exerciseCount),
    for (final tag in kachel.tags) 'Tag $tag',
  ].join(', ');
}

/// Der Vorlesetext der grauen Kachel: **keine Ziffer**.
const String gymTrainingsLaedtVorlesetext = 'wird geladen';

/// Der Vorlesetext einer Filterkapsel: „Gym, ausgewählt" bzw. „Gym".
String gymTrainingsChipVorlesetext(String tag, {required bool ausgewaehlt}) =>
    ausgewaehlt ? '$tag, ausgewählt' : tag;

// --- Die Figur ---------------------------------------------------------------

/// Die Aktion für VoiceOver, das nicht wischen kann (Spec 7.5).
const String gymTrainingsFigurUmdrehen = 'Figur umdrehen';

/// Die Muskeln aus [muskeln], die auf [seite] liegen, in der Reihenfolge von
/// [Muscle.values] — die Seite rechnet der Painter, hier nur die Auswahl für
/// den Text.
List<Muscle> gymTrainingsMuskelnAuf(Set<Muscle> muskeln, MuskelSeite seite) {
  final auf = MuskelFigurPainter.pfadeJeMuskel(seite);
  return [
    for (final m in Muscle.values)
      if (muskeln.contains(m) && auf.containsKey(m)) m,
  ];
}

/// „Brust, vordere Schulter und Trizeps".
String gymTrainingsMuskelListe(List<Muscle> muskeln) {
  final namen = [for (final m in muskeln) m.german];
  if (namen.length < 2) return namen.join();
  return '${namen.sublist(0, namen.length - 1).join(', ')} und ${namen.last}';
}

/// Der Vorlesetext der **Kachel-Figur** (Spec 7.5): die Seite **und** die
/// gefärbten Muskeln in Worten — „Vorderseite, trifft Brust und vordere
/// Schulter". Liegt auf dieser Seite keiner, steht das da, nicht eine leere
/// Aufzählung.
String gymTrainingsFigurVorlesetext(Set<Muscle> muskeln, MuskelSeite seite) {
  final name = seite == MuskelSeite.vorne ? 'Vorderseite' : 'Rückseite';
  final liste = gymTrainingsMuskelnAuf(muskeln, seite);
  return liste.isEmpty
      ? '$name, hier liegt kein trainierter Muskel'
      : '$name, trifft ${gymTrainingsMuskelListe(liste)}';
}

// --- Detail ------------------------------------------------------------------

const String gymTrainingDetailTitelZurueck = 'Trainings';
const String gymTrainingDetailKickerEigenes = 'Eigenes Training';
const String gymTrainingDetailKickerTemplate = 'Template';
const String gymTrainingDetailUebungen = 'Übungen';
const String gymTrainingDetailEckdaten = 'Eckdaten';
const String gymTrainingDetailTeilen = 'Teilen';
const String gymTrainingDetailStarten = 'Training starten';
const String gymTrainingDetailBearbeiten = 'Bearbeiten';
const String gymTrainingDetailBearbeitenKopie = 'Bearbeiten (als Kopie)';
const String gymTrainingDetailNichtGefunden =
    'Dieses Training gibt es nicht mehr.';
const String gymTrainingDetailNichtLesbar =
    'Dieses Training lässt sich gerade nicht lesen.';

const String gymTrainingDetailKopieHinweis =
    '„Bearbeiten" legt eine Kopie unter „Eigene" an — das Template bleibt, '
    'wie es ist.';

/// Die Herkunft — **aus der Kategorie abgeleitet, nicht gespeichert**
/// (Spec 17.12).
String gymTrainingDetailHerkunft(WorkoutCategory kategorie) =>
    kategorie == WorkoutCategory.template
    ? 'Template · mit der App'
    : 'Selbst angelegt';

/// Die Löschen-Zeile gibt es nur beim Eigenen (Spec 26 Nr. 1).
const String gymTrainingDetailLoeschen = 'Training löschen';

const String gymTrainingDetailLoeschenFuss =
    'Weg ist weg — eingetragene Sitzungen im Verlauf bleiben unverändert '
    'stehen.';

/// „Training „X" löschen?" — die Rückfrage nennt, was gelöscht würde.
String gymTrainingDetailLoeschenFrage(String name) =>
    'Training „$name" löschen?';

const String gymTrainingDetailLoeschenBestaetigen = 'Löschen';
const String gymTrainingDetailAbbrechen = 'Abbrechen';
const String gymTrainingDetailOk = 'OK';

/// Die Ablage lehnt ab, weil die Erfassung das Training trägt (Spec 4.7).
const String gymTrainingDetailLaeuftTitel = 'Das Training läuft gerade';

String gymTrainingDetailLaeuftText(String name) =>
    '„$name" läuft gerade in der Erfassung — erst abschließen oder '
    'verwerfen, dann lässt es sich löschen.';

const String gymTrainingDetailLoeschenFehlerTitel =
    'Löschen hat nicht geklappt';

/// „Übungen · Sätze" und der Wert dazu.
const String gymTrainingDetailUebungenSaetzeLabel = 'Übungen · Sätze';

/// „ca. 40 min · 5 Übungen · 15 Sätze" — die Lede des Details. **Ohne Dauer**
/// steht dort „keine Dauer", nicht „0 min".
String gymTrainingDetailLede(TrainingKachel kachel) {
  final minuten = kachel.minutes;
  return [
    minuten == null ? 'keine Dauer' : 'ca. $minuten min',
    gymTrainingsAnzahl(kachel.exerciseCount),
    kachel.setCount == 1 ? '1 Satz' : '${kachel.setCount} Sätze',
  ].join(' · ');
}

/// „4 Sätze · 6–10 Wdh"; eine Zeitübung „3 Sätze · 30–45 s".
String gymTrainingDetailUebungSchema(
  WorkoutExercise uebung, {
  bool zeit = false,
}) {
  final saetze = uebung.sets == 1 ? '1 Satz' : '${uebung.sets} Sätze';
  final bereich = '${uebung.repLow}–${uebung.repHigh}';
  return zeit ? '$saetze · $bereich s' : '$saetze · $bereich Wdh';
}

/// Der Vorlesetext der **Detail-Figur**: beide Seiten, alle gefärbten Muskeln.
String gymTrainingDetailFigurVorlesetext(Set<Muscle> muskeln) {
  final liste = [
    for (final m in Muscle.values)
      if (muskeln.contains(m)) m,
  ];
  return liste.isEmpty
      ? 'Vorderseite und Rückseite, kein trainierter Muskel'
      : 'Vorderseite und Rückseite, trifft ${gymTrainingsMuskelListe(liste)}';
}
