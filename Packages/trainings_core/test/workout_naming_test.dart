import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutNaming`** — Kurzname und die dreistufige
/// Namensauflösung einer Sitzung (#532). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitte 4.6, 5.8 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Der Verlauf friert ein — eine eingetragene
///   Sitzung zeigt für immer, was damals trainiert wurde; Umbenennen und
///   Löschen schreiben den Verlauf nicht um (18.11.2026, #531).
/// - **Folgerung aus dem Code (Spec 4.6):** Stufe 2 der Auflösung ist
///   `'${label} — ${title}'`, **dieselbe Zeichenkette, die die Schirme heute
///   zusammensetzen** (`heute_training.dart`, `gym_fokus_texte.dart`);
///   `shortName` ergibt für Templates `Workout.label` — der Verlauf zeigt
///   dort **dasselbe wie heute**, für jede bestehende Sitzung.
/// - **Vorschlag der Spec, hier vorausgesetzt:** die Regel für den Kurznamen
///   — der Teil vor dem ersten `' — '` (Gedankenstrich mit Leerzeichen
///   davor und danach), sonst der ganze Name (4.6, „[Vorschlag zur Regel;
///   die Entsprechung zu `Workout.label` ist [Folgerung]]").
///
/// ## Die drei Stufen
///
/// 1. `trainingName`, wenn gesetzt — **auch wenn ein `workout` da ist**;
///    der eingefrorene Name geht vor.
/// 2. Sonst, wenn `workout != null`: `'${label} — ${title}'`.
/// 3. Sonst `null` — die Ansicht schreibt „Training".
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_naming.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutNaming {
///   static String shortName(String name);
///   static String? title(ImportedSession session);
///   static String? shortTitle(ImportedSession session);   // shortName(title)
/// }
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **Ein leerer `trainingName` (`''`).** Die Spec sagt „wenn gesetzt";
///   ob `''` gesetzt ist, sagt sie nicht. Der Builder und die Spalte
///   schreiben ihn nicht als Leerzeichenkette, aber der Kern erzwingt es
///   nicht. Gemeldet, nicht entschieden.
/// - **Ein Name, der mit `' — '` beginnt** (leerer Kurzname).
/// - **Das Lesen der Namen in den Schirmen** (`gym_verlauf_texte.dart`,
///   `gym_auswertung.dart`) — `app/`.

ImportedSession sitzung({
  Workout? workout,
  String? trainingId,
  String? trainingName,
}) => ImportedSession(
  id: 'S1',
  date: DateTime.utc(2027, 2, 10, 9),
  workout: workout,
  minutes: null,
  note: null,
  exercises: const [],
  trainingId: trainingId,
  trainingName: trainingName,
);

void main() {
  // -------------------------------------------------------------------------
  group('shortName — der Teil vor dem ersten „ — "', () {
    test('Aus einem Template-Namen wird das Label', () {
      expect(
        WorkoutNaming.shortName('Gym A — Oberkörper Push + Arme'),
        'Gym A',
      );
      expect(
        WorkoutNaming.shortName('Push — Brust, Schultern, Trizeps'),
        'Push',
      );
      expect(
        WorkoutNaming.shortName('Pull — Rücken, hintere Schulter, Bizeps'),
        'Pull',
      );
      expect(WorkoutNaming.shortName('Legs — Beine komplett'), 'Legs');
    });

    test('Ein Name ohne Gedankenstrich bleibt ganz', () {
      expect(
        WorkoutNaming.shortName('Kurzhantel zuhause'),
        'Kurzhantel zuhause',
      );
    });

    test('Bei mehreren Gedankenstrichen gilt der erste', () {
      expect(WorkoutNaming.shortName('A — B — C'), 'A');
    });

    test('Für die Templates ist der Kurzname das Label des Enums', () {
      // Die Entsprechung aus Spec 4.6: Verlauf und Wochenleiste zeigen für
      // Templates dasselbe wie heute.
      for (final workout in Workout.values) {
        expect(
          WorkoutNaming.shortName('${workout.label} — ${workout.title}'),
          workout.label,
          reason: workout.code,
        );
      }
    });

    test('Ein Bindestrich ohne Leerzeichen trennt nicht', () {
      expect(WorkoutNaming.shortName('Push-Pull'), 'Push-Pull');
      expect(
        WorkoutNaming.shortName('Ganzkörper-Training'),
        'Ganzkörper-Training',
      );
    });

    test(
      'Ein Gedankenstrich ohne Leerzeichen auf beiden Seiten trennt nicht',
      () {
        expect(WorkoutNaming.shortName('A—B'), 'A—B');
        expect(WorkoutNaming.shortName('A —B'), 'A —B');
        expect(WorkoutNaming.shortName('A— B'), 'A— B');
      },
    );

    test('Ein Bindestrich mit Leerzeichen trennt nicht', () {
      // Das Trennzeichen ist der Gedankenstrich (U+2014) mit Leerzeichen;
      // „Kraft - Ausdauer" mit Bindestrich tippt jemand selbst und meint den
      // ganzen Namen.
      expect(WorkoutNaming.shortName('Kraft - Ausdauer'), 'Kraft - Ausdauer');
    });

    test('Ein Name nur aus dem Kurzteil bleibt unverändert', () {
      expect(WorkoutNaming.shortName('Gym A'), 'Gym A');
    });
  });

  // -------------------------------------------------------------------------
  group('title — Stufe 1: der eingefrorene Name', () {
    test('Ein gesetzter trainingName ist der Titel', () {
      expect(
        WorkoutNaming.title(sitzung(trainingName: 'Kurzhantel zuhause')),
        'Kurzhantel zuhause',
      );
    });

    test('Der eingefrorene Name geht dem Workout vor', () {
      // Eine Sitzung, die als Template entstand und später umbenannt wurde:
      // Die Karte zeigt weiter den Namen von damals.
      expect(
        WorkoutNaming.title(
          sitzung(workout: Workout.a, trainingName: 'Gym A — Alter Name'),
        ),
        'Gym A — Alter Name',
      );
    });

    test('Der eingefrorene Name geht der Kennung vor', () {
      expect(
        WorkoutNaming.title(
          sitzung(trainingId: '8F3A-ABCD', trainingName: 'Damals benannt'),
        ),
        'Damals benannt',
      );
    });

    test('Der Name wird nicht verändert', () {
      expect(
        WorkoutNaming.title(sitzung(trainingName: 'Gym A — Oberkörper')),
        'Gym A — Oberkörper',
      );
    });
  });

  group('title — Stufe 2: das Workout aus dem Enum', () {
    test('Ohne Namen kommt „Label — Titel" aus dem Enum', () {
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.a)),
        'Gym A — Oberkörper Push + Arme',
      );
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.b)),
        'Gym B — Läufer-Kraft + Brust',
      );
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.c)),
        'Gym C — Oberkörper Pull + Arme',
      );
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.d)),
        'Gym D — Arme + Schultern',
      );
    });

    test('Für die frei wählbaren steht das Label ohne „Gym"', () {
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.push)),
        'Push — Brust, Schultern, Trizeps',
      );
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.pull)),
        'Pull — Rücken, hintere Schulter, Bizeps',
      );
      expect(
        WorkoutNaming.title(sitzung(workout: Workout.legs)),
        'Legs — Beine komplett',
      );
    });

    test('Eine Sitzung aus der Übernahme bekommt ihren Namen aus dem Enum, '
        'nicht aus der Datenbank', () {
      // Es gibt keine Abhängigkeit von einer Zeile, die verschwinden darf —
      // der Kern kennt keine Datenbank, und der Titel entsteht allein aus
      // der Sitzung.
      final alt = sitzung(workout: Workout.a);
      expect(WorkoutNaming.title(alt), 'Gym A — Oberkörper Push + Arme');
    });
  });

  group('title — Stufe 3: nichts', () {
    test('Weder Name noch Workout ergibt null', () {
      expect(WorkoutNaming.title(sitzung()), isNull);
    });

    test('Eine Kennung allein nennt keinen Namen', () {
      // Eine UUID ist kein Titel; die Ansicht schreibt „Training".
      expect(WorkoutNaming.title(sitzung(trainingId: '8F3A-ABCD')), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('shortTitle', () {
    test('Stufe 1: der Kurzname des eingefrorenen Namens', () {
      expect(
        WorkoutNaming.shortTitle(
          sitzung(trainingName: 'Gym A — Oberkörper Push + Arme'),
        ),
        'Gym A',
      );
    });

    test('Stufe 1: Ein eigener Name ohne Gedankenstrich bleibt ganz', () {
      expect(
        WorkoutNaming.shortTitle(sitzung(trainingName: 'Kurzhantel zuhause')),
        'Kurzhantel zuhause',
      );
    });

    test('Stufe 1 geht dem Workout vor', () {
      expect(
        WorkoutNaming.shortTitle(
          sitzung(workout: Workout.a, trainingName: 'Altes Training'),
        ),
        'Altes Training',
      );
    });

    test('Stufe 2: das Label des Workouts', () {
      expect(WorkoutNaming.shortTitle(sitzung(workout: Workout.a)), 'Gym A');
      expect(WorkoutNaming.shortTitle(sitzung(workout: Workout.d)), 'Gym D');
      expect(WorkoutNaming.shortTitle(sitzung(workout: Workout.push)), 'Push');
      expect(WorkoutNaming.shortTitle(sitzung(workout: Workout.legs)), 'Legs');
    });

    test('Stufe 2: Für jeden Enum-Fall ist es `Workout.label`', () {
      // Genau das, was `gym_verlauf_texte.dart` heute liest
      // (`sitzung.workout?.label`) — für jede bestehende Sitzung unverändert.
      for (final workout in Workout.values) {
        expect(
          WorkoutNaming.shortTitle(sitzung(workout: workout)),
          workout.label,
          reason: workout.code,
        );
      }
    });

    test('Stufe 3: null, die Ansicht schreibt „Training"', () {
      expect(WorkoutNaming.shortTitle(sitzung()), isNull);
      expect(WorkoutNaming.shortTitle(sitzung(trainingId: 'U1')), isNull);
    });
  });
}
