import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;

import 'gym_fortschritt_support.dart';

/// Das Menü der Übungsauswahl im Schirm „Fortschritt pro Übung" nach
/// **Nachtrag 17 Nr. 4** (#551, Plan Task 3.3; Tims Entscheidung vom
/// 20.11.2026): Das Menü bietet **ausschließlich Übungen mit mindestens
/// einem Satz im Verlauf** an — Anker und Bibliothek gleich behandelt. Es
/// beantwortet „wie entwickle ich mich", nicht „was gibt es".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// ## Festlegungen des Test-Agenten — Tim hat sie nicht gesehen
///
/// - **[kFWahlLeer]** (`gym-fortschritt-auswahl-leer`): der eine Satz im
///   Menü, wenn es außer der gerade gewählten Übung nichts anzubieten gibt —
///   statt einer leeren Aktionsliste (Hausregel „eine Form"; die Form des
///   Leerzustands ist Vorschlag, Lücke 4). Sein Wortlaut ist frei, nur der
///   Schlüssel ist fest.
/// - **Die aktuell gewählte Übung steht immer im Menü**, auch ohne Verlauf
///   (Vorschlag, Lücke 4c): Was die Auswahlzeile nennt, muss das Menü
///   wiederfinden, sonst zeigte der Schirm etwas, das es „nicht gibt".
/// - **Die zuletzt gezeigte Übung bleibt nach dem Zurücknavigieren** —
///   Fehler `32` gilt auch für die Auswahl, nicht nur für die Werte.
///
/// Die übrigen Zustände des Schirms stehen in
/// `gym_fortschritt_leerzustaende_test.dart` und bleiben unberührt. Alle
/// Daten sind erfunden.

/// Der eine Satz im Menü, wenn nichts Trainiertes anzubieten ist.
const kFWahlLeer = Key('gym-fortschritt-auswahl-leer');

/// Die Bibliotheksübung der Fälle — erzeugt, kein Anker.
const idKniebeuge = 'squat';

