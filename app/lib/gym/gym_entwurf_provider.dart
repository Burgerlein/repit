// Das laufende Training, wie es der Gym-Übersichtsschirm braucht (#78): ein
// `GymDraft` für `GymDayPlanner.day` — damit die Fokus-Karte „Weiter
// eintragen" zeigen kann, sobald ein Training angefangen ist.
//
// **Gelesen wird die Ablage, nicht der Notifier des Erfassen-Schirms:** Die
// Übersicht muss auch nach einem Neustart wissen, dass etwas läuft, bevor
// jemand das Erfassen geöffnet hat. Der Notifier ruft nach jedem
// Schreiben, Verwerfen und Abschließen `ref.invalidate` auf diesen
// Provider (`GymLogNotifier`); sonst stünde die Karte auf dem Stand von
// vorhin.
//
// **Eine Übung zählt, wenn jede ihrer Zeilen zählt** — der Kern kennt
// `GymDraft.doneExercises`. Tim hat am 10.11.2026 entschieden, dass der
// Fortschritt Sätze zählt (#26); im Erfassen-Schirm tut er das. Dass auch
// `GymDraft` im Kern auf Sätze umzustellen ist, ist **noch nicht passiert**,
// und bis dahin zeigt die Fokus-Karte Übungen — dasselbe Wort wie ihr
// Fußzeilenindex („Als Nächstes: Übung n"), der an derselben Zahl hängt.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart';
import '../data/gym_training_repository.dart';
import 'gym_log_entwurf.dart';

/// Der laufende Entwurf als `GymDraft`, `null` wenn keiner läuft **oder er
/// sich nicht lesen lässt** (den Fall meldet der Erfassen-Schirm, wenn man
/// ihn öffnet — hier gäbe es keinen Platz, es zu sagen).
///
/// **Ein laufendes eigenes Training ist sichtbar** (Spec 27 Nr. 4): Der
/// Entwurf trägt dann die Kennung und den Namen des Trainings statt eines
/// Enum-Falls — ein Training darf nicht unsichtbar sein, nur weil es keinen
/// Enum-Fall hat. Der Name wird beim Lesen aus der Zeile geholt; gibt es sie
/// nicht (mehr), zählt der Entwurf mit den Übungen, die die Ablage führt,
/// und ohne Namen.
final gymEntwurfProvider = FutureProvider<GymDraft?>((ref) async {
  final ablage = await ref.watch(gymRepositoryProvider).entwurf();
  if (ablage == null) return null;

  WorkoutDefinition? definition;
  final kennung = ablage.trainingId;
  if (kennung != null) {
    definition = await ref
        .watch(gymTrainingRepositoryProvider)
        .trainingAuchGeloescht(kennung);
  }
  final entwurf = GymLogEntwurf.ausAblage(ablage, definition: definition);
  if (entwurf == null) return null;
  return GymDraft(
    workout: entwurf.workout,
    trainingId: entwurf.trainingId,
    trainingName: definition?.name,
    doneExercises: entwurf.uebungen.where(GymLogEntwurf.uebungErledigt).length,
    totalExercises: entwurf.uebungen.length,
  );
});

/// Ob es eine Ablage gibt, aus der der Gym-Tab lesen kann.
///
/// In der App ist `appCacheProvider` immer überschrieben (`main.dart`). Wo
/// er es nicht ist — ein Test, der allein die Kette `heutigerTagProvider` →
/// `gymTagProvider` prüft —, wirft schon das Anlegen der Ablage; ohne dieses
/// Tor stünde dort ein Lesefehler, der später eintrifft und den Tageszustand
/// neu rechnen ließe. Ohne Ablage ist der Tag ehrlich leer: nichts da,
/// nichts zu lesen.
final gymAblageVerfuegbarProvider = Provider<bool>((ref) {
  try {
    ref.watch(gymRepositoryProvider);
    return true;
  } on Object {
    return false;
  }
});
