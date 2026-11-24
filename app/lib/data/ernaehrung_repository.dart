// Der Rundweg der Ernährungseinträge (Schema v12, Ernährungsplan Task 3):
// buchen, lesen, löschen und den Health-Stand fortschreiben. Die Tabellen
// liegen in `ernaehrung_tabellen.dart`, die Migration in `cache.dart`.
//
// API und Vertrag sind durch `app/test/data/ernaehrung_repository_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die eigene Tabelle ist die Wahrheit, Apple Health bekommt eine Kopie**
// (Tim, 03.11.2026). Daraus folgen die beiden Regeln, die diese Datei
// trägt:
//
// - **Gebucht wird immer**, auch ohne Schreibfreigabe. [HealthStand] hält
//   fest, was aus der Kopie geworden ist; `offen` heißt „noch nicht
//   geschrieben", nicht „nicht gespeichert"
//   (`docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, „Wenn die
//   Schreibfreigabe fehlt").
// - **Die Nährwerte sind eingefroren, nicht verwiesen.** Das Lebensmittel
//   ist Vorlage, der Eintrag ist Tatsache.
//
// **Es gibt keinen Schreibweg, der einen ganzen Tag ersetzt** — nur
// [ErnaehrungRepository.buche] und [ErnaehrungRepository.loesche]. Die
// Altapp hatte beide Hälften von #142: `schreibeErnaehrungsTage` verwarf
// die leere Liste, `schreibeMahlzeiten` leerte dafür den Tag. Dieser
// Schnitt macht das unausdrückbar.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Was aus der Kopie nach Apple Health geworden ist.
///
/// Drei Fälle, nicht zwei: `nicht_moeglich` ist der, in dem HealthKit den
/// Typ abgelehnt hat. Der wird nicht endlos erneut versucht — käme er
/// wieder in die Liste der offenen, liefe der Nachlauf bei jedem Start
/// gegen dieselbe Wand.
enum HealthStand {
  /// Noch nicht nach Health geschrieben — der Normalfall direkt nach dem
  /// Buchen, auch mit erteilter Freigabe (geschrieben wird danach).
  offen,

  /// Drüben, mit [Eintrag.healthUuid] als Beleg.
  geschrieben,

  /// HealthKit hat den Typ abgelehnt. Kein erneuter Versuch.
  nichtMoeglich,
}

/// Ein gebuchter Eintrag: was zu welcher Mahlzeit auf dem Teller lag.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Die Tagesliste
/// ist Abhängigkeit eines Providers; ohne Wertgleichheit baute jeder
/// Lesevorgang neue, ungleiche Objekte, und Ring, Makros und Verlauf
/// rechneten bei jedem Zugriff neu — Fehler `03`, wortgleich, im neuen
/// Code (`CLAUDE.md`).
@immutable
class Eintrag {
  const Eintrag({
    this.id,
    required this.tagesSchluessel,
    required this.mahlzeit,
    required this.zeitpunkt,
    this.lebensmittelId,
    required this.name,
    this.mengeG,
    required this.naehrwerte,
    this.healthUuid,
    this.healthStand = HealthStand.offen,
    this.vorschlag,
    this.portionId,
    this.portionName,
    this.portionG,
    this.fluessig,
  });

  /// Der Schlüssel, unter dem der Eintrag steht — `null`, solange er noch
  /// nicht gebucht ist. Ohne ihn gibt es kein [ErnaehrungRepository.loesche]
  /// und kein [ErnaehrungRepository.setzeHealthStand].
  final int? id;

  /// Der **Esstag** als ISO-Tagesstring, nicht der Kalendertag von
  /// [zeitpunkt]: Ein Eintrag um 01:30 gehört zum Abend davor.
  ///
  /// **Die Datenschicht rechnet ihn nicht aus.** Er kommt vom
  /// Buchungsblatt — Tim kann die Mahlzeit dort auf einen anderen Tag
  /// legen, und wer über ‹ › einen Tag offen hat, meint diesen Tag. Ein
  /// selbst gerechneter Esstag überstimmte das stillschweigend.
  final String tagesSchluessel;

  final Mahlzeit mahlzeit;

  /// Wann gegessen wurde, als UTC-Zeitpunkt.
  final DateTime zeitpunkt;

  /// Die Vorlage — `null` beim Schnelleintrag „nur Kalorien".
  final int? lebensmittelId;

