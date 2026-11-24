import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/main.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/root_view.dart';

/// Smoke-Test für `main.dart` — nicht mehr das Gerüst-Stadium von vor Task 10
/// (`find.text('Flutter Rebuild')` gegen eine lose `Text`-Zeile), sondern das,
/// was nach Task 10 tatsächlich gilt: `RepitApp` muss `RootView`
/// ohne eigene `Router`-Instanz starten (der Produktionsfall; `RootView`
/// baut sich dann selbst eine, siehe `shell/root_view_test.dart`) und beim
/// Start sichtbar das Tab-Gerüst zeigen, nicht einen leeren oder werfenden
/// Baum.
///
/// Diese Datei prüft bewusst nur die **Verdrahtung** (main → RootView →
/// Tab-Leiste → Start-Tab) — alle Stapel-, Wechsel- und Platzhalter-Details
/// deckt `test/shell/root_view_test.dart` ab. Eine zweite, ausführliche
/// Prüfung hier wäre doppelte Pflege ohne zusätzlichen Beweiswert.
///
/// **Verschoben, nicht neu erfunden:** Diese Datei stammte aus der
/// Gerüst-Aufgabe vor Task 10 und ist seitdem unausweichlich an die
/// Shell-Verdrahtung gekoppelt — sie gehört ab jetzt zu Task 10s Testfläche,
/// nicht mehr zum alten Gerüst. Aktualisiert als Teil von Task 10, nicht als
/// eigener Auftrag.
///
/// **Nachtrag (task-navbar, 26.10.2026):** Seit dem Umbau der Tableiste
/// zeigt der erste Tab (`Tab.heute`, sichtbares Label „Home") nicht mehr
/// `PlatzhalterTab`, sondern `HeuteView` — das ist der Schritt, nach dem Tim
/// zum ersten Mal echte Zahlen im Simulator sieht (Auftrag, wörtlich). Diese
/// Datei pumpt `RepitApp` unverändert **ohne** Provider-Override
/// (echte `main.dart`-Verdrahtung, kein Test-Double) — `HeuteView` liest
/// dann den echten, nicht überschriebenen `healthProvider`, der ohne
/// Override mit `UnimplementedError` wirft (siehe `health_provider.dart`).
/// Das führt **nicht** zu einem Absturz: Der Wurf passiert synchron im
/// Rumpf einer `async`-Methode (`DailyMetricsNotifier.build()`), und Dart
/// wandelt das automatisch in einen abgelehnten Future um, den Riverpods
/// `AsyncNotifier` als `AsyncError` auffängt, nie als unbehandelte Flutter-
/// Exception. `HeuteView` zeigt in diesem Zustand ihren Ladezweig
/// (`NochNie`, weil `AsyncValue.value` ohne vorherigen Erfolg `null` ist) —
/// ein Smoke-Test, der nur die Verdrahtung, nicht den Dateninhalt prüft
/// (das deckt `heute_view_test.dart` mit echten Provider-Overrides ab).
void main() {
  testWidgets('App startet mit dem Tab-Geruest und zeigt den Home-Tab', (
    tester,
  ) async {
    await tester.pumpWidget(const RepitApp());
    await tester.pump();

    expect(find.byType(RootView), findsOneWidget);
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    // Home ist seit dem Umbau der Tableiste der einzige Tab, der sofort
    // einen echten Schirm zeigt (die übrigen drei bleiben PlatzhalterTab/
    // MehrView, siehe `shell/root_view_test.dart`) — und der Startzustand,
    // den die App ohne jede Interaktion zeigt.
    expect(find.byType(HeuteView).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('erfassen-knopf')).hitTestable(), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
