import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Workout`, portiert aus
/// `Packages/TrainingsCore/Tests/TrainingsCoreTests/WorkoutTests.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block A“, `lib/src/exercise.dart`.
///
/// Die Workouts zerfallen in zwei Gruppen, und die Trennung trägt die ganze
/// Logik des Gym-Tabs: `rotation` bekommt Wochentage, Fristen und Plätze in
/// der Wochenleiste, `freelyChosen` nichts davon. Wer ein Workout in die
/// falsche Gruppe legt, baut entweder eine Kachel, die ewig „offen“ sagt,
/// oder nimmt einem geplanten Workout seine Frist.
///
/// **Bewusste Abweichung von Swift** (Spec, Punkt 3): `rawValue` heißt in
/// Dart `code`. Der Wert bleibt wortgleich, weil er in gespeicherten
/// Trainings und im Dashboard-Export steht. Dazu kommt `fromCode`, das es in
/// Swift nicht gibt — dort leistet das `init?(rawValue:)`.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`).
void main() {
  group('Die beiden Gruppen zerlegen die Workouts vollständig', () {
    test('Rotation und frei wählbare ergeben zusammen genau alle Workouts', () {
      expect({
        ...Workout.rotation,
        ...Workout.freelyChosen,
      }, Workout.values.toSet());
      expect(
        Workout.rotation.length + Workout.freelyChosen.length,
        Workout.values.length,
      );
    });

    test('Kein Workout steht in beiden Gruppen', () {
      expect(
        Workout.rotation.toSet().intersection(Workout.freelyChosen.toSet()),
        isEmpty,
      );
    });

    test('Die Wochenrotation ist A bis D, die frei wählbaren sind Push, Pull '
        'und Legs', () {
      expect(Workout.rotation, [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(Workout.freelyChosen, [Workout.push, Workout.pull, Workout.legs]);
    });

    test('Keine Gruppe nennt ein Workout zweimal', () {
      expect(Workout.rotation.toSet(), hasLength(Workout.rotation.length));
      expect(
        Workout.freelyChosen.toSet(),
        hasLength(Workout.freelyChosen.length),
      );
    });
  });

  group('Der Code ist der gespeicherte Bezeichner', () {
    // Der Code steht im gespeicherten Verlauf und im Dashboard-Export.
    // Wer ihn ändert, macht alte Trainings namenlos.
    test('Die Codes sind die Bezeichner aus der Spec', () {
      expect(Workout.a.code, 'A');
      expect(Workout.b.code, 'B');
      expect(Workout.c.code, 'C');
      expect(Workout.d.code, 'D');
      expect(Workout.push.code, 'Push');
      expect(Workout.pull.code, 'Pull');
      expect(Workout.legs.code, 'Legs');
    });

    test('Kein Code kommt zweimal vor', () {
      final codes = Workout.values.map((w) => w.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('Jeder Code findet sein Workout wieder', () {
      for (final workout in Workout.values) {
        expect(Workout.fromCode(workout.code), workout);
      }
    });

    test('Ein unbekannter Code gibt null, statt etwas zu erfinden', () {
      // Der Code kommt aus der Datenbank. Eine stillschweigend geratene
      // Zuordnung schriebe ein fremdes Workout in Tims Verlauf.
      expect(Workout.fromCode('E'), isNull);
      expect(Workout.fromCode(''), isNull);
      expect(Workout.fromCode('Gym A'), isNull);
      expect(Workout.fromCode('Beine'), isNull);
    });

    test('Die Zuordnung unterscheidet Groß- und Kleinschreibung', () {
      // 'A' ist der gespeicherte Wert, 'a' ist der Name des Dart-Falls.
      // Würde 'a' akzeptiert, wäre nicht mehr entscheidbar, welcher von
      // beiden geschrieben wurde.
      expect(Workout.fromCode('a'), isNull);
      expect(Workout.fromCode('push'), isNull);
      expect(Workout.fromCode('PUSH'), isNull);
    });
  });

  group('Titel und Beschriftung', () {
    test('Die Titel stehen so in der Spec', () {
      expect(Workout.a.title, 'Oberkörper Push + Arme');
      expect(Workout.b.title, 'Läufer-Kraft + Brust');
      expect(Workout.c.title, 'Oberkörper Pull + Arme');
      expect(Workout.d.title, 'Arme + Schultern');
      expect(Workout.push.title, 'Brust, Schultern, Trizeps');
      expect(Workout.pull.title, 'Rücken, hintere Schulter, Bizeps');
      expect(Workout.legs.title, 'Beine komplett');
    });

    /// Die Ansichten setzen überall `'$label — $title'` zusammen. Trüge der
    /// Titel den Namen noch einmal, stünde dort „Push — Push — Brust…“.
    test('Kein Titel wiederholt den Namen des frei wählbaren Workouts', () {
      // Nur für Push, Pull und Legs prüfbar: „Arme“ in Gym A enthält
      // zwangsläufig das A, ohne dass sich etwas doppelte.
      for (final workout in Workout.freelyChosen) {
        expect(
          workout.title.contains(workout.code),
          isFalse,
          reason:
              '${workout.code}: Titel ${workout.title} nennt den Namen '
              'erneut',
        );
      }
      for (final workout in Workout.values) {
        expect(
          workout.title.contains('—'),
          isFalse,
          reason:
              '${workout.code}: Titel ${workout.title} trägt schon '
              'einen Gedankenstrich',
        );
      }
    });

    test(
      'Die Rotation heißt Gym A bis Gym D, die frei wählbaren nur beim Namen',
      () {
        expect(Workout.a.label, 'Gym A');
        expect(Workout.b.label, 'Gym B');
        expect(Workout.c.label, 'Gym C');
        expect(Workout.d.label, 'Gym D');
        expect(Workout.push.label, 'Push');
        expect(Workout.pull.label, 'Pull');
        expect(Workout.legs.label, 'Legs');
      },
    );

    test('Die Beschriftung folgt der Gruppe, nicht dem Einzelfall', () {
      for (final workout in Workout.rotation) {
        expect(workout.label, 'Gym ${workout.code}');
      }
      for (final workout in Workout.freelyChosen) {
        expect(workout.label, workout.code);
      }
    });

    test(
      'Zwei Workouts tragen nie denselben Titel oder dieselbe Beschriftung',
      () {
        final titel = Workout.values.map((w) => w.title).toList();
        expect(titel.toSet(), hasLength(titel.length));
        final labels = Workout.values.map((w) => w.label).toList();
        expect(labels.toSet(), hasLength(labels.length));
      },
    );
  });

  group('Die ungefähre Dauer', () {
    test('Die Dauer steht so in der Spec', () {
      expect(Workout.a.minutes, 70);
      expect(Workout.b.minutes, 65);
      expect(Workout.c.minutes, 70);
      expect(Workout.d.minutes, 60);
      expect(Workout.push.minutes, 70);
      expect(Workout.pull.minutes, 70);
      expect(Workout.legs.minutes, 60);
    });

    test('Jedes Workout dauert eine plausible Zeit und ist beschriftet', () {
      for (final workout in Workout.values) {
        expect(
          workout.minutes,
          greaterThanOrEqualTo(30),
          reason: '${workout.code}: ${workout.minutes} min',
        );
        expect(
          workout.minutes,
          lessThanOrEqualTo(120),
          reason: '${workout.code}: ${workout.minutes} min',
        );
        expect(
          workout.title,
          isNotEmpty,
          reason: '${workout.code}: kein Titel',
        );
        expect(
          workout.label,
          isNotEmpty,
          reason: '${workout.code}: keine Beschriftung',
        );
        expect(workout.code, isNotEmpty, reason: '$workout: kein Code');
      }
    });
  });
}
