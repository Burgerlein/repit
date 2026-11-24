// Der Suchschirm des Eintragwegs (#285) — `docs/screens/screens/
// erfassen.js`, Zustände `suche-leer` und `suche-treffer`.
//
// API und Verhalten sind durch `app/test/ernaehrung/erfassen_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Eine Liste, eigene vorn** (#284; Tim, 04.11.2026: „Eigene Treffer
// sollen einfach mit den anderen gemischt werden, höchstens mit einem Tag
// gekennzeichnet."). Die eigenen Treffer stehen sofort da, ungebremst, mit
// dem Abzeichen „eigen"; ab dem zweiten Zeichen fragt die Suche zusätzlich
// online und hängt das in derselben Karte an (`off_abschnitt.dart`,
// `off_suche_provider.dart`). Gleiche Produkte erscheinen einmal — das
// rechnet der Provider, nicht dieses Widget. Barcode und Foto sind spätere Tickets; ein
// Text, der sie nennt, wäre eine Zusage ohne Deckung (`CLAUDE.md`, „Keine
// Zusage stehen lassen, die nicht mehr stimmt").
//
// **„+" je Zeile** (#440, Entscheidung 10, V24): Mit [SuchePlus] trägt
// jede Trefferzeile rechts einen Knopf, der genau die Menge ihrer zweiten
// Zeile bucht, und nach dem Buchen einen Haken. Was gebucht und gezählt
// ist, hält `SucheSeite`; hier wird nur gezeigt und gemeldet.
//
// **Die Keine-Daten-Ansicht gehört dazu** (Tim, 28.10.2026): Ist die
// eigene Tabelle leer, steht der Grund da **und** der Weg hinaus. Und
// während gelesen wird, steht kein Leerstand da — das wäre Fehler `01`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lebensmittel_repository.dart';
import '../design/glas_abstand.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import 'anlegen_blatt.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_provider.dart';
import 'off_abschnitt.dart';
import 'off_suche_provider.dart';
import 'seed_abschnitt.dart';
import 'seed_suche_provider.dart';
import 'plus_bausteine.dart';

/// Der Suchschirm.
///
/// Bringt **keinen** eigenen `CupertinoPageScaffold` mit — den stellt,
/// wer ihn schiebt.
class SucheView extends ConsumerWidget {
  const SucheView({
    super.key,
    this.onGewaehlt,
    this.kacheln,
    this.platzhalter = 'Lebensmittel suchen',
    this.umrandet = false,
    this.plus,
    this.band,
  });

  /// Was passiert, wenn eine Trefferzeile angetippt wird.
  final void Function(LebensmittelVorlage vorlage)? onGewaehlt;

  /// Die Kachelreihe der Wege über dem Suchfeld (#439) — sie scrollt mit,
  /// wie im Entwurf (`SUCHE_NEU`). Ohne sie beginnt die Suche beim Feld.
  final Widget? kacheln;

  /// Was das leere Suchfeld fragt — in der `SucheSeite` die Mahlzeit
  /// (V23).
  final String platzhalter;

  /// Das Suchfeld umrandet wie im Entwurf (`.searchfield.fokus`).
  final bool umrandet;

  /// „+" je Zeile (#440). Ohne bleibt die Zeile ohne Knopf — so in der
  /// Auswahl des KI-Prüfblatts, die nichts bucht.
  final SuchePlus? plus;

  /// Das Band nach einer Buchung (V26), unter der Liste wie im Entwurf
  /// (`vorschlag-gebucht`).
  final Widget? band;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eigene = ref.watch(suchtrefferProvider).value;
    final gesucht = ref.watch(suchtextProvider).trim().isNotEmpty;
    final online = ref.watch(offAnzeigeProvider);
    // Die zweite Stufe: die mitgelieferte Datenbank. Sie steht zwischen
    // den eigenen Lebensmitteln und der Online-Suche — so legt es die
    // Spec fest („Die Suche läuft lokal zuerst"), und sie braucht kein
    // Netz.
    final seed = ref.watch(seedSucheProvider);

