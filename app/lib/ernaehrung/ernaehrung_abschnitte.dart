// Die Abschnitte des Ernährungs-Tag-Schirms (#282, Ernährungsplan Task 4)
// — der Grund „kein Ziel", Wasser, Rezepte, Verlauf, Herleitung und die
// vier Wege. Die Mahlzeitenliste steht seit #434 in
// `mahlzeiten_liste.dart`; Name und Symbol einer Mahlzeit bleiben hier.
// Der Schirm, der sie zusammensetzt, liegt in `ernaehrung_view.dart`; der
// Zustand in `ernaehrung_provider.dart`.
//
// Aufbau, Beschriftung und Reihenfolge nach
// `docs/screens/screens/ernaehrung.js` (Zustände `tag`, `leer`, `laedt`,
// `kein-ziel`, `ueber`) — eigene Datei, weil Views klein bleiben
// (`CLAUDE.md`).
//
// **Den eigenen Makroblock gibt es seit dem 04.11.2026 nicht mehr** (Tim):
// Eiweiß, Kohlenhydrate und Fett stehen jetzt als die drei Ringe oben.
// Dieselben drei Zahlen ein zweites Mal als Balken kosteten eine halbe
// Bildschirmhöhe und sagten nichts Neues.
//
// **Der Vorlesetext nennt den Zustand, nicht das Zeichen.** Jede Zeile,
// die `–/–` zeigen kann, trägt deshalb ein eigenes `Semantics` mit
// `excludeSemantics: true` — sonst läse VoiceOver „Strich Schrägstrich
// Strich" vor (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine
// Form").
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/stammdaten.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/kachel_karte.dart';
import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/symbole.dart';
import '../design/zahlen.dart';
import '../health/health_types.dart';
import 'ernaehrung_provider.dart';
import 'wasser_bausteine.dart';
import 'wasser_blatt.dart';
import 'wasser_provider.dart';

/// Die Beschriftung einer Mahlzeit. Steht hier und nicht im Kern:
/// Nutzertexte gehören in die Views (`CLAUDE.md`).
String mahlzeitName(Mahlzeit mahlzeit) => switch (mahlzeit) {
  Mahlzeit.fruehstueck => 'Frühstück',
  Mahlzeit.mittag => 'Mittag',
  Mahlzeit.snack => 'Snack',
  Mahlzeit.abend => 'Abend',
};

/// Das Symbol einer Mahlzeit — dieselben vier wie im Entwurf
/// (`aufteilung.js`, `ernaehrung.js`, `MAHLZEITEN_NEU`). Steht neben
/// [mahlzeitName], weil es genauso Beschriftung ist.
String mahlzeitSymbol(Mahlzeit mahlzeit) => switch (mahlzeit) {
  Mahlzeit.fruehstueck => '☕️',
  Mahlzeit.mittag => '🍜',
  Mahlzeit.snack => '🍎',
  Mahlzeit.abend => '🥗',
};

