import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`SleepMerge`** (#192) — die Rechnung dahinter, ob eine von
/// Hand eingetragene Nacht die gemessene *korrigiert* oder zu ihr
/// *dazukommt*, und was aus den Eingaben des Score wird, wenn sie
/// dazukommt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Regel kommt
///
/// Tim am 30.10.2026 am Gerät: „ich will einen schlaf nachtragen von
/// gestern. ich habe von 19-21:30 geschlafen wenn ich das mache wird die
/// nacht überschrieben". Die Regel aus #131 („Der Eintrag gewinnt, und
/// zwar ganz") trägt weiter **für eine Korrektur** — eine aus gemessener
/// Dauer und eingetippter Einschlafzeit zusammengesetzte Nacht hätte es so
/// nie gegeben. **Für eine Ergänzung ist sie falsch:** Schlaf von 19:00 bis
/// 21:30 korrigiert die gemessene Nacht nicht, er kommt dazu.
///
/// Tims Entscheidung vom 30.10.2026: **Addieren, wenn es sich nicht
/// überlappt.** Ein Eintrag, der die gemessene Zeit nicht überlappt, wird
/// dazugezählt; nur ein Eintrag, der sie überlappt, gilt als Korrektur.
///
/// ## Die Grenzfallregel
///
/// **Fünf Minuten — dieselbe Schwelle und dieselbe Haltung wie
/// `kleinsteMessluecke` (#156).** Ein getipptes Fenster ist minutengenau
/// und aus der Erinnerung, ein gemessenes sekundengenau von der Uhr; was
/// sich davon an den Rändern berührt, ist eine Rundung und keine Aussage
/// über denselben Schlaf. Darunter ersetzt zu werden hieße, eine ganze
/// gemessene Nacht für eine Berührung wegzuwerfen — genau der Fehler
/// dieses Tickets; darüber addiert zu werden hieße, einmal geschlafene
/// Minuten zweimal zu zählen.
///
/// Drei Fälle gelten weiterhin als **Korrektur**, weil der Eintrag sich
/// nicht auf die Uhr legen lässt: ohne Uhrzeiten („nur Dauer"), mit einem
/// Fenster, das nicht vorwärts läuft, und wenn es gar keine gemessene
/// Nacht gibt.
///
/// ## Der Score einer Nacht aus zwei Strecken
///
/// - **Dauer:** beide zusammen. Zwei Aussagen über geschlafene Minuten
///   addieren sich, so wie der Tagschlaf es schon tut.
/// - **Zubettgehzeit:** die der **längeren** Strecke; bei gleicher Länge
///   die frühere, wobei eine Strecke ohne Uhrzeit nie die frühere ist. Hat
///   die gewählte Strecke keine Uhrzeit, **entfällt** die Teilnote — eine
///   andere Strecke einzusetzen hieße, einen Nachtbeginn zu behaupten, den
///   niemand kennt.
/// - **Unterbrechungen:** unverändert aus der gemessenen Strecke. Der
///   Eintrag zählt keine Wachphasen, und die gemessenen sind gemessen;
///   sie wegzuwerfen wäre genauso erfunden wie welche dazuzudichten.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/src/sleep_merge.dart, über das Barrel exportiert
///
/// abstract final class SleepMerge {
///   /// Ab so vielen Minuten Überschneidung ist ein Eintrag eine Korrektur.
///   static const double minimumOverlapMinutes = 5;
///
///   /// Ob der Eintrag die gemessene Nacht korrigiert (`true`) oder zu ihr
///   /// dazukommt (`false`). Alle vier Zeiten zählen Minuten seit 18:00
///   /// ([EveningClock]).
///   static bool corrects({
///     required double? entryStart,
///     required double? entryEnd,
///     required double? measuredStart,
///     required double? measuredEnd,
///   });
///
///   /// Die Eingaben des Score für eine Nacht aus zwei Strecken.
///   static ({
///     double asleepMinutes,
///     double? bedtimeMinutes,
///     double awakeMinutes,
///     int wakeCount,
///   }) combined({
///     required double measuredAsleepMinutes,
///     required double? measuredBedtimeMinutes,
///     required double measuredAwakeMinutes,
///     required int measuredWakeCount,
///     required double entryAsleepMinutes,
///     required double? entryBedtimeMinutes,
///   });
/// }
/// ```
void main() {
  /// Minuten seit 18:00 für eine Wanduhrzeit — dieselbe Skala, auf der der
  /// Score rechnet.
  double uhr(int stunde, [int minute = 0]) =>
      EveningClock.minutesSinceEveningOfClock(hour: stunde, minute: minute);

  // ───────────────────────────────────────────────────────────────────────
  // Korrektur oder Ergänzung
  // ───────────────────────────────────────────────────────────────────────

  group('corrects — Tims Fall', () {
    test('19:00 bis 21:30 neben einer gemessenen Nacht ab 23:10 ist eine '
        'Ergänzung, keine Korrektur', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(19),
          entryEnd: uhr(21, 30),
          measuredStart: uhr(23, 10),
          measuredEnd: uhr(6, 40),
        ),
        isFalse,
      );
    });

    test('und dieselbe Nacht noch einmal eingetippt ist eine Korrektur', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(23, 10),
          entryEnd: uhr(6, 15),
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
      );
    });
  });

  group('corrects — die Grenze liegt bei fünf Minuten', () {
    bool mitUeberschneidung(double minuten) => SleepMerge.corrects(
      entryStart: uhr(19),
      // Das Fenster des Eintrags reicht um `minuten` in die gemessene
      // Nacht hinein, die um 23:00 beginnt.
      entryEnd: uhr(23) + minuten,
      measuredStart: uhr(23),
      measuredEnd: uhr(6, 40),
    );

    test('genau fünf Minuten überschneiden sich: Korrektur', () {
      expect(mitUeberschneidung(5), isTrue);
    });

    test('vier Minuten: Ergänzung — das ist eine Rundung, keine Aussage', () {
      expect(mitUeberschneidung(4), isFalse);
    });

    test('eine Minute ebenso', () {
      expect(mitUeberschneidung(1), isFalse);
    });

    test('Kante an Kante ist keine Überschneidung', () {
      expect(mitUeberschneidung(0), isFalse);
    });

    test('und die Schwelle steht als Zahl da, nicht im Rechenweg', () {
      expect(SleepMerge.minimumOverlapMinutes, 5);
    });
  });

  group('corrects — die Überschneidung zählt in beide Richtungen', () {
    test('ein Eintrag, der hinten in die Nacht hineinragt, korrigiert', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(6),
          entryEnd: uhr(9),
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
      );
    });

    test('ein Eintrag, der hinter der Nacht liegt, kommt dazu', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(7),
          entryEnd: uhr(9),
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isFalse,
      );
    });

    test(
      'ein Eintrag, der die gemessene Nacht ganz umschließt, korrigiert',
      () {
        expect(
          SleepMerge.corrects(
            entryStart: uhr(22),
            entryEnd: uhr(8),
            measuredStart: uhr(23),
            measuredEnd: uhr(6, 40),
          ),
          isTrue,
        );
      },
    );

    test('und eine gemessene Nacht, die ganz im Eintrag liegt, ebenso', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(23),
          entryEnd: uhr(7),
          measuredStart: uhr(1),
          measuredEnd: uhr(3),
        ),
        isTrue,
      );
    });
  });

  group('corrects — was sich nicht auf die Uhr legen lässt, korrigiert', () {
    test('ein Eintrag ohne Uhrzeiten („nur Dauer")', () {
      expect(
        SleepMerge.corrects(
          entryStart: null,
          entryEnd: null,
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
        reason:
            'eine Dauer trägt keine Uhr — wo sie liegt, weiß niemand, und '
            'die ehrliche Lesart bleibt die aus #131',
      );
    });

    test('ein halb angegebenes Fenster ebenso', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(19),
          entryEnd: null,
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
      );
    });

    test('ein Fenster, das nicht vorwärts läuft', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(23),
          entryEnd: uhr(22),
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
      );
    });

    test('ein Fenster ohne Länge', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(19),
          entryEnd: uhr(19),
          measuredStart: uhr(23),
          measuredEnd: uhr(6, 40),
        ),
        isTrue,
      );
    });

    test('und eine gemessene Nacht, die es gar nicht gibt — dann ist der '
        'Eintrag die Nacht', () {
      expect(
        SleepMerge.corrects(
          entryStart: uhr(19),
          entryEnd: uhr(21, 30),
          measuredStart: null,
          measuredEnd: null,
        ),
        isTrue,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Eingaben des Score
  // ───────────────────────────────────────────────────────────────────────

  group('combined — die Dauer zählt zusammen', () {
    test('420 gemessene und 150 eingetragene Minuten sind 570', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 30,
        measuredWakeCount: 3,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.asleepMinutes, 570);
    });
  });

  group('combined — die Zubettgehzeit ist die der längeren Strecke', () {
    test('die gemessene Nacht ist die längere: ihre zählt', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 30,
        measuredWakeCount: 3,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(
        zusammen.bedtimeMinutes,
        uhr(23),
        reason:
            'die Teilnote fragt, wann die Nacht begann — von zwei Strecken '
            'ist die lange die Nacht',
      );
    });

    test('der Eintrag ist die längere Strecke: seine zählt', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 60,
        measuredBedtimeMinutes: uhr(4),
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 390,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.bedtimeMinutes, uhr(19));
    });

    test('bei gleicher Länge die frühere', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 150,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.bedtimeMinutes, uhr(19));
    });

    test('und bei gleicher Länge ist eine Strecke ohne Uhrzeit nie die '
        'frühere', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 150,
        measuredBedtimeMinutes: null,
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.bedtimeMinutes, uhr(19));
    });

    test('hat die längere Strecke keine Uhrzeit, entfällt die Teilnote — '
        'die kürzere einzusetzen behauptete einen Nachtbeginn, den niemand '
        'kennt', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: null,
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.bedtimeMinutes, isNull);
    });
  });

  group('combined — die Unterbrechungen kommen aus der gemessenen Strecke', () {
    test('Wachminuten und Wachphasen gehen unverändert durch', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 30,
        measuredWakeCount: 12,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.awakeMinutes, 30);
      expect(zusammen.wakeCount, 12);
    });

    test('der Eintrag fügt keine einzige Wachminute hinzu', () {
      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      expect(zusammen.awakeMinutes, 0);
      expect(zusammen.wakeCount, 0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Einmal durchgerechnet — die beiden Rechnungen zusammen
  // ───────────────────────────────────────────────────────────────────────

  group('Tims Nacht, von vorn bis hinten', () {
    test('gemessen 23:00–06:00 (420 min, durchgeschlafen) plus eingetragen '
        '19:00–21:30 (150 min): 9:30 h, Zubettgehzeit 23:00, '
        'Unterbrechungen gemessen — und 100 erreichbare Punkte', () {
      const zielStunden = 8.0;
      final zielBett = uhr(22, 30);

      final zusammen = SleepMerge.combined(
        measuredAsleepMinutes: 420,
        measuredBedtimeMinutes: uhr(23),
        measuredAwakeMinutes: 0,
        measuredWakeCount: 0,
        entryAsleepMinutes: 150,
        entryBedtimeMinutes: uhr(19),
      );

      final score = SleepScoring.score(
        asleepHours: zusammen.asleepMinutes / Duration.minutesPerHour,
        goalHours: zielStunden,
        bedtimeMinutes: zusammen.bedtimeMinutes,
        bedtimeGoalMinutes: zielBett,
        awakeMinutes: zusammen.awakeMinutes,
        wakeCount: zusammen.wakeCount,
      );

      // Dauer          min(50, 50 · 570/480)            = 50 (gedeckelt)
      // Zubettgehzeit  clamp(30 − max(0, 300−270)/15)   = 28
      // Unterbrechungen 20 − 0,5·max(0, 0−10) − 1·max(0, 0−10) = 20
      expect(score.duration, 50);
      expect(score.bedtime, 28);
      expect(score.interruptions, 20);
      expect(score.total, 98);
      expect(
        score.maxTotal,
        100,
        reason:
            'die gemessene Nacht ist vollständig da — ihre Phasen zu '
            'verlieren, nur weil daneben etwas eingetragen wurde, wäre der '
            'Fehler, gegen den dieses Ticket geschrieben ist',
      );
      expect(score.rating, SleepRating.veryGood);
    });
  });
}
