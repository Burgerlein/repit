// Der Schirm „Training eintragen" (#78) — **der Schirm, auf dem die App
// beim Heben benutzt wird**: mit nassen Händen, zwischen zwei Sätzen, mit dem
// Telefon auf der Bank. Aufbau, Abschnitte und Zustände nach
// `docs/screens/screens/gym-log.js`, die Begründungen in
// `docs/superpowers/specs/` (Datei `…-gym-training-eintragen-design.md`, im
// Folgenden „die Spec"); Dart-Entsprechung von `GymLogView.swift`.
//
// API und Verhalten sind durch `app/test/gym/gym_log_*_test.dart`
// verbindlich vorgegeben — diese Dateien dürfen die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Von oben nach unten** (Spec 3): die klebende Fortschrittsleiste unter
// der Navigationsleiste, Titel, Eckdaten, die Aufwärm-Karte, die
// Übungskarten, „Training abbrechen", die Fußnote — und unten die klebende
// Fußleiste über der Tableiste. Jeder Abschnitt steht in jeder Datenlage;
// keiner verschwindet, weil ein Wert fehlt (`CLAUDE.md`: „Eine Anzeige, die
// es gibt, hat genau eine Form").
//
// **Der Entwurf lebt im Notifier** ([gymLogProvider]), nicht in diesem
// `State` (Spec 9.2, Fehler `32`): Ein eingetippter Satz steht nach dem
// Öffnen und Schließen des Vollbilds wieder da, auch nach dem Verlassen des
// Schirms. Dieser `State` hält nur, was dem Auge gehört — welche Karten
// zugeklappt sind.
//
// **Kein Navigator hier.** Der Schirm wird auf den Stapel des Tabs
// geschoben, aus dem man kommt ([oeffneGymLog], `AppTarget.aktuell`); das
// Vollbild geht über den Wurzel-Navigator ([oeffneGymVollbild]).
//
// **Unter der Tastatur wird durchgezeichnet statt abgeschnitten**
// (flutter#179482): Das Gerüst verkleinert sich nicht um die Tastatur, der
// Inhalt bekommt unten stattdessen so viel Rand, wie sie hoch ist. Das gehört
// in die Prüfanleitung — ein Widget-Test sieht es nicht.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/symbole.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_log_aufwaermen.dart';
import 'gym_log_ansicht.dart';
import 'gym_log_karte.dart';
import 'gym_log_kopf.dart';
import 'gym_log_leisten.dart';
import 'gym_log_provider.dart';
import 'gym_pause_provider.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_stand.dart';
import 'gym_log_texte.dart';
import 'gym_log_vollbild.dart';

/// Öffnet das Erfassen auf dem Stapel des **aktuell gewählten** Tabs —
/// gerufen aus der Fokus-Karte und der Wochenleiste des Gym-Schirms.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des
/// Tabs, aus dem man kommt, sonst führte „zurück" in ein Menü, das der
/// Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneGymLog(AppRouter router, TrainingKey workout) =>
    router.open(AppTarget.aktuell((_) => GymLogView(workout: workout)));

/// Der ganze geschobene Schirm — mit Gerüst und Navigationsleiste (Zurück,
/// Vollbild-Knopf).
///
/// **Er besorgt seine Daten selbst**: Entwurf und Verlauf aus der Ablage,
/// die Uhr aus `clockProvider`. Aus jedem Tab erreichbar, darf er sich nicht
/// darauf verlassen, dass die Gym-Übersicht vorher geladen hat.
class GymLogView extends ConsumerStatefulWidget {
  const GymLogView({super.key, required this.workout});

  final TrainingKey workout;

  @override
  ConsumerState<GymLogView> createState() => _GymLogViewState();
}

class _GymLogViewState extends ConsumerState<GymLogView> {
  final GymKartenAnsicht _ansicht = GymKartenAnsicht();

  /// Eine Rückfrage steht schon — keine zweite darüber.
  bool _fragt = false;

  TrainingKey get _workout => widget.workout;

  /// Wie das Training in den Rückfragen heißt.
  String get _name =>
      gymTrainingsLabel(_workout, ref.read(gymLogProvider(_workout)).training);

