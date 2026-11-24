// Welche Nacht der Schlaf-Schirm zeigt (#92) — die gewählte Nacht gegen
// die geladene Reihe aufgelöst, ihre beiden Nachbarn, die Richtungen der
// Blätterleiste und der Ansichtszustand, der die Wahl hält.
//
// **Die reinen Funktionen und der Notifier stehen zusammen**, weil
// `blaettere` genau sie aufruft: Pfeil und Wischgeste (#127) rechnen die
// Nachbarschaft nicht selbst nach, sie lesen dieselbe Funktion. Getrennt
// lägen die Rechnung und ihr einziger Aufrufer in zwei Dateien.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'schlaf_reihe.dart';
import 'schlaf_von_hand.dart';

/// Die beiden Richtungen der Blätterleiste.
///
/// Als Aufzählung und nicht als zwei Methoden, **weil #127 eine Wischgeste
/// nachreicht**: Die Geste ruft dieselbe Methode wie der Pfeil.
enum SchlafBlaettern { frueher, spaeter }

/// Die gezeigte Nacht, aufgelöst gegen die geladene Reihe.
///
/// Ohne Auswahl die letzte. Fällt die gewählte Nacht nach einem Neuladen
/// weg, steht ebenfalls die letzte da — nicht eine leere Karte.
SleepNight? geloesteNacht({
  required List<SleepNight> naechte,
  required DateTime? gewaehlt,
}) {
  if (naechte.isEmpty) return null;
  final sortiert = schlafChronologisch(naechte);
  if (gewaehlt != null) {
    for (final nacht in sortiert) {
      if (nacht.date == gewaehlt) return nacht;
    }
  }
  return sortiert.last;
}

/// Der früheste Tag, den der Schirm zeigen kann (#177).
///
/// **Der Anfang des Rechenfensters**, denn so weit hat die App gelesen:
/// Jeder Tag darin ist angesehen worden, auch wenn keine Nacht herauskam —
/// „nachgesehen und nichts gefunden" ist eine Aussage, „nie nachgesehen"
/// ist keine. Was davor liegt, darf deshalb nicht als leerer Tag dastehen.
///
/// Zwei Dinge können den Anfang nach hinten schieben, und beide sind
/// Tatsachen, keine Annahmen:
///
/// - **eine eigene Eingabe**, denn die kennt kein Fenster (Spec 5.6a) und
///   ihr Tag muss erreichbar bleiben, sonst sieht man den Eintrag nie
///   wieder;
/// - **eine gemessene Nacht**, falls der Cache eine ältere hält als das
///   heutige Fenster — eine Nacht, die oben stehen kann, muss auch
///   anwählbar sein.
///
/// Nie später als [heute]: Ein Fenster, das in der Zukunft anfinge, ließe
/// den Schirm auf keinen Tag mehr zeigen.
DateTime fruehesterSchlaftag({
  required DateTime fensterBeginn,
  required DateTime heute,
  List<SleepNight> naechte = const [],
  List<SchlafEintrag> eintraege = const [],
}) {
  var frueheste = BerlinCalendar.startOfDay(fensterBeginn);
  for (final nacht in naechte) {
    final tag = BerlinCalendar.startOfDay(nacht.date);
    if (tag.isBefore(frueheste)) frueheste = tag;
  }
  for (final eintrag in eintraege) {
    final tag = BerlinCalendar.startOfDay(datumAusTag(eintrag.tag));
    if (tag.isBefore(frueheste)) frueheste = tag;
  }
  final grenze = BerlinCalendar.startOfDay(heute);
  return frueheste.isAfter(grenze) ? grenze : frueheste;
}

/// Die Nachbarn eines **Kalendertags** (#177); `null` heißt „am Rand".
///
/// **Geblättert wird von Tag zu Tag, nicht von Nacht zu Nacht.** Steht man
/// auf einem leeren Tag, ist „die Nacht davor" nicht bestimmt, „der Tag
/// davor" schon; und in der Leiste steht ein Datum, also dürfen die Pfeile
/// keine Daten überspringen. Vor allem aber gibt es damit wieder **eine**
/// Menge statt zweier — an genau dieser Spaltung ist am 29.10.2026 schon
/// einmal etwas zerbrochen (`4a51775`): Der Pfeil wies auf einen Tag und
/// das Drücken führte an ihm vorbei.
///
/// Nach vorn ist [heute] die Grenze. Eine Nacht, die noch nicht war, trägt
/// man nicht ein.
({DateTime? frueher, DateTime? spaeter}) schlafTagNachbarn({
  required DateTime tag,
  required DateTime fruehesterTag,
  required DateTime heute,
}) {
  final hier = BerlinCalendar.startOfDay(tag);
  final anfang = BerlinCalendar.startOfDay(fruehesterTag);
  final ende = BerlinCalendar.startOfDay(heute);
  return (
    frueher: hier.isAfter(anfang) ? BerlinCalendar.addDays(hier, -1) : null,
    spaeter: hier.isBefore(ende) ? BerlinCalendar.addDays(hier, 1) : null,
  );
}

