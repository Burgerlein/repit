/// Alle Tagesgrenzen laufen über diese Klasse. Niemals mit einer festen
/// Dauer (`Duration(days: 1)` o.ä.) auf einem Zeitstempel rechnen, um einen
/// Kalendertag weiterzugehen — am 29.03.2026 hat der Tag 23, am 25.10.2026
/// 25 Stunden.
///
/// Dart hat keine Zeitzonendatenbank: `dart:core` kennt nur „lokal" (die
/// Gerätezeitzone — auf einem anders eingestellten Gerät also falsch) und
/// „UTC". `package:timezone` ist verboten, weil es die Importgrenze aus
/// `test/import_boundary_test.dart` bräche (`trainings_core` importiert nur
/// `dart:core` und `dart:math`). Die EU-Sommerzeitregel wird deshalb von Hand
/// nachgebildet: Sommerzeit (UTC+2) gilt vom letzten Sonntag im März
/// 01:00 UTC bis zum letzten Sonntag im Oktober 01:00 UTC, sonst Winterzeit
/// (UTC+1). `_versatz` ist die einzige Stelle, die diese Regel kennt — alles
/// andere rechnet darüber.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/BerlinCalendar.swift`,
/// das sich dort auf Apples Zeitzonendatenbank verlassen kann.
///
/// Alle Rückgaben sind UTC-`DateTime`-Werte, die einen Berliner Tagesbeginn
/// bezeichnen.
///
/// Die nachgebildete Regel gilt **ab 1996**. Davor endete die Sommerzeit in
/// der EU am letzten Sonntag im September statt im Oktober, und vor 1980 gab
/// es in Deutschland gar keine Sommerzeit — für Zeitpunkte vor 1996 liefert
/// diese Klasse falsche Tagesgrenzen. Für eine Trainings-App ohne historische
/// Daten ist das irrelevant; wer sie künftig auf ältere Daten anwendet
/// (z. B. ein Gesundheitsdaten-Import), muss das wissen.
abstract final class BerlinCalendar {
  /// Berliner Mitternacht des Kalendertags, der den gegebenen Zeitpunkt
  /// enthält, als UTC-Zeitpunkt.
  static DateTime startOfDay(DateTime zeitpunkt) {
    final (jahr, monat, tag) = _lokalesDatum(zeitpunkt);
    return _beginnDesLokalenTages(jahr, monat, tag);
  }

  /// Obere Grenze für Abfragen, die den ganzen Tag einschließen sollen: die
  /// Mitternacht des Folgetags. Der Grenzzeitpunkt selbst gehört noch dazu,
  /// alles danach nicht mehr.
  static DateTime endOfDay(DateTime zeitpunkt) => dayBounds(zeitpunkt).$2;

  /// Beide Grenzen einschließlich: Beginn des Tages und Beginn des
  /// Folgetags.
  static (DateTime start, DateTime end) dayBounds(DateTime zeitpunkt) {
    final (jahr, monat, tag) = _lokalesDatum(zeitpunkt);
    final start = _beginnDesLokalenTages(jahr, monat, tag);
    // Reiner Datumsschritt (kein Zeitstempel-Offset): `DateTime.utc`
    // normalisiert `tag + 1` korrekt über Monats- und Jahresgrenzen hinweg.
    final folgetag = DateTime.utc(jahr, monat, tag + 1);
    final end = _beginnDesLokalenTages(
      folgetag.year,
      folgetag.month,
      folgetag.day,
    );
    return (start, end);
  }

  /// Alle Tage zwischen `from` und `through`, beide Grenzen einschließlich.
  /// Liegt `from` nach `through`, ist das Ergebnis leer.
  static List<DateTime> days({
    required DateTime from,
    required DateTime through,
  }) {
    final (vonJahr, vonMonat, vonTag) = _lokalesDatum(from);
    final (bisJahr, bisMonat, bisTag) = _lokalesDatum(through);
    var datum = DateTime.utc(vonJahr, vonMonat, vonTag);
    final letztesDatum = DateTime.utc(bisJahr, bisMonat, bisTag);

    final ergebnis = <DateTime>[];
    while (!datum.isAfter(letztesDatum)) {
      ergebnis.add(_beginnDesLokalenTages(datum.year, datum.month, datum.day));
      // Reiner Datumsschritt, kein Zeitstempel-Offset: unabhängig davon, ob
      // der überschrittene Tag 23, 24 oder 25 Stunden hat, rückt das Datum
      // garantiert um genau einen Kalendertag vor — keine Endlosschleife.
      datum = DateTime.utc(datum.year, datum.month, datum.day + 1);
    }
    return ergebnis;
  }

