// Der Zustand hinter dem Mahlzeiten-Schirm (#300, Ernährungsplan Task 9) —
// was zu einer Mahlzeit eines Esstags eingetragen ist, einmal gerechnet und
// ohne Widget prüfbar. Der Schirm liegt in `mahlzeit_view.dart`.
//
// API und Vertrag sind durch `app/test/mahlzeit/mahlzeit_inhalt_test.dart`,
// `app/test/mahlzeit/mahlzeit_ziel_test.dart` (Ziel je Mahlzeit, #442) und
// `app/test/mahlzeit/mahlzeit_view_test.dart` verbindlich vorgegeben
// (siehe deren Dateiköpfe) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Der Inhalt kommt aus dem Tag.** [mahlzeitProvider] leitet aus
// `ernaehrungsTagProvider` ab und sucht dort die `MahlzeitZeile` dieser
// Mahlzeit heraus, statt die Einteilung ein zweites Mal zu rechnen: Ein
// eigener Eintrag steht in der Zeile, die er selbst nennt, eine fremde
// Probe in der Zeile ihrer Berliner Uhrzeit. Zwei Einteilungen an zwei
// Stellen liefen irgendwann auseinander, und dann zeigten Tagesschirm und
// Mahlzeiten-Schirm verschiedene Summen für dieselbe Mahlzeit.
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../data/lebensmittel_repository.dart';
import 'erfassen_formular.dart';
import 'erfassen_weg.dart';
import 'ernaehrung_provider.dart';

/// Was zu einer Mahlzeit eines Esstags eingetragen ist.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** — er ist
/// Abhängigkeit eines Providers, und ohne Wertgleichheit liefe jeder
/// abgeleitete Wert bei jedem Zugriff neu (`CLAUDE.md`, Fehler `03`).
@immutable
class MahlzeitInhalt {
  const MahlzeitInhalt({
    required this.tagesSchluessel,
    required this.mahlzeit,
    required this.eigene,
    required this.fremde,
    required this.summe,
    required this.laedt,
    this.fluessigeVorlagen = const {},
    this.zielKcal,
    this.prozent,
    this.tageszielKcal,
    this.aufteilungGesichert = false,
    this.zielLaedt = false,
  });

  /// Der **Esstag** als ISO-Tagesstring.
  final String tagesSchluessel;

  final Mahlzeit mahlzeit;

  /// Tims eigene Einträge dieser Mahlzeit, chronologisch.
  final List<Eintrag> eigene;

  /// Die fremden Mahlzeiten aus Apple Health, chronologisch.
  final List<FremdeMahlzeit> fremde;

  /// Eigene und fremde zusammen — **`null` genau dann, wenn [leer]**.
  ///
  /// `MahlzeitZeile.summe` trägt bei einer leeren Zeile acht Nullen; auf
  /// dem Tagesschirm ist das richtig, denn dort steht ein Plus und keine
  /// Zahl. Dieser Schirm zeigt die Summe aber **als Zahl**, und eine `0`
  /// behauptete „nichts gegessen" — etwas anderes als „nichts
  /// eingetragen" (`mahlzeit.js`, Zustand `leer`). Darum `null`, und der
  /// Schirm macht daraus `–/–`.
  final Naehrwerte? summe;

  /// Die eigenen Einträge sind noch nicht gelesen.
  ///
  /// **Kommt nicht aus dem fertigen Tag.** `ernaehrungsTagProvider` fällt
  /// auf `const []` zurück, solange die eigenen Einträge ausstehen — aus
  /// dem Ergebnis ist „noch nicht gelesen" dann nicht mehr von „nichts
  /// eingetragen" zu unterscheiden. Genau diese Verwechslung ist Fehler
  /// `01`; deshalb wird direkt am `eigeneEintraegeProvider` abgelesen.
  final bool laedt;

  /// Die Vorlagen unter den eigenen Einträgen **ohne** Schnappschuss
  /// `fluessig`, die flüssig sind (#403) — der Rückfall für Einträge von
  /// vor der Stufe 20. Gelesen in **einer** Abfrage für die ganze Liste
  /// ([fluessigeVorlagenProvider]), nicht je Zeile.
  final Set<int> fluessigeVorlagen;

  /// Ob [eintrag] in Millilitern dasteht: der Schnappschuss, wenn er einen
  /// trägt — er gewinnt gegen die Vorlage —, sonst die Vorlage, sonst
  /// Gramm.
  bool inMillilitern(Eintrag eintrag) {
    final schnappschuss = eintrag.fluessig;
    if (schnappschuss != null) return schnappschuss;
    final vorlage = eintrag.lebensmittelId;
    return vorlage != null && fluessigeVorlagen.contains(vorlage);
  }

