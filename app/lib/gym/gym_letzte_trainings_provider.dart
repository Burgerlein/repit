// Was der Schirm „Letzte Trainings" (#79) abliest: die zwölf neuesten
// Sitzungen und die beiden Kennzahlen über vierzehn Tage.
//
// **Kein `Messwert<T>`** (`CLAUDE.md`): Die Trainings sind Tims eigene Daten,
// es gibt keinen Lauf, der leer ausgehen könnte. Aber auch hier gilt: „wird
// gerade gelesen" darf nicht wie „nichts da" aussehen — das trägt
// [GymLetzteTrainings.laedt], nach dem Muster von `GymTag.laedt`.
//
// **Gelesen wird einmal je Änderung der Ablage**, nicht je Bild und nicht je
// Tipp (Hausregel 2, Fehler `03`): [gymSitzungenProvider] liest alle
// Sitzungen, [gymLetzteTrainingsProvider] rechnet daraus einmal Karten und
// Kennzahlen und **hält** sie. Eine zweite Abfrage gibt es bewusst nicht —
// sie bräuchte ihre eigene Invalidierung (siehe dort). **Gefiltert wird hier
// in Dart, nicht in SQL**, und das ist Absicht (Spec Abschnitt 4,
// Entscheidung 6): Die Kennzahlen und die Karten stammen aus **der einen**
// Liste, die der Steigerungsvorschlag ohnehin hält. Wie weit das trägt, ist
// zu messen (Spec Abschnitt 12), nicht zu raten.
//
// **Keine Texte** — die stehen in `gym_verlauf_texte.dart`.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart' show heutigerTagProvider;
import 'gym_verlauf_provider.dart';

/// Wie viele Karten der Verlauf höchstens zeigt (SPEC 4.4: „Letzte 12
/// Trainings").
const int gymVerlaufKartenMax = 12;

/// Wie viele Berliner Kalendertage die Kennzahlen umfassen — heute und die
/// dreizehn davor. **Die Beschriftung gilt**, nicht Swifts Rechnung
/// `heute − 14 Tage`, die fünfzehn Tage zählte (Spec Abschnitt 5).
const int gymKennzahlenTage = 14;

/// Karten und Kennzahlen des Verlaufs.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`); die
/// Karten werden inhaltlich verglichen, so wie `GymVerlauf` es vormacht.
@immutable
class GymLetzteTrainings {
  const GymLetzteTrainings({
    this.karten = const [],
    this.anzahl14Tage,
    this.volumen14TageKg,
  }) : laedt = false,
       fehlgeschlagen = false;

  /// Noch nicht gelesen, und es gab noch keine Antwort.
  const GymLetzteTrainings.laedt()
    : laedt = true,
      fehlgeschlagen = false,
      karten = const [],
      anzahl14Tage = null,
      volumen14TageKg = null;

  /// Das Lesen ist gescheitert **und nichts ist bekannt**. Nicht dasselbe
  /// wie „noch nichts da": Das Gerät ist Tims einzige Kopie, und wer „noch
  /// nichts da" sagt, obwohl nur das Lesen scheiterte, lässt ihn glauben,
  /// seine Trainings seien weg.
  const GymLetzteTrainings.fehlgeschlagen()
    : laedt = false,
      fehlgeschlagen = true,
      karten = const [],
      anzahl14Tage = null,
      volumen14TageKg = null;

  /// `true`, solange noch keine Antwort da ist. Nur maßgeblich, wo noch
  /// nichts dasteht: Ein Stand, der schon gelesen war, bleibt stehen, auch
  /// während neu gelesen wird (`CLAUDE.md`: der Platzhalter gehört allein
  /// in den Ladezustand).
  final bool laedt;

  /// Siehe [GymLetzteTrainings.fehlgeschlagen].
  final bool fehlgeschlagen;

  /// Höchstens [gymVerlaufKartenMax] Sitzungen, neueste zuerst. Leer, wenn
  /// nichts bekannt ist oder nichts da ist — unterscheiden lassen sie sich
  /// über [laedt] und [fehlgeschlagen].
  final List<ImportedSession> karten;

  /// Die Trainings der letzten vierzehn Berliner Kalendertage.
  ///
  /// **`null`, solange kein Stand bekannt ist oder noch nie ein Training
  /// eingetragen wurde** — nicht `0`: Ein Ring auf 0 behauptet „nichts
  /// getan". Gibt es Trainings, aber keines im Fenster, ist es `0`: eine
  /// wahre Auskunft über Tims eigene Daten, kein fehlender Wert.
  final int? anzahl14Tage;

