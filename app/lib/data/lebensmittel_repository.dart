// Die **Vorlagenhälfte** der Ernährung (#285, Schema v13): Lebensmittel
// anlegen, wiederfinden, ändern — und seit #284 (Schema v14) aus Open
// Food Facts übernehmen. Die Tatsachenhälfte — das Gebuchte — liegt
// nebenan in `ernaehrung_repository.dart`, die Tabelle in
// `ernaehrung_tabellen.dart`, die Migration in `cache.dart`.
//
// API und Vertrag sind durch
// `app/test/ernaehrung/lebensmittel_repository_test.dart` und
// `app/test/ernaehrung/lebensmittel_herkunft_test.dart` verbindlich
// vorgegeben (siehe deren Dateiköpfe) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Das Lebensmittel ist Vorlage, der Eintrag ist Tatsache**
// (`docs/superpowers/specs/2026-11-03-ernaehrung-design.md`,
// „Eingefrorene Nährwerte"). Daraus folgt alles, was diese Datei
// **nicht** tut: Sie fasst keinen gebuchten Eintrag an. Wer ein
// Lebensmittel ändert oder löscht, ändert keine Zahl, die schon auf einem
// Tag steht.
//
// **Gefiltert und sortiert wird in SQL** (`CLAUDE.md`, Hausregel 2): Eine
// Abfrage ohne `WHERE` holte jedes jemals angelegte Lebensmittel in den
// Speicher und würfe es dann weg — das wächst mit jedem Monat, den Tim
// die App benutzt, und ist Fehler `03` in der Datenschicht.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';
import 'portion.dart';
import 'portionen_repository.dart';

/// Woher eine Vorlage stammt (#284). In der Datenbank als Text: `'eigen'`,
/// `'off'`, `'bls'` — der Name des Werts ist das, was in der Spalte steht.
enum Herkunft {
  /// Von Tim selbst angelegt.
  eigen,

  /// Aus Open Food Facts übernommen, beim ersten Buchen.
  off,

  /// Aus dem Bundeslebensmittelschlüssel der mitgelieferten
  /// Seed-Datenbank übernommen, beim ersten Buchen (#543).
  ///
  /// **Der Wert steht hier, bevor die erste Zeile damit geschrieben
  /// wird** (Spec, „Die Seed-Datenbank"): [_herkunftAusText] liest die
  /// Spalte über `Herkunft.values.byName` und wirft bei Unbekanntem.
  /// Käme er erst mit dem ersten Schreiben, wäre jede Datei, die einmal
  /// `bls` gesehen hat, für die Fassung davor unlesbar.
  ///
  /// Ein BLS-Eintrag trägt **keinen** Strichcode, sondern seinen BLS-Code
  /// in [LebensmittelVorlage.quelleSchluessel] — darüber erkennt
  /// [LebensmittelRepository.uebernimm] ihn wieder.
  bls,
}

/// Ein Lebensmittel als **Vorlage** — Nährwerte je 100 g.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Die Trefferliste
/// der Suche ist Abhängigkeit eines Providers; ohne Wertgleichheit baute
/// jeder Lesevorgang neue, ungleiche Objekte, und jeder abgeleitete Wert
/// liefe neu — Fehler `03`, wortgleich, im neuen Code (`CLAUDE.md`).
///
/// **`Vorlage` im Namen ist kein Hilfswort.** Es ist das Wort des
/// Entwurfs, und es trennt den Werttyp von der gleichnamigen Tabelle
/// `Lebensmittel`: Bei `Eintrag`/`Eintraege` trennt der Numerus, hier gibt
/// es keinen, der das könnte.
@immutable
class LebensmittelVorlage {
  const LebensmittelVorlage({
    this.id,
    required this.name,
    required this.je100g,
    this.fluessig = false,
    this.zuletztBenutzt,
    this.barcode,
    this.herkunft = Herkunft.eigen,
    this.quelleSchluessel,
    this.offPortionen,
    this.portionenAbgefragtAm,
  });

