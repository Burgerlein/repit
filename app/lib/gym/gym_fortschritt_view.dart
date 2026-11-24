// Der Schirm „Fortschritt pro Übung" (#93) — Dart-Entsprechung von
// `GymProgressView.swift`, gebaut nach dem Entwurf `docs/screens/screens/
// gym-progress.js` und der Spec `docs/superpowers/specs/2026-11-11-gym-
// fortschritt-design.md` (im Folgenden „die Spec"), wo beide sich
// widersprechen: nach der Spec (Abschnitt 17 nennt, was am Board nachzuziehen
// ist).
//
// API und Verhalten sind durch `app/test/gym/gym_fortschritt_*_test.dart`
// verbindlich vorgegeben — diese Dateien dürfen die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Von oben nach unten, und jeder Abschnitt steht in jeder Datenlage da:**
// die Auswahl der Übung, zwei Kennzahlen, die Diagrammkarte, der Satz zur
// Übung (nur bei Unterstützung und Zeitübungen — er hängt an der Übung, nicht
// an den Daten), der Hinweiskasten und die Fußnote. Keiner verschwindet, weil
// ein Wert fehlt („Eine Anzeige, die es gibt, hat genau eine Form").
//
// **Kein Trendpfeil, kein „+ 2,5 kg", kein „du wirst stärker".** Eine Aussage
// über die Richtung gibt es genau an zwei Stellen: den Steigerungsvorschlag
// (aus dem Kern) und das Plateau (nach vier Trainings).
//
// **Kein Navigator hier.** Der Schirm wird auf den Stapel des Tabs
// geschoben, aus dem man kommt ([oeffneGymFortschritt], `AppTarget.aktuell`).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../shell/diagramm_zeitraum.dart';
import '../shell/mess_abschnitte.dart' show Notizflaeche;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_fortschritt_diagramm.dart';
import 'gym_fortschritt_hinweis.dart';
import 'gym_fortschritt_kacheln.dart';
import 'gym_fortschritt_kennwerte.dart';
import 'gym_fortschritt_provider.dart';
import 'gym_fortschritt_schluessel.dart';
import 'gym_fortschritt_texte.dart';
import 'gym_verlauf_provider.dart' show gymSitzungenProvider;

/// Öffnet den Schirm auf dem Stapel des **aktuell gewählten** Tabs — gerufen
/// aus der Zeile „Fortschritt pro Übung" der Gym-Übersicht.
///
/// [uebungId] stellt eine andere Übung vor (für später, etwa ein Link aus der
/// Erfassung); ohne sie gilt die erste Übung von Gym A.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des Tabs,
/// aus dem man kommt, sonst führte „zurück" in ein Menü, das der Nutzer nie
/// geöffnet hat (`CLAUDE.md`).
void oeffneGymFortschritt(AppRouter router, {String? uebungId}) => router.open(
  AppTarget.aktuell((_) => GymFortschrittSeite(uebungId: uebungId)),
);

/// Der ganze geschobene Schirm — Gerüst und Navigationsleiste um
/// [GymFortschrittView].
///
/// **Kein eigener `Navigator`:** Die Seite wird auf den Stapel eines Tabs
/// geschoben, der Stapel gehört weiter `RootView`.
class GymFortschrittSeite extends StatelessWidget {
  const GymFortschrittSeite({super.key, this.uebungId});

  final String? uebungId;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(gymFortschrittTitel),
      ),
      child: GymFortschrittView(uebungId: uebungId),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([gymFortschrittProvider]): aus jedem Tab
/// direkt erreichbar, darf er sich nicht darauf verlassen, dass die
/// Gym-Übersicht vorher geladen hat. Die Auswahl der Übung lebt hier — sie
/// ist Bedienzustand, kein Datenstand; dass ein Wechsel A → B → A den Wert von
/// A sofort wieder zeigt, trägt der Provider, der je Übung hält.
class GymFortschrittView extends ConsumerStatefulWidget {
  const GymFortschrittView({super.key, this.uebungId});

  final String? uebungId;

  @override
  ConsumerState<GymFortschrittView> createState() => _GymFortschrittViewState();
}

