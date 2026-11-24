// Die Übungszeile des Editors (#534, Task 3.6; Spec 9.1, 9.4, 9.7): Griff (≡),
// Position als Ziffer, Name, „4 × 6–10", Winkel — **jede Zeile gleich hoch**,
// mindestens 44 pt, mit und ohne alles (Entwurf `ED` in
// `docs/screens/screens/gym-training-editor.js`).
//
// **Ziehen am Griff** ändert die Reihenfolge (`ReorderableDragStartListener`
// der Liste, die der Editor stellt); **VoiceOver** nennt „Übung 2 von 5, …"
// und bietet am Griff „Nach oben" und „Nach unten" — damit es auch ohne
// Treffsicherheit geht.
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/typografie.dart';
import 'gym_editor_texte.dart';
import 'gym_training_editor_schluessel.dart';

/// Die feste Höhe jeder Zeile.
const double kGymEditorZeilenHoehe = 52;

class GymEditorUebungZeile extends StatelessWidget {
  const GymEditorUebungZeile({
    super.key,
    required this.uebung,
    required this.index,
    required this.von,
    required this.onTap,
    required this.onHoch,
    required this.onRunter,
  });

  final WorkoutExercise uebung;

  /// Der Index ab 0; die Ziffer in der Zeile ist `index + 1`.
  final int index;
  final int von;
  final VoidCallback onTap;

  /// `null`, wo es nicht weiter nach oben geht.
  final VoidCallback? onHoch;

  /// `null`, wo es nicht weiter nach unten geht.
  final VoidCallback? onRunter;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final katalog = ExerciseLibrary.byId(uebung.exerciseId);
    final zeit = katalog?.isTimed ?? false;
    final name = katalog?.name ?? uebung.exerciseId;

    return Semantics(
      key: kGymEditorUebung(uebung.exerciseId),
      container: true,
      button: true,
      label: gymEditorUebungVorlesen(
        position: index + 1,
        von: von,
        name: name,
        e: uebung,
        zeit: zeit,
      ),
      onTap: onTap,
      child: SizedBox(
        height: kGymEditorZeilenHoehe,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                key: kGymEditorGriff(uebung.exerciseId),
                container: true,
                label: gymEditorGriffVorlesen,
                customSemanticsActions: {
                  CustomSemanticsAction(label: gymEditorNachOben): ?onHoch,
                  CustomSemanticsAction(label: gymEditorNachUnten): ?onRunter,
                },
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 44,
                    height: kGymEditorZeilenHoehe,
                    child: Center(
                      child: Text(
                        '≡',
                        style: TextStyle(fontSize: 20, color: muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: kGymEditorZeilenHoehe,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${index + 1}',
                            key: kGymEditorPos(uebung.exerciseId),
                            style: Typografie.tabularNumbers(
                              TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          gymEditorDosis(uebung, zeit: zeit),
                          key: kGymEditorDosis(uebung.exerciseId),
                          style: Typografie.tabularNumbers(
                            TextStyle(fontSize: 13, color: muted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('›', style: TextStyle(fontSize: 18, color: muted)),
                        const SizedBox(width: 13),
                      ],
                    ),
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