  /// Was auf dem Teller lag. Auch der Schnelleintrag trägt einen Namen.
  final String name;

  /// Die gegessene Menge in Gramm — `null` beim Schnelleintrag, der
  /// nichts wiegt. **Nicht `0`:** „nicht gewogen" ist nicht „0 g
  /// gegessen", und genau diese Unterscheidung trägt den ganzen Schirm.
  final double? mengeG;

  /// Die **eingefrorenen** Nährwerte — die Zahlen, die beim Buchen
  /// galten, kein Verweis auf [lebensmittelId].
  ///
  /// `Naehrwerte` aus `trainings_core` und kein eigener Typ: Ein zweiter
  /// Typ für dieselben acht Felder wäre eine zweite Stelle, an der `null`
  /// zu `0` werden kann.
  final Naehrwerte naehrwerte;

  /// Die UUID der Probe in Apple Health — `null`, solange nicht
  /// geschrieben wurde.
  final String? healthUuid;

  /// Was aus der Kopie geworden ist. Ein frisch gebuchter Eintrag steht
  /// auf [HealthStand.offen].
  final HealthStand healthStand;

  /// Woher der Eintrag stammt, wenn ihn ein KI-Vorschlag angelegt hat —
  /// die Herkunft als JSON-Text (`KiHerkunft.alsJson`, Spalte
  /// `eintraege.vorschlag`). `null` heißt: von Hand gebucht.
  ///
  /// **Text, kein `KiHerkunft`:** So trägt das Feld Wertgleichheit ohne
  /// eigenes `==`, und ein Eintrag sagt nur, *dass* er geschätzt war —
  /// gelesen wird die Herkunft, wo sie gezeigt wird.
  ///
  /// **Unveränderlich nach dem Buchen.** Gesetzt wird sie nur von
  /// [ErnaehrungRepository.buche] und [ErnaehrungRepository.bucheAlle];
  /// [ErnaehrungRepository.aktualisiere] fasst die Spalte nicht an. Ein geänderter Eintrag bleibt als
  /// Schätzung erkennbar (Spec KI-Zugang, „Was gebucht ist, bleibt als
  /// Schätzung erkennbar").
  final String? vorschlag;

  /// Die Portion, mit der gebucht wurde (#325) — über sie findet die
  /// Vorwahl die Portion wieder, auch nachdem sie umbenannt wurde. `null`
  /// heißt: ohne Portion gebucht, oder die Portion hatte beim Buchen keine
  /// Zeile. **Kein Verweis, aus dem gelesen wird:** Name und Gramm stehen
  /// in [portionName] und [portionG].
  final int? portionId;

  /// Der Name der Portion **beim Buchen** — ein Schnappschuss, eingefroren
  /// wie die Nährwerte (#325, Entscheidung 8). Wird die Portion später
  /// umbenannt oder gelöscht, steht hier weiter, womit gebucht wurde.
  /// Steht nur zusammen mit [portionG] da.
  final String? portionName;

  /// Die Gramm bzw. Milliliter **einer** Portion beim Buchen —
  /// Schnappschuss wie [portionName]. **Keine Anzahl:** Sie ist
  /// [mengeG] / [portionG], und ein zweites Feld könnte dem ersten
  /// widersprechen.
  final double? portionG;

  /// Ob in Millilitern gebucht wurde (#403) — ein **Schnappschuss** von
  /// `LebensmittelVorlage.fluessig` beim Buchen, eingefroren wie die
  /// Nährwerte. `true` heißt „in Millilitern", `false` „in Gramm", `null`
  /// „unbekannt" — so steht es in jedem Eintrag von vor der Stufe 20.
  ///
  /// **Das Repository liest die Spalte, wie sie dasteht.** Den Rückfall
  /// auf die Vorlage bei `null` macht die Anzeige, nicht der Leseweg —
  /// sonst schriebe [ErnaehrungRepository.aktualisiere] beim nächsten
  /// Sichern den heutigen Stand der Vorlage als Schnappschuss fest.
  final bool? fluessig;

