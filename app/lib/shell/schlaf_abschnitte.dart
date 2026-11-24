// Die Abschnitte des Schlaf-Schirms (#92) — Blätterleiste, Score-Karte,
// Tagschlaf-Tür, Verlauf, Statistiken, Puls- und Atemspannen und die sieben
// Nächte. Der Schirm, der sie zusammensetzt, liegt in `schlaf_view.dart`,
// der Zustand darunter in `schlaf_zustand.dart`.
//
// **Diese Datei ist seit #153 zugleich die Tür zu vier anderen** (28.10.2026,
// rund 1000 Zeilen waren es vorher). Sie trägt selbst nur noch die
// Abschnitte über der angezeigten Nacht — die Blätterleiste, die
// Score-Karte und seit #127 die Wischgeste, die beide blättert —, der Rest
// liegt daneben und wird von hier weiterexportiert:
//
// - `schlaf_texte.dart` — Dauer, Uhrzeit, Fenster, Bewertung, der Satz bei
//   fehlenden Daten; von allen vieren gebraucht.
// - `schlaf_verlauf.dart` — die Diagrammkarte über mehrere Nächte und die
//   Statistikblöcke mit festem Zeitraum.
// - `schlaf_spannen.dart` — das Min-Max-Diagramm für Puls und Atmung.
// - `schlaf_naechte.dart` — die sieben Nächte auf der gemeinsamen Nachtuhr.
//
// **Die festgelegte API ist `import '…/shell/schlaf_abschnitte.dart'`.**
// `schlaf_view.dart`, `tagschlaf_view.dart` und die Widget-Tests holen von
// hier alles, so wie `zeitdiagramm.dart` es für `zeitdiagramm_leiste.dart`
// vormacht; der Schnitt bleibt deshalb innen. Tim hat „aufteilen"
// verlangt; wo der Schnitt liegt, hat der umsetzende Agent entschieden.
//
// Die Beschriftungen folgen `docs/screens/screens/schlaf.js`. Zwei Stellen
// weichen bewusst ab, beide nach der Spec statt nach dem Board:
//
// - **Die zweite Teilnote heißt „Zubettgehzeit"** und ihre Begründung nennt
//   das Schlafenszeitziel, nicht den Schnitt der letzten 14 Nächte
//   (`docs/SPEC.md` 4.6). Entwurf und Swift-Code tragen dort noch die alte
//   „Regelmäßigkeit".
// - **Das Blatt hinter dem „?" nennt die erreichbare Punktzahl ohne die
//   100 danebenzustellen.** „Erreichbar sind hier 70 statt 100" liest sich
//   wie ein Abzug; erreichbar sind 70, und bewertet wird der Anteil davon.
//   Bis #429 stand das als Fußnote unter der Karte.
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/ziele.dart';
import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/segment_ring.dart';
import '../design/typografie.dart';
import 'schlaf_score_blatt.dart';
import 'schlaf_texte.dart';
import 'schlaf_zustand.dart';

export 'schlaf_naechte.dart';
export 'schlaf_spannen.dart';
export 'schlaf_texte.dart';
export 'schlaf_verlauf.dart';

String _teilTitel(SchlafTeil teil) => switch (teil) {
  SchlafTeil.dauer => 'Dauer',
  SchlafTeil.zubettgehzeit => 'Zubettgehzeit',
  SchlafTeil.unterbrechungen => 'Unterbrechungen',
};

String _teilSchluessel(SchlafTeil teil) => switch (teil) {
  SchlafTeil.dauer => 'dauer',
  SchlafTeil.zubettgehzeit => 'zubettgehzeit',
  SchlafTeil.unterbrechungen => 'unterbrechungen',
};

// ───────────────────────────────────────────────────────────────────────
// Blätterleiste
// ───────────────────────────────────────────────────────────────────────

/// Die Kopfzeile der Nachtkarte: ‹ Datum ›.
///
/// Beide Pfeile stehen **immer** da; am Rand sind sie aus. Ein Pfeil, der
/// verschwindet, lässt die Zeile springen, und ein Pfeil, der ins Leere
/// führt, ist schlimmer als ein blasser.
class SchlafBlaetterleiste extends StatelessWidget {
  const SchlafBlaetterleiste({
    super.key,
    required this.datum,
    required this.fenster,
    required this.aufFrueher,
    required this.aufSpaeter,
  });

  final DateTime datum;
  final String fenster;

