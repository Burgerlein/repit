// Die Trainings-Übersicht (#533 unter #531, Task 2.3; Spec 7) — Aufbau,
// Abschnitte und Beschriftungen wörtlich aus `docs/screens/screens/
// gym-trainings.js` (Varianten `liste`, `eigene-leer`, `gefiltert`), Bausteine
// `trainingTile`, `muscleThumb` und `.tagfilter`.
//
// API und Verhalten sind durch `app/test/gym/gym_trainings_*_test.dart`
// verbindlich vorgegeben — diese Dateien dürfen die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`).
//
// **Sechs Abschnitte, und jeder steht in jedem Zustand** (Spec 7.1, 26 Nr. 2):
// Zurück und „+" in der Leiste, Kicker/Titel, die Filterzeile, die Gruppe
// „Templates", die Gruppe „Eigene", der Fuß-Knopf. Lede und Hinweisfuß gibt
// es nicht mehr. Keiner
// verschwindet, weil ein Wert fehlt — was sich ändert, ist allein die
// Füllung (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine Form"):
//
// - **lädt:** je Gruppe genau **eine graue Kachel** in Kachelgröße, die
//   Filterzeile mit „Alle" als einziger grauer Kapsel — **kein Satz, keine
//   Zahl, kein Fehler** (Fehler `01`).
// - **Templates und Eigene**, **Noch keine Eigenen**, **Gefiltert**, **Keine
//   Templates mehr:** der Gruppenkopf bleibt, und was fehlt, sagt ein Satz an
//   seiner Stelle.
// - **Ein gescheitertes erstes Lesen** behauptet keine Datenlage („noch keine
//   Trainings"), sondern sagt, dass nicht gelesen werden konnte.
//
// **Ein Schirm, der Daten braucht, besorgt sie selbst** (`gymTrainingsProvider`):
// Er ist aus jedem Tab erreichbar und verlässt sich nicht darauf, dass die
// Gym-Übersicht vorher geladen hat. Hereingereicht wird nur der [AppRouter].
// **Kein Navigator hier:** Er liegt auf dem Stapel des Tabs, aus dem man kommt
// ([oeffneGymTrainings], `AppTarget.aktuell`).
//
// **„+" und „Eigenes Training anlegen" öffnen den Editor, neu** (Plan 3.8,
// Spec 7.6). Beide tragen keinen Text, der etwas verspricht.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/glas_abstand.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import '../shell/mess_abschnitte.dart' show Notizflaeche;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_editor_provider.dart' show GymEditorQuelle;
import 'gym_training_editor_view.dart' show oeffneGymEditor;
import 'gym_trainings_filter.dart';
import 'gym_trainings_fuss.dart';
import 'gym_trainings_kachel.dart';
import 'gym_trainings_provider.dart';
import 'gym_trainings_schluessel.dart';
import 'gym_trainings_texte.dart';

/// Öffnet die Übersicht auf dem Stapel des **aktuell gewählten** Tabs —
/// gerufen aus der Zeile „Trainings" des Gym-Schirms.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des Tabs,
/// aus dem man kommt, sonst führte „zurück" in ein Menü, das der Nutzer nie
/// geöffnet hat (`CLAUDE.md`).
void oeffneGymTrainings(AppRouter router) =>
    router.open(AppTarget.aktuell((_) => GymTrainingsView(router: router)));

/// Der ganze geschobene Schirm — mit Gerüst und Navigationsleiste.
class GymTrainingsView extends ConsumerWidget {
  const GymTrainingsView({super.key, required this.router});

  /// Die Tür zum Detail.
  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stand = ref.watch(gymTrainingsGefiltertProvider);
    final filter = ref.watch(gymTrainingsFilterProvider);
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final padding = MediaQuery.paddingOf(context);

