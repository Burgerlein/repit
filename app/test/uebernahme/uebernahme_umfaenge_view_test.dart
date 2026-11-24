import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/uebernahme/uebernahme_schluessel.dart'
    show
        kTageUmfaengeNeu,
        kTageUmfaengeSchonDa,
        kUebernahmeErgebnisUmfaenge,
        kUebernahmeUmfaengeNichtLesbar,
        kUebernahmeUmfaengeUnbekannt,
        kZahlUmfaengeNeu,
        kZahlUmfaengeNichtLesbar,
        kZahlUmfaengeSchonDa;

import '../gym/log_support.dart' show textVon;
import 'export_fixtur.dart';
import 'uebernahme_support.dart';

/// Die **Berichtskarte der Umfänge** auf dem Schirm „Daten übernehmen"
/// (#498): Zustände und Übergänge, nicht Layout und Beschriftung.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum diese Fälle grün geboren werden
///
/// Die Umsetzung stand vor diesen Tests (`adb3f72`, `529ed12`); hier wird
/// kein noch zu bauendes Verhalten beschrieben, sondern eine **getroffene
/// Entscheidung bewacht** — dieselbe Begründung wie beim Importgrenz-Test
/// (`CLAUDE.md`, „Ein Wächtertest ist von Anfang an grün"). Wird einer
/// dieser Fälle rot, weicht der gebaute Schirm von der Vorlage ab; das ist
/// ein Befund und kein Grund, den Test nachzubessern.
///
/// ## Die Entscheidung, die hier bewacht wird — **von Tim**, 11.11.2026
///
/// **Der Tage-Platz steht in jedem Zustand da und sagt `–/–`, wenn er leer
/// ist.** Er fällt nicht weg. Tims Begründung, wörtlich: „Jede Zeile hat in
/// jedem Zustand dieselbe Gestalt — die Hausregel, die verhindert, dass der
/// Schirm springt, sobald Werte eintreffen." Auch „0 Werte · an 0 Tagen"
/// bleibt so stehen.
///
/// Dazu die beiden Hälften der Leerzustandsregel, die schon für die
/// Trainings-Karte gelten (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat
/// genau eine Form"):
///
/// 1. **Ohne Lauf keine Zahl** — vor dem ersten Lauf, während des Laufs,
///    nach einer abgelehnten und nach einer gescheiterten Übernahme steht
///    in jedem Platz `–/–`. Eine `0` dort behauptete, in der Datei sei
///    nichts gewesen (Fehler `01`).
/// 2. **Nach einem gelaufenen Lauf ist die `0` die Antwort**, und die Karte
///    fällt nicht weg: Eine fehlende Karte sähe aus wie eine App, die keine
///    Umfänge kann.
///
/// Geprüft werden außerdem die drei Auslegungen, die der Implementierende
/// gemeldet statt still gebaut hat: die blanke Zahl im Wertplatz mit dem
/// grauen Zusatz daneben, die Zeile unter „nicht lesbar", die die **Stelle
/// in der Datei** nennt und kein Datum, und die Meldung, die nicht
/// behauptet, die Datei trage keine Umfänge.
///
/// Hülle, Schlüssel und Bedienung stehen in `uebernahme_support.dart`; die
/// Schlüssel der Umfänge werden aus
/// `lib/uebernahme/uebernahme_schluessel.dart` gelesen, nicht abgeschrieben.
///
/// Alle Zahlen, Maße und Zeitpunkte sind **erfunden** und liegen im Jahr
/// 2099 — keine echten Gesundheitsdaten (`CLAUDE.md`).
void main() {
  /* ---- Fixturen ------------------------------------------------------ */

  Map<String, Object?> rohMessung(String datum, Map<String, Object?> werte) => {
    'date': datum,
    'values': werte,
  };

  Uint8List dateiMit({
    List<Object?> sitzungen = const [],
    List<Object?> messungen = const [],
  }) => alsBytes(
    exportDatei(sitzungen: sitzungen, uebrige: {'circumferences': messungen}),
  );

  /// Ein Training, damit die Trainings-Karte nicht leer ausgeht.
  List<Object?> einTraining() => [
    rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A'),
  ];

  /// Drei Werte an zwei Tagen.
  List<Object?> dreiWerte() => [
    rohMessung(zeit(14), {'waist': 81.0, 'chest': 102.4}),
    rohMessung(zeit(21), {'waist': 80.5}),
  ];

  /// Die fünf Plätze der Umfänge-Karte, in der Reihenfolge der Karte.
  const alleUmfangsplaetze = [
    kZahlUmfaengeNeu,
    kTageUmfaengeNeu,
    kZahlUmfaengeSchonDa,
    kTageUmfaengeSchonDa,
    kZahlUmfaengeNichtLesbar,
  ];

  /// Die Karte steht da und **jeder** ihrer Plätze ist ungefüllt.
  void erwarteUmfaengeUngefuellt(WidgetTester tester, {String? warum}) {
    expect(
      find.byKey(kUebernahmeErgebnisUmfaenge),
      findsOneWidget,
      reason: '${warum ?? ''} Die Umfänge-Karte steht in jedem Zustand da',
    );
    for (final platz in alleUmfangsplaetze) {
      expect(
        find.byKey(platz),
        findsOneWidget,
        reason: '${warum ?? ''} $platz steht in jedem Zustand da — auch der '
            'Tage-Platz (Tim, 11.11.2026)',
      );
      expect(
        zahlText(tester, platz),
        ohneWert,
        reason: '${warum ?? ''} $platz: ungefüllt, keine Zahl',
      );
      expect(
        zahlText(tester, platz),
        isNot(matches(eineZiffer)),
        reason: '${warum ?? ''} $platz trägt keine Ziffer',
      );
    }
  }

  /* ---- Ohne Lauf keine Zahl ------------------------------------------ */

  group('Ohne Lauf steht in jedem Platz `–/–` — auch im Tage-Platz', () {
    uebernahmeTest('vor dem ersten Lauf', (tester, h) async {
      await zeigeUebernahme(tester, h);

      erwarteUmfaengeUngefuellt(tester, warum: 'Vor dem ersten Lauf:');
    });

    uebernahmeTest('während des Laufs', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining(), messungen: dreiWerte()));
      h.ablage.tor = Completer<void>();

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeLaeuft]);
      erwarteUmfaengeUngefuellt(tester, warum: 'Während geschrieben wird:');

      h.ablage.tor!.complete();
      await verstreiche(tester);
      expect(stehendeMeldungen(), [kUebernahmeFertig]);
    });

    uebernahmeTest('nach einer abgelehnten Datei', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(alsBytes(fassungEins()));

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeAbgelehnt]);
      erwarteUmfaengeUngefuellt(tester, warum: 'Nach einer Ablehnung:');
    });

    uebernahmeTest('nach einer gescheiterten Übernahme', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));
      h.ablage.scheitert = true;

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeGescheitert]);
      erwarteUmfaengeUngefuellt(tester, warum: 'Nach einem Scheitern:');
    });

    uebernahmeTest('eine Ablehnung nach einem geglückten Lauf räumt die '
        'Zahlen weg, statt alte stehen zu lassen', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));
      await waehle(tester);
      expect(zahlText(tester, kZahlUmfaengeNeu), '3');

      h.waehleDatei(alsBytes(fassungEins()));
      await waehle(tester);

      erwarteUmfaengeUngefuellt(
        tester,
        warum: 'Nach einer Ablehnung, die auf einen Lauf folgte:',
      );
    });

    uebernahmeTest('Der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);

      for (final platz in alleUmfangsplaetze) {
        final label = tester.widget<Text>(find.byKey(platz)).semanticsLabel;
        expect(
          label,
          isNotNull,
          reason: '$platz: „Strich Schrägstrich Strich" ist kein Zustand',
        );
        expect(label, contains('keine Werte'));
      }
    });
  });

  /* ---- Nach einem Lauf ist die 0 eine Antwort ------------------------ */

  group('Nach einem Lauf ist die `0` eine Antwort', () {
    uebernahmeTest('Eine Datei ohne Messungen zeigt `0`, nicht `–/–`', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining()));

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(find.byKey(kUebernahmeErgebnisUmfaenge), findsOneWidget);
      expect(zahlText(tester, kZahlUmfaengeNeu), '0');
      expect(zahlText(tester, kZahlUmfaengeSchonDa), '0');
      expect(zahlText(tester, kZahlUmfaengeNichtLesbar), '0');
    });

    uebernahmeTest('Auch der Tage-Platz steht dann gefüllt da', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining()));

      await waehle(tester);

      expect(zahlText(tester, kTageUmfaengeNeu), 'an 0 Tagen');
      expect(zahlText(tester, kTageUmfaengeSchonDa), 'an 0 Tagen');
    });

    uebernahmeTest('Die Meldung behauptet nicht, die Datei trage keine '
        'Umfänge — `0` kann auch „alles stand schon da" heißen', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining()));

      await waehle(tester);

      final meldung = meldungText(tester, kUebernahmeFertig);
      expect(meldung, contains('Übernommen'));
      expect(
        meldung,
        isNot(contains('Umfang')),
        reason: 'Die Karte zeigt die 0; die Meldung nennt nur, was '
            'übernommen wurde',
      );
    });
  });

  /* ---- Eine Datei mit Messungen -------------------------------------- */

  group('Eine Datei mit Messungen', () {
    uebernahmeTest('Die Zahlen stehen da: Werte und Tage getrennt', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining(), messungen: dreiWerte()));

      await waehle(tester);

      expect(zahlText(tester, kZahlUmfaengeNeu), '3');
      expect(zahlText(tester, kTageUmfaengeNeu), 'an 2 Tagen');
      expect(zahlText(tester, kZahlUmfaengeSchonDa), '0');
      expect(zahlText(tester, kZahlUmfaengeNichtLesbar), '0');
    });

    uebernahmeTest('Der Wertplatz trägt die blanke Zahl, der Zusatz steht '
        'daneben', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));

      await waehle(tester);

      expect(
        zahlText(tester, kZahlUmfaengeNeu),
        '3',
        reason: 'Je Schlüssel genau eine Zahl — ohne Einheit und ohne '
            'Nachsatz, sonst ließe sich keines von beidem prüfen',
      );
      expect(zahlText(tester, kTageUmfaengeNeu), isNot(contains('3')));
    });

    uebernahmeTest('Ein einzelner Tag steht im Singular', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        dateiMit(
          messungen: [
            rohMessung(zeit(14), {'waist': 81.0}),
          ],
        ),
      );

      await waehle(tester);

      expect(zahlText(tester, kZahlUmfaengeNeu), '1');
      expect(zahlText(tester, kTageUmfaengeNeu), 'an 1 Tag');
    });

    uebernahmeTest('Eine Datei, die nur Messungen trägt, bekommt '
        '„Übernommen", nicht „nichts Neues"', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));

      await waehle(tester);

      final meldung = meldungText(tester, kUebernahmeFertig);
      expect(meldung, contains('Übernommen'));
      expect(
        meldung,
        isNot(contains('nichts Neues')),
        reason: 'Es wurden drei Werte geschrieben — „nichts Neues" wäre '
            'Fehler `01` in der Meldung',
      );
      expect(zahlText(tester, kZahlUmfaengeNeu), '3');
      expect(zahlText(tester, kZahlNeu), '0', reason: 'kein Training darin');
    });

    uebernahmeTest('Zweimal dieselbe Datei: nichts Neues, alles schon da', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));
      await waehle(tester);

      h.waehleDatei(dateiMit(messungen: dreiWerte()));
      await waehle(tester);

      expect(zahlText(tester, kZahlUmfaengeNeu), '0');
      expect(zahlText(tester, kTageUmfaengeNeu), 'an 0 Tagen');
      expect(zahlText(tester, kZahlUmfaengeSchonDa), '3');
      expect(zahlText(tester, kTageUmfaengeSchonDa), 'an 2 Tagen');
      expect(meldungText(tester, kUebernahmeFertig), contains('nichts Neues'));
    });

    uebernahmeTest('Was dastand, steht nach dem Zurücknavigieren wieder da '
        '(`32`)', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: dreiWerte()));
      await waehle(tester);
      expect(zahlText(tester, kZahlUmfaengeNeu), '3');

      await tester.pageBack();
      await verstreiche(tester);
      await tester.tap(find.byKey(kHuelleOeffnen));
      await verstreiche(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlUmfaengeNeu), '3');
      expect(zahlText(tester, kTageUmfaengeNeu), 'an 2 Tagen');
    });
  });

  /* ---- Nicht lesbar und Unbekanntes ---------------------------------- */

  group('Was nicht gelesen wurde, steht mit Grund darunter', () {
    /// Ein unplausibler Wert an der Taille, ein guter an der Brust.
    List<Object?> einUnplausiblerWert() => [
      rohMessung(zeit(14), {'waist': 810.0, 'chest': 102.4}),
    ];

    uebernahmeTest('Die Zahl steht in der Karte, die Zeile darunter', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: einUnplausiblerWert()));

      await waehle(tester);

      expect(zahlText(tester, kZahlUmfaengeNichtLesbar), '1');
      expect(zahlText(tester, kZahlUmfaengeNeu), '1');
      expect(find.byKey(kUebernahmeUmfaengeNichtLesbar(0)), findsOneWidget);
    });

    uebernahmeTest('Die Zeile nennt das Maß, die rohe Zahl und die Grenzen', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: einUnplausiblerWert()));

      await waehle(tester);

      final zeile = textVon(tester, kUebernahmeUmfaengeNichtLesbar(0));
      expect(zeile, contains('Taille'));
      expect(
        zeile,
        contains('810'),
        reason: 'Die Zahl steht roh so da, wie sie in der Datei stand',
      );
      expect(zeile, contains('10 bis 200'));
    });

    uebernahmeTest('Die Zeile nennt die Stelle in der Datei und kein Datum', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(messungen: einUnplausiblerWert()));

      await waehle(tester);

      final zeile = textVon(tester, kUebernahmeUmfaengeNichtLesbar(0));
      expect(zeile, contains('Eintrag 1'));
      expect(
        zeile,
        isNot(contains('2099')),
        reason: '`ExportMeasureSkip` trägt keinen Zeitpunkt — und ein '
            'Eintrag ohne lesbares `date` hätte auch keinen',
      );
    });

    uebernahmeTest('Ein unbekanntes Maß wird benannt, nicht gezählt', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        dateiMit(
          messungen: [
            rohMessung(zeit(14), {'waist': 81.0, 'ellbogen': 29.0}),
          ],
        ),
      );

      await waehle(tester);

      expect(find.byKey(kUebernahmeUmfaengeUnbekannt), findsOneWidget);
      expect(
        meldungText(tester, kUebernahmeUmfaengeUnbekannt),
        contains('ellbogen'),
      );
      expect(
        zahlText(tester, kZahlUmfaengeNichtLesbar),
        '0',
        reason: 'Ein unbekannter Schlüssel ist kein Lesefehler',
      );
    });

    uebernahmeTest('Eine saubere Datei trägt weder Zeilen noch Hinweis', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dateiMit(sitzungen: einTraining(), messungen: dreiWerte()));

      await waehle(tester);

      expect(find.byKey(kUebernahmeUmfaengeUnbekannt), findsNothing);
      expect(find.byKey(kUebernahmeUmfaengeNichtLesbar(0)), findsNothing);
      expect(zahlText(tester, kZahlUmfaengeNichtLesbar), '0');
    });
  });
}