    // **Die Namensnennung hängt an den Daten** (ODbL): Sie steht da,
    // sobald etwas aus Open Food Facts zu sehen ist — eine Online-Zeile
    // oder eine übernommene eigene, auch in „zuletzt benutzt". Ohne beides
    // steht sie nicht da; ein Hinweis auf eine Quelle, die nichts
    // beigetragen hat, wäre eine falsche Auskunft.
    final eigeneListe = eigene ?? const <LebensmittelVorlage>[];
    final ausOff =
        online is OffAnzeigeZeilen ||
        seed.any((t) => t.quelle == 'off') ||
        eigeneListe.any((vorlage) => vorlage.herkunft == Herkunft.off);

    // **Dieselbe Regel für den Bundeslebensmittelschlüssel** (#543): Die
    // Zitierweise steht da, sobald eine BLS-Zeile zu sehen ist — eine aus
    // dem Seed oder eine übernommene eigene. Das Max Rubner-Institut
    // stellt die Daten lizenzfrei bereit und bittet um genau diese
    // Nennung; sie hängt an den Daten, nicht an der Stelle.
    final ausBls =
        seed.any((t) => t.quelle == 'bls') ||
        eigeneListe.any((vorlage) => vorlage.herkunft == Herkunft.bls);

    // Die eine Liste: eigene vorn, der Online-Teil dahinter. Gerechnet ist
    // hier nichts — zusammengefasst hat `offAnzeigeProvider`.
    final zeilen = <Widget>[
      // `null` ist „noch nicht nachgesehen". Ein Leerstand hier wäre die
      // Behauptung, es gäbe nichts — Fehler `01`.
      if (eigene == null)
        const ErfassenLadendeListe()
      else
        for (final vorlage in eigene)
          _Trefferzeile(
            key: Key('erfassen-treffer-${vorlage.id}'),
            vorlage: vorlage,
            // Das Abzeichen unterscheidet nur dort, wo gemischt wird. In
            // „zuletzt benutzt" ist ohnehin alles eigen.
            eigen: gesucht,
            plus: plus,
            aufTippen: () => onGewaehlt?.call(vorlage),
          ),
      ...seedZeilen(seed, onGewaehlt: onGewaehlt, plus: plus),
      ...offZeilen(
        online,
        eigeneLeer: eigene?.isEmpty ?? false,
        onGewaehlt: onGewaehlt,
        plus: plus,
      ),
    ];
    // Der Leerstand nur, wenn nachgesehen wurde und die Liste sonst nichts
    // trägt — kein Platzhalter, kein Online-Satz.
    if (zeilen.isEmpty) zeilen.add(_Leer(gesucht: gesucht));

