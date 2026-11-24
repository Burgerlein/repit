// Der Zustand des Schirms „Fortschritt pro Übung" (#93): alles, was er zu
// **einer** Übung zeigt, einmal gerechnet und gehalten.
//
// **Kein `Messwert<T>`** (`CLAUDE.md`): Die Trainings sind Tims eigene Daten,
// es gibt keinen Lauf, der leer ausgehen könnte. Aber auch hier gilt: Zwischen
// dem Öffnen und dem Eintreffen der Antwort liegt ein Lesevorgang, und in
// diesem Moment darf **nicht** „noch zu wenige Trainings" und **nicht**
// „Erstes Mal" stehen (Fehler `01`). [GymFortschritt] trägt deshalb `laedt`
// und `fehlgeschlagen`, und `vorschlag` ist in beiden Fällen `null`, nicht
// `FirstTime` — die Frage wird dort gar nicht gestellt.
//
// **Gelesen wird einmal je Änderung der Ablage**, nicht je Bild, nicht je
// Übung: [gymSitzungenProvider] liest alle Sitzungen — dieselbe Liste, an der
// der Steigerungsvorschlag und der Verlauf hängen —, und dieser Provider
// rechnet daraus je Übung Punkte, Plateau und Vorschlag und **hält** sie. Wer
// ein Training ablegt, ruft `ref.invalidate(gymSitzungenProvider)`
// (`GymLogNotifier.schliesseAb` tut es); der Fortschritt liest daraufhin neu
// und hält währenddessen den alten Stand.
//
// **Ein Wechsel der Übung kostet deshalb keinen Lesevorgang.** Die Spec
// (Abschnitt 6) nennt `GymRepository.saetzeDerUebung`, eine Abfrage je
// geöffneter Übung; die liefe an der Invalidierung vorbei und bräuchte eine
// eigene. Die gemeinsame Liste gibt dieselbe Antwort, mit einer Abfrage
// weniger — und bei einer Übung, die noch nie geöffnet war, sofort.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import 'gym_verlauf_provider.dart' show gymSitzungenProvider;

/// Alles, was der Schirm zu **einer** Übung zeigt.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`): Er ist
/// die Abhängigkeit, an der die Ansicht hängt. Ohne Wertgleichheit wäre jedes
/// neu gelesene Ergebnis ungleich dem vorigen, und alles, was daran hängt,
/// rechnete bei jedem Neulesen neu.
@immutable
class GymFortschritt {
  const GymFortschritt({
    required this.uebung,
    required this.laedt,
    required this.fehlgeschlagen,
    required this.reihe,
    required this.plateau,
    required this.vorschlag,
  });

  final Exercise uebung;

  /// Noch keine Antwort der Ablage. Nur maßgeblich, wo noch nichts dasteht:
  /// Ein Stand, der schon da war, bleibt stehen, auch während neu gelesen wird
  /// (`CLAUDE.md`: Der Platzhalter gehört allein in den Ladezustand).
  final bool laedt;

  /// Das Lesen ist gescheitert. **Nicht dasselbe wie „keine Trainings"** —
  /// es stehen vielleicht vier in der Ablage, sie ließen sich nur nicht lesen.
  final bool fehlgeschlagen;

  /// [ExerciseProgress.points] — roh, **nicht verdichtet**. Verdichtet wird
  /// im `Zeitdiagramm`; zwei Fassungen derselben Verdichtung liefen beim
  /// nächsten Umbau auseinander.
  final List<ProgressPoint> reihe;

  /// [OneRepMax.isPlateau] über die Trainings dieser Übung. Eine Beobachtung
  /// über die Einträge, keine Beurteilung.
  final bool plateau;

  /// `null`, solange nicht bekannt — beim Laden und beim Scheitern.
  final Suggestion? vorschlag;

  /// Ob die Auskunft über diese Übung belastbar ist.
  bool get bekannt => !laedt && !fehlgeschlagen;

  @override
  bool operator ==(Object other) =>
      other is GymFortschritt &&
      other.uebung == uebung &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      other.plateau == plateau &&
      other.vorschlag == vorschlag &&
      listEquals(other.reihe, reihe);

  @override
  int get hashCode => Object.hash(
    uebung,
    laedt,
    fehlgeschlagen,
    plateau,
    vorschlag,
    Object.hashAll(reihe),
  );

  @override
  String toString() =>
      'GymFortschritt(${uebung.id}, laedt: $laedt, '
      'fehlgeschlagen: $fehlgeschlagen, ${reihe.length} Punkte, '
      'plateau: $plateau, $vorschlag)';
}

/// Die Übungen, die das Auswahlmenü des Schirms anbietet (#551, Nachtrag 17
/// Nr. 4): **ausschließlich Übungen mit mindestens einem Satz im Verlauf**,
/// Anker und Bibliothek gleich behandelt, sortiert nach dem **gefalteten**
/// Namen („Überzüge" nicht hinter „Z").
///
/// **Werttyp mit [==] und [hashCode]** (Fehler `03`), gehalten im Provider
/// darunter. [bekannt] unterscheidet „die Ablage hat geantwortet, es gibt
/// nichts" von „noch keine Antwort" — nur im ersten Fall darf das Menü einen
/// Leerzustand behaupten (Fehler `01`).
@immutable
class GymFortschrittUebungen {
  const GymFortschrittUebungen({required this.bekannt, required this.ids});

  /// Ob die Liste aus einer Antwort der Ablage stammt. `false` heißt „noch
  /// keine Antwort" — nicht „keine Übungen".
  final bool bekannt;

