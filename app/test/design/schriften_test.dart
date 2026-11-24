import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die SHA-256 der beiden gebündelten Phosphor-Schriftdateien fest.
///
/// **Warum das hier steht, nicht ein Pixel-Test:** `lib/design/symbole.dart`
/// baut `IconData`-Konstanten mit Codepoints, die von Hand aus
/// `phosphor_flutter` 2.1.0 abgeschrieben wurden (das Paket selbst lässt
/// sich gegen diese Flutter-Fassung nicht mehr übersetzen, siehe Kommentar
/// dort). Die Gefahr dabei: Tauscht jemand künftig die Schriftdatei aus
/// (neue Phosphor-Fassung, anderer Font-Build), können sich Codepoints
/// verschieben — ein Name zeigt dann still auf ein falsches oder leeres
/// Glyph, und kein Test schlägt an, weil `Symbole.tabelle` weiterhin
/// syntaktisch gültige `IconData`-Werte enthält.
///
/// Ein Pixel-Test (Rendern + Auszählen heller Pixel) wurde dafür probiert
/// und wieder verworfen: Schriftrasterung unterscheidet sich zwischen
/// Plattformen/Fassungen, `flutter test` ersetzt Schriften standardmäßig
/// durch eine interne Testschrift (erfordert `FontLoader`-Klimmzüge), und
/// ein Lauf über alle 20 Symbole blieb im eigenen Testlauf hängen — spröde,
/// für genau das, was hier geprüft werden soll.
///
/// Stattdessen: **statisch und deterministisch.** Dieser Test vergleicht nur
/// die Prüfsumme der Dateien. Er beweist nicht, dass die Codepoints heute
/// richtig sind (das wurde einmalig geprüft, siehe unten) — er schlägt
/// fehl, sobald sich die **Grundlage** dafür ändert, und genau das reicht:
/// Jede Änderung an den Dateien erzwingt eine bewusste Entscheidung statt
/// eines stillen Rückfalls.
///
/// **Einmalig geprüft (nicht Teil dieses Tests, da kein Dart-Werkzeug dafür
/// im Projekt steckt):** Mit `fontTools` (Python) wurde nachgesehen, dass
/// alle 20 Codepoints aus `Symbole.tabelle` in der `cmap`-Tabelle der
/// jeweiligen Datei vorkommen und auf eine Glyphe mit echten Konturen zeigen
/// (keine leere `.notdef`-Ersatzglyphe) — siehe `task-9-report.md` für das
/// Ergebnis. Ändert sich eine der beiden Prüfsummen unten, ist genau dieser
/// Abgleich gegen die neue Datei zu wiederholen, bevor man den neuen Hash
/// hier einträgt.
void main() {
  test('Phosphor-Regular.ttf ist unverändert (SHA-256)', () {
    final bytes = File('assets/fonts/Phosphor/Phosphor-Regular.ttf').readAsBytesSync();
    expect(
      sha256.convert(bytes).toString(),
      '06b91e022b7ee899a63efced879392a74f0bacbda54e4467e9f663220d173a10',
    );
  });

  test('Phosphor-Fill.ttf ist unverändert (SHA-256)', () {
    final bytes = File('assets/fonts/Phosphor/Phosphor-Fill.ttf').readAsBytesSync();
    expect(
      sha256.convert(bytes).toString(),
      'a53f5d2630cab5e3b7536ecb9d69d71519a2190298c22b1f8d770dd37bc2940a',
    );
  });
}
