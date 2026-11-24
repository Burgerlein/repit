import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/health/health_provider.dart';
import 'package:repit/main.dart';
import 'package:repit/shell/tageswacht.dart';

/// Tests für **den Anstoß des Tageswechsels** (#124, zu #90).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `pruefeTageswechsel()` ist gebaut und geprüft
/// (`test/health/tageswechsel_test.dart`) — **nur ruft ihn niemand auf.**
/// Liegt die App über Mitternacht im Hintergrund und kommt wieder nach
/// vorn, rechnet sie weiter auf dem Vortag: „Heute" ist gestern, der
/// Erholungs-Schirm rechnet gegen die falsche Nacht, und erst ein Neustart
/// rückt die Sache zurecht. Beide bestehenden Testdateien sagen
/// ausdrücklich, dass sie den Aufrufer **nicht** prüfen („Diese Datei
/// prüft, dass der Weg existiert und richtig wirkt — nicht, wer ihn
/// geht"). Diese hier prüft genau das Fehlende.
///
/// ## Die verlangte Form
///
/// Ein Baustein `Tageswacht` in `lib/shell/tageswacht.dart`, der einen
/// beliebigen `child` durchreicht und in `main.dart` **innerhalb** des
/// `ProviderScope` sitzt:
///
/// ```dart
/// class Tageswacht extends ConsumerWidget {
///   const Tageswacht({super.key, required this.child});
///   final Widget child;
/// }
/// ```
///
/// Warum ein eigener Baustein und nicht `RootView`: `RootView` wird von
/// einem Dutzend Widget-Tests ohne `ProviderScope` gepumpt, und ein Schirm
/// mitten im Tab-Gerüst ist der falsche Ort für etwas, das so lange leben
/// muss wie die App. Warum nicht im Notifier selbst: Dort steht
/// ausdrücklich „Wer das aufruft, entscheidet die Widget-Schicht" — und ein
/// `WidgetsBinding`-Beobachter in `health_provider.dart` zöge die
/// Widget-Schicht in die Datenschicht.
///
/// ## Was hier geprüft wird — und was nicht
///
/// Geprüft wird der **Zustandswechsel `resumed`**: der einzige Zustand, der
/// „die App ist wieder vorn und nimmt wieder Eingaben entgegen" bedeutet.
/// `inactive` und `hidden` sind Durchgangszustände — sie laufen auf iOS
/// auch dann durch, wenn die App gar nicht weg war (Kontrollzentrum,
/// App-Umschalter, ein Anruf-Banner), und **jeder** Weg zurück nach vorn
/// endet ohnehin bei `resumed`. Ein Test hält deshalb ausdrücklich fest,
/// dass `inactive` allein **nichts** auslöst: Das ist eine Entscheidung,
/// keine Lücke.
///
/// **Nicht geprüft** wird ein Ticker für den Fall „App liegt offen auf dem
/// Tisch, während es Mitternacht wird" (#124 nennt ihn als offene Frage).
/// Kommt er, braucht er seinen eigenen Test mit dem Nachweis, dass er
/// nichts neu rechnet, solange der Tag derselbe ist.
///
/// **Alle Zeitpunkte hier sind erfunden.**
void main() {
  // 27.10.2026, 22:50 UTC = 23:50 Berliner Zeit (Winterzeit, die Umstellung
  // war am 25.10.).
  final kurzVorMitternacht = DateTime.utc(2026, 10, 27, 22, 50);

  // 27.10.2026, 23:05 UTC = 00:05 Berliner Zeit am 28.10.
  final kurzNachMitternacht = DateTime.utc(2026, 10, 27, 23, 5);

  // Derselbe Abend, eine Viertelstunde später — noch derselbe Berliner Tag.
  final nochDerselbeAbend = DateTime.utc(2026, 10, 27, 22, 58);

  final tagesbeginn27 = BerlinCalendar.startOfDay(
    DateTime.utc(2026, 10, 27, 12),
  );
  final tagesbeginn28 = BerlinCalendar.startOfDay(
    DateTime.utc(2026, 10, 28, 12),
  );

  ({ProviderContainer behaelter, void Function(DateTime) stelleUhr}) aufbau() {
    var jetzt = kurzVorMitternacht;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [clockProvider.overrideWithValue(() => jetzt)],
    );
    addTearDown(container.dispose);
    return (behaelter: container, stelleUhr: (neu) => jetzt = neu);
  }

  Future<void> pumpeWacht(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Tageswacht(child: SizedBox.shrink()),
      ),
    );
  }

  /// Schickt einen Lebenszyklus-Zustand so, wie die Plattform ihn schickt —
  /// über `SystemChannels.lifecycle`. Das ist der öffentliche Weg (die
  /// Binding-Methode selbst ist `@protected`) und erzeugt nebenbei die
  /// Zwischenzustände, die iOS auch erzeugt: `paused` → `resumed` läuft
  /// über `hidden` und `inactive`.
  Future<void> sendeLebenszyklus(
    WidgetTester tester,
    AppLifecycleState zustand,
  ) {
    return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(zustand.toString()),
      (_) {},
    );
  }

  group('Tageswacht — beim Start', () {
    testWidgets('legt den heutigen Tag fest, bevor ein Schirm ihn liest', (
      tester,
    ) async {
      final (behaelter: container, stelleUhr: _) = aufbau();

      await pumpeWacht(tester, container);

      expect(
        container.exists(heutigerTagProvider),
        isTrue,
        reason:
            'Der Tag muss beim Aufbau des Baums feststehen — sonst hängt er '
            'am ersten Schirm, der ihn zufällig zuerst liest.',
      );
      expect(container.read(heutigerTagProvider), tagesbeginn27);
    });
  });

  group('Tageswacht — Rückkehr aus dem Hintergrund', () {
    testWidgets(
      'die App lag über Mitternacht im Hintergrund: bei resumed rückt der '
      'Tag nach',
      (tester) async {
        final (behaelter: container, stelleUhr: stelleUhr) = aufbau();
        await pumpeWacht(tester, container);
        expect(container.read(heutigerTagProvider), tagesbeginn27);

        // App in den Hintergrund, Mitternacht vergeht, App wieder nach vorn.
        await sendeLebenszyklus(tester, AppLifecycleState.paused);
        stelleUhr(kurzNachMitternacht);
        await sendeLebenszyklus(tester, AppLifecycleState.resumed);
        await tester.pump();

        expect(
          container.read(heutigerTagProvider),
          tagesbeginn28,
          reason:
              'Ohne diesen Nachruck zeigt „Heute" gestern, und der '
              'Erholungs-Schirm rechnet gegen die falsche Nacht (#124).',
        );
      },
    );

    testWidgets(
      'am selben Kalendertag ändert die Rückkehr nichts — kein neuer Wert, '
      'keine Benachrichtigung',
      (tester) async {
        final (behaelter: container, stelleUhr: stelleUhr) = aufbau();
        await pumpeWacht(tester, container);
        expect(container.read(heutigerTagProvider), tagesbeginn27);

        var benachrichtigungen = 0;
        container.listen<DateTime>(
          heutigerTagProvider,
          (_, _) => benachrichtigungen++,
        );

        await sendeLebenszyklus(tester, AppLifecycleState.paused);
        stelleUhr(nochDerselbeAbend);
        await sendeLebenszyklus(tester, AppLifecycleState.resumed);
        await tester.pump();

        expect(container.read(heutigerTagProvider), tagesbeginn27);
        expect(
          benachrichtigungen,
          0,
          reason:
              'Ein Ruf, der denselben Tag findet, darf nichts auslösen — '
              'sonst rechnet bei jeder Rückkehr alles neu (Fehler `03`).',
        );
      },
    );

    testWidgets(
      'inactive allein prüft nicht — das Kontrollzentrum ist keine Rückkehr',
      (tester) async {
        final (behaelter: container, stelleUhr: stelleUhr) = aufbau();
        await pumpeWacht(tester, container);

        await sendeLebenszyklus(tester, AppLifecycleState.resumed);
        stelleUhr(kurzNachMitternacht);

        await sendeLebenszyklus(tester, AppLifecycleState.inactive);
        await tester.pump();

        expect(
          container.read(heutigerTagProvider),
          tagesbeginn27,
          reason:
              'inactive ist ein Durchgangszustand und läuft auch durch, wenn '
              'die App gar nicht weg war. Geprüft wird bei resumed.',
        );

        await sendeLebenszyklus(tester, AppLifecycleState.resumed);
        await tester.pump();

        expect(
          container.read(heutigerTagProvider),
          tagesbeginn28,
          reason: 'Jeder Weg zurück nach vorn endet bei resumed.',
        );
      },
    );

    testWidgets('nach dem Abbau hängt kein Beobachter mehr am Binding', (
      tester,
    ) async {
      final (behaelter: container, stelleUhr: stelleUhr) = aufbau();
      await pumpeWacht(tester, container);

      await tester.pumpWidget(const SizedBox.shrink());

      stelleUhr(kurzNachMitternacht);
      await sendeLebenszyklus(tester, AppLifecycleState.paused);
      await sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(
        container.read(heutigerTagProvider),
        tagesbeginn27,
        reason:
            'Ein Beobachter, der den Abbau überlebt, hält den Baum fest und '
            'ruft in einen Container, den es nicht mehr geben muss.',
      );
    });
  });

  group('Tageswacht — in der App verdrahtet', () {
    testWidgets('main.dart hängt sie unter den ProviderScope', (tester) async {
      await tester.pumpWidget(const RepitApp());

      expect(
        find.byType(Tageswacht),
        findsOneWidget,
        reason:
            'Der Baustein nützt nichts, solange ihn niemand in den Baum '
            'hängt — genau das war der Befund zu pruefeTageswechsel (#124).',
      );
      expect(
        find.ancestor(
          of: find.byType(Tageswacht),
          matching: find.byType(ProviderScope),
        ),
        findsOneWidget,
        reason:
            'Innerhalb des Scopes, sonst findet sie heutigerTagProvider '
            'nicht.',
      );
    });
  });
}
