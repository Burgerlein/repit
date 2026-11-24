import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/tagesgrenze.dart`, Teil 1 —
/// Task 2 des Umsetzungsplans
/// `docs/superpowers/plans/2026-11-10-tagesgrenze.md` (#452, #375), Spec
/// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitt
/// „Die Kern-Rechnungen“, Entscheidungen 1–4 und Vorgaben V1–V5.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## API, die diese Tests verbindlich vorgeben (aus der Spec)
///
/// ```dart
/// const int tagesObergrenzeInMinuten;    // 8 * 60
/// const Duration wachLuecke;             // 60 min
/// const Duration nachtMindestschlaf;     // 3 h
/// const int nachtAbInMinuten;            // 18 * 60
/// const int wachSchritteJeStunde;        // 100
///
/// enum WachQuelle { eintrag, app, schritte, training }
/// class Wachbeleg { const Wachbeleg({required DateTime von, DateTime? bis,
///     required WachQuelle quelle}); DateTime get bis; }
/// class GemeldeteNacht { const GemeldeteNacht({required DateTime beginn,
///     required DateTime ende, required Duration schlaf}); }
/// enum Tagesgrund { normal, laeuftNoch, verlaengert, nachtVorbei }
/// class Tagesstand { tag, grund, endetSpaetestens, zuletztWach }
/// enum Endegrund { eingeschlafen, mitternacht, festeGrenze, wachkette,
///     obergrenze }
/// class Tagesende { tag, endete, grund, eingeschlafen, zuletztWach }
///
/// Tagesstand laufenderTag({required DateTime jetzt,
///     Iterable<Wachbeleg> belege = const [],
///     Iterable<GemeldeteNacht> naechte = const []});
/// Tagesende tagesende({required String tag,
///     Iterable<Wachbeleg> belege = const [], GemeldeteNacht? nacht});
/// ```
///
/// ## Wie die Zeitpunkte entstehen
///
/// Jede Uhrzeit ist als **Berliner Wanduhr** an einem Kalendertag im Jahr
/// 2099 formuliert und wird über [berlin] in einen UTC-Zeitpunkt
/// umgerechnet. [berlin] prüft jedes Ergebnis mit
/// `BerlinCalendar.dayKey` und `BerlinCalendar.wallClock` gegen; die Gruppe
/// „Hilfsfunktion“ belegt es zusätzlich an festen UTC-Werten. Die
/// Grenzfälle laufen in vier Kalendern: Winter, Sommer und die beiden
/// Umstellungsnächte. Dort ist der Vortag (`D` bzw. `K−1`) der **Samstag
/// vor dem letzten Sonntag** — im Jahr 2099 der 28.03. und der 24.10. —
/// und der Kalendertag (`D+1` bzw. `K`) der Umstellungssonntag selbst
/// (29.03.: 02:00 → 03:00; 25.10.: 03:00 → 02:00).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Abstände sind echte Dauern, Grenzen sind Wanduhr.** „60 min nach dem
///   bisher spätesten Ende“ (V3) und „Ende + 60 min“ (V5) werden als
///   Zeitspanne auf dem UTC-Zeitpunkt gelesen. Nur K 00:00, K 04:00,
///   K 08:00, K−1 18:00 und M, G, O kommen von der Wanduhr, so steht es in
///   der Spec.
/// - **Vergleiche an den Grenzen**, wörtlich aus der Spec: „genau 60 zählt“
///   (≤ 60 min); „`jetzt` vor ihrem Ende + 60 min“ (streng); „mindestens
///   3 h“ (≥); „ab K−1 18:00 beginnt“ (≥); „spätestens `jetzt` endet“ (≤);
///   „Kette, die vor G beginnt und deren Ende + 60 min nach G liegt“ (beide
///   streng); „`nacht` beginnt vor G“ (streng); „`mitternacht`, wenn
///   `nacht.beginn` ≤ M“; „Beginn bis `endete`“ (≤).
/// - **`zuletztWach` im laufenden Tag** folgt dem Fließtext der Spec („der
///   Beleg mit dem spätesten Ende bis `jetzt`“), nicht dem Kurzkommentar am
///   Typ („jüngster Beleg“). Der Fall, in dem beides auseinanderfällt, ist
///   eigens geprüft.
/// - **Ein Training, das über `jetzt` hinaus läuft**, wird nur über
///   Quelle und Beginn geprüft. Ob `zuletztWach` den gekappten oder den
///   ursprünglichen Beleg trägt, lässt die Spec offen.
/// - **`zuletztWach` im vergangenen Tag** wird nur dort geprüft, wo der
///   Beleg mit dem spätesten Beginn auch das späteste Ende hat. Die Spec
///   sagt „jüngster Beleg mit Beginn bis `endete`“ und lässt offen, ob
///   „jüngster“ nach Beginn oder nach Ende misst.
/// - **Schritte sind Zeitpunkte** (V1: Beleg ist der Beginn der Stunde),
///   Trainings Spannen (V2).
/// - **Zwei Abweichungen von den Uhrzeiten im Plan**, weil es sie nicht an
///   jedem Umstellungstag gibt: Die Belege „nur 02:00 und 03:30“ stehen
///   hier auf 01:30 und 03:30 (02:00 fehlt am 29.03.); das Training
///   „02:30–04:30“ beginnt hier um 03:00 (02:30 fehlt am 29.03. und ist am
///   25.10. doppelt). Die Aussage des Falls bleibt dieselbe.
/// - **Schlafmengen** der Nächte sind so gewählt, dass sie auch in der
///   verkürzten Märznacht nicht länger sind als die Nacht selbst (5 h statt
///   der 6 h aus dem Plan). Die Regel braucht nur „mindestens 3 h“.
/// - Zeitpunkte werden mit UTC-`DateTime`-Werten verglichen; Dartsches `==`
///   beachtet `isUtc`, ein lokaler Wert desselben Zeitpunkts fiele durch.
///   Die Spec sagt „UTC“.
void main() {
  group('Hilfsfunktion berlin', () {
    test('Winter: 01:30 Berlin ist 00:30 UTC desselben Tages', () {
      expect(berlin('2099-01-14', 1, 30), DateTime.utc(2099, 1, 14, 0, 30));
    });

    test('Sommer: 01:30 Berlin ist 23:30 UTC des Vortags', () {
      // Der Fall, an dem schon einmal ein Test danebenlag: 23:30 UTC ist im
      // Sommer in Berlin bereits der Folgetag.
      expect(berlin('2099-07-15', 1, 30), DateTime.utc(2099, 7, 14, 23, 30));
    });

    test('29.03.2099: 01:30 ist noch Winterzeit, 04:00 schon Sommerzeit', () {
      expect(berlin('2099-03-29', 1, 30), DateTime.utc(2099, 3, 29, 0, 30));
      expect(berlin('2099-03-29', 4, 0), DateTime.utc(2099, 3, 29, 2, 0));
    });

    test('29.03.2099: 02:30 gibt es nicht', () {
      expect(() => berlin('2099-03-29', 2, 30), throwsArgumentError);
    });

    test('25.10.2099: das doppelte 02:30 ist das erste, 04:00 ist Winter', () {
      expect(berlin('2099-10-25', 2, 30), DateTime.utc(2099, 10, 25, 0, 30));
      expect(berlin('2099-10-25', 4, 0), DateTime.utc(2099, 10, 25, 3, 0));
    });

    test('die Umstellungssonntage sind Sonntage', () {
      expect(
        BerlinCalendar.weekday(berlin('2099-03-29', 12, 0)),
        DateTime.sunday,
      );
      expect(
        BerlinCalendar.weekday(berlin('2099-10-25', 12, 0)),
        DateTime.sunday,
      );
    });
  });

  group('Konstanten', () {
    test('Obergrenze 08:00 (Entscheidung 2)', () {
      expect(tagesObergrenzeInMinuten, 8 * 60);
    });

    test('Wachlücke 60 min (Entscheidung 3)', () {
      expect(wachLuecke, const Duration(minutes: 60));
    });

    test('Mindestschlaf 3 h, Nacht ab 18:00 (Entscheidung 4)', () {
      expect(nachtMindestschlaf, const Duration(hours: 3));
      expect(nachtAbInMinuten, 18 * 60);
    });

    test('Schritte zählen ab 100 in der Stunde (V1)', () {
      expect(wachSchritteJeStunde, 100);
    });

    test('der Tagesbeginn bleibt die Untergrenze des Frühstücks', () {
      expect(Mahlzeitfenster.tagesbeginnInMinuten, 4 * 60);
    });
  });

  group('Wachbeleg', () {
    test('ein Zeitpunkt hat bis == von', () {
      final t = berlin('2099-01-14', 3, 10);
      expect(Wachbeleg(von: t, quelle: WachQuelle.eintrag).bis, t);
    });

    test('eine Spanne behält ihr Ende', () {
      final von = berlin('2099-01-14', 3, 0);
      final bis = berlin('2099-01-14', 4, 30);
      expect(
        Wachbeleg(von: von, bis: bis, quelle: WachQuelle.training).bis,
        bis,
      );
    });
  });

  group('laufenderTag — Sonderfall ohne Belege und Nächte ist esstag', () {
    for (final k in kalender) {
      for (final (h, m) in const [
        (0, 0),
        (1, 30),
        (3, 59),
        (4, 0),
        (7, 59),
        (8, 0),
        (23, 59),
      ]) {
        test('${k.name}: ${uhr(h, m)}', () {
          final jetzt = berlin(k.tag, h, m);
          final stand = laufenderTag(jetzt: jetzt);
          expect(stand.tag, esstag(jetzt));
          expect(stand.endetSpaetestens, naechsterEsstagBeginn(jetzt));
          expect(stand.zuletztWach, isNull);
          if (h < 4) {
            expect(stand.tag, k.vortag);
            expect(stand.grund, Tagesgrund.laeuftNoch);
            expect(stand.endetSpaetestens, berlin(k.tag, 4, 0));
          } else {
            expect(stand.tag, k.tag);
            expect(stand.grund, Tagesgrund.normal);
            expect(stand.endetSpaetestens, berlin(k.folgetag, 4, 0));
          }
        });
      }
    }

    test('über das ganze Jahr 2099 im Viertelstundentakt', () {
      // Die Spec: „Für jeden Zeitpunkt t gilt
      // `laufenderTag(jetzt: t).tag == esstag(t)`“, und ohne Belege ist
      // `endetSpaetestens` `naechsterEsstagBeginn`.
      var t = DateTime.utc(2098, 12, 31, 23, 0);
      final ende = DateTime.utc(2099, 12, 31, 23, 0);
      while (t.isBefore(ende)) {
        final stand = laufenderTag(jetzt: t);
        if (stand.tag != esstag(t) ||
            stand.endetSpaetestens != naechsterEsstagBeginn(t)) {
          fail('Abweichung bei $t: $stand');
        }
        t = t.add(const Duration(minutes: 15));
      }
    });
  });

  group('laufenderTag — feste UTC-Werte an den Umstellungstagen', () {
    test('29.03.2099 01:30 CET → 28.03., endet 02:00 UTC (04:00 CEST)', () {
      final stand = laufenderTag(jetzt: DateTime.utc(2099, 3, 29, 0, 30));
      expect(stand.tag, '2099-03-28');
      expect(stand.grund, Tagesgrund.laeuftNoch);
      expect(stand.endetSpaetestens, DateTime.utc(2099, 3, 29, 2, 0));
    });

    test(
      '25.10.2099, das zweite 02:30 (01:30 UTC) → 24.10., endet 03:00 UTC',
      () {
        final stand = laufenderTag(jetzt: DateTime.utc(2099, 10, 25, 1, 30));
        expect(stand.tag, '2099-10-24');
        expect(stand.grund, Tagesgrund.laeuftNoch);
        expect(stand.endetSpaetestens, DateTime.utc(2099, 10, 25, 3, 0));
      },
    );

    test('25.10.2099 03:59 CET (02:59 UTC) läuft noch, 04:00 nicht mehr', () {
      expect(
        laufenderTag(jetzt: DateTime.utc(2099, 10, 25, 2, 59)).tag,
        '2099-10-24',
      );
      expect(
        laufenderTag(jetzt: DateTime.utc(2099, 10, 25, 3, 0)).tag,
        '2099-10-25',
      );
    });

    test('29.03.2099 verlängert: Obergrenze 08:00 CEST ist 06:00 UTC', () {
      final stand = laufenderTag(
        jetzt: DateTime.utc(2099, 3, 29, 5, 30), // 07:30 CEST
        belege: kette('2099-03-29', const [
          (3, 30),
          (4, 20),
          (5, 10),
          (6, 0),
          (6, 50),
          (7, 20),
        ]),
      );
      expect(stand.tag, '2099-03-28');
      expect(stand.grund, Tagesgrund.verlaengert);
      expect(stand.endetSpaetestens, DateTime.utc(2099, 3, 29, 6, 0));
    });
  });

  for (final k in kalender) {
    group('laufenderTag — ${k.name}', () {
      DateTime am(int h, int m) => berlin(k.tag, h, m);
      DateTime vorabend(int h, int m) => berlin(k.vortag, h, m);
      Wachbeleg beleg(int h, int m, WachQuelle q) =>
          Wachbeleg(von: am(h, m), quelle: q);
      GemeldeteNacht nacht(DateTime beginn, DateTime ende, Duration schlaf) =>
          GemeldeteNacht(beginn: beginn, ende: ende, schlaf: schlaf);

      final normalesEnde = berlin(k.folgetag, 4, 0);

      test('01:30, nichts → Vortag, läuft noch, endet 04:00', () {
        final stand = laufenderTag(jetzt: am(1, 30));
        expect(stand.tag, k.vortag);
        expect(stand.grund, Tagesgrund.laeuftNoch);
        expect(stand.endetSpaetestens, am(4, 0));
        expect(stand.zuletztWach, isNull);
      });

      test('01:30 mit Eintrag um 01:24 → läuft noch, zuletzt wach 01:24', () {
        final eintrag = beleg(1, 24, WachQuelle.eintrag);
        final stand = laufenderTag(jetzt: am(1, 30), belege: [eintrag]);
        expect(stand.tag, k.vortag);
        expect(stand.grund, Tagesgrund.laeuftNoch);
        expect(stand.endetSpaetestens, am(4, 0));
        expect(stand.zuletztWach, eintrag);
      });

      test('vor 04:00 verschiebt eine Kette das Ende nicht', () {
        // Tabelle: vor 04:00 entscheidet nur die Nacht.
        final stand = laufenderTag(
          jetzt: am(3, 50),
          belege: [
            beleg(3, 10, WachQuelle.eintrag),
            beleg(3, 45, WachQuelle.app),
          ],
        );
        expect(stand.tag, k.vortag);
        expect(stand.grund, Tagesgrund.laeuftNoch);
        expect(stand.endetSpaetestens, am(4, 0));
      });

      group('Nacht vorbei (Entscheidung 4, V4)', () {
        test('03:45, Nacht 21:00–03:30 mit 5 h → Kalendertag', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(21, 0), am(3, 30), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.nachtVorbei);
          expect(stand.endetSpaetestens, normalesEnde);
        });

        test('03:45, dieselbe Nacht mit 2 h 50 → Vortag', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(
                vorabend(21, 0),
                am(3, 30),
                const Duration(hours: 2, minutes: 50),
              ),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.laeuftNoch);
          expect(stand.endetSpaetestens, am(4, 0));
        });

        test('genau 3 h Schlaf genügen, 2 h 59 nicht', () {
          final mitDrei = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(21, 0), am(3, 30), const Duration(hours: 3)),
            ],
          );
          expect(mitDrei.tag, k.tag);
          expect(mitDrei.grund, Tagesgrund.nachtVorbei);

          final knapp = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(
                vorabend(21, 0),
                am(3, 30),
                const Duration(hours: 2, minutes: 59),
              ),
            ],
          );
          expect(knapp.tag, k.vortag);
          expect(knapp.grund, Tagesgrund.laeuftNoch);
        });

        test('03:45, Nacht ab 17:30 → Vortag (beginnt vor 18:00)', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(17, 30), am(3, 30), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.laeuftNoch);
        });

        test('03:45, Nacht ab genau 18:00 → Kalendertag', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(18, 0), am(3, 30), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.nachtVorbei);
        });

        test('01:00, Nickerchen 18:30–21:45 (3 h 15) → Vortag', () {
          // Endet vor Mitternacht: „frühestens Mitternacht“ (V4).
          final stand = laufenderTag(
            jetzt: am(1, 0),
            naechte: [
              nacht(
                vorabend(18, 30),
                vorabend(21, 45),
                const Duration(hours: 3, minutes: 15),
              ),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.laeuftNoch);
          expect(stand.endetSpaetestens, am(4, 0));
        });

        test('eine Nacht, die nach jetzt endet, ist nicht vorbei', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(21, 0), am(3, 46), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.laeuftNoch);
        });

        test('eine Nacht, die genau jetzt endet, ist vorbei', () {
          final stand = laufenderTag(
            jetzt: am(3, 45),
            naechte: [
              nacht(vorabend(21, 0), am(3, 45), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.nachtVorbei);
        });

        test('05:10, Kette und Nacht 22:00–04:50 mit 5 h → Kalendertag', () {
          final stand = laufenderTag(
            jetzt: am(5, 10),
            belege: [
              beleg(3, 10, WachQuelle.eintrag),
              beleg(4, 5, WachQuelle.app),
              beleg(5, 0, WachQuelle.schritte),
            ],
            naechte: [
              nacht(vorabend(22, 0), am(4, 50), const Duration(hours: 5)),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.normal);
          expect(stand.endetSpaetestens, normalesEnde);
        });
      });

      group('Wachkette (Entscheidung 3, V2, V3)', () {
        test(
          '05:10, 03:10 Eintrag, 04:05 App, 05:00 Schritte → verlängert',
          () {
            final schritte = beleg(5, 0, WachQuelle.schritte);
            final stand = laufenderTag(
              jetzt: am(5, 10),
              belege: [
                beleg(3, 10, WachQuelle.eintrag),
                beleg(4, 5, WachQuelle.app),
                schritte,
              ],
            );
            expect(stand.tag, k.vortag);
            expect(stand.grund, Tagesgrund.verlaengert);
            expect(stand.endetSpaetestens, am(6, 0));
            expect(stand.zuletztWach, schritte);
          },
        );

        test('dieselben Belege in umgekehrter Reihenfolge', () {
          // V3: Die Kette sortiert selbst nach Beginn.
          final schritte = beleg(5, 0, WachQuelle.schritte);
          final stand = laufenderTag(
            jetzt: am(5, 10),
            belege: [
              schritte,
              beleg(4, 5, WachQuelle.app),
              beleg(3, 10, WachQuelle.eintrag),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(6, 0));
          expect(stand.zuletztWach, schritte);
        });

        test('05:10, Belege nur 01:30 und 03:30 → Kalendertag, normal', () {
          final letzter = beleg(3, 30, WachQuelle.app);
          final stand = laufenderTag(
            jetzt: am(5, 10),
            belege: [beleg(1, 30, WachQuelle.eintrag), letzter],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.normal);
          expect(stand.endetSpaetestens, normalesEnde);
          expect(stand.zuletztWach, letzter);
        });

        test('Lücke genau 60 min zählt: 03:00 und 04:00, jetzt 04:30', () {
          final stand = laufenderTag(
            jetzt: am(4, 30),
            belege: [
              beleg(3, 0, WachQuelle.eintrag),
              beleg(4, 0, WachQuelle.app),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(5, 0));
        });

        test('Lücke 61 min reißt: 03:00 und 04:01, jetzt 04:30', () {
          final stand = laufenderTag(
            jetzt: am(4, 30),
            belege: [
              beleg(3, 0, WachQuelle.eintrag),
              beleg(4, 1, WachQuelle.app),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.normal);
          expect(stand.endetSpaetestens, normalesEnde);
        });

        test('jetzt genau Ende + 60 min ist nicht mehr verlängert', () {
          final belege = [
            beleg(3, 0, WachQuelle.eintrag),
            beleg(3, 30, WachQuelle.app),
          ];
          final knappDavor = laufenderTag(jetzt: am(4, 29), belege: belege);
          expect(knappDavor.tag, k.vortag);
          expect(knappDavor.grund, Tagesgrund.verlaengert);
          expect(knappDavor.endetSpaetestens, am(4, 30));

          final genau = laufenderTag(jetzt: am(4, 30), belege: belege);
          expect(genau.tag, k.tag);
          expect(genau.grund, Tagesgrund.normal);
          expect(genau.endetSpaetestens, normalesEnde);
        });

        test('eine Kette, die erst um 04:00 beginnt, verlängert nicht', () {
          final stand = laufenderTag(
            jetzt: am(4, 30),
            belege: [
              beleg(4, 0, WachQuelle.app),
              beleg(4, 20, WachQuelle.eintrag),
            ],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.normal);
        });

        test('07:30, Kette bis 07:20 → verlängert, endet 08:00', () {
          final stand = laufenderTag(
            jetzt: am(7, 30),
            belege: kette(k.tag, const [
              (3, 30),
              (4, 20),
              (5, 10),
              (6, 0),
              (6, 50),
              (7, 20),
            ]),
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(8, 0));
          expect(stand.zuletztWach?.von, am(7, 20));
        });

        test('07:59 mit lebender Kette ist noch verlängert, 08:00 nicht', () {
          final belege = kette(k.tag, const [
            (3, 30),
            (4, 20),
            (5, 10),
            (6, 0),
            (6, 50),
            (7, 20),
          ]);
          final davor = laufenderTag(jetzt: am(7, 59), belege: belege);
          expect(davor.tag, k.vortag);
          expect(davor.grund, Tagesgrund.verlaengert);
          expect(davor.endetSpaetestens, am(8, 0));

          final um8 = laufenderTag(jetzt: am(8, 0), belege: belege);
          expect(um8.tag, k.tag);
          expect(um8.grund, Tagesgrund.normal);
          expect(um8.endetSpaetestens, normalesEnde);
        });

        test('Training 03:00–04:30 als Spanne, jetzt 05:00 → endet 05:30', () {
          // V2: Die Kette misst ab dem Ende der Spanne, nicht ab ihrem
          // Beginn (03:00 + 60 min läge vor 05:00).
          final training = Wachbeleg(
            von: am(3, 0),
            bis: am(4, 30),
            quelle: WachQuelle.training,
          );
          final stand = laufenderTag(jetzt: am(5, 0), belege: [training]);
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(5, 30));
          expect(stand.zuletztWach, training);
        });

        test('ein Beleg innerhalb einer Spanne reißt die Kette nicht', () {
          // Lücke vom bisher spätesten Ende, nicht vom letzten Beleg.
          final stand = laufenderTag(
            jetzt: am(5, 0),
            belege: [
              Wachbeleg(
                von: am(3, 0),
                bis: am(4, 40),
                quelle: WachQuelle.training,
              ),
              beleg(3, 20, WachQuelle.app),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(5, 40));
        });

        test('Belege nach jetzt zählen nicht', () {
          final letzter = beleg(3, 50, WachQuelle.eintrag);
          final stand = laufenderTag(
            jetzt: am(4, 30),
            belege: [letzter, beleg(5, 0, WachQuelle.schritte)],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          expect(stand.endetSpaetestens, am(4, 50));
          expect(stand.zuletztWach, letzter);
        });

        test('ein Training, das nach jetzt endet, gilt als bis jetzt', () {
          final stand = laufenderTag(
            jetzt: am(4, 30),
            belege: [
              Wachbeleg(
                von: am(3, 30),
                bis: am(6, 0),
                quelle: WachQuelle.training,
              ),
            ],
          );
          expect(stand.tag, k.vortag);
          expect(stand.grund, Tagesgrund.verlaengert);
          // 04:30 + 60 min, nicht 06:00 + 60 min.
          expect(stand.endetSpaetestens, am(5, 30));
          expect(stand.zuletztWach?.quelle, WachQuelle.training);
          expect(stand.zuletztWach?.von, am(3, 30));
        });
      });

      group('zuletztWach', () {
        test('ist der Beleg mit dem spätesten Ende, nicht dem spätesten '
            'Beginn', () {
          final training = Wachbeleg(
            von: am(3, 0),
            bis: am(4, 30),
            quelle: WachQuelle.training,
          );
          final stand = laufenderTag(
            jetzt: am(5, 0),
            belege: [training, beleg(4, 0, WachQuelle.app)],
          );
          expect(stand.zuletztWach, training);
        });

        test('steht auch tagsüber', () {
          final app = beleg(11, 0, WachQuelle.app);
          final stand = laufenderTag(
            jetzt: am(12, 0),
            belege: [beleg(9, 0, WachQuelle.eintrag), app],
          );
          expect(stand.tag, k.tag);
          expect(stand.grund, Tagesgrund.normal);
          expect(stand.endetSpaetestens, normalesEnde);
          expect(stand.zuletztWach, app);
        });
      });
    });
  }

  for (final k in kalender) {
    group('tagesende — ${k.name} (D = ${k.vortag})', () {
      // Tag D ist der Vortag, D+1 der Kalendertag; M, G, O wie in der Spec.
      final d = k.vortag;
      DateTime morgen(int h, int m) => berlin(k.tag, h, m);
      DateTime abend(int h, int m) => berlin(d, h, m);
      Wachbeleg beleg(DateTime t, WachQuelle q) => Wachbeleg(von: t, quelle: q);
      GemeldeteNacht nachtAb(DateTime beginn, DateTime ende) => GemeldeteNacht(
        beginn: beginn,
        ende: ende,
        schlaf: const Duration(hours: 5),
      );

      final mitternacht = morgen(0, 0);
      final grenze = morgen(4, 0);
      final obergrenze = morgen(8, 0);

      final ketteBis5 = [
        beleg(morgen(3, 10), WachQuelle.eintrag),
        beleg(morgen(4, 5), WachQuelle.app),
        beleg(morgen(5, 0), WachQuelle.schritte),
      ];

      test('Nacht ab D+1 00:47 → endete 00:47, eingeschlafen', () {
        final ende = tagesende(
          tag: d,
          nacht: nachtAb(morgen(0, 47), morgen(7, 30)),
        );
        expect(ende.tag, d);
        expect(ende.endete, morgen(0, 47));
        expect(ende.grund, Endegrund.eingeschlafen);
        expect(ende.eingeschlafen, morgen(0, 47));
      });

      test('Nacht ab D 23:10 → endete Mitternacht', () {
        final ende = tagesende(
          tag: d,
          nacht: nachtAb(abend(23, 10), morgen(7, 0)),
        );
        expect(ende.endete, mitternacht);
        expect(ende.grund, Endegrund.mitternacht);
        expect(ende.eingeschlafen, abend(23, 10));
      });

      test('Nacht ab genau Mitternacht → mitternacht', () {
        final ende = tagesende(
          tag: d,
          nacht: nachtAb(mitternacht, morgen(7, 0)),
        );
        expect(ende.endete, mitternacht);
        expect(ende.grund, Endegrund.mitternacht);
        expect(ende.eingeschlafen, mitternacht);
      });

      test('Nacht ab 03:59 → eingeschlafen, auch mit lebender Kette', () {
        final ende = tagesende(
          tag: d,
          belege: ketteBis5,
          nacht: nachtAb(morgen(3, 59), morgen(10, 0)),
        );
        expect(ende.endete, morgen(3, 59));
        expect(ende.grund, Endegrund.eingeschlafen);
      });

      test('keine Nacht, keine Belege → D+1 04:00, feste Grenze', () {
        final ende = tagesende(tag: d);
        expect(ende.tag, d);
        expect(ende.endete, grenze);
        expect(ende.grund, Endegrund.festeGrenze);
        expect(ende.eingeschlafen, isNull);
        expect(ende.zuletztWach, isNull);
      });

      test('keine Nacht, Kette 03:10, 04:05, 05:00 → 06:00, Wachkette', () {
        final ende = tagesende(tag: d, belege: ketteBis5);
        expect(ende.endete, morgen(6, 0));
        expect(ende.grund, Endegrund.wachkette);
        expect(ende.eingeschlafen, isNull);
        expect(ende.zuletztWach, ketteBis5.last);
      });

      test('keine Nacht, Kette bis 07:30 → 08:00, Obergrenze', () {
        final belege = kette(k.tag, const [
          (3, 30),
          (4, 20),
          (5, 10),
          (6, 0),
          (6, 50),
          (7, 30),
        ]);
        final ende = tagesende(tag: d, belege: belege);
        expect(ende.endete, obergrenze);
        expect(ende.grund, Endegrund.obergrenze);
        expect(ende.zuletztWach?.von, morgen(7, 30));
      });

      test('Gleichstand Wachkette und Obergrenze → Wachkette', () {
        // Kette bis 07:00: Ende + 60 min ist genau 08:00.
        final belege = kette(k.tag, const [
          (3, 30),
          (4, 20),
          (5, 10),
          (6, 0),
          (7, 0),
        ]);
        final ende = tagesende(tag: d, belege: belege);
        expect(ende.endete, obergrenze);
        expect(ende.grund, Endegrund.wachkette);
      });

      test('Nacht ab 05:30, Kette bis 05:00 → 05:30, eingeschlafen', () {
        final ende = tagesende(
          tag: d,
          belege: ketteBis5,
          nacht: nachtAb(morgen(5, 30), morgen(11, 0)),
        );
        expect(ende.endete, morgen(5, 30));
        expect(ende.grund, Endegrund.eingeschlafen);
        expect(ende.eingeschlafen, morgen(5, 30));
        expect(ende.zuletztWach, ketteBis5.last);
      });

      test('Nacht ab 06:00, Kette bis 05:00 → 06:00, eingeschlafen '
          '(Gleichstand)', () {
        final ende = tagesende(
          tag: d,
          belege: ketteBis5,
          nacht: nachtAb(morgen(6, 0), morgen(11, 0)),
        );
        expect(ende.endete, morgen(6, 0));
        expect(ende.grund, Endegrund.eingeschlafen);
        expect(ende.eingeschlafen, morgen(6, 0));
      });

      test('Nacht ab 08:00, Kette bis 07:30 → 08:00, eingeschlafen '
          '(Gleichstand mit der Obergrenze)', () {
        final belege = kette(k.tag, const [
          (3, 30),
          (4, 20),
          (5, 10),
          (6, 0),
          (6, 50),
          (7, 30),
        ]);
        final ende = tagesende(
          tag: d,
          belege: belege,
          nacht: nachtAb(morgen(8, 0), morgen(13, 0)),
        );
        expect(ende.endete, obergrenze);
        expect(ende.grund, Endegrund.eingeschlafen);
      });

      test('Nacht ab 06:30, Kette bis 05:00 → 06:00, Wachkette', () {
        final ende = tagesende(
          tag: d,
          belege: ketteBis5,
          nacht: nachtAb(morgen(6, 30), morgen(12, 0)),
        );
        expect(ende.endete, morgen(6, 0));
        expect(ende.grund, Endegrund.wachkette);
        expect(ende.eingeschlafen, morgen(6, 30));
      });

      test('Nacht ab 09:00, keine Kette → 04:00, feste Grenze; '
          'eingeschlafen ist trotzdem 09:00', () {
        final ende = tagesende(
          tag: d,
          nacht: nachtAb(morgen(9, 0), morgen(15, 0)),
        );
        expect(ende.endete, grenze);
        expect(ende.grund, Endegrund.festeGrenze);
        expect(ende.eingeschlafen, morgen(9, 0));
      });

      test('Nacht ab genau 04:00, keine Kette → feste Grenze', () {
        // „beginnt vor G“ ist streng: 04:00 fällt in Schritt 2 und 3.
        final ende = tagesende(tag: d, nacht: nachtAb(grenze, morgen(10, 0)));
        expect(ende.endete, grenze);
        expect(ende.grund, Endegrund.festeGrenze);
        expect(ende.eingeschlafen, grenze);
      });

      test(
        'Kette endet um 03:00: Ende + 60 min ist genau G → feste Grenze',
        () {
          final ende = tagesende(
            tag: d,
            belege: [beleg(morgen(3, 0), WachQuelle.app)],
          );
          expect(ende.endete, grenze);
          expect(ende.grund, Endegrund.festeGrenze);
        },
      );

      test('Kette endet um 03:01 → 04:01, Wachkette', () {
        final ende = tagesende(
          tag: d,
          belege: [beleg(morgen(3, 1), WachQuelle.app)],
        );
        expect(ende.endete, morgen(4, 1));
        expect(ende.grund, Endegrund.wachkette);
      });

      test('eine Kette, die erst nach G beginnt, zählt nicht', () {
        final ende = tagesende(
          tag: d,
          belege: [
            beleg(morgen(4, 30), WachQuelle.schritte),
            beleg(morgen(5, 0), WachQuelle.app),
          ],
        );
        expect(ende.endete, grenze);
        expect(ende.grund, Endegrund.festeGrenze);
      });

      test('Training 03:00–04:30 als Spanne → 05:30, Wachkette', () {
        final ende = tagesende(
          tag: d,
          belege: [
            Wachbeleg(
              von: morgen(3, 0),
              bis: morgen(4, 30),
              quelle: WachQuelle.training,
            ),
          ],
        );
        expect(ende.endete, morgen(5, 30));
        expect(ende.grund, Endegrund.wachkette);
      });

      test('Lücke von 61 min reißt die Kette auch hier', () {
        // 03:00 + 60 min ist genau G; der zweite Beleg beginnt nicht vor G.
        // Zählte die Lücke, endete der Tag um 05:01.
        final ende = tagesende(
          tag: d,
          belege: [
            beleg(morgen(3, 0), WachQuelle.eintrag),
            beleg(morgen(4, 1), WachQuelle.app),
          ],
        );
        expect(ende.endete, grenze);
        expect(ende.grund, Endegrund.festeGrenze);
      });

      group('zuletztWach', () {
        test('ist der jüngste Beleg mit Beginn bis endete', () {
          final schritte = beleg(morgen(0, 31), WachQuelle.schritte);
          final ende = tagesende(
            tag: d,
            belege: [
              beleg(abend(23, 10), WachQuelle.eintrag),
              schritte,
              beleg(morgen(1, 30), WachQuelle.app),
            ],
            nacht: nachtAb(morgen(0, 47), morgen(7, 30)),
          );
          expect(ende.endete, morgen(0, 47));
          expect(ende.zuletztWach, schritte);
        });

        test('ein Beleg genau bei endete zählt noch', () {
          final genau = beleg(morgen(0, 47), WachQuelle.app);
          final ende = tagesende(
            tag: d,
            belege: [beleg(morgen(0, 31), WachQuelle.schritte), genau],
            nacht: nachtAb(morgen(0, 47), morgen(7, 30)),
          );
          expect(ende.zuletztWach, genau);
        });

        test('ohne Schlafdaten: der letzte Eintrag am Abend', () {
          // Entwurf „ohne Schlafdaten“: Endete Di 04:00, zuletzt wach
          // Mo 23:10 · Eintrag.
          final eintrag = beleg(abend(23, 10), WachQuelle.eintrag);
          final ende = tagesende(
            tag: d,
            belege: [beleg(abend(10, 0), WachQuelle.app), eintrag],
          );
          expect(ende.endete, grenze);
          expect(ende.grund, Endegrund.festeGrenze);
          expect(ende.zuletztWach, eintrag);
        });

        test('bei Mitternacht zählt ein Beleg danach nicht', () {
          final abendEintrag = beleg(abend(23, 30), WachQuelle.eintrag);
          final ende = tagesende(
            tag: d,
            belege: [abendEintrag, beleg(morgen(0, 20), WachQuelle.app)],
            nacht: nachtAb(abend(23, 50), morgen(7, 0)),
          );
          expect(ende.endete, mitternacht);
          expect(ende.zuletztWach, abendEintrag);
        });
      });
    });
  }

  group('tagesende — feste UTC-Werte an den Umstellungstagen', () {
    test('D = 28.03.2099: G ist 02:00 UTC, M 23:00 UTC, O 06:00 UTC', () {
      expect(
        tagesende(tag: '2099-03-28').endete,
        DateTime.utc(2099, 3, 29, 2, 0),
      );
      expect(
        tagesende(
          tag: '2099-03-28',
          nacht: GemeldeteNacht(
            beginn: DateTime.utc(2099, 3, 28, 22, 0), // 23:00 CET
            ende: DateTime.utc(2099, 3, 29, 5, 0),
            schlaf: const Duration(hours: 5),
          ),
        ).endete,
        DateTime.utc(2099, 3, 28, 23, 0),
      );
      expect(
        tagesende(
          tag: '2099-03-28',
          belege: kette('2099-03-29', const [
            (3, 30),
            (4, 20),
            (5, 10),
            (6, 0),
            (6, 50),
            (7, 30),
          ]),
        ).endete,
        DateTime.utc(2099, 3, 29, 6, 0),
      );
    });

    test('D = 24.10.2099: G ist 03:00 UTC, M 22:00 UTC, O 07:00 UTC', () {
      expect(
        tagesende(tag: '2099-10-24').endete,
        DateTime.utc(2099, 10, 25, 3, 0),
      );
      expect(
        tagesende(
          tag: '2099-10-24',
          nacht: GemeldeteNacht(
            beginn: DateTime.utc(2099, 10, 24, 21, 0), // 23:00 CEST
            ende: DateTime.utc(2099, 10, 25, 6, 0),
            schlaf: const Duration(hours: 5),
          ),
        ).endete,
        DateTime.utc(2099, 10, 24, 22, 0),
      );
      expect(
        tagesende(
          tag: '2099-10-24',
          belege: kette('2099-10-25', const [
            (3, 30),
            (4, 20),
            (5, 10),
            (6, 0),
            (6, 50),
            (7, 30),
          ]),
        ).endete,
        DateTime.utc(2099, 10, 25, 7, 0),
      );
    });
  });

  group('Gleichheit', () {
    final t1 = berlin('2099-01-14', 3, 10);
    final t2 = berlin('2099-01-14', 4, 30);

    test('Wachbeleg', () {
      final a = Wachbeleg(von: t1, bis: t2, quelle: WachQuelle.training);
      final b = Wachbeleg(von: t1, bis: t2, quelle: WachQuelle.training);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(Wachbeleg(von: t1, bis: t2, quelle: WachQuelle.app)));
      expect(a, isNot(Wachbeleg(von: t1, quelle: WachQuelle.training)));
      expect(
        a,
        isNot(Wachbeleg(von: t2, bis: t2, quelle: WachQuelle.training)),
      );
      expect(
        Wachbeleg(von: t1, quelle: WachQuelle.eintrag),
        Wachbeleg(von: t1, quelle: WachQuelle.eintrag),
      );
    });

    test('GemeldeteNacht', () {
      GemeldeteNacht n(Duration schlaf) =>
          GemeldeteNacht(beginn: t1, ende: t2, schlaf: schlaf);
      expect(n(const Duration(hours: 1)), n(const Duration(hours: 1)));
      expect(
        n(const Duration(hours: 1)).hashCode,
        n(const Duration(hours: 1)).hashCode,
      );
      expect(n(const Duration(hours: 1)), isNot(n(const Duration(hours: 2))));
      expect(
        GemeldeteNacht(beginn: t1, ende: t2, schlaf: Duration.zero),
        isNot(GemeldeteNacht(beginn: t2, ende: t2, schlaf: Duration.zero)),
      );
      expect(
        GemeldeteNacht(beginn: t1, ende: t2, schlaf: Duration.zero),
        isNot(GemeldeteNacht(beginn: t1, ende: t1, schlaf: Duration.zero)),
      );
    });

    test('Tagesstand', () {
      // Zweimal aus eigens gebauten Eingaben gerechnet: gleiche Werte,
      // verschiedene Objekte. 05:00 mit Kette bis 04:05 ist verlängert.
      Tagesstand rechne() => laufenderTag(
        jetzt: berlin('2099-01-14', 5, 0),
        belege: [
          Wachbeleg(von: t1, quelle: WachQuelle.eintrag),
          Wachbeleg(von: berlin('2099-01-14', 4, 5), quelle: WachQuelle.app),
        ],
      );
      final a = rechne();
      final b = rechne();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(laufenderTag(jetzt: berlin('2099-01-14', 5, 0))));
      expect(
        laufenderTag(jetzt: berlin('2099-01-14', 1, 0)),
        isNot(laufenderTag(jetzt: berlin('2099-01-14', 12, 0))),
      );
    });

    test('Tagesstand unterscheidet sich auch nur in zuletztWach', () {
      // Tag, Grund und Ende gleich; nur der Beleg fehlt.
      final mit = laufenderTag(
        jetzt: berlin('2099-01-14', 12, 0),
        belege: [
          Wachbeleg(von: berlin('2099-01-14', 11, 0), quelle: WachQuelle.app),
        ],
      );
      final ohne = laufenderTag(jetzt: berlin('2099-01-14', 12, 0));
      expect(mit.tag, ohne.tag);
      expect(mit.grund, ohne.grund);
      expect(mit.endetSpaetestens, ohne.endetSpaetestens);
      expect(mit, isNot(ohne));
    });

    test('Tagesende', () {
      Tagesende rechne() => tagesende(
        tag: '2099-01-13',
        belege: [Wachbeleg(von: t1, quelle: WachQuelle.eintrag)],
        nacht: GemeldeteNacht(
          beginn: berlin('2099-01-14', 0, 47),
          ende: berlin('2099-01-14', 7, 30),
          schlaf: const Duration(hours: 6),
        ),
      );
      final a = rechne();
      final b = rechne();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(tagesende(tag: '2099-01-13')));
      expect(tagesende(tag: '2099-01-13'), tagesende(tag: '2099-01-13'));
      expect(tagesende(tag: '2099-01-13'), isNot(tagesende(tag: '2099-01-12')));
    });

    test('Tagesende unterscheidet sich auch nur in eingeschlafen oder '
        'zuletztWach', () {
      // Alle drei enden um 04:00 an der festen Grenze.
      final nackt = tagesende(tag: '2099-01-13');
      final mitSpaeterNacht = tagesende(
        tag: '2099-01-13',
        nacht: GemeldeteNacht(
          beginn: berlin('2099-01-14', 9, 0),
          ende: berlin('2099-01-14', 15, 0),
          schlaf: const Duration(hours: 5),
        ),
      );
      final mitBeleg = tagesende(
        tag: '2099-01-13',
        belege: [
          Wachbeleg(von: berlin('2099-01-13', 10, 0), quelle: WachQuelle.app),
        ],
      );
      for (final x in [mitSpaeterNacht, mitBeleg]) {
        expect(x.endete, nackt.endete);
        expect(x.grund, nackt.grund);
        expect(x, isNot(nackt));
      }
      expect(mitSpaeterNacht, isNot(mitBeleg));
    });
  });
}

