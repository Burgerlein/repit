import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`GymPulse`** — die Rechnungen hinter dem Pulsverlauf und dem
/// Übungsband im Gym-Verlauf. Ticket #512, Spec
/// `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, Abschnitt 4.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert** — die Entscheidung trifft Tim oder der Test-Agent.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/gym_pulse.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart` — diese Datei importiert das Barrel, also ist
/// der Export Teil des Vertrags.
///
/// ```dart
/// final class PulseSummary {           // ==, hashCode über alle Felder
///   const PulseSummary({
///     required double avg, required double min, required double max,
///   });
/// }
///
/// final class GymExerciseSection {     // ==, hashCode über alle Felder
///   const GymExerciseSection({
///     required int position,           // ab 1, Position in session.exercises
///     required String exerciseId,
///     required DateTime start,
///     required DateTime end,
///   });
/// }
///
/// abstract final class GymPulse {
///   static int bucketCount({required double minutes});
///   static PulseSummary? summary({
///     required List<ChartSample> samples,
///     required DateTime from,
///     required DateTime to,
///   });
///   static List<GymExerciseSection> sections({
///     required ImportedSession session,
///     required DateTime from,
///     required DateTime to,
///   });
/// }
/// ```
///
/// Der Kern kennt weder `WorkoutSample` noch `QuantitySample`: Stichproben
/// kommen als `ChartSample`, Sitzungen als `ImportedSession` (beides schon im
/// Kern).
///
/// ## Was hier **nicht** getestet wird
///
/// - Die Verdichtung zu Spannen — das ist `SpanBuckets` (`span_buckets_test`).
/// - Die Zuordnung des Trainings — das ist `GymWorkoutMatch`
///   (`gym_workout_match_test`).
/// - **Überlappende Abschnitte** (Supersätze): offene Entscheidung 4 der
///   Spec. Die Rechnung liefert sie, wie sie sind; wie das Band sie zeichnet,
///   ist nicht entschieden.
///
/// Alle Zeitpunkte sind UTC, alle Daten erfunden.

/// Beginn des Apple-Trainings der Beispiele: Montag, 09.03.2026, 08:00 Berliner
/// Zeit (MEZ, +1).
final _t0 = DateTime.utc(2026, 3, 9, 7);

DateTime _m(int minuten) => _t0.add(Duration(minutes: minuten));

/// Ortszeit desselben Zeitpunkts — so liefert sie der Platform-Channel
/// (`DateTime.fromMillisecondsSinceEpoch` ohne `isUtc`).
DateTime _ort(DateTime zeitpunkt) =>
    DateTime.fromMillisecondsSinceEpoch(zeitpunkt.millisecondsSinceEpoch);

ChartSample _s(int minute, double wert) =>
    ChartSample(date: _m(minute), value: wert);

ImportedExercise _uebung(String id, List<int?> minuten) => ImportedExercise(
  exerciseId: id,
  sets: [
    for (final minute in minuten)
      CompletedSet(
        weight: 60,
        reps: 10,
        recordedAt: minute == null ? null : _m(minute),
      ),
  ],
);

ImportedSession _sitzung(List<ImportedExercise> uebungen) => ImportedSession(
  id: 'S',
  date: _t0,
  workout: Workout.a,
  minutes: 65,
  note: null,
  exercises: uebungen,
);

/// Das Fenster des Apple-Trainings: 68 Minuten ab [_t0].
final _von = _m(0);
final _bis = _m(68);

List<GymExerciseSection> _abschnitte(ImportedSession sitzung) =>
    GymPulse.sections(session: sitzung, from: _von, to: _bis);

