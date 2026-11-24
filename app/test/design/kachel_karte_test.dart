import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/kachel_karte.dart';
import 'package:repit/design/kacheln.dart';

import 'support.dart';

/// `KachelKarte` (`lib/design/kachel_karte.dart`) — der gemeinsame
/// Kartenbaustein von Home (#376).
///
/// **Tims Entscheidung vom 05.11.2026:** „Alle Karten auf Home bekommen die
/// Ränder wie die Erholung-Karte." Die Erholungskarte trägt seit #299 die
/// Fläche der Kacheln (`kachelFlaeche` in `kacheln.dart`): Grundfarbe
/// `surface`, Radius der Kacheln, **kein Rand**. Diese Datei prüft, dass der
/// Baustein genau diese Fläche trägt und dass die Erholungskarte ihn
/// benutzt — es gibt dann eine Stelle für die Form, nicht eine je Karte.
///
/// Kein Pixeltest: Verglichen wird die `BoxDecoration`, nicht ein Bild.
///
/// Festgelegte API: `const KachelKarte({super.key, required Widget child})`.
void main() {
  testWidgets('zeigt seinen Inhalt', (tester) async {
    await tester.pumpWidget(huelle(const KachelKarte(child: Text('Inhalt'))));

    expect(find.text('Inhalt'), findsOneWidget);
  });

  testWidgets('trägt die Fläche der Kacheln — ohne Rand', (tester) async {
    await tester.pumpWidget(huelle(const KachelKarte(child: Text('Inhalt'))));

    final flaechen = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(KachelKarte),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .toList();
    final erwartet = kachelFlaeche(tester.element(find.byType(KachelKarte)));

    expect(
      flaechen,
      contains(erwartet),
      reason: 'dieselbe Fläche wie Kacheln und Erholungskarte — eine '
          'zweite Fassung driftete auseinander, sobald jemand eine anfasst',
    );
    for (final flaeche in flaechen) {
      expect(
        flaeche.border,
        isNull,
        reason: 'die Erholungskarte hat keinen Rand (#167, #299)',
      );
    }
  });

  testWidgets('die Erholungskarte sitzt auf einer KachelKarte', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(
        const ErholungsKarte(
          ueberschrift: 'Erfunden',
          satz: 'Erfundener Satz.',
          akzent: Color(0xFF000000),
          vitalwerte: [VitalWert(name: 'HRV')],
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ErholungsKarte),
        matching: find.byType(KachelKarte),
      ),
      findsOneWidget,
      reason: 'sie gibt die Form vor — und trägt sie über denselben '
          'Baustein wie die übrigen Home-Karten',
    );
  });
}
