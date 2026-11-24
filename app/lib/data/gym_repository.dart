// Die Ablage der Gym-Trainings (Schema v18, #78): abgeschlossene Sitzungen,
// ihre Sätze, der Zwischenstand eines laufenden Trainings und die Abfragen,
// für die die Tabellen überhaupt existieren. Die Tabellen liegen in
// `gym_tabellen.dart`, die Migration in `cache.dart`.
//
// API und Vertrag sind durch `app/test/data/gym_ablage_test.dart` und
// `app/test/data/gym_entwurf_test.dart` verbindlich vorgegeben (siehe deren
// Dateiköpfe) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// Derselbe Schnitt wie `WasserRepository`: SQL hier, Riverpod nebenan.
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Gym-Trainings sind Tims eigene Daten; leer heißt leer, und es gibt keinen
// Lauf, der leer ausgehen könnte.
//
// **Gefiltert wird in SQL**, über den ISO-Tagesstring `tag` (Hausregel 2):
// `WHERE tag >= ?` vergleicht lexikografisch richtig und übersteht jede
// Zeitumstellung. Nach dem Laden in Dart zu filtern war der Grund gegen die
// generische Tabelle.
//
// **Die Reihenfolge hängt nie an der Satz-Uhrzeit.** Sie steht in
// `uebung_pos` und `satz_nr`: Die Satz-Uhrzeit ist bei allem Übernommenen
// (#59) `NULL`, und ein `ORDER BY` darüber schöbe Tims ganzen bisherigen
// Verlauf ans Ende oder aus dem Ergebnis.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart' show appCacheProvider;
import 'cache.dart';

/// Eine Satzzeile, so wie sie in der Datenbank steht — die Form, in der der
/// Fortschritt (#93) Sätze über die Zeit liest.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymSatzZeile {
  const GymSatzZeile({
    required this.sitzungId,
    required this.tag,
    required this.uebungId,
    required this.uebungPos,
    required this.satzNr,
    required this.gewichtKg,
    required this.wdh,
    this.zeitpunkt,
  });

  final String sitzungId;

  /// Der Berliner ISO-Tagesschlüssel der Sitzung.
  final String tag;

  final String uebungId;

  /// Position der Übung in der Sitzung, ab 1.
  final int uebungPos;

  /// Nummer des Satzes in der Übung, ab 1.
  final int satzNr;

  /// Negativ heißt Unterstützung, `0.0` eigenes Körpergewicht.
  final double gewichtKg;

  /// Wiederholungen — bei Zeitübungen Sekunden.
  final int wdh;

  /// Wann der Satz eingetragen wurde (UTC), `null` heißt „nicht erfasst" —
  /// der Normalfall bei allem Übernommenen.
  final DateTime? zeitpunkt;

  @override
  bool operator ==(Object other) =>
      other is GymSatzZeile &&
      other.sitzungId == sitzungId &&
      other.tag == tag &&
      other.uebungId == uebungId &&
      other.uebungPos == uebungPos &&
      other.satzNr == satzNr &&
      other.gewichtKg == gewichtKg &&
      other.wdh == wdh &&
      other.zeitpunkt == zeitpunkt;

  @override
  int get hashCode => Object.hash(
    sitzungId,
    tag,
    uebungId,
    uebungPos,
    satzNr,
    gewichtKg,
    wdh,
    zeitpunkt,
  );

  @override
  String toString() =>
      'GymSatzZeile($sitzungId, $tag, $uebungId #$uebungPos, Satz $satzNr, '
      '$gewichtKg kg x $wdh, $zeitpunkt)';
}

