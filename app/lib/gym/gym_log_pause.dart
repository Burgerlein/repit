// Die Pausenzeile (#78) — `restRow` aus `docs/screens/components.js`.
//
// **Genau eine im ganzen Training** (Spec 7.1): Die Erfassung setzt sie in
// die Übung, in der man gerade ist, das Vollbild auf die Seite, die es
// zeigt. Die Uhr selbst gehört zum Training (`gymPauseProvider`).
//
// **Diese Zeile ist die einzige, die den Takt liest**
// (`gymPauseAnzeigeProvider`, Spec 7.2): Zweimal je Sekunde neu zu
// zeichnen ist ihre Aufgabe, nicht die der sieben Karten darüber. Die
// Karte, in der sie steht, hängt nicht am Takt.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/symbole.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';
import 'gym_pause_provider.dart';

/// Die Pausenzeile für [uebung]: Ohne laufende Pause steht die empfohlene
/// Zeit da, mit laufender die Restzeit — danach zählt sie hoch.
///
/// Die ganze Zeile ist der Knopf (Start/Stopp). Ruhe `river`, läuft `iron`,
/// vorbei `ok` — und neben der Farbe steht immer ein Wort, denn **Farbe
/// allein trägt die Aussage nicht**.
class GymPauseZeile extends ConsumerWidget {
  const GymPauseZeile({super.key, required this.uebung, this.gross = false});

  final Exercise uebung;

  /// Im Vollbild größer gesetzt (`.rest` gegenüber `.rest.sm2`).
  final bool gross;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anzeige = ref.watch(gymPauseAnzeigeProvider);
    final laeuft = anzeige != null;
    final vorbei = anzeige?.vorbei ?? false;
    final ton = CupertinoDynamicColor.resolve(
      gymPauseTon(laeuft: laeuft, vorbei: vorbei),
      context,
    );

    final grossStil = TextStyle(
      fontFamily: 'Barlow Condensed',
      fontSize: gross ? 20.8 : 17.6,
      color: ton,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final kleinStil = TextStyle(fontSize: 12.2, color: ton);
    final titelStil = TextStyle(
      fontSize: gross ? 16 : 14,
      fontWeight: FontWeight.w600,
      color: ton,
    );
    final symbolGroesse = gross ? 21.0 : 17.0;

    return Padding(
      padding: EdgeInsets.only(top: gross ? 14 : 9),
      child: Semantics(
        button: true,
        label: laeuft
            ? '${gymPauseStatus(vorbei: vorbei)}, ${gymPauseLabel(anzeige.sekunden)}'
            : gymPauseTitel,
        excludeSemantics: true,
        child: GestureDetector(
          key: kGymPauseStart,
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final pause = ref.read(gymPauseProvider.notifier);
            laeuft ? pause.stoppe() : pause.starte(uebung);
          },
          child: DecoratedBox(
            key: kGymPause,
            decoration: BoxDecoration(
              color: ton.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(gross ? 11 : 9),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: gross ? 13 : 11,
                vertical: gross ? 11 : 8,
              ),
              child: SizedBox(
                // Beide Lagen stehen in derselben Höhe: Die größere der
                // beiden Schriften gibt sie vor.
                height: gross ? 25 : 21,
                child: Row(
                  children: [
                    Icon(
                      Symbole.aufloesen(laeuft ? 'stop.circle.fill' : 'timer'),
                      size: symbolGroesse,
                      color: ton,
                    ),
                    const SizedBox(width: 9),
                    if (laeuft) ...[
                      Text(
                        gymPauseLabel(anzeige.sekunden),
                        key: kGymPauseZeit,
                        style: grossStil,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          gymPauseStatus(vorbei: vorbei),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kleinStil,
                        ),
                      ),
                    ] else ...[
                      Text(gymPauseTitel, style: titelStil),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          gymPauseEmpfehlung(uebung),
                          key: kGymPauseZeit,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kleinStil,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
