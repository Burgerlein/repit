import 'package:flutter/cupertino.dart';

/// Palette des Web-Dashboards.
///
/// **Die Quelle ist `docs/screens/tokens.css`, nicht `Palette.swift`**
/// (Tims Entscheidung vom 27.10.2026, nachdem er den gebauten
/// Erholung-Schirm gegen das Entwurfsboard gehalten hat). Die Richtung des
/// Abgleichs hat sich damit umgedreht: Früher entstand das Board aus der
/// Swift-Palette, jetzt wird die App auf das Board nachgezogen. Eine Farbe,
/// die hier steht und in `tokens.css` fehlt — oder dort anders steht —, ist
/// ab jetzt ein Fehler in der App; `test/design/palette_test.dart` prüft das
/// Token für Token.
///
/// **Die dunklen Werte sind die Fassung „Nacht"** aus
/// `docs/screens/tokens.css` (Board, seit 26.10.2026): `bg` ist echtes
/// Schwarz, die Akzente sind deutlich heller als im Hellmodus. Vorher
/// standen hier die alten Anthrazit-Werte; Board und App zeigten
/// verschiedene Dunkelmodi.
///
/// **`surface` ist `#090D10`, und das Board sagt dasselbe.** Tim hat am
/// 29.10.2026 aus fünf Fassungen die dunkelste ohne Kante gewählt (#167,
/// dort „A3"); `tokens.css` ist im selben Zug nachgezogen. Wer den älteren
/// Wert `#0E1317` zurückschreibt, nimmt eine Entscheidung zurück, statt
/// einen Fehler zu beheben. Was das kostet, steht in `kacheln.dart`.
///
/// Jede Farbe ist eine `CupertinoDynamicColor`, die zwischen Hell- und
/// Dunkelmodus wechselt — wie `Color.adaptive(light:dark:)` in der Swift-
/// Vorlage. Anders als in SwiftUI löst sich eine `CupertinoDynamicColor`
/// nicht von selbst auf: Wer sie zeichnet, muss
/// `CupertinoDynamicColor.resolve(Palette.x, context)` aufrufen, sonst bleibt
/// sie auf ihrer hellen Variante stehen. Das übernehmen die Bausteine in
/// diesem Verzeichnis (`InsetCard`, `IconRow`, …), nicht `Palette` selbst.
///
/// Die abgeleiteten Werte des Boards (`--chrome`, `--sep`, `--fill`, die
/// Schatten) stehen hier bewusst **nicht**: Sie sind Deckkraftvarianten und
/// entstehen dort, wo sie gebraucht werden (`Glas`, `InsetCard`).
class Palette {
  Palette._();