/// Eine Zeile der Aufwärm-Auswertung (#40) — eine je Sitzung, auch wenn
/// nichts eingetragen wurde.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymAufwaermZeile {
  const GymAufwaermZeile({
    required this.sitzungId,
    required this.tag,
    required this.zeitpunkt,
    required this.aufwaermen,
    this.healthUuid,
  });

  final String sitzungId;

  /// Der Berliner ISO-Tagesschlüssel der Sitzung.
  final String tag;

  /// Der Zeitpunkt der Sitzung, UTC.
  final DateTime zeitpunkt;

  /// `null` heißt „nichts eingetragen" — nicht „übersprungen"
  /// ([WarmUpSkipped]).
  final WarmUp? aufwaermen;

  /// Die Kennung des Health-Workouts zum Aufwärmen, sobald #414 sie setzt.
  final String? healthUuid;

  @override
  bool operator ==(Object other) =>
      other is GymAufwaermZeile &&
      other.sitzungId == sitzungId &&
      other.tag == tag &&
      other.zeitpunkt == zeitpunkt &&
      other.aufwaermen == aufwaermen &&
      other.healthUuid == healthUuid;

  @override
  int get hashCode =>
      Object.hash(sitzungId, tag, zeitpunkt, aufwaermen, healthUuid);

  @override
  String toString() =>
      'GymAufwaermZeile($sitzungId, $tag, $zeitpunkt, $aufwaermen, '
      '$healthUuid)';
}

/// Der Zwischenstand eines angefangenen Trainings.
///
/// **Schmierzettel, kein Datensatz:** [dauer] und [felder] tragen rohen
/// Text, so wie getippt. **Werttyp mit [==] und [hashCode] über alle
/// Felder** (Fehler `03`).
@immutable
class GymEntwurf {
  const GymEntwurf({
    this.workout,
    this.trainingId,
    required this.sitzungId,
    required this.zeitpunkt,
    this.dauer,
    this.notiz,
    required this.gespeichertAm,
    required this.felder,
  }) : assert(
         workout != null || trainingId != null,
         'Ein Entwurf gehört zu einem Training: Enum-Fall oder Kennung',
       );

  /// Der Enum-Fall des Trainings — **`null` für ein Training ohne Enum-Fall**
  /// (ein eigenes Training, Spec 4.7), dessen Kennung dann in [trainingId]
  /// steht. Wie bei `ImportedSession` gilt: Wo es einen Fall gibt, steht er
  /// hier und [trainingId] ist `null`.
  ///
  /// **Scheibe 1 (#532) liest nur die Kennung.** Einen Entwurf mit [workout]
  /// `null` schreibt noch kein Weg — die Erfassung eines Trainings ohne
  /// Enum-Fall kommt mit #534 (Plan 3.1/3.2), und dort bekommt der Entwurf
  /// seine Anzeige. Bis dahin gilt: Die Ablage liest ihn und lässt ihn
  /// stehen — `GymLogNotifier` schreibt und verwirft in dieser Lage nichts —,
  /// aber die Fokus-Karte zeigt ihn noch nicht.
  final Workout? workout;

  /// Die Kennung eines Trainings **ohne Enum-Fall** (die UUID eines eigenen
  /// Trainings), sonst `null`.
  final String? trainingId;

  /// Die gespeicherte Kennung des Trainings — `Workout.code` oder die UUID.
  /// Das, was in `gym_entwuerfe.workout` steht.
  String get kennung => trainingId ?? workout!.code;

  /// Die UUID der künftigen Sitzung.
  final String sitzungId;

  /// Das eingestellte Datum des Trainings, UTC.
  final DateTime zeitpunkt;

  /// Die getippte Dauer, roher Text.
  final String? dauer;

  final String? notiz;

  /// Wann zuletzt zwischengespeichert wurde, UTC.
  final DateTime gespeichertAm;

  /// Die Satzzeilen als JSON-Text, roh.
  final String felder;

  @override
  bool operator ==(Object other) =>
      other is GymEntwurf &&
      other.workout == workout &&
      other.trainingId == trainingId &&
      other.sitzungId == sitzungId &&
      other.zeitpunkt == zeitpunkt &&
      other.dauer == dauer &&
      other.notiz == notiz &&
      other.gespeichertAm == gespeichertAm &&
      other.felder == felder;

  @override
  int get hashCode => Object.hash(
    workout,
    trainingId,
    sitzungId,
    zeitpunkt,
    dauer,
    notiz,
    gespeichertAm,
    felder,
  );

  @override
  String toString() =>
      'GymEntwurf($kennung, $sitzungId, $zeitpunkt, '
      'gespeichert $gespeichertAm)';
}