  /// Die Summe von `ImportedSession.volumeKg` über dieselben Sitzungen, mit
  /// derselben Bedingung wie [anzahl14Tage]. Eine Schätzung, keine Messung:
  /// unterstützte Sätze tragen nichts bei.
  final double? volumen14TageKg;

  /// Ob der Stand belastbar ist.
  bool get bekannt => !laedt && !fehlgeschlagen;

  /// Ob bekannt ist, dass es keine Trainings gibt.
  bool get bekanntLeer => bekannt && karten.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is GymLetzteTrainings &&
      other.laedt == laedt &&
      other.fehlgeschlagen == fehlgeschlagen &&
      other.anzahl14Tage == anzahl14Tage &&
      other.volumen14TageKg == volumen14TageKg &&
      _gleicheKarten(other.karten, karten);

  @override
  int get hashCode => Object.hash(
    laedt,
    fehlgeschlagen,
    anzahl14Tage,
    volumen14TageKg,
    Object.hashAll(karten),
  );

  @override
  String toString() =>
      'GymLetzteTrainings(laedt: $laedt, fehlgeschlagen: $fehlgeschlagen, '
      '${karten.length} Karten, $anzahl14Tage Trainings, '
      '$volumen14TageKg kg)';
}

/// Karten und Kennzahlen, **gehalten** (Hausregel 2) und ohne `AsyncValue`
/// für die Ansicht (Hausregel 1).
///
/// Hängt an [gymSitzungenProvider] und [heutigerTagProvider] — dem Berliner
/// Tagesbeginn, der sich nur beim Kalendertagswechsel ändert. Ein
/// `DateTime.now()` an dieser Stelle wäre ungleich sich selbst bei jedem
/// Bild.
///
/// **Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg:**
/// [GymLetzteTrainings.fehlgeschlagen] gilt nur, wenn nichts
/// zwischengespeichert ist; sonst bleibt der letzte Stand stehen — `.value`
/// des `FutureProvider` liefert den vorigen Wert auch im Fehlerfall.
final gymLetzteTrainingsProvider = Provider<GymLetzteTrainings>((ref) {
  final sitzungen = ref.watch(gymSitzungenProvider);
  final heute = ref.watch(heutigerTagProvider);

  final liste = sitzungen.value;
  if (liste == null) {
    return sitzungen.hasError
        ? const GymLetzteTrainings.fehlgeschlagen()
        : const GymLetzteTrainings.laedt();
  }
  return _rechne(liste, heute: heute);
});

/// Die Rechnung hinter [gymLetzteTrainingsProvider].
///
/// [sitzungen] liegt **neueste zuerst** (Reihenfolge von
/// `GymRepository.sitzungen`). Jede Tageszuordnung läuft über
/// `BerlinCalendar.dayKey`: 23:30 UTC am 23.02. ist 00:30 Berliner Zeit am
/// 24.02.
GymLetzteTrainings _rechne(
  List<ImportedSession> sitzungen, {
  required DateTime heute,
}) {
  final karten = sitzungen.length <= gymVerlaufKartenMax
      ? sitzungen
      : sitzungen.sublist(0, gymVerlaufKartenMax);
  // Noch nie ein Training: keine Zahl, nicht `0`.
  if (sitzungen.isEmpty) return const GymLetzteTrainings();

  // Heute und die dreizehn Tage davor, einschließlich. Sitzungen **nach**
  // heute sind keine „letzten" und zählen nicht — als Karte stehen sie
  // trotzdem da.
  final bis = BerlinCalendar.dayKey(heute);
  final von = BerlinCalendar.dayKey(
    BerlinCalendar.addDays(heute, 1 - gymKennzahlenTage),
  );
  var anzahl = 0;
  var volumen = 0.0;
  for (final sitzung in sitzungen) {
    final tag = BerlinCalendar.dayKey(sitzung.date);
    // ISO-Tagesstrings: lexikografisch richtig verglichen.
    if (tag.compareTo(von) >= 0 && tag.compareTo(bis) <= 0) {
      anzahl++;
      volumen += sitzung.volumeKg;
    }
  }
  return GymLetzteTrainings(
    karten: karten,
    anzahl14Tage: anzahl,
    volumen14TageKg: volumen,
  );
}

bool _gleicheKarten(List<ImportedSession> a, List<ImportedSession> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