/// Die Zeile unter dem Ring, wenn **kein Kalorienziel berechenbar** ist —
/// `ZIEL_FEHLT` in `docs/screens/screens/ernaehrung.js`.
///
/// Bis zum 04.11.2026 hieß sie „Größe, Geburtsjahr und Körperziel" und
/// führte auf *Einstellungen ▸ Über dich*. Beides war falsch, und beides
/// war eine **Zusage**, keine Beschreibung (`CLAUDE.md`, „Keine Zusage
/// stehen lassen, die nicht mehr stimmt"):
///
/// - **Das Körperziel ist nie der Grund.** Ohne Zielgewicht und Zieldatum
///   ist der Überschuss schlicht `0` und das Ziel steht trotzdem
///   (`_koerperzielUeberschuss` im Kern). Wer danach sucht, sucht nach
///   einem Wert, der nicht fehlt.
/// - **„Über dich" gibt es nicht.** Den Schirm hat nie jemand gebaut.
/// - **Die drei Angaben fehlen nicht gemeinsam.** Gewicht, Größe und
///   Geburtsjahr können einzeln fehlen; genannt wird deshalb genau das,
///   was wirklich fehlt.
/// - **„Nicht hinterlegt" und „nicht freigegeben" sind nicht
///   unterscheidbar.** Apple verrät den Lesestatus nicht (`CLAUDE.md`);
///   ein Text, der nur die erste Möglichkeit nennt, behauptet die zweite
///   als ausgeschlossen. Und „nicht getrackt" wäre dieselbe Behauptung,
///   nur andersherum.
///
/// **Ohne Tür** (`dead: true` im Entwurf): Alle drei Angaben kommen aus
/// Apple Health, und dorthin führt kein Weg aus dieser App. Ohne `onTap`
/// zeichnet [IconRow] auch keinen Winkel — keine Zeile, die drückbar
/// aussieht und nirgendwohin führt.
///
/// **Zwei Flächen, ein Inhalt** (#376): Auf dem Ernährungs-Tab sitzt die
/// Zeile auf einer `InsetCard` wie jede Karte dort; auf Home trägt sie
/// mit [kachelKarte] die Fläche der Erholungskarte ([KachelKarte]), wie
/// alle Karten auf Home. Der Schalter statt einer zweiten Fassung, damit
/// der Grund an einer Stelle formuliert bleibt.
class ErnaehrungZielFehlt extends StatelessWidget {
  const ErnaehrungZielFehlt({
    super.key,
    required this.tag,
    required this.stammdaten,
    this.kachelKarte = false,
  });

  final ErnaehrungsTag tag;
  final Stammdaten stammdaten;

  /// `true` auf Home: [KachelKarte] statt `InsetCard`.
  final bool kachelKarte;

  @override
  Widget build(BuildContext context) {
    final zeile = IconRow(
      title: 'Kein Kalorienziel',
      subtitle: _grund(fehlendeAngaben(tag, stammdaten)),
      symbol: 'heart',
      accent: CupertinoDynamicColor.resolve(Palette.warn, context),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: kachelKarte ? KachelKarte(child: zeile) : InsetCard(child: zeile),
    );
  }
}

/// Die Angaben, an denen das Kalorienziel hängt und die gerade fehlen —
/// in der Reihenfolge, in der `kalorienziel` sie prüft.
///
/// **Genau die drei Bedingungen des Kerns**, nicht eine eigene Auswahl:
/// `kalorienziel` gibt `null` zurück bei fehlendem Gewicht, fehlender
/// Größe und fehlendem oder unbrauchbarem Alter — und bei nichts sonst.
/// Steht der Grund auf dem Schirm, ist diese Liste deshalb nicht leer.
///
/// **Das Gewicht wird an den Makrozielen abgelesen**, nicht an einem
/// eigenen Feld: `makrozieleFuer` liefert genau dann keine Mindestmengen,
/// wenn kein brauchbares Gewicht vorliegt (`gewichtKg <= 0`) — dieselbe
/// Grenze, die `kalorienziel` zieht. Ein zweiter Weg zum selben Wert wäre
/// eine zweite Stelle, die der ersten widersprechen kann.
List<String> fehlendeAngaben(ErnaehrungsTag tag, Stammdaten stammdaten) {
  final groesse = stammdaten.groesseCm;
  final alter = stammdaten.alterAm(datumAusTag(tag.tagesSchluessel));
  return [
    if (tag.makroziele.eiweissMinG == null) 'Gewicht',
    if (groesse == null || groesse <= 0) 'Größe',
    if (alter == null || alter <= 0) 'Geburtsjahr',
  ];
}

