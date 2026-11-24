import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/main.dart';

/// Befund aus `task-13-report.md` (Abschnitt „Selbstprüfung" /
/// Nebenbefund): `dart analyze` meldet `missing_provider_scope` für
/// `app/lib/main.dart` — die App hat **keinen** `ProviderScope` an der
/// Wurzel.
///
/// Ohne ihn erreicht kein Schirm, auch `HeuteView` aus diesem Task nicht,
/// `dailyMetricsProvider` oder einen der anderen Health-Provider
/// (`healthProvider`, `appCacheProvider`, `cacheRepositoryProvider`,
/// `dataWindowProvider`, `clockProvider`): Jedes `ref.watch(...)` braucht
/// einen `ProviderContainer`, den nur `ProviderScope`/
/// `UncontrolledProviderScope` in den Widget-Baum stellt. `RootView` und
/// `CupertinoApp` tun das nicht von sich aus.
///
/// Dieser Test hält **nur** die Struktur fest — ein `ProviderScope` existiert
/// irgendwo oberhalb von `RootView` in `main.dart`. Er prüft **nicht**, dass
/// `healthProvider`/`appCacheProvider` darin mit den echten Instanzen
/// (`HealthChannel`, `AppCache.oeffnen()`) überschrieben sind: Das ließe
/// sich ohne echte Plattform-Kanäle (HealthKit, ein echtes Dateisystem für
/// den drift-Cache) in einem reinen Widget-Test nicht gefahrlos auslösen
/// und gehört eher in die Prüfanleitung für den Simulator als in eine
/// automatisierte Zusicherung hier.
///
/// **RED heute:** `main.dart` hat noch keinen `ProviderScope` — dieser Test
/// schlägt deshalb fehl, bis er nachgetragen wird. Sobald `HeuteView` (oder
/// ein anderer Schirm) tatsächlich in `RootView` hängt und einen
/// Health-Provider liest, würde ohne diesen `ProviderScope` nicht dieser
/// Test, sondern die App selbst mit einer `UnimplementedError`/einem
/// „No ProviderScope found"-Fehler abstürzen — genau das soll dieser Test
/// vorab, ohne jeden Schirm, sichtbar machen.
///
/// Diese Datei ist bewusst **neu**, nicht Teil von `main_test.dart` — die
/// Aufgabe verbietet, bestehende Testdateien anzufassen, auch um einen
/// zusätzlichen Fall zu ergänzen.
void main() {
  testWidgets('main.dart umschließt die App mit einem ProviderScope', (
    tester,
  ) async {
    await tester.pumpWidget(const RepitApp());

    expect(
      find.byType(ProviderScope),
      findsOneWidget,
      reason: 'ohne ProviderScope erreicht kein Schirm einen Health-Provider '
          '(dailyMetricsProvider, healthProvider, appCacheProvider, ...) — '
          'Befund aus task-13-report.md, Abschnitt Selbstprüfung',
    );
  });
}
