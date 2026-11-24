import 'package:test/test.dart';
import 'package:trainings_core/src/exercise_library_daten.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `ExerciseLibrary` — die Bibliothek aller Übungen, die man in ein
/// Training legen kann: die 33 handgeschriebenen Anker, die erzeugten Übungen
/// und die handgeschriebenen Ergänzungen (#551, Scheibe 2, Task 2.1).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// `docs/superpowers/specs/2026-11-20-uebungskatalog-650-design.md` (4, 12.1,
/// mit den Nachträgen 17 und 18) und dem Plan `…-650-plan.md`, Task 2.1 —
/// **ohne** `exercise_library.dart` gesehen zu haben, die es beim Schreiben
/// noch nicht gab.
///
/// ## Woher die festen Zahlen stammen
///
/// Sie stehen **mit Absicht** als Literale da. Sie sind **nicht** aus Spec
/// Abschnitt 2 und nicht aus der Statistik des Generators abgeschrieben,
/// sondern am gepinnten Datensatz `scripts/.cache/exercises.json` (RepDB
/// `free-708-2026-11`, Commit `4b1358a`, 708 Übungen, SHA-256 `ad7c602f…948f`)
/// mit einem Wegwerfskript nachgezählt, das Spec 6 samt Nachträgen 18 bis 20
/// unabhängig auf alle Zeilen anwendet — nur JSON-Felder, **keine Bilddatei
/// geöffnet**. Dass die Statistik des Generators (`--statistik`) dieselben
/// Zahlen nennt, ist ein Gegenbeleg, keine Quelle. Ein neuer Pin ändert sie;
/// dann bekommt der Test-Agent neue Zahlen:
///
/// | Was | Zahl |
/// |---|---:|
/// | RepDB-Zeilen | 708 |
/// | Zeilen der 33 Anker (`MAPPING`) | 33 |
/// | ohne Hauptmuskel in den 16 Gruppen | 19 |
/// | Namensfilter (unsauber übersetzt, nach Akzeptanzliste) | 108 |
/// | **erzeugt** (Cardio ist dabei, Nachtrag 19) | **548** |
/// | **Bibliothek** (33 + 548 + 0 Ergänzungen) | **581** |
/// | erzeugte Zeitübungen (Halteübungen und Cardio) | 162 |
/// | davon Z1 / Z2 / Z3 / Cardio | 60 / 16 / 67 / 19 |
///
/// **Überholt, und deshalb nirgends in dieser Datei:** 514, 481, 117, 118,
/// 59/11/47 (Stand vor dem 708er-Sprung, Nachtrag 20) sowie 584, 617, 125 und
/// 2 der Spec (Nachtrag 17 Nr. 2; Nachtrag 18).
///
/// ## Wer was entschieden hat
///
/// - **Entscheidung von Tim (Nachtrag 17 und 19, 20.11.2026):** nur sauber
///   übersetzte Namen (die Bibliothek startet ohne die Ausgeschlossenen); die
///   Bilder werden committet; Cardio kommt in die Bibliothek.
/// - **Vorschlag der Spec, den diese Tests voraussetzen** (Spec 15: 2, 4–7,
///   11, 14; Plan 1, 2, 7; Nachtrag 19: der Cardio-Zweig als „Brücke“): die
///   Übungen ohne Hauptmuskel bleiben draußen, Gewichte nur 1,0 und 0,5,
///   `ExerciseExtras.all` startet leer, `commonMistake == null` für alle
///   Erzeugten, Trage-Übungen als Zeitübung, Cardio als Zeitübung 1 × 300–600 s.
///   **Das ist nicht entschieden**, nur vorausgesetzt.
/// - **Folgerung aus dem 708er-Sprung (Nachtrag 20):** `savasana` fällt
///   bewusst heraus; `sissy-squat` ist drin.
/// - **Festlegung des Test-Agenten** (keine Entscheidung von Tim): die Form
///   `Map<String, Exercise> mergeExercises(List<Iterable<Exercise>>)` für den
///   Kollisionstest (Plan Task 2.1 fixiert den Namen); die Grenzen der
///   Bereichs-Eigenschaft (Sätze 1–10 aus `WorkoutRules.maxSets`, Wdh bis
///   `maxReps`, Sekunden bis `maxSeconds`); dass `ExerciseLibrary.all` in
///   dieser Schlüsselreihenfolge steht: erst `ExerciseCatalog`, dann die
///   erzeugten, dann die Ergänzungen (so steht es im Doc-Kommentar der Spec 4.6).
///
/// Die Handwerte der 33 prüft `exercise_catalog_test.dart` — **nicht
/// verändern**. Hier gilt nur: Die Anker sind unverändert **eingebunden**.
void main() {
  Exercise bau(String id, {String? name, Map<Muscle, double>? muscles}) =>
      Exercise(
        id: id,
        name: name ?? 'Übung $id',
        sets: 3,
        repLow: 8,
        repHigh: 12,
        increment: 2.5,
        cue: 'Hinweis',
        howTo: const ['Schritt'],
        youTubeQuery: '$id Technik',
        muscles: muscles ?? const {Muscle.chest: 1},
      );

  final alle = ExerciseLibrary.all.values.toList();
  final ankerIds = ExerciseCatalog.all.keys.toSet();
  final erzeugte = [
    for (final e in alle)
      if (!ankerIds.contains(e.id)) e,
  ];

  group('Die Bibliothek in Zahlen', () {
    test('Es sind 581 Übungen: 33 Anker + 548 erzeugte + 0 Ergänzungen', () {
      expect(ExerciseCatalog.all, hasLength(33));
      expect(generatedExercises, hasLength(548));
      expect(ExerciseExtras.all, isEmpty);
      expect(ExerciseLibrary.length, 581);
      expect(ExerciseLibrary.all, hasLength(581));
    });

    test('`length` ist die Größe von `all`', () {
      expect(ExerciseLibrary.length, ExerciseLibrary.all.length);
    });

    test('`ExerciseCatalog.all` bleibt bei 33 — die Bibliothek verändert '
        'den Katalog nicht', () {
      expect(ExerciseCatalog.all, hasLength(33));
      for (final id in ExerciseCatalog.all.keys) {
        expect(
          ExerciseLibrary.isCatalog(id),
          isTrue,
          reason: '$id muss als Anker gelten',
        );
      }
    });

    test('162 erzeugte und 163 Übungen insgesamt sind Zeitübungen — die '
        'eine Handübung ist der Seitstütz', () {
      expect(erzeugte.where((e) => e.isTimed), hasLength(162));
      expect(alle.where((e) => e.isTimed), hasLength(163));
      expect(
        ExerciseCatalog.all.values.where((e) => e.isTimed).map((e) => e.id),
        ['sidePlank'],
      );
    });

    test('Die Zeitübungen zerfallen in 60 / 16 / 67 / 19 nach Dauer '
        '(Zweige Z1, Z2, Z3 und Cardio der Regeltabelle)', () {
      int zaehle(int sets, int low, int high) => erzeugte
          .where(
            (e) =>
                e.isTimed &&
                e.sets == sets &&
                e.repLow == low &&
                e.repHigh == high &&
                e.increment == 5,
          )
          .length;
      expect(zaehle(2, 30, 60), 60, reason: 'Z1: Dehnung halten');
      expect(zaehle(3, 10, 20), 16, reason: 'Z2: schwere Halteübung');
      expect(zaehle(3, 30, 45), 67, reason: 'Z3: Halteübung');
      expect(zaehle(1, 300, 600), 19, reason: 'Cardio: 1 × 300–600 s');
    });

    test('Unterstützung erlauben genau vier: `dips`, `pullUp` (Anker), '
        '`assisted-dips`, `assisted-pull-ups`', () {
      expect(
        {
          for (final e in alle)
            if (e.allowsAssist) e.id,
        },
        {'dips', 'pullUp', 'assisted-dips', 'assisted-pull-ups'},
      );
    });
  });

  group('IDs und Schlüssel', () {
    test('Jede ID kommt genau einmal vor, der Schlüssel ist die `id`', () {
      for (final eintrag in ExerciseLibrary.all.entries) {
        expect(eintrag.key, eintrag.value.id);
      }
      expect({for (final e in alle) e.id}, hasLength(alle.length));
    });

    test('IDs sind nicht leer und ohne Leerraum', () {
      for (final e in alle) {
        expect(e.id, isNotEmpty);
        expect(e.id, e.id.trim(), reason: e.id);
        expect(e.id.contains(' '), isFalse, reason: e.id);
      }
    });

    test('Die Schlüssel stehen erst im Katalog, dann bei den erzeugten, '
        'dann bei den Ergänzungen (Spec 4.6)', () {
      final erwartet = [
        ...ExerciseCatalog.all.keys,
        for (final e in generatedExercises) e.id,
        for (final e in ExerciseExtras.all) e.id,
      ];
      expect(ExerciseLibrary.all.keys.toList(), erwartet);
    });

    test('`all` ist nicht veränderbar', () {
      expect(
        () => ExerciseLibrary.all['x-neu'] = bau('x-neu'),
        throwsUnsupportedError,
      );
      expect(() => ExerciseLibrary.all.remove('squat'), throwsUnsupportedError);
      expect(ExerciseLibrary.all, hasLength(581));
    });

    test('`byId` findet Anker und Erzeugte, eine fremde ID ergibt `null`', () {
      expect(ExerciseLibrary.byId('benchPress'), isNotNull);
      expect(ExerciseLibrary.byId('squat')?.id, 'squat');
      expect(ExerciseLibrary.byId('plank')?.id, 'plank');
      expect(ExerciseLibrary.byId('gibtEsNicht'), isNull);
      expect(ExerciseLibrary.byId(''), isNull);
      for (final e in alle) {
        expect(ExerciseLibrary.byId(e.id), same(e), reason: e.id);
      }
    });

    test('`isCatalog` gilt genau für die 33 Anker', () {
      expect(ExerciseLibrary.isCatalog('benchPress'), isTrue);
      expect(ExerciseLibrary.isCatalog('squat'), isFalse);
      expect(ExerciseLibrary.isCatalog('gibtEsNicht'), isFalse);
      expect({
        for (final e in alle)
          if (ExerciseLibrary.isCatalog(e.id)) e.id,
      }, ankerIds);
    });
  });

  group('Die 33 Anker bleiben wörtlich', () {
    test('Jeder Anker ist dasselbe Objekt wie im Katalog (`identical`)', () {
      for (final eintrag in ExerciseCatalog.all.entries) {
        expect(
          ExerciseLibrary.all[eintrag.key],
          same(eintrag.value),
          reason: '${eintrag.key}: nicht dasselbe Objekt wie im Katalog',
        );
      }
    });

    test('Die Anker behalten ihren `commonMistake` und haben keine `tips`', () {
      for (final e in ExerciseCatalog.all.values) {
        expect(e.commonMistake, isNotNull, reason: e.id);
        expect(e.tips, isEmpty, reason: e.id);
      }
    });
  });

  group('Namen', () {
    test('Kein Name ist leer', () {
      for (final e in alle) {
        expect(e.name.trim(), isNotEmpty, reason: e.id);
      }
    });

    test('Zwei Übungen heißen nie gleich — auch nicht ohne Beachtung der '
        'Schreibweise', () {
      final klein = <String, String>{};
      for (final e in alle) {
        final bisher = klein[e.name.toLowerCase()];
        expect(
          bisher,
          isNull,
          reason: '${e.id} heißt wie $bisher: „${e.name}“',
        );
        klein[e.name.toLowerCase()] = e.id;
      }
    });

    test('… und nicht nach der Umlaut-Faltung: „Überzüge“ und „Uberzuge“ '
        'wären dieselbe Suche', () {
      final gefaltet = <String, String>{};
      for (final e in alle) {
        final schluessel = foldSearchWords(e.name).join(' ');
        final bisher = gefaltet[schluessel];
        expect(
          bisher,
          isNull,
          reason: '${e.id} faltet wie $bisher zu „$schluessel“',
        );
        gefaltet[schluessel] = e.id;
      }
    });
  });

  group('Muskeln', () {
    test('Jede Übung trifft mindestens einen Muskel, und mindestens einer '
        'ist Hauptmuskel (Gewicht 1,0)', () {
      for (final e in alle) {
        expect(e.muscles, isNotEmpty, reason: e.id);
        expect(
          e.muscles.values.any((w) => w == 1.0),
          isTrue,
          reason: '${e.id}: kein Hauptmuskel',
        );
      }
    });

    test('Es gibt nur die Gewichte 1,0 und 0,5', () {
      for (final e in alle) {
        for (final eintrag in e.muscles.entries) {
          expect(
            eintrag.value,
            anyOf(1.0, 0.5),
            reason: '${e.id}/${eintrag.key.code}: ${eintrag.value}',
          );
        }
      }
    });

    test('Jede der 16 Gruppen wird von mindestens einer Übung getroffen — '
        'fehlt eine, ist das ein Befund für Tim, kein Grund zu lockern', () {
      for (final muskel in Muscle.values) {
        expect(
          alle.any((e) => e.muscles.containsKey(muskel)),
          isTrue,
          reason: '${muskel.code}: keine Übung der Bibliothek trifft ihn',
        );
      }
    });

    test('… und bei mindestens einer ist sie Hauptmuskel (Gewicht 1,0)', () {
      for (final muskel in Muscle.values) {
        expect(
          alle.any((e) => e.muscles[muskel] == 1.0),
          isTrue,
          reason: '${muskel.code}: bei keiner Übung Hauptmuskel',
        );
      }
    });
  });

  group('Bereiche', () {
    test('Sätze 1 bis 10, Wiederholungen von 1 bis zur Grenze, Steigerung '
        'über null', () {
      for (final e in alle) {
        expect(e.sets, inInclusiveRange(1, WorkoutRules.maxSets), reason: e.id);
        expect(e.repLow, greaterThan(0), reason: e.id);
        expect(e.repLow, lessThan(e.repHigh), reason: e.id);
        final grenze = e.isTimed
            ? WorkoutRules.maxSeconds
            : WorkoutRules.maxReps;
        expect(e.repHigh, lessThanOrEqualTo(grenze), reason: e.id);
        expect(e.increment, greaterThan(0), reason: e.id);
      }
    });

    test('Zeitübungen haben einen Sekundenbereich: ab 10 Sekunden, '
        'Steigerung in Sekunden (mindestens 5), obere Grenze ab 20', () {
      for (final e in alle.where((e) => e.isTimed)) {
        expect(e.repLow, greaterThanOrEqualTo(10), reason: e.id);
        expect(e.repHigh, greaterThanOrEqualTo(20), reason: e.id);
        expect(e.increment, greaterThanOrEqualTo(5), reason: e.id);
      }
    });

    test('Wiederholungsübungen haben nie einen Sekundenbereich: obere '
        'Grenze höchstens 25 (so hoch geht der Anker `tibialisRaise`), bei '
        'den erzeugten höchstens 20', () {
      for (final e in alle.where((e) => !e.isTimed)) {
        expect(e.repHigh, lessThanOrEqualTo(25), reason: e.id);
      }
      for (final e in erzeugte.where((e) => !e.isTimed)) {
        expect(e.repHigh, lessThanOrEqualTo(20), reason: e.id);
      }
    });

    test('Wer eine obere Grenze ab 30 hat, ist als Zeitübung markiert', () {
      for (final e in alle.where((e) => e.repHigh >= 30)) {
        expect(e.isTimed, isTrue, reason: '${e.id}: ${e.repHigh} ohne isTimed');
      }
    });

    test('Die acht Trage-Übungen sind Zeitübungen ohne erfasste Last '
        '(3 × 30–45 s, Zweig Z3, Vorschlag der Spec 15.11)', () {
      const trage = [
        'db-overhead-carry',
        'double-db-overhead-carry',
        'dumbbell-farmers-walk',
        'kettlebell-farmers-walk',
        'kettlebell-overhead-carry',
        'sandbag-carry',
        'suitcase-carry',
      ];
      for (final id in trage) {
        final e = ExerciseLibrary.byId(id);
        expect(e, isNotNull, reason: '$id fehlt');
        expect(e!.isTimed, isTrue, reason: id);
        expect((e.sets, e.repLow, e.repHigh), (3, 30, 45), reason: id);
      }
      // Die achte ist als „schwer“ eingestuft: Zweig Z2 (Spec 6, Z2 vor Z3).
      final schwer = ExerciseLibrary.byId('double-kettlebell-overhead-carry');
      expect(schwer, isNotNull);
      expect(schwer!.isTimed, isTrue);
      expect((schwer.sets, schwer.repLow, schwer.repHigh), (3, 10, 20));
    });
  });

  group('Texte', () {
    test('`cue`, `howTo`, `tips` und `youTubeQuery` sind vollständig', () {
      for (final e in alle) {
        expect(e.cue.trim(), isNotEmpty, reason: '${e.id}: cue');
        expect(e.howTo, isNotEmpty, reason: '${e.id}: howTo');
        for (final schritt in e.howTo) {
          expect(schritt.trim(), isNotEmpty, reason: '${e.id}: leerer Schritt');
        }
        for (final tipp in e.tips) {
          expect(tipp.trim(), isNotEmpty, reason: '${e.id}: leerer Tipp');
        }
        expect(e.youTubeQuery.trim(), isNotEmpty, reason: '${e.id}: query');
      }
    });

    test('Erzeugte Übungen haben 4 bis 7 Schritte und 1 bis 3 Tipps (am '
        'Datensatz gemessen), und keinen erfundenen „häufigsten Fehler“', () {
      for (final e in erzeugte) {
        expect(e.howTo.length, inInclusiveRange(4, 7), reason: e.id);
        expect(e.tips.length, inInclusiveRange(1, 3), reason: e.id);
        expect(e.commonMistake, isNull, reason: '${e.id}: erfunden');
      }
    });

    test('Die Suche im Netz heißt „<Name> Technik“ (Spec 5.3)', () {
      for (final e in erzeugte) {
        expect(e.youTubeQuery, '${e.name} Technik', reason: e.id);
      }
    });
  });

  group('Gegenseiten: `exerciseSearchTerms` und die Bibliothek', () {
    test('Jede ID der Suchwörter ist eine Bibliotheks-ID und umgekehrt', () {
      expect(
        exerciseSearchTerms.keys.toSet(),
        ExerciseLibrary.all.keys.toSet(),
      );
    });

    test('Jede Übung hat mindestens ein Suchwort, jedes ist gefaltet '
        '(nur a–z und 0–9, nicht leer)', () {
      final gefaltet = RegExp(r'^[a-z0-9]+$');
      for (final eintrag in exerciseSearchTerms.entries) {
        expect(eintrag.value, isNotEmpty, reason: eintrag.key);
        for (final wort in eintrag.value) {
          expect(
            gefaltet.hasMatch(wort),
            isTrue,
            reason: '${eintrag.key}: „$wort“ ist nicht gefaltet',
          );
        }
      }
    });

    test('Die gefalteten Namenswörter sind eine Teilmenge der Suchwörter — '
        'so fängt der Test eine Faltungstabelle, die ein Zeichen vergisst', () {
      for (final e in alle) {
        final woerter = exerciseSearchTerms[e.id]!.toSet();
        for (final wort in foldSearchWords(e.name)) {
          expect(
            woerter,
            contains(wort),
            reason: '${e.id}: „$wort“ aus „${e.name}“ fehlt in den Suchwörtern',
          );
        }
      }
    });

    test('Für Anker stehen die Wörter des Handnamens **und** des englischen '
        'RepDB-Namens in den Suchwörtern (Spec 5.3)', () {
      final bank = exerciseSearchTerms['benchPress']!;
      expect(bank, containsAll(['bankdrucken', 'langhantel']));
      expect(bank, containsAll(['barbell', 'bench', 'press']));
      final zehen = exerciseSearchTerms['tibialisRaise']!;
      expect(zehen, containsAll(['kettlebell', 'tibialis']));
    });
  });

  group('Kollisionen: `mergeExercises`', () {
    test(
      'Ohne gemeinsame ID entsteht eine Map in der Reihenfolge der Quellen',
      () {
        final a = bau('a');
        final b = bau('b');
        final c = bau('c');
        final karte = mergeExercises([
          [a],
          [b, c],
        ]);
        expect(karte.keys.toList(), ['a', 'b', 'c']);
        expect(karte['b'], same(b));
      },
    );

    test('Keine Quelle ergibt eine leere Map', () {
      expect(mergeExercises(const []), isEmpty);
      expect(mergeExercises(const [[], []]), isEmpty);
    });

    test('Dieselbe ID in zwei Quellen wirft `StateError` und nennt die ID', () {
      expect(
        () => mergeExercises([
          [bau('dips')],
          [bau('dips', name: 'Andere Dips')],
        ]),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('dips'),
          ),
        ),
      );
    });

    test('Dieselbe ID zweimal in **einer** Quelle wirft ebenso', () {
      expect(
        () => mergeExercises([
          [bau('x-doppelt'), bau('x-doppelt')],
        ]),
        throwsStateError,
      );
    });

    test('Auch dasselbe Objekt zweimal ist eine Kollision: ersetzt wird nie, '
        'auch nicht durch ein gleiches', () {
      final a = bau('a');
      expect(
        () => mergeExercises([
          [a],
          [a],
        ]),
        throwsStateError,
      );
    });

    test('Die Bibliothek ist genau die Vereinigung von Katalog, Erzeugten '
        'und Ergänzungen', () {
      final erwartet = mergeExercises([
        ExerciseCatalog.all.values,
        generatedExercises,
        ExerciseExtras.all,
      ]);
      expect(ExerciseLibrary.all.keys.toList(), erwartet.keys.toList());
      for (final id in erwartet.keys) {
        expect(ExerciseLibrary.all[id], same(erwartet[id]), reason: id);
      }
    });

    test('Die einzige Überschneidung der IDs mit dem Datensatz ist `dips` — '
        'und dort gewinnt kein Datensatz-Eintrag', () {
      // Die RepDB-Zeile `dips` gehört dem Anker `dips` (Spec 4.2); sie darf
      // nicht ein zweites Mal als erzeugte Übung auftauchen.
      expect(generatedExercises.where((e) => e.id == 'dips'), isEmpty);
      expect(ExerciseLibrary.byId('dips'), same(ExerciseCatalog.all['dips']));
    });
  });
}
