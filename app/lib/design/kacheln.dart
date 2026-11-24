import 'package:flutter/cupertino.dart';

import 'karten_flaeche.dart';
import 'palette.dart';
import 'platzhalter.dart';
import 'typografie.dart';

/// Eine Kachel aus dem Streifen „Zahlen": Beschriftung, Wert, Einordnung,
/// optional ein Verlauf — Dart-Entsprechung von `KachelWert` zu einem
/// Eintrag in `tiles` (`docs/screens/components.js`, `.tiles`) und
/// `HighlightTile` in `Sources/DesignSystem/HighlightTile.swift`.
class KachelWert {
  const KachelWert({
    required this.label,
    required this.wert,
    this.einheit,
    required this.zusatz,
    required this.farbe,
    this.verlauf,
    this.platzhalter,
    this.schluessel,
    this.onTap,
  });

  final String label;

  /// `null` heißt „gelesen, kein Wert" — die Kachel bleibt dann stehen und
  /// zeigt [ohneWert] an der Stelle der Zahl, statt zu verschwinden. Sie
  /// verschwinden zu lassen sprengte die Breite der Nachbarkachel
  /// (`Kacheln` legt seine Kinder als gleich breite `Expanded` ab), und
  /// eine `0` wäre Fehler `01` aus `CLAUDE.md`. Spec:
  /// `docs/superpowers/specs/2026-10-28-leerzustaende-design.md`.
  final String? wert;
  final String? einheit;
  final String zusatz;
  final Color farbe;

  /// Beispieltext für die graue Fläche, solange noch nichts gelesen wurde
  /// (#24). Nur wirksam, wenn [wert] fehlt — beim Nachladen bleibt der
  /// alte Wert stehen.
  final String? platzhalter;

  /// Die letzten Werte für die Verlaufslinie. `null` oder leer zeigt keine
  /// — ein echter Fall, kein Sonderweg: Der Demo-Datensatz hat an
  /// mehreren Tagen `steps: null` bzw. `weightKg: null`.
  final List<double>? verlauf;

  /// Der Schlüssel, unter dem die **ganze Kachelfläche** zu finden ist —
  /// und nicht nur ihr Inneres. Er sitzt deshalb auf dem Auslöser außen um
  /// die Kachel, nicht auf der Zahl darin: Eine Tür, die nur in der Mitte
  /// aufgeht, ist keine.
  ///
  /// Additiv und optional: Die Kacheln auf Heute tragen weder Schlüssel
  /// noch Tür und bauen sich unverändert.
  final Key? schluessel;

  /// Was passiert, wenn man die Kachel antippt. `null` heißt „keine Tür" —
  /// die Kachel bleibt reine Anzeige.
  ///
  /// Auf `koerper` führen „Körperfett" und „Muskelmasse" damit auf den
  /// Verlauf ihres Werts (`koerper.js`, Nachtrag vom 02.11.2026: vorher
  /// sahen die Kacheln drückbar aus, ohne es zu sein).
  final VoidCallback? onTap;
}

/// Die Fläche, auf der eine Kachel sitzt — seit #384 dieselbe wie jede
/// andere Karte der App, [kartenFlaeche] aus `karten_flaeche.dart`.
///
/// **Öffentlich, weil die Gewichts-Kopfkarte auf `koerper` dieselbe Fläche
/// trägt** (#239, Tims Wortlaut: „die box soll gleich aussehen von der
/// hintergrund und box umrandung wie die von körperfett und so"). Der Name
/// bleibt für diese Aufrufer stehen; Radius und Farbe stehen nur in
/// [kartenFlaeche].
BoxDecoration kachelFlaeche(BuildContext context) => kartenFlaeche(context);

/// Die Kachelreihe — Dart-Entsprechung von `tiles(list)` in
/// `docs/screens/components.js`. Anders als `IconRow` (eine einzelne
/// Zeile) nimmt `Kacheln` die ganze Liste entgegen und legt sie selbst
/// nebeneinander.
class Kacheln extends StatelessWidget {
  const Kacheln(this.werte, {super.key});

