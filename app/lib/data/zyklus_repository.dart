// Die Ablage des Zykluskalenders (#592 unter #539): Werttypen, Repository
// und Provider. Die Tabellen selbst stehen in `zyklus_tabelle.dart`
// (Stufe 25), die Clusterregel und die Vorhersage im Kern
// (`Packages/trainings_core/lib/src/zyklus_perioden.dart`).
//
// API und Vertrag sind durch `app/test/data/zyklus_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht
// die Implementierung"). Spec:
// `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitt 4.
//
// Derselbe Schnitt wie bei `EreignisRepository` und
// `UmfaengeRepository`: SQL hier, Riverpod nebenan.
//
// **Kein `Messwert<T>`** (Zyklus-Spec 7): Zyklusdaten sind eigene Daten,
// es gibt keinen Lauf aus Apple Health, der leer ausgehen könnte. Ein
// unbekannter Tag ist `null`, kein `LeerNachLauf`.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Wie stark ein Schmerz an einem Tag war.
///
/// **Nicht im Kern** (Spec 4.3.1): Anders als `Blutungsstaerke`, die in
/// `periodenAus` eingeht, trägt der Schmerz keine Rechnung — er ist
/// Nutzlast der Ablage, und Transporttypen gehören nicht in den Kern
/// (`CLAUDE.md`).
enum Schmerzstaerke { leicht, mittel, stark }

/// Das Ergebnis eines Schwangerschaftstests. Ein positiver pausiert die
/// Vorhersage (Spec 3.8) — er darf auf keinen Fall mit einer leeren Zeile
/// verschwinden.
enum Testergebnis { positiv, negativ }

/// Woher ein Tageseintrag stammt. `health` trägt der Erstimport aus Apple
/// Health; alles, was die Nutzerin selbst einträgt, ist `eigen`.
enum ZyklusQuelle { eigen, health }

/// Welche Sicht der Kalender zeigt (Spec 4.3).
enum ZyklusSicht { ueberblick, kinderwunsch }

/// Ein Tageseintrag, abgelegt oder abzulegen (Spec 4.1).
///
/// **Werttyp mit `==` und `hashCode` über alle Felder** — er wird
/// Abhängigkeit eines Providers, und ein Vergleich nach Identität ließe
/// jeden Beobachter bei jedem Neulesen neu rechnen (Hausregel 2).
/// [symptome] wird dabei über den **Inhalt** verglichen: Zwei gleich
/// befüllte Listen sind verschiedene Objekte, und nach Identität wäre ein
/// neu gelesener Tag ungleich sich selbst.
@immutable
class ZyklusEintrag {
  const ZyklusEintrag({
    required this.tag,
    this.blutung,
    this.zwischenblutung = false,
    this.schmerz,
    this.symptome = const [],
    this.sex = false,
    this.verhuetet,
    this.test,
    this.notiz,
    this.quelle = ZyklusQuelle.eigen,
    this.geaendert,
  });

  /// Der Tag als ISO-Tagesstring (`YYYY-MM-DD`).
  final String tag;

  /// Die Blutungsstärke, `null`, wenn an diesem Tag keine eingetragen ist.
  /// **Nicht `0`** — `0` ist keine Antwort auf „kein Wert" (`CLAUDE.md`).
  final Blutungsstaerke? blutung;

  /// Eine Zwischenblutung — ein eigenes Feld und kein Blutungstag
  /// (Spec 1).
  final bool zwischenblutung;

  final Schmerzstaerke? schmerz;

  /// Die gewählten Symptomschlüssel aus `lib/zyklus/zyklus_symptome.dart`.
  /// Keine Symptome heißen die **leere Liste**, nicht `null`.
  final List<String> symptome;

  final bool sex;

  /// Ob verhütet wurde; `null`, wenn nichts dazu eingetragen ist. Nur
  /// sinnvoll, wenn [sex] (Spec 4.1).
  final bool? verhuetet;

  final Testergebnis? test;

  /// Freitext, `null`, wenn keiner eingetragen ist.
  final String? notiz;

