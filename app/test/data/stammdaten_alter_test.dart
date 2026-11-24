// Tests für `Stammdaten.alterAm(DateTime)` — die eine Stelle, an der aus
// Tims Jahrgang ein Alter in Jahren wird.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden. Sie ist am
// 04.11.2026 nachgereicht worden: `alterAm` entstand beim Bau von #306 als
// Zugabe des Implementierungs-Agenten und blieb deshalb ohne Test — und ein
// falsches Alter bleibt nicht folgenlos, es geht über `kalorienziel`
// (`Packages/trainings_core/lib/src/kalorienziel.dart`, Mifflin-St Jeor:
// `10·kg + 6,25·cm − 5·Alter + 5`) direkt in den Ernährungsring.
//
// ## Was hier geprüft wird — die Anforderung, nicht der Code
//
// Die Erwartungen unten sind aus `CLAUDE.md` und `docs/SPEC.md` 4.8
// hergeleitet und von Hand nachgerechnet, nicht aus `stammdaten.dart`
// abgelesen.
//
// **Die Zeitfalle.** Die ganze Zeitrechnung der App läuft über
// UTC-Zeitpunkte, die **Berliner** Tagesgrenzen bezeichnen (`CLAUDE.md`,
// „Zeitstempel liegen in der Datenbank als Text"). Der 1. Januar beginnt in
// Berlin als `31.12. 23:00 UTC` (Winterzeit, UTC+1). Wer das Jahr aus
// `zeitpunkt.year` nimmt statt aus dem Berliner Kalendertag, macht Tim an
// genau diesem einen Tag im Jahr ein Jahr jünger — und das Kalorienziel
// sähe an diesem Tag um rund 5 kcal anders aus als an allen übrigen, ohne
// dass irgendwo stünde, warum. Dasselbe gilt eine Ebene feiner für jeden
// Tagesbeginn: Als UTC-Zeitpunkt ist er immer 22:00 oder 23:00 des
// **Vortags**.
//
// **Keine echten Gesundheitsdaten** (`CLAUDE.md`). Die Jahrgänge hier sind
// 1904 und 2099 — Nachbarn der 1899/1901/1904 aus
// `test/data/stammdaten_aus_health_test.dart`,
// `test/health/koerpermerkmale_test.dart` und
// `test/shell/vorlaeufige_werte_test.dart`. Keiner davon ist Tims
// Geburtsjahr, keiner ist auch nur plausibel. Ebenso sind die Zeitpunkte
// reine Rechengrößen und keine Termine — 2027 bis 2030 steht hier, weil
// die Sommerzeitgrenzen dieser Jahre in
// `Packages/trainings_core/test/berlin_calendar_test.dart` bereits von Hand
// ausgerechnet und dokumentiert sind (letzter Sonntag im März 2028: 26.03.,
// im Oktober 2028: 29.10.; im März 2030: 31.03.), nicht weil irgendetwas an
// diesen Tagen stattfände.
//
// ## Entscheidung: ein Zeitpunkt **vor** dem Geburtsjahr ergibt eine
// ## negative Zahl — kein `null`, kein Wurf
//
// Der Fall kann im Betrieb nicht auftreten (die Zeitpunkte kommen aus
// „jetzt" oder aus dem angezeigten Tag), aber was dann herauskommt, ist
// trotzdem eine Entscheidung. Begründung für die Subtraktion ohne
// Sonderbehandlung:
//
// * **`null` ist schon vergeben.** `null` heißt an dieser Methode genau
//   eines: „kein Geburtsjahr bekannt". Ein zweiter Grund für denselben
//   Rückgabewert machte aus einer eindeutigen Auskunft eine mehrdeutige —
//   der Schirm führte auf „Geburtsjahr eintragen", obwohl eins eingetragen
//   ist.
// * **Ein Wurf verwandelte eine Datenlage in einen Absturz.** Stammdaten
//   kommen aus einem Formular und aus Apple Health; ein unsinniger Jahrgang
//   ist ein falscher Wert, kein Programmierfehler im Kanal.
// * **Nach unten ist der Fall bereits gefangen.** `kalorienziel` weist
//   `alter <= 0` zurück und liefert `null` — „kein Ziel berechenbar", die
//   ehrliche Auskunft. Eine negative Zahl ist damit laut sichtbar und
//   führt zu keinem erfundenen Ergebnis.
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/stammdaten.dart';