  /// Eine Kopie mit geänderten Feldern. Nullbare Felder nehmen einen
  /// [ValueGetter], damit sich auch `null` setzen lässt: `healthUuid: () =>
  /// null` leert die Kennung, ein weggelassenes Argument lässt sie stehen.
  Eintrag copyWith({
    ValueGetter<int?>? id,
    String? tagesSchluessel,
    Mahlzeit? mahlzeit,
    DateTime? zeitpunkt,
    ValueGetter<int?>? lebensmittelId,
    String? name,
    ValueGetter<double?>? mengeG,
    Naehrwerte? naehrwerte,
    ValueGetter<String?>? healthUuid,
    HealthStand? healthStand,
    ValueGetter<String?>? vorschlag,
    ValueGetter<int?>? portionId,
    ValueGetter<String?>? portionName,
    ValueGetter<double?>? portionG,
    ValueGetter<bool?>? fluessig,
  }) => Eintrag(
    id: id == null ? this.id : id(),
    tagesSchluessel: tagesSchluessel ?? this.tagesSchluessel,
    mahlzeit: mahlzeit ?? this.mahlzeit,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    lebensmittelId: lebensmittelId == null
        ? this.lebensmittelId
        : lebensmittelId(),
    name: name ?? this.name,
    mengeG: mengeG == null ? this.mengeG : mengeG(),
    naehrwerte: naehrwerte ?? this.naehrwerte,
    healthUuid: healthUuid == null ? this.healthUuid : healthUuid(),
    healthStand: healthStand ?? this.healthStand,
    vorschlag: vorschlag == null ? this.vorschlag : vorschlag(),
    portionId: portionId == null ? this.portionId : portionId(),
    portionName: portionName == null ? this.portionName : portionName(),
    portionG: portionG == null ? this.portionG : portionG(),
    fluessig: fluessig == null ? this.fluessig : fluessig(),
  );

  @override
  bool operator ==(Object other) =>
      other is Eintrag &&
      other.id == id &&
      other.tagesSchluessel == tagesSchluessel &&
      other.mahlzeit == mahlzeit &&
      other.zeitpunkt == zeitpunkt &&
      other.lebensmittelId == lebensmittelId &&
      other.name == name &&
      other.mengeG == mengeG &&
      other.naehrwerte == naehrwerte &&
      other.healthUuid == healthUuid &&
      other.healthStand == healthStand &&
      other.vorschlag == vorschlag &&
      other.portionId == portionId &&
      other.portionName == portionName &&
      other.portionG == portionG &&
      other.fluessig == fluessig;

  @override
  int get hashCode => Object.hash(
    id,
    tagesSchluessel,
    mahlzeit,
    zeitpunkt,
    lebensmittelId,
    name,
    mengeG,
    naehrwerte,
    healthUuid,
    healthStand,
    vorschlag,
    portionId,
    portionName,
    portionG,
    fluessig,
  );

  @override
  String toString() =>
      'Eintrag(id: $id, tagesSchluessel: $tagesSchluessel, '
      'mahlzeit: $mahlzeit, zeitpunkt: $zeitpunkt, '
      'lebensmittelId: $lebensmittelId, name: $name, mengeG: $mengeG, '
      'naehrwerte: $naehrwerte, healthUuid: $healthUuid, '
      'healthStand: $healthStand, vorschlag: $vorschlag, '
      'portionId: $portionId, portionName: $portionName, '
      'portionG: $portionG, fluessig: $fluessig)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und [Eintrag] — derselbe
/// Schnitt wie bei `StammdatenRepository` und `ZieleRepository`: SQL hier,
/// Riverpod nebenan.
class ErnaehrungRepository {
  ErnaehrungRepository(this._db);

  final AppCache _db;

  /// Die Einträge **eines Esstags**, nach [Eintrag.zeitpunkt] aufsteigend.
  ///
  /// **Gefiltert wird in SQL** (`WHERE tages_schluessel = ?`), nicht
  /// hinterher in Dart. Eine Abfrage ohne den Tagesschlüssel holte jede
  /// jemals gebuchte Mahlzeit in den Speicher und würfe sie dann weg —
  /// das wächst mit jedem Monat, den Tim die App benutzt, und ist Fehler
  /// `03` in der Datenschicht (`CLAUDE.md`, Hausregel 2). Sortiert wird
  /// ebenfalls in SQL; die Zeitpunkte liegen als ISO-Text, und der
  /// vergleicht sich lexikografisch wie chronologisch.
  ///
  /// Ein Tag ohne Einträge antwortet mit einer **leeren Liste**, nicht mit
  /// `null`: Für Tims eigene Daten gibt es keinen Lauf, der leer ausgehen
  /// kann — leer heißt hier schlicht leer.
  Future<List<Eintrag>> eintraegeAmTag(String tagesSchluessel) async {
    final zeilen =
        await (_db.select(_db.eintraege)
              ..where((t) => t.tagesSchluessel.equals(tagesSchluessel))
              ..orderBy([(t) => OrderingTerm(expression: t.zeitpunkt)]))
            .get();
    return zeilen.map(_ausZeile).toList();
  }

