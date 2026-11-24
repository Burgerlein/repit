// Der 14-Tage-Verlauf auf dem Ernährungs-Tag (#312, mit dem Befund aus
// #231): gegessen als Balken, Verbrauch als Linie, Ziel je Tag als Strich,
// dazu die Siebentagezeile „Ziel an X von Y Tagen getroffen, Ø ±Z kcal"
// (SPEC 4.8). Die Ansicht dazu liegt in `ernaehrung_verlauf_ansicht.dart`.
//
// **Nur vierzehn Tage.** Der Entwurf zeichnet zusätzlich `1M` und `3M`;
// die sind nicht gebaut und auf dem Board als „später" markiert — ob und
// wann sie kommen, ist offen (Tims Entscheidung).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ereignisse.dart';
import '../data/ernaehrung_repository.dart';
import '../data/kalorienziele.dart';
import '../data/stammdaten.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'ernaehrung_provider.dart';

/// So viele Tage zeigt der Verlauf.
const verlaufTage = 14;

/// Ein Tag des Verlaufs. Werttyp mit `==` und `hashCode` — er ist Teil
/// eines gehaltenen Providerwerts (Fehler `03`).
@immutable
class VerlaufTag {
  const VerlaufTag({
    required this.tag,
    this.gegessenKcal,
    this.verbrauchKcal,
    this.zielKcal,
  });

  /// ISO-Tagesschlüssel.
  final String tag;

  /// Summe der eigenen Einträge. `null` heißt **nichts eingetragen** —
  /// keine 0: An einem vergangenen Tag ist „nichts eingetragen" keine
  /// Aussage über das Essen.
  final double? gegessenKcal;

  /// Aktiv plus Grundumsatz aus Apple Health; `null`, wenn eins fehlt —
  /// eine halbe Summe wäre eine falsche Zahl. **Hängt nicht am
  /// Gegessenen** (#231): Ein Tag, an dem die Uhr gemessen hat, behält
  /// seinen Verbrauch, auch wenn nichts eingetragen ist.
  final double? verbrauchKcal;

  /// Dasselbe Ziel wie `ernaehrungsTagProvider(tag).zielKcal` — ab der
  /// ersten Festlegung das feste Ziel (#410), davor heute der Planwert,
  /// sonst aus dem Verbrauch (#229).
  final double? zielKcal;

  @override
  bool operator ==(Object other) =>
      other is VerlaufTag &&
      other.tag == tag &&
      other.gegessenKcal == gegessenKcal &&
      other.verbrauchKcal == verbrauchKcal &&
      other.zielKcal == zielKcal;

  @override
  int get hashCode => Object.hash(tag, gegessenKcal, verbrauchKcal, zielKcal);

  @override
  String toString() =>
      'VerlaufTag($tag, gegessen: $gegessenKcal, verbrauch: $verbrauchKcal, '
      'ziel: $zielKcal)';
}

/// Die 14 Tage bis einschließlich des Endtags und die Siebentagezeile.
@immutable
class ErnaehrungsVerlauf {
  const ErnaehrungsVerlauf({
    required this.tage,
    required this.siebenTage,
    this.durchschnittKcal,
    this.laedt = false,
  });

  /// Vierzehn Tage, lückenlos, der älteste zuerst.
  final List<VerlaufTag> tage;

  /// Aus dem Kern (`siebenTage`), über die **abgeschlossenen** Tage: Endet
  /// das Fenster heute, die sieben Tage davor — ein Tag, der noch läuft,
  /// stünde mittags als „Ziel verfehlt" in der Quote. Endet es an einem
  /// vergangenen Tag, die letzten sieben, dieser eingeschlossen.
  final SiebenTage siebenTage;

  /// Mittel des Gegessenen über die abgeschlossenen Tage des Fensters, an
  /// denen etwas eingetragen ist — dieselbe Auswahl wie bei
  /// [siebenTage], nur über alle vierzehn. `null` ohne einen solchen Tag:
  /// Ein Mittel über nichts ist keine 0.
  final double? durchschnittKcal;

  /// Die Tagessummen sind noch nicht gelesen. Dann trägt kein Tag ein
  /// Gegessenes, und die Ansicht nennt **keinen** Grund — „keine Werte"
  /// wäre eine Behauptung über eine Datenlage, die niemand gesehen hat
  /// (Fehler `01`).
  final bool laedt;

  @override
  bool operator ==(Object other) =>
      other is ErnaehrungsVerlauf &&
      listEquals(other.tage, tage) &&
      other.siebenTage == siebenTage &&
      other.durchschnittKcal == durchschnittKcal &&
      other.laedt == laedt;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(tage), siebenTage, durchschnittKcal, laedt);
}

/// Die vierzehn Tagesschlüssel bis einschließlich [bis], der älteste
/// zuerst — **über den Kalender**, nicht über 86.400 Sekunden: Das
/// Fenster läuft sonst über eine Zeitumstellung schief.
List<String> verlaufFenster(String bis) {
  final ende = datumAusTag(bis);
  return [
    for (var i = verlaufTage - 1; i >= 0; i--)
      BerlinCalendar.dayKey(BerlinCalendar.addDays(ende, -i)),
  ];
}

