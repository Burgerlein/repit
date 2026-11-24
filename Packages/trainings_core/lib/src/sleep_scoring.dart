import 'dart:math';

import 'berlin_calendar.dart';
import 'recovery_input.dart';

/// Die Uhr einer Nacht: Minuten seit 18:00.
///
/// Uhrzeiten einer Nacht brauchen eine durchgehende Zahl, sonst läge 00:30
/// vor 23:23. Der Nullpunkt ist 18:00, der Abend läuft vorwärts, und nach
/// Mitternacht läuft die Zahl weiter, statt zu springen.
///
/// **Vor 18:00 wird die Skala negativ** (Spec Abschnitt 10a, Punkt 1, vom
/// 27.10.2026): 17:50 ist −10, nicht 1430. Nur so kostet „früher als das
/// Ziel" nichts, wie die Formel es meint.
///
/// Unbegrenzt negativ darf sie nicht werden — irgendwo muss „später
/// Nachmittag" von „nächster Vormittag" getrennt werden, sonst würde 06:00
/// morgens zu −720 statt zu 720. Der Schnitt liegt auf [wrapHour]: Der
/// Mittag ist der Punkt, der von jeder denkbaren Einschlafzeit am weitesten
/// entfernt liegt.
abstract final class EveningClock {
  /// Der Nullpunkt der Skala.
  static const int eveningHour = 18;

  /// Ab dieser Stunde rechnet die Skala auf den Abend zu; davor gehört die
  /// Uhrzeit zum Morgen danach.
  static const int wrapHour = 12;

  /// Minuten seit 18:00 für einen Zeitpunkt, gelesen auf der **Berliner
  /// Wanduhr**.
  ///
  /// Eine Zubettgehzeit ist eine Uhrzeit, keine Dauer. Der Abstand zur
  /// letzten Mitternacht (`moment.difference(BerlinCalendar.startOfDay(…))`)
  /// wäre etwas anderes: Am 25.10.2026 fällt die lokale Uhrzeit 02:30 auf
  /// zwei Zeitpunkte, und der zweite ergäbe auf diesem Weg 03:30.
  static double minutesSinceEvening(DateTime moment) {
    final (hour, minute) = BerlinCalendar.wallClock(moment);
    return minutesSinceEveningOfClock(hour: hour, minute: minute);
  }

  /// Minuten seit 18:00 für eine reine Uhrzeit.
  static double minutesSinceEveningOfClock({
    required int hour,
    required int minute,
  }) {
    const evening = eveningHour * Duration.minutesPerHour;
    final clock = hour * Duration.minutesPerHour + minute;
    final wrapped = hour >= wrapHour ? clock : clock + Duration.minutesPerDay;
    return (wrapped - evening).toDouble();
  }
}

/// Wie eine Nacht insgesamt zu lesen ist — als Anteil der **erreichbaren**
/// Punkte, nicht als Prozentzahl von 100.
enum SleepRating { veryGood, good, okay, low }

/// Die drei Teilnoten einer Nacht und was sie zusammen ergeben.
///
/// **Zwei der drei können entfallen, und `null` heißt dort genau das** —
/// nicht null Punkte. Null Punkte behaupteten ein schlechtes Ergebnis, das
/// niemand gemessen hat (`docs/SPEC.md` 4.6).
///
/// - `bedtime` ist `null`, wenn die Nacht keine Einschlafzeit hat.
/// - `interruptions` ist `null`, wenn die Nacht **keine Phasendaten** hat —
///   eine von Hand eingetragene Nacht (#131). Ohne Phasen gibt es keine
///   Wachminuten und keine Wachphasen, also nichts zu zählen.
///
/// Was entfällt, senkt die erreichbare Punktzahl, statt die erreichte zu
/// drücken:
///
/// | Fall | erreichbar |
/// |---|---|
/// | gemessen, mit Einschlafzeit | 100 |
/// | gemessen, ohne Einschlafzeit | 70 |
/// | von Hand, mit Zeiten | 80 |
/// | von Hand, nur Dauer | 50 |
class SleepScore {
  const SleepScore({
    required this.duration,
    required this.bedtime,
    required this.interruptions,
  });

