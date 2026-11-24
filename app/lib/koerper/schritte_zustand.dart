// Der Zustand des Schritte-Schirms (#84) — **gehalten, nicht je Bild
// gerechnet** (Hausregel 2): Kennzahlen und Diagrammreihe entstehen hier
// einmal, wenn sich die Tageswerte oder der Kalendertag ändern.
//
// API und Verhalten sind durch `app/test/shell/schritte_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Es entsteht keine zweite Quelle für Tageswerte.** `dailyMetricsProvider`
// liest bereits Cache zuerst und dann den Kanal; hier wird davon
// **abgeleitet** und nichts selbst gefragt — derselbe Schnitt wie bei
// `koerper_zustand.dart`, das dieselben Schritte für die Kachel „Ø 7 Tage"
// zieht.
//
// **Keine Formel steht hier als Zahl.** Gestern, Ø 7 mit Trend, Ø 30,
// „Ziel erreicht x / y" und Top rechnet [StepStatistics] im Kern
// (`Packages/trainings_core`), wo jede Formel ihren Test hat.
//
// **Keine Nutzertexte.** Der Zustand liefert Zahlen; „▲ 2 % zur Vorwoche"
// und die Fußnoten stehen in der View (`CLAUDE.md`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ziele.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';

/// Wie viele Kalendertage hinter „Ziel erreicht", Ø 30 und Top stecken —
/// `StepStatistics.make` zählt die Abstände 1–30 (SPEC 4.6). Die Zahl steht
/// hier für den Satz „x Tage ohne Messung", nicht als eigene Rechnung.
const int schritteFensterTage = 30;

/// Was der Schritte-Schirm zeigt, einmal gerechnet.
///
/// Werttyp mit `==` und `hashCode`, weil er in einer Provider-Abhängigkeit
/// steckt: Ohne Wertgleichheit wäre jede neu gerechnete Fassung ungleich
/// der vorigen, und jeder abgeleitete Wert liefe neu — Fehler `03`,
/// wortgleich im neuen Code (`CLAUDE.md`).
@immutable
class SchritteWerte {
  const SchritteWerte({required this.kennzahlen, required this.tagesReihe});

  /// Gestern, Ø 7 mit Trend, Ø 30, Ziel erreicht, Top — aus dem Kern.
  final StepStats kennzahlen;

  /// Alle **gemessenen** Tage als Diagrammreihe, aufsteigend. Ein Tag ohne
  /// Schritte fehlt, er steht nicht mit `0` darin (Fehler `01`).
  final List<({DateTime tag, double wert})> tagesReihe;

  /// `30 − daysWithData` — die Tage, die der Schirm dazusagt, statt sie in
  /// den Nenner zu zählen („Stand die Uhr zwei Wochen im Schrank, wären
  /// ‚8 / 30' eine Behauptung über Tage, über die niemand etwas weiß").
  int get tageOhneMessung => schritteFensterTage - kennzahlen.daysWithData;

  @override
  bool operator ==(Object other) =>
      other is SchritteWerte &&
      other.kennzahlen == kennzahlen &&
      listEquals(other.tagesReihe, tagesReihe);

  @override
  int get hashCode => Object.hash(kennzahlen, Object.hashAll(tagesReihe));
}

/// Rechnet den Schirm-Zustand aus den Tageswerten.
///
/// Die vier Zustände werden durchgereicht; nur aus `Bekannt` kann ein
/// anderer werden, und zwar genau dann, wenn **kein** Tag gemessene
/// Schritte trägt — dieselbe Regel wie `koerperWerteAus`:
///
/// * läuft der Lauf noch, ist es [NochNie] — der graue Platzhalter;
/// * ist er fertig, ist es [LeerNachLauf].
Messwert<SchritteWerte> schritteWerteAus({
  required Messwert<List<DailyMetrics>> tageswerte,
  required DateTime heute,
}) => switch (tageswerte) {
  // Vollständig über den sealed-Typ: Käme ein fünfter Zustand, zeigte der
  // Analyzer genau hierhin.
  NochNie<List<DailyMetrics>>() => const NochNie<SchritteWerte>(),
  LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
    LeerNachLauf<SchritteWerte>(gelaufen: gelaufen),
  Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
    Fehlgeschlagen<SchritteWerte>(fehler: fehler, gelaufen: gelaufen),
  Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
    _ausTagen(wert, stand: stand, laeuft: laeuft, heute: heute),
};

Messwert<SchritteWerte> _ausTagen(
  List<DailyMetrics> tage, {
  required DateTime stand,
  required bool laeuft,
  required DateTime heute,
}) {
  // `?tag.steps`: Ein Tag ohne gemessene Schritte fällt heraus, statt mit
  // `0` darin zu stehen — der Unterschied, an dem Fehler `01` hängt und
  // den `StepStatistics` im Nenner braucht.
  final kennzahlen = StepStatistics.make({
    for (final tag in tage) tag.tag: ?tag.steps,
  }, goal: schritteTagesziel, now: heute);

  final reihe = <({DateTime tag, double wert})>[
    for (final tag in tage)
      if (tag.steps case final schritte?)
        (tag: datumAusTag(tag.tag), wert: schritte.toDouble()),
  ]..sort((eins, zwei) => eins.tag.compareTo(zwei.tag));

  if (reihe.isEmpty) {
    if (laeuft) return const NochNie<SchritteWerte>();
    // Der Zeitpunkt ist der Stand der Daten, die nichts hergaben — wie bei
    // `koerperWerteAus`, dort begründet.
    return LeerNachLauf<SchritteWerte>(gelaufen: stand);
  }

  return Bekannt<SchritteWerte>(
    SchritteWerte(kennzahlen: kennzahlen, tagesReihe: List.unmodifiable(reihe)),
    stand: stand,
    laeuft: laeuft,
  );
}

/// Der gehaltene Zustand des Schirms — ohne `AsyncValue`, das endet hier
/// (Hausregel 1; dasselbe Muster wie `gewichtsReiheProvider`).
///
/// `.value` trägt beim Nachlauf noch den vorigen [Messwert]:
/// `invalidateSelf` macht daraus `AsyncLoading.copyWithPrevious(…)`, und
/// genau deshalb bleibt `Bekannt` stehen, statt auf den Platzhalter
/// zurückzufallen (`32`).
final schritteZustandProvider = Provider<Messwert<SchritteWerte>>((ref) {
  final tageswerte =
      ref.watch(dailyMetricsProvider).value ??
      const NochNie<List<DailyMetrics>>();
  // Der Tag kommt aus `heutigerTagProvider`, nicht aus der Uhr: Nur so
  // rücken die Fenster über Mitternacht mit, und nur so rechnet der
  // Zustand nicht je Zugriff neu (Fehler `03`).
  final heute = ref.watch(heutigerTagProvider);
  return schritteWerteAus(tageswerte: tageswerte, heute: heute);
});
