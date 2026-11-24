import 'berlin_calendar.dart';

/// Die Stufen der Zeitraumleiste (`T W M 6M J`).
///
/// `day` hat heute keinen Abnehmer — die Schirme liefern Tagessummen, keine
/// Stundenwerte. Die Stufe bleibt trotzdem, weil sie verdichtungsfrei
/// durchreicht und damit bereitsteht, sobald HealthKit stündlich gelesen
/// wird.
enum ChartRange { day, week, month, halfYear, year }

/// Wie [ChartBuckets.points] die Messwerte eines Kalendermonats zu einem
/// Punkt zusammenfasst — nur dort, wo verdichtet wird ([ChartRange.halfYear]
/// und [ChartRange.year]).
///
/// [mean] ist richtig für Schritte, Körpergewicht und Schlaf. Eine Reihe,
/// die ein **Höchstgewicht** zeigt, braucht [max]: 60 kg am 2. und 70 kg am
/// 28. ergäben im Mittel 65 — ein Gewicht, das nie auf der Stange lag
/// (`docs/SPEC.md` 4.4, Board-Nr. 18). Deshalb eine Art je Aufruf und keine
/// neue Regel für alle.
enum ChartAggregation { mean, max }

/// In welche Richtung [ChartBuckets.snap] rastet.
enum SnapDirection { nearest, forward, backward }

/// Ein Messwert: Zeitpunkt und Zahl.
///
/// Werttyp mit `==` und `hashCode`: Eine Reihe von Messwerten ist die
/// Abhängigkeit, aus der ein Provider die Punkte ableitet. Ohne Gleichheit
/// auf den Elementen wäre jede neu gebaute Liste ungleich der vorigen, und
/// alles Abgeleitete liefe neu.
final class ChartSample {
  const ChartSample({required this.date, required this.value});

  final DateTime date;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ChartSample && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);

  @override
  String toString() => 'ChartSample(date: $date, value: $value)';
}

/// Ein gezeichneter Punkt.
///
/// Werttyp, aus demselben Grund wie [ChartSample].
final class ChartPoint {
  const ChartPoint({
    required this.start,
    required this.value,
    required this.dayCount,
  });

  /// Der Beginn des Abschnitts, den der Punkt darstellt — bei den
  /// durchreichenden Stufen der Zeitpunkt des Messwerts selbst.
  final DateTime start;

  final double value;

  /// Wie viele **gemessene** Kalendertage hinter dem Punkt stecken.
  final int dayCount;

  @override
  bool operator ==(Object other) =>
      other is ChartPoint &&
      other.start == start &&
      other.value == value &&
      other.dayCount == dayCount;

  @override
  int get hashCode => Object.hash(start, value, dayCount);

  @override
  String toString() =>
      'ChartPoint(start: $start, value: $value, dayCount: $dayCount)';
}

