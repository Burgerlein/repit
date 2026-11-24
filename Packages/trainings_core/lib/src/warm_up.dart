// Das Aufwärmen am Trainingsanfang (#40, mitgebaut in #78), Spec
// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
// Abschnitte 10 und 18.

/// Womit aufgewärmt wurde.
///
/// Eine **feste Auswahl statt Freitext** (#40): Vergleichen ist der Zweck —
/// „gleiche Dauer, mehr Kilometer" lässt sich nur über eine Art ablesen, die
/// zweimal dieselbe ist. Freitext hätte „Rad", „Fahrrad" und „Ergometer"
/// nebeneinander.
///
/// Die Fälle tragen **Codes, keine Beschriftungen** (`CLAUDE.md`): „Rad",
/// „Laufband" und die übrigen stehen in der Ansicht. [code] ist dagegen ein
/// Persistenzschlüssel — er landet in der Spalte, die die Migration auf
/// Schema 18 anlegt, und wer ihn ändert, macht alte Einträge namenlos.
enum WarmUpKind {
  bike('bike'),
  treadmill('treadmill'),
  rowing('rowing'),
  crossTrainer('cross_trainer'),
  jumpRope('jump_rope'),
  mobility('mobility');

  const WarmUpKind(this.code);

  /// Der gespeicherte Bezeichner. Ausgeschrieben und nicht aus `name`
  /// abgeleitet — dieselbe Begründung wie bei `Workout.code`: Eine
  /// Umbenennung des Dart-Falls darf den Verlauf nicht mitnehmen.
  final String code;

  /// Die Art zu einem gespeicherten [code], `null` bei unbekanntem.
  ///
  /// Wie `Workout.fromCode`: Unterscheidet Groß- und Kleinschreibung und
  /// rät nicht. Eine stillschweigende Zuordnung schriebe ein fremdes
  /// Aufwärmen in den Verlauf.
  static WarmUpKind? fromCode(String code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// Was zum Aufwärmen eines Trainings eingetragen wurde.
///
/// **Es gibt drei Zustände, nicht zwei** (#40: „‚Übersprungen‘ ist eine
/// Antwort und für den Plan-Agenten brauchbar; ein leeres Feld ist es
/// nicht."):
///
/// - `null` — **nichts eingetragen.** So kommt alles herein, was die
///   Übernahme aus der alten App (#59) bringt; dort gab es kein Feld dafür.
/// - [WarmUpSkipped] — **übersprungen**, eine bewusste Antwort auf eine
///   gestellte Frage.
/// - [WarmUpDone] — **gemacht**, mit Art, Minuten und wo sie etwas heißt
///   der Strecke.
///
/// Wer die ersten beiden verwechselt, rechnet später Durchschnitte über
/// Tage, an denen gar nicht trainiert wurde.
///
/// `sealed` wie `Suggestion` in `progression.dart`: Der `switch` über die
/// Fälle muss vollständig sein, und käme ein dritter dazu, meldet der
/// Analyzer jede Stelle, die ihn nicht behandelt.
sealed class WarmUp {
  const WarmUp();
}

/// Übersprungen — eine gegebene Antwort, kein fehlender Wert.
final class WarmUpSkipped extends WarmUp {
  const WarmUpSkipped();

  @override
  bool operator ==(Object other) => other is WarmUpSkipped;

  @override
  int get hashCode => Object.hash(WarmUpSkipped, 0);

  @override
  String toString() => 'WarmUpSkipped()';
}

/// Gemacht, mit Art und Dauer — und der Strecke, wo es eine gibt.
///
/// Werttyp mit [==] und [hashCode] über alle Felder (`CLAUDE.md`,
/// Fehler `03`): Das Aufwärmen hängt über `ImportedSession` in der
/// Abhängigkeitskette von Riverpod.
final class WarmUpDone extends WarmUp {
  const WarmUpDone({required this.kind, required this.minutes, this.km});

  /// Womit aufgewärmt wurde.
  final WarmUpKind kind;

  /// Die Dauer des Aufwärmens. Sie steht **neben** `ImportedSession.minutes`
  /// und nicht darin — der Kern addiert die beiden nicht, sonst wüchse die
  /// Trainingsdauer, ohne dass mehr trainiert wurde.
  final int minutes;

  /// Zurückgelegte Strecke in Kilometern, `null` wenn es keine gibt oder
  /// keine abgelesen wurde.
  ///
  /// **Echt nullbar, nicht `0`** (`CLAUDE.md`: „`0` ist keine Antwort auf
  /// ‚kein Wert'"). Bei Mobility gibt es keine Strecke, und wer aufs Rad
  /// steigt, ohne die Anzeige abzulesen, ist trotzdem gefahren. `0.0`
  /// behauptete „null Kilometer zurückgelegt" — dasselbe Muster wie
  /// `ImportedSession.minutes`.
  final double? km;

  @override
  bool operator ==(Object other) =>
      other is WarmUpDone &&
      other.kind == kind &&
      other.minutes == minutes &&
      other.km == km;

  @override
  int get hashCode => Object.hash(WarmUpDone, kind, minutes, km);

  @override
  String toString() => 'WarmUpDone(${kind.code}, $minutes min, ${km ?? '–'})';
}
