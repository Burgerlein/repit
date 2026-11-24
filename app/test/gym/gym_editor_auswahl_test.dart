import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_editor_provider.dart';
import 'package:repit/gym/gym_editor_texte.dart';
import 'package:repit/gym/uebungsbilder.dart';

import 'gym_editor_support.dart';

/// Die Auswahl (`uebung-waehlen`) über der **Bibliothek** (#551, Spec 9,
/// Tabelle 9.8; Plan Task 3.4) — **nur Zustände und Übergänge**, kein Layout
/// und keine Beschriftung über das in der Spec Genannte hinaus.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// ## Festlegungen des Test-Agenten — Tim hat sie nicht gesehen
///
/// - **[kGymEditorWahlBild]** (`gym-editor-wahl-bild-<id>`): der Schlüssel am
///   Abspiel-Icon einer Zeile — **nur im Baum, wenn das Icon steht**
///   (Spec 9.9 nennt den Namen, die Zeichenkette legt dieser Test fest; die
///   Implementierung führt denselben Schlüssel in
///   `gym_training_editor_schluessel.dart`).
/// - Das Icon ist `CupertinoIcons.play_circle` (Spec 9.6, Vorschlag,
///   Entscheidung 12) — der eine Fall, in dem ein Test das Zeichen kennt,
///   denn „es steht nirgends" lässt sich nur über das Zeichen prüfen.
/// - Der Vorlesetext einer Zeile mit Icon enthält „mit Bewegungsbild", ohne
///   Icon nicht (Spec 9.6: der Zustand, nicht das Zeichen).
///
/// Tests **scrollen zur Zeile** (`scrollUntilVisible`), statt sie im Baum
/// vorauszusetzen (Spec 9.9): Die Liste ist lazy. Alle Daten sind erfunden.

/// Der Schlüssel am Abspiel-Icon — Festlegung, siehe Kopf. Heißt hier
/// bewusst anders als `kGymEditorWahlBild`, das die Implementierung in
/// `gym_training_editor_schluessel.dart` anlegt: Derselbe Dart-Name an
/// beiden Stellen wäre nach dem Bau ein Namenskonflikt, den der
/// Implementierende nicht auflösen darf (er ändert keine Testdatei).
/// **Die Zeichenkette ist der Vertrag.**
Key wahlBildSchluessel(String id) => Key('gym-editor-wahl-bild-$id');

/// Die vertikale Liste der Auswahl — nicht das Suchfeld (dessen
/// `EditableText` scrollt waagerecht).
Finder wahlListe() => find
    .descendant(
      of: find.byKey(kGymEditorWahl),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ),
    )
    .first;

/// Scrollt die Auswahl, bis die Zeile [uid] gebaut und sichtbar ist.
Future<void> zeigeZeile(WidgetTester tester, String uid) async {
  await tester.scrollUntilVisible(
    find.byKey(kGymEditorWahlUebung(uid)),
    300,
    scrollable: wahlListe(),
    maxScrolls: 400,
  );
  await tester.pump();
}

/// Bewegungsbilder für **jede** Bibliotheksübung außer [ohne] — über den
/// echten Text-Weg (`Uebungsbilder.parse`, `media`-Zuordnungen). Der Test
/// bestimmt so, welche Übung ein Bild hat, statt es aus dem Asset zu raten.
Uebungsbilder bibliotheksBilder({Set<String> ohne = const {}}) {
  final spalten = Uebungsbilder.erwarteteSpalten;
  final zeilen = <List<Object?>>[];
  final media = <String, Object?>{};
  for (final id in ExerciseLibrary.all.keys) {
    if (ohne.contains(id)) continue;
    final zeile = List<Object?>.filled(spalten.length, null);
    zeile[spalten.indexOf('id')] = 'repdb-$id';
    zeile[spalten.indexOf('en')] = 'Erfundene Übung $id';
    zeile[spalten.indexOf('images')] = {'main': '$id.webp'};
    zeilen.add(zeile);
    media[id] = {'repdb': 'repdb-$id', 'approximate': false, 'note': null};
  }
  return Uebungsbilder.parse(
    jsonEncode({'fields': spalten, 'exercises': zeilen, 'media': media}),
  );
}

