// Die Texte des Training-Editors (#534, Spec 9; Entwurf `docs/screens/
// screens/gym-training-editor.js`). Der Kern trägt keine Nutzertexte
// (`CLAUDE.md`); sie entstehen hier, an einer Stelle.
//
// **Die Wortlaute der Flächen, die nicht eigens entworfen wurden** (Tags,
// Dauer, Stepper, Rückfragen), sind Vorschläge der Spec (17 Nr. 23) — Tim
// sieht sie in der Prüfanleitung (Spec 22 Nr. 4).
//
// **Der Vorlesetext nennt den Zustand, nicht das Zeichen** (Spec 9.7): „Dauer,
// noch nicht geschätzt", nie „Strich".
import 'package:trainings_core/trainings_core.dart';

// --- Schirm ------------------------------------------------------------------

const gymEditorTitelNeu = 'Neues Training';
const gymEditorTitelBearbeiten = 'Training bearbeiten';
const gymEditorAbbrechen = 'Abbrechen';
const gymEditorSpeichern = 'Speichern';

String gymEditorKopieHinweis(String templateName) =>
    'Kopie von „$templateName". Das Template bleibt unverändert.';

// --- Stamm -------------------------------------------------------------------

const gymEditorStammKopf = 'Training';
const gymEditorNameLabel = 'Name';
const gymEditorNamePlatzhalter = 'z. B. Kurzhantel zuhause';
const gymEditorTagsLabel = 'Tags';
const gymEditorTagPlatzhalter = 'Tag hinzufügen';
const gymEditorDauerLabel = 'Dauer';
const gymEditorDauerZuruecksetzen = 'zurück zur Schätzung';
const gymEditorStammFuss =
    'Tags sind frei — schon benutzte werden vorgeschlagen. Die Dauer wird aus '
    'den Übungen geschätzt; eigene Minuten kannst du eintragen und jederzeit '
    'auf die Schätzung zurückgehen.';

/// „geschätzt 50 min" / „eingetragen 55 min" / „geschätzt – min" (ohne
/// Übung — die Zeile steht schon da, gleiche Form wie gefüllt).
String gymEditorDauerText({int? eingetragen, int? schaetzung}) {
  if (eingetragen != null) return 'eingetragen $eingetragen min';
  return 'geschätzt ${schaetzung ?? '–'} min';
}

/// „Dauer, geschätzt 50 Minuten" — nie „Strich" (Spec 9.7).
String gymEditorDauerVorlesen({int? eingetragen, int? schaetzung}) {
  if (eingetragen != null) return 'Dauer, eingetragen $eingetragen Minuten';
  if (schaetzung == null) return 'Dauer, noch nicht geschätzt';
  return 'Dauer, geschätzt $schaetzung Minuten';
}

// --- Dauerblatt --------------------------------------------------------------

const gymEditorDauerBlattTitel = 'Dauer';
const gymEditorDauerBlattFeld = 'Minuten';
const gymEditorDauerBlattSchaetzung = 'Schätzung benutzen';
const gymEditorDauerBlattFertig = 'Fertig';

/// Die Spanne der eingetragenen Dauer (Spec 5.2): 1 bis 600.
String gymEditorDauerBlattFuss() =>
    '${1} bis ${WorkoutRules.maxMinutes} Minuten. „Schätzung benutzen" nimmt '
    'die eigene Zahl zurück.';

// --- Übungen -----------------------------------------------------------------

const gymEditorUebungenKopf = 'Übungen';
const gymEditorUebungHinzufuegen = 'Übung hinzufügen';
const gymEditorUebungenFuss =
    'Ziehen am ≡ ändert die Reihenfolge. Antippen öffnet Sätze und '
    'Wiederholungsbereich.';
const gymEditorUebungenFussNeu =
    'Sätze und Wiederholungsbereich kommen aus dem Katalog vorbelegt und '
    'lassen sich je Übung ändern.';
const gymEditorLoeschen = 'Training löschen';
const gymEditorLoeschenFuss =
    'Mit Nachfrage. Eingetragene Sitzungen im Verlauf bleiben unverändert.';

/// „4 × 6–10", bei einer Zeitübung „3 × 30–45 s".
String gymEditorDosis(WorkoutExercise e, {required bool zeit}) =>
    '${e.sets} × ${e.repLow}–${e.repHigh}${zeit ? ' s' : ''}';

