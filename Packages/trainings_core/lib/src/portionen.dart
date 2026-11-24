// Die **Portionsregeln** (#325, Karte #394): welche Angaben von Open
// Food Facts eine Portion werden, was beim Öffnen des Buchungsblatts
// vorgewählt ist und wie die Anzahl rechnet.
//
// Spec: `docs/superpowers/specs/2026-11-05-portionen-design.md`. Die
// Entscheidungen 3, 4, 7, 10 und 11 sind Tims Entscheidungen vom
// 05.11.2026; V1, V2 und V7 hat der Planende formuliert, Tim hat sie am
// 05.11.2026 übernommen.
//
// API und Vertrag sind durch `test/portionen_test.dart` vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Keine Nutzertexte.** Der Kern liefert [OffPortionsArt.portion] und
// [OffPortionsArt.packung]; die Wörter „Portion" und „Packung" setzt die
// App.

/// Die Toleranz für „genau 100", „gleich der Packung" und „größer als die
/// Packung" (V2). OFF liefert gerechnete Zahlen, und `99.99999` ist
/// dieselbe Bezugsgröße wie `100`.
const double portionsToleranz = 0.01;

/// Die Bezugsgröße der Nährwerte. Eine Portion dieser Größe ist keine
/// Portion, sondern die Angabe „je 100 g" noch einmal (Entscheidung 3).
const double _bezugsgroesse = 100;

/// Welche der beiden OFF-Angaben eine [OffPortion] ist.
enum OffPortionsArt {
  /// Aus `serving_quantity`.
  portion,

  /// Aus `product_quantity`.
  packung,
}

/// Eine Portion, wie Open Food Facts sie liefert — Menge in der Einheit
/// des Lebensmittels (g oder ml).
final class OffPortion {
  const OffPortion({required this.art, required this.menge});

  final OffPortionsArt art;
  final double menge;

  @override
  bool operator ==(Object other) =>
      other is OffPortion && other.art == art && other.menge == menge;

  @override
  int get hashCode => Object.hash(art, menge);

  @override
  String toString() => 'OffPortion(art: ${art.name}, menge: $menge)';
}

/// Was [offPortionen] aus den vier OFF-Feldern macht.
final class OffPortionsAngaben {
  const OffPortionsAngaben({required this.fluessig, required this.portionen});

  /// Ob eine der beiden **rohen** Einheiten `ml` ist (Entscheidung 10) —
  /// auch dann, wenn die Angabe danach entfällt.
  final bool fluessig;

  /// Die übernommenen Portionen, aufsteigend nach Menge. Leer heißt
  /// „gefragt, keine".
  final List<OffPortion> portionen;

  @override
  bool operator ==(Object other) =>
      other is OffPortionsAngaben &&
      other.fluessig == fluessig &&
      _gleicheListen(other.portionen, portionen);

  @override
  int get hashCode => Object.hash(fluessig, Object.hashAll(portionen));

  @override
  String toString() =>
      'OffPortionsAngaben(fluessig: $fluessig, portionen: $portionen)';
}

/// Welche OFF-Angaben eine Portion werden.
///
/// - **Nur g oder ml** (Entscheidungen 3 und 4). Die Einheit wird
///   getrimmt und klein geschrieben; `kg`, `l`, `stück` oder keine
///   Einheit sind keine Angabe. Umgerechnet wird nicht.
/// - **Nur eine Menge größer 0** ist eine Angabe.
/// - **Die Portion entfällt bei genau 100** (Entscheidung 3, Toleranz
///   nach V2).
/// - **Verschiedene Einheiten bei Portion und Packung:** Die Portion
///   entfällt, die Packung bleibt (V1). Steht nur eine Angabe da, gilt
///   die Regel nicht.
/// - **Gleich der Packung oder größer:** Die Portion entfällt, die Packung
///   bleibt (Entscheidung 3, Toleranz nach V2).
/// - **[OffPortionsAngaben.fluessig]** hängt an der rohen Einheit, nicht
///   am Ergebnis (Entscheidung 10).
///
/// Ergebnis aufsteigend nach Menge: Bleiben beide, ist die Portion nach
/// den Regeln oben immer die kleinere.
OffPortionsAngaben offPortionen({
  double? portionMenge,
  String? portionEinheit,
  double? packungMenge,
  String? packungEinheit,
}) {
  final pEinheit = _einheit(portionEinheit);
  final pkEinheit = _einheit(packungEinheit);
  final fluessig = pEinheit == 'ml' || pkEinheit == 'ml';

  final packung = _gueltig(packungMenge, pkEinheit) ? packungMenge! : null;
  var portion = _gueltig(portionMenge, pEinheit) ? portionMenge! : null;

  if (portion != null && _ungefaehrGleich(portion, _bezugsgroesse)) {
    portion = null;
  }
  if (portion != null && packung != null) {
    final verschiedeneEinheiten = pEinheit != pkEinheit;
    final gleich = _ungefaehrGleich(portion, packung);
    final groesser = portion > packung + portionsToleranz;
    if (verschiedeneEinheiten || gleich || groesser) portion = null;
  }

  return OffPortionsAngaben(
    fluessig: fluessig,
    portionen: List.unmodifiable([
      if (portion != null)
        OffPortion(art: OffPortionsArt.portion, menge: portion),
      if (packung != null)
        OffPortion(art: OffPortionsArt.packung, menge: packung),
    ]),
  );
}

