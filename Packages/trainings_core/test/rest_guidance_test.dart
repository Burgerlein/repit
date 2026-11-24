import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Pausenempfehlung** aus Ticket #91, Block B — API-Vorgabe
/// `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`.
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/RestGuidance.swift`
/// samt `Tests/TrainingsCoreTests/RestGuidanceTests.swift`.
///
/// **Die Zahlen sind abgeleitet, keine Spec-Zahlen.** `docs/SPEC.md` nennt
/// keine Pausenzeiten. Statt eine Tabelle zu erfinden, leitet sich die
/// Empfehlung aus dem Wiederholungsbereich ab, der ohnehin im Katalog
/// steht: wenige Wiederholungen heißt schwer heißt lange Pause. Wer die
/// Werte später ändern will, ändert eine Ableitung und keine Vorgabe — und
/// es ist eine **allgemeine Empfehlung**, keine ärztliche.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class RestGuidance {
///   static int seconds(Exercise exercise);
/// }
/// ```
///
/// Vier Stufen: Zeitübung 45 s, `repHigh` ≤ 10 → 150 s, ≤ 15 → 90 s,
/// darüber 60 s.
///
/// **Alle Zahlen hier sind erfunden**, soweit sie nicht aus dem Katalog
/// stammen; aus dem Katalog kommen nur die Fälle, die auch die
/// Swift-Vorlage dort holt.

/// Eine Übung, die nur für die Grenzfälle existiert. Alles außer `repHigh`
/// und `isTimed` ist für die Empfehlung ohne Belang.
Exercise _probe({required int repHigh, bool isTimed = false}) {
  return Exercise(
    id: 'probe$repHigh${isTimed ? 'Timed' : ''}',
    name: 'Prüfübung',
    sets: 3,
    repLow: 1,
    repHigh: repHigh,
    increment: 2.5,
    isTimed: isTimed,
    cue: 'Nur für den Test.',
    howTo: const ['Schritt eins', 'Schritt zwei', 'Schritt drei'],
    commonMistake: 'Keiner.',
    youTubeQuery: 'Prüfübung',
    muscles: const {Muscle.chest: 1.0},
  );
}

void main() {
  group('Die Stufen', () {
    test('schwere Übungen bekommen zweieinhalb Minuten', () {
      expect(RestGuidance.seconds(_probe(repHigh: 6)), 150);
      expect(RestGuidance.seconds(_probe(repHigh: 8)), 150);
    });

    test('mittlere Bereiche bekommen anderthalb Minuten', () {
      expect(RestGuidance.seconds(_probe(repHigh: 12)), 90);
    });

    test('hohe Wiederholungszahlen bekommen eine Minute', () {
      expect(RestGuidance.seconds(_probe(repHigh: 20)), 60);
      expect(RestGuidance.seconds(_probe(repHigh: 30)), 60);
    });

    test('zehn Wiederholungen liegen auf der schweren Stufe', () {
      // Die Grenze gehört zur schweren Stufe, nicht zur mittleren.
      expect(RestGuidance.seconds(_probe(repHigh: 10)), 150);
      expect(RestGuidance.seconds(_probe(repHigh: 11)), 90);
    });

    test('fünfzehn Wiederholungen liegen auf der mittleren Stufe', () {
      expect(RestGuidance.seconds(_probe(repHigh: 15)), 90);
      expect(RestGuidance.seconds(_probe(repHigh: 16)), 60);
    });

    test('es gibt genau vier Werte und keinen fünften', () {
      for (var repHigh = 1; repHigh <= 60; repHigh++) {
        final sekunden = RestGuidance.seconds(_probe(repHigh: repHigh));
        expect(
          sekunden,
          anyOf(45, 60, 90, 150),
          reason: 'repHigh $repHigh ergibt $sekunden s — keine der Stufen.',
        );
        expect(sekunden, greaterThan(0));
      }
    });
  });

  group('Zeitübungen', () {
    test('bekommen 45 Sekunden, egal wie hoch ihr Wert steht', () {
      // Die Reihenfolge der Bedingungen ist Teil der Regel: Bei einer
      // Zeitübung stehen in `repHigh` Sekunden und keine Wiederholungen.
      // Wer `isTimed` erst nach den Zahlen prüft, landet bei 45 Sekunden
      // Haltezeit in der Stufe „hohe Wiederholungszahl" und empfiehlt
      // 60 s — dieselbe Zahl in der falschen Einheit gelesen.
      expect(RestGuidance.seconds(_probe(repHigh: 45, isTimed: true)), 45);
      // Und andersherum: Eine kleine Zahl darf sie nicht in die schwere
      // Stufe ziehen.
      expect(RestGuidance.seconds(_probe(repHigh: 8, isTimed: true)), 45);
      expect(RestGuidance.seconds(_probe(repHigh: 12, isTimed: true)), 45);
      expect(RestGuidance.seconds(_probe(repHigh: 60, isTimed: true)), 45);
    });

    test('unterscheiden sich von einer Gewichtsübung mit gleichem repHigh', () {
      // Derselbe Zahlenwert, zwei verschiedene Empfehlungen — genau das
      // leistet die Prüfung auf `isTimed`.
      expect(RestGuidance.seconds(_probe(repHigh: 45, isTimed: true)), 45);
      expect(RestGuidance.seconds(_probe(repHigh: 45)), 60);
    });
  });

  // Diese Gruppe hängt bewusst am Katalog — so hält es auch die
  // Swift-Vorlage. Sie prüft nicht die Tabelle, sondern dass der Katalog
  // und die Tabelle zueinander passen: Eine Übung ohne Pause gäbe es
  // sonst erst auf dem Schirm zu sehen.
  group('Am Katalog', () {
    const beispiele = <(String, int)>[
      ('benchPress', 150),
      ('inclineDumbbellPress', 90),
      ('lateralRaise', 60),
      ('sidePlank', 45),
    ];

    for (final (id, erwartet) in beispiele) {
      test('$id bekommt $erwartet Sekunden', () {
        final uebung = ExerciseCatalog.all[id];
        expect(uebung, isNotNull, reason: '$id fehlt im Katalog.');
        expect(RestGuidance.seconds(uebung!), erwartet);
      });
    }

    test('der Seitstütz fällt nicht in die Gewichts-Stufen', () {
      // Der Fall, für den die Reihenfolge der Bedingungen gebaut ist: Der
      // Seitstütz hält 45 Sekunden, und 45 ist eine hohe Zahl.
      final plank = ExerciseCatalog.all['sidePlank'];
      expect(plank, isNotNull, reason: 'sidePlank fehlt im Katalog.');
      expect(plank!.isTimed, isTrue);
      expect(plank.repHigh, 45);
      expect(RestGuidance.seconds(plank), 45);
    });

    test('jede Übung des Katalogs bekommt eine Pause aus der Tabelle', () {
      for (final uebung in ExerciseCatalog.all.values) {
        final sekunden = RestGuidance.seconds(uebung);
        expect(sekunden, greaterThan(0), reason: '${uebung.id}: $sekunden s');
        expect(
          sekunden,
          anyOf(45, 60, 90, 150),
          reason: '${uebung.id}: $sekunden s ist keine der vier Stufen.',
        );
      }
    });
  });
}
