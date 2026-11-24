/// Die vier Mahlzeiten eines Tages, in der Reihenfolge, in der sie auf dem
/// Tag-Schirm stehen.
///
/// Hier stehen nur die vier Fälle, **keine Sätze**: Die Beschriftungen
/// gehören in die View (`CLAUDE.md`, „Deutsch in der Oberfläche, Englisch
/// im Code").
enum Mahlzeit { fruehstueck, mittag, snack, abend }

/// Welche Mahlzeit zu welcher Uhrzeit gehört — und welche Uhrzeit eine
/// Mahlzeit vorgibt.
///
/// Gerechnet wird in **Minuten seit Mitternacht der Berliner Wanduhr**
/// (`0 … 1439`). Ein Zeitpunkt wird anderswo auf die Wanduhr gelesen
/// (`BerlinCalendar.wallClock`); hier liegt nur die Einteilung.
///
/// | Mahlzeit | Von | Bis |
/// |---|---|---|
/// | Frühstück | 04:00 | 10:59 |
/// | Mittagessen | 11:00 | 14:59 |
/// | Snack | 15:00 | 17:59 |
/// | Abendessen | 18:00 | **03:59** |
///
/// **Der Abend umschließt Mitternacht**, und das ist der Grund für diese
/// Klasse: Ein Eintrag um 01:30 gehört zum Abend davor und damit auf den
/// Tag davor. Ein viertes Fenster ohne Umschlag machte daraus einen Snack
/// auf dem falschen Tag.
///
/// **Jede Grenze gehört dem späteren Fenster:** 10:59 ist noch Frühstück,
/// 11:00 schon Mittag.
abstract final class Mahlzeitfenster {
  /// Wo der Esstag beginnt, in Minuten seit Mitternacht: 04:00, die
  /// Untergrenze des Frühstücks.
  ///
  /// Öffentlich, weil `laufenderTag` und `tagesende` (und über sie `esstag`
  /// und `naechsterEsstagBeginn`) dieselbe Grenze brauchen. Sie bekommen
  /// **keine zweite Konstante**: Rückte das Frühstück, rückte der Esstag
  /// mit, statt still einen Abend-Eintrag auf den falschen Tag zu legen.
  static const int tagesbeginnInMinuten = _fruehstueckAb;

  static const int _fruehstueckAb = 4 * 60; // 04:00
  static const int _mittagAb = 11 * 60; // 11:00
  static const int _snackAb = 15 * 60; // 15:00
  static const int _abendAb = 18 * 60; // 18:00

  /// Zu welcher Mahlzeit [minutenSeitMitternacht] gehört.
  ///
  /// Jede Zahl ergibt eine Mahlzeit; außerhalb von `0 … 1439` fällt sie in
  /// den Abend, weil der alles aufnimmt, was keinem der drei Tagfenster
  /// gehört. Geprüft wird der Bereich nicht — der Kern rechnet, er
  /// entscheidet nicht, ob eine Uhrzeit als Uhrzeit taugt.
  static Mahlzeit fuer(int minutenSeitMitternacht) {
    if (minutenSeitMitternacht >= _fruehstueckAb &&
        minutenSeitMitternacht < _mittagAb) {
      return Mahlzeit.fruehstueck;
    }
    if (minutenSeitMitternacht >= _mittagAb &&
        minutenSeitMitternacht < _snackAb) {
      return Mahlzeit.mittag;
    }
    if (minutenSeitMitternacht >= _snackAb &&
        minutenSeitMitternacht < _abendAb) {
      return Mahlzeit.snack;
    }
    return Mahlzeit.abend;
  }

  /// Die Vorgabe-Uhrzeit einer Mahlzeit: die Mitte ihres Fensters, in
  /// Minuten seit Mitternacht.
  ///
  /// Wird auf einem geblätterten Tag gebucht, ist „jetzt" die falsche
  /// Uhrzeit — der Eintrag gehört auf den offenen Tag. Die vier Zahlen
  /// stehen deshalb hier und nicht in einer View: Dort wären sie vier
  /// hartcodierte Werte außerhalb jeder Prüfung.
  ///
  /// Jede liegt in ihrem eigenen Fenster, sonst zeigte die Uhrzeit eines
  /// Eintrags auf eine andere Mahlzeit als die, unter der er steht.
  static int mitteInMinuten(Mahlzeit mahlzeit) => switch (mahlzeit) {
    Mahlzeit.fruehstueck => 8 * 60, // 08:00
    Mahlzeit.mittag => 12 * 60 + 30, // 12:30
    Mahlzeit.snack => 15 * 60 + 30, // 15:30
    Mahlzeit.abend => 19 * 60, // 19:00
  };
}
