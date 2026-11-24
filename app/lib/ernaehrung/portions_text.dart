// Die **Texte rund um eine Portion** (#398, unter #325): die Beschriftung
// eines Knopfs, die Rechenzeile unter der Wahl und eine gebuchte Portion
// als Text (V9).
//
// API und Vertrag sind durch
// `app/test/ernaehrung/portions_formular_test.dart` vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Die Wörter stehen hier, nicht im Kern.** Der Kern rechnet die Anzahl
// (`anzahlAus`), die App schreibt sie hin.
//
// Gramm stehen mit höchstens einer Nachkommastelle da, die Anzahl mit
// höchstens zwei, jeweils ohne nachgehängte Null und in deutscher
// Schreibweise über [formatNumber]. So verschwindet auch das
// Rechenrauschen: 3 × 5,9 ist im Rechner 17,700000000000003 und steht
// hier als „17,7".
import 'package:trainings_core/trainings_core.dart';

import '../data/portion.dart';
import '../design/zahlen.dart';

/// Die Beschriftung eines Knopfs: „Bon (5,9 g)", bei Flüssigem
/// „Portion (250 ml)".
String portionsKnopf(Portion p, {required bool fluessig}) =>
    '${p.name} (${_menge(p.mengeG, fluessig)})';

/// Die Zeile unter einer gewählten Portion: „2 × 5,9 g = 11,8 g"
/// (Spec, V8 a).
String portionsRechnung({
  required double anzahl,
  required double portionG,
  required bool fluessig,
}) =>
    '${_anzahl(anzahl)} × ${_menge(portionG, fluessig)} = '
    '${_menge(anzahl * portionG, fluessig)}';

/// Eine gebuchte Portion als Text: „2 Bon (11,8 g)" — Anzahl ohne „×",
/// Name, Menge in Klammern (V9).
///
/// Die Anzahl ist `mengeG / portionG`, auf zwei Stellen gerundet
/// ([anzahlAus]); der Eintrag trägt keine eigene Anzahl.
///
/// [fluessig] schreibt „ml" statt „g" — „2 Glas (500 ml)". **Vorgabe des
/// Koordinators**, nicht Tims Entscheidung: Plan und Test kennen den
/// Parameter nicht, ohne ihn stünde ein gebuchtes Getränk aber in Gramm
/// da.
///
/// Ohne Portionsgramm größer 0 gibt es keine Anzahl; dann steht nur Name
/// und Menge da, statt durch null zu teilen.
String gebuchtePortion({
  required double mengeG,
  required String name,
  required double portionG,
  bool fluessig = false,
}) {
  final menge = _menge(mengeG, fluessig);
  if (portionG <= 0) return '$name ($menge)';
  final anzahl = anzahlAus(mengeG: mengeG, portionG: portionG);
  return '${_anzahl(anzahl)} $name ($menge)';
}

/// Eine Menge mit Einheit, wie sie die Zeile unter der Wahl ohne Portion
/// sagt: „100 g", „11,8 g", „250 ml" (Spec, V8 e).
String portionsMenge(double wert, {required bool fluessig}) =>
    _menge(wert, fluessig);

/// Eine Anzahl, wie sie im Vorlesetext steht: „2", „0,5".
String portionsAnzahl(double wert) => _anzahl(wert);

/// Eine Menge mit Einheit, höchstens eine Nachkommastelle.
String _menge(double wert, bool fluessig) =>
    '${_ohneNull(formatNumber(wert, nachkommastellen: 1))} '
    '${fluessig ? 'ml' : 'g'}';

/// Eine Anzahl, höchstens zwei Nachkommastellen.
String _anzahl(double wert) =>
    _ohneNull(formatNumber(wert, nachkommastellen: 2));

/// Nimmt nachgehängte Nullen und ein dann leeres Komma weg: „2,00" → „2",
/// „0,50" → „0,5". Der Tausenderpunkt steht vor dem Komma und bleibt.
String _ohneNull(String text) {
  if (!text.contains(',')) return text;
  var t = text;
  while (t.endsWith('0')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.endsWith(',')) t = t.substring(0, t.length - 1);
  return t;
}