/// Der gemeinsame Unterbau aller Zeitdiagramme: Punkte bilden und
/// Rastgrenzen finden. Jede Kalendergrenze läuft über [BerlinCalendar] —
/// am 29.03.2026 hat der Tag 23 Stunden, am 25.10.2026 25, und die Wochen
/// um die Umstellung entsprechend 167 statt 169.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/ChartBuckets.swift`,
/// mit drei bewussten Abweichungen:
///
/// 1. [ChartRange.year] rastet auf den **Monats**ersten, nicht auf den
///    1. Januar. Jahresgrenzen sind zu grob: Im geladenen Jahr gibt es
///    genau eine, rückwärts liegt die nächste außerhalb der Daten — und
///    dann rastet gar nichts. Die Swift-Fassung tut hier etwas anderes.
/// 2. `visibleLength` gibt es nicht. Das ist eine angenäherte Fensterbreite
///    in Sekunden für SwiftUIs `.chartXVisibleDomain(length:)`; die
///    Flutter-Seite rechnet mit echten Kalendergrenzen.
/// 3. `window` und `windows` gibt es nicht. Kein Abnehmer, und Swifts
///    `window(containing:, for: .halfYear)` liefert das **Kalender**halbjahr
///    — dieselbe Stufe hieße dann im Kern „Januar bis Juni" und in der
///    Shell „die letzten sechs Monate".
abstract final class ChartBuckets {
  /// Die zu zeichnenden Punkte, aufsteigend nach Zeit.
  ///
  /// Bei [ChartRange.day], [ChartRange.week] und [ChartRange.month] werden
  /// die Messwerte **unverändert** durchgereicht: Ihr Zeitpunkt bleibt
  /// stehen, auch wenn er mitten am Tag liegt, und mehrere Werte am selben
  /// Tag bleiben mehrere Punkte. `ChartSample.date` ist laut Spec bereits
  /// Stunden- oder Tagesbeginn; wer Rohwerte hat, normalisiert sie vor dem
  /// Aufruf (das tut in der App `diagrammPunkte` in
  /// `app/lib/shell/diagramm_zeitraum.dart`).
  ///
  /// Bei [ChartRange.halfYear] und [ChartRange.year] entsteht je
  /// Kalendermonat mit mindestens einer Messung ein Punkt auf dem Berliner
  /// Monatsersten. Monate ohne Messung fehlen — eine Lücke bleibt eine
  /// Lücke.
  ///
  /// [aggregation] bestimmt nur, was aus den Messwerten eines Monats wird
  /// ([ChartAggregation.mean], die Vorgabe, oder [ChartAggregation.max]);
  /// die durchreichenden Stufen kennen keine Verdichtung und ignorieren sie.
  ///
  /// Die übergebene Liste wird nicht verändert.
  static List<ChartPoint> points({
    required List<ChartSample> samples,
    required ChartRange range,
    ChartAggregation aggregation = ChartAggregation.mean,
  }) {
    // `List.sort` sortiert an Ort und Stelle. Hält ein Provider die Reihe,
    // hätte der Aufruf sonst eine sichtbare Nebenwirkung.
    final sorted = List<ChartSample>.of(samples)
      ..sort((a, b) => a.date.compareTo(b.date));

    switch (range) {
      case ChartRange.day:
      case ChartRange.week:
      case ChartRange.month:
        return [
          for (final sample in sorted)
            ChartPoint(start: sample.date, value: sample.value, dayCount: 1),
        ];
      case ChartRange.halfYear:
      case ChartRange.year:
        return _monthly(sorted, aggregation);
    }
  }

  /// Der Zeitpunkt, auf den `date` in seiner Stufe rastet.
  ///
  /// Die Rastgrenzen: [ChartRange.day] der Tagesbeginn, [ChartRange.week]
  /// der Montag, [ChartRange.month], [ChartRange.halfYear] und
  /// [ChartRange.year] der Monatserste. Sechs Monate sind das Fenster, der
  /// Monat ist die Grenze.
  ///
  /// Ein Zeitpunkt, der schon auf einer Grenze liegt, ist in jeder Richtung
  /// seine eigene Antwort — sonst blättert ein Diagramm an der Kante eine
  /// Seite zu weit. Bei [SnapDirection.nearest] entscheidet die
  /// **verstrichene** Zeit, nicht die Wanduhrzeit; bei Gleichstand gewinnt
  /// die frühere Grenze.
  ///
  /// Die Antwort ist immer ein UTC-Zeitpunkt, der einen Berliner
  /// Tagesbeginn bezeichnet.
  static DateTime snap({
    required DateTime date,
    required ChartRange range,
    required SnapDirection direction,
  }) {
    final earlier = _boundaryAtOrBefore(date, range);
    // Liegt der Zeitpunkt selbst auf der Grenze, gibt es keine spätere:
    // Er beginnt seinen eigenen Abschnitt, statt den vorigen zu beenden.
    final later = date.isAtSameMomentAs(earlier)
        ? earlier
        : _nextBoundary(earlier, range);

    switch (direction) {
      case SnapDirection.backward:
        return earlier;
      case SnapDirection.forward:
        return later;
      case SnapDirection.nearest:
        return date.difference(earlier) <= later.difference(date)
            ? earlier
            : later;
    }
  }

