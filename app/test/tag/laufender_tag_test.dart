// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke) —
// die verdecken sonst die gleichnamigen Matcher. Dieselbe Begründung wie in
// `test/live/live_provider_test.dart`.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
// `fake_async` kommt über `flutter_test` mit, steht aber nicht selbst in
// `pubspec.yaml`. Der Auftrag verlangt `fakeAsync` für den Zeitgeber, und
// `flutter_test` exportiert es nicht. Eine Zeile in `pubspec.yaml` ist keine
// Testdatei und gehört nicht in den Commit des Test-Agenten.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/data/wach_belege.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/live/live_provider.dart';
import 'package:repit/live/live_types.dart';
import 'package:repit/shell/tageswacht.dart';
import 'package:repit/tag/laufender_tag_provider.dart';

import '../ernaehrung/tag_huelle.dart';
import '../health/health_reading_attrappe.dart';
import 'berliner_wanduhr.dart';

/// Tests für **den laufenden Tag als Provider** (#455 unter #375,
/// Tagesgrenze): `laufenderTagProvider`, `wachbelegProvider`, die Anstöße
/// aus `Tageswacht`, `esstagProvider` und `offenerTagProvider` als Leser
/// und das `staleDate` der Live-Aktivität.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`,
/// Abschnitte „`laufenderTagProvider`“ und „Eigene Belege schreiben“,
/// Entscheidung 9 (Tim, 10.11.2026) und die Vorgaben V9, V10, V11, V13,
/// V16, V17 (vom Planenden formuliert, laut Spec von Tim übernommen).
/// Pflichtfälle aus dem Plan `docs/superpowers/plans/2026-11-10-tagesgrenze.md`,
/// Task 5.
///
/// Verbindlich aus dem Plan, in `lib/tag/laufender_tag_provider.dart`:
///
/// ```dart
/// final laufenderTagProvider =
///     NotifierProvider<LaufenderTagNotifier, Tagesstand>(…);
/// class LaufenderTagNotifier extends Notifier<Tagesstand> {
///   Future<void> pruefe();
/// }
/// final wachbelegProvider = NotifierProvider<WachbelegNotifier, void>(…);
/// class WachbelegNotifier extends Notifier<void> {
///   Future<void> merke(WachArt art);
/// }
/// ```
///
/// `esstagProvider` und `offenerTagProvider` behalten Namen und Typ (V17).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die eigenen Belege liest der Provider über
///   `wachbelegRepositoryProvider`.** Einige Fälle überschreiben das
///   Repository mit einer Attrappe ([_Belege]), weil eine echte drift-Datei
///   unter `fakeAsync` und in Widget-Tests nicht verlässlich abschließt; die
///   übrigen Fälle laufen gegen die echte Tabelle im Speicher.
/// - **Die Nächte liest der Provider aus `sleepProvider`**, nie über
///   `HealthReading.sleepSessions`. `sleepProvider` ist hier überschrieben
///   ([_Naechte]); `melde` setzt einen neuen Stand, wie es ein Nachlauf täte.
/// - **„Ohne auf die Datenbank zu warten“** heißt: Das erste Lesen von
///   `laufenderTagProvider` liefert synchron einen fertigen `Tagesstand`,
///   auch wenn das Repository und `sleepProvider` nie antworten.
/// - **V11, das Fenster ab 03:00:** Gefragt werden Schritte mit `von` =
///   03:00 des Kalendertags (verglichen als Zeitpunkt). Bei Trainings
///   verlangt diese Datei nur, dass `von` nicht nach 03:00 liegt — ein
///   früherer Beginn fängt ein Training, das vor 03:00 begann und über
///   04:00 lief (V2), und die Spec schließt das nicht aus. `bis` legt diese
///   Datei nicht fest. **Um 08:00 und danach wird nicht gefragt** (Spec,
///   Tabelle „ab 08:00 — K normal“); **um 04:00 schon**.
/// - **„Keine Benachrichtigung“** wird mit `container.listen` gezählt; ein
///   gleicher, neu gerechneter `Tagesstand` darf keinen Ruf auslösen.
/// - **`merke` schreibt den Zeitpunkt der Uhr (`clockProvider`) als UTC**,
///   in der Spalte `art` den Namen des `WachArt`-Werts, und wartet, bis der
///   angestoßene `pruefe()` den neuen Beleg sieht. Geprüft wird das über
///   `zuletztWach` und `endetSpaetestens`, ohne die Reihenfolge der
///   Abfragen festzulegen. Nach dem `await` darf noch ein
///   `pumpEventQueue()` nötig sein; mehr nicht.
/// - **`EsstagNotifier.pruefe()`** wird hier nur aufgerufen, nicht
///   abgewartet: Ob es `void` bleibt oder ein `Future` zurückgibt, legt
///   diese Datei nicht fest.
/// - **`Tageswacht`:** Ein Beleg `oeffnen` beim Aufbau, einer je `resumed`;
///   `inactive` allein schreibt keinen (dieselbe Lesart wie
///   `tageswacht_test.dart`). Die Reihenfolge „nach
///   `pruefeTageswechsel()`“ prüft diese Datei nicht.
/// - **Der Zeitgeber feuert genau zu `endetSpaetestens`:** eine Sekunde
///   vorher steht noch der alte Tag, zum Zeitpunkt selbst der neue. Danach
///   ist er neu gestellt (der nächste Wechsel kommt ebenfalls von selbst).
///   Nach `dispose` steht kein Zeitgeber mehr aus.
/// - **`staleDate`** ist `EssenKarte.verfaelltUm`, verglichen als
///   Zeitpunkt; die Karte entsteht wie in `live_provider_test.dart` über
///   `liveSollProvider`.
/// - **Die bekannte Lücke aus V10** (Kaltstart zwischen 04:00 und 08:00
///   zeigt kurz den neuen Tag) wird hier **nicht** festgeschrieben: Eine
///   Fassung, die sie schließt, soll nicht rot werden.
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“), Uhrzeiten als Berliner Wanduhr über [berlin].
/// Der 12.01.2099 ist ein Montag.
void main() {
  const sa = '2099-01-10';
  const mo = '2099-01-12';
  const di = '2099-01-13';
  const mi = '2099-01-14';

  late AppCache db;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> eigenerBeleg(WachArt art, DateTime zeitpunkt) => db
      .into(db.wachBelege)
      .insert(WachBelegeCompanion.insert(zeitpunkt: zeitpunkt, art: art.name));

  /// Die Hauptnacht Mo 21:00 bis Di 03:30 mit 6 h Schlaf (21:00–00:00 core,
  /// 00:00–00:30 wach, 00:30–03:30 deep), Aufwachtag Dienstag.
  SleepNight fruehBeendeteNacht() => SleepNight(
    date: datumAusTag(di),
    session: SleepSession(
      segments: [
        SleepSegment(
          stage: SleepStage.core,
          start: berlin(mo, 21, 0),
          end: berlin(di, 0, 0),
        ),
        SleepSegment(
          stage: SleepStage.awake,
          start: berlin(di, 0, 0),
          end: berlin(di, 0, 30),
        ),
        SleepSegment(
          stage: SleepStage.deep,
          start: berlin(di, 0, 30),
          end: berlin(di, 3, 30),
        ),
      ],
    ),
  );

  Messwert<List<SleepNight>> bekannt(
    List<SleepNight> naechte, {
    bool laeuft = false,
  }) => Bekannt<List<SleepNight>>(
    naechte,
    stand: berlin(mo, 12, 0),
    laeuft: laeuft,
  );

  /// Echte Tabelle im Speicher (es sei denn, [belege] ersetzt das
  /// Repository), steuerbare Uhr, abgeschaltete Wiederholung (`CLAUDE.md`).
  ({ProviderContainer c, _Attrappe health, void Function(DateTime) stelleUhr})
  behaelter({
    required DateTime jetzt,
    _Attrappe? health,
    WachbelegRepository? belege,
    Future<Messwert<List<SleepNight>>> Function()? naechte,
    List<Override> zusaetzlich = const [],
  }) {
    var uhr = jetzt;
    final quelle = health ?? _Attrappe();
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => uhr),
        healthProvider.overrideWithValue(quelle),
        sleepProvider.overrideWith(
          () => _Naechte(naechte ?? () async => bekannt(const [])),
        ),
        if (belege != null)
          wachbelegRepositoryProvider.overrideWithValue(belege),
        ...zusaetzlich,
      ],
    );
    addTearDown(c.dispose);
    return (c: c, health: quelle, stelleUhr: (neu) => uhr = neu);
  }

  /// Lässt den Anstoß aus `build()` laufen und sieht danach selbst nach.
  Future<Tagesstand> nachgesehen(ProviderContainer c) async {
    c.listen(laufenderTagProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(laufenderTagProvider.notifier).pruefe();
    await pumpEventQueue();
    return c.read(laufenderTagProvider);
  }

  // ─────────────────────────────────────────────────────────────────────
  group('Der erste Wert (V10)', () {
    test('um Di 01:30 ist der erste Wert sofort Montag, läuft noch — ohne '
        'auf Datenbank und Nächte zu warten', () {
      final b = behaelter(
        jetzt: berlin(di, 1, 30),
        belege: _Belege(halten: Completer<void>()),
        naechte: () => Completer<Messwert<List<SleepNight>>>().future,
      );

      expect(
        b.c.read(laufenderTagProvider),
        Tagesstand(
          tag: mo,
          grund: Tagesgrund.laeuftNoch,
          endetSpaetestens: berlin(di, 4, 0),
        ),
      );
    });

    test('der erste Wert nimmt die Nächte aus dem Cache von sleepProvider, '
        'auch während Health nachliest', () async {
      final b = behaelter(
        jetzt: berlin(di, 3, 45),
        belege: _Belege(halten: Completer<void>()),
        naechte: () async => bekannt([fruehBeendeteNacht()], laeuft: true),
      );
      await b.c.read(sleepProvider.future);

      final erster = b.c.read(laufenderTagProvider);

      expect(erster.tag, di);
      expect(erster.grund, Tagesgrund.nachtVorbei);
      expect(erster.endetSpaetestens, berlin(mi, 4, 0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('pruefe() und die Belege (V9, V11)', () {
    test('um 05:10 mit eigenen Belegen 03:10 und 04:05 und Schritten um '
        '05:00: Montag, verlängert bis 06:00', () async {
      await eigenerBeleg(WachArt.oeffnen, berlin(di, 3, 10));
      await eigenerBeleg(WachArt.buchung, berlin(di, 4, 5));
      final health = _Attrappe(
        schritte: [QuantitySample(date: berlin(di, 5, 0), value: 400)],
      );
      final b = behaelter(jetzt: berlin(di, 5, 10), health: health);

      expect(
        await nachgesehen(b.c),
        Tagesstand(
          tag: mo,
          grund: Tagesgrund.verlaengert,
          endetSpaetestens: berlin(di, 6, 0),
          zuletztWach: Wachbeleg(
            von: berlin(di, 5, 0),
            quelle: WachQuelle.schritte,
          ),
        ),
      );
      expect(health.schrittAufrufe, isNotEmpty);
      for (final aufruf in health.schrittAufrufe) {
        expect(
          aufruf.von.isAtSameMomentAs(berlin(di, 3, 0)),
          isTrue,
          reason: 'Schritte ab 03:00 (V11), gefragt ab ${aufruf.von}',
        );
      }
      expect(health.trainingAufrufe, isNotEmpty);
      for (final aufruf in health.trainingAufrufe) {
        expect(
          aufruf.von.isAfter(berlin(di, 3, 0)),
          isFalse,
          reason:
              'Trainings spätestens ab 03:00 (V11), gefragt ab '
              '${aufruf.von}',
        );
      }
    });

    test('um 14:00 fragt pruefe() Health weder nach Schritten noch nach '
        'Trainings', () async {
      final health = _Attrappe();
      final b = behaelter(jetzt: berlin(di, 14, 0), health: health);

      final stand = await nachgesehen(b.c);

      expect(stand.tag, di);
      expect(stand.grund, Tagesgrund.normal);
      expect(health.schrittAufrufe, isEmpty);
      expect(health.trainingAufrufe, isEmpty);
      expect(health.schlafAufrufe, 0);
    });

    for (final (stunde, minute) in const [
      (0, 30),
      (1, 30),
      (3, 59),
      (8, 0),
      (23, 30),
    ]) {
      final uhrzeit =
          '${'$stunde'.padLeft(2, '0')}:${'$minute'.padLeft(2, '0')}';
      test('um $uhrzeit fragt pruefe() Health nicht (nur 04:00 bis vor '
          '08:00)', () async {
        final health = _Attrappe();
        final b = behaelter(jetzt: berlin(di, stunde, minute), health: health);

        await nachgesehen(b.c);

        expect(health.schrittAufrufe, isEmpty);
        expect(health.trainingAufrufe, isEmpty);
      });
    }

    for (final (stunde, minute) in const [(4, 0), (7, 59)]) {
      final uhrzeit =
          '${'$stunde'.padLeft(2, '0')}:${'$minute'.padLeft(2, '0')}';
      test(
        'um $uhrzeit fragt pruefe() Health nach Schritten und Trainings',
        () async {
          final health = _Attrappe();
          final b = behaelter(
            jetzt: berlin(di, stunde, minute),
            health: health,
          );

          await nachgesehen(b.c);

          expect(health.schrittAufrufe, isNotEmpty);
          expect(health.trainingAufrufe, isNotEmpty);
        },
      );
    }

    test('wirft Health um 05:10 und gibt es keine eigenen Belege: Dienstag, '
        'normal — ohne Fehler', () async {
      final b = behaelter(
        jetzt: berlin(di, 5, 10),
        health: _Attrappe(wirft: true),
      );
      b.c.listen(laufenderTagProvider, (_, _) {});
      await pumpEventQueue();

      await expectLater(
        b.c.read(laufenderTagProvider.notifier).pruefe(),
        completes,
      );
      await pumpEventQueue();

      expect(
        b.c.read(laufenderTagProvider),
        Tagesstand(
          tag: di,
          grund: Tagesgrund.normal,
          endetSpaetestens: berlin(mi, 4, 0),
        ),
      );
    });

    test('wirft Health, zählen die eigenen Belege allein', () async {
      await eigenerBeleg(WachArt.oeffnen, berlin(di, 3, 10));
      await eigenerBeleg(WachArt.buchung, berlin(di, 4, 5));
      await eigenerBeleg(WachArt.buchung, berlin(di, 5, 0));
      final b = behaelter(
        jetzt: berlin(di, 5, 10),
        health: _Attrappe(wirft: true),
      );

      expect(
        await nachgesehen(b.c),
        Tagesstand(
          tag: mo,
          grund: Tagesgrund.verlaengert,
          endetSpaetestens: berlin(di, 6, 0),
          zuletztWach: Wachbeleg(
            von: berlin(di, 5, 0),
            quelle: WachQuelle.eintrag,
          ),
        ),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Neue Nächte (Entscheidung 4, V9)', () {
    test('sleepProvider liefert um 03:45 eine fertige Nacht mit 6 h: der Tag '
        'wechselt auf Dienstag, Nacht vorbei — ohne Neustart', () async {
      final b = behaelter(
        jetzt: berlin(di, 3, 45),
        naechte: () async => bekannt(const [], laeuft: true),
      );
      final vorher = await nachgesehen(b.c);
      expect(vorher.tag, mo);
      expect(vorher.grund, Tagesgrund.laeuftNoch);

      final staende = <Tagesstand>[];
      b.c.listen(laufenderTagProvider, (_, neu) => staende.add(neu));

      (b.c.read(sleepProvider.notifier) as _Naechte).melde(
        bekannt([fruehBeendeteNacht()]),
      );
      await pumpEventQueue();

      expect(
        b.c.read(laufenderTagProvider),
        Tagesstand(
          tag: di,
          grund: Tagesgrund.nachtVorbei,
          endetSpaetestens: berlin(mi, 4, 0),
        ),
      );
      expect(staende, isNotEmpty, reason: 'Beobachter erfahren den Wechsel');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Nur bei einer Änderung (V9, Review Focus 4)', () {
    test('zweimal pruefe() ohne Änderung: keine Benachrichtigung', () async {
      await eigenerBeleg(WachArt.oeffnen, berlin(di, 3, 10));
      await eigenerBeleg(WachArt.buchung, berlin(di, 4, 5));
      final b = behaelter(
        jetzt: berlin(di, 5, 10),
        health: _Attrappe(
          schritte: [QuantitySample(date: berlin(di, 5, 0), value: 400)],
        ),
      );
      final vorher = await nachgesehen(b.c);
      expect(vorher.grund, Tagesgrund.verlaengert); // Selbstprüfung

      var rufe = 0;
      b.c.listen(laufenderTagProvider, (_, _) => rufe++);

      await b.c.read(laufenderTagProvider.notifier).pruefe();
      await pumpEventQueue();
      await b.c.read(laufenderTagProvider.notifier).pruefe();
      await pumpEventQueue();

      expect(b.c.read(laufenderTagProvider), vorher);
      expect(
        rufe,
        0,
        reason:
            'Ein gleicher, neu gerechneter Tagesstand löst nichts aus — '
            'sonst rechnet alles Abgeleitete bei jedem Nachsehen neu (03).',
      );
    });

    test(
      'auch tagsüber: zweimal pruefe() ohne Änderung meldet nichts',
      () async {
        await eigenerBeleg(WachArt.buchung, berlin(di, 12, 30));
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);

        var rufe = 0;
        b.c.listen(laufenderTagProvider, (_, _) => rufe++);

        await b.c.read(laufenderTagProvider.notifier).pruefe();
        await b.c.read(laufenderTagProvider.notifier).pruefe();
        await pumpEventQueue();

        expect(rufe, 0);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  group('esstagProvider und offenerTagProvider lesen ihn (V16, V17)', () {
    test(
      'esstagProvider folgt dem laufenden Tag, auch im verlängerten',
      () async {
        await eigenerBeleg(WachArt.oeffnen, berlin(di, 3, 10));
        await eigenerBeleg(WachArt.buchung, berlin(di, 4, 5));
        final b = behaelter(
          jetzt: berlin(di, 5, 10),
          health: _Attrappe(
            schritte: [QuantitySample(date: berlin(di, 5, 0), value: 400)],
          ),
        );
        b.c.listen(esstagProvider, (_, _) {});
        await nachgesehen(b.c);

        expect(
          b.c.read(esstagProvider),
          mo,
          reason: 'esstag() allein sagte um 05:10 schon Dienstag',
        );

        // EsstagNotifier.pruefe() geht an den laufenden Tag.
        b.stelleUhr(berlin(di, 6, 0));
        b.c.read(esstagProvider.notifier).pruefe();
        await pumpEventQueue();

        expect(b.c.read(laufenderTagProvider).tag, di);
        expect(b.c.read(esstagProvider), di);
      },
    );

    test('esstagProvider folgt einer früh beendeten Nacht', () async {
      final b = behaelter(
        jetzt: berlin(di, 3, 45),
        naechte: () async => bekannt([fruehBeendeteNacht()]),
      );
      b.c.listen(esstagProvider, (_, _) {});
      await b.c.read(sleepProvider.future);
      await nachgesehen(b.c);

      expect(
        b.c.read(esstagProvider),
        di,
        reason: 'esstag() allein sagte um 03:45 noch Montag',
      );
    });

    test('offenerTagProvider steht um Di 01:30 auf Montag; blaettere(1) '
        'bleibt dort', () async {
      final b = behaelter(jetzt: berlin(di, 1, 30));
      b.c.listen(offenerTagProvider, (_, _) {});
      await nachgesehen(b.c);

      expect(b.c.read(offenerTagProvider), mo);

      b.c.read(offenerTagProvider.notifier).blaettere(1);
      expect(
        b.c.read(offenerTagProvider),
        mo,
        reason: 'Geblättert wird höchstens bis zum laufenden Tag (V16)',
      );
    });

    test('wechselt der laufende Tag, wechselt der offene mit — auch nach '
        'blaettere(-2)', () async {
      final b = behaelter(
        jetzt: berlin(di, 3, 45),
        naechte: () async => bekannt(const [], laeuft: true),
      );
      b.c.listen(offenerTagProvider, (_, _) {});
      await nachgesehen(b.c);
      expect(b.c.read(offenerTagProvider), mo);

      b.c.read(offenerTagProvider.notifier).blaettere(-2);
      expect(b.c.read(offenerTagProvider), sa);

      (b.c.read(sleepProvider.notifier) as _Naechte).melde(
        bekannt([fruehBeendeteNacht()]),
      );
      await pumpEventQueue();

      expect(b.c.read(laufenderTagProvider).tag, di); // Selbstprüfung
      expect(b.c.read(offenerTagProvider), di);

      b.c.read(offenerTagProvider.notifier).blaettere(1);
      expect(b.c.read(offenerTagProvider), di);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('wachbelegProvider (V13)', () {
    test('merke(oeffnen) schreibt eine Zeile mit der Uhr und stößt pruefe() '
        'an', () async {
      await eigenerBeleg(WachArt.buchung, berlin(di, 3, 40));
      final jetzt = berlin(di, 4, 30);
      final b = behaelter(jetzt: jetzt);

      final vorher = await nachgesehen(b.c);
      expect(vorher.grund, Tagesgrund.verlaengert); // Selbstprüfung
      expect(vorher.endetSpaetestens, berlin(di, 4, 40)); // Selbstprüfung

      await b.c.read(wachbelegProvider.notifier).merke(WachArt.oeffnen);
      await pumpEventQueue();

      final zeilen = await (db.select(
        db.wachBelege,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(zeilen, hasLength(2));
      expect(zeilen.last.art, 'oeffnen');
      expect(
        zeilen.last.zeitpunkt.isAtSameMomentAs(jetzt),
        isTrue,
        reason: 'geschrieben wurde ${zeilen.last.zeitpunkt}',
      );

      expect(
        b.c.read(laufenderTagProvider),
        Tagesstand(
          tag: mo,
          grund: Tagesgrund.verlaengert,
          endetSpaetestens: berlin(di, 5, 30),
          zuletztWach: Wachbeleg(von: jetzt, quelle: WachQuelle.app),
        ),
      );
    });

    test('merke(buchung) tagsüber: Zeile „buchung“, zuletzt wach ist der '
        'Eintrag', () async {
      final jetzt = berlin(di, 14, 0);
      final b = behaelter(jetzt: jetzt);
      await nachgesehen(b.c);

      await b.c.read(wachbelegProvider.notifier).merke(WachArt.buchung);
      await pumpEventQueue();

      final zeilen = await db.select(db.wachBelege).get();
      expect(zeilen, hasLength(1));
      expect(zeilen.single.art, 'buchung');
      expect(
        b.c.read(laufenderTagProvider).zuletztWach,
        Wachbeleg(von: jetzt, quelle: WachQuelle.eintrag),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Tageswacht schreibt Belege (V13)', () {
    Future<void> sendeLebenszyklus(
      WidgetTester tester,
      AppLifecycleState zustand,
    ) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(zustand.toString()),
      (_) {},
    );

    testWidgets('Aufbau schreibt einen Beleg „oeffnen“, ein resumed einen '
        'weiteren, inactive allein keinen', (tester) async {
      var uhr = berlin(di, 14, 0);
      final belege = _Belege();
      // Ohne `addTearDown`: Der Behälter wird unten im Testkörper
      // abgeräumt, sonst stünde der Zeitgeber noch aus, wenn
      // `testWidgets` nach offenen Timern fragt.
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => uhr),
          healthProvider.overrideWithValue(_Attrappe()),
          sleepProvider.overrideWith(
            () => _Naechte(() async => bekannt(const [])),
          ),
          wachbelegRepositoryProvider.overrideWithValue(belege),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const Tageswacht(child: SizedBox.shrink()),
        ),
      );
      await tester.pump();

      expect(belege.gemerkt, [(art: WachArt.oeffnen, zeitpunkt: uhr)]);

      await sendeLebenszyklus(tester, AppLifecycleState.inactive);
      await tester.pump();
      expect(
        belege.gemerkt,
        hasLength(1),
        reason:
            'inactive ist keine '
            'Rückkehr',
      );

      await sendeLebenszyklus(tester, AppLifecycleState.paused);
      uhr = berlin(di, 14, 30);
      await sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(belege.gemerkt, [
        (art: WachArt.oeffnen, zeitpunkt: berlin(di, 14, 0)),
        (art: WachArt.oeffnen, zeitpunkt: berlin(di, 14, 30)),
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Live-Aktivität: staleDate ist endetSpaetestens (Entscheidung 9)', () {
    List<Override> live() => [
      stammdatenProvider.overrideWith(
        () => HuelleStammdaten(const Stammdaten()),
      ),
      dailyMetricsProvider.overrideWith(
        () => HuelleTageswerte(
          LeerNachLauf<List<DailyMetrics>>(gelaufen: berlin(mo, 12, 0)),
        ),
      ),
      fremdeMahlzeitenProvider.overrideWith2(
        (tag) => HuelleFremde(
          LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: berlin(mo, 12, 0)),
        ),
      ),
    ];

    /// Wartet, bis Einträge des Esstags und Serie gelesen sind, und gibt
    /// die Karte zurück.
    Future<EssenKarte> karte(ProviderContainer c) async {
      c.listen(liveSollProvider, (_, _) {});
      await pumpEventQueue();
      final tag = c.read(esstagProvider);
      await c.read(eigeneEintraegeProvider(tag).future);
      await c.read(serieProvider.future);
      await pumpEventQueue();
      final soll = c.read(liveSollProvider);
      expect(soll, isA<EssenLive>());
      return (soll! as EssenLive).karte;
    }

    Future<void> buche(ProviderContainer c, String tag, DateTime zeitpunkt) => c
        .read(ernaehrungRepositoryProvider)
        .buche(
          Eintrag(
            tagesSchluessel: tag,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: zeitpunkt,
            name: 'Prüfgericht',
            naehrwerte: const Naehrwerte(kcal: 400),
          ),
        );

    void verfaelltUm(EssenKarte karte, DateTime erwartet) => expect(
      karte.verfaelltUm.isAtSameMomentAs(erwartet),
      isTrue,
      reason: 'verfaelltUm war ${karte.verfaelltUm}, erwartet $erwartet',
    );

    test('verlängert (Kette bis 05:00): verfaelltUm ist 06:00', () async {
      await eigenerBeleg(WachArt.oeffnen, berlin(di, 3, 10));
      await eigenerBeleg(WachArt.buchung, berlin(di, 4, 5));
      final b = behaelter(
        jetzt: berlin(di, 5, 10),
        health: _Attrappe(
          schritte: [QuantitySample(date: berlin(di, 5, 0), value: 400)],
        ),
        zusaetzlich: live(),
      );
      await buche(b.c, mo, berlin(di, 4, 5));
      await nachgesehen(b.c);

      final k = await karte(b.c);
      verfaelltUm(k, berlin(di, 6, 0));
      expect(
        k.ringe.singleWhere((r) => r.mahlzeit == Mahlzeit.abend).eintrag,
        isTrue,
        reason: 'die Karte zeigt den laufenden Tag Montag',
      );
    });

    test('um Di 01:30: verfaelltUm ist Di 04:00', () async {
      final b = behaelter(jetzt: berlin(di, 1, 30), zusaetzlich: live());
      await nachgesehen(b.c);

      verfaelltUm(await karte(b.c), berlin(di, 4, 0));
    });

    test('um Di 03:45 nach einer früh beendeten Nacht: verfaelltUm ist '
        'Mi 04:00', () async {
      final b = behaelter(
        jetzt: berlin(di, 3, 45),
        naechte: () async => bekannt([fruehBeendeteNacht()]),
        zusaetzlich: live(),
      );
      await b.c.read(sleepProvider.future);
      await nachgesehen(b.c);

      verfaelltUm(await karte(b.c), berlin(mi, 4, 0));
    });

    test('ein Öffnen im verlängerten Tag schiebt verfaelltUm nach', () async {
      await eigenerBeleg(WachArt.buchung, berlin(di, 3, 40));
      final b = behaelter(jetzt: berlin(di, 4, 30), zusaetzlich: live());
      await nachgesehen(b.c);
      verfaelltUm(await karte(b.c), berlin(di, 4, 40));

      await b.c.read(wachbelegProvider.notifier).merke(WachArt.oeffnen);
      await pumpEventQueue();

      verfaelltUm(await karte(b.c), berlin(di, 5, 30));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Der Zeitgeber (V9)', () {
    /// Ein Behälter unter `fakeAsync`: Die Uhr läuft mit der falschen Zeit.
    ProviderContainer unterFakeAsync(
      FakeAsync async, {
      required DateTime start,
      required _Belege belege,
      _Attrappe? health,
    }) => ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => start.add(async.elapsed)),
        healthProvider.overrideWithValue(health ?? _Attrappe()),
        sleepProvider.overrideWith(
          () => _Naechte(() async => bekannt(const [])),
        ),
        wachbelegRepositoryProvider.overrideWithValue(belege),
      ],
    );

    test('ruft pruefe() genau zu endetSpaetestens — und stellt sich neu', () {
      fakeAsync((async) {
        final start = berlin(di, 1, 30);
        final c = unterFakeAsync(async, start: start, belege: _Belege());
        c.listen(laufenderTagProvider, (_, _) {});
        async.flushMicrotasks();

        expect(c.read(laufenderTagProvider).tag, mo);
        expect(c.read(laufenderTagProvider).endetSpaetestens, berlin(di, 4, 0));

        final bisVier = berlin(di, 4, 0).difference(start);
        async.elapse(bisVier - const Duration(seconds: 1));
        expect(c.read(laufenderTagProvider).tag, mo, reason: 'noch 03:59:59');

        async.elapse(const Duration(seconds: 1));
        expect(
          c.read(laufenderTagProvider),
          Tagesstand(
            tag: di,
            grund: Tagesgrund.normal,
            endetSpaetestens: berlin(mi, 4, 0),
          ),
          reason: 'Um 04:00 steht ohne Zutun der neue Tag',
        );

        // Neu gestellt: Mi 04:00 kommt ebenfalls von selbst.
        async.elapse(berlin(mi, 4, 0).difference(berlin(di, 4, 0)));
        expect(c.read(laufenderTagProvider).tag, mi);

        c.dispose();
      });
    });

    test('verlängert bis 06:00: um 06:00 wechselt der Tag von selbst', () {
      fakeAsync((async) {
        final start = berlin(di, 5, 10);
        final belege = _Belege()
          ..gemerkt.addAll([
            (art: WachArt.oeffnen, zeitpunkt: berlin(di, 3, 10)),
            (art: WachArt.buchung, zeitpunkt: berlin(di, 4, 5)),
          ]);
        final c = unterFakeAsync(
          async,
          start: start,
          belege: belege,
          health: _Attrappe(
            schritte: [QuantitySample(date: berlin(di, 5, 0), value: 400)],
          ),
        );
        c.listen(laufenderTagProvider, (_, _) {});
        async.flushMicrotasks();
        c.read(laufenderTagProvider.notifier).pruefe();
        async.flushMicrotasks();

        expect(c.read(laufenderTagProvider).grund, Tagesgrund.verlaengert);
        expect(c.read(laufenderTagProvider).endetSpaetestens, berlin(di, 6, 0));

        async.elapse(const Duration(minutes: 50) - const Duration(seconds: 1));
        expect(c.read(laufenderTagProvider).tag, mo, reason: 'noch 05:59:59');

        async.elapse(const Duration(seconds: 1));
        expect(c.read(laufenderTagProvider).tag, di);
        expect(c.read(laufenderTagProvider).grund, Tagesgrund.normal);

        c.dispose();
      });
    });

    test('nach dispose steht kein Zeitgeber mehr aus', () {
      fakeAsync((async) {
        final c = unterFakeAsync(
          async,
          start: berlin(di, 1, 30),
          belege: _Belege(),
        );
        c.listen(laufenderTagProvider, (_, _) {});
        async.flushMicrotasks();
        expect(
          async.pendingTimers,
          isNotEmpty,
          reason: 'Der Zeitgeber auf 04:00 ist gestellt',
        );

        c.dispose();
        async.flushMicrotasks();

        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}

// ───────────────────────────────────────────────────────────────────────
// Attrappen
// ───────────────────────────────────────────────────────────────────────

/// Eine Health-Attrappe, die ihre Aufrufe zählt und — wie Health — nur
/// liefert, was im gefragten Fenster liegt. Mit [wirft] scheitern Schritte
/// und Trainings.
class _Attrappe extends HealthReadingAttrappe {
  _Attrappe({this.schritte = const [], this.wirft = false});

  final List<QuantitySample> schritte;
  final bool wirft;

  final schrittAufrufe = <({DateTime von, DateTime bis})>[];
  final trainingAufrufe = <({DateTime von, DateTime bis})>[];
  var schlafAufrufe = 0;

  @override
  Future<List<QuantitySample>> hourlySteps(
    DateTime from,
    DateTime through,
  ) async {
    schrittAufrufe.add((von: from, bis: through));
    if (wirft) throw StateError('Health antwortet nicht');
    return schritte
        .where((s) => !s.date.isBefore(from) && !s.date.isAfter(through))
        .toList();
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    trainingAufrufe.add((von: from, bis: through));
    if (wirft) throw StateError('Health antwortet nicht');
    return const [];
  }

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafAufrufe++;
    return const [];
  }
}

/// `sleepProvider` mit steuerbarem Stand: [build] liefert, was [_anfang]
/// liefert; [melde] setzt einen neuen Stand, wie es ein Nachlauf täte.
class _Naechte extends SleepNotifier {
  _Naechte(this._anfang);

  final Future<Messwert<List<SleepNight>>> Function() _anfang;

  @override
  Future<Messwert<List<SleepNight>>> build() => _anfang();

  void melde(Messwert<List<SleepNight>> neu) => state = AsyncData(neu);
}

/// Das Repository der eigenen Belege ohne Datenbank. [gemerkt] ist die
/// Tabelle; mit [halten] antwortet [zwischen] erst, wenn es erfüllt ist.
class _Belege implements WachbelegRepository {
  _Belege({this.halten});

  final Completer<void>? halten;
  final gemerkt = <({WachArt art, DateTime zeitpunkt})>[];

  @override
  Future<void> merke(WachArt art, DateTime zeitpunkt) async =>
      gemerkt.add((art: art, zeitpunkt: zeitpunkt.toUtc()));

  @override
  Future<List<Wachbeleg>> zwischen(DateTime von, DateTime bis) async {
    if (halten != null) await halten!.future;
    final treffer =
        gemerkt
            .where(
              (b) => !b.zeitpunkt.isBefore(von) && !b.zeitpunkt.isAfter(bis),
            )
            .toList()
          ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    return [
      for (final b in treffer)
        Wachbeleg(von: b.zeitpunkt, quelle: b.art.quelle),
    ];
  }
}
