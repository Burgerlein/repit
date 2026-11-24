import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **VO₂max-Einordnung** aus Ticket #95 — `docs/SPEC.md` 4.7
/// („Einordnung für Männer 20–29: < 36 unterdurchschnittlich, < 42
/// durchschnittlich, < 48 gut, < 53 sehr gut, sonst hervorragend").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/VO2MaxRating.swift`;
/// die Grenzfälle stehen dort in `Tests/TrainingsCoreTests/RacePredictionTests.swift`
/// („Die Einordnung folgt den Grenzen der Spec").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// /// Einordnung für Männer 20–29 nach SPEC 4.7. Die Zahl der Watch ist
/// /// eine Schätzung mit mehreren Punkten Spielraum; aussagekräftig ist
/// /// der Trend. Die Namen sind Fachbegriffe, keine Nutzertexte — was der
/// /// Schirm daraus macht, entscheidet die View.
/// enum VO2MaxRating {
///   belowAverage, average, good, veryGood, excellent;
///
///   static VO2MaxRating rating(double vo2max);
/// }
/// ```
void main() {
  group('Die Einordnung folgt den Grenzen der Spec', () {
    test('unter 36 ist unterdurchschnittlich', () {
      expect(VO2MaxRating.rating(35.9), VO2MaxRating.belowAverage);
      expect(VO2MaxRating.rating(20), VO2MaxRating.belowAverage);
    });

    test('36 bis unter 42 ist durchschnittlich', () {
      expect(VO2MaxRating.rating(36), VO2MaxRating.average);
      expect(VO2MaxRating.rating(41.9), VO2MaxRating.average);
    });

    test('42 bis unter 48 ist gut', () {
      expect(VO2MaxRating.rating(42), VO2MaxRating.good);
      expect(VO2MaxRating.rating(47.9), VO2MaxRating.good);
    });

    test('48 bis unter 53 ist sehr gut', () {
      expect(VO2MaxRating.rating(48), VO2MaxRating.veryGood);
      expect(VO2MaxRating.rating(52.9), VO2MaxRating.veryGood);
    });

    test('ab 53 ist hervorragend', () {
      expect(VO2MaxRating.rating(53), VO2MaxRating.excellent);
      expect(VO2MaxRating.rating(70), VO2MaxRating.excellent);
    });
  });

  group('Die Grenze gehört zur oberen Stufe', () {
    // „< 36" heißt: genau 36 ist schon durchschnittlich. Wer hier `<=`
    // schreibt, verschiebt alle vier Grenzen um einen Messpunkt nach oben.
    test('jede Grenze fällt in die Stufe darüber, knapp darunter nicht', () {
      // `final`, nicht `const`: double-Schlüssel haben in Dart keine
      // primitive Gleichheit, eine const-Map verbietet sie.
      final boundaries = <double, (VO2MaxRating below, VO2MaxRating at)>{
        36: (VO2MaxRating.belowAverage, VO2MaxRating.average),
        42: (VO2MaxRating.average, VO2MaxRating.good),
        48: (VO2MaxRating.good, VO2MaxRating.veryGood),
        53: (VO2MaxRating.veryGood, VO2MaxRating.excellent),
      };
      boundaries.forEach((boundary, expected) {
        expect(
          VO2MaxRating.rating(boundary - 0.0001),
          expected.$1,
          reason: 'knapp unter $boundary',
        );
        expect(
          VO2MaxRating.rating(boundary),
          expected.$2,
          reason: 'genau $boundary',
        );
      });
    });
  });

  group('Es gibt genau fünf Stufen', () {
    test('die fünf Stufen der Spec, in aufsteigender Reihenfolge', () {
      expect(VO2MaxRating.values, [
        VO2MaxRating.belowAverage,
        VO2MaxRating.average,
        VO2MaxRating.good,
        VO2MaxRating.veryGood,
        VO2MaxRating.excellent,
      ]);
    });
  });
}
