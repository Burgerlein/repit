// Die Historie der Aufteilung des Tagesziels auf die Mahlzeiten (#432
// unter #374) — Repository und Provider. Die Tabelle steht in
// `aufteilung_tabelle.dart`, Werttyp und Rechnungen (`MahlzeitAufteilung`,
// `AufteilungAb`, `geltendeAufteilung`) im Kern.
//
// API und Vertrag sind durch `app/test/data/mahlzeit_aufteilungen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Spec: `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Repository und Provider". Gebaut nach dem Muster von
// `kalorienziele.dart`.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Die Aufteilung ist Tims eigene Einstellung; leer heißt leer.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Lese-/Schreib-Brücke zwischen `AppCache` und der Historie — SQL hier,
/// Riverpod darunter.
class MahlzeitAufteilungRepository {
  MahlzeitAufteilungRepository(this._db);

  final AppCache _db;

  /// Alle Aufteilungen, aufsteigend nach `ab_tag` — sortiert und gefiltert
  /// in SQL.
  ///
  /// **Nur Zeilen mit allen drei Werten** (V1): Einer halben Aufteilung
  /// fehlte der Rest, aus dem der Snack entsteht. Eine Zeile mit einem
  /// verbotenen Wert (kein Vielfaches von 5, Summe über 100) wirft dagegen
  /// `ArgumentError` aus dem Konstruktor (V3) — ein falscher Wert in der
  /// eigenen Tabelle ist ein Programmierfehler, keine Datenlage.
  Future<List<AufteilungAb>> alle() async {
    final t = _db.mahlzeitAufteilungen;
    final zeilen =
        await (_db.select(t)
              ..where(
                (z) =>
                    z.fruehstueckPct.isNotNull() &
                    z.mittagPct.isNotNull() &
                    z.abendPct.isNotNull(),
              )
              ..orderBy([(z) => OrderingTerm.asc(z.abTag)]))
            .get();
    return [
      for (final z in zeilen)
        AufteilungAb(
          abTag: z.abTag,
          aufteilung: MahlzeitAufteilung(
            fruehstueck: z.fruehstueckPct!,
            mittag: z.mittagPct!,
            abend: z.abendPct!,
          ),
        ),
    ];
  }

  /// Legt [a] ab. Eine Aufteilung für einen Tag, der schon eine hat,
  /// **ersetzt** sie (V2). Der Snack wird nicht gespeichert (V1).
  Future<void> setze(AufteilungAb a) async {
    await _db
        .into(_db.mahlzeitAufteilungen)
        .insertOnConflictUpdate(
          MahlzeitAufteilungenCompanion(
            abTag: Value(a.abTag),
            fruehstueckPct: Value(a.aufteilung.fruehstueck),
            mittagPct: Value(a.aufteilung.mittag),
            abendPct: Value(a.aufteilung.abend),
          ),
        );
  }
}

final mahlzeitAufteilungRepositoryProvider =
    Provider<MahlzeitAufteilungRepository>(
      (ref) => MahlzeitAufteilungRepository(ref.watch(appCacheProvider)),
    );

/// Die Historie, **gehalten** (kein `autoDispose`). Kein `Messwert` — Tims
/// eigene Einstellung, leer heißt leer.
///
/// **Lesen legt nichts an** (Entscheidung 1): Ohne gesicherte Aufteilung
/// ist die Liste leer, und keine Mahlzeit hat ein Ziel. Der Startwert
/// steht nur im Formular.
final mahlzeitAufteilungenProvider =
    AsyncNotifierProvider<MahlzeitAufteilungenNotifier, List<AufteilungAb>>(
      MahlzeitAufteilungenNotifier.new,
    );

class MahlzeitAufteilungenNotifier extends AsyncNotifier<List<AufteilungAb>> {
  @override
  Future<List<AufteilungAb>> build() =>
      ref.watch(mahlzeitAufteilungRepositoryProvider).alle();

  /// Sichert [a] **ab heute** — dem Berliner Tag aus [clockProvider], nicht
  /// dem UTC-Tag (V2). Frühere Tage behalten ihre Aufteilung
  /// (Entscheidung 5); ein zweites Sichern am selben Tag ersetzt die Zeile.
  ///
  /// Uhr und Repository **vor** dem ersten `await`: Danach kann der
  /// Notifier schon neu aufgebaut sein. `await future` zuerst, sonst rennt
  /// das Schreiben mit dem noch laufenden ersten Lesen um die Reihenfolge.
  Future<void> setzeAbHeute(MahlzeitAufteilung a) async {
    final heute = BerlinCalendar.dayKey(ref.read(clockProvider)());
    final repo = ref.read(mahlzeitAufteilungRepositoryProvider);
    await future;
    await repo.setze(AufteilungAb(abTag: heute, aufteilung: a));
    await _uebernimm(repo);
  }

  /// Liest die Historie nach dem Schreiben neu — die Tabelle ist die
  /// Wahrheit, auch über die Ersetzung je Tag. Gesetzt wird nur, wenn sich
  /// etwas geändert hat und dieser Notifier noch lebt; ein gleicher Stand
  /// bewegte jeden Beobachter ohne Anlass.
  Future<void> _uebernimm(MahlzeitAufteilungRepository repo) async {
    final neu = await repo.alle();
    if (!ref.mounted) return;
    if (state.hasValue && listEquals(state.value, neu)) return;
    state = AsyncData(neu);
  }
}
