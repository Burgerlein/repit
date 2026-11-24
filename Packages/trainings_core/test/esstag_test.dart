import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/esstag.dart` — Task 1 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`
/// (#363), Spec `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitt „Die Rechnungen im Kern", Vorgabe V3.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// String esstag(DateTime utc);
/// DateTime naechsterEsstagBeginn(DateTime utc); // UTC
/// ```
///
/// ## Die Regel (V3, Tim 05.11.2026: „erst mal 4 Uhr")
///
/// Ist es auf der **Berliner Wanduhr** vor 04:00, ist der Esstag der
/// Kalendertag davor, sonst der Kalendertag selbst. **04:00 gehört dem neuen
/// Tag.** `naechsterEsstagBeginn` ist die nächste Berliner 04:00 **nach**
/// dem Zeitpunkt; um genau 04:00 also die des Folgetags. Gerechnet über den
/// Kalender, nie über `+ 24 h`: Am Tag der Umstellung im März liegen
/// zwischen zwei 04:00 23 Stunden, im Oktober 25.
///
/// Alle Zeitpunkte unten sind UTC und ergeben den Fall erst über die
/// Wanduhr — 22:30 UTC im Juli ist in Berlin schon 00:30 des Folgetags.
/// Die Jahre (2027, 2028) sind frei gewählt; die nachgebildete
/// Sommerzeitregel gilt ab 1996. Letzter Sonntag im März 2027 ist der 28.,
/// im Oktober 2027 der 31.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - Das Ergebnis von `naechsterEsstagBeginn` wird mit `DateTime.utc(…)`
///   verglichen. Dartsches `==` beachtet `isUtc`, ein lokaler `DateTime`
///   desselben Zeitpunkts fällt also durch. Die Spec sagt „UTC", der Test
///   nimmt sie beim Wort.
/// - Die Gruppe „Eigenschaften über ein ganzes Jahr" prüft im
///   Viertelstundentakt, was aus der Regel folgt (Ergebnis liegt danach,
///   steht auf 04:00 Wanduhr, ist genau ein Esstag weiter). Sie ist keine
///   Zeile der Spec, sondern deren Folge.
void main() {
  group('esstag — Winter (UTC+1)', () {
    test('03:59 Berlin gehört zum Vortag', () {
      // 14.01.2027 03:59 Berlin = 02:59 UTC
      expect(esstag(DateTime.utc(2027, 1, 14, 2, 59)), '2027-01-13');
    });

    test('04:00 Berlin gehört zum Kalendertag selbst', () {
      // 14.01.2027 04:00 Berlin = 03:00 UTC
      expect(esstag(DateTime.utc(2027, 1, 14, 3, 0)), '2027-01-14');
    });

    test('02:30 UTC ist im Winter 03:30 Berlin — noch der Vortag', () {
      expect(esstag(DateTime.utc(2027, 1, 14, 2, 30)), '2027-01-13');
    });

    test('00:30 Berlin (23:30 UTC am Vorabend) gehört zum Vortag', () {
      // 13.01.2027 23:30 UTC = 14.01.2027 00:30 Berlin → Esstag 13.01.
      expect(esstag(DateTime.utc(2027, 1, 13, 23, 30)), '2027-01-13');
    });

    test('23:59 Berlin gehört zum Kalendertag selbst', () {
      // 14.01.2027 23:59 Berlin = 22:59 UTC
      expect(esstag(DateTime.utc(2027, 1, 14, 22, 59)), '2027-01-14');
    });

    test('vor 04:00 am Neujahrsmorgen ist der Esstag Silvester', () {
      // 01.01.2027 03:00 Berlin = 02:00 UTC
      expect(esstag(DateTime.utc(2027, 1, 1, 2, 0)), '2026-12-31');
    });

    test('vor 04:00 am Monatsersten ist der Esstag der Monatsletzte', () {
      // 01.03.2027 01:00 Berlin = 00:00 UTC; 2027 ist kein Schaltjahr
      expect(esstag(DateTime.utc(2027, 3, 1, 0, 0)), '2027-02-28');
    });
  });

  group('esstag — Sommer (UTC+2)', () {
    test('03:59 Berlin gehört zum Vortag', () {
      // 15.07.2027 03:59 Berlin = 01:59 UTC
      expect(esstag(DateTime.utc(2027, 7, 15, 1, 59)), '2027-07-14');
    });

    test('04:00 Berlin gehört zum Kalendertag selbst', () {
      // 15.07.2027 04:00 Berlin = 02:00 UTC
      expect(esstag(DateTime.utc(2027, 7, 15, 2, 0)), '2027-07-15');
    });

    test('22:30 UTC im Juli ist 00:30 Berlin — Esstag ist der UTC-Tag', () {
      // 14.07.2027 22:30 UTC = 15.07.2027 00:30 Berlin → Esstag 14.07.
      expect(esstag(DateTime.utc(2027, 7, 14, 22, 30)), '2027-07-14');
    });

    test('02:30 UTC ist im Sommer 04:30 Berlin — schon der neue Tag', () {
      // Dieselbe UTC-Uhrzeit wie im Wintertest, anderes Ergebnis: Nur die
      // Wanduhr entscheidet.
      expect(esstag(DateTime.utc(2027, 7, 15, 2, 30)), '2027-07-15');
    });

    test('Mittag gehört zum Kalendertag selbst', () {
      expect(esstag(DateTime.utc(2027, 7, 15, 10, 0)), '2027-07-15');
    });
  });

  group('esstag — an den Tagen der Zeitumstellung', () {
    test('März: 01:30 CET (00:30 UTC) gehört zum Vortag', () {
      expect(esstag(DateTime.utc(2027, 3, 28, 0, 30)), '2027-03-27');
    });

    test('März: 03:30 CEST (01:30 UTC, nach der Umstellung) → Vortag', () {
      expect(esstag(DateTime.utc(2027, 3, 28, 1, 30)), '2027-03-27');
    });

    test('März: 04:00 CEST (02:00 UTC) → der Umstellungstag', () {
      expect(esstag(DateTime.utc(2027, 3, 28, 2, 0)), '2027-03-28');
    });

    test('Oktober: das zweite 02:30 (01:30 UTC, schon CET) → Vortag', () {
      expect(esstag(DateTime.utc(2027, 10, 31, 1, 30)), '2027-10-30');
    });

    test('Oktober: 03:59 CET (02:59 UTC) → Vortag', () {
      expect(esstag(DateTime.utc(2027, 10, 31, 2, 59)), '2027-10-30');
    });

    test('Oktober: 04:00 CET (03:00 UTC) → der Umstellungstag', () {
      expect(esstag(DateTime.utc(2027, 10, 31, 3, 0)), '2027-10-31');
    });
  });

  group('naechsterEsstagBeginn', () {
    test('um 21:00 Berlin → 04:00 am nächsten Morgen (Winter)', () {
      // 14.01.2027 21:00 Berlin = 20:00 UTC → 15.01. 04:00 = 03:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 1, 14, 20, 0)),
        DateTime.utc(2027, 1, 15, 3, 0),
      );
    });

    test('um 21:00 Berlin → 04:00 am nächsten Morgen (Sommer)', () {
      // 14.07.2027 21:00 Berlin = 19:00 UTC → 15.07. 04:00 = 02:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 7, 14, 19, 0)),
        DateTime.utc(2027, 7, 15, 2, 0),
      );
    });

    test('um 02:00 Berlin → 04:00 am selben Kalendertag', () {
      // 15.01.2027 02:00 Berlin = 01:00 UTC → 15.01. 04:00 = 03:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 1, 15, 1, 0)),
        DateTime.utc(2027, 1, 15, 3, 0),
      );
    });

    test('um 00:30 Berlin, UTC noch am Vortag → 04:00 desselben Morgens', () {
      // 14.07.2027 22:30 UTC = 15.07. 00:30 Berlin → 15.07. 02:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 7, 14, 22, 30)),
        DateTime.utc(2027, 7, 15, 2, 0),
      );
    });

    test('um 03:59 Berlin → 04:00 eine Minute später', () {
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 1, 15, 2, 59)),
        DateTime.utc(2027, 1, 15, 3, 0),
      );
    });

    test('um genau 04:00 Berlin → 04:00 am Folgetag', () {
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 1, 15, 3, 0)),
        DateTime.utc(2027, 1, 16, 3, 0),
      );
    });

    test('über den Jahreswechsel', () {
      // 31.12.2027 21:00 Berlin = 20:00 UTC → 01.01.2028 04:00 = 03:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 12, 31, 20, 0)),
        DateTime.utc(2028, 1, 1, 3, 0),
      );
    });

    test('das Ergebnis ist ein UTC-Zeitpunkt', () {
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 7, 14, 19, 0)).isUtc,
        isTrue,
      );
    });
  });

  group('naechsterEsstagBeginn — über die Zeitumstellung', () {
    test('Abend vor dem letzten Märzsonntag → 02:00 UTC (04:00 CEST)', () {
      // 27.03.2027 21:00 CET = 20:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 3, 27, 20, 0)),
        DateTime.utc(2027, 3, 28, 2, 0),
      );
    });

    test('März: nach der Umstellung, vor 04:00 CEST → 02:00 UTC', () {
      // 28.03.2027 01:30 UTC = 03:30 CEST
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 3, 28, 1, 30)),
        DateTime.utc(2027, 3, 28, 2, 0),
      );
    });

    test('März: von 04:00 CET bis 04:00 CEST sind es 23 Stunden', () {
      // 27.03.2027 04:00 CET = 03:00 UTC
      final von = DateTime.utc(2027, 3, 27, 3, 0);
      final bis = naechsterEsstagBeginn(von);
      expect(bis, DateTime.utc(2027, 3, 28, 2, 0));
      expect(bis.difference(von), const Duration(hours: 23));
    });

    test('Abend vor dem letzten Oktobersonntag → 03:00 UTC (04:00 CET)', () {
      // 30.10.2027 21:00 CEST = 19:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 10, 30, 19, 0)),
        DateTime.utc(2027, 10, 31, 3, 0),
      );
    });

    test('Oktober: im zweiten 02:30 (01:30 UTC) → 03:00 UTC', () {
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 10, 31, 1, 30)),
        DateTime.utc(2027, 10, 31, 3, 0),
      );
    });

    test('Oktober: von 04:00 CEST bis 04:00 CET sind es 25 Stunden', () {
      // 30.10.2027 04:00 CEST = 02:00 UTC
      final von = DateTime.utc(2027, 10, 30, 2, 0);
      final bis = naechsterEsstagBeginn(von);
      expect(bis, DateTime.utc(2027, 10, 31, 3, 0));
      expect(bis.difference(von), const Duration(hours: 25));
    });

    test('nach der Umstellung wieder 24 Stunden', () {
      // 28.03.2027 04:00 CEST = 02:00 UTC → 29.03. 04:00 CEST = 02:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 3, 28, 2, 0)),
        DateTime.utc(2027, 3, 29, 2, 0),
      );
      // 31.10.2027 04:00 CET = 03:00 UTC → 01.11. 04:00 CET = 03:00 UTC
      expect(
        naechsterEsstagBeginn(DateTime.utc(2027, 10, 31, 3, 0)),
        DateTime.utc(2027, 11, 1, 3, 0),
      );
    });
  });

  group('Eigenschaften über ein ganzes Jahr (Viertelstundentakt)', () {
    // Das ganze Jahr 2028 (Schaltjahr) samt beider Ränder und beider
    // Umstellungen, jede Viertelstunde. Der Schritt über `Duration` ist
    // hier richtig: Er läuft über UTC-Zeitpunkte, nicht über Kalendertage.
    final zeitpunkte = <DateTime>[
      for (
        var t = DateTime.utc(2027, 12, 31, 12);
        t.isBefore(DateTime.utc(2029, 1, 1, 12));
        t = t.add(const Duration(minutes: 15))
      )
        t,
    ];

    test('der nächste Beginn liegt nach dem Zeitpunkt, höchstens 25 h', () {
      for (final t in zeitpunkte) {
        final n = naechsterEsstagBeginn(t);
        expect(n.isAfter(t), isTrue, reason: '$t → $n');
        expect(
          n.difference(t) <= const Duration(hours: 25),
          isTrue,
          reason: '$t → $n',
        );
      }
    });

    test('der nächste Beginn steht auf 04:00 Berliner Wanduhr', () {
      for (final t in zeitpunkte) {
        final n = naechsterEsstagBeginn(t);
        expect(BerlinCalendar.wallClock(n), (4, 0), reason: '$t → $n');
      }
    });

    test('der nächste Beginn eröffnet genau den folgenden Esstag', () {
      for (final t in zeitpunkte) {
        final n = naechsterEsstagBeginn(t);
        final heute = esstag(t);
        expect(
          esstag(n.subtract(const Duration(minutes: 1))),
          heute,
          reason: 'eine Minute vor $n gehört noch zu $heute',
        );
        expect(
          BerlinCalendar.daysBetween(from: heute, to: esstag(n)),
          1,
          reason: '$t: $heute → ${esstag(n)}',
        );
      }
    });

    test('ab 04:00 Wanduhr ist der Esstag der Kalendertag, davor nicht', () {
      for (final t in zeitpunkte) {
        final (stunde, _) = BerlinCalendar.wallClock(t);
        final kalendertag = BerlinCalendar.dayKey(t);
        if (stunde >= 4) {
          expect(esstag(t), kalendertag, reason: '$t');
        } else {
          expect(
            BerlinCalendar.daysBetween(from: esstag(t), to: kalendertag),
            1,
            reason: '$t',
          );
        }
      }
    });
  });
}
