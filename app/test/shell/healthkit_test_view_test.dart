import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/stand_zeile.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/healthkit_test_view.dart';
import 'package:repit/shell/heute_view.dart' show heuteZustandAusProvider;

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für `HealthKitTestView` (`lib/shell/healthkit_test_view.dart`) —
/// den einzigen Punkt im *Mehr*-Menü, der in M1 funktioniert
/// (`docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md`,
/// Abschnitt 10, „M1 — Home und Navbar"). Entwurf:
/// `docs/screens/screens/healthtest.js` (siehe dessen Kommentarkopf: „kein
/// Schirm für den Alltag, sondern einer für die Frage 'liegt es an der App
/// oder an den Daten'"). Auftrag: #45 („Der HealthKit-Test soll zeigen,
/// was wir lesen *und nutzen*").
///
/// ## Festgelegte API
///
/// - `class HealthKitTestView extends ConsumerWidget` in
///   `app/lib/shell/healthkit_test_view.dart`, Konstruktor
///   `const HealthKitTestView({super.key})`. **Bringt keinen eigenen
///   `CupertinoPageScaffold`/keine `NavigationBar` mit** (Hausregel, parallel
///   zu `HeuteView`/`PlatzhalterTab`) — der Host (laut
///   `task-navbar-tests-report.md` zieht `MehrView` den echten Schirm später
///   anstelle von `_HealthKitTestPlatzhalter` auf den Stapel des *Mehr*-Tabs;
///   diese Verdrahtung ist **nicht** Teil dieses Tasks) stellt beides. Dieser
///   Test stellt beides selbst (`harness` unten, wie in
///   `heute_view_test.dart`).
/// - **13 Schlüssel, einer je Feld aus `DailyMetrics`, für den Tag „heute"**
///   (den Referenztag — Begründung zur Mehrdeutigkeit „letztes Element vs.
///   Tag-Abgleich" siehe unten, wörtlich dieselbe wie in
///   `heute_view_test.dart`):
///   ```
///   Key('healthkit-typ-steps')
///   Key('healthkit-typ-activeKcal')
///   Key('healthkit-typ-basalKcal')
///   Key('healthkit-typ-restingHR')
///   Key('healthkit-typ-hrvMs')
///   Key('healthkit-typ-respRate')
///   Key('healthkit-typ-vo2max')
///   Key('healthkit-typ-weightKg')
///   Key('healthkit-typ-bodyFatPct')
///   Key('healthkit-typ-leanKg')
///   Key('healthkit-typ-exerciseMinutes')
///   Key('healthkit-typ-standHours')
///   Key('healthkit-typ-recoveryHRDrop')
///   ```
///   Die Feldnamen sind dieselben wie in `DailyMetrics` (Code-Englisch,
///   keine Oberflächenbeschriftung — die Schlüssel sind reine
///   Fundstellen für Tests, keine sichtbaren Texte, `CLAUDE.md` greift hier
///   nicht). **Diese Schlüssel bezeichnen ausdrücklich den Tag „heute".**
///   Zeigt der Schirm zusätzlich weitere Tage (z. B. eine kurze
///   Gewichtshistorie wie im Entwurf `healthtest.js`, „Gewicht, letzte
///   Messungen"), brauchen die zugehörigen Zeilen **andere** Schlüssel —
///   sonst verletzt ein doppelter `Key('healthkit-typ-weightKg')`
///   Flutters Eindeutigkeitsannahme für `find.byKey`. Jeder Schlüssel sitzt
///   auf einem **Vorfahren** des erklärenden Inhalts, nicht auf dem `Text`
///   selbst (wie bei `HeuteView`s Hinweis-Schlüsseln) — die Tests suchen
///   über `find.descendant`.
///
/// ## Warum nur 13 Typen, nicht ~200
///
/// `docs/health-datentypen.md` und `HealthTypeCatalog` (Swift) kennen rund
/// 200 angefragte HealthKit-Bezeichner. Diese Datei prüft nur die, die auf
/// der Dart-Seite heute tatsächlich **ankommen**: `DailyMetrics` (Task
/// 7/12) über `dailyMetricsProvider` (Task 13) — der einzige Provider, den
/// es gibt. `hourlyStepsProvider`/`sleepProvider`/`workoutsProvider`/
/// `nutritionProvider` fehlen laut `health_provider.dart`s eigenem
/// Dateikopf bewusst („sie auf Verdacht zu bauen hieße, eine ungeprüfte
/// Cache-Strategie für sie festzuschreiben"). Dieselbe Zurückhaltung gilt
/// hier: Gewicht-Historie, Workouts gestern, Ernährung gestern, Schlaf-
/// Rohabschnitte, Abfragedauern und die Doppelquelle aus `healthtest.js`
/// bzw. Spec 8.3/8.4 sind **bewusst nicht** Teil dieser Testdatei — sie
/// hängen an Providern, die noch nicht existieren, bzw. an einer zweiten
/// `HealthReading`-Instanz, die kein bisheriger Task liefert. Eine spätere
/// Aufgabe erweitert Schirm und Tests, sobald diese Provider gebaut sind.
///
/// ## Wie „heute" im Datensatz gefunden wird — bewusst nicht festgelegt
///
/// Wie in `heute_view_test.dart`: `Bekannt<List<DailyMetrics>>.wert` ist
/// eine Liste über mehrere Tage. Ob `HealthKitTestView` „heute" per
/// Tag-Abgleich gegen `clockProvider` oder als letztes Listenelement
/// findet, legen diese Tests **nicht** fest — die Fixtures unten machen
/// beide Strategien ununterscheidbar richtig.
///
/// ## Die Berechtigungsanfrage — eine bewusste Auslegungsentscheidung
///
/// Spec 10 (M1) zählt den Berechtigungsdialog ausdrücklich zur „vollen
/// Breite" dieses Schirms: „Der Berechtigungsdialog fragt den
/// vollständigen Katalog ab … Es gibt genau einen Dialog pro Installation."
/// Der Auftrag zu dieser Datei nennt das unter „Eigenart dieses Schirms"
/// bedingt („nagle es fest, wenn es sich im Schirm zeigt"). Diese Datei
/// entscheidet sich dafür, es zu prüfen — der M1-Entwurf benennt diesen
/// Schirm als den einen Ort, an dem die Anfrage passiert, und „einmal pro
/// Installation" ist ein Zustandsübergang (höchstens ein Aufruf über
/// mehrere Rebuilds hinweg), kein Layout. **Wer das für falsch hält, meldet
/// es, ändert den Test aber nicht** (`CLAUDE.md`). Was hier **nicht**
/// geprüft wird: dass der Katalog „vollständig" ist (≈200 Typen) — das
/// entscheidet sich serverseitig in `app/ios/Runner/HealthTypeCatalog.swift`
/// (noch nicht portiert), nicht in diesem Dart-Aufruf: `HealthReading.
/// requestAuthorization()` nimmt ohnehin keine Typliste entgegen, kann von
/// Dart aus also gar keine Teilmenge anfragen.
///
/// ## Was ein Widget-Test hier nicht prüft (CLAUDE.md)
///
/// Layout und genauer Wortlaut. Reason-Texte werden nur auf „enthält kein
/// erfundenes Zahlenzeichen, mit sagt stattdessen einen Grund" geprüft
/// (lose Stichwort-Treffer), nie auf einen exakten Satz — mit derselben
/// einen Ausnahme wie in `heute_view_test.dart`: „wird geladen" ist
/// wörtlich aus dem Testgerüst in
/// `docs/superpowers/plans/2026-10-23-flutter-rebuild-m0-m1.md` (Task 14)
/// übernommen.
///
/// ## Zahlen in dieser Datei
///
/// Ausschließlich erfunden (keine Werte aus `docs/sample_export.json`,
/// `docs/SPEC.md` oder Tims echten Daten). `hrvMs: 0.0` ist absichtlich ein
/// gültiger, seltener Grenzfall (kein „kein Wert"), um „`null` ist nicht
/// `0`" (CLAUDE.md) am Bildschirm zu belegen. `respRate: 13.27` hat zwei
/// Nachkommastellen, damit eine stille Rundung auf eine Nachkommastelle
/// oder auf eine ganze Zahl auffiele.
void main() {
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);
  const gestern = '2026-10-19';
  const heute = '2026-10-20';

  final tageswerte = <DailyMetrics>[
    const DailyMetrics(tag: gestern, steps: 500, hrvMs: 41.2),
    const DailyMetrics(
      tag: heute,
      steps: 8041,
      activeKcal: 432,
      // basalKcal bleibt null: Typ ohne Daten.
      restingHR: 56,
      hrvMs: 0.0, // gültiger Grenzfall, kein "kein Wert".
      respRate: 13.27, // zwei Nachkommastellen, Rundungsfalle.
      // vo2max bleibt null.
      weightKg: 58.6,
      // bodyFatPct, leanKg, exerciseMinutes, standHours, recoveryHRDrop
      // bleiben null — echte HealthKit-Lücken, kein erfundener Nullwert.
    ),
  ];

  /// Alle 13 Felder aus `DailyMetrics`, in derselben Schreibweise wie dort.
  const typSchluessel = [
    'steps',
    'activeKcal',
    'basalKcal',
    'restingHR',
    'hrvMs',
    'respRate',
    'vo2max',
    'weightKg',
    'bodyFatPct',
    'leanKg',
    'exerciseMinutes',
    'standHours',
    'recoveryHRDrop',
  ];

  ({ProviderContainer container, Widget app}) harness({
    required DailyMetricsNotifier Function() notifier,
    HealthReading? healthQuelle,
  }) {
    final container = ProviderContainer(
      overrides: [
        dailyMetricsProvider.overrideWith(notifier),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(
          healthQuelle ?? _ZaehlendeHealthReading(),
        ),
      ],
    );
    final app = UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(
        home: CupertinoPageScaffold(child: HealthKitTestView()),
      ),
    );
    return (container: container, app: app);
  }

  Finder typZeile(String feld) => find.byKey(Key('healthkit-typ-$feld'));

  group('während des Ladens steht nirgends eine Zahl, die es nicht gibt', () {
    testWidgets('ohne Cache-Treffer: nur ein Ladehinweis, keine Typzeilen', (
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

      for (final feld in typSchluessel) {
        // **Geändert am 03.11.2026 (#182/#262).** Vorher verlangte diese
        // Schleife `findsNothing`: Der Schirm zeigte seine Zeilen nur in
        // `Bekannt`, und wer ihn öffnete, sah eine fast leere Seite, bis
        // beim Eintreffen der Werte alles sprang. Die Anforderung dahinter
        // ist unverändert und steht eine Zeile tiefer — es darf **keine
        // Zahl** dastehen, die es nicht gibt. Neu ist nur, dass das Gerüst
        // trotzdem steht; die Werte sind graue Formen ohne Ziffern (siehe
        // `icon_row_platzhalter_test.dart`).
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
      expect(find.byType(StandZeile), findsNothing);
      expect(
        find.textContaining('8041'),
        findsNothing,
        reason: 'kein Rohwert vor dem ersten Ergebnis, auch nicht aus einem '
            'Cache, den es hier nicht gibt',
      );
      // **Eingegrenzt am 03.11.2026 (#182/#262).** Die Aussage ist
      // dieselbe und sie ist eine der beiden, auf die es laut
      // `CLAUDE.md` ankommt: Während des Ladens steht nie ein „keine
      // Daten"-Grund. Gesucht wird sie jetzt **in den dreizehn
      // Typzeilen**, nicht über den ganzen Schirm — seit dem Umbau
      // trägt die Fußnote den Satz „ein fehlender Typ heißt entweder
      // nichts aufgezeichnet oder kein Lesezugriff" in jedem Zustand.
      // Das ist eine stehende Erklärung über den Schirm, keine Aussage
      // über diesen Lauf, und sie darf nicht mitwandern, nur weil sie
      // dasselbe Wort benutzt.
      for (final feld in typSchluessel) {
        final text = _textUnter(tester, Key('healthkit-typ-$feld'));
        for (final wort in ['aufgezeichnet', 'keine', 'kein ', 'zugriff']) {
          expect(
            text,
            isNot(contains(wort)),
            reason: 'der "keine Daten"-Grund gehört nur zu einem FERTIGEN '
                'Lauf ohne Treffer, nicht zum Laden — $feld trägt "$wort"',
          );
        }
      }
      expect(find.textContaining('wird geladen'), findsWidgets);
    });

    testWidgets(
      'mit Cache-Treffer stehen die Rohwerte sofort mit "wird aktualisiert" '
      '— nie NochNie dazwischen (Tims ursprüngliche Beschwerde, eine Ebene '
      'höher als docs/todo/01)',
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

        expect(find.byType(StandZeile), findsOneWidget);
        var stand = tester
            .widget<StandZeile>(find.byType(StandZeile))
            .messwert;
        expect(stand.laeuft, isTrue);
        expect(stand.stand, cacheStand);

        expect(typZeile('steps'), findsOneWidget);
        expect(_textUnter(tester, const Key('healthkit-typ-steps')), contains('8041'));

        kanalAntwort.complete(
          Bekannt<List<DailyMetrics>>(tageswerte, stand: jetzt, laeuft: false),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(StandZeile), findsOneWidget);
        stand = tester.widget<StandZeile>(find.byType(StandZeile)).messwert;
        expect(stand.laeuft, isFalse);
        expect(stand.stand, jetzt);
        expect(
          _textUnter(tester, const Key('healthkit-typ-steps')),
          contains('8041'),
          reason: 'der Wert, der da stand, ist nie verschwunden',
        );

        expect(
          beobachtet.whereType<NochNie<List<DailyMetrics>>>(),
          isEmpty,
          reason: 'zwischen Cache-Treffer und Endergebnis darf nie NochNie '
              'aufscheinen',
        );
      },
    );
  });

  testWidgets(
    'jeder abgefragte Typ erscheint, auch der ohne Daten, mit einem Grund '
    'statt einer Zahl — und "0" bleibt von "kein Wert" unterscheidbar',
    (tester) async {
      final h = harness(
        notifier: () => _GesteuerterNotifier(
          endwert: () async => Bekannt<List<DailyMetrics>>(
            tageswerte,
            stand: jetzt,
            laeuft: false,
          ),
        ),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      for (final feld in typSchluessel) {
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }

      // --- Vorhandene Werte: roh, nicht verschwiegen. ---
      expect(_textUnter(tester, const Key('healthkit-typ-steps')), contains('8041'));
      expect(_textUnter(tester, const Key('healthkit-typ-activeKcal')), contains('432'));
      expect(_textUnter(tester, const Key('healthkit-typ-restingHR')), contains('56'));
      expect(
        _enthaeltUnverundet(
          _textUnter(tester, const Key('healthkit-typ-respRate')),
          13.27,
        ),
        isTrue,
        reason: 'zwei Nachkommastellen dürfen nicht auf eine gerundet werden',
      );
      expect(_textUnter(tester, const Key('healthkit-typ-weightKg')), contains('58'));

      // --- hrvMs: 0.0 ist ein gültiger Wert, kein "kein Wert". ---
      final hrvText = _textUnter(tester, const Key('healthkit-typ-hrvMs'));
      expect(
        hrvText.contains('0'),
        isTrue,
        reason: 'hrvMs: 0.0 ist ein echter Messwert, CLAUDE.md: "null ist '
            'nicht 0"',
      );
      expect(
        _istGrundStattZahl(hrvText),
        isFalse,
        reason: 'ein echter Nullwert darf nicht wie eine Datenlücke aussehen',
      );

      // --- Fehlende Felder: ein Grund, keine Zahl. ---
      for (final feld in [
        'basalKcal',
        'vo2max',
        'bodyFatPct',
        'leanKg',
        'exerciseMinutes',
        'standHours',
        'recoveryHRDrop',
      ]) {
        final text = _textUnter(tester, Key('healthkit-typ-$feld'));
        expect(
          _istGrundStattZahl(text),
          isTrue,
          reason: '$feld ist im Fixture null, erwartet einen Grund statt '
              'einer Zahl, tatsächlicher Text: "$text"',
        );
      }
    },
  );

  testWidgets(
    'nach einem fertigen Lauf ohne Treffer stehen beide möglichen Gründe, '
    'weil Apple sie nicht unterscheidet',
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

      for (final feld in typSchluessel) {
        // **Geändert am 03.11.2026 (#182/#262).** Vorher verlangte diese
        // Schleife `findsNothing`: Der Schirm zeigte seine Zeilen nur in
        // `Bekannt`, und wer ihn öffnete, sah eine fast leere Seite, bis
        // beim Eintreffen der Werte alles sprang. Die Anforderung dahinter
        // ist unverändert und steht eine Zeile tiefer — es darf **keine
        // Zahl** dastehen, die es nicht gibt. Neu ist nur, dass das Gerüst
        // trotzdem steht; die Werte sind graue Formen ohne Ziffern (siehe
        // `icon_row_platzhalter_test.dart`).
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
      expect(find.byType(StandZeile), findsNothing);

      final alleTexte = _alleTexte(tester).join(' ').toLowerCase();
      expect(
        alleTexte,
        contains('aufgezeichnet'),
        reason: 'erste Möglichkeit: nichts aufgezeichnet',
      );
      expect(
        alleTexte.contains('zugriff') || alleTexte.contains('freigegeben'),
        isTrue,
        reason: 'zweite Möglichkeit: kein Lesezugriff/nicht freigegeben — '
            'beide müssen genannt werden, nicht nur eine',
      );
    },
  );

  testWidgets(
    'ein gescheiterter Lauf nimmt keinen sichtbaren Wert weg — stand ein '
    'Wert da, bleibt er mit dem alten Stand stehen (alsMesswert: Fehler + '
    'Cache ⇒ Bekannt(laeuft: false), nie Fehlgeschlagen)',
    (tester) async {
      final cacheStand = DateTime.utc(2026, 10, 20, 9, 0);
      final zwischenwert = Bekannt<List<DailyMetrics>>(
        tageswerte,
        stand: cacheStand,
        laeuft: true,
      );
      final kanalAntwort = Completer<Messwert<List<DailyMetrics>>>();

      final h = harness(
        notifier: () => _GesteuerterNotifier(
          zwischenwert: zwischenwert,
          endwert: () => kanalAntwort.future,
        ),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pump();

      expect(_textUnter(tester, const Key('healthkit-typ-steps')), contains('8041'));

      // Der Kanal scheitert, aber es gibt einen Cache — `alsMesswert` gibt
      // dafür `Bekannt(cache.wert, stand: cache.stand, laeuft: false)`
      // zurück, nie `Fehlgeschlagen` (Spec 5.3d, CLAUDE.md „Ein
      // gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg").
      kanalAntwort.complete(
        Bekannt<List<DailyMetrics>>(tageswerte, stand: cacheStand, laeuft: false),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _textUnter(tester, const Key('healthkit-typ-steps')),
        contains('8041'),
        reason: 'der Wert, der dastand, ist nicht verschwunden',
      );
      final stand = tester.widget<StandZeile>(find.byType(StandZeile)).messwert;
      expect(stand.laeuft, isFalse);
      expect(
        stand.stand,
        cacheStand,
        reason: 'kein frischer Stand ohne frisches Ergebnis — der '
            'gescheiterte Versuch darf den Stand nicht auf "jetzt" '
            'vorrücken',
      );
    },
  );

  testWidgets(
    'Rohwerte bleiben roh: keine Rundung, keine Umrechnung, keine Mittelung '
    'über mehrere Tage',
    (tester) async {
      final h = harness(
        notifier: () => _GesteuerterNotifier(
          endwert: () async => Bekannt<List<DailyMetrics>>(
            tageswerte,
            stand: jetzt,
            laeuft: false,
          ),
        ),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      // "heute" hat 8041 Schritte, "gestern" 500 — eine Mittelung ((500 +
      // 8041) / 2 = 4270.5) darf nirgends unter dem Typ "steps" für heute
      // auftauchen, nur der rohe Tageswert.
      final steps = _textUnter(tester, const Key('healthkit-typ-steps'));
      expect(steps, contains('8041'));
      expect(steps, isNot(contains('4270')));
      expect(steps, isNot(contains('4271')));

      // 13,27 (bzw. 13.27) darf nicht auf eine Nachkommastelle oder auf
      // eine ganze Zahl gerundet werden.
      final respRate = _textUnter(tester, const Key('healthkit-typ-respRate'));
      expect(_enthaeltUnverundet(respRate, 13.27), isTrue);
    },
  );

  testWidgets(
    'die HealthKit-Berechtigung wird höchstens einmal angefragt, nicht bei '
    'jedem Rebuild (Spec 10/M1: "genau ein Dialog pro Installation" — '
    'Auslegungsentscheidung, siehe Dateikopf)',
    (tester) async {
      final quelle = _ZaehlendeHealthReading();
      final zwischenwert = Bekannt<List<DailyMetrics>>(
        tageswerte,
        stand: jetzt,
        laeuft: true,
      );
      final kanalAntwort = Completer<Messwert<List<DailyMetrics>>>();

      final h = harness(
        notifier: () => _GesteuerterNotifier(
          zwischenwert: zwischenwert,
          endwert: () => kanalAntwort.future,
        ),
        healthQuelle: quelle,
      );
      addTearDown(h.container.dispose);
      addTearDown(() {
        if (!kanalAntwort.isCompleted) {
          kanalAntwort.complete(
            Bekannt<List<DailyMetrics>>(tageswerte, stand: jetzt, laeuft: false),
          );
        }
      });

      await tester.pumpWidget(h.app);
      await tester.pump();
      await tester.pump(); // ein zweiter Frame ohne weitere Zustandsänderung

      kanalAntwort.complete(
        Bekannt<List<DailyMetrics>>(tageswerte, stand: jetzt, laeuft: false),
      );
      await tester.pump();
      await tester.pump();

      expect(
        quelle.anzahlAufrufe,
        lessThanOrEqualTo(1),
        reason: 'ein Dialog pro Installation (CLAUDE.md) — nicht einer je '
            'Rebuild. (0 ist ebenfalls zulässig, falls die Anfrage an '
            'anderer Stelle als in diesem Schirm passiert; das belegt dann '
            'ein anderer Test an anderer Stelle, nicht dieser hier.)',
      );
    },
  );

  testWidgets(
    'ein gescheiterter Lauf ohne Cache stürzt den Schirm nicht ab '
    '(Zusatzfall, nicht einer der fünf Pflichtfälle — Wortlaut der '
    'Fehlermeldung ist nicht festgelegt)',
    (tester) async {
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
      for (final feld in typSchluessel) {
        // **Geändert am 03.11.2026 (#182/#262).** Vorher verlangte diese
        // Schleife `findsNothing`: Der Schirm zeigte seine Zeilen nur in
        // `Bekannt`, und wer ihn öffnete, sah eine fast leere Seite, bis
        // beim Eintreffen der Werte alles sprang. Die Anforderung dahinter
        // ist unverändert und steht eine Zeile tiefer — es darf **keine
        // Zahl** dastehen, die es nicht gibt. Neu ist nur, dass das Gerüst
        // trotzdem steht; die Werte sind graue Formen ohne Ziffern (siehe
        // `icon_row_platzhalter_test.dart`).
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
    },
  );
}

/// Ein steuerbarer Ableger von `DailyMetricsNotifier` (Task 13), mit dem
/// sich jede Zustandsfolge nachstellen lässt, die der echte Notifier auch
/// erzeugt — wörtlich dasselbe Muster wie `_GesteuerterNotifier` in
/// `heute_view_test.dart` (dort ausführlich begründet, warum es von
/// `DailyMetricsNotifier` erbt statt von `AsyncNotifier` direkt: Riverpods
/// generische Typen sind hier invariant). Diese Datei prüft nur, wie
/// `HealthKitTestView` auf eine gegebene Zustandsfolge reagiert, nicht, wie
/// die Folge zustande kommt (das deckt `health_provider_test.dart` ab).
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

/// Fake-Quelle für `healthProvider`. Zählt nur `requestAuthorization`-
/// Aufrufe — alle übrigen Methoden werfen, weil `HealthKitTestView` Daten
/// ausschließlich über `dailyMetricsProvider` beziehen soll (Hausregel:
/// „Views rufen niemals direkt den Kanal auf"). Wirft eine dieser Methoden
/// in einem Test, ist das ein Hinweis, dass der Schirm die Mock-Variante
/// umgeht, nicht ein Fehler dieser Fake-Klasse.
class _ZaehlendeHealthReading extends HealthReadingAttrappe {
  int anzahlAufrufe = 0;

  @override
  DateTime get earliestPermittedDate =>
      DateTime.utc(2000).toUtc();

  @override
  Future<void> requestAuthorization() async {
    anzahlAufrufe += 1;
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) =>
      throw UnimplementedError(
        'HealthKitTestView soll Tageswerte ueber dailyMetricsProvider lesen, '
        'nicht direkt ueber den Kanal.',
      );

  @override
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) => throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');
}

/// `true`, wenn [text] nach einem Grund statt einer Zahl aussieht: keine
/// Ziffer (also keine erfundene Zahl irgendeiner Art), aber ein Stichwort,
/// das auf eine Erklärung hindeutet. Lose geprüft (CLAUDE.md: kein exakter
/// Wortlaut), aber "keine Ziffer" ist hart — ein Grund, der zufällig eine
/// Ziffer enthält (z. B. eine Jahreszahl), wäre ohnehin ein ungewöhnlicher
/// Formulierungsstil für eine Datenlücke.
bool _istGrundStattZahl(String text) {
  final hatZiffer = RegExp('[0-9]').hasMatch(text);
  final klein = text.toLowerCase();
  final hatSchluesselwort = [
    'keine',
    'kein',
    'nicht',
    'fehlt',
    'unbekannt',
  ].any(klein.contains);
  return !hatZiffer && hatSchluesselwort;
}

/// `true`, wenn [text] [wert] in voller, unveränderter Nachkommagenauigkeit
/// enthält — mit Punkt oder mit Komma (deutsche Zahlschreibweise), damit der
/// Test nicht an einer Formatierungsentscheidung (`Format`/eigene
/// Zahlfunktion) zerbricht, die mit "roh" nichts zu tun hat.
bool _enthaeltUnverundet(String text, double wert) {
  final mitPunkt = wert.toString();
  final mitKomma = mitPunkt.replaceAll('.', ',');
  return text.contains(mitPunkt) || text.contains(mitKomma);
}

/// Alle sichtbaren `Text`-Inhalte auf dem Schirm, für lose
/// Stichwort-Suchen, die keine einzelne Stelle im Baum kennen müssen.
List<String> _alleTexte(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(textOf).toList();

/// Alle `Text`-Nachfahren unter [key], als ein kleingeschriebener String —
/// für Stichwort-Treffer innerhalb eines festgelegten Abschnitts. Der
/// Schlüssel muss auf einem **Vorfahren** des Textes sitzen, nicht auf dem
/// Text selbst (siehe Dateikopf).
String _textUnter(WidgetTester tester, Key key) {
  return tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ')
      .toLowerCase();
}