  /// Der Schlüssel, unter dem die Vorlage steht — `null`, solange sie noch
  /// nicht angelegt ist. Ohne ihn gibt es kein [LebensmittelRepository
  /// .aendere] und kein [LebensmittelRepository.merkeBenutzung].
  final int? id;

  /// Wie die Vorlage heißt — das, wonach die Suche sucht.
  final String name;

  /// Die Nährwerte **je 100 g**, so wie sie auf der Packung stehen. Das
  /// Buchungsblatt rechnet jede Menge daraus aus.
  ///
  /// Ein fehlender Wert ist `null`, nie `0`: Ein Lebensmittel ohne
  /// Zuckerangabe hat keine 0 g Zucker, es hat keine Angabe (#232). Eine
  /// **eingetragene** Null bleibt dagegen `0` — „zuckerfrei" ist eine
  /// Angabe.
  final Naehrwerte je100g;

  /// Ob in Millilitern gerechnet wird statt in Gramm — **das ist alles,
  /// was dieses Feld entscheidet.**
  final bool fluessig;

  /// Wann die Vorlage zuletzt gebucht wurde, als UTC-Zeitpunkt — `null`,
  /// solange nie. **Angelegt ist nicht benutzt:** kein `DateTime(0)` und
  /// kein „jetzt".
  final DateTime? zuletztBenutzt;

  /// Der Strichcode — `null` bei selbst angelegten Vorlagen.
  final String? barcode;

  /// Woher die Vorlage stammt. Ohne Angabe [Herkunft.eigen].
  final Herkunft herkunft;

  /// Der Schlüssel **in der Quelle**, aus der die Vorlage übernommen wurde
  /// (Schema v25, #543): der BLS-Code bei einem Generikum aus der
  /// Seed-Datenbank, die EAN bei einem Produkt aus Open Food Facts.
  /// `null` bei selbst angelegten Vorlagen.
  ///
  /// **Nicht dasselbe wie [barcode]**, auch wenn bei OFF beides
  /// gleichlautet: Ein BLS-Code ist kein Strichcode, und [zuBarcode] sucht
  /// Produkte, die man scannen kann (`Lebensmittel.quelleSchluessel`).
  final String? quelleSchluessel;

  /// Die Portionen aus Open Food Facts — gesetzt **nur bei einem noch
  /// nicht übernommenen OFF-Produkt** (#325). `null` heißt „nicht
  /// abgefragt" (Suchtreffer), `[]` heißt „gefragt, keine". Die beiden
  /// werden nicht vermischt: Ein gescanntes Produkt trägt hier seine
  /// Antwort und fragt beim Öffnen des Blatts nicht noch einmal.
  final List<Portion>? offPortionen;

  /// Wann Open Food Facts zu diesem Produkt einmal nach Portionen gefragt
  /// wurde **und geantwortet hat**, als UTC-Zeitpunkt (#325,
  /// Entscheidung 6, V4) — `null`, solange nie. Aus der Spalte
  /// `lebensmittel.portionen_abgefragt_am`.
  ///
  /// **Kein Vorgabewert:** Ein erfundener Zeitpunkt behauptete eine
  /// Anfrage, die es nie gab, und unterdrückte die einmalige Nachfrage.
  final DateTime? portionenAbgefragtAm;

  @override
  bool operator ==(Object other) =>
      other is LebensmittelVorlage &&
      other.id == id &&
      other.name == name &&
      other.je100g == je100g &&
      other.fluessig == fluessig &&
      other.zuletztBenutzt == zuletztBenutzt &&
      other.barcode == barcode &&
      other.herkunft == herkunft &&
      other.quelleSchluessel == quelleSchluessel &&
      listEquals(other.offPortionen, offPortionen) &&
      other.portionenAbgefragtAm == portionenAbgefragtAm;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    je100g,
    fluessig,
    zuletztBenutzt,
    barcode,
    herkunft,
    quelleSchluessel,
    offPortionen == null ? null : Object.hashAll(offPortionen!),
    portionenAbgefragtAm,
  );

  @override
  String toString() =>
      'LebensmittelVorlage(id: $id, name: $name, je100g: $je100g, '
      'fluessig: $fluessig, zuletztBenutzt: $zuletztBenutzt, '
      'barcode: $barcode, herkunft: ${herkunft.name}, '
      'quelleSchluessel: $quelleSchluessel, '
      'offPortionen: $offPortionen, '
      'portionenAbgefragtAm: $portionenAbgefragtAm)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und [LebensmittelVorlage] —
