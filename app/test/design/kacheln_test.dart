import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/kacheln.dart';

import 'support.dart';

/// Tests für `Kacheln`, `KachelWert` und `Verlaufslinie` (Baukasten „Heute,
/// kombiniert", Task H1), nach `tiles`/`spark` in
/// `docs/screens/components.js` und `HighlightTile`/`Sparkline` in
/// `Sources/DesignSystem/HighlightTile.swift`.
///
/// **Alle Zahlen unten sind erfunden — nicht aus dem Entwurfsboard
/// übernommen.** Das Board behauptet zwar „Zahlen sind erfundene
/// Beispiele", das stimmte an mehreren Stellen aber nicht. Wer es als
/// Vorlage für einen Baustein nimmt, übernimmt seine Zahlen nicht blind.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** Die Tabelle des Auftrags
/// nennt den Baustein im Plural (`Kacheln`, Entwurfsfunktion `tiles`, die
/// ebenfalls eine ganze Liste entgegennimmt und selbst nebeneinander legt
/// — anders als `IconRow`, das eine einzelne Zeile ist und dessen Liste der
/// Schirm selbst zusammensetzt). `Kacheln` nimmt deshalb `List<KachelWert>`
/// entgegen, nicht einen einzelnen Wert.
///
/// Die Verlaufslinie (`Sparkline` in Swift, `spark()` im Entwurf) ist als
/// eigener, oeffentlicher Baustein `Verlaufslinie` herausgezogen, nicht
/// Implementierungsdetail von `Kacheln`: Nur so laesst sich von außen
/// pruefen, ob sie bei fehlender Reihe weggelassen wird, ohne Annahmen über
/// die Zeichentechnik (`CustomPainter` o. ä.) zu treffen.
///
/// Schwerpunkt laut Auftrag: „Was zeigt eine Kachel ohne Verlaufsreihe?" —
/// das ist keine hypothetische Frage, der Demo-Datensatz
/// `app/test/fixtures/health_export_demo.json` hat an mehreren Tagen
/// `steps: null` bzw. `weightKg: null`, eine Kachel ohne Reihe ist also ein
/// echter Fall, kein Sonderweg.
void main() {
  group('Kacheln / Verlaufslinie (Widget)', () {
    testWidgets('zeigt keine Verlaufslinie, wenn keine Reihe uebergeben wird', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Gewicht',
              wert: '58,4',
              einheit: 'kg',
              zusatz: '−0,20 kg/Woche · Ziel 54,0',
              farbe: CupertinoColors.systemYellow,
            ),
          ]),
        ),
      );

      expect(find.byType(Verlaufslinie), findsNothing);
    });

    testWidgets('zeigt keine Verlaufslinie fuer eine leere Reihe', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Gewicht',
              wert: '58,4',
              einheit: 'kg',
              zusatz: '−0,20 kg/Woche · Ziel 54,0',
              farbe: CupertinoColors.systemYellow,
              verlauf: [],
            ),
          ]),
        ),
      );

      expect(find.byType(Verlaufslinie), findsNothing);
    });

    testWidgets('zeigt eine Verlaufslinie, wenn eine Reihe uebergeben wird', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Schritte',
              wert: '4.128',
              zusatz: 'gestern · Ø 7 Tage 5.302 ▼ 4 %',
              farbe: CupertinoColors.systemGreen,
              verlauf: [5900, 5500, 5100, 4800, 4950, 4600, 4128],
            ),
          ]),
        ),
      );

      expect(find.byType(Verlaufslinie), findsOneWidget);
    });

    testWidgets(
      'rendert fuer jeden Eintrag eine eigene Kachel, mit und ohne Reihe '
      'gemischt',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const Kacheln([
              KachelWert(
                label: 'Schritte',
                wert: '4.128',
                zusatz: 'gestern · Ø 7 Tage 5.302 ▼ 4 %',
                farbe: CupertinoColors.systemGreen,
                verlauf: [5900, 5500, 5100, 4800, 4950, 4600, 4128],
              ),
              KachelWert(
                label: 'Gewicht',
                wert: '58,4',
                einheit: 'kg',
                zusatz: '−0,20 kg/Woche · Ziel 54,0',
                farbe: CupertinoColors.systemYellow,
              ),
            ]),
          ),
        );

        expect(find.text('Schritte'), findsOneWidget);
        expect(find.text('Gewicht'), findsOneWidget);
        // Genau eine Verlaufslinie fuer die eine Kachel, die eine Reihe hat.
        expect(find.byType(Verlaufslinie), findsOneWidget);
      },
    );
  });

  group('Verlaufslinie (Widget, einzeln)', () {
    testWidgets(
      'baut ohne Fehler, wenn alle Werte der Reihe gleich sind (flache '
      'Linie statt Teilung durch 0)',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const Verlaufslinie(
              werte: [12.0, 12.0, 12.0],
              farbe: CupertinoColors.systemYellow,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Verlaufslinie), findsOneWidget);
      },
    );
  });
}
