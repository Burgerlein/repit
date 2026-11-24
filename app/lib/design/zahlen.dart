/// Deutsche Zahlenschreibweise (Komma statt Punkt, Punkt als
/// Tausendertrennzeichen) ohne Abhängigkeit von `intl`-Zahlensymbolen.
///
/// Reine Mechanik, kein Fachbegriff — deshalb nicht in `Format`, das laut
/// eigenem Kommentarkopf nur Datumsformate trägt.
String formatNumber(double wert, {int nachkommastellen = 0}) {
  final text = wert.toStringAsFixed(nachkommastellen);
  final teile = text.split('.');
  final negativ = teile[0].startsWith('-');
  final ziffern = negativ ? teile[0].substring(1) : teile[0];

  final gruppen = <String>[];
  for (var ende = ziffern.length; ende > 0; ende -= 3) {
    final start = ende - 3 < 0 ? 0 : ende - 3;
    gruppen.insert(0, ziffern.substring(start, ende));
  }

  final ganzzahl = '${negativ ? '-' : ''}${gruppen.join('.')}';
  if (teile.length == 1) return ganzzahl;
  return '$ganzzahl,${teile[1]}';
}
