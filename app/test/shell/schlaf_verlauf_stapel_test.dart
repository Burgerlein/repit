/// **#504 — Der Schlaf-Verlauf zeichnet wieder Balken, nach Phasen
/// gestapelt.**
///
/// Tim am 13.11.2026, mit einem Bildschirmfoto des Verlaufs aus der
/// eingefrorenen Swift-App:
///
/// > „Schlaf-Verlauf-Graph — doch, den hier übernehmen, nur die Balken so
/// > einfärben wie die Phasen, damit man sieht, wie die prozentual drin
/// > waren. Weiterhin aber eingeklappt lassen."
///
/// Das **kehrt #255 um** (03.11.2026, „Die Linie gewinnt"). Die Begründung
/// von damals trägt die Umkehr mit: Jede Nacht ist eine abgeschlossene
/// Menge, und eine Linie zwischen zwei Nächten behauptet Zwischenwerte,
/// die es nicht gibt.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_abschnitte.dart
///
/// class SchlafVerlauf extends StatelessWidget {
///   const SchlafVerlauf({
///     super.key,
///     required List<({DateTime tag, double wert})> reihe,
///     List<({DateTime tag, List<double> teile})> phasenReihe = const [],
///     double? schlafzielStunden,
///   });
/// }
/// ```
///
/// ## Was hier geprüft wird — und was nicht
///
/// - **Balken, keine Linie.** Die eine Zusicherung, um die es in #504
///   geht.
/// - **Die Farben kommen aus `SchlafPhasen.farbe`**, nicht aus der
///   Swift-Fassung: Dort ist „Tief" bewusst `riverDark` statt `deep`, weil
///   `deep` im Dunkelmodus das hellste Blau der Palette ist. Derselbe
///   Schlaf sieht damit im Hypnogramm und im Verlauf gleich aus.
/// - **Die Fußnote nennt den Balken und die Phasen** — und nicht mehr den
///   Punkt. Dass sie bis heute beides in einem Satz sagte, stand schon in
///   #255 und ist nie berichtigt worden.
/// - **Der Schirm liest den gehaltenen Provider**, er rechnet die Phasen
///   nicht selbst (Hausregel 2).
///
/// **Nicht geprüft, bewusst:** dass der Abschnitt zugeklappt startet —
/// das steht in `schlaf_klapp_test.dart` und gilt unverändert weiter
/// (Tim: „weiterhin aber eingeklappt lassen").
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_abschnitte.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  SleepNight nachtVon(int tag) {
    const phasen = [
      (SleepStage.core, 120),
      (SleepStage.deep, 60),
      (SleepStage.awake, 15),
      (SleepStage.rem, 90),
      (SleepStage.core, 135),
    ];
    final abschnitte = <SleepSegment>[];
    var zeiger = berlin(tag - 1, 23);
    for (final (phase, minuten) in phasen) {
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

  final werte = [
    for (var tag = 6; tag <= 12; tag++)
      (tag: tagesbeginn(tag), wert: 6.0 + tag % 3 * 0.4),
  ];

  final phasen = [
    for (var tag = 6; tag <= 12; tag++)
      (tag: tagesbeginn(tag), teile: const [1.0, 4.0, 1.5, 0.0]),
  ];

  Future<void> zeige(WidgetTester tester, Widget inhalt) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(child: inhalt),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer behaelter() {
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_FakeHealthReading()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              [for (var i = 13; i >= 0; i--) nachtVon(12 - i)],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Zeitdiagramm diagramm(WidgetTester tester) =>
      tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));

  String fussnote(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('diagramm-fussnote')),
          matching: find.byType(Text),
        ),
      )
      .map(textOf)
      .join(' ')
      .toLowerCase();

  // ═══════════════════════════════════════════════════════════════════════

  group('Balken statt Linie', () {
    testWidgets('eine Nacht ist ein Balken', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      expect(
        diagramm(tester).alsBalken,
        isTrue,
        reason:
            'Tim am 13.11.2026 (#504, kehrt #255 um): den Verlauf der '
            'alten App übernehmen, „nur die Balken so einfärben wie die '
            'Phasen"',
      );
    });

    testWidgets('die Phasenreihe geht unverändert an das Bauteil', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      expect(diagramm(tester).stapelReihe, phasen);
    });

    testWidgets('ohne Phasenreihe steht kein Stapel im Bauteil', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(
        diagramm(tester).stapelReihe,
        isEmpty,
        reason:
            'keine Phasendaten heißt einfarbig, nicht eine erfundene '
            'Verteilung (#504)',
      );
      expect(
        diagramm(tester).alsBalken,
        isTrue,
        reason: 'die Balken hängen nicht an den Phasen',
      );
    });
  });

  group('Die Farben kommen aus dem Hypnogramm', () {
    testWidgets('je Phase die Farbe aus SchlafPhasen.farbe', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      expect(
        diagramm(tester).stapelFarben,
        [for (final phase in schlafVerlaufPhasen) SchlafPhasen.farbe(phase)],
        reason:
            'derselbe Schlaf sieht im Hypnogramm und im Verlauf gleich '
            'aus; „Tief" ist dort bewusst `riverDark` und nicht `deep`',
      );
    });

    testWidgets('so viele Farben wie Teile', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      expect(
        diagramm(tester).stapelFarben.length,
        schlafVerlaufPhasen.length,
        reason: 'ein Teil ohne Farbe wäre ein unsichtbarer Teil',
      );
    });
  });

  group('Die Fußnote sagt, was zu sehen ist', () {
    testWidgets('auf W nennt sie den Balken, die Nacht und das Bett', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      final text = fussnote(tester);
      expect(text, contains('balken'));
      expect(text, contains('nacht'));
      expect(
        text,
        contains('bett'),
        reason:
            'gezählt wird die Zeit im Schlaf, nicht die Zeit im Bett — den '
            'Unterschied benennt der Entwurf ausdrücklich',
      );
      expect(
        text,
        isNot(contains('punkt')),
        reason:
            '#255 hat „Je Punkt eine Nacht. Der Balken zeigt …" als zwei '
            'Darstellungen in einem Satz gemeldet; seit #504 zeichnet der '
            'Verlauf Balken, also ist „Punkt" das Falsche',
      );
    });

    testWidgets('sie nennt die Phasen, nach denen gefärbt wird', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      final text = fussnote(tester);
      for (final name in const ['tief', 'kern', 'rem']) {
        expect(
          text,
          contains(name),
          reason: 'ohne Namen ist die Farbe eine Behauptung ohne Lesart',
        );
      }
    });

    testWidgets('ab 6M ist ein Balken ein Monat, und das steht da', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte, phasenReihe: phasen));

      expect(fussnote(tester), contains('je balken eine nacht'));

      await tester.tap(find.text('6M'));
      await tester.pumpAndSettle();

      final text = fussnote(tester);
      expect(
        text,
        isNot(contains('je balken eine nacht')),
        reason:
            'ab 6M ist ein Balken ein Kalendermonat — „je Balken eine '
            'Nacht" wäre dort schlicht falsch',
      );
      expect(text, contains('monat'));
      expect(text, contains('balken'));
      expect(
        text,
        isNot(contains('punkt')),
        reason: 'auch die zweite Fassung nennt den Balken, nicht den Punkt',
      );
    });
  });

  group('Der Schirm liest die Phasen aus dem gehaltenen Provider', () {
    testWidgets('der Abschnitt reicht sie an das Diagramm durch', (
      tester,
    ) async {
      final container = behaelter();
      final router = AppRouter();

      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: SchlafView(router: router)),
        ),
      );
      await tester.pumpAndSettle();

      // Zugeklappt seit #253, und das bleibt so (Tim am 13.11.2026).
      await tester.tap(find.byKey(const Key('schlaf-verlauf-kopf')));
      await tester.pumpAndSettle();

      expect(
        diagramm(tester).stapelReihe,
        container.read(schlafPhasenTagewerteProvider),
        reason: 'der Schirm liest den Provider, er rechnet nicht selbst',
      );
      expect(
        diagramm(tester).stapelReihe,
        isNotEmpty,
        reason: 'sonst prüft der Fall zwei leere Listen gegeneinander',
      );
    });
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

/// Eine Quelle, die nichts liefert — der Verlauf hängt an [sleepProvider],
/// nicht am Kanal.
class _FakeHealthReading extends HealthReadingAttrappe {}
