import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutCategory`, `WorkoutExercise` und `WorkoutDefinition`**
/// — die Werttypen hinter „Eigene Trainings" (#532, #531). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitte 4.5, 5.1 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Bearbeiten legt eine Kopie unter „Eigene" an
///   (18.11.2026, #531/#532); der Name der Kopie `Gym A (Kopie)` steht so im
///   Entwurf `gym-training-editor.js`, Variante „kopie".
/// - **Folgerung aus dem Code:** `==`/`hashCode` über alle Felder, Listen
///   inhaltlich und in ihrer Reihenfolge (Hausregel, Fehler `03`).
/// - **Festlegung des Test-Agenten** (die Spec nennt nur Felder, keine
///   Konstruktorform): die Konstruktoren unten.
/// - **Vorschlag der Spec, hier vorausgesetzt:** 17.8 — die Kopie nimmt die
///   eingetragene Dauer mit.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_definition.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// enum WorkoutCategory {
///   template, own;                          // code 'template' / 'eigene'
///   final String code;
///   static WorkoutCategory? fromCode(String code);   // null bei Unbekanntem
/// }
///
/// final class WorkoutExercise {             // ==, hashCode über alle Felder
///   const WorkoutExercise({
///     required String exerciseId, required int sets,
///     required int repLow, required int repHigh, double? increment,
///   });
///   factory WorkoutExercise.fromCatalog(Exercise exercise); // increment: null
///   Exercise? resolve();
/// }
///
/// final class WorkoutDefinition {           // ==, hashCode über alle Felder
///   const WorkoutDefinition({
///     required String id, required String name,
///     required WorkoutCategory category,
///     required List<String> tags, required List<WorkoutExercise> exercises,
///     int? enteredMinutes, bool isDraft = false,
///   });
///   WorkoutDefinition copyAsOwn({required String id});
/// }
/// ```
///
/// Die Tests übergeben jedes Feld ausdrücklich und verlassen sich nicht auf
/// Vorgaben — außer dort, wo die Vorgabe selbst geprüft wird.
///
/// ## Was hier **nicht** getestet wird
///
/// - Prüfregeln (`WorkoutRules`), Dauer, Muskeln, Tags, Templates — eigene
///   Dateien.
/// - Das Speichern der Kopie: `kopiereAlsEigenes` und `speichere` sind
///   Repository (`app/`), nicht Kern.

// ---------------------------------------------------------------------------
// Hilfen — jede Liste wird bei jedem Aufruf **neu** gebaut. Zwei gleich
// aussehende Listen sind damit nie dieselbe Instanz, und ein `==`, das nur
// die Identität vergleicht, fällt durch.
// ---------------------------------------------------------------------------

WorkoutExercise uebung(
  String id, {
  int sets = 3,
  int repLow = 8,
  int repHigh = 12,
  double? increment,
}) => WorkoutExercise(
  exerciseId: id,
  sets: sets,
  repLow: repLow,
  repHigh: repHigh,
  increment: increment,
);

List<WorkoutExercise> zweiUebungen() => [
  uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
  uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
];

WorkoutDefinition definition({
  String id = 'ID1',
  String name = 'Oberkörper zuhause',
  WorkoutCategory category = WorkoutCategory.own,
  List<String>? tags,
  List<WorkoutExercise>? exercises,
  int? enteredMinutes,
  bool isDraft = false,
}) => WorkoutDefinition(
  id: id,
  name: name,
  category: category,
  tags: tags ?? ['Gym', 'Home'],
  exercises: exercises ?? zweiUebungen(),
  enteredMinutes: enteredMinutes,
  isDraft: isDraft,
);

