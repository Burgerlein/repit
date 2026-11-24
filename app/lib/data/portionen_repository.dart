// Die **Portionen** eines Lebensmittels lesen, anlegen, ändern und löschen
// (#396, unter #325). Die Spalten trägt Schemastufe 17
// (`ernaehrung_tabellen.dart`, `cache.dart`); das Anlegen zusammen mit
// einem Lebensmittel und die einmalige Nachfrage bei Open Food Facts
// liegen in `lebensmittel_repository.dart`, weil sie das Lebensmittel mit
// schreiben.
//
// API und Vertrag sind durch `app/test/data/portionen_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Gefiltert und sortiert wird in SQL** (`CLAUDE.md`, Hausregel 2): nur
// Zeilen dieses Lebensmittels mit `menge_g > 0`, aufsteigend nach Menge,
// bei Gleichstand nach `id`.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_provider.dart';
import 'cache.dart';
import 'lebensmittel_repository.dart';
import 'portion.dart';

/// Lese-/Schreib-Brücke zwischen `AppCache` und [Portion] — derselbe
/// Schnitt wie bei `LebensmittelRepository`: SQL hier, Riverpod nebenan.
class PortionenRepository {
  PortionenRepository(this._db);

  final AppCache _db;

  /// Die Portionen eines Lebensmittels, die kleinste zuerst.
  ///
  /// **Eine Portion ohne Gramm ist keine:** Zeilen mit `menge_g` `NULL`,
  /// `0` oder kleiner erscheinen nicht, ebenso keine Zeile ohne
  /// `lebensmittel_id` (die Spalte ist nur nullbar, weil Stufe 17 sie
  /// nachgetragen hat). Gleich große Portionen stehen in der Reihenfolge
  /// ihres Anlegens.
  Future<List<Portion>> fuer(int lebensmittelId) async {
    final zeilen =
        await (_db.select(_db.portionen)
              ..where(
                (t) =>
                    t.lebensmittelId.equals(lebensmittelId) &
                    t.mengeG.isBiggerThanValue(0),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.mengeG),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return zeilen.map(_ausZeile).toList();
  }

  /// Legt eine Portion an [lebensmittelId] an und gibt ihren Schlüssel
  /// zurück. Ein mitgegebenes [Portion.id] wird nicht übernommen; die
  /// Herkunft geht mit, wie sie kommt.
  Future<int> legeAn(int lebensmittelId, Portion portion) =>
      schreibePortion(_db, lebensmittelId, portion);

  /// Schreibt **Name und Menge** einer bestehenden Portion neu.
  ///
  /// **Die Herkunft bleibt**, gleich was in [Portion.herkunft] steht: Eine
  /// umbenannte „Portion" aus Open Food Facts stammt weiter von dort.
  ///
  /// Wirft `ArgumentError`, wenn [Portion.id] fehlt — eine Portion ohne
  /// Schlüssel ist nicht gespeichert, und sie zu „ändern" wäre ein
  /// Programmierfehler, keine Datenlage.
  Future<void> aendere(Portion portion) async {
    final id = portion.id;
    if (id == null) {
      throw ArgumentError.notNull('portion.id');
    }

    await (_db.update(_db.portionen)..where((t) => t.id.equals(id))).write(
      PortionenCompanion(
        name: Value(portion.name),
        mengeG: Value(portion.mengeG),
      ),
    );
  }

  /// Nimmt **genau eine Zeile** weg. Gebuchte Einträge behalten ihren
  /// Schnappschuss aus Name und Gramm; sie verweisen nicht auf diese Zeile.
  Future<void> loesche(int id) async {
    await (_db.delete(_db.portionen)..where((t) => t.id.equals(id))).go();
  }

  Portion _ausZeile(PortionRow zeile) => Portion(
    id: zeile.id,
    name: zeile.name,
    // `menge_g > 0` steht im `WHERE` — `NULL` kommt hier nicht an.
    mengeG: zeile.mengeG!,
    // Ein unbekannter Wert wirft, statt still `eigen` zu werden — dieselbe
    // Haltung wie bei `lebensmittel.herkunft`.
    herkunft: Herkunft.values.byName(zeile.herkunft),
  );
}

/// Schreibt eine Zeile in `portionen` — der eine Schreibweg, den
/// [PortionenRepository.legeAn] und die Transaktionen in
/// `LebensmittelRepository` teilen.
///
/// **Öffnet keine eigene Transaktion.** Wer mehrere Zeilen zusammen mit
/// einem Lebensmittel schreibt, ruft das innerhalb seiner
/// `_db.transaction` auf; drift leitet den Aufruf dann in diese Transaktion.
/// [herkunft] überstimmt [Portion.herkunft], wo die Herkunft feststeht
/// (die Nachfrage bei Open Food Facts).
Future<int> schreibePortion(
  AppCache db,
  int lebensmittelId,
  Portion portion, {
  Herkunft? herkunft,
}) => db
    .into(db.portionen)
    .insert(
      PortionenCompanion.insert(
        lebensmittelId: Value(lebensmittelId),
        name: Value(portion.name),
        mengeG: Value(portion.mengeG),
        herkunft: Value((herkunft ?? portion.herkunft).name),
      ),
    );

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `lebensmittelRepositoryProvider`.
final portionenRepositoryProvider = Provider<PortionenRepository>(
  (ref) => PortionenRepository(ref.watch(appCacheProvider)),
);
