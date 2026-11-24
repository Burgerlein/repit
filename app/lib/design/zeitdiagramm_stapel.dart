/// Die Rechnung hinter einem **gestapelten** Balken des Diagramm-Bauteils:
/// Teile auf denselben Platz zusammenfassen und die Höhe eines Balkens
/// danach aufteilen.
///
/// **Warum eine eigene Datei.** Dasselbe Argument wie bei
/// `zeitdiagramm_fenster.dart`: Das Zeichnen liegt getrennt, der Zustand
/// auch, und eine Rechnung, die weder Widget noch Strich ist, gehört in
/// keines von beiden. Hier steht sie ohne Pixelvergleich prüfbar
/// (`zeitdiagramm_stapel_test.dart`).
///
/// **Warum nicht in den Kern** (`Packages/trainings_core/`): Das hier ist
/// Zeichenarithmetik — wie eine Fläche in Teile zerfällt. Keine Formel aus
/// `docs/SPEC.md`. Im Kern wäre sie eine Rechnung ohne Fachgehalt;
/// derselbe Grund, aus dem `Fensterstand` dort auch nicht liegt.
///
/// **Die Teile kommen in der Einheit der Reihe herein, nicht als Prozent.**
/// Minuten lassen sich über einen Monat aufsummieren, Anteile nicht: Ein
/// Monat mit drei kurzen und einer langen Nacht wöge sonst falsch. Der
/// Anteil fällt beim Normieren in [stapelGrenzen] ab, ganz am Ende.
library;

/// Die **Oberkanten** der Stapelteile auf einem Balken der Höhe 1 — von
/// unten nach oben, kumuliert und auf die Summe der Teile normiert.
///
/// Die Höhe eines Balkens bleibt sein Messwert; die Teile teilen diese
/// Höhe anteilig (#504). Höhe = Anteil verlöre die Dauer.
///
/// **Die oberste Grenze ist genau `1`**, nicht `0,999…`: Über die Summe
/// gerechnet bliebe sonst oben ein Haarspalt offen, und bei
/// Rundungsfehlern in die andere Richtung ragte der oberste Teil über den
/// Balken hinaus.
///
/// **Ohne etwas zu teilen gibt es keinen Stapel.** Eine leere Liste und
/// eine Liste aus lauter Nullen geben beide `[]` zurück — der Balken steht
/// dann einfarbig da. Eine erfundene Gleichverteilung wäre schlimmer als
/// keine (`CLAUDE.md`, Fehler `01`): Ältere Uhren und das iPhone melden
/// Schlaf ohne Phasenangabe, und daraus ist kein Tiefschlafanteil zu
/// gewinnen.
///
/// Negative Teile zählen als nichts. Es gibt sie nicht — käme eine, dürfte
/// sie den Stapel aber nicht rückwärts laufen lassen.
List<double> stapelGrenzen(List<double> teile) {
  var summe = 0.0;
  for (final teil in teile) {
    if (teil > 0) summe += teil;
  }
  if (summe <= 0) return const [];

  final grenzen = List<double>.filled(teile.length, 0);
  var gelaufen = 0.0;
  for (var i = 0; i < teile.length; i++) {
    if (teile[i] > 0) gelaufen += teile[i];
    grenzen[i] = gelaufen / summe;
  }
  // Der letzte Teil endet an der Oberkante, nicht eine Rundung darunter.
  grenzen[grenzen.length - 1] = 1;
  return grenzen;
}

/// Teile, die auf **denselben Platz** fallen, elementweise aufsummiert —
/// nach Platz aufsteigend.
///
/// Bei `W` und `M` ist ein Platz ein Kalendertag und trifft genau einen
/// Messwert; ab `6M` ist er ein Kalendermonat, und dann laufen hier alle
/// Tage des Monats zusammen. **Gepoolt, nicht gemittelt:** Der Anteil ist
/// danach der Monatsschnitt, gewichtet mit den tatsächlichen Teilen, und
/// ein kurzer Tag wiegt weniger als ein langer.
///
/// **Dasselbe Verfahren wie `SchlafStatistik.anteile` — aber nicht
/// dieselbe Zahl.** Dort wird ebenfalls gepoolt, über eine andere Menge:
/// Nächte ohne Phasendaten fallen dort ganz heraus, und `awake` zählt in
/// den Nenner. Wer die beiden Zahlen nebeneinander hält, bekommt
/// verschiedene Prozente; die Begründung steht bei
/// `schlafVerlaufPhasen`.
///
/// Verschieden lange Listen werden auf die längste aufgefüllt: Eine Nacht
/// ohne REM-Abschnitt trägt dort nichts bei, verschiebt die übrigen Teile
/// aber nicht.
///
/// Aufsteigend sortiert, damit der Maler eine feste Reihenfolge sieht —
/// eine zufällige machte jeden Vergleich unlesbar.
List<({int platz, List<double> teile})> stapelSummen(
  List<({int platz, List<double> teile})> roh,
) {
  if (roh.isEmpty) return const [];

  final summen = <int, List<double>>{};
  for (final eintrag in roh) {
    final bisher = summen[eintrag.platz];
    if (bisher == null) {
      summen[eintrag.platz] = [...eintrag.teile];
      continue;
    }
    while (bisher.length < eintrag.teile.length) {
      bisher.add(0);
    }
    for (var i = 0; i < eintrag.teile.length; i++) {
      bisher[i] += eintrag.teile[i];
    }
  }

  final plaetze = summen.keys.toList()..sort();
  return [
    for (final platz in plaetze)
      (platz: platz, teile: List<double>.unmodifiable(summen[platz]!)),
  ];
}
