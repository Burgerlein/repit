/// Die beiden eigenständigen Bausteine des Diagramms: die Zeitraumleiste
/// darüber und die waagerechte Linie darin.
///
/// Sie stehen hier und nicht in `zeitdiagramm.dart`, weil beide für sich
/// allein stehen — die Leiste ist zustandslos, [Ziellinie] ist ein reiner
/// Werttyp. Zusammen waren es 110 Zeilen in einer Datei, die schon den
/// Zustand, die Kopfzeile und zwei Gesten trug.
///
/// **`zeitdiagramm.dart` exportiert diese Datei weiter.** Die festgelegte
/// API ist `import '…/design/zeitdiagramm.dart'`, und so benutzen sie der
/// Bauteiltest und die Schirme aus #94; der Schnitt bleibt deshalb innen.
///
/// Entschieden am 28.10.2026 vom Koordinator von #130, nicht von Tim.
library;

import 'package:flutter/cupertino.dart';

import '../shell/diagramm_zeitraum.dart';
import 'palette.dart';

/// Eine waagerechte Linie im Diagramm (Ziel, Median, Schwelle).
///
/// Werttyp mit `==` und `hashCode`: Eine Liste von Linien ist Abhängigkeit
/// eines Diagramms. Ohne Gleichheit wäre jede neu gebaute Liste ungleich der
/// vorigen und jedes Bild zeichnete neu — das wäre `docs/todo/03`, wortgleich
/// im neuen Code.
@immutable
class Ziellinie {
  const Ziellinie({
    required this.name,
    required this.wert,
    required this.farbe,
    this.wertText,
  });

  final String name;
  final double wert;
  final CupertinoDynamicColor farbe;

  /// Der Wert, **wie der Schirm ihn geschrieben haben will** — „6:41 h",
  /// „30 min", „58 ms".
  ///
  /// **Warum eine Zeichenkette und kein Formatierer** (#178): Ein Diagramm
  /// weiß nicht, ob sein Wert Stunden, Minuten oder Schläge sind; beim
  /// Schlaf muss „6:41 h" dastehen und nicht „6,7" (#151). Ein
  /// `String Function(double)` wie `Zeitdiagramm.kopfzahl` täte dasselbe,
  /// zerstörte hier aber das `==`: Eine Closure ist nie gleich der des
  /// vorigen Baus, jede neu gebaute Linie wäre ungleich der vorigen und
  /// jedes Bild zeichnete neu — `docs/todo/03`, wortgleich.
  ///
  /// **Und nicht in [name] hineingeschrieben**, obwohl das Entwurfsboard es
  /// so macht (`linien: [{ name: 'Tagesziel 30 min', … }]`): Dort ist es
  /// eine Vorschau mit festen Zahlen, hier steht neben dem Text die Lage
  /// der Linie. Zwei Felder lassen sich nebeneinander lesen und
  /// gegeneinander prüfen; ein zusammengesetzter Name nicht.
  ///
  /// **`null` heißt: nur der Name**, wie bis zum 29.10.2026 überall. Das
  /// ist keine Zusicherung, sondern der Stand: Die vierte Aufrufstelle
  /// (`schlaf_verlauf.dart`, „Schlafziel") gehört gerade einem anderen
  /// Zweig (#177) und kann hier nicht mitwandern. Dass daraus eine Pflicht
  /// wird, steht als eigenes Ticket.
  final String? wertText;

  /// Was an der Linie steht: „Normal 6:41 h", oder der Name allein, solange
  /// kein [wertText] dabei ist.
  ///
  /// Zusammengesetzt wird hier und nicht im Maler: Der Maler bekommt
  /// fertige Striche und fertige Texte.
  String get beschriftung => wertText == null ? name : '$name $wertText';

  @override
  bool operator ==(Object other) =>
      other is Ziellinie &&
      other.name == name &&
      other.wert == wert &&
      other.farbe == farbe &&
      other.wertText == wertText;

  @override
  int get hashCode => Object.hash(name, wert, farbe, wertText);

  @override
  String toString() => 'Ziellinie(beschriftung: $beschriftung, wert: $wert)';
}

/// Die Zeitraumleiste über jedem Diagramm — `rangeBar` im Entwurfsboard.
///
/// Eigenständig und zustandslos: Welche Stufe gewählt ist, weiß das
/// [Zeitdiagramm], nicht die Leiste. Die Schirmtests aus #94 suchen sie per
/// `find.byType`, während der Schirm nur ein [Zeitdiagramm] baut — sie ist
/// deshalb immer ein Nachfahre davon.
class Zeitraumleiste extends StatelessWidget {
  const Zeitraumleiste({
    super.key,
    required this.stufen,
    required this.gewaehlt,
    required this.onWaehle,
  });

  final List<DiagrammStufe> stufen;
  final DiagrammStufe gewaehlt;
  final ValueChanged<DiagrammStufe> onWaehle;

  /// `T · W · M · 6M · J` aus der Spec. Nutzertext, also in der View und
  /// nicht im Kern — `DiagrammStufe` trägt keine Beschriftung.
  static String beschriftung(DiagrammStufe stufe) => switch (stufe) {
    DiagrammStufe.woche => 'W',
    DiagrammStufe.monat => 'M',
    DiagrammStufe.halbjahr => '6M',
    DiagrammStufe.jahr => 'J',
  };

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        // `--fill` aus `docs/screens/tokens.css`: die Tintenfarbe bei 6 %.
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final stufe in stufen)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onWaehle(stufe),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: stufe == gewaehlt
                      ? BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: [
                            BoxShadow(
                              color: ink.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    beschriftung(stufe),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: stufe == gewaehlt ? ink : muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
