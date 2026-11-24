/// **#504 — Die Rechnung hinter einem gestapelten Balken.**
///
/// Der Schlaf-Verlauf zeichnet seit dem 13.11.2026 wieder Balken, und jeder
/// Balken ist in sich nach Schlafphasen geteilt (Tim: „nur die Balken so
/// einfärben wie die Phasen, damit man sieht, wie die prozentual drin
/// waren"). Die Teilung selbst ist reine Arithmetik und steht deshalb in
/// eigenen Funktionen statt in einer `build`- oder `paint`-Methode — hier
/// ist sie ohne Pixelvergleich prüfbar.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/design/zeitdiagramm_stapel.dart
///
/// /// Die **Oberkanten** der Stapelteile auf einem Balken der Höhe 1 —
/// /// von unten nach oben, kumuliert und auf die Summe normiert.
/// List<double> stapelGrenzen(List<double> teile);
///
/// /// Teile, die auf denselben Platz fallen, elementweise aufsummiert —
/// /// nach Platz aufsteigend.
/// List<({int platz, List<double> teile})> stapelSummen(
///   List<({int platz, List<double> teile})> roh,
/// );
/// ```
///
/// ## Was hier geprüft wird
///
/// - **Normiert auf die Balkenhöhe.** Die Höhe eines Balkens bleibt die
///   Schlafdauer; die Phasen teilen diese Höhe anteilig (#504). Also ist
///   die letzte Grenze genau 1 — und zwar ohne Gleitkomma-Rest, sonst
///   bliebe oben ein Haarspalt offen oder der oberste Teil ragte hinaus.
/// - **Nichts zu teilen heißt kein Stapel.** Eine leere Liste und eine
///   Liste aus lauter Nullen geben beide `[]` zurück: Der Balken steht
///   dann einfarbig da. Eine erfundene Gleichverteilung wäre schlimmer als
///   keine (`CLAUDE.md`, Fehler `01`).
/// - **Summiert wird elementweise**, weil ab `6M` ein Platz ein
///   Kalendermonat ist und die Anteile dort ein Monatsschnitt. Gezählt
///   werden die tatsächlichen Minuten je Phase; der Anteil fällt beim
///   Normieren ab. Ein Monat mit drei kurzen und einer langen Nacht wiegt
///   damit richtig.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:repit/design/zeitdiagramm_stapel.dart';

void main() {
  group('stapelGrenzen', () {
    test('teilt die Höhe 1 nach den Anteilen auf', () {
      expect(stapelGrenzen(const [3, 1]), [0.75, 1.0]);
    });

    test('die oberste Grenze ist genau 1', () {
      // 1/3 + 1/3 + 1/3 läuft über die Summe gerechnet auf 0,999… hinaus;
      // oben bliebe ein Haarspalt offen.
      final grenzen = stapelGrenzen(const [1, 1, 1]);
      expect(grenzen.last, 1.0);
      expect(grenzen.first, closeTo(1 / 3, 1e-12));
    });

    test('ein einziger Teil füllt den ganzen Balken', () {
      expect(stapelGrenzen(const [5]), [1.0]);
    });

    test('eine leere Liste ergibt keinen Stapel', () {
      expect(stapelGrenzen(const []), isEmpty);
    });

    test('lauter Nullen ergeben keinen Stapel', () {
      expect(
        stapelGrenzen(const [0, 0, 0]),
        isEmpty,
        reason:
            'ohne Phasendaten steht der Balken einfarbig da — eine '
            'erfundene Verteilung wäre schlimmer als keine (#504)',
      );
    });

    test('negative Teile zählen als nichts, nicht als Abzug', () {
      // Negative Minuten gibt es nicht; käme eine, dürfte sie den Stapel
      // nicht rückwärts laufen lassen.
      expect(stapelGrenzen(const [-1, 2, 2]), [0.0, 0.5, 1.0]);
    });

    test('ein Teil ohne Minuten bekommt keine Höhe', () {
      expect(stapelGrenzen(const [1, 0, 3]), [0.25, 0.25, 1.0]);
    });
  });

  group('stapelSummen', () {
    // **Platz und Teile einzeln verglichen, nicht der ganze Datensatz.**
    // Ein Record mit einem `List`-Feld vergleicht die Liste über ihre
    // Identität, nicht über ihren Inhalt — ein Vergleich gegen ein Literal
    // wäre nie wahr, auch bei richtiger Rechnung nicht.
    test('fasst gleiche Plätze elementweise zusammen', () {
      final raus = stapelSummen(const [
        (platz: 0, teile: [1.0, 2.0]),
        (platz: 0, teile: [3.0, 4.0]),
      ]);

      expect(raus.single.platz, 0);
      expect(raus.single.teile, [4.0, 6.0]);
    });

    test('verschieden lange Listen werden auf die längste aufgefüllt', () {
      final raus = stapelSummen(const [
        (platz: 2, teile: [1.0]),
        (platz: 2, teile: [1.0, 5.0, 2.0]),
      ]);

      expect(raus.single.platz, 2);
      expect(raus.single.teile, [2.0, 5.0, 2.0]);
    });

    test('gibt die Plätze aufsteigend zurück', () {
      expect(
        stapelSummen(const [
          (platz: 3, teile: [1.0]),
          (platz: -1, teile: [2.0]),
          (platz: 0, teile: [3.0]),
        ]).map((e) => e.platz),
        [-1, 0, 3],
        reason:
            'der Maler läuft die Liste einmal durch; eine zufällige '
            'Reihenfolge machte jeden Vergleich unlesbar',
      );
    });

    test('lässt getrennte Plätze getrennt', () {
      final raus = stapelSummen(const [
        (platz: 0, teile: [1.0, 1.0]),
        (platz: 1, teile: [2.0, 0.0]),
      ]);
      expect(raus.length, 2);
      expect(raus[1].teile, [2.0, 0.0]);
    });

    test('eine leere Eingabe ergibt eine leere Ausgabe', () {
      expect(stapelSummen(const []), isEmpty);
    });
  });
}
