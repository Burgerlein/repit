// Der **Portionswähler** im Buchungsblatt (#399, unter #325) —
// `docs/screens/screens/erfassen.js`, Zustände `produkt`, `produkt-laedt`,
// `produkt-kein-netz`, `produkt-ohne-portion`, gezeichnet mit dem Baustein
// `portion` aus `docs/screens/components.js`.
//
// Verhalten durch `app/test/ernaehrung/portionen_blatt_test.dart` und
// `portion_dialog_test.dart` vorgegeben (siehe deren Dateikopf) — diese
// Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer
// Tests schreibt, schreibt nicht die Implementierung").
//
// **Eine Form für alle Zustände** (`CLAUDE.md`, „Eine Anzeige, die es
// gibt, hat genau eine Form"): Mengenkarte, Zeile und Knopfreihe stehen
// immer da, je in derselben Höhe. Die Karte ist fest hoch, die Zeile
// einzeilig, die Reihe einzeilig und quer scrollend. Kommen Portionen an,
// wächst nichts — es füllt sich nur.
//
// Der Wähler rechnet nichts und hält nichts. Das Formular liegt im Blatt,
// Tastendrücke gehen über die Rückrufe dorthin.
import 'package:flutter/cupertino.dart';

import '../data/portion.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import 'erfassen_formular.dart';
import 'portions_abruf.dart';
import 'portions_text.dart';

/// Die Mengenkarte, die Zeile darunter und die Knopfreihe
/// g · Portionen · „+ Portion".
class PortionsWaehler extends StatelessWidget {
  const PortionsWaehler({
    super.key,
    required this.formular,
    required this.abruf,
    required this.mengeController,
    required this.anzahlController,
    required this.aufMenge,
    required this.aufAnzahl,
    required this.aufGramm,
    required this.aufPortion,
    required this.aufPlus,
    required this.aufMinus,
    this.aufLangdruck,
    this.aufNeu,
  });

  final BuchungsFormular formular;

  /// Wie der Abruf bei Open Food Facts steht — `null`, wenn das Blatt
  /// nicht nachfragt.
  final PortionsAbruf? abruf;

  final TextEditingController mengeController;
  final TextEditingController anzahlController;
  final ValueChanged<String> aufMenge;
  final ValueChanged<String> aufAnzahl;
  final VoidCallback? aufGramm;
  final ValueChanged<Portion>? aufPortion;
  final VoidCallback? aufPlus;
  final VoidCallback? aufMinus;

  /// Langdruck auf eine Portion — „Portion ändern". `null` heißt: keiner,
  /// wie im Ändern-Blatt.
  final ValueChanged<Portion>? aufLangdruck;

  /// „+ Portion". `null` heißt: Der Knopf steht nicht da, wie im
  /// Ändern-Blatt — eine neue Portion gehört an das Lebensmittel, nicht an
  /// einen gebuchten Eintrag.
  final VoidCallback? aufNeu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Mengenkarte(
          formular: formular,
          mengeController: mengeController,
          anzahlController: anzahlController,
          aufMenge: aufMenge,
          aufAnzahl: aufAnzahl,
          aufPlus: aufPlus,
          aufMinus: aufMinus,
        ),
        _Zeile(formular: formular, abruf: abruf, kannNeu: aufNeu != null),
        _Knopfreihe(
          formular: formular,
          laedt: abruf is AbrufLaeuft,
          aufGramm: aufGramm,
          aufPortion: aufPortion,
          aufLangdruck: aufLangdruck,
          aufNeu: aufNeu,
        ),
      ],
    );
  }
}

/// Die große Zahl: bei „g" das Mengenfeld, bei einer Portion − Anzahl +.
///
/// **Bei „g" bleibt das Textfeld** (Entscheidung 11), ohne − und +. Ihr
/// Platz bleibt frei, damit die Zahl an derselben Stelle steht und die
/// Karte nicht ihre Form wechselt.
class _Mengenkarte extends StatelessWidget {
  const _Mengenkarte({
    required this.formular,
    required this.mengeController,
    required this.anzahlController,
    required this.aufMenge,
    required this.aufAnzahl,
    required this.aufPlus,
    required this.aufMinus,
  });

