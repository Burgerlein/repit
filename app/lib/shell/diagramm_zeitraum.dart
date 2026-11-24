/// Die Rechnung hinter jeder Zeitraumleiste eines Diagramms, mit den
/// deutschen Fachbegriffen, die die Oberfläche benutzt.
///
/// **Die Rechnung liegt im Kern, nicht hier.** Jede Zeile dieser Datei
/// reicht an `ChartBuckets` bzw. `BerlinCalendar` weiter; wer hier eine
/// Monats- oder Wochengrenze nachrechnet, baut die Doppelung wieder ein,
/// die Ticket #130 gerade aufgelöst hat.
///
/// ## Arbeitsteilung mit dem Kern
///
/// `diagrammPunkte` zieht einen Zeitpunkt mitten am Tag auf den
/// Tagesbeginn, `ChartBuckets.points` tut das **nicht**. Das ist kein
/// Widerspruch: Der Kern reicht `ChartSample.date` unverändert durch, weil
/// dort laut Spec bereits ein Stunden- oder Tagesbeginn steht. Diese
/// Funktion nimmt Tageswerte entgegen und ist der Aufrufer, der diese
/// Pflicht trägt. Der Kern rechnet, die Shell bereitet vor.
library;

import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

/// Die Stufen der Zeitraumleiste (Entwurfs-Spec
/// `2026-10-13-graphen-zeitraum-und-ablesen-design.md`, „Rastgrenzen je
/// Stufe"). `T` fehlt: Keiner der beiden Schirme hat Stundenwerte.
enum DiagrammStufe { woche, monat, halbjahr, jahr }

/// Ein gezeichneter Punkt.
///
/// Werttyp mit `==` und `hashCode`: Eine Liste von Punkten ist die
/// Abhängigkeit, aus der ein Diagramm gebaut wird. Ohne Gleichheit wäre
/// jede neu gebaute Liste ungleich der vorigen, und jedes Bild rechnete neu.
@immutable
class DiagrammPunkt {
  const DiagrammPunkt({
    required this.beginn,
    required this.wert,
    required this.tage,
  });

  /// Der Beginn des Abschnitts: bei `woche` und `monat` der Tagesbeginn,
  /// bei `halbjahr` und `jahr` der Berliner Monatserste.
  final DateTime beginn;

  final double wert;

  /// Wie viele **gemessene** Kalendertage hinter dem Punkt stecken.
  final int tage;

  @override
  bool operator ==(Object other) =>
      other is DiagrammPunkt &&
      other.beginn == beginn &&
      other.wert == wert &&
      other.tage == tage;

  @override
  int get hashCode => Object.hash(beginn, wert, tage);

  @override
  String toString() =>
      'DiagrammPunkt(beginn: $beginn, wert: $wert, tage: $tage)';
}

/// Die Startstufe ist die **kleinste** angebotene — Tims Entscheidung vom
/// 27.10.2026 („immer das kleinste zuerst"); vorher war es die erste in der
/// Liste.
///
/// „Kleinste" heißt: der niedrigste `index`, denn [DiagrammStufe] ist
/// aufsteigend deklariert (`woche, monat, halbjahr, jahr`). Verglichen wird
/// statt gezählt — eine doppelt angemeldete Stufe ist ein Versehen des
/// Schirms, kein Stimmrecht.
///
/// Eigene Funktion und keine Zeile im Widget: Das ist `#7`. In Swift steht
/// die Absicht als Kommentar und der Code tut etwas anderes — eine Absicht,
/// die niemand ausführen kann, ist keine. Als Funktion ist sie prüfbar, und
/// der Schirm kann sie nicht umgehen. Dass die Regel nicht mehr an der
/// Reihenfolge der Liste hängt, nimmt ihr die letzte stille Ausweiche.
///
/// Wirft bei leerer Liste: Ein Diagramm ohne Stufe hat keine Startstufe,
/// und still eine zu erfinden hieße, eine Leiste zu zeigen, die der Schirm
/// nicht angemeldet hat. `reduce` wirft von selbst, ohne eigene Prüfung.
DiagrammStufe startStufe(List<DiagrammStufe> stufen) =>
    stufen.reduce((a, b) => a.index <= b.index ? a : b);

