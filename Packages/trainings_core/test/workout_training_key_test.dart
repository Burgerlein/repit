import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`TrainingKey`**, **`CustomTrainingKey`** und die Schnittstelle
/// von `Workout` (#532). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 3.1 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Folgerung aus dem Code (Spec 3.1):** Ein Enum darf eine
///   Schnittstelle implementieren; `gymLogProvider(Workout.a)` bleibt
///   gültig, wenn der Schlüsseltyp der Familie `TrainingKey` wird. **Die
///   Regel: bestehende Signaturen bleiben übersetzbar** — die 34
///   Testdateien, die `Workout` nennen, laufen unverändert.
/// - **Vorschlag der Spec (3.1, „Konkret [Vorschlag]"), hier
///   vorausgesetzt:** die Form `TrainingKey` / `CustomTrainingKey` /
///   `fromId`. Die Spec nennt es einen Vorschlag; die Tests nageln die
///   Eigenschaften fest, an denen die Erfassung hängt: **nie zwei Schlüssel
///   für dieselbe Kennung** („sonst gäbe es zwei Provider für ein
///   Training").
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/training_key.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`. `Workout` (in `exercise.dart`) bekommt
/// `implements TrainingKey`.
///
/// ```dart
/// abstract interface class TrainingKey {
///   String get id;
///   static TrainingKey fromId(String id);   // Workout oder CustomTrainingKey
/// }
///
/// final class CustomTrainingKey implements TrainingKey {   // ==, hashCode
///   const CustomTrainingKey(String id);
///   final String id;
/// }
///
/// // enum Workout implements TrainingKey { … String get id => code; }
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **`fromId('')`**: eine leere Kennung kann nur ein Programmierfehler
///   sein; die Spec sagt nichts dazu.
/// - **Der Provider** (`gymLogProvider` als Familie über `TrainingKey`) —
///   `app/`.

void main() {
  // -------------------------------------------------------------------------
  group('Workout ist ein TrainingKey', () {
    test('Jeder Enum-Fall ist ein TrainingKey', () {
      for (final workout in Workout.values) {
        expect(workout, isA<TrainingKey>(), reason: workout.code);
      }
    });

    test('Die Kennung ist der gespeicherte Code', () {
      expect(Workout.a.id, 'A');
      expect(Workout.b.id, 'B');
      expect(Workout.c.id, 'C');
      expect(Workout.d.id, 'D');
      expect(Workout.push.id, 'Push');
      expect(Workout.pull.id, 'Pull');
      expect(Workout.legs.id, 'Legs');
    });

    test('Kennung und Code sind für jeden Fall dasselbe', () {
      for (final workout in Workout.values) {
        expect(workout.id, workout.code);
      }
    });

    test('Ein Workout lässt sich dort übergeben, wo ein TrainingKey verlangt '
        'wird', () {
      // Die Regel aus Spec 3.1: Bestehende Aufrufe bleiben gültig.
      String kennung(TrainingKey schluessel) => schluessel.id;
      expect(kennung(Workout.push), 'Push');
    });
  });

  // -------------------------------------------------------------------------
  group('TrainingKey.fromId', () {
    test('Eine Kennung mit Enum-Fall ergibt den Enum-Fall', () {
      for (final workout in Workout.values) {
        final schluessel = TrainingKey.fromId(workout.code);
        expect(schluessel, isA<Workout>(), reason: workout.code);
        expect(identical(schluessel, workout), isTrue, reason: workout.code);
      }
    });

    test('Eine Kennung ohne Enum-Fall ergibt einen CustomTrainingKey', () {
      final schluessel = TrainingKey.fromId('8F3A-ABCD-0001');
      expect(schluessel, isA<CustomTrainingKey>());
      expect(schluessel.id, '8F3A-ABCD-0001');
    });

    test('Nie beides für dieselbe Kennung', () {
      // Sonst gäbe es zwei Provider für ein Training (Spec 3.1).
      for (final kennung in [
        for (final workout in Workout.values) workout.code,
        '8F3A-ABCD-0001',
        'gibtEsNicht',
      ]) {
        final schluessel = TrainingKey.fromId(kennung);
        final istWorkout = schluessel is Workout;
        final istEigener = schluessel is CustomTrainingKey;
        expect(
          istWorkout != istEigener,
          isTrue,
          reason: '$kennung: genau eins von beiden',
        );
      }
    });

    test('Die Kennung des Ergebnisses ist die übergebene', () {
      for (final kennung in ['A', 'Push', 'Legs', 'abc', '8F3A']) {
        expect(TrainingKey.fromId(kennung).id, kennung);
      }
    });

    test('Die Schreibweise zählt, wie bei `Workout.fromCode`', () {
      // `'a'` ist der Name des Dart-Falls, nicht der gespeicherte Code.
      final klein = TrainingKey.fromId('a');
      expect(klein, isA<CustomTrainingKey>());
      expect(klein.id, 'a');
      expect(TrainingKey.fromId('push'), isA<CustomTrainingKey>());
    });

    test('Zweimal dieselbe Kennung ergibt zwei gleiche Schlüssel', () {
      // Eine Familie von Providern hängt an dieser Gleichheit.
      expect(TrainingKey.fromId('Push'), equals(TrainingKey.fromId('Push')));
      expect(
        TrainingKey.fromId('8F3A-ABCD-0001'),
        equals(TrainingKey.fromId('8F3A-ABCD-0001')),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('CustomTrainingKey', () {
    test('Trägt seine Kennung', () {
      expect(CustomTrainingKey('8F3A').id, '8F3A');
    });

    test('Ist ein TrainingKey', () {
      expect(CustomTrainingKey('8F3A'), isA<TrainingKey>());
    });

    test('Gleiche Kennung ist gleich, mit gleichem Hash', () {
      final a = CustomTrainingKey('8F3A');
      final b = CustomTrainingKey('8F3A');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Verschiedene Kennungen sind verschieden', () {
      expect(CustomTrainingKey('8F3A') == CustomTrainingKey('8F3B'), isFalse);
    });

    test('Die Schreibweise unterscheidet', () {
      expect(CustomTrainingKey('abc') == CustomTrainingKey('ABC'), isFalse);
    });

    test('Als Schlüssel einer Menge oder Map zählt der Inhalt', () {
      // Genau so benutzt Riverpod den Schlüssel einer Familie.
      expect({CustomTrainingKey('x'), CustomTrainingKey('x')}, hasLength(1));
      final map = {CustomTrainingKey('x'): 1};
      expect(map[CustomTrainingKey('x')], 1);
      expect(map[CustomTrainingKey('y')], isNull);
    });

    test('Ist nie gleich einem Workout mit derselben Kennung', () {
      // Zwei verschiedene Schlüssel für ein Training wären zwei Provider —
      // `fromId` verhindert, dass sie entstehen; diese Gleichheit sorgt dafür,
      // dass sie auch nicht still verschmelzen.
      expect(CustomTrainingKey('A') == Workout.a, isFalse);
      expect(Workout.a == CustomTrainingKey('A'), isFalse);
      expect(CustomTrainingKey('Push') == Workout.push, isFalse);
    });
  });
}
