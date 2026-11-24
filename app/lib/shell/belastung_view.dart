// Der Schirm `belastung` (#94) — die Trainingsminuten der Woche gegen das
// Ziel, ihr Verlauf und der Vergleich zur Vorwoche. Der Zustand darunter
// liegt in `belastung_zustand.dart`, das Diagramm in
// `../design/zeitdiagramm.dart`.
//
// API und Verhalten sind durch `app/test/shell/belastung_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/belastung.js` (`KOPF`, `VERLAUF`,
// `VORWOCHE`, `noteBox`, `disclaimer`) und der Entwurfs-Spec
// `docs/superpowers/specs/2026-10-13-graphen-zeitraum-und-ablesen-design.md`;
// Vorlage ist `Sources/Features/Recovery/LoadDetailView.swift`.
//
// **Drei Abweichungen vom Entwurfsboard**, alle gemeldet und keine
// stillschweigend:
//
// - **Keine Zahl „210" in den Fließtexten.** Das Board schreibt sie in die
//   Fußnote („Das Wochenziel von 210 Minuten ist 7 × 30"). Im Quelltext
//   stünde sie damit ein zweites Mal, und ein geändertes Ziel ließe sie
//   stehen — `Ziele.vorbelegung` ist die einzige Stelle, die sie kennt.
//   Hier steht sie nur dort, wo sie aus den Zielen kommt: in der Kopfzeile.
// - **Die Fußnote des Diagramms nennt kein „Grün: Tagesziel erreicht".**
//   `Zeitdiagramm` färbt keinen Balken nach einer Ziellinie ein; der Satz
//   beschriebe etwas, das der Schirm nicht tut.
// - **Der Einordnungssatz ist als allgemeine Empfehlung gekennzeichnet.**
//   Das Board formuliert ihn als Befund („Das ist das Muster, das oft in
//   einen Infekt führt"); `CLAUDE.md` verbietet Diagnosen.
//
// **Die Tür hängt seit dem 28.10.2026:** Der Ring „BELASTUNG" des
// Erholung-Schirms führt hierher, über [oeffneBelastung].
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../core/messwert.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../design/zeitdiagramm.dart';
import 'belastung_zustand.dart';
import 'diagramm_zeitraum.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet den Belastungs-Schirm auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Ein Schirm, der im Menü unter
/// einem bestimmten Tab einsortiert ist, wechselt trotzdem nie dorthin,
/// sonst führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat
/// (`CLAUDE.md`).
void oeffneBelastung(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const BelastungSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste um [BelastungView].
///
/// Den stellt der Gastgeber, nicht der Schirm. **Kein eigener `Navigator`:**
/// Diese Ansicht wird auf den Stapel eines Tabs geschoben, der Stapel
/// gehört weiter `RootView`.
class BelastungSeite extends StatelessWidget {
  const BelastungSeite({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Belastung')),
      child: const BelastungView(),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([belastungProvider]): Jeder Schirm
/// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass
/// eine Übersicht vorher geladen hat.
class BelastungView extends ConsumerWidget {
  const BelastungView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(belastungProvider);

    // Der `switch` über den sealed-Typ ist vollständig: Käme ein fünfter
    // Zustand, zeigte der Analyzer genau hier hin.
    final List<Widget> inhalt = switch (zustand.daten) {
      NochNie<BelastungDaten>() => const [_Laden(key: Key('belastung-laden'))],
      LeerNachLauf<BelastungDaten>() => const [
        _Leer(key: Key('belastung-leer')),
      ],
      Fehlgeschlagen<BelastungDaten>() => const [
        _Fehler(key: Key('belastung-fehler')),
      ],
      Bekannt<BelastungDaten>(:final wert) => _inhalt(wert),
    };

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...inhalt,
          // Die Fußnote steht in **jedem** Zustand: Dass die Minuten aus
          // Apple Health kommen, erklärt gerade den leeren Schirm mit.
          const Hinweisfuss(_fussnote, key: Key('belastung-fuss')),
        ],
      ),
    );
  }

  List<Widget> _inhalt(BelastungDaten daten) => [
    _Kopf(key: const Key('belastung-kopf'), daten: daten),
    const SectionHeader('Verlauf'),
    Padding(
      // `.chartcard { margin: 10px var(--pad-screen) 0 }` — keine Karte
      // darunter, der Graph steht frei auf dem Hintergrund.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Zeitdiagramm(
        reihe: daten.tagesminuten,
        stufen: belastungsStufen,
        fussnote: _diagrammFussnote,
        // Die Einheit des Fensters ist eine Rate, die eines einzelnen
        // Balkens nicht: Ein Dienstag mit 42 Minuten ist kein Durchschnitt
        // pro Tag (`chartCard`/`pickedUnit` im Entwurfsboard).
        einheit: 'min / Tag',
        einheitAbgelesen: 'min',
        linien: [
          Ziellinie(
            name: 'Tagesziel',
            // Das Wochenziel durch sieben, nie eine 30 aus dem Quelltext:
            // Ändert sich das eine, ändert sich das andere mit.
            wert: daten.wochenziel / DateTime.daysPerWeek,
            // „Tagesziel 30 min" — der Name trägt den Wert, wörtlich wie
            // im Entwurfsboard (`belastung.js`). Dieses Diagramm hat keine
            // Werteachse; ohne die Zahl ließe sich die Linie nicht
            // ablesen (#178).
            wertText: '${_zahl(daten.wochenziel / DateTime.daysPerWeek)} min',
            farbe: Palette.ok,
          ),
        ],
      ),
    ),
    if (daten.vorwochenminuten case final vorwoche?)
      _Vorwoche(
        key: const Key('belastung-vorwoche'),
        minuten: vorwoche,
        veraenderung: daten.veraenderung,
      ),
    _Einordnung(key: const Key('belastung-einordnung'), signale: daten.signale),
  ];
}