/// Was eine Übernahme getan hat (#59 Teil 1, mit #482): was neu in der
/// Ablage steht und was **nicht** geschrieben wurde — mit dem Grund je
/// Sitzung.
///
/// **Werttyp mit [==] und [hashCode]** über beide Listen, in ihrer
/// Reihenfolge (Fehler `03`).
@immutable
class GymUebernahme {
  const GymUebernahme({required this.geschrieben, required this.uebersprungen});

  /// Die neu geschriebenen Sitzungen in der Reihenfolge der Eingabe — die
  /// übergebenen Objekte selbst.
  final List<ImportedSession> geschrieben;

  /// Die Sitzungen, die nicht geschrieben wurden, aus dem Planer des Kerns
  /// (`GymSessionImport`).
  final List<GymImportSkip> uebersprungen;

  @override
  bool operator ==(Object other) =>
      other is GymUebernahme &&
      listEquals(other.geschrieben, geschrieben) &&
      listEquals(other.uebersprungen, uebersprungen);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(geschrieben), Object.hashAll(uebersprungen));

  @override
  String toString() =>
      'GymUebernahme(${geschrieben.length} geschrieben, '
      '${uebersprungen.length} übersprungen)';
}

class GymRepository {
  GymRepository(this._db);

  final AppCache _db;

  // --- Abgeschlossene Sitzungen ------------------------------------------

  /// Legt eine abgeschlossene Sitzung ab.
  ///
  /// `tag` wird aus `BerlinCalendar.dayKey(sitzung.date)` gerechnet, nicht
  /// aus den Feldern des `DateTime`. Eine vorhandene Sitzung desselben Tages
  /// und desselben Trainings wird **ersetzt**, samt ihren Sätzen — „kein
  /// Workout" ist dabei ein eigener Schlüssel (`GymSessionMerge`), die
  /// Kennung eines eigenen Trainings (`trainingId`) ein weiterer je Training;
  /// geschrieben wird sie in die Spalte `workout` (Spec 4.6), und der
  /// eingefrorene Name in `trainings_name`. Den
  /// Vergleich macht diese Methode mit `IS`: Der `UNIQUE`-Constraint trägt
  /// ihn nicht, weil SQLite zwei `NULL` für verschieden hält.
  ///
  /// **Vorhandene Health-Kennungen überleben das Ersetzen.** Ginge die der
  /// Sitzung verloren, legte der Lückenfüller (#418) beim nächsten Start ein
  /// zweites `HKWorkout` für denselben Tag an und das erste bliebe
  /// verwaist.
  ///
  /// Wirft [ArgumentError] und schreibt nichts, wenn eine Übung keinen Satz
  /// trägt, wenn ein Satz keine positive Wiederholungszahl hat oder wenn
  /// dieselbe Übung zweimal in der Sitzung steht — still zu verlieren wäre
  /// Datenverlust ohne Meldung, und das Gerät ist die einzige Kopie.
  Future<void> legeAb(ImportedSession sitzung) async {
    _pruefe(sitzung);
    final zeitpunkt = sitzung.date.toUtc();
    final tag = BerlinCalendar.dayKey(zeitpunkt);
    // Die Kennung des Trainings: der Code eines Enum-Falls, sonst die UUID
    // (Spec 4.6). Zwei verschiedene eigene Trainings am selben Tag haben
    // damit verschiedene Schlüssel; ohne Kennung bliebe „kein Workout" der
    // eine, gemeinsame.
    final workoutCode = sitzung.trainingId ?? sitzung.workout?.code;

    await _db.transaction(() async {
      // Treffer über Tag und Workout (`IS`, damit auch „kein Workout" ein
      // Schlüssel ist) oder über dieselbe Kennung.
      final vorhandene = await _db
          .customSelect(
            'SELECT id, health_uuid, aufwaermen_health_uuid '
            'FROM gym_sitzungen WHERE id = ? OR (tag = ? AND workout IS ?);',
            variables: [
              Variable<String>(sitzung.id),
              Variable<String>(tag),
              Variable<String>(workoutCode),
            ],
          )
          .get();

      String? healthUuid;
      String? aufwaermHealthUuid;
      for (final z in vorhandene) {
        healthUuid ??= z.read<String?>('health_uuid');
        aufwaermHealthUuid ??= z.read<String?>('aufwaermen_health_uuid');
      }
      for (final z in vorhandene) {
        final id = z.read<String>('id');
        await (_db.delete(
          _db.gymSaetze,
        )..where((t) => t.sitzungId.equals(id))).go();
        await (_db.delete(
          _db.gymSitzungen,
        )..where((t) => t.id.equals(id))).go();
      }

      final warm = sitzung.warmUp;
      await _db
          .into(_db.gymSitzungen)
          .insert(
            GymSitzungenCompanion.insert(
              id: sitzung.id,
              tag: tag,
              zeitpunkt: zeitpunkt,
              workout: Value(workoutCode),
              trainingsName: Value(sitzung.trainingName),
              minuten: Value(sitzung.minutes),
              notiz: Value(sitzung.note),
              healthUuid: Value(healthUuid),
              aufwaermenArt: Value(warm is WarmUpDone ? warm.kind.code : null),
              aufwaermenMinuten: Value(
                warm is WarmUpDone ? warm.minutes : null,
              ),
              aufwaermenKm: Value(warm is WarmUpDone ? warm.km : null),
              aufwaermenUebersprungen: Value(warm is WarmUpSkipped),
              aufwaermenHealthUuid: Value(aufwaermHealthUuid),
            ),
          );

      for (var u = 0; u < sitzung.exercises.length; u++) {
        final uebung = sitzung.exercises[u];
        for (var s = 0; s < uebung.sets.length; s++) {
          final satz = uebung.sets[s];
          await _db
              .into(_db.gymSaetze)
              .insert(
                GymSaetzeCompanion.insert(
                  sitzungId: sitzung.id,
                  uebungId: uebung.exerciseId,
                  uebungPos: u + 1,
                  satzNr: s + 1,
                  gewichtKg: satz.weight,
                  wdh: satz.reps,
                  zeitpunkt: Value(satz.recordedAt?.toUtc()),
                ),
              );
        }
      }
    });
  }

