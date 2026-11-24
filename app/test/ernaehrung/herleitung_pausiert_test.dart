import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ereignisse.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_types.dart';

import 'tag_huelle.dart';

/// Tests für **die Herleitung in der Auszeit** (#449 unter #404): Liegt
/// der Tag in einer OP, Krankheit oder Verletzung, sagt „Woher das Ziel
/// kommt“, dass das Körperziel pausiert und bis wann — nicht „+ 0 kcal“.
///
/// **Ein Agent, Test zuerst** (Plan, Task 6): Diese Datei ist vor der
/// Implementierung entstanden, rot gesehen und committet worden. Danach
/// wird sie nicht mehr verändert (`.githooks/pre-commit`).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitte
/// „Herleitung auf dem Ernährungs-Tag“ und „Leerzustände“, dazu V15–V17;
/// Entwurf `HERLEITUNG_PAUSIERT` in `docs/screens/screens/auszeit.js`. Von
/// Tim am 10.11.2026 freigegeben („bauen“).
///
/// ## Festlegungen dieser Datei — nicht von Tim
///
/// - **Schlüssel wie bisher:** `ernaehrung-herleitung-kopf`,
///   `ernaehrung-herleitung-inhalt`, `ernaehrung-herleitung-koerperziel`.
///   **Neu:** `ernaehrung-herleitung-erklaerung` auf der Erklärung unter
///   den Zeilen — an ihr wird die Höhe gemessen (V17).
/// - **Geprüft werden Stichworte, nicht der Satzbau** (Kleinschreibung
///   verglichen): „pausiert“, „op-erholung bis“, „krankheit bis“,
///   „verletzung bis“, das Ende als „24.06.“; in der Erklärung „ärztin“
///   für den Freigabe-Hinweis und „während der auszeit“ für den Wortlaut
///   aus V16.
/// - **Vollständig heißt: nicht abgeschnitten.** Die Erklärung mit dem
///   Freigabe-Text überschreitet ihre Zeilenzahl nicht
///   (`RenderParagraph.didExceedMaxLines`). Ob fünf Zeilen auf dem Gerät
///   reichen, sieht dieser Test nicht — das prüft der Simulator.
/// - **V15, Ziel von Hand:** geprüft wird nur, dass Kopf und Zeile kein
///   „pausiert“ tragen und die Erklärung „von hand“ und den
///   Freigabe-Hinweis („ärztin“) nennt — der Wortlaut dafür steht nicht im
///   Entwurf.
/// - **Die Auszeiten kommen über einen überschriebenen
///   `ereignisseProvider`**, `auszeitenProvider` bleibt der echte (wie in
///   `kalorienziel_pause_test.dart`).
///
/// **Alle Zahlen und Tage sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“).
void main() {
  const heute = '2099-06-17';
  final jetzt = DateTime.utc(2099, 6, 17, 10);

  /// Körperziel 95 kg bis Mitte Dezember bei 80 kg — der Aufschlag ist
  /// deutlich größer als 0.
  const mitKoerperziel = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 2069,
    zielgewichtKg: 95,
    zieldatum: '2099-12-15',
  );
  const ohneKoerperziel = Stammdaten(groesseCm: 180, geburtsjahr: 2069);

  final tageswerte = Bekannt<List<DailyMetrics>>(
    const [
      DailyMetrics(tag: heute, activeKcal: 300, basalKcal: 800, weightKg: 80),
    ],
    stand: jetzt,
    laeuft: false,
  );

  Ereignis auszeit(EreignisArt art, {int id = 1}) => Ereignis(
    id: id,
    art: art,
    von: '2099-06-10',
    bis: '2099-06-24',
    angelegt: DateTime.utc(2099, 6, 1),
  );

  const kopf = Key('ernaehrung-herleitung-kopf');
  const inhalt = Key('ernaehrung-herleitung-inhalt');
  const koerperziel = Key('ernaehrung-herleitung-koerperziel');
  const erklaerung = Key('ernaehrung-herleitung-erklaerung');

  /// Baut den Tag mit [ereignisse] (`null`: das erste Lesen wird nie
  /// fertig) und [historie] in der Tabelle der festen Ziele. Klappt die
  /// Herleitung auf, wenn [aufklappen].
  Future<TagHuelle> oeffne(
    WidgetTester tester, {
    List<Ereignis>? ereignisse = const [],
    Stammdaten stammdaten = mitKoerperziel,
    List<KalorienzielFestlegung> historie = const [],
    bool aufklappen = true,
  }) async {
    final h = tagHuelle(
      jetzt: jetzt,
      tageswerte: tageswerte,
      stammdaten: stammdaten,
      zusaetzlich: [
        ereignisseProvider.overrideWith(
          () => ereignisse == null
              ? _HaengendeEreignisse()
              : _FesteEreignisse(ereignisse),
        ),
      ],
    );
    final repo = KalorienzielRepository(h.db);
    for (final f in historie) {
      await repo.setze(f);
    }
    await zeigeTag(tester, h.app);
    if (aufklappen) {
      await tester.tap(find.byKey(kopf));
      await tester.pumpAndSettle();
      expect(find.byKey(inhalt), findsOneWidget);
    }
    return h;
  }

  String text(WidgetTester tester, Key key) =>
      texteUnter(tester, key).toLowerCase();

  /// Der Absatz der Erklärung, der den Freigabe-Hinweis trägt.
  RenderParagraph freigabeAbsatz(WidgetTester tester) {
    final treffer = find.descendant(
      of: find.byKey(inhalt),
      matching: find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Ärztin'),
      ),
    );
    expect(treffer, findsOneWidget, reason: 'der Freigabe-Hinweis steht da');
    return tester.renderObject<RenderParagraph>(treffer);
  }

  group('Tag in einer OP', () {
    testWidgets('der Kopf trägt „· pausiert“, auch zugeklappt', (
      tester,
    ) async {
      await oeffne(
        tester,
        ereignisse: [auszeit(EreignisArt.op)],
        aufklappen: false,
      );
      expect(find.byKey(inhalt), findsNothing, reason: 'noch zugeklappt');
      final k = text(tester, kopf);
      expect(k, contains('kcal'));
      expect(k, contains('· pausiert'));
    });

    testWidgets('die Körperziel-Zeile sagt „pausiert“ und das Ende der OP, '
        'nicht „+ 0 kcal“', (tester) async {
      await oeffne(tester, ereignisse: [auszeit(EreignisArt.op)]);
      final zeile = text(tester, koerperziel);
      expect(zeile, contains('pausiert'));
      expect(zeile, contains('op-erholung bis'));
      expect(zeile, contains('24.06.'));
      expect(zeile, isNot(contains('kcal')));
      expect(
        RegExp(r'(^|\s|\+)0(\s|$)').hasMatch(zeile),
        isFalse,
        reason: '„+ 0 kcal“ hieße „das Körperziel bringt nichts“',
      );
    });

    testWidgets('der Vorlesetext nennt den Zustand und das Ende als Wort', (
      tester,
    ) async {
      await oeffne(tester, ereignisse: [auszeit(EreignisArt.op)]);
      final vorgelesen = (await vorlesetext(tester, koerperziel)).toLowerCase();
      expect(vorgelesen, contains('körperziel'));
      expect(vorgelesen, contains('pausiert'));
      expect(vorgelesen, contains('op-erholung bis 24. juni'));
    });

    testWidgets('die Erklärung trägt den Freigabe-Hinweis, ungekürzt (V17)', (
      tester,
    ) async {
      await oeffne(tester, ereignisse: [auszeit(EreignisArt.op)]);
      final e = text(tester, erklaerung);
      expect(e, contains('während der erholung'));
      expect(e, contains('ärztin'));
      expect(
        freigabeAbsatz(tester).didExceedMaxLines,
        isFalse,
        reason: 'eine abgeschnittene Freigabe wäre schlimmer als keine',
      );
    });

    testWidgets('fester, berechneter Tag in der OP: ebenfalls „pausiert“ '
        '(V14)', (tester) async {
      await oeffne(
        tester,
        ereignisse: [auszeit(EreignisArt.op)],
        historie: const [
          KalorienzielFestlegung(
            abTag: '2099-06-01',
            kcal: 3000,
            herkunft: KalorienzielHerkunft.berechnet,
            anteile: KalorienzielAnteile(
              grundumsatzKcal: 1900,
              aktivKcal: 700,
              koerperzielKcal: 400,
              gemessen: false,
            ),
          ),
        ],
      );
      expect(text(tester, kopf), contains('· pausiert'));
      expect(text(tester, koerperziel), contains('pausiert'));
      expect(text(tester, koerperziel), contains('op-erholung bis'));
    });
  });

  group('Krankheit und Verletzung (V16)', () {
    testWidgets('Krankheit: „Krankheit bis …“ und der Wortlaut der Auszeit', (
      tester,
    ) async {
      await oeffne(tester, ereignisse: [auszeit(EreignisArt.krankheit)]);
      expect(text(tester, kopf), contains('· pausiert'));
      final zeile = text(tester, koerperziel);
      expect(zeile, contains('pausiert'));
      expect(zeile, contains('krankheit bis'));
      expect(zeile, contains('24.06.'));
      expect(zeile, isNot(contains('op-erholung')));
      final e = text(tester, erklaerung);
      expect(e, contains('während der auszeit'));
      expect(e, contains('ärztin'));
      expect(freigabeAbsatz(tester).didExceedMaxLines, isFalse);
    });

    testWidgets('Verletzung: „Verletzung bis …“', (tester) async {
      await oeffne(tester, ereignisse: [auszeit(EreignisArt.verletzung)]);
      final zeile = text(tester, koerperziel);
      expect(zeile, contains('pausiert'));
      expect(zeile, contains('verletzung bis'));
      expect(zeile, contains('24.06.'));
      expect(text(tester, erklaerung), contains('während der auszeit'));
      expect(freigabeAbsatz(tester).didExceedMaxLines, isFalse);
    });
  });

  testWidgets('Tag im Urlaub: wie ohne Auszeit', (tester) async {
    await oeffne(
      tester,
      ereignisse: [auszeit(EreignisArt.urlaub)],
      aufklappen: false,
    );
    expect(text(tester, kopf), contains('kcal'));
    expect(text(tester, kopf), isNot(contains('pausiert')));

    await tester.tap(find.byKey(kopf));
    await tester.pumpAndSettle();
    final zeile = text(tester, koerperziel);
    expect(zeile, contains('+'));
    expect(zeile, contains('kcal'));
    expect(zeile, isNot(contains('pausiert')));
    expect(text(tester, erklaerung), isNot(contains('ärztin')));
  });

  testWidgets('ohne Körperziel in einer OP: „kein Körperziel eingetragen“, '
      'kein „pausiert“', (tester) async {
    await oeffne(
      tester,
      ereignisse: [auszeit(EreignisArt.op)],
      stammdaten: ohneKoerperziel,
    );
    expect(text(tester, kopf), contains('kcal'));
    expect(text(tester, kopf), isNot(contains('pausiert')));
    final zeile = text(tester, koerperziel);
    expect(zeile, contains(ohneWert));
    expect(zeile, contains('kein körperziel eingetragen'));
    expect(zeile, isNot(contains('pausiert')));
  });

  testWidgets('Ziel von Hand in einer OP: kein „pausiert“, die Erklärung '
      'sagt „von Hand“ und trägt den Freigabe-Hinweis (V15)', (tester) async {
    await oeffne(
      tester,
      ereignisse: [auszeit(EreignisArt.op)],
      historie: const [
        KalorienzielFestlegung(
          abTag: '2099-06-01',
          kcal: 3300,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ],
    );
    expect(text(tester, kopf), contains('3.300'));
    expect(text(tester, kopf), isNot(contains('pausiert')));
    final zeile = text(tester, koerperziel);
    expect(zeile, contains(ohneWert));
    expect(zeile, isNot(contains('pausiert')));
    final e = text(tester, erklaerung);
    expect(e, contains('von hand'));
    expect(e, contains('ärztin'));
    expect(freigabeAbsatz(tester).didExceedMaxLines, isFalse);
  });

  group('Während das Ziel lädt (01)', () {
    testWidgets('mit Körperziel: weder „pausiert“ noch „kein Körperziel '
        'eingetragen“', (tester) async {
      await oeffne(tester, ereignisse: null, aufklappen: false);
      expect(text(tester, kopf), isNot(contains('pausiert')));

      await tester.tap(find.byKey(kopf));
      await tester.pumpAndSettle();
      final zeile = text(tester, koerperziel);
      expect(zeile, contains(ohneWert));
      expect(zeile, isNot(contains('pausiert')));
      expect(zeile, isNot(contains('kein körperziel')));
      expect(text(tester, erklaerung), isNot(contains('ärztin')));
    });

    testWidgets('ohne Körperziel: auch dann kein „kein Körperziel '
        'eingetragen“, solange nichts entschieden ist', (tester) async {
      await oeffne(tester, ereignisse: null, stammdaten: ohneKoerperziel);
      final zeile = text(tester, koerperziel);
      expect(zeile, contains(ohneWert));
      expect(zeile, isNot(contains('kein körperziel')));
      expect(zeile, isNot(contains('pausiert')));
    });
  });

  testWidgets('gleiche Höhe mit und ohne Pause, und beim Laden (V17)', (
    tester,
  ) async {
    Future<(Size, Size)> masse(List<Ereignis>? ereignisse) async {
      await oeffne(tester, ereignisse: ereignisse);
      final groessen = (
        tester.getSize(find.byKey(erklaerung)),
        tester.getSize(find.byKey(inhalt)),
      );
      // Frischer Baum für die nächste Messung.
      await tester.pumpWidget(const SizedBox());
      return groessen;
    }

    final ohne = await masse(const []);
    final pausiert = await masse([auszeit(EreignisArt.op)]);
    final laedt = await masse(null);

    expect(pausiert.$1.height, ohne.$1.height, reason: 'Erklärung');
    expect(laedt.$1.height, ohne.$1.height, reason: 'Erklärung beim Laden');
    expect(pausiert.$2.height, ohne.$2.height, reason: 'ganzer Inhalt');
    expect(laedt.$2.height, ohne.$2.height, reason: 'Inhalt beim Laden');
  });
}

/// Ereignisse, die sofort mit [liste] gelesen sind.
class _FesteEreignisse extends EreignisseNotifier {
  _FesteEreignisse(this.liste);

  final List<Ereignis> liste;

  @override
  Future<List<Ereignis>> build() async => liste;
}

/// Ereignisse, deren erstes Lesen nie fertig wird.
class _HaengendeEreignisse extends EreignisseNotifier {
  @override
  Future<List<Ereignis>> build() => Completer<List<Ereignis>>().future;
}
