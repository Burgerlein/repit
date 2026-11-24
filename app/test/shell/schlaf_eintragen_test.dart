import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_eintragen.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';
import 'package:repit/shell/tagschlaf_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für das **Formular „von Hand eintragen" und seine Einstiege**
/// (#131, Zug 3) — `lib/shell/schlaf_eintragen.dart` sowie die Zeilen und
/// Knöpfe, die es öffnen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Geprüft werden Zustände und Übergänge, nicht Beschriftungen
///
/// `CLAUDE.md`: „Views bekommen Widget-Tests, aber nur für Zustände und
/// Übergänge." Also: Geht das Blatt auf? Wechselt es die Fassung? Kommt
/// hinten ein Eintrag heraus? Steht die Plakette da, wenn die Nacht
/// eingetragen ist? Nicht geprüft wird, wie die Knöpfe heißen.
///
/// ## Das Formular ist ein Blatt, kein Schirm
///
/// Der Entwurf zeigt es als `sheet` über dem Schlaf-Schirm, nicht als
/// eigenen Eintrag im Navigationsstapel. Daraus folgt für **jeden** der
/// drei Einstiege dasselbe: `router.nimmBefehl()` bleibt `null`. Für den
/// Knopf auf dem Erholung-Schirm ist das keine neue Zusicherung, sondern
/// genau die, die `erholung_view_test.dart` dort schon festhält — nur dass
/// jetzt das Formular aufgeht und nicht mehr der Hinweis „gibt es noch
/// nicht".
///
/// ## Festgelegte öffentliche API (`lib/shell/schlaf_eintragen.dart`)
///
/// ```dart
/// enum SchlafEintragenArt { nacht, tagschlaf }
///
/// /// Öffnet das Formular als Blatt über dem aktuellen Schirm.
/// Future<void> zeigeSchlafEintragen(
///   BuildContext context, {
///   required SchlafEintragenArt art,
///   required DateTime tag,
/// });
/// ```
///
/// Schlüssel, auf die sich diese Tests festlegen:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `schlaf-eintragen` | die Zeile „Nacht von Hand eintragen" |
/// | `tagschlaf-eintragen` | dieselbe Zeile für ein Nickerchen |
/// | `tagschlaf-plus` | das (+) in der Navigationsleiste |
/// | `schlaf-eintragen-blatt` | das Formular selbst |
/// | `schlaf-eintragen-modus` | die Auswahl Zeiten / nur Dauer |
/// | `schlaf-eintragen-kosten` | der Satz, was „nur Dauer" kostet |
/// | `schlaf-eintragen-sichern` | Sichern |
/// | `schlaf-von-hand-hinweis` | der Kasten über der eingetragenen Nacht |
void main() {
  final jetzt = DateTime.utc(2026, 10, 29, 9);
  DateTime tag(int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tagImMonat, 12));

  SleepNight gemesseneNacht(int tagImMonat) {
    final beginn = BerlinCalendar.startOfDay(
      DateTime.utc(2026, 10, tagImMonat - 1, 12),
    ).add(const Duration(hours: 23));
    return SleepNight(
      date: tag(tagImMonat),
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(const Duration(minutes: 420)),
          ),
        ],
      ),
      naps: const [],
    );
  }

  ({ProviderContainer container, AppRouter router, Widget app}) huelle(
    Widget Function(AppRouter router) inhalt, {
    Messwert<List<SleepNight>>? schlaf,
  }) {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        // **Ohne diese Zeile endet jedes `pumpAndSettle` in einer
        // Zeitschranke.** `healthProvider` wirft ohne Override, der
        // Lauf für Puls und Atmung scheitert — und
        // `nachtVitalwerteAusProvider` bildet einen gescheiterten Lauf
        // heute auf `NochNie` ab (`schlaf_vitalwerte.dart:160`,
        // `zustand.value ?? NochNie`). Die Karte zeigt dann dauerhaft
        // einen `CupertinoActivityIndicator`, und der animiert ewig.
        // Dieselbe Hülle steht aus demselben Grund in
        // `schlaf_view_test.dart`. Dass ein Fehler dort als Ladezustand
        // erscheint, ist ein eigener Befund und gehört nicht hierher.
        healthProvider.overrideWithValue(_StilleQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  [gemesseneNacht(29)],
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
        child: CupertinoApp(home: inhalt(router)),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Die drei Einstiege
  // ───────────────────────────────────────────────────────────────────────

  group('Drei Türen, ein Formular', () {
    testWidgets(
      'die Zeile auf dem Schlaf-Schirm öffnet das Blatt und springt in '
      'keinen anderen Schirm',
      (tester) async {
        final h = huelle((router) => SchlafSeite(router: router));
        await zeige(tester, h.app);

        await tester.scrollUntilVisible(
          find.byKey(const Key('schlaf-eintragen')),
          200,
        );
        await tester.tap(find.byKey(const Key('schlaf-eintragen')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-eintragen-blatt')), findsOneWidget);
        expect(
          h.router.nimmBefehl(),
          isNull,
          reason: 'das Formular ist ein Blatt, kein Eintrag im Stapel',
        );
      },
    );

    testWidgets('das (+) des Tagschlaf-Schirms öffnet dasselbe Blatt', (
      tester,
    ) async {
      final h = huelle((router) => TagschlafSeite(router: router));
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('tagschlaf-plus')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-eintragen-blatt')), findsOneWidget);
      expect(h.router.nimmBefehl(), isNull);
    });

    testWidgets(
      'und die Zeile darunter ebenso — ein Weg im Kopf, einer im Fluss',
      (tester) async {
        final h = huelle((router) => TagschlafSeite(router: router));
        await zeige(tester, h.app);

        await tester.scrollUntilVisible(
          find.byKey(const Key('tagschlaf-eintragen')),
          200,
        );
        await tester.tap(find.byKey(const Key('tagschlaf-eintragen')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-eintragen-blatt')), findsOneWidget);
      },
    );

    testWidgets(
      'auch im leeren Zustand steht die Zeile da — dort führt sie als '
      'einzige weiter',
      (tester) async {
        final h = huelle(
          (router) => SchlafSeite(router: router),
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-eintragen')), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Formular
  // ───────────────────────────────────────────────────────────────────────

  group('Zwei Fassungen, und die zweite sagt vorher, was sie kostet', () {
    Future<void> oeffne(WidgetTester tester, Widget app) async {
      await zeige(tester, app);
      await tester.scrollUntilVisible(
        find.byKey(const Key('schlaf-eintragen')),
        200,
      );
      await tester.tap(find.byKey(const Key('schlaf-eintragen')));
      await tester.pumpAndSettle();
    }

    testWidgets('in der Fassung „Zeiten" steht kein Kostensatz', (
      tester,
    ) async {
      final h = huelle((router) => SchlafSeite(router: router));
      await oeffne(tester, h.app);

      expect(find.byKey(const Key('schlaf-eintragen-modus')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-eintragen-kosten')), findsNothing);
    });

    testWidgets(
      'nach dem Wechsel auf „nur Dauer" steht er da — vor dem Sichern, '
      'nicht hinterher am halben Score',
      (tester) async {
        final h = huelle((router) => SchlafSeite(router: router));
        await oeffne(tester, h.app);

        await tester.tap(find.byKey(const Key('schlaf-eintragen-modus-dauer')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('schlaf-eintragen-kosten')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'beim Tagschlaf kostet „nur Dauer" nichts, also steht dort auch '
      'nichts — er hat keinen Score',
      (tester) async {
        final h = huelle((router) => TagschlafSeite(router: router));
        await zeige(tester, h.app);
        await tester.tap(find.byKey(const Key('tagschlaf-plus')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('schlaf-eintragen-modus-dauer')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-eintragen-kosten')), findsNothing);
      },
    );

    testWidgets('Abbrechen schließt das Blatt und legt nichts ab', (
      tester,
    ) async {
      final h = huelle((router) => SchlafSeite(router: router));
      await oeffne(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-eintragen-abbrechen')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-eintragen-blatt')), findsNothing);
      expect(await h.container.read(schlafEintraegeProvider.future), isEmpty);
    });

    testWidgets('Sichern legt die Nacht ab und schließt das Blatt', (
      tester,
    ) async {
      final h = huelle((router) => SchlafSeite(router: router));
      await oeffne(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-eintragen-sichern')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-eintragen-blatt')), findsNothing);
      final eintraege = await h.container.read(schlafEintraegeProvider.future);
      expect(eintraege, hasLength(1));
      expect(eintraege.single.art, SchlafEintragArt.nacht);
      expect(eintraege.single.schlafMinuten, greaterThan(0));
    });

    testWidgets('und über das (+) landet ein Nickerchen in der Ablage', (
      tester,
    ) async {
      final h = huelle((router) => TagschlafSeite(router: router));
      await zeige(tester, h.app);
      await tester.tap(find.byKey(const Key('tagschlaf-plus')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schlaf-eintragen-sichern')));
      await tester.pumpAndSettle();

      final eintraege = await h.container.read(schlafEintraegeProvider.future);
      expect(eintraege, hasLength(1));
      expect(eintraege.single.art, SchlafEintragArt.tagschlaf);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die eingetragene Nacht auf dem Schirm
  // ───────────────────────────────────────────────────────────────────────

  group('Eine eingetragene Nacht sieht anders aus, und sagt warum', () {
    Future<ProviderContainer> mitEintrag(WidgetTester tester) async {
      final h = huelle((router) => SchlafSeite(router: router));
      await zeige(tester, h.app);
      await h.container
          .read(schlafEintraegeProvider.notifier)
          .setzeNacht(
            tag: BerlinCalendar.dayKey(tag(29)),
            schlafMinuten: 425,
            beginnMinuten: 23 * 60 + 10,
            endeMinuten: 6 * 60 + 15,
          );
      await tester.pumpAndSettle();
      return h.container;
    }

    testWidgets('über ihr steht ein Kasten, der die Lage erklärt', (
      tester,
    ) async {
      await mitEintrag(tester);

      expect(find.byKey(const Key('schlaf-von-hand-hinweis')), findsOneWidget);
    });

    testWidgets(
      'Hypnogramm, Puls und Atmung fehlen ganz — gemessen wurde nichts, '
      'also wird nichts gezeigt',
      (tester) async {
        await mitEintrag(tester);

        expect(find.byKey(const Key('schlaf-phasen')), findsNothing);
        expect(find.byKey(const Key('schlaf-puls')), findsNothing);
        expect(find.byKey(const Key('schlaf-atmung')), findsNothing);
      },
    );

    testWidgets('die Score-Karte steht weiter da', (tester) async {
      await mitEintrag(tester);

      expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
    });

    testWidgets(
      'und ohne Eintrag sind die drei Karten da, wo sie immer waren',
      (tester) async {
        final h = huelle((router) => SchlafSeite(router: router));
        await zeige(tester, h.app);

        expect(find.byKey(const Key('schlaf-phasen')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-scorekarte')), findsOneWidget);
      },
    );
  });
}

/// Eine Quelle, die auf alles mit „nichts" antwortet. Der Schlaf-Schirm
/// fragt sie nur nach Puls und Atmung der Nacht; die Nächte selbst kommen
/// aus dem überschriebenen `sleepProvider`.
class _StilleQuelle extends HealthReadingAttrappe {}

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
