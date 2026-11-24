import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Schlaf-Score mit Zubettgehzeit** aus Ticket #110 —
/// `docs/SPEC.md` 4.6 und Spec `2026-10-26-erholung-flutter-design.md`
/// Abschnitt 7 samt der Entscheidung in Abschnitt 10a vom 27.10.2026.
///
/// **Die Swift-Vorlage ist hier ausdrücklich keine Vorlage.**
/// `Packages/TrainingsCore/Sources/TrainingsCore/Sleep/SleepScoring.swift`
/// rechnet in Zeile 42–58 noch die alte Teilnote „Regelmäßigkeit", und 906
/// Zeilen Swift-Tests schreiben sie fest. Wer sie abschreibt, holt den
/// Fehler zurück. Es gilt die Tabelle aus Abschnitt 7:
///
/// |            | Swift heute                  | gültig                      |
/// |------------|------------------------------|-----------------------------|
/// | Name       | `regularity`                 | **Zubettgehzeit**           |
/// | Bezug      | Schnitt der letzten 14 Nächte| **Ziel aus den Einstellungen** |
/// | Richtung   | `abs(…)`                     | `max(0, …)` — nur später zählt |
/// | Teiler     | 3                            | **15**                      |
/// | Fenster    | 14 Nächte                    | **entfällt**                |
/// | Entfällt   | ohne Zeit **oder** ohne Vornacht | **nur** ohne Einschlafzeit |
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// enum SleepRating { veryGood, good, okay, low }
///
/// class SleepScore {
///   const SleepScore({
///     required int duration,      // 0..50
///     required int? bedtime,      // 0..30, null = keine Einschlafzeit
///     required int interruptions, // 0..20
///   });
///   final int duration;
///   final int? bedtime;
///   final int interruptions;
///   int get total;                // duration + (bedtime ?? 0) + interruptions
///   int get maxTotal;             // 70 ohne Zubettgehzeit, sonst 100
///   SleepRating get rating;       // Anteil an maxTotal
///   // Wertgleichheit.
/// }
///
/// abstract final class SleepScoring {
///   static SleepScore score({
///     required double asleepHours,
///     required double goalHours,
///     required double? bedtimeMinutes,    // Minuten seit 18:00, s.u.
///     required double bedtimeGoalMinutes, // Ziel, Minuten seit 18:00
///     required double awakeMinutes,
///     required int wakeCount,
///   });
///
///   /// Score je Nacht, Schlüssel ist `RecoveryNight.date`. Nächte ohne
///   /// Schlafminuten fehlen im Ergebnis.
///   static Map<DateTime, SleepScore> series({
///     required List<RecoveryNight> nights,
///     required double goalHours,
///     required double bedtimeGoalMinutes,
///   });
/// }
///
/// /// Eine Nacht mit genau den Werten, die Score und Schnappschuss brauchen.
/// class RecoveryNight {
///   const RecoveryNight({
///     required DateTime date,       // Tag des Aufwachens, Berliner Tagesbeginn
///     required double asleepMinutes,
///     DateTime? bedtime,            // Einschlafzeit, `null` wenn unbekannt
///     double awakeMinutes = 0,
///     int wakeCount = 0,
///   });
///   final DateTime date;
///   final double asleepMinutes;
///   final DateTime? bedtime;
///   final double awakeMinutes;
///   final int wakeCount;
///   double get asleepHours;         // asleepMinutes / 60
///   // Wertgleichheit.
/// }
///
/// abstract final class EveningClock {
///   static const int eveningHour = 18;
///   static const int wrapHour = 12;
///   static double minutesSinceEvening(DateTime moment);
///   static double minutesSinceEveningOfClock({
///     required int hour,
///     required int minute,
///   });
/// }
/// ```
///
/// ### Kein Standardwert für Ziel oder Schlafenszeit
///
/// `goalHours` und `bedtimeGoalMinutes` sind **required**, obwohl Swift ein
/// `goalHours: Double = 8` kennt. Beide Ziele werden ab #111 abgelegt; ein
/// stiller Vorgabewert im Kern wäre eine zweite Wahrheit neben der
/// Einstellung, und genau davor warnt Spec 10a Punkt 4 („Keine
/// Zielkonstante im Quelltext"). Wer den Score rechnet, muss die Ziele
/// kennen.
///
/// ### Die Skala „Minuten seit 18:00" und die Entscheidung vom 27.10.2026
///
/// Uhrzeiten einer Nacht laufen als eine durchgehende Zahl: Minuten seit
/// 18:00. Ohne das läge 00:30 vor 23:23. Spec 10a Punkt 1 entscheidet, was
/// mit einer Einschlafzeit **vor** 18:00 passiert: **Die Skala wird
/// gedreht** — 17:50 ist **−10**, nicht 1430. Die Formel bleibt wörtlich
/// `clamp(30 − max(0, Einschlafzeit − Ziel) / 15, 0, 30)`; mit −10 und dem
/// Ziel 270 ergibt `max(0, −10 − 270)` keinen Abzug, die Nacht bekommt die
/// vollen 30 Punkte. Früher als das Ziel kostet nichts.
///
/// **Entscheidung dieser Testdatei, weil weder Ticket noch Spec sie
/// treffen:** Negativ werden darf die Skala nicht unbegrenzt — irgendwo
/// muss „später Nachmittag" von „nächster Vormittag" getrennt werden, sonst
/// würde 06:00 morgens zu −720 statt zu 720. Der Schnitt liegt auf
/// **12:00 Uhr** (`EveningClock.wrapHour`): Uhrzeiten ab Mittag rechnen
/// vorwärts auf 18:00 zu (12:00 -> −360, 17:50 -> −10, 18:00 -> 0, 23:59 ->
/// 359), Uhrzeiten vor Mittag gehören zum Morgen danach (00:00 -> 360,
/// 11:59 -> 1079). Der Mittag ist der Punkt, der von jeder denkbaren
/// Einschlafzeit am weitesten entfernt liegt.
///
/// ### Wanduhr, nicht verstrichene Zeit
///
/// `minutesSinceEvening` liest die **Berliner Wanduhr**, nicht den Abstand
/// zur letzten Mitternacht. Der Unterschied wird am 25.10.2026 sichtbar:
/// Die lokale Uhrzeit 02:30 fällt dort auf zwei Zeitpunkte (00:30 UTC noch
/// in der Sommerzeit, 01:30 UTC schon in der Winterzeit). Beide ergeben
/// denselben Wert — eine Zubettgehzeit ist eine Uhrzeit, keine Dauer. Wer
/// über `moment.difference(BerlinCalendar.startOfDay(moment))` rechnet,
/// bekommt für den zweiten Zeitpunkt 03:30 und fällt in der Gruppe
/// „Zeitumstellung" unten auf.
///
/// **Alle Zahlen hier sind erfunden.** Keine Nacht, keine Dauer und keine
/// Uhrzeit stammt aus einem Health-Export.
void main() {
  // 22:30 als Ziel — der Wert, den #111 als Vorbelegung ablegt. Hier
  // bewusst aus `EveningClock` hergeleitet statt als `270` hingeschrieben:
  // Wer die Skala ändert, verschiebt Ziel und Einschlafzeit gemeinsam.
  final ziel = EveningClock.minutesSinceEveningOfClock(hour: 22, minute: 30);

  SleepScore score({
    double asleepHours = 8,
    double goalHours = 8,
    double? bedtimeMinutes,
    double? bedtimeGoalMinutes,
    double awakeMinutes = 0,
    int wakeCount = 0,
  }) => SleepScoring.score(
    asleepHours: asleepHours,
    goalHours: goalHours,
    bedtimeMinutes: bedtimeMinutes,
    bedtimeGoalMinutes: bedtimeGoalMinutes ?? ziel,
    awakeMinutes: awakeMinutes,
    wakeCount: wakeCount,
  );

  group('EveningClock: Minuten seit 18:00', () {
    test('18:00 ist der Nullpunkt', () {
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 18, minute: 0),
        0.0,
      );
    });

    test('der Abend läuft vorwärts', () {
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 22, minute: 30),
        270.0,
      );
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 23, minute: 59),
        359.0,
      );
    });

    test('nach Mitternacht läuft die Zahl weiter, sie springt nicht', () {
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 0, minute: 0),
        360.0,
      );
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 0, minute: 30),
        390.0,
      );
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 6, minute: 0),
        720.0,
      );
    });

    test('vor 18:00 wird die Skala negativ — 17:50 ist −10', () {
      // Spec 10a, Punkt 1, Entscheidung vom 27.10.2026.
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 17, minute: 50),
        -10.0,
      );
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 17, minute: 0),
        -60.0,
      );
    });

    test('der Schnitt liegt am Mittag', () {
      // Festlegung dieser Testdatei, siehe Dateikopf: ab 12:00 rechnet die
      // Skala rückwärts auf den Abend zu, davor gehört die Uhrzeit zum
      // Morgen nach der Nacht.
      expect(EveningClock.wrapHour, 12);
      expect(EveningClock.eveningHour, 18);
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 12, minute: 0),
        -360.0,
      );
      expect(
        EveningClock.minutesSinceEveningOfClock(hour: 11, minute: 59),
        1079.0,
      );
    });

    test('ein Zeitpunkt wird über die Berliner Wanduhr gelesen', () {
      // 21:00 UTC am 24.10.2026 ist 23:00 Berliner Sommerzeit (UTC+2).
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 10, 24, 21)),
        300.0,
      );
    });
  });

  group('EveningClock über die Zeitumstellung', () {
    test('dieselbe Uhrzeit ergibt vor und nach der Umstellung denselben '
        'Wert', () {
      // 24.10.2026 23:00 Berlin = 21:00 UTC (Sommerzeit, UTC+2).
      // 26.10.2026 23:00 Berlin = 22:00 UTC (Winterzeit, UTC+1).
      // Gemessen wird die Uhrzeit, nicht der Abstand zur Mitternacht.
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 10, 24, 21)),
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 10, 26, 22)),
      );
    });

    test('die doppelte Stunde ergibt beide Male denselben Wert', () {
      // Am 25.10.2026 springt die Uhr um 03:00 auf 02:00 zurück. Lokal
      // 02:30 gibt es zweimal: 00:30 UTC (noch UTC+2) und 01:30 UTC (schon
      // UTC+1). 02:30 ergibt auf der Skala 2·60 + 30 + 1440 − 1080 = 510.
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 10, 25, 0, 30)),
        510.0,
      );
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 10, 25, 1, 30)),
        510.0,
      );
    });

    test('die übersprungene Stunde im März verschiebt nichts', () {
      // Am 29.03.2026 springt die Uhr um 02:00 auf 03:00. 00:30 UTC ist
      // noch 01:30 Berlin (UTC+1) -> 90 + 360 = 450.
      // 01:30 UTC ist bereits 03:30 Berlin (UTC+2) -> 210 + 360 = 570.
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 3, 29, 0, 30)),
        450.0,
      );
      expect(
        EveningClock.minutesSinceEvening(DateTime.utc(2026, 3, 29, 1, 30)),
        570.0,
      );
    });
  });

  group('Teilnote Dauer (max 50)', () {
    test('Ziel erreicht gibt volle 50', () {
      expect(score(asleepHours: 8, goalHours: 8).duration, 50);
    });

    test('halbes Ziel gibt die Hälfte', () {
      expect(score(asleepHours: 4, goalHours: 8).duration, 25);
    });

    test('mehr als das Ziel ist gedeckelt', () {
      expect(score(asleepHours: 12, goalHours: 8).duration, 50);
    });

    test('keine Schlafzeit gibt 0', () {
      expect(score(asleepHours: 0, goalHours: 8).duration, 0);
    });

    test('ein Ziel von 0 gibt 0 statt einer Division durch null', () {
      expect(score(asleepHours: 8, goalHours: 0).duration, 0);
    });

    test('ein anderes Ziel verschiebt die Teilnote', () {
      // Ziel 10 h, geschlafen 5 h -> die Hälfte.
      expect(score(asleepHours: 5, goalHours: 10).duration, 25);
    });
  });

  group('Teilnote Zubettgehzeit (max 30)', () {
    test('pünktlich zur Zielzeit gibt volle 30', () {
      expect(score(bedtimeMinutes: ziel).bedtime, 30);
    });

    test('eine Viertelstunde später kostet genau einen Punkt', () {
      expect(score(bedtimeMinutes: ziel + 15).bedtime, 29);
    });

    test('neunzig Minuten später kosten sechs Punkte', () {
      // In der alten Teilnote kostete das alle 30 — der Grund für #110.
      expect(score(bedtimeMinutes: ziel + 90).bedtime, 24);
    });

    test('früher als das Ziel kostet nichts', () {
      expect(score(bedtimeMinutes: ziel - 15).bedtime, 30);
      expect(score(bedtimeMinutes: ziel - 120).bedtime, 30);
    });

    test('eine Einschlafzeit vor 18:00 kostet ebenfalls nichts', () {
      // Spec 10a, Punkt 1: 17:50 ist −10 auf der Skala, und
      // `max(0, −10 − 270)` ergibt null Abzug. Auf der alten, ungedrehten
      // Skala wäre 17:50 die Zahl 1430 gewesen — über 19 Stunden nach dem
      // Ziel, also maximal bestraft, obwohl die Nacht weit vor dem Ziel
      // begann.
      final frueh = EveningClock.minutesSinceEveningOfClock(
        hour: 17,
        minute: 50,
      );
      expect(frueh, -10.0);
      expect(score(bedtimeMinutes: frueh).bedtime, 30);
    });

    test('der Deckel liegt bei 0, nicht im Negativen', () {
      // 450 Minuten später sind genau 30 Punkte Abzug.
      expect(score(bedtimeMinutes: ziel + 450).bedtime, 0);
      expect(score(bedtimeMinutes: ziel + 900).bedtime, 0);
    });

    test('ohne Einschlafzeit entfällt die Teilnote', () {
      final ergebnis = score(bedtimeMinutes: null);
      expect(ergebnis.bedtime, isNull);
      // Null Punkte behaupteten ein schlechtes Ergebnis, das niemand
      // gemessen hat (`docs/SPEC.md` 4.6).
      expect(ergebnis.maxTotal, 70);
    });

    test('ein anderes Ziel verschiebt die Teilnote mit', () {
      // Ziel 23:00 statt 22:30: wer um 23:15 einschläft, ist eine
      // Viertelstunde zu spät, nicht dreiviertel.
      final spaeteresZiel = EveningClock.minutesSinceEveningOfClock(
        hour: 23,
        minute: 0,
      );
      final einschlafen = EveningClock.minutesSinceEveningOfClock(
        hour: 23,
        minute: 15,
      );
      expect(
        score(
          bedtimeMinutes: einschlafen,
          bedtimeGoalMinutes: spaeteresZiel,
        ).bedtime,
        29,
      );
    });

    test('die Teilnote kennt kein Fenster über frühere Nächte', () {
      // Die alte Teilnote brauchte mindestens eine Vornacht als Bezug. Die
      // neue nicht: Ein Ziel gibt es ab der ersten Nacht, und `score`
      // bekommt gar keine Liste früherer Nächte mehr.
      expect(score(bedtimeMinutes: ziel).bedtime, 30);
    });
  });

  group('Teilnote Unterbrechungen (max 20)', () {
    test('ohne Wachliegen volle 20', () {
      expect(score(awakeMinutes: 0, wakeCount: 0).interruptions, 20);
    });

    test('genau zehn Wachminuten und zehn Wachphasen kosten nichts', () {
      // Die beiden Grenzen sind gemessen, nicht gesetzt — Herleitung in
      // `docs/SPEC.md` 4.6.
      expect(score(awakeMinutes: 10, wakeCount: 10).interruptions, 20);
    });

    test('jede Wachminute über zehn kostet einen halben Punkt', () {
      expect(score(awakeMinutes: 20, wakeCount: 0).interruptions, 15);
      expect(score(awakeMinutes: 30, wakeCount: 0).interruptions, 10);
    });

    test('jede Wachphase über zehn kostet einen ganzen Punkt', () {
      expect(score(awakeMinutes: 0, wakeCount: 16).interruptions, 14);
      expect(score(awakeMinutes: 0, wakeCount: 20).interruptions, 10);
    });

    test('beide Abzüge gelten nebeneinander', () {
      // 20 − 0,5·(30−10) − 1,0·(20−10) = 20 − 10 − 10 = 0.
      expect(score(awakeMinutes: 30, wakeCount: 20).interruptions, 0);
    });

    test('der Deckel liegt bei 0, nicht im Negativen', () {
      expect(score(awakeMinutes: 300, wakeCount: 90).interruptions, 0);
    });
  });

  group('Summe, erreichbare Punkte und Bewertung', () {
    test('die Summe ist die Summe der drei Teilnoten', () {
      final ergebnis = score(
        asleepHours: 8,
        goalHours: 8,
        bedtimeMinutes: ziel + 90,
        awakeMinutes: 20,
        wakeCount: 0,
      );
      expect(ergebnis.duration, 50);
      expect(ergebnis.bedtime, 24);
      expect(ergebnis.interruptions, 15);
      expect(ergebnis.total, 89);
      expect(ergebnis.maxTotal, 100);
    });

    test('ohne Zubettgehzeit zählt die fehlende Teilnote nicht als 0', () {
      final ergebnis = score(
        asleepHours: 8,
        goalHours: 8,
        bedtimeMinutes: null,
        awakeMinutes: 0,
        wakeCount: 0,
      );
      expect(ergebnis.total, 70);
      expect(ergebnis.maxTotal, 70);
      // Der Ring normiert **nicht** um: 70 von 70 ist sehr gut, nicht 70 %.
      expect(ergebnis.rating, SleepRating.veryGood);
    });

    test('Bewertung über 100 erreichbare Punkte', () {
      expect(
        const SleepScore(duration: 50, bedtime: 30, interruptions: 20).rating,
        SleepRating.veryGood,
      );
      expect(
        const SleepScore(duration: 50, bedtime: 15, interruptions: 20).rating,
        SleepRating.veryGood, // 85 von 100 — genau auf der Schwelle
      );
      expect(
        const SleepScore(duration: 50, bedtime: 14, interruptions: 20).rating,
        SleepRating.good, // 84
      );
      expect(
        const SleepScore(duration: 50, bedtime: 0, interruptions: 20).rating,
        SleepRating.good, // 70 — genau auf der Schwelle
      );
      expect(
        const SleepScore(duration: 49, bedtime: 0, interruptions: 20).rating,
        SleepRating.okay, // 69
      );
      expect(
        const SleepScore(duration: 35, bedtime: 0, interruptions: 20).rating,
        SleepRating.okay, // 55 — genau auf der Schwelle
      );
      expect(
        const SleepScore(duration: 34, bedtime: 0, interruptions: 20).rating,
        SleepRating.low, // 54
      );
    });

    test('Bewertung über 70 erreichbare Punkte', () {
      // Die Schwellen liegen hier zwischen zwei ganzen Punkten (59,5 / 49 /
      // 38,5). Verglichen wird deshalb der Anteil selbst, nicht auf ganze
      // Prozent gerundet.
      expect(
        const SleepScore(duration: 40, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.veryGood, // 60 von 70 = 0,857
      );
      expect(
        const SleepScore(duration: 39, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.good, // 59 von 70 = 0,843
      );
      expect(
        const SleepScore(duration: 29, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.good, // 49 von 70 = genau 0,70
      );
      expect(
        const SleepScore(duration: 28, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.okay, // 48 von 70 = 0,686
      );
      expect(
        const SleepScore(duration: 19, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.okay, // 39 von 70 = 0,557
      );
      expect(
        const SleepScore(duration: 18, bedtime: null, interruptions: 20)
            .rating,
        SleepRating.low, // 38 von 70 = 0,543
      );
    });

    test('ein leerer Score ist niedrig, nicht gut', () {
      expect(
        const SleepScore(duration: 0, bedtime: 0, interruptions: 0).rating,
        SleepRating.low,
      );
    });

    test('zwei gleiche SleepScore sind gleich', () {
      expect(
        const SleepScore(duration: 50, bedtime: 30, interruptions: 20),
        const SleepScore(duration: 50, bedtime: 30, interruptions: 20),
      );
      expect(
        const SleepScore(duration: 50, bedtime: null, interruptions: 20),
        isNot(const SleepScore(duration: 50, bedtime: 0, interruptions: 20)),
      );
    });
  });

  group('Die Reihe über mehrere Nächte', () {
    DateTime tag(int tagImMonat) =>
        BerlinCalendar.startOfDay(DateTime.utc(2026, 6, tagImMonat));

    /// 22:30 Berliner Zeit am Vorabend des genannten Tages. Im Juni gilt
    /// Sommerzeit (UTC+2), 22:30 Berlin ist also 20:30 UTC.
    DateTime einschlafenVor(int tagImMonat) =>
        DateTime.utc(2026, 6, tagImMonat - 1, 20, 30);

    test('der Schlüssel ist das Datum der Nacht', () {
      final reihe = SleepScoring.series(
        nights: [
          RecoveryNight(
            date: tag(10),
            asleepMinutes: 480,
            bedtime: einschlafenVor(10),
          ),
          RecoveryNight(
            date: tag(11),
            asleepMinutes: 240,
            bedtime: einschlafenVor(11),
          ),
        ],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      expect(reihe.keys, containsAll(<DateTime>[tag(10), tag(11)]));
      expect(reihe[tag(10)]!.duration, 50);
      expect(reihe[tag(11)]!.duration, 25);
    });

    test('Nächte ohne Schlafminuten fallen heraus', () {
      // Das Kriterium sind die Schlafminuten, nicht „keine Abschnitte":
      // Eine Nacht aus lauter Wachabschnitten ist nicht leer, aber auch
      // kein Schlaf.
      final reihe = SleepScoring.series(
        nights: [
          RecoveryNight(date: tag(10), asleepMinutes: 0, awakeMinutes: 120),
          RecoveryNight(date: tag(11), asleepMinutes: 480),
        ],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      expect(reihe.keys, [tag(11)]);
    });

    test('eine leere Eingabe ergibt eine leere Reihe', () {
      expect(
        SleepScoring.series(
          nights: const [],
          goalHours: 8,
          bedtimeGoalMinutes: ziel,
        ),
        isEmpty,
      );
    });

    test('jede Nacht rechnet für sich — Nachbarnächte ändern nichts', () {
      // Der sichtbare Gewinn der neuen Teilnote: Die rollende Liste der
      // Einschlafzeiten entfällt. Dieselbe Nacht muss allein denselben
      // Score bekommen wie inmitten von zehn anderen.
      final einzelneNacht = RecoveryNight(
        date: tag(10),
        asleepMinutes: 420,
        bedtime: einschlafenVor(10),
        awakeMinutes: 25,
        wakeCount: 12,
      );

      final allein = SleepScoring.series(
        nights: [einzelneNacht],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      final inGesellschaft = SleepScoring.series(
        nights: [
          for (var i = 1; i < 10; i++)
            RecoveryNight(
              date: tag(i),
              asleepMinutes: 600,
              // Deutlich andere Einschlafzeiten: 02:00 nachts. Unter der
              // alten Teilnote hätten sie den Bezugswert verschoben.
              bedtime: DateTime.utc(2026, 6, i, 0, 0),
            ),
          einzelneNacht,
        ],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      expect(inGesellschaft[tag(10)], allein[tag(10)]);
    });

    test('eine Nacht ohne Einschlafzeit bleibt in der Reihe, ohne Teilnote',
        () {
      final reihe = SleepScoring.series(
        nights: [RecoveryNight(date: tag(10), asleepMinutes: 480)],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      expect(reihe[tag(10)]!.bedtime, isNull);
      expect(reihe[tag(10)]!.maxTotal, 70);
    });

    test('die Einschlafzeit wird über EveningClock gelesen', () {
      // 20:30 UTC = 22:30 Berliner Sommerzeit = genau die Zielzeit.
      final reihe = SleepScoring.series(
        nights: [
          RecoveryNight(
            date: tag(10),
            asleepMinutes: 480,
            bedtime: einschlafenVor(10),
          ),
        ],
        goalHours: 8,
        bedtimeGoalMinutes: ziel,
      );

      expect(reihe[tag(10)]!.bedtime, 30);
    });
  });
}
