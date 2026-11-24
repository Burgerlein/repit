// Geschätztes Einwiederholungsmaximum, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/OneRepMax.swift` (#91).

import 'progression.dart';

/// Geschätztes Einwiederholungsmaximum nach Epley (`docs/SPEC.md` 4.4).
///
/// Eine **Schätzung**, kein Maximalversuch, und mit steigender
/// Wiederholungszahl ungenauer. Eine allgemeine Rechengröße für den
/// Verlauf, keine Trainingsvorgabe und keine ärztliche Auskunft.
abstract final class OneRepMax {
  /// Epley: Gewicht · (1 + Wdh./30), auf eine Nachkommastelle gerundet.
  ///
  /// `null` bei [weight] ≤ 0 oder [reps] ≤ 0. Nur für positive Gewichte:
  /// Bei Unterstützung wäre das tatsächlich bewegte Gewicht vom
  /// Körpergewicht abhängig, und eine Schätzung darauf wäre eine Schätzung
  /// auf einer Schätzung.
  static double? epley({required double weight, required int reps}) {
    if (weight <= 0 || reps <= 0) return null;
    // Eine Wiederholung **ist** das Maximum, gemessen statt geschätzt. Die
    // Formel ergäbe 1,033 · Gewicht und läge damit über einem tatsächlich
    // bewegten Gewicht — der einzige Fall, in dem die Schätzung
    // überprüfbar ist.
    if (reps <= 1) return weight;
    final value = weight * (1 + reps / 30);
    return (value * 10).roundToDouble() / 10;
  }

  /// Das höchste geschätzte Maximum einer Sitzung, `null`, wenn kein Satz
  /// schätzbar ist.
  ///
  /// Nicht der schwerste Satz: 50 kg × 10 schätzen höher als 55 kg × 6.
  static double? best(List<CompletedSet> session) {
    double? bester;
    for (final satz in session) {
      final wert = epley(weight: satz.weight, reps: satz.reps);
      if (wert == null) continue;
      if (bester == null || wert > bester) bester = wert;
    }
    return bester;
  }

  /// Kein Anstieg des geschätzten 1RM über vier Trainings
  /// (`docs/SPEC.md` 4.4). [sessions] neueste zuerst.
  ///
  /// Gebraucht werden **vier auswertbare** Sitzungen: Trägt eine davon
  /// keine Schätzung — leer oder nur unterstützte Sätze —, ist der
  /// Vergleich nicht zu führen, und `false` ist die ehrlichere Antwort als
  /// ein auf drei Werten errechnetes Ja.
  static bool isPlateau(List<List<CompletedSet>> sessions) {
    final values = <double>[];
    for (final session in sessions.take(4)) {
      final wert = best(session);
      if (wert != null) values.add(wert);
    }
    if (values.length != 4) return false;
    // Ein Prozent Luft, damit Messrauschen kein Plateau verhindert.
    return values.first <= values.last * 1.01;
  }
}
