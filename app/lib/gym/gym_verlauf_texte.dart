// Die Sätze des Schirms „Letzte Trainings" (#79) — Dart-Entsprechung der
// Beschriftungen in `Sources/Features/Gym/GymHistoryView.swift`, nachgezogen
// auf den Entwurf `docs/screens/screens/gym-history.js` und die Spec
// `docs/superpowers/specs/` (Datei `…-gym-verlauf-design.md`, im Folgenden
// „die Spec").
//
// `trainings_core` trägt keine Nutzertexte (`CLAUDE.md`); die Sätze entstehen
// in der Ansichtsschicht, an **genau einer Stelle je Vokabular**. Das
// Aufwärmen steht in `gym_log_texte.dart` und wird von dort geholt, nicht ein
// zweites Mal geschrieben.
//
// **Ein fehlender Wert steht nie als `0` da** (`CLAUDE.md`): Eine Dauer, die
// nicht eingetragen wurde, ein Volumen ohne tragende Last und ein Satz am
// eigenen Körpergewicht tragen keine Null — sie fehlen.
//
// Jede Datumsangabe läuft über [Format] mit fest gesetzter Sprache und über
// den **Berliner** Kalendertag der Sitzung ([kalendertag]), jede Zahl über
// [gymZahlText] oder [formatNumber] — „62,5", nie „62.5".
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/zahlen.dart';
import 'gym_log_texte.dart';
import 'gym_vorschlag_texte.dart';

// --- Schirm ------------------------------------------------------------------

const gymVerlaufTitel = 'Letzte Trainings';

// --- Kennzahlen --------------------------------------------------------------

const gymVerlaufTrainingsLabel = 'Trainings 14 Tage';
const gymVerlaufVolumenLabel = 'Volumen 14 Tage';

/// „5" — die Zahl der Trainings. Nie `0` für „nicht bekannt": das regelt
/// der Aufrufer, hier steht nur die Zahl.
String gymVerlaufTrainingsText(int anzahl) => '$anzahl';

/// „38.420 kg". Eine allgemeine Schätzung: unterstützte Sätze zählen nicht
/// mit (siehe [gymVerlaufFuss]).
String gymVerlaufVolumenText(double kg) => '${formatNumber(kg)} kg';

/// Beispieltexte für die graue Form — die Breite des echten Werts, nie
/// gezeichnet (siehe `Platzhalter`).
const gymVerlaufTrainingsBeispiel = '00';
const gymVerlaufVolumenBeispiel = '38.420 kg';

/// Der Vorlesetext einer Kachel: nennt den Zustand, nicht das Zeichen
/// (`CLAUDE.md`). Während des Lesens steht kein Grund da (Fehler `01`);
/// nach einem gescheiterten Lesen steht „nicht lesbar" und **nicht** „keine
/// Trainings" — Letzteres behauptete eine Datenlage, die nicht bekannt ist.
String gymVerlaufKachelVorlesetext({
  required String label,
  required String? wert,
  required bool laedt,
  required bool fehlgeschlagen,
  required String keinWert,
}) {
  if (wert != null) return '$label, $wert';
  if (laedt) return '$label, wird geladen';
  if (fehlgeschlagen) return '$label, nicht lesbar';
  return '$label, $keinWert';
}

const gymVerlaufKeineTrainings = 'keine Trainings';
const gymVerlaufKeinVolumen = 'kein Volumen';

// --- Hinweise ----------------------------------------------------------------

/// Der leere Verlauf — der Zustand, den Tim als Erstes sieht (Spec 6.1).
///
/// Nennt **beide Wege**. Und sagt, dass der zweite noch nicht geht: Die
/// Zeile „Daten übernehmen" im Mehr-Menü trägt selbst den Zusatz „folgt in
/// einer späteren Aufgabe", und die Übernahme (#59) ist nicht gebaut. Ohne
/// den Zusatz wäre der Satz eine Zusage, die nicht stimmt (`CLAUDE.md`).
/// **Wer #59 baut, streicht den Zusatz.**
///
/// Sagt „noch nichts da", nicht „keine Daten": Das wäre die Antwort auf
/// eine Abfrage, die leer ausging — und die gab es hier nicht.
const gymVerlaufLeerText =
    'Noch nichts da. Ein Training kannst du selbst eintragen: Gym › Training '
    'starten. Die Sitzungen aus dem alten Web-Dashboard holst du über Mehr › '
    'Daten übernehmen — das folgt in einer späteren Aufgabe.';

/// Das Lesen ist gescheitert, und nichts ist bekannt. Sagt **nichts** über
/// die Datenlage — insbesondere nicht, dass nichts eingetragen wäre
/// (Spec 6.2).
const gymVerlaufFehlerText =
    'Die Trainings ließen sich gerade nicht lesen. Das sagt nichts darüber, '
    'ob welche eingetragen sind. Öffne den Schirm später noch einmal.';

