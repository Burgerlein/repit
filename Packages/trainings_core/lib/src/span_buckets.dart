// Verdichtung vieler Einzelmessungen auf wenige Abschnitte mit je einer
// Spanne — die Rechnung hinter „Herzfrequenz im Schlaf" und „Atemfrequenz
// im Schlaf" (#148).
//
// Der Vertrag und seine Begründungen stehen im Kopf von
// `test/span_buckets_test.dart`; diese Datei setzt ihn um und erfindet
// nichts dazu.
import 'chart_buckets.dart';

/// Die Spanne über einem Abschnitt der Nacht.
///
/// Werttyp mit `==` und `hashCode` aus demselben Grund wie [ChartPoint]:
/// Die Reihe der Spannen ist die Abhängigkeit, aus der eine Ansicht ihr
/// Diagramm ableitet. Ohne Gleichheit wäre jede neu gebaute Liste ungleich
/// der vorigen und alles Abgeleitete liefe neu.
final class ValueSpan {
  /// Ein Abschnitt mit mindestens einer Messung.
  const ValueSpan({
    required this.start,
    required this.end,
    required double this.min,
    required double this.max,
  });

  /// Ein Abschnitt ohne Messung.
  ///
  /// [min] und [max] sind `null` — **niemals `0`**. Eine Kapsel bei 0 bpm
  /// wäre eine Behauptung über den Nutzer, die niemand gemessen hat.
  const ValueSpan.empty({required this.start, required this.end})
    : min = null,
      max = null;

  /// Beginn des Abschnitts, einschließlich.
  final DateTime start;

  /// Ende des Abschnitts, ausschließlich — außer beim letzten, der das
  /// Fensterende einschließt.
  final DateTime end;

  /// Tiefster bzw. höchster Messwert des Abschnitts; `null`, wenn keiner
  /// darin lag.
  final double? min;
  final double? max;

  /// Wahr genau dann, wenn im Abschnitt keine Messung lag.
  bool get isEmpty => min == null;

  @override
  bool operator ==(Object other) =>
      other is ValueSpan &&
      other.start == start &&
      other.end == end &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(start, end, min, max);

  @override
  String toString() =>
      'ValueSpan(start: $start, end: $end, min: $min, max: $max)';
}

/// Verdichtet Einzelmessungen auf gleich lange Abschnitte.
abstract final class SpanBuckets {
  /// Verdichtet [samples] auf [sectionCount] gleich lange Abschnitte
  /// zwischen [from] und [to].
  ///
  /// Geteilt wird **verstrichene** Zeit, nicht Wanduhrzeit: Hier kommt
  /// keine Kalendergrenze vor, mit Absicht. Die Nacht zum 25.10.2026 ist
  /// physisch neun Stunden lang und soll das zeigen, statt in einen doppelt
  /// belegten „02:00"-Abschnitt zu fallen. Die Wanduhr kommt genau einmal
  /// ins Spiel — wenn die Ansicht [ValueSpan.start] beschriftet.
  ///
  /// Die Abschnitte sind halboffen `[start, end)`, damit ein Messwert genau
  /// auf einer Grenze nicht zweimal zählt; der **letzte** schließt [to] ein,
  /// weil die letzte Messung einer Nacht typisch genau auf dem
  /// Aufwachzeitpunkt liegt und oft der Spitzenwert ist.
  ///
  /// Ein Abschnitt ohne Messung bleibt an seinem Platz und ist
  /// [ValueSpan.empty] — fiele er aus der Liste, verrutschte ab dort die
  /// Achse und jede folgende Beschriftung löge. Liegt dagegen **kein
  /// einziger** Messwert im Fenster, ist das Ergebnis leer: Das ist für die
  /// Ansicht das Zeichen, einen Leerzustand zu zeigen, statt ein
  /// vollständiges leeres Raster zu zeichnen.
  ///
  /// Wirft `ArgumentError`, wenn [sectionCount] kleiner als 1 ist oder [to]
  /// nicht nach [from] liegt — **vor** jedem Blick auf die Daten, sonst
  /// verdeckt eine leere Nacht den Programmierfehler bis zur ersten vollen.
  /// Die übergebene Liste bleibt unverändert.
  static List<ValueSpan> spans({
    required List<ChartSample> samples,
    required DateTime from,
    required DateTime to,
    required int sectionCount,
  }) {
    final grenzen = _grenzen(from, to, sectionCount);

    final min = List<double?>.filled(sectionCount, null);
    final max = List<double?>.filled(sectionCount, null);
    var gemessen = false;

    for (final sample in samples) {
      if (sample.date.isBefore(from) || sample.date.isAfter(to)) continue;
      final index = _abschnittVon(grenzen, sample.date, sectionCount);
      final bisher = min[index];
      if (bisher == null || sample.value < bisher) min[index] = sample.value;
      final hoechster = max[index];
      if (hoechster == null || sample.value > hoechster) {
        max[index] = sample.value;
      }
      gemessen = true;
    }

    if (!gemessen) return const [];

    return [
      for (var i = 0; i < sectionCount; i++)
        if (min[i] case final tiefster?)
          ValueSpan(
            start: grenzen[i],
            end: grenzen[i + 1],
            min: tiefster,
            max: max[i]!,
          )
        else
          ValueSpan.empty(start: grenzen[i], end: grenzen[i + 1]),
    ];
  }

