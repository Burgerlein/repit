import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/zyklus_repository.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für **Ablage und Werttypen des Zykluskalenders** (Bereich #539,
/// Stufe 3 des Umsetzungsplans) — `ZyklusEintrag`, `ZyklusRepository`,
/// `ZyklusEinstellungen` und der Health-Spiegel in
/// `lib/data/zyklus_repository.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn, statt ihn
/// passend zu machen.
///
/// Die Tabellen selbst (Spalten, Stufe 25) prüft `schema_v25_test.dart`,
/// die Clusterregel und die Vorhersage der Kern
/// (`Packages/trainings_core/test/`).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`:
///
/// - **4.1** die Spalten eines Tageseintrags und der Satz, um den sich
///   diese Datei dreht: „**Eine Zeile ohne jeden Wert wird gelöscht, nicht
///   gespeichert.** Ein leerer Tag ist ein Tag ohne Zeile."
/// - **4.2** der Health-Spiegel: „Je geschriebenem Sample eine Zeile. Beim
///   Ändern oder Löschen eines Tages werden die zugehörigen Samples
///   gezielt entfernt."
/// - **4.3** die Einstellungen: `kalenderAn`, `sicht`, `verhuetungAn`,
///   `verhuetungSeit`, `verhuetungArt`, `importGelaufen`,
///   `vorhersagePausiert`.
/// - **7**: „`Messwert<T>` gilt hier nicht — Zyklusdaten sind eigene
///   Daten, leer heißt leer."
///
/// Dazu Plan `docs/superpowers/plans/2026-11-23-zyklus-umsetzung.md`,
/// Stufe 3 und 4: Tagesschlüssel als ISO-String, **Filterung in SQL**,
/// Werttypen mit `==` und `hashCode`, weil sie Abhängigkeit eines
/// Providers werden.
///
/// Der Code existierte beim Schreiben dieser Datei nicht. Gelesen wurden
/// Spec, Plan und die bestehenden Ablage-Tests (`ereignisse_test.dart`,
/// `ziele_test.dart`), nicht die spätere Implementierung.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Spec und Plan lassen die folgenden Punkte offen; diese Datei legt sie
/// fest, damit der Implementierende nicht raten muss (der Plan sagt
/// ausdrücklich: „Was unterwegs auffällt, wird als Karte abgelegt und im
/// Code benannt, nicht geraten"):
///
/// - **Die Namen.** Repository `ZyklusRepository`, Werttyp
///   `ZyklusEintrag` (die drift-Zeile heißt anders — `ZyklusRow` oder
///   wie der Generator sie nennt), Einstellungen
///   `ZyklusEinstellungen`, Provider `zyklusRepositoryProvider`. Datei
///   `lib/data/zyklus_repository.dart`, Tabellen in
///   `lib/data/zyklus_tabelle.dart` (sonst Ringimport, wie bei
///   `ereignis_tabelle.dart`).
/// - **`Blutungsstaerke` kommt aus dem Kern** — die Spec legt sie in
///   Abschnitt 5 dorthin, weil `periodenAus` damit rechnet.
///   **`Schmerzstaerke`, `Testergebnis`, `ZyklusQuelle` und
///   `ZyklusSicht` nicht:** Sie tragen keine Rechnung, sondern sind
///   Nutzlast der Ablage, und Transporttypen gehören nicht in den Kern
///   (`CLAUDE.md`). Sie stehen deshalb neben dem Repository.
/// - **`ZyklusEintrag.istLeer`** ist die eine Stelle, an der „ohne jeden
///   Wert" entschieden wird. Leer heißt: keine Blutung, keine
///   Zwischenblutung, kein Schmerz, keine Symptome, kein Sex, kein Test,
///   keine Notiz. **Eine Notiz zählt, wenn sie nach `trim()` nicht leer
///   ist** — sonst bliebe ein Tag stehen, auf dem nur ein Leerzeichen
///   steht. `quelle` und `geaendert` zählen **nicht** als Wert: Sie sagen
///   etwas über die Zeile, nicht über den Tag.
/// - **`verhuetet` ohne `sex` prüft diese Datei nicht.** Spec 4.1 sagt
///   „nur sinnvoll, wenn `sex`", und das Formular kann den Zustand nicht
///   erzeugen; was `istLeer` dann liefert, entscheidet der
///   Implementierende.
/// - **`symptome` ist im Werttyp eine `List<String>`** und in der Tabelle
///   der kommagetrennte Text aus Spec 4.1. Die leere Liste ist der leere
///   Text, nicht `null`.
/// - **`schreibe` setzt `geaendert` immer aus der Uhr**, als UTC, und
///   übernimmt ein mitgegebenes `geaendert` nicht. Die Uhr wird
///   **injiziert** (`ZyklusRepository(db, uhr: …)`), im Provider aus
///   `clockProvider` — kein `DateTime.now()` im Rumpf.
/// - **`loesche(tag)` nimmt die Spiegelzeilen dieses Tages mit.** Wer die
///   Samples in HealthKit entfernen will, liest `spiegel(tag)` **vorher**
///   — danach sind die UUIDs weg. Das ist die Reihenfolge, die Spec 4.2
///   verlangt („gezielt entfernen").
/// - **Was `schreibe` mit dem Spiegel macht, wenn der Tag Werte behält,
///   steht hier nicht.** Welche Samples neu geschrieben und welche
///   verworfen werden, entscheidet die HealthKit-Stufe (Stufe 9 des
///   Plans), nicht die Ablage. Geprüft ist nur: Verschwindet der Tag,
///   verschwindet sein Spiegel.
/// - **`ZyklusEinstellungen.vorbelegung` ist eine Dart-Konstante**, keine
///   Zeile in der Datenbank — dieselbe Überlegung wie bei
///   `Ziele.vorbelegung`: sonst stünde die Vorbelegung an zwei Orten, und
///   einer wäre irgendwann der falsche. Der Kalender ist darin **aus**
///   (Spec: „Der Kalender erscheint unter *Mehr* nur, wenn
///   eingeschaltet"), die Sicht ist `ueberblick` (die Spec nennt sie
///   zuerst), alles übrige aus bzw. `null`.
/// - **`verhuetungArt` ist ein `String?`**, nicht ein Aufzählungstyp:
///   Spec 4.3 schreibt „Text, nullable", und die Arten aus 6.2 gehören zu
///   den Mitteilungen, nicht zur Ablage.
///
/// **Alle Tage, Notizen, Symptome, UUIDs und Zeitpunkte hier sind
/// erfunden** und liegen im Jahr 2099. Es steht kein einziger echter
/// Gesundheitswert im Quelltext (`CLAUDE.md`, „Niemals tun").
void main() {
  late AppCache db;
  late DateTime jetzt;
  late ZyklusRepository repo;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    jetzt = DateTime.utc(2099, 6, 3, 9, 30);
    repo = ZyklusRepository(db, uhr: () => jetzt);
  });

  /// Ein Tag mit allem, was Spec 4.1 kennt — erfunden, bis aufs letzte
  /// Zeichen.
  const voll = ZyklusEintrag(
    tag: '2099-06-03',
    blutung: Blutungsstaerke.mittel,
    zwischenblutung: false,
    schmerz: Schmerzstaerke.leicht,
    symptome: ['pruefsymptomA', 'pruefsymptomB'],
    sex: true,
    verhuetet: true,
    test: Testergebnis.negativ,
    notiz: 'Prüfnotiz',
  );

  const leer = ZyklusEintrag(tag: '2099-06-03');

  Future<List<Map<String, Object?>>> rohEintraege() async {
    final zeilen = await db
        .customSelect('SELECT * FROM zyklus_eintraege ORDER BY tag;')
        .get();
    return [for (final z in zeilen) z.data];
  }

  Future<List<Map<String, Object?>>> rohSpiegel() async {
    final zeilen = await db
        .customSelect('SELECT * FROM zyklus_health_spiegel ORDER BY uuid;')
        .get();
    return [for (final z in zeilen) z.data];
  }

  Future<List<Map<String, Object?>>> rohEinstellungen() async {
    final zeilen = await db
        .customSelect('SELECT * FROM zyklus_einstellungen;')
        .get();
    return [for (final z in zeilen) z.data];
  }

  group('Der Werttyp ZyklusEintrag', () {
    test('vergleicht über alle Felder — er wird Abhängigkeit eines '
        'Providers, und ohne == rechnete jeder Beobachter bei jedem '
        'Neulesen neu (Hausregel 2)', () {
      const a = voll;
      const b = ZyklusEintrag(
        tag: '2099-06-03',
        blutung: Blutungsstaerke.mittel,
        zwischenblutung: false,
        schmerz: Schmerzstaerke.leicht,
        symptome: ['pruefsymptomA', 'pruefsymptomB'],
        sex: true,
        verhuetet: true,
        test: Testergebnis.negativ,
        notiz: 'Prüfnotiz',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);

      ZyklusEintrag mit({
        String tag = '2099-06-03',
        Blutungsstaerke? blutung = Blutungsstaerke.mittel,
        bool zwischenblutung = false,
        Schmerzstaerke? schmerz = Schmerzstaerke.leicht,
        List<String> symptome = const ['pruefsymptomA', 'pruefsymptomB'],
        bool sex = true,
        bool? verhuetet = true,
        Testergebnis? test = Testergebnis.negativ,
        String? notiz = 'Prüfnotiz',
        ZyklusQuelle quelle = ZyklusQuelle.eigen,
        DateTime? geaendert,
      }) => ZyklusEintrag(
        tag: tag,
        blutung: blutung,
        zwischenblutung: zwischenblutung,
        schmerz: schmerz,
        symptome: symptome,
        sex: sex,
        verhuetet: verhuetet,
        test: test,
        notiz: notiz,
        quelle: quelle,
        geaendert: geaendert,
      );

      expect(mit(), a, reason: 'die Hilfe baut denselben Wert');
      expect(mit(tag: '2099-06-04'), isNot(a), reason: 'tag');
      expect(mit(blutung: Blutungsstaerke.stark), isNot(a), reason: 'blutung');
      expect(mit(blutung: null), isNot(a), reason: 'blutung null');
      expect(mit(zwischenblutung: true), isNot(a), reason: 'zwischenblutung');
      expect(mit(schmerz: null), isNot(a), reason: 'schmerz');
      expect(mit(symptome: const []), isNot(a), reason: 'symptome');
      expect(
        mit(symptome: const ['pruefsymptomA']),
        isNot(a),
        reason: 'symptome, ein Eintrag weniger',
      );
      expect(mit(sex: false), isNot(a), reason: 'sex');
      expect(mit(verhuetet: false), isNot(a), reason: 'verhuetet');
      expect(mit(verhuetet: null), isNot(a), reason: 'verhuetet null');
      expect(mit(test: Testergebnis.positiv), isNot(a), reason: 'test');
      expect(mit(notiz: null), isNot(a), reason: 'notiz');
      expect(mit(quelle: ZyklusQuelle.health), isNot(a), reason: 'quelle');
      expect(
        mit(geaendert: DateTime.utc(2099, 6, 3, 9, 30)),
        isNot(a),
        reason: 'geaendert',
      );
    });

    test('zwei gleiche Symptomlisten sind gleich, auch als verschiedene '
        'Objekte — sonst wäre jeder neu gelesene Tag ungleich sich '
        'selbst', () {
      final a = ZyklusEintrag(
        tag: '2099-06-03',
        symptome: ['pruefsymptomA', 'pruefsymptomB'],
      );
      final b = ZyklusEintrag(
        tag: '2099-06-03',
        symptome: ['pruefsymptomA', 'pruefsymptomB'],
      );
      expect(
        identical(a.symptome, b.symptome),
        isFalse,
        reason: 'Vorbedingung',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('istLeer: ein Tag ohne jeden Wert ist leer', () {
      expect(leer.istLeer, isTrue);
      expect(
        const ZyklusEintrag(
          tag: '2099-06-03',
          quelle: ZyklusQuelle.health,
        ).istLeer,
        isTrue,
        reason:
            'quelle sagt etwas über die Zeile, nicht über den Tag. Eine '
            'leere Zeile aus dem Import ist genauso leer wie eine eigene',
      );
      expect(
        const ZyklusEintrag(tag: '2099-06-03', symptome: []).istLeer,
        isTrue,
      );
    });

    test('istLeer: jedes einzelne Feld macht den Tag nicht leer', () {
      expect(
        const ZyklusEintrag(
          tag: '2099-06-03',
          blutung: Blutungsstaerke.leicht,
        ).istLeer,
        isFalse,
        reason: 'blutung',
      );
      expect(
        const ZyklusEintrag(tag: '2099-06-03', zwischenblutung: true).istLeer,
        isFalse,
        reason:
            'Zwischenblutung ist ein eigenes Feld und kein Blutungstag '
            '(Spec 1) — aber ein Wert',
      );
      expect(
        const ZyklusEintrag(
          tag: '2099-06-03',
          schmerz: Schmerzstaerke.stark,
        ).istLeer,
        isFalse,
        reason: 'schmerz',
      );
      expect(
        const ZyklusEintrag(
          tag: '2099-06-03',
          symptome: ['pruefsymptomA'],
        ).istLeer,
        isFalse,
        reason: 'symptome',
      );
      expect(
        const ZyklusEintrag(tag: '2099-06-03', sex: true).istLeer,
        isFalse,
        reason: 'sex',
      );
      expect(
        const ZyklusEintrag(
          tag: '2099-06-03',
          test: Testergebnis.positiv,
        ).istLeer,
        isFalse,
        reason:
            'ein positiver Test pausiert die Vorhersage (Spec 3.8) — er darf '
            'auf keinen Fall mit einer leeren Zeile verschwinden',
      );
      expect(
        const ZyklusEintrag(tag: '2099-06-03', notiz: 'Prüfnotiz').istLeer,
        isFalse,
        reason: 'notiz',
      );
      expect(voll.istLeer, isFalse);
    });

    test('istLeer: eine Notiz aus Leerzeichen ist keine Notiz', () {
      expect(
        const ZyklusEintrag(tag: '2099-06-03', notiz: '').istLeer,
        isTrue,
        reason:
            'sonst bliebe ein Tag stehen, auf dem nichts steht — und die '
            'Nutzerin, die alle Felder leert, hinterließe trotzdem einen '
            'Eintrag',
      );
      expect(
        const ZyklusEintrag(tag: '2099-06-03', notiz: '   ').istLeer,
        isTrue,
      );
    });
  });

  group('Das Repository: Eintragen, Lesen, Ändern', () {
    test('ein unbekannter Tag ist null, nicht ein leerer Eintrag', () async {
      expect(
        await repo.lies('2099-06-03'),
        isNull,
        reason:
            'leer heißt leer (Spec 7): Zyklusdaten sind eigene Daten, es '
            'gibt keinen Lauf, der leer ausgehen könnte. Kein Messwert, kein '
            'LeerNachLauf',
      );
    });

    test('schreibe legt den Tag ab, lies gibt ihn zurück', () async {
      await repo.schreibe(voll);

      final gelesen = await repo.lies('2099-06-03');
      expect(gelesen, isNotNull);
      expect(gelesen!.tag, '2099-06-03');
      expect(gelesen.blutung, Blutungsstaerke.mittel);
      expect(gelesen.zwischenblutung, isFalse);
      expect(gelesen.schmerz, Schmerzstaerke.leicht);
      expect(gelesen.symptome, ['pruefsymptomA', 'pruefsymptomB']);
      expect(gelesen.sex, isTrue);
      expect(gelesen.verhuetet, isTrue);
      expect(gelesen.test, Testergebnis.negativ);
      expect(gelesen.notiz, 'Prüfnotiz');
      expect(gelesen.quelle, ZyklusQuelle.eigen);
      expect(gelesen.geaendert, DateTime.utc(2099, 6, 3, 9, 30));
    });

    test('schreibe setzt geaendert aus der Uhr, als UTC — nie aus dem '
        'mitgegebenen Wert', () async {
      await repo.schreibe(
        ZyklusEintrag(
          tag: '2099-06-03',
          blutung: Blutungsstaerke.leicht,
          geaendert: DateTime.utc(2000, 1, 1),
        ),
      );

      final gelesen = await repo.lies('2099-06-03');
      expect(
        gelesen!.geaendert,
        DateTime.utc(2099, 6, 3, 9, 30),
        reason:
            'der Zeitstempel kommt aus der injizierten Uhr, nicht aus dem '
            'Aufrufer und nicht aus DateTime.now() im Rumpf — sonst wäre er '
            'in keinem Test prüfbar',
      );
      expect(gelesen.geaendert!.isUtc, isTrue);
    });

    test('eine Uhr in Ortszeit wird nach UTC umgerechnet', () async {
      final lokal = ZyklusRepository(
        db,
        uhr: () => DateTime.utc(2099, 6, 3, 9, 30).toLocal(),
      );
      await lokal.schreibe(
        const ZyklusEintrag(tag: '2099-06-03', blutung: Blutungsstaerke.stark),
      );

      final gelesen = await lokal.lies('2099-06-03');
      expect(gelesen!.geaendert!.isUtc, isTrue);
      expect(
        gelesen.geaendert,
        DateTime.utc(2099, 6, 3, 9, 30),
        reason:
            'Dart vergleicht DateTime samt isUtc — ein als Ortszeit '
            'abgelegter Wert wäre ungleich sich selbst',
      );
    });

    test('schreibe auf denselben Tag ändert die eine Zeile, legt keine '
        'zweite an', () async {
      await repo.schreibe(voll);
      jetzt = DateTime.utc(2099, 6, 4, 20, 15);

      await repo.schreibe(
        const ZyklusEintrag(
          tag: '2099-06-03',
          blutung: Blutungsstaerke.stark,
          notiz: 'geändert',
        ),
      );

      expect(await rohEintraege(), hasLength(1));
      final gelesen = await repo.lies('2099-06-03');
      expect(gelesen!.blutung, Blutungsstaerke.stark);
      expect(gelesen.notiz, 'geändert');
      expect(
        gelesen.schmerz,
        isNull,
        reason:
            'geschrieben wird der ganze Tag, nicht ein Feld: Ein Schmerz, '
            'den die Nutzerin wegnimmt, bleibt sonst für immer stehen',
      );
      expect(gelesen.symptome, isEmpty);
      expect(gelesen.sex, isFalse);
      expect(gelesen.verhuetet, isNull);
      expect(gelesen.test, isNull);
      expect(gelesen.geaendert, DateTime.utc(2099, 6, 4, 20, 15));
    });

    test('die Symptome gehen als kommagetrennter Text in die Tabelle und '
        'als Liste zurück', () async {
      await repo.schreibe(
        const ZyklusEintrag(
          tag: '2099-06-03',
          symptome: ['pruefsymptomA', 'pruefsymptomB'],
        ),
      );

      expect(
        (await rohEintraege()).single['symptome'],
        'pruefsymptomA,pruefsymptomB',
        reason: 'Spec 4.1: „kommagetrennte Schlüssel"',
      );
      expect((await repo.lies('2099-06-03'))!.symptome, [
        'pruefsymptomA',
        'pruefsymptomB',
      ]);
    });

    test('keine Symptome heißen leerer Text, nicht NULL', () async {
      await repo.schreibe(
        const ZyklusEintrag(tag: '2099-06-03', blutung: Blutungsstaerke.leicht),
      );

      expect((await rohEintraege()).single['symptome'], '');
      expect((await repo.lies('2099-06-03'))!.symptome, isEmpty);
    });

    test('eine fehlende Notiz bleibt NULL, nicht leerer Text', () async {
      await repo.schreibe(
        const ZyklusEintrag(tag: '2099-06-03', blutung: Blutungsstaerke.leicht),
      );

      expect((await rohEintraege()).single['notiz'], isNull);
      expect((await repo.lies('2099-06-03'))!.notiz, isNull);
    });

    test('die Quelle wird abgelegt und kommt zurück — der Erstimport muss '
        'erkennbar bleiben', () async {
      await repo.schreibe(
        const ZyklusEintrag(
          tag: '2099-06-03',
          blutung: Blutungsstaerke.leicht,
          quelle: ZyklusQuelle.health,
        ),
      );

      expect((await rohEintraege()).single['quelle'], 'health');
      expect((await repo.lies('2099-06-03'))!.quelle, ZyklusQuelle.health);
    });

    test('eine Zeile mit unbekannter Blutungsstufe wird übergangen, nicht '
        'geworfen und nicht gelöscht', () async {
      await db.customStatement(
        'INSERT INTO zyklus_eintraege (tag, blutung, symptome, quelle, '
        "geaendert) VALUES ('2099-06-03', 'pruefstufeX', '', 'eigen', "
        "'2099-06-03T07:05:00.000Z');",
      );

      final gelesen = await repo.lies('2099-06-03');
      expect(
        gelesen?.blutung,
        isNull,
        reason:
            'eine spätere Fassung kennt vielleicht eine vierte Stufe, und '
            'eine ältere soll die Datei trotzdem öffnen — dieselbe Regel '
            'wie bei ereignisse.art (V20)',
      );
      expect(
        await rohEintraege(),
        hasLength(1),
        reason: 'übergangen heißt nicht gelöscht',
      );
    });
  });

  group('Eine Zeile ohne jeden Wert wird gelöscht, nicht gespeichert', () {
    test('ein leerer Tag, den es nie gab, legt keine Zeile an', () async {
      await repo.schreibe(leer);

      expect(
        await rohEintraege(),
        isEmpty,
        reason:
            'Spec 4.1: „Ein leerer Tag ist ein Tag ohne Zeile." Eine Zeile '
            'nur mit Tag und Zeitstempel behauptete, die Nutzerin habe etwas '
            'eingetragen',
      );
      expect(await repo.lies('2099-06-03'), isNull);
    });

    test('wer alle Felder leert, hinterlässt keinen Tag', () async {
      await repo.schreibe(voll);
      expect(await rohEintraege(), hasLength(1), reason: 'Vorbedingung');

      await repo.schreibe(leer);

      expect(
        await rohEintraege(),
        isEmpty,
        reason:
            'die wichtigste Regel aus Spec 4.1. Bliebe die Zeile stehen, '
            'zählte sie im Kalender weiter als „etwas eingetragen", und die '
            'Nutzerin hätte keinen Weg, einen Tag zurückzunehmen',
      );
      expect(await repo.lies('2099-06-03'), isNull);
    });

    test('eine Notiz aus Leerzeichen rettet den Tag nicht', () async {
      await repo.schreibe(voll);

      await repo.schreibe(const ZyklusEintrag(tag: '2099-06-03', notiz: '  '));

      expect(await rohEintraege(), isEmpty);
    });

    test('das Leeren nimmt nur diesen Tag mit, nicht die Nachbarn', () async {
      await repo.schreibe(voll);
      await repo.schreibe(
        const ZyklusEintrag(tag: '2099-06-04', blutung: Blutungsstaerke.leicht),
      );

      await repo.schreibe(leer);

      expect(await repo.lies('2099-06-03'), isNull);
      expect((await repo.lies('2099-06-04'))!.blutung, Blutungsstaerke.leicht);
    });

    test('das Leeren nimmt den Health-Spiegel dieses Tages mit', () async {
      await repo.schreibe(voll);
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0002',
        tag: '2099-06-04',
        typ: 'pruef_typ_blutung',
      );

      await repo.schreibe(leer);

      expect(
        await repo.spiegel('2099-06-03'),
        isEmpty,
        reason:
            'Spec 4.2: Beim Löschen eines Tages werden die zugehörigen '
            'Samples gezielt entfernt. Bliebe die Spiegelzeile stehen, '
            'zeigte Health einen sensiblen Eintrag weiter, den es in der App '
            'nicht mehr gibt',
      );
      expect(await repo.spiegel('2099-06-04'), hasLength(1));
    });
  });

  group('Löschen', () {
    test('loesche nimmt die Zeile und ihren Spiegel mit', () async {
      await repo.schreibe(voll);
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0002',
        tag: '2099-06-03',
        typ: 'pruef_typ_symptom',
      );

      await repo.loesche('2099-06-03');

      expect(await repo.lies('2099-06-03'), isNull);
      expect(await rohEintraege(), isEmpty);
      expect(await rohSpiegel(), isEmpty);
    });

    test(
      'loesche auf einen Tag ohne Zeile tut nichts und wirft nicht',
      () async {
        await repo.schreibe(
          const ZyklusEintrag(
            tag: '2099-06-04',
            blutung: Blutungsstaerke.leicht,
          ),
        );

        await repo.loesche('2099-06-03');

        expect(await rohEintraege(), hasLength(1));
      },
    );
  });

  group('Der Bereich über einen Monat', () {
    Future<void> lege(String tag, Blutungsstaerke staerke) =>
        repo.schreibe(ZyklusEintrag(tag: tag, blutung: staerke));

    test('liefert nur die Tage des Zeitraums, einschließlich der Ränder, '
        'sortiert', () async {
      for (final tag in [
        '2099-05-31',
        '2099-06-01',
        '2099-06-15',
        '2099-06-30',
        '2099-07-01',
      ]) {
        await lege(tag, Blutungsstaerke.leicht);
      }

      final monat = await repo.imZeitraum(von: '2099-06-01', bis: '2099-06-30');

      expect(
        [for (final e in monat) e.tag],
        ['2099-06-01', '2099-06-15', '2099-06-30'],
        reason:
            'gefiltert wird in SQL über den ISO-Tagesstring, einschließlich '
            'beider Ränder. Nach dem Laden in Dart zu filtern umginge Regel '
            '2 der Datenschicht',
      );
    });

    test('sortiert aufsteigend, auch wenn die Tage durcheinander '
        'eingetragen wurden und über einen Jahreswechsel liegen', () async {
      for (final tag in ['2100-01-02', '2099-12-28', '2099-12-31']) {
        await lege(tag, Blutungsstaerke.mittel);
      }

      final fenster = await repo.imZeitraum(
        von: '2099-12-01',
        bis: '2100-01-31',
      );

      expect(
        [for (final e in fenster) e.tag],
        ['2099-12-28', '2099-12-31', '2100-01-02'],
      );
    });

    test('ein Zeitraum ohne Tage ist eine leere Liste, kein Fehler', () async {
      expect(
        await repo.imZeitraum(von: '2099-06-01', bis: '2099-06-30'),
        isEmpty,
      );
    });

    test('die gelesenen Tage tragen alle Felder', () async {
      await repo.schreibe(voll);

      final monat = await repo.imZeitraum(von: '2099-06-01', bis: '2099-06-30');
      expect(monat.single, await repo.lies('2099-06-03'));
    });
  });

  group('Der Health-Spiegel', () {
    test('merkeSample legt je Sample eine Zeile mit Tag und Typ an', () async {
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0002',
        tag: '2099-06-03',
        typ: 'pruef_typ_symptom',
      );

      final gemerkt = await repo.spiegel('2099-06-03');
      expect(
        gemerkt,
        hasLength(2),
        reason:
            'ein Zyklustag erzeugt mehrere Samples (Blutung, Sex, je Symptom '
            'eines) — je geschriebenem Sample eine Zeile',
      );
      expect(
        [for (final s in gemerkt) s.uuid],
        ['PRUEF-UUID-0001', 'PRUEF-UUID-0002'],
      );
      expect(
        [for (final s in gemerkt) s.typ],
        ['pruef_typ_blutung', 'pruef_typ_symptom'],
      );
      expect([for (final s in gemerkt) s.tag], ['2099-06-03', '2099-06-03']);
    });

    test('spiegel liefert nur die Samples dieses Tages', () async {
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0002',
        tag: '2099-06-04',
        typ: 'pruef_typ_blutung',
      );

      expect(
        [for (final s in await repo.spiegel('2099-06-04')) s.uuid],
        ['PRUEF-UUID-0002'],
      );
    });

    test('ein Tag ohne Samples ist eine leere Liste', () async {
      expect(await repo.spiegel('2099-06-03'), isEmpty);
    });

    test('dasselbe Sample zweimal zu merken bleibt eine Zeile', () async {
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );
      await repo.merkeSample(
        uuid: 'PRUEF-UUID-0001',
        tag: '2099-06-03',
        typ: 'pruef_typ_blutung',
      );

      expect(
        await rohSpiegel(),
        hasLength(1),
        reason:
            'die Sample-UUID ist der Schlüssel; ein zweiter Durchlauf des '
            'Schreibens darf nicht zwei Zeilen hinterlassen, die auf '
            'dasselbe Sample zeigen',
      );
    });
  });

  group('Die Einstellungen', () {
    test('ohne abgelegte Zeile gilt die Vorbelegung — kein null, kein '
        'Leerzustand', () async {
      final gelesen = await repo.liesEinstellungen();

      expect(gelesen, ZyklusEinstellungen.vorbelegung);
      expect(
        gelesen.kalenderAn,
        isFalse,
        reason:
            'der Kalender erscheint unter Mehr nur, wenn eingeschaltet '
            '(Spec 7) — eine App, die ihn ungefragt zeigt, hat ihn '
            'eingeschaltet, ohne gefragt zu werden',
      );
      expect(gelesen.sicht, ZyklusSicht.ueberblick);
      expect(gelesen.verhuetungAn, isFalse);
      expect(gelesen.verhuetungSeit, isNull);
      expect(gelesen.verhuetungArt, isNull);
      expect(gelesen.importGelaufen, isFalse);
      expect(gelesen.vorhersagePausiert, isFalse);
      expect(
        await rohEinstellungen(),
        isEmpty,
        reason:
            'das Lesen legt keine Zeile an. Die Vorbelegung ist eine '
            'Dart-Konstante, keine Zeile in der Datenbank — sonst stünde sie '
            'an zwei Orten (wie bei Ziele.vorbelegung)',
      );
    });

    test('schreibeEinstellungen legt die eine Zeile an und gibt sie '
        'zurück', () async {
      const neu = ZyklusEinstellungen(
        kalenderAn: true,
        sicht: ZyklusSicht.kinderwunsch,
        verhuetungAn: true,
        verhuetungSeit: '2099-06-01',
        verhuetungArt: 'pruefart',
        importGelaufen: true,
        vorhersagePausiert: true,
      );

      await repo.schreibeEinstellungen(neu);

      expect(await rohEinstellungen(), hasLength(1));
      expect(await repo.liesEinstellungen(), neu);
    });

    test('zweimal schreiben überschreibt die eine Zeile', () async {
      await repo.schreibeEinstellungen(
        ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true),
      );
      await repo.schreibeEinstellungen(
        ZyklusEinstellungen.vorbelegung.kopieMit(
          kalenderAn: true,
          sicht: ZyklusSicht.kinderwunsch,
        ),
      );

      expect(
        await rohEinstellungen(),
        hasLength(1),
        reason:
            'Einstellungen sind kein Verlauf. Eine zweite Zeile wäre ein '
            'zweiter, widersprechender Stand, und niemand wüsste, welcher '
            'gilt',
      );
      final gelesen = await repo.liesEinstellungen();
      expect(gelesen.kalenderAn, isTrue);
      expect(gelesen.sicht, ZyklusSicht.kinderwunsch);
    });

    test('der Zeitpunkt des Umschaltens auf Verhütung wird gespeichert und '
        'kommt zurück (Spec 3.7)', () async {
      await repo.schreibeEinstellungen(
        ZyklusEinstellungen.vorbelegung.kopieMit(
          kalenderAn: true,
          verhuetungAn: true,
          verhuetungSeit: '2099-06-01',
          verhuetungArt: 'pruefart',
        ),
      );

      final gelesen = await repo.liesEinstellungen();
      expect(
        gelesen.verhuetungSeit,
        '2099-06-01',
        reason:
            'nur so bleibt rückwirkend erkennbar, welcher Zyklus unter '
            'Verhütung lief — ein bloßes Flag verlöre das beim nächsten '
            'Umschalten',
      );
      expect(gelesen.verhuetungArt, 'pruefart');
    });

    test('das Ausschalten der Verhütung nimmt Zeitpunkt und Art zurück auf '
        'null, nicht auf leeren Text', () async {
      await repo.schreibeEinstellungen(
        ZyklusEinstellungen.vorbelegung.kopieMit(
          verhuetungAn: true,
          verhuetungSeit: '2099-06-01',
          verhuetungArt: 'pruefart',
        ),
      );

      await repo.schreibeEinstellungen(
        const ZyklusEinstellungen(
          kalenderAn: true,
          sicht: ZyklusSicht.ueberblick,
          verhuetungAn: false,
          verhuetungSeit: null,
          verhuetungArt: null,
          importGelaufen: false,
          vorhersagePausiert: false,
        ),
      );

      final zeile = (await rohEinstellungen()).single;
      expect(
        zeile['verhuetung_seit'],
        isNull,
        reason:
            'ein stehengebliebener Zeitpunkt behauptete eine Verhütung, die '
            'es nicht mehr gibt',
      );
      expect(zeile['verhuetung_art'], isNull);
      expect((await repo.liesEinstellungen()).verhuetungSeit, isNull);
    });

    test('ZyklusEinstellungen vergleicht über alle Felder', () {
      const a = ZyklusEinstellungen(
        kalenderAn: true,
        sicht: ZyklusSicht.kinderwunsch,
        verhuetungAn: true,
        verhuetungSeit: '2099-06-01',
        verhuetungArt: 'pruefart',
        importGelaufen: true,
        vorhersagePausiert: true,
      );

      expect(a, a.kopieMit(), reason: 'kopieMit ohne Argumente ändert nichts');
      expect(a.hashCode, a.kopieMit().hashCode);
      expect(a.kopieMit(kalenderAn: false), isNot(a), reason: 'kalenderAn');
      expect(
        a.kopieMit(sicht: ZyklusSicht.ueberblick),
        isNot(a),
        reason: 'sicht',
      );
      expect(a.kopieMit(verhuetungAn: false), isNot(a), reason: 'verhuetungAn');
      expect(
        a.kopieMit(verhuetungSeit: '2099-06-02'),
        isNot(a),
        reason: 'verhuetungSeit',
      );
      expect(
        a.kopieMit(verhuetungArt: 'pruefart2'),
        isNot(a),
        reason: 'verhuetungArt',
      );
      expect(
        a.kopieMit(importGelaufen: false),
        isNot(a),
        reason: 'importGelaufen',
      );
      expect(
        a.kopieMit(vorhersagePausiert: false),
        isNot(a),
        reason: 'vorhersagePausiert',
      );
    });
  });

  group('Der Provider', () {
    ProviderContainer behaelter() {
      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('zyklusRepositoryProvider schreibt in dieselbe Datenbank', () async {
      final c = behaelter();

      await c.read(zyklusRepositoryProvider).schreibe(voll);

      expect(
        (await rohEintraege()).single['tag'],
        '2099-06-03',
        reason: 'das Repository des Providers nimmt den appCacheProvider',
      );
    });

    test('das Repository des Providers nimmt die Uhr aus clockProvider — '
        'nie DateTime.now() im Rumpf', () async {
      jetzt = DateTime.utc(2099, 7, 1, 5, 45);
      final c = behaelter();

      await c.read(zyklusRepositoryProvider).schreibe(voll);

      expect(
        (await c.read(zyklusRepositoryProvider).lies('2099-06-03'))!.geaendert,
        DateTime.utc(2099, 7, 1, 5, 45),
      );
    });

    test('zweimal gelesen ist dasselbe Repository — ein Provider hält, was '
        'er anbietet (Hausregel 2)', () {
      final c = behaelter();

      expect(
        identical(
          c.read(zyklusRepositoryProvider),
          c.read(zyklusRepositoryProvider),
        ),
        isTrue,
      );
    });
  });
}
