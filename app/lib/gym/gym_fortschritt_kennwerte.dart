// Was die beiden Kacheln und die Startstufe aus dem Verlauf machen (#93) —
// reine Funktionen, ohne Widget.
//
// **Die Kacheln nennen das Ende der Linie, die gerade gezeigt wird**
// (`docs/SPEC.md` 4.4: „Die Kacheln nahmen den unverdichteten letzten
// Punkt, während die Linie verdichtet war — beide sprachen über
// verschiedene Werte."). Deshalb rechnet diese Datei **nicht selbst**
// verdichtend, sondern ruft dieselbe Funktion wie das Diagramm
// (`diagrammPunkte` mit derselben Art): Zwei Fassungen derselben
// Verdichtung liefen beim nächsten Umbau auseinander.
import 'package:trainings_core/trainings_core.dart';

import '../design/zeitdiagramm_fenster.dart' show monateZwischen;
import '../shell/diagramm_zeitraum.dart';

/// Die Stufen der Leiste: `W M 6M J`, kein `T` (Spec 3.3).
const gymFortschrittStufen = [
  DiagrammStufe.woche,
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// Die Höchstgewicht-Reihe in der Form, die das Diagramm nimmt: rohe
/// Tageswerte, **nicht verdichtet**.
List<({DateTime tag, double wert})> hoechstReihe(List<ProgressPoint> reihe) => [
  for (final p in reihe) (tag: p.day, wert: p.top),
];

/// Die 1RM-Reihe: nur Tage, an denen es eines gibt. **Eine Lücke fehlt, sie
/// steht nicht mit 0 da.**
List<({DateTime tag, double wert})> einRmReihe(List<ProgressPoint> reihe) => [
  for (final p in reihe)
    if (p.oneRepMax != null) (tag: p.day, wert: p.oneRepMax!),
];

/// Die Startstufe richtet sich nach dem Verlauf (`docs/SPEC.md` 4.4, Spec
/// 5.3): unter drei Kalendermonaten `M` — je Training ein Punkt —, sonst `6M`.
/// Nie `W` und nie `J` beim Aufschlagen.
///
/// „Kalendermonate Verlauf" heißt [monateZwischen] des ersten und des
/// letzten Trainingstags: Januar bis März sind zwei, Dezember bis März drei.
/// **Dies widerspricht der allgemeinen Regel „immer das kleinste zuerst"**
/// (27.10.2026), gilt hier aber als die speziellere und ältere Entscheidung
/// (26.10.2026) — offene Frage 1 der Spec, die Tim entscheidet.
DiagrammStufe gymFortschrittStartStufe(List<ProgressPoint> reihe) {
  if (reihe.length < 2) return DiagrammStufe.monat;
  return monateZwischen(reihe.first.day, reihe.last.day) < 3
      ? DiagrammStufe.monat
      : DiagrammStufe.halbjahr;
}

/// Die beiden Kennzahlen in einer Stufe: das Ende der gezeigten Linie.
/// `null` heißt „kein Wert" — **nie `0`**.
typedef GymFortschrittKennwerte = ({double? hoechst, double? einRm});

/// Das jüngste Ende der Linien in [stufe]: bei `W` und `M` der jüngste
/// Trainingstag, ab `6M` das Maximum des jüngsten Monats.
GymFortschrittKennwerte gymFortschrittKennwerte(
  List<ProgressPoint> reihe,
  DiagrammStufe stufe,
) {
  double? ende(List<({DateTime tag, double wert})> werte) {
    if (werte.isEmpty) return null;
    final punkte = diagrammPunkte(
      werte: werte,
      stufe: stufe,
      verdichtung: ChartAggregation.max,
    );
    return punkte.isEmpty ? null : punkte.last.wert;
  }

  return (hoechst: ende(hoechstReihe(reihe)), einRm: ende(einRmReihe(reihe)));
}

/// Für wie viele Übungen mit Verlauf der Vorschlag auf **Steigern** steht
/// ([Increase], bei Zeitübungen [IncreaseTime]) — der Wert der Zeile
/// „Fortschritt pro Übung" in der Gym-Übersicht. `null` bei **null**: Eine
/// `0` behauptete, nachgesehen worden und nichts zu steigern (`CLAUDE.md`).
///
/// [verlauf] ist die Form, die [Progression.suggest] erwartet (Übungs-ID →
/// Satzlisten, neueste Sitzung zuerst). Übungen, die der Katalog nicht kennt,
/// und Schlüssel ohne Sätze zählen nicht.
int? gymFortschrittSteigernAnzahl(
  Map<String, List<List<CompletedSet>>> verlauf,
) {
  var anzahl = 0;
  for (final eintrag in verlauf.entries) {
    final uebung = ExerciseLibrary.byId(eintrag.key);
    if (uebung == null || eintrag.value.isEmpty) continue;
    final vorschlag = Progression.suggest(uebung, eintrag.value);
    if (vorschlag is Increase || vorschlag is IncreaseTime) anzahl++;
  }
  return anzahl == 0 ? null : anzahl;
}
