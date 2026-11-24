import 'berlin_calendar.dart';

// Perioden aus Blutungstagen (Clusterregel 2.1) und der Zyklustag eines
// Kalendertags (Abschnitt 1).
//
// Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte 1, 2
// und 5; Bereich #539, Ticket #591. Die Clusterregel und die beiden
// Beispiele aus 2.2 stammen aus der von Tim am 23.11.2026 freigegebenen
// Spec; der Grenzfall am Ende einer gekappten Periode ist dort als
// Festlegung gekennzeichnet und nicht von Tim freigegeben.
//
// Alle Tage sind ISO-Tagesschlüssel (`JJJJ-MM-TT`, wie
// [BerlinCalendar.dayKey] sie erzeugt). Abstände laufen über
// [BerlinCalendar.daysBetween] — nie über `DateTime.parse` auf dem
// Schlüssel allein, das ergäbe Ortszeit. Die Reihenfolge zweier Schlüssel
// wird mit `compareTo` verglichen: ISO-Tage sortieren lexikografisch in
// Kalenderreihenfolge und überstehen jede Zeitumstellung.

/// Wie stark ein Blutungstag blutet (Spec 4.1).
///
/// **Die Namen sind Speicherformat:** Die Spalte `blutung` der Tabelle
/// `zyklus_eintraege` speichert `name`. Wer einen Wert umbenennt, macht
/// jede gespeicherte Zeile dieser Stärke unlesbar.
enum Blutungsstaerke { leicht, mittel, stark }

/// Eine Periode: [von] und [bis] als ISO-Tag, **beide einschließlich**.
///
/// Erster und letzter Tag sind nach Regel 2.1 immer Blutungstage; eine
/// eintägige Periode hat `von == bis`.
///
/// Werttyp mit `==` und `hashCode` über beide Felder — ein Provider, der
/// eine Liste davon hält, soll nur neu rechnen, wenn sich wirklich etwas
/// geändert hat (`CLAUDE.md`, Werttypen als Abhängigkeit).
class Periode {
  const Periode({required this.von, required this.bis});

  /// Erster Tag der Periode, einschließlich — zugleich der Periodenstart,
  /// an dem der Zyklustag wieder bei 1 anfängt.
  final String von;

  /// Letzter Tag der Periode, einschließlich.
  final String bis;

  @override
  bool operator ==(Object other) =>
      other is Periode && other.von == von && other.bis == bis;

  @override
  int get hashCode => Object.hash(von, bis);

  @override
  String toString() => 'Periode(von: $von, bis: $bis)';
}

/// Höchstlänge einer Periode in Tagen (Regel 2.1, Nummer 3).
const int periodeHoechstensTage = 10;

/// Höchstzahl aufeinanderfolgender blutungsfreier Tage **innerhalb** einer
/// Periode (Regel 2.1, Nummer 2). Drei oder mehr trennen.
const int periodeHoechstensLueckeTage = 2;

/// Mindestabstand zweier Periodenstarts in Tagen (Regel 2.1).
const int periodeMindestabstandTage = 10;

