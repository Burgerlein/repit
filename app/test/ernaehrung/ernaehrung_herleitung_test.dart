import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_types.dart';

import 'tag_huelle.dart';

/// Tests für **#314** — „Ernährung · Herleitung zeigt zwei Zeilen statt
/// drei".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die Rechnung
/// dahinter prüft `Packages/trainings_core/test/kalorienziel_anteile_test.dart`;
/// hier geht es um Verdrahtung und Zustände.
///
/// ## Was verlangt wird
///
/// Der eingeklappte Abschnitt „Woher das Ziel kommt" zeigt die drei Zeilen
/// des Boards (`docs/screens/screens/ernaehrung.js`, `HERLEITUNG`):
/// **Grundumsatz, Aktiv, Körperziel** — und ihre Summe ist das Ziel, das im
/// Ring steht (Ticket, „Fertig, wenn").
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// In `lib/ernaehrung/ernaehrung_provider.dart`:
///
/// ```dart
/// /// Die drei Anteile des Kalorienziels am Esstag — `null`, wenn kein
/// /// Ziel berechenbar ist. Aus `kalorienzielAnteile` im Kern, mit genau
/// /// den Eingaben, aus denen `ernaehrungsTagProvider` das Ziel rechnet.
/// final ernaehrungsHerleitungProvider =
///     Provider.family<KalorienzielAnteile?, String>(…);
/// ```
///
/// Die drei Zeilen im aufgeklappten Inhalt tragen je einen Schlüssel auf
/// einem Vorfahren ihrer Texte:
///
/// - `Key('ernaehrung-herleitung-grundumsatz')`
/// - `Key('ernaehrung-herleitung-aktiv')`
/// - `Key('ernaehrung-herleitung-koerperziel')`
///
/// ## Zwei Regeln aus dem Ticket, und wie sie hier gelesen sind
///
/// - **„Fällt das Ziel auf Mifflin zurück, gibt es keinen gemessenen
///   Grundumsatz. Die Zeile muss das sagen."** Für heute ist das immer der
///   Fall (#229). Verlangt: Die Grundumsatz-Zeile nennt eine Schätzung
///   (ein Wort mit „schätz") und **nicht** „Apple Watch". An einem
///   vergangenen Tag mit ganztägigen Watch-Daten steht dort kein „schätz".
/// - **„Ohne Körperziel ist der Aufschlag 0 und die Zeile entfällt — oder
///   steht mit `–/–`. Zu entscheiden."** Entschieden nach `CLAUDE.md`,
///   nicht von Tim: Die Zeile **steht** („Eine Anzeige verschwindet nicht,
///   weil ihr Wert fehlt") und zeigt `–/–` — nicht `+ 0 kcal`, denn „`0`
///   ist keine Antwort auf ‚kein Wert'". Ohne Zielgewicht oder Zieldatum
///   gibt es kein Körperziel, und das ist etwas anderes als ein Körperziel
///   mit Aufschlag 0 (erreicht, OP-Erholung). Der Vorlesetext nennt den
///   Zustand, nicht das Zeichen.
///
/// **Nicht geprüft:** Beschriftungen, die Erklärung unter den Zeilen,
/// Rundung über die Anzeige hinaus.
///
/// Alle Zahlen sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit.
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  /// Gestern ganztägig gemessen, heute nur ein halber Tag — das Ziel für
  /// heute kommt trotzdem nicht aus der Uhr (#229).
  final tageswerte = Bekannt<List<DailyMetrics>>(
    const [
      DailyMetrics(
        tag: gestern,
        activeKcal: 600,
        basalKcal: 1600,
        weightKg: 80,
      ),
      DailyMetrics(tag: heute, activeKcal: 200, basalKcal: 700, weightKg: 80),
    ],
    stand: jetzt,
    laeuft: false,
  );

  const zeilen = {
    'grundumsatz': Key('ernaehrung-herleitung-grundumsatz'),
    'aktiv': Key('ernaehrung-herleitung-aktiv'),
    'koerperziel': Key('ernaehrung-herleitung-koerperziel'),
  };

  Future<TagHuelle> oeffne(
    WidgetTester tester, {
    Stammdaten stammdaten = huelleStammdaten,
    String? tag,
  }) async {
    final h = tagHuelle(
      jetzt: jetzt,
      tageswerte: tageswerte,
      stammdaten: stammdaten,
    );
    await zeigeTag(tester, h.app);
    if (tag != null) {
      h.container.read(offenerTagProvider.notifier).setze(tag);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('ernaehrung-herleitung-kopf')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ernaehrung-herleitung-inhalt')),
      findsOneWidget,
    );
    return h;
  }

  String text(WidgetTester tester, String zeile) =>
      texteUnter(tester, zeilen[zeile]!).toLowerCase();

  group('Drei Zeilen statt zwei (#314)', () {
    testWidgets('Grundumsatz, Aktiv und Körperziel stehen da', (tester) async {
      await oeffne(tester);
      for (final MapEntry(:key, :value) in zeilen.entries) {
        expect(
          find.descendant(
            of: find.byKey(const Key('ernaehrung-herleitung-inhalt')),
            matching: find.byKey(value),
          ),
          findsOneWidget,
          reason: 'die Zeile „$key" aus dem Board',
        );
      }
    });

    testWidgets('jede Zeile zeigt ihren Anteil', (tester) async {
      final h = await oeffne(tester);
      final anteile = h.container.read(ernaehrungsHerleitungProvider(heute));
      expect(anteile, isNotNull);

      expect(
        text(tester, 'grundumsatz'),
        contains(formatNumber(anteile!.grundumsatzKcal)),
      );
      expect(text(tester, 'aktiv'), contains(formatNumber(anteile.aktivKcal)));
      expect(
        text(tester, 'koerperziel'),
        contains(formatNumber(anteile.koerperzielKcal)),
      );
    });

    testWidgets('die Summe der drei ist das Ziel im Ring', (tester) async {
      final h = await oeffne(tester);
      final anteile = h.container.read(ernaehrungsHerleitungProvider(heute))!;
      final tag = h.container.read(ernaehrungsTagProvider(heute));
      expect(tag.zielKcal, isNotNull);
      expect(anteile.summeKcal, closeTo(tag.zielKcal!, 1e-6));
      expect(
        anteile.koerperzielKcal,
        greaterThan(0),
        reason: 'die Stammdaten der Hülle tragen ein Körperziel',
      );
    });
  });

  group('Heute ist geschätzt, nicht gemessen (#229, #314)', () {
    testWidgets('heute: Mifflin-St Jeor — die Grundumsatz-Zeile sagt, dass '
        'sie schätzt, und nennt keine Uhr', (tester) async {
      final h = await oeffne(tester);
      final anteile = h.container.read(ernaehrungsHerleitungProvider(heute))!;
      expect(
        anteile.gemessen,
        isFalse,
        reason:
            'das Ziel für heute kommt aus dem Planwert, nicht aus dem '
            'halben Tag, den die Uhr bisher gemessen hat',
      );
      expect(text(tester, 'grundumsatz'), contains('schätz'));
      expect(text(tester, 'grundumsatz'), isNot(contains('apple watch')));
    });

    testWidgets('gestern, ganztägig gemessen: die gemessenen Werte, ohne '
        '„geschätzt"', (tester) async {
      final h = await oeffne(tester, tag: gestern);
      final anteile = h.container.read(ernaehrungsHerleitungProvider(gestern))!;
      expect(anteile.gemessen, isTrue);
      expect(anteile.grundumsatzKcal, 1600);
      expect(anteile.aktivKcal, 600);
      expect(text(tester, 'grundumsatz'), contains(formatNumber(1600)));
      expect(text(tester, 'aktiv'), contains(formatNumber(600)));
      expect(
        text(tester, 'grundumsatz'),
        isNot(contains('schätz')),
        reason: 'eine Messung ist keine Schätzung',
      );
    });
  });

  group('Ohne Körperziel steht die Zeile mit –/– (#314)', () {
    const ohneKoerperziel = Stammdaten(groesseCm: 180, geburtsjahr: 1990);

    testWidgets('die Zeile bleibt, zeigt –/– und keine 0', (tester) async {
      final h = await oeffne(tester, stammdaten: ohneKoerperziel);
      expect(
        h.container.read(ernaehrungsTagProvider(heute)).zielKcal,
        isNotNull,
        reason: 'ohne Körperziel gibt es trotzdem ein Ziel',
      );

      expect(find.byKey(zeilen['koerperziel']!), findsOneWidget);
      final zeile = text(tester, 'koerperziel');
      expect(zeile, contains(ohneWert));
      expect(
        RegExp(r'(^|\s|\+)0(\s|$)').hasMatch(zeile),
        isFalse,
        reason:
            '„+ 0 kcal" behauptete ein Körperziel ohne Aufschlag '
            '(gefunden: „$zeile")',
      );
    });

    testWidgets('der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
    ) async {
      await oeffne(tester, stammdaten: ohneKoerperziel);
      final vorgelesen = (await vorlesetext(
        tester,
        zeilen['koerperziel']!,
      )).toLowerCase();
      expect(vorgelesen, isNotEmpty);
      expect(vorgelesen, isNot(contains(ohneWert)));
      expect(vorgelesen, contains('kein'));
    });

    testWidgets('Grundumsatz und Aktiv ergeben dann allein das Ziel', (
      tester,
    ) async {
      final h = await oeffne(tester, stammdaten: ohneKoerperziel);
      final anteile = h.container.read(ernaehrungsHerleitungProvider(heute))!;
      final ziel = h.container.read(ernaehrungsTagProvider(heute)).zielKcal!;
      expect(anteile.koerperzielKcal, 0);
      expect(anteile.grundumsatzKcal + anteile.aktivKcal, closeTo(ziel, 1e-6));
    });
  });

  group('Ohne Ziel behält die Herleitung ihre Form', () {
    testWidgets('fehlt die Größe, stehen alle drei Zeilen mit –/–', (
      tester,
    ) async {
      final h = await oeffne(
        tester,
        stammdaten: const Stammdaten(geburtsjahr: 1990),
      );
      expect(h.container.read(ernaehrungsHerleitungProvider(heute)), isNull);
      for (final MapEntry(:key, :value) in zeilen.entries) {
        expect(find.byKey(value), findsOneWidget, reason: key);
        expect(
          texteUnter(tester, value),
          contains(ohneWert),
          reason: '„$key" ohne Ziel zeigt –/–, keine 0',
        );
      }
    });
  });

  group('Der Provider hält, was er rechnet', () {
    testWidgets('zweimal gelesen ist dasselbe Ergebnis — gehalten, nicht neu '
        'gebaut', (tester) async {
      final h = await oeffne(tester);
      final erstes = h.container.read(ernaehrungsHerleitungProvider(heute));
      final zweites = h.container.read(ernaehrungsHerleitungProvider(heute));
      expect(identical(erstes, zweites), isTrue);
    });

    testWidgets('dieselben Anteile wie der Kern aus denselben Eingaben', (
      tester,
    ) async {
      final h = await oeffne(tester, tag: gestern);
      final stammdaten = huelleStammdaten;
      final erwartet = kalorienzielAnteile(
        aktivKcal: 600,
        basalKcal: 1600,
        gewichtKg: 80,
        groesseCm: stammdaten.groesseCm,
        alter: stammdaten.alterAm(datumAusTag(gestern)),
        zielgewichtKg: stammdaten.zielgewichtKg,
        tageBisZiel: BerlinCalendar.daysBetween(
          from: gestern,
          to: stammdaten.zieldatum!,
        ),
      );
      expect(
        h.container.read(ernaehrungsHerleitungProvider(gestern)),
        erwartet,
      );
    });
  });
}
