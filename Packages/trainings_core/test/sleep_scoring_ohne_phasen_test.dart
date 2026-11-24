import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den Schlaf-Score **ohne Phasendaten** (#131) —
/// `lib/src/sleep_scoring.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Warum es diesen Zweig gibt
///
/// Eine von Hand eingetragene Nacht hat **keine Phasendaten**, also auch
/// keine Wachminuten und keine Wachphasen. Der Entwurf vom 26.10.2026
/// (`docs/screens/screens/schlaf.js`, Zustand `von-hand`) zieht daraus die
/// Folgerung:
///
/// > Die Punkte für Unterbrechungen **entfallen** deshalb — genau wie die
/// > Zubettgehzeit, wenn keine Einschlafzeit aufgezeichnet ist. Eine 10/20
/// > zu erfinden, wäre eine Zahl ohne Messung.
///
/// Erreichbar sind dann **80** Punkte statt 100, und bewertet wird der
/// Anteil davon — dieselbe Mechanik, die es für die Zubettgehzeit seit
/// #110 schon gibt (70 von 100). Null Punkte zu vergeben behauptete eine
/// durchwachte Nacht, die niemand gemessen hat; zwanzig Punkte zu vergeben
/// behauptete eine ruhige.
///
/// ## Was das für die bestehende Rechnung heißt
///
/// `SleepScore.interruptions` wird **nullbar**, wortgleich zu `bedtime`,
/// und `maxTotal` zählt nur die Teilnoten, die eine Grundlage haben:
///
/// | Fall | erreichbar |
/// |---|---|
/// | gemessene Nacht mit Einschlafzeit | 100 |
/// | gemessene Nacht ohne Einschlafzeit | 70 |
/// | von Hand, mit Zeiten | **80** |
/// | von Hand, nur Dauer | **50** |
///
/// Die letzte Zeile ist der Fall, den der Entwurf unter dem Formular
/// ausschreibt: „Ohne Einschlafzeit entfällt auch die Zubettgehzeit —
/// erreichbar sind dann 50 von 100 Punkten."
///
/// **Der Befund aus #92 bekommt hier seinen Fall.** Der Zweig „keine
/// Einschlafzeit, also 70 erreichbare Punkte" ist über den Kanal gar nicht
/// erreichbar: `alsRecoveryNacht` setzt `bedtime` nur dann auf `null`, wenn
/// die Nacht überhaupt keinen Schlafabschnitt hat — und dann fällt sie
/// ohnehin aus der Score-Reihe. Eine von Hand eingetragene Nacht ohne
/// Zeiten ist genau die Lage, für die er gedacht war. **Die Rechnung dafür
/// konnte der Kern schon**; neu ist allein die entfallende dritte Teilnote.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class SleepScore {
///   const SleepScore({
///     required int duration,
///     required int? bedtime,       // null = keine Einschlafzeit
///     required int? interruptions, // null = keine Phasendaten
///   });
///   int get total;     // duration + (bedtime ?? 0) + (interruptions ?? 0)
///   int get maxTotal;  // 50 + (bedtime == null ? 0 : 30)
///                      //    + (interruptions == null ? 0 : 20)
/// }
///
/// abstract final class SleepScoring {
///   static SleepScore score({
///     required double asleepHours,
///     required double goalHours,
///     required double? bedtimeMinutes,
///     required double bedtimeGoalMinutes,
///     required double? awakeMinutes, // null = nicht gemessen
///     required int? wakeCount,       // null = nicht gemessen
///   });
/// }
/// ```
///
/// `awakeMinutes` und `wakeCount` gehören zusammen: Entweder liegen beide
/// vor oder keines von beiden. Eine halbe Messung wirft `ArgumentError`,
/// statt still die eine Hälfte wegzuwerfen — das wäre ein
/// Programmierfehler des Aufrufers, keine Datenlage.
void main() {
  group('Die Teilnote Unterbrechungen entfällt (#131)', () {
    test('ohne Phasendaten ist sie null, nicht 0 — null Punkte behaupteten '
        'eine durchwachte Nacht, die niemand gemessen hat', () {
      final score = SleepScoring.score(
        asleepHours: 7,
        goalHours: 8,
        bedtimeMinutes: 310, // 23:10 auf der 18-Uhr-Skala
        bedtimeGoalMinutes: 270, // 22:30
        awakeMinutes: null,
        wakeCount: null,
      );

      expect(score.interruptions, isNull);
      expect(score.interruptions, isNot(0));
    });

    test('dann sind 80 Punkte erreichbar, nicht 100', () {
      const score = SleepScore(duration: 44, bedtime: 27, interruptions: null);

      expect(score.total, 71);
      expect(score.maxTotal, 80);
    });

    test('und ohne Einschlafzeit zusätzlich nur noch 50 — der Satz unter dem '
        'Formular, nachgerechnet', () {
      const score = SleepScore(
        duration: 44,
        bedtime: null,
        interruptions: null,
      );

      expect(score.total, 44);
      expect(score.maxTotal, 50);
    });

    test('die beiden bekannten Fälle bleiben, was sie waren', () {
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: 10).maxTotal,
        100,
      );
      expect(
        const SleepScore(
          duration: 44,
          bedtime: null,
          interruptions: 10,
        ).maxTotal,
        70,
      );
    });

    test('bewertet wird der Anteil der erreichbaren Punkte — 71 von 80 ist '
        'sehr gut, dieselben 71 von 100 wären nur gut', () {
      // Die Nacht aus dem Entwurf (`schlaf.js`, Zustand `von-hand`):
      // 7:05 h bei 8:00 h Ziel, eingeschlafen 23:10 bei Ziel 22:30.
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: null).rating,
        SleepRating.veryGood, // 71 / 80 = 0,8875
      );
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: 0).rating,
        SleepRating.good, // 71 / 100 = 0,71
      );
    });

    test('Bewertung über 80 erreichbare Punkte, an den Schwellen', () {
      // 0,85 · 80 = 68; 0,70 · 80 = 56; 0,55 · 80 = 44.
      expect(
        const SleepScore(duration: 38, bedtime: 30, interruptions: null).rating,
        SleepRating.veryGood, // 68 von 80 = genau 0,85
      );
      expect(
        const SleepScore(duration: 37, bedtime: 30, interruptions: null).rating,
        SleepRating.good, // 67 von 80 = 0,8375
      );
      expect(
        const SleepScore(duration: 26, bedtime: 30, interruptions: null).rating,
        SleepRating.good, // 56 von 80 = genau 0,70
      );
      expect(
        const SleepScore(duration: 25, bedtime: 30, interruptions: null).rating,
        SleepRating.okay, // 55 von 80 = 0,6875
      );
      expect(
        const SleepScore(duration: 14, bedtime: 30, interruptions: null).rating,
        SleepRating.okay, // 44 von 80 = genau 0,55
      );
      expect(
        const SleepScore(duration: 13, bedtime: 30, interruptions: null).rating,
        SleepRating.low, // 43 von 80 = 0,5375
      );
    });

    test('Bewertung über 50 erreichbare Punkte — nur die Dauer trägt', () {
      // 0,85 · 50 = 42,5; 0,70 · 50 = 35; 0,55 · 50 = 27,5.
      expect(
        const SleepScore(
          duration: 43,
          bedtime: null,
          interruptions: null,
        ).rating,
        SleepRating.veryGood, // 43 von 50 = 0,86
      );
      expect(
        const SleepScore(
          duration: 42,
          bedtime: null,
          interruptions: null,
        ).rating,
        SleepRating.good, // 42 von 50 = 0,84
      );
      expect(
        const SleepScore(
          duration: 35,
          bedtime: null,
          interruptions: null,
        ).rating,
        SleepRating.good, // 35 von 50 = genau 0,70
      );
      expect(
        const SleepScore(
          duration: 34,
          bedtime: null,
          interruptions: null,
        ).rating,
        SleepRating.okay, // 34 von 50 = 0,68
      );
      expect(
        const SleepScore(
          duration: 27,
          bedtime: null,
          interruptions: null,
        ).rating,
        SleepRating.low, // 27 von 50 = 0,54
      );
    });

    test('„entfällt" und „null Punkte" sind zwei verschiedene Scores, auch '
        'für ==', () {
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: null),
        isNot(const SleepScore(duration: 44, bedtime: 27, interruptions: 0)),
      );
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: null),
        const SleepScore(duration: 44, bedtime: 27, interruptions: null),
      );
    });
  });

  group('Die eingetragene Nacht, durchgerechnet', () {
    test('mit Zeiten: 7:05 h und Einschlafen 23:10 ergeben 71 von 80 — die '
        'Zahlen des Entwurfs, nachgerechnet', () {
      final score = SleepScoring.score(
        // 425 Minuten = 7:05 h.
        asleepHours: 425 / Duration.minutesPerHour,
        goalHours: 8,
        bedtimeMinutes: EveningClock.minutesSinceEveningOfClock(
          hour: 23,
          minute: 10,
        ),
        bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
          hour: 22,
          minute: 30,
        ),
        awakeMinutes: null,
        wakeCount: null,
      );

      expect(score.duration, 44);
      expect(score.bedtime, 27);
      expect(score.interruptions, isNull);
      expect(score.total, 71);
      expect(score.maxTotal, 80);
      expect(score.rating, SleepRating.veryGood);
    });

    test(
      'nur Dauer: ohne Einschlafzeit bleibt allein die Dauer, 44 von 50',
      () {
        final score = SleepScoring.score(
          asleepHours: 425 / Duration.minutesPerHour,
          goalHours: 8,
          bedtimeMinutes: null,
          bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
            hour: 22,
            minute: 30,
          ),
          awakeMinutes: null,
          wakeCount: null,
        );

        expect(score.duration, 44);
        expect(score.bedtime, isNull);
        expect(score.interruptions, isNull);
        expect(score.total, 44);
        expect(score.maxTotal, 50);
      },
    );
  });

  group('Eine halbe Messung gibt es nicht', () {
    test('nur Wachminuten ohne Wachphasen wirft, statt die eine Hälfte still '
        'wegzuwerfen', () {
      expect(
        () => SleepScoring.score(
          asleepHours: 7,
          goalHours: 8,
          bedtimeMinutes: 310,
          bedtimeGoalMinutes: 270,
          awakeMinutes: 30,
          wakeCount: null,
        ),
        throwsArgumentError,
      );
    });

    test('und umgekehrt genauso', () {
      expect(
        () => SleepScoring.score(
          asleepHours: 7,
          goalHours: 8,
          bedtimeMinutes: 310,
          bedtimeGoalMinutes: 270,
          awakeMinutes: null,
          wakeCount: 3,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Die gemessene Nacht rechnet unverändert weiter', () {
    test('mit Phasendaten steht die Teilnote da, wie sie immer dastand', () {
      final score = SleepScoring.score(
        asleepHours: 7,
        goalHours: 8,
        bedtimeMinutes: EveningClock.minutesSinceEveningOfClock(
          hour: 23,
          minute: 10,
        ),
        bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
          hour: 22,
          minute: 30,
        ),
        awakeMinutes: 30,
        wakeCount: 10,
      );

      expect(score.duration, 44);
      expect(score.bedtime, 27);
      expect(score.interruptions, 10);
      expect(score.total, 81);
      expect(score.maxTotal, 100);
      expect(score.rating, SleepRating.good);
    });

    test('und die Reihe über `RecoveryNight` liefert weiter gemessene '
        'Unterbrechungen — sie trägt immer beide Zahlen', () {
      final reihe = SleepScoring.series(
        nights: [
          RecoveryNight(
            date: DateTime.utc(2026, 10, 29),
            asleepMinutes: 420,
            awakeMinutes: 30,
            wakeCount: 10,
          ),
        ],
        goalHours: 8,
        bedtimeGoalMinutes: 270,
      );

      expect(reihe[DateTime.utc(2026, 10, 29)]!.interruptions, 10);
    });
  });
}
