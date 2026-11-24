// Die **Seed-Datenbank** (#543, entschieden in #542): die mitgelieferte,
// schreibgeschützte SQLite-Datei `assets/ernaehrung_seed.sqlite` — BLS 4.0
// (7.140 deutsche Generika) plus die 20.000 populärsten deutschen
// Open-Food-Facts-Produkte, mit fertig gebautem FTS5-Index. Sie ist
// **Stufe 2** der Suche: eigene Lebensmittel, dann das Seed, dann die
// Online-Namenssuche (`docs/superpowers/specs/2026-11-03-ernaehrung-design.md`,
// „Die Suche läuft lokal zuerst").
//
// API und Vertrag sind durch `app/test/ernaehrung/seed_datenbank_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf den
// Test ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// ## Warum `package:sqlite3` und nicht drift
//
// Die Seed-Datei ist **nicht** der App-Cache. Sie wird nie geschrieben, nie
// migriert und bringt ihren Index schon mit; der drift-Cache hat bewusst
// keine Indizes und keinen FTS. Eine zweite, nur lesende Verbindung über
// `package:sqlite3` ist deshalb der ganze Zugriff — synchron, ohne Generat,
// ohne Migrationspfad. `sqlite3_flutter_libs` (über `drift_flutter` schon
// dabei) liefert auf dem Gerät die Bibliothek samt FTS5, unter
// `flutter test` kommt sie vom System.
//
// ## Warum die Datei kopiert wird
//
// Ein Flutter-Asset liegt im Bündel, nicht im Dateisystem — SQLite kann es
// nicht öffnen. Beim Start wird es deshalb einmal nach
// `getApplicationSupportDirectory()` geschrieben ([ladeSeedDatenbank]) und
// von dort schreibgeschützt geöffnet. **Nicht nach `Documents`** (bei
// aktiviertem File Sharing nutzersichtbar) und **nicht nach `Caches`** (iOS
// räumt das unter Speicherdruck ab) — dieselbe Hausregel wie für den
// drift-Cache.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';

/// Ein Treffer aus der Seed-Datenbank — **gefunden, nicht übernommen**.
///
/// Erst beim Buchen wandert er über [LebensmittelRepository.uebernimm] in
/// die eigene Tabelle ([alsVorlage]); bis dahin steht er nur in der
/// Trefferliste.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Die Trefferliste
/// ist Abhängigkeit eines Providers; ohne Wertgleichheit wäre jede neu
/// gelesene Liste ungleich der vorigen und jeder abgeleitete Wert liefe
/// neu — Fehler `03` (`CLAUDE.md`).
@immutable
class SeedTreffer {
  const SeedTreffer({
    required this.quelle,
    required this.schluessel,
    required this.name,
    this.marke,
    required this.je100g,
    required this.fluessig,
  });

  /// Woher die Zeile stammt: `'bls'` (Bundeslebensmittelschlüssel) oder
  /// `'off'` (Open Food Facts) — der Text aus der Spalte `quelle`, nicht
  /// umgedeutet.
  final String quelle;

  /// Der Schlüssel **in der Quelle**: der BLS-Code bzw. die EAN. Bei `off`
  /// ist das der Strichcode, bei `bls` ausdrücklich keiner — ein BLS-Code
  /// lässt sich nicht scannen, und im Strichcodefeld träfe er bei jedem
  /// Scan daneben (`Lebensmittel.quelleSchluessel`).
  final String schluessel;

  /// Der Name, so wie ihn die Quelle führt.
  final String name;

  /// Die Marke — `null` bei BLS-Generika und bei OFF-Produkten ohne
  /// Markenangabe. Sie gehört zur Anzeige, nicht zur Vorlage: Die eigene
  /// Tabelle hat keine Markenspalte.
  final String? marke;

  /// Die Nährwerte **je 100 g**. Ein fehlender Wert ist `null`, nie `0` —
  /// die OFF-Zeilen tragen etwa bei `wasser_ml` durchweg NULL, und eine
  /// Null behauptete „enthält kein Wasser" (Fehler `01`).
  final Naehrwerte je100g;

  /// Ob in Millilitern gerechnet wird statt in Gramm.
  final bool fluessig;

