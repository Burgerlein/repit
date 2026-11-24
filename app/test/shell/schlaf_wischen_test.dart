import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';
// `AppTarget` liegt in `shell/ziele.dart`, nicht in `shell/router.dart`.
import 'package:repit/shell/ziele.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Wischgeste** des Schlaf-Schirms (#127) —
/// „Im Schlaf-Detail zur Nacht davor wischen".
///
/// Der Schirm selbst steht in `schlaf_view_test.dart`, der Zustand darunter
/// in `schlaf_zustand_test.dart`. Diese Datei kommt dazu und nimmt dort
/// nichts weg: `schlaf_view_test.dart` hält im Kopf fest, die Wischgeste sei
/// „bewusst nicht geprüft, sie ist #127" — **das ist sie ab hier.** Der
/// Satz dort bleibt stehen, weil nach der Rollentrennung niemand eine
/// fremde Testdatei anfasst.
///
/// ## Was die Geste tut
///
/// Aus dem Ticket, und aus der Entscheidung vom 13.10.2026
/// (`docs/superpowers/specs/2026-10-13-aeltere-nacht-auswaehlen-design.md`):
///
/// - **Wisch nach rechts → die Nacht davor**, Wisch nach links → die Nacht
///   danach. Dieselbe Richtung wie in Fotos und in Apple Health.
/// - **Die Pfeile bleiben** und führen auf denselben Zustand. Eine Geste
///   ohne sichtbares Gegenstück findet niemand.
/// - **Dieselbe Grenze wie die Pfeile**: über alle geladenen Nächte. Am
///   ältesten und am jüngsten Rand passiert **nichts** — kein Nachtwechsel,
///   kein leerer Schirm.
/// - **Es wischt nur der Nachtbereich.** Verlauf, Statistiken und „Sieben
///   Nächte" bleiben auf heute bezogen (Entscheidung 3 vom 13.10.2026) und
///   blättern deshalb auch nicht mit.
/// - **Die linke Bildschirmkante gehört dem System.** iOS blättert von dort
///   im Navigationsstapel zurück; fängt der Nachtbereich diese Geste ab,
///   kommt der Nutzer nicht mehr aus dem Schirm heraus.
///
/// ## Was hier nicht geprüft wird
///
/// - **Die Haptik am Rand.** „Spürbar anstoßen" ist genau das: spürbar.
///   Ein Widget-Test sieht keinen Vibrationsmotor. Geprüft wird die
///   nachprüfbare Hälfte — dass am Rand **kein** Nachtwechsel stattfindet
///   und der Schirm stehen bleibt. Die Haptik gehört in die Prüfanleitung
///   fürs Gerät (`CLAUDE.md`, „Was ein Widget-Test nicht sehen kann").
/// - **Schwellwerte.** Ab welcher Strecke oder welchem Tempo ein Zug als
///   Wisch gilt, ist Abstimmung am Gerät und keine Anforderung. Die Tests
///   ziehen deutlich — 260 Punkte auf einem 900 Punkte breiten Schirm.
/// - **Eine Animation.** Der Entwurf sieht keine vor; die Nacht wechselt.
///
/// ## Zwei Wächter, von Anfang an grün
///
/// „Ein Wisch von der linken Kante blättert nicht" und „… und er schiebt den
/// Schirm vom Stapel" gelten schon vor der Geste — heute fängt niemand dort
/// etwas ab. Sie sind trotzdem der Kern von Punkt 3 des Tickets und stehen
/// deshalb hier: Sie bewachen genau den Schaden, den das Bauen anrichten
/// kann (`CLAUDE.md`, „Ein Wächtertest ist von Anfang an grün").
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

  /// Eine Nacht mit allen vier Phasen, 23:00 bis 06:00.
  SleepNight nachtVon(int tag) {
    final abschnitte = <SleepSegment>[];
    var zeiger = berlin(tag - 1, 23);
    for (final (phase, minuten) in const [
      (SleepStage.core, 120),
      (SleepStage.deep, 60),
      (SleepStage.awake, 15),
      (SleepStage.rem, 90),
      (SleepStage.core, 135),
    ]) {
      final ende = zeiger.add(Duration(minutes: minuten));
      abschnitte.add(SleepSegment(stage: phase, start: zeiger, end: ende));
      zeiger = ende;
    }
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(segments: abschnitte),
      naps: const [],
    );
  }

  List<SleepNight> reihe({int anzahl = 14}) => [
    for (var i = anzahl - 1; i >= 0; i--) nachtVon(12 - i),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    int naechte = 14,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        // **Der gelesene Zeitraum beginnt an der ältesten Nacht dieser
        // Hülle** (#177). Seit leere Tage erreichbar sind, stößt der Wisch
        // am Anfang des Zeitraums an und nicht an der ältesten Nacht; ohne
        // diese Zeile läge der Rand dreißig Tage weiter hinten und „am
        // ältesten Rand blättert ein Wisch nicht weiter" prüfte nichts.
        dataWindowProvider.overrideWith(
          (ref) => DataWindow(start: reihe(anzahl: naechte).first.date),
        ),
        healthProvider.overrideWithValue(_LeereQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              reihe(anzahl: naechte),
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
              // Entspricht der durchscheinenden Navigations- und Tableiste.
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: SchlafView(router: router),
            ),
          ),
        ),
      ),
    );
  }

  /// Derselbe Schirm, aber **auf einem echten Navigationsstapel** — der
  /// einzige Aufbau, in dem iOS' Zurück-Wisch von der linken Kante
  /// überhaupt existiert.
  Widget stapel(ProviderContainer container, AppRouter router) =>
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  key: const Key('test-tuer'),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => SchlafSeite(router: router),
                    ),
                  ),
                  child: const Text('auf'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist.
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  /// Welche Nacht der Schirm gerade zeigt.
  DateTime gezeigteNacht(ProviderContainer container) {
    final daten = container.read(schlafProvider).daten;
    return (daten as Bekannt<SchlafDaten>).wert.nacht!.nacht.date;
  }

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  /// Ein deutlicher waagerechter Zug über der Mitte von [key].
  ///
  /// Positives [weite] heißt nach rechts — zur Nacht davor.
  Future<void> wische(WidgetTester tester, Key key, double weite) async {
    await tester.dragFrom(tester.getCenter(find.byKey(key)), Offset(weite, 0));
    await tester.pumpAndSettle();
  }

  /// Die Zeichenfläche des großen Hypnogramms — dort liegt seit #141 das
  /// Ablesen durch Halten.
  Finder hypnogrammBild() => find.descendant(
    of: find.byKey(const Key('schlaf-phasen')),
    matching: find.byKey(const Key('hypnogramm-bild')),
  );

  /// Die Kopfzeile des Hypnogramms: in Ruhe „WACH", beim Ablesen die
  /// Zeitspanne des gehaltenen Abschnitts.
  String hypnogrammKopf(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.descendant(
            of: find.byKey(const Key('schlaf-phasen')),
            matching: find.byKey(const Key('hypnogramm-kopf')),
          ),
          matching: find.byType(Text),
        ),
      )
      .map(textOf)
      .join(' ');

  // ───────────────────────────────────────────────────────────────────────
  // 1 — Wischen blättert
  // ───────────────────────────────────────────────────────────────────────

  group('Wischen blättert eine Nacht', () {
    testWidgets('nach rechts zur Nacht davor', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      expect(gezeigteNacht(h.container), tagesbeginn(12));

      await wische(tester, const Key('schlaf-scorekarte'), 260);

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets('nach links wieder zur Nacht danach', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-scorekarte'), 260);
      await wische(tester, const Key('schlaf-scorekarte'), 260);
      expect(gezeigteNacht(h.container), tagesbeginn(10));

      await wische(tester, const Key('schlaf-scorekarte'), -260);

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets('auch über der Blätterleiste, nicht nur über der Karte', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-blaetterleiste'), 260);

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets('und die Leiste nennt danach die neue Nacht', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      expect(
        textUnter(tester, const Key('schlaf-blaetterleiste')),
        contains('12'),
      );

      await wische(tester, const Key('schlaf-scorekarte'), 260);

      expect(
        textUnter(tester, const Key('schlaf-blaetterleiste')),
        contains('11'),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 2 — Am Rand stößt es an, statt ins Leere zu laufen
  // ───────────────────────────────────────────────────────────────────────

  group('Am Rand der geladenen Nächte', () {
    testWidgets('am jüngsten Rand blättert ein Wisch nach links nicht weiter', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      expect(gezeigteNacht(h.container), tagesbeginn(12));

      await wische(tester, const Key('schlaf-scorekarte'), -260);

      expect(gezeigteNacht(h.container), tagesbeginn(12));
      expect(
        textUnter(tester, const Key('schlaf-blaetterleiste')),
        contains('12'),
      );
    });

    testWidgets(
      'am ältesten Rand blättert ein Wisch nach rechts nicht weiter',
      (tester) async {
        final h = harness(naechte: 2);
        await zeige(tester, h.app);

        await wische(tester, const Key('schlaf-scorekarte'), 260);
        expect(gezeigteNacht(h.container), tagesbeginn(11));

        await wische(tester, const Key('schlaf-scorekarte'), 260);

        expect(gezeigteNacht(h.container), tagesbeginn(11));
        expect(
          textUnter(tester, const Key('schlaf-blaetterleiste')),
          contains('11'),
        );
      },
    );

    testWidgets(
      'mit einer einzigen Nacht bewegt sich in keiner Richtung etwas',
      (tester) async {
        final h = harness(naechte: 1);
        await zeige(tester, h.app);

        await wische(tester, const Key('schlaf-scorekarte'), 260);
        expect(gezeigteNacht(h.container), tagesbeginn(12));

        await wische(tester, const Key('schlaf-scorekarte'), -260);
        expect(gezeigteNacht(h.container), tagesbeginn(12));

        // Und der Schirm steht noch, statt leer zu sein.
        expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-leer')), findsNothing);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // 3 — Die linke Kante gehört dem System
  // ───────────────────────────────────────────────────────────────────────

  group('Der Zurück-Wisch von der linken Kante', () {
    testWidgets('ein Zug, der an der linken Kante beginnt, blättert nicht', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final hoehe = tester.getCenter(
        find.byKey(const Key('schlaf-scorekarte')),
      );
      await tester.dragFrom(Offset(4, hoehe.dy), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(gezeigteNacht(h.container), tagesbeginn(12));
    });

    testWidgets('und er schiebt den Schirm weiter vom Stapel', (tester) async {
      final h = harness();
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(stapel(h.container, h.router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('test-tuer')));
      await tester.pumpAndSettle();
      expect(find.byType(SchlafSeite), findsOneWidget);

      await tester.dragFrom(const Offset(4, 400), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.byType(SchlafSeite), findsNothing);
      expect(find.byKey(const Key('test-tuer')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 4 — Wischen und Halten fressen einander nicht
  // ───────────────────────────────────────────────────────────────────────

  group('Wischen und Halten', () {
    testWidgets('ein Wisch über dem Hypnogramm blättert und liest nicht ab', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      expect(hypnogrammKopf(tester), contains('WACH'));

      await tester.dragFrom(
        tester.getCenter(hypnogrammBild()),
        const Offset(260, 0),
      );
      await tester.pumpAndSettle();

      expect(gezeigteNacht(h.container), tagesbeginn(11));
      expect(hypnogrammKopf(tester), contains('WACH'));
    });

    testWidgets('ein Halten über dem Hypnogramm liest ab und blättert nicht', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final geste = await tester.startGesture(
        tester.getCenter(hypnogrammBild()),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Abgelesen heißt: oben steht die Zeitspanne des Abschnitts, nicht
      // mehr die Wachbilanz der Nacht.
      expect(hypnogrammKopf(tester), isNot(contains('WACH')));
      expect(gezeigteNacht(h.container), tagesbeginn(12));

      await geste.up();
      await tester.pumpAndSettle();
      expect(hypnogrammKopf(tester), contains('WACH'));
      expect(gezeigteNacht(h.container), tagesbeginn(12));
    });

    testWidgets('ein Wisch über den Pulsspannen blättert ebenfalls', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-puls'), 260);

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 5 — Es wischt nur der Nachtbereich
  // ───────────────────────────────────────────────────────────────────────

  group('Was nicht mitwischt', () {
    testWidgets('ein Wisch über dem Verlauf wechselt die Nacht nicht', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-verlauf'), 260);

      expect(gezeigteNacht(h.container), tagesbeginn(12));
    });

    testWidgets('ein Wisch über den sieben Nächten auch nicht', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-naechte'), 260);

      expect(gezeigteNacht(h.container), tagesbeginn(12));
    });

    testWidgets(
      'nach dem Wischen sagt der Schirm, dass Verlauf und Schnitte auf heute '
      'bezogen bleiben',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);
        expect(find.byKey(const Key('schlaf-verlauf-hinweis')), findsNothing);

        await wische(tester, const Key('schlaf-scorekarte'), 260);

        expect(find.byKey(const Key('schlaf-verlauf-hinweis')), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // 6 — Beide Wege führen auf denselben Zustand
  // ───────────────────────────────────────────────────────────────────────

  group('Pfeile und Geste', () {
    testWidgets('die Pfeile tun nach einem Wisch weiter dasselbe', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await wische(tester, const Key('schlaf-scorekarte'), 260);
      expect(gezeigteNacht(h.container), tagesbeginn(11));

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();
      expect(gezeigteNacht(h.container), tagesbeginn(10));

      await tester.tap(find.byKey(const Key('schlaf-spaeter')));
      await tester.pumpAndSettle();
      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets('und ein Tipper auf den Pfeil bleibt ein Tipper', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-frueher')));
      await tester.pumpAndSettle();

      expect(gezeigteNacht(h.container), tagesbeginn(11));
    });

    testWidgets(
      'die gewischte Nacht überlebt das Verlassen des Schirms nicht',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        await wische(tester, const Key('schlaf-scorekarte'), 260);
        expect(gezeigteNacht(h.container), tagesbeginn(11));

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: const CupertinoApp(home: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(Duration.zero);

        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(gezeigteNacht(h.container), tagesbeginn(12));
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

/// Eine Quelle ohne Messungen — der Schlaf-Schirm holt von ihr nur die
/// Spannen, und die Geste hängt nicht an ihnen.
class _LeereQuelle extends HealthReadingAttrappe {}
