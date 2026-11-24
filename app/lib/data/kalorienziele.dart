// Die Historie des festen Kalorienziels (#410) — Werttyp, Repository und
// Provider. Die Tabelle selbst steht in `kalorienziel_tabelle.dart`.
//
// API und Vertrag sind durch `app/test/data/kalorienziele_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Woher die Anforderung kommt.** Tim, 07.11.2026: „Das Kalorienziel soll
// fest sein und sich nicht täglich ändern — außer der Coach passt es an."
// Die Ausgestaltung ist eine **Vorgabe des Koordinators**; Tim hat die
// Rückfrage dazu weggeklickt, sie also weder bestätigt noch verworfen:
// einmal mit der Formel für heute berechnen und speichern, danach gilt die
// gespeicherte Zahl ab ihrem Tag; jede Änderung gilt ab ihrem Tag, frühere
// Tage behalten die alte. Das Festlegen selbst steht in
// `ernaehrung/ernaehrung_provider.dart` (`kalorienzielFestlegenProvider`),
// weil nur dort die Rechnung des Tages bekannt ist.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Hinter der Historie steht kein Lauf aus Apple Health. Leer heißt leer.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Woher ein festes Ziel stammt. In der Tabelle als [name] des Werts
/// (`'berechnet'`, `'hand'`); `coach` kommt mit dem Coach dazu.
enum KalorienzielHerkunft { berechnet, hand }

/// Ein festgelegtes Kalorienziel — gilt ab [abTag] bis zur nächsten
/// Festlegung.
///
/// **Werttyp mit `==` und `hashCode` über alle Felder**, auch über die
/// [herkunft]: Dieselbe Zahl von Hand statt berechnet ist für die
/// Herleitung ein anderer Wert, und ein Provider, der den Unterschied nicht
/// mitbekommt, zeigte die alte Herkunft weiter an.
@immutable
class KalorienzielFestlegung {
  const KalorienzielFestlegung({
    required this.abTag,
    required this.kcal,
    required this.herkunft,
    this.anteile,
  });

  /// Der Tag, ab dem das Ziel gilt, als ISO-Tagesstring.
  final String abTag;

  final double kcal;

  final KalorienzielHerkunft herkunft;

  /// Die drei Anteile, aus denen die Zahl gerechnet wurde — nur bei
  /// [KalorienzielHerkunft.berechnet]. Von Hand gibt es keine: `null`,
  /// nicht drei Nullen.
  final KalorienzielAnteile? anteile;

  @override
  bool operator ==(Object other) =>
      other is KalorienzielFestlegung &&
      other.abTag == abTag &&
      other.kcal == kcal &&
      other.herkunft == herkunft &&
      other.anteile == anteile;

  @override
  int get hashCode => Object.hash(abTag, kcal, herkunft, anteile);

  @override
  String toString() =>
      'KalorienzielFestlegung(abTag: $abTag, kcal: $kcal, '
      'herkunft: ${herkunft.name}, anteile: $anteile)';
}

