// Der Gym-Übersichtsschirm (#77) — die Wurzel des Gym-Tabs. Aufbau,
// Abschnitte und Reihenfolge wörtlich aus `docs/screens/screens/gym.js`,
// die Begründungen in `docs/superpowers/specs/`, Datei
// `…-gym-fokus-karte-design.md` (im Folgenden „die Spec"). Das
// Datumspräfix steht hier nicht ausgeschrieben, damit der `grep` auf
// hartcodierte Ereignisse aus `CLAUDE.md` über diesem Verzeichnis sauber
// durchläuft.
//
// API und Verhalten sind durch `app/test/gym/gym_view_test.dart` und
// `app/test/gym/gym_view_leerzustaende_test.dart` verbindlich vorgegeben —
// diese Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`,
// „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Die Keine-Daten-Ansicht ist hier der Normalfall, nicht die Ausnahme.**
// Von den sechs Eingaben von `GymDayPlanner.day` existiert heute genau
// eine: der heutige Tag. Es gibt keinen Plan (#64, #81), keine
// Gym-Trainings (#59, #418), keinen Entwurf (#78) und kein Ereignis-Objekt
// für die OP (#41). Der Schirm zeigt deshalb meist den Ruhetag mit den
// Plätzen der gespeicherten Rotation (Push, Pull, Legs, Spec 23) ohne Tag —
// und das ist ein ehrlicher Schirm, keine Fehlermeldung (Spec Abschnitt 9.1).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../health/health_provider.dart';
import '../shell/router.dart';
import 'gym_auswertung.dart';
import 'gym_fokus_karte.dart';
import 'gym_fokus_texte.dart';
import 'gym_provider.dart';
import 'gym_wochenleiste.dart';

/// Der Wurzelschirm des Gym-Tabs.
///
/// **Bringt weder Gerüst noch Leiste noch Navigator mit.** Beides stellt
/// `RootView` für jeden Tab, wie heute schon für `HeuteView`,
/// `ErnaehrungView` und `MehrView`; die Navigationsleiste trägt „Gym" und
/// die Hinweis-Glocke. Ein zweiter `Navigator` hier wäre ein zweiter
/// Stapel im selben Tab (`CLAUDE.md`).
///
/// **Er besorgt seine Daten selbst** ([gymTagProvider]): Seit jeder Schirm
/// aus jedem Tab direkt erreichbar ist, darf niemand sich darauf verlassen,
/// dass vorher eine Übersicht geladen hat. Hereingereicht wird nur der
/// [AppRouter].
///
/// **Fünf Abschnitte, und jeder steht in jedem Zustand und in jeder
/// Datenlage** (Spec Abschnitt 3): Titel und Lede, Fokus-Karte,
/// Wochenleiste, Auswertung; der Hinweis am Fuß nur in `recovery`
/// (Spec 26 Nr. 3). Keiner verschwindet, weil ein Wert
/// fehlt — was sich ändert, ist allein die Füllung.
class GymView extends ConsumerWidget {
  const GymView({super.key, required this.router});

  /// Die Tür zu den Detailschirmen: das Erfassen (#78) von den Knöpfen der
  /// Fokus-Karte und den Kacheln der Wochenleiste, der Verlauf (#79), der
  /// Fortschritt pro Übung (#93) und die Trainings-Übersicht (#533), alle über
  /// `AppTarget.aktuell`.
  ///
  /// Die übrigen Ziele fehlen noch: die Muskelkarte (#96) und der Plan (#81).
  /// Sie laufen später über denselben Weg — über `AppRouter.open(AppTarget
  /// .aktuell(…))`, also auf den Stapel des Tabs, aus dem man kommt, und nie
  /// fest in den Gym-Tab. Sonst führte „zurück" in ein Menü, das der Nutzer
  /// nie geöffnet hat (`CLAUDE.md`, vorgemacht in `shell/mehr_view.dart`).
  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = ref.watch(gymTagProvider);
    final heute = ref.watch(heutigerTagProvider);

    return SingleChildScrollView(
      // `padding` statt einer äußeren `Padding` — aus demselben Grund wie
      // in `HeuteView` und `MehrView`: Eine äußere verkleinerte den
      // Scroll-Viewport, statt den Inhalt darin einzurücken, und dann
      // liefe er nicht mehr sichtbar unter der Leiste durch.
      padding: GlasAbstand.of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift('Gym'),
          _Lede(tag: tag, heute: heute),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GymFokusKarte(
              key: const Key('gym-fokus-karte'),
              tag: tag,
              heute: heute,
              router: router,
            ),
          ),
          const SectionHeader('Diese Woche'),
          GymWochenleiste(
            key: const Key('gym-woche'),
            woche: tag.tag.week,
            heute: heute,
            laedt: tag.laedt,
            router: router,
          ),
          const SectionHeader('Auswertung'),
          GymAuswertung(
            key: const Key('gym-auswertung'),
            tag: tag,
            router: router,
          ),
          // Der Fuß steht nur in `recovery` (Spec 26 Nr. 3) — dort trägt er
          // die ärztliche Freigabe. Sonst ein kleiner Auslauf statt des
          // Fußtexts.
          if (gymHinweis(tag.tag.focus) case final hinweis?)
            Hinweisfuss(hinweis, key: const Key('gym-hinweis'))
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Die Einordnung unter der Überschrift „Gym".
///
/// **Gerechnet, nicht geschrieben** ([gymLede]): die Wochentage der Plätze
/// aus dem Plan, „kein fester Tag", wenn keiner einen hat, und im Zustand
/// `recovery` der Tag nach der OP. In der Swift-Vorlage stand hier einmal
/// „Montag, Mittwoch, Donnerstag" fest im Quelltext, während die
/// Wochenleiste zwei Zeilen tiefer längst „DI" zeigte.
///
/// Steht neben [GrosseUeberschrift] statt in deren `einordnung`, weil die
/// nur einen Text nimmt: Während des Lesens steht hier eine graue Form.
class _Lede extends StatelessWidget {
  const _Lede({required this.tag, required this.heute});

  final GymTag tag;
  final DateTime heute;

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 15,
      color: CupertinoDynamicColor.resolve(Palette.muted, context),
    );
    final text = gymLede(tag.tag, heute: heute);

    return Padding(
      key: const Key('gym-lede'),
      // Dieselben Abstände, die `GrosseUeberschrift` ihrer `einordnung`
      // gibt (3 über, 12 unter, 20 an den Seiten).
      padding: const EdgeInsets.fromLTRB(20, 3, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: tag.laedt
            ? Platzhalter(beispiel: text, stil: stil)
            : Text(text, style: stil),
      ),
    );
  }
}
