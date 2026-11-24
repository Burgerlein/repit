import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **neuen optionalen Parameter `rotation`** von
/// `GymDayPlanner.day` — die Quelle der Wochenleiste und der Fokus-Karte
/// wechselt von `Workout.rotation` (A–D) auf die gespeicherte Rotation
/// (zum Start Push, Pull, Legs). Ticket #532 (Datenteil, vorgezogen aus
/// #536). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitte 14.1, 23 und 24.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Nachträge bewachen
///
/// - **Abschnitt 23 (Tim, 19.11.2026): „Die Rotation-Umstellung wird
///   vorgezogen."** Der Planer liest die gespeicherte Rotation statt
///   `Workout.rotation`; die Logik (Plätze ohne Tag, „heute"/überfällig,
///   Auffüllen wie `_sorted`) bleibt **wörtlich dieselbe**, nur die Quelle
///   wechselt — **drei Plätze statt vier**. Gruppen „Drei Plätze ohne Tag",
///   „Gegen die Rotation gefiltert".
/// - **Die Rotation trägt keine Wochentage** (Spec 23, 24 Nr. 2): Die
///   Plätze kommen ohne Tag aus der Rotation; Wochentage kommen weiter nur
///   aus `planned`. Gruppe „Drei Plätze ohne Tag".
/// - **Abschnitt 24 Nr. 1:** Löschen nimmt ein Training aus der Rotation;
///   die Wochenleiste trägt deshalb **0 bis 3 Plätze**. Gruppe „Weniger als
///   drei Plätze".
/// - **Gym A–D fallen aus der Woche** (Spec 23), auch ein überfälliges oder
///   erledigtes `Workout.d` bekommt keinen Platz. Gruppe „Gegen die
///   Rotation gefiltert".
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Die Rotation wird vorgezogen, Wochenleiste
///   und Fokus-Karte zeigen Push/Pull/Legs (19.11.2026, Spec 23).
/// - **Folgerung (Spec 23, „wörtlich dieselbe"):** Alles, was nicht die
///   Quelle der Plätze betrifft, bleibt wie im bestehenden Planer. Die Fälle
///   unten spiegeln deshalb die von `gym_day_planner_test.dart` mit der
///   anderen Rotation; **ein Fall, der dort anders ausginge als hier, wäre
///   ein Befund.**
/// - **Festlegung des Test-Agenten:** Dass ein **Entwurf** der Erfassung mit
///   einem Workout außerhalb der Rotation (Gym A) die Fokus-Karte trotzdem
///   belegt, aber keinen Platz bekommt. Die Spec sagt „wörtlich dieselbe";
///   der bestehende Planer filtert den Entwurf nicht, und Spec 24 Nr. 5
///   will, dass ein laufender Entwurf mit Code A–D nicht unsichtbar wird.
///   Siehe Gruppe „Der Entwurf der Erfassung".
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// static GymDay day({
///   required DateTime today,
///   required List<PlannedGym> planned,
///   required Map<Workout, DateTime> completed,
///   required List<Workout> overdue,
///   GymDraft? draft,
///   DateTime? surgery,
///   int pauseDays = 14,
///   List<Workout> rotation = Workout.rotation,     // NEU, optional
/// })
/// ```
///
/// Die Vorgabe ist `Workout.rotation`: **Jeder bestehende Aufruf liefert
/// dasselbe wie vorher** — `gym_day_planner_test.dart` und
/// `workout_test.dart` bleiben unverändert grün. Gruppe „Die Vorgabe ist die
/// bisherige Rotation" beweist es für eine Reihe von Eingaben.
///
/// ## Was hier **nicht** getestet wird
///
/// - **Zwei Einträge am selben Wochentag (#426).** Der bestehende Planer
///   bricht bei einem erledigten Treffer ab; die Spec 23 nimmt #426
///   ausdrücklich nicht vor. Hier wird der Fehler weder festgeschrieben
///   noch behoben.
/// - **Wochentage aus der Rotation.** Es gibt sie in dieser Stufe nicht
///   (Spec 24 Nr. 2); `PlannedGym` bleibt die einzige Quelle von Tagen.
/// - **Unbekannte Rotations-Kennung wirft** (Spec 24 Nr. 4): das ist der
///   Provider (`app/`), der Kennungen (`String`) in `Workout` übersetzt —
///   der Planer bekommt schon `List<Workout>`.
///
/// ## Die Kalendertage sind nachgerechnet, nicht angenommen
///
/// Dieselbe Verankerung wie in `gym_day_planner_test.dart`: 01.01.2027 =
/// Freitag, daraus 01.02.2027 = Montag. Also
///
///   Mo 08.02.2027 · Di 09. · Mi 10. · Do 11. · Fr 12. · Sa 13. · So 14.
///   Mo 15.02.2027 · Mo 22.02.2027
///
/// Alle Zeitpunkte UTC, alle Daten erfunden — insbesondere das OP-Datum.