  final List<KachelWert> werte;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final wert in werte) Expanded(child: _Kachel(wert: wert)),
      ],
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({required this.wert});

  final KachelWert wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final verlauf = wert.verlauf;

    return Semantics(
      // Der Vorlesetext nennt den Zustand, nicht das Zeichen: „–/–" ist
      // für das Auge gemacht, vorgelesen ergibt es „Strich Schrägstrich
      // Strich" (CLAUDE.md, „Eine Anzeige … hat genau eine Form"). Die
      // Kinder sind deshalb stumm — sonst läse VoiceOver das Zeichen
      // zusätzlich vor.
      label: _vorlesetext(wert),
      // Die Tür steht innen; `excludeSemantics` nähme VoiceOver sonst die
      // Tippmöglichkeit mit den Kindern zusammen weg.
      button: wert.onTap != null,
      onTap: wert.onTap,
      excludeSemantics: true,
      child: _tuer(_kachel(context, ink, muted, verlauf)),
    );
  }

  /// Legt Schlüssel und Tipp-Handler um die **ganze** Kachel, wenn es sie
  /// gibt. `HitTestBehavior.opaque`, damit auch der Rand zwischen Zahl und
  /// Kachelkante trifft.
  Widget _tuer(Widget kachel) {
    if (wert.schluessel == null && wert.onTap == null) return kachel;
    return GestureDetector(
      key: wert.schluessel,
      behavior: HitTestBehavior.opaque,
      onTap: wert.onTap,
      child: kachel,
    );
  }

  Widget _kachel(
    BuildContext context,
    Color ink,
    Color muted,
    List<double>? verlauf,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: kachelFlaeche(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: wert.farbe,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  wert.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: _Wertzeile(wert: wert, ink: ink, muted: muted),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            // Drei Zeilen fest reserviert (#24): Die Erläuterung ist im
            // Normalfall kurz („heute gezählt") und im Leerfall lang (der
            // Grund mit dem Verweis auf die Health-Einstellungen) — ohne
            // Reservierung wüchse die Kachel genau dann, wenn Werte
            // fehlen. Drei statt zwei, weil „Health-Einstellungen" ein
            // unteilbarer Block ist, der in der halbbreiten Kachel allein
            // zwei Zeilen braucht; mit zweien fiel er stumm weg.
            child: FesteZeilen(
              zeilen: 3,
              stil: _zusatzStil(muted),
              child: Text(
                wert.zusatz,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _zusatzStil(muted),
              ),
            ),
          ),
          // **Der Streifen steht immer, die Linie nicht** (#501). Bis
          // zum 16.11.2026 hing das ganze `Padding` an der Reihe — und
          // solange niemand eine mitgab, fiel das nicht auf. Seit Home
          // Schritte und Gewicht mit Verlauf füttert, schon: Beim
          // Kaltstart ist das Fenster leer, es gibt keine Linie; trifft
          // der Cache ein, wächst die Kachel um 33 Punkt und der
          // Hinweisfuß darunter rutscht. Und eine Kachel mit Linie steht
          // neben einer ohne (das Gewicht hat seltener Werte als die
          // Schritte), beide verschieden hoch.
          //
          // **Leer, nicht grau.** Die graue Form ist der Ladeplatzhalter
          // und gehört allein dorthin (`CLAUDE.md`); ein grauer Balken,
          // wo es nie eine Linie geben wird, verspräche einen Wert, der
          // nicht kommt.
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              height: 28,
              child: verlauf == null || verlauf.isEmpty
                  ? null
                  : Verlaufslinie(werte: verlauf, farbe: wert.farbe),
            ),
          ),
        ],
      ),
    );
  }
}

/// Schriftgröße 10, nicht 11: Die Kachel ist auf einem 393 Punkt breiten
/// Gerät innen rund 140 Punkt schmal, und „Einstellungen" passte bei 11
/// nicht mehr auf eine Zeile.
TextStyle _zusatzStil(Color muted) => TextStyle(fontSize: 10, color: muted);

