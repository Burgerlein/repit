import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`GymWorkoutMatch`** — welches Apple-Training zu einer
/// Gym-Sitzung gehört. Ticket #414 (Vorbedingung für #512), Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymWorkoutMatch.swift`
/// und `GymWorkoutMatchTests.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Was hier festgelegt wird
///
/// ```dart
/// abstract final class GymWorkoutMatch {
///   /// Der **Index** des Krafttrainings des Berliner Tages [day] in
///   /// [workouts], oder `null`.
///   static int? matchIndex({
///     required DateTime day,
///     required List<({DateTime start, bool isStrength, double minutes})>
///         workouts,
///   });
/// }
/// ```
///
/// ### Weg 1 aus #414: Record als Eingabe
///
/// `WorkoutSample` ist ein HealthKit-Transporttyp und gehört laut
/// `CLAUDE.md` nicht in den Kern. Die Rechnung braucht von ihm aber nur drei
/// Dinge, und genau die nimmt der Kern als Record:
///
/// - `start` — der Beginn; mit ihm wird der Berliner Tag bestimmt und bei
///   Gleichstand das frühere gewählt.
/// - `isStrength` — **ein `bool`, nicht `WorkoutKind`.** Der Kern kennt die
///   Trainingsarten der App nicht und soll sie nicht kennen; ob eine davon
///   „Krafttraining" ist, entscheidet die App an der einen Stelle, an der
///   sie übersetzt (`isStrength: s.kind == WorkoutKind.strength`).
/// - `minutes` — die Dauer, `double` wie in `WorkoutSample`. Ein Training
///   von 45,4 Minuten ist länger als eines von 45,0; wer auf `int` kürzt,
///   macht daraus einen Gleichstand (eigener Test).
///
/// Der Record ist **strukturell** gleich (`==`/`hashCode` bringt Dart für
/// Records mit) — ein Provider, der die übersetzte Liste hält, rechnet nicht
/// bei jedem Neubau neu (`03`). Die Tests schreiben den Record als Literal
/// und legen deshalb **keinen Typnamen** fest; ob die Implementierung ein
/// `typedef` dafür anbietet, ist ihre Sache.
///
/// ### Rückgabe: der Index, weder der Eintrag noch ein dritter Typ
///
/// Der Kern bekommt nur drei Felder, die App will aber das ganze
/// `WorkoutSample` zurück — für `id` (der Pulsverlauf in #512 fragt zu genau
/// diesem Training), `avgHR` und `maxHR`. Gäbe die Funktion den
/// **Record-Eintrag** zurück, fehlte die Id, und die App müsste das Sample
/// über `start` und `minutes` ein zweites Mal suchen — und fände bei zwei
/// Trainings mit gleichen Werten womöglich das falsche. Der **Index** löst
/// beides: `samples[index]` ist das Sample, ohne Suche und ohne Zweideutigkeit.
/// Die App übersetzt mit `samples.map(...).toList()` und behält damit die
/// Reihenfolge — die eine Pflicht, die der Aufrufer hat. Ein eigener dritter
/// Typ (Treffer mit Index und Eintrag) trüge nichts, was `index` nicht schon
/// sagt, und brächte ein `==`/`hashCode` mit, das niemand braucht: `int?` ist
/// als Wert schon alles, was ein Provider vergleichen muss.
///
/// **Der Name sagt es:** `matchIndex`, nicht `match` — `match` ließe einen
/// Eintrag erwarten, wie die Swift-Fassung ihn liefert.
///
/// ## Was die Rechnung leistet — und warum
///
/// Aus `GymWorkoutMatch.swift`, die Begründungen stehen dort:
///
/// - **Nur Krafttraining kommt in Frage**, auch nicht als einziges Training
///   des Tages: Der Puls eines Laufs unter einer Gym-Sitzung wäre schlicht
///   falsch.
/// - **Bei mehreren Krafttrainings gewinnt das längere.**
/// - **Bei gleicher Dauer das frühere**, damit die Antwort nicht von der
///   Reihenfolge abhängt, in der HealthKit die Stichproben liefert.
/// - **Der Tagesvergleich läuft über den Berliner Tag**, nicht über die
///   Felder eines `DateTime`.
/// - **Kein passendes Training ist der Normalfall**, nicht die Ausnahme: Die
///   Uhr lief nicht immer mit, und bei den übernommenen alten Trainings fast
///   nie. Das Ergebnis ist `null` — kein leerer Eintrag, kein Index `-1`.
///
/// ## Zusätzlich gegenüber Swift festgelegt
///
/// - **Völliger Gleichstand** (gleicher Beginn, gleiche Dauer): der Eintrag
///   mit dem **kleineren Index**. Swifts `min(by:)` liefert dort den ersten,
///   die Swift-Tests prüfen es nicht. Mit Index als Rückgabe sind die beiden
///   unterscheidbar, also muss die Antwort feststehen.
/// - **Die Eingabeliste wird nicht verändert** und darf unveränderlich sein
///   (`List.unmodifiable`). Wer sie in place sortiert, verschiebt die
///   Indizes, auf die sich die App verlässt.
///
/// ## Wie die Zeitpunkte gebaut sind
///
/// **Alle als UTC-Literal, daneben die Berliner Uhrzeit im Kommentar** — nicht
/// über eine Hilfsfunktion, die selbst einen Versatz rechnete und damit die
/// Sommerzeitregel ein zweites Mal im Test nachbaute. Die Zeitpunkte sind
/// nachgerechnet, nicht angenommen, und die Gruppe „Die Zeitpunkte
/// stimmen" am Ende prüft sie gegen `BerlinCalendar.dayKey`: Stimmt ein
/// Literal nicht, scheitert diese Gruppe und nicht ein Fall mit
/// irreführendem Namen.
///
/// Berlin ist im Oktober 2026 bis zum 25.10. 01:00 UTC UTC+2, danach UTC+1;
/// im März 2027 ab dem 28.03. 01:00 UTC UTC+2; im Januar 2027 UTC+1.
/// Das ist der Grund, warum 23:30 UTC im Oktober **schon der Folgetag** ist
/// — derselbe Zahlendreher, den die `DataWindow`-Tests einmal hatten.
///
/// Alle Zahlen sind erfunden. Echte Gesundheitsdaten gehören nicht ins
/// Repository, und kein Datum steht hier für ein Ereignis.
void main() {
  group('Der einfache Fall', () {
    test('ein Krafttraining am selben Tag wird gefunden', () {
      final liste = [
        // 12.10. 18:30 Berlin.
        _kraft(_utc(2026, 10, 12, 16, 30), 58),
      ];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), 0);
    });

    test('ohne Trainings gibt es nichts zu finden, und das ist null', () {
      expect(_treffer(_utc(2026, 10, 12, 10), const []), isNull);
    });

    test('der Index bezieht sich auf die Eingabeliste, nicht auf die '
        'gefilterte', () {
      // Der Fall, an dem eine Implementierung, die erst filtert und dann den
      // Index der gefilterten Liste zurückgibt, scheitert: Das Krafttraining
      // steht an Stelle 3, davor stehen Lauf, Vortag und Spaziergang.
      final liste = [
        _anderes(_utc(2026, 10, 12, 5, 15), 52), // 0: Lauf 07:15 Berlin
        _kraft(_utc(2026, 10, 10, 16, 0), 60), //   1: Vortag
        _anderes(_utc(2026, 10, 12, 9, 0), 30), //  2: Spaziergang
        _kraft(_utc(2026, 10, 12, 16, 30), 58), //  3: das gesuchte
        _kraft(_utc(2026, 10, 14, 16, 0), 60), //   4: Folgetag
      ];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), 3);
    });
  });

  group('Nur Krafttraining kommt in Frage', () {
    test('ein Lauf am selben Tag wird übergangen — der Puls eines Laufs unter '
        'einer Gym-Sitzung wäre falsch', () {
      final liste = [_anderes(_utc(2026, 10, 12, 5, 15), 52)];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), isNull);
    });

    test('jedes andere Training wird übergangen, auch wenn es das einzige des '
        'Tages ist und das längste', () {
      final liste = [
        _anderes(_utc(2026, 10, 12, 5, 0), 45),
        _anderes(_utc(2026, 10, 12, 10, 0), 120),
        _anderes(_utc(2026, 10, 12, 15, 0), 80),
      ];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), isNull);
    });

    // Prüfschwerpunkt: erst die Art aussortieren, dann die längste Dauer
    // suchen — nicht umgekehrt.
    test('ein längerer Lauf schlägt das kürzere Krafttraining nicht', () {
      final lauf = _anderes(_utc(2026, 10, 12, 5, 15), 95);
      final kraft = _kraft(_utc(2026, 10, 12, 16, 30), 41);

      expect(_treffer(_utc(2026, 10, 12, 10), [lauf, kraft]), 1);
      expect(_treffer(_utc(2026, 10, 12, 10), [kraft, lauf]), 0);
    });
  });

  group('Nur dieser Tag zählt', () {
    test('Krafttraining am Vortag und am Folgetag wird nicht gefunden — an '
        'den eigenen Tagen schon', () {
      final liste = [
        _kraft(_utc(2026, 10, 11, 16, 30), 60), // 11.10. 18:30 Berlin
        _kraft(_utc(2026, 10, 13, 16, 30), 60), // 13.10. 18:30 Berlin
      ];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), isNull);
      // Gegenprobe: Beide werden an ihren Tagen gefunden.
      expect(_treffer(_utc(2026, 10, 11, 10), liste), 0);
      expect(_treffer(_utc(2026, 10, 13, 10), liste), 1);
    });

    test('der Tag darf mit Uhrzeit hereinkommen und findet dasselbe Training '
        'wie sein Berliner Tagesbeginn', () {
      final liste = [_kraft(_utc(2026, 10, 12, 16, 30), 58)];

      // Tagesbeginn: 12.10. 00:00 Berlin = 11.10. 22:00 UTC. Der UTC-Tag
      // dieses Zeitpunkts ist der 11. — wer `day.day` vergleicht, sucht am
      // falschen Tag.
      final tagesbeginn = _utc(2026, 10, 11, 22);
      // 12.10. 15:00 Berlin.
      final nachmittags = _utc(2026, 10, 12, 13);
      // 12.10. 23:59 Berlin.
      final spaetabends = _utc(2026, 10, 12, 21, 59);

      expect(_treffer(tagesbeginn, liste), 0);
      expect(_treffer(nachmittags, liste), 0);
      expect(_treffer(spaetabends, liste), 0);
    });

    test(
      'auch der gesuchte Tag wird in Berliner Zeit gelesen, nicht in UTC',
      () {
        // 12.10. 23:30 UTC ist in Berlin der 13.10., 01:30. Die UTC-Felder
        // sagen „12.10." — gemeint ist der 13.
        final liste = [
          _kraft(_utc(2026, 10, 12, 16, 30), 60), // 12.10. 18:30 Berlin
          _kraft(_utc(2026, 10, 13, 16, 30), 50), // 13.10. 18:30 Berlin
        ];

        expect(_treffer(_utc(2026, 10, 12, 23, 30), liste), 1);
      },
    );

    test('ein lokaler DateTime (wie ihn `fromMillisecondsSinceEpoch` liefert) '
        'gibt dieselbe Antwort wie derselbe Zeitpunkt in UTC', () {
      // `WorkoutSample.ausMap` baut `start` lokal. Die Antwort darf nicht von
      // der Zeitzone des Geräts abhängen, auf dem der Test läuft.
      final start = _utc(2026, 10, 12, 22, 30); // 13.10. 00:30 Berlin
      final utcListe = [_kraft(start, 40)];
      final lokalListe = [_kraft(start.toLocal(), 40)];
      final tag = _utc(2026, 10, 13, 10);

      expect(_treffer(tag, utcListe), 0);
      expect(_treffer(tag.toLocal(), lokalListe), 0);
      expect(_treffer(_utc(2026, 10, 12, 10), lokalListe), isNull);
    });
  });

  group('Die Tagesgrenze liegt in Berlin, nicht in UTC', () {
    // Prüfschwerpunkt: 00:10 Berliner Zeit ist in UTC noch der Vortag. Wer
    // die Tage in UTC vergleicht, schiebt dieses Training einen Tag zurück.
    test('ein Training um 00:10 Berliner Zeit gehört zum neuen Tag', () {
      // 12.10. 00:10 Berlin = 11.10. 22:10 UTC.
      final liste = [_kraft(_utc(2026, 10, 11, 22, 10), 35)];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), 0);
      expect(_treffer(_utc(2026, 10, 11, 10), liste), isNull);
    });

    // Prüfschwerpunkt: 23:50 gehört zu seinem eigenen Tag.
    test(
      'ein Training um 23:50 Berliner Zeit gehört zu seinem eigenen Tag',
      () {
        // 12.10. 23:50 Berlin = 12.10. 21:50 UTC.
        final liste = [_kraft(_utc(2026, 10, 12, 21, 50), 20)];

        expect(_treffer(_utc(2026, 10, 12, 10), liste), 0);
        expect(_treffer(_utc(2026, 10, 13, 10), liste), isNull);
      },
    );

    test('Mitternacht selbst gehört zum neuen Tag, die Sekunde davor zum '
        'alten', () {
      // Berliner Mitternacht 13.10. = 12.10. 22:00 UTC.
      final genauMitternacht = _kraft(_utc(2026, 10, 12, 22), 30);
      final sekundeDavor = _kraft(_utc(2026, 10, 12, 21, 59, 59), 30);

      expect(_treffer(_utc(2026, 10, 13, 10), [genauMitternacht]), 0);
      expect(_treffer(_utc(2026, 10, 12, 10), [genauMitternacht]), isNull);
      expect(_treffer(_utc(2026, 10, 12, 10), [sekundeDavor]), 0);
      expect(_treffer(_utc(2026, 10, 13, 10), [sekundeDavor]), isNull);
    });

    // Derselbe Zahlendreher wie in den `DataWindow`-Tests: 00:05 UTC und
    // 23:30 UTC desselben UTC-Datums sind im Oktober **nicht** derselbe
    // Berliner Tag.
    test('00:05 UTC und 23:30 UTC desselben UTC-Datums sind zwei Berliner '
        'Tage', () {
      final fruehMorgens = _kraft(_utc(2026, 10, 12, 0, 5), 40); // 12.10. 02:05
      final spaetAbends = _kraft(
        _utc(2026, 10, 12, 23, 30),
        40,
      ); // 13.10. 01:30
      final liste = [fruehMorgens, spaetAbends];

      // Nach UTC-Feldern lägen beide am 12.10. und es gewänne das frühere.
      expect(_treffer(_utc(2026, 10, 12, 10), liste), 0);
      expect(_treffer(_utc(2026, 10, 13, 10), liste), 1);
      expect(_treffer(_utc(2026, 10, 14, 10), liste), isNull);
    });

    test('auch in der Winterzeit gehört 23:50 zum eigenen Tag — eine fest '
        'verdrahtete Verschiebung trifft höchstens eine Jahreszeit', () {
      // Januar: Berlin ist UTC+1.
      // 14.01. 23:50 Berlin = 14.01. 22:50 UTC; 15.01. 00:10 = 14.01. 23:10 UTC.
      final spaet = _kraft(_utc(2027, 1, 14, 22, 50), 20);
      final frueh = _kraft(_utc(2027, 1, 14, 23, 10), 20);

      expect(_treffer(_utc(2027, 1, 14, 10), [spaet]), 0);
      expect(_treffer(_utc(2027, 1, 15, 10), [spaet]), isNull);
      expect(_treffer(_utc(2027, 1, 15, 10), [frueh]), 0);
      expect(_treffer(_utc(2027, 1, 14, 10), [frueh]), isNull);
    });
  });

  group('Über die Sommerzeitumstellung', () {
    test('am Tag der Umstellung im März hat der Tag 23 Stunden — die '
        'Nachbartage bleiben draußen', () {
      // Umstellung am 28.03.2027 um 01:00 UTC. Der 28. beginnt um
      // 27.03. 23:00 UTC (UTC+1) und endet um 28.03. 22:00 UTC (UTC+2).
      // Wer 24 Stunden auf den Tagesbeginn addiert, endet um 23:00 UTC und
      // zieht das Training vom 29. 00:10 mit herein.
      final vorher = _kraft(_utc(2027, 3, 27, 22, 30), 30); // 27.03. 23:30
      final anfang = _kraft(_utc(2027, 3, 27, 23, 30), 30); // 28.03. 00:30
      final ende = _kraft(_utc(2027, 3, 28, 21, 50), 30); //   28.03. 23:50
      final folgetag = _kraft(_utc(2027, 3, 28, 22, 10), 30); // 29.03. 00:10
      final liste = [vorher, anfang, ende, folgetag];

      final tag28 = _utc(2027, 3, 28, 10);
      expect(_treffer(tag28, [vorher]), isNull);
      expect(_treffer(tag28, [anfang]), 0);
      expect(_treffer(tag28, [ende]), 0);
      expect(_treffer(tag28, [folgetag]), isNull);
      // Alle vier auf einmal: an Stelle 1 und 2 stehen zwei vom 28., beide
      // 30 Minuten — das frühere gewinnt.
      expect(_treffer(tag28, liste), 1);
      // Und der 29. bekommt das Training von 00:10.
      expect(_treffer(_utc(2027, 3, 29, 10), liste), 3);
    });

    test('am Tag der Umstellung im Oktober hat der Tag 25 Stunden — das '
        'Training um 23:30 gehört noch dazu', () {
      // Umstellung am 25.10.2026 um 01:00 UTC. Der 25. beginnt um
      // 24.10. 22:00 UTC (UTC+2) und endet um 25.10. 23:00 UTC (UTC+1).
      // Wer 24 Stunden auf den Tagesbeginn addiert, endet um 22:00 UTC und
      // wirft das Training von 23:30 Berliner Zeit dem 26. zu.
      final abends = _kraft(_utc(2026, 10, 25, 22, 30), 30); // 25.10. 23:30
      final folgetag = _kraft(_utc(2026, 10, 25, 23, 10), 30); // 26.10. 00:10
      final vortag = _kraft(_utc(2026, 10, 24, 21, 50), 30); //   24.10. 23:50

      final tag25 = _utc(2026, 10, 25, 10);
      expect(_treffer(tag25, [abends]), 0);
      expect(_treffer(tag25, [folgetag]), isNull);
      expect(_treffer(tag25, [vortag]), isNull);
      expect(_treffer(_utc(2026, 10, 26, 10), [folgetag]), 0);
      expect(_treffer(_utc(2026, 10, 26, 10), [abends]), isNull);
    });

    test('die Uhrzeit 02:30 gibt es am Umstellungstag im Oktober zweimal — '
        'beide gehören zum 25. und die frühere Stunde gewinnt den '
        'Gleichstand', () {
      // 02:30 Sommerzeit = 00:30 UTC, 02:30 Winterzeit = 01:30 UTC. Gleiche
      // Wanduhr, zwei Zeitpunkte; „früher" heißt der Zeitpunkt.
      final zweiteStunde = _kraft(_utc(2026, 10, 25, 1, 30), 45);
      final ersteStunde = _kraft(_utc(2026, 10, 25, 0, 30), 45);
      final tag25 = _utc(2026, 10, 25, 10);

      expect(_treffer(tag25, [zweiteStunde, ersteStunde]), 1);
      expect(_treffer(tag25, [ersteStunde, zweiteStunde]), 0);
    });
  });

  group('Mehrere Krafttrainings an einem Tag', () {
    test('von zwei Krafttrainings gewinnt das längere, in jeder '
        'Reihenfolge', () {
      // Wer morgens kurz an die Hantel geht und abends das eigentliche
      // Training macht, meint das abendliche.
      final kurz = _kraft(_utc(2026, 10, 12, 5, 30), 18);
      final lang = _kraft(_utc(2026, 10, 12, 16, 30), 62);
      final tag = _utc(2026, 10, 12, 10);

      expect(_treffer(tag, [kurz, lang]), 1);
      expect(_treffer(tag, [lang, kurz]), 0);
    });

    test('die Dauer entscheidet vor dem Beginn — das frühere, aber kürzere '
        'verliert', () {
      final frueherKuerzer = _kraft(_utc(2026, 10, 12, 4, 0), 44);
      final spaeterLaenger = _kraft(_utc(2026, 10, 12, 18, 0), 46);

      expect(
        _treffer(_utc(2026, 10, 12, 10), [frueherKuerzer, spaeterLaenger]),
        1,
      );
    });

    test('Bruchteile einer Minute zählen: 45,4 schlägt 45,0', () {
      // `minutes` ist ein `double`. Wer auf ganze Minuten kürzt, macht daraus
      // einen Gleichstand und wählt das frühere.
      final frueh = _kraft(_utc(2026, 10, 12, 5, 30), 45.0);
      final spaet = _kraft(_utc(2026, 10, 12, 16, 30), 45.4);

      expect(_treffer(_utc(2026, 10, 12, 10), [frueh, spaet]), 1);
      expect(_treffer(_utc(2026, 10, 12, 10), [spaet, frueh]), 0);
    });

    // Determinismus: „damit die Antwort nicht von der Reihenfolge abhängt,
    // in der HealthKit die Stichproben liefert."
    test('bei gleicher Dauer gewinnt das frühere, in jeder Reihenfolge von '
        'dreien', () {
      final a = _kraft(_utc(2026, 10, 12, 5, 30), 45); // 07:30 Berlin
      final b = _kraft(_utc(2026, 10, 12, 11, 0), 45); // 13:00 Berlin
      final c = _kraft(_utc(2026, 10, 12, 16, 30), 45); // 18:30 Berlin
      final tag = _utc(2026, 10, 12, 10);

      for (final reihenfolge in _permutationen([a, b, c])) {
        expect(
          reihenfolge[_treffer(tag, reihenfolge)!],
          a,
          reason: 'bei Reihenfolge $reihenfolge muss das früheste gewinnen',
        );
      }
    });

    test('bei gleicher Dauer entscheidet der Zeitpunkt, nicht die Stelle in '
        'der Liste', () {
      final frueh = _kraft(_utc(2026, 10, 12, 5, 30), 45);
      final spaet = _kraft(_utc(2026, 10, 12, 16, 30), 45);
      final tag = _utc(2026, 10, 12, 10);

      expect(_treffer(tag, [frueh, spaet]), 0);
      expect(_treffer(tag, [spaet, frueh]), 1);
    });

    test('bei völligem Gleichstand gewinnt der Eintrag mit dem kleineren '
        'Index', () {
      // Gleicher Beginn, gleiche Dauer. Mit dem Index als Antwort sind die
      // beiden unterscheidbar — also muss feststehen, welcher es ist.
      final start = _utc(2026, 10, 12, 16, 30);
      final liste = [
        _anderes(_utc(2026, 10, 12, 5, 0), 90),
        _kraft(start, 45),
        _kraft(start, 45),
      ];

      expect(_treffer(_utc(2026, 10, 12, 10), liste), 1);
    });

    test(
      'aus einer Woche am Stück, mit Läufen, kommt das richtige Training',
      () {
        // Der tatsächliche Fall: viele Workouts nebeneinander, gesucht ist das
        // lange Krafttraining vom 12.10.
        final liste = [
          _anderes(_utc(2026, 10, 11, 7, 0), 110), // 0: Lauf, Vortag
          _kraft(_utc(2026, 10, 11, 17, 0), 70), //   1: Kraft, Vortag, länger
          _anderes(_utc(2026, 10, 12, 4, 45), 48), // 2: Lauf, gleicher Tag
          _kraft(_utc(2026, 10, 12, 10, 10), 22), //  3: kurzes Kraft
          _kraft(_utc(2026, 10, 12, 16, 20), 64), //  4: das gesuchte
          _kraft(_utc(2026, 10, 13, 16, 0), 90), //   5: Kraft, Folgetag, länger
        ];

        expect(_treffer(_utc(2026, 10, 12, 10), liste), 4);
      },
    );
  });

  group('Die Eingabeliste bleibt, wie sie ist', () {
    test('sie wird nicht verändert', () {
      final lang = _kraft(_utc(2026, 10, 12, 16, 30), 62);
      final kurz = _kraft(_utc(2026, 10, 12, 5, 30), 18);
      final lauf = _anderes(_utc(2026, 10, 12, 4, 0), 50);
      final liste = [kurz, lauf, lang];
      final vorher = List.of(liste);

      _treffer(_utc(2026, 10, 12, 10), liste);

      // Reihenfolge und Länge unverändert: Die App verlässt sich darauf,
      // dass `samples[index]` das gemeinte Sample ist.
      expect(liste, vorher);
    });

    test('sie darf unveränderlich sein', () {
      final liste = List<_Eintrag>.unmodifiable([
        _anderes(_utc(2026, 10, 12, 4, 0), 50),
        _kraft(_utc(2026, 10, 12, 5, 30), 18),
        _kraft(_utc(2026, 10, 12, 16, 30), 62),
      ]);

      expect(_treffer(_utc(2026, 10, 12, 10), liste), 2);
    });

    test('derselbe Aufruf zweimal gibt dieselbe Antwort', () {
      final liste = [
        _kraft(_utc(2026, 10, 12, 5, 30), 45),
        _kraft(_utc(2026, 10, 12, 16, 30), 45),
      ];
      final tag = _utc(2026, 10, 12, 10);

      expect(_treffer(tag, liste), _treffer(tag, liste));
    });
  });

  // Die Zeitpunkte oben sind nachgerechnet; diese Gruppe hält die Rechnung
  // fest, damit ein falsches Literal hier auffällt und nicht als Fall mit
  // irreführendem Namen. Sie prüft `BerlinCalendar`, nicht `GymWorkoutMatch`.
  group('Die Zeitpunkte stimmen', () {
    final erwartet = <(DateTime, String)>[
      (_utc(2026, 10, 11, 22, 10), '2026-10-12'), // 00:10 Berlin
      (_utc(2026, 10, 12, 21, 50), '2026-10-12'), // 23:50 Berlin
      (_utc(2026, 10, 12, 21, 59, 59), '2026-10-12'),
      (_utc(2026, 10, 12, 22), '2026-10-13'), // Mitternacht Berlin
      (_utc(2026, 10, 12, 0, 5), '2026-10-12'), // 02:05 Berlin
      (_utc(2026, 10, 12, 23, 30), '2026-10-13'), // 01:30 Berlin — der Dreher
      (_utc(2027, 1, 14, 22, 50), '2027-01-14'), // 23:50 Berlin, UTC+1
      (_utc(2027, 1, 14, 23, 10), '2027-01-15'), // 00:10 Berlin, UTC+1
      (_utc(2027, 3, 27, 22, 30), '2027-03-27'), // 23:30 Berlin
      (_utc(2027, 3, 27, 23, 30), '2027-03-28'), // 00:30 Berlin
      (_utc(2027, 3, 28, 21, 50), '2027-03-28'), // 23:50 Berlin, UTC+2
      (_utc(2027, 3, 28, 22, 10), '2027-03-29'), // 00:10 Berlin
      (_utc(2026, 10, 24, 21, 50), '2026-10-24'), // 23:50 Berlin
      (_utc(2026, 10, 25, 0, 30), '2026-10-25'), // 02:30 Sommerzeit
      (_utc(2026, 10, 25, 1, 30), '2026-10-25'), // 02:30 Winterzeit
      (_utc(2026, 10, 25, 22, 30), '2026-10-25'), // 23:30 Berlin, UTC+1
      (_utc(2026, 10, 25, 23, 10), '2026-10-26'), // 00:10 Berlin
    ];

    for (final (zeitpunkt, tag) in erwartet) {
      test('${zeitpunkt.toIso8601String()} ist in Berlin der $tag', () {
        expect(BerlinCalendar.dayKey(zeitpunkt), tag);
      });
    }
  });
}

