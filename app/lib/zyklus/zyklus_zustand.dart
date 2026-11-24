// Die Provider-Schicht des Zykluskalenders (Spec 5.1, #571 und #572 unter
// #539) — **gehalten, nicht je Bild gerechnet** (Hausregel 2): Das
// Monatsraster, die Vorhersage und der Tageseintrag entstehen hier einmal,
// wenn sich die Ablage ändert.
//
// Hier, nicht im Widget, wird `AsyncValue` gelesen: Die Widget-Schicht
// bekommt einen sealed-Typ und muss jeden Fall behandeln (Hausregel 1).
// **Kein `Messwert<T>`** (Spec 7) — Zyklusdaten sind eigene Daten, es gibt
// keinen Lauf aus Apple Health, der leer ausgehen könnte. Leer heißt leer;
// was fehlt, fehlt.
//
// **Gelesen wird über einen Strom auf die Tabelle, nicht einmalig.** Der
// Kalender und „Tag eintragen" liegen auf demselben Stapel: Wer einen Tag
// einträgt und zurückgeht, muss ihn im Raster sehen (`32`). Ein einmal
// gelesener `FutureProvider` bliebe stehen, und es gibt keine Stelle, die
// beim Zurückkommen verlässlich ungültig machen könnte — der Push läuft
// über `AppRouter`, der Weg zurück über Wischgeste, Zurück-Knopf oder
// `Navigator.pop`. `tableUpdates` fängt alle drei, auch das Schreiben an
// diesen Schirmen vorbei.
//
// Gefragt wird dabei **immer über `ZyklusRepository`**, nie mit eigenem
// SQL: Nur so trägt eine Attrappe in den Tests noch.
import 'package:drift/drift.dart'
    show ResultSetImplementation, TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/cache.dart';
import '../data/ereignisse.dart';
import '../data/zyklus_repository.dart';
import '../design/formatierung.dart';
import '../health/health_provider.dart';
import 'zyklus_raster.dart';

// ─────────────────────────────────────────────────────────────────────────
// Was aus der Ablage kommt
// ─────────────────────────────────────────────────────────────────────────

/// Die Ränder, mit denen nach **allen** Tageseinträgen gefragt wird.
///
/// `periodenAus` braucht den ganzen bekannten Verlauf, kein Monatsfenster:
/// Der erste Blutungstag der übergebenen Map startet immer eine Periode, und
/// wer monatsweise hereinreicht, bekommt am Fensterrand einen erfundenen
/// Periodenstart samt falschem Zyklustag (siehe Doc-Kommentar von
/// `periodenAus`).
const String _ersterTag = '0000-01-01';
const String _letzterTag = '9999-12-31';

/// Alle Tageseinträge, neu gelesen bei jeder Änderung der Tabelle.
final zyklusEintraegeProvider = StreamProvider<List<ZyklusEintrag>>((ref) {
  final ablage = ref.watch(zyklusRepositoryProvider);
  final cache = ref.watch(appCacheProvider);
  return _beiAenderung(
    cache,
    cache.zyklusEintraege,
    () => ablage.imZeitraum(von: _ersterTag, bis: _letzterTag),
  );
});

/// Die Einstellungen, neu gelesen bei jeder Änderung ihrer Tabelle.
final zyklusEinstellungenLaufProvider = StreamProvider<ZyklusEinstellungen>((
  ref,
) {
  final ablage = ref.watch(zyklusRepositoryProvider);
  final cache = ref.watch(appCacheProvider);
  return _beiAenderung(
    cache,
    cache.zyklusEinstellungen,
    ablage.liesEinstellungen,
  );
});

