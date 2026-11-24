// Nachgezogene Zustandstests des Schritte-Schirms (#84, Review-Funde
// vom 18.11.2026) — eine **neue** Datei, weil die bestehende
// `schritte_view_test.dart` nach der Rollentrennung nicht angefasst wird.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung.** Diese Fälle
// entstanden aus dem Review und dem Entwurf (`docs/screens/screens/
// schritte.js`), vor der Korrektur; die Implementierung darf sie
// ausführen, aber nicht verändern.
//
// ## Die drei Funde, die hier festgenagelt werden
//
// 1. **„keine Vorwoche" darf nur dastehen, wenn es stimmt.** `StepStats.
//    trendPercent` ist auch dann `null`, wenn die Vorwoche **gemessen**
//    wurde und ihr Mittel 0 ist — „ein Anstieg von 0 ist kein Prozentsatz".
//    Sieben gemessene Ruhetage sind keine fehlende Vorwoche; der Zusatz
//    muss eine Aussage sein, die beide Fälle trägt. (`StepStats` reicht
//    das Vorwochenmittel nicht heraus; die View kann die beiden Ursachen
//    deshalb nicht unterscheiden und darf keine von beiden behaupten.)
// 2. **Im Leerzustand zeigt die Ø-7-Kachel das Entwurfs-Detail** „keine
//    Vorwoche" (`schritte.js`, Variante `leer`) — nicht nichts.
// 3. **„30 Tage ohne Messung" darf nur dastehen, wenn es keine Daten
//    gibt.** Ist allein der **laufende** Tag gemessen, existieren Daten;
//    das Kennzahlenfenster (Abstände 1–30) ist nur leer. Der Zusatz muss
//    das sagen, statt wie ein Leerzustand zu klingen.
//
// Dazu der vierte Fund, als Übergang: **Die Fußnote springt nicht.** Die
// Stufen-Fußnoten sind ungleich lang; nach der Hausregel „Mehrzeilige
// Erläuterungen bekommen eine feste Zeilenzahl" muss die Fußzeile beim
// Stufenwechsel ihre Höhe behalten — sonst rutscht alles darunter
// (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine Form").
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/koerper/schritte_view.dart';

