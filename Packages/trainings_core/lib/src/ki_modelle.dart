// Welche Gemini-Modelle die Foto-Schätzung anbietet und welches gilt
// (#334).
//
// Der Kern nimmt die **dekodierte** Liste aus `models.list`, nie
// JSON-Text. Ob ein Modell tatsächlich Bilder versteht, prüft hier niemand
// — das tut das Testbild beim Auswählen in der App.

/// Ein Modell, wie es im Auswahlblatt steht.
///
/// Werttyp mit [==] und [hashCode] über alle drei Felder (`CLAUDE.md`,
/// Fehler `03`).
class KiModell {
  const KiModell({
    required this.id,
    required this.anzeigeName,
    required this.vorschau,
  });

  /// Der Modellname **ohne** `models/`, etwa `gemini-3.6-flash`.
  final String id;

  /// `displayName` aus der Liste; fehlt der, die [id].
  final String anzeigeName;

  /// `-preview` oder `-exp` im Namen.
  final bool vorschau;

  @override
  bool operator ==(Object other) =>
      other is KiModell &&
      other.id == id &&
      other.anzeigeName == anzeigeName &&
      other.vorschau == vorschau;

  @override
  int get hashCode => Object.hash(id, anzeigeName, vorschau);

  @override
  String toString() =>
      'KiModell(id: $id, anzeigeName: $anzeigeName, vorschau: $vorschau)';
}

const String _praefix = 'models/';
const String _geminiPraefix = 'models/gemini-';

/// Bausteine im Namen, die ein Modell für die Foto-Schätzung ausschließen.
const List<String> _ausgeschlossen = [
  'image',
  'tts',
  'audio',
  'live',
  'embedding',
  'veo',
  'imagen',
  'aqa',
  'computer-use',
];

const List<String> _vorschauMerkmale = ['-preview', '-exp'];

/// Filtert und sortiert die Rohliste aus `models.list`.
///
/// **Drin** ist ein Eintrag, dessen `name` mit `models/gemini-` beginnt,
/// dessen `supportedGenerationMethods` `generateContent` enthält und
/// dessen Name keinen der Bausteine `image`, `tts`, `audio`, `live`,
/// `embedding`, `veo`, `imagen`, `aqa`, `computer-use` enthält.
///
/// - Ein Eintrag ohne `name` oder mit `name: null` wird übersprungen.
/// - Fehlt `supportedGenerationMethods`, ist das Modell draußen — ohne die
///   Angabe steht nicht fest, dass es `generateContent` kann.
/// - Ein Feld mit falschem Typ (`name` oder `displayName` kein Text,
///   `supportedGenerationMethods` keine Liste) wirft eine
///   [FormatException], wie überall im Kern.
///
/// **Reihenfolge:** stabile Modelle vor Vorschau-Modellen, innerhalb
/// dessen nach Name absteigend (als Zeichenfolge).
List<KiModell> fotoModelle(List<Map<String, Object?>> rohListe) {
  final ergebnis = <KiModell>[];
  for (final eintrag in rohListe) {
    final name = _textOderNull(eintrag, 'name');
    if (name == null || !name.startsWith(_geminiPraefix)) continue;
    if (_ausgeschlossen.any(name.contains)) continue;
    if (!_kannGenerateContent(eintrag)) continue;

    final id = name.substring(_praefix.length);
    ergebnis.add(
      KiModell(
        id: id,
        anzeigeName: _textOderNull(eintrag, 'displayName') ?? id,
        vorschau: _vorschauMerkmale.any(id.contains),
      ),
    );
  }
  ergebnis.sort((a, b) {
    if (a.vorschau != b.vorschau) return a.vorschau ? 1 : -1;
    return b.id.compareTo(a.id);
  });
  return ergebnis;
}

String? _textOderNull(Map<String, Object?> eintrag, String schluessel) {
  final wert = eintrag[schluessel];
  if (wert == null || wert is String) return wert as String?;
  throw FormatException(
    '$schluessel ist kein Text, sondern ${wert.runtimeType}',
    wert,
  );
}

bool _kannGenerateContent(Map<String, Object?> eintrag) {
  final methoden = eintrag['supportedGenerationMethods'];
  if (methoden == null) return false;
  if (methoden is! List) {
    throw FormatException(
      'supportedGenerationMethods ist keine Liste, sondern '
      '${methoden.runtimeType}',
      methoden,
    );
  }
  return methoden.contains('generateContent');
}

/// Welches Modell gilt.
///
/// 1. Steht [gemerkt] in [liste], gilt es — auch ein Vorschau-Modell:
///    „nie Voreinstellung" betrifft die Voreinstellung, nicht Tims Wahl.
/// 2. Sonst [voreinstellung], falls in [liste].
/// 3. Sonst das erste der übergebenen [liste] — sortiert wird hier nicht,
///    die Reihenfolge kommt aus [fotoModelle].
/// 4. Ist [liste] leer, gibt es kein Modell (`null`).
///
/// `gemerktFehlt` ist `true`, wenn ein Modell gemerkt war und nicht
/// angeboten wird — auch bei leerer Liste: Warum sie leer ist, weiß der
/// Kern nicht.
({KiModell? modell, bool gemerktFehlt}) loeseModell({
  required List<KiModell> liste,
  String? gemerkt,
  required String voreinstellung,
}) {
  if (gemerkt != null) {
    final treffer = _finde(liste, gemerkt);
    if (treffer != null) return (modell: treffer, gemerktFehlt: false);
  }
  final gemerktFehlt = gemerkt != null;
  final modell = _finde(liste, voreinstellung) ?? _erstesOderNull(liste);
  return (modell: modell, gemerktFehlt: gemerktFehlt);
}

KiModell? _finde(List<KiModell> liste, String id) {
  for (final modell in liste) {
    if (modell.id == id) return modell;
  }
  return null;
}

KiModell? _erstesOderNull(List<KiModell> liste) =>
    liste.isEmpty ? null : liste.first;
