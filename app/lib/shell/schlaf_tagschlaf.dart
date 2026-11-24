// Der Zustand des Tagschlaf-Schirms (#92) — die Nickerchen eines Tages
// und ihre Summe, und **nichts von der Nacht**. Die Oberfläche dazu liegt
// in `tagschlaf_view.dart`.
//
// **Ein eigener Schirm, eine eigene Datei.** Welcher Tag gemeint ist,
// kommt aus `schlaf_auswahl.dart`: Der Tagschlaf folgt der gewählten
// Nacht, sonst wäre er beim Blättern unsichtbar.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'schlaf_auswahl.dart';
import 'schlaf_minuten.dart';
import 'schlaf_von_hand.dart';

/// Der Tagschlaf eines Tages — und **nichts von der Nacht**.
@immutable
class TagschlafZustand {
  const TagschlafZustand({
    required this.phasen,
    required this.tag,
    this.eintraege = const [],
  });

  /// Die **gemessenen** Nickerchen des Tages, zeitlich sortiert.
  final Messwert<List<SleepSession>> phasen;

  /// Der Berliner Kalendertag, um den es geht.
  final DateTime tag;

  /// Die von Hand eingetragenen Nickerchen desselben Tages (#131) —
  /// **zusätzlich** zu [phasen], nicht statt ihrer. Ein Nickerchen gibt es
  /// je Tag mehrfach; ein eingetragenes ersetzt deshalb keines.
  ///
  /// Kein `Messwert`: Tims eigene Eingabe kennt keinen Lauf, der leer
  /// ausgehen könnte (Spec 5.6a). Leer heißt leer.
  final List<SchlafEintrag> eintraege;

  /// Ob es überhaupt etwas zu zeigen gibt — gemessen oder eingetragen.
  bool get hatPhasen {
    final phasen = this.phasen;
    final gemessen =
        phasen is Bekannt<List<SleepSession>> && phasen.wert.isNotEmpty;
    return gemessen || eintraege.isNotEmpty;
  }

  /// Wie viele Phasen zusammen, gemessene und eingetragene.
  int get anzahl {
    final phasen = this.phasen;
    final gemessen = phasen is Bekannt<List<SleepSession>>
        ? phasen.wert.length
        : 0;
    return gemessen + eintraege.length;
  }

  /// Die Summe der Schlafminuten — Wachliegen im Nickerchen zählt nicht,
  /// und die Nacht geht nicht ein. Eingetragene Phasen zählen mit
  /// (`tagschlaf.js`: „Die Summe oben zählt beide Phasen").
  double get minuten {
    var summe = 0.0;
    final phasen = this.phasen;
    if (phasen is Bekannt<List<SleepSession>>) {
      for (final phase in phasen.wert) {
        summe += schlafMinutenVon(phase);
      }
    }
    for (final eintrag in eintraege) {
      summe += eintrag.schlafMinuten;
    }
    return summe;
  }
}

/// Welcher Tag gemeint ist, entscheidet die Auswahl des Nacht-Schirms —
/// sonst wäre der Tagschlaf beim Blättern unsichtbar. Ein Parameter am
/// Schirm daneben wäre eine zweite Wahrheit über denselben Tag.
final tagschlafProvider = Provider.autoDispose<TagschlafZustand>((ref) {
  final naechte =
      ref.watch(sleepProvider).value ?? const NochNie<List<SleepNight>>();
  final gewaehlt = ref.watch(schlafAuswahlProvider);
  final heute = BerlinCalendar.startOfDay(ref.watch(clockProvider)());

  final liste = naechte is Bekannt<List<SleepNight>>
      ? naechte.wert
      : const <SleepNight>[];
  final tag = geloesteNacht(naechte: liste, gewaehlt: gewaehlt)?.date ?? heute;

  final Messwert<List<SleepSession>> phasen = switch (naechte) {
    NochNie<List<SleepNight>>() => const NochNie<List<SleepSession>>(),
    LeerNachLauf<List<SleepNight>>(:final gelaufen) =>
      LeerNachLauf<List<SleepSession>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<SleepNight>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<List<SleepSession>>(fehler: fehler, gelaufen: gelaufen),
    // **Bekannt, auch ohne Nickerchen.** „An diesem Tag kein Nickerchen"
    // ist eine Aussage, kein Leerstand: Die Schlafdaten sind da, und die
    // Lücke ist eindeutig.
    Bekannt<List<SleepNight>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<List<SleepSession>>(
        _napsAm(wert, tag),
        stand: stand,
        laeuft: laeuft,
      ),
  };

  return TagschlafZustand(
    phasen: phasen,
    tag: tag,
    eintraege: tagschlafEintraegeZu(
      tag,
      ref.watch(schlafEintraegeProvider).value ?? const [],
    ),
  );
});

List<SleepSession> _napsAm(List<SleepNight> naechte, DateTime tag) {
  for (final nacht in naechte) {
    if (nacht.date != tag) continue;
    final naps = [...nacht.naps];
    naps.sort((a, b) {
      final (aVon, _) = schlafFensterVon(a);
      final (bVon, _) = schlafFensterVon(b);
      if (aVon == null || bVon == null) return 0;
      return aVon.compareTo(bVon);
    });
    return naps;
  }
  return const [];
}
