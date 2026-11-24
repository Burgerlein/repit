// Die Tagesplanung des Gym-Tabs, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymDayPlanner.swift`
// (#91, Block D).

import 'berlin_calendar.dart';
import 'exercise.dart';

/// Ein Workout mit seinem festen Wochentag.
///
/// **1 ist Montag, 7 ist Sonntag** — die Dart-Zählung aus
/// [DateTime.monday] … [DateTime.sunday], passend zu
/// [BerlinCalendar.weekday]. Swift zählt an dieser Stelle anders
/// (1 = Sonntag, 2 = Montag); die Abweichung ist in der Spec zu #91
/// ausdrücklich entschieden, damit nicht an jeder Vergleichsstelle gegen
/// [BerlinCalendar.weekday] umgerechnet werden muss — genau dort vergisst
/// es irgendwann jemand.
///
/// Werttyp mit [==] und [hashCode] (`CLAUDE.md`, Fehler `03`).
final class PlannedGym {
  const PlannedGym({required this.workout, required this.weekday});

  final Workout workout;

  /// 1 = Montag … 7 = Sonntag.
  final int weekday;

  @override
  bool operator ==(Object other) =>
      other is PlannedGym &&
      other.workout == workout &&
      other.weekday == weekday;

  @override
  int get hashCode => Object.hash(workout, weekday);

  @override
  String toString() => 'PlannedGym(${workout.code}, weekday: $weekday)';
}

/// Ein angefangenes, noch nicht abgeschlossenes Training.
///
/// **Ein Training ohne Enum-Fall** (ein eigenes, Spec 27 Nr. 4) trägt keine
/// [workout], sondern seine Kennung in [trainingId] und den Namen, unter dem
/// es läuft, in [trainingName]. Wo es einen Fall gibt, steht er in [workout]
/// und [trainingId] ist `null` — wie bei `ImportedSession`. Beides zugleich
/// zu setzen erzwingt dieser Typ nicht.
///
/// Werttyp mit [==] und [hashCode].
final class GymDraft {
  const GymDraft({
    this.workout,
    this.trainingId,
    this.trainingName,
    required this.doneExercises,
    required this.totalExercises,
  }) : assert(
         workout != null || trainingId != null,
         'Ein Entwurf gehört zu einem Training: Enum-Fall oder Kennung',
       );

  /// Der Enum-Fall, `null` bei einem Training ohne.
  final Workout? workout;

  /// Die Kennung eines Trainings ohne Enum-Fall, sonst `null`.
  final String? trainingId;

  /// Der Name eines Trainings ohne Enum-Fall, **wie er beim Lesen steht**;
  /// `null`, wo es einen Enum-Fall gibt (dessen Name steht im Fall) oder wo
  /// der Name nicht bekannt ist.
  final String? trainingName;

  /// Wie viele Übungen erfasst sind. **Null erfasste Übungen sind kein
  /// laufendes Training** — ein Entwurf, den man geöffnet und sofort wieder
  /// verlassen hat, soll die Fokus-Karte nicht belegen.
  final int doneExercises;

  final int totalExercises;

  @override
  bool operator ==(Object other) =>
      other is GymDraft &&
      other.workout == workout &&
      other.trainingId == trainingId &&
      other.trainingName == trainingName &&
      other.doneExercises == doneExercises &&
      other.totalExercises == totalExercises;

  @override
  int get hashCode => Object.hash(
    workout,
    trainingId,
    trainingName,
    doneExercises,
    totalExercises,
  );

  @override
  String toString() =>
      'GymDraft(${workout?.code ?? trainingId}, '
      '$doneExercises/$totalExercises)';
}

