// Die Gewichts-Tür auf Home und die Kopfkarte ohne Pfeil (#239).
//
// **Tims Anpassung am 03.11.2026**, nach dem Bau von #82:
//
// > „auf dem home screen ist unter zahlen so ein widget gewicht ich will
// > von da direkt zu dem gewicht detail seite kommen."
// >
// > „die kachel ganz oben von gewicht soll den pfeil nicht haben und die
// > box soll gleich aussehen … wie die von körperfett und so"
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// ## Was hier geprüft wird — und was nicht
//
// Geprüft wird, dass die Türen **führen** und dass der Pfeil **weg** ist.
// Nicht geprüft werden Eckenradius und Randfarbe in Zahlen: Ein Test, der
// `17.0` festnagelt, bricht beim ersten Feinschliff und sagt nichts über
// das, was Tim gemeint hat („sieht aus wie die anderen"). Stattdessen
// hält ein Fall fest, dass Kopfkarte und Kacheln **dieselbe Quelle** für
// ihre Fläche benutzen — driften können sie dann nicht mehr.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/messung_detail_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';
import '../health/health_reading_attrappe.dart';

void main() {
  final jetzt = DateTime.utc(2026, 11, 3, 12);

  late _Quelle quelle;
  late AppCache db;
  late AppRouter router;

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    router = AppRouter();
    // Erfundene Zahlen, keine echten Gesundheitswerte (`CLAUDE.md`).
    quelle = _Quelle([
      DailyMetrics(tag: '2026-11-02', steps: 7200, weightKg: 77.3),
      DailyMetrics(tag: '2026-11-03', steps: 410),
    ]);
  });

  group('Home › Zahlen › Gewicht', () {
    testWidgets('führt auf den Gewichtsverlauf', (tester) async {
      final container = behaelter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: RootView(router: router)),
        ),
      );
      await tester.pumpAndSettle();

      final kachel = find.byKey(const Key('heute-kachel-gewicht'));
      expect(kachel, findsOneWidget);

      // „Zahlen" ist der unterste Abschnitt des Schirms und liegt im
      // 600 Punkt hohen Testfenster außerhalb der Fläche; ohne dies ginge
      // der Tipp ins Leere, und zwar mit **jeder** Umsetzung, die sich an
      // den Entwurf hält. Dieselbe Zeile benutzt `koerper_view_test.dart`
      // in seinem `tippe`-Helfer.
      await tester.ensureVisible(kachel);
      await tester.pumpAndSettle();

      await tester.tap(kachel);
      await tester.pumpAndSettle();

      expect(
        find.byType(MessungDetailView),
        findsOneWidget,
        reason:
            'von der Zahl direkt zu ihrem Verlauf — derselbe Schirm, den '
            'auch die Kopfkarte auf `koerper` öffnet',
      );
    });

    testWidgets('die Schritte-Kachel bleibt ohne Tür', (tester) async {
      final container = behaelter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: RootView(router: router)),
        ),
      );
      await tester.pumpAndSettle();

      // Der Schritte-Schirm ist #84 und noch nicht gebaut. Eine Tür, die
      // auf einen Platzhalter führt, verspricht mehr als sie hält.
      expect(find.byKey(const Key('heute-kachel-schritte')), findsNothing);
    });
  });

  group('Die Kopfkarte auf Körper', () {
    Future<void> zeigeKoerper(WidgetTester tester) async {
      final container = behaelter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(child: KoerperView(router: router)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('trägt keinen Pfeil mehr', (tester) async {
      await zeigeKoerper(tester);

      final pfeile = find.descendant(
        of: find.byKey(const Key('koerper-kopfkarte')),
        matching: find.byIcon(CupertinoIcons.chevron_right),
      );
      expect(
        pfeile,
        findsNothing,
        reason:
            'Die Kacheln darunter sind ebenfalls Türen und tragen keinen '
            'Pfeil. Der Winkel folgt der Tür bei **Zeilen** (Tims Regel vom '
            '27.10.), nicht bei Kacheln',
      );
    });

    testWidgets('bleibt trotzdem eine Tür', (tester) async {
      await zeigeKoerper(tester);

      await tester.tap(find.byKey(const Key('koerper-kopfkarte')));
      await tester.pumpAndSettle();

      expect(router.nimmBefehl(), isNotNull);
    });

    testWidgets('benutzt dieselbe Fläche wie die Kacheln', (tester) async {
      await zeigeKoerper(tester);

      final kopf = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('koerper-kopfkarte')),
              matching: find.byType(Container),
            )
            .first,
      );
      final kachel = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('koerper-kachel-koerperfett')),
              matching: find.byType(Container),
            )
            .first,
      );

      final kopfDeko = kopf.decoration as BoxDecoration;
      final kachelDeko = kachel.decoration as BoxDecoration;

      expect(
        kopfDeko.borderRadius,
        kachelDeko.borderRadius,
        reason: 'dieselbe Quelle für den Radius, sonst driften sie',
      );
      expect(kopfDeko.border, kachelDeko.border);
      expect(kopfDeko.color, kachelDeko.color);
    });
  });
}

class _Quelle extends HealthReadingAttrappe {
  _Quelle(this.tage);

  final List<DailyMetrics> tage;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) async =>
      tage;
}
