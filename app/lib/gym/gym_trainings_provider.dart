// Die Provider der Trainings-Übersicht und der gespeicherten Rotation (#532
// unter #531, Task 1.9): die fertigen Kacheln, der Tag-Filter, das Detail, die
// gewählte Seite der Figur und die Rotation als Daten.
//
// Form und Namen geben `app/test/gym/gym_trainings_provider_test.dart` und
// `gym_trainings_seite_provider_test.dart` verbindlich vor (siehe deren
// Dateiköpfe) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`). Spec: `docs/superpowers/specs/2026-11-19-eigene-trainings-
// design.md`, Abschnitt 6.3 und die Nachträge 23 bis 25.
//
// **Kein `Messwert<T>`** (`CLAUDE.md`, Spec 5.6a): Das sind Tims eigene Daten;
// es gibt keinen Lauf, der leer ausgehen kann. **Und kein `AsyncValue` in der
// Widget-Schicht** — die Brücke ist wie bei `gymTagProvider` ein Werttyp mit
// einem `laedt`, ausgepackt hier, in der Provider-Schicht.
//
// **Wer den Platzhalter braucht, fragt `laedt`, und `laedt` gilt nur, bis
// zum ersten Mal gelesen wurde** (Fehler `01`). Liegt ein Stand vor, bleibt er
// stehen — auch während neu gelesen wird (`hasValue`, nicht `isLoading`) und
// auch, wenn das Nachlesen scheitert. Ein Platzhalter, der bei jedem Zug von
// oben aufblitzt, ist das Flackern, gegen das die Regel gebaut ist. Ein
// **erstes** Lesen, das scheitert, ist „nichts da": Es gibt keine Quelle, die
// etwas erfinden könnte, und kein Stand, den man wegnähme.
//
// **Was ein Provider anbietet, wird gehalten, nicht je Zugriff gerechnet**
// (Hausregel 2, Fehler `03`): Dauer, Muskeln und Zählungen einer Kachel sind
// hier **einmal** gerechnet, wenn die Quelle neu liest, nicht je Bild. Jeder
// Werttyp bringt `==` und `hashCode` über alle Felder mit — Listen und
// `Set<Muscle>` inhaltlich —, damit ein erneutes Lesen mit gleichem Inhalt
// niemanden benachrichtigt.
//
// **Die Invalidierung steht beim Schreiber, nicht im Repository:** Wer
// `speichere`, `loesche` oder `kopiereAlsEigenes` aufruft, sagt es mit
// `ref.invalidate(gymTrainingsQuelleProvider)` (und, wo die Rotation
// betroffen ist, `gymRotationQuelleProvider`) — wie der Erfassen-Schirm bei
// `gymTagProvider`. Die App benutzt keine drift-Streams; dieser Provider führt
// keine ein.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_training_repository.dart';
import '../design/muskel_figur.dart' show MuskelSeite;
import 'gym_entwurf_provider.dart' show gymAblageVerfuegbarProvider;

/// Eine fertig gerechnete Kachel der Übersicht (Spec 6.3).
///
/// **Alles ist gerechnet, die Kachel liest nur Felder.** Eine berechnete
/// Eigenschaft, die je Bild rechnet, wäre `03`.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder**, [tags] in ihrer
/// Reihenfolge (sie ist die der Anzeige), [muscles] als Menge (ohne
/// Reihenfolge).
@immutable
class TrainingKachel {
  const TrainingKachel({
    required this.id,
    required this.name,
    required this.category,
    required this.isDraft,
    required this.minutes,
    required this.minutesEntered,
    required this.exerciseCount,
    required this.setCount,
    required this.tags,
    required this.muscles,
    required this.unknownExerciseCount,
  });

  /// Bei Templates der `Workout.code`, bei Eigenen eine UUID.
  final String id;

  final String name;
  final WorkoutCategory category;

  /// Ein Zwischenstand des Editors — trägt die Entwurfs-Kapsel, ist weder
  /// startbar noch einplanbar.
  final bool isDraft;

