import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'platzhalter.dart';
import 'typografie.dart';

/// Ein Makro-Balken: Name, Wert gegen Ziel, gefüllter Anteil —
/// Dart-Entsprechung von `macroBar` in `docs/screens/components.js`
/// (`.macro`). Keine Swift-Entsprechung vorhanden.
///
/// „Über dem Ziel läuft der Balken nicht weiter — er färbt sich um"
/// (Entwurfszitat). [anteil] und [ueberZiel] sind deshalb zwei reine,
/// statische Funktionen, testbar ohne Widget-Pumping.
///
/// **Drei Fassungen, eine Form** (#358, `MAKROS_LEER` und `MAKROS_LAEDT`
/// in `docs/screens/screens/heute-kombi.js`): Werte da ([MakroBalken.new]),
/// gelesen und kein Wert ([MakroBalken.ohneWert], rechts [ohneWert], der
/// Balken leer) und wird geladen ([MakroBalken.laedt], rechts eine graue
/// Form in der Breite eines Beispieltexts). Höhe und Breite sind in allen
/// drei dieselben — eine Anzeige verschwindet nicht, weil ihr Wert fehlt,
/// und ein leerer Balken behauptet keine `0`.
///
/// Dazu eine vierte für ein Ziel ohne Wert ([MakroBalken.nurZiel]):
/// „– / 180 kcal" — das Ziel steht, gegessen ist noch nichts (#442,
/// Mahlzeit-Detail, Entscheidung 7 der Aufteilungs-Spec).
class MakroBalken extends StatelessWidget {
  const MakroBalken({
    super.key,
    required this.label,
    required int this.wert,
    required int this.ziel,
    required this.einheit,
    required this.farbe,
    this.ueberZielUmfaerben = true,
  }) : platzhalter = null;

  /// Ein Ziel, aber kein Wert dagegen: rechts „– / [ziel] [einheit]", der
  /// Balken leer. Nicht `0 / 180` — eine Null behauptete „nichts
  /// gegessen", wo nichts eingetragen ist.
  const MakroBalken.nurZiel({
    super.key,
    required this.label,
    required int this.ziel,
    required this.einheit,
    required this.farbe,
  }) : wert = null,
       platzhalter = null,
       ueberZielUmfaerben = true;

  /// Gelesen, kein Wert — oder kein Ziel, gegen das er stünde. Rechts
  /// steht [ohneWert], der Balken bleibt leer.
  const MakroBalken.ohneWert({
    super.key,
    required this.label,
    required this.einheit,
    required this.farbe,
  }) : wert = null,
       ziel = null,
       platzhalter = null,
       ueberZielUmfaerben = true;

  /// Noch nichts gelesen. [platzhalter] ist ein Beispieltext in der
  /// Schrift der Beschriftung; er wird nie gezeichnet, nur gemessen
  /// ([Platzhalter]). Gehört allein in `NochNie` — beim Nachladen bleibt
  /// der alte Wert stehen.
  const MakroBalken.laedt({
    super.key,
    required this.label,
    required this.einheit,
    required this.farbe,
    required String this.platzhalter,
  }) : wert = null,
       ziel = null,
       ueberZielUmfaerben = true;

  final String label;

  /// `null` in [MakroBalken.ohneWert] und [MakroBalken.laedt] — nie `0`.
  final int? wert;
  final int? ziel;
  final String einheit;
  final Color farbe;
  final String? platzhalter;

  /// Ob der Balken über dem Ziel in [Palette.warn] umschlägt — Vorgabe
  /// wie bisher. **`false` beim Ziel einer Mahlzeit** (V18): Über dem
  /// eigenen Anteil zu liegen ist dort kein Fehler; der Balken bleibt voll
  /// und in [farbe].
  final bool ueberZielUmfaerben;

  /// Gefüllter Anteil, 0 bis 1 gedeckelt — der Balken läuft über dem Ziel
  /// nicht weiter über die Karte hinaus.
  static double anteil(int wert, int ziel) {
    if (ziel <= 0) return 0;
    final voll = wert / ziel;
    return voll > 1 ? 1 : voll;
  }

  /// Erst das Überschreiten färbt um, nicht das Erreichen.
  static bool ueberZiel(int wert, int ziel) => wert > ziel;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    // Entspricht `--fill` in `docs/screens/tokens.css`
    // (`rgba(21,36,42,.06)`): ein von Ink abgeleiteter, sehr heller Grund
    // für den Balken, kein eigener Palette-Token.
    final grund = ink.withValues(alpha: 0.06);
    final wert = this.wert;
    final ziel = this.ziel;
    final hatWert = wert != null && ziel != null;
    final ueber =
        ueberZielUmfaerben &&
        wert != null &&
        ziel != null &&
        ueberZiel(wert, ziel);
    final gefuellt = wert != null && ziel != null ? anteil(wert, ziel) : 0.0;
    final farbeBalken = ueber ? Palette.warn : farbe;
    final beschriftungStil = Typografie.tabularNumbers(
      TextStyle(fontSize: 14, color: muted),
    );
    final beispiel = platzhalter;

    final balken = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // Die graue Form hat keine Grundlinie. An der Grundlinie
            // ausgerichtet säße sie mit ihrer Unterkante darauf und machte
            // die Zeile höher als mit Text — mittig ausgerichtet bleibt
            // die Höhe die der Beschriftung links, wie in den beiden
            // anderen Fassungen.
            crossAxisAlignment: beispiel != null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // `Expanded` statt `Spacer`: Auf Gerätebreite mit großer
              // Schrift reichte der Platz für Name und Zahl nicht, und der
              // Balken lief über den Rand (gelb-schwarz). Gekürzt wird
              // dann der Name, nie die Zahl — eine halbe Zahl wäre eine
              // falsche Auskunft.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                ),
              ),
              const SizedBox(width: 8),
              if (beispiel != null)
                Platzhalter(beispiel: beispiel, stil: beschriftungStil)
              else
                Text(
                  hatWert
                      ? '$wert / $ziel $einheit'
                      : ziel != null
                      ? '– / $ziel $einheit'
                      : ohneWert,
                  style: beschriftungStil,
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: grund,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: gefuellt,
                child: Container(
                  color: CupertinoDynamicColor.resolve(farbeBalken, context),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (hatWert) return balken;
    // Der Vorlesetext nennt den Zustand, nicht das Zeichen: Mit `–/–`
    // läse VoiceOver „Strich Schrägstrich Strich" vor (`CLAUDE.md`).
    return Semantics(
      label: beispiel != null
          ? '$label, wird geladen'
          : ziel != null
          ? '$label, keine Werte, Ziel $ziel $einheit'
          : '$label, keine Werte',
      excludeSemantics: true,
      child: balken,
    );
  }
}