  /// `null` heißt „am Rand" — der Knopf ist aus.
  final VoidCallback? aufFrueher;
  final VoidCallback? aufSpaeter;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          // **Nicht `chevron_right`/`›`.** Beide Pfeile können aus sein,
          // und der Board-Test „kein Chevron ohne Tür" verlangt für genau
          // diese Zeichen eine Tür dahinter. Die dickeren Navigationspfeile
          // sagen hier ohnehin das Richtige: eine Bewegung, kein Sprung.
          CupertinoButton(
            key: const Key('schlaf-frueher'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(44, 44),
            onPressed: aufFrueher,
            child: const Icon(CupertinoIcons.chevron_back, size: 20),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${Format.wochentagKurz(kalendertag(datum))} '
                  '${Format.tagMonat(kalendertag(datum))}',
                  style: Typografie.tabularNumbers(
                    Typografie.numeric(TypografieGroesse.title3),
                  ).copyWith(color: ink),
                ),
                Text(fenster, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          CupertinoButton(
            key: const Key('schlaf-spaeter'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(44, 44),
            onPressed: aufSpaeter,
            child: const Icon(CupertinoIcons.chevron_forward, size: 20),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Wischen über dem Nachtbereich
// ───────────────────────────────────────────────────────────────────────

/// Breite des Streifens an der linken Bildschirmkante, der dem System
/// gehört.
///
/// Derselbe Wert wie Flutters `_kBackGestureWidth` in
/// `cupertino/route.dart`; dort ist er privat, also steht er hier noch
/// einmal. Wächst er dort je, fängt dieser Bereich wieder einen Teil des
/// Zurück-Wischs ab.
const double _systemrandBreite = 20;

/// Ab dieser Strecke gilt ein Zug als Wisch …
const double _mindestWeg = 36;

/// … oder ab diesem Tempo, damit auch ein kurzer Schnipser zählt.
const double _mindestTempo = 220;

/// Waagerechtes Wischen über dem Nachtbereich blättert eine Nacht (#127).
///
/// Nach rechts zur Nacht davor, nach links zur Nacht danach — dieselbe
/// Richtung wie in Fotos und in Apple Health. [aufFrueher] und [aufSpaeter]
/// sind **dieselben** Rückrufe wie an [SchlafBlaetterleiste]: Pfeil und
/// Geste führen auf denselben Zustand, und `null` heißt an beiden Stellen
/// „am Rand".
///
/// Zwei Dinge sind hier aufgehoben:
///
/// 1. **Der Zurück-Wisch von der linken Kante bleibt beim System.** iOS
///    blättert von dort im Navigationsstapel zurück; fängt dieser Bereich
///    die Geste ab, kommt der Nutzer nicht mehr aus dem Schirm heraus. Ein
///    Zeiger, der im linken Streifen aufsetzt, kommt deshalb **gar nicht
///    erst** in die Gestenarena ([_NachtWischen.isPointerAllowed]). Erst
///    in `onStart` zu prüfen käme zu spät: Da hat der Zug die Arena schon
///    gewonnen und der Zurück-Wisch ist verloren.
/// 2. **Wischen und Halten schließen einander nicht aus.** Hypnogramm
///    (#141) und Spannen (#157) lesen durch Halten ab und bringen dafür
///    eigene `GestureDetector` mit. Beide Erkenner liegen in derselben
///    Arena: Bewegt sich der Finger über den Slop, gewinnt der Zug; bleibt
///    er liegen, gewinnt nach einer halben Sekunde das Halten. Kein Flag,
///    kein Zustand, in dem die beiden sich ausschließen könnten —
///    dieselbe Lösung wie in `design/zeitdiagramm.dart`.
///
/// Am Rand stößt die Geste an: Sie löst einen leichten Stoß aus und der
/// Schirm bleibt stehen. **Der Stoß ist in keinem Widget-Test zu sehen**
/// und steht deshalb in der Prüfanleitung; nachprüfbar ist hier nur, dass
/// kein Nachtwechsel stattfindet.
///
/// **Seit #241 trägt sie auch das Monatsraster des Kalenderblatts** — dort
/// blättert derselbe Zug einen Monat statt einer Nacht
/// (`schlaf_kalenderblatt.dart`). Beides ist dieselbe Geste über
/// derselben Frage „was liegt davor?", beides mit demselben Vertrag:
/// dieselben Rückrufe wie die Pfeile daneben, `null` heißt „am Rand". Im
/// Raster liegt unter der Geste ein Tipper je Tag; auch das ist der Fall
/// aus Punkt 2 — ein Zug über den Slop gewinnt, ein liegender Finger
/// nicht.
class SchlafWischen extends StatefulWidget {
  const SchlafWischen({
    super.key,
    required this.aufFrueher,
    required this.aufSpaeter,
    required this.child,
  });

  /// `null` heißt „am Rand" — es wird nicht geblättert.
  final VoidCallback? aufFrueher;
  final VoidCallback? aufSpaeter;

  final Widget child;

  @override
  State<SchlafWischen> createState() => _SchlafWischenState();
}

class _SchlafWischenState extends State<SchlafWischen> {
  /// Die bisher gezogene Strecke. **Kein `setState`:** Hier wird nichts
  /// gezeichnet, was dem Finger folgt, also braucht es auch kein Bild je
  /// Bewegung.
  double _weg = 0;

  void _ende(DragEndDetails einzelheiten) {
    final weg = _weg;
    _weg = 0;

    // Strecke **oder** Tempo: Ein langsamer, weiter Zug hat kaum Tempo,
    // ein Schnipser kaum Strecke. Beides soll blättern.
    final tempo = einzelheiten.primaryVelocity ?? 0;
    final weit = weg.abs() >= _mindestWeg;
    final schnell = tempo.abs() >= _mindestTempo;
    if (!weit && !schnell) return;

    final nachRechts = weit ? weg > 0 : tempo > 0;
    final ziel = nachRechts ? widget.aufFrueher : widget.aufSpaeter;
    if (ziel == null) {
      HapticFeedback.lightImpact();
      return;
    }
    ziel();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      // `opaque`, damit auch die Lücken zwischen den Zeilen tragen. Die
      // Kinder werden trotzdem zuerst getroffen: Die Pfeile bleiben
      // Knöpfe, und der Tipper auf die Tagschlaf-Zeile bleibt ein Tipper.
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _NachtWischen: GestureRecognizerFactoryWithHandlers<_NachtWischen>(
          () => _NachtWischen(debugOwner: this),
          // Blockrümpfe, keine Pfeile: Ein `=>`-Rumpf schluckt die
          // folgenden Kaskadenglieder, und `..onUpdate` landete dann auf
          // dem Ergebnis der Zuweisung statt auf dem Erkenner.
          (erkenner) => erkenner
            ..onStart = (_) {
              _weg = 0;
            }
            ..onUpdate = (einzelheiten) {
              _weg += einzelheiten.delta.dx;
            }
            ..onEnd = _ende
            ..onCancel = () {
              _weg = 0;
            },
        ),
      },
      child: widget.child,
    );
  }
}

/// Ein waagerechter Zug, der im linken Systemstreifen gar nicht erst
/// mitspielt — die Begründung steht bei [SchlafWischen].
class _NachtWischen extends HorizontalDragGestureRecognizer {
  _NachtWischen({super.debugOwner});

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx >= _systemrandBreite && super.isPointerAllowed(event);
}

// ───────────────────────────────────────────────────────────────────────
// Score-Karte
// ───────────────────────────────────────────────────────────────────────

/// Ring, Dauer, Fenster und die drei Teilergebnisse mit ihrer Begründung.
///
/// **Diese Karte nennt die Nacht, nicht den Tag** (#212). Die Leiste
/// darüber sagt „Mo. 02.11." und meint den Kalendertag — sie ist die
/// Klammer über Nacht **und** Nickerchen, und genau deshalb darf dort
/// „Nacht auf …" nicht stehen. Hier steht wirklich nur die Nacht, also
/// heißt sie auch so: „Nacht So. → Mo. · 23:10–06:40". Tims Beobachtung
/// vom 02.11.2026 war, dass „Mo. 02.11." offenlässt, ob die Nacht *auf*
/// Montag oder die Nacht *von* Montagabend gemeint ist; beide Enden
/// nebeneinander lassen die Frage nicht mehr zu.
///
/// Die Spanne steht **in derselben Zeile wie das Fenster**, nicht als
/// eigene Überschrift darüber: Eine zusätzliche Zeile machte die Karte
/// höher, und die Uhrzeiten daneben sind dieselbe Auskunft in fein — wann
/// diese Nacht lief.
class SchlafScoreKarte extends StatelessWidget {
  const SchlafScoreKarte({super.key, required this.nacht, required this.ziele});

  final SchlafNacht nacht;
  final Ziele ziele;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final score = nacht.score;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SegmentRing(
                    abschnitte: schlafRingAbschnitte(nacht.teilnoten),
                    mitte: '${score.total}',
                    // **Die erreichbare Punktzahl, nicht „von 100".** Ohne
                    // sie ist die Bewertung daneben nicht nachrechenbar.
                    caption: 'von ${score.maxTotal}',
                    durchmesser: 88,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // **20 Punkte hoch, ob rechts etwas steht oder
                        // nicht** (#429). Marke und „?" sitzen in einer
                        // Zeile, die es ohnehin gibt; ein Platz, der nur
                        // bei Bedarf entsteht, wäre der Sprung von vorn.
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              Text(
                                'SCHLAFDAUER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: muted,
                                ),
                              ),
                              const Spacer(),
                              if (nacht.vonHand != null) ...[
                                const _Marke(
                                  'von Hand',
                                  key: Key('schlaf-score-marke'),
                                ),
                                const SizedBox(width: 2),
                              ],
                              _HilfeKnopf(
                                key: const Key('schlaf-score-hilfe'),
                                onPressed: () =>
                                    zeigeSchlafScoreBlatt(context, nacht),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          schlafDauerText(nacht.kern.asleepMinutes),
                          style: Typografie.tabularNumbers(
                            Typografie.numeric(
                              TypografieGroesse.title,
                              gewicht: FontWeight.w700,
                            ),
                          ).copyWith(color: ink),
                        ),
                        Text(
                          'Nacht ${Format.nachtSpanne(nacht.nacht.date)} '
                          '· ${schlafFensterText(nacht.von, nacht.bis)}',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        Text(
                          schlafBewertungText(score.rating),
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final teil in nacht.teilnoten)
                _Teilnote(
                  key: Key('schlaf-teil-${_teilSchluessel(teil.teil)}'),
                  teilnote: teil,
                  begruendung: _begruendung(teil),
                ),
              // **Kein Satz unter den Teilnoten** (#429). Bis zum 10.11.2026
              // stand hier „Erreichbar sind hier 80 Punkte: …", nur wenn ein
              // Teil entfiel — die Karte war dann drei Zeilen höher. Die
              // Summe nennt die Caption des Rings, den Grund die Teilnote,
              // die ganze Erklärung das Blatt hinter dem „?"
              // (`schlaf_score_blatt.dart`).
            ],
          ),
        ),
      ),
    );
  }

  /// Was unter der Teilnote steht — die Zahlen, aus denen sie entstand.
  String _begruendung(SchlafTeilnote teil) {
    switch (teil.teil) {
      case SchlafTeil.dauer:
        final ziel = schlafDauerText(ziele.schlafzielMinuten.toDouble());
        return '${schlafDauerText(nacht.kern.asleepMinutes)} von $ziel';

      case SchlafTeil.zubettgehzeit:
        final bettzeit = nacht.kern.bedtime;
        if (bettzeit == null) return 'keine Einschlafzeit aufgezeichnet';
        final ziel = Format.uhrzeit(
          DateTime.utc(
            2000,
            1,
            1,
            ziele.schlafenszeitMinuten ~/ Duration.minutesPerHour,
            ziele.schlafenszeitMinuten % Duration.minutesPerHour,
          ),
        );
        return 'Einschlafen ${schlafZeitText(bettzeit)} · Ziel $ziel';

      case SchlafTeil.unterbrechungen:
        // Ohne Phasendaten gibt es nichts zu zählen. `nacht.kern` trüge
        // hier 0 Wachminuten in 0 Wachphasen — eine ruhige Nacht, die
        // niemand gemessen hat.
        if (teil.grund == SchlafEntfallGrund.keinePhasendaten) {
          return 'von Hand eingetragen, nicht gemessen';
        }
        final wach = nacht.kern.awakeMinutes.round();
        return '${nacht.kern.wakeCount}× wach, $wach min';
    }
  }
}

