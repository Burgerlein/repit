// Der Schirm **„Vorläufige Werte"** (#307) — der Eingangsweg für
// Zielgewicht und Zieldatum, bis der Erststart (#102, #103) ihn übernimmt.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber **nicht verändert** werden — keine
// Zeile, kein Erwartungswert, kein Testname. Wer einen Fall für falsch
// hält, meldet ihn, statt ihn passend zu machen.
//
// ## Woher die Anforderungen kommen
//
// Issue #307 („Ernährung · Vorläufiger Eingabeweg für Zielgewicht und
// Zieldatum", Tim am 04.11.2026) und `CLAUDE.md`. Der Schirm schreibt in
// die **vorhandene** Stammdaten-Tabelle (#277,
// `lib/data/stammdaten.dart`), nicht in eine eigene: Wenn der Erststart
// kommt, ändert sich nur der Eingang, die Daten bleiben liegen und nichts
// muss migriert werden. Vorbild für Form und Ort ist
// `healthkit_test_view.dart` — auch ein Schirm, der im Mehr-Menü hängt
// und nicht für die Ewigkeit gedacht ist.
//
// ## Festgelegte öffentliche API (`lib/shell/vorlaeufige_werte_view.dart`)
//
// ```dart
// /// Öffnet den Schirm auf dem Stapel des **aktuell gewählten** Tabs —
// /// die eine Stelle, die das weiß (wie `oeffneErholungWerte`,
// /// `oeffneKoerper`, `oeffneMessungen`).
// void oeffneVorlaeufigeWerte(AppRouter router);
//
// /// Der Rahmen: Gerüst und Navigationsleiste um den Schirm. **Kein**
// /// eigener `Navigator` — der gehört `RootView`.
// class VorlaeufigeWerteSeite extends StatelessWidget {
//   const VorlaeufigeWerteSeite({super.key});
// }
//
// /// Der Schirm selbst, ohne Gerüst. Er besorgt seine Daten selbst
// /// (`stammdatenProvider`).
// class VorlaeufigeWerteView extends ConsumerStatefulWidget {
//   const VorlaeufigeWerteView({super.key});
// }
// ```
//
// Dazu eine Zeile im Mehr-Menü mit dem Titel **„Vorläufige Werte"**, nicht
// abgeblendet und tippbar. In welcher Gruppe sie steht, prüft hier
// niemand — das ist Anordnung, keine Zustandsfrage.
//
// ## Die Schlüssel
//
// Weil es für „dieser Teil ist da / zeigt dies" sonst keine strukturelle
// Stelle im Baum gibt — dieselbe Begründung wie bei den Schlüsseln in
// `erholung_werte_view_test.dart` und `schlaf_eintragen.dart`:
//
// - `Key('vorlaeufige-werte-hinweis')` — der Satz, der sagt, dass dieser
//   Schirm vorläufig ist. **Steht in jedem Zustand.**
// - `Key('vorlaeufige-werte-zielgewicht-feld')` — das `CupertinoTextField`
//   fürs Zielgewicht. Der Schlüssel sitzt **auf dem Feld selbst**.
// - `Key('vorlaeufige-werte-zieldatum')` — die Zeile, die das Datumsrad
//   aufklappt.
// - `Key('vorlaeufige-werte-zieldatum-wert')` — der sichtbare Wert des
//   Zieldatums (formatiert oder `ohneWert`).
// - `Key('vorlaeufige-werte-zieldatum-loeschen')` — leert das Zieldatum.
// - `Key('vorlaeufige-werte-sichern')` — schreibt den Stand.
//
// ## Entscheidungen des Test-Agenten (nicht mit Tim abgestimmt)
//
// 1. **Ein „Sichern" statt Schreiben bei jedem Tastendruck.** Die Tests
//    tippen den Knopf, nachdem sie etwas geändert haben. Wer stattdessen
//    sofort schreibt, besteht sie trotzdem — der Knopf ist dann ein
//    Nicht-Ereignis. Er muss aber **existieren**: Ein Schirm, der still
//    beim Verlassen schreibt, lässt den Nutzer raten, ob sein Wert
//    angekommen ist.
// 2. **Das Zieldatum kommt aus einem `CupertinoDatePicker`, nicht aus
//    einer Tastatur.** Hausform (`schlaf_eintragen.dart`: „Pickerräder
//    statt Tastatur, wo es geht"), und ein getipptes Datum müsste geparst
//    werden — ein Parser, den niemand braucht, ist ein Fehler, den niemand
//    sucht. Die Tests drehen das Rad **nicht** per Geste, sondern rufen
//    `onDateTimeChanged` unmittelbar auf: deterministisch, und sie binden
//    damit keine Rastweite fest. Das Rad hängt **im Schirm**, nicht in
//    einem Modal — ein Blatt mit eigenem „Fertig" wäre eine zweite
//    Sicherungsstufe neben Entscheidung 1.
// 3. **Das Rad ist erst nach dem Antippen der Zeile da.** Ein immer
//    sichtbares Rad steht beim leeren Stand auf *heute* und sieht aus wie
//    ein Wert — genau das, was Pflicht 5 verbietet.
// 4. **Komma und Punkt werden beide als Dezimaltrennzeichen gelesen.** Die
//    deutsche Ziffern-Tastatur liefert das Komma; ein Feld, das nur den
//    Punkt kennt, verschluckt „81,4" oder macht daraus 814. Das ist
//    Zustand, nicht Beschriftung.
// 5. **Das Zielgewicht ist ein `CupertinoTextField`**, kein Rad: Es ist
//    eine Zahl mit Nachkommastelle über einen offenen Bereich, und ein Rad
//    dafür hätte hunderte Rasten.
//
// ## Was hier absichtlich **nicht** geprüft wird
//
// - Layout, Abstände, Farben, Schriftgrößen und der genaue Wortlaut von
//   Überschriften, Knöpfen und Hinweisen (`CLAUDE.md`: Widget-Tests prüfen
//   Zustände und Übergänge; „Keine Schriftgrößen-Tests"). Der
//   Vorläufigkeits-Hinweis wird nur auf seinen **Zustand** geprüft, nicht
//   auf seinen Satzbau.
// - Ob der Kalorienring danach einen Körperziel-Aufschlag ausweist — das
//   ist die Rechnung aus #306/#275 und gehört in den Kern, nicht hierher.
// - Grundumsatz, Körpergröße und Geburtsjahr. Die beiden letzteren kommen
//   aus Apple Health (#306); dieser Schirm fasst sie nicht an — und genau
//   das prüft der Fall „lässt Größe und Geburtsjahr unangetastet".
//
// ## Erfundene Zahlen
//
// Zielgewicht, Zieldatum, Größe und Geburtsjahr unten sind **erfunden und
// erkennbar künstlich** (`CLAUDE.md`: „Echte Gesundheitsdaten stehen nie
// im Quelltext"). Das Zieldatum liegt im Juli 2031, das Geburtsjahr ist
// 1901 — beides kann niemand für Tims Daten halten.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/icon_row.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/vorlaeufige_werte_view.dart';

