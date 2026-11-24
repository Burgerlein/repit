// Das Blatt „Lebensmittel anlegen" (#285) — `docs/screens/screens/
// erfassen.js`, Zustand `anlegen`.
//
// API und Verhalten sind durch `app/test/ernaehrung/erfassen_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Der vollständige Weg ohne fremde Datenbank** (Tim, 04.11.2026). Bis
// Barcode und Open Food Facts stehen, ist das der einzige Weg zu einem
// Lebensmittel — und er ist kein Notbehelf: Was hier entsteht, liegt in
// derselben Tabelle wie ein gescannter Treffer, taucht in der Suche auf
// und lässt sich beliebig oft buchen.
//
// **Das Blatt schließt sich nicht selbst**, es meldet `onFertig`. Wer ein
// Blatt öffnet, schließt es; ein Blatt, das selbst `Navigator.pop` ruft,
// hinge an der Art, wie es gezeigt wird.
//
// **Die Rechnung liegt nicht hier**, sondern in `AnlegenFormular`
// (`erfassen_formular.dart`). Diese Datei zeigt Felder an und reicht
// Tastendrücke weiter.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/portion.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_formular.dart';
import 'erfassen_provider.dart';
import 'portion_dialog.dart';
import 'portions_text.dart';

/// Das Blatt „Lebensmittel anlegen".
///
/// Bringt **keinen** eigenen `CupertinoPageScaffold` mit — den stellt,
/// wer es zeigt.
class AnlegenBlatt extends ConsumerStatefulWidget {
  const AnlegenBlatt({super.key, this.onFertig, this.name, this.barcode});

  /// Gerufen nach dem Sichern, mit dem Schlüssel des neuen Lebensmittels.
  final void Function(int id)? onFertig;

  /// Ein vorbelegter Name — aus einem Treffer von Open Food Facts, der
  /// keine Kalorien trägt (#324). Er steht im Feld und lässt sich ändern.
  final String? name;

  /// Ein vorbelegter Strichcode aus dem Scanner (#324). Er wird nicht
  /// angezeigt und nicht getippt, sondern mitgesichert — sonst erkennte
  /// der nächste Scan dieselbe Packung nicht wieder.
  final String? barcode;

  @override
  ConsumerState<AnlegenBlatt> createState() => _AnlegenBlattZustand();
}

class _AnlegenBlattZustand extends ConsumerState<AnlegenBlatt> {
  late AnlegenFormular _formular = AnlegenFormular(
    name: widget.name ?? '',
    barcode: widget.barcode,
  );

  /// Nur für einen vorbelegten Namen: Der Anfangstext kommt von außen,
  /// und dafür braucht das Feld einen Controller (`ErfassenFeldZeile`).
  late final TextEditingController? _nameController = widget.name == null
      ? null
      : TextEditingController(text: widget.name);

  @override
  void dispose() {
    _nameController?.dispose();
    super.dispose();
  }

  /// Solange geschrieben wird, ist der Knopf gesperrt — sonst legt ein
  /// zweiter Druck dasselbe Lebensmittel ein zweites Mal an.
  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    // **Unten durchzeichnen statt abschneiden** (`CLAUDE.md`,
    // flutter#179482): Die halbtransparente Tastatur schiebt sich über das
    // Blatt, und wo Flutter nicht zeichnet, steht Schwarz.
    final tastatur = MediaQuery.of(context).viewInsets.bottom;

