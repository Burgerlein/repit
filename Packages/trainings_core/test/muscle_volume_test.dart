import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `MuscleVolume`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/MuscleVolume.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block E“. Portiert aus `MuscleVolumeTests.swift` und um die
/// Fälle ergänzt, die der von Hand gebaute Berliner Kalender verlangt.
///
/// **Die Zielbereiche sind allgemeine Richtwerte für Muskelaufbau, keine
/// ärztliche Vorgabe.** Sie stehen in `docs/SPEC.md` 4.4 (Zeile 159) und in
/// `Muscle.swift`; hier werden sie nur benutzt, nicht festgelegt — das prüft
/// `muscle_test.dart`.
///
/// ### Woher die Zahlen kommen
/// Die Gewichtung steht **im Übungskatalog**, nicht in dieser Rechnung:
/// Hauptmuskel 1,0, Nebenbelastung 0,5. Welche Gewichte die hier benutzten
/// Übungen tragen, hält die Gruppe „Voraussetzungen aus dem Übungskatalog“
/// ausdrücklich fest — steht dort rot, liegt es an einer geänderten
/// Katalogzahl und nicht an der Rechnung.
///
/// ### Zeitrechnung
/// Alle Zeitpunkte sind UTC-`DateTime`-Werte, die Berliner Kalendertage
/// bezeichnen; das Datum ist erfunden und meint kein Ereignis. Die
/// Fenstergrenze läuft über den **Berliner Tagesbeginn**, nicht über eine
/// Dauer in Stunden — deshalb die eigenen Fälle über beide
/// Sommerzeitumstellungen.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`, „Wer
/// Tests schreibt, schreibt nicht die Implementierung“).
void main() {
  // Erfundener Bezugszeitpunkt: Mittwoch, 12.05.2027, 22:00 Berliner Zeit.
  // Mai liegt in der Sommerzeit (UTC+2), also 20:00 UTC. Bewusst spät am
  // Abend, damit jeder Satz „von heute“ in der Vergangenheit liegt und die
  // Tests keine Aussage über künftige Sätze treffen.
  final jetzt = DateTime.utc(2027, 5, 12, 20);

  /// Ein Zeitpunkt mitten am Berliner Kalendertag, der [tageZurueck] Tage vor
  /// dem 12.05.2027 liegt.
  ///
  /// 10:00 UTC ist in Berlin 12:00 (Sommerzeit) oder 11:00 (Winterzeit) —
  /// in beiden Fällen derselbe Kalendertag, die Uhrzeit ist also unabhängig
  /// vom Versatz eindeutig. `12 - tageZurueck` lässt Dart über Monatsgrenzen
  /// hinweg normalisieren (`DateTime.utc(2027, 5, -28)` ist der 02.04.2027).
  DateTime tag(int tageZurueck) => DateTime.utc(2027, 5, 12 - tageZurueck, 10);

  TrainedSet satz(int tageZurueck, String uebungsId) =>
      TrainedSet(date: tag(tageZurueck), exerciseId: uebungsId);

  /// Ein UTC-Zeitpunkt, der die angegebene **Berliner Wanduhrzeit**
  /// bezeichnet. Der Versatz steht von Hand da (+2 Sommerzeit, +1
  /// Winterzeit): Ein Test, der ihn über `BerlinCalendar` bestimmte, stützte
  /// sich auf dieselbe Regel, die er prüfen soll.
  DateTime berlin(
    int jahr,
    int monat,
    int tagImMonat,
    int stunde,
    int minute, {
    required int versatzStunden,
  }) => DateTime.utc(jahr, monat, tagImMonat, stunde - versatzStunden, minute);

  /// Jeder nicht genannte Muskel muss bei null stehen — eine Karte, der ein
  /// Muskel fehlt oder die ihn still auf einem alten Wert lässt, zeigt ein
  /// Loch statt einer Null.
  void erwarteNullAusser(Map<Muscle, double> volumen, Set<Muscle> ausnahmen) {
    for (final muskel in Muscle.values) {
      if (ausnahmen.contains(muskel)) continue;
      expect(volumen[muskel], 0, reason: '${muskel.code} muss bei null stehen');
    }
  }

  group('Voraussetzungen aus dem Übungskatalog', () {
    // Dieser eine Test ist die Diagnosehilfe für alle anderen: Jede Zahl
    // weiter unten setzt genau diese Gewichtung voraus. Ist er rot, hat
    // jemand den Katalog geändert; sind nur die anderen rot, liegt es an der
    // Rechnung.
    test('Die benutzten Übungen tragen die erwarteten Gewichte', () {
      expect(ExerciseCatalog.all['benchPress']?.muscles, {
        Muscle.chest: 1.0,
        Muscle.frontDelt: 0.5,
        Muscle.triceps: 0.5,
      });
      expect(ExerciseCatalog.all['dips']?.muscles, {
        Muscle.triceps: 1.0,
        Muscle.chest: 0.5,
        Muscle.frontDelt: 0.5,
      });
      expect(ExerciseCatalog.all['closeGripBench']?.muscles, {
        Muscle.triceps: 1.0,
        Muscle.chest: 0.5,
      });
      expect(ExerciseCatalog.all['cableFly']?.muscles, {Muscle.chest: 1.0});
      expect(ExerciseCatalog.all['lateralRaise']?.muscles, {
        Muscle.sideDelt: 1.0,
      });
      expect(ExerciseCatalog.all['hipThrust']?.muscles, {
        Muscle.glutes: 1.0,
        Muscle.hamstrings: 0.5,
      });
      expect(ExerciseCatalog.all['calfRaiseSeated']?.muscles, {
        Muscle.calves: 1.0,
      });
      expect(ExerciseCatalog.all['legPress']?.muscles, {
        Muscle.quads: 1.0,
        Muscle.glutes: 0.5,
      });
      expect(ExerciseCatalog.all['legCurl']?.muscles, {Muscle.hamstrings: 1.0});
      expect(ExerciseCatalog.all['hipAbduction']?.muscles, {
        Muscle.glutes: 1.0,
      });
      expect(ExerciseCatalog.all['legExtension']?.muscles, {Muscle.quads: 1.0});
    });

    test('Die erfundene Übungs-ID steht wirklich nicht im Katalog', () {
      // Sonst prüfte „unbekannte Übung wird übergangen“ gar nichts.
      expect(ExerciseCatalog.all.containsKey('zumba'), isFalse);
    });
  });

  group('Der Fensteranfang', () {
    test('Bei einem Tag ist es der heutige Berliner Tagesbeginn', () {
      // 12.05.2027 00:00 Berliner Zeit, Sommerzeit → 11.05.2027 22:00 UTC.
      expect(
        MuscleVolume.windowStart(days: 1, now: jetzt),
        DateTime.utc(2027, 5, 11, 22),
      );
    });

    test('Bei sieben Tagen ist es der Tagesbeginn von vor sechs Tagen', () {
      // days - 1 = 6 → 06.05.2027 00:00 Berliner Zeit → 05.05.2027 22:00 UTC.
      expect(
        MuscleVolume.windowStart(days: 7, now: jetzt),
        DateTime.utc(2027, 5, 5, 22),
      );
    });

    test('Bei dreißig Tagen ist es der Tagesbeginn von vor 29 Tagen', () {
      // 12.05. minus 29 Tage = 13.04.2027 00:00 Berliner Zeit (Sommerzeit)
      // → 12.04.2027 22:00 UTC.
      expect(
        MuscleVolume.windowStart(days: 30, now: jetzt),
        DateTime.utc(2027, 4, 12, 22),
      );
    });

    test('Ohne Fenster gibt es keine Grenze', () {
      // Kein Fenster heißt nichts zu zählen — nicht „alles zählt“.
      expect(MuscleVolume.windowStart(days: 0, now: jetzt), isNull);
      expect(MuscleVolume.windowStart(days: -1, now: jetzt), isNull);
      expect(MuscleVolume.windowStart(days: -30, now: jetzt), isNull);
    });

    test('Die Grenze hängt am Tag, nicht an der Uhrzeit', () {
      // Derselbe Berliner Kalendertag, drei Uhrzeiten — dieselbe Grenze.
      final frueh = berlin(2027, 5, 12, 0, 5, versatzStunden: 2);
      final mittags = berlin(2027, 5, 12, 13, 0, versatzStunden: 2);
      final spaet = berlin(2027, 5, 12, 23, 55, versatzStunden: 2);
      final erwartet = DateTime.utc(2027, 5, 5, 22);
      expect(MuscleVolume.windowStart(days: 7, now: frueh), erwartet);
      expect(MuscleVolume.windowStart(days: 7, now: mittags), erwartet);
      expect(MuscleVolume.windowStart(days: 7, now: spaet), erwartet);
    });
  });

  group('Die Gewichtung', () {
    test('Ein Satz Bankdrücken zählt Brust 1, vordere Schulter und Trizeps '
        'je 0,5', () {
      final v = MuscleVolume.weeklySets(
        [satz(1, 'benchPress')],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], 1);
      expect(v[Muscle.frontDelt], 0.5);
      expect(v[Muscle.triceps], 0.5);
      erwarteNullAusser(v, {Muscle.chest, Muscle.frontDelt, Muscle.triceps});
    });

    test('Eine Nebenbelastung trägt einen halben Satz bei, nicht einen '
        'ganzen', () {
      // Der Fall, den eine Vereinfachung auf „trainiert ja/nein“ zerstören
      // würde: Dips treffen den Trizeps voll, Brust und vordere Schulter
      // halb. Vier Sätze sind für den Trizeps vier, für die anderen beiden
      // zwei — und auf keinen Fall ebenfalls vier.
      final v = MuscleVolume.weeklySets(
        List.generate(4, (i) => satz(i + 1, 'dips')),
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.triceps], 4);
      expect(v[Muscle.chest], 2);
      expect(v[Muscle.frontDelt], 2);
      expect(v[Muscle.chest], isNot(4));
      expect(v[Muscle.frontDelt], isNot(4));
      erwarteNullAusser(v, {Muscle.triceps, Muscle.chest, Muscle.frontDelt});
    });

    test('Mehrere Übungen addieren sich auf denselben Muskel', () {
      final v = MuscleVolume.weeklySets(
        [
          satz(1, 'benchPress'), // Brust 1
          satz(2, 'cableFly'), // Brust 1
          satz(3, 'closeGripBench'), // Brust 0,5
        ],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], closeTo(2.5, 1e-9));
      expect(v[Muscle.triceps], closeTo(1.5, 1e-9)); // 0,5 + 1
      expect(v[Muscle.frontDelt], 0.5);
    });

    test('Die neuen Beinübungen zählen auf ihre Muskeln', () {
      final v = MuscleVolume.weeklySets(
        [
          satz(1, 'legPress'),
          satz(1, 'legCurl'),
          satz(1, 'hipAbduction'),
          satz(1, 'legExtension'),
        ],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.quads], 2); // Beinpresse 1 + Beinstrecker 1
      expect(v[Muscle.glutes], 1.5); // Beinpresse 0,5 + Abduktoren 1
      expect(v[Muscle.hamstrings], 1); // Beinbeuger 1
    });

    test('Ein alter Satz einer ausgemusterten Übung zählt weiter mit', () {
      // Hip Thrust und Wadenheben sitzend stehen in keinem Workout mehr. Im
      // gespeicherten Verlauf stehen sie weiter — und müssen dort zählen,
      // sonst fällt rückwirkend Volumen aus der Muskelkarte.
      final hueft = MuscleVolume.weeklySets(
        [satz(1, 'hipThrust')],
        days: 7,
        now: jetzt,
      );
      expect(hueft[Muscle.glutes], 1);
      expect(hueft[Muscle.hamstrings], 0.5);

      final wade = MuscleVolume.weeklySets(
        [satz(2, 'calfRaiseSeated')],
        days: 7,
        now: jetzt,
      );
      expect(wade[Muscle.calves], 1);
    });

    test('Eine unbekannte Übung wird übergangen, nicht geraten', () {
      // Eine Übung, die der Katalog nicht kennt, hat keine Muskelzuordnung.
      // Raten hieße, eine Zahl zu erfinden.
      final v = MuscleVolume.weeklySets(
        [satz(1, 'zumba')],
        days: 7,
        now: jetzt,
      );
      expect(v, hasLength(16));
      expect(v.values, everyElement(0));
    });

    test('Eine unbekannte Übung nimmt den bekannten Sätzen nichts weg', () {
      final v = MuscleVolume.weeklySets(
        [satz(1, 'zumba'), satz(1, 'benchPress'), satz(2, 'zumba')],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], 1);
    });
  });

  group('Die Mittelung auf die Woche', () {
    test('Im Sieben-Tage-Fenster bleibt die rohe Summe stehen', () {
      // Der Faktor ist 7/7 = 1 — genau deshalb taugt dieses Fenster allein
      // nicht als Beweis für die Mittelung.
      final v = MuscleVolume.weeklySets(
        [satz(1, 'cableFly'), satz(2, 'cableFly'), satz(3, 'cableFly')],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], closeTo(3, 1e-9));
    });

    test('Im Vierzehn-Tage-Fenster halbiert sich die Zahl', () {
      // Dieselben drei Sätze, doppelt so langes Fenster: 3 / (14/7) = 1,5.
      final v = MuscleVolume.weeklySets(
        [satz(1, 'cableFly'), satz(2, 'cableFly'), satz(3, 'cableFly')],
        days: 14,
        now: jetzt,
      );
      expect(v[Muscle.chest], closeTo(1.5, 1e-9));
    });

    test('Gewichtung und Mittelung greifen zusammen', () {
      // Drei Sätze Bankdrücken im 14-Tage-Fenster: Brust 3 × 1 / 2 = 1,5,
      // Trizeps und vordere Schulter 3 × 0,5 / 2 = 0,75.
      final saetze = [
        satz(1, 'benchPress'),
        satz(5, 'benchPress'),
        satz(12, 'benchPress'),
      ];
      final v = MuscleVolume.weeklySets(saetze, days: 14, now: jetzt);
      expect(v[Muscle.chest], closeTo(1.5, 1e-9));
      expect(v[Muscle.triceps], closeTo(0.75, 1e-9));
      expect(v[Muscle.frontDelt], closeTo(0.75, 1e-9));
    });

    test('Im Dreißig-Tage-Fenster wird auf eine Woche heruntergerechnet', () {
      // Zwölf Sätze Bankdrücken in 30 Tagen sind 12 / (30/7) = 2,8 pro Woche.
      final saetze = List.generate(12, (i) => satz(i + 1, 'benchPress'));
      final v = MuscleVolume.weeklySets(saetze, days: 30, now: jetzt);
      expect(v[Muscle.chest], closeTo(2.8, 1e-9));
      expect(v[Muscle.triceps], closeTo(1.4, 1e-9));
    });
  });

  group('Die Fenstergrenze', () {
    test('Ein Satz von heute zählt mit', () {
      final v = MuscleVolume.weeklySets(
        [satz(0, 'benchPress')],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], 1);
    });

    test('Der Satz von vor sechs Tagen zählt, der von vor sieben nicht', () {
      final v = MuscleVolume.weeklySets(
        [satz(6, 'benchPress'), satz(7, 'benchPress')],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], 1);
    });

    test('Ein Satz genau zum Berliner Tagesbeginn des Grenztags zählt mit', () {
      // Die Grenze ist einschließlich: `startOfDay(satz) >= cutoff`.
      final v = MuscleVolume.weeklySets(
        [
          TrainedSet(
            date: berlin(2027, 5, 6, 0, 0, versatzStunden: 2),
            exerciseId: 'cableFly',
          ),
        ],
        days: 7,
        now: jetzt,
      );
      expect(v[Muscle.chest], 1);
    });

    test('Am Grenztag entscheidet der Kalendertag, nicht die Uhrzeit', () {
      // 23:00 am ältesten zählenden Tag zählt genauso wie 06:00 — und 23:00
      // am Tag davor zählt nicht, obwohl es nur eine Stunde vor der Grenze
      // liegt. Wer das Fenster über eine Dauer in Stunden rechnet, dreht
      // genau dieses Paar um.
      final spaetDrin = TrainedSet(
        date: berlin(2027, 5, 6, 23, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final fruehDrin = TrainedSet(
        date: berlin(2027, 5, 6, 6, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final spaetDraussen = TrainedSet(
        date: berlin(2027, 5, 5, 23, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );

      expect(
        MuscleVolume.weeklySets([spaetDrin], days: 7, now: jetzt)[Muscle.chest],
        1,
      );
      expect(
        MuscleVolume.weeklySets([fruehDrin], days: 7, now: jetzt)[Muscle.chest],
        1,
      );
      expect(
        MuscleVolume.weeklySets(
          [spaetDraussen],
          days: 7,
          now: jetzt,
        )[Muscle.chest],
        0,
      );
    });

    test('Ohne Fenster steht jeder der 16 Muskeln bei null', () {
      // `days <= 0` heißt: kein Fenster, nichts zu zählen. Nicht null, nicht
      // eine leere Map — sonst zeigte die Karte Löcher statt Nullen.
      for (final tage in [0, -1, -7]) {
        final v = MuscleVolume.weeklySets(
          [satz(0, 'benchPress'), satz(1, 'cableFly')],
          days: tage,
          now: jetzt,
        );
        expect(v, hasLength(16), reason: 'days: $tage');
        expect(v.keys.toSet(), Muscle.values.toSet(), reason: 'days: $tage');
        expect(v.values, everyElement(0), reason: 'days: $tage');
      }
    });
  });

  group('Die Fenstergrenze über die Sommerzeitumstellung', () {
    // Die Umstellung liegt in der EU jeweils um 01:00 UTC am letzten Sonntag
    // im März und im Oktober. 2027 ist das der 28.03. und der 31.10.
    // (01.03.2027 ist ein Montag → Sonntage 7/14/21/28; 01.10.2027 ist ein
    // Freitag → Sonntage 3/10/17/24/31.)
    //
    // Für das Fenster heißt das: Sechs Kalendertage zurück sind über eine
    // Umstellung hinweg nicht 144 Stunden, sondern 143 oder 145. Wer mit
    // einer festen Dauer rechnet, verschiebt die Grenze um eine Stunde — und
    // genau in dieser Stunde liegen die beiden Sätze unten.

    test('Im Frühjahr liegt die Grenze eine Stunde später als 144 Stunden', () {
      // 30.03.2027, 08:00 Berliner Zeit (schon Sommerzeit, UTC+2).
      final jetztImFruehjahr = berlin(2027, 3, 30, 8, 0, versatzStunden: 2);
      // Sechs Kalendertage zurück: 24.03.2027 00:00 Berliner Zeit, noch
      // Winterzeit (UTC+1) → 23.03.2027 23:00 UTC.
      expect(
        MuscleVolume.windowStart(days: 7, now: jetztImFruehjahr),
        DateTime.utc(2027, 3, 23, 23),
      );
    });

    test('Im Frühjahr trennt die Grenze zwei Sätze desselben UTC-Tages', () {
      final jetztImFruehjahr = berlin(2027, 3, 30, 8, 0, versatzStunden: 2);
      // Beide Zeitpunkte liegen am 23.03. in UTC, aber auf verschiedenen
      // Berliner Kalendertagen.
      final draussen = TrainedSet(
        // 23.03.2027, 23:30 Berliner Zeit → 22:30 UTC am 23.03.
        date: berlin(2027, 3, 23, 23, 30, versatzStunden: 1),
        exerciseId: 'cableFly',
      );
      final drin = TrainedSet(
        // 24.03.2027, 00:30 Berliner Zeit → 23:30 UTC am 23.03.
        date: berlin(2027, 3, 24, 0, 30, versatzStunden: 1),
        exerciseId: 'cableFly',
      );
      expect(draussen.date, DateTime.utc(2027, 3, 23, 22, 30));
      expect(drin.date, DateTime.utc(2027, 3, 23, 23, 30));

      final v = MuscleVolume.weeklySets(
        [draussen, drin],
        days: 7,
        now: jetztImFruehjahr,
      );
      expect(v[Muscle.chest], 1);
    });

    test('Im Herbst liegt die Grenze eine Stunde früher als 144 Stunden', () {
      // 02.11.2027, 08:00 Berliner Zeit (schon Winterzeit, UTC+1).
      final jetztImHerbst = berlin(2027, 11, 2, 8, 0, versatzStunden: 1);
      // Sechs Kalendertage zurück: 27.10.2027 00:00 Berliner Zeit, noch
      // Sommerzeit (UTC+2) → 26.10.2027 22:00 UTC.
      expect(
        MuscleVolume.windowStart(days: 7, now: jetztImHerbst),
        DateTime.utc(2027, 10, 26, 22),
      );
    });

    test('Im Herbst trennt die Grenze zwei Sätze desselben UTC-Tages', () {
      final jetztImHerbst = berlin(2027, 11, 2, 8, 0, versatzStunden: 1);
      final draussen = TrainedSet(
        // 26.10.2027, 23:30 Berliner Zeit → 21:30 UTC am 26.10.
        date: berlin(2027, 10, 26, 23, 30, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final drin = TrainedSet(
        // 27.10.2027, 00:30 Berliner Zeit → 22:30 UTC am 26.10.
        date: berlin(2027, 10, 27, 0, 30, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      expect(draussen.date, DateTime.utc(2027, 10, 26, 21, 30));
      expect(drin.date, DateTime.utc(2027, 10, 26, 22, 30));

      final v = MuscleVolume.weeklySets(
        [draussen, drin],
        days: 7,
        now: jetztImHerbst,
      );
      expect(v[Muscle.chest], 1);
    });

    test('Ein Fenster über die Umstellung zählt sieben Kalendertage', () {
      // 27.10. bis 02.11.2027 sind sieben Kalendertage und 169 Stunden. Je
      // ein Satz pro Tag muss siebenmal zählen; der Tag davor nicht.
      final jetztImHerbst = berlin(2027, 11, 2, 8, 0, versatzStunden: 1);
      final saetze = <TrainedSet>[
        TrainedSet(
          date: berlin(2027, 10, 26, 12, 0, versatzStunden: 2),
          exerciseId: 'cableFly',
        ),
        // 27. bis 30.10. liegen noch in der Sommerzeit (UTC+2) …
        for (final t in [27, 28, 29, 30])
          TrainedSet(
            date: berlin(2027, 10, t, 12, 0, versatzStunden: 2),
            exerciseId: 'cableFly',
          ),
        // … der 31.10. ab 01:00 UTC schon in der Winterzeit (UTC+1).
        TrainedSet(
          date: berlin(2027, 10, 31, 12, 0, versatzStunden: 1),
          exerciseId: 'cableFly',
        ),
        for (final t in [1, 2])
          TrainedSet(
            date: berlin(2027, 11, t, 7, 0, versatzStunden: 1),
            exerciseId: 'cableFly',
          ),
      ];
      final v = MuscleVolume.weeklySets(saetze, days: 7, now: jetztImHerbst);
      expect(v[Muscle.chest], closeTo(7, 1e-9));
    });
  });

  group('Die Karte hat nie ein Loch', () {
    test('Ohne Training steht jeder Muskel bei null', () {
      final v = MuscleVolume.weeklySets([], days: 7, now: jetzt);
      expect(v, hasLength(16));
      expect(v.keys.toSet(), Muscle.values.toSet());
      for (final muskel in Muscle.values) {
        expect(v[muskel], 0, reason: muskel.code);
        expect(MuscleVolume.status(muskel, 0), MuscleStatus.priority);
      }
    });

    test('Auch mit Training sind alle 16 Muskeln enthalten', () {
      final v = MuscleVolume.weeklySets(
        [satz(1, 'lateralRaise')],
        days: 7,
        now: jetzt,
      );
      expect(v, hasLength(16));
      expect(v.keys.toSet(), Muscle.values.toSet());
      expect(v[Muscle.sideDelt], 1);
      erwarteNullAusser(v, {Muscle.sideDelt});
    });
  });

  group('Der Zustand zum Zielbereich', () {
    test('Es gibt genau vier Zustände', () {
      expect(MuscleStatus.values, [
        MuscleStatus.priority,
        MuscleStatus.low,
        MuscleStatus.ok,
        MuscleStatus.high,
      ]);
    });

    test('Brust: alle vier Grenzen von beiden Seiten', () {
      // Ziel 10 bis 20, halbe Untergrenze 5.
      expect(MuscleVolume.status(Muscle.chest, 0), MuscleStatus.priority);
      expect(MuscleVolume.status(Muscle.chest, 4.999), MuscleStatus.priority);
      expect(MuscleVolume.status(Muscle.chest, 5), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.chest, 5.001), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.chest, 9.999), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.chest, 10), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.chest, 10.001), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.chest, 19.999), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.chest, 20), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.chest, 20.001), MuscleStatus.high);
      expect(MuscleVolume.status(Muscle.chest, 100), MuscleStatus.high);
    });

    test('Unterer Rücken: die engste Spanne der Karte', () {
      // Ziel 2 bis 8, halbe Untergrenze 1.
      expect(
        MuscleVolume.status(Muscle.lowerBack, 0.999),
        MuscleStatus.priority,
      );
      expect(MuscleVolume.status(Muscle.lowerBack, 1), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.lowerBack, 1.999), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.lowerBack, 2), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.lowerBack, 8), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.lowerBack, 8.001), MuscleStatus.high);
    });

    test('Vordere Schulter: eigener Bereich, eigene Grenzen', () {
      // Ziel 4 bis 12, halbe Untergrenze 2.
      expect(
        MuscleVolume.status(Muscle.frontDelt, 1.999),
        MuscleStatus.priority,
      );
      expect(MuscleVolume.status(Muscle.frontDelt, 2), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.frontDelt, 3.999), MuscleStatus.low);
      expect(MuscleVolume.status(Muscle.frontDelt, 4), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.frontDelt, 12), MuscleStatus.ok);
      expect(MuscleVolume.status(Muscle.frontDelt, 12.001), MuscleStatus.high);
    });

    test('Jeder Muskel liegt an seinen eigenen vier Grenzen richtig', () {
      // Dasselbe für alle 16, aus dem Zielbereich abgeleitet statt
      // abgeschrieben: Wer eine Grenze aus `Muscle.target` falsch benutzt,
      // fällt hier auf.
      for (final muskel in Muscle.values) {
        final (low: unten, high: oben) = muskel.target;
        final grund = muskel.code;
        expect(
          MuscleVolume.status(muskel, unten / 2 - 0.001),
          MuscleStatus.priority,
          reason: grund,
        );
        expect(
          MuscleVolume.status(muskel, unten / 2),
          MuscleStatus.low,
          reason: grund,
        );
        expect(
          MuscleVolume.status(muskel, unten - 0.001),
          MuscleStatus.low,
          reason: grund,
        );
        expect(
          MuscleVolume.status(muskel, unten),
          MuscleStatus.ok,
          reason: grund,
        );
        expect(
          MuscleVolume.status(muskel, oben),
          MuscleStatus.ok,
          reason: grund,
        );
        expect(
          MuscleVolume.status(muskel, oben + 0.001),
          MuscleStatus.high,
          reason: grund,
        );
      }
    });
  });

  group('Die Reihenfolge nach Dringlichkeit', () {
    test('Das Ergebnis enthält immer alle 16 Muskeln', () {
      expect(MuscleVolume.sortedByNeed(const {}), hasLength(16));
      expect(
        MuscleVolume.sortedByNeed(const {}).toSet(),
        Muscle.values.toSet(),
      );
    });

    test('Ein fehlender Muskel gilt als null, nicht als fehlend', () {
      // Nur die Brust steht drin und ist über dem Ziel; die übrigen 15 sind
      // unbekannt und damit dringend.
      final reihenfolge = MuscleVolume.sortedByNeed({Muscle.chest: 30});
      expect(reihenfolge, hasLength(16));
      expect(reihenfolge.last, Muscle.chest);
    });

    test('Bei Gleichstand entscheidet der Code — jedes Mal gleich', () {
      // Der ganze Zweck der letzten Stufe: Stehen alle Muskeln bei null,
      // sind Zustand (priority) und Abstand zur Untergrenze (0) für alle
      // gleich. Ohne die dritte Stufe hinge die Reihenfolge an der Laune der
      // Map und spränge bei jedem Aufruf.
      final alleNull = {for (final m in Muscle.values) m: 0.0};
      const alphabetisch = [
        Muscle.biceps,
        Muscle.calves,
        Muscle.chest,
        Muscle.core,
        Muscle.forearms,
        Muscle.frontDelt,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lats,
        Muscle.lowerBack,
        Muscle.quads,
        Muscle.rearDelt,
        Muscle.sideDelt,
        Muscle.tibialis,
        Muscle.triceps,
        Muscle.upperBack,
      ];
      expect(MuscleVolume.sortedByNeed(alleNull), alphabetisch);
      // Und beim zweiten Aufruf dasselbe.
      expect(MuscleVolume.sortedByNeed(alleNull), alphabetisch);
    });

    test(
      'Gleicher Zustand und gleicher Abstand, verschiedene Zielbereiche',
      () {
        // Brust (Ziel ab 10) bei 5 und hintere Schulter (Ziel ab 6) bei 3:
        // beide `low`, beide genau auf der halben Untergrenze, Abstand also
        // 0,5. Dann entscheidet der Code: chest vor rearDelt.
        final volumen = {
          for (final m in Muscle.values) m: m.target.high + 1,
          Muscle.chest: 5.0,
          Muscle.rearDelt: 3.0,
        };
        final reihenfolge = MuscleVolume.sortedByNeed(volumen);
        expect(reihenfolge.take(2), [Muscle.chest, Muscle.rearDelt]);
      },
    );

    test('Die Gruppen stehen in der Reihenfolge priority, low, high, ok', () {
      // „high“ steht vor „ok“: Wer über dem Ziel liegt, braucht eher einen
      // Hinweis als wer darin liegt.
      final volumen = {
        for (final m in Muscle.values) m: 12.0,
        Muscle.chest: 0.0, // priority
        Muscle.lats: 2.0, // priority
        Muscle.biceps: 7.0, // low
        Muscle.triceps: 9.0, // low
        Muscle.upperBack: 25.0, // high
      };
      final reihenfolge = MuscleVolume.sortedByNeed(volumen);

      MuscleStatus zustand(Muscle m) => MuscleVolume.status(m, volumen[m] ?? 0);
      const rang = {
        MuscleStatus.priority: 0,
        MuscleStatus.low: 1,
        MuscleStatus.high: 2,
        MuscleStatus.ok: 3,
      };
      final raenge = reihenfolge.map((m) => rang[zustand(m)]!).toList();
      for (var i = 1; i < raenge.length; i++) {
        expect(
          raenge[i],
          greaterThanOrEqualTo(raenge[i - 1]),
          reason: 'Rangfolge bricht bei ${reihenfolge[i].code}',
        );
      }
      expect(reihenfolge.first, Muscle.chest);
    });

    test('Innerhalb einer Gruppe entscheidet der Abstand zur Untergrenze', () {
      // Dieselbe Lage, vollständig durchsortiert:
      //   priority: chest 0/10 = 0, lats 2/10 = 0,2
      //   low:      biceps 7/10 = 0,7, triceps 9/10 = 0,9
      //   high:     core/forearms/tibialis 12/4 = 3 (Gleichstand → Code),
      //             upperBack 25/8 = 3,125, lowerBack 12/2 = 6
      //   ok:       sideDelt 12/10 = 1,2,
      //             calves/glutes/hamstrings/quads/rearDelt 12/6 = 2
      //             (Gleichstand → Code), frontDelt 12/4 = 3
      final volumen = {
        for (final m in Muscle.values) m: 12.0,
        Muscle.chest: 0.0,
        Muscle.lats: 2.0,
        Muscle.biceps: 7.0,
        Muscle.triceps: 9.0,
        Muscle.upperBack: 25.0,
      };
      expect(MuscleVolume.sortedByNeed(volumen), [
        Muscle.chest,
        Muscle.lats,
        Muscle.biceps,
        Muscle.triceps,
        Muscle.core,
        Muscle.forearms,
        Muscle.tibialis,
        Muscle.upperBack,
        Muscle.lowerBack,
        Muscle.sideDelt,
        Muscle.calves,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.quads,
        Muscle.rearDelt,
        Muscle.frontDelt,
      ]);
    });

    test('Die Liste führt die dringendsten Muskeln zuerst', () {
      // Der portierte Swift-Fall, lockerer formuliert.
      final volumen = {
        for (final m in Muscle.values) m: 12.0,
        Muscle.chest: 0.0,
        Muscle.biceps: 7.0,
        Muscle.lats: 25.0,
        Muscle.triceps: 15.0,
      };
      final reihenfolge = MuscleVolume.sortedByNeed(volumen);
      expect(reihenfolge.first, Muscle.chest);
      expect(
        reihenfolge.indexOf(Muscle.biceps),
        lessThan(reihenfolge.indexOf(Muscle.lats)),
      );
      expect(
        reihenfolge.indexOf(Muscle.lats),
        lessThan(reihenfolge.indexOf(Muscle.triceps)),
      );
    });
  });

  group('TrainedSet als Werttyp', () {
    // Ein Werttyp, der Abhängigkeit eines Providers ist, braucht `==` und
    // `hashCode` — sonst rechnet Riverpod jedes Mal neu (`CLAUDE.md`).
    test('Gleiche Werte sind gleich', () {
      final a = TrainedSet(date: tag(1), exerciseId: 'benchPress');
      final b = TrainedSet(date: tag(1), exerciseId: 'benchPress');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Ein anderes Datum oder eine andere Übung macht ungleich', () {
      final a = TrainedSet(date: tag(1), exerciseId: 'benchPress');
      expect(a, isNot(TrainedSet(date: tag(2), exerciseId: 'benchPress')));
      expect(a, isNot(TrainedSet(date: tag(1), exerciseId: 'cableFly')));
    });

    test('Zwei gleiche Sätze liegen im Set nur einmal', () {
      final menge = {
        TrainedSet(date: tag(1), exerciseId: 'benchPress'),
        TrainedSet(date: tag(1), exerciseId: 'benchPress'),
      };
      expect(menge, hasLength(1));
    });
  });
}
