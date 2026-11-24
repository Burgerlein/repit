import 'dart:math';

import 'berlin_calendar.dart';
import 'zyklus_perioden.dart';

// Die Vorhersage der nächsten Blutung, des Eisprungs und des fruchtbaren
// Fensters.
//
// Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte 3 und
// 5; Bereich #539, Ticket #591. Die Zahlen stammen aus der von Tim am
// 23.11.2026 freigegebenen Spec; was dort als „Festlegung“ steht, ist nicht
// von Tim freigegeben und hier an der jeweiligen Stelle als solche
// benannt.
//
// **Alles hier ist eine Schätzung aus dem Kalender, keine Messung** und
// erst recht keine Diagnose (`CLAUDE.md`). Die Ansicht muss das sagen; der
// Kern rechnet nur.
//
// Alle Tage sind ISO-Tagesschlüssel. Abstände und Verschiebungen laufen
// über [BerlinCalendar] — nie über eine feste Dauer auf einem Zeitpunkt,
// die über eine Zeitumstellung eine Stunde zu kurz oder zu lang wäre.

/// Wie belastbar die Fruchtbarkeitsschätzung ist (Spec 3.7).
///
/// **Die Namen sind Speicherformat**, sobald ein Zyklus mit seinem Stand
/// abgelegt wird; `verhuetungAn` entscheidet ihn zur Rechenzeit (Spec 4.3).
///
/// `unterHormonellerVerhuetung` heißt **nicht** „sicher“: Kein Tag darf je
/// als sicher dargestellt werden, weder durch Farbe noch durch Weglassen
/// (Spec 3.7).
enum Fruchtbarkeitssicherheit { natuerlich, unterHormonellerVerhuetung }

/// Warum keine Vorhersage vorliegt (Spec 5: „gesetzt, wenn nichts
/// vorliegt“).
///
/// **Die Namen sind Speicherformat**, sobald der Grund in die
/// Mitteilungsplanung wandert (Spec 6.3).
enum VorhersageGrund {
  /// Weniger als zwei verwendbare abgeschlossene Zyklen (Spec 3.1, 3.2,
  /// 3.3). Geraten wird nicht.
  zuWenigDaten,

  /// Ein positiver Schwangerschaftstest nach dem letzten Periodenstart
  /// pausiert die Vorhersage (Spec 3.8).
  pausiertWegenTest,
}

/// Ein Zeitraum von [von] bis [bis] als ISO-Tag, **beide einschließlich**.
///
/// Dient doppelt: als vorhergesagtes Fenster im Ergebnis und als
/// Krankheitszeitraum im Aufruf.
///
/// Werttyp mit `==` und `hashCode` über beide Felder (`CLAUDE.md`).
class Zyklusfenster {
  const Zyklusfenster({required this.von, required this.bis});

  /// Erster Tag des Zeitraums, einschließlich.
  final String von;

  /// Letzter Tag des Zeitraums, einschließlich.
  final String bis;

  @override
  bool operator ==(Object other) =>
      other is Zyklusfenster && other.von == von && other.bis == bis;

  @override
  int get hashCode => Object.hash(von, bis);

  @override
  String toString() => 'Zyklusfenster(von: $von, bis: $bis)';
}

/// Was die Vorhersage über den kommenden Zyklus sagt (Spec 5).
///
/// Liegt keine Vorhersage vor, stehen die Fenster auf `null` und [grund]
/// sagt, warum. Eine leere Vorhersage ist kein Fehler, sondern eine
/// Datenlage: Die Ansicht sagt dann „noch keine Vorhersage“ und zeigt
/// dieselbe Form ungefüllt (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat
/// genau eine Form“).
class Zyklusvorhersage {
  const Zyklusvorhersage({
    required this.sicherheit,
    this.kern,
    this.randVor,
    this.randNach,
    this.eisprung,
    this.fruchtbar,
    this.erwarteteLaenge,
    this.grund,
  });