  /// Woher die Zeile stammt. Gesetzt vom Aufrufer, nicht vom Repository —
  /// der Erstimport muss erkennbar bleiben.
  final ZyklusQuelle quelle;

  /// Wann die Zeile zuletzt geschrieben wurde, UTC. Gesetzt vom
  /// Repository aus seiner Uhr; `null`, solange der Tag nicht abgelegt
  /// ist.
  final DateTime? geaendert;

  /// Ob dieser Tag **ohne jeden Wert** ist — die eine Stelle, an der das
  /// entschieden wird.
  ///
  /// „Eine Zeile ohne jeden Wert wird gelöscht, nicht gespeichert. Ein
  /// leerer Tag ist ein Tag ohne Zeile" (Spec 4.1). Bliebe die Zeile
  /// stehen, zählte sie im Kalender weiter als „etwas eingetragen", und
  /// die Nutzerin hätte keinen Weg, einen Tag zurückzunehmen.
  ///
  /// **[quelle] und [geaendert] zählen nicht als Wert** (Spec 4.3.2): Sie
  /// sagen etwas über die Zeile, nicht über den Tag. Eine leere Zeile aus
  /// dem Import ist genauso leer wie eine eigene.
  ///
  /// **Eine Notiz zählt erst nach `trim()`** — sonst bliebe ein Tag
  /// stehen, auf dem nur ein Leerzeichen steht.
  ///
  /// **[verhuetet] zählt nicht** (von Spec und Tests offengelassen):
  /// „nur sinnvoll, wenn `sex`" (Spec 4.1), und ohne [sex] sagt das Feld
  /// nichts über den Tag aus. Das Formular kann den Zustand ohnehin nicht
  /// erzeugen; mit [sex] ist der Tag schon deshalb nicht leer.
  bool get istLeer =>
      blutung == null &&
      !zwischenblutung &&
      schmerz == null &&
      symptome.isEmpty &&
      !sex &&
      test == null &&
      (notiz == null || notiz!.trim().isEmpty);

  @override
  bool operator ==(Object other) =>
      other is ZyklusEintrag &&
      other.tag == tag &&
      other.blutung == blutung &&
      other.zwischenblutung == zwischenblutung &&
      other.schmerz == schmerz &&
      listEquals(other.symptome, symptome) &&
      other.sex == sex &&
      other.verhuetet == verhuetet &&
      other.test == test &&
      other.notiz == notiz &&
      other.quelle == quelle &&
      other.geaendert == geaendert;

  @override
  int get hashCode => Object.hash(
    tag,
    blutung,
    zwischenblutung,
    schmerz,
    Object.hashAll(symptome),
    sex,
    verhuetet,
    test,
    notiz,
    quelle,
    geaendert,
  );

  @override
  String toString() =>
      'ZyklusEintrag(tag: $tag, blutung: ${blutung?.name}, '
      'zwischenblutung: $zwischenblutung, schmerz: ${schmerz?.name}, '
      'symptome: $symptome, sex: $sex, verhuetet: $verhuetet, '
      'test: ${test?.name}, notiz: $notiz, quelle: ${quelle.name}, '
      'geaendert: $geaendert)';
}

/// Eine Zeile des Health-Spiegels: ein Sample, das die App nach HealthKit
/// geschrieben hat (Spec 4.2).
@immutable
class ZyklusSpiegelZeile {
  const ZyklusSpiegelZeile({
    required this.uuid,
    required this.tag,
    required this.typ,
  });

  /// Die Sample-UUID aus HealthKit.
  final String uuid;

  /// Der Tag, zu dem das Sample gehört, als ISO-Tagesstring.
  final String tag;

  /// Der HealthKit-Typbezeichner.
  final String typ;

  @override
  bool operator ==(Object other) =>
      other is ZyklusSpiegelZeile &&
      other.uuid == uuid &&
      other.tag == tag &&
      other.typ == typ;

  @override
  int get hashCode => Object.hash(uuid, tag, typ);

  @override
  String toString() => 'ZyklusSpiegelZeile(uuid: $uuid, tag: $tag, typ: $typ)';
}