// ---------------------------------------------------------------------------
// Hilfen
// ---------------------------------------------------------------------------

/// Ein Zeitpunkt mitten im Berliner Kalendertag, als UTC. 09:00 UTC ist in
/// Berlin 10:00 (Winterzeit) — derselbe Kalendertag.
DateTime amTag(int jahr, int monat, int tag) =>
    DateTime.utc(jahr, monat, tag, 9);

/// Der Berliner Tagesbeginn als UTC-Zeitpunkt.
DateTime tagesbeginn(int jahr, int monat, int tag) =>
    BerlinCalendar.startOfDay(amTag(jahr, monat, tag));

/// Die Start-Rotation aus Spec 23.
const pushPullLegs = [Workout.push, Workout.pull, Workout.legs];

/// Ein Tageszustand, standardmäßig mit der Start-Rotation.
GymDay tagesplan(
  DateTime heute, {
  List<PlannedGym> plan = const [],
  Map<Workout, DateTime> completed = const {},
  List<Workout> overdue = const [],
  GymDraft? draft,
  DateTime? surgery,
  int pauseDays = 14,
  List<Workout> rotation = pushPullLegs,
}) => GymDayPlanner.day(
  today: heute,
  planned: plan,
  completed: completed,
  overdue: overdue,
  draft: draft,
  surgery: surgery,
  pauseDays: pauseDays,
  rotation: rotation,
);

List<Workout> workoutsVon(GymDay tag) =>
    tag.week.map((slot) => slot.workout).toList();

GymSlot? platzFuer(GymDay tag, Workout workout) {
  for (final slot in tag.week) {
    if (slot.workout == workout) return slot;
  }
  return null;
}