  /// Die vorhergesagte Blutung: beginnt am erwarteten Tag und ist so lang
  /// wie die erwartete Blutungsdauer `d` (Spec 3.5).
  final Zyklusfenster? kern;

  /// Die `b` Tage vor [kern] — „kann auch hier sein“.
  final Zyklusfenster? randVor;

  /// Die `b` Tage nach [kern] — „kann auch hier sein“.
  final Zyklusfenster? randNach;

  /// Der geschätzte Eisprung als ISO-Tag (Spec 3.6).
  final String? eisprung;

  /// Das fruchtbare Fenster um [eisprung] (Spec 3.6).
  final Zyklusfenster? fruchtbar;

  /// Ob [eisprung] und [fruchtbar] unter hormoneller Verhütung entstanden
  /// sind. Nicht nullbar: Ohne Verhütung steht hier
  /// [Fruchtbarkeitssicherheit.natuerlich].
  final Fruchtbarkeitssicherheit sicherheit;

  /// Der Median der verwendeten Zykluslängen in Tagen.
  ///
  /// `null` bei [VorhersageGrund.zuWenigDaten] — es gibt nachweislich
  /// keinen Median. Bei [VorhersageGrund.pausiertWegenTest] bleibt der
  /// Wert gefüllt, sofern er sich rechnen lässt: Die Statistik ist da, nur
  /// die Vorhersage ruht (Spec 3.8).
  final int? erwarteteLaenge;

  /// Warum keine Vorhersage vorliegt — `null`, wenn eine vorliegt.
  final VorhersageGrund? grund;

  /// **Werttyp, und das ist hier keine Formsache.** `zyklusMonatProvider`
  /// hängt an dieser Vorhersage (Spec 5.1). Ohne `==` wäre jede neu
  /// gebaute Vorhersage ungleich der vorigen, und das Monatsraster würde
  /// bei jedem Lauf neu gerechnet — Fehler `03`, wortgleich im neuen
  /// Code (`CLAUDE.md`).
  @override
  bool operator ==(Object other) =>
      other is Zyklusvorhersage &&
      other.kern == kern &&
      other.randVor == randVor &&
      other.randNach == randNach &&
      other.eisprung == eisprung &&
      other.fruchtbar == fruchtbar &&
      other.sicherheit == sicherheit &&
      other.erwarteteLaenge == erwarteteLaenge &&
      other.grund == grund;

  @override
  int get hashCode => Object.hash(
    kern,
    randVor,
    randNach,
    eisprung,
    fruchtbar,
    sicherheit,
    erwarteteLaenge,
    grund,
  );

  @override
  String toString() =>
      'Zyklusvorhersage(kern: $kern, randVor: $randVor, randNach: $randNach, '
      'eisprung: $eisprung, fruchtbar: $fruchtbar, '
      'sicherheit: ${sicherheit.name}, erwarteteLaenge: $erwarteteLaenge, '
      'grund: ${grund?.name})';
}

/// Wie viele abgeschlossene Zyklen und Perioden höchstens eingehen
/// (Spec 3.1, 3.5).
const int vorhersageZyklenFenster = 6;

/// Zykluslängen außerhalb dieser Grenzen fließen nicht in den Median ein
/// (Spec 3.2) — sie sind entweder Fehleingaben oder etwas, das eine
/// Kalenderrechnung nicht abbildet.
const int zykluslaengeMindestens = 15;

/// Siehe [zykluslaengeMindestens].
const int zykluslaengeHoechstens = 60;

/// Grenzen des Unsicherheitsbands in Tagen (Spec 3.5).
const int unsicherheitsbandMindestens = 1;

/// Siehe [unsicherheitsbandMindestens].
const int unsicherheitsbandHoechstens = 5;

/// Grenzen der erwarteten Blutungsdauer in Tagen (Spec 3.5).
const int blutungsdauerMindestens = 3;

