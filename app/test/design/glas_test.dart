import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/glas.dart';

import 'support.dart';

/// Tests für `Glas` (Task 9, `lib/design/glas.dart`).
///
/// **Was hier bewusst nicht geprüft wird:** die Glasoptik selbst (Blur,
/// Transparenz, Schimmer). Ein Widget-Test befragt den Elementbaum und
/// Eigenschaften, keine gerenderten Pixel — ob `Glas` tatsächlich wie Glas
/// aussieht, lässt sich nur im Simulator beurteilen, nicht hier.
///
/// **Grund für die eigene Datei laut Brief:** Die Glasoptik liegt hinter
/// genau dieser einen Widget-Schicht, weil `liquid_glass_widgets` in 6-12
/// Monaten gegen die offiziellen `cupertino_ui`-Widgets getauscht werden
/// soll und der Umstieg dann nur `glas.dart` betreffen soll. Dieser Test
/// prüft also den Vertrag der Schicht (Kind durchreichen, zwei Stärken,
/// schwächere als Vorgabe), nicht das Paket dahinter.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** Der Brief nennt nur, dass es
/// zwei Stärken gibt und die schwächere die Vorgabe ist, aber keine Namen.
/// Diese Tests nehmen ein Enum `GlasStaerke` mit den Werten `schwach`
/// (Vorgabe) und `stark` an. Passt das nicht zur gewählten Benennung, bitte
/// melden statt die Tests umzubenennen.
void main() {
  testWidgets('reicht sein Kind unveraendert durch', (tester) async {
    await tester.pumpWidget(huelle(const Glas(child: Text('Inhalt'))));

    expect(find.text('Inhalt'), findsOneWidget);
  });

  test('kennt genau zwei Staerken', () {
    expect(GlasStaerke.values, hasLength(2));
  });

  test('die schwaechere Staerke ist die Vorgabe', () {
    const glas = Glas(child: SizedBox());

    expect(glas.staerke, GlasStaerke.schwach);
  });

  testWidgets(
    'laesst sich an dieser einen Stelle auf die staerkere Stufe schalten',
    (tester) async {
      await tester.pumpWidget(
        huelle(const Glas(staerke: GlasStaerke.stark, child: Text('Inhalt'))),
      );

      expect(find.text('Inhalt'), findsOneWidget);
      expect(tester.widget<Glas>(find.byType(Glas)).staerke, GlasStaerke.stark);
    },
  );
}