  /// Die **wirksame** Dauer in Minuten: die eingetragene, sonst die
  /// Schätzung des Kerns (`WorkoutDuration.effective`). **`null` heißt „keine
  /// Dauer" — ein Training ohne Übung —, nie 0** (Fehler `01`): Die Zeile
  /// zeigt dann „–".
  final int? minutes;

  /// Ob [minutes] eingetragen ist (`true`) oder geschätzt (`false`). Die
  /// Kachel kennzeichnet die Schätzung als solche.
  final bool minutesEntered;

  /// Die Zahl der Einträge in den Übungen — **auch wenn eine ID der Katalog
  /// nicht kennt** (Spec 5.4); die unbekannten zählt [unknownExerciseCount]
  /// eigens.
  final int exerciseCount;

  /// Die Summe der Sätze über alle Einträge.
  final int setCount;

  /// In der Reihenfolge der Anzeige.
  final List<String> tags;

  /// Die trainierten Muskeln, einfarbig gefärbt: Haupt- und Nebenmuskeln
  /// (`WorkoutMuscles.trained`). Das leere Training färbt nichts.
  final Set<Muscle> muscles;

  /// Wie viele Einträge eine Übung nennen, die der Katalog nicht (mehr)
  /// kennt. Sie bleiben im Training, zählen aber weder in der Dauer noch in
  /// den Muskeln (Spec 6.2).
  final int unknownExerciseCount;

  @override
  bool operator ==(Object other) =>
      other is TrainingKachel &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.isDraft == isDraft &&
      other.minutes == minutes &&
      other.minutesEntered == minutesEntered &&
      other.exerciseCount == exerciseCount &&
      other.setCount == setCount &&
      other.unknownExerciseCount == unknownExerciseCount &&
      listEquals(other.tags, tags) &&
      setEquals(other.muscles, muscles);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    isDraft,
    minutes,
    minutesEntered,
    exerciseCount,
    setCount,
    unknownExerciseCount,
    Object.hashAll(tags),
    Object.hashAllUnordered(muscles),
  );

  @override
  String toString() =>
      'TrainingKachel($id, $name, ${category.code}'
      '${isDraft ? ', Entwurf' : ''}, $minutes min, $exerciseCount Übungen)';
}

/// Alles, was die Übersicht zeigt — Templates, Eigene, die Tags des Filters.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder**, Listen in ihrer
/// Reihenfolge (sie ist die der Anzeige).
@immutable
class GymTrainingsStand {
  GymTrainingsStand({
    required this.templates,
    required this.own,
    required this.allTags,
    required this.laedt,
    this.fehlgeschlagen = false,
  });

  /// Noch nichts gelesen — der Platzhalter steht, **nicht** ein „keine
  /// Trainings"-Grund. Siehe [laedt].
  static final GymTrainingsStand wirdGelesen = GymTrainingsStand(
    templates: const [],
    own: const [],
    allTags: const [],
    laedt: true,
  );

  /// Nichts da und nichts zu warten: Es gibt keine Ablage im Baum (Tests ohne
  /// Datenbank).
  static final GymTrainingsStand leer = GymTrainingsStand(
    templates: const [],
    own: const [],
    allTags: const [],
    laedt: false,
  );

  /// Das **erste** Lesen ist gescheitert: nichts da, und nichts zu warten.
  /// Anders als [leer] sagt dieser Stand es — die Übersicht behauptet dann
  /// nicht „noch keine Trainings", wo nur nicht gelesen werden konnte
  /// (Fehler `01`, Spec 7.4).
  static final GymTrainingsStand nichtLesbar = GymTrainingsStand(
    templates: const [],
    own: const [],
    allTags: const [],
    laedt: false,
    fehlgeschlagen: true,
  );

  /// Die lebenden Templates — Tombstones stehen nicht darin.
  final List<TrainingKachel> templates;

  /// Die Eigenen samt Entwürfen, in der Reihenfolge der Ablage.
  final List<TrainingKachel> own;

