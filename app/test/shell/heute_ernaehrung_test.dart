// Home bekommt die Ernährung (#358, unter #73): Kalorien- und Eiweißring,
// offene und erledigte Mahlzeiten. Die Makros standen hier bis #376.
//
// **Tims Entscheidung vom 05.11.2026** (Issue #376): „Makros auf Home
// entfernen — der Ring oben gibt genug Infos." Und: „Der Hinweis zu
// Trainingseinheiten (‚noch nicht angebunden') kommt weg — sieht hässlich
// aus, Tim weiß es." Die Fälle, die Makro-Karte und Einheiten-Hinweis
// festschrieben, sind deshalb umgestellt, nicht ergänzt: Ein Test, der
// eine überholte Entscheidung verteidigt, ist schlimmer als keiner.
// Dazu: „Alle Karten auf Home bekommen die Ränder wie die Erholung-Karte"
// — geprüft wird nicht der Rand selbst (kein Pixeltest), sondern dass die
// Karten den gemeinsamen Baustein `KachelKarte` tragen.
//
// **Tims Auftrag vom 04.11.2026** (Issue #358): „Auf Home die Ernährung
// einbauen, damit das Thema erledigt ist." Bis dahin standen dort drei
// Hinweise — Ringe, Mahlzeiten, Makros seien „noch nicht angebunden".
// Gebaut wird nach dem Entwurf `docs/screens/screens/heute-kombi.js`
// (Zustände „Kopf: Ringe", „Keine Werte", „Teils Werte", „Lädt", „Über dem
// Budget") mit den Bausteinen aus `docs/screens/components.js`.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden. Scheitert ein
// Fall und hält der Implementierende ihn für falsch: melden, nicht
// korrigieren.
//
// ## Festgelegte API
//
// `HeuteView` (`lib/shell/heute_view.dart`) behält ihren Konstruktor
// `const HeuteView({super.key, AppRouter? router})`. Neu sind diese
// Schlüssel; jeder sitzt auf der Zeile bzw. dem Abschnitt **oder einem
// Vorfahren seiner Texte**, nie auf einem einzelnen `Text`:
//
// **Seit #501 (13.11.2026) gibt es auf Home keine Mahlzeitenlisten
// mehr** — Tim: „Erledigt kann weg, heute noch offen auch." Damit sind
// `Key('heute-offen-mahlzeit-…')`, `Key('heute-erledigt-mahlzeiten')`,
// `Key('heute-offen-leer')` und `Key('heute-erledigt-leer')`
// verschwunden, und mit ihnen die Fälle, die sie prüften. Was auf Home
// von der Ernährung bleibt, sind die beiden Ringe. Die Mahlzeiten stehen
// auf dem Ernährungs-Tab und werden dort geprüft
// (`ernaehrung_view_test.dart`). Dass sie auf Home nicht mehr auftauchen,
// bewacht `heute_umbau_test.dart`.
//
// **Seit #376 gibt es nicht mehr:** `Key('heute-makros')`, die drei
// `Key('heute-makro-…')`, `Key('heute-offen-hinweis')` und
// `Key('heute-erledigt-hinweis')`. Schon seit #358 nicht mehr:
// `Key('heute-ernaehrung-hinweis')` und `Key('heute-makros-hinweis')`.
//
// **Der gemeinsame Kartenbaustein (#376):** `KachelKarte` in
// `lib/design/kachel_karte.dart`, `const KachelKarte({super.key,
// required Widget child})`. Ringblock, offene und erledigte Mahlzeiten,
// der Grund „kein Kalorienziel" und die Erholungskarte sitzen darin; eine
// `InsetCard` kommt auf Home nicht mehr vor.
//
// **Die Quelle ist `ernaehrungsTagProvider(<heutiger Tagesschlüssel>)`**,
// derselbe gerechnete Tag wie auf dem Ernährungs-Tab. Die Fälle lesen ihre
// Erwartungswerte daraus (`gezeigterTag`), statt die Zielformel ein zweites
// Mal hinzuschreiben. Zwei Rechnungen an zwei Stellen gäben zwei
// verschiedene Kalorienziele.
//
// ## Wie die Ringe hier gelesen werden
//
// Über die drei `RingZiel` in `Ringe` (`lib/design/ringe.dart`), gefunden
// über ihr `label` — „Kalorien", „Eiweiß", „Training", wörtlich aus
// `RINGE` im Entwurf. `wert == null` heißt „kein Wert", `platzhalter`
// gesetzt heißt „wird geladen"; genau so zeichnet `RingLegende` sie. Der
// Eiweißring läuft gegen `makroziele.eiweissMinG` — dasselbe Ziel wie der
// Eiweißring auf dem Ernährungs-Tab.
//
// ## Abweichungen vom Auftrag, nach Entwurf entschieden
//
// - **Die offene Mahlzeit führt in die Kamera, nicht auf den
//   Mahlzeiten-Schirm.** Der Auftrag nannte „Ernährung oder Mahlzeit"; der
//   Entwurf zeichnet die Zeile „Abendessen" mit `value: '+'` und `opens:
//   'erfassen'`. Erfassen ist seit #324 die Kamera (`erfassen.js`:
//   „Der (+) öffnet direkt die Kamera"), und `oeffneKamera` kennt die
//   vorgewählte Mahlzeit schon (#344). Die Tür nach *Ernährung* war bis
//   #376 der Verweis „Ernährung ›" über den Makros; mit ihnen ist er weg.
// - **Die gegessenen Mahlzeiten stehen unter „Erledigt"**, nicht unter
//   „Heute noch offen" — so zeichnet es der Entwurf (`ERLEDIGT`), und der
//   Auftrag verweist auf ihn. Die Zeile ist im Entwurf keine Tür.
//
// ## Eigene Festlegungen — nicht von Tim freigegeben
//
// - **Welche Mahlzeit „offen" ist, legt diese Datei nicht fest.** Der
//   Entwurf zeigt abends genau eine, „Abendessen", nachdem Frühstück,
//   Mittag und Snack gegessen sind. Ob „offen" heißt „noch ohne Eintrag"
//   oder „ohne Eintrag und ihr Zeitfenster ist nicht vorbei", ist nirgends
//   entschieden. Die Fälle wählen Uhrzeit und Einträge so, dass beide
//   Lesarten dasselbe ergeben — abends ist nur das Abendessen leer, morgens
//   um halb neun ist das Frühstück offen.
// - **Der Grund für „kein Ziel" muss das Wort „Ziel" enthalten** und darf
//   nur in diesem Zustand dastehen — nicht in der Legende, nicht während
//   des Ladens. Wortlaut und Ort sind frei.
// - **Home stößt den Stammdaten-Lauf an**, wie der Ernährungs-Tab
//   (Tims Befund vom 04.11.2026, Kopf von `ernaehrung_view_test.dart`).
//   Sonst steht der Kalorienring nach einer Neuinstallation so lange auf
//   „kein Ziel", bis jemand den Ernährungs-Tab öffnet.
// - **„Nichts mehr offen" ist so hoch wie eine offene Mahlzeit** (#376,
//   gemessen gegeneinander, nicht gegen eine Zahl): Der Auftrag zu #376
//   schließt eine leere Überschrift aus — das ist die Festlegung des
//   Auftrags, nicht Tims Wortlaut —, und eine Zeile anderer Höhe ließe
//   alles darunter rutschen, sobald die letzte Mahlzeit eingetragen ist.
//   Ihr Wortlaut ist frei —
//   nur von Einheiten darf sie nicht sprechen: Über die weiß Home nichts,
//   solange Gym nicht angebunden ist, und „weder Mahlzeiten noch
//   Einheiten" behauptete etwas, das niemand nachgesehen hat.
//
// ## Was hier nicht geprüft wird
//
// Wortlaut, Farben, Abstände, Symbole. Zahlen werden **als Zahl** gelesen
// (`zahlenIn`), nicht als Satz: „noch 540 kcal" und „540 kcal offen" sind
// beide richtig. Wo ein Wort einen Zustand trägt („noch", „darüber"),
// steht es im Entwurf wörtlich so.
//
// Der Banner bei laufender Erfassung (`laufend` im Entwurf) ist nicht
// Gegenstand: Eine laufende Erfassung gibt es im Neubau noch nicht.
//
// ## Zahlen in dieser Datei
//
// Erfunden und erkennbar künstlich — runde Hunderter, keine Werte aus dem
// Entwurf (`CLAUDE.md`: keine echten Gesundheitsdaten, auch nicht in
// Tests).
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/inset_card.dart';
import 'package:repit/design/kachel_karte.dart';
import 'package:repit/design/makro_balken.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/ernaehrung/ernaehrung_abschnitte.dart'
    show ErnaehrungZielFehlt;
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

