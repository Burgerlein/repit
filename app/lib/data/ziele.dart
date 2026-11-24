// Tims Ziele (#111): Schlafziel, Schlafenszeitziel und Wochenziel
// Trainingsminuten. Ablage, Vorbelegung und der Weg, sie zu setzen — der
// Schirm dafür kommt aus #31.
//
// API und Vertrag sind durch `app/test/data/ziele_test.dart` verbindlich
// vorgegeben (siehe dessen Dateikopf) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.** Das
// sind Tims eigene Daten, kein Lauf aus Apple Health, der leer ausgehen
// könnte. Eine leere Tabelle heißt „noch nichts eingestellt", und darauf
// antwortet die Ablage mit [Ziele.vorbelegung], nicht mit einem Leerzustand.
//
// **Nicht zu verwechseln mit `lib/shell/ziele.dart`** — das ist `AppTarget`,
// das Sprungziel des Routers, und bleibt unberührt.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Die drei Ziele als ein Wert.
///
/// **Beide Zeiten liegen als ganze Minuten vor.** Das Schlafziel in Minuten
/// statt Stunden, damit „7:30 h" ohne Gleitkommarundung ausdrückbar bleibt;
/// das Schlafenszeitziel als Minuten **nach Mitternacht** — nicht auf der
/// 18-Uhr-Skala, auf der die Zubettgehzeit-Formel (#110) rechnet und
/// ausdrücklich negative Werte zulässt. Die Ablage soll lesbar sein, ohne
/// die Formel zu kennen; eine Umrechnung an dieser Kante hätte ein
/// Vorzeichen zu viel.
@immutable
class Ziele {
  const Ziele({
    required this.schlafzielMinuten,
    required this.schlafenszeitMinuten,
    required this.wochenzielTrainingsminuten,
  });

  /// Schlafziel in Minuten, 1 bis 1440.
  final int schlafzielMinuten;

  /// Übliche Schlafenszeit als Minuten nach Mitternacht, 0 bis 1439.
  final int schlafenszeitMinuten;

  /// Wochenziel Trainingsminuten, 0 oder mehr.
  final int wochenzielTrainingsminuten;

  /// Die **einzige** Stelle im Quelltext, an der diese drei Zahlen stehen
  /// (SPEC 3: Schlafziel 8 h, übliche Schlafenszeit 22:30; Spec 10a Punkt 4:
  /// das Wochenziel Trainingsminuten). Keine Zielkonstante sonst, nirgends —
  /// #41 liest später auf denselben Wert.
  ///
  /// Als Dart-Konstante und **nicht** als vorab eingefügte Datenbankzeile:
  /// Sonst gäbe es die Vorbelegung an zwei Orten, in der Migration und im
  /// Code, und einer von beiden wäre irgendwann der falsche.
  static const Ziele vorbelegung = Ziele(
    schlafzielMinuten: 480, // 8 h
    schlafenszeitMinuten: 1350, // 22:30, also 22 · 60 + 30
    wochenzielTrainingsminuten: 210,
  );

  Ziele kopieMit({
    int? schlafzielMinuten,
    int? schlafenszeitMinuten,
    int? wochenzielTrainingsminuten,
  }) => Ziele(
    schlafzielMinuten: schlafzielMinuten ?? this.schlafzielMinuten,
    schlafenszeitMinuten: schlafenszeitMinuten ?? this.schlafenszeitMinuten,
    wochenzielTrainingsminuten:
        wochenzielTrainingsminuten ?? this.wochenzielTrainingsminuten,
  );

  // Wertgleichheit aus demselben Grund wie bei `DataWindow`: Riverpod
  // berechnet abgeleitete Provider nur neu, wenn die Abhängigkeit ungleich
  // vergleicht. Ohne `==` baute jeder Lesevorgang ein neues, ungleiches
  // Objekt, und jeder Beobachter rechnete neu, obwohl sich nichts geändert
  // hat.
  @override
  bool operator ==(Object other) =>
      other is Ziele &&
      other.schlafzielMinuten == schlafzielMinuten &&
      other.schlafenszeitMinuten == schlafenszeitMinuten &&
      other.wochenzielTrainingsminuten == wochenzielTrainingsminuten;

  @override
  int get hashCode => Object.hash(
    schlafzielMinuten,
    schlafenszeitMinuten,
    wochenzielTrainingsminuten,
  );

  @override
  String toString() =>
      'Ziele(schlafzielMinuten: $schlafzielMinuten, '
      'schlafenszeitMinuten: $schlafenszeitMinuten, '
      'wochenzielTrainingsminuten: $wochenzielTrainingsminuten)';
}

/// Das Schritteziel je Tag — die **eine** Stelle, an der diese Zahl steht
/// (`docs/SPEC.md` 3: „Schritteziel 8.000"), wie [Ziele.vorbelegung] für
/// die drei Ziele darüber.
///
/// **Noch eine Konstante, keine Spalte in `ZielWerte`:** Es gibt keinen
/// Schirm, der das Schritteziel einstellt — eine Datenbankspalte ohne
/// Schreibweg wäre eine Migration für nichts. Sobald der Ziele-Schirm
/// (#31/#41) es einstellbar macht, wandert der Wert als Vorbelegung in die
/// Ablage, und diese Konstante wird ihr Default — derselbe Weg, den die
/// drei Ziele oben gegangen sind.
///
/// Kein Ereignis und kein Datum, nur eine Zielgröße — die Regel „keine
/// hartcodierten Ereignisse" (`CLAUDE.md`) betrifft sie nicht. In der
/// Swift-Vorlage steht dieselbe Zahl im **Schirm** (`StepsView.swift`);
/// genau das ist hier vermieden: Der Schirm liest diese Konstante.
const int schritteTagesziel = 8000;

