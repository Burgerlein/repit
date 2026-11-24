// Die Filterzeile der Trainings-Übersicht (#533 unter #531, Task 2.3; Spec
// 7.1 Nr. 3, 7.6, 7.8) — `.tagfilter` in `docs/screens/components.css`.
//
// **Eine Zeile Kapseln, „Alle" zuerst**, danach die benutzten Tags (`allTags`).
// Genau eine Kapsel ist an. **Dieselbe Kapsel noch einmal wählt nichts ab:**
// „Alle" ist die Abwahl. Waagerecht scrollbar.
//
// **Beim ersten Lesen steht „Alle" als einzige, graue Kapsel da** (Spec 7.4):
// Welche Tags es gibt, weiß noch niemand. Sie lässt sich nicht antippen — ein
// Filter vor dem Lesen wäre eine Auswahl ohne Wahl.
//
// **Der Vorlesetext der Kapsel** sagt den Zustand: „Gym, ausgewählt" bzw.
// „Gym" (Spec 7.8) — keine Farbe, die nur das Auge sieht.
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import 'gym_trainings_schluessel.dart';
import 'gym_trainings_texte.dart';

/// Die Filterzeile. [tags] sind die benutzten Tags; [gewaehlt] ist der
/// gewählte (`null` = „Alle"); [laedt]: noch nichts gelesen.
class GymTrainingsFilter extends StatelessWidget {
  const GymTrainingsFilter({
    super.key,
    required this.tags,
    required this.gewaehlt,
    required this.laedt,
    required this.onWaehle,
  });

  final List<String> tags;
  final String? gewaehlt;
  final bool laedt;

  /// Wählt einen Tag; `null` führt auf „Alle" zurück.
  final ValueChanged<String?> onWaehle;

  @override
  Widget build(BuildContext context) {
    final gewaehltSchluessel = gewaehlt?.toLowerCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Kapsel(
            schluessel: kGymTrainingsChipAlle,
            text: gymTrainingsChipAlle,
            // Beim Lesen grau: nicht an, nicht antippbar.
            an: !laedt && gewaehlt == null,
            onTap: laedt ? null : () => onWaehle(null),
          ),
          if (!laedt)
            for (final tag in tags) ...[
              const SizedBox(width: 7),
              _Kapsel(
                schluessel: kGymTrainingsChip(tag),
                text: tag,
                an: tag.toLowerCase() == gewaehltSchluessel,
                onTap: () => onWaehle(tag),
              ),
            ],
        ],
      ),
    );
  }
}

class _Kapsel extends StatelessWidget {
  const _Kapsel({
    required this.schluessel,
    required this.text,
    required this.an,
    required this.onTap,
  });

  final Key schluessel;
  final String text;
  final bool an;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    return Semantics(
      key: schluessel,
      container: true,
      button: true,
      selected: an,
      label: gymTrainingsChipVorlesetext(text, ausgewaehlt: an),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: an ? iron : surface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 26,
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: an ? CupertinoColors.white : muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
