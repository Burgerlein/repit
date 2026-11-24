import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_auswahl.dart';
import 'package:repit/shell/schlaf_view.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **drei klappbaren Abschnitte am Fuß des Schlaf-Schirms**
/// (#253, nachgezogen für #257) — `lib/shell/schlaf_view.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Tim am 03.11.2026: „letzte 7 Nächte und letzte 30 Tage auf dem
/// Schlaf-Screen sollen auch nach unten und mit dem Verlauf zusammen, je
/// ein- und ausklappbar, default eingeklappt — sonst ist die Seite so
/// lang." Im Auswahlmenü desselben Tages kam „Sieben Nächte" dazu und die
/// Entscheidung, dass in der zugeklappten Zeile **der Schnitt** steht.
///
/// ## Nachgezogen am 03.11.2026 für #257
///
/// „Sieben Nächte" gehörte nie dazu — Tim: „Sieben Nächte nicht ein- und
/// ausklappen, das hast du falsch verstanden." Der Abschnitt steht wieder
/// offen bei den Bildern der Nacht, mit eigener Überschrift und ohne
/// Klappzeile; dass er dort offen steht, prüft
/// `schlaf_sieben_naechte_offen_test.dart`.
///
/// Diese Datei prüft seither **drei** Abschnitte statt vier. Keine
/// Zusicherung über die übrigen drei ändert ihre Aussage: Was über
/// „Sieben Nächte" lief, ist entfallen, nicht umgeschrieben. Entfallen ist
/// damit auch „steht keine Zahl zur Verfügung, steht dort nichts" — sie
/// hatte „Sieben Nächte" als einzigen Gegenstand (die drei übrigen haben
/// immer eine Zahl, sonst gibt es den Abschnitt gar nicht). Die Regel
/// selbst steht unverändert in `../design/klapp_abschnitt_test.dart`, wo
/// das Bauteil ohne Hinweis geprüft wird.
///
/// Drei Abschnitte, in dieser Reihenfolge vom kurzen zum langen Zeitraum:
///
/// 1. Letzte 7 Nächte bis heute
/// 2. Letzte 30 Nächte bis heute
/// 3. Verlauf
///
/// ## Die Schlüssel
///
/// Die drei **Abschnittsschlüssel bleiben, wo sie waren** — sie sitzen nun
/// auf der Klappzeile, also auf dem Teil, den es in jedem Zustand gibt:
///
/// - `Key('schlaf-statistik-7')`, `Key('schlaf-statistik-30')`,
///   `Key('schlaf-verlauf')`
///
/// Dazu je ein Kopf und ein Inhalt, wie bei den Tipps der Erholungsseite
/// (`erholung-tipps-kopf` / `-inhalt`):
///
/// - `Key('schlaf-statistik-7-kopf')` … `Key('schlaf-verlauf-kopf')`
/// - `Key('schlaf-statistik-7-inhalt')` … `Key('schlaf-verlauf-inhalt')`
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: **Zustände und Übergänge**, nicht Layout und Beschriftung.
/// Kein Test schreibt einen Wortlaut, eine Höhe oder eine Reihenfolge im
/// Bild fest. Geprüft wird:
///
/// - Beim Öffnen des Schirms sind alle drei zu, und ihr Inhalt steht nicht
///   im Baum.
/// - **Aufgeklappt bleibt aufgeklappt** — auch über das Blättern zur Nacht
///   davor hinweg, und auch dann, wenn der Schirm dabei den Weg wechselt
///   (Nacht → leerer Tag). Fiele der Abschnitt dabei zu, wäre das aus
///   Sicht des Nutzers `32`.
/// - Beide Wege des Schirms tragen die drei Abschnitte (#177).
/// - Die Zahl in der zugeklappten Zeile ist **dieselbe**, die aufgeklappt
///   dasteht — nicht eine zweite, daneben gerechnete.
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

  /// Sieben Stunden Kernschlaf ab 23:00 Berliner Zeit des Vortags.
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

  /// Der 21. fehlt — an dem lag die Uhr auf dem Nachttisch. Ein Schritt
  /// zurück führt also auf einen **leeren Tag**, und damit auf den anderen
  /// Weg des Schirms (#177).
  List<SleepNight> reiheMitLuecke() => [
    nachtVon(18, stunden: 6),
    nachtVon(19, stunden: 7),
    nachtVon(20, stunden: 8),
    nachtVon(22, stunden: 7),
  ];

  ({ProviderContainer container, Widget app}) huelle({
    List<SleepNight>? naechte,
    DateTime? uhr,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => uhr ?? jetzt),
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

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  Future<void> klappe(WidgetTester tester, Key kopf) async {
    await tester.tap(find.byKey(kopf));
    await tester.pumpAndSettle();
  }

  const abschnitte = [
    'schlaf-statistik-7',
    'schlaf-statistik-30',
    'schlaf-verlauf',
  ];

  // ═════════════════════════════════════════════════════════════════════
  // 1 — Zugeklappt beim Öffnen des Schirms
  // ═════════════════════════════════════════════════════════════════════

  group('Beim Öffnen des Schirms sind alle drei zu', () {
    testWidgets('die drei Zeilen stehen da', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      for (final name in abschnitte) {
        expect(
          find.byKey(Key(name)),
          findsOneWidget,
          reason: '$name fehlt ganz',
        );
      }
    });

    testWidgets('und keiner ihrer Inhalte steht im Baum', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      for (final name in abschnitte) {
        expect(
          find.byKey(Key('$name-inhalt')),
          findsNothing,
          reason: '$name ist beim Öffnen des Schirms offen',
        );
      }
    });

    testWidgets('jede Zeile klappt für sich auf, ohne die anderen', (
      tester,
    ) async {
      final h = huelle();
      await zeige(tester, h.app);

      await klappe(tester, const Key('schlaf-statistik-7-kopf'));

      expect(
        find.byKey(const Key('schlaf-statistik-7-inhalt')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('schlaf-statistik-30-inhalt')), findsNothing);
      expect(find.byKey(const Key('schlaf-verlauf-inhalt')), findsNothing);
    });

    testWidgets('und wieder zu', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      await klappe(tester, const Key('schlaf-verlauf-kopf'));
      expect(find.byKey(const Key('schlaf-verlauf-inhalt')), findsOneWidget);

      await klappe(tester, const Key('schlaf-verlauf-kopf'));
      expect(find.byKey(const Key('schlaf-verlauf-inhalt')), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Aufgeklappt bleibt aufgeklappt
  // ═════════════════════════════════════════════════════════════════════

  group('Aufgeklappt bleibt aufgeklappt', () {
    testWidgets(
      'über das Blättern zur Nacht davor hinweg — wer aufklappt und dann '
      'blättert, findet den Abschnitt offen vor',
      (tester) async {
        final h = huelle(
          naechte: [
            nachtVon(19, stunden: 7),
            nachtVon(20, stunden: 8),
            nachtVon(21, stunden: 6),
            nachtVon(22, stunden: 7),
          ],
        );
        await zeige(tester, h.app);

        await klappe(tester, const Key('schlaf-statistik-7-kopf'));
        expect(
          find.byKey(const Key('schlaf-statistik-7-inhalt')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('schlaf-statistik-7-inhalt')),
          findsOneWidget,
          reason:
              'Ein offener Abschnitt ist ein Zustand der Oberfläche, kein '
              'abgeleiteter Wert — fiele er beim Blättern zu, wäre das 32.',
        );
      },
    );

    testWidgets(
      'auch wenn der Schirm dabei auf einen leeren Tag wechselt — dort ist '
      'der ganze Aufbau ein anderer (#177)',
      (tester) async {
        final h = huelle();
        await zeige(tester, h.app);

        await klappe(tester, const Key('schlaf-verlauf-kopf'));

        // Vom 22. zurück auf den 21., für den keine Nacht vorliegt.
        await tester.tap(find.byKey(const Key('schlaf-frueher')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-leerer-tag')), findsOneWidget);
        expect(
          find.byKey(const Key('schlaf-verlauf-inhalt')),
          findsOneWidget,
          reason: 'Der Wegwechsel darf den offenen Abschnitt nicht zuklappen.',
        );
      },
    );

    testWidgets('und ein zugeklappter bleibt zu', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-verlauf-inhalt')), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3 — Beide Wege des Schirms
  // ═════════════════════════════════════════════════════════════════════

  group('Der leere Tag trägt dieselben drei Abschnitte', () {
    Future<void> aufDenLeerenTag(WidgetTester tester) async {
      final h = huelle();
      await zeige(tester, h.app);
      h.container.read(schlafAuswahlProvider.notifier).waehle(tagesbeginn(21));
      await tester.pumpAndSettle();
    }

    testWidgets('alle drei stehen da', (tester) async {
      await aufDenLeerenTag(tester);

      for (final name in abschnitte) {
        expect(find.byKey(Key(name)), findsOneWidget, reason: '$name fehlt');
      }
    });

    testWidgets('und alle drei sind zu', (tester) async {
      await aufDenLeerenTag(tester);

      for (final name in abschnitte) {
        expect(
          find.byKey(Key('$name-inhalt')),
          findsNothing,
          reason: '$name steht auf dem leeren Tag offen',
        );
      }
    });

    testWidgets('und lassen sich dort genauso aufklappen', (tester) async {
      await aufDenLeerenTag(tester);

      await klappe(tester, const Key('schlaf-statistik-30-kopf'));

      expect(
        find.byKey(const Key('schlaf-statistik-30-inhalt')),
        findsOneWidget,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4 — Die Zahl in der zugeklappten Zeile
  // ═════════════════════════════════════════════════════════════════════

  group('Die Zahl in der zugeklappten Zeile', () {
    /// „6:45 h" — die Form, in der dieser Schirm Schlafdauern setzt.
    final dauer = RegExp(r'\d{1,2}:\d{2} h');

    testWidgets(
      'der Schnitt der letzten 7 Nächte steht in der Zeile — man soll nicht '
      'aufklappen müssen, um zu sehen, ob sich das Aufklappen lohnt',
      (tester) async {
        final h = huelle();
        await zeige(tester, h.app);

        expect(
          textUnter(tester, const Key('schlaf-statistik-7-kopf')),
          matches(dauer),
        );
      },
    );

    testWidgets(
      'und es ist dieselbe Zahl, die aufgeklappt dasteht — zwei Stellen mit '
      'derselben Zahl laufen auseinander',
      (tester) async {
        final h = huelle();
        await zeige(tester, h.app);

        final zeile = textUnter(tester, const Key('schlaf-statistik-7-kopf'));
        final zahl = dauer.firstMatch(zeile)?.group(0);
        expect(zahl, isNotNull);

        await klappe(tester, const Key('schlaf-statistik-7-kopf'));

        expect(
          textUnter(tester, const Key('schlaf-statistik-7-inhalt')),
          contains(zahl!),
        );
      },
    );

    testWidgets('der Verlauf nennt die Spanne seiner Reihe', (tester) async {
      final h = huelle();
      await zeige(tester, h.app);

      final zeile = textUnter(tester, const Key('schlaf-verlauf-kopf'));

      // Die Reihe läuft von sechs bis acht Stunden; beide Enden stehen da.
      expect(zeile, contains('6:00'));
      expect(zeile, contains('8:00'));
    });
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
