import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';

/// Tests für `heuteZustandAusProvider` (`lib/shell/heute_view.dart`) — die
/// Antwort dieses Tasks auf die offene Frage aus `task-13-report.md`:
///
/// > Ohne Cache-Treffer gibt der Provider KEINEN Messwert-Zwischenwert aus
/// > — ein Beobachter sieht dort das rohe Riverpod-`AsyncLoading`, nicht
/// > `NochNie`. Der Zustand des Providers ist damit
/// > `AsyncValue<Messwert<T>>`, also zwei Zustandsebenen. Wie eine View
/// > „lädt ohne Cache" von „lädt mit Cache" unterscheidet, OHNE eine zweite
/// > `AsyncValue`→`Messwert`-Übersetzungsstelle zu bauen, ist offen und
/// > gehört zum Schirm-Task.
///
/// `dailyMetricsProvider` (`lib/health/health_provider.dart`) ist ein
/// `AsyncNotifierProvider<DailyMetricsNotifier, Messwert<List<DailyMetrics>>>`
/// — `ref.watch(dailyMetricsProvider)` liefert deshalb nicht direkt einen
/// `Messwert`, sondern `AsyncValue<Messwert<List<DailyMetrics>>>`: eine
/// `AsyncValue`-Hülle **um** einen `Messwert` herum.
///
/// ## Die Entscheidung
///
/// `heuteZustandAusProvider` ist **kein** zweites `alsMesswert`
/// (`lib/core/async_bruecke.dart`) — es kennt keinen Cache-Parameter, kein
/// `jetzt`, kein `istLeer`, und trifft damit keine der sechs fachlichen
/// Entscheidungen aus dessen Tabelle neu. Es ist ein einziges, reines
/// Durchreichen mit Rückfall:
///
/// ```dart
/// Messwert<List<DailyMetrics>> heuteZustandAusProvider(
///   AsyncValue<Messwert<List<DailyMetrics>>> zustand,
/// ) => zustand.value ?? const NochNie();
/// ```
///
/// (`AsyncValue.value` ist in Riverpod 3.4.3 bereits die nullbare
/// „letzter bekannter Wert, egal ob gerade geladen/gescheitert"-Stelle —
/// siehe `package:riverpod/src/core/async_value.dart:557`. Es gibt in dieser
/// Fassung kein zusätzliches `valueOrNull`, `.value` **ist** es.)
///
/// ## Warum das reicht
///
/// `DailyMetricsNotifier.build()` (Task 13) gibt **niemals** eine rohe
/// `AsyncLoading`/`AsyncError` als eigenes Ergebnis zurück — jeder
/// Zwischen- und Endzustand ist bereits ein vollständig klassifizierter
/// `Messwert` (`alsMesswert` hat das schon entschieden, *bevor* der Wert
/// den Notifier über `state =`/den Rückgabewert verlässt, siehe
/// `health_provider.dart`). Die äußere `AsyncValue`-Hülle hat für
/// `HeuteView` deshalb nur zwei Fälle:
///
/// - **Sie trägt bereits einen `Messwert`** (`.value != null`, unabhängig
///   davon, ob `isLoading`/`hasError` nebenbei auch wahr sind — das kann in
///   Riverpod gleichzeitig gelten, Spec 5.3e) — dann gilt genau dieser
///   `Messwert`, unverändert.
/// - **Sie trägt noch keinen** (`.value == null`) — dann ist fachlich
///   nichts bekannt, also `NochNie`. Das deckt den dokumentierten
///   Lücke-Fall ab (reines `AsyncLoading`, bevor der erste Cache-Treffer
///   oder das erste Kanalergebnis über `state =`/den Rückgabewert
///   geschrieben wurde) **und** einen Fall, den `DailyMetricsNotifier`
///   heute nicht erzeugt, aber erzeugen könnte: `build()` wirft selbst,
///   bevor es überhaupt zu einem `Messwert` kommt (z. B. ein Fehler beim
///   Cache-Lesen, außerhalb des Kanal-`try`/`catch` in
///   `health_provider.dart`). So ein Absturz ist kein von
///   `DailyMetricsNotifier` **vorgesehener** Fehlerpfad — jeder vorgesehene
///   Kanalfehler ist schon als `Fehlgeschlagen` im `Messwert` selbst
///   verpackt. Ihn trotzdem als `NochNie` statt als fünften/sechsten, neu
///   erfundenen Zustand zu behandeln, hält das Vokabular auf die vier in
///   `messwert.dart` deklarierten Fälle beschränkt, statt einen Riverpod-
///   Sonderfall in die Oberfläche durchsickern zu lassen.
///
/// ## Warum das KEINE zweite `AsyncValue`→`Messwert`-Übersetzungsstelle ist
///
/// `alsMesswert` trifft sechs verschiedene, fachlich begründete
/// Entscheidungen (Cache da/nicht da, kreuzweise mit lädt/Fehler/fertig) und
/// braucht dafür `cache`/`jetzt`/`istLeer`. `heuteZustandAusProvider` trifft
/// **keine** einzige davon neu — es reicht einen bereits fertig
/// klassifizierten `Messwert` nur noch durch eine zusätzliche, von Riverpod
/// selbst auferlegte Hülle hindurch. Eine zweite Übersetzungsstelle läge nur
/// vor, wenn diese Funktion selbst zwischen Cache und Nicht-Cache, zwischen
/// „lädt" und „gescheitert" usw. unterscheiden müsste — das tut sie nicht,
/// das hat `alsMesswert` längst erledigt.
///
/// ## Was hier bewusst nicht geprüft wird
///
/// Riverpods `copyWithPrevious`/`isRefreshing` (ein `AsyncValue`, das
/// während eines erneuten Ladens den *vorherigen* Wert mitträgt) wird hier
/// nicht konstruiert: Diese API ist in `riverpod-3.4.3` mit `@internal`
/// markiert, und `DailyMetricsNotifier` erzeugt sie an keiner Stelle selbst
/// (sie weist ihren Zwischenwert immer über ein vollständiges, eigenes
/// `AsyncData(...)` zu, nie über `copyWithPrevious`). Ein Test dafür prüfte
/// also einen Zustand, den der echte Provider nie erzeugt.
void main() {
  group('heuteZustandAusProvider', () {
    test(
      'ohne jeden Wert (reines Laden, z. B. ohne Cache-Treffer) wird '
      'NochNie',
      () {
        final ergebnis = heuteZustandAusProvider(
          const AsyncValue<Messwert<List<DailyMetrics>>>.loading(),
        );

        expect(ergebnis, isA<NochNie<List<DailyMetrics>>>());
      },
    );

    test(
      'ein Fehler ganz ohne vorherigen Wert wird ebenfalls NochNie, kein '
      'neu erfundener fünfter Zustand',
      () {
        final ergebnis = heuteZustandAusProvider(
          AsyncValue<Messwert<List<DailyMetrics>>>.error(
            Exception('build() ist selbst gescheitert, außerhalb jedes '
                'Kanal-try/catch'),
            StackTrace.empty,
          ),
        );

        expect(ergebnis, isA<NochNie<List<DailyMetrics>>>());
      },
    );

    test(
      'ein Bekannt-Zwischenwert (Cache-Treffer, laeuft:true) kommt '
      'unverändert durch — dieselbe Instanz, keine Kopie',
      () {
        final bekannt = Bekannt<List<DailyMetrics>>(
          const [DailyMetrics(tag: '2026-10-20', steps: 842)],
          stand: DateTime.utc(2026, 10, 20, 9, 0),
          laeuft: true,
        );

        final ergebnis = heuteZustandAusProvider(
          AsyncValue<Messwert<List<DailyMetrics>>>.data(bekannt),
        );

        expect(identical(ergebnis, bekannt), isTrue);
      },
    );

    test(
      'ein Bekannt-Endergebnis (laeuft:false) kommt unverändert durch',
      () {
        final bekannt = Bekannt<List<DailyMetrics>>(
          const [DailyMetrics(tag: '2026-10-20', steps: 842)],
          stand: DateTime.utc(2026, 10, 20, 14, 32),
          laeuft: false,
        );

        final ergebnis = heuteZustandAusProvider(
          AsyncValue<Messwert<List<DailyMetrics>>>.data(bekannt),
        );

        expect(identical(ergebnis, bekannt), isTrue);
      },
    );

    test('LeerNachLauf kommt unverändert durch', () {
      final leer = LeerNachLauf<List<DailyMetrics>>(
        gelaufen: DateTime.utc(2026, 10, 20, 14, 32),
      );

      final ergebnis = heuteZustandAusProvider(
        AsyncValue<Messwert<List<DailyMetrics>>>.data(leer),
      );

      expect(identical(ergebnis, leer), isTrue);
    });

    test('Fehlgeschlagen kommt unverändert durch', () {
      final fehlgeschlagen = Fehlgeschlagen<List<DailyMetrics>>(
        fehler: Exception('Kanal nicht erreichbar'),
        gelaufen: DateTime.utc(2026, 10, 20, 14, 32),
      );

      final ergebnis = heuteZustandAusProvider(
        AsyncValue<Messwert<List<DailyMetrics>>>.data(fehlgeschlagen),
      );

      expect(identical(ergebnis, fehlgeschlagen), isTrue);
    });
  });
}
