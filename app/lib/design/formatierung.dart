import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:trainings_core/trainings_core.dart';

/// Datumsformate der App — Dart-Entsprechung von
/// `Sources/DesignSystem/Formatting.swift`.
///
/// `DateFormat` richtet sich ohne ausdrückliche Locale nach
/// `Intl.defaultLocale` — der Dart-Entsprechung zu
/// `Locale.autoupdatingCurrent` in Swift. Genau das war der Fehler, den
/// `Formatting.swift:6-10` beschreibt: Ohne feste Locale stand auf einem
/// englisch eingestellten Gerät „6. Oct 2026“ mitten im deutschen Text. Die
/// App ist einsprachig deutsch, also setzt `Format` die Locale **fest** auf
/// `de_DE`, unabhängig von `Intl.defaultLocale` — jede Methode gibt sie
/// ausdrücklich mit, siehe `test/design/formatierung_test.dart`.
class Format {
  Format._();

  static const _locale = 'de_DE';
  static bool _initialisiert = false;

  /// `initializeDateFormatting` liefert für mitgelieferte („lokale“) Daten
  /// bereits beim Aufruf einen abgeschlossenen Future — das Ergebnis steht
  /// unmittelbar danach synchron zur Verfügung. Unawaited mit Absicht:
  /// `Format` bleibt synchron aufrufbar, wie die Swift-Vorlage. Tests rufen
  /// `initializeDateFormatting` zusätzlich selbst in `setUpAll` auf (siehe
  /// `formatierung_test.dart`) — doppelte Initialisierung ist unschädlich,
  /// diese hier sichert den Fall ab, dass das niemand sonst für die echte
  /// App erledigt.
  static void _sicherstellen() {
    if (_initialisiert) return;
    _initialisiert = true;
    // ignore: discarded_futures
    initializeDateFormatting(_locale);
  }

  /// 06.10.2026
  static String tag(DateTime datum) {
    _sicherstellen();
    return DateFormat('dd.MM.yyyy', _locale).format(datum);
  }

  /// „Montag, 12. Oktober“ — die Datumszeile über einem Schirm, ohne
  /// Jahreszahl und ohne Ziffernformat.
  ///
  /// Gedacht für einen **Kalendertag**, nicht für einen Zeitpunkt: Der
  /// Aufrufer übergibt den Tag, den er meint (siehe `erholung_view.dart`,
  /// das ihn aus `BerlinCalendar.dayKey` baut) — ein roher UTC-Zeitpunkt
  /// kurz nach Berliner Mitternacht trüge hier sonst das Vortagsdatum.
  static String wochentagUndDatum(DateTime tag) {
    _sicherstellen();
    return DateFormat('EEEE, d. MMMM', _locale).format(tag);
  }

  /// „27. Oktober 2026“ — die Datumszeile über dem Erholung-Schirm.
  ///
  /// Der ausgeschriebene Monat statt der Ziffernform, Punkt nur hinter dem
  /// Tag und **ohne führende Null** („6. Oktober 2026“). Weder [tag]
  /// („27.10.2026“) noch [wochentagUndDatum] („Dienstag, 27. Oktober“,
  /// ohne Jahr) passen dafür.
  ///
  /// Wie [wochentagUndDatum] für einen **Kalendertag** gedacht, nicht für
  /// einen Zeitpunkt.
  static String datumAusgeschrieben(DateTime tag) {
    _sicherstellen();
    return DateFormat('d. MMMM y', _locale).format(tag);
  }

  /// „1. Dezember“ — Tag und ausgeschriebener Monat, ohne Jahr. Für eine
  /// Frist im laufenden Jahr („bis zum 1. Dezember“, KI-Zugang).
  ///
  /// Wie [datumAusgeschrieben] für einen **Kalendertag** gedacht.
  static String tagMonatAusgeschrieben(DateTime tag) {
    _sicherstellen();
    return DateFormat('d. MMMM', _locale).format(tag);
  }

  /// „11.10.“ — Tag und Monat ohne Jahr, für die Nachtkarte („Mo 11.10. ·
  /// 23:10–06:15“). Das Jahr steht dort schon in der Datumszeile oben.
  static String tagMonat(DateTime tag) {
    _sicherstellen();
    return DateFormat('dd.MM.', _locale).format(tag);
  }

