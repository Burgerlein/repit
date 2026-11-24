// Die gemeinsamen Bauteile der Editor-Blätter (#534; aus
// `gym_editor_blaetter.dart` herausgelöst, #559 — die Datei war 933 Zeilen
// und trug drei Blätter plus ihre Bauteile): der Rahmen mit Kopfzeile, die
// Abschnitts-Überschrift, der Erklärfuß, der Trenner und die Stepper-Zeile.
//
// **Hier steht nichts Fachliches.** Wer ein Blatt baut, nimmt diese Teile;
// was ein Blatt *tut*, steht in `gym_editor_einstellblatt.dart` (Vorschau
// und Einstellblatt) bzw. `gym_editor_blaetter.dart` (Auswahl, Dauer).
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import '../design/typografie.dart';

/// Öffnet [inhalt] als Blatt über dem Editor.
Future<void> zeigeGymEditorBlatt(BuildContext context, Widget inhalt) =>
    showCupertinoModalPopup<void>(context: context, builder: (_) => inhalt);

/// Der Rahmen der Blätter: oben abgerundet, Kopf mit Zurück, Titel, Fertig.
class GymEditorBlattRahmen extends StatelessWidget {
  const GymEditorBlattRahmen({
    super.key,
    required this.titel,
    required this.lead,
    required this.trail,
    required this.child,
    this.leadSchluessel,
    this.trailSchluessel,
    this.trailAktion,
    this.hoehe = 0.82,
    this.tastaturAbstand = true,
  });

  final String titel;
  final String lead;
  final String? trail;
  final Key? leadSchluessel;
  final Key? trailSchluessel;

  /// Was der rechte Knopf tut. Ohne Angabe schließt er nur das Blatt
  /// („Fertig"); die **Vorschau** hängt hier ihr „Speichern" ein, das erst
  /// hinzufügt und dann schließt (Nachtrag 29 Nr. 1).
  final VoidCallback? trailAktion;
  final Widget child;
  final double hoehe;

  /// Ob der Rahmen den Inhalt über die Tastatur hebt. Die **Auswahl** setzt
  /// `false` und nimmt `viewInsets.bottom` stattdessen als unteres Padding
  /// ihrer Liste: Die Liste läuft **unter** der Tastatur durch, statt an
  /// ihrer Oberkante abzuschneiden (#551, Spec 9.4, flutter#179482).
  final bool tastaturAbstand;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final tastatur = tastaturAbstand
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      height: MediaQuery.sizeOf(context).height * hoehe,
      child: DefaultTextStyle(
        style: TextStyle(
          color: ink,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    key: leadSchluessel,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 36),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(lead),
                  ),
                  Expanded(
                    child: Text(
                      titel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  trail == null
                      ? const SizedBox(width: 60, height: 36)
                      : CupertinoButton(
                          key: trailSchluessel,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(44, 36),
                          onPressed:
                              trailAktion ??
                              () => Navigator.of(context).pop(),
                          child: Text(trail!),
                        ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: tastatur),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GymEditorBlattKapitel extends StatelessWidget {
  const GymEditorBlattKapitel(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

class GymEditorBlattFuss extends StatelessWidget {
  const GymEditorBlattFuss(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.33, color: muted),
      ),
    );
  }
}

class GymEditorBlattTrenner extends StatelessWidget {
  const GymEditorBlattTrenner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 0.5,
    margin: const EdgeInsets.only(left: 13),
    color: CupertinoDynamicColor.resolve(Palette.line, context),
  );
}

/// Eine Zeile mit „−", Wert und „+" — der Stepper der iOS-Einstellungen.
class GymEditorStepperZeile extends StatelessWidget {
  const GymEditorStepperZeile({
    super.key,
    required this.schluessel,
    required this.label,
    required this.wert,
    required this.min,
    required this.max,
    required this.onChanged,
    this.schritt = 1,
  });

  final Key schluessel;
  final String label;
  final int wert;
  final int min;
  final int max;
  final int schritt;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, color: ink)),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: wert > min
                  ? () => onChanged((wert - schritt).clamp(min, max))
                  : null,
              child: Semantics(
                label: '$label weniger',
                child: Text('−', style: TextStyle(fontSize: 22, color: river)),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$wert',
                key: schluessel,
                textAlign: TextAlign.center,
                style: Typografie.tabularNumbers(
                  TextStyle(fontSize: 17, color: ink),
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: wert < max
                  ? () => onChanged((wert + schritt).clamp(min, max))
                  : null,
              child: Semantics(
                label: '$label mehr',
                child: Text('+', style: TextStyle(fontSize: 22, color: river)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
