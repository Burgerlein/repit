// Tims Stammdaten (Ernährungsplan Task 1, Schema v11): Körpergröße,
// Geburtsjahr, Zielgewicht und Zieldatum. Vier Angaben, die nicht aus
// Apple Health kommen und keinen Verlauf haben — aus Größe, Alter und
// Gewicht entsteht der Grundumsatz, aus Zielgewicht und Zieldatum der
// Überschuss aus dem Körperziel. Ohne sie gibt es kein Kalorienziel
// (`docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, „Stammdaten
// und Körperziel — das Minimum für den Ring").
//
// API und Vertrag sind durch `app/test/data/schema_v11_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die Tabelle selbst steht in `tables.dart`**, neben den anderen sieben,
// und heißt dort `Stammdaten` mit `@DataClassName('StammdatenRow')` — die
// Hausform, der auch `ZielWerte`/`ZielWerteRow` folgt. Hier liegt der
// Werttyp gleichen Namens: Beide in einer Datei ginge nicht, und der
// Umweg über einen abweichenden Tabellennamen brächte einen
// `tableName`-Übersteuerer und einen Ringimport zwischen `cache.dart` und
// dieser Datei ein, den sonst keine Ablage hat.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Hinter den vier Feldern steht kein Lauf aus Apple Health, der leer
// ausgehen könnte, sondern Tim. Leer heißt leer.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import '../health/health_reading.dart';
import '../health/health_types.dart';
import 'cache.dart';

/// Die vier Angaben über Tim als ein Wert.
///
/// **Alle vier Felder sind nullbar, und das ist der Kern dieses Typs.**
/// Solange nichts eingetragen ist, steht dort nichts: kein `0`, kein
/// vorbelegtes Geburtsjahr, kein Platzhalterdatum. Ein Mensch mit 0 cm ist
/// kein fehlender Wert, und ein Grundumsatz aus einer erfundenen Größe
/// sähe aus wie eine Rechnung und wäre eine Behauptung — Fehler `01` eine
/// Schicht tiefer.
///
/// **Anders als bei `Ziele` gibt es deshalb keine Vorbelegung.** Acht
/// Stunden Schlaf sind eine Empfehlung, die für jeden gilt; eine
/// Körpergröße gilt für niemanden außer Tim. `const Stammdaten()` — alle
/// vier Felder weggelassen — ist der leere Stand und die Antwort auf eine
/// leere Tabelle.
@immutable
class Stammdaten {
  const Stammdaten({
    this.groesseCm,
    this.geburtsjahr,
    this.zielgewichtKg,
    this.zieldatum,
  });

  /// Körpergröße in ganzen Zentimetern, `null` solange nichts eingetragen
  /// ist.
  final int? groesseCm;

  /// Geburtsjahr als vierstellige Jahreszahl — kein Geburtsdatum:
  /// Mifflin-St Jeor braucht das Alter in Jahren, ein volles Datum wäre
  /// eine Angabe mehr, als die Formel trägt.
  final int? geburtsjahr;

  /// Zielgewicht in Kilogramm. `double`, nicht `int`: Eine Ganzzahl zwänge
  /// zum Runden, und das wäre eine stille Veränderung von Tims Wert.
  final double? zielgewichtKg;

  /// Das Zieldatum als **ISO-Tagesstring** (`YYYY-MM-DD`), nicht als
  /// `DateTime`. Ein Zieldatum ist eine Kalenderangabe, kein Zeitpunkt;
  /// ein Umweg über `DateTime` und zurück verschöbe den Tag auf einem
  /// anders eingestellten Gerät um einen (`CLAUDE.md`, „Der Datumsschlüssel
  /// ist der ISO-Tagesstring").
  final String? zieldatum;

