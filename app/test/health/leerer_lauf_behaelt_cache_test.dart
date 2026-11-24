import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';
import 'health_reading_attrappe.dart';

/// Tests zu **#224**: Ein **erfolgreicher, aber leerer** Lauf lässt den
/// zwischengespeicherten Wert stehen, statt ihn durch `LeerNachLauf` zu
/// ersetzen.
///
/// **Entschieden von Tim am 03.11.2026** (Variante (b) im Issue): Ein
/// leerer Lauf endet in `Bekannt(…, laeuft: false)` mit der Stand-Zeile von
/// vorhin — genau wie ein gescheiterter Lauf. Der beobachtete Lauf, der
/// das ausgelöst hat, sah so aus:
///
/// ```
/// [AsyncLoading, Bekannt(laeuft: true, 49.5 aus dem Cache), LeerNachLauf]
/// ```
///
/// Der Grund ist nicht Bequemlichkeit, sondern dass Apple den Lesestatus
/// nicht verrät: „keine Daten" und „nicht erlaubt" sind nicht
/// unterscheidbar. Entzieht iOS oder Tim der App die Freigabe, kommen alle
/// Reihen **leer, aber erfolgreich** zurück — und vor dieser Änderung waren
/// damit sämtliche zwischengespeicherten Werte auf einen Schlag weg. „Werte
/// verschwinden" ist Tims ursprüngliche Beschwerde (#55) und der halbe
/// Grund für den Umbau.
///
/// **Der Preis ist benannt und von Tim angenommen:** Ein wirklich
/// gelöschter Health-Eintrag bleibt stehen, bis ein Lauf etwas anderes
/// findet. Das ist die kleinere Lüge. Ein Test darauf, dass ein gelöschter
/// Eintrag verschwindet, steht hier deshalb **bewusst nicht**.
///
/// ## Wo die Regel lebt
///
/// In genau einer Funktion: `alsMesswert` in `lib/core/async_bruecke.dart`
/// (`CLAUDE.md`: „Eine Stelle, an der man es richtig machen muss, statt
/// acht, an denen man es falsch machen kann"). Die Fälle der Funktion
/// selbst — mit und ohne Cache, `istLeer` und `null` — stehen in
/// `test/core/messwert_test.dart`. **Diese Datei prüft die Ebene darüber:**
/// dass die drei Gesundheits-Provider die Regel tatsächlich abbekommen, und
/// dass die **Stand-Zeile ehrlich bleibt**.
///
/// ## Die Stand-Zeile ist die Stelle, an der das still falsch werden kann
///
/// Bleibt ein alter Wert stehen, darf sein Stand nicht auf „jetzt"
/// springen — sonst behauptet die Zeile einen Lauf, der diesen Wert nie
/// gesehen hat. Zwei Zusicherungen fangen das:
///
/// 1. **In der Ausgabe:** `Bekannt.stand` ist der Cache-Stand, nicht
///    `jetzt`. Beides sind hier verschiedene, fest gesetzte Zeitpunkte;
///    ein `stand`, der auf `jetzt` springt, fällt sofort auf.
/// 2. **Auf der Platte:** Nach dem leeren Lauf trägt die Cache-Zeile
///    weiterhin ihr altes `gelesenAm`. Das ist die Zusicherung, die über
///    einen Kaltstart trägt — stünde dort `jetzt`, käme die Lüge beim
///    nächsten Start aus der Datenbank zurück, wo `alsMesswert` sie gar
///    nicht mehr sehen kann.
///
/// **Alle Zahlen hier sind erfunden** — kein echter Gesundheitswert.
void main() {
  // Fester Zeitpunkt statt `DateTime.now()` (Spec 5.3b).
  // 20.10.2026, 14:32 UTC = 16:32 Berliner Sommerzeit.
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);

  /// Der Stand des Caches: fünfeinhalb Stunden vor `jetzt`. Zwei klar
  /// verschiedene Zeitpunkte — ein `stand`, der auf `jetzt` springt, ist
  /// nicht zu übersehen.
  final cacheStand = DateTime.utc(2026, 10, 20, 9);

  DateTime tagesbeginn(int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tag, 12));

  /// Eine gemessene Nacht mit einem durchgehenden Abschnitt über ihr
  /// Fenster: 21:00 Berliner Zeit am Vorabend bis 06:00 am Aufwachtag.
  SleepNight nacht(int monat, int tag) {
    final beginn = tagesbeginn(monat, tag);
    final von = beginn.subtract(const Duration(hours: 3));
    final bis = beginn.add(const Duration(hours: 6));
    return SleepNight(
      date: beginn,
      session: SleepSession(
        segments: [SleepSegment(stage: SleepStage.core, start: von, end: bis)],
      ),
    );
  }

  ProviderContainer behaelter({
    required AppCache db,
    required HealthReading quelle,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group(
    'dailyMetricsProvider: der leere Lauf nimmt die Schritte nicht weg',
    () {
      test('mit Cache endet ein leerer, erfolgreicher Lauf in Bekannt mit dem '
          'alten Wert und dem alten Stand, nicht in LeerNachLauf', () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        await CacheRepository(db).schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-20', steps: 4200),
        ], gelesenAm: cacheStand);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(tageswerte: () async => const []),
        );

        // **Nicht `.future`**: Bei einem Cache-Treffer gibt der Provider
        // zweimal aus, und `.future` friert in Riverpod 3.4.3 die erste
        // Ausgabe ein (begründet im Kopf von `health_provider_test.dart`).
        final beobachtet = <AsyncValue<Messwert<List<DailyMetrics>>>>[];
        container.listen(
          dailyMetricsProvider,
          (prev, next) => beobachtet.add(next),
          fireImmediately: true,
        );
        await pumpEventQueue();

        final ausgaben = beobachtet
            .whereType<AsyncData<Messwert<List<DailyMetrics>>>>()
            .map((d) => d.value)
            .toList();

        expect(
          ausgaben.whereType<LeerNachLauf<List<DailyMetrics>>>(),
          isEmpty,
          reason:
              'Tims Beschwerde: ein leerer Lauf darf einen sichtbaren Wert '
              'nicht wegnehmen — und „keine Daten" ist von „nicht erlaubt" '
              'ohnehin nicht zu unterscheiden (#224)',
        );
        final ergebnis = ausgaben.last;
        expect(ergebnis, isA<Bekannt<List<DailyMetrics>>>());
        final bekannt = ergebnis as Bekannt<List<DailyMetrics>>;
        expect(bekannt.wert.single.steps, 4200);
        expect(
          bekannt.laeuft,
          isFalse,
          reason: 'der Lauf ist fertig — er hat nur nichts gefunden',
        );
        expect(
          bekannt.stand,
          cacheStand,
          reason:
              'die Stand-Zeile nennt den Lauf, der diesen Wert gesehen hat — '
              'und das war nicht der leere von „jetzt"',
        );
        expect(bekannt.stand, isNot(jetzt));
      });

      test('und die Cache-Zeile behält ihr altes gelesenAm — der leere Lauf '
          'schreibt sich nicht als frisch in die Datenbank', () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-20', steps: 4200),
        ], gelesenAm: cacheStand);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(tageswerte: () async => const []),
        );
        container.listen(dailyMetricsProvider, (prev, next) {});
        await pumpEventQueue();

        final aufDerPlatte = await repo.liesTagesWerte(DataWindow.unlimited);
        expect(aufDerPlatte, isNotNull);
        expect(
          aufDerPlatte!.stand,
          cacheStand,
          reason:
              'stünde hier „jetzt", käme die Lüge beim nächsten Kaltstart aus '
              'der Datenbank zurück — unterhalb von Messwert<T>, wo der '
              'sealed-Typ sie nicht mehr sehen kann',
        );
        expect(aufDerPlatte.werte.single.steps, 4200);
      });

      test('ohne Cache bleibt der leere Lauf LeerNachLauf — die Regel bekommt '
          'einen Zwilling, sie ersetzt nichts', () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(tageswerte: () async => const []),
        );

        final ergebnis = await container.read(dailyMetricsProvider.future);

        expect(ergebnis, isA<LeerNachLauf<List<DailyMetrics>>>());
        expect(
          (ergebnis as LeerNachLauf<List<DailyMetrics>>).gelaufen,
          jetzt,
          reason:
              'ohne Cache gibt es keinen fremden Stand, den man ehrlich '
              'nennen könnte — hier ist „jetzt" richtig',
        );
      });
    },
  );

  group('sleepProvider: dieselbe Regel, derselbe Beleg', () {
    test(
      'mit Cache bleibt die Nacht stehen, wenn der Kanal nichts liefert',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        await CacheRepository(db)
            .schreibeNaechte([nacht(10, 20)], gelesenAm: cacheStand);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(schlaf: () async => const []),
        );

        final beobachtet = <AsyncValue<Messwert<List<SleepNight>>>>[];
        container.listen(
          sleepProvider,
          (prev, next) => beobachtet.add(next),
          fireImmediately: true,
        );
        await pumpEventQueue();

        final ausgaben = beobachtet
            .whereType<AsyncData<Messwert<List<SleepNight>>>>()
            .map((d) => d.value)
            .toList();

        expect(ausgaben.whereType<LeerNachLauf<List<SleepNight>>>(), isEmpty);
        final bekannt = ausgaben.last as Bekannt<List<SleepNight>>;
        expect(bekannt.laeuft, isFalse);
        expect(bekannt.wert, hasLength(1));
        expect(bekannt.stand, cacheStand);
      },
    );
  });

  group('nachtWerteProvider: genau der Lauf aus #224', () {
    test('49.5 aus dem Cache bleibt stehen, wenn der Kanal keine Proben '
        'liefert — statt [Bekannt(laeuft: true), LeerNachLauf]', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);
      await repo.schreibeNaechte([nacht(10, 19)], gelesenAm: cacheStand);
      await repo.schreibeNachtWerte(const {
        '2026-10-19': NightVitals(restingHeartRate: 49.5),
      }, gelesenAm: cacheStand);

      // Nächte gibt es, Proben nicht: der Kanal antwortet erfolgreich mit
      // nichts — genau das, was eine entzogene Freigabe liefert.
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(schlaf: () async => [nacht(10, 19)]),
      );

      final beobachtet = <AsyncValue<Messwert<Map<String, NightVitals>>>>[];
      container.listen(
        nachtWerteProvider,
        (prev, next) => beobachtet.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();

      final ausgaben = beobachtet
          .whereType<AsyncData<Messwert<Map<String, NightVitals>>>>()
          .map((d) => d.value)
          .toList();

      expect(
        ausgaben.whereType<LeerNachLauf<Map<String, NightVitals>>>(),
        isEmpty,
        reason: 'das war die Ausgabe, die #224 ausgelöst hat',
      );
      final bekannt = ausgaben.last as Bekannt<Map<String, NightVitals>>;
      expect(bekannt.laeuft, isFalse);
      expect(bekannt.wert['2026-10-19']!.restingHeartRate, 49.5);
      expect(bekannt.stand, cacheStand);
      expect(bekannt.stand, isNot(jetzt));
    });
  });
}

/// Konfigurierbare Test-Quelle. Ohne Angabe antwortet jede Methode
/// erfolgreich mit nichts — das ist hier der Normalfall, nicht die
/// Ausnahme.
///
/// Alle Antworten sind erfunden; aus echten Gesundheitsdaten stammt hier
/// kein einziger Wert.
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading({
    FutureOr<List<SleepNight>> Function()? schlaf,
    FutureOr<List<DailyMetrics>> Function()? tageswerte,
  }) : _schlaf = schlaf ?? (() => const <SleepNight>[]),
       _tageswerte = tageswerte ?? (() => const <DailyMetrics>[]);

  final FutureOr<List<SleepNight>> Function() _schlaf;
  final FutureOr<List<DailyMetrics>> Function() _tageswerte;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async => _schlaf();

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => _tageswerte();
}
