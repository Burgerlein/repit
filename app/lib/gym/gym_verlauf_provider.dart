// Der Verlauf der Gym-Trainings und was der Erfassen-Schirm daraus ableitet
// (#78): der Steigerungsvorschlag je Übung und die Werte vom letzten Mal.
//
// **Kein `Messwert<T>`** (`CLAUDE.md`): Die abgelegten Trainings sind Tims
// eigene Daten. Aber auch hier gilt Spec 9.3: Zwischen dem Öffnen des
// Schirms und dem Eintreffen des Verlaufs liegt ein drift-Lesevorgang, und
// in diesem Moment darf **nicht** „Erstes Mal — taste dich heran" stehen,
// obwohl die Übung schon gemacht wurde. Das wäre eine falsche Auskunft über
// Tims Trainingsverlauf, und sie sähe nicht aus wie ein Ladezustand.
// Deshalb trägt [GymVerlauf] ein Feld, das „noch nicht nachgesehen" von
// „nichts eingetragen" trennt — und [GymVorschlag.vorschlag] ist in diesem
// Moment **`null`**, nicht [FirstTime].
//
// **Gelesen wird einmal je Änderung der Ablage**, nicht je Bild und nicht
// je Taste: [gymSitzungenProvider] liest alle Sitzungen, [gymVerlaufProvider]
// rechnet daraus einmal die Karte, die `Progression.suggest` erwartet.
// Beides ändert sich nur, wenn ein Training abgelegt wird. Wie lange das bei
// einem Jahr Training dauert, ist zu **messen** (Spec 16), nicht zu raten.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart';
import 'gym_provider.dart' show gleicherGymVerlauf, gymVerlaufHash;

/// Alle abgelegten Sitzungen, neueste zuerst.
///
/// Die Quelle von `GymSessionMerge.history` und — später — vom Verlauf
/// (#79). **Wer ein Training ablegt, ruft `ref.invalidate` darauf**
/// (`GymLogNotifier.schliesseAb` tut es); sonst steht der Vorschlag der
/// nächsten Übung auf dem Stand von gestern.
final gymSitzungenProvider = FutureProvider<List<ImportedSession>>(
  (ref) => ref.watch(gymRepositoryProvider).sitzungen(),
);

/// Der Verlauf in der Form, die [Progression.suggest] erwartet: Übungs-ID →
/// Satzlisten, **neueste Sitzung zuerst**.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`). Der
/// Vergleich der Karte ist der von `GymTag` — `gleicherGymVerlauf`, an
/// einer Stelle.
@immutable
class GymVerlauf {
  const GymVerlauf({this.verlauf = const {}})
    : laedt = false,
      fehlgeschlagen = false;

  /// Noch nicht gelesen.
  const GymVerlauf.laedt()
    : laedt = true,
      fehlgeschlagen = false,
      verlauf = const {};

  /// Das Lesen ist gescheitert. **Nicht dasselbe wie „kein Verlauf":**
  /// Ein Vorschlag „Erstes Mal" wäre hier eine Aussage über Daten, die
  /// vielleicht da sind. Der Schirm zeigt keinen Vorschlag.
  const GymVerlauf.fehlgeschlagen()
    : laedt = false,
      fehlgeschlagen = true,
      verlauf = const {};

  /// `true`, solange noch keine Antwort da ist. Nur maßgeblich, wo noch
  /// nichts dasteht: Ein Verlauf, der schon gelesen war, bleibt stehen,
  /// auch während neu gelesen wird (`CLAUDE.md`: der Platzhalter gehört
  /// allein in den Ladezustand).
  final bool laedt;

  final bool fehlgeschlagen;

  /// Leer, wenn es keinen Verlauf gibt **oder** er nicht bekannt ist —
  /// unterscheiden lassen sie sich über [laedt] und [fehlgeschlagen].
  final Map<String, List<List<CompletedSet>>> verlauf;

  /// Ob die Auskunft „Verlauf dieser Übung" belastbar ist.
  bool get bekannt => !laedt && !fehlgeschlagen;

  @override
  bool operator ==(Object other) =>
      other is GymVerlauf &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      gleicherGymVerlauf(other.verlauf, verlauf);

  @override
  int get hashCode =>
      Object.hash(laedt, fehlgeschlagen, gymVerlaufHash(verlauf));

  @override
  String toString() =>
      'GymVerlauf(laedt: $laedt, fehlgeschlagen: $fehlgeschlagen, '
      '${verlauf.length} Übungen)';
}