/// Die Form der Eingabe — nur hier im Test benannt, damit die Tests keinen
/// Typnamen der Implementierung voraussetzen. Als Record ist sie strukturell
/// dieselbe Form, die `matchIndex` verlangt.
typedef _Eintrag = ({DateTime start, bool isStrength, double minutes});

/// Ein UTC-Zeitpunkt. Absichtlich nur der Konstruktor: Die Berliner Uhrzeit
/// steht neben jedem Aufruf im Kommentar, nicht in einer Hilfsfunktion, die
/// die Sommerzeitregel nachbaute.
DateTime _utc(
  int jahr,
  int monat,
  int tag, [
  int stunde = 0,
  int minute = 0,
  int sekunde = 0,
]) => DateTime.utc(jahr, monat, tag, stunde, minute, sekunde);

_Eintrag _kraft(DateTime start, double minuten) =>
    (start: start, isStrength: true, minutes: minuten);

/// Alles, was kein Krafttraining ist — Lauf, Spaziergang, Rad. Der Kern
/// unterscheidet sie nicht weiter.
_Eintrag _anderes(DateTime start, double minuten) =>
    (start: start, isStrength: false, minutes: minuten);

int? _treffer(DateTime tag, List<_Eintrag> liste) =>
    GymWorkoutMatch.matchIndex(day: tag, workouts: liste);

/// Alle Reihenfolgen einer kleinen Liste.
Iterable<List<T>> _permutationen<T>(List<T> eintraege) sync* {
  if (eintraege.length <= 1) {
    yield List.of(eintraege);
    return;
  }
  for (var i = 0; i < eintraege.length; i++) {
    final rest = [...eintraege.sublist(0, i), ...eintraege.sublist(i + 1)];
    for (final tail in _permutationen(rest)) {
      yield [eintraege[i], ...tail];
    }
  }
}
