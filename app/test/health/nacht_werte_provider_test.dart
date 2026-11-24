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

/// Tests für `nachtWerteProvider` (#193, Stufe 3 von
/// `docs/superpowers/specs/2026-11-02-193-nachtwerte.md`, Teil 2 von zwei —
/// die Ablage steht in `test/data/schema_v8_test.dart`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Die **Rechnung** steht im Kern und ist dort mit 43 Fällen belegt
/// (`Packages/trainings_core/test/night_vitals_test.dart`). Hier wird sie
/// nicht noch einmal nachgerechnet. Geprüft wird, dass der Provider sie
/// richtig **benutzt** und ihr Ergebnis richtig **hält**.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// final nachtWerteProvider =
///     AsyncNotifierProvider<NachtWerteNotifier,
///         Messwert<Map<String, NightVitals>>>(NachtWerteNotifier.new);
///
/// class NachtWerteNotifier
///     extends AsyncNotifier<Messwert<Map<String, NightVitals>>> {
///   @override
///   Future<Messwert<Map<String, NightVitals>>> build();
/// }
/// ```
///
/// Der Klassenname ist nur insofern verbindlich, als es ein
/// `(Async)Notifier` sein muss: Der Provider gibt bei einem Cache-Treffer
/// während `build()` einen Zwischenzustand über `state =` aus, und das kann
/// ein `FutureProvider` nicht.
///
/// **Der Schlüssel der Karte ist der ISO-Tagesschlüssel des Aufwachtags**
/// (`BerlinCalendar.dayKey(nacht.date)`) — derselbe wie in `Naechte.tag`.
/// Ein Tag ist eine Kalenderangabe, kein Zeitpunkt (`CLAUDE.md`).
///
/// **Woher die Nächte kommen, legt diese Datei nicht fest** — ob der
/// Provider `ref.watch(sleepProvider.future)` liest oder den beobachteten
/// Zustand, ist seine Sache. Fest steht nur: Die Fenster sind die aus
/// `SleepNight.session`, und was `sleepProvider` als `Messwert` meldet,
/// kommt hier als `Messwert` wieder heraus. `AsyncValue` taucht nirgends
/// auf, auch nicht als geworfene Ausnahme.
///
/// ## Entscheidung 1 — dreimal insgesamt, nicht dreimal je Nacht
///
/// Das ist die Zusicherung, auf die es bei Stufe 3 ankommt: **ein** Aufruf
/// je Messreihe über das ganze Rechenfenster, danach die Zuordnung in Dart.
/// Dreißig Nächte wären sonst neunzig Abfragen (Spec). Der Test unten zählt
/// mit; eine Absichtserklärung im Kommentar zählt nicht.
///
/// Daraus folgt umgekehrt: **Gibt es keine Nacht, wird der Kanal gar nicht
/// gefragt.** Es gäbe kein Fenster, in das eine Probe fiele, und die drei
/// Abfragen holten für dreißig Tage rund 24.000 Pulsproben (Spec, „Warum
/// eine eigene Spalte") für ein Ergebnis, das in jedem Fall leer ist.
///
/// ## Entscheidung 2 — der Kanal wird ab dem frühesten Nachtbeginn gefragt
///
/// Das Rechenfenster beginnt auf einem Berliner **Tagesbeginn**; die Nacht
/// dieses Tages beginnt am Abend **davor**. Wer den Kanal mit
/// `rechenfenster.queryStart(...)` fragt, verliert von der ersten Nacht
/// alles vor Mitternacht — bei einer Nacht von 21:00 bis 06:00 sind das
/// drei der neun Stunden, und beim Ruhepuls liegt in ihnen der Tiefpunkt.
/// Das wäre Fehler `01` unterhalb von `Messwert<T>`: Die Zahl fehlt nicht,
/// sie ist still falsch.
///
/// Verbindlich ist deshalb die **Anforderung**, nicht ihre Umsetzung: Die
/// untere Grenze der Abfrage liegt nicht nach dem frühesten Beginn aller
/// Nächte, die obere nicht vor deren spätestem Ende.
///
/// ## Entscheidung 3 — eine Nacht ohne jeden Wert steht nicht in der Karte
///
/// `Bekannt.wert` soll nie leer sein, und bei generischem `T` kann das
/// niemand erzwingen — die Pflicht liegt beim Aufrufer, je Provider genau
/// eine Stelle (`CLAUDE.md`). Hier heißt sie: Eine Nacht, für die keine der
/// drei Reihen eine Probe im Fenster hat, taucht in der Karte **nicht** auf;
/// bleibt die Karte dadurch leer, ist das Ergebnis `LeerNachLauf`, nicht
/// `Bekannt({})`.
///
/// Für die Ansicht ist das derselbe Fall: `karte[tag]` ist `null`, und `null`
/// heißt „keine Werte" — nicht `0` (`CLAUDE.md`, „`0` ist keine Antwort auf
/// ‚kein Wert'"). Ein `NightVitals` mit drei `null`-Feldern wäre dieselbe
/// Auskunft mit mehr Zeilen.
///
/// ## Die Ladereihenfolge ist die von `SleepNotifier`
///
/// Wörtlich dieselbe: Cache lesen → **nur bei vorhandenem Cache** sofort
/// `Bekannt(laeuft: true)` ausgeben → Kanal fragen, höchstens drei
/// Versuche → zurückschreiben → `alsMesswert`. Keine eigene Variante: Ein
/// dritter Ladeweg neben den beiden bestehenden wäre eine dritte Stelle, an
/// der Tims Fehler („Ladezustand als Leerstand") neu entstehen könnte. Die
/// Begründung jedes einzelnen Schritts steht in `health_provider.dart` bei
/// `DailyMetricsNotifier` und gilt hier unverändert.
///
/// **`.future` wird nur dort benutzt, wo kein Cache vorliegt.** In Riverpod
/// 3.4.3 löst `AsyncNotifier.future` mit der **zuerst** ausgegebenen Ausgabe
/// auf und friert sie ein; bei einem Cache-Treffer wäre das die
/// Zwischenausgabe, nicht das Ergebnis. Endzustände mit Cache werden deshalb
/// über den Listener gelesen — dieselbe Regel wie in
/// `health_provider_test.dart` und `sleep_provider_test.dart`.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Die Verdrahtung in Ampel, Heute- und Verlauf-Schirm.** Das ist
///   Stufe 4 der Spec und hat ihre eigenen Tests.
/// - **Ob ein erneuter Schlaflauf die drei Cache-Spalten stehen lässt.**
///   Das ist das `NULL`-Überschreiben aus #197, in der Spec zu #193
///   ausdrücklich als „nicht Gegenstand" geführt.
/// - **Die Wiederholungsregel der echten App** (Spec 5.3c) —
///   `retry: (_, _) => null` ist für Tests vorgeschrieben und unten überall
///   gesetzt. Geprüft wird nur die **eigene** Obergrenze von drei Versuchen.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  // Fester Zeitpunkt statt `DateTime.now()` — sonst wäre jede Fenstergrenze
  // unten in jedem Lauf eine andere (Spec 5.3b).
  // 20.10.2026, 14:32 UTC = 16:32 Berliner Sommerzeit.
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);

  /// Berliner Tagesbeginn — **nicht** von Hand gepaarte UTC-Zeitpunkte.
  /// Genau dort lag der Zahlendreher in den `DataWindow`-Tests: 23:30 UTC
  /// ist im Oktober in Berlin schon der Folgetag.
  DateTime tagesbeginn(int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tag, 12));

  /// Das Schlaffenster der Nacht, die auf den Tag [monat]/[tag] führt:
  /// 21:00 Berliner Zeit am Vorabend bis 06:00 am Aufwachtag, beides aus
  /// dem Tagesbeginn abgeleitet statt einzeln hingeschrieben.
  ({DateTime von, DateTime bis}) fenster(int monat, int tag) {
    final beginn = tagesbeginn(monat, tag);
    return (
      von: beginn.subtract(const Duration(hours: 3)),
      bis: beginn.add(const Duration(hours: 6)),
    );
  }

  /// Eine gemessene Nacht mit einem durchgehenden Abschnitt über ihr
  /// Fenster.
  SleepNight nacht(
    int monat,
    int tag, {
    List<SleepSession> nickerchen = const [],
  }) {
    final f = fenster(monat, tag);
    return SleepNight(
      date: tagesbeginn(monat, tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: f.von, end: f.bis),
        ],
      ),
      naps: nickerchen,
    );
  }

  QuantitySample probe(DateTime zeit, double wert) =>
      QuantitySample(date: zeit, value: wert);

  /// Fünf Pulsproben im Fenster der Nacht auf [monat]/[tag] — die
  /// Mindestzahl, unter der `NightVitals` `null` liefert.
  List<QuantitySample> fuenfPulsproben(int monat, int tag, {double ab = 50}) {
    final f = fenster(monat, tag);
    return [
      for (var i = 0; i < 5; i++)
        probe(f.von.add(Duration(hours: i + 1)), ab + i),
    ];
  }

  ProviderContainer behaelter({
    required AppCache db,
    required HealthReading quelle,
    DateTime? uhr,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => uhr ?? jetzt),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Die Messwert-Ausgaben eines Listeners, ohne die äußere
  /// `AsyncValue`-Hülle, die der `AsyncNotifierProvider` zwangsläufig
  /// mitbringt.
  List<Messwert<Map<String, NightVitals>>> ausgaben(
    List<AsyncValue<Messwert<Map<String, NightVitals>>>> beobachtet,
  ) => beobachtet
      .whereType<AsyncData<Messwert<Map<String, NightVitals>>>>()
      .map((d) => d.value)
      .toList();

  List<AsyncValue<Messwert<Map<String, NightVitals>>>> hoerZu(
    ProviderContainer container,
  ) {
    final beobachtet = <AsyncValue<Messwert<Map<String, NightVitals>>>>[];
    container.listen(
      nachtWerteProvider,
      (prev, next) => beobachtet.add(next),
      fireImmediately: true,
    );
    return beobachtet;
  }

  group('Der Kanal wird dreimal gefragt — nicht dreimal je Nacht', () {
    test('drei Nächte kosten drei Abfragen, eine je Messreihe', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 18), nacht(10, 19), nacht(10, 20)],
        proben: {
          VitalKind.heartRate: () async => [
            ...fuenfPulsproben(10, 18),
            ...fuenfPulsproben(10, 19),
            ...fuenfPulsproben(10, 20),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      await container.read(nachtWerteProvider.future);

      expect(quelle.aufrufe[VitalKind.heartRate], 1);
      expect(quelle.aufrufe[VitalKind.heartRateVariability], 1);
      expect(quelle.aufrufe[VitalKind.respiratoryRate], 1);
      expect(
        quelle.aufrufeGesamt,
        3,
        reason:
            'einmal je Messreihe über das ganze Rechenfenster, danach die '
            'Zuordnung in Dart. Je Nacht gefragt wären es bei dreißig '
            'Nächten neunzig Abfragen (Spec, Stufe 3)',
      );
    });

    test('ohne eine einzige Nacht wird der Kanal gar nicht gefragt — das '
        'Ergebnis ist LeerNachLauf', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(schlaf: () async => const []);
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);

      expect(
        quelle.aufrufeGesamt,
        0,
        reason:
            'es gäbe kein Fenster, in das eine Probe fiele. Drei Abfragen '
            'über dreißig Tage Rohproben für ein Ergebnis, das in jedem '
            'Fall leer ist',
      );
      expect(ergebnis, isA<LeerNachLauf<Map<String, NightVitals>>>());
      expect(
        (ergebnis as LeerNachLauf<Map<String, NightVitals>>).gelaufen,
        jetzt,
      );
    });

    test('die Abfrage beginnt am frühesten Nachtbeginn, nicht erst am '
        'Fensterbeginn', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // Die Nacht auf den ersten Tag des Rechenfensters: Sie beginnt am
      // Abend davor und damit **vor** dem Fensterbeginn.
      final ersteNacht = fenster(9, 21);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(9, 21), nacht(10, 20)],
        proben: {VitalKind.heartRate: () async => fuenfPulsproben(10, 20)},
      );
      final container = behaelter(db: db, quelle: quelle);

      await container.read(nachtWerteProvider.future);

      expect(
        container.read(rechenfensterProvider).start,
        tagesbeginn(9, 21),
        reason:
            'Kontrolle der Annahme: Das Rechenfenster beginnt wirklich auf '
            'dem Tagesbeginn des 21.09., und die Nacht dieses Tages beginnt '
            'drei Stunden davor',
      );
      expect(
        quelle.von[VitalKind.heartRate]!.isAfter(ersteNacht.von),
        isFalse,
        reason:
            'wer ab dem Fensterbeginn fragt, verliert von der ersten Nacht '
            'alles vor Mitternacht — und beim Ruhepuls liegt dort der '
            'Tiefpunkt. Die Zahl fehlte dann nicht, sie wäre still falsch',
      );
      expect(
        quelle.bis[VitalKind.heartRate]!.isBefore(fenster(10, 20).bis),
        isFalse,
        reason: 'und die obere Grenze liegt nicht vor dem letzten Nachtende',
      );
    });
  });

  group('Die Zuordnung Probe → Nacht passiert über die Fenster', () {
    test('jede Nacht bekommt ihre eigenen Proben, abgelegt unter dem '
        'Tagesschlüssel des Aufwachtags', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 19), nacht(10, 20)],
        proben: {
          VitalKind.heartRate: () async => [
            // 50..54 in der einen Nacht, 60..64 in der anderen. Die
            // Rechnung selbst prüft der Kern; hier zählt nur, dass die
            // beiden Reihen nicht zusammenlaufen.
            ...fuenfPulsproben(10, 19, ab: 50),
            ...fuenfPulsproben(10, 20, ab: 60),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(karte.keys.toList()..sort(), ['2026-10-19', '2026-10-20']);
      expect(karte['2026-10-19']!.restingHeartRate, lessThan(55));
      expect(
        karte['2026-10-20']!.restingHeartRate,
        greaterThan(59),
        reason:
            'liefen beide Reihen in dieselbe Nacht, läge das 5. Perzentil '
            'beider Nächte bei 50 — die höhere Nacht verschwände',
      );
    });

    test('eine Probe, die in keine Nacht fällt, landet in keiner', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 20)],
        proben: {
          VitalKind.heartRateVariability: () async => [
            probe(fenster(10, 20).von.add(const Duration(hours: 2)), 42),
            // Mittags, hellwach: 12:00 Berliner Zeit.
            probe(tagesbeginn(10, 20).add(const Duration(hours: 12)), 18),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(karte, hasLength(1));
      expect(
        karte['2026-10-20']!.hrv,
        42,
        reason:
            'der Median über beide Proben wäre 30 — genau die Vermischung '
            'von Tag und Nacht, dessentwegen es #193 gibt',
      );
    });

    test('eine Probe im Tagschlaf zählt nicht zur Nacht', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final mittags = tagesbeginn(10, 20).add(const Duration(hours: 13));
      final quelle = _FakeHealthReading(
        schlaf: () async => [
          nacht(
            10,
            20,
            nickerchen: [
              SleepSession(
                segments: [
                  SleepSegment(
                    stage: SleepStage.core,
                    start: mittags,
                    end: mittags.add(const Duration(minutes: 40)),
                  ),
                ],
              ),
            ],
          ),
        ],
        proben: {
          VitalKind.respiratoryRate: () async => [
            probe(fenster(10, 20).von.add(const Duration(hours: 1)), 14),
            probe(mittags.add(const Duration(minutes: 10)), 20),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(
        karte['2026-10-20']!.respiratoryRate,
        14,
        reason:
            'die Fenster kommen aus `SleepNight.session`, nicht aus `naps` '
            '— SPEC 4.6 zählt Tagschlaf nicht zur Nacht',
      );
    });

    test('das Fenster einer Nacht reicht vom frühesten Beginn bis zum '
        'spätesten Ende ihrer Abschnitte', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final f = fenster(10, 20);
      // Eine Nacht mit einer Wachlücke in der Mitte: zwei Abschnitte, eine
      // Stunde Abstand. Die Nacht ist trotzdem **eine** Nacht.
      final zerrissen = SleepNight(
        date: tagesbeginn(10, 20),
        session: SleepSession(
          segments: [
            SleepSegment(
              stage: SleepStage.core,
              start: f.von,
              end: f.von.add(const Duration(hours: 3)),
            ),
            SleepSegment(
              stage: SleepStage.deep,
              start: f.von.add(const Duration(hours: 4)),
              end: f.bis,
            ),
          ],
        ),
      );
      final quelle = _FakeHealthReading(
        schlaf: () async => [zerrissen],
        proben: {
          VitalKind.heartRateVariability: () async => [
            // Genau in der Lücke zwischen den beiden Abschnitten.
            probe(f.von.add(const Duration(hours: 3, minutes: 30)), 39),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(
        karte['2026-10-20']!.hrv,
        39,
        reason:
            'ein Fenster je Nacht, nicht eines je Abschnitt. Wer je '
            'Abschnitt zuordnet, verliert jede Probe aus einer Wachphase — '
            'und bei zwei bis sechs HRV-Proben je Nacht ist das schnell die '
            'einzige',
      );
    });

    test('eine Nacht, für die keine Reihe etwas hergibt, steht nicht in der '
        'Karte', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 19), nacht(10, 20)],
        proben: {VitalKind.heartRate: () async => fuenfPulsproben(10, 20)},
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(
        karte.keys.toList(),
        ['2026-10-20'],
        reason:
            'ein NightVitals mit drei null-Feldern wäre dieselbe Auskunft '
            'wie ein fehlender Eintrag, nur mit mehr Zeilen. Die Ansicht '
            'liest `karte[tag] == null` als "keine Werte"',
      );
    });
  });

  group('Mindestens fünf Pulsproben — sonst null, nie 0', () {
    test('vier Pulsproben ergeben keinen Ruhepuls, die HRV derselben Nacht '
        'bleibt aber stehen', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final f = fenster(10, 20);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 20)],
        proben: {
          VitalKind.heartRate: () async => [
            // `52.0 + i` und nicht `52 + i`: Das wäre ein `int`-Ausdruck,
            // kein Literal, und Dart wandelt ihn nicht stillschweigend in
            // `double` um.
            for (var i = 0; i < 4; i++)
              probe(f.von.add(Duration(hours: i + 1)), 52.0 + i),
          ],
          VitalKind.heartRateVariability: () async => [
            probe(f.von.add(const Duration(hours: 2)), 44),
          ],
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);
      final karte = (ergebnis as Bekannt<Map<String, NightVitals>>).wert;

      expect(
        karte['2026-10-20']!.restingHeartRate,
        isNull,
        reason:
            'ein Perzentil über vier Proben ist keine Auskunft, und 0 bpm '
            'wäre kein fehlender Wert, sondern ein Alarmwert — "0 ist keine '
            'Antwort auf kein Wert" (CLAUDE.md)',
      );
      expect(
        karte['2026-10-20']!.hrv,
        44,
        reason:
            'für HRV gibt es keine Mindestzahl — die Uhr misst sie nur '
            'zwei- bis sechsmal je Nacht. Ein fehlender Ruhepuls nimmt sie '
            'nicht mit',
      );
    });
  });

  group('Ohne Cache: der Platzhalter erscheint genau einmal', () {
    test('vor der Kanal-Antwort gibt es keine Messwert-Ausgabe, danach '
        'Bekannt — und nie ein NochNie dazwischen oder danach', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final antwort = Completer<List<QuantitySample>>();
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 20)],
          proben: {VitalKind.heartRate: () => antwort.future},
        ),
      );

      final beobachtet = hoerZu(container);
      await pumpEventQueue();

      expect(
        ausgaben(beobachtet),
        isEmpty,
        reason:
            'ohne Cache gibt es nichts zu zeigen. Eine vorgezogene Ausgabe '
            'wäre entweder ein erfundener Wert oder ein Leerstand, der nur '
            'ein Ladezustand ist',
      );

      antwort.complete(fuenfPulsproben(10, 20));
      await pumpEventQueue();

      final gesehen = ausgaben(beobachtet);
      expect(
        gesehen.whereType<NochNie<Map<String, NightVitals>>>(),
        isEmpty,
        reason: 'zurück nach NochNie gibt es nicht (Spec 5.3)',
      );
      final bekannt = gesehen.last as Bekannt<Map<String, NightVitals>>;
      expect(bekannt.laeuft, isFalse);
      expect(bekannt.stand, jetzt);
      expect(bekannt.wert, hasLength(1));
    });
  });

  group('Mit Cache: der Platzhalter erscheint nie', () {
    test('zuerst Bekannt(laeuft: true) mit dem Cache-Stand, danach '
        'Bekannt(laeuft: false) mit dem frischen Wert', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final cacheStand = DateTime.utc(2026, 10, 20, 9);
      final repo = CacheRepository(db);
      await repo.schreibeNaechte([nacht(10, 19)], gelesenAm: cacheStand);
      await repo.schreibeNachtWerte(const {
        '2026-10-19': NightVitals(restingHeartRate: 49.5),
      }, gelesenAm: cacheStand);

      final antwort = Completer<List<QuantitySample>>();
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 19), nacht(10, 20)],
          proben: {VitalKind.heartRate: () => antwort.future},
        ),
      );

      final beobachtet = hoerZu(container);
      await pumpEventQueue();

      final waehrendDesLaufs =
          ausgaben(beobachtet).first as Bekannt<Map<String, NightVitals>>;
      expect(waehrendDesLaufs.laeuft, isTrue);
      expect(waehrendDesLaufs.stand, cacheStand);
      expect(waehrendDesLaufs.wert['2026-10-19']!.restingHeartRate, 49.5);

      antwort.complete([
        ...fuenfPulsproben(10, 19, ab: 50),
        ...fuenfPulsproben(10, 20, ab: 60),
      ]);
      await pumpEventQueue();

      final gesehen = ausgaben(beobachtet);
      expect(
        gesehen.whereType<NochNie<Map<String, NightVitals>>>(),
        isEmpty,
        reason:
            'mit Cache darf der Platzhalter kein einziges Mal auftauchen — '
            'genau das war Tims „Heute zeigt 0"',
      );
      final fertig = gesehen.last as Bekannt<Map<String, NightVitals>>;
      expect(fertig.laeuft, isFalse);
      expect(fertig.wert, hasLength(2));
      expect(
        fertig.stand,
        jetzt,
        reason:
            'ein frisch geholter Wert trägt "jetzt" als Stand, nicht den '
            'alten Cache-Stand (Spec 5.3d)',
      );
    });

    test('Nächte im Cache ohne gerechnete Nachtwerte sind kein Cache — es '
        'gibt kein Bekannt mit leerer Karte', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // Der Zustand nach dem allerersten Schlaflauf: Nächte liegen da, die
      // Nachtwerte sind noch nie gerechnet worden.
      await CacheRepository(db).schreibeNaechte([
        nacht(10, 19),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 9));

      final antwort = Completer<List<QuantitySample>>();
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 19)],
          proben: {VitalKind.heartRate: () => antwort.future},
        ),
      );

      final beobachtet = hoerZu(container);
      await pumpEventQueue();

      expect(
        ausgaben(beobachtet),
        isEmpty,
        reason:
            'eine leere Karte als Bekannt auszugeben hieße: "gerechnet, '
            'nichts da" — dabei läuft die Rechnung noch. Das ist der '
            'Ladezustand als Leerstand',
      );
    });
  });

  group('Leer, gescheitert, und was dazwischen nicht passieren darf', () {
    test(
      'Nächte ohne jede Probe werden LeerNachLauf, nie Bekannt({})',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(schlaf: () async => [nacht(10, 20)]),
        );

        final ergebnis = await container.read(nachtWerteProvider.future);

        expect(
          ergebnis,
          isA<LeerNachLauf<Map<String, NightVitals>>>(),
          reason:
              'der Lauf ist fertig und hat nichts gebracht. Nur dieser '
              'Zustand darf einen „keine Daten"-Grund anzeigen',
        );
        expect(
          (ergebnis as LeerNachLauf<Map<String, NightVitals>>).gelaufen,
          jetzt,
        );
      },
    );

    test('ohne Cache wird ein gescheiterter Lauf Fehlgeschlagen — nicht '
        'LeerNachLauf, das hieße „nichts gemessen"', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 20)],
          proben: {
            for (final art in VitalKind.values)
              art: () async => throw Exception('HealthKit nicht erreichbar'),
          },
        ),
      );

      final ergebnis = await container.read(nachtWerteProvider.future);

      expect(ergebnis, isA<Fehlgeschlagen<Map<String, NightVitals>>>());
      expect(
        (ergebnis as Fehlgeschlagen<Map<String, NightVitals>>).gelaufen,
        jetzt,
      );
    });

    test(
      'ein gescheiterter Nachlauf nimmt den Wert aus dem Cache nicht weg',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final cacheStand = DateTime.utc(2026, 10, 20, 9);
        final repo = CacheRepository(db);
        await repo.schreibeNaechte([nacht(10, 19)], gelesenAm: cacheStand);
        await repo.schreibeNachtWerte(const {
          '2026-10-19': NightVitals(restingHeartRate: 49.5, hrv: 41.5),
        }, gelesenAm: cacheStand);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(
            schlaf: () async => [nacht(10, 19)],
            proben: {
              for (final art in VitalKind.values)
                art: () async => throw Exception('HealthKit nicht erreichbar'),
            },
          ),
        );

        // Nicht `.future`: Mit Cache gibt der Provider zwischendurch aus, und
        // `.future` friert in Riverpod 3.4.3 die erste Ausgabe ein.
        final beobachtet = hoerZu(container);
        await pumpEventQueue();

        final ergebnis = ausgaben(beobachtet).last;
        expect(
          ergebnis,
          isNot(isA<Fehlgeschlagen<Map<String, NightVitals>>>()),
          reason:
              'Fehlgeschlagen gilt nur ohne Cache (Spec 5.3a). Tims '
              'Beschwerde ist, dass Werte verschwinden',
        );
        final bekannt = ergebnis as Bekannt<Map<String, NightVitals>>;
        expect(bekannt.laeuft, isFalse);
        expect(bekannt.stand, cacheStand);
        expect(bekannt.wert['2026-10-19']!.restingHeartRate, 49.5);
      },
    );

    test('die Zahl der Versuche ist begrenzt: dreimal, dann gilt das '
        'Ergebnis', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 20)],
        proben: {
          for (final art in VitalKind.values)
            art: () async => throw Exception('HealthKit nicht erreichbar'),
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      await container.read(nachtWerteProvider.future);

      expect(
        quelle.aufrufe[VitalKind.heartRate],
        3,
        reason:
            'eine entzogene Freigabe sieht aus wie ein vorübergehender '
            'Fehler — ohne Obergrenze liefe die App endlos weiter und '
            'zeigte dauerhaft einen Platzhalter statt einer Aussage '
            '(dieselbe Grenze wie bei dailyMetricsProvider)',
      );
    });

    test('ein vorübergehender Fehler wird überstanden: zwei Fehlschläge, '
        'dann das Ergebnis', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      var versuche = 0;
      final quelle = _FakeHealthReading(
        schlaf: () async => [nacht(10, 20)],
        proben: {
          VitalKind.heartRate: () async {
            versuche += 1;
            if (versuche < 3) throw Exception('kurz nicht erreichbar');
            return fuenfPulsproben(10, 20);
          },
        },
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);

      expect(ergebnis, isA<Bekannt<Map<String, NightVitals>>>());
      expect(quelle.aufrufe[VitalKind.heartRate], 3);
    });

    test('scheitert schon der Schlaflauf, scheitert auch dieser — und der '
        'Kanal wird für die Proben nicht gefragt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final quelle = _FakeHealthReading(
        schlaf: () async => throw Exception('HealthKit nicht erreichbar'),
      );
      final container = behaelter(db: db, quelle: quelle);

      final ergebnis = await container.read(nachtWerteProvider.future);

      expect(
        ergebnis,
        isA<Fehlgeschlagen<Map<String, NightVitals>>>(),
        reason:
            'ohne Nächte gibt es keine Fenster. Dass nichts gefunden wurde, '
            'ist dann die falsche Auskunft — gescheitert ist nicht leer',
      );
      expect(quelle.aufrufeGesamt, 0);
    });
  });

  group('Zurückschreiben und kalter Neustart', () {
    test('nach einem erfolgreichen Lauf liegen die Nachtwerte im Cache, und '
        'ein neuer Behälter zeigt sie sofort — ohne auf den Kanal zu '
        'warten', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final ersterBehaelter = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 19), nacht(10, 20)],
          proben: {
            VitalKind.heartRate: () async => [
              ...fuenfPulsproben(10, 19, ab: 50),
              ...fuenfPulsproben(10, 20, ab: 60),
            ],
          },
        ),
      );
      final ersteKarte = (await ersterBehaelter.read(
        nachtWerteProvider.future,
      ) as Bekannt<Map<String, NightVitals>>).wert;

      final imCache = await CacheRepository(db)
          .liesNachtWerte(DataWindow.unlimited);
      expect(imCache, isNotNull);
      expect(imCache!.werte, hasLength(2));
      expect(
        imCache.stand,
        jetzt,
        reason: 'der Stand kommt aus dem gerade gelaufenen Lauf (Spec 5.3b)',
      );

      // Der Kanal des zweiten Behälters hängt für immer fest: Was sichtbar
      // wird, kann dann nur aus dem Cache stammen.
      final haengtFest = Completer<List<QuantitySample>>();
      final zweiterBehaelter = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 19), nacht(10, 20)],
          proben: {VitalKind.heartRate: () => haengtFest.future},
        ),
        uhr: jetzt.add(const Duration(minutes: 5)),
      );

      final beobachtet = hoerZu(zweiterBehaelter);
      await pumpEventQueue();

      final erste =
          ausgaben(beobachtet).first as Bekannt<Map<String, NightVitals>>;
      expect(erste.laeuft, isTrue);
      expect(erste.stand, jetzt);
      expect(
        erste.wert['2026-10-20'],
        ersteKarte['2026-10-20'],
        reason:
            'was in den Cache ging, kommt wieder heraus — derselbe Wert, '
            'nicht ein gerundeter oder ein auf 0 gefallener',
      );
    });

    test('ein unveränderter Lauf erzeugt keinen neuen Wert — gleiche Nächte '
        'und gleiche Proben sind gleich', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final container = behaelter(
        db: db,
        quelle: _FakeHealthReading(
          schlaf: () async => [nacht(10, 20)],
          proben: {
            VitalKind.heartRate: () async => fuenfPulsproben(10, 20),
            VitalKind.heartRateVariability: () async => [
              probe(fenster(10, 20).von.add(const Duration(hours: 2)), 41.5),
            ],
          },
        ),
      );

      final erst = (await container.read(
        nachtWerteProvider.future,
      ) as Bekannt<Map<String, NightVitals>>).wert;

      container.invalidate(nachtWerteProvider);
      final beobachtet = hoerZu(container);
      await pumpEventQueue();

      final erneut =
          ausgaben(beobachtet).last as Bekannt<Map<String, NightVitals>>;

      expect(
        erneut.wert['2026-10-20'],
        erst['2026-10-20'],
        reason:
            'NightVitals ist Abhängigkeit abgeleiteter Provider. Ohne == '
            'wäre jeder neu gebaute Wert ungleich dem vorigen und alles '
            'Abgeleitete liefe neu — das wäre Fehler 03, wortgleich im '
            'neuen Code (CLAUDE.md)',
      );
      expect(
        erneut.wert['2026-10-20'].hashCode,
        erst['2026-10-20'].hashCode,
        reason: 'wer == mitgibt, gibt hashCode mit',
      );
    });
  });
}

