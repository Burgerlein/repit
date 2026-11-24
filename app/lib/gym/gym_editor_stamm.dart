// Der Stamm des Editors (#534, Task 3.6/3.7; Spec 9.1, 9.3): die Karte
// „Training" mit den Zeilen **Name**, **Tags** und **Dauer** — in jedem
// Zustand dieselbe Form (Entwurf `STAMM` in `docs/screens/screens/
// gym-training-editor.js`).
//
// - **Name:** ein Textfeld, roh gehalten, getrimmt gespeichert.
// - **Tags:** frei, mit Vorschlägen aus den benutzten Tags; ein Tag ist
//   antippbar, normalisiert (`WorkoutTags.add`) und entfernbar.
// - **Dauer:** „geschätzt 50 min", mit eigenen Minuten „eingetragen 55 min"
//   und „zurück zur Schätzung" daneben. **Ohne Übung steht „geschätzt – min"**:
//   die Zeile steht schon da, gleiche Form wie gefüllt, nie „0 min" (Fehler
//   `01`).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import 'gym_editor_blaetter.dart';
import 'gym_editor_provider.dart';
import 'gym_editor_texte.dart';
import 'gym_training_editor_schluessel.dart';
import 'gym_trainings_provider.dart';

class GymEditorStamm extends ConsumerStatefulWidget {
  const GymEditorStamm({super.key, required this.quelle});

  final GymEditorQuelle quelle;

  @override
  ConsumerState<GymEditorStamm> createState() => _StammZustand();
}

class _StammZustand extends ConsumerState<GymEditorStamm> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(gymEditorProvider(widget.quelle)).name,
  );
  final TextEditingController _tagFeld = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _tagFeld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quelle = widget.quelle;
    final stand = ref.watch(gymEditorProvider(quelle));
    final notifier = ref.read(gymEditorProvider(quelle).notifier);
    final benutzt = ref.watch(gymTrainingsProvider.select((s) => s.allTags));
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    // Der Name im Feld folgt dem Stand, wenn dieser von außen kommt (das
    // Lesen ist fertig): Getippt wird über `onChanged` in den Stand, beide
    // sind dann gleich und nichts wird überschrieben.
    ref.listen(gymEditorProvider(quelle).select((s) => s.name), (_, name) {
      if (_name.text != name) _name.text = name;
    });

    final gesetzt = {for (final t in stand.tags) t.toLowerCase()};
    final vorschlaege = [
      for (final t in benutzt)
        if (!gesetzt.contains(t.toLowerCase())) t,
    ];

    Widget zeile(String label, Widget inhalt, {bool oben = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          crossAxisAlignment: oben
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 70,
              child: Padding(
                padding: EdgeInsets.only(top: oben ? 15 : 0),
                child: Text(label, style: TextStyle(fontSize: 15, color: ink)),
              ),
            ),
            Expanded(child: inhalt),
          ],
        ),
      ),
    );

    final trenner = Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 13),
      color: line,
    );

    return InsetCard(
      child: Column(
        children: [
          zeile(
            gymEditorNameLabel,
            CupertinoTextField(
              key: kGymEditorName,
              controller: _name,
              enabled: !stand.laedt,
              placeholder: gymEditorNamePlatzhalter,
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 15, color: ink),
              onChanged: notifier.setzeName,
            ),
          ),
          trenner,
          zeile(
            gymEditorTagsLabel,
            Padding(
              key: kGymEditorTags,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in stand.tags)
                    _Kapsel(
                      key: kGymEditorTag(tag),
                      text: tag,
                      zusatz: '×',
                      gefuellt: true,
                      onTap: () => notifier.entferneTag(tag),
                      vorlesen: '$tag, entfernen',
                    ),
                  for (final tag in vorschlaege)
                    _Kapsel(
                      key: kGymEditorTagVorschlag(tag),
                      text: tag,
                      gefuellt: false,
                      onTap: stand.laedt
                          ? null
                          : () => notifier.fuegeTagHinzu(tag),
                      vorlesen: '$tag, hinzufügen',
                    ),
                  SizedBox(
                    width: 120,
                    child: CupertinoTextField(
                      key: kGymEditorTagFeld,
                      controller: _tagFeld,
                      enabled: !stand.laedt,
                      placeholder: gymEditorTagPlatzhalter,
                      decoration: null,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      style: TextStyle(fontSize: 14, color: ink),
                      onSubmitted: (roh) {
                        notifier.fuegeTagHinzu(roh);
                        _tagFeld.clear();
                      },
                    ),
                  ),
                ],
              ),
            ),
            oben: true,
          ),
          trenner,
          zeile(
            gymEditorDauerLabel,
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    excludeSemantics: true,
                    label: gymEditorDauerVorlesen(
                      eingetragen: stand.dauerEingetragen,
                      schaetzung: stand.schaetzung,
                    ),
                    onTap: stand.laedt
                        ? null
                        : () => zeigeGymEditorBlatt(
                            context,
                            GymEditorDauerBlatt(quelle: quelle),
                          ),
                    child: GestureDetector(
                      key: kGymEditorDauer,
                      behavior: HitTestBehavior.opaque,
                      onTap: stand.laedt
                          ? null
                          : () => zeigeGymEditorBlatt(
                              context,
                              GymEditorDauerBlatt(quelle: quelle),
                            ),
                      child: SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            gymEditorDauerText(
                              eingetragen: stand.dauerEingetragen,
                              schaetzung: stand.schaetzung,
                            ),
                            style: Typografie.tabularNumbers(
                              TextStyle(fontSize: 15, color: muted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (stand.dauerEingetragen != null)
                  CupertinoButton(
                    key: kGymEditorDauerZuruecksetzen,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: notifier.dauerZuruecksetzen,
                    child: Text(
                      gymEditorDauerZuruecksetzen,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoDynamicColor.resolve(
                          Palette.river,
                          context,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eine Kapsel: ein gesetzter Tag (gefüllt, mit „×") oder ein Vorschlag.
class _Kapsel extends StatelessWidget {
  const _Kapsel({
    super.key,
    required this.text,
    required this.gefuellt,
    required this.onTap,
    required this.vorlesen,
    this.zusatz,
  });

  final String text;
  final String? zusatz;
  final bool gefuellt;
  final VoidCallback? onTap;
  final String vorlesen;

  @override
  Widget build(BuildContext context) {
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Semantics(
      button: true,
      label: vorlesen,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gefuellt ? iron.withValues(alpha: 0.14) : null,
            border: gefuellt ? null : Border.all(color: line),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(fontSize: 13, color: gefuellt ? ink : muted),
                ),
                if (zusatz != null) ...[
                  const SizedBox(width: 5),
                  Text(zusatz!, style: TextStyle(fontSize: 13, color: muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