void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit — dieselbe Uhr wie in
  // `schritte_view_test.dart`.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  ({ProviderContainer container, Widget app}) harness(
    Messwert<List<DailyMetrics>> tageswerte,
  ) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(() => _Tageswerte(tageswerte)),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: SchritteView()),
      ),
    );
  }

  /// Gerätenahe Breite, nicht die 900 der langen Schirme: Der
  /// Fußnoten-Fall unten vergleicht Umbruchhöhen, und auf 900 Punkten
  /// brächen beide Fassungen gar nicht um — der Test prüfte dann nichts.
  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String textOf(Text text) => text.data ?? text.textSpan!.toPlainText();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  Bekannt<List<DailyMetrics>> bekannt(List<DailyMetrics> tage) =>
      Bekannt<List<DailyMetrics>>(tage, stand: jetzt, laeuft: false);

  group('Der Trend-Zusatz der Ø-7-Kachel', () {
    testWidgets('eine gemessene Null-Vorwoche ist keine fehlende Vorwoche', (
      tester,
    ) async {
      // Tage 1–7 je 8.000, Tage 8–14 **gemessen mit 0** — sieben Ruhetage
      // auf dem Sofa. `trendPercent` ist `null` (ein Anstieg von 0 ist
      // kein Prozentsatz), aber „keine Vorwoche" wäre eine falsche
      // Auskunft über sieben gemessene Tage.
      final h = harness(
        bekannt([
          for (var abstand = 1; abstand <= 7; abstand++)
            DailyMetrics(tag: schluesselVor(abstand), steps: 8000),
          for (var abstand = 8; abstand <= 14; abstand++)
            DailyMetrics(tag: schluesselVor(abstand), steps: 0),
        ]),
      );
      await zeige(tester, h.app);

      final zusatz = textUnter(
        tester,
        const Key('schritte-kachel-schnitt7'),
      ).toLowerCase();
      expect(zusatz, isNot(contains('keine vorwoche')));
      expect(zusatz, contains('kein vergleich zur vorwoche'));
    });

    testWidgets('ohne gemessene Vorwoche steht derselbe Sammeltext', (
      tester,
    ) async {
      // Nur die Tage 1–7 gemessen. `StepStats` trägt kein Vorwochenmittel,
      // die View kann „nicht gemessen" und „Mittel 0" also nicht
      // unterscheiden — der Zusatz muss in beiden Fällen derselbe sein
      // und in beiden stimmen.
      final h = harness(
        bekannt([
          for (var abstand = 1; abstand <= 7; abstand++)
            DailyMetrics(tag: schluesselVor(abstand), steps: 8000),
        ]),
      );
      await zeige(tester, h.app);

      final zusatz = textUnter(
        tester,
        const Key('schritte-kachel-schnitt7'),
      ).toLowerCase();
      expect(zusatz, contains('kein vergleich zur vorwoche'));
    });

    testWidgets('im Leerzustand steht das Entwurfs-Detail „keine Vorwoche"', (
      tester,
    ) async {
      final h = harness(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
      await zeige(tester, h.app);

      expect(
        textUnter(
          tester,
          const Key('schritte-kachel-schnitt7'),
        ).toLowerCase(),
        contains('keine vorwoche'),
        reason: '`schritte.js`, Variante `leer`: detail „keine Vorwoche"',
      );
    });
  });

  group('Der Zusatz der Ziel-Kachel', () {
    testWidgets('„Tage ohne Messung" nur, wenn es wirklich keine Daten gibt', (
      tester,
    ) async {
      // Allein der **laufende** Tag ist gemessen: Es gibt Daten, nur keine
      // im Kennzahlenfenster (Abstände 1–30, der laufende Tag bleibt
      // draußen). „30 Tage ohne Messung" klänge wie ein Leerzustand.
      final h = harness(
        bekannt([DailyMetrics(tag: schluesselVor(0), steps: 5000)]),
      );
      await zeige(tester, h.app);

      expect(alleTexte(tester), isNot(contains('30 tage ohne messung')));
      final zusatz = textUnter(
        tester,
        const Key('schritte-kachel-ziel'),
      ).toLowerCase();
      expect(
        zusatz,
        contains('vor heute'),
        reason:
            'Das Fenster sind die 30 Tage **vor** heute — das darf der '
            'Zusatz sagen, einen Leerzustand darf er nicht behaupten',
      );
    });

    testWidgets('im Leerzustand bleibt der Entwurfstext stehen', (
      tester,
    ) async {
      final h = harness(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('schritte-kachel-ziel')).toLowerCase(),
        contains('30 tage ohne messung'),
        reason: '`schritte.js`, Variante `leer`',
      );
    });
  });

  group('Die Fußnote springt beim Stufenwechsel nicht', () {
    testWidgets('W → 6M behält die Höhe der Fußzeile', (tester) async {
      final h = harness(
        bekannt([
          for (var abstand = 1; abstand <= 14; abstand++)
            DailyMetrics(tag: schluesselVor(abstand), steps: 8000),
        ]),
      );
      await zeige(tester, h.app);

      final vorher = tester
          .getSize(find.byKey(const Key('diagramm-fussnote')))
          .height;

      await tester.tap(
        find.descendant(
          of: find.byType(Zeitraumleiste),
          matching: find.text('6M'),
        ),
      );
      await tester.pumpAndSettle();

      final nachher = tester
          .getSize(find.byKey(const Key('diagramm-fussnote')))
          .height;
      expect(
        nachher,
        vorher,
        reason:
            'Die Stufen-Fußnoten sind ungleich lang — ohne feste '
            'Zeilenzahl rutscht beim Stufenwechsel alles unter dem '
            'Diagramm („Mehrzeilige Erläuterungen bekommen eine feste '
            'Zeilenzahl", `CLAUDE.md`)',
      );
    });
  });
}

/// Steuerbarer Ableger des echten Notifiers — siehe `koerper_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}
