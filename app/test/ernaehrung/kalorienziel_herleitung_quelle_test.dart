import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/mess_abschnitte.dart'
    show datumZumAnzeigen;

import 'tag_huelle.dart';

/// Tests für **#410 — die Herleitung sagt, woher die Zahl stammt und seit
/// wann.**
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die Rechnung
/// dahinter prüft `kalorienziel_fest_test.dart`; hier geht es um das, was
/// der aufgeklappte Abschnitt „Woher das Ziel kommt" zeigt.
///
/// ## Was verlangt wird
///
/// Aus dem Auftrag zu #410 (Vorgabe des Koordinators, Tim hat die
/// Rückfrage weggeklickt): Die Herleitung zeigt, woher die Zahl stammt —
/// „fest seit …", „berechnet am …" bzw. „von Hand".
///
/// ## Festgelegt vom Test-Agenten — nicht von Tim freigegeben
///
/// - **Eine Zeile `Key('ernaehrung-herleitung-quelle')`** im aufgeklappten
///   Inhalt (`Key('ernaehrung-herleitung-inhalt')`). Sie **steht in jedem
///   Zustand** — auch ohne Ziel („Eine Anzeige, die es gibt, hat genau eine
///   Form", `CLAUDE.md`).
/// - **Was sie sagt**, geprüft nur auf Stichworte, nicht auf den Satzbau
///   (Kleinschreibung verglichen):
///   - fest, aus der Formel: „fest seit" und das Datum des Festlegens im
///     gemeinsamen Formatierer (`Format.tag`), dazu „berechnet";
///   - fest, von Hand: „von hand" und das Datum;
///   - ein Tag **vor** der ersten Festlegung: „berechnet", aber **kein**
///     „fest seit" — der Tag rechnete damals für sich.
/// - **An einem festen, berechneten Tag zeigen die drei Zeilen die
///   gespeicherten Anteile**, nicht die von heute: Ihre Summe bleibt die
///   Zahl im Ring (#314). **Von Hand gibt es keine Anteile** — die drei
///   Zeilen stehen trotzdem, mit `–/–`.
///
/// Alle Zahlen erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit.
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

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

  const festeAnteile = KalorienzielAnteile(
    grundumsatzKcal: 1900,
    aktivKcal: 800,
    koerperzielKcal: 300,
    gemessen: false,
  );

  const quelle = Key('ernaehrung-herleitung-quelle');
  const zeilen = [
    Key('ernaehrung-herleitung-grundumsatz'),
    Key('ernaehrung-herleitung-aktiv'),
    Key('ernaehrung-herleitung-koerperziel'),
  ];

  Future<TagHuelle> oeffne(
    WidgetTester tester, {
    List<KalorienzielFestlegung> historie = const [],
    Stammdaten stammdaten = huelleStammdaten,
    String? tag,
  }) async {
    final h = tagHuelle(
      jetzt: jetzt,
      tageswerte: tageswerte,
      stammdaten: stammdaten,
    );
    final repo = KalorienzielRepository(h.db);
    for (final f in historie) {
      await repo.setze(f);
    }
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

  String quellText(WidgetTester tester) {
    expect(
      find.descendant(
        of: find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        matching: find.byKey(quelle),
      ),
      findsOneWidget,
      reason: 'die Zeile „woher die Zahl stammt" im aufgeklappten Inhalt',
    );
    return texteUnter(tester, quelle).toLowerCase();
  }

  String datum(String iso) => Format.tag(datumZumAnzeigen(iso)).toLowerCase();

  testWidgets('fest aus der Formel: „fest seit" mit dem Tag, und dass es '
      'berechnet ist', (tester) async {
    await oeffne(
      tester,
      historie: const [
        KalorienzielFestlegung(
          abTag: gestern,
          kcal: 3000,
          herkunft: KalorienzielHerkunft.berechnet,
          anteile: festeAnteile,
        ),
      ],
    );

    final text = quellText(tester);
    expect(text, contains('fest seit'));
    expect(text, contains(datum(gestern)));
    expect(text, contains('berechnet'));
    expect(text, isNot(contains('von hand')));
  });

  testWidgets('fest aus der Formel: die drei Zeilen zeigen die gespeicherten '
      'Anteile, ihre Summe ist die Zahl im Ring', (tester) async {
    final h = await oeffne(
      tester,
      historie: const [
        KalorienzielFestlegung(
          abTag: gestern,
          kcal: 3000,
          herkunft: KalorienzielHerkunft.berechnet,
          anteile: festeAnteile,
        ),
      ],
    );

    expect(h.container.read(ernaehrungsTagProvider(heute)).zielKcal, 3000);
    expect(
      texteUnter(tester, zeilen[0]).toLowerCase(),
      contains(formatNumber(1900)),
    );
    expect(texteUnter(tester, zeilen[1]), contains(formatNumber(800)));
    expect(texteUnter(tester, zeilen[2]), contains(formatNumber(300)));
  });

  testWidgets('von Hand: „von Hand" mit dem Tag — und die drei Zeilen stehen '
      'mit –/–', (tester) async {
    await oeffne(
      tester,
      historie: const [
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 2900,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ],
    );

    final text = quellText(tester);
    expect(text, contains('von hand'));
    expect(text, contains(datum(heute)));

    for (final z in zeilen) {
      expect(find.byKey(z), findsOneWidget, reason: '$z steht');
      expect(
        texteUnter(tester, z),
        contains(ohneWert),
        reason:
            '$z: ein Ziel von Hand hat keine Anteile — –/–, keine 0 und '
            'nicht die heutigen',
      );
    }
  });

  testWidgets('ein Tag vor der ersten Festlegung: berechnet, nicht fest', (
    tester,
  ) async {
    await oeffne(
      tester,
      tag: gestern,
      historie: const [
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 3000,
          herkunft: KalorienzielHerkunft.berechnet,
          anteile: festeAnteile,
        ),
      ],
    );

    final text = quellText(tester);
    expect(text, contains('berechnet'));
    expect(
      text,
      isNot(contains('fest seit')),
      reason: 'gestern lag vor dem Festlegen und rechnete für sich',
    );
  });

  testWidgets('ohne jedes Ziel steht die Zeile trotzdem — dieselbe Form', (
    tester,
  ) async {
    final h = await oeffne(tester, stammdaten: const Stammdaten());
    expect(
      h.container.read(ernaehrungsTagProvider(heute)).zielKcal,
      isNull,
      reason: 'Vorbedingung',
    );
    quellText(tester);
  });
}