    return CupertinoPageScaffold(
      key: kGymTrainings,
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: gymTrainingsKicker,
        // Das „+": ein neues, leeres Training im Editor (Spec 7.6).
        trailing: CupertinoButton(
          key: kGymTrainingsPlus,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: () => oeffneGymEditor(router, const GymEditorQuelle.neu()),
          child: Semantics(
            label: gymTrainingsAnlegen,
            child: Icon(Symbole.aufloesen('plus'), size: 22),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // `Builder`: `GlasAbstand.of` muss den `MediaQuery` **unterhalb**
            // des Gerüsts lesen — erst dort steht die Höhe der Leiste im
            // oberen Rand. Aus dem `context` von `build` käme nur die
            // Statusleiste, und der Titel läge beim Öffnen unter der
            // Navigationsleiste (#546, Nr. 6).
            child: Builder(
              builder: (inner) => SingleChildScrollView(
                padding: GlasAbstand.of(inner).copyWith(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Kopf(),
                    GymTrainingsFilter(
                      key: kGymTrainingsFilter,
                      tags: stand.allTags,
                      gewaehlt: filter,
                      laedt: stand.laedt,
                      onWaehle: (tag) => ref
                          .read(gymTrainingsFilterProvider.notifier)
                          .setze(tag),
                    ),
                    const SectionHeader(
                      gymTrainingsGruppeTemplates,
                      key: kGymTrainingsGruppeTemplates,
                    ),
                    ..._templates(stand, filter),
                    const SectionHeader(
                      gymTrainingsGruppeEigene,
                      key: kGymTrainingsGruppeEigene,
                    ),
                    ..._eigene(stand, filter),
                  ],
                ),
              ),
            ),
          ),
          GymTrainingsFuss(
            label: gymTrainingsAnlegen,
            schluessel: kGymTrainingsAnlegen,
            onPressed: () =>
                oeffneGymEditor(router, const GymEditorQuelle.neu()),
          ),
          SizedBox(height: padding.bottom),
        ],
      ),
    );
  }

  /// Die Gruppe „Templates" — genau eines von vieren (Spec 7.4).
  List<Widget> _templates(GymTrainingsStand stand, String? filter) {
    if (stand.laedt) {
      return const [
        GymTrainingKachelLaedt(schluessel: kGymTrainingsLaedtTemplates),
      ];
    }
    if (stand.fehlgeschlagen) {
      return const [
        Notizflaeche(
          key: kGymTrainingsFehler,
          text: gymTrainingsNichtLesbar,
          ton: Palette.warn,
          oben: 0,
        ),
      ];
    }
    if (stand.templates.isEmpty) {
      return [
        filter == null
            ? const Notizflaeche(
                key: kGymTrainingsLeerTemplates,
                text: gymTrainingsLeerTemplates,
                oben: 0,
              )
            : const Notizflaeche(
                key: kGymTrainingsLeerGefiltertTemplates,
                text: gymTrainingsLeerGefiltertTemplates,
                oben: 0,
              ),
      ];
    }
    return [
      for (final kachel in stand.templates)
        GymTrainingKachel(
          key: ValueKey('kachel-${kachel.id}'),
          kachel: kachel,
          router: router,
        ),
    ];
  }

  /// Die Gruppe „Eigene" — genau eines von vieren (Spec 7.4).
  List<Widget> _eigene(GymTrainingsStand stand, String? filter) {
    if (stand.laedt) {
      return const [
        GymTrainingKachelLaedt(schluessel: kGymTrainingsLaedtEigene),
      ];
    }
    // Ohne Stand (erstes Lesen gescheitert) steht hier nichts: Die Gruppe
    // behauptete sonst „noch keine eigenen Trainings".
    if (stand.fehlgeschlagen) return const [];
    if (stand.own.isEmpty) {
      return [
        filter == null
            ? const Notizflaeche(
                key: kGymTrainingsLeerEigene,
                text: gymTrainingsLeerEigene,
                oben: 0,
              )
            : const Notizflaeche(
                key: kGymTrainingsLeerGefiltertEigene,
                text: gymTrainingsLeerGefiltertEigene,
                oben: 0,
              ),
      ];
    }
    return [
      for (final kachel in stand.own)
        GymTrainingKachel(
          key: ValueKey('kachel-${kachel.id}'),
          kachel: kachel,
          router: router,
        ),
    ];
  }
}

/// Kicker und Titel (`obBody`). Eine Lede gibt es nicht (Spec 26 Nr. 2).
class _Kopf extends StatelessWidget {
  const _Kopf();

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gymTrainingsKicker.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              gymTrainingsTitel,
              style: Typografie.numeric(TypografieGroesse.title2)
                  .copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
