// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

/// Tests für den **Portions-Schnappschuss am Eintrag** und die letzte
/// Buchung eines Lebensmittels (#397, unter #325).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Geschrieben nach Task 5 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` und der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` („Schemastufe 17"
/// → `eintraege`, „Vorwahl", Entscheidung 8, V12) — **ohne** die
/// Implementierung gesehen zu haben. `ernaehrung_repository_test.dart`
/// bleibt, wie es ist, und muss weiter grün laufen.
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// class Eintrag {
///   const Eintrag({…, this.portionId, this.portionName, this.portionG});
///   final int? portionId;       // Vorgabe null
///   final String? portionName;  // Vorgabe null
///   final double? portionG;     // Vorgabe null
///   // in ==, hashCode und toString
/// }
///
/// class ErnaehrungRepository {
///   Future<LetzteBuchung?> letzteBuchung(int lebensmittelId);
/// }
/// ```
///
/// - `buche`, `bucheAlle` und `aktualisiere` schreiben die drei Felder,
///   jeder Lesepfad (`eintraegeAmTag`, `offeneHealthEintraege`) füllt sie.
/// - **Schnappschuss, kein Verweis** (Entscheidung 8): Name und Gramm
///   stehen im Eintrag. Wird die Portion in `portionen` umbenannt, geändert
///   oder gelöscht, liest der Eintrag weiter, was beim Buchen galt.
/// - **`aktualisiere` auf „g"** — alle drei `null` — entfernt den
///   Schnappschuss (V12). Anders als `vorschlag` geht der Schnappschuss
///   beim Ändern mit.
/// - **`letzteBuchung`** liest den jüngsten Eintrag desselben Lebensmittels
///   nach `id DESC LIMIT 1` — nicht nach `zeitpunkt` (Spec, „Vorwahl"). Ohne
///   Eintrag `null`. Das Ergebnis ist `LetzteBuchung` aus `trainings_core`
///   mit `mengeG`, `portionId` und `portionG` des Eintrags.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Ein Schnappschuss ohne `portionId`** (Name und Gramm gesetzt, ID
///   `null`) geht unverändert hin und zurück. Die Spec erlaubt den Fall
///   ausdrücklich (Strichcode lag schon in der Tabelle); der Test prüft
///   nur, dass der Rundweg nichts daran ändert.
/// - **Die Portionszeile im Schnappschuss-Test wird roh in `portionen`
///   geschrieben**, nicht über `PortionenRepository`: Task 4 läuft
///   parallel, und diese Datei soll nicht an ihm hängen.
/// - **`toString` nennt Name und Gramm der Portion** — geprüft wird nur,
///   dass beide Werte darin vorkommen, nicht die Schreibweise.
///
/// Alle Namen und Zahlen hier sind **erfunden**, alle Tage liegen im Jahr
/// 2099.
void main() {
  const tag = '2099-05-11';

  /// 2099-05-11, 12:20 Berliner Wanduhr (MESZ, UTC+2).
  final mittag = DateTime.utc(2099, 5, 11, 10, 20);

  /// 2099-05-11, 16:20 Berliner Wanduhr.
  final nachmittag = DateTime.utc(2099, 5, 11, 14, 20);

  /// 2099-05-11, 20:45 Berliner Wanduhr.
  final abend = DateTime.utc(2099, 5, 11, 18, 45);

  const bons = 3;
  const saft = 4;

  AppCache frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Eintrag eintrag({
    int? id,
    DateTime? zeitpunkt,
    int? lebensmittelId = bons,
    String name = 'Prüf-Schokolinsen',
    double? mengeG = 11.8,
    Naehrwerte naehrwerte = const Naehrwerte(kcal: 65.5),
    int? portionId,
    String? portionName,
    double? portionG,
  }) => Eintrag(
    id: id,
    tagesSchluessel: tag,
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

  /// Die drei Schnappschuss-Spalten einer Zeile, roh aus der Datei.
  Future<({int? id, String? name, double? g})> rohSchnappschuss(
    AppCache db,
    int eintragId,
  ) async {
    final zeile = await db
        .customSelect(
          'SELECT portion_id, portion_name, portion_g FROM eintraege '
          'WHERE id = ?;',
          variables: [Variable<int>(eintragId)],
        )
        .getSingle();
    return (
      id: zeile.read<int?>('portion_id'),
      name: zeile.read<String?>('portion_name'),
      g: zeile.read<double?>('portion_g'),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Eintrag trägt den Schnappschuss', () {
    test('ohne Angabe sind alle drei null', () {
      final e = eintrag();
      expect(e.portionId, isNull);
      expect(e.portionName, isNull);
      expect(e.portionG, isNull);
    });

    test('die drei Felder gehören zu == und hashCode', () {
      final a = eintrag(portionId: 7, portionName: 'Bon', portionG: 5.9);
      final b = eintrag(portionId: 7, portionName: 'Bon', portionG: 5.9);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(eintrag(portionId: 8, portionName: 'Bon', portionG: 5.9)),
      );
      expect(
        a,
        isNot(eintrag(portionId: 7, portionName: 'Bun', portionG: 5.9)),
      );
      expect(
        a,
        isNot(eintrag(portionId: 7, portionName: 'Bon', portionG: 6.1)),
      );
      expect(a, isNot(eintrag()));
    });

    test('toString nennt Name und Gramm der Portion', () {
      final text = eintrag(
        portionId: 7,
        portionName: 'Würfelchen',
        portionG: 4.4,
      ).toString();
      expect(text, contains('Würfelchen'));
      expect(text, contains('4.4'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Rundweg', () {
    test('mit Portion gebucht kommt der Eintrag == zurück', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final gebucht = eintrag(
        portionId: 7,
        portionName: 'Bon',
        portionG: 5.9,
        mengeG: 11.8,
      );

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      expect(await rohSchnappschuss(db, id), (id: 7, name: 'Bon', g: 5.9));
    });

    test('ohne Portion gebucht: alle drei null, auch in der Datei', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      final id = await repo.buche(eintrag(mengeG: 30));

      final gelesen = (await repo.eintraegeAmTag(tag)).single;
      expect(gelesen.portionId, isNull);
      expect(gelesen.portionName, isNull);
      expect(gelesen.portionG, isNull);
      expect(await rohSchnappschuss(db, id), (id: null, name: null, g: null));
    });

    test(
      'Schnappschuss ohne portionId geht unverändert hin und zurück',
      () async {
        final repo = ErnaehrungRepository(frisch());
        final gebucht = eintrag(portionName: 'Bon', portionG: 5.9);

        final id = await repo.buche(gebucht);

        expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      },
    );

    test('bucheAlle schreibt den Schnappschuss je Eintrag', () async {
      final repo = ErnaehrungRepository(frisch());
      final mit = eintrag(
        zeitpunkt: mittag,
        portionId: 7,
        portionName: 'Bon',
        portionG: 5.9,
      );
      final ohne = eintrag(zeitpunkt: abend, name: 'Prüfbrot', mengeG: 80);

      final ids = await repo.bucheAlle([mit, ohne]);

      expect(await repo.eintraegeAmTag(tag), [
        mitId(mit, ids[0]),
        mitId(ohne, ids[1]),
      ]);
    });

    test('offeneHealthEintraege füllt den Schnappschuss', () async {
      final repo = ErnaehrungRepository(frisch());
      final gebucht = eintrag(portionId: 7, portionName: 'Bon', portionG: 5.9);

      final id = await repo.buche(gebucht);

      expect(await repo.offeneHealthEintraege(), [mitId(gebucht, id)]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('aktualisiere', () {
    test('auf „g" (alle drei null) entfernt den Schnappschuss (V12)', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final id = await repo.buche(
        eintrag(portionId: 7, portionName: 'Bon', portionG: 5.9, mengeG: 11.8),
      );

      final aufGramm = eintrag(id: id, mengeG: 12);
      await repo.aktualisiere(aufGramm);

      expect(await repo.eintraegeAmTag(tag), [aufGramm]);
      expect(await rohSchnappschuss(db, id), (id: null, name: null, g: null));
    });

    test('von „g" auf eine Portion schreibt den Schnappschuss', () async {
      final repo = ErnaehrungRepository(frisch());
      final id = await repo.buche(eintrag(mengeG: 12));

      final aufPortion = eintrag(
        id: id,
        mengeG: 17.7,
        portionId: 7,
        portionName: 'Bon',
        portionG: 5.9,
      );
      await repo.aktualisiere(aufPortion);

      expect(await repo.eintraegeAmTag(tag), [aufPortion]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Schnappschuss, kein Verweis (Entscheidung 8)', () {
    test('umbenannte und geänderte Portion: der Eintrag liest weiter „Bon" '
        'und 5,9', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final portionId = await db.customInsert(
        'INSERT INTO portionen (lebensmittel_id, name, menge_g, herkunft) '
        "VALUES ($bons, 'Bon', 5.9, 'eigen');",
      );
      final gebucht = eintrag(
        portionId: portionId,
        portionName: 'Bon',
        portionG: 5.9,
        mengeG: 11.8,
      );
      final id = await repo.buche(gebucht);

      await db.customStatement(
        "UPDATE portionen SET name = 'Schokobon', menge_g = 6.1 "
        'WHERE id = $portionId;',
      );

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
    });

    test('gelöschte Portion: der Eintrag liest weiter „Bon" und 5,9', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final portionId = await db.customInsert(
        'INSERT INTO portionen (lebensmittel_id, name, menge_g, herkunft) '
        "VALUES ($bons, 'Bon', 5.9, 'eigen');",
      );
      final gebucht = eintrag(
        portionId: portionId,
        portionName: 'Bon',
        portionG: 5.9,
        mengeG: 11.8,
      );
      final id = await repo.buche(gebucht);

      await db.customStatement('DELETE FROM portionen WHERE id = $portionId;');

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('letzteBuchung', () {
    test('ohne Eintrag null', () async {
      final repo = ErnaehrungRepository(frisch());
      expect(await repo.letzteBuchung(bons), isNull);
    });

    test(
      'die höchste id gewinnt, auch gegen einen späteren Zeitpunkt',
      () async {
        final repo = ErnaehrungRepository(frisch());
        // Zuerst gebucht, aber auf den Abend gelegt.
        await repo.buche(
          eintrag(
            zeitpunkt: abend,
            mengeG: 11.8,
            portionId: 7,
            portionName: 'Bon',
            portionG: 5.9,
          ),
        );
        // Danach gebucht, auf den Mittag nachgetragen — das ist die letzte
        // Buchung.
        await repo.buche(eintrag(zeitpunkt: mittag, mengeG: 30));

        expect(await repo.letzteBuchung(bons), const LetzteBuchung(mengeG: 30));
      },
    );

    test('mit Portion: Menge, portionId und portionG des Eintrags', () async {
      final repo = ErnaehrungRepository(frisch());
      await repo.buche(eintrag(zeitpunkt: abend, mengeG: 30));
      await repo.buche(
        eintrag(
          zeitpunkt: mittag,
          mengeG: 11.8,
          portionId: 7,
          portionName: 'Bon',
          portionG: 5.9,
        ),
      );

      expect(
        await repo.letzteBuchung(bons),
        const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9),
      );
    });

    test('Einträge anderer Lebensmittel zählen nicht', () async {
      final repo = ErnaehrungRepository(frisch());
      await repo.buche(
        eintrag(mengeG: 11.8, portionId: 7, portionName: 'Bon', portionG: 5.9),
      );
      await repo.buche(
        eintrag(lebensmittelId: saft, name: 'Prüfsaft', mengeG: 250),
      );
      await repo.buche(
        eintrag(lebensmittelId: null, name: 'Nur Kalorien', mengeG: null),
      );

      expect(
        await repo.letzteBuchung(bons),
        const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9),
      );
      expect(await repo.letzteBuchung(saft), const LetzteBuchung(mengeG: 250));
      expect(await repo.letzteBuchung(99), isNull);
    });

    test('ein gelöschter jüngster Eintrag zählt nicht mehr', () async {
      final repo = ErnaehrungRepository(frisch());
      await repo.buche(eintrag(mengeG: 30));
      final juengster = await repo.buche(
        eintrag(mengeG: 11.8, portionId: 7, portionName: 'Bon', portionG: 5.9),
      );

      await repo.loesche(juengster);

      expect(await repo.letzteBuchung(bons), const LetzteBuchung(mengeG: 30));
    });
  });
}
