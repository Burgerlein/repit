import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart'
    show Platzhalter, ohneWert;
import 'package:repit/gym/gym_fokus_texte.dart';
import 'package:repit/gym/gym_provider.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/gym/gym_wochen_texte.dart';
import 'package:repit/health/health_provider.dart';

import 'support.dart';

/// Die **Leerzustände** des Gym-Übersichtsschirms (#77) und die beiden
/// Anforderungen, auf die es nach `CLAUDE.md` ankommt.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-fokus-karte-design.md`,
/// Abschnitte 9.3, 10 und 13. Die Zustände und Übergänge liegen in
/// `gym_view_test.dart`, die Hülle in `support.dart`.
///
/// ## Die beiden Pflichtfälle
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (Fehler
///    `01`). Solange `GymTag.laedt` wahr ist, darf weder die Ersatzzeile
///    „Diese Woche ist das Krafttraining durch." noch dreimal „offen" in
///    der Wochenleiste dastehen: Beides ist eine Aussage über eine
///    Datenlage, und nachgesehen wurde noch nicht.
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder
///    da** (Fehler `32`). Er hängt daran, dass `gymTagProvider` seinen
///    Wert **hält** statt ihn neu zu rechnen — und ist damit zugleich der
///    Test auf Hausregel 2 (Fehler `03`).
///
/// ## Warum die Höhe gemessen werden darf
///
/// `CLAUDE.md` verbietet Layout-Tests; Spec Abschnitt 13 nennt die Höhe
/// ausdrücklich als Ausnahme: „Die Höhe ist messbar; das ist kein
/// Layout-Test im verbotenen Sinn, sondern der Test auf die
/// Leerzustandsregel." Verglichen wird deshalb nur **dieselbe Anzeige mit
/// sich selbst** in zwei Datenlagen, nie gegen eine Zahl.
///
/// Alle Daten erfunden; alle Zeitpunkte UTC auf Berliner Tagesgrenzen.
void main() {
  /// Die Ersatzzeile aus `gym_fokus_texte.dart` — der „keine Daten"-Grund
  /// dieses Schirms. Abgeleitet statt getippt: Ändert sich der Wortlaut
  /// dort, prüft dieser Test weiter dasselbe.
  final grund = gymFokusUntertitel(
    tagRuheLeer().tag.focus,
    heute: heute,
  ).split('\n').last;

  /// Der Statustext eines offenen Platzes.
  final offen = gymWochenStatus(const Open());

  setUp(() {
    expect(
      grund,
      contains('Krafttraining durch'),
      reason:
          'Vorbedingung: das ist der Grund, der beim Laden nicht '
          'dastehen darf (Spec 9.3)',
    );
    expect(offen, 'offen', reason: 'Vorbedingung');
  });

  group('Pflicht 1 — während des Ladens steht nie ein „keine Daten"-Grund '
      '(`01`)', () {
    testWidgets('mit `laedt: true` steht die Ersatzzeile nicht da', (
      tester,
    ) async {
      final h = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, h.app);

      expect(
        flach(alleTexte(tester)),
        isNot(contains(flach(grund))),
        reason:
            'Der Satz behauptet, nachgesehen worden zu sein. Solange '
            'eine Quelle noch kein Ergebnis hat, ist das falsch — Fehler '
            '`01` in neuer Verpackung (Spec 9.3).',
      );
    });

    testWidgets('mit `laedt: true` steht in der Wochenleiste kein Statustext '
        '„offen"', (tester) async {
      final h = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, h.app);

      expect(
        flach(texteUnter(tester, kWoche)),
        isNot(contains(offen)),
        reason:
            'Dreimal „offen" ist dieselbe Behauptung wie die '
            'Ersatzzeile, nur kleiner gedruckt',
      );
    });

    testWidgets('derselbe Zustand mit `laedt: false` zeigt beides', (
      tester,
    ) async {
      final h = gymHuelle(tagRuheLeer());
      await zeige(tester, h.app);

      expect(
        flach(alleTexte(tester)),
        contains(flach(grund)),
        reason:
            'Sobald nachgesehen ist, heißt leer schlicht leer — dann '
            'darf der Grund stehen (Spec 9.3)',
      );
      expect(flach(texteUnter(tester, kWoche)), contains(offen));
    });

    testWidgets('beim Laden stehen stattdessen graue Formen an ihrer '
        'Stelle', (tester) async {
      final h = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, h.app);

      for (final key in [kLede, kKarte, kWoche, ...auswertungsZeilen]) {
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(Platzhalter),
          ),
          findsAtLeastNWidgets(1),
          reason:
              '$key: „dieselbe Geometrie, Inhalte als graue Formen" '
              '(Spec 10). Geprüft über den Baustein, nicht über eine Farbe.',
        );
      }
    });

    testWidgets('ist nachgesehen, blitzt keine graue Form mehr auf', (
      tester,
    ) async {
      final h = gymHuelle(tagRuheLeer());
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byType(GymView),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason:
            '„Der Platzhalter gehört allein in den Ladezustand" '
            '(`CLAUDE.md`)',
      );
    });

    testWidgets('die drei Abschnitte behalten beim Laden ihre Form', (
      tester,
    ) async {
      final masse = <Key, Size>{};

      final laedt = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, laedt.app);
      for (final key in [kKarte, kWoche, kAuswertung]) {
        masse[key] = tester.getSize(find.byKey(key));
      }

      final fertig = gymHuelle(tagRuheLeer());
      await zeige(tester, fertig.app);
      for (final key in [kKarte, kWoche, kAuswertung]) {
        final jetztGross = tester.getSize(find.byKey(key));
        expect(
          jetztGross.height,
          closeTo(masse[key]!.height, 0.5),
          reason:
              '$key springt zwischen Laden und Fertig. „Werte da, keine '
              'Werte, lädt — dieselbe Höhe, dieselbe Breite, dieselbe '
              'Stelle" (`CLAUDE.md`).',
        );
        expect(
          jetztGross.width,
          closeTo(masse[key]!.width, 0.5),
          reason: '$key',
        );
      }
    });
  });

  group('Pflicht 2 — ein Wert, der dastand, steht nach dem '
      'Zurücknavigieren wieder da (`32`)', () {
    testWidgets('hin zu einem Detailziel und zurück', (tester) async {
      final tag = tagGeplant();
      final h = gymHuelle(tag);

      final gesehen = <GymTag>[];
      h.container.listen(
        gymTagProvider,
        (_, next) => gesehen.add(next),
        fireImmediately: true,
      );

      await zeige(tester, h.app);
      final titelVorher = flach(texteUnter(tester, kTitel));
      final ledeVorher = flach(texteUnter(tester, kLede));
      final wocheVorher = flach(texteUnter(tester, kWoche));
      expect(
        titelVorher,
        isNot(''),
        reason: 'Vorbedingung: es stand ein echter Wert da',
      );

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('woanders')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('woanders'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(flach(texteUnter(tester, kTitel)), titelVorher);
      expect(flach(texteUnter(tester, kLede)), ledeVorher);
      expect(flach(texteUnter(tester, kWoche)), wocheVorher);
      expect(
        flach(alleTexte(tester)),
        isNot(contains(flach(grund))),
        reason: 'nach dem Zurückkommen steht kein Leerstand da',
      );
      expect(
        find.byType(Platzhalter),
        findsNothing,
        reason:
            'und auch kein Ladeplatzhalter — der Wert war die ganze '
            'Zeit da',
      );
      expect(
        gesehen.every((wert) => wert == tag),
        isTrue,
        reason:
            'Der Provider hält seinen Wert, statt ihn neu zu rechnen '
            '(Hausregel 2). Ein zwischendurch anderer Wert wäre Fehler '
            '`32` — und sein Grund wäre Fehler `03`.',
      );
    });

    testWidgets('`gymTagProvider` hält seinen Wert, statt ihn je Zugriff '
        'zu rechnen', (tester) async {
      // Hier ohne Überschreibung des Providers: geprüft ist die echte
      // Kette `heutigerTagProvider` → `gymTagProvider` (Spec 9.2).
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [clockProvider.overrideWithValue(() => jetzt)],
      );
      addTearDown(container.dispose);
      container.listen(gymTagProvider, (_, _) {});

      final erster = container.read(gymTagProvider);
      final zweiter = container.read(gymTagProvider);

      expect(
        identical(erster, zweiter),
        isTrue,
        reason:
            'Eine berechnete Eigenschaft rechnete je Bild — genau das '
            'war Fehler `03` (`CLAUDE.md`, Hausregel 2)',
      );
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets('ohne jeden Wert verschwindet keine einzige Anzeige', (
      tester,
    ) async {
      final h = gymHuelle(tagRuheLeer());
      await zeige(tester, h.app);

      for (final key in pflichtAbschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key fehlt');
      }
      // `rotationPpl` statt `Workout.rotation`: Die Rotation ist seit
      // 19.11.2026 Push, Pull, Legs (Task 2.8, Spec 23; TEST_AENDERN=1).
      for (final workout in rotationPpl) {
        expect(
          find.byKey(kPlatz(workout)),
          findsOneWidget,
          reason:
              '${workout.label}: die Leiste steht auch ohne Plan in '
              'voller Breite da (Spec 6, Leerfall)',
        );
      }
    });

    testWidgets('der Untertitel der Karte hat in allen vier Zuständen '
        'dieselbe Höhe', (tester) async {
      double? erste;
      String? ersterFall;

      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        final hoehe = tester.getSize(find.byKey(kUntertitel)).height;
        if (erste == null) {
          erste = hoehe;
          ersterFall = fall.key;
          continue;
        }
        expect(
          hoehe,
          closeTo(erste, 0.5),
          reason:
              '${fall.key} gegen $ersterFall: Der Untertitel bekommt in '
              'allen vier Zuständen eine feste Zeilenzahl (`FesteZeilen`, '
              'Spec 5.3 und 10) — sonst rutscht alles darunter, sobald die '
              'zweite Zeile wegfällt.',
        );
      }
    });

    testWidgets('der Ruhetag behält seine Kartenhöhe, ob `next` gesetzt ist '
        'oder nicht', (tester) async {
      final mit = gymHuelle(tagRuheMitNaechstem());
      await zeige(tester, mit.app);
      final hoeheMit = tester.getSize(find.byKey(kKarte)).height;

      final ohne = gymHuelle(tagRuheLeer());
      await zeige(tester, ohne.app);

      expect(
        tester.getSize(find.byKey(kKarte)).height,
        closeTo(hoeheMit, 0.5),
        reason:
            'Fällt die Zeile „Nächstes Krafttraining: …" weg, darf die '
            'Karte nicht schrumpfen (Spec 5.3)',
      );
    });

    testWidgets('`0` ist keine Antwort auf „kein Wert"', (tester) async {
      final faelle = {
        'leer': tagRuheLeer(),
        'leer und ladend': tagRuheLeer(laedt: true),
        'nachzügler': tagRuheMitNachzuegler(),
      };

      for (final fall in faelle.entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(
          find.byKey(kWoche),
          findsOneWidget,
          reason: '${fall.key}: Vorbedingung — der Schirm steht überhaupt da',
        );
        final texte = flach(alleTexte(tester));
        expect(
          texte,
          isNot(matches(nullAlsWert)),
          reason:
              '${fall.key}: Eine Null behauptet „nichts getan" — das ist '
              '`01` in neuer Verpackung (`CLAUDE.md`)',
        );
        expect(
          texte,
          isNot(contains(ohneWert)),
          reason:
              '${fall.key}: „–/–" hieße „gelesen, kein Wert". Auf diesem '
              'Schirm gibt es keinen Lauf, der leer ausgehen könnte '
              '(Spec 9.3).',
        );
      }
    });

    testWidgets('auch ohne jede Zahl steht kein grauer Hinweis am Fuß — er '
        'ist ganz entfallen (Spec 26 Nr. 3)', (tester) async {
      for (final laedt in [true, false]) {
        final h = gymHuelle(tagRuheLeer(laedt: laedt));
        await zeige(tester, h.app);

        expect(
          find.byKey(kHinweis),
          findsNothing,
          reason:
              'laedt: $laedt — der Fuß „Die Gewichte sind Vorschläge …" '
              'existiert nicht mehr [Tim, 19.11.2026]',
        );
      }
    });
  });

  group('Der Vorlesetext nennt den Zustand, nicht das Zeichen', () {
    // „Pull, offen" statt „Gym B, offen": Gym B ist seit 19.11.2026 nicht
    // mehr in der Woche (Task 2.8, Spec 23; TEST_AENDERN=1).
    testWidgets('eine Kachel der Wochenleiste liest sich als „Pull, '
        'offen"', (tester) async {
      final tag = tagGeplant();
      final platz = tag.tag.week.firstWhere(
        (slot) => slot.workout == Workout.pull,
      );
      final erwartet = gymWochenVorlesetext(platz);

      final h = gymHuelle(tag);
      await zeige(tester, h.app);

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(erwartet))),
        findsAtLeastNWidgets(1),
        reason:
            '„$erwartet" — nicht „B Strich offen" (`CLAUDE.md`, '
            'Spec 10). Der Wochentag steht bewusst nicht darin.',
      );
    });

    testWidgets('„Trainierte Muskeln" liest sich ohne Ankündigung vor — nur '
        'der Titel und der beschreibende Untertitel (Spec 26 Nr. 4)', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      // Stand auf „folgt in einer späteren Aufgabe", bis Tim die
      // Ankündigung gestrichen hat [19.11.2026, Spec 26 Nr. 4].
      expect(
        find.descendant(
          of: find.byKey(kZeileMuskeln),
          matching: find.bySemanticsLabel(ankuendigung),
        ),
        findsNothing,
        reason: 'keine Ankündigung im Vorlesetext der Zeile',
      );
      expect(
        find.descendant(
          of: find.byKey(kZeileMuskeln),
          matching: find.bySemanticsLabel(RegExp('zu kurz kommen')),
        ),
        findsAtLeastNWidgets(1),
        reason: 'der Untertitel wird weiter vorgelesen',
      );
    });

    testWidgets('kein Zeichen steht je in einem Vorlesetext', (tester) async {
      for (final fall in [tagRuheLeer(), tagRuheLeer(laedt: true)]) {
        final h = gymHuelle(fall);
        await zeige(tester, h.app);

        expect(
          find.byKey(kWoche),
          findsOneWidget,
          reason: 'Vorbedingung: die Leiste steht da',
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(ohneWert))),
          findsNothing,
          reason: 'VoiceOver läse „Strich Schrägstrich Strich" vor',
        );
      }
    });
  });
}