/// Siehe [blutungsdauerMindestens].
const int blutungsdauerHoechstens = 8;

/// Tage zwischen dem geschätzten Eisprung und dem erwarteten Tag der
/// nächsten Blutung (Spec 3.6).
const int eisprungVorlaufTage = 14;

/// Tage des fruchtbaren Fensters **vor** dem geschätzten Eisprung
/// (Spec 3.6).
const int fruchtbarVorTage = 5;

/// Tage des fruchtbaren Fensters **nach** dem geschätzten Eisprung
/// (Spec 3.6).
const int fruchtbarNachTage = 1;

/// Die Vorhersage aus [perioden] (Spec 3.1 bis 3.8).
///
/// * [krankheitstage] sind **Zeiträume**, nicht einzelne Tage: jede Auszeit
///   mit `art = krankheit`. Der Name bleibt, weil die Tests ihn tragen.
/// * [hormonell]: ob zur Rechenzeit hormonelle Verhütung eingetragen ist.
/// * [pausiert]: ob ein positiver Test nach dem letzten Periodenstart
///   vorliegt. **Das stellt die App fest, nicht der Kern** (Spec 3.8,
///   Festlegung): Der Provider hat die Tageseinträge ohnehin, der Kern
///   bekommt nur das Ergebnis.
/// * [heute] geht in die Rechnung **nicht** ein (Spec 3.1, Festlegung):
///   Die Vorhersage ist am letzten Periodenstart verankert, und 3.6 sagt
///   ausdrücklich, dass Zurückliegendes nicht nachträglich verändert wird.
///   Derselbe Datenstand ergibt an jedem Tag dasselbe Ergebnis. Der
///   Parameter bleibt, weil die App den Tag ohnehin führt und eine spätere
///   Regel ihn brauchen könnte.
///
/// [perioden] darf unsortiert sein (Spec 5).
///
/// Wirft eine [FormatException], wenn ein Tag kein lesbarer ISO-Tag ist.
/// **Zu `krankheitstage`:** Ihre Tage werden nur verglichen, nie geparst.
/// Ein unlesbarer oder nicht aufgefüllter Schlüssel (`2099-1-2` statt
/// `2099-01-02`) wirft deshalb **nicht**, sondern sortiert lexikografisch
/// falsch und verfehlt den Zyklus, den er treffen sollte — die Krankheit
/// zählt dann nicht, und das Band bleibt zu schmal, ohne dass es jemand
/// merkt. Ein Fenster mit `von` nach `bis` wird ebenfalls nicht
/// abgewiesen. Beides ist Pflicht des Aufrufers; die Zusage einer
/// `FormatException` oben gilt nur für `perioden`
/// (Fund des Review-Agenten, 24.11.2026).
Zyklusvorhersage zyklusVorhersage({
  required List<Periode> perioden,
  required String heute,
  required List<Zyklusfenster> krankheitstage,
  required bool hormonell,
  required bool pausiert,
}) {
  final sicherheit = hormonell
      ? Fruchtbarkeitssicherheit.unterHormonellerVerhuetung
      : Fruchtbarkeitssicherheit.natuerlich;

  final sortiert = [...perioden]..sort((a, b) => a.von.compareTo(b.von));
  final statistik = _Statistik.aus(sortiert, krankheitstage);

  // Rangfolge der Gründe (Spec 3.8, Festlegung): Liegt `pausiert` an und
  // fehlen Daten, gilt `pausiertWegenTest`. Wer pausiert hat, hat
  // entschieden; „noch keine Vorhersage“ wäre dann die unwichtigere
  // Auskunft.
  if (pausiert) {
    return Zyklusvorhersage(
      sicherheit: sicherheit,
      erwarteteLaenge: statistik?.erwarteteLaenge,
      grund: VorhersageGrund.pausiertWegenTest,
    );
  }

  if (statistik == null) {
    return Zyklusvorhersage(
      sicherheit: sicherheit,
      grund: VorhersageGrund.zuWenigDaten,
    );
  }

  final erwarteterTag = _tagPlus(sortiert.last.von, statistik.erwarteteLaenge);
  final band = statistik.band;
  final kernBis = _tagPlus(erwarteterTag, statistik.blutungsdauer - 1);
  final eisprung = _tagPlus(erwarteterTag, -eisprungVorlaufTage);

  return Zyklusvorhersage(
    sicherheit: sicherheit,
    kern: Zyklusfenster(von: erwarteterTag, bis: kernBis),
    randVor: Zyklusfenster(
      von: _tagPlus(erwarteterTag, -band),
      bis: _tagPlus(erwarteterTag, -1),
    ),
    randNach: Zyklusfenster(
      von: _tagPlus(kernBis, 1),
      bis: _tagPlus(kernBis, band),
    ),
    eisprung: eisprung,
    fruchtbar: Zyklusfenster(
      von: _tagPlus(eisprung, -fruchtbarVorTage),
      bis: _tagPlus(eisprung, fruchtbarNachTage),
    ),
    erwarteteLaenge: statistik.erwarteteLaenge,
  );
}

