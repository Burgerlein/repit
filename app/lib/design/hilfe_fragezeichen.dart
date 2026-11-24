// Das app-weite ?-Muster: eine Kopfzeile mit kleinem Fragezeichen, dahinter
// ein Modal mit Erklärabsätzen (Tims Wunsch „Hilfetexte hinter ein
// Fragezeichen"; erste Instanz ist das Einstellblatt des Trainings-Editors,
// Nachtrag 29 Nr. 2 der Spec `2026-11-19-eigene-trainings-design.md`, #562).
//
// **Warum hier und nicht im Gym-Schirm:** Der nächste Schirm soll den
// Baustein nehmen können, statt ihn nachzubauen — sonst stehen zwei
// Fassungen desselben ? nebeneinander und laufen auseinander.
//
// **Bewusst schmal:** Titel, Absätze und Schlüssel kommen von außen, sonst
// nichts. Keine Konfigurationsmaschinerie — wer mehr braucht (Bilder,
// Links, Abschnitte), erweitert das hier an einer Stelle.
import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Eine Abschnitts-Überschrift mit einem **?** rechts daneben, das
/// [absaetze] in einem Modal zeigt.
///
/// Die Schlüssel kommen von außen und bleiben damit schirm-spezifisch: Ein
/// Test spricht über `gym-editor-blatt-hilfe`, nicht über einen Namen, den
/// sich der Baustein ausgedacht hat.
class HilfeKopfzeile extends StatelessWidget {
  const HilfeKopfzeile({
    super.key,
    required this.titel,
    required this.absaetze,
    required this.hilfeSchluessel,
    required this.modalSchluessel,
    required this.schliessenSchluessel,
    this.modalTitel,
    this.vorlesetext,
    this.schliessen = 'Fertig',
  });

  /// Die Überschrift des Abschnitts, etwa „Umfang".
  final String titel;

  /// Die Absätze des Modals, in dieser Reihenfolge. Leere Einträge gibt es
  /// nicht — wer nichts zu sagen hat, braucht kein ?.
  final List<String> absaetze;

  final Key hilfeSchluessel;
  final Key modalSchluessel;
  final Key schliessenSchluessel;

  /// Die Überschrift **im** Modal; ohne sie gilt [titel].
  final String? modalTitel;

  /// Der Vorlesetext des ? — **der Zustand, nicht das Zeichen**
  /// (`CLAUDE.md`): „Hilfe zu Umfang und Training", nie „Fragezeichen".
  /// Ohne Angabe „Hilfe zu `<titel>`".
  final String? vorlesetext;

  final String schliessen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Row(
        children: [
          Text(
            titel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          const SizedBox(width: 6),
          // 28 pt Tippfläche um ein 15-pt-Zeichen: unter Apples 44 pt,
          // weil der Knopf sonst die Höhe der Abschnitts-Überschrift
          // bestimmte. Bewusst klein — ein ?, das so laut ist wie die
          // Überschrift, zieht den Blick von ihr ab.
          CupertinoButton(
            key: hilfeSchluessel,
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: () => zeigeHilfe(
              context,
              titel: modalTitel ?? titel,
              absaetze: absaetze,
              modalSchluessel: modalSchluessel,
              schliessenSchluessel: schliessenSchluessel,
              schliessen: schliessen,
            ),
            child: Semantics(
              button: true,
              label: vorlesetext ?? 'Hilfe zu $titel',
              excludeSemantics: true,
              child: Icon(
                CupertinoIcons.question_circle,
                size: 15,
                color: river,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeigt die Erklärabsätze als Modal über dem aktuellen Schirm.
///
/// Eigenständig aufrufbar, nicht nur über [HilfeKopfzeile]: Manche Schirme
/// haben keine Kopfzeile, an der das ? hängen könnte.
Future<void> zeigeHilfe(
  BuildContext context, {
  required String titel,
  required List<String> absaetze,
  required Key modalSchluessel,
  required Key schliessenSchluessel,
  String schliessen = 'Fertig',
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (blatt) => _HilfeModal(
    titel: titel,
    absaetze: absaetze,
    schliessen: schliessen,
    schliessenSchluessel: schliessenSchluessel,
    schluessel: modalSchluessel,
  ),
);

class _HilfeModal extends StatelessWidget {
  const _HilfeModal({
    required this.titel,
    required this.absaetze,
    required this.schliessen,
    required this.schliessenSchluessel,
    required this.schluessel,
  });

  final String titel;
  final List<String> absaetze;
  final String schliessen;
  final Key schliessenSchluessel;
  final Key schluessel;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final rand = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: schluessel,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: ink,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        titel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: schliessenSchluessel,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 36),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(schliessen),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + rand),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final absatz in absaetze)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          absatz,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