/// Die Festlegung, die an [tagesSchluessel] gilt: die mit dem spätesten
/// `abTag <= tagesSchluessel`. `null` vor der ersten.
///
/// Die Eingabe muss nicht sortiert sein. Verglichen wird lexikografisch —
/// beim ISO-Tagesstring ist das der Kalender, auch über einen
/// Jahreswechsel.
KalorienzielFestlegung? geltendeFestlegung(
  List<KalorienzielFestlegung> historie,
  String tagesSchluessel,
) {
  KalorienzielFestlegung? beste;
  for (final f in historie) {
    if (f.abTag.compareTo(tagesSchluessel) > 0) continue;
    if (beste == null || f.abTag.compareTo(beste.abTag) > 0) beste = f;
  }
  return beste;
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und der Historie — derselbe
/// Schnitt wie bei `StammdatenRepository`: SQL hier, Riverpod darunter.
class KalorienzielRepository {
  KalorienzielRepository(this._db);

  final AppCache _db;

  /// Alle Festlegungen, aufsteigend nach `abTag` — sortiert in SQL.
  Future<List<KalorienzielFestlegung>> alle() async {
    final zeilen = await (_db.select(
      _db.kalorienziele,
    )..orderBy([(t) => OrderingTerm.asc(t.abTag)])).get();
    return [for (final z in zeilen) _ausZeile(z)];
  }

  /// Legt [festlegung] ab. Eine Festlegung für einen Tag, der schon eine
  /// hat, **ersetzt** sie — samt ihren Anteilen: Die Anteile einer
  /// ersetzten Berechnung gehören nicht zu einem Ziel von Hand.
  ///
  /// Jedes Feld geht als `Value(...)` hinein, auch wenn es `null` ist —
  /// sonst blieben beim Ersetzen die alten Anteile stehen.
  Future<void> setze(KalorienzielFestlegung festlegung) async {
    final anteile = festlegung.anteile;
    await _db
        .into(_db.kalorienziele)
        .insertOnConflictUpdate(
          KalorienzieleCompanion(
            abTag: Value(festlegung.abTag),
            kcal: Value(festlegung.kcal),
            herkunft: Value(festlegung.herkunft.name),
            grundumsatzKcal: Value(anteile?.grundumsatzKcal),
            aktivKcal: Value(anteile?.aktivKcal),
            koerperzielKcal: Value(anteile?.koerperzielKcal),
          ),
        );
  }

  /// **Die Anteile kommen nur als ganze Gruppe zurück**: alle drei da, oder
  /// `null`. Zwei von drei wären eine Herleitung, deren Summe nicht die
  /// Zahl ist. `gemessen` ist immer `false` — festgelegt wird mit der
  /// Formel für heute, und die nimmt nie den gemessenen Verbrauch (#229).
  KalorienzielFestlegung _ausZeile(KalorienzielRow z) {
    final grund = z.grundumsatzKcal;
    final aktiv = z.aktivKcal;
    final koerper = z.koerperzielKcal;
    return KalorienzielFestlegung(
      abTag: z.abTag,
      kcal: z.kcal,
      herkunft: _herkunft(z.herkunft),
      anteile: grund == null || aktiv == null || koerper == null
          ? null
          : KalorienzielAnteile(
              grundumsatzKcal: grund,
              aktivKcal: aktiv,
              koerperzielKcal: koerper,
              gemessen: false,
            ),
    );
  }

  /// Ein unbekanntes Wort wirft, statt still zu einer Herkunft zu werden —
  /// ein falscher Wert in der eigenen Tabelle ist ein Programmierfehler,
  /// keine Datenlage. (`coach` kommt erst mit dem Coach dazu.)
  KalorienzielHerkunft _herkunft(String wort) =>
      KalorienzielHerkunft.values.byName(wort);
}

final kalorienzielRepositoryProvider = Provider<KalorienzielRepository>(
  (ref) => KalorienzielRepository(ref.watch(appCacheProvider)),
);

/// Die Historie, **gehalten**. Kein `Messwert` — Tims eigene Daten, leer
/// heißt leer.
final kalorienzieleProvider =
    AsyncNotifierProvider<KalorienzieleNotifier, List<KalorienzielFestlegung>>(
      KalorienzieleNotifier.new,
    );

class KalorienzieleNotifier
    extends AsyncNotifier<List<KalorienzielFestlegung>> {
  /// Läuft gerade ein Festlegen? Zwei Auslöser kurz hintereinander (etwa
  /// Gewicht und Stammdaten kommen im selben Augenblick an) sähen beide die
  /// leere Historie, bevor die erste Zeile geschrieben ist.
  bool _festlegenLaeuft = false;

  @override
  Future<List<KalorienzielFestlegung>> build() =>
      ref.watch(kalorienzielRepositoryProvider).alle();

  /// Ein Ziel von Hand, **ab heute** — dem Berliner Tag aus
  /// [clockProvider], nicht dem UTC-Tag: Um 23:30 UTC ist in Berlin im
  /// Sommer schon morgen. Am selben Tag ersetzt es eine frühere Festlegung.
  ///
  /// `await future` zuerst, aus demselben Grund wie bei
  /// `StammdatenNotifier.setze`: Sonst rennt das Schreiben mit dem noch
  /// laufenden ersten Lesen um die Reihenfolge.
  Future<void> setzeVonHand(double kcal) async {
    // Uhr und Repository **vor** dem ersten `await`: Danach kann der
    // Notifier schon neu aufgebaut sein, und sein `ref` ist dann nicht mehr
    // zu benutzen.
    final heute = BerlinCalendar.dayKey(ref.read(clockProvider)());
    final repo = ref.read(kalorienzielRepositoryProvider);
    await future;
    await repo.setze(
      KalorienzielFestlegung(
        abTag: heute,
        kcal: kcal,
        herkunft: KalorienzielHerkunft.hand,
      ),
    );
    await _uebernimm(repo);
  }

  /// Legt das **erste** Ziel fest — aber nur, solange die Tabelle leer ist.
  /// Steht eine Festlegung da, egal welcher Herkunft, legt die App nie
  /// wieder von selbst fest.
  ///
  /// Aufgerufen von `kalorienzielFestlegenProvider`; der kennt die Rechnung
  /// des Tages, diese Datei nicht.
  ///
  /// **Gefragt wird die Tabelle, nicht [state].** Der Aufruf kommt aus
  /// einem Mikrotask, und bis dahin kann dieser Notifier neu aufgebaut sein
  /// oder sein erstes Lesen noch laufen; die Tabelle ist in beiden Fällen
  /// die verlässliche Auskunft.
  Future<void> legeErstesFest(KalorienzielFestlegung festlegung) async {
    if (_festlegenLaeuft) return;
    _festlegenLaeuft = true;
    final repo = ref.read(kalorienzielRepositoryProvider);
    try {
      if ((await repo.alle()).isEmpty) await repo.setze(festlegung);
      await _uebernimm(repo);
    } finally {
      _festlegenLaeuft = false;
    }
  }

  /// Liest die Historie nach dem Schreiben neu und setzt sie — die Tabelle
  /// ist die Wahrheit, auch über die Ersetzung je Tag. Gesetzt wird nur,
  /// wenn sich etwas geändert hat und dieser Notifier noch lebt; ein
  /// gleicher Stand bewegte jeden Beobachter ohne Anlass.
  Future<void> _uebernimm(KalorienzielRepository repo) async {
    final neu = await repo.alle();
    if (!ref.mounted) return;
    if (state.hasValue && listEquals(state.value, neu)) return;
    state = AsyncData(neu);
  }
}
