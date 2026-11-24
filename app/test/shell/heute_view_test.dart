import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/grosse_ueberschrift.dart';
import 'package:repit/design/hinweisfuss.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/design/stand_zeile.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';

import '../design/support.dart' show textOf;

/// Tests für `HeuteView` (`lib/shell/heute_view.dart`) — der erste Schirm,
/// der echte Zahlen aus Apple Health zeigt. Entwurf: `docs/screens/screens/
/// heute-kombi.js` (siehe dessen Kommentarkopf für die Begründung, warum
/// die Ringe mit Rest- statt Standbeschriftung den Schirm tragen, nicht die
/// Energiebilanz).
///
/// ## Festgelegte API
///
/// - `class HeuteView extends ConsumerWidget` in
///   `app/lib/shell/heute_view.dart`, Konstruktor `const HeuteView({super.key})`.
///   **Bringt keinen eigenen `CupertinoPageScaffold`/`NavigationBar` mit**
///   (Hausregel „eine gepushte Ansicht bringt niemals ihren eigenen
///   Navigationsstapel/-rahmen mit", parallel zu `PlatzhalterTab`) — der
///   Host (`RootView`, Wiring folgt in einer späteren Aufgabe, siehe unten)
///   stellt Scaffold und Leiste. Dieser Test stellt beides selbst (`huelle`
///   unten).
/// - Top-Level-Funktion `heuteZustandAusProvider` im selben File, siehe
///   `heute_zustand_test.dart` für ihre eigene Testfläche.
/// - Schlüssel für die Hinweise, weil es für sie (anders als bei
///   `VitalWert.hinweis`, das ein eigenes Feld hat) keine strukturierte
///   Stelle im Baukasten gibt, an der sich „sagt, dass es fehlt" sonst
///   zweifelsfrei wiederfinden ließe:
///   - `Key('heute-offen-hinweis')` und `Key('heute-erledigt-hinweis')`
///     gibt es seit #376 **nicht mehr** (siehe „Vierte Fassung" unten)
///   - `Key('heute-ernaehrung-hinweis')` und `Key('heute-makros-hinweis')`
///     gibt es seit #358 **nicht mehr**
///   Jeder Schlüssel sitzt auf einem **Vorfahren** des erklärenden Textes
///   (z. B. `Padding`/`Column`), nicht auf dem `Text` selbst — die Tests
///   suchen über `find.descendant`.
///
/// ## Der Zuschnitt, den diese Tests festnageln (Auftrag, Tabelle)
///
/// | Block | Daten | Was er tut |
/// |---|---|---|
/// | Ringe | Trainingsring aus `exerciseMinutes` | echte Zahlen |
/// | Ringe | Kalorien, Eiweiß (seit #358) | echte Zahlen, geprüft in `heute_ernaehrung_test.dart` |
/// | Erholung | Schlaf, Ruhepuls, HRV, Atemfrequenz | echte Zahlen |
/// | Zahlen | Schritte, Gewicht | echte Zahlen |
/// | Heute Training | die heutige Einheit (seit #501) | geprüft in `heute_training_test.dart` |
/// | Makros | seit #376 nicht mehr auf Home | geprüft in `heute_ernaehrung_test.dart` |
///
/// Daraus: **genau drei** `RingZiel` in `Ringe.ziele` — Kalorien, Eiweiß,
/// Training, in dieser Reihenfolge (`RINGE` in `heute-kombi.js`). Bis #358
/// stand hier „genau ein" Ring und „`MakroBalken` und `IconRow` kommen
/// nirgends vor"; beides war die Zusicherung, dass nichts Erfundenes auf
/// dem Schirm steht, solange die Ernährung nicht angebunden war. Was die
/// beiden neuen Ringe, die Mahlzeiten und die Makros zeigen, prüft
/// `heute_ernaehrung_test.dart`; diese Datei prüft nur noch, dass sie in
/// jedem Zustand **stehen** und keine Zahl behaupten, die es nicht gibt.
///
/// ## Zahlen in dieser Datei
///
/// Ausschließlich erfunden, keine aus `docs/sample_export.json`/`docs/
/// SPEC.md` Abschnitt 1. Schritte bewusst < 1000 (`842`), damit ein
/// eventuelles Tausendertrennzeichen den im Test verwendeten
/// Nur-Ziffern-Vergleich nicht verfälscht. Das Trainingsring-Ziel `30` (Min.)
/// ist **keine** personenbezogene Kennzahl, sondern der in `docs/SPEC.md`
/// Abschnitt 3 dokumentierte Apple-Watch-Standardwert für den Trainierenring
/// („Trainieren 30 min") — wörtlich wie in `heute-kombi.js`s eigenem
/// fiktiven Beispiel.
///
/// ## Wie „heute" im Datensatz gefunden wird — bewusst nicht festgelegt
///
/// `Bekannt<List<DailyMetrics>>.wert` ist eine Liste über mehrere Tage.
/// Ob `HeuteView` „heute" darin per Tag-Abgleich gegen `clockProvider`
/// (wie `BodyStore.swift`: `metrics.first { ... == today }`) oder einfach
/// als letztes Element der Liste findet, legen diese Tests **nicht** fest
/// — die Fixtures unten machen beide Strategien ununterscheidbar richtig:
/// der passende Eintrag ist zugleich der letzte in der Liste **und** der
/// einzige, dessen `tag` zum über `clockProvider` injizierten `jetzt` passt.
///
/// ## Was ein Widget-Test hier nicht prüft (CLAUDE.md)
///
/// Layout und genauer Wortlaut. Wo eine Aussage („sagt, dass X fehlt")
/// geprüft wird, über lose Stichwort-Treffer (klein geschrieben, per
/// `contains`), nie über einen exakten Satz.
///
/// **Eine begründete Ausnahme seit der zweiten Fassung (s. u.):** Zwei
/// Fälle messen tatsächlich Geometrie („die Breite springt nicht", „der
/// Ring steht beim Laden an derselben Stelle"). Das ist hier kein Layouttest
/// aus Langeweile, sondern der einzige beobachtbare Gehalt zweier
/// Entscheidungen der Spec (Ziel 1/3 und „Die Stand-Zeile reserviert ihre
/// Höhe"): Ohne sie ließe sich „dieselbe Form" behaupten, ohne sie zu
/// liefern. Gemessen wird nur, was nicht von Schriftmetrik abhängt —
/// Spaltenbreite und die Höhe **einer** reservierten Zeile, beides im
/// selben Lauf gegen den Normalfall verglichen, nie gegen eine feste Zahl.
///
/// ## Zweite Fassung — „Eine Anzeige, die es gibt, hat genau eine Form"
///
/// Spec: `docs/superpowers/specs/2026-10-28-leerzustaende-design.md`
/// (Ticket #137, Entwurf von Tim am 28.10.2026 freigegeben), Entwurf:
/// `docs/screens/screens/heute-kombi.js`, Zustände „Keine Werte", „Teils
/// Werte", „Lädt (ohne Puls)". Regel seitdem auch in `CLAUDE.md`.
///
/// Drei Fälle dieser Datei behaupteten das Gegenteil der neuen Anforderung
/// und sind deshalb neu geschrieben — nicht ergänzt, sondern ersetzt, weil
/// ein Test, der die überholte Regel verteidigt, schlimmer ist als keiner:
///
/// 1. „ohne Cache-Treffer: nur ein Ladehinweis, keine Blöcke" prüfte für
///    `NochNie` `findsNothing` auf `Ringe`, `Kacheln` und `ErholungsKarte`.
///    Richtig, solange der Ladezustand ein nackter Satz war; die Spec
///    verlangt jetzt dasselbe Gerüst wie im Normalfall.
/// 2. „nach einem fertigen Lauf ohne Treffer…" prüfte dasselbe für
///    `LeerNachLauf`. Auch dort steht das Gerüst jetzt (Tim, 28.10.2026 —
///    der wahrscheinlichste „nichts da"-Fall überhaupt).
/// 3. „fehlende Trainingsminuten … erzeugen keinen erfundenen Null-Ring"
///    war tolerant formuliert (`if (ringeFinder.evaluate().isNotEmpty)`)
///    und wäre auch dann grün geblieben, wenn der Ring ganz verschwindet —
///    also genau im Fehlerfall. Jetzt fordert er die Anzeige ein.
///
/// `find.byType(StandZeile)` bleibt in `NochNie`/`LeerNachLauf` bei
/// `findsNothing`, und das ist kein Versehen: `StandZeile` nimmt per Typ
/// ein `Bekannt` entgegen und hat ohne Daten nichts zu sagen. Was die Spec
/// dort verlangt, ist ein **Platzhalter ihrer Höhe** — geprüft über die
/// Lage des Rings, nicht über den Bausteintyp.
///
/// ## Dritte Fassung — #358, die Ernährung kommt auf Home
///
/// **Tims Auftrag vom 04.11.2026** (Issue #358): „Auf Home die Ernährung
/// einbauen, damit das Thema erledigt ist." Drei Hinweise dieser Datei
/// behaupteten das Gegenteil und sind deshalb umgestellt, nicht ergänzt:
///
/// 1. `_geruestSteht` verlangte **genau einen** Ring (Training). Jetzt
///    verlangt es die drei aus dem Entwurf — in jedem Zustand, denn eine
///    Anzeige, die es gibt, hat genau eine Form.
/// 2. „bei bekannten Werten …" verlangte `heute-ernaehrung-hinweis`,
///    `heute-makros-hinweis` und `heute-offen-hinweis` mit „nicht", dazu
///    `findsNothing` für `MakroBalken` und `IconRow`. Die beiden ersten
///    Hinweise müssen jetzt **fehlen**; der dritte bleibt, spricht aber
///    nur noch von den Einheiten. Die beiden `findsNothing` entfallen.
/// 3. „ein Nachladen … zeigt KEINEN Platzhalter" suchte `–/–` in der
///    ganzen Ringlegende. Der Kalorienring dieser Hülle hat kein Ziel (die
///    Stammdaten sind leer) und sagt dort zu Recht `–/–`; die Zusicherung
///    galt dem Trainingsring und prüft jetzt nur ihn.
///
/// Die Hülle bekommt dafür eine **echte, leere Datenbank im Speicher**
/// (`appCacheProvider`), wie `root_view_test.dart` sie begründet: Ohne sie
/// verschwände der Wurf von `appCacheProvider` lautlos in einem
/// `AsyncError`, und die Ernährungsanzeigen stünden in einem
/// Fehlerzustand da, ohne dass ein Fall es merkt.
///
/// ## Vierte Fassung — #376, Home wird aufgeräumt
///
/// **Tims Entscheidung vom 05.11.2026** (Issue #376): „Makros auf Home
/// entfernen — der Ring oben gibt genug Infos." Und der Hinweis zu den
/// Trainingseinheiten kommt weg: „sieht hässlich aus, Tim weiß es."
/// Umgestellt, nicht ergänzt:
///
/// 1. „bei bekannten Werten …" verlangte `heute-offen-hinweis` mit „nicht".
///    Jetzt muss er **fehlen**.
/// 2. Beide Abschnittslisten verlangten „Makros" zwischen „Heute noch
///    offen" und „Erholung". Der Abschnitt ist weg.
///
/// Was an seine Stelle tritt („Nichts mehr offen") und dass die Karten den
/// gemeinsamen Baustein tragen, prüft `heute_ernaehrung_test.dart`.
///
/// ## Woran diese Tests bewusst nicht rühren
///
/// - **Wie `RingZiel`/`KachelWert` „kein Wert" ausdrücken.** Die Spec lässt
///   das offen (nullbares Feld, eigener Typ, benannter Konstruktor); ein
///   Test, der eine der drei Formen liest, entschiede sie. Werte werden
///   deshalb **am gezeichneten Text** geprüft und über die Spaltenlage der
///   Kachel zugeordnet (`_kachelTexte`) — damit erfüllt dieselbe Prüfung
///   auch die Forderung der Spec, dass „irgendwo steht `–/–`" nicht reicht:
///   Die Anzeige muss an **ihrer** Stelle stehen.
/// - **Der Wortlaut des Ladezustands.** Der Satz „Noch keine Werte · wird
///   geladen" war an das alte Verhalten gebunden; ob er neben dem Gerüst
///   bestehen bleibt, sagt die Spec nicht, also fordert ihn hier niemand
///   mehr ein. Was bleibt, ist die Hausregel aus `CLAUDE.md`: **während des
///   Ladens steht nie ein „keine Daten"-Grund** (Fehler `01`).
/// - **Die Pulsation.** Ausdrückliches Nicht-Ziel der Spec (#24).
/// - **Ob im Ladezustand ein unsichtbarer Beispieltext die Platzhalterbreite
///   erzeugt.** Die Spec verlangt die Breite „aus einem Beispieltext in
///   derselben Schrift" — ein solcher Text trägt Ziffern, die niemand sieht.
///   Deshalb prüft `NochNie` hier **keine** Ziffern-Abwesenheit; das tun die
///   Zustände, in denen ein Wert tatsächlich gelesen wurde und fehlt.
///
/// ## Was diese Datei NICHT prüft
///
/// - Dass `HeuteView` tatsächlich im Heute-Tab von `RootView` hängt. Die
///   Tableiste ist laut `progress.md` gerade in Überarbeitung bei Tim
///   ("BLOCKED... Tableiste... Tab 10/11 müssen nachgezogen werden") — das
///   Verdrahten ist deshalb ausdrücklich **nicht** Teil dieses Tasks.
/// - Die Cache-zuerst-dann-Kanal-Logik selbst (Reihenfolge, Wiederholungen,
///   Zurückschreiben) — die hat `health_provider_test.dart` (Task 13)
///   bereits abgedeckt. Diese Datei testet nur, wie der Schirm auf eine
///   gegebene Zustandsfolge reagiert, nicht, wie die Folge zustande kommt.
void main() {
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);
  const heute = '2026-10-20';
  const gestern = '2026-10-19';
  const vorgestern = '2026-10-18';

  final tageswerte = <DailyMetrics>[
    const DailyMetrics(tag: gestern, steps: 500, exerciseMinutes: 10),
    const DailyMetrics(
      tag: heute,
      steps: 842,
      restingHR: 55,
      hrvMs: 70.0,
      respRate: 14.0,
      weightKg: 58.4,
      exerciseMinutes: 18.0,
    ),
  ];

  /// Zwei Tage, an denen Apple Health nichts geliefert hat — ein `Bekannt`
  /// mit durchweg leeren Feldern. Laut Spec der Normalfall, kein
  /// Widerspruch zu `Messwert<T>`: Die vier Zustände beschreiben den
  /// **Lauf**, die nullbaren Felder das **einzelne Feld**.
  final ohneWerte = <DailyMetrics>[
    const DailyMetrics(tag: gestern),
    const DailyMetrics(tag: heute),
  ];

  /// Tim wiegt sich nicht täglich: Gewicht nur vorgestern, Schritte nur
  /// vorgestern und gestern, heute beides leer. Zahlen erfunden.
  final nurAeltereWerte = <DailyMetrics>[
    const DailyMetrics(tag: vorgestern, steps: 311, weightKg: 57.2),
    const DailyMetrics(tag: gestern, steps: 404),
    const DailyMetrics(tag: heute, exerciseMinutes: 18.0),
  ];

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.** Der Zustand wandert mit — ein gescheiterter Tageslauf
  /// bedeutet hier auch einen gescheiterten Nachtlauf.
  Messwert<Map<String, NightVitals>> nachtwerteAus(
    Messwert<List<DailyMetrics>> tageswerte,
  ) => switch (tageswerte) {
    Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in wert)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: stand, laeuft: laeuft),
    NochNie<List<DailyMetrics>>() => const NochNie<Map<String, NightVitals>>(),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
      LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<Map<String, NightVitals>>(
        fehler: fehler,
        gelaufen: gelaufen,
      ),
  };

  ({ProviderContainer container, Widget app}) harness({
    required DailyMetricsNotifier Function() notifier,
    Messwert<Map<String, NightVitals>> nachtwerte =
        const NochNie<Map<String, NightVitals>>(),
  }) {
    // #358: Kalorien, Eiweiß und Mahlzeiten lesen Tims eigene Einträge und
    // Stammdaten aus der Datenbank — eine echte, leere im Speicher statt
    // eines lautlosen `AsyncError` (siehe Dateikopf, „Dritte Fassung").
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        dailyMetricsProvider.overrideWith(notifier),
        clockProvider.overrideWithValue(() => jetzt),
        // Seit dem 27.10.2026 holt sich die Erholungskarte ihre Werte aus
        // demselben Zustand wie der Erholung-Schirm (siehe
        // `heute_erholungskarte_test.dart`) — und der liest Schlaf, Ziele
        // und Tagesgefühl mit. Ohne diese drei Überschreibungen liefe ein
        // Widget-Test in die echte drift-Datenbank.
        sleepProvider.overrideWith(_KeineNaechte.new),
        zieleProvider.overrideWith(_Ziele.new),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster. Der Vorgabewert `NochNie` ist der Ladezustand —
        // genau der, den die Gruppe „während des Ladens" braucht.
        nachtWerteProvider.overrideWith(() => _Nachtwerte(nachtwerte)),
      ],
    );
    final app = UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(
        home: CupertinoPageScaffold(child: HeuteView()),
      ),
    );
    return (container: container, app: app);
  }

  /// Ein `Bekannt` mit den übergebenen Tagen, fertig gelaufen.
  ({ProviderContainer container, Widget app}) mitWerten(
    List<DailyMetrics> werte,
  ) => harness(
    notifier: () => _GesteuerterNotifier(
      endwert: () async =>
          Bekannt<List<DailyMetrics>>(werte, stand: jetzt, laeuft: false),
    ),
    nachtwerte: nachtwerteAus(
      Bekannt<List<DailyMetrics>>(werte, stand: jetzt, laeuft: false),
    ),
  );

  group('während des Ladens steht nirgends eine Zahl, die es nicht gibt', () {
    testWidgets('ohne Cache-Treffer steht das Gerüst — dieselben Anzeigen an '
        'denselben Stellen, nur ungefüllt, und kein "keine Daten"-Grund', (
      tester,
    ) async {
      final nieFertig = Completer<Messwert<List<DailyMetrics>>>();
      final h = harness(
        notifier: () => _GesteuerterNotifier(endwert: () => nieFertig.future),
      );
      addTearDown(h.container.dispose);
      addTearDown(() {
        if (!nieFertig.isCompleted) {
          nieFertig.complete(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
        }
      });

      await tester.pumpWidget(h.app);
      await tester.pump();

      _geruestSteht(tester, zustand: 'NochNie');

      expect(
        find.byType(StandZeile),
        findsNothing,
        reason:
            'StandZeile nimmt per Typ ein Bekannt entgegen und hat '
            'ohne Daten keinen Stand zu nennen — die Spec verlangt hier '
            'einen Platzhalter ihrer HÖHE, nicht den Baustein selbst. '
            'Geprüft wird die Höhe im Fall "der Ring steht beim Laden an '
            'derselben Stelle"',
      );
      expect(
        find.textContaining('aufgezeichnet'),
        findsNothing,
        reason:
            'der "keine Daten"-Grund gehört nur zu einem FERTIGEN Lauf '
            'ohne Treffer (LeerNachLauf/Fehlgeschlagen), nicht zum Laden '
            '— das ist Fehler 01 aus CLAUDE.md',
      );
      expect(
        _alleTexte(tester).join(' ').toLowerCase(),
        isNot(contains('zugriff')),
        reason:
            'dasselbe von der anderen Seite: auch die zweite der '
            'beiden Möglichkeiten (kein Lesezugriff) ist während des '
            'Laufs keine Aussage, die jemand treffen kann',
      );
    });

    testWidgets(
      'mit Cache-Treffer bleibt der alte Wert stehen und nennt "wird '
      'aktualisiert" — danach verschwindet nur der Lauf-Hinweis, der Wert '
      'bleibt (Tims ursprüngliche Beschwerde, nie wieder NochNie dazwischen)',
      (tester) async {
        final cacheStand = DateTime.utc(2026, 10, 20, 9, 0);
        final zwischenwert = Bekannt<List<DailyMetrics>>(
          tageswerte,
          stand: cacheStand,
          laeuft: true,
        );
        final kanalAntwort = Completer<Messwert<List<DailyMetrics>>>();

        final beobachtet = <Messwert<List<DailyMetrics>>>[];
        final h = harness(
          notifier: () => _GesteuerterNotifier(
            zwischenwert: zwischenwert,
            endwert: () => kanalAntwort.future,
          ),
        );
        addTearDown(h.container.dispose);
        h.container.listen(
          dailyMetricsProvider,
          (previous, next) => beobachtet.add(heuteZustandAusProvider(next)),
          fireImmediately: true,
        );

        await tester.pumpWidget(h.app);
        await tester.pump();

        // Die Stand-Zeile ist seit #514 nicht mehr auf Home; denselben
        // Übergang trägt der beobachtete Provider-Zustand.
        var stand = beobachtet.last as Bekannt<List<DailyMetrics>>;
        expect(stand.laeuft, isTrue);
        expect(stand.stand, cacheStand);

        final schritteWaehrendLauf = _kachelWert(tester, 'schritt');
        expect(schritteWaehrendLauf, isNotNull);
        expect(_nurZiffern(schritteWaehrendLauf!), contains('842'));

        kanalAntwort.complete(
          Bekannt<List<DailyMetrics>>(tageswerte, stand: jetzt, laeuft: false),
        );
        await tester.pump();
        await tester.pump();

        stand = beobachtet.last as Bekannt<List<DailyMetrics>>;
        expect(stand.laeuft, isFalse);
        expect(stand.stand, jetzt);

        final schritteDanach = _kachelWert(tester, 'schritt');
        expect(
          schritteDanach,
          isNotNull,
          reason: 'der Wert, der da stand, ist nie verschwunden',
        );
        expect(_nurZiffern(schritteDanach!), contains('842'));

        expect(
          beobachtet.whereType<NochNie<List<DailyMetrics>>>(),
          isEmpty,
          reason:
              'zwischen Cache-Treffer und Endergebnis darf nie NochNie '
              'aufscheinen — genau das war Tims "zeigt 0" (docs/todo/01)',
        );
      },
    );

    testWidgets('ein Nachladen mit zwischengespeichertem Wert zeigt KEINEN '
        'Platzhalter — der gehört allein in NochNie (zweite Falle der Spec)', (
      tester,
    ) async {
      final kanalAntwort = Completer<Messwert<List<DailyMetrics>>>();
      final h = harness(
        notifier: () => _GesteuerterNotifier(
          zwischenwert: Bekannt<List<DailyMetrics>>(
            tageswerte,
            stand: DateTime.utc(2026, 10, 20, 9, 0),
            laeuft: true,
          ),
          endwert: () => kanalAntwort.future,
        ),
      );
      addTearDown(h.container.dispose);
      addTearDown(() {
        if (!kanalAntwort.isCompleted) {
          kanalAntwort.complete(
            Bekannt<List<DailyMetrics>>(
              tageswerte,
              stand: jetzt,
              laeuft: false,
            ),
          );
        }
      });

      await tester.pumpWidget(h.app);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(Kacheln),
          matching: find.text(_ohneWert),
        ),
        findsNothing,
        reason:
            'beide Kacheln haben einen zwischengespeicherten Wert — '
            'ein aufblitzendes "$_ohneWert" wäre genau der Platzhalter, '
            'den #24 beim Nachladen verbietet',
      );
      // Seit #358 nur der Trainingsring: Kalorien und Eiweiß haben in
      // dieser Hülle kein Ziel (leere Stammdaten) und sagen dort zu Recht
      // `–/–` — das ist kein Platzhalter, sondern ein gelesener Leerstand.
      final training = tester
          .widget<Ringe>(find.byType(Ringe))
          .ziele
          .firstWhere((z) => z.label == 'Training');
      expect(
        training.wert,
        isNotNull,
        reason: 'dasselbe für den Trainingsring',
      );
      expect(
        training.text,
        isNot(_ohneWert),
        reason: 'dasselbe für den Trainingsring',
      );
    });
  });

  testWidgets(
    'nach einem fertigen Lauf ohne Treffer steht das Gerüst, und der Grund '
    'steht EINMAL darüber statt in jedem Feld',
    (tester) async {
      final h = harness(
        notifier: () => _GesteuerterNotifier(
          endwert: () async =>
              LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        ),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      _geruestSteht(tester, zustand: 'LeerNachLauf');

      expect(
        find.byType(StandZeile),
        findsNothing,
        reason:
            'ein ergebnisloser Lauf hat keinen Stand zu nennen — nur '
            'eine reservierte Höhe (siehe Dateikopf)',
      );

      // --- Beide Möglichkeiten, die Apple nicht unterscheidet. ---
      final alleTexte = _alleTexte(tester).join(' ').toLowerCase();
      expect(
        alleTexte,
        contains('aufgezeichnet'),
        reason: 'erste Möglichkeit: nichts aufgezeichnet',
      );
      expect(
        alleTexte.contains('zugriff') || alleTexte.contains('freigegeben'),
        isTrue,
        reason:
            'zweite Möglichkeit: kein Lesezugriff/nicht freigegeben — '
            'beide müssen genannt werden, nicht nur eine',
      );

      // --- Der Grund steht ÜBER dem Gerüst, nicht in den Feldern. ---
      final ringOben = tester.getTopLeft(find.byType(Ringe)).dy;
      final grundUeberDemGeruest = find
          .textContaining('aufgezeichnet')
          .evaluate()
          .any((element) => _obenVon(tester, element) < ringOben);
      expect(
        grundUeberDemGeruest,
        isTrue,
        reason:
            'die Spec: "Der Grund … steht dann als Zeile ÜBER dem '
            'Gerüst, nicht in jedem einzelnen Feld" — sonst wächst der '
            'Schirm genau dann, wenn Werte fehlen',
      );

      // --- Und in den Feldern steht das Zeichen, keine Zahl. ---
      for (final kachel in const ['schritt', 'gewicht']) {
        expect(
          _kachelWert(tester, kachel),
          _ohneWert,
          reason:
              'die Kachel "$kachel" bleibt stehen und sagt, dass sie '
              'keinen Wert hat — statt zu verschwinden oder 0 zu behaupten',
        );
      }
      _ringLegendeOhneZahl(tester);
    },
  );

  testWidgets(
    'bei bekannten Werten: Trainingsring rechnet den Rest, die Ernährung '
    'steht ohne Hinweis da, nur die Einheiten sagen, dass sie fehlen',
    (tester) async {
      final h = mitWerten(tageswerte);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      // --- Ringe: drei Ringe (#358), Training rechnet den Rest. ---
      expect(find.byType(Ringe), findsOneWidget);
      final ringe = tester.widget<Ringe>(find.byType(Ringe));
      expect(
        ringe.ziele.map((z) => z.label).toList(),
        ['Kalorien', 'Eiweiß', 'Training'],
        reason: '`RINGE` in heute-kombi.js — seit #358 angebunden',
      );
      final training = ringe.ziele.firstWhere((z) => z.label == 'Training');
      expect(training.wert, 18.0, reason: 'echte Zahl aus exerciseMinutes');
      expect(
        training.ziel,
        30.0,
        reason: 'SPEC Abschnitt 3 / Apple-Watch-Standard: Trainieren 30 min',
      );
      expect(
        training.text,
        contains('12'),
        reason: 'Rest (30-18=12), nicht der Stand',
      );
      expect(
        training.text,
        isNot(contains('18')),
        reason:
            'der Stand (18) darf nicht als Beschriftung erscheinen — '
            'das wäre "noch 1.620 von 1.800" statt "noch 180 kcal"',
      );

      // --- Ernährung angebunden (#358): kein Hinweis mehr. ---
      expect(
        find.byKey(const Key('heute-ernaehrung-hinweis')),
        findsNothing,
        reason: '„Ernährung ist noch nicht angebunden" stimmt seit #358 '
            'nicht mehr — eine Zusage, die nicht mehr stimmt, bleibt nicht '
            'stehen (CLAUDE.md)',
      );

      // --- Erholung: HRV/Ruhepuls/Atmung echt, Schlaf fehlt mit Grund. ---
      expect(find.byType(ErholungsKarte), findsOneWidget);
      final erholung = tester.widget<ErholungsKarte>(
        find.byType(ErholungsKarte),
      );
      VitalWert finde(String teil) => erholung.vitalwerte.firstWhere(
        (v) => v.name.toLowerCase().contains(teil),
        orElse: () => throw StateError('kein Vitalwert enthält "$teil"'),
      );
      expect(_nurZiffern(finde('hrv').wert ?? ''), contains('70'));
      expect(_nurZiffern(finde('puls').wert ?? ''), contains('55'));
      expect(_nurZiffern(finde('atem').wert ?? ''), contains('14'));
      // Der Schlaf ist seit dem 27.10.2026 verdrahtet; in **dieser**
      // Hülle liegt aber keine Nacht vor (`_KeineNaechte`), also steht
      // hier kein Wert — und zwar aus Datenmangel, nicht aus fehlender
      // Anbindung. Was die Karte mit echten Nächten zeigt, prüft
      // `heute_erholungskarte_test.dart`.
      expect(
        finde('schlaf').wert,
        isNull,
        reason: 'ohne Nacht kein erfundener Wert',
      );

      // --- Zahlen: Schritte und Gewicht echt. ---
      final schritte = _kachelWert(tester, 'schritt');
      expect(schritte, isNotNull);
      expect(_nurZiffern(schritte!), contains('842'));
      final gewicht = _kachelWert(tester, 'gewicht');
      expect(gewicht, isNotNull);
      expect(_nurZiffern(gewicht!), startsWith('58'));

      // --- Kein Hinweis mehr, auch nicht auf die Einheiten (#376). ---
      expect(find.byKey(const Key('heute-makros-hinweis')), findsNothing);
      expect(
        find.byKey(const Key('heute-offen-hinweis')),
        findsNothing,
        reason: 'Tim, 05.11.2026: „sieht hässlich aus, Tim weiß es"',
      );

      // --- Aufbau/Reihenfolge (Tim, 26.10.: Erholung vor Erledigt). ---
      final titel = tester
          .widgetList<SectionHeader>(find.byType(SectionHeader))
          .map((s) => s.title)
          .toList();
      expect(
        titel,
        ['Heute Training', 'Erholung', 'Zahlen'],
        reason: 'die Makros sind seit #376 nicht mehr auf Home',
      );

      // Großer Datumskopf und Stand-Zeile sind seit #514 (Tim,
      // 16.11.2026) nicht mehr auf Home — den neuen Kopf (Wochentag in
      // der Leiste) bewacht `heute_leiste_wochentag_test.dart`.
      expect(find.byType(GrosseUeberschrift), findsNothing);
      expect(find.byType(StandZeile), findsNothing);
      // Und der Fußtext ist seit #516 ebenfalls weg (Tim, 16.11.2026) —
      // ausführlich in `heute_schlicht_test.dart`.
      expect(find.byType(Hinweisfuss), findsNothing);
    },
  );

  testWidgets(
    'ein gelesener Tag ohne einzelne Werte lässt Ring und Kacheln STEHEN — '
    'ungefüllt statt verschwunden, und nirgends eine 0',
    (tester) async {
      final h = mitWerten(ohneWerte);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      _geruestSteht(tester, zustand: 'Bekannt mit lauter leeren Feldern');

      // Der Ring ist da und behauptet keine Zahl — weder "0" noch "noch
      // 30 min", was beides hieße, es sei etwas gelesen worden.
      _ringLegendeOhneZahl(tester);

      // Beide Kacheln stehen, beide sagen, dass sie keinen Wert haben.
      expect(_kachelWert(tester, 'schritt'), _ohneWert);
      expect(_kachelWert(tester, 'gewicht'), _ohneWert);

      // Die Stand-Zeile stand hier bis #514 (Tim, 16.11.2026) — sie ist
      // mit dem großen Datumskopf von Home gefallen.
      expect(find.byType(StandZeile), findsNothing);
    },
  );

  testWidgets(
    'die Kachelbreite springt nicht, wenn ein Wert fehlt — der Fall, in dem '
    '"Schritte" heute über den ganzen Schirm läuft',
    (tester) async {
      final mit = mitWerten(tageswerte);
      addTearDown(mit.container.dispose);
      await tester.pumpWidget(mit.app);
      await tester.pumpAndSettle();
      final breiteMitBeidenWerten = tester.getRect(find.text('Schritte')).width;

      await tester.pumpWidget(const SizedBox.shrink());

      final teils = mitWerten(nurAeltereWerte);
      addTearDown(teils.container.dispose);
      await tester.pumpWidget(teils.app);
      await tester.pumpAndSettle();
      final breiteOhneSchrittwert = tester.getRect(find.text('Schritte')).width;

      expect(
        breiteOhneSchrittwert,
        closeTo(breiteMitBeidenWerten, 0.5),
        reason:
            'Kacheln legt seine Kinder als gleich breite Expanded in '
            'einer Row ab: Fällt eine weg, verdoppelt sich die andere. '
            'Beide müssen stehen bleiben, damit die Breite dieselbe ist',
      );
    },
  );

  testWidgets(
    'der Ring steht beim Laden an derselben Stelle wie mit Werten — die '
    'Stand-Zeile reserviert ihre Höhe, sonst rutscht beim Eintreffen alles',
    (tester) async {
      final mit = mitWerten(tageswerte);
      addTearDown(mit.container.dispose);
      await tester.pumpWidget(mit.app);
      await tester.pumpAndSettle();
      final ringMitWerten = tester.getTopLeft(find.byType(Ringe)).dy;

      await tester.pumpWidget(const SizedBox.shrink());

      final nieFertig = Completer<Messwert<List<DailyMetrics>>>();
      final laedt = harness(
        notifier: () => _GesteuerterNotifier(endwert: () => nieFertig.future),
      );
      addTearDown(laedt.container.dispose);
      addTearDown(() {
        if (!nieFertig.isCompleted) {
          nieFertig.complete(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
        }
      });
      await tester.pumpWidget(laedt.app);
      await tester.pump();
      final ringBeimLaden = tester.getTopLeft(find.byType(Ringe)).dy;

      expect(
        ringBeimLaden,
        closeTo(ringMitWerten, 1.0),
        reason:
            'StandZeile erscheint heute nur bei Bekannt. Zeichnet '
            'NochNie den vollen Schirm, wäre sie der letzte verbliebene '
            'Sprung: Beim Übergang schöbe sich eine Zeile ein, und alles '
            'darunter rutschte',
      );
    },
  );

  group('die Gewichtskachel zeigt den jüngsten bekannten Wert', () {
    testWidgets(
      'Gewicht von vorgestern steht da, Schritte von vorgestern NICHT — ein '
      'Schrittwert von gestern ist keine Auskunft über heute',
      (tester) async {
        final h = mitWerten(nurAeltereWerte);
        addTearDown(h.container.dispose);

        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        final gewicht = _kachelWert(tester, 'gewicht');
        expect(gewicht, isNotNull);
        expect(
          _nurZiffern(gewicht!),
          startsWith('57'),
          reason:
              'Tim wiegt sich nicht täglich: Der jüngste Wert aus dem '
              'Fenster steht da, sonst sähe die Kachel an den meisten Tagen '
              'nach einem Fehler aus',
        );

        expect(
          _kachelWert(tester, 'schritt'),
          _ohneWert,
          reason:
              'für Schritte gilt das ausdrücklich NICHT — gestern 404 '
              'Schritte zu zeigen, wäre eine falsche Auskunft über heute',
        );
      },
    );

    testWidgets(
      'die Einordnung unter dem Gewicht sagt, wie alt der Wert ist — sie '
      'lautet nicht gleich wie bei einer Messung von heute',
      (tester) async {
        final frisch = mitWerten(tageswerte);
        addTearDown(frisch.container.dispose);
        await tester.pumpWidget(frisch.app);
        await tester.pumpAndSettle();
        final zusatzHeute = _kachelZusatz(tester, 'gewicht');
        expect(zusatzHeute, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());

        final alt = mitWerten(nurAeltereWerte);
        addTearDown(alt.container.dispose);
        await tester.pumpWidget(alt.app);
        await tester.pumpAndSettle();
        final zusatzAelter = _kachelZusatz(tester, 'gewicht');

        expect(
          zusatzAelter,
          isNotNull,
          reason:
              'die Einordnung unter dem Wert bleibt auch dann stehen, '
              'wenn der Wert älter ist — sie trägt die Höhe mit',
        );
        expect(
          zusatzAelter,
          isNot(zusatzHeute),
          reason:
              'ein Wert von vorgestern darf nicht so dastehen wie einer '
              'von heute (der Wortlaut ist nicht festgelegt, nur dass die '
              'beiden Fälle sich unterscheiden)',
        );
      },
    );

    testWidgets(
      'liegt im ganzen Fenster kein Gewicht, steht das Zeichen — kein '
      'erfundener Wert, nur weil ein Rückgriff erlaubt ist',
      (tester) async {
        final h = mitWerten(ohneWerte);
        addTearDown(h.container.dispose);

        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(_kachelWert(tester, 'gewicht'), _ohneWert);
      },
    );
  });

  testWidgets(
    'der Vorlesetext nennt den Zustand, nicht das Zeichen — VoiceOver sagt '
    'nie "Strich Schrägstrich Strich"',
    (tester) async {
      // **Kein eigenes `tester.ensureSemantics()` hier.** `testWidgets`
      // schaltet die Semantik selbst ein (`semanticsEnabled: true`) und
      // zählt am **Ende des Testrumpfs** die offenen `SemanticsHandle` —
      // also bevor `package:test` die `addTearDown`-Rückrufe abarbeitet.
      // Ein über `addTearDown(handle.dispose)` aufgeräumtes zweites Handle
      // ist zu diesem Zeitpunkt noch offen, und der Fall scheitert an
      // „A SemanticsHandle was active at the end of the test", ohne dass
      // eine einzige Zusicherung fehlschlägt. `tester.getSemantics(…)`
      // braucht ohnehin keines.
      final h = mitWerten(ohneWerte);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final beschriftung = tester.getSemantics(find.byType(Ringe)).label;
      expect(
        beschriftung.toLowerCase(),
        contains('training'),
        reason: 'welcher Ring gemeint ist, sagt der Vorlesetext weiterhin',
      );
      expect(
        beschriftung,
        isNot(contains('–')),
        reason:
            'das Zeichen für "kein Wert" ist für das Auge gemacht; '
            'vorgelesen ergibt es "Strich Schrägstrich Strich" und ist '
            'schlechter als das frühere Weglassen (Anti-Ziel der Spec)',
      );
      expect(
        beschriftung.toLowerCase(),
        contains('keine'),
        reason:
            'stattdessen der Zustand in Worten ("Training, keine '
            'Werte"), abgeleitet aus dem fehlenden Wert',
      );
    },
  );

  group('die Erholungskarte richtet sich danach, ob Werte vorliegen', () {
    testWidgets(
      'Überschrift und Akzent sind nicht dieselben wie mit Werten — ein '
      'grüner Punkt neben vier "$_ohneWert" behauptete eine Einordnung',
      (tester) async {
        final mit = mitWerten(tageswerte);
        addTearDown(mit.container.dispose);
        await tester.pumpWidget(mit.app);
        await tester.pumpAndSettle();
        final karteMitWerten = tester.widget<ErholungsKarte>(
          find.byType(ErholungsKarte),
        );
        final ueberschriftMitWerten = karteMitWerten.ueberschrift;
        final akzentMitWerten = karteMitWerten.akzent;

        await tester.pumpWidget(const SizedBox.shrink());

        final ohne = mitWerten(ohneWerte);
        addTearDown(ohne.container.dispose);
        await tester.pumpWidget(ohne.app);
        await tester.pumpAndSettle();
        final karteOhneWerte = tester.widget<ErholungsKarte>(
          find.byType(ErholungsKarte),
        );

        expect(
          karteOhneWerte.ueberschrift,
          isNot(ueberschriftMitWerten),
          reason:
              'die Überschrift ist heute fest "Erholung" — sie muss '
              'sich danach richten, ob überhaupt etwas eingeordnet werden '
              'kann (der Wortlaut ist nicht festgelegt)',
        );
        expect(
          karteOhneWerte.akzent,
          isNot(akzentMitWerten),
          reason: 'dasselbe für die Akzentfarbe (heute fest Palette.ok)',
        );
      },
    );

    testWidgets(
      'der Grund steht einmal im Kartensatz, nicht in jeder Spalte — sonst '
      'wächst die Karte genau dann, wenn Werte fehlen',
      (tester) async {
        final h = mitWerten(ohneWerte);
        addTearDown(h.container.dispose);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        final karte = tester.widget<ErholungsKarte>(
          find.byType(ErholungsKarte),
        );

        final satz = karte.satz.toLowerCase();
        expect(
          satz,
          contains('aufgezeichnet'),
          reason: 'erste Möglichkeit im Kartensatz',
        );
        expect(
          satz.contains('zugriff') || satz.contains('freigegeben'),
          isTrue,
          reason: 'zweite Möglichkeit im Kartensatz — beide, wie überall',
        );

        for (final name in const ['hrv', 'puls', 'atem']) {
          final vital = karte.vitalwerte.firstWhere(
            (v) => v.name.toLowerCase().contains(name),
            orElse: () => throw StateError('kein Vitalwert enthält "$name"'),
          );
          final hinweis = vital.hinweis?.toLowerCase() ?? '';
          expect(
            hinweis.contains('zugriff') || hinweis.contains('aufgezeichnet'),
            isFalse,
            reason:
                'der Grund hing bisher an jeder einzelnen Spalte, lief '
                'dort über mehrere Zeilen und machte die Karte höher, '
                'sobald Werte fehlten — er gehört einmal in den Kartensatz',
          );
        }
      },
    );

    testWidgets(
      'fehlende Vitalwerte zeigen dasselbe Zeichen wie die Kacheln — ein '
      'Zeichen, nicht zwei',
      (tester) async {
        final h = mitWerten(ohneWerte);
        addTearDown(h.container.dispose);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(ErholungsKarte),
            matching: find.text(_ohneWert),
          ),
          findsNWidgets(4),
          reason:
              'alle vier Spalten stehen ohne Wert da; die Karte schrieb '
              'bisher "–" (ein Zeichen), der Entwurf schreibt "$_ohneWert" '
              '— ein einzelner Strich ist von einem Minuszeichen nicht zu '
              'unterscheiden',
        );
      },
    );
  });

  testWidgets('ein gescheiterter Lauf ohne Cache stürzt den Schirm nicht ab '
      '(Zusatzfall, nicht einer der fünf Pflichtfälle — Wortlaut der '
      'Fehlermeldung ist nicht festgelegt)', (tester) async {
    final h = harness(
      notifier: () => _GesteuerterNotifier(
        endwert: () async => Fehlgeschlagen<List<DailyMetrics>>(
          fehler: Exception('Kanal nicht erreichbar'),
          gelaufen: jetzt,
        ),
      ),
    );
    addTearDown(h.container.dispose);

    await tester.pumpWidget(h.app);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byType(Ringe),
      findsNothing,
      reason:
          'Fehlgeschlagen bleibt, wie es war: Dass ein Lauf '
          'scheiterte, ist eine Aussage über den Lauf und gehört nicht in '
          'die Felder (Spec, Abschnitt "Der Ladezustand bekommt dieselbe '
          'Form")',
    );
  });
}

