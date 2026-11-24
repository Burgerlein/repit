import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart';
import 'package:repit/gym/gym_editor_provider.dart';
import 'package:repit/gym/gym_editor_texte.dart'
    show gymEditorWahlFuss;
import 'package:repit/gym/gym_log_schluessel.dart'
    show kGymBild, kGymBildAttribution, kGymBildFrame;
import 'package:repit/gym/gym_log_view.dart' show GymLogView;
import 'package:repit/gym/uebungsbild_animation.dart';
import 'package:repit/gym/uebungsbilder.dart' show repdbAttribution;

import '../design/muskel_figur_support.dart' show kMuskelFigurSeite;
import 'gym_editor_support.dart';

/// Widget-Tests für den **Editor-Schirm** (#534 unter #531, Task 3.5 des
/// Plans `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`) —
/// **Zustände und Übergänge**, nicht Layout und Beschriftung (`CLAUDE.md`).
/// Der Zustand dahinter steht in `gym_editor_provider_test.dart`, die
/// Datenbank in `app/test/data/gym_training_entwurf_test.dart`; Hülle,
/// Fixturen und die **Festlegungen zu den Methoden** im Kopf von
/// `gym_editor_support.dart`, die Schlüssel in
/// `lib/gym/gym_training_editor_schluessel.dart` (vom Test-Agenten angelegt).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Fehler `01`:** Solange der Editor liest, steht kein „fehlt"-Grund und
///   keine Null (Spec 9.6, 9.3).
/// - **Fehler `32`:** Ein eingegebener Stand übersteht das Öffnen und
///   Schließen der Blätter (Einstellblatt, Auswahl) **und** das
///   Zurücknavigieren — als Entwurf, über die Entwurfs-Kachel der Übersicht.
/// - **Speichern aus, und der Satz sagt warum — an derselben Stelle in jedem
///   Zustand**, leer, wenn nichts fehlt (keine springende Karte, Spec 9.6
///   und `CLAUDE.md`: „Eine Anzeige, die es gibt, hat genau eine Form").
/// - **Abbrechen** ohne Änderung fragt nichts; mit Änderung fragt es
///   (System-Rückfrage: behalten, verwerfen, weiter) — **auch bei
///   `bearbeite`** (Spec 22 Nr. 3, hebt 17.14 auf).
/// - **Die Wege hinein:** „+" und Fuß-Knopf (neu), Entwurfs-Kachel
///   (`entwurf`, **nicht** das Detail), „Bearbeiten" im Detail (Eigenes →
///   `bearbeite`, Template → `kopie`).
/// - **Die Wege hinaus (Spec 17 Nr. 13):** Neu und Kopie → die Übersicht,
///   eine Änderung → das Detail; **ein im Editor gespeichertes Training ist
///   sofort in der Übersicht** (Invalidierung).
/// - **Die Kopie ist ein Neues** (Tim, 18.11.2026): Hinweis „Kopie von …",
///   Name vorbelegt, **das Template bleibt nach dem Speichern unverändert**.
/// - **Zeitübung: Sekunden, nicht Wiederholungen** (Spec 9.4);
///   **„schon im Training" abgeblendet** (9.4); die **leere Suche** sagt es
///   in einem Satz (9.5).
/// - **Vorlesetexte nennen den Zustand, nicht das Zeichen** (`CLAUDE.md`,
///   Spec 9.7): „Dauer, noch nicht geschätzt", nie „Strich".
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Leer nicht speicherbar; Selbstsicherung,
///   Abbrechen-Rückfrage und Entwurfs-Kachel (19.11.2026, Spec 22 Nr. 3);
///   Verschieben über Griff **und** ↑/↓ (18.11.2026); die kleinen
///   Eingabeflächen sind Standard-iOS-Elemente ohne eigenen Entwurf
///   (19.11.2026, Spec 22 Nr. 4); Templates sind nicht löschbar, das
///   Detail eines Templates hat keine Löschen-Zeile (Spec 26 Nr. 1).
/// - **Vorschläge der Spec, hier vorausgesetzt:** Zielschirm nach dem
///   Speichern (17 Nr. 13); Name ist Pflicht (17 Nr. 7); die Gruppierung
///   der Auswahl nach Hauptmuskel (höchstes Gewicht, bei Gleichstand der
///   kleinere `Muscle.index`) und alphabetisch darin (9.5); „Übung 2 von 5"
///   (9.4); Wortlaute werden **nicht** geprüft — nur Stichwörter, wo ein
///   Zustand sie braucht.
/// - **Festlegungen des Test-Agenten, Tim hat sie nicht gesehen:** Die Lage
///   der Schlüssel (Kopf von `gym_training_editor_schluessel.dart`); dass
///   die Tests den Editor **nur über seine Zugänge** erreichen („+", Kachel,
///   „Bearbeiten"), nie über einen Konstruktor. *(Dass die Auswahl nach dem
///   Antippen schließt, stand hier bis zum 20.11.2026; Spec 28 Nr. 1 ersetzt
///   es — Antippen öffnet das Einstellblatt, „Fertig" kehrt zur Auswahl
///   zurück. Ein Vorschlag des Test-Agenten, den Tims Feedback überholt hat.)*
///
/// ## Nachtrag 20.11.2026 — Tims Editor-Feedback (Spec 28, #553, #554)
///
/// - **Auswahl → Antippen** fügt hinzu **und** öffnet das Einstellblatt;
///   „Entfernen" nimmt das Hinzufügen zurück; „Fertig" kehrt zur Auswahl
///   zurück; zwei Übungen nacheinander bleiben flüssig (Nr. 1).
/// - **Bild im Einstellblatt:** mit Bild steht unten dieselbe
///   Zwei-Standbild-Animation wie in der Erfassung, ohne Bild **nichts** —
///   kein Platzhalter; beide Wege ins Blatt (Nr. 2).
/// - **Muskelfigur im Editor** [#554]: zwischen Stamm und Übungsliste, beide
///   Seiten, färbt `WorkoutMuscles.trained` des aktuellen Stands, feste Maße
///   (Nr. 3).
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Ziehen am Griff** (zu unzuverlässig im Widget-Test) — die Reihenfolge
///   prüfen die Aktionen „Nach oben/Nach unten" und ↑/↓ im Blatt; das Ziehen
///   selbst steht in der Prüfanleitung.
/// - **Die Stepper für Sätze und Wiederholungen und die Tag-Eingabe** — die
///   Spec nennt Standard-iOS-Elemente ohne Form; geprüft wird, was sie
///   **tragen** (`gym_editor_provider_test.dart`).
/// - **Der Wortlaut** der Rückfragen, Fußtexte, Titel.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden.**
void main() {
  final push = WorkoutTemplates.byId('Push')!;

  /// Ein Widget-Test mit Semantik — das Handle wird **im** Test
  /// freigegeben.
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

  Future<TrainingsHuelle> huelleMitEigenem({
    String name = 'Kurzhantel zuhause',
    List<String> tags = const ['Home'],
  }) async {
    final repo = EditorRepo(neueDb());
    final h = editorHuelle(repo: repo);
    await legeEigenes(h.repo, 'E-1', name: name, tags: tags);
    return h;
  }

  Future<TrainingsHuelle> huelleMitEntwurf() async {
    final repo = EditorRepo(neueDb());
    final h = editorHuelle(repo: repo);
    await legeEntwurf(h.repo, 'ENT-1');
    return h;
  }

  Future<void> oeffneEntwurfsKachel(
    WidgetTester tester,
    TrainingsHuelle h, {
    String id = 'ENT-1',
    bool warte = true,
  }) async {
    await oeffneUebersicht(tester, h);
    await tippe(
      tester,
      find.byKey(kGymTrainingsName(id)),
      warte: warte,
      warnIfMissed: false,
    );
  }

  /// Ob ein Widget da **und** nicht unsichtbar ist.
  bool sichtbar(WidgetTester tester, Key key) =>
      find.byKey(key).evaluate().isNotEmpty &&
      deckkraft(tester, find.byKey(key)) > 0;

  GymEditorStand editorStand(TrainingsHuelle h, GymEditorQuelle quelle) =>
      h.container.read(gymEditorProvider(quelle));

  group('Die Wege hinein (Spec 7.6, Plan 3.8)', () {
    for (final eintrag in {
      'das „+" der Übersicht': kGymTrainingsPlus,
      'der Fuß-Knopf der Übersicht': kGymTrainingsAnlegen,
    }.entries) {
      editorTest('${eintrag.key} öffnet den Editor, neu — ohne '
          'Kopie-Hinweis und ohne Löschen', (tester) async {
        final h = editorHuelle();
        await oeffneUebersicht(tester, h);

        expect(
          ohneWirkung(tester, eintrag.value),
          isFalse,
          reason: '${eintrag.value} hat jetzt ein Ziel (Plan 3.8)',
        );
        await tippe(tester, find.byKey(eintrag.value));

        expect(find.byKey(kGymEditor), findsOneWidget);
        expect(find.byKey(kGymEditorKopieHinweis), findsNothing);
        expect(find.byKey(kGymEditorLoeschen), findsNothing);
        expect(feldInhalt(tester, kGymEditorName), '');
      });
    }

    editorTest('die Entwurfs-Kachel öffnet den Editor — nicht das Detail', (
      tester,
    ) async {
      final h = await huelleMitEntwurf();

      await oeffneEntwurfsKachel(tester, h);

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymTrainingDetail), findsNothing);
      expect(feldInhalt(tester, kGymEditorName), 'Oberkörper kurz');
      expect(uebungenImBaum(tester), ['benchPress', 'lateralRaise']);
    });

    editorTest('„Bearbeiten" an einem Template ist wirksam und öffnet den '
        'Editor als Kopie', (tester) async {
      final h = editorHuelle();
      await oeffneDetailVon(tester, h, 'Push');

      expect(
        ohneWirkung(tester, kGymTrainingDetailBearbeiten),
        isFalse,
        reason: 'Das Ziel entsteht mit #534 (Plan 3.8)',
      );
      await tippe(tester, find.byKey(kGymTrainingDetailBearbeiten));

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorKopieHinweis), findsOneWidget);
      expect(find.byKey(kGymEditorLoeschen), findsNothing);
    });

    editorTest('„Bearbeiten" an einem Eigenen öffnet den Editor ohne '
        'Kopie-Hinweis — und mit „Training löschen"', (tester) async {
      final h = await huelleMitEigenem();

      await oeffneBearbeiten(tester, h, 'E-1');

      expect(find.byKey(kGymEditorKopieHinweis), findsNothing);
      expect(find.byKey(kGymEditorLoeschen), findsOneWidget);
      expect(feldInhalt(tester, kGymEditorName), 'Kurzhantel zuhause');
    });

    editorTest('„Training starten" ist für ein Eigenes jetzt wirksam und '
        'führt in die Erfassung; „Teilen" bleibt bis #535 abgeblendet', (
      tester,
    ) async {
      final h = await huelleMitEigenem();
      await oeffneDetailVon(tester, h, 'E-1');
      h.befehle.clear();

      expect(
        ohneWirkung(tester, kGymTrainingDetailStarten),
        isFalse,
        reason: 'Die Erfassung läuft über `TrainingKey` (Spec 15)',
      );
      expect(
        ohneWirkung(tester, kGymTrainingDetailTeilen),
        isTrue,
        reason: 'Das Teilen kommt mit #535',
      );
      final kontext = tester.element(find.byKey(kGymTrainingDetail));
      await tester.tap(find.byKey(kGymTrainingDetailStarten));
      await tester.pumpAndSettle();

      expect(h.befehle, hasLength(1));
      expect(h.befehle.single.ersetztStapel, isFalse);
      expect(h.befehle.single.builder(kontext), isA<GymLogView>());
    });
  });

  group('Lädt (Fehler `01`)', () {
    editorTest('solange gelesen wird, steht kein Grund und keine Null — und '
        'Speichern ist aus', (tester) async {
      final h = await huelleMitEntwurf();
      await oeffneUebersicht(tester, h);
      final tor = halteLesen(h.repo as EditorRepo);

      await tippe(
        tester,
        find.byKey(kGymTrainingsName('ENT-1')),
        warte: false,
        warnIfMissed: false,
      );

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorLaedt), findsOneWidget);
      expect(find.byKey(kGymEditorKopieHinweis), findsNothing);
      expect(
        textVonSchluessel(tester, kGymEditorSpeichernGrund),
        isNot(matches(fehlendGrund)),
        reason: 'Aus nichts Gelesenem folgt kein Grund (Spec 9.6, `01`)',
      );
      expect(ohneWirkung(tester, kGymEditorSpeichern), isTrue);
      expect(
        find.byKey(kGymEditorDauer),
        findsOneWidget,
        reason: 'Die Dauerzeile steht schon da — gleiche Form (Spec 9.3)',
      );
      expect(
        textUnter(tester, kGymEditorDauer),
        isNot(matches(nullAlsWert)),
        reason: 'Keine „0 min" für etwas, das nicht gelesen ist',
      );

      tor.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditorLaedt), findsNothing);
      expect(feldInhalt(tester, kGymEditorName), 'Oberkörper kurz');
    });
  });

  group('Speichern: aus, und der Satz sagt warum (Spec 9.6)', () {
    editorTest('leer: Speichern ist aus, der Satz nennt, was fehlt — und ein '
        'Tipp darauf ändert nichts', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      expect(ohneWirkung(tester, kGymEditorSpeichern), isTrue);
      expect(
        textUnter(tester, kGymEditorSpeichernGrund),
        isNotEmpty,
        reason: '„Speichern geht, sobald mindestens eine Übung drin ist"',
      );
      expect(
        textUnter(tester, kGymEditorSpeichernGrund),
        matches(RegExp('Übung', caseSensitive: false)),
      );

      await tester.tap(find.byKey(kGymEditorSpeichern), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(await eigeneZeilen(h.db), isEmpty);
    });

    editorTest('nur ein Name: Speichern bleibt aus, der Satz nennt die '
        'Übung', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');

      expect(ohneWirkung(tester, kGymEditorSpeichern), isTrue);
      expect(
        textUnter(tester, kGymEditorSpeichernGrund),
        matches(RegExp('Übung', caseSensitive: false)),
      );
    });

    editorTest('nur eine Übung: Speichern bleibt aus, der Satz nennt den '
        'Namen [Vorschlag, Spec 17 Nr. 7]', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await waehleUebung(tester, 'benchPress');

      expect(ohneWirkung(tester, kGymEditorSpeichern), isTrue);
      expect(
        textUnter(tester, kGymEditorSpeichernGrund),
        matches(RegExp('Name', caseSensitive: false)),
      );
    });

    editorTest('Name und Übung: Speichern ist an, der Satz ist leer — und '
        'steht in derselben Form da', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      final leer = tester.getSize(find.byKey(kGymEditorSpeichernGrund));

      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');

      expect(ohneWirkung(tester, kGymEditorSpeichern), isFalse);
      expect(find.byKey(kGymEditorSpeichernGrund), findsOneWidget);
      expect(
        textUnter(tester, kGymEditorSpeichernGrund),
        isEmpty,
        reason: 'Nichts fehlt — der Satz ist leer, die Karte springt nicht',
      );
      expect(
        tester.getSize(find.byKey(kGymEditorSpeichernGrund)),
        leer,
        reason: 'Der Satz steht in jedem Zustand in derselben Größe da (9.6)',
      );
    });

    editorTest('wird die einzige Übung wieder entfernt, ist Speichern wieder '
        'aus', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');
      expect(ohneWirkung(tester, kGymEditorSpeichern), isFalse);

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      await tippe(tester, find.byKey(kGymEditorBlattEntfernen));

      expect(uebungenImBaum(tester), isEmpty);
      expect(ohneWirkung(tester, kGymEditorSpeichern), isTrue);
      expect(textUnter(tester, kGymEditorSpeichernGrund), isNotEmpty);
    });
  });

  group('Abbrechen (Spec 22 Nr. 3, 9.6)', () {
    editorTest('ohne Änderung: schließt, fragt nichts, legt nichts an', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(fragtZurueck(kGymEditorAbbrechenFrage), isFalse);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(await eigeneZeilen(h.db), isEmpty);
    });

    editorTest('mit Änderung: fragt — behalten, verwerfen, weiter bearbeiten', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      expect(find.byKey(kGymEditorAbbrechenFrage), findsOneWidget);
      expect(find.byKey(kGymEditorEntwurfBehalten), findsOneWidget);
      expect(find.byKey(kGymEditorVerwerfen), findsOneWidget);
      expect(find.byKey(kGymEditorWeiter), findsOneWidget);
      expect(find.byKey(kGymEditor), findsOneWidget);
    });

    editorTest('„Weiter bearbeiten": der Editor bleibt, der Stand auch', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');
      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      await tippe(tester, find.byKey(kGymEditorWeiter));

      expect(fragtZurueck(kGymEditorAbbrechenFrage), isFalse);
      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(feldInhalt(tester, kGymEditorName), 'Zuhause kurz');
      expect(uebungenImBaum(tester), ['benchPress']);
    });

    editorTest('„Verwerfen": schließt — und löscht auch, was schon gesichert '
        'war', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(
        await eigeneZeilen(h.db),
        isNotEmpty,
        reason: 'Vorbedingung: Die Selbstsicherung hat geschrieben',
      );

      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorVerwerfen));
      await tester.pump(const Duration(seconds: 3));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(await eigeneZeilen(h.db), isEmpty);
      expect(find.byKey(kGymTrainingsEntwurf(neueKennung)), findsNothing);
    });

    editorTest('„Als Entwurf behalten": schließt, und die Übersicht zeigt die '
        'Entwurfs-Kachel', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorEntwurfBehalten));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(
        find.byKey(kGymTrainingsEntwurf(neueKennung)),
        findsOneWidget,
        reason: 'Der Entwurf steht als Kachel mit der Kapsel da (Spec 7.3)',
      );
      expect(textUnter(tester, kGymTrainingsName(neueKennung)), 'Zuhause kurz');
    });

    editorTest('bearbeite mit Änderung: auch hier gibt es alle drei '
        'Antworten (Spec 22 Nr. 3 hebt 17.14 auf)', (tester) async {
      final h = await huelleMitEigenem();
      await oeffneBearbeiten(tester, h, 'E-1');
      await gebeEin(tester, kGymEditorName, 'Anders');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      expect(find.byKey(kGymEditorAbbrechenFrage), findsOneWidget);
      expect(find.byKey(kGymEditorEntwurfBehalten), findsOneWidget);
      expect(find.byKey(kGymEditorVerwerfen), findsOneWidget);
      expect(find.byKey(kGymEditorWeiter), findsOneWidget);
    });

    editorTest('bearbeite, „Verwerfen": das Detail steht wieder da, das '
        'Training ist unverändert, nichts bleibt gesichert', (tester) async {
      final h = await huelleMitEigenem();
      final vorher = await abbild(h.db, 'E-1');
      await oeffneBearbeiten(tester, h, 'E-1');
      await gebeEin(tester, kGymEditorName, 'Anders');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorVerwerfen));
      await tester.pump(const Duration(seconds: 3));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(await abbild(h.db, 'E-1'), vorher);
      expect(await zwischenstaendeAn(h.db, 'E-1'), 0);
    });

    editorTest('bearbeite, „Als Entwurf behalten": der Zwischenstand liegt da '
        'und ist **keine** eigene Kachel (Spec 27 Nr. 2) — das Training ist '
        'unverändert', (tester) async {
      final h = await huelleMitEigenem();
      final vorher = await abbild(h.db, 'E-1');
      await oeffneBearbeiten(tester, h, 'E-1');
      await gebeEin(tester, kGymEditorName, 'Anders');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorEntwurfBehalten));
      await zurueck(tester, h);

      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(await zwischenstaendeAn(h.db, 'E-1'), 1);
      expect(await abbild(h.db, 'E-1'), vorher);
      expect(
        find.byKey(kGymTrainingsKachel(neueKennung)),
        findsNothing,
        reason:
            'Training und Zwischenstand wären zwei Kacheln für dieselbe Sache '
            '(Spec 27 Nr. 2)',
      );
      expect(find.byKey(kGymTrainingsEntwurf(neueKennung)), findsNothing);
      expect(
        textUnter(tester, kGymTrainingsName('E-1')),
        'Kurzhantel zuhause',
        reason: 'Das Training selbst steht unverändert da',
      );
    });

    editorTest('kopie ohne Änderung: schließt, fragt nichts, legt nichts '
        'an', (tester) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(fragtZurueck(kGymEditorAbbrechenFrage), isFalse);
      expect(await h.repo.alle(), hasLength(3));
    });

    editorTest('entwurf ohne Änderung: schließt, fragt nichts, der Entwurf '
        'bleibt', (tester) async {
      final h = await huelleMitEntwurf();
      await oeffneEntwurfsKachel(tester, h);

      await tippe(tester, find.byKey(kGymEditorAbbrechen));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(fragtZurueck(kGymEditorAbbrechenFrage), isFalse);
      expect(find.byKey(kGymTrainingsEntwurf('ENT-1')), findsOneWidget);
    });
  });

  group('Ein Wert, der dastand, steht wieder da (Fehler `32`)', () {
    editorTest('der Stand übersteht das Öffnen und Schließen von Einstellblatt '
        'und Auswahl', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'lateralRaise');

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      await tippe(tester, find.byKey(kGymEditorBlattFertig));
      expect(find.byKey(kGymEditorBlatt), findsNothing);

      await tippe(tester, find.byKey(kGymEditorHinzufuegen));
      expect(find.byKey(kGymEditorWahl), findsOneWidget);
      // Lazy Liste (#551): erst zur Zeile scrollen, dann tippen.
      await zeigeWahlZeile(tester, 'dips');
      await tippe(tester, find.byKey(kGymEditorWahlUebung('dips')));
      // Antippen oeffnet nur die Vorschau (Nachtrag 29) — erst
      // „Speichern" haengt die Uebung an.
      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(feldInhalt(tester, kGymEditorName), 'Zuhause kurz');
      expect(uebungenImBaum(tester), ['benchPress', 'lateralRaise', 'dips']);
    });

    editorTest('„Als Entwurf behalten", zurück, die Kachel antippen: Name und '
        'Übungen stehen wieder da', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'dips');
      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorEntwurfBehalten));
      expect(find.byKey(kGymEditor), findsNothing);

      await tippe(
        tester,
        find.byKey(kGymTrainingsName(neueKennung)),
        warnIfMissed: false,
      );

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(feldInhalt(tester, kGymEditorName), 'Zuhause kurz');
      expect(uebungenImBaum(tester), ['benchPress', 'dips']);
    });
  });

  group('Übungen: Position, Reihenfolge, Einstellblatt (Spec 9.4)', () {
    Future<TrainingsHuelle> mitDreien(WidgetTester tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'lateralRaise');
      await waehleUebung(tester, 'dips');
      return h;
    }

    /// Die Ziffern der Zeilen, von oben nach unten.
    List<String> ziffern(WidgetTester tester) => [
      for (final uid in uebungenImBaum(tester))
        textUnter(tester, kGymEditorPos(uid)),
    ];

    editorTest('die Position steht als Ziffer in der Zeile, ab 1, in der '
        'Reihenfolge des Trainings', (tester) async {
      await mitDreien(tester);

      expect(uebungenImBaum(tester), ['benchPress', 'lateralRaise', 'dips']);
      expect(ziffern(tester), ['1', '2', '3']);
    });

    editorTest('jede Zeile ist gleich hoch, mindestens 44 pt', (tester) async {
      await mitDreien(tester);

      final hoehen = [
        for (final uid in ['benchPress', 'lateralRaise', 'dips'])
          hoehe(tester, kGymEditorUebung(uid)),
      ];
      expect(hoehen.toSet(), hasLength(1), reason: 'Höhen: $hoehen');
      expect(hoehen.first, greaterThanOrEqualTo(44));
    });

    editorTest('die Dosis steht in der Zeile: „4 × 6–10", bei einer '
        'Zeitübung in Sekunden', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'sidePlank');

      expect(textUnter(tester, kGymEditorDosis('benchPress')), '4 × 6–10');
      expect(
        textUnter(tester, kGymEditorDosis('sidePlank')),
        matches(RegExp(r'3 × 30–45\s*s')),
        reason: 'Zeitübung: Sekunden, nicht Wiederholungen (Spec 9.4)',
      );
    });

    editorTest('↑ im Einstellblatt: die Übung rückt nach oben, alle Ziffern '
        'sind neu; ↓ bringt sie zurück', (tester) async {
      await mitDreien(tester);

      await tippe(tester, find.byKey(kGymEditorUebung('dips')));
      expect(
        textUnter(tester, kGymEditorBlattPosition),
        contains('3 von 3'),
        reason: 'Das Segment zeigt „↑ / 3 von 3 / ↓" (Spec 9.4)',
      );
      await tippe(tester, find.byKey(kGymEditorBlattHoch));
      expect(textUnter(tester, kGymEditorBlattPosition), contains('2 von 3'));
      await tippe(tester, find.byKey(kGymEditorBlattFertig));

      expect(uebungenImBaum(tester), ['benchPress', 'dips', 'lateralRaise']);
      expect(ziffern(tester), ['1', '2', '3']);

      await tippe(tester, find.byKey(kGymEditorUebung('dips')));
      await tippe(tester, find.byKey(kGymEditorBlattRunter));
      await tippe(tester, find.byKey(kGymEditorBlattFertig));

      expect(uebungenImBaum(tester), ['benchPress', 'lateralRaise', 'dips']);
    });

    editorTest('„Aus dem Training entfernen": die Übung ist weg, die '
        'übrigen sind neu nummeriert', (tester) async {
      await mitDreien(tester);

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      await tippe(tester, find.byKey(kGymEditorBlattEntfernen));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(uebungenImBaum(tester), ['lateralRaise', 'dips']);
      expect(ziffern(tester), ['1', '2']);
    });

    editorTest('das Einstellblatt nennt Sätze und Wiederholungen — bei einer '
        'Zeitübung heißt die Zeile „Sekunden"', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'sidePlank');

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      final bankText = textUnter(tester, kGymEditorBlatt);
      expect(bankText, contains('Wiederholungen'));
      expect(bankText, isNot(contains('Sekunden')));
      expect(find.byKey(kGymEditorBlattSaetze), findsOneWidget);
      expect(find.byKey(kGymEditorBlattWdhVon), findsOneWidget);
      expect(find.byKey(kGymEditorBlattWdhBis), findsOneWidget);
      // Seit Nachtrag 29 Nr. 2 steht die Auskunft im Hilfe-Modal statt als
      // Fuss im Blatt — gerechnet bleibt sie (9.4).
      await tippe(tester, find.byKey(kBlattHilfe));
      expect(
        textVonSchluessel(tester, kBlattHilfeModal),
        allOf(contains('4 × 6–10'), contains('2,5')),
        reason: 'Die Katalogwerte sind gerechnet, nicht geschrieben (9.4)',
      );
      await tippe(tester, find.byKey(kBlattHilfeSchliessen));
      await tippe(tester, find.byKey(kGymEditorBlattFertig));

      await tippe(tester, find.byKey(kGymEditorUebung('sidePlank')));
      final plankText = textUnter(tester, kGymEditorBlatt);
      expect(plankText, contains('Sekunden'));
      expect(plankText, isNot(contains('Wiederholungen')));
      await tippe(tester, find.byKey(kBlattHilfe));
      expect(
        textVonSchluessel(tester, kBlattHilfeModal),
        contains('+5 s'),
        reason: 'bei Zeitübung „+5 s" (Spec 9.4)',
      );
      await tippe(tester, find.byKey(kBlattHilfeSchliessen));
    });

    semantikTest('der Griff nennt „Reihenfolge ändern" und bietet „Nach '
        'oben" und „Nach unten" — und beide wirken', (tester) async {
      await mitDreien(tester);

      final texte = semantikTexte(tester, find.byKey(kGymEditorUebung('dips')));
      expect(texte, contains('reihenfolge ändern'));

      Future<void> fuehre(String uid, String stichwort) async {
        final aktionen = semantikAktionen(
          tester,
          find.byKey(kGymEditorUebung(uid)),
        );
        final treffer = aktionen.where(
          (a) => a.aktion.label!.toLowerCase().contains(stichwort),
        );
        expect(
          treffer,
          isNotEmpty,
          reason:
              '„$stichwort" fehlt an $uid: '
              '${aktionen.map((a) => a.aktion.label).toList()}',
        );
        await fuehreAus(tester, treffer.first);
      }

      await fuehre('dips', 'nach oben');
      expect(uebungenImBaum(tester), ['benchPress', 'dips', 'lateralRaise']);
      expect(ziffern(tester), ['1', '2', '3']);

      await fuehre('benchPress', 'nach unten');
      expect(uebungenImBaum(tester), ['dips', 'benchPress', 'lateralRaise']);
      expect(ziffern(tester), ['1', '2', '3']);
    });
  });

  // Seit #551 listet die Auswahl die **Bibliothek** und baut **lazy**
  // (Spec 9.4): Gruppen und Zeilen stehen nicht mehr alle im Baum, die
  // Anker stehen zwischen den Erzeugten. Die Fälle dieser Gruppe sind
  // entsprechend angepasst (Spec 12.4, `TEST_AENDERN=1`, Tims Wort):
  // Mitgliedschaft und Reihenfolge werden über die **Suche** geprüft, die
  // die Gruppen stehen lässt; zu Zeilen wird gescrollt ([zeigeWahlZeile]).
  // Die Zustände der neuen Auswahl stehen in `gym_editor_auswahl_test.dart`;
  // die Sortier- und Gruppenrechnung selbst trägt der Kern
  // (`exercise_library_suche_test.dart`).
  group('Die Auswahl (Spec 9.5)', () {
    Future<TrainingsHuelle> auswahl(WidgetTester tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await tippe(tester, find.byKey(kGymEditorHinzufuegen));
      expect(find.byKey(kGymEditorWahl), findsOneWidget);
      return h;
    }

    double oben(WidgetTester tester, Key key) =>
        tester.getTopLeft(find.byKey(key)).dy;

    /// Die Gruppen im Baum, in der Reihenfolge von oben nach unten.
    List<String> gruppenImBaum(WidgetTester tester) {
      final gefunden = <(double, String)>[];
      for (final m in Muscle.values) {
        final f = find.byKey(kGymEditorWahlGruppe(m.code));
        if (f.evaluate().isEmpty) continue;
        gefunden.add((tester.getTopLeft(f).dy, m.code));
      }
      gefunden.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final (_, code) in gefunden) code];
    }

    /// Ob die Zeile [uid] unter dem Kopf [gruppe] und über dem nächsten Kopf
    /// steht — nur für **gebaute** Köpfe und Zeilen aussagekräftig, also
    /// nach einer Anfrage, deren Treffer auf einen Schirm passen.
    bool inGruppe(WidgetTester tester, String uid, String gruppe) {
      final gruppen = gruppenImBaum(tester);
      final i = gruppen.indexOf(gruppe);
      if (i < 0) return false;
      final y = oben(tester, kGymEditorWahlUebung(uid));
      final von = oben(tester, kGymEditorWahlGruppe(gruppe));
      final bis = i + 1 < gruppen.length
          ? oben(tester, kGymEditorWahlGruppe(gruppen[i + 1]))
          : double.infinity;
      return y > von && y < bis;
    }

    /// Sucht nach dem Namen von [uid] und prüft die Zeile unter dem Kopf
    /// [gruppe] — die Gruppen bleiben in der Suche (Spec 9.1).
    Future<void> pruefeGruppe(
      WidgetTester tester,
      String uid,
      String gruppe,
    ) async {
      await gebeEin(
        tester,
        kGymEditorWahlSuche,
        ExerciseLibrary.byId(uid)!.name,
      );
      await tester.pumpAndSettle();
      await zeigeWahlZeile(tester, uid);
      expect(
        inGruppe(tester, uid, gruppe),
        isTrue,
        reason: '$uid gehört unter den Kopf $gruppe (Spec 9.2)',
      );
    }

    editorTest('gruppiert nach Hauptmuskel, die Gruppen in der Reihenfolge '
        'von `Muscle`', (tester) async {
      await auswahl(tester);

      final gruppen = gruppenImBaum(tester);
      expect(gruppen, isNotEmpty);
      expect(gruppen, [
        for (final m in Muscle.values)
          if (gruppen.contains(m.code)) m.code,
      ], reason: 'Gruppen in der Reihenfolge von `Muscle` (Spec 9.5)');

      await pruefeGruppe(tester, 'benchPress', 'chest');
      await pruefeGruppe(tester, 'lateralRaise', 'sideDelt');
      // Dass der Hauptmuskel gewinnt (Dips: Trizeps 1,0 vor Brust 0,5),
      // rechnet und prüft der Kern (`ExerciseLibrary.byMainMuscle`).
    });

    editorTest('bei Gleichstand gewinnt der Muskel mit dem kleineren '
        '`Muscle.index`', (tester) async {
      await auswahl(tester);

      await pruefeGruppe(tester, 'splitSquat', 'glutes');
      expect(
        inGruppe(tester, 'splitSquat', 'quads'),
        isFalse,
        reason: 'Gesäß (11) vor Quadrizeps (12) bei gleichem Gewicht',
      );
      await pruefeGruppe(tester, 'hammerCurl', 'biceps');
      expect(
        inGruppe(tester, 'hammerCurl', 'forearms'),
        isFalse,
        reason: 'Bizeps (4) vor Unterarmen (6) bei gleichem Gewicht',
      );
    });

    editorTest('die sichtbaren Zeilen stehen in der Reihenfolge der '
        'Bibliothek — Gruppe, dann gefalteter Name', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'curls');
      await tester.pumpAndSettle();

      final erwartet = [for (final u in ExerciseLibrary.search('curls')) u.id];
      final sichtbar = <(double, String)>[];
      for (final uid in erwartet) {
        final f = find.byKey(kGymEditorWahlUebung(uid));
        if (f.evaluate().isEmpty) continue;
        sichtbar.add((oben(tester, kGymEditorWahlUebung(uid)), uid));
      }
      expect(sichtbar, hasLength(greaterThan(1)), reason: 'sonst prüft das nichts');
      final vonObenNachUnten = [...sichtbar]
        ..sort((a, b) => a.$1.compareTo(b.$1));
      expect(
        [for (final (_, uid) in vonObenNachUnten) uid],
        [for (final (_, uid) in sichtbar) uid],
        reason:
            'Die Anzeige folgt `ExerciseLibrary.search` — alphabetisch nach '
            'dem **gefalteten** Namen („Überzüge" nicht hinter „Z", '
            'Spec 9.2); die Rechnung selbst prüft der Kern',
      );
    });

    editorTest('jede Zeile nennt den Standardumfang — bei einer Zeitübung in '
        'Sekunden', (tester) async {
      await auswahl(tester);

      await gebeEin(
        tester,
        kGymEditorWahlSuche,
        ExerciseLibrary.byId('benchPress')!.name,
      );
      await tester.pumpAndSettle();
      await zeigeWahlZeile(tester, 'benchPress');
      expect(
        textUnter(tester, kGymEditorWahlUebung('benchPress')),
        contains('4 × 6–10'),
      );

      await gebeEin(
        tester,
        kGymEditorWahlSuche,
        ExerciseLibrary.byId('sidePlank')!.name,
      );
      await tester.pumpAndSettle();
      await zeigeWahlZeile(tester, 'sidePlank');
      expect(
        textUnter(tester, kGymEditorWahlUebung('sidePlank')),
        matches(RegExp(r'3 × 30–45\s*s')),
        reason: 'Zeitübung: „3 × 30–45 s" (Spec 9.5)',
      );
    });

    editorTest('die Suche: Teilzeichenfolge im Namen, ohne Beachtung der '
        'Schreibweise', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'BANK');
      await tester.pumpAndSettle();

      final treffer = [for (final u in ExerciseLibrary.search('bank')) u.id];
      final erwartet = [
        'benchPress',
        'inclineDumbbellPress',
        'closeGripBench',
        'inclineCurl',
      ]..sort((a, b) => treffer.indexOf(a).compareTo(treffer.indexOf(b)));
      for (final uid in erwartet) {
        await zeigeWahlZeile(tester, uid);
        expect(
          find.byKey(kGymEditorWahlUebung(uid)),
          findsOneWidget,
          reason: uid,
        );
      }
      for (final uid in ['lateralRaise', 'dips', 'legPress']) {
        expect(
          find.byKey(kGymEditorWahlUebung(uid), skipOffstage: false),
          findsNothing,
          reason: '$uid: kein Treffer wird nie gebaut',
        );
      }
      expect(find.byKey(kGymEditorWahlLeer), findsNothing);
    });

    editorTest('ohne Treffer sagt ein Satz es — und die Liste ist wieder da, '
        'sobald die Suche leer ist', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'zzz');
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditorWahlLeer), findsOneWidget);
      expect(textUnter(tester, kGymEditorWahlLeer), isNotEmpty);
      expect(
        find.byKey(kGymEditorWahlUebung('benchPress'), skipOffstage: false),
        findsNothing,
      );

      await gebeEin(tester, kGymEditorWahlSuche, '');
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditorWahlLeer), findsNothing);
      expect(
        find.byKey(kGymEditorWahlGruppe(Muscle.chest.code)),
        findsOneWidget,
        reason: 'die volle Liste ist wieder da (Tabelle 9.8)',
      );
      await zeigeWahlZeile(tester, 'benchPress');
      expect(find.byKey(kGymEditorWahlUebung('benchPress')), findsOneWidget);
    });

    editorTest('der Fuß nennt die gezählte Zahl der Übungen — '
        '`ExerciseLibrary.length`, nicht 33, ohne „mit Bild" '
        '(Spec 9.5, 10, 12)', (tester) async {
      await auswahl(tester);

      // Eine enge Anfrage macht die Liste kurz; der Fuß steht an ihrem
      // Ende (Spec 9.1) und nennt trotzdem die Gesamtzahl des Katalogs.
      await gebeEin(
        tester,
        kGymEditorWahlSuche,
        ExerciseLibrary.byId('sidePlank')!.name,
      );
      await tester.pumpAndSettle();

      final fuss = textUnter(tester, kGymEditorWahlFuss);
      expect(fuss, gymEditorWahlFuss(ExerciseLibrary.length));
      expect(fuss, isNot(contains('33 ')));
      expect(fuss, isNot(contains('mit Bild')));
    });

    editorTest('eine Übung antippen öffnet die Vorschau; erst „Speichern" '
        'hängt sie ans Ende (Nachtrag 29 Nr. 1)', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'lateralRaise');

      await tippeInAuswahl(tester, 'benchPress');

      expect(
        find.byKey(kGymEditorBlatt),
        findsOneWidget,
        reason: 'Antippen öffnet das Blatt dieser Übung — als Vorschau',
      );
      expect(
        editorStand(
          h,
          const GymEditorQuelle.neu(),
        ).uebungen.map((e) => e.exerciseId),
        ['lateralRaise'],
        reason:
            'Antippen fügt nichts hinzu (Nachtrag 29 Nr. 1 kippt Spec 28 '
            'Nr. 1) — die Vorschau zeigt sie nur',
      );
      expect(textUnter(tester, kGymEditorBlatt), contains('Bankdrücken'));
      expect(find.byKey(kGymEditorBlattSaetze), findsOneWidget);

      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(
        editorStand(
          h,
          const GymEditorQuelle.neu(),
        ).uebungen.map((e) => e.exerciseId),
        ['lateralRaise', 'benchPress'],
        reason: '„Speichern" hängt sie **am Ende** an',
      );
    });

    editorTest('„Speichern" im Blatt kehrt zur Auswahl zurück, nicht zur '
        'Übungsliste — die Übung ist jetzt drin (Nachtrag 29 Nr. 1)', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await tippeInAuswahl(tester, 'benchPress');

      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(
        find.byKey(kGymEditorWahl),
        findsOneWidget,
        reason:
            'Die Auswahl liegt weiter darunter — die nächste Übung ist '
            'direkt wählbar',
      );
      expect(
        find.byKey(kGymEditorWahlSchonDrin('benchPress')),
        findsOneWidget,
        reason:
            'die eben gespeicherte Übung steht jetzt als „schon im '
            'Training" da',
      );
      expect(
        editorStand(h, const GymEditorQuelle.neu()).uebungen,
        hasLength(1),
      );
    });

    editorTest('„Zurück" in der Vorschau verwirft: nichts ist drin, die '
        'Auswahl steht da, die Übung ist weiter wählbar '
        '(Nachtrag 29 Nr. 1)', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await tippeInAuswahl(tester, 'benchPress');

      await tippe(tester, find.byKey(kBlattZurueck));

      expect(find.byKey(kGymEditorBlatt), findsNothing);
      expect(
        find.byKey(kGymEditorWahl),
        findsOneWidget,
        reason: 'zurück in der Auswahl, nicht in der Übungsliste',
      );
      expect(
        editorStand(h, const GymEditorQuelle.neu()).uebungen,
        isEmpty,
        reason: 'verworfen — hinzugefügt war ohnehin nichts',
      );
      expect(find.byKey(kGymEditorWahlSchonDrin('benchPress')), findsNothing);
      expect(
        deckkraft(tester, find.byKey(kGymEditorWahlUebung('benchPress'))),
        1,
        reason: 'nicht abgeblendet',
      );

      await tippe(tester, find.byKey(kGymEditorWahlUebung('benchPress')));
      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(
        editorStand(h, const GymEditorQuelle.neu()).uebungen,
        hasLength(1),
        reason: 'wieder wählbar, und nur einmal drin',
      );
    });

    editorTest('zwei Übungen nacheinander, ohne die Auswahl zu verlassen: '
        'beide im Stand, die Reihenfolge stimmt (Nachtrag 29 Nr. 1)', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      // Erst die nahe Zeile, dann die ferne: Die Liste ist lazy (#551),
      // und [zeigeWahlZeile] scrollt vorwärts zur zweiten Übung.
      await tippeInAuswahl(tester, 'benchPress');
      await tippe(tester, find.byKey(kBlattSpeichern));
      await zeigeWahlZeile(tester, 'lateralRaise');
      await tippeInAuswahl(tester, 'lateralRaise');
      expect(
        textUnter(tester, kGymEditorBlatt),
        contains('Seitheben'),
        reason: 'die zweite Übung öffnet ihre eigene Vorschau',
      );
      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(find.byKey(kGymEditorWahl), findsOneWidget);
      expect(
        editorStand(
          h,
          const GymEditorQuelle.neu(),
        ).uebungen.map((e) => e.exerciseId),
        ['benchPress', 'lateralRaise'],
      );

      await tippe(tester, find.byKey(kGymEditorWahlZurueck));

      expect(find.byKey(kGymEditorWahl), findsNothing);
      expect(uebungenImBaum(tester), ['benchPress', 'lateralRaise']);
      expect(textUnter(tester, kGymEditorDosis('benchPress')), '4 × 6–10');
    });

    editorTest('„schon im Training": abgeblendet, nicht antippbar — und es '
        'wird nicht doppelt eingefügt', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');

      await tippe(tester, find.byKey(kGymEditorHinzufuegen));

      expect(find.byKey(kGymEditorWahlSchonDrin('benchPress')), findsOneWidget);
      expect(find.byKey(kGymEditorWahlSchonDrin('dips')), findsNothing);
      expect(
        deckkraft(tester, find.byKey(kGymEditorWahlUebung('benchPress'))),
        lessThan(1),
        reason: 'abgeblendet (Spec 9.4)',
      );

      await tester.tap(
        find.byKey(kGymEditorWahlUebung('benchPress')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        editorStand(h, const GymEditorQuelle.neu()).uebungen,
        hasLength(1),
        reason: 'Eine Übung bleibt einmal im Training (Spec 4.1)',
      );
    });
  });

  group('Das Einstellblatt zeigt unten das Übungsbild (Spec 28 Nr. 2)', () {
    /// benchPress: zwei Bilder, sidePlank: eines. **lateralRaise und dips
    /// haben keines** — der Test bestimmt es, nicht das Asset.
    final bilder = editorBilder(zwei: ['benchPress'], einzel: ['sidePlank']);

    /// Die Animation **im** Blatt — nicht irgendwo im Baum.
    Finder animationImBlatt() => find.descendant(
      of: find.byKey(kGymEditorBlatt),
      matching: find.byType(UebungsbildAnimation),
    );

    editorTest('frisch hinzugefügt, mit Bild: dieselbe Animation wie in der '
        'Erfassung steht im Blatt, samt Pflichtangabe', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'benchPress');

      expect(animationImBlatt(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kGymEditorBlatt),
          matching: find.byKey(kGymBild('benchPress')),
        ),
        findsOneWidget,
        reason: 'derselbe Baustein wie in der Erfassung (`GymBewegungsbild`)',
      );
      expect(
        find.byKey(kGymBildFrame('benchPress', 1)),
        findsOneWidget,
        reason: 'die quadratische Fläche der Animation',
      );
      expect(
        tester.widget<Text>(find.byKey(kGymBildAttribution('benchPress'))).data,
        repdbAttribution,
        reason: 'Wo ein RepDB-Bild steht, steht die Pflichtangabe darunter',
      );
    });

    editorTest('im Zeilen-Weg steht „Entfernen" ganz unten — unter dem '
        'Bild (Nachtrag 29 Nr. 3)', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));

      expect(
        tester.getTopLeft(find.byKey(kGymEditorBlattEntfernen)).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(kGymBild('benchPress'))).dy,
        ),
        reason:
            'Tim, 23.11.2026: „Aus dem Training entfernen" rückt ganz ans '
            'Ende, unter das Bewegungsbild — vorher stand das Bild darunter',
      );
    });

    editorTest('in der Vorschau steht das Bild unten und kein Entfernen '
        '(Nachtrag 29 Nr. 1)', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'benchPress');

      expect(find.byKey(kGymBild('benchPress')), findsOneWidget);
      expect(find.byKey(kGymEditorBlattEntfernen), findsNothing);
    });

    editorTest('frisch hinzugefügt, ohne Bild: dort steht nichts — kein '
        'Platzhalter', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'lateralRaise');

      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      expect(animationImBlatt(), findsNothing);
      expect(find.byKey(kGymBild('lateralRaise')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(kGymEditorBlatt),
          matching: find.byType(Image),
        ),
        findsNothing,
        reason:
            'weder Bild noch graue Fläche (Spec 28 Nr. 2: zwei '
            'verschiedene Übungen, kein Zustandswechsel)',
      );
      expect(find.byKey(kGymBildAttribution('lateralRaise')), findsNothing);
    });

    editorTest('ohne jedes Bild im Provider: kein Bild und kein Fehler', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'benchPress');

      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      expect(animationImBlatt(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    editorTest('eine Übung mit nur einem Bild (Halteübung): das Bild steht '
        'da, ohne zweite Lage', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'sidePlank');

      expect(animationImBlatt(), findsOneWidget);
      expect(find.byKey(kGymBildFrame('sidePlank', 1)), findsOneWidget);
      expect(find.byKey(kGymBildFrame('sidePlank', 2)), findsNothing);
    });

    editorTest('der zweite Weg ins Blatt, über die bestehende Zeile: mit '
        'Bild steht es da, ohne nicht — und das Blatt der anderen Übung '
        'trägt das Bild nicht mit', (tester) async {
      final h = editorHuelle(bilder: bilder);
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'lateralRaise');
      expect(find.byKey(kGymEditorBlatt), findsNothing);

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      expect(animationImBlatt(), findsOneWidget);
      expect(find.byKey(kGymBild('benchPress')), findsOneWidget);
      await tippe(tester, find.byKey(kGymEditorBlattFertig));

      await tippe(tester, find.byKey(kGymEditorUebung('lateralRaise')));
      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      expect(animationImBlatt(), findsNothing);
      expect(find.byKey(kGymBild('benchPress')), findsNothing);
      expect(find.byKey(kGymBild('lateralRaise')), findsNothing);
    });
  });

  group('Die Muskelfigur im Editor (Spec 28 Nr. 3, #554)', () {
    Finder figurFinder() => find.descendant(
      of: find.byKey(kGymEditorFigur),
      matching: find.byType(MuskelFigur),
    );

    MuskelFigur figur(WidgetTester tester) =>
        tester.widget<MuskelFigur>(figurFinder());

    Set<Muscle> gefaerbt(WidgetTester tester) =>
        figur(tester).gefaerbt.keys.toSet();

    Set<Muscle> trainiert(List<String> uids) =>
        WorkoutMuscles.trained([for (final uid in uids) ausKatalog(uid)]);

    /// Größe **und** Lage der Figur — beides ändert sich nie.
    ({Size groesse, double oben}) mass(WidgetTester tester) => (
      groesse: tester.getSize(find.byKey(kGymEditorFigur)),
      oben: tester.getTopLeft(find.byKey(kGymEditorFigur)).dy,
    );

    editorTest('steht zwischen Stamm und Übungsliste, in jedem Zustand', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      void pruefe(String zustand) {
        expect(figurFinder(), findsOneWidget, reason: zustand);
        final oben = tester.getTopLeft(find.byKey(kGymEditorFigur)).dy;
        final unten = tester.getBottomLeft(find.byKey(kGymEditorFigur)).dy;
        expect(
          oben,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.byKey(kGymEditorDauer)).dy,
          ),
          reason:
              '$zustand: unter der Stamm-Karte (die Dauerzeile ist ihre '
              'letzte)',
        );
        expect(
          unten,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(kGymEditorUebungen)).dy,
          ),
          reason: '$zustand: über der Übungsliste',
        );
      }

      pruefe('leer');
      await waehleUebung(tester, 'benchPress');
      pruefe('mit Übung');
    });

    editorTest('beide Seiten nebeneinander, wie das Detail', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      expect(figur(tester).seite, isNull);
      for (final seite in MuskelSeite.values) {
        expect(
          find.descendant(
            of: find.byKey(kGymEditorFigur),
            matching: find.byKey(kMuskelFigurSeite(seite)),
          ),
          findsOneWidget,
          reason: '$seite',
        );
      }
    });

    editorTest('leer färbt sie nichts — und steht trotzdem da', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      expect(gefaerbt(tester), isEmpty);
      expect(
        trainiert(const []),
        isEmpty,
        reason: 'Voraussetzung: ein leeres Training trainiert nichts',
      );
    });

    editorTest('nach „Bankdrücken" färbt sie genau `WorkoutMuscles.trained` '
        'der Liste, einfarbig; jede weitere Übung und jedes Entfernen '
        'rechnen neu', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await waehleUebung(tester, 'benchPress');
      expect(gefaerbt(tester), trainiert(['benchPress']));
      expect(
        gefaerbt(tester),
        containsAll([Muscle.chest, Muscle.frontDelt, Muscle.triceps]),
      );
      expect(
        figur(tester).gefaerbt.values.toSet(),
        hasLength(1),
        reason:
            'einfarbig — „trifft diese Muskeln", nicht „wie viel" '
            '(Spec 8.1)',
      );

      await waehleUebung(tester, 'lateralRaise');
      expect(gefaerbt(tester), trainiert(['benchPress', 'lateralRaise']));
      expect(gefaerbt(tester), contains(Muscle.sideDelt));

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      await tippe(tester, find.byKey(kGymEditorBlattEntfernen));
      expect(gefaerbt(tester), trainiert(['lateralRaise']));
      expect(gefaerbt(tester), isNot(contains(Muscle.chest)));
    });

    editorTest('wird die einzige Übung wieder entfernt, ist sie wieder '
        'leer', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      expect(gefaerbt(tester), isNotEmpty);

      await tippe(tester, find.byKey(kGymEditorUebung('benchPress')));
      await tippe(tester, find.byKey(kGymEditorBlattEntfernen));

      expect(gefaerbt(tester), isEmpty);
      expect(figurFinder(), findsOneWidget);
    });

    editorTest('die Figur folgt dem Stand auch, während die Auswahl noch '
        'offen ist — gefärbt wird erst mit „Speichern" '
        '(Nachtrag 29 Nr. 1)', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      await tippeInAuswahl(tester, 'benchPress');
      expect(
        gefaerbt(tester),
        isEmpty,
        reason: 'die Vorschau hat nichts hinzugefügt — nichts zu färben',
      );

      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(gefaerbt(tester), trainiert(['benchPress']));
    });

    editorTest('ein bestehendes Training: gefärbt, sobald es gelesen ist', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      expect(gefaerbt(tester), WorkoutMuscles.trained(push.exercises));
    });

    editorTest('die Maße ändern sich nie: leer, gefüllt, mit mehr Übungen, '
        'beim Tippen im Namensfeld (eine Form)', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      final leer = mass(tester);

      await gebeEin(
        tester,
        kGymEditorName,
        'Ein sehr langer Name, der in keine Zeile passt und deshalb '
        'umbrechen müsste, wenn das Feld es zuließe',
      );
      expect(mass(tester), leer, reason: 'beim Tippen im Namensfeld');

      await waehleUebung(tester, 'benchPress');
      expect(mass(tester), leer, reason: 'mit einer Übung');

      await waehleUebung(tester, 'barbellRow');
      await waehleUebung(tester, 'dips');
      expect(mass(tester), leer, reason: 'mit drei Übungen');
      expect(leer.groesse.height, greaterThan(0));
    });

    editorTest('beim Laden steht dieselbe Figur da — ungefärbt, ohne '
        'Muskeln im Vorlesetext, in denselben Maßen wie danach', (
      tester,
    ) async {
      final h = await huelleMitEntwurf();
      await oeffneUebersicht(tester, h);
      final tor = halteLesen(h.repo as EditorRepo);
      await tippe(
        tester,
        find.byKey(kGymTrainingsName('ENT-1')),
        warte: false,
        warnIfMissed: false,
      );
      expect(find.byKey(kGymEditorLaedt), findsOneWidget);

      expect(figurFinder(), findsOneWidget);
      expect(
        gefaerbt(tester),
        isEmpty,
        reason:
            'Aus nichts Gelesenem wird '
            'nichts gefärbt (Fehler `01`)',
      );
      final vorher = mass(tester);

      tor.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditorLaedt), findsNothing);
      expect(mass(tester), vorher, reason: 'Laden → gelesen springt nicht');
    });

    editorTest('die Figur eines neuen Editors und die eines bestehenden '
        'Trainings haben dieselben Maße', (tester) async {
      final neu = editorHuelle();
      await oeffneNeuenEditor(tester, neu);
      final fuerNeu = mass(tester).groesse;

      await tester.pumpWidget(const SizedBox.shrink());
      final bestehend = editorHuelle();
      await oeffneBearbeiten(tester, bestehend, 'Push');

      // Nur die Größe: „Bearbeiten" an einem Template ist eine Kopie, und der
      // Kopie-Hinweis schiebt die Figur tiefer — die Lage unterscheidet sich
      // dort zwangsläufig, ohne dass die Figur ihre Form ändert.
      expect(mass(tester).groesse, fuerNeu);
    });

    semantikTest('der Vorlesetext nennt den Zustand: leer sagt es und nennt '
        'keinen Muskel, mit Bankdrücken nennt er die Brust', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      final leer = semantikTexte(tester, find.byKey(kGymEditorFigur));
      expect(leer, isNot(contains('brust')));
      expect(leer, isNot(contains('trizeps')));
      expect(leer, isNot(contains('strich')));
      expect(leer.trim(), isNotEmpty, reason: 'die Figur wird vorgelesen');

      await waehleUebung(tester, 'benchPress');

      final voll = semantikTexte(tester, find.byKey(kGymEditorFigur));
      expect(voll, contains('brust'));
      expect(voll, isNot(equals(leer)));
    });
  });

  group('Die Kopie eines Templates (Spec 4.5, 9.1)', () {
    editorTest('der Hinweis nennt das Template, der Name ist vorbelegt, '
        'nichts ist angelegt', (tester) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      expect(
        textUnter(tester, kGymEditorKopieHinweis),
        contains('Push — Brust, Schultern, Trizeps'),
      );
      expect(feldInhalt(tester, kGymEditorName), 'Push (Kopie)');
      expect(uebungenImBaum(tester), [
        for (final u in push.exercises) u.exerciseId,
      ]);
      expect(await h.repo.alle(), hasLength(3));
    });

    editorTest('Speichern: die Übersicht steht da, das neue Eigene ist sofort '
        'in ihr, das Template ist unverändert', (tester) async {
      final h = editorHuelle();
      final vorher = await abbild(h.db, 'Push');
      await oeffneBearbeiten(tester, h, 'Push');
      await gebeEin(tester, kGymEditorName, 'Push — meine Fassung');

      await tippe(tester, find.byKey(kGymEditorSpeichern));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(
        find.byKey(kGymTrainingDetail),
        findsNothing,
        reason:
            'Neu und Kopie führen in die Übersicht, nicht ins Detail (17.13)',
      );
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel(neueKennung)), findsOneWidget);
      expect(
        textUnter(tester, kGymTrainingsName(neueKennung)),
        'Push — meine Fassung',
      );
      expect(find.byKey(kGymTrainingsEntwurf(neueKennung)), findsNothing);
      expect(await abbild(h.db, 'Push'), vorher);
      expect(
        textUnter(tester, kGymTrainingsName('Push')),
        isNot(contains('Kopie')),
      );
    });

    editorTest('Abbrechen und Verwerfen: nichts ist entstanden, das Template '
        'bleibt', (tester) async {
      final h = editorHuelle();
      final vorher = await abbild(h.db, 'Push');
      await oeffneBearbeiten(tester, h, 'Push');
      await gebeEin(tester, kGymEditorName, 'Push — meine Fassung');

      await tippe(tester, find.byKey(kGymEditorAbbrechen));
      await tippe(tester, find.byKey(kGymEditorVerwerfen));
      await tester.pump(const Duration(seconds: 3));

      expect(await eigeneZeilen(h.db), isEmpty);
      expect(await abbild(h.db, 'Push'), vorher);
    });
  });

  group('Wohin nach dem Speichern (Spec 9.6, 17 Nr. 13)', () {
    editorTest('neu: die Übersicht, und das Training ist sofort da', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await gebeEin(tester, kGymEditorName, 'Zuhause kurz');
      await waehleUebung(tester, 'benchPress');

      await tippe(tester, find.byKey(kGymEditorSpeichern));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel(neueKennung)), findsOneWidget);
      expect(textUnter(tester, kGymTrainingsName(neueKennung)), 'Zuhause kurz');
      expect(find.byKey(kGymTrainingsEntwurf(neueKennung)), findsNothing);
      expect(
        h.repo.alleAufrufe,
        greaterThan(1),
        reason: 'Der Schreiber sagt es, die Übersicht liest neu (Spec 6.3)',
      );
    });

    editorTest('bearbeite: das Detail — mit dem neuen Namen', (tester) async {
      final h = await huelleMitEigenem();
      await oeffneBearbeiten(tester, h, 'E-1');
      await gebeEin(tester, kGymEditorName, 'Kurzhantel neu');

      await tippe(tester, find.byKey(kGymEditorSpeichern));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(alleTexteDes(tester), contains('Kurzhantel neu'));
      expect(await zwischenstaendeAn(h.db, 'E-1'), 0);
    });

    editorTest('entwurf: die Übersicht, der Entwurf ist ein fertiges Eigenes '
        'ohne Kapsel', (tester) async {
      final h = await huelleMitEntwurf();
      await oeffneEntwurfsKachel(tester, h);

      await tippe(tester, find.byKey(kGymEditorSpeichern));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel('ENT-1')), findsOneWidget);
      expect(
        find.byKey(kGymTrainingsEntwurf('ENT-1')),
        findsNothing,
        reason: 'Ein geöffneter Entwurf verliert dabei die Kapsel (9.6)',
      );
    });
  });

  group('Löschen und die Sperre (Spec 4.7, 9.6)', () {
    editorTest('Löschen fragt zurück; danach sind Editor und Detail zu und '
        'die Übersicht steht ohne das Training da', (tester) async {
      final h = await huelleMitEigenem();
      await oeffneBearbeiten(tester, h, 'E-1');

      await tippe(tester, find.byKey(kGymEditorLoeschen));
      expect(find.byKey(kGymEditorLoeschenFrage), findsOneWidget);
      expect(
        await h.repo.training('E-1'),
        isNotNull,
        reason: 'Gelöscht wird erst nach der Antwort',
      );
      await tippe(tester, find.byKey(kGymEditorLoeschenBestaetigen));

      expect(find.byKey(kGymEditor), findsNothing);
      expect(find.byKey(kGymTrainingDetail), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsNothing);
      expect(await h.repo.training('E-1'), isNull);
    });

    editorTest('Speichern, solange das Training läuft: abgelehnt, mit Satz — '
        'der eingetippte Stand bleibt', (tester) async {
      final h = await huelleMitEigenem();
      await laufendesTraining(h.db, 'E-1');
      await oeffneBearbeiten(tester, h, 'E-1');
      await gebeEin(tester, kGymEditorName, 'Gesperrt');
      expect(find.byKey(kGymEditorGesperrt), findsNothing);

      await tippe(tester, find.byKey(kGymEditorSpeichern));

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorGesperrt), findsOneWidget);
      expect(
        textUnter(tester, kGymEditorGesperrt),
        matches(RegExp('läuft|abschließen|verwerfen', caseSensitive: false)),
      );
      expect(feldInhalt(tester, kGymEditorName), 'Gesperrt');
      expect((await h.repo.training('E-1'))!.name, 'Kurzhantel zuhause');
    });

    editorTest('Löschen, solange das Training läuft: abgelehnt, mit Satz — '
        'Editor und Training bleiben', (tester) async {
      final h = await huelleMitEigenem();
      await laufendesTraining(h.db, 'E-1');
      await oeffneBearbeiten(tester, h, 'E-1');

      await tippe(tester, find.byKey(kGymEditorLoeschen));
      await tippe(tester, find.byKey(kGymEditorLoeschenBestaetigen));

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorGesperrt), findsOneWidget);
      expect(await h.repo.training('E-1'), isNotNull);
    });
  });

  group('Die Dauer (Spec 9.3, Tim 19.11.2026)', () {
    editorTest('ohne Übung steht „geschätzt – min" da — kein „0 min"; mit '
        'Übung die Schätzung', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      final leer = textUnter(tester, kGymEditorDauer);
      expect(leer, contains('geschätzt'));
      expect(leer, contains('–'));
      expect(leer, isNot(matches(nullAlsWert)));
      expect(sichtbar(tester, kGymEditorDauerZuruecksetzen), isFalse);

      await waehleUebung(tester, 'benchPress');

      final gefuellt = textUnter(tester, kGymEditorDauer);
      expect(gefuellt, contains('geschätzt'));
      expect(gefuellt, contains('10'));
      expect(gefuellt, isNot(contains('–')));
    });

    editorTest('eingetragen: „eingetragen 70 min" mit „zurück zur '
        'Schätzung" — und der Knopf bringt die Schätzung zurück', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      final eingetragen = textUnter(tester, kGymEditorDauer);
      expect(eingetragen, contains('eingetragen'));
      expect(eingetragen, contains('70'));
      expect(sichtbar(tester, kGymEditorDauerZuruecksetzen), isTrue);

      await tippe(tester, find.byKey(kGymEditorDauerZuruecksetzen));

      final geschaetzt = textUnter(tester, kGymEditorDauer);
      expect(geschaetzt, contains('geschätzt'));
      expect(geschaetzt, contains('55'));
      expect(sichtbar(tester, kGymEditorDauerZuruecksetzen), isFalse);
    });

    editorTest('eine eingetragene Dauer bleibt, wenn sich die Übungen '
        'ändern; die Schätzung rechnet daneben weiter', (tester) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      await tippe(tester, find.byKey(kGymEditorUebung('overheadTriceps')));
      await tippe(tester, find.byKey(kGymEditorBlattEntfernen));

      expect(textUnter(tester, kGymEditorDauer), contains('eingetragen'));
      expect(textUnter(tester, kGymEditorDauer), contains('70'));
      expect(
        editorStand(h, const GymEditorQuelle.kopie('Push')).dauerEingetragen,
        70,
      );
    });
  });

  group('Tags (Spec 9.3)', () {
    editorTest('ein benutzter Tag wird vorgeschlagen; antippen setzt ihn, und '
        'der Vorschlag verschwindet', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      expect(find.byKey(kGymEditorTagVorschlag('Gym')), findsOneWidget);
      expect(find.byKey(kGymEditorTag('Gym')), findsNothing);

      await tippe(tester, find.byKey(kGymEditorTagVorschlag('Gym')));

      expect(find.byKey(kGymEditorTag('Gym')), findsOneWidget);
      expect(textUnter(tester, kGymEditorTag('Gym')), contains('Gym'));
      expect(find.byKey(kGymEditorTagVorschlag('Gym')), findsNothing);
      expect(editorStand(h, const GymEditorQuelle.neu()).tags, [
        'Gym',
      ], reason: 'Der Tag steht im Stand, wie die Ablage ihn kennt');
    });

    editorTest('in der Kopie steht der Tag des Templates schon da — ohne '
        'Vorschlag', (tester) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      expect(find.byKey(kGymEditorTag('Gym')), findsOneWidget);
      expect(find.byKey(kGymEditorTagVorschlag('Gym')), findsNothing);
    });
  });

  group('Vorlesetexte nennen den Zustand, nicht das Zeichen (Spec 9.7)', () {
    semantikTest('die Übungszeile: Position, Name, Sätze, Wiederholungen — '
        'bei einer Zeitübung Sekunden', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);
      await waehleUebung(tester, 'benchPress');
      await waehleUebung(tester, 'sidePlank');

      final bank = semantikTexte(
        tester,
        find.byKey(kGymEditorUebung('benchPress')),
      );
      expect(bank, contains('übung 1 von 2'));
      expect(bank, contains('bankdrücken langhantel'));
      expect(bank, contains('4 sätze'));
      expect(bank, contains('6 bis 10 wiederholungen'));

      final plank = semantikTexte(
        tester,
        find.byKey(kGymEditorUebung('sidePlank')),
      );
      expect(plank, contains('übung 2 von 2'));
      expect(plank, contains('30 bis 45 sekunden'));
    });

    semantikTest('die Dauerzeile sagt „noch nicht geschätzt", „geschätzt …" '
        'oder „eingetragen …" — nie „Strich"', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      final leer = semantikTexte(tester, find.byKey(kGymEditorDauer));
      expect(leer, contains('noch nicht geschätzt'));
      expect(leer, isNot(contains('strich')));

      await waehleUebung(tester, 'benchPress');
      final geschaetzt = semantikTexte(tester, find.byKey(kGymEditorDauer));
      expect(geschaetzt, contains('geschätzt 10 minuten'));
      expect(geschaetzt, isNot(contains('strich')));
    });

    semantikTest('eine eingetragene Dauer wird als „eingetragen" gelesen', (
      tester,
    ) async {
      final h = editorHuelle();
      await oeffneBearbeiten(tester, h, 'Push');

      final texte = semantikTexte(tester, find.byKey(kGymEditorDauer));

      expect(texte, contains('eingetragen 70 minuten'));
    });

    semantikTest('Speichern, solange es nicht geht: „nicht möglich" und der '
        'Grund', (tester) async {
      final h = editorHuelle();
      await oeffneNeuenEditor(tester, h);

      final texte = semantikTexte(tester, find.byKey(kGymEditorSpeichern));

      expect(texte, contains('speichern'));
      expect(texte, contains('nicht möglich'));
    });
  });
}