void main() {
  group('bucketCount — ein Abschnitt je zwei Minuten, 12 bis 36', () {
    test('unter 24 Minuten bleibt es bei 12', () {
      for (final minuten in [0.0, 1.0, 10.0, 23.9, 24.0, 25.9]) {
        expect(
          GymPulse.bucketCount(minutes: minuten),
          12,
          reason: '$minuten min: Die Untergrenze trägt, damit das Band lesbar bleibt',
        );
      }
    });

    test('darüber ein Abschnitt je zwei Minuten, nach unten gerundet', () {
      expect(GymPulse.bucketCount(minutes: 26), 13);
      expect(GymPulse.bucketCount(minutes: 27.9), 13);
      expect(GymPulse.bucketCount(minutes: 28), 14);
      expect(GymPulse.bucketCount(minutes: 40), 20);
      expect(GymPulse.bucketCount(minutes: 67.9), 33);
      expect(GymPulse.bucketCount(minutes: 68), 34);
    });

    test('nach oben endet es bei 36', () {
      expect(GymPulse.bucketCount(minutes: 71.9), 35);
      expect(GymPulse.bucketCount(minutes: 72), 36);
      expect(GymPulse.bucketCount(minutes: 73), 36);
      expect(GymPulse.bucketCount(minutes: 500), 36);
    });

    test('eine negative Dauer ist keine Ausnahme, sondern die Untergrenze', () {
      expect(GymPulse.bucketCount(minutes: -5), 12);
    });
  });

  group('summary — Ø, Min und Max über ein Zeitfenster', () {
    test('Mittel, Tiefst- und Höchstwert der Stichproben im Fenster', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(5, 100), _s(10, 110), _s(20, 120)],
        from: _von,
        to: _bis,
      );

      expect(ergebnis, isNotNull);
      expect(ergebnis!.avg, 110);
      expect(ergebnis.min, 100);
      expect(ergebnis.max, 120);
    });

    test('keine Stichproben: null, nicht 0 (`01`)', () {
      expect(
        GymPulse.summary(samples: const [], from: _von, to: _bis),
        isNull,
      );
    });

    test('Stichproben nur außerhalb des Fensters: null', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(-10, 90), _s(80, 95)],
        from: _von,
        to: _bis,
      );

      expect(ergebnis, isNull);
    });

    test('ein Fenster, dessen Ende vor dem Beginn liegt, gibt null — keine '
        'Ausnahme', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(10, 100)],
        from: _bis,
        to: _von,
      );

      expect(ergebnis, isNull);
    });

    test('beide Grenzen gehören dazu, eine Mikrosekunde daneben nicht', () {
      final ergebnis = GymPulse.summary(
        samples: [
          ChartSample(
            date: _von.subtract(const Duration(microseconds: 1)),
            value: 40,
          ),
          ChartSample(date: _von, value: 100),
          ChartSample(date: _bis, value: 120),
          ChartSample(
            date: _bis.add(const Duration(microseconds: 1)),
            value: 220,
          ),
        ],
        from: _von,
        to: _bis,
      );

      expect(ergebnis!.min, 100, reason: 'Die 40 davor zählt nicht');
      expect(ergebnis.max, 120, reason: 'Die 220 danach zählt nicht');
      expect(ergebnis.avg, 110, reason: 'Genau die beiden auf den Grenzen');
    });

    test('das Mittel ist nicht zeitgewichtet', () {
      // Drei Stichproben dicht beieinander, eine lange danach. Zeitgewichtet
      // wöge die 100 fast das ganze Training; hier zählt jede Probe einmal.
      final ergebnis = GymPulse.summary(
        samples: [_s(0, 100), _s(1, 100), _s(2, 100), _s(50, 200)],
        from: _von,
        to: _bis,
      );

      expect(ergebnis!.avg, 125);
    });

    test('die Reihenfolge der Eingabe spielt keine Rolle', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(30, 130), _s(5, 90), _s(60, 110)],
        from: _von,
        to: _bis,
      );

      expect(ergebnis!.min, 90);
      expect(ergebnis.max, 130);
    });

    test('eine einzige Stichprobe: Mittel, Tiefst- und Höchstwert sind sie', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(12, 117)],
        from: _von,
        to: _bis,
      );

      expect(ergebnis!.avg, 117);
      expect(ergebnis.min, 117);
      expect(ergebnis.max, 117);
    });

    test('ein Fenster in Ortszeit trifft Stichproben in UTC '
        '(Zeitpunkte, nicht `==`)', () {
      final ergebnis = GymPulse.summary(
        samples: [_s(0, 100), _s(68, 120)],
        from: _ort(_von),
        to: _ort(_bis),
      );

      expect(
        ergebnis,
        isNotNull,
        reason:
            'Der Kanal liefert Ortszeit, `recordedAt` und die Proben sind UTC '
            '— `DateTime ==` unterscheidet beide, die Rechnung darf es nicht',
      );
      expect(ergebnis!.avg, 110);
    });

    test('die übergebene Liste bleibt unverändert und darf unveränderlich '
        'sein', () {
      final eingabe = List<ChartSample>.unmodifiable([_s(30, 130), _s(5, 90)]);

      GymPulse.summary(samples: eingabe, from: _von, to: _bis);

      expect(eingabe.map((e) => e.value), [130, 90]);
    });

    test('PulseSummary ist ein Werttyp (Fehler `03`)', () {
      const a = PulseSummary(avg: 110, min: 100, max: 120);
      const b = PulseSummary(avg: 110, min: 100, max: 120);
      const c = PulseSummary(avg: 110, min: 100, max: 121);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('sections — die Abschnitte je Übung aus den Satzzeiten', () {
    test('ohne jede Uhrzeit — alles Übernommene — gibt es keinen Abschnitt',
        () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [null, null, null]),
          _uebung('dips', [null, null]),
        ]),
      );

      expect(
        ergebnis,
        isEmpty,
        reason:
            'Es wird nichts gleichmäßig verteilt und nichts aus Satzzahl und '
            'Pause geschätzt',
      );
    });

    test('eine Übung mit Uhrzeiten: von der frühesten bis zur spätesten', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [3, 11, 19]),
        ]),
      );

      expect(ergebnis, [
        GymExerciseSection(
          position: 1,
          exerciseId: 'benchPress',
          start: _m(3),
          end: _m(19),
        ),
      ]);
    });

    test('die Reihenfolge der Sätze hängt nie an der Uhr: Minimum und '
        'Maximum, nicht erster und letzter', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [30, 10, 20]),
        ]),
      );

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.start, _m(10));
      expect(ergebnis.single.end, _m(30));
    });

    test('weniger als zwei Uhrzeiten: kein Abschnitt — die erste ist das '
        'Ende des ersten Satzes, wo er begann, steht nirgends', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [10]),
          _uebung('dips', [12, null, null]),
        ]),
      );

      expect(ergebnis, isEmpty);
    });

    test('zwei gleiche Uhrzeiten haben die Breite null und ergeben keinen '
        'Abschnitt', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [10, 10]),
        ]),
      );

      expect(ergebnis, isEmpty);
    });

    test('Sätze ohne Uhrzeit tragen zur Lage nichts bei und verschieben '
        'nichts', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [10, null, null, 20]),
        ]),
      );

      expect(ergebnis.single.start, _m(10));
      expect(ergebnis.single.end, _m(20));
    });

    test('die Position zählt jede Übung der Sitzung, auch die ohne '
        'Abschnitt — Fehlt Übung 2, heißt der nächste Abschnitt „3"', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [3, 19]),
          _uebung('inclineDumbbellPress', [null, null]),
          _uebung('dips', [47, 57]),
        ]),
      );

      expect(ergebnis.map((a) => a.position), [1, 3]);
      expect(ergebnis.map((a) => a.exerciseId), ['benchPress', 'dips']);
    });

    test('Pausen bleiben Lücken: der Abschnitt endet bei seiner letzten '
        'Uhrzeit, nicht am Anfang des nächsten', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [3, 19]),
          _uebung('inclineDumbbellPress', [21, 33]),
        ]),
      );

      expect(ergebnis, hasLength(2));
      expect(ergebnis[0].end, _m(19));
      expect(ergebnis[1].start, _m(21));
      expect(
        ergebnis[1].start.isAfter(ergebnis[0].end),
        isTrue,
        reason: 'Zwischen 19 und 21 liegt der Umbau — keine Übung',
      );
    });

    test('derselbe Übungstyp zweimal in einer Sitzung: zwei Abschnitte, zwei '
        'Positionen', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('lateralRaise', [5, 12]),
          _uebung('dips', [20, 30]),
          _uebung('lateralRaise', [40, 50]),
        ]),
      );

      expect(ergebnis.map((a) => a.position), [1, 2, 3]);
      expect(ergebnis.map((a) => a.exerciseId), [
        'lateralRaise',
        'dips',
        'lateralRaise',
      ]);
    });

    test('die Rückgabe folgt der Sitzung, nicht der Zeit', () {
      // Übung 2 wurde (laut Uhr) vor Übung 1 eingetragen.
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [30, 40]),
          _uebung('dips', [5, 15]),
        ]),
      );

      expect(ergebnis.map((a) => a.position), [1, 2]);
    });

    test('ein Abschnitt, der ganz im Fenster liegt, bleibt — auch genau auf '
        'beiden Grenzen', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [0, 68]),
        ]),
      );

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.start, _m(0));
      expect(ergebnis.single.end, _m(68));
    });

    test('beginnt ein Abschnitt vor dem Fenster, entsteht keiner — Eingabezeit '
        'ist nicht Hebezeit', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [-30, 10]),
        ]),
      );

      expect(ergebnis, isEmpty);
    });

    test('endet ein Abschnitt nach dem Fenster, entsteht keiner — alles oder '
        'nichts, es wird nicht beschnitten', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [60, 90]),
        ]),
      );

      expect(
        ergebnis,
        isEmpty,
        reason:
            'Ein beschnittener Abschnitt behauptete eine Zeit, die niemand '
            'aufgezeichnet hat',
      );
    });

    test('wer ein Training am nächsten Tag nachträgt, bekommt keinen '
        'Abschnitt — die anderen Übungen im Fenster bleiben', () {
      final ergebnis = _abschnitte(
        _sitzung([
          _uebung('benchPress', [3, 19]),
          _uebung('dips', [24 * 60 + 5, 24 * 60 + 15]),
        ]),
      );

      expect(ergebnis.map((a) => a.position), [1]);
    });

    test('ein Fenster, dessen Ende nicht nach dem Beginn liegt, gibt eine '
        'leere Liste — keine Ausnahme', () {
      final sitzung = _sitzung([
        _uebung('benchPress', [3, 19]),
      ]);

      expect(
        GymPulse.sections(session: sitzung, from: _bis, to: _von),
        isEmpty,
      );
      expect(
        GymPulse.sections(session: sitzung, from: _von, to: _von),
        isEmpty,
      );
    });

    test('eine Sitzung ohne Übungen gibt eine leere Liste', () {
      expect(_abschnitte(_sitzung(const [])), isEmpty);
    });

    test('ein Fenster in Ortszeit und Satzzeiten in UTC: derselbe Abschnitt '
        '(Zeitpunkte, nicht `==`)', () {
      final ergebnis = GymPulse.sections(
        session: _sitzung([
          _uebung('benchPress', [3, 19]),
        ]),
        from: _ort(_von),
        to: _ort(_bis),
      );

      expect(
        ergebnis,
        hasLength(1),
        reason: 'Der Kanal liefert Ortszeit, `recordedAt` ist UTC',
      );
      expect(ergebnis.single.position, 1);
    });

    test('GymExerciseSection ist ein Werttyp (Fehler `03`)', () {
      final a = GymExerciseSection(
        position: 1,
        exerciseId: 'benchPress',
        start: _m(3),
        end: _m(19),
      );
      final b = GymExerciseSection(
        position: 1,
        exerciseId: 'benchPress',
        start: _m(3),
        end: _m(19),
      );
      final c = GymExerciseSection(
        position: 2,
        exerciseId: 'benchPress',
        start: _m(3),
        end: _m(19),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
