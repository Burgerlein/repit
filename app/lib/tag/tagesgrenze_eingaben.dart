// Die Eingaben der Tagesgrenze aus Apple Health (#454 unter #375): reine
// Funktionen, die Health-Werte in die Werttypen des Kerns übersetzen.
//
// API und Vertrag sind durch `app/test/tag/tagesgrenze_eingaben_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`). Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitt
// „Eingaben aus Health".
//
// **Warum nicht im Kern:** `SleepNight`, `QuantitySample` und
// `WorkoutSample` sind Transporttypen des Kanals und liegen in
// `health_types.dart`. Der Kern kennt sie nicht und trägt nur die Rechnung.
//
// Alle Zeitpunkte gehen als UTC hinaus: Der Kanal liefert Ortszeiten
// (`fromMillisecondsSinceEpoch`), und die Werttypen des Kerns vergleichen
// `DateTime` mit `==`, das `isUtc` mitprüft.
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import '../health/health_types.dart';

/// Die Hauptnacht [n] als [GemeldeteNacht] (V4).
///
/// Beginn ist der Beginn des ersten Abschnitts, der nicht `awake` ist, Ende
/// das Ende des letzten solchen; Schlaf ist die Summe ihrer Dauern.
/// `unspecified` zählt als Schlaf. Ein Wachabschnitt mitten in der Nacht
/// zählt nicht zum Schlaf, verschiebt aber weder Beginn noch Ende.
/// Nickerchen (`SleepNight.naps`) zählen nicht.
///
/// `null`, wenn die Nacht keinen Schlafabschnitt hat — eine Nacht ohne
/// Schlaf ist keine Nacht, und eine erfundene stieße die Tagesgrenze an.
GemeldeteNacht? nachtAus(SleepNight n) {
  final schlaf = [
    for (final abschnitt in n.session.segments)
      if (abschnitt.stage != SleepStage.awake) abschnitt,
  ];
  if (schlaf.isEmpty) return null;

  var beginn = schlaf.first.start;
  var ende = schlaf.first.end;
  var dauer = Duration.zero;
  for (final abschnitt in schlaf) {
    if (abschnitt.start.isBefore(beginn)) beginn = abschnitt.start;
    if (abschnitt.end.isAfter(ende)) ende = abschnitt.end;
    dauer += abschnitt.end.difference(abschnitt.start);
  }
  return GemeldeteNacht(
    beginn: beginn.toUtc(),
    ende: ende.toUtc(),
    schlaf: dauer,
  );
}

/// Ein Beleg je Stunde mit mindestens [wachSchritteJeStunde] Schritten
/// (V1), am **Beginn** der Stunde, Quelle `schritte`. Ein Zeitpunkt, keine
/// Spanne: Wann in der Stunde Tim gelaufen ist, verrät die Summe nicht.
List<Wachbeleg> belegeAusSchritten(List<QuantitySample> stunden) => [
  for (final stunde in stunden)
    if (stunde.value >= wachSchritteJeStunde)
      Wachbeleg(von: stunde.date.toUtc(), quelle: WachQuelle.schritte),
];

/// Ein Beleg je Training (V2): eine Spanne von `start` bis
/// `start + minutes`, sekundengenau, Quelle `training`.
List<Wachbeleg> belegeAusTrainings(List<WorkoutSample> trainings) => [
  for (final training in trainings)
    Wachbeleg(
      von: training.start.toUtc(),
      bis: training.start.toUtc().add(
        Duration(
          microseconds: (training.minutes * Duration.microsecondsPerMinute)
              .round(),
        ),
      ),
      quelle: WachQuelle.training,
    ),
];