/// Den Wortlaut der Diagramm-Fußzeile liefert der Schirm — das Bauteil
/// kennt die Herkunft der Zahlen nicht.
///
/// **Ab `6M` ist ein Balken ein Monat**, und dass darin ein
/// Tagesdurchschnitt steht, muss dabeistehen; auf `W` und `M` gibt es
/// nichts zu verdichten (`LoadDetailView.swift:79–81`).
String _diagrammFussnote(DiagrammStufe stufe) => switch (stufe) {
  DiagrammStufe.woche || DiagrammStufe.monat =>
    'Ein Balken ist ein Tag. Die grüne Linie ist dein Tagesziel — das '
        'Wochenziel geteilt durch sieben.',
  DiagrammStufe.halbjahr || DiagrammStufe.jahr =>
    'Ein Balken ist ein Monat: gezeigt wird der Tagesdurchschnitt dieses '
        'Monats. Die grüne Linie ist dein Tagesziel.',
};

/// Keine Zahl in diesem Satz: Das Wochenziel steht in der Kopfzeile, und
/// zwar aus [BelastungDaten.wochenziel]. Ein zweites Mal hingeschrieben
/// bliebe es stehen, wenn Tim sein Ziel ändert.
const _fussnote =
    'Trainingsminuten kommen aus Apple Health — die Uhr zählt jede Minute '
    'mit erhöhtem Puls, nicht nur die aufgezeichneten Einheiten. Das '
    'Wochenziel kommt aus deinen Zielen, das Tagesziel im Diagramm ist ein '
    'Siebtel davon. Grobe Orientierung, keine medizinische Bewertung.';

// ───────────────────────────────────────────────────────────────────────
// Die vier Zweige
// ───────────────────────────────────────────────────────────────────────

/// **Während des Laufs steht nie ein „keine Daten"-Grund** — das ist
/// `docs/todo/01`, in einem Satz.
class _Laden extends StatelessWidget {
  const _Laden({super.key});

  @override
  Widget build(BuildContext context) =>
      const _Absatz('Trainingsminuten werden gelesen …');
}