/// Der Fuß — steht in jeder Datenlage, **ein** Satz für den ganzen Schirm
/// (nicht einer je Karte). Nennt die Grenze von zwölf, das Volumen als
/// Schätzung, die Quelle des Pulses als Messung und was das Band zeigt
/// (#512, Spec 10).
///
/// **Keine Ankündigung mehr:** „Pulsverlauf und Übungsband folgen in einer
/// späteren Aufgabe" wäre eine Zusage, die nicht mehr stimmt. Der Puls ist
/// eine Messung, kein Urteil über die Anstrengung.
const gymVerlaufFuss =
    'Die letzten 12 Trainings. Das Volumen ist eine Schätzung: Sätze mit '
    'Unterstützung zählen nicht mit. Der Puls stammt aus Apple Health und ist '
    'eine Messung, kein Urteil über die Anstrengung. Das Band zeigt, wann '
    'Sätze eingetragen wurden, nicht wann gehoben.';

// --- Karte -------------------------------------------------------------------

/// „Gym A · Do. 05.03." — Name und **Berliner** Tag; der Name löst
/// `WorkoutNaming.shortTitle` auf (eingefrorener Name, sonst Enum-Fall). Eine
/// Sitzung ohne beides heißt „Training" (wie bei der Zeile „Letzte Trainings" auf dem
/// Gym-Schirm); Swifts „Gym ?" ist eine Platzhalterschreibweise.
String gymVerlaufKartenTitel(ImportedSession sitzung) {
  final tag = kalendertag(sitzung.date);
  final name = WorkoutNaming.shortTitle(sitzung) ?? 'Training';
  return '$name · ${Format.wochentagKurz(tag)} ${Format.tagMonat(tag)}';
}

/// „18 Sätze · 7.240 kg · 68 min" — **was nicht bekannt ist, steht nicht
/// da**: keine „0 Sätze" bei einer Sitzung ohne Satz, kein „0 kg" bei einem
/// Training ohne tragende Last (Unterstützung zählt nicht), keine „0 min"
/// ohne eingetragene Dauer. Das Aufwärmen steht nicht darin: Es zählt weder
/// zu den Sätzen noch zum Volumen noch zur Dauer.
String gymVerlaufKurzfassung(ImportedSession sitzung) {
  final saetze = sitzung.setCount;
  final volumen = sitzung.volumeKg;
  final minuten = sitzung.minutes;
  return [
    if (saetze > 0) gymSaetzeText(saetze),
    if (volumen > 0) '${formatNumber(volumen)} kg',
    if (minuten != null && minuten > 0) '$minuten min',
  ].join(' · ');
}

// --- Sätze -------------------------------------------------------------------

/// Die Plakette eines Satzes: „60 kg × 10", „62,5 kg × 9", „25 kg U × 9"
/// (der **Betrag**, nie „−25"), bei einer Zeitübung „30 s".
///
/// Ein Satz am eigenen Körpergewicht hat **kein** Gewicht, nicht das Gewicht
/// 0: „– kg × 12" — wie die Erfassung es zeigt (`gym_log_texte.dart`).
/// [uebung] ist `null`, wenn der Katalog die Übung nicht kennt; der Satz
/// steht dann als „Gewicht × Wdh.".
String gymVerlaufSatzText(Exercise? uebung, CompletedSet satz) {
  if (uebung != null && uebung.isTimed) return '${satz.reps} s';
  final gewicht = satz.weight;
  if (gewicht == 0) return '$gymPlatzhalterLeer kg × ${satz.reps}';
  final einheit = gymGewichtEinheit(unterstuetzt: gewicht < 0, zeit: false);
  return '${gymZahlText(gewicht.abs())} $einheit × ${satz.reps}';
}

/// Die Erklärung des „U" — nur, wo ein Satz mit Unterstützung steht.
const gymVerlaufUnterstuetzungHinweis = 'U = Unterstützung von der Maschine';

// --- Aufwärmen ---------------------------------------------------------------

/// Die Füllung der Aufwärmzeile — **drei Zustände** (#40): gemacht, mit Art,
/// Minuten und — wo es sie gibt — der Strecke; übersprungen (eine gegebene
/// Antwort); nicht eingetragen (so kommt alles aus der Übernahme herein).
///
/// Der Text für „gemacht" kommt von der Stelle, an der die Erfassung ihn
/// führt ([gymAufwaermenZusammenfassung]); `null` bekommt dort keinen Text
/// und braucht hier einen — und er heißt **nicht** „übersprungen": Ein
/// erfundenes „übersprungen" behauptete eine Antwort, die niemand gegeben
/// hat.
String gymVerlaufAufwaermenText(WarmUp? aufwaermen) => switch (aufwaermen) {
  null => 'nicht eingetragen',
  WarmUpSkipped() => 'übersprungen',
  WarmUpDone() => gymAufwaermenZusammenfassung(aufwaermen)!,
};

/// Die Notiz der Sitzung, mit ihrem Wort davor.
String gymVerlaufNotizText(String notiz) => 'Notiz: $notiz';