  /// Die Summen der eigenen Einträge je **Esstag** von [von] bis [bis],
  /// beide eingeschlossen — die Datengrundlage des 14-Tage-Verlaufs
  /// (#312).
  ///
  /// **In SQL gefiltert und summiert** — eine Abfrage, egal wie viele
  /// Tage (Hausregel 2). Gefiltert wird über den Tagesschlüssel, nicht
  /// über den Zeitpunkt: Ein Eintrag um 01:30 gehört zum Abend davor, und
  /// der ISO-Tagesstring vergleicht lexikografisch richtig, auch über eine
  /// Zeitumstellung.
  ///
  /// **Ein Tag ohne Eintrag fehlt in der Map**; er steht nicht mit 0 drin
  /// — „nichts eingetragen" ist keine Aussage über das Gegessene. Je
  /// Spalte gilt die Regel von `SUM`, die auch `Naehrwerte.+` hat: Fehlt
  /// der Wert in allen Einträgen eines Tages, ist die Summe `null`; fehlt
  /// er nur in einigen, zählen die vorhandenen. Eine gewogene `0` bleibt
  /// `0` (#232). `extra` wird nicht summiert und bleibt leer.
  Future<Map<String, Naehrwerte>> tagessummen({
    required String von,
    required String bis,
  }) async {
    final zeilen = await _db
        .customSelect(
          'SELECT tages_schluessel, '
          'SUM(kcal) AS kcal, '
          'SUM(eiweiss_g) AS eiweiss_g, '
          'SUM(kohlenhydrate_g) AS kohlenhydrate_g, '
          'SUM(fett_g) AS fett_g, '
          'SUM(zucker_g) AS zucker_g, '
          'SUM(ballaststoffe_g) AS ballaststoffe_g, '
          'SUM(gesaettigt_g) AS gesaettigt_g, '
          'SUM(wasser_ml) AS wasser_ml '
          'FROM eintraege '
          'WHERE tages_schluessel >= ? AND tages_schluessel <= ? '
          'GROUP BY tages_schluessel '
          'ORDER BY tages_schluessel',
          variables: [Variable.withString(von), Variable.withString(bis)],
          readsFrom: {_db.eintraege},
        )
        .get();

    double? zahl(QueryRow zeile, String spalte) =>
        (zeile.data[spalte] as num?)?.toDouble();

    return {
      for (final zeile in zeilen)
        zeile.read<String>('tages_schluessel'): Naehrwerte(
          kcal: zahl(zeile, 'kcal'),
          eiweissG: zahl(zeile, 'eiweiss_g'),
          kohlenhydrateG: zahl(zeile, 'kohlenhydrate_g'),
          fettG: zahl(zeile, 'fett_g'),
          zuckerG: zahl(zeile, 'zucker_g'),
          ballaststoffeG: zahl(zeile, 'ballaststoffe_g'),
          gesaettigtG: zahl(zeile, 'gesaettigt_g'),
          wasserMl: zahl(zeile, 'wasser_ml'),
        ),
    };
  }

  /// Je **Esstag** bis [bis] (eingeschlossen) die Menge der Mahlzeiten mit
  /// mindestens einem eigenen Eintrag — die Datengrundlage der Serie der
  /// Live-Aktivität (#368).
  ///
  /// **In SQL gefiltert und entdoppelt** (`DISTINCT`, Hausregel 2): eine
  /// Abfrage, egal wie viele Tage, und höchstens vier Zeilen je Tag statt
  /// einer je Eintrag. **Eine untere Grenze gibt es nicht** — sonst wäre
  /// eine Serie, die länger ist als das Fenster, still zu kurz (Spec,
  /// „Zustand").
  ///
  /// Gezählt wird der Tagesschlüssel des Eintrags, nicht der Kalendertag
  /// seines Zeitpunkts: Ein Eintrag um 01:30 gehört zum Abend davor. Ein
  /// Tag ohne Eintrag fehlt in der Map.
  Future<Map<String, Set<Mahlzeit>>> mahlzeitenJeTag({
    required String bis,
  }) async {
    final zeilen = await _db
        .customSelect(
          'SELECT DISTINCT tages_schluessel, mahlzeit '
          'FROM eintraege '
          'WHERE tages_schluessel <= ?',
          variables: [Variable.withString(bis)],
          readsFrom: {_db.eintraege},
        )
        .get();

    final jeTag = <String, Set<Mahlzeit>>{};
    for (final zeile in zeilen) {
      jeTag
          .putIfAbsent(zeile.read<String>('tages_schluessel'), () => {})
          .add(Mahlzeit.values.byName(zeile.read<String>('mahlzeit')));
    }
    return jeTag;
  }

