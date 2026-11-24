import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `GymDayPlanner`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymDayPlanner.swift`.
/// Vorlage ist `Tests/TrainingsCoreTests/GymDayPlannerTests.swift`; die API
/// steht in `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Block D.
///
/// ### Die Wochentagszählung ist umgerechnet
///
/// Swift zählt `1 = Sonntag, 2 = Montag`; Dart zählt
/// `DateTime.monday == 1 … DateTime.sunday == 7`. Die API-Vorgabe entscheidet
/// sich für die **Dart-Zählung**, passend zu `BerlinCalendar.weekday`. Jeder
/// Wochentagswert aus der Swift-Vorlage ist hier umgerechnet
/// (Swift 2→1, 3→2, 4→3, 5→4, 6→5, 7→6, 1→7); geschrieben steht aber nicht
/// die Zahl, sondern `DateTime.monday` und seine Geschwister — eine Zahl,
/// die man nachschlagen muss, ist genau die Stelle, an der dieser Port still
/// falsch würde.
///
/// ### Die Kalendertage sind nachgerechnet, nicht angenommen
///
/// Jeder Testzeitpunkt trägt seinen Wochentag im Kommentar. Die Kette ist an
/// `01.01.2027 = Freitag` verankert (dieselbe Verankerung wie in
/// `berlin_calendar_test.dart`, dort aus `01.01.2000 = Samstag`
/// fortgerechnet):
///
///   01.02.2027 = Montag    (Jan hat 31 Tage, 31 ≡ 3 mod 7, Fr + 3 = Mo)
///   08.02.2027 = Montag    → Di 09., Mi 10., Do 11., Fr 12., Sa 13., So 14.
///   15.02.2027 = Montag    (die **nächste** Woche — Wochengrenze!)
///   01.03.2027 = Montag    (Feb 2027 hat 28 Tage, 28 ≡ 0 mod 7)
///   03.03.2027 = Mittwoch, 12.03. = Freitag, 17.03. = Mittwoch
///   15.03.2027 = Montag, 22.03.2027 = Montag, 29.03.2027 = Montag
///   24.03.2027 = Mittwoch, 30.03.2027 = Dienstag, 12.04.2027 = Montag
///   01.10.2027 = Freitag   (273 ≡ 0 mod 7, 2027 ist kein Schaltjahr)
///   19.10.2027 = Dienstag, 29.10.2027 = Freitag
///   01.11.2027 = Montag, 02.11.2027 = Dienstag, 08.11.2027 = Montag
///
/// Sommerzeit 2027: letzter Sonntag im März = **28.03.**, letzter Sonntag im
/// Oktober = **31.10.** — beide Umstellungen liegen in einem Pausenfenster
/// weiter unten.
///
/// ### Alle Daten sind erfunden
///
/// Insbesondere das OP-Datum: Es kommt als Parameter herein und steht
/// nirgends im Quelltext der App. Die Zahlen hier sind frei gewählt und
/// bezeichnen kein Ereignis.

// ---------------------------------------------------------------------------
// Hilfen
// ---------------------------------------------------------------------------

/// Ein Zeitpunkt mitten im Berliner Kalendertag, als UTC.
///
/// 09:00 UTC ist in Berlin 10:00 (Winterzeit) oder 11:00 (Sommerzeit) — in
/// beiden Fällen derselbe Kalendertag. Absichtlich **nicht** der Tagesbeginn:
/// Der Planer muss den Zeitpunkt selbst auf seinen Tag normalisieren.
DateTime amTag(int jahr, int monat, int tag) =>
    DateTime.utc(jahr, monat, tag, 9);

/// Der Berliner Tagesbeginn als UTC-Zeitpunkt — die Form, in der Datumswerte
/// aus dem Planer herauskommen.
DateTime tagesbeginn(int jahr, int monat, int tag) =>
    BerlinCalendar.startOfDay(amTag(jahr, monat, tag));

/// Mo Gym A, Mi Gym B, Do Gym C — der Plan aus SPEC 4.4 vor der OP.
///
/// Die Swift-Vorlage schreibt `weekday: 2, 4, 5`; in Dart-Zählung sind das
/// 1, 3 und 4. Gym D hat keinen festen Tag und steht deshalb nicht im Plan.
final standardPlan = [
  PlannedGym(workout: Workout.a, weekday: DateTime.monday),
  PlannedGym(workout: Workout.b, weekday: DateTime.wednesday),
  PlannedGym(workout: Workout.c, weekday: DateTime.thursday),
];

