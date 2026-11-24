import 'package:test/test.dart';

// Direkter Import der Implementierungsdatei statt des Barrel-Files
// `package:trainings_core/trainings_core.dart`: Der Task-3-Auftrag nennt nur
// `lib/src/berlin_calendar.dart` als anzulegende Datei, keine Änderung an
// `lib/trainings_core.dart`. Dieser Test hängt also nicht davon ab, ob (und
// wann) jemand den Barrel-Export ergänzt.
import 'package:trainings_core/src/berlin_calendar.dart';

/// Tests für `BerlinCalendar`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/BerlinCalendar.swift`.
///
/// Die Swift-Fassung verlässt sich auf Apples Zeitzonendatenbank
/// (`TimeZone(identifier: "Europe/Berlin")`). `dart:core` hat keine
/// Zeitzonendatenbank, und `package:timezone` ist verboten (bräche die
/// Importgrenze aus Task 2). Die Implementierung muss die EU-Sommerzeitregel
/// deshalb von Hand nachbilden:
///
///   Sommerzeit (UTC+2) gilt vom letzten Sonntag im März 01:00 UTC bis zum
///   letzten Sonntag im Oktober 01:00 UTC. Sonst gilt Winterzeit (UTC+1).
///
/// Jede Erwartung unten ist von Hand nachgerechnet und kommentiert — ohne
/// `package:timezone` lässt sich nichts automatisch gegenrechnen.
///
/// ### Wochentags-Anker für die Rechnungen
/// Alle "letzter Sonntag im März/Oktober"-Werte in den Kommentaren beruhen auf
/// einer Wochentagskette, verankert an `01.01.2000 = Samstag` (verbreitet
/// bekanntes Datum) und vorwärts gerechnet über Schaltjahre (Tagesverschiebung
/// +2 nach einem Schaltjahr, sonst +1):
///   01.01.2024 = Montag   (Kontrollrechnung: 2000→2024 macht 6 Schaltjahre
///                          (2000,04,08,12,16,20) × 2 + 18 × 1 = 30 ≡ 2 mod 7,
///                          Samstag + 2 = Montag)
///   01.01.2025 = Mittwoch (2024 war Schaltjahr: Montag + 2)
///   01.01.2026 = Donnerstag (2025 kein Schaltjahr: Mittwoch + 1)
///   01.01.2027 = Freitag    (Donnerstag + 1)
///   01.01.2028 = Samstag    (Freitag + 1)
///   01.01.2029 = Montag     (2028 war Schaltjahr: Samstag + 2)
///   01.01.2030 = Dienstag   (Montag + 1)
///
/// Der 1. März liegt in einem Nicht-Schaltjahr 59 Tage (≡ 3 mod 7), in einem
/// Schaltjahr 60 Tage (≡ 4 mod 7) nach dem 1. Januar — der Unterschied kommt
/// vom 29. Februar, der in einem Schaltjahr dazwischenliegt. Der 1. Oktober
/// liegt in einem Nicht-Schaltjahr 273 Tage (≡ 0 mod 7), in einem Schaltjahr
/// 274 Tage (≡ 1 mod 7) nach dem 1. Januar.
///
///   2026: 01.03. = Do + 3 = So  → Sonntage 1,8,15,22,29  → letzter So = 29.03.
///         01.10. = Do + 0 = Do  → Sonntage 4,11,18,25    → letzter So = 25.10.
///   2027: 01.03. = Fr + 3 = Mo  → Sonntage 7,14,21,28    → letzter So = 28.03.
///         01.10. = Fr + 0 = Fr  → Sonntage 3,10,17,24,31 → letzter So = 31.10.
///   2028: 01.03. = Sa + 4 = Mi  → Sonntage 5,12,19,26    → letzter So = 26.03.
///         (2028 ist Schaltjahr, 01.10. = Sa + 1 = So)
///   2029: 01.03. = Mo + 3 = Do  → Sonntage 4,11,18,25    → letzter So = 25.03.
///   2030: 01.03. = Di + 3 = Fr  → Sonntage 3,10,17,24,31 → letzter So = 31.03.
///
/// Die Umstellung selbst: Am letzten Sonntag im März springen die Uhren von
/// 02:00 MEZ (UTC+1) auf 03:00 MESZ (UTC+2) — das ist der Instant 01:00 UTC,
/// an dem der Versatz von +1 auf +2 wechselt. Am letzten Sonntag im Oktober
/// springen sie von 03:00 MESZ (UTC+2) auf 02:00 MEZ (UTC+1) zurück — wieder
/// bei 01:00 UTC, diesmal von +2 auf +1. Die Mitternacht eines Kalendertages
/// liegt lokal immer vor dieser Umstellungsuhrzeit (02:00/03:00 lokal), daher
/// ist die Mitternacht selbst nie mehrdeutig; nur Instants zwischen 01:00 UTC
/// und dem jeweiligen Tagesende sind vom Wechsel betroffen.
void main() {
  group('Pflichtfälle aus dem Task-Brief (Werte wörtlich übernommen)', () {
    test('kurzer Tag: 29.03.2026 hat 23 Stunden', () {
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2026, 3, 29, 12),
      );
      expect(end.difference(start), const Duration(hours: 23));
    });

    test('langer Tag: 25.10.2026 hat 25 Stunden', () {
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2026, 10, 25, 12),
      );
      expect(end.difference(start), const Duration(hours: 25));
    });

    test(
      'days zaehlt ueber die Umstellung hinweg genau 31 Tage im Oktober',
      () {
        final tage = BerlinCalendar.days(
          from: DateTime.utc(2026, 10, 1, 10),
          through: DateTime.utc(2026, 10, 31, 10),
        );
        expect(tage.length, 31);
      },
    );

    test('dayKey ist der ISO-Tag in Berliner Zeit', () {
      // 22:30 UTC + 2h Sommerzeit (22.10.2026 liegt vor der Umstellung am
      // 25.10.) = 00:30 Lokalzeit am 23.10. — also bereits der Folgetag.
      expect(
        BerlinCalendar.dayKey(DateTime.utc(2026, 10, 22, 22, 30)),
        '2026-10-23',
      );
    });

    test('startOfDay ist idempotent', () {
      final einmal = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 7, 10, 15, 42),
      );
      final zweimal = BerlinCalendar.startOfDay(einmal);
      expect(zweimal, einmal);
    });
  });

  group('Exakte Tagesgrenzen an den Pflicht-Umstellungstagen 2026', () {
    test('29.03.2026: Tagesbeginn 1h-Versatz, Tagesende 2h-Versatz', () {
      // Mitternacht 29.03. lokal liegt vor der Umstellung (02:00→03:00 lokal
      // = 01:00 UTC), also gilt dort noch Winterzeit (+1h):
      //   00:00 lokal 29.03. = 23:00 UTC 28.03.
      // Mitternacht 30.03. lokal liegt nach der Umstellung, also Sommerzeit
      // (+2h):
      //   00:00 lokal 30.03. = 22:00 UTC 29.03.
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2026, 3, 29, 12),
      );
      expect(start, DateTime.utc(2026, 3, 28, 23, 0));
      expect(end, DateTime.utc(2026, 3, 29, 22, 0));
    });

    test('25.10.2026: Tagesbeginn 2h-Versatz, Tagesende 1h-Versatz', () {
      // Mitternacht 25.10. lokal liegt vor der Umstellung (03:00→02:00 lokal
      // = 01:00 UTC), also noch Sommerzeit (+2h):
      //   00:00 lokal 25.10. = 22:00 UTC 24.10.
      // Mitternacht 26.10. lokal liegt nach der Umstellung, also Winterzeit
      // (+1h):
      //   00:00 lokal 26.10. = 23:00 UTC 25.10.
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2026, 10, 25, 12),
      );
      expect(start, DateTime.utc(2026, 10, 24, 22, 0));
      expect(end, DateTime.utc(2026, 10, 25, 23, 0));
    });
  });

  group('Grenzzeitpunkte direkt an der Umstellungssekunde (2026)', () {
    // Alle drei Instants liegen am selben lokalen Kalendertag (29.03.), egal
    // ob der Versatz +1 oder +2 ist: 00:59:59 UTC + 1h = 01:59:59 lokal;
    // 01:00:00 UTC + 2h = 03:00:00 lokal; 01:00:01 UTC + 2h = 03:00:01 lokal.
    // Keiner der drei überspringt die lokale Mitternacht. Ein Fehler in der
    // Grenzbedingung (`<` statt `<=` o.ä.) dürfte die Tagesgrenzen hier nicht
    // verschieben.
    const fruehjahrInstants = [
      // eine Sekunde vor der Umstellung (noch Winterzeit)
      [2026, 3, 29, 0, 59, 59],
      // exakt die Umstellungssekunde (laut Regel bereits Sommerzeit)
      [2026, 3, 29, 1, 0, 0],
      // eine Sekunde nach der Umstellung (schon Sommerzeit)
      [2026, 3, 29, 1, 0, 1],
    ];

    for (final werte in fruehjahrInstants) {
      test('Fruehjahr: ${werte[3]}:${werte[4]}:${werte[5]} UTC liegt weiter '
          'im 29.03.', () {
        final instant = DateTime.utc(
          werte[0],
          werte[1],
          werte[2],
          werte[3],
          werte[4],
          werte[5],
        );
        final (start, end) = BerlinCalendar.dayBounds(instant);
        expect(start, DateTime.utc(2026, 3, 28, 23, 0));
        expect(end, DateTime.utc(2026, 3, 29, 22, 0));
      });
    }

    // Herbst analog: 00:59:59 UTC + 2h = 02:59:59 lokal; 01:00:00 UTC + 1h =
    // 02:00:00 lokal; 01:00:01 UTC + 1h = 02:00:01 lokal. Wieder bleibt jeder
    // der drei Instants innerhalb des 25.10. lokal.
    const herbstInstants = [
      [2026, 10, 25, 0, 59, 59],
      [2026, 10, 25, 1, 0, 0],
      [2026, 10, 25, 1, 0, 1],
    ];

    for (final werte in herbstInstants) {
      test('Herbst: ${werte[3]}:${werte[4]}:${werte[5]} UTC liegt weiter im '
          '25.10.', () {
        final instant = DateTime.utc(
          werte[0],
          werte[1],
          werte[2],
          werte[3],
          werte[4],
          werte[5],
        );
        final (start, end) = BerlinCalendar.dayBounds(instant);
        expect(start, DateTime.utc(2026, 10, 24, 22, 0));
        expect(end, DateTime.utc(2026, 10, 25, 23, 0));
      });
    }
  });

  group('Jahresgrenze (Silvester/Neujahr, reine Winterzeit)', () {
    test('dayKey ueber den Jahreswechsel', () {
      // 31.12. liegt weit entfernt von jeder Umstellung, also Winterzeit
      // (+1h): 23:30 UTC + 1h = 00:30 lokal am 01.01. des Folgejahres.
      expect(
        BerlinCalendar.dayKey(DateTime.utc(2026, 12, 31, 23, 30)),
        '2027-01-01',
      );
    });

    test('dayBounds fuer den 31.12. ist ein normaler 24-Stunden-Tag', () {
      // Mitternacht 31.12. lokal = 23:00 UTC 30.12. (+1h).
      // Mitternacht 01.01. lokal = 23:00 UTC 31.12. (+1h) — kein
      // Umstellungstag in der Naehe, also schlicht 24 Stunden Differenz.
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2026, 12, 31, 10),
      );
      expect(start, DateTime.utc(2026, 12, 30, 23, 0));
      expect(end, DateTime.utc(2026, 12, 31, 23, 0));
      expect(end.difference(start), const Duration(hours: 24));
    });

    test('days ueber den Jahreswechsel liefert die vier erwarteten Tage', () {
      final tage = BerlinCalendar.days(
        from: DateTime.utc(2026, 12, 30, 9),
        through: DateTime.utc(2027, 1, 2, 9),
      );
      expect(tage.map(BerlinCalendar.dayKey).toList(), [
        '2026-12-30',
        '2026-12-31',
        '2027-01-01',
        '2027-01-02',
      ]);
    });
  });

  group('Schaltjahr 2028 (29. Februar)', () {
    test('dayKey und dayBounds fuer den 29.02.2028', () {
      // Weit vor der Maerz-Umstellung 2028 (letzter Sonntag = 26.03., siehe
      // Wochentags-Rechnung oben), also Winterzeit (+1h) an diesem Tag.
      // Mitternacht 29.02. lokal = 23:00 UTC 28.02. (+1h).
      // Mitternacht 01.03. lokal = 23:00 UTC 29.02. (+1h, Maerz-Umstellung
      // ist erst am 26.03.) -> normaler 24-Stunden-Tag.
      expect(
        BerlinCalendar.dayKey(DateTime.utc(2028, 2, 29, 12)),
        '2028-02-29',
      );
      final (start, end) = BerlinCalendar.dayBounds(
        DateTime.utc(2028, 2, 29, 12),
      );
      expect(start, DateTime.utc(2028, 2, 28, 23, 0));
      expect(end, DateTime.utc(2028, 2, 29, 23, 0));
    });

    test('days ueber den Schalttag liefert alle fuenf Tage inkl. 29.02.', () {
      final tage = BerlinCalendar.days(
        from: DateTime.utc(2028, 2, 27, 9),
        through: DateTime.utc(2028, 3, 2, 9),
      );
      expect(tage.map(BerlinCalendar.dayKey).toList(), [
        '2028-02-27',
        '2028-02-28',
        '2028-02-29',
        '2028-03-01',
        '2028-03-02',
      ]);
    });
  });

  group('days(): Rand- und Fehlerfaelle', () {
    test('from == through ergibt genau einen Tag, nicht null', () {
      final tage = BerlinCalendar.days(
        from: DateTime.utc(2026, 6, 15, 9),
        through: DateTime.utc(2026, 6, 15, 18),
      );
      expect(tage, [BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 15, 9))]);
    });

    test('from nach through ergibt eine leere Liste, keinen Absturz', () {
      final tage = BerlinCalendar.days(
        from: DateTime.utc(2026, 6, 20, 9),
        through: DateTime.utc(2026, 6, 10, 9),
      );
      expect(tage, isEmpty);
    });
  });

  group('endOfDay ist die Mitternacht des Folgetags', () {
    test('an einem gewoehnlichen Tag ohne Umstellung', () {
      final endeDesTages = BerlinCalendar.endOfDay(
        DateTime.utc(2026, 5, 1, 10),
      );
      final beginnDesFolgetags = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 5, 2, 10),
      );
      expect(endeDesTages, beginnDesFolgetags);
    });

    test('ueber die Fruehjahrs-Umstellung hinweg (29.03. -> 30.03.2026)', () {
      final endeDesTages = BerlinCalendar.endOfDay(
        DateTime.utc(2026, 3, 29, 12),
      );
      final beginnDesFolgetags = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 3, 30, 12),
      );
      expect(endeDesTages, beginnDesFolgetags);
      // Konkreter Wert zur Absicherung, siehe Gruppe "Exakte Tagesgrenzen".
      expect(endeDesTages, DateTime.utc(2026, 3, 29, 22, 0));
    });

    test('ueber die Herbst-Umstellung hinweg (25.10. -> 26.10.2026)', () {
      final endeDesTages = BerlinCalendar.endOfDay(
        DateTime.utc(2026, 10, 25, 12),
      );
      final beginnDesFolgetags = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 10, 26, 12),
      );
      expect(endeDesTages, beginnDesFolgetags);
      expect(endeDesTages, DateTime.utc(2026, 10, 25, 23, 0));
    });
  });

  test(
    'dayBounds ist konsistent mit separaten startOfDay-/endOfDay-Aufrufen',
    () {
      final tag = DateTime.utc(2026, 7, 4, 15);
      final (start, end) = BerlinCalendar.dayBounds(tag);
      expect(start, BerlinCalendar.startOfDay(tag));
      expect(end, BerlinCalendar.endOfDay(tag));
    },
  );

  group(
    'Zwei verschiedene Jahre mit fruehem bzw. spaetem Umstellungstermin',
    () {
      test('2029: letzter Sonntag im Maerz ist der 25. (fruehestmoeglich)', () {
        // Siehe Wochentagsrechnung oben: 01.03.2029 ist ein Donnerstag, also
        // Sonntage 4,11,18,25 -> letzter Sonntag = 25.03.2029.
        // Mitternacht 25.03. lokal liegt vor der Umstellung -> Winterzeit
        // (+1h): 00:00 lokal = 23:00 UTC 24.03.
        // Mitternacht 26.03. lokal liegt danach -> Sommerzeit (+2h):
        // 00:00 lokal = 22:00 UTC 25.03.
        final (start, end) = BerlinCalendar.dayBounds(
          DateTime.utc(2029, 3, 25, 12),
        );
        expect(start, DateTime.utc(2029, 3, 24, 23, 0));
        expect(end, DateTime.utc(2029, 3, 25, 22, 0));
        expect(end.difference(start), const Duration(hours: 23));
      });

      test('2030: letzter Sonntag im Maerz ist der 31. (spaetestmoeglich)', () {
        // 01.03.2030 ist ein Freitag, also Sonntage 3,10,17,24,31 -> letzter
        // Sonntag = 31.03.2030.
        // Mitternacht 31.03. lokal: Winterzeit (+1h) = 23:00 UTC 30.03.
        // Mitternacht 01.04. lokal: Sommerzeit (+2h) = 22:00 UTC 31.03.
        final (start, end) = BerlinCalendar.dayBounds(
          DateTime.utc(2030, 3, 31, 12),
        );
        expect(start, DateTime.utc(2030, 3, 30, 23, 0));
        expect(end, DateTime.utc(2030, 3, 31, 22, 0));
        expect(end.difference(start), const Duration(hours: 23));
      });

      test('2027: letzter Sonntag im Oktober ist der 31. (Gegenstueck zum 25. '
          'aus dem Pflichtfall)', () {
        // 01.10.2027 ist ein Freitag (01.01.2027 = Freitag, Oktober-Versatz
        // in Nicht-Schaltjahren = 0 Tage mod 7), also Sonntage 3,10,17,24,31
        // -> letzter Sonntag = 31.10.2027.
        // Mitternacht 31.10. lokal: Sommerzeit (+2h) = 22:00 UTC 30.10.
        // Mitternacht 01.11. lokal: Winterzeit (+1h) = 23:00 UTC 31.10.
        final (start, end) = BerlinCalendar.dayBounds(
          DateTime.utc(2027, 10, 31, 12),
        );
        expect(start, DateTime.utc(2027, 10, 30, 22, 0));
        expect(end, DateTime.utc(2027, 10, 31, 23, 0));
        expect(end.difference(start), const Duration(hours: 25));
      });
    },
  );

  group('Formatierung von dayKey', () {
    test('einstelliger Monat und Tag werden mit Nullen aufgefuellt', () {
      // 10:00 UTC + 1h Winterzeit = 11:00 lokal, gleicher Kalendertag.
      expect(BerlinCalendar.dayKey(DateTime.utc(2026, 1, 5, 10)), '2026-01-05');
    });

    test('Monatswechsel unter Sommerzeit-Versatz (30.09. -> 01.10.2026)', () {
      // 30.09.2026 liegt innerhalb der Sommerzeit (29.03.-25.10.2026), also
      // +2h: 23:30 UTC + 2h = 01:30 lokal am 01.10. -- Monatswechsel.
      expect(
        BerlinCalendar.dayKey(DateTime.utc(2026, 9, 30, 23, 30)),
        '2026-10-01',
      );
    });
  });

  group('Eingabe mit isUtc == false (z. B. aus DateTime.now())', () {
    // Alle bisherigen Tests uebergeben ausschliesslich DateTime.utc(...).
    // Im echten Betrieb liefert `DateTime.now()` aber eine lokale DateTime
    // (isUtc == false) -- genau der Pfad, den die Implementierung ueber
    // `.toUtc()` normalisieren muss, bevor sie den Versatz bestimmt. Diese
    // Gruppe prueft explizit diesen Pfad.
    //
    // `DateTime.fromMillisecondsSinceEpoch(ms)` (ohne `isUtc: true`) liefert
    // eine DateTime mit `isUtc == false`, die exakt denselben Instant
    // bezeichnet wie `ms` -- unabhaengig von der Systemzeitzone der
    // Maschine, die den Test ausfuehrt, weil `millisecondsSinceEpoch` den
    // Instant eindeutig und zeitzonenunabhaengig festlegt. Die erwarteten
    // Werte sind deshalb dieselben wie bei der aequivalenten
    // `DateTime.utc(...)`-Eingabe an anderer Stelle in dieser Datei.
    DateTime alsLokaleDateTimeMitGleichemInstant(DateTime utc) =>
        DateTime.fromMillisecondsSinceEpoch(utc.millisecondsSinceEpoch);

    test(
      'dayKey mit isUtc == false liefert denselben Tag wie mit UTC-Eingabe',
      () {
        final lokal = alsLokaleDateTimeMitGleichemInstant(
          DateTime.utc(2026, 10, 22, 22, 30),
        );
        // Testvoraussetzung: wirklich kein UTC-Objekt, sonst waere dieser
        // Test wertlos.
        expect(lokal.isUtc, isFalse);
        // Gleicher Instant wie im Pflichtfall "dayKey ist der ISO-Tag in
        // Berliner Zeit" oben (22:30 UTC = 00:30 Berlin Folgetag) -- deshalb
        // derselbe erwartete Wert: '2026-10-23'.
        expect(BerlinCalendar.dayKey(lokal), '2026-10-23');
      },
    );

    test(
      'dayBounds mit isUtc == false behandelt den Umstellungstag korrekt',
      () {
        final lokal = alsLokaleDateTimeMitGleichemInstant(
          DateTime.utc(2026, 3, 29, 12),
        );
        expect(lokal.isUtc, isFalse);
        // Gleicher Instant wie im Pflichtfall "kurzer Tag: 29.03.2026 hat 23
        // Stunden" / der Gruppe "Exakte Tagesgrenzen" oben: Start 28.03.
        // 23:00 UTC, Ende 29.03. 22:00 UTC.
        final (start, end) = BerlinCalendar.dayBounds(lokal);
        expect(start, DateTime.utc(2026, 3, 28, 23, 0));
        expect(end, DateTime.utc(2026, 3, 29, 22, 0));
      },
    );
  });

  group(
    'days() ueber beide Umstellungsmonate 2026 mit geprueften Eintraegen',
    () {
      // Der Pflichtfall oben zaehlt fuer Oktober nur die Laenge (31) -- ein
      // falscher Instant mitten in der Liste faellt dabei nicht auf, und fuer
      // Maerz gibt es bislang gar keinen days()-Test. Diese Gruppe prueft
      // beide Monate vollstaendig: einmal die Liste aller 31 Tagesschluessel
      // (deckt fehlende/doppelte/falsch benannte Kalendertage auf), und
      // zusaetzlich die konkreten DateTime-Werte genau an den beiden Eintraegen
      // links und rechts der Umstellung (deckt einen Stundenfehler ab, der bei
      // gleichem Kalendertag ueber dayKey allein nicht sichtbar waere: z. B.
      // liefern sowohl 2026-10-24T22:00:00Z als auch faelschlich
      // 2026-10-24T23:00:00Z denselben dayKey '2026-10-25', weil der Versatz
      // zu diesem Zeitpunkt bereits +2h betraegt).
      test(
        'Maerz 2026: alle 31 Tage korrekt, Umstellung bei Index 28/29 exakt',
        () {
          final tage = BerlinCalendar.days(
            from: DateTime.utc(2026, 3, 1, 9),
            through: DateTime.utc(2026, 3, 31, 9),
          );
          expect(tage.map(BerlinCalendar.dayKey).toList(), [
            '2026-03-01',
            '2026-03-02',
            '2026-03-03',
            '2026-03-04',
            '2026-03-05',
            '2026-03-06',
            '2026-03-07',
            '2026-03-08',
            '2026-03-09',
            '2026-03-10',
            '2026-03-11',
            '2026-03-12',
            '2026-03-13',
            '2026-03-14',
            '2026-03-15',
            '2026-03-16',
            '2026-03-17',
            '2026-03-18',
            '2026-03-19',
            '2026-03-20',
            '2026-03-21',
            '2026-03-22',
            '2026-03-23',
            '2026-03-24',
            '2026-03-25',
            '2026-03-26',
            '2026-03-27',
            '2026-03-28',
            '2026-03-29',
            '2026-03-30',
            '2026-03-31',
          ]);
          // Index 28 = 29.03. (der 23-Stunden-Tag), Index 29 = 30.03., siehe
          // Rechnung in der Gruppe "Exakte Tagesgrenzen" oben.
          expect(tage[28], DateTime.utc(2026, 3, 28, 23, 0));
          expect(tage[29], DateTime.utc(2026, 3, 29, 22, 0));
        },
      );

      test(
        'Oktober 2026: alle 31 Tage korrekt, Umstellung bei Index 24/25 exakt',
        () {
          final tage = BerlinCalendar.days(
            from: DateTime.utc(2026, 10, 1, 9),
            through: DateTime.utc(2026, 10, 31, 9),
          );
          expect(tage.map(BerlinCalendar.dayKey).toList(), [
            '2026-10-01',
            '2026-10-02',
            '2026-10-03',
            '2026-10-04',
            '2026-10-05',
            '2026-10-06',
            '2026-10-07',
            '2026-10-08',
            '2026-10-09',
            '2026-10-10',
            '2026-10-11',
            '2026-10-12',
            '2026-10-13',
            '2026-10-14',
            '2026-10-15',
            '2026-10-16',
            '2026-10-17',
            '2026-10-18',
            '2026-10-19',
            '2026-10-20',
            '2026-10-21',
            '2026-10-22',
            '2026-10-23',
            '2026-10-24',
            '2026-10-25',
            '2026-10-26',
            '2026-10-27',
            '2026-10-28',
            '2026-10-29',
            '2026-10-30',
            '2026-10-31',
          ]);
          // Index 24 = 25.10. (der 25-Stunden-Tag), Index 25 = 26.10., siehe
          // Rechnung in der Gruppe "Exakte Tagesgrenzen" oben.
          expect(tage[24], DateTime.utc(2026, 10, 24, 22, 0));
          expect(tage[25], DateTime.utc(2026, 10, 25, 23, 0));
        },
      );
    },
  );

  // ---------------------------------------------------------------------
  // Additiv ergänzt am 27.10.2026 für Ticket #130 (`ChartBuckets`).
  //
  // `ChartBuckets.points` braucht für die Stufen `6M` und `J` den Berliner
  // Monatsersten, `ChartBuckets.snap` zusätzlich den des Folgemonats.
  // Entscheidung des Test-Agenten (nicht mit Tim abgestimmt, Begründung im
  // Kopf von `chart_buckets_test.dart`): Die Monatsarithmetik gehört
  // hierher und nicht privat nach `chart_buckets.dart` — eine Monatsgrenze
  // ist eine Kalenderfrage, und `_versatz` in dieser Klasse ist die einzige
  // Stelle im Paket, die die EU-Sommerzeitregel kennt.
  //
  // Vorhandene Fälle sind unberührt geblieben.
  // ---------------------------------------------------------------------
  group('Monatsgrenzen (startOfMonth, addMonths) -- ergaenzt fuer #130', () {
    test('startOfMonth: mitten im Monat -> Monatserster, Sommerzeit', () {
      // 01.05.2026 00:00 Berlin liegt in der Sommerzeit (29.03.-25.10.2026),
      // also +2h: 30.04. 22:00 UTC.
      expect(
        BerlinCalendar.startOfMonth(DateTime.utc(2026, 5, 16, 10)),
        DateTime.utc(2026, 4, 30, 22),
      );
    });

    test('startOfMonth: mitten im Monat -> Monatserster, Winterzeit', () {
      // 01.01.2026 00:00 Berlin = 31.12.2025 23:00 UTC (+1h).
      expect(
        BerlinCalendar.startOfMonth(DateTime.utc(2026, 1, 15, 10)),
        DateTime.utc(2025, 12, 31, 23),
      );
    });

    test('startOfMonth: ein Monatserster bleibt stehen', () {
      final ersterMaerz = BerlinCalendar.startOfDay(DateTime.utc(2026, 3, 1));
      expect(ersterMaerz, DateTime.utc(2026, 2, 28, 23));
      expect(BerlinCalendar.startOfMonth(ersterMaerz), ersterMaerz);
    });

    test('startOfMonth: die Grenze laeuft ueber den Berliner Kalender, '
        'nicht ueber UTC', () {
      // 31.10.2026 23:30 UTC: Die Sommerzeit endete am 25.10., also +1h --
      // lokal ist das der 01.11.2026 um 00:30. Nach UTC-Datum noch Oktober.
      expect(
        BerlinCalendar.startOfMonth(DateTime.utc(2026, 10, 31, 23, 30)),
        DateTime.utc(2026, 10, 31, 23),
      );
      // Eine Stunde frueher ist es lokal noch der 31.10. um 23:30 -- also
      // Oktober, und dessen Erster liegt noch in der Sommerzeit (+2h).
      expect(
        BerlinCalendar.startOfMonth(DateTime.utc(2026, 10, 31, 22, 30)),
        DateTime.utc(2026, 9, 30, 22),
      );
    });

    test('startOfMonth gibt immer einen UTC-Zeitpunkt zurueck', () {
      expect(
        BerlinCalendar.startOfMonth(DateTime.utc(2026, 5, 16, 10)).isUtc,
        isTrue,
      );
    });

    test('startOfMonth mit isUtc == false liefert denselben Monatsersten', () {
      // `DateTime.fromMillisecondsSinceEpoch(ms)` bezeichnet denselben
      // Instant wie `ms`, unabhaengig von der Systemzeitzone -- derselbe
      // Kunstgriff wie in der Gruppe "Eingabe mit isUtc == false" oben.
      final lokal = DateTime.fromMillisecondsSinceEpoch(
        DateTime.utc(2026, 10, 31, 23, 30).millisecondsSinceEpoch,
      );
      expect(lokal.isUtc, isFalse);
      expect(
        BerlinCalendar.startOfMonth(lokal),
        DateTime.utc(2026, 10, 31, 23),
      );
    });

    test('addMonths(x, 0) ist startOfMonth(x)', () {
      for (final zeitpunkt in [
        DateTime.utc(2026, 5, 16, 10),
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 10, 31, 23, 30),
      ]) {
        expect(
          BerlinCalendar.addMonths(zeitpunkt, 0),
          BerlinCalendar.startOfMonth(zeitpunkt),
          reason: '$zeitpunkt',
        );
      }
    });

    test('addMonths zaehlt in Monaten, nicht in Tagen -- keine Klemmung', () {
      // Der Monat des 31.01.2026 ist der Januar; einer weiter ist der
      // Februar, und dessen Erster ist die Antwort. Die Frage nach dem
      // "31. Februar" stellt sich gar nicht erst.
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 1, 31, 12), 1),
        BerlinCalendar.startOfDay(DateTime.utc(2026, 2, 1)),
      );
    });

    test('addMonths vorwaerts ueber die Jahresgrenze', () {
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 11, 15, 12), 3),
        // 01.02.2027 00:00 Berlin = 31.01.2027 23:00 UTC (Winterzeit).
        DateTime.utc(2027, 1, 31, 23),
      );
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 12, 15, 12), 1),
        // 01.01.2027 00:00 Berlin = 31.12.2026 23:00 UTC.
        DateTime.utc(2026, 12, 31, 23),
      );
    });

    test('addMonths rueckwaerts ueber die Jahresgrenze', () {
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 1, 15, 12), -3),
        // 01.10.2025 00:00 Berlin: Die Sommerzeit 2025 endete am letzten
        // Sonntag im Oktober, der 1. liegt also noch darin (+2h).
        DateTime.utc(2025, 9, 30, 22),
      );
    });

    test('addMonths um zwoelf landet im selben Monat des Folgejahres', () {
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 5, 16, 10), 12),
        BerlinCalendar.startOfDay(DateTime.utc(2027, 5, 1)),
      );
    });

    test('addMonths rechnet nicht in Sekunden: Maerz 2026 hat 743 Stunden', () {
      // 31 Kalendertage, einer davon (29.03.) mit 23 Stunden. Wer
      // `Duration(days: 31)` addiert, landet eine Stunde zu spaet.
      final ersterMaerz = BerlinCalendar.startOfMonth(
        DateTime.utc(2026, 3, 15, 12),
      );
      expect(
        BerlinCalendar.addMonths(ersterMaerz, 1).difference(ersterMaerz),
        const Duration(hours: 743),
      );
    });

    test(
      'addMonths rechnet nicht in Sekunden: Oktober 2026 hat 745 Stunden',
      () {
        // 31 Kalendertage, einer davon (25.10.) mit 25 Stunden.
        final ersterOktober = BerlinCalendar.startOfMonth(
          DateTime.utc(2026, 10, 15, 12),
        );
        expect(
          BerlinCalendar.addMonths(ersterOktober, 1).difference(ersterOktober),
          const Duration(hours: 745),
        );
      },
    );

    test('addMonths im Schaltjahr: Februar 2028 hat 29 Tage', () {
      final ersterFebruar = BerlinCalendar.startOfMonth(
        DateTime.utc(2028, 2, 14, 12),
      );
      expect(
        BerlinCalendar.addMonths(ersterFebruar, 1).difference(ersterFebruar),
        const Duration(days: 29),
        reason:
            'Februar 2028 liegt ganz in der Winterzeit -- 29 volle Tage, '
            'keine Umstellung darin',
      );
    });

    test('addMonths gibt immer einen UTC-Zeitpunkt zurueck', () {
      expect(
        BerlinCalendar.addMonths(DateTime.utc(2026, 5, 16, 10), 1).isUtc,
        isTrue,
      );
    });
  });
}
