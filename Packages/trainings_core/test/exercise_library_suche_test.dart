import 'package:test/test.dart';
import 'package:trainings_core/src/exercise_library_daten.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `foldSearchWords`, `ExerciseLibrary.search`, `mainMuscle` und
/// `ExerciseLibrary.byMainMuscle` (Spec 4.6, 9.2, 9.3, 12.1).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// der Spec und dem Plan (Task 2.1), ohne `exercise_library.dart` gesehen zu
/// haben.
///
/// ## Wer was entschieden hat
///
/// - **Tim (Nachtrag 17):** nichts, was diese Datei betrifft.
/// - **Vorschlag der Spec, vorausgesetzt:** Gruppierung nach höchstem
///   Gewicht, bei Gleichstand kleinerer `Muscle.index` (Spec 15.9, Vorschlag
///   (a): Die Schieflage — Gesäß groß, Oberschenkel vorne klein — ist
///   hingenommen; **getestet wird die Regel, nicht die Verteilung**);
///   Sortierung nach gefaltetem Namen mit Umlaut-Faltung (15.15); die Faltung
///   kennt nur die Tabelle `ä ö ü Ü ß` (9.3); die Suche ist „jedes Wort der
///   Anfrage ist Teilzeichenfolge mindestens eines Suchworts“, ohne
///   Rangfolge (4.6).
/// - **Festlegung des Test-Agenten (keine Entscheidung von Tim):**
///   - **Reihenfolge der Treffer** ist die von `byMainMuscle` (Gruppen in
///     `Muscle`-Reihenfolge, darin nach gefaltetem Namen) — so schreibt es
///     Spec 4.6 vor. Der „gefaltete Name“, nach dem **innerhalb** einer
///     Gruppe sortiert wird, ist `foldSearchWords(name)`, mit Leerzeichen
///     **oder** ohne Leerzeichen verbunden, nach **Codepunkten**
///     (`String.compareTo`) verglichen, nie nach Locale. Die Spec lässt das
///     Verbinden offen, und es ist nicht gleichgültig (die beiden Schlüssel
///     ordnen die 581 Namen verschieden); der Test lässt deshalb beide
///     Lesarten gelten, statt eine festzulegen.
///   - Ein Wort besteht aus `a–z0–9` (Spec 4.6: „in Wörter zerlegt an allem,
///     was nicht a–z/0–9 ist“). Das Verhalten für Zeichen außerhalb der
///     Tabelle (`é`) ist **nicht festgelegt** und hier nicht getestet.
void main() {
  List<Exercise> flach() => [
    for (final gruppe in ExerciseLibrary.byMainMuscle.values) ...gruppe,
  ];

  /// Wie die Spec die Treffer erklärt: jedes Wort der Anfrage ist
  /// Teilzeichenfolge mindestens eines Suchworts der Übung.
  bool trifft(String id, String anfrage) {
    final woerter = foldSearchWords(anfrage);
    final suchwoerter = exerciseSearchTerms[id]!;
    return woerter.every((w) => suchwoerter.any((s) => s.contains(w)));
  }

  Set<String> ids(Iterable<Exercise> uebungen) => {
    for (final e in uebungen) e.id,
  };

  group('foldSearchWords', () {
    test(
      'Umlaute werden zu ihrem Grundbuchstaben: „Überzüge“ → „uberzuge“',
      () {
        expect(foldSearchWords('Überzüge'), ['uberzuge']);
      },
    );

    test('ß wird zu ss: „Straße“ → „strasse“', () {
      expect(foldSearchWords('Straße'), ['strasse']);
    });

    test('ä, ö, ü klein und groß: Kleinschreibung zuerst', () {
      expect(foldSearchWords('Schräg Köpfe Füße'), [
        'schrag',
        'kopfe',
        'fusse',
      ]);
      expect(foldSearchWords('ÜBUNG'), ['ubung']);
    });

    test('Ein Bindestrich trennt Wörter: „Bench-Press“ → bench, press', () {
      expect(foldSearchWords('Bench-Press'), ['bench', 'press']);
    });

    test('Alles außer a–z und 0–9 trennt: Leerzeichen, Schrägstrich, '
        'Apostroph, Klammern', () {
      expect(foldSearchWords('Curl\'s (SZ) / Stange'), [
        'curl',
        's',
        'sz',
        'stange',
      ]);
    });

    test('Ziffern bleiben Wörter: „Figure-4 Stretch“', () {
      expect(foldSearchWords('Figure-4 Stretch'), ['figure', '4', 'stretch']);
    });

    test('Leer, nur Leerraum oder nur Trennzeichen ergibt keine Wörter', () {
      expect(foldSearchWords(''), isEmpty);
      expect(foldSearchWords('   '), isEmpty);
      expect(foldSearchWords('-/ ()'), isEmpty);
    });

    test('Die Reihenfolge der Wörter bleibt die des Textes', () {
      expect(foldSearchWords('Zug Bank Druck'), ['zug', 'bank', 'druck']);
    });

    test('Klein- und Großschreibung machen keinen Unterschied', () {
      expect(foldSearchWords('SQUAT'), foldSearchWords('squat'));
      expect(foldSearchWords('SqUaT'), ['squat']);
    });
  });

  group('search: was gefunden wird', () {
    test('Jedes Wort ist eine Teilzeichenfolge, in beliebiger Reihenfolge: '
        '„press bank“ findet das Bankdrücken (Anker)', () {
      expect(ids(ExerciseLibrary.search('press bank')), contains('benchPress'));
      expect(ids(ExerciseLibrary.search('bank press')), contains('benchPress'));
    });

    test('Deutsch und Englisch führen zur selben Übung: „Bankdrücken '
        'Langhantel“ und „Barbell Bench Press“', () {
      for (final anfrage in [
        'bankdrucken langhantel',
        'barbell bench',
        'Bankdrücken',
        'bench press barbell',
      ]) {
        expect(
          ids(ExerciseLibrary.search(anfrage)),
          contains('benchPress'),
          reason: anfrage,
        );
      }
    });

    test('Teile eines Wortes genügen: „bankdr“ findet „Bankdrücken“', () {
      expect(ids(ExerciseLibrary.search('bankdr')), contains('benchPress'));
      expect(ids(ExerciseLibrary.search('ankdruck')), contains('benchPress'));
    });

    test('Umlaut-frei tippen findet die Übung mit Umlaut, und umgekehrt: '
        '„uberzuge“ und „Überzüge“ finden `straightArmPulldown`', () {
      expect(
        ids(ExerciseLibrary.search('uberzuge')),
        contains('straightArmPulldown'),
      );
      expect(
        ids(ExerciseLibrary.search('Überzüge')),
        contains('straightArmPulldown'),
      );
    });

    test('Der englische Name wird gefunden, nicht nur der deutsche: „squat“ '
        'findet mehr als „kniebeuge“', () {
      final englisch = ExerciseLibrary.search('squat');
      final deutsch = ExerciseLibrary.search('kniebeuge');
      expect(deutsch, isNotEmpty);
      expect(englisch.length, greaterThan(deutsch.length));
      expect(ids(englisch), contains('squat'));
    });

    test('Groß- und Kleinschreibung der Anfrage ändern nichts', () {
      expect(
        ids(ExerciseLibrary.search('SQUAT')),
        ids(ExerciseLibrary.search('squat')),
      );
      expect(
        ExerciseLibrary.search('Bench-Press').map((e) => e.id).toList(),
        ExerciseLibrary.search('bench press').map((e) => e.id).toList(),
      );
    });

    test('Ein Treffer erscheint genau einmal, auch wenn mehrere Wörter '
        'oder mehrere Suchwörter ihn treffen', () {
      for (final anfrage in [
        'press',
        'curl press',
        'e',
        'a e',
        'bench press',
      ]) {
        final treffer = ExerciseLibrary.search(anfrage)
            .map((e) => e.id)
            .toList();
        expect(treffer.toSet(), hasLength(treffer.length), reason: anfrage);
      }
    });

    test('Die Treffermenge ist genau die der Spec: jedes Wort Teilzeichen'
        'folge mindestens eines Suchworts — nicht mehr, nicht weniger', () {
      for (final anfrage in [
        'press',
        'curl',
        'bank',
        'band',
        'uberzuge',
        'press bank',
        'kurzhantel curl',
        'a',
        'zz',
        'stretch hold',
        'Wadenheben',
        'plank',
      ]) {
        final erwartet = {
          for (final e in ExerciseLibrary.all.values)
            if (trifft(e.id, anfrage)) e.id,
        };
        expect(
          ids(ExerciseLibrary.search(anfrage)),
          erwartet,
          reason: '„$anfrage“',
        );
      }
    });

    test('Jede Übung findet sich über ihren eigenen Namen — Anker, Erzeugte '
        'und Cardio', () {
      for (final e in ExerciseLibrary.all.values) {
        expect(
          ExerciseLibrary.search(e.name).map((u) => u.id),
          contains(e.id),
          reason: '„${e.name}“ findet ${e.id} nicht',
        );
      }
    });

    test('Ein Anfragewort, das nur über eine Wortgrenze hinweg als Stück '
        'eines Namens passt, trifft nicht (Spec 4.6)', () {
      // „telschr“ wäre ein Stück von „Kurzhantel Schrägbank …“, ist aber
      // kein Teilstück eines einzelnen Suchworts.
      expect(ExerciseLibrary.search('telschr'), isEmpty);
      expect(ExerciseLibrary.search('presscurl'), isEmpty);
    });
  });

  group('search: leer, nichts, Reihenfolge', () {
    test('Eine leere Anfrage ergibt alle Übungen, jede einmal', () {
      final alle = ExerciseLibrary.search('');
      expect(alle, hasLength(ExerciseLibrary.length));
      expect(ids(alle), ExerciseLibrary.all.keys.toSet());
    });

    test('Nur Leerraum oder Trennzeichen zählen als leer: alle', () {
      for (final anfrage in ['   ', '-', ' - / ', '()']) {
        expect(
          ExerciseLibrary.search(anfrage),
          hasLength(ExerciseLibrary.length),
          reason: '„$anfrage“',
        );
      }
    });

    test('Ohne Treffer kommt eine leere Liste, nie `null`', () {
      final treffer = ExerciseLibrary.search('xyzzyqwertz');
      expect(treffer, isA<List<Exercise>>());
      expect(treffer, isEmpty);
      expect(ExerciseLibrary.search('squat xyzzyqwertz'), isEmpty);
    });

    test('Die Treffer stehen in der Reihenfolge von `byMainMuscle`: Gruppe, '
        'dann gefalteter Name — keine Rangfolge nach Treffergüte', () {
      final reihenfolge = flach().map((e) => e.id).toList();
      for (final anfrage in ['', 'press', 'curl', 'band', 'stretch']) {
        final treffer = ExerciseLibrary.search(anfrage).map((e) => e.id);
        final erwartet = reihenfolge.where(treffer.toSet().contains).toList();
        expect(treffer.toList(), erwartet, reason: '„$anfrage“');
      }
    });

    test('Dieselbe Anfrage gibt dieselbe Antwort in derselben Reihenfolge', () {
      for (final anfrage in ['', 'press', 'bank druck', 'Überzüge']) {
        expect(
          ExerciseLibrary.search(anfrage).map((e) => e.id).toList(),
          ExerciseLibrary.search(anfrage).map((e) => e.id).toList(),
          reason: '„$anfrage“',
        );
      }
    });
  });

  group('mainMuscle: höchstes Gewicht, bei Gleichstand der kleinere Index', () {
    Exercise mit(Map<Muscle, double> muscles) => Exercise(
      id: 'x',
      name: 'x',
      sets: 3,
      repLow: 8,
      repHigh: 12,
      increment: 2.5,
      cue: 'x',
      howTo: const ['x'],
      youTubeQuery: 'x',
      muscles: muscles,
    );

    test('Das höchste Gewicht gewinnt', () {
      expect(
        ExerciseLibrary.mainMuscle(mit({Muscle.biceps: 0.5, Muscle.chest: 1})),
        Muscle.chest,
      );
      expect(
        ExerciseLibrary.mainMuscle(mit({Muscle.chest: 0.5, Muscle.biceps: 1})),
        Muscle.biceps,
      );
    });

    test('Bei Gleichstand gewinnt der Muskel mit dem kleineren '
        '`Muscle.index`, gleich wie die Map geschrieben ist', () {
      expect(
        ExerciseLibrary.mainMuscle(mit({Muscle.quads: 1, Muscle.glutes: 1})),
        Muscle.glutes,
      );
      expect(
        ExerciseLibrary.mainMuscle(mit({Muscle.glutes: 1, Muscle.quads: 1})),
        Muscle.glutes,
      );
      expect(
        ExerciseLibrary.mainMuscle(
          mit({Muscle.triceps: 1, Muscle.chest: 1, Muscle.calves: 0.5}),
        ),
        Muscle.chest,
      );
    });

    test('Gleichstand gilt auch bei lauter Nebenmuskeln (0,5)', () {
      expect(
        ExerciseLibrary.mainMuscle(
          mit({Muscle.rearDelt: 0.5, Muscle.biceps: 0.5}),
        ),
        Muscle.rearDelt,
      );
    });

    test('Ein einziger Muskel ist der Hauptmuskel', () {
      expect(
        ExerciseLibrary.mainMuscle(mit({Muscle.tibialis: 1})),
        Muscle.tibialis,
      );
    });

    test('Eine leere Zuordnung wirft `StateError` — kein stilles „Rumpf“', () {
      expect(() => ExerciseLibrary.mainMuscle(mit(const {})), throwsStateError);
    });
  });

  group('byMainMuscle', () {
    test('Wiederholte Aufrufe geben dieselbe Instanz zurück (einmal '
        'gerechnet, Hausregel 2)', () {
      final erste = ExerciseLibrary.byMainMuscle;
      expect(ExerciseLibrary.byMainMuscle, same(erste));
      expect(ExerciseLibrary.byMainMuscle, same(erste));
    });

    test('Die Gruppen stehen in der Reihenfolge von `Muscle`', () {
      final indizes = ExerciseLibrary.byMainMuscle.keys.map((m) => m.index);
      expect(indizes.toList(), [...indizes]..sort());
      expect(indizes.toSet(), hasLength(indizes.length));
    });

    test('Leere Gruppen fehlen', () {
      for (final eintrag in ExerciseLibrary.byMainMuscle.entries) {
        expect(
          eintrag.value,
          isNotEmpty,
          reason: '${eintrag.key.code}: leere Gruppe',
        );
      }
    });

    test('Jede Übung steht in genau einer Gruppe, und die ist ihr '
        '`mainMuscle`', () {
      final gesehen = <String, Muscle>{};
      for (final eintrag in ExerciseLibrary.byMainMuscle.entries) {
        for (final e in eintrag.value) {
          expect(
            gesehen.containsKey(e.id),
            isFalse,
            reason: '${e.id} steht in zwei Gruppen',
          );
          gesehen[e.id] = eintrag.key;
          expect(
            eintrag.key,
            ExerciseLibrary.mainMuscle(e),
            reason: '${e.id}: falsche Gruppe',
          );
        }
      }
      expect(gesehen.keys.toSet(), ExerciseLibrary.all.keys.toSet());
    });

    test('Die Gruppe folgt der Regel „höchstes Gewicht, Gleichstand kleinerer '
        'Index“ — unabhängig nachgerechnet', () {
      for (final e in ExerciseLibrary.all.values) {
        Muscle? bester;
        for (final eintrag in e.muscles.entries) {
          if (bester == null ||
              eintrag.value > e.muscles[bester]! ||
              (eintrag.value == e.muscles[bester]! &&
                  eintrag.key.index < bester.index)) {
            bester = eintrag.key;
          }
        }
        expect(ExerciseLibrary.mainMuscle(e), bester, reason: e.id);
      }
    });

    test('Innerhalb einer Gruppe nach gefaltetem Namen, nach Codepunkten — '
        'die Wörter mit Leerzeichen oder ohne verbunden', () {
      // Die Spec sagt „alphabetisch nach dem gefalteten Namen“ und lässt
      // offen, ob die Wörter mit Leerzeichen oder ohne verbunden werden. Das
      // ist **nicht gleichgültig**: „negativ bank drucken“ und
      // „negativbank kurzhantel flys“ stehen je nach Schlüssel in anderer
      // Reihenfolge. Der Test lässt beide gelten (Festlegung des Test-Agenten:
      // keine Lücke der Spec zugunsten einer Implementierung schließen) und
      // fängt, was beide ausschließen: `toLowerCase` ohne Faltung, Locale,
      // Zufall. Gemeldet an den Koordinator, die Spec zu präzisieren.
      for (final eintrag in ExerciseLibrary.byMainMuscle.entries) {
        bool sortiertNach(String Function(Exercise) schluessel) {
          final liste = eintrag.value.map(schluessel).toList();
          for (var i = 1; i < liste.length; i++) {
            if (liste[i - 1].compareTo(liste[i]) > 0) return false;
          }
          return true;
        }

        final mitLeerzeichen = sortiertNach(
          (e) => foldSearchWords(e.name).join(' '),
        );
        final ohneLeerzeichen = sortiertNach(
          (e) => foldSearchWords(e.name).join(),
        );
        expect(
          mitLeerzeichen || ohneLeerzeichen,
          isTrue,
          reason:
              '${eintrag.key.code}: weder mit noch ohne Leerzeichen nach '
              'gefaltetem Namen sortiert',
        );
      }
    });

    test('„Überzüge …“ steht unter U, nicht hinter Z: in der Gruppe des '
        'Ankers `straightArmPulldown` vor jedem Namen ab V', () {
      final uebung = ExerciseCatalog.all['straightArmPulldown']!;
      final gruppe =
          ExerciseLibrary.byMainMuscle[ExerciseLibrary.mainMuscle(uebung)]!;
      final position = gruppe.indexOf(uebung);
      expect(position, isNonNegative);
      for (var i = 0; i < gruppe.length; i++) {
        final anfang = foldSearchWords(gruppe[i].name).first[0];
        if (anfang.compareTo('u') > 0) {
          expect(
            i,
            greaterThan(position),
            reason: '„${gruppe[i].name}“ steht vor „${uebung.name}“',
          );
        }
        if (anfang.compareTo('u') < 0) {
          expect(
            i,
            lessThan(position),
            reason: '„${gruppe[i].name}“ steht hinter „${uebung.name}“',
          );
        }
      }
    });

    test('Die Summe aller Gruppen ist die ganze Bibliothek', () {
      final summe = ExerciseLibrary.byMainMuscle.values.fold<int>(
        0,
        (a, gruppe) => a + gruppe.length,
      );
      expect(summe, ExerciseLibrary.length);
    });
  });
}
