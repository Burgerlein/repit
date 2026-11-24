import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/formatierung.dart';
import 'package:repit/design/platzhalter.dart'
    show Platzhalter, ohneWert;
import 'package:repit/gym/gym_fokus_texte.dart';
import 'package:repit/gym/gym_view.dart';

import 'support.dart';

/// Die Auswertungszeilen, deren Ziel noch fehlt (#96).
/// „Letzte Trainings" führt seit #79 in den Verlauf, „Fortschritt pro
/// Übung" seit #93 in den Fortschritt — beide gehören nicht mehr dazu
/// (nachgezogen am 11.11.2026 mit TEST_AENDERN=1). **„Trainings"
/// (`gym-auswertung-plaene`) führt seit #533 auf die Trainings-Übersicht**
/// und gehört ebenfalls nicht mehr dazu (nachgezogen am 19.11.2026 mit
/// TEST_AENDERN=1; Spec 7.9 nennt diese Stelle ausdrücklich, Tür und Wert
/// prüft `gym_trainings_zugang_test.dart`).
const zeilenOhneZiel = [kZeileMuskeln];

/// Widget-Tests für den **Gym-Übersichtsschirm** (#77),
/// `lib/gym/gym_view.dart`.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-fokus-karte-design.md`; die
/// Liste der Fälle steht dort in Abschnitt 13. Die Leerzustände und die
/// beiden Pflichtanforderungen liegen in
/// `gym_view_leerzustaende_test.dart`, die Hülle in `support.dart`.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Geprüft wird die eine Verzweigung dieses Schirms —
/// `GymDay.focus` mit vier Fällen — und was sich mit ihr ändert.
///
/// **Warum trotzdem Texte verglichen werden.** Die Sätze dieses Schirms
/// entstehen nach Spec Abschnitt 4 an **genau einer Stelle je Vokabular**
/// (`gym_fokus_texte.dart`, `gym_wochen_texte.dart`,
/// `gym_vorschlag_texte.dart`). Die Tests rufen deshalb dieselben
/// Funktionen auf und vergleichen damit — sie nageln keinen Wortlaut
/// fest, sondern die Zusage, dass der Schirm sich seine Sätze nicht
/// selbst zusammenbaut. Ein Wortlautwechsel in der Textdatei lässt sie
/// grün; ein zweiter Ort, an dem derselbe Satz entsteht, nicht.
///
/// Die einzige Ausnahme, an der ein Wortlaut wirklich gebunden ist: der
/// **Hinweis auf die ärztliche Freigabe** im Zustand `recovery`. `CLAUDE.md`
/// („Keine Diagnosen") verlangt ihn, und sein Wegfall wäre eine falsche
/// Zusage — Spec Abschnitt 13 nennt das ausdrücklich.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Farben, Abstände, Schriftgrößen, Pixelpositionen.** Auch nicht
///   `Palette.rest` als Akzent des Ruhetags: Das ist eine
///   Entwurfsentscheidung und kein Verhalten (offene Entscheidung 5 der
///   Spec).
/// - **Dynamic Type.** `content_size` wird nirgends verstellt.
/// - **Golden-Tests.**
/// - **Die Zahl der Vorschauzeilen** (drei oder vier). Spec Abschnitt 5.2
///   sagt drei, Abschnitt 14 führt die Frage als **offen**. Ein Test
///   darauf entschiede sie — siehe Bericht.
/// - **Wohin eine Tür führt.** Heute führt keine irgendwohin (Spec
///   Abschnitt 11, alle fünf Zielschirme fehlen); geprüft ist deshalb das
///   Gegenteil, und der `AppTarget.aktuell`-Fall kommt mit dem ersten
///   gebauten Ziel dazu.
void main() {
  group('Hausordnung', () {
    testWidgets('der Schirm bringt weder Gerüst noch Leiste noch Navigator '
        'mit', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byType(GymView),
          matching: find.byType(CupertinoPageScaffold),
        ),
        findsNothing,
        reason: 'Das Gerüst stellt `RootView` für jeden Tab (Spec 3)',
      );
      expect(
        find.descendant(
          of: find.byType(GymView),
          matching: find.byType(CupertinoNavigationBar),
        ),
        findsNothing,
        reason:
            'Die Navigationsleiste trägt „Gym" und die Glocke — in '
            '`RootView`, nicht hier',
      );
      expect(
        find.descendant(
          of: find.byType(GymView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
        reason:
            'Jeder Tab führt seinen eigenen Stapel; ein zweiter hier '
            'wäre ein zweiter (`CLAUDE.md`)',
      );
    });

    testWidgets('die Pflichtabschnitte stehen in jedem der vier Zustände', (
      tester,
    ) async {
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        for (final key in pflichtAbschnitte) {
          expect(
            find.byKey(key),
            findsOneWidget,
            reason:
                '${fall.key}: $key fehlt. „Jeder dieser Abschnitte steht in '
                'jedem Zustand und in jeder Datenlage" (Spec 3)',
          );
        }
      }
    });

    testWidgets('baut ohne Ausnahme und ohne ErrorWidget', (tester) async {
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(find.byType(ErrorWidget), findsNothing, reason: fall.key);
        expect(tester.takeException(), isNull, reason: fall.key);
      }
    });
  });

  group('Die vier Zustände der Fokus-Karte', () {
    testWidgets('jeder Fall zeigt seine Kapsel — und keine der drei '
        'anderen', (tester) async {
      final faelle = alleVierZustaende();
      final kapseln = {
        for (final fall in faelle.entries)
          fall.key: gymFokusKapsel(fall.value.tag.focus),
      };

      for (final fall in faelle.entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        final gezeigt = flach(texteUnter(tester, kKapsel));
        expect(
          gezeigt,
          kapseln[fall.key],
          reason: '${fall.key}: die Kapsel kommt aus `gymFokusKapsel`',
        );
        for (final andere in kapseln.entries) {
          if (andere.key == fall.key) continue;
          expect(
            gezeigt,
            isNot(andere.value),
            reason: '${fall.key} zeigt die Kapsel von ${andere.key}',
          );
        }
      }
    });

    testWidgets('Titel und Untertitel kommen aus `gym_fokus_texte.dart`', (
      tester,
    ) async {
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(
          flach(texteUnter(tester, kTitel)),
          flach(gymFokusTitel(fall.value.tag.focus)),
          reason: fall.key,
        );
        expect(
          flach(texteUnter(tester, kUntertitel)),
          flach(gymFokusUntertitel(fall.value.tag.focus, heute: heute)),
          reason: fall.key,
        );
      }
    });

    testWidgets('der Fortschrittsbalken steht ausschließlich bei '
        '`InProgress`', (tester) async {
      final laeuft = tagLaeuft(erfasst: 2);
      final h = gymHuelle(laeuft);
      await zeige(tester, h.app);

      expect(find.byKey(kFortschritt), findsOneWidget);
      expect(
        flach(texteUnter(tester, kKarte)),
        contains(gymFokusFortschrittText(done: 2, total: uebungenPush)),
        reason:
            'die Beschriftung unter dem Balken nennt Übungen, keine '
            'Sätze (Spec 5.1)',
      );

      for (final fall in alleVierZustaende().entries) {
        if (fall.key == 'inProgress') continue;
        final ohne = gymHuelle(fall.value);
        await zeige(tester, ohne.app);
        expect(
          find.byKey(kFortschritt),
          findsNothing,
          reason:
              '${fall.key}: kein Balken — und schon gar keiner auf 0 %, '
              'das wäre Fehler `01` in neuer Verpackung',
        );
      }
    });

    testWidgets('die Knopfreihe je Zustand: zwei, zwei, zwei bzw. einer, '
        'einer', (tester) async {
      final erwartet = {
        'inProgress': (tagLaeuft(), 2),
        'planned': (tagGeplant(), 2),
        'rest mit next': (tagRuheMitNaechstem(), 2),
        'rest ohne next': (tagRuheLeer(), 1),
        'recovery': (tagErholung(), 1),
      };

      for (final fall in erwartet.entries) {
        final h = gymHuelle(fall.value.$1);
        await zeige(tester, h.app);

        expect(
          knoepfe(),
          findsNWidgets(fall.value.$2),
          reason:
              '${fall.key} (Spec 5.1–5.4). Es gibt keinen Zustand ohne '
              'Knopf — „Plan ansehen" ist in zweien der einzige.',
        );
      }
    });

    testWidgets('die Fußzeile des laufenden Trainings nennt die erste noch '
        'nicht erfasste Übung', (tester) async {
      const erfasst = 2;
      final h = gymHuelle(tagLaeuft(erfasst: erfasst));
      await zeige(tester, h.app);

      final naechste = ExerciseCatalog.exercisesFor(Workout.push)[erfasst];
      expect(find.byKey(kKartenFuss), findsOneWidget);
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        contains(flach(gymNaechsteUebungTitel(naechste))),
        reason: '`exercisesFor(workout)[done]` (Spec 5.1)',
      );
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        isNot(matches(nullAlsWert)),
        reason:
            'Ohne Verlauf gibt es kein Gewicht, sondern den Hinweis auf '
            'den Wiederholungsbereich — „0 kg" wäre Fehler `01`',
      );
    });

    testWidgets('ist alles erfasst, hat die Karte keine Fußzeile', (
      tester,
    ) async {
      final h = gymHuelle(tagLaeuft(erfasst: uebungenPush));
      await zeige(tester, h.app);

      expect(
        find.byKey(kKartenFuss),
        findsNothing,
        reason:
            '„solange `done` innerhalb der Liste liegt, sonst keine '
            'Fußzeile" (Spec 5.1)',
      );
      expect(
        find.byKey(kKarte),
        findsOneWidget,
        reason: 'die Karte selbst bleibt — es gibt keinen Zustand ohne sie',
      );
    });

    testWidgets('die Übungsvorschau führt die Zeile „Alle N Übungen '
        'ansehen"', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      expect(find.byKey(kKartenFuss), findsOneWidget);
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        contains(gymAlleUebungenText(uebungenPush)),
        reason:
            'Die Zeile erscheint, weil die Vorschau weniger zeigt als '
            'Push Übungen hat (Spec 5.2). Wie viele sie zeigt, ist offene '
            'Entscheidung 3 und wird hier nicht festgelegt.',
      );
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        isNot(matches(nullAlsWert)),
        reason:
            'Ohne Verlauf steht je Zeile kein Zielgewicht, nie „0 kg" '
            '(Spec 5.2)',
      );
    });

    testWidgets('der Ruhetag nennt das nächste Krafttraining genau dann, '
        'wenn `next` vorliegt', (tester) async {
      final mit = tagRuheMitNaechstem();
      final ohne = tagRuheLeer();
      final restMit = mit.tag.focus as Rest;
      final restOhne = ohne.tag.focus as Rest;
      expect(restMit.next, isNotNull, reason: 'Vorbedingung');
      expect(restOhne.next, isNull, reason: 'Vorbedingung');

      final h = gymHuelle(mit);
      await zeige(tester, h.app);
      expect(
        flach(texteUnter(tester, kUntertitel)),
        contains(restMit.next!.title),
        reason: 'die zweite Untertitelzeile nennt das nächste Workout',
      );

      final leer = gymHuelle(ohne);
      await zeige(tester, leer.app);
      expect(
        flach(texteUnter(tester, kUntertitel)),
        isNot(contains(restMit.next!.title)),
      );
      expect(
        flach(texteUnter(tester, kUntertitel)),
        flach(gymFokusUntertitel(restOhne, heute: heute)),
        reason:
            'stattdessen die Ersatzzeile — und die darf stehen, weil '
            'hier wirklich nachgesehen wurde (`laedt: false`)',
      );
    });

    testWidgets('der Ruhetag zeigt die Fußzeile genau dann, wenn `overdue` '
        'vorliegt', (tester) async {
      final ohne = gymHuelle(tagRuheLeer());
      await zeige(tester, ohne.app);
      expect(find.byKey(kKartenFuss), findsNothing);

      final mit = tagRuheMitNachzuegler();
      final nachzuegler = (mit.tag.focus as Rest).overdue;
      expect(nachzuegler, isNotNull, reason: 'Vorbedingung');

      final h = gymHuelle(mit);
      await zeige(tester, h.app);
      expect(find.byKey(kKartenFuss), findsOneWidget);
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        contains(gymOffenTitel(nachzuegler!)),
      );
    });

    testWidgets('die Erholung nennt die ärztliche Freigabe — im Untertitel '
        'und in der Fußzeile der Karte', (tester) async {
      final h = gymHuelle(tagErholung());
      await zeige(tester, h.app);

      // Der einzige Wortlaut, der hier wirklich gebunden ist: `CLAUDE.md`
      // („Keine Diagnosen") verlangt den Verweis, und sein Wegfall wäre
      // eine falsche Zusage (Spec 5.4 und 13).
      expect(
        flach(texteUnter(tester, kUntertitel)),
        contains('ärztlicher Freigabe'),
      );
      expect(
        flach(texteUnter(tester, kKartenFuss)),
        contains('ärztlicher Freigabe'),
      );
      // Der graue Hinweis am Fuß des Schirms trug hier „Ärztin oder dein
      // Arzt". Spec 26 Nr. 3 nimmt „den grauen Fußtext" weg und nennt
      // ausdrücklich nur den Satz über die Gewichte — ob der Erholungs-Fuß
      // mitgeht, ist **nicht entschieden** und wird hier nicht geprüft
      // (gemeldet). Die Pflicht aus `CLAUDE.md` bleibt in Untertitel und
      // Kartenfuß bewacht, oben.
    });

    testWidgets('kein Datum im Quelltext: zwei erfundene OP-Tage ergeben '
        'zwei verschiedene Termine', (tester) async {
      final texte = <String>[];
      final ledes = <String>[];

      for (final tage in [9, 3]) {
        final tag = tagErholung(tageNachOp: tage);
        final erholung = tag.tag.focus as Recovery;
        expect(erholung.dayAfterSurgery, tage, reason: 'Vorbedingung');

        final h = gymHuelle(tag);
        await zeige(tester, h.app);

        final untertitel = flach(texteUnter(tester, kUntertitel));
        expect(
          untertitel,
          contains(
            Format.wochentagUndTagMonat(kalendertag(erholung.earliestReturn)),
          ),
          reason:
              'der Termin kommt aus `Recovery.earliestReturn`, nicht aus '
              'dem Quelltext',
        );
        texte.add(untertitel);
        ledes.add(flach(texteUnter(tester, kLede)));
      }

      expect(
        texte.first,
        isNot(texte.last),
        reason: 'wäre das Datum fest verdrahtet, stünde zweimal dasselbe da',
      );
      expect(ledes.first, isNot(ledes.last), reason: 'Tag 9 ist nicht Tag 3');
    });

    testWidgets('es gibt keinen grauen Hinweis am Fuß mehr — in keinem Zustand '
        'außer `recovery` (Spec 26 Nr. 3)', (tester) async {
      // „Die Gewichte sind Vorschläge …" entfällt [Tim, 19.11.2026]. Der
      // Erholungs-Fuß (ärztliche Freigabe) bleibt.
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);
        if (fall.value.tag.focus is Recovery) {
          expect(
            find.byKey(kHinweis),
            findsOneWidget,
            reason: '${fall.key}: der Erholungs-Fuß mit der ärztlichen '
                'Freigabe bleibt (Folgerung aus Spec 26, vom Koordinator '
                'bestätigt)',
          );
          continue;
        }

        expect(
          find.byKey(kHinweis),
          findsNothing,
          reason: '${fall.key}: Der Fuß existiert nicht mehr',
        );
        expect(
          alleTexte(tester),
          isNot(contains('Vorschläge')),
          reason: '${fall.key}: auch nicht als Text ohne den Schlüssel',
        );
      }
    });

    testWidgets('der Lede ist gerechnet: Tage, „kein fester Tag", Tag nach '
        'der OP', (tester) async {
      final faelle = {
        'mit Plan': tagGeplant(),
        'ohne Plan': tagRuheLeer(),
        'recovery': tagErholung(),
      };

      for (final fall in faelle.entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(
          flach(texteUnter(tester, kLede)),
          flach(gymLede(fall.value.tag, heute: heute)),
          reason: fall.key,
        );
      }
    });
  });

  group('Übergänge', () {
    testWidgets('ändert sich der Fokus, ändert sich die Karte mit — und '
        'nichts bleibt stehen', (tester) async {
      final laeuft = tagLaeuft();
      final ruhe = tagRuheLeer();

      final h = gymHuelle(laeuft);
      await zeige(tester, h.app);
      expect(
        flach(texteUnter(tester, kKapsel)),
        gymFokusKapsel(laeuft.tag.focus),
      );
      expect(find.byKey(kFortschritt), findsOneWidget);

      setze(h, ruhe);
      await tester.pumpAndSettle();

      expect(
        flach(texteUnter(tester, kKapsel)),
        gymFokusKapsel(ruhe.tag.focus),
      );
      expect(flach(texteUnter(tester, kTitel)), gymFokusTitel(ruhe.tag.focus));
      expect(
        find.byKey(kFortschritt),
        findsNothing,
        reason:
            'ein Balken aus dem vorigen Zustand behauptete ein Training, '
            'das nicht mehr läuft',
      );
      expect(
        alleTexte(tester),
        isNot(contains(gymFokusKapsel(laeuft.tag.focus))),
      );
      expect(
        alleTexte(tester),
        isNot(contains(gymFokusTitel(laeuft.tag.focus))),
      );
    });

    testWidgets('und zurück: der Übergang trägt in beide Richtungen', (
      tester,
    ) async {
      final geplant = tagGeplant();
      final erholung = tagErholung();

      final h = gymHuelle(geplant);
      await zeige(tester, h.app);

      setze(h, erholung);
      await tester.pumpAndSettle();
      expect(
        flach(texteUnter(tester, kKapsel)),
        gymFokusKapsel(erholung.tag.focus),
      );

      setze(h, geplant);
      await tester.pumpAndSettle();
      expect(
        flach(texteUnter(tester, kKapsel)),
        gymFokusKapsel(geplant.tag.focus),
      );
      expect(
        find.byKey(kHinweis),
        findsNothing,
        reason: 'auch nach dem Rückweg aus `recovery` steht kein Fuß da',
      );
    });
  });

  group('Die Wochenleiste „Diese Woche"', () {
    // Nachgezogen am 19.11.2026 mit TEST_AENDERN=1 (Task 2.8, Spec 23):
    // Die Woche liest die gespeicherte Rotation, und die ist zum Start
    // Push, Pull, Legs — **drei Plätze sind ab jetzt richtig** („Die
    // Wochenleisten-Wächtertests (vier Plätze, #425) gehören dem
    // Test-Agenten", Spec 23). **Die Wächterrolle bleibt:** Die Platzzahl
    // und damit die Breite springen nicht, sobald ein Platz einen Tag
    // bekommt oder verliert (#425) — nur ist die Zahl jetzt drei.
    testWidgets('zeigt in jedem der vier Zustände drei Plätze (#425)', (
      tester,
    ) async {
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(
          fall.value.tag.week.length,
          3,
          reason: 'Vorbedingung: der Kern liefert die drei der Rotation',
        );
        for (final workout in rotationPpl) {
          expect(
            find.byKey(kPlatz(workout)),
            findsOneWidget,
            reason:
                '${fall.key}: ${workout.label} fehlt in der Leiste. Drei '
                'Plätze in jedem Zustand — sonst springt die Breite, sobald '
                'ein Platz einen Tag bekommt oder verliert (#425).',
          );
        }
      }
    });

    // Umgekehrt am 19.11.2026 mit TEST_AENDERN=1: Bis dahin galt „Push, Pull
    // und Legs stehen nie in der Leiste, weil sie nie fällig werden"
    // (`Workout.freelyChosen`). Spec 23 hebt das auf — und dreht die
    // Aussage um: **Gym A bis D** stehen nicht mehr in der Leiste.
    testWidgets('Gym A bis D stehen nicht in der Leiste', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      for (final workout in rotationPpl) {
        expect(
          find.byKey(kPlatz(workout)),
          findsOneWidget,
          reason: 'Vorbedingung: ohne die drei Kacheln prüft der Rest nichts',
        );
      }
      for (final workout in Workout.rotation) {
        expect(
          find.byKey(kPlatz(workout)),
          findsNothing,
          reason:
              '${workout.label}: in der Oberfläche nirgends mehr startbar '
              '(Spec 23); der Kern gibt sie nicht mehr heraus, der Schirm '
              'filtert nicht ein zweites Mal (Spec 6)',
        );
      }
    });

    testWidgets('ein Platz ohne festen Tag steht mit „—" da, nicht leer', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      final ohneTag = tagGeplant().tag.week.firstWhere(
        (platz) => platz.weekday == null,
      );
      expect(
        texteUnter(tester, kPlatz(ohneTag.workout)),
        contains('—'),
        reason:
            '„—" ist kein Platzhalter für einen fehlenden Wert, sondern '
            'die Aussage „dieses Workout hat keinen festen Tag" (Spec 6)',
      );
    });
  });

  group('Die Gruppe „Auswertung"', () {
    testWidgets('die vier Zeilen stehen in jeder Datenlage da', (tester) async {
      final faelle = {...alleVierZustaende(), 'leer': tagRuheLeer()};

      for (final fall in faelle.entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        for (final zeile in auswertungsZeilen) {
          expect(
            find.byKey(zeile),
            findsOneWidget,
            reason:
                '${fall.key}: $zeile. Die Zeilen verschwinden nicht und '
                'werden nicht durch eine Sammelzeile ersetzt (Spec 7).',
          );
        }
      }
    });

    testWidgets('ohne Ziel trägt keine Zeile einen Chevron und keine ist '
        'tippbar', (tester) async {
      // Seit #79 führt „Letzte Trainings" in den Verlauf; die Zeile ist hier
      // ausgenommen (Tür und Wert prüft `gym_verlauf_zugang_test.dart`).
      // Nachgezogen am 11.11.2026 mit TEST_AENDERN=1.
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      for (final zeile in zeilenOhneZiel) {
        expect(
          find.byKey(zeile),
          findsOneWidget,
          reason: 'Vorbedingung: $zeile steht da',
        );
        expect(
          find.descendant(
            of: find.byKey(zeile),
            matching: find.byIcon(CupertinoIcons.chevron_right),
          ),
          findsNothing,
          reason:
              '$zeile: „Der Winkel folgt der Tür" — alle vier Ziele '
              'fehlen heute (Spec 7)',
        );
        expect(
          istTippbar(tester, find.byKey(zeile)),
          isFalse,
          reason:
              '$zeile: eine Zeile, die aussieht wie ein Knopf und beim '
              'Tippen schweigt, ist genau der gesuchte Fehler',
        );
      }
    });

    testWidgets('ohne Ziel bleibt der Wert leer — keine 0, kein –/–, kein '
        'Platzhalter', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      for (final zeile in auswertungsZeilen) {
        expect(
          find.byKey(zeile),
          findsOneWidget,
          reason: 'Vorbedingung: $zeile steht da',
        );
        final text = flach(texteUnter(tester, zeile));
        expect(
          text,
          isNot(matches(nullAlsWert)),
          reason:
              '$zeile: „`0` ist keine Antwort auf „kein Wert"" '
              '(`CLAUDE.md`)',
        );
        expect(
          text,
          isNot(contains(ohneWert)),
          reason:
              '$zeile: „–/–" hieße „gelesen, kein Wert" — es gibt hier '
              'keinen Lauf, der leer ausgegangen wäre (Spec 7)',
        );
        expect(
          find.descendant(
            of: find.byKey(zeile),
            matching: find.byType(Platzhalter),
          ),
          findsNothing,
          reason:
              '$zeile: die graue Form sagt „gleich kommt etwas" — hier '
              'kommt nichts mehr, bis das Ziel gebaut ist',
        );
      }
    });

    testWidgets('eine Zeile ohne Ziel kündigt nichts an — „Trainierte '
        'Muskeln" trägt nur den beschreibenden Untertitel (Spec 26 Nr. 4)', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      for (final zeile in zeilenOhneZiel) {
        final text = flach(texteUnter(tester, zeile));
        expect(
          text,
          isNot(matches(ankuendigung)),
          reason:
              '$zeile: „folgt in einer späteren Aufgabe" entfällt — Tims '
              'ausdrückliche Entscheidung [19.11.2026], gegen die Hausregel '
              '„ein Satz, bis das Feature dran ist"',
        );
      }
      expect(
        flach(texteUnter(tester, kZeileMuskeln)),
        contains('zu kurz kommen'),
        reason: 'es bleibt der Untertitel „Welche Muskeln diese Woche zu '
            'kurz kommen"',
      );
    });
  });

  group('Navigation', () {
    testWidgets('eine Zeile, deren Zielschirm fehlt, loest keinen Befehl aus', (
      tester,
    ) async {
      // Bis #78 galt das für **alles** auf diesem Schirm. Seitdem führen
      // die vier Wochenkacheln und die Knöpfe der Fokus-Karte ins
      // Erfassen; die vier Auswertungszeilen warten weiter auf ihre
      // Zielschirme (#79, #93, #96, #107). Nachgezogen am 10.11.2026 mit
      // TEST_AENDERN=1 — die Anforderung ist dieselbe, nur gilt sie jetzt
      // für weniger Elemente. Seit #79 ist auch „Letzte Trainings"
      // ausgenommen (nachgezogen am 11.11.2026 mit TEST_AENDERN=1).
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        final ziele = <Finder>[...zeilenOhneZiel.map(find.byKey)];

        for (final ziel in ziele) {
          await tester.ensureVisible(ziel);
          await tester.pumpAndSettle();
          await tester.tap(ziel, warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(
            h.router.nimmBefehl(),
            isNull,
            reason:
                '${fall.key}: die Zielschirme der Auswertung fehlen '
                '(#79, #93, #96, #107) — ein Befehl führte ins Leere',
          );
          expect(tester.takeException(), isNull, reason: fall.key);
        }
      }
    });

    testWidgets('ein Knopf ohne Ziel steht abgeblendet da, statt zu '
        'verschwinden', (tester) async {
      // Bis #78 galt das für jeden Knopf dieses Schirms. Seitdem führen
      // „Training starten", „Weiter eintragen" und „vorziehen" ins
      // Erfassen und sind deshalb wirksam. Was weiter kein Ziel hat —
      // „Plan ansehen" (#80/#81) — bleibt abgeblendet, und genau darum
      // geht es: Ein Knopf ohne Ziel verschwindet nicht, er steht grau da.
      // Nachgezogen am 10.11.2026 mit TEST_AENDERN=1. Seit #79 führt auch
      // „Verlauf" in den Verlauf; „Plan ansehen" steht aber nur in `rest`
      // und `recovery`, dort muss es also einen abgeblendeten Knopf geben
      // (nachgezogen am 11.11.2026 mit TEST_AENDERN=1).
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        final gefunden = tester.widgetList<CupertinoButton>(knoepfe());
        expect(
          gefunden,
          isNotEmpty,
          reason: '${fall.key}: es gibt keinen Zustand ohne Knopf',
        );

        var ohneZiel = 0;
        for (var i = 0; i < gefunden.length; i++) {
          final knopf = gefunden.elementAt(i);
          final abgeblendet =
              knopf.onPressed == null || opazitaet(tester, knoepfe().at(i)) < 1;
          if (!abgeblendet) continue;
          ohneZiel++;
          expect(
            knopf.child,
            isNotNull,
            reason:
                '${fall.key}, Knopf $i: „abgeblendet und ohne Wirkung; '
                'ihre Beschriftung bleibt" (Spec 11). Ein unbeschrifteter '
                'Nicht-Knopf wäre schlimmer.',
          );
        }
        if (fall.key == 'rest' || fall.key == 'recovery') {
          expect(
            ohneZiel,
            greaterThan(0),
            reason:
                '${fall.key}: „Plan ansehen" hat noch kein Ziel — gäbe es '
                'hier keinen abgeblendeten Knopf mehr, prüfte dieser Fall '
                'nichts',
          );
        }
      }
    });

    testWidgets('der Schirm besorgt seine Daten selbst — nur der Router '
        'kommt herein', (tester) async {
      // Gebaut wird allein mit `GymView(router: …)`; der Tageszustand
      // stammt aus `gymTagProvider` (Spec 3). Dass die Karte ihren
      // Zustand zeigt, belegt, dass der Schirm ihn selbst geholt hat.
      final h = gymHuelle(tagErholung());
      await zeige(tester, h.app);

      expect(find.byType(GymView), findsOneWidget);
      expect(
        flach(texteUnter(tester, kKapsel)),
        gymFokusKapsel(tagErholung().tag.focus),
      );
      expect(h.router.nimmBefehl(), isNull);
    });
  });
}
