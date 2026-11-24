// Der Schritte-Schirm (#84, Umgestaltung #15) — vier Kacheln und **ein**
// Diagramm mit Zeitraumleiste, erreichbar über Körper › Schritte und die
// Kachel „Auf einen Blick".
//
// API und Verhalten sind durch `app/test/shell/schritte_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// Aufbau nach `docs/screens/screens/schritte.js` (Commit fd43877), mit
// **zwei** Abweichungen, die nicht dieser Schirm entschieden hat:
//
// 1. Der Entwurf zeichnet die Leiste `T W M 6M J` mit der Stundenstufe
//    `T` als Start. `DiagrammStufe` trägt aber **bewusst kein `tag`** —
//    gepinnt in `schlaf_zustand_test.dart` („vorerst gewinnt die SPEC,
//    die Frage an Tim steht in Ticket #92") und in
//    `diagramm_zeitraum_test.dart`. Bis Tim die T-Stufe freigibt, zeigt
//    der Schirm `W M 6M J`; die Stundenwerte (`hourlySteps`,
//    `StundenSchritte`-Cache) kommen mit ihr (#538).
// 2. Der Entwurf zeichnet auf `6M` eine **Ereignis-Marke** als optionales
//    Element („sie erscheint, wenn im gezeigten Fenster ein Ereignis
//    liegt, und fehlt sonst ersatzlos"). Das `Zeitdiagramm` kennt noch
//    keine senkrechten Marken, und die Anbindung an die `ereignisse`-
//    Tabelle (#404/#444) ist nicht entworfen — die Marke kommt als
//    Folgearbeit mit der T-Stufe (#538), kein Datum steht bis dahin
//    irgendwo im Quelltext (`CLAUDE.md`).
//
// Die Rechnung steht im Kern (`StepStatistics`), der gehaltene Zustand in
// `schritte_zustand.dart` — hier stehen nur Aufbau und Nutzertexte.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ziele.dart';
import '../design/glas_abstand.dart';
import '../design/kacheln.dart';
import '../design/palette.dart';
import '../design/zahlen.dart';
import '../design/zeitdiagramm.dart';
import '../shell/diagramm_zeitraum.dart';
import '../shell/mess_abschnitte.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'schritte_zustand.dart';
import 'umfaenge_notiz.dart';