  final BuchungsFormular formular;
  final TextEditingController mengeController;
  final TextEditingController anzahlController;
  final ValueChanged<String> aufMenge;
  final ValueChanged<String> aufAnzahl;
  final VoidCallback? aufPlus;
  final VoidCallback? aufMinus;

  static const _knopf = 36.0;
  static const _rand = 12.0;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final zahl = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.title,
        gewicht: FontWeight.w400,
      ).copyWith(color: ink, fontSize: 30),
    );
    // Die Höhe kommt aus der Schrift, nicht aus einer festen Zahl — und
    // ist in beiden Formen dieselbe.
    final zeile = textMass(context, '0', zahl).height;
    final hoehe = (zeile > _knopf ? zeile : _knopf) + 2 * _rand;

    final portion = formular.portion;
    final anzahl = formular.anzahl;
    final mitPortion = portion != null;

    final feld = mitPortion
        ? _Zahlfeld(
            key: const Key('portion-anzahl'),
            controller: anzahlController,
            stil: zahl,
            aufEingabe: aufAnzahl,
            vorlesen: 'Anzahl',
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // So breit wie die Zahl, damit die Einheit direkt dahinter
              // steht (`.portion .amt b i`) — und mindestens so breit,
              // dass ein leeres Feld noch zu treffen ist.
              Flexible(
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48),
                    child: _Zahlfeld(
                      key: const Key('buchung-menge'),
                      controller: mengeController,
                      stil: zahl,
                      aufEingabe: aufMenge,
                      vorlesen: formular.fluessig ? 'Milliliter' : 'Gramm',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                formular.fluessig ? 'ml' : 'g',
                style: TextStyle(color: muted, fontSize: 15),
              ),
            ],
          );

    return InsetCard(
      child: SizedBox(
        height: hoehe,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _rand),
          child: Row(
            children: [
              _RundKnopf(
                knopfKey: mitPortion ? const Key('portion-minus') : null,
                zeichen: CupertinoIcons.minus,
                vorlesen: 'Eine weniger',
                sichtbar: mitPortion,
                // V7: Bei 1 oder weniger ist − gesperrt.
                aufTippen: anzahl != null && anzahl > 1 ? aufMinus : null,
              ),
              Expanded(child: Center(child: feld)),
              _RundKnopf(
                knopfKey: mitPortion ? const Key('portion-plus') : null,
                zeichen: CupertinoIcons.plus,
                vorlesen: 'Eine mehr',
                sichtbar: mitPortion,
                aufTippen: aufPlus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ein Zahlfeld mit dem Ziffernblock — **auch für 0,5** (Entscheidung 11):
/// Der Ziffernblock trägt das Komma.
class _Zahlfeld extends StatelessWidget {
  const _Zahlfeld({
    super.key,
    required this.controller,
    required this.stil,
    required this.aufEingabe,
    required this.vorlesen,
  });

  final TextEditingController controller;
  final TextStyle stil;
  final ValueChanged<String> aufEingabe;
  final String vorlesen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: vorlesen,
      child: CupertinoTextField.borderless(
        controller: controller,
        style: stil,
        textAlign: TextAlign.center,
        padding: EdgeInsets.zero,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onChanged: aufEingabe,
      ),
    );
  }
}

/// − oder + als runder Knopf (`.portion .amt span`). Unsichtbar behält er
/// seinen Platz.
class _RundKnopf extends StatelessWidget {
  const _RundKnopf({
    required this.knopfKey,
    required this.zeichen,
    required this.vorlesen,
    required this.sichtbar,
    required this.aufTippen,
  });

  /// Der Schlüssel sitzt am `CupertinoButton` selbst — an seinem
  /// `onPressed` hängt, ob er gesperrt ist.
  final Key? knopfKey;
  final IconData zeichen;
  final String vorlesen;
  final bool sichtbar;
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    final knopf = CupertinoButton(
      key: knopfKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(_Mengenkarte._knopf),
      onPressed: sichtbar ? aufTippen : null,
      child: Semantics(
        label: vorlesen,
        child: Container(
          width: _Mengenkarte._knopf,
          height: _Mengenkarte._knopf,
          decoration: BoxDecoration(
            color: line.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(zeichen, size: 20, color: river),
        ),
      ),
    );

    return Visibility(
      visible: sichtbar,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: knopf,
    );
  }
}

/// Die **eine** Zeile unter der Zahl — einzeilig, feste Höhe, in jedem
/// Zustand da (V8). Was sie sagt, in dieser Reihenfolge:
///
/// a. Portion gewählt: „2 × 5,9 g = 11,8 g"
/// b. Abruf läuft: „Portionen werden nachgesehen …"
/// c. Abruf gescheitert: „Portionen nicht abrufbar — kein Netz"
/// d. keine Portion bekannt: „Keine Portion bekannt — „+ Portion" legt
///    eine an"
/// e. „g" gewählt, Portionen bekannt: die Menge allein, „100 g"
///
/// **„Kein Netz" ist nicht „keine Portion"**: Ein gescheiterter Abruf hat
/// nicht nachgesehen, und während er läuft, ist nichts entschieden
/// (Fehler `01`).
class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.formular,
    required this.abruf,
    required this.kannNeu,
  });

  final BuchungsFormular formular;
  final PortionsAbruf? abruf;

  /// Ob „+ Portion" dasteht. Ohne den Knopf (Ändern-Blatt) verwiese (d)
  /// auf etwas, das es nicht gibt; dann gilt (e).
  final bool kannNeu;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.tabularNumbers(
      TextStyle(fontSize: 13, color: muted),
    );
    final (text, vorlesen) = _inhalt();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FesteZeilen(
        key: const Key('portion-zeile'),
        zeilen: 1,
        stil: stil,
        child: SizedBox(
          width: double.infinity,
          child: Semantics(
            label: vorlesen,
            excludeSemantics: true,
            child: Text(
              text,
              style: stil,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _inhalt() {
    final fluessig = formular.fluessig;
    final einheit = fluessig ? 'Milliliter' : 'Gramm';

    final portion = formular.portion;
    if (portion != null) {
      final anzahl = formular.anzahl;
      if (anzahl == null) return (ohneWert, 'Portion, keine Anzahl');
      final menge = formular.mengeG ?? anzahl * portion.mengeG;
      return (
        portionsRechnung(
          anzahl: anzahl,
          portionG: portion.mengeG,
          fluessig: fluessig,
        ),
        'Portion, ${portionsAnzahl(anzahl)} ${portion.name}, '
            '${_ohneEinheit(menge)} $einheit',
      );
    }

    switch (abruf) {
      case AbrufLaeuft():
        return (
          'Portionen werden nachgesehen …',
          'Portionen werden nachgesehen',
        );
      case AbrufGescheitert():
        return (
          'Portionen nicht abrufbar — kein Netz',
          'Portionen nicht abrufbar, kein Netz',
        );
      case AbrufFertig() || null:
        break;
    }

    if (formular.portionen.isEmpty && kannNeu) {
      return (
        'Keine Portion bekannt — „+ Portion" legt eine an',
        'Keine Portion bekannt',
      );
    }

    final menge = formular.mengeG;
    if (menge == null) return (ohneWert, 'Keine Menge');
    return (
      portionsMenge(menge, fluessig: fluessig),
      '${_ohneEinheit(menge)} $einheit',
    );
  }

  /// „11,8" aus „11,8 g" — für den Vorlesetext, der die Einheit ausschreibt.
  String _ohneEinheit(double menge) =>
      portionsMenge(menge, fluessig: false).replaceAll(' g', '');
}

/// Die Knopfreihe g · Portionen · Platzhalter · „+ Portion" — **einzeilig,
/// quer scrollend**: Drei Portionen machen das Blatt nicht höher als eine.
///
/// „g" steht immer vorn. Die Portionen folgen in der Reihenfolge des
/// Formulars, aufsteigend nach Gramm. Während des Abrufs stehen zwei graue
/// Platzhalter hinter den bekannten (V13), weil Open Food Facts höchstens
/// Portion und Packung liefert.
class _Knopfreihe extends StatelessWidget {
  const _Knopfreihe({
    required this.formular,
    required this.laedt,
    required this.aufGramm,
    required this.aufPortion,
    required this.aufLangdruck,
    required this.aufNeu,
  });

  final BuchungsFormular formular;
  final bool laedt;
  final VoidCallback? aufGramm;
  final ValueChanged<Portion>? aufPortion;
  final ValueChanged<Portion>? aufLangdruck;
  final VoidCallback? aufNeu;

  static const _abstand = 6.0;

  @override
  Widget build(BuildContext context) {
    final hoehe = textMass(context, 'Ag', _Chip.stil).height + 2 * _Chip.innen;
    final fluessig = formular.fluessig;
    final gewaehlt = formular.portion;

    final knoepfe = <Widget>[
      _Chip(
        key: const Key('portion-gramm'),
        text: fluessig ? 'ml' : 'g',
        art: gewaehlt == null ? _ChipArt.an : _ChipArt.aus,
        aufTippen: aufGramm,
      ),
      for (final (i, p) in formular.portionen.indexed)
        _Chip(
          key: Key('portion-knopf-$i'),
          text: portionsKnopf(p, fluessig: fluessig),
          art: p == gewaehlt ? _ChipArt.an : _ChipArt.aus,
          aufTippen: aufPortion == null ? null : () => aufPortion!(p),
          aufLangdruck: aufLangdruck == null ? null : () => aufLangdruck!(p),
        ),
      if (laedt)
        for (var i = 0; i < 2; i++)
          const _Chip(
            key: Key('portion-platzhalter'),
            text: 'Portion (00 g)',
            art: _ChipArt.platzhalter,
          ),
      if (aufNeu != null)
        _Chip(
          key: const Key('portion-neu'),
          text: '+ Portion',
          art: _ChipArt.neu,
          aufTippen: aufNeu,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: SizedBox(
        key: const Key('portion-reihe'),
        height: hoehe,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, k) in knoepfe.indexed)
                // Je Knopf ein eigener Rahmen: Die beiden Platzhalter
                // tragen denselben Schlüssel, und Geschwister dürfen das
                // nicht.
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : _abstand),
                  child: k,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChipArt { an, aus, platzhalter, neu }

/// Ein Knopf der Reihe (`.portion .units span`).
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.text,
    required this.art,
    this.aufTippen,
    this.aufLangdruck,
  });

  final String text;
  final _ChipArt art;
  final VoidCallback? aufTippen;
  final VoidCallback? aufLangdruck;

  static const stil = TextStyle(fontSize: 13.5);
  static const innen = 6.0;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final fill = line.withValues(alpha: 0.6);

    final (Color? grund, Color farbe, BoxBorder? rand) = switch (art) {
      _ChipArt.an => (river, const Color(0xFFFFFFFF), null),
      _ChipArt.aus => (fill, muted, null),
      _ChipArt.platzhalter => (fill.withValues(alpha: 0.35), muted, null),
      _ChipArt.neu => (
        null,
        river,
        Border.all(color: river.withValues(alpha: 0.4)),
      ),
    };

    // Der Platzhalter hat die Form des echten Knopfs, aber keinen Text im
    // Baum — sonst fände jeder Test ein „Portion (00 g)", das niemand
    // sieht (`Platzhalter`).
    final inhalt = art == _ChipArt.platzhalter
        ? SizedBox.fromSize(size: textMass(context, text, stil))
        : Text(text, style: stil.copyWith(color: farbe), maxLines: 1);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: innen),
      decoration: BoxDecoration(
        color: grund,
        border: rand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: inhalt,
    );

    if (art == _ChipArt.platzhalter) return ExcludeSemantics(child: chip);

    return Semantics(
      button: true,
      selected: art == _ChipArt.an,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aufTippen,
        onLongPress: aufLangdruck,
        child: chip,
      ),
    );
  }
}