  /// Die benutzten Tags in der Reihenfolge von `WorkoutTags.suggestions` mit
  /// leerem `current`: absteigend nach Häufigkeit, bei Gleichstand
  /// alphabetisch. Entwürfe zählen, Tombstones nicht.
  final List<String> allTags;

  /// **`true`, solange nichts gelesen wurde — und nur dann.** Ein Stand, der
  /// schon da war, bleibt stehen, auch wenn neu gelesen wird oder das
  /// Nachlesen scheitert.
  final bool laedt;

  /// `true` nur, wenn das **erste** Lesen gescheitert ist und deshalb kein
  /// Stand vorliegt. Ein Stand, der schon da war, bleibt stehen — dann ist
  /// dies `false`, auch wenn das Nachlesen scheitert.
  final bool fehlgeschlagen;

  /// Die fertigen, startbaren Trainings: lebende, **nicht** Entwürfe —
  /// Templates und Eigene. Das ist die Zahl der Gym-Tab-Zeile; sie hängt am
  /// Filter nicht.
  ///
  /// Einmal je Stand gerechnet und gehalten, nicht je Zugriff.
  late final int readyCount =
      templates.where((k) => !k.isDraft).length +
      own.where((k) => !k.isDraft).length;

  @override
  bool operator ==(Object other) =>
      other is GymTrainingsStand &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      listEquals(other.templates, templates) &&
      listEquals(other.own, own) &&
      listEquals(other.allTags, allTags);

  @override
  int get hashCode => Object.hash(
    laedt,
    fehlgeschlagen,
    Object.hashAll(templates),
    Object.hashAll(own),
    Object.hashAll(allTags),
  );

  @override
  String toString() =>
      'GymTrainingsStand(${templates.length} Templates, ${own.length} '
      'Eigene, laedt: $laedt)';
}

/// Die Rotation, wie der Planer sie liest: die Trainings in der Reihenfolge
/// der Plätze (Spec 23, 24).
///
/// **Als [Workout], nicht als Kennung:** Der Planer rechnet über [Workout]
/// (Plan 18), und die Kennung ist `workout.id`. Ein Training ohne Enum-Fall
/// lässt sich hier **nicht** tragen — in dieser Stufe schreibt nur die
/// Einspielung die Rotation, und die nennt nur Enum-Fälle; eine andere
/// Kennung lässt den Provider werfen (Spec 24 Nr. 4).
///
/// **Werttyp mit [==] und [hashCode]**, [workouts] in ihrer Reihenfolge.
@immutable
class GymRotationStand {
  const GymRotationStand({required this.workouts, required this.laedt});

  final List<Workout> workouts;

  /// **`true`, solange nichts gelesen wurde — und nur dann.** Solange es gilt,
  /// zeigt die Wochenleiste den Platzhalter in derselben Geometrie und die
  /// Fokus-Karte nie „Ruhetag" (Fehler `01`); der Inhalt von [workouts] ist
  /// dann ohne Aussage.
  final bool laedt;

  @override
  bool operator ==(Object other) =>
      other is GymRotationStand &&
      other.laedt == laedt &&
      listEquals(other.workouts, workouts);

  @override
  int get hashCode => Object.hash(laedt, Object.hashAll(workouts));

  @override
  String toString() =>
      'GymRotationStand(${workouts.map((w) => w.code).join(', ')}, '
      'laedt: $laedt)';
}

// --- Quellen -----------------------------------------------------------------