  /// Schreibt eine Übernahme aus der alten App (#59 Teil 1, mit #482) —
  /// **nur dazu, nie ersetzen, nie löschen.**
  ///
  /// Was geschrieben werden darf, entscheidet der Kern
  /// (`GymSessionImport.plan`); diese Methode führt aus. Sie liest, plant und
  /// schreibt in **einer Transaktion**: Ein Training, das währenddessen
  /// gespeichert wird, kann nicht dazwischenkommen.
  ///
  /// **Nur `INSERT`.** Kein `UPDATE`, kein `DELETE`, und **nie [legeAb]**:
  /// `legeAb` ersetzt eine Sitzung gleichen Tages und Workouts und löschte
  /// damit ein selbst eingetragenes Training samt Satz-Uhrzeiten und
  /// Aufwärmen, die die alte App gar nicht kennt — das Gerät ist die einzige
  /// Kopie. Auch dieselbe Kennung mit anderem Tag würde `legeAb` über
  /// `id = ?` ersetzen; der Planer überspringt sie als „schon da".
  ///
  /// **Alles oder nichts:** Jede zu schreibende Sitzung wird mit denselben
  /// Regeln wie in [legeAb] geprüft, **bevor** etwas geschrieben wird.
  /// Verletzt eine sie, wirft die Methode [ArgumentError] und es steht nichts
  /// da. Übersprungene Sitzungen werden nicht geprüft.
  ///
  /// **Nichts wird erfunden:** `health_uuid`, `aufwaermen_*` und
  /// `satz.zeitpunkt` bleiben `NULL`, `aufwaermen_uebersprungen` bleibt `0` —
  /// „nichts eingetragen", nicht „übersprungen". Der Entwurf eines laufenden
  /// Trainings bleibt unberührt.
  Future<GymUebernahme> uebernimm(List<ImportedSession> sitzungen) =>
      _db.transaction(() async {
        final plan = GymSessionImport.plan(
          existing: await this.sitzungen(),
          incoming: sitzungen,
        );
        plan.toWrite.forEach(_pruefe);

        for (final sitzung in plan.toWrite) {
          final zeitpunkt = sitzung.date.toUtc();
          await _db
              .into(_db.gymSitzungen)
              .insert(
                GymSitzungenCompanion.insert(
                  id: sitzung.id,
                  tag: BerlinCalendar.dayKey(zeitpunkt),
                  zeitpunkt: zeitpunkt,
                  workout: Value(sitzung.trainingId ?? sitzung.workout?.code),
                  trainingsName: Value(sitzung.trainingName),
                  minuten: Value(sitzung.minutes),
                  notiz: Value(sitzung.note),
                ),
              );
          for (var u = 0; u < sitzung.exercises.length; u++) {
            final uebung = sitzung.exercises[u];
            for (var s = 0; s < uebung.sets.length; s++) {
              final satz = uebung.sets[s];
              await _db
                  .into(_db.gymSaetze)
                  .insert(
                    GymSaetzeCompanion.insert(
                      sitzungId: sitzung.id,
                      uebungId: uebung.exerciseId,
                      uebungPos: u + 1,
                      satzNr: s + 1,
                      gewichtKg: satz.weight,
                      wdh: satz.reps,
                      // Die Datei kennt keine Satz-Uhrzeit.
                    ),
                  );
            }
          }
        }

        return GymUebernahme(
          geschrieben: plan.toWrite,
          uebersprungen: plan.skipped,
        );
      });