/// Der Lauf ist fertig und hat nichts gebracht. **Beide Möglichkeiten
/// werden genannt**, denn Apple verrät den Lesestatus nicht.
class _Leer extends StatelessWidget {
  const _Leer({super.key});

  @override
  Widget build(BuildContext context) => const _Absatz(
    'Für diesen Zeitraum liegen keine Trainingsminuten vor. Zwei '
    'Erklärungen, beide möglich: Entweder hat die Uhr nichts aufgezeichnet '
    '— oder der Lesezugriff auf die Trainingsminuten ist nicht freigegeben. '
    'Apple verrät nicht, welches von beidem zutrifft. Also beides prüfen: '
    'Uhr beim Training tragen, Lesezugriff in den Health-Einstellungen '
    'freigeben.',
  );
}

/// Ein Fehler ist keine Aussage über die Datenlage — hier steht deshalb
/// gerade **nicht**, dass es keine Daten gäbe.
class _Fehler extends StatelessWidget {
  const _Fehler({super.key});

  @override
  Widget build(BuildContext context) => const _Absatz(
    'Die Trainingsminuten konnten nicht geladen werden. Das sagt nichts '
    'darüber, ob welche vorliegen — es hat nur gerade nicht geklappt. '
    'Später noch einmal versuchen.',
  );
}

