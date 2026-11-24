// Der Lampenknopf der Kamera (#347) — ein Baustein für beide Modi.
//
// Im Barcode-Modus gab es ihn (`strichcode_leser.dart`, `_Taschenlampe`),
// im KI-Modus fehlte er (Tims Befund vom 04.11.2026: „Blitz fehlt im
// KI-Modus"). Beide Sucher benutzen jetzt `LampenKnopf` aus
// `kamera_bausteine.dart`; welche Kamera dahinter schaltet
// (`mobile_scanner` bzw. `camera` mit `FlashMode.torch`), weiß der Knopf
// nicht. Ob das Gerät eine Lampe hat, entscheidet der Sucher — ohne Lampe
// steht kein Knopf da.
//
// Geprüft werden Zustand und Übergang: Was der Knopf ansagt, und dass ein
// Tipp den Wechsel auslöst.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/ernaehrung/kamera_bausteine.dart';

Future<void> _zeige(
  WidgetTester tester, {
  required bool an,
  VoidCallback? aufWechsel,
}) => tester.pumpWidget(
  CupertinoApp(
    home: Center(
      child: LampenKnopf(an: an, aufWechsel: aufWechsel),
    ),
  ),
);

void main() {
  testWidgets('aus: sagt „einschalten", ein Tipp löst den Wechsel aus', (
    tester,
  ) async {
    var wechsel = 0;
    await _zeige(tester, an: false, aufWechsel: () => wechsel++);

    expect(find.bySemanticsLabel('Taschenlampe einschalten'), findsOneWidget);
    await tester.tap(find.byType(LampenKnopf));
    expect(wechsel, 1);
  });

  testWidgets('an: sagt „ausschalten", ein Tipp löst den Wechsel aus', (
    tester,
  ) async {
    var wechsel = 0;
    await _zeige(tester, an: true, aufWechsel: () => wechsel++);

    expect(find.bySemanticsLabel('Taschenlampe ausschalten'), findsOneWidget);
    await tester.tap(find.byType(LampenKnopf));
    expect(wechsel, 1);
  });

  testWidgets('an und aus haben dieselbe Größe', (tester) async {
    await _zeige(tester, an: false, aufWechsel: () {});
    final aus = tester.getSize(find.byType(LampenKnopf));
    await _zeige(tester, an: true, aufWechsel: () {});
    expect(tester.getSize(find.byType(LampenKnopf)), aus);
  });
}
