// Das Trainings-Detail (#533 unter #531, Task 2.4; Spec 8) — Aufbau,
// Abschnitte und Beschriftungen wörtlich aus `docs/screens/screens/
// gym-training-detail.js` (Varianten `eigenes` und `template`).
//
// API und Verhalten sind durch `app/test/gym/gym_training_detail_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`).
//
// **Ein Baustein mit drei Aufrufern** (Tim, 18.11.2026): die Übersicht, die
// Import-Vorschau (#535) und perspektivisch die Erfassung. Die Abschnitte
// stehen deshalb in `gym_training_detail_bausteine.dart` und lesen alle nur
// einen [GymTrainingDetailStand]; die Vorschau setzt sie mit eigenem Fuß
// wieder zusammen, ohne sie umzubauen.
//
// **Der Schirm besorgt seine Daten selbst** ([gymTrainingDetailProvider] je
// Kennung): Er ist aus jedem Tab erreichbar. Hereingereicht wird nur die
// Kennung und der [AppRouter].
//
// **Drei Lagen, jede in der Form der Detailseite** (Spec 8.3):
//
// - **lädt:** alle Abschnitte stehen, Titel, Lede, Figur und Zeilen als graue
//   Formen, die Knöpfe abgeblendet. **Nie „gibt es nicht mehr"** (Fehler `01`).
// - **gefunden:** Template und Eigenes unterscheiden sich an genau den Stellen
//   aus 8.2 (Kopie-Hinweis, „Template löschen", Herkunft).
// - **nicht gefunden:** ein Satz, Titel statt Abschnitte, keine Knöpfe.
//
// **Löschen** fragt zurück. Danach schließt das Detail; die Übersicht steht
// ohne das Training da. Läuft das Training in der Erfassung, lehnt die Ablage
// ab (Spec 4.7) und die Rückfrage sagt es — das Detail bleibt.
//
// **„Training starten"** öffnet die Erfassung über den Schlüssel des Trainings
// (`TrainingKey.fromId`, Spec 15); läuft schon ein Training, gilt die
// bestehende Rückfrage der Erfassung. **„Bearbeiten"** öffnet den Editor: ein
// Eigenes wird bearbeitet, ein Template als Kopie. **„Teilen" steht abgeblendet
// da und tut nichts** (Plan 2.5, Lücke 7), bis es #535 gibt.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/glas_abstand.dart';
import '../design/palette.dart';
import '../shell/mess_abschnitte.dart' show Notizflaeche;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_editor_provider.dart' show GymEditorQuelle;
import 'gym_log_view.dart';
import 'gym_training_editor_view.dart' show oeffneGymEditor;
import 'gym_training_detail_bausteine.dart';
import 'gym_trainings_fuss.dart';
import 'gym_trainings_provider.dart';
import 'gym_trainings_schluessel.dart';
import 'gym_trainings_texte.dart';

/// Öffnet das Detail des Trainings [id] auf dem Stapel des **aktuell
/// gewählten** Tabs — gerufen aus einer Kachel der Übersicht.
///
/// `AppTarget.aktuell`, nicht `.detail` (`CLAUDE.md`).
void oeffneGymTrainingDetail(AppRouter router, String id) => router.open(
  AppTarget.aktuell((_) => GymTrainingDetailView(id: id, router: router)),
);

/// Der ganze geschobene Schirm — mit Gerüst und Navigationsleiste.
class GymTrainingDetailView extends ConsumerStatefulWidget {
  const GymTrainingDetailView({
    super.key,
    required this.id,
    required this.router,
  });

  /// Die Kennung des Trainings (`WorkoutDefinition.id`).
  final String id;

  /// Die Tür zur Erfassung.
  final AppRouter router;

  @override
  ConsumerState<GymTrainingDetailView> createState() =>
      _GymTrainingDetailViewState();
}

class _GymTrainingDetailViewState extends ConsumerState<GymTrainingDetailView> {
  /// Eine Rückfrage steht schon — keine zweite darüber.
  bool _fragt = false;

  /// Das Training ist gelöscht und das Detail schließt gerade. Solange es
  /// zufährt, liest die Quelle schon „gibt es nicht mehr" — dieser Satz stünde
  /// sonst für die Dauer des Übergangs auf dem Schirm.
  bool _entfernt = false;

  /// Der letzte Stand **mit** Training — was beim Schließen stehen bleibt.
  GymTrainingDetailStand? _letzter;

