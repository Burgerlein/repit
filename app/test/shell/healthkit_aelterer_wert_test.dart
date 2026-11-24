// „Heute nicht gemessen" ist nicht „keine Daten" (#237).
//
// **Tims Befund am 03.11.2026:** Auf dem HealthKit-Test-Schirm fehlten
// Gewicht, Körperfett und Magermasse weiterhin — obwohl sie in der
// Datenbank seines iPhones standen, mit einer Wägung vom Vortag und
// einem heutigen Tag ohne Wägung. *(Die echten Zahlen stehen hier
// bewusst nicht: `CLAUDE.md` — keine Mock-Konstante aus tatsächlichen
// Werten des Nutzers. Die Fixturen unten sind erfunden.)*
//
// Der Schirm zeigt den **heutigen** Tag. Für Schritte, Ruhepuls, HRV und
// Atmung ist das die richtige Frage. Für Gewicht, Körperfett, Magermasse
// und VO₂max nicht: **Man wiegt sich nicht jeden Tag.** Die Zeile nannte
// zwei Möglichkeiten („keine Daten", „kein Zugriff"), von denen keine
// zutraf, und verschwieg die, die zutraf — es gibt einen Wert, er ist nur
// von gestern. Auf einem Diagnoseschirm wiegt das doppelt: Dort sucht man
// nach der Ursache und bekommt eine falsche Fährte.
//
// **Tims Vorgabe:** „keine daten von heute aber von gestern in klammern
// der wert". Die Klammern tragen die Aussage — der Wert gilt, er ist nur
// nicht von heute. Ohne sie läse sich die Zeile wie eine heutige Messung.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// ## Was hier bewusst offen bleibt
//
// Die genaue Schreibweise in der Klammer ist **nicht** festgelegt — geprüft
// wird, dass Wert und Tag vorkommen und dass geklammert ist. Ein Test, der
// ein Trennzeichen festnagelt, kostet mehr Pflege als er wert ist.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/healthkit_test_view.dart';
import '../health/health_reading_attrappe.dart';

void main() {
  final jetzt = DateTime.utc(2026, 11, 3, 12);

  late _Quelle quelle;
  late AppCache db;

  Future<void> zeige(WidgetTester tester) async {
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: HealthKitTestView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String zeilentext(WidgetTester tester, String feld) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(Key('healthkit-typ-$feld')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .join(' ');

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // Tims Datenlage: heute Schritte und Puls, die Wägung ist von gestern.
    quelle = _Quelle([
      DailyMetrics(
        tag: '2026-11-02',
        steps: 7200,
        restingHR: 54,
        weightKg: 77.3,
        bodyFatPct: 18.4,
        leanKg: 63.1,
      ),
      DailyMetrics(tag: '2026-11-03', steps: 410, restingHR: 54),
    ]);
  });

  group('Ein Wert von gestern steht in Klammern', () {
    testWidgets('das Gewicht nennt Zahl und Tag', (tester) async {
      await zeige(tester);
      final text = zeilentext(tester, 'weightKg');

      expect(text, contains('77,3'));
      expect(text, contains('02.11.'));
      expect(text, contains('('));
      expect(text, contains(')'));
    });

    testWidgets('Körperfett und Magermasse ebenso', (tester) async {
      await zeige(tester);

      expect(zeilentext(tester, 'bodyFatPct'), contains('18,4'));
      expect(zeilentext(tester, 'leanKg'), contains('63,1'));
    });

    testWidgets('und behauptet nicht mehr, es gäbe keine Daten',
        (tester) async {
      await zeige(tester);

      for (final feld in ['weightKg', 'bodyFatPct', 'leanKg']) {
        expect(
          zeilentext(tester, feld).toLowerCase(),
          isNot(contains('keine daten')),
          reason:
              '„keine Daten oder kein Zugriff" nennt zwei Möglichkeiten, von '
              'denen hier keine zutrifft — der Wert ist da, nur nicht von '
              'heute',
        );
      }
    });
  });

  group('Was sich nicht ändert', () {
    testWidgets('ein heutiger Wert steht ohne Klammern da', (tester) async {
      quelle = _Quelle([
        DailyMetrics(tag: '2026-11-03', steps: 410, weightKg: 77.3),
      ]);
      await zeige(tester);

      final text = zeilentext(tester, 'weightKg');
      expect(text, contains('77,3'));
      expect(
        text,
        isNot(contains('(')),
        reason:
            'Die Klammer sagt „nicht von heute". Wer sie auch um einen '
            'heutigen Wert setzt, nimmt ihr die Aussage',
      );
    });

    testWidgets('Tageswerte bleiben bei heute', (tester) async {
      await zeige(tester);

      // Gestern 7200 Schritte, heute 410 — gezeigt wird heute. Ein
      // Schrittzähler, der auf den letzten Tag mit Wert ausweicht, zeigte
      // morgens früh dauerhaft den Vortag.
      expect(zeilentext(tester, 'steps'), contains('410'));
      expect(zeilentext(tester, 'steps'), isNot(contains('7200')));
    });

    testWidgets('liegt im ganzen Fenster nichts, gilt der Hinweis weiter',
        (tester) async {
      quelle = _Quelle([DailyMetrics(tag: '2026-11-03', steps: 410)]);
      await zeige(tester);

      expect(
        zeilentext(tester, 'weightKg').toLowerCase(),
        contains('keine daten'),
        reason:
            'Dann stimmen beide Möglichkeiten wieder — und Apple verrät '
            'nicht, welche es ist',
      );
      expect(zeilentext(tester, 'weightKg'), isNot(contains('0')));
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