/// Die Quelle der Übersicht: alle lebenden Trainings samt Entwürfen. Ziel von
/// `ref.invalidate`, wer schreibt.
///
/// **Ohne die Zwischenstände** an bestehenden Trainings (Spec 27 Nr. 2): Ein
/// Training und sein ungespeicherter Zwischenstand wären zwei Kacheln für
/// dieselbe Sache, und das Speichern schluckte eine davon lautlos. Der
/// Zwischenstand erreicht den Nutzer über „Bearbeiten" am Training. Beide
/// Auskünfte kommen **in einem** Lesen, damit kein Stand entsteht, in dem die
/// eine da ist und die andere noch fehlt.
final gymTrainingsQuelleProvider = FutureProvider<List<WorkoutDefinition>>((
  ref,
) async {
  final repo = ref.watch(gymTrainingRepositoryProvider);
  final alle = await repo.alle();
  final zwischenstaende = await repo.zwischenstandKennungen();
  if (zwischenstaende.isEmpty) return alle;
  return [
    for (final training in alle)
      if (!zwischenstaende.contains(training.id)) training,
  ];
});

/// Die Quelle der Rotation: die Kennungen in der Reihenfolge der Plätze, ohne
/// Entwürfe und ohne Tombstones. Ziel von `ref.invalidate`, wer die Rotation
/// verändert (`loesche`).
final gymRotationQuelleProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(gymTrainingRepositoryProvider).rotation(),
);

// --- Die Übersicht -----------------------------------------------------------

/// Die Übersicht — **gehalten**, nicht bei jedem Zugriff gerechnet.
///
/// Synchron und ohne `AsyncValue` für die Widget-Schicht: Wer liest, bekommt
/// einen Wert, und der Ladezustand steckt in [GymTrainingsStand.laedt].
///
/// **Ohne Ablage im Baum** (Tests ohne Datenbank, siehe
/// `gymAblageVerfuegbarProvider`) ist der Stand leer mit `laedt == false` —
/// ein Lesefehler, der später eintrüfe, ließe sonst jeden abgeleiteten Wert
/// neu rechnen.
final gymTrainingsProvider = Provider<GymTrainingsStand>((ref) {
  if (!ref.watch(gymAblageVerfuegbarProvider)) return GymTrainingsStand.leer;
  final quelle = ref.watch(gymTrainingsQuelleProvider);

  // `hasValue`, nicht `isLoading`: Ein erneutes Lesen behält den letzten
  // Wert, und ein gescheitertes Nachlesen nimmt ihn nicht weg.
  if (!quelle.hasValue) {
    return quelle.hasError
        ? GymTrainingsStand.nichtLesbar
        : GymTrainingsStand.wirdGelesen;
  }
  return _standAus(quelle.requireValue);
});

GymTrainingsStand _standAus(List<WorkoutDefinition> trainings) {
  final templates = <TrainingKachel>[];
  final eigene = <TrainingKachel>[];
  final benutzt = <String, int>{};
  for (final training in trainings) {
    final kachel = kachelAus(training);
    (training.category == WorkoutCategory.template ? templates : eigene).add(
      kachel,
    );
    for (final tag in training.tags) {
      benutzt[tag] = (benutzt[tag] ?? 0) + 1;
    }
  }
  return GymTrainingsStand(
    templates: List.unmodifiable(templates),
    own: List.unmodifiable(eigene),
    allTags: List.unmodifiable(
      WorkoutTags.suggestions(used: benutzt, current: const []),
    ),
    laedt: false,
  );
}

/// Die fertig gerechnete Kachel zu einem Training — **einmal**, wenn die Quelle
/// neu liest, nicht je Bild. Das Detail benutzt dieselbe Rechnung
/// ([gymTrainingDetailProvider]), damit Übersicht und Detail nie
/// verschiedene Dauern oder Muskeln nennen.
TrainingKachel kachelAus(WorkoutDefinition training) {
  var saetze = 0;
  var unbekannt = 0;
  for (final uebung in training.exercises) {
    saetze += uebung.sets;
    if (uebung.resolve() == null) unbekannt++;
  }
  return TrainingKachel(
    id: training.id,
    name: training.name,
    category: training.category,
    isDraft: training.isDraft,
    minutes: WorkoutDuration.effective(
      entered: training.enteredMinutes,
      exercises: training.exercises,
    ),
    minutesEntered: training.enteredMinutes != null,
    exerciseCount: training.exercises.length,
    setCount: saetze,
    tags: List.unmodifiable(training.tags),
    muscles: Set.unmodifiable(WorkoutMuscles.trained(training.exercises)),
    unknownExerciseCount: unbekannt,
  );
}

