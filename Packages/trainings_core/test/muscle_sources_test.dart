import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `muscleSources`, das Dart-Gegenstück zu
/// `MuscleVolume.sources(for:sets:window:now:)` aus
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/MuscleSources.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block E“ — in Dart eine **Funktion auf Bibliotheksebene**, weil
/// es keine statischen Extensions gibt.
///
/// Beim Antippen eines Muskels soll die Muskelkarte sagen, woher seine Sätze
/// kommen. Es ist dieselbe Rechnung wie in `MuscleVolume.weeklySets`, nur
/// nach Übung aufgeschlüsselt statt auf den Muskel zusammengefasst. Die
/// wichtigste Zusicherung steht deshalb in der Gruppe „Die Summe muss
/// stimmen“: Die Summe der Quellen ist exakt der Wert, den die Karte zeigt.
/// Laufen die beiden auseinander, erklärt die Aufschlüsselung eine Zahl, die
/// auf der Karte nirgends steht.
///
/// **Die Zielbereiche der Muskeln sind allgemeine Richtwerte, keine
/// ärztliche Vorgabe** — hier spielen sie ohnehin keine Rolle, die
/// Aufschlüsselung kennt keinen Zustand.
///
/// Zeitrechnung wie in `muscle_volume_test.dart`: UTC-Zeitpunkte, die
/// Berliner Kalendertage bezeichnen, erfundenes Datum.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`, „Wer
/// Tests schreibt, schreibt nicht die Implementierung“).
void main() {
  // Mittwoch, 12.05.2027, 22:00 Berliner Zeit (Sommerzeit, UTC+2).
  final jetzt = DateTime.utc(2027, 5, 12, 20);

  /// Mitten am Berliner Kalendertag, [tageZurueck] Tage vor dem 12.05.2027:
  /// 10:00 UTC sind in Berlin 12:00 (Sommer) oder 11:00 (Winter) — in jedem
  /// Fall derselbe Kalendertag.
  DateTime tag(int tageZurueck) => DateTime.utc(2027, 5, 12 - tageZurueck, 10);

  TrainedSet satz(int tageZurueck, String uebungsId) =>
      TrainedSet(date: tag(tageZurueck), exerciseId: uebungsId);

  /// Ein UTC-Zeitpunkt, der die angegebene **Berliner Wanduhrzeit** meint.
  /// Der Versatz steht von Hand da (+2 Sommerzeit, +1 Winterzeit), damit der
  /// Test sich nicht auf dieselbe Regel stützt, die er prüft.
  DateTime berlin(
    int jahr,
    int monat,
    int tagImMonat,
    int stunde,
    int minute, {
    required int versatzStunden,
  }) => DateTime.utc(jahr, monat, tagImMonat, stunde - versatzStunden, minute);

  List<MuscleSource> quellen(
    Muscle muskel,
    List<TrainedSet> saetze, {
    int days = 7,
    DateTime? now,
  }) => muscleSources(
    muscle: muskel,
    sets: saetze,
    days: days,
    now: now ?? jetzt,
  );

  group('Voraussetzungen aus dem Übungskatalog', () {
    // Diagnosehilfe für alles Weitere: Jede Zahl unten setzt diese
    // Gewichtung voraus. Ist nur dieser Test rot, hat jemand den Katalog
    // geändert — nicht die Rechnung.
    test('Die benutzten Übungen tragen die erwarteten Gewichte', () {
      expect(ExerciseCatalog.all['benchPress']?.muscles, {
        Muscle.chest: 1.0,
        Muscle.frontDelt: 0.5,
        Muscle.triceps: 0.5,
      });
      expect(ExerciseCatalog.all['closeGripBench']?.muscles, {
        Muscle.triceps: 1.0,
        Muscle.chest: 0.5,
      });
      expect(ExerciseCatalog.all['dips']?.muscles, {
        Muscle.triceps: 1.0,
        Muscle.chest: 0.5,
        Muscle.frontDelt: 0.5,
      });
      expect(ExerciseCatalog.all['overheadTriceps']?.muscles, {
        Muscle.triceps: 1.0,
      });
      expect(ExerciseCatalog.all['tricepsPushdown']?.muscles, {
        Muscle.triceps: 1.0,
      });
      expect(ExerciseCatalog.all['cableFly']?.muscles, {Muscle.chest: 1.0});
      expect(ExerciseCatalog.all['lateralRaise']?.muscles, {
        Muscle.sideDelt: 1.0,
      });
      expect(ExerciseCatalog.all['tibialisRaise']?.muscles, {
        Muscle.tibialis: 1.0,
      });
      expect(ExerciseCatalog.all['hammerCurl']?.muscles, {
        Muscle.biceps: 1.0,
        Muscle.forearms: 1.0,
      });
      expect(ExerciseCatalog.all['ezCurl']?.muscles, {
        Muscle.biceps: 1.0,
        Muscle.forearms: 0.5,
      });
      expect(ExerciseCatalog.all['pullUp']?.muscles, {
        Muscle.lats: 1.0,
        Muscle.biceps: 0.5,
        Muscle.rearDelt: 0.5,
      });
      expect(ExerciseCatalog.all['romanianDeadlift']?.muscles, {
        Muscle.hamstrings: 1.0,
        Muscle.glutes: 0.5,
        Muscle.lowerBack: 0.5,
      });
      expect(ExerciseCatalog.all['sidePlank']?.muscles, {Muscle.core: 1.0});
    });

    test('Die erfundene Übungs-ID steht wirklich nicht im Katalog', () {
      expect(ExerciseCatalog.all.containsKey('zumba'), isFalse);
    });
  });

  group('Leere und unpassende Eingaben', () {
    test('Ohne Sätze gibt es keine Quellen', () {
      expect(quellen(Muscle.chest, const []), isEmpty);
    });

    test('Ein Fenster von null oder negativ ergibt keine Quellen', () {
      // `days <= 0` heißt: kein Fenster, nichts zu zählen — eine leere
      // Liste, nicht null.
      final saetze = [satz(0, 'benchPress'), satz(1, 'benchPress')];
      for (final tage in [0, -1, -7]) {
        final ergebnis = quellen(Muscle.chest, saetze, days: tage);
        expect(ergebnis, isEmpty, reason: 'days: $tage');
      }
    });

    test('Ein Muskel, den keine der Übungen trifft, hat keine Quellen', () {
      final saetze = [satz(1, 'benchPress'), satz(2, 'cableFly')];
      expect(quellen(Muscle.tibialis, saetze), isEmpty);
      expect(quellen(Muscle.calves, saetze), isEmpty);
    });

    test('Nur Übungen, die den Muskel treffen, erscheinen', () {
      // Seitheben trifft nur die seitliche Schulter, Zehenheben an der Wand
      // nur das Schienbein. Keine der beiden darf unter der Brust stehen.
      final saetze = [
        satz(1, 'benchPress'),
        satz(1, 'lateralRaise'),
        satz(2, 'tibialisRaise'),
      ];
      expect(quellen(Muscle.chest, saetze).map((q) => q.exerciseId), [
        'benchPress',
      ]);
      expect(quellen(Muscle.sideDelt, saetze).map((q) => q.exerciseId), [
        'lateralRaise',
      ]);
      expect(quellen(Muscle.tibialis, saetze).map((q) => q.exerciseId), [
        'tibialisRaise',
      ]);
    });

    test('Eine unbekannte Übung wird übergangen, der Rest bleibt stehen', () {
      // Genau wie in `weeklySets`: Ein Satz, dessen Gewichte niemand kennt,
      // zählt nirgends mit — und nimmt den bekannten nichts weg.
      final saetze = [
        satz(1, 'zumba'),
        satz(1, 'benchPress'),
        satz(2, 'zumba'),
      ];
      final ergebnis = quellen(Muscle.chest, saetze);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.exerciseId, 'benchPress');
      expect(ergebnis.single.setCount, 1);
      expect(ergebnis.single.weeklySets, closeTo(1, 1e-9));
    });
  });

  group('Die Fenstergrenze', () {
    test('Der älteste zählende Tag ist drin, der nächste fällt heraus', () {
      // Dieselbe Grenze wie `weeklySets`: Bei sieben Tagen zählt der Satz
      // von vor sechs Tagen noch, der von vor sieben nicht mehr.
      final ergebnis = quellen(Muscle.chest, [
        satz(6, 'benchPress'),
        satz(7, 'benchPress'),
      ]);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.setCount, 1);
      expect(ergebnis.single.lastDate, tag(6));
    });

    test('Eine Übung, die nur außerhalb des Fensters vorkommt, fehlt ganz', () {
      final saetze = [
        satz(1, 'benchPress'),
        satz(7, 'cableFly'),
        satz(20, 'cableFly'),
      ];
      expect(quellen(Muscle.chest, saetze).map((q) => q.exerciseId), [
        'benchPress',
      ]);
    });

    test('Ein Satz von heute zählt mit', () {
      final ergebnis = quellen(Muscle.chest, [satz(0, 'benchPress')]);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.lastDate, tag(0));
    });

    test('Am Grenztag entscheidet der Kalendertag, nicht die Uhrzeit', () {
      // 23:00 am ältesten zählenden Tag zählt; 23:00 am Tag davor nicht,
      // obwohl es nur eine Stunde vor der Grenze liegt. Wer das Fenster über
      // eine Dauer in Stunden rechnet, dreht dieses Paar um.
      final spaetDrin = TrainedSet(
        date: berlin(2027, 5, 6, 23, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final spaetDraussen = TrainedSet(
        date: berlin(2027, 5, 5, 23, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final ergebnis = quellen(Muscle.chest, [spaetDrin, spaetDraussen]);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.setCount, 1);
      expect(ergebnis.single.lastDate, spaetDrin.date);
    });

    test('Ein Satz genau zum Berliner Tagesbeginn des Grenztags zählt mit', () {
      final amAnfang = TrainedSet(
        date: berlin(2027, 5, 6, 0, 0, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      expect(quellen(Muscle.chest, [amAnfang]), hasLength(1));
    });

    test('Im Frühjahr trennt die Grenze zwei Sätze desselben UTC-Tages', () {
      // Umstellung 2027: letzter Sonntag im März = 28.03., 01:00 UTC.
      // Jetzt: 30.03.2027, 08:00 Berliner Zeit (Sommerzeit).
      // Fensterbeginn: 24.03.2027 00:00 Berliner Zeit = 23.03. 23:00 UTC.
      final jetztImFruehjahr = berlin(2027, 3, 30, 8, 0, versatzStunden: 2);
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
      final ergebnis = quellen(Muscle.chest, [
        draussen,
        drin,
      ], now: jetztImFruehjahr);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.setCount, 1);
      expect(ergebnis.single.lastDate, drin.date);
    });

    test('Im Herbst trennt die Grenze zwei Sätze desselben UTC-Tages', () {
      // Umstellung 2027: letzter Sonntag im Oktober = 31.10., 01:00 UTC.
      // Jetzt: 02.11.2027, 08:00 Berliner Zeit (Winterzeit).
      // Fensterbeginn: 27.10.2027 00:00 Berliner Zeit = 26.10. 22:00 UTC.
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
      final ergebnis = quellen(Muscle.chest, [
        draussen,
        drin,
      ], now: jetztImHerbst);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.lastDate, drin.date);
    });

    test('Über die Umstellung hinweg sagen Quellen und Karte dasselbe', () {
      // Der eigentliche Punkt der beiden Fälle oben: Es ist dieselbe Grenze.
      final jetztImHerbst = berlin(2027, 11, 2, 8, 0, versatzStunden: 1);
      final saetze = <TrainedSet>[
        TrainedSet(
          date: berlin(2027, 10, 26, 23, 30, versatzStunden: 2),
          exerciseId: 'benchPress',
        ),
        TrainedSet(
          date: berlin(2027, 10, 27, 0, 30, versatzStunden: 2),
          exerciseId: 'benchPress',
        ),
        TrainedSet(
          date: berlin(2027, 10, 31, 18, 0, versatzStunden: 1),
          exerciseId: 'cableFly',
        ),
        TrainedSet(
          date: berlin(2027, 11, 1, 7, 0, versatzStunden: 1),
          exerciseId: 'dips',
        ),
      ];
      final karte = MuscleVolume.weeklySets(
        saetze,
        days: 7,
        now: jetztImHerbst,
      );
      for (final muskel in Muscle.values) {
        final summe = quellen(
          muskel,
          saetze,
          now: jetztImHerbst,
        ).fold<double>(0, (s, q) => s + q.weeklySets);
        expect(
          summe,
          closeTo(karte[muskel] ?? 0, 1e-9),
          reason: 'Quellen und Karte laufen bei ${muskel.code} auseinander',
        );
      }
    });
  });

  group('Zählung und Mittelung', () {
    test('setCount zählt roh, weeklySets gewichtet und auf die Woche '
        'gemittelt', () {
      // Bankdrücken trägt den Trizeps mit 0,5. Drei Sätze im 14-Tage-
      // Fenster: 3 × 0,5 = 1,5 gewichtete Sätze, geteilt durch 14/7 = 2
      // Wochen → 0,75 pro Woche. Die ungewichtete Zahl bleibt davon
      // unberührt: drei Sätze sind drei. Dass die beiden Zahlen
      // auseinandergehen, ist Absicht.
      final saetze = [
        satz(1, 'benchPress'),
        satz(5, 'benchPress'),
        satz(12, 'benchPress'),
      ];
      final trizeps = quellen(Muscle.triceps, saetze, days: 14);
      expect(trizeps, hasLength(1));
      expect(trizeps.single.setCount, 3);
      expect(trizeps.single.weeklySets, closeTo(0.75, 1e-9));
      expect(trizeps.single.weeklySets, isNot(closeTo(3, 1e-9)));

      // Für den Hauptmuskel derselben Übung: 3 × 1 / 2 Wochen = 1,5.
      final brust = quellen(Muscle.chest, saetze, days: 14);
      expect(brust.single.setCount, 3);
      expect(brust.single.weeklySets, closeTo(1.5, 1e-9));
    });

    test('Eine Nebenbelastung trägt einen halben Satz, keinen ganzen', () {
      // Im Sieben-Tage-Fenster ist der Mittelungsfaktor 1, der Unterschied
      // kommt also allein von der Gewichtung.
      final saetze = [satz(1, 'dips'), satz(2, 'dips')];
      expect(
        quellen(Muscle.triceps, saetze).single.weeklySets,
        closeTo(2, 1e-9),
      );
      expect(quellen(Muscle.chest, saetze).single.weeklySets, closeTo(1, 1e-9));
      // Ungewichtet sind es beide Male zwei Sätze.
      expect(quellen(Muscle.triceps, saetze).single.setCount, 2);
      expect(quellen(Muscle.chest, saetze).single.setCount, 2);
    });

    test('Mehrere Sätze derselben Übung werden zu einem Eintrag '
        'zusammengefasst', () {
      final saetze = [
        satz(5, 'cableFly'),
        satz(1, 'cableFly'),
        satz(3, 'cableFly'),
      ];
      final ergebnis = quellen(Muscle.chest, saetze);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.exerciseId, 'cableFly');
      expect(ergebnis.single.setCount, 3);
      expect(ergebnis.single.weeklySets, closeTo(3, 1e-9));
      expect(ergebnis.single.lastDate, tag(1));
    });

    test('Jede Übung kommt höchstens einmal vor', () {
      final saetze = [
        satz(0, 'benchPress'),
        satz(1, 'benchPress'),
        satz(2, 'dips'),
        satz(3, 'dips'),
        satz(4, 'closeGripBench'),
      ];
      final ids = quellen(Muscle.triceps, saetze).map((q) => q.exerciseId);
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.toSet(), {'benchPress', 'dips', 'closeGripBench'});
    });
  });

  group('Das jüngste Datum', () {
    test('lastDate ist der jüngste Satz der Übung im Fenster', () {
      final ergebnis = quellen(Muscle.chest, [
        satz(6, 'cableFly'),
        satz(2, 'cableFly'),
        satz(4, 'cableFly'),
      ]);
      expect(ergebnis.single.lastDate, tag(2));
    });

    test('lastDate trägt die Uhrzeit des Satzes, nicht den Tagesbeginn', () {
      // Der Schirm zeigt „zuletzt am …“ — ein auf Mitternacht gerundeter
      // Wert behauptete eine Uhrzeit, die es nicht gab.
      final frueh = TrainedSet(
        date: berlin(2027, 5, 10, 7, 15, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final spaet = TrainedSet(
        date: berlin(2027, 5, 10, 19, 47, versatzStunden: 2),
        exerciseId: 'cableFly',
      );
      final ergebnis = quellen(Muscle.chest, [frueh, spaet]);
      expect(ergebnis.single.lastDate, spaet.date);
      expect(ergebnis.single.lastDate, DateTime.utc(2027, 5, 10, 17, 47));
      // Und ausdrücklich nicht der Berliner Tagesbeginn des 10.05.2027.
      expect(ergebnis.single.lastDate, isNot(DateTime.utc(2027, 5, 9, 22)));
    });

    test('Ein Satz außerhalb des Fensters verschiebt lastDate nicht', () {
      // Weder nach vorn noch nach hinten: Was draußen liegt, zählt gar nicht.
      final ergebnis = quellen(Muscle.chest, [
        satz(2, 'cableFly'),
        satz(30, 'cableFly'),
      ]);
      expect(ergebnis.single.setCount, 1);
      expect(ergebnis.single.lastDate, tag(2));
    });
  });

  group('Die Sortierung', () {
    test('Der größte Beitrag steht oben', () {
      // Trizeps-Beiträge im Sieben-Tage-Fenster: Trizeps über Kopf 3 × 1 = 3,
      // enges Bankdrücken 2 × 1 = 2, Bankdrücken 2 × 0,5 = 1.
      final saetze = [
        satz(1, 'overheadTriceps'),
        satz(2, 'overheadTriceps'),
        satz(3, 'overheadTriceps'),
        satz(1, 'closeGripBench'),
        satz(4, 'closeGripBench'),
        satz(2, 'benchPress'),
        satz(5, 'benchPress'),
      ];
      final ergebnis = quellen(Muscle.triceps, saetze);
      expect(ergebnis.map((q) => q.exerciseId), [
        'overheadTriceps',
        'closeGripBench',
        'benchPress',
      ]);
      expect(ergebnis[0].weeklySets, closeTo(3, 1e-9));
      expect(ergebnis[1].weeklySets, closeTo(2, 1e-9));
      expect(ergebnis[2].weeklySets, closeTo(1, 1e-9));
    });

    test('Bei gleichem Beitrag steht das jüngere Training oben', () {
      final saetze = [satz(5, 'overheadTriceps'), satz(1, 'tricepsPushdown')];
      final ergebnis = quellen(Muscle.triceps, saetze);
      expect(ergebnis[0].weeklySets, closeTo(ergebnis[1].weeklySets, 1e-9));
      expect(ergebnis.map((q) => q.exerciseId), [
        'tricepsPushdown',
        'overheadTriceps',
      ]);
      expect(ergebnis[0].lastDate, tag(1));
    });

    test('Bei gleichem Beitrag und gleichem Datum entscheidet die '
        'Übungs-ID', () {
      // Die letzte Stufe ist reiner Determinismus: Ohne sie hinge die
      // Reihenfolge an der Laune der Map und spränge bei jedem Aufruf.
      final saetze = [satz(2, 'tricepsPushdown'), satz(2, 'overheadTriceps')];
      final ergebnis = quellen(Muscle.triceps, saetze);
      expect(ergebnis[0].weeklySets, closeTo(ergebnis[1].weeklySets, 1e-9));
      expect(ergebnis[0].lastDate, ergebnis[1].lastDate);
      expect(ergebnis.map((q) => q.exerciseId), [
        'overheadTriceps',
        'tricepsPushdown',
      ]);
    });

    test('Dieselbe Eingabe ergibt zweimal dieselbe Reihenfolge', () {
      // Vier Übungen mit identischem Beitrag und identischem Datum —
      // allein die dritte Stufe hält die Liste still.
      final saetze = [
        satz(2, 'tricepsPushdown'),
        satz(2, 'overheadTriceps'),
        satz(2, 'closeGripBench'),
        satz(2, 'dips'),
      ];
      const erwartet = [
        'closeGripBench',
        'dips',
        'overheadTriceps',
        'tricepsPushdown',
      ];
      expect(
        quellen(Muscle.triceps, saetze).map((q) => q.exerciseId),
        erwartet,
      );
      expect(
        quellen(Muscle.triceps, saetze).map((q) => q.exerciseId),
        erwartet,
      );
      // Auch wenn die Sätze in anderer Reihenfolge hereinkommen.
      expect(
        quellen(
          Muscle.triceps,
          saetze.reversed.toList(),
        ).map((q) => q.exerciseId),
        erwartet,
      );
    });

    test('Alle drei Stufen greifen nacheinander', () {
      // Trizeps im Sieben-Tage-Fenster:
      //   Trizeps über Kopf 3 × 1 = 3 — führt über die erste Stufe.
      //   Trizepsdrücken, enges Bankdrücken und Dips liegen mit je 1 × 1 = 1
      //   gleichauf; Trizepsdrücken ist von gestern und zieht über die
      //   zweite Stufe vor. Enges Bankdrücken und Dips teilen sich denselben
      //   Tag, also entscheidet die dritte Stufe: closeGripBench vor dips.
      final saetze = [
        satz(1, 'overheadTriceps'),
        satz(2, 'overheadTriceps'),
        satz(3, 'overheadTriceps'),
        satz(1, 'tricepsPushdown'),
        satz(4, 'closeGripBench'),
        satz(4, 'dips'),
      ];
      final ergebnis = quellen(Muscle.triceps, saetze);
      expect(ergebnis.map((q) => q.exerciseId), [
        'overheadTriceps',
        'tricepsPushdown',
        'closeGripBench',
        'dips',
      ]);
      expect(ergebnis[0].weeklySets, closeTo(3, 1e-9));
      expect(ergebnis[0].setCount, 3);
      expect(ergebnis[1].weeklySets, closeTo(1, 1e-9));
      expect(ergebnis[2].weeklySets, closeTo(1, 1e-9));
      expect(ergebnis[3].weeklySets, closeTo(1, 1e-9));
      expect(ergebnis[1].lastDate, tag(1));
      expect(ergebnis[2].lastDate, tag(4));
      expect(ergebnis[3].lastDate, tag(4));
    });
  });

  group('Die Summe muss stimmen', () {
    test('Die Summe aller Quellen ist genau der Wert der Muskelkarte', () {
      // Gemischter Datensatz: mehrere Übungen, mehrere Tage, eine unbekannte
      // ID und ein Satz außerhalb des Fensters.
      final saetze = [
        satz(0, 'benchPress'),
        satz(2, 'benchPress'),
        satz(2, 'benchPress'),
        satz(1, 'cableFly'),
        satz(4, 'closeGripBench'),
        satz(4, 'dips'),
        satz(3, 'lateralRaise'),
        satz(5, 'hammerCurl'),
        satz(6, 'pullUp'),
        satz(2, 'romanianDeadlift'),
        satz(6, 'sidePlank'),
        satz(9, 'benchPress'), // außerhalb des Fensters
        satz(1, 'zumba'), // nicht im Katalog
      ];
      final karte = MuscleVolume.weeklySets(saetze, days: 7, now: jetzt);

      for (final muskel in Muscle.values) {
        final summe = quellen(
          muskel,
          saetze,
        ).fold<double>(0, (s, q) => s + q.weeklySets);
        expect(
          summe,
          closeTo(karte[muskel] ?? 0, 1e-9),
          reason: 'Quellen und Karte laufen bei ${muskel.code} auseinander',
        );
      }
    });

    test('Die Summe stimmt auch im Dreißig-Tage-Fenster', () {
      // Das Fenster ist bewusst nicht sieben Tage: Dort wäre der
      // Mittelungsfaktor 1 und ein vergessenes Teilen unsichtbar.
      const ids = ['benchPress', 'cableFly', 'dips', 'pullUp', 'ezCurl'];
      final saetze = [
        for (var t = 0; t <= 40; t++) satz(t, ids[t % ids.length]),
      ];
      final karte = MuscleVolume.weeklySets(saetze, days: 30, now: jetzt);

      for (final muskel in Muscle.values) {
        final summe = quellen(
          muskel,
          saetze,
          days: 30,
        ).fold<double>(0, (s, q) => s + q.weeklySets);
        expect(
          summe,
          closeTo(karte[muskel] ?? 0, 1e-9),
          reason: 'Quellen und Karte laufen bei ${muskel.code} auseinander',
        );
      }
    });

    test('Die Summe stimmt auch, wenn gar nichts im Fenster liegt', () {
      final saetze = [satz(40, 'benchPress'), satz(50, 'cableFly')];
      final karte = MuscleVolume.weeklySets(saetze, days: 7, now: jetzt);
      for (final muskel in Muscle.values) {
        expect(quellen(muskel, saetze), isEmpty, reason: muskel.code);
        expect(karte[muskel], 0, reason: muskel.code);
      }
    });
  });

  group('MuscleSource als Werttyp', () {
    // Ein Werttyp, der Abhängigkeit eines Providers ist, braucht `==` und
    // `hashCode` — sonst rechnet Riverpod jedes Mal neu (`CLAUDE.md`).
    MuscleSource quelle({
      String exerciseId = 'benchPress',
      double weeklySets = 1.5,
      int setCount = 3,
      DateTime? lastDate,
    }) => MuscleSource(
      exerciseId: exerciseId,
      weeklySets: weeklySets,
      setCount: setCount,
      lastDate: lastDate ?? DateTime.utc(2027, 5, 10, 17, 47),
    );

    test('Gleiche Werte sind gleich', () {
      expect(quelle(), quelle());
      expect(quelle().hashCode, quelle().hashCode);
    });

    test('Jedes einzelne Feld macht ungleich', () {
      expect(quelle(), isNot(quelle(exerciseId: 'cableFly')));
      expect(quelle(), isNot(quelle(weeklySets: 1.6)));
      expect(quelle(), isNot(quelle(setCount: 4)));
      expect(
        quelle(),
        isNot(quelle(lastDate: DateTime.utc(2027, 5, 10, 17, 48))),
      );
    });

    test('Zwei gleiche Quellen liegen im Set nur einmal', () {
      expect({quelle(), quelle()}, hasLength(1));
    });
  });
}
