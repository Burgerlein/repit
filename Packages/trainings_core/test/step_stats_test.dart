import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Schritt-Kennzahlen des Schritte-Schirms** (#84): gestern,
/// Ø 7 Tage mit Trend zur Vorwoche, Ø 30 Tage, „Ziel erreicht x von y" und
/// Top-Tag. Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/StepStatistics.swift`
/// samt `StepStatisticsTests.swift`; dazu `docs/SPEC.md` 4.6 („Schritte:
/// Kennzahlen …").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert** — die Entscheidung trifft Tim oder der Test-Agent.
///
/// `StepStatistics.average7` aus `step_statistics_test.dart` bleibt
/// unangetastet; diese Datei erweitert das Modul um den vollen `StepStats`.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// final class StepStats {
///   final int? yesterday;
///   final int? average7;
///   /// Veränderung des Sieben-Tage-Schnitts gegen die sieben Tage davor,
///   /// in Prozent. `null`, wenn es eine der beiden Wochen nicht gibt.
///   final double? trendPercent;
///   final int? average30;
///   final int goalReached;
///   /// Nenner für „Ziel erreicht x von y". Nicht 30: Tage ohne Messung
///   /// sind keine Tage mit null Schritten.
///   final int daysWithData;
///   final int? best;
///   // == und hashCode über alle Felder — siehe Gruppe „Wertgleichheit".
/// }
///
/// abstract final class StepStatistics {
///   static StepStats make(
///     Map<String, int> stepsByDay, {
///     required int goal,
///     required DateTime now,
///   });
/// }
/// ```
///
/// Wie der Konstruktor von `StepStats` aussieht, legen diese Tests **nicht**
/// fest — alles läuft über `make`. Die Eingabeform ist dieselbe wie bei
/// [StepStatistics.average7] und genau die, die [StepMerge.daily]
/// zurückgibt: Tagesschlüssel aus [BerlinCalendar.dayKey] auf Schritte.
/// Ein ungemessener Tag ist ein **fehlender Schlüssel**, kein Eintrag mit
/// Wert `0` — der Wertetyp ist `int`, nicht `int?`, Fehler `01` ist in der
/// Eingabe nicht ausdrückbar. Die Swift-Vorlage nimmt `[DailyMetrics]` mit
/// `steps: Int?` und wirft `nil`-Tage in der Schleife weg
/// (`StepStatistics.swift:40`); hier gibt es die `nil`-Tage gar nicht erst.
///
/// ## Die Fenster, wie die Vorlage sie zieht
///
/// Alles rechnet **von gestern rückwärts**; der laufende Tag ist noch nicht
/// vorbei und zöge jeden Durchschnitt nach unten (`StepStatistics.swift:30`).
/// In Tagesabständen (1 ist gestern):
///
/// * `yesterday`: Abstand 1.
/// * `average7` und die junge Trend-Woche: Abstände 1–7.
/// * die Vergleichswoche des Trends: Abstände 8–14.
/// * `average30`, `goalReached`, `daysWithData`, `best`: Abstände 1–30.
///
/// **Der Nenner von „Ziel erreicht" ist `daysWithData`, nicht 30** — der
/// Swift-Code gewinnt gegen die SPEC-Formulierung „x/30" (so ausdrücklich in
/// #84, Begründung `StepsView.swift:64–66`: „Stand die Uhr zwei Wochen im
/// Schrank, wären ‚8 / 30' eine Behauptung über Tage, über die niemand etwas
/// weiß"). Die Zahl der **Tage ohne Messung**, die der Schirm dazusagt
/// (`bestText`, `StepsView.swift:72–79`), ist `30 − daysWithData` und
/// braucht kein eigenes Feld — die Gruppe „Ziel erreicht" rechnet sie vor.
///
/// Durchschnitte sind kaufmännisch gerundete Ganzzahlen (`.rounded()` in der
/// Vorlage, in Dart `round()`); der Trend bleibt ein `double` und wird erst
/// in der View formatiert.
///
/// ## Was hier bewusst **nicht** festgelegt wird
///
/// * Was bei einem **unlesbaren** Schlüssel passiert (etwa `"gestern"`) —
///   dieselbe offene Entscheidung wie in `step_statistics_test.dart`.
/// * Die Rundungsreihenfolge im Trend. Die Vorlage rechnet den Trend aus den
///   bereits gerundeten Wochenmitteln; alle Zahlen hier sind so gewählt,
///   dass beide Reihenfolgen dasselbe Ergebnis liefern.
///
/// **Alle Zahlen hier sind erfunden** und tragen keine Gesundheitsbedeutung.
/// Glatte Tausender, damit jedes Mittel im Kopf nachrechenbar bleibt.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — derselbe Zeitpunkt
  // wie in `step_statistics_test.dart`, damit die beiden Dateien über
  // derselben Lage reden. Die 30 Tage davor (12.09.–11.10.) liegen
  // vollständig in der Sommerzeit; die Umstellung am 25.10.2026 fällt in
  // keinen Abstand hinein.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  /// Das Schritteziel aller Tests, wie in `StepStatisticsTests.swift` und
  /// SPEC 3 (8.000). Erwartungswerte hängen nur über `goalReached` daran.
  const ziel = 8000;

  /// Der Tagesschlüssel des Berliner Tages, der [tage] Kalendertage vor dem
  /// Tag von [bezug] liegt. Über [BerlinCalendar.addDays], **nie** über
  /// `Duration(days: …)` — siehe die Gruppe zur Zeitumstellung.
  String schluesselVor(int tage, {DateTime? bezug}) => BerlinCalendar.dayKey(
    BerlinCalendar.addDays(BerlinCalendar.startOfDay(bezug ?? jetzt), -tage),
  );

  /// Eine Schrittkarte aus Tagesabständen: Schlüssel ist „vor wie vielen
  /// Tagen", 1 ist gestern, 0 ist der laufende Tag.
  Map<String, int> karte(Map<int, int> jeAbstand, {DateTime? bezug}) => {
    for (final eintrag in jeAbstand.entries)
      schluesselVor(eintrag.key, bezug: bezug): eintrag.value,
  };

  StepStats mache(Map<int, int> jeAbstand, {DateTime? bezug, int goal = ziel}) =>
      StepStatistics.make(
        karte(jeAbstand, bezug: bezug),
        goal: goal,
        now: bezug ?? jetzt,
      );

  // ─────────────────────────────────────────────────────────────────────

  group('Gestern', () {
    test('ist der Wert von gestern, nicht der von heute', () {
      // Dieselben Zahlen wie `yesterdayIsYesterday` in der Swift-Vorlage.
      final stats = mache({0: 2000, 1: 10613});

      expect(stats.yesterday, 10613);
    });

    test('bleibt leer, wenn gestern nicht gemessen wurde', () {
      // Vorgestern liegt ein Wert — der darf nicht als „gestern" einspringen.
      final stats = mache({2: 5000});

      expect(stats.yesterday, isNull);
      expect(stats.yesterday, isNot(0));
    });

    test('ein gemessener Nulltag gestern ist 0, nicht leer', () {
      // Uhr getragen, auf dem Sofa geblieben: eine Antwort, kein Loch.
      final stats = mache({1: 0});

      expect(stats.yesterday, 0);
      expect(stats.yesterday, isNotNull);
    });
  });

  group('Ø 7 Tage und der Trend zur Vorwoche', () {
    test('der Schnitt mittelt die Abstände 1 bis 7 ohne heute', () {
      // 1000 + … + 7000 = 28000, durch sieben ist 4000. Heute trägt 120 und
      // bleibt draußen; wer ihn mitrechnet, bekommt 3515.
      final stats = mache({for (var t = 1; t <= 7; t++) t: t * 1000, 0: 120});

      expect(stats.average7, 4000);
    });

    test('`make` und `average7` nennen dieselbe Zahl', () {
      // Zwei Wege, ein Vertrag: Die Kachel der Körper-Übersicht rechnet über
      // `StepStatistics.average7`, der Schritte-Schirm über `make`. Weichen
      // sie ab, zeigt die App zwei verschiedene „Ø 7 Tage".
      final werte = karte({1: 1000, 3: 2000, 6: 4000});

      expect(
        StepStatistics.make(werte, goal: ziel, now: jetzt).average7,
        StepStatistics.average7(werte, now: jetzt),
      );
    });

    test('der Trend vergleicht die letzten sieben Tage mit den sieben davor', () {
      // Dieselben Zahlen wie `trendComparesTwoWeeks` in der Swift-Vorlage:
      // (8480 − 8000) / 8000 = 6 %.
      final stats = mache({
        for (var t = 1; t <= 7; t++) t: 8480,
        for (var t = 8; t <= 14; t++) t: 8000,
      });

      expect(stats.trendPercent, isNotNull);
      expect(stats.trendPercent, closeTo(6.0, 0.001));
    });

    test('weniger als in der Vorwoche ist ein negativer Trend', () {
      // (7000 − 8000) / 8000 = −12,5 %. Das Vorzeichen trägt die Richtung;
      // die View macht daraus erst Pfeil und Betrag.
      final stats = mache({
        for (var t = 1; t <= 7; t++) t: 7000,
        for (var t = 8; t <= 14; t++) t: 8000,
      });

      expect(stats.trendPercent, closeTo(-12.5, 0.001));
    });

    test('ohne Vorwoche gibt es keinen Trend', () {
      // Kein Vergleichswert heißt kein Trend — und nicht „0 Prozent". Eine 0
      // behauptete „alles wie letzte Woche", über die niemand etwas weiß.
      final stats = mache({for (var t = 1; t <= 7; t++) t: 8480});

      expect(stats.trendPercent, isNull);
      expect(stats.trendPercent, isNot(0));
    });

    test('ohne junge Woche gibt es keinen Trend und keinen Ø 7', () {
      // Nur die Abstände 8 bis 14 sind gemessen. Ø 30 und Top-Tag leben
      // trotzdem — die Fenster sind unabhängig.
      final stats = mache({for (var t = 8; t <= 14; t++) t: 6000});

      expect(stats.average7, isNull);
      expect(stats.trendPercent, isNull);
      expect(stats.average30, 6000);
      expect(stats.best, 6000);
    });

    test('eine Vorwoche aus lauter Nulltagen ergibt keinen Trend', () {
      // Gemessen, aber null: Ein Anstieg von 0 auf 5000 ist kein Prozentsatz
      // — die Vorlage verlangt `before > 0` (`StepStatistics.swift:62`).
      final stats = mache({
        for (var t = 1; t <= 7; t++) t: 5000,
        for (var t = 8; t <= 14; t++) t: 0,
      });

      expect(stats.trendPercent, isNull);
    });

    test('die Vorwoche endet bei Abstand 14, Abstand 15 zählt nicht', () {
      // Beide Wochen je 8000, davor ein absurd hoher Tag. Rutscht er in die
      // Vorwoche, kippt der Trend ins Negative.
      final stats = mache({
        for (var t = 1; t <= 14; t++) t: 8000,
        15: 99000,
      });

      expect(stats.trendPercent, closeTo(0.0, 0.001));
    });

    test('der Trend rechnet je Woche über die gemessenen Tage', () {
      // In jeder Woche nur ein Messtag: 9000 gegen 8000 ist +12,5 %. Wer
      // Lücken als Nullen zählt, teilt durch sieben und bekommt dasselbe
      // Verhältnis nur zufällig — hier stünde sonst der Nenner 1142 ≈ 0 und
      // der Trend wäre grotesk.
      final stats = mache({1: 9000, 10: 8000});

      expect(stats.trendPercent, closeTo(12.5, 0.001));
    });
  });

  group('Ø 30 Tage', () {
    test('mittelt die gemessenen Tage der Abstände 1 bis 30', () {
      // Drei Messtage quer übers Fenster: 3000 + 6000 + 9000 durch drei ist
      // 6000. Als Nullen gezählt wären es 600 — ein Tag ohne Messung ist
      // kein Tag mit null Schritten.
      final stats = mache({2: 3000, 15: 6000, 29: 9000});

      expect(stats.average30, 6000);
    });

    test('Abstand 30 liegt im Fenster, Abstand 31 draußen', () {
      // Wie `olderThanThirtyDaysIsOutside` in der Swift-Vorlage: Der absurd
      // hohe Tag davor darf weder Mittel noch Top-Tag noch Nenner berühren.
      final stats = mache({30: 5000, 31: 99000});

      expect(stats.average30, 5000);
      expect(stats.best, 5000);
      expect(stats.daysWithData, 1);
    });

    test('gerundet wird kaufmännisch, genau die Hälfte geht nach oben', () {
      // 1000 und 1001 mitteln auf 1000,5.
      expect(mache({1: 1000, 20: 1001}).average30, 1001);
    });
  });

  group('Ziel erreicht — der Nenner ist `daysWithData`, nicht 30', () {
    test('fehlende Tage zählen weder als verfehlt noch in den Nenner', () {
      // Wie `missingDaysAreNotMissedGoals` in der Swift-Vorlage: drei
      // Messtage über dem Ziel, 27 Tage stand die Uhr im Schrank. „3 / 30"
      // wäre eine Behauptung über Tage, über die niemand etwas weiß
      // (`StepsView.swift:64–66`; der Swift-Code gewinnt gegen SPEC „x/30").
      final stats = mache({1: 9000, 2: 9000, 3: 9000});

      expect(stats.goalReached, 3);
      expect(stats.daysWithData, 3);
      // Die Zahl der Tage ohne Messung, die der Schirm dazusagt, fällt
      // daraus ohne eigenes Feld ab: 30 − 3 = 27.
      expect(30 - stats.daysWithData, 27);
    });

    test('genau das Ziel gilt als erreicht, knapp darunter nicht', () {
      final stats = mache({1: 8000, 2: 7999});

      expect(stats.goalReached, 1);
      expect(stats.daysWithData, 2);
    });

    test('ein gemessener Nulltag steht im Nenner, nicht im Zähler', () {
      // Genau hier liegt die Unterscheidung, um die es in #84 geht: Der
      // Nulltag ist ein Messtag (Ruhetag auf dem Sofa), der fehlende Tag
      // nicht. {0, 9000} heißt „1 von 2" — nicht „1 von 1" und nicht
      // „1 von 30".
      final stats = mache({1: 0, 2: 9000});

      expect(stats.goalReached, 1);
      expect(stats.daysWithData, 2);
    });

    test('gezählt wird über alle 30 Tage, nicht nur über die Woche', () {
      // Ein einziger Messtag tief im Monat erreicht das Ziel.
      final stats = mache({20: 9000});

      expect(stats.goalReached, 1);
      expect(stats.daysWithData, 1);
    });

    test('ein anderes Ziel ändert nur den Zähler', () {
      final werte = {1: 9000, 2: 7000};

      expect(mache(werte, goal: 8000).goalReached, 1);
      expect(mache(werte, goal: 6000).goalReached, 2);
      expect(mache(werte, goal: 6000).daysWithData, 2);
    });
  });

  group('Top-Tag', () {
    test('ist der höchste Wert im 30-Tage-Fenster, egal wo er liegt', () {
      // Wie `bestIsTheHighestInTheWindow` in der Swift-Vorlage: ein
      // Ausreißer bei Abstand 13 zwischen lauter 7000ern.
      final stats = mache({
        for (var t = 1; t <= 30; t++) t: 7000,
        13: 14902,
      });

      expect(stats.best, 14902);
    });

    test('heute zählt nicht mit, auch wenn heute der beste Tag wäre', () {
      // Der laufende Tag ist noch nicht vorbei; sein Zwischenstand ist kein
      // Tagesergebnis. Er fehlt in allen Fenstern, nicht nur im Schnitt.
      final stats = mache({0: 50000, 1: 6000});

      expect(stats.best, 6000);
      expect(stats.daysWithData, 1);
      expect(stats.average30, 6000);
    });

    test('ein einziger gemessener Nulltag hat den Top-Tag 0, nicht keinen', () {
      // Gemessen und null ist eine Antwort. `null` hieße „nie gemessen" —
      // das wäre Fehler `01` im Kleinen.
      final stats = mache({1: 0});

      expect(stats.best, 0);
      expect(stats.best, isNotNull);
      expect(stats.average7, 0);
      expect(stats.average30, 0);
      expect(stats.daysWithData, 1);
      expect(stats.goalReached, 0);
    });
  });

  group('Ränder', () {
    test('ganz ohne Daten bleibt alles leer statt null', () {
      // Wie `noDataLeavesEverythingEmpty` in der Swift-Vorlage. Die Zähler
      // sind echte Nullen — null erreichte Ziele an null Messtagen ist eine
      // Aussage —, die Werte sind `null`, nie `0`.
      final stats = StepStatistics.make(const {}, goal: ziel, now: jetzt);

      expect(stats.yesterday, isNull);
      expect(stats.average7, isNull);
      expect(stats.trendPercent, isNull);
      expect(stats.average30, isNull);
      expect(stats.best, isNull);
      expect(stats.goalReached, 0);
      expect(stats.daysWithData, 0);
    });

    test('nur der laufende Tag ist so leer wie gar keine Daten', () {
      final stats = mache({0: 9000});

      expect(stats.yesterday, isNull);
      expect(stats.average7, isNull);
      expect(stats.average30, isNull);
      expect(stats.best, isNull);
      expect(stats.daysWithData, 0);
    });

    test('ein Tag in der Zukunft zählt nirgends mit', () {
      // Die Vorlage verlangt `offset >= 1`; ein Tag nach heute hat einen
      // negativen Abstand und fällt überall heraus.
      final stats = mache({-1: 99000});

      expect(stats.yesterday, isNull);
      expect(stats.average30, isNull);
      expect(stats.best, isNull);
      expect(stats.daysWithData, 0);
    });

    test('ein einziger Messtag füllt alle Werte mit sich selbst', () {
      final stats = mache({1: 8000});

      expect(stats.yesterday, 8000);
      expect(stats.average7, 8000);
      expect(stats.average30, 8000);
      expect(stats.best, 8000);
      expect(stats.goalReached, 1);
      expect(stats.daysWithData, 1);
      expect(stats.trendPercent, isNull);
    });
  });

  group('Wertgleichheit', () {
    // `StepStats` wird die Abhängigkeit eines abgeleiteten Providers. Ohne
    // `==` und `hashCode` ist jedes neu gebaute Exemplar ungleich dem
    // vorigen, und jeder abgeleitete Wert rechnet je Bild neu — das wäre
    // Fehler `03`, wortgleich, im neuen Code (`CLAUDE.md`, „Ein Werttyp, der
    // Abhängigkeit eines Providers ist, braucht `==` und `hashCode`").

    test('dieselbe Lage ergibt gleiche Werte mit gleichem Hash', () {
      final lage = {1: 9000, 5: 3000, 12: 0, 28: 11000};

      final einmal = mache(lage);
      final nochmal = mache(lage);

      expect(nochmal, equals(einmal));
      expect(nochmal.hashCode, einmal.hashCode);
      expect(identical(einmal, nochmal), isFalse);
    });

    test('ein anderes Ziel ergibt ungleiche Werte', () {
      final lage = {1: 7000};

      expect(mache(lage, goal: 8000), isNot(equals(mache(lage, goal: 6000))));
    });
  });

  group('Über eine Zeitumstellung hinweg', () {
    test('die Monatskante zählt Kalendertage, keine 24-Stunden-Schritte', () {
      // Berliner Donnerstag, 05.11.2026, 09:00 (CET, +1). Die Umstellung am
      // 25.10. liegt mitten im 30-Tage-Fenster. Die Lage der Fixture
      // ausdrücklich festgehalten — sie ist die halbe Aussage dieses Tests.
      final nachUmstellung = DateTime.utc(2026, 11, 5, 8);

      expect(schluesselVor(30, bezug: nachUmstellung), '2026-10-06');
      expect(schluesselVor(31, bezug: nachUmstellung), '2026-10-05');

      final stats = mache({30: 5000, 31: 99000}, bezug: nachUmstellung);

      // Wer die Kante über `Duration(days: 30)` zieht, verliert den 06.10.
      // und holt den 05.10. mit seinen 99000 Schritten herein.
      expect(stats.average30, 5000);
      expect(stats.best, 5000);
      expect(stats.daysWithData, 1);
    });

    test('die Wochenkante des Trends übersteht das Ende der Sommerzeit', () {
      // Berliner Mittwoch, 28.10.2026, 09:00 (CET, +1): Die junge Woche
      // (21.–27.10.) enthält die Umstellung, die Vorwoche (14.–20.10.) nicht.
      final nachUmstellung = DateTime.utc(2026, 10, 28, 8);

      expect(schluesselVor(7, bezug: nachUmstellung), '2026-10-21');
      expect(schluesselVor(14, bezug: nachUmstellung), '2026-10-14');

      final stats = mache({
        for (var t = 1; t <= 7; t++) t: 9000,
        for (var t = 8; t <= 14; t++) t: 8000,
      }, bezug: nachUmstellung);

      expect(stats.average7, 9000);
      expect(stats.trendPercent, closeTo(12.5, 0.001));
    });
  });
}