/// derselbe Schnitt wie bei `ErnaehrungRepository` und
/// `StammdatenRepository`: SQL hier, Riverpod nebenan.
class LebensmittelRepository {
  LebensmittelRepository(this._db);

  final AppCache _db;

  /// Legt eine neue Vorlage an und gibt ihren Schlüssel zurück — samt
  /// ihren [portionen] (#325, Anlegen-Blatt „Portionen · freiwillig").
  ///
  /// **Lebensmittel und Portionen stehen in einer Transaktion:** Scheitert
  /// eine Portion, steht weder das Lebensmittel noch eine Portion da, und
  /// der Fehler kommt heraus. Ein halb angelegtes Lebensmittel sähe aus wie
  /// eines ohne Portionen, und das hat Tim nicht so eingegeben. Jede
  /// Portion behält ihre Herkunft.
  ///
  /// [LebensmittelVorlage.zuletztBenutzt] geht dabei **nicht** mit: Was
  /// gerade erst entsteht, ist noch nie benutzt worden, und ein
  /// mitgegebener Zeitpunkt wäre eine Behauptung darüber, wann Tim es
  /// gegessen hat. [LebensmittelVorlage.portionenAbgefragtAm] geht mit,
  /// so wie es in der Vorlage steht.
  Future<int> legeAn(
    LebensmittelVorlage vorlage, {
    List<Portion> portionen = const [],
  }) => _db.transaction(
    () => _legeAnMitPortionen(
      vorlage,
      portionen: portionen,
      abgefragtAm: vorlage.portionenAbgefragtAm,
    ),
  );

  /// Der Schreibweg von [legeAn] und [uebernimm] — **ohne eigene
  /// Transaktion**; beide rufen ihn innerhalb ihrer auf.
  Future<int> _legeAnMitPortionen(
    LebensmittelVorlage vorlage, {
    required List<Portion> portionen,
    required DateTime? abgefragtAm,
  }) async {
    final id = await _db
        .into(_db.lebensmittel)
        .insert(
          LebensmittelCompanion.insert(
            name: Value(vorlage.name),
            kcal: Value(vorlage.je100g.kcal),
            eiweissG: Value(vorlage.je100g.eiweissG),
            kohlenhydrateG: Value(vorlage.je100g.kohlenhydrateG),
            fettG: Value(vorlage.je100g.fettG),
            zuckerG: Value(vorlage.je100g.zuckerG),
            ballaststoffeG: Value(vorlage.je100g.ballaststoffeG),
            gesaettigtG: Value(vorlage.je100g.gesaettigtG),
            wasserMl: Value(vorlage.je100g.wasserMl),
            extra: Value(jsonEncode(vorlage.je100g.extra)),
            fluessig: Value(vorlage.fluessig),
            barcode: Value(vorlage.barcode),
            herkunft: Value(vorlage.herkunft.name),
            quelleSchluessel: Value(vorlage.quelleSchluessel),
            portionenAbgefragtAm: Value(abgefragtAm?.toUtc()),
          ),
        );
    for (final portion in portionen) {
      await schreibePortion(_db, id, portion);
    }
    return id;
  }