void main() {
  // Dienstag, 14.07.2026, Berliner Sommerzeit (+2).
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  /// 08:30 Berlin — Frühstückszeit.
  final morgens = DateTime.utc(2026, 7, 14, 6, 30);

  /// 18:30 Berlin — Frühstück, Mittag und Snack sind vorbei, das
  /// Abendessen hat begonnen. Der Moment, den der Entwurf zeichnet.
  final abends = DateTime.utc(2026, 7, 14, 16, 30);

  /// 22:00 Berlin — auch das Abendessen ist gegessen.
  final spaet = DateTime.utc(2026, 7, 14, 20);

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  /// Ein Tag aus Apple Health mit Gewicht — daraus entstehen Kalorien-,
  /// Eiweiß-, Fett- und Kohlenhydratziel. Trainingsminuten erfunden.
  List<DailyMetrics> mitGewicht() => const [
    DailyMetrics(tag: gestern, weightKg: 80, exerciseMinutes: 10),
    DailyMetrics(
      tag: heute,
      activeKcal: 500,
      basalKcal: 1600,
      weightKg: 80,
      exerciseMinutes: 20,
    ),
  ];

  /// Derselbe Tag ohne Gewicht: Kein Ziel lässt sich rechnen.
  List<DailyMetrics> ohneGewicht() => const [
    DailyMetrics(tag: gestern, exerciseMinutes: 10),
    DailyMetrics(tag: heute, exerciseMinutes: 20),
  ];

  /// Die Uhrzeit, zu der eine Mahlzeit gebucht wird — in ihrem eigenen
  /// Fenster (`Mahlzeitfenster`), und vor [abends], außer dem Abendessen.
  DateTime zeitpunktFuer(Mahlzeit mahlzeit, {String tag = heute}) {
    final tagNr = tag == heute ? 14 : 13;
    return switch (mahlzeit) {
      Mahlzeit.fruehstueck => DateTime.utc(2026, 7, tagNr, 6),
      Mahlzeit.mittag => DateTime.utc(2026, 7, tagNr, 10, 30),
      Mahlzeit.snack => DateTime.utc(2026, 7, tagNr, 14),
      Mahlzeit.abend => DateTime.utc(2026, 7, tagNr, 17, 30),
    };
  }

  Eintrag eintrag(
    Mahlzeit mahlzeit, {
    String tag = heute,
    double kcal = 400,
    double eiweissG = 30,
    double kohlenhydrateG = 50,
    double fettG = 10,
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: zeitpunktFuer(mahlzeit, tag: tag),
    name: 'Testgericht',
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      kohlenhydrateG: kohlenhydrateG,
      fettG: fettG,
    ),
  );

  /// Frühstück, Mittag, Snack — zusammen 1.200 kcal, 80 g Eiweiß, 150 g
  /// Kohlenhydrate, 30 g Fett. Das Abendessen ist offen.
  List<Eintrag> bisZumAbend() => [
    eintrag(Mahlzeit.fruehstueck, kcal: 400, eiweissG: 20, kohlenhydrateG: 50),
    eintrag(Mahlzeit.mittag, kcal: 600, eiweissG: 50, kohlenhydrateG: 70),
    eintrag(Mahlzeit.snack, kcal: 200, eiweissG: 10, kohlenhydrateG: 30),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die Hülle um Home, mit echter Datenbank im Speicher und dem echten
  /// `ernaehrungsTagProvider` darüber. Überschrieben ist nur, was aus
  /// Apple Health kommt, und die Stammdaten.
  ///
  /// [eigeneStammdaten] lässt den `stammdatenProvider` auf der Datenbank
  /// laufen — nur dort ist zu sehen, ob der Stammdaten-Lauf etwas
  /// hinterlässt.
  ({ProviderContainer container, AppCache db, AppRouter router, Widget app})
  harness({
    DateTime? uhr,
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<FremdeMahlzeit>>? fremde,
    Stammdaten stammdaten = vollstaendig,
    bool eigeneStammdaten = false,
    HealthReading? quelle,
  }) {
    final jetzt = uhr ?? abends;
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final router = AppRouter();

    final tage =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(mitGewicht(), stand: jetzt, laeuft: false);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(quelle ?? _StilleQuelle()),
        dailyMetricsProvider.overrideWith(() => _Tageswerte(tage)),
        if (!eigeneStammdaten)
          stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            fremde ?? LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
          ),
        ),
        // Die Erholungskarte ist nicht Gegenstand dieser Datei; dieselben
        // drei Überschreibungen wie in `heute_view_test.dart`.
        sleepProvider.overrideWith(_KeineNaechte.new),
        zieleProvider.overrideWith(_Ziele.new),
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(
            tage is NochNie<List<DailyMetrics>>
                ? const NochNie<Map<String, NightVitals>>()
                : LeerNachLauf<Map<String, NightVitals>>(gelaufen: jetzt),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Hält den gerechneten Tag am Leben, damit `gezeigterTag` die
    // Erwartungswerte aus demselben Stand liest, den Home zeigt — und
    // nicht einen frisch angelegten, noch ladenden.
    container.listen(ernaehrungsTagProvider(heute), (_, _) {});

    return (
      container: container,
      db: db,
      router: router,
      app: BehaelterImBaum(
        container: container,
        child: CupertinoApp(
          home: CupertinoPageScaffold(child: HeuteView(router: router)),
        ),
      ),
    );
  }

  Future<void> zeige(
    WidgetTester tester,
    ({ProviderContainer container, AppCache db, AppRouter router, Widget app})
    h, {
    List<Eintrag> eintraege = const [],
  }) async {
    // Groß genug, dass der ganze Schirm sichtbar ist und kein Fall selbst
    // scrollen muss.
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    if (eintraege.isNotEmpty) {
      await ErnaehrungRepository(h.db).bucheAlle(eintraege);
      // Der Weg, den auch das Buchungsblatt geht: schreiben, dann Bescheid
      // sagen. Nötig, weil `harness()` den gerechneten Tag schon vor dem
      // Buchen am Leben hält — `eigeneEintraegeProvider(heute)` hat dann
      // die leere Tabelle gelesen und liest von selbst nicht neu.
      await h.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();
    }
    await tester.pumpWidget(h.app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  List<RingZiel> ringe(WidgetTester tester) =>
      tester.widget<Ringe>(find.byType(Ringe)).ziele;

  RingZiel ring(WidgetTester tester, String label) =>
      ringe(tester).firstWhere(
        (z) => z.label == label,
        orElse: () => throw TestFailure(
          'Der Ring "$label" fehlt. Eine Anzeige, die es gibt, hat genau '
          'eine Form — sie verschwindet nicht, weil ihr Wert fehlt '
          '(CLAUDE.md)',
        ),
      );

  RingZiel kalorien(WidgetTester tester) => ring(tester, 'Kalorien');
  RingZiel eiweiss(WidgetTester tester) => ring(tester, 'Eiweiß');

  /// Der gerechnete Tag, so wie Home ihn sehen soll.
  ErnaehrungsTag gezeigterTag(ProviderContainer container) =>
      container.read(ernaehrungsTagProvider(heute));

  List<String> alleTexte(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map(textOf).toList();

  /// Die ganzen Zahlen in [text], Tausenderpunkte entfernt — „noch 1.344
  /// kcal" ergibt `[1344]`, „80 / 128 g" ergibt `[80, 128]`.
  List<int> zahlenIn(String text) => RegExp(r'\d+')
      .allMatches(text.replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}(?!\d))'), ''))
      .map((m) => int.parse(m.group(0)!))
      .toList();

  /// Ob [text] eine Zahl trägt, die höchstens um 1 von [erwartet] abweicht
  /// — Rundung ist Sache der Anzeige, nicht dieser Datei.
  bool nenntUngefaehr(String text, double erwartet) =>
      zahlenIn(text).any((z) => (z - erwartet).abs() <= 1);

  /// `true`, wenn ein Vorfahre ein `GestureDetector` mit `onTap` oder ein
  /// `CupertinoButton` mit `onPressed` ist — wörtlich wie in
  /// `ernaehrung_view_test.dart`.
  bool tippbar(Element element) {
    var gefunden = false;
    element.visitAncestorElements((vorfahre) {
      final widget = vorfahre.widget;
      if (widget is GestureDetector && widget.onTap != null) {
        gefunden = true;
        return false;
      }
      if (widget is CupertinoButton && widget.onPressed != null) {
        gefunden = true;
        return false;
      }
      return true;
    });
    return gefunden;
  }

  /// Der Ladezustand: Weder der Health-Lauf (Gewicht, also Ziel) noch die
  /// fremden Mahlzeiten haben geantwortet, eingetragen ist nichts.
  ({ProviderContainer container, AppCache db, AppRouter router, Widget app})
  laedt({Stammdaten stammdaten = vollstaendig}) => harness(
    tageswerte: const NochNie<List<DailyMetrics>>(),
    fremde: const NochNie<List<FremdeMahlzeit>>(),
    stammdaten: stammdaten,
  );

  /// Kein Ziel: weder Stammdaten noch ein Gewicht. Gegessen ist etwas —
  /// der Wert ist also bekannt, nur das Ziel fehlt.
  ({ProviderContainer container, AppCache db, AppRouter router, Widget app})
  ohneZiel() => harness(
    tageswerte: Bekannt<List<DailyMetrics>>(
      ohneGewicht(),
      stand: abends,
      laeuft: false,
    ),
    stammdaten: const Stammdaten(),
  );

  // ───────────────────────────────────────────────────────────────────────

  group('Die Ringe', () {
    testWidgets('Kalorien und Eiweiß kommen zum Trainingsring dazu — drei '
        'Ringe, in der Reihenfolge des Entwurfs', (tester) async {
      final h = harness();
      await zeige(tester, h, eintraege: bisZumAbend());

      expect(
        ringe(tester).map((z) => z.label).toList(),
        ['Kalorien', 'Eiweiß', 'Training'],
        reason:
            '`RINGE` in heute-kombi.js, von außen nach innen. Die '
            'Reihenfolge ist die Zuordnung Ring → Wert, keine Beschriftung',
      );
      expect(
        ring(tester, 'Training').wert,
        20,
        reason: 'der Trainingsring bleibt, wie er war',
      );
    });

    testWidgets('die Beschriftung nennt den Rest, nicht den Stand', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h, eintraege: bisZumAbend());

      final tag = gezeigterTag(h.container);
      final zielKcal = tag.zielKcal;
      final zielEiweiss = tag.makroziele.eiweissMinG;
      expect(zielKcal, isNotNull, reason: 'Vorbedingung: ein Ziel steht');
      expect(zielEiweiss, isNotNull, reason: 'Vorbedingung: ein Ziel steht');
      expect(
        zielKcal!,
        greaterThan(1200),
        reason: 'Vorbedingung: noch nicht über dem Ziel',
      );
      expect(zielEiweiss!, greaterThan(80));

      final k = kalorien(tester);
      expect(k.wert, 1200, reason: 'gegessen: Frühstück, Mittag, Snack');
      expect(k.ziel, closeTo(zielKcal, 1));
      expect(
        k.text,
        contains('noch'),
        reason: '„noch 540 kcal" ist die Zahl, nach der man handelt',
      );
      expect(
        nenntUngefaehr(k.text, zielKcal - 1200),
        isTrue,
        reason: 'der Rest (${zielKcal - 1200}), nicht der Stand: "${k.text}"',
      );
      expect(
        zahlenIn(k.text),
        isNot(contains(1200)),
        reason: '„1.260 von 1.800" muss man erst im Kopf abziehen',
      );

      final e = eiweiss(tester);
      expect(e.wert, 80);
      expect(e.ziel, closeTo(zielEiweiss, 0.5));
      expect(e.text, contains('noch'));
      expect(
        nenntUngefaehr(e.text, zielEiweiss - 80),
        isTrue,
        reason: 'der Rest (${zielEiweiss - 80} g): "${e.text}"',
      );
    });

    testWidgets('über dem Ziel sagt sie, wie weit darüber — und der Ring '
        'läuft weiter', (tester) async {
      final h = harness();
      await zeige(
        tester,
        h,
        eintraege: [
          eintrag(Mahlzeit.fruehstueck, kcal: 2000, eiweissG: 200),
          eintrag(Mahlzeit.mittag, kcal: 2000, eiweissG: 100),
        ],
      );

      final zielKcal = gezeigterTag(h.container).zielKcal!;
      expect(zielKcal, lessThan(4000), reason: 'Vorbedingung');

      final k = kalorien(tester);
      expect(k.wert, 4000);
      expect(
        k.wert! > k.ziel,
        isTrue,
        reason: 'ein gedeckelter Ring sähe bei „Ziel erreicht" und „50 % '
            'darüber" gleich aus (Zustand `ueberschuss`)',
      );
      expect(k.text, contains('darüber'));
      expect(k.text, isNot(contains('noch')));
      expect(nenntUngefaehr(k.text, 4000 - zielKcal), isTrue, reason: k.text);
    });

    testWidgets('ohne Einträge zählt der Tag als 0 gegessen — eigene Daten, '
        'kein Leerstand', (tester) async {
      final h = harness(uhr: morgens);
      await zeige(tester, h);

      final zielKcal = gezeigterTag(h.container).zielKcal!;
      final k = kalorien(tester);
      expect(
        k.wert,
        0,
        reason:
            'Für Tims eigene Daten gibt es keinen Lauf, der leer ausgehen '
            'kann (CLAUDE.md) — „nichts eingetragen" ist eine Aussage, '
            'und die Null ist hier ehrlich',
      );
      expect(k.text, isNot(ohneWert));
      expect(k.text, contains('noch'));
      expect(
        nenntUngefaehr(k.text, zielKcal),
        isTrue,
        reason: 'das volle Tagesbudget ist offen: "${k.text}"',
      );
      expect(eiweiss(tester).wert, 0);
    });

    testWidgets('ohne Ziel steht `–/–` und kein Wert — nicht 0, auch wenn '
        'gegessen wurde', (tester) async {
      final h = ohneZiel();
      await zeige(tester, h, eintraege: bisZumAbend());

      expect(gezeigterTag(h.container).zielKcal, isNull, reason: 'Vorbed.');

      for (final r in [kalorien(tester), eiweiss(tester)]) {
        expect(
          r.wert,
          isNull,
          reason:
              '${r.label}: ein Ring gegen kein Ziel ist ein Ring gegen '
              'nichts — und ein Ring auf 0 behauptete „nichts gegessen"',
        );
        expect(r.text, ohneWert, reason: r.label);
        expect(
          r.platzhalter,
          isNull,
          reason:
              '${r.label}: der Lauf ist fertig, es wird nichts mehr '
              'geladen — ein Platzhalter hier hieße „wird geladen" im '
              'Vorlesetext',
        );
      }
    });

    testWidgets('Teils Werte: Gewicht da, Kalorienziel nicht — Eiweiß '
        'rechnet, Kalorien sagt `–/–`', (tester) async {
      final h = harness(stammdaten: const Stammdaten());
      await zeige(tester, h, eintraege: bisZumAbend());

      final tag = gezeigterTag(h.container);
      expect(tag.zielKcal, isNull, reason: 'Vorbedingung');
      expect(tag.makroziele.eiweissMinG, isNotNull, reason: 'Vorbedingung');

      expect(kalorien(tester).wert, isNull);
      expect(kalorien(tester).text, ohneWert);

      final e = eiweiss(tester);
      expect(e.wert, 80);
      expect(
        nenntUngefaehr(e.text, tag.makroziele.eiweissMinG! - 80),
        isTrue,
        reason:
            'das Eiweißziel hängt am Gewicht, nicht am Kalorienziel — '
            'jede Anzeige fehlt einzeln: "${e.text}"',
      );
    });

    testWidgets('beim Laden stehen Platzhalter in derselben Form', (
      tester,
    ) async {
      final h = laedt();
      await zeige(tester, h);

      expect(
        ringe(tester).map((z) => z.label).toList(),
        ['Kalorien', 'Eiweiß', 'Training'],
        reason: 'auch während des Ladens drei Ringe',
      );
      for (final r in [kalorien(tester), eiweiss(tester)]) {
        expect(r.wert, isNull, reason: r.label);
        expect(
          r.platzhalter,
          isNotNull,
          reason:
              '${r.label}: nur mit gesetztem `platzhalter` zeichnet '
              '`RingLegende` die graue Form statt `–/–`, und nur dann sagt '
              'der Vorlesetext „wird geladen" statt „keine Werte"',
        );
      }
    });

    testWidgets('beim Nachladen bleibt der Wert stehen — der Platzhalter '
        'gehört allein in NochNie', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          mitGewicht(),
          stand: abends,
          laeuft: true,
        ),
        fremde: Bekannt<List<FremdeMahlzeit>>(
          const [],
          stand: abends,
          laeuft: true,
        ),
      );
      await zeige(tester, h, eintraege: bisZumAbend());

      expect(kalorien(tester).wert, 1200);
      expect(eiweiss(tester).wert, 80);
      expect(
        find.descendant(
          of: find.byType(RingLegende),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason: 'ein Platzhalter, der bei jedem Zug aufblitzt, ist genau das '
            'Flackern, gegen das die Regel gebaut ist',
      );
    });
  });

  group('Der Grund für „kein Ziel"', () {
    /// Die Texte, die der Zustand „kein Ziel" **zusätzlich** zeigt und die
    /// vom Ziel sprechen — der Grund, wo immer er steht.
    Future<Set<String>> grundTexte(WidgetTester tester) async {
      final voll = harness();
      await zeige(tester, voll, eintraege: bisZumAbend());
      final normal = alleTexte(tester).toSet();

      await tester.pumpWidget(const SizedBox.shrink());

      final ohne = ohneZiel();
      await zeige(tester, ohne, eintraege: bisZumAbend());
      return alleTexte(tester)
          .where((t) => t.toLowerCase().contains('ziel'))
          .toSet()
          .difference(normal);
    }

    testWidgets('steht da, einmal, und nicht in den Feldern', (tester) async {
      final grund = await grundTexte(tester);

      expect(
        grund,
        isNotEmpty,
        reason:
            'ohne Ziel steht `–/–` MIT dem Grund — sonst ist dem Schirm '
            'nicht anzusehen, warum der Ring leer ist',
      );

      final inDerLegende = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(RingLegende),
              matching: find.byType(Text),
            ),
          )
          .map(textOf)
          .toSet();
      for (final satz in grund) {
        expect(
          inDerLegende.contains(satz),
          isFalse,
          reason:
              'der Grund steht einmal, nicht je Feld — in der schmalen '
              'Legende liefe er über mehrere Zeilen und machte den Kopf '
              'höher, sobald Werte fehlen: "$satz"',
        );
      }
    });

    testWidgets('steht während des Ladens nicht da (docs/todo/01)', (
      tester,
    ) async {
      final grund = await grundTexte(tester);
      expect(grund, isNotEmpty, reason: 'Vorbedingung');

      await tester.pumpWidget(const SizedBox.shrink());

      // Dieselbe Datenlage wie „kein Ziel" — keine Stammdaten —, nur ist
      // der Health-Lauf noch nicht zurück. Entschieden ist noch nichts.
      final h = laedt(stammdaten: const Stammdaten());
      await zeige(tester, h);

      final texte = alleTexte(tester).toSet();
      expect(
        texte.intersection(grund),
        isEmpty,
        reason:
            'während des Ladens steht nie ein „keine Daten"-Grund — '
            'das ist Fehler 01 in neuer Verpackung',
      );
      expect(
        find.descendant(
          of: find.byType(RingLegende),
          matching: find.text(ohneWert),
        ),
        findsNothing,
        reason: '`–/–` heißt „gelesen, kein Wert" — gelesen ist noch nichts',
      );
    });
  });

  /// **„Heute noch offen" und „Erledigt" gibt es auf Home nicht mehr**
  /// (#501, Tim am 13.11.2026: „Erledigt kann weg, heute noch offen
  /// auch"). Die Mahlzeitenlisten und ihre Leerzeilen standen bis dahin
  /// hier; sie leben auf dem Ernährungs-Tab weiter und werden dort
  /// geprüft (`ernaehrung_view_test.dart`). Was auf Home von der
  /// Ernährung bleibt, sind die beiden Ringe — und dass sie nachziehen,
  /// prüfen die beiden Fälle unten.
  group('Die Ringe ziehen nach', () {
    testWidgets('eine neue Buchung zieht auf Home nach', (tester) async {
      final h = harness(uhr: morgens);
      await zeige(tester, h);
      expect(kalorien(tester).wert, 0);

      // Der Weg, den das Buchungsblatt nimmt: schreiben, dann Bescheid
      // sagen (`EigeneEintraegeNotifier.neuLesen`).
      await ErnaehrungRepository(
        h.db,
      ).buche(eintrag(Mahlzeit.fruehstueck, kcal: 400, eiweissG: 20));
      await h.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();
      await tester.pumpAndSettle();

      expect(kalorien(tester).wert, 400);
      expect(eiweiss(tester).wert, 20);
    });

    testWidgets('Home zeigt heute, auch wenn die Ernährung auf gestern '
        'geblättert ist', (tester) async {
      final h = harness();
      await zeige(
        tester,
        h,
        eintraege: [
          eintrag(Mahlzeit.mittag, tag: gestern, kcal: 900, eiweissG: 60),
        ],
      );

      h.container.read(offenerTagProvider.notifier).setze(gestern);
      await tester.pumpAndSettle();

      expect(
        kalorien(tester).wert,
        0,
        reason: 'heute ist nichts gegessen; die 900 kcal sind von gestern',
      );
    });
  });
  group('Keine Makros auf Home (#376)', () {
    // Tim, 05.11.2026: „Makros auf Home entfernen — der Ring oben gibt
    // genug Infos." Die Makros stehen auf dem Ernährungs-Tab; dort prüft
    // sie `ernaehrung_view_test.dart`.
    testWidgets('weder Abschnitt noch Karte noch Balken — in jedem Zustand', (
      tester,
    ) async {
      final zustaende = <String, Future<void> Function()>{
        'mit Werten': () => zeige(tester, harness(), eintraege: bisZumAbend()),
        'ohne Ziel': () => zeige(tester, ohneZiel(), eintraege: bisZumAbend()),
        'beim Laden': () => zeige(tester, laedt()),
      };
      for (final MapEntry(key: name, value: zeigen) in zustaende.entries) {
        await zeigen();
        expect(
          find.byWidgetPredicate(
            (w) => w is SectionHeader && w.title == 'Makros',
          ),
          findsNothing,
          reason: '$name: der Kopf „Makros · Ernährung ›" ist weg',
        );
        expect(
          find.byKey(const Key('heute-makros')),
          findsNothing,
          reason: name,
        );
        for (final schluessel in const [
          Key('heute-makro-eiweiss'),
          Key('heute-makro-kohlenhydrate'),
          Key('heute-makro-fett'),
        ]) {
          expect(
            find.byKey(schluessel),
            findsNothing,
            reason: '$name: $schluessel',
          );
        }
        expect(find.byType(MakroBalken), findsNothing, reason: name);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Karten wie die Erholungskarte (#376)', () {
    // Tim, 05.11.2026: „Alle Karten auf Home bekommen die Ränder wie die
    // Erholung-Karte." Geprüft wird nicht der Rand (kein Pixeltest),
    // sondern dass jede Karte auf Home denselben Baustein trägt — dann
    // gibt es genau eine Stelle, an der sich die Fläche ändern lässt.
    Finder inKarte(Finder kind) =>
        find.ancestor(of: kind, matching: find.byType(KachelKarte));

    /// Ob [baustein] auf einer `KachelKarte` sitzt — sie liegt um ihn
    /// herum oder, bei einem Baustein, der seine Fläche selbst mitbringt
    /// (Erholungskarte, Grund „kein Ziel"), in ihm.
    bool traegtKarte(Finder baustein) =>
        inKarte(baustein).evaluate().isNotEmpty ||
        find
            .descendant(of: baustein, matching: find.byType(KachelKarte))
            .evaluate()
            .isNotEmpty;

    testWidgets('Ringblock und Erholungskarte sitzen auf einer KachelKarte', (
      tester,
    ) async {
      await zeige(tester, harness(), eintraege: bisZumAbend());

      expect(
        inKarte(find.byType(Ringe)),
        findsOneWidget,
        reason: 'der Ringblock ist eine Karte (`.ringhero` im Entwurf)',
      );
      expect(
        traegtKarte(find.byType(ErholungsKarte)),
        isTrue,
        reason:
            'die Erholungskarte gibt den Rand vor und trägt ihn über '
            'denselben Baustein',
      );
    });

    // Die beiden Mahlzeitenkarten und ihre Leerzeilen standen hier mit
    // in der Aufzählung; sie gibt es auf Home seit #501 nicht mehr.
    testWidgets('auch der Grund „kein Ziel"', (tester) async {
      await zeige(tester, ohneZiel(), eintraege: bisZumAbend());
      expect(traegtKarte(find.byType(ErnaehrungZielFehlt)), isTrue);
    });

    testWidgets('auf Home steht keine InsetCard mehr — in jedem Zustand', (
      tester,
    ) async {
      final zustaende = <String, Future<void> Function()>{
        'mit Werten': () => zeige(tester, harness(), eintraege: bisZumAbend()),
        'alles gegessen': () => zeige(
          tester,
          harness(uhr: spaet),
          eintraege: [...bisZumAbend(), eintrag(Mahlzeit.abend, kcal: 500)],
        ),
        'ohne Ziel': () => zeige(tester, ohneZiel(), eintraege: bisZumAbend()),
        'beim Laden': () => zeige(tester, laedt()),
      };
      for (final MapEntry(key: name, value: zeigen) in zustaende.entries) {
        await zeigen();
        expect(
          find.descendant(
            of: find.byType(HeuteView),
            matching: find.byType(InsetCard),
          ),
          findsNothing,
          reason:
              '$name: Home baut seine Karten mit KachelKarte (#376), '
              'nicht mit InsetCard',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Wächter', () {
    testWidgets('die beiden alten Hinweise sind weg — in jedem Zustand', (
      tester,
    ) async {
      final zustaende = <String, Future<void> Function()>{
        'mit Werten': () => zeige(tester, harness(), eintraege: bisZumAbend()),
        'ohne Ziel': () => zeige(tester, ohneZiel(), eintraege: bisZumAbend()),
        'beim Laden': () => zeige(tester, laedt()),
      };
      for (final MapEntry(key: name, value: zeigen) in zustaende.entries) {
        await zeigen();
        expect(
          find.byKey(const Key('heute-ernaehrung-hinweis')),
          findsNothing,
          reason: '$name: „Ernährung ist noch nicht angebunden" stimmt nicht '
              'mehr',
        );
        expect(
          find.byKey(const Key('heute-makros-hinweis')),
          findsNothing,
          reason: '$name: „Makros sind noch nicht angebunden" stimmt nicht '
              'mehr',
        );
        expect(
          find.byKey(const Key('heute-offen-hinweis')),
          findsNothing,
          reason:
              '$name: auch der Hinweis auf die Einheiten ist seit #376 '
              'weg (Tim, 05.11.2026)',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('ein Wert, der dastand, steht nach dem Zurücknavigieren '
        'wieder da (docs/todo/32)', (tester) async {
      final h = harness();
      final gesehen = <Messwert<Naehrwerte>>[];
      h.container.listen(
        ernaehrungsTagProvider(heute),
        (_, next) => gesehen.add(next.gegessen),
        fireImmediately: true,
      );
      await zeige(tester, h, eintraege: bisZumAbend());
      expect(kalorien(tester).wert, 1200);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('woanders')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('woanders'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(kalorien(tester).wert, 1200);
      expect(eiweiss(tester).wert, 80);
      expect(
        find.descendant(
          of: find.byType(RingLegende),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
      );
      // Der Vorlauf vor dem ersten Wert ist bauartbedingt `NochNie` (Kopf
      // von `erholung_view_test.dart`). Ab dem ersten bekannten Wert ist
      // jedes `NochNie` Fehler 32.
      final abErstemWert = gesehen
          .skipWhile((m) => m is NochNie<Naehrwerte>)
          .toList();
      expect(abErstemWert, isNotEmpty, reason: 'Vorbedingung');
      expect(abErstemWert.whereType<NochNie<Naehrwerte>>(), isEmpty);
    });

    testWidgets('Home stößt den Stammdaten-Lauf an — sonst stünde das Ziel '
        'erst nach dem Besuch im Ernährungs-Tab da', (tester) async {
      final quelle = _Merkmalsquelle(
        const BodyCharacteristics(heightCm: 180, birthYear: 1990),
      );
      final h = harness(eigeneStammdaten: true, quelle: quelle);
      await zeige(tester, h);

      expect(
        quelle.anfragen,
        greaterThanOrEqualTo(1),
        reason:
            'ein `FutureProvider`, den niemand anfordert, läuft nie — '
            'Tims Befund vom 04.11.2026 auf dem Ernährungs-Tab',
      );
      expect(gezeigterTag(h.container).zielKcal, isNotNull);
      expect(kalorien(tester).wert, isNotNull);
      expect(kalorien(tester).text, isNot(ohneWert));
    });

    testWidgets('jedes sichtbare Chevron sitzt unter einem tippbaren '
        'Vorfahren', (tester) async {
      final h = harness();
      await zeige(tester, h, eintraege: bisZumAbend());

      final chevrons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
      );
      expect(chevrons, findsWidgets, reason: 'sonst prüft dieser Fall nichts');
      for (final element in chevrons.evaluate()) {
        expect(
          tippbar(element),
          isTrue,
          reason: 'ein Winkel ohne Tür ist genau der Fehler, den '
              '`docs/screens/pruefen.mjs` am Board verhindert',
        );
      }
    });

    testWidgets('baut ohne Ausnahme, in jedem Zustand', (tester) async {
      await zeige(tester, harness(), eintraege: bisZumAbend());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await zeige(tester, ohneZiel());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await zeige(tester, laedt());
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Attrappen
// ─────────────────────────────────────────────────────────────────────────

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

class _KeineNaechte extends SleepNotifier {
  @override
  Future<Messwert<List<SleepNight>>> build() async =>
      LeerNachLauf<List<SleepNight>>(gelaufen: DateTime.utc(2026, 7, 14));
}

class _Ziele extends ZieleNotifier {
  @override
  Future<Ziele> build() async => Ziele.vorbelegung;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}

/// Kann die Zeitraum-Methoden und sonst nichts — der Stammdaten-Lauf geht
/// durch, ohne etwas zu füllen.
class _StilleQuelle extends HealthReadingAttrappe {}

/// Liefert zusätzlich Körpermerkmale und zählt, wie oft danach gefragt
/// wurde (Vorbild: `_Merkmalsquelle` in `ernaehrung_view_test.dart`).
class _Merkmalsquelle extends _StilleQuelle
    implements BodyCharacteristicsReading {
  _Merkmalsquelle(this.merkmale);

  final BodyCharacteristics merkmale;

  int anfragen = 0;

  @override
  Future<BodyCharacteristics> bodyCharacteristics() async {
    anfragen += 1;
    return merkmale;
  }
}
