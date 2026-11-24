import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_abschnitte.dart'
    show SchlafNaechteDiagramm;
import 'package:repit/shell/schlaf_auswahl.dart';
import 'package:repit/shell/schlaf_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für **„Sieben Nächte" steht wieder offen** (#257) —
/// `lib/shell/schlaf_view.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Tim am 03.11.2026: „Sieben Nächte nicht ein- und ausklappen, das hast du
/// falsch verstanden." Bei #253 war der Abschnitt mit den drei anderen
/// eingeklappt worden; das war die Auslegung einer Rückfrage, nicht Tims
/// Wunsch. Die Korrektur gilt.
///
/// Danach steht der Schirm so:
///
/// 1. Schlafphasen, Herzfrequenz, Atemfrequenz — die Diagramme der Nacht
/// 2. **Sieben Nächte, offen**, mit eigener Überschrift
/// 3. drei Klappzeilen, zugeklappt: Letzte 7 Nächte bis heute · Letzte 30
///    Nächte bis heute · Verlauf
///
/// „Sieben Nächte" ist ein Bild, kein Textblock — zwischen drei Textzeilen
/// gehört es nicht hin. Die Stelle ist entschieden, nicht geraten, und
/// deshalb wird sie hier geprüft; sonst prüft diese Datei keine Anordnung.
///
/// ## Die Schlüssel
///
/// - `Key('schlaf-naechte')` sitzt wieder auf der **Karte** mit dem
///   Diagramm. Er bleibt, wo er war — `schlaf_wischen_test.dart` und
///   `schlaf_leerer_tag_test.dart` greifen darüber zu.
/// - `Key('schlaf-naechte-kopf')` und `Key('schlaf-naechte-inhalt')` gibt
///   es **nicht mehr**: Es gibt keine Klappzeile, also auch keinen Kopf und
///   keinen eingeklappten Inhalt.
/// - Die drei übrigen behalten ihre drei Schlüssel unverändert.
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Zustände und Übergänge. Kein Test schreibt einen Wortlaut,
/// eine Höhe oder eine Farbe fest. Geprüft wird:
///
/// - Das Diagramm steht beim Öffnen des Schirms im Baum, **ohne dass
///   jemand tippt**.
/// - Es gibt nichts zum Zuklappen.
/// - Die drei übrigen Abschnitte sind weiterhin zugeklappt und lassen sich
///   aufklappen.
/// - Beide Wege des Schirms tragen den offenen Abschnitt — der mit Nacht
///   und der für einen leeren Tag (#177).
/// - Die Stelle: hinter der Atemfrequenz, vor der ersten Klappzeile.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt. Keine stammt aus einem Health-Export
/// oder einem Screenshot (`CLAUDE.md`).
void main() {
  // Donnerstag, 22.10.2026, 09:00 Berlin — noch Sommerzeit.
  final jetzt = DateTime.utc(2026, 10, 22, 7);

  DateTime tagesbeginn(int tag, {int monat = 10}) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tag));

  /// Eine Nacht Kernschlaf, die eine Stunde vor dem Tagesbeginn anfängt.
  SleepNight nachtVon(int tag, {int monat = 10, int stunden = 7}) {
    final ende = tagesbeginn(tag, monat: monat);
    final beginn = ende.subtract(const Duration(hours: 1));
    return SleepNight(
      date: ende,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(Duration(hours: stunden)),
          ),
        ],
      ),
      naps: const [],
    );
  }

  /// Der 21. fehlt — ein Schritt zurück führt auf einen **leeren Tag** und
  /// damit auf den anderen Weg des Schirms (#177).
  List<SleepNight> reiheMitLuecke() => [
    nachtVon(18, stunden: 6),
    nachtVon(19, stunden: 7),
    nachtVon(20, stunden: 8),
    nachtVon(22, stunden: 7),
  ];

  ({ProviderContainer container, Widget app}) huelle({
    List<SleepNight>? naechte,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dataWindowProvider.overrideWith(
          (ref) => DataWindow(start: tagesbeginn(1, monat: 9)),
        ),
        healthProvider.overrideWithValue(_LeereQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              naechte ?? reiheMitLuecke(),
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
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: SchlafView(router: router)),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  const klappbare = [
    'schlaf-statistik-7',
    'schlaf-statistik-30',
    'schlaf-verlauf',
  ];

  // ═════════════════════════════════════════════════════════════════════
  // 1 — „Sieben Nächte" steht offen da
  // ═════════════════════════════════════════════════════════════════════

  group('„Sieben Nächte" steht offen da', () {
    testWidgets('das Diagramm steht im Baum, ohne dass jemand tippt', (
      tester,
    ) async {
      final h = huelle();
      await zeige(tester, h.app);

      expect(find.byType(SchlafNaechteDiagramm), findsOneWidget);
    });

    testWidgets('und sein Schlüssel sitzt weiter auf dem Abschnitt', (
      tester,
    ) async {
      final h = huelle();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-naechte')), findsOneWidget);
    });

    testWidgets('es gibt nichts zum Zuklappen — kein Kopf, kein Inhalt', (
      tester,
    ) async {
      final h = huelle();
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('schlaf-naechte-kopf')),
        findsNothing,
        reason: 'Eine Klappzeile für „Sieben Nächte" gibt es nicht mehr.',
      );
      expect(find.byKey(const Key('schlaf-naechte-inhalt')), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Die drei übrigen bleiben klappbar und zugeklappt
  // ═════════════════════════════════════════════════════════════════════

  group('Die drei übrigen bleiben klappbar und zugeklappt', () {
    testWidgets('ihre Zeilen stehen da und ihre Inhalte nicht', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      for (final name in klappbare) {
        expect(
          find.byKey(Key('$name-kopf')),
          findsOneWidget,
          reason: '$name hat keine Klappzeile mehr',
        );
        expect(
          find.byKey(Key('$name-inhalt')),
          findsNothing,
          reason: '$name steht beim Öffnen des Schirms offen',
        );
      }
    });

    testWidgets('und jede klappt für sich auf', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      for (final name in klappbare) {
        await tester.tap(find.byKey(Key('$name-kopf')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('$name-inhalt')),
          findsOneWidget,
          reason: '$name klappt nicht auf',
        );

        await tester.tap(find.byKey(Key('$name-kopf')));
        await tester.pumpAndSettle();
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3 — Beide Wege des Schirms
  // ═════════════════════════════════════════════════════════════════════

  group('Der leere Tag trägt denselben offenen Abschnitt (#177)', () {
    Future<void> aufDenLeerenTag(WidgetTester tester) async {
      final h = huelle();
      await zeige(tester, h.app);
      h.container.read(schlafAuswahlProvider.notifier).waehle(tagesbeginn(21));
      await tester.pumpAndSettle();
    }

    testWidgets('das Diagramm steht auch dort ohne Tippen da', (tester) async {
      await aufDenLeerenTag(tester);

      expect(find.byKey(const Key('schlaf-leerer-tag')), findsOneWidget);
      expect(find.byType(SchlafNaechteDiagramm), findsOneWidget);
    });

    testWidgets('und auch dort gibt es keine Klappzeile dafür', (tester) async {
      await aufDenLeerenTag(tester);

      expect(find.byKey(const Key('schlaf-naechte-kopf')), findsNothing);
      expect(find.byKey(const Key('schlaf-naechte-inhalt')), findsNothing);
    });

    testWidgets('die drei übrigen sind dort weiterhin zu', (tester) async {
      await aufDenLeerenTag(tester);

      for (final name in klappbare) {
        expect(
          find.byKey(Key('$name-inhalt')),
          findsNothing,
          reason: '$name steht auf dem leeren Tag offen',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4 — Die Stelle: hinter der Atemfrequenz, vor der ersten Klappzeile
  // ═════════════════════════════════════════════════════════════════════

  group('Die Stelle im Schirm', () {
    testWidgets(
      '„Sieben Nächte" steht hinter den Diagrammen der Nacht und vor den '
      'Klappzeilen — ein Bild gehört zu den Bildern',
      (tester) async {
        final h = huelle();
        await zeige(tester, h.app);

        final atmung = tester.getTopLeft(
          find.byKey(const Key('schlaf-atmung')),
        );
        final naechte = tester.getTopLeft(
          find.byKey(const Key('schlaf-naechte')),
        );
        final ersteZeile = tester.getTopLeft(
          find.byKey(const Key('schlaf-statistik-7')),
        );

        expect(
          naechte.dy,
          greaterThan(atmung.dy),
          reason: '„Sieben Nächte" steht vor der Atemfrequenz',
        );
        expect(
          naechte.dy,
          lessThan(ersteZeile.dy),
          reason: '„Sieben Nächte" steht zwischen oder hinter den Klappzeilen',
        );
      },
    );
  });
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

/// Liefert nichts — Puls und Atmung sind hier nicht der Gegenstand.
class _LeereQuelle extends HealthReadingAttrappe {}
