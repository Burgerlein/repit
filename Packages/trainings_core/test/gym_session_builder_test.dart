import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `GymSessionBuilder`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymSessionBuilder.swift`.
/// Portiert aus `GymSessionBuilderTests.swift`.
///
/// Der Builder macht aus eingetippten Zeichenketten eine Sitzung. Was ein
/// gültiger Satz ist, ist **Fachlogik** und gehört deshalb hierher und nicht
/// in die Ansicht. Die vier Zusagen, auf die es ankommt:
///
/// 1. **Ohne einen einzigen brauchbaren Satz entsteht keine Sitzung.** Ein
///    leeres Training abzulegen hieße, in „Letzte Trainings" eine Zeile ohne
///    Inhalt zu führen — und im Verlauf einen Punkt bei null.
/// 2. **Eine Übungs-ID, die der Katalog nicht kennt, wird übergangen statt
///    geraten.** Sie hätte weder Muskeln noch Zielbereiche.
/// 3. **Der Assist-Umschalter speichert das Gewicht negativ** — und zwar über
///    `-abs(…)`, damit eine schon negativ eingetippte Zahl nicht zurück ins
///    Positive kippt.
/// 4. **Die Reihenfolge der Übungen folgt dem Workout**, Fremdes alphabetisch
///    dahinter. Eine Ansicht, die bei jedem Start anders aussieht, ist kaputt.
///
/// **Zum Zahlenlesen:** Maßgeblich ist, was die Swift-Fassung annimmt und
/// ablehnt, nicht was `double.tryParse` und `int.tryParse` zufällig tun. Die
/// Gruppe „Zahlenformate" hält die Fälle fest, in denen die beiden Sprachen
/// auseinanderlaufen könnten; die Begründung steht jeweils am Testfall.
///
/// Alle Zeitpunkte sind UTC-Werte, die Berliner Wanduhrzeiten bezeichnen —
/// so rechnet das ganze Paket. Alle Zahlen sind erfunden.
void main() {
  CompletedSet satz(double gewicht, int wiederholungen) =>
      CompletedSet(weight: gewicht, reps: wiederholungen);

  // Berliner Zeit 18:30 am 21.09.2026 (Sommerzeit, UTC+2).
  final abends = DateTime.utc(2026, 9, 21, 16, 30);

  group('Aus Feldern werden Sätze', () {
    test('Gewicht und Wiederholungen werden zu einem Satz', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-1',
        date: abends,
        workout: Workout.a,
        minutes: 62,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
      );

      expect(ergebnis?.exercises, hasLength(1));
      expect(ergebnis?.exercises.first.exerciseId, 'benchPress');
      expect(ergebnis?.exercises.first.sets, [satz(40, 8)]);
    });

    test('Komma und Punkt bedeuten dasselbe Gewicht', () {
      // Auf der Zehnertastatur liegt je nach Region das eine oder das andere
      // Trennzeichen. Wer 42,5 kg auflegt, hat nicht 425 kg bewegt.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-2',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '42,5', reps: '6'),
            RawSet(weight: '42.5', reps: '5'),
          ],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(42.5, 6), satz(42.5, 5)]);
    });

    test('Sätze ohne brauchbare Wiederholungen fallen weg', () {
      // Ein leeres Feld ist ein Satz, der nie stattgefunden hat. Ihn mit null
      // Wiederholungen zu speichern verfälscht Tonnage und Vorschlag.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-3',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: ''),
            RawSet(weight: '40', reps: '   '),
            RawSet(weight: '40', reps: '0'),
            RawSet(weight: '40', reps: 'acht'),
            RawSet(weight: '40', reps: '8'),
          ],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(40, 8)]);
    });

    test('Negative Wiederholungen sind keine Wiederholungen', () {
      // Die Schranke ist „größer als null", nicht „nicht leer".
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-3b',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: '-3'),
            RawSet(weight: '40', reps: '8'),
          ],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(40, 8)]);
    });

    test('Ein Satz ohne Gewicht zählt als null Kilo', () {
      // Dips am eigenen Körpergewicht sind ein gültiger Satz, kein
      // unvollständiges Formular.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-4',
        date: abends,
        workout: Workout.a,
        entries: {
          'dips': [RawSet(weight: '', reps: '10')],
        },
      );

      expect(ergebnis?.exercises.first.exerciseId, 'dips');
      expect(ergebnis?.exercises.first.sets, [satz(0, 10)]);
    });

    test('Ein unlesbares Gewichtsfeld macht den ganzen Satz ungültig', () {
      // Anders als beim leeren Feld: Dort stand nichts, hier steht etwas, das
      // niemand deuten kann. Es als null Kilo zu buchen hieße raten.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-4b',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: 'schwer', reps: '8'),
            RawSet(weight: '40', reps: '8'),
          ],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(40, 8)]);
    });

    test('Leerzeichen um die Zahlen herum werden abgeschnitten', () {
      // Der Nutzer tippt in ein Textfeld, nicht in ein Formular.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-4c',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '  42,5  ', reps: '  8  ')],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(42.5, 8)]);
    });
  });

  group('Unterstützung', () {
    test('Unterstützung macht das Gewicht negativ', () {
      // −27 heißt: 27 kg Hilfe von der Maschine. So liest es die Progression,
      // so rechnet die Tonnage.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-5',
        date: abends,
        workout: Workout.a,
        entries: {
          'dips': [RawSet(weight: '27', reps: '6')],
        },
        assist: {'dips': true},
      );

      expect(ergebnis?.exercises.first.sets, [satz(-27, 6)]);
    });

    test('Ohne Schalter bleibt dieselbe Eingabe Zusatzgewicht', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-6',
        date: abends,
        workout: Workout.a,
        entries: {
          'dips': [RawSet(weight: '27', reps: '6')],
        },
      );

      expect(ergebnis?.exercises.first.sets, [satz(27, 6)]);
    });

    test(
      'Ein schon negativ eingetipptes Gewicht wird nicht noch einmal gedreht',
      () {
        // Sonst würde aus 27 kg Hilfe plötzlich 27 kg Zusatzlast.
        final ergebnis = GymSessionBuilder.session(
          id: 'eigen-7',
          date: abends,
          workout: Workout.a,
          entries: {
            'dips': [
              RawSet(weight: '-27', reps: '6'),
              RawSet(weight: '-24,5', reps: '5'),
            ],
          },
          assist: {'dips': true},
        );

        expect(ergebnis?.exercises.first.sets, [satz(-27, 6), satz(-24.5, 5)]);
      },
    );

    test('Der Schalter gilt nur für die Übung, für die er gesetzt ist', () {
      // Der Schalter steht an der Übungszeile, nicht am Training.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-7b',
        date: abends,
        workout: Workout.a,
        entries: {
          'dips': [RawSet(weight: '27', reps: '6')],
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
        assist: {'dips': true},
      );

      final nachId = {
        for (final uebung in ergebnis!.exercises)
          uebung.exerciseId: uebung.sets,
      };
      expect(nachId['dips'], [satz(-27, 6)]);
      expect(nachId['benchPress'], [satz(40, 8)]);
    });
  });

  group('Wann gar keine Sitzung entsteht', () {
    test('Eine Übung ohne übrig gebliebenen Satz taucht nicht auf', () {
      // Ein leerer Eintrag sähe in „Letzte Trainings" nach einem Fehler aus —
      // die Übung wurde schlicht nicht gemacht.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-8',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
          'dips': [RawSet(weight: '30', reps: '0')],
          'lateralRaise': <RawSet>[],
        },
      );

      expect(ergebnis?.exercises, hasLength(1));
      expect(ergebnis?.exercises.map((uebung) => uebung.exerciseId).toList(), [
        'benchPress',
      ]);
    });

    test('Bleibt nichts übrig, entsteht keine Sitzung', () {
      // Wer das Formular öffnet und nichts einträgt, hat nicht trainiert.
      final leer = GymSessionBuilder.session(
        id: 'eigen-9',
        date: abends,
        workout: Workout.a,
        minutes: 60,
        note: 'Nur kurz reingeschaut',
        entries: const {},
      );
      expect(leer, isNull);

      final unbrauchbar = GymSessionBuilder.session(
        id: 'eigen-10',
        date: abends,
        workout: Workout.a,
        minutes: 60,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '')],
          'dips': <RawSet>[],
        },
      );
      expect(unbrauchbar, isNull);
    });

    test('Eine unbekannte Übungs-ID wird übergangen', () {
      // Nicht raten: Eine ID, die der Katalog nicht kennt, hat keine
      // Muskelzuordnung und keinen Wiederholungsbereich.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-12',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
          'einhornheben': [RawSet(weight: '99', reps: '3')],
        },
      );

      expect(ergebnis?.exercises.map((uebung) => uebung.exerciseId).toList(), [
        'benchPress',
      ]);
    });

    test('Bleibt nur Unbekanntes übrig, entsteht keine Sitzung', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-13',
        date: abends,
        workout: Workout.a,
        entries: {
          'einhornheben': [RawSet(weight: '99', reps: '3')],
        },
      );

      expect(ergebnis, isNull);
    });
  });

  group('Reihenfolge und Kopfdaten', () {
    test('Die Übungen stehen in der Reihenfolge des Workouts, Fremdes alphabetisch dahinter', () {
      // Dieselbe Regel wie beim Dashboard-Import: Eine Map hat keine
      // verlässliche Fachreihenfolge, und eine Ansicht, die bei jedem Start
      // anders aussieht, ist kaputt.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-11',
        date: abends,
        workout: Workout.a,
        entries: {
          'lateralRaise': [RawSet(weight: '12', reps: '15')],
          'benchPress': [RawSet(weight: '40', reps: '8')],
          'dips': [RawSet(weight: '0', reps: '9')],
          'pullUp': [RawSet(weight: '0', reps: '7')],
          'facePull': [RawSet(weight: '18', reps: '14')],
        },
      );

      // Gym A: benchPress, inclineDumbbellPress, shoulderPressDumbbell, dips,
      // lateralRaise, overheadTriceps, bicepsCurl — davon vorhanden sind drei.
      // pullUp und facePull gehören zu Gym C und hängen alphabetisch nach
      // Übungs-ID hinten an.
      expect(ergebnis?.exercises.map((uebung) => uebung.exerciseId).toList(), [
        'benchPress',
        'dips',
        'lateralRaise',
        'facePull',
        'pullUp',
      ]);
    });

    test('ID, Workout, Dauer und Notiz werden unverändert durchgereicht', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-14',
        date: abends,
        workout: Workout.c,
        minutes: 73,
        note: 'Schulter hat gezwickt',
        entries: {
          'pullUp': [RawSet(weight: '0', reps: '7')],
        },
      );

      expect(ergebnis?.id, 'eigen-14');
      expect(ergebnis?.workout, Workout.c);
      expect(ergebnis?.minutes, 73);
      expect(ergebnis?.note, 'Schulter hat gezwickt');
    });

    test('Keine Dauer eingetragen heißt keine Dauer, nicht null Minuten', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-15',
        date: abends,
        workout: Workout.c,
        entries: {
          'pullUp': [RawSet(weight: '0', reps: '7')],
        },
      );

      expect(ergebnis?.minutes, isNull);
      expect(ergebnis?.note, isNull);
    });

    test('Eine leere Notiz wird nichts, keine leere Zeichenkette', () {
      // Sonst zeichnet die Ansicht eine leere Notizzeile unter das Training.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-16',
        date: abends,
        workout: Workout.a,
        note: '',
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
      );

      expect(ergebnis?.note, isNull);
    });

    test('Das Datum behält die Uhrzeit des Trainings', () {
      // Anders als beim Import, der nur ein Tagesdatum kennt: Wer um 19:45
      // abschließt, soll das später auch sehen. Und zwei Trainings an einem
      // Tag sollen sich unterscheiden lassen.
      final zeitpunkt = DateTime.utc(2026, 9, 21, 17, 45); // Berlin 19:45
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-17',
        date: zeitpunkt,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
      );

      expect(ergebnis?.date, zeitpunkt);
      expect(ergebnis?.date, isNot(BerlinCalendar.startOfDay(zeitpunkt)));
    });

    test('Ein frei wählbares Workout wird wie jedes andere eingetragen', () {
      // Push, Pull und Legs haben keinen festen Tag — beim Eintragen macht
      // das keinen Unterschied.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-18',
        date: DateTime.utc(2026, 9, 23, 16), // Berlin 18:00
        workout: Workout.legs,
        minutes: 58,
        entries: {
          'legPress': [RawSet(weight: '80', reps: '10')],
          'legCurl': [RawSet(weight: '30', reps: '12')],
        },
      );

      expect(ergebnis?.workout, Workout.legs);
      expect(ergebnis?.minutes, 58);
      expect(ergebnis?.exercises, hasLength(2));
      // Reihenfolge des Workouts, nicht die der Eingabe.
      expect(ergebnis?.exercises.map((uebung) => uebung.exerciseId).toList(), [
        'legPress',
        'legCurl',
      ]);
    });
  });

  group('Zahlenformate: wo Dart und Swift auseinanderlaufen könnten', () {
    /// Liefert die Sätze, die von einer Übung übrig bleiben. Der jeweils
    /// fragliche Satz steht neben einem sicher gültigen, damit die Sitzung
    /// nicht als Ganzes verschwindet und der Unterschied sichtbar wird.
    List<CompletedSet>? uebrig(List<RawSet> saetze) {
      final ergebnis = GymSessionBuilder.session(
        id: 'format',
        date: abends,
        workout: Workout.a,
        entries: {'benchPress': saetze},
      );
      return ergebnis?.exercises.first.sets;
    }

    test('Exponentialschreibweise im Gewicht wird gelesen', () {
      // Swift nimmt "1e3" als 1000 an, Dart ebenso. Kein Sonderfall, nur
      // festgehalten, damit niemand sie nachträglich verbietet.
      expect(uebrig([RawSet(weight: '1e3', reps: '2')]), [satz(1000, 2)]);
    });

    test('Ein hexadezimales Gewicht wird abgelehnt', () {
      // Hier weicht Dart bewusst von Swift ab: Swifts Double("0x10") ergibt
      // 16, weil es hexadezimale Gleitkommaliterale annimmt. Niemand tippt
      // 0x10 als Gewicht; eine stillschweigend gedeutete Zahl wäre schlimmer
      // als ein verworfener Satz.
      expect(
        uebrig([
          RawSet(weight: '0x10', reps: '5'),
          RawSet(weight: '40', reps: '8'),
        ]),
        [satz(40, 8)],
      );
    });

    test('Unendlich als Gewicht wird abgelehnt', () {
      // Swifts Double("inf") ergibt Unendlich, Darts double.tryParse kennt
      // dafür die Schreibweise "Infinity". Beide Schreibweisen gehören
      // verworfen: Eine unendliche Last macht jede Tonnage unbrauchbar.
      expect(
        uebrig([
          RawSet(weight: 'inf', reps: '5'),
          RawSet(weight: 'Infinity', reps: '5'),
          RawSet(weight: '-Infinity', reps: '5'),
          RawSet(weight: '40', reps: '8'),
        ]),
        [satz(40, 8)],
      );
    });

    test('Keine Zahl als Gewicht wird abgelehnt', () {
      // double.tryParse('NaN') liefert in Dart NaN statt null. Ein NaN-Gewicht
      // vergiftet jede Summe lautlos: volumeKg wäre danach NaN, und das sieht
      // man der Zahl auf der Karte nicht an.
      expect(
        uebrig([
          RawSet(weight: 'NaN', reps: '5'),
          RawSet(weight: '40', reps: '8'),
        ]),
        [satz(40, 8)],
      );
    });

    test('Zwei Trennzeichen im Gewicht werden abgelehnt', () {
      // "42,5,0" wird zu "42.5.0" und ist in beiden Sprachen keine Zahl.
      expect(
        uebrig([
          RawSet(weight: '42,5,0', reps: '5'),
          RawSet(weight: '40', reps: '8'),
        ]),
        [satz(40, 8)],
      );
    });

    test('Eine gebrochene Wiederholungszahl wird abgelehnt', () {
      // Wiederholungen sind ganze Zahlen. Weder Swifts Int("8.5") noch Darts
      // int.tryParse('8.5') nehmen das an — und 8 daraus zu machen hieße
      // raten.
      expect(
        uebrig([
          RawSet(weight: '40', reps: '8.5'),
          RawSet(weight: '40', reps: '8'),
        ]),
        [satz(40, 8)],
      );
    });

    test('Ein ausdrückliches Pluszeichen stört nicht', () {
      // Swifts Int("+8") und Darts int.tryParse('+8') ergeben beide 8.
      expect(uebrig([RawSet(weight: '+40', reps: '+8')]), [satz(40, 8)]);
    });
  });

  group('RawSet: == und hashCode', () {
    test('zwei gleich eingetippte Sätze sind gleich', () {
      const einer = RawSet(weight: '42,5', reps: '8');
      const anderer = RawSet(weight: '42,5', reps: '8');

      expect(einer, equals(anderer));
      expect({einer, anderer}, hasLength(1));
    });

    test('verschiedener Text ist ein anderer Satz', () {
      // Bewusst auf dem Text, nicht auf der Zahl: "42,5" und "42.5" sind
      // dasselbe Gewicht, aber nicht dieselbe Eingabe. Geprüft wird hier der
      // Eingabezustand des Formulars.
      const kommaSchreibweise = RawSet(weight: '42,5', reps: '8');
      const punktSchreibweise = RawSet(weight: '42.5', reps: '8');

      expect(kommaSchreibweise, isNot(equals(punktSchreibweise)));
      expect(
        kommaSchreibweise,
        isNot(equals(const RawSet(weight: '42,5', reps: '7'))),
      );
    });
  });
}