// --- Der Filter --------------------------------------------------------------

/// Der gewählte Tag der Übersicht; `null` heißt „Alle".
///
/// **Nicht `autoDispose`:** Der Filter überlebt das Schließen der Ansicht
/// (Fehler `32`).
///
/// **Ein Filter, dessen Tag nicht mehr benutzt wird, fällt auf „Alle"
/// zurück** — der Zustand wird zurückgesetzt, nicht nur ignoriert, sonst
/// stünde er beim nächsten Training mit diesem Tag unvermittelt wieder da.
/// Das tut der Notifier selbst, indem er die benutzten Tags beobachtet.
final gymTrainingsFilterProvider =
    NotifierProvider<GymTrainingsFilterNotifier, String?>(
      GymTrainingsFilterNotifier.new,
    );

class GymTrainingsFilterNotifier extends Notifier<String?> {
  @override
  String? build() {
    // `listen` und nicht `watch`: Ein Neuaufbau setzte den Filter bei jedem
    // Lesen zurück. Solange nichts gelesen wurde, weiß niemand, welche Tags
    // es gibt — dann fällt auch nichts zurück.
    ref.listen(gymTrainingsProvider.select((s) => s.laedt ? null : s.allTags), (
      _,
      tags,
    ) {
      final gewaehlt = state;
      if (gewaehlt == null || tags == null) return;
      final schluessel = gewaehlt.toLowerCase();
      if (!tags.any((t) => t.toLowerCase() == schluessel)) state = null;
    });
    return null;
  }

  /// Wählt [tag]; `null` führt auf „Alle" zurück.
  void setze(String? tag) {
    if (state != tag) state = tag;
  }
}

/// Die Übersicht mit angewendetem Filter — der Filter wird **einmal**
/// angewendet und das Ergebnis gehalten, nicht je Bild.
///
/// Filtern heißt: der Tag steht in `tags` (ohne Beachtung der Schreibweise).
/// **Entwürfe mit passendem Tag zählen mit** — sie stehen als Kapsel-Kachel
/// da — und `readyCount` zählt sie nicht. Ohne Filter ist es derselbe Stand.
final gymTrainingsGefiltertProvider = Provider<GymTrainingsStand>((ref) {
  final stand = ref.watch(gymTrainingsProvider);
  final tag = ref.watch(gymTrainingsFilterProvider);
  if (tag == null) return stand;

  final schluessel = tag.toLowerCase();
  bool trifft(TrainingKachel k) =>
      k.tags.any((t) => t.toLowerCase() == schluessel);
  return GymTrainingsStand(
    templates: List.unmodifiable(stand.templates.where(trifft)),
    own: List.unmodifiable(stand.own.where(trifft)),
    allTags: stand.allTags,
    laedt: stand.laedt,
    fehlgeschlagen: stand.fehlgeschlagen,
  );
});

// --- Detail und Seite ----------------------------------------------------------

/// Das Detail je Kennung; `null` heißt: Es gibt dieses Training nicht
/// (mehr) — auch ein Tombstone ist „nicht (mehr) da". Ziel von `ref.invalidate`,
/// wer das Training schreibt.
final gymTrainingProvider = FutureProvider.family<WorkoutDefinition?, String>(
  (ref, id) => ref.watch(gymTrainingRepositoryProvider).training(id),
);