  /// Die Vorlage, die beim Buchen in die eigene Tabelle wandert: ohne
  /// Schlüssel (den vergibt die Datenbank), ohne `zuletztBenutzt` —
  /// gefunden ist nicht benutzt.
  ///
  /// **Der Schlüssel der Quelle wandert in `quelle_schluessel`**, und zwar
  /// bei beiden Quellen. Bei `off` steht er **zusätzlich** als
  /// [LebensmittelVorlage.barcode], denn eine EAN ist ein Strichcode und
  /// wird gescannt; ein BLS-Code ist keiner und bleibt deshalb aus dem
  /// Feld heraus (Spec, „Die Seed-Datenbank"). Wiedererkannt wird ein
  /// BLS-Eintrag über `quelle_schluessel`
  /// ([LebensmittelRepository.uebernimm]).
  ///
  /// [marke] geht nicht mit: Die Tabelle `lebensmittel` hat keine Spalte
  /// dafür.
  LebensmittelVorlage alsVorlage() => LebensmittelVorlage(
    name: name,
    je100g: je100g,
    fluessig: fluessig,
    barcode: _herkunft == Herkunft.off ? schluessel : null,
    herkunft: _herkunft,
    quelleSchluessel: schluessel,
  );

  /// Die Quelle als [Herkunft].
  ///
  /// **Ein unbekannter Wert wirft**, statt still `eigen` zu werden — wie
  /// in `lebensmittel_repository.dart`: Eine dritte Quelle kann nur aus
  /// einer Seed-Datei stammen, die diese App nicht kennt, und eine stille
  /// Umdeutung schriebe eine erfundene Herkunft in die eigene Tabelle.
  Herkunft get _herkunft => switch (quelle) {
    'bls' => Herkunft.bls,
    'off' => Herkunft.off,
    _ => throw StateError('unbekannte Quelle in der Seed-Datei: $quelle'),
  };

  @override
  bool operator ==(Object other) =>
      other is SeedTreffer &&
      other.quelle == quelle &&
      other.schluessel == schluessel &&
      other.name == name &&
      other.marke == marke &&
      other.je100g == je100g &&
      other.fluessig == fluessig;

  @override
  int get hashCode =>
      Object.hash(quelle, schluessel, name, marke, je100g, fluessig);

  @override
  String toString() =>
      'SeedTreffer(quelle: $quelle, schluessel: $schluessel, name: $name, '
      'marke: $marke, je100g: $je100g, fluessig: $fluessig)';
}

/// Die schreibgeschützte Verbindung zur Seed-Datei — **synchron**, wie
/// jede SQLite-Abfrage über `package:sqlite3`.
///
/// Geöffnet wird genau einmal beim Start ([ladeSeedDatenbank]), danach ist
/// Suchen ein reiner Lesevorgang. Es gibt keinen Zustand „lädt noch": Zum
/// Zeitpunkt, an dem ein Schirm [suche] ruft, steht die Datei schon offen —
/// dieselbe Überlegung wie bei `uebungsbilderProvider`.
class SeedDatenbank {
  SeedDatenbank._(this._db);

  /// Öffnet die Seed-Datei unter [pfad] — **nur lesend**.
  ///
  /// `OpenMode.readOnly` ist keine Vorsichtsmaßnahme, sondern die Aussage
  /// der Datei: Sie wird nie geändert, ein neues Seed ersetzt sie beim
  /// App-Update als Ganzes. Mit Schreibrecht legte SQLite bei der ersten
  /// Abfrage ein Journal daneben, und ein Fehler im Code könnte die
  /// mitgelieferten Zeilen verändern.
  ///
  /// Wirft, wenn es die Datei nicht gibt oder sie keine SQLite-Datei ist —
  /// das fängt [ladeSeedDatenbank] ab.
  factory SeedDatenbank.oeffnen(String pfad) =>
      SeedDatenbank._(sqlite3.open(pfad, mode: OpenMode.readOnly));