  /// Höchstpunktzahl der Teilnote Dauer.
  static const int maxDuration = 50;

  /// Höchstpunktzahl der Teilnote Zubettgehzeit.
  static const int maxBedtime = 30;

  /// Höchstpunktzahl der Teilnote Unterbrechungen.
  static const int maxInterruptions = 20;

  /// Ab diesem Anteil der erreichbaren Punkte: sehr gut.
  static const double veryGoodShare = 0.85;

  /// Ab diesem Anteil: gut.
  static const double goodShare = 0.70;

  /// Ab diesem Anteil: okay, darunter niedrig.
  static const double okayShare = 0.55;

  final int duration;
  final int? bedtime;
  final int? interruptions;

  int get total => duration + (bedtime ?? 0) + (interruptions ?? 0);

  /// Nur die Teilnoten, die eine Grundlage haben. Der Ring normiert
  /// **nicht** um: 70 von 70 ist sehr gut, nicht 70 %.
  int get maxTotal =>
      maxDuration +
      (bedtime == null ? 0 : maxBedtime) +
      (interruptions == null ? 0 : maxInterruptions);

  /// Verglichen wird der Anteil selbst, nicht auf ganze Prozent gerundet:
  /// Über 70 erreichbare Punkte liegen die Schwellen zwischen zwei ganzen
  /// Punkten (59,5 · 49 · 38,5), über 50 ebenso (42,5 · 35 · 27,5).
  SleepRating get rating {
    final share = total / maxTotal;
    if (share >= veryGoodShare) return SleepRating.veryGood;
    if (share >= goodShare) return SleepRating.good;
    if (share >= okayShare) return SleepRating.okay;
    return SleepRating.low;
  }

  @override
  bool operator ==(Object other) =>
      other is SleepScore &&
      other.duration == duration &&
      other.bedtime == bedtime &&
      other.interruptions == interruptions;

  @override
  int get hashCode => Object.hash(duration, bedtime, interruptions);

  @override
  String toString() =>
      'SleepScore(duration: $duration, bedtime: $bedtime, '
      'interruptions: $interruptions)';
}

/// Der Schlaf-Score nach `docs/SPEC.md` 4.6 in der Fassung vom 26.10.2026.
///
/// **Die Swift-Vorlage ist hier ausdrücklich keine Vorlage.**
/// `Sources/TrainingsCore/Sleep/SleepScoring.swift` rechnet noch die alte
/// Teilnote „Regelmäßigkeit": Bezug war der Schnitt der letzten 14 Nächte,
/// `abs(…)` statt `max(0, …)`, Teiler 3 statt 15, und sie entfiel auch ohne
/// Vornacht. Wer sie abschreibt, holt den Fehler zurück.
///
/// Was daraus folgt, ist vor allem ein Wegfall: **Jede Nacht rechnet für
/// sich.** Die rollende Liste der Einschlafzeiten gibt es nicht mehr.
abstract final class SleepScoring {
  /// So viele Minuten nach dem Ziel kosten einen Punkt.
  static const double bedtimeMinutesPerPoint = 15;

  /// Bis hierhin kostet Wachliegen nichts.
  static const double freeAwakeMinutes = 10;

  /// Abzug je Wachminute darüber.
  static const double awakeMinutePenalty = 0.5;

  /// Bis hierhin kosten Wachphasen nichts. Gemessen, nicht gesetzt — die
  /// Herleitung über 117 Nächte steht in `docs/SPEC.md` 4.6.
  static const int freeWakeCount = 10;

  /// Abzug je Wachphase darüber.
  static const double wakeCountPenalty = 1;

