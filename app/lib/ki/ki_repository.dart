import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/cache.dart';
import '../health/health_provider.dart';

// Einstellungen und Verbrauch des KI-Zugangs (#337), über den Tabellen aus
// `app/lib/data/ki_tabellen.dart` (Schema 15). Spec
// „KI-Zugang und Foto-Schätzung" (`docs/superpowers/specs/`), „Verbrauch und
// Limit" und „Datenschicht — Schema 14 → 15".
//
// **Der Schlüssel kommt hier nicht vor.** Kein Parameter nimmt ihn
// entgegen; die Datenbank wandert ins iCloud-Gerätebackup, der Schlüssel
// nicht.
//
// `Messwert<T>` gilt hier nicht — Einstellungen und Verbrauch sind Tims
// eigene Daten, leer heißt leer.

/// Was in `ki_einstellungen` steht, als Werttyp.
///
/// Fehlt die Zeile, ist jedes Feld `null` bzw. [preise] leer — die
/// Vorgaben der App (Modell, Limit) entscheidet die Anzeige, nicht die
/// Datenbank.
///
/// **`==` und `hashCode` über alle Felder, [preise] inhaltlich verglichen:**
/// Der Stand ist Abhängigkeit des KI-Zugang-Providers; ohne inhaltliches
/// `==` rechnete jeder abgeleitete Wert bei jeder Lesung neu (`03`).
@immutable
class KiEinstellungenStand {
  const KiEinstellungenStand({
    this.modell,
    this.limitUsd,
    this.preise = const {},
    this.geprueftAm,
    this.pruefErgebnis,
  });

  /// Das gewählte Modell; `null` heißt „Voreinstellung der App".
  final String? modell;

  /// Das Monatslimit in US-Dollar; `null` heißt „Vorgabe", nicht `0`.
  final double? limitUsd;

  /// Tims eigene Preise je Modell, Überschreibungen der vorbelegten. Leer
  /// heißt „keine Überschreibungen".
  final Map<String, KiPreis> preise;

  /// Wann der Schlüssel zuletzt geprüft wurde, UTC; `null` heißt „nie".
  final DateTime? geprueftAm;

  /// Ergebnis der letzten Prüfung (`gueltig`, `abgelehnt`, `kontingent`).
  final String? pruefErgebnis;

  @override
  bool operator ==(Object other) =>
      other is KiEinstellungenStand &&
      other.modell == modell &&
      other.limitUsd == limitUsd &&
      mapEquals(other.preise, preise) &&
      other.geprueftAm == geprueftAm &&
      other.pruefErgebnis == pruefErgebnis;

