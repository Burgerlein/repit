import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_editor_provider.dart';
import 'gym_editor_support.dart';

/// Die **Vorschau** der Auswahl und das **Hilfe-?** des Einstellblatts
/// (Nachtrag 29 der Spec `2026-11-19-eigene-trainings-design.md`, #561/#562;
/// Entwurf `gym-training-editor.js`, Varianten `uebung-vorschau`,
/// `uebung-einstellen`, `uebung-waehlen`) — **nur Zustände und Übergänge**.
///
/// Tims Entscheidung vom 23.11.2026 kippt Nachtrag 28 Nr. 1 für den
/// Auswahl-Weg: Antippen fügt **nicht** mehr hinzu, es öffnet das Blatt als
/// Vorschau; erst „Speichern" fügt mit den eingestellten Werten hinzu,
/// „Zurück" verwirft. Der Zeilen-Weg (Übung schon im Training) bleibt wie
/// in Nachtrag 28; „Entfernen" rückt dort ans Ende (Nr. 3 — Lage prüft kein
/// Test über das Genannte hinaus, nur der angepasste Bild-Fall in
/// `gym_editor_view_test.dart`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// ## Festlegungen des Test-Agenten — Tim hat sie nicht gesehen
///
/// Die Schlüssel (Zeichenketten sind der Vertrag, Dart-Namen stehen in
/// `gym_editor_support.dart`): [kBlattSpeichern]
/// (`gym-editor-blatt-speichern`), [kBlattZurueck]
/// (`gym-editor-blatt-zurueck`, auf **beiden** Wegen am „Zurück" des
/// Blatts), [kBlattHilfe] (`gym-editor-blatt-hilfe`), [kBlattHilfeModal]
/// (`gym-editor-blatt-hilfe-modal`), [kBlattHilfeSchliessen]
/// (`gym-editor-blatt-hilfe-schliessen`). Der Vorlesetext des ? nennt den
/// Zustand („Hilfe …"), nicht das Zeichen; die Empfehlungs-Kennzeichnung im
/// Modal folgt `CLAUDE.md` „Keine Diagnosen" (das Wort „Empfehlung" ist
/// Anforderung, der übrige Wortlaut Vorschlag). „Zuziehen verwirft" bleibt
/// der Prüfanleitung am Gerät — eine Barrier-Geste ist im Widget-Test
/// Geometrie-Raterei.
void main() {
  final bank = ExerciseLibrary.byId('benchPress')!;

  GymEditorStand stand(TrainingsHuelle h) =>
      h.container.read(gymEditorProvider(const GymEditorQuelle.neu()));

  /// Öffnet einen neuen Editor samt Auswahl.
  Future<TrainingsHuelle> auswahl(WidgetTester tester) async {
    final h = editorHuelle();
    await oeffneNeuenEditor(tester, h);
    await tippe(tester, find.byKey(kGymEditorHinzufuegen));
    expect(find.byKey(kGymEditorWahl), findsOneWidget);
    return h;
  }

  /// Tippt das „+" des **ersten** Steppers im offenen Blatt — die
  /// Sätze-Zeile steht im Abschnitt „Umfang" zuoberst (Entwurf
  /// `uebung-vorschau`). Über die Struktur, nicht über einen Wortlaut:
  /// Das „+" ist ein Zeichen des Bausteins, keine Beschriftung.
  Future<void> saetzeMehr(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byKey(kGymEditorBlatt),
            matching: find.widgetWithText(CupertinoButton, '+'),
          )
          .first,
    );
    await tester.pump();
  }

  /// Ein Widget-Test mit Semantik — das Handle wird **im** Test freigegeben
  /// (wie in `gym_editor_view_test.dart`).
  void semantikTest(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) => editorTest(name, (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });

  group('Die Vorschau (Nachtrag 29 Nr. 1)', () {
    editorTest('Antippen öffnet das Blatt — das Training ist unverändert, '
        'ohne Position, ohne Entfernen, mit „Speichern"', (tester) async {
      final h = await auswahl(tester);

      await tippeInAuswahl(tester, 'benchPress');

      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      expect(
        stand(h).uebungen,
        isEmpty,
        reason:
            '„Wenn ich sie andrücke, ist sie schon drin, obwohl ich sie '
            'mir erst mal anschauen wollte" (Tim) — Antippen fügt nichts '
            'mehr hinzu',
      );
      expect(
        find.byKey(kGymEditorBlattPosition),
        findsNothing,
        reason: 'keine Position — die Übung ist noch nicht drin',
      );
      expect(
        find.byKey(kGymEditorBlattEntfernen),
        findsNothing,
        reason: 'ein Entfernen-Knopf behauptete das Gegenteil',
      );
      expect(
        find.byKey(kBlattSpeichern),
        findsOneWidget,
        reason: 'oben „Speichern" statt „Fertig"',
      );
      expect(
        find.byKey(kGymEditorBlattSaetze),
        findsOneWidget,
        reason: 'Sätze und Wdh-Bereich sind einstellbar',
      );
      expect(find.byKey(kGymEditorBlattWdhVon), findsOneWidget);
      expect(find.byKey(kGymEditorBlattWdhBis), findsOneWidget);
    });

    editorTest('„Zurück" verwirft: nichts hinzugefügt, die Auswahl steht '
        'wieder da — Suchtext und Scrollposition unverändert', (
      tester,
    ) async {
      final h = await auswahl(tester);
      await gebeEin(tester, kGymEditorWahlSuche, 'curl');
      await tester.pumpAndSettle();
      final erste = ExerciseLibrary.search('curl').first.id;
      await zeigeWahlZeile(tester, erste);
      final lage = tester.getTopLeft(find.byKey(kGymEditorWahlUebung(erste)));

      await tippe(tester, find.byKey(kGymEditorWahlUebung(erste)));
      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      await tippe(tester, find.byKey(kBlattZurueck));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(find.byKey(kGymEditorWahl), findsOneWidget);
      expect(stand(h).uebungen, isEmpty, reason: 'verworfen heißt verworfen');
      expect(
        feldInhalt(tester, kGymEditorWahlSuche),
        'curl',
        reason: 'der Suchtext bleibt',
      );
      expect(
        tester.getTopLeft(find.byKey(kGymEditorWahlUebung(erste))),
        lage,
        reason: 'die Scrollposition bleibt',
      );
      expect(
        find.byKey(kGymEditorWahlSchonDrin(erste)),
        findsNothing,
        reason: 'nicht abgeblendet — sie ist ja nicht drin',
      );

      await tippe(tester, find.byKey(kGymEditorWahlUebung(erste)));
      expect(
        find.byKey(kGymEditorBlatt),
        findsOneWidget,
        reason: 'und sofort wieder ansehbar',
      );
    });

    editorTest('„Speichern" fügt mit den **eingestellten** Werten hinzu '
        'und kehrt zur Auswahl zurück — die Zeile abgeblendet', (
      tester,
    ) async {
      final h = await auswahl(tester);
      await tippeInAuswahl(tester, 'benchPress');

      await saetzeMehr(tester);
      expect(
        stand(h).uebungen,
        isEmpty,
        reason: 'auch Einstellen fügt noch nichts hinzu',
      );

      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(
        find.byKey(kGymEditorWahl),
        findsOneWidget,
        reason: 'zurück in der Auswahl, nicht in der Übungsliste',
      );
      final e = stand(h).uebungen.single;
      expect(e.exerciseId, 'benchPress');
      expect(
        e.sets,
        bank.sets + 1,
        reason:
            'die in der Vorschau eingestellten Sätze, nicht die Vorbelegung',
      );
      expect(e.repLow, bank.repLow);
      expect(e.repHigh, bank.repHigh);
      expect(find.byKey(kGymEditorWahlSchonDrin('benchPress')), findsOneWidget);
      expect(
        deckkraft(tester, find.byKey(kGymEditorWahlUebung('benchPress'))),
        lessThan(1),
        reason: 'abgeblendet „schon im Training"',
      );
    });

    editorTest('der Zeilen-Weg bleibt: Position und Entfernen stehen da, '
        '„Zurück" behält die Übung', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));

      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      expect(
        find.byKey(kGymEditorBlattPosition),
        findsOneWidget,
        reason: 'die Übung ist drin — Position gibt es (Nachtrag 29 Nr. 1)',
      );
      expect(find.byKey(kGymEditorBlattEntfernen), findsOneWidget);
      expect(
        find.byKey(kBlattSpeichern),
        findsNothing,
        reason: 'hier heißt es weiter „Fertig", nicht „Speichern"',
      );
      expect(find.byKey(kGymEditorBlattFertig), findsOneWidget);

      await tippe(tester, find.byKey(kBlattZurueck));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(
        stand(h).uebungen,
        hasLength(1),
        reason: '„Zurück" behält — zurückgenommen wird nur über „Entfernen"',
      );
    });
  });

  group('Das Hilfe-? in der Umfang-Kopfzeile (Nachtrag 29 Nr. 2)', () {
    editorTest('in der Vorschau: das ? steht da, öffnet das Modal, '
        'Schließen geht — das Blatt bleibt', (tester) async {
      await auswahl(tester);
      await tippeInAuswahl(tester, 'benchPress');

      expect(find.byKey(kBlattHilfe), findsOneWidget);
      expect(find.byKey(kBlattHilfeModal), findsNothing);

      await tippe(tester, find.byKey(kBlattHilfe));
      expect(find.byKey(kBlattHilfeModal), findsOneWidget);
      expect(
        textVonSchluessel(tester, kBlattHilfeModal),
        matches(RegExp('empfehlung', caseSensitive: false)),
        reason:
            'Trainingsempfehlungen sind als allgemeine Empfehlung '
            'gekennzeichnet (`CLAUDE.md` „Keine Diagnosen", Nachtrag 29)',
      );

      await tippe(tester, find.byKey(kBlattHilfeSchliessen));
      expect(find.byKey(kBlattHilfeModal), findsNothing);
      expect(
        find.byKey(kGymEditorBlatt),
        findsOneWidget,
        reason: 'das Schließen schließt das Modal, nicht das Blatt',
      );
    });

    editorTest('im Zeilen-Weg: dasselbe ?, dasselbe Modal', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));

      expect(find.byKey(kBlattHilfe), findsOneWidget);
      await tippe(tester, find.byKey(kBlattHilfe));
      expect(find.byKey(kBlattHilfeModal), findsOneWidget);
      await tippe(tester, find.byKey(kBlattHilfeSchliessen));
      expect(find.byKey(kBlattHilfeModal), findsNothing);
    });

    editorTest('die alten Erklärfüße stehen nicht mehr im Blatt', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));

      // Über die Zeichenkette, nicht die Konstante: Die Implementierung darf
      // Schlüssel und Text der Füße entfernen, ohne diese Datei zu brechen.
      expect(
        find.byKey(const Key('gym-editor-blatt-steigerung-auskunft')),
        findsNothing,
        reason:
            'Der Vorbelegungs-/Steigerungs-Fuß ist ins Hilfe-Modal gezogen '
            '(Nachtrag 29 Nr. 2)',
      );
    });

    semantikTest('der Vorlesetext des ? nennt den Zustand, nicht das '
        'Zeichen', (tester) async {
      await auswahl(tester);
      await tippeInAuswahl(tester, 'benchPress');

      expect(
        semantikTexte(tester, find.byKey(kBlattHilfe)),
        contains('hilfe'),
        reason: '„Hilfe …", nicht „Fragezeichen"',
      );
    });
  });
}