/// Was sich aus den vergangenen Zyklen rechnen lässt — oder nichts.
class _Statistik {
  const _Statistik({
    required this.erwarteteLaenge,
    required this.band,
    required this.blutungsdauer,
  });

  final int erwarteteLaenge;
  final int band;
  final int blutungsdauer;

  /// `null`, wenn weniger als zwei verwendbare abgeschlossene Zyklen
  /// übrig bleiben (Spec 3.1, 3.2, 3.3).
  ///
  /// [perioden] muss nach `von` aufsteigend sortiert sein.
  static _Statistik? aus(
    List<Periode> perioden,
    List<Zyklusfenster> krankheitstage,
  ) {
    // Ein Zyklus reicht von einem Periodenstart bis zum Tag **vor** dem
    // nächsten (Spec 1). Der laufende zählt nicht mit, weil kein nächster
    // Start bekannt ist (Spec 3.1).
    final zyklen = <_Zyklus>[
      for (var i = 0; i + 1 < perioden.length; i++)
        _Zyklus(
          von: perioden[i].von,
          bis: _tagPlus(perioden[i + 1].von, -1),
          laenge: _abstand(perioden[i].von, perioden[i + 1].von),
        ),
    ];
    final letzte = zyklen.sublist(
      max(0, zyklen.length - vorhersageZyklenFenster),
    );

    // 3.2 vor 3.3 (Festlegung, nicht von Tim freigegeben): Ein Ausreißer
    // ist schon ganz draußen, und das Band für ihn ein zweites Mal zu
    // weiten, bestrafte denselben Zyklus doppelt. 3.2 weitet es nicht.
    final brauchbare = letzte
        .where(
          (z) =>
              z.laenge >= zykluslaengeMindestens &&
              z.laenge <= zykluslaengeHoechstens,
        )
        .toList();

    final krank = brauchbare
        .where((z) => krankheitstage.any(z.ueberlappt))
        .length;
    final laengen = brauchbare
        .where((z) => !krankheitstage.any(z.ueberlappt))
        .map((z) => z.laenge)
        .toList();
    if (laengen.length < 2) return null;

    // Band `b`: Spannweite der verwendeten Längen, halbiert und
    // aufgerundet, gekappt — dazu je ein Tag für jeden Krankheitszyklus,
    // in Summe ebenfalls höchstens 5 (Spec 3.3, 3.5). Hormonelle
    // Verhütung weitet es für sich allein nicht (Spec 3.7); deshalb steht
    // sie hier gar nicht.
    final spannweite = laengen.reduce(max) - laengen.reduce(min);
    final grundband = min(
      unsicherheitsbandHoechstens,
      max(unsicherheitsbandMindestens, (spannweite / 2).ceil()),
    );

    // Die erwartete Blutungsdauer `d` hängt an den Perioden selbst, nicht
    // an den Zyklen: Sie überlebt auch Krankheit und Ausreißer (Spec 3.5).
    //
    // **Offen (#595):** Die letzte Periode zählt hier mit, auch wenn sie
    // gerade erst begonnen hat und dann einen Tag lang ist. Bei der
    // Mindestdatenlage kippt das sichtbar — aus 7 und 3 wird der Median
    // 5, mit einem frischen Ein-Tages-Eintrag wird er 3. Das Fenster
    // würde also ausgerechnet dann kürzer, wenn eine Periode anfängt.
    // Ein Test hält die heutige Lesart fest; die Änderung wäre eine
    // fachliche Entscheidung und gehört Tim, nicht der Nacht.
    final periodenlaengen = [
      for (final periode in perioden.sublist(
        max(0, perioden.length - vorhersageZyklenFenster),
      ))
        _abstand(periode.von, periode.bis) + 1,
    ];

    return _Statistik(
      erwarteteLaenge: _median(laengen),
      band: min(unsicherheitsbandHoechstens, grundband + krank),
      blutungsdauer: min(
        blutungsdauerHoechstens,
        max(blutungsdauerMindestens, _median(periodenlaengen)),
      ),
    );
  }
}

