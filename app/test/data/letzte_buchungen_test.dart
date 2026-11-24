// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

/// Tests für die **letzte Buchung je Lebensmittel, für viele auf einmal**
/// (#401, unter #325) — die Grundlage der Trefferzeile „2 Bon (11,8 g)" in
/// der Suche (Spec, V9).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das.
///
/// Geschrieben nach Task 9 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` (Step 1, „Interfaces")
/// und der Spec `docs/superpowers/specs/2026-11-05-portionen-design.md`
/// (V9, „Vorwahl", Entscheidung 8) — **bevor** die Methode existierte.
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// class ErnaehrungRepository {
///   /// Je Lebensmittel der Eintrag mit der höchsten `id`, in **einer**
///   /// Abfrage.
///   Future<Map<int, Eintrag>> letzteBuchungen(Set<int> lebensmittelIds);
/// }
/// ```
///
/// - **Die höchste `id` gewinnt**, nicht der späteste `zeitpunkt` —
///   dieselbe Regel wie `letzteBuchung` (Spec, „Vorwahl": `ORDER BY id
///   DESC`). Zuletzt gebucht, nicht zuletzt gegessen.
/// - Ein Lebensmittel ohne Eintrag hat **keinen Schlüssel** — nicht einen
///   Schlüssel mit leerem Wert.
/// - Der Wert ist der **ganze Eintrag**, wie ihn `eintraegeAmTag` liest,
///   samt Schnappschuss (`portionId`, `portionName`, `portionG`).
/// - **Bei leerer Menge ist die Map leer und es wird nichts gefragt.**
/// - **Eine Abfrage**, egal wie viele Lebensmittel (Hausregel 2: gefiltert
///   wird in SQL; je Treffer eine Abfrage wäre die Suche, die je Zeile
///   rechnet).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **„Eine Abfrage" wird an der Datenbank gezählt**, über einen
///   `QueryInterceptor` von drift: genau **ein** `SELECT`, kein
///   Schreibbefehl. Dass die eine Abfrage innerhalb einer Transaktion
///   läuft, ist erlaubt — gezählt werden Anweisungen, nicht
///   Transaktionen.
/// - **„Fragt nicht"** heißt: Bei leerer Menge erreicht **keine**
///   Anweisung die Datenbank.
/// - Nicht angefragte Lebensmittel stehen nicht in der Map, auch wenn sie
///   Einträge haben. IDs ohne Lebensmittel und ohne Eintrag sind kein
///   Fehler.
///
/// Alle Namen und Zahlen hier sind **erfunden**, alle Tage liegen im Jahr
/// 2099.
void main() {
  const tag = '2099-05-11';
  const gestern = '2099-05-10';

  /// 2099-05-10, 08:10 Berliner Wanduhr (MESZ, UTC+2).
  final gesternFrueh = DateTime.utc(2099, 5, 10, 6, 10);

  /// 2099-05-11, 12:20 Berliner Wanduhr.
  final mittag = DateTime.utc(2099, 5, 11, 10, 20);

  /// 2099-05-11, 16:20 Berliner Wanduhr.
  final nachmittag = DateTime.utc(2099, 5, 11, 14, 20);

  /// 2099-05-11, 20:45 Berliner Wanduhr.
  final abend = DateTime.utc(2099, 5, 11, 18, 45);

  const bons = 3;
  const saft = 4;
  const hafer = 5;
  const linsen = 6;

  ({AppCache db, _Zaehler zaehler}) frisch() {
    final zaehler = _Zaehler();
    final db = AppCache(NativeDatabase.memory().interceptWith(zaehler));
    addTearDown(db.close);
    return (db: db, zaehler: zaehler);
  }

  Eintrag eintrag({
    required int? lebensmittelId,
    String tagesSchluessel = tag,
    DateTime? zeitpunkt,
    String name = 'Prüf-Schokolinsen',
    double? mengeG = 11.8,
    Naehrwerte naehrwerte = const Naehrwerte(kcal: 65.5),
    int? portionId,
    String? portionName,
    double? portionG,
  }) => Eintrag(
    tagesSchluessel: tagesSchluessel,
    mahlzeit: Mahlzeit.snack,
    zeitpunkt: zeitpunkt ?? nachmittag,
    lebensmittelId: lebensmittelId,
    name: name,
    mengeG: mengeG,
    naehrwerte: naehrwerte,
    portionId: portionId,
    portionName: portionName,
    portionG: portionG,
  );

  /// Der Eintrag mit Schlüssel — so, wie er aus der Datei zurückkommen muss.
  Eintrag mitId(Eintrag e, int id) => Eintrag(
    id: id,
    tagesSchluessel: e.tagesSchluessel,
    mahlzeit: e.mahlzeit,
    zeitpunkt: e.zeitpunkt,
    lebensmittelId: e.lebensmittelId,
    name: e.name,
    mengeG: e.mengeG,
    naehrwerte: e.naehrwerte,
    healthUuid: e.healthUuid,
    healthStand: e.healthStand,
    vorschlag: e.vorschlag,
    portionId: e.portionId,
    portionName: e.portionName,
    portionG: e.portionG,
  );

  /// Bucht [e] und gibt ihn mit Schlüssel zurück.
  Future<Eintrag> buche(ErnaehrungRepository repo, Eintrag e) async =>
      mitId(e, await repo.buche(e));

  // ═════════════════════════════════════════════════════════════════════
  group('letzteBuchungen', () {
    test('drei Lebensmittel, eines ohne Eintrag: genau zwei Schlüssel, je '
        'mit dem Eintrag der höchsten id', () async {
      final repo = ErnaehrungRepository(frisch().db);

      // Bons: drei Einträge, der letzte mit Portion.
      await buche(repo, eintrag(lebensmittelId: bons, mengeG: 30));
      await buche(
        repo,
        eintrag(
          lebensmittelId: bons,
          mengeG: 5.9,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );
      // Saft dazwischen — die ids der beiden laufen verschränkt.
      await buche(
        repo,
        eintrag(lebensmittelId: saft, name: 'Prüf-Saft', mengeG: 200),
      );
      final letzterBon = await buche(
        repo,
        eintrag(
          lebensmittelId: bons,
          mengeG: 11.8,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );
      final letzterSaft = await buche(
        repo,
        eintrag(
          lebensmittelId: saft,
          name: 'Prüf-Saft',
          mengeG: 500,
          portionId: 9,
          portionName: 'Glas',
          portionG: 250,
        ),
      );

      final karte = await repo.letzteBuchungen({bons, saft, hafer});

      expect(karte.keys.toSet(), {bons, saft});
      expect(karte[bons], letzterBon);
      expect(karte[saft], letzterSaft);
      expect(
        karte.containsKey(hafer),
        isFalse,
        reason: 'ohne Eintrag kein Schlüssel, auch keiner mit leerem Wert',
      );
    });

    test('die höchste id gewinnt, auch gegen einen späteren Zeitpunkt und '
        'einen späteren Tag', () async {
      final repo = ErnaehrungRepository(frisch().db);

      // Zuerst gebucht, aber auf den Abend gelegt.
      await buche(
        repo,
        eintrag(lebensmittelId: bons, zeitpunkt: abend, mengeG: 50),
      );
      // Danach nachgetragen: Mittag.
      final nachgetragen = await buche(
        repo,
        eintrag(
          lebensmittelId: bons,
          zeitpunkt: mittag,
          mengeG: 17.7,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );
      // Zuerst gebucht, auf einen späteren Tag gelegt; dann für gestern
      // nachgetragen.
      await buche(
        repo,
        eintrag(lebensmittelId: saft, name: 'Prüf-Saft', zeitpunkt: abend),
      );
      final saftGestern = await buche(
        repo,
        eintrag(
          lebensmittelId: saft,
          name: 'Prüf-Saft',
          tagesSchluessel: gestern,
          zeitpunkt: gesternFrueh,
          mengeG: 250,
        ),
      );

      final karte = await repo.letzteBuchungen({bons, saft});

      expect(karte[bons], nachgetragen);
      expect(karte[saft], saftGestern);
    });

    test('der Schnappschuss kommt mit — ein Eintrag ohne Portion trägt drei '
        'null', () async {
      final repo = ErnaehrungRepository(frisch().db);

      final mitPortion = await buche(
        repo,
        eintrag(
          lebensmittelId: bons,
          mengeG: 11.8,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );
      final inGramm = await buche(
        repo,
        eintrag(lebensmittelId: hafer, name: 'Prüf-Hafer', mengeG: 60),
      );

      final karte = await repo.letzteBuchungen({bons, hafer});

      expect(karte[bons]!.portionId, 7);
      expect(karte[bons]!.portionName, 'Bon');
      expect(karte[bons]!.portionG, 5.9);
      expect(karte[bons], mitPortion);

      expect(karte[hafer]!.portionId, isNull);
      expect(karte[hafer]!.portionName, isNull);
      expect(karte[hafer]!.portionG, isNull);
      expect(karte[hafer], inGramm);
    });

    test('nicht angefragte Lebensmittel und Schnelleinträge stehen nicht '
        'drin', () async {
      final repo = ErnaehrungRepository(frisch().db);

      final bon = await buche(repo, eintrag(lebensmittelId: bons));
      await buche(repo, eintrag(lebensmittelId: linsen, name: 'Prüf-Linsen'));
      // Ein Schnelleintrag „nur Kalorien" hat kein Lebensmittel.
      await buche(
        repo,
        eintrag(lebensmittelId: null, name: 'Prüf-Kuchen', mengeG: null),
      );

      final karte = await repo.letzteBuchungen({bons});

      expect(karte, {bons: bon});
    });

    test('nach dem Löschen des jüngsten Eintrags gilt der davor', () async {
      final repo = ErnaehrungRepository(frisch().db);

      final davor = await buche(
        repo,
        eintrag(
          lebensmittelId: bons,
          mengeG: 11.8,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );
      final juengster = await buche(
        repo,
        eintrag(lebensmittelId: bons, mengeG: 40),
      );
      await repo.loesche(juengster.id!);

      final karte = await repo.letzteBuchungen({bons});

      expect(karte, {bons: davor});
    });

    test('nur unbekannte ids: leere Map, kein Fehler', () async {
      final repo = ErnaehrungRepository(frisch().db);
      await buche(repo, eintrag(lebensmittelId: bons));

      expect(await repo.letzteBuchungen({hafer, linsen, 999}), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Was die Datenbank sieht', () {
    test(
      'bei leerer Menge ist die Map leer und es wird nichts gefragt',
      () async {
        final f = frisch();
        final repo = ErnaehrungRepository(f.db);
        // Öffnen und Migration laufen hier, nicht im gezählten Teil.
        await buche(repo, eintrag(lebensmittelId: bons));
        f.zaehler.zuruecksetzen();

        final karte = await repo.letzteBuchungen(const <int>{});

        expect(karte, isEmpty);
        expect(
          f.zaehler.anweisungen,
          isEmpty,
          reason: 'eine leere Menge braucht keine Abfrage',
        );
      },
    );

    test('drei Lebensmittel: genau ein SELECT, kein Schreibbefehl', () async {
      final f = frisch();
      final repo = ErnaehrungRepository(f.db);
      await buche(repo, eintrag(lebensmittelId: bons));
      await buche(repo, eintrag(lebensmittelId: bons, mengeG: 5.9));
      await buche(repo, eintrag(lebensmittelId: saft, name: 'Prüf-Saft'));
      await buche(repo, eintrag(lebensmittelId: linsen, name: 'Prüf-Linsen'));
      f.zaehler.zuruecksetzen();

      final karte = await repo.letzteBuchungen({bons, saft, hafer, linsen});

      expect(karte.keys.toSet(), {bons, saft, linsen});
      expect(
        f.zaehler.selects,
        1,
        reason:
            'eine Abfrage für alle — je Treffer eine wäre die Suche, die je '
            'Zeile rechnet (Hausregel 2). Gesehen: ${f.zaehler.anweisungen}',
      );
      expect(
        f.zaehler.schreibend,
        0,
        reason: 'Lesen schreibt nicht. Gesehen: ${f.zaehler.anweisungen}',
      );
    });
  });
}

/// Zählt, was die Datenbank zu sehen bekommt — Anweisungen, nicht
/// Transaktionen.
class _Zaehler extends QueryInterceptor {
  final anweisungen = <String>[];
  var selects = 0;
  var schreibend = 0;

  void zuruecksetzen() {
    anweisungen.clear();
    selects = 0;
    schreibend = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    anweisungen.add(statement);
    selects++;
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    anweisungen.add(statement);
    schreibend++;
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    anweisungen.add(statement);
    schreibend++;
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    anweisungen.add(statement);
    schreibend++;
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    anweisungen.add(statement);
    schreibend++;
    return super.runCustom(executor, statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    anweisungen.addAll(statements.statements);
    schreibend++;
    return super.runBatched(executor, statements);
  }
}
