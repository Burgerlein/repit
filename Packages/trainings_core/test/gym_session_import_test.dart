import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `GymSessionImport.plan` — **die eine Stelle, an der entschieden
/// wird, was eine Übernahme schreiben darf** (#59 Teil 1, mit #482).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte
/// 3 und 4, **ohne** den späteren Code gesehen zu haben.
///
/// ## Worum es geht
///
/// `GymRepository.legeAb` ersetzt eine Sitzung, wenn Tag und Workout
/// gleich sind, und fragt nicht, woher die vorhandene stammt. Beim
/// Nachtragen eines eigenen Trainings ist das richtig. Bei einer Übernahme
/// aus der alten App wäre es **Datenverlust ohne Meldung**: Das iPhone ist
/// Tims einzige Kopie, und ein im Neubau eingetragenes Training trägt Satz-
/// Uhrzeiten und Aufwärmen, die die alte App gar nicht kennt. Der Planer
/// legt fest, dass eine Übernahme **nur dazuschreibt**: Was schon da ist,
/// bleibt, gleich ob es selbst eingetragen oder früher übernommen wurde.
///
/// Der Kern sagt es an seiner Stelle schon so (`GymSessionMerge.merge`: das
/// Vorhandene gewinnt); der letzte Block unten bindet den Planer an genau
/// diese Regel, damit beide nicht auseinanderlaufen.
///
/// ## Entscheidung des Test-Agenten, nicht von Tim
///
/// Ohne Herkunftsspalte weiß die Ablage nicht, ob die Sitzung, die im Weg
/// steht, selbst eingetragen oder früher übernommen wurde. Deshalb heißt der
/// Grund [GymImportSkipReason.dayAndWorkoutTaken] und **behauptet kein
/// „eigen"**.
///
/// Alle Zeitpunkte sind UTC und erfunden, im Jahr 2099. Im Januar gilt
/// Berliner Winterzeit (UTC+1): 09:00 UTC ist 10:00 Berliner Zeit,
/// 23:30 UTC ist 00:30 des **Folgetages**. Von Hand ausgerechnet, nicht über
/// `BerlinCalendar` erzeugt.
void main() {
  /// Vormittag des 14.01.2099, Berliner Zeit.
  final tag14 = DateTime.utc(2099, 1, 14, 9);

  /// Später am selben Berliner Tag (14.01., 19:00 Berliner Zeit).
  final tag14Abend = DateTime.utc(2099, 1, 14, 18);

  /// 23:30 UTC am 14.01. = 00:30 Berliner Zeit am **15.01.**
  final tag15Nacht = DateTime.utc(2099, 1, 14, 23, 30);

  /// Der Berliner Tagesbeginn des 15.01. — so schreibt das Dashboard.
  final tag15Beginn = DateTime.utc(2099, 1, 14, 23);

  /// 22:30 UTC am 14.01. = 23:30 Berliner Zeit am 14.01.
  final tag14Spaet = DateTime.utc(2099, 1, 14, 22, 30);

  final tag16 = DateTime.utc(2099, 1, 16, 9);

  ImportedSession sitzung(
    String id,
    DateTime wann, {
    Workout? workout = Workout.a,
    List<ImportedExercise>? uebungen,
    WarmUp? aufwaermen,
  }) => ImportedSession(
    id: id,
    date: wann,
    workout: workout,
    minutes: null,
    note: null,
    warmUp: aufwaermen,
    exercises:
        uebungen ??
        [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 60, reps: 10)],
          ),
        ],
  );

  List<String> ids(Iterable<ImportedSession> sitzungen) =>
      sitzungen.map((s) => s.id).toList();

  Map<String, GymImportSkipReason> gruende(GymImportPlan plan) => {
    for (final s in plan.skipped) s.session.id: s.reason,
  };

  group('plan: nichts da, alles darf geschrieben werden', () {
    test('leere Ablage: alles wird geschrieben, nichts übersprungen', () {
      final neu = [
        sitzung('N1', tag14),
        sitzung('N2', tag16, workout: Workout.b),
      ];

      final plan = GymSessionImport.plan(existing: const [], incoming: neu);

      expect(ids(plan.toWrite), ['N1', 'N2']);
      expect(plan.skipped, isEmpty);
    });

    test('nichts in der Datei: nichts zu tun, kein Fehler', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E1', tag14)],
        incoming: const [],
      );

      expect(plan.toWrite, isEmpty);
      expect(plan.skipped, isEmpty);
    });

    test('Die Reihenfolge der Datei bleibt in `toWrite` erhalten', () {
      final neu = [
        sitzung('Z', tag16, workout: Workout.b),
        sitzung('A', tag14),
        sitzung('M', tag14, workout: Workout.c),
      ];

      final plan = GymSessionImport.plan(existing: const [], incoming: neu);

      expect(ids(plan.toWrite), ['Z', 'A', 'M']);
    });

    test('Die geschriebenen Sitzungen sind die der Datei, unverändert', () {
      // Nichts wird erfunden und nichts umgeformt: weder ein Aufwärmen noch
      // eine Satz-Uhrzeit noch ein anderes Workout.
      final neu = sitzung('N1', tag14, workout: null);

      final plan = GymSessionImport.plan(existing: const [], incoming: [neu]);

      expect(plan.toWrite.single, neu);
      expect(plan.toWrite.single.warmUp, isNull);
      expect(plan.toWrite.single.workout, isNull);
      expect(plan.toWrite.single.exercises.single.sets.single.recordedAt,
          isNull);
    });
  });

  group('plan: dieselbe Kennung — schon übernommen', () {
    test('gleiche Kennung: übersprungen als `alreadyPresent`', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('S1', tag14)],
        incoming: [sitzung('S1', tag14)],
      );

      expect(plan.toWrite, isEmpty);
      expect(gruende(plan), {'S1': GymImportSkipReason.alreadyPresent});
    });

    test('die Kennung entscheidet, nicht der Inhalt: gleiche Kennung mit '
        'anderen Sätzen wird **nicht** nachgezogen', () {
      // Ohne Herkunft ließe sich nicht sagen, ob die vorhandene Zeile seit
      // der Übernahme von Hand geändert wurde. Eine Übernahme schreibt nur
      // dazu und ersetzt nie.
      final vorhanden = sitzung(
        'S1',
        tag14,
        uebungen: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 80, reps: 5)],
          ),
        ],
      );
      final geaendert = sitzung(
        'S1',
        tag14,
        uebungen: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 20, reps: 20)],
          ),
        ],
      );

      final plan = GymSessionImport.plan(
        existing: [vorhanden],
        incoming: [geaendert],
      );

      expect(plan.toWrite, isEmpty);
      expect(gruende(plan), {'S1': GymImportSkipReason.alreadyPresent});
    });

    test('gleiche Kennung an einem anderen Tag: ebenfalls `alreadyPresent`', () {
      // Der Primärschlüssel der Tabelle ist die Kennung. Ein Schreibversuch
      // würfe — hier wird er gar nicht erst geplant.
      final plan = GymSessionImport.plan(
        existing: [sitzung('S1', tag14)],
        incoming: [sitzung('S1', tag16, workout: Workout.b)],
      );

      expect(plan.toWrite, isEmpty);
      expect(gruende(plan), {'S1': GymImportSkipReason.alreadyPresent});
    });

    test('die Kennung schlägt den Tag: trifft beides zu, steht dort '
        '`alreadyPresent`', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('S1', tag14)],
        incoming: [sitzung('S1', tag14)],
      );

      expect(
        plan.skipped.single.reason,
        GymImportSkipReason.alreadyPresent,
        reason:
            'Wer zum zweiten Mal übernimmt, soll „schon da" lesen und nicht '
            '„Tag belegt" — das klänge nach einem Konflikt',
      );
    });
  });

  group('plan: #482 — ein Training, das schon dasteht, wird nie überschrieben',
      () {
    test('gleicher Berliner Tag, gleiches Workout, andere Kennung: '
        'übersprungen, das Vorhandene gewinnt', () {
      final eigen = sitzung('EIGEN', tag14);
      final alt = sitzung('ALT', tag14Abend);

      final plan = GymSessionImport.plan(existing: [eigen], incoming: [alt]);

      expect(plan.toWrite, isEmpty, reason: 'Die Übernahme schreibt nichts');
      expect(gruende(plan), {'ALT': GymImportSkipReason.dayAndWorkoutTaken});
    });

    test('der Zeitpunkt macht keinen Unterschied: auch eine **neuere** '
        'Übernahme verdrängt nichts', () {
      // Eine Regel „der Neuere gewinnt" wäre falsch: Das Dashboard schreibt
      // den Tagesbeginn, ein eigener Eintrag trägt die Uhrzeit — der
      // Übernommene wäre fast immer der „ältere", aber nie der bessere.
      final eigen = sitzung('EIGEN', tag14);
      final spaeter = sitzung('ALT', tag14Abend);
      final frueher = sitzung('ALT2', DateTime.utc(2099, 1, 13, 23, 30));

      for (final alt in [spaeter, frueher]) {
        final plan = GymSessionImport.plan(existing: [eigen], incoming: [alt]);
        // `frueher` liegt in Berlin am 14.01. um 00:30 — derselbe Tag.
        expect(plan.toWrite, isEmpty, reason: '${alt.id}');
      }
    });

    test('der Berliner Tag zählt, nicht der UTC-Kalendertag (Richtung 1): '
        '23:30 UTC ist schon der Folgetag', () {
      // 14.01. 09:00 UTC (Berlin 14.01.) gegen 14.01. 23:30 UTC (Berlin
      // 15.01.): verschiedene Berliner Tage, obwohl derselbe UTC-Tag.
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14)],
        incoming: [sitzung('N', tag15Nacht)],
      );

      expect(ids(plan.toWrite), ['N']);
      expect(plan.skipped, isEmpty);
    });

    test('der Berliner Tag zählt, nicht der UTC-Kalendertag (Richtung 2): '
        'zwei UTC-Tage, ein Berliner Tag', () {
      // Tagesbeginn des 15.01. (14.01. 23:00 UTC) und 00:30 Berliner Zeit
      // am 15.01. (14.01. 23:30 UTC) sind derselbe Berliner Tag.
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag15Nacht)],
        incoming: [sitzung('N', tag15Beginn)],
      );

      expect(plan.toWrite, isEmpty);
      expect(gruende(plan), {'N': GymImportSkipReason.dayAndWorkoutTaken});
    });

    test('23:30 Berliner Zeit und der Tagesbeginn des nächsten Tages sind '
        'verschieden', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14Spaet)],
        incoming: [sitzung('N', tag15Beginn)],
      );

      expect(ids(plan.toWrite), ['N']);
    });

    test('anderes Workout am selben Tag: kein Konflikt', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14)],
        incoming: [sitzung('N', tag14, workout: Workout.b)],
      );

      expect(ids(plan.toWrite), ['N']);
      expect(plan.skipped, isEmpty);
    });

    test('anderer Tag, gleiches Workout: kein Konflikt', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14)],
        incoming: [sitzung('N', tag16)],
      );

      expect(ids(plan.toWrite), ['N']);
    });

    test('„kein Workout" ist ein eigener Schlüssel: gegen Gym A kein Konflikt',
        () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14, workout: Workout.a)],
        incoming: [sitzung('N', tag14, workout: null)],
      );

      expect(ids(plan.toWrite), ['N']);
    });

    test('„kein Workout" gegen „kein Workout" am selben Tag: Konflikt', () {
      // Die Tabelle trägt das nicht über `UNIQUE` (SQLite hält zwei `NULL`
      // für verschieden). Der Planer muss es selbst wissen.
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14, workout: null)],
        incoming: [sitzung('N', tag14, workout: null)],
      );

      expect(plan.toWrite, isEmpty);
      expect(gruende(plan), {'N': GymImportSkipReason.dayAndWorkoutTaken});
    });

    test('der Fall aus dem Ticket, mit Tims Sätzen: Das Vorhandene wird nicht '
        'angefasst, auch nicht als Objekt in `toWrite` ersetzt', () {
      final eigen = sitzung(
        'EIGEN',
        tag14,
        aufwaermen: const WarmUpDone(kind: WarmUpKind.bike, minutes: 8),
        uebungen: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [
              CompletedSet(
                weight: 62.5,
                reps: 9,
                recordedAt: DateTime.utc(2099, 1, 14, 9, 12),
              ),
            ],
          ),
        ],
      );
      final alt = sitzung('ALT', tag14);

      final plan = GymSessionImport.plan(existing: [eigen], incoming: [alt]);

      expect(
        plan.toWrite.map((s) => s.id),
        isNot(contains('EIGEN')),
        reason: 'Der Planer schlägt nie vor, das Vorhandene zu schreiben',
      );
      expect(plan.toWrite, isEmpty);
      // Eingabe unverändert:
      expect(eigen.warmUp, const WarmUpDone(kind: WarmUpKind.bike, minutes: 8));
    });

    test('auch ein früher Übernommenes wird nicht verdrängt — der Grund '
        'behauptet nicht, es sei „eigen"', () {
      // Der Planer kann Herkunft nicht unterscheiden. Beide Fälle werden
      // gleich und vorsichtig behandelt; der Name des Grundes sagt nur, was
      // sicher ist: Tag und Workout sind belegt.
      final plan = GymSessionImport.plan(
        existing: [sitzung('FRUEHER-UEBERNOMMEN', tag14)],
        incoming: [sitzung('NEUE-FASSUNG', tag14)],
      );

      expect(plan.toWrite, isEmpty);
      expect(
        plan.skipped.single.reason,
        GymImportSkipReason.dayAndWorkoutTaken,
      );
    });

    test('jede übersprungene Sitzung trägt die Sitzung selbst, damit der '
        'Schirm Tag und Workout nennen kann', () {
      final alt = sitzung('ALT', tag14);

      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14)],
        incoming: [alt],
      );

      expect(plan.skipped.single.session, alt);
    });
  });

  group('plan: gemischte Datei', () {
    test('jede Sitzung bekommt genau ein Schicksal: geschrieben oder '
        'übersprungen, nie beides, nie keines', () {
      final vorhanden = [
        sitzung('E1', tag14),
        sitzung('E2', tag16, workout: Workout.b),
      ];
      final neu = [
        sitzung('E1', tag14), // schon da (Kennung)
        sitzung('X1', tag14Abend), // Tag belegt
        sitzung('N1', tag14, workout: Workout.c), // neu
        sitzung('N2', DateTime.utc(2099, 2, 1, 9)), // neu
      ];

      final plan = GymSessionImport.plan(existing: vorhanden, incoming: neu);

      expect(ids(plan.toWrite), ['N1', 'N2']);
      expect(gruende(plan), {
        'E1': GymImportSkipReason.alreadyPresent,
        'X1': GymImportSkipReason.dayAndWorkoutTaken,
      });
      expect(
        plan.toWrite.length + plan.skipped.length,
        neu.length,
        reason: 'Es geht keine Sitzung verloren, ohne dass sie genannt wird',
      );
    });

    test('zweimal derselbe Lauf: beim zweiten ist alles `alreadyPresent`', () {
      final neu = [
        sitzung('N1', tag14),
        sitzung('N2', tag16, workout: Workout.b),
      ];

      final erster = GymSessionImport.plan(existing: const [], incoming: neu);
      final zweiter = GymSessionImport.plan(
        existing: erster.toWrite,
        incoming: neu,
      );

      expect(zweiter.toWrite, isEmpty);
      expect(zweiter.skipped.map((s) => s.reason).toSet(), {
        GymImportSkipReason.alreadyPresent,
      });
      expect(zweiter.skipped.length, neu.length);
    });
  });

  group('plan: Dubletten innerhalb der Datei', () {
    test('zwei Sitzungen mit demselben Tag und Workout: die mit dem späteren '
        'Zeitpunkt gewinnt, die andere heißt `duplicateInFile`', () {
      final frueh = sitzung('FRUEH', tag14);
      final spaet = sitzung('SPAET', tag14Abend);

      final plan = GymSessionImport.plan(
        existing: const [],
        incoming: [frueh, spaet],
      );

      expect(ids(plan.toWrite), ['SPAET']);
      expect(gruende(plan), {'FRUEH': GymImportSkipReason.duplicateInFile});
    });

    test('die Reihenfolge in der Datei ändert das Ergebnis nicht', () {
      final frueh = sitzung('FRUEH', tag14);
      final spaet = sitzung('SPAET', tag14Abend);

      final vorwaerts = GymSessionImport.plan(
        existing: const [],
        incoming: [frueh, spaet],
      );
      final rueckwaerts = GymSessionImport.plan(
        existing: const [],
        incoming: [spaet, frueh],
      );

      expect(ids(vorwaerts.toWrite), ids(rueckwaerts.toWrite));
      expect(gruende(vorwaerts), gruende(rueckwaerts));
    });

    test('bei gleichem Zeitpunkt entscheidet die größere Kennung — nicht die '
        'Reihenfolge', () {
      // Beide mit dem Tagesbeginn, so wie das Dashboard sie schreibt.
      final a = sitzung('AAA', tag15Beginn);
      final b = sitzung('BBB', tag15Beginn);

      for (final eingabe in [
        [a, b],
        [b, a],
      ]) {
        final plan = GymSessionImport.plan(existing: const [], incoming: eingabe);
        expect(ids(plan.toWrite), ['BBB']);
        expect(gruende(plan), {'AAA': GymImportSkipReason.duplicateInFile});
      }
    });

    test('dieselbe Kennung zweimal in der Datei: einmal geschrieben', () {
      final plan = GymSessionImport.plan(
        existing: const [],
        incoming: [sitzung('S1', tag14), sitzung('S1', tag14)],
      );

      expect(ids(plan.toWrite), ['S1']);
      expect(plan.skipped.length, 1);
      expect(plan.skipped.single.reason, GymImportSkipReason.duplicateInFile);
    });

    test('ist die Kennung schon in der Ablage, sind beide Fassungen '
        '`alreadyPresent`', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('S1', tag14)],
        incoming: [sitzung('S1', tag14), sitzung('S1', tag14)],
      );

      expect(plan.toWrite, isEmpty);
      expect(
        plan.skipped.map((s) => s.reason).toSet(),
        {GymImportSkipReason.alreadyPresent},
      );
      expect(plan.skipped.length, 2);
    });

    test('trifft die Dublette zusätzlich auf Vorhandenes, sind beide '
        '`dayAndWorkoutTaken` — das Vorhandene gewinnt vor jeder Auswahl in '
        'der Datei', () {
      final plan = GymSessionImport.plan(
        existing: [sitzung('E', tag14)],
        incoming: [sitzung('A1', tag14), sitzung('A2', tag14Abend)],
      );

      expect(plan.toWrite, isEmpty);
      expect(
        plan.skipped.map((s) => s.reason).toSet(),
        {GymImportSkipReason.dayAndWorkoutTaken},
      );
    });

    test('verschiedene Workouts am selben Tag sind keine Dubletten', () {
      final plan = GymSessionImport.plan(
        existing: const [],
        incoming: [
          sitzung('A', tag14),
          sitzung('B', tag14, workout: Workout.b),
          sitzung('K', tag14, workout: null),
        ],
      );

      expect(ids(plan.toWrite), ['A', 'B', 'K']);
      expect(plan.skipped, isEmpty);
    });
  });

  group('plan: dieselbe Regel wie `GymSessionMerge.merge`', () {
    // Der Kern sagt an seiner Stelle schon: „Treffen beide auf denselben
    // Berliner Tag und dasselbe Workout, gewinnt das eigene." Der Planer
    // darf davon nie abweichen — sonst gäbe es zwei Regeln, und die
    // Übernahme folgte der falschen. Verglichen wird das Ergebnis, nicht die
    // Bauform.
    final faelle = <String, (ImportedSession, ImportedSession)>{
      'gleicher Tag, gleiches Workout': (
        sitzung('E', tag14),
        sitzung('N', tag14Abend),
      ),
      'gleicher Berliner Tag über die UTC-Grenze': (
        sitzung('E', tag15Nacht),
        sitzung('N', tag15Beginn),
      ),
      'Berliner Tagesgrenze zwischen beiden': (
        sitzung('E', tag14Spaet),
        sitzung('N', tag15Beginn),
      ),
      'anderes Workout': (
        sitzung('E', tag14),
        sitzung('N', tag14, workout: Workout.b),
      ),
      'kein Workout gegen Workout': (
        sitzung('E', tag14, workout: null),
        sitzung('N', tag14),
      ),
      'kein Workout gegen kein Workout': (
        sitzung('E', tag14, workout: null),
        sitzung('N', tag14Abend, workout: null),
      ),
      'anderer Tag': (sitzung('E', tag14), sitzung('N', tag16)),
    };

    for (final eintrag in faelle.entries) {
      test('${eintrag.key}: schreibt genau dann nichts, wenn `merge` '
          'zusammenlegt', () {
        final (vorhanden, neu) = eintrag.value;

        final zusammengelegt =
            GymSessionMerge.merge(logged: [vorhanden], imported: [neu]).length ==
            1;
        final plan = GymSessionImport.plan(
          existing: [vorhanden],
          incoming: [neu],
        );

        expect(
          plan.toWrite.isEmpty,
          zusammengelegt,
          reason:
              '`merge` ${zusammengelegt ? "legt zusammen" : "lässt beide stehen"}'
              ' — der Planer muss dasselbe sagen',
        );
        if (zusammengelegt) {
          expect(
            GymSessionMerge.merge(logged: [vorhanden], imported: [neu]).single,
            vorhanden,
            reason: 'und das Vorhandene ist, was dort gewinnt',
          );
        }
      });
    }
  });
}