  /// Übernimmt ein Produkt aus Open Food Facts oder einen Eintrag aus der
  /// Seed-Datenbank und gibt seinen Schlüssel zurück (#284, #543).
  ///
  /// **Zwei Abgleichwege, in dieser Reihenfolge** (Spec, „Die
  /// Seed-Datenbank"): erst der Strichcode, dann — und nur ohne
  /// Strichcode — [LebensmittelVorlage.quelleSchluessel]. Ein BLS-Eintrag
  /// hat keinen Strichcode, sondern seinen BLS-Code; ohne den zweiten Weg
  /// landete dasselbe Generikum bei jedem Buchen ein weiteres Mal in der
  /// Tabelle. Der Strichcode bleibt vorn, weil ein gescanntes Produkt
  /// seine eigene Zeile hat, auch wenn der Seed-Schlüssel daneben steht.
  ///
  /// **Liegt der Strichcode schon in der Tabelle, wird nichts angelegt
  /// und nichts überschrieben** — es gilt die vorhandene Zeile. Tim kann
  /// die eigene Kopie korrigiert haben, und ein stilles Überschreiben beim
  /// nächsten Buchen nähme ihm die Korrektur weg: Die eigene Tabelle ist
  /// die Wahrheit.
  ///
  /// Nachsehen und Anlegen stehen **in einer Transaktion**. Ohne sie
  /// könnten zwei schnell aufeinanderfolgende Buchungen beide „gibt es
  /// noch nicht" lesen und beide anlegen.
  ///
  /// [LebensmittelVorlage.zuletztBenutzt] geht nicht mit, aus demselben
  /// Grund wie bei [legeAn] — übernommen ist nicht gebucht; das merkt sich
  /// `ErfassenNotifier.buche`.
  ///
  /// **Die Portionen gehen mit** (#325, V3): Ist das Produkt neu, legt die
  /// Übernahme [LebensmittelVorlage.offPortionen] in derselben Transaktion
  /// an, jede mit ihrer Herkunft — eine im Blatt angelegte „Bon" bleibt
  /// `eigen`. Ist [LebensmittelVorlage.offPortionen] nicht `null`, wurde
  /// Open Food Facts gefragt und hat geantwortet, auch mit `[]`; dann
  /// steht danach `portionen_abgefragt_am = jetzt`. Bei `null` („nicht
  /// abgefragt") gilt, was die Vorlage trägt. **Liegt der Strichcode
  /// schon da, wird auch keine Portion angelegt und die Marke nicht
  /// angefasst.**
  ///
  /// Wirft `ArgumentError`, wenn **beide** Schlüssel fehlen —
  /// [LebensmittelVorlage.barcode] und
  /// [LebensmittelVorlage.quelleSchluessel]: Dann gibt es nichts
  /// wiederzuerkennen, und das wäre ein Programmierfehler, keine
  /// Datenlage. Was ohne jede Herkunft entsteht, ist eine eigene Vorlage
  /// und gehört zu [legeAn]. Ebenso, wenn
  /// [LebensmittelVorlage.offPortionen] gesetzt ist und [jetzt] fehlt —
  /// geprüft vor jedem Schreiben, nicht erst, wenn das Produkt neu ist.
  ///
  /// [ohneAntwort] sind Portionen, die im Buchungsblatt angelegt wurden,
  /// **bevor Open Food Facts geantwortet hat** — der Abruf lief noch oder
  /// ist gescheitert, [LebensmittelVorlage.offPortionen] ist deshalb
  /// `null` (#398). Sie gehen in derselben Transaktion mit, jede mit ihrer
  /// Herkunft, aber **die Marke bleibt, was die Vorlage trägt**: Ohne
  /// Antwort ist nicht gefragt (V4), und das Produkt fragt beim nächsten
  /// Öffnen wieder. *Vorgabe des Koordinators, nicht Tims Entscheidung.*
  /// Neben gesetzten [LebensmittelVorlage.offPortionen] wirft der
  /// Parameter `ArgumentError` — dort stehen die im Blatt angelegten schon
  /// in der Liste.
  Future<int> uebernimm(
    LebensmittelVorlage vorlage, {
    DateTime? jetzt,
    List<Portion> ohneAntwort = const [],
  }) async {
    final barcode = vorlage.barcode;
    final quelleSchluessel = vorlage.quelleSchluessel;
    if (barcode == null && quelleSchluessel == null) {
      // Beide Namen, nicht nur der erste: Wer die Meldung liest, soll
      // sehen, dass es zwei Wege gibt und keiner begangen wurde.
      throw ArgumentError.notNull('vorlage.barcode/vorlage.quelleSchluessel');
    }
    final offPortionen = vorlage.offPortionen;
    if (offPortionen != null && jetzt == null) {
      throw ArgumentError.notNull('jetzt');
    }
    if (offPortionen != null && ohneAntwort.isNotEmpty) {
      throw ArgumentError.value(
        ohneAntwort,
        'ohneAntwort',
        'neben gesetzten offPortionen',
      );
    }

    return _db.transaction(() async {
      final vorhanden = barcode != null
          ? await zuBarcode(barcode)
          : await zuQuelleSchluessel(quelleSchluessel!);
      final id = vorhanden?.id;
      if (id != null) return id;
      return _legeAnMitPortionen(
        vorlage,
        portionen: offPortionen ?? ohneAntwort,
        abgefragtAm: offPortionen != null
            ? jetzt
            : vorlage.portionenAbgefragtAm,
      );
    });
  }