  /// Legt einen neuen Eintrag an. [Eintrag.id] wird dabei vergeben, ein
  /// mitgegebener Wert nicht übernommen — wer einen bestehenden Eintrag
  /// ändern will, nimmt [aktualisiere].
  ///
  /// Jedes Feld geht einzeln hinein; `null` bleibt `null`, und eine
  /// gewogene `0` bleibt `0`. Ein Schreibweg, der `0` für „leer" hielte,
  /// würfe genau die Angabe weg, die Mineralwasser von „keine Angabe"
  /// unterscheidet.
  ///
  /// Gibt den vergebenen Schlüssel zurück — den braucht, wer danach den
  /// Health-Stand dieser einen Zeile fortschreibt (#283).
  Future<int> buche(Eintrag eintrag) =>
      _db.into(_db.eintraege).insert(_neueZeile(eintrag));

  /// Bucht mehrere Einträge **in einer Transaktion** — alle oder keiner.
  ///
  /// Der Weg eines KI-Vorschlags (#341): Ein Teller aus fünf Posten, von
  /// dem nach einem Fehler in der Mitte zwei gebucht stünden, wäre eine
  /// halbe Mahlzeit, die niemand so bestätigt hat. Jede Zeile geht wie bei
  /// [buche] hinein. Gibt die vergebenen Schlüssel in der Reihenfolge von
  /// [eintraege] zurück.
  Future<List<int>> bucheAlle(List<Eintrag> eintraege) =>
      _db.transaction(() async {
        final ids = <int>[];
        for (final eintrag in eintraege) {
          ids.add(await _db.into(_db.eintraege).insert(_neueZeile(eintrag)));
        }
        return ids;
      });

  EintraegeCompanion _neueZeile(Eintrag eintrag) {
    final werte = eintrag.naehrwerte;
    return EintraegeCompanion.insert(
      tagesSchluessel: eintrag.tagesSchluessel,
      mahlzeit: eintrag.mahlzeit.name,
      zeitpunkt: eintrag.zeitpunkt,
      lebensmittelId: Value(eintrag.lebensmittelId),
      name: eintrag.name,
      mengeG: Value(eintrag.mengeG),
      kcal: Value(werte.kcal),
      eiweissG: Value(werte.eiweissG),
      kohlenhydrateG: Value(werte.kohlenhydrateG),
      fettG: Value(werte.fettG),
      zuckerG: Value(werte.zuckerG),
      ballaststoffeG: Value(werte.ballaststoffeG),
      gesaettigtG: Value(werte.gesaettigtG),
      wasserMl: Value(werte.wasserMl),
      extra: Value(jsonEncode(werte.extra)),
      healthUuid: Value(eintrag.healthUuid),
      healthStand: Value(healthStandAlsText(eintrag.healthStand)),
      vorschlag: Value(eintrag.vorschlag),
      portionId: Value(eintrag.portionId),
      portionName: Value(eintrag.portionName),
      portionG: Value(eintrag.portionG),
      fluessig: Value(eintrag.fluessig),
    );
  }