  static const bg = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFEDF1EF),
    // Echtes Schwarz: Auf OLED sind die Pixel aus (`tokens.css`, Entwurf
    // „Nacht").
    darkColor: Color(0xFF000000),
  );

  /// Die Kartenfläche bleibt vom Hintergrund abgehoben. Wären beide
  /// schwarz, verschwänden die Karten und mit ihnen der Aufbau jedes
  /// Schirms.
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF8FAF9),
    darkColor: Color(0xFF090D10),
  );

  static const ink = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF15242A),
    darkColor: Color(0xFFF2F6F7),
  );

  static const muted = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF5B6B70),
    darkColor: Color(0xFF8A9AA1),
  );

  static const line = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFCBD5D3),
    darkColor: Color(0xFF222C31),
  );

  static const river = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2B6A8A),
    darkColor: Color(0xFF5CD2FF),
  );

  static const river2 = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF8DB4C6),
    darkColor: Color(0xFF1E4E66),
  );

  /// **Im Dunkelmodus das hellste Blau der Palette** — richtig für Ringe und
  /// Flächen, falsch für die unterste Schlafspur. Das Hypnogramm hat dafür
  /// seinen eigenen Ton (siehe `SchlafPhasen.farbe`).
  static const deep = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF173F54),
    darkColor: Color(0xFF9FE4FF),
  );

  static const bib = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2C230),
    darkColor: Color(0xFFFFD84D),
  );

  static const rest = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC3CCCA),
    darkColor: Color(0xFF39454A),
  );

  static const pre = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDCE3E1),
    darkColor: Color(0xFF161E22),
  );

  static const warn = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA33B3B),
    darkColor: Color(0xFFFF7E7E),
  );

  /// Wachliegen — `--awake` aus `docs/screens/tokens.css`.
  ///
  /// **Hell und dunkel sind verschieden.** Eine frühere Fassung trug
  /// zweimal `#E8735A` und begründete das mit `docs/prototype/
  /// erholung-alles.html`; auf dem schwarzen Grund des Boards ist der
  /// hellere Lachston `#FF8E72` der richtige, und die alte Zusage gilt
  /// nicht mehr.
  ///
  /// **Nicht `warn`.** Wachliegen ist kein Warnsignal. Auf dem
  /// Erholung-Schirm stehen das Unterbrechungs-Segment des Schlaf-Rings
  /// und die Wach-Balken des Hypnogramms übereinander — zwei Farben für
  /// denselben Begriff liest niemand als zwei Zufälle, sondern als zwei
  /// Bedeutungen (Tims Entscheidung vom 27.10.2026).
  static const wach = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE87359),
    darkColor: Color(0xFFFF8E72),
  );

  static const ok = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF2F7A4F),
    darkColor: Color(0xFF4FE0A0),
  );

  /// Blutung im Zykluskalender — `--blut` aus `docs/screens/tokens.css`
  /// (#539).
  ///
  /// **Nicht `warn`.** Das Rot der Palette heißt ‚Achtung‘ und trägt das
  /// quer durch die App — ein Ruhepuls außer der Reihe, eine
  /// gescheiterte Übernahme. Eine Periode ist kein Warnzustand, und ein
  /// Kalender, der sie in Warnrot malt, sagt etwas, das niemand gemeint
  /// hat. Darum eine eigene Farbe, deutlich rosa statt braunrot.
  ///
  /// Die Ziffer in einer gefüllten Zelle steht in [flaeche], nicht in
  /// [ink]: hell auf dem dunklen Rosa des Hellmodus, dunkel auf dem
  /// hellen Rosa des Dunkelmodus. Eine Regel, beide Fassungen.
  static const blut = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC44E6C),
    darkColor: Color(0xFFFF8FA8),
  );

  /// Die helle Schwester von [blut], für Flächen — genau wie `river2`
  /// zu `river`. Auf ihr steht die Ziffer in [blut]: der vorhergesagte
  /// Blutungstag, der noch keiner ist.
  static const blut2 = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF0D2DA),
    darkColor: Color(0xFF45232E),
  );

  static const iron = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6B5B95),
    darkColor: Color(0xFFB79DFF),
  );

  static const summer = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6E9F5A),
    darkColor: Color(0xFF9BE87A),
  );

  /// „Etwas zu wenig" — `--low`. Das Gelb der Muskelkarte und das Orange der
  /// Verlaufsampel (`VitalTon.nahAmSignal`). **Nicht `bib`:** Das
  /// Startnummer-Gelb bezeichnet den Wettkampf, nicht eine Bewertung.
  static const low = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE0A82E),
    darkColor: Color(0xFFFFC43D),
  );

  /// Die dunklen Enden der Verläufe im Banner einer laufenden Erfassung.
  /// `deep` taugt dafür nicht — das dreht sich im Dunkelmodus ins Helle um,
  /// und auf dem Banner steht in beiden Modi weiße Schrift.
  static const ironDark = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF4B3F6D),
    darkColor: Color(0xFF2A2148),
  );

  static const riverDark = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF173F54),
    darkColor: Color(0xFF06303F),
  );
}
