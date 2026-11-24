// Eingetragenes Wasser (Schema v16, #311): eintragen, lesen, ändern,
// löschen und den Health-Stand fortschreiben. Die Tabelle liegt in
// `wasser_tabellen.dart`, die Migration in `cache.dart`, der Notifier in
// `lib/ernaehrung/wasser_provider.dart`.
//
// API und Vertrag sind durch `app/test/data/wasser_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// Derselbe Schnitt wie `ErnaehrungRepository`: SQL hier, Riverpod nebenan,
// und **eingetragen wird immer**, auch ohne Schreibfreigabe für Health —
// `offen` heißt „noch nicht geschrieben", nicht „nicht gespeichert".
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_provider.dart';
import 'cache.dart';
import 'ernaehrung_repository.dart'
    show HealthStand, healthStandAlsText, healthStandAusText;

/// Ein eingetragenes Glas Wasser.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** — die Tagesliste
/// ist Abhängigkeit eines Providers (Fehler `03`).
@immutable
class WasserEintrag {
  const WasserEintrag({
    this.id,
    required this.tagesSchluessel,
    required this.zeitpunkt,
    required this.mengeMl,
    this.healthUuid,
    this.healthStand = HealthStand.offen,
  });

  /// `null`, solange das Glas nicht eingetragen ist.
  final int? id;

  /// Der Tag, auf den eingetragen wurde — der offene Tag des Schirms.
  final String tagesSchluessel;

  /// Wann, als UTC-Zeitpunkt.
  final DateTime zeitpunkt;

  final double mengeMl;

  /// Die Kennung der Kopie in Apple Health, sobald es eine gibt — oder
  /// der **Merker** einer veralteten Kopie nach einer Änderung, bis der
  /// Nachlauf sie ersetzt hat.
  final String? healthUuid;

  final HealthStand healthStand;

  @override
  bool operator ==(Object other) =>
      other is WasserEintrag &&
      other.id == id &&
      other.tagesSchluessel == tagesSchluessel &&
      other.zeitpunkt == zeitpunkt &&
      other.mengeMl == mengeMl &&
      other.healthUuid == healthUuid &&
      other.healthStand == healthStand;

  @override
  int get hashCode => Object.hash(
    id,
    tagesSchluessel,
    zeitpunkt,
    mengeMl,
    healthUuid,
    healthStand,
  );

  @override
  String toString() =>
      'WasserEintrag(id: $id, $tagesSchluessel, $zeitpunkt, $mengeMl ml, '
      '$healthStand)';
}

class WasserRepository {
  WasserRepository(this._db);

  final AppCache _db;

  /// Die Gläser **eines** Tages, nach Zeitpunkt aufsteigend — in SQL
  /// gefiltert und sortiert (Hausregel 2). Ein Tag ohne Wasser ist eine
  /// leere Liste: Für Tims eigene Daten heißt leer schlicht leer.
  Future<List<WasserEintrag>> wasserAmTag(String tagesSchluessel) async {
    final zeilen =
        await (_db.select(_db.wasserEintraege)
              ..where((t) => t.tagesSchluessel.equals(tagesSchluessel))
              ..orderBy([
                (t) => OrderingTerm(expression: t.zeitpunkt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return zeilen.map(_ausZeile).toList();
  }

  /// Legt ein Glas an und gibt die neue ID zurück. Eine mitgegebene ID
  /// wird nicht übernommen.
  Future<int> trageEin(WasserEintrag eintrag) => _db
      .into(_db.wasserEintraege)
      .insert(
        WasserEintraegeCompanion.insert(
          tagesSchluessel: eintrag.tagesSchluessel,
          zeitpunkt: eintrag.zeitpunkt,
          mengeMl: eintrag.mengeMl,
          healthUuid: Value(eintrag.healthUuid),
          healthStand: Value(healthStandAlsText(eintrag.healthStand)),
        ),
      );

  /// Schreibt ein bestehendes Glas neu, alle Felder. Ohne ID ist das ein
  /// Programmierfehler, kein stilles zweites Eintragen.
  Future<void> aendere(WasserEintrag eintrag) async {
    final id = eintrag.id;
    if (id == null) throw ArgumentError.notNull('eintrag.id');
    await (_db.update(
      _db.wasserEintraege,
    )..where((t) => t.id.equals(id))).write(
      WasserEintraegeCompanion(
        tagesSchluessel: Value(eintrag.tagesSchluessel),
        zeitpunkt: Value(eintrag.zeitpunkt),
        mengeMl: Value(eintrag.mengeMl),
        healthUuid: Value(eintrag.healthUuid),
        healthStand: Value(healthStandAlsText(eintrag.healthStand)),
      ),
    );
  }

  /// Nimmt genau eine Zeile weg; eine unbekannte ID ändert nichts.
  Future<void> loesche(int id) =>
      (_db.delete(_db.wasserEintraege)..where((t) => t.id.equals(id))).go();

  /// Stand und Kennung einer Zeile zusammen — wie
  /// `ErnaehrungRepository.setzeHealthKopie`.
  Future<void> setzeHealthKopie(
    int id, {
    required String? healthUuid,
    required HealthStand stand,
  }) async {
    await (_db.update(
      _db.wasserEintraege,
    )..where((t) => t.id.equals(id))).write(
      WasserEintraegeCompanion(
        healthUuid: Value(healthUuid),
        healthStand: Value(healthStandAlsText(stand)),
      ),
    );
  }

  /// Alles mit Stand `offen`, über alle Tage, das Älteste zuerst.
  Future<List<WasserEintrag>> offeneHealthEintraege() async {
    final zeilen =
        await (_db.select(_db.wasserEintraege)
              ..where(
                (t) =>
                    t.healthStand.equals(healthStandAlsText(HealthStand.offen)),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.zeitpunkt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return zeilen.map(_ausZeile).toList();
  }

  WasserEintrag _ausZeile(WasserEintragRow zeile) => WasserEintrag(
    id: zeile.id,
    tagesSchluessel: zeile.tagesSchluessel,
    zeitpunkt: zeile.zeitpunkt,
    mengeMl: zeile.mengeMl,
    healthUuid: zeile.healthUuid,
    healthStand: healthStandAusText(zeile.healthStand),
  );
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `ernaehrungRepositoryProvider`.
final wasserRepositoryProvider = Provider<WasserRepository>(
  (ref) => WasserRepository(ref.watch(appCacheProvider)),
);