/// Öffnet den Schritte-Schirm auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des
/// Tabs, aus dem man kommt, sonst führte „zurück" in ein Menü, das der
/// Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneSchritte(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const SchritteSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste um [SchritteView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
class SchritteSeite extends StatelessWidget {
  const SchritteSeite({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Schritte')),
      child: const SchritteView(),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([schritteZustandProvider]): Jeder
/// Schirm ist aus jedem Tab erreichbar, niemand darf sich darauf
/// verlassen, dass eine Übersicht vorher geladen hat.
class SchritteView extends ConsumerWidget {
  const SchritteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(schritteZustandProvider);
    // Zustand und Nutzlast getrennt gezogen, wie beim Verlauf je Maß
    // (#479): Ein `is … ? … : null` ebnete „lädt", „leer" und
    // „gescheitert" in einem Schritt ein.
    final lage = messLageAus(zustand);
    final werte = switch (zustand) {
      Bekannt<SchritteWerte>(:final wert) => wert,
      NochNie<SchritteWerte>() ||
      LeerNachLauf<SchritteWerte>() ||
      Fehlgeschlagen<SchritteWerte>() => null,
    };

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 15 statt 20: Die Kacheln tragen selbst 5 Punkt Rand, wie auf
          // `koerper`.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Kacheln(_obereKacheln(context, lage, werte)),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Kacheln(_untereKacheln(context, lage, werte)),
          ),
          // Der Grund steht **einmal**, nicht je Kachel — und nur, wenn der
          // Lauf fertig ist und nichts fand. Während des Ladens behauptet
          // nichts „keine Daten" (Fehler `01`).
          if (lage == MessLage.leer)
            const UmfangsNotiz(
              key: Key('schritte-leer'),
              ton: UmfangsNotizTon.neutral,
              text:
                  'Keine Schritte aus Apple Health — entweder ist nichts '
                  'aufgezeichnet oder die App darf sie nicht lesen. Apple '
                  'verrät den Unterschied nicht. Prüfen kannst du das in der '
                  'Health-App unter Privatsphäre › Apps.',
            ),
          if (lage == MessLage.fehler)
            const UmfangsNotiz(
              key: Key('schritte-fehler'),
              ton: UmfangsNotizTon.warnung,
              text:
                  'Die Schritte ließen sich nicht aus Apple Health lesen. '
                  'Versuch es gleich noch einmal.',
            ),
          SchritteDiagramm(werte: werte),
        ],
      ),
    );
  }

  /// Gestern und Ø 7 Tage — die obere Reihe aus dem Entwurf.
  List<KachelWert> _obereKacheln(
    BuildContext context,
    MessLage lage,
    SchritteWerte? werte,
  ) {
    final laedt = lage == MessLage.laedt;
    final kennzahlen = werte?.kennzahlen;
    final gestern = kennzahlen?.yesterday;
    final schnitt7 = kennzahlen?.average7;
    final farbe = CupertinoDynamicColor.resolve(Palette.ok, context);

    return [
      KachelWert(
        label: 'Gestern',
        wert: gestern == null ? null : formatNumber(gestern.toDouble()),
        // Kein eigener Grund an der Kachel — der steht einmal, im Kasten.
        // „Kein älterer Tag springt ein, und 0 hieße gemessen und null"
        // (`StepStats.yesterday`).
        zusatz: gestern == null ? '' : 'Schritte am Vortag',
        farbe: farbe,
        platzhalter: laedt ? '00.000' : null,
        schluessel: const Key('schritte-kachel-gestern'),
      ),
      KachelWert(
        label: 'Ø 7 Tage',
        wert: schnitt7 == null ? null : formatNumber(schnitt7.toDouble()),
        zusatz: _trendZusatz(lage, kennzahlen),
        farbe: farbe,
        platzhalter: laedt ? '00.000' : null,
        schluessel: const Key('schritte-kachel-schnitt7'),
      ),
    ];
  }

  /// Ø 30 Tage und „Ziel erreicht" — die untere Reihe.
  List<KachelWert> _untereKacheln(
    BuildContext context,
    MessLage lage,
    SchritteWerte? werte,
  ) {
    final laedt = lage == MessLage.laedt;
    final kennzahlen = werte?.kennzahlen;
    final schnitt30 = kennzahlen?.average30;
    final farbe = CupertinoDynamicColor.resolve(Palette.ok, context);

    // Der Nenner ist `daysWithData`, nicht 30: Tage ohne Messung sind
    // keine Tage mit null Schritten (Schirm-Karte #84, gegen SPEC Z. 172).
    final gemessen = kennzahlen?.daysWithData ?? 0;
    final erreicht = kennzahlen == null || gemessen == 0
        ? null
        : '${kennzahlen.goalReached} / $gemessen';

    return [
      KachelWert(
        label: 'Ø 30 Tage',
        wert: schnitt30 == null ? null : formatNumber(schnitt30.toDouble()),
        zusatz: schnitt30 == null ? '' : 'Mittel der gemessenen Tage',
        farbe: farbe,
        platzhalter: laedt ? '00.000' : null,
        schluessel: const Key('schritte-kachel-schnitt30'),
      ),
      KachelWert(
        label: 'Ziel erreicht',
        wert: erreicht,
        zusatz: _zielZusatz(lage, werte),
        farbe: farbe,
        platzhalter: laedt ? '00 / 00' : null,
        schluessel: const Key('schritte-kachel-ziel'),
      ),
    ];
  }
}

