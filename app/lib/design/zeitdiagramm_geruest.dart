/// Das Gerüst des Diagramm-Bauteils: Leiste, Kopfzeile, Graphfläche,
/// Fußzeile — übereinander, mit denselben Abständen und Maßen wie im
/// [Zeitdiagramm].
///
/// **Wozu es eine eigene Datei gibt** (#93): Der Schirm „Fortschritt pro
/// Übung" zeigt bei weniger als zwei Trainingstagen **dieselbe Karte
/// ungefüllt** — und kein [Zeitdiagramm], weil das eine leere Reihe als
/// Linie behauptete. „Eine Anzeige, die es gibt, hat genau eine Form"
/// (`CLAUDE.md`): Höhe und Breite müssen gleich sein, und das bleibt nur
/// wahr, wenn beide Fälle **dieselbe** Stelle bauen und nicht zwei, die
/// beim nächsten Umbau auseinanderlaufen. Dies ist diese Stelle; das
/// [Zeitdiagramm] baut sich daraus, ohne seine Schlüssel oder Maße zu
/// ändern.
library;

import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'platzhalter.dart';

/// Wie hoch die Graphfläche ist — `.chart { height: 148px }` aus
/// `docs/screens/components.css`.
const double zeitdiagrammGraphHoehe = 148;

/// Leiste, Kopfzeile, Graphfläche und Fußzeile.
///
/// Die Kopfzeile steht unter `Key('diagramm-kopfzeile')`, die Fußzeile unter
/// `Key('diagramm-fussnote')`. **Dazwischen liegt die Graphfläche ohne
/// Luft** — die Abstände tragen Kopf- und Fußzeile selbst, damit das Band
/// zwischen beiden genau die Fläche ist, auf der die Gesten liegen.
class ZeitdiagrammGeruest extends StatelessWidget {
  const ZeitdiagrammGeruest({
    super.key,
    required this.leiste,
    required this.kopf,
    required this.graph,
    required this.fussnote,
    this.fussnoteZeilen,
    this.graphKey,
  });

  final Widget leiste;
  final Widget kopf;

  /// Der Inhalt der Graphfläche; sie hat die Höhe [zeitdiagrammGraphHoehe].
  final Widget graph;

  /// Die Fußzeile — fertiger Text.
  final String fussnote;

  /// Reserviert der Fußzeile eine **feste Zeilenzahl** ([FesteZeilen]).
  ///
  /// Für Schirme, deren Fußnoten je Stufe ungleich lang sind: Ohne
  /// Reservierung wüchse die Zeile beim Stufenwechsel, und alles unter dem
  /// Diagramm rutschte — „Mehrzeilige Erläuterungen bekommen eine feste
  /// Zeilenzahl" (`CLAUDE.md`). Der Schirm wählt die Zahl, weil nur er
  /// seine längste Fassung kennt; ein längerer Text wird mit `…`
  /// abgeschnitten statt zu wachsen.
  ///
  /// `null` heißt: wie bisher, die Zeile trägt ihre natürliche Höhe —
  /// richtig für Schirme, deren Fassungen ungefähr gleich lang sind
  /// (Schlaf, dort ist das ausdrücklich begründet).
  final int? fussnoteZeilen;

  /// Der Schlüssel der Graphfläche; das [Zeitdiagramm] misst daran die
  /// Breite für seine Gesten.
  final Key? graphKey;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 12.5, height: 1.4, color: muted);
    final zeilen = fussnoteZeilen;
    final text = Text(
      fussnote,
      maxLines: zeilen,
      overflow: zeilen == null ? null : TextOverflow.ellipsis,
      style: stil,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        leiste,
        const SizedBox(height: 14),
        Container(
          key: const Key('diagramm-kopfzeile'),
          // Der Abstand zum Graphen gehört in die Kopfzeile, nicht zwischen
          // beide: Sonst läge zwischen Kopfzeile und Graph Luft, und eine
          // Geste auf das Band träfe daneben.
          padding: const EdgeInsets.only(bottom: 10),
          child: kopf,
        ),
        SizedBox(key: graphKey, height: zeitdiagrammGraphHoehe, child: graph),
        Container(
          key: const Key('diagramm-fussnote'),
          padding: const EdgeInsets.only(top: 7),
          child: zeilen == null
              ? text
              : FesteZeilen(zeilen: zeilen, stil: stil, child: text),
        ),
      ],
    );
  }
}
