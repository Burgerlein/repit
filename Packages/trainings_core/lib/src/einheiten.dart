/// Haushaltsmaße in Gramm, unabhängig vom Lebensmittel.
///
/// „Stück" steht bewusst **nicht** darin: Eine Zwiebel ist kein Ei, ein
/// globaler Faktor wäre hier frei erfunden. Stückgewichte hängen am
/// Lebensmittel und kommen über den Parameter `portionen` von [inGramm].
const Map<String, double> haushaltsmasse = {
  'EL': 15,
  'TL': 5,
  'Prise': 0.5,
  'Tasse': 240,
  'Glas': 200,
};

/// Wie viel Gramm [menge] in [einheit] sind, gegeben die am Lebensmittel
/// hinterlegten [portionen].
///
/// `null` heißt „dafür gibt es keinen Faktor" — **nicht** `0`. `0` hieße
/// „wiegt nichts" und zöge sich durch jede Nährwertsumme; `null` sagt der
/// View, dass die Zutat zwar angelegt ist, ihre Nährwerte aber unbekannt
/// bleiben. Das ist ein gültiges Ergebnis, kein Fehler.
///
/// Die Reihenfolge der Quellen:
///
/// 1. **Die Tabelle des Lebensmittels sticht alles andere.** Ein
///    gestrichener Esslöffel Erdnussmus wiegt nicht 15 g; wer das am
///    Lebensmittel hinterlegt, meint es so.
/// 2. **`g` und `ml` sind der Maßstab selbst.** Ein Milliliter zählt 1:1
///    als Gramm. Das ist für Wasser richtig und für Öl falsch — aber es ist
///    die Annahme, die jede Nährwerttabelle trifft, und sie steht hier an
///    genau einer Stelle statt in jedem Rezept neu.
/// 3. **Die Haushaltsmaße** aus [haushaltsmasse].
double? inGramm(double menge, String einheit, Map<String, double> portionen) {
  final faktor = _grammJeEinheit(einheit, portionen);
  return faktor == null ? null : menge * faktor;
}

double? _grammJeEinheit(String einheit, Map<String, double> portionen) {
  final amLebensmittel = portionen[einheit];
  if (amLebensmittel != null) return amLebensmittel;
  if (einheit == 'g' || einheit == 'ml') return 1;
  return haushaltsmasse[einheit];
}

/// Eine Portionsgröße auf ein anzeigbares Maß runden (`docs/SPEC.md` 4.8:
/// „g/ml auf 5 bzw. 1 runden, Stück/EL/TL auf 0,5").
///
/// **Jede andere Einheit rundet ebenfalls auf 0,5** — Prise, Tasse, Glas
/// und jede selbst eingetippte („Bund"). Halbe Schritte sind das gröbste
/// Maß, das bei kleinen Zahlen noch etwas aussagt.
///
/// Gerundet wird kaufmännisch von der Null weg (`num.round()`), und es gibt
/// **keinen Boden**: 2 g runden auf 0 g. Das ist die Rundung der Anzeige,
/// nicht die Menge, mit der gerechnet wird — ein Boden behauptete eine
/// Zahl, die niemand eingegeben hat.
double rundePortion(double wert, String einheit) {
  final stufe = _rundungsstufe(einheit);
  return (wert / stufe).round() * stufe;
}

double _rundungsstufe(String einheit) => switch (einheit) {
  'g' => 5,
  'ml' => 1,
  _ => 0.5,
};
