import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/makro_balken.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;
import '../tag/behaelter_im_baum.dart';

/// Tests für den **Schirm** `mahlzeit` (#300, Task 9 des
/// Ernährungsplans) — `lib/ernaehrung/mahlzeit_view.dart`.
///
/// Der Zustand darunter liegt in `mahlzeit_inhalt_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. Hält der Implementierende einen Fall für falsch, wird das
/// **gemeldet, nicht korrigiert** — die Entscheidung trifft Tim oder der
/// Test-Agent.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/ernaehrung/mahlzeit_view.dart
///
/// /// Der Inhalt des Mahlzeiten-Schirms — Kopf, Werte, Liste, Knopf,
/// /// Fußtext. **Ohne** eigenen `CupertinoPageScaffold`; den stellt
/// /// [MahlzeitSeite] (Hausform: `ErholungSeite`, `SchlafSeite`,
/// /// `VorlaeufigeWerteSeite`).
/// class MahlzeitView extends ConsumerWidget {
///   const MahlzeitView({
///     super.key,
///     required this.tagesSchluessel,
///     required this.mahlzeit,
///   });
///
///   final String tagesSchluessel;
///   final Mahlzeit mahlzeit;
/// }
///
/// /// Der Gastgeber für den Push: Scaffold und Navigationsleiste um
/// /// genau eine [MahlzeitView].
/// class MahlzeitSeite extends StatelessWidget {
///   const MahlzeitSeite({
///     super.key,
///     required this.tagesSchluessel,
///     required this.mahlzeit,
///   });
/// }
/// ```
///
/// ```dart
/// // lib/ernaehrung/mahlzeit_provider.dart
///
/// /// Der Weg von einer eigenen Zeile ins Bearbeiten-Blatt.
/// typedef BearbeitenOeffner =
///     Future<void> Function(BuildContext context, Eintrag eintrag);
///
/// final bearbeitenOeffnerProvider = Provider<BearbeitenOeffner>(…);
/// ```
///
/// ## Die Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt (dieselbe Begründung wie in
/// `ernaehrung_view_test.dart` und `erholung_view_test.dart`):
///
/// - `Key('mahlzeit-kopf')` — Name der Mahlzeit, Datum, Zahl der Einträge
/// - `Key('mahlzeit-raster')` — das 2×2-Raster oben (#442, siehe
///   „Nachgezogen für #442" unten); `Key('mahlzeit-raster-kcal')` ist das
///   Feld mit den Kalorien. **Es trägt die Summe, die bis #442 in der
///   Kalorienzeile stand**, samt Vorlesetext des Zustands.
/// - `Key('mahlzeit-ziel')` — der Balken gegen das Mahlzeitenziel, der
///   einzige Balken auf diesem Schirm
/// - `Key('mahlzeit-werte')` — der Abschnitt „Alle Nährwerte"
/// - `Key('mahlzeit-werte-kopf')` — seine tippbare Kopfzeile; sie klappt
///   die Tabelle auf und zu
/// - `Key('mahlzeit-werte-tabelle')` — die sechs Nährwertzeilen, es gibt
///   sie **nur aufgeklappt**
/// - `Key('mahlzeit-wert-eiweiss' | '-kohlenhydrate' | '-zucker' |
///   '-fett' | '-gesaettigt' | '-ballaststoffe')` — die sechs Zeilen
///   einzeln, in dieser Reihenfolge (`mahlzeit.js`, `ZEILEN`)
/// - `Key('mahlzeit-liste')` — der Abschnitt „Eingetragen"
/// - `Key('mahlzeit-eintrag-<id>')` — eine **eigene** Zeile, `<id>` ist
///   `Eintrag.id`
/// - `Key('mahlzeit-fremd-<i>')` — eine **fremde** Zeile, `<i>` ihr Platz
///   in `MahlzeitInhalt.fremde` (eine fremde Probe trägt hier keine
///   eigene Kennung)
/// - `Key('mahlzeit-leer')` — „Noch nichts eingetragen", **nur** im
///   Zustand `leer` und **nie** während des Laufs
/// - `Key('mahlzeit-nur-health')` — der Hinweis, **nur** wenn alles aus
///   einer anderen App kommt
/// - `Key('mahlzeit-hinzufuegen')` — der Knopf unten
/// - `Key('mahlzeit-fuss')` — der Hinweisfuß zu den fremden Zeilen
/// - `Key('mahlzeit-rueckgaengig')` — die Rückgängig-Anzeige, **nur**
///   nach einem Löschen
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht
/// Layout und Beschriftung. Kein Fall schreibt eine Knopfbeschriftung
/// fest. Wo ein Text einen *Zustand* trägt, wird der Zustand geprüft —
/// `–/–` gegen `0` ist der Unterschied zwischen „nichts eingetragen" und
/// „nichts gegessen", und die Herkunft „Apple Health" an einer Zeile ist
/// die Auskunft, dass diese Zeile nicht änderbar ist.
///
/// **Zwei Geometrie-Zusicherungen gibt es trotzdem**, und sie sind keine
/// Layout-Tests: „Eine Anzeige, die es gibt, hat genau eine Form" ist eine
/// Regel über **Zustände**. Geprüft wird, dass die Liste in allen
/// Zuständen an derselben Stelle beginnt, und dass das Aufklappen der
/// Nährwerte weder das Raster noch die Kopfzeile von „Alle Nährwerte"
/// bewegt (bis #442: die Kalorienzeile). Welche Höhe das ist,
/// prüft niemand.
///
/// **Nicht geprüft, bewusst:**
///
/// - Wohin der Knopf „hinzufügen" führt. Das Erfassen ist Task 7 (#285)
///   und gibt es noch nicht.
/// - Der Weg **auf** diesen Schirm, also die Tür aus der
///   Mahlzeitenzeile des Tagesschirms. Dafür müsste `ErnaehrungView`
///   einen `AppRouter` bekommen, und dessen Bauvertrag
///   (`const ErnaehrungView({super.key})`) ist durch
///   `test/ernaehrung/ernaehrung_view_test.dart` festgelegt — eine
///   Testdatei, die weder der Implementierende noch dieser Test-Agent
///   ändern darf. Der Fall gehört dorthin, nicht hierher.
/// - Farben, Abstände, Schriften und Schriftgrößen.
///
/// ## Entscheidung des Test-Agenten: der Öffner ist ein Provider
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// „Jede eigene Zeile führt ins Bearbeiten-Blatt, kein zweites Formular"
/// ist eine Aussage über das Ziel eines Tipps, und das Blatt gibt es
/// (Task 7, #285) noch nicht. Ohne eine Naht ließe sich nur prüfen, dass
/// *irgendetwas* aufgeht — ein „kommt später"-Dialog bestünde den Fall
/// genauso wie das richtige Blatt.
///
/// [bearbeitenOeffnerProvider] ist diese Naht und zugleich die eine
/// Stelle, an der der Schirm das Blatt öffnet. Die Fälle unten prüfen
/// damit beides: dass eine eigene Zeile **genau ihren** Eintrag
/// weiterreicht, und dass eine fremde Zeile es nicht tut.
///
/// ## Entscheidung des Test-Agenten: Streichen und Rückgängig
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben, und im Entwurf fehlt
/// der Zustand.** `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`
/// sagt „Streichen in der Mahlzeitenzeile löscht direkt, mit Rückgängig"
/// und hält im selben Abschnitt fest: „Drei Zustände, die der Entwurf
/// noch nicht hat, und die dort entstehen, bevor gebaut wird."
/// `mahlzeit.js` zeichnet weder das Streichen noch das Rückgängig.
///
/// Die Fälle unten sind deshalb bewusst **verhaltensnah und formlos**:
/// Sie verlangen, dass ein waagerechter Zug die Zeile wegnimmt und dass
/// es danach einen Weg zurück gibt — nicht, wie dieser Weg aussieht, wo
/// er steht oder wie lange er bleibt. Die Form gehört aufs Entwurfsboard,
/// bevor sie jemand festnagelt.
///
/// ## Nachgezogen für #442 (Schnitt 3 von #385)
///
/// **Vom Test-Agenten mit `TEST_AENDERN=1`, nicht von Tim und nicht vom
/// Implementierenden.** Tims Entscheidung 11 und V17 der Spec
/// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`:
/// Die bisherige Kalorienzeile entfällt, die kcal stehen im Raster, und die
/// sechs Zeilen klappen unter „Alle Nährwerte" auf, samt ihren Schlüsseln.
/// Darunter steht **ein** Balken, kcal gegen das Mahlzeitenziel. Was diese
/// Datei bis dahin festschrieb und jetzt anders prüft:
///
/// - `Key('mahlzeit-werte-kcal')` gibt es nicht mehr. Die Summe wird am
///   Raster gelesen (`mahlzeit-raster-kcal`), aufgeklappt wird über
///   `mahlzeit-werte-kopf`.
/// - „Keine Makro-Ziele je Mahlzeit" verbot jeden `MakroBalken`. Jetzt gibt
///   es höchstens einen, und der steht in `mahlzeit-ziel`.
/// - Die Hülle hängt den Behälter über `BehaelterImBaum` ein statt über
///   `UncontrolledProviderScope`, wie jede Hülle, deren Schirm den
///   laufenden Tag lesen kann (`test/tag/behaelter_im_baum.dart`).
///
/// Raster, Balken, Satz und „Alle Nährwerte" selbst prüft
/// `mahlzeit_raster_test.dart`. Die Hülle hier legt keine Aufteilung ab;
/// der Balken steht in allen Fällen dieser Datei ohne Ziel.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und erkennbar künstlich — runde Fünfziger und Hunderter,
/// keine Werte aus `mahlzeit.js` und keine Werte von Tim (`CLAUDE.md`:
/// keine echten Gesundheitsdaten, auch nicht in Tests).
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) =>
      DailyMetrics(tag: tag, activeKcal: 600, basalKcal: 1600, weightKg: 80);

  /// Ein eigener Eintrag. **Zucker und gesättigte Fette bleiben überall
  /// ohne Angabe** — so hat jeder Fall zwei Nährwertzeilen, die `–/–`
  /// zeigen müssen, und vier, die eine Zahl zeigen.
  Eintrag eintrag({
    required String name,
    Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
    int stundeUtc = 6,
    int minuteUtc = 0,
    double? kcal = 300,
    double? eiweissG = 10,
    double? kohlenhydrateG = 50,
    double? fettG = 6,
    double? ballaststoffeG = 8,
  }) => Eintrag(
    tagesSchluessel: heute,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc, minuteUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      kohlenhydrateG: kohlenhydrateG,
      fettG: fettG,
      ballaststoffeG: ballaststoffeG,
    ),
  );

  FremdeMahlzeit fremdeMahlzeit({
    required String name,
    int stundeUtc = 6,
    int minuteUtc = 30,
    double? kcal = 150,
  }) => FremdeMahlzeit(
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc, minuteUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: 5,
      kohlenhydrateG: 20,
      fettG: 2,
      ballaststoffeG: 1,
    ),
  );

  /// Der Zustand `voll` aus dem Entwurf: drei eigene Einträge und eine
  /// fremde Zeile. Zusammen 300 + 200 + 100 + 150 = 750 kcal.
  List<Eintrag> dreiEigene() => [
    eintrag(name: 'Testbrei', stundeUtc: 6, kcal: 300),
    eintrag(name: 'Testquark', stundeUtc: 7, kcal: 200),
    eintrag(name: 'Testobst', stundeUtc: 8, kcal: 100),
  ];

  Messwert<List<FremdeMahlzeit>> eineFremde() => Bekannt<List<FremdeMahlzeit>>(
    [fremdeMahlzeit(name: 'Fremdgericht')],
    stand: jetzt,
    laeuft: false,
  );

  Messwert<List<FremdeMahlzeit>> keineFremde() =>
      Bekannt<List<FremdeMahlzeit>>(const [], stand: jetzt, laeuft: false);

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die Hülle um den Schirm.
  ///
  /// Die eigenen Einträge gehen durch das **echte** Repository auf einer
  /// Datenbank im Speicher — Löschen und Rückgängig sollen denselben Weg
  /// nehmen wie in der App.
  ///
  /// [beimOeffnen] läuft, wenn der Schirm das Bearbeiten-Blatt öffnet.
  /// Darüber spielt der Fall zu `32` nach, was das Blatt tut: Es schreibt
  /// und sagt Bescheid.
  Future<Huelle> harness({
    List<Eintrag> eigene = const [],
    Messwert<List<FremdeMahlzeit>>? fremde,
    bool eigeneLaufen = false,
    Future<void> Function(ProviderContainer, Eintrag)? beimOeffnen,
  }) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = ErnaehrungRepository(db);
    for (final e in eigene) {
      await repo.buche(e);
    }

    late final ProviderContainer container;
    final geoeffnet = <Eintrag>[];

    Future<void> oeffne(BuildContext context, Eintrag e) async {
      geoeffnet.add(e);
      if (beimOeffnen != null) await beimOeffnen(container, e);
    }

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        bearbeitenOeffnerProvider.overrideWithValue(oeffne),
        stammdatenProvider.overrideWith(() => _Stammdaten(vollstaendig)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(
              [tageswert(heute)],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(fremde ?? keineFremde()),
        ),
        if (eigeneLaufen) eigeneEintraegeProvider.overrideWith2(_NieFertig.new),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      db: db,
      geoeffnet: geoeffnet,
      app: BehaelterImBaum(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            child: MahlzeitView(
              tagesSchluessel: heute,
              mahlzeit: Mahlzeit.fruehstueck,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist und kein
    // Fall selbst scrollen muss.
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  /// Die Summe der Kalorien — seit #442 im Feld `kcal` des Rasters, bis
  /// dahin in der Kalorienzeile.
  String kcalZeile(WidgetTester tester) =>
      textUnter(tester, const Key('mahlzeit-raster-kcal'));

  /// Die eigenen Einträge, wie der Schirm sie gerade sieht — die Stelle,
  /// an der ein Fall an die vom Repository vergebenen `id`s kommt.
  List<Eintrag> eigeneVon(Huelle h) =>
      h.container.read(mahlzeitProvider((heute, Mahlzeit.fruehstueck))).eigene;

  Key eintragsSchluessel(Eintrag e) => Key('mahlzeit-eintrag-${e.id}');

  /// `true`, wenn ein `GestureDetector` mit gesetztem `onTap` oder ein
  /// `CupertinoButton` mit gesetztem `onPressed` zu [key] gehört — die
  /// beiden Wege, über die diese reine Cupertino-App etwas antippbar
  /// macht (dieselben wie in `ernaehrung_view_test.dart`).
  ///
  /// **Gesucht wird in beide Richtungen und begrenzt.** Ob die Geste
  /// über oder unter dem Schlüssel sitzt, ist eine Bauentscheidung — der
  /// Tagesschirm setzt den Schlüssel auf das `Semantics` **über** der
  /// Geste, anderswo liegt sie darüber. Nach oben endet die Suche an
  /// [bis]: Sonst meldete jede Zeile „tippbar", sobald irgendwo weiter
  /// oben im Schirm eine Geste liegt — und genau das soll der Fall zur
  /// fremden Zeile ausschließen.
  ///
  /// `Dismissible` zählt nicht mit: Es setzt `onHorizontalDrag…`, nicht
  /// `onTap`.
  bool tippbarAn(
    WidgetTester tester,
    Key key, {
    Key bis = const Key('mahlzeit-liste'),
  }) {
    var gefunden = false;

    bool istGeste(Widget widget) =>
        (widget is GestureDetector && widget.onTap != null) ||
        (widget is CupertinoButton && widget.onPressed != null);

    void nachUnten(Element element) {
      if (istGeste(element.widget)) gefunden = true;
      if (!gefunden) element.visitChildElements(nachUnten);
    }

    final wurzel = tester.element(find.byKey(key));
    nachUnten(wurzel);
    if (gefunden) return true;

    wurzel.visitAncestorElements((vorfahre) {
      if (vorfahre.widget.key == bis) return false;
      if (istGeste(vorfahre.widget)) {
        gefunden = true;
        return false;
      }
      return true;
    });
    return gefunden;
  }

  /// Die Schlüssel, die es in **jedem** Zustand gibt. „Eine Anzeige, die
  /// es gibt, hat genau eine Form" (`CLAUDE.md`): Dieselbe Kopfzeile,
  /// dieselbe Tabelle, derselbe Knopf — nur die Füllung unterscheidet
  /// sich.
  const immer = [
    Key('mahlzeit-kopf'),
    Key('mahlzeit-raster'),
    Key('mahlzeit-raster-kcal'),
    Key('mahlzeit-ziel'),
    Key('mahlzeit-werte'),
    Key('mahlzeit-werte-kopf'),
    Key('mahlzeit-liste'),
    Key('mahlzeit-hinzufuegen'),
    Key('mahlzeit-fuss'),
  ];

  const naehrwertZeilen = [
    Key('mahlzeit-wert-eiweiss'),
    Key('mahlzeit-wert-kohlenhydrate'),
    Key('mahlzeit-wert-zucker'),
    Key('mahlzeit-wert-fett'),
    Key('mahlzeit-wert-gesaettigt'),
    Key('mahlzeit-wert-ballaststoffe'),
  ];

  Future<void> klappeAuf(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mahlzeit-werte-kopf')));
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────

  group('Die Nährwerte klappen unter „Alle Nährwerte" auf (V17)', () {
    testWidgets('zugeklappt gibt es die Tabelle nicht', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-werte-kopf')), findsOneWidget);
      expect(find.byKey(const Key('mahlzeit-werte-tabelle')), findsNothing);
      for (final key in naehrwertZeilen) {
        expect(find.byKey(key), findsNothing);
      }
    });

    testWidgets('ein Tipp klappt auf, der nächste wieder zu', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      await klappeAuf(tester);
      expect(find.byKey(const Key('mahlzeit-werte-tabelle')), findsOneWidget);
      for (final key in naehrwertZeilen) {
        expect(find.byKey(key), findsOneWidget);
      }

      await klappeAuf(tester);
      expect(find.byKey(const Key('mahlzeit-werte-tabelle')), findsNothing);
    });

    testWidgets('die alte Kalorienzeile gibt es nicht mehr', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      expect(
        find.byKey(const Key('mahlzeit-werte-kcal')),
        findsNothing,
        reason:
            'Die kcal stehen im Raster (V17); zwei Stellen für dieselbe '
            'Summe liefen irgendwann auseinander.',
      );
    });

    testWidgets('beim Aufklappen springen weder Raster noch Kopfzeile', (
      tester,
    ) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      final raster = tester.getRect(find.byKey(const Key('mahlzeit-raster')));
      final kopf = tester.getRect(find.byKey(const Key('mahlzeit-werte-kopf')));
      final listeVorher = tester
          .getTopLeft(find.byKey(const Key('mahlzeit-liste')))
          .dy;

      await klappeAuf(tester);

      expect(
        tester.getRect(find.byKey(const Key('mahlzeit-raster'))),
        raster,
        reason: 'Das Raster steht über dem Abschnitt und bleibt, wo es ist.',
      );
      expect(
        tester.getRect(find.byKey(const Key('mahlzeit-werte-kopf'))),
        kopf,
        reason:
            'Die Zeile bleibt genau dort und genau so hoch — es klappt nur '
            'etwas darunter auf.',
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('mahlzeit-liste'))).dy,
        greaterThan(listeVorher),
        reason: 'Die Liste rutscht nach unten, sie springt nicht nach oben.',
      );
    });

    testWidgets('die Kopfzeile ist antippbar', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      expect(
        tippbarAn(
          tester,
          const Key('mahlzeit-werte-kopf'),
          bis: const Key('mahlzeit-werte'),
        ),
        isTrue,
      );
    });
  });

  group('Keine Makro-Ziele je Mahlzeit (Entscheidung 11)', () {
    /// Alle `MakroBalken` des Schirms stehen in `mahlzeit-ziel`, und es ist
    /// höchstens einer: kcal gegen das Mahlzeitenziel. Ob der Balken ohne
    /// Ziel ein `MakroBalken` ist, legt diese Datei nicht fest.
    void hoechstensDerEineBalken(WidgetTester tester) {
      final alle = find.byType(MakroBalken).evaluate().length;
      final imZiel = find
          .descendant(
            of: find.byKey(const Key('mahlzeit-ziel')),
            matching: find.byType(MakroBalken),
          )
          .evaluate()
          .length;
      expect(
        alle,
        imZiel,
        reason:
            'Ein Balken braucht ein Ziel, und Makro-Ziele je Mahlzeit gibt '
            'es nicht — nur der kcal-Balken gegen das Mahlzeitenziel.',
      );
      expect(alle, lessThanOrEqualTo(1));
    }

    testWidgets('außer dem einen kcal-Balken weder Balken noch Ringe', (
      tester,
    ) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      hoechstensDerEineBalken(tester);
      expect(find.byType(Ringe), findsNothing);
    });

    testWidgets('auch die leere Mahlzeit zeichnet keinen Balken auf null', (
      tester,
    ) async {
      final h = await harness();
      await zeige(tester, h.app);
      await klappeAuf(tester);

      hoechstensDerEineBalken(tester);
      expect(find.byType(Ringe), findsNothing);
      expect(
        textUnter(tester, const Key('mahlzeit-ziel')),
        isNot(contains('0')),
        reason:
            'Ohne Aufteilung gibt es kein Ziel, und ein leerer Balken '
            'behauptet keine 0.',
      );
    });
  });

  group('Die leere Mahlzeit behält ihre Form', () {
    testWidgets('dieselben Abschnitte wie im vollen Zustand', (tester) async {
      final h = await harness();
      await zeige(tester, h.app);

      for (final key in immer) {
        expect(find.byKey(key), findsOneWidget, reason: '$key fehlt');
      }
      expect(find.byKey(const Key('mahlzeit-leer')), findsOneWidget);
    });

    testWidgets('die Summe sagt `–/–` und nicht `0`', (tester) async {
      final h = await harness();
      await zeige(tester, h.app);

      expect(kcalZeile(tester), contains(ohneWert));
      expect(
        kcalZeile(tester),
        isNot(contains('0')),
        reason:
            'Eine Null behauptete „nichts gegessen", und das ist etwas '
            'anderes als „nichts eingetragen".',
      );
    });

    testWidgets('auch die sechs Nährwertzeilen sagen `–/–`', (tester) async {
      final h = await harness();
      await zeige(tester, h.app);
      await klappeAuf(tester);

      for (final key in naehrwertZeilen) {
        expect(textUnter(tester, key), contains(ohneWert), reason: '$key');
      }
    });

    testWidgets('die Liste beginnt an derselben Stelle wie im vollen Zustand', (
      tester,
    ) async {
      final voll = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, voll.app);
      final oben = tester
          .getTopLeft(find.byKey(const Key('mahlzeit-liste')))
          .dy;

      final leer = await harness();
      await zeige(tester, leer.app);

      expect(
        tester.getTopLeft(find.byKey(const Key('mahlzeit-liste'))).dy,
        oben,
        reason:
            'Werte da, keine Werte, lädt — dieselbe Höhe, dieselbe Stelle. '
            'Sonst springt der Schirm, sobald ein Wert eintrifft.',
      );
    });

    testWidgets('und auch während des Laufs', (tester) async {
      final voll = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, voll.app);
      final oben = tester
          .getTopLeft(find.byKey(const Key('mahlzeit-liste')))
          .dy;

      final laeuft = await harness(eigeneLaufen: true);
      await zeige(tester, laeuft.app);

      expect(
        tester.getTopLeft(find.byKey(const Key('mahlzeit-liste'))).dy,
        oben,
      );
    });
  });

  group('Jede eigene Zeile führt ins Bearbeiten-Blatt', () {
    testWidgets('jede der drei steht einzeln da', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      final eigene = eigeneVon(h);
      expect(eigene.length, 3);
      for (final e in eigene) {
        expect(find.byKey(eintragsSchluessel(e)), findsOneWidget);
      }
    });

    testWidgets('ein Tipp reicht genau diesen Eintrag weiter', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      final zweiter = eigeneVon(h)[1];
      await tester.tap(find.byKey(eintragsSchluessel(zweiter)));
      await tester.pumpAndSettle();

      expect(h.geoeffnet, hasLength(1));
      expect(h.geoeffnet.single.id, zweiter.id);
      expect(h.geoeffnet.single.name, zweiter.name);
    });

    testWidgets('und das gilt für jede der drei Zeilen', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      for (final e in eigeneVon(h)) {
        await tester.tap(find.byKey(eintragsSchluessel(e)));
        await tester.pumpAndSettle();
      }

      expect(
        h.geoeffnet.map((e) => e.id).toList(),
        eigeneVon(h).map((e) => e.id).toList(),
      );
    });

    testWidgets(
      'nach dem Ändern einer Menge stimmt die Summe beim Zurückkommen '
      '(docs/todo/32)',
      (tester) async {
        // Das Blatt tut, was das Buchungsblatt aus Task 7 tut: Es
        // schreibt und sagt Bescheid.
        final h = await harness(
          eigene: [
            eintrag(name: 'Testbrei', stundeUtc: 6, kcal: 300),
            eintrag(name: 'Testquark', stundeUtc: 7, kcal: 200),
          ],
          beimOeffnen: (container, e) async {
            final repo = container.read(ernaehrungRepositoryProvider);
            await repo.loesche(e.id!);
            await repo.buche(
              Eintrag(
                tagesSchluessel: e.tagesSchluessel,
                mahlzeit: e.mahlzeit,
                zeitpunkt: e.zeitpunkt,
                name: e.name,
                naehrwerte: const Naehrwerte(
                  kcal: 400,
                  eiweissG: 10,
                  kohlenhydrateG: 50,
                  fettG: 6,
                  ballaststoffeG: 8,
                ),
              ),
            );
            await container
                .read(eigeneEintraegeProvider(heute).notifier)
                .neuLesen();
          },
        );
        await zeige(tester, h.app);

        expect(kcalZeile(tester), contains(formatNumber(500)));

        final zweiter = eigeneVon(h)[1];
        await tester.tap(find.byKey(eintragsSchluessel(zweiter)));
        await tester.pumpAndSettle();

        expect(
          kcalZeile(tester),
          contains(formatNumber(700)),
          reason:
              'Der Schirm hält keine eigene Kopie der Summe — er liest sie '
              'aus dem Provider, und der kommt aus der Tabelle.',
        );
      },
    );
  });

  group('Fremde Zeilen aus Apple Health', () {
    testWidgets('sie stehen in der Liste und zählen in der Summe mit', (
      tester,
    ) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-fremd-0')), findsOneWidget);
      expect(kcalZeile(tester), contains(formatNumber(750)));
    });

    testWidgets('die Herkunft steht an der Zeile', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('mahlzeit-fremd-0')).toLowerCase(),
        contains('health'),
        reason:
            'Das muss man sehen, bevor man darauf tippt — eine Zeile, die '
            'aussieht wie die eigenen und nichts tut, ist eine kaputte '
            'Zeile.',
      );
      expect(
        textUnter(tester, eintragsSchluessel(eigeneVon(h).first)).toLowerCase(),
        isNot(contains('health')),
      );
    });

    testWidgets('sie hat keinen tippbaren Vorfahren', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      expect(
        tippbarAn(tester, const Key('mahlzeit-fremd-0')),
        isFalse,
        reason: 'Keine Zeile, die drückbar aussieht und nirgendwohin führt.',
      );
      expect(tippbarAn(tester, eintragsSchluessel(eigeneVon(h).first)), isTrue);
    });

    testWidgets('ein Tipp darauf öffnet kein Blatt', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      await tester.tap(
        find.byKey(const Key('mahlzeit-fremd-0')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        h.geoeffnet,
        isEmpty,
        reason: 'Apple gibt fremde Proben nicht frei.',
      );
    });

    testWidgets('und der Schirm sagt, warum', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-fuss')), findsOneWidget);
      expect(
        textUnter(tester, const Key('mahlzeit-fuss')).toLowerCase(),
        contains('health'),
      );
    });

    testWidgets('sie lässt sich nicht wegstreichen', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      await tester.drag(
        find.byKey(const Key('mahlzeit-fremd-0')),
        const Offset(-600, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mahlzeit-fremd-0')),
        findsOneWidget,
        reason: 'Eine fremde Probe ist nicht unsere, sie zu löschen.',
      );
      expect(find.byKey(const Key('mahlzeit-rueckgaengig')), findsNothing);
    });
  });

  group('Kommt alles aus einer anderen App', () {
    testWidgets('steht ein Hinweis statt eines kaputt wirkenden Schirms', (
      tester,
    ) async {
      final h = await harness(fremde: eineFremde());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-nur-health')), findsOneWidget);
      expect(find.byKey(const Key('mahlzeit-fremd-0')), findsOneWidget);
      expect(find.byKey(const Key('mahlzeit-leer')), findsNothing);
      for (final key in immer) {
        expect(find.byKey(key), findsOneWidget, reason: '$key fehlt');
      }
    });

    testWidgets('bei gemischten Zeilen steht er nicht da', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-nur-health')), findsNothing);
    });

    testWidgets('und bei der leeren Mahlzeit auch nicht', (tester) async {
      final h = await harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-nur-health')), findsNothing);
    });
  });

  group('Während des Laufs (docs/todo/01)', () {
    testWidgets('steht nirgends ein „nichts eingetragen"-Grund', (
      tester,
    ) async {
      final h = await harness(eigeneLaufen: true);
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-leer')), findsNothing);
      expect(
        alleTexte(tester),
        isNot(contains('nichts')),
        reason:
            'Solange niemand nachgesehen hat, ist „nichts eingetragen" '
            'eine Behauptung über eine Datenlage, die keiner kennt.',
      );
    });

    testWidgets('an der Stelle der Summe steht der Ladeplatzhalter', (
      tester,
    ) async {
      final h = await harness(eigeneLaufen: true);
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byKey(const Key('mahlzeit-raster-kcal')),
          matching: find.byType(Platzhalter),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        kcalZeile(tester),
        isNot(contains(ohneWert)),
        reason:
            'Der Platzhalter gehört allein in „noch nie" — `–/–` hieße '
            '„gelesen, kein Wert", und gelesen hat noch niemand.',
      );
      expect(kcalZeile(tester), isNot(contains('0')));
    });

    testWidgets('und die Abschnitte stehen trotzdem alle da', (tester) async {
      final h = await harness(eigeneLaufen: true);
      await zeige(tester, h.app);

      for (final key in immer) {
        expect(find.byKey(key), findsOneWidget, reason: '$key fehlt');
      }
    });
  });

  group('Der Vorlesetext nennt den Zustand, nicht das Zeichen', () {
    testWidgets('das kcal-Feld ohne Werte sagt „keine Werte"', (tester) async {
      // **Kein eigenes `tester.ensureSemantics()` hier.** `testWidgets`
      // schaltet die Semantik selbst ein und zählt die offenen
      // `SemanticsHandle` am **Ende des Testrumpfs** — also bevor
      // `package:test` die `addTearDown`-Rückrufe abarbeitet. Ein über
      // `addTearDown(handle.dispose)` aufgeräumtes Handle ist dann noch
      // offen, und der Fall scheitert an „A SemanticsHandle was active at
      // the end of the test", ohne dass eine einzige Zusicherung
      // fehlschlägt. `tester.getSemantics(…)` braucht ohnehin keines.
      // Hausform: `shell/heute_view_test.dart` und
      // `design/icon_row_test.dart`.
      final h = await harness();
      await zeige(tester, h.app);

      final label = tester
          .getSemantics(find.byKey(const Key('mahlzeit-raster-kcal')))
          .label
          .toLowerCase();

      expect(label, contains('kalorien'));
      expect(label, contains('keine werte'));
      expect(
        label,
        isNot(contains(ohneWert)),
        reason: 'VoiceOver läse `–/–` als „Strich Schrägstrich Strich" vor.',
      );
      expect(label, isNot(contains('strich')));
    });

    testWidgets('und eine Nährwertzeile ohne Angabe genauso', (tester) async {
      // Kein eigenes `ensureSemantics()` — siehe oben: `addTearDown` läuft
      // erst nach der Handle-Zählung von `testWidgets`.
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      final label = tester
          .getSemantics(find.byKey(const Key('mahlzeit-wert-zucker')))
          .label
          .toLowerCase();

      expect(label, contains('keine werte'));
      expect(label, isNot(contains(ohneWert)));
      expect(label, isNot(contains('strich')));
    });
  });

  group('Ein fehlender Nährwert steht als `–/–` da', () {
    testWidgets('was niemand deklariert hat, ist kein `0`', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      expect(
        textUnter(tester, const Key('mahlzeit-wert-zucker')),
        contains(ohneWert),
      );
      expect(
        textUnter(tester, const Key('mahlzeit-wert-gesaettigt')),
        contains(ohneWert),
      );
      expect(
        textUnter(tester, const Key('mahlzeit-wert-eiweiss')),
        contains(formatNumber(30)),
      );
      expect(
        textUnter(tester, const Key('mahlzeit-wert-ballaststoffe')),
        contains(formatNumber(24)),
      );
    });
  });

  group('Löschen über Streichen, mit Rückgängig', () {
    testWidgets('ein waagerechter Zug nimmt die Zeile weg', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      final zweiter = eigeneVon(h)[1];
      await tester.drag(
        find.byKey(eintragsSchluessel(zweiter)),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(eintragsSchluessel(zweiter)), findsNothing);
      expect(eigeneVon(h).map((e) => e.name), isNot(contains('Testquark')));
      expect(kcalZeile(tester), contains(formatNumber(400)));
    });

    testWidgets('die Zeile ist danach auch aus der Tabelle weg', (
      tester,
    ) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      final zweiter = eigeneVon(h)[1];
      await tester.drag(
        find.byKey(eintragsSchluessel(zweiter)),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      final ausDerTabelle = await h.container
          .read(ernaehrungRepositoryProvider)
          .eintraegeAmTag(heute);
      expect(ausDerTabelle.map((e) => e.name), isNot(contains('Testquark')));
    });

    testWidgets('danach gibt es einen Weg zurück', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      await tester.drag(
        find.byKey(eintragsSchluessel(eigeneVon(h)[1])),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mahlzeit-rueckgaengig')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mahlzeit-rueckgaengig')));
      await tester.pumpAndSettle();

      expect(eigeneVon(h).map((e) => e.name), contains('Testquark'));
      expect(eigeneVon(h), hasLength(3));
      expect(kcalZeile(tester), contains(formatNumber(600)));
    });

    testWidgets('das Rückgängig schreibt die Zeile auch zurück', (
      tester,
    ) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      await tester.drag(
        find.byKey(eintragsSchluessel(eigeneVon(h)[1])),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mahlzeit-rueckgaengig')));
      await tester.pumpAndSettle();

      final ausDerTabelle = await h.container
          .read(ernaehrungRepositoryProvider)
          .eintraegeAmTag(heute);
      expect(ausDerTabelle.map((e) => e.name), contains('Testquark'));
    });

    testWidgets('ohne Löschen steht kein Rückgängig da', (tester) async {
      final h = await harness(eigene: dreiEigene());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('mahlzeit-rueckgaengig')), findsNothing);
    });

    testWidgets('die letzte Zeile wegzustreichen führt in den leeren Zustand', (
      tester,
    ) async {
      final h = await harness(eigene: [eintrag(name: 'Testbrei', kcal: 300)]);
      await zeige(tester, h.app);

      await tester.drag(
        find.byKey(eintragsSchluessel(eigeneVon(h).single)),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mahlzeit-leer')), findsOneWidget);
      expect(kcalZeile(tester), contains(ohneWert));
      expect(kcalZeile(tester), isNot(contains('0')));
    });
  });

  group('Der Schirm baut', () {
    testWidgets('ohne Ausnahme und ohne ErrorWidget', (tester) async {
      final h = await harness(eigene: dreiEigene(), fremde: eineFremde());
      await zeige(tester, h.app);
      await klappeAuf(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('und die Seite trägt genau eine Ansicht', (tester) async {
      final h = await harness(eigene: dreiEigene());
      tester.view.physicalSize = const Size(900, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BehaelterImBaum(
          container: h.container,
          child: const CupertinoApp(
            home: MahlzeitSeite(
              tagesSchluessel: heute,
              mahlzeit: Mahlzeit.fruehstueck,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MahlzeitView), findsOneWidget);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    });
  });
}

/// Was die Testhülle zurückgibt.
typedef Huelle = ({
  ProviderContainer container,
  AppCache db,
  Widget app,
  List<Eintrag> geoeffnet,
});

/// Steuerbare Ableger der echten Notifier — siehe `ernaehrung_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
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

/// Ein Lesevorgang, der nie zurückkommt — der einzige Zustand, in dem
/// „noch nicht gelesen" gilt.
class _NieFertig extends EigeneEintraegeNotifier {
  _NieFertig(super.tagesSchluessel);

  @override
  Future<List<Eintrag>> build() => Completer<List<Eintrag>>().future;
}
