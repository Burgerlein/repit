import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/shell/erholung_werte_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;

/// Tests für den **Schirm** `erholung-werte` (#117) —
/// `lib/shell/erholung_werte_view.dart`. Der Zustand darunter liegt in
/// `erholung_werte_zustand_test.dart`; die Trennung ist dieselbe wie bei
/// `erholung_view_test.dart` / `erholung_zustand_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/erholung_werte_view.dart`)
///
/// ```dart
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// ///
/// /// **Er besorgt seine Daten selbst** (`erholungProvider`): Jeder Schirm
/// /// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen,
/// /// dass eine Übersicht vorher geladen hat.
/// class ErholungWerteView extends ConsumerWidget {
///   const ErholungWerteView({super.key});
/// }
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [ErholungWerteView].
/// class ErholungWerteSeite extends StatelessWidget {
///   const ErholungWerteSeite({super.key});
/// }
///
/// /// Öffnet `erholung-werte` auf dem Stapel des **aktuell gewählten**
/// /// Tabs — die eine Stelle, die das weiß. Neu am 28.10.2026.
/// void oeffneErholungWerte(AppRouter router);
/// ```
///
/// Die Werttypen und reinen Funktionen, aus denen der Schirm gebaut wird,
/// stehen in `lib/shell/erholung_werte_zustand.dart` — ihre API legt
/// `erholung_werte_zustand_test.dart` fest.
///
/// ## Nachtrag 28.10.2026 — die Tür ist umgehängt
///
/// Bis heute stand hier: „Die Tür wird hier nicht umgehängt. `ErholungTuer
/// .werte` führt weiterhin auf `ErholungTuerPlatzhalter`." Das stimmt nicht
/// mehr. Der mittlere Ring des Erholung-Schirms führt auf
/// [ErholungWerteSeite]; festgelegt ist das in `erholung_view_test.dart`,
/// Nachtrag vom 28.10.2026, wo auch `ErholungTuer` und der Platzhalter
/// selbst wegfallen.
///
/// Dazu kommt **eine neue Funktion** in `lib/shell/erholung_werte_view.dart`
/// (siehe API oben). Warum nicht einfach ein `router.open(...)` im
/// Erholung-Schirm: Jedes andere Ziel dieses Bereichs hat seine eigene
/// solche Stelle — `oeffneSchlaf`, `oeffneTagschlaf`, `oeffneBelastung`,
/// `oeffneVerlauf` —, und sie ist jeweils die einzige, die
/// `AppTarget.aktuell` kennt. Dieses eine Ziel davon auszunehmen hieße,
/// dieselbe Entscheidung an zwei Orten zu treffen; der nächste Aufrufer
/// träfe sie neu, und einer von beiden würde sie falsch treffen.
///
/// *(Entscheidung des Test-Agenten dieses Durchgangs, mit Begründung —
/// nicht mit Tim abgestimmt.)*
///
/// ## Die Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt — dieselbe Begründung wie bei den acht
/// Schlüsseln in `erholung_view_test.dart`:
///
/// - `Key('erholung-werte-karte')` — die Statuskarte. **Steht in jedem
///   Zustand.**
/// - `Key('erholung-werte-zeile-<metrik>')` — eine der vier Wertzeilen
///   darin; `<metrik>` ist `RecoveryMetric.name`, also `sleep`,
///   `restingHeartRate`, `hrv`, `respiratoryRate`.
/// - `Key('erholung-werte-balken-<metrik>')` — der Balken hinter dem Wert.
///   **Fehlt ohne Median.**
/// - `Key('erholung-werte-health-einstellungen')` — der Weg in die
///   Health-Einstellungen, nur wenn nichts vorliegt.
/// - `Key('erholung-werte-band')` — das Signalband der letzten 30 Tage.
/// - `Key('erholung-werte-band-tag-<i>')` — **ein Tagesbalken**, `i` ab 0,
///   ältester zuerst, je einer pro Eintrag in
///   `RecoverySnapshot.signalHistory`. Der Schlüssel sitzt auf dem Balken
///   selbst: Seine **gerenderte Höhe** trägt die Regel „gemessen → 30 +
///   Signale · 14, nicht gemessen → 10", und genau die liest dieser Test.
/// - `Key('erholung-werte-schwellen')` — die Karte „Die Schwellen".
/// - `Key('erholung-werte-fuss')` — die Fußnote. Eigener Schlüssel, weil
///   der Erklärsatz unter der Karte derselbe Baustein ist und beide sonst
///   nicht auseinanderzuhalten wären.
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: **Zustände und Übergänge**, nicht Layout und Beschriftung.
/// Wo ein Text eine *Regel* trägt, wird die Regel geprüft:
///
/// - Die Karte steht in allen vier Zuständen von `Messwert`.
/// - Während des Ladens steht nirgends ein „keine Daten"-Grund
///   (`docs/todo/01`).
/// - Bei fehlenden Daten stehen **beide** Möglichkeiten und der Weg in die
///   Health-Einstellungen.
/// - Ein fehlender Einzelwert steht als „—", nie als „0".
/// - Ohne Median fehlt der Balken, und „kein Normalbereich" steht da.
/// - Das Band unterscheidet den grauen Stummel vom grünen Balken.
/// - Die Fußnote ist der Ampel-Satz, **nicht** die Health-Fußnote. Der
///   Entwurf wiederholt an dieser Stelle die falsche.
///
/// **Nicht geprüft, bewusst:**
///
/// - Farben. Die Zuordnung Zustand → Farbe steht als reine Funktion in
///   `erholung_werte_zustand_test.dart`; ein Widget-Test, der eine
///   aufgelöste Farbe aus dem Baum fischt, prüfte nebenbei, in welchem
///   Widget sie steckt.
/// - Überschrift, Unterzeile, Erklärsatz und die Beschriftung der
///   Schwellenregeln.
/// - Der `postOperative`-Zweig: Der Schirm kann ihn heute nicht erzeugen
///   (Spec Abschnitt 9, #41 fehlt). Er ist ohne Widget geprüft.
/// - Dass der Health-Knopf `x-apple-health://` öffnet — `app/` hat kein
///   `url_launcher`, und ein Widget-Test sähe einen geöffneten URL nicht.
///   Der Knopf wird deshalb auch nicht angetippt.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int t) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, t));

  String tagKey(int t) => '2026-10-${t.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int t, {
    int? puls = 54,
    double? hrv = 60,
    double? atmung = 14,
  }) => DailyMetrics(
    tag: tagKey(t),
    restingHR: puls,
    hrvMs: hrv,
    respRate: atmung,
    exerciseMinutes: 20,
  );

  /// Ein Tag, an dem nichts aufgezeichnet wurde. Kein Feld steht auf Null —
  /// die Felder fehlen.
  DailyMetrics leererTag(int t) => DailyMetrics(tag: tagKey(t));

  SleepNight nachtVon(int t, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, t, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(t),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
    );
  }

  /// Zehn ruhige Tage, der letzte ist heute.
  List<DailyMetrics> tage() => [for (var t = 3; t <= 12; t++) tagwert(t)];
  List<SleepNight> naechte() => [for (var t = 3; t <= 12; t++) nachtVon(t)];

  /// Neun Tage, heute keiner — die Ampel steht auf `noData`, und
  /// „zuletzt gesehen" trägt den 11.10.
  List<DailyMetrics> tageOhneHeute() => [
    for (var t = 3; t <= 11; t++) tagwert(t),
  ];
  List<SleepNight> naechteOhneHeute() => [
    for (var t = 3; t <= 11; t++) nachtVon(t),
  ];

  /// Vier Tage vor heute reichen für keinen Median (fünf sind nötig) —
  /// heute liegen Werte vor.
  List<DailyMetrics> tageOhneMedian() => [
    for (var t = 3; t <= 6; t++) tagwert(t),
    tagwert(12),
  ];
  List<SleepNight> naechteOhneMedian() => [
    for (var t = 3; t <= 6; t++) nachtVon(t),
    nachtVon(12),
  ];

  /// Zehn Tage für das Band: Der 7.10. ist **nicht gemessen** (kein
  /// Tageswert, keine Nacht), in der Nacht auf den 10.10. waren es nur
  /// fünf Stunden — ein Warnsignal, und zwar das einzige.
  List<DailyMetrics> bandTage() => [
    for (var t = 3; t <= 12; t++)
      if (t == 7) leererTag(t) else tagwert(t),
  ];
  List<SleepNight> bandNaechte() => [
    for (var t = 3; t <= 12; t++)
      if (t != 7) nachtVon(t, stunden: t == 10 ? 5 : 7),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

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
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    bool mitSeite = false,
  }) {
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(() => _Tageswerte(tagesWert)),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster. Ohne diese Überschreibung liefe ein Widget-Test in
        // die echte drift-Datenbank — und die drei Werte blieben leer.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(tagesWert)),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  naechte(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);

    final inhalt = mitSeite
        ? const ErholungWerteSeite()
        : const ErholungWerteView();

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              // Entspricht der durchscheinenden Navigations- und Tableiste:
              // Nur mit echten Rändern hat `GlasAbstand` etwas zu tun.
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
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist und kein
    // Test selbst scrollen muss.
    tester.view.physicalSize = const Size(900, 4200);
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

  Key karte() => const Key('erholung-werte-karte');
  Key zeile(RecoveryMetric m) => Key('erholung-werte-zeile-${m.name}');
  Key balken(RecoveryMetric m) => Key('erholung-werte-balken-${m.name}');
  Key band() => const Key('erholung-werte-band');
  Key bandTag(int i) => Key('erholung-werte-band-tag-$i');
  Key schwellen() => const Key('erholung-werte-schwellen');
  Key fuss() => const Key('erholung-werte-fuss');

  // ───────────────────────────────────────────────────────────────────────

  group('Die Statuskarte verschwindet in keinem Zustand', () {
    /// Der Kern des Tickets: Platz, Form und Position bleiben, nur Inhalt
    /// und Kantenfarbe wechseln. Eine fehlende Karte hieße gleichzeitig
    /// „alles gut", „die Uhr hat nichts aufgezeichnet" und „die App darf
    /// nicht lesen" — den Unterschied verrät HealthKit nicht.
    final lagen =
        <
          String,
          ({
            Messwert<List<DailyMetrics>>? tage,
            Messwert<List<SleepNight>>? schlaf,
          })
        >{
          'alles ruhig': (tage: null, schlaf: null),
          'noch nie gelesen': (
            tage: const NochNie<List<DailyMetrics>>(),
            schlaf: const NochNie<List<SleepNight>>(),
          ),
          'leer nach Lauf': (
            tage: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
            schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
          ),
          'Lauf gescheitert': (
            tage: Fehlgeschlagen<List<DailyMetrics>>(
              fehler: Exception('kein Kanal'),
              gelaufen: jetzt,
            ),
            schlaf: Fehlgeschlagen<List<SleepNight>>(
              fehler: Exception('kein Kanal'),
              gelaufen: jetzt,
            ),
          ),
        };

    for (final MapEntry(key: name, value: lage) in lagen.entries) {
      testWidgets('$name: die Karte steht da', (tester) async {
        final h = harness(tageswerte: lage.tage, schlaf: lage.schlaf);
        await zeige(tester, h.app);

        expect(find.byKey(karte()), findsOneWidget, reason: name);
        for (final metrik in RecoveryMetric.values) {
          expect(
            find.byKey(zeile(metrik)),
            findsOneWidget,
            reason: '$name / ${metrik.name}',
          );
        }
      });
    }

    testWidgets('auch wenn heute nichts vorliegt', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tageOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechteOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(karte()), findsOneWidget);
    });
  });

  group('Während des Ladens steht kein „keine Daten"-Grund', () {
    /// `docs/todo/01`. Die Karte steht auch hier — und gerade deshalb darf
    /// sie nicht behaupten, es gebe nichts.
    testWidgets('weder Grund noch Knopf noch Zahlen', (tester) async {
      final h = harness(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        schlaf: const NochNie<List<SleepNight>>(),
      );
      await zeige(tester, h.app);

      final text = alleTexte(tester);
      expect(text, isNot(contains('aufgezeichnet')));
      expect(text, isNot(contains('freigegeben')));
      expect(text, isNot(contains('kein normalbereich')));
      expect(text, isNot(contains('kein median')));
      expect(
        find.byKey(const Key('erholung-werte-health-einstellungen')),
        findsNothing,
      );
    });

    testWidgets(
      'was Daten braucht, erscheint erst mit Daten — Band und Schwellen',
      (tester) async {
        final h = harness(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        );
        await zeige(tester, h.app);

        expect(find.byKey(band()), findsNothing);
        expect(find.byKey(schwellen()), findsNothing);
      },
    );

    testWidgets('ein gescheiterter Lauf behauptet ebenfalls nichts', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: Exception('kein Kanal'),
          gelaufen: jetzt,
        ),
        schlaf: Fehlgeschlagen<List<SleepNight>>(
          fehler: Exception('kein Kanal'),
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      final text = alleTexte(tester);
      expect(text, isNot(contains('aufgezeichnet')));
      expect(text, isNot(contains('freigegeben')));
      expect(
        find.byKey(const Key('erholung-werte-health-einstellungen')),
        findsNothing,
      );
    });

    testWidgets('ein laufender Nachlauf nimmt keinen Wert weg', (tester) async {
      // `docs/todo/32`: Was dasteht, bleibt stehen, während nachgeladen
      // wird.
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(),
          stand: jetzt,
          laeuft: true,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechte(),
          stand: jetzt,
          laeuft: true,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(karte()), findsOneWidget);
      expect(find.byKey(band()), findsOneWidget);
      expect(find.byKey(schwellen()), findsOneWidget);
      expect(
        textUnter(tester, zeile(RecoveryMetric.restingHeartRate)),
        contains('54'),
      );
    });
  });

  group('Fehlen die Werte, stehen beide Möglichkeiten da', () {
    testWidgets('beide Wörter und der Weg in die Health-Einstellungen', (
      tester,
    ) async {
      for (final lage in [
        (
          tage: Bekannt<List<DailyMetrics>>(
            tageOhneHeute(),
            stand: jetzt,
            laeuft: false,
          ),
          schlaf: Bekannt<List<SleepNight>>(
            naechteOhneHeute(),
            stand: jetzt,
            laeuft: false,
          ),
        ),
        (
          tage: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        ),
      ]) {
        final h = harness(tageswerte: lage.tage, schlaf: lage.schlaf);
        await zeige(tester, h.app);

        final text = alleTexte(tester);
        expect(text, contains('aufgezeichnet'));
        expect(text, contains('freigegeben'));
        expect(
          find.byKey(const Key('erholung-werte-health-einstellungen')),
          findsOneWidget,
        );
      }
    });

    testWidgets('jeder fehlende Einzelwert steht als „—", nie als „0"', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tageOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechteOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      for (final metrik in RecoveryMetric.values) {
        final text = textUnter(tester, zeile(metrik));
        expect(text, contains(keinWert), reason: metrik.name);
        expect(text, isNot(contains('0 bpm')), reason: metrik.name);
        expect(text, isNot(contains('0 ms')), reason: metrik.name);
      }
    });

    testWidgets('und trägt keinen Balken, auch mit Median', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tageOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechteOhneHeute(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      for (final metrik in RecoveryMetric.values) {
        expect(find.byKey(balken(metrik)), findsNothing, reason: metrik.name);
      }
    });
  });

  group('Fehlt der Median, fällt der Balken ganz weg', () {
    testWidgets('kein Balken, dafür „kein Normalbereich"', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tageOhneMedian(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechteOhneMedian(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      for (final metrik in RecoveryMetric.values) {
        expect(find.byKey(balken(metrik)), findsNothing, reason: metrik.name);
        expect(
          textUnter(tester, zeile(metrik)).toLowerCase(),
          contains('kein normalbereich'),
          reason: metrik.name,
        );
      }
    });

    testWidgets('mit Median trägt jeder der vier Werte einen Balken', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      for (final metrik in RecoveryMetric.values) {
        expect(find.byKey(balken(metrik)), findsOneWidget, reason: metrik.name);
      }
    });
  });

  group('Das Band unterscheidet „kein Signal" von „nicht gemessen"', () {
    Future<void> zeigeBand(WidgetTester tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          bandTage(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          bandNaechte(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);
    }

    testWidgets('je ein Balken pro Tag der Signalhistorie, ältester zuerst', (
      tester,
    ) async {
      await zeigeBand(tester);

      expect(find.byKey(band()), findsOneWidget);
      // Zehn Tage, 3.10. bis 12.10.
      for (var i = 0; i < 10; i++) {
        expect(find.byKey(bandTag(i)), findsOneWidget, reason: 'Tag $i');
      }
      expect(find.byKey(bandTag(10)), findsNothing);
    });

    testWidgets('ein grauer Stummel ist etwas anderes als ein grüner Balken', (
      tester,
    ) async {
      await zeigeBand(tester);

      // Index 4 ist der 7.10. — kein Tageswert, keine Nacht.
      expect(tester.getSize(find.byKey(bandTag(4))).height, 10);
      // Index 0 ist der 3.10. — gemessen, kein Signal: 30 + 0 · 14.
      expect(tester.getSize(find.byKey(bandTag(0))).height, 30);
    });

    testWidgets('die Höhe ist die Zahl der Signale am Tag', (tester) async {
      await zeigeBand(tester);

      // Index 7 ist der 10.10. — fünf Stunden Schlaf, also ein Signal:
      // 30 + 1 · 14.
      expect(tester.getSize(find.byKey(bandTag(7))).height, 44);
      // Der Tag davor und der danach sind ruhig.
      expect(tester.getSize(find.byKey(bandTag(6))).height, 30);
      expect(tester.getSize(find.byKey(bandTag(8))).height, 30);
    });

    testWidgets('die Legende nennt die drei Fälle', (tester) async {
      await zeigeBand(tester);

      final text = textUnter(tester, band()).toLowerCase();
      expect(text, contains('ohne signal'));
      expect(text, contains('ein signal'));
      expect(text, contains('zwei und mehr'));
    });
  });

  group('Die Schwellen', () {
    testWidgets('vier Zeilen mit Regel und ausgerechnetem Wert', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final text = textUnter(tester, schwellen());
      // Ruhepuls: Median 54, Zuschlag aus dem Kern.
      expect(
        text,
        contains(
          '${(54 + RecoveryTrafficLight.restingHeartRateMargin).round()}',
        ),
      );
      // HRV: Median 60, Faktor aus dem Kern.
      expect(
        text,
        contains('${(60 * RecoveryTrafficLight.hrvFactor).round()}'),
      );
      // Schlaf: feste Grenze, unabhängig vom Schlafziel.
      expect(
        text,
        contains(stundenText(RecoveryTrafficLight.minimumSleepHours)),
      );
      expect(text.toLowerCase(), isNot(contains('kein median')));
    });

    testWidgets('ohne Median steht „kein Median" — außer beim Schlaf', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tageOhneMedian(),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechteOhneMedian(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final text = textUnter(tester, schwellen());
      expect(text.toLowerCase(), contains('kein median'));
      expect(
        text,
        contains(stundenText(RecoveryTrafficLight.minimumSleepHours)),
        reason: 'die Schlafgrenze steht fest und braucht keinen Median',
      );
    });
  });

  group('Die Fußnote ist der Ampel-Satz, nicht die Health-Fußnote', () {
    testWidgets('sie nennt die Schwelle „ab zwei Signalen"', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final text = textUnter(tester, fuss()).toLowerCase();
      expect(text, contains('zwei signalen'));
      expect(text, contains('stress'));
    });

    testWidgets(
      'und wiederholt nicht die Health-Fußnote des Erholung-Schirms',
      (tester) async {
        // Der Entwurf setzt an dieser Stelle `disclaimer(FUSS)` mit dem
        // Apple-Health-Satz — ein bekannter Fehler des Boards.
        final h = harness();
        await zeige(tester, h.app);

        final text = textUnter(tester, fuss()).toLowerCase();
        expect(text, isNot(contains('apple health')));
        expect(text, isNot(contains('freigabe')));
      },
    );

    testWidgets('die Fußnote steht genau einmal', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(fuss()), findsOneWidget);
    });
  });

  group('Rahmen und Hausordnung', () {
    testWidgets(
      'ErholungWerteView bringt weder Gerüst noch Leiste noch Navigator mit',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          find.descendant(
            of: find.byType(ErholungWerteView),
            matching: find.byType(CupertinoPageScaffold),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ErholungWerteView),
            matching: find.byType(CupertinoNavigationBar),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ErholungWerteView),
            matching: find.byType(Navigator),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('ErholungWerteSeite stellt genau diesen Rahmen', (
      tester,
    ) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(ErholungWerteView), findsOneWidget);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    // Siehe Nachtrag im Dateikopf vom 28.10.2026. Derselbe Fall steht
    // wörtlich so in `belastung_view_test.dart` und `schlaf_view_test.dart`
    // — er ist der Wächter dafür, dass ein Detailziel nie von sich aus den
    // Tab wechselt (`CLAUDE.md`).
    testWidgets('`oeffneErholungWerte` schiebt auf den Stapel des '
        'aktuellen Tabs', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final router = AppRouter();
      final tabVorher = router.tab;

      oeffneErholungWerte(router);
      final befehl = router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(
        router.tab,
        tabVorher,
        reason:
            'Ein Detailziel wechselt nie von sich aus den Tab — sonst '
            'führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat',
      );
      expect(befehl!.ersetztStapel, isFalse, reason: 'geschoben, nicht '
          'ersetzt');
      expect(befehl.tab, tabVorher);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ErholungWerteView), findsOneWidget);
    });

    testWidgets(
      'der Glas-Abstand liegt als padding im SingleChildScrollView, nicht '
      'als äußere Padding — sonst schrumpft der Viewport statt des Inhalts',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final scroll = tester.widget<SingleChildScrollView>(
          find
              .descendant(
                of: find.byType(ErholungWerteView),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        );
        final erwartet = GlasAbstand.of(
          tester.element(find.byType(ErholungWerteView)),
        );

        expect(scroll.padding, isNotNull);
        final padding = scroll.padding! as EdgeInsets;
        expect(padding.top, erwartet.top);
        expect(padding.bottom, greaterThanOrEqualTo(erwartet.bottom));
        expect(
          erwartet.top,
          greaterThan(0),
          reason: 'sonst prüft dieser Test gar nichts',
        );
        expect(
          find.descendant(
            of: find.byType(ErholungWerteView),
            matching: find.byType(GlasRand),
          ),
          findsNothing,
          reason: 'GlasRand ist die Variante für nicht scrollende Schirme',
        );
      },
    );

    testWidgets('der Schirm besorgt seine Daten selbst', (tester) async {
      // Kein Erholung-Schirm davor, kein Vorladen: Seit jeder Schirm aus
      // jedem Tab erreichbar ist, darf sich niemand darauf verlassen, dass
      // eine Übersicht vorher geladen hat.
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(band()), findsOneWidget);
      expect(
        textUnter(tester, zeile(RecoveryMetric.restingHeartRate)),
        contains('54'),
      );
    });
  });
}

class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

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

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
