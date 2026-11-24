import 'dart:async';

// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL`),
// das mit `package:matcher`s `isNull`-Matcher kollidiert — dieselbe
// Begründung wie in `test/data/migration_test.dart` und
// `cache_repository_test.dart`. Hier zusätzlich gebraucht für `Value(...)`
// beim direkten Vorbelegen einer Cache-Zeile.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/tables.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'health_reading_attrappe.dart';

/// Tests für `health_provider.dart` (Task 13) — der Punkt, an dem Tims
/// gemeldeter Fehler tatsächlich verschwindet: „Er sieht beim Start seine
/// Schritte, navigiert herum, kommt zurück auf *Heute* — und dort steht 0."
/// (#55, „Das Schritte-Detail hängt").
///
/// Drei bereits gebaute Teile kommen hier zum ersten Mal zusammen (Spec 5.5):
/// `Messwert<T>`/`alsMesswert` (Task 5, drückt die vier Zustände aus),
/// `AppCache` (Task 6, hält den letzten Wert auf der Platte), `HealthReading`
/// (Task 7/12, liefert frische Daten über den Kanal). **Dieser Test prüft,
/// dass die Verbindung hält** — nicht nur, dass jedes Teil für sich
/// funktioniert.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// `lib/health/health_provider.dart` existiert noch nicht. Diese Datei legt
/// die API fest, gegen die gebaut wird, und darf ausgeführt, aber nicht
/// verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Fünf Top-Level-Bindungen, alle aus `health_provider.dart` exportiert.
/// Die genaue Notifier-Klasse dahinter (Name, `Notifier` vs. `AsyncNotifier`)
/// ist **nicht** festgelegt — nur das äußere Verhalten, das diese Tests
/// beobachten:
///
/// - `final healthProvider = Provider<HealthReading>(...)` — wirft ohne
///   Override (Spec: nur `main.dart` liefert die echte Quelle). Jeder Test
///   hier überschreibt ihn mit einer Fake-Quelle
///   (`overrideWithValue(zaehlendeQuelle)`, wörtlich aus
///   `task-13-brief.md`).
/// - `final appCacheProvider = Provider<AppCache>(...)` — ebenso, jeder Test
///   überschreibt ihn mit einer In-Memory-`AppCache`.
/// - `final dataWindowProvider = StateProvider<DataWindow>(...)` —
///   Default `DataWindow.unlimited`. Der Betrachtungszeitraum ist in Task 13
///   noch nicht an eine persistente Einstellung angebunden (das ist Task
///   11s `DataWindowSettings`); dieser Provider ist hier die **Stelle**, an
///   der `dailyMetricsProvider` seine Abhängigkeit bekommt — eine Festlegung
///   dieses Tests, siehe Dateikopf-Begründung weiter unten.
/// - `final clockProvider = Provider<DateTime Function()>(...)` — Default
///   `DateTime.now`. Entspricht dem `jetzt`-Parameter von `alsMesswert`
///   (Spec 5.3b: „deterministisch testbar, nie `DateTime.now()` direkt
///   aufrufen") — hier als Funktion, nicht als fester `DateTime`-Wert,
///   damit sie bei jedem Lauf frisch ausgewertet wird, nicht einmal pro
///   Container eingefroren ist.
/// - `final dailyMetricsProvider = AsyncNotifierProvider<..., Messwert<List<DailyMetrics>>>(...)`
///   — **ein** Provider für alle Schirme (`86` Punkt 1: `BodyStore` und
///   `EnduranceStore` holten bisher beide dieselben Tageswerte). Muss
///   `.future` unterstützen (`dailyMetricsProvider.future`, wörtlich aus
///   `task-13-brief.md`) **und** während seines `build()` einen
///   Zwischenzustand über `state =` ausgeben können, bevor es zurückkehrt —
///   das schließt einen reinen `FutureProvider` aus (der kennt kein `state =`
///   während des Ladens) und verlangt einen `(Async)Notifier` als Unterbau.
///
/// ### `.future` bedeutet „die erste Auflösung", nicht „das Endergebnis"
///
/// *(Nachtrag — ursprünglich prüften zwei Tests unten den Endzustand eines
/// Laufs mit Cache-Treffer über `await container.read(dailyMetricsProvider.
/// future)`. Der Implementierende meldete sie als unerfüllbar, belegt mit
/// sechs Experimenten gegen den Riverpod-Quellcode: In Riverpod 3.4.3 löst
/// `AsyncNotifier.future` mit dem **zuerst** ausgegebenen Wert auf und
/// friert ihn ein. Bei einem Provider, der absichtlich zweimal ausgibt —
/// erst den Cache-Treffer mit `laeuft: true`, dann das Ergebnis (Spec 5.5)
/// — bekommt ein `.future`-Zugriff nach Abschluss des Kanals deshalb die
/// **Zwischenausgabe**, nicht das Endergebnis. Das ist kein Timing-Problem,
/// das ein zusätzliches `pumpEventQueue()` beheben müsste, sondern eine
/// Verwechslung der Frage: `.future` beantwortet „was kam zuerst", nicht
/// „was steht am Ende".*
///
/// Daraus folgt eine klare Regel für diese Datei:
///
/// - **`.future` ist das richtige Werkzeug für „zwei gleichzeitige Leser
///   warten auf denselben Lauf"** (Pflichtfälle 1 und 2) — dort *ist* „die
///   erste Auflösung" genau die Frage: Beide Leser sollen dieselbe
///   bekommen, keiner einen eigenen zweiten Lauf. Ebenso unbedenklich,
///   solange **kein** Cache-Eintrag vorliegt (Pflichtfall 4, der
///   Fehlgeschlagen-Fall ohne Cache, der erste Lauf im
///   Zurückschreiben-Test) — ohne Cache-Treffer gibt es keine
///   Zwischenausgabe, „erste" und „letzte" Ausgabe sind dieselbe.
/// - **Sobald ein Cache-Treffer eine Zwischenausgabe erzeugt** (Pflichtfall
///   3, der Fehlgeschlagen-Fall *mit* Cache), wird der **Endzustand über
///   den Listener gelesen** (`beobachtet.last`), nicht über `.future` — an
///   derselben Quelle, aus der auch die Zustandsfolge stammt, statt mit
///   einem Werkzeug, das eine andere Frage beantwortet.
///
/// Getestet wird die Zustandsfolge selbst immer über
/// `container.listen(dailyMetricsProvider, ...)`, **nie** über `.future` —
/// sonst bewiese der Test nur eine einzelne Ausgabe, nicht die Reihenfolge
/// aus Spec 5.5, und genau die Reihenfolge ist Tims Fehler.
///
/// `hourlyStepsProvider`, `sleepProvider`, `workoutsProvider` und
/// `nutritionProvider` aus den Interfaces von `task-13-brief.md` werden
/// **hier nicht geprüft** — bewusste Lücke, Begründung im Abschnitt „Was
/// bewusst nicht abgedeckt wird" unten.
///
/// `CacheRepository` (die Lese-/Schreib-Brücke zu `AppCache`) hat ihre
/// eigene Testdatei, `cache_repository_test.dart` — hier wird nur noch
/// geprüft, dass `dailyMetricsProvider` sie tatsächlich benutzt (per
/// direkter Prüfung der `tages_werte`-Tabelle, nicht über einen Mock der
/// Brücke selbst, um keine zwei Tests auf unterschiedlichen
/// Abstraktionsebenen über *dieselbe* Annahme auseinanderlaufen zu lassen).
///
/// ## Warum `dataWindowProvider` und `clockProvider` hier neu entstehen
///
/// Spec 5.7/Task 4 sagen „die App hält das Fenster in einem
/// Riverpod-Provider" und verlangen `==`/`hashCode` auf `DataWindow` genau
/// dafür — aber **keine** bisherige Aufgabe legt den Namen dieses Providers
/// fest, weil vor Task 13 noch kein echter Provider im Projekt existiert.
/// Dasselbe gilt für eine injizierbare Uhr. Beide Namen sind deshalb eine
/// Festlegung dieser Testdatei, keine Entdeckung einer bereits getroffenen
/// Entscheidung — im Bericht als solche gekennzeichnet.
///
/// ## Was bewusst nicht abgedeckt wird
///
/// - **`hourlyStepsProvider`/`sleepProvider`/`workoutsProvider`/`nutritionProvider`.**
///   Für Tageswerte legt Spec 5.5/5.6 die Ladereihenfolge und die
///   Cache-Tabelle (`TagesWerte`) konkret fest — für die anderen drei Typen
///   gibt es (Stand Task 6) gar keine Cache-Tabelle, nur `StundenSchritte`
///   zusätzlich zu `TagesWerte`. Tests für Provider, deren Cache-Strategie
///   die Spec nicht festlegt, würden eigene Annahmen erfinden statt eine
///   bestehende Vorgabe zu prüfen — das Risiko, dem Implementierenden damit
///   eine falsche Festlegung unterzuschieben, wiegt hier schwerer als die
///   Lücke. `hourlyStepsProvider` dürfte strukturell analog zu
///   `dailyMetricsProvider` sein (eigene Tabelle `StundenSchritte` liegt
///   vor); das ist aber eine Vermutung, kein geprüfter Vertrag.
/// - **Die Wiederholungsregel für gescheiterte Läufe in der echten App**
///   (Spec 5.3c). Für Tests ist `retry: (_, __) => null` vorgeschrieben und
///   wird unten überall gesetzt — eine Regel *für die App* zu testen hieße,
///   eine Entscheidung festzuschreiben, die die Spec ausdrücklich als noch
///   offen markiert. Meine Einschätzung dazu steht im Bericht, nicht in
///   einem Test.
/// - **`riverpod_lint`, ob `ref` nur in `build`/Notifiern vorkommt**
///   (`task-13-brief.md`, Schritt 5). Das ist eine Werkzeug-Prüfung für den
///   Implementierenden, kein Verhalten, das ein `flutter test` feststellen
///   könnte.
void main() {
  // Ein fester Zeitpunkt, nicht `DateTime.now()` — sonst wäre ein Vergleich
  // mit `clockProvider` in jedem Testlauf ein neuer Zufallswert (Spec 5.3b).
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);

  group('Pflichtfall 1 (task-13-brief.md) — zwei gleichzeitige Leser', () {
    test(
      'loesen genau einen Lauf aus, der zweite wartet statt zu '
      'ueberspringen (Review Focus 2; Spec 5.1)',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        // Die Quelle antwortet erst, wenn der Test es erlaubt — sonst
        // bewiese `aufrufe == 1` nichts darüber, ob der zweite Leser
        // tatsächlich auf einen *laufenden* Vorgang traf oder nur zufällig
        // schnell genug war.
        final darfAntworten = Completer<void>();
        final zaehlendeQuelle = _FakeHealthReading(
          dailyMetricsAntwort: () async {
            await darfAntworten.future;
            return const [DailyMetrics(tag: '2026-10-20', steps: 1234)];
          },
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appCacheProvider.overrideWithValue(db),
            healthProvider.overrideWithValue(zaehlendeQuelle),
            clockProvider.overrideWithValue(() => jetzt),
          ],
        );
        addTearDown(container.dispose);

        final beide = Future.wait([
          container.read(dailyMetricsProvider.future),
          container.read(dailyMetricsProvider.future),
        ]);

        // Erst jetzt darf der Lauf fertig werden — genau in diesem Fenster
        // läge der alte Swift-Fehler: ein zweiter, eigener Lauf hätte hier
        // schon gezählt.
        await pumpEventQueue();
        darfAntworten.complete();
        await beide;

        expect(
          zaehlendeQuelle.aufrufe,
          1,
          reason:
              'nicht 2 — der zweite Leser hat wartet, statt einen eigenen '
              'Lauf zu starten',
        );
      },
    );
  });

  group('Pflichtfall 2 (task-13-brief.md) — der zweite Aufrufer', () {
    test(
      'bekommt Daten, nicht null — der heutige Swift-Fehler war '
      '"guard !isLoading else { return }": der zweite Store lief ohne '
      'Daten weiter',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final quelle = _FakeHealthReading(
          dailyMetricsAntwort: () async =>
              const [DailyMetrics(tag: '2026-10-20', steps: 1234)],
        );

        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appCacheProvider.overrideWithValue(db),
            healthProvider.overrideWithValue(quelle),
            clockProvider.overrideWithValue(() => jetzt),
          ],
        );
        addTearDown(container.dispose);

        final ergebnisse = await Future.wait([
          container.read(dailyMetricsProvider.future),
          container.read(dailyMetricsProvider.future),
        ]);

        for (final ergebnis in ergebnisse) {
          expect(
            ergebnis,
            isA<Bekannt<List<DailyMetrics>>>(),
            reason: 'kein Aufrufer bekommt null oder NochNie, obwohl Daten '
                'vorliegen',
          );
        }
        expect(
          identical(ergebnisse[0], ergebnisse[1]),
          isTrue,
          reason: 'beide Aufrufer hängen an derselben Future-Instanz — es '
              'gibt keinen zweiten Lauf, dessen Ergebnis auseinanderlaufen '
              'könnte',
        );
      },
    );
  });

  group(
    'Pflichtfall 3 (task-13-brief.md) — Ladereihenfolge aus Spec 5.5, '
    'als Folge beobachtet, nicht nur als Endzustand',
    () {
      test(
        'aus dem Cache kommt sofort Bekannt mit laeuft:true, danach '
        'Bekannt mit laeuft:false — zwischen beiden steht nie NochNie '
        '(genau das wäre Tims "Heute zeigt 0")',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final cacheStand = DateTime.utc(2026, 10, 20, 9, 0);
          await db
              .into(db.tagesWerte)
              .insert(
                TagesWerteCompanion.insert(
                  tag: '2026-10-20',
                  schritte: const Value(4200),
                  gelesenAm: Value(cacheStand),
                ),
              );

          // Die Quelle hängt fest, bis der Test sie löst — so lässt sich
          // der Zwischenzustand (Cache gelesen, Kanal noch nicht fertig)
          // zuverlässig einfangen, statt auf Zufallstiming zu hoffen.
          final kanalAntwort = Completer<List<DailyMetrics>>();
          final quelle = _FakeHealthReading(
            dailyMetricsAntwort: () => kanalAntwort.future,
          );

          final beobachtet = <AsyncValue<Messwert<List<DailyMetrics>>>>[];
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(quelle),
              clockProvider.overrideWithValue(() => jetzt),
            ],
          );
          addTearDown(container.dispose);

          container.listen(
            dailyMetricsProvider,
            (prev, next) => beobachtet.add(next),
            fireImmediately: true,
          );

          // Lässt den Cache-Lauf (drift, async über das DB-Isolate) zu
          // Ende laufen, ohne dass der Kanal (noch im Completer gefangen)
          // fertig wird.
          await pumpEventQueue();

          expect(
            beobachtet.whereType<AsyncData<Messwert<List<DailyMetrics>>>>(),
            isNotEmpty,
            reason:
                'nach dem Cache-Lauf muss mindestens eine Ausgabe vorliegen '
                '— sonst zeigt die Oberfläche in dieser Zeitspanne nichts '
                'an, obwohl ein Wert bekannt ist',
          );

          final nachCache = beobachtet
              .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
              .last
              .value;
          expect(
            nachCache,
            isA<Bekannt<List<DailyMetrics>>>(),
            reason: 'Spec 5.5: der Cache-Treffer wird sofort als Bekannt '
                'ausgegeben, bevor der Kanal überhaupt geantwortet hat',
          );
          final bekanntWaehrendLauf = nachCache as Bekannt<List<DailyMetrics>>;
          expect(bekanntWaehrendLauf.laeuft, isTrue);
          expect(bekanntWaehrendLauf.stand, cacheStand);
          expect(bekanntWaehrendLauf.wert.single.steps, 4200);

          expect(
            beobachtet
                .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
                .map((d) => d.value)
                .whereType<NochNie<List<DailyMetrics>>>(),
            isEmpty,
            reason:
                'Tims Fehler in einem Satz: zwischen den beiden '
                'Bekannt-Ausgaben darf nie NochNie stehen, solange ein '
                'Cache vorliegt',
          );

          // Jetzt darf der Kanal antworten — der Lauf wird fertig.
          kanalAntwort.complete(
            const [DailyMetrics(tag: '2026-10-20', steps: 5500)],
          );
          await pumpEventQueue();

          // **Nicht `.future`.** Dieser Provider gibt bei einem
          // Cache-Treffer absichtlich zweimal aus (Spec 5.5): erst
          // Bekannt(laeuft:true), dann das Endergebnis. In Riverpod 3.4.3
          // löst `AsyncNotifier.future` mit der **ersten** ausgegebenen
          // Ausgabe auf und friert sie ein — ein `.future`-Zugriff an
          // dieser Stelle bekäme also die Bekannt(laeuft:true)-
          // Zwischenausgabe von oben zurück, nicht das Endergebnis.
          // `.future` beantwortet „was wurde zuerst ausgegeben", nicht
          // „was steht am Ende" — bei einem zweistufigen Provider sind das
          // zwei verschiedene Fragen (sechs Experimente des
          // Implementierenden gegen den Riverpod-Quellcode haben das
          // belegt, siehe `task-13-tests-report.md`). Der Listener, der die
          // Folge oben schon mitschreibt, ist deshalb auch hier das
          // richtige Werkzeug für den Endzustand — dieselbe Quelle, aus der
          // auch die Zwischenausgabe kam, nicht ein zweites, falsch
          // passendes Werkzeug.
          final endgueltig = beobachtet
              .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
              .last
              .value;

          expect(endgueltig, isA<Bekannt<List<DailyMetrics>>>());
          final bekanntFertig = endgueltig as Bekannt<List<DailyMetrics>>;
          expect(bekanntFertig.laeuft, isFalse);
          expect(bekanntFertig.wert.single.steps, 5500);
          expect(
            bekanntFertig.stand,
            jetzt,
            reason: 'ein frisch geholter Wert trägt "jetzt" als Stand '
                '(Spec 5.3d), nicht den alten Cache-Stand',
          );
        },
      );
    },
  );

  group(
    'Pflichtfall 4 (task-13-brief.md) — ohne Cache, leeres Ergebnis',
    () {
      test(
        'ergibt LeerNachLauf, nie Bekannt mit einer leeren Liste (Spec '
        '5.3/5.3d)',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final quelle = _FakeHealthReading(
            dailyMetricsAntwort: () async => const <DailyMetrics>[],
          );

          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(quelle),
              clockProvider.overrideWithValue(() => jetzt),
            ],
          );
          addTearDown(container.dispose);

          final ergebnis = await container.read(dailyMetricsProvider.future);

          expect(ergebnis, isA<LeerNachLauf<List<DailyMetrics>>>());
          expect(
            (ergebnis as LeerNachLauf<List<DailyMetrics>>).gelaufen,
            jetzt,
          );
        },
      );
    },
  );

  group(
    'Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg (Spec '
    '5.3a, Tims Beschwerde eine Ebene höher)',
    () {
      test(
        'mit Cache bleibt das Ergebnis Bekannt(laeuft:false) mit dem '
        'alten Wert, nicht Fehlgeschlagen',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final cacheStand = DateTime.utc(2026, 10, 20, 9, 0);
          await db
              .into(db.tagesWerte)
              .insert(
                TagesWerteCompanion.insert(
                  tag: '2026-10-20',
                  schritte: const Value(4200),
                  gelesenAm: Value(cacheStand),
                ),
              );
          final quelle = _FakeHealthReading(
            dailyMetricsAntwort: () async =>
                throw Exception('HealthKit nicht erreichbar'),
          );

          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(quelle),
              clockProvider.overrideWithValue(() => jetzt),
            ],
          );
          addTearDown(container.dispose);

          // **Nicht `.future`** — derselbe Grund wie bei Pflichtfall 3: Ein
          // Cache liegt vor, also gibt der Provider zwischendurch
          // Bekannt(laeuft:true) aus, bevor der gescheiterte Kanal-Versuch
          // das Endergebnis liefert. `.future` friert in Riverpod 3.4.3 die
          // **erste** Ausgabe ein — hier die Zwischenausgabe, nicht das,
          // was diese Aussage eigentlich meint ("am Ende bleibt
          // Bekannt(laeuft:false) stehen"). Der Listener liest denselben
          // Endzustand an der Quelle, aus der auch die Folge käme, statt
          // mit dem falschen Werkzeug nach ihm zu fragen.
          final beobachtet = <AsyncValue<Messwert<List<DailyMetrics>>>>[];
          container.listen(
            dailyMetricsProvider,
            (prev, next) => beobachtet.add(next),
            fireImmediately: true,
          );
          await pumpEventQueue();

          final ergebnis = beobachtet
              .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
              .last
              .value;

          expect(
            ergebnis,
            isNot(isA<Fehlgeschlagen<List<DailyMetrics>>>()),
            reason:
                'ein gescheiterter Nachlauf darf einen sichtbaren Wert '
                'nicht wegnehmen',
          );
          expect(ergebnis, isA<Bekannt<List<DailyMetrics>>>());
          final bekannt = ergebnis as Bekannt<List<DailyMetrics>>;
          expect(bekannt.laeuft, isFalse);
          expect(bekannt.wert.single.steps, 4200);
          expect(bekannt.stand, cacheStand);
        },
      );

      test(
        'ohne Cache wird das Ergebnis Fehlgeschlagen, nicht NochNie und '
        'nicht Bekannt mit erfundenem Wert',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final quelle = _FakeHealthReading(
            dailyMetricsAntwort: () async =>
                throw Exception('HealthKit nicht erreichbar'),
          );

          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(quelle),
              clockProvider.overrideWithValue(() => jetzt),
            ],
          );
          addTearDown(container.dispose);

          final ergebnis = await container.read(dailyMetricsProvider.future);

          expect(ergebnis, isA<Fehlgeschlagen<List<DailyMetrics>>>());
          expect(
            (ergebnis as Fehlgeschlagen<List<DailyMetrics>>).gelaufen,
            jetzt,
          );
        },
      );
    },
  );

  group(
    'Zurückschreiben in den Cache (Spec 5.5 letzter Satz) und ein kalter '
    'Neustart',
    () {
      test(
        'nach einem erfolgreichen Lauf trägt die Zeile ein gelesenAm, und '
        'ein neuer Container (Kaltstart) findet den Wert, ohne auf einen '
        'eigenen, absichtlich nie abschließenden Kanal zu warten',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          final ersterContainer = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(
                _FakeHealthReading(
                  dailyMetricsAntwort: () async =>
                      const [DailyMetrics(tag: '2026-10-20', steps: 7777)],
                ),
              ),
              clockProvider.overrideWithValue(() => jetzt),
            ],
          );
          addTearDown(ersterContainer.dispose);

          final ersteRunde = await ersterContainer.read(
            dailyMetricsProvider.future,
          );
          expect(ersteRunde, isA<Bekannt<List<DailyMetrics>>>());

          final zeile =
              await (db.select(
                db.tagesWerte,
              )..where((t) => t.tag.equals('2026-10-20'))).getSingle();
          expect(zeile.schritte, 7777);
          expect(
            zeile.gelesenAm,
            jetzt,
            reason:
                'Spec 5.3b: der Stand steht je Zeile, nicht als ein '
                'globaler Zeitstempel für den ganzen Cache — hier aus dem '
                'gerade erfolgreichen Lauf',
          );

          // Zweiter, unabhängiger Container == Kaltstart nach einem
          // Neustart der App. Der Kanal hängt absichtlich für immer fest:
          // Ob der erste sichtbare Zustand den Wert zeigt, hängt damit
          // beweiskräftig am Cache, nicht an einem zufällig schnellen
          // zweiten Kanal-Lauf.
          final haengtFest = Completer<List<DailyMetrics>>();
          final zweiterContainer = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(
                _FakeHealthReading(dailyMetricsAntwort: () => haengtFest.future),
              ),
              clockProvider.overrideWithValue(
                () => jetzt.add(const Duration(minutes: 5)),
              ),
            ],
          );
          addTearDown(zweiterContainer.dispose);

          final beobachtet = <AsyncValue<Messwert<List<DailyMetrics>>>>[];
          zweiterContainer.listen(
            dailyMetricsProvider,
            (prev, next) => beobachtet.add(next),
            fireImmediately: true,
          );
          await pumpEventQueue();

          final ersteAusgabeNachCache = beobachtet
              .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
              .first
              .value;
          expect(ersteAusgabeNachCache, isA<Bekannt<List<DailyMetrics>>>());
          final bekannt =
              ersteAusgabeNachCache as Bekannt<List<DailyMetrics>>;
          expect(
            bekannt.wert.single.steps,
            7777,
            reason:
                'der kalte Neustart findet den zurückgeschriebenen Wert '
                'aus dem ersten Container, ohne dass der (hier absichtlich '
                'hängende) Kanal je geantwortet hätte',
          );
          expect(bekannt.laeuft, isTrue);
          expect(bekannt.stand, jetzt);
        },
      );
    },
  );

  group(
    'DataWindow als Abhängigkeit (Spec 5.2/5.7, Task 4 == und hashCode)',
    () {
      test(
        'ein tatsächlich geändertes Fenster löst einen neuen Lauf aus; '
        'ein gleich bleibendes Fenster — auch als neu konstruiertes Objekt '
        '— nicht',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final quelle = _FakeHealthReading(
            dailyMetricsAntwort: () async =>
                const [DailyMetrics(tag: '2026-10-20', steps: 1)],
          );

          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              appCacheProvider.overrideWithValue(db),
              healthProvider.overrideWithValue(quelle),
              clockProvider.overrideWithValue(() => jetzt),
              dataWindowProvider.overrideWith(
                (ref) => DataWindow(start: DateTime.utc(2026, 9, 1)),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(dailyMetricsProvider.future);
          expect(quelle.aufrufe, 1, reason: 'Testvoraussetzung');

          // Ein neues Objekt, aber derselbe Kalendertag: laut `DataWindow.
          // ==` (Task 4) gleich. Kein Rebuild fällig.
          container.read(dataWindowProvider.notifier).state = DataWindow(
            start: DateTime.utc(2026, 9, 1),
          );
          await pumpEventQueue();
          expect(
            quelle.aufrufe,
            1,
            reason:
                'ein gleich bleibendes Fenster darf keinen neuen Lauf '
                'auslösen, auch wenn das Objekt neu konstruiert wurde — '
                'sonst wäre jeder Widget-Rebuild, der zufällig ein neues '
                'DataWindow baut, ein neuer HealthKit-Zugriff (Fehlermuster '
                '`03`, Spec 5.2)',
          );

          // Ein tatsächlich anderes Fenster: Rebuild ist fällig.
          container.read(dataWindowProvider.notifier).state = DataWindow(
            start: DateTime.utc(2026, 10, 1),
          );
          await container.read(dailyMetricsProvider.future);
          expect(
            quelle.aufrufe,
            2,
            reason: 'ein echt geändertes Fenster löst einen neuen Lauf aus',
          );
        },
      );
    },
  );
}

/// Konfigurierbare Test-Quelle für `HealthReading`. Implementiert alle
/// sieben Methoden des Protokolls (Task 12) — nur `dailyMetrics` ist für die
/// Tests oben von Belang, die übrigen sechs liefern leere Listen/Defaults,
/// weil `dailyMetricsProvider` sie laut Spec 5.5 nicht braucht.
///
/// `aufrufe` zählt jeden tatsächlichen Aufruf von `dailyMetrics` — das ist
/// „die zählende Quelle" aus `task-13-brief.md` (dort `zaehlendeQuelle`
/// genannt; hier als wiederverwendbare Klasse gebaut, weil mehrere Tests
/// eine Variante davon brauchen: zählend, künstlich verzögert, leer,
/// gescheitert — alles dieselbe Form, nur eine andere `dailyMetricsAntwort`).
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading({
    required FutureOr<List<DailyMetrics>> Function() dailyMetricsAntwort,
  }) : _dailyMetricsAntwort = dailyMetricsAntwort;

  final FutureOr<List<DailyMetrics>> Function() _dailyMetricsAntwort;

  int aufrufe = 0;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) async {
    aufrufe += 1;
    return await _dailyMetricsAntwort();
  }
}
