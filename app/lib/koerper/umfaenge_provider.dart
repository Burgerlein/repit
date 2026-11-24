// Was die beiden Umfänge-Schirme zeigen (#477 und #478 unter #88) —
// **gehalten, nicht je Bild gerechnet** (Hausregel 2): Wert, Veränderung
// und Vorlesetext je Maß entstehen hier einmal, wenn sich die Messungen
// ändern. Eine berechnete Eigenschaft im Widget liefe je Bild, und das ist
// Fehler `03`.
//
// Hier, nicht im Widget, wird `AsyncValue` gelesen: Die Widget-Schicht
// bekommt einen sealed-Typ und muss jeden Fall behandeln (Hausregel 1).
// `Messwert<T>` gilt nicht — Umfänge sind Tims eigene Daten, es gibt keinen
// Lauf, der leer ausgehen kann. Leer heißt leer.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/umfaenge_repository.dart';

// ─────────────────────────────────────────────────────────────────────────
// Die Übersicht
// ─────────────────────────────────────────────────────────────────────────

/// Eine Zeile der Übersicht: ein Maß, sein jüngster Wert und was sich seit
/// der vorigen Messung **dieses Maßes** getan hat.
@immutable
class UmfangsZeile {
  const UmfangsZeile({
    required this.mass,
    required this.wert,
    required this.veraenderung,
    required this.vorigerTag,
  });

  final Umfang mass;

  /// `null` heißt „nie gemessen" — **nicht** `0`. Ein Umfang von null
  /// Zentimetern wäre eine Behauptung (`CLAUDE.md`).
  final double? wert;

  /// `null`, solange es keinen zweiten Punkt dieses Maßes gibt. „Erste
  /// Messung" ist kein „±0,0".
  final UmfangsVeraenderung? veraenderung;

  /// Der Tag der vorigen Messung dieses Maßes, für „seit 30.08.".
  final String? vorigerTag;

  @override
  bool operator ==(Object other) =>
      other is UmfangsZeile &&
      other.mass == mass &&
      other.wert == wert &&
      other.veraenderung == veraenderung &&
      other.vorigerTag == vorigerTag;

  @override
  int get hashCode => Object.hash(mass, wert, veraenderung, vorigerTag);
}

/// Eine Zeile unter „Alle Messungen": ein Messtag und wie viele Maße er
/// trägt.
@immutable
class UmfangsMesstag {
  const UmfangsMesstag({required this.tag, required this.anzahlMasse});

  /// ISO-Tagesstring. **Er steht auch im Schlüssel der Zeile**: Eine Zeile,
  /// die ihren Tag nicht kennt, kann ihn nicht öffnen.
  final String tag;

  final int anzahlMasse;

  @override
  bool operator ==(Object other) =>
      other is UmfangsMesstag &&
      other.tag == tag &&
      other.anzahlMasse == anzahlMasse;

  @override
  int get hashCode => Object.hash(tag, anzahlMasse);
}

/// Der Zustand der Übersicht.
sealed class UmfaengeUebersicht {
  const UmfaengeUebersicht();
}

/// Die Tabelle wird gelesen. **Kein Leerzustand** — „Noch keine Umfänge
/// erfasst" während des Lesens wäre Fehler `01`.
final class UebersichtLaedt extends UmfaengeUebersicht {
  const UebersichtLaedt();

  @override
  bool operator ==(Object other) => other is UebersichtLaedt;

  @override
  int get hashCode => (UebersichtLaedt).hashCode;
}

/// Die Tabelle ließ sich nicht lesen. Auch das ist kein Leerzustand.
final class UebersichtUnlesbar extends UmfaengeUebersicht {
  const UebersichtUnlesbar();

  @override
  bool operator ==(Object other) => other is UebersichtUnlesbar;

  @override
  int get hashCode => (UebersichtUnlesbar).hashCode;
}

/// Gelesen. [messtage] ist leer, wenn nie gemessen wurde.
final class UebersichtGelesen extends UmfaengeUebersicht {
  const UebersichtGelesen({required this.zeilen, required this.messtage});