/// Ein abgeschlossener Zyklus: von einem Periodenstart bis zum Tag vor dem
/// nächsten, beide Grenzen einschließlich.
class _Zyklus {
  const _Zyklus({required this.von, required this.bis, required this.laenge});

  final String von;
  final String bis;
  final int laenge;

  /// Ob [fenster] mindestens einen Tag dieses Zyklus trifft (Spec 3.3).
  bool ueberlappt(Zyklusfenster fenster) =>
      fenster.von.compareTo(bis) <= 0 && von.compareTo(fenster.bis) <= 0;
}

/// Der Median von [werte], auf ganze Tage **kaufmännisch gerundet**
/// (Spec 3.4 — dieselbe Rundung gilt überall, wo hier ein Median steht).
///
/// [werte] darf nicht leer sein; der einzige Aufrufer prüft das vorher.
int _median(List<int> werte) {
  final sortiert = [...werte]..sort();
  final mitte = sortiert.length ~/ 2;
  if (sortiert.length.isOdd) return sortiert[mitte];
  // `round()` rundet von der Null weg, bei positiven Tagen also 0,5 auf.
  return ((sortiert[mitte - 1] + sortiert[mitte]) / 2).round();
}

/// Der ISO-Tag [tage] Kalendertage nach [tag]; negative Werte gehen zurück.
///
/// Gerechnet über [BerlinCalendar.addDays], also über das Datum — nie über
/// `tage · 24 h`, was über eine Zeitumstellung eine Stunde danebenläge.
/// Der Tag wird dafür als 12:00 UTC gelesen: Das liegt bei +1 h wie bei
/// +2 h sicher im Berliner Tag desselben Datums.
String _tagPlus(String tag, int tage) => BerlinCalendar.dayKey(
  BerlinCalendar.addDays(DateTime.parse('${tag}T12:00:00Z'), tage),
);

/// Kalendertage von [von] bis [bis]; negativ, wenn [bis] früher liegt.
///
/// Dieselbe Rechnung wie in `zyklus_perioden.dart`, bewusst doppelt: Ein
/// gemeinsamer Helfer müsste öffentlich sein und stünde dann als
/// Kern-API da, die die Spec nicht kennt.
int _abstand(String von, String bis) {
  final tage = BerlinCalendar.daysBetween(from: von, to: bis);
  if (tage == null) {
    throw FormatException('Kein lesbarer ISO-Tag: "$von" oder "$bis"');
  }
  return tage;
}
