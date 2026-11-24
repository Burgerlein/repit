// Die 16 Muskelgruppen der Muskelkarte, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Muscle.swift` (#91).

/// Die 16 Muskelgruppen der Muskelkarte mit ihren Zielbereichen in harten
/// Sätzen pro Woche.
///
/// Die Werte stammen aus `docs/SPEC.md` 4.4 und sind **allgemeine
/// Richtwerte** für Muskelaufbau, keine ärztliche Vorgabe. Sie gelten für
/// einen Plan mit Schwerpunkt Oberkörper und Arme; die Beine stehen
/// niedriger, weil sie zusätzlich durchs Laufen belastet werden.
///
/// Die Reihenfolge der Fälle ist die Reihenfolge der Karte und zugleich die
/// natürliche Sortierung überall dort, wo nicht nach Bedarf sortiert wird.
/// Ein Dart-Enum ist über seinen `index` persistierbar — wer die Fälle
/// umstellt, verschiebt gespeicherte Werte.
enum Muscle {
  chest('chest', 'Brust', (low: 10.0, high: 20.0)),
  frontDelt('frontDelt', 'Vordere Schulter', (low: 4.0, high: 12.0)),
  sideDelt('sideDelt', 'Seitliche Schulter', (low: 10.0, high: 20.0)),
  rearDelt('rearDelt', 'Hintere Schulter', (low: 6.0, high: 14.0)),
  biceps('biceps', 'Bizeps', (low: 10.0, high: 20.0)),
  triceps('triceps', 'Trizeps', (low: 10.0, high: 20.0)),
  forearms('forearms', 'Unterarme', (low: 4.0, high: 10.0)),
  upperBack('upperBack', 'Oberer Rücken', (low: 8.0, high: 16.0)),
  lats('lats', 'Latissimus', (low: 10.0, high: 20.0)),
  lowerBack('lowerBack', 'Unterer Rücken', (low: 2.0, high: 8.0)),
  core('core', 'Rumpf', (low: 4.0, high: 10.0)),
  glutes('glutes', 'Gesäß', (low: 6.0, high: 12.0)),
  quads('quads', 'Oberschenkel vorne', (low: 6.0, high: 12.0)),
  hamstrings('hamstrings', 'Oberschenkel hinten', (low: 6.0, high: 12.0)),
  calves('calves', 'Waden', (low: 6.0, high: 14.0)),
  tibialis('tibialis', 'Schienbein', (low: 4.0, high: 10.0));

  const Muscle(this.code, this.german, this.target);

  /// Der gespeicherte Bezeichner, wortgleich mit Swifts `rawValue`.
  ///
  /// Steht ausgeschrieben da und ist **nicht** `name`: Der Code liegt in
  /// gespeicherten Daten und im Dashboard-Export, eine Umbenennung des
  /// Dart-Falls würde ihn sonst lautlos mitnehmen und alte Zuordnungen
  /// namenlos machen.
  final String code;

  /// Der Name auf der Muskelkarte. Fachinhalt des Katalogs, deshalb
  /// deutsch — die ausdrückliche Ausnahme aus `CLAUDE.md`.
  final String german;

  /// Harte Sätze pro Woche, Unter- und Obergrenze.
  ///
  /// Swifts `ClosedRange<Double>` gibt es in Dart nicht; die Spec zu #91
  /// legt dafür den Record `({double low, double high})` fest.
  final ({double low, double high}) target;
}
