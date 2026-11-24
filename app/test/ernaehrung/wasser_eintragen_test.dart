import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/wasser_repository.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/wasser_provider.dart';
import 'package:repit/health/health_types.dart';

import 'health_schreiben_attrappe.dart';
import 'tag_huelle.dart';

/// Tests für **#311 — Wasser eintragen**: die Knöpfe auf dem Tag-Schirm,
/// Ändern und Löschen, und die Kopie nach Apple Health.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Tabelle und
/// Migration: `test/data/schema_v16_test.dart`; Repository:
/// `test/data/wasser_repository_test.dart`.
///
/// ## Was verlangt wird (Ticket, Spec „Wasser", Entwurf `WASSER`)
///
/// - Die Wasserzeile hat **zwei Knöpfe, die eintragen**: `+ 250 ml` und
///   `+ 500 ml`. Der Satz „lässt sich noch nicht eintragen" ist weg.
/// - Eingetragenes Wasser **überlebt einen Neustart** (Repository-Test),
///   **steht in Apple Health** und **zählt im Ring nicht doppelt**: Es ist
///   keine Mahlzeit, ändert keine Mahlzeitenzeile und keine Kalorie.
/// - Die Zeile zeigt die Summe aus eingetragenem Wasser **und** dem Wasser
///   in gebuchten Lebensmitteln (`Naehrwerte.wasserMl`), gegen das
///   Wasserziel (seit #408: 35 ml je kg Körpergewicht, ohne Gewicht 2 l).
/// - **Ändern und Löschen** gehen über `WasserNotifier`; die Kopie in
///   Health wird ersetzt bzw. gelöscht.
///
/// ## Apple Health — der Weg, festgelegt vom Test-Agenten
///
/// Seit #283 schreibt die App `dietaryWater`, wenn ein gebuchtes
/// Lebensmittel Wasser trägt (`HealthNutrition.fields` in
/// `HealthNutritionWriting.swift`). **Das ist gewollt:** Die Spec sagt
/// „Wasser … wird geschrieben und gelesen wie eine Mahlzeit, mit demselben
/// Quellenfilter", der Schreibkatalog enthält Wasser ausdrücklich, und #311
/// verlangt „Schreiben nach Apple Health mit demselben Quellenfilter wie
/// Mahlzeiten". Ein eingetragenes Glas geht deshalb **denselben Kanal**:
///
/// ```dart
/// health.writeMeal(
///   werte: Naehrwerte(wasserMl: mengeMl), // nur Wasser, sonst nichts
///   name: 'Wasser',
///   at: eintrag.zeitpunkt,
/// );
/// ```
///
/// Keine neue Kanalmethode, kein neuer Freigabedialog: `writeMeal` schreibt
/// nur die vorhandenen Werte — hier also genau eine `dietaryWater`-Probe —,
/// und die eigene Probe wird beim Lesen an der Quelle erkannt und
/// übersprungen. Gelöscht wird über `deleteMeal(kennung)`.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/ernaehrung/wasser_provider.dart`:
///
/// ```dart
/// /// Das Wasser eines Tages — Tims eigene Daten, also kein `Messwert`.
/// final wasserProvider = AsyncNotifierProvider.family<
///     WasserNotifier, List<WasserEintrag>, String>(WasserNotifier.new);
///
/// class WasserNotifier extends AsyncNotifier<List<WasserEintrag>> {
///   WasserNotifier(this.tagesSchluessel);
///   final String tagesSchluessel;
///
///   /// Trägt [mengeMl] auf **diesen** Tag ein, zur Uhrzeit des Trackens
///   /// (#328): heute jetzt, an einem geblätterten Tag dieselbe Wanduhrzeit
///   /// auf jenem Tag. Danach die Kopie nach Health — **gebucht wird
///   /// immer**, auch ohne Freigabe.
///   Future<void> trageEin(double mengeMl);
///
///   /// Setzt die Menge neu; die alte Kopie in Health wird gelöscht, eine
///   /// neue geschrieben.
///   Future<void> aendere(WasserEintrag eintrag, double mengeMl);
///
///   /// Nimmt den Eintrag weg und löscht seine Kopie in Health. Scheitert
///   /// das Löschen dort, ist das kein Fehler für Tim (Spec, „Löschen").
///   Future<void> loesche(WasserEintrag eintrag);
/// }
/// ```
///
/// Die Knöpfe tragen `Key('wasser-plus-250')` und `Key('wasser-plus-500')`.
///
/// ## Was hier **nicht** verlangt wird — Fragen an Tim
///
/// - **„Menge …"** — der dritte Knopf des Entwurfs. Wie die Eingabe
///   aussieht (Blatt, Rad, Feld), zeichnet das Board nicht. Nach `CLAUDE.md`
///   wird das vorher entworfen, nicht beim Bauen entschieden.
/// - **Wo Tim ein eingetragenes Glas ändert oder löscht.** Das Board
///   zeichnet keinen Weg dorthin; die Funktionen stehen deshalb hier nur
///   am Provider fest, nicht an der Oberfläche.
///
/// Alle Zahlen und Kennungen erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  Future<(TagHuelle, SchreibAttrappe)> starte(
    WidgetTester tester, {
    WriteAuthorization freigabe = WriteAuthorization.granted,
  }) async {
    final quelle = SchreibAttrappe(freigabe: freigabe);
    final h = tagHuelle(jetzt: jetzt, quelle: quelle);
    await zeigeTag(tester, h.app);
    return (h, quelle);
  }

  WasserNotifier wasser(TagHuelle h, String tag) {
    h.container.listen(wasserProvider(tag), (_, _) {});
    return h.container.read(wasserProvider(tag).notifier);
  }

  Future<List<WasserEintrag>> gespeichert(TagHuelle h, String tag) =>
      WasserRepository(h.db).wasserAmTag(tag);

  String wasserzeile(WidgetTester tester) =>
      texteUnter(tester, const Key('ernaehrung-wasser')).toLowerCase();

  Future<void> tippe(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Die Knöpfe auf dem Tag-Schirm (#311)', () {
    testWidgets('der Satz „lässt sich noch nicht eintragen" ist weg, die '
        'zwei Knöpfe sind da und antippbar', (tester) async {
      await starte(tester);

      expect(wasserzeile(tester), isNot(contains('noch nicht')));
      for (final key in const [
        Key('wasser-plus-250'),
        Key('wasser-plus-500'),
      ]) {
        final knopf = find.descendant(
          of: find.byKey(const Key('ernaehrung-wasser')),
          matching: find.byKey(key),
        );
        expect(knopf, findsOneWidget, reason: '$key steht in der Wasserzeile');
        final text = find
            .descendant(of: knopf, matching: find.byType(RichText))
            .evaluate();
        expect(text, isNotEmpty, reason: '$key trägt eine Beschriftung');
        expect(
          tippbar(text.first),
          isTrue,
          reason: 'drei Knöpfe, die nichts tun, wären schlimmer als keine',
        );
      }
    });

    testWidgets('+ 500 ml trägt 500 ml auf heute ein, und die Zeile zeigt '
        'sie sofort', (tester) async {
      final (h, _) = await starte(tester);

      await tippe(tester, const Key('wasser-plus-500'));

      final heuteGespeichert = await gespeichert(h, heute);
      expect(heuteGespeichert.map((e) => e.mengeMl), [500]);
      expect(heuteGespeichert.single.zeitpunkt, jetzt);
      expect(wasserzeile(tester), contains('0,5'));
    });

    testWidgets('+ 250 ml zweimal und + 500 ml: drei Einträge, die Zeile '
        'zeigt die Summe', (tester) async {
      final (h, _) = await starte(tester);

      await tippe(tester, const Key('wasser-plus-250'));
      await tippe(tester, const Key('wasser-plus-250'));
      await tippe(tester, const Key('wasser-plus-500'));

      expect(
        (await gespeichert(h, heute)).map((e) => e.mengeMl).toList()..sort(),
        [250, 250, 500],
      );
      // 1000 ml sind „1", nicht „1,0": keine nachgehängte Null (#408,
      // Tims Meldung vom 07.11.2026).
      expect(wasserzeile(tester), contains('1 von'));
    });

    testWidgets('die Summe zählt das Wasser in gebuchten Lebensmitteln mit', (
      tester,
    ) async {
      final (h, _) = await starte(tester);
      await ErnaehrungRepository(h.db).buche(
        Eintrag(
          tagesSchluessel: heute,
          mahlzeit: Mahlzeit.mittag,
          zeitpunkt: jetzt,
          name: 'Prüfsuppe',
          mengeG: 250,
          naehrwerte: const Naehrwerte(kcal: 100, wasserMl: 200),
        ),
      );
      await h.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();
      await tester.pumpAndSettle();

      await tippe(tester, const Key('wasser-plus-500'));

      expect(wasserzeile(tester), contains('0,7'));
    });

    testWidgets('auf einem geblätterten Tag landet das Glas auf diesem Tag, '
        'zur Uhrzeit des Trackens', (tester) async {
      final (h, _) = await starte(tester);
      await tippe(tester, const Key('ernaehrung-zurueck'));

      await tippe(tester, const Key('wasser-plus-250'));

      expect(await gespeichert(h, heute), isEmpty);
      final e = (await gespeichert(h, gestern)).single;
      expect(BerlinCalendar.dayKey(e.zeitpunkt), gestern);
      expect(
        BerlinCalendar.wallClock(e.zeitpunkt),
        BerlinCalendar.wallClock(jetzt),
        reason: 'die Uhrzeit des Trackens (#328), auf dem offenen Tag',
      );
    });
  });

  group('Wasser ist keine Mahlzeit — der Ring zählt nichts doppelt (#311)', () {
    testWidgets('nach einem Glas sind alle vier Mahlzeiten weiter leer und '
        'die Kalorien unverändert', (tester) async {
      final (h, _) = await starte(tester);
      final vorher = h.container.read(ernaehrungsTagProvider(heute));

      await tippe(tester, const Key('wasser-plus-500'));

      final nachher = h.container.read(ernaehrungsTagProvider(heute));
      expect(nachher.mahlzeiten.every((z) => z.leer), isTrue);
      expect(gegessenWerte(nachher)?.kcal, gegessenWerte(vorher)?.kcal);
      expect(gegessenWerte(nachher)?.eiweissG, gegessenWerte(vorher)?.eiweissG);
    });
  });

  group('Die Kopie in Apple Health (#311)', () {
    testWidgets('ein Glas wird als reine Wasserprobe geschrieben — nichts '
        'sonst', (tester) async {
      final (h, quelle) = await starte(tester);

      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();

      expect(quelle.geschrieben, hasLength(1));
      final kopie = quelle.geschrieben.single;
      expect(kopie.werte, const Naehrwerte(wasserMl: 250));
      expect(kopie.werte.kcal, isNull, reason: 'kein 0-kcal-Eintrag in Health');
      expect(kopie.name, 'Wasser');
      expect(kopie.at, jetzt);

      final e = (await gespeichert(h, heute)).single;
      expect(e.healthStand, HealthStand.geschrieben);
      expect(e.healthUuid, kopie.id);
    });

    testWidgets('ohne Freigabe wird trotzdem eingetragen — der Eintrag '
        'bleibt offen', (tester) async {
      final (h, quelle) = await starte(
        tester,
        freigabe: WriteAuthorization.denied,
      );

      await wasser(h, heute).trageEin(500);
      await tester.pumpAndSettle();

      expect(quelle.geschrieben, isEmpty);
      final e = (await gespeichert(h, heute)).single;
      expect(e.mengeMl, 500);
      expect(e.healthStand, HealthStand.offen);
      expect(e.healthUuid, isNull);
    });

    testWidgets('kommt die Freigabe später, nimmt das nächste Glas die '
        'offenen mit', (tester) async {
      final (h, quelle) = await starte(
        tester,
        freigabe: WriteAuthorization.denied,
      );
      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();

      quelle.freigabe = WriteAuthorization.granted;
      await wasser(h, heute).trageEin(500);
      await tester.pumpAndSettle();

      expect(quelle.geschrieben.map((k) => k.werte.wasserMl), [
        250,
        500,
      ], reason: 'das ältere offene Glas zuerst');
      for (final e in await gespeichert(h, heute)) {
        expect(e.healthStand, HealthStand.geschrieben, reason: '${e.mengeMl}');
      }
    });

    testWidgets('lehnt HealthKit ab, steht der Eintrag auf „nicht möglich" '
        'und wird nicht endlos neu versucht', (tester) async {
      final (h, quelle) = await starte(tester);
      quelle.schreibFehlerFuer['Wasser'] = HealthWriteRejected('erfunden');

      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();
      expect(
        (await gespeichert(h, heute)).single.healthStand,
        HealthStand.nichtMoeglich,
      );
      final versucheNachErstem = quelle.schreibVersuche.length;

      quelle.schreibFehlerFuer.clear();
      await wasser(h, heute).trageEin(500);
      await tester.pumpAndSettle();
      expect(
        quelle.schreibVersuche.length,
        versucheNachErstem + 1,
        reason:
            'nur das neue Glas wird geschrieben, das abgelehnte nicht '
            'noch einmal',
      );
    });
  });

  group('Ändern und Löschen (#311)', () {
    testWidgets('Ändern setzt die Menge und ersetzt die Kopie in Health', (
      tester,
    ) async {
      final (h, quelle) = await starte(tester);
      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();
      final alt = (await gespeichert(h, heute)).single;
      final alteKopie = alt.healthUuid!;

      await wasser(h, heute).aendere(alt, 400);
      await tester.pumpAndSettle();

      final neu = (await gespeichert(h, heute)).single;
      expect(neu.id, alt.id, reason: 'dieselbe Zeile, kein zweites Glas');
      expect(neu.mengeMl, 400);
      expect(quelle.loeschVersuche, contains(alteKopie));
      expect(quelle.geschrieben.last.werte.wasserMl, 400);
      expect(neu.healthUuid, quelle.geschrieben.last.id);
      expect(neu.healthStand, HealthStand.geschrieben);
      expect(wasserzeile(tester), contains('0,4'));
    });

    testWidgets('Löschen nimmt den Eintrag weg und löscht seine Kopie', (
      tester,
    ) async {
      final (h, quelle) = await starte(tester);
      await wasser(h, heute).trageEin(250);
      await wasser(h, heute).trageEin(500);
      await tester.pumpAndSettle();
      final weg = (await gespeichert(
        h,
        heute,
      )).firstWhere((e) => e.mengeMl == 250);

      await wasser(h, heute).loesche(weg);
      await tester.pumpAndSettle();

      expect((await gespeichert(h, heute)).map((e) => e.mengeMl), [500]);
      expect(quelle.loeschVersuche, [weg.healthUuid]);
      expect(wasserzeile(tester), contains('0,5'));
    });

    testWidgets('scheitert das Löschen in Health, ist der Eintrag trotzdem '
        'weg — und nichts wirft', (tester) async {
      final (h, quelle) = await starte(tester);
      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();
      quelle.loeschFehler = StateError('Probe in Health schon gelöscht');

      await wasser(h, heute).loesche((await gespeichert(h, heute)).single);
      await tester.pumpAndSettle();

      expect(await gespeichert(h, heute), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ein Glas ohne Kopie wird gelöscht, ohne Health zu fragen', (
      tester,
    ) async {
      final (h, quelle) = await starte(
        tester,
        freigabe: WriteAuthorization.denied,
      );
      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();

      await wasser(h, heute).loesche((await gespeichert(h, heute)).single);
      await tester.pumpAndSettle();

      expect(await gespeichert(h, heute), isEmpty);
      expect(quelle.loeschVersuche, isEmpty);
    });

    testWidgets('der Provider zeigt den Stand ohne Neustart', (tester) async {
      final (h, _) = await starte(tester);
      await wasser(h, heute).trageEin(250);
      await tester.pumpAndSettle();

      final liste = h.container.read(wasserProvider(heute)).value;
      expect(liste?.map((e) => e.mengeMl), [250]);
    });
  });
}
