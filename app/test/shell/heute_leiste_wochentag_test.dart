// Der Leistentitel von Home ist der Wochentag (#514).
//
// Tim, 16.11.2026, beim Testen auf dem iPhone: „das Home gegen den
// heutigen Tag austauschen — dann steht da Montag z. B. Datum und Stand
// xx:xx fallen weg." Auf Nachfrage: oben in der Leiste; das Tab-Label
// unten bleibt „Home".
//
// Das ersetzt die Entscheidung aus #501 („Heute" in der Leiste, groß das
// Datum): Der Titel ist jetzt der Wochentag, die große Datumszeile und
// die Stand-Zeile entfallen ersatzlos.
//
// Harness wie in `root_view_test.dart`/`heute_umbau_test.dart`: RootView
// mit stillem Metrics-Notifier. Alle Zahlen und Zeitpunkte erfunden.
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/design/grosse_ueberschrift.dart';
import 'package:repit/design/stand_zeile.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../ernaehrung/kamera_attrappe.dart';

/// Hält `HeuteView` im Tab-Gerüst harmlos — wie `_StillerNotifier` in
/// `root_view_test.dart`.
class _Stiller extends DailyMetricsNotifier {
  @override
  Future<Messwert<List<DailyMetrics>>> build() async =>
      LeerNachLauf<List<DailyMetrics>>(gelaufen: DateTime.utc(2026, 1, 1));
}

/// Pumpt die RootView auf den gegebenen Zeitpunkt und lässt sie zur Ruhe
/// kommen.
Future<void> zeigeRoot(WidgetTester tester, DateTime jetzt) async {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(_Stiller.new),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
      ],
      child: CupertinoApp(home: RootView(router: AppRouter())),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Alle sichtbaren Texte, die mit „Stand " beginnen — Wert **oder**
/// Platzhalter der früheren Stand-Zeile.
Finder standTexte() => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').startsWith('Stand '),
);

void main() {
  // Montag, 16.11.2026, 09:15 Berliner Zeit (CET, +1).
  final montag = DateTime.utc(2026, 11, 16, 8, 15);
  // Donnerstag, 19.11.2026 — ein zweiter Tag, damit kein fest
  // hingeschriebenes „Montag" den ersten Fall besteht.
  final donnerstag = DateTime.utc(2026, 11, 19, 8, 15);

  testWidgets('die Leiste trägt den Wochentag, nicht „Heute"', (tester) async {
    await zeigeRoot(tester, montag);

    final leiste = find.byType(CupertinoNavigationBar);
    expect(
      find.descendant(of: leiste, matching: find.text('Montag')),
      findsOneWidget,
      reason: 'der 16.11.2026 ist ein Montag — der steht in der Leiste',
    );
    expect(
      find.descendant(of: leiste, matching: find.text('Heute')),
      findsNothing,
      reason: 'Tim, 16.11.2026: der Wochentag ersetzt den festen Titel',
    );
  });

  testWidgets('an einem anderen Tag steht dessen Wochentag da', (
    tester,
  ) async {
    await zeigeRoot(tester, donnerstag);

    expect(
      find.descendant(
        of: find.byType(CupertinoNavigationBar),
        matching: find.text('Donnerstag'),
      ),
      findsOneWidget,
      reason: 'der Titel kommt aus dem Tag, nicht aus einer Konstante',
    );
  });

  testWidgets('die große Datumszeile ist weg', (tester) async {
    await zeigeRoot(tester, montag);

    expect(
      find.byType(GrosseUeberschrift),
      findsNothing,
      reason:
          'Tim, 16.11.2026: das Datum fällt weg — der Schirm beginnt mit '
          'dem Ringblock',
    );
  });

  testWidgets('die Stand-Zeile ist weg, auch ihr Platzhalter', (tester) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => montag),
          dailyMetricsProvider.overrideWith(_Stiller.new),
          strichcodeLeserProvider.overrideWithValue(TestLeser()),
        ],
        child: CupertinoApp(home: RootView(router: AppRouter())),
      ),
    );

    // Noch vor dem Abschluss des stillen Laufs: kein „Stand 00:00"-
    // Platzhalter mehr.
    expect(find.byType(StandZeile), findsNothing);
    expect(standTexte(), findsNothing);

    await tester.pump();
    await tester.pump();

    // Und nach dem Lauf ebenso wenig eine echte Stand-Zeile.
    expect(find.byType(StandZeile), findsNothing);
    expect(standTexte(), findsNothing);
  });
}
