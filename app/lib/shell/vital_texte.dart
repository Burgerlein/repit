/// Die Nutzertexte der vier Erholungswerte — Name, Wert mit Einheit und
/// der Normalwert darunter.
///
/// **Eine Stelle, zwei Schirme** (#501). Home und der Schirm
/// `erholung-werte` beschrifteten dieselbe Metrik bis zum 16.11.2026
/// verschieden: Hier „Atmung" und „11,8", dort „Atemfrequenz" und
/// „11,8/min". Tim hat am 13.11.2026 entschieden, dass Home aussieht wie
/// die alte App — und die hat dafür genau **eine** Tabelle
/// (`RecoveryWording.name(_:)` und `text(_:_:)` in
/// `Sources/Features/Recovery/RecoveryStatusCard.swift`). Diese Datei ist
/// ihre Dart-Entsprechung.
///
/// **Sie gehört in die Ansichtsschicht, nicht in den Kern.**
/// `trainings_core` trägt keine Nutzertexte (`CLAUDE.md`); der Kern
/// liefert [RecoveryMetric] und die Zahlen, die Beschriftung entsteht
/// hier.
///
/// **Die Schwelle hinter dem `·` steht hier nicht.** Sie ist der lange
/// Teil der Bildunterschrift und gehört auf den Erholungs-Schirm, wo
/// jeder Wert eine eigene Zeile über die volle Breite hat
/// (`_bildunterschrift` in `erholung_werte_zustand.dart`). Auf Home
/// stehen vier Werte nebeneinander, und dort wurde derselbe Satz nach
/// „· Si…" abgeschnitten — eine gekappte Schwelle ist keine Auskunft
/// (`shortCaption` in der alten App).
library;

import 'package:trainings_core/trainings_core.dart';

import 'erholung_abschnitte.dart' show kommazahl, stundenText;

/// „Schlaf", „Ruhepuls", „HRV", „Atemfrequenz".
String vitalName(RecoveryMetric metrik) => switch (metrik) {
  RecoveryMetric.sleep => 'Schlaf',
  RecoveryMetric.restingHeartRate => 'Ruhepuls',
  RecoveryMetric.hrv => 'HRV',
  RecoveryMetric.respiratoryRate => 'Atemfrequenz',
};

/// Der Wert **mit seiner Einheit**: „8:38 h", „55 bpm", „50 ms",
/// „11,8/min".
///
/// Deutsch formatiert, über die gemeinsamen Helfer — nie mit Punkt als
/// Dezimaltrenner.
String vitalWertText(RecoveryMetric metrik, double wert) => switch (metrik) {
  RecoveryMetric.sleep => stundenText(wert),
  RecoveryMetric.restingHeartRate => '${wert.round()} bpm',
  RecoveryMetric.hrv => '${wert.round()} ms',
  RecoveryMetric.respiratoryRate => '${kommazahl(wert)}/min',
};

/// „Normal 6:40 h" — der Normalwert unter dem Messwert.
///
/// **Durchgehend „Normal", nicht mal „Ø" und mal „Median".** Es ist
/// derselbe Median für alle vier; zwei Wörter für dieselbe Rechnung
/// behaupteten einen Unterschied, den es nicht gibt.
String vitalNormalText(RecoveryMetric metrik, double median) =>
    'Normal ${vitalWertText(metrik, median)}';

/// Der heutige Messwert dieser Metrik — `null`, wenn er fehlt.
double? vitalMesswert(RecoveryMetric metrik, RecoveryReading messwerte) =>
    switch (metrik) {
      RecoveryMetric.sleep => messwerte.sleepHours,
      RecoveryMetric.restingHeartRate => messwerte.restingHeartRate,
      RecoveryMetric.hrv => messwerte.hrv,
      RecoveryMetric.respiratoryRate => messwerte.respiratoryRate,
    };

/// Der Normalwert dieser Metrik — `null`, wenn zu wenige Messwerte für
/// einen Median vorliegen.
double? vitalMedian(RecoveryMetric metrik, RecoveryBaseline baseline) =>
    switch (metrik) {
      RecoveryMetric.sleep => baseline.sleepHours,
      RecoveryMetric.restingHeartRate => baseline.restingHeartRate,
      RecoveryMetric.hrv => baseline.hrv,
      RecoveryMetric.respiratoryRate => baseline.respiratoryRate,
    };