import '../design/support.dart' show textOf;
import 'support.dart';
import '../health/health_reading_attrappe.dart';

void main() {
  // Erfundene Werte, siehe Dateikopf.
  const zielgewicht = 82.0;
  const zielgewichtMitKomma = 81.4;
  const zieldatumIso = '2031-07-18';
  final zieldatum = DateTime(2031, 7, 18);
  const groesseCm = 123;
  const geburtsjahr = 1901;

  /// Die Zeile im Mehr-Menü. Ein Titel ist eine Beschriftung — hier
  /// trotzdem festgenagelt, weil es sonst keinen Weg gibt, *die eine*
  /// Zeile zu finden, deren Zustand geprüft werden soll.
  const menuepunkt = 'Vorläufige Werte';

  final feld = find.byKey(const Key('vorlaeufige-werte-zielgewicht-feld'));
  final datumZeile = find.byKey(const Key('vorlaeufige-werte-zieldatum'));
  final datumWert = find.byKey(const Key('vorlaeufige-werte-zieldatum-wert'));
  final datumLoeschen = find.byKey(
    const Key('vorlaeufige-werte-zieldatum-loeschen'),
  );
  final sichernKnopf = find.byKey(const Key('vorlaeufige-werte-sichern'));
  final hinweis = find.byKey(const Key('vorlaeufige-werte-hinweis'));

  /// Klingt nach „das hier bleibt nicht so". Nicht der Wortlaut, nur der
  /// Zustand — siehe Dateikopf.
  final vorlaeufigkeitsMuster = RegExp(
    r'vorläufig|vorerst|übergangsweise|zwischenzeitlich|Erststart|'
    r'solange|später|bis der|bis die',
    caseSensitive: false,
  );

  /// Ein Datum in einer der beiden Schreibweisen, die in dieser App
  /// vorkommen: `18.07.2031` und `2031-07-18`.
  final datumsMuster = RegExp(r'\d{2}\.\d{2}\.\d{4}|\d{4}-\d{2}-\d{2}');

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
    // Das englisch eingestellte Gerät aus `Formatting.swift:6-10` — siehe
    // die Gruppe „Der gemeinsame Formatierer" unten.
    await initializeDateFormatting('en_US');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        // Der Schirm fragt Apple Health nicht; die Attrappe steht hier,
        // damit ein Provider, der später einen Lauf dazubekommt, nicht in
        // `UnimplementedError` läuft.
        healthProvider.overrideWithValue(_LeereQuelle()),
        clockProvider.overrideWithValue(() => DateTime.utc(2031, 1, 2, 9)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Baut den Schirm auf. Ohne `mit` entsteht ein **frischer** Behälter
  /// über derselben Datenbank — das ist der Neustart aus Pflichtfall 2:
  /// Was danach dasteht, kam aus der Tabelle und nicht aus einem
  /// Formularzustand, der zufällig noch im Speicher lag.
  Future<ProviderContainer> zeige(
    WidgetTester tester, {
    ProviderContainer? mit,
  }) async {
    final container = mit ?? behaelter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: VorlaeufigeWerteSeite()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Alle Texte unterhalb (und auf) [wurzel], zusammengefügt — unabhängig
  /// davon, ob der Schlüssel auf dem `Text` selbst oder auf einer Hülle
  /// darum sitzt.
  String textUnter(WidgetTester tester, Finder wurzel) {
    expect(
      wurzel,
      findsOneWidget,
      reason: 'Der Schlüssel fehlt — siehe „Die Schlüssel" im Dateikopf.',
    );
    return tester
        .widgetList<Text>(
          find.descendant(
            of: wurzel,
            matching: find.byType(Text),
            matchRoot: true,
          ),
        )
        .map(textOf)
        .join(' ');
  }

  /// Der tatsächlich im Zielgewichts-Feld stehende Text.
  String gewichtsText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: feld, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  CupertinoTextField gewichtsFeld(WidgetTester tester) =>
      tester.widget<CupertinoTextField>(
        find
            .descendant(
              of: feld,
              matching: find.byType(CupertinoTextField),
              matchRoot: true,
            )
            .first,
      );

  Future<void> tippeGewicht(WidgetTester tester, String text) async {
    await tester.enterText(feld, text);
    await tester.pumpAndSettle();
  }

  /// Klappt das Rad auf und meldet ihm [tag]. Siehe Entscheidung 2 im
  /// Dateikopf: der Rückruf wird unmittelbar aufgerufen, nicht gedreht.
  Future<void> waehleDatum(WidgetTester tester, DateTime tag) async {
    await tester.tap(datumZeile);
    await tester.pumpAndSettle();

    final rad = find.byType(CupertinoDatePicker);
    expect(
      rad,
      findsOneWidget,
      reason:
          'Ein Tipp auf die Zieldatum-Zeile muss genau ein '
          'CupertinoDatePicker im Schirm aufklappen (Entscheidung 2).',
    );

    tester.widget<CupertinoDatePicker>(rad).onDateTimeChanged(tag);
    await tester.pumpAndSettle();
  }

  Future<void> sichere(WidgetTester tester) async {
    expect(
      sichernKnopf,
      findsOneWidget,
      reason:
          'Der Schirm braucht einen sichtbaren „Sichern" — ein Schirm, '
          'der still beim Verlassen schreibt, lässt den Nutzer raten '
          '(Entscheidung 1).',
    );
    // Seit der Zeile „Aufteilung auf Mahlzeiten" (#433) liegt „Sichern"
    // bei offenem Datumsrad unter der 800×600-Testfläche. Ein Tipp dorthin
    // trifft nichts, und ein Fall, der danach `null` erwartet, wäre
    // grundlos grün. Also erst in Sicht rollen, wie der Nutzer es täte.
    await tester.ensureVisible(sichernKnopf);
    await tester.pumpAndSettle();
    await tester.tap(sichernKnopf);
    await tester.pumpAndSettle();
  }

  /// Liest unmittelbar aus der Datenbank, nicht über den Provider: Was
  /// hier steht, hat den Schirm überlebt.
  Future<Stammdaten> ausDerDatenbank() => StammdatenRepository(db).lies();

  Future<void> legeAb(Stammdaten stammdaten) =>
      StammdatenRepository(db).schreibe(stammdaten);

  group('Leer ist erlaubt', () {
    testWidgets('beide Felder zeigen –/–, nicht 0', (tester) async {
      await zeige(tester);

      expect(
        gewichtsText(tester),
        isEmpty,
        reason:
            'Ein leeres Zielgewicht ist leer — eine 0 behauptete ein Ziel '
            'von null Kilogramm (Fehler 01 in neuer Verpackung).',
      );
      expect(
        gewichtsFeld(tester).placeholder,
        ohneWert,
        reason:
            'Die leere Anzeige sagt „$ohneWert" — dieselbe Form wie die '
            'gefüllte, nur ungefüllt (`CLAUDE.md`).',
      );
      expect(
        textUnter(tester, datumWert),
        contains(ohneWert),
        reason: 'Auch das Zieldatum sagt „$ohneWert", wenn keins da ist.',
      );
    });

    testWidgets('ohne Eintrag steht nirgends ein Datum', (tester) async {
      // Pflicht 5: Der Schirm bringt keinen Vorgabewert mit. Ein Rad, das
      // beim Aufbau schon dasteht, zeigt *heute* — und das sähe aus wie
      // ein Wert, den jemand gesetzt hat.
      await zeige(tester);

      expect(
        find.byType(CupertinoDatePicker),
        findsNothing,
        reason:
            'Das Rad klappt erst auf Tippen auf — vorher steht dort kein '
            'Datum (Entscheidung 3).',
      );

      final texte = tester.widgetList<Text>(find.byType(Text)).map(textOf);
      for (final text in texte) {
        expect(
          datumsMuster.hasMatch(text),
          isFalse,
          reason:
              'Text „$text" nennt ein Datum, obwohl nichts eingetragen '
              'ist — leer heißt leer (Tims Entscheidung vom 04.11.2026).',
        );
      }
    });

    testWidgets('speichern ohne Eingabe schreibt nichts', (tester) async {
      await zeige(tester);
      await sichere(tester);

      final stand = await ausDerDatenbank();
      expect(stand.zielgewichtKg, isNull);
      expect(
        stand.zieldatum,
        isNull,
        reason:
            'Kein Vorgabewert, auch nicht über den Umweg „Sichern ohne '
            'Eingabe" — das ist der Kern von #307.',
      );
    });

    testWidgets('das Rad aufklappen allein setzt noch kein Datum', (
      tester,
    ) async {
      // Der heimliche Weg zu einem hartcodierten Datum: Das Rad startet
      // bei „heute", und wer das beim Sichern mitnimmt, hat ein Datum
      // erfunden, das Tim nie gewählt hat.
      await zeige(tester);

      await tester.tap(datumZeile);
      await tester.pumpAndSettle();
      await sichere(tester);

      expect((await ausDerDatenbank()).zieldatum, isNull);
      expect(
        textUnter(tester, datumWert),
        contains(ohneWert),
        reason:
            'Solange niemand am Rad gedreht hat, steht dort weiter '
            '„$ohneWert" — nicht der Tag, auf dem das Rad zufällig steht.',
      );
    });
  });

  group('Eintragen', () {
    testWidgets('das Zielgewicht landet in der Stammdaten-Tabelle', (
      tester,
    ) async {
      await zeige(tester);
      await tippeGewicht(tester, '82');
      await sichere(tester);

      expect((await ausDerDatenbank()).zielgewichtKg, zielgewicht);
    });

    testWidgets('ein Komma zählt wie ein Punkt', (tester) async {
      // Entscheidung 4 im Dateikopf: Die deutsche Tastatur liefert das
      // Komma. Ein Feld, das nur den Punkt kennt, macht aus 81,4 entweder
      // nichts oder 814.
      await zeige(tester);
      await tippeGewicht(tester, '81,4');
      await sichere(tester);

      expect((await ausDerDatenbank()).zielgewichtKg, zielgewichtMitKomma);
    });

    testWidgets('das Zieldatum landet als ISO-Tagesstring in der Tabelle', (
      tester,
    ) async {
      await zeige(tester);
      await waehleDatum(tester, zieldatum);
      await sichere(tester);

      expect(
        (await ausDerDatenbank()).zieldatum,
        zieldatumIso,
        reason:
            'Ein Zieldatum ist eine Kalenderangabe. Der Tagesstring wird '
            'aus den Kalenderfeldern des Rades gebaut (Jahr, Monat, Tag) '
            '— wer den lokalen Zeitpunkt erst nach UTC dreht, verschiebt '
            'den Tag um einen (`CLAUDE.md`, „Der Datumsschlüssel ist der '
            'ISO-Tagesstring").',
      );
    });

    testWidgets('lässt Größe und Geburtsjahr unangetastet', (tester) async {
      // `StammdatenRepository.schreibe` schreibt **alle vier** Felder,
      // jedes als `Value(...)`. Wer hier einen frisch gebauten
      // `Stammdaten(zielgewichtKg: …, zieldatum: …)` übergibt, löscht die
      // beiden anderen Felder — lautlos und ohne Fehlermeldung.
      await legeAb(
        const Stammdaten(groesseCm: groesseCm, geburtsjahr: geburtsjahr),
      );

      await zeige(tester);
      await tippeGewicht(tester, '82');
      await waehleDatum(tester, zieldatum);
      await sichere(tester);

      final stand = await ausDerDatenbank();
      expect(stand.groesseCm, groesseCm);
      expect(stand.geburtsjahr, geburtsjahr);
      expect(stand.zielgewichtKg, zielgewicht);
      expect(stand.zieldatum, zieldatumIso);
    });
  });

  group('Eingetragenes überlebt', () {
    testWidgets('abgelegte Werte stehen beim Aufbau da', (tester) async {
      await legeAb(
        const Stammdaten(
          zielgewichtKg: zielgewicht,
          zieldatum: zieldatumIso,
        ),
      );

      await zeige(tester);

      expect(
        double.tryParse(gewichtsText(tester).replaceAll(',', '.')),
        zielgewicht,
        reason:
            'Das Feld zeigt den abgelegten Wert — in welcher Schreibweise, '
            'ist dem Schirm überlassen, solange er sie selbst wieder liest.',
      );
      expect(textUnter(tester, datumWert), isNot(contains(ohneWert)));
    });

    testWidgets('eingetragene Werte stehen nach dem Neuaufbau wieder da', (
      tester,
    ) async {
      // Pflicht 2 und zugleich Fehler `32` („ein Wert, der dastand, steht
      // nach dem Zurücknavigieren wieder da"): Der zweite Aufbau läuft
      // über einen **frischen** Behälter, also über die Datenbank.
      await zeige(tester);
      await tippeGewicht(tester, '82');
      await waehleDatum(tester, zieldatum);
      await sichere(tester);

      await zeige(tester);

      expect(
        double.tryParse(gewichtsText(tester).replaceAll(',', '.')),
        zielgewicht,
      );
      expect(textUnter(tester, datumWert), isNot(contains(ohneWert)));
      expect(
        datumsMuster.hasMatch(textUnter(tester, datumWert)),
        isTrue,
        reason: 'Nach dem Neuaufbau steht das Zieldatum wieder da.',
      );
    });
  });

  group('Geleert ist geleert', () {
    testWidgets('ein geleertes Zielgewicht wird null, nicht ignoriert', (
      tester,
    ) async {
      // Derselbe Fall wie `Value(null)` statt `Value.absent()` in
      // `schema_v11_test.dart`: Ein Schreibweg, der `null` als „nicht
      // angegeben, bitte stehen lassen" liest, macht das Leeren unmöglich
      // — und zwar lautlos.
      await legeAb(
        const Stammdaten(
          zielgewichtKg: zielgewicht,
          zieldatum: zieldatumIso,
        ),
      );
      await zeige(tester);

      await tippeGewicht(tester, '');
      await sichere(tester);

      final stand = await ausDerDatenbank();
      expect(
        stand.zielgewichtKg,
        isNull,
        reason: 'Wer ein Feld löscht, hat es gelöscht.',
      );
      expect(
        stand.zieldatum,
        zieldatumIso,
        reason: 'Das Zieldatum war nicht gemeint und bleibt stehen.',
      );
    });

    testWidgets('ein gelöschtes Zieldatum wird null, nicht ignoriert', (
      tester,
    ) async {
      await legeAb(
        const Stammdaten(
          zielgewichtKg: zielgewicht,
          zieldatum: zieldatumIso,
        ),
      );
      await zeige(tester);

      expect(
        datumLoeschen,
        findsOneWidget,
        reason:
            'Ohne eigenen Weg zum Leeren gibt es keinen: Ein Rad kann man '
            'drehen, aber nicht auf „nichts" stellen.',
      );
      await tester.tap(datumLoeschen);
      await tester.pumpAndSettle();
      await sichere(tester);

      final stand = await ausDerDatenbank();
      expect(stand.zieldatum, isNull);
      expect(
        stand.zielgewichtKg,
        zielgewicht,
        reason: 'Das Zielgewicht war nicht gemeint und bleibt stehen.',
      );
    });

    testWidgets('nach dem Leeren steht wieder –/– da, auch neu aufgebaut', (
      tester,
    ) async {
      await legeAb(
        const Stammdaten(
          zielgewichtKg: zielgewicht,
          zieldatum: zieldatumIso,
        ),
      );
      await zeige(tester);

      await tippeGewicht(tester, '');
      await tester.tap(datumLoeschen);
      await tester.pumpAndSettle();
      await sichere(tester);

      await zeige(tester);

      expect(gewichtsText(tester), isEmpty);
      expect(gewichtsFeld(tester).placeholder, ohneWert);
      expect(textUnter(tester, datumWert), contains(ohneWert));
    });
  });

  group('Der Schirm sagt, dass er vorläufig ist', () {
    testWidgets('der Hinweis steht da, leer wie gefüllt', (tester) async {
      // Pflicht 4: Sonst sieht der Schirm in drei Monaten aus wie eine
      // Funktion, die jemand vergessen hat. Geprüft wird der Zustand, nicht
      // der Wortlaut.
      await zeige(tester);

      expect(hinweis, findsOneWidget);
      expect(
        vorlaeufigkeitsMuster.hasMatch(textUnter(tester, hinweis)),
        isTrue,
        reason:
            'Der Hinweis muss erkennbar sagen, dass dieser Eingang nur '
            'bis zum Erststart besteht — gefunden wurde: '
            '„${textUnter(tester, hinweis)}".',
      );

      await legeAb(
        const Stammdaten(
          zielgewichtKg: zielgewicht,
          zieldatum: zieldatumIso,
        ),
      );
      await zeige(tester);

      expect(
        hinweis,
        findsOneWidget,
        reason:
            'Der Hinweis verschwindet nicht, sobald Werte dastehen — '
            'vorläufig bleibt der Schirm trotzdem.',
      );
    });
  });

  group('Der gemeinsame Formatierer', () {
    /// Die Datumsformate, die `Format` kennt. Welches der Schirm nimmt, ist
    /// seine Sache — dass es eines davon ist, nicht.
    Set<String> erlaubteTexte(DateTime tag) => {
      Format.tag(tag),
      Format.datumAusgeschrieben(tag),
      Format.wochentagUndDatum(tag),
      Format.tagMonat(tag),
      Format.monatUndJahr(tag),
    };

    testWidgets('das Zieldatum steht in einem Format aus `Format`', (
      tester,
    ) async {
      await legeAb(const Stammdaten(zieldatum: zieldatumIso));
      await zeige(tester);

      final gezeigt = textUnter(tester, datumWert);
      expect(
        erlaubteTexte(zieldatum).any(gezeigt.contains),
        isTrue,
        reason:
            'Gezeigt wurde „$gezeigt". Datumsangaben laufen über den '
            'gemeinsamen Formatierer (`lib/design/formatierung.dart`), nie '
            'über eine eigene Zusammensetzung — `CLAUDE.md`.',
      );
    });

    testWidgets('es bleibt deutsch, auch wenn die Umgebung englisch ist', (
      tester,
    ) async {
      // Der Fehler aus `Formatting.swift:6-10`: Auf einem englisch
      // eingestellten Gerät stand „6. Oct 2026" mitten im deutschen Text.
      // `Intl.defaultLocale` ist die Dart-Entsprechung zur Geräte-Locale
      // (siehe `test/design/formatierung_test.dart`).
      await legeAb(const Stammdaten(zieldatum: zieldatumIso));

      await zeige(tester);
      final deutsch = textUnter(tester, datumWert);

      Intl.defaultLocale = 'en_US';
      await zeige(tester);

      expect(
        textUnter(tester, datumWert),
        deutsch,
        reason:
            'Dasselbe Datum muss unter einer englischen Umgebung gleich '
            'aussehen — sonst steht die Standardformatierung dahinter und '
            'nicht `Format`.',
      );
    });
  });

  group('Kein hartcodiertes Datum', () {
    test('der Quelltext des Schirms nennt kein Datum', () {
      // Die Prüfung aus `CLAUDE.md` („Keine hartcodierten Ereignisse"),
      // eingeengt auf die eine neue Datei und auf **Code**: Kommentare
      // dürfen Spec-Dateien nennen, die ein Datum im Namen tragen
      // (`docs/superpowers/specs/2026-11-03-…`). Deshalb wird jede Zeile
      // vor dem ersten `//` geprüft, nicht die ganze Zeile.
      final datei = File('lib/shell/vorlaeufige_werte_view.dart');
      expect(
        datei.existsSync(),
        isTrue,
        reason:
            'Erwartet wird `lib/shell/vorlaeufige_werte_view.dart` — '
            'siehe „Festgelegte öffentliche API" im Dateikopf.',
      );

      final muster = RegExp(
        r'20(2[6-9]|3[0-9])-[0-9]{2}-[0-9]{2}|DateTime\(20',
      );
      final treffer = <String>[];
      final zeilen = datei.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final code = zeilen[i].split('//').first;
        if (muster.hasMatch(code)) treffer.add('${i + 1}: ${zeilen[i]}');
      }

      expect(
        treffer,
        isEmpty,
        reason:
            'Kein Datum eines Ereignisses steht je im Quelltext — weder '
            'als Konstante noch „nur zum Anschauen" (`CLAUDE.md`). In der '
            'Altapp lag der OP-Termin an sechs Stellen und an einer davon '
            'anders.',
      );
    });
  });

  group('Der Weg aus dem Mehr-Menü', () {
    /// Dieselbe Vergrößerung wie in `mehr_view_test.dart`: Ohne sie liegt
    /// die untere Hälfte des Menüs außerhalb der Testfläche.
    Future<void> zeigeMehr(WidgetTester tester, AppRouter router) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(huelle(MehrView(router: router)));
      await tester.pumpAndSettle();
    }

    /// Produkt aller `Opacity`-Werte über der Zeile — `1.0` ohne
    /// `Opacity`-Vorfahren. Wörtlich aus `mehr_view_test.dart`.
    double opazitaetVon(WidgetTester tester, Finder titel) {
      final werte = tester.widgetList<Opacity>(
        find.ancestor(of: titel, matching: find.byType(Opacity)),
      );
      if (werte.isEmpty) return 1.0;
      return werte.map((o) => o.opacity).reduce((a, b) => a * b);
    }

    testWidgets('die Zeile steht da und ist nicht abgeblendet', (
      tester,
    ) async {
      await zeigeMehr(tester, AppRouter());

      expect(
        find.text(menuepunkt),
        findsOneWidget,
        reason: 'Ohne Zeile im Mehr-Menü ist der Schirm unerreichbar.',
      );
      expect(
        opazitaetVon(tester, find.text(menuepunkt)),
        1.0,
        reason:
            'Die Zeile führt irgendwohin — abgeblendet sind nur die, die '
            'es noch nicht tun.',
      );
      expect(
        tester.widget<IconRow>(find.widgetWithText(IconRow, menuepunkt)).onTap,
        isNotNull,
        reason:
            'Eine Zeile, die aussieht wie ein Knopf und beim Tippen '
            'schweigt, ist genau der Fehler, den `pruefen.mjs` sucht.',
      );
    });

    testWidgets('der Tipp schiebt den Schirm auf den aktuellen Stapel', (
      tester,
    ) async {
      final router = AppRouter();
      final tabVorher = router.tab;
      await zeigeMehr(tester, router);

      await tester.tap(find.text(menuepunkt));
      await tester.pumpAndSettle();

      expect(
        router.tab,
        tabVorher,
        reason: 'Ein Menüpunkt wechselt nie den Tab (`CLAUDE.md`).',
      );

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(
        befehl!.ersetztStapel,
        isFalse,
        reason:
            'Geschoben (`AppTarget.aktuell`), nicht den Stapel ersetzt '
            '(`AppTarget.detail` wäre der Fehler aus der Hausregel).',
      );
      expect(befehl.tab, router.tab);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: behaelter(),
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(VorlaeufigeWerteView),
        findsOneWidget,
        reason: 'Der Befehl muss wirklich diesen Schirm bauen.',
      );
    });

    testWidgets('`oeffneVorlaeufigeWerte` tut dasselbe von außen', (
      tester,
    ) async {
      // Eine eigene Stelle statt eines `router.open(...)` beim Aufrufer —
      // wie `oeffneKoerper`, `oeffneErholung`, `oeffneMessungen`: Sonst
      // trifft der nächste Aufrufer dieselbe Entscheidung neu, und einer
      // von beiden trifft sie falsch.
      final router = AppRouter();
      final tabVorher = router.tab;

      oeffneVorlaeufigeWerte(router);

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(router.tab, tabVorher);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: behaelter(),
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VorlaeufigeWerteView), findsOneWidget);
    });
  });

  group('Der Schirm bringt keinen eigenen Rahmen mit', () {
    testWidgets('kein zweiter Navigator, keine eigene Tab-Leiste', (
      tester,
    ) async {
      // Hausregel aus `CLAUDE.md`: Eine Ansicht, die gepusht wird, bringt
      // niemals ihren eigenen Navigationsstapel mit — den stellt
      // `RootView`. Zwei verschachtelte Stapel schließen die gepushte
      // Seite sofort wieder.
      await zeige(tester);

      expect(find.byType(Navigator), findsOneWidget);
      expect(find.byType(CupertinoTabScaffold), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Eine Quelle, die nichts hergibt. Der Schirm fragt Apple Health nicht —
/// siehe `behaelter()`.
class _LeereQuelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);
}
