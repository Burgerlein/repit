import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/ernaehrung/wasser_bausteine.dart';

/// Tests für **#408 — Wasser in Litern**: `liter(milliliter)` in
/// `lib/ernaehrung/wasser_bausteine.dart`.
///
/// **Beobachtung (Tim, 07.11.2026):** Nach einem Glas von 250 ml stand
/// „0,3 l" da. `liter` rundete auf eine Nachkommastelle.
///
/// **Verlangt:** Liter mit **bis zu zwei** Nachkommastellen, **ohne
/// nachgehängte Null** — „0,25", „1,5", „2,35", „2". Das gilt überall, wo
/// Wasser in Litern steht; beide Stellen (Wasserzeile auf dem Tag-Schirm,
/// „Aus Lebensmitteln" im Blatt) laufen über `liter`.
///
/// **Gerundet wird auf ganze 10 ml, halbe nach oben.** 2345 ml sind
/// „2,35", nicht „2,34": `2.345` ist als `double` knapp kleiner als
/// 2,345, und `toStringAsFixed(2)` rundete dann ab.
///
/// Alle Mengen sind erfundene Rechenwerte.
void main() {
  group('liter', () {
    test('250 ml sind 0,25, nicht 0,3', () {
      expect(liter(250), '0,25');
    });

    test('zwei Nachkommastellen, wo sie gebraucht werden', () {
      expect(liter(2350), '2,35');
      expect(liter(1230), '1,23');
      expect(liter(330), '0,33');
    });

    test('keine nachgehängte Null', () {
      expect(liter(1500), '1,5');
      expect(liter(600), '0,6');
      expect(liter(2000), '2');
      expect(liter(10000), '10');
    });

    test('gerundet auf ganze 10 ml, die Hälfte nach oben', () {
      expect(liter(2345), '2,35');
      expect(liter(1005), '1,01');
      expect(liter(1004), '1');
      expect(liter(999), '1');
    });

    test('nichts ist 0, ohne Komma', () {
      expect(liter(0), '0');
      expect(liter(4), '0');
    });
  });

  testWidgets('„Aus Lebensmitteln" zeigt 250 ml als 0,25 l', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(child: AusEssenZeile(ml: 250)),
      ),
    );

    expect(find.text('0,25 l'), findsOneWidget);
    expect(find.text('0,3 l'), findsNothing);
  });
}