/// Der Zustand eines Platzes in der Wochenleiste.
///
/// Swifts `enum GymSlotStatus` mit assoziiertem Wert wird in Dart eine
/// sealed class — die Form, die der Rest des Pakets benutzt und die den
/// `switch` vollständig erzwingt.
///
/// **Zwei verschiedene feldlose Fälle sind nie gleich.** `Running()` und
/// `Today()` tragen beide nichts, wären über einen gemeinsamen `==` aber
/// ununterscheidbar; jeder Fall vergleicht deshalb zuerst seinen eigenen
/// Typ.
sealed class GymSlotStatus {
  const GymSlotStatus();
}

/// In dieser Woche abgeschlossen.
///
/// [date] ist der **Berliner Tagesbeginn** des Abschlusses, nicht der
/// hereingereichte Zeitstempel: Die Wochenleiste zeigt einen Tag, keine
/// Uhrzeit, und zwei inhaltsgleiche Tage dürfen sich nicht in der Sekunde
/// unterscheiden (Fehler `03`).
///
/// Positionell, als einziger Fall — so steht es in der Spec zu #91.
final class Done extends GymSlotStatus {
  const Done(this.date);

  /// Berliner Tagesbeginn als UTC-Zeitpunkt, wie alles aus
  /// [BerlinCalendar].
  final DateTime date;

  @override
  bool operator ==(Object other) => other is Done && other.date == date;

  @override
  int get hashCode => Object.hash(Done, date);

  @override
  String toString() => 'Done($date)';
}

/// Angefangen und noch nicht abgeschlossen.
final class Running extends GymSlotStatus {
  const Running();

  @override
  bool operator ==(Object other) => other is Running;

  @override
  int get hashCode => (Running).hashCode;

  @override
  String toString() => 'Running()';
}

/// Heute dran.
final class Today extends GymSlotStatus {
  const Today();

  @override
  bool operator ==(Object other) => other is Today;

  @override
  int get hashCode => (Today).hashCode;

  @override
  String toString() => 'Today()';
}

/// Steht noch aus — oder hat gar keinen festen Tag.
final class Open extends GymSlotStatus {
  const Open();

  @override
  bool operator ==(Object other) => other is Open;

  @override
  int get hashCode => (Open).hashCode;

  @override
  String toString() => 'Open()';
}

/// Liegen geblieben: der geplante Tag ist vorbei, oder die Liste von außen
/// meldet es als nachzuholen.
final class Overdue extends GymSlotStatus {
  const Overdue();

  @override
  bool operator ==(Object other) => other is Overdue;

  @override
  int get hashCode => (Overdue).hashCode;

  @override
  String toString() => 'Overdue()';
}

/// Ausgesetzt, weil die Erholung nach einer OP läuft.
final class Paused extends GymSlotStatus {
  const Paused();

  @override
  bool operator ==(Object other) => other is Paused;

  @override
  int get hashCode => (Paused).hashCode;

  @override
  String toString() => 'Paused()';
}

/// Ein Platz in der Wochenleiste.
///
/// Werttyp mit [==] und [hashCode].
final class GymSlot {
  const GymSlot({required this.workout, this.weekday, required this.status});

  final Workout workout;

  /// Kein fester Tag im Plan — etwa Gym D, das nur nachgeholt wird.
  /// 1 = Montag … 7 = Sonntag.
  final int? weekday;

  final GymSlotStatus status;

  @override
  bool operator ==(Object other) =>
      other is GymSlot &&
      other.workout == workout &&
      other.weekday == weekday &&
      other.status == status;

  @override
  int get hashCode => Object.hash(workout, weekday, status);

  @override
  String toString() =>
      'GymSlot(${workout.code}, weekday: $weekday, status: $status)';
}

/// Was die Fokus-Karte zeigt.
///
/// **Trägt nur Zahlen und Fälle.** Wie daraus ein Satz wird, entscheidet
/// die Ansicht — im Kern stehen keine Nutzertexte.
sealed class GymFocus {
  const GymFocus();
}

