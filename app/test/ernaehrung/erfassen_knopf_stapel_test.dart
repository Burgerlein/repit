import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/kamera_seite.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für **#326** — „Der (+) öffnet bei offener Kamera eine zweite
/// darüber".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Für Widget-Tests genügt ein Agent, solange der Test zuerst entsteht,
/// rot gesehen und committet wird. Danach darf diese Datei ausgeführt,
/// aber nicht verändert werden.
///
/// ## Der Befund
///
/// Die Kamera liegt auf dem Stapel des Tabs, wie die Suche — Tableiste und
/// (+) bleiben sichtbar. Ein Tipp auf den (+) bei offener Kamera öffnet
/// eine zweite Kamera darüber (gemeldet vom Implementierenden von #324).
/// Dasselbe über die Suche: (+) → Kamera → „Suchen" → (+) legt die zweite
/// Kamera über die Suche, und darunter liegt noch die erste.
///
/// ## Was hier verlangt wird — und was offen bleibt
///
/// Das „Fertig, wenn" des Tickets: **Wiederholtes Tippen auf den (+)
/// stapelt keine Kameras.** Geprüft wird genau diese Invariante: Im ganzen
/// Baum — auch auf den verdeckten Seiten darunter (`skipOffstage: false`)
/// — steht **höchstens eine** `KameraSeite`.
///
/// **Offen und nicht hier entschieden:** ob der (+) bei offener Kamera
/// *nichts tut* oder sie *schließt* wie ein Umschalter. Das Ticket nennt
/// „nichts tun" die kleinere Überraschung, entscheidet es aber nicht. Beide
/// Fassungen erfüllen diese Datei; die Wahl gehört Tim. Ebenso offen: Ob
/// der (+) aus der Suche heraus zur schon offenen Kamera *zurückführt* oder
/// nichts tut — auch das erfüllt die Invariante in beiden Fassungen.
///
/// Geprüft an der **ganzen** App (`RootView`), wie
/// `barcode_kamera_test.dart`: Der (+) gehört der Schale, nicht einem
/// Schirm. Kein Netz, keine echte Kamera (`TestLeser`).
void main() {
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  Future<void> starte(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(
          OffClient(client: MockClient((_) async => http.Response('', 500))),
        ),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: RootView(router: AppRouter())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> plus(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('erfassen-knopf')));

  /// Alle Kameras im Baum — **auch die verdeckten.** Eine Seite unter einer
  /// anderen ist offstage; ein gewöhnlicher Finder sähe nur die oberste,
  /// und zwei gestapelte Kameras sähen aus wie eine.
  int kameras(WidgetTester tester) =>
      find.byType(KameraSeite, skipOffstage: false).evaluate().length;

  group('Der (+) stapelt keine Kameras (#326)', () {
    testWidgets('der erste Tipp öffnet genau eine Kamera', (tester) async {
      await starte(tester);
      await plus(tester);

      expect(kameras(tester), 1);
      expect(find.byKey(const Key('kamera')), findsOneWidget);
    });

    testWidgets('ein zweiter Tipp bei offener Kamera legt keine zweite '
        'darüber', (tester) async {
      await starte(tester);
      await plus(tester);
      await plus(tester);

      expect(
        kameras(tester),
        lessThanOrEqualTo(1),
        reason:
            'zwei Kameras übereinander — „Abbrechen" führte in die zweite '
            'statt zurück',
      );
    });

    testWidgets('auch nicht nach mehrmaligem Tippen', (tester) async {
      await starte(tester);
      for (var i = 0; i < 4; i++) {
        await plus(tester);
        expect(
          kameras(tester),
          lessThanOrEqualTo(1),
          reason: 'nach ${i + 1} Tipps auf den (+)',
        );
      }
    });

    testWidgets('über die Suche: (+) → Kamera → „Suchen" → (+) legt keine '
        'zweite Kamera auf den Stapel', (tester) async {
      await starte(tester);
      await plus(tester);
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);

      await plus(tester);

      expect(
        kameras(tester),
        lessThanOrEqualTo(1),
        reason:
            'unter der Suche liegt schon die Kamera, aus der sie kam — eine '
            'zweite darüber wäre derselbe Stapel, nur mit der Suche '
            'dazwischen',
      );
    });

    testWidgets('über die Kachel „Barcode" im Ernährungs-Tab: der (+) legt '
        'keine zweite Kamera darüber', (tester) async {
      await starte(tester);
      await tippe(
        tester,
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.byIcon(Symbole.aufloesen('fork.knife')),
        ),
      );
      await tippe(
        tester,
        find.descendant(
          of: find.byKey(const Key('ernaehrung-wege')),
          matching: find.text('Barcode'),
        ),
      );
      expect(kameras(tester), 1);

      await plus(tester);

      expect(kameras(tester), lessThanOrEqualTo(1));
    });
  });
}

class _StilleQuelle extends HealthReadingAttrappe {}
