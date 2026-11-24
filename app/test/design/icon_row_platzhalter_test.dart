import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/icon_row.dart';
import 'package:repit/design/platzhalter.dart';

import 'support.dart';

/// Tests für `IconRow.platzhalter` — die graue Form an der Stelle, an
/// der ein Wert stehen wird (#182, gegen
/// `docs/superpowers/specs/2026-11-03-healthkit-test-aufteilung.md`,
/// Abschnitt 3).
///
/// Bis zum 03.11.2026 konnte nur eine Kachel oder ein Ring einen
/// Platzhalter tragen. Ein Schirm aus Zeilen — und der HealthKit-Test
/// ist genau das — hatte im Ladezustand deshalb **gar kein** Gerüst: Er
/// zeigte einen Satz, und beim Eintreffen der Werte sprang alles.
void main() {
  Widget zeile({String? value, String? platzhalter, String? subtitle}) =>
      huelle(
        IconRow(
          title: 'Schritte',
          subtitle: subtitle,
          symbol: 'figure.walk',
          accent: const Color(0xFF2F7A4F),
          value: value,
          platzhalter: platzhalter,
        ),
      );

  testWidgets('zeigt eine graue Form statt des Werts', (tester) async {
    await tester.pumpWidget(zeile(platzhalter: '9.215'));

    expect(find.byType(Platzhalter), findsOneWidget);
  });

  /// Der eigentliche Punkt: Ein Platzhalter, der die Ziffern als Text
  /// mitbrächte, wäre eine erfundene Zahl auf dem Schirm — Fehler `01`
  /// in neuer Verpackung, und jeder Widget-Test fände sie.
  testWidgets('die Ziffern des Beispiels stehen nirgends im Baum', (
    tester,
  ) async {
    await tester.pumpWidget(zeile(platzhalter: '9.215'));

    expect(find.textContaining('9.215'), findsNothing);
    expect(find.textContaining('9'), findsNothing);
  });

  /// Die Breite kommt aus dem Beispiel, nicht aus einer festen Zahl.
  /// Ein Platzhalter, der kürzer ist als das, was ihn ablöst, lässt die
  /// Spalte beim Eintreffen springen — Schritte sind fünfstellig, ein
  /// Gewicht hat eine Nachkommastelle.
  testWidgets('ein laengeres Beispiel ergibt eine breitere Form', (
    tester,
  ) async {
    await tester.pumpWidget(zeile(platzhalter: '9'));
    final schmal = tester.getSize(find.byType(Platzhalter)).width;

    await tester.pumpWidget(zeile(platzhalter: '9.215 kcal'));
    final breit = tester.getSize(find.byType(Platzhalter)).width;

    expect(breit, greaterThan(schmal));
  });

  /// Dieselbe Geometrie wie mit Wert — das ist der ganze Zweck. Wäre die
  /// Zeile im Ladezustand niedriger, spränge beim Eintreffen alles
  /// darunter, und der Platzhalter hätte den Fehler nur verschoben.
  testWidgets('die Zeile ist mit Platzhalter so hoch wie mit Wert', (
    tester,
  ) async {
    await tester.pumpWidget(zeile(value: '9.215'));
    final mitWert = tester.getSize(find.byType(IconRow)).height;

    await tester.pumpWidget(zeile(platzhalter: '9.215'));
    final mitForm = tester.getSize(find.byType(IconRow)).height;

    expect(mitForm, mitWert);
  });

  testWidgets('ohne Platzhalter bleibt alles, wie es war', (tester) async {
    await tester.pumpWidget(zeile(value: '9.215'));

    expect(find.byType(Platzhalter), findsNothing);
    expect(find.text('9.215'), findsOneWidget);
  });

  /// „Wert" und „Platzhalter" sind zwei Antworten auf dieselbe Frage.
  /// Stünden beide da, behauptete die Zeile gleichzeitig, der Wert sei
  /// bekannt und er werde noch geladen. Der Wert gewinnt: Er ist die
  /// stärkere Aussage, und so kann ein Aufrufer den Platzhalter
  /// unbesehen durchreichen.
  testWidgets('ein vorhandener Wert schlaegt den Platzhalter', (tester) async {
    await tester.pumpWidget(zeile(value: '9.215', platzhalter: '9.215'));

    expect(find.byType(Platzhalter), findsNothing);
    expect(find.text('9.215'), findsOneWidget);
  });

  /// Der Platzhalter sitzt auf dem **Wert**, nicht auf dem Namen: Der
  /// Name ist nichts, was ankommen könnte, er steht von Anfang an fest.
  testWidgets('der Name steht auch im Ladezustand als Text da', (
    tester,
  ) async {
    await tester.pumpWidget(zeile(platzhalter: '9.215'));

    expect(find.text('Schritte'), findsOneWidget);
  });
}