/// Ein angefangenes Training; es geht allem anderen vor.
///
/// Trägt, was [GymDraft] trägt: den Enum-Fall in [workout] oder, bei einem
/// Training ohne, seine Kennung und seinen Namen (Spec 27 Nr. 4).
final class InProgress extends GymFocus {
  const InProgress({
    this.workout,
    this.trainingId,
    this.trainingName,
    required this.done,
    required this.total,
  }) : assert(
         workout != null || trainingId != null,
         'Ein laufendes Training hat einen Enum-Fall oder eine Kennung',
       );

  final Workout? workout;
  final String? trainingId;
  final String? trainingName;
  final int done;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is InProgress &&
      other.workout == workout &&
      other.trainingId == trainingId &&
      other.trainingName == trainingName &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode =>
      Object.hash(InProgress, workout, trainingId, trainingName, done, total);

  @override
  String toString() =>
      'InProgress(${workout?.code ?? trainingId}, $done/$total)';
}

/// Heute steht dieses Workout an.
final class Planned extends GymFocus {
  const Planned({required this.workout});

  final Workout workout;

  @override
  bool operator ==(Object other) =>
      other is Planned && other.workout == workout;

  @override
  int get hashCode => Object.hash(Planned, workout);

  @override
  String toString() => 'Planned(${workout.code})';
}

/// Ruhetag. Alle drei Angaben dürfen fehlen — dann ist die Woche durch.
final class Rest extends GymFocus {
  const Rest({required this.next, required this.inDays, required this.overdue});

  /// Das nächste Workout mit festem Tag in dieser Woche. Workouts ohne
  /// Tag kommen hier nie in Frage: „als Nächstes" braucht einen Tag, sonst
  /// stünde dort eine Zahl ohne Bedeutung.
  final Workout? next;

  /// Wie viele Tage es bis [next] sind.
  final int? inDays;

  /// Das erste liegen gebliebene Workout, falls es eines gibt.
  final Workout? overdue;

  @override
  bool operator ==(Object other) =>
      other is Rest &&
      other.next == next &&
      other.inDays == inDays &&
      other.overdue == overdue;

  @override
  int get hashCode => Object.hash(Rest, next, inDays, overdue);

  @override
  String toString() => 'Rest(next: $next, inDays: $inDays, overdue: $overdue)';
}

/// Die Erholung nach einer OP läuft.
///
/// [dayAfterSurgery] zählt Kalendertage seit dem OP-Tag; der OP-Tag selbst
/// ist `0`. [earliestReturn] ist der Berliner Tagesbeginn des
/// Wiedereinstiegs.
///
/// Beides ist eine **allgemeine Empfehlung**, keine ärztliche Freigabe —
/// die Ansicht muss darauf hinweisen.
final class Recovery extends GymFocus {
  const Recovery({required this.dayAfterSurgery, required this.earliestReturn});

  final int dayAfterSurgery;
  final DateTime earliestReturn;

  @override
  bool operator ==(Object other) =>
      other is Recovery &&
      other.dayAfterSurgery == dayAfterSurgery &&
      other.earliestReturn == earliestReturn;

  @override
  int get hashCode => Object.hash(Recovery, dayAfterSurgery, earliestReturn);

  @override
  String toString() =>
      'Recovery(dayAfterSurgery: $dayAfterSurgery, '
      'earliestReturn: $earliestReturn)';
}

/// Was der Gym-Tab heute zeigt: die Fokus-Karte und die Wochenleiste.
///
/// Werttyp mit [==] und [hashCode]; [week] wird **inhaltlich** verglichen,
/// Darts `==` auf `List` wäre Identität. Ohne das wäre ein neu gerechneter,
/// inhaltsgleicher Tag ungleich dem vorigen und löste jedes abgeleitete
/// Provider-Ergebnis neu aus (Fehler `03`).
final class GymDay {
  const GymDay({required this.focus, required this.week});

  final GymFocus focus;
  final List<GymSlot> week;

