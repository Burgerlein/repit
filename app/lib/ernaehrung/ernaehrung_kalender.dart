// Der Kalender des Ernährungs-Tags (#409) — Tim, 07.11.2026:
// „Kalender-Icon wie bei Schlaf". Gezeichnet in
// `docs/screens/screens/ernaehrung.js`, Zustand `kalender`; Verhalten und
// API durch `test/ernaehrung/ernaehrung_kalender_test.dart` festgelegt.
//
// **Derselbe Baustein wie beim Schlaf** (`shell/monatsblatt.dart`), nur
// ein anderer Ring: **ein** Bogen je Tag für den Anteil gegessen/Ziel,
// gedeckelt. Über dem Ziel ist er voll und färbt sich um — wie der Bogen
// der Übersicht (#406).
//
//   Einträge und Ziel     Bogen auf der Spur          → antippbar
//   keine Einträge        leere Spur                   → antippbar
//   Einträge, kein Ziel   gestrichelte Spur            → antippbar
//   noch nicht gelesen    kein Ring                    → antippbar
//   Zukunft               kein Ring, blasse Ziffer     → stumm
//
// **Rückwärts ohne Grenze.** Die Einträge liegen in der eigenen Tabelle;
// einen Lesezeitraum wie beim Schlaf gibt es nicht, und ‹ auf dem Schirm
// ist ebenso unbegrenzt.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ernaehrung_repository.dart';
import '../data/kalorienziele.dart';
import '../data/stammdaten.dart';
import '../design/palette.dart';
import '../design/segment_ring.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import '../shell/monatsblatt.dart';
import 'ernaehrung_provider.dart';

/// Was der Ring eines Tages zeigt. Werttyp mit `==` — er ist Teil eines
/// gehaltenen Providerwerts (Fehler `03`).
@immutable
class KalenderRingWert {
  const KalenderRingWert({
    required this.anteil,
    this.ueber = false,
    this.ohneZiel = false,
  });

  /// Gegessen durch Ziel, auf 0 bis 1 gedeckelt.
  final double anteil;

  /// Mehr gegessen als das Ziel.
  final bool ueber;

  /// Einträge da, aber kein Ziel für diesen Tag — gestrichelt.
  final bool ohneZiel;

  @override
  bool operator ==(Object other) =>
      other is KalenderRingWert &&
      other.anteil == anteil &&
      other.ueber == ueber &&
      other.ohneZiel == ohneZiel;

  @override
  int get hashCode => Object.hash(anteil, ueber, ohneZiel);
}

/// Die **eine** Stelle, an der ein Tag seinen Ring bekommt. Rein und ohne
/// Widget.
///
/// `null` heißt **gar kein Ring**: für die Zukunft, und solange die Summen
/// nicht gelesen sind ([gelesen]) — ein leerer Ring hieße „nichts
/// eingetragen", und das wäre eine Aussage über eine Abfrage, die noch
/// läuft (Fehler `01`). [summe] `null` heißt: an diesem Tag nichts
/// eingetragen.
KalenderRingWert? ernaehrungKalenderRing({
  required String tag,
  required String heute,
  required bool gelesen,
  Naehrwerte? summe,
  double? ziel,
}) {
  if (tag.compareTo(heute) > 0) return null;
  if (!gelesen) return null;
  if (summe == null) return const KalenderRingWert(anteil: 0);
  if (ziel == null || ziel <= 0) {
    return const KalenderRingWert(anteil: 0, ohneZiel: true);
  }
  final kcal = summe.kcal ?? 0;
  return KalenderRingWert(
    anteil: (kcal / ziel).clamp(0.0, 1.0),
    ueber: kcal > ziel,
  );
}

/// Die Ringe eines Monats, je ISO-Tag.
@immutable
class ErnaehrungsMonat {
  const ErnaehrungsMonat(this.tage);

  final Map<String, KalenderRingWert?> tage;

  @override
  bool operator ==(Object other) =>
      other is ErnaehrungsMonat && mapEquals(other.tage, tage);

