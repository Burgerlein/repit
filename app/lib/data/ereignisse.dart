// Die Ereignisse — heute die Auszeiten OP, Krankheit, Verletzung und
// Urlaub (#446 unter #404): Werttyp, Repository und Provider. Die Tabelle
// selbst steht in `ereignis_tabelle.dart`.
//
// API und Vertrag sind durch `app/test/data/ereignisse_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht
// die Implementierung"). Spec: die Auszeit-Spec in
// `docs/superpowers/specs/`, Abschnitt „Repository und Provider".
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Ein Ereignis ist Tims eigene Angabe; leer heißt leer. Welche Auszeit an
// einem Tag pausiert, rechnet der Kern (`pausierendeAuszeitAm`), nicht
// diese Datei.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Ein abgelegtes oder abzulegendes Ereignis.
///
/// **Werttyp mit `==` und `hashCode` über alle Felder** — er ist Zustand
/// von [ereignisseProvider], und ein Vergleich nach Identität ließe jeden
/// Beobachter bei jedem Neulesen neu rechnen (Hausregel 2).
@immutable
class Ereignis {
  const Ereignis({
    this.id,
    required this.art,
    required this.von,
    required this.bis,
    this.notiz,
    this.angelegt,
    this.geaendert,
  });

  /// Die Zeilennummer; `null`, solange das Ereignis nicht abgelegt ist.
  final int? id;

  final EreignisArt art;

  /// Erster Tag, einschließlich, als ISO-Tagesschlüssel.
  final String von;

  /// Letzter Tag, einschließlich, als ISO-Tagesschlüssel.
  final String bis;

  /// Freitext, `null`, wenn keiner eingetragen ist.
  final String? notiz;

  /// Wann die Zeile angelegt wurde, UTC. Gesetzt vom Repository.
  final DateTime? angelegt;

  /// Wann die Zeile zuletzt geändert wurde, UTC; `null` bis zur ersten
  /// Änderung.
  final DateTime? geaendert;

  /// Id, Art und Zeitraum für die Rechnung im Kern.
  ///
  /// **Wirft ohne [id]:** Ein nicht abgelegtes Ereignis hat keine Nummer,
  /// die bei gleichem `bis` entscheiden könnte (V3). Eine erfundene Nummer
  /// entschiede still falsch.
  AuszeitTage get tage {
    final nummer = id;
    if (nummer == null) {
      throw StateError('Ein Ereignis ohne id hat keine AuszeitTage.');
    }
    return AuszeitTage(id: nummer, art: art, von: von, bis: bis);
  }

  @override
  bool operator ==(Object other) =>
      other is Ereignis &&
      other.id == id &&
      other.art == art &&
      other.von == von &&
      other.bis == bis &&
      other.notiz == notiz &&
      other.angelegt == angelegt &&
      other.geaendert == geaendert;

  @override
  int get hashCode =>
      Object.hash(id, art, von, bis, notiz, angelegt, geaendert);

  @override
  String toString() =>
      'Ereignis(id: $id, art: ${art.name}, von: $von, bis: $bis, '
      'notiz: $notiz, angelegt: $angelegt, geaendert: $geaendert)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und den Ereignissen — derselbe
/// Schnitt wie bei `KalorienzielRepository`: SQL hier, Riverpod darunter.
class EreignisRepository {
  EreignisRepository(this._db, {this._uhr = DateTime.now});

  final AppCache _db;
  final DateTime Function() _uhr;

