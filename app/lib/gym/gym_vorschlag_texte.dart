// Die Sätze eines Steigerungsvorschlags (#77) — Dart-Entsprechung von
// `Sources/Features/Gym/SuggestionText.swift`.
//
// **Warum an genau einer Stelle:** Der Kern gibt mit [Suggestion] nur
// Zahlen und Fälle heraus. Die Unterstützungs-Fälle („30 kg
// Unterstützung") sind der Grund, warum es diese Datei in Swift gibt —
// ohne den Zusatz liest sich „zurück auf 30 kg" als Gewicht und damit als
// das Gegenteil von leichter. Zwei Ansichten, die das je für sich
// formulieren, laufen beim ersten Wortlautwechsel auseinander.
//
// **Ein Zielgewicht ist ein Vorschlag, keine Messung** (`CLAUDE.md`,
// „Keine Diagnosen"). Woher die Zahlen kommen, sagt der Hinweis am Fuß
// des Gym-Schirms; hier steht nur die Zahl.
//
// Portiert sind die Formen, die der Gym-Übersichtsschirm (#77) braucht —
// Gewicht, Kurzfassung, Zielgewicht und Ton — und die beiden des
// Erfassen-Schirms (#78): die Zeile über den Satzzeilen
// ([vorschlagKompaktText], Swifts `compact`) und ihr Zeichen
// ([vorschlagSymbol]). `full` gehört zum Fortschritts-Schirm (#93) und
// wandert mit ihm mit — hier wäre sie heute toter Text.
import 'package:flutter/widgets.dart' show Color;
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/zahlen.dart';

/// „55 kg" oder „30 kg Unterstützung".
///
/// **Negative Werte sind Unterstützung von der Maschine**, kein negatives
/// Gewicht — aber nur bei einer Übung, die das kann
/// ([Exercise.allowsAssist]). Bei jeder anderen bliebe ein negativer Wert
/// ein Rechenfehler, und ihn als „Unterstützung" zu beschriften machte ihn
/// unsichtbar.
String vorschlagGewichtText(double wert, Exercise uebung) {
  final zahl = gymZahlText(wert.abs());
  return wert < 0 && uebung.allowsAssist
      ? '$zahl kg Unterstützung'
      : '$zahl kg';
}

/// Die Kurzfassung: „Nächstes Mal 62,5 kg, Ziel 6 Wiederholungen."
///
/// [hatVerlauf] unterscheidet bei Zeitübungen das erste Mal vom Steigern:
/// [IncreaseTime] entsteht in beiden Fällen, und „auf 30 Sekunden
/// steigern" wäre beim ersten Mal eine Behauptung über einen Verlauf, den
/// es nicht gibt.
///
/// **Ein vorhandener Schlüssel heißt nicht, dass auch Sätze darunter
/// stehen** — der Aufrufer prüft auf „nicht leer", nicht auf „vorhanden"
/// (so macht es `GymPlanPreview.line`).
String vorschlagKurzText(
  Suggestion vorschlag,
  Exercise uebung, {
  required bool hatVerlauf,
}) => switch (vorschlag) {
  FirstTime(:final targetReps) =>
    'Noch kein Verlauf — taste dich an $targetReps bis ${uebung.repHigh} '
        'saubere Wiederholungen heran.',
  Increase(:final toWeight, :final targetReps) =>
    'Nächstes Mal ${vorschlagGewichtText(toWeight, uebung)}, '
        'Ziel $targetReps Wiederholungen.',
  Hold(:final atWeight, :final targetReps) =>
    'Nächstes Mal ${vorschlagGewichtText(atWeight, uebung)} halten, '
        'Ziel $targetReps Wiederholungen.',
  Deload(:final toWeight, :final targetReps) =>
    toWeight < 0 && uebung.allowsAssist
        ? 'Nächstes Mal mehr Hilfe: '
              '${vorschlagGewichtText(toWeight, uebung)}, Ziel $targetReps.'
        : 'Nächstes Mal zurück auf '
              '${vorschlagGewichtText(toWeight, uebung)}, Ziel $targetReps.',
  IncreaseTime(:final toSeconds) =>
    hatVerlauf
        ? 'Nächstes Mal $toSeconds Sekunden.'
        : 'Erstes Mal — $toSeconds Sekunden.',
  HarderVariant() => 'Obergrenze erreicht — such dir eine schwerere Variante.',
};

/// Nur das Zielgewicht, für die Übungsvorschau der Fokus-Karte: „62,5 kg",
/// bei einer Zeitübung „45 s".
///
/// **Ohne Verlauf steht hier „—" und nicht „0 kg".** [FirstTime] heißt,
/// dass es kein Gewicht vorzuschlagen gibt; eine Null behauptete eine
/// Zahl, die niemand gemessen hat — Fehler `01` in neuer Verpackung
/// (`CLAUDE.md`). Dasselbe gilt für [HarderVariant]: Dort ist die Antwort
/// eine andere Übung, kein Gewicht.
String vorschlagZielgewichtText(Suggestion vorschlag, Exercise uebung) =>
    switch (vorschlag) {
      FirstTime() => '—',
      Increase(:final toWeight) => vorschlagGewichtText(toWeight, uebung),
      Hold(:final atWeight) => vorschlagGewichtText(atWeight, uebung),
      Deload(:final toWeight) => vorschlagGewichtText(toWeight, uebung),
      IncreaseTime(:final toSeconds) => '$toSeconds s',
      HarderVariant() => '—',
    };

