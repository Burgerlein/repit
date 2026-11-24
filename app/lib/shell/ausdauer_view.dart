// Der Ausdauer-Schirm (#95, mit #16) — VO₂max, die Halbmarathon-Prognose
// und die Verteilung auf die Herzfrequenz-Zonen. Der Zustand darunter
// liegt in `ausdauer_zustand.dart`.
//
// API und Verhalten sind durch `app/test/shell/ausdauer_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau und Beschriftung nach `docs/screens/screens/ausdauer.js`
// (a4077f3, Zustände `werte`/`laufband`/`leer`): Kopf → VO₂max-Kacheln →
// Verlauf (M 6M J) → HM-Prognose → Kadenz → Erholungspuls → Zonen →
// Verteilung → Watch-Anleitung → Fußnote. Der Leerzustand hat dieselbe
// Geometrie wie der gefüllte — dieselben Abschnitte, `–/–` statt
// weggelassener Karten, der Grund steht einmal oben.
//
// **Die Kadenz-Karte steht als ehrliche Keine-Werte-Form da:** Der Kanal
// liefert weder Schrittfrequenz noch Schritte im Lauf-Fenster, und eine
// Behelfsrechnung aus Stundenschritten wäre eine erfundene Zahl. Die
// Karte bleibt in der Geometrie des Entwurfs stehen und sagt, dass die
// Quelle noch fehlt — Kanal-Erweiterung als Folgearbeit.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../design/formatierung.dart' show kalendertag;
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/kacheln.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/zahlen.dart';
import '../design/zeitdiagramm.dart';
import '../ziele/ziele_view.dart';
import 'ausdauer_zustand.dart';
import 'mess_abschnitte.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet den Ausdauer-Schirm auf dem Stapel des **aktuell gewählten**
/// Tabs — gerufen aus `MehrView`. Über `AppTarget.aktuell(...)`, nie über
/// einen Tab-Wechsel (`CLAUDE.md`).
void oeffneAusdauer(AppRouter router) {
  router.open(AppTarget.aktuell((context) => AusdauerSeite(router: router)));
}

