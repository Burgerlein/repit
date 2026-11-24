// Die Schlüssel des Training-Editors (#534 unter #531, Spec 9.7) — an einer
// Stelle, damit Schirm und Widget-Tests (`app/test/gym/gym_editor_view_test.dart`)
// von denselben Zeichenketten sprechen. **Nur Zeichenketten, keine Logik.**
//
// Angelegt vom Test-Agenten (Plan Task 3.5: „Schlüsseldatei
// `gym_training_editor_schluessel.dart` (Tabelle 9.7)"); der Implementierende
// darf sie ergänzen, aber keinen Schlüssel umbenennen oder entfernen, den ein
// Test benutzt. Wörtlich nach der Tabelle in Spec 9.7 — **mit einer
// Festlegung des Test-Agenten zur Lage**, die die Spec offen lässt (Tim hat sie
// nicht gesehen):
//
// - Ein Schlüssel sitzt auf dem Widget, das er beschreibt. Die
//   Eingabefelder (`gym-editor-name`) tragen **ein** `EditableText` im
//   Teilbaum (oder sind selbst eins); die Texte (`-speichern-grund`,
//   `-dauer`, `-dosis-<uid>`, `-pos-<uid>`) tragen ihren Text im Teilbaum.
// - `-speichern`, `-abbrechen`, `-hinzufuegen`, `-loeschen`, `-dauer-
//   zuruecksetzen` und die Knöpfe der Blätter sind die **antippbaren**
//   Widgets; ein abgeblendeter Knopf bleibt mit seinem Schlüssel im Baum.
// - `-abbrechen-frage` und `-loeschen-frage` sitzen auf der **ganzen**
//   Rückfrage (Dialog mit Text und Knöpfen), `-entwurf-behalten`,
//   `-verwerfen`, `-weiter` und `-loeschen-bestaetigen` auf den Knöpfen darin.
// - `-wahl-schon-drin-<uid>` steht **nur** bei einer Übung, die schon im
//   Training ist; `-wahl-uebung-<uid>` steht bei jeder Zeile.
// - `-gesperrt` ist der Satz der Sperre aus Spec 4.7 und steht **nur**, wenn
//   gerade eine Sperre gemeldet wurde.
//
// `<uid>` ist `Exercise.id`, `<tag>` der Tag **kleingeschrieben**
// (`Gym` → `gym`), `<muskel-code>` ist `Muscle.code` (`chest`, `frontDelt` …).
import 'package:flutter/widgets.dart';

// --- Der Schirm --------------------------------------------------------------

/// Der Schirm — auch der Schlüssel des geschobenen Gerüsts.
const kGymEditor = Key('gym-editor');

/// Das Zeichen, dass noch gelesen wird — **nur** im Zustand „lädt".
const kGymEditorLaedt = Key('gym-editor-laedt');

/// Die Notizfläche „Kopie von …" — **nur** bei der Quelle `kopie`.
const kGymEditorKopieHinweis = Key('gym-editor-kopie-hinweis');

// --- Stamm -------------------------------------------------------------------

const kGymEditorName = Key('gym-editor-name');
const kGymEditorTags = Key('gym-editor-tags');

/// Ein Vorschlag (antippbar) — nur, solange der Tag noch nicht gesetzt ist.
Key kGymEditorTagVorschlag(String tag) =>
    Key('gym-editor-tag-vorschlag-${tag.toLowerCase()}');

/// Ein gesetzter Tag.
Key kGymEditorTag(String tag) => Key('gym-editor-tag-${tag.toLowerCase()}');

/// Die Dauerzeile — **steht in jedem Zustand**.
const kGymEditorDauer = Key('gym-editor-dauer');

/// „zurück zur Schätzung" — **nur**, wenn eigene Minuten eingetragen sind.
const kGymEditorDauerZuruecksetzen = Key('gym-editor-dauer-zuruecksetzen');

// --- Übungen -----------------------------------------------------------------

const kGymEditorUebungen = Key('gym-editor-uebungen');
Key kGymEditorUebung(String uid) => Key('gym-editor-uebung-$uid');
Key kGymEditorGriff(String uid) => Key('gym-editor-griff-$uid');

/// Die Position als Ziffer („1", „2" …).
Key kGymEditorPos(String uid) => Key('gym-editor-pos-$uid');

/// „4 × 6–10", bei einer Zeitübung „3 × 30–45 s".
Key kGymEditorDosis(String uid) => Key('gym-editor-dosis-$uid');
const kGymEditorHinzufuegen = Key('gym-editor-hinzufuegen');

// --- Speichern, Abbrechen, Löschen -------------------------------------------

const kGymEditorSpeichern = Key('gym-editor-speichern');

/// Der Satz, der sagt, was fehlt — **steht in jedem Zustand**, leer, wenn
/// nichts fehlt.
const kGymEditorSpeichernGrund = Key('gym-editor-speichern-grund');
const kGymEditorAbbrechen = Key('gym-editor-abbrechen');
const kGymEditorAbbrechenFrage = Key('gym-editor-abbrechen-frage');
const kGymEditorEntwurfBehalten = Key('gym-editor-entwurf-behalten');
const kGymEditorVerwerfen = Key('gym-editor-verwerfen');
const kGymEditorWeiter = Key('gym-editor-weiter');

/// „Training löschen" — **nur** bei der Quelle `bearbeite`.
const kGymEditorLoeschen = Key('gym-editor-loeschen');
const kGymEditorLoeschenFrage = Key('gym-editor-loeschen-frage');
const kGymEditorLoeschenBestaetigen = Key('gym-editor-loeschen-bestaetigen');

