import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/tagesgrenze.dart`, Teil 2, und
/// den neuen Parameter von `essenKarte` — Task 3 des Umsetzungsplans
/// `docs/superpowers/plans/2026-11-10-tagesgrenze.md` (#453, #375), Spec
/// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Vorgabe V14,
/// Entscheidung 6, Abschnitte „Uhrzeit und Mahlzeit im Tag“ und
/// „Live-Aktivität“.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## API, die diese Tests verbindlich vorgeben (aus der Spec)
///
/// ```dart
/// DateTime wanduhrZeitpunkt(String tag, int minuten);
/// DateTime zeitpunktImTag({required String tag, required int minuten,
///     Tagesgrund grund = Tagesgrund.normal});
/// Mahlzeit mahlzeitImTag({required int minuten,
///     Tagesgrund grund = Tagesgrund.normal});
/// EssenKarte essenKarte({required List<MahlzeitStand> mahlzeiten,
///     required ({int heute, int abMorgen}) serie, required DateTime jetzt,
///     DateTime? verfaelltUm});
/// ```
///
/// ## Die Regeln aus der Spec
///
/// - **`wanduhrZeitpunkt`** ist `_alsZeitpunkt` aus
///   `app/lib/ernaehrung/erfassen_formular.dart`, in den Kern gezogen „samt
///   seiner Behandlung der übersprungenen und der doppelten Stunde“: In der
///   übersprungenen Stunde (März) gilt der Sommerversatz (UTC+2), in der
///   doppelten (Oktober) die erste, also ebenfalls UTC+2.
/// - **`zeitpunktImTag`** (V14): Normal und „läuft noch“ → vor 04:00 der
///   Folgetag, sonst der Tag selbst. Verlängert → vor 08:00 der Folgetag.
///   Nach einer früh beendeten Nacht → der Tag selbst.
/// - **`mahlzeitImTag`** (Entscheidung 6): verlängert und vor 08:00 →
///   Abend; Nacht vorbei und vor 04:00 → Frühstück; sonst
///   `Mahlzeitfenster.fuer(minuten)`.
/// - **`essenKarte(…, verfaelltUm: x)`** trägt `x`; fehlt der Parameter,
///   gilt wie bisher `naechsterEsstagBeginn(jetzt)`. Additiv —
///   `live_aktivitaet_test.dart` bleibt unverändert.
///
/// ## Wie die Zeitpunkte entstehen
///
/// Jede Erwartung steht als **UTC-Literal** da, mit der Berliner Wanduhr im
/// Kommentar, und wird in der Gruppe „Gegenprobe der Erwartungen“ über
/// `BerlinCalendar.dayKey` und `BerlinCalendar.wallClock` gegengeprüft —
/// die Erwartungen hängen also nicht an der Funktion, die sie prüfen. Die
/// Kalender: Winter (14./15.01.2099), Sommer (14./15.07.2099) und die
/// beiden Umstellungsnächte wie in `tagesgrenze_test.dart`: Tag ist der
/// **Samstag vor dem letzten Sonntag** (28.03. bzw. 24.10.2099), Folgetag
/// der Umstellungssonntag (29.03.: 02:00 → 03:00; 25.10.: 03:00 → 02:00).
/// Dazu ein Monats- und ein Jahreswechsel.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die übersprungene Stunde wird zu UTC+2.** Der Plan sagt
///   „Sommerversatz“, `_alsZeitpunkt` rechnet so: 29.03.2099 02:30 →
///   00:30 UTC. Dieser Zeitpunkt liest sich auf der Wanduhr als 01:30 MEZ;
///   die Gegenprobe nimmt diesen Fall deshalb aus.
/// - **„Gewöhnlicher Tag“** umfasst auch 00:00 und 23:59 sowie einen Tag
///   im Sommer, dessen 01:30 in UTC auf dem Vortag liegt.
/// - **Die Grenzen gehören dem späteren Fenster**, wie bei
///   `Mahlzeitfenster`: 04:00 ist bei normal/„läuft noch“ schon der Tag
///   selbst, 08:00 bei „verlängert“ ebenso; 03:59 bzw. 07:59 noch der
///   Folgetag.
/// - **`nachtVorbei` vor 04:00 ist Frühstück, auch um 00:30.** Die Spec
///   sagt „Nacht vorbei und vor 04:00 → Frühstück“ ohne Untergrenze.
/// - **`zeitpunktImTag` und `mahlzeitImTag` gelten für jede Minute des
///   Tages** (`0 … 1439`). Was außerhalb liegt, prüft diese Datei nicht;
///   ebenso wenig einen ungültigen ISO-Tag — die Spec legt dafür nichts
///   fest.
/// - **Ein ausdrückliches `verfaelltUm: null`** gilt wie ein fehlender
///   Parameter. Die Spec gibt `DateTime? verfaelltUm` vor und sagt „Fehlt
///   er, gilt wie heute …“.
/// - **Gegenprobe mit `laufenderTag`:** Wer „jetzt“ auf den laufenden Tag
///   bucht, bekommt mit `zeitpunktImTag(tag, Wanduhr von jetzt, grund)`
///   genau `jetzt` zurück (#373: Di 01:30 auf Montag → **Di** 01:30).
///   Geprüft über das ganze Jahr 2099 ohne Belege (normal, „läuft noch“)
///   und an je einem Fall für „verlängert“ und „Nacht vorbei“. Ausgenommen
///   ist nur das **zweite** 02:xx am 25.10. — dieselbe Wanduhrzeit gibt es
///   dort zweimal, und `wanduhrZeitpunkt` nimmt die erste.
/// - Zeitpunkte werden mit UTC-`DateTime`-Werten verglichen; Dartsches `==`
///   beachtet `isUtc`, ein lokaler Wert desselben Zeitpunkts fiele durch.
///   Die Spec sagt „als UTC“.
void main() {
  group('wanduhrZeitpunkt', () {
    for (final f in _wanduhrFaelle) {
      test(f.name, () {
        expect(wanduhrZeitpunkt(f.tag, f.minuten), f.erwartet);
      });
    }

    test('liefert UTC', () {
      expect(wanduhrZeitpunkt('2099-01-14', _m(13, 15)).isUtc, isTrue);
      expect(wanduhrZeitpunkt('2099-07-15', _m(1, 30)).isUtc, isTrue);
    });
  });

  group('zeitpunktImTag (V14)', () {
    for (final f in _zeitpunktFaelle) {
      test(f.name, () {
        expect(
          zeitpunktImTag(tag: f.tag, minuten: f.minuten, grund: f.grund),
          f.erwartet,
        );
      });
    }

    test('ohne Grund rechnet „normal“: 01:30 → Folgetag, 20:30 → der Tag', () {
      // 15.01.2099 01:30 MEZ = 00:30 UTC; 14.01.2099 20:30 MEZ = 19:30 UTC.
      expect(
        zeitpunktImTag(tag: '2099-01-14', minuten: _m(1, 30)),
        DateTime.utc(2099, 1, 15, 0, 30),
      );
      expect(
        zeitpunktImTag(tag: '2099-01-14', minuten: _m(20, 30)),
        DateTime.utc(2099, 1, 14, 19, 30),
      );
    });

    test('liefert UTC', () {
      for (final grund in Tagesgrund.values) {
        expect(
          zeitpunktImTag(
            tag: '2099-07-14',
            minuten: _m(1, 30),
            grund: grund,
          ).isUtc,
          isTrue,
          reason: '$grund',
        );
      }
    });

    test('jede Minute des Tages: Folgetag oder der Tag, je nach Grund', () {
      // Die Regel aus V14 als Tabelle über alle 1440 Minuten, im Winter.
      // Erwartet wird die Wanduhrzeit selbst am erwarteten Kalendertag.
      for (final grund in Tagesgrund.values) {
        for (var minuten = 0; minuten < 24 * 60; minuten++) {
          final folgetag = switch (grund) {
            Tagesgrund.normal || Tagesgrund.laeuftNoch => minuten < 4 * 60,
            Tagesgrund.verlaengert => minuten < 8 * 60,
            Tagesgrund.nachtVorbei => false,
          };
          final t = zeitpunktImTag(
            tag: '2099-01-14',
            minuten: minuten,
            grund: grund,
          );
          final wo = '$grund, ${_uhr(minuten)}';
          expect(
            BerlinCalendar.dayKey(t),
            folgetag ? '2099-01-15' : '2099-01-14',
            reason: wo,
          );
          expect(BerlinCalendar.wallClock(t), (
            minuten ~/ 60,
            minuten % 60,
          ), reason: wo);
        }
      }
    });
  });

  group('zeitpunktImTag mit laufenderTag: jetzt bleibt jetzt (#373)', () {
    test('über das ganze Jahr 2099 im Viertelstundentakt, ohne Belege', () {
      // Zweites 02:xx am 25.10.2099 (01:00–01:59 UTC) ausgenommen, siehe
      // Dateikopf.
      final zweitesStart = DateTime.utc(2099, 10, 25, 1, 0);
      final zweitesEnde = DateTime.utc(2099, 10, 25, 2, 0);
      final ende = DateTime.utc(2099, 12, 31, 23, 0);
      for (
        var jetzt = DateTime.utc(2099, 1, 1, 0, 0);
        jetzt.isBefore(ende);
        jetzt = jetzt.add(const Duration(minutes: 15))
      ) {
        if (!jetzt.isBefore(zweitesStart) && jetzt.isBefore(zweitesEnde)) {
          continue;
        }
        final stand = laufenderTag(jetzt: jetzt);
        final (h, m) = BerlinCalendar.wallClock(jetzt);
        expect(
          zeitpunktImTag(
            tag: stand.tag,
            minuten: h * 60 + m,
            grund: stand.grund,
          ),
          jetzt,
          reason: '$jetzt (${stand.tag}, ${stand.grund})',
        );
      }
    });

    test('verlängert: Do 05:10 auf dem laufenden Mittwoch → Do 05:10', () {
      // Belege 03:30, 04:20, 05:00 MEZ am 15.01.2099 (Donnerstag); jetzt
      // 05:10 MEZ = 04:10 UTC. Die Kette beginnt vor 04:00 und lebt bis
      // 06:00 → verlängert, laufender Tag 14.01.
      final jetzt = DateTime.utc(2099, 1, 15, 4, 10);
      final stand = laufenderTag(
        jetzt: jetzt,
        belege: [
          Wachbeleg(
            von: DateTime.utc(2099, 1, 15, 2, 30),
            quelle: WachQuelle.eintrag,
          ),
          Wachbeleg(
            von: DateTime.utc(2099, 1, 15, 3, 20),
            quelle: WachQuelle.app,
          ),
          Wachbeleg(
            von: DateTime.utc(2099, 1, 15, 4, 0),
            quelle: WachQuelle.eintrag,
          ),
        ],
      );
      expect(stand.grund, Tagesgrund.verlaengert);
      expect(stand.tag, '2099-01-14');
      expect(
        zeitpunktImTag(tag: stand.tag, minuten: _m(5, 10), grund: stand.grund),
        jetzt,
      );
      expect(
        mahlzeitImTag(minuten: _m(5, 10), grund: stand.grund),
        Mahlzeit.abend,
      );
    });

    test('Nacht vorbei: Do 03:45 auf dem laufenden Donnerstag → Do 03:45', () {
      // Nacht 14.01. 22:00 MEZ bis 15.01. 03:15 MEZ, 5 h Schlaf; jetzt
      // 15.01. 03:45 MEZ = 02:45 UTC → Nacht vorbei, laufender Tag 15.01.
      final jetzt = DateTime.utc(2099, 1, 15, 2, 45);
      final stand = laufenderTag(
        jetzt: jetzt,
        naechte: [
          GemeldeteNacht(
            beginn: DateTime.utc(2099, 1, 14, 21, 0),
            ende: DateTime.utc(2099, 1, 15, 2, 15),
            schlaf: const Duration(hours: 5),
          ),
        ],
      );
      expect(stand.grund, Tagesgrund.nachtVorbei);
      expect(stand.tag, '2099-01-15');
      expect(
        zeitpunktImTag(tag: stand.tag, minuten: _m(3, 45), grund: stand.grund),
        jetzt,
      );
      expect(
        mahlzeitImTag(minuten: _m(3, 45), grund: stand.grund),
        Mahlzeit.fruehstueck,
      );
    });
  });

  group('mahlzeitImTag (Entscheidung 6)', () {
    const faelle = <(Tagesgrund, int, Mahlzeit)>[
      // Pflichtfälle aus dem Plan.
      (Tagesgrund.verlaengert, 5 * 60 + 10, Mahlzeit.abend),
      (Tagesgrund.verlaengert, 8 * 60, Mahlzeit.fruehstueck),
      (Tagesgrund.nachtVorbei, 3 * 60 + 45, Mahlzeit.fruehstueck),
      (Tagesgrund.nachtVorbei, 11 * 60, Mahlzeit.mittag),
      (Tagesgrund.normal, 1 * 60 + 30, Mahlzeit.abend),
      (Tagesgrund.normal, 5 * 60 + 10, Mahlzeit.fruehstueck),
      // Ränder und weitere Gründe.
      (Tagesgrund.verlaengert, 1 * 60 + 30, Mahlzeit.abend),
      (Tagesgrund.verlaengert, 4 * 60, Mahlzeit.abend),
      (Tagesgrund.verlaengert, 7 * 60 + 59, Mahlzeit.abend),
      (Tagesgrund.verlaengert, 12 * 60, Mahlzeit.mittag),
      (Tagesgrund.verlaengert, 20 * 60 + 30, Mahlzeit.abend),
      (Tagesgrund.nachtVorbei, 0 * 60 + 30, Mahlzeit.fruehstueck),
      (Tagesgrund.nachtVorbei, 3 * 60 + 59, Mahlzeit.fruehstueck),
      (Tagesgrund.nachtVorbei, 10 * 60 + 59, Mahlzeit.fruehstueck),
      (Tagesgrund.nachtVorbei, 20 * 60 + 30, Mahlzeit.abend),
      (Tagesgrund.laeuftNoch, 1 * 60 + 30, Mahlzeit.abend),
      (Tagesgrund.laeuftNoch, 3 * 60 + 59, Mahlzeit.abend),
      (Tagesgrund.laeuftNoch, 5 * 60 + 10, Mahlzeit.fruehstueck),
      (Tagesgrund.normal, 3 * 60 + 59, Mahlzeit.abend),
      (Tagesgrund.normal, 4 * 60, Mahlzeit.fruehstueck),
      (Tagesgrund.normal, 15 * 60 + 30, Mahlzeit.snack),
    ];
    for (final (grund, minuten, mahlzeit) in faelle) {
      test('${grund.name} ${_uhr(minuten)} → ${mahlzeit.name}', () {
        expect(mahlzeitImTag(minuten: minuten, grund: grund), mahlzeit);
      });
    }

    test('ohne Grund rechnet „normal“', () {
      expect(mahlzeitImTag(minuten: _m(1, 30)), Mahlzeit.abend);
      expect(mahlzeitImTag(minuten: _m(5, 10)), Mahlzeit.fruehstueck);
      expect(mahlzeitImTag(minuten: _m(12, 30)), Mahlzeit.mittag);
    });

    test('jede Minute des Tages: Sonderfall oder Mahlzeitfenster.fuer', () {
      for (final grund in Tagesgrund.values) {
        for (var minuten = 0; minuten < 24 * 60; minuten++) {
          final erwartet = switch (grund) {
            Tagesgrund.verlaengert when minuten < 8 * 60 => Mahlzeit.abend,
            Tagesgrund.nachtVorbei when minuten < 4 * 60 =>
              Mahlzeit.fruehstueck,
            _ => Mahlzeitfenster.fuer(minuten),
          };
          expect(
            mahlzeitImTag(minuten: minuten, grund: grund),
            erwartet,
            reason: '$grund, ${_uhr(minuten)}',
          );
        }
      }
    });
  });

  group('essenKarte(…, verfaelltUm:)', () {
    final staende = [
      for (final m in Mahlzeit.values)
        MahlzeitStand(
          mahlzeit: m,
          hatEintrag: m == Mahlzeit.fruehstueck,
          kcal: m == Mahlzeit.fruehstueck ? 420.0 : null,
        ),
    ];
    const serie = (heute: 3, abMorgen: 4);

    // 15.01.2099 05:10 MEZ = 04:10 UTC: verlängerter 14.01.
    final jetzt = DateTime.utc(2099, 1, 15, 4, 10);
    // 15.01.2099 06:00 MEZ = 05:00 UTC: Kette + 60 min (Entscheidung 9).
    final staleDate = DateTime.utc(2099, 1, 15, 5, 0);

    test('verfaelltUm: x → die Karte trägt x', () {
      final k = essenKarte(
        mahlzeiten: staende,
        serie: serie,
        jetzt: jetzt,
        verfaelltUm: staleDate,
      );
      expect(k.verfaelltUm, staleDate);
    });

    test('ohne Parameter wie bisher naechsterEsstagBeginn(jetzt)', () {
      // 15.01.2099 01:30 MEZ = 00:30 UTC → 15.01. 04:00 MEZ = 03:00 UTC.
      final nachts = DateTime.utc(2099, 1, 15, 0, 30);
      final k = essenKarte(mahlzeiten: staende, serie: serie, jetzt: nachts);
      expect(k.verfaelltUm, DateTime.utc(2099, 1, 15, 3, 0));
      expect(k.verfaelltUm, naechsterEsstagBeginn(nachts));
    });

    test('ohne Parameter nach 04:00: die 04:00 des Folgetags', () {
      // 15.01.2099 05:10 MEZ → 16.01. 04:00 MEZ = 03:00 UTC.
      final k = essenKarte(mahlzeiten: staende, serie: serie, jetzt: jetzt);
      expect(k.verfaelltUm, DateTime.utc(2099, 1, 16, 3, 0));
    });

    test('verfaelltUm: null gilt wie ein fehlender Parameter', () {
      final k = essenKarte(
        mahlzeiten: staende,
        serie: serie,
        jetzt: jetzt,
        verfaelltUm: null,
      );
      expect(k.verfaelltUm, naechsterEsstagBeginn(jetzt));
    });

    test('der Parameter ändert nur verfaelltUm', () {
      final mit = essenKarte(
        mahlzeiten: staende,
        serie: serie,
        jetzt: jetzt,
        verfaelltUm: staleDate,
      );
      final ohne = essenKarte(mahlzeiten: staende, serie: serie, jetzt: jetzt);
      expect(mit.ringe, ohne.ringe);
      expect(mit.ersteOffene, ohne.ersteOffene);
      expect(mit.serie, ohne.serie);
      expect(mit.serieAbMorgen, ohne.serieAbMorgen);
      expect(mit, isNot(ohne), reason: 'verfaelltUm geht in == ein');
    });

    test('gleiches verfaelltUm, anderes jetzt → gleiche Karte', () {
      // Sonst ginge jede Neuberechnung im verlängerten Tag als Update an
      // iOS (Fehler 03).
      final a = essenKarte(
        mahlzeiten: staende,
        serie: serie,
        jetzt: jetzt,
        verfaelltUm: staleDate,
      );
      final b = essenKarte(
        mahlzeiten: staende,
        serie: serie,
        jetzt: jetzt.add(const Duration(minutes: 20)),
        verfaelltUm: staleDate,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Gegenprobe der Erwartungen', () {
    // Prüft die UTC-Literale oben gegen BerlinCalendar, ohne die Funktionen
    // unter Test.
    for (final f in [..._wanduhrFaelle, ..._zeitpunktFaelle]) {
      if (f.ohneGegenprobe) continue;
      test(f.name, () {
        expect(f.erwartet.isUtc, isTrue);
        expect(BerlinCalendar.dayKey(f.erwartet), f.erwarteterTag);
        expect(BerlinCalendar.wallClock(f.erwartet), (
          f.minuten ~/ 60,
          f.minuten % 60,
        ));
      });
    }

    test('die Umstellungssonntage sind Sonntage', () {
      expect(
        BerlinCalendar.weekday(DateTime.utc(2099, 3, 29, 12)),
        DateTime.sunday,
      );
      expect(
        BerlinCalendar.weekday(DateTime.utc(2099, 10, 25, 12)),
        DateTime.sunday,
      );
    });

    test('29.03.2099 02:30 gibt es nicht, 00:30 UTC ist 01:30 MEZ', () {
      // Die Sommerzeit beginnt um 01:00 UTC: 00:59 UTC ist 01:59 MEZ,
      // 01:00 UTC ist 03:00 MESZ.
      expect(BerlinCalendar.wallClock(DateTime.utc(2099, 3, 29, 0, 59)), (
        1,
        59,
      ));
      expect(BerlinCalendar.wallClock(DateTime.utc(2099, 3, 29, 1, 0)), (3, 0));
      expect(BerlinCalendar.wallClock(DateTime.utc(2099, 3, 29, 0, 30)), (
        1,
        30,
      ));
    });

    test('25.10.2099 02:30 gibt es zweimal: 00:30 und 01:30 UTC', () {
      expect(BerlinCalendar.wallClock(DateTime.utc(2099, 10, 25, 0, 30)), (
        2,
        30,
      ));
      expect(BerlinCalendar.wallClock(DateTime.utc(2099, 10, 25, 1, 30)), (
        2,
        30,
      ));
    });
  });
}

/// Ein Fall mit Eingabe, erwartetem UTC-Zeitpunkt und dem Berliner
/// Kalendertag, auf dem er liegen muss.
class _Fall {
  const _Fall(
    this.name, {
    required this.tag,
    required this.minuten,
    this.grund = Tagesgrund.normal,
    required this.erwartet,
    required this.erwarteterTag,
    this.ohneGegenprobe = false,
  });

  final String name;
  final String tag;
  final int minuten;
  final Tagesgrund grund;
  final DateTime erwartet;
  final String erwarteterTag;

  /// Die übersprungene Stunde: Die Erwartung liest sich auf der Wanduhr
  /// anders als die Eingabe.
  final bool ohneGegenprobe;
}

final _wanduhrFaelle = <_Fall>[
  // Gewöhnliche Tage.
  _Fall(
    'Winter: 14.01. 13:15 MEZ → 12:15 UTC',
    tag: '2099-01-14',
    minuten: _m(13, 15),
    erwartet: DateTime.utc(2099, 1, 14, 12, 15),
    erwarteterTag: '2099-01-14',
  ),
  _Fall(
    'Winter: 14.01. 00:00 MEZ → 13.01. 23:00 UTC',
    tag: '2099-01-14',
    minuten: 0,
    erwartet: DateTime.utc(2099, 1, 13, 23, 0),
    erwarteterTag: '2099-01-14',
  ),
  _Fall(
    'Winter: 14.01. 23:59 MEZ → 22:59 UTC',
    tag: '2099-01-14',
    minuten: _m(23, 59),
    erwartet: DateTime.utc(2099, 1, 14, 22, 59),
    erwarteterTag: '2099-01-14',
  ),
  _Fall(
    'Sommer: 15.07. 01:30 MESZ → 14.07. 23:30 UTC',
    tag: '2099-07-15',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 7, 14, 23, 30),
    erwarteterTag: '2099-07-15',
  ),
  _Fall(
    'Sommer: 15.07. 20:30 MESZ → 18:30 UTC',
    tag: '2099-07-15',
    minuten: _m(20, 30),
    erwartet: DateTime.utc(2099, 7, 15, 18, 30),
    erwarteterTag: '2099-07-15',
  ),
  // Umstellung im März: 02:00 → 03:00 (01:00 UTC).
  _Fall(
    '29.03.: 01:30 ist noch MEZ → 00:30 UTC',
    tag: '2099-03-29',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 3, 29, 0, 30),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    '29.03.: übersprungenes 02:30 → Sommerversatz, 00:30 UTC',
    tag: '2099-03-29',
    minuten: _m(2, 30),
    erwartet: DateTime.utc(2099, 3, 29, 0, 30),
    erwarteterTag: '2099-03-29',
    ohneGegenprobe: true,
  ),
  _Fall(
    '29.03.: 03:00 ist schon MESZ → 01:00 UTC',
    tag: '2099-03-29',
    minuten: _m(3, 0),
    erwartet: DateTime.utc(2099, 3, 29, 1, 0),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    '29.03.: 04:00 MESZ → 02:00 UTC',
    tag: '2099-03-29',
    minuten: _m(4, 0),
    erwartet: DateTime.utc(2099, 3, 29, 2, 0),
    erwarteterTag: '2099-03-29',
  ),
  // Umstellung im Oktober: 03:00 → 02:00 (01:00 UTC).
  _Fall(
    '25.10.: 01:30 ist noch MESZ → 24.10. 23:30 UTC',
    tag: '2099-10-25',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 10, 24, 23, 30),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    '25.10.: doppeltes 02:30 → das erste, 00:30 UTC',
    tag: '2099-10-25',
    minuten: _m(2, 30),
    erwartet: DateTime.utc(2099, 10, 25, 0, 30),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    '25.10.: 04:00 ist MEZ → 03:00 UTC',
    tag: '2099-10-25',
    minuten: _m(4, 0),
    erwartet: DateTime.utc(2099, 10, 25, 3, 0),
    erwarteterTag: '2099-10-25',
  ),
];

