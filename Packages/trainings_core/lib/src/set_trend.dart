// Besser, schlechter oder gleich als beim letzten Mal (#78, Spec 13.2).
//
// **Ohne Test:** Diese Formel ist im Zug des Erfassen-Schirms entstanden,
// weil der Schirm sie braucht und im Kern keine stand. Nach `CLAUDE.md`
// bekommt jede Formel ihren Test im Kern, von einem zweiten Agenten aus
// Spec 13.2 geschrieben — das steht noch aus. Bis dahin prüfen sie nur die
// Widget-Tests des Schirms (`gym_log_leerzustaende_test.dart`).
import 'progression.dart';

/// Wie sich ein Satz zum selben Satz vom letzten Mal verhält.
enum SetTrend { better, worse, same }

/// Die Rechnung hinter dem Trendpfeil neben einer Satzzeile.
abstract final class SetTrends {
  /// Vergleicht den eingetragenen Satz mit [previous], dem Satz mit
  /// demselben Index aus dem letzten Training.
  ///
  /// **Erst das Gewicht, dann die Wiederholungen:** Wer schwerer hebt, hat
  /// sich gesteigert, auch wenn er dabei eine Wiederholung verliert.
  ///
  /// **Fehlt der Vergleichswert, gibt es keinen Pfeil** — `null` —, statt
  /// eines geratenen. Dasselbe gilt für einen Satz, der noch keine lesbare
  /// Wiederholungszahl trägt.
  ///
  /// [weight] und [reps] sind der **rohe Text** der Felder; Komma und Punkt
  /// werden beide gelesen. Ein leeres oder unlesbares Gewicht wird nicht
  /// verglichen (es heißt „wie letztes Mal", Tim, 10.11.2026), und dann
  /// entscheiden die Wiederholungen.
  ///
  /// Bei [assist] ist der eingetippte Betrag die Hilfe von der Maschine und
  /// zählt **negativ**, so wie die Ablage ihn führt: −24 ist schwerer als
  /// −27, also ist weniger Unterstützung die Steigerung.
  static SetTrend? compare({
    required String weight,
    required String reps,
    required bool assist,
    required CompletedSet? previous,
  }) {
    if (previous == null) return null;

    final r = int.tryParse(reps.trim());
    if (r == null || r <= 0) return null;

    final gelesen = double.tryParse(weight.trim().replaceAll(',', '.'));
    if (gelesen != null && gelesen.isFinite) {
      final w = assist ? -gelesen.abs() : gelesen;
      if (w != previous.weight) {
        return w > previous.weight ? SetTrend.better : SetTrend.worse;
      }
    }
    if (r != previous.reps) {
      return r > previous.reps ? SetTrend.better : SetTrend.worse;
    }
    return SetTrend.same;
  }
}