/// Das Zeichen für „gelesen, kein Wert" — `OHNE_WERT` aus
/// `docs/screens/components.js` und die Schreibweise, auf die `CLAUDE.md`
/// seit dem 28.10.2026 festgelegt ist („sie steht ungefüllt da und sagt
/// `–/–`"). Ein einzelner Strich ist von einem Minuszeichen nicht zu
/// unterscheiden.
const _ohneWert = '–/–';

/// Die tragende Behauptung der Spec, an einer Stelle: **Eine Anzeige, die
/// es gibt, hat genau eine Form.** Ring, Kacheln und Erholungskarte stehen
/// in derselben Gestalt da, ob Werte vorliegen oder nicht — geprüft über
/// ihre Anwesenheit im Baum und ihre Anzahl, nicht über ihren Inhalt.
///
/// Dass die Prüfung über `findsOneWidget`/`hasLength` läuft und nicht über
/// einen Text, ist der Kern: Ein Test, der nur nach „$_ohneWert" sucht,
/// ginge auch durch, wenn die Anzeige ganz woanders säße.
void _geruestSteht(WidgetTester tester, {required String zustand}) {
  expect(
    find.byType(Ringe),
    findsOneWidget,
    reason:
        '$zustand: der Ring verschwindet nicht, nur weil sein Wert '
        'fehlt — sonst ist dem Schirm nicht anzusehen, ob die App ihn '
        'nicht kann oder nur keine Zahl hat',
  );
  final ringe = tester.widget<Ringe>(find.byType(Ringe));
  expect(
    ringe.ziele.map((z) => z.label).toList(),
    ['Kalorien', 'Eiweiß', 'Training'],
    reason:
        '$zustand: dieselben drei Ringe wie im Normalfall (#358) — keiner '
        'verschwindet, weil sein Wert fehlt',
  );
  expect(find.byType(RingLegende), findsOneWidget, reason: zustand);

  expect(
    find.byType(Kacheln),
    findsOneWidget,
    reason: '$zustand: der Kachelstreifen bleibt',
  );
  final kacheln = tester.widget<Kacheln>(find.byType(Kacheln));
  expect(
    kacheln.werte,
    hasLength(2),
    reason:
        '$zustand: beide Kacheln, sonst teilt sich die verbliebene die '
        'ganze Breite',
  );
  expect(
    kacheln.werte.map((w) => w.label),
    containsAll(<String>['Schritte', 'Gewicht']),
    reason: zustand,
  );

  expect(
    find.byType(ErholungsKarte),
    findsOneWidget,
    reason: '$zustand: die Erholungskarte bleibt',
  );
  expect(
    tester.widget<ErholungsKarte>(find.byType(ErholungsKarte)).vitalwerte,
    hasLength(4),
    reason: '$zustand: alle vier Spalten, keine fällt bei fehlendem Wert weg',
  );

  final titel = tester
      .widgetList<SectionHeader>(find.byType(SectionHeader))
      .map((s) => s.title)
      .toList();
  expect(
    titel,
    ['Heute Training', 'Erholung', 'Zahlen'],
    reason:
        '$zustand: Überschriften und Abschnittstitel stehen sofort da '
        '(#24: kein Platzhalter für ganze Schirme), und zwar in derselben '
        'Reihenfolge wie mit Werten',
  );
}

