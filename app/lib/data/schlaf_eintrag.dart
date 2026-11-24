// Von Hand eingetragene Schlafphasen (#131) — Nacht und Tagschlaf. Ablage,
// Prüfung und der Weg, sie zu setzen; die Formulare dazu liegen in
// `lib/shell/schlaf_eintragen.dart`.
//
// API und Vertrag sind durch `app/test/data/schlaf_eintrag_test.dart` und
// `schlaf_eintrag_provider_test.dart` verbindlich vorgegeben (siehe deren
// Dateiköpfe) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Die App schreibt nichts nach Apple Health.** `CLAUDE.md` legt fest,
// dass sie auf dem Gerät reine Lesequelle bleibt
// (`requestAuthorization(toShare: [], …)`), und der Entwurf sagt dem Nutzer
// genau das. Ein eingetragener Eintrag liegt deshalb hier — dauerhaft, nicht
// im nachladbaren Cache.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Hinter diesen Zeilen steht kein Lauf, der leer ausgehen könnte, sondern
// Tim. Leer heißt leer: kein `LeerNachLauf`, kein Stand, kein `laeuft`.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Nacht oder Nickerchen — die beiden Arten, die der Entwurf kennt
/// (`docs/screens/screens/schlaf.js` und `tagschlaf.js`).
enum SchlafEintragArt { nacht, tagschlaf }

/// Eine von Hand eingetragene Schlafphase.
///
/// Die beiden Uhrzeiten stehen als **Minuten nach Mitternacht** (0..1439),
/// nicht als Zeitpunkt: „23:10" ist eine Tageszeit, kein Ereignis. Sie
/// stehen entweder beide da (Formularfassung „Zeiten") oder keine von
/// beiden („nur Dauer") — dazwischen gibt es nichts.
@immutable
class SchlafEintrag {
  const SchlafEintrag({
    required this.tag,
    required this.art,
    required this.lfdNr,
    required this.schlafMinuten,
    this.beginnMinuten,
    this.endeMinuten,
    this.notiz,
  });

  /// ISO-Tagesschlüssel (`JJJJ-MM-TT`) — bei der Nacht der Aufwachtag.
  final String tag;

  final SchlafEintragArt art;

  /// 0 bei der Nacht; beim Tagschlaf die laufende Nummer, die die Ablage
  /// vergibt.
  final int lfdNr;

  /// Die geschlafene Zeit in ganzen Minuten. Steht auch dann in der Zeile,
  /// wenn Zeiten vorliegen: Der Entwurf lässt die gerechnete Dauer
  /// überschreiben, „falls du wach dazwischen lagst".
  final int schlafMinuten;

  final int? beginnMinuten;
  final int? endeMinuten;
  final String? notiz;

  /// Ob dieser Eintrag ein Fenster auf der Uhr hat — und damit eine
  /// Einschlafzeit, aus der die Teilnote Zubettgehzeit entsteht.
  bool get hatZeiten => beginnMinuten != null && endeMinuten != null;

  // Wertgleichheit aus demselben Grund wie bei `Ziele`: Ein Werttyp, der
  // Abhängigkeit eines Providers ist, braucht `==` und `hashCode`, sonst
  // rechnet jeder abgeleitete Wert nach jedem Lesevorgang neu (Fehler `03`).
  @override
  bool operator ==(Object other) =>
      other is SchlafEintrag &&
      other.tag == tag &&
      other.art == art &&
      other.lfdNr == lfdNr &&
      other.schlafMinuten == schlafMinuten &&
      other.beginnMinuten == beginnMinuten &&
      other.endeMinuten == endeMinuten &&
      other.notiz == notiz;

  @override
  int get hashCode => Object.hash(
    tag,
    art,
    lfdNr,
    schlafMinuten,
    beginnMinuten,
    endeMinuten,
    notiz,
  );

  @override
  String toString() =>
      'SchlafEintrag(tag: $tag, art: $art, lfdNr: $lfdNr, '
      'schlafMinuten: $schlafMinuten, beginnMinuten: $beginnMinuten, '
      'endeMinuten: $endeMinuten, notiz: $notiz)';
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und [SchlafEintrag] — derselbe
/// Schnitt wie bei `CacheRepository` und `ZieleRepository`: SQL hier,
/// Riverpod nebenan.
class SchlafEintragRepository {
  SchlafEintragRepository(this._db);

