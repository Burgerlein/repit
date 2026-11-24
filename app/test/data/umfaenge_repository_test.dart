import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';

/// Tests für die **Ablage der Umfänge** (#477 unter #88, Scheibe 2) —
/// `lib/data/umfaenge_repository.dart`. Die Tabelle selbst und ihre
/// Migration prüft `schema_v24_test.dart`; die Rechnungen darunter
/// (`Umfang`, `UmfangsEingabe`, `UmfangsMerge`) liegen im Kern und sind
/// dort geprüft.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden — keine Zeile,
/// kein Erwartungswert, kein Testname. Hält der Implementierende einen Fall
/// für falsch, **meldet** er ihn, statt ihn passend zu machen.
///
/// ## Woher die Anforderung kommt
///
/// `docs/SPEC.md` 4.6 („Eine zweite Eingabe am selben Tag ändert die erste.
/// Eingetippte Werte schlagen importierte, maßweise.") und
/// `docs/superpowers/plans/2026-11-11-umfaenge.md`, Task 2.1. Die
/// Spaltenbedeutung steht am Tabellentyp `Umfaenge` in
/// `lib/data/tables.dart`.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/data/umfaenge_repository.dart`, derselbe Schnitt wie bei
/// `WasserRepository` und `EreignisRepository`: SQL hier, Riverpod nebenan.
///
/// ```dart
/// class UmfaengeRepository {
///   /// [uhr] liefert den Zeitpunkt für `eingetragen_am`; ohne sie die
///   /// Uhr des Geräts.
///   UmfaengeRepository(AppCache db, {DateTime Function()? uhr});
///
///   /// Alle zusammengeführten Messungen, **absteigend nach Tag** — die
///   /// jüngste zuerst. [abTag] und [bisTag] sind ISO-Tagesstrings und
///   /// beide **einschließlich**; gefiltert wird in SQL.
///   Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag});
///
///   /// Die zusammengeführte Messung eines Tages, oder `null`, wenn es für
///   /// ihn keine einzige Zeile gibt.
///   Future<Umfangsmessung?> messungAm(String tag);
///
///   /// Schreibt die getippten Werte eines Tages — je **gefülltem** Maß
///   /// eine Zeile mit `quelle = 'getippt'`.
///   Future<void> schreibeGetippt({
///     required String tag,
///     required Map<Umfang, double> werte,
///   });
///
///   /// Die Platzhalter des Formulars: je Maß der Wert der jüngsten
///   /// Messung **vor** [vorTag], die dieses Maß enthält.
///   Future<Map<Umfang, double>> werteVomLetztenMal({required String vorTag});
///
///   /// Der Tag der jüngsten Messung als ISO-Tagesstring, oder `null`.
///   Future<String?> letzterMesstag();
/// }
///
/// final umfaengeRepositoryProvider = Provider<UmfaengeRepository>(…);
/// ```
///
/// Der Provider steht hier nur der Vollständigkeit halber; geprüft wird er
/// in `test/shell/umfaenge_eintragen_test.dart`, wo ein hängendes
/// Repository den Ladezustand erzwingt.
///
/// ## Die zwei Festlegungen, die der Plan offen lässt
///
/// ### 1. „Die Werte vom letzten Mal" sind **je Maß** gesucht
///
/// Nicht die Werte der jüngsten Messung als Block, sondern je Maß der Wert
/// der **jüngsten Messung, die dieses Maß enthält** — die Werte eines
/// Formularaufrufs dürfen also aus verschiedenen Tagen stammen.
///
/// Der Grund: Leere Felder werden nicht gespeichert (SPEC 4.6). Wer abends
/// nur die Taille nachträgt, legt damit eine Messung an, die **ein** Maß
/// trägt. Nähme der Platzhalter die jüngste Messung als Block, stünden beim
/// nächsten Messen vierzehn Felder ohne Vorwert da — genau dann, wenn man
/// sie braucht. Dieselbe Begründung, die `UmfangsMerge` maßweise statt
/// eintragsweise zusammenführen lässt.
///
/// Dasselbe tut die eingefrorene Swift-App, und sie ist hier der Maßstab:
/// `CircumferenceEntryView.swift:100-107` nimmt
/// `earlier.reversed().compactMap { $0.values[measure] }.first`.
///
/// **Und zwar vor dem gewählten Tag, nicht vor heute.** Wer rückdatiert,
/// will den Stand sehen, der damals galt; und wer einen Tag erneut öffnet,
/// an dem schon gemessen wurde, bekäme sonst die eigenen Werte als
/// Platzhalter gespiegelt und hielte sie für die vom letzten Mal. Auch das
/// steht so in der Swift-Fassung (`$0.date < today`).
///
/// ### 2. Schreiben **ergänzt maßweise**, es ersetzt den Tag nicht
///
/// `schreibeGetippt` legt je gefülltem Maß eine Zeile an und ändert eine
/// gleichnamige; ein Maß, das in [werte] **fehlt**, bleibt unberührt
/// stehen. Ein leeres Feld ist damit ein „nichts dazu zu sagen", kein
/// Löschbefehl.
///
/// Das folgt dem Kern: `UmfangsMerge` führt ausdrücklich maßweise zusammen,
/// „wer abends nur die Taille nachträgt, löscht damit nicht Hals und Brust
/// vom Morgen". **Die Swift-App macht es anders** (`save()` ersetzt den
/// Tageseintrag ganz, nachdem `loadDay()` die Felder vorbelegt hat) — diese
/// Abweichung ist bewusst und im Bericht gemeldet: Ein Formular, dessen
/// leere Felder löschen, verliert Tims Werte lautlos, und zwar genau dann,
/// wenn er nur eine Zahl korrigieren wollte. Fehlt deshalb später das
/// Löschen eines einzelnen Maßes, ist das ein eigenes Ticket und kein
/// stiller Datenverlust.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Wie Importzeilen entstehen.** Den Importlauf gibt es im Neubau noch
///   nicht; die Zeilen mit `quelle = 'import'` legt diese Datei deshalb
///   unmittelbar in der Tabelle ab, wie ein späterer Lauf es täte. Eine
///   Schreibmethode dafür zu verlangen hieße, eine API festzulegen, die
///   niemand aufruft.
/// - **Löschen.** Weder Plan noch Spec kennen es für Umfänge.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099 —
/// echte Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  // Drei Tage in dieser Reihenfolge: tagA ist der älteste.
  const tagA = '2099-03-01';
  const tagB = '2099-03-15';
  const tagC = '2099-03-29';

  /// Ein Zeitpunkt, an dem die App gelaufen ist — für `eingetragen_am`.
  final jetzt = DateTime.utc(2099, 3, 29, 17, 42, 11);

  AppCache frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  UmfaengeRepository repoVon(AppCache db, {DateTime? uhr}) =>
      UmfaengeRepository(db, uhr: () => uhr ?? jetzt);

  /// Legt eine Zeile unmittelbar in der Tabelle ab — am Repository vorbei,
  /// wie ein Importlauf oder eine frühere Sitzung es getan hätte.
  Future<void> legeRohZeile(
    AppCache db, {
    required String tag,
    required String mass,
    required double zentimeter,
    required String quelle,
    DateTime? eingetragenAm,
  }) => db
      .into(db.umfaenge)
      .insert(
        UmfaengeCompanion.insert(
          tag: tag,
          mass: mass,
          zentimeter: zentimeter,
          eingetragenAm: eingetragenAm ?? jetzt,
          quelle: quelle,
        ),
        mode: InsertMode.insertOrReplace,
      );

  Future<void> legeZeile(
    AppCache db, {
    required String tag,
    required Umfang mass,
    required double zentimeter,
    required String quelle,
    DateTime? eingetragenAm,
  }) => legeRohZeile(
    db,
    tag: tag,
    mass: mass.schluessel,
    zentimeter: zentimeter,
    quelle: quelle,
    eingetragenAm: eingetragenAm,
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

  /// Die Tagesschlüssel einer gelesenen Liste, in ihrer Reihenfolge.
  List<String> tageVon(List<Umfangsmessung> messungen) => [
    for (final messung in messungen) BerlinCalendar.dayKey(messung.zeitpunkt),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Schreiben
  // ───────────────────────────────────────────────────────────────────────

  group('Schreiben legt je gefülltem Maß genau eine Zeile an', () {
    test('drei Maße werden drei Zeilen mit quelle = getippt', () async {
      final db = frisch();
      await repoVon(db).schreibeGetippt(
        tag: tagB,
        werte: {
          Umfang.brust: 103.5,
          Umfang.taille: 84.0,
          Umfang.oberarmRechtsAngespannt: 38.2,
        },
      );

      final zeilen = await rohZeilen(db);
      expect(zeilen, hasLength(3));
      for (final zeile in zeilen) {
        expect(zeile['tag'], tagB);
        expect(
          zeile['quelle'],
          'getippt',
          reason:
              'Was von Hand eingetragen wird, trägt `getippt` — nur so kann '
              'das Zusammenführen beim Lesen entscheiden (Kopf von '
              '`umfangs_merge.dart`)',
        );
      }
      expect(
        {for (final zeile in zeilen) zeile['mass']},
        {
          Umfang.brust.schluessel,
          Umfang.taille.schluessel,
          Umfang.oberarmRechtsAngespannt.schluessel,
        },
        reason: 'abgelegt wird der stabile Schlüssel, nicht der Dart-Name',
      );
    });

    test('ein Maß, das nicht in der Karte steht, bekommt keine Zeile — kein '
        'NULL, keine Null', () async {
      final db = frisch();
      await repoVon(db).schreibeGetippt(
        tag: tagB,
        werte: {Umfang.taille: 84.0},
      );

      final zeilen = await rohZeilen(db);
      expect(
        zeilen,
        hasLength(1),
        reason:
            'Vierzehn leere Felder sind vierzehn fehlende Zeilen. `0` '
            'behauptete einen gemessenen Umfang von null Zentimetern '
            '(`CLAUDE.md`)',
      );
      expect(zeilen.single['mass'], Umfang.taille.schluessel);
    });

    test('eine leere Karte schreibt gar nichts', () async {
      final db = frisch();
      await repoVon(db).schreibeGetippt(tag: tagB, werte: const {});

      expect(await rohZeilen(db), isEmpty);
    });

    test('der Zentimeterwert wird nicht gerundet', () async {
      final db = frisch();
      await repoVon(db).schreibeGetippt(
        tag: tagB,
        werte: {Umfang.wadeLinks: 37.8},
      );

      expect(
        (await rohZeilen(db)).single['zentimeter'],
        37.8,
        reason:
            'Die Totzone des Fortschritts rechnet mit 0,2 cm — sie kann '
            'nichts entscheiden, wenn die Ablage rundet',
      );
    });

    test('eingetragen_am kommt aus der Uhr der App und ist UTC', () async {
      final db = frisch();
      final uhr = DateTime.utc(2099, 3, 15, 6, 30);
      await repoVon(
        db,
        uhr: uhr,
      ).schreibeGetippt(tag: tagB, werte: {Umfang.hals: 39.5});

      final zeile = await db
          .customSelect('SELECT eingetragen_am FROM umfaenge;')
          .getSingle();
      final gelesen = zeile.read<DateTime>('eingetragen_am');
      expect(gelesen, uhr);
      expect(
        gelesen.isUtc,
        isTrue,
        reason:
            'Zeitstempel liegen als Text in der Datenbank; ein als '
            'Ortszeit zurückgelesener Wert wäre ungleich sich selbst '
            '(`CLAUDE.md`)',
      );
    });

    test('überlebt einen Neustart', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = AppCache(
        NativeDatabase.opened(roh, closeUnderlyingOnClose: false),
      );
      await UmfaengeRepository(
        erstes,
        uhr: () => jetzt,
      ).schreibeGetippt(tag: tagB, werte: {Umfang.brust: 103.5});
      await erstes.close();

      final zweites = AppCache(
        NativeDatabase.opened(roh, closeUnderlyingOnClose: false),
      );
      addTearDown(zweites.close);

      final messung = await UmfaengeRepository(zweites).messungAm(tagB);
      expect(messung?.werte[Umfang.brust], 103.5);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Eine zweite Eingabe am selben Tag (SPEC 4.6)
  // ───────────────────────────────────────────────────────────────────────

  group('Eine zweite Eingabe am selben Tag ändert die erste', () {
    test('dasselbe Maß bleibt eine Zeile und trägt den neuen Wert', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 83.5});

      final zeilen = await rohZeilen(db);
      expect(
        zeilen,
        hasLength(1),
        reason:
            'SPEC 4.6: „Eine zweite Eingabe am selben Tag ändert die '
            'erste" — zwei Zeilen wären zwei Antworten auf dieselbe Frage',
      );
      expect(zeilen.single['zentimeter'], 83.5);
    });

    test('und der Zeitstempel zieht mit', () async {
      final db = frisch();
      final frueh = DateTime.utc(2099, 3, 15, 7);
      final spaet = DateTime.utc(2099, 3, 15, 21, 5);

      await repoVon(
        db,
        uhr: frueh,
      ).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});
      await repoVon(
        db,
        uhr: spaet,
      ).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 83.5});

      final zeile = await db
          .customSelect('SELECT eingetragen_am FROM umfaenge;')
          .getSingle();
      expect(
        zeile.read<DateTime>('eingetragen_am'),
        spaet,
        reason:
            'Eine geänderte Zeile ist frisch eingetragen; der alte '
            'Zeitstempel behauptete, der neue Wert stünde schon seit '
            'morgens da',
      );
    });

    test('ein Maß, das beim zweiten Mal fehlt, bleibt stehen', () async {
      // Siehe „Festlegung 2" im Dateikopf: Ein leeres Feld sagt nichts, es
      // löscht nicht.
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagB,
        werte: {Umfang.brust: 103.5, Umfang.hals: 39.5},
      );
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      final messung = await repo.messungAm(tagB);
      expect(messung!.werte, {
        Umfang.brust: 103.5,
        Umfang.hals: 39.5,
        Umfang.taille: 84.0,
      });
    });

    test('ein anderer Tag bleibt ein anderer Tag', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(await rohZeilen(db), hasLength(2));
      expect((await repo.messungAm(tagA))!.werte[Umfang.taille], 85.0);
      expect((await repo.messungAm(tagB))!.werte[Umfang.taille], 84.0);
    });

    test('und die importierte Zeile desselben Maßes bleibt daneben '
        'liegen', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 86.0,
        quelle: 'import',
      );
      await repoVon(db).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(
        await rohZeilen(db),
        hasLength(2),
        reason:
            'Die Quelle steht im Primärschlüssel: Zusammengeführt wird '
            'beim **Lesen**, nicht beim Schreiben — sonst hätte '
            '`UmfangsMerge` nichts mehr zu entscheiden',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Lesen
  // ───────────────────────────────────────────────────────────────────────

  group('Lesen gibt zusammengeführte Messungen, absteigend nach Tag', () {
    test('ohne eine einzige Zeile ist die Liste leer, nicht null', () async {
      final db = frisch();
      expect(await repoVon(db).messungen(), isEmpty);
      expect(await repoVon(db).messungAm(tagB), isNull);
      expect(await repoVon(db).letzterMesstag(), isNull);
    });

    test('die jüngste Messung steht vorn', () async {
      final db = frisch();
      final repo = repoVon(db);
      // Bewusst in ungeordneter Folge geschrieben.
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.taille: 83.5});

      expect(
        tageVon(await repo.messungen()),
        [tagC, tagB, tagA],
        reason:
            'Der Schirm zeigt die jüngste Messung oben; nach dem Laden in '
            'Dart zu sortieren wäre Arbeit je Zugriff (Hausregel 2)',
      );
    });

    test('der Zeitpunkt ist der Berliner Tagesbeginn in UTC', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.brust: 103.5});

      final messung = (await repo.messungen()).single;
      expect(messung.zeitpunkt.isUtc, isTrue);
      expect(messung.zeitpunkt, BerlinCalendar.startOfDay(messung.zeitpunkt));
      expect(BerlinCalendar.dayKey(messung.zeitpunkt), tagB);
    });

    test('ein Tag ohne eine einzige Zeile taucht nicht als leere Messung '
        'auf', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.taille: 83.5});

      expect(tageVon(await repo.messungen()), [tagC, tagA]);
    });

    test('messungAm gibt genau diesen Tag', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.brust: 103.5});

      expect((await repo.messungAm(tagA))!.werte, {Umfang.brust: 101.0});
      expect(await repo.messungAm(tagC), isNull);
    });

    test('letzterMesstag ist der Tag der jüngsten Messung', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.brust: 101.0});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.wadeRechts: 38.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.hals: 39.5});

      expect(await repo.letzterMesstag(), tagC);
    });

    test('eine fremde Zeile mit unbekanntem Maß bricht das Lesen nicht '
        'ab', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 103.5,
        quelle: 'import',
      );
      await legeRohZeile(
        db,
        tag: tagB,
        mass: 'kleinerZeh',
        zentimeter: 9.0,
        quelle: 'import',
      );

      final messung = await repoVon(db).messungAm(tagB);
      expect(
        messung!.werte,
        {Umfang.brust: 103.5},
        reason:
            '`Umfang.vonSchluessel` gibt bei einem unbekannten Schlüssel '
            '`null` und keine Ausnahme — eine ältere Importdatei darf das '
            'Lesen nicht abbrechen',
      );
    });
  });

  group('Getippt schlägt importiert, und zwar maßweise', () {
    test('dasselbe Maß an demselben Tag: der getippte Wert gilt', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 86.0,
        quelle: 'import',
      );
      await repoVon(db).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect((await repoVon(db).messungAm(tagB))!.werte[Umfang.taille], 84.0);
    });

    test('und die übrigen importierten Maße desselben Tages bleiben '
        'stehen', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 86.0,
        quelle: 'import',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.brust,
        zentimeter: 103.5,
        quelle: 'import',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.hals,
        zentimeter: 39.5,
        quelle: 'import',
      );
      await repoVon(db).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect((await repoVon(db).messungAm(tagB))!.werte, {
        Umfang.taille: 84.0,
        Umfang.brust: 103.5,
        Umfang.hals: 39.5,
      }, reason: 'SPEC 4.6: „Eingetippte Werte schlagen importierte, maßweise"');
    });

    test('entschieden wird nach der Quelle, nicht nach dem Zeitstempel', () async {
      // Der Import trägt die Uhrzeit des Exportlaufs, und die sagt nichts
      // darüber, wann gemessen wurde (Kopf von `umfangs_merge.dart`).
      final db = frisch();
      await repoVon(
        db,
        uhr: DateTime.utc(2099, 3, 15, 7),
      ).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 86.0,
        quelle: 'import',
        eingetragenAm: DateTime.utc(2099, 3, 15, 23, 55),
      );

      expect((await repoVon(db).messungAm(tagB))!.werte[Umfang.taille], 84.0);
    });

    test('ein Tag, den nur der Import kennt, ist trotzdem eine Messung', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagA,
        mass: Umfang.brust,
        zentimeter: 101.0,
        quelle: 'import',
      );
      await repoVon(db).schreibeGetippt(tag: tagC, werte: {Umfang.brust: 103.5});

      expect(tageVon(await repoVon(db).messungen()), [tagC, tagA]);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Gefiltert wird in SQL
  // ───────────────────────────────────────────────────────────────────────

  group('Gefiltert wird in SQL über den ISO-Tagesstring', () {
    Future<void> dreiTage(UmfaengeRepository repo) async {
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.taille: 83.5});
    }

    test('abTag schneidet unten ab, einschließlich', () async {
      final db = frisch();
      final repo = repoVon(db);
      await dreiTage(repo);

      expect(tageVon(await repo.messungen(abTag: tagB)), [tagC, tagB]);
    });

    test('bisTag schneidet oben ab, einschließlich', () async {
      final db = frisch();
      final repo = repoVon(db);
      await dreiTage(repo);

      expect(tageVon(await repo.messungen(bisTag: tagB)), [tagB, tagA]);
    });

    test('beide zusammen ergeben ein Fenster', () async {
      final db = frisch();
      final repo = repoVon(db);
      await dreiTage(repo);

      expect(tageVon(await repo.messungen(abTag: tagB, bisTag: tagB)), [tagB]);
    });

    test('lesen ist lesen — eine Abfrage nimmt keine Zeile weg', () async {
      final db = frisch();
      final repo = repoVon(db);
      await dreiTage(repo);

      await repo.messungen(abTag: tagC);
      expect(await rohZeilen(db), hasLength(3));
    });

    test('und die Abfrage gegen umfaenge trägt den Tagesschlüssel bei '
        'sich', () async {
      final mitschrift = _Mitschrift();
      final db = AppCache(NativeDatabase.memory().interceptWith(mitschrift));
      addTearDown(db.close);
      final repo = UmfaengeRepository(db, uhr: () => jetzt);
      await dreiTage(repo);

      mitschrift.gelesen.clear();
      expect(tageVon(await repo.messungen(abTag: tagB)), [tagC, tagB]);

      final gegenUmfaenge = mitschrift.gelesen
          .where((abfrage) => abfrage.sql.contains('umfaenge'))
          .toList();

      expect(
        gegenUmfaenge,
        isNotEmpty,
        reason:
            'Vorbedingung: Die Mitschrift hat die Abfrage überhaupt '
            'gesehen. Sieht sie keine, prüft der Fall darunter nichts',
      );

      for (final abfrage in gegenUmfaenge) {
        expect(
          abfrage.args.contains(tagB) || abfrage.sql.contains(tagB),
          isTrue,
          reason:
              'gefiltert wird in SQL (`WHERE tag >= ?`), nicht nach dem '
              'Laden in Dart. Eine Abfrage ohne den Tagesschlüssel holt '
              'jede jemals gemessene Zeile in den Speicher und wirft sie '
              'wieder weg — das wächst mit jedem Jahr, das Tim misst, und '
              'ist Fehler 03 in der Datenschicht. Gefunden: ${abfrage.sql}',
        );
      }
    });

    test('messungAm fragt ebenfalls mit dem Tag in SQL', () async {
      final mitschrift = _Mitschrift();
      final db = AppCache(NativeDatabase.memory().interceptWith(mitschrift));
      addTearDown(db.close);
      final repo = UmfaengeRepository(db, uhr: () => jetzt);
      await dreiTage(repo);

      mitschrift.gelesen.clear();
      expect((await repo.messungAm(tagB))!.werte[Umfang.taille], 84.0);

      final gegenUmfaenge = mitschrift.gelesen
          .where((abfrage) => abfrage.sql.contains('umfaenge'))
          .toList();
      expect(gegenUmfaenge, isNotEmpty, reason: 'Vorbedingung, siehe oben');

      for (final abfrage in gegenUmfaenge) {
        expect(
          abfrage.args.contains(tagB) || abfrage.sql.contains(tagB),
          isTrue,
          reason:
              'Ein einzelner Tag ist eine `WHERE tag = ?`-Abfrage, kein '
              'Durchsuchen aller Messungen. Gefunden: ${abfrage.sql}',
        );
      }
    });

    test('der Tagesschlüssel vergleicht lexikografisch über den '
        'Monatswechsel', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: '2099-02-28', werte: {Umfang.hals: 39.0});
      await repo.schreibeGetippt(tag: '2099-03-01', werte: {Umfang.hals: 39.5});
      await repo.schreibeGetippt(tag: '2099-12-31', werte: {Umfang.hals: 40.0});

      expect(tageVon(await repo.messungen(abTag: '2099-03-01')), [
        '2099-12-31',
        '2099-03-01',
      ]);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Werte vom letzten Mal — die Platzhalter des Formulars
  // ───────────────────────────────────────────────────────────────────────

  group('Die Werte vom letzten Mal, je Maß', () {
    test('ohne eine einzige Messung ist die Karte leer', () async {
      final db = frisch();
      expect(await repoVon(db).werteVomLetztenMal(vorTag: tagC), isEmpty);
    });

    test('je Maß der Wert der jüngsten Messung, die es enthält — auch aus '
        'verschiedenen Tagen', () async {
      // Siehe „Festlegung 1" im Dateikopf. Am tagB wurde nur die Taille
      // nachgetragen; Brust und Hals stammen deshalb weiter von tagA.
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagA,
        werte: {Umfang.brust: 101.0, Umfang.hals: 39.0, Umfang.taille: 85.0},
      );
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(await repo.werteVomLetztenMal(vorTag: tagC), {
        Umfang.brust: 101.0,
        Umfang.hals: 39.0,
        Umfang.taille: 84.0,
      });
    });

    test('der gewählte Tag selbst zählt nicht mit', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(
        await repo.werteVomLetztenMal(vorTag: tagB),
        {Umfang.taille: 85.0},
        reason:
            'Wer einen Tag erneut öffnet, bekäme sonst die eigenen Werte '
            'als „die vom letzten Mal" gespiegelt',
      );
    });

    test('und ein späterer Tag auch nicht — wer rückdatiert, sieht den '
        'Stand von damals', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagA, werte: {Umfang.taille: 85.0});
      await repo.schreibeGetippt(tag: tagC, werte: {Umfang.taille: 83.5});

      expect(await repo.werteVomLetztenMal(vorTag: tagB), {
        Umfang.taille: 85.0,
      });
    });

    test('vor der ersten Messung gibt es nichts', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(await repo.werteVomLetztenMal(vorTag: tagA), isEmpty);
    });

    test('importierte Werte zählen mit, getippte schlagen sie', () async {
      final db = frisch();
      await legeZeile(
        db,
        tag: tagA,
        mass: Umfang.brust,
        zentimeter: 101.0,
        quelle: 'import',
      );
      await legeZeile(
        db,
        tag: tagB,
        mass: Umfang.taille,
        zentimeter: 86.0,
        quelle: 'import',
      );
      await repoVon(db).schreibeGetippt(tag: tagB, werte: {Umfang.taille: 84.0});

      expect(await repoVon(db).werteVomLetztenMal(vorTag: tagC), {
        Umfang.brust: 101.0,
        Umfang.taille: 84.0,
      });
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Wertgleichheit — sonst rechnet jeder abgeleitete Provider neu
  // ───────────────────────────────────────────────────────────────────────

  group('Wertgleichheit', () {
    test('zweimal gelesen ergibt gleiche Messungen', () async {
      final db = frisch();
      final repo = repoVon(db);
      await repo.schreibeGetippt(
        tag: tagB,
        werte: {Umfang.brust: 103.5, Umfang.taille: 84.0},
      );

      final erste = await repo.messungen();
      final zweite = await repo.messungen();
      expect(erste, zweite);
      expect(erste.single.hashCode, zweite.single.hashCode);
    });
  });
}

/// Schreibt jede Leseabfrage mit — der Beweis, dass in SQL gefiltert wird
/// und nicht hinterher in Dart.
class _Mitschrift extends QueryInterceptor {
  final List<({String sql, List<Object?> args})> gelesen = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    gelesen.add((sql: statement, args: args));
    return executor.runSelect(statement, args);
  }
}
