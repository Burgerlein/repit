// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';

/// Tests für die **Ablage der Gym-Trainings** (#78, mit #418) — der
/// Rundweg, die Eindeutigkeit, die Tagesgrenzen und die drei Abfragen, für
/// die die Tabellen überhaupt existieren.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die Tabellen
/// selbst und ihre Migration prüft `schema_v18_test.dart`; warum die
/// Trainings eigene Tabellen bekommen und nicht `eigene_daten`, steht in
/// Abschnitt 10 der Spec
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`.
///
/// Geschrieben aus dieser Spec (Abschnitt 10.2, 10.4, 11) und Tims
/// Entscheidungen vom 10.11.2026, **ohne** den späteren Code gesehen zu
/// haben.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/data/gym_repository.dart`, derselbe Schnitt wie
/// `WasserRepository` (SQL hier, Riverpod nebenan):
///
/// ```dart
/// /// Eine Satzzeile, so wie sie in der Datenbank steht — die Form, in
/// /// der der Fortschritt (#93) Sätze über die Zeit liest. Werttyp mit
/// /// == und hashCode über alle Felder (Fehler `03`).
/// class GymSatzZeile {
///   const GymSatzZeile({
///     required this.sitzungId,
///     required this.tag,          // ISO-Tagesschlüssel der Sitzung
///     required this.uebungId,
///     required this.uebungPos,
///     required this.satzNr,
///     required this.gewichtKg,
///     required this.wdh,
///     this.zeitpunkt,             // UTC oder null — „nicht erfasst"
///   });
/// }
///
/// class GymRepository {
///   GymRepository(AppCache db);
///
///   /// Legt eine abgeschlossene Sitzung ab.
///   ///
///   /// `tag` wird aus `BerlinCalendar.dayKey(sitzung.date)` gerechnet,
///   /// nicht aus den Feldern des `DateTime`. Eine vorhandene Sitzung
///   /// desselben Tages und desselben Workouts wird **ersetzt**, samt
///   /// ihren Sätzen — „kein Workout" ist dabei ein eigener Schlüssel und
///   /// nicht dasselbe wie Gym A (`GymSessionMerge`).
///   ///
///   /// Wirft `ArgumentError` und schreibt nichts, wenn eine Übung keinen
///   /// Satz trägt, wenn ein Satz keine positive Wiederholungszahl hat
///   /// oder wenn dieselbe Übung zweimal in der Sitzung steht.
///   Future<void> legeAb(ImportedSession sitzung);
///
///   /// Die Sitzung mit dieser Kennung, oder `null`.
///   Future<ImportedSession?> sitzung(String id);
///
///   /// Die Sitzungen eines Zeitraums, **neueste zuerst** — in SQL über
///   /// `tag` gefiltert, beide Grenzen einschließlich. Ohne Grenzen: alle.
///   Future<List<ImportedSession>> sitzungen({String? vonTag,
///       String? bisTag});
///
///   /// Je Workout der Zeitpunkt der jüngsten Sitzung — die Eingabe
///   /// `completed` von `GymDayPlanner.day`. Sitzungen ohne Workout
///   /// tauchen nicht auf.
///   Future<Map<Workout, DateTime>> letzteSitzungJeWorkout();
///
///   /// Alle Sätze eines Zeitraums über alle Sitzungen (Muskelkarte, #96),
///   /// ältester zuerst. In SQL über `tag` gefiltert.
///   Future<List<TrainedSet>> trainierteSaetze({required String vonTag,
///       required String bisTag});
///
///   /// Alle Sätze einer Übung über die Zeit (Fortschritt, #93),
///   /// chronologisch aufsteigend.
///   Future<List<GymSatzZeile>> saetzeDerUebung(String uebungId,
///       {String? vonTag, String? bisTag});
///
///   /// Das Aufwärmen der Sitzungen eines Zeitraums (#40), ältestes
///   /// zuerst — **eine Zeile je Sitzung**, auch wenn nichts eingetragen
///   /// wurde. In SQL über `tag` gefiltert.
///   Future<List<GymAufwaermZeile>> aufwaermenImZeitraum(
///       {required String vonTag, required String bisTag});
/// }
///
/// /// Eine Zeile der Aufwärm-Auswertung. Werttyp mit == und hashCode.
/// class GymAufwaermZeile {
///   const GymAufwaermZeile({
///     required this.sitzungId,
///     required this.tag,
///     required this.zeitpunkt,   // der Zeitpunkt der Sitzung, UTC
///     required this.aufwaermen,  // WarmUp? — null heißt „nichts"
///     this.healthUuid,
///   });
/// }
///
/// final gymRepositoryProvider = Provider<GymRepository>(…);
/// ```
///
/// ## Was der Kern dafür bekommt — und warum es der Kern ist
///
/// #40 schreibt es wörtlich vor: „`ImportedSession` und
/// `GymSessionBuilder` um das Aufwärmen erweitern: Art, Minuten, Strecke,
/// oder ‚übersprungen'. Die Form muss dieselbe bleiben, mit der die
/// Übernahme aus dem Dashboard arbeitet." Dieselbe Abwägung wie bei
/// `CompletedSet.recordedAt` (Spec 11.2): Trüge die Sitzung das Aufwärmen nicht,
/// wäre der Rundweg **per Definition** verlustbehaftet, und die
/// Aufwärm-Einheit hinge an einer Parallelstruktur, die niemand zusammen
/// mit der Sitzung pflegt.
///
/// ```dart
/// /// Die sechs Arten aus #40. `code` ist der abgelegte Wert.
/// enum WarmUpKind {
///   bike('bike'), treadmill('treadmill'), rowing('rowing'),
///   crossTrainer('cross_trainer'), jumpRope('jump_rope'),
///   mobility('mobility');
///   final String code;
///   static WarmUpKind? fromCode(String code);  // null statt raten
/// }
///
/// /// Das Aufwärmen am Anfang eines Trainings.
/// sealed class WarmUp {}
///
/// /// „Übersprungen" — eine Antwort, kein fehlender Wert.
/// final class WarmUpSkipped extends WarmUp { const WarmUpSkipped(); }
///
/// /// Gemacht. [km] ist null, wo es keine Strecke gibt (Mobility).
/// final class WarmUpDone extends WarmUp {
///   const WarmUpDone({required this.kind, required this.minutes,
///       this.km});
/// }
/// ```
///
/// `ImportedSession` bekommt `final WarmUp? warmUp;` — **nullbar, ohne
/// `required`, mit Vorgabe `null`**. `null` heißt „nichts eingetragen",
/// und das ist der Normalfall für alles Übernommene (#59) wie für die
/// fünf bestehenden Kern-Testdateien, die `ImportedSession` bauen: Ein
/// Pflichtfeld machte sie rot, und `.githooks/pre-commit` ließe niemanden
/// sie ändern. `warmUp` geht in `==` und `hashCode` ein.
///
/// **Das ist eine Änderung am Kern, und sie braucht nach `CLAUDE.md` einen
/// eigenen Kern-Test von einem Kern-Test-Agenten** — diese Datei schreibt
/// ihn nicht, sie setzt ihn nur voraus. **Gemeldet, nicht entschieden.**
///
/// Die HealthKit-Kennung des Aufwärm-Workouts steht **nicht** am Kerntyp,
/// sondern nur in der Spalte `aufwaermen_health_uuid` — genau wie
/// `health_uuid` der Sitzung. Sie ist ein Ablageschlüssel und keine
/// Rechnung (`CLAUDE.md`, „Transporttypen gehören nicht in den Kern"), und
/// geschrieben wird sie erst von #414.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. Der Rundweg ist verlustfrei** (Spec 10.4 Punkt 1). Eine
/// `ImportedSession` ablegen und laden ergibt eine `==`-gleiche Sitzung —
/// mit der Reihenfolge der Übungen, der Reihenfolge der Sätze, den
/// negativen Gewichten, den `null`-Feldern und den Satz-Zeitpunkten.
///
/// **2. `null` bleibt `null`** (Punkt 2). Keine fehlende Minutenangabe wird
/// zu `0`, keine fehlende Notiz zur leeren Zeichenkette, kein fehlender
/// Satz-Zeitpunkt zu irgendetwas.
///
/// **3. Trainings ohne Satz-Uhrzeit sind der Hauptfall, nicht der
/// Randfall** (Tim, 10.11.2026). Die Übernahme aus der alten App (#59)
/// bringt Tims ganzen bisherigen Verlauf, und dort gibt es keine
/// Satz-Uhrzeiten; das iPhone ist seine einzige Kopie. Deshalb hat der
/// reine Fall — **keine einzige** Uhrzeit in der ganzen Sitzung — eigene
/// Tests, nicht nur der gemischte.
///
/// **4. Nirgends wird ein Zeitstempel erfunden.** Nicht beim Schreiben,
/// nicht beim Lesen. Kein Rückfall auf „jetzt", keiner auf den
/// Sitzungsbeginn, keine `0`, kein Epoch-Null.
///
/// **5. Die Reihenfolge hängt nicht an der Uhr.** Sie steht in `uebung_pos`
/// und `satz_nr`; eine Sitzung ohne jede Uhrzeit hat dieselbe eindeutige
/// Reihenfolge wie eine mit.
///
/// **6. Ersetzen statt verdoppeln** (Punkt 3) über `(tag, workout)`.
///
/// **7. Tagesgrenzen** (Punkt 4): `tag` kommt aus `BerlinCalendar.dayKey`.
///
/// **8. Gefiltert wird in SQL** (Hausregel 2), über den ISO-Tagesstring.
/// `'2099-09-30' < '2099-10-01'` vergleicht lexikografisch richtig und
/// übersteht die Zeitumstellung.
///
/// **9. Das Aufwärmen (#40) hat drei Zustände, und sie fallen nie
/// zusammen:** nichts eingetragen (`null`), übersprungen
/// (`WarmUpSkipped`), ausgefüllt (`WarmUpDone`). Eine Sitzung **ohne**
/// Aufwärmen bleibt gültig — das ist der Normalfall der Übernahme (#59),
/// derselbe Gedanke wie bei den Satz-Uhrzeiten.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`CompletedSet` trägt den Satz-Zeitpunkt als `recordedAt`** (Spec
///   11.1, Weg A). Das war **offene Frage 6** der Spec und ist am
///   10.11.2026 entschieden: Es ist der Zeitpunkt der **Eingabe**, nicht
///   der des Hebens. `at` sagte nur „irgendwann"; aus dem Feld entsteht
///   später das Übungsband im Verlauf (#79), und ein Name, der die falsche
///   Lesart nahelegt, erzeugt dort irgendwann die falsche Beschriftung
///   („gehoben um" statt „eingetragen um"). Das Feld gehört dem Kern-Test
///   `Packages/trainings_core/test/completed_set_zeitpunkt_test.dart`;
///   diese Datei fasst es nur an einer Stelle an — [satz] im Kopf von
///   `main`.
/// - **Die Zählung von `uebung_pos` und `satz_nr` beginnt bei 1.** Eine
///   Null in `satz_nr` läse sich für jeden, der in die Datei schaut, als
///   „Satz 0".
/// - **`TrainedSet.date` ist der Satz-Zeitpunkt, und wo keiner steht, der
///   Zeitpunkt der Sitzung.** `TrainedSet` verlangt ein Datum, die
///   Muskelkarte braucht nur den Tag, und die Alternative wäre, dass Tims
///   gesamter übernommener Verlauf dort nicht vorkommt. Das ist **kein**
///   erfundener Zeitstempel: In der Ablage bleibt `null` stehen (eigene
///   Tests), ersetzt wird nur in dieser einen Abfrage, und der
///   Sitzungszeitpunkt ist ein erfasster Wert. **Gemeldet, nicht
///   stillschweigend entschieden** — die Spec sagt dazu nichts.
/// - **Eine vorhandene `health_uuid` überlebt das Nachtragen.** Schriebe
///   das Ersetzen sie auf `null`, legte der Lückenfüller (#418 Punkt 3)
///   beim nächsten Start ein zweites `HKWorkout` für denselben Tag an, und
///   das erste bliebe verwaist. Auch das sagt die Spec nicht.
/// - **Eine Übung, die zweimal in derselben Sitzung steht, wird
///   abgelehnt.** Der Primärschlüssel `(sitzung_id, uebung_id, satz_nr)`
///   kann sie nicht tragen; still die zweite zu verlieren wäre Datenverlust
///   ohne Meldung. Dass die Form das nicht kann, ist eine Eigenschaft der
///   Spec, keine Entscheidung dieser Datei — aber **dass es auffällt statt
///   zu verschwinden**, ist eine.
///
/// **Alle Zahlen, Namen, Übungs-IDs und Zeitpunkte sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099. Es stehen keine echten Trainingsdaten
/// darin.
void main() {
  // --- Hilfsmittel -------------------------------------------------------

  /// Die **eine** Stelle, an der der Name des Satz-Zeitpunkts steht.
  CompletedSet satz(double gewichtKg, int wdh, [DateTime? um]) =>
      CompletedSet(weight: gewichtKg, reps: wdh, recordedAt: um);

  ImportedExercise uebung(String id, List<CompletedSet> saetze) =>
      ImportedExercise(exerciseId: id, sets: saetze);

  ({AppCache db, GymRepository repo}) frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return (db: db, repo: GymRepository(db));
  }

  Future<List<Map<String, Object?>>> rohSaetze(AppCache db) async {
    final zeilen = await db
        .customSelect('SELECT * FROM gym_saetze ORDER BY uebung_pos, satz_nr;')
        .get();
    return [for (final z in zeilen) z.data];
  }

  Future<List<Map<String, Object?>>> rohSitzungen(AppCache db) async {
    final zeilen = await db
        .customSelect('SELECT * FROM gym_sitzungen ORDER BY tag;')
        .get();
    return [for (final z in zeilen) z.data];
  }

  // --- Erfundene Trainings ----------------------------------------------

  /// Ein vollständiges Training: drei Übungen, gemischte Satz-Zeitpunkte,
  /// ein unterstützter Satz, ein Satz am eigenen Körpergewicht, dazu ein
  /// eingetragenes Aufwärmen.
  ImportedSession volles({
    String id = 'pruef-1',
    DateTime? datum,
    Workout? workout = Workout.a,
    int? minuten = 68,
    String? notiz = 'Prüfnotiz',
    WarmUp? aufwaermen = const WarmUpDone(
      kind: WarmUpKind.bike,
      minutes: 10,
      km: 3.4,
    ),
  }) => ImportedSession(
    id: id,
    date: datum ?? DateTime.utc(2099, 3, 2, 17, 30, 15, 123),
    workout: workout,
    minutes: minuten,
    note: notiz,
    warmUp: aufwaermen,
    exercises: [
      uebung('pruef-bank', [
        satz(62.5, 10, DateTime.utc(2099, 3, 2, 16, 41)),
        satz(62.5, 9, DateTime.utc(2099, 3, 2, 16, 45, 30)),
        satz(60.0, 8, DateTime.utc(2099, 3, 2, 16, 50)),
      ]),
      uebung('pruef-dip', [
        satz(0.0, 12, DateTime.utc(2099, 3, 2, 17, 0)),
        satz(-27.0, 8, DateTime.utc(2099, 3, 2, 17, 5)),
      ]),
      uebung('pruef-seitstuetz', [satz(0.0, 35)]),
    ],
  );

  /// Dasselbe Training, wie es aus der Übernahme (#59) käme: **keine
  /// einzige** Satz-Uhrzeit, kein Workout, keine Minuten, keine Notiz.
  ImportedSession uebernommenes({
    String id = 'pruef-alt',
    DateTime? datum,
    Workout? workout,
  }) => ImportedSession(
    id: id,
    // 18:00 UTC ist im Januar in Berlin 19:00 am **selben** Tag. Vorher
    // stand hier 23:00 UTC — das ist im Januar (UTC+1) schon 00:00 des
    // Folgetags, und `BerlinCalendar.dayKey` lieferte deshalb zu Recht
    // `2099-01-10`, während die Erwartungen `2099-01-09` sagten. Derselbe
    // Zahlendreher wie seinerzeit in den `DataWindow`-Tests; gemeldet hat
    // ihn der Implementierende, korrigiert wurde er hier
    // (10.11.2026, TEST_AENDERN=1).
    date: datum ?? DateTime.utc(2099, 1, 9, 18, 0),
    workout: workout,
    minutes: null,
    note: null,
    exercises: [
      uebung('pruef-bank', [satz(55.0, 10), satz(55.0, 8)]),
      uebung('pruef-rudern', [satz(40.0, 12), satz(42.5, 10), satz(42.5, 9)]),
    ],
  );

  // ═════════════════════════════════════════════════════════════════════

  group('Der Rundweg', () {
    test('eine leere Ablage kennt keine Sitzung', () async {
      final h = frisch();
      expect(await h.repo.sitzung('pruef-1'), isNull);
      expect(await h.repo.sitzungen(), isEmpty);
    });

    test('eine vollständige Sitzung kommt gleich zurück', () async {
      final h = frisch();
      final sitzung = volles();
      await h.repo.legeAb(sitzung);

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(
        gelesen,
        sitzung,
        reason:
            'die erste Anforderung an die Ablage (Spec 10.4): verlustfrei '
            'hin und zurück, einschließlich der Reihenfolgen',
      );
    });

    test('die Reihenfolge der Übungen bleibt, auch gegen die '
        'Katalogreihenfolge', () async {
      final h = frisch();
      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-1',
          date: DateTime.utc(2099, 3, 2, 17, 30),
          workout: Workout.a,
          minutes: 60,
          note: null,
          exercises: [
            uebung('pruef-zzz', [satz(10, 10)]),
            uebung('pruef-aaa', [satz(20, 10)]),
            uebung('pruef-mmm', [satz(30, 10)]),
          ],
        ),
      );

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(
        gelesen!.exercises.map((e) => e.exerciseId).toList(),
        ['pruef-zzz', 'pruef-aaa', 'pruef-mmm'],
        reason:
            'die Reihenfolge gehört zur Sitzung und wird nicht beim Laden '
            'neu gerechnet — sonst änderte eine Umsortierung des Katalogs '
            'rückwirkend, wie Tim vor einem Jahr trainiert hat (Spec 10.2)',
      );
    });

    test('die Reihenfolge der Sätze bleibt', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.exercises.first.sets.map((s) => s.reps).toList(), [
        10,
        9,
        8,
      ], reason: 'erst 10 und dann 8 ist ein anderer Verlauf als umgekehrt');
    });

    test('ein Workout von `null` bleibt `null`', () async {
      final h = frisch();
      await h.repo.legeAb(volles(workout: null));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(
        gelesen!.workout,
        isNull,
        reason:
            '„kein Workout" ist ein eigener Fall und nicht dasselbe wie '
            'Gym A — einem Workout zuzuschlagen hieße raten',
      );
    });

    test('fehlende Minuten bleiben `null` und werden nicht `0`', () async {
      final h = frisch();
      await h.repo.legeAb(volles(minuten: null));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.minutes, isNull);
      expect(
        gelesen.minutes,
        isNot(0),
        reason: '„nicht erfasst" ist nicht „null Minuten" (Fehler `01`)',
      );
    });

    test('eine fehlende Notiz bleibt `null` und wird nicht zur leeren '
        'Zeichenkette', () async {
      final h = frisch();
      await h.repo.legeAb(volles(notiz: null));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.note, isNull);
      expect(
        gelesen.note,
        isNot(''),
        reason: 'eine leere Notiz zeichnete eine leere Notizzeile',
      );
    });

    test('negatives Gewicht bleibt negativ', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      final gelesen = await h.repo.sitzung('pruef-1');
      final dip = gelesen!.exercises[1];
      expect(
        dip.sets[1].weight,
        -27.0,
        reason:
            '−27 sind 27 kg Hilfe der Maschine. Ein Betrag beim Ablegen '
            'machte aus Unterstützung Zusatzgewicht',
      );
    });

    test('ein Satz ohne Gewicht ist gültig — der Dip am eigenen '
        'Körpergewicht', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.exercises[1].sets.first.weight, 0.0);
      expect(gelesen.exercises[1].sets.first.reps, 12);
    });

    test('ein Satz ohne Wiederholungen wird abgelehnt, und es bleibt '
        'nichts zurück', () async {
      final h = frisch();
      final kaputt = ImportedSession(
        id: 'pruef-kaputt',
        date: DateTime.utc(2099, 3, 2, 17, 30),
        workout: Workout.a,
        minutes: 60,
        note: null,
        exercises: [
          uebung('pruef-bank', [satz(62.5, 10), satz(62.5, 0)]),
        ],
      );

      await expectLater(() => h.repo.legeAb(kaputt), throwsArgumentError);
      expect(await rohSitzungen(h.db), isEmpty);
      expect(
        await rohSaetze(h.db),
        isEmpty,
        reason: 'abgelehnt heißt: gar nichts geschrieben, kein halber Stand',
      );
    });

    test('eine Übung ohne Satz wird abgelehnt statt still verloren zu '
        'gehen', () async {
      final h = frisch();
      final leer = ImportedSession(
        id: 'pruef-leer',
        date: DateTime.utc(2099, 3, 2, 17, 30),
        workout: Workout.a,
        minutes: 60,
        note: null,
        exercises: [
          uebung('pruef-bank', [satz(62.5, 10)]),
          uebung('pruef-ohne', const []),
        ],
      );

      await expectLater(() => h.repo.legeAb(leer), throwsArgumentError);
      expect(
        await rohSitzungen(h.db),
        isEmpty,
        reason:
            'die Form kennt keine Übung ohne Satz (Spec 10.2). Sie beim '
            'Ablegen wegzulassen hieße, dass der Rundweg verlustbehaftet '
            'ist, und niemand erführe es',
      );
    });

    test('dieselbe Übung zweimal in einer Sitzung wird abgelehnt', () async {
      final h = frisch();
      final doppelt = ImportedSession(
        id: 'pruef-doppelt',
        date: DateTime.utc(2099, 3, 2, 17, 30),
        workout: Workout.a,
        minutes: 60,
        note: null,
        exercises: [
          uebung('pruef-bank', [satz(62.5, 10)]),
          uebung('pruef-bank', [satz(60.0, 8)]),
        ],
      );

      await expectLater(() => h.repo.legeAb(doppelt), throwsArgumentError);
      expect(
        await rohSitzungen(h.db),
        isEmpty,
        reason:
            'der Primärschlüssel (sitzung_id, uebung_id, satz_nr) kann das '
            'nicht tragen — still die zweite zu überschreiben wäre '
            'Datenverlust ohne Meldung',
      );
    });

    test('die Uhrzeit der Sitzung bleibt erhalten, sie wird nicht auf den '
        'Tagesbeginn gerundet', () async {
      final h = frisch();
      final zeitpunkt = DateTime.utc(2099, 3, 2, 17, 30, 15, 123);
      await h.repo.legeAb(volles(datum: zeitpunkt));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.date, zeitpunkt);
      expect(
        gelesen.date.isUtc,
        isTrue,
        reason:
            'storeDateTimeAsText: als Ortszeit käme der Wert ungleich sich '
            'selbst zurück, und jeder abgeleitete Provider rechnete neu',
      );
    });
  });

  group('Trainings ohne Satz-Uhrzeit — der Hauptfall der Übernahme', () {
    test('eine Sitzung, in der kein einziger Satz eine Uhrzeit trägt, '
        'kommt gleich zurück', () async {
      final h = frisch();
      final alt = uebernommenes();
      await h.repo.legeAb(alt);

      final gelesen = await h.repo.sitzung('pruef-alt');
      expect(
        gelesen,
        alt,
        reason:
            'das ist der Normalfall für Tims gesamten bisherigen Verlauf '
            '(#59), nicht ein Randfall',
      );
      for (final u in gelesen!.exercises) {
        for (final s in u.sets) {
          expect(
            s.recordedAt,
            isNull,
            reason: '${u.exerciseId}: nichts erfunden',
          );
        }
      }
    });

    test('in der Datei steht dort NULL, kein Ersatzwert', () async {
      final h = frisch();
      await h.repo.legeAb(uebernommenes());

      final zeilen = await rohSaetze(h.db);
      expect(zeilen, hasLength(5));
      for (final z in zeilen) {
        expect(
          z['zeitpunkt'],
          isNull,
          reason:
              'kein „jetzt", kein Sitzungsbeginn, keine 0, kein Epoch-Null '
              '(Tim, 10.11.2026)',
        );
      }
    });

    test(
      'gemischt: ein Satz ohne Uhrzeit bekommt nicht die des nächsten',
      () async {
        final h = frisch();
        final erste = DateTime.utc(2099, 3, 2, 16, 41);
        final dritte = DateTime.utc(2099, 3, 2, 16, 50);
        await h.repo.legeAb(
          ImportedSession(
            id: 'pruef-gemischt',
            date: DateTime.utc(2099, 3, 2, 17, 30),
            workout: Workout.a,
            minutes: 60,
            note: null,
            exercises: [
              uebung('pruef-bank', [
                satz(62.5, 10, erste),
                satz(62.5, 9),
                satz(60.0, 8, dritte),
              ]),
            ],
          ),
        );

        final saetze = (await h.repo.sitzung('pruef-gemischt'))!
            .exercises
            .single
            .sets;
        expect(saetze[0].recordedAt, erste);
        expect(
          saetze[1].recordedAt,
          isNull,
          reason: 'Satz 2 hat keine Uhrzeit und bekommt auch keine geliehene',
        );
        expect(
          saetze[2].recordedAt,
          dritte,
          reason: 'und die Zuordnung verrutscht dabei nicht',
        );
        expect(saetze.map((s) => s.reps).toList(), [10, 9, 8]);
      },
    );

    test('die Reihenfolge wird nicht aus der Uhrzeit abgeleitet', () async {
      final h = frisch();
      // Absichtlich gegenläufig: Satz 1 ist der späteste, Satz 3 der
      // früheste. Wer nach der Uhr sortiert, dreht die Sätze um.
      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-gegenlaeufig',
          date: DateTime.utc(2099, 3, 2, 17, 30),
          workout: Workout.a,
          minutes: 60,
          note: null,
          exercises: [
            uebung('pruef-bank', [
              satz(62.5, 10, DateTime.utc(2099, 3, 2, 16, 59)),
              satz(60.0, 9, DateTime.utc(2099, 3, 2, 16, 50)),
              satz(57.5, 8, DateTime.utc(2099, 3, 2, 16, 41)),
            ]),
          ],
        ),
      );

      final saetze = (await h.repo.sitzung('pruef-gegenlaeufig'))!
          .exercises
          .single
          .sets;
      expect(
        saetze.map((s) => s.reps).toList(),
        [10, 9, 8],
        reason:
            'sortiert wird über satz_nr. Käme die Reihenfolge aus der Uhr, '
            'hätte eine Sitzung ohne Uhrzeiten gar keine',
      );
    });

    test('`uebung_pos` und `satz_nr` zählen ab 1 und sind auch ohne jede '
        'Uhrzeit eindeutig', () async {
      final h = frisch();
      await h.repo.legeAb(uebernommenes());

      final zeilen = await rohSaetze(h.db);
      expect(
        zeilen.map((z) => (z['uebung_pos'], z['satz_nr'])).toList(),
        [(1, 1), (1, 2), (2, 1), (2, 2), (2, 3)],
        reason:
            'die Reihenfolge steht in Zahlen, nicht in Zeitstempeln — und '
            'sie beginnt bei 1, damit „Satz 1" in der Datei auch Satz 1 ist',
      );
    });
  });

  group('Tagesgrenzen und Filtern in SQL', () {
    // 2099: Die Sommerzeit endet am letzten Sonntag im Oktober, dem 25.,
    // um 01:00 UTC. Davor liegt Berlin zwei Stunden vor UTC, danach eine.
    final kurzNachMitternacht = DateTime.utc(2099, 10, 24, 22, 30);
    final spaetAmAbend = DateTime.utc(2099, 10, 25, 22, 30);
    final naechsterTag = DateTime.utc(2099, 10, 25, 23, 30);

    test('die Vorbedingung stimmt: drei Zeitpunkte, zwei Berliner Tage, '
        'drei UTC-Tage', () {
      expect(BerlinCalendar.dayKey(kurzNachMitternacht), '2099-10-25');
      expect(BerlinCalendar.dayKey(spaetAmAbend), '2099-10-25');
      expect(BerlinCalendar.dayKey(naechsterTag), '2099-10-26');
      expect(
        {kurzNachMitternacht.day, spaetAmAbend.day, naechsterTag.day},
        {24, 25},
        reason:
            'nach UTC gerechnet wären es der 24. und der 25. — genau der '
            'Zahlendreher, den die Rollentrennung bei DataWindow gefangen '
            'hat',
      );
    });

    test('`tag` kommt aus BerlinCalendar.dayKey, nicht aus dem '
        'UTC-Kalendertag', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-nacht', datum: kurzNachMitternacht),
      );

      final zeile = (await rohSitzungen(h.db)).single;
      expect(
        zeile['tag'],
        '2099-10-25',
        reason:
            'der UTC-Kalendertag ist der 24., der Berliner der 25. — '
            'gefiltert wird über den Berliner (Spec 10.4 Punkt 4)',
      );
    });

    test('zwei Sitzungen desselben Berliner Tages tragen denselben `tag`, '
        'obwohl sie auf verschiedenen UTC-Tagen liegen', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(
          id: 'pruef-frueh',
          datum: kurzNachMitternacht,
          workout: Workout.a,
        ),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-spaet', datum: spaetAmAbend, workout: Workout.c),
      );

      final tage = (await rohSitzungen(h.db)).map((z) => z['tag']).toSet();
      expect(tage, {'2099-10-25'});
    });

    test('ein Filter über die Sommerzeitgrenze nimmt beide mit und den '
        'Folgetag nicht', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(
          id: 'pruef-frueh',
          datum: kurzNachMitternacht,
          workout: Workout.a,
        ),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-spaet', datum: spaetAmAbend, workout: Workout.c),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-danach', datum: naechsterTag, workout: Workout.push),
      );

      final amTag = await h.repo.sitzungen(
        vonTag: '2099-10-25',
        bisTag: '2099-10-25',
      );
      expect(amTag.map((s) => s.id).toSet(), {
        'pruef-frueh',
        'pruef-spaet',
      }, reason: 'beide Grenzen einschließlich');
    });

    test('der Tagesstring vergleicht lexikografisch über den '
        'Monatswechsel', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-sep', datum: DateTime.utc(2099, 9, 30, 12)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-okt-1', datum: DateTime.utc(2099, 10, 1, 12)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-okt-9', datum: DateTime.utc(2099, 10, 9, 12)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-okt-10', datum: DateTime.utc(2099, 10, 10, 12)),
      );

      final oktober = await h.repo.sitzungen(vonTag: '2099-10-01');
      expect(
        oktober.map((s) => s.id).toSet(),
        {'pruef-okt-1', 'pruef-okt-9', 'pruef-okt-10'},
        reason:
            "'2099-09-30' < '2099-10-01' — ein Tag ist eine Kalenderangabe, "
            'kein Zeitpunkt (CLAUDE.md)',
      );
    });

    test('die Sitzungen kommen neueste zuerst', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-alt', datum: DateTime.utc(2099, 10, 1, 12)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-neu', datum: DateTime.utc(2099, 10, 10, 12)),
      );

      expect((await h.repo.sitzungen()).map((s) => s.id).toList(), [
        'pruef-neu',
        'pruef-alt',
      ]);
    });
  });

  group('Ersetzen statt verdoppeln', () {
    test('zweimal dasselbe Workout am selben Tag ist ein Nachtragen: die '
        'zweite Sitzung ersetzt die erste', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-erst'));
      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-zweit',
          date: DateTime.utc(2099, 3, 2, 19, 0),
          workout: Workout.a,
          minutes: 71,
          note: 'nachgetragen',
          exercises: [
            uebung('pruef-bank', [satz(65.0, 10)]),
          ],
        ),
      );

      final alle = await h.repo.sitzungen();
      expect(alle, hasLength(1), reason: 'nicht verdoppelt (Spec 10.4)');
      expect(alle.single.id, 'pruef-zweit');
      expect(alle.single.minutes, 71);
      expect(await h.repo.sitzung('pruef-erst'), isNull);
    });

    test('die Sätze der ersetzten Sitzung bleiben nicht als Waisen '
        'liegen', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-erst'));
      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-zweit',
          date: DateTime.utc(2099, 3, 2, 19, 0),
          workout: Workout.a,
          minutes: 71,
          note: null,
          exercises: [
            uebung('pruef-bank', [satz(65.0, 10)]),
          ],
        ),
      );

      final zeilen = await rohSaetze(h.db);
      expect(zeilen, hasLength(1));
      expect(zeilen.single['sitzung_id'], 'pruef-zweit');
    });

    test('verschiedene Workouts am selben Tag stehen nebeneinander', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-a', workout: Workout.a));
      await h.repo.legeAb(volles(id: 'pruef-c', workout: Workout.c));

      expect(await h.repo.sitzungen(), hasLength(2));
    });

    test(
      'dasselbe Workout an verschiedenen Tagen steht nebeneinander',
      () async {
        final h = frisch();
        await h.repo.legeAb(
          volles(id: 'pruef-mo', datum: DateTime.utc(2099, 3, 2, 17)),
        );
        await h.repo.legeAb(
          volles(id: 'pruef-do', datum: DateTime.utc(2099, 3, 5, 17)),
        );

        expect(await h.repo.sitzungen(), hasLength(2));
      },
    );

    // ACHTUNG, wer hier später etwas ändert: **Der Constraint
    // `UNIQUE (tag, workout)` trägt diesen Fall nicht.** SQLite hält zwei
    // NULL für verschieden und ließe zwei workout-lose Sitzungen desselben
    // Tages nebeneinander stehen; `GymSessionMerge` führt „kein Workout"
    // dagegen als **einen** Schlüssel (`'?'`). Die Spec behauptet in 10.2,
    // der Index sei „derselbe Schlüssel" — das stimmt nicht.
    //
    // Entschieden am 10.11.2026: **Die Ablage vergleicht beim Nachtragen
    // mit `IS`**; der Constraint bleibt als zusätzliche Sicherung für den
    // Nicht-NULL-Fall stehen. In der Spalte steht weiter `NULL` und nicht
    // `'?'` — `NULL` ist die ehrliche Angabe „das Dashboard führt hier kein
    // Workout", ein Platzhalterwert wäre eine stille Verfälschung. Ein
    // Ausdrucksindex über `COALESCE(workout, '?')` scheidet aus, weil
    // `_reconcileSchema` keine Indizes kennt.
    //
    // Wer den Constraint für ausreichend hält und diesen Test fallen lässt,
    // bekommt ein nachgetragenes Dashboard-Training zweimal in den Verlauf.
    test(
      'zwei Sitzungen desselben Tages **ohne** Workout sind dieselbe',
      () async {
        final h = frisch();
        await h.repo.legeAb(volles(id: 'pruef-erst', workout: null));
        await h.repo.legeAb(volles(id: 'pruef-zweit', workout: null));

        final alle = await h.repo.sitzungen();
        expect(
          alle,
          hasLength(1),
          reason:
              'GymSessionMerge führt „kein Workout" als eigenen Schlüssel '
              "('?'), nicht als Abwesenheit. Ein UNIQUE (tag, workout) allein "
              'trägt das nicht: SQLite hält zwei NULL für verschieden — die '
              'Ablage muss hier `IS` vergleichen',
        );
        expect(alle.single.id, 'pruef-zweit');
      },
    );

    test(
      'die Datenbank selbst weist den zweiten Eintrag mit Workout ab',
      () async {
        final h = frisch();
        await h.repo.legeAb(volles(id: 'pruef-erst'));

        await expectLater(
          h.db.customInsert(
            'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
            "VALUES ('pruef-von-hand', '2099-03-02', "
            "'2099-03-02T17:30:00.000Z', 'A');",
          ),
          throwsA(anything),
          reason:
              '„wird ersetzt, nicht verdoppelt" ist eine Eigenschaft der '
              'Datenbank und nicht nur eine Regel im Kopf (Spec 10.2)',
        );
      },
    );

    test('eine vorhandene health_uuid überlebt das Nachtragen', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-erst'));
      await h.db.customUpdate(
        "UPDATE gym_sitzungen SET health_uuid = 'PRUEF-HK-0001';",
      );

      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-zweit',
          date: DateTime.utc(2099, 3, 2, 19, 0),
          workout: Workout.a,
          minutes: 71,
          note: null,
          exercises: [
            uebung('pruef-bank', [satz(65.0, 10)]),
          ],
        ),
      );

      expect(
        (await rohSitzungen(h.db)).single['health_uuid'],
        'PRUEF-HK-0001',
        reason:
            'ginge sie verloren, legte der Lückenfüller beim nächsten Start '
            'ein zweites HKWorkout für denselben Tag an, und das erste '
            'bliebe verwaist (#418 Punkt 2 und 3)',
      );
    });

    test('eine frisch abgelegte Sitzung hat keine health_uuid', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      expect(
        (await rohSitzungen(h.db)).single['health_uuid'],
        isNull,
        reason:
            'die Spalte entsteht jetzt, der Lückenfüller schreibt sie '
            'später — eine erfundene Kennung wäre schlimmer als keine',
      );
    });
  });

  group('Abfrage 1: die Sätze eines Zeitraums (Muskelkarte, #96)', () {
    test('ein leerer Zeitraum ist eine leere Liste', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      expect(
        await h.repo.trainierteSaetze(
          vonTag: '2099-04-01',
          bisTag: '2099-04-30',
        ),
        isEmpty,
      );
    });

    test('alle Sätze aller Sitzungen des Zeitraums, Grenzen '
        'einschließlich', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-1', datum: DateTime.utc(2099, 3, 2, 17)),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-2',
          datum: DateTime.utc(2099, 3, 5, 17),
          workout: Workout.c,
        ),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-3',
          datum: DateTime.utc(2099, 3, 9, 17),
          workout: Workout.push,
        ),
      );

      final saetze = await h.repo.trainierteSaetze(
        vonTag: '2099-03-02',
        bisTag: '2099-03-05',
      );
      expect(
        saetze,
        hasLength(12),
        reason: 'sechs Sätze je Sitzung, zwei Sitzungen im Zeitraum',
      );
      expect(saetze.map((s) => s.exerciseId).toSet(), {
        'pruef-bank',
        'pruef-dip',
        'pruef-seitstuetz',
      });
    });

    // **Das ist kein Widerspruch zu „nirgends wird ein Zeitstempel
    // erfunden", und wer es dafür hält, liest zwei Dinge als eines.**
    //
    // In der **Ablage** bleibt `recordedAt` `null` — geschrieben wird
    // nichts, gelesen wird `null` zurück, und `gym_ablage_test.dart` hält
    // das an drei Stellen fest (Gruppe „Trainings ohne Satz-Uhrzeit").
    //
    // Hier geht es um etwas anderes: `TrainedSet` **verlangt** ein Datum,
    // weil die Muskelkarte Sätze auf Tage verteilt. Für diese eine
    // Rechnung tritt ersatzweise der Zeitpunkt der **Sitzung** ein — ein
    // erfasster Wert, kein ausgedachter, und er bezeichnet denselben Tag.
    // Die Alternative wäre, die Sätze ohne Uhrzeit wegzulassen, und dann
    // fehlte Tims gesamter übernommener Verlauf (#59) in der Muskelkarte.
    //
    // Bestätigt am 10.11.2026. Erfunden würde ein Zeitstempel erst, wenn
    // er **in die Datei** geschrieben würde — und genau das passiert nicht.
    test(
      'eine Sitzung aus lauter uhrzeitlosen Sätzen fällt nicht heraus',
      () async {
        final h = frisch();
        await h.repo.legeAb(
          uebernommenes(id: 'pruef-alt', datum: DateTime.utc(2099, 3, 3, 17)),
        );

        final saetze = await h.repo.trainierteSaetze(
          vonTag: '2099-03-01',
          bisTag: '2099-03-31',
        );
        expect(
          saetze,
          hasLength(5),
          reason:
              'genau hier macht ein naives Filtern oder Sortieren über die '
              'Satzzeit Tims übernommenen Verlauf unsichtbar (Tim, '
              '10.11.2026)',
        );
        for (final s in saetze) {
          expect(
            s.date,
            DateTime.utc(2099, 3, 3, 17),
            reason:
                'ohne Satzzeit gilt der Zeitpunkt der Sitzung — ein erfasster '
                'Wert, kein erfundener',
          );
        }

        // Und in derselben Prüfung der Gegenbeweis: In der Datei steht
        // weiterhin NULL. Der Ersatz lebt in der Abfrage, nicht in der
        // Ablage.
        for (final z in await rohSaetze(h.db)) {
          expect(
            z['zeitpunkt'],
            isNull,
            reason:
                'die Abfrage setzt den Sitzungszeitpunkt ein, sie schreibt '
                'ihn nicht zurück',
          );
        }
      },
    );

    test('mit Satzzeit gilt die Satzzeit', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      final saetze = await h.repo.trainierteSaetze(
        vonTag: '2099-03-02',
        bisTag: '2099-03-02',
      );
      final bank = [
        for (final s in saetze)
          if (s.exerciseId == 'pruef-bank') s.date,
      ];
      expect(bank, [
        DateTime.utc(2099, 3, 2, 16, 41),
        DateTime.utc(2099, 3, 2, 16, 45, 30),
        DateTime.utc(2099, 3, 2, 16, 50),
      ]);
    });

    test('eine uhrzeitlose Sitzung sortiert nicht ans falsche Ende', () async {
      final h = frisch();
      await h.repo.legeAb(
        uebernommenes(id: 'pruef-alt', datum: DateTime.utc(2099, 3, 1, 17)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-neu', datum: DateTime.utc(2099, 3, 2, 17, 30)),
      );

      final saetze = await h.repo.trainierteSaetze(
        vonTag: '2099-03-01',
        bisTag: '2099-03-31',
      );
      expect(
        saetze.first.date,
        DateTime.utc(2099, 3, 1, 17),
        reason: 'ältester zuerst — die uhrzeitlose Sitzung steht vorn',
      );
      expect(
        saetze.map((s) => s.date).toList(),
        orderedEquals(
          ([...saetze.map((s) => s.date)]..sort((a, b) => a.compareTo(b))),
        ),
        reason: 'und die ganze Liste ist aufsteigend',
      );
    });
  });

  group('Abfrage 2: die jüngste Sitzung je Workout (Fokus-Karte)', () {
    test('eine leere Ablage ergibt eine leere Zuordnung', () async {
      final h = frisch();
      expect(await h.repo.letzteSitzungJeWorkout(), isEmpty);
    });

    test('je Workout der Zeitpunkt des letzten Abschlusses', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-a1', datum: DateTime.utc(2099, 3, 2, 17)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-a2', datum: DateTime.utc(2099, 3, 9, 18, 15)),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-c1',
          datum: DateTime.utc(2099, 3, 5, 17),
          workout: Workout.c,
        ),
      );

      expect(await h.repo.letzteSitzungJeWorkout(), {
        Workout.a: DateTime.utc(2099, 3, 9, 18, 15),
        Workout.c: DateTime.utc(2099, 3, 5, 17),
      });
    });

    test('Sitzungen ohne Workout tauchen nicht auf', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-ohne', workout: null));

      expect(
        await h.repo.letzteSitzungJeWorkout(),
        isEmpty,
        reason:
            'einem Workout zuzuschlagen hieße raten — und GymDayPlanner '
            'bekäme einen Abschluss, den es nicht gab',
      );
    });

    test('eine Sitzung aus lauter uhrzeitlosen Sätzen zählt mit', () async {
      final h = frisch();
      await h.repo.legeAb(
        uebernommenes(
          id: 'pruef-alt',
          datum: DateTime.utc(2099, 1, 9, 23),
          workout: Workout.b,
        ),
      );

      expect(await h.repo.letzteSitzungJeWorkout(), {
        Workout.b: DateTime.utc(2099, 1, 9, 23),
      });
    });

    test('ein unbekannter Workout-Code in der Datei wird übergangen statt '
        'geraten', () async {
      final h = frisch();
      await h.db.customInsert(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
        "VALUES ('pruef-fremd', '2099-03-02', "
        "'2099-03-02T17:30:00.000Z', 'Z');",
      );

      expect(
        await h.repo.letzteSitzungJeWorkout(),
        isEmpty,
        reason:
            'Workout.fromCode gibt null zurück, und eine stillschweigende '
            'Zuordnung schriebe ein fremdes Workout in die Fokus-Karte',
      );
    });
  });

  group('Abfrage 3: alle Sätze einer Übung über die Zeit (#93)', () {
    test('eine unbekannte Übung ergibt eine leere Liste', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      expect(await h.repo.saetzeDerUebung('pruef-gibt-es-nicht'), isEmpty);
    });

    test('nur die Sätze dieser Übung, chronologisch aufsteigend', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-1', datum: DateTime.utc(2099, 3, 2, 17)),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-2',
          datum: DateTime.utc(2099, 3, 9, 17),
          workout: Workout.c,
        ),
      );

      final saetze = await h.repo.saetzeDerUebung('pruef-dip');
      expect(saetze, hasLength(4));
      expect(saetze.map((s) => s.uebungId).toSet(), {'pruef-dip'});
      expect(saetze.map((s) => s.tag).toList(), [
        '2099-03-02',
        '2099-03-02',
        '2099-03-09',
        '2099-03-09',
      ]);
      expect(saetze.map((s) => s.satzNr).toList(), [
        1,
        2,
        1,
        2,
      ], reason: 'innerhalb einer Sitzung in der Reihenfolge der Satznummern');
      expect(saetze.first.gewichtKg, 0.0);
      expect(saetze[1].gewichtKg, -27.0);
    });

    test('Sätze ohne Uhrzeit kommen mit und tragen `null`', () async {
      final h = frisch();
      await h.repo.legeAb(
        // 18:00 statt 23:00 UTC: Im Januar ist Berlin UTC+1, 23:00 UTC ist
        // dort schon 00:00 des Folgetags, und der Tagesschlüssel lautete
        // dann `2099-01-10`. Korrigiert am 10.11.2026 mit TEST_AENDERN=1
        // — die Anforderung (die ältere Sitzung steht vorn) ist dieselbe.
        uebernommenes(id: 'pruef-alt', datum: DateTime.utc(2099, 1, 9, 18)),
      );
      await h.repo.legeAb(
        volles(id: 'pruef-neu', datum: DateTime.utc(2099, 3, 2, 17)),
      );

      final saetze = await h.repo.saetzeDerUebung('pruef-bank');
      expect(
        saetze,
        hasLength(5),
        reason: 'zwei aus der Übernahme, drei aus dem eigenen Training',
      );
      expect(
        saetze.map((s) => s.tag).toList(),
        ['2099-01-09', '2099-01-09', '2099-03-02', '2099-03-02', '2099-03-02'],
        reason:
            'die übernommene Sitzung steht vorn und nicht hinten — sortiert '
            'wird über den Tag der Sitzung, nicht über die Satzzeit',
      );
      expect(saetze[0].zeitpunkt, isNull);
      expect(saetze[1].zeitpunkt, isNull);
      expect(saetze[2].zeitpunkt, DateTime.utc(2099, 3, 2, 16, 41));
    });

    test('der Zeitraum lässt sich eingrenzen', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(id: 'pruef-1', datum: DateTime.utc(2099, 3, 2, 17)),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-2',
          datum: DateTime.utc(2099, 3, 9, 17),
          workout: Workout.c,
        ),
      );

      final saetze = await h.repo.saetzeDerUebung(
        'pruef-bank',
        vonTag: '2099-03-05',
      );
      expect(saetze, hasLength(3));
      expect(saetze.map((s) => s.tag).toSet(), {'2099-03-09'});
    });

    test(
      'die Satzzeile nennt ihre Sitzung und die Position der Übung',
      () async {
        final h = frisch();
        await h.repo.legeAb(volles());

        final saetze = await h.repo.saetzeDerUebung('pruef-seitstuetz');
        expect(saetze, hasLength(1));
        expect(saetze.single.sitzungId, 'pruef-1');
        expect(saetze.single.uebungPos, 3);
        expect(saetze.single.satzNr, 1);
        expect(
          saetze.single.wdh,
          35,
          reason: 'bei einer Zeitübung trägt dasselbe Feld Sekunden',
        );
      },
    );
  });

  group('Das Aufwärmen am Trainingsanfang (#40)', () {
    test('ein ausgefülltes Aufwärmen kommt gleich zurück', () async {
      final h = frisch();
      const warm = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);
      await h.repo.legeAb(volles(aufwaermen: warm));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.warmUp, warm);
    });

    test('die Strecke wird als Zahl abgelegt, nicht als Text', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.treadmill,
            minutes: 12,
            km: 2.45,
          ),
        ),
      );

      final z = (await rohSitzungen(h.db)).single;
      expect(z['aufwaermen_art'], 'treadmill');
      expect(z['aufwaermen_minuten'], 12);
      expect(
        z['aufwaermen_km'],
        2.45,
        reason:
            'vier Wochen „10 min Rad" mit wachsender Strecke ist das '
            'Signal, um das es geht — als Text wäre es nicht vergleichbar '
            '(#40)',
      );
      expect(z['aufwaermen_uebersprungen'], 0);
    });

    test(
      'Mobility ohne Strecke: `null` bleibt `null` und wird nicht 0',
      () async {
        final h = frisch();
        await h.repo.legeAb(
          volles(
            aufwaermen: const WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
          ),
        );

        final gelesen = await h.repo.sitzung('pruef-1');
        final warm = gelesen!.warmUp! as WarmUpDone;
        expect(warm.kind, WarmUpKind.mobility);
        expect(warm.minutes, 8);
        expect(
          warm.km,
          isNull,
          reason:
              'bei Mobility gibt es keine Strecke. Eine 0 behauptete „null '
              'Kilometer", und daraus rechnete die Steigerungskarte später '
              'einen Rückschritt',
        );
        expect((await rohSitzungen(h.db)).single['aufwaermen_km'], isNull);
      },
    );

    test('„übersprungen" kommt als „übersprungen" zurück', () async {
      final h = frisch();
      await h.repo.legeAb(volles(aufwaermen: const WarmUpSkipped()));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(gelesen!.warmUp, isA<WarmUpSkipped>());

      final z = (await rohSitzungen(h.db)).single;
      expect(z['aufwaermen_uebersprungen'], 1);
      expect(z['aufwaermen_art'], isNull);
      expect(z['aufwaermen_minuten'], isNull);
    });

    test('„nichts eingetragen" ist nicht „übersprungen"', () async {
      final h = frisch();
      await h.repo.legeAb(volles(aufwaermen: null));

      final gelesen = await h.repo.sitzung('pruef-1');
      expect(
        gelesen!.warmUp,
        isNull,
        reason:
            '„Übersprungen ist eine Antwort und für den Plan-Agenten '
            'brauchbar; ein leeres Feld ist es nicht" (#40)',
      );
      expect(
        gelesen.warmUp,
        isNot(isA<WarmUpSkipped>()),
        reason: 'die beiden Zustände fallen nicht zusammen',
      );
      expect((await rohSitzungen(h.db)).single['aufwaermen_uebersprungen'], 0);
    });

    test('eine Sitzung ohne Aufwärmen bleibt gültig — der Normalfall der '
        'Übernahme', () async {
      final h = frisch();
      final alt = uebernommenes();
      await h.repo.legeAb(alt);

      final gelesen = await h.repo.sitzung('pruef-alt');
      expect(
        gelesen,
        alt,
        reason:
            'in der alten App gibt es kein Aufwärmen. Abweisen oder auf 0 '
            'abbilden wäre derselbe Fehler wie bei den Satz-Uhrzeiten',
      );
      expect(gelesen!.warmUp, isNull);
    });

    test('die drei Zustände bleiben nebeneinander unterscheidbar', () async {
      final h = frisch();
      await h.repo.legeAb(
        volles(
          id: 'pruef-nichts',
          datum: DateTime.utc(2099, 3, 2, 17),
          workout: Workout.a,
          aufwaermen: null,
        ),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-sprung',
          datum: DateTime.utc(2099, 3, 5, 17),
          workout: Workout.b,
          aufwaermen: const WarmUpSkipped(),
        ),
      );
      await h.repo.legeAb(
        volles(
          id: 'pruef-gemacht',
          datum: DateTime.utc(2099, 3, 9, 17),
          workout: Workout.c,
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.rowing,
            minutes: 9,
            km: 1.8,
          ),
        ),
      );

      expect((await h.repo.sitzung('pruef-nichts'))!.warmUp, isNull);
      expect(
        (await h.repo.sitzung('pruef-sprung'))!.warmUp,
        isA<WarmUpSkipped>(),
      );
      expect(
        (await h.repo.sitzung('pruef-gemacht'))!.warmUp,
        const WarmUpDone(kind: WarmUpKind.rowing, minutes: 9, km: 1.8),
      );
    });

    test('die Kennung des Health-Workouts bleibt bei der Sitzung und '
        'überlebt das Nachtragen', () async {
      final h = frisch();
      await h.repo.legeAb(volles(id: 'pruef-erst'));
      await h.db.customUpdate(
        "UPDATE gym_sitzungen SET aufwaermen_health_uuid = 'PRUEF-HK-RAD';",
      );

      await h.repo.legeAb(
        ImportedSession(
          id: 'pruef-zweit',
          date: DateTime.utc(2099, 3, 2, 19, 0),
          workout: Workout.a,
          minutes: 71,
          note: null,
          warmUp: const WarmUpDone(kind: WarmUpKind.bike, minutes: 10),
          exercises: [
            uebung('pruef-bank', [satz(65.0, 10)]),
          ],
        ),
      );

      expect(
        (await rohSitzungen(h.db)).single['aufwaermen_health_uuid'],
        'PRUEF-HK-RAD',
        reason:
            'die App merkt sich beim Eintragen, welches Health-Workout '
            'passt, statt es bei jedem Blick neu zu suchen — sonst wandert '
            'der Puls (Tim, 10.11.2026)',
      );
    });

    test('eine frisch abgelegte Sitzung hat keine Aufwärm-Kennung', () async {
      final h = frisch();
      await h.repo.legeAb(volles());

      expect(
        (await rohSitzungen(h.db)).single['aufwaermen_health_uuid'],
        isNull,
        reason: 'das Zuordnen kommt mit #414; hier entsteht nur die Spalte',
      );
    });
  });

  group('Abfrage 4: das Aufwärmen eines Zeitraums (#40)', () {
    Future<void> dreiTage(GymRepository repo) async {
      await repo.legeAb(
        volles(
          id: 'pruef-nichts',
          datum: DateTime.utc(2099, 3, 2, 17),
          workout: Workout.a,
          aufwaermen: null,
        ),
      );
      await repo.legeAb(
        volles(
          id: 'pruef-sprung',
          datum: DateTime.utc(2099, 3, 5, 17),
          workout: Workout.b,
          aufwaermen: const WarmUpSkipped(),
        ),
      );
      await repo.legeAb(
        volles(
          id: 'pruef-gemacht',
          datum: DateTime.utc(2099, 3, 9, 17),
          workout: Workout.c,
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.bike,
            minutes: 10,
            km: 3.4,
          ),
        ),
      );
    }

    test('ein Zeitraum ohne Training ist eine leere Liste', () async {
      final h = frisch();
      await dreiTage(h.repo);

      expect(
        await h.repo.aufwaermenImZeitraum(
          vonTag: '2099-04-01',
          bisTag: '2099-04-30',
        ),
        isEmpty,
      );
    });

    test('eine Zeile je Sitzung, ältestes zuerst, Grenzen '
        'einschließlich', () async {
      final h = frisch();
      await dreiTage(h.repo);

      final zeilen = await h.repo.aufwaermenImZeitraum(
        vonTag: '2099-03-02',
        bisTag: '2099-03-09',
      );
      expect(zeilen, hasLength(3));
      expect(zeilen.map((z) => z.tag).toList(), [
        '2099-03-02',
        '2099-03-05',
        '2099-03-09',
      ]);
      expect(zeilen.map((z) => z.sitzungId).toList(), [
        'pruef-nichts',
        'pruef-sprung',
        'pruef-gemacht',
      ]);
    });

    test(
      'übersprungen und „nichts eingetragen" fallen nicht zusammen',
      () async {
        final h = frisch();
        await dreiTage(h.repo);

        final zeilen = await h.repo.aufwaermenImZeitraum(
          vonTag: '2099-03-01',
          bisTag: '2099-03-31',
        );
        expect(zeilen[0].aufwaermen, isNull, reason: 'nichts eingetragen');
        expect(
          zeilen[1].aufwaermen,
          isA<WarmUpSkipped>(),
          reason:
              'übersprungen ist eine Antwort. Wer beides verwechselt, '
              'rechnet später einen Durchschnitt über Tage, an denen gar '
              'nicht trainiert wurde (Tim, 10.11.2026)',
        );
        expect(
          zeilen[2].aufwaermen,
          const WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
        );
      },
    );

    test('die Zeile trägt Minuten, Strecke und Kennung', () async {
      final h = frisch();
      await dreiTage(h.repo);
      await h.db.customUpdate(
        "UPDATE gym_sitzungen SET aufwaermen_health_uuid = 'PRUEF-HK-RAD' "
        "WHERE id = 'pruef-gemacht';",
      );

      final zeilen = await h.repo.aufwaermenImZeitraum(
        vonTag: '2099-03-09',
        bisTag: '2099-03-09',
      );
      final zeile = zeilen.single;
      final warm = zeile.aufwaermen! as WarmUpDone;
      expect(warm.minutes, 10);
      expect(warm.km, 3.4);
      expect(zeile.healthUuid, 'PRUEF-HK-RAD');
      expect(zeile.zeitpunkt, DateTime.utc(2099, 3, 9, 17));
      expect(zeile.zeitpunkt.isUtc, isTrue);
    });

    test('eine Sitzung ohne jede Satz-Uhrzeit kommt auch hier vor', () async {
      final h = frisch();
      await h.repo.legeAb(
        uebernommenes(id: 'pruef-alt', datum: DateTime.utc(2099, 3, 3, 17)),
      );

      final zeilen = await h.repo.aufwaermenImZeitraum(
        vonTag: '2099-03-01',
        bisTag: '2099-03-31',
      );
      expect(zeilen, hasLength(1));
      expect(zeilen.single.aufwaermen, isNull);
    });
  });
}
