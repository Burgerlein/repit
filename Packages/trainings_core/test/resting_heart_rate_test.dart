import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Ruhepuls als Grundlage der Zonenberechnung** aus Ticket
/// #95 — `docs/SPEC.md` 4.7 („… und Ruhepuls (Median der letzten 30 Werte
/// oder manuell)").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RestingHeartRate.swift`
/// samt `Tests/TrainingsCoreTests/RestingHeartRateTests.swift` — die
/// Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht"). Die Medianregel (Fenster 30, mindestens 5 Werte, bei gerader
/// Anzahl der obere der beiden mittleren) ist dieselbe wie in
/// `HealthMedian` — zwei Stellen der App sollen nicht verschieden runden.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// /// Woher der Wert stammt — die Oberfläche muss das benennen können.
/// /// Ein sealed-Typ, damit der switch vollständig prüfbar ist; der
/// /// Median trägt die Zahl der Werte, aus denen er entstand.
/// sealed class RestingHeartRateSource {
///   const RestingHeartRateSource();
/// }
///
/// final class RestingManual extends RestingHeartRateSource {
///   const RestingManual();
/// }
///
/// final class RestingMedian extends RestingHeartRateSource {
///   const RestingMedian(this.sampleCount);
///   final int sampleCount;
/// }
///
/// final class RestingEstimate extends RestingHeartRateSource {
///   const RestingEstimate();
/// }
///
/// // Alle drei vergleichen nach Wert (== und hashCode).
///
/// abstract final class RestingHeartRate {
///   /// Greift, solange zu wenige Messwerte vorliegen. Eine allgemeine
///   /// Annahme, kein Messwert — die Quelle [RestingEstimate] sagt das.
///   static const int fallbackBpm = 64;
///
///   /// [manual] gewinnt, wenn er gesetzt und > 0 ist. Sonst der Median
///   /// der letzten 30 Werte aus [recent] (jüngste am Ende, geschnitten
///   /// wird vorn), sofern mindestens 5 übrig bleiben — sonst
///   /// [fallbackBpm]. Bei gerader Anzahl gewinnt der obere der beiden
///   /// mittleren.
///   static (int bpm, RestingHeartRateSource source) value({
///     int? manual,
///     required List<int> recent,
///   });
/// }
/// ```
///
/// **Alle Pulswerte sind erfunden** — keine Messwerte von Tim.
void main() {
  group('Ein manuell gesetzter Wert hat Vorrang', () {
    test('manuell schlägt den Median', () {
      final r = RestingHeartRate.value(manual: 58, recent: [70, 71, 72, 73, 74]);
      expect(r.$1, 58);
      expect(r.$2, const RestingManual());
    });

    test('ein manueller Wert von 0 zählt nicht als gesetzt', () {
      final r = RestingHeartRate.value(manual: 0, recent: [60, 61, 62, 63, 90]);
      expect(r.$1, 62);
      expect(r.$2, const RestingMedian(5));
    });

    test('ein negativer manueller Wert zählt nicht als gesetzt', () {
      final r = RestingHeartRate.value(manual: -5, recent: []);
      expect(r.$1, RestingHeartRate.fallbackBpm);
      expect(r.$2, const RestingEstimate());
    });
  });

  group('Der Median der letzten Werte', () {
    test('ein Ausreißer verschiebt den Median nicht', () {
      final r = RestingHeartRate.value(manual: null, recent: [60, 61, 62, 63, 90]);
      expect(r.$1, 62);
      expect(r.$2, const RestingMedian(5));
    });

    test('die Eingabe muss nicht sortiert sein', () {
      final r = RestingHeartRate.value(manual: null, recent: [90, 62, 60, 63, 61]);
      expect(r.$1, 62);
    });

    test('bei gerader Anzahl gewinnt der obere der beiden mittleren', () {
      // Dieselbe Regel wie in HealthMedian: sorted[count ~/ 2].
      final r = RestingHeartRate.value(
        manual: null,
        recent: [60, 61, 62, 63, 64, 65],
      );
      expect(r.$1, 63);
      expect(r.$2, const RestingMedian(6));
    });

    test('nur die letzten 30 Werte zählen', () {
      // 31 Werte, der älteste (10) ist ein Ausreißer nach unten. Zählt nur
      // das Fenster 60…89, ist der Median 75 (oberer der beiden mittleren);
      // zählte der Ausreißer mit, wäre er 74.
      final recent = [10, ...List.generate(30, (i) => 60 + i)];
      final r = RestingHeartRate.value(manual: null, recent: recent);
      expect(r.$1, 75);
      expect(r.$2, const RestingMedian(30));
    });
  });

  group('Unter fünf Werten gilt der Rückfallwert', () {
    test('vier Werte reichen nicht', () {
      final r = RestingHeartRate.value(manual: null, recent: [60, 61, 62, 63]);
      expect(r.$1, 64);
      expect(r.$2, const RestingEstimate());
    });

    test('eine leere Liste fällt zurück', () {
      final r = RestingHeartRate.value(manual: null, recent: []);
      expect(r.$1, 64);
      expect(r.$2, const RestingEstimate());
    });

    test('genau fünf Werte reichen', () {
      final r = RestingHeartRate.value(manual: null, recent: [60, 61, 62, 63, 64]);
      expect(r.$1, 62);
      expect(r.$2, const RestingMedian(5));
    });

    test('der Rückfallwert ist als Konstante benannt', () {
      expect(RestingHeartRate.fallbackBpm, 64);
    });
  });

  group('Die Quelle vergleicht nach Wert', () {
    // Der Wert landet als Provider-Abhängigkeit in der App — ohne == wäre
    // jede neu gebaute Quelle ungleich der vorigen (`CLAUDE.md`,
    // Datenschicht).
    test('gleiche Quellen sind gleich', () {
      expect(const RestingManual() == RestingManual(), isTrue);
      expect(const RestingEstimate() == RestingEstimate(), isTrue);
      expect(const RestingMedian(5) == RestingMedian(5), isTrue);
      expect(
        const RestingMedian(5).hashCode,
        RestingMedian(5).hashCode,
      );
    });

    test('ein Median aus anderer Wertezahl ist eine andere Quelle', () {
      expect(const RestingMedian(5) == RestingMedian(30), isFalse);
    });
  });
}