/// Ein Kalender für die Grenzfälle: [tag] ist K (bzw. D+1), [vortag] ist
/// K−1 (bzw. D), [folgetag] ist K+1.
typedef Kalender = ({String name, String vortag, String tag, String folgetag});

const List<Kalender> kalender = [
  (
    name: 'Winter',
    vortag: '2099-01-13',
    tag: '2099-01-14',
    folgetag: '2099-01-15',
  ),
  (
    name: 'Sommer',
    vortag: '2099-07-14',
    tag: '2099-07-15',
    folgetag: '2099-07-16',
  ),
  (
    name: 'Umstellung März',
    vortag: '2099-03-28',
    tag: '2099-03-29',
    folgetag: '2099-03-30',
  ),
  (
    name: 'Umstellung Oktober',
    vortag: '2099-10-24',
    tag: '2099-10-25',
    folgetag: '2099-10-26',
  ),
];

/// Die Berliner Wanduhrzeit [stunde]:[minute] am Kalendertag [tag]
/// (`JJJJ-MM-TT`), als UTC-Zeitpunkt.
///
/// Probiert erst den Sommer-, dann den Winterversatz und nimmt den ersten,
/// den `BerlinCalendar` bestätigt: In der doppelten Stunde im Oktober ist
/// das die erste. Eine Uhrzeit, die es nicht gibt (die übersprungene Stunde
/// im März), wirft.
DateTime berlin(String tag, int stunde, int minute) {
  final teile = tag.split('-').map(int.parse).toList();
  final naiv = DateTime.utc(teile[0], teile[1], teile[2], stunde, minute);
  for (final versatz in const [2, 1]) {
    final kandidat = naiv.subtract(Duration(hours: versatz));
    if (BerlinCalendar.dayKey(kandidat) == tag &&
        BerlinCalendar.wallClock(kandidat) == (stunde, minute)) {
      return kandidat;
    }
  }
  throw ArgumentError('$tag ${uhr(stunde, minute)} gibt es in Berlin nicht');
}

/// Eine Kette aus Belegen (abwechselnd Eintrag und App) zu den Uhrzeiten
/// [uhrzeiten] am Kalendertag [tag].
List<Wachbeleg> kette(String tag, List<(int, int)> uhrzeiten) => [
  for (final (i, (h, m)) in uhrzeiten.indexed)
    Wachbeleg(
      von: berlin(tag, h, m),
      quelle: i.isEven ? WachQuelle.eintrag : WachQuelle.app,
    ),
];

String uhr(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