/// Die Einstellungen des Zykluskalenders (Spec 4.3) als ein Wert.
@immutable
class ZyklusEinstellungen {
  const ZyklusEinstellungen({
    required this.kalenderAn,
    required this.sicht,
    required this.verhuetungAn,
    required this.verhuetungSeit,
    required this.verhuetungArt,
    required this.importGelaufen,
    required this.vorhersagePausiert,
  });

  /// Ob der Kalender geführt wird — er erscheint unter *Mehr* nur, wenn
  /// eingeschaltet (Spec 7).
  final bool kalenderAn;

  final ZyklusSicht sicht;

  final bool verhuetungAn;

  /// Seit wann verhütet wird, als ISO-Tagesstring; `null`, wenn nicht.
  ///
  /// **Nicht bloß ein Flag:** Nur so bleibt rückwirkend erkennbar, welcher
  /// Zyklus unter Verhütung lief (Spec 3.7).
  final String? verhuetungSeit;

  /// Die Art der Verhütung als Freitext (Spec 4.3), `null`, wenn keine
  /// eingetragen ist.
  final String? verhuetungArt;

  /// Ob der Erstimport aus Apple Health schon gelaufen ist.
  final bool importGelaufen;

  /// Ob die Vorhersage pausiert (Spec 3.8).
  final bool vorhersagePausiert;

  /// Was gilt, solange niemand etwas eingestellt hat.
  ///
  /// **Eine Dart-Konstante und keine vorab eingefügte Datenbankzeile** —
  /// dieselbe Überlegung wie bei `Ziele.vorbelegung`: Sonst stünde die
  /// Vorbelegung an zwei Orten, in der Migration und im Code, und einer
  /// von beiden wäre irgendwann der falsche. Der Kalender ist darin
  /// **aus**; eine App, die ihn ungefragt zeigt, hat ihn eingeschaltet,
  /// ohne gefragt zu werden.
  static const ZyklusEinstellungen vorbelegung = ZyklusEinstellungen(
    kalenderAn: false,
    sicht: ZyklusSicht.ueberblick,
    verhuetungAn: false,
    verhuetungSeit: null,
    verhuetungArt: null,
    importGelaufen: false,
    vorhersagePausiert: false,
  );

  /// Eine Kopie mit einzelnen geänderten Feldern.
  ///
  /// **Zurück auf `null` geht damit nicht** — [verhuetungSeit] und
  /// [verhuetungArt] lassen sich so nur setzen, nicht leeren. Wer das
  /// Umschalten zurücknimmt, baut den ganzen Wert; dort muss ohnehin
  /// mehr als ein Feld zusammenpassen, und ein stehengebliebener
  /// Zeitpunkt behauptete eine Verhütung, die es nicht mehr gibt.
  ZyklusEinstellungen kopieMit({
    bool? kalenderAn,
    ZyklusSicht? sicht,
    bool? verhuetungAn,
    String? verhuetungSeit,
    String? verhuetungArt,
    bool? importGelaufen,
    bool? vorhersagePausiert,
  }) => ZyklusEinstellungen(
    kalenderAn: kalenderAn ?? this.kalenderAn,
    sicht: sicht ?? this.sicht,
    verhuetungAn: verhuetungAn ?? this.verhuetungAn,
    verhuetungSeit: verhuetungSeit ?? this.verhuetungSeit,
    verhuetungArt: verhuetungArt ?? this.verhuetungArt,
    importGelaufen: importGelaufen ?? this.importGelaufen,
    vorhersagePausiert: vorhersagePausiert ?? this.vorhersagePausiert,
  );

  @override
  bool operator ==(Object other) =>
      other is ZyklusEinstellungen &&
      other.kalenderAn == kalenderAn &&
      other.sicht == sicht &&
      other.verhuetungAn == verhuetungAn &&
      other.verhuetungSeit == verhuetungSeit &&
      other.verhuetungArt == verhuetungArt &&
      other.importGelaufen == importGelaufen &&
      other.vorhersagePausiert == vorhersagePausiert;

