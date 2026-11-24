import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_view.dart';

import 'log_support.dart';

/// Das **Aufwärmen im Vollbild** (#78 mit #40): eine Seite vor Übung 1, auf
/// der man Art, Minuten und Strecke einträgt und überspringen kann.
///
/// Anlass ist Tims Auftrag vom 11.11.2026: „bau bitte cardio auch im
/// fullscreen mode ein, dass man das auch auswählen kann". Die Aufwärm-Karte
/// der Erfassung ist in `gym_log_aufwaermen_test.dart` geprüft; hier geht es
/// um das, was das Vollbild dazu beiträgt:
///
/// - **Die Seite ist da, und die Art lässt sich wählen** — das war der Kern
///   des Auftrags.
/// - **Ein Entwurf, zwei Ansichten.** Im Vollbild eingetragen heißt in der
///   Erfassung sichtbar und umgekehrt. Es gibt keine zweite Quelle.
/// - **Die drei Zustände bleiben drei Antworten** (nichts eingetragen,
///   übersprungen, ausgefüllt) — auch auf dieser Seite.
/// - **Die Seitenzählung:** Die Aufwärm-Seite steht vor Übung 1; „Training
///   abschließen" steht weiter nur auf der Seite der letzten Übung.
/// - **Die Startseite:** Bei einem frischen Training (kein Satz, Aufwärmen
///   unbeantwortet) geht das Vollbild auf der Aufwärm-Seite auf, sonst bei
///   der ersten offenen Übung. Eine Funktion, die eine Wischgeste links vom
///   Sichtbaren liegt, findet nur, wer sie schon kennt.
///
/// Nicht geprüft werden Layout, Schriftgröße und die Darstellung unter der
/// Tastatur.
void main() {
  final ids = [for (final uebung in uebungenVon(Workout.a)) uebung.id];

  bool zeigtImVollbild(Key schluessel) => find
      .descendant(of: find.byKey(kVollbild), matching: find.byKey(schluessel))
      .evaluate()
      .isNotEmpty;

  /// Wischt von der Seite der ersten Übung eine Seite zurück — zur
  /// Aufwärm-Seite.
  Future<void> zumAufwaermen(WidgetTester tester) async {
    await tester.fling(find.byKey(kVollbild), const Offset(400, 0), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Öffnet das Vollbild und steht auf der Aufwärm-Seite — gleich, ob es dort
  /// aufgeht (frisches Training) oder bei einer Übung (dann eine Seite
  /// zurück).
  Future<void> oeffneAufwaermen(WidgetTester tester) async {
    await oeffneVollbild(tester);
    if (!zeigtImVollbild(kAufwaermen)) await zumAufwaermen(tester);
  }

  /// Schließt das Vollbild mit dem Kreuz.
  Future<void> schliesseVollbild(WidgetTester tester) async {
    await tester.tap(find.byKey(kVollbildSchliessen));
    await verstreiche(tester);
  }

  /// Trägt einen Satz ein, legt ab und gibt die Sitzung zurück.
  Future<ImportedSession> legeAb(WidgetTester tester, LogHuelle h) async {
    await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
    await tester.tap(find.byKey(kAbschliessen));
    await verstreiche(tester);
    return (await h.sitzungen()).single;
  }

  group('Die Aufwärm-Seite ist da', () {
    logTest('eine Seite vor Übung 1 trägt Art, Minuten, Strecke und '
        'Überspringen', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      expect(zeigtImVollbild(kAufwaermen), isTrue);
      expect(zeigtImVollbild(kAufwaermenArt), isTrue);
      expect(zeigtImVollbild(kAufwaermenMinuten), isTrue);
      expect(zeigtImVollbild(kAufwaermenKm), isTrue);
      expect(zeigtImVollbild(kAufwaermenUeberspringen), isTrue);
      expect(
        zeigtImVollbild(kFeldWdh(ids[0], 1)),
        isFalse,
        reason: 'Die Aufwärm-Seite ist eine eigene Seite, keine Übung',
      );
    });

    logTest('„Nächste Übung" führt von der Aufwärm-Seite zu Übung 1', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      expect(find.byKey(kVollbildWeiter), findsOneWidget);
      expect(
        find.byKey(kVollbildAbschliessen),
        findsNothing,
        reason: 'Die Aufwärm-Seite ist nie die letzte',
      );
      await tester.tap(find.byKey(kVollbildWeiter));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(zeigtImVollbild(kFeldWdh(ids[0], 1)), isTrue);
      expect(zeigtImVollbild(kAufwaermen), isFalse);
    });

    logTest('„Training abschließen" steht weiter erst auf der letzten '
        'Übung', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      // Von der Aufwärm-Seite bis zur letzten Übung sind es so viele
      // Schritte, wie es Übungen gibt.
      for (var i = 0; i < ids.length; i++) {
        expect(
          find.byKey(kVollbildAbschliessen),
          findsNothing,
          reason: 'Schritt $i: noch nicht die Seite der letzten Übung',
        );
        await tester.tap(find.byKey(kVollbildWeiter));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      expect(zeigtImVollbild(kFeldWdh(ids.last, 1)), isTrue);
      expect(find.byKey(kVollbildAbschliessen), findsOneWidget);
      expect(find.byKey(kVollbildWeiter), findsNothing);
    });

    logTest('die Seite trägt keinen eigenen Navigationsstapel', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(zeigtImVollbild(kAufwaermen), isTrue);
      for (final typ in [
        find.byType(Navigator),
        find.byType(CupertinoNavigationBar),
        find.byType(CupertinoTabView),
        find.byType(CupertinoPageScaffold),
      ]) {
        expect(
          find.descendant(of: find.byKey(kVollbild), matching: typ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });

    logTest('das Vollbild bleibt bei Übung 3, wenn zwei erledigt sind — das '
        'Aufwärmen verschiebt den Start nicht', (tester, h) async {
      await zeigeLog(tester, h);
      for (final id in ids.take(2)) {
        for (var n = 1; n <= ExerciseCatalog.all[id]!.sets; n++) {
          await satz(tester, id, n, wdh: '10');
        }
      }

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kFeldWdh(ids[2], 1)), isTrue);
      expect(zeigtImVollbild(kAufwaermen), isFalse);
    });
  });

  group('Wo das Vollbild aufgeht', () {
    logTest('frisch: auf der Aufwärm-Seite', (tester, h) async {
      await zeigeLog(tester, h);

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kAufwaermen), isTrue);
      expect(zeigtImVollbild(kFeldWdh(ids[0], 1)), isFalse);
    });

    logTest('mit einem Satz: bei Übung 1', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, ids[0], 1, wdh: '10');

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kFeldWdh(ids[0], 1)), isTrue);
      expect(zeigtImVollbild(kAufwaermen), isFalse);
    });

    logTest('übersprungenes Aufwärmen: bei Übung 1', (tester, h) async {
      await zeigeLog(tester, h);
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kFeldWdh(ids[0], 1)), isTrue);
      expect(zeigtImVollbild(kAufwaermen), isFalse);
    });

    logTest('ausgefülltes Aufwärmen: bei Übung 1', (tester, h) async {
      await zeigeLog(tester, h);
      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kFeldWdh(ids[0], 1)), isTrue);
      expect(zeigtImVollbild(kAufwaermen), isFalse);
    });

    logTest('eine halbe Eingabe (Art ohne Minuten) ist keine Antwort: '
        'weiter auf der Aufwärm-Seite', (tester, h) async {
      await zeigeLog(tester, h);
      await waehleArt(tester, WarmUpKind.bike);

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kAufwaermen), isTrue);
    });

    logTest('nach dem Zurücknehmen des Überspringens ist es wieder frisch', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(kAufwaermen), isTrue);
    });
  });

  group('Die Art lässt sich im Vollbild wählen', () {
    logTest('die Auswahl bietet alle sechs Arten', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await tester.tap(find.byKey(kAufwaermenArt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      for (final art in WarmUpKind.values) {
        expect(
          find.byKey(kAufwaermenArtWahl(art)),
          findsOneWidget,
          reason: '${art.code} fehlt in der Auswahl',
        );
      }
    });

    logTest('die gewählte Art steht auf der Seite', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      expect(textVon(tester, kAufwaermenArt), isNot(contains('Rudern')));

      await waehleArt(tester, WarmUpKind.rowing);

      expect(textVon(tester, kAufwaermenArt), contains('Rudern'));
    });

    logTest('Art, Minuten und Strecke landen in der Ablage', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await waehleArt(tester, WarmUpKind.treadmill);
      await tippe(tester, kAufwaermenMinuten, '12');
      await tippe(tester, kAufwaermenKm, '2,1');
      await schliesseVollbild(tester);
      final sitzung = await legeAb(tester, h);

      expect(
        sitzung.warmUp,
        const WarmUpDone(kind: WarmUpKind.treadmill, minutes: 12, km: 2.1),
      );
    });

    logTest('bei Mobility gibt es keine Strecke, und in der Ablage steht '
        '`null`, nie 0', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      expect(zeigtImVollbild(kAufwaermenKm), isTrue, reason: 'Vorbedingung');

      await waehleArt(tester, WarmUpKind.mobility);
      await tippe(tester, kAufwaermenMinuten, '8');

      expect(zeigtImVollbild(kAufwaermenKm), isFalse);
      await schliesseVollbild(tester);
      final sitzung = await legeAb(tester, h);
      expect(
        sitzung.warmUp,
        const WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
      );
    });
  });

  group('Ein Entwurf, zwei Ansichten', () {
    logTest('im Vollbild eingetragen steht in der Erfassung', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await waehleArt(tester, WarmUpKind.crossTrainer);
      await tippe(tester, kAufwaermenMinuten, '15');
      await tippe(tester, kAufwaermenKm, '4,5');
      await schliesseVollbild(tester);

      expect(find.byKey(kVollbild), findsNothing);
      expect(textVon(tester, kAufwaermenArt), contains('Crosstrainer'));
      expect(feldText(tester, kAufwaermenMinuten), '15');
      expect(feldText(tester, kAufwaermenKm), '4,5');
    });

    logTest('in der Erfassung eingetragen steht im Vollbild', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await waehleArt(tester, WarmUpKind.jumpRope);
      await tippe(tester, kAufwaermenMinuten, '5');

      await oeffneAufwaermen(tester);

      expect(textVon(tester, kAufwaermenArt), contains('Seilspringen'));
      expect(feldText(tester, kAufwaermenMinuten), '5');
    });

    logTest('Hin und Zurück: was dastand, steht wieder da', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await schliesseVollbild(tester);

      await oeffneAufwaermen(tester);

      expect(textVon(tester, kAufwaermenArt), contains('Rad'));
      expect(feldText(tester, kAufwaermenMinuten), '10');
    });

    logTest('im Vollbild übersprungen heißt in der Erfassung übersprungen', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await schliesseVollbild(tester);

      expect(
        textVon(tester, kAufwaermenUeberspringen),
        contains('wieder eintragen'),
        reason:
            'Der Knopf der Erfassung zeigt „Übersprungen — wieder '
            'eintragen": derselbe Zustand',
      );
    });
  });

  group('Die drei Zustände bleiben drei Antworten', () {
    logTest('nichts eingetragen: `null`', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      await schliesseVollbild(tester);

      expect((await legeAb(tester, h)).warmUp, isNull);
    });

    logTest('übersprungen: `WarmUpSkipped`', (tester, h) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await schliesseVollbild(tester);

      expect((await legeAb(tester, h)).warmUp, const WarmUpSkipped());
    });

    logTest('Überspringen lässt sich im Vollbild zurücknehmen', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);

      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await schliesseVollbild(tester);

      expect((await legeAb(tester, h)).warmUp, isNull);
    });

    logTest('übersprungen sperrt die Art: Antippen öffnet kein Menü', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();

      await tester.tap(find.byKey(kAufwaermenArt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(kAufwaermenArtWahl(WarmUpKind.bike)), findsNothing);
    });

    logTest('alle drei Zustände sind auf der Seite gleich hoch', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await oeffneAufwaermen(tester);
      double hoehe() => tester.getSize(find.byKey(kAufwaermen)).height;

      final leer = hoehe();
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      final uebersprungen = hoehe();
      await tester.tap(find.byKey(kAufwaermenUeberspringen));
      await tester.pump();
      await waehleArt(tester, WarmUpKind.bike);
      await tippe(tester, kAufwaermenMinuten, '10');
      await tippe(tester, kAufwaermenKm, '3');
      final ausgefuellt = hoehe();

      expect(uebersprungen, leer);
      expect(ausgefuellt, leer);
    });
  });
}
