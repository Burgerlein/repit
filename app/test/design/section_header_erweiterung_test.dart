import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/section_header.dart';

import 'support.dart';

/// Tests für die Erweiterung von `SectionHeader` um einen rechten Zusatz
/// (Baukasten „Heute, kombiniert", Task H1). `SectionHeader` selbst stammt
/// aus Task 9 (`section_header.dart`, siehe `section_header_test.dart`) —
/// diese Datei kommt **zusätzlich** hinzu, statt die bestehende Testdatei
/// anzufassen (CLAUDE.md: „Bestehende Tests rührst du nicht an"; Auftrag:
/// „Die neun Dateien unter app/test/design/ gehören anderen; leg eigene
/// an").
///
/// Entwurfsgrundlage: `sectionHead(title, link)` in
/// `docs/screens/components.js` — der zweite Parameter steht mal für eine
/// Zahl („3" bei „Heute noch offen"), mal für einen Verweis („Alle ›" bei
/// „Zahlen"). Beide Formen sind für `SectionHeader` dieselbe Sache: ein
/// optionaler Text rechts neben dem Titel, ohne eigenes Antippverhalten —
/// der Entwurf zeichnet `link` als reinen Text (`<a>...</a>` ohne
/// `data-opens`), nicht als Auslöser.
///
/// Die Beispielzahl „3" unten ist eine Zählung von Listenpunkten (UI-Zahl,
/// keine Gesundheitsangabe) — anders als an mehreren anderen Stellen des
/// Entwurfsboards (siehe `ringe_test.dart`, `kacheln_test.dart` u. a.)
/// steckt hier keine von Tims echten Werten dahinter.
void main() {
  testWidgets('zeigt keinen Zusatz, wenn keiner uebergeben wird', (
    tester,
  ) async {
    await tester.pumpWidget(huelle(const SectionHeader('Makros')));

    expect(find.text('3'), findsNothing);
  });

  testWidgets('zeigt eine Zahl als Zusatz, wenn sie uebergeben wird', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(const SectionHeader('Heute noch offen', zusatz: '3')),
    );

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('zeigt einen Verweistext als Zusatz, wenn er uebergeben wird', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(const SectionHeader('Zahlen', zusatz: 'Alle ›')),
    );

    expect(find.text('Alle ›'), findsOneWidget);
  });
}
