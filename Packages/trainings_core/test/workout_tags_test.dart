import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutTags`** — Normalisieren, Hinzufügen und Vorschlagen
/// von Tags (#532). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 5.6 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Tags sind **frei mit Vorschlägen**; schon
///   benutzte Tags werden vorgeschlagen (18.11.2026, #531, Entscheidung 4).
/// - **Vorschlag der Spec, hier vorausgesetzt:** die Grenzen — höchstens 5
///   Tags, je höchstens 20 Zeichen (17.22, „meine Zahlen") — und die
///   Sortierung der Vorschläge: Häufigkeit absteigend, bei Gleichstand
///   alphabetisch ohne Beachtung der Schreibweise (5.6, „[Vorschlag zur
///   Sortierung]").
/// - **Festlegung des Test-Agenten:** Dass die Länge **nach** dem
///   Zusammenziehen von Leerraum gezählt wird. Die Spec nennt die Schritte in
///   der Reihenfolge trimmen, Leerraum zusammenziehen, leer → `null`, mehr
///   als 20 → `null`; die Tests lesen das als Reihenfolge der Ausführung.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_tags.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutTags {
///   static String? normalize(String raw);
///   static List<String> add(List<String> tags, String raw);
///   static List<String> suggestions({
///     required Map<String, int> used, required List<String> current,
///   });
/// }
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **„Gym" und „Home" sind nirgends fest einprogrammiert** (Spec 5.6):
///   ein negativer Fall über den Quelltext lässt sich im Kern nicht
///   beweisen. `suggestions` mit leerem `used` gibt leer — das ist der
///   prüfbare Teil.
/// - **Wie Tags über Schreibweisen hinweg gezählt werden** (`used` enthält
///   „Gym" und „gym" getrennt?) — das ist Sache der Abfrage
///   (`benutzteTags`, `app/`).

String zeichen(int n) => 'a' * n;

void main() {
  // -------------------------------------------------------------------------
  group('normalize', () {
    test('Ein sauberer Tag bleibt, wie er ist', () {
      expect(WorkoutTags.normalize('Gym'), 'Gym');
    });

    test('Führender und folgender Leerraum fällt weg', () {
      expect(WorkoutTags.normalize('  Gym  '), 'Gym');
      expect(WorkoutTags.normalize('\tGym\n'), 'Gym');
    });

    test('Innere Folgen von Leerraum werden ein Leerzeichen', () {
      expect(
        WorkoutTags.normalize('Kurz   hantel  zuhause'),
        'Kurz hantel zuhause',
      );
      expect(WorkoutTags.normalize('a\tb'), 'a b');
      expect(WorkoutTags.normalize('a \n b'), 'a b');
    });

    test('Die Schreibweise bleibt, wie getippt', () {
      expect(WorkoutTags.normalize('GYM'), 'GYM');
      expect(WorkoutTags.normalize('gym'), 'gym');
      expect(WorkoutTags.normalize('Äpfel'), 'Äpfel');
    });

    test('Leer oder nur Leerraum ergibt null', () {
      expect(WorkoutTags.normalize(''), isNull);
      expect(WorkoutTags.normalize('   '), isNull);
      expect(WorkoutTags.normalize(' \t\n '), isNull);
    });

    test('20 Zeichen sind noch erlaubt, 21 ergeben null', () {
      expect(WorkoutTags.normalize(zeichen(20)), zeichen(20));
      expect(WorkoutTags.normalize(zeichen(21)), isNull);
    });

    test('Ein zu langer Tag wird nicht gekürzt', () {
      // Kürzen wäre Raten (Spec 5.6): Aus „Oberkörper-Push-und-Arme-heute"
      // würde ein Tag, den niemand getippt hat.
      expect(WorkoutTags.normalize('Oberkörper-Push-und-Arme-heute'), isNull);
    });

    test('Gezählt wird nach dem Trimmen', () {
      expect(WorkoutTags.normalize('  ${zeichen(20)}  '), zeichen(20));
    });

    test('Gezählt wird nach dem Zusammenziehen von Leerraum', () {
      // 9 + 4 Leerzeichen + 10 = 23 Zeichen roh, zusammengezogen
      // 9 + 1 + 10 = 20.
      final roh = '${zeichen(9)}    ${zeichen(10)}';
      expect(roh.length, 23);
      expect(WorkoutTags.normalize(roh), '${zeichen(9)} ${zeichen(10)}');
    });
  });

  // -------------------------------------------------------------------------
  group('add', () {
    test('Ein neuer Tag kommt ans Ende', () {
      expect(WorkoutTags.add(['Gym'], 'Home'), ['Gym', 'Home']);
    });

    test('Zu einer leeren Liste hinzugefügt wird er der einzige', () {
      expect(WorkoutTags.add([], 'Gym'), ['Gym']);
    });

    test('Der Tag wird vor dem Hinzufügen normalisiert', () {
      expect(WorkoutTags.add(['Gym'], '  Kurz   hantel '), [
        'Gym',
        'Kurz hantel',
      ]);
    });

    test('Ein Tag, der sich nicht normalisieren lässt, ändert nichts', () {
      expect(WorkoutTags.add(['Gym'], ''), ['Gym']);
      expect(WorkoutTags.add(['Gym'], '   '), ['Gym']);
      expect(WorkoutTags.add(['Gym'], zeichen(21)), ['Gym']);
    });

    test('Wer schon da ist, wird nicht noch einmal aufgenommen', () {
      expect(WorkoutTags.add(['Gym'], 'Gym'), ['Gym']);
    });

    test('Der Vergleich ignoriert die Schreibweise', () {
      expect(WorkoutTags.add(['Gym'], 'gym'), ['Gym']);
      expect(WorkoutTags.add(['Gym'], 'GYM'), ['Gym']);
      expect(WorkoutTags.add(['gym'], 'Gym'), ['gym']);
    });

    test('Die zuerst geschriebene Schreibweise gewinnt', () {
      final tags = WorkoutTags.add(WorkoutTags.add([], 'Home'), 'HOME');
      expect(tags, ['Home']);
    });

    test('Der Vergleich gilt für den normalisierten Tag', () {
      // „ gym " wird zu „gym" und ist dann „Gym" schon.
      expect(WorkoutTags.add(['Gym'], '  gym '), ['Gym']);
    });

    test('Bis fünf Tags geht es, der fünfte ist noch erlaubt', () {
      var tags = <String>[];
      for (final tag in ['a1', 'a2', 'a3', 'a4', 'a5']) {
        tags = WorkoutTags.add(tags, tag);
      }
      expect(tags, ['a1', 'a2', 'a3', 'a4', 'a5']);
    });

    test('Beim sechsten Tag ändert sich nichts', () {
      expect(WorkoutTags.add(['a1', 'a2', 'a3', 'a4', 'a5'], 'a6'), [
        'a1',
        'a2',
        'a3',
        'a4',
        'a5',
      ]);
    });

    test('Die Eingabeliste wird nicht verändert', () {
      // Eine unveränderliche Liste darf kein Hindernis sein, und die
      // Eingabe bleibt, wie sie war: Es kommt eine **neue** Liste heraus.
      final eingabe = List<String>.unmodifiable(['Gym']);
      final ergebnis = WorkoutTags.add(eingabe, 'Home');
      expect(eingabe, ['Gym']);
      expect(ergebnis, ['Gym', 'Home']);
    });
  });

  // -------------------------------------------------------------------------
  group('suggestions', () {
    test('Ohne benutzte Tags gibt es nichts vorzuschlagen', () {
      expect(WorkoutTags.suggestions(used: {}, current: []), isEmpty);
      expect(WorkoutTags.suggestions(used: {}, current: ['Gym']), isEmpty);
    });

    test('Alle benutzten Tags werden vorgeschlagen, häufigster zuerst', () {
      expect(
        WorkoutTags.suggestions(
          used: {'Home': 1, 'Gym': 3, 'Hotel': 2},
          current: [],
        ),
        ['Gym', 'Hotel', 'Home'],
      );
    });

    test('Was schon am Training steht, wird nicht vorgeschlagen', () {
      expect(
        WorkoutTags.suggestions(used: {'Gym': 3, 'Home': 1}, current: ['Gym']),
        ['Home'],
      );
    });

    test('Der Abgleich mit dem Training ignoriert die Schreibweise', () {
      expect(
        WorkoutTags.suggestions(used: {'Gym': 3, 'Home': 1}, current: ['gym']),
        ['Home'],
      );
      expect(
        WorkoutTags.suggestions(used: {'gym': 3, 'Home': 1}, current: ['GYM']),
        ['Home'],
      );
    });

    test('Sind alle schon gesetzt, bleibt nichts', () {
      expect(
        WorkoutTags.suggestions(
          used: {'Gym': 3, 'Home': 1},
          current: ['Gym', 'Home'],
        ),
        isEmpty,
      );
    });

    test('Bei gleicher Häufigkeit entscheidet das Alphabet', () {
      expect(
        WorkoutTags.suggestions(
          used: {'Zuhause': 2, 'Arm': 2, 'Mitte': 2},
          current: [],
        ),
        ['Arm', 'Mitte', 'Zuhause'],
      );
    });

    test('Das Alphabet beachtet die Schreibweise nicht', () {
      // Nach Zeichencode käme „Beta" (B = 66) vor „alpha" (a = 97); ohne
      // Beachtung der Schreibweise kommt „alpha" zuerst.
      expect(
        WorkoutTags.suggestions(used: {'Beta': 1, 'alpha': 1}, current: []),
        ['alpha', 'Beta'],
      );
    });

    test('Die Häufigkeit geht dem Alphabet vor', () {
      expect(
        WorkoutTags.suggestions(used: {'Arm': 1, 'Zuhause': 5}, current: []),
        ['Zuhause', 'Arm'],
      );
    });

    test('Die Vorschläge tragen die Schreibweise aus `used`', () {
      expect(
        WorkoutTags.suggestions(used: {'KURZHANTEL': 2}, current: ['Gym']),
        ['KURZHANTEL'],
      );
    });

    test('Die Eingaben werden nicht verändert', () {
      final used = {'Gym': 3, 'Home': 1};
      final current = ['Gym'];
      WorkoutTags.suggestions(used: used, current: current);
      expect(used, {'Gym': 3, 'Home': 1});
      expect(current, ['Gym']);
    });
  });
}
