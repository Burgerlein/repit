import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `body_trend.dart` aus Ticket #202 — Spec
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// **Teil A**. Vorlage:
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/BodyTrend.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Importiert wird das Barrel `package:trainings_core/trainings_core.dart`,
/// weil die Spec die Ausfuhr ausdrücklich verlangt („Neue Datei
/// `lib/src/body_trend.dart`, exportiert aus `trainings_core.dart`"). Der
/// fehlende Export fiele sonst erst der App auf.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class MeasurementPoint {
///   MeasurementPoint({required DateTime date, required double value});
///   final DateTime date;
///   final double value;
///   // Wertgleichheit: == und hashCode.
/// }
///
/// enum TrendRating { losing, slow, good, fast }
///
/// abstract final class BodyTrend {
///   static double? perWeek(
///     List<MeasurementPoint> points, {
///     int weeks = 6,
///     required DateTime now,
///   });
///   static TrendRating rating(double perWeek);
/// }
///
/// abstract final class ProteinTarget {
///   static (int low, int high)? grams(double weightKg);
/// }
/// ```
///
/// `(int low, int high)` ist ein Record mit **positionellen** Feldern — die
/// Bezeichner sind in Dart reine Dokumentation. Die Tests vergleichen
/// deshalb den ganzen Record (`(128, 160)`), was Reihenfolge und Typ
/// zugleich festnagelt.
///
/// ## Alle Zahlen hier sind erfunden
///
/// Kein Wert stammt aus Tims Gesundheitsdaten, und keiner aus
/// `docs/screens/` — die Zahlen dort sind Beispielfüllung und nie
/// Erwartungswert. Gewählt sind Werte, die sich im Kopf nachrechnen lassen.
///
/// ## Warum die Fensterkante über `BerlinCalendar` läuft
///
/// Das Fenster beginnt `weeks * 7` Tage vor dem **Berliner Tagesbeginn** von
/// `now`, nicht vor `now` selbst und nicht über eine Rechnung mit 86400.
/// Beide Abweichungen bekommen unten einen eigenen Fall, weil beide still
/// falsch sind:
///
/// * Wer von `now` statt vom Tagesbeginn zurückrechnet, verliert je nach
///   Tageszeit den ältesten Messtag — die Waage wiegt morgens, der Nutzer
///   schaut abends.
/// * Wer `Duration(days: 42)` abzieht, verschiebt die Kante über eine
///   Zeitumstellung hinweg um eine Stunde.
void main() {
  /// Bequemer Bauer, damit die Testkörper aus Datum und Wert bestehen und
  /// nicht aus Konstruktoraufrufen.
  MeasurementPoint p(DateTime date, double value) =>
      MeasurementPoint(date: date, value: value);

  group('MeasurementPoint ist ein Werttyp', () {
    // Er wird von einem Provider gehalten; ohne `==`/`hashCode` wäre jede
    // neu gebaute Liste ungleich der vorigen und jeder abgeleitete Wert
    // liefe neu — Fehler `03`, wortgleich im neuen Code (`CLAUDE.md`).

    test('gleiches Datum und gleicher Wert sind gleich', () {
      expect(
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
      );
    });

    test('gleiche Punkte haben denselben hashCode', () {
      expect(
        p(DateTime.utc(2026, 6, 1, 6), 80.0).hashCode,
        p(DateTime.utc(2026, 6, 1, 6), 80.0).hashCode,
      );
    });

    test('ein anderer Wert macht den Punkt ungleich', () {
      expect(
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
        isNot(p(DateTime.utc(2026, 6, 1, 6), 80.1)),
      );
    });

    test('ein anderes Datum macht den Punkt ungleich', () {
      expect(
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
        isNot(p(DateTime.utc(2026, 6, 2, 6), 80.0)),
      );
    });

    test('ein Set fasst gleiche Punkte zusammen', () {
      // Fängt den Fall, den ein reines `==` nicht fängt: ein `hashCode`,
      // der nicht zu `==` passt, fällt erst in einer Menge auf.
      final menge = {
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
        p(DateTime.utc(2026, 6, 1, 6), 80.0),
        p(DateTime.utc(2026, 6, 2, 6), 80.0),
      };
      expect(menge, hasLength(2));
    });

    test('Datum und Wert kommen unverändert wieder heraus', () {
      final punkt = p(DateTime.utc(2026, 6, 1, 6), 80.0);
      expect(punkt.date, DateTime.utc(2026, 6, 1, 6));
      expect(punkt.value, 80.0);
    });
  });

  group('BodyTrend.perWeek: zu wenig, um eine Gerade zu legen', () {
    final now = DateTime.utc(2026, 6, 15, 12);

    test('eine leere Liste ergibt null', () {
      expect(BodyTrend.perWeek(const [], now: now), isNull);
    });

    test('ein einzelner Punkt ergibt null, nicht 0,0', () {
      // „0,0 pro Woche" wäre eine Zahl, die niemand gerechnet hat — die
      // View sagt an dieser Stelle „zu wenige Wägungen".
      expect(
        BodyTrend.perWeek([p(DateTime.utc(2026, 6, 8, 6), 80.0)], now: now),
        isNull,
      );
    });

    test('zwei Punkte, von denen einer außerhalb liegt, ergeben null', () {
      // Fenster: 42 Tage vor dem Berliner Tagesbeginn des 15.06.2026, also
      // ab 2026-05-03T22:00Z. Der Januar-Punkt fällt heraus, übrig bleibt
      // einer.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 1, 5, 6), 70.0),
          p(DateTime.utc(2026, 6, 8, 6), 80.0),
        ], now: now),
        isNull,
      );
    });

    test('alle Punkte auf demselben Zeitpunkt ergeben null', () {
      // Senkrechte Punktwolke: der Nenner der kleinsten Quadrate ist 0.
      final zeitpunkt = DateTime.utc(2026, 6, 10, 7, 30);
      expect(
        BodyTrend.perWeek([
          p(zeitpunkt, 80.0),
          p(zeitpunkt, 80.4),
          p(zeitpunkt, 79.6),
        ], now: now),
        isNull,
      );
    });

    test('zwei Punkte am selben Tag, aber zu verschiedenen Zeiten, '
        'ergeben eine Steigung', () {
      // Die Grenze ist der **Zeitpunkt**, nicht der Kalendertag (Spec: „wenn
      // alle Punkte im Fenster denselben Zeitpunkt tragen"). Zwölf Stunden
      // sind 1/14 Woche, 0,5 kg darüber ergeben 7,0 kg pro Woche — absurd
      // als Gewichtstrend, aber genau die Rechnung, die hier geprüft wird.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 6, 15, 6), 80.0),
          p(DateTime.utc(2026, 6, 15, 18), 80.5),
        ], now: now),
        closeTo(7.0, 1e-6),
      );
    });
  });

  group('BodyTrend.perWeek: die Steigung selbst', () {
    final now = DateTime.utc(2026, 6, 15, 12);

    test('zwei Punkte, genau eine Woche auseinander', () {
      // 08.06. 80,0 kg → 15.06. 80,5 kg. Beide Zeitpunkte liegen in der
      // Sommerzeit, der Abstand ist exakt 7 · 24 h, also exakt eine Woche
      // auf der x-Achse. Steigung 0,5 / 1 = 0,5.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 6, 8, 6), 80.0),
          p(DateTime.utc(2026, 6, 15, 6), 80.5),
        ], now: now),
        closeTo(0.5, 1e-9),
      );
    });

    test('abwärts ergibt eine negative Steigung', () {
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 6, 8, 6), 80.5),
          p(DateTime.utc(2026, 6, 15, 6), 80.0),
        ], now: now),
        closeTo(-0.5, 1e-9),
      );
    });

    test('gleicher Wert zu zwei Zeitpunkten ergibt 0,0 — nicht null', () {
      // Das ist der Unterschied zwischen „gerechnet, Ergebnis Stillstand"
      // und „nicht rechenbar". Nur das Zweite ist null.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 6, 8, 6), 80.0),
          p(DateTime.utc(2026, 6, 15, 6), 80.0),
        ], now: now),
        closeTo(0.0, 1e-9),
      );
    });

    test('vier Punkte, kleinste Quadrate — 0,14 kg pro Woche', () {
      // Vier Wägungen im Wochenabstand:
      //
      //   25.05. 80,0 · 01.06. 80,2 · 08.06. 80,1 · 15.06. 80,5
      //
      // x in Wochen, relativ gezählt (die Konstante kürzt sich heraus):
      //   x = 0, 1, 2, 3        → x̄ = 1,5
      //   y = 80,0 80,2 80,1 80,5 → ȳ = 320,8 / 4 = 80,2
      //
      //   Δx = −1,5  −0,5  +0,5  +1,5
      //   Δy = −0,2   0,0  −0,1  +0,3
      //
      //   Zähler  = 0,30 + 0,00 − 0,05 + 0,45 = 0,70
      //   Nenner  = 2,25 + 0,25 + 0,25 + 2,25 = 5,00
      //   Steigung = 0,70 / 5,00 = 0,14
      //
      // Der mittlere Punkt liegt bewusst unter der Geraden: ein Verfahren,
      // das nur ersten und letzten Punkt verbindet, käme auf 0,5/3 ≈ 0,167
      // und fiele hier durch.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 5, 25, 6), 80.0),
          p(DateTime.utc(2026, 6, 1, 6), 80.2),
          p(DateTime.utc(2026, 6, 8, 6), 80.1),
          p(DateTime.utc(2026, 6, 15, 6), 80.5),
        ], now: now),
        closeTo(0.14, 1e-9),
      );
    });

    test('die Reihenfolge der Eingabe ändert nichts', () {
      // Nirgends steht, dass die Liste sortiert ankommt — aus der Datenbank
      // tut sie das, aus einem Zusammenschnitt nicht.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 6, 8, 6), 80.1),
          p(DateTime.utc(2026, 6, 15, 6), 80.5),
          p(DateTime.utc(2026, 5, 25, 6), 80.0),
          p(DateTime.utc(2026, 6, 1, 6), 80.2),
        ], now: now),
        closeTo(0.14, 1e-9),
      );
    });

    test('ein Punkt außerhalb des Fensters beeinflusst nichts', () {
      // Derselbe Satz wie oben, dazu eine Wägung vom Januar mit 200 kg.
      // Wer das Fenster nicht anwendet, bekommt eine völlig andere Gerade.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 1, 5, 6), 200.0),
          p(DateTime.utc(2026, 5, 25, 6), 80.0),
          p(DateTime.utc(2026, 6, 1, 6), 80.2),
          p(DateTime.utc(2026, 6, 8, 6), 80.1),
          p(DateTime.utc(2026, 6, 15, 6), 80.5),
        ], now: now),
        closeTo(0.14, 1e-9),
      );
    });
  });

  group('BodyTrend.perWeek: die Kante des Fensters', () {
    final now = DateTime.utc(2026, 6, 15, 12);
    // Berliner Tagesbeginn des 15.06.2026 = 2026-06-14T22:00Z (Sommerzeit).
    final tagesbeginn = BerlinCalendar.startOfDay(now);
    // 42 Tage davor = Berliner Mitternacht des 03.05.2026 = 2026-05-03T22:00Z.
    final kante = BerlinCalendar.addDays(tagesbeginn, -6 * 7);

    test('ein Punkt genau auf der Kante zählt mit', () {
      // Spec: „Punkte genau auf der Grenze zählen mit (`>=`)." Ohne das
      // bliebe nur ein Punkt übrig und das Ergebnis wäre null.
      expect(
        BodyTrend.perWeek([
          p(kante, 70.0),
          p(kante.add(const Duration(days: 7)), 71.0),
        ], now: now),
        closeTo(1.0, 1e-9),
      );
    });

    test('eine Millisekunde vor der Kante fällt heraus', () {
      expect(
        BodyTrend.perWeek([
          p(kante.subtract(const Duration(milliseconds: 1)), 70.0),
          p(kante.add(const Duration(days: 7)), 71.0),
        ], now: now),
        isNull,
      );
    });

    test('gezählt wird ab dem Tagesbeginn, nicht ab `now`', () {
      // 04.05.2026 06:00Z liegt **nach** der Kante (03.05. 22:00Z), aber
      // **vor** `now` minus 42 Tage (04.05. 12:00Z). Wer von `now` statt
      // vom Berliner Tagesbeginn zurückrechnet, verliert diesen Punkt und
      // liefert null.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 5, 4, 6), 70.0),
          p(DateTime.utc(2026, 5, 11, 6), 70.5),
        ], now: now),
        closeTo(0.5, 1e-9),
      );
    });

    test('die Uhrzeit von `now` verschiebt das Fenster nicht', () {
      // 05:00Z und 21:00Z sind derselbe Berliner Kalendertag (15.06.2026).
      final punkte = [
        p(DateTime.utc(2026, 5, 4, 6), 70.0),
        p(DateTime.utc(2026, 5, 11, 6), 70.5),
      ];
      expect(
        BodyTrend.perWeek(punkte, now: DateTime.utc(2026, 6, 15, 5)),
        BodyTrend.perWeek(punkte, now: DateTime.utc(2026, 6, 15, 21)),
      );
    });

    test('die Kante läuft über BerlinCalendar, nicht über 86400', () {
      // `now` = 20.04.2026 12:00Z, Berliner Tagesbeginn 2026-04-19T22:00Z
      // (Sommerzeit). 42 Kalendertage davor ist der 09.03.2026, und dessen
      // Berliner Mitternacht liegt bei 2026-03-08T**23:00**Z — Winterzeit.
      // `Duration(days: 42)` abzuziehen ergäbe 2026-03-08T**22:00**Z, eine
      // Stunde zu früh.
      //
      // Der erste Punkt sitzt um 22:30Z genau in dieser Stunde: Mit der
      // richtigen Kante fällt er heraus und es bleibt ein Punkt übrig
      // (null), mit der Duration-Rechnung käme 1,0 heraus.
      expect(
        BodyTrend.perWeek([
          p(DateTime.utc(2026, 3, 8, 22, 30), 70.0),
          p(DateTime.utc(2026, 3, 15, 22, 30), 71.0),
        ], now: DateTime.utc(2026, 4, 20, 12)),
        isNull,
      );
    });
  });

  group('BodyTrend.perWeek: der Parameter `weeks`', () {
    final now = DateTime.utc(2026, 6, 15, 12);
    final tagesbeginn = BerlinCalendar.startOfDay(now);

    test('die Vorgabe ist sechs Wochen', () {
      // Punkt A liegt 43 Tage vor dem Tagesbeginn, also eine Kalenderstufe
      // außerhalb; Punkt B sieben Tage davor, drinnen. Mit der Vorgabe 6
      // bleibt nur B übrig.
      expect(
        BodyTrend.perWeek([
          p(BerlinCalendar.addDays(tagesbeginn, -43), 70.0),
          p(BerlinCalendar.addDays(tagesbeginn, -7), 72.0),
        ], now: now),
        isNull,
      );
    });

    test('mit der Vorgabe liegen 21 und 7 Tage beide im Fenster', () {
      // 2026-05-24T22:00Z und 2026-06-07T22:00Z, beide Sommerzeit — exakt
      // zwei Wochen Abstand. 2,0 kg über zwei Wochen sind 1,0 pro Woche.
      expect(
        BodyTrend.perWeek([
          p(BerlinCalendar.addDays(tagesbeginn, -21), 70.0),
          p(BerlinCalendar.addDays(tagesbeginn, -7), 72.0),
        ], now: now),
        closeTo(1.0, 1e-9),
      );
    });

    test('`weeks: 2` schneidet denselben Satz auf einen Punkt zusammen', () {
      expect(
        BodyTrend.perWeek([
          p(BerlinCalendar.addDays(tagesbeginn, -21), 70.0),
          p(BerlinCalendar.addDays(tagesbeginn, -7), 72.0),
        ], weeks: 2, now: now),
        isNull,
      );
    });

    test('`weeks: 52` holt auch den Januar-Punkt herein', () {
      // Dieselben vier Wägungen wie oben plus der Januar-Ausreißer. Mit
      // einem Jahr Fenster ist er drin, und die Steigung ist deutlich
      // negativ — der Beleg, dass `weeks` das Fenster tatsächlich weitet
      // und nicht nur den Null-Fall verschiebt.
      final steigung = BodyTrend.perWeek([
        p(DateTime.utc(2026, 1, 5, 6), 200.0),
        p(DateTime.utc(2026, 5, 25, 6), 80.0),
        p(DateTime.utc(2026, 6, 1, 6), 80.2),
        p(DateTime.utc(2026, 6, 8, 6), 80.1),
        p(DateTime.utc(2026, 6, 15, 6), 80.5),
      ], weeks: 52, now: now);
      expect(steigung, isNotNull);
      expect(steigung!, lessThan(-1.0));
    });
  });

  group('BodyTrend.rating: die vier Fälle', () {
    // Guter Bereich +0,10 bis +0,25 kg pro Woche (SPEC 4.6 und 3.1).

    test('unter null heißt losing', () {
      expect(BodyTrend.rating(-0.01), TrendRating.losing);
      expect(BodyTrend.rating(-0.5), TrendRating.losing);
      expect(BodyTrend.rating(-3.0), TrendRating.losing);
    });

    test('genau null ist slow, nicht losing', () {
      // Stillstand ist kein Abnehmen (Spec, ausdrücklich).
      expect(BodyTrend.rating(0.0), TrendRating.slow);
    });

    test('zwischen null und 0,1 heißt slow', () {
      expect(BodyTrend.rating(0.01), TrendRating.slow);
      expect(BodyTrend.rating(0.05), TrendRating.slow);
      expect(BodyTrend.rating(0.099), TrendRating.slow);
    });

    test('genau 0,1 gehört zu good', () {
      expect(BodyTrend.rating(0.1), TrendRating.good);
    });

    test('zwischen den Grenzen heißt good', () {
      expect(BodyTrend.rating(0.14), TrendRating.good);
      expect(BodyTrend.rating(0.2), TrendRating.good);
      expect(BodyTrend.rating(0.249), TrendRating.good);
    });

    test('genau 0,25 gehört zu good', () {
      // Die obere Grenze ist einschließlich (`<=`). Ein `<` schöbe den
      // Grenzfall nach `fast` und riete dem Nutzer, weniger zu essen.
      expect(BodyTrend.rating(0.25), TrendRating.good);
    });

    test('über 0,25 heißt fast', () {
      expect(BodyTrend.rating(0.26), TrendRating.fast);
      expect(BodyTrend.rating(1.0), TrendRating.fast);
    });

    test('es gibt genau diese vier Fälle', () {
      expect(TrendRating.values, [
        TrendRating.losing,
        TrendRating.slow,
        TrendRating.good,
        TrendRating.fast,
      ]);
    });
  });

  group('ProteinTarget.grams: 1,6 bis 2,0 g je Kilogramm', () {
    test('80 kg ergeben 128 bis 160 g', () {
      // 80 · 1,6 = 128,0 und 80 · 2,0 = 160,0 — beide Grenzen gehen glatt
      // auf, hier wird nur die Spanne selbst geprüft.
      expect(ProteinTarget.grams(80.0), (128, 160));
    });

    test('die Spanne kommt als (niedrig, hoch) in dieser Reihenfolge', () {
      final spanne = ProteinTarget.grams(80.0)!;
      expect(spanne.$1, 128);
      expect(spanne.$2, 160);
    });

    test('jede Grenze wird einzeln gerundet', () {
      // 70,3 · 1,6 = 112,48 → 112 (abgerundet)
      // 70,3 · 2,0 = 140,6  → 141 (aufgerundet)
      // Wer nur einmal rundet und die Spanne daraus ableitet, trifft eine
      // der beiden Zahlen nicht.
      expect(ProteinTarget.grams(70.3), (112, 141));
    });

    test('genau ein halbes Gramm wird kaufmännisch aufgerundet', () {
      // 70,25 · 2,0 = 140,5 → 141 (`.round()` rundet die Hälfte vom
      // Nullpunkt weg). Die untere Grenze: 70,25 · 1,6 = 112,4 → 112.
      expect(ProteinTarget.grams(70.25), (112, 141));
    });

    test('ein weiteres Gewicht zur Sicherheit', () {
      // 92,4 · 1,6 = 147,84 → 148 · 92,4 · 2,0 = 184,8 → 185.
      expect(ProteinTarget.grams(92.4), (148, 185));
    });

    test('null Kilogramm ergibt null', () {
      expect(ProteinTarget.grams(0.0), isNull);
    });

    test('ein negatives Gewicht ergibt null', () {
      expect(ProteinTarget.grams(-5.0), isNull);
      expect(ProteinTarget.grams(-0.1), isNull);
    });

    test('ein winziges, aber positives Gewicht ergibt eine Spanne', () {
      // Die Grenze ist `<= 0`, nicht „unplausibel klein": 1 · 1,6 = 1,6 → 2
      // und 1 · 2,0 = 2,0 → 2. Unsinnig als Körpergewicht, aber der Kern
      // urteilt nicht über Plausibilität.
      expect(ProteinTarget.grams(1.0), (2, 2));
    });
  });
}
