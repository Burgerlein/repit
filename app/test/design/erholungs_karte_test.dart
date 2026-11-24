import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/erholungs_karte.dart';

import 'support.dart';

/// Tests für `ErholungsKarte` und `VitalWert` (Baukasten „Heute,
/// kombiniert", Task H1), nach `recoveryCard` in
/// `docs/screens/components.js`. Keine Swift-Entsprechung vorhanden — der
/// Entwurf ist neu (zu unterscheiden von `RecoveryStatusCard`/`statusCard`
/// auf dem separaten Erholung-Screen, siehe `erholung-screen-entwurf-a`).
///
/// Kernpunkt laut Auftrag: Der Demo-Datensatz
/// `app/test/fixtures/health_export_demo.json` hat absichtlich Lücken (z. B.
/// `restingHR`/`hrvMs`/`respRate` an sechs der 48 Tage `null`), und das
/// Projekt lebt davon, dass „kein Wert" nicht als „0" erscheint
/// (CLAUDE.md, Abschnitt HealthKit). `VitalWert.wert` ist deshalb `String?`,
/// nicht `0` oder ein leerer String als Sentinel — ein Aufrufer, der keinen
/// Wert hat, übergibt `null` und bekommt dafür keinen erfundenen Wert
/// gezeigt.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** `vitalwerte` ist eine Liste
/// beliebiger Länge (wie `vitals` in `components.js`), nicht vier feste
/// Felder (Schlaf/HRV/Ruhepuls/Atmung) — der Entwurf zeigt zwar genau vier,
/// aber nichts an `recoveryCard` erzwingt diese Zahl, und eine feste
/// Vierer-Struktur wäre eine Annahme, die dieser Baustein nicht treffen
/// muss.
///
/// **Zu den Zahlen unten:** Die vier Vitalwerte sind eigene, erfundene
/// Zahlen und nicht aus dem Entwurf übernommen — aus Vorsicht, weil das
/// Board seine eigene „erfundene Beispiele"-Behauptung an anderer Stelle
/// nicht eingehalten hat.
void main() {
  const vierVitalwerteOhneLuecke = [
    VitalWert(name: 'Schlaf', wert: '6:05', hinweis: 'Ø 6:40'),
    VitalWert(name: 'HRV', wert: '61', hinweis: 'Median 58'),
    VitalWert(name: 'Ruhepuls', wert: '68', hinweis: 'Ø 66'),
    VitalWert(name: 'Atmung', wert: '15.2', hinweis: 'Normal 14.0'),
  ];

  testWidgets('zeigt Ueberschrift und Satz', (tester) async {
    await tester.pumpWidget(
      huelle(
        const ErholungsKarte(
          ueberschrift: 'Gut erholt',
          satz: 'Schlaf, HRV, Ruhepuls und Atmung liegen im Normalbereich.',
          akzent: CupertinoColors.systemGreen,
          vitalwerte: vierVitalwerteOhneLuecke,
        ),
      ),
    );

    expect(find.text('Gut erholt'), findsOneWidget);
    expect(
      find.text('Schlaf, HRV, Ruhepuls und Atmung liegen im Normalbereich.'),
      findsOneWidget,
    );
  });

  testWidgets('zeigt alle vier Vitalwerte, wenn keiner fehlt', (tester) async {
    await tester.pumpWidget(
      huelle(
        const ErholungsKarte(
          ueberschrift: 'Gut erholt',
          satz: 'Schlaf, HRV, Ruhepuls und Atmung liegen im Normalbereich.',
          akzent: CupertinoColors.systemGreen,
          vitalwerte: vierVitalwerteOhneLuecke,
        ),
      ),
    );

    expect(find.text('Schlaf'), findsOneWidget);
    expect(find.text('6:05'), findsOneWidget);
    expect(find.text('HRV'), findsOneWidget);
    expect(find.text('61'), findsOneWidget);
    expect(find.text('Ruhepuls'), findsOneWidget);
    expect(find.text('68'), findsOneWidget);
    expect(find.text('Atmung'), findsOneWidget);
    expect(find.text('15.2'), findsOneWidget);
  });

  testWidgets(
    'zeigt bei fehlendem Vitalwert dessen Namen weiter, aber nirgends "0" '
    'als erfundenen Wert',
    (tester) async {
      // Bewusst nullstellenfreie Zahlen fuer die drei vorhandenen Werte,
      // damit eine zufaellige Teilstring-Kollision mit "0" ausgeschlossen
      // ist. HRV fehlt — wie an sechs der 48 Tage im Demo-Datensatz.
      await tester.pumpWidget(
        huelle(
          const ErholungsKarte(
            ueberschrift: 'Erholung unklar',
            satz: 'Für HRV liegt heute Nacht kein Wert vor.',
            akzent: CupertinoColors.systemGrey,
            vitalwerte: [
              VitalWert(name: 'Schlaf', wert: '6:10', hinweis: 'Ø 6:40'),
              VitalWert(name: 'HRV'),
              VitalWert(name: 'Ruhepuls', wert: '70', hinweis: 'Ø 66'),
              VitalWert(name: 'Atmung', wert: '15.4', hinweis: 'Normal 14.0'),
            ],
          ),
        ),
      );

      // Die Zeile bleibt stehen — der Name verschwindet nicht nur, weil
      // der Wert fehlt.
      expect(find.text('HRV'), findsOneWidget);
      // Kein Text zeigt exakt "0" fuer den fehlenden Wert.
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('baut ohne Fehler, wenn die Liste der Vitalwerte leer ist', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(
        const ErholungsKarte(
          ueberschrift: 'Keine Werte',
          satz: 'Für heute Nacht liegen keine Vitalwerte vor.',
          akzent: CupertinoColors.systemGrey,
          vitalwerte: [],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ErholungsKarte), findsOneWidget);
  });
}
