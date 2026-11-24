import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Die Frage der Alkohol-Zeile ist seit #268 eine andere: **nicht, wann
/// zuletzt getrunken wurde, sondern ob am Vortag des gezeigten Tages
/// etwas erfasst ist.**
///
/// Tim am 03.11.2026: „wenn ich den Schirm heute angucke, steht da, ob ich
/// gestern getrunken habe. Das ist das, was ich wissen will — nicht wann
/// zuletzt." Alkohol drückt die Erholung der **folgenden** Nacht; „zuletzt
/// am 2. November" sagt über die Nacht auf den 28. Oktober nichts.
///
/// ## Die Regel, ausgeschrieben
///
/// „Alkohol am Vortag" heißt **mehr als nichts**, genau wie bei
/// [AlcoholDays.from] (#125) — keine zweite Schwelle, kein Richtwert.
/// Der Vortag ist der Berliner Kalendertag vor dem gewählten.
///
/// ## Drei Zustände, nicht zwei
///
/// „Nein" und „nicht erfasst" sind zwei verschiedene Dinge. Ein „nein",
/// das in Wahrheit „keine Daten" heißt, wäre Fehler `01` in klein.
/// Deshalb trägt [AlcoholEve] drei Fälle, und sie entsprechen eins zu eins
/// den drei Fällen, die [AlcoholDays] schon immer unterscheidet:
///
/// | Getränke am Vortag | [AlcoholEve] |
/// |---|---|
/// | größer 0 | `drinks` |
/// | genau 0 — gemessen, nichts | `noDrinks` |
/// | kein Wert | `unknown` |
///
/// **`unknown` ist der Normalfall, und das ist kein Mangel.** Apple Health
/// legt für `NumberOfAlcoholicBeverages` nur dann eine Probe an, wenn etwas
/// getrunken wurde; eine fehlende Freigabe sieht genauso aus. Eine gemessene
/// Null kommt nur von einem Tagebuch, das sie ausdrücklich schreibt. Dass
/// `noDrinks` heute selten entsteht, ändert nichts daran, dass es der
/// einzige Fall ist, in dem „nein" belegt ist.
///
/// ## Der Vortag wird roh nachgeschlagen, nicht im Fenster
///
/// Der Betrachtungszeitraum schneidet die **Zahl** der Alkohol-Tage; die
/// Auskunft über den Vortag ist eine Auskunft über genau einen Tag. Liegt
/// der Vortag eine Nacht vor dem Fensteranfang und ist für ihn etwas
/// übergeben worden, wird es benutzt. Zwei verschiedene Mengen in einer
/// Zeile sind der Fehler, den #266 behandelt — hier sind es zwei
/// verschiedene Fragen, und sie stehen getrennt.
///
/// Alle Tage und Zahlen sind erfunden.
void main() {
  /// Ein Berliner Kalendertag im Juli — Sommerzeit, also UTC+2, und weit
  /// von jeder Umstellung entfernt.
  DateTime juli(int tag, [int stundeUtc = 6]) =>
      DateTime.utc(2026, 7, tag, stundeUtc);

  DateTime julitag(int tag) => BerlinCalendar.startOfDay(juli(tag));

  ({DateTime date, double? drinks}) eintrag(DateTime date, double? drinks) =>
      (date: date, drinks: drinks);

  group('AlcoholDays.measuredZero — die gemessene Null', () {
    test('eine Null macht den Tag zu einem gemessenen Nicht-Trinktag', () {
      expect(AlcoholDays.measuredZero([eintrag(juli(14), 0)]), [julitag(14)]);
    });

    test('ein fehlender Wert tut das nicht', () {
      expect(AlcoholDays.measuredZero([eintrag(juli(14), null)]), isEmpty);
    });

    test('ein Tag mit Getränken erst recht nicht', () {
      expect(AlcoholDays.measuredZero([eintrag(juli(14), 2)]), isEmpty);
    });

    test('Null und Getränke am selben Tag: der Tag hat Alkohol', () {
      final eintraege = [eintrag(juli(14), 0), eintrag(juli(14), 2)];

      expect(
        AlcoholDays.measuredZero(eintraege),
        isEmpty,
        reason:
            'eine einzelne Null widerlegt nicht, was am selben Tag sonst '
            'noch erfasst ist',
      );
      expect(AlcoholDays.from(eintraege), [julitag(14)]);
    });

    test('ein negativer Wert ist ein Datenfehler und belegt nichts', () {
      expect(AlcoholDays.measuredZero([eintrag(juli(14), -1)]), isEmpty);
    });

    test('die Tage stehen aufsteigend, ohne Doppel, auf der Tagesgrenze', () {
      expect(
        AlcoholDays.measuredZero([
          // 20:00 UTC ist im Juli 22:00 in Berlin — noch derselbe Tag.
          // Ab 22:00 UTC wäre es schon der Folgetag.
          eintrag(juli(18, 20), 0),
          eintrag(juli(12, 3), 0),
          eintrag(juli(18, 5), 0),
        ]),
        [julitag(12), julitag(18)],
      );
    });

    test('die beiden Listen überschneiden sich nie', () {
      final eintraege = [
        eintrag(juli(12), 0),
        eintrag(juli(13), 1),
        eintrag(juli(14), null),
      ];

      final mit = AlcoholDays.from(eintraege);
      final ohne = AlcoholDays.measuredZero(eintraege);

      expect(mit, [julitag(13)]);
      expect(ohne, [julitag(12)]);
      expect(mit.toSet().intersection(ohne.toSet()), isEmpty);
    });
  });

  group('RecoverySnapshot.alcoholEve — der Abend davor', () {
    /// Bezugstag aller Fälle: 20.07.2026, mittags Berliner Zeit.
    final heute = juli(20, 10);

    RecoverySnapshot schnappschuss({
      List<DateTime> alcoholDays = const [],
      List<DateTime> alcoholFreeDays = const [],
      DateTime? selectedDay,
      DataWindow? window,
    }) => RecoverySnapshot.make(
      days: const [],
      nights: const [],
      today: heute,
      selectedDay: selectedDay,
      sleepGoalHours: 7.5,
      bedtimeGoalMinutes: 270,
      alcoholDays: alcoholDays,
      alcoholFreeDays: alcoholFreeDays,
      window: window,
    );

    test('ohne jede Angabe bleibt der Vortag unbekannt', () {
      expect(schnappschuss().alcoholEve, AlcoholEve.unknown);
    });

    test('ein Alkohol-Tag am Vortag heißt „ja"', () {
      expect(
        schnappschuss(alcoholDays: [juli(19, 19)]).alcoholEve,
        AlcoholEve.drinks,
      );
    });

    test('eine gemessene Null am Vortag heißt „nein"', () {
      expect(
        schnappschuss(alcoholFreeDays: [juli(19)]).alcoholEve,
        AlcoholEve.noDrinks,
      );
    });

    test('„nein" und „unbekannt" sind nicht dasselbe', () {
      expect(
        schnappschuss(alcoholFreeDays: [juli(19)]).alcoholEve,
        isNot(schnappschuss().alcoholEve),
        reason: 'ein „nein", das „keine Daten" heißt, ist Fehler 01 in klein',
      );
    });

    test(
      'ein Alkohol-Tag am gewählten Tag selbst sagt nichts über den Vortag',
      () {
        expect(
          schnappschuss(alcoholDays: [juli(20, 20)]).alcoholEve,
          AlcoholEve.unknown,
          reason:
              'Alkohol drückt die Erholung der folgenden Nacht, nicht der '
              'vergangenen',
        );
      },
    );

    test('ein Alkohol-Tag zwei Tage davor zählt auch nicht', () {
      expect(
        schnappschuss(alcoholDays: [juli(18)]).alcoholEve,
        AlcoholEve.unknown,
      );
    });

    test('widersprüchliche Angaben: Alkohol gewinnt', () {
      expect(
        schnappschuss(
          alcoholDays: [juli(19)],
          alcoholFreeDays: [juli(19)],
        ).alcoholEve,
        AlcoholEve.drinks,
        reason: 'von zwei Auskünften ist die belegte die stärkere',
      );
    });

    test('der Vortag wandert mit dem gewählten Tag', () {
      final alkohol = [juli(14)];

      expect(
        schnappschuss(alcoholDays: alkohol, selectedDay: juli(15)).alcoholEve,
        AlcoholEve.drinks,
      );
      expect(
        schnappschuss(alcoholDays: alkohol, selectedDay: juli(16)).alcoholEve,
        AlcoholEve.unknown,
      );
    });

    test('der Vortag kann vor dem Fensteranfang liegen und zählt doch', () {
      // Das Fenster beginnt am 18.07.; gewählt ist sein erster Tag, der
      // Vortag ist der 17.07. und liegt davor.
      final fenster = DataWindow(start: julitag(18));

      expect(
        schnappschuss(
          alcoholDays: [juli(17)],
          selectedDay: juli(18),
          window: fenster,
        ).alcoholEve,
        AlcoholEve.drinks,
        reason:
            'der Zeitraum schneidet die Zahl der Alkohol-Tage, nicht die '
            'Auskunft über einen einzelnen Tag',
      );
    });

    test('ein roher Zeitpunkt des Vortags ist derselbe Tag', () {
      expect(
        schnappschuss(alcoholDays: [juli(19, 21)]).alcoholEve,
        AlcoholEve.drinks,
        reason: '21:00 UTC ist am 19.07. in Berlin 23:00 — derselbe Tag',
      );
      expect(
        schnappschuss(alcoholDays: [juli(19, 22)]).alcoholEve,
        AlcoholEve.unknown,
        reason: '22:00 UTC ist in Berlin Mitternacht, also schon der 20.07.',
      );
    });

    test('über die Umstellung auf Winterzeit bleibt der Vortag der Vortag', () {
      // Die Sommerzeit endet am Sonntag, 25.10.2026, 01:00 UTC. Gewählt ist
      // der 25.10., der Vortag ist der 24.10. — noch Sommerzeit.
      final oktober = RecoverySnapshot.make(
        days: const [],
        nights: const [],
        today: DateTime.utc(2026, 10, 26, 10),
        selectedDay: DateTime.utc(2026, 10, 25, 10),
        sleepGoalHours: 7.5,
        bedtimeGoalMinutes: 270,
        alcoholDays: [DateTime.utc(2026, 10, 24, 20)],
      );

      expect(oktober.alcoholEve, AlcoholEve.drinks);
    });
  });

  group('Die Zahl im Zeitraum bleibt eine eigene Auskunft', () {
    final heute = juli(20, 10);

    RecoverySnapshot schnappschuss(List<DateTime> alkohol) =>
        RecoverySnapshot.make(
          days: const [],
          nights: const [],
          today: heute,
          sleepGoalHours: 7.5,
          bedtimeGoalMinutes: 270,
          alcoholDays: alkohol,
        );

    test('sie zählt weiter alle Tage im Zeitraum, nicht nur den Vortag', () {
      final s = schnappschuss([juli(12), juli(18), juli(19)]);
      final zeile = s.trends.firstWhere(
        (t) => t.kind == RecoveryTrendKind.alcoholDays,
      );

      expect(zeile.count, 3);
      expect(zeile.average, isNull);
      expect(s.alcoholEve, AlcoholEve.drinks);
    });

    test('ein Vortag ohne Alkohol lässt die Zahl unberührt', () {
      final s = schnappschuss([juli(12), juli(18)]);
      final zeile = s.trends.firstWhere(
        (t) => t.kind == RecoveryTrendKind.alcoholDays,
      );

      expect(zeile.count, 2);
      expect(s.alcoholEve, AlcoholEve.unknown);
    });
  });
}
