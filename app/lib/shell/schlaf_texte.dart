// Die Wortlaute und Zahlenformate des Schlaf-Schirms (#92): der Satz bei
// fehlenden Health-Daten, Dauer, Uhrzeit, Nachtfenster und Bewertung.
//
// Eigene Datei, weil alle vier Abschnittsdateien sie brauchen. Stünden sie
// weiter in `schlaf_abschnitte.dart`, müssten `schlaf_verlauf.dart`,
// `schlaf_spannen.dart` und `schlaf_naechte.dart` genau die Datei
// importieren, die sie selbst weiterexportiert — ein Ring, der nichts
// erklärt.
//
// **`schlaf_abschnitte.dart` exportiert diese Datei weiter.** Die
// festgelegte API bleibt `import '…/shell/schlaf_abschnitte.dart'`; keine
// fremde Importzeile ändert sich.
//
// Herausgelöst am 28.10.2026 für #153. Tim hat „aufteilen" verlangt; wo
// der Schnitt liegt, hat der umsetzende Agent entschieden.
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import 'schlaf_zustand.dart';

/// Der Satz, der bei fehlenden Health-Daten steht.
///
/// **Beide Möglichkeiten, immer.** Apple verrät den Lesestatus nicht: „nichts
/// aufgezeichnet" und „nicht freigegeben" sind von außen nicht zu
/// unterscheiden (`CLAUDE.md`).
const String schlafOhneDaten =
    'Nicht aufgezeichnet oder nicht freigegeben — in den '
    'Health-Einstellungen prüfen.';

/// „6:45 h".
String schlafDauerText(double minuten) => '${_stundenUndMinuten(minuten)} h';

/// „6:00–8:00 h" — zwei Dauern als Spanne, mit **einer** Einheit am Ende.
///
/// Sind beide Enden gleich, bleibt eine Dauer stehen: „7:00–7:00 h" sähe
/// aus wie ein Fehler, nicht wie eine einzige Nacht.
String schlafSpanneText(double vonMinuten, double bisMinuten) {
  final von = _stundenUndMinuten(vonMinuten);
  final bis = _stundenUndMinuten(bisMinuten);
  return von == bis ? '$von h' : '$von–$bis h';
}

/// „6:45" — Dauer und Spanne setzen dieselben Ziffern, also stehen sie an
/// einer Stelle.
String _stundenUndMinuten(double minuten) {
  final gesamt = minuten.round();
  final stunden = gesamt ~/ Duration.minutesPerHour;
  final rest = gesamt % Duration.minutesPerHour;
  return '$stunden:${rest.toString().padLeft(2, '0')}';
}

/// Eine Uhrzeit der 18-Uhr-Skala, über [Format] gesetzt — nie über
/// `DateFormat` ohne feste Sprache (`CLAUDE.md`). `null` wird zum
/// Gedankenstrich, nicht zu 0:00.
String schlafUhrzeitText(double? abendminuten) {
  if (abendminuten == null) return '—';
  final (:stunde, :minute) = wanduhrAusAbendminuten(abendminuten);
  // Ein beliebiger Kalendertag als Träger: Gesetzt wird nur die Uhrzeit.
  return Format.uhrzeit(DateTime.utc(2000, 1, 1, stunde, minute));
}

/// Ein Zeitpunkt als Uhrzeit auf der **Berliner Wanduhr** — „23:07".
///
/// Die öffentliche Fassung dessen, was vor der Aufteilung die private
/// Hilfsfunktion `_berlin` war: Drei Abschnitte setzen damit eine Uhrzeit,
/// und sie liegen seit #153 in drei Dateien. Herausgegeben wird der fertige
/// Text, nicht der Träger-`DateTime` — der ist ein Rechenschritt und gehört
/// niemandem außerhalb dieser Datei.
String schlafZeitText(DateTime zeitpunkt) => Format.uhrzeit(_berlin(zeitpunkt));

/// „23:00–06:00".
String schlafFensterText(DateTime? von, DateTime? bis) {
  if (von == null || bis == null) return '—';
  return '${schlafZeitText(von)}–${schlafZeitText(bis)}';
}

/// „23:10–06:15" aus zwei Uhrzeiten in **Minuten nach Mitternacht** — die
/// Form, in der eine von Hand eingetragene Nacht ihre Zeiten trägt (#131).
///
/// `null` wird zum Gedankenstrich, nicht zu „0:00–0:00": Die Fassung „nur
/// Dauer" hat kein Fenster, und eine erfundene Uhrzeit sähe aus wie eine
/// eingetippte.
String schlafFensterTextAusMinuten(int? von, int? bis) {
  if (von == null || bis == null) return '—';
  return '${_uhrzeitAusMinuten(von)}–${_uhrzeitAusMinuten(bis)}';
}

/// Eine Uhrzeit in Minuten nach Mitternacht, über [Format] gesetzt.
String _uhrzeitAusMinuten(int minuten) => Format.uhrzeit(
  // Ein beliebiger Kalendertag als Träger: Gesetzt wird nur die Uhrzeit.
  DateTime.utc(
    2000,
    1,
    1,
    minuten ~/ Duration.minutesPerHour,
    minuten % Duration.minutesPerHour,
  ),
);

/// Ein Zeitpunkt auf der Berliner Wanduhr, als Träger für [Format].
DateTime _berlin(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  return DateTime.utc(2000, 1, 1, stunde, minute);
}

/// „sehr gut" · „gut" · „okay" · „niedrig".
String schlafBewertungText(SleepRating bewertung) => switch (bewertung) {
  SleepRating.veryGood => 'sehr gut',
  SleepRating.good => 'gut',
  SleepRating.okay => 'okay',
  SleepRating.low => 'niedrig',
};
