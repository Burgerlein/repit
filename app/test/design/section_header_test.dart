import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/section_header.dart';

import 'support.dart';

/// Test für `SectionHeader` (Task 9, `lib/design/section_header.dart`).
///
/// Die Interface-Zeile des Briefs reduziert die Signatur auf
/// `SectionHeader(String)` — ohne den optionalen Link/Aktion-Teil, den
/// `Sources/DesignSystem/InsetList.swift` kennt (`linkTitle`, `action`).
/// Entsprechend bleibt wenig zu prüfen: dass die Komponente den übergebenen
/// Titel überhaupt zeigt. Ob er dabei großgeschrieben wird (wie in Swift via
/// `.uppercased()`), ist Darstellung, nicht Zustand — nach CLAUDE.md werden
/// Beschriftungs-/Layout-Details hier nicht geprüft, deshalb vergleicht
/// dieser Test ohne Rücksicht auf Groß-/Kleinschreibung.
void main() {
  testWidgets('zeigt den uebergebenen Titel', (tester) async {
    await tester.pumpWidget(huelle(const SectionHeader('Ziele')));

    final zeigtTitel = find.byWidgetPredicate(
      (widget) =>
          widget is Text && textOf(widget).toLowerCase().contains('ziele'),
    );
    expect(zeigtTitel, findsOneWidget);
  });
}
