import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/makro_balken.dart';

import 'support.dart';

/// Tests für `MakroBalken` (Baukasten „Heute, kombiniert", Task H1), nach
/// `macroBar` in `docs/screens/components.js`. Keine Swift-Entsprechung
/// vorhanden — der Entwurf ist neu.
///
/// **Alle Zahlen unten sind erfunden — nicht aus dem Entwurfsboard
/// übernommen.** Das Board behauptet zwar „Zahlen sind erfundene
/// Beispiele", das stimmte an mehreren Stellen aber nicht. Wer es als
/// Vorlage für einen Baustein nimmt, übernimmt seine Zahlen nicht blind.
///
/// Entwurfszitat (`components.js`, `macroBar`): „Über dem Ziel läuft der
/// Balken nicht weiter — er färbt sich um." Genau das ist der Fall, den der
/// Auftrag ausdrücklich nennt — hier mit erfundenen Zahlen nachgebildet
/// (Wert klar über dem Ziel), nicht mit dem Entwurfsbeispiel.
///
/// Wie bei `RingZiel.ersteRunde`/`.zweiteRunde` (siehe `ringe_test.dart`)
/// steckt die Deckelung und die Ueberschreitungs-Erkennung als zwei reine,
/// statische Funktionen auf `MakroBalken` — testbar ohne Widget-Pumping,
/// und genau die Stelle, an der ein Vorzeichenfehler (`>=` statt `>`, oder
/// eine fehlende Deckelung) sonst nur im Simulator auffiele.
///
/// `wert`/`ziel` sind `int` (Gramm) — Nachkommaformatierung ist hier keine
/// Testfrage.
void main() {
  group('MakroBalken.anteil (reine Logik, ohne Widget)', () {
    test('ist 0 bei einem Wert von 0', () {
      expect(MakroBalken.anteil(0, 220), 0);
    });

    test('ist genau 1, wenn der Wert das Ziel genau erreicht', () {
      expect(MakroBalken.anteil(220, 220), 1);
    });

    test('bleibt bei 1 gedeckelt, wenn der Wert das Ziel uebersteigt', () {
      expect(MakroBalken.anteil(90, 40), 1);
    });

    test('ist 0, wenn das Ziel 0 ist, statt durch 0 zu teilen', () {
      expect(MakroBalken.anteil(10, 0), 0);
    });
  });

  group('MakroBalken.ueberZiel (reine Logik, ohne Widget)', () {
    test('ist falsch, wenn der Wert unter dem Ziel liegt', () {
      expect(MakroBalken.ueberZiel(60, 120), isFalse);
    });

    test('ist falsch, wenn der Wert das Ziel genau erreicht — erst das '
        'Ueberschreiten faerbt um, nicht das Erreichen', () {
      expect(MakroBalken.ueberZiel(120, 120), isFalse);
    });

    test('ist wahr, wenn der Wert das Ziel uebersteigt', () {
      expect(MakroBalken.ueberZiel(90, 40), isTrue);
    });
  });

  group('MakroBalken (Widget)', () {
    testWidgets(
      'zeigt Bezeichnung, Einheit sowie Wert und Ziel fuer ein Makro unter '
      'dem Ziel',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const MakroBalken(
              label: 'Eiweiß',
              wert: 150,
              ziel: 220,
              einheit: 'g',
              farbe: CupertinoColors.systemPurple,
            ),
          ),
        );

        expect(find.text('Eiweiß'), findsOneWidget);
        expect(find.textContaining('150'), findsOneWidget);
        expect(find.textContaining('220'), findsOneWidget);
        expect(find.textContaining('g'), findsWidgets);
      },
    );

    testWidgets('baut ohne Fehler, wenn der Wert das Ziel uebersteigt', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const MakroBalken(
            label: 'Fett',
            wert: 90,
            ziel: 40,
            einheit: 'g',
            farbe: CupertinoColors.systemGreen,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(MakroBalken), findsOneWidget);
    });
  });
}
