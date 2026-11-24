import 'health_median.dart';
import 'recovery_input.dart';

/// Die vier Messwerte einer Nacht. `null` heißt „kein Wert" — ob nichts
/// aufgezeichnet wurde oder der Lesezugriff fehlt, verrät HealthKit nicht,
/// und eine Lücke darf nie als Null dargestellt werden.
class RecoveryReading {
  const RecoveryReading({
    this.sleepHours,
    this.restingHeartRate,
    this.hrv,
    this.respiratoryRate,
  });

  final double? sleepHours;
  final double? restingHeartRate;
  final double? hrv;
  final double? respiratoryRate;

  @override
  bool operator ==(Object other) =>
      other is RecoveryReading &&
      other.sleepHours == sleepHours &&
      other.restingHeartRate == restingHeartRate &&
      other.hrv == hrv &&
      other.respiratoryRate == respiratoryRate;

  @override
  int get hashCode =>
      Object.hash(sleepHours, restingHeartRate, hrv, respiratoryRate);

  @override
  String toString() =>
      'RecoveryReading(sleepHours: $sleepHours, '
      'restingHeartRate: $restingHeartRate, hrv: $hrv, '
      'respiratoryRate: $respiratoryRate)';
}

/// Der eigene Normalbereich: je Metrik ein Median über das Fenster. `null`
/// heißt „nicht genug Werte" und schaltet **nur diese eine** Metrik ab.
class RecoveryBaseline {
  const RecoveryBaseline({
    this.sleepHours,
    this.restingHeartRate,
    this.hrv,
    this.respiratoryRate,
  });

  /// Die vier Mediane aus Tageswerten und Schlafstunden.
  ///
  /// **Erst die Lücken heraus, dann das Fenster.** Wer das Fenster über die
  /// letzten 30 **Tage** legt und erst danach die Lücken entfernt, verliert
  /// den Median, sobald die Uhr zehn Nächte aussetzt — obwohl davor dreißig
  /// gemessene Tage liegen.
  factory RecoveryBaseline.from({
    required List<RecoveryDay> days,
    required List<double> sleepHours,
    int window = HealthMedian.defaultWindow,
    int minimumSamples = HealthMedian.defaultMinimumSamples,
  }) {
    double? median(List<double> samples) => HealthMedian.value(
      samples,
      window: window,
      minimumSamples: minimumSamples,
    );

    double? medianOf(double? Function(RecoveryDay day) field) =>
        median([for (final day in days) ?field(day)]);

    return RecoveryBaseline(
      sleepHours: median(sleepHours),
      restingHeartRate: medianOf((day) => day.restingHeartRate),
      hrv: medianOf((day) => day.hrv),
      respiratoryRate: medianOf((day) => day.respiratoryRate),
    );
  }

  final double? sleepHours;
  final double? restingHeartRate;
  final double? hrv;
  final double? respiratoryRate;

  @override
  bool operator ==(Object other) =>
      other is RecoveryBaseline &&
      other.sleepHours == sleepHours &&
      other.restingHeartRate == restingHeartRate &&
      other.hrv == hrv &&
      other.respiratoryRate == respiratoryRate;

  @override
  int get hashCode =>
      Object.hash(sleepHours, restingHeartRate, hrv, respiratoryRate);

  @override
  String toString() =>
      'RecoveryBaseline(sleepHours: $sleepHours, '
      'restingHeartRate: $restingHeartRate, hrv: $hrv, '
      'respiratoryRate: $respiratoryRate)';
}

/// Die vier Metriken der Ampel. **Die Reihenfolge ist Vertrag:** Die vier
/// Viertel des Erholungsrings werden in ihr gezeichnet. Wer sie umsortiert,
/// färbt das falsche Viertel ein, und es gibt keine UI-Tests, die das
/// merkten.
enum RecoveryMetric { sleep, restingHeartRate, hrv, respiratoryRate }

/// Das Verdikt der Ampel.
enum RecoveryVerdict {
  /// kein Warnsignal
  calm,

  /// genau ein Warnsignal
  watch,

  /// zwei oder mehr Warnsignale
  stressed,

  /// keiner der vier Werte liegt vor
  noData,

  /// Erholung nach der OP — es wird nicht bewertet
  postOperative,
}

/// Was die Ampel über eine Nacht sagt.
class RecoveryEvaluation {
  const RecoveryEvaluation({
    required this.verdict,
    required this.signals,
    required this.measuredCount,
    this.rated = const [],
  });

  final RecoveryVerdict verdict;

  /// Immer in der Reihenfolge von [RecoveryMetric].
  final List<RecoveryMetric> signals;

  /// Wie viele der vier Werte vorliegen — gezählt **vor** allen Abkürzungen,
  /// also auch nach der OP und bei `noData`.
  final int measuredCount;

  /// Die Metriken, über die die Ampel überhaupt eine Aussage gemacht hat —
  /// ebenfalls in der Reihenfolge von [RecoveryMetric]. Es gilt
  /// `signals ⊆ rated`.
  ///
  /// **Warum es das Feld gibt.** Ohne Median gibt es keinen Vergleich, ohne
  /// Vergleich kein Warnsignal, und null Warnsignale sind
  /// [RecoveryVerdict.calm] — ein Ring malte dort vier grüne Viertel und
  /// behauptete „alles im Normalbereich", eine Aussage, die niemand gemacht
  /// hat. `measuredCount` fängt das nicht: Die Werte liegen ja vor, es fehlt
  /// die Vergleichsgrundlage. Für die fünf ältesten Tage des Rechenfensters
  /// ist das der Normalfall, weil [HealthMedian] unter fünf Werten `null`
  /// liefert.
  ///
  /// Vorgabewert `const []`, damit bestehende Konstruktionen übersetzen;
  /// [RecoveryTrafficLight.evaluate] füllt es immer.
  final List<RecoveryMetric> rated;