void main() {
  final kniebeuge = ExerciseLibrary.byId(idKniebeuge)!;

  /// Öffnet das Menü der Auswahlzeile, ohne etwas zu wählen.
  Future<void> oeffneMenue(WidgetTester tester) async {
    await tester.tap(find.byKey(kFAuswahl));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Schließt das Menü über die Fläche daneben, ohne etwas zu wählen.
  Future<void> schliesseMenue(WidgetTester tester) async {
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('Nur Trainierte (Nachtrag 17 Nr. 4)', () {
    testWidgets('das Menü bietet genau die Übungen mit mindestens einem Satz '
        'im Verlauf an — Anker und Bibliothek gleich', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idKniebeuge: [(80, 8)],
        }),
      ]);
      await zeigeFortschritt(tester, h);

      await oeffneMenue(tester);

      expect(
        find.byKey(kFWahl(idBank), skipOffstage: false),
        findsOneWidget,
        reason: 'der Anker mit Verlauf steht im Menü',
      );
      expect(
        find.byKey(kFWahl(idKniebeuge), skipOffstage: false),
        findsOneWidget,
        reason:
            'die Bibliotheksübung mit Verlauf steht im Menü — sonst wäre '
            'ihr Fortschritt unsichtbar, obwohl sie eingetragen wird',
      );
      expect(
        find.byKey(kFWahl(idSeitstuetz), skipOffstage: false),
        findsNothing,
        reason:
            'ein Anker ohne Verlauf steht nicht im Menü — Anker und '
            'Bibliothek gleich behandelt',
      );
      expect(
        find.byKey(kFWahl('ab-wheel-rollout'), skipOffstage: false),
        findsNothing,
        reason: 'eine untrainierte Bibliotheksübung auch nicht',
      );
      expect(
        find.byKey(kFWahlLeer, skipOffstage: false),
        findsNothing,
        reason: 'es gibt Trainierte — der Leersatz hat hier nichts verloren',
      );
    });

    testWidgets('eine Bibliotheksübung lässt sich wählen und zeigt ihren '
        'Verlauf', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idKniebeuge: [(80, 8)],
        }),
        sitzung('S2', morgens(3, 9), {
          idKniebeuge: [(82.5, 8)],
        }),
      ]);
      await zeigeFortschritt(tester, h);

      await waehleUebung(tester, idKniebeuge);

      expect(textVon(tester, kFAuswahl), contains(kniebeuge.name));
      expect(
        kachelWert(tester, kFWertHoechst),
        isNotEmpty,
        reason: 'ihr jüngster Stand, keine leere Kachel',
      );
    });
  });

  group('Der Leerzustand (Hausregel „eine Form", Lücke 4)', () {
    testWidgets('ohne ein einziges Training: im Menü steht ein Satz und die '
        'aktuell gewählte Übung — keine leere Aktionsliste', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);
      final vorgabe = ExerciseCatalog.exercisesFor(Workout.a).first;

      await oeffneMenue(tester);

      expect(
        find.byKey(kFWahlLeer, skipOffstage: false),
        findsOneWidget,
        reason:
            'Ein Menü ohne einen Eintrag und ohne ein Wort wäre eine '
            'Sackgasse, der man nicht ansieht, warum',
      );
      expect(
        find.byKey(kFWahl(vorgabe.id), skipOffstage: false),
        findsOneWidget,
        reason:
            'die aktuell gewählte Übung steht im Menü, auch ohne Verlauf '
            '(Vorschlag, Lücke 4c)',
      );
      expect(
        find.byKey(kFWahl(idSeitstuetz), skipOffstage: false),
        findsNothing,
        reason: 'sonst niemand — der volle Katalog ist Geschichte',
      );
    });

    testWidgets('die Auswahlzeile hat mit und ohne Verlauf dieselbe Form', (
      tester,
    ) async {
      final ohne = fortschrittHuelle();
      await zeigeFortschritt(tester, ohne);
      final formOhne = (
        groesse: tester.getSize(find.byKey(kFAuswahl)),
        oben: tester.getTopLeft(find.byKey(kFAuswahl)).dy,
      );

      final mit = fortschrittHuelle();
      await mit.lege([bank('S1', morgens(3, 2), 60, 10)]);
      await zeigeFortschritt(tester, mit);
      final formMit = (
        groesse: tester.getSize(find.byKey(kFAuswahl)),
        oben: tester.getTopLeft(find.byKey(kFAuswahl)).dy,
      );

      expect(
        formOhne,
        formMit,
        reason:
            'Dieselbe Höhe, dieselbe Breite, dieselbe Stelle — nur die '
            'Füllung unterscheidet sich (`CLAUDE.md`)',
      );
    });

    testWidgets('die Vorgabe des Aufrufers steht auch ohne Verlauf im Menü', (
      tester,
    ) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await zeigeFortschritt(tester, h);

      await oeffneMenue(tester);

      expect(
        find.byKey(kFWahl(idDips), skipOffstage: false),
        findsOneWidget,
        reason: 'was die Auswahlzeile nennt, findet das Menü wieder (4c)',
      );
    });
  });

  group('Fehler `01` — Laden ist kein Leerstand', () {
    testWidgets('solange die Ablage schweigt, steht im Menü kein Leersatz', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      h.ablage.tor = Completer<void>();
      await starte(tester, h);
      await verstreiche(tester);

      await oeffneMenue(tester);

      expect(
        find.byKey(kFWahlLeer, skipOffstage: false),
        findsNothing,
        reason:
            'Aus nichts Gelesenem folgt kein „nichts trainiert" — der '
            'Leersatz gehört allein in den bekannten leeren Fall',
      );
      final vorgabe = ExerciseCatalog.exercisesFor(Workout.a).first;
      expect(
        find.byKey(kFWahl(vorgabe.id), skipOffstage: false),
        findsOneWidget,
        reason: 'die gewählte Übung steht trotzdem da — das Menü ist nie leer',
      );

      await schliesseMenue(tester);
      h.ablage.tor!.complete();
      await verstreiche(tester);
    });

    testWidgets('ein gescheitertes Neulesen nimmt keinen Eintrag weg', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege([bank('S1', morgens(3, 2), 60, 10)]);
      await zeigeFortschritt(tester, h);

      await oeffneMenue(tester);
      expect(find.byKey(kFWahl(idBank), skipOffstage: false), findsOneWidget);
      await schliesseMenue(tester);

      h.ablage.fehler = StateError('vom Test erzwungen');
      h.container.invalidate(gymSitzungenProvider);
      await verstreiche(tester);

      await oeffneMenue(tester);
      expect(
        find.byKey(kFWahl(idBank), skipOffstage: false),
        findsOneWidget,
        reason:
            'Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg '
            '(`CLAUDE.md`) — auch keinen Menüeintrag',
      );
      expect(find.byKey(kFWahlLeer, skipOffstage: false), findsNothing);
    });
  });

  group('Fehler `32` — zurück und wieder hinein', () {
    testWidgets('die zuletzt gezeigte Übung bleibt — samt Wert, ohne '
        'Platzhalter', (tester) async {
      final h = fortschrittHuelle(mitStapel: true);
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idKniebeuge: [(80, 8)],
        }),
        sitzung('S2', morgens(3, 9), {
          idKniebeuge: [(82.5, 8)],
        }),
      ]);
      await starte(tester, h);
      await oeffneFortschritt(tester);
      await waehleUebung(tester, idKniebeuge);
      final wert = kachelWert(tester, kFWertHoechst);
      expect(wert, isNotEmpty, reason: 'Voraussetzung: ein Wert stand da');

      await zurueck(tester);
      await oeffneFortschritt(tester);

      expect(
        textVon(tester, kFAuswahl),
        contains(kniebeuge.name),
        reason:
            'Die zuletzt gezeigte Übung steht wieder da (Fehler `32`) — '
            'nicht die Vorgabe',
      );
      expect(
        kachelWert(tester, kFWertHoechst),
        wert,
        reason: 'und ihr Wert steht sofort, ohne Platzhalter dazwischen',
      );
    });
  });
}
