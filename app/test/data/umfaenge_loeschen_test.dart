import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';

/// Tests für das **Löschen von Umfängen** (#486 unter #88) —
/// `lib/data/umfaenge_repository.dart`, die zwei neuen Methoden. Schreiben,
/// Lesen und Zusammenführen prüft `umfaenge_repository_test.dart`; dort
/// steht ausdrücklich „Löschen: weder Plan noch Spec kennen es" — seit #486
/// kennt es das Board, und diese Datei trägt den Vertrag.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden — keine Zeile,
/// kein Erwartungswert, kein Testname.
///
/// ## Woher die Anforderung kommt
///
/// Issue #486 („Fertig, wenn"): Ein falsch eingetragener Wert verschwindet
/// so, dass er **in keinem Verlauf und keiner Veränderung mehr auftaucht** —
/// und das Löschen eines Maßes lässt die übrigen Maße desselben Tages
/// stehen. Entwurf: `docs/screens/screens/umfaenge.js` (Messtag) und
/// `docs/screens/screens/umfang-detail.js` (einzelnes Maß), Commit
/// `ac84126`.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// ```dart
/// /// Löscht **ein** Maß eines Tages — über alle Quellen.
/// Future<void> loescheMass({required String tag, required Umfang mass});
///
/// /// Löscht einen **ganzen Messtag** — über alle Quellen.
/// Future<void> loescheMesstag(String tag);
/// ```
///
/// ## Die eine Festlegung, die zählt: **alle Quellen**
///
/// Die Quelle steht im Primärschlüssel (`{tag, mass, quelle}`), und
/// zusammengeführt wird beim Lesen: getippt schlägt importiert. Löschte man
/// nur die getippte Zeile, käme die importierte darunter **wieder hervor** —
/// der gelöschte Wert stünde am nächsten Bild erneut im Verlauf. Genau das
/// verbietet das „Fertig, wenn": Löschen trifft **jede** Zeile des
/// Tags/Maßes, gleich welcher Quelle.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099 —
/// echte Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  // Drei Tage in dieser Reihenfolge: tagA ist der älteste.
  const tagA = '2099-04-02';
  const tagB = '2099-04-16';
  const tagC = '2099-04-30';

  final jetzt = DateTime.utc(2099, 4, 30, 18, 3, 27);

  AppCache frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  UmfaengeRepository repoVon(AppCache db) =>
      UmfaengeRepository(db, uhr: () => jetzt);

  /// Legt eine Zeile unmittelbar in der Tabelle ab — am Repository vorbei,
  /// wie ein Importlauf oder eine frühere Sitzung es getan hätte.
  Future<void> legeZeile(
    AppCache db, {
    required String tag,
    required Umfang mass,
    required double zentimeter,
    required String quelle,
  }) => db
      .into(db.umfaenge)
      .insert(
        UmfaengeCompanion.insert(
          tag: tag,
          mass: mass.schluessel,
          zentimeter: zentimeter,
          eingetragenAm: jetzt,
          quelle: quelle,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Alle Zeilen roh, ohne den Weg über das Repository: Was hier steht, ist
  /// das, was wirklich in der Datei liegt.
  Future<List<Map<String, Object?>>> rohZeilen(AppCache db) async => [
    for (final zeile
        in await db
            .customSelect('SELECT * FROM umfaenge ORDER BY tag, mass, quelle;')
            .get())
      zeile.data,
  ];

  group('loescheMass löscht ein Maß eines Tages', () {
    test('das Maß verschwindet, die übrigen Maße des Tages bleiben', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagB,
        werte: {
          Umfang.brust: 103.5,
          Umfang.taille: 84.0,
          Umfang.hals: 39.5,
        },
      );

      await repo.loescheMass(tag: tagB, mass: Umfang.brust);

      final messung = await repo.messungAm(tagB);
      expect(
        messung,
        isNotNull,
        reason:
            'Der Tag trägt noch zwei Maße — er verschwindet nicht mit '
            '(#486, „Fertig, wenn").',
      );
      expect(
        messung!.werte.containsKey(Umfang.brust),
        isFalse,
        reason: 'Das gelöschte Maß taucht nicht mehr auf.',
      );
      expect(
        messung.werte,
        {Umfang.taille: 84.0, Umfang.hals: 39.5},
        reason: 'Die übrigen Maße desselben Tages bleiben unberührt stehen.',
      );
    });

    test('es trifft alle Quellen — ein importierter Wert desselben Maßes '
        'kommt nicht wieder hervor', () async {
      final db = frisch();
      final repo = repoVon(db);
      // Importzeile unter der getippten: getippt gewinnt beim Lesen. Löschte
      // man nur die getippte, stünde 101,0 wieder im Verlauf.
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 101.0,
        quelle: 'import',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 103.5,
        quelle: 'getippt',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 84.0,
        quelle: 'import',
      );

      await repo.loescheMass(tag: tagB, mass: Umfang.brust);

      final messung = await repo.messungAm(tagB);
      expect(
        messung?.werte,
        {Umfang.taille: 84.0},
        reason:
            'Weder 103,5 (getippt) noch 101,0 (import) dürfen noch '
            'auftauchen — sonst käme der gelöschte Wert beim nächsten '
            'Lesen unter der getippten Zeile wieder hervor.',
      );
      final zeilen = await rohZeilen(db);
      expect(
        zeilen,
        hasLength(1),
        reason: 'Auch in der Tabelle liegt keine Brust-Zeile mehr.',
      );
      expect(zeilen.single['mass'], Umfang.taille.schluessel);
    });

    test('war es das letzte Maß des Tages, verschwindet der Tag mit',
        () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.brust: 103.5});

      await repo.loescheMass(tag: tagB, mass: Umfang.brust);

      expect(
        await repo.messungAm(tagB),
        isNull,
        reason:
            'Ein Tag ohne Maße ist kein Messtag mehr (Entwurf '
            '`umfang-detail.js`: „War es das letzte Maß des Tages, '
            'verschwindet der Tag auch dort aus Alle Messungen").',
      );
      expect(
        await repo.letzterMesstag(),
        tagA,
        reason: 'Der jüngste Messtag ist jetzt der ältere.',
      );
    });

    test('andere Tage desselben Maßes bleiben stehen', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.brust: 112.3});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.brust: 103.5});

      // Der Vertipper in der Mitte (112,3 statt 102,3, Entwurf).
      await repo.loescheMass(tag: tagB, mass: Umfang.brust);

      final messungen = await repo.messungen();
      expect(messungen, hasLength(2));
      expect(
        [for (final m in messungen) m.werte[Umfang.brust]],
        [103.5, 101.0],
        reason:
            'Nur der Punkt des gelöschten Tages fehlt; die Reihe davor und '
            'danach bleibt — absteigend, die jüngste zuerst.',
      );
    });

    test('nach dem Löschen steht der Wert auch nicht mehr als Vorwert da',
        () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.brust: 112.3});

      await repo.loescheMass(tag: tagB, mass: Umfang.brust);

      final vorwerte = await repo.werteVomLetztenMal(vorTag: tagC);
      expect(
        vorwerte[Umfang.brust],
        101.0,
        reason:
            'Der Platzhalter des Formulars zeigt den Stand **ohne** den '
            'gelöschten Wert — „in keinem Verlauf und keiner Veränderung" '
            'schließt die Vorwerte ein (#486).',
      );
    });
  });

  group('loescheMesstag löscht einen ganzen Tag', () {
    test('alle Maße des Tages verschwinden, andere Tage bleiben', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagA,
        werte: {Umfang.brust: 101.0, Umfang.taille: 86.0},
      );
      await repo.schreibeGetippt(
        tag: tagB,
        werte: {Umfang.brust: 103.5, Umfang.taille: 84.0, Umfang.hals: 39.5},
      );

      await repo.loescheMesstag(tagB);

      expect(await repo.messungAm(tagB), isNull);
      final uebrig = await repo.messungen();
      expect(uebrig, hasLength(1));
      expect(
        uebrig.single.werte,
        {Umfang.brust: 101.0, Umfang.taille: 86.0},
        reason: 'Der andere Tag bleibt vollständig stehen.',
      );
    });

    test('es trifft alle Quellen — auch die importierten Zeilen des Tages',
        () async {
      final db = frisch();
      final repo = repoVon(db);
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 101.0,
        quelle: 'import',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 103.5,
        quelle: 'getippt',
      );
      await legeZeile(
        db,
        tag: tagA,
        mass: Umfang.brust,
        zentimeter: 100.8,
        quelle: 'import',
      );

      await repo.loescheMesstag(tagB);

      final zeilen = await rohZeilen(db);
      expect(
        zeilen,
        hasLength(1),
        reason:
            'Vom gelöschten Tag bleibt keine Zeile, gleich welcher Quelle — '
            'sonst käme der importierte Wert wieder hervor (#486).',
      );
      expect(zeilen.single['tag'], tagA);
    });

    test('der letzte Messtag gelöscht heißt: leer', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagC,
        werte: {Umfang.brust: 103.5, Umfang.taille: 84.0},
      );

      await repo.loescheMesstag(tagC);

      expect(await repo.messungen(), isEmpty);
      expect(
        await repo.letzterMesstag(),
        isNull,
        reason:
            'Danach gilt der bestehende Leerzustand — „Noch nichts '
            'erfasst", kein eigener Zustand fürs Löschen (Entwurf).',
      );
    });

    test('ein Tag, den es nicht gibt, ist kein Fehler und nimmt nichts mit',
        () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});

      await repo.loescheMesstag(tagB);

      expect(
        await repo.messungen(),
        hasLength(1),
        reason: 'Löschen ohne Treffer lässt den Bestand unberührt.',
      );
    });
  });
}