    return ColoredBox(
      color: bg,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          children: [
            ErfassenKopf(
              titel: 'Lebensmittel anlegen',
              sichernText: 'Sichern',
              sichernSchluessel: const Key('anlegen-sichern'),
              aufAbbrechen: _laeuft
                  ? null
                  : () => Navigator.maybePop(context),
              aufSichern: _formular.kannSichern && !_laeuft ? _sichere : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + tastatur),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _inhalt(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inhalt() => [
    const ErfassenKapitel('Was es ist'),
    InsetCard(
      child: Column(
        children: [
          ErfassenFeldZeile(
            key: const Key('anlegen-name'),
            titel: 'Name',
            platzhalter: 'Haferflocken kernig',
            controller: _nameController,
            nurZiffern: false,
            aufEingabe: (text) => _setze(_formular.mit(name: text)),
          ),
          const ErfassenTrenner(),
          // **Die Einheit entscheidet über g oder ml — sonst nichts.** Ein
          // Getränk wiegt man nicht, man schenkt es ein.
          ErfassenWertZeile(
            key: const Key('anlegen-bezug'),
            titel: 'Bezug',
            wert: _formular.fluessig ? 'je 100 ml' : 'je 100 g',
            aufTippen: () =>
                _setze(_formular.mit(fluessig: !_formular.fluessig)),
          ),
        ],
      ),
    ),

    const ErfassenKapitel('Nährwerte je 100 g'),
    InsetCard(
      child: Column(
        children: [
          ErfassenFeldZeile(
            key: const Key('anlegen-kcal'),
            titel: 'Kalorien',
            einheit: 'kcal',
            platzhalter: 'Pflicht',
            aufEingabe: (text) => _setze(_formular.mit(kcal: text)),
          ),
          const ErfassenTrenner(),
          ErfassenFeldZeile(
            key: const Key('anlegen-eiweiss'),
            titel: 'Eiweiß',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(eiweissG: text)),
          ),
          const ErfassenTrenner(),
          ErfassenFeldZeile(
            key: const Key('anlegen-kohlenhydrate'),
            titel: 'Kohlenhydrate',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(kohlenhydrateG: text)),
          ),
          const ErfassenTrenner(),
          ErfassenFeldZeile(
            key: const Key('anlegen-fett'),
            titel: 'Fett',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(fettG: text)),
          ),
        ],
      ),
    ),

    const ErfassenKapitel('Freiwillig'),
    InsetCard(
      child: Column(
        children: [
          ErfassenFeldZeile(
            key: const Key('anlegen-zucker'),
            titel: 'davon Zucker',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(zuckerG: text)),
          ),
          const ErfassenTrenner(),
          ErfassenFeldZeile(
            key: const Key('anlegen-gesaettigt'),
            titel: 'davon gesättigt',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(gesaettigtG: text)),
          ),
          const ErfassenTrenner(),
          ErfassenFeldZeile(
            key: const Key('anlegen-ballaststoffe'),
            titel: 'Ballaststoffe',
            einheit: 'g',
            aufEingabe: (text) => _setze(_formular.mit(ballaststoffeG: text)),
          ),
        ],
      ),
    ),

    // **Portionen gleich beim Anlegen** (#400, `anlegen-portionen`) —
    // freiwillig, und dieselben, die das Buchungsblatt als Knöpfe zeigt.
    // Ohne Portion steht nur „Portion hinzufügen" da; der Abschnitt fällt
    // nicht weg.
    const ErfassenKapitel('Portionen · freiwillig'),
    InsetCard(
      child: Column(
        children: [
          for (final (i, p) in _formular.portionen.indexed) ...[
            ErfassenWertZeile(
              key: Key('anlegen-portion-$i'),
              titel: p.name,
              wert: portionsMenge(p.mengeG, fluessig: _formular.fluessig),
              aufTippen: _laeuft ? null : () => _aenderePortion(p),
            ),
            const ErfassenTrenner(),
          ],
          _AktionsZeile(
            key: const Key('anlegen-portion-neu'),
            text: 'Portion hinzufügen',
            aufTippen: _laeuft ? null : _legePortionAn,
          ),
        ],
      ),
    ),

    // **Feste Zeilenzahl, kein wachsender Text** (`CLAUDE.md`): Der
    // Hinweis sagt immer dasselbe, auch wenn der Knopf gesperrt ist —
    // sonst spränge das Blatt beim Tippen.
    const ErfassenHinweis(
      'Pflicht sind Name und Kalorien. Leere Felder bleiben leer — sie '
      'werden nicht als null gezählt. Ein unlesbarer Wert sperrt „Sichern", '
      'damit keine Eingabe stillschweigend verlorengeht. Portionen sind '
      'Abkürzungen: Gebucht wird immer in Gramm. Was du anlegst, liegt auf '
      'diesem Gerät und steht ab sofort in deiner Suche.',
    ),
  ];

  /// „Portion hinzufügen" — der Dialog `portion-anlegen`. Die Portion
  /// bleibt im Formular, bis gesichert wird; dann gehen Lebensmittel und
  /// Portionen in **einer** Transaktion in die Tabelle (`legeAn`).
  Future<void> _legePortionAn() async {
    final ergebnis = await zeigePortionDialog(
      context,
      lebensmittelName: _name,
      fluessig: _formular.fluessig,
    );
    if (ergebnis is! PortionGesichert || !mounted) return;
    _setze(
      _formular.mitNeuerPortion(
        Portion(name: ergebnis.name, mengeG: ergebnis.mengeG),
      ),
    );
  }

  /// Eine Zeile angetippt — der Dialog `portion-aendern`.
  Future<void> _aenderePortion(Portion p) async {
    final ergebnis = await zeigePortionDialog(
      context,
      lebensmittelName: _name,
      portion: p,
      fluessig: _formular.fluessig,
    );
    if (ergebnis == null || !mounted) return;
    _setze(switch (ergebnis) {
      PortionGesichert(:final name, :final mengeG) =>
        _formular.mitGeaenderterPortion(p, p.mit(name: name, mengeG: mengeG)),
      PortionGeloescht() => _formular.ohnePortion(p),
    });
  }

  /// Der Name im Dialogtext — solange noch keiner getippt ist, steht dort
  /// „dieses Lebensmittel".
  String get _name {
    final name = _formular.name.trim();
    return name.isEmpty ? 'dieses Lebensmittel' : name;
  }

  void _setze(AnlegenFormular formular) => setState(() => _formular = formular);

  Future<void> _sichere() async {
    final vorlage = _formular.alsVorlage();
    if (vorlage == null) return;

    setState(() => _laeuft = true);
    final int id;
    try {
      id = await ref
          .read(erfassenProvider.notifier)
          .legeLebensmittelAn(vorlage, portionen: _formular.portionen);
    } catch (_) {
      // Ein gescheitertes Sichern meldet **kein** „fertig": Sonst
      // schlösse der Aufrufer das Blatt, und die Eingabe wäre weg, ohne
      // dass irgendwo etwas stünde.
      if (mounted) setState(() => _laeuft = false);
      return;
    }
    if (!mounted) return;
    setState(() => _laeuft = false);
    widget.onFertig?.call(id);
  }
}

/// Eine Zeile, die etwas tut, statt einen Wert zu zeigen
/// (`formRow(…, 'action')`) — „Portion hinzufügen".
class _AktionsZeile extends StatelessWidget {
  const _AktionsZeile({super.key, required this.text, this.aufTippen});

  final String text;
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aufTippen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: TextStyle(color: river)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