/// Verdichtet Tageswerte zur Stufe — aufsteigend sortiert.
///
/// `woche` und `monat` reichen durch, `halbjahr` und `jahr` bilden je
/// Kalendermonat ein Mittel — oder mit [verdichtung] `max` das Maximum
/// (`docs/SPEC.md` 4.4: Kraftreihen). Lücken bleiben Lücken: Ein Monat ohne
/// Messung fehlt, und zwischen zwei Tagen wird nichts aufgefüllt.
///
/// **Die Art geht an `ChartBuckets` durch, hier wird nichts nachgerechnet.**
/// Vorgabe ist das Mittel, das Verhalten aller bisherigen Aufrufer.
///
/// Jeder Zeitpunkt wird vorher auf den Berliner Tagesbeginn gezogen. Ein
/// Diagramm, das seine x-Achse aus den Punkten baut, braucht gleich lange
/// Abstände — sonst steht ein Balken schief, weil der Messwert um 14:30
/// ankam.
List<DiagrammPunkt> diagrammPunkte({
  required List<({DateTime tag, double wert})> werte,
  required DiagrammStufe stufe,
  ChartAggregation verdichtung = ChartAggregation.mean,
}) {
  final punkte = ChartBuckets.points(
    samples: [
      for (final eintrag in werte)
        ChartSample(
          date: BerlinCalendar.startOfDay(eintrag.tag),
          value: eintrag.wert,
        ),
    ],
    range: _stufenBereich(stufe),
    aggregation: verdichtung,
  );

  return [
    for (final punkt in punkte)
      DiagrammPunkt(
        beginn: punkt.start,
        wert: punkt.value,
        tage: punkt.dayCount,
      ),
  ];
}

/// Rastet einen Zeitpunkt auf die Grenze seiner Stufe — rückwärts, also auf
/// die Grenze auf oder vor dem Zeitpunkt.
///
/// `woche` rastet auf den Montag, `monat`, `halbjahr` und `jahr` auf den
/// Monatsersten. Auch `jahr`: Jahresgrenzen sind zu grob, rückwärts liegt
/// die nächste außerhalb der Daten, und dann rastet gar nichts.
DateTime rastgrenze(DateTime zeitpunkt, DiagrammStufe stufe) =>
    ChartBuckets.snap(
      date: zeitpunkt,
      range: _stufenBereich(stufe),
      direction: SnapDirection.backward,
    );

/// Das Fenster, das beim Aufschlagen sichtbar ist — halboffen `[von, bis)`.
///
/// Es ist ein **rollendes** Fenster, kein Kalenderabschnitt: Es endet an der
/// Rastgrenze **nach** dem jüngsten Wert und reicht von dort eine Woche,
/// einen Monat, sechs oder zwölf Monate zurück. Endete es an der Grenze
/// davor, läge der neueste Balken außerhalb und der Schirm schlüge auf einer
/// leeren Fläche auf — genau das ist `#7`.
///
/// Gezählt wird in Kalendertagen und Kalendermonaten, nie in Sekunden: Die
/// Woche ab dem 19.10.2026 hat 169 Stunden, der März 2026 743.
(DateTime von, DateTime bis) startFenster({
  required DiagrammStufe stufe,
  required DateTime juengster,
}) {
  // Erst zurück auf die Grenze, dann einen Schritt vor. Über
  // `SnapDirection.forward` liefe ein Zeitpunkt, der selbst auf einer Grenze
  // liegt, auf sich selbst zurück — dann endete das Fenster genau auf dem
  // jüngsten Wert, und der fiele aus dem halboffenen Fenster heraus.
  final beginn = rastgrenze(juengster, stufe);
  final bis = switch (stufe) {
    DiagrammStufe.woche => BerlinCalendar.addDays(beginn, 7),
    DiagrammStufe.monat ||
    DiagrammStufe.halbjahr ||
    DiagrammStufe.jahr => BerlinCalendar.addMonths(beginn, 1),
  };
  final von = switch (stufe) {
    DiagrammStufe.woche => BerlinCalendar.addDays(bis, -7),
    DiagrammStufe.monat => BerlinCalendar.addMonths(bis, -1),
    DiagrammStufe.halbjahr => BerlinCalendar.addMonths(bis, -6),
    DiagrammStufe.jahr => BerlinCalendar.addMonths(bis, -12),
  };
  return (von, bis);
}

/// Die Stufe der Oberfläche auf die Stufe des Kerns. `T` (`ChartRange.day`)
/// kommt hier nicht vor — kein Schirm hat Stundenwerte.
ChartRange _stufenBereich(DiagrammStufe stufe) => switch (stufe) {
  DiagrammStufe.woche => ChartRange.week,
  DiagrammStufe.monat => ChartRange.month,
  DiagrammStufe.halbjahr => ChartRange.halfYear,
  DiagrammStufe.jahr => ChartRange.year,
};