/// „Übung 2 von 5, Schrägbankdrücken Kurzhantel, 3 Sätze, 8 bis 12
/// Wiederholungen" (Zeitübung: „… 30 bis 45 Sekunden").
String gymEditorUebungVorlesen({
  required int position,
  required int von,
  required String name,
  required WorkoutExercise e,
  required bool zeit,
}) =>
    'Übung $position von $von, $name, ${e.sets} Sätze, '
    '${e.repLow} bis ${e.repHigh} ${zeit ? 'Sekunden' : 'Wiederholungen'}';

const gymEditorGriffVorlesen = 'Reihenfolge ändern';
const gymEditorNachOben = 'Nach oben';
const gymEditorNachUnten = 'Nach unten';

// --- Speichern: der Grund ------------------------------------------------------

/// Der Satz unter der Liste, **was dem Speichern fehlt** — leer, wenn nichts
/// fehlt (die Karte springt nicht, Spec 9.6). Auch leer, solange gelesen wird:
/// Aus nichts Gelesenem folgt kein Grund (Fehler `01`).
String gymEditorGrund(List<WorkoutProblem> probleme) {
  if (probleme.isEmpty) return '';
  final name = probleme.any((p) => p is NameEmpty);
  final uebung = probleme.any((p) => p is NoExercises);
  if (name && uebung) {
    return 'Speichern geht, sobald ein Name da ist und mindestens eine Übung '
        'drin ist.';
  }
  if (uebung) return 'Speichern geht, sobald mindestens eine Übung drin ist.';
  if (name) return 'Speichern geht, sobald das Training einen Namen hat.';
  if (probleme.any((p) => p is NameTooLong)) {
    return 'Speichern geht, sobald der Name höchstens '
        '${WorkoutRules.maxNameLength} Zeichen hat.';
  }
  if (probleme.any((p) => p is MinutesOutOfRange)) {
    return 'Speichern geht, sobald die Dauer zwischen 1 und '
        '${WorkoutRules.maxMinutes} Minuten liegt.';
  }
  return 'Speichern geht, sobald Sätze und Wiederholungen jeder Übung '
      'stimmen.';
}

/// „Speichern, nicht möglich, `Grund`" (Spec 9.7).
String gymEditorSpeichernNichtMoeglich(String grund) => grund.isEmpty
    ? 'Speichern, nicht möglich'
    : 'Speichern, nicht möglich, '
          '${grund.replaceFirst('Speichern geht, ', '')}';

// --- Rückfragen und Meldungen --------------------------------------------------

const gymEditorAbbrechenTitel = 'Änderungen sichern?';
const gymEditorAbbrechenText =
    'Der Stand ist als Entwurf gesichert. Du kannst ihn behalten oder '
    'verwerfen.';
const gymEditorEntwurfBehalten = 'Als Entwurf behalten';
const gymEditorVerwerfen = 'Verwerfen';
const gymEditorWeiter = 'Weiter bearbeiten';

const gymEditorLoeschenTitel = 'Training löschen?';
const gymEditorLoeschenText =
    'Das Training ist danach weg, auch aus der Wochenleiste. Eingetragene '
    'Sitzungen im Verlauf bleiben unverändert.';
const gymEditorLoeschenBestaetigen = 'Löschen';

/// Die Sperre aus Spec 4.7 — **nur**, wenn gerade eine gemeldet wurde.
const gymEditorGesperrt =
    'Das Training läuft gerade. Schließe es erst ab oder verwirf es, dann '
    'lässt es sich ändern oder löschen. Deine Eingaben bleiben stehen.';

const gymEditorFehler =
    'Das hat nicht geklappt. Deine Eingaben stehen noch hier, versuch es '
    'gleich noch einmal.';

// --- Einstellblatt -----------------------------------------------------------

const gymEditorBlattZurueck = 'Zurück';
const gymEditorBlattFertig = 'Fertig';
const gymEditorBlattUmfang = 'Umfang';
const gymEditorBlattSaetze = 'Sätze';
const gymEditorBlattWiederholungen = 'Wiederholungen';
const gymEditorBlattSekunden = 'Sekunden';
const gymEditorBlattVon = 'von';
const gymEditorBlattBis = 'bis';
const gymEditorBlattPosition = 'Position';
const gymEditorBlattImTraining = 'Im Training';
const gymEditorBlattEntfernen = 'Aus dem Training entfernen';

/// „Speichern" oben rechts in der **Vorschau** (Nachtrag 29 Nr. 1): Erst
/// das fügt die Übung mit den eingestellten Werten hinzu.
const gymEditorBlattSpeichern = 'Speichern';