/// Ein Tageszustand aus dem Standardplan.
GymDay tagesplan(
  DateTime heute, {
  List<PlannedGym>? plan,
  Map<Workout, DateTime> completed = const {},
  List<Workout> overdue = const [],
  GymDraft? draft,
  DateTime? surgery,
  int pauseDays = 14,
}) => GymDayPlanner.day(
  today: heute,
  planned: plan ?? standardPlan,
  completed: completed,
  overdue: overdue,
  draft: draft,
  surgery: surgery,
  pauseDays: pauseDays,
);

/// Die Workouts der Wochenleiste in ihrer Reihenfolge.
List<Workout> workoutsVon(GymDay tag) =>
    tag.week.map((slot) => slot.workout).toList();

/// Der Platz eines Workouts, oder `null`, wenn es keinen hat.
GymSlot? platzFuer(GymDay tag, Workout workout) {
  for (final slot in tag.week) {
    if (slot.workout == workout) return slot;
  }
  return null;
}

/// Ein Platz für die Tests von `doneThisWeek`, die ohne Planer auskommen.
GymSlot platz(Workout workout, int? weekday, GymSlotStatus status) =>
    GymSlot(workout: workout, weekday: weekday, status: status);

/// Eine Woche aus fertigen Plätzen. Der Fokus steht dort nie zur Debatte;
/// `doneThisWeek` liest allein die Woche.
GymDay woche(List<GymSlot> slots) =>
    GymDay(focus: Rest(next: null, inDays: null, overdue: null), week: slots);