  /// Schreibt einen **bestehenden** Eintrag neu — alle Felder, auch die
  /// eingefrorenen Nährwerte (#285).
  ///
  /// **Ändern ist ein eigener Weg, kein zweites Buchen.** [buche] übernimmt
  /// eine mitgegebene `id` ausdrücklich nicht; wer das für „ändern"
  /// benutzte, legte eine zweite Zeile an und ließe die erste stehen.
  ///
  /// Wirft, wenn [Eintrag.id] `null` ist: Ein Eintrag ohne Schlüssel ist
  /// nicht gebucht, und ihn zu „ändern" wäre ein Programmierfehler, keine
  /// Datenlage.
  ///
  /// **Jedes Feld geht als `Value(...)` hinein, auch `null`** — nie als
  /// `Value.absent()`. Wer eine Mengenangabe löscht, hat sie gelöscht; ein
  /// Schreibweg, der `null` als „bitte stehen lassen" läse, machte das
  /// Leeren unmöglich, und zwar lautlos. Dieselbe Regel wie bei
  /// `StammdatenRepository.schreibe`.
  ///
  /// **Der Health-Stand geht mit, er wird aber nicht erfunden:** Was
  /// hereinkommt, wird geschrieben. Was mit der Kopie in Apple Health
  /// geschieht, entscheidet der Nachlauf über [setzeHealthStand].
  ///
  /// **Der Portions-Schnappschuss geht mit** (#325, V12): Wer im
  /// Ändern-Blatt auf „g" wechselt und sichert, schickt alle drei Felder
  /// als `null`, und der Eintrag verliert seine Portion.
  ///
  /// **Die einzige Ausnahme ist [Eintrag.vorschlag]** — die Herkunft
  /// bleibt, wie sie gebucht wurde. Das Buchungsblatt kennt sie nicht;
  /// schriebe diese Methode sie mit, löschte jede Mengenkorrektur das
  /// Abzeichen „KI-Schätzung".
  Future<void> aktualisiere(Eintrag eintrag) async {
    final id = eintrag.id;
    if (id == null) {
      throw ArgumentError.notNull('eintrag.id');
    }

    final werte = eintrag.naehrwerte;
    await (_db.update(_db.eintraege)..where((t) => t.id.equals(id))).write(
      EintraegeCompanion(
        tagesSchluessel: Value(eintrag.tagesSchluessel),
        mahlzeit: Value(eintrag.mahlzeit.name),
        zeitpunkt: Value(eintrag.zeitpunkt),
        lebensmittelId: Value(eintrag.lebensmittelId),
        name: Value(eintrag.name),
        mengeG: Value(eintrag.mengeG),
        kcal: Value(werte.kcal),
        eiweissG: Value(werte.eiweissG),
        kohlenhydrateG: Value(werte.kohlenhydrateG),
        fettG: Value(werte.fettG),
        zuckerG: Value(werte.zuckerG),
        ballaststoffeG: Value(werte.ballaststoffeG),
        gesaettigtG: Value(werte.gesaettigtG),
        wasserMl: Value(werte.wasserMl),
        extra: Value(jsonEncode(werte.extra)),
        healthUuid: Value(eintrag.healthUuid),
        healthStand: Value(healthStandAlsText(eintrag.healthStand)),
        portionId: Value(eintrag.portionId),
        portionName: Value(eintrag.portionName),
        portionG: Value(eintrag.portionG),
        fluessig: Value(eintrag.fluessig),
      ),
    );
  }

