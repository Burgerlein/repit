import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Erweiterungen der Sitzungstypen um das Training** (#532):
/// `ImportedSession.trainingId`/`trainingName`, `GymSessionBuilder` mit
/// `workout: null`, `GymSessionOrder.ordered(…, trainingOrder:)` und
/// `GymSessionMerge.sessionKey`. Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitte 3.1, 4.6, 5.9 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// **Dies ist eine neue Datei neben `gym_session_test.dart`,
/// `gym_session_builder_test.dart` und `gym_session_merge_test.dart` — keine
/// davon wird angefasst.** Die bestehenden bleiben unverändert grün; die
/// Erweiterungen sind **nur additiv** (Spec 3.1).
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Der Verlauf friert ein — die Sitzung speichert
///   den Trainings**namen** zum Zeitpunkt der Sitzung (18.11.2026, #531).
///   Eigene Trainings sind voll einplanbar und mehrere am Tag sind möglich.
/// - **Folgerung aus dem Code (Spec 4.6):** Ohne Eingriff kollidierten zwei
///   verschiedene eigene Trainings am selben Tag — beide haben
///   `workout == null`, der Schlüssel wäre `…-?`, die zweite Sitzung ersetzte
///   die erste. Der Schlüssel ist deshalb
///   `'${dayKey}-${trainingId ?? workout?.code ?? '?'}'`; **für jede
///   bestehende Sitzung bleibt er unverändert.**
/// - **Vorschlag der Spec, hier vorausgesetzt:** `trainingId` ist nur für
///   Trainings **ohne** Enum-Fall gesetzt (4.6, „[Vorschlag zur Form]").
///   Die Tests nageln nur fest, dass der Kern ein hereingereichtes
///   `trainingId` durchreicht und mit in `==`/`hashCode` nimmt, nicht, wer es
///   setzt.
/// - **Festlegung des Test-Agenten:** `GymSessionBuilder` reicht `trainingId`
///   und `trainingName` unverändert durch, auch neben einem `Workout`
///   (Template-Sitzung über den Enum-Weg, Spec 3.2: „`trainingName` wird beim
///   Abschließen geschrieben — auch für Template-Sitzungen").
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// ImportedSession({…bisher…, String? trainingId, String? trainingName})
///                                       // beide in ==/hashCode, Vorgabe null
/// GymSessionBuilder.session({…bisher…, required Workout? workout,
///                            String? trainingId, String? trainingName})
/// GymSessionOrder.ordered(Iterable<String> ids, Workout? workout,
///                         {List<String>? trainingOrder})
/// GymSessionMerge.sessionKey(ImportedSession)  // Signatur unverändert
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **Die Reihenfolge der Übungen einer Sitzung ohne Enum-Fall im
///   `GymSessionBuilder`.** `GymSessionBuilder.session` hat in der Spec 21
///   **keinen** `trainingOrder`-Parameter, `GymSessionOrder.ordered` schon;
///   wie der Builder die Reihenfolge eines Trainings ohne Enum-Fall bekommt,
///   sagt die Spec nicht. Bei `workout == null` und ohne Reihenfolge wäre sie
///   alphabetisch (bestehendes Verhalten von `ordered`). **Gemeldet, nicht
///   entschieden** — hier wird deshalb nur geprüft, dass **alle** Übungen
///   in der Sitzung stehen.
/// - **Zwei Sitzungen mit demselben Zeitstempel und ohne Enum-Fall in
///   `merge`:** Die Sortierung bei gleichem Zeitstempel hängt am
///   Workout-Code; für Trainings ohne Code legt die Spec nichts fest.
/// - **Das Lesen aus der Datenbank** (`GymRepository._lade`, Spec 4.6) —
///   `app/test/data/`.

CompletedSet satz(double kg, int wdh) => CompletedSet(weight: kg, reps: wdh);

ImportedSession sitzung(
  String id,
  DateTime datum, {
  Workout? workout,
  String? trainingId,
  String? trainingName,
  List<ImportedExercise>? exercises,
  int? minutes,
  String? note,
}) => ImportedSession(
  id: id,
  date: datum,
  workout: workout,
  minutes: minutes,
  note: note,
  exercises:
      exercises ??
      [
        ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
      ],
  trainingId: trainingId,
  trainingName: trainingName,
);

List<String> ids(List<ImportedSession> sitzungen) =>
    sitzungen.map((s) => s.id).toList();

void main() {
  // -------------------------------------------------------------------------
  group('ImportedSession trägt trainingId und trainingName', () {
    test('Ohne Angabe sind beide null — bestehende Aufrufe bleiben gültig', () {
      final s = ImportedSession(
        id: 'S1',
        date: DateTime.utc(2027, 2, 10, 9),
        workout: Workout.a,
        minutes: 60,
        note: null,
        exercises: const [],
      );
      expect(s.trainingId, isNull);
      expect(s.trainingName, isNull);
    });

    test('Beide Werte werden getragen', () {
      final s = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        trainingId: '8F3A-ABCD',
        trainingName: 'Kurzhantel zuhause',
      );
      expect(s.trainingId, '8F3A-ABCD');
      expect(s.trainingName, 'Kurzhantel zuhause');
      expect(s.workout, isNull);
    });

    test('Ein Workout und ein Name können nebeneinander stehen', () {
      // Template-Sitzung über den Enum-Weg: `workout` wie bisher, dazu der
      // eingefrorene Name zum Zeitpunkt der Sitzung.
      final s = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        workout: Workout.push,
        trainingName: 'Push — Brust, Schultern, Trizeps',
      );
      expect(s.workout, Workout.push);
      expect(s.trainingId, isNull);
      expect(s.trainingName, 'Push — Brust, Schultern, Trizeps');
    });

    test('Zwei Sitzungen mit gleichen Angaben sind gleich', () {
      final a = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        trainingId: 'U1',
        trainingName: 'Eigenes',
      );
      final b = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        trainingId: 'U1',
        trainingName: 'Eigenes',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Ohne die neuen Felder bleibt die Gleichheit, wie sie war', () {
      final a = sitzung('S1', DateTime.utc(2027, 2, 10, 9), workout: Workout.a);
      final b = sitzung('S1', DateTime.utc(2027, 2, 10, 9), workout: Workout.a);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Eine andere trainingId macht die Sitzung ungleich', () {
      final a = sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingId: 'U1');
      final b = sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingId: 'U2');
      expect(a == b, isFalse);
      expect(b == a, isFalse);
    });

    test('Ein anderer trainingName macht die Sitzung ungleich', () {
      final a = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        trainingName: 'Alter Name',
      );
      final b = sitzung(
        'S1',
        DateTime.utc(2027, 2, 10, 9),
        trainingName: 'Neuer Name',
      );
      expect(a == b, isFalse);
      expect(b == a, isFalse);
    });

    test('Gesetzt und nicht gesetzt sind verschieden', () {
      final ohne = sitzung('S1', DateTime.utc(2027, 2, 10, 9));
      expect(
        ohne == sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingId: 'U1'),
        isFalse,
      );
      expect(
        ohne ==
            sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingName: 'Name'),
        isFalse,
      );
    });

    test('Der Hash unterscheidet die neuen Felder', () {
      // Ein Hash muss nicht verschieden sein — aber eine Menge, die beide
      // Sitzungen halten soll, darf sie nicht zusammenfallen lassen.
      final a = sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingId: 'U1');
      final b = sitzung('S1', DateTime.utc(2027, 2, 10, 9), trainingId: 'U2');
      expect({a, b}, hasLength(2));
    });
  });

  // -------------------------------------------------------------------------
  group('GymSessionBuilder ohne Enum-Workout', () {
    final zeitpunkt = DateTime.utc(2027, 2, 10, 17);

    test(
      'Ein Training ohne Workout ergibt eine Sitzung mit Kennung und Namen',
      () {
        final s = GymSessionBuilder.session(
          id: 'S1',
          date: zeitpunkt,
          workout: null,
          trainingId: '8F3A-ABCD',
          trainingName: 'Kurzhantel zuhause',
          minutes: 45,
          entries: {
            'benchPress': [const RawSet(weight: '40', reps: '8')],
          },
        );
        expect(s, isNotNull);
        expect(s!.workout, isNull);
        expect(s.trainingId, '8F3A-ABCD');
        expect(s.trainingName, 'Kurzhantel zuhause');
        expect(s.minutes, 45);
        expect(s.date, zeitpunkt);
      },
    );

    test('Alle Übungen mit Sätzen stehen in der Sitzung', () {
      final s = GymSessionBuilder.session(
        id: 'S1',
        date: zeitpunkt,
        workout: null,
        trainingId: '8F3A-ABCD',
        trainingName: 'Eigenes',
        entries: {
          'lateralRaise': [const RawSet(weight: '8', reps: '15')],
          'benchPress': [const RawSet(weight: '40', reps: '8')],
          'cableFly': [const RawSet(weight: '12', reps: '12')],
        },
      );
      expect(s!.exercises.map((e) => e.exerciseId).toSet(), {
        'benchPress',
        'lateralRaise',
        'cableFly',
      });
      expect(s.exercises, hasLength(3));
    });

    test('Ein leeres Training ergibt weiter null', () {
      expect(
        GymSessionBuilder.session(
          id: 'S1',
          date: zeitpunkt,
          workout: null,
          trainingId: '8F3A-ABCD',
          trainingName: 'Eigenes',
          entries: {
            'benchPress': [const RawSet(weight: '', reps: '')],
          },
        ),
        isNull,
      );
    });

    test('Eine Übung, die der Katalog nicht kennt, wird übergangen', () {
      final s = GymSessionBuilder.session(
        id: 'S1',
        date: zeitpunkt,
        workout: null,
        trainingId: '8F3A-ABCD',
        trainingName: 'Eigenes',
        entries: {
          'benchPress': [const RawSet(weight: '40', reps: '8')],
          'gibtEsNicht': [const RawSet(weight: '10', reps: '10')],
        },
      );
      expect(s!.exercises.map((e) => e.exerciseId), ['benchPress']);
    });

    test('Ein Enum-Workout mit eingefrorenem Namen: Name ja, Kennung nein', () {
      // Der Enum-Weg für Templates: `workout` wie bisher, `trainingId`
      // bleibt leer (Spec 4.6: nur für Trainings ohne Enum-Fall gesetzt).
      final s = GymSessionBuilder.session(
        id: 'S1',
        date: zeitpunkt,
        workout: Workout.push,
        trainingName: 'Push — Brust, Schultern, Trizeps',
        entries: {
          'benchPress': [const RawSet(weight: '40', reps: '8')],
        },
      );
      expect(s!.workout, Workout.push);
      expect(s.trainingId, isNull);
      expect(s.trainingName, 'Push — Brust, Schultern, Trizeps');
    });

    test('Ohne die neuen Parameter bleibt alles wie bisher', () {
      final s = GymSessionBuilder.session(
        id: 'S1',
        date: zeitpunkt,
        workout: Workout.a,
        entries: {
          'benchPress': [const RawSet(weight: '40', reps: '8')],
        },
      );
      expect(s!.workout, Workout.a);
      expect(s.trainingId, isNull);
      expect(s.trainingName, isNull);
    });

    test('Mit Workout bleibt die Reihenfolge die des Katalogs', () {
      // Gym A: Bankdrücken vor Seitheben vor Bizeps-Curls.
      final s = GymSessionBuilder.session(
        id: 'S1',
        date: zeitpunkt,
        workout: Workout.a,
        entries: {
          'bicepsCurl': [const RawSet(weight: '10', reps: '10')],
          'lateralRaise': [const RawSet(weight: '8', reps: '15')],
          'benchPress': [const RawSet(weight: '40', reps: '8')],
        },
      );
      expect(s!.exercises.map((e) => e.exerciseId), [
        'benchPress',
        'lateralRaise',
        'bicepsCurl',
      ]);
    });
  });

  // -------------------------------------------------------------------------
  group('GymSessionOrder.ordered mit trainingOrder', () {
    test('Ist die Reihenfolge des Trainings gegeben, gilt sie', () {
      // Alphabetisch käme benchPress vor cableFly.
      expect(
        GymSessionOrder.ordered(
          ['benchPress', 'lateralRaise', 'cableFly'],
          null,
          trainingOrder: ['cableFly', 'benchPress', 'lateralRaise'],
        ),
        ['cableFly', 'benchPress', 'lateralRaise'],
      );
    });

    test('Was in der Reihenfolge des Trainings nicht steht, hängt '
        'alphabetisch dahinter', () {
      expect(
        GymSessionOrder.ordered(
          ['tricepsPushdown', 'benchPress', 'lateralRaise', 'dips'],
          null,
          trainingOrder: ['lateralRaise', 'benchPress'],
        ),
        ['lateralRaise', 'benchPress', 'dips', 'tricepsPushdown'],
      );
    });

    test('Was nur in der Reihenfolge des Trainings steht, kommt nicht vor', () {
      expect(
        GymSessionOrder.ordered(
          ['benchPress'],
          null,
          trainingOrder: ['dips', 'benchPress', 'cableFly'],
        ),
        ['benchPress'],
      );
    });

    test('Mehrfach genannte IDs kommen einmal heraus', () {
      expect(
        GymSessionOrder.ordered(
          ['benchPress', 'benchPress', 'dips'],
          null,
          trainingOrder: ['dips', 'benchPress', 'benchPress'],
        ),
        ['dips', 'benchPress'],
      );
    });

    test('Die Reihenfolge des Trainings gilt statt der des Katalogs', () {
      // „… gilt statt `ExerciseCatalog.exercisesFor(workout)`" (Spec 5.9).
      // Gym A führt im Katalog Bankdrücken vor Seitheben.
      expect(
        GymSessionOrder.ordered(
          ['benchPress', 'lateralRaise'],
          Workout.a,
          trainingOrder: ['lateralRaise', 'benchPress'],
        ),
        ['lateralRaise', 'benchPress'],
      );
    });

    test('Neben einem Workout hängt das Fehlende alphabetisch dahinter', () {
      // Push führt im Katalog cableFly, tricepsPushdown, overheadTriceps;
      // die Reihenfolge des Trainings nennt nur zwei davon.
      expect(
        GymSessionOrder.ordered(
          ['overheadTriceps', 'tricepsPushdown', 'cableFly'],
          Workout.push,
          trainingOrder: ['overheadTriceps', 'cableFly'],
        ),
        ['overheadTriceps', 'cableFly', 'tricepsPushdown'],
      );
    });

    test('Ohne trainingOrder bleibt die Reihenfolge des Workouts', () {
      // Push im Katalog: cableFly, tricepsPushdown, overheadTriceps —
      // alphabetisch wäre overheadTriceps vor tricepsPushdown.
      expect(
        GymSessionOrder.ordered([
          'overheadTriceps',
          'tricepsPushdown',
          'cableFly',
        ], Workout.push),
        ['cableFly', 'tricepsPushdown', 'overheadTriceps'],
      );
    });

    test('Ohne trainingOrder und ohne Workout steht alles alphabetisch', () {
      expect(
        GymSessionOrder.ordered([
          'overheadTriceps',
          'tricepsPushdown',
          'cableFly',
        ], null),
        ['cableFly', 'overheadTriceps', 'tricepsPushdown'],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('GymSessionMerge.sessionKey', () {
    // Mi, 10.02.2027; 09:00 UTC ist in Berlin 10:00.
    final morgens = DateTime.utc(2027, 2, 10, 9);
    final abends = DateTime.utc(2027, 2, 10, 17);

    test('Jeder bestehende Schlüssel bleibt unverändert: Tag und Code', () {
      expect(
        GymSessionMerge.sessionKey(sitzung('S', morgens, workout: Workout.a)),
        '2027-02-10-A',
      );
      expect(
        GymSessionMerge.sessionKey(
          sitzung('S', morgens, workout: Workout.legs),
        ),
        '2027-02-10-Legs',
      );
    });

    test('Ohne Workout und ohne Training bleibt es das Fragezeichen', () {
      expect(GymSessionMerge.sessionKey(sitzung('S', morgens)), '2027-02-10-?');
    });

    test('Ein Training ohne Enum-Fall hat seine Kennung im Schlüssel', () {
      expect(
        GymSessionMerge.sessionKey(
          sitzung('S', morgens, trainingId: '8F3A-ABCD'),
        ),
        '2027-02-10-8F3A-ABCD',
      );
    });

    test('Zwei verschiedene eigene Trainings am selben Tag haben '
        'verschiedene Schlüssel', () {
      // Der Anlass des Eingriffs (Spec 4.6): beide hätten `workout == null`
      // und damit denselben Schlüssel `…-?`.
      final eins = GymSessionMerge.sessionKey(
        sitzung('S1', morgens, trainingId: 'U1'),
      );
      final zwei = GymSessionMerge.sessionKey(
        sitzung('S2', abends, trainingId: 'U2'),
      );
      expect(eins, isNot(zwei));
    });

    test('Dasselbe eigene Training am selben Tag hat denselben Schlüssel', () {
      expect(
        GymSessionMerge.sessionKey(sitzung('S1', morgens, trainingId: 'U1')),
        GymSessionMerge.sessionKey(sitzung('S2', abends, trainingId: 'U1')),
      );
    });

    test('Dasselbe eigene Training an zwei Tagen hat zwei Schlüssel', () {
      expect(
        GymSessionMerge.sessionKey(sitzung('S1', morgens, trainingId: 'U1')),
        isNot(
          GymSessionMerge.sessionKey(
            sitzung('S2', DateTime.utc(2027, 2, 11, 9), trainingId: 'U1'),
          ),
        ),
      );
    });

    test('Der Tag ist der Berliner Tag, nicht der UTC-Tag', () {
      // 23:30 UTC am 10.02. ist in Berlin (Winterzeit, +1) schon 00:30 am
      // 11.02. — der Zahlendreher, vor dem `data_window_test.dart` warnt.
      expect(
        GymSessionMerge.sessionKey(
          sitzung('S', DateTime.utc(2027, 2, 10, 23, 30), trainingId: 'U1'),
        ),
        '2027-02-11-U1',
      );
    });

    test(
      'Eine Kennung hat Vorrang vor dem Workout, wenn beide gesetzt sind',
      () {
        expect(
          GymSessionMerge.sessionKey(
            sitzung('S', morgens, workout: Workout.a, trainingId: 'U1'),
          ),
          '2027-02-10-U1',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('GymSessionMerge.merge mit eigenen Trainings', () {
    final morgens = DateTime.utc(2027, 2, 10, 9);
    final abends = DateTime.utc(2027, 2, 10, 17);

    test('Zwei verschiedene eigene Trainings am selben Tag bleiben beide '
        'stehen, das spätere zuerst', () {
      final zusammen = GymSessionMerge.merge(
        logged: [
          sitzung('s-morgens', morgens, trainingId: 'U1'),
          sitzung('s-abends', abends, trainingId: 'U2'),
        ],
        imported: [],
      );
      expect(ids(zusammen), ['s-abends', 's-morgens']);
    });

    test('Ein eigenes Training und ein übernommenes Gym A am selben Tag '
        'bleiben beide stehen', () {
      final zusammen = GymSessionMerge.merge(
        logged: [sitzung('eigen', abends, trainingId: 'U1')],
        imported: [sitzung('import', morgens, workout: Workout.a)],
      );
      expect(zusammen, hasLength(2));
      expect(ids(zusammen).toSet(), {'eigen', 'import'});
    });

    test('Dasselbe Training am selben Tag: das eigene gewinnt', () {
      final zusammen = GymSessionMerge.merge(
        logged: [sitzung('neu', abends, trainingId: 'U1')],
        imported: [sitzung('alt', morgens, trainingId: 'U1')],
      );
      expect(ids(zusammen), ['neu']);
    });

    test('Eigene Trainings an verschiedenen Tagen stehen beide da', () {
      final zusammen = GymSessionMerge.merge(
        logged: [
          sitzung('tag1', morgens, trainingId: 'U1'),
          sitzung('tag2', DateTime.utc(2027, 2, 11, 9), trainingId: 'U1'),
        ],
        imported: [],
      );
      expect(ids(zusammen), ['tag2', 'tag1']);
    });

    test(
      'Bestehendes Verhalten: Workout am selben Tag, das eigene gewinnt',
      () {
        final zusammen = GymSessionMerge.merge(
          logged: [sitzung('eigen', abends, workout: Workout.a)],
          imported: [sitzung('import', morgens, workout: Workout.a)],
        );
        expect(ids(zusammen), ['eigen']);
      },
    );
  });
}
