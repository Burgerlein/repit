// Was der Verlaufsschirm **eines** Maßes zeigt (#479 unter #88) —
// **gehalten, nicht je Bild gerechnet** (Hausregel 2): Reihe, Gegenreihe,
// Kennzahlen und Messliste entstehen hier einmal, wenn sich die Messungen
// ändern. Eine berechnete Eigenschaft im Widget liefe je Bild, und das ist
// Fehler `03`.
//
// Hier, nicht im Widget, wird `AsyncValue` gelesen: Die Widget-Schicht
// bekommt einen sealed-Typ und muss jeden Fall behandeln (Hausregel 1).
// `Messwert<T>` gilt nicht — Umfänge sind Tims eigene Daten, es gibt keinen
// Lauf, der leer ausgehen kann. Leer heißt leer.
//
// **Die Quelle ist dieselbe wie bei der Übersicht**
// ([umfaengeMessungenProvider]): Wer von der Übersicht hierher kommt und
// wieder zurück, wartet auf keinen zweiten Lauf — der Lauf ist derselbe
// (`32`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import 'umfaenge_provider.dart';

/// Ein Punkt in der Form, die `Zeitdiagramm` erwartet.
typedef Verlaufspunkt = ({DateTime tag, double wert});

/// Eine Zeile unter „Alle Messungen": der Tag und der Wert dieses Maßes an
/// ihm.
typedef Verlaufszeile = ({String tag, double wert});

/// Der Zustand des Verlaufsschirms.
sealed class UmfangsVerlauf {
  const UmfangsVerlauf();
}

/// Die Tabelle wird gelesen. **Kein Leerzustand** — „noch nie gemessen"
/// während des Lesens wäre Fehler `01`.
final class VerlaufLaedt extends UmfangsVerlauf {
  const VerlaufLaedt();

  @override
  bool operator ==(Object other) => other is VerlaufLaedt;

  @override
  int get hashCode => (VerlaufLaedt).hashCode;
}

/// Die Tabelle ließ sich nicht lesen. Auch das ist kein Leerzustand — und
/// auch keine Aussage über einen laufenden Versuch: Es läuft nichts mehr.
final class VerlaufUnlesbar extends UmfangsVerlauf {
  const VerlaufUnlesbar();

  @override
  bool operator ==(Object other) => other is VerlaufUnlesbar;

  @override
  int get hashCode => (VerlaufUnlesbar).hashCode;
}

/// Gelesen. Alle Listen sind leer, wenn dieses Maß nie gemessen wurde.
///
/// Werttyp mit `==` und `hashCode`, weil er Abhängigkeit eines Providers
/// ist und seine Reihe in ein Diagramm geht: Ohne Gleichheit wäre jede neu
/// gelesene Reihe ungleich der vorigen und jedes Bild rechnete neu —
/// Fehler `03` (`CLAUDE.md`).
final class VerlaufGelesen extends UmfangsVerlauf {
  const VerlaufGelesen({
    required this.mass,
    required this.reihe,
    required this.gegenreihe,
    required this.messungen,
    required this.veraenderung,
    required this.vorigerTag,
    required this.ersterTag,
    required this.seitStart,
    required this.proMonat,
    required this.spanne,
    required this.seitendifferenz,
  });

  final Umfang mass;

  /// Die Punkte **dieses** Maßes, aufsteigend. Ein Tag, an dem nur die
  /// Taille nachgemessen wurde, ist für den Oberarm keine Messung — die
  /// Lücke bleibt eine Lücke und wird nicht mit `0` gefüllt.
  final List<Verlaufspunkt> reihe;

  /// Die Punkte der Gegenseite ([Umfang.partner]), aufsteigend. Leer, wenn
  /// es keine Gegenseite gibt **oder** sie nie gemessen wurde — eine leere
  /// zweite Linie wäre eine Legende ohne Inhalt.
  final List<Verlaufspunkt> gegenreihe;

  /// Dieselben Werte wie [reihe], **absteigend** und mit Tagesschlüssel —
  /// „Alle Werte dieses Maßes als Liste, neueste zuerst" (Spec).
  final List<Verlaufszeile> messungen;

  /// Gegen die vorige Messung dieses Maßes; `null`, solange es keinen
  /// zweiten Punkt gibt. „Erste Messung" ist kein „±0,0".
  final UmfangsVeraenderung? veraenderung;

  /// Der Tag der vorigen bzw. der ersten Messung dieses Maßes — für „seit
  /// 30.08.".
  final String? vorigerTag;
  final String? ersterTag;

  final double? seitStart;
  final double? proMonat;
  final (double niedrigster, double hoechster)? spanne;

  /// Wie weit dieses Maß von seiner Gegenseite entfernt liegt — gerechnet
  /// im Kern (`UmfangsFortschritt.seitendifferenz`, #493), nicht hier:
  /// Totzone, Richtung und „beide Seiten gleich" sind eine Rechnung, und
  /// Rechnungen bekommen ihren Test im Kern. `null` heißt „es gibt keine":
  /// ohne Gegenseite ([Umfang.partner]) oder solange eine Seite nie
  /// gemessen wurde — unterscheiden kann die Ansicht das am Maß selbst.
  final UmfangsSeitendifferenz? seitendifferenz;