  /// „Mo.“ — der abgekürzte Wochentag, für die Nachtkarte („Mo. 11.10.“).
  ///
  /// **Mit Punkt.** `intl` schreibt die deutsche Kurzform so; eine frühere
  /// Fassung dieses Kommentars versprach „Mo“ ohne Punkt, und das stimmte
  /// nie. Das Entwurfsboard schreibt sie ohne — wer das angleichen will,
  /// entscheidet damit über eine Schreibweise und nicht über einen
  /// Tippfehler.
  static String wochentagKurz(DateTime tag) {
    _sicherstellen();
    return DateFormat('EEE', _locale).format(tag);
  }

  /// „Mittwoch“ — der ausgeschriebene Wochentag **allein**, ohne Datum
  /// (#77).
  ///
  /// Für den Lede des Gym-Schirms („Montag, Mittwoch, Donnerstag“) und für
  /// „Nächstes Krafttraining: Mittwoch, Gym B — …“ auf der Fokus-Karte.
  /// [wochentagKurz] liefert „Mi.“ und [wochentagUndDatum] „Mittwoch, 12.
  /// November“ — das eine nennt zu wenig, das andere zu viel. Der Entwurf
  /// nennt den nächsten Termin bewusst beim Wochentag und nicht als
  /// Abstand in Tagen: „Mittwoch“ ist eindeutig, „in 2 Tagen“ muss man
  /// nachrechnen (`GymFocusText.weekdayName`).
  ///
  /// Wie [wochentagUndDatum] für einen **Kalendertag** gedacht — der
  /// Aufrufer schickt den Zeitpunkt durch [kalendertag], sonst trägt ein
  /// Berliner Tagesbeginn in UTC den Vortag.
  static String wochentag(DateTime tag) {
    _sicherstellen();
    return DateFormat('EEEE', _locale).format(tag);
  }

  /// „Montag, 16.11.“ — Wochentag ausgeschrieben, Tag und Monat in
  /// Ziffern, **ohne Jahr** (#77).
  ///
  /// Für den Wiedereinstieg nach der OP auf der Gym-Fokus-Karte. Den Grund
  /// für das fehlende Jahr nennt die Swift-Vorlage
  /// (`GymFocusText.dayAndDate`): „ohne Jahr, die Karte ist schmal“.
  ///
  /// **Zusammengesetzt aus [wochentag] und [tagMonat]**, statt ein eigenes
  /// Muster zu tippen: Sonst stünde die Ziffernform desselben Datums an
  /// zwei Stellen und liefe beim nächsten Wortlautwechsel auseinander.
  ///
  /// **Mit führender Null** („Montag, 06.11.“), weil [tagMonat] sie setzt.
  /// Die Swift-Vorlage schreibt dort `.day()` ohne Null; welche der beiden
  /// Schreibweisen gilt, ist eine Entscheidung und kein Tippfehler —
  /// dieselbe offene Frage wie beim Punkt in [wochentagKurz].
  ///
  /// Wie [wochentag] für einen **Kalendertag** gedacht.
  static String wochentagUndTagMonat(DateTime tag) =>
      '${wochentag(tag)}, ${tagMonat(tag)}';

  /// „So. → Mo.“ — die **Nacht**, benannt nach beiden Enden (#212).
  ///
  /// Übergeben wird der **Aufwachtag**, unter dem die Nacht abgelegt ist
  /// (`SleepGrouping.nights`: Schlüssel ist der Tag, an dem die Phase
  /// endet; dazu `nextDayHour = 18`, „wer abends einschläft, meint die
  /// kommende Nacht“). Apple Health ordnet genauso zu. Nur sagte „Mo.
  /// 02.11.“ das nicht: Es ließ offen, ob die Nacht *auf* Montag oder die
  /// Nacht *von* Montagabend gemeint war — Tims Beobachtung auf dem Gerät
  /// am 02.11.2026.
  ///
  /// **Nur dort, wo wirklich nur die Nacht steht.** Die Kopfzeile eines
  /// Schirms nennt weiter den Tag (Tims Entscheidung vom 02.11.2026): Sie
  /// ist die Klammer über Nacht **und** Nickerchen, und „Nacht auf …“
  /// beschriftete die eine Hälfte richtig und die andere falsch.
  ///
  /// Der Vorabend kommt über `BerlinCalendar.addDays`, nicht über
  /// `subtract(const Duration(days: 1))`: Minus 24 Stunden landet über
  /// eine Zeitumstellung hinweg einen Tag zu früh. Beide Enden gehen
  /// anschließend durch [kalendertag] — `addDays` gibt wie
  /// `BerlinCalendar.startOfDay` den UTC-Zeitpunkt der Berliner
  /// Mitternacht zurück, dessen UTC-Datum im Sommer der Vortag ist.
  static String nachtSpanne(DateTime aufwachtag) {
    final abend = kalendertag(BerlinCalendar.addDays(aufwachtag, -1));
    return '${wochentagKurz(abend)} → '
        '${wochentagKurz(kalendertag(aufwachtag))}';
  }