/// Rechnet den Verlauf. Reine Funktion — alles kommt herein; gehalten
/// wird sie von [ernaehrungsVerlaufProvider].
///
/// [kalorienziele]: die Historie des festen Ziels (#410). `null` heißt
/// „noch nicht gelesen" — dann steht an keinem Tag ein Ziel, statt erst die
/// gerechneten und danach die festen Striche zu zeigen.
///
/// [auszeiten]: Jeder Tag in einer OP, Krankheit oder Verletzung rechnet
/// ohne Aufschlag fürs Körperziel, auch rückwirkend (#447, Entscheidung 5)
/// — über [zielKcalAm], dieselbe Rechnung wie der Tag. [auszeitenLaden]:
/// Die Ereignisse sind noch nicht gelesen; dann steht wie bei der Historie
/// an keinem Tag ein Ziel (V12).
ErnaehrungsVerlauf ernaehrungsVerlaufAus({
  required String bis,
  required String heute,
  required Map<String, Naehrwerte>? summen,
  required Messwert<List<DailyMetrics>> tageswerte,
  required Stammdaten stammdaten,
  List<KalorienzielFestlegung>? kalorienziele = const [],
  List<AuszeitTage> auszeiten = const [],
  bool auszeitenLaden = false,
}) {
  final historie = kalorienziele;
  final metriken = <String, DailyMetrics>{
    if (tageswerte is Bekannt<List<DailyMetrics>>)
      for (final m in tageswerte.wert) m.tag: m,
  };

  final tage = [
    for (final tag in verlaufFenster(bis))
      () {
        final m = metriken[tag];
        final aktiv = m?.activeKcal;
        final basal = m?.basalKcal;
        return VerlaufTag(
          tag: tag,
          gegessenKcal: summen?[tag]?.kcal,
          verbrauchKcal: aktiv == null || basal == null
              ? null
              : (aktiv + basal).toDouble(),
          zielKcal: historie == null
              ? null
              : zielKcalAm(
                  tagesSchluessel: tag,
                  heute: heute,
                  tageswerte: tageswerte,
                  stammdaten: stammdaten,
                  kalorienziele: historie,
                  auszeiten: auszeiten,
                  auszeitenLaden: auszeitenLaden,
                ),
        );
      }(),
  ];

  // Abgeschlossen ist, was vor heute liegt.
  final abgeschlossen = [
    for (final t in tage)
      if (t.tag.compareTo(heute) < 0) t,
  ];
  final sieben = bis == heute
      ? tage.sublist(verlaufTage - 8, verlaufTage - 1)
      : tage.sublist(verlaufTage - 7);

  final gegessen = [
    for (final t in abgeschlossen)
      if (t.gegessenKcal != null) t.gegessenKcal!,
  ];

  return ErnaehrungsVerlauf(
    tage: tage,
    siebenTage: siebenTage([
      for (final t in sieben) (gegessen: t.gegessenKcal, ziel: t.zielKcal),
    ]),
    durchschnittKcal: gegessen.isEmpty
        ? null
        : gegessen.reduce((a, b) => a + b) / gegessen.length,
    laedt: summen == null || historie == null || auszeitenLaden,
  );
}

/// Die Tagessummen des Fensters, das an [bis] endet — **eine** Abfrage,
/// in SQL gefiltert und summiert (`ErnaehrungRepository.tagessummen`).
///
/// Liest neu, sobald irgendein Esstag nach einer Buchung neu gelesen wurde
/// ([eintraegeStandProvider]).
final verlaufSummenProvider =
    FutureProvider.family<Map<String, Naehrwerte>, String>((ref, bis) {
      ref.watch(eintraegeStandProvider);
      final fenster = verlaufFenster(bis);
      return ref
          .watch(ernaehrungRepositoryProvider)
          .tagessummen(von: fenster.first, bis: fenster.last);
    });

/// Der Verlauf, der an [bis] endet — der Schirm übergibt den offenen Tag.
///
/// **Gehalten, nicht je Zugriff gerechnet** (Hausregel 2). Gelesen wird er
/// erst, wenn „Verlauf" aufgeklappt ist oder seine Kopfzeile den
/// Durchschnitt nennt; die Rechnung ist eine SQL-Abfrage und vierzehn
/// Zielrechnungen.
final ernaehrungsVerlaufProvider = Provider.family<ErnaehrungsVerlauf, String>((
  ref,
  bis,
) {
  final jetzt = ref.watch(clockProvider)();
  final (:laden, :historie) = kalorienzielHistorie(
    ref.watch(kalorienzieleProvider),
  );
  final auszeiten = ref.watch(auszeitenProvider);
  return ernaehrungsVerlaufAus(
    bis: bis,
    heute: BerlinCalendar.dayKey(jetzt),
    summen: ref.watch(verlaufSummenProvider(bis)).value,
    tageswerte:
        ref.watch(dailyMetricsProvider).value ??
        const NochNie<List<DailyMetrics>>(),
    stammdaten: stammdatenAusProvider(ref.watch(stammdatenProvider)).stammdaten,
    kalorienziele: laden ? null : historie,
    auszeiten: auszeiten.auszeiten,
    auszeitenLaden: auszeiten.laden,
  );
});