class _GymFortschrittViewState extends ConsumerState<GymFortschrittView> {
  /// Die in **diesem** Schirm gewählte Übung — `null`, solange hier keine
  /// gewählt wurde; dann gilt die Vorgabe des Aufrufers, die zuletzt
  /// gezeigte ([gymFortschrittZuletztProvider], Fehler `32`) oder [_vorgabe].
  String? _gewaehlt;

  /// Die Stufe, die der Nutzer im Diagramm gewählt hat — `null`, solange er
  /// keine gewählt hat und die Startstufe gilt. Die Kacheln folgen ihr: Sie
  /// nennen das Ende der Linie, die gerade gezeigt wird (Spec 5.2).
  DiagrammStufe? _stufe;

  /// Die Kennzahlen, **gehalten** statt je Bild gerechnet: Sie ändern sich
  /// nur, wenn sich der Stand oder die Stufe ändert (Hausregel 2).
  GymFortschritt? _gemerktStand;
  DiagrammStufe? _gemerkteStufe;
  late GymFortschrittKennwerte _kennwerte;

  /// Die beim Öffnen zuletzt gezeigte Übung — **einmal** gelesen (Fehler
  /// `32`): Wählt eine zweite lebende Instanz in einem anderen Tab-Stapel
  /// später etwas anderes, darf diese hier nicht bei irgendeinem Rebuild
  /// still umschalten (die Stufe gehört zur gezeigten Übung).
  late final String? _zuletztBeimOeffnen = ref.read(
    gymFortschrittZuletztProvider,
  );

  /// Die gerade gezeigte Übung.
  String get _uebungId =>
      _gewaehlt ?? widget.uebungId ?? _zuletztBeimOeffnen ?? _vorgabe;

  /// Die erste Übung von Gym A — eine **feste** Vorgabe, keine aus den Daten
  /// gerechnete: Eine Auswahl, die erst springt, wenn der Verlauf eintrifft,
  /// ist genau das Springen, das die Hausregel verbietet (Spec 3.1).
  static String get _vorgabe =>
      ExerciseCatalog.exercisesFor(Workout.a).first.id;

  void _waehle(String id) {
    // **Erst vergleichen, dann merken**: [_uebungId] liest den gemerkten
    // Stand mit — nach dem Merken wäre jede Wahl „unverändert".
    final vorher = _uebungId;
    // Gemerkt wird jede gezeigte Wahl — sie steht nach dem Zurücknavigieren
    // wieder da (Fehler `32`).
    ref.read(gymFortschrittZuletztProvider.notifier).merke(id);
    if (id == vorher) {
      // Nichts Sichtbares ändert sich; nur die eigene Wahl festhalten.
      _gewaehlt = id;
      return;
    }
    setState(() {
      _gewaehlt = id;
      // Stufe und Blätterstand der einen Übung gelten nicht für die andere.
      _stufe = null;
    });
  }

