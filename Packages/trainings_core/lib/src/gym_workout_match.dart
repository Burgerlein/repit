import 'berlin_calendar.dart';

/// Ein Apple-Training, soweit [GymWorkoutMatch] es braucht: drei Felder.
///
/// Der Kern kennt weder `WorkoutSample` (ein Transporttyp des Kanals, er
/// gehört nicht hierher) noch die Trainingsarten der App. [isStrength] sagt
/// nur, ob die App dieses Training als Krafttraining übersetzt hat. Als Record
/// ist die Eingabe strukturell gleich — ein Provider, der die übersetzte Liste
/// hält, rechnet nicht bei jedem Neubau neu (`03`).
typedef GymWorkoutCandidate = ({
  DateTime start,
  bool isStrength,
  double minutes,
});

/// Welches Apple-Training zu einer Gym-Sitzung gehört.
///
/// Eine Sitzung kennt nur ihren Tag — weder die Dashboard-Übernahme noch die
/// eigene Erfassung hält eine Uhrzeit fest. Das Zeitfenster für den Puls
/// stammt deshalb vollständig aus HealthKit, und diese Regel entscheidet,
/// welches Training gemeint ist.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymWorkoutMatch.swift`.
abstract final class GymWorkoutMatch {
  /// Der **Index** des Krafttrainings des Berliner Tages [day] in [workouts],
  /// oder `null`.
  ///
  /// Läufe und Spaziergänge kommen nicht in Frage, auch nicht als einziges
  /// Training des Tages: Der Puls eines Laufs unter einer Gym-Sitzung wäre
  /// schlicht falsch. Bei mehreren Krafttrainings gewinnt das längere; bei
  /// gleicher Dauer das frühere, damit die Antwort nicht von der Reihenfolge
  /// abhängt, in der HealthKit die Stichproben liefert. Bei völligem
  /// Gleichstand (gleicher Beginn, gleiche Dauer) gewinnt der kleinere Index.
  ///
  /// **Kein passendes Training ist der Normalfall, nicht die Ausnahme:** Die
  /// Uhr lief nicht immer mit, und bei den übernommenen alten Trainings fast
  /// nie. Das Ergebnis ist dann `null` — kein leerer Eintrag, kein Index `-1`.
  ///
  /// **Der Index bezieht sich auf [workouts], so wie sie übergeben wurde**,
  /// nicht auf eine gefilterte Liste. Wer das Ergebnis hat, liest
  /// `samples[index]` und bekommt ohne zweite Suche das ganze Sample samt
  /// Id. Voraussetzung ist, dass der Aufrufer die Liste in der Reihenfolge der
  /// Samples übersetzt (`samples.map(...).toList()`). [workouts] wird nicht
  /// verändert und darf unveränderlich sein.
  ///
  /// **Der Tagesvergleich läuft über [BerlinCalendar]**, nicht über die Felder
  /// eines `DateTime` und nicht über eine feste Dauer: [day] wird ebenso in
  /// Berliner Zeit gelesen wie jeder Beginn, und ein Tag hat dort 23, 24 oder
  /// 25 Stunden. Ein Training um 00:10 Berliner Zeit gehört zum neuen Tag,
  /// obwohl es in UTC noch der Vortag ist.
  static int? matchIndex({
    required DateTime day,
    required List<GymWorkoutCandidate> workouts,
  }) {
    final wanted = BerlinCalendar.startOfDay(day);
    int? best;
    for (var i = 0; i < workouts.length; i++) {
      final candidate = workouts[i];
      if (!candidate.isStrength ||
          BerlinCalendar.startOfDay(candidate.start) != wanted) {
        continue;
      }
      if (best == null || _beats(candidate, workouts[best])) best = i;
    }
    return best;
  }

  /// Ob [candidate] das bisher beste [incumbent] **echt** schlägt: länger, bei
  /// gleicher Dauer früher. Bei Gleichstand schlägt es nicht — der kleinere
  /// Index, der zuerst gesehen wurde, bleibt.
  static bool _beats(
    GymWorkoutCandidate candidate,
    GymWorkoutCandidate incumbent,
  ) {
    if (candidate.minutes != incumbent.minutes) {
      return candidate.minutes > incumbent.minutes;
    }
    return candidate.start.isBefore(incumbent.start);
  }
}