  /// Noch nie gemessen.
  bool get istLeer => reihe.isEmpty;

  /// Genau einmal gemessen — ein Punkt ist noch kein Verlauf.
  bool get istErsteMessung => reihe.length == 1;

  @override
  bool operator ==(Object other) =>
      other is VerlaufGelesen &&
      other.mass == mass &&
      listEquals(other.reihe, reihe) &&
      listEquals(other.gegenreihe, gegenreihe) &&
      listEquals(other.messungen, messungen) &&
      other.veraenderung == veraenderung &&
      other.vorigerTag == vorigerTag &&
      other.ersterTag == ersterTag &&
      other.seitStart == seitStart &&
      other.proMonat == proMonat &&
      other.spanne == spanne &&
      other.seitendifferenz == seitendifferenz;

  @override
  int get hashCode => Object.hash(
    mass,
    Object.hashAll(reihe),
    Object.hashAll(gegenreihe),
    Object.hashAll(messungen),
    veraenderung,
    vorigerTag,
    ersterTag,
    seitStart,
    proMonat,
    spanne,
    seitendifferenz,
  );
}

/// Die Lage des Verlaufsschirms, **vollständig über den sealed-Typ** — das
/// Gegenstück zu [UmfaengeLage] auf der Übersicht.
///
/// Zustand und Nutzlast werden getrennt gezogen: Ein
/// `is VerlaufGelesen ? … : null` ebnet beides in einem Schritt ein und
/// macht aus drei Fällen zwei Auskünfte; „lädt" sähe dann aus wie „nicht
/// lesbar", und beide sähen aus wie „nie gemessen". Genau das war in dieser
/// Scheibe schon zweimal das Loch (#489).
enum VerlaufLage {
  /// Es wird gelesen. Hier steht **nie** eine Aussage über die Datenlage
  /// (`01`).
  laedt,

  /// Das Lesen ist gescheitert. Keine Aussage über die Datenlage — und
  /// keine über einen laufenden Versuch.
  unlesbar,

  /// Gelesen. Erst hier darf dastehen, was gemessen ist und was nicht.
  gelesen,
}

VerlaufLage verlaufLageAus(UmfangsVerlauf zustand) => switch (zustand) {
  VerlaufLaedt() => VerlaufLage.laedt,
  VerlaufUnlesbar() => VerlaufLage.unlesbar,
  VerlaufGelesen() => VerlaufLage.gelesen,
};

/// Die Nutzlast, oder `null` — über denselben `switch`, nicht über einen
/// `is`-Test daneben.
VerlaufGelesen? verlaufWerte(UmfangsVerlauf zustand) => switch (zustand) {
  final VerlaufGelesen gelesen => gelesen,
  VerlaufLaedt() || VerlaufUnlesbar() => null,
};

/// Der Verlauf **eines** Maßes, einmal gerechnet und gehalten.
///
/// Eine Familie und nicht fünfzehn Kopien: Den Schirm gibt es fünfzehnmal,
/// die Rechnung einmal.
final umfangsVerlaufProvider = Provider.family<UmfangsVerlauf, Umfang>((
  ref,
  mass,
) {
  final lauf = ref.watch(umfaengeMessungenProvider);
  if (lauf.hasValue) return _verlaufAus(mass, lauf.value!);
  if (lauf.hasError) return const VerlaufUnlesbar();
  return const VerlaufLaedt();
});

VerlaufGelesen _verlaufAus(Umfang mass, List<Umfangsmessung> messungen) {
  // Aufsteigend für Reihe und Rechnungen, absteigend für die Liste.
  final aufsteigend = [...messungen]
    ..sort((eine, andere) => eine.zeitpunkt.compareTo(andere.zeitpunkt));

  List<Verlaufspunkt> reiheVon(Umfang gesucht) => [
    for (final messung in aufsteigend)
      if (messung.werte[gesucht] case final wert?)
        (tag: messung.zeitpunkt, wert: wert),
  ];

  final reihe = reiheVon(mass);
  final partner = mass.partner;
  final gegenreihe = partner == null
      ? const <Verlaufspunkt>[]
      : reiheVon(partner);

  return VerlaufGelesen(
    mass: mass,
    reihe: List.unmodifiable(reihe),
    gegenreihe: List.unmodifiable(gegenreihe),
    messungen: List.unmodifiable([
      for (final punkt in reihe.reversed)
        (tag: BerlinCalendar.dayKey(punkt.tag), wert: punkt.wert),
    ]),
    veraenderung: UmfangsFortschritt.veraenderung(mass, messungen),
    vorigerTag: reihe.length < 2
        ? null
        : BerlinCalendar.dayKey(reihe[reihe.length - 2].tag),
    ersterTag: reihe.isEmpty ? null : BerlinCalendar.dayKey(reihe.first.tag),
    seitStart: UmfangsFortschritt.seitStart(mass, messungen),
    proMonat: UmfangsFortschritt.proMonat(mass, messungen),
    spanne: UmfangsFortschritt.spanne(mass, messungen),
    seitendifferenz: UmfangsFortschritt.seitendifferenz(mass, messungen),
  );
}
