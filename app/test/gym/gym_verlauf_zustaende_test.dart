import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;

import 'support.dart' show ankuendigung;
import 'verlauf_support.dart';

/// Die **Zustände und Übergänge** des Schirms „Letzte Trainings" (#79) und
/// die beiden Anforderungen, auf die es nach `CLAUDE.md` ankommt.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-verlauf-design.md`,
/// Abschnitte 4, 6 und 13. Hülle und API stehen in `verlauf_support.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Die beiden Pflichtfälle
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (Fehler
///    `01`). Zwischen dem Öffnen und dem Eintreffen der Sitzungen liegt ein
///    drift-Lesevorgang, und in diesem Moment darf weder „noch keine
///    Trainings" noch „nicht lesbar" noch eine `0` dastehen — der Schirm
///    behauptete sonst etwas über Tims einzige Kopie seiner Trainings.
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da**
///    (Fehler `32`) — samt der Karte, die der Nutzer aufgeklappt hat.
///
/// ## Der Zustand, den Tim als Erstes sieht
///
/// Er hat heute **null** Trainings eingetragen. Der leere Verlauf sagt
/// „noch nichts da" — nicht „keine Daten" und nicht eine `0`.
///
/// ## Warum die Höhe gemessen werden darf
///
/// `CLAUDE.md` verbietet Layout-Tests; die Leerzustandsregel nennt die Höhe
/// ausdrücklich als Ausnahme: „dieselbe Höhe, dieselbe Breite, dieselbe
/// Stelle". Verglichen wird nur **dieselbe Anzeige mit sich selbst**.
void main() {
  group('Pflicht 1 — während des Ladens steht nie ein „keine Daten"-Grund '
      '(`01`)', () {
    verlaufTest('lädt, und es gibt Trainings: weder Leer-Grund noch Fehler '
        'noch eine Zahl', (tester, h) async {
      // Es gibt einen Verlauf — „noch keine Trainings" wäre falsch.
      await h.fuelle(trainingsReihe(3));
      h.ablage.verlaufTor = Completer<void>();

      await zeigeVerlauf(tester, h);

      expect(
        find.byKey(kVerlaufLeer),
        findsNothing,
        reason:
            'Solange nicht gelesen ist, weiß der Schirm nicht, ob etwas '
            'da ist — „noch nichts da" behauptete es',
      );
      expect(find.byKey(kVerlaufFehler), findsNothing);
      expect(verlaufAllesText(tester), isNot(matches(nochNichtsDa)));
      for (final wert in [kVerlaufWertTrainings, kVerlaufWertVolumen]) {
        expect(
          verlaufText(tester, wert),
          isNot(matches(eineZiffer)),
          reason:
              '„0 Trainings" hieße „nichts getan" — Fehler `01` in neuer '
              'Verpackung',
        );
      }
      expect(verlaufAllesText(tester), isNot(contains(ohneWert)));
    });

    verlaufTest('lädt, und die Ablage ist leer: auch dann kein Grund, '
        'solange nicht nachgesehen ist', (tester, h) async {
      // Der strengste Fall: Es ist wirklich nichts da, und trotzdem darf
      // „noch nichts da" erst stehen, wenn nachgesehen wurde.
      h.ablage.verlaufTor = Completer<void>();

      await zeigeVerlauf(tester, h);

      expect(find.byKey(kVerlaufLeer), findsNothing);
      expect(find.byKey(kVerlaufFehler), findsNothing);
      expect(verlaufAllesText(tester), isNot(matches(nochNichtsDa)));
      expect(
        verlaufText(tester, kVerlaufWertTrainings),
        isNot(matches(eineZiffer)),
      );
    });

    verlaufTest('lädt: die graue Form steht im Wertplatz, danach nicht mehr', (
      tester,
      h,
    ) async {
      await h.fuelle(trainingsReihe(3));
      h.ablage.verlaufTor = Completer<void>();

      await zeigeVerlauf(tester, h);

      for (final wert in [kVerlaufWertTrainings, kVerlaufWertVolumen]) {
        expect(
          find.descendant(of: find.byKey(wert), matching: platzhalter()),
          findsOneWidget,
          reason:
              '$wert: Solange gelesen wird, steht an der Stelle der Zahl '
              'eine graue Form derselben Größe',
        );
      }
      expect(
        find.byKey(kVerlaufKartenLaedt),
        findsOneWidget,
        reason:
            'Wie viele Karten es werden, weiß niemand — eine graue '
            'Kartenzeile hält den Platz',
      );
      expect(find.byKey(kVerlaufKopf('S-0')), findsNothing);

      await gibFrei(tester, h);

      expect(
        platzhalter(),
        findsNothing,
        reason:
            'Der Platzhalter gehört allein in den Ladezustand. Ein '
            'Wert, der da ist, steht ohne graue Form da.',
      );
      expect(find.byKey(kVerlaufKartenLaedt), findsNothing);
      expect(find.byKey(kVerlaufKopf('S-0')), findsOneWidget);
      expect(
        verlaufText(tester, kVerlaufWertTrainings),
        matches(eineZiffer),
        reason: 'Jetzt ist nachgesehen: die Zahl steht da',
      );
    });

    verlaufTest('lädt, dann ist wirklich nichts da: erst jetzt steht der '
        'Grund', (tester, h) async {
      h.ablage.verlaufTor = Completer<void>();
      await zeigeVerlauf(tester, h);
      expect(find.byKey(kVerlaufLeer), findsNothing, reason: 'Vorbedingung');

      await gibFrei(tester, h);

      expect(
        find.byKey(kVerlaufLeer),
        findsOneWidget,
        reason: 'Nachgesehen und leer: jetzt darf der Grund stehen',
      );
      expect(platzhalter(), findsNothing);
    });

    verlaufTest('die Abschnitte stehen auch während des Ladens da', (
      tester,
      h,
    ) async {
      h.ablage.verlaufTor = Completer<void>();
      await zeigeVerlauf(tester, h);

      for (final key in kVerlaufPflichtAbschnitte) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              '$key — „Eine Anzeige, die es gibt, hat genau eine Form": '
              'Keiner verschwindet, weil ein Wert fehlt',
        );
      }
    });
  });

  group('Der leere Verlauf — der Zustand, den Tim als Erstes sieht', () {
    verlaufTest('sagt „noch nichts da": ein Hinweis, keine Karten, keine '
        'Zahl', (tester, h) async {
      await zeigeVerlauf(tester, h);

      expect(find.byKey(kVerlaufLeer), findsOneWidget);
      expect(find.byKey(kVerlaufFehler), findsNothing);
      expect(karten(), findsNothing);
      expect(find.byKey(kVerlaufKartenLaedt), findsNothing);
      expect(platzhalter(), findsNothing);
    });

    verlaufTest('die Kennzahlen stehen da, ohne Zahl: keine 0, kein –/–', (
      tester,
      h,
    ) async {
      await zeigeVerlauf(tester, h);

      for (final key in kVerlaufPflichtAbschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key steht da');
      }
      for (final wert in [kVerlaufWertTrainings, kVerlaufWertVolumen]) {
        expect(
          verlaufText(tester, wert),
          isNot(matches(eineZiffer)),
          reason:
              '$wert: „`0` ist keine Antwort auf ‚kein Wert\'" — ein Ring '
              'auf 0 behauptet „nichts getan"',
        );
      }
      expect(
        verlaufAllesText(tester),
        isNot(contains(ohneWert)),
        reason:
            'Es sind Tims eigene Daten: Es gibt keinen Lauf, der leer '
            'ausgegangen wäre. „–/–" hieße „gelesen, kein Wert".',
      );
    });

    verlaufTest('der Hinweis nennt beide Wege — Eintragen und Übernehmen — '
        'und sagt, dass die Übernahme noch fehlt', (tester, h) async {
      await zeigeVerlauf(tester, h);

      final text = verlaufText(tester, kVerlaufLeer);
      expect(
        text,
        matches(RegExp('eintrag', caseSensitive: false)),
        reason: 'Der erste Weg: selbst ein Training eintragen',
      );
      expect(
        text,
        contains('Daten übernehmen'),
        reason: 'Der zweite Weg: Mehr › Daten übernehmen (#59)',
      );
      expect(
        text,
        matches(ankuendigung),
        reason:
            'Die Übernahme gibt es noch nicht (#59). Ein Hinweis, der '
            'dorthin schickt, ohne das zu sagen, ist eine Zusage, die nicht '
            'stimmt (`CLAUDE.md`)',
      );
    });

    verlaufTest('sagt nirgends „keine Daten"', (tester, h) async {
      await zeigeVerlauf(tester, h);

      expect(
        verlaufAllesText(tester),
        isNot(matches(RegExp('keine\\s+daten', caseSensitive: false))),
        reason:
            '„Keine Daten" ist die Antwort auf eine Abfrage, die leer '
            'ausging. Hier gibt es keine; es ist noch nichts eingetragen.',
      );
    });
  });

  group('Das Lesen scheitert', () {
    verlaufTest('ohne bekannten Stand sagt der Schirm „nicht lesbar" — nicht '
        '„noch nichts da"', (tester, h) async {
      await h.fuelle(trainingsReihe(2));
      h.ablage.lesenScheitert = true;

      await zeigeVerlauf(tester, h);

      expect(
        find.byKey(kVerlaufFehler),
        findsOneWidget,
        reason:
            'Das Gerät ist die einzige Kopie. Wer „noch nichts da" sagt, '
            'obwohl nur das Lesen scheiterte, lässt Tim glauben, seine '
            'Trainings seien weg.',
      );
      expect(find.byKey(kVerlaufLeer), findsNothing);
      expect(verlaufAllesText(tester), isNot(matches(nochNichtsDa)));
      expect(
        verlaufText(tester, kVerlaufWertTrainings),
        isNot(matches(eineZiffer)),
      );
      expect(platzhalter(), findsNothing, reason: 'Es kommt nichts mehr');
      for (final key in kVerlaufPflichtAbschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key steht da');
      }
    });

    verlaufTest('die Anzeige behält ihre Form: Lesefehler, leer und gefüllt '
        'sind dieselben Kacheln', (tester, h) async {
      h.ablage.lesenScheitert = true;
      await zeigeVerlauf(tester, h);
      final fehler = kennzahlenForm(tester);

      h.ablage.lesenScheitert = false;
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);
      expect(find.byKey(kVerlaufLeer), findsOneWidget, reason: 'Vorbedingung');
      final leer = kennzahlenForm(tester);

      await h.fuelle(trainingsReihe(3));
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);
      expect(find.byKey(kVerlaufKopf('S-0')), findsOneWidget);
      final gefuellt = kennzahlenForm(tester);

      expect(leer, fehler, reason: 'leer gegen Lesefehler');
      expect(gefuellt, leer, reason: 'gefüllt gegen leer');
    });

    verlaufTest('ein späteres Lesen, das gelingt, ersetzt den Hinweis', (
      tester,
      h,
    ) async {
      await h.fuelle(trainingsReihe(2));
      h.ablage.lesenScheitert = true;
      await zeigeVerlauf(tester, h);
      expect(
        find.byKey(kVerlaufFehler),
        findsOneWidget,
        reason: 'Vorbedingung',
      );

      h.ablage.lesenScheitert = false;
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);

      expect(find.byKey(kVerlaufFehler), findsNothing);
      expect(find.byKey(kVerlaufKopf('S-0')), findsOneWidget);
    });

    verlaufTest('ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg', (
      tester,
      h,
    ) async {
      await h.fuelle(trainingsReihe(3));
      await zeigeVerlauf(tester, h);
      expect(
        find.byKey(kVerlaufKopf('S-0')),
        findsOneWidget,
        reason: 'Vorbedingung',
      );
      final davor = verlaufText(tester, kVerlaufWertTrainings);

      h.ablage.lesenScheitert = true;
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);

      expect(
        find.byKey(kVerlaufKopf('S-0')),
        findsOneWidget,
        reason:
            '`Fehlgeschlagen` gilt nur, wenn nichts zwischengespeichert '
            'ist. Tims Beschwerde ist, dass Werte verschwinden.',
      );
      expect(find.byKey(kVerlaufFehler), findsNothing);
      expect(find.byKey(kVerlaufLeer), findsNothing);
      expect(verlaufText(tester, kVerlaufWertTrainings), davor);
    });
  });

  group('Pflicht 2 — ein Wert, der dastand, steht nach dem Zurücknavigieren '
      'wieder da (`32`)', () {
    verlaufTest('ein Schirm darüber und wieder zurück: Kennzahlen, Karten '
        'und die aufgeklappte Karte stehen wieder da, ohne Platzhalter '
        'dazwischen', (tester, h) async {
      await h.fuelle(trainingsReihe(4));
      await zeigeVerlauf(tester, h);
      await verstreiche(tester);
      await oeffneKarte(tester, 'S-2');

      final trainings = verlaufText(tester, kVerlaufWertTrainings);
      final volumen = verlaufText(tester, kVerlaufWertVolumen);
      final reihenfolge = kartenReihenfolge(tester);
      expect(reihenfolge, hasLength(4), reason: 'Vorbedingung');
      expect(trainings, matches(eineZiffer), reason: 'Vorbedingung');
      expect(karteOffen('S-0'), isTrue, reason: 'Vorbedingung: neueste offen');
      expect(karteOffen('S-2'), isTrue, reason: 'Vorbedingung: von Hand offen');

      await schiebeDetail(tester);
      await zurueckSchrittweise(
        tester,
        pruefe: () {
          expect(
            platzhalter(),
            findsNothing,
            reason: 'Zwischendurch blitzt keine graue Form auf',
          );
          expect(find.byKey(kVerlaufLeer), findsNothing);
          expect(find.byKey(kVerlaufFehler), findsNothing);
        },
      );

      expect(verlaufText(tester, kVerlaufWertTrainings), trainings);
      expect(verlaufText(tester, kVerlaufWertVolumen), volumen);
      expect(kartenReihenfolge(tester), reihenfolge);
      expect(
        karteOffen('S-0'),
        isTrue,
        reason:
            'Ein offener Abschnitt ist ein Zustand der Oberfläche, kein '
            'abgeleiteter Wert',
      );
      expect(
        karteOffen('S-2'),
        isTrue,
        reason: 'Was der Nutzer aufgeklappt hat, bleibt aufgeklappt',
      );
      expect(karteOffen('S-1'), isFalse);
      expect(
        h.ablage.lesevorgaenge,
        1,
        reason: 'Zurückkommen liest nicht neu — der Provider hält den Wert',
      );
    });

    verlaufTest('den Schirm verlassen und wiederkommen: die Werte stehen '
        'sofort da, auch wenn ein neues Lesen noch hängt', (tester, h) async {
      await h.fuelle(trainingsReihe(4));
      await zeigeVerlauf(tester, h);
      final trainings = verlaufText(tester, kVerlaufWertTrainings);
      final reihenfolge = kartenReihenfolge(tester);
      expect(reihenfolge, hasLength(4), reason: 'Vorbedingung');

      await verlasseVerlauf(tester);
      // Falls der Schirm beim Öffnen neu liest: Das Lesen hängt. Der Wert
      // von vorhin muss trotzdem dastehen.
      h.ablage.verlaufTor = Completer<void>();
      await oeffneVerlauf(tester);

      expect(
        platzhalter(),
        findsNothing,
        reason: 'Ein Wert, der dastand, steht wieder da — nicht als graue Form',
      );
      expect(find.byKey(kVerlaufKartenLaedt), findsNothing);
      expect(find.byKey(kVerlaufLeer), findsNothing);
      expect(verlaufText(tester, kVerlaufWertTrainings), trainings);
      expect(kartenReihenfolge(tester), reihenfolge);
    });
  });

  group('Übergänge', () {
    verlaufTest('ein neu abgelegtes Training erscheint, ohne dass etwas '
        'dazwischen verschwindet', (tester, h) async {
      await h.fuelle([
        sitzung(id: 'ALT-1', datum: vormittag(3)),
        sitzung(id: 'ALT-2', datum: vormittag(5)),
      ]);
      await zeigeVerlauf(tester, h);
      final davor = verlaufText(tester, kVerlaufWertTrainings);
      expect(zahlAus(davor), 2, reason: 'Vorbedingung');

      // Ein Training wird abgelegt, und das Lesen danach hängt.
      await h.ablage.legeAb(sitzung(id: 'NEU', datum: vormittag(0)));
      h.ablage.verlaufTor = Completer<void>();
      h.container.invalidate(gymSitzungenProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(kVerlaufKopf('ALT-1')),
        findsOneWidget,
        reason: 'Während des Nachlesens bleibt stehen, was da war',
      );
      expect(find.byKey(kVerlaufKopf('ALT-2')), findsOneWidget);
      expect(platzhalter(), findsNothing);
      expect(find.byKey(kVerlaufLeer), findsNothing);

      await gibFrei(tester, h);

      expect(kartenReihenfolge(tester), ['NEU', 'ALT-1', 'ALT-2']);
      expect(
        zahlAus(verlaufText(tester, kVerlaufWertTrainings)),
        3,
        reason: 'Die Kennzahl zählt das neue Training mit',
      );
    });

    verlaufTest('gelesen wird einmal je Änderung der Ablage, nicht je Bild '
        'und nicht je Tipp (Hausregel 2)', (tester, h) async {
      await h.fuelle(trainingsReihe(3));
      await zeigeVerlauf(tester, h);
      await verstreiche(tester);
      expect(h.ablage.lesevorgaenge, 1, reason: 'Vorbedingung: ein Lesen');

      // Karten auf- und zuklappen, scrollen, die Fläche ändern: nichts davon
      // ist eine Änderung der Ablage.
      await oeffneKarte(tester, 'S-1');
      await schliesseKarte(tester, 'S-1');
      await oeffneKarte(tester, 'S-2');
      tester.view.physicalSize = const Size(402, 7000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        h.ablage.lesevorgaenge,
        1,
        reason:
            'Eine berechnete Eigenschaft rechnet je Bild — genau das war '
            'Fehler `03`. Der Schirm liest und rechnet einmal und hält es.',
      );

      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);
      expect(
        h.ablage.lesevorgaenge,
        2,
        reason: 'Eine Änderung der Ablage dagegen führt zu genau einem Lesen',
      );
    });

    verlaufTest('die Kennzahlen behalten Form und Stelle: lädt, leer und '
        'gefüllt', (tester, h) async {
      h.ablage.verlaufTor = Completer<void>();
      await zeigeVerlauf(tester, h);
      final laedt = kennzahlenForm(tester);

      await gibFrei(tester, h);
      expect(find.byKey(kVerlaufLeer), findsOneWidget, reason: 'Vorbedingung');
      final leer = kennzahlenForm(tester);

      await h.fuelle(trainingsReihe(3));
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);
      expect(find.byKey(kVerlaufKopf('S-0')), findsOneWidget);
      final gefuellt = kennzahlenForm(tester);

      expect(
        leer,
        laedt,
        reason:
            'Werte da, keine Werte, lädt — dieselbe Höhe, dieselbe Breite, '
            'dieselbe Stelle. Nur die Füllung unterscheidet sich.',
      );
      expect(gefuellt, leer);
    });
  });
}
