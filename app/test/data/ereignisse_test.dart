import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ereignisse.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für **Ablage und Provider der Ereignisse** (#446 unter #404) —
/// Werttyp, Repository und Provider in `lib/data/ereignisse.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// Die Tabelle selbst (Spalten, Stufe 22) prüft `schema_v22_test.dart`, die
/// Regeln der Pause der Kern (`trainings_core/test/auszeit_test.dart`), die
/// Wirkung aufs Kalorienziel `ernaehrung/kalorienziel_pause_test.dart`.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitt
/// „Repository und Provider“, dazu V1 (Namen), V8 (Sortierung in SQL),
/// V12 (`laden` und Lesefehler) und V20 (unbekannte Art wird übergangen).
/// Die Vorgaben V1–V20 hat der Planende formuliert; Tim hat sie am
/// 10.11.2026 übernommen („Ja, so bauen“). Die Schnittstelle steht im Plan
/// `docs/superpowers/plans/2026-11-10-auszeit.md`, Task 3.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Plan und Spec lassen die folgenden Punkte offen; diese Datei legt sie
/// fest:
///
/// - **Der Konstruktor von `Ereignis` hat benannte Parameter**:
///   `Ereignis({int? id, required EreignisArt art, required String von,
///   required String bis, String? notiz, DateTime? angelegt,
///   DateTime? geaendert})`.
/// - **`legeAn` nimmt `angelegt` immer aus der Uhr** und schreibt
///   `geaendert` als `NULL` — auch wenn das übergebene Ereignis andere
///   Zeitstempel trägt. Eine Uhr, die Ortszeit liefert, wird nach UTC
///   umgerechnet.
/// - **`aendere` schreibt alle Felder außer `angelegt`**, auch eine Notiz,
///   die auf `null` zurückgeht. Ein `angelegt` im übergebenen Ereignis wird
///   nicht übernommen.
/// - **Das Repository schreibt die Notiz, wie sie kommt** — ungetrimmt
///   (Plan, Task 3: getrimmt wird im Formular, V6).
/// - **Das Repository des Providers nimmt die Uhr aus `clockProvider`**,
///   der injizierbaren Uhr der App.
/// - **`auszeitenProvider` führt alle Ereignisse als `AuszeitTage`**, in
///   der Reihenfolge von `alle()`, Urlaub eingeschlossen — welche davon
///   pausiert, entscheidet `pausierendeAuszeitAm` im Kern.
/// - **`auszeitenProvider` meldet sich nicht, wenn sich an den Tagen
///   nichts ändert** (etwa nur die Notiz). Das ist Hausregel 2 aus
///   `CLAUDE.md` und der Satz der Spec „Werttyp mit `==`, damit Abgeleitetes
///   nicht je Bild neu rechnet“ — der Test macht ihn prüfbar. Ein Record
///   vergleicht eine `List` nach Identität; eine neu gelesene, gleiche Liste
///   genügt also nicht von selbst.
/// - **Ein Lesefehler wird über eine fehlende Tabelle erzwungen**, nicht
///   über ein nachgebautes Repository — so legt der Test keine weitere
///   Form der Klasse fest.
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“).
void main() {
  late AppCache db;
  late DateTime jetzt;
  late EreignisRepository repo;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    jetzt = DateTime.utc(2099, 3, 14, 9, 30);
    repo = EreignisRepository(db, uhr: () => jetzt);
  });

  final op = Ereignis(
    art: EreignisArt.op,
    von: '2099-03-10',
    bis: '2099-03-24',
    notiz: 'Knie',
  );

  final urlaub = Ereignis(
    art: EreignisArt.urlaub,
    von: '2099-05-01',
    bis: '2099-05-14',
  );

  Future<List<EreignisRow>> zeilen() => (db.select(
    db.ereignisse,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  group('Der Werttyp', () {
    test('vergleicht über alle Felder', () {
      final a = Ereignis(
        id: 3,
        art: EreignisArt.krankheit,
        von: '2099-01-02',
        bis: '2099-01-05',
        notiz: 'Grippe',
        angelegt: DateTime.utc(2099, 1, 2, 8),
        geaendert: DateTime.utc(2099, 1, 3, 8),
      );
      final b = Ereignis(
        id: 3,
        art: EreignisArt.krankheit,
        von: '2099-01-02',
        bis: '2099-01-05',
        notiz: 'Grippe',
        angelegt: DateTime.utc(2099, 1, 2, 8),
        geaendert: DateTime.utc(2099, 1, 3, 8),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      Ereignis mit({
        int? id = 3,
        EreignisArt art = EreignisArt.krankheit,
        String von = '2099-01-02',
        String bis = '2099-01-05',
        String? notiz = 'Grippe',
        DateTime? angelegt,
        DateTime? geaendert,
      }) => Ereignis(
        id: id,
        art: art,
        von: von,
        bis: bis,
        notiz: notiz,
        angelegt: angelegt ?? DateTime.utc(2099, 1, 2, 8),
        geaendert: geaendert ?? DateTime.utc(2099, 1, 3, 8),
      );

      expect(mit(), a, reason: 'die Hilfe baut denselben Wert');
      expect(mit(id: 4), isNot(a), reason: 'id');
      expect(mit(id: null), isNot(a), reason: 'id null');
      expect(mit(art: EreignisArt.verletzung), isNot(a), reason: 'art');
      expect(mit(von: '2099-01-01'), isNot(a), reason: 'von');
      expect(mit(bis: '2099-01-06'), isNot(a), reason: 'bis');
      expect(mit(notiz: null), isNot(a), reason: 'notiz');
      expect(
        mit(angelegt: DateTime.utc(2099, 1, 2, 9)),
        isNot(a),
        reason: 'angelegt',
      );
      expect(
        mit(geaendert: DateTime.utc(2099, 1, 4, 8)),
        isNot(a),
        reason: 'geaendert',
      );
    });

    test('tage liefert id, Art und Zeitraum als AuszeitTage', () {
      final e = Ereignis(
        id: 7,
        art: EreignisArt.verletzung,
        von: '2099-02-01',
        bis: '2099-02-09',
        notiz: 'Knöchel',
      );
      expect(
        e.tage,
        const AuszeitTage(
          id: 7,
          art: EreignisArt.verletzung,
          von: '2099-02-01',
          bis: '2099-02-09',
        ),
      );
    });

    test('tage wirft ohne id — ein nicht abgelegtes Ereignis hat keine '
        'Nummer, die bei Gleichstand entscheiden könnte (V3)', () {
      expect(() => op.tage, throwsA(anything));
    });
  });

  group('Das Repository', () {
    test('eine leere Tabelle ist eine leere Liste', () async {
      expect(await repo.alle(), isEmpty);
    });

    test('legeAn setzt angelegt aus der Uhr (UTC), lässt geaendert NULL '
        'und gibt die id zurück', () async {
      final id = await repo.legeAn(op);

      final z = (await zeilen()).single;
      expect(z.id, id);
      expect(z.art, 'op');
      expect(z.von, '2099-03-10');
      expect(z.bis, '2099-03-24');
      expect(z.notiz, 'Knie');
      expect(z.angelegt, DateTime.utc(2099, 3, 14, 9, 30));
      expect(z.angelegt.isUtc, isTrue);
      expect(z.geaendert, isNull);

      expect(await repo.alle(), [
        Ereignis(
          id: id,
          art: EreignisArt.op,
          von: '2099-03-10',
          bis: '2099-03-24',
          notiz: 'Knie',
          angelegt: DateTime.utc(2099, 3, 14, 9, 30),
        ),
      ]);
    });

    test('legeAn nimmt die Uhr, nicht die Zeitstempel des übergebenen '
        'Ereignisses', () async {
      final mitAltenStempeln = Ereignis(
        art: EreignisArt.krankheit,
        von: '2099-03-01',
        bis: '2099-03-03',
        angelegt: DateTime.utc(2099, 1, 1),
        geaendert: DateTime.utc(2099, 1, 2),
      );

      await repo.legeAn(mitAltenStempeln);

      final z = (await zeilen()).single;
      expect(z.angelegt, DateTime.utc(2099, 3, 14, 9, 30));
      expect(z.geaendert, isNull, reason: 'Anlegen ist keine Änderung');
    });

    test('eine Uhr in Ortszeit wird als UTC abgelegt', () async {
      final ortszeit = DateTime(2099, 3, 14, 11, 30);
      final lokal = EreignisRepository(db, uhr: () => ortszeit);

      await lokal.legeAn(urlaub);

      final angelegt = (await repo.alle()).single.angelegt!;
      expect(angelegt.isUtc, isTrue);
      expect(angelegt, ortszeit.toUtc());
    });

    test('zwei Ereignisse bekommen verschiedene ids', () async {
      final a = await repo.legeAn(op);
      final b = await repo.legeAn(urlaub);
      expect(b, isNot(a));
      expect({for (final e in await repo.alle()) e.id}, {a, b});
    });

    test('aendere setzt geaendert aus der Uhr und lässt angelegt', () async {
      final id = await repo.legeAn(op);
      jetzt = DateTime.utc(2099, 3, 20, 18, 5);

      await repo.aendere(
        Ereignis(
          id: id,
          art: EreignisArt.op,
          von: '2099-03-10',
          bis: '2099-03-31',
          notiz: 'Knie, länger',
          // Ein abweichendes `angelegt` im Ereignis wird nicht übernommen.
          angelegt: DateTime.utc(2099, 12, 31),
        ),
      );

      final z = (await zeilen()).single;
      expect(z.id, id);
      expect(z.bis, '2099-03-31');
      expect(z.notiz, 'Knie, länger');
      expect(z.angelegt, DateTime.utc(2099, 3, 14, 9, 30));
      expect(z.geaendert, DateTime.utc(2099, 3, 20, 18, 5));
      expect(z.geaendert!.isUtc, isTrue);
    });

    test('aendere schreibt Art und Zeitraum neu und nimmt eine Notiz, die '
        'auf null zurückgeht, mit', () async {
      final id = await repo.legeAn(op);

      await repo.aendere(
        Ereignis(
          id: id,
          art: EreignisArt.krankheit,
          von: '2099-04-01',
          bis: '2099-04-04',
        ),
      );

      final z = (await zeilen()).single;
      expect(z.art, 'krankheit');
      expect(z.von, '2099-04-01');
      expect(z.bis, '2099-04-04');
      expect(z.notiz, isNull, reason: 'null heißt: keine Notiz mehr');
    });

    test('aendere trifft genau die eine Zeile', () async {
      final a = await repo.legeAn(op);
      final b = await repo.legeAn(urlaub);
      jetzt = DateTime.utc(2099, 3, 15, 7);

      await repo.aendere(
        Ereignis(
          id: b,
          art: EreignisArt.urlaub,
          von: '2099-05-02',
          bis: '2099-05-14',
        ),
      );

      final alle = await zeilen();
      final za = alle.singleWhere((z) => z.id == a);
      expect(za.von, '2099-03-10');
      expect(za.notiz, 'Knie');
      expect(za.geaendert, isNull);
      expect(alle.singleWhere((z) => z.id == b).von, '2099-05-02');
    });

    test('loesche nimmt genau die eine Zeile', () async {
      final a = await repo.legeAn(op);
      final b = await repo.legeAn(urlaub);
      final c = await repo.legeAn(
        Ereignis(
          art: EreignisArt.verletzung,
          von: '2099-06-01',
          bis: '2099-06-03',
        ),
      );

      await repo.loesche(b);

      expect([for (final z in await zeilen()) z.id], [a, c]);
    });

    test('alle() sortiert nach von absteigend, dann nach id absteigend '
        '(V8)', () async {
      final frueh = await repo.legeAn(
        Ereignis(
          art: EreignisArt.krankheit,
          von: '2099-01-05',
          bis: '2099-01-08',
        ),
      );
      final spaetErst = await repo.legeAn(
        Ereignis(art: EreignisArt.op, von: '2099-04-01', bis: '2099-04-15'),
      );
      final mitte = await repo.legeAn(
        Ereignis(art: EreignisArt.urlaub, von: '2099-02-10', bis: '2099-02-20'),
      );
      final spaetDann = await repo.legeAn(
        Ereignis(
          art: EreignisArt.verletzung,
          von: '2099-04-01',
          bis: '2099-04-02',
        ),
      );
      // Über einen Jahreswechsel: lexikografisch ist das der Kalender.
      final vorjahr = await repo.legeAn(
        Ereignis(art: EreignisArt.urlaub, von: '2098-12-28', bis: '2099-01-03'),
      );

      expect(
        [for (final e in await repo.alle()) e.id],
        [spaetDann, spaetErst, mitte, frueh, vorjahr],
      );
    });

    test('eine Zeile mit unbekannter Art wird übergangen, ohne zu werfen '
        '(V20)', () async {
      final bekannt = await repo.legeAn(op);
      // So schriebe sie eine spätere Fassung (Spieltag, #389).
      await db
          .into(db.ereignisse)
          .insert(
            EreignisseCompanion.insert(
              art: 'spieltag',
              von: '2099-03-12',
              bis: '2099-03-12',
              angelegt: DateTime.utc(2099, 3, 1),
            ),
          );

      final alle = await repo.alle();
      expect([for (final e in alle) e.id], [bekannt]);
      expect(alle.single.art, EreignisArt.op);
      expect(
        (await zeilen()).length,
        2,
        reason: 'übergangen heißt nicht gelöscht',
      );
    });

    test('eine fehlende Notiz bleibt NULL, nicht leerer Text', () async {
      await repo.legeAn(urlaub);

      expect((await zeilen()).single.notiz, isNull);
      expect((await repo.alle()).single.notiz, isNull);
    });

    test('die Notiz wird geschrieben, wie sie kommt — getrimmt wird im '
        'Formular (V6)', () async {
      await repo.legeAn(
        Ereignis(
          art: EreignisArt.krankheit,
          von: '2099-03-01',
          bis: '2099-03-02',
          notiz: '  Fieber ',
        ),
      );

      expect((await zeilen()).single.notiz, '  Fieber ');
      expect((await repo.alle()).single.notiz, '  Fieber ');
    });
  });

  group('Die Provider', () {
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

    test('ereignisseProvider liest die Ereignisse aus der Tabelle, '
        'sortiert wie alle()', () async {
      await repo.legeAn(op);
      await repo.legeAn(urlaub);
      final c = behaelter();

      expect(await c.read(ereignisseProvider.future), await repo.alle());
    });

    test('ohne Ereignisse: leer, kein Fehler', () async {
      final c = behaelter();
      expect(await c.read(ereignisseProvider.future), isEmpty);
    });

    test(
      'das Repository des Providers nimmt die Uhr aus clockProvider',
      () async {
        final c = behaelter();
        // Über den Provider angelegt, über die Tabelle geprüft.
        await c.read(ereignisRepositoryProvider).legeAn(op);
        expect(
          (await zeilen()).single.angelegt,
          DateTime.utc(2099, 3, 14, 9, 30),
        );
      },
    );

    test(
      'nach legeAn steht die neue Zeile im Zustand, ohne Neustart',
      () async {
        await repo.legeAn(op);
        final c = behaelter();
        final sub = c.listen(ereignisseProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(ereignisseProvider.future);

        await c.read(ereignisseProvider.notifier).legeAn(urlaub);

        final zustand = c.read(ereignisseProvider).value;
        expect(zustand, isNotNull);
        expect(zustand, await repo.alle());
        expect(zustand, hasLength(2));
        expect(
          zustand!.first.art,
          EreignisArt.urlaub,
          reason: 'von absteigend',
        );
      },
    );

    test('nach aendere steht der neue Stand im Zustand', () async {
      final id = await repo.legeAn(op);
      final c = behaelter();
      final sub = c.listen(ereignisseProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(ereignisseProvider.future);
      jetzt = DateTime.utc(2099, 3, 16, 12);

      await c
          .read(ereignisseProvider.notifier)
          .aendere(
            Ereignis(
              id: id,
              art: EreignisArt.op,
              von: '2099-03-10',
              bis: '2099-03-28',
            ),
          );

      final zustand = c.read(ereignisseProvider).value!;
      expect(zustand.single.bis, '2099-03-28');
      expect(zustand.single.geaendert, DateTime.utc(2099, 3, 16, 12));
    });

    test('nach loesche ist die Zeile aus dem Zustand verschwunden', () async {
      final a = await repo.legeAn(op);
      final b = await repo.legeAn(urlaub);
      final c = behaelter();
      final sub = c.listen(ereignisseProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(ereignisseProvider.future);

      await c.read(ereignisseProvider.notifier).loesche(b);

      expect([for (final e in c.read(ereignisseProvider).value!) e.id], [a]);
    });

    test('auszeitenProvider: laden, bis gelesen ist, danach die '
        'AuszeitTage (V12)', () async {
      final idOp = await repo.legeAn(op);
      final idUrlaub = await repo.legeAn(urlaub);
      final c = behaelter();
      final sub = c.listen(auszeitenProvider, (_, _) {});
      addTearDown(sub.close);

      final vorher = c.read(auszeitenProvider);
      expect(vorher.laden, isTrue);
      expect(vorher.auszeiten, isEmpty);

      await c.read(ereignisseProvider.future);
      final nachher = c.read(auszeitenProvider);
      expect(nachher.laden, isFalse);
      expect(nachher.auszeiten, [
        AuszeitTage(
          id: idUrlaub,
          art: EreignisArt.urlaub,
          von: '2099-05-01',
          bis: '2099-05-14',
        ),
        AuszeitTage(
          id: idOp,
          art: EreignisArt.op,
          von: '2099-03-10',
          bis: '2099-03-24',
        ),
      ]);
    });

    test(
      'auszeitenProvider: ohne Ereignisse nicht laden, leere Liste',
      () async {
        final c = behaelter();
        final sub = c.listen(auszeitenProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(ereignisseProvider.future);

        final stand = c.read(auszeitenProvider);
        expect(stand.laden, isFalse);
        expect(stand.auszeiten, isEmpty);
      },
    );

    test('auszeitenProvider: scheitert das Lesen, nicht laden und eine leere '
        'Liste — gerechnet wird dann ohne Pause (V12)', () async {
      // Erst öffnen (legt die Tabellen an), dann die Tabelle wegnehmen.
      await repo.alle();
      await db.customStatement('DROP TABLE ereignisse;');
      final c = behaelter();
      final sub = c.listen(auszeitenProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(c.read(ereignisseProvider.future), throwsA(anything));

      final stand = c.read(auszeitenProvider);
      expect(stand.laden, isFalse, reason: 'ein Fehler lädt nicht für immer');
      expect(stand.auszeiten, isEmpty);
    });

    test('auszeitenProvider folgt legeAn, ohne Neustart', () async {
      final c = behaelter();
      final sub = c.listen(auszeitenProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(ereignisseProvider.future);
      expect(c.read(auszeitenProvider).auszeiten, isEmpty);

      await c.read(ereignisseProvider.notifier).legeAn(op);

      final stand = c.read(auszeitenProvider);
      expect(stand.laden, isFalse);
      expect(stand.auszeiten, hasLength(1));
      expect(stand.auszeiten.single.art, EreignisArt.op);
      expect(stand.auszeiten.single.von, '2099-03-10');
      expect(stand.auszeiten.single.bis, '2099-03-24');
    });

    test('auszeitenProvider meldet sich nicht, wenn sich an den Tagen '
        'nichts ändert (Hausregel 2)', () async {
      final id = await repo.legeAn(op);
      final c = behaelter();
      final meldungen = <({bool laden, List<AuszeitTage> auszeiten})>[];
      final sub = c.listen(auszeitenProvider, (_, neu) => meldungen.add(neu));
      addTearDown(sub.close);
      await c.read(ereignisseProvider.future);
      final gelesen = c.read(auszeitenProvider);
      expect(gelesen.laden, isFalse);
      meldungen.clear();

      // Nur die Notiz ändert sich — Art, Zeitraum und id bleiben.
      await c
          .read(ereignisseProvider.notifier)
          .aendere(
            Ereignis(
              id: id,
              art: EreignisArt.op,
              von: '2099-03-10',
              bis: '2099-03-24',
              notiz: 'nur eine andere Notiz',
            ),
          );
      expect(
        c.read(ereignisseProvider).value!.single.notiz,
        'nur eine andere Notiz',
        reason: 'der Notifier hat neu gelesen',
      );

      expect(meldungen, isEmpty);
      expect(c.read(auszeitenProvider), gelesen);
    });
  });
}
