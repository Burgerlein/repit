import 'berlin_calendar.dart';
import 'mahlzeit.dart';

/// Ob ein Esstag für die Serie zählt: sobald **mindestens eine** Mahlzeit
/// einen Eintrag hat, gleich welche, auch ein Snack (V1, Tim 05.11.2026).
bool vollstaendig(Set<Mahlzeit> mitEintrag) => mitEintrag.isNotEmpty;

/// Wie viele Esstage am Stück vollständig sind ([vollstaendig]).
///
/// - `heute` zählt rückwärts, angefangen beim [esstag], wenn er vollständig
///   ist, sonst beim Vortag. Ein noch leeres Heute bricht die Serie nicht,
///   es zählt nur nicht mit. Ein Tag, der in [mahlzeitenJeTag] fehlt oder
///   mit leerer Menge steht, ist nicht vollständig.
/// - `abMorgen` ist der Wert, den die Karte ab 04:00 zeigt, wenn die App
///   bis dahin nicht mehr läuft: `heute`, wenn der Esstag einen Eintrag hat,
///   sonst `0` — ein Tag ohne Eintrag ist um 04:00 abgeschlossen.
///
/// Tage **nach** dem Esstag spielen keine Rolle. Gezählt wird über den
/// Kalender (`BerlinCalendar.addDays`, `dayKey`), nie über Sekunden.
///
/// [esstag] ist ein ISO-Tag (`2026-10-23`), wie `esstag(…)` ihn liefert;
/// ein unlesbarer wirft `FormatException` — ein Programmierfehler, keine
/// Datenlage.
({int heute, int abMorgen}) serie({
  required Map<String, Set<Mahlzeit>> mahlzeitenJeTag,
  required String esstag,
}) {
  bool voll(String tag) => vollstaendig(mahlzeitenJeTag[tag] ?? const {});

  // 12:00 UTC liegt in Berlin immer auf demselben Kalendertag (13:00 oder
  // 14:00) — ein Zeitpunkt, an dem `BerlinCalendar` den Tag anfassen kann.
  final anker = DateTime.parse('${esstag}T12:00:00Z');
  String tagVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(anker, -tage));

  final heuteVoll = voll(esstag);
  var zurueck = heuteVoll ? 0 : 1;
  var anzahl = 0;
  // Endet spätestens nach `mahlzeitenJeTag.length` Schritten: Jeder
  // gezählte Tag ist ein eigener Schlüssel der Map.
  while (voll(tagVor(zurueck))) {
    anzahl++;
    zurueck++;
  }
  return (heute: anzahl, abMorgen: heuteVoll ? anzahl : 0);
}