  @override
  int get hashCode => Object.hash(
    kalenderAn,
    sicht,
    verhuetungAn,
    verhuetungSeit,
    verhuetungArt,
    importGelaufen,
    vorhersagePausiert,
  );

  @override
  String toString() =>
      'ZyklusEinstellungen(kalenderAn: $kalenderAn, sicht: ${sicht.name}, '
      'verhuetungAn: $verhuetungAn, verhuetungSeit: $verhuetungSeit, '
      'verhuetungArt: $verhuetungArt, importGelaufen: $importGelaufen, '
      'vorhersagePausiert: $vorhersagePausiert)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und dem Zykluskalender.
class ZyklusRepository {
  /// [uhr] liefert den Zeitpunkt für `geaendert`; ohne sie die Uhr des
  /// Geräts. Nie `DateTime.now()` unmittelbar im Rumpf — sonst ließe sich
  /// das Schreiben nicht deterministisch prüfen.
  ZyklusRepository(AppCache db, {DateTime Function()? uhr})
    : _db = db,
      _uhr = uhr ?? _geraeteUhr;

  static DateTime _geraeteUhr() => DateTime.now().toUtc();

  final AppCache _db;
  final DateTime Function() _uhr;

  /// Der Tageseintrag zu [tag], oder `null`, wenn es ihn nicht gibt.
  ///
  /// **`null` und kein leerer Eintrag:** Leer heißt leer (Spec 7). Ein
  /// zurückgegebener Leereintrag ließe sich nicht von einem Tag
  /// unterscheiden, an dem jemand alle Felder abgewählt hat — und den gibt
  /// es gar nicht.
  Future<ZyklusEintrag?> lies(String tag) async {
    final zeile = await (_db.select(
      _db.zyklusEintraege,
    )..where((t) => t.tag.equals(tag))).getSingleOrNull();
    return zeile == null ? null : _ausZeile(zeile);
  }