  /// Trägt die Portionen eines **schon übernommenen** Produkts nach, das
  /// noch nie nach Portionen gefragt wurde (#325, Entscheidung 6, V5) —
  /// und antwortet, ob es das getan hat.
  ///
  /// **Einmal, nicht zweimal.** Ist `portionen_abgefragt_am` schon
  /// gesetzt, tut die Methode nichts und antwortet `false`. Prüfen und
  /// Setzen sind **ein** `UPDATE … WHERE portionen_abgefragt_am IS NULL`
  /// in derselben Transaktion wie das Anlegen der Portionen: Zwei schnell
  /// aufeinanderfolgende Nachfragen können nicht beide „noch nie gefragt"
  /// lesen und die Portionen doppelt anlegen.
  ///
  /// Jede Portion wird mit Herkunft `off` angelegt. [fluessig] setzt die
  /// Spalte nur von `false` auf `true`, nie zurück. Gebuchte Einträge
  /// bleiben, wie sie sind. Scheitert eine Portion, steht danach nichts
  /// davon da — keine Portion, keine Marke, `fluessig` wie vorher — und
  /// der Fehler kommt heraus.
  ///
  /// Wirft `ArgumentError`, wenn es kein Lebensmittel mit [id] gibt: Die
  /// Nachfrage gilt einer Zeile, die das Blatt gerade gelesen hat.
  Future<bool> trageOffPortionenNach(
    int id, {
    required List<Portion> portionen,
    required bool fluessig,
    required DateTime jetzt,
  }) => _db.transaction(() async {
    final geaendert =
        await (_db.update(_db.lebensmittel)
              ..where((t) => t.id.equals(id) & t.portionenAbgefragtAm.isNull()))
            .write(
              LebensmittelCompanion(
                portionenAbgefragtAm: Value(jetzt.toUtc()),
                fluessig: fluessig ? const Value(true) : const Value.absent(),
              ),
            );
    if (geaendert == 0) {
      if (await lies(id) == null) {
        throw ArgumentError.value(id, 'id', 'kein Lebensmittel');
      }
      return false;
    }

    for (final portion in portionen) {
      await schreibePortion(_db, id, portion, herkunft: Herkunft.off);
    }
    return true;
  });

  /// Die Vorlage zu einem Strichcode — `null`, wenn keine da ist.
  ///
  /// Gäbe es — etwa nach einem Zweigwechsel — doch zwei Zeilen mit
  /// demselben Strichcode, gilt die älteste: Auf sie zeigen die ersten
  /// Einträge, und sie ist die, die Tim zuerst gesehen hat.
  Future<LebensmittelVorlage?> zuBarcode(String barcode) async {
    final zeile =
        await (_db.select(_db.lebensmittel)
              ..where((t) => t.barcode.equals(barcode))
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(1))
            .getSingleOrNull();
    return zeile == null ? null : _ausZeile(zeile);
  }