  /// Eine Seed-Datenbank **ohne Zeilen** — der Rückfall, wenn die
  /// Asset-Datei nicht lesbar ist ([ladeSeedDatenbank]).
  ///
  /// Dieselbe Entscheidung wie bei `Uebungsbilder.leer`: Ein Start, der an
  /// der Seed-Datei scheitert, wäre schlimmer als eine Suchstufe, die
  /// ausfällt — die eigenen Lebensmittel (Stufe 1) und die Online-Suche
  /// (Stufe 3) stehen weiter. [suche] liefert hier immer die leere Liste,
  /// ohne die Datenbank überhaupt zu fragen; eine nachgebaute leere Datei
  /// wäre dasselbe Ergebnis mit mehr Teilen.
  SeedDatenbank.leer() : _db = null;

  /// `null` in der leeren Fassung ([SeedDatenbank.leer]).
  final Database? _db;

  /// Die Treffer zu [text] — höchstens [grenze], die besten zuerst.
  ///
  /// **Die Rangfolge ist die aus `scripts/ernaehrung-seed/messen.sh`**, und
  /// zwar wörtlich dieselbe; dort ist sie an den Prüffällen aus
  /// `pruef-suchen.txt` gemessen worden:
  ///
  /// ```text
  /// bm25(lebensmittel_fts)            Textnähe, kleiner ist besser
  ///   − 0,3 · boost                   Beliebtheit (OFF-Scans, vorgerechnet)
  ///   − 4,0 bei Ganzwort-Treffer      die Suche steht wörtlich im suchtext
  ///   − 1,5 bei quelle = 'bls'        Generika-Bonus
  ///   + 0,01 · Namenslänge            kürzer = grundlegender
  /// ```
  ///
  /// **Jedes Suchwort als Präfix**, erst UND-verknüpft; bleibt das ohne
  /// Treffer, folgt ein ODER-Rückfall. Eine Suche, die wegen eines
  /// Tippfehlers im zweiten Wort gar nichts zeigt, sähe aus wie eine leere
  /// Datenbank.
  ///
  /// **Unter zwei Zeichen wird nicht gesucht** — ein einzelner Buchstabe
  /// als Präfix trifft Tausende Zeilen, und beim Tippen des ersten
  /// Buchstabens hat niemand eine Trefferliste erwartet. Das ist die leere
  /// Liste, keine Ausnahme: „nichts gefunden" ist eine Datenlage.
  ///
  /// **Die Parameter sind gebunden, nicht eingesetzt.** `messen.sh` muss
  /// Apostrophe von Hand verdoppeln („Kellogg's"); hier erledigt das die
  /// Bindung, und ein getipptes `'` kann die Abfrage nicht zerlegen.
  List<SeedTreffer> suche(String text, {int grenze = 25}) {
    final db = _db;
    if (db == null) return const [];

    // Anführungszeichen raus, wie in `messen.sh`: Sie umschließen in FTS5
    // ein Suchwort und machten aus einem getippten `"` eine halbe
    // Zeichenkette.
    final gesucht = text.replaceAll('"', '').trim();
    if (gesucht.length < _mindestzeichen) return const [];

    final woerter = gesucht.split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (woerter.isEmpty) return const [];

    final und = woerter.map((w) => '"$w"*').join(' ');
    final treffer = _frage(db, und, gesucht, grenze);
    if (treffer.isNotEmpty || woerter.length == 1) return treffer;

    final oder = woerter.map((w) => '"$w"*').join(' OR ');
    return _frage(db, oder, gesucht, grenze);
  }

  /// Ein Lauf gegen den Index — [match] ist der FTS5-Ausdruck, [ganzwort]
  /// der Suchtext für den Ganzwort-Bonus.
  ///
  /// `lower()` in SQLite kennt nur ASCII; Umlaute bleiben also auf beiden
  /// Seiten des Vergleichs stehen und heben sich auf. `messen.sh` rechnet
  /// genauso — wer das ändert, ändert die gemessene Rangfolge.
  List<SeedTreffer> _frage(
    Database db,
    String match,
    String ganzwort,
    int grenze,
  ) {
    final zeilen = db.select(_abfrage, [
      match,
      // Fünfmal derselbe Suchtext: einmal je Stufe der Rangfolge. Benannte
      // Platzhalter wären lesbarer, aber `package:sqlite3` bindet
      // positionsweise.
      ganzwort, ganzwort, ganzwort, ganzwort, ganzwort,
      grenze,
    ]);
    return [for (final zeile in zeilen) _ausZeile(zeile)];
  }

