import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Zeitpunkt je Satz** — Ticket #78, Spec
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitt 11 („Die Uhrzeit je Satz"), Weg A.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Was hier festgelegt wird
///
/// ```dart
/// final class CompletedSet {
///   const CompletedSet({required double weight, required int reps, DateTime? recordedAt});
///   final DateTime? recordedAt;  // Vorgabewert null
/// }
///
/// final class RawSet {
///   const RawSet({required String weight, required String reps, DateTime? recordedAt});
///   final DateTime? recordedAt;  // Vorgabewert null
/// }
/// ```
///
/// `recordedAt` ist **der Moment, in dem der Satz vollständig wurde** — der
/// Zeitpunkt der **Eingabe**, nicht des Hebens (Spec 11.4). Eine spätere
/// Korrektur verschiebt ihn nicht; ein Satz, der geleert und neu gefüllt
/// wird, ist ein neuer Satz und bekommt einen neuen Zeitpunkt. Die beiden
/// letzten Sätze sind Verhalten der Erfassung und nicht hier prüfbar —
/// prüfbar ist ihre Kehrseite im Kern: **Der Kern erfindet keinen Zeitpunkt
/// und überschreibt keinen.** Er reicht durch, was hereingereicht wird, und
/// `null` bleibt `null`.
///
/// **Der Name sagt die Lesart** (Tims Entscheidung vom 10.11.2026, offene
/// Frage 6 der Spec): `recordedAt`, nicht `at`. Aus dem Feld wird später das
/// Übungsband in „Gym — Verlauf" (#79) gespeist, und dort entscheidet sich,
/// ob „gehoben um 18:42" oder „eingetragen um 18:42" dasteht. `at` sagt nur
/// „irgendwann" und legte damit die falsche Beschriftung nahe.
///
/// **Warum nullbar — und warum das der Hauptfall ist:** Die Übernahme aus
/// der alten App (#59) bringt Tims gesamten bisherigen Trainingsverlauf, und
/// dort gibt es keine Satzzeiten. Alles, was über diesen Weg hereinkommt,
/// trägt `recordedAt == null`; das iPhone ist seine einzige Kopie dieser
/// Daten. Ein erfundener Zeitstempel behauptete, der Satz sei zu dieser
/// Minute gehoben worden; `null` heißt ehrlich „nicht erfasst". Die Gruppe
/// „Sätze ohne Uhrzeit sind der Hauptfall" prüft diesen Weg deshalb
/// geschlossen und nicht nur nebenbei als Variante.
///
/// ## Die harte Randbedingung
///
/// Fünf bestehende Kern-Testdateien bauen `CompletedSet` ohne Zeitangabe
/// (`progression_test`, `one_rep_max_test`, `gym_session_test`,
/// `gym_session_builder_test`, `gym_session_merge_test`). Sie müssen
/// unverändert weiterlaufen — `.githooks/pre-commit` bricht jeden Commit ab,
/// der eine bestehende Testdatei anfasst. Daraus folgt: benannter optionaler
/// Parameter, Vorgabewert `null`, **`const`-Konstruktor bleibt.**
///
/// ## Die Entscheidung zu `isUtc` (#427)
///
/// Darts `DateTime.==` vergleicht **auch das `isUtc`-Flag**, `compareTo`
/// nicht. `DateTime.utc(2026, 9, 21, 16, 30)` und derselbe Augenblick als
/// Ortszeit sind also nicht gleich, obwohl sie denselben Moment bezeichnen.
///
/// **Entschieden: `recordedAt` wird als UTC geführt, und `==` vergleicht streng,
/// ohne vorher umzurechnen.** Begründung:
///
/// 1. **Ein nicht-UTC-Zeitpunkt ist in diesem Paket keine andere
///    Schreibweise desselben Moments, sondern ein falscher Wert.**
///    `BerlinCalendar` rechnet auf UTC-Zeitpunkten, die Berliner
///    Wanduhrzeiten bezeichnen; auf einer Ortszeit liest es die falschen
///    Felder und liefert lautlos den falschen Tag. Ein `==`, das beide
///    gleichsetzte, erklärte einen kaputten Wert für denselben wie den
///    heilen — und nähme damit das einzige Signal weg, an dem ein
///    vergessenes `.toUtc()` auffällt.
/// 2. **`ImportedSession.date` macht es heute schon so** und wird mit
///    `DateTime.==` verglichen. Zwei Regeln für Zeitpunkte in derselben
///    Typkette wären schlimmer als eine strenge.
/// 3. **Normalisieren ginge ohnehin nur in `==`**, nicht im Konstruktor:
///    Der bleibt `const`, und `const` kann nichts umrechnen. Eine
///    Gleichheit, die etwas heilt, was im Feld weiter falsch steht, wäre
///    eine Zusage, die der Code nicht einlöst.
///
/// Geprüft wird das unten ausdrücklich, damit es eine Entscheidung bleibt
/// und keine Nebenwirkung. **Nicht geprüft wird der `hashCode` dieses
/// Falls:** Darts `DateTime.hashCode` nimmt `isUtc` nicht auf, zwei
/// ungleiche Zeitpunkte desselben Augenblicks haben also denselben
/// `hashCode`. Das ist erlaubt — ungleiche Objekte dürfen sich einen
/// `hashCode` teilen — und nichts, was dieses Paket zusagen sollte.
///
/// **Alle Zeitpunkte und Zahlen hier sind erfunden.** Kein Gewicht, keine
/// Wiederholungszahl und kein Datum stammt aus Tims Trainingsverlauf oder
/// bezeichnet ein wirkliches Ereignis.

// Berliner Zeit am 21.09.2026 (Sommerzeit, UTC+2) — erfundene Werte.
final _t1 = DateTime.utc(2026, 9, 21, 16, 30); // 18:30 Berlin
final _t2 = DateTime.utc(2026, 9, 21, 16, 34); // 18:34 Berlin
final _t3 = DateTime.utc(2026, 9, 21, 16, 38); // 18:38 Berlin

/// Eine Prüfübung. Für die Steigerungslogik zählen nur `repLow`, `repHigh`,
/// `increment` und `isTimed`; der Rest ist Beiwerk.
Exercise _uebung({
  required String id,
  required int repLow,
  required int repHigh,
  required double increment,
}) {
  return Exercise(
    id: id,
    name: 'Prüfübung',
    sets: 3,
    repLow: repLow,
    repHigh: repHigh,
    increment: increment,
    cue: 'Nur für den Test.',
    howTo: const ['Schritt eins', 'Schritt zwei', 'Schritt drei'],
    commonMistake: 'Keiner.',
    youTubeQuery: 'Prüfübung',
    muscles: const {Muscle.chest: 1.0},
  );
}

/// Eine Sitzung aus einer Übung mit den genannten Sätzen.
ImportedSession _sitzung({
  required String id,
  required DateTime date,
  required Workout? workout,
  required String exerciseId,
  required List<CompletedSet> sets,
}) {
  return ImportedSession(
    id: id,
    date: date,
    workout: workout,
    minutes: null,
    note: null,
    exercises: [ImportedExercise(exerciseId: exerciseId, sets: sets)],
  );
}

void main() {
  group('CompletedSet trägt einen Zeitpunkt, muss aber keinen haben', () {
    test('ohne Zeitangabe gebaut trägt der Satz null', () {
      // Das ist die Zusage, an der die fünf bestehenden Testdateien hängen:
      // Sie bauen Sätze mit zwei Argumenten und müssen weiterlaufen.
      const satz = CompletedSet(weight: 40, reps: 8);

      expect(satz.recordedAt, isNull);
      expect(satz.weight, 40);
      expect(satz.reps, 8);
    });

    test('der Konstruktor bleibt const', () {
      // Zwei inhaltsgleiche const-Objekte werden kanonisiert und sind
      // dasselbe Objekt. Hielte der Konstruktor das nicht mehr aus, würde
      // diese Datei nicht einmal übersetzen — und die bestehenden Tests,
      // die Sätze in const-Listen führen, genauso wenig.
      const eins = CompletedSet(weight: 40, reps: 8);
      const zwei = CompletedSet(weight: 40, reps: 8);

      expect(identical(eins, zwei), isTrue);
    });

    test('ein ausdrückliches null ist dasselbe wie keine Zeitangabe', () {
      const ohne = CompletedSet(weight: 40, reps: 8);
      const ausdruecklich = CompletedSet(weight: 40, reps: 8, recordedAt: null);

      expect(ausdruecklich, ohne);
      expect(ausdruecklich.hashCode, ohne.hashCode);
    });

    test(
      'der Zeitpunkt wird als benannter Parameter übergeben und behalten',
      () {
        final satz = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);

        expect(satz.recordedAt, _t1);
        expect(
          satz.recordedAt!.isUtc,
          isTrue,
          reason: 'Der Kern führt UTC-Zeitpunkte.',
        );
      },
    );
  });

  group('== und hashCode beziehen den Zeitpunkt ein', () {
    test('gleiche Zahlen und derselbe Zeitpunkt sind derselbe Satz', () {
      final eins = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);
      final zwei = CompletedSet(
        weight: 40,
        reps: 8,
        recordedAt: DateTime.utc(2026, 9, 21, 16, 30),
      );

      expect(eins, zwei);
      expect(eins.hashCode, zwei.hashCode);
    });

    test('gleiche Zahlen, verschiedene Zeitpunkte sind verschiedene Sätze', () {
      // Ohne das rechnet jeder abgeleitete Riverpod-Wert neu, sobald eine
      // Satzliste neu gebaut wird — und umgekehrt bliebe eine geänderte
      // Satzzeit in der Ansicht unsichtbar. Beides wäre Fehler `03`.
      final frueh = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);
      final spaet = CompletedSet(weight: 40, reps: 8, recordedAt: _t3);

      expect(frueh, isNot(spaet));
      expect(frueh.hashCode, isNot(spaet.hashCode));
    });

    test('ein Satz mit Zeitpunkt ist nicht derselbe wie einer ohne', () {
      final mit = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);
      const ohne = CompletedSet(weight: 40, reps: 8);

      expect(mit, isNot(ohne));
      expect(ohne, isNot(mit));
      expect(mit.hashCode, isNot(ohne.hashCode));
    });

    test('zwei Sätze mit verschiedenen Zeitpunkten belegen zwei Plätze in '
        'einem Set', () {
      final menge = {
        CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
        CompletedSet(weight: 40, reps: 8, recordedAt: _t2),
        CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
      };

      expect(menge, hasLength(2));
    });

    test(
      'derselbe Augenblick auf zwei Wegen gebaut ist derselbe Zeitpunkt',
      () {
        final ausFeldern = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);
        final ausEpoch = CompletedSet(
          weight: 40,
          reps: 8,
          recordedAt: DateTime.fromMicrosecondsSinceEpoch(
            _t1.microsecondsSinceEpoch,
            isUtc: true,
          ),
        );

        expect(ausFeldern, ausEpoch);
        expect(ausFeldern.hashCode, ausEpoch.hashCode);
      },
    );

    test('eine Ortszeit ist nicht derselbe Satz wie der UTC-Zeitpunkt '
        'desselben Augenblicks', () {
      // Entschieden und nicht nebenbei entstanden — die Begründung steht im
      // Kopf dieser Datei (#427). Kurz: Eine Ortszeit ist in diesem Paket
      // kein anderer Anstrich desselben Moments, sondern ein Wert, den
      // `BerlinCalendar` falsch liest. Dass `==` sie nicht gleichsetzt, ist
      // das Signal für ein vergessenes `.toUtc()`.
      final utc = CompletedSet(weight: 40, reps: 8, recordedAt: _t1);
      final ortszeit = CompletedSet(
        weight: 40,
        reps: 8,
        recordedAt: _t1.toLocal(),
      );

      if (_t1.toLocal().isUtc) {
        // Läuft der Test auf einer Maschine, die auf UTC steht, gibt es den
        // Unterschied nicht und es bleibt nichts zu zeigen.
        expect(ortszeit, utc);
        return;
      }
      expect(ortszeit, isNot(utc));
      // Der hashCode wird hier bewusst nicht geprüft: Darts
      // `DateTime.hashCode` nimmt `isUtc` nicht auf, beide tragen also
      // denselben. Das ist erlaubt und keine Zusage dieses Pakets.
    });
  });

  group('RawSet trägt den Zeitpunkt durch die Zwischenstand-Ablage', () {
    test('ohne Zeitangabe gebaut trägt der Roh-Satz null', () {
      const roh = RawSet(weight: '40', reps: '8');

      expect(roh.recordedAt, isNull);
    });

    test('der Konstruktor bleibt const', () {
      const eins = RawSet(weight: '40', reps: '8');
      const zwei = RawSet(weight: '40', reps: '8');

      expect(identical(eins, zwei), isTrue);
    });

    test('derselbe Text zu verschiedenen Zeitpunkten ist nicht derselbe '
        'Roh-Satz', () {
      // Ein Satz, der geleert und neu gefüllt wird, ist ein neuer Satz
      // (Spec 11.4) — auch dann, wenn am Ende wieder dasselbe dasteht. Der
      // Zustand des Formulars umfasst deshalb den Zeitpunkt.
      final frueh = RawSet(weight: '40', reps: '8', recordedAt: _t1);
      final spaet = RawSet(weight: '40', reps: '8', recordedAt: _t3);

      expect(frueh, isNot(spaet));
      expect(frueh.hashCode, isNot(spaet.hashCode));
    });

    test('derselbe Text und derselbe Zeitpunkt sind derselbe Roh-Satz', () {
      final eins = RawSet(weight: '40', reps: '8', recordedAt: _t1);
      final zwei = RawSet(
        weight: '40',
        reps: '8',
        recordedAt: DateTime.utc(2026, 9, 21, 16, 30),
      );

      expect(eins, zwei);
      expect(eins.hashCode, zwei.hashCode);
    });

    test('ein Roh-Satz mit Zeitpunkt ist nicht derselbe wie einer ohne', () {
      final mit = RawSet(weight: '40', reps: '8', recordedAt: _t1);
      const ohne = RawSet(weight: '40', reps: '8');

      expect(mit, isNot(ohne));
      expect(mit.hashCode, isNot(ohne.hashCode));
    });
  });

  group('GymSessionBuilder reicht den Zeitpunkt durch', () {
    // Berliner Zeit 19:05 am 21.09.2026 — der Abschluss des Trainings.
    final abschluss = DateTime.utc(2026, 9, 21, 17, 5);

    test('aus einem Roh-Satz mit Zeitpunkt wird ein Satz mit demselben', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-1',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8', recordedAt: _t1)],
        },
      );

      expect(ergebnis?.exercises.single.sets, [
        CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
      ]);
    });

    test('ohne Zeitangabe erfindet der Builder keinen Zeitpunkt', () {
      // Weder „jetzt" noch das Abschlussdatum: Ein erfundener Zeitstempel
      // behauptete, der Satz sei zu dieser Minute entstanden.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-2',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [const RawSet(weight: '40', reps: '8')],
        },
      );

      expect(ergebnis?.exercises.single.sets.single.recordedAt, isNull);
    });

    test('jeder Satz behält seinen eigenen Zeitpunkt', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-3',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: '8', recordedAt: _t1),
            RawSet(weight: '40', reps: '7', recordedAt: _t2),
            RawSet(weight: '42.5', reps: '6', recordedAt: _t3),
          ],
        },
      );

      expect(
        ergebnis?.exercises.single.sets.map((s) => s.recordedAt).toList(),
        [_t1, _t2, _t3],
      );
    });

    test(
      'ein Satz ohne Zeitpunkt zwischen Sätzen mit Zeitpunkt bleibt leer',
      () {
        // Gemischte Herkunft: Was keinen Zeitpunkt hat, bekommt keinen vom
        // Nachbarn geliehen.
        final ergebnis = GymSessionBuilder.session(
          id: 'eigen-zeit-4',
          date: abschluss,
          workout: Workout.a,
          entries: {
            'benchPress': [
              RawSet(weight: '40', reps: '8', recordedAt: _t1),
              const RawSet(weight: '40', reps: '7'),
              RawSet(weight: '40', reps: '6', recordedAt: _t3),
            ],
          },
        );

        expect(
          ergebnis?.exercises.single.sets.map((s) => s.recordedAt).toList(),
          [_t1, null, _t3],
        );
      },
    );

    test('ein verworfener Satz nimmt seinen Zeitpunkt mit', () {
      // Die übrigen behalten ihren eigenen — die Zeitpunkte rutschen nicht
      // um einen Platz nach, wenn in der Mitte etwas wegfällt.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-5',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: '8', recordedAt: _t1),
            RawSet(weight: '40', reps: '', recordedAt: _t2),
            RawSet(weight: '40', reps: '6', recordedAt: _t3),
          ],
        },
      );

      expect(ergebnis?.exercises.single.sets, [
        CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
        CompletedSet(weight: 40, reps: 6, recordedAt: _t3),
      ]);
    });

    test(
      'ein unlesbares Gewicht lässt den Satz auch mit Zeitpunkt wegfallen',
      () {
        final ergebnis = GymSessionBuilder.session(
          id: 'eigen-zeit-6',
          date: abschluss,
          workout: Workout.a,
          entries: {
            'benchPress': [
              RawSet(weight: 'vierzig', reps: '8', recordedAt: _t1),
              RawSet(weight: '40', reps: '8', recordedAt: _t2),
            ],
          },
        );

        expect(ergebnis?.exercises.single.sets, [
          CompletedSet(weight: 40, reps: 8, recordedAt: _t2),
        ]);
      },
    );

    test('ein Zeitpunkt macht aus einem ungültigen Satz keinen gültigen', () {
      // Null Wiederholungen bleiben kein Satz, egal wann getippt wurde —
      // und ohne einen einzigen brauchbaren Satz entsteht keine Sitzung.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-7',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: '0', recordedAt: _t1),
            RawSet(weight: '40', reps: '', recordedAt: _t2),
          ],
        },
      );

      expect(ergebnis, isNull);
    });

    test('eine unbekannte Übungs-ID wird auch mit Zeitpunkten übergangen', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-8',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'gibtEsNicht': [RawSet(weight: '40', reps: '8', recordedAt: _t1)],
          'benchPress': [RawSet(weight: '40', reps: '8', recordedAt: _t2)],
        },
      );

      expect(ergebnis?.exercises.map((e) => e.exerciseId), ['benchPress']);
      expect(ergebnis?.exercises.single.sets.single.recordedAt, _t2);
    });

    test('Unterstützung dreht das Gewicht um, nicht den Zeitpunkt', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-9',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'dips': [RawSet(weight: '27', reps: '8', recordedAt: _t1)],
        },
        assist: const {'dips': true},
      );

      expect(ergebnis?.exercises.single.sets, [
        CompletedSet(weight: -27, reps: 8, recordedAt: _t1),
      ]);
    });

    test('das Abschlussdatum der Sitzung bleibt vom Satz-Zeitpunkt '
        'unberührt', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-zeit-10',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8', recordedAt: _t1)],
        },
      );

      expect(ergebnis?.date, abschluss);
    });
  });

  group('Die Sitzung trägt die Zeitpunkte mit', () {
    test('ImportedExercise unterscheidet Sätze an ihrem Zeitpunkt', () {
      final frueh = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t1)],
      );
      final spaet = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t3)],
      );

      expect(frueh, isNot(spaet));
      expect(frueh.hashCode, isNot(spaet.hashCode));
    });

    test('ImportedSession unterscheidet sich an einem einzigen '
        'Satz-Zeitpunkt', () {
      final tag = DateTime.utc(2026, 9, 21, 17, 5);
      final eine = _sitzung(
        id: 'eigen-1',
        date: tag,
        workout: Workout.a,
        exerciseId: 'benchPress',
        sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t1)],
      );
      final andere = _sitzung(
        id: 'eigen-1',
        date: tag,
        workout: Workout.a,
        exerciseId: 'benchPress',
        sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t2)],
      );

      expect(eine, isNot(andere));
      expect(eine.hashCode, isNot(andere.hashCode));
    });

    test('zwei gleich gebaute Sitzungen mit Zeitpunkten sind gleich', () {
      final tag = DateTime.utc(2026, 9, 21, 17, 5);
      ImportedSession bauen() => _sitzung(
        id: 'eigen-1',
        date: tag,
        workout: Workout.a,
        exerciseId: 'benchPress',
        sets: [
          CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
          CompletedSet(weight: 40, reps: 7, recordedAt: _t2),
        ],
      );

      // Das ist die Zusage, an der Riverpod hängt: Zweimal aus derselben
      // Ablage gelesen heißt zweimal gleich, sonst rechnet jeder
      // abgeleitete Wert neu (Fehler `03`).
      expect(bauen(), bauen());
      expect(bauen().hashCode, bauen().hashCode);
    });

    test('setCount und volumeKg rechnen unverändert', () {
      final mit = _sitzung(
        id: 'eigen-1',
        date: DateTime.utc(2026, 9, 21, 17, 5),
        workout: Workout.a,
        exerciseId: 'benchPress',
        sets: [
          CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
          CompletedSet(weight: -27, reps: 6, recordedAt: _t2),
        ],
      );
      final ohne = _sitzung(
        id: 'eigen-1',
        date: DateTime.utc(2026, 9, 21, 17, 5),
        workout: Workout.a,
        exerciseId: 'benchPress',
        sets: const [
          CompletedSet(weight: 40, reps: 8),
          CompletedSet(weight: -27, reps: 6),
        ],
      );

      expect(mit.setCount, ohne.setCount);
      expect(mit.volumeKg, ohne.volumeKg);
      expect(mit.volumeKg, 320);
    });
  });

  group('GymSessionMerge verliert den Zeitpunkt nicht', () {
    // Zwei erfundene Trainingstage.
    final fruehererTag = DateTime.utc(2026, 9, 19, 17, 0);
    final spaetererTag = DateTime.utc(2026, 9, 22, 17, 0);

    test('history gibt die Sätze samt Zeitpunkt weiter', () {
      final verlauf = GymSessionMerge.history([
        _sitzung(
          id: 'eigen-neu',
          date: spaetererTag,
          workout: Workout.a,
          exerciseId: 'benchPress',
          sets: [CompletedSet(weight: 42.5, reps: 7, recordedAt: _t2)],
        ),
        _sitzung(
          id: 'eigen-alt',
          date: fruehererTag,
          workout: Workout.a,
          exerciseId: 'benchPress',
          sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t1)],
        ),
      ]);

      expect(verlauf['benchPress'], [
        [CompletedSet(weight: 42.5, reps: 7, recordedAt: _t2)],
        [CompletedSet(weight: 40, reps: 8, recordedAt: _t1)],
      ]);
    });

    test('merge gibt die Sätze samt Zeitpunkt weiter', () {
      final zusammen = GymSessionMerge.merge(
        logged: [
          _sitzung(
            id: 'eigen-1',
            date: spaetererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 42.5, reps: 7, recordedAt: _t2)],
          ),
        ],
        imported: [
          _sitzung(
            id: 'import-1',
            date: fruehererTag,
            workout: Workout.b,
            exerciseId: 'splitSquat',
            sets: const [CompletedSet(weight: 20, reps: 10)],
          ),
        ],
      );

      expect(zusammen.first.exercises.single.sets.single.recordedAt, _t2);
      expect(zusammen.last.exercises.single.sets.single.recordedAt, isNull);
    });

    test('das eigene Training gewinnt samt seiner Zeitpunkte', () {
      // Derselbe Berliner Tag, dasselbe Workout: Das eigene ist der neuere
      // Stand — und seine Satzzeiten überleben, statt dass die zeitlose
      // übernommene Fassung stehen bleibt.
      final zusammen = GymSessionMerge.merge(
        logged: [
          _sitzung(
            id: 'eigen-1',
            date: spaetererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 42.5, reps: 7, recordedAt: _t2)],
          ),
        ],
        imported: [
          _sitzung(
            id: 'import-1',
            date: spaetererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: const [CompletedSet(weight: 40, reps: 8)],
          ),
        ],
      );

      expect(zusammen, hasLength(1));
      expect(zusammen.single.id, 'eigen-1');
      expect(zusammen.single.exercises.single.sets.single.recordedAt, _t2);
    });

    test('sortiert wird nach dem Sitzungsdatum, nicht nach dem '
        'Satz-Zeitpunkt', () {
      // Die ältere Sitzung trägt bewusst die späteren Satzzeiten. Käme sie
      // dadurch nach vorn, bezöge `Progression.suggest` seinen Vorschlag auf
      // die ältere Last — lautlos falsch.
      final zusammen = GymSessionMerge.merge(
        logged: [
          _sitzung(
            id: 'eigen-alt',
            date: fruehererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t3)],
          ),
          _sitzung(
            id: 'eigen-neu',
            date: spaetererTag,
            workout: Workout.b,
            exerciseId: 'splitSquat',
            sets: [CompletedSet(weight: 20, reps: 10, recordedAt: _t1)],
          ),
        ],
        imported: const [],
      );

      expect(zusammen.map((s) => s.id), ['eigen-neu', 'eigen-alt']);
    });
  });

  group('Der Zeitpunkt beeinflusst keine Rechnung', () {
    // 4 × 6–10 Wiederholungen, Schrittweite 2,5 kg.
    final langhantel = _uebung(
      id: 'pruefLanghantel',
      repLow: 6,
      repHigh: 10,
      increment: 2.5,
    );

    test('Progression.suggest liefert mit und ohne Zeitpunkt dasselbe — '
        'Steigern', () {
      final mit = Progression.suggest(langhantel, [
        [
          CompletedSet(weight: 50, reps: 10, recordedAt: _t1),
          CompletedSet(weight: 50, reps: 10, recordedAt: _t2),
          CompletedSet(weight: 50, reps: 10, recordedAt: _t3),
        ],
      ]);
      final ohne = Progression.suggest(langhantel, const [
        [
          CompletedSet(weight: 50, reps: 10),
          CompletedSet(weight: 50, reps: 10),
          CompletedSet(weight: 50, reps: 10),
        ],
      ]);

      expect(mit, isA<Increase>());
      expect(mit, ohne);
    });

    test('Progression.suggest liefert mit und ohne Zeitpunkt dasselbe — '
        'Halten', () {
      final mit = Progression.suggest(langhantel, [
        [
          CompletedSet(weight: 50, reps: 8, recordedAt: _t1),
          CompletedSet(weight: 50, reps: 7, recordedAt: _t2),
        ],
      ]);
      final ohne = Progression.suggest(langhantel, const [
        [CompletedSet(weight: 50, reps: 8), CompletedSet(weight: 50, reps: 7)],
      ]);

      expect(mit, isA<Hold>());
      expect(mit, ohne);
    });

    test('OneRepMax.best liefert mit und ohne Zeitpunkt dasselbe', () {
      final mit = OneRepMax.best([
        CompletedSet(weight: 50, reps: 10, recordedAt: _t1),
        CompletedSet(weight: 55, reps: 6, recordedAt: _t2),
      ]);
      final ohne = OneRepMax.best(const [
        CompletedSet(weight: 50, reps: 10),
        CompletedSet(weight: 55, reps: 6),
      ]);

      expect(mit, ohne);
      expect(mit, isNotNull);
    });

    test('OneRepMax.isPlateau liefert mit und ohne Zeitpunkt dasselbe', () {
      List<List<CompletedSet>> vier({required bool mitZeit}) => [
        for (var i = 0; i < 4; i++)
          [
            CompletedSet(
              weight: 50,
              reps: 8,
              recordedAt: mitZeit ? _t1.add(Duration(days: i)) : null,
            ),
          ],
      ];

      expect(
        OneRepMax.isPlateau(vier(mitZeit: true)),
        OneRepMax.isPlateau(vier(mitZeit: false)),
      );
      expect(OneRepMax.isPlateau(vier(mitZeit: true)), isTrue);
    });
  });

  group('Sätze ohne Uhrzeit sind der Hauptfall', () {
    // Alles, was über die Übernahme aus der alten App (#59) hereinkommt,
    // trägt `recordedAt == null`. Das ist kein Randfall, den der Kern
    // irgendwie übersteht, sondern der Zustand, in dem der größere Teil von
    // Tims Verlauf dauerhaft bleibt.

    final abschluss = DateTime.utc(2026, 9, 21, 17, 5);
    final fruehererTag = DateTime.utc(2026, 9, 19, 17, 0);
    final spaetererTag = DateTime.utc(2026, 9, 22, 17, 0);

    /// Eine ganze Sitzung, in der kein einziger Satz eine Uhrzeit trägt.
    ImportedSession? uhrzeitlos() => GymSessionBuilder.session(
      id: 'uebernommen-1',
      date: abschluss,
      workout: Workout.a,
      minutes: 58,
      entries: {
        'benchPress': [
          const RawSet(weight: '40', reps: '8'),
          const RawSet(weight: '40', reps: '7'),
        ],
        'lateralRaise': [const RawSet(weight: '10', reps: '12')],
      },
    );

    test('eine Sitzung ohne eine einzige Uhrzeit entsteht vollständig', () {
      final ergebnis = uhrzeitlos();

      expect(ergebnis, isNotNull);
      expect(ergebnis!.setCount, 3);
      expect(ergebnis.exercises.map((e) => e.exerciseId), [
        'benchPress',
        'lateralRaise',
      ]);
      expect(ergebnis.exercises.first.sets, const [
        CompletedSet(weight: 40, reps: 8),
        CompletedSet(weight: 40, reps: 7),
      ]);
    });

    test('der Builder erfindet nirgends einen Zeitstempel', () {
      // Kein Rückfall auf „jetzt" und keiner auf das Sitzungsdatum. Dass
      // jeder Satz `null` trägt, ist der Beweis für beides: Hätte der Kern
      // eines von beidem eingesetzt, stünde hier ein Wert.
      final saetze = [
        for (final uebung in uhrzeitlos()!.exercises) ...uebung.sets,
      ];

      expect(saetze, hasLength(3));
      expect(saetze.map((s) => s.recordedAt), everyElement(isNull));
      // Das Sitzungsdatum selbst bleibt davon unberührt — es ist ein
      // anderer Wert mit einer anderen Bedeutung.
      expect(uhrzeitlos()!.date, abschluss);
    });

    test('eine uhrzeitlose Sitzung übersteht merge unverändert', () {
      final sitzung = uhrzeitlos()!;

      final zusammen = GymSessionMerge.merge(
        logged: [sitzung],
        imported: const [],
      );

      expect(zusammen, [sitzung]);
      expect(
        zusammen.single.exercises
            .expand((e) => e.sets)
            .map((s) => s.recordedAt),
        everyElement(isNull),
      );
    });

    test('eine uhrzeitlose Sitzung übersteht history unverändert', () {
      final sitzung = uhrzeitlos()!;

      final verlauf = GymSessionMerge.history([sitzung]);

      expect(verlauf['benchPress'], [sitzung.exercises.first.sets]);
      expect(verlauf['lateralRaise'], [sitzung.exercises.last.sets]);
      expect(
        verlauf.values
            .expand((s) => s)
            .expand((s) => s)
            .map((s) => s.recordedAt),
        everyElement(isNull),
      );
    });

    test('merge füllt eine fehlende Uhrzeit nicht aus der anderen Fassung', () {
      // Derselbe Tag, dasselbe Workout: Das eigene gewinnt — und zwar
      // ganz, samt seinem fehlenden Zeitpunkt. Die Uhrzeit der
      // übernommenen Fassung herüberzuziehen hieße, einen Zeitpunkt zu
      // behaupten, den dieser Satz nie hatte.
      final zusammen = GymSessionMerge.merge(
        logged: [
          _sitzung(
            id: 'eigen-1',
            date: spaetererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: const [CompletedSet(weight: 40, reps: 8)],
          ),
        ],
        imported: [
          _sitzung(
            id: 'import-1',
            date: spaetererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 40, reps: 8, recordedAt: _t1)],
          ),
        ],
      );

      expect(zusammen, hasLength(1));
      expect(zusammen.single.id, 'eigen-1');
      expect(zusammen.single.exercises.single.sets.single.recordedAt, isNull);
    });

    test('in einer gemischten Übung verrutscht die Zuordnung nicht', () {
      // Die Wiederholungszahlen sind verschieden, damit die Paarung von
      // Satz und Zeitpunkt prüfbar ist und nicht nur die Reihenfolge der
      // Zeitpunkte für sich.
      final ergebnis = GymSessionBuilder.session(
        id: 'gemischt-1',
        date: abschluss,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: '8', recordedAt: _t1),
            const RawSet(weight: '40', reps: '7'),
            RawSet(weight: '40', reps: '6', recordedAt: _t3),
          ],
        },
      );

      expect(ergebnis?.exercises.single.sets, [
        CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
        const CompletedSet(weight: 40, reps: 7),
        CompletedSet(weight: 40, reps: 6, recordedAt: _t3),
      ]);
    });

    test('eine gemischte Übung ist nicht dieselbe wie eine mit vertauschten '
        'Uhrzeiten', () {
      // Gleiche Sätze, gleiche Zeitpunkte, nur anders zugeordnet: Sähe `==`
      // das nicht, bliebe ein verrutschter Zeitpunkt in der Ablage
      // unbemerkt.
      final so = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [
          CompletedSet(weight: 40, reps: 8, recordedAt: _t1),
          const CompletedSet(weight: 40, reps: 7),
        ],
      );
      final vertauscht = ImportedExercise(
        exerciseId: 'benchPress',
        sets: [
          const CompletedSet(weight: 40, reps: 8),
          CompletedSet(weight: 40, reps: 7, recordedAt: _t1),
        ],
      );

      expect(so, isNot(vertauscht));
    });

    test('eine Historie aus uhrzeitlosen Sitzungen sortiert nach dem '
        'Sitzungsdatum', () {
      // Absichtlich älteste zuerst hereingereicht: `history` sortiert
      // selbst. Ohne Uhrzeiten gibt es nichts anderes zu sortieren als das
      // Sitzungsdatum — und genau das muss es auch mit Uhrzeiten bleiben.
      final verlauf = GymSessionMerge.history([
        _sitzung(
          id: 'alt',
          date: fruehererTag,
          workout: Workout.a,
          exerciseId: 'benchPress',
          sets: const [CompletedSet(weight: 40, reps: 8)],
        ),
        _sitzung(
          id: 'neu',
          date: spaetererTag,
          workout: Workout.a,
          exerciseId: 'benchPress',
          sets: const [CompletedSet(weight: 42.5, reps: 7)],
        ),
      ]);

      expect(verlauf['benchPress'], const [
        [CompletedSet(weight: 42.5, reps: 7)],
        [CompletedSet(weight: 40, reps: 8)],
      ]);
    });

    test('merge sortiert uhrzeitlose Sitzungen nach dem Sitzungsdatum', () {
      final zusammen = GymSessionMerge.merge(
        logged: [
          _sitzung(
            id: 'alt',
            date: fruehererTag,
            workout: Workout.a,
            exerciseId: 'benchPress',
            sets: const [CompletedSet(weight: 40, reps: 8)],
          ),
          _sitzung(
            id: 'neu',
            date: spaetererTag,
            workout: Workout.b,
            exerciseId: 'splitSquat',
            sets: const [CompletedSet(weight: 20, reps: 10)],
          ),
        ],
        imported: const [],
      );

      expect(zusammen.map((s) => s.id), ['neu', 'alt']);
    });

    test('die Rechnungen liefern auf einer uhrzeitlosen Historie dasselbe', () {
      // 4 × 6–10 Wiederholungen, Schrittweite 2,5 kg.
      final langhantel = _uebung(
        id: 'pruefLanghantel',
        repLow: 6,
        repHigh: 10,
        increment: 2.5,
      );

      List<List<CompletedSet>> historie({required bool mitZeit}) => [
        for (var i = 0; i < 4; i++)
          [
            CompletedSet(
              weight: 50,
              reps: 8,
              recordedAt: mitZeit ? _t1.add(Duration(days: i)) : null,
            ),
            CompletedSet(
              weight: 50,
              reps: 7,
              recordedAt: mitZeit ? _t2.add(Duration(days: i)) : null,
            ),
          ],
      ];

      expect(
        Progression.suggest(langhantel, historie(mitZeit: false)),
        Progression.suggest(langhantel, historie(mitZeit: true)),
      );
      expect(
        OneRepMax.best(historie(mitZeit: false).first),
        OneRepMax.best(historie(mitZeit: true).first),
      );
      expect(
        OneRepMax.isPlateau(historie(mitZeit: false)),
        OneRepMax.isPlateau(historie(mitZeit: true)),
      );
    });

    test('OneRepMax.epley kennt den Zeitpunkt gar nicht', () {
      // `epley` nimmt Gewicht und Wiederholungen, keinen Satz — es kann
      // also gar nicht an der Uhrzeit hängen. Geprüft wird die Naht
      // darüber: `best` auf einem uhrzeitlosen Satz liefert genau das, was
      // `epley` auf denselben Zahlen liefert.
      expect(
        OneRepMax.best(const [CompletedSet(weight: 50, reps: 10)]),
        OneRepMax.epley(weight: 50, reps: 10),
      );
    });
  });
}