  Future<void> _loesche(WorkoutDefinition training) async {
    if (_fragt) return;
    _fragt = true;
    final loeschen = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        key: kGymTrainingDetailLoeschenFrage,
        title: Text(gymTrainingDetailLoeschenFrage(training.name)),
        content: const Text(gymTrainingDetailLoeschenFuss),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text(gymTrainingDetailAbbrechen),
          ),
          CupertinoDialogAction(
            key: kGymTrainingDetailLoeschenBestaetigen,
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text(gymTrainingDetailLoeschenBestaetigen),
          ),
        ],
      ),
    );
    _fragt = false;
    if (loeschen != true || !mounted) return;

    // Vor dem Löschen gemerkt, damit der Satz „gibt es nicht mehr" nie auf dem
    // Schirm steht: Die Quelle liest gleich neu, und der Schirm schließt.
    _entfernt = true;
    final ergebnis = await ref
        .read(gymTrainingsAktionenProvider.notifier)
        .loesche(training.id);
    if (!mounted) return;

    switch (ergebnis) {
      case GymLoeschErgebnis.geloescht:
        Navigator.of(context).pop();
      case GymLoeschErgebnis.laeuft:
        _entfernt = false;
        await _meldung(
          gymTrainingDetailLaeuftTitel,
          gymTrainingDetailLaeuftText(training.name),
        );
      case GymLoeschErgebnis.fehlgeschlagen:
        _entfernt = false;
        await _meldung(gymTrainingDetailLoeschenFehlerTitel, null);
    }
  }

  Future<void> _meldung(String titel, String? text) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          title: Text(titel),
          content: text == null ? null : Text(text),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialog),
              child: const Text(gymTrainingDetailOk),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gelesen = ref.watch(gymTrainingDetailProvider(widget.id));
    if (gelesen.training != null) _letzter = gelesen;
    final stand = _entfernt && gelesen.training == null && _letzter != null
        ? _letzter!
        : gelesen;

    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final padding = MediaQuery.paddingOf(context);
    final training = stand.training;
    final nichtGefunden = !stand.laedt && training == null;

    return CupertinoPageScaffold(
      key: kGymTrainingDetail,
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: gymTrainingDetailTitelZurueck,
        // „Teilen" — abgeblendet, bis es ein Teilen gibt. Ein Training, das es
        // nicht gibt, lässt sich nicht teilen.
        trailing: nichtGefunden
            ? null
            : Opacity(
                opacity: 0.45,
                child: CupertinoButton(
                  key: kGymTrainingDetailTeilen,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: null,
                  child: const Text(gymTrainingDetailTeilen),
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
            // Statusleiste, und die Überschrift läge beim Öffnen unter der
            // Navigationsleiste (#546, Nr. 6).
            child: Builder(
              builder: (inner) => SingleChildScrollView(
                padding: GlasAbstand.of(inner).copyWith(bottom: 24),
                child: nichtGefunden
                    ? _NichtGefunden(fehlgeschlagen: stand.fehlgeschlagen)
                    : _Inhalt(
                        stand: stand,
                        onLoesche: training == null
                            ? null
                            : () => _loesche(training),
                      ),
              ),
            ),
          ),
          // Ein Training, das es nicht gibt, hat keine Fußleiste mit Knöpfen.
          if (!nichtGefunden) _fuss(training),
          SizedBox(height: padding.bottom),
        ],
      ),
    );
  }

  /// Hauptknopf „Training starten", darunter „Bearbeiten" bzw.
  /// „Bearbeiten (als Kopie)".
  Widget _fuss(WorkoutDefinition? training) {
    // Gestartet wird über den Schlüssel des Trainings (Spec 15): ein Enum-Fall,
    // wo es einen gibt, sonst seine Kennung. Ein Entwurf des Editors ist weder
    // startbar noch einplanbar (Spec 9.6).
    final schluessel = training == null || training.isDraft
        ? null
        : TrainingKey.fromId(training.id);

    return GymTrainingsFuss(
      label: gymTrainingDetailStarten,
      schluessel: kGymTrainingDetailStarten,
      onPressed: schluessel == null
          ? null
          : () => oeffneGymLog(widget.router, schluessel),
      alt: training?.category == WorkoutCategory.template
          ? gymTrainingDetailBearbeitenKopie
          : gymTrainingDetailBearbeiten,
      altSchluessel: kGymTrainingDetailBearbeiten,
      // Ein Eigenes wird bearbeitet, ein Template als Kopie (Spec 4.5, 9);
      // der Editor liegt auf dem Detail und schließt es, wo es dazugehört.
      altOnPressed: training == null || training.isDraft
          ? null
          : () => oeffneGymEditor(
              widget.router,
              training.category == WorkoutCategory.template
                  ? GymEditorQuelle.kopie(training.id)
                  : GymEditorQuelle.bearbeite(training.id),
              ausDetail: true,
            ),
    );
  }
}

/// Alle Abschnitte des Details — mit Training oder als graue Formen.
class _Inhalt extends StatelessWidget {
  const _Inhalt({required this.stand, required this.onLoesche});

  final GymTrainingDetailStand stand;

  /// `null`: Es gibt kein Training zu löschen.
  final VoidCallback? onLoesche;

  @override
  Widget build(BuildContext context) {
    final training = stand.training;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nur beim Laden: das Zeichen, dass noch gelesen wird. Es trägt keinen
        // Text und keine Zahl.
        if (stand.laedt) const SizedBox.shrink(key: kGymTrainingDetailLaedt),
        GymDetailKopf(stand: stand),
        GymDetailFigur(stand: stand),
        GymDetailUebungen(stand: stand),
        if (training?.category == WorkoutCategory.template)
          const Notizflaeche(
            key: kGymTrainingDetailKopieHinweis,
            text: gymTrainingDetailKopieHinweis,
            oben: 12,
          ),
        GymDetailEckdaten(stand: stand),
        // Nur das Eigene lässt sich löschen (Spec 26 Nr. 1) — und die Zeile
        // steht erst, wenn „eigene" gelesen ist, genau wie der Kopie-Hinweis
        // beim Template: derselbe, dokumentierte Sprung je Öffnen.
        if (training?.category == WorkoutCategory.own)
          GymDetailLoeschen(onTap: onLoesche),
      ],
    );
  }
}

/// „Dieses Training gibt es nicht mehr." — **in der Form der Detailseite**:
/// ein Titel, kein Abschnitt, keine Knöpfe.
///
/// Ist das erste Lesen gescheitert, steht ein anderer Satz: Das ist nicht „gibt
/// es nicht mehr", und der Schirm behauptet es nicht.
class _NichtGefunden extends StatelessWidget {
  const _NichtGefunden({required this.fehlgeschlagen});

  final bool fehlgeschlagen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Text(
        fehlgeschlagen
            ? gymTrainingDetailNichtLesbar
            : gymTrainingDetailNichtGefunden,
        key: kGymTrainingDetailNichtGefunden,
        style: TextStyle(fontSize: 17, height: 1.35, color: ink),
      ),
    );
  }
}
