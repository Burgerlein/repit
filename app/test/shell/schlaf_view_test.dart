import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/segment_ring.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';
import 'package:repit/shell/tagschlaf_view.dart';
// `AppTarget` liegt in `shell/ziele.dart`, nicht in `shell/router.dart`.
import 'package:repit/shell/ziele.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für den **Schirm** `schlaf` (#92) — `lib/shell/schlaf_view.dart`.
/// Der Zustand darunter liegt in `schlaf_zustand_test.dart`, der
/// Tagschlaf-Schirm in `tagschlaf_view_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/schlaf_view.dart`)
///
/// ```dart
/// /// Öffnet den Schlaf-Schirm auf dem Stapel des **aktuell gewählten**
/// /// Tabs. Die eine Stelle, die das weiß.
/// void oeffneSchlaf(AppRouter router);
///
/// /// Der Rahmen: Gerüst, Navigationsleiste und das Kalenderblatt oben
/// /// rechts.
/// class SchlafSeite extends StatelessWidget {
///   const SchlafSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class SchlafView extends ConsumerWidget {
///   const SchlafView({super.key, required AppRouter router});
/// }
///
/// /// Das Monatsraster hinter dem Kalenderknopf.
/// class SchlafKalenderblatt extends ConsumerWidget {
///   const SchlafKalenderblatt({super.key});
/// }
/// ```
///
/// Die einzelnen Abschnitte dürfen in eigene Dateien
/// (`lib/shell/schlaf_abschnitte.dart` o. ä.) — `CLAUDE.md`: „Views bleiben
/// klein." Diese Datei legt nur fest, was der Schirm **tut**, nicht wie er
/// geschnitten ist.
///
/// ## Die Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt (dieselbe Begründung wie in
/// `erholung_view_test.dart`). Jeder sitzt auf einem **Vorfahren** der
/// Texte, nicht auf einem `Text` selbst:
///
/// - `Key('schlaf-laden')` — der reine Ladezweig
/// - `Key('schlaf-leer')` — fertiger Lauf ohne Nacht
/// - `Key('schlaf-fehler')` — gescheiterter Lauf ohne Cache
/// - `Key('schlaf-blaetterleiste')` — die Kopfzeile der Nachtkarte
/// - `Key('schlaf-frueher')`, `Key('schlaf-spaeter')` — die beiden Pfeile
/// - `Key('schlaf-scorekarte')` — Ring, Dauer, Fenster, drei Teilnoten
/// - `Key('schlaf-teil-dauer')`, `Key('schlaf-teil-zubettgehzeit')`,
///   `Key('schlaf-teil-unterbrechungen')`
/// - `Key('schlaf-tagschlaf')` — die Zeile zum Tagschlaf, nur mit Tagschlaf
/// - `Key('schlaf-verlauf')` — Diagramm samt Stufenleiste
/// - `Key('schlaf-verlauf-hinweis')` — der Satz „bezieht sich auf heute",
///   **nur**, wenn oben eine ältere Nacht steht
/// - `Key('schlaf-statistik-7')`, `Key('schlaf-statistik-30')`
/// - `Key('schlaf-phasen')` — das volle Hypnogramm
/// - `Key('schlaf-puls')`, `Key('schlaf-atmung')` — die Min-Max-Spannen
/// - `Key('schlaf-naechte')` — „Sieben Nächte"
/// - `Key('schlaf-fussnote')` — die Erklärung des Score
/// - `Key('schlaf-kalender-knopf')` — in der Navigationsleiste von
///   [SchlafSeite]
/// - `Key('schlaf-kalenderblatt')` — das Sheet
/// - `Key('schlaf-kalender-tag-2026-10-09')` — je Tageszelle, Schlüssel ist
///   `BerlinCalendar.dayKey`
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht Layout
/// und Beschriftung. Kein Test schreibt einen Satz fest. Wo ein Text eine
/// *Regel* trägt, wird die Regel geprüft:
///
/// - Während des Ladens steht **kein** „keine Daten"-Grund (`docs/todo/01`).
/// - Bei fehlenden Daten kommen **beide** Wörter vor („aufgezeichnet" und
///   „freigegeben") — Apple verrät den Lesestatus nicht.
/// - Eine entfallene Teilnote steht als „entfällt", **nie** als „0/30".
/// - Die Caption des Rings nennt die **erreichbare** Punktzahl; bei 70
///   erreichbaren Punkten steht in der Karte nirgends 100.
/// - Die gewählte Nacht überlebt das Verlassen des Schirms **nicht**.
/// - Verlauf und Statistiken sagen, dass sie sich auf heute beziehen,
///   sobald oben eine ältere Nacht steht — und ändern ihre Zahlen beim
///   Blättern nicht.
/// - Jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren.
///
/// **Nicht geprüft, bewusst:**
///
/// - **Die Wischgeste.** Sie ist #127 und ausdrücklich nicht Teil dieses
///   Auftrags; der Zustand ist nur so geschnitten, dass sie dazukommen kann
///   (`blaettere(…)`, siehe `schlaf_zustand_test.dart`).
/// - **„Nacht von Hand eintragen".** ENTWURF vom 26.10.2026
///   (`docs/screens/screens/schlaf.js:20–37`), steht **nicht** in
///   `docs/SPEC.md` und nicht im Auftrag. Der Schirm baut es nicht, und
///   dieser Test verlangt es nicht.
/// - **Das Diagramm selbst.** Balken, Ziellinie, Achsen, Blättern und
///   Ablesen gehören zu **#130** (Diagramm-Bauteil). Hier steht nur, dass
///   es den Abschnitt `Key('schlaf-verlauf')` gibt und was der Satz
///   darunter sagt, wenn oben eine ältere Nacht steht. Die Stufen und die
///   Verdichtung kommen aus `lib/shell/diagramm_zeitraum.dart` (#94) —
///   deshalb entsteht hier kein zweites Stufen-Enum.
/// - **Die Stufe `T` im Verlauf.** Der Entwurf nimmt sie dazu
///   (`schlaf.js:102–105`), SPEC 4.6 Z. 227–228 schließt sie aus. Vorerst
///   gewinnt die SPEC (Ticket #92, „Offene Frage an Tim"); geprüft wird das
///   im Zustandstest an `DiagrammStufe.values`.
/// - **Das Zeichnen selbst** — Balkenhöhen, Farben, Abstände, die
///   Reihenfolge der Abschnitte untereinander.
/// - **Wohin der Erholung-Schirm springt.** Das legt
///   `erholung_view_test.dart` fest. Hier wird nur [oeffneSchlaf] für sich
///   geprüft — die eine Stelle, die weiß, wie dieser Schirm geöffnet wird.
///
///   *(Stand 28.10.2026: Bis dahin stand hier, der Schlaf-Ring führe noch
///   auf `ErholungTuerPlatzhalter`. Seit dem Durchgang „die Türen werden
///   verdrahtet" führt er auf `SchlafSeite`, und der Platzhalter ist weg.
///   An dieser Datei ändert das nichts.)*
///
/// ## Ein Fall räumt den Baum selbst ab — und warum das bleiben muss
///
/// Genau **ein** Test dieser Datei baut zwei `harness()` nacheinander und
/// pumpt beide („die Dauer der Nacht enthält den Tagschlaf nicht"): Er
/// vergleicht denselben Schirm mit und ohne Nickerchen, und dafür braucht
/// er zwei Container. Er endet deshalb mit [raeumeAb].
///
/// Der Grund ist Riverpods Aufräumweg, nicht eine Eigenart des Schirms:
/// Beim zweiten `pumpWidget` wird der `UncontrolledProviderScope` des
/// ersten Containers abgebaut. `flutterVsyncs` ist dann leer, und
/// riverpod 3.4.3 plant das Aufräumen jedes `autoDispose`-Providers über
/// einen `Timer(Duration.zero)` statt über den Flutter-Vsync. Ohne einen
/// weiteren Frame bleibt der Timer stehen, und `testWidgets` meldet „A
/// Timer is still pending even after the widget tree was disposed".
/// Nachgestellt wurde das an einem Minimalbeispiel ohne jeden Schlaf-Code:
/// zweimal `pumpWidget` mit je eigenem Container und einem einzigen
/// `Provider.autoDispose` — es fällt um; mit `Provider` läuft es durch.
///
/// **`autoDispose` ist trotzdem richtig und bleibt.** Dieselbe Datei
/// verlangt eine Zeile weiter oben ausdrücklich, dass die gewählte Nacht
/// das Verlassen des Schirms nicht überlebt — das ist Entscheidung 3 vom
/// 13.10.2026, und `autoDispose` ist der Mechanismus dahinter. Wer den
/// hängenden Timer durch einen dauerhaften Provider „behebt", nimmt dem
/// Schirm seine Hauptzusage. Deshalb räumt der Test ab, nicht der Zustand.
///
/// Kein anderer Fall dieser Datei pumpt zwei Container; die
/// `addTearDown(container.dispose)`-Zeile in [harness] reicht ihnen. Der
/// Test „die gewählte Nacht überlebt das Verlassen nicht" tauscht den Baum
/// zwar ebenfalls aus, behält aber **denselben** Container und pumpt
/// danach weiter — dort entsteht der Timer gar nicht erst.
///
/// ## Nachgezogen am 03.11.2026 für #253 und #257
///
/// „Gibt es kein zirkuläres Mittel, steht ein Gedankenstrich …" klappt den
/// Statistikblock seither **auf**, bevor es nachsieht. Seit #253 stehen
/// die beiden Schnitte und der Verlauf am Fuß des Schirms in je einem
/// `KlappAbschnitt` und sind beim Öffnen zugeklappt (Tim am 03.11.2026:
/// „sonst ist die Seite so lang"). „Ø Einschlafen" steht im Rumpf, und den
/// gibt es zugeklappt nicht.
///
/// **„Sieben Nächte" gehört seit #257 nicht mehr dazu** — es stand kurz
/// mit in den Klappzeilen, das war die Auslegung einer Rückfrage. Der
/// Abschnitt steht wieder offen bei den Bildern der Nacht;
/// `Key('schlaf-naechte')` sitzt wieder auf seiner Karte und findet ihn
/// genauso.
///
/// **Die Zusicherungen stehen Wort für Wort unverändert** — der
/// Gedankenstrich, kein `0:00`, kein `00:00`. Dazugekommen ist allein der
/// Weg dorthin: ein Tipp auf `Key('schlaf-statistik-7-kopf')`. Wer ihn für
/// überflüssig hält und entfernt, macht den Fall rot, ohne dass am Schirm
/// etwas falsch wäre.
///
/// Die übrigen Fälle bleiben, wie sie waren: Die drei Abschnittsschlüssel
/// sitzen seit #253 auf der **Klappzeile** statt auf dem Inhalt, also
/// finden sie den Abschnitt weiter, und der Titel „Letzte 7 Nächte bis
/// heute" steht weiter unter ihnen. Dass die drei zugeklappt beginnen und
/// aufgeklappt bleiben, prüft `schlaf_klapp_test.dart`; dass „Sieben
/// Nächte" offen steht, `schlaf_sieben_naechte_offen_test.dart`.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  SleepNight nachtAus({
    required DateTime tag,
    required DateTime beginn,
    required List<(SleepStage, int)> phasen,
    List<SleepSession> naps = const [],
  }) {
    final abschnitte = <SleepSegment>[];
    var zeiger = beginn;
    for (final (phase, minuten) in phasen) {
      final ende = zeiger.add(Duration(minutes: minuten));
      abschnitte.add(SleepSegment(stage: phase, start: zeiger, end: ende));
      zeiger = ende;
    }
    return SleepNight(
      date: tag,
      session: SleepSession(segments: abschnitte),
      naps: naps,
    );
  }

  /// Eine Nacht mit allen vier Phasen, 23:00 bis 06:00.
  SleepNight nachtVon(int tag, {List<SleepSession> naps = const []}) => nachtAus(
    tag: tagesbeginn(tag),
    beginn: berlin(tag - 1, 23),
    phasen: const [
      (SleepStage.core, 120),
      (SleepStage.deep, 60),
      (SleepStage.awake, 15),
      (SleepStage.rem, 90),
      (SleepStage.core, 135),
    ],
    naps: naps,
  );

  SleepSession nickerchen(int tag) => SleepSession(
    segments: [
      SleepSegment(
        stage: SleepStage.core,
        start: berlin(tag, 13, 40),
        end: berlin(tag, 14, 15),
      ),
    ],
  );

  List<SleepNight> reihe({int anzahl = 14}) {
    final ergebnis = <SleepNight>[];
    for (var i = anzahl - 1; i >= 0; i--) {
      ergebnis.add(nachtVon(12 - i));
    }
    return ergebnis;
  }

  /// Dieselbe Reihe, aber die letzte Nacht hat ein Nickerchen.
  ///
  /// **Nicht angehängt, sondern ersetzt:** Zwei Nächte mit demselben Datum
  /// wären keine Datenlage, die der Kanal je liefert — und sie brächen
  /// sowohl die Score-Karte des Kalenderblatts als auch die Nachbarschaft
  /// beim Blättern.
  List<SleepNight> reiheMitNickerchen() => [
    ...reihe().sublist(0, reihe().length - 1),
    nachtVon(12, naps: [nickerchen(12)]),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Von Hand gebaute Zustände — für die Fälle, die der Kanal heute nicht
  // erzeugen kann (siehe Bericht: eine Nacht aus `alsRecoveryNacht` hat
  // immer eine Einschlafzeit, sobald sie überhaupt Schlaf enthält).
  // ───────────────────────────────────────────────────────────────────────

  SchlafNacht schlafNacht({
    SleepNight? nacht,
    SleepScore score = const SleepScore(
      duration: 44,
      bedtime: 27,
      interruptions: 10,
    ),
  }) {
    final n = nacht ?? nachtVon(12);
    return SchlafNacht(
      nacht: n,
      kern: RecoveryNight(
        date: n.date,
        asleepMinutes: 405,
        bedtime: score.bedtime == null ? null : berlin(11, 23),
        awakeMinutes: 15,
        wakeCount: 1,
      ),
      score: score,
      teilnoten: schlafTeilnoten(score),
      von: berlin(11, 23),
      bis: berlin(12, 6),
      naps: n.naps,
    );
  }

  SchlafZustand handZustand({
    SchlafNacht? nacht,
    DateTime? frueher,
    DateTime? spaeter,
    bool zeigtAeltereNacht = false,
    SchlafStatistik? statistik7,
    SchlafStatistik? statistik30,
    Map<DateTime, SleepScore> scores = const {},
    Messwert<SchlafDaten>? roh,
  }) {
    final daten =
        roh ??
        Bekannt<SchlafDaten>(
          SchlafDaten(
            nacht: nacht ?? schlafNacht(),
            frueher: frueher,
            spaeter: spaeter,
            zeigtAeltereNacht: zeigtAeltereNacht,
            statistik7: statistik7,
            statistik30: statistik30,
            scores: scores,
          ),
          stand: jetzt,
          laeuft: false,
        );
    return SchlafZustand(
      daten: daten,
      ziele: Ziele.vorbelegung,
      heute: BerlinCalendar.startOfDay(jetzt),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    Messwert<List<SleepNight>>? schlaf,
    Ziele ziele = Ziele.vorbelegung,
    SchlafZustand? zustand,
    _FakeHealthReading? quelle,
    bool mitSeite = false,
    // **Der gelesene Zeitraum** (#177). Seit leere Tage erreichbar sind,
    // endet das Blättern an seinem Anfang und nicht an der ältesten
    // geladenen Nacht — wer einen Rand prüfen will, sagt hier, wo er liegt.
    DateTime? fensterBeginn,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        if (fensterBeginn != null)
          dataWindowProvider.overrideWith(
            (ref) => DataWindow(start: fensterBeginn),
          ),
        healthProvider.overrideWithValue(quelle ?? _FakeHealthReading()),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: false),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(ziele)),
        if (zustand != null) schlafProvider.overrideWith((ref) => zustand),
      ],
    );
    addTearDown(container.dispose);

    final inhalt = mitSeite
        ? SchlafSeite(router: router)
        : SchlafView(router: router);

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              // Entspricht der durchscheinenden Navigations- und Tableiste.
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: inhalt,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist.
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// Räumt den Widget-Baum ab und gibt Riverpod den Frame, in dem es seine
  /// `autoDispose`-Provider aufräumen kann.
  ///
  /// Nötig in jedem Fall, der **zwei** Container nacheinander pumpt — die
  /// ausführliche Begründung steht im Dateikopf. Nicht entfernen, auch
  /// wenn die Zeilen wie Kosmetik aussehen: Ohne sie bleibt ein
  /// `Timer(Duration.zero)` stehen und der Fall scheitert mit „A Timer is
  /// still pending".
  Future<void> raeumeAb(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
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

  /// `true`, wenn der Pfeil hinter [key] gedrückt werden kann.
  ///
  /// Sucht den Schlüssel **auf** dem Knopf und, falls er weiter innen
  /// sitzt, bei dessen Vorfahren. Wo genau der Umsetzende ihn hinhängt,
  /// ist Aufbau und soll keinen Test umwerfen.
  bool knopfAktiv(WidgetTester tester, Key key) {
    final direkt = find.byKey(key);
    final aufDemKnopf = find.byWidgetPredicate(
      (w) => w is CupertinoButton && w.key == key,
    );
    final treffer = aufDemKnopf.evaluate().isNotEmpty
        ? aufDemKnopf
        : find.ancestor(of: direkt, matching: find.byType(CupertinoButton));

    return tester.widget<CupertinoButton>(treffer.first).onPressed != null;
  }

  DateTime gezeigteNacht(ProviderContainer container) {
    final daten = container.read(schlafProvider).daten;
    return (daten as Bekannt<SchlafDaten>).wert.nacht!.nacht.date;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Hausordnung
  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets('SchlafView bringt weder Gerüst noch Leiste noch Navigator', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SchlafView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
    });

    testWidgets('SchlafSeite stellt beides — sie ist das Geschobene', (
      tester,
    ) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(SchlafView), findsOneWidget);
    });

    testWidgets(
      'der Inhalt scrollt und bekommt GlasAbstand als padding — er läuft '
      'unter der Leiste durch, statt davor anzuhalten',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final scroll = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: find.byType(SchlafView),
            matching: find.byType(SingleChildScrollView),
          ).first,
        );
        final padding = scroll.padding! as EdgeInsets;

        expect(padding.top, 47);
        expect(padding.bottom, greaterThanOrEqualTo(34 + GlasAbstand.fabUeberstand));
      },
    );

    testWidgets(
      'der Schirm besorgt seine Daten selbst — ohne jede Vorarbeit steht '
      'die letzte Nacht da',
      (tester) async {
        // Nur die Quellen sind überschrieben, `schlafProvider` nicht.
        final h = harness();
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
        expect(gezeigteNacht(h.container), tagesbeginn(12));
      },
    );

    testWidgets('oeffneSchlaf schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final router = AppRouter();
      router.open(AppTarget.gym());
      router.nimmBefehl();

      oeffneSchlaf(router);
      final befehl = router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(befehl.tab, Tab.gym);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die vier Messwert-Zweige
  // ───────────────────────────────────────────────────────────────────────

  group('Die vier Zustände von Messwert', () {
    testWidgets(
      'NochNie: ein Ladehinweis und **kein** Grund — während des Laufs steht '
      'nie „keine Daten" (docs/todo/01)',
      (tester) async {
        final h = harness(schlaf: const NochNie<List<SleepNight>>());
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-laden')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-leer')), findsNothing);
        expect(find.byKey(const Key('schlaf-scorekarte')), findsNothing);

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('nicht aufgezeichnet')));
        expect(texte, isNot(contains('nicht freigegeben')));
        expect(texte, isNot(contains('keine daten')));
      },
    );

    testWidgets(
      'LeerNachLauf: beide Möglichkeiten werden genannt — Apple verrät den '
      'Lesestatus nicht',
      (tester) async {
        final h = harness(
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-leer')), findsOneWidget);
        final texte = alleTexte(tester);
        expect(texte, contains('aufgezeichnet'));
        expect(texte, contains('freigegeben'));
      },
    );

    testWidgets(
      'LeerNachLauf behauptet nirgends, es sei nichts getrackt worden',
      (tester) async {
        final h = harness(
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('nichts getrackt')));
        expect(texte, isNot(contains('nicht geschlafen')));
      },
    );

    testWidgets(
      'Fehlgeschlagen: der Schirm sagt, dass es nicht geklappt hat — und '
      'gerade nicht, dass es keine Daten gäbe',
      (tester) async {
        final h = harness(
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'Kanal weg',
            gelaufen: jetzt,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-fehler')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-leer')), findsNothing);
        expect(alleTexte(tester), isNot(contains('freigegeben')));
      },
    );

    testWidgets('Bekannt: die Score-Karte steht da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-laden')), findsNothing);
      expect(find.byKey(const Key('schlaf-leer')), findsNothing);
      expect(find.byKey(const Key('schlaf-fehler')), findsNothing);
    });

    testWidgets(
      'Bekannt mit laufendem Nachlauf zeigt weiter die Nacht — ein '
      'gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            reihe(),
            stand: jetzt,
            laeuft: true,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Score steht ausgeschrieben da
  // ───────────────────────────────────────────────────────────────────────

  group('Die Score-Karte', () {
    testWidgets('drei Teilnoten, jede mit eigener Zeile', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-teil-dauer')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-teil-zubettgehzeit')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-teil-unterbrechungen')), findsOneWidget);
    });

    testWidgets('der Ring trägt drei Abschnitte', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final ring = tester.widget<SegmentRing>(
        find.descendant(
          of: find.byKey(const Key('schlaf-scorekarte')),
          matching: find.byType(SegmentRing),
        ),
      );

      expect(ring.abschnitte, hasLength(3));
    });

    testWidgets('in der Mitte steht die Summe', (tester) async {
      final h = harness(
        zustand: handZustand(
          nacht: schlafNacht(
            score: const SleepScore(duration: 44, bedtime: 27, interruptions: 10),
          ),
        ),
      );
      await zeige(tester, h.app);

      final ring = tester.widget<SegmentRing>(find.byType(SegmentRing));

      expect(ring.mitte, '81');
    });

    testWidgets(
      'die Caption nennt die erreichbare Punktzahl — ohne sie ist die '
      'Bewertung daneben nicht nachrechenbar',
      (tester) async {
        final h = harness(
          zustand: handZustand(
            nacht: schlafNacht(
              score: const SleepScore(
                duration: 44,
                bedtime: null,
                interruptions: 10,
              ),
            ),
          ),
        );
        await zeige(tester, h.app);

        final ring = tester.widget<SegmentRing>(find.byType(SegmentRing));

        expect(ring.mitte, '54');
        expect(ring.caption, contains('70'));
      },
    );

    testWidgets(
      'der Ring normiert nicht hoch: bei 70 erreichbaren Punkten steht in '
      'der Karte nirgends 100',
      (tester) async {
        final h = harness(
          zustand: handZustand(
            nacht: schlafNacht(
              score: const SleepScore(
                duration: 44,
                bedtime: null,
                interruptions: 10,
              ),
            ),
          ),
        );
        await zeige(tester, h.app);

        expect(
          textUnter(tester, const Key('schlaf-scorekarte')),
          isNot(contains('100')),
        );
      },
    );

    testWidgets(
      'fehlt die Einschlafzeit, steht „entfällt" — nicht „0/30". Die Nacht '
      'war nicht spät, es ist nichts aufgezeichnet',
      (tester) async {
        final h = harness(
          zustand: handZustand(
            nacht: schlafNacht(
              score: const SleepScore(
                duration: 44,
                bedtime: null,
                interruptions: 10,
              ),
            ),
          ),
        );
        await zeige(tester, h.app);

        final zeile = textUnter(
          tester,
          const Key('schlaf-teil-zubettgehzeit'),
        ).toLowerCase();

        expect(zeile, contains('entfällt'));
        expect(zeile, isNot(contains('0/30')));
        expect(zeile, isNot(contains('0 / 30')));
      },
    );

    testWidgets(
      'und der Abschnitt des Rings ist als ohne Grundlage gekennzeichnet',
      (tester) async {
        final h = harness(
          zustand: handZustand(
            nacht: schlafNacht(
              score: const SleepScore(
                duration: 44,
                bedtime: null,
                interruptions: 10,
              ),
            ),
          ),
        );
        await zeige(tester, h.app);

        final ring = tester.widget<SegmentRing>(find.byType(SegmentRing));

        expect(ring.abschnitte[1].hatGrundlage, isFalse);
        expect(ring.abschnitte[0].hatGrundlage, isTrue);
        expect(ring.abschnitte[2].hatGrundlage, isTrue);
      },
    );

    testWidgets('null Punkte sind etwas anderes und stehen als Zahl da', (
      tester,
    ) async {
      final h = harness(
        zustand: handZustand(
          nacht: schlafNacht(
            score: const SleepScore(duration: 20, bedtime: 0, interruptions: 0),
          ),
        ),
      );
      await zeige(tester, h.app);

      final zeile = textUnter(
        tester,
        const Key('schlaf-teil-zubettgehzeit'),
      ).toLowerCase();

      expect(zeile, isNot(contains('entfällt')));
      expect(zeile, contains('0'));
    });

    testWidgets('die Fußnote erklärt den Score und ist keine Diagnose', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final fuss = textUnter(tester, const Key('schlaf-fussnote')).toLowerCase();

      // `CLAUDE.md`: jeder Wert als Schätzung oder Empfehlung gekennzeichnet.
      expect(
        fuss,
        anyOf(contains('schätzung'), contains('keine medizinische')),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Blättern
  // ───────────────────────────────────────────────────────────────────────

  group('Blättern über die geladenen Nächte', () {
    testWidgets('die Leiste trägt beide Pfeile und steht immer da', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-blaetterleiste')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-frueher')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-spaeter')), findsOneWidget);
    });

    testWidgets('die Leiste nennt immer die Nacht, auch die letzte', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      // 12.10.2026 — das Datum der gezeigten Nacht steht in der Leiste.
      expect(textUnter(tester, const Key('schlaf-blaetterleiste')), contains('12'));
    });

    testWidgets('‹ zeigt die Nacht davor', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets('und › wieder zurück', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schlaf-spaeter')));
      await tester.pumpAndSettle();

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets(
      'auf der letzten Nacht ist › aus — am Rand stößt es an, statt ins '
      'Leere zu laufen',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(knopfAktiv(tester, const Key('schlaf-spaeter')), isFalse);
        expect(knopfAktiv(tester, const Key('schlaf-frueher')), isTrue);
      },
    );

    testWidgets('am Anfang des gelesenen Zeitraums ist ‹ aus', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          reihe(anzahl: 2),
          stand: jetzt,
          laeuft: false,
        ),
        fensterBeginn: reihe(anzahl: 2).first.date,
      );
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();

      expect(knopfAktiv(tester, const Key('schlaf-frueher')), isFalse);
      expect(knopfAktiv(tester, const Key('schlaf-spaeter')), isTrue);
    });

    testWidgets('mit einem einzigen Tag im Zeitraum sind beide aus', (
      tester,
    ) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          reihe(anzahl: 1),
          stand: jetzt,
          laeuft: false,
        ),
        fensterBeginn: reihe(anzahl: 1).first.date,
      );
      await zeige(tester, h.app);

      expect(knopfAktiv(tester, const Key('schlaf-frueher')), isFalse);
      expect(knopfAktiv(tester, const Key('schlaf-spaeter')), isFalse);
    });

    testWidgets(
      'die gewählte Nacht überlebt das Verlassen des Schirms nicht — sonst '
      'landet man beim Wiederkommen unerklärt auf einer alten Nacht '
      '(Entscheidung 3 vom 13.10.2026)',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();
        expect(gezeigteNacht(h.container), tagesbeginn(11));

        // Den Schirm verlassen …
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: const CupertinoApp(home: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(Duration.zero);

        // … und wiederkommen.
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(gezeigteNacht(h.container), tagesbeginn(12));
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Verlauf und Statistiken bleiben auf heute bezogen
  // ───────────────────────────────────────────────────────────────────────

  group('Diagramm und Statistiken beziehen sich auf heute', () {
    testWidgets('auf der letzten Nacht steht kein Hinweis — es gäbe keinen', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-verlauf')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-verlauf-hinweis')), findsNothing);
    });

    testWidgets(
      'steht oben eine ältere Nacht, sagt der Schirm, worauf sich Verlauf '
      'und Schnitte beziehen',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-verlauf-hinweis')), findsOneWidget);
        expect(
          textUnter(tester, const Key('schlaf-verlauf-hinweis')).toLowerCase(),
          contains('heute'),
        );
      },
    );

    testWidgets(
      'die Statistiken ändern beim Blättern keine Zahl — sonst ändern sich '
      'Werte, die niemand gesucht hat',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final vorher7 = textUnter(tester, const Key('schlaf-statistik-7'));
        final vorher30 = textUnter(tester, const Key('schlaf-statistik-30'));

        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();

        expect(textUnter(tester, const Key('schlaf-statistik-7')), vorher7);
        expect(textUnter(tester, const Key('schlaf-statistik-30')), vorher30);
      },
    );

    testWidgets(
      'die beiden Statistikblöcke sagen selbst, dass sie bis heute laufen',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          textUnter(tester, const Key('schlaf-statistik-7')).toLowerCase(),
          contains('heute'),
        );
        expect(
          textUnter(tester, const Key('schlaf-statistik-30')).toLowerCase(),
          contains('heute'),
        );
      },
    );

    testWidgets(
      'gibt es kein zirkuläres Mittel, steht ein Gedankenstrich und keine '
      'erfundene Uhrzeit — und nie 0:00',
      (tester) async {
        final h = harness(
          zustand: handZustand(
            statistik7: const SchlafStatistik(
              naechte: 7,
              schlafMinuten: 400,
              einschlafMinuten: null,
              aufwachMinuten: null,
              anteile: {},
            ),
            statistik30: const SchlafStatistik(
              naechte: 30,
              schlafMinuten: 400,
              einschlafMinuten: null,
              aufwachMinuten: null,
              anteile: {},
            ),
          ),
        );
        await zeige(tester, h.app);

        // Zugeklappt seit #253 — „Ø Einschlafen" steht im Rumpf.
        await tester.tap(find.byKey(const Key('schlaf-statistik-7-kopf')));
        await tester.pumpAndSettle();

        final block = textUnter(tester, const Key('schlaf-statistik-7'));

        expect(block, contains('—'));
        expect(block, isNot(contains('0:00')));
        expect(block, isNot(contains('00:00')));
      },
    );

    testWidgets('ohne Statistik fehlt der Block ganz, statt Nullen zu zeigen', (
      tester,
    ) async {
      final h = harness(
        zustand: handZustand(statistik7: null, statistik30: null),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-statistik-7')), findsNothing);
      expect(find.byKey(const Key('schlaf-statistik-30')), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Tagschlaf
  // ───────────────────────────────────────────────────────────────────────

  group('Tagschlaf ist eine Tür, kein Abschnitt', () {
    testWidgets('ohne Nickerchen gibt es die Zeile nicht', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-tagschlaf')), findsNothing);
    });

    testWidgets('mit Nickerchen schon', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          reiheMitNickerchen(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-tagschlaf')), findsOneWidget);
    });

    testWidgets(
      'und sie führt auf den Tagschlaf-Schirm, nicht tiefer in die Nacht',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            reiheMitNickerchen(),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-tagschlaf')));
        await tester.pumpAndSettle();

        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(home: Builder(builder: befehl!.builder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TagschlafSeite), findsOneWidget);
      },
    );

    testWidgets(
      'die Dauer der Nacht enthält den Tagschlaf nicht — dieselbe Nacht mit '
      'und ohne Nickerchen zeigt denselben Score',
      (tester) async {
        final ohne = harness();
        await zeige(tester, ohne.app);
        final scoreOhne = tester
            .widget<SegmentRing>(find.byType(SegmentRing))
            .mitte;

        final mit = harness(
          schlaf: Bekannt<List<SleepNight>>(
            reiheMitNickerchen(),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, mit.app);
        final scoreMit = tester
            .widget<SegmentRing>(find.byType(SegmentRing))
            .mitte;

        expect(scoreMit, scoreOhne);

        // Zwei Container in einem Fall — siehe [raeumeAb] und den Dateikopf.
        await raeumeAb(tester);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Hypnogramm, Puls, Atmung
  // ───────────────────────────────────────────────────────────────────────

  group('Schlafphasen', () {
    testWidgets('das Hypnogramm steht in voller Fassung, mit Spurnamen', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final hypnogramm = tester.widget<Hypnogramm>(
        find.descendant(
          of: find.byKey(const Key('schlaf-phasen')),
          matching: find.byType(Hypnogramm),
        ),
      );

      expect(hypnogramm.kompakt, isFalse);
    });

    testWidgets('es zeigt die gezeigte Nacht, nicht immer die letzte', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();

      final hypnogramm = tester.widget<Hypnogramm>(
        find.descendant(
          of: find.byKey(const Key('schlaf-phasen')),
          matching: find.byType(Hypnogramm),
        ),
      );

      expect(
        hypnogramm.session.segments.first.start,
        nachtVon(11).session.segments.first.start,
      );
    });
  });

  group('Puls und Atmung im Schlaf', () {
    testWidgets(
      'solange die Spannen geladen werden, steht ein Ladezeiger — nicht '
      '„nichts gemessen", das wäre eine andere Aussage',
      (tester) async {
        final quelle = _FakeHealthReading(haengt: true);
        final h = harness(quelle: quelle);
        await tester.pumpWidget(h.app);
        await tester.pump();

        expect(find.byKey(const Key('schlaf-puls')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-atmung')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('schlaf-puls')),
            matching: find.byType(CupertinoActivityIndicator),
          ),
          findsOneWidget,
        );

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('nichts gemessen')));
        expect(texte, isNot(contains('nicht gemessen')));

        quelle.loese();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'liegt nach dem Lauf nichts vor, werden beide Möglichkeiten genannt',
      (tester) async {
        final h = harness(quelle: _FakeHealthReading(messungen: const []));
        await zeige(tester, h.app);

        final puls = textUnter(tester, const Key('schlaf-puls')).toLowerCase();

        expect(puls, contains('aufgezeichnet'));
        expect(puls, contains('freigegeben'));
      },
    );

    testWidgets('mit Messungen stehen Spannen da', (tester) async {
      final h = harness(
        quelle: _FakeHealthReading(
          messungen: [
            for (var i = 0; i < 20; i++)
              QuantitySample(
                date: berlin(11, 23).add(Duration(minutes: 20 * i)),
                value: 50 + (i % 7).toDouble(),
              ),
          ],
        ),
      );
      await zeige(tester, h.app);

      final puls = textUnter(tester, const Key('schlaf-puls')).toLowerCase();

      expect(puls, isNot(contains('aufgezeichnet')));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Kalenderblatt
  // ───────────────────────────────────────────────────────────────────────

  group('Das Kalenderblatt', () {
    testWidgets('sitzt als Knopf in der Navigationsleiste', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-kalender-knopf')), findsOneWidget);
    });

    testWidgets('und öffnet das Monatsraster', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-kalenderblatt')), findsOneWidget);
    });

    testWidgets('ein Tag mit Nacht ist tippbar, wählt sie und schließt', (
      tester,
    ) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schlaf-kalender-tag-2026-10-09')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-kalenderblatt')), findsNothing);
      expect(gezeigteNacht(h.container), tagesbeginn(9));
    });

    testWidgets(
      'ein Tag ohne Nacht im gelesenen Zeitraum ist tippbar und wählt ihn — '
      'seit #177, und ohne das ist die Eingabe von Hand (#131) für genau '
      'den Fall unerreichbar, für den es sie gibt',
      (tester) async {
        // Die Reihe lässt den 08.10. aus.
        final naechte = [
          for (final tag in [5, 6, 7, 9, 10, 11, 12]) nachtVon(tag),
        ];
        final h = harness(
          mitSeite: true,
          schlaf: Bekannt<List<SleepNight>>(
            naechte,
            stand: jetzt,
            laeuft: false,
          ),
          fensterBeginn: naechte.first.date,
        );
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('schlaf-kalender-tag-2026-10-08')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-kalenderblatt')), findsNothing);
        expect(
          h.container.read(schlafAuswahlProvider),
          tagesbeginn(8),
          reason:
              'Der 8. liegt im gelesenen Zeitraum und hat keine Nacht. '
              'Genau dafür gibt es seit #177 die Tür.',
        );
      },
    );

    testWidgets(
      'ein Tag außerhalb des gelesenen Zeitraums bleibt stumm — dort hat '
      'niemand nachgesehen, und das ist nicht dasselbe wie „nachgesehen '
      'und nichts gefunden"',
      (tester) async {
        final naechte = [
          for (final tag in [5, 6, 7, 9, 10, 11, 12]) nachtVon(tag),
        ];
        final h = harness(
          mitSeite: true,
          schlaf: Bekannt<List<SleepNight>>(
            naechte,
            stand: jetzt,
            laeuft: false,
          ),
          fensterBeginn: naechte.first.date,
        );
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('schlaf-kalender-tag-2026-10-02')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(h.container.read(schlafAuswahlProvider), isNull);
        expect(find.byKey(const Key('schlaf-kalenderblatt')), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Regel vom Entwurfsboard
  // ───────────────────────────────────────────────────────────────────────

  group('Kein Chevron ohne Tür', () {
    testWidgets(
      'jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren — die '
      'Regel, die pruefen.mjs am Board durchsetzt',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            reiheMitNickerchen(),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final pfeile = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
        );
        for (final element in pfeile.evaluate()) {
          expect(
            tippbar(element),
            isTrue,
            reason: 'ein Chevron ohne Tür dahinter',
          );
        }

        final pfeilTexte = find.byWidgetPredicate(
          (w) => w is Text && textOf(w).contains('›'),
        );
        for (final element in pfeilTexte.evaluate()) {
          expect(
            tippbar(element),
            isTrue,
            reason: 'ein Pfeil-Zeichen ohne Tür dahinter',
          );
        }
      },
    );
  });
}

/// Steuerbarer Ableger des echten Notifiers.
class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

/// Eine Quelle, die nur [quantitySamples] beantwortet — mehr braucht der
/// Schlaf-Schirm vom Kanal nicht. Mit `haengt: true` antwortet sie gar
/// nicht, bis [loese] gerufen wird; so lässt sich der Ladezustand der
/// Spannen prüfen, ohne auf eine Zeitschranke zu warten.
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading({this.messungen = const [], this.haengt = false});

  final List<QuantitySample> messungen;
  final bool haengt;
  final Completer<void> _tor = Completer<void>();

  void loese() {
    if (!_tor.isCompleted) _tor.complete();
  }

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    if (haengt) await _tor.future;
    return messungen
        .where((m) => !m.date.isBefore(from) && !m.date.isAfter(through))
        .toList();
  }
}