  /// Der Mittelwert der Stichproben je Abschnitt, in derselben Zahl und
  /// Reihenfolge wie [spans] — die Linie über der Fläche (#515).
  ///
  /// **Dieselben Abschnittsgrenzen wie [spans], mikrosekundengenau:** Beide
  /// rufen denselben Helfer ([_grenzen]) und dieselbe Zuordnung
  /// ([_abschnittVon]) auf, statt die Formel zu wiederholen. Zwei getrennte
  /// Rechnungen, die sich um eine Mikrosekunde unterscheiden, ordneten eine
  /// Stichprobe am Rand verschiedenen Abschnitten zu — die Linie läge
  /// neben ihrer Fläche, und niemand fände den Grund.
  ///
  /// Das **einfache** Mittel der Stichproben im Abschnitt: nicht
  /// zeitgewichtet und nicht die Mitte zwischen Min und Max. Die Mitte wäre
  /// eine andere Zahl und hieße trotzdem „Ø".
  ///
  /// `null` für einen Abschnitt ohne Stichprobe — **nie `0`**. Liegt
  /// **keine einzige** Stichprobe im Fenster, ist das Ergebnis leer, genau
  /// wie bei [spans]; zwei Längen für denselben Fall hielte später jemand
  /// für einen Fehler.
  ///
  /// Wirft dieselben `ArgumentError` wie [spans], vor jedem Blick auf die
  /// Daten. Die übergebene Liste bleibt unverändert.
  static List<double?> means({
    required List<ChartSample> samples,
    required DateTime from,
    required DateTime to,
    required int sectionCount,
  }) {
    final grenzen = _grenzen(from, to, sectionCount);

    final summe = List<double>.filled(sectionCount, 0);
    final anzahl = List<int>.filled(sectionCount, 0);
    var gemessen = false;

    for (final sample in samples) {
      if (sample.date.isBefore(from) || sample.date.isAfter(to)) continue;
      final index = _abschnittVon(grenzen, sample.date, sectionCount);
      summe[index] += sample.value;
      anzahl[index]++;
      gemessen = true;
    }

    if (!gemessen) return const [];

    return [
      for (var i = 0; i < sectionCount; i++)
        if (anzahl[i] > 0) summe[i] / anzahl[i] else null,
    ];
  }

  /// Prüft die Eingaben und teilt das Fenster in [sectionCount] gleich lange
  /// Abschnitte; liefert `sectionCount + 1` Grenzen.
  ///
  /// Die eine Stelle, an der die Grenzen entstehen — für [spans] und
  /// [means] gemeinsam. Die letzte Grenze trifft [to] exakt, weil sie nicht
  /// aus aufsummierten, gerundeten Längen entsteht.
  static List<DateTime> _grenzen(DateTime from, DateTime to, int sectionCount) {
    if (sectionCount < 1) {
      throw ArgumentError.value(
        sectionCount,
        'sectionCount',
        'Weniger als einen Abschnitt gibt es nicht',
      );
    }
    final total = to.difference(from).inMicroseconds;
    if (total <= 0) {
      throw ArgumentError.value(
        to,
        'to',
        'Das Fensterende muss nach dem Fensterbeginn liegen',
      );
    }
    return [
      for (var i = 0; i <= sectionCount; i++)
        from.add(Duration(microseconds: total * i ~/ sectionCount)),
    ];
  }

  /// Der letzte Abschnitt, dessen Beginn nicht nach [zeitpunkt] liegt —
  /// höchstens der letzte überhaupt, damit ein Wert genau auf dem
  /// Fensterende hineinfällt statt daneben.
  static int _abschnittVon(
    List<DateTime> grenzen,
    DateTime zeitpunkt,
    int sectionCount,
  ) {
    var tief = 0;
    var hoch = sectionCount; // grenzen[hoch] ist das Fensterende
    while (tief < hoch) {
      final mitte = tief + (hoch - tief + 1) ~/ 2;
      if (grenzen[mitte].isAfter(zeitpunkt)) {
        hoch = mitte - 1;
      } else {
        tief = mitte;
      }
    }
    return tief >= sectionCount ? sectionCount - 1 : tief;
  }
}
