// Die Ablage der Umfänge (#477 unter #88, Scheibe 2): schreiben, lesen und
// die Werte vom letzten Mal. Die Tabelle liegt in `tables.dart` (Stufe 24,
// #476), die Rechnungen darunter im Kern (`Umfang`, `UmfangsMerge`).
//
// API und Vertrag sind durch `app/test/data/umfaenge_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Derselbe Schnitt wie `WasserRepository`: SQL hier, Riverpod nebenan.
//
// **Zusammengeführt wird beim Lesen, nicht beim Schreiben.** Die Quelle
// steht im Primärschlüssel; eine getippte und eine importierte Zeile
// desselben Maßes liegen nebeneinander, und erst `UmfangsMerge` entscheidet.
//
// **Kein `Messwert`.** Umfänge sind Tims eigene Daten; es gibt keinen Lauf,
// der leer ausgehen kann. Leer heißt leer.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import '../health/health_types.dart' show datumAusTag;
import 'cache.dart';

/// Was von Hand eingetragen wurde — schlägt beim Zusammenführen den Import.
const String quelleGetippt = 'getippt';

/// Was übernommen wurde — aus der Exportdatei der eingefrorenen Swift-App
/// (#498) und darüber auch das, was jene aus dem alten Web-Dashboard trug.
/// Angelegt von [UmfaengeRepository.uebernimm], nie von Hand.
const String quelleImport = 'import';

/// Was eine Übernahme getan hat — beide Listen tagweise gefaltet und
/// aufsteigend, mit dem Berliner Tagesbeginn als `zeitpunkt`
/// ([UmfangsImport.plan]).
class UmfaengeUebernahme {
  const UmfaengeUebernahme({
    required this.geschrieben,
    required this.schonVorhanden,
  });

  /// Je Tag die Maße, die neu dazugekommen sind.
  final List<Umfangsmessung> geschrieben;

  /// Je Tag die Maße, die als Import schon dastanden — mit dem Wert aus der
  /// Datei, nicht dem abgelegten.
  final List<Umfangsmessung> schonVorhanden;

  @override
  String toString() =>
      'UmfaengeUebernahme(${geschrieben.length} Tage neu, '
      '${schonVorhanden.length} Tage schon da)';
}

class UmfaengeRepository {
  /// [uhr] liefert den Zeitpunkt für `eingetragen_am`; ohne sie die Uhr des
  /// Geräts. Nie `DateTime.now()` unmittelbar im Rumpf — sonst ließe sich
  /// das Schreiben nicht deterministisch prüfen.
  UmfaengeRepository(AppCache db, {DateTime Function()? uhr})
    : _db = db,
      _uhr = uhr ?? _geraeteUhr;

  static DateTime _geraeteUhr() => DateTime.now().toUtc();

  final AppCache _db;
  final DateTime Function() _uhr;

  /// Alle zusammengeführten Messungen, **absteigend nach Tag** — die jüngste
  /// zuerst. [abTag] und [bisTag] sind ISO-Tagesstrings und beide
  /// **einschließlich**.
  ///
  /// Gefiltert und sortiert wird in SQL (Hausregel 2): Nach dem Laden in
  /// Dart zu filtern holte jede jemals gemessene Zeile in den Speicher und
  /// würfe sie wieder weg — das wächst mit jedem Jahr, das Tim misst.
  Future<List<Umfangsmessung>> messungen({
    String? abTag,
    String? bisTag,
  }) async {
    final zeilen = await _zeilen(abTag: abTag, bisTag: bisTag);
    // `UmfangsMerge` gibt aufsteigend zurück, der Schirm zeigt die jüngste
    // oben.
    return _zusammengefuehrt(zeilen).reversed.toList();
  }

  /// Die zusammengeführte Messung eines Tages, oder `null`, wenn es für ihn
  /// keine einzige Zeile gibt.
  Future<Umfangsmessung?> messungAm(String tag) async {
    final zeilen = await _zeilen(abTag: tag, bisTag: tag);
    final messungen = _zusammengefuehrt(zeilen);
    return messungen.isEmpty ? null : messungen.single;
  }

