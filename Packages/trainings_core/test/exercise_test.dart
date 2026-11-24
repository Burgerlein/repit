import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Exercise`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Exercise.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block A“, `lib/src/exercise.dart`.
///
/// Zwei Dinge prüft diese Datei, die es in Swift gar nicht zu prüfen gab:
///
/// * **`==` und `hashCode`.** Swift bekommt sie synthetisiert, Dart nicht.
///   Ohne sie ist jede neu gebaute `Exercise` ungleich der vorigen, und jeder
///   abgeleitete Riverpod-Wert, der eine Übung als Abhängigkeit führt, rechnet
///   bei jedem Neubau neu — das wäre Fehler `03` im neuen Code
///   (`CLAUDE.md`, „Die Datenschicht“).
/// * **Die Kodierung der Such-URL.** `URLComponents` nimmt Swift ab, was in
///   Dart von Hand richtig sein muss: Leerzeichen und Umlaut gehören kodiert,
///   sonst zeigt der Link auf eine andere Suche als die, die dort steht.
///
/// Die Übungen hier sind **erfunden** und stehen so in keinem Katalog. Die
/// echten Werte prüft `exercise_catalog_test.dart`; hier geht es um das
/// Verhalten des Typs, nicht um Fachinhalt.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`).
void main() {
  /// Eine vollständig befüllte Übung. Jeder Test, der Ungleichheit zeigen
  /// will, ändert daran **genau ein** Feld — sonst beweist er nicht, welches
  /// Feld in `==` fehlt.
  Exercise probe({
    String id = 'probeUebung',
    String name = 'Probeübung',
    int sets = 3,
    int repLow = 8,
    int repHigh = 12,
    double increment = 2.5,
    bool isTimed = false,
    bool allowsAssist = false,
    String cue = 'Rücken gerade, ruhig atmen.',
    List<String> howTo = const [
      'Erster Schritt.',
      'Zweiter Schritt.',
      'Dritter Schritt.',
    ],
    String commonMistake = 'Mit Schwung arbeiten.',
    String youTubeQuery = 'Probeübung Technik',
    Map<Muscle, double> muscles = const {Muscle.chest: 1.0},
  }) => Exercise(
    id: id,
    name: name,
    sets: sets,
    repLow: repLow,
    repHigh: repHigh,
    increment: increment,
    isTimed: isTimed,
    allowsAssist: allowsAssist,
    cue: cue,
    howTo: howTo,
    commonMistake: commonMistake,
    youTubeQuery: youTubeQuery,
    muscles: muscles,
  );

  group('Die Übung reicht durch, was man ihr gibt', () {
    test('Jedes Feld kommt unverändert wieder heraus', () {
      final e = probe();
      expect(e.id, 'probeUebung');
      expect(e.name, 'Probeübung');
      expect(e.sets, 3);
      expect(e.repLow, 8);
      expect(e.repHigh, 12);
      expect(e.increment, 2.5);
      expect(e.isTimed, isFalse);
      expect(e.allowsAssist, isFalse);
      expect(e.cue, 'Rücken gerade, ruhig atmen.');
      expect(e.howTo, [
        'Erster Schritt.',
        'Zweiter Schritt.',
        'Dritter Schritt.',
      ]);
      expect(e.commonMistake, 'Mit Schwung arbeiten.');
      expect(e.youTubeQuery, 'Probeübung Technik');
      expect(e.muscles, {Muscle.chest: 1.0});
    });

    test('Zeitübung und Unterstützung sind standardmäßig aus', () {
      // Beides sind Ausnahmen: genau eine Zeitübung und genau zwei Übungen
      // mit Unterstützung im ganzen Katalog. Der Standard muss deshalb der
      // Normalfall sein, sonst trägt jede Übung die Ausnahme.
      final e = Exercise(
        id: 'ohneSchalter',
        name: 'Ohne Schalter',
        sets: 3,
        repLow: 8,
        repHigh: 12,
        increment: 2.5,
        cue: 'Hinweis.',
        howTo: const ['Eins.', 'Zwei.', 'Drei.'],
        commonMistake: 'Fehler.',
        youTubeQuery: 'Suche',
        muscles: const {Muscle.core: 1.0},
      );
      expect(e.isTimed, isFalse);
      expect(e.allowsAssist, isFalse);
    });

    test('Die Gewichtung der Muskeln bleibt eine Zahl, kein Ja/Nein', () {
      // 1,0 ist der Hauptmuskel, 0,5 eine Nebenbelastung. Wer daraus
      // „trainiert ja/nein“ macht, zerstört die Rechnung der Muskelkarte,
      // und es fällt erst dort auf.
      final e = probe(
        muscles: const {
          Muscle.chest: 1.0,
          Muscle.frontDelt: 0.5,
          Muscle.triceps: 0.5,
        },
      );
      expect(e.muscles[Muscle.chest], 1.0);
      expect(e.muscles[Muscle.frontDelt], 0.5);
      expect(e.muscles[Muscle.triceps], 0.5);
      expect(e.muscles[Muscle.lats], isNull);
    });
  });

  group('Die YouTube-Adresse ist eine Suche, keine Einbettung', () {
    test('Sie zeigt auf die Trefferseite von YouTube', () {
      // Die App bettet nichts ein, sie öffnet nur — das steht so in der
      // Swift-Quelle und bleibt so.
      final url = probe(youTubeQuery: 'Seitheben Technik').youTubeSearchUrl;
      expect(url.scheme, 'https');
      expect(url.host, 'www.youtube.com');
      expect(url.path, '/results');
    });

    test('Sie bettet kein Video ein', () {
      final url = probe(youTubeQuery: 'Seitheben Technik').youTubeSearchUrl;
      expect(url.toString().contains('/embed/'), isFalse);
      expect(url.toString().contains('watch?v='), isFalse);
      expect(url.toString().contains('youtu.be'), isFalse);
    });

    test('Der Suchbegriff steht unter search_query', () {
      final url = probe(youTubeQuery: 'Seitheben Technik').youTubeSearchUrl;
      expect(url.queryParameters['search_query'], 'Seitheben Technik');
      expect(url.queryParameters.keys, ['search_query']);
    });

    test('Leerzeichen und Umlaut kommen kodiert in der Adresse an', () {
      // Genau hier geht es beim Portieren schief: Ein rohes Leerzeichen oder
      // ein rohes „ü“ in der Adresse ergibt entweder eine kaputte URL oder
      // eine andere Suche als die, die danebensteht.
      const suchbegriff = 'Bankdrücken Technik Anleitung';
      final url = probe(youTubeQuery: suchbegriff).youTubeSearchUrl;

      expect(
        url.toString().contains(' '),
        isFalse,
        reason: 'rohes Leerzeichen in ${url.toString()}',
      );
      expect(
        url.toString().contains('ü'),
        isFalse,
        reason: 'roher Umlaut in ${url.toString()}',
      );

      // Egal ob das Leerzeichen als `+` oder als `%20` kodiert wird: Was
      // ankommt, muss wieder der Suchbegriff sein.
      expect(url.queryParameters['search_query'], suchbegriff);
      expect(
        Uri.parse(url.toString()).queryParameters['search_query'],
        suchbegriff,
      );
    });

    test('Auch ein großes Ü am Wortanfang übersteht den Weg', () {
      // „Überzüge am Kabel gestreckte Arme Latissimus“ ist der Suchbegriff
      // einer echten Übung; hier nur das Zeichen, nicht der Katalogeintrag.
      const suchbegriff = 'Überzüge am Kabel gestreckte Arme Latissimus';
      final url = probe(youTubeQuery: suchbegriff).youTubeSearchUrl;
      expect(url.queryParameters['search_query'], suchbegriff);
      expect(url.toString().contains('Ü'), isFalse);
    });

    test('Ein Kaufmanns-Und im Suchbegriff erzeugt kein zweites Feld', () {
      // Unkodiert würde aus einem Suchbegriff eine zweite Angabe in der
      // Adresse — und die Suche wäre eine andere als die angezeigte.
      const suchbegriff = 'Rudern & Latziehen';
      final url = probe(youTubeQuery: suchbegriff).youTubeSearchUrl;
      expect(url.queryParameters.keys, ['search_query']);
      expect(url.queryParameters['search_query'], suchbegriff);
    });

    test('Jede Übung des Katalogs bekommt eine auflösbare Adresse', () {
      for (final e in ExerciseCatalog.all.values) {
        final url = e.youTubeSearchUrl;
        expect(url.host, 'www.youtube.com', reason: e.id);
        expect(url.path, '/results', reason: e.id);
        expect(
          url.queryParameters['search_query'],
          e.youTubeQuery,
          reason: '${e.id}: Suchbegriff kommt nicht heil an',
        );
        expect(
          url.toString().contains(' '),
          isFalse,
          reason: '${e.id}: rohes Leerzeichen in der Adresse',
        );
      }
    });
  });

  group('Zwei gleich befüllte Übungen sind gleich', () {
    test('Gleicher Inhalt heißt gleich, auch über Liste und Map hinweg', () {
      // Die beiden Exemplare teilen keine Liste und keine Map — die
      // Gleichheit muss inhaltlich entschieden werden, nicht über die
      // Identität der Sammlungen.
      final a = probe(
        howTo: ['Eins.', 'Zwei.', 'Drei.'],
        muscles: {Muscle.chest: 1.0, Muscle.triceps: 0.5},
      );
      final b = probe(
        howTo: ['Eins.', 'Zwei.', 'Drei.'],
        muscles: {Muscle.chest: 1.0, Muscle.triceps: 0.5},
      );
      expect(identical(a, b), isFalse, reason: 'sonst beweist der Test nichts');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Die Reihenfolge in der Muskel-Map entscheidet nicht', () {
      // Eine Map ist ungeordnet. Zwei gleich befüllte Zuordnungen in
      // anderer Schreibreihenfolge sind dieselbe Zuordnung.
      final a = probe(muscles: {Muscle.chest: 1.0, Muscle.triceps: 0.5});
      final b = probe(muscles: {Muscle.triceps: 0.5, Muscle.chest: 1.0});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('Eine andere Muskelgewichtung macht die Übung ungleich', () {
      // Der Fall, auf den es ankommt: 0,5 statt 1,0 ist für die Muskelkarte
      // ein anderer Wert. Bliebe die Übung gleich, bekäme die Karte die
      // Änderung nie zu sehen.
      final a = probe(muscles: {Muscle.chest: 1.0, Muscle.triceps: 0.5});
      final b = probe(muscles: {Muscle.chest: 1.0, Muscle.triceps: 1.0});
      expect(a, isNot(b));
    });

    test('Ein zusätzlicher Nebenmuskel macht die Übung ungleich', () {
      final a = probe(muscles: {Muscle.chest: 1.0});
      final b = probe(muscles: {Muscle.chest: 1.0, Muscle.frontDelt: 0.5});
      expect(a, isNot(b));
    });

    test('Ein anderer Muskel bei gleichem Gewicht macht sie ungleich', () {
      final a = probe(muscles: {Muscle.chest: 1.0});
      final b = probe(muscles: {Muscle.lats: 1.0});
      expect(a, isNot(b));
    });

    test('Andere Schritte in der Anleitung machen die Übung ungleich', () {
      final a = probe(howTo: ['Eins.', 'Zwei.', 'Drei.']);
      final b = probe(howTo: ['Eins.', 'Zwei.', 'Vier.']);
      expect(a, isNot(b));
    });

    test('Dieselben Schritte in anderer Reihenfolge sind nicht dieselbe '
        'Anleitung', () {
      // Anders als die Muskel-Map ist `howTo` eine Reihenfolge: Schritt 1
      // kommt vor Schritt 2.
      final a = probe(howTo: ['Eins.', 'Zwei.', 'Drei.']);
      final b = probe(howTo: ['Drei.', 'Zwei.', 'Eins.']);
      expect(a, isNot(b));
    });

    test('Jedes einzelne Feld trägt zur Gleichheit bei', () {
      final basis = probe();
      final abweichungen = <String, Exercise>{
        'id': probe(id: 'andereId'),
        'name': probe(name: 'Anderer Name'),
        'sets': probe(sets: 4),
        'repLow': probe(repLow: 6),
        'repHigh': probe(repHigh: 15),
        'increment': probe(increment: 5),
        'isTimed': probe(isTimed: true),
        'allowsAssist': probe(allowsAssist: true),
        'cue': probe(cue: 'Anderer Hinweis.'),
        'commonMistake': probe(commonMistake: 'Anderer Fehler.'),
        'youTubeQuery': probe(youTubeQuery: 'Andere Suche'),
      };
      abweichungen.forEach((feld, abweichend) {
        expect(basis, isNot(abweichend), reason: '$feld geht in == nicht ein');
      });
    });

    test('Eine Übung ist sich selbst gleich und bleibt es', () {
      final e = probe();
      expect(e, e);
      expect(e.hashCode, e.hashCode);
    });

    test('Gleiche Übungen fallen in einer Menge zusammen', () {
      // Der praktische Grund für `hashCode`: Ohne ihn stünden zwei gleiche
      // Übungen zweimal in derselben Menge.
      final menge = {probe(), probe(), probe(id: 'andereId')};
      expect(menge, hasLength(2));
    });
  });
}