/// „▲ 2 % zur Vorwoche" — gerundet, mit Richtung. Ohne Trend steht keine
/// erfundene 0 da: Ein Anstieg von 0 ist kein Prozentsatz
/// (`StepStats.trendPercent`).
///
/// **Ohne Trend, aber mit Daten: „kein Vergleich zur Vorwoche".**
/// `trendPercent` ist in zwei Lagen `null` — die Vorwoche wurde nicht
/// gemessen, **oder** sie wurde gemessen und ihr Mittel ist 0 (sieben
/// Ruhetage auf dem Sofa). `StepStats` reicht das Vorwochenmittel nicht
/// heraus, die View kann die beiden also nicht unterscheiden — und
/// „keine Vorwoche" wäre im zweiten Fall eine falsche Auskunft über
/// sieben gemessene Tage. Der Sammeltext stimmt in beiden.
///
/// Im **Leerzustand** (gar keine Daten) steht das Entwurfs-Detail
/// „keine Vorwoche" (`schritte.js`, Variante `leer`) — dort stimmt es.
String _trendZusatz(MessLage lage, StepStats? kennzahlen) {
  final trend = kennzahlen?.trendPercent;
  if (trend == null) {
    return ohneWertZusatz(
      lage,
      grund: kennzahlen == null
          ? 'keine Vorwoche'
          : 'kein Vergleich zur Vorwoche',
    );
  }
  final prozent = trend.round();
  final richtung = prozent > 0
      ? '▲'
      : prozent < 0
      ? '▼'
      : '±';
  return '$richtung ${prozent.abs()} % zur Vorwoche';
}

/// „Top 10.480 · 4 Tage ohne Messung" — die Tage ohne Messung werden
/// genannt statt mitgezählt (`bestText` in der Swift-Vorlage).
///
/// **„30 Tage ohne Messung" nur, wenn es wirklich keine Daten gibt**
/// (Leerzustand, Entwurfstext). Gibt es Daten, aber keine im
/// Kennzahlenfenster — etwa wenn allein der **laufende** Tag gemessen ist,
/// der aus den Abständen 1–30 bewusst herausfällt —, sagt der Zusatz das
/// Fenster, statt wie ein Leerzustand zu klingen.
String _zielZusatz(MessLage lage, SchritteWerte? werte) {
  final top = werte?.kennzahlen.best;
  if (werte == null) {
    return ohneWertZusatz(
      lage,
      grund: '$schritteFensterTage Tage ohne Messung',
    );
  }
  if (top == null) {
    return 'keine Messung in den $schritteFensterTage Tagen vor heute';
  }
  final ohne = werte.tageOhneMessung;
  final topText = 'Top ${formatNumber(top.toDouble())}';
  return ohne > 0 ? '$topText · $ohne Tage ohne Messung' : topText;
}

/// Die Diagrammkarte — `chartCard` im Entwurf, in **allen** Lagen dieselbe
/// Form: Leiste, Kopf, Fläche und Fußnote stehen auch ohne Werte da, nur
/// ungefüllt („Eine Anzeige, die es gibt, hat genau eine Form").
///
/// Eigener `StatefulWidget`, weil die **Linien** an der Stufe hängen: Die
/// Ø-7-Linie gehört zu `W` und `M` (SPEC 4.6), ab `6M` bleibt nur das
/// Ziel — gegen einen Monatsbalken darf das Tagesziel stehen, weil der den
/// Tagesdurchschnitt zeigt. [Zeitdiagramm] fragt die Fußnote je Stufe,
/// die Linien nicht; die gewählte Stufe kommt deshalb über `onStufe`
/// hierher zurück.
class SchritteDiagramm extends StatefulWidget {
  const SchritteDiagramm({super.key, required this.werte});

  final SchritteWerte? werte;

  /// `W M 6M J` — die T-Stufe wartet auf Tims Entscheidung (#92), siehe
  /// Dateikopf. Die kleinste angebotene ist die Startstufe (`startStufe`).
  static const List<DiagrammStufe> stufen = [
    DiagrammStufe.woche,
    DiagrammStufe.monat,
    DiagrammStufe.halbjahr,
    DiagrammStufe.jahr,
  ];