  final AppCache _db;

  /// Die laufende Nummer der einen Nacht je Aufwachtag. Eine zweite wäre
  /// eine zweite Antwort auf dieselbe Frage.
  static const _nachtLfdNr = 0;

  /// Der Tagesschlüssel, so wie `BerlinCalendar.dayKey(...)` ihn schreibt.
  /// Ein Zeitstempel oder ein deutsches Datum verglichen sich unter
  /// `WHERE tag >= ?` falsch — lautlos, denn SQLite vergleicht jede
  /// Zeichenkette klaglos.
  static final _tagesSchluessel = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Alle Einträge, deren Tag im `fenster` liegt, aufsteigend nach Tag, Art
  /// und laufender Nummer.
  ///
  /// Gefiltert wird in SQL (`WHERE tag >= ?`), nicht nach dem Laden in Dart
  /// — Hausregel 2 (`CLAUDE.md`, Spec 5.6).
  ///
  /// **Kein `null`-Fall wie bei `liesNaechte`.** Der Cache trennt „kein
  /// Cache" von „leer gelaufen", weil hinter ihm ein Lauf steht, der leer
  /// ausgehen kann. Hinter dieser Tabelle steht Tim; leer heißt leer.
  Future<List<SchlafEintrag>> lies(DataWindow fenster) async {
    final abfrage = _db.select(_db.schlafEintraege)
      ..orderBy([
        (t) => OrderingTerm.asc(t.tag),
        (t) => OrderingTerm.asc(t.art),
        (t) => OrderingTerm.asc(t.lfdNr),
      ]);
    final start = fenster.start;
    if (start != null) {
      abfrage.where(
        (t) => t.tag.isBiggerOrEqualValue(BerlinCalendar.dayKey(start)),
      );
    }

    return (await abfrage.get()).map(_alsEintrag).toList();
  }

  /// Trägt die Nacht dieses Aufwachtags ein; ein zweiter Eintrag für
  /// denselben Tag **ersetzt** den ersten.
  Future<void> schreibeNacht({
    required String tag,
    required int schlafMinuten,
    int? beginnMinuten,
    int? endeMinuten,
    String? notiz,
  }) async {
    _pruefe(
      tag: tag,
      schlafMinuten: schlafMinuten,
      beginnMinuten: beginnMinuten,
      endeMinuten: endeMinuten,
    );

    await _db
        .into(_db.schlafEintraege)
        .insertOnConflictUpdate(
          SchlafEintraegeCompanion.insert(
            tag: tag,
            art: SchlafEintragArt.nacht.name,
            lfdNr: _nachtLfdNr,
            schlafMinuten: schlafMinuten,
            beginnMinuten: Value(beginnMinuten),
            endeMinuten: Value(endeMinuten),
            notiz: Value(_gesaeuberteNotiz(notiz)),
          ),
        );
  }

  /// Hängt ein Nickerchen an diesen Tag an. Die laufende Nummer vergibt die
  /// Ablage — ein Aufrufer, der sie raten müsste, riete irgendwann falsch.
  ///
  /// **Eine Lücke wird nicht wieder aufgefüllt** (`max + 1`, nicht
  /// `anzahl`): Nach dem Löschen der ersten von zwei Phasen trüge die
  /// nächste sonst die Nummer der verbliebenen, und `insertOnConflictUpdate`
  /// überschriebe sie.
  Future<void> fuegeTagschlafHinzu({
    required String tag,
    required int schlafMinuten,
    int? beginnMinuten,
    int? endeMinuten,
    String? notiz,
  }) async {
    _pruefe(
      tag: tag,
      schlafMinuten: schlafMinuten,
      beginnMinuten: beginnMinuten,
      endeMinuten: endeMinuten,
    );

    // In einer Transaktion, damit zwischen „höchste Nummer lesen" und
    // „schreiben" nichts dazwischenkommt.
    await _db.transaction(() async {
      final vorhanden =
          await (_db.select(_db.schlafEintraege)..where(
                (t) =>
                    t.tag.equals(tag) &
                    t.art.equals(SchlafEintragArt.tagschlaf.name),
              ))
              .get();
      final naechste = vorhanden.isEmpty
          ? 0
          : vorhanden.map((z) => z.lfdNr).reduce((a, b) => a > b ? a : b) + 1;

      await _db
          .into(_db.schlafEintraege)
          .insert(
            SchlafEintraegeCompanion.insert(
              tag: tag,
              art: SchlafEintragArt.tagschlaf.name,
              lfdNr: naechste,
              schlafMinuten: schlafMinuten,
              beginnMinuten: Value(beginnMinuten),
              endeMinuten: Value(endeMinuten),
              notiz: Value(_gesaeuberteNotiz(notiz)),
            ),
          );
    });
  }