final _zeitpunktFaelle = <_Fall>[
  // --- normal und „läuft noch“, Winter ---------------------------------
  for (final grund in const [Tagesgrund.normal, Tagesgrund.laeuftNoch]) ...[
    _Fall(
      'Winter, ${grund.name}: 01:30 → Folgetag 01:30',
      tag: '2099-01-14',
      minuten: _m(1, 30),
      grund: grund,
      erwartet: DateTime.utc(2099, 1, 15, 0, 30),
      erwarteterTag: '2099-01-15',
    ),
    _Fall(
      'Winter, ${grund.name}: 03:59 → Folgetag 03:59',
      tag: '2099-01-14',
      minuten: _m(3, 59),
      grund: grund,
      erwartet: DateTime.utc(2099, 1, 15, 2, 59),
      erwarteterTag: '2099-01-15',
    ),
    _Fall(
      'Winter, ${grund.name}: 04:00 → der Tag 04:00',
      tag: '2099-01-14',
      minuten: _m(4, 0),
      grund: grund,
      erwartet: DateTime.utc(2099, 1, 14, 3, 0),
      erwarteterTag: '2099-01-14',
    ),
    _Fall(
      'Winter, ${grund.name}: 20:30 → der Tag 20:30',
      tag: '2099-01-14',
      minuten: _m(20, 30),
      grund: grund,
      erwartet: DateTime.utc(2099, 1, 14, 19, 30),
      erwarteterTag: '2099-01-14',
    ),
  ],
  // --- verlängert, Winter ----------------------------------------------
  _Fall(
    'Winter, verlaengert: 05:10 → Folgetag 05:10',
    tag: '2099-01-14',
    minuten: _m(5, 10),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 1, 15, 4, 10),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, verlaengert: 01:30 → Folgetag 01:30',
    tag: '2099-01-14',
    minuten: _m(1, 30),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 1, 15, 0, 30),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, verlaengert: 07:59 → Folgetag 07:59',
    tag: '2099-01-14',
    minuten: _m(7, 59),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 1, 15, 6, 59),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, verlaengert: 08:00 → der Tag 08:00',
    tag: '2099-01-14',
    minuten: _m(8, 0),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 1, 14, 7, 0),
    erwarteterTag: '2099-01-14',
  ),
  _Fall(
    'Winter, verlaengert: 20:30 → der Tag 20:30',
    tag: '2099-01-14',
    minuten: _m(20, 30),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 1, 14, 19, 30),
    erwarteterTag: '2099-01-14',
  ),
  // --- Nacht vorbei, Winter (der Tag ist der Kalendertag K) ------------
  _Fall(
    'Winter, nachtVorbei: 03:45 → der Tag 03:45',
    tag: '2099-01-15',
    minuten: _m(3, 45),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 1, 15, 2, 45),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, nachtVorbei: 00:30 → der Tag 00:30',
    tag: '2099-01-15',
    minuten: _m(0, 30),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 1, 14, 23, 30),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, nachtVorbei: 05:10 → der Tag 05:10',
    tag: '2099-01-15',
    minuten: _m(5, 10),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 1, 15, 4, 10),
    erwarteterTag: '2099-01-15',
  ),
  _Fall(
    'Winter, nachtVorbei: 20:30 → der Tag 20:30',
    tag: '2099-01-15',
    minuten: _m(20, 30),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 1, 15, 19, 30),
    erwarteterTag: '2099-01-15',
  ),
  // --- Sommer ------------------------------------------------------------
  _Fall(
    'Sommer, normal: 01:30 → Folgetag 01:30 MESZ, in UTC noch der Tag',
    tag: '2099-07-14',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 7, 14, 23, 30),
    erwarteterTag: '2099-07-15',
  ),
  _Fall(
    'Sommer, laeuftNoch: 04:00 → der Tag 04:00',
    tag: '2099-07-14',
    minuten: _m(4, 0),
    grund: Tagesgrund.laeuftNoch,
    erwartet: DateTime.utc(2099, 7, 14, 2, 0),
    erwarteterTag: '2099-07-14',
  ),
  _Fall(
    'Sommer, normal: 20:30 → der Tag 20:30',
    tag: '2099-07-14',
    minuten: _m(20, 30),
    erwartet: DateTime.utc(2099, 7, 14, 18, 30),
    erwarteterTag: '2099-07-14',
  ),
  _Fall(
    'Sommer, verlaengert: 05:10 → Folgetag 05:10',
    tag: '2099-07-14',
    minuten: _m(5, 10),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 7, 15, 3, 10),
    erwarteterTag: '2099-07-15',
  ),
  _Fall(
    'Sommer, nachtVorbei: 03:45 → der Tag 03:45',
    tag: '2099-07-15',
    minuten: _m(3, 45),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 7, 15, 1, 45),
    erwarteterTag: '2099-07-15',
  ),
  // --- Umstellung im März: Tag 28.03. (Sa), Folgetag 29.03. (So) -------
  _Fall(
    'März, normal: 28.03. 01:30 → 29.03. 01:30 MEZ',
    tag: '2099-03-28',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 3, 29, 0, 30),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    'März, normal: 28.03. 02:30 → das übersprungene 02:30, Sommerversatz',
    tag: '2099-03-28',
    minuten: _m(2, 30),
    erwartet: DateTime.utc(2099, 3, 29, 0, 30),
    erwarteterTag: '2099-03-29',
    ohneGegenprobe: true,
  ),
  _Fall(
    'März, laeuftNoch: 28.03. 03:30 → 29.03. 03:30 MESZ',
    tag: '2099-03-28',
    minuten: _m(3, 30),
    grund: Tagesgrund.laeuftNoch,
    erwartet: DateTime.utc(2099, 3, 29, 1, 30),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    'März, normal: 28.03. 04:00 → der Tag, MEZ',
    tag: '2099-03-28',
    minuten: _m(4, 0),
    erwartet: DateTime.utc(2099, 3, 28, 3, 0),
    erwarteterTag: '2099-03-28',
  ),
  _Fall(
    'März, normal: 28.03. 20:30 → der Tag, MEZ',
    tag: '2099-03-28',
    minuten: _m(20, 30),
    erwartet: DateTime.utc(2099, 3, 28, 19, 30),
    erwarteterTag: '2099-03-28',
  ),
  _Fall(
    'März, verlaengert: 28.03. 05:10 → 29.03. 05:10 MESZ',
    tag: '2099-03-28',
    minuten: _m(5, 10),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 3, 29, 3, 10),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    'März, verlaengert: 28.03. 01:30 → 29.03. 01:30 MEZ',
    tag: '2099-03-28',
    minuten: _m(1, 30),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 3, 29, 0, 30),
    erwarteterTag: '2099-03-29',
  ),
  _Fall(
    'März, verlaengert: 28.03. 08:00 → der Tag, MEZ',
    tag: '2099-03-28',
    minuten: _m(8, 0),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 3, 28, 7, 0),
    erwarteterTag: '2099-03-28',
  ),
  _Fall(
    'März, nachtVorbei: 29.03. 03:45 → der Tag, MESZ',
    tag: '2099-03-29',
    minuten: _m(3, 45),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 3, 29, 1, 45),
    erwarteterTag: '2099-03-29',
  ),
  // --- Umstellung im Oktober: Tag 24.10. (Sa), Folgetag 25.10. (So) ----
  _Fall(
    'Oktober, normal: 24.10. 01:30 → 25.10. 01:30 MESZ',
    tag: '2099-10-24',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2099, 10, 24, 23, 30),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    'Oktober, laeuftNoch: 24.10. 02:30 → das erste 02:30 am 25.10.',
    tag: '2099-10-24',
    minuten: _m(2, 30),
    grund: Tagesgrund.laeuftNoch,
    erwartet: DateTime.utc(2099, 10, 25, 0, 30),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    'Oktober, normal: 24.10. 03:30 → 25.10. 03:30 MEZ',
    tag: '2099-10-24',
    minuten: _m(3, 30),
    erwartet: DateTime.utc(2099, 10, 25, 2, 30),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    'Oktober, normal: 24.10. 20:30 → der Tag, MESZ',
    tag: '2099-10-24',
    minuten: _m(20, 30),
    erwartet: DateTime.utc(2099, 10, 24, 18, 30),
    erwarteterTag: '2099-10-24',
  ),
  _Fall(
    'Oktober, verlaengert: 24.10. 05:10 → 25.10. 05:10 MEZ',
    tag: '2099-10-24',
    minuten: _m(5, 10),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 10, 25, 4, 10),
    erwarteterTag: '2099-10-25',
  ),
  _Fall(
    'Oktober, verlaengert: 24.10. 08:00 → der Tag, MESZ',
    tag: '2099-10-24',
    minuten: _m(8, 0),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 10, 24, 6, 0),
    erwarteterTag: '2099-10-24',
  ),
  _Fall(
    'Oktober, nachtVorbei: 25.10. 03:45 → der Tag, MEZ',
    tag: '2099-10-25',
    minuten: _m(3, 45),
    grund: Tagesgrund.nachtVorbei,
    erwartet: DateTime.utc(2099, 10, 25, 2, 45),
    erwarteterTag: '2099-10-25',
  ),
  // --- Monats- und Jahreswechsel ----------------------------------------
  _Fall(
    'Monatswechsel, verlaengert: 28.02. 05:10 → 01.03. 05:10',
    tag: '2099-02-28',
    minuten: _m(5, 10),
    grund: Tagesgrund.verlaengert,
    erwartet: DateTime.utc(2099, 3, 1, 4, 10),
    erwarteterTag: '2099-03-01',
  ),
  _Fall(
    'Jahreswechsel, normal: 31.12.2099 01:30 → 01.01.2100 01:30',
    tag: '2099-12-31',
    minuten: _m(1, 30),
    erwartet: DateTime.utc(2100, 1, 1, 0, 30),
    erwarteterTag: '2100-01-01',
  ),
];

int _m(int stunde, int minute) => stunde * 60 + minute;

String _uhr(int minuten) =>
    '${(minuten ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuten % 60).toString().padLeft(2, '0')}';
