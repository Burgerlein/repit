// Verlauf und Statistiken des Schlaf-Schirms (#92): das Diagramm über die
// Nächte und die beiden Blöcke mit den festen Zeiträumen.
//
// **Keiner der drei bringt seit #253 seine eigene Karte mit.** Sie sitzen
// am Fuß des Schirms in je einem `KlappAbschnitt`, und der trägt Karte,
// Titel und die Zeile, die auf- und zuklappt. Was hier steht, ist der
// Inhalt — und je eine Funktion für die Zahl, die in der zugeklappten
// Zeile daneben steht.
//
// Eigene Datei, weil beide dieselbe Frage beantworten — „wie war es über
// mehrere Nächte?" — und als einzige des Schirms das gemeinsame
// [Zeitdiagramm] mitbringen. Die Abschnitte der **einen** Nacht stehen in
// `schlaf_abschnitte.dart`, `schlaf_spannen.dart` und `schlaf_naechte.dart`.
//
// **`schlaf_abschnitte.dart` exportiert diese Datei weiter.** Die
// festgelegte API bleibt `import '…/shell/schlaf_abschnitte.dart'`.
//
// Herausgelöst am 28.10.2026 für #153. Tim hat „aufteilen" verlangt; wo
// der Schnitt liegt, hat der umsetzende Agent entschieden.
import 'package:flutter/cupertino.dart';

import '../design/hypnogramm.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import '../design/zeitdiagramm.dart';
import 'diagramm_zeitraum.dart';
import 'schlaf_texte.dart';
import 'schlaf_zustand.dart';

