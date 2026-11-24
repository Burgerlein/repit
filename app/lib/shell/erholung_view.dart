// Der Schirm `erholung` (#115) — der letzte Baustein des Erholung-Ports.
// Der Zustand darunter liegt in `erholung_zustand.dart`, die einzelnen
// Abschnitte in `erholung_abschnitte.dart`.
//
// API und Verhalten sind durch `app/test/shell/erholung_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau und Beschriftung nach `docs/prototype/erholung-alles.html` und
// `docs/superpowers/specs/2026-10-26-erholung-flutter-design.md`,
// Abschnitt 3; die Nutzertexte wörtlich aus
// `docs/superpowers/plans/2026-10-27-erholung-schirm-texte.md`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ziele.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/ring_karte.dart';
import '../design/stand_zeile.dart';
import '../health/health_provider.dart';
import 'belastung_view.dart';
import 'erholung_abschnitte.dart';
import 'erholung_nacht.dart';
import 'erholung_werte_view.dart';
import 'erholung_zustand.dart';
import 'router.dart';
import 'schlaf_eintragen.dart';
import 'schlaf_view.dart';
import 'tagschlaf_view.dart';
import 'verlauf_view.dart';
import 'ziele.dart';

/// Öffnet den Erholung-Schirm auf dem Stapel des **aktuell gewählten** Tabs.
///
/// Die eine Stelle, die das weiß: `MehrView` und die Erholungskarte auf
/// Heute rufen beide hierher. Über `AppTarget.aktuell(...)`, nie über einen
/// Tab-Wechsel — sonst führte „zurück" in ein Menü, das der Nutzer nie
/// geöffnet hat (`CLAUDE.md`).
void oeffneErholung(AppRouter router) {
  router.open(AppTarget.aktuell((context) => ErholungSeite(router: router)));
}

