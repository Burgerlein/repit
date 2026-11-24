// Das Löschen per Wischen (#486 unter #88) — die Rückfrage und die
// wischbare Zeile, gemeinsam für beide Umfänge-Schirme: Die Übersicht
// löscht den ganzen Messtag, der Maß-Verlauf ein einzelnes Maß. Es ist
// dieselbe Rückfrage, nur Titel und Text nennen etwas anderes.
//
// Verhalten verbindlich vorgegeben durch
// `app/test/shell/umfaenge_loeschen_wisch_test.dart` (siehe dessen
// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern.
//
// Entwurf: `docs/screens/screens/umfaenge.js` und `umfang-detail.js`,
// Baustein `alert` in `docs/screens/components.js` (Commit `ac84126`).
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../design/palette.dart';

/// Die Rückfrage vor etwas Unumkehrbarem — `showCupertinoDialog` mit
/// `CupertinoAlertDialog` (Baustein `alert` im Entwurf).
///
/// **Die Rückfrage nennt, was verschwindet** — ein „Wirklich löschen?" ohne
/// Gegenstand ließe sich nur wegklicken, nicht beantworten. Deshalb kommen
/// [titel] und [text] vom Aufrufer, der den Gegenstand kennt.
///
/// Rot ist nur „Löschen"; „Abbrechen" ist der fette, sichere Platz
/// (`isDefaultAction`). Kein Tippen neben den Dialog schließt ihn — es gibt
/// keinen Papierkorb und kein Rückgängig, die Antwort ist ausdrücklich.
Future<bool> umfangLoeschenFrage(
  BuildContext context, {
  required String titel,
  required String text,
}) async {
  final geloescht = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialog) => CupertinoAlertDialog(
      key: const Key('umfang-loeschen-frage'),
      title: Text(titel),
      content: Text(text),
      actions: [
        CupertinoDialogAction(
          key: const Key('umfang-loeschen-abbrechen'),
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Abbrechen'),
        ),
        CupertinoDialogAction(
          key: const Key('umfang-loeschen-bestaetigen'),
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Löschen'),
        ),
      ],
    ),
  );
  return geloescht ?? false;
}

/// Eine Zeile, die sich nach links wischen lässt: „Löschen" kommt hervor,
/// dann entscheidet die Rückfrage — **die Geste allein löscht nichts.**
///
/// Dieselbe Form wie bei den Gläsern in „Wasser" (`wasser_blatt.dart`),
/// nur **mit** Rückfrage: Es sind Tims eigene Daten, und es gibt keinen
/// Papierkorb.
///
/// **Der Vorlesetext nennt den Zustand, nicht das Zeichen** (`CLAUDE.md`):
/// Für Screenreader liegt das Löschen als benannte Aktion auf der Zeile
/// ([aktion], etwa „Messung vom 05.01.2099 löschen") — eine Wischgeste ist
/// mit VoiceOver nicht auffindbar. Das rote Feld hinter der Zeile ist davon
/// ausgenommen, es ist nur das Bild der Geste.
class WischLoeschen extends StatelessWidget {
  const WischLoeschen({
    super.key,
    required this.aktion,
    required this.frage,
    required this.aufBestaetigt,
    required this.child,
  });

  /// Der Name der Löschaktion fürs Vorlesen — nennt, was verschwindet.
  final String aktion;

  /// Stellt die Rückfrage; `true` heißt „wirklich löschen".
  final Future<bool> Function(BuildContext context) frage;

  /// Läuft erst **nach** bestätigter Rückfrage. Der Aufrufer nimmt die
  /// Zeile sofort aus seiner Liste und löscht dann in der Ablage; scheitert
  /// das, stellt er sie wieder hin.
  final VoidCallback aufBestaetigt;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: aktion): () async {
          // Der Dialog steht offen, während der Schirm darunter
          // verschwinden kann — nach dem `await` erst prüfen, ob die Zeile
          // noch steht, bevor ihr Besitzer `setState` gesagt bekommt.
          if (await frage(context) && context.mounted) aufBestaetigt();
        },
      },
      child: Dismissible(
        key: ValueKey('wisch-loeschen-$aktion'),
        direction: DismissDirection.endToStart,
        background: const SizedBox.shrink(),
        secondaryBackground: const _Loeschfeld(),
        // **Immer `false`:** Die Zeile verschwindet, weil der Aufrufer sie
        // bei bestätigter Rückfrage sofort aus seiner Liste nimmt — nicht,
        // weil das `Dismissible` sich für erledigt hält. Ein bestätigt
        // weggewischtes `Dismissible`, das nach einem **gescheiterten**
        // Löschen zurückkommt, bliebe sonst im Zustand „weggewischt"
        // hängen und stünde als unsichtbare Zeile da.
        confirmDismiss: (_) async {
          final ok = await frage(context);
          if (ok && context.mounted) aufBestaetigt();
          return false;
        },
        child: child,
      ),
    );
  }
}

/// Was hinter einer nach links gezogenen Zeile erscheint — dieselbe Form
/// wie in „Wasser" und „Mahlzeit".
///
/// Ohne eigene Semantik: Das Wort „Löschen" ist hier das Bild der Geste;
/// vorgelesen wird die benannte Aktion auf der Zeile.
class _Loeschfeld extends StatelessWidget {
  const _Loeschfeld();

  @override
  Widget build(BuildContext context) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    return ExcludeSemantics(
      child: ColoredBox(
        color: warn,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Löschen',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