/// Der Satz zu [angaben] — er nennt die Herkunft und lässt **beide**
/// Möglichkeiten offen.
///
/// Der leere Fall ist nach [fehlendeAngaben] nicht erreichbar; er steht
/// hier trotzdem, weil ein leerer Satz die schlechtere Antwort wäre als
/// ein unscharfer. Eine Zusicherung, die der Code nicht durchsetzt,
/// hinzuschreiben wäre die schlechteste (`CLAUDE.md`).
String _grund(List<String> angaben) {
  if (angaben.isEmpty) {
    return 'Gewicht, Größe oder Geburtsjahr sind in Apple Health nicht '
        'hinterlegt oder nicht freigegeben';
  }
  final liste = angaben.length == 1
      ? angaben.single
      : '${angaben.sublist(0, angaben.length - 1).join(', ')} und '
            '${angaben.last}';
  final verb = angaben.length == 1 ? 'ist' : 'sind';
  return '$liste $verb in Apple Health nicht hinterlegt oder nicht '
      'freigegeben';
}

/// Abschnitt „Rezepte und Einkauf".
///
/// **Beide Zeilen sind abgeblendet und haben keine Tür** (#359, Tims
/// Auftrag vom 04.11.2026: Rezepte und Einkauf werden noch nicht gebaut).
/// Sie stehen da, weil eine fehlende Zeile aussähe wie eine Funktion, die
/// es nicht gibt, und sagen selbst, dass sie später kommen. Ohne `onTap`
/// zeichnet [IconRow] auch keinen Winkel: keine Zeile, die drückbar
/// aussieht und erst nach dem Tipp sagt, dass dahinter nichts ist. Die
/// Entwürfe `rezepte.js` und `einkauf.js` bleiben auf dem Board.
class ErnaehrungRezepte extends StatelessWidget {
  const ErnaehrungRezepte({super.key});

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    Color abgeblendet(CupertinoDynamicColor farbe) =>
        CupertinoDynamicColor.resolve(farbe, context).withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader('Rezepte und Einkauf'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InsetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconRow(
                  title: 'Eigene Rezepte',
                  subtitle: 'kommt in einer späteren Aufgabe',
                  symbol: 'fork.knife',
                  accent: abgeblendet(Palette.bib),
                ),
                Container(height: 1, color: line),
                IconRow(
                  title: 'Einkauf',
                  subtitle: 'kommt in einer späteren Aufgabe',
                  symbol: 'list.bullet',
                  accent: abgeblendet(Palette.ok),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Abschnitt „Wasser" (#311).
///
/// Die Zeile zeigt eingetragene Gläser **und** das Wasser in gebuchten
/// Lebensmitteln gegen das Ziel; darunter zwei Knöpfe, die eintragen —
/// auf den **offenen** Tag. Ein Glas ist keine Mahlzeit: Es landet in
/// `wasser_eintraege`, nicht in einer der vier Zeilen, und zählt keine
/// Kalorie.
///
/// **Die Zeile ist eine Tür** (#360): Sie öffnet in jedem Zustand das
/// Blatt „Wasser heute" (`wasser_blatt.dart`) mit den Gläsern des offenen
/// Tages — dort wird geändert, gelöscht und eine freie Menge eingetragen.
/// Die beiden Knöpfe bleiben hier: Das schnelle Glas kostet keinen Umweg.
class ErnaehrungWasser extends ConsumerWidget {
  const ErnaehrungWasser({super.key, required this.tag});

  final ErnaehrungsTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glaeser = ref.watch(wasserProvider(tag.tagesSchluessel)).value;
    final ausEssen = gegessenWerte(tag)?.wasserMl;
    final ziel = tag.makroziele.wasserMinMl;

    // Kein Wert, solange weder ein Glas noch ein Lebensmittel mit Wasser
    // dasteht — `–/–`, nicht `0`. Ein eingetragenes Glas ist dagegen immer
    // eine Zahl, auch wenn die Lebensmittel noch gelesen werden.
    final glasSumme = glaeser == null || glaeser.isEmpty
        ? null
        : glaeser.fold<double>(0, (summe, g) => summe + g.mengeMl);
    final getrunken = glasSumme == null && ausEssen == null
        ? null
        : (glasSumme ?? 0) + (ausEssen ?? 0);

    final text = getrunken == null
        ? '$ohneWert von ${liter(ziel)} l'
        : '${liter(getrunken)} von ${liter(ziel)} l';
    final anteil = getrunken == null || ziel <= 0
        ? null
        : '${formatNumber(getrunken / ziel * 100)} %';
    final letztes = glaeser == null || glaeser.isEmpty
        ? null
        : glaeser.last.zeitpunkt;
    final unterzeile = letztes == null
        ? 'aus deinen Einträgen'
        : 'eingetragen · zuletzt ${wanduhr(letztes)}';

    void oeffneBlatt() =>
        zeigeWasserBlatt(context, tagesSchluessel: tag.tagesSchluessel);

    // Derselbe Hinweis wie beim Essen, einmal je App-Lauf (#283).
    Future<void> trageEin(double mengeMl) =>
        trageWasserEin(context, ref, tag.tagesSchluessel, mengeMl);

    return Column(
      key: const Key('ernaehrung-wasser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader('Wasser'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InsetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  key: const Key('wasser-zeile'),
                  label: getrunken == null
                      ? 'Wasser, keine Werte'
                      : 'Wasser, $text, $unterzeile',
                  button: true,
                  onTap: oeffneBlatt,
                  excludeSemantics: true,
                  child: IconRow(
                    title: text,
                    subtitle: unterzeile,
                    value: anteil,
                    symbol: 'scale',
                    accent: CupertinoDynamicColor.resolve(
                      Palette.river,
                      context,
                    ),
                    onTap: oeffneBlatt,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: [
                      WasserKnopf(
                        key: const Key('wasser-plus-250'),
                        titel: '+ 250 ml',
                        onPressed: () => trageEin(250),
                      ),
                      const SizedBox(width: 8),
                      WasserKnopf(
                        key: const Key('wasser-plus-500'),
                        titel: '+ 500 ml',
                        onPressed: () => trageEin(500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Die vier Wege unten — **gleich groß**, wie im Entwurf.
///
/// Der Foto-Weg ist abgeblendet: Ein KI-Zugang zum Abschätzen eines
/// Tellers fehlt (#287). „Barcode" öffnet die Kamera (#324, [onBarcode]),
/// „Suchen" die Suche (#285, [onSuchen]). Favoriten gibt es noch nicht —
/// sie sagen das über [onWeg], statt stumm zu bleiben.
class ErnaehrungWege extends StatelessWidget {
  const ErnaehrungWege({
    super.key,
    required this.onWeg,
    required this.onBarcode,
    required this.onFoto,
    required this.onSuchen,
  });

  final void Function(String weg) onWeg;
  final VoidCallback onBarcode;
  final VoidCallback onFoto;
  final VoidCallback onSuchen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      key: const Key('ernaehrung-wege'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Weg(label: 'Barcode', symbol: 'ruler', onTap: onBarcode),
              _Weg(label: 'Foto', symbol: 'photo', onTap: onFoto, blass: true),
              _Weg(label: 'Suchen', symbol: 'list.bullet', onTap: onSuchen),
              _Weg(
                label: 'Favoriten',
                symbol: 'checkmark',
                onTap: () => onWeg('Favoriten'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Produktdaten von Open Food Facts',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Weg extends StatelessWidget {
  const _Weg({
    required this.label,
    required this.symbol,
    required this.onTap,
    this.blass = false,
  });

  final String label;
  final String symbol;
  final VoidCallback onTap;
  final bool blass;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final farbe = blass ? ink.withValues(alpha: 0.4) : ink;

    return Expanded(
      child: Semantics(
        label: blass ? '$label, noch nicht verfügbar' : label,
        button: true,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: kartenFlaeche(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbole.aufloesen(symbol), size: 20, color: farbe),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: farbe),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