  /// Tims Alter in vollen Jahren an [zeitpunkt] — `null`, solange kein
  /// Geburtsjahr bekannt ist.
  ///
  /// **Hier und nicht beim Aufrufer.** `kalorienziel` nimmt ein `alter`,
  /// [Stammdaten] trägt ein [geburtsjahr], und dazwischen stand bislang
  /// nichts; ohne eine Stelle stünde dieselbe Subtraktion am Ende in jedem
  /// Schirm noch einmal.
  ///
  /// **`null`, nicht `0`.** Ein Alter von 0 wäre eine Angabe über Tim, die
  /// niemand gemacht hat, und `kalorienziel` rechnete damit eine Zahl aus,
  /// die wie ein Ergebnis aussieht — Fehler `01` in der Rechnung statt in
  /// der Anzeige.
  ///
  /// **Das Jahr kommt aus dem Berliner Kalender**, nicht aus
  /// `zeitpunkt.year`: Die ganze Zeitrechnung der App läuft über
  /// UTC-Zeitpunkte, die Berliner Tagesgrenzen bezeichnen (`CLAUDE.md`).
  /// Der 1. Januar beginnt als `31.12. 23:00 UTC` — `zeitpunkt.year` gäbe
  /// dort das Vorjahr und machte Tim an einem Tag im Jahr ein Jahr jünger.
  ///
  /// **Nur aus dem Jahrgang, nicht aus einem Geburtstag.** Wer in diesem
  /// Jahr noch Geburtstag hat, ist hier bereits ein Jahr älter; für den
  /// Grundumsatz ist das folgenlos (Mifflin-St Jeor gewichtet das Alter mit
  /// rund 5 kcal je Jahr), und ein volles Geburtsdatum trägt [Stammdaten]
  /// bewusst nicht.
  ///
  /// **Zwei Grenzen, die der Rückgabetyp nicht zeigt** (gefunden beim
  /// Nachtest am 04.11.2026, `test/data/stammdaten_alter_test.dart`):
  ///
  /// - `null` heißt hier **nur** „kein Geburtsjahr bekannt". Eine `0` oder
  ///   eine negative Zahl kommt trotzdem heraus, wenn der Zeitpunkt im
  ///   Jahrgang selbst oder davor liegt. Das ist Absicht und nicht
  ///   gefangen: `null` ist schon vergeben, ein zweiter Grund dafür machte
  ///   die Auskunft mehrdeutig, und ein Wurf verwandelte eine Datenlage in
  ///   einen Absturz. Nach unten fängt es `kalorienziel` ab
  ///   (`alter == null || alter <= 0` → kein Ziel berechenbar).
  /// - Das Jahr kommt aus [BerlinCalendar], und dessen Sommerzeitregel
  ///   **gilt ab 1996**. Für „jetzt" und für den angezeigten Tag ist das
  ///   folgenlos; für einen Zeitpunkt vor 1996 wäre die Tagesgrenze und
  ///   damit am 1. Januar auch das Jahr falsch.
  int? alterAm(DateTime zeitpunkt) {
    final jahrgang = geburtsjahr;
    if (jahrgang == null) return null;
    return int.parse(BerlinCalendar.dayKey(zeitpunkt).substring(0, 4)) -
        jahrgang;
  }

  Stammdaten kopieMit({
    int? groesseCm,
    int? geburtsjahr,
    double? zielgewichtKg,
    String? zieldatum,
  }) => Stammdaten(
    groesseCm: groesseCm ?? this.groesseCm,
    geburtsjahr: geburtsjahr ?? this.geburtsjahr,
    zielgewichtKg: zielgewichtKg ?? this.zielgewichtKg,
    zieldatum: zieldatum ?? this.zieldatum,
  );

  // Wertgleichheit aus demselben Grund wie bei `Ziele` und `DataWindow`:
  // Riverpod rechnet Abgeleitetes neu, sobald die Abhängigkeit ungleich
  // vergleicht. Ohne `==` baute jeder Lesevorgang ein neues, ungleiches
  // Objekt, und Grundumsatz, Kalorienziel und der ganze Ernährungsschirm
  // rechneten bei jedem Zugriff neu. Das wäre Fehler `03`, wortgleich, im
  // neuen Code.
  @override
  bool operator ==(Object other) =>
      other is Stammdaten &&
      other.groesseCm == groesseCm &&
      other.geburtsjahr == geburtsjahr &&
      other.zielgewichtKg == zielgewichtKg &&
      other.zieldatum == zieldatum;

  @override
  int get hashCode =>
      Object.hash(groesseCm, geburtsjahr, zielgewichtKg, zieldatum);

  @override
  String toString() =>
      'Stammdaten(groesseCm: $groesseCm, geburtsjahr: $geburtsjahr, '
      'zielgewichtKg: $zielgewichtKg, zieldatum: $zieldatum)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und [Stammdaten] — derselbe
/// Schnitt wie bei `ZieleRepository`: SQL hier, Riverpod nebenan.
class StammdatenRepository {
  StammdatenRepository(this._db);

  final AppCache _db;

  /// Vier `null`, solange nichts abgelegt ist — **keine Vorbelegung**.
  /// Eine geratene Körpergröße wäre eine Angabe über Tim, die niemand
  /// gemacht hat.
  Future<Stammdaten> lies() async {
    final zeile = await _db.select(_db.stammdaten).getSingleOrNull();
    if (zeile == null) return const Stammdaten();
    return Stammdaten(
      groesseCm: zeile.groesseCm,
      geburtsjahr: zeile.geburtsjahr,
      zielgewichtKg: zeile.zielgewichtKg,
      zieldatum: zeile.zieldatum,
    );
  }

