// Die Knopfreihe der Gym-Fokus-Karte (#77) — `btn(label, kind, accent)`
// aus `docs/screens/components.js`, gesetzt wie `.focus-top .acts`.
//
// Eigene Datei, damit die Karte selbst lesbar bleibt: Was welcher Zustand
// anbietet, ist eine eigene Frage und steht hier an einer Stelle.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../shell/router.dart';
import 'gym_fokus_texte.dart';
import 'gym_ladeform.dart';
import 'gym_log_view.dart';
import 'gym_verlauf_view.dart';

/// Die Knopfreihe — zwei Knöpfe, zwei, zwei bzw. einer, einer.
///
/// **Die drei Knöpfe, die ein Training anfangen oder weiterführen, haben ihr
/// Ziel** („Weiter eintragen", „Training starten", „‹Gym B› vorziehen"):
/// das Erfassen (#78), auf den Stapel des Tabs, aus dem man kommt
/// (`AppTarget.aktuell`). **„Verlauf" führt seit #79 zu „Letzte Trainings"**,
/// auf demselben Weg. **Die übrigen sind abgeblendet und ohne Wirkung**,
/// denn ihr Ziel gibt es nicht: der Plan (#81). Ihre Beschriftung bleibt trotzdem stehen — ein unbeschrifteter Nicht-Knopf
/// wäre schlimmer als ein abgeblendeter, und die Geometrie ist dieselbe wie
/// später (Spec Abschnitt 11).
class GymAktionen extends StatelessWidget {
  const GymAktionen({
    super.key,
    required this.focus,
    required this.akzent,
    required this.laedt,
    required this.router,
  });

  final GymFocus focus;
  final Color akzent;
  final bool laedt;

  /// Die Tür zum Erfassen.
  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);

    void erfassen(TrainingKey schluessel) => oeffneGymLog(router, schluessel);

    final knoepfe = switch (focus) {
      InProgress(:final workout, :final trainingId) => [
        (
          beschriftung: 'Weiter eintragen',
          gefuellt: true,
          ton: akzent,
          // Ein eigenes Training hat keinen Enum-Fall, nur seine Kennung.
          ziel: () => erfassen(workout ?? CustomTrainingKey(trainingId!)),
        ),
        (
          beschriftung: 'Verlauf',
          gefuellt: false,
          ton: muted,
          ziel: () => oeffneGymVerlauf(router),
        ),
      ],
      Planned(:final workout) => [
        (
          beschriftung: 'Training starten',
          gefuellt: true,
          ton: akzent,
          ziel: () => erfassen(workout),
        ),
        (
          beschriftung: 'Verlauf',
          gefuellt: false,
          ton: muted,
          ziel: () => oeffneGymVerlauf(router),
        ),
      ],
      Rest(:final next) => [
        if (next != null)
          (
            beschriftung: gymVorziehenKnopf(next),
            gefuellt: false,
            ton: iron,
            ziel: () => erfassen(next),
          ),
        (beschriftung: 'Plan ansehen', gefuellt: false, ton: muted, ziel: null),
      ],
      Recovery() => [
        (beschriftung: 'Plan ansehen', gefuellt: false, ton: muted, ziel: null),
      ],
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < knoepfe.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          // `Flexible`, nicht fest: Zwei Knöpfe nebeneinander sind im
          // Entwurf ein Flexkasten und dürfen schmaler werden, wenn die
          // Beschriftung lang ist (`.focus-top .acts`). Ohne das liefe die
          // Reihe bei „‹Gym B› vorziehen · Plan ansehen" aus der Karte
          // heraus.
          Flexible(
            child: _Knopf(
              beschriftung: knoepfe[i].beschriftung,
              gefuellt: knoepfe[i].gefuellt,
              ton: knoepfe[i].ton,
              laedt: laedt,
              onTap: knoepfe[i].ziel,
            ),
          ),
        ],
      ],
    );
  }
}

/// Ein Knopf der Fokus-Karte — `fill` oder `tint` aus `btn(label, kind,
/// accent)` (`docs/screens/components.css`, `.btn`).
class _Knopf extends StatelessWidget {
  const _Knopf({
    required this.beschriftung,
    required this.gefuellt,
    required this.ton,
    required this.laedt,
    required this.onTap,
  });

  final String beschriftung;
  final bool gefuellt;
  final Color ton;
  final bool laedt;

  /// `null`: Das Ziel gibt es nicht — der Knopf steht abgeblendet da.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final stil = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: gefuellt ? surface : ton,
    );

    // Solange gelesen wird, steht noch nicht fest, was der Knopf sagt — und
    // wohin er führte. Dann ist auch ein Knopf mit Ziel abgeblendet.
    final wirksam = onTap != null && !laedt;
    return Opacity(
      opacity: wirksam ? 1 : 0.45,
      child: CupertinoButton(
        // **`null`, nicht „tut nichts"**: Ein Knopf mit leerem Rückruf sähe
        // tippbar aus und schwiege.
        onPressed: wirksam ? onTap : null,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gefuellt ? ton : ton.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: GymTextOderForm(
              text: beschriftung,
              stil: stil,
              laedt: laedt,
              einzeilig: true,
            ),
          ),
        ),
      ),
    );
  }
}
