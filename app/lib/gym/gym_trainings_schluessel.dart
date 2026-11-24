// Die Schlüssel der Trainings-Übersicht und des Trainings-Details (#533 unter
// #531, Spec 7.7 und 8.5) — an einer Stelle, damit Schirm und Widget-Tests
// (`app/test/gym/gym_trainings_support.dart`) von denselben Zeichenketten
// sprechen. **Nur Zeichenketten, keine Logik.**
//
// Angelegt vom Test-Agenten (Plan Task 2.2: „die Datei legt der Test-Agent
// an"); der Implementierende darf sie ergänzen, aber keinen Schlüssel
// umbenennen oder entfernen, den ein Test benutzt.
//
// `<id>` ist `WorkoutDefinition.id` (bei Templates der `Workout.code`, bei
// Eigenen eine UUID), `<tag>` der Tag **kleingeschrieben** (`Home` → `home`),
// `<uid>` die `Exercise.id`.
import 'package:flutter/widgets.dart';

// --- Übersicht (Spec 7.7) ----------------------------------------------------

/// Der Schirm — auch der Schlüssel des geschobenen Gerüsts.
const kGymTrainings = Key('gym-trainings');
const kGymTrainingsFilter = Key('gym-trainings-filter');
const kGymTrainingsChipAlle = Key('gym-trainings-chip-alle');

/// Eine Filterkapsel; `<tag>` wird kleingeschrieben.
Key kGymTrainingsChip(String tag) =>
    Key('gym-trainings-chip-${tag.toLowerCase()}');

/// Die Gruppenköpfe — **stehen in jedem Zustand**.
const kGymTrainingsGruppeTemplates = Key('gym-trainings-gruppe-templates');
const kGymTrainingsGruppeEigene = Key('gym-trainings-gruppe-eigene');

/// Die Kachel — auch der `Semantics`-Knoten.
Key kGymTrainingsKachel(String id) => Key('gym-trainings-kachel-$id');

/// Die Figur — **die Fläche des Zugs**.
Key kGymTrainingsFigur(String id) => Key('gym-trainings-figur-$id');
Key kGymTrainingsPunkte(String id) => Key('gym-trainings-punkte-$id');
Key kGymTrainingsName(String id) => Key('gym-trainings-name-$id');
Key kGymTrainingsDauer(String id) => Key('gym-trainings-dauer-$id');
Key kGymTrainingsAnzahl(String id) => Key('gym-trainings-anzahl-$id');
Key kGymTrainingsTags(String id) => Key('gym-trainings-tags-$id');

/// Die Kapsel „Entwurf" — **nur** bei Entwürfen.
Key kGymTrainingsEntwurf(String id) => Key('gym-trainings-entwurf-$id');

/// Die grauen Kacheln — **nur** im Zustand „lädt".
const kGymTrainingsLaedtTemplates = Key('gym-trainings-laedt-templates');
const kGymTrainingsLaedtEigene = Key('gym-trainings-laedt-eigene');

/// Der Leerzustand der Eigenen — **nur**, wenn gelesen, leer, ungefiltert.
const kGymTrainingsLeerEigene = Key('gym-trainings-leer-eigene');

/// „Kein … trägt diesen Tag" — **nur** bei Filter ohne Treffer.
const kGymTrainingsLeerGefiltertTemplates = Key(
  'gym-trainings-leer-gefiltert-templates',
);
const kGymTrainingsLeerGefiltertEigene = Key(
  'gym-trainings-leer-gefiltert-eigene',
);

/// „Alle Templates gelöscht" — **nur** dann.
const kGymTrainingsLeerTemplates = Key('gym-trainings-leer-templates');

/// Der Satz, wenn schon das **erste** Lesen gescheitert ist — ein Satz über das
/// Lesen, keiner über die Datenlage. Ergänzt vom Implementierenden (Spec 7.4
/// verlangt „ohne einen Grund-Satz, der ‚keine Trainings' behauptete").
const kGymTrainingsFehler = Key('gym-trainings-fehler');

const kGymTrainingsPlus = Key('gym-trainings-plus');
const kGymTrainingsAnlegen = Key('gym-trainings-anlegen');

// --- Detail (Spec 8.5) -------------------------------------------------------

const kGymTrainingDetail = Key('gym-training-detail');
const kGymTrainingDetailFigur = Key('gym-training-detail-figur');

/// Eine Übungszeile; `<uid>` ist `Exercise.id`.
Key kGymTrainingDetailUebung(String uid) =>
    Key('gym-training-detail-uebung-$uid');
const kGymTrainingDetailDauer = Key('gym-training-detail-dauer');
const kGymTrainingDetailUebungenSaetze = Key(
  'gym-training-detail-uebungen-saetze',
);
const kGymTrainingDetailTags = Key('gym-training-detail-tags');
const kGymTrainingDetailHerkunft = Key('gym-training-detail-herkunft');

/// Der Hinweis „Bearbeiten legt eine Kopie an" — **nur** bei Templates.
const kGymTrainingDetailKopieHinweis = Key('gym-training-detail-kopie-hinweis');
const kGymTrainingDetailStarten = Key('gym-training-detail-starten');
const kGymTrainingDetailBearbeiten = Key('gym-training-detail-bearbeiten');
const kGymTrainingDetailTeilen = Key('gym-training-detail-teilen');
const kGymTrainingDetailLoeschen = Key('gym-training-detail-loeschen');
const kGymTrainingDetailLoeschenFrage = Key(
  'gym-training-detail-loeschen-frage',
);
const kGymTrainingDetailLoeschenBestaetigen = Key(
  'gym-training-detail-loeschen-bestaetigen',
);
const kGymTrainingDetailLaedt = Key('gym-training-detail-laedt');
const kGymTrainingDetailNichtGefunden = Key(
  'gym-training-detail-nicht-gefunden',
);

// --- Import-Vorschau (Spec 8.5, #535 — Scheibe 4) ------------------------------

const kGymTrainingVorschau = Key('gym-training-vorschau');

/// Eine je weggelassene Übung.
Key kGymTrainingVorschauUnbekannt(String uid) =>
    Key('gym-training-vorschau-unbekannt-$uid');
const kGymTrainingVorschauUebernehmen = Key(
  'gym-training-vorschau-uebernehmen',
);

/// Warum der Knopf aus ist.
const kGymTrainingVorschauGrund = Key('gym-training-vorschau-grund');
const kGymTrainingVorschauAbbrechen = Key('gym-training-vorschau-abbrechen');