/// Die Sperre aus Spec 4.7 („Das Training läuft gerade …").
const kGymEditorGesperrt = Key('gym-editor-gesperrt');

// --- Einstellblatt (Variante `uebung-einstellen`) -----------------------------

const kGymEditorBlatt = Key('gym-editor-blatt');
const kGymEditorBlattSaetze = Key('gym-editor-blatt-saetze');
const kGymEditorBlattWdhVon = Key('gym-editor-blatt-wdh-von');
const kGymEditorBlattWdhBis = Key('gym-editor-blatt-wdh-bis');

/// „2 von 4" zwischen ↑ und ↓.
const kGymEditorBlattPosition = Key('gym-editor-blatt-position');
const kGymEditorBlattHoch = Key('gym-editor-blatt-hoch');
const kGymEditorBlattRunter = Key('gym-editor-blatt-runter');
const kGymEditorBlattEntfernen = Key('gym-editor-blatt-entfernen');
const kGymEditorBlattFertig = Key('gym-editor-blatt-fertig');

/// „Zurück" oben links — auf **beiden** Wegen ins Blatt. Im Zeilen-Weg
/// behält es die Übung, in der Vorschau verwirft es (Nachtrag 29 Nr. 1).
const kGymEditorBlattZurueck = Key('gym-editor-blatt-zurueck');

/// „Speichern" oben rechts — **nur in der Vorschau**: Erst das fügt die
/// Übung mit den eingestellten Werten hinzu (Nachtrag 29 Nr. 1). Der
/// Zeilen-Weg trägt dort weiter „Fertig".
const kGymEditorBlattSpeichern = Key('gym-editor-blatt-speichern');

/// Das „?" in der Kopfzeile „Umfang" (Nachtrag 29 Nr. 2) und das Modal
/// dahinter — auf beiden Wegen ins Blatt.
const kGymEditorBlattHilfe = Key('gym-editor-blatt-hilfe');
const kGymEditorBlattHilfeModal = Key('gym-editor-blatt-hilfe-modal');
const kGymEditorBlattHilfeSchliessen = Key(
  'gym-editor-blatt-hilfe-schliessen',
);

// --- Auswahl (Variante `uebung-waehlen`) ----------------------------------------

const kGymEditorWahl = Key('gym-editor-wahl');
const kGymEditorWahlSuche = Key('gym-editor-wahl-suche');

/// Der Kopf einer Gruppe; `<muskel-code>` ist `Muscle.code`.
Key kGymEditorWahlGruppe(String muskelCode) =>
    Key('gym-editor-wahl-gruppe-$muskelCode');
Key kGymEditorWahlUebung(String uid) => Key('gym-editor-wahl-uebung-$uid');

/// „schon im Training" — **nur** bei einer Übung, die schon drin ist.
Key kGymEditorWahlSchonDrin(String uid) =>
    Key('gym-editor-wahl-schon-drin-$uid');

/// „Keine Übung gefunden." — **nur** bei einer Suche ohne Treffer.
const kGymEditorWahlLeer = Key('gym-editor-wahl-leer');
const kGymEditorWahlFuss = Key('gym-editor-wahl-fuss');

/// Das Abspiel-Icon einer Zeile (#551, Spec 9.6, 9.9) — **nur im Baum, wenn
/// es steht**: in gemischter Lage (mindestens eine Übung ohne Bild,
/// Nachtrag 17 Nr. 1) und nur an Zeilen **mit** Bild. Zeichenkette
/// festgelegt in `app/test/gym/gym_editor_auswahl_test.dart`.
Key kGymEditorWahlBild(String uid) => Key('gym-editor-wahl-bild-$uid');

// --- Ergänzt vom Implementierenden (Spec 9.3, 9.6; keine Tabelle 9.7) --------

/// Der Satz, wenn das Speichern oder Löschen aus einem anderen Grund als der
/// Sperre gescheitert ist — **nur**, wenn gerade etwas gescheitert ist.
const kGymEditorFehler = Key('gym-editor-fehler');

/// Das Eingabeblatt für eigene Minuten (Spec 9.3, Vorschlag).
const kGymEditorDauerBlatt = Key('gym-editor-dauer-blatt');
const kGymEditorDauerFeld = Key('gym-editor-dauer-feld');

/// „Schätzung benutzen" im Eingabeblatt.
const kGymEditorDauerSchaetzung = Key('gym-editor-dauer-schaetzung');
const kGymEditorDauerFertig = Key('gym-editor-dauer-fertig');

/// Das Eingabefeld für einen neuen Tag.
const kGymEditorTagFeld = Key('gym-editor-tag-feld');

// --- Ergänzt vom Test-Agenten (Spec 28, #553, #554) ----------------------------

/// „Zurück" im Kopf der Auswahl — schließt sie (Spec 28 Nr. 1: Die Auswahl
/// schließt nicht mehr beim Antippen, sondern hier).
const kGymEditorWahlZurueck = Key('gym-editor-wahl-zurueck');

/// Die Muskelfigur zwischen Stamm und Übungsliste (Spec 28 Nr. 3, #554). Der
/// Schlüssel sitzt auf dem **Rahmen mit der festen Höhe**; die [MuskelFigur]
/// steht darin, beide Seiten nebeneinander.
const kGymEditorFigur = Key('gym-editor-figur');