  /// Der Score einer einzelnen Nacht.
  ///
  /// `goalHours` und `bedtimeGoalMinutes` sind **verpflichtend**, obwohl
  /// Swift ein `goalHours: Double = 8` kennt. Beide Ziele liegen in den
  /// Einstellungen; ein stiller Vorgabewert im Kern wäre eine zweite
  /// Wahrheit daneben (Spec Abschnitt 10a, Punkt 4).
  ///
  /// `bedtimeMinutes` und `bedtimeGoalMinutes` zählen beide Minuten seit
  /// 18:00, siehe [EveningClock]. `null` heißt: Die Nacht hat keine
  /// Einschlafzeit.
  ///
  /// `awakeMinutes` und `wakeCount` sind `null`, wenn die Nacht **keine
  /// Phasendaten** hat — dann entfällt die Teilnote Unterbrechungen (#131).
  /// Beide gehören zusammen: Entweder liegen sie vor oder keines von
  /// beiden. Eine halbe Messung wirft [ArgumentError], statt die eine
  /// Hälfte still wegzuwerfen — das wäre ein Programmierfehler des
  /// Aufrufers, keine Datenlage.
  static SleepScore score({
    required double asleepHours,
    required double goalHours,
    required double? bedtimeMinutes,
    required double bedtimeGoalMinutes,
    required double? awakeMinutes,
    required int? wakeCount,
  }) {
    if ((awakeMinutes == null) != (wakeCount == null)) {
      throw ArgumentError(
        'Wachminuten und Wachphasen liegen zusammen vor oder gar nicht: '
        'awakeMinutes=$awakeMinutes, wakeCount=$wakeCount',
      );
    }
    // Ein Ziel von null gibt null Punkte statt einer Division durch null.
    final duration = goalHours <= 0
        ? 0
        : (SleepScore.maxDuration * min(1.0, asleepHours / goalHours)).round();

    // `max(0, …)`: Nur später als das Ziel kostet. Früher ist kein Fehler —
    // und auf der gedrehten Skala ist eine Einschlafzeit vor 18:00 eine
    // negative Zahl, also erst recht kein Abzug.
    final int? bedtime = bedtimeMinutes == null
        ? null
        : (SleepScore.maxBedtime -
                  max(0.0, bedtimeMinutes - bedtimeGoalMinutes) /
                      bedtimeMinutesPerPoint)
              .clamp(0, SleepScore.maxBedtime)
              .round();

    // Ohne Phasendaten entfällt die Teilnote, sie wird nicht mit null
    // bewertet: Eine 10 von 20 zu erfinden wäre eine Zahl ohne Messung.
    final int? interruptions = (awakeMinutes == null || wakeCount == null)
        ? null
        : (SleepScore.maxInterruptions -
                  awakeMinutePenalty *
                      max(0.0, awakeMinutes - freeAwakeMinutes) -
                  wakeCountPenalty * max(0, wakeCount - freeWakeCount))
              .clamp(0, SleepScore.maxInterruptions)
              .round();

    return SleepScore(
      duration: duration,
      bedtime: bedtime,
      interruptions: interruptions,
    );
  }

  /// Ein Score je Nacht, Schlüssel ist `RecoveryNight.date`.
  ///
  /// Nächte ohne Schlafminuten fehlen im Ergebnis. Das Kriterium sind die
  /// Schlafminuten, nicht „keine Abschnitte": Eine Nacht aus lauter
  /// Wachabschnitten ist nicht leer, aber auch kein Schlaf.
  static Map<DateTime, SleepScore> series({
    required List<RecoveryNight> nights,
    required double goalHours,
    required double bedtimeGoalMinutes,
  }) {
    final result = <DateTime, SleepScore>{};
    for (final night in nights) {
      if (night.asleepMinutes <= 0) continue;
      result[night.date] = score(
        asleepHours: night.asleepHours,
        goalHours: goalHours,
        bedtimeMinutes: night.bedtime == null
            ? null
            : EveningClock.minutesSinceEvening(night.bedtime!),
        bedtimeGoalMinutes: bedtimeGoalMinutes,
        awakeMinutes: night.awakeMinutes,
        wakeCount: night.wakeCount,
      );
    }
    return result;
  }
}
