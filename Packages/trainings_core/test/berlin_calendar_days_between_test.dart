import 'package:test/test.dart';

import 'package:trainings_core/src/berlin_calendar.dart';

/// Tests für `BerlinCalendar.daysBetween` — den Abstand zweier
/// ISO-Tagesschlüssel in Tagen.
///
/// ## Warum es diese Rechnung gibt
///
/// Die Gewichtskachel auf Home sagt, wie alt der jüngste Waage-Wert ist
/// („gestern gemessen", „vor 3 Tagen gemessen", Ticket #137). Dafür muss der
/// Abstand zweier Tagesschlüssel (`BerlinCalendar.dayKey`, Form `JJJJ-MM-TT`)
/// bekannt sein.
///
/// In `app/lib/shell/heute_anzeigen.dart` stand das als private Funktion in
/// der Ansicht und rechnete so:
///
/// ```dart
/// final von = DateTime.tryParse(vonTag);   // ohne Z → ORTSZEIT
/// return bis.difference(von).inDays;
/// ```
///
/// `DateTime.parse` liest einen Tagesschlüssel ohne Zeitzonenangabe als
/// **lokale** Mitternacht. Über eine Zeitumstellung hinweg hat ein Tag dann
/// 23 oder 25 Stunden, und `inDays` schneidet ab, statt zu runden. Auf einer
/// Maschine in `Europe/Berlin` nachgerechnet:
///
/// ```
/// 2026-03-28 -> 2026-03-29:  1   (richtig)
/// 2026-03-29 -> 2026-03-30:  0   (falsch, 23 Stunden)
/// 2026-03-28 -> 2026-03-31:  2   (falsch, 71 Stunden)
/// ```
///
/// Die Wirkung ist keine Kosmetik, sondern eine **falsche Auskunft**: Tim
/// wiegt sich am Sonntag der Zeitumstellung, schaut am Montag auf Home — und
/// die Kachel sagt „heute gemessen".
///
/// ## Warum der Test hier liegt und nicht in `app/test/`
///
/// Eine Tagesdifferenz ist eine Rechnung, und `CLAUDE.md` sagt: „Jede Formel
/// bekommt einen Test, und zwar **im Kern**". Eine Formel, deren Test in
/// `app/test/` landet, beweist die Importgrenze nicht mehr mit — und sie
/// wäre dort an eine Ansicht gebunden, obwohl jeder Schirm sie braucht, der
/// einen Wert altern lässt.
///
/// ## Festgelegte API
///
/// ```dart
/// static int? BerlinCalendar.daysBetween({
///   required String from,
///   required String to,
/// })
/// ```
///
/// - Benannte Parameter wie bei `BerlinCalendar.days`, nicht zwei
///   gleichartige positionelle Strings: Vertauschen kehrt das Vorzeichen um,
///   und das soll man beim Lesen sehen.
/// - **`int?`, nicht `int`:** Der Aufrufer bekommt die Schlüssel aus Daten,
///   nicht aus einer Konstante. Ein unlesbarer Schlüssel ist `null` und führt
///   dort zur unbestimmten Beschriftung („zuletzt gemessen") — er darf keine
///   Ausnahme werfen, die den Schirm leert, und erst recht keine erfundene
///   Zahl liefern.
/// - **Nicht zu verwechseln mit `BerlinCalendar.days(from:through:)`**, das
///   eine Liste **einschließlich beider** Grenzen liefert: Für zwei
///   aufeinanderfolgende Tage hat jene Liste zwei Einträge, `daysBetween`
///   ergibt `1`. Der erste Fall unten hält beides nebeneinander fest, damit
///   niemand das eine über das andere implementiert und sich um eins vertut.
///
/// ## Warum `BerlinCalendar` der richtige Ort ist
///
/// Die Klasse ist die Heimat des Tagesschlüssels: `dayKey` erzeugt ihn, und
/// ihr tragender Satz ist, dass ein Tag eine **Kalenderangabe** ist und kein
/// Zeitpunkt. Genau daran scheiterte die alte Fassung. Die Rechnung selbst
/// braucht keine Zeitzone — sie darf keine benutzen.
///
/// `BerlinCalendar.startOfDay(...)` löst es ausdrücklich **nicht**: Das sind
/// Zeitpunkte der Berliner Mitternacht, deren Abstand ebenfalls 23 oder 25
/// Stunden beträgt. Richtig ist reine UTC-Kalenderarithmetik.
///
/// ## Zu den Daten in dieser Datei
///
/// Kalenderdaten, keine Ereignisse — kein OP-Termin, kein Wettkampf, kein
/// Planstart (`CLAUDE.md`, „Keine hartcodierten Ereignisse"). Die Wochentage
/// sind nachgerechnet: 29.03.2026 und 25.10.2026 sind Sonntage und damit die
/// EU-Umstellungstage 2026; 08.03.2026 und 01.11.2026 sind die
/// US-Umstellungstage, 05.04.2026 und 04.10.2026 die australischen.
///
/// **Warum fremde Zeitzonen in einem Test für eine Berlin-Klasse stehen:**
/// `dart test` läuft in der Zeitzone der Maschine. Stünde dort UTC, wäre
/// dieser Test für genau den Fehler blind, den er fängt — in UTC stimmt die
/// alte Rechnung. Die Umstellungstage dreier Zonen zusammen lassen ihn auf
/// praktisch jeder realistisch eingestellten Maschine zuschlagen. Die App
/// kümmert sich weiterhin nur um Berlin.
void main() {
  group('der Normalfall, und der Unterschied zu days(from:through:)', () {
    test('derselbe Tag ist 0 Tage her', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-20', to: '2026-10-20'),
        0,
      );
    });

    test('zwei aufeinanderfolgende Tage sind 1 — nicht 2, wie die Länge der '
        'Liste aus days(from:through:)', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-19', to: '2026-10-20'),
        1,
      );

      // Dieselbe Spanne als Liste: beide Grenzen eingeschlossen, also zwei
      // Einträge. Wer daysBetween über days().length baut, landet bei 2.
      final tage = BerlinCalendar.days(
        from: DateTime.utc(2026, 10, 19, 12),
        through: DateTime.utc(2026, 10, 20, 12),
      );
      expect(tage, hasLength(2));
    });

    test('rückwärts gerechnet ist der Abstand negativ', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-20', to: '2026-10-19'),
        -1,
      );
    });

    test('über eine ganze Woche', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-13', to: '2026-10-20'),
        7,
      );
    });
  });

  group('Zeitumstellung — der Fehler, um den es geht', () {
    // Letzter Sonntag im März 2026: 29.03. Der Tag hat in Berlin 23 Stunden,
    // `Duration.inDays` schneidet auf 0 ab.
    test('der Tag des Sommerzeitbeginns zählt als ein Tag, nicht als keiner', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-29', to: '2026-03-30'),
        1,
      );
    });

    test('der Tag davor und der Tag danach bleiben ebenfalls richtig', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-28', to: '2026-03-29'),
        1,
      );
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-30', to: '2026-03-31'),
        1,
      );
    });

    test('eine Spanne über den Sommerzeitbeginn hinweg ist 3 Tage, nicht 2', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-28', to: '2026-03-31'),
        3,
      );
    });

    // Letzter Sonntag im Oktober 2026: 25.10. Der Tag hat 25 Stunden; dort
    // rechnet `inDays` zufällig richtig, weil es abschneidet — der Fall
    // gehört trotzdem her, sonst hielte der Test nur eine Richtung fest.
    test('der Tag des Sommerzeitendes zählt ebenfalls als ein Tag', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-25', to: '2026-10-26'),
        1,
      );
    });

    test('eine Spanne über das Sommerzeitende hinweg ist 3 Tage', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-24', to: '2026-10-27'),
        3,
      );
    });

    test('eine lange Spanne über beide Umstellungen hinweg stimmt auf den '
        'Tag — hier gleicht sich keine Stunde gegen die andere aus', () {
      // 01.03.2026 bis 01.11.2026: 30+31+30+31+31+30+31+31 = 245 Tage.
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-01', to: '2026-11-01'),
        245,
      );
    });

    test('auch die Umstellungstage anderer Zeitzonen zählen als ein Tag — '
        'damit dieser Test nicht von der Zeitzone der Maschine abhängt', () {
      // USA 2026: Beginn am zweiten Sonntag im März (08.03.), Ende am
      // ersten Sonntag im November (01.11.).
      expect(
        BerlinCalendar.daysBetween(from: '2026-03-08', to: '2026-03-09'),
        1,
      );
      expect(
        BerlinCalendar.daysBetween(from: '2026-11-01', to: '2026-11-02'),
        1,
      );
      // Australien (Sydney) 2026: Ende am ersten Sonntag im April (05.04.),
      // Beginn am ersten Sonntag im Oktober (04.10.).
      expect(
        BerlinCalendar.daysBetween(from: '2026-04-05', to: '2026-04-06'),
        1,
      );
      expect(
        BerlinCalendar.daysBetween(from: '2026-10-04', to: '2026-10-05'),
        1,
      );
    });
  });

  group('Monats-, Jahres- und Schaltjahresgrenzen', () {
    test('über eine Monatsgrenze', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-01-31', to: '2026-02-01'),
        1,
      );
    });

    test('über eine Jahresgrenze', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-12-31', to: '2027-01-01'),
        1,
      );
    });

    test('im Schaltjahr liegt der 29. Februar dazwischen', () {
      // 2028 ist ein Schaltjahr (durch 4 teilbar, kein volles Jahrhundert).
      expect(
        BerlinCalendar.daysBetween(from: '2028-02-28', to: '2028-03-01'),
        2,
      );
    });

    test('ohne Schaltjahr folgt der 1. März direkt auf den 28. Februar', () {
      expect(
        BerlinCalendar.daysBetween(from: '2026-02-28', to: '2026-03-01'),
        1,
      );
    });
  });

  group('unlesbare Schlüssel', () {
    test('eine leere Zeichenkette ergibt null, keine 0', () {
      expect(BerlinCalendar.daysBetween(from: '', to: '2026-10-20'), isNull);
      expect(BerlinCalendar.daysBetween(from: '2026-10-20', to: ''), isNull);
    });

    test('ein Wort statt eines Tagesschlüssels ergibt null', () {
      expect(
        BerlinCalendar.daysBetween(from: 'heute', to: '2026-10-20'),
        isNull,
      );
    });
  });

  group('die Rechnung passt zu dayKey, aus dem die Schlüssel stammen', () {
    test('zwei über dayKey erzeugte Schlüssel ergeben ihren Tagesabstand — '
        'auch über den Sommerzeitbeginn hinweg', () {
      // Zwei Zeitpunkte, die in Berlin auf den 29. und den 30.03.2026
      // fallen. Ihr Abstand in Stunden ist 23, ihr Abstand in Tagen 1.
      final sonntag = DateTime.utc(2026, 3, 29, 12);
      final montag = DateTime.utc(2026, 3, 30, 12);

      expect(
        BerlinCalendar.daysBetween(
          from: BerlinCalendar.dayKey(sonntag),
          to: BerlinCalendar.dayKey(montag),
        ),
        1,
      );
    });
  });
}
