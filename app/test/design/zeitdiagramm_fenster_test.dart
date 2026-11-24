import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/formatierung.dart';
import 'package:repit/design/zeitdiagramm_fenster.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

/// Tests für `Fensterstand` — `lib/design/zeitdiagramm_fenster.dart`.
///
/// ## Warum es diese Datei gibt
///
/// Der Umsetzungsagent von #130 hat die Lücke selbst gemeldet, bevor sie
/// teuer wurde: `Fensterstand.grenzen(…)` und `Fensterstand.achse()` waren
/// **von keinem einzigen Test gedeckt**. Beide könnten stillschweigend
/// Unsinn zurückgeben, und der volle Lauf bliebe grün. Am 28.10.2026 ist
/// genau das eingetreten — `achse()` beschriftete die Wochenansicht mit
/// „So Mo Di Mi Do Fr Sa" statt „Mo Di Mi Do Fr Sa So", und keiner der
/// 1047 grünen Tests hat es gesehen. Gefunden wurde es von Hand im
/// Simulator.
///
/// `Fensterstand` ist ein `@immutable`-Werttyp ohne Widget-Baum: Er lässt
/// sich ohne Mocks, ohne Pumpen und ohne Pixelvergleich prüfen. Das ist der
/// billigste Ort für diese Behauptungen, und deshalb stehen sie hier und
/// nicht in `zeitdiagramm_test.dart`.
///
/// ## Der Fehler, den diese Datei festhält
///
/// `BerlinCalendar.startOfDay` (und alles, was daraus folgt: `startFenster`,
/// `addDays`, `platzBeginn`) liefert den **UTC-Zeitpunkt** einer Berliner
/// Mitternacht. Montag, 26.10.2026 00:00 Berliner Zeit *ist* der 25.10.2026
/// 23:00 UTC. `DateFormat` liest die UTC-Felder — formatiert steht dort also
/// der **Vortag**, und zwar immer, nicht nur über die Zeitumstellung: Im
/// Winter liegt Berlin auf UTC+1, im Sommer auf UTC+2, und beide Male ist
/// Berliner Mitternacht in UTC der Vortag.
///
/// Jede andere Stelle der App umgeht das über `kalendertag(…)`
/// (`lib/shell/erholung_abschnitte.dart`), deren Doc-Kommentar es wörtlich
/// sagt: „Alles, was ein Datum **anzeigt**, geht durch hier." `achse()` geht
/// nicht durch.
///
/// **Die Rechnung ist nicht schuld.** `startFenster` liefert für den
/// 26.10.2026 korrekt Montag 26.10. bis Montag 02.11.; der Test „W rastet
/// auch über die Zeitumstellung richtig" in
/// `test/shell/diagramm_zeitraum_test.dart` ist grün. Falsch ist allein die
/// **Anzeige**.
///
/// ## Entscheidungen dieser Datei — vom Test-Agenten, nicht von Tim
///
/// 1. **Welche Methoden geprüft werden.** `grenzen(…)` und `achse()` tragen
///    je eine Behauptung, die falsch werden kann, und waren ungedeckt —
///    sie sind der Auftrag. Dazu kommen `platzBeginn`, `abgelesen` und
///    `Fensterstand.leer`, weil auch sie eine Behauptung tragen
///    (Kalenderschritt statt 24-Stunden-Schritt; „keine Messung" statt
///    Nachbarwert; `null` statt `0`). Die Felder selbst und der öffentliche
///    Konstruktor behaupten nichts — sie legen ab, was `Fensterstand.aus`
///    gerechnet hat, und werden nicht einzeln geprüft.
///
///    **`==`/`hashCode` wird nicht geprüft, weil es sie nicht gibt.**
///    `Fensterstand` ist `@immutable`, aber keine Abhängigkeit eines
///    Providers: Er lebt im `State` des Diagramms und wird dort gehalten.
///    Die Regel aus `CLAUDE.md` („ein Werttyp, der Abhängigkeit eines
///    Providers ist, braucht `==`") greift hier nicht. Ein Test, der
///    Identitätsgleichheit prüft, bewiese nichts.
///
/// 2. **`tageZwischen` wird mitgeprüft, `monateZwischen` auch.** Beide sind
///    öffentlich, und `tageZwischen` trägt die schärfste Behauptung der
///    Datei: Die Woche ab dem 19.10.2026 hat 169 Stunden, und `inDays`
///    schnitte sie auf sechs Tage herunter. Darauf steht jede Platzrechnung
///    auf.
///
/// 3. **Der Wortlaut einer Achsenbeschriftung wird nicht festgenagelt.**
///    `CLAUDE.md`: keine Tests auf Beschriftungen. Erwartet wird deshalb
///    nicht `'Mo.'`, sondern `Format.wochentagKurz(DateTime.utc(2026, 10,
///    26))` — der Wortlaut, den `Format` für den **Kalendertag** Montag
///    liefert. Ob dort ein Punkt steht, ist eine offene Entscheidung
///    (siehe `formatierung.dart`), und sie geht diesen Fehler nichts an.
///    Scharf wird die Behauptung über die Gegenprobe: Es darf **nicht** der
///    Wortlaut des Sonntags davor sein.
///
///    Bei `Format.tagMonat` steht die Literalform (`'26.10.'`) da. Dieses
///    Format ist im Doc-Kommentar von `Format.tagMonat` festgelegt und in
///    `formatierung_test.dart` festgenagelt, und eine Meldung „erwartet
///    26.10., gefunden 25.10." benennt den Fehler so, wie er im Simulator
///    aussieht.
///
/// 4. **Drei Jahreszeiten, nicht nur die Zeitumstellung.** Ein Test, der nur
///    den 26.10.2026 prüft, ließe die Ursache halb stehen: Der Versatz ist
///    im Winter (UTC+1) wie im Sommer (UTC+2) da, nur unterschiedlich groß.
///    Geprüft werden deshalb eine Winterwoche, eine Sommerwoche und die
///    Woche nach der Umstellung.
///
/// 5. **Keine echten Gesundheitsdaten.** Alle Zahlen sind erfunden und so
///    gewählt, dass sie sich nicht gegenseitig als Teilzeichenkette
///    enthalten.
void main() {
  // Die Locale einmal laden, wie `formatierung_test.dart` es tut. `Format`
  // täte es selbst, aber ein Test, der sich darauf verlässt, prüft neben
  // seiner Sache auch noch eine Reihenfolge.
  setUpAll(() => initializeDateFormatting('de_DE'));

  // ───────────────────────────────────────────────────────────────────────
  // Hülle
  //
  // **Weitergezählt wird mit `BerlinCalendar.addDays`, nie über
  // `montag.day + i`.** `startOfDay` gibt einen UTC-*Zeitpunkt* zurück, der
  // eine Berliner Mitternacht bezeichnet; dessen UTC-Datum ist der Vortag.
  // Die erste Fassung der Hülle in `zeitdiagramm_test.dart` hat genau das
  // getan und sieben Fälle rot gemacht. Diese hier ist von dort übernommen.
  // ───────────────────────────────────────────────────────────────────────

  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  ({DateTime tag, double wert}) wert(DateTime t, double v) => (tag: t, wert: v);

  /// Eine volle Kalenderwoche ab `montag`, jeden Tag derselbe Wert.
  List<({DateTime tag, double wert})> woche(DateTime montag, double v) => [
    for (var i = 0; i < 7; i++) wert(BerlinCalendar.addDays(montag, i), v),
  ];

  Fensterstand stand(
    List<({DateTime tag, double wert})> reihe, {
    DiagrammStufe stufe = DiagrammStufe.woche,
    int verschiebung = 0,
  }) =>
      Fensterstand.aus(reihe: reihe, stufe: stufe, verschiebung: verschiebung);

  /// Der Wortlaut, den `Format` für einen **Kalendertag** liefert — also für
  /// ein reines Datum ohne Zeitzonenlast. Das ist der Maßstab: Genau diesen
  /// Wortlaut muss die Achse zeigen.
  String kurzFuer(int jahr, int monat, int t) =>
      Format.wochentagKurz(DateTime.utc(jahr, monat, t));

  List<String> achsenTexte(Fensterstand s) => [
    for (final eintrag in s.achse()) eintrag.text,
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // Der Tagesversatz: die Achse beschriftet den Tag, auf dem sie steht
  // ═══════════════════════════════════════════════════════════════════════

  group('achse(): die Wochenachse beginnt am Montag des Fensters', () {
    test('26.10.2026 — Montag, und der Tag nach der Zeitumstellung', () {
      // Der härteste Fall, den die Spec kennt: Die Sommerzeit endet am
      // Sonntag, 25.10.2026 um 01:00 UTC. `startFenster` rastet auf Montag,
      // den 26.10. — das ist in UTC der 25.10. um 23:00.
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(
        s.achse(),
        hasLength(7),
        reason: 'Bei `W` bekommt jeder der sieben Tage eine Beschriftung',
      );
      expect(
        achsenTexte(s).first,
        kurzFuer(2026, 10, 26),
        reason:
            'Das Fenster beginnt am Montag, 26.10.2026 — `startFenster` '
            'liefert ihn korrekt. Steht hier der Sonntag, ist nicht die '
            'Rechnung falsch, sondern die Anzeige: `platzBeginn` gibt den '
            'UTC-Zeitpunkt der Berliner Mitternacht (25.10. 23:00 UTC), und '
            '`DateFormat` liest dessen UTC-Felder. Der Weg daran vorbei '
            'heißt `kalendertag(…)` in `lib/shell/erholung_abschnitte.dart`',
      );
      expect(
        achsenTexte(s).first,
        isNot(kurzFuer(2026, 10, 25)),
        reason:
            'Der Sonntag davor gehört in das Fenster davor. Steht er hier, '
            'ist jedes angezeigte Datum des Diagramms einen Tag zu früh',
      );
    });

    test('mitten im Winter ist derselbe Versatz da (UTC+1)', () {
      // Keine Zeitumstellung weit und breit — und trotzdem liegt Berliner
      // Mitternacht in UTC auf dem Vortag. Ein Test, der nur die Umstellung
      // prüft, ließe die Ursache halb stehen.
      final s = stand(woche(tag(2026, 1, 12), 41));

      expect(achsenTexte(s).first, kurzFuer(2026, 1, 12));
      expect(
        achsenTexte(s).first,
        isNot(kurzFuer(2026, 1, 11)),
        reason:
            'Im Winter liegt Berlin auf UTC+1: Montag 00:00 Berlin ist '
            'Sonntag 23:00 UTC',
      );
    });

    test('mitten im Sommer auch (UTC+2)', () {
      final s = stand(woche(tag(2026, 7, 13), 41));

      expect(achsenTexte(s).first, kurzFuer(2026, 7, 13));
      expect(
        achsenTexte(s).first,
        isNot(kurzFuer(2026, 7, 12)),
        reason:
            'Im Sommer liegt Berlin auf UTC+2: Montag 00:00 Berlin ist '
            'Sonntag 22:00 UTC — derselbe Fehler, nur zwei Stunden tief',
      );
    });

    test('und die sieben Tage stehen in der richtigen Reihenfolge', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(
        achsenTexte(s),
        [
          for (var t = 26; t <= 31; t++) kurzFuer(2026, 10, t),
          kurzFuer(2026, 11, 1),
        ],
        reason:
            'Mo Di Mi Do Fr Sa So, beginnend am Fensteranfang. Im Simulator '
            'stand am 28.10.2026 So Mo Di Mi Do Fr Sa — um eins gedreht, '
            'weil jedes einzelne Datum einen Tag zu früh formatiert wurde',
      );
      expect(
        [for (final eintrag in s.achse()) eintrag.platz],
        [0, 1, 2, 3, 4, 5, 6],
        reason: 'Bei `W` trägt jeder Platz eine Beschriftung, Schritt 1',
      );
    });
  });

  group('achse(): auch die gröberen Stufen beschriften ihren eigenen Tag', () {
    test('`M` beschriftet jeden siebten Tag, beginnend am Monatsersten', () {
      // Oktober 2026 hat 31 Tage; das Fenster reicht vom 01.10. bis zum
      // 01.11. (halboffen).
      final s = stand([
        for (var t = 1; t <= 31; t++) wert(tag(2026, 10, t), 41),
      ], stufe: DiagrammStufe.monat);

      expect(
        [for (final eintrag in s.achse()) eintrag.platz],
        [0, 7, 14, 21, 28],
        reason:
            'Bei `M` jeder siebte Platz (Doc-Kommentar von `achse()`). Die '
            'Plätze zählen nach `plaetze` (31 im Oktober), nicht nach den '
            'gezeichneten 31 eines kürzeren Monats',
      );
      expect(
        achsenTexte(s).first,
        '01.10.',
        reason:
            'Der Monat beginnt am 1. Oktober. „30.09." wäre der Versatz, '
            'wortgleich zur Wochenachse — `platzBeginn(0)` ist der '
            '30.09.2026 22:00 UTC',
      );
      expect(
        achsenTexte(s),
        ['01.10.', '08.10.', '15.10.', '22.10.', '29.10.'],
        reason:
            'Sieben Tage Abstand, und der 29.10. liegt hinter der '
            'Zeitumstellung — der Abstand wird in Kalendertagen gezählt, '
            'nicht in 24-Stunden-Schritten',
      );
    });

    test('`M` im Februar zeigt 28 Plätze, nicht 31', () {
      final s = stand([
        for (var t = 1; t <= 28; t++) wert(tag(2026, 2, t), 41),
      ], stufe: DiagrammStufe.monat);

      expect(
        s.plaetze,
        28,
        reason: 'In das Fenster passen 28 Tage — dort hinein wird gewählt',
      );
      expect(
        s.gezeichnet,
        31,
        reason:
            '„`M` zeigt 31 Balken, damit auch der längste Monat ganz '
            'hineinpasst; in kürzeren Monaten bleibt rechts Luft" (Spec)',
      );
      expect(
        [for (final eintrag in s.achse()) eintrag.platz],
        [0, 7, 14, 21],
        reason:
            'Beschriftet werden die Plätze **im Fenster**, nicht die '
            'gezeichneten. Ein Strich unter Platz 28 stünde im Februar unter '
            'leerer Fläche',
      );
      expect(achsenTexte(s).first, '01.02.');
    });

    // ─────────────────────────────────────────────────────────────────────
    // #149 — ab `6M` steht der Monatsname auf der Achse, nicht der Erste
    //
    // Bis zum 28.10.2026 erwartete dieser Fall
    // `['01.05.', '01.06.', …]` und hieß „`6M` beschriftet jeden Monat mit
    // dessen Erstem". Tim hat die App auf dem Gerät geprüft und
    // entschieden: Monatsnamen. Bei `J` steht die „01." sonst zwölfmal da
    // und sagt nichts; das Entwurfsboard macht es für Monatsdiagramme
    // längst so (`docs/screens/screens/gym-progress.js`, `xLabels: MONTHS`).
    //
    // **Die Behauptung von damals bleibt trotzdem scharf**, nur anders
    // formuliert: Platz 0 ist der Mai, nicht der April. „30.04." war der
    // Tagesversatz, der sogar in den Vormonat fiel; „Apr" wäre heute
    // derselbe Fehler, nur lesbarer. Deshalb prüft jeder Fall beides — der
    // richtige Monat muss dastehen, der Vormonat darf nicht.
    // ─────────────────────────────────────────────────────────────────────

    test('`6M` beschriftet jeden Monat mit dessen Namen', () {
      // Sechs Monate, je ein Messwert — Mai bis Oktober 2026. Das Fenster
      // endet am 01.11. und reicht sechs Monate zurück: ab 01.05.
      final s = stand([
        for (var m = 5; m <= 10; m++) wert(tag(2026, m, 15), 41),
      ], stufe: DiagrammStufe.halbjahr);

      expect(
        [for (final eintrag in s.achse()) eintrag.platz],
        [0, 1, 2, 3, 4, 5],
        reason: 'Ab `6M` ist ein Platz ein Monat, und jeder wird beschriftet',
      );
      expect(
        achsenTexte(s),
        [
          for (var m = 5; m <= 10; m++)
            Format.monatKurz(DateTime.utc(2026, m, 1)),
        ],
        reason:
            'Der Monatsname, nicht sein Erster: Bei zwölf Monaten stünde '
            'die „01." zwölfmal da und sagte nichts (#149)',
      );
      expect(
        achsenTexte(s).first,
        Format.monatKurz(DateTime.utc(2026, 5, 1)),
        reason:
            'Platz 0 ist der Mai. Der April wäre derselbe Tagesversatz wie '
            'das frühere „30.04." — die Achse behauptete einen Monat, der '
            'nicht im Fenster liegt',
      );
      expect(
        achsenTexte(s),
        isNot(contains(Format.monatKurz(DateTime.utc(2026, 4, 1)))),
      );
    });

    test('`J` auch — dort trägt die alte Form zwölfmal dieselbe „01."', () {
      // Zwölf Monate, je ein Messwert — November 2025 bis Oktober 2026.
      final s = stand([
        for (var i = 0; i < 12; i++)
          wert(BerlinCalendar.addMonths(tag(2025, 11, 15), i), 41),
      ], stufe: DiagrammStufe.jahr);

      expect(
        s.plaetze,
        12,
        reason: 'Ohne zwölf Plätze prüfte dieser Fall nicht, worum es geht',
      );
      expect(
        achsenTexte(s).toSet().length,
        12,
        reason:
            'Zwölf Monate, zwölf verschiedene Beschriftungen. Mit '
            '`Format.tagMonat` stünde zwölfmal „01." am Anfang — genau Tims '
            'Beanstandung',
      );
      expect(achsenTexte(s).first, Format.monatKurz(DateTime.utc(2025, 11, 1)));
      expect(achsenTexte(s).last, Format.monatKurz(DateTime.utc(2026, 10, 1)));
    });

    test('`W` und `M` ändern sich nicht mit', () {
      final w = stand(woche(tag(2026, 10, 26), 41));
      expect(
        achsenTexte(w).first,
        kurzFuer(2026, 10, 26),
        reason:
            'Bei `W` bleibt der Wochentag — Tims Entscheidung nennt `6M` '
            'und `J`, sonst nichts',
      );

      final m = stand([
        for (var t = 1; t <= 31; t++) wert(tag(2026, 10, t), 41),
      ], stufe: DiagrammStufe.monat);
      expect(
        achsenTexte(m).first,
        '01.10.',
        reason:
            'und bei `M` das Tagesdatum. Ein Monatsname stünde dort fünfmal '
            'untereinander',
      );
    });

    test('eine leere Reihe hat keine Achse', () {
      expect(
        stand(const []).achse(),
        isEmpty,
        reason:
            'Ohne Fenster gibt es keinen Platz zu beschriften. Eine '
            'Beschriftung über leerer Fläche behauptete einen Tag, den '
            'niemand gemessen hat',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // grenzen(…): was die y-Achse aufspannt
  // ═══════════════════════════════════════════════════════════════════════

  group('grenzen(): Balken wachsen aus der Null', () {
    test('die Null liegt immer mit drin, auch bei lauter hohen Werten', () {
      final s = stand(woche(tag(2026, 10, 26), 500));

      expect(
        s.grenzen(linien: const [], alsBalken: true),
        (0.0, 500.0),
        reason:
            '„Balken wachsen aus der Null" (`lineChart` im Entwurfsboard). '
            'Spannte die Achse nur 500 bis 500 auf, stünden sieben gleich '
            'hohe Balken als volle Fläche da und die Zahl wäre nicht mehr '
            'abzulesen',
      );
    });

    test('ein negativer Wert zieht die Untergrenze mit', () {
      final s = stand([
        wert(tag(2026, 10, 26), -12),
        wert(tag(2026, 10, 27), 30),
        ...[for (var t = 28; t <= 31; t++) wert(tag(2026, 10, t), 30)],
        wert(tag(2026, 11, 1), 30),
      ]);

      expect(
        s.grenzen(linien: const [], alsBalken: true),
        (-12.0, 30.0),
        reason:
            'Ein Balken unter der Null muss sichtbar bleiben; `min(0, …)` '
            'senkt die Grenze, es hebt sie nie an',
      );
    });

    test('eine Linie füllt die Spanne ihrer Werte, ohne die Null', () {
      // Gewicht und Umfänge: Eine Linie von 78 bis 82 kg über eine Achse ab
      // 0 zu zeichnen macht sie zu einem waagerechten Strich.
      final s = stand([
        wert(tag(2026, 10, 26), 78),
        wert(tag(2026, 10, 27), 79),
        wert(tag(2026, 10, 28), 80),
        wert(tag(2026, 10, 29), 81),
        wert(tag(2026, 10, 30), 82),
        wert(tag(2026, 10, 31), 80),
        wert(tag(2026, 11, 1), 79),
      ]);

      expect(
        s.grenzen(linien: const [], alsBalken: false),
        (78.0, 82.0),
        reason:
            '„Eine Linie füllt die Spanne ihrer Werte" (`lineChart` im '
            'Entwurfsboard). Ab der Null wäre jede Gewichtskurve flach',
      );
    });

    test('eine Ziellinie über allen Balken hebt die Obergrenze', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      final (unten, oben) = s.grenzen(linien: const [250], alsBalken: true);
      expect(unten, 0.0, reason: 'Balken wachsen aus der Null');
      expect(
        oben,
        greaterThanOrEqualTo(250.0),
        reason:
            '„Die Ziellinien zählen mit — eine Ziellinie außerhalb der Achse '
            'wäre unsichtbar und damit wertlos" (Doc-Kommentar von '
            '`grenzen`). Genau so sieht ein Wochenziel über einer schwachen '
            'Woche aus, und das ist der Fall, in dem man es sehen will.\n'
            'Hier stand bis zum 29.10.2026 genau `(0.0, 250.0)` — die '
            'Obergrenze **auf** der Ziellinie. Dort fiel sie mit der '
            'obersten Rasterlinie zusammen und ihre Beschriftung wurde '
            'abgeschnitten (#162); seither bleibt über ihr Luft. Wie viel, '
            'steht in `zeitdiagramm_ziellinien_test.dart` — hier gehört nur '
            'hin, dass die Linie überhaupt auf die Achse kommt',
      );
    });

    test('eine Ziellinie unter allen Werten senkt die Untergrenze', () {
      // Linie statt Balken — sonst zöge `min(0, …)` die Grenze ohnehin auf
      // die Null und die Behauptung wäre nicht trennscharf.
      final s = stand([
        for (var i = 0; i < 7; i++)
          wert(BerlinCalendar.addDays(tag(2026, 10, 26), i), 78),
      ]);

      final (unten, oben) = s.grenzen(linien: const [60], alsBalken: false);
      expect(
        unten,
        lessThanOrEqualTo(60.0),
        reason:
            'Auch nach unten: eine unsichtbare Ziellinie ist wertlos. Genau '
            '`60.0` stand hier bis zum 29.10.2026 — seit #162 bleibt auch '
            'unter der Linie Luft, aus demselben Grund wie darüber',
      );
      expect(oben, 78.0, reason: 'Oben bestimmt die Messung, nicht die Linie');
    });

    test('mehrere Ziellinien spannen beide Enden auf', () {
      final s = stand(woche(tag(2026, 10, 26), 78));

      final (unten, oben) = s.grenzen(linien: const [60, 95], alsBalken: false);
      expect(
        unten,
        lessThanOrEqualTo(60.0),
        reason: 'Die äußerste zählt, nicht die erste',
      );
      expect(
        oben,
        greaterThanOrEqualTo(95.0),
        reason:
            'Dieselbe Behauptung nach oben. Bis zum 29.10.2026 stand hier '
            'genau `(60.0, 95.0)`; seit #162 liegt um jede der beiden Linien '
            'noch Luft für ihre Beschriftung',
      );
    });

    test('Balken außerhalb des Fensters zählen nicht mit', () {
      // `Fensterstand` hält auch die Nachbarn links und rechts, damit beim
      // Wischen am Rand nicht plötzlich nichts steht. Für die y-Achse dürfen
      // sie nicht zählen: Sonst staucht ein Ausreißer aus der Vorwoche die
      // sichtbare Woche zusammen.
      final s = stand([
        ...woche(tag(2026, 10, 19), 900),
        ...woche(tag(2026, 10, 26), 41),
      ]);

      expect(
        s.balken.length,
        greaterThan(s.plaetze),
        reason:
            'Die Nachbarwoche liegt mit im Stand — sonst prüfte dieser Fall '
            'nichts',
      );
      expect(
        s.grenzen(linien: const [], alsBalken: true),
        (0.0, 41.0),
        reason:
            'Die 900 der Vorwoche liegt bei negativen Plätzen und gehört '
            'nicht auf die Achse dieses Fensters. Zählte sie mit, sähe die '
            'gezeigte Woche aus wie ein flacher Strich',
      );
    });

    test('lauter gleiche Werte ergeben trotzdem eine Spanne', () {
      final s = stand(woche(tag(2026, 10, 26), 78));

      final (unten, oben) = s.grenzen(linien: const [], alsBalken: false);
      expect(
        oben,
        greaterThan(unten),
        reason:
            'Eine Achse mit Höhe 0 teilt beim Zeichnen durch null. Bei '
            'lauter gleichen Werten muss oben über unten liegen',
      );
      expect((unten, oben), (78.0, 79.0));
    });

    test('ohne jeden Wert eine brauchbare Achse statt einer leeren', () {
      expect(
        stand(const []).grenzen(linien: const [], alsBalken: true),
        (0.0, 1.0),
        reason:
            'Ein leerer Stand hat kein Fenster und keinen Balken. Die Achse '
            'muss trotzdem eine Höhe haben, sonst stürzt das Zeichnen ab',
      );
    });

    test('ohne Balken, aber mit Ziellinie zählt die Ziellinie', () {
      const leer = Fensterstand.leer(DiagrammStufe.woche);

      final (unten, oben) = leer.grenzen(linien: const [120], alsBalken: true);
      expect(
        (unten, oben >= 120),
        (0.0, true),
        reason:
            'Auch ohne einen einzigen Balken muss die Ziellinie auf der '
            'Achse liegen — sonst zeichnet der Schirm sie ins Nichts. Als '
            'Balkendiagramm beginnt die Achse dabei bei null. Genau '
            '`(0.0, 120.0)` stand hier bis zum 29.10.2026: Die Linie lag '
            'damit auf der obersten Rasterlinie und ihre Beschriftung im '
            'Nichts darüber (#162)',
      );
      expect(
        leer.grenzen(linien: const [120], alsBalken: false),
        (120.0, 121.0),
        reason:
            'Als Linie spannt eine einzelne Ziellinie keine Spanne auf. Die '
            'Obergrenze fällt aus `oben <= unten` heraus — eine Achse der '
            'Höhe 0 teilte beim Zeichnen durch null',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Die übrigen Behauptungen
  // ═══════════════════════════════════════════════════════════════════════

  group('Fensterstand.leer behauptet keine Messung', () {
    test('kein Fenster, kein Platz, kein Durchschnitt', () {
      const s = Fensterstand.leer(DiagrammStufe.woche);

      expect(s.von, isNull);
      expect(s.bis, isNull);
      expect(
        s.schnitt,
        isNull,
        reason:
            '„Eine 0 stünde hier für eine Messung, die es nicht gab" '
            '(`docs/todo/01`)',
      );
      expect(s.plaetze, 0);
      expect(s.balken, isEmpty);
      expect(s.maxVerschiebung, 0);
      expect(
        s.platzBeginn(0),
        isNull,
        reason: 'ohne Fenster hat kein Platz einen Beginn',
      );
      expect(s.abgelesen(0), isNull);
    });

    test('eine leere Reihe führt dorthin', () {
      final s = stand(const []);
      expect(s.von, isNull);
      expect(s.schnitt, isNull);
    });
  });

  group('platzBeginn() zählt in Kalenderschritten', () {
    test('bei `W` über die Zeitumstellung hinweg', () {
      // Die Woche ab dem 26.10.2026 beginnt am Tag nach der Umstellung; die
      // Woche davor hat 169 Stunden. Ein Schritt von 24 Stunden liefe
      // irgendwann mitten in den Tag hinein.
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(BerlinCalendar.dayKey(s.platzBeginn(0)!), '2026-10-26');
      expect(BerlinCalendar.dayKey(s.platzBeginn(6)!), '2026-11-01');
      for (var platz = 0; platz < 7; platz++) {
        expect(
          BerlinCalendar.wallClock(s.platzBeginn(platz)!),
          (0, 0),
          reason:
              'Jeder Platz beginnt zur Berliner Mitternacht. Steht dort '
              '23:00, ist in 24-Stunden-Schritten gerechnet worden',
        );
      }
    });

    test('bei `6M` in Monaten, nicht in 30 Tagen', () {
      final s = stand([
        for (var m = 5; m <= 10; m++) wert(tag(2026, m, 15), 41),
      ], stufe: DiagrammStufe.halbjahr);

      expect(BerlinCalendar.dayKey(s.platzBeginn(0)!), '2026-05-01');
      expect(BerlinCalendar.dayKey(s.platzBeginn(3)!), '2026-08-01');
      expect(BerlinCalendar.dayKey(s.platzBeginn(5)!), '2026-10-01');
    });
  });

  group('abgelesen() nennt den Balken, auf dem der Finger liegt', () {
    test('Tag und Wert gehören zusammen', () {
      final s = stand([
        wert(tag(2026, 10, 26), 11),
        wert(tag(2026, 10, 27), 22),
        wert(tag(2026, 10, 28), 33),
        wert(tag(2026, 10, 29), 44),
        wert(tag(2026, 10, 30), 55),
        wert(tag(2026, 10, 31), 66),
        wert(tag(2026, 11, 1), 77),
      ]);

      final erster = s.abgelesen(0)!;
      expect(erster.wert, 11);
      expect(
        BerlinCalendar.dayKey(erster.beginn),
        '2026-10-26',
        reason:
            'Der abgelesene Balken nennt **sein eigenes** Datum. Als Wert '
            'stimmt der Zeitpunkt hier; angezeigt wird er in '
            '`zeitdiagramm.dart`, und dort steht der Versatz',
      );

      final letzter = s.abgelesen(6)!;
      expect(letzter.wert, 77);
      expect(BerlinCalendar.dayKey(letzter.beginn), '2026-11-01');
    });

    test('über einer Lücke steht kein Wert, nie der Nachbarwert', () {
      final s = stand([
        wert(tag(2026, 10, 26), 11),
        wert(tag(2026, 11, 1), 77),
      ]);

      final mitte = s.abgelesen(3)!;
      expect(
        mitte.wert,
        isNull,
        reason:
            '„Ein Tag ohne Messung gibt den Tag mit `wert == null` zurück — '
            'daraus wird „keine Messung", nie der Nachbarwert"',
      );
      expect(
        BerlinCalendar.dayKey(mitte.beginn),
        '2026-10-29',
        reason: 'der Tag steht trotzdem da, nur ohne Zahl',
      );
    });

    test('ohne Auswahl nichts', () {
      expect(stand(woche(tag(2026, 10, 26), 41)).abgelesen(null), isNull);
    });
  });

  group('tageZwischen() zählt Kalendertage, keine 24-Stunden-Schritte', () {
    test('die Woche ab dem 19.10.2026 hat 169 Stunden und 7 Tage', () {
      final von = tag(2026, 10, 19);
      final bis = tag(2026, 10, 26);

      expect(
        bis.difference(von).inHours,
        169,
        reason:
            'Erst die Vorbedingung: Diese Woche enthält die Umstellung auf '
            'die Winterzeit und ist eine Stunde länger',
      );
      expect(
        tageZwischen(von, bis),
        7,
        reason:
            '`inDays` schnitte 169 Stunden auf 7 ab — hier zufällig richtig. '
            'Der Fall darunter ist der, an dem es bricht',
      );
    });

    test('und die Woche ab dem 23.03.2026 hat 167 Stunden und 7 Tage', () {
      // Die Umstellung auf die Sommerzeit liegt am Sonntag, 29.03.2026 um
      // 01:00 UTC — also **innerhalb** der Woche ab Montag, dem 23.03.
      // Diese Woche ist eine Stunde **kürzer**, und `inDays` schnitte sie
      // auf sechs Tage herunter.
      final von = tag(2026, 3, 23);
      final bis = tag(2026, 3, 30);

      expect(bis.difference(von).inHours, 167);
      expect(
        bis.difference(von).inDays,
        6,
        reason:
            'Die Vorbedingung: `inDays` liegt hier tatsächlich daneben. Ohne '
            'diesen Nachweis prüfte der Fall darunter nichts',
      );
      expect(
        tageZwischen(von, bis),
        7,
        reason:
            '„Gezählt wird über `BerlinCalendar.dayKey` und nicht über die '
            'verstrichene Zeit" (Doc-Kommentar). Sieben Kalendertage bleiben '
            'sieben, egal wie viele Stunden dazwischen liegen',
      );
    });

    test('rückwärts negativ, auf der Stelle null', () {
      expect(tageZwischen(tag(2026, 10, 26), tag(2026, 10, 26)), 0);
      expect(tageZwischen(tag(2026, 10, 26), tag(2026, 10, 19)), -7);
    });

    test('ein Zeitpunkt mitten am Tag zählt als dieser Tag', () {
      // 22:30 UTC am 26.10.2026 ist in Berlin (UTC+1) der 26.10. um 23:30 —
      // noch derselbe Kalendertag.
      expect(
        tageZwischen(tag(2026, 10, 26), DateTime.utc(2026, 10, 26, 22, 30)),
        0,
        reason:
            'Gezählt werden Kalendertage. Ein Zeitpunkt am Abend ist kein '
            'angebrochener achter Tag',
      );
    });
  });

  group('monateZwischen() zählt Kalendermonate', () {
    test('über einen Jahreswechsel hinweg', () {
      expect(monateZwischen(tag(2025, 11, 1), tag(2026, 5, 1)), 6);
      expect(monateZwischen(tag(2026, 1, 1), tag(2026, 1, 1)), 0);
      expect(monateZwischen(tag(2026, 5, 1), tag(2025, 11, 1)), -6);
    });

    test('der Februar zählt wie jeder andere Monat', () {
      expect(
        monateZwischen(tag(2026, 1, 1), tag(2026, 3, 1)),
        2,
        reason:
            'In Tagen gerechnet wären es 59 und damit nicht zwei gleich '
            'lange Schritte',
      );
    });
  });

  group('nachTagen()', () {
    test('`W` und `M` zählen Tage, `6M` und `J` Monate', () {
      expect(nachTagen(DiagrammStufe.woche), isTrue);
      expect(nachTagen(DiagrammStufe.monat), isTrue);
      expect(nachTagen(DiagrammStufe.halbjahr), isFalse);
      expect(nachTagen(DiagrammStufe.jahr), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Ein Rastschritt ist ein Platz, kein Fenster — geändert am 28.10.2026
  //
  // Bis heute zählte `verschiebung` in **Fenstern**: `schritteProFenster`
  // gab 1 für `W` und `M`, 6 für `6M`, 12 für `J`, und ein Wisch über die
  // volle Breite blätterte genau ein Fenster weiter. Tim hat die App am
  // 28.10.2026 auf dem iPhone geprüft: „das wischen reagiert komisch ich
  // muss sehr weit wischen und es fühlt sich nicht flüssig an" (#145).
  //
  // Neu zählt `verschiebung` in **Plätzen** — bei `W` und `M` in
  // Kalendertagen, bei `6M` und `J` in Kalendermonaten, also genau in der
  // Einheit, in der auch `plaetze`, `platzBeginn` und `achse` rechnen. Die
  // Funktion `schritteProFenster` gibt es deshalb nicht mehr; was ein Zug
  // über die volle Breite blättert, steht jetzt in `gezeichnet`.
  //
  // Ein Fenster darf damit mitten in der Woche beginnen. Die alte
  // Begründung — „Ein Fenster, das mitten in der Woche beginnt, lässt sich
  // nicht mit dem Nachbarfenster vergleichen" (Entwurfs-Spec, „Einrasten")
  // — war eine Entscheidung ohne Gerät; dieselbe Spec sieht „langsam
  // gezogen bleibt stehen" ausdrücklich vor.
  // ═══════════════════════════════════════════════════════════════════════

  group('Ein Rastschritt ist ein Platz, kein Fenster', () {
    test('`W` schiebt das Fenster um Kalendertage', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 41),
        ...woche(tag(2026, 10, 26), 41),
      ], verschiebung: 1);

      expect(
        s.von,
        tag(2026, 10, 25),
        reason:
            'Ein Schritt zurück ist **ein Tag**. War es eine ganze Woche, '
            'stünde hier der 19.10. — und Tim müsste wieder über die halbe '
            'Breite ziehen, um sich überhaupt zu bewegen (#145)',
      );
      expect(
        s.bis,
        tag(2026, 11, 1),
        reason: 'und das Fenster bleibt sieben Tage breit',
      );
      expect(s.plaetze, 7);
    });

    test('ein Fenster darf mitten in der Woche beginnen', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 41),
        ...woche(tag(2026, 10, 26), 41),
      ], verschiebung: 3);

      expect(
        s.von,
        tag(2026, 10, 23),
        reason:
            'Der 23.10.2026 ist ein Freitag. Genau das war bis zum '
            '28.10.2026 ausgeschlossen',
      );
    });

    test('`6M` schiebt um Kalendermonate, nicht um Halbjahre', () {
      // Zehn Monate, damit links überhaupt Platz zum Blättern ist: Der
      // Anschlag liegt am Balken der ersten Messung.
      final s = stand(
        [for (var m = 1; m <= 10; m++) wert(tag(2026, m, 15), 41)],
        stufe: DiagrammStufe.halbjahr,
        verschiebung: 1,
      );

      expect(
        s.von,
        tag(2026, 4, 1),
        reason:
            'Ab `6M` ist ein Platz ein Monat, also ist auch ein Schritt ein '
            'Monat. Sechs wären ein ganzes Fenster — die alte Regel',
      );
      expect(s.bis, tag(2026, 10, 1));
      expect(s.plaetze, 6);
    });

    test('der linke Anschlag zählt in derselben Einheit', () {
      // Drei volle Wochen: der erste Messwert liegt vierzehn Tage vor dem
      // Beginn des Startfensters.
      final s = stand([
        ...woche(tag(2026, 10, 12), 41),
        ...woche(tag(2026, 10, 19), 41),
        ...woche(tag(2026, 10, 26), 41),
      ]);

      expect(
        s.maxVerschiebung,
        14,
        reason:
            'Vierzehn Tagesschritte, nicht zwei Wochenschritte. Zählte der '
            'Anschlag weiter in Wochen, bliebe das Fenster schon nach zwei '
            'Plätzen stehen',
      );
    });

    test('und er klemmt, was darüber hinausgeht', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 41),
        ...woche(tag(2026, 10, 26), 41),
      ], verschiebung: 99);

      expect(s.verschiebung, 7);
      expect(
        s.von,
        tag(2026, 10, 19),
        reason:
            'Weiter zurück stünde der Schirm auf leerer Fläche — „der '
            'Wertebereich beginnt am Balken der ersten Messung" (Spec)',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // sichtbar(): der Ausschnitt, der während eines Zuges im Bild steht
  //
  // Der Kern von #147: Während des Zuges wurden die Nachbarpunkte
  // mitgezeichnet, aber mit der y-Skala und der Achse des **alten**
  // Fensters. Die Linie schoss oben und unten aus dem Bild, und von der
  // Achse blieb ein einzelnes „Mo." stehen.
  // ═══════════════════════════════════════════════════════════════════════

  group('sichtbar(): der Ausschnitt während eines Zuges', () {
    test('ohne Zug ist es genau das Fenster', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(
        s.sichtbar(0),
        (0, 7),
        reason:
            'Liegt kein Versatz an, ist der gezeigte Ausschnitt das Fenster '
            'selbst — sonst änderte diese Änderung den Ruhezustand mit',
      );
      expect(
        s.grenzen(linien: const [], alsBalken: true, ausschnitt: s.sichtbar(0)),
        s.grenzen(linien: const [], alsBalken: true),
        reason: 'und beide Wege ergeben dieselbe Achse',
      );
      expect(
        [for (final e in s.achse(s.sichtbar(0))) e.platz],
        [for (final e in s.achse()) e.platz],
      );
    });

    test('ein Zug nach rechts holt ältere Plätze ins Bild', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(
        s.sichtbar(4.5),
        (-5, 3),
        reason:
            'Viereinhalb Plätze nach rechts gezogen: Links stehen fünf '
            'angeschnittene Plätze der Vorwoche, rechts endet das Bild '
            'mitten im dritten. Angeschnittene zählen mit — sie sind zu '
            'sehen',
      );
    });

    test('die y-Skala folgt dem Ausschnitt, nicht dem alten Fenster', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 900),
        ...woche(tag(2026, 10, 26), 41),
      ]);

      expect(s.grenzen(linien: const [], alsBalken: true), (
        0.0,
        41.0,
      ), reason: 'im Ruhezustand steht nur die flache Woche im Bild');
      expect(
        s.grenzen(
          linien: const [],
          alsBalken: true,
          ausschnitt: s.sichtbar(4.5),
        ),
        (0.0, 900.0),
        reason:
            'Sobald die Vorwoche ins Bild wandert, gehört sie auf die Achse. '
            'Tut sie das nicht, schießt die Linie oben aus dem Bild — Tims '
            'Video vom 28.10.2026 (#147)',
      );
    });

    test('die Achse beschriftet die Plätze, die im Bild stehen', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 41),
        ...woche(tag(2026, 10, 26), 41),
      ]);

      final plaetze = [for (final e in s.achse(s.sichtbar(4.5))) e.platz];

      expect(
        plaetze,
        [-5, -4, -3, -2, -1, 0, 1, 2],
        reason:
            'Blieb die Achse beim alten Fenster, stünde von ihr nur noch '
            'der letzte Tag im Bild — „von der Achse bleibt ein einzelnes '
            '„Mo." stehen" (#147)',
      );
      expect(
        s.achse(s.sichtbar(4.5)).first.text,
        kurzFuer(2026, 10, 21),
        reason:
            'Platz -5 ist der 21.10.2026, fünf Tage vor dem Fensterbeginn. '
            'Auch negative Plätze gehen durch `kalendertag`',
      );
    });

    test('bei `M` bleibt der Raster der Beschriftung stehen', () {
      final s = stand([
        for (var t = 1; t <= 31; t++) wert(tag(2026, 10, t), 41),
      ], stufe: DiagrammStufe.monat);

      expect(
        [for (final e in s.achse()) e.platz],
        [0, 7, 14, 21, 28],
        reason: 'im Ruhezustand jeder siebte Platz des Fensters',
      );
      expect(
        [for (final e in s.achse(s.sichtbar(8))) e.platz],
        [-7, 0, 7, 14, 21],
        reason:
            '`M` beschriftet jeden siebten Platz, und der Raster hängt am '
            'Fensterbeginn, nicht am Rand des Bildes: Links kommt -7 dazu, '
            'rechts fällt 28 heraus. Hinge er am Bildrand, wanderten die '
            'Beschriftungen beim Ziehen zwischen den Balken hin und her',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #150 — die Kopfzeile läuft beim Ziehen mit
  //
  // `sichtbar(…)` gibt seit dem 28.10.2026 den gezeigten Ausschnitt, und
  // `grenzen(…, ausschnitt:)` und `achse([ausschnitt])` benutzen ihn. Die
  // Kopfzeile blieb stehen: „Durchschnitt 333 · 05.10. – 11.10." über einer
  // Achse, die längst andere Tage nannte. Tim stört das.
  //
  // Durchschnitt und Zeitraum müssen über **denselben** Ausschnitt rechnen
  // wie Achse und y-Skala. Geprüft wird das hier, wo gerechnet wird; dass
  // das Bauteil die Rechnung auch wirklich fragt, steht in
  // `zeitdiagramm_test.dart`.
  //
  // **Entscheidungen dieser Ergänzung — vom Test-Agenten, nicht von Tim:**
  //
  // a) **Eine Methode für beides, nicht zwei.** Zeitraum und Durchschnitt
  //    sind dieselbe Frage an denselben Ausschnitt, und sie müssen
  //    zusammenpassen: Ein Durchschnitt über acht Tage neben einem Zeitraum
  //    über sieben wäre eine falsche Auskunft. Eine Methode kann nicht halb
  //    aufgerufen werden.
  // b) **Ohne Ausschnitt gilt das Fenster, und zwar wortgleich zu den
  //    Feldern.** `ueberblick()` muss `von`, `bis` und `schnitt` ergeben —
  //    sonst gäbe es zwei Rechnungen für denselben Ruhezustand, und sie
  //    könnten auseinanderlaufen. Derselbe Schnitt wie bei `grenzen` und
  //    `achse`.
  // c) **Gewogen nach gemessenen Tagen.** Bei `W` und `M` steckt hinter
  //    jedem Platz genau ein Tag, da fällt es nicht auf. Ab `6M` ist ein
  //    Platz ein Monat, und die Kopfzeile nennt den Durchschnitt **je Tag**
  //    (Spec, „Verdichtung ab 6M") — ein Monat mit einer einzigen Messung
  //    darf nicht so schwer wiegen wie ein voller.
  // d) **Ein Ausschnitt ohne Messung hat `null`, nicht `0`.** Dasselbe wie
  //    `Fensterstand.leer`: Eine 0 stünde für eine Messung, die es nicht
  //    gab (`docs/todo/01`).
  // ═══════════════════════════════════════════════════════════════════════

  group('ueberblick(): was die Kopfzeile über den Ausschnitt sagt', () {
    test('ohne Zug ist es genau das Fenster', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      expect(
        s.ueberblick(),
        (von: s.von, bis: s.bis, schnitt: s.schnitt),
        reason:
            'Liegt kein Versatz an, sagt die Kopfzeile dasselbe wie bisher. '
            'Zwei Rechnungen für denselben Ruhezustand könnten '
            'auseinanderlaufen',
      );
      expect(
        s.ueberblick(s.sichtbar(0)),
        s.ueberblick(),
        reason:
            'und beide Wege ergeben dieselbe Auskunft — wie bei '
            '`grenzen` und `achse`',
      );
    });

    test('ein Zug nimmt den Zeitraum mit', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 900),
        ...woche(tag(2026, 10, 26), 500),
      ]);

      final blick = s.ueberblick(s.sichtbar(4.5));

      expect(
        blick.von,
        s.platzBeginn(-5),
        reason:
            'Viereinhalb Plätze nach rechts gezogen beginnt das Bild fünf '
            'Tage vor dem Fenster — der 21.10.2026',
      );
      expect(
        blick.bis,
        s.platzBeginn(3),
        reason:
            'und endet mitten im dritten Platz. Halboffen wie `von`/`bis`, '
            'damit der Schirm wie bisher einen Tag abzieht',
      );
      expect(
        blick.von,
        isNot(s.von),
        reason:
            'Bliebe der Zeitraum beim Fenster, stünde über einer Achse, die '
            'den 21.10. nennt, weiter „26.10. – 01.11." (#150)',
      );
    });

    test('und den Durchschnitt', () {
      final s = stand([
        ...woche(tag(2026, 10, 19), 900),
        ...woche(tag(2026, 10, 26), 500),
      ]);

      expect(s.schnitt, 500, reason: 'im Ruhezustand die gezeigte Woche');
      expect(
        s.ueberblick(s.sichtbar(4.5)).schnitt,
        750,
        reason:
            'Im Bild stehen fünf Tage der 900er-Woche und drei der '
            '500er-Woche: (5 × 900 + 3 × 500) / 8 = 750. Bleibt der '
            'Durchschnitt beim alten Fenster, behauptet die Kopfzeile einen '
            'Wert für Tage, die niemand sieht',
      );
    });

    test('ab `6M` wiegt ein Monat so viel, wie er gemessene Tage hat', () {
      // September: ein einziger Messtag mit 400. Oktober: drei Messtage mit
      // je 100. Ungewogen wäre der Schnitt 250, gewogen 175.
      final s = stand([
        for (var m = 5; m <= 8; m++) wert(tag(2026, m, 15), 10),
        wert(tag(2026, 9, 15), 400),
        for (var t = 1; t <= 3; t++) wert(tag(2026, 10, t), 100),
      ], stufe: DiagrammStufe.halbjahr);

      expect(
        s.ueberblick((4, 6)).schnitt,
        175,
        reason:
            'Die Kopfzeile nennt den Durchschnitt **je Tag** (Spec, '
            '„Verdichtung ab 6M"). Ungewogen stünden dort 250 — ein Monat '
            'mit einer einzigen Messung wöge so viel wie ein voller',
      );
    });

    test('ein Ausschnitt ohne Messung hat keinen Durchschnitt', () {
      final s = stand(woche(tag(2026, 10, 26), 41));

      final blick = s.ueberblick((-30, -20));

      expect(
        blick.schnitt,
        isNull,
        reason:
            '„Eine 0 stünde hier für eine Messung, die es nicht gab" '
            '(`docs/todo/01`) — dort steht dann „—", keine Null',
      );
      expect(
        blick.von,
        isNotNull,
        reason:
            'Der Zeitraum gibt es trotzdem: Die Tage sind zu sehen, nur '
            'gemessen wurde an ihnen nichts',
      );
    });

    test('ein leerer Stand verspricht nichts', () {
      const s = Fensterstand.leer(DiagrammStufe.woche);

      expect(s.ueberblick(), (von: null, bis: null, schnitt: null));
      expect(
        s.ueberblick((0, 7)),
        (von: null, bis: null, schnitt: null),
        reason:
            'Ohne Fenster hat kein Platz einen Beginn — auch nicht mit '
            'einem Ausschnitt in der Hand',
      );
    });
  });
}