/// Das Detail eines Trainings, **gehalten**: das Training und seine fertig
/// gerechnete [TrainingKachel] (Dauer, Muskeln, Zählungen) — das Detail liest
/// Felder und rechnet nichts je Bild (Fehler `03`).
///
/// Drei Lagen, und keine ist mit einer anderen zu verwechseln:
///
/// - [laedt]: noch nichts gelesen — die Anzeige steht als graue Form da, **nie**
///   „gibt es nicht mehr" (Fehler `01`).
/// - [training] ist `null`, nicht [laedt], nicht [fehlgeschlagen]: gelesen, und
///   es gibt dieses Training nicht (mehr).
/// - [fehlgeschlagen]: das erste Lesen ist gescheitert. Das ist **nicht** „gibt
///   es nicht mehr" — der Schirm sagt es anders.
///
/// Ein gelesener Stand bleibt stehen, auch während neu gelesen wird und wenn
/// das Nachlesen scheitert (`hasValue`, nicht `isLoading`).
///
/// **Werttyp mit [==] und [hashCode]** über alle Felder.
@immutable
class GymTrainingDetailStand {
  const GymTrainingDetailStand({
    required this.laedt,
    this.fehlgeschlagen = false,
    this.training,
    this.kachel,
  });

  final bool laedt;
  final bool fehlgeschlagen;

  /// Das lebende Training, `null` wenn es keines gibt (oder noch nichts
  /// gelesen wurde, siehe [laedt]).
  final WorkoutDefinition? training;

  /// Dauer, Muskeln und Zählungen zu [training].
  final TrainingKachel? kachel;

  @override
  bool operator ==(Object other) =>
      other is GymTrainingDetailStand &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      other.training == training &&
      other.kachel == kachel;

  @override
  int get hashCode => Object.hash(laedt, fehlgeschlagen, training, kachel);
}

/// Das Detail je Kennung als [GymTrainingDetailStand] — gehalten, ohne
/// `AsyncValue` für die Widget-Schicht.
final gymTrainingDetailProvider =
    Provider.family<GymTrainingDetailStand, String>((ref, id) {
      final quelle = ref.watch(gymTrainingProvider(id));
      if (!quelle.hasValue) {
        return quelle.hasError
            ? const GymTrainingDetailStand(laedt: false, fehlgeschlagen: true)
            : const GymTrainingDetailStand(laedt: true);
      }
      final training = quelle.requireValue;
      return GymTrainingDetailStand(
        laedt: false,
        training: training,
        kachel: training == null ? null : kachelAus(training),
      );
    });

/// Die gewählte Seite der Figur je Training; ohne Eintrag **vorne**.
///
/// **Nicht persistiert** über den App-Start (Tim, 19.11.2026, Spec 7.5) und
/// **nicht `autoDispose`**: Sie überlebt das Verlassen der Ansicht und die
/// Navigation (Fehler `32`).
final gymTrainingsSeiteProvider =
    NotifierProvider.family<GymTrainingsSeiteNotifier, MuskelSeite, String>(
      GymTrainingsSeiteNotifier.new,
    );

class GymTrainingsSeiteNotifier extends Notifier<MuskelSeite> {
  GymTrainingsSeiteNotifier(this.trainingId);

  /// Die Kennung des Trainings, dessen Figur gedreht wird.
  final String trainingId;

  @override
  MuskelSeite build() => MuskelSeite.vorne;

  /// Dreht die Figur. Wer die Seite wählt, die schon steht, benachrichtigt
  /// niemanden.
  void setze(MuskelSeite seite) {
    if (state != seite) state = seite;
  }
}

// --- Schreiben -------------------------------------------------------------

/// Wie ein Löschversuch ausgegangen ist.
enum GymLoeschErgebnis {
  /// Das Eigene ist weg. Templates sind nicht löschbar (Spec 26 Nr. 1).
  geloescht,

  /// Das Training läuft gerade in der Erfassung (ein Entwurf trägt es,
  /// Spec 4.7): Die Ablage hat abgelehnt, es ist unverändert da.
  laeuft,

  /// Etwas anderes ist schiefgegangen.
  fehlgeschlagen,
}

/// Die Schreibwege der Übersicht und des Details.
///
/// **Ein Notifier, damit `ref` dort steht, wo es hingehört** (Hausregel 3): Der
/// Schirm ruft nur [loesche] und erfährt das Ergebnis. **Die Invalidierung
/// steht hier beim Schreiber, nicht im Repository** (Spec 6.3): Wer ein
/// Training löscht, sagt es den Quellen — die Übersicht, die Wochenleiste und
/// die Fokus-Karte (über die Rotation) lesen neu.
class GymTrainingsAktionen extends Notifier<void> {
  @override
  void build() {}