  @override
  int get hashCode => Object.hashAllUnordered(
    tage.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Erster und letzter ISO-Tag des Monats, dessen Erster [monatsErster]
/// ist (`JJJJ-07-01` → `JJJJ-07-31`).
({String von, String bis}) _monatsGrenzen(String monatsErster) {
  final teile = monatsErster.split('-').map(int.parse).toList();
  final letzter = DateTime.utc(teile[0], teile[1] + 1, 0).day;
  final praefix = monatsErster.substring(0, 8);
  return (
    von: monatsErster,
    bis: '$praefix${letzter.toString().padLeft(2, '0')}',
  );
}

/// Die Tagessummen eines Monats — **eine** Abfrage, in SQL gefiltert und
/// summiert (`ErnaehrungRepository.tagessummen`). Liest neu nach jeder
/// Buchung ([eintraegeStandProvider]).
final kalenderSummenProvider =
    FutureProvider.family<Map<String, Naehrwerte>, String>((ref, monatsErster) {
      ref.watch(eintraegeStandProvider);
      final (:von, :bis) = _monatsGrenzen(monatsErster);
      return ref
          .watch(ernaehrungRepositoryProvider)
          .tagessummen(von: von, bis: bis);
    });

/// Die Ringe des Monats, dessen Erster [monatsErster] ist (ISO-Tag).
///
/// **Gehalten, nicht je Bild gerechnet** (Hausregel 2): Das Ziel je Tag
/// ist dasselbe wie auf dem Tag selbst (`zielKcalAm`) — gerechnet wird es
/// nur für vergangene Tage mit Einträgen.
final ernaehrungsMonatProvider = Provider.family<ErnaehrungsMonat, String>((
  ref,
  monatsErster,
) {
  final heute = BerlinCalendar.dayKey(ref.watch(clockProvider)());
  final summen = ref.watch(kalenderSummenProvider(monatsErster)).value;
  final (:laden, :historie) = kalorienzielHistorie(
    ref.watch(kalorienzieleProvider),
  );
  final tageswerte =
      ref.watch(dailyMetricsProvider).value ??
      const NochNie<List<DailyMetrics>>();
  final stammdaten = stammdatenAusProvider(ref.watch(stammdatenProvider))
      .stammdaten;

  // Gelesen ist, was Summe **und** Ziel entscheiden kann. Solange Apple
  // Health oder die Zielhistorie noch nicht geantwortet haben, stünde
  // sonst „kein Ziel" da, wo nur noch niemand nachgesehen hat.
  final gelesen =
      summen != null && !laden && tageswerte is! NochNie<List<DailyMetrics>>;

  final (:von, :bis) = _monatsGrenzen(monatsErster);
  final letzter = int.parse(bis.substring(8));
  final praefix = von.substring(0, 8);
  final tage = <String, KalenderRingWert?>{};
  for (var n = 1; n <= letzter; n++) {
    final tag = '$praefix${n.toString().padLeft(2, '0')}';
    final summe = summen?[tag];
    final brauchtZiel = gelesen && summe != null && tag.compareTo(heute) <= 0;
    tage[tag] = ernaehrungKalenderRing(
      tag: tag,
      heute: heute,
      gelesen: gelesen,
      summe: summe,
      ziel: brauchtZiel
          ? zielKcalAm(
              tagesSchluessel: tag,
              heute: heute,
              tageswerte: tageswerte,
              stammdaten: stammdaten,
              kalorienziele: historie,
            )
          : null,
    );
  }
  return ErnaehrungsMonat(tage);
});

/// Der Knopf oben rechts, neben der Glocke. Öffnet das Kalenderblatt.
class ErnaehrungKalenderKnopf extends StatelessWidget {
  const ErnaehrungKalenderKnopf({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kalender',
      button: true,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const Key('ernaehrung-kalender-knopf'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 36),
        onPressed: () => showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => const ErnaehrungKalenderblatt(
            key: Key('ernaehrung-kalenderblatt'),
          ),
        ),
        child: const Icon(CupertinoIcons.calendar, size: 22),
      ),
    );
  }
}

/// Das Monatsraster. Hält den gezeigten Monat; der gewählte Tag ist der
/// offene Tag des Schirms.
class ErnaehrungKalenderblatt extends ConsumerStatefulWidget {
  const ErnaehrungKalenderblatt({super.key});

  @override
  ConsumerState<ErnaehrungKalenderblatt> createState() =>
      _ErnaehrungKalenderblattZustand();
}

