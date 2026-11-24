// Der eine Baustein, der auf dem Gym-Schirm (#77) zwischen „steht da" und
// „wird gelesen" umschaltet.
//
// Eigene Datei, weil ihn Fokus-Karte und Knopfreihe gleichermaßen
// brauchen — und weil die Zusage, die er trägt, an einer Stelle stehen
// soll: **Die graue Form ist so hoch und so breit wie der Text, den sie
// ablöst.** Wird sie geraten, springt die Karte in dem Moment, in dem die
// Daten eintreffen (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau
// eine Form").
import 'package:flutter/cupertino.dart';

import '../design/platzhalter.dart';

/// Entweder der Satz oder die graue Form, die ihn ablöst — **in derselben
/// Schrift und damit in derselben Höhe.**
///
/// Der Beispieltext wird nie gezeichnet, nur gemessen (siehe [Platzhalter]).
/// Ohne [formBeispiel] misst die Form den Text selbst; das hält die
/// Geometrie zwischen „lädt" und „fertig" exakt gleich, statt sie auf eine
/// getippte Breite zu raten.
class GymTextOderForm extends StatelessWidget {
  const GymTextOderForm({
    super.key,
    required this.text,
    required this.stil,
    required this.laedt,
    this.formBeispiel,
    this.einzeilig = false,
  });

  final String text;
  final TextStyle stil;
  final bool laedt;
  final String? formBeispiel;

  /// Eine Knopfbeschriftung bricht nicht um — sie kürzt. Mehrzeilige
  /// Knöpfe änderten die Höhe der Karte, je nachdem wie lang ein
  /// Workout-Name ist.
  final bool einzeilig;

  @override
  Widget build(BuildContext context) {
    if (!laedt) {
      return Text(
        text,
        style: stil,
        maxLines: einzeilig ? 1 : null,
        overflow: einzeilig ? TextOverflow.ellipsis : null,
      );
    }
    return Platzhalter(beispiel: formBeispiel ?? text, stil: stil);
  }
}
