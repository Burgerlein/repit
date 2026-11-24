import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/palette.dart';

/// **Die Palette kommt aus `docs/screens/tokens.css`, nicht aus
/// `Palette.swift`.** Tims Entscheidung vom 27.10.2026, nachdem er den
/// gebauten Erholung-Schirm gegen das Entwurfsboard gehalten hat — und zwar
/// für die **ganze App**, nicht nur für diesen einen Schirm.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum das überhaupt ein Test ist
///
/// „Dunkelmodus sieht gut aus" ist Geschmack und gehört nicht in einen
/// Widget-Test. Dies hier ist etwas anderes: eine **Zusage über eine
/// Quelle**. `tokens.css` sagt seit dem 27.10.2026 im eigenen Dateikopf,
/// dass die Richtung des Abgleichs sich umgedreht hat — das Board ist die
/// Vorlage, die App wird nachgezogen. Eine Farbe, die in `palette.dart`
/// steht und in `tokens.css` fehlt (oder dort anders steht), ist ab jetzt
/// ein Fehler in der App. Genau das prüft diese Datei, Token für Token.
///
/// ## Die Werte
///
/// Wörtlich aus `docs/screens/tokens.css`, Stand 27.10.2026: der
/// `:root`-Block ist hell, der `[data-theme="dark"]`-Block ist dunkel.
/// Jeder Eintrag steht hier **als Zahl**, nicht als Verweis — ein Test, der
/// die Datei zur Laufzeit parst, prüfte nur „beide sagen dasselbe", nicht
/// „beide sagen das Richtige", und wäre nach einem Tippfehler im Board
/// weiterhin grün.
///
/// **Hell ändert sich an genau einer Stelle:** `--awake` ist `#E87359`, die
/// App trug `#E8735A` (letzte Ziffer). Der Wert kam aus
/// `docs/prototype/erholung-alles.html`; das Board hat ihn korrigiert, und
/// `wach_farbe_test.dart` ist mitgezogen. Alle übrigen hellen Werte stimmten
/// schon überein — sie stehen hier trotzdem vollständig, weil eine
/// Teilprüfung die Zusage nur halb einlöst.
///
/// **Dunkel ändert sich überall**, am deutlichsten:
/// `--bg` von Anthrazit auf echtes Schwarz (auf OLED sind die Pixel aus),
/// `--river`/`--deep` von gedecktem Blau auf Hellblau.
///
/// ## Neu: `Palette.low`
///
/// Das Board kennt `--low` (Gelb der Muskelkarte für „etwas zu wenig"),
/// `palette.dart` nicht. Nach der Regel aus `tokens.css` („eine Farbe, die
/// in palette.dart auftaucht und hier fehlt, ist ein Fehler in der App")
/// gilt auch die Gegenrichtung: Die App soll die Palette vollständig
/// tragen, nicht nur ihren heute benutzten Ausschnitt. Der Erholung-Schirm
/// braucht den Ton ab sofort selbst — er ist das Orange der Ampel in den
/// Verlaufszeilen (`erholung_verlaufston_test.dart`).
///
/// ## Was hier absichtlich **nicht** steht
///
/// - `--chrome`, `--sep`, `--fill`, `--shadow-*`: abgeleitete Werte mit
///   Deckkraft. Die App baut sie dort, wo sie gebraucht werden
///   (`Glas`, `InsetCard`), und nicht als Palette-Einträge; sie hier
///   einzufordern hieße, eine Umsetzung zu verlangen, die niemand
///   entschieden hat.
/// - Schrift, Radien, Abstände. Stehen in `tokens.css` mit, gehören aber zu
///   `Typografie` und den Bausteinen.
/// - Wie eine Farbe aussieht. Kein Pixelvergleich und kein Kontrastmaß —
///   geprüft wird, dass die App den Wert aus dem Board trägt.
void main() {
  /// Token-Name im Board → (hell, dunkel), beide aus `tokens.css`.
  const ausDemBoard = <String, (int, int)>{
    'bg': (0xFFEDF1EF, 0xFF000000),
    'surface': (0xFFF8FAF9, 0xFF090D10),
    'ink': (0xFF15242A, 0xFFF2F6F7),
    'muted': (0xFF5B6B70, 0xFF8A9AA1),
    'line': (0xFFCBD5D3, 0xFF222C31),
    'river': (0xFF2B6A8A, 0xFF5CD2FF),
    'river2': (0xFF8DB4C6, 0xFF1E4E66),
    'deep': (0xFF173F54, 0xFF9FE4FF),
    'bib': (0xFFF2C230, 0xFFFFD84D),
    'rest': (0xFFC3CCCA, 0xFF39454A),
    'pre': (0xFFDCE3E1, 0xFF161E22),
    'warn': (0xFFA33B3B, 0xFFFF7E7E),
    'ok': (0xFF2F7A4F, 0xFF4FE0A0),
    'iron': (0xFF6B5B95, 0xFFB79DFF),
    'summer': (0xFF6E9F5A, 0xFF9BE87A),
    'low': (0xFFE0A82E, 0xFFFFC43D),
    'awake': (0xFFE87359, 0xFFFF8E72),
    'iron-dark': (0xFF4B3F6D, 0xFF2A2148),
    'river-dark': (0xFF173F54, 0xFF06303F),
  };

  /// Board-Name → Eintrag in `Palette`. Die Namen weichen an drei Stellen
  /// ab, und das ist Absicht: `--awake` heißt in der App `wach` (deutscher
  /// Fachbegriff, siehe `wach_farbe_test.dart`), die beiden
  /// `-dark`-Varianten tragen in Dart die übliche Schreibweise.
  final inDerApp = <String, CupertinoDynamicColor>{
    'bg': Palette.bg,
    'surface': Palette.surface,
    'ink': Palette.ink,
    'muted': Palette.muted,
    'line': Palette.line,
    'river': Palette.river,
    'river2': Palette.river2,
    'deep': Palette.deep,
    'bib': Palette.bib,
    'rest': Palette.rest,
    'pre': Palette.pre,
    'warn': Palette.warn,
    'ok': Palette.ok,
    'iron': Palette.iron,
    'summer': Palette.summer,
    'low': Palette.low,
    'awake': Palette.wach,
    'iron-dark': Palette.ironDark,
    'river-dark': Palette.riverDark,
  };

  /// Wo die App bewusst vom Board abweicht — eine Entscheidung, kein
  /// Fehler. `surface` ist seit dem 29.10.2026 die dunkelste der fünf
  /// Fassungen ohne sichtbare Kante (#167, dort „A3"); der Boardwert
  /// #0E1317 steht oben in `ausDemBoard` stehen geblieben, damit die
  /// Abweichung sichtbar bleibt und niemand sie als Tippfehler
  /// zurückschreibt. Die Begründung steht in `palette.dart`.
  const abweichungDunkel = <String, int>{'surface': 0xFF090D10};

  group('Jede Farbe steht so in der App, wie sie im Board steht', () {
    for (final eintrag in ausDemBoard.entries) {
      final (hell, dunkel) = eintrag.value;
      final farbe = inDerApp[eintrag.key]!;

      test('--${eintrag.key}, hell', () {
        expect(
          farbe.color.toARGB32(),
          hell,
          reason:
              '`--${eintrag.key}` steht in docs/screens/tokens.css im '
              ':root-Block als #${hell.toRadixString(16).substring(2).toUpperCase()}',
        );
      });

      test('--${eintrag.key}, dunkel', () {
        final erwartet = abweichungDunkel[eintrag.key] ?? dunkel;
        expect(
          farbe.darkColor.toARGB32(),
          erwartet,
          reason: erwartet == dunkel
              ? '`--${eintrag.key}` steht in docs/screens/tokens.css im '
                    '[data-theme="dark"]-Block als '
                    '#${dunkel.toRadixString(16).substring(2).toUpperCase()}'
              : '`--${eintrag.key}` weicht bewusst vom Board ab: erwartet '
                    '#${erwartet.toRadixString(16).substring(2).toUpperCase()}, '
                    'Board #${dunkel.toRadixString(16).substring(2).toUpperCase()}',
        );
      });
    }
  });

  group('Die beiden Zusagen, die der Dunkelmodus ausdrücklich gibt', () {
    // `tokens.css`: „Die Kartenfläche bleibt abgehoben. Wären beide
    // schwarz, verschwänden die Karten und mit ihnen der Aufbau jedes
    // Schirms."
    test('die Kartenfläche hebt sich vom Hintergrund ab', () {
      expect(Palette.surface.darkColor.toARGB32(), isNot(0xFF000000));
      expect(
        Palette.surface.darkColor.toARGB32(),
        isNot(Palette.bg.darkColor.toARGB32()),
      );
    });

    // `tokens.css`: „Die Ampelfarben behalten ihren Farbton." Geprüft wird
    // der Farbton grob über den dominanten Kanal — ein Grün, das im
    // Dunkelmodus blau würde, trüge seine Bedeutung nicht mehr
    // (`docs/todo/30`).
    test('die Ampelfarben behalten ihren Farbton', () {
      int gruen(Color farbe) => (farbe.toARGB32() >> 8) & 0xFF;
      int rot(Color farbe) => (farbe.toARGB32() >> 16) & 0xFF;

      expect(
        gruen(Palette.ok.darkColor),
        greaterThan(rot(Palette.ok.darkColor)),
      );
      expect(
        rot(Palette.warn.darkColor),
        greaterThan(gruen(Palette.warn.darkColor)),
      );
      expect(rot(Palette.bib.darkColor), greaterThan(80));
      expect(gruen(Palette.bib.darkColor), greaterThan(80));
    });
  });
}
