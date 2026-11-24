import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutRules.check`** und **`WorkoutProblem`** — die eine
/// Prüfung, die Editor, Repository und Import gemeinsam benutzen (#532).
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 5.2 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** „Ein leeres Training lässt sich nicht
///   speichern" (19.11.2026, Kopf der Entwürfe); der Zwischenstand darf
///   unfertig sein (19.11.2026, Spec 22 Nr. 3 — der Editor sichert
///   fortlaufend, sobald etwas geändert wurde).
/// - **Vorschlag der Spec, hier vorausgesetzt:** 17.7 (Name ist Pflicht,
///   ≤ 60 Zeichen) und 17.22 (höchstens 5 Tags, je ≤ 20 Zeichen; 1–10
///   Sätze; Wiederholungen ≤ 100, Sekunden ≤ 600; Dauer 1–600). **Die
///   Zahlen sind die der Spec, nicht Tims** — jede Grenze steht hier als
///   Paar „noch erlaubt / schon zu viel", damit eine andere Zahl genau
///   einen Fall bricht.
/// - **Festlegung des Test-Agenten:** die Form von `WorkoutProblem`. Die
///   Spec sagt „enum oder sealed, Fälle mit `detail`", ohne Namen. Unten
///   steht die Form, die diese Tests vorgeben.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Dateien `lib/src/workout_rules.dart` (`WorkoutRules` und
/// `WorkoutProblem`), dazu die Export-Zeile in `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutRules {
///   static List<WorkoutProblem> check(WorkoutDefinition definition);
///   // leer = in Ordnung; wirft nie
/// }
///
/// sealed class WorkoutProblem { const WorkoutProblem(); }   // ==, hashCode
/// final class NameEmpty          extends WorkoutProblem { const NameEmpty(); }
/// final class NameTooLong        extends WorkoutProblem { const NameTooLong(); }
/// final class NoExercises        extends WorkoutProblem { const NoExercises(); }
/// final class UnknownExercise    extends WorkoutProblem { const UnknownExercise(String exerciseId); }
/// final class DuplicateExercise  extends WorkoutProblem { const DuplicateExercise(String exerciseId); }
/// final class SetsOutOfRange     extends WorkoutProblem { const SetsOutOfRange(String exerciseId); }
/// final class RepsInvalid        extends WorkoutProblem { const RepsInvalid(String exerciseId); }
/// final class TooManyTags        extends WorkoutProblem { const TooManyTags(); }
/// final class TagInvalid         extends WorkoutProblem { const TagInvalid(String tag); }
/// final class MinutesOutOfRange  extends WorkoutProblem { const MinutesOutOfRange(); }
/// ```
///
/// Geprüft wird nur, was die Spec festlegt: **welche** Fälle bei **welcher**
/// Eingabe herauskommen, jeweils mit der betroffenen Kennung. Die Reihenfolge
/// der Liste legt die Spec nicht fest — mehrere Funde werden ungeordnet
/// verglichen. Ein Feldname für die Kennung (`detail`?) steht **nicht** im
/// Vertrag; die Tests fassen nur den Konstruktor und `==` an.
///
/// ## Was hier **nicht** getestet wird
///
/// - **`UnknownExercise` bei einem Entwurf** und was bei einer unbekannten ID
///   mit Sätzen und Bereich geschieht: die Spec sagt „`exerciseId` im
///   Katalog" und „Entwurf prüft nur die Gestalt", nicht, ob das eine die
///   andere aufhebt. Gemeldet, nicht entschieden.
/// - **Leere oder doppelte Tags** (`TagInvalid('')`, „gym"/„Gym"): die Spec
///   nennt für `check` nur die Obergrenzen 5 und 20.
/// - **Die Zahl der Funde bei dreimal derselben Übung.**

// ---------------------------------------------------------------------------
// Hilfen
// ---------------------------------------------------------------------------

WorkoutExercise uebung(
  String id, {
  int sets = 3,
  int repLow = 8,
  int repHigh = 12,
}) => WorkoutExercise(
  exerciseId: id,
  sets: sets,
  repLow: repLow,
  repHigh: repHigh,
  increment: null,
);

/// Ein fertiges, gültiges Training: drei bekannte Übungen, ein Tag.
List<WorkoutExercise> gueltigeUebungen() => [
  uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
  uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
  uebung('sidePlank', sets: 3, repLow: 30, repHigh: 45),
];

WorkoutDefinition training({
  String name = 'Oberkörper zuhause',
  List<String>? tags,
  List<WorkoutExercise>? exercises,
  int? enteredMinutes,
  bool isDraft = false,
}) => WorkoutDefinition(
  id: 'ID1',
  name: name,
  category: WorkoutCategory.own,
  tags: tags ?? ['Gym'],
  exercises: exercises ?? gueltigeUebungen(),
  enteredMinutes: enteredMinutes,
  isDraft: isDraft,
);

List<WorkoutProblem> pruefe(WorkoutDefinition d) => WorkoutRules.check(d);

String zeichen(int n) => 'a' * n;

void main() {
  // -------------------------------------------------------------------------
  group('Ein gültiges Training', () {
    test('hat keinen Fund', () {
      expect(pruefe(training()), isEmpty);
    });

    test('Der Prüfer wirft bei keiner Eingabe', () {
      expect(
        () => pruefe(
          training(
            name: '',
            tags: List.generate(9, (i) => zeichen(30 + i)),
            exercises: [
              uebung('benchPress', sets: -1, repLow: -5, repHigh: -9),
              uebung('benchPress', sets: 99, repLow: 999, repHigh: 0),
              uebung('gibtEsNicht', sets: 0, repLow: 0, repHigh: 0),
            ],
            enteredMinutes: -3,
          ),
        ),
        returnsNormally,
      );
    });

    test('Zweimal geprüft ergibt zweimal dasselbe', () {
      final d = training(name: '', exercises: []);
      expect(pruefe(d), unorderedEquals(pruefe(d)));
    });
  });

  // -------------------------------------------------------------------------
  group('Der Name — Vorschlag 17.7: Pflicht, höchstens 60 Zeichen', () {
    test('Ein leerer Name ist ein Fund', () {
      expect(pruefe(training(name: '')), [const NameEmpty()]);
    });

    test('Ein Name nur aus Leerraum ist ein leerer Name', () {
      expect(pruefe(training(name: '   ')), [const NameEmpty()]);
      expect(pruefe(training(name: ' \t ')), [const NameEmpty()]);
    });

    test('60 Zeichen sind noch erlaubt, 61 schon zu viel', () {
      expect(pruefe(training(name: zeichen(60))), isEmpty);
      expect(pruefe(training(name: zeichen(61))), [const NameTooLong()]);
    });

    test('Gezählt wird der getrimmte Name', () {
      // „Name (getrimmt)" in der Grenztabelle.
      expect(pruefe(training(name: ' ${zeichen(60)} ')), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('Tags — Vorschlag 17.22: höchstens 5, je höchstens 20 Zeichen', () {
    test('Fünf Tags sind noch erlaubt, sechs schon zu viel', () {
      expect(pruefe(training(tags: ['a1', 'a2', 'a3', 'a4', 'a5'])), isEmpty);
      expect(pruefe(training(tags: ['a1', 'a2', 'a3', 'a4', 'a5', 'a6'])), [
        const TooManyTags(),
      ]);
    });

    test('20 Zeichen sind noch erlaubt, 21 schon zu viel — mit dem Tag', () {
      expect(pruefe(training(tags: [zeichen(20)])), isEmpty);
      expect(pruefe(training(tags: [zeichen(21)])), [TagInvalid(zeichen(21))]);
    });

    test('Ein zu langer Tag unter gültigen wird benannt', () {
      expect(pruefe(training(tags: ['Gym', zeichen(25), 'Home'])), [
        TagInvalid(zeichen(25)),
      ]);
    });

    test('Zu viele und ein zu langer Tag sind zwei Funde', () {
      expect(
        pruefe(training(tags: ['a1', 'a2', 'a3', 'a4', 'a5', zeichen(21)])),
        unorderedEquals([const TooManyTags(), TagInvalid(zeichen(21))]),
      );
    });

    test('Kein Tag ist in Ordnung', () {
      expect(pruefe(training(tags: [])), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('Die Übungsliste', () {
    test('Ein fertiges Training ohne Übung ist ein Fund', () {
      // Tim, 19.11.2026: „Ein leeres Training lässt sich nicht speichern."
      expect(pruefe(training(exercises: [])), [const NoExercises()]);
    });

    test('Eine Übung, die der Katalog nicht kennt, wird benannt', () {
      expect(
        pruefe(
          training(
            exercises: [
              ...gueltigeUebungen(),
              uebung('gibtEsNicht', sets: 3, repLow: 8, repHigh: 12),
            ],
          ),
        ),
        [const UnknownExercise('gibtEsNicht')],
      );
    });

    test('Dieselbe Übung zweimal ist ein Fund — mit ihrer Kennung', () {
      // Ein Training mit derselben Übung zweimal ließe sich nicht eintragen:
      // `gym_saetze` führt `(sitzung_id, uebung_id, satz_nr)` (Spec 4.1).
      final funde = pruefe(
        training(
          exercises: [
            uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
            uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
            uebung('benchPress', sets: 3, repLow: 8, repHigh: 12),
          ],
        ),
      );
      expect(funde, isNotEmpty);
      expect(funde, everyElement(const DuplicateExercise('benchPress')));
    });

    test('Zwei verschiedene Übungen sind keine Dublette', () {
      expect(
        pruefe(
          training(exercises: [uebung('benchPress'), uebung('closeGripBench')]),
        ),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Sätze — Vorschlag 17.22: 1 bis 10', () {
    test('1 und 10 Sätze sind erlaubt', () {
      expect(
        pruefe(training(exercises: [uebung('benchPress', sets: 1)])),
        isEmpty,
      );
      expect(
        pruefe(training(exercises: [uebung('benchPress', sets: 10)])),
        isEmpty,
      );
    });

    test('0 und 11 Sätze sind zu wenig bzw. zu viel — mit der Übung', () {
      expect(pruefe(training(exercises: [uebung('benchPress', sets: 0)])), [
        const SetsOutOfRange('benchPress'),
      ]);
      expect(pruefe(training(exercises: [uebung('benchPress', sets: 11)])), [
        const SetsOutOfRange('benchPress'),
      ]);
    });

    test('Negative Sätze sind außerhalb', () {
      expect(pruefe(training(exercises: [uebung('benchPress', sets: -1)])), [
        const SetsOutOfRange('benchPress'),
      ]);
    });

    test('Jede Übung wird für sich beurteilt', () {
      expect(
        pruefe(
          training(
            exercises: [
              uebung('benchPress', sets: 0),
              uebung('lateralRaise', sets: 11),
              uebung('dips', sets: 3),
            ],
          ),
        ),
        unorderedEquals([
          const SetsOutOfRange('benchPress'),
          const SetsOutOfRange('lateralRaise'),
        ]),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Wiederholungen — Vorschlag 17.22: ab 1, bis ≤ 100', () {
    test('Untergrenze 0 ist ungültig, 1 ist gültig', () {
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 0, repHigh: 10)]),
        ),
        [const RepsInvalid('benchPress')],
      );
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 1, repHigh: 10)]),
        ),
        isEmpty,
      );
    });

    test('Die Obergrenze darf nicht unter der Untergrenze liegen', () {
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 10, repHigh: 8)]),
        ),
        [const RepsInvalid('benchPress')],
      );
    });

    test('Gleiche Unter- und Obergrenze sind ein gültiger Bereich', () {
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 8, repHigh: 8)]),
        ),
        isEmpty,
      );
    });

    test('Bei Wiederholungen sind 100 noch erlaubt, 101 schon zu viel', () {
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 8, repHigh: 100)]),
        ),
        isEmpty,
      );
      expect(
        pruefe(
          training(exercises: [uebung('benchPress', repLow: 8, repHigh: 101)]),
        ),
        [const RepsInvalid('benchPress')],
      );
    });

    test('Auch die Untergrenze darf nicht über 100 liegen', () {
      expect(
        pruefe(
          training(
            exercises: [uebung('benchPress', repLow: 101, repHigh: 101)],
          ),
        ),
        [const RepsInvalid('benchPress')],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Zeitübungen — Sekunden bis 600 statt Wiederholungen bis 100', () {
    // Der Seitstütz ist die einzige Zeitübung des Katalogs (`isTimed`); seine
    // „Wiederholungen" sind Sekunden.

    test('Über 100 ist bei einer Zeitübung noch erlaubt', () {
      expect(
        pruefe(
          training(
            exercises: [uebung('sidePlank', sets: 3, repLow: 30, repHigh: 300)],
          ),
        ),
        isEmpty,
      );
    });

    test('600 Sekunden sind erlaubt, 601 schon zu viel', () {
      expect(
        pruefe(
          training(
            exercises: [uebung('sidePlank', sets: 3, repLow: 30, repHigh: 600)],
          ),
        ),
        isEmpty,
      );
      expect(
        pruefe(
          training(
            exercises: [uebung('sidePlank', sets: 3, repLow: 30, repHigh: 601)],
          ),
        ),
        [const RepsInvalid('sidePlank')],
      );
    });

    test('Dieselbe Zahl ist bei einer Übung mit Wiederholungen zu viel', () {
      // 300 ist als Sekunden gültig, als Wiederholungen nicht — die Grenze
      // hängt an der Übung, nicht an der Zahl.
      expect(
        pruefe(
          training(
            exercises: [
              uebung('benchPress', sets: 3, repLow: 30, repHigh: 300),
            ],
          ),
        ),
        [const RepsInvalid('benchPress')],
      );
    });

    test('Der Bereich muss auch bei Sekunden geordnet sein', () {
      expect(
        pruefe(
          training(
            exercises: [uebung('sidePlank', sets: 3, repLow: 60, repHigh: 30)],
          ),
        ),
        [const RepsInvalid('sidePlank')],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Die eingetragene Dauer — Vorschlag 17.22: null oder 1 bis 600', () {
    test('null heißt „geschätzt" und ist in Ordnung', () {
      expect(pruefe(training(enteredMinutes: null)), isEmpty);
    });

    test('1 und 600 Minuten sind erlaubt', () {
      expect(pruefe(training(enteredMinutes: 1)), isEmpty);
      expect(pruefe(training(enteredMinutes: 600)), isEmpty);
    });

    test('0, 601 und negative Minuten sind außerhalb', () {
      expect(pruefe(training(enteredMinutes: 0)), [const MinutesOutOfRange()]);
      expect(pruefe(training(enteredMinutes: 601)), [
        const MinutesOutOfRange(),
      ]);
      expect(pruefe(training(enteredMinutes: -5)), [const MinutesOutOfRange()]);
    });
  });

  // -------------------------------------------------------------------------
  group('Mehrere Funde auf einmal', () {
    test('Der Prüfer meldet alle, nicht nur den ersten', () {
      // Der Editor zeigt jeden Grund; ein Prüfer, der beim ersten abbräche,
      // ließe den Nutzer in Runden speichern.
      expect(
        pruefe(training(name: '', exercises: [])),
        unorderedEquals([const NameEmpty(), const NoExercises()]),
      );
    });

    test('Funde aus Name, Dauer und Übung kommen zusammen', () {
      expect(
        pruefe(
          training(
            name: zeichen(61),
            enteredMinutes: 0,
            exercises: [uebung('benchPress', sets: 0)],
          ),
        ),
        unorderedEquals([
          const NameTooLong(),
          const MinutesOutOfRange(),
          const SetsOutOfRange('benchPress'),
        ]),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('Ein Entwurf wird nur auf seine Gestalt geprüft', () {
    // Tim, 19.11.2026 (Spec 22 Nr. 3): Der Editor sichert fortlaufend, sobald
    // etwas geändert wurde — ein Zwischenstand darf unfertig sein, das ist
    // sein Zweck. Spec 5.2: „Grenzen und Dubletten ja, `nameEmpty` und
    // `noExercises` nein."

    test('Ein Entwurf ohne Namen und ohne Übung hat keinen Fund', () {
      expect(pruefe(training(isDraft: true, name: '', exercises: [])), isEmpty);
    });

    test('Ein Entwurf ohne Namen, aber mit Übungen hat keinen Fund', () {
      expect(pruefe(training(isDraft: true, name: '')), isEmpty);
    });

    test('Ein Entwurf mit Namen, aber ohne Übung hat keinen Fund', () {
      expect(pruefe(training(isDraft: true, exercises: [])), isEmpty);
    });

    test('Dasselbe Training, fertig gespeichert, hat beide Funde', () {
      // Gegenprobe: Es ist `isDraft`, das die beiden Fälle ausnimmt.
      expect(
        pruefe(training(isDraft: false, name: '', exercises: [])),
        unorderedEquals([const NameEmpty(), const NoExercises()]),
      );
    });

    test('Ein zu langer Name ist auch im Entwurf ein Fund', () {
      expect(pruefe(training(isDraft: true, name: zeichen(61))), [
        const NameTooLong(),
      ]);
    });

    test('Zu viele und zu lange Tags sind auch im Entwurf Funde', () {
      expect(
        pruefe(
          training(
            isDraft: true,
            tags: ['a1', 'a2', 'a3', 'a4', 'a5', zeichen(21)],
          ),
        ),
        unorderedEquals([const TooManyTags(), TagInvalid(zeichen(21))]),
      );
    });

    test('Eine Dublette ist auch im Entwurf ein Fund', () {
      final funde = pruefe(
        training(
          isDraft: true,
          exercises: [uebung('benchPress'), uebung('benchPress')],
        ),
      );
      expect(funde, isNotEmpty);
      expect(funde, everyElement(const DuplicateExercise('benchPress')));
    });

    test('Sätze und Wiederholungen außerhalb sind auch im Entwurf Funde', () {
      expect(
        pruefe(
          training(
            isDraft: true,
            exercises: [
              uebung('benchPress', sets: 0),
              uebung('lateralRaise', repLow: 10, repHigh: 5),
            ],
          ),
        ),
        unorderedEquals([
          const SetsOutOfRange('benchPress'),
          const RepsInvalid('lateralRaise'),
        ]),
      );
    });

    test('Eine Dauer außerhalb ist auch im Entwurf ein Fund', () {
      expect(pruefe(training(isDraft: true, enteredMinutes: 0)), [
        const MinutesOutOfRange(),
      ]);
    });

    test('Ein vollständiger Entwurf hat keinen Fund', () {
      expect(pruefe(training(isDraft: true)), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutProblem vergleicht sich inhaltlich', () {
    // Die Vergleiche oben (`unorderedEquals`, `everyElement`) stehen auf
    // diesem `==`.
    test('Gleiche Fälle mit gleicher Kennung sind gleich', () {
      expect(const NameEmpty(), equals(const NameEmpty()));
      expect(const UnknownExercise('a'), equals(const UnknownExercise('a')));
      expect(
        const UnknownExercise('a').hashCode,
        const UnknownExercise('a').hashCode,
      );
      expect(TagInvalid(zeichen(21)), equals(TagInvalid(zeichen(21))));
    });

    test('Verschiedene Kennungen sind verschieden', () {
      expect(const UnknownExercise('a') == const UnknownExercise('b'), isFalse);
      expect(const SetsOutOfRange('a') == const SetsOutOfRange('b'), isFalse);
      expect(const RepsInvalid('a') == const RepsInvalid('b'), isFalse);
    });

    test('Verschiedene Fälle mit gleicher Kennung sind verschieden', () {
      expect(
        const UnknownExercise('a') == const DuplicateExercise('a'),
        isFalse,
      );
      expect(const SetsOutOfRange('a') == const RepsInvalid('a'), isFalse);
    });

    test('Zwei verschiedene Fälle ohne Kennung sind nie gleich', () {
      // Dieselbe Falle wie bei `Running()` und `Today()` im Planer: Fälle
      // ohne Felder wären über einen gemeinsamen `==` ununterscheidbar.
      expect(const NameEmpty() == const NameTooLong(), isFalse);
      expect(const NameEmpty() == const NoExercises(), isFalse);
      expect(const TooManyTags() == const MinutesOutOfRange(), isFalse);
    });
  });
}
