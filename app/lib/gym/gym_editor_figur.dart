// Die Muskelfigur des Editors (#554 unter #531; Spec 28 Nr. 3): beide Seiten
// nebeneinander, einfarbig in `Palette.iron` — „trifft diese Muskeln", nicht
// „wie viel" (Spec 8.1) —, gefärbt mit den Muskeln der **aktuellen**
// Übungsliste des Editor-Stands.
//
// **Eine Form in jedem Zustand** (`CLAUDE.md`, „Eine Anzeige, die es gibt,
// hat genau eine Form"): Der Rahmen hat eine feste Höhe, und die Figur steht
// beim Laden, leer und gefüllt in denselben Maßen da. Nur die Füllung
// unterscheidet sich; nichts darin hängt am Namensfeld oder an der Zahl der
// Übungen. Ein leerer Stand färbt nichts und sagt es auch so.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/muskel_figur.dart';
import '../design/palette.dart';
import 'gym_editor_provider.dart';
import 'gym_training_editor_schluessel.dart';
import 'gym_trainings_texte.dart' show gymTrainingDetailFigurVorlesetext;

/// Die feste Höhe des Rahmens — jede Hälfte der Figur samt Beschriftung
/// („VORNE", „HINTEN") passt hinein.
const double kGymEditorFigurHoehe = 168;

class GymEditorFigur extends ConsumerWidget {
  const GymEditorFigur({super.key, required this.quelle});

  final GymEditorQuelle quelle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muskeln = ref.watch(gymEditorMuskelnProvider(quelle));
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);

    return SizedBox(
      key: kGymEditorFigur,
      height: kGymEditorFigurHoehe,
      child: MuskelFigur(
        gefaerbt: {for (final m in muskeln) m: iron},
        semantik: gymTrainingDetailFigurVorlesetext(muskeln),
      ),
    );
  }
}