void main() {
  // Erkennbar erfunden, wie die Nachbarn in `stammdaten_aus_health_test.dart`
  // (1899) und `schema_v11_test.dart` (1904).
  const jahrgang = 1904;

  group('alterAm am Jahreswechsel über die Berliner Tagesgrenze', () {
    // Dezember liegt weit hinter dem Ende der Sommerzeit (letzter Sonntag im
    // Oktober), also Winterzeit, UTC+1. Berliner Mitternacht des 01.01.2028
    // ist damit der Instant 31.12.2027 23:00 UTC.
    const stammdaten = Stammdaten(geburtsjahr: jahrgang);

    test('eine Sekunde vor der Grenze gilt noch das alte Jahr', () {
      // 22:59:59 UTC + 1h = 23:59:59 lokal am 31.12.2027 -> Berliner Tag
      // 2027-12-31 -> 2027 − 1904 = 123.
      expect(stammdaten.alterAm(DateTime.utc(2027, 12, 31, 22, 59, 59)), 123);
    });

    test('auf der Grenze selbst steigt das Alter — nicht erst 60 Minuten '
        'später', () {
      // 23:00:00 UTC + 1h = 00:00 lokal am 01.01.2028 -> Berliner Tag
      // 2028-01-01 -> 2028 − 1904 = 124.
      //
      // Das ist der Kern dieser Datei: `zeitpunkt.year` wäre hier 2027 und
      // ergäbe 123 — Tim wäre an diesem einen Tag ein Jahr jünger als an den
      // 365 übrigen.
      final zeitpunkt = DateTime.utc(2027, 12, 31, 23);
      expect(
        zeitpunkt.year,
        2027,
        reason:
            'Testvoraussetzung: der UTC-Tag '
            'liegt noch im alten Jahr, der Berliner Tag nicht mehr.',
      );
      expect(stammdaten.alterAm(zeitpunkt), 124);
    });

    test('eine Stunde nach der Grenze ändert sich nichts mehr', () {
      // 00:00 UTC + 1h = 01:00 lokal am 01.01.2028 — derselbe Berliner Tag
      // wie oben, also derselbe Wert. Ein Sprung zwischen diesen beiden
      // Zeitpunkten wäre der Fehler.
      expect(stammdaten.alterAm(DateTime.utc(2028, 1, 1)), 124);
    });
  });

  group('alterAm unter Sommerzeit (UTC+2)', () {
    const stammdaten = Stammdaten(geburtsjahr: jahrgang);

    test('UTC-Tag und Berliner Tag fallen auseinander', () {
      // 14.06.2028 liegt zwischen dem 26.03. und dem 29.10.2028, also
      // Sommerzeit: 22:30 UTC + 2h = 00:30 lokal am 15.06.2028. Der
      // UTC-Kalendertag ist der 14., der Berliner der 15.
      final zeitpunkt = DateTime.utc(2028, 6, 14, 22, 30);
      expect(
        zeitpunkt.day,
        14,
        reason:
            'Testvoraussetzung: der UTC-Tag ist '
            'der 14., der Berliner Tag ist bereits der 15.',
      );
      expect(
        BerlinCalendar.dayKey(zeitpunkt),
        '2028-06-15',
        reason:
            'Testvoraussetzung: die beiden Kalendertage gehen hier '
            'wirklich auseinander, sonst prüft dieser Fall nichts.',
      );
      expect(stammdaten.alterAm(zeitpunkt), 124);
    });

    test('derselbe Berliner Tag, von beiden Seiten der UTC-Mitternacht', () {
      // 15.06.2028 00:30 UTC + 2h = 02:30 lokal — derselbe Berliner Tag wie
      // 22:30 UTC des Vortags. Das Alter darf dazwischen nicht wackeln.
      expect(stammdaten.alterAm(DateTime.utc(2028, 6, 15, 0, 30)), 124);
    });

    test('an jedem Berliner Tagesbeginn des Jahres 2028 gilt dasselbe Alter', () {
      // Der Durchlauf über ein ganzes Jahr ist der eigentliche Beweis gegen
      // `zeitpunkt.year`: Ein Berliner Tagesbeginn ist als UTC-Instant immer
      // 22:00 (Sommerzeit) oder 23:00 (Winterzeit) des **Vortags**. Für den
      // 01.01. liegt dieser Vortag im Vorjahr — für alle übrigen nicht.
      //
      // Die Erwartung steht hier als Literal (2028 − 1904 = 124) und wird
      // nicht aus dem Kalender abgeleitet; der Durchlauf liefert nur die
      // Zeitpunkte.
      final tagesbeginne = BerlinCalendar.days(
        from: DateTime.utc(2028, 1, 1, 12),
        through: DateTime.utc(2028, 12, 31, 12),
      );
      expect(
        tagesbeginne,
        hasLength(366),
        reason:
            'Testvoraussetzung: 2028 ist ein Schaltjahr, der Durchlauf '
            'deckt das ganze Jahr ab.',
      );

      for (final zeitpunkt in tagesbeginne) {
        expect(
          stammdaten.alterAm(zeitpunkt),
          124,
          reason:
              'Berliner Tagesbeginn ${zeitpunkt.toIso8601String()} '
              'gehört zum Kalenderjahr 2028.',
        );
      }

      // Und der Nachweis, dass die Falle an genau einem Tag im Jahr zuschnappt
      // — ohne diesen Zähler könnte der Durchlauf oben auch mit
      // `zeitpunkt.year` grün werden.
      final imVorjahr = tagesbeginne.where((t) => t.year == 2027).length;
      expect(
        imVorjahr,
        1,
        reason:
            'Genau ein Tagesbeginn des Jahres 2028 liegt als '
            'UTC-Zeitpunkt noch in 2027 — der des 01.01.',
      );
    });
  });

  group('alterAm an einem gewöhnlichen Tag mitten im Jahr', () {
    test('Mittag, Sommerzeit, kein Kalendertagwechsel in Sicht', () {
      // 04.07.2028, 12:00 UTC + 2h = 14:00 lokal am selben Tag.
      expect(
        const Stammdaten(geburtsjahr: jahrgang)
            .alterAm(DateTime.utc(2028, 7, 4, 12)),
        124,
      );
    });

    test('Mittag, Winterzeit, kein Kalendertagwechsel in Sicht', () {
      // 04.02.2029, 12:00 UTC + 1h = 13:00 lokal am selben Tag.
      expect(
        const Stammdaten(geburtsjahr: jahrgang)
            .alterAm(DateTime.utc(2029, 2, 4, 12)),
        125,
      );
    });

    test('die übrigen drei Felder ändern am Alter nichts', () {
      // Größe, Zielgewicht und Zieldatum gehen in die Rechnung nicht ein.
      // Die Werte sind dieselben erkennbar unmöglichen wie in
      // `schema_v11_test.dart` (211 cm, 33,3 kg, 2099-12-31).
      expect(
        const Stammdaten(
          groesseCm: 211,
          geburtsjahr: jahrgang,
          zielgewichtKg: 33.3,
          zieldatum: '2099-12-31',
        ).alterAm(DateTime.utc(2028, 7, 4, 12)),
        124,
      );
    });
  });

  group('alterAm ohne Geburtsjahr', () {
    test('der leere Stand antwortet mit null, nicht mit 0', () {
      // `0` wäre ein Alter — eine Angabe über Tim, die niemand gemacht hat,
      // und `kalorienziel` rechnete damit eine Zahl aus, die wie ein Ergebnis
      // aussieht. Fehler `01` in der Rechnung statt in der Anzeige.
      final alter = const Stammdaten().alterAm(DateTime.utc(2028, 7, 4, 12));
      expect(alter, isNull);
      expect(alter, isNot(0));
    });

    test('auch wenn die drei übrigen Felder gefüllt sind', () {
      // Eine gefüllte Zeile ohne Jahrgang ist der Normalfall, solange Health
      // nur die Größe geliefert hat (#306, Zusage 1: er füllt Lücken).
      final alter = const Stammdaten(
        groesseCm: 211,
        zielgewichtKg: 33.3,
        zieldatum: '2099-12-31',
      ).alterAm(DateTime.utc(2028, 7, 4, 12));
      expect(alter, isNull);
      expect(alter, isNot(0));
    });

    test('an der Jahresgrenze bleibt es null', () {
      // Der Jahrgang fehlt — daran ändert auch der Tag nichts, an dem die
      // Zeitfalle zuschnappt.
      expect(
        const Stammdaten().alterAm(DateTime.utc(2027, 12, 31, 23)),
        isNull,
      );
    });
  });

  group('alterAm vor dem Geburtsjahr', () {
    // Jahrgang 2099 — dieselbe erkennbar unmögliche Zahl, die
    // `schema_v11_test.dart` als Zieldatum benutzt. Mit ihr bleibt der
    // Zeitpunkt in der Gegenwart; ein Zeitpunkt vor 1996 wäre untauglich,
    // weil `BerlinCalendar` die EU-Sommerzeitregel erst ab 1996 richtig
    // nachbildet (siehe dessen Klassenkommentar).
    const stammdaten = Stammdaten(geburtsjahr: 2099);

    test('liefert eine negative Zahl — nicht null und keinen Wurf', () {
      // 20.05.2030, 12:00 UTC + 2h = 14:00 lokal am selben Tag (die
      // Sommerzeit 2030 beginnt am 31.03.). 2030 − 2099 = −69.
      final alter = stammdaten.alterAm(DateTime.utc(2030, 5, 20, 12));
      expect(alter, -69);
      expect(
        alter,
        isNotNull,
        reason:
            '`null` heißt an dieser Methode „kein Geburtsjahr bekannt" '
            'und darf keinen zweiten Grund bekommen.',
      );
    });

    test('der Rückgabewert ist für kalorienziel unbrauchbar, und das ist der '
        'Punkt', () {
      // Nach unten ist der Fall bereits gefangen: `kalorienziel` weist
      // `alter <= 0` zurück und liefert `null` — „kein Ziel berechenbar".
      // Eine negative Zahl erfindet also nichts, sie fällt auf.
      final alter = stammdaten.alterAm(DateTime.utc(2030, 5, 20, 12));
      expect(alter, lessThanOrEqualTo(0));
      expect(
        kalorienziel(gewichtKg: 33.3, groesseCm: 211, alter: alter),
        isNull,
      );
    });

    test('im Geburtsjahr selbst ist das Alter 0 — ebenfalls unbrauchbar', () {
      // Die Methode rechnet nur aus dem Jahrgang, nicht aus einem Geburtstag
      // (so steht es im Vertrag). Im Jahrgang selbst ist das Ergebnis
      // deshalb 0, und auch das weist `kalorienziel` über `alter <= 0`
      // zurück, statt mit einer Null zu rechnen.
      const imJahrgang = Stammdaten(geburtsjahr: 2030);
      expect(imJahrgang.alterAm(DateTime.utc(2030, 5, 20, 12)), 0);
      expect(kalorienziel(gewichtKg: 33.3, groesseCm: 211, alter: 0), isNull);
    });
  });

  group('alterAm mit isUtc == false (z. B. aus DateTime.now())', () {
    // Im Betrieb kommt der Zeitpunkt aus `DateTime.now()` und trägt
    // `isUtc == false` — genau der Pfad, den die Implementierung
    // normalisieren muss, bevor sie den Berliner Tag bestimmt. Dieselbe
    // Vorgehensweise wie in `berlin_calendar_test.dart`: Über
    // `millisecondsSinceEpoch` bezeichnet die lokale DateTime exakt denselben
    // Instant, unabhängig von der Zeitzone der Maschine, die den Test
    // ausführt.
    DateTime alsLokaleDateTimeMitGleichemInstant(DateTime utc) =>
        DateTime.fromMillisecondsSinceEpoch(utc.millisecondsSinceEpoch);

    test('die Jahresgrenze gilt auch für eine lokale DateTime', () {
      final lokal = alsLokaleDateTimeMitGleichemInstant(
        DateTime.utc(2027, 12, 31, 23),
      );
      expect(
        lokal.isUtc,
        isFalse,
        reason:
            'Testvoraussetzung: wirklich kein UTC-Objekt, sonst prüft '
            'dieser Fall nichts.',
      );
      // Gleicher Instant wie oben, also derselbe erwartete Wert: 124.
      expect(const Stammdaten(geburtsjahr: jahrgang).alterAm(lokal), 124);
    });
  });
}
