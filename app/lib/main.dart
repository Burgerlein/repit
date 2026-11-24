import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// `show AppCache`, nicht der ganze Namensraum: `cache.dart` reicht drift
// weiter, und drift bringt einen eigenen Namen `Override` mit. Ohne die
// Einschränkung kollidiert er mit Riverpods `Override`, und der Analyzer
// meldet das als „ist kein Typ" — ein Fehler, der auf die Zeile zeigt, die
// den Typ benutzt, nicht auf den Import, der ihn kaputtmacht.
import 'data/cache.dart' show AppCache;
import 'design/palette.dart';
import 'ernaehrung/seed_datenbank.dart';
import 'gym/uebungsbilder_provider.dart';
import 'health/health_channel.dart';
import 'health/health_mock.dart';
import 'health/health_provider.dart';
import 'live/live_anzeige.dart';
import 'live/live_wacht.dart';
import 'shell/aenderungen.dart';
import 'shell/root_view.dart';
import 'shell/router.dart';
import 'shell/tageswacht.dart';

/// `healthProvider` und `appCacheProvider` werfen absichtlich, solange sie
/// niemand überschreibt — hier ist die eine Stelle, die es tut. Ohne sie
/// baut die App, laufen alle Tests grün, und der Heute-Schirm steht im
/// Simulator trotzdem ewig auf „wird geladen": Der Provider kommt nie zu
/// einem Ergebnis, weil sein `HealthReading` beim ersten Zugriff eine
/// `UnimplementedError` wirft. Ein Widget-Test sieht das nicht, weil er
/// beide Provider selbst überschreibt.
///
/// **Die Quelle hängt am Gerät, nicht an einem Schalter.** Im Simulator
/// liegt der Demo-Datensatz im Dokumentenverzeichnis, sofern
/// `scripts/health_demo_in_simulator.sh` gelaufen ist; auf einem echten
/// iPhone gibt es ihn nicht, [ladeDemoDatensatzFuerSimulator] liefert
/// `null`, und der echte [HealthChannel] bleibt übrig. Im Release-Build
/// entfernt der Compiler den Demo-Zweig vollständig (`kDebugMode` ist eine
/// Kompilierzeit-Konstante) — Demodaten können das Gerät also nicht nur
/// nicht erreichen, sie liegen dort gar nicht erst im Programm.
///
/// `missing_provider_scope` trifft hier nicht zu, und die Regel kann das
/// nicht sehen: Sie vergleicht ausschließlich den statischen Typ des ersten
/// `runApp`-Arguments mit `ProviderScope`/`UncontrolledProviderScope`
/// (`riverpod_lint-3.1.9/lib/src/lints/missing_provider_scope.dart`) und
/// schaut nie in eine `build()`-Methode hinein.
///
/// **Der `AppRouter` entsteht hier**, nicht in `RootView` (#369): Die
/// Live-Aktivität öffnet über ihren Link „Mahlzeit eintragen", und
/// `LiveWacht` sitzt oberhalb der `CupertinoApp`. Sie braucht dieselbe
/// Instanz wie die Schale, sonst ginge die Kamera an einen Router, auf den
/// niemand hört. `liveAnzeigeProvider` wirft ohne Override, wie
/// `healthProvider` — hier bekommt er den echten Kanal.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final demo = await ladeDemoDatensatzFuerSimulator();
  // Einmal, vor dem ersten Bild: Danach ist „hat die Übung ein Bild?" eine
  // reine Nachschlage-Frage (`uebungsbilderProvider`).
  final bilder = await ladeUebungsbilder(rootBundle);
  // Dasselbe einmal für die Lebensmittel-Seed-Datenbank (#543): Das Asset
  // wandert beim ersten Start neben den drift-Cache, danach ist Suchen eine
  // reine Leseabfrage. Scheitert das, startet die App mit
  // `SeedDatenbank.leer()` — Stufe 2 der Suche fällt aus, die eigenen
  // Lebensmittel und Open Food Facts bleiben.
  final seed = await ladeSeedDatenbank(rootBundle);
  // Ebenso einmal, vor dem ersten Bild: Die Mehr-Fußzeile und das
  // Änderungsblatt (#89) lesen die Fassungsliste danach nur noch nach.
  final aenderungen = await ladeAenderungen(rootBundle);

  // ignore: missing_provider_scope
  runApp(
    RepitApp(
      behaelter: ProviderContainer(
        overrides: [
          appCacheProvider.overrideWithValue(AppCache.oeffnen()),
          uebungsbilderProvider.overrideWithValue(bilder),
          seedDatenbankProvider.overrideWithValue(seed),
          aenderungenProvider.overrideWithValue(aenderungen),
          healthProvider.overrideWithValue(demo ?? HealthChannel()),
          liveAnzeigeProvider.overrideWithValue(KanalLiveAnzeige()),
        ],
      ),
      router: AppRouter(),
    ),
  );
}