  /// Schreibt die eine Zeile, überschreibend — Stammdaten sind kein
  /// Verlauf.
  ///
  /// **Jedes Feld geht als `Value(...)` hinein, auch wenn es `null` ist**,
  /// und nie als `Value.absent()`: Wer ein Feld löscht, hat es gelöscht.
  /// Ein Schreibweg, der `null` als „nicht angegeben, bitte stehen lassen"
  /// liest, machte das Leeren unmöglich — und zwar lautlos.
  ///
  /// **Ohne Plausibilitätsprüfung**, anders als bei `ZieleRepository`.
  /// Dort gibt es für jeden Wert eine Grenze, die aus der Sache folgt
  /// (eine Tageszeit hat 1440 Minuten); hier gibt es keine, die nicht
  /// geraten wäre. Eine untere Schranke für das Geburtsjahr oder eine
  /// obere für die Körpergröße wiese irgendwann einen Wert zurück, der
  /// stimmt. Was offensichtlich unsinnig ist, fängt das Formular ab, bevor
  /// es hier ankommt.
  Future<void> schreibe(Stammdaten stammdaten) async {
    await _db
        .into(_db.stammdaten)
        .insertOnConflictUpdate(
          StammdatenCompanion.insert(
            id: const Value(_einzigeZeile),
            groesseCm: Value(stammdaten.groesseCm),
            geburtsjahr: Value(stammdaten.geburtsjahr),
            zielgewichtKg: Value(stammdaten.zielgewichtKg),
            zieldatum: Value(stammdaten.zieldatum),
          ),
        );
  }

  /// Der Schlüssel der einen Zeile. Eine zweite wäre ein zweiter,
  /// widersprechender Stand.
  static const _einzigeZeile = 0;
}

final stammdatenRepositoryProvider = Provider<StammdatenRepository>(
  (ref) => StammdatenRepository(ref.watch(appCacheProvider)),
);

/// Tims Stammdaten, lesbar und änderbar.
final stammdatenProvider =
    AsyncNotifierProvider<StammdatenNotifier, Stammdaten>(
      StammdatenNotifier.new,
    );

class StammdatenNotifier extends AsyncNotifier<Stammdaten> {
  @override
  Future<Stammdaten> build() => ref.watch(stammdatenRepositoryProvider).lies();