/// Der Vorlesetext des „?" — **der Zustand, nicht das Zeichen**
/// (`CLAUDE.md`). **Wortlaut ist Vorschlag.**
const gymEditorBlattHilfeVorlesen = 'Hilfe zu Umfang und Training';

/// Die Überschrift des Hilfe-Modals. **Wortlaut ist Vorschlag.**
const gymEditorBlattHilfeTitel = 'Umfang und Training';

const gymEditorBlattHilfeSchliessen = 'Fertig';

/// Die Absätze des Hilfe-Modals hinter dem „?" (Nachtrag 29 Nr. 2) — die
/// Erklärtexte, die vorher als Füße im Blatt standen, dazu die Tipps zu
/// Wiederholungsbereichen und zu den Aufwärmsätzen. Der erste Absatz hängt
/// an der Übung und wird gerechnet ([gymEditorSteigerungAuskunft]).
///
/// **Alle Wortlaute sind Vorschläge** (Nachtrag 29 Nr. 2). Die Angaben zu
/// Wiederholungsbereichen sind **allgemeine Empfehlungen**, keine Vorgabe
/// im Einzelfall und keine ärztliche Auskunft (`CLAUDE.md`, „Keine
/// Diagnosen").
List<String> gymEditorBlattHilfeAbsaetze(Exercise katalog) => [
  gymEditorSteigerungAuskunft(katalog),
  'Zu den Bereichen: Für Muskelaufbau liegen meist 6 bis 12 '
      'Wiederholungen je Satz gut, für Grundfitness und Technik eher 12 '
      'bis 20 mit weniger Gewicht. Das ist eine allgemeine Empfehlung und '
      'keine Vorgabe für dich — nach einer Verletzung oder Operation '
      'gilt, was ärztlich freigegeben ist.',
  'Aufwärmsätze zählen hier nicht mit: Gemeint sind die Arbeitssätze. '
      'Was du dich vorher warm machst, trägst du nicht als Satz ein.',
  'Entfernt die Übung nur aus diesem Training — eingetragene Sitzungen '
      'bleiben unverändert.',
];

/// „Vorbelegt aus dem Katalog: 4 × 6–10, Steigerung +2,5 kg. Die
/// Steigerungsregel folgt in einem späteren Update." — **gerechnet** aus dem
/// Katalog, nicht geschrieben (Spec 9.4).
///
/// **Die Ankündigung ist nur ehrlich, solange #537 offen ist** (Spec 12
/// Nr. 2): Wer die Steigerungsregel baut, nimmt den zweiten Satz heraus.
String gymEditorSteigerungAuskunft(Exercise katalog) {
  final zahl = katalog.increment == katalog.increment.roundToDouble()
      ? '${katalog.increment.round()}'
      : '${katalog.increment}'.replaceAll('.', ',');
  final schritt = katalog.isTimed ? '+$zahl s' : '+$zahl kg';
  final dosis =
      '${katalog.sets} × ${katalog.repLow}–${katalog.repHigh}'
      '${katalog.isTimed ? ' s' : ''}';
  return 'Vorbelegt aus dem Katalog: $dosis, Steigerung $schritt. Die '
      'Steigerungsregel folgt in einem späteren Update.';
}

/// „2 von 4" zwischen ↑ und ↓.
String gymEditorBlattPositionText(int position, int von) =>
    '$position von $von';

// --- Auswahl -----------------------------------------------------------------

const gymEditorWahlTitel = 'Übung hinzufügen';
const gymEditorWahlZurueck = 'Zurück';
const gymEditorWahlSuche = 'Übung suchen';
const gymEditorWahlLeer = 'Keine Übung gefunden.';
const gymEditorWahlSchonDrin = 'schon im Training';

/// Der Vorlesetext des Abspiel-Icons (#551, Spec 9.6): der Zustand, nicht
/// das Zeichen. **Wortlaut ist Vorschlag der Spec.**
const gymEditorWahlMitBild = 'mit Bewegungsbild';

/// „581 Übungen in der Bibliothek, mit Technikhinweis in der Erfassung." —
/// die Zahl ist gezählt (`ExerciseLibrary.length`), **ohne „mit Bild"**
/// (Spec 9.5, 12). „Bibliothek", nicht „Katalog": Der Katalog sind im
/// Projekt die 33 Anker.
String gymEditorWahlFuss(int anzahl) =>
    '$anzahl Übungen in der Bibliothek, mit Technikhinweis in der Erfassung.';