  /// „Nov“ — der abgekürzte Monatsname, für die Diagrammachse ab `6M`.
  ///
  /// Bis zum 28.10.2026 stand dort [tagMonat], also „01.11.“, „01.12.“; bei
  /// zwölf Monaten stand die „01.“ zwölfmal da und sagte nichts. Tims
  /// Entscheidung nach einer Prüfung auf dem Gerät: Monatsnamen (#149). Das
  /// Entwurfsboard macht es für Monatsdiagramme längst so
  /// (`docs/screens/screens/gym-progress.js`, `xLabels: MONTHS`).
  ///
  /// **Ohne Punkt**, anders als [wochentagKurz] — das ist keine Wahl,
  /// sondern das, was `intl` für `de_DE` liefert („Jan“, „Mär“, „Nov“), und
  /// es deckt sich mit dem Wortlaut des Entwurfsboards. Festgenagelt für
  /// alle zwölf Monate in `test/design/formatierung_test.dart`.
  ///
  /// Der Tag im übergebenen Datum spielt keine Rolle; die Achse reicht den
  /// Monatsersten herein. Wie [wochentagUndDatum] für einen
  /// **Kalendertag** gedacht — der Aufrufer schickt ihn durch
  /// [kalendertag], sonst trägt ein Monatserster in UTC den Vormonat.
  static String monatKurz(DateTime tag) {
    _sicherstellen();
    return DateFormat('MMM', _locale).format(tag);
  }

  /// „Oktober 2026" — der Kopf des Kalenderblatts (#177).
  ///
  /// **Ausgeschrieben, nicht wie [monatKurz]:** Über einem Monatsraster
  /// steht kein Achsenwert, sondern der Name des Monats, den man gerade
  /// ansieht. Wie [wochentagUndDatum] für einen **Kalendertag** gedacht —
  /// der Aufrufer schickt ihn durch [kalendertag], sonst trägt ein
  /// Monatserster in UTC den Vormonat.
  static String monatUndJahr(DateTime tag) {
    _sicherstellen();
    return DateFormat('MMMM y', _locale).format(tag);
  }

  /// 14:32
  ///
  /// Öffentlich, weil [StandZeile] in `stand_zeile.dart` nur die Uhrzeit
  /// braucht, nicht den Abstandstext aus [zuletztAktualisiert] — nach
  /// `CLAUDE.md` läuft jede Zeitangabe über `Format`, keine eigene
  /// Formatierung in einem einzelnen Baustein.
  static String uhrzeit(DateTime datum) {
    _sicherstellen();
    return DateFormat('HH:mm', _locale).format(datum);
  }

  /// „14:32 · gerade eben“, bei einem Stand von einem anderen Tag als
  /// `jetzt` mit Datum davor: „06.10.2026, 14:32 · vor 3 Minuten“.
  ///
  /// `jetzt` kommt von außen herein statt aus `DateTime.now()`, damit diese
  /// Funktion deterministisch testbar bleibt — dasselbe Prinzip wie bei
  /// `alsMesswert` in `lib/core/async_bruecke.dart`. Ohne Angabe gilt die
  /// tatsächliche aktuelle Zeit, wie es der Ein-Argument-Aufruf aus dem
  /// Task-Brief erwartet.
  static String zuletztAktualisiert(DateTime stand, {DateTime? jetzt}) {
    final referenz = jetzt ?? DateTime.now();
    final stempel = _selberTag(stand, referenz)
        ? uhrzeit(stand)
        : '${tag(stand)}, ${uhrzeit(stand)}';
    return '$stempel · ${_abstand(stand, referenz)}';
  }

