// Workout und Übung, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Exercise.swift` (#91).

import 'muscle.dart';
import 'training_key.dart';

/// Die Workouts aus `docs/SPEC.md` 4.4.
///
/// Sie zerfallen in zwei Gruppen, und die Trennung trägt die Logik des
/// Gym-Tabs: [rotation] bekommt Wochentage, Fristen und Plätze in der
/// Wochenleiste, [freelyChosen] nichts davon.
enum Workout implements TrainingKey {
  a('A', 'Oberkörper Push + Arme', 70),
  b('B', 'Läufer-Kraft + Brust', 65),
  c('C', 'Oberkörper Pull + Arme', 70),
  d('D', 'Arme + Schultern', 60),
  push('Push', 'Brust, Schultern, Trizeps', 70),
  pull('Pull', 'Rücken, hintere Schulter, Bizeps', 70),
  legs('Legs', 'Beine komplett', 60);

  const Workout(this.code, this.title, this.minutes);

  /// Der gespeicherte Bezeichner, wortgleich mit Swifts `rawValue`.
  ///
  /// Steht im Verlauf und im Dashboard-Export, deshalb ausgeschrieben und
  /// nicht aus `name` abgeleitet: `name` ist `a`, der gespeicherte Wert ist
  /// `'A'`, und eine Umbenennung des Dart-Falls darf den Verlauf nicht
  /// mitnehmen.
  final String code;

  /// Woraus das Workout besteht. Nennt den Namen bewusst **nicht** noch
  /// einmal — die Ansichten setzen überall `'$label — $title'` zusammen.
  final String title;

  /// Ungefähre Dauer in Minuten.
  final int minutes;

  /// Die Kennung als [TrainingKey]: derselbe Wert wie [code].
  ///
  /// `code` bleibt der gespeicherte Bezeichner, auf den sich Verlauf und
  /// Export verlassen; [id] ist nur der Name, unter dem die Schnittstelle
  /// ihn kennt.
  @override
  String get id => code;

  /// Die Workouts der geplanten Wochenrotation. Nur diese bekommen einen
  /// Platz in der Wochenleiste und können „heute" oder überfällig werden.
  static const List<Workout> rotation = [a, b, c, d];

  /// Workouts ohne festen Tag, die man sich nimmt, wenn Zeit ist.
  ///
  /// Bewusst **neben** der Rotation und nicht in ihr: Ein Platz in der
  /// Woche, der nie fällig wird, wäre eine Kachel, die dauerhaft „offen"
  /// sagt — und nach drei Wochen glaubt man ihr nicht mehr.
  static const List<Workout> freelyChosen = [push, pull, legs];

  /// Wie die Ansicht das Workout benennt. „Gym A" trägt den Buchstaben
  /// allein nicht — „Push" dagegen schon, und „Gym Push" läse sich falsch.
  String get label => rotation.contains(this) ? 'Gym $code' : code;

  /// Das Workout zu einem gespeicherten [code], `null` bei unbekanntem.
  ///
  /// Die Entsprechung zu Swifts `init?(rawValue:)`. Unterscheidet Groß- und
  /// Kleinschreibung: `'A'` ist der gespeicherte Wert, `'a'` der Name des
  /// Dart-Falls — würden beide gelten, wäre nicht mehr entscheidbar, welcher
  /// von beiden geschrieben wurde. Geraten wird nicht: Eine stillschweigende
  /// Zuordnung schriebe ein fremdes Workout in den Verlauf.
  static Workout? fromCode(String code) {
    for (final workout in values) {
      if (workout.code == code) return workout;
    }
    return null;
  }
}