/// Der Verlauf, **gehalten** (Hausregel 2) und ohne `AsyncValue` für die
/// Ansicht (Hausregel 1).
///
/// Ein Fehler beim Lesen wird **nicht** zu „leer": [GymVerlauf.fehlgeschlagen].
/// Hat schon einmal ein Lesen geklappt und das nächste scheitert, bleibt der
/// letzte Stand stehen — ein gescheiterter Nachlauf nimmt keinen sichtbaren
/// Wert weg.
final gymVerlaufProvider = Provider<GymVerlauf>((ref) {
  final sitzungen = ref.watch(gymSitzungenProvider);
  final liste = sitzungen.value;
  if (liste != null) {
    return GymVerlauf(verlauf: GymSessionMerge.history(liste));
  }
  if (sitzungen.hasError) return const GymVerlauf.fehlgeschlagen();
  return const GymVerlauf.laedt();
});

/// Was der Verlauf über **eine** Übung sagt: der Vorschlag und die Sätze
/// vom letzten Mal.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymVorschlag {
  const GymVorschlag({
    required this.laedt,
    required this.fehlgeschlagen,
    required this.vorschlag,
    required this.hatVerlauf,
    required this.letzteSaetze,
  });

  /// Siehe [GymVerlauf.laedt].
  final bool laedt;

  /// Siehe [GymVerlauf.fehlgeschlagen].
  final bool fehlgeschlagen;

  /// Der Vorschlag aus der Double Progression — **`null`, solange der
  /// Verlauf nicht bekannt ist.** [Progression.suggest] gäbe mit leerem
  /// Verlauf [FirstTime] zurück; hier wird die Frage gar nicht gestellt, wo
  /// die Antwort eine Behauptung wäre. Damit ist „Erstes Mal" während des
  /// Ladens nicht ausdrückbar (Spec 9.3).
  final Suggestion? vorschlag;

  /// Ob es einen Verlauf gibt: Swifts `hasHistory`. Nur wo [vorschlag]
  /// gesetzt ist, eine Auskunft — sonst `false`.
  final bool hatVerlauf;

  /// Die Sätze der **jüngsten** Sitzung dieser Übung, in ihrer Reihenfolge
  /// — die Platzhalter je Satzindex (Spec 3.5, 13.4): Satz 1 zeigt Satz 1
  /// des letzten Trainings. Leer, wenn es keine gibt oder der Verlauf nicht
  /// bekannt ist.
  final List<CompletedSet> letzteSaetze;

  @override
  bool operator ==(Object other) =>
      other is GymVorschlag &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      other.vorschlag == vorschlag &&
      other.hatVerlauf == hatVerlauf &&
      _gleicheSaetze(other.letzteSaetze, letzteSaetze);

  @override
  int get hashCode => Object.hash(
    laedt,
    fehlgeschlagen,
    vorschlag,
    hatVerlauf,
    Object.hashAll(letzteSaetze),
  );

  @override
  String toString() =>
      'GymVorschlag($vorschlag, hatVerlauf: $hatVerlauf, '
      'laedt: $laedt, fehlgeschlagen: $fehlgeschlagen)';
}

/// Der Vorschlag und die letzten Sätze **einer Übung**, gehalten.
///
/// **Der Schlüssel ist die Übung mit dem Bereich des Trainings**
/// (`WorkoutExercise.resolve`, Spec 15.2), nicht die Kennung: Die Progression
/// rechnet gegen den Bereich des Trainings, das gerade gestartet wird, auf
/// dem **übungsweiten** Verlauf (Spec 17 Nr. 20). [Exercise] ist ein
/// Werttyp, zwei gleiche Aufrufe treffen denselben Provider.
///
/// Hängt allein am Verlauf, nicht am Entwurf: Tippen in ein Feld rechnet
/// `Progression.suggest` nicht neu — das lief je Taste siebenmal, wenn der
/// Vorschlag in der Übungskarte gerechnet würde.
final gymVorschlagProvider = Provider.family<GymVorschlag, Exercise>((
  ref,
  uebung,
) {
  final uebungId = uebung.id;
  final verlauf = ref.watch(gymVerlaufProvider);
  if (!verlauf.bekannt) {
    return GymVorschlag(
      laedt: verlauf.laedt,
      fehlgeschlagen: verlauf.fehlgeschlagen,
      vorschlag: null,
      hatVerlauf: false,
      letzteSaetze: const [],
    );
  }
  final historie = verlauf.verlauf[uebungId] ?? const <List<CompletedSet>>[];
  return GymVorschlag(
    laedt: false,
    fehlgeschlagen: false,
    vorschlag: Progression.suggest(uebung, historie),
    // „Ein vorhandener Schlüssel heißt nicht, dass auch Sätze darunter
    // stehen" — geprüft wird auf „nicht leer".
    hatVerlauf: historie.isNotEmpty,
    letzteSaetze: historie.isEmpty ? const [] : historie.first,
  );
});

bool _gleicheSaetze(List<CompletedSet> a, List<CompletedSet> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