/// Die Marke „VON HAND" in der Zeile „SCHLAFDAUER" (#429) — dieselbe Form
/// wie das Kennzeichen „manuell" in `mess_abschnitte.dart`.
class _Marke extends StatelessWidget {
  const _Marke(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: muted,
        ),
      ),
    );
  }
}

/// Das „?" der Score-Karte (#429). Steht **immer** da, auch bei einer
/// gemessenen Nacht — sonst wäre es eine Anzeige, die nur bei Bedarf
/// entsteht.
///
/// Der Kreis ist 20 Punkte groß wie im Entwurf, die Tippfläche so breit
/// wie ein Daumen; höher als die Zeile darf sie nicht werden, sonst wüchse
/// die Karte.
class _HilfeKnopf extends StatelessWidget {
  const _HilfeKnopf({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Semantics(
      button: true,
      label: 'Erklärung zum Schlaf-Score',
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 20),
        onPressed: onPressed,
        child: SizedBox(
          width: 44,
          height: 20,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: river, width: 1.3),
              ),
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: river,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Teilnote extends StatelessWidget {
  const _Teilnote({
    super.key,
    required this.teilnote,
    required this.begruendung,
  });

  final SchlafTeilnote teilnote;
  final String begruendung;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final farbe = CupertinoDynamicColor.resolve(
      schlafTeilFarbe(teilnote.teil),
      context,
    );

    // **„entfällt", nicht „0/30".** Die Nacht war nicht spät — es ist
    // keine Einschlafzeit aufgezeichnet. Zwei verschiedene Dinge.
    final wert = teilnote.entfaellt
        ? 'entfällt'
        : '${teilnote.punkte}/${teilnote.maximum}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: farbe.withValues(alpha: teilnote.entfaellt ? 0.35 : 1),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _teilTitel(teilnote.teil),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                wert,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(TypografieGroesse.callout),
                ).copyWith(color: teilnote.entfaellt ? muted : ink),
              ),
              Text(begruendung, style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}
