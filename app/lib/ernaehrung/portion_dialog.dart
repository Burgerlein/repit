// Der Dialog **„Portion anlegen" / „Portion ändern"** (#400, unter #325)
// — `docs/screens/screens/erfassen.js`, Zustände `portion-anlegen` und
// `portion-aendern`.
//
// API und Verhalten sind durch `app/test/ernaehrung/portion_dialog_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Ein Dialog, kein drittes Blatt** (Entwurf): zwei Felder über dem
// Buchungs- oder Anlegen-Blatt, wie iOS „Neuer Ordner" zeigt. Der Dialog
// schreibt nichts — er meldet, was gewählt wurde, und wer ihn öffnet,
// entscheidet, ob das in die Tabelle geht oder im Formular bleibt (V3).
import 'package:flutter/cupertino.dart';

import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';
import '../design/palette.dart';
import 'erfassen_formular.dart' show liesZahl;

/// Was der Dialog meldet. `null` heißt „Abbrechen".
sealed class PortionDialogErgebnis {
  const PortionDialogErgebnis();
}

/// „Sichern": der Name ohne Ränder und die Menge in g bzw. ml.
final class PortionGesichert extends PortionDialogErgebnis {
  const PortionGesichert(this.name, this.mengeG);

  final String name;
  final double mengeG;

  @override
  bool operator ==(Object other) =>
      other is PortionGesichert && other.name == name && other.mengeG == mengeG;

  @override
  int get hashCode => Object.hash(name, mengeG);

  @override
  String toString() => 'PortionGesichert($name, $mengeG)';
}

/// „Portion löschen" — **ohne weitere Rückfrage**, denn der Knopf ist die
/// Rückfrage (V10).
final class PortionGeloescht extends PortionDialogErgebnis {
  const PortionGeloescht();

  @override
  bool operator ==(Object other) => other is PortionGeloescht;

  @override
  int get hashCode => (PortionGeloescht).hashCode;

  @override
  String toString() => 'PortionGeloescht()';
}

/// Zeigt „Portion anlegen" (ohne [portion]) oder „Portion ändern" (mit).
///
/// [lebensmittelName] steht im Text des Anlegens, [fluessig] entscheidet
/// über „g" oder „ml" hinter dem Mengenfeld.
Future<PortionDialogErgebnis?> zeigePortionDialog(
  BuildContext context, {
  required String lebensmittelName,
  Portion? portion,
  required bool fluessig,
}) => showCupertinoDialog<PortionDialogErgebnis>(
  context: context,
  builder: (_) => _PortionDialog(
    lebensmittelName: lebensmittelName,
    portion: portion,
    fluessig: fluessig,
  ),
);

class _PortionDialog extends StatefulWidget {
  const _PortionDialog({
    required this.lebensmittelName,
    required this.portion,
    required this.fluessig,
  });

  final String lebensmittelName;
  final Portion? portion;
  final bool fluessig;

  @override
  State<_PortionDialog> createState() => _PortionDialogZustand();
}

class _PortionDialogZustand extends State<_PortionDialog> {
  late final _name = TextEditingController(text: widget.portion?.name ?? '');
  late final _mengeAnfang = widget.portion == null
      ? ''
      : _alsText(widget.portion!.mengeG);
  late final _menge = TextEditingController(text: _mengeAnfang);

  @override
  void dispose() {
    _name.dispose();
    _menge.dispose();
    super.dispose();
  }

  bool get _aendert => widget.portion != null;

  /// Pflicht sind ein Name, der ohne Ränder nicht leer ist, und eine
  /// Menge größer 0 (V10). Doppelte Namen werden nicht geprüft.
  PortionGesichert? get _ergebnis {
    final name = _name.text.trim();
    // Unverändert bleibt die Menge, wie sie war — auch wenn Open Food
    // Facts mehr Stellen liefert, als das Feld zeigt. Ein Umbenennen
    // ändert sonst still die Gramm.
    final vorher = widget.portion;
    final menge = vorher != null && _menge.text == _mengeAnfang
        ? vorher.mengeG
        : liesZahl(_menge.text).wert;
    if (name.isEmpty || menge == null || menge <= 0) return null;
    return PortionGesichert(name, menge);
  }

  String get _text {
    // **Eine Zusage, keine Beschreibung** (Spec, „Texte, die Zusagen
    // sind"): Sie stimmt, weil der Eintrag einen Schnappschuss trägt und
    // keinen Verweis liest.
    const zusage =
        'Gebuchte Einträge behalten ihre Gramm — die Änderung gilt ab dem '
        'nächsten Buchen.';
    final portion = widget.portion;
    if (portion == null) {
      return 'Für ${widget.lebensmittelName}. Die Gramm stehen oft auf der '
          'Packung unter „Portion" — sonst einmal wiegen.';
    }
    return portion.herkunft == Herkunft.off
        ? 'Aus Open Food Facts. $zusage'
        : 'Für ${widget.lebensmittelName}. $zusage';
  }

  @override
  Widget build(BuildContext context) {
    final ergebnis = _ergebnis;
    final sichern = CupertinoDialogAction(
      key: const Key('portion-dialog-sichern'),
      isDefaultAction: true,
      onPressed: ergebnis == null
          ? null
          : () => Navigator.of(context).pop(ergebnis),
      child: const Text('Sichern'),
    );
    final abbrechen = CupertinoDialogAction(
      key: const Key('portion-dialog-abbrechen'),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Abbrechen'),
    );

    return CupertinoAlertDialog(
      title: Text(_aendert ? 'Portion ändern' : 'Portion anlegen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_text),
          const SizedBox(height: 8),
          _Feld(
            key: const Key('portion-dialog-name'),
            controller: _name,
            platzhalter: 'Name, z. B. Stück',
            autofocus: !_aendert,
            aufEingabe: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _Feld(
            key: const Key('portion-dialog-menge'),
            controller: _menge,
            platzhalter: widget.fluessig
                ? 'Milliliter je Portion'
                : 'Gramm je Portion',
            einheit: widget.fluessig ? 'ml' : 'g',
            aufEingabe: (_) => setState(() {}),
          ),
        ],
      ),
      // Beim Ändern drei Knöpfe — `CupertinoAlertDialog` stapelt sie
      // selbst, wie im Entwurf.
      actions: _aendert
          ? [
              sichern,
              CupertinoDialogAction(
                key: const Key('portion-dialog-loeschen'),
                isDestructiveAction: true,
                onPressed: () =>
                    Navigator.of(context).pop(const PortionGeloescht()),
                child: const Text('Portion löschen'),
              ),
              abbrechen,
            ]
          : [abbrechen, sichern],
    );
  }
}

/// Ein Eingabefeld des Dialogs — umrandet, wie iOS es in Alerts zeigt.
class _Feld extends StatelessWidget {
  const _Feld({
    super.key,
    required this.controller,
    required this.platzhalter,
    required this.aufEingabe,
    this.einheit,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String platzhalter;
  final ValueChanged<String> aufEingabe;
  final String? einheit;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);

    return CupertinoTextField(
      controller: controller,
      placeholder: platzhalter,
      autofocus: autofocus,
      keyboardType: einheit == null
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      textCapitalization: einheit == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      onChanged: aufEingabe,
      suffix: einheit == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(einheit!, style: TextStyle(color: muted)),
            ),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: line, width: 0.5),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

/// Eine Menge als Feldtext: „5,9", „60" — Komma, höchstens zwei Stellen,
/// ohne nachgehängte Null.
String _alsText(double wert) {
  var t = wert.toStringAsFixed(2);
  while (t.endsWith('0')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t.replaceAll('.', ',');
}