  /// Nimmt die eingetragene Nacht dieses Tages zurück. Nickerchen desselben
  /// Tages bleiben stehen — sie beantworten eine andere Frage.
  Future<void> loescheNacht(String tag) async {
    await (_db.delete(_db.schlafEintraege)..where(
          (t) => t.tag.equals(tag) & t.art.equals(SchlafEintragArt.nacht.name),
        ))
        .go();
  }

  Future<void> loescheTagschlaf({
    required String tag,
    required int lfdNr,
  }) async {
    await (_db.delete(_db.schlafEintraege)..where(
          (t) =>
              t.tag.equals(tag) &
              t.art.equals(SchlafEintragArt.tagschlaf.name) &
              t.lfdNr.equals(lfdNr),
        ))
        .go();
  }

  /// Geprüft wird **vor** dem Schreiben, damit ein abgewiesener Wert keine
  /// halbe Zeile hinterlässt.
  ///
  /// **Die Dauer wird ausdrücklich nicht gegen die Zeiten geprüft.** Wer von
  /// 23:10 bis 06:15 im Bett lag und 6:30 h eintippt, hat recht und nicht
  /// die Rechnung; der Entwurf nennt den Fall beim Namen („falls du wach
  /// dazwischen lagst").
  void _pruefe({
    required String tag,
    required int schlafMinuten,
    required int? beginnMinuten,
    required int? endeMinuten,
  }) {
    if (!_tagesSchluessel.hasMatch(tag)) {
      throw ArgumentError.value(
        tag,
        'tag',
        'Ein Tag ist ein ISO-Tagesschlüssel der Form JJJJ-MM-TT',
      );
    }
    if (schlafMinuten < 1 || schlafMinuten > Duration.minutesPerDay) {
      throw ArgumentError.value(
        schlafMinuten,
        'schlafMinuten',
        'Geschlafen wird zwischen 1 Minute und 24 Stunden',
      );
    }
    if ((beginnMinuten == null) != (endeMinuten == null)) {
      throw ArgumentError.value(
        beginnMinuten ?? endeMinuten,
        beginnMinuten == null ? 'beginnMinuten' : 'endeMinuten',
        'Entweder beide Uhrzeiten oder keine — eine halbe Angabe ergibt '
        'kein Fenster',
      );
    }
    for (final (name, wert) in [
      ('beginnMinuten', beginnMinuten),
      ('endeMinuten', endeMinuten),
    ]) {
      if (wert == null) continue;
      if (wert < 0 || wert >= Duration.minutesPerDay) {
        throw ArgumentError.value(
          wert,
          name,
          'Eine Uhrzeit liegt zwischen 0 und 1439 Minuten nach Mitternacht',
        );
      }
    }
  }

  /// Leer heißt leer: Eine Notiz aus Leerzeichen wird `null`, sonst gäbe es
  /// zwei Schreibweisen für „keine Notiz".
  String? _gesaeuberteNotiz(String? notiz) {
    final beschnitten = notiz?.trim();
    if (beschnitten == null || beschnitten.isEmpty) return null;
    return beschnitten;
  }

