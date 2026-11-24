import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'health_reading_attrappe.dart';

/// Tests für **den Tageswechsel** — Nachtrag zu `sleep_provider_test.dart`
/// und `health_provider_test.dart` nach einem Review-Befund vom 27.10.2026
/// (Befund G).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `rechenfensterProvider` holt `jetzt` im Provider-Rumpf
/// (`ref.watch(clockProvider)()`). `clockProvider` ist ein Provider über
/// eine **Funktion**, und die ändert sich nie — ein `Provider` rechnet
/// deshalb nie neu, und das Fenster bleibt auf dem Tag stehen, an dem es
/// zum ersten Mal gelesen wurde. Läuft eine Sitzung über Mitternacht,
/// rechnen Ampel und Diagramm weiter auf dem Vortag, und `sleepProvider`
/// fragt den Kanal mit einem `bis`, das gestern endet: **die Nacht, die Tim
/// gerade hinter sich hat, kommt nie an.** Dasselbe gilt für das eingefrorene
/// `jetzt` in `SleepNotifier.build()` und `DailyMetricsNotifier.build()`.
///
/// Das ist derselbe Fehlertyp wie `01`: Daten sind da, die App sagt, es
/// seien keine da.
///
/// ## Verlangte API-Änderung: ein Provider für den heutigen Tag
///
/// Eine injizierbare Uhr reicht dafür nicht. Riverpod rechnet Abgeleitetes
/// neu, wenn sich eine **Abhängigkeit** ändert; eine Funktion, die bei
/// jedem Aufruf etwas anderes liefert, ist keine Änderung, die Riverpod
/// sehen kann. Umgekehrt wäre ein Provider, der die Uhrzeit selbst trägt,
/// Fehler `03`: jede Sekunde ein neuer Wert, jedes Bild eine neue Rechnung.
///
/// Gebraucht wird genau das Dazwischen — ein Wert, der sich **nur beim
/// Kalendertagswechsel** ändert. In `lib/health/health_provider.dart`,
/// neben `clockProvider`:
///
/// ```dart
/// /// Der Berliner Kalendertag, auf den die App gerade rechnet, als
/// /// Tagesbeginn (`BerlinCalendar.startOfDay`).
/// final heutigerTagProvider =
///     NotifierProvider<HeutigerTagNotifier, DateTime>(
///       HeutigerTagNotifier.new,
///     );
///
/// class HeutigerTagNotifier extends Notifier<DateTime> {
///   @override
///   DateTime build();
///
///   /// Liest die Uhr neu. Hat sich der Berliner Kalendertag geändert,
///   /// ändert sich der Zustand — und alles, was ihn beobachtet, rechnet
///   /// neu. Ist es derselbe Tag, passiert **nichts**.
///   void pruefeTageswechsel();
/// }
/// ```
///
/// `rechenfensterProvider`, `SleepNotifier.build()` und
/// `DailyMetricsNotifier.build()` beobachten ihn. `clockProvider` bleibt,
/// wo er ist: Innerhalb eines Laufs wird weiter die genaue Uhrzeit
/// gebraucht (`jetzt` als obere Kanalgrenze, `gelesenAm` als Stand) — nur
/// die Frage „welcher Tag ist heute?" darf nicht mehr an einer Funktion
/// hängen, deren Ergebnis niemand beobachtet.
///
/// Denselben Provider verlangte Befund C, geprüft in
/// `test/data/tagesgefuehl_tageswechsel_test.dart` — die Datei ist mit dem
/// Tagesgefühl entfallen (#269). **Ein Begriff, ein Provider** bleibt: zwei
/// Stellen, die unabhängig voneinander bestimmen, welcher Tag heute ist,
/// sind genau die Bauart, aus der beide Befunde entstanden sind.
///
/// **Wer `pruefeTageswechsel()` aufruft, entscheidet der Schirm** (#115):
/// App-Lebenszyklus, ein Ticker, ein `WidgetsBindingObserver`. Das ist eine
/// Entscheidung der Widget-Schicht und gehört in deren Ticket. Diese Datei
/// prüft, dass der Weg existiert und richtig wirkt — nicht, wer ihn geht.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Ein Tageswechsel mitten in einem laufenden Kanal-Aufruf.** Riverpod
///   verwirft den alten Lauf und startet einen neuen; welche der beiden
///   Antworten zuletzt in den Cache schreibt, hängt an Riverpods eigener
///   Reihenfolge und nicht an unserem Code. Ein Test darauf prüfte das
///   Framework.
/// - **Die Zeitumstellung.** Die trägt `BerlinCalendar` und ist dort
///   geprüft; hier geht es nur darum, dass der Tageswechsel überhaupt
///   ankommt.
///
/// **Alle Zahlen und Antworten hier sind erfunden.**
void main() {
  // 27.10.2026, 22:50 UTC = 23:50 Berliner Zeit (Winterzeit, die Umstellung
  // war am 25.10.).
  final kurzVorMitternacht = DateTime.utc(2026, 10, 27, 22, 50);

  // 27.10.2026, 23:05 UTC = 00:05 Berliner Zeit am 28.10.
  final kurzNachMitternacht = DateTime.utc(2026, 10, 27, 23, 5);

  final tagesbeginn27 = BerlinCalendar.startOfDay(
    DateTime.utc(2026, 10, 27, 12),
  );
  final tagesbeginn28 = BerlinCalendar.startOfDay(
    DateTime.utc(2026, 10, 28, 12),
  );

  ({
    ProviderContainer behaelter,
    void Function(DateTime) stelleUhr,
    _FakeHealthReading quelle,
  })
  aufbau({DateTime? start}) {
    var jetzt = start ?? kurzVorMitternacht;
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final quelle = _FakeHealthReading();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return (
      behaelter: container,
      stelleUhr: (neu) => jetzt = neu,
      quelle: quelle,
    );
  }

  group('heutigerTagProvider — der Tag, auf den die App gerade rechnet', () {
    test('ist der Berliner Tagesbeginn, nicht der UTC-Zeitpunkt', () {
      final (behaelter: container, stelleUhr: _, quelle: _) = aufbau();

      expect(container.read(heutigerTagProvider), tagesbeginn27);
    });

    test(
      'am selben Kalendertag ändert pruefeTageswechsel nichts — und das '
      'Rechenfenster wird gehalten, nicht neu gerechnet (Fehler 03)',
      () {
        final (behaelter: container, :stelleUhr, quelle: _) = aufbau();
        final vorher = container.read(rechenfensterProvider);

        // Eine Minute später, derselbe Berliner Kalendertag.
        stelleUhr(DateTime.utc(2026, 10, 27, 22, 51));
        container.read(heutigerTagProvider.notifier).pruefeTageswechsel();

        expect(container.read(heutigerTagProvider), tagesbeginn27);
        expect(
          container.read(rechenfensterProvider),
          same(vorher),
          reason:
              'ein Fenster, das sich bei jedem Zugriff neu baut, ist ein '
              'neues Objekt und damit für Riverpod eine Änderung — jeder '
              'abgeleitete Wert liefe neu. Genau das war Fehler 03',
        );
      },
    );

    test(
      'über Mitternacht rückt der Tag vor, und das Rechenfenster rückt '
      'mit',
      () {
        final (behaelter: container, :stelleUhr, quelle: _) = aufbau();

        expect(
          container.read(rechenfensterProvider).start,
          BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 28, 12)),
          reason: 'Vorbedingung: 30 Tage einschließlich des 27.10.',
        );

        stelleUhr(kurzNachMitternacht);
        container.read(heutigerTagProvider.notifier).pruefeTageswechsel();

        expect(container.read(heutigerTagProvider), tagesbeginn28);
        expect(
          container.read(rechenfensterProvider).start,
          BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 29, 12)),
          reason:
              'sonst rechnen Ampel und Diagramm am 28. weiter über ein '
              'Fenster, das auf dem 27. endet',
        );
      },
    );
  });

  group(
    'Die Provider, die am Fenster hängen, laufen nach dem Tageswechsel neu',
    () {
      test(
        'sleepProvider fragt den Kanal erneut, und bis liegt im neuen Tag',
        () async {
          final (behaelter: container, :stelleUhr, :quelle) = aufbau();
          container.listen(sleepProvider, (_, _) {});

          await container.read(sleepProvider.future);
          expect(quelle.schlafAufrufe, 1);
          expect(BerlinCalendar.dayKey(quelle.schlafBis!), '2026-10-27');

          stelleUhr(kurzNachMitternacht);
          container.read(heutigerTagProvider.notifier).pruefeTageswechsel();
          await container.read(sleepProvider.future);

          expect(
            quelle.schlafAufrufe,
            2,
            reason:
                'ohne zweiten Lauf kommt die Nacht, die Tim gerade hinter '
                'sich hat, nie an',
          );
          expect(
            BerlinCalendar.dayKey(quelle.schlafBis!),
            '2026-10-28',
            reason:
                'die obere Grenze muss den neuen Tag erreichen, sonst '
                'schneidet die Abfrage genau die gesuchte Nacht ab',
          );
        },
      );

      test(
        'dailyMetricsProvider ebenso — sein jetzt war genauso eingefroren',
        () async {
          final (behaelter: container, :stelleUhr, :quelle) = aufbau();
          container.listen(dailyMetricsProvider, (_, _) {});

          await container.read(dailyMetricsProvider.future);
          expect(quelle.tagesAufrufe, 1);
          expect(BerlinCalendar.dayKey(quelle.tagesBis!), '2026-10-27');

          stelleUhr(kurzNachMitternacht);
          container.read(heutigerTagProvider.notifier).pruefeTageswechsel();
          await container.read(dailyMetricsProvider.future);

          expect(quelle.tagesAufrufe, 2);
          expect(BerlinCalendar.dayKey(quelle.tagesBis!), '2026-10-28');
        },
      );

      test(
        'am selben Kalendertag läuft keiner von beiden ein zweites Mal',
        () async {
          final (behaelter: container, :stelleUhr, :quelle) = aufbau();
          container.listen(sleepProvider, (_, _) {});
          container.listen(dailyMetricsProvider, (_, _) {});

          await container.read(sleepProvider.future);
          await container.read(dailyMetricsProvider.future);

          stelleUhr(DateTime.utc(2026, 10, 27, 22, 51));
          container.read(heutigerTagProvider.notifier).pruefeTageswechsel();
          await Future<void>.delayed(Duration.zero);

          expect(
            [quelle.schlafAufrufe, quelle.tagesAufrufe],
            [1, 1],
            reason:
                'eine Prüfung, die nichts findet, darf nichts auslösen — '
                'sonst fragt die App den Kanal bei jedem Tick neu',
          );
        },
      );
    },
  );
}

/// Test-Quelle, die zählt und sich die obere Grenze merkt. Alle Antworten
/// sind leer und erfunden; aus echten Gesundheitsdaten stammt hier kein
/// einziger Wert.
class _FakeHealthReading extends HealthReadingAttrappe {
  int schlafAufrufe = 0;
  int tagesAufrufe = 0;
  DateTime? schlafBis;
  DateTime? tagesBis;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafAufrufe += 1;
    schlafBis = through;
    return const [];
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    tagesAufrufe += 1;
    tagesBis = through;
    return const [];
  }
}
