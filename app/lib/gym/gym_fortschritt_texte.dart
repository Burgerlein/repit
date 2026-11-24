// Die Sätze des Schirms „Fortschritt pro Übung" (#93) — Dart-Entsprechung der
// Beschriftungen in `Sources/Features/Gym/GymProgressView.swift`, nachgezogen
// auf die Spec `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`
// (im Folgenden „die Spec") und den Entwurf `docs/screens/screens/
// gym-progress.js`.
//
// `trainings_core` trägt keine Nutzertexte (`CLAUDE.md`); die Sätze entstehen
// in der Ansichtsschicht, an **genau einer Stelle**. Gewichte laufen über
// [vorschlagGewichtText] und [gymZahlText] — „62,5 kg", nie „62.5".
//
// **Das geschätzte 1RM ist eine Schätzung** (`CLAUDE.md`, „Keine
// Diagnosen"). Gekennzeichnet ist es an drei Stellen, je ein Wort oder ein
// Satz (Spec 7): in der Beschriftung der Kachel ([gymFortschrittKachel1rm]),
// in der Legende ([gymFortschrittLegende1rm]) und in der Fußnote
// ([gymFortschrittFuss]). Keine Fehlerbalken, keine Spanne, keine Schwelle:
// Eine Genauigkeit der Genauigkeit kennt niemand.
import 'package:trainings_core/trainings_core.dart';

import '../shell/diagramm_zeitraum.dart';
import 'gym_vorschlag_texte.dart';

// --- Schirm ------------------------------------------------------------------

const gymFortschrittTitel = 'Fortschritt';
const gymFortschrittAuswahlLabel = 'Übung';
const gymFortschrittAuswahlAbbrechen = 'Abbrechen';

/// Der Satz im Menü, wenn noch keine Übung einen Verlauf hat (#551,
/// Nachtrag 17 Nr. 4). **Wortlaut ist Vorschlag** — der Schlüssel
/// (`kGymFortschrittWahlLeer`) ist fest, der Satz nicht.
const gymFortschrittAuswahlLeer =
    'Noch keine Übung trainiert. Nach dem ersten Training stehen deine '
    'Übungen hier.';

// --- Kacheln -----------------------------------------------------------------

const gymFortschrittKachelHoechst = 'Höchstgewicht';

/// Bei einer Zeitübung steht im Gewichtsfeld keine Last; zählt die längste
/// Zeit (Spec 9.2).
const gymFortschrittKachelBesteZeit = 'Beste Zeit';

/// **Die Beschriftung nennt die Schätzung** — bei der Zahl, dort, wo sie
/// gelesen wird (Spec 7).
const gymFortschrittKachel1rm = '1RM geschätzt';

/// Beispieltext für die graue Form — die Breite des echten Werts, nie
/// gezeichnet.
const gymFortschrittKachelBeispiel = '62,5 kg';

/// „62,5 kg", bei Unterstützung „24,5 kg Unterstützung", bei einer
/// Zeitübung „40 s".
String gymFortschrittHoechstText(double wert, Exercise uebung) => uebung.isTimed
    ? '${gymZahlText(wert)} s'
    : vorschlagGewichtText(wert, uebung);

/// „83,3 kg".
String gymFortschritt1rmText(double wert) => '${gymZahlText(wert)} kg';

/// Der Vorlesetext einer Kachel: nennt den Zustand, nicht das Zeichen
/// (`CLAUDE.md`). Beim Lesen steht kein Grund da (Fehler `01`).
String gymFortschrittKachelVorlesetext({
  required String label,
  required String? wert,
  required bool laedt,
  required bool fehlgeschlagen,
}) {
  if (wert != null) return '$label, $wert';
  if (laedt) return '$label, wird geladen';
  if (fehlgeschlagen) return '$label, nicht lesbar';
  return '$label, kein Wert';
}

// --- Diagramm ----------------------------------------------------------------

const gymFortschrittLegende1rm = '1RM, geschätzt';

/// Der Satz **in** der Karte, wo bekannt ist, dass es weniger als zwei
/// Trainingstage gibt. Beim Laden und nach einem Fehler steht er nicht da —
/// beides wären Gründe, die es noch nicht gibt.
const gymFortschrittDiagrammLeer =
    'Noch zu wenige Trainings für einen Verlauf. Ab dem zweiten '
    'Trainingstag erscheint hier eine Linie.';

/// Die Fußzeile des Diagramms **wechselt mit der Stufe** und behauptet nie
/// ein Mittel: Der Satz „…gezeigt wird der Monatsdurchschnitt" stand im alten
/// Entwurf und bliebe als Zusage stehen, die nicht stimmt (Spec 3.3).
String gymFortschrittDiagrammFuss(DiagrammStufe stufe) => switch (stufe) {
  DiagrammStufe.woche || DiagrammStufe.monat => 'Je Trainingstag ein Punkt.',
  DiagrammStufe.halbjahr ||
  DiagrammStufe.jahr => 'Je Punkt ein Monat, gezeigt wird das Monatsmaximum.',
};

// --- Hinweise ----------------------------------------------------------------

/// Der Satz zur Übung — hängt an der **Übung**, nicht an den Daten (Spec
/// 3.4): Er steht bei Dips und Klimmzügen immer da (Board und Swift,
/// wörtlich).
const gymFortschrittUnterstuetzung =
    'Für Sätze mit Unterstützung gibt es keine 1RM-Schätzung: Was '
    'tatsächlich bewegt wird, hinge vom Körpergewicht ab — das wäre eine '
    'Schätzung auf einer Schätzung.';

const gymFortschrittZeituebung = 'Zeitübungen haben kein 1RM.';

const gymFortschrittFehlerText = 'Verlauf konnte nicht gelesen werden.';
const gymFortschrittErneut = 'Erneut lesen';

/// **Eine Beobachtung, keine Beurteilung** (Spec 8): Der Satz sagt, was
/// gezählt wurde — vier **Trainings**, nicht vier Wochen —, und nicht,
/// warum. Keine Ursache, kein Befund (`CLAUDE.md`, „Keine Diagnosen").
const gymFortschrittPlateauText =
    'Seit vier Trainings kein Anstieg des geschätzten 1RM. Das ist eine '
    'Beobachtung aus deinen Einträgen, keine Beurteilung. Allgemein hilft '
    'oft: Schlaf und Essen prüfen oder für ein paar Wochen den '
    'Wiederholungsbereich wechseln.';

/// Das Zeichen des Plateaus — **Farbe allein trägt die Aussage nicht**
/// (Spec 3.4). Ein Pfeil nach rechts: weder hoch noch runter.
const gymFortschrittPlateauSymbol = '→';

// --- Fußnote -----------------------------------------------------------------

/// Die Formel und das Wort „Schätzung" — **einmal, und in jeder Lage derselbe
/// Satz** (Spec 7). Dazu der Hinweis, dass die Vorschläge allgemeine
/// Empfehlungen sind, und die ärztliche Freigabe (`CLAUDE.md`: bei
/// OP-Erholung und Krankheit immer — dieser Schirm gibt
/// Steigerungsvorschläge).
const gymFortschrittFuss =
    '1RM nach Epley: Gewicht × (1 + Wiederholungen / 30). Schätzung, kein '
    'Maximalversuch — und mit steigender Wiederholungszahl ungenauer. '
    'Hinweise auf diesem Schirm sind allgemeine Empfehlungen, keine '
    'Diagnose. Bei Krankheit oder nach einer OP zählt die ärztliche '
    'Freigabe.';
