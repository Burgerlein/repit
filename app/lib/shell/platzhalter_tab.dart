import 'package:flutter/cupertino.dart';

import '../design/glas_abstand.dart';
import '../design/palette.dart';
import '../design/typografie.dart';

/// Ruhiger, ehrlicher Hinweis für einen Tab, der in diesem Meilenstein noch
/// nicht bedienbar ist (Heute, Plan, Gym, Ernährung in M1, siehe
/// `root_view.dart`) — **kein** leerer Schirm, der nach Fehler aussieht, und
/// **keine** Fehlermeldung, die keine ist.
///
/// Bringt bewusst **keinen** eigenen `CupertinoPageScaffold` mit — den
/// stellt der Gastgeber (`RootView`, pro Tab), parallel zur Hausregel „eine
/// gepushte Ansicht bringt niemals ihren eigenen Navigationsstapel mit".
class PlatzhalterTab extends StatelessWidget {
  const PlatzhalterTab({
    super.key,
    required this.titel,
    required this.erklaerung,
  });

  /// Kurzer Titel, z. B. derselbe wie in der Navigationsleiste des Tabs.
  final String titel;

  /// Fließtext, der sagt, was fehlt und dass es kommt — nicht, dass etwas
  /// kaputt ist.
  final String erklaerung;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // `GlasRand` statt einer nackten `Padding` mit erfundenen Werten: Dieser
    // Schirm scrollt nicht (sein Inhalt ist kurz und `mainAxisSize.min`), also
    // rückt ihn `GlasAbstand` über eine echte äußere `Padding` von der
    // durchscheinenden Navigations- und Tableiste ab (siehe
    // `GlasAbstand`-Klassenkommentar) statt den Viewport eines
    // Scroll-Containers zu verändern, den es hier gar nicht gibt.
    return GlasRand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titel,
                textAlign: TextAlign.center,
                style: Typografie.numeric(TypografieGroesse.title3)
                    .copyWith(color: ink),
              ),
              const SizedBox(height: 10),
              Text(
                erklaerung,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.35, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
