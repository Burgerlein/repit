// Lese-/Schreib-Brücke zwischen `AppCache` (drift, Task 6) und
// `DailyMetrics` (Task 12) — der Teil von Task 13, der SQL von Riverpod
// trennt. `health_provider.dart` kennt nach diesem Schnitt keine
// drift-Typen mehr, nur noch `DailyMetrics`/`DataWindow`.
//
// API und Vertrag sind durch `app/test/health/cache_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
import 'package:drift/drift.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_types.dart';
import 'cache.dart';

class CacheRepository {
  CacheRepository(this._db);

  final AppCache _db;

  /// Die laufende Nummer der Markierungszeile einer Quelle ohne Abschnitte.
  /// Negativ, damit sie mit keiner echten kollidieren kann — die zählen ab
  /// 0 — und damit sie beim `ORDER BY lfd_nr` vorneweg steht.
  static const _leereQuelleLfdNr = -1;

  /// Kein `SleepStage.name`: `SleepStage.values.byName('')` würfe, falls
  /// die Markierung doch einmal als Abschnitt gelesen würde. Lieber ein
  /// lautes Scheitern als eine stille Phase, die es nicht gibt.
  static const _leereQuellePhase = '';

  /// Der Nullpunkt der Unix-Zeit, Beginn wie Ende — ein Fenster der Länge
  /// null, lange vor jeder Nacht, die diese App je sieht. Eine Markierung,
  /// keine Zeitangabe.
  static final _leereQuelleZeit = DateTime.utc(1970);

  /// Liest alle `TagesWerte`-Zeilen, deren Tag im `fenster` liegt, aufsteigend
  /// sortiert (Spec 5.6, letzter Punkt: `DataWindow.clip(...)` wird zu
  /// `WHERE tag >= ?` — hier direkt als SQL, nicht erst nach dem Laden
  /// gefiltert, sonst wäre Fehlermuster `03`/5.2 wieder da).
  ///
  /// `null`, wenn keine einzige Zeile trifft — „kein Cache" ist ein eigener
  /// Zustand (Spec 5.3d), keine leere Liste mit einem erfundenen Stand.
  Future<({List<DailyMetrics> werte, DateTime stand})?> liesTagesWerte(
    DataWindow fenster,
  ) async {
    final query = _db.select(_db.tagesWerte)
      ..orderBy([(t) => OrderingTerm.asc(t.tag)]);
    final start = fenster.start;
    if (start != null) {
      final tagesSchluessel = BerlinCalendar.dayKey(start);
      query.where((t) => t.tag.isBiggerOrEqualValue(tagesSchluessel));
    }

    final zeilen = await query.get();
    if (zeilen.isEmpty) return null;

    // Der Stand des Fensters ist das jüngste `gelesenAm` der tatsächlich
    // zurückgegebenen Zeilen — nicht das älteste, und nicht das irgendeiner
    // Zeile außerhalb des Fensters (siehe Test „der Stand gehört zu den
    // tatsächlich zurückgegebenen Zeilen, nicht zur ältesten Zeile im ganzen
    // Cache"). Spec 5.3b/5.5 sieht nur den Fall vor, dass alle Zeilen eines
    // Fensters aus demselben Lauf stammen und also denselben Stand tragen;
    // dieser Ausdruck liefert in genau diesem Fall exakt diesen gemeinsamen
    // Wert, ohne eine Aggregationsregel für gemischte Läufe zu erfinden, die
    // die Spec nicht trifft.
    DateTime? stand;
    for (final zeile in zeilen) {
      final gelesenAm = zeile.gelesenAm;
      if (gelesenAm == null) continue;
      if (stand == null || gelesenAm.isAfter(stand)) stand = gelesenAm;
    }
    // Keine Zeile trägt einen Stand (z. B. nach einer Migration aus Schema
    // v1, das die Spalte noch nicht kannte, siehe `cache.dart`). Ein
    // `Bekannt` ohne ehrlichen Stand wäre eine erfundene Zahl — also gilt
    // das Fenster hier als "kein Cache", nicht als Cache mit `DateTime.now()`
    // als Attrappe.
    if (stand == null) return null;

    return (werte: zeilen.map(_alsDailyMetrics).toList(), stand: stand);
  }