  /// Wie viele Einheiten dieser Woche abgeschlossen sind.
  ///
  /// Gezählt werden **Plätze**, nicht Trainings: In [week] steht je Workout
  /// genau ein Platz, und er wird nur dann auf [Done] gesetzt, wenn das
  /// Abschlussdatum in derselben Woche liegt wie heute. Die Beschränkung
  /// auf die laufende Woche steckt damit schon in den Plätzen — eine
  /// Zählung über die erledigten Trainings zählte Wochen davor mit.
  ///
  /// Wer dasselbe Workout zweimal in einer Woche macht, hat einen Platz
  /// gefüllt, nicht zwei.
  int get doneThisWeek => week.where((slot) => slot.status is Done).length;

  @override
  bool operator ==(Object other) =>
      other is GymDay &&
      other.focus == focus &&
      _gleicheWoche(other.week, week);

  @override
  int get hashCode => Object.hash(focus, Object.hashAll(week));

  @override
  String toString() => 'GymDay(focus: $focus, week: $week)';
}

/// Inhaltlicher Vergleich zweier Wochenleisten — die Reihenfolge zählt.
bool _gleicheWoche(List<GymSlot> a, List<GymSlot> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Ein Workout mit optionalem Tag. [PlannedGym] verlangt einen Tag;
/// innerhalb der Rechnung braucht es aber auch die Workouts ohne.
final class _Entry {
  const _Entry(this.workout, this.weekday);

  final Workout workout;
  final int? weekday;
}

/// Leitet aus Plan, erledigten Trainings und Entwurf ab, was der Gym-Tab
/// heute zeigt. Die Erholung nach der OP hat Vorrang vor allem anderen.
abstract final class GymDayPlanner {
  /// Der Tageszustand des Gym-Tabs.
  ///
  /// [today] kommt als beliebiger Zeitpunkt herein und wird selbst auf
  /// seinen Berliner Kalendertag normalisiert. [completed] hält je Workout
  /// den Zeitpunkt des letzten Abschlusses, [overdue] die von außen als
  /// nachzuholen gemeldeten Workouts.
  ///
  /// **Das OP-Datum ist ein Parameter** und steht nirgends im Quelltext
  /// (`CLAUDE.md`, „Keine hartcodierten Ereignisse"). [pauseDays] ist eine
  /// allgemeine Empfehlung, keine ärztliche Vorgabe.
  ///
  /// [rotation] sind die Workouts, die einen Platz in der Wochenleiste
  /// bekommen, in der Reihenfolge der Leiste. Vorgabe ist [Workout.rotation]
  /// (Gym A–D): Jeder Aufruf ohne den Parameter liefert dasselbe wie vorher.
  /// Die gespeicherte Rotation (zum Start Push, Pull, Legs) reicht der
  /// Aufrufer herein; sie kann auch kürzer sein — ein gelöschtes Training
  /// nimmt seinen Platz mit. Ein Workout außerhalb von [rotation] bekommt
  /// keinen Platz und wird nie überfällig; **ein laufender [draft] für es
  /// belegt die Fokus-Karte trotzdem**, damit er nicht unsichtbar wird.
  ///
  /// Die Rotation trägt keine Wochentage; die kommen allein aus [planned].
  static GymDay day({
    required DateTime today,
    required List<PlannedGym> planned,
    required Map<Workout, DateTime> completed,
    required List<Workout> overdue,
    GymDraft? draft,
    DateTime? surgery,
    int pauseDays = 14,
    List<Workout> rotation = Workout.rotation,
  }) {
    final start = BerlinCalendar.startOfDay(today);
    final slots = _sorted(planned, rotation);
    // Workouts außerhalb der Rotation haben keinen Platz, also auch keine
    // Frist. Hier abzuschneiden statt an jeder Auswertungsstelle: Sonst
    // stünde „Push nachholen" in der Fokus-Karte, obwohl Push nie fällig
    // war.
    final faellig = overdue.where(rotation.contains).toList(growable: false);

    if (surgery != null) {
      final erholung = _recovery(
        start: start,
        surgery: surgery,
        pauseDays: pauseDays,
      );
      if (erholung != null) {
        return GymDay(
          focus: erholung,
          week: [
            for (final entry in slots)
              GymSlot(
                workout: entry.workout,
                weekday: entry.weekday,
                status: const Paused(),
              ),
          ],
        );
      }
    }

    final week = [
      for (final entry in slots)
        GymSlot(
          workout: entry.workout,
          weekday: entry.weekday,
          status: _status(
            entry: entry,
            start: start,
            completed: completed,
            overdue: faellig,
            draft: draft,
          ),
        ),
    ];

    if (draft != null && draft.doneExercises > 0) {
      return GymDay(
        focus: InProgress(
          workout: draft.workout,
          trainingId: draft.trainingId,
          trainingName: draft.trainingName,
          done: draft.doneExercises,
          total: draft.totalExercises,
        ),
        week: week,
      );
    }

    final weekday = BerlinCalendar.weekday(start);
    for (final entry in slots) {
      if (entry.weekday != weekday) continue;
      if (_isDone(entry.workout, on: start, completed: completed)) break;
      return GymDay(
        focus: Planned(workout: entry.workout),
        week: week,
      );
    }

    // Workouts ohne festen Tag kommen hier nie in Frage — „als Nächstes"
    // braucht einen Tag, sonst stünde dort eine Zahl ohne Bedeutung.
    Workout? next;
    int? inDays;
    for (final entry in slots) {
      final plannedDay = entry.weekday;
      if (plannedDay == null || plannedDay <= weekday) continue;
      if (_isSameWeekDone(entry.workout, start: start, completed: completed)) {
        continue;
      }
      final abstand = plannedDay - weekday;
      if (inDays == null || abstand < inDays) {
        next = entry.workout;
        inDays = abstand;
      }
    }

    return GymDay(
      focus: Rest(
        next: next,
        inDays: inDays,
        overdue: faellig.isEmpty ? null : faellig.first,
      ),
      week: week,
    );
  }

  /// Workouts ohne festen Tag hängen hinten an, sonst nach Wochentag.
  static List<_Entry> _sorted(
    List<PlannedGym> planned,
    List<Workout> rotation,
  ) {
    // Auch hier filtern und nicht nur bei `overdue`: Ein Workout außerhalb
    // der Rotation mit Wochentag wäre ein Widerspruch in sich, und die
    // Wochenleiste zeigte dann doch einen Platz für Push (bei Gym A–D
    // als Rotation) oder für Gym A (bei Push/Pull/Legs). Was von außen
    // kommt, darf die Zusage nicht aushebeln.
    final scheduled =
        planned.where((gym) => rotation.contains(gym.workout)).toList()
          ..sort((a, b) => a.weekday.compareTo(b.weekday));
    // Nur die Rotation füllt die Wochenleiste auf. Was nicht in ihr steht,
    // bekäme sonst eine Kachel, die auf ewig „offen" sagt.
    final missing = rotation.where(
      (workout) => !planned.any((gym) => gym.workout == workout),
    );
    return [
      for (final gym in scheduled) _Entry(gym.workout, gym.weekday),
      for (final workout in missing) _Entry(workout, null),
    ];
  }

  /// Die Erholung, falls heute in ihr liegt — sonst `null`.
  ///
  /// Am OP-Tag selbst beginnt sie bei `0`; der Tag des Wiedereinstiegs
  /// gehört nicht mehr dazu.
  static GymFocus? _recovery({
    required DateTime start,
    required DateTime surgery,
    required int pauseDays,
  }) {
    final opDay = BerlinCalendar.startOfDay(surgery);
    if (start.isBefore(opDay)) return null;
    final back = _earliestReturn(opDay: opDay, pauseDays: pauseDays);
    if (!start.isBefore(back)) return null;
    // Über Tagesschlüssel, nicht über `difference(...).inDays`: Zwischen
    // zwei Berliner Tagesbeginnen liegen über eine Zeitumstellung hinweg
    // 23 bzw. 25 Stunden, und `inDays` schnitte auf den Tag davor ab.
    final days =
        BerlinCalendar.daysBetween(
          from: BerlinCalendar.dayKey(opDay),
          to: BerlinCalendar.dayKey(start),
        ) ??
        0;
    return Recovery(dayAfterSurgery: days, earliestReturn: back);
  }

  /// Erster Montag ab OP plus Pause. Fällt das Ende der Pause selbst auf
  /// einen Montag, ist das der Tag.
  ///
  /// Der Schritt läuft über [BerlinCalendar.addDays], nicht über eine
  /// [Duration]: 14 × 24 Stunden sind über die Herbstumstellung hinweg
  /// 14 Tage **minus** eine Stunde, das Pausenende landete einen Tag zu
  /// früh — und weil danach auf den nächsten Montag gesucht wird, läge der
  /// Wiedereinstieg am Ende eine ganze Woche daneben.
  static DateTime _earliestReturn({
    required DateTime opDay,
    required int pauseDays,
  }) {
    var cursor = BerlinCalendar.addDays(opDay, pauseDays);
    while (BerlinCalendar.weekday(cursor) != DateTime.monday) {
      cursor = BerlinCalendar.addDays(cursor, 1);
    }
    return cursor;
  }

  /// Der Vorrang der Zustände: laufender Entwurf, dann in dieser Woche
  /// erledigt, dann überfällig von außen, dann der Kalender.
  static GymSlotStatus _status({
    required _Entry entry,
    required DateTime start,
    required Map<Workout, DateTime> completed,
    required List<Workout> overdue,
    required GymDraft? draft,
  }) {
    if (draft != null &&
        draft.workout == entry.workout &&
        draft.doneExercises > 0) {
      return const Running();
    }
    final done = completed[entry.workout];
    if (done != null && _isSameWeek(done, start)) {
      return Done(BerlinCalendar.startOfDay(done));
    }
    if (overdue.contains(entry.workout)) return const Overdue();

    // Ab hier entscheidet allein der Kalender. Ohne festen Tag gibt er
    // nichts her: ein Workout wie Gym D ist nie „heute" und wird auch nie
    // von selbst überfällig. Dass es trotzdem als „nachholen" erscheinen
    // kann, liegt an der `overdue`-Liste weiter oben — die kommt von außen
    // und wiegt schwerer als jede Ableitung aus dem Tag.
    final plannedDay = entry.weekday;
    if (plannedDay == null) return const Open();
    final weekday = BerlinCalendar.weekday(start);
    if (plannedDay == weekday) return const Today();
    return plannedDay > weekday ? const Open() : const Overdue();
  }

  static bool _isDone(
    Workout workout, {
    required DateTime on,
    required Map<Workout, DateTime> completed,
  }) {
    final done = completed[workout];
    if (done == null) return false;
    return BerlinCalendar.startOfDay(done) == on;
  }

  static bool _isSameWeekDone(
    Workout workout, {
    required DateTime start,
    required Map<Workout, DateTime> completed,
  }) {
    final done = completed[workout];
    if (done == null) return false;
    return _isSameWeek(done, start);
  }

  /// Liegen beide Zeitpunkte in derselben Woche, **Montag bis Sonntag**?
  ///
  /// Swifts `Calendar.isDate(_:equalTo:toGranularity: .weekOfYear)` gibt es
  /// in Dart nicht; die Woche wird deshalb von Hand gerechnet. Montag als
  /// Wochenbeginn ist die Woche, die die Wochenleiste zeichnet — der
  /// Sonntag gehört noch zur Woche davor.
  static bool _isSameWeek(DateTime a, DateTime b) =>
      _startOfWeek(a) == _startOfWeek(b);

  /// Der Berliner Tagesbeginn des Montags der Woche, in der der Zeitpunkt
  /// liegt.
  static DateTime _startOfWeek(DateTime zeitpunkt) =>
      BerlinCalendar.addDays(zeitpunkt, 1 - BerlinCalendar.weekday(zeitpunkt));
}
