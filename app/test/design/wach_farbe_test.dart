import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/ring_karte.dart';
import 'package:repit/health/health_types.dart';

/// Ein Begriff, ein Ton: **„Wach" ist auf dem ganzen Erholung-Schirm
/// dieselbe Farbe.** Review-Befund vom 27.10.2026, Tims Entscheidung am
/// selben Tag.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `lib/design/hypnogramm.dart` zeichnete `SleepStage.awake` in
/// `Palette.warn` (#A33B3B hell, #E07A7A dunkel). `lib/design/ring_karte.dart`
/// zeichnete das Unterbrechungs-Segment des Schlaf-Rings — **denselben
/// Begriff** — in einer eigenen privaten Konstante `_wach = 0xFFE8735A`, mit
/// der ausdrücklichen Begründung, die Palette kenne den Ton nicht.
///
/// Auf dem Erholung-Schirm standen damit übereinander: das
/// Unterbrechungs-Segment in Lachs und, direkt darunter, die Wach-Balken des
/// Hypnogramms in Backsteinrot. **Ein Schirm, ein Begriff, zwei Farben.**
///
/// Richtig ist der Lachston. Prototyp und Swift stimmen überein und
/// widersprechen dem Code:
///
/// | Quelle | Wert |
/// |---|---|
/// | `docs/prototype/erholung-alles.html:16` (hell) | `--wake:#E8735A` |
/// | `docs/prototype/erholung-alles.html:23` (dunkel) | `--wake:#E8735A` |
/// | `Sources/Features/Recovery/SleepChart.swift:19` | `Color(red: 0.91, green: 0.45, blue: 0.35)` = #E8735A |
///
/// Die Spec schreibt an dieser Stelle „Wach `--warn`", und Ticket #116 hat
/// das übernommen. **Beide sind falsch, nicht der Umsetzende** — und der
/// bisherige Test dieser Zeile (`hypnogramm_test.dart`) hat den Irrtum
/// festgeschrieben, statt ihn zu fangen.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// ```dart
/// // in lib/design/palette.dart, neben `warn`:
///
/// /// Wachliegen — `--awake` aus `docs/screens/tokens.css`.
/// static const wach = CupertinoDynamicColor.withBrightness(
///   color: Color(0xFFE87359),
///   darkColor: Color(0xFFFF8E72),
/// );
/// ```
///
/// ## Nachtrag 27.10.2026 — die Quelle ist jetzt das Board
///
/// Diese Datei schrieb ursprünglich `#E8735A` fest, hell **wie** dunkel,
/// aus `docs/prototype/erholung-alles.html`. Beides ist überholt, seit Tim
/// die Palette der ganzen App auf `docs/screens/tokens.css` festgelegt hat
/// (`palette_test.dart` trägt die vollständige Tabelle):
///
/// | Quelle | hell | dunkel |
/// |---|---|---|
/// | `docs/prototype/erholung-alles.html` (alt) | `#E8735A` | `#E8735A` |
/// | `docs/screens/tokens.css` (gilt) | `#E87359` | `#FF8E72` |
///
/// Die helle Abweichung ist eine Ziffer und sieht nach einem Tippfehler in
/// einer der beiden Dateien aus — das Board gewinnt, weil es laut eigenem
/// Dateikopf die Quelle ist. **Der Dunkelmodus ist dagegen eine echte
/// Entscheidung:** Auf dem neuen schwarzen Grund (`--bg: #000000`) ist der
/// helle Lachston `#FF8E72` richtig, und der Satz „kein vergessener
/// Dunkelmodus" aus der ersten Fassung dieser Datei gilt nicht mehr. Wer
/// den Doc-Kommentar in `palette.dart` stehen lässt, lässt eine Zusage
/// stehen, die nicht mehr stimmt.
///
/// **Unverändert bleibt der Befund selbst:** ein Begriff, ein Ton. Ring und
/// Hypnogramm lesen beide `Palette.wach`, und `wach` ist nicht `warn`.
///
/// Die private Konstante `_wach` in `ring_karte.dart` **verschwindet**;
/// beide Stellen lesen `Palette.wach`. Die Wahl von `Palette` als Zuhause
/// ist im Dateikopf von `hypnogramm_test.dart` begründet — kurz: Der
/// Prototyp deklariert `--wake` im selben `:root`-Block wie `--warn`, und
/// Swift kennt den Ton auch, nur zweimal hartcodiert, weil es dort keinen
/// Palette-Eintrag gibt. Das ist die Schwäche der Vorlage, kein Vorbild.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Ob irgendwo sonst `Palette.warn` steht.** `warn` bleibt der Ton der
///   Warnsignale und wird weiter gebraucht; ein Test gegen sein Vorkommen
///   wäre ein Suchlauf, kein Verhalten.
/// - **Wie der Ton aussieht.** Kein Pixelvergleich — geprüft wird, dass es
///   **ein** Ton ist und welcher.
void main() {
  /// Die beiden Werte aus dem Board. Stehen hier **einmal** als Zahl, damit
  /// der Test nicht nur „beide sind gleich" sagt (zwei gleich falsche Töne
  /// wären das auch), sondern auch, welcher gilt.
  const hellAusDemBoard = Color(0xFFE87359);
  const dunkelAusDemBoard = Color(0xFFFF8E72);

  /// Ein Schlaf-Ring, wie ihn der Erholung-Schirm baut. Die Zahlen sind
  /// erfunden; nur das dritte Segment interessiert.
  final schlafRing = ErholungRinge.schlaf(
    gesamt: 76,
    punkteDauer: 44,
    punkteZubettgehzeit: 17,
    punkteUnterbrechungen: 15,
    dauer: '5:35 h',
  );

  group('Palette.wach — der Ton hat ein Zuhause', () {
    test('trägt hell und dunkel die Werte aus dem Board', () {
      expect(Palette.wach.color.toARGB32(), hellAusDemBoard.toARGB32());
      expect(
        Palette.wach.darkColor.toARGB32(),
        dunkelAusDemBoard.toARGB32(),
        reason:
            '`--awake` steht in docs/screens/tokens.css im '
            '[data-theme="dark"]-Block als #FF8E72 — auf schwarzem Grund '
            'ist der helle Lachston der richtige',
      );
      expect(
        Palette.wach.darkColor.toARGB32(),
        isNot(Palette.wach.color.toARGB32()),
        reason:
            'die alte Fassung trug hell wie dunkel denselben Wert und '
            'begründete das mit dem Prototyp — das Board sagt etwas anderes',
      );
    });

    test('und ist nicht der Ton der Warnsignale', () {
      expect(
        Palette.wach.color.toARGB32(),
        isNot(Palette.warn.color.toARGB32()),
        reason:
            'Wachliegen ist kein Warnsignal. Die Verwechslung von `--wake` '
            'mit `--warn` beim Abschreiben ist genau dieser Befund',
      );
    });
  });

  group('Ring und Hypnogramm sprechen über dieselbe Sache in derselben '
      'Farbe', () {
    test('die Wach-Phase des Hypnogramms trägt Palette.wach', () {
      expect(SchlafPhasen.farbe(SleepStage.awake), Palette.wach);
    });

    test('das Unterbrechungs-Segment des Schlaf-Rings ebenfalls', () {
      expect(
        schlafRing.abschnitte[2].farbe,
        Palette.wach,
        reason:
            'bisher eine private Konstante in `ring_karte.dart` — ein '
            'zweites Zuhause für genau einen Wert',
      );
    });

    test(
      'und damit denselben Ton — das ist die eigentliche Zusage',
      () {
        expect(
          SchlafPhasen.farbe(SleepStage.awake).color.toARGB32(),
          schlafRing.abschnitte[2].farbe.toARGB32(),
          reason:
              'die beiden stehen auf demselben Schirm übereinander. Zwei '
              'Farben für denselben Begriff liest niemand als zwei '
              'Zufälle — er liest es als zwei Bedeutungen',
        );
        expect(
          SchlafPhasen.farbe(SleepStage.awake).color.toARGB32(),
          hellAusDemBoard.toARGB32(),
          reason: 'und zwar den aus dem Board, nicht irgendeinen gemeinsamen',
        );
      },
    );
  });
}
