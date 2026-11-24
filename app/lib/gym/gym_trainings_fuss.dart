// Die Fußleiste der Trainings-Schirme (#533 unter #531; Spec 7.1 Nr. 7, 8.2
// Nr. 7) — `obFoot` in `docs/screens/components.js`: ein Hauptknopf, darunter
// höchstens eine Ausweichzeile. Dieselbe Leiste trägt „Eigenes Training
// anlegen" in der Übersicht und „Training starten" samt „Bearbeiten" im Detail.
//
// **Ein Knopf ohne Ziel steht abgeblendet da und tut nichts** (Plan 2.5,
// Lücke 7) — **ohne Text, der etwas verspricht**: Wer „Eigenes Training
// anlegen" abgeblendet sieht, soll nicht lesen, wann es kommt. Ob ein Knopf
// wirkt, entscheidet allein sein `onPressed`; abgeblendet wird mit demselben
// Wert, damit beides nie auseinanderläuft.
//
// **Kein Glas:** Die Leiste steht neben scrollendem Inhalt (`CLAUDE.md`).
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import '../design/typografie.dart';

/// Die Fußleiste: Hauptknopf [label] und optional die Ausweichzeile [alt].
///
/// [onPressed] `null` blendet den Hauptknopf ab, [altOnPressed] `null` die
/// Ausweichzeile. Die Leiste behält in beiden Fällen ihre Form.
class GymTrainingsFuss extends StatelessWidget {
  const GymTrainingsFuss({
    super.key,
    required this.label,
    required this.schluessel,
    required this.onPressed,
    this.alt,
    this.altSchluessel,
    this.altOnPressed,
  });

  final String label;
  final Key schluessel;
  final VoidCallback? onPressed;

  /// Die Ausweichzeile unter dem Knopf („Bearbeiten"); `null`: keine.
  final String? alt;
  final Key? altSchluessel;
  final VoidCallback? altOnPressed;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final alt = this.alt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(Palette.bg, context),
        border: Border(top: BorderSide(color: linie, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: onPressed == null ? 0.45 : 1,
              child: CupertinoButton(
                key: schluessel,
                color: iron,
                disabledColor: iron,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(vertical: 13),
                onPressed: onPressed,
                child: Text(
                  label,
                  style: Typografie.numeric(TypografieGroesse.headline)
                      .copyWith(fontSize: 17, color: surface),
                ),
              ),
            ),
            if (alt != null)
              Opacity(
                opacity: altOnPressed == null ? 0.45 : 1,
                child: CupertinoButton(
                  key: altSchluessel,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 34),
                  onPressed: altOnPressed,
                  child: Text(
                    alt,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: river,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
