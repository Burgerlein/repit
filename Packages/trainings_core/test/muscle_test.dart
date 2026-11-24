import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Muscle`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Muscle.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block A“.
///
/// **Die Zielbereiche sind allgemeine Richtwerte für Muskelaufbau, keine
/// ärztliche Vorgabe.** Sie stammen aus `docs/SPEC.md` 4.4 und gelten für
/// einen Plan mit Schwerpunkt Oberkörper und Arme; die Beine stehen
/// niedriger, weil sie zusätzlich durchs Laufen belastet werden. Wer sie
/// ändert, ändert die Muskelkarte, nicht eine Empfehlung an den Nutzer.
///
/// **Bewusste Abweichung von Swift** (Spec, Punkt 2 und 3):
/// `ClosedRange<Double>` wird zum Record `({double low, double high})`, und
/// `rawValue` heißt `code`. Beides prüfen die Tests unten ausdrücklich mit.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`, „Wer
/// Tests schreibt, schreibt nicht die Implementierung“).
void main() {
  group('Die Muskelgruppen der Muskelkarte', () {
    test('Es sind genau 16, keiner mehr und keiner weniger', () {
      // Die Zahl steht in der Spec. Ein siebzehnter Muskel wäre eine
      // fachliche Entscheidung und keine Portierung — und die Muskelkarte
      // rechnet mit genau dieser Menge.
      expect(Muscle.values, hasLength(16));
    });

    test('Die Reihenfolge ist die der Spec', () {
      // Die Reihenfolge der Fälle ist keine Zierde: `Muscle.values` ist die
      // natürliche Sortierung überall dort, wo die Karte nicht nach Bedarf
      // sortiert.
      expect(Muscle.values, [
        Muscle.chest,
        Muscle.frontDelt,
        Muscle.sideDelt,
        Muscle.rearDelt,
        Muscle.biceps,
        Muscle.triceps,
        Muscle.forearms,
        Muscle.upperBack,
        Muscle.lats,
        Muscle.lowerBack,
        Muscle.core,
        Muscle.glutes,
        Muscle.quads,
        Muscle.hamstrings,
        Muscle.calves,
        Muscle.tibialis,
      ]);
    });

    test('Kein Muskel steht zweimal in der Liste', () {
      expect(Muscle.values.toSet(), hasLength(Muscle.values.length));
    });
  });

  group('Der Code ist der Persistenzschlüssel', () {
    // Der Code steht in gespeicherten Daten und im Dashboard-Export. Wer ihn
    // ändert, macht alte Zuordnungen namenlos — deshalb steht jeder einzeln
    // hier und nicht als Schleife über `name`.
    test('Jeder Muskel trägt den Code aus der Swift-Quelle', () {
      expect(Muscle.chest.code, 'chest');
      expect(Muscle.frontDelt.code, 'frontDelt');
      expect(Muscle.sideDelt.code, 'sideDelt');
      expect(Muscle.rearDelt.code, 'rearDelt');
      expect(Muscle.biceps.code, 'biceps');
      expect(Muscle.triceps.code, 'triceps');
      expect(Muscle.forearms.code, 'forearms');
      expect(Muscle.upperBack.code, 'upperBack');
      expect(Muscle.lats.code, 'lats');
      expect(Muscle.lowerBack.code, 'lowerBack');
      expect(Muscle.core.code, 'core');
      expect(Muscle.glutes.code, 'glutes');
      expect(Muscle.quads.code, 'quads');
      expect(Muscle.hamstrings.code, 'hamstrings');
      expect(Muscle.calves.code, 'calves');
      expect(Muscle.tibialis.code, 'tibialis');
    });

    test('Kein Code kommt zweimal vor', () {
      final codes = Muscle.values.map((m) => m.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('Jeder Code findet seinen Muskel wieder', () {
      // Die Entsprechung zu Swifts `Muscle(rawValue:)`. Ohne eindeutige
      // Rückrichtung wäre der Code als Schlüssel wertlos.
      for (final muscle in Muscle.values) {
        final gefunden = Muscle.values
            .where((m) => m.code == muscle.code)
            .toList();
        expect(gefunden, [muscle]);
      }
    });

    test('Kein Code ist leer', () {
      for (final muscle in Muscle.values) {
        expect(muscle.code, isNotEmpty, reason: '$muscle: kein Code');
      }
    });
  });

  group('Die deutschen Namen stehen in der Oberfläche', () {
    test('Jeder Muskel trägt den Namen aus der Swift-Quelle', () {
      expect(Muscle.chest.german, 'Brust');
      expect(Muscle.frontDelt.german, 'Vordere Schulter');
      expect(Muscle.sideDelt.german, 'Seitliche Schulter');
      expect(Muscle.rearDelt.german, 'Hintere Schulter');
      expect(Muscle.biceps.german, 'Bizeps');
      expect(Muscle.triceps.german, 'Trizeps');
      expect(Muscle.forearms.german, 'Unterarme');
      expect(Muscle.upperBack.german, 'Oberer Rücken');
      expect(Muscle.lats.german, 'Latissimus');
      expect(Muscle.lowerBack.german, 'Unterer Rücken');
      expect(Muscle.core.german, 'Rumpf');
      expect(Muscle.glutes.german, 'Gesäß');
      expect(Muscle.quads.german, 'Oberschenkel vorne');
      expect(Muscle.hamstrings.german, 'Oberschenkel hinten');
      expect(Muscle.calves.german, 'Waden');
      expect(Muscle.tibialis.german, 'Schienbein');
    });

    test('Kein Name ist leer', () {
      for (final muscle in Muscle.values) {
        expect(muscle.german, isNotEmpty, reason: '$muscle: kein Name');
      }
    });

    test('Zwei Muskeln heißen nie gleich', () {
      // Auf der Muskelkarte stehen alle 16 nebeneinander. Zwei gleiche Namen
      // wären dort zwei Zeilen, die sich nicht unterscheiden lassen.
      final namen = Muscle.values.map((m) => m.german).toList();
      expect(namen.toSet(), hasLength(namen.length));
    });
  });

  group('Die Zielbereiche sind allgemeine Richtwerte, keine Vorgabe', () {
    test('Jeder Muskel trägt den Bereich aus der Spec', () {
      // Harte Sätze pro Woche. Die Gruppen aus `Muscle.swift` einzeln
      // ausgeschrieben, damit ein verschobener Fall auffällt und nicht nur
      // eine verschobene Gruppengrenze.
      expect(Muscle.chest.target, (low: 10.0, high: 20.0));
      expect(Muscle.sideDelt.target, (low: 10.0, high: 20.0));
      expect(Muscle.biceps.target, (low: 10.0, high: 20.0));
      expect(Muscle.triceps.target, (low: 10.0, high: 20.0));
      expect(Muscle.lats.target, (low: 10.0, high: 20.0));

      expect(Muscle.upperBack.target, (low: 8.0, high: 16.0));
      expect(Muscle.rearDelt.target, (low: 6.0, high: 14.0));
      expect(Muscle.frontDelt.target, (low: 4.0, high: 12.0));

      expect(Muscle.forearms.target, (low: 4.0, high: 10.0));
      expect(Muscle.core.target, (low: 4.0, high: 10.0));
      expect(Muscle.tibialis.target, (low: 4.0, high: 10.0));

      // Die Beine stehen niedriger, weil sie zusätzlich durchs Laufen
      // belastet werden — das ist der Grund, nicht ein Tippfehler.
      expect(Muscle.glutes.target, (low: 6.0, high: 12.0));
      expect(Muscle.quads.target, (low: 6.0, high: 12.0));
      expect(Muscle.hamstrings.target, (low: 6.0, high: 12.0));

      expect(Muscle.calves.target, (low: 6.0, high: 14.0));
      expect(Muscle.lowerBack.target, (low: 2.0, high: 8.0));
    });

    test('Die Untergrenze liegt immer unter der Obergrenze', () {
      for (final muscle in Muscle.values) {
        expect(
          muscle.target.low,
          lessThan(muscle.target.high),
          reason:
              '${muscle.code}: '
              '${muscle.target.low}–${muscle.target.high}',
        );
      }
    });

    test('Kein Zielbereich beginnt bei null oder darunter', () {
      // Ein Ziel von 0 hieße „dieser Muskel braucht nichts“, und die
      // Muskelkarte teilte durch den Bereich.
      for (final muscle in Muscle.values) {
        expect(
          muscle.target.low,
          greaterThan(0),
          reason: '${muscle.code}: Untergrenze ${muscle.target.low}',
        );
      }
    });

    test('Der Zielbereich ist ein Record mit low und high, kein Paar', () {
      // Spec, bewusste Abweichung 2: `ClosedRange<Double>` wird zum Record
      // `({double low, double high})`. Der statische Typ wird hier
      // festgeschrieben, damit niemand daraus eine Klasse oder eine Liste
      // macht — die Aufrufstellen schreiben `target.low`.
      for (final muscle in Muscle.values) {
        expect(
          muscle.target,
          isA<({double low, double high})>(),
          reason: '${muscle.code}: kein Record (low, high)',
        );
      }
    });
  });
}