void main() {
  /// Öffnet einen neuen Editor und darüber die Auswahl.
  Future<TrainingsHuelle> auswahl(
    WidgetTester tester, {
    Uebungsbilder? bilder,
  }) async {
    final h = editorHuelle(bilder: bilder);
    await oeffneNeuenEditor(tester, h);
    await tippe(tester, find.byKey(kGymEditorHinzufuegen));
    expect(find.byKey(kGymEditorWahl), findsOneWidget);
    return h;
  }

  GymEditorStand stand(TrainingsHuelle h) =>
      h.container.read(gymEditorProvider(const GymEditorQuelle.neu()));

  group('Fokus und Suchfeld (Spec 9.5, Tabelle 9.8)', () {
    editorTest('das Blatt öffnet mit Fokus im Suchfeld', (tester) async {
      await auswahl(tester);
      await tester.pump();

      final feld = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(kGymEditorWahlSuche),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        feld.focusNode.hasFocus,
        isTrue,
        reason: 'Suche zuerst (Entscheidung 12): Autofokus beim Öffnen',
      );
    });

    editorTest('das Suchfeld bleibt beim Scrollen an derselben Stelle', (
      tester,
    ) async {
      await auswahl(tester);
      final vorher = tester.getTopLeft(find.byKey(kGymEditorWahlSuche));
      final ersteGruppe = find.byKey(kGymEditorWahlGruppe(Muscle.chest.code));
      expect(
        ersteGruppe,
        findsOneWidget,
        reason: 'Voraussetzung: die Liste zeigt die ersten Gruppen (9.8)',
      );
      final gruppeVorher = tester.getTopLeft(ersteGruppe).dy;

      await tester.drag(wahlListe(), const Offset(0, -400));
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(kGymEditorWahlSuche)),
        vorher,
        reason:
            'Das Suchfeld steht außerhalb des Scrollbereichs (9.1) — bei '
            '581 Zeilen wäre ein wegscrollendes Feld der Fehler',
      );
      final gruppeNachher = ersteGruppe.evaluate().isEmpty
          ? double.negativeInfinity
          : tester.getTopLeft(ersteGruppe).dy;
      expect(
        gruppeNachher,
        lessThan(gruppeVorher),
        reason: 'und die Liste hat sich wirklich bewegt',
      );
    });
  });

  group('Lazy (Spec 9.4, 9.9)', () {
    editorTest('nicht alle Zeilen stehen im Baum — und doch ist jede durch '
        'Scrollen erreichbar', (tester) async {
      await auswahl(tester);

      var gebaut = 0;
      for (final id in ExerciseLibrary.all.keys) {
        if (find
            .byKey(kGymEditorWahlUebung(id), skipOffstage: false)
            .evaluate()
            .isNotEmpty) {
          gebaut++;
        }
      }
      expect(
        gebaut,
        greaterThan(0),
        reason: 'Voraussetzung: die Liste zeigt etwas',
      );
      expect(
        gebaut,
        lessThan(ExerciseLibrary.length),
        reason:
            'Die Liste wird gebaut, wenn sie ins Bild kommt — keine Column '
            'aus ${ExerciseLibrary.length} Widgets (9.4)',
      );

      // Schienbein ist die letzte Gruppe (ein Eintrag, der Anker
      // `tibialisRaise`): erst nicht im Baum, nach dem Scrollen da.
      const letzte = 'tibialisRaise';
      expect(ExerciseLibrary.byId(letzte), isNotNull);
      expect(
        find.byKey(kGymEditorWahlUebung(letzte), skipOffstage: false),
        findsNothing,
        reason: 'eine Zeile am Ende der Liste ist anfangs nicht gebaut',
      );
      await zeigeZeile(tester, letzte);
      expect(find.byKey(kGymEditorWahlUebung(letzte)), findsOneWidget);
    });
  });

  group('Suche (Spec 9.3, Tabelle 9.8)', () {
    editorTest('die Anfrage filtert beim Tippen, leere Gruppen fehlen', (
      tester,
    ) async {
      await auswahl(tester);
      final bauchroller = ExerciseLibrary.byId('ab-wheel-rollout')!;

      await gebeEin(tester, kGymEditorWahlSuche, bauchroller.name);
      await tester.pumpAndSettle();

      expect(
        find.byKey(kGymEditorWahlUebung('ab-wheel-rollout')),
        findsOneWidget,
        reason: 'der Treffer steht da, ohne Scrollen — die Liste ist kurz',
      );
      expect(
        find.byKey(kGymEditorWahlGruppe(Muscle.core.code)),
        findsOneWidget,
        reason: 'seine Gruppe bleibt — Suchen und Blättern sind eine Anzeige',
      );
      expect(
        find.byKey(kGymEditorWahlGruppe(Muscle.chest.code)),
        findsNothing,
        reason: 'eine Gruppe ohne Treffer fehlt (9.1)',
      );
      expect(find.byKey(kGymEditorWahlLeer), findsNothing);
    });

    editorTest('die Suche faltet: „uberzuge" findet die Übung mit Umlaut, '
        '„squat" und „kniebeuge" finden dieselbe Übung', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'uberzuge');
      await tester.pumpAndSettle();
      expect(
        find.byKey(kGymEditorWahlUebung('straightArmPulldown')),
        findsOneWidget,
        reason: '„Überzüge am Kabel" — gefaltet, nicht wörtlich (Spec 9.3)',
      );

      for (final anfrage in ['squat', 'kniebeuge']) {
        await gebeEin(tester, kGymEditorWahlSuche, anfrage);
        await tester.pumpAndSettle();
        await zeigeZeile(tester, 'squat');
        expect(
          find.byKey(kGymEditorWahlUebung('squat')),
          findsOneWidget,
          reason: '„$anfrage": Englisch und Deutsch finden beide (Spec 9.3)',
        );
      }
    });

    editorTest('ohne Treffer ein Satz; die Anfrage geleert bringt alles '
        'wieder', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'zzzzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(kGymEditorWahlLeer), findsOneWidget);
      expect(
        find.byKey(kGymEditorWahlGruppe(Muscle.chest.code)),
        findsNothing,
      );

      await gebeEin(tester, kGymEditorWahlSuche, '');
      await tester.pumpAndSettle();
      expect(find.byKey(kGymEditorWahlLeer), findsNothing);
      expect(
        find.byKey(kGymEditorWahlGruppe(Muscle.chest.code)),
        findsOneWidget,
        reason: 'wieder die volle Liste (Tabelle 9.8)',
      );
    });

    editorTest('die sichtbaren Zeilen stehen in der Reihenfolge von '
        '`ExerciseLibrary.search`', (tester) async {
      await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'curl');
      await tester.pumpAndSettle();

      final erwartet = [
        for (final u in ExerciseLibrary.search('curl')) u.id,
      ];
      expect(erwartet, isNotEmpty, reason: 'sonst prüft das nichts');
      final sichtbar = <(double, String)>[];
      for (final id in erwartet) {
        final f = find.byKey(kGymEditorWahlUebung(id));
        if (f.evaluate().isEmpty) continue;
        sichtbar.add((tester.getTopLeft(f).dy, id));
      }
      expect(
        sichtbar,
        hasLength(greaterThan(1)),
        reason: 'mindestens zwei Treffer im Bild',
      );
      final vonObenNachUnten = [...sichtbar]
        ..sort((a, b) => a.$1.compareTo(b.$1));
      expect(
        [for (final (_, id) in vonObenNachUnten) id],
        [for (final (_, id) in sichtbar) id],
        reason:
            'Gruppe, dann gefalteter Name — die Reihenfolge der Bibliothek, '
            'keine eigene (Spec 9.2, 9.3)',
      );
    });
  });

  group('Die Vorschau unterbricht nichts (Spec 9.5, Tabelle 9.8; '
      'Nachtrag 29 Nr. 1)', () {
    editorTest('Anfrage und Scrollposition überleben die Vorschau — '
        'dreimal nacheinander wählen', (tester) async {
      final h = await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'curl');
      await tester.pumpAndSettle();
      final treffer = [for (final u in ExerciseLibrary.search('curl')) u.id];
      final erste = treffer.first;
      final zweite = treffer[1];
      await zeigeZeile(tester, erste);
      final lage = tester.getTopLeft(find.byKey(kGymEditorWahlUebung(erste)));

      // Erste Übung: antippen öffnet die **Vorschau**, „Speichern" fügt
      // hinzu und kehrt zur Auswahl zurück (Nachtrag 29 Nr. 1, kippt
      // Spec 28 Nr. 1) — mit derselben Anfrage und derselben
      // Scrollposition.
      await tippe(tester, find.byKey(kGymEditorWahlUebung(erste)));
      expect(find.byKey(kGymEditorBlatt), findsOneWidget);
      await tippe(tester, find.byKey(kBlattSpeichern));

      expect(find.byKey(kGymEditorWahl), findsOneWidget);
      expect(
        feldInhalt(tester, kGymEditorWahlSuche),
        'curl',
        reason: 'die Anfrage bleibt stehen (9.5)',
      );
      expect(
        tester.getTopLeft(find.byKey(kGymEditorWahlUebung(erste))),
        lage,
        reason: 'die Scrollposition bleibt (9.5)',
      );
      expect(
        find.byKey(kGymEditorWahlSchonDrin(erste)),
        findsOneWidget,
        reason: 'die eben gewählte Übung steht als „schon im Training" da',
      );

      // Zweite und dritte Wahl, ohne neu zu tippen.
      await zeigeZeile(tester, zweite);
      await tippe(tester, find.byKey(kGymEditorWahlUebung(zweite)));
      await tippe(tester, find.byKey(kBlattSpeichern));
      expect(feldInhalt(tester, kGymEditorWahlSuche), 'curl');
      expect(
        stand(h).uebungen.map((e) => e.exerciseId),
        [erste, zweite],
        reason: '„Curl eintippen, dreimal tippen" ist der Sinn der Regel',
      );
    });

    editorTest('„schon im Training" bleibt nicht antippbar — auch für eine '
        'Bibliotheksübung', (tester) async {
      final h = await auswahl(tester);

      await gebeEin(tester, kGymEditorWahlSuche, 'Bauchroller');
      await tester.pumpAndSettle();
      await tippe(
        tester,
        find.byKey(kGymEditorWahlUebung('ab-wheel-rollout')),
      );
      await tippe(tester, find.byKey(kBlattSpeichern));
      expect(stand(h).uebungen, hasLength(1));

      expect(
        find.byKey(kGymEditorWahlSchonDrin('ab-wheel-rollout')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(kGymEditorWahlUebung('ab-wheel-rollout')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        stand(h).uebungen,
        hasLength(1),
        reason: 'Eine Übung steht nur einmal im Training (Spec 4.1)',
      );
      expect(find.byKey(kGymEditorBlatt), findsNothing);
    });
  });

  group('Der Fußtext (Spec 9.1, 10)', () {
    editorTest('nennt `ExerciseLibrary.length` — gezählt, nicht 33, ohne '
        '„mit Bild"', (tester) async {
      await auswahl(tester);

      // Eine enge Anfrage macht die Liste kurz; der Fuß steht an ihrem Ende
      // und nennt trotzdem die Gesamtzahl — er beschreibt den Katalog, nicht
      // die Treffer.
      await gebeEin(tester, kGymEditorWahlSuche, 'Bauchroller');
      await tester.pumpAndSettle();

      final fuss = textUnter(tester, kGymEditorWahlFuss);
      expect(fuss, gymEditorWahlFuss(ExerciseLibrary.length));
      expect(fuss, contains('${ExerciseLibrary.length}'));
      expect(fuss, isNot(contains('33 ')));
      expect(
        fuss,
        isNot(contains('mit Bild')),
        reason:
            'Die Zusage steht nicht im Fußtext, sondern im Icon, das jede '
            'Zeile für sich beantwortet (Spec 9.6)',
      );
    });
  });

  group('Das Abspiel-Icon (Spec 9.6, Nachtrag 17 Nr. 1 — latent)', () {
    editorTest('haben alle Übungen ein Bild, steht nirgends ein Icon', (
      tester,
    ) async {
      await auswahl(tester, bilder: bibliotheksBilder());

      expect(
        find.byIcon(CupertinoIcons.play_circle),
        findsNothing,
        reason:
            'Tims Entscheidung (Nachtrag 17 Nr. 1): sichtbar erst bei '
            'gemischter Lage — heute haben alle ein Bild',
      );
      // Auch nach einer Anfrage, die Zeilen baut:
      await gebeEin(tester, kGymEditorWahlSuche, 'Bauchroller');
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.play_circle), findsNothing);
      expect(
        find.byKey(wahlBildSchluessel('ab-wheel-rollout')),
        findsNothing,
      );
    });

    editorTest('fehlt mindestens ein Bild, steht das Icon bei jeder Zeile '
        'mit Bild und bei keiner ohne — und beide Zeilen haben dieselbe '
        'Form', (tester) async {
      // `squat` hat als einzige kein Bild — der Test bestimmt das, nicht
      // das Asset.
      await auswahl(tester, bilder: bibliotheksBilder(ohne: {'squat'}));

      await gebeEin(tester, kGymEditorWahlSuche, 'kniebeuge');
      await tester.pumpAndSettle();

      // Ein Nachbar mit Bild aus denselben Treffern.
      final mitBild = ExerciseLibrary.search('kniebeuge')
          .map((u) => u.id)
          .firstWhere((id) => id != 'squat');

      await zeigeZeile(tester, mitBild);
      expect(
        find.byKey(wahlBildSchluessel(mitBild)),
        findsOneWidget,
        reason: '$mitBild hat ein Bild — das Icon steht',
      );
      final zeileMit = (
        hoehe: tester.getSize(find.byKey(kGymEditorWahlUebung(mitBild))).height,
        nameX: tester
            .getTopLeft(
              find.descendant(
                of: find.byKey(kGymEditorWahlUebung(mitBild)),
                matching: find.text(ExerciseLibrary.byId(mitBild)!.name),
              ),
            )
            .dx,
      );

      await zeigeZeile(tester, 'squat');
      expect(
        find.byKey(wahlBildSchluessel('squat')),
        findsNothing,
        reason: 'squat hat keins — kein Icon, aber reservierter Platz',
      );
      final zeileOhne = (
        hoehe: tester.getSize(find.byKey(kGymEditorWahlUebung('squat'))).height,
        nameX: tester
            .getTopLeft(
              find.descendant(
                of: find.byKey(kGymEditorWahlUebung('squat')),
                matching: find.text(ExerciseLibrary.byId('squat')!.name),
              ),
            )
            .dx,
      );

      expect(
        zeileOhne.hoehe,
        zeileMit.hoehe,
        reason: 'dieselbe Höhe mit und ohne Icon („eine Form", Spec 9.6)',
      );
      expect(
        zeileOhne.nameX,
        zeileMit.nameX,
        reason: 'Name und Dosis springen nicht (fester 24-pt-Platz)',
      );
    });

    editorTest('der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
    ) async {
      await auswahl(tester, bilder: bibliotheksBilder(ohne: {'squat'}));

      await gebeEin(tester, kGymEditorWahlSuche, 'kniebeuge');
      await tester.pumpAndSettle();
      final mitBild = ExerciseLibrary.search('kniebeuge')
          .map((u) => u.id)
          .firstWhere((id) => id != 'squat');

      await zeigeZeile(tester, mitBild);
      expect(
        semantikTexte(tester, find.byKey(kGymEditorWahlUebung(mitBild))),
        contains('mit bewegungsbild'),
        reason: 'Spec 9.6: der Name, die Dosis, dann „mit Bewegungsbild"',
      );

      await zeigeZeile(tester, 'squat');
      expect(
        semantikTexte(tester, find.byKey(kGymEditorWahlUebung('squat'))),
        isNot(contains('mit bewegungsbild')),
        reason: 'ohne Bild sagt der Vorlesetext nichts dergleichen',
      );
    });
  });
}
