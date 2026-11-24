// Der Schlaf-Score in seinen drei Teilen (#92) — die Teilnoten mit ihrem
// eigenen Maximum, ihre Farben und die drei Ringabschnitte der Score-Karte.
//
// **Teilnoten und Ring bleiben zusammen**, weil der Ring die Maxima der
// Teilnoten zu seinen Anteilen macht: 50/30/20 steht nur an einer Stelle,
// und dass er bei einer entfallenen Teilnote nicht hochnormiert, ist eine
// Aussage über dieselben drei Zahlen.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/segment_ring.dart';

/// Die drei Teile des Schlaf-Score, in der Reihenfolge, in der sie auf dem
/// Schirm stehen.
///
/// **`zubettgehzeit`, nicht `regelmaessigkeit`.** Die Teilnote misst seit
/// `docs/SPEC.md` 4.6 eine einzelne Nacht gegen das Schlafenszeitziel aus
/// den Einstellungen, nicht die Streuung gegen den eigenen Schnitt der
/// letzten vierzehn Nächte. Die Swift-Vorlage trägt noch den alten Namen
/// **und die alte Rechnung** — wer sie abschreibt, holt den Fehler zurück.
enum SchlafTeil { dauer, zubettgehzeit, unterbrechungen }

/// Die Gründe, aus denen eine Teilnote entfällt.
///
/// **Zwei, und beide sind eine Aussage.** „Keine frühere Nacht als
/// Vergleich" ist mit dem 14-Nächte-Fenster weggefallen; ein
/// Schlafenszeitziel gibt es ab der ersten Nacht. Geblieben sind:
///
/// - [keineEinschlafzeit] — die Nacht hat keine Einschlafzeit, also
///   entfällt die Zubettgehzeit (#110).
/// - [keinePhasendaten] — die Nacht ist von Hand eingetragen, hat also
///   keine Phasen und damit nichts zu zählen; die Unterbrechungen
///   entfallen (#131).
///
/// Der Grund steht hier und nicht als Satz in der View: Wer die Teilnote
/// zeichnet, soll ihn aus dem Zustand lesen können.
enum SchlafEntfallGrund { keineEinschlafzeit, keinePhasendaten }

/// Eine Teilnote mit ihrem eigenen Maximum.
///
/// `punkte == null` heißt **entfällt**, nicht null Punkte: Die Nacht war
/// nicht spät, es ist nichts aufgezeichnet. Zwei verschiedene Dinge, und
/// nur das erste senkt die erreichbare Punktzahl.
@immutable
class SchlafTeilnote {
  const SchlafTeilnote({
    required this.teil,
    required this.punkte,
    required this.maximum,
    required this.grund,
  });

  final SchlafTeil teil;

  /// `null` heißt „entfällt".
  final int? punkte;

  /// 50, 30 oder 20 — das Maximum **dieser** Teilnote, nicht des Score.
  final int maximum;

  /// Warum sie entfällt; `null`, solange sie es nicht tut.
  final SchlafEntfallGrund? grund;

  bool get entfaellt => punkte == null;

  /// Punkte durch das eigene Maximum, 0 bis 1 — nicht durch den ganzen
  /// Score. Ohne Grundlage 0; der Ring zeichnet den Abschnitt dann
  /// gestrichelt statt blass.
  double get fuellung {
    final punkte = this.punkte;
    if (punkte == null || maximum <= 0) return 0;
    return punkte / maximum;
  }
}

/// Die drei Teilnoten eines Score, in fester Reihenfolge.
List<SchlafTeilnote> schlafTeilnoten(SleepScore score) => [
  SchlafTeilnote(
    teil: SchlafTeil.dauer,
    punkte: score.duration,
    maximum: SleepScore.maxDuration,
    grund: null,
  ),
  SchlafTeilnote(
    teil: SchlafTeil.zubettgehzeit,
    punkte: score.bedtime,
    maximum: SleepScore.maxBedtime,
    grund: score.bedtime == null ? SchlafEntfallGrund.keineEinschlafzeit : null,
  ),
  SchlafTeilnote(
    teil: SchlafTeil.unterbrechungen,
    punkte: score.interruptions,
    maximum: SleepScore.maxInterruptions,
    grund: score.interruptions == null
        ? SchlafEntfallGrund.keinePhasendaten
        : null,
  ),
];

/// Die Farbe einer Teilnote — unaufgelöst, wie jede Palette-Zuordnung
/// außerhalb einer `build`-Methode.
CupertinoDynamicColor schlafTeilFarbe(SchlafTeil teil) => switch (teil) {
  SchlafTeil.dauer => Palette.river,
  SchlafTeil.zubettgehzeit => Palette.ok,
  SchlafTeil.unterbrechungen => Palette.wach,
};

/// Die drei Ringabschnitte der Score-Karte — Anteile 50/30/20.
///
/// **Der Ring normiert nicht hoch.** Entfällt eine Teilnote, bleibt ihr
/// Stück des Kreises stehen und wird als ohne Grundlage gezeichnet; auf
/// 50/50 aufgeblasen verschwände die Aussage „ein Teil ist nicht gemessen",
/// und eine von Hand eingetragene Nacht sähe aus wie eine vollständig
/// gemessene.
List<RingAbschnitt> schlafRingAbschnitte(List<SchlafTeilnote> teile) {
  const gesamt =
      SleepScore.maxDuration +
      SleepScore.maxBedtime +
      SleepScore.maxInterruptions;
  return [
    for (final teil in teile)
      RingAbschnitt(
        anteil: teil.maximum / gesamt,
        fuellung: teil.fuellung,
        farbe: schlafTeilFarbe(teil.teil),
        hatGrundlage: !teil.entfaellt,
      ),
  ];
}