  /// Wirft [ArgumentError], bevor irgendetwas geschrieben wird.
  void _pruefe(ImportedSession sitzung) {
    final gesehen = <String>{};
    for (final uebung in sitzung.exercises) {
      if (uebung.sets.isEmpty) {
        throw ArgumentError.value(
          uebung.exerciseId,
          'sitzung',
          'Übung ohne Satz — die Ablage kennt keine',
        );
      }
      if (!gesehen.add(uebung.exerciseId)) {
        throw ArgumentError.value(
          uebung.exerciseId,
          'sitzung',
          'dieselbe Übung steht zweimal in der Sitzung',
        );
      }
      for (final satz in uebung.sets) {
        if (satz.reps <= 0) {
          throw ArgumentError.value(
            satz.reps,
            'sitzung',
            'Satz ohne positive Wiederholungszahl (${uebung.exerciseId})',
          );
        }
      }
    }
  }

  /// Die Sitzung mit dieser Kennung, oder `null`.
  Future<ImportedSession?> sitzung(String id) async {
    final liste = await _lade((s) => s.id.equals(id));
    return liste.isEmpty ? null : liste.single;
  }

  /// Die Sitzungen eines Zeitraums, **neueste zuerst** — in SQL über `tag`
  /// gefiltert, beide Grenzen einschließlich. Ohne Grenzen: alle.
  Future<List<ImportedSession>> sitzungen({String? vonTag, String? bisTag}) =>
      _lade((s) => _tagesFilter(s.tag, vonTag, bisTag));

  Expression<bool> _tagesFilter(
    GeneratedColumn<String> tag,
    String? vonTag,
    String? bisTag,
  ) {
    Expression<bool> filter = const Constant(true);
    if (vonTag != null) filter = filter & tag.isBiggerOrEqualValue(vonTag);
    if (bisTag != null) filter = filter & tag.isSmallerOrEqualValue(bisTag);
    return filter;
  }