  /// Eine unbekannte Art wirft, statt still zur Nacht zu werden — ein
  /// falscher Wert in der Spalte wäre ein Programmierfehler, keine
  /// Datenlage (`CLAUDE.md`, zum Kanal-Codec).
  SchlafEintrag _alsEintrag(SchlafEintragRow zeile) => SchlafEintrag(
    tag: zeile.tag,
    art: SchlafEintragArt.values.byName(zeile.art),
    lfdNr: zeile.lfdNr,
    schlafMinuten: zeile.schlafMinuten,
    beginnMinuten: zeile.beginnMinuten,
    endeMinuten: zeile.endeMinuten,
    notiz: zeile.notiz,
  );
}

final schlafEintragRepositoryProvider = Provider<SchlafEintragRepository>(
  (ref) => SchlafEintragRepository(ref.watch(appCacheProvider)),
);

/// Die eigenen Schlafeinträge über das Rechenfenster — **ein** Provider für
/// Nacht und Tagschlaf.
///
/// Beide Schirme brauchen dieselbe Lesung über dasselbe Fenster; zwei
/// Provider wären zwei Abfragen auf eine Tabelle. Welche Zeilen ein Schirm
/// zeigt, entscheidet er über [SchlafEintrag.art].
///
/// Das Fenster ist `rechenfensterProvider`, dasselbe wie bei `sleepProvider`
/// — eine eingetragene Nacht außerhalb davon wäre eine Zeile, die es gibt
/// und die niemand sieht.
final schlafEintraegeProvider =
    AsyncNotifierProvider<SchlafEintraegeNotifier, List<SchlafEintrag>>(
      SchlafEintraegeNotifier.new,
    );

class SchlafEintraegeNotifier extends AsyncNotifier<List<SchlafEintrag>> {
  @override
  Future<List<SchlafEintrag>> build() {
    final repo = ref.watch(schlafEintragRepositoryProvider);
    return repo.lies(ref.watch(rechenfensterProvider));
  }

  /// Schreibt durch bis in die Datenbank und liest danach neu — sonst wäre
  /// es wieder ein `@State`, das beim Verlassen des Schirms vergisst.
  ///
  /// `await future` zuerst, aus demselben Grund wie bei `ZieleNotifier.setze`:
  /// Ohne das könnte ein Schreibvorgang direkt nach dem ersten `read` mit dem
  /// noch laufenden `build()` um die Reihenfolge rennen.
  ///
  /// **Neu gelesen statt von Hand nachgetragen:** Die laufende Nummer eines
  /// Nickerchens vergibt die Ablage, und das Fenster filtert. Beides im
  /// Zustand nachzubilden wäre eine zweite Wahrheit über dieselbe Tabelle.
  Future<void> setzeNacht({
    required String tag,
    required int schlafMinuten,
    int? beginnMinuten,
    int? endeMinuten,
    String? notiz,
  }) => _schreibe(
    (repo) => repo.schreibeNacht(
      tag: tag,
      schlafMinuten: schlafMinuten,
      beginnMinuten: beginnMinuten,
      endeMinuten: endeMinuten,
      notiz: notiz,
    ),
  );

  Future<void> fuegeTagschlafHinzu({
    required String tag,
    required int schlafMinuten,
    int? beginnMinuten,
    int? endeMinuten,
    String? notiz,
  }) => _schreibe(
    (repo) => repo.fuegeTagschlafHinzu(
      tag: tag,
      schlafMinuten: schlafMinuten,
      beginnMinuten: beginnMinuten,
      endeMinuten: endeMinuten,
      notiz: notiz,
    ),
  );

  Future<void> loescheNacht(String tag) =>
      _schreibe((repo) => repo.loescheNacht(tag));

  Future<void> loescheTagschlaf({required String tag, required int lfdNr}) =>
      _schreibe((repo) => repo.loescheTagschlaf(tag: tag, lfdNr: lfdNr));

  Future<void> _schreibe(
    Future<void> Function(SchlafEintragRepository repo) was,
  ) async {
    await future;
    final repo = ref.read(schlafEintragRepositoryProvider);
    // Ein abgewiesener Wert wirft hierher durch und lässt den Zustand
    // unangetastet — er hat ja auch nichts geändert.
    await was(repo);
    state = AsyncData(await repo.lies(ref.read(rechenfensterProvider)));
  }
}
