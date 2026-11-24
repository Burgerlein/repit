import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:repit/design/formatierung.dart';

/// Tests für `Format` (Task 9, `lib/design/formatierung.dart`) — die
/// Dart-Entsprechung von `Sources/DesignSystem/Formatting.swift`.
///
/// **Der Fehler, gegen den hier getestet wird** (CLAUDE.md und
/// `Formatting.swift:6-10`): `Date.formatted(…)` nahm in der Swift-App die
/// Sprache aus der Gerätezeitzone/-locale und ignorierte eine ausdrücklich
/// gesetzte Umgebung — auf einem englisch eingestellten Gerät stand „6. Oct
/// 2026" mitten im deutschen Text. `Format` muss die Locale **fest** auf
/// `de_DE` setzen, unabhängig von der Umgebung.
///
/// **Wie die andere Locale erzwungen wird:** Dart/`intl` kennt kein
/// Gegenstück zu `Locale.autoupdatingCurrent`, aber die Stelle, die
/// `DateFormat` befragt, wenn ihm keine Locale ausdrücklich mitgegeben wird,
/// ist `Intl.defaultLocale`. Das ist die Entsprechung zur Geräte-Locale aus
/// der Swift-Fehlerbeschreibung. Ein Test, der `Intl.defaultLocale` auf
/// `en_US` setzt und danach `Format.tag` aufruft, bildet das englisch
/// eingestellte Gerät nach.
///
/// **Nachgemessen, ob das wirklich beißt** (siehe `task-9-tests-report.md`
/// für die vollständige Messung): Ein literales Zahlen-Pattern
/// (`DateFormat('dd.MM.yyyy')`) ändert sich durch `Intl.defaultLocale`
/// **nicht** — es hat keine textuellen Monats- oder Wochentagsnamen, an
/// denen sich eine Locale zeigen könnte. Ein locale-abhängiges Skeleton wie
/// `DateFormat.yMd()` dagegen schon: `06.10.2026` unter `de_DE` wird zu
/// `10/6/2026` unter `en_US` — Tag und Monat tauschen die Reihenfolge. Genau
/// dieser Unterschied ist es, den die Tests unten abfragen: Sie beißen nicht,
/// weil sich ein Monatsname ändert (es gibt hier keinen), sondern weil eine
/// vertauschte Tag/Monat-Reihenfolge ein falsches Datum ergäbe.
///
/// **Was `Format.tag` tatsächlich liefern muss:** Der Task-Brief nennt als
/// Beispiel „6. Okt. 2026" — das ist aber **nicht** die Ausgabe von
/// `Format.day` aus `Formatting.swift` (dem naheliegenden Vorbild für
/// `Format.tag`), sondern eines ganz anderen, dort nicht exponierten
/// Zwischenformats, das nur innerhalb von `dayRange` auftaucht
/// (`.day().month(.abbreviated).year()`, ohne `.twoDigits`). Nachgemessen mit
/// einem kleinen Swift-Skript (siehe Bericht) liefert `Format.day` für den
/// 6. Oktober 2026 tatsächlich **"06.10.2026"**
/// (`.day(.twoDigits).month(.twoDigits).year()`). Laut Auftrag gewinnt die
/// echte Swift-Ausgabe gegen die Vermutung im Brief — die Tests unten prüfen
/// deshalb "06.10.2026", nicht "6. Okt. 2026".
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    await initializeDateFormatting('en_US');
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  group('Format.tag', () {
    test('formatiert Tag, Monat und Jahr zweistellig, deutsch', () {
      expect(Format.tag(DateTime.utc(2026, 10, 6)), '06.10.2026');
    });

    test('bleibt deutsch formatiert, auch wenn die Umgebung Englisch ist', () {
      // Entspricht dem englisch eingestellten Gerät aus Formatting.swift:6-10.
      Intl.defaultLocale = 'en_US';

      expect(Format.tag(DateTime.utc(2026, 10, 6)), '06.10.2026');
    });

    test('vertauscht Tag und Monat nicht unter einer englischen Umgebung', () {
      // Ergänzender Beleg: Mit Tag 25 kann "25" nicht als Monat 25
      // missverstanden werden — ein vertauschtes Format würde hier sofort an
      // einem offensichtlich falschen Wert auffallen, nicht nur an einer
      // anderen Reihenfolge zweier gültiger Zahlen.
      Intl.defaultLocale = 'en_US';

      expect(Format.tag(DateTime.utc(2026, 1, 25)), '25.01.2026');
    });
  });

  /// Neu am 27.10.2026, für die Datumszeile des Erholung-Schirms. Tim:
  /// „lass uns das Datum mittig hin platzieren, so 27.Oktober.2026. Aber
  /// den Text drum rum nicht."
  ///
  /// **Die Schreibweise ist ausgelegt, nicht abgeschrieben:** Tim hat
  /// Punkte zwischen alle drei Teile getippt; „27.Oktober.2026" ist im
  /// Deutschen keine übliche Form. Gemeint ist der ausgeschriebene Monat
  /// statt der Ziffernform — also **„27. Oktober 2026"**, Punkt nur hinter
  /// dem Tag. Der Koordinator hat Tim diese Auslegung angesagt.
  ///
  /// Keine der vorhandenen Methoden passt: `tag` ist die Ziffernform
  /// („27.10.2026"), `wochentagUndDatum` trägt den Wochentag und **kein**
  /// Jahr („Dienstag, 27. Oktober"). Deshalb eine eigene.
  group('Format.datumAusgeschrieben', () {
    test('Tag, ausgeschriebener Monat, Jahr — ohne Wochentag', () {
      expect(
        Format.datumAusgeschrieben(DateTime.utc(2026, 10, 27)),
        '27. Oktober 2026',
      );
    });

    test('der Tag steht ohne führende Null', () {
      expect(
        Format.datumAusgeschrieben(DateTime.utc(2026, 10, 6)),
        '6. Oktober 2026',
      );
    });

    test('bleibt deutsch, auch wenn die Umgebung Englisch ist', () {
      // Hier beißt die Locale sichtbarer als bei `Format.tag`: Der
      // Monatsname ist der Unterschied, und „6. October 2026" mitten im
      // deutschen Text ist genau der Fehler aus Formatting.swift:6-10.
      Intl.defaultLocale = 'en_US';

      expect(
        Format.datumAusgeschrieben(DateTime.utc(2026, 10, 6)),
        '6. Oktober 2026',
      );
    });
  });

  group('Format.zuletztAktualisiert', () {
    // Diese Gruppe testet nur den Teil, der ohne Bezug auf die echte
    // Systemzeit deterministisch ist. Siehe Bericht: Schon Swifts eigenes
    // `.relative(presentation: .numeric)` (Formatting.swift:70) hat keinen
    // Weg, einen Bezugszeitpunkt ungleich der tatsächlichen Systemzeit
    // hineinzureichen — nachgemessen mit einem Swift-Skript, das trotz
    // synthetischer Zeitdifferenzen immer densel­ben, an der echten
    // Systemzeit gemessenen Text lieferte. Welchen Mechanismus die
    // Dart-Seite für den Abstandstext ("vor 5 Minuten" o. Ä.) wählt, ist
    // deshalb nicht Gegenstand dieser Tests.

    test('zeigt "gerade eben", wenn Stand und Jetzt zusammenfallen', () {
      final stand = DateTime.utc(2026, 10, 6, 14, 32);

      expect(
        Format.zuletztAktualisiert(stand, jetzt: stand),
        '14:32 · gerade eben',
      );
    });

    test('zeigt nur die Uhrzeit als Stand, solange Stand und Jetzt am selben Tag liegen', () {
      final stand = DateTime.utc(2026, 10, 6, 14, 32);
      final jetzt = stand.add(const Duration(minutes: 5));

      final text = Format.zuletztAktualisiert(stand, jetzt: jetzt);

      expect(text, startsWith('14:32 · '));
    });

    test('zeigt Datum und Uhrzeit als Stand, wenn Stand und Jetzt an verschiedenen Tagen liegen', () {
      final stand = DateTime.utc(2026, 10, 6, 14, 32);
      final jetzt = stand.add(const Duration(days: 2));

      final text = Format.zuletztAktualisiert(stand, jetzt: jetzt);

      expect(text, startsWith('06.10.2026, 14:32 · '));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #149 — der kurze Monatsname für die Diagrammachse
  //
  // Bei `6M` und `J` beschriftete die Achse mit `Format.tagMonat`, also
  // „01.11.", „01.12.". Bei zwölf Monaten steht die „01." zwölfmal da und
  // sagt nichts. Tim hat am 28.10.2026 entschieden: Monatsnamen.
  //
  // **Hier, nicht im Diagramm.** Datumsformate wohnen gesammelt in `Format`,
  // mit fest gesetzter Sprache — ein `DateFormat` im Diagramm läse die
  // Sprache aus `Intl.defaultLocale` und schriebe auf einem englisch
  // eingestellten Gerät „Nov" neben „Mär".
  //
  // **Entscheidungen dieser Ergänzung — vom Test-Agenten, nicht von Tim:**
  //
  // a) **Der Wortlaut wird festgenagelt, anders als sonst.** `CLAUDE.md`
  //    verbietet Tests auf Beschriftungen in **Views**; `Format` ist aber
  //    selbst die Beschriftungsschicht, und jede andere Methode dieser
  //    Datei wird genauso geprüft („06.10.2026", „6. Oktober 2026").
  // b) **Alle zwölf Monate.** Die deutschen Kurzformen sind nicht
  //    gleichförmig — `intl` kürzt „März" auf „Mär", und ob eine Form einen
  //    Punkt trägt, entscheidet CLDR je Sprache. Ein Test auf einen
  //    einzelnen Monat ließe offen, was in den anderen elf steht.
  // c) **Ohne Punkt — und das ist hier eine Beobachtung, keine Wahl.**
  //    `Format.wochentagKurz` liefert „Mo." **mit** Punkt, das
  //    Entwurfsboard schreibt sie ohne; der Doc-Kommentar dort hält diesen
  //    Unterschied ausdrücklich fest. Bei den Monaten fallen beide
  //    zusammen: `intl` liefert für `de_DE` „Nov", und
  //    `docs/screens/screens/gym-progress.js` schreibt
  //    `['Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt']`. Der Test nagelt damit
  //    zugleich fest, dass Board und App dasselbe sagen.
  // ═══════════════════════════════════════════════════════════════════════

  group('Format.monatKurz', () {
    test('nennt den Monat beim Namen, nicht den Ersten des Monats', () {
      expect(Format.monatKurz(DateTime.utc(2026, 11, 1)), 'Nov');
      expect(Format.monatKurz(DateTime.utc(2026, 12, 1)), 'Dez');
      expect(Format.monatKurz(DateTime.utc(2027, 1, 1)), 'Jan');
    });

    test('der Tag im Monat ändert nichts daran', () {
      expect(
        Format.monatKurz(DateTime.utc(2026, 11, 23)),
        'Nov',
        reason:
            'Beschriftet wird der Monat, nicht der Tag — die Achse bekommt '
            'den Monatsersten, aber darauf darf sich niemand verlassen',
      );
    });

    test('alle zwölf Monate, so wie `intl` sie für `de_DE` kürzt', () {
      expect(
        [for (var m = 1; m <= 12; m++) Format.monatKurz(DateTime.utc(2026, m))],
        [
          'Jan',
          'Feb',
          'Mär',
          'Apr',
          'Mai',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Okt',
          'Nov',
          'Dez',
        ],
        reason:
            'Mai bis Okt stehen wortgleich im Entwurfsboard '
            '(`docs/screens/screens/gym-progress.js`, `MONTHS`). Weicht '
            'eine Form davon ab, zeigt das Board etwas anderes als die App',
      );
    });

    test('bleibt deutsch, auch wenn die Umgebung Englisch ist', () {
      Intl.defaultLocale = 'en_US';

      expect(
        Format.monatKurz(DateTime.utc(2026, 12, 1)),
        'Dez',
        reason:
            'Ein Monatsname ist der Fall, in dem die Sprache sichtbar wird — '
            'ohne feste Locale stünde „Dec" mitten im deutschen Text',
      );
    });
  });
}