  /// Der ISO-Tag (`yyyy-MM-dd`) in Berliner Zeit.
  static String dayKey(DateTime zeitpunkt) {
    final (jahr, monat, tag) = _lokalesDatum(zeitpunkt);
    final j = jahr.toString().padLeft(4, '0');
    final m = monat.toString().padLeft(2, '0');
    final t = tag.toString().padLeft(2, '0');
    return '$j-$m-$t';
  }

  /// Der Berliner Tagesbeginn, der `tage` Kalendertage nach dem Tag des
  /// gegebenen Zeitpunkts liegt; negative Werte gehen zurück.
  ///
  /// Der Schritt läuft über das Datum, nicht über eine Dauer: `addDays(x, 7)`
  /// landet garantiert auf derselben Uhrzeit desselben Wochentags, auch wenn
  /// dazwischen eine Woche mit 167 oder 169 Stunden liegt.
  static DateTime addDays(DateTime zeitpunkt, int tage) {
    final (jahr, monat, tag) = _lokalesDatum(zeitpunkt);
    final datum = DateTime.utc(jahr, monat, tag + tage);
    return _beginnDesLokalenTages(datum.year, datum.month, datum.day);
  }

  /// Der Berliner Monatserste 00:00 des Monats, der den gegebenen Zeitpunkt
  /// enthält — als UTC-Zeitpunkt, wie alles aus dieser Klasse.
  ///
  /// Nicht `DateTime.utc(jahr, monat, 1)`: Das wäre der **UTC**-Monatsanfang
  /// und läge eine bzw. zwei Stunden zu spät.
  static DateTime startOfMonth(DateTime zeitpunkt) {
    final (jahr, monat, _) = _lokalesDatum(zeitpunkt);
    return _beginnDesLokalenTages(jahr, monat, 1);
  }

  /// Der Berliner Monatserste, der `monate` Kalendermonate nach dem **Monat**
  /// des gegebenen Zeitpunkts liegt; negative Werte gehen zurück.
  ///
  /// Die Auflösung ist der Monat, nicht der Tag — damit stellt sich die Frage
  /// nach dem 31. in einem 30-Tage-Monat gar nicht erst.
  /// `addMonths(x, 0)` ist `startOfMonth(x)`.
  ///
  /// Der Schritt läuft über das Datum, nicht über eine Dauer: Der März 2026
  /// ist 743 Stunden lang, der Oktober 2026 745.
  static DateTime addMonths(DateTime zeitpunkt, int monate) {
    final (jahr, monat, _) = _lokalesDatum(zeitpunkt);
    // `DateTime.utc` normalisiert `monat + monate` über Jahresgrenzen hinweg,
    // in beide Richtungen.
    final datum = DateTime.utc(jahr, monat + monate, 1);
    return _beginnDesLokalenTages(datum.year, datum.month, 1);
  }

  /// Der Wochentag des Berliner Kalendertags, der den gegebenen Zeitpunkt
  /// enthält — `DateTime.monday` bis `DateTime.sunday`.
  ///
  /// Nicht über `startOfDay(…).weekday` zu haben: Der Berliner Tagesbeginn
  /// ist als UTC-Zeitpunkt 22:00 oder 23:00 des **Vortags**, und dessen
  /// `weekday` ist um eins zu klein.
  static int weekday(DateTime zeitpunkt) {
    final (jahr, monat, tag) = _lokalesDatum(zeitpunkt);
    return DateTime.utc(jahr, monat, tag).weekday;
  }

  /// Die Berliner Wanduhrzeit zum gegebenen Zeitpunkt, als Stunde und
  /// Minute.
  ///
  /// Der Versatz wird **am Zeitpunkt** bestimmt, nicht am Tagesbeginn: Am
  /// 25.10.2026 liegt die lokale Uhrzeit 02:30 auf zwei Zeitpunkten
  /// (00:30 UTC noch +2, 01:30 UTC schon +1), der Tagesbeginn dieses Tages
  /// hat aber nur einen Versatz. Wer über
  /// `zeitpunkt.difference(startOfDay(zeitpunkt))` rechnet, bekommt für den
  /// zweiten Zeitpunkt 03:30 statt 02:30.
  static (int hour, int minute) wallClock(DateTime zeitpunkt) {
    final utc = zeitpunkt.toUtc();
    final lokal = utc.add(_versatz(utc));
    return (lokal.hour, lokal.minute);
  }