  /// **Ein** Eintrag samt Health-Stand und Kennung, frisch aus der Tabelle
  /// — oder `null`, wenn es die Zeile nicht (mehr) gibt.
  ///
  /// Dafür da, dass „Rückgängig" nicht mit dem Stand arbeitet, der beim
  /// Buchen galt: Die Kopie in Health kann erst danach geschrieben worden
  /// sein, und mit der alten, leeren Kennung bliebe sie stehen (V27).
  Future<Eintrag?> eintrag(int id) async {
    final zeile = await (_db.select(
      _db.eintraege,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return zeile == null ? null : _ausZeile(zeile);
  }

  /// Nimmt **genau eine Zeile** weg. Eine unbekannte `id` ändert nichts —
  /// ein zweiter Druck auf „Löschen" oder ein Nachlauf auf einem längst
  /// gelöschten Eintrag darf nicht mehr wegnehmen als die eine Zeile, die
  /// es nicht mehr gibt.
  Future<void> loesche(int id) async {
    await (_db.delete(_db.eintraege)..where((t) => t.id.equals(id))).go();
  }

  /// Schreibt den Health-Stand **einer** Zeile fort. Ein Update ohne
  /// `WHERE id = ?` setzte den Stand des ganzen Tages.
  ///
  /// Die UUID bleibt, wie sie ist: Sie gehört zum Schreibvorgang, nicht
  /// zum Stand, und wird dort gesetzt, wo sie entsteht.
  Future<void> setzeHealthStand(int id, HealthStand stand) async {
    await (_db.update(_db.eintraege)..where((t) => t.id.equals(id))).write(
      EintraegeCompanion(healthStand: Value(healthStandAlsText(stand))),
    );
  }

  /// Schreibt fest, was aus der Kopie **einer** Zeile geworden ist: Stand
  /// und Kennung zusammen (#283).
  ///
  /// Anders als [setzeHealthStand] setzt diese Methode die Kennung mit —
  /// auch auf `null`. Nach dem Schreiben gehören beide zusammen: eine neue
  /// Kennung ohne `geschrieben` oder ein `geschrieben` mit der Kennung
  /// einer gelöschten Probe behaupteten jeweils eine Kopie, die es so
  /// nicht gibt.
  Future<void> setzeHealthKopie(
    int id, {
    required String? healthUuid,
    required HealthStand stand,
  }) async {
    await (_db.update(_db.eintraege)..where((t) => t.id.equals(id))).write(
      EintraegeCompanion(
        healthUuid: Value(healthUuid),
        healthStand: Value(healthStandAlsText(stand)),
      ),
    );
  }

  /// Alles, was noch nicht nach Apple Health geschrieben ist — **über alle
  /// Tage**, das Älteste zuerst.
  ///
  /// Der Nachlauf fragt nicht nach einem Tag, sondern nach allem, was noch
  /// nicht drüben ist. [HealthStand.nichtMoeglich] ist nicht dabei.
  Future<List<Eintrag>> offeneHealthEintraege() async {
    final zeilen =
        await (_db.select(_db.eintraege)
              ..where(
                (t) =>
                    t.healthStand.equals(healthStandAlsText(HealthStand.offen)),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.zeitpunkt)]))
            .get();
    return zeilen.map(_ausZeile).toList();
  }

  Eintrag _ausZeile(EintragRow zeile) => Eintrag(
    id: zeile.id,
    tagesSchluessel: zeile.tagesSchluessel,
    mahlzeit: Mahlzeit.values.byName(zeile.mahlzeit),
    zeitpunkt: zeile.zeitpunkt,
    lebensmittelId: zeile.lebensmittelId,
    name: zeile.name,
    mengeG: zeile.mengeG,
    naehrwerte: Naehrwerte(
      kcal: zeile.kcal,
      eiweissG: zeile.eiweissG,
      kohlenhydrateG: zeile.kohlenhydrateG,
      fettG: zeile.fettG,
      zuckerG: zeile.zuckerG,
      ballaststoffeG: zeile.ballaststoffeG,
      gesaettigtG: zeile.gesaettigtG,
      wasserMl: zeile.wasserMl,
      extra: _extraAusText(zeile.extra),
    ),
    healthUuid: zeile.healthUuid,
    healthStand: healthStandAusText(zeile.healthStand),
    vorschlag: zeile.vorschlag,
    portionId: zeile.portionId,
    portionName: zeile.portionName,
    portionG: zeile.portionG,
    fluessig: zeile.fluessig,
  );

