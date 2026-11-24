import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_view.dart';

import 'log_support.dart';

/// Die **Aufwärm-Karte** des Schirms „Training eintragen" (#40, mit #78):
/// erste Karte im Training, über Übung 1.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitt 10.2 (die fünf Aufwärm-Spalten), und der Entwurf
/// `docs/screens/screens/gym-log.js` (Entscheidung 4, die vier Zustände).
/// Hülle und API stehen in `log_support.dart`.
///
/// Geschrieben aus Spec und Entwurf, **ohne** den späteren Schirm gesehen
/// zu haben.
///
/// ## Worauf diese Datei zielt
///
/// **Die drei Zustände dürfen nicht einebnen** (Entwurf, Entscheidung 4):
/// nichts eingetragen, übersprungen, ausgefüllt. „Übersprungen ist eine
/// Antwort und für den Plan-Agenten brauchbar; ein leeres Feld ist es
/// nicht." Geprüft wird deshalb, **was in der Ablage steht**: `null`,
/// `WarmUpSkipped`, `WarmUpDone` — drei verschiedene Dinge, nicht zwei.
///
/// Dazu zwei Zusagen des Entwurfs: **Die Strecke erscheint nur, wo sie
/// etwas heißt** (bei Mobility gibt es keine, und in der Ablage steht dann
/// `null`, nie `0`), und **alle drei Zustände haben dieselbe Geometrie** —
/// eine Karte, die beim Überspringen schrumpft, ließe Übung 1 darunter
/// springen (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine
/// Form").
///
/// ## Was hier nicht geprüft wird
///
/// Zone und Puls: Sie kommen aus Apple Health, und das Zuordnen ist #414.
/// Das Ablesen („wird das Aufwärmen besser?") ist #467.
void main() {
  /// Trägt einen einzigen Satz ein — ohne Satz lässt sich kein Training
  /// abschließen — und legt ab. Gibt die abgelegte Sitzung zurück.
  Future<ImportedSession> traineEinenSatzUndSchliesse(
    WidgetTester tester,
    LogHuelle h,
  ) async {
    await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
    await tester.tap(find.byKey(kAbschliessen));
    await verstreiche(tester);
    return (await h.sitzungen()).single;
  }

  group('Die drei Zustände landen als drei verschiedene Antworten in der '
      'Ablage', () {
    logTest('nichts eingetragen: `null`', (tester, h) async {
      await zeigeLog(tester, h);

      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        sitzung.warmUp,
        isNull,
        reason:
            '`null` heißt „nichts eingetragen" — nicht „übersprungen". '
            'Ein erfundenes „übersprungen" behauptete eine Antwort, die '
            'niemand gegeben hat',
      );
    });

    logTest('übersprungen: `WarmUpSkipped`', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        sitzung.warmUp,
        const WarmUpSkipped(),
        reason:
            '„Übersprungen" ist eine Antwort und darf nicht zu `null` '
            'einebnen',
      );
    });

    logTest('ausgefüllt: Art, Minuten und Strecke', (tester, h) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tippe(tester, kAufwaermenKm, '3,2');
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        sitzung.warmUp,
        const WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.2),
      );
    });

    logTest('überspringen lässt sich zurücknehmen — dann ist es wieder '
        '„nichts eingetragen"', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      // Der Entwurf zeichnet „Übersprungen — wieder eintragen": derselbe
      // Knopf, andere Beschriftung.
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(sitzung.warmUp, isNull);
    });

    logTest('nach dem Zurücknehmen lässt sich das Aufwärmen ausfüllen', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await waehleArt(tester, WarmUpKind.rowing);
      await tippe(tester, kAufwaermenMinuten, '8');
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        sitzung.warmUp,
        const WarmUpDone(kind: WarmUpKind.rowing, minutes: 8),
        reason: 'Ohne Strecke: `km` ist `null`, nicht 0',
      );
    });

    logTest('Minuten ohne Strecke: die Strecke ist `null`, nie 0', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.treadmill);
      await tippe(tester, kAufwaermenMinuten, '12');
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      final aufwaermen = sitzung.warmUp;
      expect(aufwaermen, isA<WarmUpDone>());
      expect(
        (aufwaermen! as WarmUpDone).km,
        isNull,
        reason:
            'Eine 0 behauptete „null Kilometer", und daraus rechnete '
            'die Steigerung einen Rückschritt (Entwurf, Entscheidung 4)',
      );
    });
  });

  group('Die Strecke erscheint abhängig von der Art', () {
    logTest('bei Mobility gibt es keine Strecke', (tester, h) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.mobility);

      expect(
        find.byKey(kAufwaermenKm),
        findsNothing,
        reason:
            'Das ist keine fehlende Anzeige, sondern eine, die es für '
            'diese Art nicht gibt',
      );
      expect(find.byKey(kAufwaermenMinuten), findsOneWidget);
    });

    logTest('bei Rad, Laufband, Rudern, Crosstrainer und Seilspringen steht '
        'die Strecke da', (tester, h) async {
      await zeigeLog(tester, h);

      for (final art in WarmUpKind.values) {
        if (art == WarmUpKind.mobility) continue;
        await waehleArt(tester, art);
        expect(
          find.byKey(kAufwaermenKm),
          findsOneWidget,
          reason: '${art.code}: Die Strecke heißt hier etwas',
        );
      }
    });

    logTest('Mobility mit 8 Minuten: Strecke `null` in der Ablage', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.mobility);
      await tippe(tester, kAufwaermenMinuten, '8');
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        sitzung.warmUp,
        const WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
        reason:
            'Spec 10.2: Bei Mobility gibt es keine Strecke — `null`, '
            'nie 0',
      );
    });

    logTest('wer erst eine Strecke tippt und dann auf Mobility wechselt, '
        'legt keine Strecke ab', (tester, h) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tippe(tester, kAufwaermenKm, '3,2');
      await waehleArt(tester, WarmUpKind.mobility);
      final sitzung = await traineEinenSatzUndSchliesse(tester, h);

      expect(
        (sitzung.warmUp! as WarmUpDone).km,
        isNull,
        reason:
            'Eine liegengebliebene Strecke bei Mobility wäre eine '
            'Zahl, die es für diese Art nicht gibt',
      );
      expect((sitzung.warmUp! as WarmUpDone).kind, WarmUpKind.mobility);
    });
  });

  group('Das Aufwärmen ist kein Satz', () {
    logTest('es zählt nicht zum Fortschritt', (tester, h) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tippe(tester, kAufwaermenKm, '3,2');

      expect(
        fortschritt(tester).fertig,
        0,
        reason:
            'Entwurf, Entscheidung 5: „Das Aufwärmen ist kein Satz und '
            'zählt nicht mit"',
      );
      expect(bilanzZahlen(tester), (saetze: 0, volumen: 0.0));
    });

    logTest('Aufwärmen allein macht noch kein Training', (tester, h) async {
      await zeigeLog(tester, h);

      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(
        find.byType(GymLogView),
        findsOneWidget,
        reason:
            '„Training abschließen" ist abgeblendet, solange kein '
            'einziger Satz zählt (Spec 3.8) — zehn Minuten Rad sind kein '
            'Training',
      );
      expect(await h.sitzungen(), isEmpty);
    });

    logTest('Abschließen ohne Satz legt auch ein übersprungenes Aufwärmen '
        'nicht ab', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(find.byType(GymLogView), findsOneWidget);
      expect(await h.sitzungen(), isEmpty);
    });
  });

  group('Alle drei Zustände haben dieselbe Geometrie', () {
    logTest('die Karte springt nicht zwischen leer, übersprungen und '
        'ausgefüllt', (tester, h) async {
      await zeigeLog(tester, h);
      double hoehe() => tester.getSize(find.byKey(kAufwaermen)).height;
      // Wie die erste Übung darunter liegt: Springt die Karte, springt sie.
      double lage() => tester.getTopLeft(find.byKey(kUebung(idBank))).dy;

      final leerHoehe = hoehe();
      final leerLage = lage();

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      expect(
        hoehe(),
        closeTo(leerHoehe, 0.5),
        reason:
            'Eine Karte, die beim Überspringen schrumpft, ließe Übung 1 '
            'darunter springen (Entwurf, Entscheidung 4)',
      );
      expect(lage(), closeTo(leerLage, 0.5));

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tippe(tester, kAufwaermenKm, '3,2');
      expect(
        hoehe(),
        closeTo(leerHoehe, 0.5),
        reason: 'Ausgefüllt mit Strecke hat dieselben Zeilen wie leer',
      );
      expect(lage(), closeTo(leerLage, 0.5));
    });
  });
}