class _ErnaehrungKalenderblattZustand
    extends ConsumerState<ErnaehrungKalenderblatt> {
  /// `null` heißt „noch nicht geblättert" — dann gilt der Monat des
  /// offenen Tags.
  DateTime? _monat;

  @override
  Widget build(BuildContext context) {
    final heuteSchluessel = BerlinCalendar.dayKey(ref.watch(clockProvider)());
    final offen = ref.watch(offenerTagProvider);
    final heute = _tagesbeginn(heuteSchluessel);
    final gewaehlt = _tagesbeginn(offen);
    final monat = _monat ?? monatsErster(gewaehlt);
    final monatsSchluessel =
        '${monat.year}-${monat.month.toString().padLeft(2, '0')}-01';
    final daten = ref.watch(ernaehrungsMonatProvider(monatsSchluessel));

    return Monatsblatt(
      schluessel: 'ernaehrung-kalender',
      monat: monat,
      heute: heute,
      gewaehlt: gewaehlt,
      aufFrueher: () => setState(() => _monat = monatVerschoben(monat, -1)),
      aufSpaeter: monat.isBefore(monatsErster(heute))
          ? () => setState(() => _monat = monatVerschoben(monat, 1))
          : null,
      aufTag: (tag) => ref
          .read(offenerTagProvider.notifier)
          .setze(BerlinCalendar.dayKey(tag)),
      tag: (tag) {
        final schluessel = BerlinCalendar.dayKey(tag);
        final wert = daten.tage[schluessel];
        return MonatsblattTag(
          ring: wert == null
              ? null
              : (ziffer) => KalenderAnteilRing(wert: wert, child: ziffer),
          tippbar: schluessel.compareTo(heuteSchluessel) <= 0,
        );
      },
      fuss:
          'Jeder Ring zeigt, wie viel vom Kalorienziel des Tages gegessen '
          'ist; voll heißt erreicht, rot heißt darüber. Ein leerer Ring: '
          'nichts eingetragen. Gestrichelt: Für diesen Tag gibt es kein '
          'Kalorienziel. Antippen öffnet den Tag. Blasse Tage ohne Ring '
          'liegen in der Zukunft.',
    );
  }
}

/// Der Berliner Tagesbeginn eines ISO-Tags — dieselbe Form, in der das
/// Monatsraster seine Tage führt.
DateTime _tagesbeginn(String tag) {
  final teile = tag.split('-').map(int.parse).toList();
  return BerlinCalendar.startOfDay(DateTime.utc(teile[0], teile[1], teile[2]));
}

/// Der Ring einer Tageszelle: Spur in [Palette.line], darauf **ein** Bogen
/// von oben im Uhrzeigersinn. Ohne Ziel gestrichelt — dasselbe Zeichen wie
/// „nicht gemessen" beim Schlaf.
class KalenderAnteilRing extends StatelessWidget {
  const KalenderAnteilRing({super.key, required this.wert, this.child});

  final KalenderRingWert wert;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (wert.ohneZiel) {
      return SegmentRingKlein(
        abschnitte: const [
          RingAbschnitt(
            anteil: 1,
            fuellung: 0,
            farbe: Palette.line,
            hatGrundlage: false,
          ),
        ],
        durchmesser: monatsblattRing,
        child: child,
      );
    }
    return SizedBox(
      width: monatsblattRing,
      height: monatsblattRing,
      child: CustomPaint(
        painter: _AnteilPainter(
          anteil: wert.anteil,
          spur: CupertinoDynamicColor.resolve(Palette.line, context),
          farbe: CupertinoDynamicColor.resolve(
            wert.ueber ? Palette.warn : Palette.river,
            context,
          ),
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _AnteilPainter extends CustomPainter {
  _AnteilPainter({
    required this.anteil,
    required this.spur,
    required this.farbe,
  });

  final double anteil;
  final Color spur;
  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final seite = math.min(size.width, size.height);
    final strich = seite * SegmentRingKlein.strichAnteil;
    final kreis = Rect.fromLTWH(
      strich / 2,
      strich / 2,
      seite - strich,
      seite - strich,
    );
    if (kreis.width <= 0) return;
    final stift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strich
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(kreis, 0, 2 * math.pi, false, stift..color = spur);
    // Erst über 2 % — ein Strichlein wäre ein Punkt, nicht „fast nichts".
    if (anteil > RingGeometrie.fuellSchwelle) {
      canvas.drawArc(
        kreis,
        -math.pi / 2,
        2 * math.pi * anteil.clamp(0.0, 1.0),
        false,
        stift..color = farbe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnteilPainter alt) =>
      alt.anteil != anteil || alt.spur != spur || alt.farbe != farbe;
}
