// Die Bibliothek aller Übungen (#551, Spec 4.6): die 33 handgeschriebenen
// Anker des Katalogs, die erzeugten Übungen aus dem RepDB-Datensatz und die
// handgeschriebenen Ergänzungen.

import 'exercise.dart';
import 'exercise_catalog.dart';
import 'exercise_library_daten.dart';
import 'muscle.dart';

/// Handgeschriebene Ergänzungen der Bibliothek — Übungen, die weder im
/// Katalog der 33 noch im Datensatz stehen.
///
/// Ihre IDs tragen den Vorsatz `x-`: Der kollidiert nie mit den camelCase-IDs
/// der Anker und nicht mit den Bindestrich-IDs des Datensatzes, und am
/// Verlauf ist ablesbar, dass die Übung von Hand ergänzt wurde. Startet leer
/// (Spec 4.5); eine Kollision mit einer späteren Datensatz-ID fängt
/// [mergeExercises].
abstract final class ExerciseExtras {
  static const List<Exercise> all = [];
}

/// Alle Übungen, die man in ein Training legen kann.
abstract final class ExerciseLibrary {
  /// Alle Übungen, Schlüssel ist die [Exercise.id]: erst die 33 des Katalogs,
  /// dann die erzeugten, dann die handgeschriebenen Ergänzungen. Nicht
  /// veränderbar. Wirft [StateError] mit beiden Quellen im Text, wenn eine ID
  /// zweimal vorkommt — nie wird eine ersetzt.
  static final Map<String, Exercise> all = Map.unmodifiable(
    mergeExercises([
      ExerciseCatalog.all.values,
      generatedExercises,
      ExerciseExtras.all,
    ]),
  );

  /// Die Übung zu [id], `null` bei einer ID, die die Bibliothek nicht führt.
  static Exercise? byId(String id) => all[id];

  /// Ob [id] eine der 33 handgeschriebenen Anker-Übungen des Katalogs ist.
  static bool isCatalog(String id) => ExerciseCatalog.all.containsKey(id);

  static int get length => all.length;

  /// Der Hauptmuskel: höchstes Gewicht; bei Gleichstand der mit dem kleineren
  /// [Muscle.index] (Vorgänger-Spec 9.5). Wirft [StateError] bei leerer
  /// Zuordnung — kein stilles „Rumpf".
  static Muscle mainMuscle(Exercise exercise) {
    Muscle? best;
    for (final entry in exercise.muscles.entries) {
      if (best == null ||
          entry.value > exercise.muscles[best]! ||
          (entry.value == exercise.muscles[best]! &&
              entry.key.index < best.index)) {
        best = entry.key;
      }
    }
    if (best == null) {
      throw StateError(
        'Exercise "${exercise.id}" has no muscles — a main muscle cannot be '
        'derived, and none is invented.',
      );
    }
    return best;
  }

  /// Die Bibliothek nach Hauptmuskel: Gruppen in der Reihenfolge von
  /// [Muscle], leere Gruppen fehlen; darin alphabetisch nach dem gefalteten
  /// Namen ([foldSearchWords] des Namens, Umlaute wie ihr Grundbuchstabe —
  /// „Überzüge" steht unter U). Einmal gerechnet, immer dieselbe Instanz
  /// (Hausregel 2).
  static Map<Muscle, List<Exercise>> get byMainMuscle => _byMainMuscle;

  static final Map<Muscle, List<Exercise>> _byMainMuscle = _groupExercises();

  static Map<Muscle, List<Exercise>> _groupExercises() {
    final groups = <Muscle, List<Exercise>>{};
    for (final exercise in all.values) {
      groups.putIfAbsent(mainMuscle(exercise), () => []).add(exercise);
    }
    String sortKey(Exercise e) => foldSearchWords(e.name).join(' ');
    for (final group in groups.values) {
      group.sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    }
    return Map.unmodifiable({
      for (final muscle in Muscle.values)
        if (groups.containsKey(muscle))
          muscle: List<Exercise>.unmodifiable(groups[muscle]!),
    });
  }

  /// [byMainMuscle] flach: die Reihenfolge, in der [search] Treffer nennt.
  static final List<Exercise> _ordered = List.unmodifiable([
    for (final group in _byMainMuscle.values) ...group,
  ]);

  /// Treffer für [query]: Jedes Wort der Anfrage (gefaltet,
  /// [foldSearchWords]) muss Teilzeichenfolge mindestens eines Suchworts der
  /// Übung sein (`exerciseSearchTerms`). Leere Anfrage (oder nur
  /// Trennzeichen) = alle. Ergebnis in der Reihenfolge von [byMainMuscle]
  /// (Gruppe, dann alphabetisch) — keine Rangfolge nach „Treffergüte".
  ///
  /// Rein: dieselbe Eingabe liefert dieselben Treffer. Der Aufrufer hält das
  /// Ergebnis (Spec 9.4), er ruft es nicht je Bild.
  static List<Exercise> search(String query) {
    final words = foldSearchWords(query);
    return [
      for (final exercise in _ordered)
        if (words.every(
          (word) => _searchTermsFor(exercise).any((t) => t.contains(word)),
        ))
          exercise,
    ];
  }

  /// Suchwörter einer Übung. `exerciseSearchTerms` erzeugt der Generator und
  /// kennt nur Katalog und Erzeugte — eine Übung aus [ExerciseExtras] wäre
  /// sonst ein Null-Check-Crash beim ersten Tastendruck. Für sie trägt der
  /// gefaltete Name.
  static List<String> _searchTermsFor(Exercise exercise) =>
      exerciseSearchTerms[exercise.id] ?? foldSearchWords(exercise.name);
}

/// Vereinigt die [sources] zu einer Map in ihrer Reihenfolge, Schlüssel ist
/// die [Exercise.id]. Wirft [StateError] mit beiden Quellen im Text, sobald
/// eine ID zum zweiten Mal auftaucht — auch innerhalb einer Quelle, auch für
/// dasselbe Objekt: Ersetzt wird nie.
Map<String, Exercise> mergeExercises(List<Iterable<Exercise>> sources) {
  final merged = <String, Exercise>{};
  final origin = <String, int>{};
  for (var i = 0; i < sources.length; i++) {
    for (final exercise in sources[i]) {
      final previous = origin[exercise.id];
      if (previous != null) {
        throw StateError(
          'Duplicate exercise id "${exercise.id}": source $previous and '
          'source $i both carry it — an exercise is never replaced.',
        );
      }
      origin[exercise.id] = i;
      merged[exercise.id] = exercise;
    }
  }
  return merged;
}

/// Kleinbuchstaben, ä→a, ö→o, ü→u, ß→ss, in Wörter zerlegt an allem, was
/// nicht a–z/0–9 ist. Dieselbe Faltung wie `foldSearch` in
/// `exercises-convert.mjs` (dort `normalize('NFD')`), für genau die Zeichen
/// des Datensatzes (Spec 2.5). Für Zeichen außerhalb der Tabelle ist nichts
/// festgelegt; sie wirken als Trennzeichen.
List<String> foldSearchWords(String text) {
  // `toLowerCase` zuerst: Damit deckt die Tabelle Ä, Ö, Ü und ẞ gleich mit.
  final folded = text
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss');
  return [
    for (final word in folded.split(_nonSearchCharacters))
      if (word.isNotEmpty) word,
  ];
}

final RegExp _nonSearchCharacters = RegExp('[^a-z0-9]+');
