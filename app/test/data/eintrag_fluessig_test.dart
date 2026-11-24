// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

/// Tests für den **Schnappschuss `fluessig` am Eintrag** (#403, unter
/// #275): Ein gebuchtes Getränk weiß selbst, dass es in Millilitern
/// gebucht wurde.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Geschrieben nach dem Ticket #403 und dem Auftrag des Koordinators vom
/// 10.11.2026 — **ohne** die Implementierung gesehen zu haben. Die Spalte
/// und ihre Migration prüft `schema_v20_test.dart`, die Anzeige
/// `test/ernaehrung/getraenk_ml_test.dart`. `eintrag_portion_test.dart`
/// und `ernaehrung_repository_test.dart` bleiben, wie sie sind, und müssen
/// weiter grün laufen.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// ```dart
/// class Eintrag {
///   const Eintrag({…, this.fluessig});
///   final bool? fluessig;   // Vorgabe null
///   // in ==, hashCode und copyWith (ValueGetter<bool?>)
/// }
/// ```
///
/// - **`true`** heißt „in Millilitern gebucht", **`false`** „in Gramm",
///   **`null`** „unbekannt" — so steht es in jedem alten Eintrag, und so
///   bleibt es, bis jemand ihn ändert.
/// - `buche`, `bucheAlle` und `aktualisiere` schreiben das Feld, und zwar
///   **jeden** der drei Werte, `null` als `NULL` (dieselbe Regel wie bei
///   allen Feldern von `aktualisiere`: `Value(...)`, nie `Value.absent()`).
///   Jeder Lesepfad (`eintraegeAmTag`, `offeneHealthEintraege`,
///   `letzteBuchungen`) füllt es.
/// - **Schnappschuss, kein Verweis** (Weg (a)): Wird die Vorlage später
///   flüssig oder fest gestellt oder gelöscht, liest der Eintrag weiter,
///   was beim Buchen galt.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Weg (a), Schnappschuss am Eintrag** — Begründung im Kopf von
///   `schema_v20_test.dart`.
/// - **Das Repository liest die Spalte, wie sie dasteht.** Steht `NULL` in
///   der Datei, ist `Eintrag.fluessig` `null` — auch wenn die Vorlage
///   flüssig ist. Der Rückfall auf die Vorlage ist Sache der **Anzeige**
///   (`getraenk_ml_test.dart`), nicht des Lesewegs. Sonst wäre ein
///   gelesener Eintrag nicht mehr das Abbild seiner Zeile: Er wäre
///   ungleich dem, der gebucht wurde, und `aktualisiere` schriebe beim
///   nächsten Sichern still den heutigen Stand der Vorlage als
///   Schnappschuss fest.
/// - **`toString` wird nicht geprüft.** Es nennt das Feld oder nicht; der
///   Test regelt es nicht.
///
/// Alle Namen und Zahlen hier sind **erfunden**, alle Tage liegen im Jahr
/// 2099.
void main() {
  const tag = '2099-06-14';

  /// 2099-06-14, 12:20 Berliner Wanduhr (MESZ, UTC+2).
  final mittag = DateTime.utc(2099, 6, 14, 10, 20);

  /// 2099-06-14, 16:20 Berliner Wanduhr.
  final nachmittag = DateTime.utc(2099, 6, 14, 14, 20);

  /// Ein Lebensmittel-Schlüssel, unter dem **keine** Vorlage steht — so
  /// prüft der Rundweg den Eintrag allein.
  const ohneVorlage = 901;

  AppCache frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Eintrag eintrag({
    int? id,
    DateTime? zeitpunkt,
    int? lebensmittelId = ohneVorlage,
    String name = 'Prüf-Limo',
    double? mengeG = 330,
    bool? fluessig,
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
    naehrwerte: const Naehrwerte(kcal: 139.9),
    fluessig: fluessig,
    portionId: portionId,
    portionName: portionName,
    portionG: portionG,
  );

  /// Der Eintrag mit Schlüssel — so, wie er aus der Datei zurückkommen muss.
  Eintrag mitId(Eintrag e, int id) => e.copyWith(id: () => id);

  /// `eintraege.fluessig` einer Zeile, roh aus der Datei — `1`, `0` oder
  /// `null`. Schärfer als der Dart-Wert: Er zeigt, dass `false` als `0`
  /// und `null` als `NULL` dasteht, nicht umgekehrt.
  Future<int?> rohFluessig(AppCache db, int eintragId) async {
    final zeile = await db
        .customSelect(
          'SELECT fluessig FROM eintraege WHERE id = ?;',
          variables: [Variable<int>(eintragId)],
        )
        .getSingle();
    return zeile.read<int?>('fluessig');
  }

  /// Legt roh eine Vorlage mit [fluessig] an — ohne
  /// `LebensmittelRepository`, damit diese Datei nur am Eintrag hängt.
  Future<int> vorlage(AppCache db, {required bool fluessig}) => db.customInsert(
    'INSERT INTO lebensmittel (name, kcal, fluessig) VALUES (?, ?, ?);',
    variables: [
      Variable.withString('Prüf-Vorlage'),
      Variable.withReal(42.4),
      Variable.withInt(fluessig ? 1 : 0),
    ],
  );

  Future<void> vorlageStellen(AppCache db, int id, {required bool fluessig}) =>
      db.customUpdate(
        'UPDATE lebensmittel SET fluessig = ? WHERE id = ?;',
        variables: [Variable.withInt(fluessig ? 1 : 0), Variable.withInt(id)],
        updates: {db.lebensmittel},
      );

  // ═════════════════════════════════════════════════════════════════════
  group('Eintrag trägt fluessig', () {
    test('ohne Angabe null — „unbekannt", nicht „in Gramm"', () {
      expect(eintrag().fluessig, isNull);
    });

    test('fluessig gehört zu == und hashCode — true, false und null sind '
        'drei verschiedene Einträge', () {
      final ml = eintrag(fluessig: true);

      expect(ml, eintrag(fluessig: true));
      expect(ml.hashCode, eintrag(fluessig: true).hashCode);
      expect(ml, isNot(eintrag(fluessig: false)));
      expect(ml, isNot(eintrag()));
      expect(
        eintrag(fluessig: false),
        isNot(eintrag()),
        reason: '„in Gramm gebucht" ist eine Aussage, „unbekannt" keine',
      );
    });

    test('copyWith setzt und leert fluessig und lässt es sonst stehen', () {
      final ml = eintrag(fluessig: true);

      expect(ml.copyWith(fluessig: () => false).fluessig, isFalse);
      expect(ml.copyWith(fluessig: () => null).fluessig, isNull);
      expect(ml.copyWith(name: 'Anders').fluessig, isTrue);
      expect(eintrag().copyWith(fluessig: () => true).fluessig, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Rundweg', () {
    test('in Millilitern gebucht: kommt == zurück, in der Datei 1', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final gebucht = eintrag(fluessig: true);

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      expect(await rohFluessig(db, id), 1);
    });

    test('in Gramm gebucht: false, in der Datei 0 — nicht NULL', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final gebucht = eintrag(name: 'Prüf-Brot', mengeG: 80, fluessig: false);

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      expect(await rohFluessig(db, id), 0);
    });

    test('ohne Angabe gebucht: null, in der Datei NULL — nicht 0', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final gebucht = eintrag();

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      expect(await rohFluessig(db, id), isNull);
    });

    test('mit Portion: Schnappschuss der Portion und fluessig kommen '
        'zusammen zurück', () async {
      final repo = ErnaehrungRepository(frisch());
      final gebucht = eintrag(
        mengeG: 500,
        fluessig: true,
        portionId: 7,
        portionName: 'Glas',
        portionG: 250,
      );

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
    });

    test('bucheAlle schreibt fluessig je Eintrag', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final limo = eintrag(zeitpunkt: mittag, fluessig: true);
      final brot = eintrag(name: 'Prüf-Brot', mengeG: 80, fluessig: false);

      final ids = await repo.bucheAlle([limo, brot]);

      expect(await repo.eintraegeAmTag(tag), [
        mitId(limo, ids[0]),
        mitId(brot, ids[1]),
      ]);
      expect(await rohFluessig(db, ids[0]), 1);
      expect(await rohFluessig(db, ids[1]), 0);
    });

    test('offeneHealthEintraege füllt fluessig', () async {
      final repo = ErnaehrungRepository(frisch());
      final gebucht = eintrag(fluessig: true);

      final id = await repo.buche(gebucht);

      expect(await repo.offeneHealthEintraege(), [mitId(gebucht, id)]);
    });

    test('letzteBuchungen füllt fluessig', () async {
      final repo = ErnaehrungRepository(frisch());
      final gebucht = eintrag(fluessig: true);

      final id = await repo.buche(gebucht);

      expect(await repo.letzteBuchungen({ohneVorlage}), {
        ohneVorlage: mitId(gebucht, id),
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('aktualisiere', () {
    test('schreibt fluessig mit — von true auf false', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final id = await repo.buche(eintrag(fluessig: true));

      final geaendert = eintrag(id: id, mengeG: 250, fluessig: false);
      await repo.aktualisiere(geaendert);

      expect(await repo.eintraegeAmTag(tag), [geaendert]);
      expect(await rohFluessig(db, id), 0);
    });

    test('von unbekannt auf true', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final id = await repo.buche(eintrag());

      final geaendert = eintrag(id: id, mengeG: 500, fluessig: true);
      await repo.aktualisiere(geaendert);

      expect(await repo.eintraegeAmTag(tag), [geaendert]);
      expect(await rohFluessig(db, id), 1);
    });

    test(
      'null geht als NULL hinein, nicht als „bitte stehen lassen"',
      () async {
        final db = frisch();
        final repo = ErnaehrungRepository(db);
        final id = await repo.buche(eintrag(fluessig: true));

        final geaendert = eintrag(id: id);
        await repo.aktualisiere(geaendert);

        expect(await repo.eintraegeAmTag(tag), [geaendert]);
        expect(await rohFluessig(db, id), isNull);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Schnappschuss, kein Verweis (Weg a)', () {
    test('die Vorlage wird danach fest gestellt: der Eintrag bleibt in '
        'Millilitern', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final vorlageId = await vorlage(db, fluessig: true);
      await repo.buche(eintrag(lebensmittelId: vorlageId, fluessig: true));

      await vorlageStellen(db, vorlageId, fluessig: false);

      expect((await repo.eintraegeAmTag(tag)).single.fluessig, isTrue);
    });

    test('die Vorlage wird danach flüssig gestellt: der Eintrag bleibt in '
        'Gramm', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final vorlageId = await vorlage(db, fluessig: false);
      await repo.buche(eintrag(lebensmittelId: vorlageId, fluessig: false));

      await vorlageStellen(db, vorlageId, fluessig: true);

      expect((await repo.eintraegeAmTag(tag)).single.fluessig, isFalse);
    });

    test(
      'die Vorlage wird gelöscht: der Eintrag bleibt in Millilitern',
      () async {
        final db = frisch();
        final repo = ErnaehrungRepository(db);
        final vorlageId = await vorlage(db, fluessig: true);
        await repo.buche(eintrag(lebensmittelId: vorlageId, fluessig: true));

        await db.customStatement('DELETE FROM lebensmittel WHERE id = ?;', [
          vorlageId,
        ]);

        expect((await repo.eintraegeAmTag(tag)).single.fluessig, isTrue);
      },
    );

    test('ein Eintrag ohne Schnappschuss liest null, auch wenn seine '
        'Vorlage flüssig ist — der Rückfall gehört der Anzeige', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);
      final vorlageId = await vorlage(db, fluessig: true);
      final gebucht = eintrag(lebensmittelId: vorlageId);

      final id = await repo.buche(gebucht);

      expect(await repo.eintraegeAmTag(tag), [mitId(gebucht, id)]);
      expect(await rohFluessig(db, id), isNull);
    });
  });
}