  /// Schreibt durch bis in die Datenbank und setzt den Zustand — sonst
  /// wäre es ein Formularzustand, der beim Verlassen des Schirms vergisst.
  ///
  /// `await future` zuerst, aus demselben Grund wie bei
  /// `ZieleNotifier.setze`: Ohne das könnte ein `setze` direkt nach dem
  /// ersten `read` mit dem noch laufenden `build()` um die Reihenfolge
  /// rennen, und der frisch gesetzte Zustand würde vom älteren Lesevorgang
  /// wieder überschrieben.
  Future<void> setze(Stammdaten stammdaten) async {
    await future;
    await ref.read(stammdatenRepositoryProvider).schreibe(stammdaten);
    state = AsyncData(stammdaten);
  }
}

/// Übersetzt den äußeren `AsyncValue` für die Oberfläche — dasselbe Muster
/// wie `zieleAusProvider`, damit `AsyncValue` in der Widget-Schicht nicht
/// auftaucht (Spec 5.4).
///
/// `laedt` sagt „noch nicht nachgesehen", **nicht** „nichts da". Ein
/// gescheiterter Lesevorgang liefert den leeren Stand: Vier `null` heißen
/// „nichts eingetragen", und das ist bei einem Fehler die ehrlichere
/// Auskunft als eine Zahl.
({bool laedt, Stammdaten stammdaten}) stammdatenAusProvider(
  AsyncValue<Stammdaten> zustand,
) => (
  laedt: zustand.isLoading,
  stammdaten: zustand.value ?? const Stammdaten(),
);

/// Füllt die **Lücken** in Tims Stammdaten aus Apple Health (#306). Wer ihn
/// beobachtet, stößt den Lauf an.
///
/// Körpergröße und Geburtsdatum stehen seit der Installation im Lesekatalog
/// (`HealthTypeCatalog.swift`) und wurden nie abgefragt. Ohne sie rechnet
/// `kalorienziel` **nichts** — mit ihnen steht im Ernährungsring sofort eine
/// echte Zahl, ohne dass Tim etwas einträgt.
///
/// Fünf Zusagen, und jede hat ihren Grund:
///
/// 1. **Er füllt, er überschreibt nicht.** Was Tim eingetragen hat, ist eine
///    Angabe über ihn; was in Health steht, kann von einer alten Waage, einer
///    anderen App oder einem Tippfehler von vor Jahren stammen. Wer von Hand
///    korrigiert und beim nächsten Start denselben falschen Wert
///    wiederfindet, hört auf zu korrigieren.
/// 2. **Er fragt nicht, wenn es nichts zu füllen gibt.** Die Größe ändert
///    sich nicht täglich; der Wert wird gelesen und **abgelegt**. Umgekehrt
///    darf er wieder fragen, solange eine Lücke bleibt — sonst wäre ein
///    Health-Eintrag, der erst morgen entsteht, für immer unerreichbar.
/// 3. **Er beobachtet [freigabeProvider] (#176).** Der erste Lesezugriff
///    läuft vor der Antwort auf den Dialog und kommt leer zurück; ohne das
///    `watch` stünde dieses leere Ergebnis bis zum nächsten App-Start.
///    **Angestoßen wird der Dialog hier nicht** — ein Auslöser im eigenen
///    Lauf verwürfe mit seiner Antwort genau den Lauf, der auf ihn wartet
///    (dieselbe Begründung wie bei `freigabeAnfrageProvider`).
/// 4. **Er wirft nicht.** „In Health nicht hinterlegt" und „Lesen
///    verweigert" sind nicht unterscheidbar (Apple verrät den Lesestatus
///    nicht) und führen zu denselben `null`. Ein Fehler, der nach oben
///    durchschlägt, machte aus den beiden ununterscheidbaren Fällen zwei
///    verschiedene — und einer davon hieße fälschlich „etwas ist kaputt".
/// 5. **Er kommt mit einer Quelle ohne Merkmale zurecht.** `HealthReading`
///    verlangt `bodyCharacteristics()` nicht; eine Quelle ohne das zweite
///    Protokoll ist ein Normalfall und kein Absturz.
final stammdatenAusHealthProvider = FutureProvider<void>((ref) async {
  // Beobachtet, nicht nur gelesen: Ist die Freigabe beantwortet, läuft
  // dieser Lauf neu (#176).
  ref.watch(freigabeProvider);

  final bisher = await ref.read(stammdatenProvider.future);
  // Zusage 2: Steht beides schon da, wird der Kanal gar nicht erst gefragt.
  if (bisher.groesseCm != null && bisher.geburtsjahr != null) return;

  // Zusage 5: eine Quelle ohne Merkmale lässt den Lauf durch, statt ihn zu
  // sprengen — dieselbe Geste wie `as? BodyCharacteristicsReading` auf der
  // Swift-Seite.
  //
  // Als `switch` und nicht als `if (quelle is! …) return;`: Dart befördert
  // einen Wert nur auf einen **Untertyp** seines deklarierten Typs, und
  // `BodyCharacteristicsReading` ist keiner von `HealthReading` — die beiden
  // Protokolle stehen bewusst nebeneinander. Nach einer `is!`-Prüfung bliebe
  // `quelle` deshalb `HealthReading` und kennte die Methode nicht.
  final merkmalsquelle = switch (ref.read(healthProvider)) {
    final BodyCharacteristicsReading quelle => quelle,
    _ => null,
  };
  if (merkmalsquelle == null) return;

  final BodyCharacteristics merkmale;
  try {
    merkmale = await merkmalsquelle.bodyCharacteristics();
  } catch (_) {
    // Zusage 4: Bewusst verschluckt. Was fehlt, fehlt — und was schon in
    // der Tabelle steht, bleibt unberührt stehen.
    return;
  }

  final gefuellt = bisher.kopieMit(
    groesseCm: bisher.groesseCm ?? _alsZentimeter(merkmale.heightCm),
    geburtsjahr: bisher.geburtsjahr ?? merkmale.birthYear,
  );
  // Nichts geholt, nichts geschrieben: Ein Schreibvorgang, der dieselbe
  // Zeile noch einmal setzt, bewegte den Zustand ohne Anlass — und jeder,
  // der `stammdatenProvider` beobachtet, rechnete umsonst neu.
  if (gefuellt == bisher) return;

  // Über den Notifier, nicht am ihm vorbei: Sonst wäre es ein Stand in der
  // Datenbank, den die laufende App bis zum Neustart nicht sieht, und der
  // Ring zeigte weiter „kein Ziel berechenbar".
  await ref.read(stammdatenProvider.notifier).setze(gefuellt);
});

/// Die eine Rundung auf ganze Zentimeter — und die eine Stelle, an der eine
/// unmögliche Größe aussortiert wird.
///
/// **Gerundet, nicht abgeschnitten:** 180,6 cm werden 181, 180,4 cm werden
/// 180. Abschneiden nähme Tim bei jedem Lauf systematisch einen halben
/// Zentimeter.
///
/// **`0` und alles darunter füllen die Lücke nicht.** Der Codec reicht eine
/// 0 unverändert durch (er urteilt nicht), aber hier endet die Kette: Eine 0
/// in der Tabelle sähe aus wie ein eingetragener Wert, verstopfte die Lücke
/// für immer — danach wird nie wieder gefragt — und ließe `kalorienziel`
/// stillschweigend `null` liefern, ohne dass irgendwo stünde, warum.
int? _alsZentimeter(double? heightCm) {
  if (heightCm == null || heightCm <= 0) return null;
  return heightCm.round();
}
