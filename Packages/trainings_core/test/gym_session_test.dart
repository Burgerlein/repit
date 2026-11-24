import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die beiden Trägertypen einer Gym-Sitzung, das Dart-Gegenstück zu
/// `ImportedExercise` und `ImportedSession` aus
/// `Packages/TrainingsCore/Sources/TrainingsCore/Import/DashboardImport.swift`
/// (Zeilen 14–58).
///
/// Sie heißen „imported", tragen aber auch die selbst erfassten Trainings:
/// Beide Herkünfte haben dieselbe Form, und zwei Namen für dieselbe Sache
/// kosten mehr als ein ungenauer.
///
/// Zwei Rechnungen hängen daran, und beide sind leicht falsch zu „reparieren":
///
/// - **`volumeKg` summiert `max(0, kg) × Wiederholungen`.** Ein unterstützter
///   Satz trägt **nichts** bei, weil negatives Gewicht Hilfe der Maschine ist
///   und keine Last. Was dort tatsächlich bewegt wurde, wäre Körpergewicht
///   minus Hilfe — das rechnet das Dashboard nicht, und zwei verschiedene
///   Zahlen für dieselbe Sitzung wären schlimmer als eine vorsichtige. Die
///   Gruppe „volumeKg" hält das ausdrücklich fest, damit es niemand als
///   vergessene Fallunterscheidung ansieht.
/// - **`setCount` zählt Sätze, nicht Last.** Ein Satz am eigenen Körpergewicht
///   und ein unterstützter Satz zählen mit, obwohl sie zur Tonnage nichts
///   beitragen.
///
/// Beide Typen bekommen `==` und `hashCode` über alle Felder, Listen
/// inhaltlich verglichen: Ein Werttyp, der Abhängigkeit eines Providers ist,
/// löst sonst bei jedem Neubau eine Neuberechnung aus.
///
/// Alle Zahlen hier sind erfunden. Echte Trainingsdaten gehören nicht ins
/// Repository.
void main() {
  CompletedSet satz(double gewicht, int wiederholungen) =>
      CompletedSet(weight: gewicht, reps: wiederholungen);

  // Berliner Zeit 18:30 am 21.09.2026 (Sommerzeit, UTC+2). Alle Zeitpunkte
  // in diesen Tests sind UTC-Werte, die Berliner Wanduhrzeiten bezeichnen.
  final zeitpunkt = DateTime.utc(2026, 9, 21, 16, 30);

  ImportedSession sitzung(List<ImportedExercise> uebungen) => ImportedSession(
    id: 'sitzung-1',
    date: zeitpunkt,
    workout: Workout.a,
    minutes: 62,
    note: null,
    exercises: uebungen,
  );

  group('ImportedExercise', () {
    test('gleiche Übung mit gleichen Sätzen ist gleich', () {
      const id = 'benchPress';
      final eine = ImportedExercise(
        exerciseId: id,
        sets: [satz(40, 8), satz(40, 7)],
      );
      final andere = ImportedExercise(
        exerciseId: id,
        sets: [satz(40, 8), satz(40, 7)],
      );

      expect(eine, equals(andere));
      // Über ein Set geprüft, weil ein == ohne passenden hashCode genau hier
      // auffällt und sonst nirgends.
      expect({eine, andere}, hasLength(1));
    });

    test('verschiedene Übungs-IDs sind nicht gleich', () {
      final eine = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [satz(40, 8)],
      );
      final andere = ImportedExercise(exerciseId: 'dips', sets: [satz(40, 8)]);

      expect(eine, isNot(equals(andere)));
    });

    test('die Sätze werden inhaltlich verglichen, nicht als Objekt', () {
      // Zwei frisch gebaute Listen mit denselben Werten sind dieselbe Übung.
      // Ohne inhaltlichen Vergleich wäre jede neu geladene Sitzung ungleich
      // der vorigen und jeder abgeleitete Wert liefe neu.
      final eine = ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]);
      final andere = ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]);
      final abweichend = ImportedExercise(
        exerciseId: 'dips',
        sets: [satz(0, 9)],
      );

      expect(eine, equals(andere));
      expect(eine, isNot(equals(abweichend)));
    });

    test('die Reihenfolge der Sätze gehört zur Übung', () {
      // Erst 8 Wiederholungen, dann 6, ist ein anderer Verlauf als umgekehrt.
      final absteigend = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [satz(40, 8), satz(40, 6)],
      );
      final aufsteigend = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [satz(40, 6), satz(40, 8)],
      );

      expect(absteigend, isNot(equals(aufsteigend)));
    });
  });

  group('ImportedSession.setCount', () {
    test('zählt die Sätze über alle Übungen hinweg', () {
      final s = sitzung([
        ImportedExercise(
          exerciseId: 'benchPress',
          sets: [satz(40, 8), satz(40, 7), satz(37.5, 8)],
        ),
        ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10), satz(0, 8)]),
      ]);

      expect(s.setCount, 5);
    });

    test('eine Sitzung ohne Übungen hat keine Sätze', () {
      expect(sitzung([]).setCount, 0);
    });

    test('Sätze ohne Last zählen mit', () {
      // Körpergewicht und Unterstützung sind Sätze. Dass sie zur Tonnage
      // nichts beitragen, ist eine andere Frage als „hat stattgefunden".
      final s = sitzung([
        ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10), satz(-27, 6)]),
      ]);

      expect(s.setCount, 2);
    });
  });

  group('ImportedSession.volumeKg', () {
    test('summiert Kilogramm mal Wiederholungen über alle Übungen', () {
      final s = sitzung([
        ImportedExercise(
          exerciseId: 'benchPress',
          sets: [satz(40, 8), satz(42.5, 6)],
        ),
        ImportedExercise(exerciseId: 'lateralRaise', sets: [satz(12, 15)]),
      ]);

      // 320 + 255 + 180
      expect(s.volumeKg, closeTo(755, 1e-9));
    });

    test('ein unterstützter Satz trägt nichts zur Tonnage bei', () {
      // −27 heißt 27 kg Hilfe von der Maschine. Das ist keine bewegte Last,
      // und als negativer Beitrag würde es die Tonnage der Sitzung senken.
      // Bewusst vorsichtig gerechnet — kein vergessener Sonderfall.
      final s = sitzung([
        ImportedExercise(exerciseId: 'dips', sets: [satz(-27, 6)]),
      ]);

      expect(s.volumeKg, 0);
    });

    test('ein Satz am eigenen Körpergewicht trägt nichts zur Tonnage bei', () {
      final s = sitzung([
        ImportedExercise(exerciseId: 'pullUp', sets: [satz(0, 7)]),
      ]);

      expect(s.volumeKg, 0);
    });

    test('neben unterstützten Sätzen bleibt die geladene Last vollständig', () {
      final s = sitzung([
        ImportedExercise(
          exerciseId: 'dips',
          sets: [satz(-27, 6), satz(0, 8), satz(10, 5)],
        ),
        ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
      ]);

      // 0 + 0 + 50 + 320
      expect(s.volumeKg, closeTo(370, 1e-9));
    });

    test('eine Sitzung ohne Übungen hat keine Tonnage', () {
      expect(sitzung([]).volumeKg, 0);
    });
  });

  group('ImportedSession: == und hashCode', () {
    ImportedSession bauen({
      String id = 'sitzung-1',
      DateTime? datum,
      Workout? workout = Workout.a,
      int? minuten = 62,
      String? notiz,
      List<ImportedExercise>? uebungen,
    }) => ImportedSession(
      id: id,
      date: datum ?? zeitpunkt,
      workout: workout,
      minutes: minuten,
      note: notiz,
      exercises:
          uebungen ??
          [
            ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
          ],
    );

    test('zwei Sitzungen mit denselben Werten sind gleich', () {
      expect(bauen(), equals(bauen()));
      expect({bauen(), bauen()}, hasLength(1));
    });

    test('ein anderer Zeitpunkt macht eine andere Sitzung', () {
      expect(
        bauen(),
        isNot(equals(bauen(datum: DateTime.utc(2026, 9, 21, 17, 30)))),
      );
    });

    test('„kein Workout" ist nicht dasselbe wie Gym A', () {
      expect(bauen(workout: null), isNot(equals(bauen(workout: Workout.a))));
    });

    test('Dauer und Notiz gehören zur Gleichheit', () {
      expect(bauen(minuten: null), isNot(equals(bauen(minuten: 62))));
      expect(
        bauen(notiz: 'Schulter hat gezwickt'),
        isNot(equals(bauen(notiz: null))),
      );
    });

    test('die Übungsliste wird inhaltlich verglichen', () {
      final eine = bauen(
        uebungen: [
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
          ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]),
        ],
      );
      final gleich = bauen(
        uebungen: [
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
          ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]),
        ],
      );
      final andersHerum = bauen(
        uebungen: [
          ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]),
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
        ],
      );

      expect(eine, equals(gleich));
      // Die Reihenfolge der Übungen ist Teil der Sitzung — sie ist bewusst
      // festgelegt und darf nicht wegvergleichen werden.
      expect(eine, isNot(equals(andersHerum)));
    });
  });
}