  @override
  int get hashCode => Object.hash(
    modell,
    limitUsd,
    Object.hashAllUnordered(
      preise.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    geprueftAm,
    pruefErgebnis,
  );

  @override
  String toString() =>
      'KiEinstellungenStand(modell: $modell, limitUsd: $limitUsd, '
      'preise: $preise, geprueftAm: $geprueftAm, '
      'pruefErgebnis: $pruefErgebnis)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und dem KI-Zugang — SQL hier,
/// Riverpod nebenan.
class KiRepository {
  KiRepository(this._db);

  final AppCache _db;

  /// Der Schlüssel der einen Zeile in `ki_einstellungen`. Eine zweite wäre
  /// ein zweiter, widersprechender Stand.
  static const _einzigeZeile = 0;

  /// Liest die Einstellungen. **Legt keine Zeile an** — eine beim Lesen
  /// angelegte Zeile behauptete eine Einstellung, die niemand getroffen hat.
  Future<KiEinstellungenStand> einstellungen() async {
    final zeile = await _db.select(_db.kiEinstellungen).getSingleOrNull();
    if (zeile == null) return const KiEinstellungenStand();
    return KiEinstellungenStand(
      modell: zeile.modell,
      limitUsd: zeile.limitUsd,
      preise: _preiseAusText(zeile.preise),
      geprueftAm: zeile.geprueftAm,
      pruefErgebnis: zeile.pruefErgebnis,
    );
  }

  Future<void> setzeModell(String modell) =>
      _setze(KiEinstellungenCompanion(modell: Value(modell)));

  Future<void> setzeLimit(double limitUsd) =>
      _setze(KiEinstellungenCompanion(limitUsd: Value(limitUsd)));

  /// Setzt Tims Preis für [modell] und ersetzt einen früheren für dasselbe
  /// Modell. Die Preise der übrigen Modelle bleiben stehen.
  Future<void> setzePreis(String modell, KiPreis preis) =>
      _db.transaction(() async {
        final zeile = await _db.select(_db.kiEinstellungen).getSingleOrNull();
        final preise = {
          if (zeile != null) ..._preiseAusText(zeile.preise),
          modell: preis,
        };
        await _setze(
          KiEinstellungenCompanion(preise: Value(_preiseAlsText(preise))),
        );
      });

  /// Hält das Ergebnis der letzten Schlüsselprüfung fest; [geprueftAm] ist
  /// ein UTC-Zeitpunkt.
  Future<void> setzePruefung(DateTime geprueftAm, String ergebnis) => _setze(
    KiEinstellungenCompanion(
      geprueftAm: Value(geprueftAm.toUtc()),
      pruefErgebnis: Value(ergebnis),
    ),
  );

  /// Schreibt nur die Felder, die [felder] trägt, in die eine Zeile; legt
  /// sie an, falls sie fehlt. Die übrigen Felder bleiben stehen.
  Future<void> _setze(KiEinstellungenCompanion felder) async {
    final mitId = felder.copyWith(id: const Value(_einzigeZeile));
    await _db
        .into(_db.kiEinstellungen)
        .insert(
          mitId,
          onConflict: DoUpdate((_) => felder, target: [_db.kiEinstellungen.id]),
        );
  }

  /// Eine Zeile je Antwort in `ki_anfragen`.
  ///
  /// Den Monat rechnet das Repository selbst aus [zeitpunkt], in Berliner
  /// Zeit (`monatsSchluessel`). [kosten] `null` heißt „kein Preis bekannt"
  /// und bleibt `null` — eine `0` senkte die Monatssumme still.
  Future<void> protokolliere({
    required DateTime zeitpunkt,
    required String modell,
    required String zweck,
    required KiVerbrauch verbrauch,
    double? kosten,
  }) async {
    final utc = zeitpunkt.toUtc();
    await _db
        .into(_db.kiAnfragen)
        .insert(
          KiAnfragenCompanion.insert(
            zeitpunkt: utc,
            monat: monatsSchluessel(utc),
            modell: modell,
            zweck: zweck,
            eingabeToken: verbrauch.eingabe,
            ausgabeToken: verbrauch.ausgabe,
            denkToken: verbrauch.denken,
            kostenUsd: Value(kosten),
          ),
        );
  }

  /// Die Summe des Berliner Kalendermonats [monatsSchluessel] (`JJJJ-MM`).
  ///
  /// **Gefiltert wird in SQL** über die Spalte `monat`; aus der Datei kommen
  /// nur die Beträge dieses Monats. Summiert wird mit `summiere` aus dem
  /// Kern, damit die Regel „ohne Betrag zählt als Anfrage, nicht als Geld"
  /// an genau einer Stelle steht.
  Future<MonatsSumme> monat(String monatsSchluessel) async {
    final tabelle = _db.kiAnfragen;
    final abfrage = _db.selectOnly(tabelle)
      ..addColumns([tabelle.kostenUsd])
      ..where(tabelle.monat.equals(monatsSchluessel));
    final betraege = await abfrage
        .map((zeile) => zeile.read(tabelle.kostenUsd))
        .get();
    return summiere(betraege);
  }

  /// Der Zeitpunkt der jüngsten Anfrage überhaupt, UTC; `null` heißt
  /// „noch keine". Für die Zeile „Anfragen · zuletzt …" des KI-Zugangs.
  ///
  /// Über alle Monate, nicht nur den laufenden: „zuletzt" fragt, wann die
  /// App zum letzten Mal Google gefragt hat, nicht wann in diesem Monat.
  Future<DateTime?> letzteAnfrage() async {
    final tabelle = _db.kiAnfragen;
    final abfrage = _db.selectOnly(tabelle)
      ..addColumns([tabelle.zeitpunkt])
      ..orderBy([OrderingTerm.desc(tabelle.zeitpunkt)])
      ..limit(1);
    final zeile = await abfrage.getSingleOrNull();
    return zeile?.read(tabelle.zeitpunkt);
  }
}

/// Liest die Preis-Überschreibungen aus der JSON-Spalte.
///
/// Form: `{"<modell>": {"eingabeJeMio": 0.75, "ausgabeJeMio": 3.75}}`. Ein
/// Eintrag in anderer Form wirft — das ist ein Programmierfehler, keine
/// Datenlage.
Map<String, KiPreis> _preiseAusText(String text) {
  final roh = jsonDecode(text) as Map<String, dynamic>;
  return {
    for (final eintrag in roh.entries)
      eintrag.key: () {
        final preis = eintrag.value as Map<String, dynamic>;
        return KiPreis(
          eingabeJeMio: (preis['eingabeJeMio'] as num).toDouble(),
          ausgabeJeMio: (preis['ausgabeJeMio'] as num).toDouble(),
        );
      }(),
  };
}

String _preiseAlsText(Map<String, KiPreis> preise) => jsonEncode({
  for (final eintrag in preise.entries)
    eintrag.key: {
      'eingabeJeMio': eintrag.value.eingabeJeMio,
      'ausgabeJeMio': eintrag.value.ausgabeJeMio,
    },
});

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `stammdatenRepositoryProvider`.
final kiRepositoryProvider = Provider<KiRepository>(
  (ref) => KiRepository(ref.watch(appCacheProvider)),
);