class _Absatz extends StatelessWidget {
  const _Absatz(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Die Abschnitte
// ───────────────────────────────────────────────────────────────────────

/// Die Kopfzeile: Minuten dieser Woche, Ziel, Anteil und der Balken
/// darunter — `KOPF`/`.scorecard` im Entwurfsboard.
class _Kopf extends StatelessWidget {
  const _Kopf({super.key, required this.daten});

  final BelastungDaten daten;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final minuten = daten.wochenminuten;
    final anteil = daten.anteil;

    // „Ziel 210 **Minuten**", nicht „210 min": Die Einheit steht hier
    // ausgeschrieben, weil die Zeile sonst wie eine zweite Messung aussieht.
    final zielZeile = StringBuffer('Ziel ${_zahl(daten.wochenziel)} Minuten');
    if (anteil != null) {
      zielZeile.write(' · ${(anteil * 100).round()} % erreicht');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DIESE WOCHE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: muted,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    // Kein erfundener Wert: Ohne Aufzeichnung steht hier
                    // ein Strich. Eine 0 behauptete, du hättest dich diese
                    // Woche nicht bewegt.
                    minuten == null ? '—' : _zahl(minuten),
                    style: Typografie.tabularNumbers(
                      Typografie.numeric(
                        TypografieGroesse.largeTitle,
                        gewicht: FontWeight.w700,
                      ),
                    ).copyWith(color: ink),
                  ),
                  // Wo keine Zahl steht, steht auch keine Einheit — sie
                  // behauptete sonst eine Messung, die es nicht gab.
                  if (minuten != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      'min',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                zielZeile.toString(),
                style: TextStyle(fontSize: 13, color: muted),
              ),
              if (minuten == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Für diese Woche ist nichts aufgezeichnet — oder der '
                    'Lesezugriff auf die Trainingsminuten ist nicht '
                    'freigegeben. Apple verrät nicht, welches von beidem '
                    'zutrifft.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: muted),
                  ),
                ),
              const SizedBox(height: 11),
              _Fortschritt(anteil: anteil),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.progress` im Entwurfsboard: 5 Punkt hohe Spur, gefüllt bis zum
/// Anteil, Akzent [Palette.iron].
///
/// **Über dem Ziel läuft der Balken nicht weiter** (wie `MakroBalken`), er
/// bleibt voll — die Zahl darüber sagt, wie weit darüber es ist.
class _Fortschritt extends StatelessWidget {
  const _Fortschritt({required this.anteil});

  final double? anteil;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        // `--fill` aus `docs/screens/tokens.css`: die Tintenfarbe bei 6 %.
        color: ink.withValues(alpha: 0.06),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: anteil == null ? 0 : anteil!.clamp(0.0, 1.0),
          child: ColoredBox(color: iron),
        ),
      ),
    );
  }
}

/// Vorwoche und Veränderung — `VORWOCHE`/`statRow` im Entwurfsboard.
///
/// Der Abschnitt entsteht gar nicht erst, wenn für die Vorwoche nichts
/// aufgezeichnet ist: Eine Vorwoche ohne Aufzeichnung ist keine Vorwoche
/// mit 0 Minuten, und statt einer erfundenen Zahl steht dort nichts.
class _Vorwoche extends StatelessWidget {
  const _Vorwoche({
    super.key,
    required this.minuten,
    required this.veraenderung,
  });

  final double minuten;
  final double? veraenderung;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final veraenderung = this.veraenderung;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Vorwoche'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InsetCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatZeile('Vorwoche', '${_zahl(minuten)} min'),
                if (veraenderung != null) ...[
                  Container(height: 0.5, color: line),
                  _StatZeile(
                    'Veränderung',
                    '${veraenderung < 0 ? '−' : '+'}'
                        '${veraenderung.abs().round()} % diese Woche',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatZeile extends StatelessWidget {
  const _StatZeile(this.titel, this.wert);

  final String titel;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(titel, style: TextStyle(fontSize: 14.5, color: ink)),
          ),
          Text(
            wert,
            style: Typografie.tabularNumbers(
              Typografie.numeric(TypografieGroesse.callout),
            ).copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}

/// Der Einordnungssatz — `noteBox` im Entwurfsboard.
///
/// **Die Kombination ist der Hinweis, nicht die Zahl allein:** Viel
/// Belastung bei guter Erholung ist Training. Deshalb hängt der Satz an
/// den Warnsignalen der Erholungsampel und nicht an den Minuten.
///
/// **Erst die farbige Kante, dann der Schnitt auf der ganzen Karte**
/// (`CLAUDE.md`): [InsetCard] legt außen ein `ClipRRect`, der 4 Punkt
/// breite Balken läuft deshalb nicht über die runde Ecke hinaus.
class _Einordnung extends StatelessWidget {
  const _Einordnung({super.key, required this.signale});

  final int signale;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final kante = CupertinoDynamicColor.resolve(_ton(signale), context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: InsetCard(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              _satz(signale),
              style: TextStyle(fontSize: 13.5, height: 1.4, color: ink),
            ),
          ),
        ),
      ),
    );
  }

  /// Grün ohne Signal, gelb bei einem, rot ab zweien — dieselbe Staffelung
  /// wie die Erholungsampel, damit „zwei Signale" auf beiden Schirmen
  /// dasselbe heißt.
  static CupertinoDynamicColor _ton(int signale) => switch (signale) {
    0 => Palette.ok,
    1 => Palette.bib,
    _ => Palette.warn,
  };

  /// **Keine Diagnose** (`CLAUDE.md`): Der Rat ist ausdrücklich als
  /// allgemeine Empfehlung gekennzeichnet, und benannt wird nur, was
  /// gemessen wurde.
  static String _satz(int signale) => switch (signale) {
    0 => 'Keine Warnsignale. Die Belastung trägt sich, dein Körper kommt mit.',
    1 =>
      'Ein Warnsignal neben dieser Belastung. Allgemeine Empfehlung: heute '
          'eher locker trainieren und früh ins Bett.',
    _ =>
      '$signale Warnsignale neben dieser Belastung. Erfahrungsgemäß ist das '
          'ein Muster, das in einen Infekt führen kann. Allgemeine '
          'Empfehlung, keine Diagnose: locker trainieren oder pausieren, '
          'viel trinken, früh ins Bett.',
  };
}

/// Minuten, wie der Schirm sie zeigt: deutsch gruppiert, ohne
/// Nachkommastelle — eine halbe Trainingsminute liest niemand.
///
/// Fest auf `de_DE`, aus demselben Grund wie `Format` in
/// `../design/formatierung.dart`: Ohne feste Sprache
/// stünde auf einem englisch eingestellten Gerät „1,050" im deutschen Text.
String _zahl(double wert) =>
    NumberFormat.decimalPattern('de_DE').format(wert.round());
