import 'package:flutter/widgets.dart';

import 'ziele.dart';

/// Die vier Reiter der App — Dart-Entsprechung von `Router.Tab` in
/// `Sources/Features/Shell/Router.swift`, seit dem Tableisten-Umbau
/// (task-navbar, 26.10.2026, `docs/screens/components.js:158`) aber nicht
/// mehr dieselben fünf wie `RootView.swift:29-40`: **Home · Ernährung ·
/// (+) · Gym · Mehr**. Der Plan-Reiter ist ersatzlos entfallen — der Plan
/// ist seitdem über `MehrView` erreichbar, nicht mehr über einen eigenen
/// Tab (siehe `test/shell/root_view_test.dart`, `test/shell/
/// mehr_view_test.dart`), und der (+) ist kein Tab, sondern eine Handlung
/// (`ErfassenKnopf` in `root_view.dart`).
///
/// `Tab.heute` heißt weiterhin so, obwohl sein sichtbares Label auf dem
/// Board „Home" ist — ein interner Bezeichner ist keine
/// Oberflächenbeschriftung (CLAUDE.md), und ihn umzubenennen hieße, jeden
/// Aufrufer anzufassen, ohne das Verhalten zu ändern.
///
/// **Keine Namenskollision mit `flutter/material.dart`'s `Tab`-Widget**, weil
/// dieses Projekt ausschließlich `cupertino.dart`/`widgets.dart` importiert —
/// dort gibt es kein eigenes `Tab`.
enum Tab { heute, ernaehrung, gym, mehr }

/// Ein Navigationsbefehl, abgeholt genau einmal von `RootView`
/// ([AppRouter.nimmBefehl]).
///
/// Bewusst **nicht** Teil des dauerhaften Zustands von [AppRouter]: Der
/// eigentliche Navigationsstapel lebt im `Navigator` jedes Tabs (siehe
/// `RootView`), nicht ein zweites Mal hier — sonst gäbe es zwei Wahrheiten
/// über denselben Stapel, die auseinanderlaufen könnten, sobald zusätzlich
/// zu `AppRouter.open(...)` auch per Wischgeste oder Zurück-Knopf zurückgegangen
/// wird (was `AppRouter` gar nicht mitbekommt und auch nicht müsste).
@immutable
class AppRouterBefehl {
  const AppRouterBefehl({
    required this.tab,
    required this.builder,
    required this.ersetztStapel,
  });

  /// Der Tab, auf dessen Stapel geschoben werden soll.
  final Tab tab;

  final WidgetBuilder builder;

  /// `true` bei `AppTarget.detail(...)`: der ganze Stapel des Tabs wird
  /// durch genau dieses eine Ziel ersetzt. `false` bei `AppTarget.aktuell(...)`:
  /// es wird auf den bestehenden Stapel geschoben.
  final bool ersetztStapel;
}

/// Hält den aktuell gewählten Tab und reicht Navigationsbefehle an
/// `RootView` weiter — Dart-Entsprechung von `Router` (siehe
/// `Sources/Features/Shell/Router.swift`), hier `AppRouter` genannt, weil
/// `flutter/widgets.dart` (von `cupertino.dart` reexportiert) selbst ein
/// `Router<T>` kennt (Navigator 2.0). Ein `hide Router` an jeder künftigen
/// Datei wäre eine Steuer, die man einmal einführt und dann vergisst —
/// der eigene Name kollidiert gar nicht erst.
///
/// `ChangeNotifier`, nicht nur ein einfaches Feld: `RootView` hört auf
/// Änderungen (`addListener`), damit ein `router.open(...)`, das **von
/// außerhalb** des Widget-Baums aufgerufen wird (wie in den Tests, oder
/// später aus einer Hintergrundaktion), tatsächlich etwas bewirkt. Ein
/// Rebuild, der erst beim nächsten Tipp in der Oberfläche ausgelöst würde,
/// reicht dafür nicht.
class AppRouter extends ChangeNotifier {
  Tab _tab = Tab.heute;

  /// Der aktuell gewählte Tab.
  Tab get tab => _tab;

  AppRouterBefehl? _befehl;

  /// Öffnet ein Ziel.
  ///
  /// Nur die Tab-Fälle von [AppTarget] (`.heute()`, `.ernaehrung()`,
  /// `.gym()`, `.mehr()`) wechseln den gewählten Tab — Hausregel aus
  /// `CLAUDE.md`: Ein Detailziel schiebt auf den Stapel des Tabs, der
  /// gerade ausgewählt ist (`AppTarget.aktuell`), oder ersetzt gezielt den
  /// Stapel eines bestimmten Tabs (`AppTarget.detail`), aber ein Ziel, das
  /// irgendwo im Menü unter einem Tab einsortiert ist, wechselt niemals von
  /// sich aus dorthin — sonst führte „zurück" in ein Menü, das der Nutzer
  /// nie geöffnet hat.
  void open(AppTarget target) {
    if (target.wechseltTab) {
      _tab = target.tab!;
    }
    if (target.builder != null) {
      _befehl = AppRouterBefehl(
        tab: target.tab ?? _tab,
        builder: target.builder!,
        ersetztStapel: target.ersetztStapel,
      );
    }
    notifyListeners();
  }

  /// Holt den ausstehenden Navigationsbefehl **genau einmal** ab und löscht
  /// ihn danach. Ein zweiter Aufruf ohne zwischenzeitliches `open(...)`
  /// liefert `null` — sonst würde ein späterer, unabhängiger Tab-Wechsel
  /// (der keinen Push meint) denselben Push ein zweites Mal auslösen.
  AppRouterBefehl? nimmBefehl() {
    final befehl = _befehl;
    _befehl = null;
    return befehl;
  }
}