  /// Die Vorlage zu einem Quellenschlüssel — dem BLS-Code aus der
  /// Seed-Datenbank oder der EAN aus Open Food Facts (#543). `null`, wenn
  /// keine da ist.
  ///
  /// Der zweite Abgleichweg von [uebernimm]. Gäbe es mehrere Zeilen mit
  /// demselben Schlüssel, gilt die älteste — aus demselben Grund wie bei
  /// [zuBarcode]: Auf sie zeigen die ersten Einträge.
  Future<LebensmittelVorlage?> zuQuelleSchluessel(String schluessel) async {
    final zeile =
        await (_db.select(_db.lebensmittel)
              ..where((t) => t.quelleSchluessel.equals(schluessel))
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(1))
            .getSingleOrNull();
    return zeile == null ? null : _ausZeile(zeile);
  }

  /// Eine Vorlage an ihrem Schlüssel — `null`, wenn es sie nicht gibt.
  ///
  /// **Kein leerer Datensatz als Ersatz:** „gibt es nicht" und „hat keine
  /// Werte" sind zwei verschiedene Auskünfte, und ein erfundener leerer
  /// Datensatz machte sie ununterscheidbar.
  Future<LebensmittelVorlage?> lies(int id) async {
    final zeile = await (_db.select(
      _db.lebensmittel,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return zeile == null ? null : _ausZeile(zeile);
  }

  /// Welche der Vorlagen [ids] flüssig sind — der Rückfall der Anzeige für
  /// Einträge ohne Schnappschuss `fluessig` (#403).
  ///
  /// **Eine Abfrage, egal wie viele Schlüssel** (Hausregel 2): Je Zeile
  /// eine Abfrage wäre die Liste, die je Zeile rechnet. Ein Schlüssel ohne
  /// Vorlage fehlt im Ergebnis, wie ein fester. Eine leere Menge fragt die
  /// Datenbank gar nicht erst.
  Future<Set<int>> fluessigeUnter(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final t = _db.lebensmittel;
    final zeilen =
        await (_db.selectOnly(t)
              ..addColumns([t.id])
              ..where(t.id.isIn(ids) & t.fluessig.equals(true)))
            .get();
    return {for (final z in zeilen) z.read(t.id)!};
  }

  /// Die Treffer zu [text] — und ohne Eingabe **nur Gebuchtes**, als
  /// „zuletzt benutzt": höchstens [_zuletztGrenze], das Jüngste oben
  /// (#345). [grenze] gilt nur mit Suchtext.
  ///
  /// **Eine Methode, nicht zwei.** Der Entwurf verlangt Treffer zum
  /// Suchtext und, ohne Eingabe, „zuletzt benutzt" statt einer leeren
  /// Seite (`erfassen.js`, `SUCHE`). Beide sortieren das zuletzt Benutzte
  /// gleich; zwei Methoden wären zwei Sortierregeln, die auseinanderlaufen
  /// können.
  ///
  /// Die Reihenfolge mit Suchtext: **zuletzt benutzt zuerst** (das Jüngste oben),
  /// **nie benutzte danach, alphabetisch**. Was man schon einmal gegessen
  /// hat, isst man wieder; was nie dran war, hat keine Rangfolge außer dem
  /// Namen.
  ///
  /// **`WHERE` steht vor `LIMIT`, und zwar in SQL.** Wer erst `grenze`
  /// Zeilen holt und danach in Dart filtert, verliert jeden Treffer, der
  /// in der Reihenfolge hinter der Grenze steht.
  ///
  /// **Grenze:** SQLites `LIKE` vergleicht ASCII-Buchstaben ohne Rücksicht
  /// auf die Schreibweise, Umlaute aber nicht — „müsli" findet „Müsli"
  /// nicht. Das ist hier bewusst nicht behauptet; wer es will, braucht
  /// `unicode61` oder eine Normalspalte, und das ist ein eigenes Ticket.
  Future<List<LebensmittelVorlage>> suche(String text, {int grenze = 25}) {
    final gesucht = text.trim();
    final abfrage = _db.select(_db.lebensmittel);

    if (gesucht.isEmpty) {
      // **Ohne Suchtext nur Gebuchtes, höchstens [_zuletztGrenze]** (Tim,
      // 04.11.2026, #345). Nie Gebuchtes unter „Zuletzt benutzt" hieß die
      // Überschrift lügen, und die Liste wuchs mit jedem übernommenen
      // Produkt. Gefunden wird es weiter, sobald man danach sucht.
      abfrage
        ..where((t) => t.zuletztBenutzt.isNotNull())
        ..orderBy([
          (t) => OrderingTerm(
            expression: t.zuletztBenutzt,
            mode: OrderingMode.desc,
          ),
        ])
        ..limit(_zuletztGrenze);
      return abfrage.map(_ausZeile).get();
    }

    // `%` und `_` sind in `LIKE` Platzhalter. Ohne Maskierung fände ein
    // getipptes `%` jedes Lebensmittel — und das sähe aus wie ein
    // Treffer, wo keiner ist.
    abfrage.where(
      (t) => t.name.like('%${_maskiert(gesucht)}%', escapeChar: _fluchtzeichen),
    );

    abfrage
      ..orderBy([
        // `IS NULL` ergibt 0 oder 1: Benutztes steht vor nie Benutztem.
        // Danach das Jüngste zuerst; innerhalb der nie Benutzten sind
        // alle gleich, und der Name entscheidet.
        (t) => OrderingTerm(expression: t.zuletztBenutzt.isNull()),
        (t) =>
            OrderingTerm(expression: t.zuletztBenutzt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.name.collate(Collate.noCase)),
      ])
      ..limit(grenze);

    return abfrage.map(_ausZeile).get();
  }

  /// Schreibt eine **bestehende** Vorlage neu — und zwar ganz.
  ///
  /// Was vorher dastand und jetzt fehlt, ist danach weg: Ändern ersetzt
  /// die Vorlage, es ergänzt sie nicht. [LebensmittelVorlage.zuletztBenutzt]
  /// bleibt dagegen unberührt — **Ändern ist kein Benutzen.** Ebenso
  /// [LebensmittelVorlage.portionenAbgefragtAm]: Die Marke sagt, dass Open
  /// Food Facts geantwortet hat, und das ändert kein Bearbeiten. Schriebe
  /// diese Methode sie mit, setzte eine Vorlage ohne Marke sie zurück, und
  /// die nächste Nachfrage legte die Portionen ein zweites Mal an.
  ///
  /// [LebensmittelVorlage.quelleSchluessel] geht dagegen mit, wie
  /// [LebensmittelVorlage.barcode] und [LebensmittelVorlage.herkunft]: Das
  /// Bearbeiten-Blatt liest die Zeile, bevor es sie schreibt, und trägt
  /// den Schlüssel deshalb unverändert zurück. Eine von Hand gebaute
  /// Vorlage ohne ihn löscht ihn — „Ändern ersetzt die Vorlage" gilt auch
  /// hier.
  ///
  /// Wirft bei fehlendem Schlüssel: Eine Vorlage ohne Schlüssel ist nicht
  /// angelegt, und sie zu „ändern" wäre ein Programmierfehler, keine
  /// Datenlage.
  Future<void> aendere(LebensmittelVorlage vorlage) async {
    final id = vorlage.id;
    if (id == null) {
      throw ArgumentError.notNull('vorlage.id');
    }

    await (_db.update(_db.lebensmittel)..where((t) => t.id.equals(id))).write(
      LebensmittelCompanion(
        name: Value(vorlage.name),
        kcal: Value(vorlage.je100g.kcal),
        eiweissG: Value(vorlage.je100g.eiweissG),
        kohlenhydrateG: Value(vorlage.je100g.kohlenhydrateG),
        fettG: Value(vorlage.je100g.fettG),
        zuckerG: Value(vorlage.je100g.zuckerG),
        ballaststoffeG: Value(vorlage.je100g.ballaststoffeG),
        gesaettigtG: Value(vorlage.je100g.gesaettigtG),
        wasserMl: Value(vorlage.je100g.wasserMl),
        extra: Value(jsonEncode(vorlage.je100g.extra)),
        fluessig: Value(vorlage.fluessig),
        barcode: Value(vorlage.barcode),
        herkunft: Value(vorlage.herkunft.name),
        quelleSchluessel: Value(vorlage.quelleSchluessel),
      ),
    );
  }

  /// Hält fest, dass die Vorlage gerade gebucht wurde — damit sie beim
  /// nächsten Mal obenan steht.
  ///
  /// **Nur diese eine Zeile.** Ein Update ohne `WHERE id = ?` hübe jedes
  /// Lebensmittel gleichzeitig nach oben. Ein unbekannter Schlüssel ändert
  /// nichts und wirft nicht: Das ist der Schnelleintrag ohne Vorlage und
  /// kein Fehler.
  Future<void> merkeBenutzung(int id, DateTime zeitpunkt) async {
    await (_db.update(_db.lebensmittel)..where((t) => t.id.equals(id))).write(
      LebensmittelCompanion(zuletztBenutzt: Value(zeitpunkt)),
    );
  }

  LebensmittelVorlage _ausZeile(LebensmittelRow zeile) => LebensmittelVorlage(
    id: zeile.id,
    name: zeile.name,
    je100g: Naehrwerte.je100g(
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
    fluessig: zeile.fluessig,
    zuletztBenutzt: zeile.zuletztBenutzt,
    barcode: zeile.barcode,
    herkunft: _herkunftAusText(zeile.herkunft),
    quelleSchluessel: zeile.quelleSchluessel,
    portionenAbgefragtAm: zeile.portionenAbgefragtAm,
  );
}

/// Die Spalte `herkunft` als [Herkunft].
///
/// **Ein unbekannter Wert wirft**, statt still `eigen` zu werden: Er kann
/// nur aus einem Zweig stammen, der eine dritte Herkunft kennt, und eine
/// stille Umdeutung behauptete eine Herkunft, die niemand kennt.
Herkunft _herkunftAusText(String text) => Herkunft.values.byName(text);

/// Das Fluchtzeichen für `LIKE`. Ein Gegenschrägstrich ist in SQL kein
/// Sonderzeichen; er wird über `ESCAPE` zu einem, und zwar nur für diese
/// eine Abfrage.
const _fluchtzeichen = '\\';

/// Wie viele Zeilen „Zuletzt benutzt" ohne Suchtext zeigt (Tim,
/// 04.11.2026, #345).
const _zuletztGrenze = 10;

/// Macht aus dem Suchtext ein `LIKE`-Muster, in dem `%` und `_` Zeichen
/// sind und keine Platzhalter.
///
/// Das Fluchtzeichen zuerst — sonst maskierte der zweite Durchgang die
/// Gegenschrägstriche, die der erste gerade gesetzt hat.
String _maskiert(String text) => text
    .replaceAll(_fluchtzeichen, '$_fluchtzeichen$_fluchtzeichen')
    .replaceAll('%', '$_fluchtzeichen%')
    .replaceAll('_', '${_fluchtzeichen}_');

/// Die JSON-Spalte als Map — wortgleich zu `ernaehrung_repository.dart`.
///
/// **Ein Schlüssel mit Wert `null` bleibt erhalten:** „bekannt als
/// unbekannt" ist eine andere Auskunft als „nie gefragt".
Map<String, double?> _extraAusText(String text) {
  final roh = jsonDecode(text) as Map<String, dynamic>;
  return {
    for (final eintrag in roh.entries)
      eintrag.key: (eintrag.value as num?)?.toDouble(),
  };
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie
/// `ernaehrungRepositoryProvider`.
final lebensmittelRepositoryProvider = Provider<LebensmittelRepository>(
  (ref) => LebensmittelRepository(ref.watch(appCacheProvider)),
);