  /// Die jüngste Buchung eines Lebensmittels — die Grundlage der Vorwahl
  /// im Buchungsblatt (#325, Entscheidung 7) —, oder `null` ohne Eintrag.
  ///
  /// **Jüngste heißt: zuletzt gebucht, nicht zuletzt gegessen.** Gelesen
  /// wird nach `id DESC`, nicht nach `zeitpunkt`: Wer eben 2 Bons für den
  /// Mittag nachgetragen hat, meint beim nächsten Buchen wieder 2 Bons,
  /// auch wenn ein früher gebuchter Eintrag auf dem Abend liegt (Spec,
  /// „Vorwahl"). **Gefiltert und begrenzt wird in SQL** — eine Zeile,
  /// drei Spalten, egal wie viel schon gebucht ist (Hausregel 2).
  Future<LetzteBuchung?> letzteBuchung(int lebensmittelId) async {
    final t = _db.eintraege;
    final zeile =
        await (_db.selectOnly(t)
              ..addColumns([t.mengeG, t.portionId, t.portionG])
              ..where(t.lebensmittelId.equals(lebensmittelId))
              ..orderBy([
                OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (zeile == null) return null;
    return LetzteBuchung(
      mengeG: zeile.read(t.mengeG),
      portionId: zeile.read(t.portionId),
      portionG: zeile.read(t.portionG),
    );
  }

  /// Je Lebensmittel aus [lebensmittelIds] der **ganze** Eintrag der
  /// jüngsten Buchung, samt Portions-Schnappschuss — die Grundlage der
  /// Trefferzeile „2 Bon (11,8 g)" in der Suche (#401, V9).
  ///
  /// **Jüngste heißt höchste `id`**, wie bei [letzteBuchung]: zuletzt
  /// gebucht, nicht zuletzt gegessen.
  ///
  /// **Eine Abfrage, egal wie viele Lebensmittel** (Hausregel 2): Die
  /// Unterabfrage sucht je Lebensmittel die größte `id`, die äußere holt
  /// genau diese Zeilen. SQLite führt beides als **ein** `SELECT` aus. Je
  /// Treffer eine Abfrage wäre die Suche, die je Zeile rechnet.
  ///
  /// Ein Lebensmittel ohne Eintrag hat **keinen Schlüssel**. Eine leere
  /// Menge fragt die Datenbank gar nicht erst.
  Future<Map<int, Eintrag>> letzteBuchungen(Set<int> lebensmittelIds) async {
    if (lebensmittelIds.isEmpty) return const {};
    final t = _db.eintraege;
    final juengste = _db.selectOnly(t)
      ..addColumns([t.id.max()])
      ..where(t.lebensmittelId.isIn(lebensmittelIds))
      ..groupBy([t.lebensmittelId]);
    final zeilen = await (_db.select(
      t,
    )..where((r) => r.id.isInQuery(juengste))).get();
    return {
      for (final zeile in zeilen) zeile.lebensmittelId!: _ausZeile(zeile),
    };
  }
}

/// Die drei Wörter, unter denen der Stand in der Datei liegt — genau so,
/// wie der Entwurf die Spalte benennt („Wenn die Schreibfreigabe fehlt").
///
/// **Öffentlich, weil `wasser_eintraege` dieselben Wörter trägt** (#311):
/// eine zweite Zuordnung dort wäre eine zweite Stelle, die auseinanderläuft.
///
/// `HealthStand.nichtMoeglich.name` wäre `nichtMoeglich`; abgelegt wird
/// `nicht_moeglich`, deshalb steht die Zuordnung hier von Hand statt über
/// `.name`. Der `switch` über den Enum ist vollständig — käme ein vierter
/// Stand dazu, zeigt der Analyzer auf diese Stelle.
String healthStandAlsText(HealthStand stand) => switch (stand) {
  HealthStand.offen => 'offen',
  HealthStand.geschrieben => 'geschrieben',
  HealthStand.nichtMoeglich => 'nicht_moeglich',
};

/// Die Gegenrichtung. Ein unbekanntes Wort **wirft**, statt still auf
/// `offen` zu fallen: Das wäre ein Eintrag, den der Nachlauf ein zweites
/// Mal nach Health schriebe, und niemand sähe, warum. Dieselbe Haltung wie
/// bei `SleepStage.values.byName(...)` in `cache_repository.dart` — ein
/// falscher Wert ist ein Programmierfehler, keine Datenlage.
HealthStand healthStandAusText(String text) => switch (text) {
  'offen' => HealthStand.offen,
  'geschrieben' => HealthStand.geschrieben,
  'nicht_moeglich' => HealthStand.nichtMoeglich,
  _ => throw ArgumentError.value(text, 'health_stand', 'unbekannter Stand'),
};

/// Die JSON-Spalte als Map.
///
/// **Ein Schlüssel mit Wert `null` bleibt erhalten** — „bekannt als
/// unbekannt" ist eine andere Auskunft als „nie gefragt", und `#232` ist
/// genau die Verwechslung von fehlend und `0`. `jsonDecode` liefert `num`;
/// `toDouble()` macht daraus den Typ, den `Naehrwerte` trägt, ohne einen
/// fehlenden Wert zu erfinden.
Map<String, double?> _extraAusText(String text) {
  final roh = jsonDecode(text) as Map<String, dynamic>;
  return {
    for (final eintrag in roh.entries)
      eintrag.key: (eintrag.value as num?)?.toDouble(),
  };
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `stammdatenRepositoryProvider` und `zieleRepositoryProvider`.
final ernaehrungRepositoryProvider = Provider<ErnaehrungRepository>(
  (ref) => ErnaehrungRepository(ref.watch(appCacheProvider)),
);