  /// Das Ziel dieser Mahlzeit in kcal (#442, Schnitt 3 von #385) —
  /// **gereicht aus `MahlzeitZeile.zielKcal`, nicht neu gerechnet.** `null`
  /// ohne gesicherte Aufteilung (Entscheidung 1, kein Startwert als
  /// Ersatz), ohne Tagesziel, bei 0 % (V4) und solange [zielLaedt].
  final double? zielKcal;

  /// Der Anteil dieser Mahlzeit in der geltenden Aufteilung, in Prozent.
  /// `null` ohne Aufteilung; **`0` ist ein Wert** — der Schirm sagt dann
  /// „0 % deines Tagesziels — so eingestellt" (V4).
  final int? prozent;

  /// Das Tagesziel (`ErnaehrungsTag.zielKcal`, V5). Steht auch ohne
  /// Aufteilung — es ist keine Rechnung über sie.
  final double? tageszielKcal;

  /// An diesem Tag gilt eine gesicherte Aufteilung
  /// (`ErnaehrungsTag.aufteilung != null`).
  final bool aufteilungGesichert;

  /// Einträge, Aufteilungen oder Tagesziel sind noch nicht gelesen
  /// (`ErnaehrungsTag.mahlzeitenLaedt`, V9).
  ///
  /// **Trennt „noch nicht gelesen" von „keine Aufteilung".** In beiden
  /// Fällen ist [aufteilungGesichert] `false`; ohne dieses Feld böte der
  /// Schirm während des Ladens das Festlegen an — Fehler `01`. [laedt]
  /// liest nur die eigenen Einträge und bleibt dabei unverändert.
  final bool zielLaedt;

  bool get leer => eigene.isEmpty && fremde.isEmpty;

  /// Alles, was dasteht, kommt aus einer anderen App — dann sagt der
  /// Schirm das, statt kaputt auszusehen. Apple gibt fremde Proben nicht
  /// frei; keine dieser Zeilen ist änderbar.
  bool get nurFremd => fremde.isNotEmpty && eigene.isEmpty;

  int get anzahl => eigene.length + fremde.length;

  @override
  bool operator ==(Object other) =>
      other is MahlzeitInhalt &&
      other.tagesSchluessel == tagesSchluessel &&
      other.mahlzeit == mahlzeit &&
      _gleicheListe(other.eigene, eigene) &&
      _gleicheListe(other.fremde, fremde) &&
      other.summe == summe &&
      other.laedt == laedt &&
      setEquals(other.fluessigeVorlagen, fluessigeVorlagen) &&
      other.zielKcal == zielKcal &&
      other.prozent == prozent &&
      other.tageszielKcal == tageszielKcal &&
      other.aufteilungGesichert == aufteilungGesichert &&
      other.zielLaedt == zielLaedt;

  @override
  int get hashCode => Object.hash(
    tagesSchluessel,
    mahlzeit,
    Object.hashAll(eigene),
    Object.hashAll(fremde),
    summe,
    laedt,
    Object.hashAllUnordered(fluessigeVorlagen),
    zielKcal,
    prozent,
    tageszielKcal,
    aufteilungGesichert,
    zielLaedt,
  );

  @override
  String toString() =>
      'MahlzeitInhalt(tagesSchluessel: $tagesSchluessel, '
      'mahlzeit: $mahlzeit, eigene: ${eigene.length}, '
      'fremde: ${fremde.length}, summe: $summe, laedt: $laedt, '
      'zielKcal: $zielKcal, prozent: $prozent, '
      'tageszielKcal: $tageszielKcal, '
      'aufteilungGesichert: $aufteilungGesichert, zielLaedt: $zielLaedt)';
}

/// Inhaltsgleichheit zweier Listen — dieselbe Handvoll Zeilen wie in
/// `ernaehrung_provider.dart`; `package:collection` wäre der kurze Weg,
/// aber die Abhängigkeitsliste von `app/` bleibt, wie sie ist.
bool _gleicheListe<T>(List<T> links, List<T> rechts) {
  if (identical(links, rechts)) return true;
  if (links.length != rechts.length) return false;
  for (var i = 0; i < links.length; i++) {
    if (links[i] != rechts[i]) return false;
  }
  return true;
}