void main() {
  // -------------------------------------------------------------------------
  group('WorkoutCategory', () {
    test('Die gespeicherten Bezeichner sind template und eigene', () {
      // `eigene` ist deutsch, `own` nur der Name des Dart-Falls — der Code
      // steht in der Datenbank (CHECK `kategorie IN ('template', 'eigene')`).
      expect(WorkoutCategory.template.code, 'template');
      expect(WorkoutCategory.own.code, 'eigene');
    });

    test('Es gibt genau diese zwei Kategorien', () {
      expect(WorkoutCategory.values, hasLength(2));
    });

    test('fromCode findet beide Fälle', () {
      expect(WorkoutCategory.fromCode('template'), WorkoutCategory.template);
      expect(WorkoutCategory.fromCode('eigene'), WorkoutCategory.own);
    });

    test('Ein unbekannter Code gibt null, statt etwas zu erfinden', () {
      expect(WorkoutCategory.fromCode('own'), isNull);
      expect(WorkoutCategory.fromCode('Template'), isNull);
      expect(WorkoutCategory.fromCode('EIGENE'), isNull);
      expect(WorkoutCategory.fromCode(''), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutExercise: Gleichheit', () {
    test('Zwei Übungen mit allen gleichen Feldern sind gleich', () {
      final a = uebung('benchPress', sets: 4, repLow: 6, repHigh: 10);
      final b = uebung('benchPress', sets: 4, repLow: 6, repHigh: 10);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Jedes einzelne Feld macht den Unterschied', () {
      final basis = uebung(
        'benchPress',
        sets: 4,
        repLow: 6,
        repHigh: 10,
        increment: 2.5,
      );
      final abweichungen = {
        'exerciseId': uebung(
          'dips',
          sets: 4,
          repLow: 6,
          repHigh: 10,
          increment: 2.5,
        ),
        'sets': uebung(
          'benchPress',
          sets: 5,
          repLow: 6,
          repHigh: 10,
          increment: 2.5,
        ),
        'repLow': uebung(
          'benchPress',
          sets: 4,
          repLow: 7,
          repHigh: 10,
          increment: 2.5,
        ),
        'repHigh': uebung(
          'benchPress',
          sets: 4,
          repLow: 6,
          repHigh: 11,
          increment: 2.5,
        ),
        'increment': uebung(
          'benchPress',
          sets: 4,
          repLow: 6,
          repHigh: 10,
          increment: 1,
        ),
        'increment null': uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
      };
      for (final eintrag in abweichungen.entries) {
        expect(
          basis == eintrag.value,
          isFalse,
          reason: 'Feld ${eintrag.key} muss in == eingehen',
        );
        expect(
          eintrag.value == basis,
          isFalse,
          reason: 'Feld ${eintrag.key}, andere Richtung',
        );
      }
    });

    test('Eine Menge kennt zwei gleiche Übungen nur einmal', () {
      final menge = {uebung('benchPress'), uebung('benchPress')};
      expect(menge, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutExercise.fromCatalog', () {
    test('Übernimmt Sätze und Wiederholungsbereich, nicht die Steigerung', () {
      // Katalog: Bankdrücken 4 × 6–10, Steigerung 2,5. Die Steigerung bleibt
      // in dieser Stufe `null` (#537) und heißt „aus dem Katalog".
      final bank = WorkoutExercise.fromCatalog(
        ExerciseCatalog.all['benchPress']!,
      );
      expect(
        bank,
        uebung('benchPress', sets: 4, repLow: 6, repHigh: 10, increment: null),
      );
      expect(bank.increment, isNull);
    });

    test('Eine Zeitübung übernimmt ihre Sekunden unverändert', () {
      // Seitstütz 3 × 30–45 **Sekunden**.
      final plank = WorkoutExercise.fromCatalog(
        ExerciseCatalog.all['sidePlank']!,
      );
      expect(
        plank,
        uebung('sidePlank', sets: 3, repLow: 30, repHigh: 45, increment: null),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutExercise.resolve', () {
    test('Ohne Überschreibung ist das Ergebnis die Übung des Katalogs', () {
      final katalog = ExerciseCatalog.all['benchPress']!;
      expect(WorkoutExercise.fromCatalog(katalog).resolve(), equals(katalog));
    });

    test('Sätze und Bereich des Trainings ersetzen die des Katalogs', () {
      // Der Weg, auf dem die Erfassung und `Progression.suggest` den Bereich
      // des **Trainings** benutzen (Spec 15.2).
      final aufgeloest = uebung(
        'benchPress',
        sets: 5,
        repLow: 3,
        repHigh: 5,
      ).resolve()!;
      expect(aufgeloest.id, 'benchPress');
      expect(aufgeloest.sets, 5);
      expect(aufgeloest.repLow, 3);
      expect(aufgeloest.repHigh, 5);
    });

    test('Alle übrigen Felder bleiben die des Katalogs', () {
      final katalog = ExerciseCatalog.all['benchPress']!;
      final aufgeloest = uebung(
        'benchPress',
        sets: 5,
        repLow: 3,
        repHigh: 5,
      ).resolve()!;
      expect(aufgeloest.name, katalog.name);
      expect(aufgeloest.cue, katalog.cue);
      expect(aufgeloest.howTo, katalog.howTo);
      expect(aufgeloest.commonMistake, katalog.commonMistake);
      expect(aufgeloest.youTubeQuery, katalog.youTubeQuery);
      expect(aufgeloest.muscles, katalog.muscles);
      expect(aufgeloest.isTimed, katalog.isTimed);
      expect(aufgeloest.allowsAssist, katalog.allowsAssist);
    });

    test('Zeitübung und Unterstützung bleiben erhalten', () {
      expect(
        uebung('sidePlank', repLow: 20, repHigh: 40).resolve()!.isTimed,
        isTrue,
      );
      expect(uebung('dips').resolve()!.allowsAssist, isTrue);
      expect(uebung('benchPress').resolve()!.allowsAssist, isFalse);
    });

    test('Ohne eigene Steigerung gilt die des Katalogs', () {
      // Bankdrücken: 2,5 kg.
      expect(uebung('benchPress', increment: null).resolve()!.increment, 2.5);
    });

    test('Eine eigene Steigerung ersetzt die des Katalogs', () {
      expect(uebung('benchPress', increment: 1.25).resolve()!.increment, 1.25);
    });

    test('Eine unbekannte Übungs-ID gibt null, statt etwas zu erfinden', () {
      expect(uebung('gibtEsNicht').resolve(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutDefinition: Gleichheit', () {
    test('Zwei Definitionen mit allen gleichen Feldern sind gleich', () {
      final a = definition(enteredMinutes: 70);
      final b = definition(enteredMinutes: 70);
      expect(identical(a.exercises, b.exercises), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Jedes einzelne Feld macht den Unterschied', () {
      final basis = definition(enteredMinutes: 70);
      final abweichungen = <String, WorkoutDefinition>{
        'id': definition(id: 'ID2', enteredMinutes: 70),
        'name': definition(name: 'Anderer Name', enteredMinutes: 70),
        'category': definition(
          category: WorkoutCategory.template,
          enteredMinutes: 70,
        ),
        'tags': definition(tags: ['Gym'], enteredMinutes: 70),
        'exercises': definition(
          exercises: [uebung('benchPress', sets: 4, repLow: 6, repHigh: 10)],
          enteredMinutes: 70,
        ),
        'enteredMinutes': definition(enteredMinutes: 60),
        'enteredMinutes null': definition(enteredMinutes: null),
        'isDraft': definition(enteredMinutes: 70, isDraft: true),
      };
      for (final eintrag in abweichungen.entries) {
        expect(
          basis == eintrag.value,
          isFalse,
          reason: 'Feld ${eintrag.key} muss in == eingehen',
        );
        expect(
          eintrag.value == basis,
          isFalse,
          reason: 'Feld ${eintrag.key}, andere Richtung',
        );
      }
    });

    test('Die Reihenfolge der Tags zählt', () {
      // Die Anzeigereihenfolge der Tags ist abgelegt (`gym_training_tags.pos`).
      expect(
        definition(tags: ['Gym', 'Home']) == definition(tags: ['Home', 'Gym']),
        isFalse,
      );
    });

    test('Die Reihenfolge der Übungen zählt', () {
      // Darts `==` auf `List` wäre Identität; die Reihenfolge ist abgelegt
      // (`gym_training_uebungen.pos`) und gehört zum Training.
      final vorwaerts = definition(exercises: zweiUebungen());
      final rueckwaerts = definition(
        exercises: zweiUebungen().reversed.toList(),
      );
      expect(vorwaerts == rueckwaerts, isFalse);
    });

    test('Ein Unterschied in einer einzelnen Übung macht die Definition '
        'ungleich', () {
      final a = definition(
        exercises: [
          uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
          uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
        ],
      );
      final b = definition(
        exercises: [
          uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
          uebung('lateralRaise', sets: 5, repLow: 12, repHigh: 20),
        ],
      );
      expect(a == b, isFalse);
    });

    test('Tags und Übungen leer sind gleich leer', () {
      final a = definition(tags: [], exercises: []);
      final b = definition(tags: [], exercises: []);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Eine Menge kennt zwei gleiche Definitionen nur einmal', () {
      // Riverpod rechnet Abgeleitetes neu, sobald die Abhängigkeit ungleich
      // ist — ohne inhaltliches `==` wäre das Fehler `03` im neuen Code.
      final menge = {definition(), definition()};
      expect(menge, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  group('WorkoutDefinition.copyAsOwn', () {
    WorkoutDefinition vorlage() => definition(
      id: 'Push',
      name: 'Push — Brust, Schultern, Trizeps',
      category: WorkoutCategory.template,
      tags: ['Gym'],
      exercises: [
        uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
        uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
      ],
      enteredMinutes: 70,
    );

    test('Die Kopie bekommt die neue Kennung und ist ein Eigenes', () {
      final kopie = vorlage().copyAsOwn(id: 'NEUE-ID');
      expect(kopie.id, 'NEUE-ID');
      expect(kopie.category, WorkoutCategory.own);
    });

    test('Der Name ist der Kurzname und „(Kopie)"', () {
      // Spec 4.5: `'${shortName} (Kopie)'` — aus „Gym A — Oberkörper Push +
      // Arme" wird „Gym A (Kopie)", nicht der ganze lange Name.
      expect(vorlage().copyAsOwn(id: 'X').name, 'Push (Kopie)');
      expect(
        definition(name: 'Gym A — Oberkörper Push + Arme')
            .copyAsOwn(id: 'X')
            .name,
        'Gym A (Kopie)',
      );
    });

    test('Ein Name ohne Gedankenstrich bleibt ganz und bekommt „(Kopie)"', () {
      expect(
        definition(name: 'Kurzhantel zuhause').copyAsOwn(id: 'X').name,
        'Kurzhantel zuhause (Kopie)',
      );
    });

    test('Die Kopie einer Kopie hängt „(Kopie)" noch einmal an', () {
      // Der Kurzname von „Push (Kopie)" ist der ganze Name — es gibt dort
      // keinen „ — ".
      final erste = vorlage().copyAsOwn(id: 'X1');
      expect(erste.copyAsOwn(id: 'X2').name, 'Push (Kopie) (Kopie)');
    });

    test('Die Kopie ist nie ein Entwurf, auch wenn die Vorlage einer ist', () {
      final entwurf = definition(isDraft: true);
      expect(entwurf.copyAsOwn(id: 'X').isDraft, isFalse);
      expect(vorlage().copyAsOwn(id: 'X').isDraft, isFalse);
    });

    test('Tags, Übungen und eingetragene Dauer wandern mit', () {
      // Die Dauer nimmt die Kopie mit — Vorschlag 17.8, hier vorausgesetzt.
      final kopie = vorlage().copyAsOwn(id: 'X');
      expect(kopie.tags, ['Gym']);
      expect(kopie.exercises, vorlage().exercises);
      expect(kopie.enteredMinutes, 70);
    });

    test('Eine geschätzte Dauer bleibt geschätzt, nicht 0', () {
      // `null` heißt „geschätzt" und darf in der Kopie nicht zu 0 werden
      // (Fehler `01`).
      final kopie = definition(enteredMinutes: null).copyAsOwn(id: 'X');
      expect(kopie.enteredMinutes, isNull);
    });

    test('Die Vorlage bleibt unverändert', () {
      final original = vorlage();
      original.copyAsOwn(id: 'X');
      expect(original, equals(vorlage()));
      expect(original.category, WorkoutCategory.template);
      expect(original.id, 'Push');
    });
  });
}
