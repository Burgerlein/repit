import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/icon_row.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den Schirm **„Umfänge messen"** (#477 unter #88,
/// Scheibe 2) — `lib/koerper/umfaenge_eintragen.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Für Widget-Tests genügt ein Agent, solange der Test zuerst entsteht,
/// einmal rot gesehen und **vor der Implementierung committet** wird — ab da
/// bewacht ihn `.githooks/pre-commit`. Diese Datei darf ausgeführt, aber
/// nicht verändert werden. Hält der Implementierende einen Fall für falsch,
/// **meldet** er ihn.
///
/// ## Woher die Anforderung kommt
///
/// `docs/SPEC.md` 4.6, `docs/superpowers/plans/2026-11-11-umfaenge.md`
/// (Scheibe 2, Task 2.2 und 2.4) und der Entwurf
/// `docs/screens/screens/umfaenge-eintragen.js` (Varianten `neu` und
/// `schon-da`).
///
/// **Ein geschobener Schirm, kein Blatt.** Der Entwurf legt ein `sheet`
/// über die Liste; der Swift-Code begründet das Gegenteil
/// (`CircumferenceEntryView.swift:4-9`: „Dreizehn Felder zwischen zwei
/// Diagrammen scrollen sich schlecht, und die Tastatur verdeckt dann genau
/// das, was man vergleichen will"). Bei fünfzehn Feldern gilt das erst
/// recht. Der Plan entscheidet für den Code; der Entwurf wird nachgezogen.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Kein Fall hier prüft, wie eine Karte überschrieben ist
/// oder welche Farbe sie trägt. Geprüft werden die vier Zusagen, deren
/// Bruch das Feature auch dann wertlos machte, wenn es läuft:
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (`01`).
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da**
///    (`32`).
/// 3. **Nichts geht verloren und nichts entsteht aus dem Nichts:** leere
///    Felder werden nicht gespeichert, unplausible abgewiesen, und beides
///    wird an der Tabelle geprüft, nicht am Text — ein Hinweis, unter dem
///    trotzdem geschrieben wurde, bestünde jede Textprüfung.
/// 4. **Die Keine-Daten-Ansicht hat dieselbe Geometrie wie die gefüllte.**
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `umfaenge-eintragen` | der Schirm selbst |
/// | `umfaenge-eintragen-datum` | die Zeile, die das Datumsrad aufklappt |
/// | `umfaenge-eintragen-hinweis` | „… ist schon eine Messung eingetragen" |
/// | `umfaenge-eintragen-fuss` | die Erläuterung unter den Feldern |
/// | `umfaenge-eintragen-problem` | die Zeile, die sagt, was dasteht |
/// | `umfaenge-eintragen-sichern` | „Sichern" |
/// | `umfaenge-zeile-<schluessel>` | je Maß die ganze Zeile |
/// | `umfaenge-feld-<schluessel>` | je Maß das `CupertinoTextField` |
///
/// `<schluessel>` ist `Umfang.schluessel` (`waist`, `chest`, …), nicht der
/// Dart-Name: Derselbe Schlüssel steht in der Tabelle, und zwei
/// Schreibweisen für dasselbe Maß liefen auseinander.
///
/// **`umfaenge-feld-…` sitzt auf dem `CupertinoTextField` selbst**, nicht
/// auf einer Hülle: Der Platzhalter ist eine Eigenschaft dieses Widgets,
/// und ohne Zugriff darauf ließe sich „die Werte vom letzten Mal stehen als
/// Platzhalter" nicht aussprechen. **`umfaenge-eintragen-sichern` sitzt auf
/// einem `CupertinoButton`** — dieselbe Form, die `schlaf_eintragen.dart`
/// und `gewicht_eintragen.dart` nebenan schon benutzen.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Der Weg auf den Schirm läuft immer über `Mehr › Umfänge messen`**
///   und einen Gastgeber, der den Befehl des `AppRouter` auf einen
///   `Navigator` schiebt — wie `RootView` es für den Stapel eines Tabs tut.
///   So legt diese Datei weder Klassennamen noch Konstruktor des Schirms
///   fest; sie kennt ihn nur über seine Schlüssel. Dass die beiden anderen
///   Türen (Körper-Kachel und Körper-Zeile) dorthin führen, prüft
///   `umfaenge_tueren_test.dart`.
/// - **Geprüft wird erst beim Sichern**, nicht beim Tippen. „27," ist ein
///   gültiger Zwischenstand, und ein Feld, das beim dritten Anschlag rot
///   wird, erzieht zum Wegschauen. Der Swift-Code prüft live
///   (`CircumferenceEntryView.swift:76`); hier gilt der Auftrag von #477.
/// - **„Sichern" schließt den Schirm**, wenn geschrieben wurde, und lässt
///   ihn stehen, wenn etwas abgewiesen wurde. Ein Schirm, der nach einer
///   Abweisung zuginge, nähme die eingetippten Zahlen mit.
/// - **Die rote Zeile nennt das Maß und den gelesenen Wert.** Das ist eine
///   Beschriftungsprüfung und damit eine bewusste Ausnahme von `CLAUDE.md`:
///   `UmfangAusserhalb` trägt den gelesenen Wert eigens mit, „damit die
///   rote Zeile sagen kann, was dasteht" (Kopf von `umfangs_eingabe.dart`)
///   — ein Hinweis ohne die Zahl wäre genau die Hälfte, die gebaut werden
///   sollte. Geprüft wird nur, dass beides vorkommt, nicht der Wortlaut.
/// - **Der Wortlaut des „schon gemessen"-Hinweises** wird dagegen
///   vollständig geprüft: Spec und Entwurf geben ihn wörtlich vor, und er
///   ist die einzige Stelle, an der der Schirm sagt, dass Sichern etwas
///   **ändert** statt anzulegen.
/// - **`umfaenge-eintragen-fuss` steht in jedem Zustand da**, mit und ohne
///   frühere Werte. Der Plan verlangt für die Keine-Daten-Ansicht „einen
///   Hinweis statt Vorwerten"; stünde er in einem Zustand und im anderen
///   nicht, verschöbe sich alles darüber oder darunter, sobald die erste
///   Messung da ist — der Sprung, gegen den die Regel gebaut ist.
/// - **Das Datumsrad wird nicht gedreht**, sondern sein
///   `onDateTimeChanged` unmittelbar aufgerufen — wie in
///   `vorlaeufige_werte_test.dart` und `ziele_view_test.dart`.
///
/// ## Nachtrag (11.11.2026): die Vorbelegung ist entschieden
///
/// Die erste Fassung dieser Datei ließ offen, ob die Felder eines Tages
/// vorbelegt werden, für den schon eine Messung vorliegt: Der Entwurf
/// zeigte leere Felder mit blassem Platzhalter, der Swift-Code belegte vor
/// (`loadDay()`). **Tim hat am 11.11.2026 für die Swift-Fassung
/// entschieden**, und der Entwurf ist nachgezogen (`7ad3abf`,
/// `umfaenge-eintragen.js`, Variante `schon-da`): Für einen Tag, an dem
/// schon gemessen wurde, stehen die Werte dieses Tages **wirklich in den
/// Feldern** — als Text, änderbar, nicht blass. „Man soll sehen, welche
/// Zahl bestätigt ist und welche nur vorgeschlagen."
///
/// Daraus folgt der Unterschied, auf den die neue Gruppe unten zielt, und
/// er ist der Kern der Entscheidung:
///
/// | Lage des Maßes am gewählten Tag | Im Feld | Dahinter |
/// |---|---|---|
/// | an diesem Tag gemessen | sein Wert, als Text | — |
/// | an diesem Tag **nicht** gemessen | leer | der blasse Wert vom letzten Mal |
///
/// Entschieden hat Tim die Sache, **nicht diese Testfassung.**
///
/// ## Nachtrag (11.11.2026): der dritte Fall des sealed-Typs
///
/// `UmfangsFormular` hat drei Fälle — `FormularLaedt`, `FormularUnlesbar`,
/// `FormularGelesen`. Die erste Fassung dieser Datei prüfte nur den
/// Unterschied zwischen „gelesen" und „noch nicht": Der Fußtext nennt
/// während des Lesens keinen Grund. **Den Fehlerfall deckte sie nicht ab**,
/// und der sah deshalb genauso aus wie der Ladefall — drei Fälle im Typ,
/// zwei Auskünfte auf dem Schirm, also trägt einer der drei nichts. Genau
/// dafür gibt es in `Messwert<T>` den Unterschied zwischen `LeerNachLauf`
/// und `Fehlgeschlagen`.
///
/// Die neue Gruppe unten verlangt deshalb einen eigenen Schlüssel
/// (`umfaenge-eintragen-unlesbar`) und sucht im Übrigen **Muster**, keine
/// Beschriftungen: Welcher Satz dort steht, ist Sache der Ansicht; dass er
/// nichts über Tims Daten behauptet, solange niemand sie kennt, ist es
/// nicht. **Keine bestehende Erwartung ist verschoben** — die neuen Fälle
/// stehen daneben.
///
/// ## Was hier absichtlich **nicht** geprüft wird
///
/// - **Wie die vorbelegte Zahl geschrieben steht** („84,0" oder „84"). Die
///   Fälle unten lesen sie mit `UmfangsEingabe.parse` zurück: Was im Feld
///   steht, muss denselben Wert ergeben, der abgelegt ist — die
///   Schreibweise ist Sache der Ansicht.
/// - Layout, Farben, Abstände, Kartenüberschriften, Knopfbeschriftungen.
/// - Die Rechnungen selbst (`UmfangsEingabe`, `UmfangsMerge`) — die liegen
///   im Kern und sind dort geprüft.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099 —
/// echte Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  /// 12:00 Berliner Zeit am 15.03.2099 — Winterzeit, also UTC+1. Bewusst
  /// weit weg von dem Tag, an dem dieser Test läuft: Nur so fällt auf, wenn
  /// jemand `DateTime.now()` statt `clockProvider` benutzt.
  final jetzt = DateTime.utc(2099, 3, 15, 11);
  const heute = '2099-03-15';
  const gestern = '2099-03-14';
  const vorwoche = '2099-03-08';

  const hinweisText =
      'Für diesen Tag ist schon eine Messung eingetragen. Sichern ändert '
      'sie, statt eine zweite anzulegen.';

  /// Wonach ein „keine Daten"-Grund klingt. Während gelesen wird, darf
  /// nichts davon dastehen (`01`).
  final leerMuster = RegExp(
    r'noch keine|keine frühere|noch nichts|nichts erfasst|keine Messung',
    caseSensitive: false,
  );

  /// Wonach eine Aussage über Tims Datenlage klingt. Solange nicht
  /// feststeht, was vorliegt, darf nichts davon dastehen.
  final datenlageBehauptung = RegExp(
    r'nichts gemessen|keine Vorwerte|noch keine Messung|schon eine Messung',
    caseSensitive: false,
  );

  /// Wonach „es läuft noch" klingt. Nach einem gescheiterten Lauf läuft
  /// nichts mehr.
  final ladeBehauptung = RegExp(
    r'wird gelesen|wird geladen|lädt',
    caseSensitive: false,
  );

  final schirm = find.byKey(const Key('umfaenge-eintragen'));
  final datumZeile = find.byKey(const Key('umfaenge-eintragen-datum'));
  final hinweis = find.byKey(const Key('umfaenge-eintragen-hinweis'));
  final fuss = find.byKey(const Key('umfaenge-eintragen-fuss'));
  final problem = find.byKey(const Key('umfaenge-eintragen-problem'));
  final unlesbar = find.byKey(const Key('umfaenge-eintragen-unlesbar'));
  final sichernKnopf = find.byKey(const Key('umfaenge-eintragen-sichern'));

  Finder feld(Umfang mass) =>
      find.byKey(Key('umfaenge-feld-${mass.schluessel}'));
  Finder zeile(Umfang mass) =>
      find.byKey(Key('umfaenge-zeile-${mass.schluessel}'));

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Legt eine Messung unmittelbar in der Tabelle ab — am Schirm vorbei,
  /// wie eine frühere Sitzung es getan hätte.
  Future<void> lege(String tag, Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: tag, werte: werte);

  /// Liest unmittelbar aus der Tabelle, nicht über den Schirm: Was hier
  /// steht, hat den Schirm überlebt.
  Future<Map<Umfang, double>> abgelegt(String tag) async =>
      (await UmfaengeRepository(db).messungAm(tag))?.werte ?? const {};

  Future<List<String>> abgelegteTage() async => [
    for (final messung in await UmfaengeRepository(db).messungen())
      BerlinCalendar.dayKey(messung.zeitpunkt),
  ];

  ProviderContainer behaelter({UmfaengeRepository? repo}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        // Der Schirm fragt Apple Health nicht; die Attrappe steht hier,
        // damit ein Provider, der später einen Lauf dazubekommt, nicht in
        // `UnimplementedError` läuft.
        healthProvider.overrideWithValue(_LeereQuelle()),
        if (repo != null) umfaengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Gastgeber: das Mehr-Menü auf einem Navigator, der jeden Befehl des
  /// [AppRouter] schiebt — wie `RootView` es für den Stapel eines Tabs tut.
  Future<GlobalKey<NavigatorState>> zeigeMehr(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    // Ein hoher Schirm, damit fünfzehn Felder, drei Karten und das Datum
    // gleichzeitig aufgebaut und sichtbar sind. Ohne das müsste jeder Fall
    // selbst scrollen, und die Geometrieprüfung unten verglich Rechtecke
    // aus verschiedenen Scrollständen.
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    final router = AppRouter();
    void schiebe() {
      final befehl = router.nimmBefehl();
      if (befehl == null) return;
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: befehl.builder),
      );
    }

    router.addListener(schiebe);
    addTearDown(() => router.removeListener(schiebe));

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(
          navigatorKey: navigator,
          home: MehrView(router: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigator;
  }

  Finder umfaengeZeile() => find.widgetWithText(IconRow, 'Umfänge messen');

  /// Mehr › Umfänge messen, und warten, bis der Schirm steht.
  Future<GlobalKey<NavigatorState>> zeigeFormular(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    final navigator = await zeigeMehr(tester, container ?? behaelter());
    await tester.tap(umfaengeZeile());
    await tester.pumpAndSettle();
    expect(
      schirm,
      findsOneWidget,
      reason: 'Mehr › Umfänge messen führt auf das Formular (Plan, 2.3).',
    );
    return navigator;
  }

  /// Alle Texte des Baums, zusammengefügt, Leerraum vereinheitlicht.
  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Alle Texte unter [wurzel], zusammengefügt, Leerraum vereinheitlicht.
  String textUnter(WidgetTester tester, Finder wurzel) => tester
      .widgetList<Text>(
        find.descendant(of: wurzel, matching: find.byType(Text), matchRoot: true),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Was im Feld **steht** — nicht, was als Platzhalter dahinterliegt.
  String feldText(WidgetTester tester, Umfang mass) => tester
      .widget<EditableText>(
        find.descendant(of: feld(mass), matching: find.byType(EditableText)),
      )
      .controller
      .text;

  String? platzhalter(WidgetTester tester, Umfang mass) =>
      tester.widget<CupertinoTextField>(feld(mass)).placeholder;

  Future<void> tippeIns(
    WidgetTester tester,
    Umfang mass,
    String text,
  ) async {
    await tester.ensureVisible(feld(mass));
    await tester.pumpAndSettle();
    await tester.enterText(feld(mass), text);
    await tester.pumpAndSettle();
  }

  Future<void> sichere(WidgetTester tester) async {
    expect(sichernKnopf, findsOneWidget, reason: 'Siehe „Die Schlüssel".');
    await tester.ensureVisible(sichernKnopf);
    await tester.pumpAndSettle();
    await tester.tap(sichernKnopf);
    await tester.pumpAndSettle();
  }

  /// Klappt das Rad auf, falls nötig, und meldet ihm [tag].
  Future<void> waehleDatum(WidgetTester tester, DateTime tag) async {
    if (find.byType(CupertinoDatePicker).evaluate().isEmpty) {
      await tester.ensureVisible(datumZeile);
      await tester.pumpAndSettle();
      await tester.tap(datumZeile);
      await tester.pumpAndSettle();
    }
    final rad = find.byType(CupertinoDatePicker);
    expect(
      rad,
      findsOneWidget,
      reason:
          'Entweder steht das Rad im Schirm oder ein Tipp auf '
          '`umfaenge-eintragen-datum` klappt genau eines auf.',
    );
    tester.widget<CupertinoDatePicker>(rad).onDateTimeChanged(tag);
    await tester.pumpAndSettle();
  }

  CupertinoDatePicker rad(WidgetTester tester) =>
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));

  // ───────────────────────────────────────────────────────────────────────
  // Fünfzehn Felder, in jedem Zustand
  // ───────────────────────────────────────────────────────────────────────

  group('Fünfzehn Felder, und zwar immer', () {
    testWidgets('ohne eine einzige frühere Messung stehen alle fünfzehn da', (
      tester,
    ) async {
      await zeigeFormular(tester);

      for (final mass in Umfang.values) {
        expect(
          feld(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel}: Eine Anzeige, die es gibt, hat genau '
              'eine Form (`CLAUDE.md`). Ein Feld, das ohne Vorwert '
              'wegfällt, sieht aus wie ein Maß, das die App nicht kennt',
        );
      }
      expect(
        find.byType(CupertinoTextField),
        findsNWidgets(Umfang.values.length),
        reason: 'Fünfzehn Maße, fünfzehn Felder — kein sechzehntes',
      );
    });

    testWidgets('ohne frühere Messung tragen sie keinen Zahl-Platzhalter', (
      tester,
    ) async {
      await zeigeFormular(tester);

      for (final mass in Umfang.values) {
        final text = platzhalter(tester, mass) ?? '';
        expect(
          RegExp(r'\d').hasMatch(text),
          isFalse,
          reason:
              '${mass.schluessel}: Es gibt keine Werte vom letzten Mal — '
              'eine Zahl dahinter wäre erfunden (`CLAUDE.md`, keine '
              'hartcodierten Werte). Platzhalter „$text"',
        );
      }
    });

    testWidgets('mit früheren Werten stehen sie als Platzhalter dahinter', (
      tester,
    ) async {
      await lege(vorwoche, {
        Umfang.brust: 103.5,
        Umfang.taille: 84.0,
        Umfang.wadeLinks: 37.8,
      });
      await zeigeFormular(tester);

      expect(platzhalter(tester, Umfang.brust), contains('103'));
      expect(platzhalter(tester, Umfang.taille), contains('84'));
      expect(platzhalter(tester, Umfang.wadeLinks), contains('37'));
      expect(
        feldText(tester, Umfang.brust),
        isEmpty,
        reason:
            'Der Platzhalter ist ein Vergleich, keine Eingabe — gespeichert '
            'wird, was getippt wird (`CircumferenceEntryView.swift:100`)',
      );
    });

    testWidgets('die Felder stehen in der Reihenfolge Arme, Rumpf, Beine', (
      tester,
    ) async {
      await zeigeFormular(tester);

      var vorigesOben = double.negativeInfinity;
      for (final mass in Umfang.values) {
        final oben = tester.getRect(zeile(mass)).top;
        expect(
          oben,
          greaterThan(vorigesOben),
          reason:
              '${mass.schluessel} steht nicht unter seinem Vorgänger. Beim '
              'Messen arbeitet man mit dem Maßband den Körper hinunter — '
              'die Übersicht sortiert nach Wichtigkeit, das Formular nach '
              'Körperregion (SPEC 4.6, bestätigt am 11.11.2026)',
        );
        vorigesOben = oben;
      }
    });

    testWidgets('und beide Zustände haben dieselbe Geometrie', (tester) async {
      // Die Regel aus `CLAUDE.md`: Werte da, keine Werte — dieselbe Höhe,
      // dieselbe Breite, dieselbe Stelle. Nur die Füllung unterscheidet
      // sich.
      await zeigeFormular(tester);
      final ohne = {
        for (final mass in Umfang.values) mass: tester.getRect(zeile(mass)),
      };
      expect(fuss, findsOneWidget, reason: 'Der Fußtext steht in beiden Fällen.');

      await lege(vorwoche, {
        for (final mass in Umfang.values) mass: 42.0 + mass.index,
      });
      await zeigeFormular(tester, container: behaelter());
      expect(fuss, findsOneWidget);

      for (final mass in Umfang.values) {
        final mit = tester.getRect(zeile(mass));
        expect(
          mit.top,
          moreOrLessEquals(ohne[mass]!.top, epsilon: 0.5),
          reason:
              '${mass.schluessel} rutscht, sobald Vorwerte da sind. Dann '
              'springt der ganze Schirm beim ersten Messen — genau der '
              'Fehler, gegen den die Keine-Daten-Regel gebaut ist',
        );
        expect(
          mit.height,
          moreOrLessEquals(ohne[mass]!.height, epsilon: 0.5),
          reason: '${mass.schluessel}: dieselbe Höhe, nur andere Füllung',
        );
        expect(
          mit.width,
          moreOrLessEquals(ohne[mass]!.width, epsilon: 0.5),
          reason: '${mass.schluessel}: dieselbe Breite',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Bestätigt oder nur vorgeschlagen — der Unterschied muss sichtbar sein
  // ───────────────────────────────────────────────────────────────────────

  group('Für einen Tag mit Messung stehen dessen Werte in den Feldern', () {
    /// Der Wert, der wirklich im Feld steht, zurückgelesen über die
    /// Prüfung des Kerns — so hängt kein Fall an der Schreibweise.
    double? wertImFeld(WidgetTester tester, Umfang mass) =>
        switch (UmfangsEingabe.parse(feldText(tester, mass))) {
          UmfangOk(:final zentimeter) => zentimeter,
          _ => null,
        };

    testWidgets('als Text, nicht als blasser Platzhalter', (tester) async {
      await lege(heute, {Umfang.taille: 84.0, Umfang.brust: 103.5});
      await zeigeFormular(tester);

      expect(
        wertImFeld(tester, Umfang.taille),
        84.0,
        reason:
            'Tim am 11.11.2026: „Man soll sehen, welche Zahl bestätigt ist '
            'und welche nur vorgeschlagen." Gefunden: '
            '„${feldText(tester, Umfang.taille)}"',
      );
      expect(wertImFeld(tester, Umfang.brust), 103.5);
    });

    testWidgets('und ein Maß, das an diesem Tag fehlt, bleibt leer mit '
        'blassem Vorwert — das ist der Unterschied', (tester) async {
      // Vorwoche: beide gemessen. Heute: nur die Taille. Die Brust muss
      // sich als „nur vorgeschlagen" von der Taille unterscheiden lassen.
      await lege(vorwoche, {Umfang.taille: 85.0, Umfang.brust: 103.5});
      await lege(heute, {Umfang.taille: 84.0});
      await zeigeFormular(tester);

      expect(
        wertImFeld(tester, Umfang.taille),
        84.0,
        reason: 'heute gemessen — bestätigt',
      );
      expect(
        feldText(tester, Umfang.brust),
        isEmpty,
        reason:
            'heute **nicht** gemessen. Stünde 103,5 als Text im Feld, '
            'behauptete der Schirm eine Messung, die es an diesem Tag nicht '
            'gab — und ein Tipp auf „Sichern" machte sie wahr',
      );
      expect(
        platzhalter(tester, Umfang.brust),
        contains('103'),
        reason: 'der Vorschlag vom letzten Mal steht blass dahinter',
      );
      expect(
        RegExp(r'\d').hasMatch(platzhalter(tester, Umfang.wadeLinks) ?? ''),
        isFalse,
        reason:
            'nie gemessen heißt weder Wert noch Vorwert — und trotzdem '
            'steht das Feld da',
      );
    });

    testWidgets('die vorbelegten Werte lassen sich ändern', (tester) async {
      await lege(heute, {Umfang.taille: 84.0, Umfang.brust: 103.5});
      await zeigeFormular(tester);

      await tippeIns(tester, Umfang.taille, '83,5');
      await sichere(tester);

      expect(await abgelegt(heute), {
        Umfang.taille: 83.5,
        Umfang.brust: 103.5,
      }, reason: 'geändert wird, was angefasst wurde — der Rest bleibt');
      expect(await abgelegteTage(), [heute]);
    });

    testWidgets('und die Belegung zieht mit, wenn das Datum wechselt', (
      tester,
    ) async {
      await lege(gestern, {Umfang.taille: 84.0});
      await zeigeFormular(tester);

      expect(
        feldText(tester, Umfang.taille),
        isEmpty,
        reason: 'Für heute liegt nichts vor — das Feld ist leer.',
      );

      await waehleDatum(tester, DateTime(2099, 3, 14, 12));
      expect(
        wertImFeld(tester, Umfang.taille),
        84.0,
        reason: 'Der gewählte Tag trägt eine Messung, also steht sie da.',
      );

      await waehleDatum(tester, DateTime(2099, 3, 8, 12));
      expect(
        feldText(tester, Umfang.taille),
        isEmpty,
        reason:
            'Der Wert eines anderen Tages darf nicht stehen bleiben — er '
            'würde beim Sichern zu einer Messung dieses Tages',
      );
      expect(
        RegExp(r'\d').hasMatch(platzhalter(tester, Umfang.taille) ?? ''),
        isFalse,
        reason:
            'und auch kein Vorwert: Vor dem 08.03. wurde nie gemessen '
            '(`werteVomLetztenMal` sieht nur zurück)',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Während des Ladens steht nie ein „keine Daten"-Grund (`01`)
  // ───────────────────────────────────────────────────────────────────────

  group('Während des Lesens steht kein „keine Daten"-Grund (`01`)', () {
    testWidgets('die fünfzehn Felder stehen schon da, der Grund nicht', (
      tester,
    ) async {
      final antwort = Completer<void>();
      final container = behaelter(repo: _HaengendesRepo(db, antwort));
      await zeigeMehr(tester, container);

      await tester.tap(umfaengeZeile());
      // Kein `pumpAndSettle`: Ein Ladezeichen, das sich dreht, käme nie zur
      // Ruhe. Eine Sekunde reicht für den Übergang der Seite.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(schirm, findsOneWidget, reason: 'Der Schirm steht, er lädt nur.');
      for (final mass in Umfang.values) {
        expect(
          feld(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel}: Der Ladezustand ist kein Leerstand. Die '
              'Felder hängen an keinem Lauf — man kann tippen, während die '
              'Platzhalter noch unterwegs sind',
        );
      }

      final texte = tester.widgetList<Text>(find.byType(Text)).map(textOf);
      for (final text in texte) {
        expect(
          leerMuster.hasMatch(text),
          isFalse,
          reason:
              'Text „$text" nennt einen „keine Daten"-Grund, während noch '
              'gelesen wird — das ist Fehler `01`, wortgleich im neuen Code',
        );
      }
      expect(
        hinweis,
        findsNothing,
        reason:
            'Solange niemand weiß, ob für diesen Tag schon etwas vorliegt, '
            'wird es auch nicht behauptet',
      );

      antwort.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('erst wenn der Lauf fertig ist, darf er sagen, dass nichts '
        'da ist', (tester) async {
      final antwort = Completer<void>();
      final container = behaelter(repo: _HaengendesRepo(db, antwort));
      await zeigeMehr(tester, container);

      await tester.tap(umfaengeZeile());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      antwort.complete();
      await tester.pumpAndSettle();

      expect(schirm, findsOneWidget);
      for (final mass in Umfang.values) {
        expect(feld(mass), findsOneWidget);
      }
      expect(
        fuss,
        findsOneWidget,
        reason: 'Der Fußtext steht vor wie nach dem Lesen an derselben Stelle.',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ein Wert, der dastand, steht wieder da (`32`)
  // ───────────────────────────────────────────────────────────────────────

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('eingetragen, zurück, wieder auf — die Werte sind da', (
      tester,
    ) async {
      final navigator = await zeigeFormular(tester);

      await waehleDatum(tester, DateTime(2099, 3, 14, 12));
      await tippeIns(tester, Umfang.taille, '84,0');
      await tippeIns(tester, Umfang.brust, '103,5');
      await sichere(tester);

      expect(
        await abgelegt(gestern),
        {Umfang.taille: 84.0, Umfang.brust: 103.5},
        reason:
            'Was der Schirm sichert, liegt in der Tabelle — nicht nur im '
            'Zustand eines Widgets',
      );
      expect(
        schirm,
        findsNothing,
        reason: 'Gesichert heißt fertig: der Schirm geht zu.',
      );
      expect(
        navigator.currentState!.canPop(),
        isFalse,
        reason: 'Zurück landet im Mehr-Menü, von dem aus geöffnet wurde.',
      );

      await tester.tap(umfaengeZeile());
      await tester.pumpAndSettle();

      expect(schirm, findsOneWidget);
      expect(
        platzhalter(tester, Umfang.taille),
        contains('84'),
        reason:
            'Der Wert von gestern ist „der vom letzten Mal" — er war weg, '
            'wenn er hier nicht wieder dasteht (`32`)',
      );
      expect(platzhalter(tester, Umfang.brust), contains('103'));
    });

    testWidgets('und ein zweites Mal gesichert ändert ihn, statt ihn zu '
        'verdoppeln', (tester) async {
      await lege(gestern, {Umfang.taille: 84.0});
      await zeigeFormular(tester);

      await waehleDatum(tester, DateTime(2099, 3, 14, 12));
      await tippeIns(tester, Umfang.taille, '83,5');
      await sichere(tester);

      expect(await abgelegt(gestern), {Umfang.taille: 83.5});
      expect(
        await abgelegteTage(),
        [gestern],
        reason: 'SPEC 4.6: eine zweite Eingabe am selben Tag ändert die erste',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Hinweis „für diesen Tag liegt schon eine Messung"
  // ───────────────────────────────────────────────────────────────────────

  group('Der Hinweis steht vorher, nicht hinterher', () {
    testWidgets('ohne Messung für den Tag steht er nicht da', (tester) async {
      await lege(vorwoche, {Umfang.taille: 85.0});
      await zeigeFormular(tester);

      expect(
        hinweis,
        findsNothing,
        reason:
            'Für heute liegt nichts vor — der Hinweis behauptete sonst eine '
            'Messung, die es nicht gibt',
      );
      expect(find.textContaining('schon eine Messung'), findsNothing);
    });

    testWidgets('liegt für heute eine Messung, steht er beim Öffnen da — '
        'vor dem Sichern', (tester) async {
      await lege(heute, {Umfang.taille: 84.0});
      await zeigeFormular(tester);

      expect(
        hinweis,
        findsOneWidget,
        reason:
            'Der Schirm sagt es vorher, nicht hinterher (Entwurf '
            '`umfaenge-eintragen.js`, Variante `schon-da`)',
      );
      expect(
        textUnter(tester, hinweis),
        contains(hinweisText),
        reason:
            'Der Satz steht wörtlich in Spec und Entwurf; er ist die '
            'einzige Stelle, die sagt, dass Sichern **ändert**',
      );
    });

    testWidgets('er folgt dem gewählten Tag, nicht dem heutigen', (
      tester,
    ) async {
      await lege(gestern, {Umfang.taille: 84.0});
      await zeigeFormular(tester);

      expect(
        hinweis,
        findsNothing,
        reason: 'Vorbelegt ist heute, und für heute liegt nichts vor.',
      );

      await waehleDatum(tester, DateTime(2099, 3, 14, 12));
      expect(
        hinweis,
        findsOneWidget,
        reason: 'Für den nun gewählten Tag liegt eine Messung vor.',
      );

      await waehleDatum(tester, DateTime(2099, 3, 8, 12));
      expect(hinweis, findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ein Feld hält Text, keine Zahl
  // ───────────────────────────────────────────────────────────────────────

  group('Ein Feld hält Text, keine Zahl', () {
    testWidgets('„27," lässt sich tippen, ohne dass etwas rot wird', (
      tester,
    ) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.unterarmRechts, '27,');

      expect(
        feldText(tester, Umfang.unterarmRechts),
        '27,',
        reason:
            'Ein halb getippter Wert ist der Normalfall. Ein Feld, das die '
            'Eingabe beim Komma verschluckt, ist unbedienbar',
      );
      expect(
        problem,
        findsNothing,
        reason:
            'Geprüft wird erst beim Sichern — ein Feld, das beim dritten '
            'Anschlag rot wird, erzieht zum Wegschauen',
      );
      expect(
        zeile(Umfang.unterarmRechts),
        findsOneWidget,
        reason: 'und die Zeile verschwindet erst recht nicht',
      );
    });

    testWidgets('ein Punkt tut es auch, und „cm" stört nicht', (tester) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.hals, '39.5');
      await tippeIns(tester, Umfang.brust, '103,5 cm');
      expect(problem, findsNothing);

      await sichere(tester);

      expect(await abgelegt(heute), {Umfang.hals: 39.5, Umfang.brust: 103.5});
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Abgewiesen wird beim Sichern, und die Zeile sagt, was dasteht
  // ───────────────────────────────────────────────────────────────────────

  group('Unplausible Werte werden abgewiesen', () {
    testWidgets('275 cm misst niemand — und die Zeile sagt, was dasteht', (
      tester,
    ) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.taille, '275');
      await tippeIns(tester, Umfang.hals, '39,5');
      await sichere(tester);

      expect(problem, findsOneWidget);
      final text = textUnter(tester, problem);
      expect(
        text,
        contains(Umfang.taille.deutsch),
        reason:
            'Bei fünfzehn Feldern muss die Zeile sagen, **welches** nicht '
            'trägt. Gefunden: „$text"',
      );
      expect(
        text,
        contains('275'),
        reason:
            '`UmfangAusserhalb` trägt den gelesenen Wert eigens mit, damit '
            'die rote Zeile sagen kann, was dasteht. Gefunden: „$text"',
      );

      expect(
        await abgelegteTage(),
        isEmpty,
        reason:
            'Abgewiesen heißt abgewiesen — auch der gültige Hals darf nicht '
            'halb gespeichert werden, sonst steht eine Messung da, die der '
            'Nutzer nie bestätigt hat',
      );
      expect(
        schirm,
        findsOneWidget,
        reason:
            'Ein Schirm, der nach einer Abweisung zuginge, nähme die '
            'eingetippten Zahlen mit',
      );
      expect(feldText(tester, Umfang.hals), '39,5');
    });

    testWidgets('unter 10 cm ebenso', (tester) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.wadeRechts, '3');
      await sichere(tester);

      expect(problem, findsOneWidget);
      expect(await abgelegteTage(), isEmpty);
    });

    testWidgets('was keine Zahl ist, auch', (tester) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.brust, '27,');
      await sichere(tester);

      expect(
        problem,
        findsOneWidget,
        reason: 'Beim Sichern ist „27," keine Zahl mehr, sondern ein Rest',
      );
      expect(await abgelegteTage(), isEmpty);
    });

    testWidgets('und nach dem Berichtigen geht es durch', (tester) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.taille, '275');
      await sichere(tester);
      expect(problem, findsOneWidget);

      await tippeIns(tester, Umfang.taille, '84,0');
      await sichere(tester);

      expect(await abgelegt(heute), {Umfang.taille: 84.0});
      expect(schirm, findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Leere Felder werden nicht gespeichert
  // ───────────────────────────────────────────────────────────────────────

  group('Leere Felder werden nicht gespeichert', () {
    testWidgets('zwei getippte Werte ergeben zwei Maße, nicht fünfzehn', (
      tester,
    ) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.taille, '84,0');
      await tippeIns(tester, Umfang.oberarmRechtsAngespannt, '38,2');
      await sichere(tester);

      expect(await abgelegt(heute), {
        Umfang.taille: 84.0,
        Umfang.oberarmRechtsAngespannt: 38.2,
      }, reason: '`0` ist keine Antwort auf „kein Wert" (`CLAUDE.md`)');
    });

    testWidgets('ein Platzhalter allein ist keine Eingabe', (tester) async {
      await lege(vorwoche, {Umfang.taille: 85.0, Umfang.brust: 103.5});
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.taille, '84,0');
      await sichere(tester);

      expect(
        await abgelegt(heute),
        {Umfang.taille: 84.0},
        reason:
            'Wer nur die Taille misst, trägt nur die Taille ein. Die '
            'Platzhalter als Werte zu übernehmen behauptete einen Verlauf, '
            'den es nicht gibt',
      );
    });

    testWidgets('ein ganz leeres Formular schreibt nichts', (tester) async {
      await zeigeFormular(tester);
      await sichere(tester);

      expect(await abgelegteTage(), isEmpty);
      expect(
        schirm,
        findsOneWidget,
        reason:
            'Nichts zu sichern ist kein Sichern — der Schirm bleibt stehen '
            'statt einen leeren Tag anzulegen',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Gescheitertes Lesen ist etwas anderes als laufendes
  // ───────────────────────────────────────────────────────────────────────

  group('Ein gescheitertes Lesen benennt sich (`FormularUnlesbar`)', () {
    testWidgets('der Schirm sagt, dass das Lesen gescheitert ist', (
      tester,
    ) async {
      await zeigeFormular(tester, container: behaelter(repo: _KaputtesRepo(db)));

      expect(
        unlesbar,
        findsOneWidget,
        reason:
            '`UmfangsFormular` hat drei Fälle. Wird der dritte mit '
            '`is FormularGelesen ? … : null` eingeebnet, trägt er nichts '
            'mehr: Dann sieht ein gescheitertes Lesen aus wie ein '
            'laufendes, und niemand erfährt, warum die Vorwerte fehlen',
      );
    });

    testWidgets('die fünfzehn Felder stehen trotzdem da — gemessen wird '
        'weiter', (tester) async {
      await zeigeFormular(tester, container: behaelter(repo: _KaputtesRepo(db)));

      for (final mass in Umfang.values) {
        expect(
          feld(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel}: Dass die alten Werte sich nicht lesen '
              'ließen, hindert niemanden daran, eine neue Messung '
              'einzutragen',
        );
      }
      expect(sichernKnopf, findsOneWidget);
      expect(fuss, findsOneWidget, reason: 'der Fußtext steht in jedem Zustand');
    });

    testWidgets('und behauptet weder „wird gelesen" noch eine Datenlage', (
      tester,
    ) async {
      await zeigeFormular(tester, container: behaelter(repo: _KaputtesRepo(db)));

      final texte = alleTexte(tester);
      expect(
        ladeBehauptung.hasMatch(texte),
        isFalse,
        reason:
            'Ein gescheitertes Lesen läuft nicht mehr. Gefunden in: '
            '„$texte"',
      );
      expect(
        datenlageBehauptung.hasMatch(texte),
        isFalse,
        reason:
            '„Vorher wurde nichts gemessen" ist eine Auskunft über Tims '
            'Daten, und die liegt nicht vor — sie wäre hier geraten. '
            'Gefunden in: „$texte"',
      );
      expect(
        hinweis,
        findsNothing,
        reason:
            'Ob für diesen Tag schon eine Messung vorliegt, ist unbekannt '
            '— also wird es nicht behauptet',
      );
    });

    testWidgets('lädt und unlesbar sehen nicht gleich aus', (tester) async {
      final antwort = Completer<void>();
      final container = behaelter(repo: _HaengendesRepo(db, antwort));
      await zeigeMehr(tester, container);
      await tester.tap(umfaengeZeile());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final beimLaden = alleTexte(tester);
      antwort.complete();
      await tester.pumpAndSettle();

      await zeigeFormular(tester, container: behaelter(repo: _KaputtesRepo(db)));
      final beimFehler = alleTexte(tester);

      expect(
        beimFehler,
        isNot(beimLaden),
        reason:
            'Heute sind beide Zustände wortgleich: Der Schirm unterscheidet '
            'nur `FormularGelesen` von „alles andere". Drei Fälle im '
            'sealed-Typ, zwei Auskünfte auf dem Schirm — einer der drei '
            'trägt dann nichts',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Datum
  // ───────────────────────────────────────────────────────────────────────

  group('Das Datum', () {
    testWidgets('ist mit heute vorbelegt — aus der Uhr, nicht aus '
        'DateTime.now()', (tester) async {
      await zeigeFormular(tester);
      await waehleDatum(tester, DateTime(2099, 3, 15, 12));
      final gewaehlt = rad(tester).initialDateTime;

      expect(
        (gewaehlt.year, gewaehlt.month, gewaehlt.day),
        (2099, 3, 15),
        reason:
            'Die Uhr steht auf dem 15.03.2099; ein anderer Tag käme aus '
            '`DateTime.now()` (`clockProvider`, `CLAUDE.md`)',
      );
    });

    testWidgets('und ohne es anzufassen landet die Messung auf heute', (
      tester,
    ) async {
      await zeigeFormular(tester);
      await tippeIns(tester, Umfang.taille, '84,0');
      await sichere(tester);

      expect(await abgelegteTage(), [heute]);
    });

    testWidgets('ist rückdatierbar', (tester) async {
      await zeigeFormular(tester);
      await waehleDatum(tester, DateTime(2099, 3, 8, 12));
      await tippeIns(tester, Umfang.taille, '85,0');
      await sichere(tester);

      expect(
        await abgelegteTage(),
        [vorwoche],
        reason:
            'Wer abends nachträgt, was er morgens gemessen hat, darf das '
            'Datum zurückstellen',
      );
    });

    testWidgets('aber nicht in die Zukunft', (tester) async {
      await zeigeFormular(tester);
      await waehleDatum(tester, DateTime(2099, 3, 15, 12));
      final grenze = rad(tester).maximumDate;

      expect(
        grenze,
        isNotNull,
        reason:
            'Ohne Obergrenze lässt sich ein Umfang für übermorgen '
            'eintragen, und der stünde im Verlauf vor seiner Messung',
      );
      expect(
        (grenze!.year, grenze.month, grenze.day),
        (2099, 3, 15),
        reason: 'Die Grenze ist heute, nicht irgendein späterer Tag.',
      );
    });
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt.
///
/// Geschrieben wird dabei nie — ein Fall, der dieses Repository benutzt,
/// prüft den Ladezustand und sonst nichts.
class _HaengendesRepo extends UmfaengeRepository {
  _HaengendesRepo(super.db, this.antwort);

  final Completer<void> antwort;

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) async {
    await antwort.future;
    return const [];
  }

  @override
  Future<Umfangsmessung?> messungAm(String tag) async {
    await antwort.future;
    return null;
  }

  @override
  Future<Map<Umfang, double>> werteVomLetztenMal({
    required String vorTag,
  }) async {
    await antwort.future;
    return const {};
  }

  @override
  Future<String?> letzterMesstag() async {
    await antwort.future;
    return null;
  }
}

/// Ein Repository, dessen Lesen scheitert — der Zustand
/// `FormularUnlesbar`. **Schreiben bleibt möglich:** Dass die alten Werte
/// sich nicht lesen ließen, hindert niemanden am Messen, und ein Stumpf,
/// der auch dabei würfe, prüfte eine andere Frage.
class _KaputtesRepo extends UmfaengeRepository {
  _KaputtesRepo(super.db);

  @override
  Future<Umfangsmessung?> messungAm(String tag) =>
      Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));

  @override
  Future<Map<Umfang, double>> werteVomLetztenMal({required String vorTag}) =>
      Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Eine Quelle, die nichts hergibt. Der Schirm fragt Apple Health nicht.
class _LeereQuelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);
}