  /// Schreibt einen Lauf zurück. `gelesenAm` gilt für **alle** Zeilen dieses
  /// Aufrufs gleich — ein Lauf hat einen Zeitpunkt (Spec 5.3b: der Stand ist
  /// je Zeile unterschiedlich *zwischen* Läufen, nicht *innerhalb* eines
  /// Laufs). Ein zweiter Lauf auf denselben Tag überschreibt die Zeile.
  Future<void> schreibeTagesWerte(
    List<DailyMetrics> werte, {
    required DateTime gelesenAm,
  }) async {
    if (werte.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.tagesWerte,
        werte
            .map(
              (wert) => TagesWerteCompanion.insert(
                tag: wert.tag,
                schritte: Value(wert.steps),
                ruhepulsBpm: Value(wert.restingHR),
                gelesenAm: Value(gelesenAm),
                hrvMs: Value(wert.hrvMs),
                respRate: Value(wert.respRate),
                recoveryHrDrop: Value(wert.recoveryHRDrop),
                gewichtKg: Value(wert.weightKg),
                trainingsMinuten: Value(wert.exerciseMinutes),
                koerperfettPct: Value(wert.bodyFatPct),
                fettfreiKg: Value(wert.leanKg),
                vo2max: Value(wert.vo2max),
              ),
            )
            .toList(),
      );
    });
  }

  /// `TagesWerte` kennt seit Schema v26 (#95) zehn Metrikspalten —
  /// `schritte`, `ruhepulsBpm`, die drei, die die Ampel braucht (Schema v3,
  /// #113), `gewichtKg`/`trainingsMinuten` (Schema v6, #194),
  /// `koerperfettPct`/`fettfreiKg` (#202) und `vo2max`. Die übrigen
  /// **drei** Felder von `DailyMetrics` (`activeKcal`, `basalKcal`,
  /// `standHours`) haben keine eigene Spalte und kommen aus dem Cache
  /// weiterhin immer `null` zurück: geerbte Schemagrenze aus Task 6, mit
  /// jedem dieser Tickets geschrumpft, aber nicht aufgehoben (siehe
  /// `cache_repository_test.dart`, Gruppe „Geerbte Schemagrenze", sowie
  /// `schema_v3_test.dart`, `schema_v6_test.dart`, `schema_v7_test.dart`
  /// und `schema_v26_test.dart`).
  ///
  /// `gewichtKg` und `trainingsMinuten` sind seit #194 dabei,
  /// `koerperfettPct` und `fettfreiKg` seit #202, `vo2max` seit #95 —
  /// immer aus demselben Grund: Gewichtskachel, Trainingsring, Körperfett-
  /// und Muskelkachel und die VO₂max-Anzeige standen nach jedem Kaltstart
  /// erst leer da, bis HealthKit antwortete.
  /// Ein fehlender Wert bleibt dabei `null` — kein Rückfall auf den
  /// jüngsten vorhandenen Wert, das ist #194 Punkt 1 und noch nicht
  /// entworfen.
  DailyMetrics _alsDailyMetrics(TagesWerteRow zeile) => DailyMetrics(
    tag: zeile.tag,
    steps: zeile.schritte,
    restingHR: zeile.ruhepulsBpm,
    hrvMs: zeile.hrvMs,
    respRate: zeile.respRate,
    recoveryHRDrop: zeile.recoveryHrDrop,
    weightKg: zeile.gewichtKg,
    exerciseMinutes: zeile.trainingsMinuten,
    bodyFatPct: zeile.koerperfettPct,
    leanKg: zeile.fettfreiKg,
    vo2max: zeile.vo2max,
  );

  /// Eine Messreihe aus dem Cache: alle Tage zwischen [von] und [bis], an
  /// denen die Spalte zu [art] einen Wert trägt, aufsteigend nach Tag
  /// (#202, Spec Teil B).
  ///
  /// **Gefiltert wird in SQL**, nicht nach dem Laden in Dart — `WHERE tag
  /// >= ? AND tag <= ?`, lexikografisch über den ISO-Tagesstring, und
  /// beide Grenzen gehören dazu (`CLAUDE.md`, Hausregel 2). Auf einem Jahr
  /// Daten wäre das Nachfiltern genau die Last, die beim Scrollen ruckelt
  /// (Fehler `03`); dass es wirklich eine Abfrage ist und SQLite wirklich
  /// nur die Zeilen des Fensters herausgibt, prüft `schema_v7_test.dart`
  /// am Mitschnitt der abgesetzten Abfrage.
  ///
  /// **Eine Zeile ohne Wert ist kein Messpunkt** und fällt schon im `WHERE`
  /// heraus. Ein Punkt mit `0,0` zöge die Kurve auf null und behauptete
  /// eine Messung, die es nie gab — `nil` darf auf keinem Weg zu `0`
  /// werden (`CLAUDE.md`, Fehler `01`).
  ///
  /// Trifft nichts, ist das Ergebnis die **leere Liste**, nicht `null`:
  /// „kein Cache" als eigener Zustand (Spec 5.3d) gehört zu
  /// [liesTagesWerte], das ein ganzes Fenster samt Stand liefert. Eine
  /// Reihe ist eine Aufzählung, und eine leere Aufzählung ist leer.
  Future<List<MeasurementPoint>> messReihe(
    MessArt art, {
    required String von,
    required String bis,
  }) async {
    final tag = _db.tagesWerte.tag;
    final wert = _wertSpalte(art);

    final abfrage = _db.selectOnly(_db.tagesWerte)
      ..addColumns([tag, wert])
      ..where(
        tag.isBiggerOrEqualValue(von) &
            tag.isSmallerOrEqualValue(bis) &
            wert.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(tag)]);

    final zeilen = await abfrage.get();
    return [
      for (final zeile in zeilen)
        MeasurementPoint(
          // Derselbe Rückweg wie bei den Nächten: der Berliner Tagesbeginn
          // des Tagesschlüssels als UTC-Zeitpunkt. `datumAusTag` steht
          // dafür öffentlich in `health_types.dart`, damit es ihn nicht
          // zweimal gibt — ein `DateTime.parse` auf den Tagesstring läge
          // je nach Jahreszeit ein oder zwei Stunden daneben.
          date: datumAusTag(zeile.read(tag)!),
          value: zeile.read(wert)!,
        ),
    ];
  }

  /// Die VO₂max-Reihe aus dem Cache (#95) — dieselbe Abfrageform wie
  /// [messReihe], nur für die Spalte `vo2max` (Schema v26).
  ///
  /// **Keine fünfte [MessArt]:** `MessArt` zählt die vier Verlaufskarten
  /// des Messungen-Schirms auf, und `messung_detail_view` baut für jeden
  /// Fall einen eigenen Schirm — ein fünfter Fall bekäme dort einen
  /// Schirm, den niemand entworfen hat. Die VO₂max-Kurve gehört allein dem
  /// Ausdauer-Schirm (`ausdauer_zustand.dart`).
  Future<List<MeasurementPoint>> vo2maxReihe({
    required String von,
    required String bis,
  }) async {
    final tag = _db.tagesWerte.tag;
    final wert = _db.tagesWerte.vo2max;

    final abfrage = _db.selectOnly(_db.tagesWerte)
      ..addColumns([tag, wert])
      ..where(
        tag.isBiggerOrEqualValue(von) &
            tag.isSmallerOrEqualValue(bis) &
            wert.isNotNull(),
      )
      ..orderBy([OrderingTerm.asc(tag)]);

    final zeilen = await abfrage.get();
    return [
      for (final zeile in zeilen)
        MeasurementPoint(
          date: datumAusTag(zeile.read(tag)!),
          value: zeile.read(wert)!,
        ),
    ];
  }

  /// Die Spalte hinter einer [MessArt], als `Expression<double>`.
  ///
  /// **`ruhepuls_bpm` wird in SQL gecastet**, nicht in Dart umgerechnet:
  /// Die Spalte ist eine Ganzzahlspalte, `MeasurementPoint.value` ist
  /// `double`. Ein `CAST(… AS REAL)` hält den Rückweg für alle vier Arten
  /// gleich — eine Fallunterscheidung beim Auslesen wäre eine zweite
  /// Stelle, an der die Zuordnung Art → Spalte stimmen müsste.
  Expression<double> _wertSpalte(MessArt art) => switch (art) {
    MessArt.gewicht => _db.tagesWerte.gewichtKg,
    MessArt.koerperfett => _db.tagesWerte.koerperfettPct,
    MessArt.fettfreieMasse => _db.tagesWerte.fettfreiKg,
    MessArt.ruhepuls => _db.tagesWerte.ruhepulsBpm.cast<double>(),
  };

  /// Liest alle Nächte, deren Aufwachtag im `fenster` liegt, aufsteigend
  /// nach Tag — dieselbe Regel wie bei [liesTagesWerte]: `DataWindow` wird
  /// zu `WHERE tag >= ?`, nicht erst nach dem Laden gefiltert (Spec 5.6).
  ///
  /// `null`, wenn keine einzige Nacht trifft **oder** keine der
  /// getroffenen Nächte einen Stand trägt — „kein Cache" ist ein eigener
  /// Zustand (Spec 5.3d), keine leere Liste mit einem erfundenen Stand.
  Future<({List<SleepNight> werte, DateTime stand})?> liesNaechte(
    DataWindow fenster,
  ) async {
    final abfrage = _db.select(_db.naechte)
      ..orderBy([(t) => OrderingTerm.asc(t.tag)]);
    final start = fenster.start;
    if (start != null) {
      final tagesSchluessel = BerlinCalendar.dayKey(start);
      abfrage.where((t) => t.tag.isBiggerOrEqualValue(tagesSchluessel));
    }

    final naechte = await abfrage.get();
    if (naechte.isEmpty) return null;

    // Derselbe Ausdruck wie in `liesTagesWerte`: das jüngste `gelesenAm`
    // der tatsächlich zurückgegebenen Nächte, nicht das irgendeiner Nacht
    // außerhalb des Fensters. Sonst behauptete die Standzeile einen Lauf,
    // dessen Daten gar nicht auf dem Schirm stehen.
    DateTime? stand;
    for (final nacht in naechte) {
      final gelesenAm = nacht.gelesenAm;
      if (gelesenAm == null) continue;
      if (stand == null || gelesenAm.isAfter(stand)) stand = gelesenAm;
    }
    if (stand == null) return null;

    final tage = naechte.map((n) => n.tag).toList();
    final abschnitte =
        await (_db.select(_db.schlafAbschnitte)
              ..where((t) => t.tag.isIn(tage))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tag),
                (t) => OrderingTerm.asc(t.quelle),
                (t) => OrderingTerm.asc(t.lfdNr),
              ]))
            .get();

    // Nach Tag und Quelle einsortieren: Quelle 0 ist die Hauptnacht, 1..n
    // sind die Nickerchen in ihrer ursprünglichen Reihenfolge.
    final jeTag = <String, Map<int, List<SleepSegment>>>{};
    for (final abschnitt in abschnitte) {
      final liste = (jeTag[abschnitt.tag] ??= <int, List<SleepSegment>>{})
          .putIfAbsent(abschnitt.quelle, () => <SleepSegment>[]);
      // Die Markierungszeile sagt nur „diese Quelle gibt es" — oben hat sie
      // ihren Schlüssel schon angelegt, ein Abschnitt wird sie nie.
      if (abschnitt.lfdNr == _leereQuelleLfdNr) continue;
      liste.add(
        SleepSegment(
          stage: SleepStage.values.byName(abschnitt.phase),
          start: abschnitt.beginn,
          end: abschnitt.ende,
        ),
      );
    }

    final werte = naechte.map((nacht) {
      final quellen = jeTag[nacht.tag] ?? const <int, List<SleepSegment>>{};
      final nickerchenQuellen = quellen.keys.where((q) => q != 0).toList()
        ..sort();
      return SleepNight(
        date: datumAusTag(nacht.tag),
        session: SleepSession(segments: quellen[0] ?? const []),
        naps: nickerchenQuellen
            .map((q) => SleepSession(segments: quellen[q]!))
            .toList(),
      );
    }).toList();

    return (werte: werte, stand: stand);
  }

  /// Schreibt einen Lauf zurück. `gelesenAm` gilt für **alle** Nächte dieses
  /// Aufrufs gleich — ein Lauf hat einen Zeitpunkt (Spec 5.3b), und die
  /// Nacht ist die Einheit, die der Kanal liefert.
  ///
  /// Eine erneut geschriebene Nacht **ersetzt** ihre Abschnitte. Blieben die
  /// alten Zeilen stehen, läse der Schirm eine Nacht, die es nie gab:
  /// zusammengesetzt aus zwei Läufen, die Apple Health unterschiedlich
  /// zugeschnitten hat.
  Future<void> schreibeNaechte(
    List<SleepNight> naechte, {
    required DateTime gelesenAm,
  }) async {
    if (naechte.isEmpty) return;

    // Löschen und Schreiben in einer Transaktion: Ein Abbruch dazwischen
    // ließe sonst eine Nacht ohne Abschnitte zurück — sichtbar als Nacht
    // ohne Schlaf, nicht als fehlender Cache.
    await _db.transaction(() async {
      for (final nacht in naechte) {
        final tag = BerlinCalendar.dayKey(nacht.date);

        await (_db.delete(
          _db.schlafAbschnitte,
        )..where((t) => t.tag.equals(tag))).go();

        await _db
            .into(_db.naechte)
            .insertOnConflictUpdate(
              NaechteCompanion.insert(tag: tag, gelesenAm: Value(gelesenAm)),
            );

        final zeilen = <SchlafAbschnitteCompanion>[
          // Die Hauptnacht braucht keine Markierung: Sie hat die feste
          // Quelle 0 und wird beim Lesen immer gebaut (`quellen[0] ?? []`).
          ..._alsZeilen(tag, 0, nacht.session),
          for (var i = 0; i < nacht.naps.length; i++)
            ..._alsZeilen(tag, i + 1, nacht.naps[i], markiereLeere: true),
        ];
        if (zeilen.isEmpty) continue;
        await _db.batch((batch) {
          batch.insertAll(_db.schlafAbschnitte, zeilen);
        });
      }
    });
  }

  /// Liest die gerechneten Nachtwerte (#193, Schema v8) aller Nächte, deren
  /// Aufwachtag im `fenster` liegt — Schlüssel ist derselbe
  /// ISO-Tagesschlüssel wie in [liesNaechte], und gefiltert wird wie dort in
  /// SQL (Spec 5.6).
  ///
  /// **Eine Nacht ohne jeden der drei Werte taucht nicht auf.** Ein
  /// `NightVitals` mit drei `null`-Feldern wäre dieselbe Auskunft wie ein
  /// fehlender Eintrag, nur mit mehr Zeilen; die Ansicht liest
  /// `karte[tag] == null` als „keine Werte".
  ///
  /// `null`, wenn dadurch keine Nacht übrig bleibt **oder** keine der
  /// übrigen einen Stand trägt — „kein Cache" ist ein eigener Zustand (Spec
  /// 5.3d). Eine leere Karte mit einem Stand behauptete einen Lauf, den es
  /// nicht gab, und der Provider gäbe daraufhin `Bekannt({})` aus: ein
  /// Ladezustand als Leerstand, also genau Tims Fehler.
  ///
  /// **Grenze dieser Ablage, bekannt und nicht behoben:** Der Stand kommt
  /// aus `naechte.gelesen_am`, und diese Spalte gehört beiden Läufen — auch
  /// [schreibeNaechte] setzt sie. Wird der Cache gelesen, **nachdem** ein
  /// Schlaflauf die Zeile angefasst hat, trägt eine ältere, unveränderte
  /// Nachtwert-Zeile den Zeitpunkt dieses Schlaflaufs. Ein vierter
  /// Zeitstempel allein für die drei Spalten wäre die saubere Antwort, und
  /// die sieht die Spec nicht vor; `nachtWerteProvider` umgeht den Fall,
  /// indem er den Cache **vor** dem Schlaflauf liest und je Lauf genau
  /// einmal (siehe dort).
  Future<({Map<String, NightVitals> werte, DateTime stand})?> liesNachtWerte(
    DataWindow fenster,
  ) async {
    final abfrage = _db.select(_db.naechte)
      ..orderBy([(t) => OrderingTerm.asc(t.tag)]);
    final start = fenster.start;
    if (start != null) {
      final tagesSchluessel = BerlinCalendar.dayKey(start);
      abfrage.where((t) => t.tag.isBiggerOrEqualValue(tagesSchluessel));
    }

    final zeilen = await abfrage.get();
    final werte = <String, NightVitals>{};
    for (final zeile in zeilen) {
      if (zeile.ruhepulsBpm == null &&
          zeile.hrvMs == null &&
          zeile.respRate == null) {
        continue;
      }
      werte[zeile.tag] = NightVitals(
        restingHeartRate: zeile.ruhepulsBpm,
        hrv: zeile.hrvMs,
        respiratoryRate: zeile.respRate,
      );
    }
    if (werte.isEmpty) return null;

    // Derselbe Ausdruck wie in [liesTagesWerte] und [liesNaechte]: das
    // jüngste `gelesenAm` der tatsächlich zurückgegebenen Nächte, nicht das
    // irgendeiner Nacht außerhalb des Fensters.
    DateTime? stand;
    for (final zeile in zeilen) {
      if (!werte.containsKey(zeile.tag)) continue;
      final gelesenAm = zeile.gelesenAm;
      if (gelesenAm == null) continue;
      if (stand == null || gelesenAm.isAfter(stand)) stand = gelesenAm;
    }
    if (stand == null) return null;

    return (werte: werte, stand: stand);
  }

  /// Schreibt die gerechneten Nachtwerte eines Laufs zurück. `gelesenAm`
  /// gilt für **alle** Nächte dieses Aufrufs gleich — ein Lauf hat einen
  /// Zeitpunkt (Spec 5.3b). Dass damit auch der Stand der Nacht selbst auf
  /// diesen Lauf rückt, ist gewollt: Beide Läufe gehören zum selben Start
  /// der App, und ein zweiter Zeitstempel allein für die drei Spalten wäre
  /// eine vierte Spalte, die die Spec nicht vorsieht.
  ///
  /// **Diese Methode legt keine Nacht an.** Gibt es zu einem Tag keine
  /// Zeile in `Naechte`, bleibt es dabei — deshalb ein `update` und kein
  /// `insertOnConflictUpdate`. Eine Zeile ohne Abschnitte läse
  /// [liesNaechte] als Nacht **ohne Schlaf**: eine Nacht mit 0 Minuten,
  /// also ein erfundener Wert. Die Nachtwerte ergänzen eine Nacht, sie
  /// bringen keine hervor; im Betrieb hat der Schlaflauf sie vorher
  /// geschrieben.
  Future<void> schreibeNachtWerte(
    Map<String, NightVitals> werte, {
    required DateTime gelesenAm,
  }) async {
    if (werte.isEmpty) return;
    await _db.transaction(() async {
      for (final eintrag in werte.entries) {
        await (_db.update(
          _db.naechte,
        )..where((t) => t.tag.equals(eintrag.key))).write(
          NaechteCompanion(
            gelesenAm: Value(gelesenAm),
            ruhepulsBpm: Value(eintrag.value.restingHeartRate),
            hrvMs: Value(eintrag.value.hrv),
            respRate: Value(eintrag.value.respiratoryRate),
          ),
        );
      }
    });
  }

  /// Die Abschnitte einer Quelle als Zeilen. `phase` liegt als
  /// `SleepStage.name` in der Spalte, nicht als Index: Eine später
  /// eingefügte Phase verschöbe sonst die Bedeutung aller abgelegten Zeilen.
  ///
  /// Mit [markiereLeere] bekommt eine Quelle **ohne** Abschnitte eine
  /// einzige Markierungszeile. Ohne sie hinterließe ein leeres Nickerchen
  /// gar keine Zeile, und [liesNaechte] — das die Nickerchen aus den
  /// vorhandenen Quellen rekonstruiert — gäbe eines weniger zurück, als
  /// hineinging: `[leer, voll]` käme als `[voll]` heraus, und jede Zählung
  /// darüber wäre um eins daneben. Die Zusage des Caches ist, dass
  /// herauskommt, was hineinging.
  ///
  /// **Keine Schemaänderung, keine erfundenen Messwerte.** Eine Spalte mit
  /// der Zahl der Nickerchen auf `naechte` wäre der andere Weg und kostete
  /// eine Schemaversion samt Migration. Die Markierung kommt stattdessen
  /// mit dem aus, was die Tabelle hat: eine laufende Nummer, die es nicht
  /// gibt ([_leereQuelleLfdNr]), eine Phase, die kein `SleepStage.name`
  /// ist, und ein Zeitfenster der Länge null auf dem Nullpunkt der
  /// Unix-Zeit. Keiner dieser Werte sieht aus wie eine Messung, und
  /// [liesNaechte] baut daraus nie einen Abschnitt.
  Iterable<SchlafAbschnitteCompanion> _alsZeilen(
    String tag,
    int quelle,
    SleepSession sitzung, {
    bool markiereLeere = false,
  }) sync* {
    if (sitzung.segments.isEmpty) {
      if (markiereLeere) {
        yield SchlafAbschnitteCompanion.insert(
          tag: tag,
          quelle: quelle,
          lfdNr: _leereQuelleLfdNr,
          phase: _leereQuellePhase,
          beginn: _leereQuelleZeit,
          ende: _leereQuelleZeit,
        );
      }
      return;
    }
    for (var i = 0; i < sitzung.segments.length; i++) {
      final abschnitt = sitzung.segments[i];
      yield SchlafAbschnitteCompanion.insert(
        tag: tag,
        quelle: quelle,
        lfdNr: i,
        phase: abschnitt.stage.name,
        beginn: abschnitt.start,
        ende: abschnitt.end,
      );
    }
  }
}

/// Welche der vier Messreihen gemeint ist (#202, Spec Teil B) — die vier
/// Verlaufskarten des Messungen-Schirms.
///
/// **In der App-Schicht, nicht im Kern:** Das Enum benennt Spalten des
/// Caches, es trägt keine Rechnung (`CLAUDE.md`, „Transporttypen gehören
/// nicht in den Kern"). Der Kern kennt nur `MeasurementPoint` — welcher
/// Messwert in einer Reihe steht, weiß die Reihe, nicht der Punkt.
///
/// Genau vier Fälle, und zu jedem gibt es eine Spalte. Ein fünfter Fall
/// ohne Spalte dahinter wäre eine Anzeige, die nie etwas zeigt.
enum MessArt { gewicht, koerperfett, fettfreieMasse, ruhepuls }