/// `ProviderScope` umschließt die App **innerhalb** von `build()`, nicht
/// nur außen in `main()` — sonst findet ein Test, der `RepitApp`
/// direkt pumpt (`main_provider_scope_test.dart`), keinen. Jedes
/// `ref.watch(...)` darunter (auch `dailyMetricsProvider` in `HeuteView`)
/// braucht genau diesen Container, den sonst nichts in `CupertinoApp`/
/// `RootView` von sich aus stellt.
///
/// Der fertig bestückte [behaelter] kommt deshalb als Parameter herein,
/// statt in `main()` einen zweiten Scope aufzuspannen: Zwei
/// ineinanderliegende Container hätten jeder ihre eigenen Instanzen, und
/// welcher gewinnt, hinge daran, auf welcher Ebene gelesen wird. Ohne
/// Argument — im Test — spannt die Klasse selbst einen leeren
/// `ProviderScope` auf und verhält sich wie zuvor.
///
/// Ein **Container** und keine Override-Liste, weil Riverpod 3.4.3 den Typ
/// `Override` nicht öffentlich exportiert: Eine Liste davon lässt sich
/// übergeben, aber kein Feld dieses Typs deklarieren. `ProviderContainer`
/// ist öffentlich, nimmt dieselben Overrides entgegen und lebt hier so
/// lange wie die App — deshalb wird er nicht entsorgt.
///
/// Mit [router] bekommt `RootView` diese Instanz, und [LiveWacht] hängt
/// die Live-Aktivität an (#369). **Ohne ihn bleibt alles wie vorher** —
/// so pumpt `main_provider_scope_test.dart` die Klasse, ohne Kanal und
/// ohne `liveAnzeigeProvider`.
class RepitApp extends StatelessWidget {
  const RepitApp({super.key, this.behaelter, this.router});

  final ProviderContainer? behaelter;

  final AppRouter? router;

  @override
  Widget build(BuildContext context) {
    // [Tageswacht] liegt **innerhalb** des Scopes (sie liest einen Provider)
    // und **außerhalb** der `CupertinoApp` (sie soll so lange leben wie die
    // App, nicht so lange wie ein Schirm): Kommt die App nach vorn, prüft
    // sie, ob inzwischen ein Berliner Kalendertag vergangen ist — sonst
    // zeigt „Heute" nach einer Nacht im Hintergrund weiter gestern (#124).
    //
    // **Hier hing bis zum Zusammenführen ein zweiter Wächter.** #194 hat
    // denselben Befund noch einmal gelöst (`TageswechselWaechter`); beim
    // Zusammenführen ist die Fassung aus #124 geblieben, weil nur sie
    // einen Test auf die Verdrahtung hier hat und `ref` ganz aus dem
    // Lebenszyklus-Rückruf heraushält. Abschnitt 1 der Spec zu #194 ist
    // damit erfüllt, nicht übergangen.
    //
    // [LiveWacht] sitzt aus demselben Grund an derselben Stelle, innerhalb
    // von `Tageswacht`. Die beiden sind zwei Belange, kein zweites Melden
    // desselben (Spec zu #369, „Verdrahtung"), und weil der Esstag die Uhr
    // selbst liest, kommt es auf ihre Reihenfolge nicht an.
    final eigenerRouter = router;
    final Widget app = eigenerRouter == null
        ? const Tageswacht(
            child: CupertinoApp(
              title: 'Flutter Rebuild',
              theme: CupertinoThemeData(primaryColor: Palette.river),
              home: RootView(),
            ),
          )
        : Tageswacht(
            child: LiveWacht(
              router: eigenerRouter,
              child: CupertinoApp(
                title: 'Flutter Rebuild',
                theme: const CupertinoThemeData(primaryColor: Palette.river),
                home: RootView(router: eigenerRouter),
              ),
            ),
          );
    final eigener = behaelter;
    return eigener == null
        ? ProviderScope(child: app)
        : UncontrolledProviderScope(container: eigener, child: app);
  }
}
