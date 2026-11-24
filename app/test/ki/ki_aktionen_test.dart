// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/ki/ki_aktionen.dart';

import '../ernaehrung/health_schreiben_attrappe.dart';

/// Tests für **`KiAktionen.fuehreAus`** — Task 10 des Plans
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md` (Karte #341), Spec
/// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitte
/// „Die Aktionsliste (#330)", „Foto-Schätzung als erste Aktion" (Schritt 6)
/// und „Datenschicht — Schema 14 → 15" (`eintraege.vorschlag`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, wird das **gemeldet, nicht
/// korrigiert**. Geschrieben ohne `lib/ki/ki_aktionen.dart` gesehen zu
/// haben — es gab die Datei beim Schreiben noch nicht.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// In `lib/ki/ki_aktionen.dart`:
///
/// ```dart
/// /// Der **einzige** Ausführer eines `KiVorschlag`s. Ein `Notifier`, kein
/// /// `Provider` mit gehaltenem `Ref` (`CLAUDE.md`, Hausregel 3).
/// final kiAktionenProvider =
///     NotifierProvider<KiAktionen, void>(KiAktionen.new);
///
/// class KiAktionen extends Notifier<void> {
///   @override
///   void build() {}
///   Future<void> fuehreAus(KiVorschlag vorschlag);
/// }
/// ```
///
/// In `lib/data/ernaehrung_repository.dart`: ein Feld **`Eintrag.vorschlag`**
/// (Plan, Task 10, „Modify"), das für einen KI-Eintrag nicht `null` und
/// für einen von Hand gebuchten `null` ist. Den Typ legt diese Datei nicht
/// fest; die Spalte `eintraege.vorschlag` wird direkt gelesen.
///
/// Was der Ausführer tut, für `EintraegeBuchen`:
///
/// - **je übernommener Posten genau ein Eintrag** über
///   `ErnaehrungRepository.buche`, mit `eintraege.vorschlag =
///   jsonEncode(herkunft.alsJson())`;
/// - Name, Menge (`gramm`) und die Nährwerte des Postens werden
///   eingefroren, `null` bleibt `null` — nie `0`;
/// - Tag, Mahlzeit und Uhrzeit kommen aus der Aktion, nicht aus der Uhr
///   und nicht aus dem Antwortzeitpunkt der Herkunft;
/// - die Kopie nach Apple Health läuft **über denselben Weg wie jedes
///   Buchen** — den Nachlauf in `ErfassenNotifier` (#283). Erkennbar
///   daran, dass mit Freigabe auch ältere `offen`e Einträge mitgenommen
///   werden und ohne Freigabe `healthSchreibHinweisProvider` anschlägt;
/// - danach steht der Tag in `eigeneEintraegeProvider` neu da;
/// - `ki_anfragen` bleibt unberührt — protokolliert wird die Antwort
///   (`KiRepository.protokolliere`, Sache des Schätzungs-Providers), nicht
///   das Buchen.
///
/// Und als Wächter: Außer `lib/ki/ki_aktionen.dart` selbst ruft nur das
/// Prüfblatt (`lib/ernaehrung/ki_pruefblatt*.dart`) `fuehreAus` auf
/// (Spec: „aufgerufen nur vom Knopf im Prüfblatt. Kein anderer
/// Aufrufer."). Dieser Fall ist von Anfang an grün — er prüft eine
/// Behauptung über den Code, kein noch zu bauendes Verhalten.
///
/// ## Eigene Festlegungen — **nicht von Tim freigegeben**
///
/// Vom Test-Agenten getroffen, wo Plan und Spec schweigen. Wer anderer
/// Meinung ist, meldet es; Tim entscheidet.
///
/// 1. **`fuehreAus` bucht `uebernommen(aktion.posten)`, nicht blind
///    `aktion.posten`.** Der Zustand `Vorschlag(KiVorschlag, geaendert)`
///    hält alle Posten, auch die unsicheren, die das Prüfblatt nicht
///    übernommen zeigt; der Knopf führt genau diesen Vorschlag aus. Filtert
///    der Ausführer selbst, ist es gleich, ob der Aufrufer vorher gefiltert
///    hat (`uebernommen` ist idempotent) — und ein unsicherer, unberührter
///    Posten ohne Menge kann auf keinem Weg gebucht werden. Daraus folgt:
///    **Ein Posten ohne Menge wird nicht gebucht**, denn ohne `gramm` ist
///    er unsicher (Review Focus 4), solange Tim ihn nicht anfasst. **Ein
///    unsicherer Posten mit Menge wird seit #407 gebucht** (Tims Meldung
///    vom 07.11.2026: Er musste erst die Menge anfassen, um ihn buchen zu
///    können) — bis dahin hielt diese Datei das Gegenteil fest.
/// 2. **Ohne Freigabe schlägt der Hinweis an**, wie beim Buchungsblatt:
///    Tim hat gerade selbst getippt, er ist „wer gerade selbst bucht"
///    (`ErfassenNotifier._kopiereNachHealth`, `hinweis: true`).
/// 3. **Ein Vorschlag ohne übernommene Posten bucht nichts, wirft nicht
///    und fragt Health nicht.** Das Prüfblatt sperrt den Knopf dann ohnehin.
///    Seit #407 heißt das: nur Posten ohne Menge, die Tim nicht berührt hat.
/// 4. **Eine gescheiterte Kopie nach Health wirft nicht aus `fuehreAus`**
///    — gebucht ist gebucht, wie in `ErfassenNotifier`.
///
/// ## Offene Punkte
///
/// - Die Spec schreibt `KiAktionen.fuehreAus(vorschlag, bestaetigt)`, der
///   Plan `fuehreAus(KiVorschlag)`. Diese Datei folgt dem Plan; was
///   `bestaetigt` sein sollte, sagt die Spec nicht.
/// - **`==`/`hashCode` auf `KiVorschlag` und `KiHerkunft`** verlangt der
///   Plan nicht (nur auf `SchaetzPosten`), und hier wird es nicht geprüft.
///   Hält der Zustand `Vorschlag(KiVorschlag, geaendert)` einen
///   `KiVorschlag` ohne Wertgleichheit, meldet jede Zuweisung eine
///   Änderung — ob das stört, entscheidet sich am Schätzungs-Provider.
/// - Ob die N Einträge in **einer** Transaktion landen (alles oder nichts),
///   legt weder Plan noch Spec fest; hier nicht geprüft.
///
/// Zahlen, Namen und Daten in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2) — die Uhr.
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  // Gebucht wird auf den Abend **davor** — nicht auf heute.
  const tag = '2026-07-13';
  final essenszeit = DateTime.utc(2026, 7, 13, 17, 45); // 19:45 Berlin

  // Die Antwort kam heute; ihr Zeitpunkt ist Herkunft, nicht Essenszeit.
  final herkunft = KiHerkunft(
    anbieter: 'gemini',
    modell: 'testmodell-flash',
    zeitpunkt: DateTime.utc(2026, 7, 14, 9, 58, 30),
    zweck: 'foto',
  );

  // ── Posten ────────────────────────────────────────────────────────────

  /// Sicher, unberührt — wird gebucht. Zucker, Ballaststoffe, gesättigte
  /// Fette und Wasser fehlen und müssen fehlen bleiben.
  const huhn = SchaetzPosten(
    name: 'Hähnchenbrust',
    gramm: 140,
    werte: Naehrwerte(kcal: 231, eiweissG: 43.4, kohlenhydrateG: 0, fettG: 5.0),
    sicher: true,
    herkunft: PostenHerkunft.erkannt,
  );

  /// Sicher, unberührt — wird gebucht.
  const reis = SchaetzPosten(
    name: 'Reis gekocht',
    gramm: 180,
    werte: Naehrwerte(
      kcal: 234,
      eiweissG: 4.9,
      kohlenhydrateG: 51.5,
      fettG: 0.5,
      ballaststoffeG: 0.7,
    ),
    sicher: true,
    herkunft: PostenHerkunft.erkannt,
  );

  /// Unsicher (Fett fehlt), aber von Tim angefasst — wird gebucht, und
  /// das fehlende Fett bleibt `null`.
  const brokkoli = SchaetzPosten(
    name: 'Brokkoli',
    gramm: 120,
    werte: Naehrwerte(kcal: 41, eiweissG: 3.4, kohlenhydrateG: 8.0),
    sicher: false,
    herkunft: PostenHerkunft.vonDir,
  );

  /// Ohne Menge, unberührt — unsicher, wird **nicht** gebucht.
  const sauce = SchaetzPosten(
    name: 'Sauce',
    gramm: null,
    werte: Naehrwerte(kcal: 80, eiweissG: 1, kohlenhydrateG: 6, fettG: 6),
    sicher: false,
    herkunft: PostenHerkunft.erkannt,
  );

  /// Unplausibel, unberührt, aber mit Menge — wird seit #407 gebucht
  /// (Tims Meldung vom 07.11.2026) und bleibt unsicher.
  const dressing = SchaetzPosten(
    name: 'Dressing',
    gramm: 30,
    werte: Naehrwerte(kcal: 400, eiweissG: 0, kohlenhydrateG: 0, fettG: 0),
    sicher: false,
    herkunft: PostenHerkunft.erkannt,
  );

  KiVorschlag vorschlag(List<SchaetzPosten> posten) => KiVorschlag(
    aktion: EintraegeBuchen(
      posten: posten,
      mahlzeit: Mahlzeit.abend,
      tagesSchluessel: tag,
      zeitpunkt: essenszeit,
    ),
    herkunft: herkunft,
  );

  final teller = [huhn, sauce, reis, dressing, brokkoli];
  const gebucht = {'Hähnchenbrust', 'Reis gekocht', 'Dressing', 'Brokkoli'};

  // ── Behälter ──────────────────────────────────────────────────────────

  late SchreibAttrappe health;
  late AppCache db;
  late ProviderContainer container;
  late ErnaehrungRepository repo;

  setUp(() {
    health = SchreibAttrappe();
    db = AppCache(NativeDatabase.memory());
    repo = ErnaehrungRepository(db);
    container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(health),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> fuehreAus(KiVorschlag v) =>
      container.read(kiAktionenProvider.notifier).fuehreAus(v);

  /// Alle Zeilen, über **alle** Tage — ein Eintrag auf dem falschen Tag
  /// soll hier nicht unsichtbar werden.
  Future<List<EintragRow>> alleZeilen() => db.select(db.eintraege).get();

  Future<EintragRow> zeile(String name) async =>
      (await alleZeilen()).singleWhere((z) => z.name == name);

  Future<Eintrag> eintrag(String name) async =>
      (await repo.eintraegeAmTag(tag)).singleWhere((e) => e.name == name);

  // ═════════════════════════════════════════════════════════════════════
  group('Gebucht wird erst auf den Tipp', () {
    test(
      'einen Vorschlag zu bauen und den Ausführer zu holen bucht nichts',
      () async {
        vorschlag(teller);
        container.read(kiAktionenProvider.notifier);
        await pumpEventQueue();

        expect(await alleZeilen(), isEmpty);
        expect(health.anfragen, 0);
        expect(health.schreibVersuche, isEmpty);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Je übernommener Posten genau ein Eintrag', () {
    test('vier übernommene von fünf Posten → genau vier Zeilen', () async {
      await fuehreAus(vorschlag(teller));

      final zeilen = await alleZeilen();
      expect(zeilen, hasLength(4));
      expect(zeilen.map((z) => z.name).toSet(), gebucht);
    });

    test('ein unsicherer, unberührter Posten ohne Menge wird nicht gebucht '
        '— der unplausible mit Menge schon (#407)', () async {
      await fuehreAus(vorschlag(teller));

      final namen = (await alleZeilen()).map((z) => z.name);
      expect(namen, isNot(contains('Sauce')));
      expect(
        namen,
        contains('Dressing'),
        reason: 'Tims Meldung vom 07.11.2026: unsicher mit Menge ist gebucht',
      );
    });

    test('ein Posten ohne Menge wird nicht gebucht — und keine Zeile steht '
        'mit fehlender Menge da', () async {
      await fuehreAus(vorschlag([sauce, huhn]));

      final zeilen = await alleZeilen();
      expect(zeilen.map((z) => z.name), ['Hähnchenbrust']);
      expect(zeilen.single.mengeG, isNotNull);
    });

    test(
      'ein bereits gefilterter Vorschlag bucht dasselbe wie der volle',
      () async {
        await fuehreAus(vorschlag(uebernommen(teller)));

        final zeilen = await alleZeilen();
        expect(zeilen, hasLength(4));
        expect(zeilen.map((z) => z.name).toSet(), gebucht);
      },
    );

    test('ein Vorschlag ohne übernommene Posten bucht nichts, wirft nicht '
        'und fragt Health nicht', () async {
      await fuehreAus(vorschlag([sauce]));

      expect(await alleZeilen(), isEmpty);
      expect(health.anfragen, 0);
      expect(health.schreibVersuche, isEmpty);
    });

    test('jede Zeile trägt vorschlag = herkunft.alsJson(), als JSON', () async {
      await fuehreAus(vorschlag(teller));

      for (final z in await alleZeilen()) {
        final text = z.vorschlag;
        expect(text, isNotNull, reason: z.name);
        expect(jsonDecode(text!), herkunft.alsJson(), reason: z.name);
      }
    });

    test('die Herkunft nennt Anbieter, Modell, Antwortzeitpunkt in UTC und '
        'Zweck', () async {
      await fuehreAus(vorschlag([huhn]));

      final json = jsonDecode(
        (await zeile('Hähnchenbrust')).vorschlag!,
      ) as Map<String, Object?>;
      expect(json, {
        'anbieter': 'gemini',
        'modell': 'testmodell-flash',
        'zeitpunkt': '2026-07-14T09:58:30.000Z',
        'zweck': 'foto',
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Was im Eintrag steht', () {
    test('Name, Menge und die eingefrorenen Nährwerte wie im Posten, ohne '
        'Vorlage', () async {
      await fuehreAus(vorschlag(teller));

      for (final p in [huhn, reis, dressing, brokkoli]) {
        final e = await eintrag(p.name);
        expect(e.mengeG, p.gramm, reason: p.name);
        expect(e.naehrwerte, p.werte, reason: p.name);
        expect(e.lebensmittelId, isNull, reason: p.name);
      }
    });

    test(
      'fehlende Werte bleiben null, nie 0 — auch ein fehlendes Fett',
      () async {
        await fuehreAus(vorschlag(teller));

        final b = await zeile('Brokkoli');
        expect(b.fettG, isNull);
        expect(b.zuckerG, isNull);
        expect(b.ballaststoffeG, isNull);
        expect(b.gesaettigtG, isNull);
        expect(b.wasserMl, isNull);

        final h = await zeile('Hähnchenbrust');
        expect(h.zuckerG, isNull);
        expect(h.ballaststoffeG, isNull);
        expect(h.gesaettigtG, isNull);
        expect(h.wasserMl, isNull);
        // Eine geschätzte 0 bleibt 0 — sie ist eine Angabe.
        expect(h.kohlenhydrateG, 0);
      },
    );

    test('Tag, Mahlzeit und Uhrzeit wie übergeben — nicht heute, nicht der '
        'Antwortzeitpunkt', () async {
      await fuehreAus(vorschlag(teller));

      for (final z in await alleZeilen()) {
        expect(z.tagesSchluessel, tag, reason: z.name);
        expect(z.mahlzeit, Mahlzeit.abend.name, reason: z.name);
        expect(
          z.zeitpunkt.isAtSameMomentAs(essenszeit),
          isTrue,
          reason: z.name,
        );
      }
      expect(await repo.eintraegeAmTag('2026-07-14'), isEmpty);
    });

    test('der Eintrag kennt seine Herkunft, ein von Hand gebuchter nicht '
        '(Grundlage des Abzeichens „KI-Schätzung")', () async {
      await repo.buche(
        Eintrag(
          tagesSchluessel: tag,
          mahlzeit: Mahlzeit.mittag,
          zeitpunkt: DateTime.utc(2026, 7, 13, 11),
          name: 'Apfel',
          mengeG: 150,
          naehrwerte: const Naehrwerte(kcal: 78),
        ),
      );

      await fuehreAus(vorschlag(teller));

      expect((await eintrag('Apfel')).vorschlag, isNull);
      for (final name in gebucht) {
        expect((await eintrag(name)).vorschlag, isNotNull, reason: name);
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Kopie nach Health läuft über denselben Weg wie jedes Buchen', () {
    test('mit Freigabe: je Eintrag eine Mahlzeit, Kennung am Eintrag, '
        'Stand geschrieben', () async {
      await fuehreAus(vorschlag(teller));

      expect(health.geschrieben, hasLength(4));
      expect(health.geschrieben.map((k) => k.name).toSet(), gebucht);
      for (final name in gebucht) {
        final e = await eintrag(name);
        final kopie = health.geschrieben.singleWhere((k) => k.name == name);
        expect(e.healthStand, HealthStand.geschrieben, reason: name);
        expect(e.healthUuid, kopie.id, reason: name);
        expect(kopie.werte, e.naehrwerte, reason: name);
        expect(kopie.at.isAtSameMomentAs(essenszeit), isTrue, reason: name);
      }
    });

    test('mit Freigabe werden ältere offene Einträge mitgenommen — wie beim '
        'Buchen über das Buchungsblatt', () async {
      await repo.buche(
        Eintrag(
          tagesSchluessel: '2026-07-12',
          mahlzeit: Mahlzeit.fruehstueck,
          zeitpunkt: DateTime.utc(2026, 7, 12, 6),
          name: 'Quark von vorgestern',
          mengeG: 250,
          naehrwerte: const Naehrwerte(kcal: 170, eiweissG: 30),
        ),
      );

      await fuehreAus(vorschlag([huhn]));

      expect(health.geschrieben.map((k) => k.name).toSet(), {
        'Hähnchenbrust',
        'Quark von vorgestern',
      });
      final alt = (await repo.eintraegeAmTag('2026-07-12')).single;
      expect(alt.healthStand, HealthStand.geschrieben);
    });

    test(
      'ohne Freigabe: trotzdem gebucht, Stand offen, der Hinweis steht',
      () async {
        health.freigabe = WriteAuthorization.denied;

        await fuehreAus(vorschlag(teller));

        expect(await alleZeilen(), hasLength(4));
        for (final name in gebucht) {
          final e = await eintrag(name);
          expect(e.healthStand, HealthStand.offen, reason: name);
          expect(e.healthUuid, isNull, reason: name);
        }
        expect(health.geschrieben, isEmpty);
        expect(container.read(healthSchreibHinweisProvider), isTrue);
      },
    );

    test('scheitert eine Kopie, bleibt das Gebuchte stehen und fuehreAus '
        'wirft nicht', () async {
      health.schreibFehlerFuer['Reis gekocht'] = Exception('erfunden');

      await fuehreAus(vorschlag(teller));

      expect(await alleZeilen(), hasLength(4));
      expect((await eintrag('Reis gekocht')).healthStand, HealthStand.offen);
      expect(
        (await eintrag('Hähnchenbrust')).healthStand,
        HealthStand.geschrieben,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Nach dem Buchen', () {
    test('der offene Tag zeigt die Einträge sofort', () async {
      final abo = container.listen(eigeneEintraegeProvider(tag), (_, _) {});
      addTearDown(abo.close);
      expect(
        await container.read(eigeneEintraegeProvider(tag).future),
        isEmpty,
      );

      await fuehreAus(vorschlag(teller));

      final liste = await container.read(eigeneEintraegeProvider(tag).future);
      expect(liste.map((e) => e.name).toSet(), gebucht);
    });

    test('Buchen ist keine Anfrage: ki_anfragen bleibt leer', () async {
      await fuehreAus(vorschlag(teller));

      expect(await db.select(db.kiAnfragen).get(), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der einzige Ausführer', () {
    test('fuehreAus wird nur vom Prüfblatt aufgerufen', () {
      final erlaubt = RegExp(
        r'^lib/(ki/ki_aktionen\.dart|ernaehrung/ki_pruefblatt[a-z_]*\.dart)$',
      );
      final fremde = <String>[];
      for (final datei in Directory('lib').listSync(recursive: true)) {
        if (datei is! File || !datei.path.endsWith('.dart')) continue;
        final pfad = datei.path.replaceAll(r'\', '/');
        if (!datei.readAsStringSync().contains('fuehreAus(')) continue;
        if (!erlaubt.hasMatch(pfad)) fremde.add(pfad);
      }
      expect(
        fremde,
        isEmpty,
        reason: 'Spec #330: „aufgerufen nur vom Knopf im Prüfblatt"',
      );
    });
  });
}
