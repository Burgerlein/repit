import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/tag/tagesbelege_provider.dart';

import '../health/health_reading_attrappe.dart';
import 'berliner_wanduhr.dart';

/// Tests für **Belege und Ende je Tag** (#454 unter #375, Tagesgrenze) —
/// `tagesbelegeProvider` und `tagesendeProvider` in
/// `lib/tag/tagesbelege_provider.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`,
/// Abschnitt „Belege und Ende je Tag“, dazu (vom Planenden formuliert,
/// laut Spec von Tim am 10.11.2026 übernommen):
///
/// - **V12:** Belege für einen Tag D liest die App einmal je Tag, für das
///   Fenster D 04:00 bis D+1 08:00: eigene Belege aus der Tabelle, Schritte
///   und Trainings aus Health. Kein `Messwert<T>`; scheitert Health, zählen
///   die eigenen Belege allein.
/// - **V13:** eigene Belege `oeffnen` und `buchung`.
/// - V1, V2, V4: die Abbildung aus Health (geprüft in
///   `tagesgrenze_eingaben_test.dart`, hier nur im Zusammenspiel).
/// - Spec: `tagesbelegeProvider` ist
///   `AsyncNotifierProvider.autoDispose.family<…, List<Wachbeleg>, String>`,
///   `tagesendeProvider` ist `Provider.autoDispose.family<Tagesende?,
///   String>` über `tagesende(tag, belege, nacht)` mit der Nacht, deren
///   Aufwachtag D+1 ist (aus `sleepProvider`) — `null`, solange Belege oder
///   Nächte noch nicht gelesen sind, und für den laufenden Tag.
///
/// Pflichtfälle aus dem Plan `docs/superpowers/plans/2026-11-10-tagesgrenze.md`,
/// Task 4: Fenster D 04:00 bis D+1 08:00, höchstens bis `jetzt`; die
/// Attrappe wird **genau einmal** je Art gefragt; wirft sie, kommen die
/// eigenen Belege allein, ohne Fehlerzustand. `tagesendeProvider`: `null`
/// vor dem Lesen, danach `tagesende` mit der Nacht des Aufwachtags D+1,
/// `null` für den laufenden Tag.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Health wird genau mit dem Fenster gefragt:** `hourlySteps` und
///   `workouts` je mit `von` = D 04:00 und `bis` = dem früheren von
///   D+1 08:00 und `jetzt` (verglichen als Zeitpunkt, nicht nach
///   `isUtc`). Die Attrappe liefert — wie Health — nur, was im gefragten
///   Fenster liegt.
/// - **Die Reihenfolge der Belege ist frei**; verglichen wird ohne
///   Reihenfolge. Die Kern-Rechnungen sortieren selbst.
/// - **Solange die Familie beobachtet wird, fragt ein zweites Lesen nicht
///   neu**; nach dem Abräumen (`autoDispose`) fragt das nächste Lesen neu
///   — so liest „jedes Öffnen des Blatts neu“ (Spec).
/// - **Den Schlaf liest `tagesendeProvider` aus `sleepProvider`**, nie
///   über `HealthReading.sleepSessions`.
/// - **`LeerNachLauf` bei den Nächten zählt als gelesen**: Der Lauf ist
///   fertig, es gibt keine Nacht → `tagesende` ohne Nacht. Ebenso eine
///   Nacht mit Aufwachtag D+1, die nur aus `awake` besteht (`nachtAus` →
///   `null`).
/// - **„Der laufende Tag“** wird nur an zwei Fällen geprüft, in denen jede
///   vernünftige Lesart übereinstimmt: D um D 14:00 und D um D+1 01:30 ohne
///   Nacht (Montag läuft noch). Wie der Provider den laufenden Tag bestimmt,
///   legt diese Datei nicht fest — `laufenderTagProvider` kommt erst mit
///   Task 5.
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“), Uhrzeiten als Berliner Wanduhr über [berlin].
void main() {
  const d = '2099-01-12';
  const d1 = '2099-01-13';
  const d2 = '2099-01-14';

  late AppCache db;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> eigenerBeleg(String art, DateTime zeitpunkt) => db
      .into(db.wachBelege)
      .insert(WachBelegeCompanion.insert(zeitpunkt: zeitpunkt, art: art));

  ProviderContainer container({
    required DateTime jetzt,
    required _Attrappe health,
    SleepNotifier Function()? naechte,
  }) {
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(health),
        if (naechte != null) sleepProvider.overrideWith(naechte),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('tagesbelegeProvider', () {
    test('vereint eigene Belege, Schritte und Trainings im Fenster '
        'D 04:00 bis D+1 08:00', () async {
      await eigenerBeleg('oeffnen', berlin(d, 3, 50)); // davor
      await eigenerBeleg('oeffnen', berlin(d, 4, 10));
      await eigenerBeleg('buchung', berlin(d, 22, 0));
      await eigenerBeleg('oeffnen', berlin(d1, 7, 50));
      await eigenerBeleg('buchung', berlin(d1, 8, 10)); // danach
      await eigenerBeleg('puls', berlin(d, 23, 0)); // unbekannte Art

      final health = _Attrappe(
        schritte: [
          QuantitySample(date: berlin(d, 3, 0), value: 500), // davor
          QuantitySample(date: berlin(d, 23, 0), value: 99), // zu wenig
          QuantitySample(date: berlin(d1, 1, 0), value: 340),
          QuantitySample(date: berlin(d1, 9, 0), value: 900), // danach
        ],
        trainings: [
          _training('lauf', berlin(d, 18, 0), 45),
          _training('spaet', berlin(d1, 9, 30), 30), // danach
        ],
      );
      final c = container(jetzt: berlin(d2, 12, 0), health: health);
      c.listen(tagesbelegeProvider(d), (_, _) {});

      final belege = await c.read(tagesbelegeProvider(d).future);

      expect(
        belege,
        unorderedEquals([
          Wachbeleg(von: berlin(d, 4, 10), quelle: WachQuelle.app),
          Wachbeleg(von: berlin(d, 22, 0), quelle: WachQuelle.eintrag),
          Wachbeleg(von: berlin(d1, 7, 50), quelle: WachQuelle.app),
          Wachbeleg(von: berlin(d1, 1, 0), quelle: WachQuelle.schritte),
          Wachbeleg(
            von: berlin(d, 18, 0),
            bis: berlin(d, 18, 45),
            quelle: WachQuelle.training,
          ),
        ]),
      );
    });

    test('fragt Health genau einmal je Art, mit dem Fenster', () async {
      final health = _Attrappe();
      final c = container(jetzt: berlin(d2, 12, 0), health: health);
      c.listen(tagesbelegeProvider(d), (_, _) {});

      await c.read(tagesbelegeProvider(d).future);

      expect(health.schrittAufrufe, hasLength(1));
      expect(health.trainingAufrufe, hasLength(1));
      for (final aufruf in [
        health.schrittAufrufe.single,
        health.trainingAufrufe.single,
      ]) {
        expect(aufruf.von.isAtSameMomentAs(berlin(d, 4, 0)), isTrue,
            reason: 'von ist D 04:00, nicht ${aufruf.von}');
        expect(aufruf.bis.isAtSameMomentAs(berlin(d1, 8, 0)), isTrue,
            reason: 'bis ist D+1 08:00, nicht ${aufruf.bis}');
      }
      expect(health.schlafAufrufe, 0);
    });

    test('über die Zeitumstellung: das Fenster folgt der Wanduhr '
        '(24.10. 04:00 Sommerzeit bis 25.10. 08:00 Winterzeit)', () async {
      final health = _Attrappe();
      final c = container(jetzt: berlin('2099-10-27', 12, 0), health: health);
      c.listen(tagesbelegeProvider('2099-10-24'), (_, _) {});

      await c.read(tagesbelegeProvider('2099-10-24').future);

      final aufruf = health.schrittAufrufe.single;
      expect(aufruf.von.isAtSameMomentAs(DateTime.utc(2099, 10, 24, 2)), isTrue,
          reason: 'von war ${aufruf.von}');
      expect(aufruf.bis.isAtSameMomentAs(DateTime.utc(2099, 10, 25, 7)), isTrue,
          reason: 'bis war ${aufruf.bis}');
    });

    test('höchstens bis jetzt', () async {
      final jetzt = berlin(d1, 6, 0);
      await eigenerBeleg('oeffnen', berlin(d1, 5, 30));
      await eigenerBeleg('buchung', berlin(d1, 6, 30)); // nach jetzt

      final health = _Attrappe(
        schritte: [
          QuantitySample(date: berlin(d1, 5, 0), value: 400),
          QuantitySample(date: berlin(d1, 7, 0), value: 400), // nach jetzt
        ],
      );
      final c = container(jetzt: jetzt, health: health);
      c.listen(tagesbelegeProvider(d), (_, _) {});

      final belege = await c.read(tagesbelegeProvider(d).future);

      expect(
        belege,
        unorderedEquals([
          Wachbeleg(von: berlin(d1, 5, 30), quelle: WachQuelle.app),
          Wachbeleg(von: berlin(d1, 5, 0), quelle: WachQuelle.schritte),
        ]),
      );
      expect(health.schrittAufrufe.single.bis.isAtSameMomentAs(jetzt), isTrue,
          reason: 'bis war ${health.schrittAufrufe.single.bis}');
      expect(health.trainingAufrufe.single.bis.isAtSameMomentAs(jetzt), isTrue,
          reason: 'bis war ${health.trainingAufrufe.single.bis}');
    });

    test('wirft Health, kommen die eigenen Belege allein — ohne Fehler',
        () async {
      await eigenerBeleg('buchung', berlin(d, 21, 0));
      await eigenerBeleg('oeffnen', berlin(d1, 0, 40));

      final health = _Attrappe(wirft: true);
      final c = container(jetzt: berlin(d2, 12, 0), health: health);
      c.listen(tagesbelegeProvider(d), (_, _) {});

      final belege = await c.read(tagesbelegeProvider(d).future);

      expect(
        belege,
        unorderedEquals([
          Wachbeleg(von: berlin(d, 21, 0), quelle: WachQuelle.eintrag),
          Wachbeleg(von: berlin(d1, 0, 40), quelle: WachQuelle.app),
        ]),
      );
      expect(c.read(tagesbelegeProvider(d)).hasError, isFalse);
    });

    test('ohne eigene Belege und ohne Health: leere Liste, kein Fehler',
        () async {
      final c = container(jetzt: berlin(d2, 12, 0), health: _Attrappe());
      c.listen(tagesbelegeProvider(d), (_, _) {});

      expect(await c.read(tagesbelegeProvider(d).future), isEmpty);
      expect(c.read(tagesbelegeProvider(d)).hasError, isFalse);
    });

    test('ein zweites Lesen fragt nicht neu, solange beobachtet wird',
        () async {
      final health = _Attrappe();
      final c = container(jetzt: berlin(d2, 12, 0), health: health);
      c.listen(tagesbelegeProvider(d), (_, _) {});

      await c.read(tagesbelegeProvider(d).future);
      await c.read(tagesbelegeProvider(d).future);

      expect(health.schrittAufrufe, hasLength(1));
      expect(health.trainingAufrufe, hasLength(1));
    });

    test('nach dem Abräumen liest das nächste Öffnen neu (autoDispose)',
        () async {
      final health = _Attrappe();
      final c = container(jetzt: berlin(d2, 12, 0), health: health);

      final erstes = c.listen(tagesbelegeProvider(d), (_, _) {});
      await c.read(tagesbelegeProvider(d).future);
      erstes.close();
      await Future<void>.delayed(Duration.zero);

      c.listen(tagesbelegeProvider(d), (_, _) {});
      await c.read(tagesbelegeProvider(d).future);

      expect(health.schrittAufrufe, hasLength(2));
      expect(health.trainingAufrufe, hasLength(2));
    });

    test('jeder Tag hat sein eigenes Fenster', () async {
      await eigenerBeleg('oeffnen', berlin(d, 12, 0));
      await eigenerBeleg('oeffnen', berlin(d1, 12, 0));

      final c = container(jetzt: berlin(d2, 12, 0), health: _Attrappe());
      c.listen(tagesbelegeProvider(d), (_, _) {});
      c.listen(tagesbelegeProvider(d1), (_, _) {});

      expect(await c.read(tagesbelegeProvider(d).future), [
        Wachbeleg(von: berlin(d, 12, 0), quelle: WachQuelle.app),
      ]);
      expect(await c.read(tagesbelegeProvider(d1).future), [
        Wachbeleg(von: berlin(d1, 12, 0), quelle: WachQuelle.app),
      ]);
    });
  });

  group('tagesendeProvider', () {
    /// Eine Hauptnacht mit Aufwachtag [aufwachtag] aus einem Abschnitt.
    SleepNight nacht(
      String aufwachtag,
      DateTime beginn,
      DateTime ende, {
      SleepStage stage = SleepStage.core,
    }) => SleepNight(
      date: datumAusTag(aufwachtag),
      session: SleepSession(
        segments: [SleepSegment(stage: stage, start: beginn, end: ende)],
      ),
    );

    SleepNotifier Function() naechte(List<SleepNight> liste) =>
        () => _Naechte(
          Bekannt<List<SleepNight>>(
            liste,
            stand: berlin(d2, 12, 0),
            laeuft: false,
          ),
        );

    /// Wartet, bis Belege und Nächte gelesen sind.
    Future<void> gelesen(ProviderContainer c, String tag) async {
      await c.read(tagesbelegeProvider(tag).future);
      await c.read(sleepProvider.future);
      await Future<void>.delayed(Duration.zero);
    }

    test('nach dem Lesen: tagesende mit der Nacht, deren Aufwachtag D+1 ist',
        () async {
      await eigenerBeleg('buchung', berlin(d, 23, 10));
      final health = _Attrappe(
        schritte: [QuantitySample(date: berlin(d1, 0, 0), value: 300)],
      );
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: health,
        naechte: naechte([
          nacht(d, berlin('2099-01-11', 23, 30), berlin(d, 6, 45)),
          nacht(d1, berlin(d1, 0, 47), berlin(d1, 7, 10)),
          nacht(d2, berlin(d1, 22, 50), berlin(d2, 6, 30)),
        ]),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(
        c.read(tagesendeProvider(d)),
        Tagesende(
          tag: d,
          endete: berlin(d1, 0, 47),
          grund: Endegrund.eingeschlafen,
          eingeschlafen: berlin(d1, 0, 47),
          zuletztWach: Wachbeleg(
            von: berlin(d1, 0, 0),
            quelle: WachQuelle.schritte,
          ),
        ),
      );
      expect(health.schlafAufrufe, 0,
          reason: 'Den Schlaf liest der Provider aus sleepProvider');
    });

    test('rechnet wie tagesende im Kern, mit Wachkette über 04:00', () async {
      await eigenerBeleg('oeffnen', berlin(d1, 3, 10));
      await eigenerBeleg('buchung', berlin(d1, 4, 5));
      final health = _Attrappe(
        schritte: [QuantitySample(date: berlin(d1, 5, 0), value: 1200)],
      );
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: health,
        naechte: naechte(const []),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      final erwartet = tagesende(
        tag: d,
        belege: [
          Wachbeleg(von: berlin(d1, 3, 10), quelle: WachQuelle.app),
          Wachbeleg(von: berlin(d1, 4, 5), quelle: WachQuelle.eintrag),
          Wachbeleg(von: berlin(d1, 5, 0), quelle: WachQuelle.schritte),
        ],
      );
      expect(erwartet.grund, Endegrund.wachkette); // Selbstprüfung
      expect(erwartet.endete, berlin(d1, 6, 0)); // Selbstprüfung
      expect(c.read(tagesendeProvider(d)), erwartet);
    });

    test('ohne Nacht für D+1: feste Grenze D+1 04:00', () async {
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: _Attrappe(),
        naechte: naechte([
          nacht(d, berlin('2099-01-11', 23, 30), berlin(d, 6, 45)),
          nacht(d2, berlin(d1, 22, 50), berlin(d2, 6, 30)),
        ]),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(
        c.read(tagesendeProvider(d)),
        Tagesende(
          tag: d,
          endete: berlin(d1, 4, 0),
          grund: Endegrund.festeGrenze,
        ),
      );
    });

    test('Nächte LeerNachLauf: gelesen, keine Nacht → feste Grenze', () async {
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: _Attrappe(),
        naechte: () => _Naechte(
          LeerNachLauf<List<SleepNight>>(gelaufen: berlin(d2, 12, 0)),
        ),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(
        c.read(tagesendeProvider(d)),
        Tagesende(
          tag: d,
          endete: berlin(d1, 4, 0),
          grund: Endegrund.festeGrenze,
        ),
      );
    });

    test('eine Nacht für D+1 nur aus awake zählt nicht als Nacht', () async {
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: _Attrappe(),
        naechte: naechte([
          nacht(
            d1,
            berlin(d1, 1, 0),
            berlin(d1, 2, 0),
            stage: SleepStage.awake,
          ),
        ]),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(
        c.read(tagesendeProvider(d)),
        Tagesende(
          tag: d,
          endete: berlin(d1, 4, 0),
          grund: Endegrund.festeGrenze,
        ),
      );
    });

    test('null, solange die Belege nicht gelesen sind', () async {
      final health = _Attrappe(halten: Completer<void>());
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: health,
        naechte: naechte([nacht(d1, berlin(d1, 0, 47), berlin(d1, 7, 10))]),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await c.read(sleepProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(tagesendeProvider(d)), isNull);

      health.halten!.complete();
      await gelesen(c, d);
      expect(c.read(tagesendeProvider(d))?.endete, berlin(d1, 0, 47));
    });

    test('null, solange die Nächte nicht gelesen sind', () async {
      final schlaf = Completer<Messwert<List<SleepNight>>>();
      final c = container(
        jetzt: berlin(d2, 12, 0),
        health: _Attrappe(),
        naechte: () => _NaechteSpaeter(schlaf.future),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await c.read(tagesbelegeProvider(d).future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(tagesendeProvider(d)), isNull);

      schlaf.complete(
        Bekannt<List<SleepNight>>(
          [nacht(d1, berlin(d1, 0, 47), berlin(d1, 7, 10))],
          stand: berlin(d2, 12, 0),
          laeuft: false,
        ),
      );
      await gelesen(c, d);
      expect(c.read(tagesendeProvider(d))?.endete, berlin(d1, 0, 47));
    });

    test('null für den laufenden Tag, tagsüber', () async {
      await eigenerBeleg('buchung', berlin(d, 12, 30));
      final c = container(
        jetzt: berlin(d, 14, 0),
        health: _Attrappe(),
        naechte: naechte(const []),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(c.read(tagesendeProvider(d)), isNull);
    });

    test('null für den laufenden Tag nach Mitternacht (Montag läuft noch)',
        () async {
      await eigenerBeleg('buchung', berlin(d1, 1, 24));
      final c = container(
        jetzt: berlin(d1, 1, 30),
        health: _Attrappe(),
        naechte: naechte([
          nacht(d, berlin('2099-01-11', 23, 30), berlin(d, 6, 45)),
        ]),
      );
      c.listen(tagesendeProvider(d), (_, _) {});

      await gelesen(c, d);

      expect(c.read(tagesendeProvider(d)), isNull);
    });
  });
}

WorkoutSample _training(String id, DateTime start, double minuten) =>
    WorkoutSample(
      id: id,
      start: start,
      kind: WorkoutKind.walking,
      minutes: minuten,
    );

/// Eine Health-Attrappe, die ihre Aufrufe zählt und — wie Health — nur
/// liefert, was im gefragten Fenster liegt. Mit [wirft] scheitern Schritte
/// und Trainings; mit [halten] warten die Schritte, bis es erfüllt ist.
class _Attrappe extends HealthReadingAttrappe {
  _Attrappe({
    this.schritte = const [],
    this.trainings = const [],
    this.wirft = false,
    this.halten,
  });

  final List<QuantitySample> schritte;
  final List<WorkoutSample> trainings;
  final bool wirft;
  final Completer<void>? halten;

  final schrittAufrufe = <({DateTime von, DateTime bis})>[];
  final trainingAufrufe = <({DateTime von, DateTime bis})>[];
  var schlafAufrufe = 0;

  static bool _drin(DateTime t, DateTime von, DateTime bis) =>
      !t.isBefore(von) && !t.isAfter(bis);

  @override
  Future<List<QuantitySample>> hourlySteps(
    DateTime from,
    DateTime through,
  ) async {
    schrittAufrufe.add((von: from, bis: through));
    if (halten != null) await halten!.future;
    if (wirft) throw StateError('Health antwortet nicht');
    return schritte.where((s) => _drin(s.date, from, through)).toList();
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    trainingAufrufe.add((von: from, bis: through));
    if (wirft) throw StateError('Health antwortet nicht');
    return trainings.where((w) => _drin(w.start, from, through)).toList();
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

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _NaechteSpaeter extends SleepNotifier {
  _NaechteSpaeter(this.wert);

  final Future<Messwert<List<SleepNight>>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() => wert;
}