  /// Alle Ereignisse, `von` absteigend, bei gleichem `von` `id` absteigend
  /// (V8) — **sortiert in SQL**. Der ISO-Tagesschlüssel sortiert
  /// lexikografisch wie der Kalender, auch über einen Jahreswechsel.
  ///
  /// **Eine Zeile mit unbekannter Art wird übergangen, nicht geworfen und
  /// nicht gelöscht** (V20): Eine spätere Fassung schreibt `spieltag`
  /// (#389), und eine ältere soll dann trotzdem öffnen.
  Future<List<Ereignis>> alle() async {
    final zeilen =
        await (_db.select(_db.ereignisse)..orderBy([
              (t) => OrderingTerm.desc(t.von),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    final arten = EreignisArt.values.asNameMap();
    return [
      for (final z in zeilen)
        if (arten[z.art] case final art?)
          Ereignis(
            id: z.id,
            art: art,
            von: z.von,
            bis: z.bis,
            notiz: z.notiz,
            angelegt: z.angelegt,
            geaendert: z.geaendert,
          ),
    ];
  }

  /// Legt [ereignis] ab und gibt die neue `id` zurück.
  ///
  /// `angelegt` kommt **immer aus der Uhr**, als UTC; `geaendert` bleibt
  /// `NULL` — Anlegen ist keine Änderung. Zeitstempel und `id` des
  /// übergebenen Ereignisses werden nicht übernommen. Die Notiz geht so
  /// hinein, wie sie kommt; getrimmt wird im Formular (V6).
  Future<int> legeAn(Ereignis ereignis) => _db
      .into(_db.ereignisse)
      .insert(
        EreignisseCompanion.insert(
          art: ereignis.art.name,
          von: ereignis.von,
          bis: ereignis.bis,
          notiz: Value(ereignis.notiz),
          angelegt: _uhr().toUtc(),
        ),
      );

  /// Schreibt Art, Zeitraum und Notiz von [ereignis] in die Zeile mit
  /// seiner `id` und setzt `geaendert` aus der Uhr. `angelegt` bleibt, wie
  /// es in der Tabelle steht.
  ///
  /// Die Notiz geht als `Value(...)` hinein, auch wenn sie `null` ist —
  /// sonst bliebe eine gelöschte Notiz stehen.
  Future<void> aendere(Ereignis ereignis) async {
    final id = ereignis.id;
    if (id == null) {
      throw ArgumentError.value(
        ereignis,
        'ereignis',
        'Ändern braucht die id einer abgelegten Zeile.',
      );
    }
    await (_db.update(_db.ereignisse)..where((t) => t.id.equals(id))).write(
      EreignisseCompanion(
        art: Value(ereignis.art.name),
        von: Value(ereignis.von),
        bis: Value(ereignis.bis),
        notiz: Value(ereignis.notiz),
        geaendert: Value(_uhr().toUtc()),
      ),
    );
  }

  /// Löscht die Zeile mit [id].
  Future<void> loesche(int id) =>
      (_db.delete(_db.ereignisse)..where((t) => t.id.equals(id))).go();
}

/// Das Repository mit der Uhr der App ([clockProvider]).
final ereignisRepositoryProvider = Provider<EreignisRepository>(
  (ref) => EreignisRepository(
    ref.watch(appCacheProvider),
    uhr: ref.watch(clockProvider),
  ),
);

/// Die Ereignisse, **gehalten**, sortiert wie [EreignisRepository.alle].
/// Kein `Messwert` — Tims eigene Daten, leer heißt leer.
final ereignisseProvider =
    AsyncNotifierProvider<EreignisseNotifier, List<Ereignis>>(
      EreignisseNotifier.new,
    );

class EreignisseNotifier extends AsyncNotifier<List<Ereignis>> {
  @override
  Future<List<Ereignis>> build() =>
      ref.watch(ereignisRepositoryProvider).alle();

  /// Legt [ereignis] ab, liest neu und gibt die neue `id` zurück.
  Future<int> legeAn(Ereignis ereignis) async {
    final repo = await _bereit();
    final id = await repo.legeAn(ereignis);
    await _uebernimm(repo);
    return id;
  }

  /// Ändert die Zeile von [ereignis] und liest neu.
  Future<void> aendere(Ereignis ereignis) async {
    final repo = await _bereit();
    await repo.aendere(ereignis);
    await _uebernimm(repo);
  }

  /// Löscht die Zeile mit [id] und liest neu.
  Future<void> loesche(int id) async {
    final repo = await _bereit();
    await repo.loesche(id);
    await _uebernimm(repo);
  }

  /// Das Repository, nachdem das erste Lesen fertig ist.
  ///
  /// Das Repository wird **vor** dem ersten `await` gegriffen: Danach kann
  /// der Notifier schon neu aufgebaut sein, und sein `ref` ist dann nicht
  /// mehr zu benutzen. Gewartet wird, damit das Schreiben nicht mit dem
  /// noch laufenden ersten Lesen um die Reihenfolge rennt (wie bei
  /// `KalorienzieleNotifier`). **Ein gescheitertes erstes Lesen hält das
  /// Schreiben nicht auf** — nach dem Schreiben wird ohnehin neu gelesen,
  /// und scheitert das Schreiben selbst, sieht der Aufrufer dessen Fehler.
  Future<EreignisRepository> _bereit() async {
    final repo = ref.read(ereignisRepositoryProvider);
    try {
      await future;
    } on Object {
      // Siehe oben: Der Lesefehler steht schon im Zustand.
    }
    return repo;
  }

  /// Liest nach dem Schreiben neu — die Tabelle ist die Wahrheit, auch über
  /// die Sortierung. Gesetzt wird nur, wenn dieser Notifier noch lebt und
  /// sich etwas geändert hat; ein gleicher Stand bewegte jeden Beobachter
  /// ohne Anlass.
  Future<void> _uebernimm(EreignisRepository repo) async {
    final neu = await repo.alle();
    if (!ref.mounted) return;
    if (state.hasValue && listEquals(state.value, neu)) return;
    state = AsyncData(neu);
  }
}

/// Der Stand der Auszeiten, wie die Rechnung ihn braucht.
typedef AuszeitenStand = ({bool laden, List<AuszeitTage> auszeiten});

/// Alle Ereignisse als [AuszeitTage], in der Reihenfolge von
/// [EreignisRepository.alle], Urlaub eingeschlossen — welche davon an
/// einem Tag pausiert, entscheidet `pausierendeAuszeitAm` im Kern.
///
/// - **Noch nicht gelesen:** `laden`, leere Liste. Die Rechnung zeigt dann
///   kein Ziel, statt kurz eines mit Aufschlag (V12).
/// - **Gelesen:** die Auszeiten.
/// - **Lesen gescheitert:** nicht `laden`, leere Liste — gerechnet wird
///   ohne Pause. Ein Ziel, das wegen einer unlesbaren Tabelle für immer
///   lädt, wäre die schlechtere Auskunft (dasselbe Muster wie
///   `kalorienzielHistorie`).
///
/// **Meldet sich nur, wenn sich an den Tagen etwas ändert** (Hausregel 2).
/// Ein Record vergleicht seine `List` nach Identität, eine neu gelesene,
/// gleiche Liste wäre also ungleich — und jede geänderte Notiz rechnete
/// jeden Tag des Verlaufs neu. Deshalb behält [AuszeitenNotifier] bei
/// gleichem Inhalt den vorigen Stand, dasselbe Objekt.
final auszeitenProvider = NotifierProvider<AuszeitenNotifier, AuszeitenStand>(
  AuszeitenNotifier.new,
);

class AuszeitenNotifier extends Notifier<AuszeitenStand> {
  @override
  AuszeitenStand build() {
    final neu = _standAus(ref.watch(ereignisseProvider));
    final vorher = stateOrNull;
    if (vorher != null &&
        vorher.laden == neu.laden &&
        listEquals(vorher.auszeiten, neu.auszeiten)) {
      return vorher;
    }
    return neu;
  }

  static AuszeitenStand _standAus(AsyncValue<List<Ereignis>> zustand) {
    if (zustand.hasValue) {
      return (
        laden: false,
        auszeiten: List.unmodifiable([for (final e in zustand.value!) e.tage]),
      );
    }
    if (zustand.hasError) return (laden: false, auszeiten: const []);
    return (laden: true, auszeiten: const []);
  }
}