  /// Alle fünfzehn Maße, in der Reihenfolge von [Umfang.values] — auch die
  /// nie gemessenen. Eine Anzeige, die es gibt, hat genau eine Form.
  final List<UmfangsZeile> zeilen;

  /// Absteigend nach Tag, die jüngste Messung zuerst.
  final List<UmfangsMesstag> messtage;

  /// Noch nie gemessen.
  bool get istLeer => messtage.isEmpty;

  /// Genau einmal gemessen — dann gibt es keinen Verlauf, und das sagt der
  /// Schirm, statt eine Null als Trend auszugeben.
  bool get istErsteMessung => messtage.length == 1;

  /// Der jüngste Messtag als ISO-Tagesstring, oder `null`.
  String? get letzterTag => messtage.isEmpty ? null : messtage.first.tag;

  @override
  bool operator ==(Object other) =>
      other is UebersichtGelesen &&
      listEquals(other.zeilen, zeilen) &&
      listEquals(other.messtage, messtage);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(zeilen), Object.hashAll(messtage));
}

/// Die Lage der Übersicht, **vollständig über den sealed-Typ** — das
/// Gegenstück zu `MessLage` in `mess_abschnitte.dart`.
///
/// Zustand und Nutzlast werden getrennt gezogen: Ein
/// `is UebersichtGelesen ? … : null` ebnet beides in einem Schritt ein und
/// macht aus drei Fällen zwei Auskünfte — dann trägt der sealed-Typ nichts
/// mehr. Käme ein vierter Fall dazu, zeigt der Analyzer auf
/// [umfaengeLageAus] und auf jeden `switch` darüber.
enum UmfaengeLage {
  /// Es wird gelesen. Hier steht **nie** eine Aussage über die Datenlage —
  /// weder im Grund-Kasten noch in einer der fünfzehn Zeilen (`01`).
  laedt,

  /// Das Lesen ist gescheitert. **Keine Aussage über die Datenlage**, und
  /// auch keine über einen laufenden Versuch: Es läuft nichts mehr.
  unlesbar,

  /// Gelesen. Erst hier darf dastehen, was erfasst ist — und was nicht.
  gelesen,
}

UmfaengeLage umfaengeLageAus(UmfaengeUebersicht zustand) => switch (zustand) {
  UebersichtLaedt() => UmfaengeLage.laedt,
  UebersichtUnlesbar() => UmfaengeLage.unlesbar,
  UebersichtGelesen() => UmfaengeLage.gelesen,
};

/// Die Nutzlast, oder `null` — und zwar über denselben `switch`, nicht über
/// einen `is`-Test daneben.
UebersichtGelesen? uebersichtWerte(UmfaengeUebersicht zustand) =>
    switch (zustand) {
      final UebersichtGelesen gelesen => gelesen,
      UebersichtLaedt() || UebersichtUnlesbar() => null,
    };

/// Alle Messungen, absteigend nach Tag — die Quelle beider Umfänge-Schirme.
final umfaengeMessungenProvider = FutureProvider<List<Umfangsmessung>>(
  (ref) => ref.watch(umfaengeRepositoryProvider).messungen(),
);

/// Die Übersicht, einmal gerechnet und gehalten.
final umfaengeUebersichtProvider = Provider<UmfaengeUebersicht>((ref) {
  final lauf = ref.watch(umfaengeMessungenProvider);
  if (lauf.hasValue) return _uebersichtAus(lauf.value!);
  if (lauf.hasError) return const UebersichtUnlesbar();
  return const UebersichtLaedt();
});

UebersichtGelesen _uebersichtAus(List<Umfangsmessung> messungen) {
  // Aufsteigend für die Rechnungen des Kerns, absteigend für die Anzeige.
  final aufsteigend = [...messungen]
    ..sort((eine, andere) => eine.zeitpunkt.compareTo(andere.zeitpunkt));

  return UebersichtGelesen(
    zeilen: List.unmodifiable([
      for (final mass in Umfang.values) _zeile(mass, messungen, aufsteigend),
    ]),
    messtage: List.unmodifiable([
      for (final messung in messungen)
        UmfangsMesstag(
          tag: BerlinCalendar.dayKey(messung.zeitpunkt),
          anzahlMasse: messung.werte.length,
        ),
    ]),
  );
}