/// Die Nachbarn der gezeigten Nacht; `null` heißt „am Rand" — der Pfeil
/// wird blass und es passiert nichts, statt ins Leere zu laufen.
///
/// **Seit #177 nicht mehr das, woran die Blätterleiste hängt** — die
/// rechnet über [schlafTagNachbarn]. Diese Funktion bleibt, weil der
/// Kalender und die Statistik weiter wissen müssen, welche *Nächte*
/// benachbart sind, und weil zwei Rechnungen besser sind als eine, die
/// beides halb kann.
({DateTime? frueher, DateTime? spaeter}) schlafNachbarn({
  required List<SleepNight> naechte,
  required DateTime? gewaehlt,
}) {
  final gezeigt = geloesteNacht(naechte: naechte, gewaehlt: gewaehlt);
  if (gezeigt == null) return (frueher: null, spaeter: null);

  final sortiert = schlafChronologisch(naechte);
  final index = sortiert.indexWhere((nacht) => nacht.date == gezeigt.date);
  return (
    frueher: index > 0 ? sortiert[index - 1].date : null,
    spaeter: index >= 0 && index < sortiert.length - 1
        ? sortiert[index + 1].date
        : null,
  );
}

/// **Ansichtszustand**: `autoDispose`, überlebt das Verlassen des Schirms
/// nicht (Entscheidung 3 vom 13.10.2026). Sonst landete man beim
/// Wiederkommen unerklärt auf dem 11. Oktober.
///
/// Ein `Notifier` mit [waehle]/[blaettere] statt eines nackten Feldes, weil
/// #127 eine Wischgeste nachreicht: Die Geste ruft dieselbe Methode wie der
/// Pfeil, ohne dass jemand den Zustand dafür anfasst.
final schlafAuswahlProvider =
    NotifierProvider.autoDispose<SchlafAuswahlNotifier, DateTime?>(
      SchlafAuswahlNotifier.new,
    );

/// `null` heißt „die letzte Nacht".
class SchlafAuswahlNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void waehle(DateTime? datum) => state = datum;

  /// Eine Nacht vor oder zurück. Am Rand passiert **nichts** — es stößt an,
  /// statt ins Leere zu laufen.
  ///
  /// Gelesen wird [sleepProvider], nicht [schlafProvider]: Sonst gäbe es
  /// einen Kreis, denn der Zustand beobachtet die Auswahl. Die Reihe der
  /// Nächte reicht, und die Nachbarschaft rechnet dieselbe reine Funktion
  /// ([schlafNachbarn]).
  ///
  /// **Über dieselbe Menge wie der Zustand** (#177): die Kalendertage
  /// zwischen [fruehesterSchlaftag] und heute. Pfeil und Wischgeste hängen
  /// an `SchlafDaten.frueher`/`.spaeter`, und die rechnen seit #177 über
  /// [schlafTagNachbarn]; rechnete diese Methode über eine andere Menge,
  /// wiese der Pfeil auf einen Tag und das Drücken führte an ihm vorbei.
  /// Genau das ist am 29.10.2026 passiert (`4a51775`), damals zwischen der
  /// rohen Nächteliste und `naechteMitEintraegen`.
  ///
  /// **Angefasst wird nur ein Tag, der einen Anker hat.** Ohne gewählten
  /// Tag und ohne geladene Nacht gibt es keinen Ausgangspunkt, und dann
  /// passiert nichts — ein Pfeil, der aus dem Nichts heraus irgendwohin
  /// springt, wäre schlimmer als ein blasser.
  ///
  /// Keiner der gelesenen Provider beobachtet die Auswahl, der Kreis zu
  /// [schlafProvider] bleibt also aus. `?? const []`, wie überall, wo ein
  /// `AsyncValue` in die Widget-Schicht stößt.
  void blaettere(SchlafBlaettern richtung) {
    final naechte = ref.read(sleepProvider).value;
    final geladen = naechte is Bekannt<List<SleepNight>>
        ? naechte.wert
        : const <SleepNight>[];
    final eintraege = ref.read(schlafEintraegeProvider).value ?? const [];

    final heute = BerlinCalendar.startOfDay(ref.read(clockProvider)());
    final hier =
        state ??
        geloesteNacht(
          naechte: naechteMitEintraegen(
            gemessen: geladen,
            eintraege: eintraege,
          ),
          gewaehlt: null,
        )?.date;
    if (hier == null) return;

    final nachbarn = schlafTagNachbarn(
      tag: hier,
      fruehesterTag: fruehesterSchlaftag(
        fensterBeginn: ref.read(rechenfensterProvider).start ?? heute,
        heute: heute,
        naechte: geladen,
        eintraege: eintraege,
      ),
      heute: heute,
    );
    final ziel = switch (richtung) {
      SchlafBlaettern.frueher => nachbarn.frueher,
      SchlafBlaettern.spaeter => nachbarn.spaeter,
    };
    if (ziel == null) return;
    state = ziel;
  }
}
