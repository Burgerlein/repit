import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Sieben-Tage-Schnitt der Schritte** — die eine Zahl hinter
/// der Körper-Kachel „Schritte Ø 7 Tage" (#202, Teil C; Spec
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Feld `schritteSchnitt7`). Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/StepStatistics.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert** — die Entscheidung trifft Tim oder der Test-Agent.
///
/// Die Rechnung lag zwischenzeitlich in der Shell-Schicht. Das war falsch:
/// Jede Formel bekommt ihren Test **im Kern**, sonst beweist sie die
/// Importgrenze nicht mehr mit (`CLAUDE.md`, „Tests"). Diese Datei holt das
/// nach.
///
/// Importiert wird das Barrel `package:trainings_core/trainings_core.dart` —
/// der neue Export aus `lib/trainings_core.dart` gehört zur Lieferung, sonst
/// fiele sein Fehlen erst der App auf.
///
/// ## Nur `average7`, der Rest kommt mit #84
///
/// Die Swift-Vorlage liefert einen ganzen `StepStats`-Typ: `yesterday`,
/// `trendPercent`, `average30`, `goalReached`, `daysWithData` und `best`.
/// **Davon wird hier nichts festgelegt.** Diese sechs gehören zum
/// Schritte-Schirm und kommen mit Ticket #84; sie jetzt zu pinnen hieße,
/// einen Vertrag zu schreiben, den niemand gelesen hat. Festgelegt wird
/// genau das Stück, das die Körper-Kachel heute braucht.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class StepStatistics {
///   /// Das Mittel der Schritte über die sieben Kalendertage **vor** dem
///   /// Berliner Tag von [now]. `null`, wenn im Fenster kein einziger Tag
///   /// gemessen wurde.
///   static int? average7(
///     Map<String, int> stepsByDay, {
///     required DateTime now,
///   });
/// }
/// ```
///
/// ### Warum `Map<String, int>` und nicht `DailyMetrics`
///
/// `DailyMetrics` ist die **Nutzlast des Platform-Channels** und liegt in
/// `app/lib/health/health_types.dart`. Es trägt dreizehn Felder aus
/// HealthKit und keine Rechnung; `CLAUDE.md` sagt dazu ausdrücklich
/// „Transporttypen gehören nicht in den Kern. Der Kern trägt Rechnungen."
/// Die Swift-Vorlage darf `[DailyMetrics]` nehmen, weil der Typ dort im
/// selben Paket liegt — in Dart tut er das nicht, und ein Nachbau im Kern
/// bräche beim Übersetzen der App am gleichnamigen Export.
///
/// Gewählt ist deshalb **Tagesschlüssel auf Schritte**, und zwar genau die
/// Form, die `StepMerge.daily` bereits **zurückgibt**
/// (`lib/src/step_merge.dart`): Schlüssel ist der ISO-Tagesstring aus
/// [BerlinCalendar.dayKey], Wert die Schrittzahl des Tages. Damit lässt
/// sich die Zusammenführung der Schrittquellen ohne Zwischenstück in den
/// Schnitt stecken, und die App bildet ihr `DailyMetrics` darauf ab.
///
/// Drei Dinge fallen bei dieser Form von selbst ab:
///
/// * **Ein Tag ohne Messung ist ein fehlender Schlüssel**, kein Eintrag mit
///   Wert `0`. Genau das ist der Unterschied, an dem Fehler `01` hängt —
///   und hier ist er nicht ausdrückbar, weil der Typ `int` und nicht `int?`
///   ist.
/// * **Ein Tag kann nicht doppelt vorkommen.** Die Swift-Vorlage schreibt
///   `byOffset[offset] = steps` in der Schleife; bei zwei Einträgen zum
///   selben Tag gewinnt still der letzte. Eine `Map` kennt das Problem
///   nicht.
/// * **Der Tagesschlüssel ist eine Kalenderangabe, kein Zeitpunkt**
///   (`CLAUDE.md`, „Der Datumsschlüssel ist der ISO-Tagesstring"). Die
///   Abstandsrechnung läuft über [BerlinCalendar.daysBetween] und übersteht
///   damit jede Zeitumstellung — siehe die Gruppe ganz unten.
///
/// ## Was hier bewusst **nicht** festgelegt wird
///
/// Was bei einem **unlesbaren** Schlüssel passieren soll (etwa `"gestern"`),
/// steht hier nicht. Die Eingabe kommt aus [BerlinCalendar.dayKey] bzw. aus
/// der Datenbankspalte und ist immer wohlgeformt; ob ein kaputter Schlüssel
/// übergangen wird oder wirft, ist eine offene Entscheidung, und eine
/// erfundene Erwartung wäre schlimmer als keine.
///
/// **Alle Zahlen hier sind erfunden** und tragen keine Gesundheitsbedeutung.
/// Glatte Tausender sind gewählt, damit jedes Mittel im Kopf nachrechenbar
/// bleibt.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie in
  // `app/test/shell/koerper_zustand_test.dart`, damit die beiden Verträge
  // über derselben Lage reden. Als UTC-Zeitpunkt, der eine Berliner Uhrzeit
  // bezeichnet.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  /// Der Tagesschlüssel des Berliner Tages, der [tage] Kalendertage vor dem
  /// Tag von [bezug] liegt. Über [BerlinCalendar.addDays], **nie** über
  /// `Duration(days: …)`: Die Nacht zum 25.10.2026 hat 25 Stunden, die zum
  /// 29.03.2026 deren 23.
  String schluesselVor(int tage, {DateTime? bezug}) => BerlinCalendar.dayKey(
    BerlinCalendar.addDays(BerlinCalendar.startOfDay(bezug ?? jetzt), -tage),
  );

  /// Eine Schrittkarte aus Tagesabständen: Schlüssel ist „vor wie vielen
  /// Tagen", 1 ist gestern, 0 ist der laufende Tag.
  Map<String, int> karte(Map<int, int> jeAbstand, {DateTime? bezug}) => {
    for (final eintrag in jeAbstand.entries)
      schluesselVor(eintrag.key, bezug: bezug): eintrag.value,
  };

  // ─────────────────────────────────────────────────────────────────────

  group('Das Fenster ist gestern rückwärts', () {
    test('die sieben Tage vor heute, der laufende Tag bleibt draußen', () {
      // 1000 + 2000 + … + 7000 = 28000, geteilt durch sieben ist 4000.
      // Der laufende Tag trägt 120 Schritte — es ist 09:15, der Tag ist
      // noch nicht vorbei und zöge jeden Durchschnitt nach unten
      // (`StepStatistics.swift:30–31`). Wer ihn mitrechnet, bekommt 3515.
      //
      // Derselbe Fall steht in `koerper_zustand_test.dart` („das Mittel der
      // sieben Tage **vor** heute"); dort ist er der Vertrag der Shell, hier
      // der des Kerns.
      final ergebnis = StepStatistics.average7(
        karte({for (var t = 1; t <= 7; t++) t: t * 1000, 0: 120}),
        now: jetzt,
      );

      expect(ergebnis, 4000);
    });

    test('gestern liegt im Fenster', () {
      expect(StepStatistics.average7(karte({1: 6400}), now: jetzt), 6400);
    });

    test('der siebte Tag zurück liegt noch im Fenster', () {
      expect(StepStatistics.average7(karte({7: 6400}), now: jetzt), 6400);
    });

    test('der achte Tag zurück liegt draußen', () {
      // Sieben gleiche Tage im Fenster, davor ein absurd hoher Tag. Wer die
      // Kante um einen Tag zu weit zieht, bekommt 13250 statt 1000.
      final ergebnis = StepStatistics.average7(
        karte({for (var t = 1; t <= 7; t++) t: 1000, 8: 99000}),
        now: jetzt,
      );

      expect(ergebnis, 1000);
    });

    test('der laufende Tag allein ergibt keinen Schnitt', () {
      // Auch dieser Fall steht in `koerper_zustand_test.dart`: „heute allein
      // ergibt keinen Sieben-Tage-Schnitt — und eine 0 behauptete einen".
      final ergebnis = StepStatistics.average7(karte({0: 9000}), now: jetzt);

      expect(ergebnis, isNull);
      expect(ergebnis, isNot(0));
    });

    test('ein Tag in der Zukunft zählt nicht mit', () {
      // Die Vorlage verlangt `offset >= 1`. Ein Tag nach heute hat einen
      // negativen Abstand und fällt damit heraus — zusammen mit dem
      // laufenden Tag bleibt hier nichts übrig.
      final ergebnis = StepStatistics.average7(
        karte({-1: 99000, 0: 99000}),
        now: jetzt,
      );

      expect(ergebnis, isNull);
    });

    test('die Reihenfolge der Einträge ändert nichts', () {
      final aufsteigend = StepStatistics.average7(
        karte({1: 1000, 2: 2000, 3: 3000}),
        now: jetzt,
      );
      final durcheinander = StepStatistics.average7(
        karte({2: 2000, 3: 3000, 1: 1000}),
        now: jetzt,
      );

      expect(aufsteigend, 2000);
      expect(durcheinander, aufsteigend);
    });
  });

  group('Tage ohne Messung zählen nicht in den Nenner', () {
    test(
      'zwei gemessene Tage werden durch zwei geteilt, nicht durch sieben',
      () {
        // Derselbe Fall wie in `koerper_zustand_test.dart`: Mittel aus 1000
        // und 1001 ist 1000,5 und wird kaufmännisch gerundet. Wer durch sieben
        // teilt, bekommt 286 — ein Tag ohne Wert ist kein Tag mit null
        // Schritten (`StepStatistics.swift:11–12`).
        final ergebnis = StepStatistics.average7(
          karte({1: 1000, 2: 1001}),
          now: jetzt,
        );

        expect(ergebnis, 1001);
      },
    );

    test('eine Lücke mitten im Fenster verschiebt den Schnitt nicht', () {
      // Gemessen an Tag 1, 4 und 7, dazwischen nichts: 1000 + 2000 + 3000
      // durch drei ist 2000. Als Nullen gezählt wären es 857.
      final ergebnis = StepStatistics.average7(
        karte({1: 1000, 4: 2000, 7: 3000}),
        now: jetzt,
      );

      expect(ergebnis, 2000);
    });

    test('ein gemessener Tag mit null Schritten zählt sehr wohl mit', () {
      // Hier liegt die ganze Unterscheidung: Ein Tag **ohne Schlüssel** ist
      // ungemessen, ein Tag mit Wert `0` ist gemessen und ergab null
      // Schritte — ein Ruhetag auf dem Sofa. Mittel aus 0 und 1000 ist 500.
      // Wer den Nulltag wie eine Lücke behandelt, bekommt 1000 und
      // beschönigt die Woche.
      final ergebnis = StepStatistics.average7(
        karte({1: 0, 2: 1000}),
        now: jetzt,
      );

      expect(ergebnis, 500);
    });

    test('alle sieben Tage auf null ergeben null Schritte, nicht `null`', () {
      // Gemessen und tatsächlich null — das ist eine Antwort, kein
      // fehlender Wert. `null` wäre hier falsch herum.
      final ergebnis = StepStatistics.average7(
        karte({for (var t = 1; t <= 7; t++) t: 0}),
        now: jetzt,
      );

      expect(ergebnis, 0);
      expect(ergebnis, isNotNull);
    });
  });

  group('Kaufmännisch gerundet', () {
    test('genau die Hälfte geht nach oben', () {
      // 100 und 101 mitteln auf 100,5.
      expect(StepStatistics.average7(karte({1: 100, 2: 101}), now: jetzt), 101);
    });

    test('unter der Hälfte geht nach unten', () {
      // 1000 + 1000 + 1001 durch drei ist 1000,333…
      final ergebnis = StepStatistics.average7(
        karte({1: 1000, 2: 1000, 3: 1001}),
        now: jetzt,
      );

      expect(ergebnis, 1000);
    });

    test('über der Hälfte geht nach oben', () {
      // 1000 + 1001 + 1001 durch drei ist 1000,666…
      final ergebnis = StepStatistics.average7(
        karte({1: 1000, 2: 1001, 3: 1001}),
        now: jetzt,
      );

      expect(ergebnis, 1001);
    });

    test('ein glattes Mittel bleibt glatt', () {
      final ergebnis = StepStatistics.average7(
        karte({1: 8000, 2: 10000}),
        now: jetzt,
      );

      expect(ergebnis, 9000);
    });
  });

  group('`null`, wenn im Fenster kein einziger Wert liegt', () {
    test('eine leere Karte', () {
      final ergebnis = StepStatistics.average7(const {}, now: jetzt);

      expect(ergebnis, isNull);
      // Eine 0 behauptete „keinen Schritt getan" — das ist Fehler `01` in
      // Rechenform (`CLAUDE.md`, „`0` ist keine Antwort auf ‚kein Wert'").
      expect(ergebnis, isNot(0));
    });

    test('nur Tage außerhalb des Fensters', () {
      final ergebnis = StepStatistics.average7(
        karte({8: 9000, 20: 12000, 30: 11000}),
        now: jetzt,
      );

      expect(ergebnis, isNull);
      expect(ergebnis, isNot(0));
    });
  });

  group('Über eine Zeitumstellung hinweg', () {
    // Beide Fälle hier sind genau die, an denen `Duration(days: 7)` eine
    // Stunde danebenliegt. Erwartet ist in beiden 2000 — ein Fehler
    // verschiebt das Fenster um einen Tag und holt den absurd hohen Nachbarn
    // herein.

    test('Ende der Sommerzeit: der 25.10.2026 hat 25 Stunden', () {
      // Berliner Mittwoch, 28.10.2026, 09:00 (CET, +1). Das Fenster sind
      // der 21. bis 27. Oktober, die Umstellung liegt mitten darin.
      final nachUmstellung = DateTime.utc(2026, 10, 28, 8);

      // Die Lage der Fixture ausdrücklich festgehalten — sie ist die halbe
      // Aussage dieses Tests.
      expect(schluesselVor(7, bezug: nachUmstellung), '2026-10-21');
      expect(schluesselVor(8, bezug: nachUmstellung), '2026-10-20');

      final ergebnis = StepStatistics.average7(
        karte({
          7: 8000,
          for (var t = 1; t <= 6; t++) t: 1000,
          8: 99000,
        }, bezug: nachUmstellung),
        now: nachUmstellung,
      );

      // (8000 + 6 × 1000) / 7 = 2000. Wer die Kante über eine feste Dauer
      // zieht, verliert den 21.10. und bekommt 1000.
      expect(ergebnis, 2000);
    });

    test('Beginn der Sommerzeit: der 29.03.2026 hat 23 Stunden', () {
      // Berliner Mittwoch, 01.04.2026, 09:00 (CEST, +2). Das Fenster sind
      // der 25. bis 31. März.
      final nachUmstellung = DateTime.utc(2026, 4, 1, 7);

      expect(schluesselVor(7, bezug: nachUmstellung), '2026-03-25');
      expect(schluesselVor(8, bezug: nachUmstellung), '2026-03-24');

      final ergebnis = StepStatistics.average7(
        karte({
          7: 8000,
          for (var t = 1; t <= 6; t++) t: 1000,
          8: 99000,
        }, bezug: nachUmstellung),
        now: nachUmstellung,
      );

      // Wer die Tage über `Duration(days: …)` abzählt, rutscht hier um einen
      // Tag nach hinten: Er verliert den 25.03. und zieht den 24.03. mit
      // seinen 99000 Schritten herein — das Ergebnis wäre 15000.
      expect(ergebnis, 2000);
    });

    test('die Uhrzeit von `now` ändert das Fenster nicht', () {
      // Früher Morgen und später Abend desselben Berliner Tages müssen
      // dasselbe Fenster ergeben. Wer von `now` selbst zurückrechnet statt
      // vom Berliner Tagesbeginn, verliert je nach Tageszeit den ältesten
      // Tag.
      final frueh = DateTime.utc(2026, 10, 12, 4, 30); // 06:30 Berlin
      final spaet = DateTime.utc(2026, 10, 12, 20, 45); // 22:45 Berlin

      final werte = karte({for (var t = 1; t <= 7; t++) t: t * 1000});

      expect(StepStatistics.average7(werte, now: frueh), 4000);
      expect(StepStatistics.average7(werte, now: spaet), 4000);
    });
  });
}
