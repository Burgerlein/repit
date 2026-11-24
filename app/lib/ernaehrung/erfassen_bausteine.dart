// Die Bausteine, aus denen der Suchschirm und die beiden Blätter des
// Eintragwegs bestehen (#285) — Kopfzeile, Kapitelüberschrift,
// Eingabezeile, Wertzeile, Hinweis.
//
// **Eine eigene Datei, damit die drei Views klein bleiben** (`CLAUDE.md`:
// „Views bleiben klein"). Dieselben Zeilen dreimal zu schreiben wäre drei
// Stellen, an denen sich die Form auseinanderentwickelt — und die Form
// ist hier die Anforderung: „Eine Anzeige, die es gibt, hat genau eine
// Form."
//
// Vorlage ist `docs/screens/components.js` (`formCard`, `formRow`,
// `formHead`, `menuPick`, `disclaimer`) und
// `docs/screens/screens/erfassen.js`.
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';

/// Die Kopfzeile eines Blattes: Abbrechen · Titel · Sichern.
///
/// Dieselbe Form wie in `schlaf_eintragen.dart` — der Knopf rechts trägt
/// den Schlüssel, weil an seinem `onPressed` hängt, ob gesichert werden
/// darf.
class ErfassenKopf extends StatelessWidget {
  const ErfassenKopf({
    super.key,
    required this.titel,
    required this.sichernText,
    required this.sichernSchluessel,
    required this.aufAbbrechen,
    required this.aufSichern,
  });

  final String titel;
  final String sichernText;
  final Key sichernSchluessel;
  final VoidCallback? aufAbbrechen;

  /// `null` sperrt den Knopf — und das ist die ganze Anzeige dafür, dass
  /// etwas fehlt. Ein Knopf, der drückbar aussieht und nichts tut, wäre
  /// die schlechtere Auskunft.
  final VoidCallback? aufSichern;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
            onPressed: aufAbbrechen,
            child: const Text('Abbrechen'),
          ),
          Expanded(
            child: Text(
              titel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          CupertinoButton(
            key: sichernSchluessel,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
            onPressed: aufSichern,
            child: Text(sichernText),
          ),
        ],
      ),
    );
  }
}

/// Eine Kapitelüberschrift — `formHead` bzw. `groupHead` aus
/// `components.js`.
class ErfassenKapitel extends StatelessWidget {
  const ErfassenKapitel(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: muted,
        ),
      ),
    );
  }
}

/// Eine Eingabezeile: Beschriftung links, Eingabefeld rechts, Einheit
/// dahinter.
///
/// **Ohne eigenen Controller.** Was getippt wird, geht über [aufEingabe]
/// sofort ins Formular; der Zustand liegt dort und nicht hier. Zwei
/// Stellen, die denselben Text halten, laufen auseinander.
class ErfassenFeldZeile extends StatelessWidget {
  const ErfassenFeldZeile({
    super.key,
    required this.titel,
    required this.aufEingabe,
    this.einheit,
    this.platzhalter,
    this.controller,
    this.nurZiffern = true,
  });

  final String titel;
  final ValueChanged<String> aufEingabe;
  final String? einheit;
  final String? platzhalter;

  /// Nur für Felder, die **vorbelegt** sind — dort braucht es einen
  /// Controller, weil der Anfangstext von außen kommt.
  final TextEditingController? controller;

  final bool nurZiffern;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(titel)),
          Expanded(
            flex: 4,
            // **Der Schlüssel sitzt außen, an der Zeile**, nicht hier:
            // `enterText` sucht das `EditableText` unterhalb des
            // gefundenen Widgets, und eine Zeile ist das, was ein Test
            // meint, wenn er „das Namensfeld" sagt.
            child: CupertinoTextField.borderless(
              controller: controller,
              placeholder: platzhalter,
              textAlign: TextAlign.end,
              // Der Zehnerblock mit Komma: Nährwerte sind Zahlen, und eine
              // volle Tastatur böte Buchstaben an, die hier nie lesbar
              // sind.
              keyboardType: nurZiffern
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              onChanged: aufEingabe,
            ),
          ),
          if (einheit != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: SizedBox(
                width: 34,
                child: Text(einheit!, style: TextStyle(color: muted)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Eine Zeile mit festem Wert — und, wenn [aufTippen] gesetzt ist, einem
/// Winkel, der eine Auswahl verspricht (`menuPick`).
///
/// **Ohne [aufTippen] steht kein Winkel da.** Eine Zeile, die drückbar
/// aussieht und nirgendwohin führt, ist genau das, was
/// `docs/screens/pruefen.mjs` im Entwurfsboard meldet.
class ErfassenWertZeile extends StatelessWidget {
  const ErfassenWertZeile({
    super.key,
    required this.titel,
    required this.wert,
    this.aufTippen,
  });

  final String titel;
  final String wert;
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(titel)),
          Text(wert, style: TextStyle(color: muted)),
          if (aufTippen != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 13,
                color: muted,
              ),
            ),
        ],
      ),
    );

    if (aufTippen == null) return inhalt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: inhalt,
    );
  }
}

/// Der Kleingedruckte Hinweis unter einer Karte (`disclaimer`).
///
/// **Er steht einmal, nicht je Feld** (`CLAUDE.md`): Ein Hinweis in einer
/// schmalen Spalte liefe über mehrere Zeilen und machte die Karte höher,
/// sobald Werte fehlen — der Sprung, den die Regel verhindern soll, nur
/// eine Ebene tiefer.
class ErfassenHinweis extends StatelessWidget {
  const ErfassenHinweis(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.35, color: muted),
      ),
    );
  }
}

/// Eine Trennlinie zwischen zwei Zeilen derselben Karte — `InsetCard`
/// setzt sie bewusst nicht selbst (siehe dort).
class ErfassenTrenner extends StatelessWidget {
  const ErfassenTrenner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 14),
    color: CupertinoDynamicColor.resolve(Palette.line, context),
  );
}

/// Zeigt ein Blatt des Eintragwegs — Anlegen oder Buchen — von unten,
/// fast bildschirmhoch und oben gerundet.
///
/// **Eine Stelle für die Form des Blattes**, nicht je Aufrufer eine: Das
/// Anlegen-Blatt öffnet die Suche, das Buchungsblatt öffnen Suche und
/// Mahlzeiten-Schirm. Wer das Blatt öffnet, schließt es auch — der
/// [baue]-Aufruf bekommt dafür den Kontext des Blattes.
Future<void> zeigeErfassenBlatt(
  BuildContext context,
  Widget Function(BuildContext blattKontext) baue,
) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (blattKontext) => Container(
      height: MediaQuery.of(blattKontext).size.height * 0.88,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: baue(blattKontext),
    ),
  );
}

/// Der Ladeplatzhalter einer Trefferliste: dieselbe Form in Grau — für die
/// eigenen Treffer wie für die aus Open Food Facts.
///
/// **Kein Text**, und schon gar kein Grund — während gelesen wird, ist
/// nichts entschieden. Drei Zeilen, damit die Karte ungefähr so hoch ist
/// wie eine gefüllte.
class ErfassenLadendeListe extends StatelessWidget {
  const ErfassenLadendeListe({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const ErfassenTrenner(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Expanded(child: Platzhalter(beispiel: 'Haferflocken kernig')),
                SizedBox(width: 10),
                Platzhalter(beispiel: '372 kcal'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