  @override
  void initState() {
    super.initState();
    // Läuft schon ein **anderes** Training, steht das im Stand — und
    // `ref.listen` meldet nur Änderungen, nicht den Stand beim Öffnen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final laufendes = ref.read(gymLogProvider(_workout)).laufendes;
      if (laufendes != null) unawaited(_fragNachLaufendem(laufendes));
    });
  }

  @override
  void dispose() {
    _ansicht.dispose();
    super.dispose();
  }

  GymLogNotifier get _notifier => ref.read(gymLogProvider(_workout).notifier);

  // --- Wege ----------------------------------------------------------------

  Future<void> _oeffneVollbild() async {
    final start = ref.read(gymAktuelleUebungProvider(_workout)) ?? 0;
    // Frisch: erst das Aufwärmen, sonst die Übung, die ansteht. Die einzige
    // Stelle, die das entscheidet.
    //
    // **Eine laufende Pausenuhr zählt als angefangen**, auch wenn noch kein
    // Satz dasteht: Wer die Uhr gestartet hat, ist mitten im Training und
    // will nicht beim Aufwärmen landen. Der Entwurf allein sieht das nicht —
    // die Uhr lebt neben ihm.
    final frisch =
        ref.read(gymLogProvider(_workout)).entwurf.frisch &&
        ref.read(gymPauseProvider) == null;
    final ergebnis = await oeffneGymVollbild(
      context,
      workout: _workout,
      start: start,
      beimAufwaermen: frisch,
    );
    // Das Vollbild ist zu; erst jetzt wird abgelegt (Spec 4.4).
    if (ergebnis == GymVollbildErgebnis.abschliessen && mounted) {
      await _abschliessen();
    }
  }

  /// „Training abschließen": Scheitert das Ablegen, bleibt der Schirm offen
  /// und der Zwischenstand stehen — der Hinweis steht in der Fußleiste
  /// (Tim, 10.11.2026; die alte App löscht den Entwurf trotzdem).
  Future<void> _abschliessen() async {
    final ergebnis = await _notifier.schliesseAb();
    if (ergebnis == GymAbschluss.abgelegt && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// „Training abbrechen": fragt nur nach, wenn schon etwas eingetragen ist
  /// — der Fall „aus Versehen gestartet" soll nicht nachfragen müssen.
  Future<void> _abbrechen() async {
    final stand = ref.read(gymLogProvider(_workout));
    if (stand.entwurf.hatEintraege) {
      final saetze = ref.read(gymFortschrittProvider(_workout)).fertig ?? 0;
      final verwerfen = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          key: kGymVerwerfenFrage,
          title: Text(gymVerwerfenTitel(_name)),
          content: Text(gymVerwerfenText(saetze)),
          actions: [
            CupertinoDialogAction(
              key: kGymVerwerfenWeiter,
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text(gymWeiterTrainieren),
            ),
            CupertinoDialogAction(
              key: kGymVerwerfenBestaetigen,
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text(gymVerwerfen),
            ),
          ],
        ),
      );
      if (verwerfen != true) return;
    }
    await _notifier.verwirf();
    if (mounted) Navigator.of(context).pop();
  }

  /// Ein **anderes** Training läuft (Tim, 10.11.2026: ein Entwurf, nicht
  /// sieben). Die Ablage kennt nur einen; geschrieben wird erst, wenn die
  /// Frage beantwortet ist.
  Future<void> _fragNachLaufendem(GymLaufendes laufendes) async {
    if (_fragt) return;
    _fragt = true;
    final ersetzen = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => CupertinoAlertDialog(
        key: kGymLaufendesFrage,
        title: Text(gymLaufendesTitel(laufendes)),
        content: Text(gymLaufendesText(laufendes, _name)),
        actions: [
          CupertinoDialogAction(
            key: kGymLaufendesWeiter,
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(gymLaufendesWeiter(laufendes)),
          ),
          CupertinoDialogAction(
            key: kGymLaufendesErsetzen,
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(gymLaufendesErsetzen(_name)),
          ),
        ],
      ),
    );
    _fragt = false;
    if (!mounted) return;
    if (ersetzen == true) {
      await _notifier.ersetzeLaufendes();
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- Aufbau --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final workout = _workout;
    final aktuell = ref.watch(gymAktuelleUebungProvider(workout)) ?? 0;
    final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final padding = MediaQuery.paddingOf(context);

    ref.listen<GymLaufendes?>(
      gymLogProvider(workout).select((s) => s.laufendes),
      (_, neu) {
        if (neu != null) unawaited(_fragNachLaufendem(neu));
      },
    );

    // Die Übungen kommen aus dem Entwurf, nicht aus dem Katalog: Bei einem
    // eigenen Training bestimmt das Training Auswahl und Reihenfolge.
    final uebungen = ref.watch(
      gymLogProvider(workout)
          .select((s) => [for (final u in s.entwurf.uebungen) u.id]),
    );

    return PopScope(
      // Beim Verlassen — Zurück-Knopf, Wischgeste, `Navigator.pop` — wird
      // sofort geschrieben, nicht erst nach den 1,5 Sekunden (Spec 9.1
      // Punkt 5).
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_notifier.schreibeSofort());
      },
      child: CupertinoPageScaffold(
        backgroundColor: bg,
        // Unter der Tastatur durchzeichnen statt abschneiden: siehe
        // Dateikopf.
        resizeToAvoidBottomInset: false,
        navigationBar: CupertinoNavigationBar(
          trailing: CupertinoButton(
            key: kGymLogVollbildOeffnen,
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(44),
            // Solange gelesen wird, steht noch nicht fest, bei welcher Übung
            // das Vollbild aufgeht.
            onPressed: laedt ? null : _oeffneVollbild,
            child: Semantics(
              label: 'Vollbild',
              child: Icon(Symbole.aufloesen('expand'), size: 22),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: padding.top),
            GymFortschrittsLeiste(workout: workout),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // Die Tastatur verkleinert nichts; ihr Platz wird Rand, damit
                // sich auch das letzte Feld über sie hochscrollen lässt.
                padding: EdgeInsets.only(
                  bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GymLogKopf(workout: workout),
                    GymEckdaten(workout: workout),
                    GymAufwaermenKarte(workout: workout),
                    for (var i = 0; i < uebungen.length; i++)
                      GymUebungKarte(
                        key: ValueKey('karte-${uebungen[i]}'),
                        workout: workout,
                        uebungId: uebungen[i],
                        nummer: i + 1,
                        aktuell: i == aktuell,
                        ansicht: _ansicht,
                      ),
                    GymAbbrechenZeile(onTap: _abbrechen),
                    const GymFussnote(),
                  ],
                ),
              ),
            ),
            GymAktionsLeiste(
              workout: workout,
              onAbschliessen: _abschliessen,
              onZwischenspeichern: () => unawaited(_notifier.schreibeSofort()),
            ),
            SizedBox(height: padding.bottom),
          ],
        ),
      ),
    );
  }
}
