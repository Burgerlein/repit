import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/makro_balken.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/ernaehrung/aufteilung_view.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show huelle, textOf;
import '../tag/behaelter_im_baum.dart';

/// Tests für **Raster, Balken gegen das Mahlzeitenziel und „Alle
/// Nährwerte"** im Mahlzeit-Detail (#442 unter #385, Schnitt 3) —
/// `lib/ernaehrung/mahlzeit_kopf.dart`, eingehängt in
/// `lib/ernaehrung/mahlzeit_view.dart`, dazu der Schalter an
/// `lib/design/makro_balken.dart`.
///
/// **Ein Agent genügt** (Widget-Test, `CLAUDE.md`): Diese Datei entsteht
/// zuerst, wird rot gesehen und **vor der Implementierung committet**. Ab
/// da bewacht sie `.githooks/pre-commit`: Sie darf ausgeführt, aber nicht
/// verändert werden. Wer einen Fall für falsch hält, meldet ihn.
///
/// Nachbarn: `mahlzeit_ziel_test.dart` (die Felder in `MahlzeitInhalt`),
/// `mahlzeit_view_test.dart` (Liste, Löschen, Laden des Schirms — für #442
/// nachgezogen).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// „Mahlzeit-Detail (Schnitt 3)", „Leerzustände", V4 und V17–V19; Plan
/// Task 13, Step 2; Entwurf `docs/screens/screens/mahlzeit.js`, Zustände
/// `vorschlag-raster`, `vorschlag-raster-leer`,
/// `vorschlag-raster-ohne-ziel`. Von Tim am 10.11.2026 übernommen:
///
/// - **Entscheidung 11:** 2×2-Raster (kcal, Kohlenhydrate, Eiweiß, Fett),
///   darunter **ein** Balken, kcal gegen das Mahlzeitenziel. Keine
///   Makro-Ziele je Mahlzeit.
/// - **Entscheidung 4 / V18:** Über dem Ziel bleibt der Balken voll und
///   wird nicht rot. `MakroBalken` bekommt dafür einen Schalter,
///   Vorgabe wie bisher.
/// - **Entscheidung 7:** Ohne Eintrag „– / 180 kcal", nicht „0 / 180".
/// - **V4:** 0 % → Balken leer mit „–/–", darunter „0 % deines
///   Tagesziels — so eingestellt".
/// - **V17:** „Alle Nährwerte" ist zugeklappt und enthält die bisherigen
///   sechs Zeilen samt Schlüsseln. Die Kalorienzeile entfällt.
/// - **V19:** „25 % deines Tagesziels von 1.800 kcal — so eingestellt";
///   ohne Tagesziel „25 % deines Tagesziels — es gibt noch kein
///   Kalorienziel"; ohne Aufteilung „Aufteilung des Tagesziels festlegen ›",
///   der `aufteilung` öffnet.
/// - **Leerzustände:** Raster und Balken haben in Werte, leer, ohne Ziel
///   und Laden dieselbe Form; beim Laden graue Formen.
///
/// ## Die Schlüssel
///
/// Aus der Spec: `mahlzeit-raster-<feld>`, `mahlzeit-ziel`,
/// `mahlzeit-ziel-satz`. Aus `mahlzeit_view_test.dart`: `mahlzeit-werte`,
/// `mahlzeit-werte-tabelle`, die sechs `mahlzeit-wert-…`, `mahlzeit-liste`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`<feld>` heißt `kcal`, `kohlenhydrate`, `eiweiss`, `fett`** (wie die
///   Schlüssel der Nährwertzeilen). Das ganze Raster trägt
///   `Key('mahlzeit-raster')`.
/// - **`Key('mahlzeit-werte-kopf')`** ist die tippbare Kopfzeile von „Alle
///   Nährwerte", `mahlzeit-werte` der ganze Abschnitt.
/// - **`mahlzeit-ziel-satz` ist der Satz unter dem Balken, und ohne
///   Aufteilung ist er selbst der Weg:** Ein Tipp darauf öffnet
///   `aufteilung` über den Router (`oeffneAufteilung`, `AppTarget.aktuell`,
///   also auf den Stapel des Tabs, in dem man ist). `MahlzeitView` bekommt
///   dafür den `router`, den es schon hat.
/// - **„Voll" heißt: Die Füllung des Balkens (`FractionallySizedBox`, wie in
///   `MakroBalken`) hat den Faktor 1, „leer": keine Füllung über 0.** Nicht
///   rot heißt: Unter `mahlzeit-ziel` ist keine Fläche in `Palette.warn`.
/// - **Zahlen im Raster:** kcal ganz, Gramm mit einer Nachkommastelle und
///   deutschem Komma, wie die Nährwertzeilen bisher und wie der Entwurf
///   („69,4 g"). Geprüft wird nur die Zahl, nicht die Einheit.
/// - **Der Satz wird mit gewöhnlichen Leerzeichen verglichen**; schmale
///   oder geschützte Leerzeichen (z. B. vor „%") sind erlaubt und werden
///   vorher ersetzt.
/// - **„Laden" ist der Zustand, in dem die eigenen Einträge oder die
///   Aufteilungen noch nicht gelesen sind** (`MahlzeitInhalt.laedt`,
///   `MahlzeitInhalt.zielLaedt` aus `mahlzeit_ziel_test.dart`). Dann steht
///   weder „–/–" noch „festlegen", sondern eine graue Form.
///
/// ## Wie gewartet wird
///
/// Das Tagesziel liegt als feste Festlegung von Hand in der Tabelle
/// (1.800 kcal), Stammdaten sind leer, Apple Health ist durch, ohne Werte.
/// Ohne diese Festlegung gibt es kein Tagesziel. Hausform:
/// `mahlzeit_ziel_test.dart`. Jeder Fall prüft vorab am Tag, dass die Lage
/// stimmt, die er meint — so ist ein roter Fall ein fehlender Schirm und
/// keine kaputte Hülle.
///
/// Widget-Tests hängen den Behälter über `BehaelterImBaum` ein, nicht über
/// `UncontrolledProviderScope` — sonst scheitern sie am Zeitgeber des
/// laufenden Tages.
///
/// **Alle Zahlen und Daten hier sind erfunden**, Zeitpunkte im Jahr 2099.
void main() {
  // Mittwoch, 11.03.2099, 11:00 Berliner Zeit (MEZ, +1).
  const heute = '2099-03-11';
  final jetzt = DateTime.utc(2099, 3, 11, 10);

  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );

  // 25 · 35 · 30 · 10: Frühstück 450, Snack 180 kcal.
  final startwert = MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30);
  // 30 · 35 · 35 · 0: Der Snack hat 0 %.
  final ohneSnack = MahlzeitAufteilung(fruehstueck: 30, mittag: 35, abend: 35);

  Eintrag eintrag({
    required String name,
    Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
    int stundeUtc = 6,
    double? kcal,
    double? kohlenhydrateG,
    double? eiweissG,
    double? fettG,
  }) => Eintrag(
    tagesSchluessel: heute,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2099, 3, 11, stundeUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      kohlenhydrateG: kohlenhydrateG,
      eiweissG: eiweissG,
      fettG: fettG,
    ),
  );

  /// Zusammen 426 kcal, 69,4 g Kohlenhydrate, 6,7 g Eiweiß, 8,6 g Fett.
  List<Eintrag> fruehstueck426() => [
    eintrag(
      name: 'Prüfbrei',
      kcal: 300,
      kohlenhydrateG: 50,
      eiweissG: 4,
      fettG: 6,
    ),
    eintrag(
      name: 'Prüfobst',
      stundeUtc: 7,
      kcal: 126,
      kohlenhydrateG: 19.4,
      eiweissG: 2.7,
      fettG: 2.6,
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  Future<Huelle> harness({
    Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
    bool mitTagesziel = true,
    MahlzeitAufteilung? aufteilung,
    List<Eintrag> eigene = const [],
    bool eigeneLaufen = false,
    bool aufteilungenLaufen = false,
  }) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    if (mitTagesziel) await KalorienzielRepository(db).setze(ziel1800);
    if (aufteilung != null) {
      await MahlzeitAufteilungRepository(db)
          .setze(AufteilungAb(abTag: '2099-01-01', aufteilung: aufteilung));
    }
    final repo = ErnaehrungRepository(db);
    for (final e in eigene) {
      await repo.buche(e);
    }

    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        stammdatenProvider.overrideWith(() => _Stammdaten(const Stammdaten())),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt)),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
        ),
        if (eigeneLaufen)
          eigeneEintraegeProvider.overrideWith2(_NieEintraege.new),
        if (aufteilungenLaufen)
          mahlzeitAufteilungenProvider.overrideWith(_NieAufteilungen.new),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      router: router,
      app: BehaelterImBaum(
        container: container,
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: MahlzeitView(
              tagesSchluessel: heute,
              mahlzeit: mahlzeit,
              router: router,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> grosseFlaeche(WidgetTester tester) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist und kein
    // Fall selbst scrollen muss — und breit genug, dass kein Satz umbricht.
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    await grosseFlaeche(tester);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  /// Schmale und geschützte Leerzeichen werden zu gewöhnlichen.
  String normal(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

  String textUnter(WidgetTester tester, Key key) => normal(
    tester
        .widgetList<Text>(
          find.descendant(of: find.byKey(key), matching: find.byType(Text)),
        )
        .map(textOf)
        .join(' '),
  );

  String alleTexte(WidgetTester tester) =>
      normal(tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' '))
          .toLowerCase();

  const felder = ['kcal', 'kohlenhydrate', 'eiweiss', 'fett'];
  Key feld(String name) => Key('mahlzeit-raster-$name');

  const rasterKey = Key('mahlzeit-raster');
  const zielKey = Key('mahlzeit-ziel');
  const satzKey = Key('mahlzeit-ziel-satz');
  const listeKey = Key('mahlzeit-liste');

  const naehrwertZeilen = [
    Key('mahlzeit-wert-eiweiss'),
    Key('mahlzeit-wert-kohlenhydrate'),
    Key('mahlzeit-wert-zucker'),
    Key('mahlzeit-wert-fett'),
    Key('mahlzeit-wert-gesaettigt'),
    Key('mahlzeit-wert-ballaststoffe'),
  ];

  Finder platzhalterUnter(Key key) =>
      find.descendant(of: find.byKey(key), matching: find.byType(Platzhalter));

  /// Die Faktoren der Füllungen im Balken.
  List<double> fuellungen(WidgetTester tester) => [
    for (final f in tester.widgetList<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(zielKey),
        matching: find.byType(FractionallySizedBox),
      ),
    ))
      f.widthFactor ?? 1,
  ];

  /// Farben werden über ihren ARGB-Wert verglichen: Eine aufgelöste
  /// `CupertinoDynamicColor` ist nicht `==` zur gleichfarbigen `Color`.
  int argb(Color c) => c.toARGB32();
  final warn = {argb(Palette.warn.color), argb(Palette.warn.darkColor)};

  /// Die Farben aller Flächen unter [unter], als ARGB-Werte.
  List<int> flaechenFarben(WidgetTester tester, Finder unter) => [
    for (final c in tester.widgetList<Container>(
      find.descendant(of: unter, matching: find.byType(Container)),
    )) ...[
      if (c.color != null) argb(c.color!),
      if (c.decoration case BoxDecoration(color: final Color farbe))
        argb(farbe),
    ],
  ];

  /// Vorbedingung am Tag: gelesen, nichts lädt.
  void tagGelesen(Huelle h, {required bool aufteilung}) {
    final tag = h.container.read(ernaehrungsTagProvider(heute));
    expect(tag.mahlzeitenLaedt, isFalse, reason: 'Vorbedingung: gelesen');
    expect(
      tag.aufteilung != null,
      aufteilung,
      reason: 'Vorbedingung: Aufteilung ${aufteilung ? '' : 'nicht '}da',
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // Raster
  // ═════════════════════════════════════════════════════════════════════

  group('Raster (Entscheidung 11)', () {
    testWidgets('vier Zahlen: kcal, Kohlenhydrate, Eiweiß, Fett', (
      tester,
    ) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(find.byKey(rasterKey), findsOneWidget);
      expect(textUnter(tester, feld('kcal')), contains('426'));
      expect(textUnter(tester, feld('kohlenhydrate')), contains('69,4'));
      expect(textUnter(tester, feld('eiweiss')), contains('6,7'));
      expect(textUnter(tester, feld('fett')), contains('8,6'));
      for (final f in felder) {
        expect(
          textUnter(tester, feld(f)),
          isNot(contains(ohneWert)),
          reason: f,
        );
      }
    });

    testWidgets('fehlt ein Wert, steht dort „–/–" — die anderen bleiben', (
      tester,
    ) async {
      final h = await harness(
        aufteilung: startwert,
        eigene: [
          eintrag(name: 'Prüfbrei', kcal: 300, kohlenhydrateG: 50, eiweissG: 4),
          eintrag(
            name: 'Prüfobst',
            stundeUtc: 7,
            kcal: 126,
            kohlenhydrateG: 19.4,
            eiweissG: 2.7,
          ),
        ],
      );
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(textUnter(tester, feld('fett')), contains(ohneWert));
      expect(
        textUnter(tester, feld('fett')),
        isNot(contains(RegExp(r'\d'))),
        reason: 'Was niemand deklariert hat, ist kein 0 g (#232).',
      );
      expect(textUnter(tester, feld('kcal')), contains('426'));
      expect(textUnter(tester, feld('eiweiss')), contains('6,7'));
    });

    testWidgets('die leere Mahlzeit: vier „–/–", nie „0"', (tester) async {
      final h = await harness(aufteilung: startwert);
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      for (final f in felder) {
        final text = textUnter(tester, feld(f));
        expect(text, contains(ohneWert), reason: f);
        expect(
          text,
          isNot(contains(RegExp(r'\d'))),
          reason: '$f: Eine 0 behauptete „nichts gegessen" (Entscheidung 7).',
        );
      }
    });

    testWidgets('beim Laden vier graue Formen, kein „–/–" und keine 0', (
      tester,
    ) async {
      final h = await harness(aufteilung: startwert, eigeneLaufen: true);
      await zeige(tester, h.app);

      for (final f in felder) {
        expect(platzhalterUnter(feld(f)), findsAtLeastNWidgets(1), reason: f);
        final text = textUnter(tester, feld(f));
        expect(text, isNot(contains(ohneWert)), reason: f);
        expect(text, isNot(contains(RegExp(r'\d'))), reason: f);
      }
    });

    testWidgets('mit Werten steht keine graue Form im Raster', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);

      expect(find.byKey(rasterKey), findsOneWidget);
      expect(platzhalterUnter(rasterKey), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Balken
  // ═════════════════════════════════════════════════════════════════════

  group('Balken gegen das Mahlzeitenziel', () {
    testWidgets('„426 / 450 kcal", zum Teil gefüllt', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(find.byKey(zielKey), findsOneWidget);
      expect(textUnter(tester, zielKey), contains('426 / 450 kcal'));
      final f = fuellungen(tester);
      expect(f, isNotEmpty);
      expect(f.reduce((a, b) => a > b ? a : b), closeTo(426 / 450, 0.01));
    });

    testWidgets('über dem Ziel voll und nicht in Palette.warn (V18)', (
      tester,
    ) async {
      final h = await harness(
        aufteilung: startwert,
        eigene: [eintrag(name: 'Prüfteller', kcal: 600)],
      );
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(textUnter(tester, zielKey), contains('600 / 450 kcal'));
      final f = fuellungen(tester);
      expect(f, isNotEmpty);
      expect(
        f.reduce((a, b) => a > b ? a : b),
        1,
        reason: 'voll, nicht weiter über die Karte hinaus',
      );
      for (final farbe in flaechenFarben(tester, find.byKey(zielKey))) {
        expect(
          warn,
          isNot(contains(farbe)),
          reason:
              'Über dem eigenen Anteil zu liegen ist bei einer Mahlzeit kein '
              'Fehler (Entscheidung 4).',
        );
      }
    });

    testWidgets('ohne Eintrag „– / 180 kcal" und leer (Entscheidung 7)', (
      tester,
    ) async {
      final h = await harness(mahlzeit: Mahlzeit.snack, aufteilung: startwert);
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      final text = textUnter(tester, zielKey);
      expect(text, contains('– / 180 kcal'));
      expect(text, isNot(contains('0 / 180')));
      for (final f in fuellungen(tester)) {
        expect(f, 0, reason: 'nichts gegessen, nichts gefüllt');
      }
    });

    testWidgets('ohne Aufteilung leer mit „–/–" (Entscheidung 1)', (
      tester,
    ) async {
      final h = await harness(eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: false);

      final text = textUnter(tester, zielKey);
      expect(text, contains(ohneWert));
      expect(text, isNot(contains('450')), reason: 'kein Startwert als Ziel');
      expect(text, isNot(contains('426')));
      for (final f in fuellungen(tester)) {
        expect(f, 0);
      }
    });

    testWidgets('ohne Tagesziel, mit Aufteilung: leer mit „–/–"', (
      tester,
    ) async {
      final h = await harness(
        mitTagesziel: false,
        aufteilung: startwert,
        eigene: fruehstueck426(),
      );
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);
      expect(
        h.container.read(ernaehrungsTagProvider(heute)).zielKcal,
        isNull,
        reason: 'Vorbedingung: kein Tagesziel',
      );

      expect(textUnter(tester, zielKey), contains(ohneWert));
      for (final f in fuellungen(tester)) {
        expect(f, 0);
      }
    });

    testWidgets('bei 0 % leer mit „–/–" (V4)', (tester) async {
      final h = await harness(
        mahlzeit: Mahlzeit.snack,
        aufteilung: ohneSnack,
        eigene: [
          eintrag(name: 'Prüfriegel', mahlzeit: Mahlzeit.snack, kcal: 120),
        ],
      );
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      final text = textUnter(tester, zielKey);
      expect(text, contains(ohneWert));
      expect(text, isNot(contains('/ 0')));
      for (final f in fuellungen(tester)) {
        expect(f, 0);
      }
    });

    testWidgets('beim Laden eine graue Form, kein „–/–"', (tester) async {
      final h = await harness(aufteilung: startwert, eigeneLaufen: true);
      await zeige(tester, h.app);

      expect(platzhalterUnter(zielKey), findsAtLeastNWidgets(1));
      expect(textUnter(tester, zielKey), isNot(contains(ohneWert)));
    });

    testWidgets('solange die Aufteilungen laden: graue Form statt „–/–"', (
      tester,
    ) async {
      final h = await harness(
        aufteilung: startwert,
        eigene: fruehstueck426(),
        aufteilungenLaufen: true,
      );
      await zeige(tester, h.app);
      expect(
        h.container.read(ernaehrungsTagProvider(heute)).mahlzeitenLaedt,
        isTrue,
        reason: 'Vorbedingung: die Aufteilungen sind nicht gelesen',
      );

      expect(platzhalterUnter(zielKey), findsAtLeastNWidgets(1));
      expect(
        textUnter(tester, zielKey),
        isNot(contains(ohneWert)),
        reason: '`–/–` hieße „gelesen, kein Ziel" — gelesen hat noch niemand.',
      );
      expect(
        textUnter(tester, feld('kcal')),
        contains('426'),
        reason: 'Das Raster hängt nicht an der Aufteilung.',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Satz (V19, V4)
  // ═════════════════════════════════════════════════════════════════════

  group('Der Satz unter dem Balken (V19)', () {
    testWidgets('mit Aufteilung und Tagesziel', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(
        textUnter(tester, satzKey),
        contains('25 % deines Tagesziels von 1.800 kcal — so eingestellt'),
      );
    });

    testWidgets('ohne Tagesziel', (tester) async {
      final h = await harness(
        mitTagesziel: false,
        aufteilung: startwert,
        eigene: fruehstueck426(),
      );
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      expect(
        textUnter(tester, satzKey),
        contains('25 % deines Tagesziels — es gibt noch kein Kalorienziel'),
      );
    });

    testWidgets('ohne Aufteilung: der Weg zur Einstellung', (tester) async {
      final h = await harness(eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: false);

      expect(
        textUnter(tester, satzKey),
        contains('Aufteilung des Tagesziels festlegen'),
      );
      expect(textUnter(tester, satzKey), isNot(contains('%')));
    });

    testWidgets('ohne Aufteilung öffnet ein Tipp `aufteilung`, auf dem '
        'Stapel des Tabs, in dem man ist', (tester) async {
      final h = await harness(eigene: fruehstueck426());
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: false);
      expect(h.router.nimmBefehl(), isNull, reason: 'Vorbedingung');

      await tester.tap(find.byKey(satzKey));
      await tester.pumpAndSettle();

      final befehl = h.router.nimmBefehl();
      expect(befehl, isNotNull, reason: 'der Tipp öffnet etwas');
      expect(
        befehl!.ersetztStapel,
        isFalse,
        reason: 'AppTarget.aktuell — kein Tab-Wechsel (CLAUDE.md)',
      );
      expect(
        befehl.builder(tester.element(find.byType(MahlzeitView))),
        isA<AufteilungSeite>(),
      );
    });

    testWidgets('bei 0 %: „0 % deines Tagesziels — so eingestellt" (V4)', (
      tester,
    ) async {
      final h = await harness(mahlzeit: Mahlzeit.snack, aufteilung: ohneSnack);
      await zeige(tester, h.app);
      tagGelesen(h, aufteilung: true);

      final satz = textUnter(tester, satzKey);
      expect(
        satz,
        contains(RegExp(r'(^|\D)0 % deines Tagesziels — so eingestellt')),
      );
      expect(satz, isNot(contains('festlegen')));
    });

    testWidgets('solange die Aufteilungen laden, steht nirgends „festlegen" '
        'und kein Prozent (`01`)', (tester) async {
      final h = await harness(
        aufteilung: startwert,
        eigene: fruehstueck426(),
        aufteilungenLaufen: true,
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, isNot(contains('festlegen')));
      expect(texte, isNot(contains('deines tagesziels')));
    });

    testWidgets('solange die Einträge laden, steht nirgends „festlegen"', (
      tester,
    ) async {
      final h = await harness(eigeneLaufen: true);
      await zeige(tester, h.app);

      expect(alleTexte(tester), isNot(contains('festlegen')));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Alle Nährwerte (V17)
  // ═════════════════════════════════════════════════════════════════════

  group('„Alle Nährwerte" (V17)', () {
    Future<void> klappeAuf(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('mahlzeit-werte-kopf')));
      await tester.pumpAndSettle();
    }

    testWidgets('ist zugeklappt', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-werte')), findsOneWidget);
      expect(find.byKey(const Key('mahlzeit-werte-kopf')), findsOneWidget);
      expect(find.byKey(const Key('mahlzeit-werte-tabelle')), findsNothing);
      for (final key in naehrwertZeilen) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }
    });

    testWidgets('aufgeklappt stehen die sechs Zeilen mit ihren Schlüsseln', (
      tester,
    ) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      expect(find.byKey(const Key('mahlzeit-werte-tabelle')), findsOneWidget);
      for (final key in naehrwertZeilen) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(
        textUnter(tester, const Key('mahlzeit-wert-eiweiss')),
        contains('6,7'),
      );
      expect(
        textUnter(tester, const Key('mahlzeit-wert-zucker')),
        contains(ohneWert),
      );
    });

    testWidgets('die Kalorienzeile gibt es nicht mehr — die kcal stehen im '
        'Raster', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      expect(find.byKey(const Key('mahlzeit-werte-kcal')), findsNothing);
    });

    testWidgets('Raster und Balken stehen über „Alle Nährwerte", die Liste '
        'darunter', (tester) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      await zeige(tester, h.app);

      double oben(Key k) => tester.getTopLeft(find.byKey(k)).dy;
      expect(oben(rasterKey), lessThan(oben(zielKey)));
      expect(oben(zielKey), lessThan(oben(const Key('mahlzeit-werte'))));
      expect(oben(const Key('mahlzeit-werte')), lessThan(oben(listeKey)));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Eine Form
  // ═════════════════════════════════════════════════════════════════════

  group('Gleiche Form in Werte, leer, ohne Ziel und Laden', () {
    testWidgets('Raster, Felder und Balken behalten ihre Größe, die Liste '
        'ihre Stelle', (tester) async {
      Future<Map<String, Object>> vermesse(Huelle h) async {
        await zeige(tester, h.app);
        return {
          'raster': tester.getSize(find.byKey(rasterKey)),
          for (final f in felder)
            'feld $f': tester.getSize(find.byKey(feld(f))),
          'balken': tester.getSize(find.byKey(zielKey)),
          'liste oben': tester.getTopLeft(find.byKey(listeKey)).dy,
        };
      }

      final werte = await vermesse(
        await harness(aufteilung: startwert, eigene: fruehstueck426()),
      );
      final leer = await vermesse(await harness(aufteilung: startwert));
      final ohneZiel = await vermesse(await harness(eigene: fruehstueck426()));
      final laden = await vermesse(
        await harness(aufteilung: startwert, eigeneLaufen: true),
      );

      for (final (name, fall) in [
        ('leer', leer),
        ('ohne Ziel', ohneZiel),
        ('Laden', laden),
      ]) {
        for (final k in werte.keys) {
          expect(
            fall[k],
            werte[k],
            reason:
                '$name: $k weicht von „Werte da" ab. Eine Anzeige, die es '
                'gibt, hat genau eine Form (CLAUDE.md).',
          );
        }
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Zurück und wieder hin (`32`)
  // ═════════════════════════════════════════════════════════════════════

  group('Zurück und wieder hin (`32`)', () {
    testWidgets('Raster und Balken stehen sofort wieder da, ohne graue Form', (
      tester,
    ) async {
      final h = await harness(aufteilung: startwert, eigene: fruehstueck426());
      const oeffnen = Key('test-oeffnen');
      await grosseFlaeche(tester);
      await tester.pumpWidget(
        BehaelterImBaum(
          container: h.container,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    key: oeffnen,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => MahlzeitSeite(
                          tagesSchluessel: heute,
                          mahlzeit: Mahlzeit.fruehstueck,
                          router: h.router,
                        ),
                      ),
                    ),
                    child: const Text('Öffnen'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(oeffnen));
      await tester.pumpAndSettle();
      expect(textUnter(tester, feld('kcal')), contains('426'));
      expect(textUnter(tester, zielKey), contains('426 / 450 kcal'));

      Navigator.of(tester.element(find.byType(MahlzeitView))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MahlzeitView), findsNothing);

      await tester.tap(find.byKey(oeffnen));
      await tester.pump();

      // **Im ersten Bild liegt die neue Seite noch offstage** — der
      // `HeroController` baut sie dort, um die Heroes zu vermessen
      // (`flutter/lib/src/widgets/heroes.dart`). `find.byKey` überspringt
      // Offstage-Widgets und sähe nichts; ein `findsNothing` auf die graue
      // Form wäre dann wertlos. Darum hier ausdrücklich mit
      // `skipOffstage: false`: Schon das erste gebaute Bild trägt die Werte.
      // Nachgezogen vom Test-Agenten (#442), nicht von Tim.
      String textImBild(Key key) => normal(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(key, skipOffstage: false),
                matching: find.byType(Text, skipOffstage: false),
              ),
            )
            .map(textOf)
            .join(' '),
      );
      Finder formImBild(Key key) => find.descendant(
        of: find.byKey(key, skipOffstage: false),
        matching: find.byType(Platzhalter, skipOffstage: false),
      );

      expect(find.byKey(rasterKey, skipOffstage: false), findsOneWidget);
      expect(
        textImBild(feld('kcal')),
        contains('426'),
        reason: 'im ersten Bild nach dem Öffnen, nicht erst nach einem Lauf',
      );
      expect(textImBild(zielKey), contains('426 / 450 kcal'));
      expect(formImBild(rasterKey), findsNothing);
      expect(formImBild(zielKey), findsNothing);

      // Das erste **sichtbare** Bild: dieselben Werte, keine graue Form.
      await tester.pump();
      expect(find.byKey(rasterKey), findsOneWidget);
      expect(textUnter(tester, feld('kcal')), contains('426'));
      expect(textUnter(tester, zielKey), contains('426 / 450 kcal'));
      expect(platzhalterUnter(rasterKey), findsNothing);
      expect(platzhalterUnter(zielKey), findsNothing);

      await tester.pumpAndSettle();
      expect(textUnter(tester, zielKey), contains('426 / 450 kcal'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Der Schalter am Baustein (V18)
  // ═════════════════════════════════════════════════════════════════════

  group('MakroBalken: über Ziel nicht umfärben (V18)', () {
    testWidgets('mit dem Schalter bleibt der Balken über dem Ziel in seiner '
        'Farbe', (tester) async {
      await tester.pumpWidget(
        huelle(
          const MakroBalken(
            label: 'Prüfziel',
            wert: 600,
            ziel: 450,
            einheit: 'kcal',
            farbe: Palette.river,
            ueberZielUmfaerben: false,
          ),
        ),
      );

      final farben = flaechenFarben(tester, find.byType(MakroBalken));
      expect(farben, isNotEmpty);
      for (final farbe in farben) {
        expect(warn, isNot(contains(farbe)));
      }
      expect(farben, contains(argb(Palette.river.color)));
    });

    testWidgets('ohne den Schalter färbt er sich um wie bisher', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const MakroBalken(
            label: 'Prüfziel',
            wert: 600,
            ziel: 450,
            einheit: 'kcal',
            farbe: Palette.river,
          ),
        ),
      );

      expect(
        flaechenFarben(tester, find.byType(MakroBalken)),
        contains(argb(Palette.warn.color)),
      );
    });
  });
}

/// Was die Testhülle zurückgibt.
typedef Huelle = ({ProviderContainer container, AppRouter router, Widget app});

/// Steuerbare Ableger der echten Notifier — Riverpods Provider-Typen sind
/// invariant, ein eigenständiger `AsyncNotifier` erfüllt die
/// `overrideWith`-Signatur nicht (siehe `ernaehrung_provider_test.dart`).
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

/// Eine Attrappe, die nie antwortet: Die Aufteilungen bleiben „noch nicht
/// gelesen".
class _NieAufteilungen extends MahlzeitAufteilungenNotifier {
  @override
  Future<List<AufteilungAb>> build() => Completer<List<AufteilungAb>>().future;
}

/// Eine Attrappe, die nie antwortet: Die eigenen Einträge bleiben „noch
/// nicht gelesen".
class _NieEintraege extends EigeneEintraegeNotifier {
  _NieEintraege(super.tagesSchluessel);

  @override
  Future<List<Eintrag>> build() => Completer<List<Eintrag>>().future;
}
