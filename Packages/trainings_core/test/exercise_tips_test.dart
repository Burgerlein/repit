import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die additive Formänderung von `Exercise` (#551, Scheibe 1):
/// `commonMistake` wird `String?`, ein Feld `tips` (Liste) kommt dazu.
///
/// Quelle: `docs/superpowers/specs/2026-11-20-uebungskatalog-650-design.md`,
/// Abschnitt 4.4 („`Exercise` wächst additiv“), Abschnitt 12.1 und Nachtrag 17;
/// `docs/superpowers/plans/2026-11-20-uebungskatalog-650-plan.md`, Task 1.3.
///
/// **Warum im Kern und nicht in `app/test/gym/`:** `Exercise` liegt in
/// `Packages/trainings_core`, und Spec 12.1 ordnet die Eigenschaften der
/// Übung dem Kern zu. Eine Eigenschaft des Werttyps, deren Test in `app/test/`
/// landet, beweist die Importgrenze nicht mehr mit (`CLAUDE.md`, „Tests“).
/// Das **Technikblatt-Verhalten** („Häufiger Fehler“ nur bei `!= null`, „Tipp:
/// …“ darunter) ist Scheibe 3 und steht hier nicht.
///
/// **Was Tim entschieden hat und was nicht.** Die Form selbst — `String?`
/// plus `tips` — ist Vorschlag 7 der Spec (Abschnitt 15), vom Plan als
/// Voraussetzung geführt; **Tims Antwort auf Frage 7 liegt dieser Datei nicht
/// vor.** Der Test setzt den Vorschlag voraus. Fällt die Antwort anders aus
/// (der erste Tipp wird zum `cue`, weitere Tipps fallen weg), ändert sich diese
/// Datei. Alles, was unten über `==`/`hashCode` steht, ist dagegen **Folgerung**
/// aus `CLAUDE.md` („Ein Werttyp, der Abhängigkeit eines Providers ist, braucht
/// `==` und `hashCode`“, Fehler `03`) und keine Entscheidung.
///
/// Die Übungen hier sind **erfunden**. Die Datei schreibt der Test-Agent aus
/// der Spec; sie darf **ausgeführt, nie verändert** werden (`CLAUDE.md`).
void main() {
  /// Eine vollständig befüllte Übung. Jeder Test, der Ungleichheit zeigen
  /// will, ändert **genau ein** Feld — sonst beweist er nicht, welches fehlt.
  /// `commonMistake` ist hier absichtlich `String?`: so lässt sich `null`
  /// übergeben, ohne dass der Test den Parameter weglassen muss.
  Exercise build({
    String id = 'tippUebung',
    String? commonMistake = 'Mit Schwung arbeiten.',
    List<String> tips = const ['Erster Tipp.', 'Zweiter Tipp.'],
  }) => Exercise(
    id: id,
    name: 'Tippübung',
    sets: 3,
    repLow: 8,
    repHigh: 12,
    increment: 2.5,
    cue: 'Rücken gerade.',
    howTo: const ['Eins.', 'Zwei.', 'Drei.'],
    commonMistake: commonMistake,
    tips: tips,
    youTubeQuery: 'Tippübung Technik',
    muscles: const {Muscle.chest: 1.0},
  );

  group('tips: die weiteren Hinweise', () {
    test('Ohne Angabe ist die Liste leer, nicht null', () {
      // Die 33 Anker setzen `tips` nie; ihr Standard muss der Normalfall
      // sein, sonst müsste jeder Eintrag das Feld mitschleppen (Spec 4.4:
      // „kein Anker ändert ein Zeichen“).
      final e = Exercise(
        id: 'ohneTipps',
        name: 'Ohne Tipps',
        sets: 3,
        repLow: 8,
        repHigh: 12,
        increment: 2.5,
        cue: 'Hinweis.',
        howTo: const ['Eins.'],
        commonMistake: 'Fehler.',
        youTubeQuery: 'Suche',
        muscles: const {Muscle.core: 1.0},
      );
      expect(e.tips, isEmpty);
      expect(e.tips, isA<List<String>>());
    });

    test('Die Tipps kommen unverändert und in dieser Reihenfolge an', () {
      final e = build(tips: ['Zuerst.', 'Dann.', 'Zuletzt.']);
      expect(e.tips, ['Zuerst.', 'Dann.', 'Zuletzt.']);
    });

    test('Jede der 33 Katalogübungen setzt weiter commonMistake und lässt '
        'tips leer', () {
      // Spec 4.4: Alle 33 Anker behalten ihren häufigen Fehler und bekommen
      // keine Tipps — die Formänderung rührt sie nicht an.
      expect(ExerciseCatalog.all, hasLength(33));
      for (final e in ExerciseCatalog.all.values) {
        expect(e.tips, isEmpty, reason: '${e.id}: der Anker trägt Tipps');
        expect(
          e.commonMistake,
          isNotNull,
          reason: '${e.id}: der Anker hat seinen häufigen Fehler verloren',
        );
        expect(e.commonMistake, isNotEmpty, reason: e.id);
      }
    });
  });

  group('commonMistake: darf fehlen', () {
    test('Weggelassen ist es null — „der Datensatz nennt keinen“', () {
      // Die erzeugten Übungen haben keinen häufigsten Fehler, und es wird
      // keiner erfunden (Spec 5.3). Dafür muss das Feld optional sein.
      final e = Exercise(
        id: 'ohneFehler',
        name: 'Ohne Fehler',
        sets: 3,
        repLow: 8,
        repHigh: 12,
        increment: 2.5,
        cue: 'Hinweis.',
        howTo: const ['Eins.'],
        youTubeQuery: 'Suche',
        muscles: const {Muscle.core: 1.0},
      );
      expect(e.commonMistake, isNull);
    });

    test('Ausdrücklich null bleibt null, nie die leere Zeichenkette', () {
      // `null` heißt „keiner bekannt“, `''` hieße „ein leerer Text“. Eine
      // Anzeige, die `!= null` prüft, zeigte bei `''` eine leere Zeile.
      final e = build(commonMistake: null);
      expect(e.commonMistake, isNull);
      expect(e.commonMistake, isNot(''));
    });

    test('Ein gesetzter Wert kommt unverändert wieder heraus', () {
      expect(build().commonMistake, 'Mit Schwung arbeiten.');
    });
  });

  group('== und hashCode tragen tips mit', () {
    test('Gleicher Inhalt heißt gleich, auch über zwei getrennte Listen', () {
      // Zwei Exemplare, die keine Liste teilen: Die Gleichheit muss über den
      // Inhalt laufen. Darts `==` auf `List` ist Identität — ohne
      // Inhaltsvergleich wäre jede neu gebaute Übung ungleich der vorigen und
      // jeder abgeleitete Riverpod-Wert liefe neu (Fehler `03`).
      final a = build(tips: List.of(['Eins.', 'Zwei.']));
      final b = build(tips: List.of(['Eins.', 'Zwei.']));
      expect(identical(a.tips, b.tips), isFalse, reason: 'sonst ohne Beweis');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Anderer Inhalt der Tipps macht die Übung ungleich', () {
      final a = build(tips: ['Eins.', 'Zwei.']);
      final b = build(tips: ['Eins.', 'Drei.']);
      expect(a, isNot(b));
    });

    test('Dieselben Tipps in anderer Reihenfolge sind nicht dieselben', () {
      // Wie `howTo` ist `tips` eine Reihenfolge: Die Anzeige zeigt sie in
      // dieser Folge (Spec 4.4: „in dieser Reihenfolge“).
      final a = build(tips: ['Eins.', 'Zwei.']);
      final b = build(tips: ['Zwei.', 'Eins.']);
      expect(a, isNot(b));
    });

    test('Ein zusätzlicher Tipp macht die Übung ungleich', () {
      final a = build(tips: ['Eins.']);
      final b = build(tips: ['Eins.', 'Zwei.']);
      expect(a, isNot(b));
      expect(b, isNot(a));
    });

    test('Keine Tipps und ein Tipp sind verschieden', () {
      expect(build(tips: const []), isNot(build(tips: const ['Eins.'])));
    });

    test('Zwei leere Listen sind gleich, auch wenn eine nicht const ist', () {
      final a = build(tips: <String>[]);
      final b = build(tips: const []);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Gleiche Übungen mit Tipps fallen in einer Menge zusammen', () {
      // Der praktische Grund für `hashCode`: Ohne ihn stünden zwei gleiche
      // Übungen zweimal in derselben Menge.
      final menge = {
        build(tips: ['Eins.']),
        build(tips: ['Eins.']),
        build(tips: ['Zwei.']),
      };
      expect(menge, hasLength(2));
    });

    test('null und die leere Zeichenkette sind bei commonMistake verschieden',
        () {
      // Der Unterschied „keiner bekannt“ gegen „leerer Text“ muss in `==`
      // ankommen, sonst verschmilzt eine Übung ohne Fehler mit einer, deren
      // Fehlertext leer ist.
      final ohne = build(commonMistake: null);
      final leer = build(commonMistake: '');
      expect(ohne, isNot(leer));
      expect(leer, isNot(ohne));
    });

    test('null gegen einen Text macht die Übung ungleich', () {
      expect(build(commonMistake: null), isNot(build()));
      expect(build(), isNot(build(commonMistake: null)));
    });

    test('Zwei Übungen ohne häufigen Fehler sind gleich', () {
      // `null == null` muss gelten, und der Hash darf an `null` nicht
      // scheitern.
      final a = build(commonMistake: null);
      final b = build(commonMistake: null);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Ein anderer häufiger Fehler macht die Übung ungleich', () {
      expect(build(), isNot(build(commonMistake: 'Anderer Fehler.')));
    });
  });

  group('withPlan bewahrt beide Felder', () {
    test('Die Tipps bleiben, in Reihenfolge', () {
      final katalog = build(tips: ['Zuerst.', 'Dann.']);
      final geplant = katalog.withPlan(
        sets: 4,
        repLow: 6,
        repHigh: 10,
        increment: 5,
      );
      expect(geplant.tips, ['Zuerst.', 'Dann.']);
      expect(geplant.sets, 4);
      expect(geplant.repLow, 6);
      expect(geplant.repHigh, 10);
      expect(geplant.increment, 5);
    });

    test('Ein gesetzter häufiger Fehler bleibt', () {
      final geplant = build().withPlan(
        sets: 2,
        repLow: 5,
        repHigh: 8,
        increment: 1,
      );
      expect(geplant.commonMistake, 'Mit Schwung arbeiten.');
    });

    test('Ein fehlender häufiger Fehler bleibt null und wird nicht leer', () {
      // Der Fall, den ein falscher Ersatz still verbiegt: `?? ''` hier ließe
      // die Erfassung eine leere „Häufiger Fehler“-Zeile zeigen.
      final geplant = build(commonMistake: null).withPlan(
        sets: 2,
        repLow: 5,
        repHigh: 8,
        increment: 1,
      );
      expect(geplant.commonMistake, isNull);
    });

    test('Mit denselben Planwerten ist das Ergebnis gleich der Übung', () {
      // Beweist, dass kein Feld — auch `tips` und `commonMistake` nicht —
      // beim Umbau verloren geht: Über `==` wäre es sonst ungleich.
      final e = build(tips: ['Eins.', 'Zwei.']);
      final geplant = e.withPlan(
        sets: e.sets,
        repLow: e.repLow,
        repHigh: e.repHigh,
        increment: e.increment,
      );
      expect(geplant, e);
      final ohneFehler = build(commonMistake: null, tips: ['Eins.']);
      expect(
        ohneFehler.withPlan(
          sets: ohneFehler.sets,
          repLow: ohneFehler.repLow,
          repHigh: ohneFehler.repHigh,
          increment: ohneFehler.increment,
        ),
        ohneFehler,
      );
    });
  });
}