  /// Die IDs mit Verlauf, nach gefaltetem Namen sortiert. Eine ID, die auch
  /// die Bibliothek nicht kennt (Import einer anderen App-Fassung), steht
  /// nicht drin: Sie hätte im Menü keinen Namen, und der Schirm könnte sie
  /// nicht zeigen (`gymFortschrittProvider` wirft, Spec 8.4).
  final List<String> ids;

  @override
  bool operator ==(Object other) =>
      other is GymFortschrittUebungen &&
      other.bekannt == bekannt &&
      listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(bekannt, Object.hashAll(ids));

  @override
  String toString() =>
      'GymFortschrittUebungen(bekannt: $bekannt, ${ids.length} Übungen)';
}

/// Die Menüquelle, **gehalten** (Hausregel 2) und ohne `AsyncValue` für die
/// Ansicht (Hausregel 1): Gerechnet wird je Änderung der Ablage
/// ([gymSitzungenProvider]), nicht je Öffnen des Menüs. Ein gescheiterter
/// Nachlauf nimmt keinen Eintrag weg — `AsyncValue.value` hält den letzten
/// gelesenen Stand.
final gymFortschrittUebungenProvider = Provider<GymFortschrittUebungen>((ref) {
  final sitzungen = ref.watch(gymSitzungenProvider);
  final liste = sitzungen.value;
  if (liste == null) {
    return const GymFortschrittUebungen(bekannt: false, ids: []);
  }

  final mitSatz = <String>{
    for (final s in liste)
      for (final e in s.exercises)
        if (e.sets.isNotEmpty) e.exerciseId,
  };
  // Schlüssel einmal je Übung falten, nicht je Vergleich.
  final sortKeys = {
    for (final id in mitSatz)
      if (ExerciseLibrary.all.containsKey(id))
        id: foldSearchWords(ExerciseLibrary.byId(id)!.name).join(' '),
  };
  final ids = sortKeys.keys.toList()
    ..sort((a, b) => sortKeys[a]!.compareTo(sortKeys[b]!));
  return GymFortschrittUebungen(bekannt: true, ids: List.unmodifiable(ids));
});

/// Die zuletzt gezeigte Übung des Schirms — **überlebt das
/// Zurücknavigieren** (Fehler `32`): Die Auswahl ist Bedienzustand, aber
/// einer, der wiederkommen muss; im State der Ansicht stürbe er mit der
/// Seite. `null`, solange nie gewählt wurde.
final gymFortschrittZuletztProvider =
    NotifierProvider<GymFortschrittZuletzt, String?>(
      GymFortschrittZuletzt.new,
    );

class GymFortschrittZuletzt extends Notifier<String?> {
  @override
  String? build() => null;

  void merke(String uebungId) => state = uebungId;
}

/// Der Fortschritt **einer** Übung, gehalten (Hausregel 2) und ohne
/// `AsyncValue` für die Ansicht (Hausregel 1).
///
/// Nicht `autoDispose`: Was dastand, steht nach dem Zurücknavigieren wieder da
/// (Fehler `32`). Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert
/// weg — hat schon einmal ein Lesen geklappt, bleibt dieser Stand stehen.
///
/// Eine Übung, die auch die Bibliothek nicht kennt, gibt es nicht; der Aufruf ist
/// dann ein Programmierfehler und wirft, wie bei `gymVorschlagProvider`.
final gymFortschrittProvider = Provider.family<GymFortschritt, String>((
  ref,
  uebungId,
) {
  final uebung = ExerciseLibrary.byId(uebungId);
  if (uebung == null) {
    throw ArgumentError.value(uebungId, 'uebungId', 'nicht in der Bibliothek');
  }

  final sitzungen = ref.watch(gymSitzungenProvider);
  final liste = sitzungen.value;
  if (liste == null) {
    // Ein Wiederholen nach einem Fehler heißt wieder „lädt": graue Formen
    // zeigen, dass etwas passiert, statt den alten Fehler stehen zu lassen.
    return GymFortschritt(
      uebung: uebung,
      laedt: sitzungen.isLoading || !sitzungen.hasError,
      fehlgeschlagen: !sitzungen.isLoading && sitzungen.hasError,
      reihe: const [],
      plateau: false,
      vorschlag: null,
    );
  }

  // Nur die Trainings, in denen die Übung vorkam — neueste zuerst, wie die
  // Ablage sie liefert; `GymSessionMerge.history` sortiert selbst.
  final mitUebung = [
    for (final s in liste)
      if (s.exercises.any((e) => e.exerciseId == uebungId)) s,
  ];
  final historie =
      GymSessionMerge.history(mitUebung)[uebungId] ??
      const <List<CompletedSet>>[];

  return GymFortschritt(
    uebung: uebung,
    laedt: false,
    fehlgeschlagen: false,
    reihe: ExerciseProgress.points(
      exercise: uebung,
      sessions: [
        for (final s in mitUebung)
          ExerciseSession(
            date: s.date,
            sets: [
              for (final e in s.exercises)
                if (e.exerciseId == uebungId) ...e.sets,
            ],
          ),
      ],
    ),
    plateau: OneRepMax.isPlateau(historie),
    // **Sitzungen, nicht Tage:** Zwei Trainings am selben Tag sind zwei für
    // den Vorschlag und das Plateau, aber ein Punkt im Diagramm.
    vorschlag: Progression.suggest(uebung, historie),
  );
});
