// Puls, HRV und Atemfrequenz einer Nacht — gerechnet über das Schlaffenster
// und nicht über den Kalendertag (#193).
//
// Apples `RestingHeartRate` ist ein Tageswert, der im Lauf des Tages
// mitwächst; HRV und Atemfrequenz hat die App bisher über den ganzen
// Kalendertag gemittelt. Beides beantwortet die Frage „wie war die Nacht?"
// nicht.
//
// Der Vertrag und seine Begründungen stehen im Kopf von
// `test/night_vitals_test.dart` und in
// `docs/superpowers/specs/2026-11-02-193-nachtwerte.md`; diese Datei setzt
// ihn um und erfindet nichts dazu.

/// Eine einzelne Messung mit ihrem Zeitpunkt.
///
/// Der Eingabetyp des Kerns — **nicht** `QuantitySample` aus
/// `app/lib/health/`: Das ist die Nutzlast des Kanals und trägt keine
/// Rechnung.
///
/// Werttyp mit `==` und `hashCode`, damit eine Probenreihe als Abhängigkeit
/// eines Providers taugt: Ohne Gleichheit wäre jede neu gebaute Liste
/// ungleich der vorigen und alles Abgeleitete liefe neu.
final class VitalSample {
  const VitalSample({required this.time, required this.value});

  /// Der Zeitpunkt der Messung. Ob er als UTC oder als Ortszeit vorliegt,
  /// spielt für [NightVitals.from] keine Rolle — dort wird der Augenblick
  /// verglichen, nicht die Schreibweise.
  final DateTime time;

  /// Der gemessene Wert in der Einheit seiner Messreihe (bpm, ms, 1/min).
  final double value;

  @override
  bool operator ==(Object other) =>
      other is VitalSample && other.time == time && other.value == value;

  @override
  int get hashCode => Object.hash(time, value);

  @override
  String toString() => 'VitalSample(time: $time, value: $value)';
}

/// Die drei Werte einer Nacht, jeder davon `null`, wenn er nicht zu haben
/// war.
///
/// **Leer ist `null`, niemals `0`.** Eine Null behauptete „gemessen und
/// nichts gefunden"; das ist Fehler `01` aus `CLAUDE.md`, eine Ebene tiefer
/// als `Messwert<T>` ihn sehen könnte.
///
/// Werttyp mit `==` und `hashCode`: In Stufe 3 hängt ein Provider je Nacht
/// an einem dieser Werte.
final class NightVitals {
  const NightVitals({this.restingHeartRate, this.hrv, this.respiratoryRate});

  /// Der Ruhepuls der Nacht in bpm — das 5. Perzentil der Pulsproben im
  /// Fenster.
  final double? restingHeartRate;

  /// Die Herzfrequenzvariabilität in ms — der Median der Proben im Fenster.
  final double? hrv;

  /// Die Atemfrequenz in Atemzügen je Minute — ebenfalls der Median.
  final double? respiratoryRate;

  /// Der Anteil der Pulsproben, unter dem der Ruhepuls liegt: das
  /// 5. Perzentil.
  ///
  /// Von Tim am 02.11.2026 entschieden — „der tiefste anhaltende Wert, nicht
  /// der tiefste Einzelwert". Das Minimum machte eine einzelne verirrte
  /// Messung zum Ruhepuls.
  static const double restingHeartRatePercentile = 0.05;

  /// Darunter gibt es keinen Ruhepuls, sondern `null`. Eine echte Nacht hat
  /// bei Tim 60 bis 115 Pulsproben; unter fünf ist keine Nacht, sondern ein
  /// Messfehler, und ein Perzentil über zwei Proben ist keine Auskunft.
  static const int minimumHeartRateSamples = 5;

  /// Rechnet die drei Werte aus den Proben zwischen [from] und [through].
  ///
  /// Das Fenster schließt **beide Ränder ein**; Proben außerhalb zählen
  /// nicht. Liegt [through] vor [from], ist das Fenster leer und alle drei
  /// Felder sind `null` — keine Probe kann zugleich nicht vor [from] und
  /// nicht nach [through] liegen.
  ///
  /// Verglichen wird über `isBefore`/`isAfter` und nicht über `==`: Darts
  /// `DateTime.==` zieht `isUtc` mit heran, also wäre eine Probe, die
  /// denselben Augenblick als Ortszeit schreibt, ungleich dem Rand und fiele
  /// heraus.
  ///
  /// Für HRV und Atemfrequenz gibt es **keine** Mindestzahl: Die Uhr misst
  /// HRV nur zwei- bis sechsmal je Nacht.
  ///
  /// Die übergebenen Listen bleiben unverändert — Stufe 3 reicht dieselben
  /// Proben nacheinander an dreißig Nächte weiter, und ein `sort()` auf der
  /// Eingabe wäre eine stille Nebenwirkung beim Aufrufer.
  static NightVitals from({
    required List<VitalSample> heartRate,
    required List<VitalSample> hrv,
    required List<VitalSample> respiratoryRate,
    required DateTime from,
    required DateTime through,
  }) => NightVitals(
    restingHeartRate: _percentile(
      _valuesWithin(heartRate, from, through),
      restingHeartRatePercentile,
      minimumSamples: minimumHeartRateSamples,
    ),
    hrv: _median(_valuesWithin(hrv, from, through)),
    respiratoryRate: _median(_valuesWithin(respiratoryRate, from, through)),
  );

  /// Die Werte der Proben im Fenster, aufsteigend sortiert — in einer
  /// **neuen** Liste, damit die Eingabe unberührt bleibt.
  static List<double> _valuesWithin(
    List<VitalSample> samples,
    DateTime from,
    DateTime through,
  ) {
    final values = <double>[
      for (final sample in samples)
        if (!sample.time.isBefore(from) && !sample.time.isAfter(through))
          sample.value,
    ];
    return values..sort();
  }

  /// Das linear interpolierte Perzentil über [sorted] — `null`, solange
  /// weniger als [minimumSamples] Werte vorliegen.
  static double? _percentile(
    List<double> sorted,
    double fraction, {
    required int minimumSamples,
  }) {
    if (sorted.length < minimumSamples) return null;
    final k = (sorted.length - 1) * fraction;
    final unten = k.floor();
    final oben = k.ceil();
    // Bei ganzzahligem `k` sind beide Ränder derselbe Wert; die
    // Interpolation fällt dann von selbst weg.
    return sorted[unten] + (sorted[oben] - sorted[unten]) * (k - unten);
  }

  /// Der Median über [sorted] — bei gerader Anzahl das **Mittel** der beiden
  /// mittleren Werte.
  ///
  /// Hier weicht die Regel bewusst von `HealthMedian.value` ab, wo bei
  /// gerader Anzahl der obere der beiden gewinnt: Dort geht es um den
  /// Normalbereich aus dreißig Nächten, hier um zwei bis sechs Proben einer
  /// einzigen. So steht es in der Spec zu #193.
  static double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final mitte = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mitte];
    return (sorted[mitte - 1] + sorted[mitte]) / 2;
  }

  @override
  bool operator ==(Object other) =>
      other is NightVitals &&
      other.restingHeartRate == restingHeartRate &&
      other.hrv == hrv &&
      other.respiratoryRate == respiratoryRate;

  @override
  int get hashCode => Object.hash(restingHeartRate, hrv, respiratoryRate);

  @override
  String toString() =>
      'NightVitals(restingHeartRate: $restingHeartRate, hrv: $hrv, '
      'respiratoryRate: $respiratoryRate)';
}