  /// Der Zeitstempel der Stand-Zeile: „16:31" am selben Tag, sonst
  /// „gestern 21:58" oder „27.10., 21:58" (#200).
  ///
  /// **Warum nicht [zuletztAktualisiert]:** Das hängt „· vor 3 Minuten"
  /// an. Die Stand-Zeile sagt nur, *wann* gelesen wurde; der Abstand wäre
  /// eine zweite Angabe und machte die Zeile zweizeilig — und eine Zeile,
  /// die mal ein-, mal zweizeilig ist, verschiebt alles darunter.
  ///
  /// **Der Tagesvergleich läuft über die rohen Kalenderfelder**
  /// ([_selberTag]), nicht über `BerlinCalendar.dayKey`. [uhrzeit]
  /// formatiert die Felder eines `DateTime`; `dayKey` deutet denselben
  /// Wert als Instant und rechnet ihn nach Berlin. Wer beides mischt,
  /// nimmt die Uhrzeit aus der einen und den Tag aus der anderen Lesart —
  /// bei einem Stand um 23:30 stünde „gestern 23:30" neben einer Uhrzeit,
  /// die zu diesem „gestern" nicht gehört. In der App ist der Stand ein
  /// lokaler Zeitpunkt (`clockProvider` ist `DateTime.now()`), also
  /// fallen beide Lesarten zusammen.
  ///
  /// **„Gestern" meint den Kalendertag davor**, nicht „vor weniger als 24
  /// Stunden": Ein Stand von 23:50 ist um 00:10 zwanzig Minuten alt und
  /// trotzdem von gestern. Wer nach Dauer rechnet, nennt ihn „heute" und
  /// behauptet damit einen Zeitpunkt, der an diesem Tag noch bevorsteht —
  /// genau der Fehler aus #200.
  static String standZeitpunkt(DateTime stand, {required DateTime jetzt}) {
    if (_selberTag(stand, jetzt)) return uhrzeit(stand);

    final gestern = DateTime(jetzt.year, jetzt.month, jetzt.day - 1);
    if (_selberTag(stand, gestern)) return 'gestern ${uhrzeit(stand)}';

    return '${tagMonat(stand)}, ${uhrzeit(stand)}';
  }

  static bool _selberTag(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// „gerade eben“ unter einer Minute, sonst „vor X Minuten/Stunden/Tagen“.
  /// Unter einer Minute rundet eine Angabe wie „vor 0 Minuten“ auf etwas,
  /// das wie eine Zukunftsform klingt — genau das, was
  /// `Formatting.swift:67-69` für den Swift-Fall vermeidet.
  static String _abstand(DateTime stand, DateTime jetzt) {
    final differenz = jetzt.difference(stand);
    final sekunden = differenz.inSeconds.abs();
    if (sekunden < 60) return 'gerade eben';

    final istVergangenheit = !differenz.isNegative;
    String richtung(String text) => istVergangenheit ? 'vor $text' : 'in $text';

    final minuten = differenz.inMinutes.abs();
    if (minuten < 60) {
      return richtung('$minuten Minute${minuten == 1 ? '' : 'n'}');
    }

    final stunden = differenz.inHours.abs();
    if (stunden < 24) {
      return richtung('$stunden Stunde${stunden == 1 ? '' : 'n'}');
    }

    final tage = differenz.inDays.abs();
    return richtung('$tage Tag${tage == 1 ? '' : 'en'}');
  }
}

/// Der **Kalendertag** zu einem Zeitpunkt, als reines Datum.
///
/// Nicht `BerlinCalendar.startOfDay`: Das liefert den UTC-Zeitpunkt der
/// Berliner Mitternacht (im Sommer 22:00 des Vortags) — formatiert stünde
/// dort der falsche Tag. Alles, was ein Datum **anzeigt**, geht durch hier.
///
/// **Warum die Funktion hier wohnt — Entscheidung des Umsetzungsagenten von
/// #130, nicht Tims; er hat sie nie gesehen.** Bis zum 28.10.2026 stand sie
/// in `shell/erholung_abschnitte.dart`. Dort konnte `design/zeitdiagramm*`
/// sie nicht benutzen, ohne die Abhängigkeitsrichtung umzudrehen: `shell`
/// hängt von `design` ab, nie umgekehrt. Und genau dort fehlte sie — die
/// Kopfzeile und die Achse des Diagramms zeigten jedes Datum einen Tag zu
/// früh. Sie neben `Format` zu legen ist der Schnitt, der zu ihr passt: Sie
/// löst kein Kalenderproblem, sondern ein Anzeigeproblem, und sie gehört vor
/// jeden `Format.*`-Aufruf, der einen Tag benennt.
DateTime kalendertag(DateTime zeitpunkt) {
  final teile = BerlinCalendar.dayKey(zeitpunkt)
      .split('-')
      .map(int.parse)
      .toList();
  return DateTime.utc(teile[0], teile[1], teile[2]);
}
