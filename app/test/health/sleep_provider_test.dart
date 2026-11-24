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

/// Tests für `sleepProvider` und `rechenfensterProvider` (#113, Teil 2 von
/// zwei — die Ablage steht in `test/data/schlaf_cache_test.dart`).
///
/// **Warum es diesen Provider bisher nicht gibt.**
/// `lib/health/health_provider.dart` sagt es im Kopfkommentar: „Für Schlaf
/// legt die Umbau-Spec weder Cache-Tabelle noch Ladereihenfolge fest. Wer
/// ihn anlegt, entscheidet beides." Die Cache-Tabelle entscheidet
/// `schlaf_cache_test.dart`; **diese** Datei entscheidet die Ladereihenfolge
/// und das Fenster.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Entscheidung 1 — die Ladereihenfolge ist die von `dailyMetricsProvider`
///
/// Wörtlich dieselbe wie in Spec 5.5 und im Ticket: Cache lesen → **nur bei
/// vorhandenem Cache** sofort `Bekannt(laeuft: true)` ausgeben → Kanal
/// fragen, höchstens drei Versuche → zurückschreiben → `alsMesswert`. Keine
/// eigene Variante: Ein zweiter Ladeweg neben dem bestehenden wäre eine
/// zweite Stelle, an der Tims Fehler („Ladezustand als Leerstand") neu
/// entstehen könnte. Die Begründung für jeden einzelnen Schritt steht
/// ausführlich in `health_provider.dart` und muss hier nicht wiederholt
/// werden — sie gilt unverändert.
///
/// **Ohne Cache gibt es keine Zwischenausgabe.** Das ist kein Versehen,
/// sondern dieselbe bewusste Entscheidung wie bei `dailyMetricsProvider`
/// (dort im Quelltext ausführlich begründet): Ein `state =` während `build()`
/// nagelt Riverpods `.future` auf diesen Zwischenwert fest, und ohne Cache
/// gibt es nichts, was das rechtfertigte. Der Platzhalter entsteht dann in
/// der Ansicht aus dem noch nicht aufgelösten Provider — **einmal**, und
/// nach dem ersten `Bekannt` nie wieder.
///
/// ## Entscheidung 2 — das Rechenfenster ist ein eigener Provider
///
/// ```dart
/// /// Das Rechenfenster aus `docs/SPEC.md` Abschnitt 3: **30 Tage**,
/// /// heutiger Tag eingeschlossen, Beginn auf `BerlinCalendar.startOfDay`.
/// /// Der eingestellte Betrachtungszeitraum (`dataWindowProvider`) kann es
/// /// **verkürzen, nie verlängern**.
/// final rechenfensterProvider = Provider<DataWindow>(...);
/// ```
///
/// Warum nicht einfach `dataWindowProvider` benutzen: Der ist der vom Nutzer
/// eingestellte Betrachtungszeitraum und steht standardmäßig auf
/// `unlimited` — der Schlaf-Provider würde damit die ganze Historie holen,
/// obwohl SPEC 3 über 30 Tage rechnet. Warum nicht umgekehrt
/// `dataWindowProvider` auf 30 Tage kappen: Der gilt app-weit, auch für
/// Gewicht und Schritte, die weiter zurückschauen dürfen.
/// `dailyMetricsProvider` bleibt deshalb unangetastet (ein Provider für alle
/// Schirme, Spec 5.1); der Erholung-Schirm schneidet seine Tageswerte mit
/// `rechenfensterProvider` selbst zu (#115).
///
/// **Der Beginn geht über `BerlinCalendar`, nicht über eine feste Dauer.**
/// `jetzt.subtract(const Duration(days: 29))` ist über eine
/// Zeitumstellung hinweg um einen Tag falsch — der Test mit dem Fenster über
/// den 29.03.2026 hält genau das fest.
///
/// ## Entscheidung 3 — parallel, weil unabhängig
///
/// Ticket und Spec 8 verlangen, dass Tageswerte und Nächte **parallel**
/// geholt werden. `sleepProvider` hängt deshalb an **keinem** anderen
/// Provider, der selbst den Kanal fragt. Zwei Provider, die niemand
/// aneinanderkettet, laufen von selbst gleichzeitig — der Test unten prüft
/// das als beobachtbare Eigenschaft, nicht als Absichtserklärung.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// final rechenfensterProvider = Provider<DataWindow>(...);
///
/// final sleepProvider =
///     AsyncNotifierProvider<SleepNotifier, Messwert<List<SleepNight>>>(
///       SleepNotifier.new,
///     );
///
/// class SleepNotifier extends AsyncNotifier<Messwert<List<SleepNight>>> {
///   @override
///   Future<Messwert<List<SleepNight>>> build();
/// }
/// ```
///
/// Der Klassenname `SleepNotifier` ist nur insofern verbindlich, als es ein
/// `(Async)Notifier` sein muss: Der Provider gibt bei einem Cache-Treffer
/// während `build()` einen Zwischenzustand über `state =` aus, und das kann
/// ein `FutureProvider` nicht.
///
/// **`.future` wird hier nur dort benutzt, wo kein Cache vorliegt.** In
/// Riverpod 3.4.3 löst `AsyncNotifier.future` mit der **zuerst**
/// ausgegebenen Ausgabe auf und friert sie ein; bei einem Cache-Treffer wäre
/// das die Zwischenausgabe, nicht das Ergebnis. Die vollständige Herleitung
/// steht im Kopf von `health_provider_test.dart` und gilt hier
/// unverändert — Endzustände mit Cache werden über den Listener gelesen.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Nachgruppieren von Abschnitten zu Nächten.** Der Kanal liefert
///   bereits Nächte (`health_types.dart`); der Provider reicht sie durch.
///   Der Test „unverändert durchgereicht" hält das fest, baut aber keine
///   Gruppierungslogik auf, die es in Dart nicht geben soll.
/// - **Die Wiederholungsregel der echten App** (Spec 5.3c) — `retry: (_, _)
///   => null` ist für Tests vorgeschrieben und wird unten überall gesetzt.
///   Geprüft wird nur die **eigene** Obergrenze von drei Versuchen, die
///   `dailyMetricsProvider` schon trägt.
void main() {
  // Fester Zeitpunkt statt `DateTime.now()` — sonst wäre jede
  // Fenstergrenze unten in jedem Lauf eine andere (Spec 5.3b).
  // 20.10.2026, 14:32 UTC = 16:32 Berliner Sommerzeit.
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);

  /// Der erwartete Fensterbeginn zu [jetzt]: 30 Tage einschließlich des
  /// heutigen Tages, also der 21.09.2026 als Berliner Tagesbeginn.
  final erwarteterBeginn = BerlinCalendar.startOfDay(
    DateTime.utc(2026, 9, 21, 12),
  );

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag, 12));

  SleepNight nacht(int monat, int tag, {SleepStage phase = SleepStage.core}) =>
      SleepNight(
        date: tagesbeginn(2026, monat, tag),
        session: SleepSession(
          segments: [
            SleepSegment(
              stage: phase,
              start: DateTime.utc(2026, monat, tag - 1, 21, 0),
              end: DateTime.utc(2026, monat, tag, 4, 30),
            ),
          ],
        ),
      );

  ProviderContainer behaelter({
    required AppCache db,
    required HealthReading quelle,
    DateTime? uhr,
    DataWindow? betrachtungszeitraum,
  }) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => uhr ?? jetzt),
        if (betrachtungszeitraum != null)
          dataWindowProvider.overrideWith((ref) => betrachtungszeitraum),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Die Messwert-Ausgaben eines Listeners, ohne die äußere
  /// `AsyncValue`-Hülle, die der `AsyncNotifierProvider` zwangsläufig
  /// mitbringt.
  List<Messwert<List<SleepNight>>> ausgaben(
    List<AsyncValue<Messwert<List<SleepNight>>>> beobachtet,
  ) => beobachtet
      .whereType<AsyncData<Messwert<List<SleepNight>>>>()
      .map((d) => d.value)
      .toList();

  List<AsyncValue<Messwert<List<SleepNight>>>> hoerZu(
    ProviderContainer container,
  ) {
    final beobachtet = <AsyncValue<Messwert<List<SleepNight>>>>[];
    container.listen(
      sleepProvider,
      (prev, next) => beobachtet.add(next),
      fireImmediately: true,
    );
    return beobachtet;
  }

  group(
    'Das Rechenfenster sind 30 Tage (SPEC 3) — der Betrachtungszeitraum '
    'kürzt es, verlängert es nie',
    () {
      test(
        'ohne eingestellten Betrachtungszeitraum beginnt das Fenster 30 '
        'Tage vor heute, auf dem Berliner Tagesbeginn',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final container = behaelter(db: db, quelle: _FakeHealthReading());

          final fenster = container.read(rechenfensterProvider);

          expect(fenster.start, erwarteterBeginn);
          expect(
            BerlinCalendar.days(from: fenster.start!, through: jetzt),
            hasLength(30),
            reason:
                'dreißig Tage, heutiger Tag eingeschlossen — nicht 29 und '
                'nicht 31',
          );
        },
      );

      test(
        'ein Fenster über die Zeitumstellung hinweg zählt Kalendertage, '
        'nicht 24-Stunden-Schritte',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          // 20.04.2026: Die Sommerzeit begann am 29.03.2026. Ein Fenster
          // von 30 Tagen reicht über diese Umstellung zurück.
          final imApril = DateTime.utc(2026, 4, 20, 10);
          final container = behaelter(
            db: db,
            quelle: _FakeHealthReading(),
            uhr: imApril,
          );

          final fenster = container.read(rechenfensterProvider);

          expect(
            fenster.start,
            BerlinCalendar.startOfDay(DateTime.utc(2026, 3, 22, 12)),
            reason:
                '`jetzt.subtract(const Duration(days: 29))` landete hier '
                'auf dem 21.03. — eine Stunde Zeitumstellung, ein Tag zu '
                'viel im Fenster. Deshalb geht der Beginn über '
                'BerlinCalendar',
          );
          expect(
            BerlinCalendar.days(from: fenster.start!, through: imApril),
            hasLength(30),
          );
        },
      );

      test(
        'ein kürzerer Betrachtungszeitraum gewinnt — er verkürzt das '
        'Rechenfenster',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final container = behaelter(
            db: db,
            quelle: _FakeHealthReading(),
            betrachtungszeitraum: DataWindow(start: DateTime.utc(2026, 10, 10)),
          );

          expect(
            container.read(rechenfensterProvider).start,
            BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 10, 12)),
          );
        },
      );

      test(
        'ein längerer Betrachtungszeitraum gewinnt nicht — das '
        'Rechenfenster bleibt bei 30 Tagen',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final container = behaelter(
            db: db,
            quelle: _FakeHealthReading(),
            betrachtungszeitraum: DataWindow(start: DateTime.utc(2026, 1, 1)),
          );

          expect(
            container.read(rechenfensterProvider).start,
            erwarteterBeginn,
            reason:
                'SPEC 3 rechnet über 30 Tage. Ein Betrachtungszeitraum von '
                'zehn Monaten darf daraus keine zehn Monate machen — sonst '
                'rechnen Diagramm und Ampel mit verschiedenen Nächten',
          );
        },
      );

      test(
        'der Kanal wird mit genau diesem Beginn gefragt, nicht mit einem '
        'Zeitpunkt mitten am Tag',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final quelle = _FakeHealthReading(
            schlaf: () async => [nacht(10, 20)],
          );
          final container = behaelter(db: db, quelle: quelle);

          await container.read(sleepProvider.future);

          expect(quelle.schlafVon, erwarteterBeginn);
          expect(
            quelle.schlafBis,
            jetzt,
            reason: 'die obere Grenze ist der Zeitpunkt der Uhr, nicht ein '
                'gerundeter Tag',
          );
        },
      );
    },
  );

  group(
    'Ohne Cache: der Platzhalter erscheint genau einmal (Ticket, '
    '„Fertig, wenn")',
    () {
      test(
        'vor der Kanal-Antwort gibt es keine Messwert-Ausgabe, danach '
        'Bekannt — und nie ein NochNie dazwischen oder danach',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final antwort = Completer<List<SleepNight>>();
          final container = behaelter(
            db: db,
            quelle: _FakeHealthReading(schlaf: () => antwort.future),
          );

          final beobachtet = hoerZu(container);
          await pumpEventQueue();

          expect(
            ausgaben(beobachtet),
            isEmpty,
            reason:
                'ohne Cache gibt es nichts zu zeigen. Eine vorgezogene '
                'Ausgabe wäre entweder ein erfundener Wert oder ein '
                'Leerstand, der nur ein Ladezustand ist — genau der Fehler, '
                'den dieser Umbau abstellt',
          );

          antwort.complete([nacht(10, 20)]);
          await pumpEventQueue();

          final gesehen = ausgaben(beobachtet);
          expect(gesehen.last, isA<Bekannt<List<SleepNight>>>());
          expect(
            gesehen.whereType<NochNie<List<SleepNight>>>(),
            isEmpty,
            reason: 'zurück nach NochNie gibt es nicht (Spec 5.3)',
          );

          final bekannt = gesehen.last as Bekannt<List<SleepNight>>;
          expect(bekannt.laeuft, isFalse);
          expect(bekannt.stand, jetzt);
          expect(bekannt.wert, hasLength(1));
        },
      );
    },
  );

  group('Mit Cache: der Platzhalter erscheint nie (Spec 5.5)', () {
    test(
      'zuerst Bekannt(laeuft: true) mit dem Cache-Stand, danach '
      'Bekannt(laeuft: false) mit dem frischen Wert',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final cacheStand = DateTime.utc(2026, 10, 20, 9);
        await CacheRepository(
          db,
        ).schreibeNaechte([nacht(10, 19)], gelesenAm: cacheStand);

        final antwort = Completer<List<SleepNight>>();
        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(schlaf: () => antwort.future),
        );

        final beobachtet = hoerZu(container);
        await pumpEventQueue();

        final waehrendDesLaufs = ausgaben(beobachtet).last;
        expect(waehrendDesLaufs, isA<Bekannt<List<SleepNight>>>());
        final ausDemCache = waehrendDesLaufs as Bekannt<List<SleepNight>>;
        expect(ausDemCache.laeuft, isTrue);
        expect(ausDemCache.stand, cacheStand);
        expect(
          BerlinCalendar.dayKey(ausDemCache.wert.single.date),
          '2026-10-19',
        );

        antwort.complete([nacht(10, 19), nacht(10, 20)]);
        await pumpEventQueue();

        final gesehen = ausgaben(beobachtet);
        expect(
          gesehen.whereType<NochNie<List<SleepNight>>>(),
          isEmpty,
          reason:
              'mit Cache darf der Platzhalter kein einziges Mal auftauchen — '
              'genau das war Tims „Heute zeigt 0"',
        );
        final fertig = gesehen.last as Bekannt<List<SleepNight>>;
        expect(fertig.laeuft, isFalse);
        expect(fertig.wert, hasLength(2));
        expect(
          fertig.stand,
          jetzt,
          reason: 'ein frisch geholter Wert trägt "jetzt" als Stand, nicht '
              'den alten Cache-Stand (Spec 5.3d)',
        );
      },
    );
  });

  group('Leer, gescheitert, und was dazwischen nicht passieren darf', () {
    test(
      'eine leere Antwort ohne Cache wird LeerNachLauf, nie Bekannt([])',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(schlaf: () async => const <SleepNight>[]),
        );

        final ergebnis = await container.read(sleepProvider.future);

        expect(ergebnis, isA<LeerNachLauf<List<SleepNight>>>());
        expect(
          (ergebnis as LeerNachLauf<List<SleepNight>>).gelaufen,
          jetzt,
        );
      },
    );

    test(
      'ein gescheiterter Nachlauf nimmt den Wert aus dem Cache nicht weg',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final cacheStand = DateTime.utc(2026, 10, 20, 9);
        await CacheRepository(
          db,
        ).schreibeNaechte([nacht(10, 19)], gelesenAm: cacheStand);

        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(
            schlaf: () async => throw Exception('HealthKit nicht erreichbar'),
          ),
        );

        // Nicht `.future`: Mit Cache gibt der Provider zwischendurch aus,
        // und `.future` friert in Riverpod 3.4.3 die erste Ausgabe ein.
        final beobachtet = hoerZu(container);
        await pumpEventQueue();

        final ergebnis = ausgaben(beobachtet).last;
        expect(
          ergebnis,
          isNot(isA<Fehlgeschlagen<List<SleepNight>>>()),
          reason: 'Fehlgeschlagen gilt nur ohne Cache (Spec 5.3a)',
        );
        final bekannt = ergebnis as Bekannt<List<SleepNight>>;
        expect(bekannt.laeuft, isFalse);
        expect(bekannt.stand, cacheStand);
        expect(BerlinCalendar.dayKey(bekannt.wert.single.date), '2026-10-19');
      },
    );

    test(
      'ohne Cache wird ein gescheiterter Lauf Fehlgeschlagen — nicht '
      'LeerNachLauf, das hieße „nichts aufgezeichnet"',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(
            schlaf: () async => throw Exception('HealthKit nicht erreichbar'),
          ),
        );

        final ergebnis = await container.read(sleepProvider.future);

        expect(ergebnis, isA<Fehlgeschlagen<List<SleepNight>>>());
        expect(
          (ergebnis as Fehlgeschlagen<List<SleepNight>>).gelaufen,
          jetzt,
        );
      },
    );

    test(
      'die Zahl der Versuche ist begrenzt: dreimal, dann gilt das Ergebnis',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final quelle = _FakeHealthReading(
          schlaf: () async => throw Exception('HealthKit nicht erreichbar'),
        );
        final container = behaelter(db: db, quelle: quelle);

        await container.read(sleepProvider.future);

        expect(
          quelle.schlafAufrufe,
          3,
          reason:
              'eine entzogene Freigabe sieht aus wie ein vorübergehender '
              'Fehler — ohne Obergrenze liefe die App endlos weiter und '
              'zeigte dauerhaft einen Platzhalter statt einer Aussage '
              '(dieselbe Grenze wie bei dailyMetricsProvider)',
        );
      },
    );

    test(
      'ein vorübergehender Fehler wird überstanden: zwei Fehlschläge, '
      'dann das Ergebnis',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        var versuche = 0;
        final quelle = _FakeHealthReading(
          schlaf: () async {
            versuche += 1;
            if (versuche < 3) throw Exception('kurz nicht erreichbar');
            return [nacht(10, 20)];
          },
        );
        final container = behaelter(db: db, quelle: quelle);

        final ergebnis = await container.read(sleepProvider.future);

        expect(ergebnis, isA<Bekannt<List<SleepNight>>>());
        expect(quelle.schlafAufrufe, 3);
      },
    );
  });

  group('Zurückschreiben und kalter Neustart', () {
    test(
      'nach einem erfolgreichen Lauf liegen die Nächte im Cache, und ein '
      'neuer Container zeigt sie sofort — ohne auf den Kanal zu warten',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        final ersterContainer = behaelter(
          db: db,
          quelle: _FakeHealthReading(
            schlaf: () async => [nacht(10, 19), nacht(10, 20)],
          ),
        );
        expect(
          await ersterContainer.read(sleepProvider.future),
          isA<Bekannt<List<SleepNight>>>(),
        );

        final imCache = await CacheRepository(
          db,
        ).liesNaechte(DataWindow.unlimited);
        expect(imCache!.werte, hasLength(2));
        expect(
          imCache.stand,
          jetzt,
          reason: 'der Stand je Zeile kommt aus dem gerade gelaufenen '
              'Lauf (Spec 5.3b)',
        );

        // Der Kanal des zweiten Containers hängt für immer fest: Was
        // sichtbar wird, kann dann nur aus dem Cache stammen.
        final haengtFest = Completer<List<SleepNight>>();
        final zweiterContainer = behaelter(
          db: db,
          quelle: _FakeHealthReading(schlaf: () => haengtFest.future),
          uhr: jetzt.add(const Duration(minutes: 5)),
        );

        final beobachtet = hoerZu(zweiterContainer);
        await pumpEventQueue();

        final erste = ausgaben(beobachtet).first;
        expect(erste, isA<Bekannt<List<SleepNight>>>());
        final bekannt = erste as Bekannt<List<SleepNight>>;
        expect(bekannt.wert, hasLength(2));
        expect(bekannt.laeuft, isTrue);
        expect(bekannt.stand, jetzt);
      },
    );
  });

  group('Was der Kanal liefert, wird durchgereicht — nicht nachgruppiert', () {
    test(
      'Reihenfolge, Abschnitte und Nickerchen kommen unverändert an',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        final mitTagschlaf = SleepNight(
          date: tagesbeginn(2026, 10, 20),
          session: nacht(10, 20, phase: SleepStage.deep).session,
          naps: [
            SleepSession(
              segments: [
                SleepSegment(
                  stage: SleepStage.core,
                  start: DateTime.utc(2026, 10, 20, 11, 30),
                  end: DateTime.utc(2026, 10, 20, 11, 55),
                ),
              ],
            ),
          ],
        );
        final container = behaelter(
          db: db,
          quelle: _FakeHealthReading(
            schlaf: () async => [nacht(10, 19), mitTagschlaf],
          ),
        );

        final ergebnis = await container.read(sleepProvider.future);
        final werte = (ergebnis as Bekannt<List<SleepNight>>).wert;

        expect(
          werte.map((n) => BerlinCalendar.dayKey(n.date)).toList(),
          ['2026-10-19', '2026-10-20'],
          reason:
              'der Kanal gruppiert bereits in Nächte (health_types.dart) — '
              'in Dart wird nicht noch einmal gruppiert, sortiert oder '
              'zusammengelegt',
        );
        expect(werte.last.session.segments.single.stage, SleepStage.deep);
        expect(werte.last.naps, hasLength(1));
      },
    );
  });

  group(
    'Tageswerte und Nächte laufen parallel, nicht nacheinander (Spec 8)',
    () {
      test(
        'beide Kanal-Abfragen sind gleichzeitig unterwegs',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          final schlafAntwort = Completer<List<SleepNight>>();
          final tagesAntwort = Completer<List<DailyMetrics>>();
          final quelle = _FakeHealthReading(
            schlaf: () => schlafAntwort.future,
            tageswerte: () => tagesAntwort.future,
          );
          final container = behaelter(db: db, quelle: quelle);

          // Beide Provider werden gelesen, keiner wartet auf den anderen.
          final beide = Future.wait([
            container.read(sleepProvider.future),
            container.read(dailyMetricsProvider.future),
          ]);
          await pumpEventQueue();

          expect(
            quelle.schlafLaeuft && quelle.tagesLaeuft,
            isTrue,
            reason:
                'nacheinander hieße: der zweite Aufruf hat noch nicht '
                'einmal begonnen, während der erste hängt. Über 30 Tage '
                'verdoppelt das die Wartezeit beim Öffnen des Schirms',
          );

          schlafAntwort.complete([nacht(10, 20)]);
          tagesAntwort.complete(const [
            DailyMetrics(tag: '2026-10-20', steps: 8042),
          ]);
          await beide;
        },
      );
    },
  );
}

/// Konfigurierbare Test-Quelle. Zählt Aufrufe, merkt sich die Grenzen, mit
/// denen gefragt wurde, und sagt, ob gerade ein Aufruf unterwegs ist — das
/// braucht der Parallelitäts-Test.
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

  int schlafAufrufe = 0;
  int tagesAufrufe = 0;
  bool schlafLaeuft = false;
  bool tagesLaeuft = false;
  DateTime? schlafVon;
  DateTime? schlafBis;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafAufrufe += 1;
    schlafVon = from;
    schlafBis = through;
    schlafLaeuft = true;
    try {
      return await _schlaf();
    } finally {
      schlafLaeuft = false;
    }
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    tagesAufrufe += 1;
    tagesLaeuft = true;
    try {
      return await _tageswerte();
    } finally {
      tagesLaeuft = false;
    }
  }
}
