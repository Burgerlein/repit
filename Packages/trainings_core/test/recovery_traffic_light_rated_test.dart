import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`RecoveryEvaluation.rated`** — Stufe 1 von #261, Spec
/// `docs/superpowers/specs/2026-11-03-erholung-tageswechsel.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Zum Zeitpunkt dieser Datei gibt es `rated` nicht; der Lauf ist rot, und
/// das ist der erwartete Zustand. Diese Datei darf ausgeführt, nie verändert
/// werden.
///
/// ## Warum es `rated` gibt
///
/// `HealthMedian` bildet unter fünf Werten keinen Median
/// (`health_median.dart`). Für die ältesten Tage des Rechenfensters gibt es
/// deshalb gar keinen. Die Kette dahinter malt **grün**: kein Median → kein
/// Vergleich → kein Warnsignal → Verdikt `calm` → vier grüne Viertel.
/// „Alles im Normalbereich", eine Aussage, die niemand gemacht hat.
///
/// Solange der Schirm nur heute zeigt, tritt der Fall nicht auf. Mit dem
/// Tageswechsel schon — und dann ist es `0` als Antwort auf „kein Wert",
/// eine Ebene tiefer, als `Messwert<T>` es sehen kann.
///
/// `rated` sind die Metriken, über die die Ampel überhaupt **eine Aussage
/// gemacht** hat:
///
/// - **Schlaf**: beurteilt, sobald ein Wert vorliegt — die
///   Sechs-Stunden-Grenze steht fest und braucht keinen Median.
/// - **Ruhepuls, HRV, Atemfrequenz**: beurteilt nur, wenn **Wert und
///   Median** vorliegen.
///
/// Es gilt `signals ⊆ rated`.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class RecoveryEvaluation {
///   const RecoveryEvaluation({
///     required RecoveryVerdict verdict,
///     required List<RecoveryMetric> signals,
///     required int measuredCount,
///     List<RecoveryMetric> rated = const [],   // neu, mit Vorgabewert
///   });
///   final List<RecoveryMetric> rated;
///   // ==, hashCode und toString ziehen mit.
/// }
/// ```
///
/// ## Entscheidungen dieser Testdatei
///
/// - **`rated` steht in der Reihenfolge von `RecoveryMetric`**, genau wie
///   `signals`. Die Reihenfolge ist Vertrag: Die vier Viertel des
///   Erholungsrings werden in ihr gezeichnet, und ein Viertel ohne `rated`
///   wird grau. Eine andere Reihenfolge färbte das falsche Viertel.
/// - **Der Fall `postOperative` wird hier nicht festgenagelt.** Die Spec
///   sagt „`evaluate` füllt es immer", sagt aber nicht, ob eine ruhende
///   Ampel etwas beurteilt hat. Das ist gemeldet, nicht stillschweigend
///   entschieden.
///
/// **Alle Zahlen sind erfunden** und bewusst rund.
void main() {
  /// Ein vollständiger Normalbereich — alle vier Mediane liegen vor.
  const vollerMedian = RecoveryBaseline(
    sleepHours: 7,
    restingHeartRate: 50,
    hrv: 70,
    respiratoryRate: 13.5,
  );

  /// Vier unauffällige Werte dazu: keiner reißt eine Schwelle.
  const ruhigeWerte = RecoveryReading(
    sleepHours: 7.5,
    restingHeartRate: 52,
    hrv: 60,
    respiratoryRate: 14,
  );

  group('Der Vorgabewert', () {
    test('eine Auswertung ohne rated trägt die leere Liste', () {
      // Vorgabewert `const []`, damit bestehende Konstruktionen übersetzen.
      const auswertung = RecoveryEvaluation(
        verdict: RecoveryVerdict.calm,
        signals: [],
        measuredCount: 0,
      );

      expect(auswertung.rated, isEmpty);
    });
  });

  group('Was beurteilt wurde', () {
    test('mit allen vier Medianen sind alle vier beurteilt', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: ruhigeWerte,
        baseline: vollerMedian,
      );

      expect(auswertung.rated, [
        RecoveryMetric.sleep,
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
      expect(auswertung.signals, isEmpty);
      expect(auswertung.verdict, RecoveryVerdict.calm);
      // Das ist das ehrliche Grün: vier Werte, vier Mediane, kein Signal.
    });

    test('ohne jeden Median bleibt nur der Schlaf beurteilt', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: ruhigeWerte,
        baseline: const RecoveryBaseline(),
      );

      expect(auswertung.rated, [RecoveryMetric.sleep]);
      expect(auswertung.signals, isEmpty);
      expect(auswertung.measuredCount, 4);
      // Dasselbe `calm` wie oben, dieselben null Signale — und etwas ganz
      // anderes. Ohne `rated` wäre das auf dem Ring nicht zu unterscheiden.
      expect(auswertung.verdict, RecoveryVerdict.calm);
      expect(auswertung.rated, isNot(hasLength(4)));
    });

    test('ein fehlender Median schaltet nur seine eigene Metrik ab', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: ruhigeWerte,
        baseline: const RecoveryBaseline(hrv: 70),
      );

      expect(auswertung.rated, [RecoveryMetric.sleep, RecoveryMetric.hrv]);
      expect(
        auswertung.rated,
        isNot(contains(RecoveryMetric.restingHeartRate)),
      );
      expect(auswertung.rated, isNot(contains(RecoveryMetric.respiratoryRate)));
    });

    test('der Schlaf braucht keinen Median, nur einen Wert', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(sleepHours: 7.5),
        baseline: const RecoveryBaseline(),
      );

      expect(auswertung.rated, [RecoveryMetric.sleep]);
    });

    test('ohne Schlafwert ist der Schlaf nicht beurteilt', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(
          restingHeartRate: 52,
          hrv: 60,
          respiratoryRate: 14,
        ),
        baseline: vollerMedian,
      );

      expect(auswertung.rated, [
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
    });

    test('ein Wert ohne Median ist nicht beurteilt, auch wenn er auffiele', () {
      // HRV 10 wäre gegen jeden plausiblen Median ein Warnsignal — ohne
      // Median ist sie trotzdem keines. Eine Schwelle aus zwei Werten wäre
      // eine Behauptung.
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(hrv: 10),
        baseline: const RecoveryBaseline(),
      );

      expect(auswertung.rated, isEmpty);
      expect(auswertung.signals, isEmpty);
      expect(auswertung.measuredCount, 1);
    });

    test('liegt gar nichts vor, ist auch nichts beurteilt', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(),
        baseline: vollerMedian,
      );

      expect(auswertung.verdict, RecoveryVerdict.noData);
      expect(auswertung.measuredCount, 0);
      expect(auswertung.rated, isEmpty);
    });
  });

  group('signals ist eine Teilmenge von rated', () {
    test('vier Warnsignale stehen auf vier beurteilten Metriken', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(
          sleepHours: 5, // < 6
          restingHeartRate: 58, // >= 50 + 5
          hrv: 50, // <= 70 * 0,8
          respiratoryRate: 16, // >= 13,5 + 1,5
        ),
        baseline: vollerMedian,
      );

      expect(auswertung.verdict, RecoveryVerdict.stressed);
      expect(auswertung.signals, [
        RecoveryMetric.sleep,
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
      expect(auswertung.rated, auswertung.signals);
    });

    test('ein Signal ohne Grundlage gibt es nicht', () {
      final auswertung = RecoveryTrafficLight.evaluate(
        reading: const RecoveryReading(sleepHours: 5, hrv: 10),
        baseline: const RecoveryBaseline(),
      );

      expect(auswertung.signals, [RecoveryMetric.sleep]);
      for (final signal in auswertung.signals) {
        expect(auswertung.rated, contains(signal));
      }
    });
  });

  group('Wertgleichheit zieht mit', () {
    const grundlage = RecoveryEvaluation(
      verdict: RecoveryVerdict.calm,
      signals: [],
      measuredCount: 4,
      rated: [RecoveryMetric.sleep],
    );

    test('zwei Auswertungen, die sich nur in rated unterscheiden, sind '
        'ungleich', () {
      const vier = RecoveryEvaluation(
        verdict: RecoveryVerdict.calm,
        signals: [],
        measuredCount: 4,
        rated: [
          RecoveryMetric.sleep,
          RecoveryMetric.restingHeartRate,
          RecoveryMetric.hrv,
          RecoveryMetric.respiratoryRate,
        ],
      );

      expect(grundlage, isNot(vier));
      // Ein Werttyp, der Abhängigkeit eines Providers ist, braucht `==` und
      // `hashCode` — sonst läuft jeder abgeleitete Wert je Bild neu
      // (`CLAUDE.md`, Fehler `03`).
      expect(grundlage.hashCode, isNot(vier.hashCode));
    });

    test('zwei gleiche Auswertungen sind gleich', () {
      const gleich = RecoveryEvaluation(
        verdict: RecoveryVerdict.calm,
        signals: [],
        measuredCount: 4,
        rated: [RecoveryMetric.sleep],
      );

      expect(grundlage, gleich);
      expect(grundlage.hashCode, gleich.hashCode);
    });

    test('toString nennt rated', () {
      expect(grundlage.toString(), contains('rated'));
    });
  });

  group('Die Ampelschwellen bleiben unverändert', () {
    test('die vier Konstanten aus docs/SPEC.md 4.6 stehen, wo sie standen', () {
      // SPEC 176: Ruhepuls >= Median + 5 bpm, HRV <= Median * 0,8,
      // Atemfrequenz >= Median + 1,5, Schlaf < 6 h. Diese Stufe ändert
      // ausschließlich, **welcher** Wert gegen **welchen** Median steht.
      expect(RecoveryTrafficLight.minimumSleepHours, 6.0);
      expect(RecoveryTrafficLight.restingHeartRateMargin, 5.0);
      expect(RecoveryTrafficLight.hrvFactor, 0.8);
      expect(RecoveryTrafficLight.respiratoryRateMargin, 1.5);
    });
  });
}