/// Lese-/Schreib-Brücke zwischen `AppCache` und [Ziele] — derselbe Schnitt
/// wie bei `CacheRepository`: SQL hier, Riverpod nebenan.
class ZieleRepository {
  ZieleRepository(this._db);

  final AppCache _db;

  /// [Ziele.vorbelegung], solange nichts abgelegt ist. Kein `null`, kein
  /// Leerzustand: Eine fehlende Zeile ist keine fehlende Antwort, sondern
  /// „noch nichts eingestellt".
  Future<Ziele> lies() async {
    final zeile = await _db.select(_db.zielWerte).getSingleOrNull();
    if (zeile == null) return Ziele.vorbelegung;
    return Ziele(
      schlafzielMinuten: zeile.schlafzielMinuten,
      schlafenszeitMinuten: zeile.schlafenszeitMinuten,
      wochenzielTrainingsminuten: zeile.wochenzielTrainingsminuten,
    );
  }

  /// Schreibt die eine Zeile, überschreibend — Ziele sind kein Verlauf.
  ///
  /// Wirft `ArgumentError` bei unmöglichen Werten. Die Prüfung sitzt hier
  /// und nicht im `const`-Konstruktor von [Ziele], weil ein
  /// `const`-Konstruktor nicht werfen kann; die Ablage ist die enge Stelle,
  /// durch die jeder Wert muss.
  Future<void> schreibe(Ziele ziele) async {
    if (ziele.schlafzielMinuten < 1 || ziele.schlafzielMinuten > 1440) {
      throw ArgumentError.value(
        ziele.schlafzielMinuten,
        'schlafzielMinuten',
        'Ein Schlafziel liegt zwischen 1 Minute und 24 Stunden',
      );
    }
    if (ziele.schlafenszeitMinuten < 0 || ziele.schlafenszeitMinuten > 1439) {
      throw ArgumentError.value(
        ziele.schlafenszeitMinuten,
        'schlafenszeitMinuten',
        'Eine Tageszeit liegt zwischen 0 und 1439 Minuten nach Mitternacht',
      );
    }
    if (ziele.wochenzielTrainingsminuten < 0) {
      throw ArgumentError.value(
        ziele.wochenzielTrainingsminuten,
        'wochenzielTrainingsminuten',
        'Weniger als keine Minute Training gibt es nicht',
      );
    }

    await _db
        .into(_db.zielWerte)
        .insertOnConflictUpdate(
          ZielWerteCompanion.insert(
            id: const Value(_einzigeZeile),
            schlafzielMinuten: ziele.schlafzielMinuten,
            schlafenszeitMinuten: ziele.schlafenszeitMinuten,
            wochenzielTrainingsminuten: ziele.wochenzielTrainingsminuten,
          ),
        );
  }

  /// Der Schlüssel der einen Zeile. Eine zweite wäre ein zweiter,
  /// widersprechender Stand.
  static const _einzigeZeile = 0;
}

final zieleRepositoryProvider = Provider<ZieleRepository>(
  (ref) => ZieleRepository(ref.watch(appCacheProvider)),
);

/// Die Ziele, lesbar und änderbar.
final zieleProvider = AsyncNotifierProvider<ZieleNotifier, Ziele>(
  ZieleNotifier.new,
);

class ZieleNotifier extends AsyncNotifier<Ziele> {
  @override
  Future<Ziele> build() => ref.watch(zieleRepositoryProvider).lies();

  /// Schreibt durch bis in die Datenbank und setzt den Zustand — sonst wäre
  /// es wieder ein `@State`, das beim Verlassen des Schirms vergisst.
  ///
  /// `await future` zuerst: Ohne das könnte ein `setze` direkt nach dem
  /// ersten `read` mit dem noch laufenden `build()` um die Reihenfolge
  /// rennen, und der frisch gesetzte Zustand würde vom älteren Lesevorgang
  /// wieder überschrieben.
  Future<void> setze(Ziele ziele) async {
    await future;
    await ref.read(zieleRepositoryProvider).schreibe(ziele);
    state = AsyncData(ziele);
  }
}

/// Übersetzt den äußeren `AsyncValue` für die Oberfläche — dasselbe Muster
/// wie `heuteZustandAusProvider` in `lib/shell/heute_view.dart`, damit
/// `AsyncValue` in der Widget-Schicht nicht auftaucht (Spec 5.4).
///
/// `laedt` sagt „noch nicht nachgesehen", **nicht** „nichts da": Wer die
/// Zeile „Schlafziel 8:00 h" zeichnet, soll den Unterschied kennen.
/// Ein gescheiterter Lesevorgang zeigt ebenfalls die Vorbelegung — eine
/// leere Zeile wäre eine Behauptung über etwas, das niemand eingestellt hat.
({bool laedt, Ziele ziele}) zieleAusProvider(AsyncValue<Ziele> zustand) => (
  laedt: zustand.isLoading,
  ziele: zustand.value ?? Ziele.vorbelegung,
);