void main() {
  // -------------------------------------------------------------------------
  group('Drei Plätze ohne Tag', () {
    test('Ein leerer Plan ergibt drei Plätze ohne festen Tag', () {
      // Mo, 08.02.2027. Das Gegenstück zu „Ein leerer Plan ergibt trotzdem
      // vier Plätze ohne festen Tag" — drei statt vier.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(workoutsVon(tag), [Workout.push, Workout.pull, Workout.legs]);
      expect(tag.week, hasLength(3));
      for (final slot in tag.week) {
        expect(slot.weekday, isNull);
        expect(slot.status, isA<Open>());
      }
    });

    test('Ohne Wochentag gibt es keinen „heute" und kein „als Nächstes"', () {
      // Mo, 08.02.2027: Die Rotation hat keine Tage; `planned` ist leer.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
      expect(fokus.overdue, isNull);
    });

    test('Die Plätze stehen in der Reihenfolge der Rotation', () {
      // Die Reihenfolge der gespeicherten Rotation ist die der Leiste.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        rotation: [Workout.pull, Workout.push, Workout.legs],
      );
      expect(workoutsVon(tag), [Workout.pull, Workout.push, Workout.legs]);
    });

    test('Kein Platz in der Woche trägt ein Gym A bis D', () {
      final tag = tagesplan(amTag(2027, 2, 8));
      for (final workout in Workout.rotation) {
        expect(platzFuer(tag, workout), isNull, reason: workout.code);
      }
    });

    test('Die Rotation füllt die Leiste auf, auch wenn der Plan ein Workout '
        'nicht führt', () {
      // Mo, 08.02.2027, Plan führt allein Push.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
      );
      expect(workoutsVon(tag), [Workout.push, Workout.pull, Workout.legs]);
      expect(tag.week[0].status, isA<Today>());
      for (final slot in tag.week.skip(1)) {
        expect(slot.weekday, isNull);
        expect(slot.status, isA<Open>());
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Plätze mit Wochentag aus `planned`', () {
    final plan = [
      PlannedGym(workout: Workout.push, weekday: DateTime.monday),
      PlannedGym(workout: Workout.pull, weekday: DateTime.wednesday),
    ];

    test('Am Montag ist Push geplant', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8), plan: plan);
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.push);
      expect(workoutsVon(tag), [Workout.push, Workout.pull, Workout.legs]);
      expect(tag.week.map((slot) => slot.weekday).toList(), [
        DateTime.monday,
        DateTime.wednesday,
        null,
      ]);
      expect(tag.week[0].status, isA<Today>());
      expect(tag.week[1].status, isA<Open>());
      expect(tag.week[2].status, isA<Open>());
    });

    test('Am Dienstag ist Ruhetag, als Nächstes kommt Pull am Mittwoch', () {
      // Di, 09.02.2027; Push lief am Mo, 08.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        plan: plan,
        completed: {Workout.push: amTag(2027, 2, 8)},
      );
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.pull);
      expect(fokus.inDays, 1);
      expect(fokus.overdue, isNull);
    });

    test('Ein in dieser Woche verpasstes Workout gilt als überfällig', () {
      // Mi, 10.02.2027: Push stand am Mo und ist nicht erledigt.
      final tag = tagesplan(amTag(2027, 2, 10), plan: plan);
      expect(platzFuer(tag, Workout.push)!.status, isA<Overdue>()); // Mo < Mi
      expect(platzFuer(tag, Workout.pull)!.status, isA<Today>()); // Mi == Mi
      expect(platzFuer(tag, Workout.legs)!.status, isA<Open>()); // kein Tag
      expect((tag.focus as Planned).workout, Workout.pull);
    });

    test('Die Plätze mit Tag stehen nach Wochentag, die ohne Tag dahinter', () {
      // Mo, 08.02.2027; Plan absichtlich verdreht und mit Legs am Donnerstag.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [
          PlannedGym(workout: Workout.legs, weekday: DateTime.thursday),
          PlannedGym(workout: Workout.push, weekday: DateTime.monday),
        ],
      );
      expect(workoutsVon(tag), [Workout.push, Workout.legs, Workout.pull]);
      expect(tag.week[2].weekday, isNull);
    });

    test('Ein Workout ohne festen Tag kommt als Nächstes nie in Frage', () {
      // Sa, 13.02.2027 — Push und Pull liegen hinter uns, Legs hat keinen
      // Tag. „In 3 Tagen" wäre für Legs eine Zahl ohne Bedeutung.
      final tag = tagesplan(amTag(2027, 2, 13), plan: plan);
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
    });

    test('Das Abschlussdatum im Platz ist der Berliner Tagesbeginn', () {
      // Mi, 10.02.2027; Push wurde Mo, 08.02.2027 um 21:00 Berliner Zeit
      // abgeschlossen (20:00 UTC, Winterzeit).
      final tag = tagesplan(
        amTag(2027, 2, 10),
        plan: plan,
        completed: {Workout.push: DateTime.utc(2027, 2, 8, 20)},
      );
      expect(
        (platzFuer(tag, Workout.push)!.status as Done).date,
        tagesbeginn(2027, 2, 8),
      );
    });

    test('Ein Abschluss aus der Vorwoche füllt keinen Platz', () {
      // Mo, 15.02.2027. Push lief So, 14.02.2027, und der Sonntag gehört
      // noch zur Woche davor.
      final tag = tagesplan(
        amTag(2027, 2, 15),
        plan: plan,
        completed: {Workout.push: amTag(2027, 2, 14)},
      );
      expect(platzFuer(tag, Workout.push)!.status, isA<Today>());
      expect(tag.doneThisWeek, 0);
    });

    test('Ein erledigter Platz zählt, auch ohne festen Tag', () {
      // Mi, 10.02.2027; Legs ohne Tag am Di nachgeholt.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        plan: plan,
        completed: {Workout.legs: amTag(2027, 2, 9)},
      );
      expect(platzFuer(tag, Workout.legs)!.status, isA<Done>());
      expect(tag.doneThisWeek, 1);
    });

    test('Ist die Woche durch, zählt die Wochenleiste drei', () {
      // Fr, 12.02.2027: Push Mo, Pull Mi, Legs Do (ohne festen Tag).
      final tag = tagesplan(
        amTag(2027, 2, 12),
        plan: plan,
        completed: {
          Workout.push: amTag(2027, 2, 8),
          Workout.pull: amTag(2027, 2, 10),
          Workout.legs: amTag(2027, 2, 11),
        },
      );
      expect(tag.doneThisWeek, 3);
      expect(tag.week, hasLength(3));
      expect(tag.focus, isA<Rest>());
    });
  });

  // -------------------------------------------------------------------------
  group('Gegen die Rotation gefiltert', () {
    // Spec 23: Gym A–D fallen aus der Woche, auch auf Tims Gerät. Überfällig
    // und geplant werden **gegen die übergebene Rotation** gefiltert, nicht
    // mehr gegen `Workout.rotation`.

    test('Ein überfälliges Gym D fällt weg', () {
      // Der Altplaner nähme es auf — mit der Rotation Push/Pull/Legs nicht.
      final tag = tagesplan(amTag(2027, 2, 9), overdue: [Workout.d]);
      expect((tag.focus as Rest).overdue, isNull);
      expect(platzFuer(tag, Workout.d), isNull);
      for (final slot in tag.week) {
        expect(slot.status, isA<Open>());
      }
    });

    test('Ein überfälliges Legs zählt', () {
      // Der Altplaner schnitte es ab, weil Legs „frei wählbar" war
      // (`Workout.freelyChosen`) — das gilt mit der Rotation nicht mehr.
      final tag = tagesplan(amTag(2027, 2, 9), overdue: [Workout.legs]);
      expect((tag.focus as Rest).overdue, Workout.legs);
      expect(platzFuer(tag, Workout.legs)!.status, isA<Overdue>());
      expect(platzFuer(tag, Workout.legs)!.weekday, isNull);
    });

    test('Ein überfälliges Push zählt ebenfalls', () {
      final tag = tagesplan(amTag(2027, 2, 9), overdue: [Workout.push]);
      expect((tag.focus as Rest).overdue, Workout.push);
      expect(platzFuer(tag, Workout.push)!.status, isA<Overdue>());
    });

    test('Neben einem Gym D bleibt das echte überfällige Workout erhalten', () {
      // Die Fokus-Karte nennt das erste Überfällige **innerhalb** der
      // Rotation, nicht das erste der Liste.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        overdue: [Workout.d, Workout.legs],
      );
      expect((tag.focus as Rest).overdue, Workout.legs);
    });

    test('Von mehreren überfälligen zählt das erste der Liste', () {
      final tag = tagesplan(
        amTag(2027, 2, 9),
        overdue: [Workout.pull, Workout.legs],
      );
      expect((tag.focus as Rest).overdue, Workout.pull);
    });

    test('Ein geplantes Gym A bekommt keinen Platz und ist nie „heute"', () {
      // Mo, 08.02.2027: Der Plan führt Gym A am Montag und Push am
      // Mittwoch. A liegt nicht in der Rotation.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [
          PlannedGym(workout: Workout.a, weekday: DateTime.monday),
          PlannedGym(workout: Workout.push, weekday: DateTime.wednesday),
        ],
      );
      expect(workoutsVon(tag), [Workout.push, Workout.pull, Workout.legs]);
      expect(platzFuer(tag, Workout.a), isNull);
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.push);
      expect(fokus.inDays, 2);
    });

    test('Ein erledigtes Gym D füllt keinen Platz der Woche', () {
      // Mi, 10.02.2027; Gym D lief am Mo.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.d: amTag(2027, 2, 8)},
      );
      expect(platzFuer(tag, Workout.d), isNull);
      expect(tag.doneThisWeek, 0);
    });

    test('Ein erledigtes Push füllt seinen Platz', () {
      // Mi, 10.02.2027; Push lief am Mo.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.push: amTag(2027, 2, 8)},
      );
      expect(platzFuer(tag, Workout.push)!.status, isA<Done>());
      expect(tag.doneThisWeek, 1);
    });

    test('Erledigt in dieser Woche schlägt überfällig', () {
      // Mi, 10.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.push: amTag(2027, 2, 8)},
        overdue: [Workout.push],
      );
      expect(platzFuer(tag, Workout.push)!.status, isA<Done>());
    });

    test('Überfällig von außen schlägt den Kalender', () {
      // Mi, 10.02.2027: Pull steht erst am Do und wäre nach dem Kalender
      // offen — die Liste von außen wiegt schwerer.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        plan: [PlannedGym(workout: Workout.pull, weekday: DateTime.thursday)],
        overdue: [Workout.pull],
      );
      expect(platzFuer(tag, Workout.pull)!.status, isA<Overdue>());
    });
  });

  // -------------------------------------------------------------------------
  group('Weniger als drei Plätze (Spec 24 Nr. 1)', () {
    // Löschen eines Trainings nimmt es aus der Rotation; die Leiste trägt
    // deshalb 0 bis 3 Plätze, und einen Weg zurück gibt es in dieser Stufe
    // nicht.

    test('Zwei Plätze, wenn ein Training aus der Rotation genommen ist', () {
      final tag = tagesplan(
        amTag(2027, 2, 8),
        rotation: [Workout.push, Workout.legs],
      );
      expect(workoutsVon(tag), [Workout.push, Workout.legs]);
      expect(platzFuer(tag, Workout.pull), isNull);
    });

    test('Ein Plan-Eintrag für das herausgenommene Training bekommt keinen '
        'Platz', () {
      // Mo, 08.02.2027: Pull war für Montag eingeplant, steht aber nicht
      // mehr in der Rotation.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [PlannedGym(workout: Workout.pull, weekday: DateTime.monday)],
        rotation: [Workout.push, Workout.legs],
      );
      expect(platzFuer(tag, Workout.pull), isNull);
      expect(tag.focus, isA<Rest>());
    });

    test('Ein Platz', () {
      final tag = tagesplan(amTag(2027, 2, 8), rotation: [Workout.legs]);
      expect(workoutsVon(tag), [Workout.legs]);
      expect(tag.week.single.status, isA<Open>());
      expect(tag.week.single.weekday, isNull);
    });

    test('Keine Rotation ergibt keine Plätze und einen Ruhetag', () {
      // Mo, 08.02.2027. Die Leiste für null Plätze ist nicht entworfen
      // (Spec 18); der Planer liefert dafür eine leere Woche, keinen Fehler.
      final tag = tagesplan(amTag(2027, 2, 8), rotation: []);
      expect(tag.week, isEmpty);
      expect(tag.doneThisWeek, 0);
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
      expect(fokus.overdue, isNull);
    });

    test(
      'Ohne Rotation zählen weder Plan noch Überfälliges noch Erledigtes',
      () {
        // Mi, 10.02.2027.
        final tag = tagesplan(
          amTag(2027, 2, 10),
          plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
          completed: {Workout.push: amTag(2027, 2, 8)},
          overdue: [Workout.legs],
          rotation: [],
        );
        expect(tag.week, isEmpty);
        expect(tag.doneThisWeek, 0);
        expect((tag.focus as Rest).overdue, isNull);
        expect((tag.focus as Rest).next, isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  group('Der Entwurf der Erfassung', () {
    test('Ein angefangenes Legs steht im Vordergrund und läuft im Platz', () {
      final tag = tagesplan(
        amTag(2027, 2, 8),
        draft: GymDraft(
          workout: Workout.legs,
          doneExercises: 2,
          totalExercises: 7,
        ),
      );
      expect(tag.focus, isA<InProgress>());
      final fokus = tag.focus as InProgress;
      expect(fokus.workout, Workout.legs);
      expect(fokus.done, 2);
      expect(fokus.total, 7);
      expect(platzFuer(tag, Workout.legs)!.status, isA<Running>());
      expect(platzFuer(tag, Workout.push)!.status, isA<Open>());
    });

    test('Ein Entwurf ohne erfasste Übung gilt als geplant, nicht als '
        'angefangen', () {
      // Mo, 08.02.2027, Push am Montag eingeplant.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
        draft: GymDraft(
          workout: Workout.push,
          doneExercises: 0,
          totalExercises: 7,
        ),
      );
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.push);
      expect(platzFuer(tag, Workout.push)!.status, isNot(isA<Running>()));
    });

    test('Ein laufender Entwurf schlägt den erledigten Platz', () {
      // Mi, 10.02.2027: Push ist diese Woche erledigt und zugleich
      // angefangen — der Platz sagt „läuft", nicht „erledigt".
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.push: amTag(2027, 2, 8)},
        draft: GymDraft(
          workout: Workout.push,
          doneExercises: 1,
          totalExercises: 7,
        ),
      );
      expect(platzFuer(tag, Workout.push)!.status, isA<Running>());
      expect(tag.focus, isA<InProgress>());
    });

    test('Ein laufender Entwurf für Gym A belegt die Fokus-Karte, bekommt aber '
        'keinen Platz', () {
      // Spec 24 Nr. 5: `fromEnum` ist das Netz für laufende Entwürfe mit
      // Code A–D — der Entwurf darf nicht unsichtbar werden (Tims Gerät ist
      // die einzige Kopie). Der Planer filtert den Entwurf wie bisher nicht;
      // Gym A bleibt trotzdem außerhalb der Woche.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        draft: GymDraft(
          workout: Workout.a,
          doneExercises: 2,
          totalExercises: 7,
        ),
      );
      expect(tag.focus, isA<InProgress>());
      expect((tag.focus as InProgress).workout, Workout.a);
      expect(tag.week, hasLength(3));
      expect(platzFuer(tag, Workout.a), isNull);
      for (final slot in tag.week) {
        expect(slot.status, isNot(isA<Running>()), reason: slot.workout.code);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Die Erholung nach einer OP hat weiter Vorrang', () {
    // Das OP-Datum ist erfunden und steht nirgends im Quelltext der App.

    test('Alle Plätze der Rotation sind pausiert', () {
      // OP Mo, 08.02.2027, Pause 14 Tage → Wiedereinstieg Mo, 22.02.2027.
      // Heute Mi, 10.02.2027: Tag 2 nach der OP.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
        surgery: amTag(2027, 2, 8),
      );
      expect(tag.focus, isA<Recovery>());
      final erholung = tag.focus as Recovery;
      expect(erholung.dayAfterSurgery, 2);
      expect(erholung.earliestReturn, tagesbeginn(2027, 2, 22));
      expect(workoutsVon(tag), [Workout.push, Workout.pull, Workout.legs]);
      for (final slot in tag.week) {
        expect(slot.status, isA<Paused>());
      }
    });

    test('Am Tag des Wiedereinstiegs läuft der Betrieb wieder', () {
      // Mo, 22.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 22),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
        surgery: amTag(2027, 2, 8),
      );
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.push);
    });

    test('Ohne OP-Datum gibt es keine Erholung', () {
      final tag = tagesplan(amTag(2027, 2, 10));
      expect(tag.focus, isNot(isA<Recovery>()));
    });
  });

  // -------------------------------------------------------------------------
  group('Die Vorgabe ist die bisherige Rotation', () {
    // Der Beweis, dass der Parameter **additiv** ist: Ohne `rotation` — wie
    // jeder bestehende Aufruf — kommt dasselbe heraus wie mit
    // `Workout.rotation` ausdrücklich, und das ist die Woche A bis D.

    /// Ein Aufruf des Planers — mit ausdrücklicher Rotation oder ganz ohne den
    /// Parameter, so wie jeder bestehende Aufruf.
    GymDay aufruf(
      bool ausdruecklich,
      DateTime heute, {
      List<PlannedGym> plan = const [],
      Map<Workout, DateTime> completed = const {},
      List<Workout> overdue = const [],
      GymDraft? draft,
      DateTime? surgery,
    }) => ausdruecklich
        ? GymDayPlanner.day(
            today: heute,
            planned: plan,
            completed: completed,
            overdue: overdue,
            draft: draft,
            surgery: surgery,
            rotation: Workout.rotation,
          )
        : GymDayPlanner.day(
            today: heute,
            planned: plan,
            completed: completed,
            overdue: overdue,
            draft: draft,
            surgery: surgery,
          );

    GymDay ohne(
      DateTime heute, {
      List<PlannedGym> plan = const [],
      List<Workout> overdue = const [],
    }) => aufruf(false, heute, plan: plan, overdue: overdue);

    final standardPlan = [
      PlannedGym(workout: Workout.a, weekday: DateTime.monday),
      PlannedGym(workout: Workout.b, weekday: DateTime.wednesday),
      PlannedGym(workout: Workout.c, weekday: DateTime.thursday),
    ];

    test('Die Woche ohne Parameter ist A bis D', () {
      // Mo, 08.02.2027 — wie in `gym_day_planner_test.dart`.
      final tag = ohne(amTag(2027, 2, 8), plan: standardPlan);
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(tag.week.map((slot) => slot.weekday).toList(), [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.thursday,
        null,
      ]);
      expect((tag.focus as Planned).workout, Workout.a);
    });

    test('Ohne Parameter dasselbe wie mit `Workout.rotation`', () {
      final szenarien = <String, GymDay Function(bool)>{
        'Montag mit Plan': (e) =>
            aufruf(e, amTag(2027, 2, 8), plan: standardPlan),
        'Dienstag, A erledigt': (e) => aufruf(
          e,
          amTag(2027, 2, 9),
          plan: standardPlan,
          completed: {Workout.a: amTag(2027, 2, 8)},
        ),
        'Mittwoch mit Entwurf und Überfälligem': (e) => aufruf(
          e,
          amTag(2027, 2, 10),
          plan: standardPlan,
          overdue: [Workout.d],
          draft: GymDraft(
            workout: Workout.b,
            doneExercises: 1,
            totalExercises: 8,
          ),
        ),
        'Leerer Plan': (e) => aufruf(e, amTag(2027, 2, 8)),
        'Erholung': (e) => aufruf(
          e,
          amTag(2027, 2, 10),
          plan: standardPlan,
          surgery: amTag(2027, 2, 8),
        ),
      };
      for (final eintrag in szenarien.entries) {
        expect(eintrag.value(false), eintrag.value(true), reason: eintrag.key);
      }
    });

    test('Ohne Parameter bleibt Push aus der Woche, wie bisher', () {
      // Mo, 08.02.2027. Der Altplaner lässt ein frei wählbares Workout im
      // Plan nicht zu.
      final tag = ohne(
        amTag(2027, 2, 8),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
      );
      expect(workoutsVon(tag), Workout.rotation);
      expect(platzFuer(tag, Workout.push), isNull);
    });

    test('Ein überfälliges Gym D zählt ohne Parameter, ein Push nicht', () {
      final tag = ohne(amTag(2027, 2, 9), overdue: [Workout.push, Workout.d]);
      expect((tag.focus as Rest).overdue, Workout.d);
    });
  });

  // -------------------------------------------------------------------------
  group('Werttypen vergleichen sich inhaltlich', () {
    test('Zweimal dieselbe Eingabe ergibt zwei gleiche Tage', () {
      // Fehler `03`: Ein neu gerechneter, inhaltsgleicher Tag, der ungleich
      // dem vorigen wäre, ließe jedes abgeleitete Ergebnis neu laufen.
      GymDay bauen() => tagesplan(
        amTag(2027, 2, 10),
        plan: [PlannedGym(workout: Workout.push, weekday: DateTime.monday)],
        completed: {Workout.legs: amTag(2027, 2, 9)},
        rotation: [Workout.push, Workout.pull, Workout.legs],
      );
      expect(bauen(), equals(bauen()));
      expect(bauen().hashCode, bauen().hashCode);
    });

    test('Eine andere Rotation ergibt einen anderen Tag', () {
      final drei = tagesplan(amTag(2027, 2, 8));
      final zwei = tagesplan(
        amTag(2027, 2, 8),
        rotation: [Workout.push, Workout.pull],
      );
      expect(drei == zwei, isFalse);
    });
  });
}