/// Die Stufen, die der Verlauf anbietet — **kein `T`**.
///
/// Die Begründung steht im Entwurf (`docs/screens/screens/schlaf.js`,
/// `VERLAUF`) und ist teuer bezahlt: Jeder Balken dieses Diagramms *ist*
/// schon eine Nacht, und eine Nacht hat keine Stundenwerte. Auf dem
/// Schritte-Schirm gibt es `T` zu Recht, dort fallen je Stunde Werte an.
/// Die einzelne Nacht erreicht man über die ‹ ›-Leiste und das
/// Kalenderblatt, nicht über eine Stufe.
const List<DiagrammStufe> schlafStufen = [
  DiagrammStufe.woche,
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// Die Diagrammkarte des Verlaufs — `chartCard` im Entwurf.
///
/// **Nur die Reihe.** Durchschnitt und Zeitraum rechnet [Zeitdiagramm] über
/// das sichtbare Fenster; ein zweiter, daneben stehender Schnitt über sieben
/// Nächte wären zwei Wahrheiten in einer Karte. Wer den festen Schnitt
/// sucht, findet ihn in den Statistikblöcken darunter, die ausdrücklich
/// sagen, worauf sie sich beziehen.
///
/// Die Werte kommen aus `schlafTagewerteProvider` und darunter aus
/// [schlafTagewerte]; verdichtet wird in `diagrammPunkte`, nicht hier.
/// **Das Schlafziel steht als Linie darin** (#152) — wie bei Belastung,
/// wo die grüne Linie das Tagesziel zeigt.
class SchlafVerlauf extends StatelessWidget {
  const SchlafVerlauf({
    super.key,
    required this.reihe,
    this.phasenReihe = const [],
    this.schlafzielStunden,
  });

  /// Schlafstunden je Nacht. Eine Nacht ohne Schlaf **fehlt** — sie ist
  /// keine gemessene Null.
  final List<({DateTime tag, double wert})> reihe;

  /// Je Nacht die Schlafstunden nach Phasen, in der Reihenfolge von
  /// [schlafVerlaufPhasen] — aus `schlafPhasenTagewerteProvider` (#504).
  ///
  /// Leer heißt: einfarbige Balken. Dasselbe gilt für die einzelne Nacht,
  /// die hier fehlt oder deren Teile alle 0 sind — ältere Uhren und das
  /// iPhone melden Schlaf ohne Phasenangabe, und eine erfundene
  /// Verteilung wäre schlimmer als keine (`CLAUDE.md`).
  final List<({DateTime tag, List<double> teile})> phasenReihe;

  /// Das Schlafziel in **Stunden**, in derselben Einheit wie [reihe].
  ///
  /// Der Wert kommt aus den Zielen (`lib/data/ziele.dart`), nie als
  /// Konstante aus dem Quelltext (`CLAUDE.md`). `null` heißt: keine Linie —
  /// ohne Ziel wird keine Behauptung über ein Ziel gezeichnet.
  final double? schlafzielStunden;

  @override
  Widget build(BuildContext context) {
    return Zeitdiagramm(
      reihe: reihe,
      stufen: schlafStufen,
      fussnote: _verlaufFussnote,
      // **Balken, und jeder in sich nach Phasen gestapelt** — Tim am
      // 13.11.2026 (#504), mit dem Bildschirmfoto des Verlaufs aus der
      // alten App: „doch, den hier übernehmen, nur die Balken so
      // einfärben wie die Phasen, damit man sieht, wie die prozentual
      // drin waren."
      //
      // **Das nimmt die Entscheidung aus #255 zurück.** Hier stand bis
      // zum 16.11.2026 `alsBalken: false` samt Begründung („Die Linie
      // gewinnt, die App zieht nach", 03.11.2026). Die Begründung von
      // damals trägt die Umkehr mit: Jede Nacht ist eine abgeschlossene
      // Menge, und eine Linie zwischen zwei Nächten behauptet
      // Zwischenwerte, die es nicht gibt. Der Entwurf zeichnet den
      // Verlauf seither als Balkenfassung von `chartCard`.
      //
      // `alsBalken` ist die Vorgabe des Bauteils und steht deshalb nicht
      // mehr da.
      //
      // **Die Höhe bleibt die Schlafdauer**, die Phasen teilen sie
      // anteilig (`stapelGrenzen`). Höhe = Anteil verlöre die Dauer, und
      // die Dauer ist die Aussage dieses Diagramms.
      //
      // **„Ziel erreicht" ist keine Balkenfarbe mehr.** Die alte App
      // färbte den ganzen Balken grün oder blau danach, ob das Ziel
      // erreicht war (`SleepHistorySection.swift:41`); zwei Bedeutungen
      // in einer Farbe gehen nicht. Die gestrichelte Ziellinie unten
      // sagt dasselbe und sagt dazu, um wie viel.
      stapelReihe: phasenReihe,
      // **Die Farben kommen aus `SchlafPhasen.farbe`, nicht aus der
      // Swift-Fassung**: Dort ist „Tief" bewusst `riverDark` statt
      // `deep`, weil `deep` im Dunkelmodus das hellste Blau der Palette
      // ist. Derselbe Schlaf sieht damit im Hypnogramm und im Verlauf
      // gleich aus — und an genau einer Stelle gepflegt.
      stapelFarben: [
        for (final phase in schlafVerlaufPhasen) SchlafPhasen.farbe(phase),
      ],
      // Der Wert des Fensters ist ein Schnitt je Nacht, der eines
      // einzelnen Balkens nicht (`unit`/`pickedUnit` im Entwurf).
      einheit: 'Schlaf / Nacht',
      einheitAbgelesen: 'Schlaf',
      linien: [
        if (schlafzielStunden case final ziel?)
          Ziellinie(name: 'Schlafziel', wert: ziel, farbe: Palette.ok),
      ],
    );
  }
}

/// Die Spanne der Reihe — „5:10–8:40 h", für die zugeklappte Zeile des
/// Abschnitts (#253).
///
/// `null` bei leerer Reihe: Dann steht in der Zeile **keine Zahl**, keine
/// 0 und kein Strich, der wie ein Messwert aussähe (`CLAUDE.md`).
///
/// **Die Spanne, nicht der Schnitt.** Welchen Schnitt dieses Diagramm
/// zeigt, hängt an der gewählten Stufe und am sichtbaren Fenster — die
/// zugeklappte Zeile kennt beides nicht und dürfte sich keines ausdenken.
/// Die Spanne gilt für die ganze Reihe und beantwortet dieselbe Frage:
/// lohnt sich das Aufklappen.
String? schlafVerlaufSpanne(List<({DateTime tag, double wert})> reihe) {
  if (reihe.isEmpty) return null;
  var kleinste = double.infinity;
  var groesste = double.negativeInfinity;
  for (final punkt in reihe) {
    if (punkt.wert < kleinste) kleinste = punkt.wert;
    if (punkt.wert > groesste) groesste = punkt.wert;
  }
  // Die Reihe steht in Stunden, die Texte rechnen in Minuten.
  return schlafSpanneText(
    kleinste * Duration.minutesPerHour,
    groesste * Duration.minutesPerHour,
  );
}

/// Den Wortlaut der Fußzeile liefert der Schirm — das Bauteil kennt die
/// Herkunft der Zahlen nicht.
///
/// **Ab `6M` ist ein Balken ein Monat.** „Je Balken eine Nacht" wäre dort
/// falsch, und die Phasen sind dann ein Monatsschnitt statt der Verteilung
/// einer Nacht. Was in beiden Fassungen stehen bleibt, ist der
/// Unterschied, auf den es ankommt — gezählt wird die Zeit im Schlaf,
/// nicht die Zeit im Bett.
///
/// **Durchgehend „Balken", nie „Punkt"** (#255, berichtigt mit #504). Der
/// erste Satz sagte beides in einem Atemzug — „Je Punkt eine Nacht. Der
/// Balken zeigt die Zeit im Schlaf" —, und einer von beiden war in jedem
/// Fall falsch. #255 hat das gemeldet und die Fußnote auf den Punkt
/// gestellt; seit Tim am 13.11.2026 die Balken zurückgeholt hat, ist der
/// Punkt das Falsche. Derselbe Wortlaut steht im Entwurf
/// (`docs/screens/screens/schlaf.js`, `VERLAUF_KARTE`).
///
/// **Jede gezeichnete Farbe wird genannt, Wach nicht.** Eine Farbe ohne
/// Namen ist eine Behauptung ohne Lesart; „Wach" steht nicht da, weil es
/// nicht im Balken steckt (siehe [schlafVerlaufPhasen]).
///
/// **Gezeichnet werden vier, nicht drei.** Der Satz sagte bis zum
/// 16.11.2026 „Tief, Kern und REM; ohne Phasendaten bleibt er einfarbig"
/// und ließ damit genau den Fall aus, den es wirklich gibt: eine Nacht
/// mit **beidem**. `_hatPhasendaten` fragt nur, ob *irgendein*
/// `rem`/`core`/`deep`-Abschnitt dabei ist — eine Nacht aus gemischten
/// Quellen trägt gestapelte Phasen **und** einen Block ohne Angabe, und
/// ab `6M` ist das in jedem Monat so, in dem eine einzige Nacht ohne
/// Phasen lag. Dieser Balken ist weder „nur Tief/Kern/REM" noch
/// einfarbig, und seine vierte Farbe hatte in der Oberfläche keinen
/// Namen. Jetzt hat sie einen.
///
/// **Beide Fassungen sind ungefähr gleich lang.** Eine, die eine Zeile
/// mehr bräuchte als die andere, ließe den Abschnitt beim Stufenwechsel
/// springen (`CLAUDE.md`).
String _verlaufFussnote(DiagrammStufe stufe) => switch (stufe) {
  DiagrammStufe.woche || DiagrammStufe.monat =>
    'Je Balken eine Nacht, seine Höhe die Zeit im Schlaf — nicht die Zeit '
        'im Bett. Die Farben teilen ihn in Tief, Kern und REM; Schlaf ohne '
        'Phasenangabe bekommt einen eigenen Ton.',
  DiagrammStufe.halbjahr || DiagrammStufe.jahr =>
    'Je Balken ein Monat, seine Höhe der Schnitt seiner Nächte im Schlaf — '
        'nicht im Bett. Die Farben sind der Monatsschnitt aus Tief, Kern '
        'und REM, dazu Schlaf ohne Phasenangabe.',
};

/// Der Schnitt, den ein Statistikblock in seiner ersten Zeile nennt.
///
/// **Die eine Stelle, an der er entsteht.** Die zugeklappte Zeile des
/// Abschnitts nennt denselben Wert (#253); zwei Rechnungen dafür liefen
/// auseinander, so wie es der Schlaf-Schirm am Hypnogramm schon einmal
/// hatte.
String schlafStatistikSchnitt(SchlafStatistik statistik) =>
    schlafDauerText(statistik.schlafMinuten);

/// Der Inhalt eines Statistikblocks über einen festen Zeitraum.
///
/// **Ohne Überschrift und ohne Karte** — beides bringt seit #253 der
/// [KlappAbschnitt] mit, in dem er sitzt: Der Titel steht in der Zeile,
/// die ihn auf- und zuklappt, und zweimal „Letzte 7 Nächte bis heute"
/// untereinander wäre eine Überschrift über ihrer eigenen Überschrift.
///
/// **Dass er bis heute läuft, sagt der Titel.** Steht oben eine ältere
/// Nacht, ändern sich seine Zahlen trotzdem nicht — sonst änderten sich
/// beim Blättern Werte, die niemand gesucht hat.
class SchlafStatistikBlock extends StatelessWidget {
  const SchlafStatistikBlock({super.key, required this.statistik});

  final SchlafStatistik statistik;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final anteile = [
      for (final phase in SchlafPhasen.reihenfolge)
        if (statistik.anteile[phase] != null)
          '${SchlafPhasen.name(phase)} '
              '${(statistik.anteile[phase]! * 100).round()} %',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Zeile('Ø Schlaf', schlafStatistikSchnitt(statistik)),
        _Zeile('Ø Einschlafen', schlafUhrzeitText(statistik.einschlafMinuten)),
        _Zeile('Ø Aufwachen', schlafUhrzeitText(statistik.aufwachMinuten)),
        if (anteile.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            anteile.join(' · '),
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile(this.titel, this.wert);

  final String titel;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(titel, style: TextStyle(fontSize: 14, color: muted)),
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