    return SingleChildScrollView(
      // Seit der Verdrahtung liegt die Suche auf dem Stapel eines Tabs,
      // unter durchscheinender Navigations- und Tableiste. `GlasAbstand`
      // rückt den Inhalt um genau deren Höhe ein — ohne ihn finge das
      // Suchfeld unter der Leiste an.
      padding:
          GlasAbstand.of(context) + const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kacheln case final kacheln?)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: kacheln),
          CupertinoSearchTextField(
            key: const Key('erfassen-suchfeld'),
            placeholder: platzhalter,
            decoration: umrandet ? _umrandet(context) : null,
            onChanged: (text) =>
                ref.read(suchtextProvider.notifier).setze(text),
          ),

          // **Eine Überschrift, keine Abschnitte.** „Eigene Treffer" und
          // „Open Food Facts" gibt es seit dem 04.11.2026 nicht mehr.
          ErfassenKapitel(gesucht ? 'Treffer' : 'Zuletzt benutzt'),

          // **Dieselbe Karte in jedem Zustand**: Treffer, Leerstand und
          // Ladezustand sitzen an derselben Stelle. Fiele die Karte weg,
          // spränge der Schirm, sobald die Werte eintreffen.
          InsetCard(
            key: const Key('erfassen-liste'),
            child: Column(
              children: [
                for (var i = 0; i < zeilen.length; i++) ...[
                  if (i > 0) const ErfassenTrenner(),
                  zeilen[i],
                ],
              ],
            ),
          ),

          if (online is OffAnzeigeKeinNetz) const OffKeinNetzHinweis(),

          if (band case final band?)
            Padding(padding: const EdgeInsets.only(top: 10), child: band),

          const ErfassenKapitel('Außerdem'),
          InsetCard(child: _AnlegenZeile(key: const Key('erfassen-anlegen'))),

          // Mit „+" der Satz aus der Spec (`PLUS_FUSS`). Die Namensnennung
          // darin hängt weiter an den Daten (ODbL): ohne Open Food Facts
          // auf dem Schirm keine Quelle, die nichts beigetragen hat.
          if (plus != null)
            ErfassenHinweis(
              key: ausOff ? const Key('erfassen-odbl') : null,
              '„+" bucht die Menge aus der zweiten Zeile — die Portion vom '
              'letzten Mal, sonst 100 g. Für eine andere Menge die Zeile '
              'antippen.${ausOff ? ' Produktdaten von Open Food Facts '
                        '(ODbL).' : ''}',
            )
          else if (ausOff)
            ErfassenHinweis(
              key: const Key('erfassen-odbl'),
              'Deine eigenen Lebensmittel und Produkte aus Open Food Facts '
              '(ODbL) in einer Liste; gleiche Produkte erscheinen einmal. '
              'Werte aus Open Food Facts pflegen Nutzer — sie können von der '
              'Packung abweichen. Was du buchst, landet in deiner eigenen '
              'Liste.${ausBls ? ' $_blsNennung' : ''}',
            )
          else if (ausBls)
            const ErfassenHinweis(
              key: Key('erfassen-bls'),
              'Deine eigenen Lebensmittel stehen vorn, darunter '
              'Grundnahrung aus dem Bundeslebensmittelschlüssel. Was du '
              'buchst, landet in deiner eigenen Liste. $_blsNennung',
            )
          else
            const ErfassenHinweis(
              'Deine eigenen Lebensmittel stehen vorn; ab zwei Buchstaben '
              'wird zusätzlich online gesucht. Was du buchst, steht danach '
              'unter „Zuletzt benutzt" und lässt sich beliebig oft buchen.',
            ),
        ],
      ),
    );
  }
}

/// `.searchfield.fokus`: die Fläche des Felds, innen 1,6 Punkte in
/// `river` umrandet.
BoxDecoration _umrandet(BuildContext context) => BoxDecoration(
  color: CupertinoDynamicColor.resolve(
    CupertinoColors.tertiarySystemFill,
    context,
  ),
  borderRadius: BorderRadius.circular(9),
  border: Border.all(
    color: CupertinoDynamicColor.resolve(Palette.river, context),
    width: 1.6,
  ),
);

/// Eine Trefferzeile: Name, darunter die Menge, die „+" bucht, rechts deren
/// Kalorien und — mit [plus] — der Knopf.
///
/// **Die zweite Zeile sagt, was „+" bucht** (V24): „2 Bon (11,8 g)",
/// „80 g" oder „100 g", aus derselben Vorwahl wie das Blatt
/// ([trefferVorwahlProvider]). Sie ersetzt „je 100 g".
/// Die Quellennennung für den Bundeslebensmittelschlüssel, wörtlich so,
/// wie das Max Rubner-Institut sie erbittet (FAQ 16 auf blsdb.de).
///
/// **An einer Stelle, nicht an jeder Zeile.** Ein Hinweis je Feld liefe in
/// einer schmalen Spalte über mehrere Zeilen und machte die Karte höher,
/// sobald BLS-Treffer dabei sind — der Sprung, den die Leerzustandsregel
/// verhindern soll, nur eine Ebene tiefer.
const String _blsNennung =
    'Nährwerte zu Grundnahrung: Max Rubner-Institut (2025), '
    'Bundeslebensmittelschlüssel (BLS), Version 4.0.';

class _Trefferzeile extends ConsumerWidget {
  const _Trefferzeile({
    super.key,
    required this.vorlage,
    required this.eigen,
    required this.plus,
    required this.aufTippen,
  });

  final LebensmittelVorlage vorlage;

  /// Ob das Abzeichen „eigen" dasteht.
  final bool eigen;

  final SuchePlus? plus;

