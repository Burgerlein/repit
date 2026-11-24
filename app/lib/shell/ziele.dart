import 'package:flutter/widgets.dart';

import 'router.dart';

/// Wohin `AppRouter.open(...)` wechseln oder schieben soll — Dart-Entsprechung
/// von `Destination`/`Router.Tab`-Fällen in
/// `Sources/Features/Shell/Router.swift`.
///
/// Vier Fabrikmethoden ohne Baufunktion (`AppTarget.heute()`,
/// `.ernaehrung()`, `.gym()`, `.mehr()`) wechseln den Tab. `AppTarget.plan()`
/// ist seit dem Tableisten-Umbau (task-navbar, 26.10.2026) ersatzlos
/// entfallen — es gibt keinen Plan-Tab mehr, zu dem es wechseln könnte; der
/// Plan ist seitdem über `MehrView` mit `AppTarget.aktuell(...)` erreichbar
/// (siehe `test/shell/root_view_test.dart`). Zwei weitere
/// nehmen einen `WidgetBuilder` entgegen und schieben statt zu wechseln:
///
/// - `AppTarget.aktuell(builder)` schiebt [builder] auf den Stapel des
///   **aktuell gewählten** Tabs, ohne ihn zu wechseln.
/// - `AppTarget.detail(tab, builder)` wechselt zu [tab] **und** ersetzt
///   dessen ganzen Stapel durch genau dieses eine Ziel — Pendant zu Swifts
///   `.detail(Tab, Destination)`.
///
/// Die Hausregel aus `CLAUDE.md` gilt wörtlich: Ein Detailziel, das
/// irgendwo im Menü unter einem bestimmten Tab einsortiert ist, schiebt
/// trotzdem auf den aktuellen Stapel (`AppTarget.aktuell`) statt den Tab zu
/// wechseln — sonst führte „zurück" in ein Menü, das der Nutzer nie
/// geöffnet hat.
///
/// `openBody(...)`/`openGym(...)` aus dem Task-Interface bauen vermutlich
/// auf `AppTarget.aktuell` auf, sobald `BodyDestination`/`GymDestination`
/// in den jeweiligen Körper-/Gym-Aufgaben entstehen — hier bewusst nicht
/// vorweggenommen.
@immutable
class AppTarget {
  const AppTarget._({
    this.tab,
    this.builder,
    required this.wechseltTab,
    required this.ersetztStapel,
  });

  /// Wechselt zum Heute-Tab.
  factory AppTarget.heute() => const AppTarget._(
    tab: Tab.heute,
    wechseltTab: true,
    ersetztStapel: false,
  );

  /// Wechselt zum Gym-Tab.
  factory AppTarget.gym() =>
      const AppTarget._(tab: Tab.gym, wechseltTab: true, ersetztStapel: false);

  /// Wechselt zum Ernährung-Tab.
  factory AppTarget.ernaehrung() => const AppTarget._(
    tab: Tab.ernaehrung,
    wechseltTab: true,
    ersetztStapel: false,
  );

  /// Wechselt zum Mehr-Tab.
  ///
  /// Nicht Teil der in `root_view_test.dart` wörtlich festgelegten API
  /// (dort stehen nur die vier übrigen Tab-Fabriken), aber konsequent dazu:
  /// Auch ein Tipp auf „Mehr" in der Tab-Leiste selbst läuft über
  /// `AppRouter.open`, nicht über einen zweiten, nur für diesen einen Tab
  /// gedachten Mechanismus in `RootView`.
  factory AppTarget.mehr() =>
      const AppTarget._(tab: Tab.mehr, wechseltTab: true, ersetztStapel: false);

  /// Schiebt [builder] auf den Stapel des aktuell gewählten Tabs, ohne den
  /// Tab zu wechseln.
  factory AppTarget.aktuell(WidgetBuilder builder) =>
      AppTarget._(builder: builder, wechseltTab: false, ersetztStapel: false);

  /// Wechselt zu [tab] und setzt dessen Stapel auf genau [builder].
  factory AppTarget.detail(Tab tab, WidgetBuilder builder) => AppTarget._(
    tab: tab,
    builder: builder,
    wechseltTab: true,
    ersetztStapel: true,
  );

  /// `null` bei `AppTarget.aktuell(...)` — dort bestimmt der aktuell
  /// gewählte Tab das Ziel, nicht dieses Feld.
  final Tab? tab;

  /// `null` bei einem reinen Tab-Wechsel (`.heute()` usw.) — dort wird
  /// nichts geschoben.
  final WidgetBuilder? builder;

  /// `true`, wenn dieses Ziel den gewählten Tab wechselt.
  final bool wechseltTab;

  /// `true`, wenn der ganze Stapel des Ziel-Tabs durch [builder] ersetzt
  /// werden soll, statt nur darauf zu schieben.
  final bool ersetztStapel;
}