  /// Der Abstand zweier Tagesschlüssel in Tagen — `to` minus `from`, also
  /// negativ, wenn `to` vor `from` liegt. `null`, wenn einer der beiden
  /// kein lesbarer Tagesschlüssel ist (Form `JJJJ-MM-TT`, wie [dayKey] ihn
  /// erzeugt).
  ///
  /// **Reine Kalenderarithmetik in UTC, und das ist der Kern der Sache.**
  /// Ein Tagesschlüssel ist eine Kalenderangabe, kein Zeitpunkt. Wer ihn
  /// mit `DateTime.parse` liest, bekommt die **Ortszeit** der Maschine;
  /// über eine Zeitumstellung hinweg hat ein Tag dann 23 oder 25 Stunden,
  /// und `Duration.inDays` schneidet ab statt zu runden — aus dem 29. auf
  /// den 30.03.2026 würden 0 Tage. Als UTC-Mitternachten gelesen hat jeder
  /// Tag genau 24 Stunden, und die Rechnung stimmt an jedem Tag des Jahres.
  ///
  /// Auch [startOfDay] taugt dafür **nicht**: Das sind Zeitpunkte der
  /// Berliner Mitternacht und tragen denselben 23/25-Stunden-Abstand.
  ///
  /// Nicht zu verwechseln mit [days]: Jene Liste schließt beide Grenzen
  /// ein, hat für zwei aufeinanderfolgende Tage also zwei Einträge —
  /// `daysBetween` ergibt für dieselbe Spanne `1`.
  static int? daysBetween({required String from, required String to}) {
    final von = _alsUtcMitternacht(from);
    final bis = _alsUtcMitternacht(to);
    if (von == null || bis == null) return null;
    return bis.difference(von).inDays;
  }

  /// Ein Tagesschlüssel als UTC-Mitternacht, oder `null`, wenn er sich
  /// nicht lesen lässt.
  ///
  /// Das angehängte `T00:00:00Z` ist der ganze Trick: `DateTime.parse`
  /// nimmt eine Zeitzonenangabe nur zusammen mit einer Uhrzeit entgegen,
  /// und ohne sie läse es den Schlüssel als lokale Mitternacht.
  static DateTime? _alsUtcMitternacht(String tagesSchluessel) =>
      DateTime.tryParse('${tagesSchluessel}T00:00:00Z');

  /// Jahr, Monat und Tag des Kalendertags in Berliner Zeit, der den
  /// gegebenen Zeitpunkt enthält.
  static (int, int, int) _lokalesDatum(DateTime zeitpunkt) {
    final utc = zeitpunkt.toUtc();
    final lokal = utc.add(_versatz(utc));
    return (lokal.year, lokal.month, lokal.day);
  }

  /// Berliner Mitternacht des gegebenen Kalendertags, als UTC-Zeitpunkt.
  ///
  /// Der Versatz wird an der UTC-Mitternacht desselben Datums bestimmt statt
  /// am tatsächlichen lokalen Mitternachtsinstant: Die EU-Umstellung liegt
  /// immer um 01:00 UTC, also nach 00:00 UTC desselben Datums. Damit liegt
  /// die UTC-Mitternacht dieses Datums immer auf derselben Seite der
  /// Umstellung wie die tatsächliche lokale Mitternacht — auch am
  /// Umstellungstag selbst (29.03.2026 00:00 UTC ist vor der Umstellung um
  /// 01:00 UTC, genau wie die lokale Mitternacht dieses Tages).
  static DateTime _beginnDesLokalenTages(int jahr, int monat, int tag) {
    final datumAlsUtc = DateTime.utc(jahr, monat, tag);
    return datumAlsUtc.subtract(_versatz(datumAlsUtc));
  }

  /// Der UTC-Versatz der mitteleuropäischen Zeit am gegebenen UTC-Zeitpunkt:
  /// +2h während der Sommerzeit (letzter Sonntag im März 01:00 UTC bis
  /// letzter Sonntag im Oktober 01:00 UTC), sonst +1h. Einzige Stelle, die
  /// die EU-Sommerzeitregel kennt — alles andere rechnet darüber.
  static Duration _versatz(DateTime zeitpunkt) {
    final utc = zeitpunkt.toUtc();
    final jahr = utc.year;
    final beginnSommerzeit = DateTime.utc(jahr, 3, _letzterSonntag(jahr, 3), 1);
    final endeSommerzeit = DateTime.utc(jahr, 10, _letzterSonntag(jahr, 10), 1);
    final istSommerzeit =
        !utc.isBefore(beginnSommerzeit) && utc.isBefore(endeSommerzeit);
    return Duration(hours: istSommerzeit ? 2 : 1);
  }

  /// Der Tag des letzten Sonntags im gegebenen Monat (UTC-Kalender).
  static int _letzterSonntag(int jahr, int monat) {
    // Tag 0 des Folgemonats ist der letzte Tag des gegebenen Monats — Dart
    // normalisiert das beim Erzeugen des DateTime (siehe Normalisierung von
    // `tag + 1` weiter oben, hier das Gegenstück rückwärts).
    var tag = DateTime.utc(jahr, monat + 1, 0).day;
    while (DateTime.utc(jahr, monat, tag).weekday != DateTime.sunday) {
      tag -= 1;
    }
    return tag;
  }
}