/// Die Einheit ohne Ränder und klein geschrieben — `null`, wenn leer.
String? _einheit(String? roh) {
  final e = roh?.trim().toLowerCase();
  return e == null || e.isEmpty ? null : e;
}

/// Eine Angabe zählt nur mit Menge größer 0 und Einheit g oder ml.
bool _gueltig(double? menge, String? einheit) =>
    menge != null &&
    menge.isFinite &&
    menge > 0 &&
    (einheit == 'g' || einheit == 'ml');

bool _ungefaehrGleich(double a, double b) => (a - b).abs() <= portionsToleranz;

/// Der jüngste Eintrag eines Lebensmittels, soweit die Vorwahl ihn
/// braucht — gelesen aus `eintraege` (Spec, „Vorwahl").
final class LetzteBuchung {
  const LetzteBuchung({this.mengeG, this.portionId, this.portionG});

  /// Die gebuchte Menge in g bzw. ml.
  final double? mengeG;

  /// Die Portion, mit der gebucht wurde — `null`, wenn ohne Portion oder
  /// wenn die Portion beim Buchen keine Zeile hatte.
  final int? portionId;

  /// Die Gramm der Portion zum Zeitpunkt des Buchens (Schnappschuss).
  final double? portionG;

  @override
  bool operator ==(Object other) =>
      other is LetzteBuchung &&
      other.mengeG == mengeG &&
      other.portionId == portionId &&
      other.portionG == portionG;

  @override
  int get hashCode => Object.hash(mengeG, portionId, portionG);

  @override
  String toString() =>
      'LetzteBuchung(mengeG: $mengeG, portionId: $portionId, '
      'portionG: $portionG)';
}

/// Was beim Öffnen des Buchungsblatts gewählt ist.
sealed class PortionsVorwahl {
  const PortionsVorwahl();
}

/// „g" mit dieser Menge.
final class VorwahlGramm extends PortionsVorwahl {
  const VorwahlGramm(this.menge);

  final double menge;

  @override
  bool operator ==(Object other) =>
      other is VorwahlGramm && other.menge == menge;

  @override
  int get hashCode => menge.hashCode;

  @override
  String toString() => 'VorwahlGramm($menge)';
}

/// Eine Portion mit dieser Anzahl.
final class VorwahlPortion extends PortionsVorwahl {
  const VorwahlPortion(this.portionId, this.anzahl);

  final int portionId;
  final double anzahl;

  @override
  bool operator ==(Object other) =>
      other is VorwahlPortion &&
      other.portionId == portionId &&
      other.anzahl == anzahl;

  @override
  int get hashCode => Object.hash(portionId, anzahl);

  @override
  String toString() => 'VorwahlPortion($portionId, $anzahl)';
}

/// Die Menge, die ohne jeden Eintrag vorgewählt ist.
const double _vorgabeGramm = 100;

/// Was vorgewählt ist (Spec, „Vorwahl"; Entscheidung 7).
///
/// - Ohne Eintrag: „g" mit 100.
/// - Gibt es die Portion des jüngsten Eintrags noch (in
///   [vorhandenePortionen]) und hat sein Schnappschuss Gramm größer 0:
///   diese Portion mit der Anzahl [anzahlAus] (V7).
/// - Sonst: „g" mit der Menge des Eintrags.
PortionsVorwahl portionsVorwahl({
  LetzteBuchung? letzte,
  required Set<int> vorhandenePortionen,
}) {
  final mengeG = letzte?.mengeG;
  if (letzte == null || mengeG == null) {
    return const VorwahlGramm(_vorgabeGramm);
  }
  final id = letzte.portionId;
  final portionG = letzte.portionG;
  if (id != null &&
      portionG != null &&
      portionG > 0 &&
      vorhandenePortionen.contains(id)) {
    return VorwahlPortion(id, anzahlAus(mengeG: mengeG, portionG: portionG));
  }
  return VorwahlGramm(mengeG);
}

/// Die Anzahl aus Menge und Portionsgramm, auf zwei Nachkommastellen
/// gerundet (V7) — `11,8 / 5,9` ist `2`, nicht `2.0000000000000004`.
/// [portionG] muss größer 0 sein; das prüft der Aufrufer, wie
/// [portionsVorwahl].
double anzahlAus({required double mengeG, required double portionG}) =>
    _aufHundertstel(mengeG / portionG);

/// + addiert 1 (Entscheidung 11, V7).
double anzahlPlus(double anzahl) => _aufHundertstel(anzahl + 1);

/// − zieht 1 ab, aber nie unter 1 (V7). Bei einer Anzahl von 1 oder
/// kleiner ist − gesperrt: `null`.
double? anzahlMinus(double anzahl) {
  if (anzahl <= 1) return null;
  final weniger = _aufHundertstel(anzahl - 1);
  return weniger < 1 ? 1 : weniger;
}

double _aufHundertstel(double wert) => (wert * 100).round() / 100;

bool _gleicheListen<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
