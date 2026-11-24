import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/health/health_mock.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';

/// Tests für `MockHealthReading` (Task 12) — die Dart-Mock-Quelle, die
/// `Sources/Health/MockHealthReading.swift` + `MockSleep.swift` +
/// `MockGym.swift` (zusammen ~320 Zeilen, Spec 8.4) ersetzt.
///
/// **Entscheidung, dokumentiert wie im Task-Bericht gefordert: Die Mock-Quelle
/// liest `test/fixtures/health_export_demo.json`, statt eigene erfundene
/// Konstanten im Quelltext zu tragen.**
///
/// Gründe:
/// 1. `docs/demo_dataset.md` kündigt diesen Datensatz ausdrücklich als
///    „später die Quelle für einen Dart-`HealthReading`-Mock (Task 12)" an —
///    das ist keine freie Wahl des Test-Autors, sondern eine bereits
///    getroffene Entscheidung, die dieser Task nur noch einlöst.
/// 2. Er vermeidet eine zweite, von Hand gepflegte Literal-Tabelle in Dart,
///    die bei jeder Änderung an der Swift-Vorlage erneut von Hand
///    nachgezogen werden müsste — genau die Art Doppelpflege, vor der
///    CLAUDE.md warnt (dort für `BerlinCalendar`/`DataWindow`/`StepMerge`,
///    aus anderem Grund, aber demselben Prinzip).
/// 3. Er hat bereits absichtliche Lücken (fehlende Schritte, fehlende
///    Nachtwerte, eine 15-tägige Gewichtslücke, fehlende Nächte) eingebaut —
///    genau das Material, das die „0 statt kein Wert"-Prüfung aus `01``
///    braucht, ohne dass ich es im Test noch einmal erfinden müsste.
///
/// Laut `docs/demo_dataset.md`, Abschnitt „Wie Task 12 den Datensatz einlesen
/// sollte", Empfehlung **„fest lassen"**: Der Mock zeigt immer genau den
/// Zeitraum 10.09.2026–27.10.2026, nicht relativ zu `DateTime.now()`
/// verankert. Das vermeidet die Zielkarte-Falle (#14)
/// vollständig, weil nirgends im Mock ein Datum behauptet, es sei „heute" —
/// anders als die Swift-Vorlage, deren `referenceDate` an `.now` hängt. Jeder
/// Test unten verwendet deshalb Daten aus diesem festen Fenster, nie
/// `DateTime.now()`.
///
/// **Nachtrag 27.10.2026 — Tagschlaf im Datensatz.** `sleep[]` bekommt
/// einen optionalen `naps`-Schlüssel, damit die Tagschlaf-Kachel im
/// Simulator überhaupt erreichbar wird. Format, Begründung und die
/// Abgrenzung zur Gruppierung im Swift-Kanal stehen vollständig über
/// der Gruppe `sleepSessions — Tagschlaf` weiter unten.
///
/// **Was hier absichtlich nicht geprüft wird:**
/// - Exakte erfundene Zahlen, wo die Vorlage selbst keine Formel dahinter
///   hat (z. B. der genaue Verlauf von `hourlySteps` innerhalb eines Tages) —
///   das sind gestalterische Entscheidungen des Mocks, keine Verträge.
/// - Der Platform-Channel (`HealthChannel`) — der Mock läuft rein in Dart,
///   ohne Map-Kodierung; dafür gibt es `workout_codec_test.dart`.
void main() {
  late Map<String, dynamic> demo;
  late List<dynamic> demoDays;
  late List<dynamic> demoWorkouts;
  late List<dynamic> demoSleep;
  late List<dynamic> demoMeals;

  setUpAll(() {
    final raw = File('test/fixtures/health_export_demo.json').readAsStringSync();
    demo = jsonDecode(raw) as Map<String, dynamic>;
    demoDays = demo['days'] as List<dynamic>;
    demoWorkouts = demo['workouts'] as List<dynamic>;
    demoSleep = demo['sleep'] as List<dynamic>;
    demoMeals = demo['meals'] as List<dynamic>;
  });

  // Das feste Fenster des Demo-Datensatzes, siehe Dateikopf.
  final from = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 10));
  final through = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 27));

  test('MockHealthReading implementiert HealthReading vollstaendig', () {
    final HealthReading reading = MockHealthReading();
    expect(reading, isA<HealthReading>());
  });

  group('earliestPermittedDate', () {
    test('liegt in der Vergangenheit, grob drei Jahre zurueck', () {
      final reading = MockHealthReading();
      final now = DateTime.now();
      expect(reading.earliestPermittedDate.isBefore(now), isTrue);
      final vorDreiJahren = now.subtract(const Duration(days: 365 * 3));
      final differenzTage =
          reading.earliestPermittedDate.difference(vorDreiJahren).inDays.abs();
      expect(
        differenzTage,
        lessThan(60),
        reason: 'soll ungefaehr drei Jahre zurueckliegen, wie die Swift-Vorlage',
      );
    });
  });

  test('requestAuthorization() schliesst ab, ohne zu werfen', () async {
    await MockHealthReading().requestAuthorization();
  });

  group('dailyMetrics — Pflichtfaelle aus dem Demo-Datensatz', () {
    test('liefert einen Eintrag je Kalendertag des Fensters, 48 Tage', () async {
      final result = await MockHealthReading().dailyMetrics(from, through);
      expect(result.length, demoDays.length);
      expect(result.length, 48);
    });

    test('die Tage stehen aufsteigend, Tag-Schluessel passend zum Demo-Datensatz',
        () async {
      final result = await MockHealthReading().dailyMetrics(from, through);
      final tags = result.map((m) => m.tag).toList();
      final erwartet = demoDays.map((d) => d['date'] as String).toList();
      expect(tags, erwartet);
    });

    test('ein Tag ohne Schrittzahl im Datensatz bleibt null, wird nicht 0', () async {
      // 2026-09-13 ist laut Demo-Datensatz einer von fünf Tagen ohne
      // Schrittzahl (docs/demo_dataset.md, Tabelle „Lücken").
      final result = await MockHealthReading().dailyMetrics(from, through);
      final tag = result.firstWhere((m) => m.tag == '2026-09-13');
      expect(tag.steps, isNull, reason: '0 statt kein Wert ist genau der Fehler 01');
    });

    test('ein Tag ganz ohne Nachtwerte hat restingHR/hrvMs/respRate alle null',
        () async {
      // 2026-09-16 ist einer von sechs Tagen ganz ohne Nachtwerte.
      final result = await MockHealthReading().dailyMetrics(from, through);
      final tag = result.firstWhere((m) => m.tag == '2026-09-16');
      expect(tag.restingHR, isNull);
      expect(tag.hrvMs, isNull);
      expect(tag.respRate, isNull);
    });

    // Die Lücke liegt ZWISCHEN zwei Messungen: 22.09. und 07.10. tragen Werte,
    // die 14 Tage dazwischen nicht. Eine frühere Fassung dieses Tests las die
    // Doku als „22.09. bis 07.10. einschliesslich" und erwartete 16 leere Tage —
    // die Doku liess offen, ob die Grenzen dazugehoeren. Sie tun es nicht.
    test('zwischen zwei Waage-Messungen liegen 14 Tage ohne Wert', () async {
      final result = await MockHealthReading().dailyMetrics(from, through);
      final luecke = result.where((m) =>
          m.tag.compareTo('2026-09-23') >= 0 && m.tag.compareTo('2026-10-06') <= 0);
      expect(luecke.length, 14, reason: '23.09. bis 06.10. einschliesslich');
      for (final tag in luecke) {
        expect(tag.weightKg, isNull, reason: '${tag.tag} liegt in der Luecke');
      }
    });

    test('die Raender der Luecke tragen Werte, sonst waere es keine Luecke',
        () async {
      final result = await MockHealthReading().dailyMetrics(from, through);
      for (final tag in ['2026-09-22', '2026-10-07']) {
        final eintrag = result.firstWhere((m) => m.tag == tag);
        expect(eintrag.weightKg, isNotNull, reason: '$tag ist ein Messtag');
      }
    });

    test('ein bekannter Messwert kommt unveraendert aus dem Datensatz an (10.09.)',
        () async {
      final result = await MockHealthReading().dailyMetrics(from, through);
      final erster = result.first;
      final datensatz = demoDays.first as Map<String, dynamic>;
      expect(erster.tag, datensatz['date']);
      expect(erster.steps, datensatz['steps']);
      expect(erster.vo2max, isNull, reason: 'laut Datensatz kein VO2max an diesem Tag');
    });

    test('ausserhalb des Datensatz-Fensters liefert dailyMetrics keine Tage',
        () async {
      final vorher = BerlinCalendar.startOfDay(DateTime.utc(2026, 1, 1));
      final result = await MockHealthReading().dailyMetrics(vorher, vorher);
      expect(result, isEmpty,
          reason: 'der Mock darf ausserhalb des Demo-Fensters nichts erfinden');
    });
  });

  group('sleepSessions', () {
    test('liefert 43 Naechte fuer das volle Fenster, nicht 48', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      expect(result.length, demoSleep.length);
      expect(result.length, 43, reason: '5 Naechte fehlen ganz laut Demo-Datensatz');
    });

    test('eine der fuenf fehlenden Naechte (15.09.) taucht nicht auf', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final tage = result.map((n) => BerlinCalendar.dayKey(n.date)).toSet();
      expect(tage.contains('2026-09-15'), isFalse);
    });

    test('eine vorhandene Nacht hat Abschnitte mit Schlafphasen', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final nacht = result.firstWhere(
          (n) => BerlinCalendar.dayKey(n.date) == '2026-09-10');
      expect(nacht.session.segments, isNotEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Tagschlaf im Demo-Datensatz
  // ─────────────────────────────────────────────────────────────────────
  //
  // **Demo-Infrastruktur für den Simulator, nicht die Logik der App.**
  // Auf dem Gerät gruppiert der Swift-Kanal rohe Abschnitte in Nacht und
  // Nickerchen und liefert `SleepNight` fertig aus
  // (`health_types.dart:126–129`); `SleepGrouping` wird ausdrücklich
  // **nicht** nach Dart portiert (Spec
  // `docs/superpowers/specs/2026-10-26-erholung-flutter-design.md`,
  // Abschnitt 1). Der Mock **bildet nach, was der Kanal liefert** — er
  // erfindet keine zweite Gruppierungsregel in Dart. Deshalb steht die
  // Trennung schon im Datensatz, und der Mock liest sie nur ab.
  //
  // ## Das festgelegte Format
  //
  // Eine Nacht in `sleep[]` bekommt einen **optionalen** Schlüssel `naps`
  // neben dem vorhandenen `segments`:
  //
  // ```json
  // { "night": "2026-10-27",
  //   "segments": [ {"start": …, "end": …, "stage": …}, … ],
  //   "naps": [ { "segments": [ {"start": …, "end": …, "stage": …} ] } ],
  //   "hrBins": [...], "rrBins": [...] }
  // ```
  //
  // Begründung für genau diese Form:
  //
  // 1. **Sie spiegelt die Kanal-Nutzlast.** `SleepNight.ausMap` liest
  //    `naps` als Liste von Objekten mit je einem `segments`-Feld. Ein
  //    Nickerchen ist eine `SleepSession`, kein loser Abschnitt — eine
  //    flache Liste von Abschnitten verlöre die Information, welche
  //    Abschnitte zu *einem* Nickerchen gehören, und der Mock müsste sie
  //    wieder zusammenrechnen. Genau das wäre die zweite
  //    Gruppierungsregel, die es nicht geben soll.
  // 2. **Dieselben Zeitstempel wie `segments`:** naive Berliner Ortszeit
  //    ohne Zonenangabe, wie der ganze Datensatz (`timezone:
  //    "Europe/Berlin"`). Der Mock rechnet sie mit derselben Funktion um.
  // 3. **Optional, und sein Fehlen ist der Normalfall.** `naps` ist eine
  //    *additive* Erweiterung der `trainingsexport`-Hülle (dieselbe Art
  //    Erweiterung, die `docs/SPEC.md` 4.11 für `gym[]` vorsieht: „additiv,
  //    `version` bleibt 1"). Ein echter Export hat den Schlüssel heute
  //    **nicht**, und 41 der 43 Nächte in diesem Datensatz haben ihn auch
  //    nicht. Fehlt er, ist `naps` leer — der Mock darf dafür weder werfen
  //    noch etwas erfinden.
  //
  // ## Die beiden Nächte mit Nickerchen
  //
  // Alle Zeiten **erfunden** (CLAUDE.md), wie der ganze Datensatz:
  //
  // | Nacht | Nickerchen |
  // |---|---|
  // | `2026-10-24` | zwei: 12:05–12:35 und 16:20–16:45 (zwei Abschnitte) |
  // | `2026-10-27` | eines: 13:40–14:12 |
  //
  // Zwei Nächte, und zwar diese beiden, aus drei Gründen:
  //
  // - **Der 27.10. ist die letzte Nacht des Datensatzes.** Sie ist die,
  //   die der Erholung-Schirm als „heute" zeigt — ohne sie bliebe die
  //   Tagschlaf-Kachel im Simulator weiter unerreichbar, und genau das
  //   war der Befund.
  // - **Der 24.10. liegt vor der Zeitumstellung, der 27.10. danach**
  //   (letzter Sonntag im Oktober 2026 ist der 25.). Die beiden Fälle
  //   prüfen damit beide Seiten der Umrechnung, ohne dafür eigene
  //   Testdaten zu brauchen.
  // - **Zwei Nickerchen an einem Tag, eines davon mit zwei Abschnitten.**
  //   Eine Liste, die nie mehr als ein Element trägt, beweist nicht, dass
  //   sie eine Liste ist; und ein Nickerchen mit nur einem Abschnitt
  //   nicht, dass die innere Gruppe erhalten bleibt.
  group('sleepSessions — Tagschlaf', () {
    test('eine Nacht ohne Nickerchen liefert naps: [], nicht null', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final nacht = result.firstWhere(
          (n) => BerlinCalendar.dayKey(n.date) == '2026-09-10');
      expect(nacht.naps, isEmpty,
          reason: 'der haeufige Fall darf sich nicht aendern');
    });

    test('ohne naps-Schluessel im Datensatz wirft der Mock nicht', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final ohneSchluessel = demoSleep
          .cast<Map<String, dynamic>>()
          .where((n) => !n.containsKey('naps'))
          .map((n) => n['night'] as String)
          .toSet();
      expect(ohneSchluessel.length, 41,
          reason: 'Vorbedingung: nur zwei Naechte tragen den Schluessel');
      for (final nacht in result) {
        if (!ohneSchluessel.contains(BerlinCalendar.dayKey(nacht.date))) {
          continue;
        }
        expect(nacht.naps, isEmpty, reason: BerlinCalendar.dayKey(nacht.date));
      }
    });

    test('die Nacht auf den 27.10. traegt ein Nickerchen', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final nacht = result.firstWhere(
          (n) => BerlinCalendar.dayKey(n.date) == '2026-10-27');
      expect(nacht.naps, hasLength(1));
      final nap = nacht.naps.single;
      expect(nap.segments, hasLength(1));
      // 27.10.2026 liegt nach der Umstellung (25.10.), also MEZ = UTC+1.
      expect(nap.segments.single.start, DateTime.utc(2026, 10, 27, 12, 40));
      expect(nap.segments.single.end, DateTime.utc(2026, 10, 27, 13, 12));
      expect(nap.segments.single.stage, SleepStage.core);
    });

    test('die Nacht auf den 24.10. traegt zwei, aufsteigend', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final nacht = result.firstWhere(
          (n) => BerlinCalendar.dayKey(n.date) == '2026-10-24');
      expect(nacht.naps, hasLength(2));
      // 24.10.2026 liegt vor der Umstellung, also MESZ = UTC+2.
      expect(nacht.naps.first.segments.first.start,
          DateTime.utc(2026, 10, 24, 10, 5));
      expect(nacht.naps.last.segments.first.start,
          DateTime.utc(2026, 10, 24, 14, 20));
      expect(
        nacht.naps.first.segments.first.start
            .isBefore(nacht.naps.last.segments.first.start),
        isTrue,
        reason: 'die Reihenfolge des Datensatzes bleibt erhalten',
      );
    });

    test('ein Nickerchen behaelt seine eigenen Abschnitte', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      final nacht = result.firstWhere(
          (n) => BerlinCalendar.dayKey(n.date) == '2026-10-24');
      final zweites = nacht.naps.last;
      expect(zweites.segments, hasLength(2),
          reason: 'zwei Abschnitte in EINEM Nickerchen, nicht zwei Nickerchen');
      expect(zweites.segments.first.stage, SleepStage.core);
      expect(zweites.segments.last.stage, SleepStage.awake);
      expect(zweites.segments.last.end, DateTime.utc(2026, 10, 24, 14, 45));
    });

    test('Nickerchen zaehlen nicht in die Nacht selbst', () async {
      final result = await MockHealthReading().sleepSessions(from, through);
      for (final tag in ['2026-10-24', '2026-10-27']) {
        final nacht =
            result.firstWhere((n) => BerlinCalendar.dayKey(n.date) == tag);
        final datensatz = demoSleep
            .cast<Map<String, dynamic>>()
            .firstWhere((n) => n['night'] == tag);
        expect(nacht.session.segments.length,
            (datensatz['segments'] as List).length,
            reason: '$tag: `naps` gehoert nicht in `session`');
        for (final nap in nacht.naps) {
          for (final abschnitt in nap.segments) {
            expect(
              nacht.session.segments.any((s) => s.start == abschnitt.start),
              isFalse,
              reason: '$tag: ein Tagschlaf-Abschnitt steht in der Nacht',
            );
          }
        }
      }
    });

    test('Nickerchen erzeugen keine zusaetzlichen quantitySamples', () async {
      // `hrBins`/`rrBins` liegen je Nacht vor und spannen die Nacht auf,
      // nicht den Tag. Ein Nickerchen bringt keine eigenen Bins mit — wer
      // es trotzdem in die Spanne hineinrechnete, verschoebe jeden Punkt
      // der Nacht.
      final tagesbeginn = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 27));
      final tagesende = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 28));
      final punkte = await MockHealthReading()
          .quantitySamples(VitalKind.heartRate, tagesbeginn, tagesende);
      final napBeginn = DateTime.utc(2026, 10, 27, 12, 40);
      final napEnde = DateTime.utc(2026, 10, 27, 13, 12);
      expect(
        punkte.where((p) =>
            !p.date.isBefore(napBeginn) && p.date.isBefore(napEnde)),
        isEmpty,
        reason: 'der Mock erfindet fuer ein Nickerchen keine Messreihe',
      );
    });
  });

  group('workouts', () {
    test('liefert alle 18 Trainings des Demo-Datensatzes', () async {
      final result = await MockHealthReading().workouts(from, through);
      expect(result.length, demoWorkouts.length);
      expect(result.length, 18);
    });

    test('stehen aufsteigend nach Startzeit', () async {
      final result = await MockHealthReading().workouts(from, through);
      for (var i = 1; i < result.length; i++) {
        expect(result[i].start.isAfter(result[i - 1].start), isTrue);
      }
    });

    test('ein Krafttraining ohne GPS hat km == null, nicht 0 (10.09., kein nil-wird-0)',
        () async {
      final result = await MockHealthReading().workouts(from, through);
      final erstes = result.first;
      expect(erstes.kind, WorkoutKind.strength);
      expect(erstes.km, isNull,
          reason: 'laut Demo-Datensatz hat dieses Training kein km — nicht 0.0');
      expect(erstes.avgHR, 120);
      expect(erstes.maxHR, 160);
    });

    test('ein Lauf mit GPS hat km gesetzt (16.09.)', () async {
      final result = await MockHealthReading().workouts(from, through);
      final lauf = result.firstWhere((w) => BerlinCalendar.dayKey(w.start) == '2026-09-16');
      expect(lauf.kind, WorkoutKind.running);
      expect(lauf.km, 4.25);
    });
  });

  group('quantitySamples', () {
    test('heartRate liefert Werte fuer eine vorhandene Nacht, aufsteigend sortiert',
        () async {
      final nachtStart = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 9));
      final nachtEnde = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 11));
      final result = await MockHealthReading()
          .quantitySamples(VitalKind.heartRate, nachtStart, nachtEnde);
      expect(result, isNotEmpty);
      for (var i = 1; i < result.length; i++) {
        expect(result[i].date.isAfter(result[i - 1].date), isTrue);
      }
    });

    test('respiratoryRate liefert eigene, von heartRate verschiedene Werte',
        () async {
      final nachtStart = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 9));
      final nachtEnde = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 11));
      final reading = MockHealthReading();
      final hr = await reading.quantitySamples(VitalKind.heartRate, nachtStart, nachtEnde);
      final rr =
          await reading.quantitySamples(VitalKind.respiratoryRate, nachtStart, nachtEnde);
      expect(rr, isNotEmpty);
      // Atemfrequenz liegt immer deutlich unter dem Puls — triviale, aber
      // echte Unterscheidung zwischen den beiden VitalKind-Faellen.
      final hrDurchschnitt = hr.map((s) => s.value).reduce((a, b) => a + b) / hr.length;
      final rrDurchschnitt = rr.map((s) => s.value).reduce((a, b) => a + b) / rr.length;
      expect(rrDurchschnitt, lessThan(hrDurchschnitt));
    });
  });

  group('hourlySteps', () {
    test('liefert nichtnegative Werte, nachts (02-04 Uhr) niedriger als mittags',
        () async {
      final tag = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 10));
      final folgetag = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 11));
      final result = await MockHealthReading().hourlySteps(tag, folgetag);
      expect(result, isNotEmpty);
      for (final sample in result) {
        expect(sample.value, greaterThanOrEqualTo(0));
      }
      final nachtSumme = result
          .where((s) => s.date.toUtc().hour >= 0 && s.date.toUtc().hour < 4)
          .fold<double>(0, (sum, s) => sum + s.value);
      final mittagSumme = result
          .where((s) => s.date.toUtc().hour >= 11 && s.date.toUtc().hour < 14)
          .fold<double>(0, (sum, s) => sum + s.value);
      expect(nachtSumme, lessThan(mittagSumme));
    });
  });

  group('nutritionEntries', () {
    test('ein Tag mit Mahlzeiten liefert sie vollstaendig (11.09., drei Mahlzeiten)',
        () async {
      final tag = BerlinCalendar.startOfDay(DateTime.utc(2026, 9, 11));
      final result = await MockHealthReading().nutritionEntries(tag);
      final erwartet =
          demoMeals.where((m) => m['date'] == '2026-09-11').toList();
      expect(result.length, erwartet.length);
      expect(result.length, 3);
      final shake = result.firstWhere((e) => e.name == 'Proteinshake');
      expect(shake.kcal, 249);
      expect(shake.proteinG, 14);
      expect(shake.carbsG, 26);
      expect(shake.fatG, 6);
    });

    test('ein Tag ohne Mahlzeiten liefert eine leere Liste, kein Platzhalter',
        () async {
      // ~35% der Tage haben laut docs/demo_dataset.md keinen Eintrag.
      final ohneMahlzeit = demoDays
          .map((d) => d['date'] as String)
          .where((tag) => demoMeals.every((m) => m['date'] != tag))
          .first;
      final teile = ohneMahlzeit.split('-').map(int.parse).toList();
      final tag = BerlinCalendar.startOfDay(
          DateTime.utc(teile[0], teile[1], teile[2]));
      final result = await MockHealthReading().nutritionEntries(tag);
      expect(result, isEmpty);
    });
  });
}