  SeedTreffer _ausZeile(Row zeile) => SeedTreffer(
    quelle: zeile['quelle'] as String,
    schluessel: zeile['schluessel'] as String,
    name: zeile['name'] as String,
    marke: zeile['marke'] as String?,
    je100g: Naehrwerte.je100g(
      kcal: _zahl(zeile['kcal']),
      eiweissG: _zahl(zeile['eiweiss_g']),
      kohlenhydrateG: _zahl(zeile['kohlenhydrate_g']),
      fettG: _zahl(zeile['fett_g']),
      zuckerG: _zahl(zeile['zucker_g']),
      ballaststoffeG: _zahl(zeile['ballaststoffe_g']),
      gesaettigtG: _zahl(zeile['gesaettigt_g']),
      wasserMl: _zahl(zeile['wasser_ml']),
    ),
    fluessig: (zeile['fluessig'] as int) != 0,
  );

  /// Gibt die Verbindung frei. Danach ist [suche] nicht mehr benutzbar.
  ///
  /// In der leeren Fassung gibt es nichts freizugeben — der Aufruf ist
  /// trotzdem erlaubt, damit niemand vorher nachsehen muss, welche Fassung
  /// er in der Hand hält.
  void schliessen() => _db?.close();
}

/// Liest die Seed-Datei aus dem Bündel, legt sie neben den drift-Cache und
/// öffnet sie schreibgeschützt.
///
/// **Kopiert wird nur, wenn sich die Größe unterscheidet.** Ein neues Seed
/// ersetzt beim App-Update die Asset-Datei, und eine nach Zeilenzahl und
/// Index neu gebaute SQLite-Datei von rund fünf Megabyte trifft die alte
/// Größe praktisch nie auf das Byte genau. Eine mitgeführte
/// Fassungsnummer wäre genauer, hinge aber daran, dass jemand sie beim
/// Einspielen hochzählt — und wer das vergisst, bekommt stillschweigend
/// das alte Seed. Die Größe fragt niemanden um Erlaubnis. *(Die Grenze
/// steht hier, damit sie beim nächsten Seed jemand liest: Zwei Seeds mit
/// identischer Byte-Zahl gelten als dasselbe.)*
///
/// **Ist das Asset nicht lesbar oder keine SQLite-Datei, startet die App
/// trotzdem** — mit [SeedDatenbank.leer]. Der Fehler wird gemeldet, nicht
/// verschluckt; das ist die eine Stelle, die ihn fängt, genau wie
/// `ladeUebungsbilder`.
Future<SeedDatenbank> ladeSeedDatenbank(AssetBundle bundle) async {
  try {
    final verzeichnis = await getApplicationSupportDirectory();
    final ziel = File('${verzeichnis.path}/$seedDateiname');

    final gebuendelt = await bundle.load('assets/$seedDateiname');
    final bytes = gebuendelt.buffer.asUint8List(
      gebuendelt.offsetInBytes,
      gebuendelt.lengthInBytes,
    );

    final vorhanden = await ziel.exists() ? await ziel.length() : -1;
    if (vorhanden != bytes.length) {
      await ziel.parent.create(recursive: true);
      await ziel.writeAsBytes(bytes, flush: true);
    }

    return SeedDatenbank.oeffnen(ziel.path);
  } catch (fehler, stapel) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: fehler,
        stack: stapel,
        library: 'seed_datenbank',
        context: ErrorDescription(
          'beim Öffnen der Lebensmittel-Seed-Datenbank — die Suche läuft '
          'ohne sie, mit eigenen Lebensmitteln und Open Food Facts',
        ),
      ),
    );
    return SeedDatenbank.leer();
  }
}

