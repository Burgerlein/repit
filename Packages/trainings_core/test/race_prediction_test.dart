import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **HM-Prognose** aus Ticket #95 — `docs/SPEC.md` 4.7
/// („HM-Prognose über die Daniels-VDOT-Tabelle … linear interpolieren.
/// Zweite, realistische Zahl für Einsteiger = Potenzial × 1,12").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/RacePrediction.swift`
/// samt `Tests/TrainingsCoreTests/RacePredictionTests.swift` — die Doppelung
/// Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist Absicht").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class RacePrediction {
///   /// Die Laufökonomie macht bei Einsteigern einen großen Unterschied —
///   /// die zweite, ehrlichere Zahl neben dem Potenzial.
///   static const double beginnerFactor = 1.12;
///
///   /// Theoretisches Potenzial in Minuten. Zwischen den Stützstellen der
///   /// Tabelle wird linear interpoliert; **außerhalb gelten die Randwerte**
///   /// (Swift-Vorlage: eine fortgesetzte Gerade ergäbe irgendwann negative
///   /// Laufzeiten, und belegt ist die Tabelle dort ohnehin nicht).
///   static double halfMarathonMinutes({required double vdot});
///
///   /// Potenzial × [beginnerFactor].
///   static double realisticMinutes({required double vdot});
/// }
/// ```
///
/// **Alle Zahlen sind Stützstellen der Daniels-Tabelle aus SPEC 4.7** oder
/// daraus gerechnet — keine Trainingsdaten.
void main() {
  group('Stützstellen der Tabelle werden genau getroffen', () {
    // Die vollständige Tabelle aus SPEC 4.7, VDOT → HM-Minuten.
    // `final`, nicht `const`: double-Schlüssel haben in Dart keine
    // primitive Gleichheit, eine const-Map verbietet sie.
    final table = <double, double>{
      30: 141.1,
      32: 133.8,
      34: 127.3,
      36: 121.3,
      38: 115.9,
      40: 111.0,
      42: 106.5,
      44: 102.3,
      46: 98.5,
      48: 94.9,
      50: 91.6,
      52: 88.6,
      54: 85.8,
      56: 83.2,
      58: 80.7,
      60: 78.4,
    };

    test('alle sechzehn Stützstellen aus SPEC 4.7', () {
      table.forEach((vdot, minutes) {
        expect(
          RacePrediction.halfMarathonMinutes(vdot: vdot),
          minutes,
          reason: 'VDOT $vdot muss exakt $minutes min ergeben',
        );
      });
    });
  });

  group('Zwischen den Stützstellen wird linear interpoliert', () {
    test('die Mitte zwischen 40 (111,0) und 42 (106,5) ist 108,75', () {
      expect(
        RacePrediction.halfMarathonMinutes(vdot: 41),
        closeTo(108.75, 0.001),
      );
    });

    test('ein Viertel über 38 (115,9) Richtung 40 (111,0) ist 114,675', () {
      // 115,9 − 0,25 · 4,9 = 114,675
      expect(
        RacePrediction.halfMarathonMinutes(vdot: 38.5),
        closeTo(114.675, 0.001),
      );
    });
  });

  group('Monotonie', () {
    test('eine höhere VO₂max ergibt nie eine langsamere Zeit', () {
      var previous = double.infinity;
      for (var vdot = 28.0; vdot <= 62.0; vdot += 0.5) {
        final minutes = RacePrediction.halfMarathonMinutes(vdot: vdot);
        expect(
          minutes,
          lessThanOrEqualTo(previous),
          reason: 'VDOT $vdot: $minutes min ist langsamer als der '
              'Wert davor ($previous min)',
        );
        previous = minutes;
      }
    });
  });

  group('Außerhalb der Tabelle gelten die Randwerte', () {
    // Eine fortgesetzte Gerade ergäbe irgendwann negative Laufzeiten — und
    // belegt ist die Tabelle dort ohnehin nicht (Swift-Vorlage).
    test('unterhalb von VDOT 30 gilt der untere Randwert', () {
      expect(RacePrediction.halfMarathonMinutes(vdot: 10), 141.1);
      expect(RacePrediction.halfMarathonMinutes(vdot: 0), 141.1);
    });

    test('oberhalb von VDOT 60 gilt der obere Randwert', () {
      expect(RacePrediction.halfMarathonMinutes(vdot: 99), 78.4);
    });
  });

  group('Die realistische Zeit', () {
    test('ist das Potenzial mal 1,12', () {
      final potential = RacePrediction.halfMarathonMinutes(vdot: 39.2);
      final realistic = RacePrediction.realisticMinutes(vdot: 39.2);
      expect(realistic, closeTo(potential * 1.12, 0.001));
      expect(realistic, greaterThan(potential));
    });

    test('der Faktor ist als Konstante benannt', () {
      expect(RacePrediction.beginnerFactor, 1.12);
    });

    test('klemmt außerhalb der Tabelle genauso wie das Potenzial', () {
      expect(
        RacePrediction.realisticMinutes(vdot: 10),
        closeTo(141.1 * 1.12, 0.001),
      );
    });
  });
}