/// Der Inhalt einer Mahlzeit, **gehalten** statt bei jedem Zugriff
/// gerechnet (`CLAUDE.md`, Hausregel 2 — Fehler `03`).
///
/// Der Preis der Ableitung aus dem Tag ist, dass dieser Provider auch dann
/// neu läuft, wenn sich am Tag etwas ändert, das diesen Schirm nichts
/// angeht (ein Gewicht, ein Ziel). Das kostet eine Listensuche auf einem
/// gehaltenen Wert, und weil [MahlzeitInhalt] `==` trägt, baut davon kein
/// Widget neu.
final mahlzeitProvider = Provider.family<MahlzeitInhalt, (String, Mahlzeit)>((
  ref,
  schluessel,
) {
  final (tagesSchluessel, mahlzeit) = schluessel;
  final tag = ref.watch(ernaehrungsTagProvider(tagesSchluessel));
  final zeile = tag.mahlzeiten.firstWhere((z) => z.mahlzeit == mahlzeit);

  // Direkt an der Quelle abgelesen, nicht am fertigen Tag — siehe
  // [MahlzeitInhalt.laedt].
  final laedt = !ref.watch(eigeneEintraegeProvider(tagesSchluessel)).hasValue;

  final leer = zeile.eigene.isEmpty && zeile.fremde.isEmpty;

  // Solange die Vorlagen nicht gelesen sind, gilt der zuletzt gelesene
  // Stand, beim ersten Mal keiner — dann stehen alte Einträge ohne
  // Schnappschuss für einen Augenblick in Gramm.
  final fluessige =
      ref.watch(fluessigeVorlagenProvider(tagesSchluessel)).value ??
      const <int>{};

  // Ziel und Anteil kommen aus dem Tag, wie die Einteilung (#442):
  // Dort ist schon entschieden, dass ohne Aufteilung und beim Laden
  // kein Ziel steht. Hier wird nur weitergereicht.
  final aufteilung = tag.aufteilung;

  return MahlzeitInhalt(
    tagesSchluessel: tagesSchluessel,
    mahlzeit: mahlzeit,
    eigene: zeile.eigene,
    fremde: zeile.fremde,
    summe: leer ? null : zeile.summe,
    laedt: laedt,
    fluessigeVorlagen: fluessige,
    zielKcal: zeile.zielKcal,
    prozent: aufteilung?.prozent(mahlzeit),
    tageszielKcal: tag.zielKcal,
    aufteilungGesichert: aufteilung != null,
    zielLaedt: tag.mahlzeitenLaedt,
  );
});

/// Welche Vorlagen der eigenen Einträge eines Esstags flüssig sind —
/// **nur** für Einträge ohne Schnappschuss `fluessig` (#403), also solche
/// von vor der Stufe 20. Ein Eintrag mit Schnappschuss fragt nicht nach.
///
/// **Eine Abfrage für den ganzen Tag** (`CLAUDE.md`, Hausregel 2), gehalten
/// und neu gelesen, wenn sich die Einträge des Tages ändern. Gibt es keinen
/// alten Eintrag mit Vorlage, wird gar nicht gefragt.
final fluessigeVorlagenProvider = FutureProvider.family<Set<int>, String>((
  ref,
  tagesSchluessel,
) async {
  final eintraege = await ref.watch(
    eigeneEintraegeProvider(tagesSchluessel).future,
  );
  final ohneSchnappschuss = {
    for (final e in eintraege)
      if (e.fluessig == null && e.lebensmittelId != null) e.lebensmittelId!,
  };
  if (ohneSchnappschuss.isEmpty) return const {};
  return ref
      .watch(lebensmittelRepositoryProvider)
      .fluessigeUnter(ohneSchnappschuss);
});

/// Der Weg von einer eigenen Zeile ins Bearbeiten-Blatt.
typedef BearbeitenOeffner = Future<void> Function(
  BuildContext context,
  Eintrag eintrag,
);

/// Die **eine** Stelle, an der der Mahlzeiten-Schirm das Bearbeiten-Blatt
/// öffnet.
///
/// „Jede eigene Zeile führt ins Bearbeiten-Blatt, kein zweites Formular"
/// (`mahlzeit.js`): Das ist das `BuchungsBlatt` aus #285, vorbelegt aus
/// **genau diesem** Eintrag (`BuchungsFormular.fuer`) — dasselbe Blatt wie
/// beim Buchen, mit Menge, Mahlzeit und Tag des Eintrags und „Löschen"
/// unten. Bis zum Eintragweg stand hier ein Dialog.
///
/// Als Provider und nicht als fest verdrahteter Aufruf, damit der Schirm
/// eine Naht hat: Ein Test kann so prüfen, dass eine eigene Zeile **genau
/// ihren** Eintrag weiterreicht und eine fremde gar keinen.
final bearbeitenOeffnerProvider = Provider<BearbeitenOeffner>(
  (ref) =>
      (context, eintrag) =>
          zeigeBuchungsBlatt(context, BuchungsFormular.fuer(eintrag)),
);