/// Der Rahmen: Gerüst und Navigationsleiste um [ErholungView].
///
/// Den stellt der Gastgeber, nicht der Schirm — wie `_HealthKitTestSeite` in
/// `mehr_view.dart`. **Kein eigener `Navigator`:** Diese Ansicht wird auf den
/// Stapel eines Tabs geschoben, der Stapel gehört weiter `RootView`.
class ErholungSeite extends StatelessWidget {
  const ErholungSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Erholung')),
      child: ErholungView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([erholungProvider]): Seit jeder Schirm
/// aus jedem Tab direkt erreichbar ist, kann niemand sich darauf verlassen,
/// dass eine Übersicht vorher geladen hat.
class ErholungView extends ConsumerWidget {
  const ErholungView({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(erholungProvider);
    final jetzt = ref.watch(clockProvider)();

    final tag = kalendertag(jetzt);

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Abschnitt 1 — hängt nicht an Apple Health und steht deshalb in
          // jedem der vier Zustände.
          //
          // **Keine grosse Ueberschrift.** Der Entwurf hat ueber der
          // Datumszeile nichts: Die Navigationsleiste nennt den Schirm
          // bereits, und zweimal derselbe Titel uebereinander ist kein
          // Aufbau, sondern ein Versehen.
          _Datumszeile(tag),
          if (zustand.daten case Bekannt<ErholungDaten> bekannt)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StandZeile(bekannt, jetzt: ref.watch(clockProvider)()),
            ),

          // Abschnitte 2, 3 und 3b — die Health-Hälfte.
          ...switch (zustand.daten) {
            NochNie<ErholungDaten>() => const [_Laden()],
            Bekannt<ErholungDaten>(:final wert) => _ringteil(
              context: context,
              daten: wert,
              ziele: zustand.ziele,
              tag: tag,
            ),
            LeerNachLauf<ErholungDaten>() => [
              ErholungHinweiskasten(
                key: const Key('erholung-hinweiskasten'),
                hinweis: erholungHinweis(
                  bewertung: const RecoveryEvaluation(
                    verdict: RecoveryVerdict.noData,
                    signals: [],
                    measuredCount: 0,
                  ),
                  messwerte: const RecoveryReading(),
                  baseline: const RecoveryBaseline(),
                )!,
                onHealthEinstellungen: () => _zeigeHealthHinweis(context),
                onSchlafNachtragen: () => _zeigeNachtragen(context, tag),
              ),
            ],
            // Ein Fehler ist keine Aussage über die Datenlage: Hier steht
            // **kein** Grund und kein Weg in die Health-Einstellungen.
            Fehlgeschlagen<ErholungDaten>() => const [_Fehler()],
          },

          // Abschnitte 5, 5b und 6 — nur mit Werten. (Abschnitt 4 war die
          // Gefühlszeile; sie ist am 03.11.2026 mit #269 entfallen.)
          if (zustand.daten case Bekannt<ErholungDaten>(
            :final wert,
            :final laeuft,
          )) ...[
            // Die Nachtkarte ist **keine** Tür: Auf den Schlaf-Schirm
            // führt seit #259 nur noch der Schlaf-Ring oben (Tim,
            // 03.11.2026). Dauer, Zeitfenster und Score bleiben stehen.
            ErholungNachtkarte(
              nacht: wert.nacht,
              kern: wert.schnappschuss.night,
              score: wert.schnappschuss.score,
              laeuft: laeuft,
            ),
            // **Auch ohne Nacht** (#209): Ein Nickerchen braucht keine.
            // Der eingetragene Tagschlaf kommt zu den gemessenen dazu,
            // statt eines zu ersetzen.
            if ((wert.nacht?.naps.isNotEmpty ?? false) ||
                wert.napEintraege.isNotEmpty)
              ErholungTagschlaf(
                naps: wert.nacht?.naps ?? const [],
                napEintraege: wert.napEintraege,
                // Ausdrücklich **nicht** der Schlaf-Schirm: Dort stünde
                // die Nacht oben und das Nickerchen weit unten.
                onTagschlaf: () => oeffneTagschlaf(router),
              ),
            ErholungVerlaeufe(
              trends: wert.schnappschuss.trends,
              messwerte: wert.schnappschuss.reading,
              baseline: wert.schnappschuss.baseline,
              // Ob überhaupt geurteilt wurde, entscheidet die Ampel, nicht
              // die Zeile (#308) — nach der OP ruht sie, und dann bleiben
              // die vier Werte ungefärbt, genau wie auf Heute.
              bewertung: wert.schnappschuss.evaluation,
              // Ob am Vortag des gezeigten Tages Alkohol erfasst ist
              // (#268) — vom Schnappschuss, nicht hier gerechnet: Der
              // Vortag ist eine Kalenderangabe, und die Tagesgrenze
              // gehört in den Kern.
              alkoholVortag: wert.schnappschuss.alcoholEve,
              // Jede Zeile führt auf den Verlauf *ihres* Wertes; welche
              // Zeile überhaupt eine Tür ist, entscheidet `verlaufArtZu`
              // in `ErholungVerlaeufe`, nicht dieser Schirm.
              onVerlauf: (art) => oeffneVerlauf(router, art),
            ),
          ],

          // Abschnitte 7 und 8.
          const ErholungTipps(key: Key('erholung-tipps')),
          const Hinweisfuss(
            'Die Ampel vergleicht Schlaf, HRV, Ruhepuls und Atemfrequenz mit '
            'deinem eigenen Median der letzten 30 Tage. Grobe Orientierung, '
            'keine medizinische Bewertung — dein Gefühl zählt mit.',
          ),
        ],
      ),
    );
  }

  /// Ringkarte und, wenn es etwas zu sagen gibt, der Hinweiskasten darunter.
  List<Widget> _ringteil({
    required BuildContext context,
    required ErholungDaten daten,
    required Ziele ziele,
    required DateTime tag,
  }) {
    final schnappschuss = daten.schnappschuss;
    final bewertung = schnappschuss.evaluation;
    final hinweis = erholungHinweis(
      bewertung: bewertung,
      messwerte: schnappschuss.reading,
      baseline: schnappschuss.baseline,
    );

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: RingKarte(
          daten: _ringe(daten, ziele, bewertung),
          onSchlaf: () => oeffneSchlaf(router),
          onErholung: () => oeffneErholungWerte(router),
          onBelastung: () => oeffneBelastung(router),
          onHilfe: () => _zeigeHilfe(context),
        ),
      ),
      if (hinweis != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ErholungHinweiskasten(
            key: const Key('erholung-hinweiskasten'),
            hinweis: hinweis,
            onHealthEinstellungen: () => _zeigeHealthHinweis(context),
            onSchlafNachtragen: () => _zeigeNachtragen(context, tag),
          ),
        ),
    ];
  }

  RingKartenDaten _ringe(
    ErholungDaten daten,
    Ziele ziele,
    RecoveryEvaluation bewertung,
  ) {
    final schnappschuss = daten.schnappschuss;
    final score = schnappschuss.score;
    final nacht = schnappschuss.night;

    return RingKartenDaten(
      schlaf: score == null || nacht == null
          ? ErholungRinge.schlafOhneNacht()
          : ErholungRinge.schlaf(
              gesamt: score.total,
              punkteDauer: score.duration,
              punkteZubettgehzeit: score.bedtime,
              // Seit #131 kann die Teilnote Unterbrechungen entfallen —
              // **hier aber nicht.** Der Schnappschuss rechnet über
              // `SleepScoring.series`, und `RecoveryNight` trägt
              // Wachminuten und Wachphasen immer mit; eine von Hand
              // eingetragene Nacht erreicht diesen Schirm nicht (sie
              // liegt in `schlafEintraegeProvider` und wird bislang nur
              // auf dem Schlaf-Schirm darübergelegt). Käme sie je hier
              // an, ist das ein Programmierfehler — dann soll es laut
              // scheitern, statt eine erfundene Null in den Ring zu
              // schreiben.
              punkteUnterbrechungen: score.interruptions!,
              dauer: dauerText(nacht.asleepMinutes),
            ),
      erholung: switch (bewertung.verdict) {
        RecoveryVerdict.noData => ErholungRinge.erholungOhneWerte(),
        RecoveryVerdict.postOperative => ErholungRinge.erholungNachOp(),
        _ => ErholungRinge.erholung(
          signale: [
            for (final signal in bewertung.signals) _alsRingwert(signal),
          ],
        ),
      },
      belastung: ErholungRinge.belastung(
        wochenminuten: daten.wochenminuten,
        // Das Wochenziel kommt aus den Zielen, nie als Zahl aus dem
        // Quelltext.
        wochenziel: ziele.wochenzielTrainingsminuten.toDouble(),
      ),
    );
  }

  /// Die Hilfe ist **kein** Sprung in einen anderen Schirm — sie geht hier
  /// auf und wieder zu. Ein Knopf, der nichts auslöst, wäre derselbe Fehler
  /// wie eine stumme Zeile, die aussieht wie eine Tür.
  void _zeigeHilfe(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Was die Ringe bedeuten'),
        content: const Text(
          'Links der Schlaf-Score aus Dauer, Zubettgehzeit und '
          'Unterbrechungen. In der Mitte die Zahl der Warnsignale: je ein '
          'Viertel für Schlaf, Ruhepuls, HRV und Atemfrequenz, verglichen '
          'mit deinem eigenen Median. Rechts die Trainingsminuten dieser '
          'Woche gegen dein Wochenziel.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  /// Der zweite Weg aus derselben Lücke — **und seit #131 führt er
  /// hierher statt in einen Hinweis.**
  ///
  /// Bis zum 29.10.2026 öffnete dieser Knopf einen Dialog „ist noch nicht
  /// gebaut". Der Grund war nicht der fehlende Schlaf-Schirm (den gibt es
  /// seit #92), sondern das fehlende **Formular**; es ist laut Entwurf ein
  /// Zustand von `schlaf`, kein eigener Schirm. Jetzt gibt es das Formular,
  /// und der Knopf öffnet genau dieses.
  ///
  /// **Er springt weiterhin nirgendwohin.** Das Formular ist ein Blatt über
  /// dem aktuellen Schirm, kein Eintrag im Navigationsstapel — wer ihn
  /// drückt, bleibt auf der Erholungsseite und steht nach dem Sichern
  /// wieder dort. Ein Sprung auf den Schlaf-Schirm wäre der Umweg, den
  /// `erholung_view_test.dart` zu Recht ausschließt.
  ///
  /// Der vorbelegte Tag ist der **heutige**: Der Knopf steht nur, wo für
  /// heute nichts vorliegt.
  void _zeigeNachtragen(BuildContext context, DateTime tag) {
    zeigeSchlafEintragen(context, art: SchlafEintragenArt.nacht, tag: tag);
  }

  /// `app/` hat kein `url_launcher`, also kann dieser Knopf
  /// `x-apple-health://` noch nicht selbst öffnen. Statt stumm zu bleiben
  /// sagt er, welchen Weg der Nutzer von Hand geht — der tatsächliche Sprung
  /// gehört in eine eigene Aufgabe.
  void _zeigeHealthHinweis(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Health-Einstellungen'),
        content: const Text(
          'In der Health-App unter „Profil ▸ Apps ▸ Trainings" lässt sich '
          'der Lesezugriff für Schlaf, HRV, Ruhepuls und Atemfrequenz '
          'einschalten.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }
}

/// Die Vertragsreihenfolge der vier Viertel liegt in [ErholungWert]; diese
/// Abbildung ist die einzige Stelle, an der die Metrik des Kerns und das
/// Viertel des Rings einander zugeordnet werden.
ErholungWert _alsRingwert(RecoveryMetric metrik) => switch (metrik) {
  RecoveryMetric.sleep => ErholungWert.schlaf,
  RecoveryMetric.restingHeartRate => ErholungWert.ruhepuls,
  RecoveryMetric.hrv => ErholungWert.hrv,
  RecoveryMetric.respiratoryRate => ErholungWert.atemfrequenz,
};

/// Abschnitt 1: **nur das Datum, zentriert.**
///
/// Tim am 27.10.2026: „lass uns das Datum mittig hin platzieren, so
/// 27.Oktober.2026. Aber den Text drum rum nicht." Damit sind Wochentag
/// und Nachtbezug beide weg — Spec 10a Punkt 2 ist zurückgenommen. Die
/// Begründung für den Nachtbezug („auf welche Nacht bezieht sich der
/// Score?") ist weggefallen, seit die Nachtkarte das Datum der Nacht
/// selbst führt; zweimal dieselbe Auskunft auf einem Schirm, einmal davon
/// als angefangener Satz, ist eine zu viel.
///
/// Formatiert ausschließlich über [Format] (`CLAUDE.md`).
class _Datumszeile extends StatelessWidget {
  const _Datumszeile(this.tag);

  final DateTime tag;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      key: const Key('erholung-datumszeile'),
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 12),
      child: Text(
        Format.datumAusgeschrieben(tag),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15, color: muted),
      ),
    );
  }
}

/// Der reine Ladezweig: noch kein Cache-Treffer, noch keine Antwort. Hier
/// steht **nie** ein „keine Daten"-Grund — der gehört zu einem fertigen Lauf
/// ohne Treffer (`docs/todo/01`).
class _Laden extends StatelessWidget {
  const _Laden();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      key: const Key('erholung-laden'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        'Noch keine Werte · wird geladen',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}

/// Ein gescheiterter Lauf ohne Cache. Sagt, dass es nicht geklappt hat —
/// und gerade **nicht**, dass es keine Daten gäbe.
class _Fehler extends StatelessWidget {
  const _Fehler();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        'Die Werte konnten gerade nicht geladen werden.',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}
