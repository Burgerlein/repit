import 'package:flutter/cupertino.dart';

/// Schriftgrößen für `Typografie.numeric`, benannt nach den Apple-eigenen
/// Textstilen (`Font.TextStyle` in SwiftUI), deren Punktgrößen sie
/// übernimmt — dieselbe Skala, an der sich
/// `Sources/DesignSystem/Typography.swift` orientiert.
enum TypografieGroesse {
  largeTitle(34),
  title(28),
  title2(22),
  title3(20),
  headline(17),
  body(17),
  callout(16),
  subheadline(15),
  footnote(13),
  caption(12),
  caption2(11);

  const TypografieGroesse(this.punktgroesse);

  final double punktgroesse;
}

/// Dart-Entsprechung von `Font.numeric` in
/// `Sources/DesignSystem/Typography.swift`: Zahlen und Überschriften in
/// Barlow Condensed, statt des heutigen Swift-Behelfs
/// (Systemschrift mit `.width(.condensed)`). Siehe Entwurf Abschnitt 6.6.
class Typografie {
  Typografie._();

  static const _barlowCondensed = 'Barlow Condensed';

  /// Barlow Condensed in der gegebenen Größe. Vorgabegewicht Semibold, wie
  /// in der Swift-Vorlage (`weight: Font.Weight = .semibold`).
  static TextStyle numeric(
    TypografieGroesse groesse, {
    FontWeight gewicht = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: _barlowCondensed,
      fontWeight: gewicht,
      fontSize: groesse.punktgroesse,
    );
  }

  /// Ziffern gleicher Breite, damit Spalten beim Aktualisieren nicht
  /// springen — Entsprechung zu `View.tabularNumbers()` in der Swift-Vorlage.
  static TextStyle tabularNumbers(TextStyle style) {
    return style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
