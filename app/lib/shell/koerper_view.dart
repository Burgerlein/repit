// Der Schirm `koerper` (#82) — die Drehscheibe für alles, was am Körper
// gemessen wird, erreichbar über *Mehr › Körper*. Die Zahlen kommen aus
// `koerper_zustand.dart`, die Abschnitte aus `koerper_abschnitte.dart`,
// die Bausteine der drei Messwert-Schirme aus `mess_abschnitte.dart`.
//
// API und Verhalten sind durch `app/test/shell/koerper_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/koerper.js`: Überschrift mit
// Stand-Zeile → Gewichts-Kopfkarte → „Auf einen Blick" mit vier Kacheln →
// „Bereiche" mit vier Zeilen → Fußnote. **Eine Zahl trägt den Schirm, nicht
// fünf gleichrangige:** Das Gewicht ist das, weswegen man herkommt.
//
// **Statt Balken und Zielabstand steht der Satz „Kein Körperziel
// festgelegt".** `Ziele` kennt kein Zielgewicht und kein Zieldatum; die
// kommen aus #41. Ein Zielgewicht oder Zieldatum im Quelltext wäre ein
// Regelbruch (`CLAUDE.md`, „Keine hartcodierten Ereignisse"), auch als
// Vorbelegung.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import 'koerper_abschnitte.dart';
import 'koerper_zustand.dart';
import 'mess_abschnitte.dart';
import 'messung_detail_view.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet den Körper-Schirm auf dem Stapel des **aktuell gewählten** Tabs —
/// die eine Stelle, die das weiß. Von dort ruft `MehrView`.
void oeffneKoerper(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => KoerperSeite(router: router)));

/// Der Rahmen: Gerüst und Navigationsleiste um [KoerperView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
///
/// Die Leiste trägt **keinen** Titel: Der Schirm nennt sich eine Zeile
/// tiefer selbst, groß, und zweimal derselbe Titel übereinander ist kein
/// Aufbau, sondern ein Versehen (dieselbe Entscheidung wie bei
/// `ErholungView`). Der Zurück-Knopf steht trotzdem da — den setzt
/// `CupertinoNavigationBar` von sich aus.
class KoerperSeite extends StatelessWidget {
  const KoerperSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(),
      child: KoerperView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([koerperWerteProvider]): Jeder Schirm
/// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass
/// eine Übersicht vorher geladen hat.
class KoerperView extends ConsumerWidget {
  const KoerperView({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messwert = ref.watch(koerperWerteProvider);
    final lage = messLageAus(messwert);
    final werte = messwert is Bekannt<KoerperWerte> ? messwert.wert : null;

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift('Körper'),
          LageZeile(
            key: switch (lage) {
              MessLage.laedt => const Key('koerper-laden'),
              MessLage.fehler => const Key('koerper-fehler'),
              MessLage.werte || MessLage.leer => null,
            },
            lage: lage,
            stand: standAus(messwert),
            laeuft: messwert is Bekannt<KoerperWerte> && messwert.laeuft,
          ),
          KoerperKopfkarte(
            lage: lage,
            werte: werte,
            onTap: () => oeffneMessungDetail(router, MessArt.gewicht),
          ),
          KoerperKacheln(
            key: const Key('koerper-kacheln'),
            lage: lage,
            werte: werte,
            router: router,
          ),
          const SectionHeader('Bereiche'),
          KoerperBereiche(router: router, werte: werte),
          const Hinweisfuss(
            'Gewicht, Körperfett und Muskelmasse kommen von der Waage über '
            'Apple Health, die Schritte vom iPhone und der Uhr. Umfänge '
            'trägst du selbst ein. Alles Schätzungen, keine medizinische '
            'Bewertung.',
          ),
        ],
      ),
    );
  }
}