  Future<void> _oeffneMenue() async {
    // **Nur Trainierte** (#551, Nachtrag 17 Nr. 4, Tim): Das Menü
    // beantwortet „wie entwickle ich mich", nicht „was gibt es". Die
    // aktuell gezeigte Übung steht immer mit drin — was die Auswahlzeile
    // nennt, muss das Menü wiederfinden. Die Liste ist im Provider
    // gehalten (Hausregel 2) und hier einmal je Öffnen gelesen.
    final stand = ref.read(gymFortschrittUebungenProvider);
    final aktuelle = _uebungId;
    // Schlüssel einmal je Übung falten, nicht je Vergleich.
    final sortKeys = {
      for (final id in {...stand.ids, aktuelle})
        id: foldSearchWords(ExerciseLibrary.byId(id)!.name).join(' '),
    };
    final ids = sortKeys.keys.toList()
      ..sort((a, b) => sortKeys[a]!.compareTo(sortKeys[b]!));
    // Der Leersatz steht nur, wo **bekannt** ist, dass nichts trainiert
    // wurde (Fehler `01`) — nie, solange die Ablage noch nicht geantwortet
    // hat, und nie statt eines gezeigten Eintrags.
    final leer = stand.bekannt && stand.ids.isEmpty;

    final gewaehlt = await showCupertinoModalPopup<String>(
      context: context,
      builder: (blatt) => CupertinoActionSheet(
        title: const Text(gymFortschrittAuswahlLabel),
        message: leer
            ? const Text(
                gymFortschrittAuswahlLeer,
                key: kGymFortschrittWahlLeer,
              )
            : null,
        actions: [
          for (final id in ids)
            CupertinoActionSheetAction(
              key: kGymFortschrittWahl(id),
              isDefaultAction: id == aktuelle,
              onPressed: () => Navigator.pop(blatt, id),
              child: Text(ExerciseLibrary.byId(id)!.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(blatt),
          child: const Text(gymFortschrittAuswahlAbbrechen),
        ),
      ),
    );
    if (gewaehlt != null && mounted) _waehle(gewaehlt);
  }

  GymFortschrittKennwerte _kennwerteFuer(GymFortschritt stand) {
    final stufe = _stufe ?? gymFortschrittStartStufe(stand.reihe);
    if (_gemerktStand != stand || _gemerkteStufe != stufe) {
      _kennwerte = gymFortschrittKennwerte(stand.reihe, stufe);
      _gemerktStand = stand;
      _gemerkteStufe = stufe;
    }
    return _kennwerte;
  }

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(gymFortschrittProvider(_uebungId));
    final uebung = stand.uebung;
    final kennwerte = _kennwerteFuer(stand);

    final hoechst = kennwerte.hoechst;
    final einRm = kennwerte.einRm;

    return SingleChildScrollView(
      // `padding` statt einer äußeren `Padding`: Der Inhalt läuft unter der
      // durchscheinenden Leiste durch, statt vorher anzuhalten.
      padding: GlasAbstand.of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Auswahl(name: uebung.name, onTap: _oeffneMenue),
          GymFortschrittKacheln(
            hoechstLabel: uebung.isTimed
                ? gymFortschrittKachelBesteZeit
                : gymFortschrittKachelHoechst,
            hoechst: hoechst == null
                ? null
                : gymFortschrittHoechstText(hoechst, uebung),
            einRm: einRm == null ? null : gymFortschritt1rmText(einRm),
            laedt: stand.laedt,
            fehlgeschlagen: stand.fehlgeschlagen,
          ),
          GymFortschrittDiagramm(
            stand: stand,
            onStufe: (stufe) => setState(() => _stufe = stufe),
          ),
          // **Der Satz zur Übung hängt an der Übung, nicht an den Daten:** Er
          // steht in jeder Lage da, auch beim Laden. Eine Zeile, die je nach
          // Datenlage kommt und geht, ließe den Schirm springen. Der Grund
          // steht einmal hier, nicht an der Kachel.
          if (uebung.allowsAssist)
            const Notizflaeche(
              key: kGymFortschrittUnterstuetzung,
              text: gymFortschrittUnterstuetzung,
              oben: 14,
            )
          else if (uebung.isTimed)
            const Notizflaeche(
              key: kGymFortschrittZeituebung,
              text: gymFortschrittZeituebung,
              oben: 14,
            ),
          GymFortschrittHinweis(
            stand: stand,
            onErneut: () => ref.invalidate(gymSitzungenProvider),
          ),
          const Hinweisfuss(gymFortschrittFuss, key: kGymFortschrittFussnote),
        ],
      ),
    );
  }
}

/// Die Auswahlzeile „Übung" — `menuPick` im Entwurfsboard: Beschriftung links,
/// Name der gewählten Übung rechts in Flussblau, Antippen öffnet das Menü.
/// Steht in jeder Lage da und trägt immer denselben Namen.
class _Auswahl extends StatelessWidget {
  const _Auswahl({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      key: kGymFortschrittAuswahl,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: InsetCard(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text(
                    gymFortschrittAuswahlLabel,
                    style: TextStyle(fontSize: 16, color: ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 16, color: river),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    CupertinoIcons.chevron_up_chevron_down,
                    size: 13,
                    color: muted.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