/// Eine Übung des Katalogs: Vorgabe, Technik-Hinweis und Muskelzuordnung.
///
/// Werttyp mit [==] und [hashCode] über **alle** Felder (`CLAUDE.md`,
/// Fehler `03`). Swift bekommt beides synthetisiert, Dart nicht — und Darts
/// `==` auf `List` und `Map` ist Identität, nicht Inhalt. Ohne inhaltlichen
/// Vergleich wäre jede neu gebaute Übung ungleich der vorigen, und jeder
/// abgeleitete Riverpod-Wert, der eine Übung als Abhängigkeit führt, liefe
/// bei jedem Neubau neu.
final class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.repLow,
    required this.repHigh,
    required this.increment,
    this.isTimed = false,
    this.allowsAssist = false,
    required this.cue,
    required this.howTo,
    this.commonMistake,
    this.tips = const [],
    required this.youTubeQuery,
    required this.muscles,
  });

  /// Der Schlüssel im gespeicherten Verlauf. Bleibt, auch wenn [name] sich
  /// ändert — `tibialisRaise` heißt längst „Zehenheben an der Wand".
  final String id;

  final String name;
  final int sets;
  final int repLow;
  final int repHigh;

  /// Schrittweite in kg; bei Zeitübungen ([isTimed]) in Sekunden.
  final double increment;

  /// Sekunden statt Wiederholungen — betrifft nur den Seitstütz.
  final bool isTimed;

  /// Umschalter Zusatzgewicht/Unterstützung. Unterstützung wird negativ
  /// gespeichert: −27 bedeutet 27 kg Hilfe von der Maschine.
  final bool allowsAssist;

  final String cue;

  /// Die Schritte der Anleitung, **in dieser Reihenfolge** — Schritt 1 kommt
  /// vor Schritt 2, deshalb geht die Reihenfolge in [==] ein.
  ///
  /// Die 33 handgeschriebenen Übungen des Katalogs haben genau drei Schritte
  /// (der Test über den Katalog erzwingt das für sie); die Bibliothek aus dem
  /// Datensatz hat 1 bis 7. Hier erzwungen wird keine Zahl.
  final List<String> howTo;

  /// Der häufigste Fehler; `null` heißt „für diese Übung ist keiner
  /// hinterlegt". Der Datensatz nennt keinen, und es wird keiner erfunden.
  final String? commonMistake;

  /// Weitere Hinweise neben [cue], **in dieser Reihenfolge** — die
  /// Reihenfolge geht in [==] ein. Leer bei den handgeschriebenen Übungen.
  final List<String> tips;
  final String youTubeQuery;

  /// Wie stark die Übung welchen Muskel trifft: 1,0 ist der Hauptmuskel,
  /// 0,5 eine Nebenbelastung.
  ///
  /// **Die Gewichte sind keine Ja/Nein-Angabe.** Daraus rechnet die
  /// Muskelkarte ihre harten Sätze pro Woche; wer sie vereinfacht, merkt es
  /// erst dort. Eine Map ist ungeordnet, deshalb entscheidet die
  /// Schreibreihenfolge in [==] nicht mit.
  final Map<Muscle, double> muscles;

  /// Adresse der YouTube-Suche. Die App bettet nichts ein, sie öffnet nur.
  ///
  /// Anders als in Swift nicht optional: Dort kann `URLComponents(string:)`
  /// scheitern, Darts [Uri]-Konstruktor kann das nicht (Spec zu #91,
  /// Abweichung 5). Die Kodierung von Leerzeichen und Umlauten übernimmt
  /// [Uri] — ein von Hand zusammengesetzter String zeigte sonst auf eine
  /// andere Suche als die, die danebensteht.
  ///
  /// **Die Adresse ist nicht zeichengleich mit der der Swift-Fassung:**
  /// [Uri] schreibt das Leerzeichen als `+`, `URLComponents` als `%20`.
  /// YouTube liest beides als dieselbe Suche. Wer die beiden Fassungen
  /// jemals als Zeichenkette vergleicht, vergleicht das Falsche.
  Uri get youTubeSearchUrl => Uri(
    scheme: 'https',
    host: 'www.youtube.com',
    path: '/results',
    queryParameters: {'search_query': youTubeQuery},
  );

  /// Dieselbe Übung mit den Sätzen, dem Wiederholungsbereich und der
  /// Schrittweite eines **Trainings** statt denen des Katalogs.
  ///
  /// Alle übrigen Felder bleiben die des Katalogs. Die Methode steht hier,
  /// neben den Feldern: Käme ein Feld dazu, vergäße ein Aufrufer, es
  /// mitzunehmen — hier fällt es beim Ergänzen des Konstruktors auf.
  Exercise withPlan({
    required int sets,
    required int repLow,
    required int repHigh,
    required double increment,
  }) => Exercise(
    id: id,
    name: name,
    sets: sets,
    repLow: repLow,
    repHigh: repHigh,
    increment: increment,
    isTimed: isTimed,
    allowsAssist: allowsAssist,
    cue: cue,
    howTo: howTo,
    commonMistake: commonMistake,
    tips: tips,
    youTubeQuery: youTubeQuery,
    muscles: muscles,
  );

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.id == id &&
      other.name == name &&
      other.sets == sets &&
      other.repLow == repLow &&
      other.repHigh == repHigh &&
      other.increment == increment &&
      other.isTimed == isTimed &&
      other.allowsAssist == allowsAssist &&
      other.cue == cue &&
      _gleicheSchritte(other.howTo, howTo) &&
      other.commonMistake == commonMistake &&
      _gleicheSchritte(other.tips, tips) &&
      other.youTubeQuery == youTubeQuery &&
      _gleicheGewichte(other.muscles, muscles);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sets,
    repLow,
    repHigh,
    increment,
    isTimed,
    allowsAssist,
    cue,
    Object.hashAll(howTo),
    commonMistake,
    Object.hashAll(tips),
    youTubeQuery,
    _gewichteHash(muscles),
  );

  @override
  String toString() => 'Exercise($id)';
}

/// Inhaltlicher Vergleich zweier Textlisten (Anleitung, Tipps) — die
/// Reihenfolge zählt.
bool _gleicheSchritte(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Inhaltlicher Vergleich zweier Muskelzuordnungen — die Reihenfolge zählt
/// nicht, ein fehlender Eintrag schon.
bool _gleicheGewichte(Map<Muscle, double> a, Map<Muscle, double> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final eintrag in a.entries) {
    final anderer = b[eintrag.key];
    if (anderer == null || anderer != eintrag.value) return false;
  }
  return true;
}

/// Hash über die Muskelzuordnung, unabhängig von der Schreibreihenfolge.
///
/// Sortiert nach [Muscle.index], statt die Einträge zu verodern: Gleiche
/// Zuordnungen müssen denselben Hash bekommen, sonst fielen zwei gleiche
/// Übungen in einer Menge nicht zusammen.
int _gewichteHash(Map<Muscle, double> muscles) {
  final eintraege = muscles.entries.toList()
    ..sort((x, y) => x.key.index.compareTo(y.key.index));
  return Object.hashAll([
    for (final eintrag in eintraege) ...[eintrag.key, eintrag.value],
  ]);
}
