import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/verlauf_view.dart';
import 'package:repit/shell/verlauf_zustand.dart';

import '../design/support.dart' show textOf;

/// Tests für die **Oberfläche** der Verlaufsseiten (#94) —
/// `lib/shell/verlauf_view.dart`. Der Zustand darunter liegt in
/// `verlauf_zustand_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/verlauf_view.dart`)
///
/// ```dart
/// /// Öffnet den Verlauf einer Art auf dem Stapel des **aktuell
/// /// gewählten** Tabs.
/// void oeffneVerlauf(AppRouter router, VerlaufArt art);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [VerlaufView].
/// class VerlaufSeite extends StatelessWidget {
///   const VerlaufSeite({super.key, required VerlaufArt art});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class VerlaufView extends ConsumerWidget {
///   const VerlaufView({super.key, required VerlaufArt art});
/// }
/// ```
///
/// ## Der Erklärsatz ist der Inhalt
///
/// „Die Kurve zeigt, *dass* sich etwas bewegt, der Satz sagt, *was das
/// bedeutet*" (`verlauf.js:9–11`). Die vier Sätze aus
/// `TrendDetailView.swift:41–59` wandern **wörtlich** mit und gehören in die
/// View, nicht ins Kernpaket. Geprüft wird hier, dass jede der vier Arten
/// ihren **eigenen** trägt — nicht der Wortlaut, mit einer Ausnahme: Beim
/// Schlaf trägt der Satz eine Regel (die Schwelle liegt fest bei sechs
/// Stunden und hängt **nicht** am Schlafziel), und Regeln werden geprüft.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Layout, Farben, Beschriftungen.** `CLAUDE.md`: nur Zustände und
///   Übergänge.
/// - **Welcher Wert rot ist.** Die Regel dahinter (`istSignal`, auf der
///   richtigen Seite der Schwelle für alle vier) steht in
///   `verlauf_zustand_test.dart` und wird dort gegen
///   `RecoveryTrafficLight` selbst geprüft. Eine Farbe im Widget-Baum
///   nachzumessen wäre dieselbe Aussage, nur schlechter.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? atem = 13,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atem,
    exerciseMinutes: 20,
  );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, tag, 4);
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: const [],
    );
  }

  List<DailyMetrics> tage({
    int? ruhepulsHeute = 52,
    double? hrvHeute = 60,
    double? atemHeute = 13,
  }) => [
    for (var t = 5; t <= 11; t++) tagwert(t),
    tagwert(12, ruhepuls: ruhepulsHeute, hrv: hrvHeute, atem: atemHeute),
  ];

  List<SleepNight> naechte() => [
    for (var t = 5; t <= 12; t++) nachtVon(t),
  ];

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

  ({ProviderContainer container, AppRouter router, Widget app}) harness(
    VerlaufArt art, {
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
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

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: mitSeite
                  ? VerlaufSeite(art: art)
                  : VerlaufView(art: art),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

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

  Zeitraumleiste leiste(WidgetTester tester) =>
      tester.widget<Zeitraumleiste>(find.byType(Zeitraumleiste));

  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets('der Schirm bringt weder Gerüst noch Leiste mit', (
      tester,
    ) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(VerlaufView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
    });

    testWidgets('die Seite bringt beides mit', (tester) async {
      final h = harness(VerlaufArt.hrv, mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('der Abstand kommt aus `GlasAbstand`', (tester) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(VerlaufView),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final erwartet = GlasAbstand.of(tester.element(find.byType(VerlaufView)));
      expect(erwartet.top, greaterThan(0), reason: 'sonst prüft das nichts');
      final padding = scroll.padding! as EdgeInsets;
      expect(padding.top, erwartet.top);
    });

    testWidgets('alle vier Arten sind erreichbar und tragen ihre Art', (
      tester,
    ) async {
      for (final art in VerlaufArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);
        final tabVorher = h.router.tab;

        oeffneVerlauf(h.router, art);
        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull, reason: '$art');
        expect(befehl!.ersetztStapel, isFalse, reason: '$art');
        expect(befehl.tab, tabVorher, reason: '$art');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(home: Builder(builder: befehl.builder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<VerlaufView>(find.byType(VerlaufView)).art,
          art,
          reason:
              '$art: welcher Wert gemeint ist, trägt das Ziel als Parameter '
              '— alle vier auf denselben Schirm zu schicken war die '
              'Platzhalter-Lösung',
        );
      }
    });
  });

  group('Der Erklärsatz', () {
    testWidgets('jede der vier Arten trägt einen eigenen', (tester) async {
      final gesehen = <VerlaufArt, String>{};

      for (final art in VerlaufArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);
        final satz = textUnter(tester, const Key('verlauf-erklaerung'));
        expect(satz.trim(), isNotEmpty, reason: '$art');
        gesehen[art] = satz;
      }

      expect(
        gesehen.values.toSet(),
        hasLength(VerlaufArt.values.length),
        reason:
            'Die vier Sätze sind der eigentliche Inhalt dieses Schirms. Vier '
            'gleiche wären vier leere',
      );
    });

    testWidgets(
      'der Schlaf-Satz nennt die feste Schwelle und dass sie nicht am '
      'Schlafziel hängt',
      (tester) async {
        final h = harness(VerlaufArt.schlaf);
        await zeige(tester, h.app);

        final satz = textUnter(
          tester,
          const Key('verlauf-erklaerung'),
        ).toLowerCase();
        expect(satz, contains('sechs stunden'));
        expect(
          satz,
          contains('schlafziel'),
          reason:
              'Die Sechs-Stunden-Grenze ist fest und hängt **nicht** am '
              'Schlafziel (`docs/SPEC.md` 4.6). Das ist eine Regel, kein '
              'Wortlaut — wer sie wegkürzt, lädt die Verwechslung ein',
        );
      },
    );
  });

  group('Die Kopfzeile behauptet keinen Zeitraum', () {
    testWidgets('kein „30 Tage" über dem Diagramm', (tester) async {
      for (final art in VerlaufArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);

        expect(
          textUnter(tester, const Key('diagramm-kopfzeile')).toLowerCase(),
          isNot(contains('30 tage')),
          reason:
              '$art: „Seit der Zeitraum wählbar ist, wäre „30 Tage" eine '
              'Behauptung über einen Ausschnitt, den der Nutzer gerade '
              'verstellt hat" (`TrendDetailView.swift:18–19`)',
        );
      }
    });

    testWidgets('der aktuelle Wert steht als eigene Zeile darunter', (
      tester,
    ) async {
      final h = harness(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(hrvHeute: 44),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('verlauf-aktuell')),
        contains('44'),
        reason:
            'Die Kopfzeile zeigt den Fensterschnitt, der aktuelle Wert steht '
            'als eigene Zeile. Beides in der großen Zeile ginge nicht; dann '
            'wäre sie keine Kopfzeile mehr',
      );
    });
  });

  group('Die Einordnung', () {
    testWidgets('vier Zeilen: Aktuell, Median, Signal ab, Spanne', (
      tester,
    ) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      final text = textUnter(
        tester,
        const Key('verlauf-einordnung'),
      ).toLowerCase();
      for (final zeile in const [
        'aktuell',
        'median',
        'signal ab',
        'spanne',
      ]) {
        expect(text, contains(zeile));
      }
    });

    testWidgets('die Einheit steht einmal, nicht zweimal', (tester) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      final aktuell = textUnter(tester, const Key('verlauf-aktuell'));
      expect(
        RegExp('ms').allMatches(aktuell).length,
        1,
        reason:
            '`unitLabel` bleibt leer, weil das Format die Einheit mitbringt '
            '— sonst steht dort „46 ms ms" '
            '(`TrendDetailView.swift:110–113`)',
      );
    });

    testWidgets('ohne Median steht dort kein erfundener Wert', (tester) async {
      final h = harness(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(11), tagwert(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final text = textUnter(
        tester,
        const Key('verlauf-einordnung'),
      ).toLowerCase();
      expect(
        text.contains('—') || text.contains('kein median'),
        isTrue,
        reason: 'Eine erfundene Schwelle wäre schlimmer als gar keine',
      );
    });

    testWidgets('beim Schlaf steht die Schwelle auch ohne Median', (
      tester,
    ) async {
      final h = harness(
        VerlaufArt.schlaf,
        schlaf: Bekannt<List<SleepNight>>(
          [nachtVon(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('verlauf-einordnung')),
        contains('6'),
        reason:
            'Nur der Schlaf hat eine feste Schwelle — sie hängt nicht am '
            'Median und fällt deshalb nicht mit ihm weg',
      );
    });
  });

  group('Das Diagramm', () {
    testWidgets('die Leiste trägt W M 6M J', (tester) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      expect(leiste(tester).stufen, verlaufsStufen);
      expect(leiste(tester).stufen, contains(DiagrammStufe.jahr));
    });

    testWidgets('beim Aufschlagen ist die erste Stufe gewählt (#7)', (
      tester,
    ) async {
      for (final art in VerlaufArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);
        expect(leiste(tester).gewaehlt, verlaufsStufen.first, reason: '$art');
      }
    });

    testWidgets('Schlaf als Balken, die übrigen drei als Linie', (
      tester,
    ) async {
      for (final art in VerlaufArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);

        expect(
          tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm)).alsBalken,
          art == VerlaufArt.schlaf,
          reason: '$art (`TrendDetailView.swift:109`)',
        );
      }
    });

    testWidgets('Median und Schwelle stehen als Linien im Diagramm', (
      tester,
    ) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      final linien = tester
          .widget<Zeitdiagramm>(find.byType(Zeitdiagramm))
          .linien;
      expect(linien, hasLength(2));
      expect(
        linien.map((l) => l.wert),
        containsAll(<Matcher>[
          closeTo(60, 1e-9),
          closeTo(60 * RecoveryTrafficLight.hrvFactor, 1e-9),
        ]),
      );
    });

    testWidgets('ohne Median bleibt nur die Reihe, keine erfundene Linie', (
      tester,
    ) async {
      final h = harness(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(11), tagwert(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm)).linien,
        isEmpty,
      );
    });

    testWidgets('ab 6M nennt die Fußzeile den Monatsdurchschnitt', (
      tester,
    ) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(
        textUnter(tester, const Key('diagramm-fussnote')).toLowerCase(),
        contains('durchschnitt'),
        reason:
            'Je Punkt ein Monat, gezeigt wird der Durchschnitt — das muss '
            'dastehen (`TrendDetailView.swift:114–118`)',
      );
    });
  });

  group('Die vier Zustände', () {
    testWidgets(
      'während des Ladens steht nirgends ein „keine Daten"-Grund '
      '(docs/todo/01)',
      (tester) async {
        final h = harness(
          VerlaufArt.hrv,
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        );
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        expect(texte.contains('keine werte'), isFalse);
        expect(texte.contains('nichts aufgezeichnet'), isFalse);
        expect(find.byKey(const Key('verlauf-laden')), findsOneWidget);
      },
    );

    testWidgets('ein gescheiterter Lauf sagt nicht, es gäbe keine Daten', (
      tester,
    ) async {
      final h = harness(
        VerlaufArt.hrv,
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
        schlaf: Fehlgeschlagen<List<SleepNight>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(
        alleTexte(tester).contains('nichts aufgezeichnet'),
        isFalse,
        reason: 'Ein Fehler ist keine Aussage über die Datenlage',
      );
    });

    testWidgets(
      'eine leere Reihe nennt beide Möglichkeiten und zeigt kein Diagramm',
      (tester) async {
        final h = harness(
          VerlaufArt.hrv,
          tageswerte: Bekannt<List<DailyMetrics>>(
            [tagwert(12, hrv: null)],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final leer = textUnter(
          tester,
          const Key('verlauf-leer'),
        ).toLowerCase();
        expect(
          leer.contains('aufgezeichnet'),
          isTrue,
          reason: 'die eine Möglichkeit',
        );
        expect(
          leer.contains('lesen') || leer.contains('freigegeben'),
          isTrue,
          reason:
              'die andere — Apple verrät den Unterschied nicht '
              '(`verlauf.js:75–83`)',
        );
        expect(
          find.byType(Zeitdiagramm),
          findsNothing,
          reason: 'eine leere Fläche mit Achsen behauptet, es gäbe eine Kurve',
        );
        expect(
          leer.contains('0'),
          isFalse,
          reason: 'Fehlender Wert heißt „—", nie „0"',
        );
      },
    );

    testWidgets('und sie nennt, um welchen Wert es geht', (tester) async {
      final h = harness(
        VerlaufArt.atemfrequenz,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(12, atem: null)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('verlauf-leer')).toLowerCase(),
        contains('atem'),
        reason:
            'Vier Schirme mit demselben Satz sagen nicht, welcher von ihnen '
            'leer ist',
      );
    });

    testWidgets(
      'ein gescheiterter Nachlauf nimmt den sichtbaren Wert nicht weg (#32)',
      (tester) async {
        final h = harness(
          VerlaufArt.hrv,
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
        );
        await zeige(tester, h.app);

        expect(textUnter(tester, const Key('verlauf-aktuell')), contains('60'));
      },
    );
  });

  group('Die Fußnote', () {
    testWidgets('sie nennt Apple Health und ist keine Diagnose', (
      tester,
    ) async {
      final h = harness(VerlaufArt.hrv);
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('apple health'));
      expect(
        texte.contains('schätzung') || texte.contains('medizinisch'),
        isTrue,
        reason:
            '`CLAUDE.md`: keine Diagnosen — jeder Gesundheitswert ist als '
            'Schätzung zu kennzeichnen',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`.
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
