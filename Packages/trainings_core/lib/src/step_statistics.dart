import 'berlin_calendar.dart';

/// Die Schritt-Kennzahlen des Schritte-Schirms (#84): gestern, Ø 7 Tage mit
/// Trend zur Vorwoche, Ø 30 Tage, „Ziel erreicht x von y" und Top-Tag.
///
/// Dart-Gegenstück zu `StepStats` in
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/StepStatistics.swift`.
/// Entsteht über [StepStatistics.make]; wie der Konstruktor aussieht, legt
/// kein Vertrag fest.
///
/// Trägt `==` und `hashCode` über alle Felder: `StepStats` wird die
/// Abhängigkeit eines abgeleiteten Providers, und ohne Wertgleichheit wäre
/// jedes neu gebaute Exemplar ungleich dem vorigen — jeder abgeleitete Wert
/// rechnete je Bild neu, Fehler `03` wortgleich im neuen Code (`CLAUDE.md`).
final class StepStats {
  /// Die Schritte von gestern. `null`, wenn gestern nicht gemessen wurde —
  /// kein älterer Tag springt ein, und `0` hieße „gemessen und null".
  final int? yesterday;

  /// Das Mittel der gemessenen Tage in den Abständen 1–7, kaufmännisch
  /// gerundet. `null`, wenn dort kein Tag gemessen wurde.
  final int? average7;

  /// Veränderung des Sieben-Tage-Schnitts gegen die sieben Tage davor,
  /// in Prozent. `null`, wenn es eine der beiden Wochen nicht gibt — oder
  /// die Vorwoche im Mittel bei 0 liegt: Ein Anstieg von 0 ist kein
  /// Prozentsatz. Bleibt ein `double`; formatiert wird erst in der View.
  final double? trendPercent;

  /// Das Mittel der gemessenen Tage in den Abständen 1–30, kaufmännisch
  /// gerundet. `null`, wenn dort kein Tag gemessen wurde.
  final int? average30;

  /// Wie viele der gemessenen Tage im 30-Tage-Fenster das Ziel erreichten.
  final int goalReached;

  /// Nenner für „Ziel erreicht x von y". Nicht 30: Tage ohne Messung sind
  /// keine Tage mit null Schritten. Die Zahl der Tage ohne Messung, die der
  /// Schirm dazusagt, ist `30 − daysWithData` und braucht kein Feld.
  final int daysWithData;

  /// Der höchste Tageswert im 30-Tage-Fenster. `null` nur, wenn dort kein
  /// Tag gemessen wurde — ein gemessener Nulltag hat den Top-Tag `0`.
  final int? best;

  const StepStats({
    required this.yesterday,
    required this.average7,
    required this.trendPercent,
    required this.average30,
    required this.goalReached,
    required this.daysWithData,
    required this.best,
  });

  @override
  bool operator ==(Object other) =>
      other is StepStats &&
      other.yesterday == yesterday &&
      other.average7 == average7 &&
      other.trendPercent == trendPercent &&
      other.average30 == average30 &&
      other.goalReached == goalReached &&
      other.daysWithData == daysWithData &&
      other.best == best;

  @override
  int get hashCode => Object.hash(yesterday, average7, trendPercent,
      average30, goalReached, daysWithData, best);
}

/// Die Rechnung hinter der Körper-Kachel „Schritte Ø 7 Tage" (#202, Teil C)
/// und den Kennzahlen des Schritte-Schirms (#84).
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/StepStatistics.swift`.
///
/// **Die Eingabe ist Tagesschlüssel auf Schritte, kein `DailyMetrics`.**
/// Der Transporttyp des Kanals liegt in `app/lib/health/health_types.dart`
/// und gehört nicht in den Kern (`CLAUDE.md`); gewählt ist genau die Form,
/// die [StepMerge.daily] bereits zurückgibt. Drei Dinge fallen dabei von
/// selbst ab: Ein ungemessener Tag ist ein **fehlender Schlüssel** und kein
/// Eintrag mit Wert `0` (der Wertetyp ist `int`, nicht `int?` — Fehler `01`
/// ist hier nicht ausdrückbar), ein Tag kann nicht doppelt vorkommen, und
/// der Schlüssel bleibt eine Kalenderangabe statt eines Zeitpunkts.
abstract final class StepStatistics {
  /// Wie viele Kalendertage das Fenster umfasst.
  static const int windowDays = 7;

