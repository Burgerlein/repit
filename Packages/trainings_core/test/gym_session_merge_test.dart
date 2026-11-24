import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `GymSessionMerge`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymSessionMerge.swift`.
///
/// Für die Swift-Fassung gibt es **keine** Tests; diese hier sind aus der
/// Quelle und ihren Doc-Kommentaren neu entworfen. Was dort zugesagt wird:
///
/// - **Gleicher Berliner Tag und gleiches Workout: das eigene gewinnt.** Es
///   ist der neuere Stand. Genau der Fall, der beim Nachtragen eines
///   Trainings entsteht, das schon im Dashboard stand — ohne diese Regel
///   stünde es zweimal da, mit verschiedenen Zahlen.
/// - **„Kein Workout" ist ein eigener Schlüssel und nicht dasselbe wie
///   Gym A.** Der Dashboard-Import erzeugt solche Sitzungen, und sie einem
///   Workout zuzuschlagen hieße raten.
/// - **Neueste zuerst; bei gleichem Zeitstempel entscheidet der
///   Workout-Code.** Eine Liste, die bei jedem Start anders aussieht, ist
///   kaputt — deshalb steht der Determinismus hier ausdrücklich als Testfall.
/// - **`history` liefert Übungs-ID → Satzlisten, neueste Sitzung zuerst** —
///   genau die Form, die `Progression.suggest` erwartet. Eine falsch
///   sortierte Historie liefert lautlos falsche Vorschläge: Der Vorschlag
///   bezöge sich auf die ältere Last.
///
/// **Der Tagesschlüssel läuft über den Berliner Tagesbeginn, nicht über den
/// UTC-Kalendertag.** Zwei Zeitpunkte desselben Berliner Tages können in UTC
/// auf verschiedenen Kalendertagen liegen und umgekehrt; beide Richtungen
/// werden unten geprüft, in Sommer- und in Winterzeit.
///
/// Alle Zeitpunkte sind als UTC geschrieben, mit der gemeinten Berliner
/// Wanduhrzeit im Kommentar — bewusst von Hand ausgerechnet und nicht über
/// `BerlinCalendar` erzeugt, damit der Test nicht dieselbe Rechnung benutzt,
/// die er absichert. September 2026 ist Sommerzeit (UTC+2), November 2026
/// Winterzeit (UTC+1).
///
/// Alle Zahlen sind erfunden.
void main() {
  CompletedSet satz(double gewicht, int wiederholungen) =>
      CompletedSet(weight: gewicht, reps: wiederholungen);

  ImportedSession sitzung(
    String id,
    DateTime wann,
    Workout? workout, [
    List<ImportedExercise> uebungen = const [],
  ]) => ImportedSession(
    id: id,
    date: wann,
    workout: workout,
    minutes: null,
    note: null,
    exercises: uebungen,
  );

  List<String> ids(List<ImportedSession> sitzungen) =>
      sitzungen.map((s) => s.id).toList();

  group('merge: zusammenführen und sortieren', () {
    test('Beide Listen stehen zusammen, neueste zuerst', () {
      final eigene = [
        sitzung(
          'eigen',
          DateTime.utc(2026, 9, 20, 16),
          Workout.a,
        ), // Berlin 18:00
      ];
      final uebernommene = [
        sitzung(
          'import-neu',
          DateTime.utc(2026, 9, 21, 22),
          Workout.c,
        ), // Berlin 22.09. 00:00
        sitzung(
          'import-alt',
          DateTime.utc(2026, 9, 17, 22),
          Workout.b,
        ), // Berlin 18.09. 00:00
      ];

      final zusammen = GymSessionMerge.merge(
        logged: eigene,
        imported: uebernommene,
      );

      expect(ids(zusammen), ['import-neu', 'eigen', 'import-alt']);
    });

    test('Am selben Tag und beim selben Workout gewinnt das eigene Training', () {
      // Beide Quellen beschreiben dieselbe Einheit: in der App abgeschlossen
      // und später die alte Exportdatei eingelesen. Der eigene Eintrag ist
      // der neuere Stand — zwei Zeilen für ein Training wären schlicht falsch.
      final eigene = [
        sitzung(
          'eigen',
          DateTime.utc(2026, 9, 20, 16, 30), // Berlin 18:30
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(42.5, 8)]),
          ],
        ),
      ];
      final uebernommene = [
        sitzung(
          'import',
          DateTime.utc(2026, 9, 19, 22), // Berlin 20.09. 00:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
          ],
        ),
      ];

      final zusammen = GymSessionMerge.merge(
        logged: eigene,
        imported: uebernommene,
      );

      expect(zusammen, hasLength(1));
      expect(zusammen.first.id, 'eigen');
      expect(zusammen.first.exercises.first.sets, [satz(42.5, 8)]);
    });

    test('Zwei verschiedene Workouts am selben Tag bleiben beide stehen', () {
      // Gym A morgens und Gym C abends ist zulässig und darf nicht zu einem
      // Training zusammenfallen.
      final eigene = [
        sitzung(
          'eigen-a',
          DateTime.utc(2026, 9, 20, 17),
          Workout.a,
        ), // Berlin 19:00
      ];
      final uebernommene = [
        sitzung(
          'import-c',
          DateTime.utc(2026, 9, 19, 22),
          Workout.c,
        ), // Berlin 20.09. 00:00
      ];

      final zusammen = GymSessionMerge.merge(
        logged: eigene,
        imported: uebernommene,
      );

      expect(zusammen, hasLength(2));
      expect(ids(zusammen).toSet(), {'eigen-a', 'import-c'});
    });

    test(
      'Ein übernommenes Training ohne Workout bleibt neben dem eigenen stehen',
      () {
        // Das Dashboard führt nicht zu jedem Eintrag ein Workout. „Kein
        // Workout" ist nicht dasselbe wie Gym A — wegwerfen hieße raten.
        final eigene = [
          sitzung(
            'eigen-a',
            DateTime.utc(2026, 9, 20, 17),
            Workout.a,
          ), // Berlin 19:00
        ];
        final uebernommene = [
          sitzung(
            'import-ohne',
            DateTime.utc(2026, 9, 19, 22),
            null,
          ), // Berlin 20.09. 00:00
        ];

        final zusammen = GymSessionMerge.merge(
          logged: eigene,
          imported: uebernommene,
        );

        expect(zusammen, hasLength(2));
        expect(ids(zusammen).toSet(), {'eigen-a', 'import-ohne'});
      },
    );

    test('Zwei Trainings ohne Workout am selben Tag fallen zusammen', () {
      // „Kein Workout" ist ein eigener Schlüssel — aber ein einziger. Zwei
      // Einträge ohne Workout am selben Tag sind dieselbe Einheit, und auch
      // hier gewinnt das eigene.
      final eigene = [
        sitzung(
          'eigen-ohne',
          DateTime.utc(2026, 9, 20, 17),
          null,
        ), // Berlin 19:00
      ];
      final uebernommene = [
        sitzung(
          'import-ohne',
          DateTime.utc(2026, 9, 19, 22),
          null,
        ), // Berlin 20.09. 00:00
      ];

      final zusammen = GymSessionMerge.merge(
        logged: eigene,
        imported: uebernommene,
      );

      expect(ids(zusammen), ['eigen-ohne']);
    });

    test('Leere Listen auf einer oder beiden Seiten ergeben kein Problem', () {
      expect(
        GymSessionMerge.merge(logged: const [], imported: const []),
        isEmpty,
      );

      final nurUebernommen = sitzung(
        'import',
        DateTime.utc(2026, 9, 19, 22), // Berlin 20.09. 00:00
        Workout.b,
      );
      expect(
        ids(
          GymSessionMerge.merge(logged: const [], imported: [nurUebernommen]),
        ),
        ['import'],
      );

      final nurEigen = sitzung(
        'eigen',
        DateTime.utc(2026, 9, 20, 16), // Berlin 18:00
        Workout.b,
      );
      expect(
        ids(GymSessionMerge.merge(logged: [nurEigen], imported: const [])),
        ['eigen'],
      );
    });
  });

  group('merge: der Tag ist der Berliner Tag', () {
    test('Derselbe Berliner Tag zählt als ein Tag, auch über die UTC-Datumsgrenze hinweg', () {
      // Sommerzeit, UTC+2:
      //   20.09. 22:30 UTC ist Berlin 21.09. 00:30 — kurz nach Mitternacht.
      //   21.09. 21:30 UTC ist Berlin 21.09. 23:30 — später Abend desselben
      //   Berliner Tages.
      // In UTC sind das zwei Kalendertage, in Berlin einer. Über den
      // UTC-Kalendertag geschlüsselt stünde dasselbe Training zweimal da.
      final eigene = [
        sitzung(
          'eigen-spaetabends',
          DateTime.utc(2026, 9, 21, 21, 30),
          Workout.a,
        ),
      ];
      final uebernommene = [
        sitzung(
          'import-nachMitternacht',
          DateTime.utc(2026, 9, 20, 22, 30),
          Workout.a,
        ),
      ];

      final zusammen = GymSessionMerge.merge(
        logged: eigene,
        imported: uebernommene,
      );

      expect(zusammen, hasLength(1));
      expect(zusammen.first.id, 'eigen-spaetabends');
    });

    test(
      'Zwei Berliner Tage bleiben getrennt, auch innerhalb desselben UTC-Tages',
      () {
        // Die Gegenprobe, Sommerzeit:
        //   21.09. 21:30 UTC ist Berlin 21.09. 23:30.
        //   21.09. 22:30 UTC ist Berlin 22.09. 00:30 — schon der Folgetag.
        // Eine Stunde Abstand, derselbe UTC-Kalendertag, aber zwei Berliner
        // Tage und damit zwei Trainings.
        final eigene = [
          sitzung('eigen-21ster', DateTime.utc(2026, 9, 21, 21, 30), Workout.a),
        ];
        final uebernommene = [
          sitzung(
            'import-22ster',
            DateTime.utc(2026, 9, 21, 22, 30),
            Workout.a,
          ),
        ];

        final zusammen = GymSessionMerge.merge(
          logged: eigene,
          imported: uebernommene,
        );

        expect(zusammen, hasLength(2));
        // Neueste zuerst — und das ist der übernommene Eintrag.
        expect(ids(zusammen), ['import-22ster', 'eigen-21ster']);
      },
    );

    test(
      'In der Winterzeit gilt dieselbe Tagesgrenze, nur eine Stunde versetzt',
      () {
        // Winterzeit, UTC+1:
        //   16.11. 23:30 UTC ist Berlin 17.11. 00:30.
        //   17.11. 22:30 UTC ist Berlin 17.11. 23:30.
        // Derselbe Berliner Tag. Wer den Versatz fest auf zwei Stunden
        // verdrahtet, fällt genau hier durch.
        final eigene = [
          sitzung(
            'eigen-spaetabends',
            DateTime.utc(2026, 11, 17, 22, 30),
            Workout.c,
          ),
        ];
        final uebernommene = [
          sitzung(
            'import-nachMitternacht',
            DateTime.utc(2026, 11, 16, 23, 30),
            Workout.c,
          ),
        ];

        final zusammen = GymSessionMerge.merge(
          logged: eigene,
          imported: uebernommene,
        );

        expect(zusammen, hasLength(1));
        expect(zusammen.first.id, 'eigen-spaetabends');
      },
    );
  });

  group('merge: die Reihenfolge ist bei jedem Start dieselbe', () {
    test('Bei gleichem Zeitstempel entscheidet der Workout-Code', () {
      // Vier Trainings mit demselben Zeitstempel. Ohne zweites
      // Sortierkriterium hinge die Reihenfolge an der Laufreihenfolge einer
      // Map — und die Liste sähe bei jedem Start anders aus.
      // Codes: '' (kein Workout) < 'A' < 'Legs' < 'Push'.
      final gleicherZeitpunkt = DateTime.utc(2026, 9, 21, 16); // Berlin 18:00
      final uebernommene = [
        sitzung('push', gleicherZeitpunkt, Workout.push),
        sitzung('ohne', gleicherZeitpunkt, null),
        sitzung('legs', gleicherZeitpunkt, Workout.legs),
        sitzung('a', gleicherZeitpunkt, Workout.a),
      ];

      final zusammen = GymSessionMerge.merge(
        logged: const [],
        imported: uebernommene,
      );

      expect(ids(zusammen), ['ohne', 'a', 'legs', 'push']);
    });

    test('Die Reihenfolge der Eingabelisten ändert das Ergebnis nicht', () {
      final gleicherZeitpunkt = DateTime.utc(2026, 9, 21, 16); // Berlin 18:00
      final einsHerum = GymSessionMerge.merge(
        logged: [
          sitzung('a', gleicherZeitpunkt, Workout.a),
          sitzung('c', gleicherZeitpunkt, Workout.c),
        ],
        imported: [
          sitzung('b', gleicherZeitpunkt, Workout.b),
          sitzung('d', gleicherZeitpunkt, Workout.d),
        ],
      );
      final andersHerum = GymSessionMerge.merge(
        logged: [
          sitzung('c', gleicherZeitpunkt, Workout.c),
          sitzung('a', gleicherZeitpunkt, Workout.a),
        ],
        imported: [
          sitzung('d', gleicherZeitpunkt, Workout.d),
          sitzung('b', gleicherZeitpunkt, Workout.b),
        ],
      );

      expect(ids(einsHerum), ['a', 'b', 'c', 'd']);
      expect(ids(andersHerum), ids(einsHerum));
    });
  });

  group('history: Verlauf pro Übung', () {
    test('Der Verlauf bildet die Übungs-ID auf die Satzlisten ab, neueste Sitzung zuerst', () {
      // Genau die Form, die `Progression.suggest` erwartet — sonst schlägt
      // der Vorschlag die alte Last vor.
      final sitzungen = [
        sitzung(
          'neu',
          DateTime.utc(2026, 9, 21, 16), // Berlin 18:00
          Workout.a,
          [
            ImportedExercise(
              exerciseId: 'benchPress',
              sets: [satz(50, 6), satz(50, 5)],
            ),
            ImportedExercise(exerciseId: 'lateralRaise', sets: [satz(12, 15)]),
          ],
        ),
        sitzung(
          'alt',
          DateTime.utc(2026, 9, 13, 22), // Berlin 14.09. 00:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(47.5, 8)]),
          ],
        ),
      ];

      final verlauf = GymSessionMerge.history(sitzungen);

      expect(verlauf['benchPress'], [
        [satz(50, 6), satz(50, 5)],
        [satz(47.5, 8)],
      ]);
      expect(verlauf['lateralRaise'], [
        [satz(12, 15)],
      ]);
      // Was nie trainiert wurde, steht nicht im Verlauf.
      expect(verlauf['pullUp'], isNull);
    });

    test('Eine Übung aus zwei Sitzungen hat zwei Einträge', () {
      final sitzungen = [
        sitzung('neu', DateTime.utc(2026, 9, 21, 16), Workout.c, [
          ImportedExercise(exerciseId: 'pullUp', sets: [satz(0, 8)]),
        ]),
        sitzung('alt', DateTime.utc(2026, 9, 13, 22), Workout.c, [
          ImportedExercise(exerciseId: 'pullUp', sets: [satz(0, 6)]),
        ]),
      ];

      final verlauf = GymSessionMerge.history(sitzungen);

      expect(verlauf['pullUp'], hasLength(2));
      expect(verlauf['pullUp'], [
        [satz(0, 8)],
        [satz(0, 6)],
      ]);
      expect(verlauf.keys, hasLength(1));
    });

    test(
      'Der Verlauf sortiert selbst und hängt nicht an der Eingabereihenfolge',
      () {
        // Darauf kommt es an: Eine falsch sortierte Historie liefert lautlos
        // falsche Vorschläge, ohne dass irgendwo etwas rot wird.
        final alt = sitzung(
          'alt',
          DateTime.utc(2026, 9, 13, 22), // Berlin 14.09. 00:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(45, 8)]),
          ],
        );
        final mittel = sitzung(
          'mittel',
          DateTime.utc(2026, 9, 17, 16), // Berlin 18:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(47.5, 8)]),
          ],
        );
        final neu = sitzung(
          'neu',
          DateTime.utc(2026, 9, 21, 16), // Berlin 18:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(50, 6)]),
          ],
        );

        final erwartet = [
          [satz(50, 6)],
          [satz(47.5, 8)],
          [satz(45, 8)],
        ];

        expect(
          GymSessionMerge.history([alt, mittel, neu])['benchPress'],
          erwartet,
        );
        expect(
          GymSessionMerge.history([neu, alt, mittel])['benchPress'],
          erwartet,
        );
        expect(
          GymSessionMerge.history([mittel, neu, alt])['benchPress'],
          erwartet,
        );
      },
    );

    test('Eine Sitzung ohne Workout steht im Verlauf wie jede andere', () {
      // Der Verlauf fragt nach der Übung, nicht nach dem Workout. Ein
      // übernommenes Training ohne Workout trägt trotzdem Sätze bei.
      final sitzungen = [
        sitzung('ohne-workout', DateTime.utc(2026, 9, 21, 16), null, [
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(50, 6)]),
        ]),
      ];

      final verlauf = GymSessionMerge.history(sitzungen);

      expect(verlauf['benchPress'], [
        [satz(50, 6)],
      ]);
    });

    test('Keine Sitzungen ergeben einen leeren Verlauf', () {
      expect(GymSessionMerge.history(const []), isEmpty);
    });

    test('Eine Sitzung ohne Übungen trägt nichts bei', () {
      final verlauf = GymSessionMerge.history([
        sitzung('leer', DateTime.utc(2026, 9, 21, 16), Workout.a),
      ]);

      expect(verlauf, isEmpty);
    });
  });

  group('Zusammengeführt und ausgewertet', () {
    test('ergibt den Verlauf beider Quellen', () {
      // Der tatsächliche Weg: eigenes Training abschließen, Dashboard-Daten
      // daneben, Vorschlag aus beidem.
      final eigen = GymSessionBuilder.session(
        id: 'eigen',
        date: DateTime.utc(2026, 9, 21, 16, 15), // Berlin 18:15
        workout: Workout.a,
        minutes: 64,
        entries: {
          'benchPress': [RawSet(weight: '50', reps: '6')],
        },
      );
      expect(eigen, isNotNull);

      final uebernommene = [
        sitzung(
          'import',
          DateTime.utc(2026, 9, 13, 22), // Berlin 14.09. 00:00
          Workout.a,
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(47.5, 8)]),
          ],
        ),
      ];

      final zusammen = GymSessionMerge.merge(
        logged: [eigen!],
        imported: uebernommene,
      );
      final verlauf = GymSessionMerge.history(zusammen);

      expect(ids(zusammen), ['eigen', 'import']);
      expect(verlauf['benchPress'], [
        [satz(50, 6)],
        [satz(47.5, 8)],
      ]);
    });
  });
}
