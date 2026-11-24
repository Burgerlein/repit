import 'berlin_calendar.dart';

/// Ein einzelner Messpunkt einer Körper-Messreihe: Gewicht, Körperfett,
/// fettfreie Masse oder Ruhepuls. Welcher der vier es ist, trägt der Punkt
/// nicht — das weiß die Reihe, aus der er stammt.
///
/// Werttyp mit [==] und [hashCode], weil eine Liste davon Abhängigkeit eines
/// Providers ist: Ohne Wertgleichheit wäre jede neu gelesene Liste ungleich
/// der vorigen und jeder abgeleitete Wert liefe neu (`CLAUDE.md`, Fehler
/// `03`).
///
/// Nicht `const`-fähig, und das liegt an [DateTime]: `DateTime.utc(…)` ist
/// kein konstanter Ausdruck.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/BodyTrend.swift`.
class MeasurementPoint {
  MeasurementPoint({required this.date, required this.value});

  final DateTime date;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is MeasurementPoint && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);

  @override
  String toString() => 'MeasurementPoint(date: $date, value: $value)';
}

/// Einordnung des Gewichtstrends für den Muskelaufbau. `docs/SPEC.md` 4.6
/// und 3.1 nennen +0,10 bis +0,25 kg pro Woche als guten Bereich.
///
/// Hier stehen nur die vier Fälle, **keine Sätze**: Die Nutzertexte gehören
/// in die View (`CLAUDE.md`, „Deutsch in der Oberfläche, Englisch im Code").
/// Es sind dort vier Sätze, nicht vier Wörter — ein Enum-Name taugt nicht
/// als Anzeige.
enum TrendRating {
  /// Es geht abwärts.
  losing,

  /// Zu langsam für den Aufbau. Stillstand (`0,0`) fällt hierher, nicht
  /// nach [losing].
  slow,

  good,

  /// Schneller als nötig — der Überschuss wird eher Fett als Muskel.
  fast,
}

abstract final class BodyTrend {
  /// Wie viele Wochen das Fenster vorgabemäßig zurückreicht.
  static const int defaultWeeks = 6;

  /// Steigung in Einheiten **pro Woche**, kleinste Quadrate über das
  /// Fenster der letzten [weeks] Wochen.
  ///
  /// `null` heißt „nicht rechenbar", nie „kein Trend":
  ///
  /// * Weniger als **zwei** Punkte im Fenster. Eine Gerade durch einen
  ///   Punkt hat keine Steigung, und „0,0 pro Woche" wäre eine Zahl, die
  ///   niemand gerechnet hat — die View sagt an dieser Stelle „zu wenige
  ///   Wägungen". Gleicher Wert zu zwei **verschiedenen** Zeitpunkten ist
  ///   dagegen `0.0`: gerechnet, Ergebnis Stillstand.
  /// * Alle Punkte im Fenster auf demselben Zeitpunkt. Die Punktwolke steht
  ///   senkrecht, der Nenner der kleinsten Quadrate ist 0.
  ///
  /// Die Fensterkante liegt `weeks * 7` Kalendertage vor dem **Berliner
  /// Tagesbeginn** von [now] — über [BerlinCalendar.addDays], nicht über
  /// `Duration(days: …)`. Zwei Fehler sind damit ausgeschlossen, und beide
  /// wären still: Wer von [now] selbst zurückrechnet, verliert je nach
  /// Tageszeit den ältesten Messtag (die Waage wiegt morgens, der Nutzer
  /// schaut abends); wer eine feste Dauer abzieht, verschiebt die Kante über
  /// eine Zeitumstellung hinweg um eine Stunde. Punkte genau auf der Kante
  /// zählen mit.
  ///
  /// **Gefiltert wird nur nach unten**, wie in der Swift-Vorlage: Ein Punkt
  /// mit einem Zeitpunkt nach [now] bliebe im Fenster. HealthKit liefert
  /// keine Zukunftswerte, und eine obere Kante wäre eine Regel, die nie
  /// greift.
  ///
  /// Die Eingabe muss **nicht** sortiert sein — aus der Datenbank kommt sie
  /// sortiert, aus einem Zusammenschnitt nicht, und die kleinsten Quadrate
  /// brauchen die Ordnung ohnehin nicht.
  static double? perWeek(
    List<MeasurementPoint> points, {
    int weeks = defaultWeeks,
    required DateTime now,
  }) {
    final cutoff = BerlinCalendar.addDays(
      BerlinCalendar.startOfDay(now),
      -weeks * 7,
    );

    final inside = points
        .where((punkt) => !punkt.date.isBefore(cutoff))
        .toList(growable: false);
    if (inside.length < 2) return null;

    // Die x-Achse zählt in Wochen seit Epoch. Damit fällt die Steigung
    // direkt in Einheiten pro Woche an, ohne Nachskalierung — und ein
    // Zwischenschritt, den jemand vergessen könnte, entfällt.
    const millisekundenJeWoche = 7 * 24 * 60 * 60 * 1000;
    final xs = inside
        .map(
          (punkt) => punkt.date.millisecondsSinceEpoch / millisekundenJeWoche,
        )
        .toList(growable: false);
    final ys = inside.map((punkt) => punkt.value).toList(growable: false);

    final n = inside.length;
    var summeX = 0.0;
    var summeY = 0.0;
    for (var i = 0; i < n; i++) {
      summeX += xs[i];
      summeY += ys[i];
    }
    final mittelX = summeX / n;
    final mittelY = summeY / n;

    var zaehler = 0.0;
    var nenner = 0.0;
    for (var i = 0; i < n; i++) {
      final abweichungX = xs[i] - mittelX;
      zaehler += abweichungX * (ys[i] - mittelY);
      nenner += abweichungX * abweichungX;
    }

    // Senkrechte Punktwolke: alle Messungen auf demselben Zeitpunkt. Die
    // Grenze ist der Zeitpunkt, nicht der Kalendertag — zwei Wägungen am
    // selben Tag zu verschiedenen Uhrzeiten ergeben sehr wohl eine Gerade.
    if (nenner <= 0) return null;
    return zaehler / nenner;
  }

  /// Die Einordnung einer Steigung in die vier Fälle von [TrendRating].
  ///
  /// Beide Grenzen gehören zu [TrendRating.good]: Ein `<` an der oberen
  /// Grenze schöbe genau 0,25 nach [TrendRating.fast] und riete dem Nutzer,
  /// weniger zu essen, obwohl er im Zielbereich liegt.
  static TrendRating rating(double perWeek) {
    if (perWeek < 0) return TrendRating.losing;
    if (perWeek < 0.1) return TrendRating.slow;
    if (perWeek <= 0.25) return TrendRating.good;
    return TrendRating.fast;
  }
}

abstract final class ProteinTarget {
  /// 1,6 bis 2,0 Gramm Eiweiß je Kilogramm Körpergewicht, auf ganze Gramm
  /// gerundet — als `(low, high)`, positionell. `null` bei `weightKg <= 0`.
  ///
  /// **Jede Grenze wird einzeln gerundet.** Wer einmal rundet und die
  /// zweite Zahl daraus ableitet, trifft eine der beiden nicht: 70,3 kg
  /// ergibt 112 und 141, und 112 · 1,25 ist nicht 141.
  ///
  /// Die Grenze ist `<= 0`, nicht „unplausibel klein". Ob ein Gewicht als
  /// Körpergewicht taugt, entscheidet nicht der Kern — er rechnet.
  static (int low, int high)? grams(double weightKg) {
    if (weightKg <= 0) return null;
    return ((weightKg * 1.6).round(), (weightKg * 2.0).round());
  }
}
