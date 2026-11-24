import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/symbole.dart';
import 'package:repit/shell/root_view.dart';

import '../design/support.dart';

/// Isolierte Tests für `TabBadge` (Task 10, `lib/shell/root_view.dart`).
///
/// Cupertino kennt kein `.badge`-Gegenstück für einen Tab (anders als
/// SwiftUIs `.badge(_:)` in `RootView.swift:73`); der Hinweis muss als
/// `Stack`-Overlay auf dem Symbol selbst gebaut werden (Task-Brief, Abschnitt
/// „Drei Dinge, die Cupertino nicht von selbst gibt"). In M1 läuft kein
/// Training, der Badge-Wert ist also immer `null` — genau deshalb muss hier
/// geprüft werden, dass „kein Wert" auch wirklich **nichts** zeichnet
/// (kein leerer Kreis), nicht erst, wenn ein späterer Task einen echten Wert
/// liefert.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** Der Badge-Baustein ist ein
/// eigener, öffentlicher, generischer Baustein (`TabBadge`) statt direkt in
/// die private Tab-Aufbaufunktion von `RootView` verwoben — nur so lässt er
/// sich isoliert prüfen, parallel zu `IconRow`/`Glas` aus Task 9. Name und
/// Feldnamen (`symbol`, `wert`) sind mein Vorschlag; an welchen Tabs
/// `RootView` ihn tatsächlich verwendet (heute: an keinem, M1 hat keine
/// laufende Trainingseinheit), ist nicht Gegenstand dieser Datei.
void main() {
  const symbol = 'dumbbell';

  testWidgets('zeigt keinen Badge, wenn kein Wert gesetzt ist', (tester) async {
    await tester.pumpWidget(huelle(const TabBadge(symbol: symbol)));

    expect(find.byKey(const Key('tab-badge')), findsNothing);
    expect(find.byIcon(Symbole.aufloesen(symbol)), findsOneWidget);
  });

  testWidgets('zeigt keinen Badge bei leerem Wert — kein leerer Kreis', (
    tester,
  ) async {
    await tester.pumpWidget(huelle(const TabBadge(symbol: symbol, wert: '')));

    expect(find.byKey(const Key('tab-badge')), findsNothing);
  });

  testWidgets('zeigt den Badge, wenn ein Wert gesetzt ist', (tester) async {
    await tester.pumpWidget(huelle(const TabBadge(symbol: symbol, wert: '3')));

    expect(find.byKey(const Key('tab-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('zeigt weiterhin das Symbol, auch wenn ein Badge gesetzt ist', (
    tester,
  ) async {
    await tester.pumpWidget(huelle(const TabBadge(symbol: symbol, wert: '12')));

    expect(find.byIcon(Symbole.aufloesen(symbol)), findsOneWidget);
  });
}