  /// Löscht [id]: Ein Eigenes verschwindet und verlässt die Rotation (Spec 24
  /// Nr. 1). Ein Template ist nicht löschbar (Spec 26 Nr. 1); die Oberfläche
  /// bietet es nicht an, die Ablage wirft.
  ///
  /// Gelesen wird danach **neu**, und zwar nur, wenn sich etwas geändert hat —
  /// ein abgelehntes Löschen lässt jeden Stand, wie er war.
  Future<GymLoeschErgebnis> loesche(String id) async {
    try {
      await ref.read(gymTrainingRepositoryProvider).loesche(id);
    } on StateError {
      // Spec 4.7: Das Training läuft in der Erfassung.
      return GymLoeschErgebnis.laeuft;
    } on Object {
      return GymLoeschErgebnis.fehlgeschlagen;
    }
    ref
      ..invalidate(gymTrainingsQuelleProvider)
      ..invalidate(gymRotationQuelleProvider)
      ..invalidate(gymTrainingProvider(id));
    return GymLoeschErgebnis.geloescht;
  }
}

final gymTrainingsAktionenProvider =
    NotifierProvider<GymTrainingsAktionen, void>(GymTrainingsAktionen.new);

// --- Die Rotation --------------------------------------------------------------

/// Die Startrotation als [Workout]: Push, Pull, Legs (Spec 23). Gilt dort, wo
/// keine Ablage im Baum steht, und als Vorgabe von `gymTagAus` — **nicht**
/// `Workout.rotation`, das wären Gym A bis D.
final List<Workout> gymStartRotation = List.unmodifiable([
  for (final id in WorkoutTemplates.initialRotation)
    Workout.fromCode(id) ??
        (throw StateError('Das Start-Template $id hat keinen Enum-Fall')),
]);

/// Die gespeicherte Rotation — **gehalten**, nicht je Zugriff gerechnet.
///
/// - **`laedt`, bis gelesen wurde:** Nie „Ruhetag" beim Laden (Fehler `01`).
/// - **Ein Stand bleibt stehen**, auch während neu gelesen wird und wenn das
///   Nachlesen scheitert. Scheitert schon das **erste** Lesen, ist die
///   Rotation „nichts da": leer mit `laedt == false` — es gibt keine Quelle,
///   die etwas erfinden könnte, und die Startbefüllung zu behaupten hieße zu
///   behaupten, Tim habe sie nie verändert.
/// - **Ohne Ablage im Baum** die Startbefüllung Push, Pull, Legs.
/// - **Eine Kennung ohne Enum-Fall lässt den Provider werfen**, statt sie still
///   zu verwerfen (Spec 24 Nr. 4): In dieser Stufe schreibt nur die
///   Einspielung die Rotation, und die kennt nur Enum-Fälle — alles andere ist
///   ein Programmierfehler, keine Datenlage. Wer eigene Trainings einplanen
///   lässt (#536), ändert den Typ des Standes.
final gymRotationProvider = Provider<GymRotationStand>((ref) {
  if (!ref.watch(gymAblageVerfuegbarProvider)) {
    return GymRotationStand(workouts: gymStartRotation, laedt: false);
  }
  final quelle = ref.watch(gymRotationQuelleProvider);
  if (!quelle.hasValue) {
    return quelle.hasError
        ? const GymRotationStand(workouts: [], laedt: false)
        : const GymRotationStand(workouts: [], laedt: true);
  }
  return GymRotationStand(
    workouts: List.unmodifiable([
      for (final id in quelle.requireValue)
        Workout.fromCode(id) ??
            (throw StateError(
              'Die Rotation nennt ein Training ohne Enum-Fall: $id',
            )),
    ]),
    laedt: false,
  );
});