/// Die Perioden, die in [blutungstage] stecken — nach [Periode.von]
/// aufsteigend sortiert (Spec 5).
///
/// [blutungstage] bildet ISO-Tage auf die erfasste Stärke ab. **Ein
/// Eintrag mit `null` ist kein Blutungstag** (Spec, Abschnitt 1): So ist
/// ein Tag abbildbar, an dem die Nutzerin etwas anderes erfasst hat —
/// Schmerz, Symptome, eine Zwischenblutung. Er zählt wie ein Tag ohne
/// Eintrag, also als Lücke.
///
/// Gelesen wird einmal von vorn nach hinten:
///
/// * Ein Blutungstag startet eine Periode, wenn er **beides** erfüllt —
///   mindestens [periodeHoechstensLueckeTage] + 1 blutungsfreie Tage davor
///   **und** mindestens [periodeMindestabstandTage] Tage Abstand zum
///   vorigen Periodenstart. Verfehlt er eine der beiden Bedingungen, ist
///   er eine Nebenblutung und zählt nicht mit.
/// * Danach wächst die Periode über Lücken von höchstens
///   [periodeHoechstensLueckeTage] Tagen hinweg, aber nur innerhalb des
///   Fensters von [periodeHoechstensTage] Tagen ab dem Start (Regel 3).
///
/// **Endet das Fenster auf einem Tag ohne Blutung, endet die Periode am
/// letzten Blutungstag darin** — Regel 1 verlangt einen Blutungstag als
/// letzten Tag. Das fällt hier ohne Zutun ab: Es wird nur fortgeschrieben,
/// was aufgenommen wurde.
///
/// Das Ergebnis hängt nicht von der Einfügereihenfolge der Map ab; eine
/// Dart-`Map` behält sie, und ein Ergebnis, das davon abhinge, wäre je
/// nach Ladeweg ein anderes.
///
/// Wirft eine [FormatException], wenn ein Schlüssel kein lesbarer ISO-Tag
/// ist — ein Programmierfehler beim Aufrufer, keine Datenlage.
/// **Braucht den ganzen bekannten Verlauf, kein Fenster.** Der erste
/// Blutungstag der übergebenen Map startet immer eine Periode — er hat
/// keinen Vorgänger, an dem er scheitern könnte. Wer monatsweise
/// hereinreicht und dabei mitten in eine Periode schneidet, bekommt dort
/// einen erfundenen Periodenstart, einen falschen Zyklustag und eine
/// falsche erste Zykluslänge (Fund des Review-Agenten, 24.11.2026).
List<Periode> periodenAus(Map<String, Blutungsstaerke?> blutungstage) {
  final tage = <String>[
    for (final eintrag in blutungstage.entries)
      if (eintrag.value != null) eintrag.key,
  ]..sort();

  final perioden = <Periode>[];
  String? letzterStart;
  var i = 0;

  while (i < tage.length) {
    final start = tage[i];
    if (!_startetPeriode(
      tag: start,
      letzterStart: letzterStart,
      vorigerBlutungstag: i == 0 ? null : tage[i - 1],
    )) {
      i++;
      continue;
    }

    var bis = start;
    var naechster = i + 1;
    while (naechster < tage.length) {
      final kandidat = tage[naechster];
      // Regel 3: Das Fenster reicht vom Start bis zum
      // `periodeHoechstensTage`-ten Tag, Grenzen eingeschlossen.
      if (_abstand(start, kandidat) > periodeHoechstensTage - 1) break;
      // Regel 2: Zwischen zwei aufgenommenen Tagen liegen höchstens
      // `periodeHoechstensLueckeTage` blutungsfreie Tage.
      if (_abstand(bis, kandidat) > periodeHoechstensLueckeTage + 1) break;
      bis = kandidat;
      naechster++;
    }

    perioden.add(Periode(von: start, bis: bis));
    letzterStart = start;
    // `naechster` steht auf dem ersten Tag, den die innere Schleife
    // abgelehnt hat — zwischen `bis` und ihm liegt nichts, weil sie beim
    // ersten Nein abbricht. Ob dieser Tag eine Periode startet, entscheidet
    // der nächste Durchlauf: Nach einer gekappten Periode kann er es
    // sehr wohl, wenn genug Abstand zum Start liegt.
    i = naechster;
  }

  return perioden;
}

/// Ob [tag] eine neue Periode startet (Regel 2.1).
///
/// Der Mindestabstand allein genügt nicht: Blutung vom 1. bis 10., der 11.
/// und 12. frei, am 13. wieder Blutung — der Abstand zum Start ist 12 und
/// damit groß genug, die Lücke von zwei Tagen ist es nicht. **Regel 2
/// schlägt den Mindestabstand**, dreizehn Tage Blutung mit einer kurzen
/// Pause sind eine lange Blutung und nicht zwei Perioden (Spec 2.1,
/// „Der Grenzfall am Ende einer gekappten Periode“ — Festlegung, nicht von
/// Tim freigegeben).
///
/// Gemessen wird gegen den **vorigen Blutungstag überhaupt**, nicht gegen
/// das Ende der letzten Periode: Ein Überhang nach Regel 3 und eine
/// Nebenblutung sind zwar keine Periodentage, aber eben auch keine
/// blutungsfreien Tage.
bool _startetPeriode({
  required String tag,
  required String? letzterStart,
  required String? vorigerBlutungstag,
}) {
  if (letzterStart != null &&
      _abstand(letzterStart, tag) < periodeMindestabstandTage) {
    return false;
  }
  if (vorigerBlutungstag != null &&
      _abstand(vorigerBlutungstag, tag) <= periodeHoechstensLueckeTage + 1) {
    return false;
  }
  return true;
}

/// Der Zyklustag von [tag]: 1 am Periodenstart, danach fortlaufend — oder
/// `null`, wenn [tag] vor der ersten bekannten Periode liegt (Spec 1, 5).
///
/// Ein Zyklus reicht von einem Periodenstart bis zum Tag **vor** dem
/// nächsten; maßgeblich ist deshalb der jüngste Periodenstart, der nicht
/// nach [tag] liegt. **Nach dem letzten bekannten Start zählt der
/// Zyklustag weiter**, auch über die erwartete Länge hinaus: Der laufende
/// Zyklus hat kein Ende, solange kein nächster Start bekannt ist.
///
/// [perioden] darf unsortiert sein (Spec 5).
int? zyklustagAm(String tag, List<Periode> perioden) {
  String? start;
  for (final periode in perioden) {
    if (periode.von.compareTo(tag) > 0) continue;
    if (start == null || periode.von.compareTo(start) > 0) start = periode.von;
  }
  if (start == null) return null;
  return _abstand(start, tag) + 1;
}

/// Kalendertage von [von] bis [bis]; negativ, wenn [bis] früher liegt.
///
/// Wirft eine [FormatException], wenn einer der beiden kein lesbarer
/// ISO-Tag ist — ein Programmierfehler beim Aufrufer, keine Datenlage, und
/// eine stille 0 wäre hier eine falsche Auskunft.
int _abstand(String von, String bis) {
  final tage = BerlinCalendar.daysBetween(from: von, to: bis);
  if (tage == null) {
    throw FormatException('Kein lesbarer ISO-Tag: "$von" oder "$bis"');
  }
  return tage;
}
