// Die Sätze des Pulsblocks im Gym-Verlauf (#512) — Spec
// `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, Abschnitte 5 bis 7.
//
// `trainings_core` trägt keine Nutzertexte (`CLAUDE.md`); sie entstehen hier,
// an genau einer Stelle. **Die Wortlaute sind Entwürfe des Test-Agenten, nicht
// Tims Entscheidung** (Spec 13, Punkt 11).
//
// **Keine Diagnose:** Ø und Spannen sind Messungen, kein Urteil über die
// Anstrengung. Hier steht nirgends „zu hoch", „Zone" oder „anstrengend".
//
// **Der Grund steht einmal.** Beide Leerfälle — kein Training an dem Tag und
// ein Training ohne Stichprobe — sind derselbe Zustand mit demselben Satz:
// Apple verrät den Lesestatus nicht, „keine Daten" und „nicht erlaubt" sind
// nicht unterscheidbar. Der Satz benennt beides und verweist auf die
// Health-Einstellungen. Er sagt nie „nichts getrackt" und nie „du hast nicht
// trainiert" — das Training steht in der Karte darüber.
import '../core/messwert.dart';
import '../design/platzhalter.dart' show ohneWert;
import 'gym_puls_provider.dart';

const gymPulsTitel = 'Herzfrequenz';

/// „Ø 123 bpm" — gerundet; eine Messung, keine Bewertung.
String gymPulsWertText(double durchschnitt) => 'Ø ${durchschnitt.round()} bpm';

/// „90–200 bpm".
String gymPulsBereichText(double tiefster, double hoechster) =>
    '${tiefster.round()}–${hoechster.round()} bpm';

/// Beispieltexte für die graue Form — die Breite des echten Werts, nie
/// gezeichnet (siehe `Platzhalter`).
const gymPulsWertBeispiel = 'Ø 000 bpm';
const gymPulsBereichBeispiel = '000–000 bpm';

/// Der Grund bei `LeerNachLauf` — **einmal**, in der Fläche.
///
/// „Die Uhr lief nicht mit" ist bei alten Trainings der Normalfall und keine
/// Störung; der Satz klingt nicht danach.
const gymPulsGrund =
    'Für diesen Tag liegt kein Apple-Krafttraining mit Herzfrequenz vor: Die '
    'Uhr lief nicht mit, oder der Zugriff ist in den Health-Einstellungen '
    'nicht freigegeben.';

/// Der Hinweis bei `Fehlgeschlagen`. Sagt, dass das Lesen scheiterte, und
/// **nichts über die Datenlage** — weder „keine Daten" noch „nicht
/// freigegeben".
const gymPulsFehler =
    'Der Puls ließ sich nicht lesen. Das sagt nichts über die Datenlage; '
    'öffne den Verlauf noch einmal.';

/// Warum es kein Band gibt — **nur** bei `Bekannt` ohne Abschnitt. Sagt nicht
/// „Fehler": Es ist der Normalfall bei allem Übernommenen.
const gymPulsBandGrund =
    'Das Band braucht eine Uhrzeit je Satz. Die schreibt erst die Erfassung '
    'im Neubau mit; übernommene Trainings haben keine.';

/// „0", „34", „68 min" — die Achse unter dem Band, in Minuten seit Beginn.
String gymPulsAchseText(int minuten, {bool mitEinheit = false}) =>
    mitEinheit ? '$minuten min' : '$minuten';

/// Das Ø rechts in der Übungszeile: „Ø 120" oder `Ø –/–`, **nie `Ø 0`**.
String gymPulsUebungText(double? durchschnitt) =>
    'Ø ${durchschnitt == null ? ohneWert : durchschnitt.round()}';

/// Der Vorlesetext der Zeile: nennt den Zustand, nicht das Zeichen.
String gymPulsUebungVorlesetext(double? durchschnitt) => durchschnitt == null
    ? 'Durchschnittspuls: kein Puls'
    : 'Durchschnittspuls ${durchschnitt.round()}';

/// Der Vorlesetext des Blocks — **ein** Knoten. Nennt den Zustand, nicht das
/// Zeichen: weder `–/–` noch „Strich", und während des Ladens keine Ziffer
/// (Fehler `01`).
String gymPulsVorlesetext(Messwert<GymPuls> puls) => switch (puls) {
  NochNie() => '$gymPulsTitel, wird geladen',
  Bekannt(:final wert) =>
    '$gymPulsTitel, durchschnittlich '
        '${wert.zusammenfassung.avg.round()}, zwischen '
        '${wert.zusammenfassung.min.round()} und '
        '${wert.zusammenfassung.max.round()} Schläge pro Minute',
  LeerNachLauf() => '$gymPulsTitel, kein Puls vorhanden',
  Fehlgeschlagen() => '$gymPulsTitel, ließ sich nicht lesen',
};