  Future<List<ImportedSession>> _lade(
    Expression<bool> Function($GymSitzungenTable s) filter,
  ) async {
    final sitzungen =
        await (_db.select(_db.gymSitzungen)
              ..where(filter)
              ..orderBy([
                (t) => OrderingTerm.desc(t.tag),
                (t) => OrderingTerm.desc(t.zeitpunkt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    if (sitzungen.isEmpty) return const [];

    // Die Sätze über denselben Filter, nicht über eine `IN`-Liste der
    // Kennungen. Die Reihenfolge trägt `uebung_pos`/`satz_nr`, nie die Uhr.
    final saetze =
        await (_db.select(_db.gymSaetze).join([
                innerJoin(
                  _db.gymSitzungen,
                  _db.gymSitzungen.id.equalsExp(_db.gymSaetze.sitzungId),
                ),
              ])
              ..where(filter(_db.gymSitzungen))
              ..orderBy([
                OrderingTerm.asc(_db.gymSaetze.sitzungId),
                OrderingTerm.asc(_db.gymSaetze.uebungPos),
                OrderingTerm.asc(_db.gymSaetze.satzNr),
              ]))
            .map((r) => r.readTable(_db.gymSaetze))
            .get();

    final jeSitzung = <String, List<GymSatzRow>>{};
    for (final satz in saetze) {
      (jeSitzung[satz.sitzungId] ??= []).add(satz);
    }

    return [
      for (final s in sitzungen) _alsSitzung(s, jeSitzung[s.id] ?? const []),
    ];
  }

  ImportedSession _alsSitzung(GymSitzungRow zeile, List<GymSatzRow> saetze) {
    // Die Sätze kommen nach `uebung_pos`, `satz_nr` sortiert; die Position
    // gruppiert, die Einfügereihenfolge der Map bleibt die Reihenfolge.
    final jeUebung = <int, ({String id, List<CompletedSet> sets})>{};
    for (final satz in saetze) {
      final uebung = jeUebung[satz.uebungPos] ??= (
        id: satz.uebungId,
        sets: <CompletedSet>[],
      );
      uebung.sets.add(
        CompletedSet(
          weight: satz.gewichtKg,
          reps: satz.wdh,
          recordedAt: satz.zeitpunkt,
        ),
      );
    }
    final uebungen = [
      for (final u in jeUebung.values)
        ImportedExercise(exerciseId: u.id, sets: u.sets),
    ];

    // Die Spalte trägt die Kennung des Trainings (Spec 4.6): Ist es ein
    // `Workout.code`, ergibt das `workout: <Fall>` und `trainingId: null` —
    // **exakt wie vor v25**, damit jede bestehende Sitzung gleich `==` bleibt.
    // Ist es keiner, ist es die UUID eines Trainings ohne Enum-Fall.
    final code = zeile.workout;
    final workout = code == null ? null : Workout.fromCode(code);
    return ImportedSession(
      id: zeile.id,
      date: zeile.zeitpunkt,
      workout: workout,
      trainingId: workout == null ? code : null,
      trainingName: zeile.trainingsName,
      minutes: zeile.minuten,
      note: zeile.notiz,
      warmUp: _warmUp(zeile),
      exercises: uebungen,
    );
  }

  /// Die drei Zustände des Aufwärmens aus den Spalten.
  ///
  /// `aufwaermen_uebersprungen` trennt „übersprungen" von „nichts
  /// eingetragen". Eine Zeile, die eine Art nennt, aber keine Minuten (oder
  /// eine unbekannte Art) trägt, kann `legeAb` nicht erzeugen; sie wird als
  /// „nichts eingetragen" gelesen, statt eine Dauer zu erfinden.
  WarmUp? _warmUp(GymSitzungRow zeile) {
    if (zeile.aufwaermenUebersprungen) return const WarmUpSkipped();
    final art = zeile.aufwaermenArt;
    final minuten = zeile.aufwaermenMinuten;
    if (art == null || minuten == null) return null;
    final kind = WarmUpKind.fromCode(art);
    if (kind == null) return null;
    return WarmUpDone(kind: kind, minutes: minuten, km: zeile.aufwaermenKm);
  }

  // --- Abfragen ----------------------------------------------------------

  /// Je Workout der Zeitpunkt der jüngsten Sitzung — die Eingabe
  /// `completed` von `GymDayPlanner.day`. Sitzungen ohne Workout tauchen
  /// nicht auf; ein unbekannter Code in der Datei wird übergangen statt
  /// geraten.
  Future<Map<Workout, DateTime>> letzteSitzungJeWorkout() async {
    final spalte = _db.gymSitzungen.workout;
    final zeitpunkt = _db.gymSitzungen.zeitpunkt.max();
    final zeilen =
        await (_db.selectOnly(_db.gymSitzungen)
              ..addColumns([spalte, zeitpunkt])
              ..where(spalte.isNotNull())
              ..groupBy([spalte]))
            .get();

    final ergebnis = <Workout, DateTime>{};
    for (final z in zeilen) {
      final code = z.read(spalte);
      final wann = z.read(zeitpunkt);
      if (code == null || wann == null) continue;
      final workout = Workout.fromCode(code);
      if (workout == null) continue;
      ergebnis[workout] = wann;
    }
    return ergebnis;
  }

  /// Alle Sätze eines Zeitraums über alle Sitzungen (Muskelkarte, #96),
  /// ältester zuerst. In SQL über `tag` gefiltert.
  ///
  /// **`TrainedSet.date` ist der Satz-Zeitpunkt, und wo keiner steht, der
  /// Zeitpunkt der Sitzung.** `TrainedSet` verlangt ein Datum, die
  /// Muskelkarte braucht nur den Tag, und sonst fehlte Tims gesamter
  /// übernommener Verlauf dort. Das ist kein erfundener Zeitstempel — der
  /// Sitzungszeitpunkt ist ein erfasster Wert, und in der Spalte bleibt
  /// `NULL` stehen: Der Ersatz lebt in dieser Abfrage und wird nirgends
  /// zurückgeschrieben.
  Future<List<TrainedSet>> trainierteSaetze({
    required String vonTag,
    required String bisTag,
  }) async {
    final saetze = _db.gymSaetze;
    final sitzungen = _db.gymSitzungen;
    final wann = coalesce([saetze.zeitpunkt, sitzungen.zeitpunkt]);
    final zeilen =
        await (_db.select(saetze).join([
                innerJoin(sitzungen, sitzungen.id.equalsExp(saetze.sitzungId)),
              ])
              ..where(_tagesFilter(sitzungen.tag, vonTag, bisTag))
              ..orderBy([
                OrderingTerm.asc(wann),
                OrderingTerm.asc(sitzungen.id),
                OrderingTerm.asc(saetze.uebungPos),
                OrderingTerm.asc(saetze.satzNr),
              ]))
            .get();

    return [
      for (final z in zeilen)
        TrainedSet(
          date:
              z.readTable(saetze).zeitpunkt ?? z.readTable(sitzungen).zeitpunkt,
          exerciseId: z.readTable(saetze).uebungId,
        ),
    ];
  }

  /// Alle Sätze einer Übung über die Zeit (Fortschritt, #93),
  /// chronologisch aufsteigend — nach Tag und Zeitpunkt der **Sitzung**,
  /// dann nach Satznummer, nie nach der Satz-Uhrzeit.
  Future<List<GymSatzZeile>> saetzeDerUebung(
    String uebungId, {
    String? vonTag,
    String? bisTag,
  }) async {
    final saetze = _db.gymSaetze;
    final sitzungen = _db.gymSitzungen;
    final zeilen =
        await (_db.select(saetze).join([
                innerJoin(sitzungen, sitzungen.id.equalsExp(saetze.sitzungId)),
              ])
              ..where(
                saetze.uebungId.equals(uebungId) &
                    _tagesFilter(sitzungen.tag, vonTag, bisTag),
              )
              ..orderBy([
                OrderingTerm.asc(sitzungen.tag),
                OrderingTerm.asc(sitzungen.zeitpunkt),
                OrderingTerm.asc(sitzungen.id),
                OrderingTerm.asc(saetze.satzNr),
              ]))
            .get();

    return [
      for (final z in zeilen)
        GymSatzZeile(
          sitzungId: z.readTable(saetze).sitzungId,
          tag: z.readTable(sitzungen).tag,
          uebungId: z.readTable(saetze).uebungId,
          uebungPos: z.readTable(saetze).uebungPos,
          satzNr: z.readTable(saetze).satzNr,
          gewichtKg: z.readTable(saetze).gewichtKg,
          wdh: z.readTable(saetze).wdh,
          zeitpunkt: z.readTable(saetze).zeitpunkt,
        ),
    ];
  }

  /// Das Aufwärmen der Sitzungen eines Zeitraums (#40), ältestes zuerst —
  /// **eine Zeile je Sitzung**, auch wenn nichts eingetragen wurde. In SQL
  /// über `tag` gefiltert.
  Future<List<GymAufwaermZeile>> aufwaermenImZeitraum({
    required String vonTag,
    required String bisTag,
  }) async {
    final zeilen =
        await (_db.select(_db.gymSitzungen)
              ..where((t) => _tagesFilter(t.tag, vonTag, bisTag))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tag),
                (t) => OrderingTerm.asc(t.zeitpunkt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final z in zeilen)
        GymAufwaermZeile(
          sitzungId: z.id,
          tag: z.tag,
          zeitpunkt: z.zeitpunkt,
          aufwaermen: _warmUp(z),
          healthUuid: z.aufwaermenHealthUuid,
        ),
    ];
  }

  // --- Entwurf -----------------------------------------------------------

  /// Der eine Entwurf, oder `null`.
  ///
  /// Die Spalte trägt die **Kennung des Trainings** (Spec 4.7). Kennt der
  /// Kern sie nicht als `Workout.code`, wird sie **gegen `gym_trainings`
  /// aufgelöst**; erst wenn auch dort nichts steht — ein Training, das es
  /// nicht mehr gibt —, wirft die Methode [StateError], statt den Entwurf
  /// unsichtbar zu machen. Das Gerät ist die einzige Kopie dieser Werte.
  /// (Dass ein laufendes Training nicht gelöscht wird, sichert
  /// `GymTrainingRepository` mit der Sperre aus 4.7; hier steht nur die
  /// Auskunft.)
  Future<GymEntwurf?> entwurf() async {
    final zeile = await (_db.select(
      _db.gymEntwuerfe,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    if (zeile == null) return null;
    final workout = Workout.fromCode(zeile.workout);
    String? trainingId;
    if (workout == null) {
      final bekannt = await _db
          .customSelect(
            'SELECT 1 FROM gym_trainings WHERE id = ?;',
            variables: [Variable<String>(zeile.workout)],
          )
          .get();
      if (bekannt.isEmpty) {
        throw StateError(
          'Der Entwurf nennt ein unbekanntes Training: ${zeile.workout}',
        );
      }
      trainingId = zeile.workout;
    }
    return GymEntwurf(
      workout: workout,
      trainingId: trainingId,
      sitzungId: zeile.sitzungId,
      zeitpunkt: zeile.zeitpunkt,
      dauer: zeile.dauer,
      notiz: zeile.notiz,
      gespeichertAm: zeile.gespeichertAm,
      felder: zeile.felder,
    );
  }

  /// Schreibt den Entwurf. Liegt bereits einer für ein **anderes**
  /// Workout, wirft die Methode [StateError] und ändert nichts — die
  /// Rückfrage stellt der Schirm, nicht die Ablage.
  Future<void> speichereEntwurf(GymEntwurf entwurf) =>
      _db.transaction(() async {
        final vorhanden = await (_db.select(
          _db.gymEntwuerfe,
        )..where((t) => t.id.equals(0))).getSingleOrNull();
        if (vorhanden != null && vorhanden.workout != entwurf.kennung) {
          throw StateError(
            'Es läuft schon ein Training (${vorhanden.workout}); '
            '${entwurf.kennung} wird nicht stillschweigend darübergelegt',
          );
        }
        await _db
            .into(_db.gymEntwuerfe)
            .insertOnConflictUpdate(
              GymEntwuerfeCompanion.insert(
                id: const Value(0),
                workout: entwurf.kennung,
                sitzungId: entwurf.sitzungId,
                zeitpunkt: entwurf.zeitpunkt.toUtc(),
                dauer: Value(entwurf.dauer),
                notiz: Value(entwurf.notiz),
                gespeichertAm: entwurf.gespeichertAm.toUtc(),
                felder: entwurf.felder,
              ),
            );
      });

  /// Nimmt den Entwurf weg. Gibt es keinen, passiert nichts.
  Future<void> verwirfEntwurf() => _db.delete(_db.gymEntwuerfe).go();

  /// Legt die Sitzung ab **und** verwirft danach den Entwurf, in einer
  /// Transaktion. Scheitert das Ablegen, bleibt der Entwurf stehen und der
  /// Fehler kommt heraus — die alte App schluckt ihn und löscht den
  /// Entwurf trotzdem; das wird nicht portiert.
  Future<void> schliesseAb(ImportedSession sitzung) =>
      _db.transaction(() async {
        await legeAb(sitzung);
        await verwirfEntwurf();
      });
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `wasserRepositoryProvider`.
final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => GymRepository(ref.watch(appCacheProvider)),
);