void main() {
  // -------------------------------------------------------------------------
  group('Die Fokus-Karte und ihr Vorrang', () {
    test('Ein angefangenes Training steht im Vordergrund', () {
      // Mo, 08.02.2027 — Gym-A-Tag, aber der Entwurf geht vor.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        draft: GymDraft(
          workout: Workout.a,
          doneExercises: 2,
          totalExercises: 7,
        ),
      );
      expect(tag.focus, isA<InProgress>());
      final fokus = tag.focus as InProgress;
      expect(fokus.workout, Workout.a);
      expect(fokus.done, 2);
      expect(fokus.total, 7);
    });

    test('Ein Entwurf ohne erfasste Übung gilt als geplant, nicht als '
        'angefangen', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        draft: GymDraft(
          workout: Workout.a,
          doneExercises: 0,
          totalExercises: 7,
        ),
      );
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.a);
    });

    test('Am Montag ohne Entwurf ist Gym A geplant', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.a);
    });

    test('Am Dienstag ist Ruhetag, als Nächstes kommt Gym B am Mittwoch', () {
      // Di, 09.02.2027; Gym A lief am Mo, 08.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        completed: {Workout.a: amTag(2027, 2, 8)},
      );
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.b);
      expect(fokus.inDays, 1);
      expect(fokus.overdue, isNull);
    });

    test('Ein liegen gebliebenes Workout wird am Ruhetag genannt', () {
      // Di, 09.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.d],
      );
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.b);
      expect(fokus.inDays, 1);
      expect(fokus.overdue, Workout.d);
    });

    test('Ist die Woche durch, bleibt der Ruhetag ohne nächstes und ohne '
        'offenes Workout', () {
      // Fr, 12.02.2027; A am Mo 08., B am Mi 10., C am Do 11.
      final tag = tagesplan(
        amTag(2027, 2, 12),
        completed: {
          Workout.a: amTag(2027, 2, 8),
          Workout.b: amTag(2027, 2, 10),
          Workout.c: amTag(2027, 2, 11),
        },
      );
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
      expect(fokus.overdue, isNull);
      // Nur die Rotation füllt die Wochenleiste.
      expect(tag.week.length, Workout.rotation.length);
    });

    test('Ist das Workout von heute schon erledigt, nennt die Fokus-Karte '
        'das nächste', () {
      // Mo, 08.02.2027 — Gym A ist der Plan von heute und schon erledigt.
      // Über die Swift-Vorlage hinaus: dort wird dieser Zweig nur an einem
      // Tag ohne geplantes Workout berührt.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        completed: {Workout.a: amTag(2027, 2, 8)},
      );
      expect(tag.focus, isA<Rest>());
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.b); // Mi, also in 2 Tagen
      expect(fokus.inDays, 2);
      expect(fokus.overdue, isNull);
      expect(platzFuer(tag, Workout.a)!.status, isA<Done>());
    });

    test('Ein Workout ohne festen Tag kommt als Nächstes nie in Frage', () {
      // Sa, 13.02.2027 — A, B und C liegen hinter uns, Gym D hat keinen Tag.
      // „In 3 Tagen" wäre für D eine Zahl ohne Bedeutung.
      final tag = tagesplan(amTag(2027, 2, 13));
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
    });

    test('Ein laufender Entwurf schlägt den erledigten Platz', () {
      // Mi, 10.02.2027: Gym A ist diese Woche erledigt und zugleich
      // angefangen — der Platz sagt „läuft", nicht „erledigt".
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.a: amTag(2027, 2, 8)},
        draft: GymDraft(
          workout: Workout.a,
          doneExercises: 1,
          totalExercises: 7,
        ),
      );
      expect(platzFuer(tag, Workout.a)!.status, isA<Running>());
      expect(tag.focus, isA<InProgress>());
    });

    test('Erledigt in dieser Woche schlägt überfällig', () {
      // Mi, 10.02.2027: Gym A am Mo erledigt, trotzdem von außen als
      // überfällig hereingereicht.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.a],
      );
      expect(platzFuer(tag, Workout.a)!.status, isA<Done>());
    });

    test('Überfällig von außen schlägt den Kalender', () {
      // Mi, 10.02.2027: Gym C steht erst am Do und wäre nach dem Kalender
      // offen — die Liste von außen wiegt schwerer.
      final tag = tagesplan(amTag(2027, 2, 10), overdue: [Workout.c]);
      expect(platzFuer(tag, Workout.c)!.status, isA<Overdue>());
    });

    test('Ein Workout ohne festen Tag kann von außen nachzuholen sein', () {
      // Mi, 10.02.2027: Gym D hat keinen Tag und wird nie von selbst
      // überfällig — über `overdue` aber schon.
      final ohne = tagesplan(amTag(2027, 2, 10));
      expect(platzFuer(ohne, Workout.d)!.status, isA<Open>());

      final mit = tagesplan(amTag(2027, 2, 10), overdue: [Workout.d]);
      expect(platzFuer(mit, Workout.d)!.status, isA<Overdue>());
      expect(platzFuer(mit, Workout.d)!.weekday, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('Die Wochenleiste', () {
    test('Die Woche nennt erledigt, laufend, offen und überfällig', () {
      // Mi, 10.02.2027: A am Mo 08. erledigt, B läuft, C steht am Do noch
      // aus, D ist von außen als nachzuholen gemeldet.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.d],
        draft: GymDraft(
          workout: Workout.b,
          doneExercises: 1,
          totalExercises: 8,
        ),
      );
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(tag.week.map((slot) => slot.weekday).toList(), [
        DateTime.monday,
        DateTime.wednesday,
        DateTime.thursday,
        null,
      ]);
      expect(tag.week[0].status, isA<Done>());
      expect((tag.week[0].status as Done).date, tagesbeginn(2027, 2, 8));
      expect(tag.week[1].status, isA<Running>());
      expect(tag.week[2].status, isA<Open>());
      expect(tag.week[3].status, isA<Overdue>());
    });

    test('Ein in dieser Woche verpasstes Workout gilt als überfällig', () {
      // Mi, 10.02.2027: Gym A stand am Mo und ist nicht erledigt.
      final tag = tagesplan(amTag(2027, 2, 10));
      expect(tag.week[0].status, isA<Overdue>()); // Mo < Mi
      expect(tag.week[1].status, isA<Today>()); // Mi == Mi
      expect(tag.week[2].status, isA<Open>()); // Do > Mi
    });

    test('Workouts ohne festen Tag stehen am Ende der Woche', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(tag.week.last.workout, Workout.d);
      expect(tag.week.last.weekday, isNull);
    });

    test('Die Rotation füllt die Wochenleiste auf, auch wenn der Plan ein '
        'Workout nicht führt', () {
      // Mo, 08.02.2027, Plan führt allein Gym A.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [PlannedGym(workout: Workout.a, weekday: DateTime.monday)],
      );
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(tag.week[0].status, isA<Today>());
      for (final slot in tag.week.skip(1)) {
        expect(slot.weekday, isNull);
        expect(slot.status, isA<Open>());
      }
    });

    test('Ein leerer Plan ergibt trotzdem vier Plätze ohne festen Tag', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8), plan: const []);
      expect(workoutsVon(tag), Workout.rotation);
      for (final slot in tag.week) {
        expect(slot.weekday, isNull);
        expect(slot.status, isA<Open>());
      }
      final fokus = tag.focus as Rest;
      expect(fokus.next, isNull);
      expect(fokus.inDays, isNull);
    });

    test('Die Plätze stehen nach Wochentag, nicht in der Reihenfolge des '
        'Plans', () {
      // Mo, 08.02.2027; Plan absichtlich verdreht aufgeschrieben.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [
          PlannedGym(workout: Workout.c, weekday: DateTime.thursday),
          PlannedGym(workout: Workout.a, weekday: DateTime.monday),
          PlannedGym(workout: Workout.b, weekday: DateTime.wednesday),
        ],
      );
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
    });

    test('Das Abschlussdatum im Platz ist der Berliner Tagesbeginn', () {
      // Mi, 10.02.2027; Gym A wurde Mo, 08.02.2027 um 21:00 Berliner Zeit
      // abgeschlossen (20:00 UTC, Winterzeit). Im Platz steht der
      // Tagesbeginn, nicht die Uhrzeit.
      final tag = tagesplan(
        amTag(2027, 2, 10),
        completed: {Workout.a: DateTime.utc(2027, 2, 8, 20)},
      );
      expect((tag.week[0].status as Done).date, tagesbeginn(2027, 2, 8));
    });

    test('Ein Abschluss aus der Vorwoche füllt keinen Platz', () {
      // Mo, 15.02.2027 — eine Woche weiter. Gym A lief So, 14.02.2027, und
      // der Sonntag gehört noch zur Woche davor.
      final tag = tagesplan(
        amTag(2027, 2, 15),
        completed: {Workout.a: amTag(2027, 2, 14)},
      );
      expect(tag.week[0].status, isA<Today>());
      expect(tag.week[0].status, isNot(isA<Done>()));
      expect(tag.doneThisWeek, 0);
    });

    test('Der Sonntag gehört noch zur Woche, die am Montag begann', () {
      // So, 14.02.2027; Gym A lief Mo, 08.02.2027 — dieselbe Woche.
      final tag = tagesplan(
        amTag(2027, 2, 14),
        completed: {Workout.a: amTag(2027, 2, 8)},
      );
      expect(tag.week[0].status, isA<Done>());
      expect(tag.doneThisWeek, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('Frei wählbare Workouts — Push, Pull und Legs', () {
    test('Die Wochenleiste führt allein die Rotation', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(workoutsVon(tag), Workout.rotation);
      for (final workout in Workout.freelyChosen) {
        expect(
          platzFuer(tag, workout),
          isNull,
          reason: '${workout.code} hat einen Platz in der Woche',
        );
      }
    });

    test('Auch ein frei wählbares Workout im Plan bekommt keinen Platz', () {
      // Mo, 08.02.2027. Der Plan führt Push nicht — stünde es doch darin,
      // bliebe die Wochenleiste trotzdem bei A bis D. Was von außen kommt,
      // darf die Zusage nicht aushebeln.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        plan: [
          ...standardPlan,
          PlannedGym(workout: Workout.push, weekday: DateTime.monday),
        ],
      );
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.a);
    });

    test('Ein frei wählbares Workout wird an keinem Wochentag heute oder '
        'überfällig', () {
      // Mo 08.02. bis So 14.02.2027, jeder Tag einmal — und an jedem Tag
      // werden Push, Pull und Legs zusätzlich als überfällig hereingereicht
      // und zugleich mit einem Wochentag in den Plan geschrieben.
      for (var t = 8; t <= 14; t++) {
        final tag = tagesplan(
          amTag(2027, 2, t),
          plan: [
            ...standardPlan,
            for (final workout in Workout.freelyChosen)
              PlannedGym(workout: workout, weekday: DateTime.monday),
          ],
          overdue: Workout.freelyChosen,
        );
        expect(
          workoutsVon(tag),
          Workout.rotation,
          reason: 'Am $t.02.2027 steht etwas Fremdes in der Woche',
        );
      }
    });

    test('Ein hineingereichtes Push gilt nicht als nachzuholen', () {
      // Di, 09.02.2027. `overdue` wiegt sonst schwerer als jede Ableitung
      // aus dem Tag — was nie fällig war, kann aber nicht liegen bleiben.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.push],
      );
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.b);
      expect(fokus.inDays, 1);
      expect(fokus.overdue, isNull);
    });

    test('Neben einem frei wählbaren bleibt das echte überfällige Workout '
        'stehen', () {
      // Di, 09.02.2027.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.legs, Workout.d],
      );
      expect((tag.focus as Rest).overdue, Workout.d);
    });

    test('Ein angefangenes Push steht trotzdem im Vordergrund', () {
      // Mo, 08.02.2027. Nicht fällig heißt nicht unsichtbar: Wer Push
      // angefangen hat, soll es wiederfinden — nur eben nicht als Platz.
      final tag = tagesplan(
        amTag(2027, 2, 8),
        draft: GymDraft(
          workout: Workout.push,
          doneExercises: 2,
          totalExercises: 7,
        ),
      );
      final fokus = tag.focus as InProgress;
      expect(fokus.workout, Workout.push);
      expect(fokus.done, 2);
      expect(fokus.total, 7);
      expect(platzFuer(tag, Workout.push), isNull);
    });

    test('Ein erledigtes Push füllt keinen Platz der Woche', () {
      // Di, 09.02.2027: Gym A am Mo, Push am Di.
      final tag = tagesplan(
        amTag(2027, 2, 9),
        completed: {
          Workout.a: amTag(2027, 2, 8),
          Workout.push: amTag(2027, 2, 9),
        },
      );
      expect(workoutsVon(tag), [Workout.a, Workout.b, Workout.c, Workout.d]);
      expect(tag.doneThisWeek, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Alle OP-Daten hier sind frei erfunden und bezeichnen kein Ereignis.
  group('Die Erholung nach einer OP hat Vorrang', () {
    test('In der Erholung zählt weder Entwurf noch geplantes Workout', () {
      // OP Mi, 03.03.2027; heute Fr, 12.03.2027 — Tag 9.
      // 14 Tage Pause enden Mi, 17.03.; Wiedereinstieg Mo, 22.03.2027.
      final tag = tagesplan(
        amTag(2027, 3, 12),
        draft: GymDraft(
          workout: Workout.a,
          doneExercises: 3,
          totalExercises: 7,
        ),
        surgery: amTag(2027, 3, 3),
      );
      expect(tag.focus, isA<Recovery>());
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 9);
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 22));
      for (final slot in tag.week) {
        expect(slot.status, isA<Paused>());
      }
      expect(tag.doneThisWeek, 0);
    });

    test('Die Erholung schiebt auch erledigte und überfällige Plätze '
        'beiseite', () {
      // OP Mi, 03.03.2027; heute Fr, 12.03.2027.
      final tag = tagesplan(
        amTag(2027, 3, 12),
        completed: {Workout.a: amTag(2027, 3, 8)}, // Mo, 08.03.2027
        overdue: [Workout.d],
        surgery: amTag(2027, 3, 3),
      );
      for (final slot in tag.week) {
        expect(slot.status, isA<Paused>());
      }
      expect(tag.doneThisWeek, 0);
    });

    test('Der Wiedereinstieg ist der erste Montag ab OP plus Pause', () {
      // OP Mi, 03.03.2027; heute Do, 04.03.2027. Pause endet Mi, 17.03. —
      // der erste Montag danach ist der 22.03.2027.
      final tag = tagesplan(amTag(2027, 3, 4), surgery: amTag(2027, 3, 3));
      final fokus = tag.focus as Recovery;
      expect(BerlinCalendar.weekday(fokus.earliestReturn), DateTime.monday);
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 22));
    });

    test('Fällt das Pausenende selbst auf einen Montag, ist das der Tag', () {
      // OP Mo, 01.03.2027; 14 Tage Pause enden Mo, 15.03.2027 — und das ist
      // der Wiedereinstieg, nicht der Montag darauf. Zaunpfahlfehler.
      final tag = tagesplan(amTag(2027, 3, 2), surgery: amTag(2027, 3, 1));
      final fokus = tag.focus as Recovery;
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 15));
      expect(fokus.earliestReturn, isNot(tagesbeginn(2027, 3, 22)));
      expect(fokus.dayAfterSurgery, 1); // Di, 02.03.2027
    });

    test('Am Tag der OP beginnt die Erholung bei null', () {
      // OP Mi, 03.03.2027, und heute ist derselbe Tag.
      final tag = tagesplan(amTag(2027, 3, 3), surgery: amTag(2027, 3, 3));
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 0);
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 22));
    });

    test('Am Tag vor der OP läuft der Betrieb normal', () {
      // OP Mi, 03.03.2027; heute Di, 02.03.2027.
      final tag = tagesplan(amTag(2027, 3, 2), surgery: amTag(2027, 3, 3));
      expect(tag.focus, isNot(isA<Recovery>()));
      final fokus = tag.focus as Rest;
      expect(fokus.next, Workout.b); // Mi, 03.03.2027
      expect(fokus.inDays, 1);
      for (final slot in tag.week) {
        expect(slot.status, isNot(isA<Paused>()));
      }
    });

    test('Das Pausenende selbst ist noch Erholung', () {
      // OP Mi, 03.03.2027; heute Mi, 17.03.2027 — genau OP plus 14 Tage,
      // aber der Wiedereinstieg ist erst Mo, 22.03.2027.
      final tag = tagesplan(amTag(2027, 3, 17), surgery: amTag(2027, 3, 3));
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 14);
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 22));
    });

    test('Am Tag des Wiedereinstiegs ist die Erholung vorbei', () {
      // OP Mi, 03.03.2027; heute Mo, 22.03.2027 — und Montag ist Gym-A-Tag.
      final tag = tagesplan(amTag(2027, 3, 22), surgery: amTag(2027, 3, 3));
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.a);
      for (final slot in tag.week) {
        expect(slot.status, isNot(isA<Paused>()));
      }
    });

    test('Eine andere Pausenlänge verschiebt den Wiedereinstieg', () {
      // OP Mi, 03.03.2027, 21 Tage Pause: Ende Mi, 24.03.2027,
      // Wiedereinstieg Mo, 29.03.2027.
      final tag = tagesplan(
        amTag(2027, 3, 12), // Fr, 12.03.2027
        surgery: amTag(2027, 3, 3),
        pauseDays: 21,
      );
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 9);
      expect(fokus.earliestReturn, tagesbeginn(2027, 3, 29));
    });

    test('Die Erholung zählt Kalendertage, auch über die Umstellung auf '
        'Sommerzeit', () {
      // OP Mi, 24.03.2027; heute Di, 30.03.2027. Dazwischen liegt So,
      // 28.03.2027 — der Tag mit 23 Stunden. Kalendarisch sind das 6 Tage;
      // mit einer Dauer gerechnet wären es 5 Tage und 23 Stunden, und
      // `Duration.inDays` schnitte das auf 5 ab.
      final tag = tagesplan(amTag(2027, 3, 30), surgery: amTag(2027, 3, 24));
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 6);
      // Pause endet Mi, 07.04.2027; Wiedereinstieg Mo, 12.04.2027.
      expect(fokus.earliestReturn, tagesbeginn(2027, 4, 12));
    });

    test('Der Wiedereinstieg verrutscht nicht über die Umstellung auf '
        'Winterzeit', () {
      // OP Di, 19.10.2027; 14 Tage Pause enden Di, 02.11.2027, also ist der
      // Wiedereinstieg Mo, 08.11.2027. Dazwischen liegt So, 31.10.2027 — der
      // Tag mit 25 Stunden. Wer die Pause als Dauer addiert, landet auf dem
      // 01.11. (einem Montag) und gäbe den Wiedereinstieg eine ganze Woche
      // zu früh an.
      final tag = tagesplan(amTag(2027, 10, 29), surgery: amTag(2027, 10, 19));
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 10); // Fr, 29.10.2027
      expect(fokus.earliestReturn, tagesbeginn(2027, 11, 8));
      expect(fokus.earliestReturn, isNot(tagesbeginn(2027, 11, 1)));
    });

    test('Das Pausenende nach der Umstellung ist noch Erholung', () {
      // OP Di, 19.10.2027; heute Di, 02.11.2027 — Tag 14, Pausenende.
      final tag = tagesplan(amTag(2027, 11, 2), surgery: amTag(2027, 10, 19));
      final fokus = tag.focus as Recovery;
      expect(fokus.dayAfterSurgery, 14);
      expect(fokus.earliestReturn, tagesbeginn(2027, 11, 8));
    });

    test('Am ersten Montag nach der Umstellung läuft der Betrieb wieder', () {
      // OP Di, 19.10.2027; heute Mo, 08.11.2027.
      final tag = tagesplan(amTag(2027, 11, 8), surgery: amTag(2027, 10, 19));
      expect(tag.focus, isA<Planned>());
      expect((tag.focus as Planned).workout, Workout.a);
    });

    test('Ohne OP-Datum gibt es keine Erholung', () {
      // Mo, 08.02.2027.
      final tag = tagesplan(amTag(2027, 2, 8));
      expect(tag.focus, isNot(isA<Recovery>()));
      for (final slot in tag.week) {
        expect(slot.status, isNot(isA<Paused>()));
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Erledigte Einheiten der Woche', () {
    test('Eine Woche ohne erledigte Einheit ergibt null', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Today()),
        platz(Workout.b, DateTime.wednesday, Open()),
        platz(Workout.c, DateTime.thursday, Open()),
        platz(Workout.d, null, Open()),
      ]);
      expect(w.doneThisWeek, 0);
    });

    test('Eine Woche ganz ohne Plätze ergibt null', () {
      expect(woche(const []).doneThisWeek, 0);
    });

    test('Gezählt werden allein die Plätze mit Status erledigt', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 8))),
        platz(Workout.b, DateTime.wednesday, Done(tagesbeginn(2027, 2, 10))),
        platz(Workout.c, DateTime.thursday, Today()),
        platz(Workout.d, null, Open()),
      ]);
      expect(w.doneThisWeek, 2);
    });

    test('Offen, heute und überfällig zählen nicht mit', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Overdue()),
        platz(Workout.b, DateTime.wednesday, Today()),
        platz(Workout.c, DateTime.thursday, Open()),
        platz(Workout.d, null, Overdue()),
      ]);
      expect(w.doneThisWeek, 0);
    });

    test('Ein laufendes Training zählt erst, wenn es abgeschlossen ist', () {
      final laufend = woche([
        platz(Workout.a, DateTime.monday, Running()),
        platz(Workout.b, DateTime.wednesday, Open()),
      ]);
      expect(laufend.doneThisWeek, 0);

      final fertig = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 8))),
        platz(Workout.b, DateTime.wednesday, Open()),
      ]);
      expect(fertig.doneThisWeek, 1);
    });

    test('In der Erholung ist nichts erledigt', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Paused()),
        platz(Workout.b, DateTime.wednesday, Paused()),
        platz(Workout.c, DateTime.thursday, Paused()),
        platz(Workout.d, null, Paused()),
      ]);
      expect(w.doneThisWeek, 0);
    });

    test('Ein nachgeholtes Gym D ohne festen Wochentag zählt mit', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 8))),
        platz(Workout.b, DateTime.wednesday, Open()),
        platz(Workout.c, DateTime.thursday, Open()),
        platz(Workout.d, null, Done(tagesbeginn(2027, 2, 13))),
      ]);
      expect(w.doneThisWeek, 2);
    });

    test('Sind alle Plätze erledigt, zählt die Woche jeden einzeln', () {
      final w = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 8))),
        platz(Workout.b, DateTime.wednesday, Done(tagesbeginn(2027, 2, 10))),
        platz(Workout.c, DateTime.thursday, Done(tagesbeginn(2027, 2, 11))),
        platz(Workout.d, null, Done(tagesbeginn(2027, 2, 13))),
      ]);
      expect(w.doneThisWeek, 4);
    });

    test('Das Datum des Abschlusses ändert die Zahl nicht', () {
      final frueh = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 8))),
      ]);
      final spaet = woche([
        platz(Workout.a, DateTime.monday, Done(tagesbeginn(2027, 2, 14))),
      ]);
      expect(frueh.doneThisWeek, spaet.doneThisWeek);
      expect(frueh.doneThisWeek, 1);
    });

    test('Dasselbe Workout zweimal in der Woche füllt einen Platz, nicht '
        'zwei', () {
      // Gym A am Mo, 08.02.2027 und noch einmal am Fr, 12.02.2027. In
      // `completed` steht je Workout nur ein Datum — gezählt werden Plätze.
      final tag = tagesplan(
        amTag(2027, 2, 12),
        completed: {Workout.a: amTag(2027, 2, 12)},
      );
      final erledigt = tag.week.where((slot) => slot.status is Done);
      expect(erledigt.length, 1);
      expect(tag.doneThisWeek, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Jeder Werttyp, der Abhängigkeit eines Providers werden kann, braucht
  // `==` und `hashCode` — sonst rechnet Riverpod jedes Abgeleitete bei jedem
  // Neubau neu. Das wäre Fehler `03` im neuen Code.
  group('Werttypen vergleichen sich inhaltlich', () {
    test('PlannedGym ist gleich, wenn Workout und Wochentag gleich sind', () {
      final a = PlannedGym(workout: Workout.a, weekday: DateTime.monday);
      final b = PlannedGym(workout: Workout.a, weekday: DateTime.monday);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(PlannedGym(workout: Workout.b, weekday: DateTime.monday)),
      );
      expect(
        a,
        isNot(PlannedGym(workout: Workout.a, weekday: DateTime.tuesday)),
      );
    });

    test('GymDraft ist gleich, wenn Workout und beide Zahlen gleich sind', () {
      final a = GymDraft(
        workout: Workout.a,
        doneExercises: 2,
        totalExercises: 7,
      );
      final b = GymDraft(
        workout: Workout.a,
        doneExercises: 2,
        totalExercises: 7,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          GymDraft(workout: Workout.a, doneExercises: 3, totalExercises: 7),
        ),
      );
      expect(
        a,
        isNot(
          GymDraft(workout: Workout.a, doneExercises: 2, totalExercises: 8),
        ),
      );
    });

    test('Die Zustände eines Platzes unterscheiden sich nach Fall und '
        'Datum', () {
      expect(Running(), Running());
      expect(Running().hashCode, Running().hashCode);
      expect(Open(), Open());
      expect(Today(), Today());
      expect(Overdue(), Overdue());
      expect(Paused(), Paused());

      // Verschiedene Fälle sind nie gleich — auch nicht die ohne Felder.
      expect(Running(), isNot(Today()));
      expect(Open(), isNot(Overdue()));
      expect(Paused(), isNot(Open()));

      final frueh = Done(tagesbeginn(2027, 2, 8));
      expect(frueh, Done(tagesbeginn(2027, 2, 8)));
      expect(frueh.hashCode, Done(tagesbeginn(2027, 2, 8)).hashCode);
      expect(frueh, isNot(Done(tagesbeginn(2027, 2, 14))));
      expect(frueh, isNot(Open()));
    });

    test('Ein Platz ist gleich, wenn Workout, Tag und Zustand gleich sind', () {
      final a = platz(Workout.a, DateTime.monday, Open());
      expect(a, platz(Workout.a, DateTime.monday, Open()));
      expect(a.hashCode, platz(Workout.a, DateTime.monday, Open()).hashCode);
      expect(a, isNot(platz(Workout.a, null, Open())));
      expect(a, isNot(platz(Workout.a, DateTime.monday, Today())));
      expect(a, isNot(platz(Workout.b, DateTime.monday, Open())));
    });

    test('Die Fälle der Fokus-Karte unterscheiden sich nach Fall und '
        'Zahlen', () {
      final laeuft = InProgress(workout: Workout.a, done: 2, total: 7);
      expect(laeuft, InProgress(workout: Workout.a, done: 2, total: 7));
      expect(
        laeuft.hashCode,
        InProgress(workout: Workout.a, done: 2, total: 7).hashCode,
      );
      expect(laeuft, isNot(InProgress(workout: Workout.a, done: 3, total: 7)));
      expect(laeuft, isNot(Planned(workout: Workout.a)));

      expect(Planned(workout: Workout.a), Planned(workout: Workout.a));
      expect(Planned(workout: Workout.a), isNot(Planned(workout: Workout.b)));

      final leer = Rest(next: null, inDays: null, overdue: null);
      expect(leer, Rest(next: null, inDays: null, overdue: null));
      expect(
        leer.hashCode,
        Rest(next: null, inDays: null, overdue: null).hashCode,
      );
      expect(leer, isNot(Rest(next: Workout.b, inDays: 1, overdue: null)));
      expect(
        Rest(next: Workout.b, inDays: 1, overdue: Workout.d),
        Rest(next: Workout.b, inDays: 1, overdue: Workout.d),
      );
      expect(
        Rest(next: Workout.b, inDays: 1, overdue: null),
        isNot(Rest(next: Workout.b, inDays: 1, overdue: Workout.d)),
      );

      final erholung = Recovery(
        dayAfterSurgery: 9,
        earliestReturn: tagesbeginn(2027, 3, 22),
      );
      expect(
        erholung,
        Recovery(dayAfterSurgery: 9, earliestReturn: tagesbeginn(2027, 3, 22)),
      );
      expect(
        erholung.hashCode,
        Recovery(
          dayAfterSurgery: 9,
          earliestReturn: tagesbeginn(2027, 3, 22),
        ).hashCode,
      );
      expect(
        erholung,
        isNot(
          Recovery(
            dayAfterSurgery: 10,
            earliestReturn: tagesbeginn(2027, 3, 22),
          ),
        ),
      );
      expect(
        erholung,
        isNot(
          Recovery(
            dayAfterSurgery: 9,
            earliestReturn: tagesbeginn(2027, 3, 29),
          ),
        ),
      );
    });

    test('Ein Tag ist gleich, wenn Fokus und Woche gleich sind', () {
      final slots = [
        platz(Workout.a, DateTime.monday, Today()),
        platz(Workout.b, DateTime.wednesday, Open()),
      ];
      final a = GymDay(
        focus: Planned(workout: Workout.a),
        week: slots,
      );
      final b = GymDay(
        focus: Planned(workout: Workout.a),
        week: [
          platz(Workout.a, DateTime.monday, Today()),
          platz(Workout.b, DateTime.wednesday, Open()),
        ],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          GymDay(
            focus: Planned(workout: Workout.b),
            week: slots,
          ),
        ),
      );
      expect(
        a,
        isNot(
          GymDay(
            focus: Planned(workout: Workout.a),
            week: [platz(Workout.a, DateTime.monday, Today())],
          ),
        ),
      );
    });

    test('Zweimal dieselbe Eingabe ergibt zwei gleiche Tage', () {
      // Der Grund für `==` überhaupt: Ein neu gerechneter, inhaltsgleicher
      // Tag darf kein abgeleitetes Provider-Ergebnis neu auslösen.
      // Mo, 08.02.2027.
      GymDay rechnen() => tagesplan(
        amTag(2027, 2, 8),
        completed: {Workout.a: amTag(2027, 2, 8)},
        overdue: [Workout.d],
      );
      expect(rechnen(), rechnen());
      expect(rechnen().hashCode, rechnen().hashCode);
    });
  });
}