/// Was VoiceOver zu einer Kachel sagt. Während des Laufs gibt es keinen
/// „keine Daten"-Grund zu nennen — auch nicht vorgelesen (Fehler `01`).
String _vorlesetext(KachelWert wert) {
  final zahl = wert.wert;
  if (zahl == null) {
    if (wert.platzhalter != null) return '${wert.label}, wird geladen';
    final grund = wert.zusatz.isEmpty ? '' : '. ${wert.zusatz}';
    return '${wert.label}, keine Werte$grund';
  }
  final einheit = wert.einheit == null ? '' : ' ${wert.einheit}';
  final zusatz = wert.zusatz.isEmpty ? '' : '. ${wert.zusatz}';
  return '${wert.label}, $zahl$einheit$zusatz';
}

/// Die Zeile mit der Zahl: der Wert mit seiner Einheit, bei fehlendem Wert
/// das Zeichen [ohneWert] — und solange noch gar nichts gelesen wurde eine
/// graue Fläche in der Breite des Beispieltexts.
class _Wertzeile extends StatelessWidget {
  const _Wertzeile({
    required this.wert,
    required this.ink,
    required this.muted,
  });

  final KachelWert wert;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title).copyWith(color: ink),
    );
    final zahl = wert.wert;
    final beispiel = wert.platzhalter;

    if (zahl == null && beispiel != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Platzhalter(beispiel: beispiel, stil: stil),
      );
    }

    final einheit = wert.einheit;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // `Flexible` + Ellipse statt Überlauf: Ein langer Wert („19 / 26"
        // auf dem Schritte-Schirm, große Schrift) lief sonst über die
        // Kachelkante hinaus — auf der halbbreiten Kachel sind es innen
        // nur rund 145 Punkt (#84). Auf dem Gerät ändert sich nichts,
        // solange der Wert passt; `find.text` sieht weiter den vollen
        // Text.
        Flexible(
          child: Text(
            zahl ?? ohneWert,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stil,
          ),
        ),
        if (einheit != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(einheit, style: TextStyle(fontSize: 14, color: muted)),
          ),
      ],
    );
  }
}

/// Verlaufslinie ohne Achsen — Dart-Entsprechung von `Sparkline` in
/// `Sources/DesignSystem/HighlightTile.swift` und `spark(vals, color)` in
/// `docs/screens/components.js`. Zeigt die Richtung, nicht den Wert.
///
/// Als eigener, öffentlicher Baustein herausgezogen, nicht
/// Implementierungsdetail von [Kacheln]: Nur so lässt sich von außen
/// prüfen, ob sie bei fehlender Reihe weggelassen wird.
class Verlaufslinie extends StatelessWidget {
  const Verlaufslinie({super.key, required this.werte, required this.farbe});

  final List<double> werte;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VerlaufslinienMaler(werte: werte, farbe: farbe),
    );
  }
}

class _VerlaufslinienMaler extends CustomPainter {
  _VerlaufslinienMaler({required this.werte, required this.farbe});

  final List<double> werte;
  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    if (werte.length < 2) return;

    final niedrig = werte.reduce((a, b) => a < b ? a : b);
    final hoch = werte.reduce((a, b) => a > b ? a : b);
    // Flache Linie statt Teilung durch 0, wenn alle Werte gleich sind.
    final spanne = (hoch - niedrig) == 0 ? 1 : (hoch - niedrig);
    final schritt = size.width / (werte.length - 1);

    final pfad = Path();
    for (var i = 0; i < werte.length; i++) {
      final anteil = (werte[i] - niedrig) / spanne;
      final punkt = Offset(i * schritt, size.height - anteil * size.height);
      if (i == 0) {
        pfad.moveTo(punkt.dx, punkt.dy);
      } else {
        pfad.lineTo(punkt.dx, punkt.dy);
      }
    }

    final stift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = farbe.withValues(alpha: 0.85);
    canvas.drawPath(pfad, stift);
  }

  @override
  bool shouldRepaint(covariant _VerlaufslinienMaler oldDelegate) {
    return oldDelegate.werte != werte || oldDelegate.farbe != farbe;
  }
}