  /// Das Mittel der Schritte über die [windowDays] Kalendertage **vor** dem
  /// Berliner Tag von [now]. `null`, wenn im Fenster kein einziger Tag
  /// gemessen wurde.
  ///
  /// **Der laufende Tag bleibt draußen** (`StepStatistics.swift:30–31`): Er
  /// ist noch nicht vorbei und zöge jeden Durchschnitt nach unten. Gestern
  /// und der siebte Tag zurück liegen beide drin, der achte nicht mehr;
  /// ein Tag nach [now] hat einen negativen Abstand und fällt mit derselben
  /// Bedingung heraus.
  ///
  /// **Ein Tag ohne Messung zählt nicht in den Nenner** — er ist kein Tag
  /// mit null Schritten (`StepStatistics.swift:11–12`). Ein Tag, der
  /// gemessen wurde und `0` ergab, zählt dagegen sehr wohl mit: ein Ruhetag
  /// auf dem Sofa. Genau dieser Unterschied trennt „keine Daten" von „nichts
  /// getan", und `null` statt `0` hält ihn auch im Ergebnis durch.
  ///
  /// Der Abstand läuft über [BerlinCalendar.daysBetween] und damit über
  /// Kalendertage, nicht über eine feste Dauer: Die Nacht zum 25.10. hat 25
  /// Stunden, die zum 29.03. deren 23 — ein Fenster aus `Duration(days: 7)`
  /// verlöre an diesen beiden Tagen seinen ältesten Tag und zöge dafür den
  /// Nachbarn davor herein.
  ///
  /// Gerundet wird kaufmännisch, wie in der Vorlage (`.rounded()`): genau
  /// die Hälfte geht nach oben.
  ///
  /// Ein Schlüssel, den [BerlinCalendar.daysBetween] nicht lesen kann, wird
  /// übergangen. Die Eingabe kommt aus [BerlinCalendar.dayKey] oder aus der
  /// Datenbankspalte und ist wohlgeformt; ein kaputter Schlüssel ist keine
  /// Datenlage, über die dieses Mittel eine Aussage treffen könnte.
  static int? average7(Map<String, int> stepsByDay, {required DateTime now}) {
    final heute = BerlinCalendar.dayKey(now);

    var summe = 0;
    var gemessen = 0;
    for (final eintrag in stepsByDay.entries) {
      final abstand = BerlinCalendar.daysBetween(from: eintrag.key, to: heute);
      if (abstand == null || abstand < 1 || abstand > windowDays) continue;
      summe += eintrag.value;
      gemessen += 1;
    }

    // Kein gemessener Tag im Fenster: `null`, nie `0`. Eine 0 behauptete
    // „keinen Schritt getan" — das ist Fehler `01` in Rechenform.
    if (gemessen == 0) return null;
    return (summe / gemessen).round();
  }

  /// Alle Kennzahlen des Schritte-Schirms in einem Zug, Verhaltensvorlage
  /// `StepStatistics.make` in `StepStatistics.swift`.
  ///
  /// **Alle Fenster rechnen von gestern rückwärts**; der laufende Tag ist
  /// noch nicht vorbei und zöge jeden Durchschnitt nach unten
  /// (`StepStatistics.swift:30–31`). In Tagesabständen (1 ist gestern):
  /// `yesterday` Abstand 1, `average7` und die junge Trend-Woche 1–7, die
  /// Vergleichswoche des Trends 8–14, `average30`, `goalReached`,
  /// `daysWithData` und `best` 1–30. Ein Tag nach [now] hat einen negativen
  /// Abstand und fällt überall heraus.
  ///
  /// Die Abstände laufen über [BerlinCalendar.daysBetween], also über
  /// Kalendertage — dieselbe Begründung wie bei [average7]: Die Nacht zum
  /// 25.10. hat 25 Stunden, ein Fenster aus `Duration(days: …)` verrutschte
  /// dort um einen Tag.
  ///
  /// Der Trend rechnet je Woche über die **gemessenen** Tage und aus den
  /// bereits gerundeten Wochenmitteln, wie die Vorlage; er verlangt eine
  /// Vorwoche mit Mittel über 0 (`StepStatistics.swift:62`) — ein Anstieg
  /// von 0 ist kein Prozentsatz, und „kein Trend" ist `null`, nie `0`.
  ///
  /// Ein Schlüssel, den [BerlinCalendar.daysBetween] nicht lesen kann, wird
  /// übergangen — dieselbe offene Entscheidung wie bei [average7].
  static StepStats make(
    Map<String, int> stepsByDay, {
    required int goal,
    required DateTime now,
  }) {
    final heute = BerlinCalendar.dayKey(now);

    /// Schritte je Tagesabstand: 1 ist gestern.
    final jeAbstand = <int, int>{};
    for (final eintrag in stepsByDay.entries) {
      final abstand = BerlinCalendar.daysBetween(from: eintrag.key, to: heute);
      if (abstand == null || abstand < 1) continue;
      jeAbstand[abstand] = eintrag.value;
    }

    List<int> werte(int von, int bis) => [
      for (var abstand = von; abstand <= bis; abstand++)
        if (jeAbstand.containsKey(abstand)) jeAbstand[abstand]!,
    ];

    int? mittel(List<int> liste) {
      if (liste.isEmpty) return null;
      return (liste.reduce((a, b) => a + b) / liste.length).round();
    }

    final jungeWoche = mittel(werte(1, 7));
    final vorwoche = mittel(werte(8, 14));
    final monat = werte(1, 30);

    double? trend;
    if (jungeWoche != null && vorwoche != null && vorwoche > 0) {
      trend = (jungeWoche - vorwoche) / vorwoche * 100;
    }

    int? hoechster;
    for (final wert in monat) {
      if (hoechster == null || wert > hoechster) hoechster = wert;
    }

    return StepStats(
      yesterday: jeAbstand[1],
      average7: jungeWoche,
      trendPercent: trend,
      average30: mittel(monat),
      goalReached: monat.where((wert) => wert >= goal).length,
      daysWithData: monat.length,
      best: hoechster,
    );
  }
}