  /// Die Grenze der Stufe, die auf `date` oder davor liegt.
  static DateTime _boundaryAtOrBefore(DateTime date, ChartRange range) {
    switch (range) {
      case ChartRange.day:
        return BerlinCalendar.startOfDay(date);
      case ChartRange.week:
        // Reiner Datumsschritt zurück auf den Montag; `addDays` gibt den
        // Tagesbeginn, also auch über eine Umstellung hinweg 00:00 lokal.
        return BerlinCalendar.addDays(date, 1 - BerlinCalendar.weekday(date));
      case ChartRange.month:
      case ChartRange.halfYear:
      case ChartRange.year:
        return BerlinCalendar.startOfMonth(date);
    }
  }

  /// Die Grenze, die auf `boundary` folgt. Gezählt wird in Kalendertagen
  /// bzw. Kalendermonaten, nie in Sekunden.
  static DateTime _nextBoundary(DateTime boundary, ChartRange range) {
    switch (range) {
      case ChartRange.day:
        return BerlinCalendar.addDays(boundary, 1);
      case ChartRange.week:
        return BerlinCalendar.addDays(boundary, 7);
      case ChartRange.month:
      case ChartRange.halfYear:
      case ChartRange.year:
        return BerlinCalendar.addMonths(boundary, 1);
    }
  }

  /// Ein Punkt je Kalendermonat, auf dem Berliner Monatsersten.
  ///
  /// Bei [ChartAggregation.max] trägt der Punkt den größten Messwert des
  /// Monats — weder den ersten noch den letzten. Bei negativen Werten
  /// (Unterstützung) ist das der, der näher an null liegt.
  ///
  /// Das Mittel läuft über die **Messwerte**, `dayCount` über die
  /// verschiedenen **Kalendertage**. Für die heutigen Abnehmer ist das
  /// dasselbe — sie liefern Tageswerte; die Annahme steht hier, damit sie
  /// jemand findet, wenn eine Reihe das einmal nicht tut.
  ///
  /// Geteilt wird durch die Zahl der Messwerte, nicht durch die Länge des
  /// Monats: Sonst sähe ein Monat mit wenigen Messungen aus wie ein fauler
  /// Monat.
  static List<ChartPoint> _monthly(
    List<ChartSample> sorted,
    ChartAggregation aggregation,
  ) {
    final order = <DateTime>[];
    final sums = <DateTime, double>{};
    final maxima = <DateTime, double>{};
    final counts = <DateTime, int>{};
    final days = <DateTime, Set<String>>{};

    for (final sample in sorted) {
      final month = BerlinCalendar.startOfMonth(sample.date);
      if (!sums.containsKey(month)) {
        order.add(month);
        sums[month] = 0;
        maxima[month] = sample.value;
        counts[month] = 0;
        days[month] = <String>{};
      }
      sums[month] = sums[month]! + sample.value;
      if (sample.value > maxima[month]!) maxima[month] = sample.value;
      counts[month] = counts[month]! + 1;
      // Der ISO-Tagesstring ist der Berliner Kalendertag: Am 25.10.2026
      // liegen 24 verstrichene Stunden noch im selben Tag, er hat 25.
      days[month]!.add(BerlinCalendar.dayKey(sample.date));
    }

    return [
      for (final month in order)
        ChartPoint(
          start: month,
          value: switch (aggregation) {
            ChartAggregation.mean => sums[month]! / counts[month]!,
            ChartAggregation.max => maxima[month]!,
          },
          dayCount: days[month]!.length,
        ),
    ];
  }
}
