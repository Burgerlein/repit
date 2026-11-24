import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutTemplates`** — die Start-Templates **Push, Pull,
/// Legs**, der Tombstone als reine Funktion, das Netz `fromEnum` und die
/// Start-Rotation (#532). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitte 4.3, 5.7 und 21 — **und die Nachträge 22 bis 24, die ältere
/// Abschnitte schlagen.**
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Nachträge bewachen
///
/// - **Abschnitt 23 (Tim, 19.11.2026): „Gym A–D löschen und nur
///   Push/Pull/Legs reinnehmen, für den Anfang".** `all` ist **genau drei**
///   Templates, in der Reihenfolge Push, Pull, Legs — **nicht** A–D, nicht
///   sieben, nicht vier. Gruppe „Die drei Start-Templates".
/// - **Abschnitt 23: `fromEnum(Workout)` ist nur das Netz** für laufende
///   Entwürfe mit Code `A`–`D` und die bestehenden Workout-Tests — nie in
///   `all`, nie in `missing`, nie eingespielt. Gruppen „Gym A–D sind keine
///   Templates" und „fromEnum".
/// - **Abschnitt 23: Die Start-Rotation ist Push, Pull, Legs**, ohne
///   Wochentage, aus `all` abgeleitet. Gruppe „initialRotation".
/// - **Abschnitt 22 Nr. 1 ist damit umgekehrt** (dort stand „nur Gym
///   A–D"); die alte Fassung gilt nicht mehr. Wer diese Datei mit einer
///   Spec liest, in der 4.3 noch A–D nennt, liest die ältere Fassung.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Push/Pull/Legs als Start-Templates,
///   Gym A–D nicht (19.11.2026, Spec 23); Tag-Vorbelegung „Gym" (Spec 23);
///   Gelöschtes kommt bei einem Update nicht wieder — Tombstone (18.11.2026,
///   #531/#532).
/// - **Folgerung aus dem Code:** Die `id` ist `Workout.code`; der Name ist
///   `'${label} — ${title}'`, wie ihn die Schirme heute zusammensetzen
///   (Spec 4.3); Übungen und Sätze kommen aus
///   `ExerciseCatalog.exercisesFor`.
/// - **Vorschlag, hier vorausgesetzt:** die eingetragenen Dauern **70/70/60**
///   (= `Workout.minutes`, Plan 12, Spec 4.3 „[Vorschlag]"). **Tim hat die
///   Zahlen nicht bestätigt.** Ebenso: der Tag „Gym" an allen drei (Plan 12).
/// - **Festlegung des Test-Agenten:** was `fromEnum` über `id` und `name`
///   hinaus trägt — **nichts**; siehe unten.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_templates.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutTemplates {
///   static List<WorkoutDefinition> get all;        // Push, Pull, Legs
///   static List<WorkoutDefinition> missing(Set<String> knownIds);
///   static WorkoutDefinition? byId(String id);
///   static WorkoutDefinition fromEnum(Workout workout);
///   static List<String> get initialRotation;       // ['Push', 'Pull', 'Legs']
/// }
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **`category`, `tags`, `enteredMinutes` von `fromEnum`.** Die Spec
///   sagt nur: „liefert die Definition eines Enum-Workouts aus dem Katalog,
///   wird nie eingespielt". Ob die Definition für Gym A als `template` oder
///   `own` gilt, ob sie „Gym" trägt und ob sie `Workout.minutes` als
///   eingetragene Dauer führt (sonst fiele die Vorbelegung der Erfassung
///   von „ca. 70 min" auf die Schätzung 55), steht nirgends. **Gemeldet,
///   nicht entschieden.** Getestet sind `id`, `name`, Übungen, `isDraft`.
/// - **Dass `all` bei jedem Zugriff dieselbe Liste liefert.** Spec 21 führt
///   `all` als Getter; „gehalten, nicht je Zugriff gerechnet" gilt für
///   Provider, nicht für diese Schicht.
/// - **Der Einspielvorgang selbst** (`spieleTemplatesEin`,
///   `spieleRotationEin`, der Merker) — Datenbank, `app/test/data/`.

/// Die Übungen eines Templates als Liste von (Kennung, Sätze), **von Hand
/// aus dem Katalog** — Reihenfolge der Spec `docs/SPEC.md` 4.4.
const pushUebungen = [
  ('benchPress', 4),
  ('inclineDumbbellPress', 3),
  ('shoulderPressMachine', 3),
  ('cableFly', 3),
  ('lateralRaise', 4),
  ('tricepsPushdown', 3),
  ('overheadTriceps', 3),
];

const pullUebungen = [
  ('pullUp', 4),
  ('barbellRow', 4),
  ('cableRowClose', 3),
  ('straightArmPulldown', 3),
  ('facePull', 3),
  ('backExtension', 3),
  ('hammerCurl', 3),
];

const legsUebungen = [
  ('legPress', 4),
  ('romanianDeadlift', 3),
  ('splitSquat', 3),
  ('legCurl', 3),
  ('hipAbduction', 3),
  ('calfRaiseStanding', 6),
  ('legExtension', 3),
];

List<WorkoutExercise> ausKatalog(Workout workout) => [
  for (final exercise in ExerciseCatalog.exercisesFor(workout))
    WorkoutExercise.fromCatalog(exercise),
];

WorkoutDefinition vorlage(String id) =>
    WorkoutTemplates.all.firstWhere((d) => d.id == id);

void main() {
  // -------------------------------------------------------------------------
  group('Die drei Start-Templates (Spec 23)', () {
    test('`all` ist genau Push, Pull, Legs — in dieser Reihenfolge', () {
      expect(WorkoutTemplates.all.map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('Es sind drei, nicht vier und nicht sieben', () {
      expect(WorkoutTemplates.all, hasLength(3));
    });

    test('Alle drei sind Templates und keine Entwürfe', () {
      for (final template in WorkoutTemplates.all) {
        expect(
          template.category,
          WorkoutCategory.template,
          reason: template.id,
        );
        expect(template.isDraft, isFalse, reason: template.id);
      }
    });

    test('Die Namen sind „Label — Titel", wie die Schirme sie setzen', () {
      // `Workout.label` für Push ist `Push` (nicht „Gym Push"), der Titel
      // steht in `Workout.title`.
      expect(vorlage('Push').name, 'Push — Brust, Schultern, Trizeps');
      expect(vorlage('Pull').name, 'Pull — Rücken, hintere Schulter, Bizeps');
      expect(vorlage('Legs').name, 'Legs — Beine komplett');
    });

    test('Jedes Template trägt den Tag „Gym" (Plan 12, Vorschlag)', () {
      for (final template in WorkoutTemplates.all) {
        expect(template.tags, ['Gym'], reason: template.id);
      }
    });

    test('Die eingetragenen Dauern sind 70, 70 und 60 (Vorschlag)', () {
      // Nicht `null`: Mit `null` stünde bei Push die Schätzung 55 statt „ca.
      // 70 min" — eine sichtbare Änderung an den bestehenden Schirmen.
      expect(vorlage('Push').enteredMinutes, 70);
      expect(vorlage('Pull').enteredMinutes, 70);
      expect(vorlage('Legs').enteredMinutes, 60);
    });

    test('Push: sieben Übungen, 23 Sätze, in der Reihenfolge der Spec', () {
      final uebungen = vorlage('Push').exercises;
      expect([for (final u in uebungen) (u.exerciseId, u.sets)], pushUebungen);
      expect(uebungen.fold<int>(0, (summe, u) => summe + u.sets), 23);
    });

    test('Pull: sieben Übungen, 23 Sätze, in der Reihenfolge der Spec', () {
      final uebungen = vorlage('Pull').exercises;
      expect([for (final u in uebungen) (u.exerciseId, u.sets)], pullUebungen);
      expect(uebungen.fold<int>(0, (summe, u) => summe + u.sets), 23);
    });

    test('Legs: sieben Übungen, 25 Sätze, in der Reihenfolge der Spec', () {
      final uebungen = vorlage('Legs').exercises;
      expect([for (final u in uebungen) (u.exerciseId, u.sets)], legsUebungen);
      expect(uebungen.fold<int>(0, (summe, u) => summe + u.sets), 25);
    });

    test('Die Übungen sind die des Katalogs, als Werte kopiert', () {
      // Sätze und Wiederholungsbereich: die Katalogwerte; `increment` bleibt
      // `null` — „aus dem Katalog", in dieser Stufe nie etwas anderes (#537).
      expect(vorlage('Push').exercises, ausKatalog(Workout.push));
      expect(vorlage('Pull').exercises, ausKatalog(Workout.pull));
      expect(vorlage('Legs').exercises, ausKatalog(Workout.legs));
      for (final template in WorkoutTemplates.all) {
        for (final uebung in template.exercises) {
          expect(uebung.increment, isNull, reason: template.id);
        }
      }
    });

    test('Jede Übung der Templates kennt der Katalog', () {
      for (final template in WorkoutTemplates.all) {
        for (final uebung in template.exercises) {
          expect(uebung.resolve(), isNotNull, reason: uebung.exerciseId);
        }
      }
    });

    test('Die Templates bestehen die eigene Prüfung', () {
      // Ein Template, das `WorkoutRules` ablehnt, ließe sich nicht kopieren
      // und speichern.
      for (final template in WorkoutTemplates.all) {
        expect(WorkoutRules.check(template), isEmpty, reason: template.id);
      }
    });

    test('Die Kennungen sind eindeutig', () {
      final ids = WorkoutTemplates.all.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  // -------------------------------------------------------------------------
  group('Gym A–D sind keine Templates (Spec 23)', () {
    // Sie bleiben Enum-Fälle und Codes — für die Übernahme alter Daten und
    // die eingefrorenen Namen im Verlauf —, aber **nicht** als
    // ausgelieferte Templates: kein Tombstone, keine Kopie, keine Zeile.

    test('Keine Kennung A bis D steht in `all`', () {
      final ids = WorkoutTemplates.all.map((d) => d.id).toSet();
      for (final code in ['A', 'B', 'C', 'D']) {
        expect(ids.contains(code), isFalse, reason: code);
      }
    });

    test('`byId` kennt A bis D nicht', () {
      for (final code in ['A', 'B', 'C', 'D']) {
        expect(WorkoutTemplates.byId(code), isNull, reason: code);
      }
    });

    test(
      '`missing` nennt A bis D nie — auch nicht, wenn nichts bekannt ist',
      () {
        final ids = WorkoutTemplates.missing({}).map((d) => d.id).toSet();
        expect(ids, {'Push', 'Pull', 'Legs'});
      },
    );

    test('Bekannte A–D ändern nichts an `missing`', () {
      // Ein Gerät, auf dem früher einmal eine Zeile `A` stand, bekommt die
      // drei Templates trotzdem.
      expect(WorkoutTemplates.missing({'A', 'B', 'C', 'D'}).map((d) => d.id), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });
  });

  // -------------------------------------------------------------------------
  group('missing — der Tombstone als reine Funktion', () {
    test(
      'Ist nichts bekannt, fehlen alle drei, in der Reihenfolge von `all`',
      () {
        expect(WorkoutTemplates.missing({}), WorkoutTemplates.all);
      },
    );

    test('Ein bekanntes Template fehlt nicht', () {
      expect(WorkoutTemplates.missing({'Pull'}).map((d) => d.id), [
        'Push',
        'Legs',
      ]);
    });

    test('Sind alle bekannt, fehlt keines', () {
      expect(WorkoutTemplates.missing({'Push', 'Pull', 'Legs'}), isEmpty);
    });

    test('„Bekannt" ist lebend **oder** gelöscht — die Funktion unterscheidet '
        'nicht', () {
      // Der Tombstone: `knownIds` enthält auch die Kennungen gelöschter
      // Templates, und genau deshalb kommen sie nicht wieder.
      final lebendUndGeloescht = {'Push', 'Legs'};
      expect(WorkoutTemplates.missing(lebendUndGeloescht).map((d) => d.id), [
        'Pull',
      ]);
    });

    test('Fremde Kennungen ändern nichts', () {
      // Eigene Trainings tragen UUIDs.
      expect(WorkoutTemplates.missing({'8F3A-ABCD', 'xyz'}).map((d) => d.id), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('Der Vergleich unterscheidet die Schreibweise', () {
      // Wie `Workout.fromCode`: `'push'` ist nicht `'Push'`.
      expect(WorkoutTemplates.missing({'push'}).map((d) => d.id), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('Die fehlenden Templates sind die aus `all`, nicht Kopien mit '
        'anderem Inhalt', () {
      expect(WorkoutTemplates.missing({'Push'}).first, vorlage('Pull'));
    });
  });

  // -------------------------------------------------------------------------
  group('byId', () {
    test('Findet jedes der drei Templates', () {
      for (final id in ['Push', 'Pull', 'Legs']) {
        expect(WorkoutTemplates.byId(id), vorlage(id), reason: id);
      }
    });

    test('Unbekannte Kennungen geben null, statt etwas zu erfinden', () {
      expect(WorkoutTemplates.byId('xyz'), isNull);
      expect(WorkoutTemplates.byId(''), isNull);
      expect(WorkoutTemplates.byId('push'), isNull);
      expect(WorkoutTemplates.byId('8F3A-ABCD'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('fromEnum — das Netz für die Enum-Workouts (Spec 23)', () {
    // `fromEnum` trägt die Erfassung eines Enum-Workouts, damit ein laufender
    // Entwurf mit Code A–D nicht unsichtbar wird (Tims Gerät ist die einzige
    // Kopie, 4.7) und die 34 Workout-Testdateien weiterlaufen. Es ist
    // **keine Tür zu Gym A–D** und taucht nirgends sonst auf.

    test('Für alle sieben Fälle gibt es eine Definition', () {
      for (final workout in Workout.values) {
        expect(
          () => WorkoutTemplates.fromEnum(workout),
          returnsNormally,
          reason: workout.code,
        );
      }
    });

    test('Die Kennung ist der Code des Workouts', () {
      for (final workout in Workout.values) {
        expect(
          WorkoutTemplates.fromEnum(workout).id,
          workout.code,
          reason: workout.code,
        );
      }
    });

    test('Die Übungen sind die des Katalogs, Fall für Fall', () {
      for (final workout in Workout.values) {
        expect(
          WorkoutTemplates.fromEnum(workout).exercises,
          ausKatalog(workout),
          reason: workout.code,
        );
      }
    });

    test('Die Namen sind „Label — Titel", auch für Gym A–D', () {
      // Die eingefrorenen Namen im Verlauf, Stufe 2 der Namensauflösung.
      expect(
        WorkoutTemplates.fromEnum(Workout.a).name,
        'Gym A — Oberkörper Push + Arme',
      );
      expect(
        WorkoutTemplates.fromEnum(Workout.b).name,
        'Gym B — Läufer-Kraft + Brust',
      );
      expect(
        WorkoutTemplates.fromEnum(Workout.c).name,
        'Gym C — Oberkörper Pull + Arme',
      );
      expect(
        WorkoutTemplates.fromEnum(Workout.d).name,
        'Gym D — Arme + Schultern',
      );
      expect(
        WorkoutTemplates.fromEnum(Workout.push).name,
        'Push — Brust, Schultern, Trizeps',
      );
      expect(
        WorkoutTemplates.fromEnum(Workout.legs).name,
        'Legs — Beine komplett',
      );
    });

    test('Gym A hat sieben Übungen und 23 Sätze, wie es die Erfassung heute '
        'zeigt', () {
      final a = WorkoutTemplates.fromEnum(Workout.a);
      expect(a.exercises, hasLength(7));
      expect(a.exercises.fold<int>(0, (summe, u) => summe + u.sets), 23);
    });

    test('Keine Definition aus `fromEnum` ist ein Entwurf', () {
      for (final workout in Workout.values) {
        expect(
          WorkoutTemplates.fromEnum(workout).isDraft,
          isFalse,
          reason: workout.code,
        );
      }
    });

    test('Gym A–D tauchen durch `fromEnum` nie in `all` auf', () {
      for (final workout in Workout.rotation) {
        WorkoutTemplates.fromEnum(workout);
      }
      expect(WorkoutTemplates.all.map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('Gym A–D tauchen durch `fromEnum` nie in `missing` auf', () {
      for (final workout in Workout.rotation) {
        WorkoutTemplates.fromEnum(workout);
      }
      expect(WorkoutTemplates.missing({}).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('Gym A–D bleiben für `byId` unbekannt, auch nach `fromEnum`', () {
      // Kein Tombstone-Pfad, keine Hintertür: `byId` ist die Template-Suche,
      // `fromEnum` die Enum-Ableitung.
      WorkoutTemplates.fromEnum(Workout.a);
      expect(WorkoutTemplates.byId('A'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('initialRotation — die gespeicherte Rotation zum Start (Spec 23)', () {
    // Tim, 19.11.2026, bei der Planbestätigung: Er steigt selbst auf
    // Push/Pull/Legs um und will die Übergangszeit „Übersicht zeigt PPL,
    // Wochenleiste zeigt A–D" nicht. Die Rotation ist eine geordnete Liste
    // von Kennungen **ohne Wochentage**.

    test('Sind Push, Pull, Legs — in dieser Reihenfolge', () {
      expect(WorkoutTemplates.initialRotation, ['Push', 'Pull', 'Legs']);
    });

    test('Sind genau die Kennungen von `all`, in deren Reihenfolge', () {
      // „Abgeleitet aus `all`, nicht ein zweites Mal getippt."
      expect(
        WorkoutTemplates.initialRotation,
        WorkoutTemplates.all.map((d) => d.id).toList(),
      );
    });

    test('Enthalten kein Gym A bis D', () {
      for (final code in ['A', 'B', 'C', 'D']) {
        expect(WorkoutTemplates.initialRotation.contains(code), isFalse);
      }
    });

    test('Nennen jedes Training höchstens einmal', () {
      // Spec 14.1: Ein Training steht höchstens einmal in der Rotation.
      final rotation = WorkoutTemplates.initialRotation;
      expect(rotation.toSet(), hasLength(rotation.length));
    });

    test('Jede Kennung ist ein Template, das es gibt', () {
      for (final id in WorkoutTemplates.initialRotation) {
        expect(WorkoutTemplates.byId(id), isNotNull, reason: id);
      }
    });

    test('Jede Kennung hat einen Enum-Fall (Plan 18: der Planer rechnet über '
        '`Workout`)', () {
      for (final id in WorkoutTemplates.initialRotation) {
        expect(Workout.fromCode(id), isNotNull, reason: id);
      }
    });
  });
}
