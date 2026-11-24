// Der zuletzt benutzte Unterstützungsmodus einer Übung (#78, Spec 13.3).
//
// **Ohne Test:** wie `set_trend.dart` — die Formel fehlte im Kern, und der
// Test von einem zweiten Agenten aus Spec 13.3 steht noch aus.
import 'exercise.dart';
import 'progression.dart';

/// „Der Modus wird fürs nächste Mal übernommen" (`SPEC.md:135`).
abstract final class AssistMode {
  /// Ob die Übung beim nächsten Training mit Unterstützung beginnt.
  ///
  /// [history] hat dieselbe Form wie bei [Progression.suggest]: je Sitzung
  /// die Sätze der Übung, **neueste Sitzung zuerst**.
  ///
  /// Gilt allein die **jüngste** Sitzung — eine ältere überschreibt sie nie.
  /// In ihr entscheidet der letzte Satz mit einem Gewicht ungleich null:
  /// negativ heißt Unterstützung, positiv Zusatzgewicht. Sätze ohne Gewicht
  /// sagen nichts (Körpergewicht), und eine Sitzung ohne jedes Gewicht
  /// sagt es auch nicht — dann gilt wie ohne Verlauf der Vorgabewert
  /// [Exercise.allowsAssist].
  ///
  /// Eine Übung, die keine Unterstützung kennt, bekommt nie welche.
  static bool lastUsed(Exercise exercise, List<List<CompletedSet>> history) {
    if (!exercise.allowsAssist) return false;
    if (history.isEmpty) return exercise.allowsAssist;
    final saetze = history.first;
    for (var i = saetze.length - 1; i >= 0; i--) {
      final gewicht = saetze[i].weight;
      if (gewicht != 0) return gewicht < 0;
    }
    return exercise.allowsAssist;
  }
}
