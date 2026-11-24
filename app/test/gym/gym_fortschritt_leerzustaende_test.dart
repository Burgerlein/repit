import 'dart:async';

import 'package:flutter/widgets.dart' show Key, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart'
    show Platzhalter, ohneWert;
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;
import 'package:repit/gym/gym_vorschlag_texte.dart';

import 'gym_fortschritt_support.dart';

/// Leerzustände und die **beiden Pflichtfälle** aus `CLAUDE.md` für den
/// Schirm „Fortschritt pro Übung" (#93).
///
/// Grundlage: `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`,
/// Abschnitte 6 und 8; `CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau
/// eine Form". Die API und die Schlüssel stehen im Kopf von
/// `gym_fortschritt_support.dart`.
///
/// 1. **Fehler `01` — während des Ladens steht nie ein „keine Daten"-Grund.**
///    Zwischen dem Öffnen und dem Eintreffen der Antwort liegt ein
///    Lesevorgang; in diesem Moment darf weder „Noch zu wenige Trainings"
///    noch „Erstes Mal" noch ein „kein Wert" noch eine 0 dastehen. Die
///    Ablage wird dafür **angehalten** (`FortschrittAblage.tor`) — das ist
///    der Moment, ohne dass ein Test wissen muss, wie der Schirm intern
///    liest. Dass dazwischen ein Platzhalter steht, wird über seinen Typ
///    geprüft, nicht über seine Farbe.
/// 2. **Fehler `32` — ein Wert, der dastand, steht nach dem Zurücknavigieren
///    wieder da.** Dasselbe Tor, andersherum: Die Ablage wird **vor** dem
///    zweiten Öffnen angehalten. Steht der Wert trotzdem da, ist er
///    gehalten und nicht neu gelesen — und der Test ist zugleich der auf
///    Hausregel 2.
///
/// **Der leere Fall ist der erste, den Tim sieht:** null Trainings. Er ist
/// kein Sonderfall, sondern die Keine-Daten-Ansicht — dieselbe Form, nur
/// ungefüllt (`CLAUDE.md`).
///
/// Alle Daten sind erfunden.
void main() {
  final bankUebung = ExerciseCatalog.all[idBank]!;
  final seitstuetz = ExerciseCatalog.all[idSeitstuetz]!;

  List<ImportedSession> vier() => [
    bank('S1', morgens(2, 9), 57.5, 10),
    bank('S2', morgens(2, 16), 60, 10),
    bank('S3', morgens(2, 23), 62.5, 8),
    bank('S4', morgens(3, 2), 62.5, 10),
  ];

  /// Der Satz, den der Hinweiskasten ohne Verlauf trägt.
  String erstesMal(Exercise uebung) => vorschlagKurzText(
    Progression.suggest(uebung, const []),
    uebung,
    hatVerlauf: false,
  );

  bool hatPlatzhalter(WidgetTester tester, Key key) => find
      .descendant(
        of: find.byKey(key),
        matching: find.byType(Platzhalter),
        matchRoot: true,
      )
      .evaluate()
      .isNotEmpty;

  /// Höhe und Breite der Abschnitte, die in **jeder** Lage dastehen.
  Map<Key, Size> masse(WidgetTester tester) => {
    for (final key in [
      kFAuswahl,
      kFKachelHoechst,
      kFKachel1rm,
      kFDiagramm,
      kFHinweis,
      kFFussnote,
    ])
      key: tester.getSize(find.byKey(key)),
  };

  group('Fehler 01 — während des Ladens steht nie ein „keine Daten"-Grund', () {
    testWidgets('weder Satz noch Strich noch 0, sondern graue Formen in '
        'derselben Geometrie', (tester) async {
      for (final id in [idBank, idDips, idSeitstuetz]) {
        final h = fortschrittHuelle(uebungId: id);
        // Es steht ein Training in der Ablage — nur weiß der Schirm es noch nicht.
        await h.lege([bank('S0', morgens(3, 2), 60, 10)]);
        h.ablage.tor = Completer<void>();
        await starte(tester, h);
        await tester.pump(const Duration(seconds: 1));

        expect(
          hatPlatzhalter(tester, kFWertHoechst),
          isTrue,
          reason: '$id: Die Kachel steht da, ihr Wert ist eine graue Form',
        );
        expect(hatPlatzhalter(tester, kFWert1rm), isTrue, reason: id);
        for (final key in [kFWertHoechst, kFWert1rm]) {
          expect(
            textVon(tester, key),
            isNot(contains(ohneWert)),
            reason:
                '$id: „–/–" hieße „gelesen, kein Wert" — gelesen ist noch '
                'nichts (Fehler `01`)',
          );
          expect(textVon(tester, key), isNot(matches(nullAlsWert)));
        }

        expect(find.byKey(kFDiagramm), findsOneWidget, reason: id);
        expect(
          find.byKey(kFDiagrammLeer),
          findsNothing,
          reason:
              '$id: „Noch zu wenige Trainings" wäre ein Grund, den es noch '
              'nicht gibt — vielleicht stehen zehn in der Ablage',
        );
        expect(find.byType(Zeitdiagramm), findsNothing, reason: id);
        expect(find.byKey(kFFehler), findsNothing, reason: id);
        expect(find.byKey(kFPlateau), findsNothing, reason: id);

        expect(find.byKey(kFHinweis), findsOneWidget, reason: id);
        expect(
          textVon(tester, kFHinweis),
          isNot(contains(erstesMal(ExerciseCatalog.all[id]!))),
          reason:
              '$id: „Erstes Mal — …" wäre eine Auskunft über Trainings, die '
              'vielleicht da sind. Das Feld `vorschlag` ist hier `null`, '
              'nicht `FirstTime` (Spec 4)',
        );
        expect(hatPlatzhalter(tester, kFHinweis), isTrue, reason: id);

        h.ablage.tor!.complete();
        await verstreiche(tester);
      }
    });

    testWidgets('der Hinweis zur Unterstützung steht auch beim Laden da — er '
        'hängt an der Übung, nicht an den Daten', (tester) async {
      for (final (id, erwartet) in [(idDips, true), (idBank, false)]) {
        final h = fortschrittHuelle(uebungId: id);
        h.ablage.tor = Completer<void>();
        await starte(tester, h);
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.byKey(kFUnterstuetzung),
          erwartet ? findsOneWidget : findsNothing,
          reason: id,
        );
        h.ablage.tor!.complete();
        await verstreiche(tester);
      }
    });

    testWidgets('trifft die Antwort ein, steht an derselben Stelle der Wert', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      h.ablage.tor = Completer<void>();
      await starte(tester, h);
      await tester.pump(const Duration(seconds: 1));
      expect(hatPlatzhalter(tester, kFWertHoechst), isTrue);

      h.ablage.tor!.complete();
      await verstreiche(tester);

      expect(hatPlatzhalter(tester, kFWertHoechst), isFalse);
      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(62.5, bankUebung),
      );
      expect(find.byType(Zeitdiagramm), findsOneWidget);
    });

    testWidgets('derselbe Zustand ohne Tor zeigt „kein Wert" und den Grund', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      expect(textVon(tester, kFWertHoechst), ohneWert);
      expect(textVon(tester, kFWert1rm), ohneWert);
      expect(find.byKey(kFDiagrammLeer), findsOneWidget);
      expect(textVon(tester, kFHinweis), contains(erstesMal(bankUebung)));
      expect(hatPlatzhalter(tester, kFWertHoechst), isFalse);
    });
  });

  group('Der leere Fall — null Trainings', () {
    testWidgets('„noch nichts da": keine 0, keine leere Linie, die Karte '
        'bleibt stehen', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      expect(find.byType(Zeitdiagramm), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(kFDiagramm),
          matching: find.byKey(kFDiagrammLeer),
        ),
        findsOneWidget,
      );
      for (final key in [kFKachelHoechst, kFKachel1rm, kFDiagramm, kFHinweis]) {
        expect(
          textVon(tester, key),
          isNot(matches(nullAlsWert)),
          reason: '$key: „0" ist keine Antwort auf „kein Wert" (`CLAUDE.md`)',
        );
      }
      expect(find.byKey(kFPlateau), findsNothing);
      expect(find.byKey(kFFehler), findsNothing);
    });

    testWidgets('für jede Art von Übung: normal, mit Unterstützung, auf '
        'Zeit', (tester) async {
      for (final id in [idBank, idDips, idSeitstuetz]) {
        final h = fortschrittHuelle(uebungId: id);
        await zeigeFortschritt(tester, h);

        final uebung = ExerciseCatalog.all[id]!;
        expect(textVon(tester, kFWertHoechst), ohneWert, reason: id);
        expect(textVon(tester, kFWert1rm), ohneWert, reason: id);
        expect(
          textVon(tester, kFHinweis),
          contains(erstesMal(uebung)),
          reason: '$id: Der Vorschlag „erstes Mal" ist der aus dem Kern',
        );
        expect(find.byType(Zeitdiagramm), findsNothing, reason: id);
        expect(find.byKey(kFDiagrammLeer), findsOneWidget, reason: id);
        expect(tester.takeException(), isNull, reason: id);
      }
      expect(
        erstesMal(seitstuetz),
        isNotEmpty,
        reason: 'Vorbedingung: auch die Zeitübung hat einen Satz',
      );
    });
  });

  group('Ein einziges Training', () {
    testWidgets('eine Zahl je Kachel, keine Linie, der Vorschlag aus dem '
        'Verlauf', (tester) async {
      final h = fortschrittHuelle();
      const saetze = [(60.0, 10), (62.5, 8)];
      await h.lege([
        sitzung('S1', morgens(3, 2), {idBank: saetze}),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(62.5, bankUebung),
      );
      expect(textVon(tester, kFWert1rm), contains(gymZahlText(80)));
      expect(find.byType(Zeitdiagramm), findsNothing);
      expect(find.byKey(kFDiagrammLeer), findsOneWidget);
      expect(
        textVon(tester, kFHinweis),
        contains(
          vorschlagKurzText(
            Progression.suggest(bankUebung, const [
              [
                CompletedSet(weight: 60, reps: 10),
                CompletedSet(weight: 62.5, reps: 8),
              ],
            ]),
            bankUebung,
            hatVerlauf: true,
          ),
        ),
        reason:
            'Mit einem Training gibt es einen Verlauf — der Vorschlag ist '
            'nicht mehr „Erstes Mal"',
      );
    });
  });

  group('Fehler 32 — ein Wert, der dastand, steht nach dem Zurücknavigieren '
      'wieder da', () {
    testWidgets('zurück und wieder hinein: derselbe Wert, auch wenn die '
        'Ablage jetzt nicht antwortet', (tester) async {
      final h = fortschrittHuelle(mitStapel: true);
      await h.lege(vier());
      await starte(tester, h);
      await oeffneFortschritt(tester);

      final vorher = textVon(tester, kFWertHoechst);
      expect(vorher, vorschlagGewichtText(62.5, bankUebung));
      expect(find.byType(Zeitdiagramm), findsOneWidget);

      await zurueck(tester);
      expect(find.byKey(kFHuelleUebersicht), findsOneWidget);

      // Ab jetzt kommt keine Antwort mehr: Was dasteht, muss gehalten sein.
      h.ablage.tor = Completer<void>();
      final gelesen = h.ablage.lesungen;
      await oeffneFortschritt(tester);

      expect(
        textVon(tester, kFWertHoechst),
        vorher,
        reason: 'Der Wert, der dastand, steht wieder da — sofort',
      );
      expect(
        hatPlatzhalter(tester, kFWertHoechst),
        isFalse,
        reason: 'Zwischendurch erscheint kein Platzhalter (Fehler `32`)',
      );
      expect(find.byKey(kFDiagrammLeer), findsNothing);
      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(
        h.ablage.lesungen,
        gelesen,
        reason:
            'Der Provider hält den Wert (Hausregel 2); er liest nicht bei '
            'jedem Öffnen neu',
      );

      h.ablage.tor!.complete();
      await verstreiche(tester);
    });

    testWidgets('Übung wechseln und zurück: der Wert der ersten steht sofort '
        'wieder da', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idDips: [(-27, 8)],
        }),
        sitzung('S2', morgens(3, 9), {
          idBank: [(62.5, 10)],
          idDips: [(-24.5, 8)],
        }),
      ]);
      await zeigeFortschritt(tester, h);
      final bankWert = textVon(tester, kFWertHoechst);

      await waehleUebung(tester, idDips);
      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(-24.5, ExerciseCatalog.all[idDips]!),
      );

      h.ablage.tor = Completer<void>();
      await waehleUebung(tester, idBank);

      expect(textVon(tester, kFWertHoechst), bankWert);
      expect(hatPlatzhalter(tester, kFWertHoechst), isFalse);
      expect(find.byType(Zeitdiagramm), findsOneWidget);

      h.ablage.tor!.complete();
      await verstreiche(tester);
    });

    testWidgets('wird neu gelesen, bleibt der alte Stand stehen — der '
        'Platzhalter gehört allein in den Ladezustand', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      await zeigeFortschritt(tester, h);
      final vorher = textVon(tester, kFWertHoechst);

      h.ablage.tor = Completer<void>();
      h.container.invalidate(gymSitzungenProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(textVon(tester, kFWertHoechst), vorher);
      expect(hatPlatzhalter(tester, kFWertHoechst), isFalse);
      expect(hatPlatzhalter(tester, kFWert1rm), isFalse);
      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(
        textVon(tester, kFHinweis),
        isNot(contains(erstesMal(bankUebung))),
      );

      h.ablage.tor!.complete();
      await verstreiche(tester);
    });

    testWidgets('ein neues Training erscheint, ohne dass der Schirm neu '
        'gebaut wird — und ohne Platzhalter dazwischen', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([bank('S1', morgens(3, 2), 60, 10)]);
      await zeigeFortschritt(tester, h);
      expect(find.byType(Zeitdiagramm), findsNothing);
      expect(find.byKey(kFDiagrammLeer), findsOneWidget);

      await h.schreiber.legeAb(bank('S2', morgens(3, 9), 65, 10));
      h.ablage.tor = Completer<void>();
      h.container.invalidate(gymSitzungenProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(60, bankUebung),
        reason: 'Bis die Antwort da ist, steht der alte Stand',
      );
      expect(hatPlatzhalter(tester, kFWertHoechst), isFalse);

      h.ablage.tor!.complete();
      await verstreiche(tester);

      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(find.byKey(kFDiagrammLeer), findsNothing);
      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(65, bankUebung),
      );
    });
  });

  group('Gescheitertes Lesen', () {
    testWidgets('sagt, dass es gescheitert ist — nicht „noch zu wenige '
        'Trainings" und nicht „Erstes Mal"', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      h.ablage.fehler = StateError('Platte nicht lesbar (vom Test erzwungen)');
      await zeigeFortschritt(tester, h);

      expect(
        find.descendant(
          of: find.byKey(kFHinweis),
          matching: find.byKey(kFFehler),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(kFDiagrammLeer),
        findsNothing,
        reason:
            '„Noch zu wenige Trainings" wäre falsch: Es stehen vier in der '
            'Ablage, sie ließen sich nur nicht lesen',
      );
      expect(find.byType(Zeitdiagramm), findsNothing);
      expect(
        textVon(tester, kFHinweis),
        isNot(contains(erstesMal(bankUebung))),
      );
      for (final key in [kFWertHoechst, kFWert1rm]) {
        expect(textVon(tester, key), isNot(matches(nullAlsWert)));
        expect(hatPlatzhalter(tester, key), isFalse, reason: '$key');
      }
      expect(find.byKey(kFDiagramm), findsOneWidget);
    });

    testWidgets('ist nicht endgültig: „Erneut lesen" holt den Verlauf, '
        'sobald die Ablage wieder antwortet', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      h.ablage.fehler = StateError('Platte nicht lesbar (vom Test erzwungen)');
      await zeigeFortschritt(tester, h);
      expect(find.byKey(kFErneut), findsOneWidget);

      h.ablage.fehler = null;
      await tester.tap(find.byKey(kFErneut));
      await verstreiche(tester);

      expect(find.byKey(kFFehler), findsNothing);
      expect(
        textVon(tester, kFWertHoechst),
        vorschlagGewichtText(62.5, bankUebung),
        reason:
            'Der Provider hält den Zustand auch im Fehlerfall — ohne diesen '
            'Weg bliebe er bis zum Neustart der App stehen',
      );
      expect(find.byType(Zeitdiagramm), findsOneWidget);
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets('lädt, keine Trainings, ein Training, Verlauf, Plateau, '
        'gescheitert: dieselben Maße an derselben Stelle', (tester) async {
      final faelle = <String, Future<FortschrittHuelle> Function()>{
        'lädt': () async {
          final h = fortschrittHuelle();
          h.ablage.tor = Completer<void>();
          return h;
        },
        'keine Trainings': () async => fortschrittHuelle(),
        'ein Training': () async {
          final h = fortschrittHuelle();
          await h.lege([bank('S1', morgens(3, 2), 60, 10)]);
          return h;
        },
        'Verlauf mit Vorschlag': () async {
          final h = fortschrittHuelle();
          await h.lege(vier());
          return h;
        },
        'Plateau': () async {
          final h = fortschrittHuelle();
          await h.lege([
            for (var i = 0; i < 4; i++)
              bank('P$i', morgens(2, 9 + 7 * i), 60, 10),
          ]);
          return h;
        },
        'gescheitert': () async {
          final h = fortschrittHuelle();
          h.ablage.fehler = StateError('vom Test erzwungen');
          return h;
        },
      };

      final gemessen = <String, Map<Key, Size>>{};
      for (final fall in faelle.entries) {
        final h = await fall.value();
        await starte(tester, h);
        await verstreiche(tester);
        gemessen[fall.key] = masse(tester);
        if (h.ablage.tor != null) h.ablage.tor!.complete();
      }

      final erster = gemessen.entries.first;
      for (final fall in gemessen.entries.skip(1)) {
        for (final key in erster.value.keys) {
          expect(
            fall.value[key],
            erster.value[key],
            reason:
                '${fall.key} gegen ${erster.key}: $key. „Werte da, keine '
                'Werte, lädt — dieselbe Höhe, dieselbe Breite, dieselbe '
                'Stelle. Nur die Füllung unterscheidet sich" (`CLAUDE.md`). '
                'Sonst springt der Schirm, sobald die Antwort eintrifft',
          );
        }
      }
    });
  });
}