/// Der Ton des Zielgewichts — grün beim Steigern, gelb beim Reduzieren,
/// sonst `null` für die normale Textfarbe.
///
/// `null` heißt „kein eigener Ton", nicht „grau": Welche Farbe die
/// Ansicht dann setzt, entscheidet sie selbst (in Swift `?? Palette.ink`).
///
/// **Farbe allein trägt die Aussage nicht.** Die Swift-Vorlage stellt
/// deshalb ein Symbol daneben (`SuggestionText.symbol`); das wandert mit
/// dem Fortschritts-Schirm (#93) mit, der es als Erster braucht.
Color? vorschlagTon(Suggestion vorschlag, {required bool hatVerlauf}) =>
    switch (vorschlag) {
      Increase() => Palette.ok,
      IncreaseTime() => hatVerlauf ? Palette.ok : null,
      Deload() || HarderVariant() => Palette.warn,
      Hold() || FirstTime() => null,
    };

/// Die Zeile über den Satzzeilen des Erfassen-Schirms (#78): was zu tun
/// ist, ohne Begründung — beim Training will man die Zahl, nicht die
/// Herleitung. Swifts `SuggestionText.compact`, wörtlich.
///
/// **Nicht [vorschlagKurzText]:** Das ist die Fassung der Fortschritts-
/// Auswertung („Nächstes Mal …"), diese hier die der Eingabe („Steigern
/// auf …"). Zwei Sätze für zwei Orte, beide an dieser einen Stelle.
///
/// „Unterstützt" heißt hier **das Vorzeichen**, nicht
/// [Exercise.allowsAssist] allein: `toWeight < 0 && uebung.allowsAssist`.
/// Ohne den Zusatz liest sich „Zurück auf 30 kg" bei einer unterstützten
/// Übung als das Gegenteil von leichter (Spec Abschnitt 6.1).
///
/// [hatVerlauf] unterscheidet bei Zeitübungen das erste Mal vom Steigern
/// — wie bei [vorschlagKurzText].
String vorschlagKompaktText(
  Suggestion vorschlag,
  Exercise uebung, {
  required bool hatVerlauf,
}) => switch (vorschlag) {
  FirstTime(:final targetReps) =>
    'Erstes Mal — taste dich an $targetReps bis ${uebung.repHigh} '
        'Wiederholungen heran.',
  Increase(:final toWeight, :final targetReps) =>
    toWeight < 0 && uebung.allowsAssist
        ? 'Weniger Unterstützung: '
              '${vorschlagGewichtText(toWeight, uebung)}, Ziel $targetReps.'
        : 'Steigern auf ${vorschlagGewichtText(toWeight, uebung)}, '
              'Ziel $targetReps Wiederholungen.',
  Hold(:final atWeight, :final targetReps) =>
    'Halten bei ${vorschlagGewichtText(atWeight, uebung)} — '
        'eine Wiederholung mehr je Satz, Ziel $targetReps.',
  Deload(:final toWeight, :final targetReps) =>
    toWeight < 0 && uebung.allowsAssist
        ? 'Mehr Hilfe nehmen: '
              '${vorschlagGewichtText(toWeight, uebung)}, Ziel $targetReps.'
        : 'Zurück auf ${vorschlagGewichtText(toWeight, uebung)}, '
              'Ziel $targetReps.',
  IncreaseTime(:final toSeconds) =>
    hatVerlauf
        ? 'Auf $toSeconds Sekunden steigern.'
        : 'Erstes Mal — $toSeconds Sekunden je Seite.',
  HarderVariant() => 'Obergrenze erreicht — such dir eine schwerere Variante.',
};

/// Das Zeichen zum Ton der Vorschlagszeile — **Farbe allein trägt die
/// Aussage nicht** (Spec Abschnitt 6.1, `tipRow` im Entwurf).
///
/// `↑` beim Steigern, `↓` beim Reduzieren, `•` sonst. **[HarderVariant]
/// bekommt `!`**, obwohl sein Ton rot ist: Ein `↓` neben „such dir eine
/// schwerere Variante" läse sich als Anweisung, leichter zu werden. Die
/// Spec ordnet jedem Ton ein Zeichen zu und nennt für Rot nur `↓`; das
/// Ausnahmezeichen steht als offene Frage im Bericht, nicht als
/// Entscheidung.
String vorschlagSymbol(Suggestion vorschlag, {required bool hatVerlauf}) =>
    switch (vorschlag) {
      Increase() => '↑',
      IncreaseTime() => hatVerlauf ? '↑' : '•',
      Deload() => '↓',
      HarderVariant() => '!',
      Hold() || FirstTime() => '•',
    };

/// „62,5" und „30" — höchstens eine Nachkommastelle, und die nur, wenn sie
/// etwas sagt. **Die eine Stelle für jedes Gewicht auf dem Gym-Schirm**
/// (Spec 6.2): Karte, Vollbild, Zusammenfassung und Vorschlagszeile
/// formatieren hier, damit „2,5" nicht an der einen Stelle als „2.5"
/// erscheint.
///
/// Die Entsprechung zu Swifts `.number.precision(.fractionLength(0...1))`.
/// Gerundet wird **vor** dem Vergleich auf eine ganze Zahl, sonst stünde
/// bei 29,97 kg „30,0 kg" statt „30 kg".
String gymZahlText(double wert) {
  final gerundet = (wert * 10).roundToDouble() / 10;
  final ganz = gerundet == gerundet.roundToDouble();
  return formatNumber(gerundet, nachkommastellen: ganz ? 0 : 1);
}
