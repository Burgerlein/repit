// Der **Online-Teil** der Suchliste (#284) — was Open Food Facts zum
// Suchtext liefert, hinter den eigenen Treffern in **derselben** Liste.
// `docs/screens/screens/erfassen.js`, Zustände `suche-treffer` und
// `suche-ohne-netz`.
//
// Geprüft in `app/test/ernaehrung/off_suche_view_test.dart` (siehe dessen
// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Eine Liste, keine Abschnitte** (Tim, 04.11.2026: „Eigene Treffer
// sollen einfach mit den anderen gemischt werden, höchstens mit einem Tag
// gekennzeichnet."). Bis dahin stand hier ein eigener Abschnitt „Open
// Food Facts" mit Überschrift und Karte. Jetzt liefert die Datei nur die
// Zeilen, die `suche_view.dart` in seine eine Karte setzt, und den Satz
// „Online nicht erreichbar" darunter.
//
// **Eine Anzeige, die es gibt, hat genau eine Form** (`CLAUDE.md`): Ab dem
// zweiten Zeichen gibt es den Online-Teil — Zeilen, Platzhalter, „nichts
// gefunden" an derselben Stelle, am Ende der Liste.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lebensmittel_repository.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_provider.dart';
import 'off_client.dart';
import 'off_suche_provider.dart';
import 'plus_bausteine.dart';

/// Die Zeilen des Online-Teils, **ohne Trenner** — die setzt die Liste,
/// die sie mit den eigenen zusammenfügt.
///
/// Leer bei [OffAnzeigeAus] (unter zwei Zeichen gibt es keinen
/// Online-Teil) und bei [OffAnzeigeKeinNetz] (der Satz dazu steht unter
/// der Liste, siehe [OffKeinNetzHinweis]).
///
/// [eigeneLeer] ändert nur den Wortlaut von „nichts gefunden": Stehen
/// keine eigenen da, sagt der Satz das mit, statt auf „oben" zu zeigen.
List<Widget> offZeilen(
  OffAnzeige anzeige, {
  required bool eigeneLeer,
  void Function(LebensmittelVorlage vorlage)? onGewaehlt,
  SuchePlus? plus,
}) => switch (anzeige) {
  OffAnzeigeAus() || OffAnzeigeKeinNetz() => const [],
  // Während gefragt wird, ist nichts entschieden — ein „nichts gefunden"
  // hier wäre Fehler `01`.
  OffAnzeigeLaedt() => const [
    ErfassenLadendeListe(key: Key('erfassen-online-laedt')),
  ],
  OffAnzeigeZeilen(:final produkte) => [
    for (final produkt in produkte)
      _OffZeile(
        key: Key('erfassen-off-${produkt.barcode}'),
        produkt: produkt,
        // Verworfen wird im Kern; ohne Kalorien kommt hier nichts an.
        // Die Prüfung bleibt, damit eine Zeile ohne Kalorien nie buchbar
        // aussieht, falls sich das je ändert.
        aufTippen: produkt.buchbar
            ? () => onGewaehlt?.call(produkt.alsVorlage())
            : null,
        // „+" nur an einer buchbaren Zeile (#440).
        plus: produkt.buchbar ? plus : null,
      ),
  ],
  OffAnzeigeLeer(:final allesSchonEigen) => [
    _Hinweis(
      key: const Key('erfassen-online-leer'),
      text: allesSchonEigen
          ? 'Was Open Food Facts dazu kennt, steht schon oben bei deinen '
                'eigenen Lebensmitteln.'
          : eigeneLeer
          ? 'Weder in deinen Lebensmitteln noch bei Open Food Facts steht '
                'etwas dazu. Leg es unten an — danach findest du es hier.'
          : 'Open Food Facts kennt dazu nichts. Leg es unten an — '
                'danach findest du es hier.',
    ),
  ],
};

/// „Online nicht erreichbar" — **unter** der Liste, am Ende, dort, wo sonst
/// die Online-Treffer folgten (Entwurf `suche-ohne-netz`). Oben stehend
/// ließe der Satz den ganzen Schirm kaputt aussehen; die eigenen Treffer
/// stehen darüber weiter da.
class OffKeinNetzHinweis extends StatelessWidget {
  const OffKeinNetzHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return Padding(
      key: const Key('erfassen-online-kein-netz'),
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 16, color: warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Online nicht erreichbar — gezeigt werden nur deine eigenen '
              'Lebensmittel.',
              style: TextStyle(fontSize: 13, height: 1.35, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Zeile aus Open Food Facts: Name, Marke und die Menge, die „+"
/// bucht — „100 g" (V24), denn ein Online-Treffer hat keine frühere
/// Buchung —, Kalorien dieser Menge. **Kein Abzeichen „eigen"** — das
/// tragen nur Tims eigene Lebensmittel.
class _OffZeile extends ConsumerWidget {
  const _OffZeile({
    super.key,
    required this.produkt,
    required this.aufTippen,
    required this.plus,
  });

  final OffProdukt produkt;

  /// `null` bei einer nicht buchbaren Zeile.
  final VoidCallback? aufTippen;

  /// `null` ohne „+" oder bei einer nicht buchbaren Zeile.
  final SuchePlus? plus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final vorlage = produkt.alsVorlage();
    // Dieselbe Rechnung wie an der eigenen Zeile, damit beide dasselbe
    // sagen; für einen Online-Treffer immer „100 g".
    final anzeige = ref.watch(trefferVorwahlProvider(vorlage));
    final menge = anzeige?.menge ?? ohneWert;
    final kcal = anzeige?.kcal;
    final marke = produkt.marke;
    final plus = this.plus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 11, plus == null ? 14 : 4, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produkt.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: produkt.buchbar ? ink : muted),
                  ),
                  const SizedBox(height: 2),
                  // Eine Zeile: Der Text unter einem Wert ist der
                  // eigentliche Übeltäter, wenn eine Liste springt.
                  Text(
                    marke == null ? menge : '$marke · $menge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // `–/–` und nicht `0`: keine Angabe ist keine Null.
            Text(
              kcal == null ? ohneWert : '${formatNumber(kcal)} kcal',
              style: TextStyle(color: muted),
            ),
            if (plus != null) ...[
              const SizedBox(width: 2),
              PlusKnopf(
                zeile: 'off-${produkt.barcode}',
                gebucht: plus.istGebucht(vorlage),
                vorlesetext: plusVorlesetext(
                  name: produkt.name,
                  menge: anzeige?.menge,
                  mahlzeit: plus.mahlzeit,
                  gebucht: plus.istGebucht(vorlage),
                ),
                aufTippen: () => plus.aufPlus(vorlage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ein Satz in der Liste — „nichts gefunden".
class _Hinweis extends StatelessWidget {
  const _Hinweis({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.35, color: muted),
      ),
    );
  }
}