UmfangsZeile _zeile(
  Umfang mass,
  List<Umfangsmessung> messungen,
  List<Umfangsmessung> aufsteigend,
) {
  // Nur die Messungen, die **dieses** Maß tragen: Ein Tag, an dem nur die
  // Taille nachgemessen wurde, ist für den Oberarm keine Messung.
  final reihe = [
    for (final messung in aufsteigend)
      if (messung.werte.containsKey(mass)) messung,
  ];

  return UmfangsZeile(
    mass: mass,
    wert: reihe.isEmpty ? null : reihe.last.werte[mass],
    veraenderung: UmfangsFortschritt.veraenderung(mass, messungen),
    vorigerTag: reihe.length < 2
        ? null
        : BerlinCalendar.dayKey(reihe[reihe.length - 2].zeitpunkt),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Das Formular
// ─────────────────────────────────────────────────────────────────────────

/// Der Zustand des Eintragen-Schirms für **einen** Tag.
sealed class UmfangsFormular {
  const UmfangsFormular();
}

/// Es wird gelesen. Die fünfzehn Felder stehen trotzdem da — der
/// Ladezustand ist kein Leerstand (`01`). Nur der Hinweis „für diesen Tag
/// ist schon eine Messung eingetragen" bleibt weg: Solange niemand weiß, ob
/// etwas vorliegt, wird es auch nicht behauptet.
final class FormularLaedt extends UmfangsFormular {
  const FormularLaedt();

  @override
  bool operator ==(Object other) => other is FormularLaedt;

  @override
  int get hashCode => (FormularLaedt).hashCode;
}

/// Die Tabelle ließ sich nicht lesen — weder Vorwerte noch Hinweis.
final class FormularUnlesbar extends UmfangsFormular {
  const FormularUnlesbar();

  @override
  bool operator ==(Object other) => other is FormularUnlesbar;

  @override
  int get hashCode => (FormularUnlesbar).hashCode;
}

/// Gelesen.
final class FormularGelesen extends UmfangsFormular {
  const FormularGelesen({required this.werteAmTag, required this.vorwerte});

  /// Was an **diesem** Tag schon gemessen wurde. Diese Werte stehen als
  /// Text in den Feldern — man soll sehen, welche Zahl bestätigt ist.
  final Map<Umfang, double> werteAmTag;

  /// Je Maß der Wert der jüngsten Messung **vor** diesem Tag. Steht blass
  /// hinter einem leeren Feld.
  final Map<Umfang, double> vorwerte;

  /// Ob für diesen Tag schon eine Messung vorliegt.
  bool get schonGemessen => werteAmTag.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is FormularGelesen &&
      mapEquals(other.werteAmTag, werteAmTag) &&
      mapEquals(other.vorwerte, vorwerte);

  @override
  int get hashCode => Object.hash(_hash(werteAmTag), _hash(vorwerte));

  /// Über die Maße in ihrer festen Reihenfolge, nicht über die der Map —
  /// dieselbe Begründung wie bei `Umfangsmessung`.
  static int _hash(Map<Umfang, double> werte) => Object.hashAll([
    for (final mass in Umfang.values)
      if (werte.containsKey(mass)) ...[mass, werte[mass]],
  ]);
}

/// Der Lauf hinter dem Formular: die Messung des gewählten Tages und die
/// Werte vom letzten Mal.
///
/// **Nicht `autoDispose`**, obwohl es naheläge: Ein autoDispose-Provider
/// bestellt beim Abbau des Baums einen Null-Timer für sein Aufräumen, und
/// den sieht `testWidgets` als „A Timer is still pending even after the
/// widget tree was disposed" — außer der Behälter hängt im Baum
/// (`BehaelterImBaum`), und das tut er nicht in jedem Test. Frisch gelesen
/// wird stattdessen über [umfaengeNeuGelesen] nach jedem Schreiben; ohne
/// das stünde der eben eingetragene Wert beim nächsten Öffnen nicht als
/// Vorwert da (`32`).
///
/// Öffentlich nur, damit [umfaengeNeuGelesen] ihn ungültig machen kann —
/// gelesen wird über [umfangsFormularProvider].
final umfangsFormularLaufProvider =
    FutureProvider.family<FormularGelesen, String>((ref, tag) async {
      final ablage = ref.watch(umfaengeRepositoryProvider);
      final messung = await ablage.messungAm(tag);
      final vorwerte = await ablage.werteVomLetztenMal(vorTag: tag);
      return FormularGelesen(
        werteAmTag: Map.unmodifiable(
          messung?.werte ?? const <Umfang, double>{},
        ),
        vorwerte: Map.unmodifiable(vorwerte),
      );
    });

/// Der Zustand des Formulars für [tag] — der sealed-Typ, den der Schirm
/// liest.
final umfangsFormularProvider = Provider.family<UmfangsFormular, String>((
  ref,
  tag,
) {
  final lauf = ref.watch(umfangsFormularLaufProvider(tag));
  if (lauf.hasValue) return lauf.value!;
  if (lauf.hasError) return const FormularUnlesbar();
  return const FormularLaedt();
});

/// Die Lage des Formulars, vollständig über den sealed-Typ — dieselbe
/// Trennung wie bei [UmfaengeLage].
enum FormularLage {
  /// Es wird gelesen: keine Vorwerte, kein Hinweis, keine Aussage darüber,
  /// ob für diesen Tag schon etwas vorliegt (`01`).
  laedt,

  /// Das Lesen ist gescheitert. Die fünfzehn Felder stehen trotzdem da —
  /// dass die alten Werte fehlen, hindert niemanden am Messen.
  unlesbar,

  /// Gelesen.
  gelesen,
}

FormularLage formularLageAus(UmfangsFormular zustand) => switch (zustand) {
  FormularLaedt() => FormularLage.laedt,
  FormularUnlesbar() => FormularLage.unlesbar,
  FormularGelesen() => FormularLage.gelesen,
};

/// Die Nutzlast, oder `null`.
FormularGelesen? formularWerte(UmfangsFormular zustand) => switch (zustand) {
  final FormularGelesen gelesen => gelesen,
  FormularLaedt() || FormularUnlesbar() => null,
};

/// Der Tag der jüngsten Messung — für die Umfänge-Kachel auf `koerper`.
///
/// Eigener Provider und nicht die ganze Liste: Die Kachel braucht ein
/// Datum, nicht fünfzehn Reihen.
final umfaengeLetzterMesstagProvider = FutureProvider<String?>(
  (ref) => ref.watch(umfaengeRepositoryProvider).letzterMesstag(),
);

/// Alles, was von den Umfängen abhängt, noch einmal lesen — nach jedem
/// Schreiben.
///
/// **Die ganze Familie des Formulars**, nicht nur der geschriebene Tag: Der
/// Vorwert eines späteren Tages ändert sich mit, und ein stehengebliebener
/// Stand behauptete sonst, es sei nichts passiert.
void umfaengeNeuGelesen(WidgetRef ref) {
  ref.invalidate(umfaengeMessungenProvider);
  ref.invalidate(umfaengeLetzterMesstagProvider);
  ref.invalidate(umfangsFormularLaufProvider);
}

/// Dasselbe über den Behälter — für Arbeit, die ein Poppen des Schirms
/// überlebt (das Löschen, #486): Ein `ref` gehört seinem Widget und ist
/// nach dessen Abbau nicht mehr benutzbar; der Behälter lebt weiter, und
/// die Schirme darunter müssen den neuen Stand sehen.
///
/// Der Aufrufer holt sich den Behälter **vor** dem `await`
/// (`ProviderScope.containerOf(context, listen: false)`), solange sein
/// `context` noch steht.
void umfaengeNeuGelesenIm(ProviderContainer behaelter) {
  behaelter.invalidate(umfaengeMessungenProvider);
  behaelter.invalidate(umfaengeLetzterMesstagProvider);
  behaelter.invalidate(umfangsFormularLaufProvider);
}
