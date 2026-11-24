// Die Zeitrechnungen einer einzelnen Nacht (#92) — Schlafminuten, das
// Fenster über alle Abschnitte und die Rückrichtung von der 18-Uhr-Skala
// auf die Wanduhr. Reine Funktionen, kein Provider, kein Widget; den
// Zustand darüber baut `schlaf_zustand.dart`.
//
// **Eigene Datei, weil alle anderen sie brauchen.** Blieben diese vier in
// der Fassade, importierten die herausgelösten Dateien genau die Datei,
// die sie weiterexportiert — derselbe Grund, aus dem `schlaf_texte.dart`
// neben `schlaf_abschnitte.dart` liegt.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:trainings_core/trainings_core.dart';

import '../health/health_types.dart';

/// Die Minuten zwischen zwei Zeitpunkten, als Bruch und nicht gerundet.
///
/// Öffentlich seit #158: Schlafminuten, Phasenanteile und Nachtlagen zählen
/// alle hiermit, und die drei liegen nun in drei Dateien.
double schlafMinutenZwischen(DateTime von, DateTime bis) =>
    bis.difference(von).inMicroseconds / Duration.microsecondsPerMinute;

/// Schlafminuten einer Phase — **jeder Abschnitt außer `awake`**, auch
/// `unspecified`: Ältere Uhren melden Schlaf ohne Phasenangabe, und den als
/// „nicht geschlafen" zu lesen wäre falsch.
double schlafMinutenVon(SleepSession phase) {
  var summe = 0.0;
  for (final abschnitt in phase.segments) {
    if (abschnitt.stage == SleepStage.awake) continue;
    summe += schlafMinutenZwischen(abschnitt.start, abschnitt.end);
  }
  return summe;
}

/// Das Fenster über **alle** Abschnitte, auch die wachen — für die Dauer
/// wäre das falsch, für das Bild ist es richtig (siehe
/// `HypnogrammGeometrie`).
(DateTime?, DateTime?) schlafFensterVon(SleepSession phase) {
  if (phase.segments.isEmpty) return (null, null);
  var von = phase.segments.first.start;
  var bis = phase.segments.first.end;
  for (final abschnitt in phase.segments) {
    if (abschnitt.start.isBefore(von)) von = abschnitt.start;
    if (abschnitt.end.isAfter(bis)) bis = abschnitt.end;
  }
  return (von, bis);
}

/// Eine Uhrzeit der 18-Uhr-Skala als Wanduhrzeit.
///
/// Die Rückrichtung zu [EveningClock.minutesSinceEvening]: 0 ist 18:00, 420
/// ist 01:00, −10 ist 17:50.
({int stunde, int minute}) wanduhrAusAbendminuten(double minuten) {
  const tag = Duration.minutesPerDay;
  final roh = EveningClock.eveningHour * Duration.minutesPerHour + minuten;
  var imTag = roh.round() % tag;
  if (imTag < 0) imTag += tag;
  return (
    stunde: imTag ~/ Duration.minutesPerHour,
    minute: imTag % Duration.minutesPerHour,
  );
}
