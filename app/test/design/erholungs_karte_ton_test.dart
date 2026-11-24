import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/palette.dart';

import 'support.dart';

/// **#254 — die Ampelfarbe der Erholungswerte auf Heute.**
///
/// Tim am 03.11.2026: „auf dem Home Screen sind die Werte von Erholung
/// immer noch nicht gefärbt". Der Entwurf sieht es vor —
/// `docs/screens/screens/heute-kombi.js`, `RECOVERY.vitals` trägt je Wert
/// ein `tone` —, gebaut war es nie: `VitalWert` kannte nur `name`, `wert`,
/// `hinweis` und `platzhalter`, und `ErholungsKarte` löste genau zwei
/// Farben auf.
///
/// Diese Datei beschreibt **das Bauteil**: Es bekommt einen fachlichen
/// Zustand und wählt die Farbe. Woher der Zustand kommt, steht in
/// `heute_ampelfarbe_test.dart`.
///
/// ## Warum ein Zustand und keine `Color`
///
/// Gäbe `VitalWert` eine Farbe weiter, entschiede jeder Aufrufer neu, was
/// „gelb" heißt — und die Karte sähe auf Heute anders aus als auf dem
/// Erholungs-Schirm, ohne dass es jemandem auffiele. Die Zuordnung Zustand
/// → Farbe gehört an **eine** Stelle.
///
/// ## Was hier geprüft wird
///
/// - Jeder der drei Zustände hat seine eigene Farbe, und der Warnzustand
///   trägt dieselbe wie auf dem Erholungs-Schirm ([Palette.warn]).
/// - **Ein unbeurteilter Wert ist weder grün noch rot.** Ohne Median gibt
///   es keinen Vergleich, und ein grüner Wert behauptete „im
///   Normalbereich" — eine Aussage, die niemand gemacht hat.
/// - **Die Form bleibt gleich.** Gefärbt und ungefärbt haben dieselbe
///   Höhe und Breite, sonst springt die Karte, sobald ein Signal auftritt
///   (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine Form").
/// - **Die Bildunterschrift bleibt stehen.** Farbe ist nicht die einzige
///   Auskunft; wer Rot und Grün schlecht unterscheidet, liest „Median 58".
///
/// ## Was hier **nicht** geprüft wird
///
/// Welcher Wert welchen Zustand bekommt. Das entscheidet die Ampel im
/// Kern, nicht die Karte — eine zweite Bewertung in der Oberfläche wären
/// zwei Wahrheiten.
///
/// Die Zahlen sind erfunden (`CLAUDE.md`, Spec Abschnitt 12).
void main() {
  Widget karte(List<VitalWert> vitalwerte) => huelle(
    ErholungsKarte(
      ueberschrift: 'Achte auf dich',
      satz: 'Ein Wert liegt außerhalb deines Normalbereichs.',
      akzent: CupertinoColors.systemGrey,
      vitalwerte: vitalwerte,
    ),
  );

  /// Die Farbe, in der die Zahl einer Spalte steht.
  Color farbeVon(WidgetTester tester, String wert) =>
      tester.widget<Text>(find.text(wert)).style!.color!;

  int aufgeloest(WidgetTester tester, CupertinoDynamicColor farbe) =>
      CupertinoDynamicColor.resolve(
        farbe,
        tester.element(find.byType(ErholungsKarte)),
      ).toARGB32();

  group('Der Zustand wählt die Farbe', () {
    testWidgets('ein Warnsignal trägt dieselbe Farbe wie auf dem '
        'Erholungs-Schirm', (tester) async {
      await tester.pumpWidget(
        karte(const [
          VitalWert(
            name: 'HRV',
            wert: '41',
            hinweis: 'Median 58',
            ton: VitalTon.warnsignal,
          ),
        ]),
      );

      expect(
        farbeVon(tester, '41').toARGB32(),
        aufgeloest(tester, Palette.warn),
        reason:
            'derselbe Wert trägt auf dem Erholungs-Schirm `Palette.warn` '
            '(`_vitalwert` in `erholung_werte_zustand.dart`) — zwei Farben '
            'für dieselbe Aussage wären zwei Wahrheiten',
      );
    });

    testWidgets('ein beurteilter Wert ohne Warnsignal ist grün', (
      tester,
    ) async {
      await tester.pumpWidget(
        karte(const [
          VitalWert(
            name: 'HRV',
            wert: '61',
            hinweis: 'Median 58',
            ton: VitalTon.normal,
          ),
        ]),
      );

      expect(
        farbeVon(tester, '61').toARGB32(),
        aufgeloest(tester, Palette.ok),
        reason: 'der Entwurf führt diese Werte mit `tone: ok`',
      );
    });

    testWidgets('ein unbeurteilter Wert ist weder grün noch rot', (
      tester,
    ) async {
      await tester.pumpWidget(
        karte(const [
          VitalWert(name: 'HRV', wert: '61', ton: VitalTon.unbeurteilt),
        ]),
      );

      final farbe = farbeVon(tester, '61').toARGB32();
      expect(
        farbe,
        isNot(aufgeloest(tester, Palette.ok)),
        reason:
            'ohne Median gibt es keinen Vergleich, und grün behauptete '
            '„im Normalbereich" — eine Aussage, die niemand gemacht hat',
      );
      expect(
        farbe,
        isNot(aufgeloest(tester, Palette.warn)),
        reason: 'und rot behauptete ein Warnsignal, das niemand gefunden hat',
      );
    });

    testWidgets('ohne Angabe ist ein Wert unbeurteilt', (tester) async {
      await tester.pumpWidget(
        karte(const [VitalWert(name: 'HRV', wert: '61')]),
      );

      expect(
        farbeVon(tester, '61').toARGB32(),
        isNot(aufgeloest(tester, Palette.ok)),
        reason:
            'wer den Zustand nicht mitgibt, hat nicht bewertet — der '
            'Vorgabewert darf keine Bewertung behaupten',
      );
    });
  });

  group('Was sich durch die Farbe nicht ändert', () {
    testWidgets('gefärbt und ungefärbt sind gleich hoch und gleich breit', (
      tester,
    ) async {
      const werte = ['7:00', '61', '68', '15,2'];

      Size groesse(WidgetTester t) => t.getSize(find.byType(ErholungsKarte));

      await tester.pumpWidget(
        karte(const [
          VitalWert(name: 'Schlaf', wert: '7:00', hinweis: 'Ø 6:40'),
          VitalWert(name: 'HRV', wert: '61', hinweis: 'Median 58'),
          VitalWert(name: 'Ruhepuls', wert: '68', hinweis: 'Ø 66'),
          VitalWert(name: 'Atmung', wert: '15,2', hinweis: 'Normal 14,0'),
        ]),
      );
      final ohne = groesse(tester);
      final zeilen = [
        for (final wert in werte) tester.getSize(find.text(wert)),
      ];

      await tester.pumpWidget(
        karte(const [
          VitalWert(
            name: 'Schlaf',
            wert: '7:00',
            hinweis: 'Ø 6:40',
            ton: VitalTon.warnsignal,
          ),
          VitalWert(
            name: 'HRV',
            wert: '61',
            hinweis: 'Median 58',
            ton: VitalTon.normal,
          ),
          VitalWert(
            name: 'Ruhepuls',
            wert: '68',
            hinweis: 'Ø 66',
            ton: VitalTon.normal,
          ),
          VitalWert(
            name: 'Atmung',
            wert: '15,2',
            hinweis: 'Normal 14,0',
            ton: VitalTon.unbeurteilt,
          ),
        ]),
      );

      expect(
        groesse(tester),
        ohne,
        reason:
            'eine Karte, die beim Auftreten eines Signals wächst, schiebt '
            'alles darunter (`CLAUDE.md`)',
      );
      for (var i = 0; i < werte.length; i++) {
        expect(
          tester.getSize(find.text(werte[i])),
          zeilen[i],
          reason: '${werte[i]}: die Farbe ändert die Schrift nicht mit',
        );
      }
    });

    testWidgets('die Bildunterschrift bleibt stehen', (tester) async {
      await tester.pumpWidget(
        karte(const [
          VitalWert(
            name: 'HRV',
            wert: '41',
            hinweis: 'Median 58',
            ton: VitalTon.warnsignal,
          ),
        ]),
      );

      expect(
        find.text('Median 58'),
        findsOneWidget,
        reason:
            'Farbe ist nicht die einzige Auskunft — wer Rot und Grün '
            'schlecht unterscheidet, braucht die Einordnung im Text',
      );
    });
  });
}