/// Liest einmal und danach nach jeder Änderung von [tabelle] erneut.
///
/// Der erste Wert kommt aus [lies] selbst — ein Strom, der erst auf die
/// erste Änderung wartete, zeigte auf einem Gerät, an dem gerade nichts
/// passiert, nie etwas an. Scheitert [lies], endet der Strom mit dem
/// Fehler: „nicht lesbar" ist eine andere Auskunft als „nichts da".
Stream<T> _beiAenderung<T>(
  AppCache cache,
  ResultSetImplementation<dynamic, dynamic> tabelle,
  Future<T> Function() lies,
) async* {
  yield await lies();
  await for (final _ in cache.tableUpdates(TableUpdateQuery.onTable(tabelle))) {
    yield await lies();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Der Zustand der Ablage
// ─────────────────────────────────────────────────────────────────────────

/// Was über die Tageseinträge bekannt ist.
sealed class ZyklusDaten {
  const ZyklusDaten();
}

/// Die Tabelle wird gelesen. **Kein Leerzustand** — „noch keine Vorhersage"
/// während des Lesens wäre Fehler `01`.
final class ZyklusDatenLaden extends ZyklusDaten {
  const ZyklusDatenLaden();

  @override
  bool operator ==(Object other) => other is ZyklusDatenLaden;

  @override
  int get hashCode => (ZyklusDatenLaden).hashCode;
}

/// Die Tabelle ließ sich nicht lesen. Auch das ist kein Leerzustand: Ob
/// etwas eingetragen ist, weiß die App dann nicht.
final class ZyklusDatenUnlesbar extends ZyklusDaten {
  const ZyklusDatenUnlesbar();

  @override
  bool operator ==(Object other) => other is ZyklusDatenUnlesbar;

  @override
  int get hashCode => (ZyklusDatenUnlesbar).hashCode;
}

/// Gelesen. [tage] ist leer, wenn nie etwas eingetragen wurde.
final class ZyklusDatenGelesen extends ZyklusDaten {
  const ZyklusDatenGelesen({
    required this.tage,
    required this.perioden,
    required this.positiverTest,
  });

  /// Jeder abgelegte Tageseintrag, nach seinem ISO-Tag.
  final Map<String, ZyklusEintrag> tage;

  /// Die Perioden aus dem **ganzen** Verlauf, aufsteigend nach `von`.
  final List<Periode> perioden;

  /// Der jüngste positive Schwangerschaftstest **nach** dem letzten
  /// Periodenstart, oder `null` (Spec 3.8). Ab ihm pausiert die Vorhersage.
  final String? positiverTest;

  /// Der letzte bekannte Periodenstart, oder `null`.
  String? get letzterStart => perioden.isEmpty ? null : perioden.last.von;

  @override
  bool operator ==(Object other) =>
      other is ZyklusDatenGelesen &&
      other.positiverTest == positiverTest &&
      listEquals(other.perioden, perioden) &&
      mapEquals(other.tage, tage);

  @override
  int get hashCode => Object.hash(
    positiverTest,
    Object.hashAll(perioden),
    Object.hashAll(tage.keys),
    Object.hashAll(tage.values),
  );
}

/// Die Tageseinträge samt Perioden — der eine Ort, an dem `AsyncValue`
/// gelesen wird.
final zyklusDatenProvider = Provider<ZyklusDaten>((ref) {
  final lauf = ref.watch(zyklusEintraegeProvider);
  if (lauf.hasValue) return _datenAus(lauf.value!);
  if (lauf.hasError) return const ZyklusDatenUnlesbar();
  return const ZyklusDatenLaden();
});

/// Die Nutzlast, oder `null` — über denselben `switch`, nicht über einen
/// `is`-Test daneben. Käme ein vierter Fall dazu, zeigt der Analyzer
/// hierher.
ZyklusDatenGelesen? zyklusWerte(ZyklusDaten zustand) => switch (zustand) {
  final ZyklusDatenGelesen gelesen => gelesen,
  ZyklusDatenLaden() || ZyklusDatenUnlesbar() => null,
};

ZyklusDatenGelesen _datenAus(List<ZyklusEintrag> eintraege) {
  // **Zwischenblutungstage gehen nicht in `periodenAus`** (Spec 2.1): Eine
  // Zwischenblutung ist ein eigenes Feld und kein Blutungstag — sie
  // verschiebt die Vorhersage nicht. Das auszusortieren ist Pflicht des
  // Aufrufers; der Kern sieht nur noch Stärken.
  final perioden = periodenAus({
    for (final eintrag in eintraege)
      eintrag.tag: eintrag.zwischenblutung ? null : eintrag.blutung,
  });
  final letzterStart = perioden.isEmpty ? null : perioden.last.von;

  String? positiv;
  for (final eintrag in eintraege) {
    if (eintrag.test != Testergebnis.positiv) continue;
    // Vor dem letzten Periodenstart ist die Frage beantwortet: Es hat
    // seither geblutet. Ist noch gar keine Periode bekannt, gibt es nichts,
    // wovor der Test liegen könnte — dann zählt er.
    if (letzterStart != null && eintrag.tag.compareTo(letzterStart) < 0) {
      continue;
    }
    if (positiv == null || eintrag.tag.compareTo(positiv) > 0) {
      positiv = eintrag.tag;
    }
  }

  return ZyklusDatenGelesen(
    tage: Map.unmodifiable({for (final e in eintraege) e.tag: e}),
    perioden: List.unmodifiable(perioden),
    positiverTest: positiv,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Einstellungen
// ─────────────────────────────────────────────────────────────────────────

/// Die Einstellungen — **nie `null`** (Spec 5.1): Solange nichts abgelegt
/// oder noch nichts gelesen ist, gilt [ZyklusEinstellungen.vorbelegung].
///
/// Das ist hier kein verkappter Leerzustand: Die Vorbelegung ist eine
/// gültige Einstellung („nichts eingestellt"), keine Aussage über Daten.
final zyklusEinstellungenProvider = Provider<ZyklusEinstellungen>((ref) {
  final lauf = ref.watch(zyklusEinstellungenLaufProvider);
  if (lauf.hasValue) return lauf.value!;
  return ZyklusEinstellungen.vorbelegung;
});

/// Ob *Mehr* die Zeile „Zyklus" zeigt (Spec 5.1, 7).
final zyklusAnProvider = Provider<bool>(
  (ref) => ref.watch(zyklusEinstellungenProvider).kalenderAn,
);

// ─────────────────────────────────────────────────────────────────────────
// Der Erstimport aus Apple Health
// ─────────────────────────────────────────────────────────────────────────

/// Was über den Erstimport bekannt ist (Entwurf `zyklus-einrichten.js`,
/// Abschnitt „Aus Apple Health").
///
/// **Ein sealed-Typ und kein `int?`:** „noch nicht nachgesehen",
/// „nichts gefunden" und „übernommen" sind drei verschiedene Auskünfte,
/// und eine Zahl, die `null` sein darf, könnte die erste nicht von der
/// zweiten unterscheiden — das ist Fehler `01` in klein. Bei HealthKit
/// sind „keine Daten" und „nicht erlaubt" ohnehin nicht unterscheidbar
/// (`CLAUDE.md`), also darf „nichts gefunden" nie geraten werden.
sealed class ZyklusImportStand {
  const ZyklusImportStand();
}

/// Niemand hat nachgesehen. **Der heutige Dauerzustand:** Den
/// HealthKit-Leser für Zyklusdaten gibt es noch nicht; er kommt mit der
/// HealthKit-Stufe und setzt dann die übrigen Fälle.
final class ZyklusImportOffen extends ZyklusImportStand {
  const ZyklusImportOffen();
}

/// Health hält [monate] Monate Blutungshistorie bereit, übernommen ist
/// sie noch nicht.
final class ZyklusImportGefunden extends ZyklusImportStand {
  const ZyklusImportGefunden(this.monate);

  final int monate;

  @override
  bool operator ==(Object other) =>
      other is ZyklusImportGefunden && other.monate == monate;

  @override
  int get hashCode => monate.hashCode;
}

/// Nachgesehen, und Health hat nichts. Die Zeile bleibt trotzdem stehen
/// und sagt es — eine fehlende Zeile sähe aus wie eine Funktion, die es
/// nicht gibt (`CLAUDE.md`).
final class ZyklusImportNichts extends ZyklusImportStand {
  const ZyklusImportNichts();
}

/// Der Erstimport ist gelaufen. Er läuft **einmal** (Entwurf).
final class ZyklusImportGelaufen extends ZyklusImportStand {
  const ZyklusImportGelaufen();
}

/// Der Stand des Erstimports, wie ihn „Zyklus einrichten" zeigt.
///
/// Heute kann er nur zwei Fälle liefern: Was die Ablage weiß, ist das
/// Flag `import_gelaufen` (Spec 4.3) — alles andere setzt einen Leser
/// voraus, den es noch nicht gibt. Die Naht steht hier, damit die
/// HealthKit-Stufe sie bespielt, **ohne den Schirm anzufassen**; und
/// damit die Keine-Daten-Ansicht prüfbar ist, statt ein Nachtrag zu
/// werden.
final zyklusImportStandProvider = Provider<ZyklusImportStand>(
  (ref) => ref.watch(zyklusEinstellungenProvider).importGelaufen
      ? const ZyklusImportGelaufen()
      : const ZyklusImportOffen(),
);

// ─────────────────────────────────────────────────────────────────────────
// Die Vorhersage
// ─────────────────────────────────────────────────────────────────────────

/// Die Vorhersage aus dem ganzen bekannten Verlauf (Spec 3).
///
/// **Dieser Provider stellt den positiven Test fest, nicht der Kern**
/// (Spec 3.8/5.1): Er hat die Tageseinträge, vergleicht den letzten
/// positiven Test mit dem letzten Periodenstart und setzt `pausiert`.
///
/// `ZyklusEinstellungen.vorhersagePausiert` geht **nicht** ein: Die Spalte
/// hat heute keinen Schreiber, und ein zweiter Grund für dieselbe Pause
/// ließe die Lagezeile ohne Tag dastehen („seit dem positiven Test am …" —
/// welchem?). Wer sie später bespielt, bringt den Tag mit.
///
/// Solange die Tabelle nicht gelesen ist, steht hier eine **leere**
/// Vorhersage: Sie malt nichts ins Raster. Dass daraus kein „noch keine
/// Vorhersage" auf dem Schirm wird, besorgt [zyklusLageProvider] — der
/// Grund wird erst genannt, wenn er feststeht (`01`).
final zyklusVorhersageProvider = Provider<Zyklusvorhersage>((ref) {
  final einstellungen = ref.watch(zyklusEinstellungenProvider);
  final gelesen = zyklusWerte(ref.watch(zyklusDatenProvider));
  if (gelesen == null) {
    return Zyklusvorhersage(
      sicherheit: einstellungen.verhuetungAn
          ? Fruchtbarkeitssicherheit.unterHormonellerVerhuetung
          : Fruchtbarkeitssicherheit.natuerlich,
      grund: VorhersageGrund.zuWenigDaten,
    );
  }
  return zyklusVorhersage(
    perioden: gelesen.perioden,
    heute: BerlinCalendar.dayKey(ref.watch(heutigerTagProvider)),
    krankheitstage: ref.watch(zyklusKrankheitstageProvider),
    hormonell: einstellungen.verhuetungAn,
    pausiert: gelesen.positiverTest != null,
  );
});

/// Die Krankheitszeiträume, die das Unsicherheitsband weiten (Spec 3.3).
///
/// Solange die Ereignisse nicht gelesen sind, ist die Liste **leer** statt
/// unbekannt: Das Band ist dann im Zweifel schmaler, und die Vorhersage
/// trägt ohnehin ihren Vorbehalt. Auf das Lesen zu warten hieße, den
/// Kalender wegen einer Bandbreite leer stehen zu lassen.
final zyklusKrankheitstageProvider = Provider<List<Zyklusfenster>>((ref) {
  final lauf = ref.watch(ereignisseProvider);
  if (!lauf.hasValue) return const [];
  final ereignisse = lauf.value!;
  return List.unmodifiable([
    for (final ereignis in ereignisse)
      if (ereignis.art == EreignisArt.krankheit)
        Zyklusfenster(von: ereignis.von, bis: ereignis.bis),
  ]);
});

// ─────────────────────────────────────────────────────────────────────────
// Die Lage unter dem Raster
// ─────────────────────────────────────────────────────────────────────────

/// Was unter Raster und Legende steht — oder `null`, wenn es nichts zu
/// melden gibt.
sealed class ZyklusLage {
  const ZyklusLage();
}

/// Es reicht noch nicht für einen Median (Spec 3.1).
final class ZyklusLageKeineVorhersage extends ZyklusLage {
  const ZyklusLageKeineVorhersage();

  @override
  bool operator ==(Object other) => other is ZyklusLageKeineVorhersage;

  @override
  int get hashCode => (ZyklusLageKeineVorhersage).hashCode;
}

/// Ein positiver Test pausiert die Vorhersage (Spec 3.8).
final class ZyklusLagePausiert extends ZyklusLage {
  const ZyklusLagePausiert({required this.seit});

  /// Der Tag des Tests, als ISO-Tag.
  final String seit;

  @override
  bool operator ==(Object other) =>
      other is ZyklusLagePausiert && other.seit == seit;

  @override
  int get hashCode => Object.hash((ZyklusLagePausiert).hashCode, seit);
}

/// Die Lagezeile des Kalenders, oder `null`.
///
/// **Während gelesen wird, steht hier nichts** und nach einem gescheiterten
/// Lesen auch nicht: Beides ist kein Leerstand, und „noch keine Vorhersage"
/// wäre dann geraten (`01`).
final zyklusLageProvider = Provider<ZyklusLage?>((ref) {
  final gelesen = zyklusWerte(ref.watch(zyklusDatenProvider));
  if (gelesen == null) return null;
  return switch (ref.watch(zyklusVorhersageProvider).grund) {
    null => null,
    VorhersageGrund.zuWenigDaten => const ZyklusLageKeineVorhersage(),
    VorhersageGrund.pausiertWegenTest => ZyklusLagePausiert(
      seit: gelesen.positiverTest!,
    ),
  };
});

// ─────────────────────────────────────────────────────────────────────────
// Ein Monat im Raster
// ─────────────────────────────────────────────────────────────────────────

/// Ein Monat, fertig gefüllt (Spec 5.1).
///
/// **Jede Zelle ist immer da**, auch während gelesen wird und auch nach
/// einem Lesefehler — nur die Füllung unterscheidet sich (`CLAUDE.md`,
/// „Eine Anzeige, die es gibt, hat genau eine Form"). Ein Raster, das erst
/// mit den Daten entsteht, ließe den halben Schirm springen.
@immutable
class ZyklusMonatsstand {
  const ZyklusMonatsstand({
    required this.monat,
    required this.titel,
    required this.vorlauf,
    required this.tage,
    required this.blaesse,
  });

  /// Der Monat als `JJJJ-MM` — der Schlüssel dieses Standes.
  final String monat;

  /// Die Überschrift über dem Raster.
  final String titel;

  /// Leere Felder vor dem Monatsersten (Montag ist die erste Spalte).
  final int vorlauf;

  /// Jeder Tag des Monats, aufsteigend.
  final List<ZyklusTag> tage;

  final ZyklusBlaesse blaesse;

  // **Kein Feld „spaeter".** Bis zum 24.11.2026 stand hier eins: Es
  // schaltete den Vorwärtspfeil aus, solange es keine Vorhersage gab —
  // also im Normalfall jeder neuen Nutzerin. Wer einen Monat
  // zurückblätterte, kam nicht mehr in den aktuellen zurück (#601).
  // Erschlossen war die Regel aus dem Entwurf (`zyklus.js`, Variante
  // `keine-vorhersage`, `spaeter: false`), gemeint war dort aber „im
  // nächsten Monat ist nichts zu sehen", nicht „Blättern verboten".
  // Blättern hängt an der Stelle im Kalender, nicht am Datenstand, und
  // die Stelle kennt der Schirm — nicht dieser Stand.

  @override
  bool operator ==(Object other) =>
      other is ZyklusMonatsstand &&
      other.monat == monat &&
      other.titel == titel &&
      other.vorlauf == vorlauf &&
      other.blaesse == blaesse &&
      listEquals(other.tage, tage);

  @override
  int get hashCode =>
      Object.hash(monat, titel, vorlauf, blaesse, Object.hashAll(tage));
}

/// Die Tage von [monat] (`JJJJ-MM`), fertig gefüllt.
///
/// **Nicht `autoDispose`:** Ein autoDispose-Provider bestellt beim Abbau
/// einen Timer für sein Aufräumen, und den sieht `testWidgets` als „A Timer
/// is still pending" (siehe `umfaenge_provider.dart`). Gehalten werden ein
/// paar Monatsstände, die die Nutzerin selbst aufgeschlagen hat.
final zyklusMonatProvider = Provider.family<ZyklusMonatsstand, String>((
  ref,
  monat,
) {
  final gelesen = zyklusWerte(ref.watch(zyklusDatenProvider));
  final vorhersage = ref.watch(zyklusVorhersageProvider);
  final einstellungen = ref.watch(zyklusEinstellungenProvider);
  final heute = BerlinCalendar.dayKey(ref.watch(heutigerTagProvider));

  final jahr = int.parse(monat.substring(0, 4));
  final nummer = int.parse(monat.substring(5, 7));
  final erster = DateTime.utc(jahr, nummer);
  final anzahl = DateTime.utc(jahr, nummer + 1).difference(erster).inDays;

  return ZyklusMonatsstand(
    monat: monat,
    titel: Format.monatUndJahr(erster),
    // `DateTime.weekday` zählt Montag als 1 — und Montag ist die erste
    // Spalte des Rasters.
    vorlauf: erster.weekday - 1,
    blaesse: einstellungen.verhuetungAn
        ? ZyklusBlaesse.fruchtbarkeitBlass
        : ZyklusBlaesse.voll,
    tage: List.unmodifiable([
      for (var nummerImMonat = 1; nummerImMonat <= anzahl; nummerImMonat++)
        _tag(
          tag: '$monat-${nummerImMonat.toString().padLeft(2, '0')}',
          nummer: nummerImMonat,
          heute: heute,
          daten: gelesen,
          vorhersage: vorhersage,
        ),
    ]),
  );
});

ZyklusTag _tag({
  required String tag,
  required int nummer,
  required String heute,
  required ZyklusDatenGelesen? daten,
  required Zyklusvorhersage vorhersage,
}) {
  final eintrag = daten?.tage[tag];
  return ZyklusTag(
    tag: tag,
    nummer: nummer,
    heute: tag == heute,
    zyklustag: daten == null ? null : _zyklustag(tag, daten, vorhersage),
    zustand: _zustand(tag, eintrag, vorhersage),
    // **Ob getestet wurde, nicht mit welchem Ergebnis** (#598): Das
    // Raster vermerkt den Test, gedeutet wird er in der Lagezeile. Eine
    // Markierung, die nur beim positiven Ergebnis erschiene, verriete
    // es jedem, der über die Schulter schaut.
    test: eintrag?.test != null,
    marken: _marken(eintrag),
  );
}

/// Der Zustand **im** Tag: was eingetragen ist, schlägt, was gerechnet ist.
///
/// Ein Tag trägt genau einen Zustand (siehe [ZyklusTagZustand]) — gefüllt
/// heißt eingetragen, ungefüllt heißt geschätzt.
///
/// Eine **Zwischenblutung mit Stärke steht gefüllt da**, obwohl sie keine
/// Periode startet: Eingetragen ist sie trotzdem, und ein Tag, an dem die
/// Nutzerin etwas abgelegt hat und nichts sieht, sieht aus wie ein
/// verlorener Eintrag. Aus der Periodenrechnung bleibt sie heraus
/// ([_datenAus]).
ZyklusTagZustand? _zustand(
  String tag,
  ZyklusEintrag? eintrag,
  Zyklusvorhersage vorhersage,
) {
  if (eintrag?.blutung != null) return ZyklusTagZustand.eingetragen;
  if (_imFenster(vorhersage.kern, tag)) return ZyklusTagZustand.vorhergesagt;
  if (_imFenster(vorhersage.randVor, tag) ||
      _imFenster(vorhersage.randNach, tag)) {
    return ZyklusTagZustand.rand;
  }
  if (vorhersage.eisprung == tag) return ZyklusTagZustand.eisprung;
  if (_imFenster(vorhersage.fruchtbar, tag)) return ZyklusTagZustand.fruchtbar;
  return null;
}

/// Was **unter** dem Tag hängt: ein Herz für Sex, ein Punkt für Schmerzen
/// oder Symptome (Entwurf).
///
/// Eine bloße Notiz bekommt **keine** Marke: Ein Punkt, der je nach Tag
/// Beschwerden oder Freitext hieße, sagte nichts mehr — der Vorlesetext
/// nennt ihn „Beschwerden eingetragen". Tim hat das am 24.11.2026
/// ausdrücklich bestätigt („aber sonst ist es ein leerer tag ja").
///
/// **Der Test bekommt auch keine**, aber aus dem umgekehrten Grund: Er
/// steht seit #598 nicht mehr unter dem Tag, sondern **im** Tag, als
/// graue Füllung ([ZyklusTag.test]). Der Entwurf ließ ihn bis dahin ganz
/// weg („eine vierte Form im Raster für ein Ereignis, das zweimal im
/// Jahr vorkommt"); Tim hat anders entschieden.
List<ZyklusMarke> _marken(ZyklusEintrag? eintrag) {
  if (eintrag == null) return const [];
  return List.unmodifiable([
    if (eintrag.sex) ZyklusMarke.sex,
    if (eintrag.schmerz != null || eintrag.symptome.isNotEmpty)
      ZyklusMarke.notiz,
  ]);
}

/// Der Zyklustag als Plakette — **ab dem letzten Periodenstart** (Entwurf).
///
/// Gezählt wird nur bis zum vorhergesagten Beginn der nächsten Blutung: Ab
/// dort fängt rechnerisch ein neuer Zyklus an, und eine Zahl, die darüber
/// hinaus weiterzählt, ist nicht mehr ungenau, sondern falsch.
int? _zyklustag(
  String tag,
  ZyklusDatenGelesen daten,
  Zyklusvorhersage vorhersage,
) {
  final start = daten.letzterStart;
  if (start == null || tag.compareTo(start) < 0) return null;
  final kern = vorhersage.kern;
  if (kern != null && tag.compareTo(kern.von) >= 0) return null;
  return zyklustagAm(tag, daten.perioden);
}

bool _imFenster(Zyklusfenster? fenster, String tag) =>
    fenster != null &&
    fenster.von.compareTo(tag) <= 0 &&
    tag.compareTo(fenster.bis) <= 0;

// ─────────────────────────────────────────────────────────────────────────
// Ein einzelner Tag — „Tag eintragen"
// ─────────────────────────────────────────────────────────────────────────

/// Was über einen einzelnen Tag bekannt ist.
///
/// **Nicht `ZyklusEintrag?`**, wie die Tabelle in Spec 5.1 es nennt: `null`
/// kann „nichts abgelegt" und „noch nicht nachgesehen" nicht
/// auseinanderhalten, und genau das ist Fehler `01` — „nichts gewählt"
/// stünde dann da, bevor feststeht, was abgelegt ist. Die Nutzlast bleibt
/// der `ZyklusEintrag?`.
sealed class ZyklusTagStand {
  const ZyklusTagStand();
}

/// Es wird gelesen. Alle Abschnitte stehen trotzdem da — der Ladezustand
/// ist kein Leerstand.
final class ZyklusTagLaedt extends ZyklusTagStand {
  const ZyklusTagLaedt();

  @override
  bool operator ==(Object other) => other is ZyklusTagLaedt;

  @override
  int get hashCode => (ZyklusTagLaedt).hashCode;
}

/// Die Tabelle ließ sich nicht lesen.
final class ZyklusTagUnlesbar extends ZyklusTagStand {
  const ZyklusTagUnlesbar();

  @override
  bool operator ==(Object other) => other is ZyklusTagUnlesbar;

  @override
  int get hashCode => (ZyklusTagUnlesbar).hashCode;
}

/// Gelesen. [eintrag] ist `null`, wenn für diesen Tag nichts abgelegt ist.
final class ZyklusTagGelesen extends ZyklusTagStand {
  const ZyklusTagGelesen({required this.eintrag, required this.zyklustag});

  final ZyklusEintrag? eintrag;

  /// Der Zyklustag dieses Tages, oder `null` vor der ersten bekannten
  /// Periode. `1` heißt Periodenbeginn — das steht im Kopf dabei.
  final int? zyklustag;

  @override
  bool operator ==(Object other) =>
      other is ZyklusTagGelesen &&
      other.eintrag == eintrag &&
      other.zyklustag == zyklustag;

  @override
  int get hashCode => Object.hash(eintrag, zyklustag);
}

/// Der Tageseintrag zu [tag], gehalten.
///
/// Gelesen wird aus demselben Stand wie das Raster: Ein zweiter Weg zur
/// selben Zeile könnte dem Kalender widersprechen, und der Zyklustag im
/// Kopf braucht ohnehin den ganzen Verlauf.
final zyklusTagProvider = Provider.family<ZyklusTagStand, String>((ref, tag) {
  final zustand = ref.watch(zyklusDatenProvider);
  final vorhersage = ref.watch(zyklusVorhersageProvider);
  return switch (zustand) {
    ZyklusDatenLaden() => const ZyklusTagLaedt(),
    ZyklusDatenUnlesbar() => const ZyklusTagUnlesbar(),
    final ZyklusDatenGelesen gelesen => ZyklusTagGelesen(
      eintrag: gelesen.tage[tag],
      zyklustag: _zyklustag(tag, gelesen, vorhersage),
    ),
  };
});