  /// Die Tageseinträge zwischen [von] und [bis], **beide einschließlich**,
  /// aufsteigend nach Tag.
  ///
  /// Gefiltert und sortiert wird **in SQL** über den ISO-Tagesstring
  /// (Hausregel 2): Nach dem Laden in Dart zu filtern holte jeden jemals
  /// eingetragenen Tag in den Speicher und würfe ihn wieder weg. Der
  /// Tagesstring hat führende Nullen und feste Breite, also ist
  /// Textsortierung hier Datumssortierung — auch über einen
  /// Jahreswechsel und über jede Zeitumstellung hinweg.
  Future<List<ZyklusEintrag>> imZeitraum({
    required String von,
    required String bis,
  }) async {
    final zeilen =
        await (_db.select(_db.zyklusEintraege)
              ..where(
                (t) =>
                    t.tag.isBiggerOrEqualValue(von) &
                    t.tag.isSmallerOrEqualValue(bis),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
            .get();
    return [for (final z in zeilen) _ausZeile(z)];
  }

  /// Legt [eintrag] ab — oder **löscht den Tag**, wenn er ohne jeden Wert
  /// ist (Spec 4.1, siehe [ZyklusEintrag.istLeer]). Mit dem Tag geht dann
  /// sein Health-Spiegel (Spec 4.2).
  ///
  /// Geschrieben wird der **ganze Tag**, nicht ein Feld: Ein Schmerz, den
  /// die Nutzerin wegnimmt, bliebe sonst für immer stehen. Je Tag gibt es
  /// höchstens eine Zeile; ein zweites Schreiben desselben Tages ersetzt
  /// sie.
  ///
  /// `geaendert` kommt **immer aus der Uhr**, als UTC — ein mitgegebener
  /// Wert wird nicht übernommen. Sonst könnte ein alter Stand aus einem
  /// Formular einen frischen Zeitstempel überschreiben, und der Spiegel
  /// wüsste nicht mehr, was neuer ist.
  Future<void> schreibe(ZyklusEintrag eintrag) async {
    if (eintrag.istLeer) {
      await loesche(eintrag.tag);
      return;
    }
    await _db
        .into(_db.zyklusEintraege)
        .insertOnConflictUpdate(
          ZyklusEintraegeCompanion.insert(
            tag: eintrag.tag,
            blutung: Value(eintrag.blutung?.name),
            zwischenblutung: Value(eintrag.zwischenblutung),
            schmerz: Value(eintrag.schmerz?.name),
            symptome: Value(eintrag.symptome.join(_trenner)),
            sex: Value(eintrag.sex),
            verhuetet: Value(eintrag.verhuetet),
            test: Value(eintrag.test?.name),
            notiz: Value(eintrag.notiz),
            quelle: Value(eintrag.quelle.name),
            geaendert: _uhr().toUtc(),
          ),
        );
  }

  /// Löscht den Tageseintrag zu [tag] **samt seinen Spiegelzeilen**; auf
  /// einen Tag ohne Zeile tut das nichts und wirft nicht.
  ///
  /// **Wer die Samples in HealthKit entfernen will, liest [spiegel]
  /// vorher** — danach sind die UUIDs fort (Spec 4.3.3). Bliebe die
  /// Spiegelzeile stehen, zeigte Health einen sensiblen Eintrag weiter,
  /// den es in der App nicht mehr gibt.
  Future<void> loesche(String tag) async {
    await (_db.delete(
      _db.zyklusEintraege,
    )..where((t) => t.tag.equals(tag))).go();
    await (_db.delete(
      _db.zyklusHealthSpiegel,
    )..where((t) => t.tag.equals(tag))).go();
  }

  /// Merkt sich ein nach HealthKit geschriebenes Sample.
  ///
  /// Die UUID ist der Schlüssel: Dasselbe Sample zweimal zu merken bleibt
  /// **eine** Zeile — ein zweiter Durchlauf des Schreibens darf keine
  /// zwei Zeilen hinterlassen, die auf dasselbe Sample zeigen.
  Future<void> merkeSample({
    required String uuid,
    required String tag,
    required String typ,
  }) => _db
      .into(_db.zyklusHealthSpiegel)
      .insertOnConflictUpdate(
        ZyklusHealthSpiegelCompanion.insert(uuid: uuid, tag: tag, typ: typ),
      );

  /// Die gemerkten Samples zu [tag], nach UUID sortiert; eine leere Liste,
  /// wenn es keine gibt. Ein Zyklustag erzeugt mehrere Samples (Blutung,
  /// Sex, je Symptom eines).
  ///
  /// Sortiert wird in SQL, damit die Reihenfolge nicht davon abhängt, wie
  /// SQLite die Zeilen gerade liegen hat.
  Future<List<ZyklusSpiegelZeile>> spiegel(String tag) async {
    final zeilen =
        await (_db.select(_db.zyklusHealthSpiegel)
              ..where((t) => t.tag.equals(tag))
              ..orderBy([(t) => OrderingTerm.asc(t.uuid)]))
            .get();
    return [
      for (final z in zeilen)
        ZyklusSpiegelZeile(uuid: z.uuid, tag: z.tag, typ: z.typ),
    ];
  }

  /// Die Einstellungen — [ZyklusEinstellungen.vorbelegung], solange nichts
  /// abgelegt ist. Kein `null`, kein Leerzustand: Eine fehlende Zeile ist
  /// keine fehlende Antwort, sondern „noch nichts eingestellt".
  ///
  /// **Das Lesen legt keine Zeile an.** Eine vorsorglich geschriebene
  /// Zeile behauptete eine Einstellung, die niemand getroffen hat.
  ///
  /// Eine unbekannte [ZyklusSicht] wird **übergangen, nicht geworfen**:
  /// Eine spätere Fassung kennt vielleicht eine dritte, und eine ältere
  /// soll die Datei trotzdem öffnen — dieselbe Regel wie bei `blutung`.
  Future<ZyklusEinstellungen> liesEinstellungen() async {
    final zeile = await _db.select(_db.zyklusEinstellungen).getSingleOrNull();
    if (zeile == null) return ZyklusEinstellungen.vorbelegung;
    return ZyklusEinstellungen(
      kalenderAn: zeile.kalenderAn,
      sicht:
          ZyklusSicht.values.asNameMap()[zeile.sicht] ??
          ZyklusEinstellungen.vorbelegung.sicht,
      verhuetungAn: zeile.verhuetungAn,
      verhuetungSeit: zeile.verhuetungSeit,
      verhuetungArt: zeile.verhuetungArt,
      importGelaufen: zeile.importGelaufen,
      vorhersagePausiert: zeile.vorhersagePausiert,
    );
  }

  /// Schreibt die **eine** Einstellungszeile, überschreibend.
  ///
  /// Einstellungen sind kein Verlauf; eine zweite Zeile wäre ein zweiter,
  /// widersprechender Stand. `verhuetungSeit` und `verhuetungArt` gehen
  /// auch als `null` hinein — ein stehengebliebener Zeitpunkt behauptete
  /// eine Verhütung, die es nicht mehr gibt.
  Future<void> schreibeEinstellungen(ZyklusEinstellungen einstellungen) => _db
      .into(_db.zyklusEinstellungen)
      .insertOnConflictUpdate(
        ZyklusEinstellungenCompanion.insert(
          id: const Value(_einzigeZeile),
          kalenderAn: Value(einstellungen.kalenderAn),
          sicht: Value(einstellungen.sicht.name),
          verhuetungAn: Value(einstellungen.verhuetungAn),
          verhuetungSeit: Value(einstellungen.verhuetungSeit),
          verhuetungArt: Value(einstellungen.verhuetungArt),
          importGelaufen: Value(einstellungen.importGelaufen),
          vorhersagePausiert: Value(einstellungen.vorhersagePausiert),
        ),
      );

  /// Der Schlüssel der einen Einstellungszeile.
  static const int _einzigeZeile = 0;

  /// Das Trennzeichen der Symptomschlüssel in der Spalte `symptome`
  /// (Spec 4.1, „kommagetrennte Schlüssel").
  static const String _trenner = ',';

  /// Eine Tabellenzeile als Werttyp.
  ///
  /// **Unbekannte Aufzählungswerte werden übergangen, nicht geworfen und
  /// nicht gelöscht** (dieselbe Regel wie bei `ereignisse.art`, V20): Eine
  /// spätere Fassung kennt vielleicht eine vierte Blutungsstufe, und eine
  /// ältere soll die Datei trotzdem öffnen. Bei `quelle` fällt sie auf
  /// `eigen` zurück — das Feld ist Pflicht, und eine unbekannte Herkunft
  /// ist keine behauptbare Herkunft.
  ///
  /// **Die Symptome kommen wörtlich zurück**, auch Schlüssel, die der
  /// Katalog heute nicht kennt: Welche davon anzeigbar sind, entscheidet
  /// die Ansicht (`symptomZu` in `lib/zyklus/zyklus_symptome.dart`). Die
  /// Ablage, die beim Lesen filterte, würfe sie beim nächsten Speichern
  /// endgültig weg.
  ZyklusEintrag _ausZeile(ZyklusEintragRow z) => ZyklusEintrag(
    tag: z.tag,
    blutung: Blutungsstaerke.values.asNameMap()[z.blutung],
    zwischenblutung: z.zwischenblutung,
    schmerz: Schmerzstaerke.values.asNameMap()[z.schmerz],
    symptome: _symptomeAus(z.symptome),
    sex: z.sex,
    verhuetet: z.verhuetet,
    test: Testergebnis.values.asNameMap()[z.test],
    notiz: z.notiz,
    quelle: ZyklusQuelle.values.asNameMap()[z.quelle] ?? ZyklusQuelle.eigen,
    geaendert: z.geaendert,
  );

  static List<String> _symptomeAus(String text) => [
    for (final s in text.split(_trenner))
      if (s.isNotEmpty) s,
  ];
}

/// Das Repository mit der Uhr der App ([clockProvider]) und dem Cache der
/// App ([appCacheProvider]) — kein `DateTime.now()` im Rumpf.
final zyklusRepositoryProvider = Provider<ZyklusRepository>(
  (ref) => ZyklusRepository(
    ref.watch(appCacheProvider),
    uhr: ref.watch(clockProvider),
  ),
);