  final VoidCallback aufTippen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final anzeige = ref.watch(trefferVorwahlProvider(vorlage));
    // Ein leerer Name kommt nur aus einer migrierten Zeile (Schema v13,
    // Vorgabewert `''`). Er wird benannt, nicht erfunden.
    final name = vorlage.name.isEmpty ? 'Ohne Namen' : vorlage.name;
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
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  // Solange die letzte Buchung nicht gelesen ist, steht
                  // ein Strich da — an derselben Stelle, in derselben
                  // Höhe. Ein „100 g" sprang gleich wieder um.
                  Text(
                    anzeige?.menge ?? ohneWert,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            if (eigen) ...[
              const SizedBox(width: 8),
              const _AbzeichenEigen(key: Key('erfassen-abzeichen-eigen')),
            ],
            const SizedBox(width: 10),
            // `–/–` und nicht `0`: Eine Vorlage ohne Kalorienangabe hat
            // keine 0 kcal, sie hat keine Angabe.
            Text(
              anzeige?.kcal == null
                  ? ohneWert
                  : '${formatNumber(anzeige!.kcal!)} kcal',
              style: TextStyle(color: muted),
            ),
            if (plus != null) ...[
              const SizedBox(width: 2),
              PlusKnopf(
                zeile: 'treffer-${vorlage.id}',
                gebucht: plus.istGebucht(vorlage),
                vorlesetext: plusVorlesetext(
                  name: name,
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

/// Das Abzeichen „eigen" — `.foodrow .tag` im Entwurf. Es kennzeichnet,
/// was aus Tims eigener Tabelle kommt; Online-Treffer tragen es nicht.
class _AbzeichenEigen extends StatelessWidget {
  const _AbzeichenEigen({super.key});

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
        'EIGEN',
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

/// Der Weg „Lebensmittel anlegen" — **steht in jedem Zustand da**, neben
/// Treffern wie im Leerstand. Im Leerstand ist er genau das, was zu tun
/// ist.
class _AnlegenZeile extends StatelessWidget {
  const _AnlegenZeile({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    // Aufgelöst wie Untertitel und Symbol daneben. Ohne Farbe erbte der
    // Titel eine dynamische Farbe, die Flutter unaufgelöst mit ihrem
    // Hellwert malt — schwarz auf der dunklen Karte, also unsichtbar.
    // Tim auf dem Gerät, 04.11.2026: „der Button anlegen hat keine
    // Schrift." Dieselbe Form wie der Titel in `IconRow`.
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _zeigeAnlegen(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(CupertinoIcons.plus_circle, size: 20, color: river),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lebensmittel anlegen',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Name und Nährwerte je 100 g',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_forward, size: 14, color: muted),
          ],
        ),
      ),
    );
  }
}

/// Öffnet das Blatt „Lebensmittel anlegen" — **und schließt es auch**.
///
/// Das Blatt meldet nur `onFertig`; wer es öffnet, schließt es. Deshalb
/// steht `Navigator.pop` hier und nicht dort.
Future<void> _zeigeAnlegen(BuildContext context) {
  return zeigeErfassenBlatt(
    context,
    (blattKontext) =>
        AnlegenBlatt(onFertig: (_) => Navigator.pop(blattKontext)),
  );
}

/// Der Leerstand — **nur, wenn nachgesehen wurde und nichts da ist.**
///
/// Er nennt den Grund und keine Quelle, die es in diesem Zuschnitt nicht
/// gibt. Den Weg hinaus nimmt er nicht mit: „Lebensmittel anlegen" steht
/// gleich darunter.
class _Leer extends StatelessWidget {
  const _Leer({required this.gesucht});

  final bool gesucht;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // Ohne Suchtext zeigt die Karte nur Gebuchtes (#345) — leer heißt
    // dort „noch nichts gebucht", nicht „nichts angelegt". Der Satz steht
    // in `erfassen.js`, Zustand `suche-leer`.
    return Padding(
      key: Key(gesucht ? 'erfassen-leer' : 'zuletzt-leer'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Text(
        gesucht
            ? 'Dazu steht nichts in deinen Lebensmitteln. Leg es unten an — '
                  'danach findest du es hier.'
            : 'Noch nichts gebucht. Such oben nach einem Lebensmittel oder '
                  'scanne einen Barcode.',
        style: TextStyle(fontSize: 13, height: 1.35, color: muted),
      ),
    );
  }
}
