// Kopf und Fuß der Erfassung (#78): Titel mit Lede, die zuklappbaren
// Eckdaten, „Training abbrechen" und die Fußnote — `HEADER`, `metaRow`,
// `.discard` und `disclaimer` aus `docs/screens/screens/gym-log.js`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../health/health_provider.dart' show heutigerTagProvider;
import 'gym_log_felder.dart';
import 'gym_log_provider.dart';
import 'gym_log_schluessel.dart';
import 'gym_log_texte.dart';

/// Der Titel und die Lede: „Gym A", darunter „Oberkörper Push + Arme ·
/// 7 Übungen · ca. 70 min".
///
/// **Der Entwurf zeigt hier „Drücken" und „Brust, Schulter, Trizeps +
/// Bizeps"** (abgenommene Abweichung 1, Spec 13.1). Der Kern trägt die
/// neuen Namen noch nicht — `Workout.title` ist noch die Langfassung aus
/// `SPEC.md`, und ein zweites Feld für die Lede gibt es nicht. Bis es das
/// gibt, steht hier, was der Kern hat, statt eines Namens, den die App an
/// anderer Stelle (Gym-Übersicht, Verlauf) nicht kennt.
class GymLogKopf extends ConsumerWidget {
  const GymLogKopf({super.key, required this.workout});

  final TrainingKey workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nur an der Definition: Tippen rechnet hier nichts neu (Hausregel 2).
    final training = ref.watch(
      gymLogProvider(workout).select((s) => s.training),
    );
    final schluessel = workout;
    final uebungen = training == null
        ? 0
        : training.exercises
              .where((e) => ExerciseLibrary.all.containsKey(e.exerciseId))
              .length;
    final kennzahlen = gymKopfKennzahlen(
      uebungen,
      training == null
          ? null
          : WorkoutDuration.effective(
              entered: training.enteredMinutes,
              exercises: training.exercises,
            ),
    );
    return GrosseUeberschrift(
      gymTrainingsLabel(schluessel, training),
      // Ein Enum-Fall nennt wie bisher seinen Langtitel; ein eigenes
      // Training hat keinen — dort stehen nur die Kennzahlen.
      einordnung: schluessel is Workout
          ? '${schluessel.title} · $kennzahlen'
          : kennzahlen,
    );
  }
}

/// „Heute · 70 min · Notiz" — zugeklappt; aufgeklappt Datum, Dauer, Notiz.
///
/// **Jede Änderung löst den Zwischenstand aus**, genau wie eine am Satz
/// (Spec 3.3). Der Tag kommt aus dem Datumswähler und gilt als Berliner
/// Kalendertag; die Uhrzeit bleibt (`GymLogNotifier.setzeDatum`).
class GymEckdaten extends ConsumerWidget {
  const GymEckdaten({super.key, required this.workout});

  final TrainingKey workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ansicht = ref.watch(
      gymLogProvider(workout).select(
        (s) => (
          datum: s.entwurf.datum,
          dauer: s.entwurf.dauer,
          notiz: s.entwurf.notiz,
          laedt: s.laedt,
        ),
      ),
    );
    final heute = ref.watch(heutigerTagProvider);
    final notifier = ref.read(gymLogProvider(workout).notifier);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    final label = TextStyle(fontSize: 15, color: ink);

    return KlappAbschnitt(
      titel: gymEckdatenTitel,
      hinweis: gymEckdatenText(
        datum: ansicht.datum,
        jetzt: heute,
        dauer: ansicht.dauer,
        notiz: ansicht.notiz,
      ),
      kopfSchluessel: kGymEckdaten,
      randAbstand: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      inhalt: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Zeile(
            kind: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: ansicht.laedt
                  ? null
                  : () async {
                      final tag = await _waehleDatum(
                        context,
                        kalendertag(ansicht.datum),
                      );
                      if (tag != null) notifier.setzeDatum(tag);
                    },
              child: Row(
                children: [
                  Expanded(child: Text(gymDatumLabel, style: label)),
                  Text(
                    Format.wochentagUndDatum(kalendertag(ansicht.datum)),
                    style: TextStyle(fontSize: 15, color: river),
                  ),
                ],
              ),
            ),
          ),
          _Zeile(
            kind: Row(
              children: [
                Expanded(child: Text(gymDauerLabel, style: label)),
                SizedBox(
                  width: 70,
                  child: GymFeld(
                    key: kGymEckdatenDauer,
                    wert: ansicht.dauer,
                    onChanged: notifier.setzeDauer,
                    stil: label,
                    tastatur: TextInputType.number,
                    formatierer: [gymZifferFormat],
                    gesperrt: ansicht.laedt,
                    hinweis: '–',
                    hinweisStil: TextStyle(fontSize: 15, color: muted),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  gymDauerEinheit,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
          _Zeile(
            kind: Row(
              children: [
                Text(gymNotizLabel, style: label),
                const SizedBox(width: 14),
                Expanded(
                  child: GymFeld(
                    key: kGymEckdatenNotiz,
                    wert: ansicht.notiz,
                    onChanged: notifier.setzeNotiz,
                    stil: label,
                    tastatur: TextInputType.text,
                    gesperrt: ansicht.laedt,
                    maxZeilen: 3,
                  ),
                ),
              ],
            ),
            letzte: true,
          ),
        ],
      ),
    );
  }

  /// Der Datumswähler; `null`, wenn nichts gewählt wurde. Gewählt wird ein
  /// **Kalendertag** — die Uhrzeit des Trainings bleibt, wie sie war.
  Future<DateTime?> _waehleDatum(BuildContext context, DateTime aktuell) async {
    var gewaehlt = aktuell;
    var geaendert = false;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (blatt) => Container(
        height: 260,
        color: CupertinoDynamicColor.resolve(Palette.bg, blatt),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: aktuell,
            onDateTimeChanged: (wert) {
              gewaehlt = wert;
              geaendert = true;
            },
          ),
        ),
      ),
    );
    return geaendert ? gewaehlt : null;
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({required this.kind, this.letzte = false});

  final Widget kind;
  final bool letzte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: letzte ? 6 : 12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 24),
      child: Align(alignment: Alignment.centerLeft, child: kind),
    ),
  );
}

/// „Training abbrechen" — in `Palette.warn`, unter den Karten. Die
/// Rückfrage stellt der Schirm; hier steht nur der Knopf.
class GymAbbrechenZeile extends StatelessWidget {
  const GymAbbrechenZeile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: GestureDetector(
        key: kGymAbbrechen,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Center(
            child: Text(
              gymAbbrechen,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: warn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Die Fußnote — **ohne den Satz zum Lückenfüller** (Spec 3.7): Er sagte
/// zu, die App prüfe beim nächsten Start, ob die Watch ein Workout in
/// Apple Health abgelegt hat, und das gibt es nicht.
class GymFussnote extends StatelessWidget {
  const GymFussnote({super.key});

  @override
  Widget build(BuildContext context) =>
      const Hinweisfuss(gymFussnote, key: kGymLogFussnote);
}
