// Home ist schlicht: kein Fußtext, keine Kopf-Verweise (#516).
//
// Tim, 16.11.2026, beim Testen auf dem iPhone: „unten den Info-Text noch
// weg, dann ist der Screen richtig schlicht und so wie ich es will" und
// „den blauen Button Gym und Details ebenfalls weg — stören mich".
//
// Die **Türen bleiben**: Trainingskarte → Gym, Erholungskarte → Erholung,
// Gewichtskachel → Verlauf. Das Antippverhalten bewachen die bestehenden
// Navigationsfälle; hier steht nur, dass die Beschriftungen weg sind.
//
// Harness wie in `heute_leiste_wochentag_test.dart`: RootView mit stillem
// Metrics-Notifier — darin hat Home immer einen Router, die Zusätze
// dürfen also nicht mit „kein Router" wegerklärt werden. Alle Zeitpunkte
// erfunden.
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/design/hinweisfuss.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../ernaehrung/kamera_attrappe.dart';

class _Stiller extends DailyMetricsNotifier {
  @override
  Future<Messwert<List<DailyMetrics>>> build() async =>
      LeerNachLauf<List<DailyMetrics>>(gelaufen: DateTime.utc(2026, 1, 1));
}

Future<void> zeigeRoot(WidgetTester tester) async {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 16, 8)),
        dailyMetricsProvider.overrideWith(_Stiller.new),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
      ],
      child: CupertinoApp(home: RootView(router: AppRouter())),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('kein Abschnittskopf auf Home trägt einen Verweis', (
    tester,
  ) async {
    await zeigeRoot(tester);

    final koepfe = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .toList();
    expect(
      koepfe.map((k) => k.title),
      containsAll(<String>['Heute Training', 'Erholung']),
      reason: 'die Abschnitte selbst bleiben — nur ihre Verweise fallen',
    );
    for (final kopf in koepfe) {
      expect(
        kopf.zusatz,
        isNull,
        reason:
            '„${kopf.title}": der blaue Verweis ist weg (Tim, 16.11.2026) — '
            'die Tür ist die Karte selbst',
      );
    }
  });

  testWidgets('der Fußtext ist weg', (tester) async {
    await zeigeRoot(tester);

    expect(
      find.byType(Hinweisfuss),
      findsNothing,
      reason:
          'Tim, 16.11.2026: der Info-Text unten fällt — die '
          'Schätzungs-Kennzeichnung trägt der Erholung-Schirm weiter',
    );
  });
}