  @override
  State<SchritteDiagramm> createState() => _SchritteDiagrammState();
}

class _SchritteDiagrammState extends State<SchritteDiagramm> {
  DiagrammStufe _stufe = startStufe(SchritteDiagramm.stufen);

  @override
  Widget build(BuildContext context) {
    final werte = widget.werte;
    final reihe = werte?.tagesReihe ?? const <({DateTime tag, double wert})>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Zeitdiagramm(
        reihe: reihe,
        stufen: SchritteDiagramm.stufen,
        fussnote: _fussnote,
        // Die Stufen-Fußnoten sind **ungleich lang** (ab `6M` kommt der
        // Ø-pro-Tag-Satz dazu); ohne feste Zeilenzahl rutschte beim
        // Stufenwechsel alles unter dem Diagramm. Vier Zeilen tragen die
        // längste Fassung auf Gerätebreite.
        fussnoteZeilen: 4,
        // Der Wert des Fensters ist ein Schnitt je Tag, der eines einzelnen
        // Balkens nicht (`unit`/`pickedUnit` im Entwurf).
        einheit: 'Schritte / Tag',
        einheitAbgelesen: 'Schritte',
        // Grün, sobald der Tag das Ziel erreicht (`barColor` in der
        // Swift-Vorlage; ab `6M` färbt der Tagesdurchschnitt — beides ist
        // „Schritte an einem Tag").
        balkenZiel: schritteTagesziel.toDouble(),
        linien: _linien(werte),
        onStufe: (stufe) => setState(() => _stufe = stufe),
      ),
    );
  }

  /// Ziellinie immer, Ø-7-Linie nur auf `W` und `M` — und beides nur,
  /// wenn Werte da sind: Eine Ziellinie über leerer Fläche wäre die
  /// einzige Aussage eines Diagramms, das nichts weiß.
  List<Ziellinie> _linien(SchritteWerte? werte) {
    if (werte == null) return const [];
    final schnitt7 = werte.kennzahlen.average7;
    return [
      Ziellinie(
        name: 'Ziel',
        wert: schritteTagesziel.toDouble(),
        farbe: Palette.muted,
        wertText: formatNumber(schritteTagesziel.toDouble()),
      ),
      if ((_stufe == DiagrammStufe.woche || _stufe == DiagrammStufe.monat) &&
          schnitt7 != null)
        Ziellinie(
          name: 'Ø 7 Tage',
          wert: schnitt7.toDouble(),
          farbe: Palette.warn,
          wertText: formatNumber(schnitt7.toDouble()),
        ),
    ];
  }
}

/// Den Wortlaut der Fußzeile liefert der Schirm — das Bauteil kennt die
/// Herkunft der Zahlen nicht.
///
/// **Ab `6M` sind die Balken Tagesdurchschnitte, und das steht dran**
/// (`monthlySuffix` und die Fußnote der Swift-Vorlage): Gegen einen
/// Monatsbalken darf das Tagesziel stehen, gegen eine Stunde nicht.
/// Die Fassungen sind **ungleich lang**; dass der Schirm beim
/// Stufenwechsel trotzdem nicht springt, trägt die feste Zeilenzahl der
/// Fußzeile (`fussnoteZeilen`), nicht der Wortlaut.
String _fussnote(DiagrammStufe stufe) {
  const quelle =
      'Quelle Apple Health — bei iPhone und Watch zählt der höhere Wert.';
  final gruen =
      'Grün: Ziel von ${formatNumber(schritteTagesziel.toDouble())} '
      'Schritten erreicht.';
  return switch (stufe) {
    DiagrammStufe.woche ||
    DiagrammStufe.monat => 'Tageswerte. $gruen $quelle',
    DiagrammStufe.halbjahr || DiagrammStufe.jahr =>
      'Je Balken ein Monat, gezeigt wird der Tagesdurchschnitt (Ø pro '
          'Tag). $gruen $quelle',
  };
}