  @override
  bool operator ==(Object other) {
    if (other is! RecoveryEvaluation) return false;
    if (other.verdict != verdict || other.measuredCount != measuredCount) {
      return false;
    }
    if (other.signals.length != signals.length) return false;
    for (var i = 0; i < signals.length; i++) {
      if (other.signals[i] != signals[i]) return false;
    }
    if (other.rated.length != rated.length) return false;
    for (var i = 0; i < rated.length; i++) {
      if (other.rated[i] != rated[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    verdict,
    measuredCount,
    Object.hashAll(signals),
    Object.hashAll(rated),
  );

  @override
  String toString() =>
      'RecoveryEvaluation(verdict: $verdict, signals: $signals, '
      'measuredCount: $measuredCount, rated: $rated)';
}

/// Vergleicht die Nacht mit dem eigenen Median. Grobe Orientierung, keine
/// medizinische Bewertung — die Schwellen stehen in `docs/SPEC.md` 4.6.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RecoveryTrafficLight.swift`.
/// **Eine Abweichung mit Absicht:** Swift schreibt `hrvDropShare = 0.2` und
/// rechnet `median * (1 - hrvDropShare)`. Die Spec sagt „HRV ≤ Median · 0,8";
/// die Konstante trägt deshalb genau die Zahl aus der Spec. Eine Umrechnung
/// im Kopf ist eine Stelle, an der sich jemand irren kann — und die Views
/// beschriften mit dieser Konstante.
///
/// Jede Schwelle steht hier **einmal**. In Swift stehen sie dreifach: einmal
/// als Wahrheit, zweimal als Beschriftung.
abstract final class RecoveryTrafficLight {
  /// Feste Schwelle, unabhängig vom Median und vom Schlafziel. Strikt
  /// kleiner: genau sechs Stunden sind kein Signal.
  static const double minimumSleepHours = 6.0;

  /// Ruhepuls ab `Median + diesem Zuschlag` ist ein Signal; Gleichheit zählt.
  static const double restingHeartRateMargin = 5.0;

  /// HRV bis `Median · diesem Faktor` ist ein Signal; Gleichheit zählt.
  static const double hrvFactor = 0.8;

  /// Atemfrequenz ab `Median + diesem Zuschlag` ist ein Signal.
  static const double respiratoryRateMargin = 1.5;

  static RecoveryEvaluation evaluate({
    required RecoveryReading reading,
    required RecoveryBaseline baseline,
    bool isPostOperative = false,
  }) {
    // Vor allen Abkürzungen: Auch eine ruhende Ampel soll sagen können, wie
    // viel überhaupt gemessen wurde.
    final measured = [
      reading.sleepHours,
      reading.restingHeartRate,
      reading.hrv,
      reading.respiratoryRate,
    ].where((value) => value != null).length;

    // Eine ruhende Ampel hat über keine Metrik eine Aussage gemacht, also
    // bleibt `rated` leer — wie `signals`. Alles andere widerspräche dem
    // Verdikt: „beurteilt" neben „es wird nicht bewertet" wäre zweierlei
    // Auskunft über dieselbe Nacht. `measuredCount` sagt weiterhin, wie viel
    // vorlag.
    if (isPostOperative) {
      return RecoveryEvaluation(
        verdict: RecoveryVerdict.postOperative,
        signals: const [],
        measuredCount: measured,
      );
    }
    if (measured == 0) {
      return const RecoveryEvaluation(
        verdict: RecoveryVerdict.noData,
        signals: [],
        measuredCount: 0,
      );
    }

    // Worüber überhaupt geurteilt werden konnte. Der Schlaf braucht nur
    // seinen Wert — die Sechs-Stunden-Grenze steht fest; die drei anderen
    // brauchen Wert **und** Median.
    final rated = <RecoveryMetric>[
      if (reading.sleepHours != null) RecoveryMetric.sleep,
      if (reading.restingHeartRate != null && baseline.restingHeartRate != null)
        RecoveryMetric.restingHeartRate,
      if (reading.hrv != null && baseline.hrv != null) RecoveryMetric.hrv,
      if (reading.respiratoryRate != null && baseline.respiratoryRate != null)
        RecoveryMetric.respiratoryRate,
    ];

    // Ein fehlender Median schaltet nur seine eigene Metrik ab — der Schlaf
    // braucht gar keinen. Dieselben Bedingungen wie oben, eine Schwelle
    // weiter: Deshalb ist `signals` immer eine Teilmenge von `rated`.
    final signals = <RecoveryMetric>[
      if (reading.sleepHours case final sleep?)
        if (sleep < minimumSleepHours) RecoveryMetric.sleep,
      if (reading.restingHeartRate case final value?)
        if (baseline.restingHeartRate case final median?)
          if (value >= median + restingHeartRateMargin)
            RecoveryMetric.restingHeartRate,
      if (reading.hrv case final value?)
        if (baseline.hrv case final median?)
          if (value <= median * hrvFactor) RecoveryMetric.hrv,
      if (reading.respiratoryRate case final value?)
        if (baseline.respiratoryRate case final median?)
          if (value >= median + respiratoryRateMargin)
            RecoveryMetric.respiratoryRate,
    ];

    return RecoveryEvaluation(
      verdict: switch (signals.length) {
        0 => RecoveryVerdict.calm,
        1 => RecoveryVerdict.watch,
        _ => RecoveryVerdict.stressed,
      },
      signals: signals,
      measuredCount: measured,
      rated: rated,
    );
  }
}