/// Konfigurierbare Test-Quelle. Zählt die Abfragen je Messreihe und merkt
/// sich die Grenzen, mit denen gefragt wurde — beides braucht die
/// Zusicherung „dreimal insgesamt".
///
/// Alle Antworten sind erfunden; aus echten Gesundheitsdaten stammt hier
/// kein einziger Wert.
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading({
    FutureOr<List<SleepNight>> Function()? schlaf,
    Map<VitalKind, FutureOr<List<QuantitySample>> Function()> proben = const {},
  }) : _schlaf = schlaf ?? (() => const <SleepNight>[]),
       _proben = proben;

  final FutureOr<List<SleepNight>> Function() _schlaf;
  final Map<VitalKind, FutureOr<List<QuantitySample>> Function()> _proben;

  final Map<VitalKind, int> aufrufe = {
    for (final art in VitalKind.values) art: 0,
  };
  final Map<VitalKind, DateTime> von = {};
  final Map<VitalKind, DateTime> bis = {};
  int schlafAufrufe = 0;

  int get aufrufeGesamt => aufrufe.values.fold(0, (a, b) => a + b);

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafAufrufe += 1;
    return _schlaf();
  }

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    aufrufe[kind] = (aufrufe[kind] ?? 0) + 1;
    von[kind] = from;
    bis[kind] = through;
    final antwort = _proben[kind];
    if (antwort == null) return const [];
    return antwort();
  }
}
