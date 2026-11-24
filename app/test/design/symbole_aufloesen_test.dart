import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/symbole.dart';

/// Tests für `Symbole.aufloesen` — die Nachschlagefunktion, die
/// `IconRow` seit der Koordinator-Auflage vom 24.10. statt `tabelle[symbol]`
/// direkt verwendet (siehe Kommentar in `lib/design/symbole.dart`).
///
/// **Warum eine eigene, neue Datei statt einer Ergänzung an
/// `symbole_test.dart`:** `symbole_test.dart` ist eine der sieben
/// gesperrten Testdateien aus Commit `037eaed` (Test-Agent) und bleibt
/// unangetastet. `schriften_test.dart` (von mir, aus der vorigen
/// Nacharbeit) prüft etwas anderes (Unversehrtheit der Schriftdateien
/// selbst). Das Nachschlageverhalten bekommt deshalb eine eigene, dritte
/// Datei — nicht Teil der sieben gesperrten, darf also von mir geschrieben
/// und bei Bedarf weiterentwickelt werden.
///
/// **Der Fehler, gegen den das hier testet:** Ein direkter Zugriff auf
/// `Symbole.tabelle[name]` liefert für einen unbekannten Namen `null`, und
/// `Icon(null, …)` zeichnet daraufhin kommentarlos nichts — kein Fehler,
/// keine Meldung, das Symbol ist einfach weg. Das fiel unter den heute 20
/// getesteten Namen nicht auf, wird aber zum Risiko, sobald ein Aufrufer
/// (ab Task 11 das *Mehr*-Menü) Namen frei eintippt.
void main() {
  test('loest einen bekannten Namen auf dasselbe IconData auf wie die Tabelle', () {
    expect(Symbole.aufloesen('calendar'), Symbole.tabelle['calendar']);
    expect(Symbole.aufloesen('stethoscope'), Symbole.tabelle['stethoscope']);
  });

  test('scheitert laut (assert) bei einem unbekannten Namen, statt still nichts zu liefern', () {
    // `flutter test` läuft mit aktivierten Asserts (wie ein Debug-Build) —
    // genau der Fall, in dem `aufloesen` laut `symbole.dart` hart abbrechen
    // soll, statt den Auslieferungs-Rückfall (Warnzeichen) zu zeigen.
    expect(
      () => Symbole.aufloesen('dieser-name-existiert-nicht'),
      throwsA(isA<AssertionError>()),
    );
  });
}