/// Der Rahmen: Gerüst und Navigationsleiste um [AusdauerView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
class AusdauerSeite extends StatelessWidget {
  const AusdauerSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Ausdauer')),
      child: AusdauerView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([ausdauerProvider]): Jeder Schirm
/// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass
/// eine Übersicht vorher geladen hat.
class AusdauerView extends ConsumerWidget {
  const AusdauerView({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messwert = ref.watch(ausdauerProvider);
    final lage = messLageAus(messwert);
    final zustand = messwert is Bekannt<AusdauerDaten> ? messwert.wert : null;

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift(
            'Ausdauer',
            einordnung: 'VO₂max, Prognose und Herzfrequenz-Zonen',
          ),
          LageZeile(
            key: switch (lage) {
              MessLage.laedt => const Key('ausdauer-laden'),
              MessLage.fehler => const Key('ausdauer-fehler'),
              MessLage.werte || MessLage.leer => null,
            },
            lage: lage,
            stand: _alsBerlinerWanduhr(standAus(messwert)),
            laeuft: messwert is Bekannt<AusdauerDaten> && messwert.laeuft,
          ),
          // Der Grund, **einmal** oben und nur bei `LeerNachLauf` — nicht
          // während des Laufs (Fehler `01`), nicht nach einem Fehler.
          if (lage == MessLage.leer)
            const Notizflaeche(
              key: Key('ausdauer-grund'),
              text:
                  'Noch kein Lauf und keine VO₂max in Apple Health. Die '
                  'Watch schätzt VO₂max nur draußen mit GPS; die eigene '
                  'Schätzung braucht einen Lauf ab drei Minuten. Fehlen '
                  'die Werte trotzdem, kann es an der Health-Freigabe '
                  'liegen — Apple verrät den Unterschied nicht.',
              oben: 0,
            ),
          const SectionHeader('VO₂max'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Kacheln([
              KachelWert(
                schluessel: const Key('ausdauer-watch'),
                label: 'Watch',
                wert: zustand?.watchAktuell == null
                    ? null
                    : formatNumber(
                        zustand!.watchAktuell!,
                        nachkommastellen: 1,
                      ),
                einheit: 'ml/kg/min',
                zusatz: 'nur draußen mit GPS',
                farbe: CupertinoDynamicColor.resolve(Palette.ok, context),
                platzhalter: lage == MessLage.laedt ? '00,0' : null,
              ),
              KachelWert(
                schluessel: const Key('ausdauer-eigene'),
                label: 'Eigene Schätzung',
                wert: zustand?.eigeneAktuell == null
                    ? null
                    : formatNumber(
                        zustand!.eigeneAktuell!,
                        nachkommastellen: 1,
                      ),
                einheit: 'ml/kg/min',
                zusatz: 'aus jedem Lauf ab 3 min',
                farbe: CupertinoDynamicColor.resolve(Palette.river, context),
                platzhalter: lage == MessLage.laedt ? '00,0' : null,
              ),
            ]),
          ),
          const SizedBox(height: 14),
          _Einordnung(lage: lage, zustand: zustand),
          const SectionHeader('Verlauf'),
          _Verlauf(zustand: zustand),
          const SectionHeader('Halbmarathon-Prognose'),
          _Prognose(lage: lage, zustand: zustand, router: router),
          const SectionHeader('Kadenz'),
          MessKarte(
            key: const Key('ausdauer-kadenz'),
            zeilen: const [
              // Ehrlich leer: keine Quelle, keine Behelfsrechnung — und
              // keine graue Fläche, denn hier kommt (noch) kein Wert. Der
              // Zielkorridor steht in der Fußzeile, nicht in der Karte:
              // In der Karte sähe „165–175" neben zwei leeren Zeilen aus
              // wie ein Messwert.
              MessZeileDaten(name: 'Letzter Lauf im Schnitt'),
              MessZeileDaten(name: 'Erstes → letztes Drittel'),
            ],
          ),
          const Hinweisfuss(
            'Zielbereich sind 165–175 Schritte pro Minute. Die '
            'Schrittfrequenz je Lauf liefert der Health-Kanal noch nicht — '
            'die Kadenz folgt in einer späteren Aufgabe.',
          ),
          const SectionHeader('Erholungspuls'),
          _Erholungspuls(lage: lage, zustand: zustand),
          const Hinweisfuss(
            'Unabhängiger Formindikator zwischen zwei VO₂max-Werten der '
            'Watch. Er fließt nicht in die Erholungs-Ampel ein.',
          ),
          const SectionHeader('Herzfrequenz-Zonen'),
          _Zonen(lage: lage, zustand: zustand),
          const SectionHeader('Verteilung der Laufzeit'),
          _Verteilung(lage: lage, zustand: zustand),
          const SectionHeader('Apple Watch einstellen'),
          _WatchSchritte(zustand: zustand),
          const Hinweisfuss(
            'VO₂max, eigene Schätzung und Prognose sind Rechenwerte, kein '
            'Labortest. Die Zonen rechnen sich nach der Herzfrequenzreserve '
            '(Karvonen); die Apple Watch nutzt dieselbe Methode. Keine '
            'medizinische Bewertung.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Einordnung und Trend
// ─────────────────────────────────────────────────────────────────────────

class _Einordnung extends StatelessWidget {
  const _Einordnung({required this.lage, required this.zustand});

  final MessLage lage;
  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final einordnung = zustand?.einordnung;
    final trend = zustand?.trendDelta;

    return MessKarte(
      key: const Key('ausdauer-einordnung'),
      zeilen: [
        zeileMitLage(
          lage,
          name: 'Einordnung',
          wert: einordnung == null ? ohneEinzelwert : _stufe(einordnung),
          beispiel: 'sehr gut',
        ).mitKennzeichen(_einordnungsHerkunft(zustand)),
        zeileMitLage(
          lage,
          name: 'Trend der Watch',
          wert: trend == null ? ohneEinzelwert : mitVorzeichen(trend),
          beispiel: '+0,0',
        ).mitKennzeichen(trend == null ? null : 'in drei Monaten'),
      ],
    );
  }

  /// Die fünf Stufen aus SPEC 4.7 als Nutzertext — Nutzertexte gehören in
  /// die View, nicht in den Kern (`CLAUDE.md`).
  String _stufe(VO2MaxRating einordnung) => switch (einordnung) {
    VO2MaxRating.belowAverage => 'unterdurchschnittlich',
    VO2MaxRating.average => 'durchschnittlich',
    VO2MaxRating.good => 'gut',
    VO2MaxRating.veryGood => 'sehr gut',
    VO2MaxRating.excellent => 'hervorragend',
  };
}

/// Woraus die Einordnung rechnet: Die Vergleichstabelle gilt für Männer
/// 20–29 (SPEC 4.7) — und ohne Watch-Wert steht die Herkunft dran
/// (Entwurf, Variante `laufband`).
String? _einordnungsHerkunft(AusdauerDaten? zustand) =>
    switch (zustand?.quelle) {
      null => null,
      PrognoseQuelle.watch => 'Männer 20–29',
      PrognoseQuelle.eigeneSchaetzung => 'aus der eigenen Schätzung',
    };

// ─────────────────────────────────────────────────────────────────────────
// Verlauf
// ─────────────────────────────────────────────────────────────────────────

class _Verlauf extends StatelessWidget {
  const _Verlauf({required this.zustand});

  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final watch = zustand?.watchReihe ?? const <MeasurementPoint>[];
    final eigene = zustand?.eigeneReihe ?? const <MeasurementPoint>[];

    // Die Kopfzeile des Diagramms gehört der ersten Reihe. Ohne einen
    // einzigen Watch-Wert trägt die eigene Schätzung den Verlauf (Entwurf,
    // Variante `laufband`) — sonst stünde „—" über einer gezeichneten
    // Kurve.
    final eigeneTraegt = watch.isEmpty && eigene.isNotEmpty;
    final erste = eigeneTraegt ? eigene : watch;
    final zweite = eigeneTraegt ? const <MeasurementPoint>[] : eigene;

    return Padding(
      key: const Key('ausdauer-diagramm'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Zeitdiagramm(
        reihe: [
          for (final punkt in erste) (tag: punkt.date, wert: punkt.value),
        ],
        zweiteReihe: [
          for (final punkt in zweite) (tag: punkt.date, wert: punkt.value),
        ],
        zweiteFarbe: Palette.river,
        stufen: ausdauerStufen,
        alsBalken: false,
        einheit: 'ml/kg/min',
        kopfzahl: (wert) => formatNumber(wert, nachkommastellen: 1),
        fussnote: (_) => eigeneTraegt
            ? 'Kein Watch-Wert: Die Watch schätzt VO₂max nur draußen mit '
                  'GPS. Die eigene Schätzung entsteht aus jedem Lauf ab '
                  'drei Minuten — auch auf dem Laufband.'
            : 'Jeder Wert ein Punkt. Die Watch schätzt nur draußen mit GPS '
                  'und bewegt sich träge; die eigene Schätzung (gestrichelt) '
                  'entsteht aus jedem Lauf ab drei Minuten und reagiert '
                  'schneller.',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Halbmarathon-Prognose
// ─────────────────────────────────────────────────────────────────────────

class _Prognose extends StatelessWidget {
  const _Prognose({
    required this.lage,
    required this.zustand,
    required this.router,
  });

  final MessLage lage;
  final AusdauerDaten? zustand;
  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    final potenzial = zustand?.potenzialMinuten;
    final realistisch = zustand?.realistischMinuten;

    return MessKarte(
      key: const Key('ausdauer-prognose'),
      zeilen: [
        zeileMitLage(
          lage,
          name: 'Potenzial',
          wert: potenzial == null ? ohneEinzelwert : _zeit(potenzial),
          beispiel: '0:00 h',
        ).mitKennzeichen(
          zustand?.quelle == PrognoseQuelle.eigeneSchaetzung
              ? 'aus der eigenen Schätzung'
              : 'Daniels-VDOT',
        ),
        zeileMitLage(
          lage,
          name: 'Realistisch für Einsteiger',
          wert: realistisch == null ? ohneEinzelwert : _zeit(realistisch),
          beispiel: '0:00 h',
        ).mitKennzeichen('Potenzial × 1,12'),
        // Die Zielzeit kommt aus dem Wettkampf-Objekt — das es im Neubau
        // noch nicht gibt (#95, Fallstricke: **nie** aus dem Quelltext).
        // Bis dahin: kein Wert, und die Zeile ist die Tür auf Ziele.
        MessZeileDaten(
          schluessel: const Key('ausdauer-zielzeit'),
          name: 'Zielzeit',
          kennzeichen: 'aus dem Wettkampf',
          wert: ohneEinzelwert,
          aufTippen: () => oeffneZiele(router),
        ),
      ],
    );
  }

  /// Minuten als „1:38 h" — auf ganze Minuten gerundet.
  String _zeit(double minuten) {
    final ganz = minuten.round();
    final h = ganz ~/ Duration.minutesPerHour;
    final min = ganz % Duration.minutesPerHour;
    return '$h:${min.toString().padLeft(2, '0')} h';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Erholungspuls
// ─────────────────────────────────────────────────────────────────────────

class _Erholungspuls extends StatelessWidget {
  const _Erholungspuls({required this.lage, required this.zustand});

  final MessLage lage;
  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final juengster = zustand?.erholungJuengster;
    final schnitt = zustand?.erholungSchnitt30;

    return MessKarte(
      key: const Key('ausdauer-erholungspuls'),
      zeilen: [
        zeileMitLage(
          lage,
          name: 'Abfall 1 min nach Belastung',
          wert: juengster == null ? ohneEinzelwert : '−$juengster bpm',
          beispiel: '−00 bpm',
        ).mitKennzeichen('höchster Wert des Tages'),
        zeileMitLage(
          lage,
          name: 'Ø letzte 30 Tage',
          wert: schnitt == null
              ? ohneEinzelwert
              : '−${formatNumber(schnitt)} bpm',
          beispiel: '−00 bpm',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Zonen
// ─────────────────────────────────────────────────────────────────────────

/// Die **angezeigte** Obergrenze einer Zone.
///
/// Der Kern rechnet beide Grenzen aus derselben Zahl: `zone[n].upper` und
/// `zone[n+1].lower` sind identisch (`heart_rate_zones.dart`), und
/// `ZoneDistribution._zoneOf` schlägt einen Puls auf einer Grenze der
/// **oberen** Zone zu. Angezeigt gehört die Grenze deshalb nur einmal hin
/// — sonst stünde dieselbe bpm-Zahl in zwei Zonen und widerspräche der
/// eigenen Zählung.
///
/// Die fünfte Zone behält ihre Obergrenze: Sie ist die HFmax und gehört
/// keiner Zone darüber. (Ein Puls oberhalb zählt weiter zu Zone 5 — mehr
/// als maximal gibt es nicht.)
///
/// **Eine Stelle für beide Anzeigen**: Zonenkarte und Watch-Anleitung
/// lesen hier. Was der Schirm als Obergrenze nennt, wird in die Watch
/// eingetragen; zwei Rechnungen wären zwei Zählweisen.
int _angezeigteObergrenze(HeartRateZone zone) =>
    zone.number >= 5 ? zone.upper : zone.upper - 1;

/// Die fünf Zeilennamen — dieselben in jedem Zustand (Entwurf `ZONEN`).
const List<String> _zonenNamen = [
  'Zone 1 · regenerativ',
  'Zone 2 · Grundlage',
  'Zone 3 · Tempo',
  'Zone 4 · Schwelle',
  'Zone 5 · maximal',
];

class _Zonen extends StatelessWidget {
  const _Zonen({required this.lage, required this.zustand});

  final MessLage lage;
  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final zonen = zustand?.zonen;

    return Column(
      key: const Key('ausdauer-zonen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MessKarte(
          zeilen: [
            for (var i = 0; i < _zonenNamen.length; i++)
              zeileMitLage(
                lage,
                name: _zonenNamen[i],
                wert: zonen == null
                    ? ohneEinzelwert
                    : '${zonen.zones[i].lower}–'
                          '${_angezeigteObergrenze(zonen.zones[i])} bpm',
                beispiel: '000–000 bpm',
              ),
          ],
        ),
        const Hinweisfuss(
          'Faustregel: Zone 2 heißt, in ganzen Sätzen sprechen können.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: IconRow(
              title: 'HFmax und Ruhepuls anpassen',
              subtitle: _herkunft(lage, zustand),
              symbol: 'heart',
              accent: CupertinoDynamicColor.resolve(Palette.river, context),
              value: 'Karvonen',
              untertitelZeilen: 2,
            ),
          ),
        ),
      ],
    );
  }

  /// Woraus die Zonen gerechnet sind — die Quelle des Ruhepulses muss
  /// dastehen, sonst sieht eine allgemeine Annahme wie eine Messung aus.
  ///
  /// **„noch keine Pulswerte" ist eine Auskunft über die Daten** und steht
  /// deshalb allein bei [MessLage.leer]: Beim Laden weiß die App noch
  /// nicht, ob Pulswerte vorliegen, und ein Fehler sagt nichts über die
  /// Datenlage (`CLAUDE.md`, Fehler `01`). In beiden Fällen steht hier
  /// stattdessen, **wie** die Zonen entstehen — eine Beschreibung, keine
  /// Behauptung, und in derselben Geometrie (`untertitelZeilen: 2`).
  ///
  /// Kein grauer Platzhalter: `IconRow.laedt` setzt Titel **und**
  /// Untertitel als Form, und der Titel ist hier keine Aussage über die
  /// Datenlage — er darf stehen bleiben.
  String _herkunft(MessLage lage, AusdauerDaten? zustand) {
    if (zustand == null) {
      return switch (lage) {
        MessLage.laedt ||
        MessLage.fehler => 'HFmax und Ruhepuls bestimmen die Grenzen.',
        MessLage.leer ||
        MessLage.werte => 'noch keine Pulswerte',
      };
    }
    final quelle = switch (zustand.ruhepulsQuelle) {
      RestingManual() => 'von Hand gesetzt',
      RestingMedian(:final sampleCount) => 'Median aus $sampleCount Werten',
      RestingEstimate() => 'allgemeine Annahme, noch zu wenige Messwerte',
    };
    final geklemmt = zustand.zonen.clamped
        ? ' — Ruhepuls zu nah an der HFmax, geklemmt'
        : '';
    return 'aus HFmax $ausdauerHfMax und Ruhepuls '
        '${zustand.ruhepulsBpm} ($quelle)$geklemmt';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Verteilung der Laufzeit
// ─────────────────────────────────────────────────────────────────────────

/// Die Balkenfarben je Zone — `river2, ok, bib, warn, warn` im Entwurf;
/// `river2` gibt es in der Palette nicht, `river` ist derselbe Ton.
const List<CupertinoDynamicColor> _zonenFarben = [
  Palette.river,
  Palette.ok,
  Palette.bib,
  Palette.warn,
  Palette.warn,
];

class _Verteilung extends StatelessWidget {
  const _Verteilung({required this.lage, required this.zustand});

  final MessLage lage;
  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final anteil = zustand?.anteilZone12;

    // Gesamtminuten über **alle sechs** Anteile (Zone 0 zählt zur Summe,
    // gezeichnet werden die fünf benannten Zonen wie im Entwurf).
    var gesamt = 0.0;
    for (final share in zustand?.verteilung ?? const <ZoneShare>[]) {
      gesamt += share.minutes;
    }

    double? anteilVon(int zone) {
      final verteilung = zustand?.verteilung;
      if (verteilung == null || gesamt <= 0) return null;
      return verteilung[zone].minutes / gesamt;
    }

    return Column(
      key: const Key('ausdauer-verteilung'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Der Grund „noch kein Lauf" steht nur, wenn ein Lauf
                    // tatsächlich nichts ergab — nicht während des Ladens
                    // und nicht nach einem Fehler (Fehler `01`).
                    gesamt <= 0 &&
                            (lage == MessLage.werte || lage == MessLage.leer)
                        ? 'Anteil der Laufzeit je Zone — noch kein Lauf '
                              'mit Pulsmessung.'
                        : 'Anteil der Laufzeit je Zone, letzte 30 Tage.',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 10),
                  for (var zone = 1; zone <= 5; zone++) ...[
                    _ZonenBalken(
                      name: _zonenNamen[zone - 1],
                      anteil: anteilVon(zone),
                      farbe: _zonenFarben[zone - 1],
                      lage: lage,
                    ),
                    if (zone < 5) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Der 80-%-Satz ist die Aussage, wegen der die Verteilung dasteht
        // (SPEC 4.7). Er steht, sobald es gezählte Laufzeit gibt — unter
        // dem Ziel als Warnung (Wortlaut aus dem Entwurf), darüber als
        // Bestätigung.
        if (anteil != null)
          Notizflaeche(
            ton: anteil < 0.8 ? Palette.warn : Palette.ok,
            text: anteil < 0.8
                ? '${formatNumber(anteil * 100)} % in Zone 1–2, Ziel sind '
                      'mindestens 80 %. Zu harte „lockere" Läufe sind der '
                      'häufigste Fehler beim Grundlagenaufbau — und sie '
                      'drücken die Erholung.'
                : '${formatNumber(anteil * 100)} % in Zone 1–2 — das Ziel '
                      'von mindestens 80 % ist erreicht.',
          ),
      ],
    );
  }
}

/// Ein Balken der Verteilung — `macroBar` aus dem Entwurf, hier ohne
/// Zielwert: Name und Prozent in einer Zeile, darunter der gefüllte
/// Anteil. Ohne Wert bleibt der Balken leer und rechts steht [ohneEinzelwert]
/// — **nie `0 %`**, das behauptete einen gemessenen Lauf (Fehler `01`).
class _ZonenBalken extends StatelessWidget {
  const _ZonenBalken({
    required this.name,
    required this.anteil,
    required this.farbe,
    required this.lage,
  });

  final String name;
  final double? anteil;
  final CupertinoDynamicColor farbe;

  /// Die Lage des ganzen Schirms — der Balken braucht sie für zweierlei:
  /// die graue Form (nur im Ladezustand) und den Vorlesetext.
  final MessLage lage;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final wertStil = TextStyle(fontSize: 13, color: muted);
    final anteil = this.anteil;
    final laedt = lage == MessLage.laedt;

    return Semantics(
      // Der Vorlesetext nennt den **Zustand**, nicht das Zeichen
      // (`CLAUDE.md`) — und „keine Laufzeit" ist eine Auskunft über die
      // Daten: Sie gilt nur, wenn ein Lauf das ergeben hat. Über einem
      // Platzhalter heißt es „wird geladen", nach einem Fehler „kein
      // Wert"; beides sagt nichts über die Datenlage (Fehler `01`).
      label: switch ((anteil, lage)) {
        (final anteil?, _) =>
          '$name, ${formatNumber(anteil * 100)} Prozent',
        (null, MessLage.laedt) => '$name, wird geladen',
        (null, MessLage.fehler) => '$name, kein Wert',
        (null, MessLage.werte || MessLage.leer) => '$name, keine Laufzeit',
      },
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              if (anteil == null && laedt)
                Platzhalter(beispiel: '00 %', stil: wertStil)
              else
                Text(
                  anteil == null
                      ? ohneEinzelwert
                      : '${formatNumber(anteil * 100)} %',
                  style: wertStil,
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: line,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (anteil ?? 0).clamp(0.0, 1.0),
                child: Container(
                  color: CupertinoDynamicColor.resolve(farbe, context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Apple Watch einstellen
// ─────────────────────────────────────────────────────────────────────────

class _WatchSchritte extends StatelessWidget {
  const _WatchSchritte({required this.zustand});

  final AusdauerDaten? zustand;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 13, height: 1.4, color: muted);
    final zonen = zustand?.zonen;

    final obergrenzen = zonen == null
        ? 'die Obergrenzen stehen hier, sobald die Zonen berechnet sind'
        : [
            for (var i = 0; i < 4; i++)
              'Zone ${zonen.zones[i].number} bis '
                  '${_angezeigteObergrenze(zonen.zones[i])}',
          ].join(', ');

    return Padding(
      key: const Key('ausdauer-watch-schritte'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. iPhone: Einstellungen → Training → Herzfrequenzzonen.',
                style: stil,
              ),
              const SizedBox(height: 6),
              Text(
                '2. Auf „Manuell" stellen und die Obergrenzen eintragen: '
                '$obergrenzen.',
                style: stil,
              ),
              const SizedBox(height: 6),
              Text(
                '3. Beim Laufen auf der Watch zur Ansicht '
                '„Herzfrequenzzonen" wischen. Bei lockeren Läufen soll die '
                'Anzeige in Zone 2 bleiben.',
                style: stil,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

/// Der Stand als Berliner Wanduhrzeit — die Anzeige eines Instants läuft
/// app-weit über [BerlinCalendar.wallClock] (vgl. `schlaf_texte.dart`,
/// `mahlzeit_view.dart`): Der Zeitstempel bezeichnet einen Zeitpunkt, die
/// Zeile zeigt, was die Berliner Uhr da zeigte. Auf dem Gerät (lokale
/// Uhr = Berlin) ändert das nichts; es hält die Zeile nur auch dann
/// richtig, wenn der Zeitstempel als UTC vorliegt.
DateTime? _alsBerlinerWanduhr(DateTime? stand) {
  if (stand == null) return null;
  final (stunde, minute) = BerlinCalendar.wallClock(stand);
  final tag = kalendertag(stand);
  return DateTime(tag.year, tag.month, tag.day, stunde, minute);
}

/// Hängt ein Kennzeichen an eine über [zeileMitLage] gebaute Zeile —
/// `statRow(name, wert, tag)` im Entwurf trägt es in jedem Zustand.
extension on MessZeileDaten {
  MessZeileDaten mitKennzeichen(String? kennzeichen) => MessZeileDaten(
    schluessel: schluessel,
    name: name,
    wert: wert,
    platzhalter: platzhalter,
    kennzeichen: kennzeichen,
  );
}