  /// Schreibt die getippten Werte eines Tages — je **gefülltem** Maß eine
  /// Zeile mit `quelle = 'getippt'`.
  ///
  /// **Ergänzt maßweise, ersetzt den Tag nicht.** Ein Maß, das in [werte]
  /// fehlt, bleibt unberührt stehen: Ein leeres Feld ist ein „nichts dazu zu
  /// sagen", kein Löschbefehl. Ein Formular, dessen leere Felder löschen,
  /// verlöre Werte genau dann, wenn nur eine Zahl korrigiert werden sollte.
  Future<void> schreibeGetippt({
    required String tag,
    required Map<Umfang, double> werte,
  }) async {
    if (werte.isEmpty) return;
    final jetzt = _uhr().toUtc();

    await _db.batch((batch) {
      for (final eintrag in werte.entries) {
        batch.insert(
          _db.umfaenge,
          UmfaengeCompanion.insert(
            tag: tag,
            mass: eintrag.key.schluessel,
            zentimeter: eintrag.value,
            eingetragenAm: jetzt,
            quelle: quelleGetippt,
          ),
          // Dieselbe Zeile, neuer Wert — SPEC 4.6: „Eine zweite Eingabe am
          // selben Tag ändert die erste." Mit ihr zieht der Zeitstempel mit;
          // der alte behauptete, der neue Wert stünde schon seit morgens da.
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Schreibt übernommene Messungen — **nur dazu, nie ersetzen, nie
  /// löschen**, immer mit `quelle = 'import'`.
  ///
  /// Lesen, Planen ([UmfangsImport.plan]) und Schreiben laufen in **einer**
  /// Transaktion: Ein halb geschriebener Stand wäre ein Stand, den niemand
  /// geplant hat.
  ///
  /// Verglichen wird nur gegen die Zeilen der Quelle `import`. Ein von Hand
  /// eingetragener Wert steht daneben und gewinnt erst beim Lesen
  /// (`UmfangsMerge`); hinderte er die Übernahme am Schreiben, verschwände
  /// der importierte Wert für immer.
  ///
  /// `eingetragen_am` kommt aus der Uhr — der Zeitpunkt der Übernahme, nicht
  /// der Messzeitpunkt der Datei. Nichts wird erfunden.
  Future<UmfaengeUebernahme> uebernimm(List<Umfangsmessung> messungen) =>
      _db.transaction(() async {
        final plan = UmfangsImport.plan(
          existing: await _importMessungen(),
          incoming: messungen,
        );
        final jetzt = _uhr().toUtc();

        for (final messung in plan.toWrite) {
          final tag = BerlinCalendar.dayKey(messung.zeitpunkt);
          for (final eintrag in messung.werte.entries) {
            await _db
                .into(_db.umfaenge)
                .insert(
                  UmfaengeCompanion.insert(
                    tag: tag,
                    mass: eintrag.key.schluessel,
                    zentimeter: eintrag.value,
                    eingetragenAm: jetzt,
                    quelle: quelleImport,
                  ),
                );
          }
        }

        return UmfaengeUebernahme(
          geschrieben: plan.toWrite,
          schonVorhanden: plan.alreadyPresent,
        );
      });

  /// Löscht **ein** Maß eines Tages — der Vertipper (#486).
  ///
  /// **Über alle Quellen.** Die Quelle steht im Primärschlüssel, und
  /// zusammengeführt wird beim Lesen: getippt schlägt importiert. Löschte
  /// man nur die getippte Zeile, käme die importierte darunter wieder
  /// hervor — der gelöschte Wert stünde am nächsten Bild erneut im Verlauf.
  ///
  /// Die übrigen Maße desselben Tages bleiben unberührt; war es das letzte,
  /// ist der Tag damit kein Messtag mehr (eine Zeile je gefülltem Maß,
  /// nichts weiter liegt in der Tabelle).
  Future<void> loescheMass({required String tag, required Umfang mass}) =>
      (_db.delete(
        _db.umfaenge,
      )..where((t) => t.tag.equals(tag) & t.mass.equals(mass.schluessel))).go();

  /// Löscht einen **ganzen Messtag** — am falschen Tag eingetragen (#486).
  ///
  /// **Über alle Quellen**, aus demselben Grund wie [loescheMass]. Ein Tag,
  /// den es nicht gibt, ist kein Fehler: Es gibt schlicht nichts zu löschen.
  Future<void> loescheMesstag(String tag) =>
      (_db.delete(_db.umfaenge)..where((t) => t.tag.equals(tag))).go();

  /// Die abgelegten Zeilen der Quelle `import`, tagweise — die Vergleichs-
  /// grundlage von [uebernimm].
  Future<List<Umfangsmessung>> _importMessungen() async {
    final zeilen = await (_db.select(
      _db.umfaenge,
    )..where((t) => t.quelle.equals(quelleImport))).get();

    final nachTag = <String, Map<Umfang, double>>{};
    for (final zeile in zeilen) {
      final mass = Umfang.vonSchluessel(zeile.mass);
      if (mass == null) continue;
      (nachTag[zeile.tag] ??= <Umfang, double>{})[mass] = zeile.zentimeter;
    }
    return _alsMessungen(nachTag);
  }

  /// Die Platzhalter des Formulars: je Maß der Wert der jüngsten Messung
  /// **vor** [vorTag], die dieses Maß enthält.
  ///
  /// Je Maß und nicht als Block: Weil leere Felder nicht gespeichert werden,
  /// trägt eine Messung oft nur ein Maß — nähme der Platzhalter den jüngsten
  /// Messtag als Ganzes, stünden vierzehn Felder ohne Vorwert da.
  ///
  /// **Vor dem gewählten Tag, nicht vor heute.** Wer rückdatiert, will den
  /// Stand sehen, der damals galt; und wer einen Tag erneut öffnet, bekäme
  /// sonst die eigenen Werte als „die vom letzten Mal" gespiegelt.
  Future<Map<Umfang, double>> werteVomLetztenMal({
    required String vorTag,
  }) async {
    final zeilen = await (_db.select(
      _db.umfaenge,
    )..where((t) => t.tag.isSmallerThanValue(vorTag))).get();

    final werte = <Umfang, double>{};
    // Aufsteigend durchlaufen: Das jüngste Vorkommen eines Maßes gewinnt.
    for (final messung in _zusammengefuehrt(zeilen)) {
      werte.addAll(messung.werte);
    }
    return werte;
  }

  /// Der Tag der jüngsten Messung als ISO-Tagesstring, oder `null`.
  Future<String?> letzterMesstag() async {
    final zeilen =
        await (_db.select(_db.umfaenge)
              ..orderBy([
                (t) => OrderingTerm(expression: t.tag, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .get();
    return zeilen.isEmpty ? null : zeilen.single.tag;
  }

  /// Die Rohzeilen eines Fensters. Beide Grenzen einschließlich; der
  /// Tagesschlüssel vergleicht lexikografisch richtig und übersteht jede
  /// Zeitumstellung.
  Future<List<UmfangRow>> _zeilen({String? abTag, String? bisTag}) {
    final abfrage = _db.select(_db.umfaenge);
    if (abTag != null) {
      abfrage.where((t) => t.tag.isBiggerOrEqualValue(abTag));
    }
    if (bisTag != null) {
      abfrage.where((t) => t.tag.isSmallerOrEqualValue(bisTag));
    }
    return abfrage.get();
  }

  /// Rohzeilen → zusammengeführte Messungen, **aufsteigend** nach Tag (so
  /// gibt `UmfangsMerge` sie zurück).
  ///
  /// Eine Zeile mit unbekanntem Maß fällt weg statt zu werfen: Eine ältere
  /// oder fremde Importdatei darf das Lesen nicht abbrechen
  /// (`Umfang.vonSchluessel`).
  List<Umfangsmessung> _zusammengefuehrt(List<UmfangRow> zeilen) {
    final importiert = <String, Map<Umfang, double>>{};
    final getippt = <String, Map<Umfang, double>>{};

    for (final zeile in zeilen) {
      final mass = Umfang.vonSchluessel(zeile.mass);
      if (mass == null) continue;
      final ziel = zeile.quelle == quelleGetippt ? getippt : importiert;
      (ziel[zeile.tag] ??= <Umfang, double>{})[mass] = zeile.zentimeter;
    }

    return UmfangsMerge.messungen(
      importiert: _alsMessungen(importiert),
      getippt: _alsMessungen(getippt),
    );
  }

  List<Umfangsmessung> _alsMessungen(
    Map<String, Map<Umfang, double>> nachTag,
  ) => [
    for (final eintrag in nachTag.entries)
      Umfangsmessung(zeitpunkt: datumAusTag(eintrag.key), werte: eintrag.value),
  ];
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `wasserRepositoryProvider`.
final umfaengeRepositoryProvider = Provider<UmfaengeRepository>(
  (ref) => UmfaengeRepository(
    ref.watch(appCacheProvider),
    uhr: ref.watch(clockProvider),
  ),
);