/// Die Seed-Datenbank im Riverpod-Baum.
///
/// **Ohne Override die leere Fassung**, nicht ein Wurf — anders als
/// `uebungsbilderProvider` und `appCacheProvider`. Der Grund ist, wer ihn
/// liest: Die Lebensmittelsuche hängt daran, und damit jeder Widget-Test,
/// der den Suchschirm pumpt, ohne vom Seed je gehört zu haben. Ein
/// werfender Provider nahm am 23.11.2026 genau diesen Weg und riss 36
/// Bestandstests mit, die mit der zweiten Suchstufe nichts zu tun haben;
/// jede künftige Stufe kostete dann eine Runde durch fremde Testdateien.
///
/// Ein Provider, der die Datei selbst öffnete, täte das im Test gegen ein
/// Verzeichnis, das es dort nicht gibt — deshalb lädt weiterhin nur
/// `main()` über [ladeSeedDatenbank] und setzt den Wert.
///
/// **Die Kehrseite, offen benannt:** Vergäße `main()` das Override, bliebe
/// die zweite Suchstufe still leer, statt laut zu scheitern. Das ist
/// hinnehmbar, weil es dieselbe Lage ist wie eine unlesbare Datei — und
/// die behandelt [ladeSeedDatenbank] schon heute so, mit
/// [SeedDatenbank.leer] und einer Meldung. Stufe 1 (eigene) und Stufe 3
/// (online) tragen die Suche in beiden Fällen weiter.
final seedDatenbankProvider = Provider<SeedDatenbank>(
  (ref) => SeedDatenbank.leer(),
);

/// Der Dateiname im Bündel **und** in `getApplicationSupportDirectory()` —
/// derselbe, damit man die Kopie im Container wiedererkennt.
const seedDateiname = 'ernaehrung_seed.sqlite';

/// Ab wie vielen Zeichen gesucht wird.
const _mindestzeichen = 2;

/// Die Abfrage — eine einzige, mit dem FTS5-Ausdruck, dem Suchtext für den
/// Ganzwort-Bonus und der Grenze als gebundene Parameter.
///
/// **Gefiltert, sortiert und begrenzt wird in SQL** (Hausregel 2). Wer
/// erst `grenze` Zeilen holte und danach in Dart sortierte, bekäme die
/// besten Treffer gar nicht erst zu sehen.
const _abfrage = '''
SELECT l.quelle, l.schluessel, l.name, l.marke,
       l.kcal, l.eiweiss_g, l.kohlenhydrate_g, l.fett_g,
       l.zucker_g, l.ballaststoffe_g, l.gesaettigt_g, l.wasser_ml,
       l.fluessig
FROM lebensmittel_fts f
JOIN lebensmittel l ON l.id = f.rowid
WHERE lebensmittel_fts MATCH ?
ORDER BY bm25(lebensmittel_fts)
         - 0.3 * l.boost
         - (CASE WHEN instr(coalesce(l.vorrang, ''),
                            ' ' || lower(?) || ' ') > 0 THEN 12.0 ELSE 0 END)
         - (CASE WHEN l.wortfolge_name = ' ' || lower(?) || ' '
                   OR l.grundform = ' ' || lower(?) || ' '
                 THEN 6.0 ELSE 0 END)
         - (CASE WHEN instr(l.wortfolge_name,
                            ' ' || lower(?) || ' ') > 0 THEN 4.0 ELSE 0 END)
         - (CASE WHEN instr(l.wortfolge,
                            ' ' || lower(?) || ' ') > 0 THEN 1.5 ELSE 0 END)
         - (CASE WHEN l.quelle = 'bls' THEN 1.5 ELSE 0 END)
         + (CASE WHEN l.kcal = 0 AND l.fluessig = 0 THEN 2.0 ELSE 0 END)
         + 0.45 * (length(l.wortfolge_name)
                   - length(replace(l.wortfolge_name, ' ', '')) - 1)
LIMIT ?;
''';

/// Eine Nährwertspalte als `double?`.
///
/// **NULL bleibt `null`.** Die Seed-Datei führt `wasser_ml` nur aus dem
/// BLS; jede OFF-Zeile hat dort NULL. Ein Codec, der das auf `0` abbildete,
/// baute Fehler `01` unterhalb der Suche neu ein, wo kein sealed-Typ ihn
/// mehr sehen kann. Ein ganzzahlig gespeicherter Wert kommt als `int`
/// heraus; ein anderer Typ wäre ein Fehler in der Seed-Datei und wirft.
double? _zahl(Object? wert) => switch (wert) {
  null => null,
  final num zahl => zahl.toDouble(),
  _ => throw StateError('keine Zahl in der Seed-Datei: $wert'),
};