/// Die Ringbeschriftung trägt keine Ziffer. Fängt beide Spielarten der
/// ersten Falle auf einmal: einen Ring auf `0` („noch 30 min", obwohl nichts
/// gelesen wurde) und eine schlicht stehengebliebene Zahl.
void _ringLegendeOhneZahl(WidgetTester tester) {
  final zahlen = find.descendant(
    of: find.byType(RingLegende),
    matching: find.textContaining(RegExp('[0-9]')),
  );
  expect(
    zahlen,
    findsNothing,
    reason:
        'ein Ring, der "noch 30 min" sagt, weil der fehlende Wert als 0 '
        'durchging, ist Fehler 01 in neuer Verpackung — lieber die Anzeige '
        'wieder verschwinden lassen als eine Null behaupten',
  );
}

String _nurZiffern(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// Die sichtbaren Texte **einer** Kachel, über ihre Spaltenlage zugeordnet.
///
/// Bewusst nicht über `KachelWert.wert`: Wie der Baukasten „kein Wert"
/// ausdrückt, lässt die Spec offen (nullbares Feld, eigener Typ, benannter
/// Konstruktor) — ein Test, der eines davon liest, entschiede es. Gelesen
/// wird deshalb, was auf dem Schirm steht, und zwar an der Stelle, an der
/// es stehen soll: `Kacheln` legt seine Kinder als gleich breite `Expanded`
/// in einer `Row` ab, also gehört jeder Text in die Spalte, über der seine
/// Mitte liegt.
///
/// Reihenfolge innerhalb der Kachel ist Baumreihenfolge: Beschriftung,
/// Wert, (Einheit), Einordnung.
List<String> _kachelTexte(WidgetTester tester, String labelTeil) {
  final kachelnFinder = find.byType(Kacheln);
  if (kachelnFinder.evaluate().isEmpty) return const [];
  final kacheln = tester.widget<Kacheln>(kachelnFinder);
  final index = kacheln.werte.indexWhere(
    (w) => w.label.toLowerCase().contains(labelTeil),
  );
  if (index < 0) return const [];

  final rahmen = tester.getRect(kachelnFinder);
  final spaltenbreite = rahmen.width / kacheln.werte.length;
  final von = rahmen.left + index * spaltenbreite;
  final bis = von + spaltenbreite;

  final texte = <String>[];
  for (final element
      in find
          .descendant(of: kachelnFinder, matching: find.byType(Text))
          .evaluate()) {
    final mitte = tester
        .getCenter(find.byElementPredicate((e) => identical(e, element)))
        .dx;
    if (mitte >= von && mitte < bis) {
      texte.add(textOf(element.widget as Text));
    }
  }
  return texte;
}

/// Der sichtbare Wert der Kachel, deren Beschriftung [labelTeil] enthält —
/// `null`, wenn gar kein `Kacheln`-Baustein auf dem Schirm steht oder die
/// Kachel fehlt. Genau dieses `null` ist in den Leerzuständen ein Fehler:
/// Dort soll die Kachel dastehen und `–/–` sagen.
String? _kachelWert(WidgetTester tester, String labelTeil) {
  final texte = _kachelTexte(tester, labelTeil);
  return texte.length < 2 ? null : texte[1];
}

/// Die Einordnung unter dem Wert (die letzte Zeile der Kachel).
String? _kachelZusatz(WidgetTester tester, String labelTeil) {
  final texte = _kachelTexte(tester, labelTeil);
  return texte.length < 3 ? null : texte.last;
}

/// Alle sichtbaren `Text`-Inhalte auf dem Schirm, für lose
/// Stichwort-Suchen, die keine einzelne Stelle im Baum kennen müssen.
List<String> _alleTexte(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(textOf).toList();

/// Die obere Kante eines einzelnen Elements — über eine Element-Gleichheit
/// gesucht, nicht über `find.byWidget`: Zwei gleich beschriftete `const
/// Text`-Widgets sind in Dart dieselbe Instanz, `byWidget` fände dann beide.
double _obenVon(WidgetTester tester, Element element) =>
    tester.getTopLeft(find.byElementPredicate((e) => identical(e, element))).dy;

/// Ein steuerbarer Ableger von `DailyMetricsNotifier` (Task 13), mit dem
/// sich jede Zustandsfolge nachstellen lässt, die der echte Notifier auch
/// erzeugt (Zwischenwert per `state =`, Endwert per Rückgabe) — ohne den
/// echten Kanal/Cache nachzubauen. Diese Datei prüft nur, wie `HeuteView`
/// auf eine gegebene Zustandsfolge reagiert, nicht, wie die Folge zustande
/// kommt (das deckt `health_provider_test.dart` ab).
///
/// **Erbt bewusst von `DailyMetricsNotifier`, nicht von `AsyncNotifier`
/// direkt:** `dailyMetricsProvider.overrideWith(...)` ist über den
/// deklarierten Provider-Typ
/// `AsyncNotifierProvider<DailyMetricsNotifier, Messwert<List<DailyMetrics>>>`
/// exakt auf `DailyMetricsNotifier Function()` festgelegt (Riverpods
/// generische Typen sind hier invariant) — ein unabhängiger
/// `AsyncNotifier<Messwert<List<DailyMetrics>>>` erfüllt die Signatur nicht,
/// selbst bei identischem `ValueT`. Die Unterklasse überschreibt nur
/// `build()`; `state =` bleibt dadurch ein normaler, in der Klassenhierarchie
/// erlaubter Zugriff auf das von `AnyNotifier` geerbte `@protected state`.
class _GesteuerterNotifier extends DailyMetricsNotifier {
  _GesteuerterNotifier({this.zwischenwert, required this.endwert});

  final Messwert<List<DailyMetrics>>? zwischenwert;
  final Future<Messwert<List<DailyMetrics>>> Function() endwert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async {
    final z = zwischenwert;
    if (z != null) {
      state = AsyncData(z);
    }
    return endwert();
  }
}

/// Kein Schlaf-Provider mit echter Datenbank im Widget-Test: Diese Datei
/// handelt von Ringen, Kacheln und Platzhaltern, nicht von der
/// Erholungskarte. Die hat seit dem 27.10.2026 ihre eigene Testfläche in
/// `heute_erholungskarte_test.dart` — hier liegt bewusst **keine** Nacht
/// vor, damit kein Test hier nebenbei etwas über sie behauptet.
class _KeineNaechte extends SleepNotifier {
  @override
  Future<Messwert<List<SleepNight>>> build() async =>
      LeerNachLauf<List<SleepNight>>(gelaufen: DateTime.utc(2026, 10, 20));
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
