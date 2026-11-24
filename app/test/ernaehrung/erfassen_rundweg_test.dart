import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Der **ganze Weg** des Eintragens, an einer echten Datenbank
/// durchgespielt (#285, zugeschnitten):
///
/// > Lebensmittel anlegen → in der eigenen Suche finden → Menge wählen →
/// > Mahlzeit wählen → buchen → auf dem Tag-Schirm sehen → ändern →
/// > löschen.
///
/// Ohne Barcode, ohne Open Food Facts, ohne Foto — ein Weg, aber der ganz
/// (Tim, 04.11.2026: „lass uns nichts abkürzen, ich will direkt eine
/// Methode vollständig drin haben").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// **Nachtrag #345** (Tims Entscheidung vom 04.11.2026): Ohne Suchtext
/// stehen nur gebuchte Lebensmittel da, höchstens 10
/// (`zuletzt_benutzt_test.dart`). Drei Fälle in „Das Angelegte steht
/// sofort in der Suche" und „buchen merkt die Benutzung" stützten sich auf
/// bloß angelegte Lebensmittel ohne Suchtext; sie sind vom Test-Agenten
/// von #345 so umgestellt, dass sie ihre Aussage behalten. Tim hat die
/// Änderung an dieser Datei nicht gesehen.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/ernaehrung/erfassen_provider.dart`:
///
/// ```dart
/// /// Was im Suchfeld steht.
/// final suchtextProvider =
///     NotifierProvider<SuchtextNotifier, String>(SuchtextNotifier.new);
///
/// class SuchtextNotifier extends Notifier<String> {
///   @override
///   String build() => '';
///   void setze(String text);
/// }
///
/// /// Die Treffer zum aktuellen Suchtext — ohne Eingabe die zuletzt
/// /// benutzten. **Kein `Messwert`:** Das sind Tims eigene Lebensmittel,
/// /// dort heißt leer schlicht leer.
/// final suchtrefferProvider = AsyncNotifierProvider<SuchtrefferNotifier,
///     List<LebensmittelVorlage>>(SuchtrefferNotifier.new);
///
/// class SuchtrefferNotifier
///     extends AsyncNotifier<List<LebensmittelVorlage>> {
///   @override
///   Future<List<LebensmittelVorlage>> build();   // watcht suchtextProvider
/// }
///
/// /// Der **einzige** Schreibweg des Erfassens.
/// ///
/// /// Ein `Notifier` und kein `Provider` mit gehaltenem `Ref`: `ref` darf
/// /// nur in `build` und in Notifiern benutzt werden (`CLAUDE.md`,
/// /// Hausregel 3, durchgesetzt über `riverpod_lint`).
/// final erfassenProvider =
///     NotifierProvider<ErfassenNotifier, void>(ErfassenNotifier.new);
///
/// class ErfassenNotifier extends Notifier<void> {
///   @override
///   void build() {}
///   Future<int> legeLebensmittelAn(LebensmittelVorlage vorlage);
///   Future<void> buche(BuchungsFormular formular);
///   Future<void> aendere(BuchungsFormular formular);
///   Future<void> loesche(Eintrag eintrag);
/// }
/// ```
///
/// Neu in `lib/data/ernaehrung_repository.dart`:
///
/// ```dart
/// /// Schreibt einen **bestehenden** Eintrag neu — alle Felder, auch die
/// /// eingefrorenen Nährwerte. Wirft, wenn `eintrag.id` null ist: Ein
/// /// Eintrag ohne Schlüssel ist nicht gebucht, und ihn zu „ändern" wäre
/// /// ein Programmierfehler, keine Datenlage.
/// Future<void> aktualisiere(Eintrag eintrag);
/// ```
///
/// (`buche` übernimmt eine mitgegebene `id` ausdrücklich **nicht** — das
/// steht so in `ernaehrung_repository.dart` und bleibt so. Ändern ist ein
/// eigener Weg, kein zweites Buchen.)
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Die Kopie nach Apple Health.** Gebucht wird immer; `healthStand`
///   steht danach auf `offen`, und das ist alles, was dieser Zuschnitt
///   behauptet. Der Nachlauf ist ein eigenes Ticket.
/// - **Löschen durch Streichen** in der Mahlzeitenzeile. Es ist ein
///   zweiter Eingang in dasselbe `ErfassenNotifier.loesche`, liegt in
///   `ernaehrung_view.dart` — dessen Testdatei dieser Auftrag nicht
///   anfassen darf — und braucht ein „Rückgängig", das kein Entwurf
///   beschreibt. An den Koordinator gemeldet.
/// - **Favoriten, benannte Portionen, Schnelleintrag.** Spätere Tickets.
///
/// Zahlen, Namen und Daten in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  const stammdaten = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) =>
      DailyMetrics(tag: tag, activeKcal: 600, basalKcal: 1600, weightKg: 80);

  const haferflocken = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
    ballaststoffeG: 10,
  );

  /// Ein Behälter mit **echter** Datenbank im Speicher und abgeschalteter
  /// Wiederholung (`CLAUDE.md`: sonst hängt ein erzwungener Fehler in
  /// einem nichtdeterministischen Zwischenzustand).
  ///
  /// Die Datenbank ist echt und nicht nachgebaut: Sowohl die Suche als
  /// auch die Tagesabfrage filtern in SQL, und ein nachgebautes
  /// Repository prüfte genau das nicht mehr.
  ///
  /// `fremdeMahlzeitenProvider` bleibt **ohne** Override: Sein echter
  /// Notifier antwortet mit `LeerNachLauf` und braucht den Kanal nicht —
  /// genau die Lage, in der die eigene Tabelle die ganze Wahrheit ist.
  ({ProviderContainer container, AppCache db}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(
              [tageswert(gestern), tageswert(heute)],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  /// Hält die Suchtreffer am Leben, damit „steht sofort da" etwas
  /// bedeutet. Ohne laufendes Abonnement baute jeder Lesevorgang den
  /// Notifier neu auf, und der Fall bewiese nichts.
  void abonniereTreffer(ProviderContainer container) {
    final abo = container.listen(suchtrefferProvider, (_, _) {});
    addTearDown(abo.close);
  }

  Future<List<LebensmittelVorlage>> treffer(ProviderContainer container) =>
      container.read(suchtrefferProvider.future);

  Future<List<Eintrag>> eintraegeAm(ProviderContainer container, String tag) =>
      container.read(eigeneEintraegeProvider(tag).future);

  /// Der gerechnete Tag — **nachdem** beide Hälften dastehen.
  ///
  /// `ernaehrungsTagProvider` liest die `AsyncValue` seiner beiden
  /// Abhängigkeiten synchron und fällt auf „noch nichts gelesen" zurück.
  /// Wer ihn liest, ohne vorher auf sie gewartet zu haben, bekommt einen
  /// leeren Tag — dasselbe Vorgehen wie in
  /// `ernaehrung_provider_test.dart`.
  Future<ErnaehrungsTag> tagVon(ProviderContainer container, String tag) async {
    await container.read(eigeneEintraegeProvider(tag).future);
    await container.read(fremdeMahlzeitenProvider(tag).future);
    return container.read(ernaehrungsTagProvider(tag));
  }

  Future<Naehrwerte?> summeAm(ProviderContainer container, String tag) async =>
      gegessenWerte(await tagVon(container, tag));

  const anlegenblatt = AnlegenFormular();

  // ═════════════════════════════════════════════════════════════════════
  group('Der ganze Weg', () {
    test(
      'anlegen → finden → Menge → Mahlzeit → buchen → auf dem Tag sehen',
      () async {
        final b = behaelter();
        abonniereTreffer(b.container);
        final erfassen = b.container.read(erfassenProvider.notifier);

        // 1. Lebensmittel anlegen — Name und Kalorien reichen, der Rest ist
        //    freiwillig.
        final formular = anlegenblatt.mit(
          name: 'Haferflocken kernig',
          kcal: '372',
          eiweissG: '13,5',
          kohlenhydrateG: '58,7',
          fettG: '7',
          ballaststoffeG: '10',
        );
        expect(formular.kannSichern, isTrue);
        final id = await erfassen.legeLebensmittelAn(formular.alsVorlage()!);

        // 2. In der eigenen Suche finden — ohne Neustart.
        b.container.read(suchtextProvider.notifier).setze('flocken');
        final gefunden = await treffer(b.container);
        expect(gefunden.map((l) => l.name), ['Haferflocken kernig']);
        expect(gefunden.single.id, id);

        // 3./4. Menge und Mahlzeit wählen.
        final buchung = BuchungsFormular.neu(
          vorlage: gefunden.single,
          tagesSchluessel: b.container.read(offenerTagProvider),
          jetzt: jetzt,
        ).mitMenge('250').mitMahlzeit(Mahlzeit.fruehstueck);
        expect(buchung.kannBuchen, isTrue);
        expect(buchung.naehrwerte.kcal, closeTo(930, 1e-9));

        // 5. Buchen.
        await erfassen.buche(buchung);

        // 6. Auf dem Tag-Schirm sehen.
        final eintraege = await eintraegeAm(b.container, heute);
        expect(eintraege.length, 1);
        expect(eintraege.single.name, 'Haferflocken kernig');
        expect(eintraege.single.mengeG, 250);
        expect(eintraege.single.lebensmittelId, id);

        final tag = await tagVon(b.container, heute);
        expect(gegessenWerte(tag)!.kcal, closeTo(930, 1e-9));
        final fruehstueck = tag.mahlzeiten.firstWhere(
          (z) => z.mahlzeit == Mahlzeit.fruehstueck,
        );
        expect(fruehstueck.eigene.single.name, 'Haferflocken kernig');
        expect(fruehstueck.leer, isFalse);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Das Angelegte steht sofort in der Suche', () {
    // #345: Ohne Suchtext steht ein bloß angelegtes Lebensmittel nicht
    // mehr da. Die Aussage „ohne Neustart und ohne zweites Lesen von
    // Hand" gilt jetzt für das erste Buchen: Erst das füllt „Zuletzt
    // benutzt" — und zwar sofort.
    test('ohne Neustart und ohne zweites Lesen von Hand', () async {
      final b = behaelter();
      abonniereTreffer(b.container);
      final erfassen = b.container.read(erfassenProvider.notifier);

      expect(await treffer(b.container), isEmpty);

      final id = await erfassen.legeLebensmittelAn(
        const LebensmittelVorlage(name: 'Skyr Natur', je100g: haferflocken),
      );
      expect(
        await treffer(b.container),
        isEmpty,
        reason: 'angelegt ist nicht gebucht (#345)',
      );

      await erfassen.buche(
        BuchungsFormular.neu(
          vorlage: (await b.container
              .read(lebensmittelRepositoryProvider)
              .lies(id))!,
          tagesSchluessel: heute,
          jetzt: jetzt,
        ),
      );

      expect((await treffer(b.container)).map((l) => l.name), ['Skyr Natur']);
    });

    test('auch wenn im Suchfeld schon etwas steht', () async {
      final b = behaelter();
      abonniereTreffer(b.container);
      b.container.read(suchtextProvider.notifier).setze('Skyr');
      expect(await treffer(b.container), isEmpty);

      await b.container
          .read(erfassenProvider.notifier)
          .legeLebensmittelAn(
            const LebensmittelVorlage(name: 'Skyr Natur', je100g: haferflocken),
          );

      expect((await treffer(b.container)).length, 1);
    });

    // #345: Bis dahin „… und ohne Eingabe steht alles da".
    test(
      'der Suchtext filtert — und ohne Eingabe steht nur Gebuchtes da',
      () async {
        final b = behaelter();
        abonniereTreffer(b.container);
        final erfassen = b.container.read(erfassenProvider.notifier);
        final skyr = await erfassen.legeLebensmittelAn(
          const LebensmittelVorlage(name: 'Skyr Natur', je100g: haferflocken),
        );
        await erfassen.legeLebensmittelAn(
          const LebensmittelVorlage(name: 'Banane', je100g: haferflocken),
        );
        await b.container
            .read(lebensmittelRepositoryProvider)
            .merkeBenutzung(skyr, jetzt);

        b.container.read(suchtextProvider.notifier).setze('Skyr');
        expect((await treffer(b.container)).map((l) => l.name), ['Skyr Natur']);

        b.container.read(suchtextProvider.notifier).setze('');
        expect((await treffer(b.container)).map((l) => l.name), ['Skyr Natur']);
      },
    );

    test('das Suchfeld steht beim Start leer', () {
      final b = behaelter();
      expect(b.container.read(suchtextProvider), '');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Gebucht wird auf den offenen Tag, nicht auf heute', () {
    test('wer über ‹ den Montag aufhat, bucht auf den Montag', () async {
      final b = behaelter();
      b.container.read(offenerTagProvider.notifier).blaettere(-1);
      expect(b.container.read(offenerTagProvider), gestern);

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                id: null,
                name: 'Haferflocken kernig',
                je100g: haferflocken,
              ),
              tagesSchluessel: b.container.read(offenerTagProvider),
              jetzt: jetzt,
            ),
          );

      expect((await eintraegeAm(b.container, gestern)).length, 1);
      expect(await eintraegeAm(b.container, heute), isEmpty);
    });

    test('die Uhrzeit ist „jetzt" — auf dem offenen Tag, nicht auf dem von '
        '„jetzt"', () async {
      // #328, Tims Entscheidung vom 04.11.2026: Im Blatt steht immer die
      // Uhrzeit, zu der getrackt wird, auch auf einem geblätterten Tag —
      // nicht mehr die Mitte der Mahlzeit. Der **Tag** bleibt der offene.
      // Geändert vom Test-Agenten von #328, nicht vom Implementierenden.
      final b = behaelter();
      b.container.read(offenerTagProvider.notifier).blaettere(-1);

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                name: 'Mittagsbrot',
                je100g: haferflocken,
              ),
              tagesSchluessel: gestern,
              jetzt: jetzt,
            ),
          );

      final eintrag = (await eintraegeAm(b.container, gestern)).single;
      // 12:00 Berliner Zeit am **13.07.**2026 (MESZ, +2) = 10:00 UTC am
      // 13.07. — und **nicht** 10:30 UTC, was die Mittagsmitte wäre.
      expect(eintrag.zeitpunkt, DateTime.utc(2026, 7, 13, 10));
      expect(eintrag.mahlzeit, Mahlzeit.mittag);
    });

    test(
      'gebucht wird auch ohne Schreibfreigabe — der Stand ist offen',
      () async {
        final b = behaelter();

        await b.container
            .read(erfassenProvider.notifier)
            .buche(
              BuchungsFormular.neu(
                vorlage: const LebensmittelVorlage(
                  name: 'Hafer',
                  je100g: haferflocken,
                ),
                tagesSchluessel: heute,
                jetzt: jetzt,
              ),
            );

        final eintrag = (await eintraegeAm(b.container, heute)).single;
        expect(eintrag.healthStand, HealthStand.offen);
        expect(eintrag.healthUuid, isNull);
      },
    );

    test(
      'buchen merkt die Benutzung — das Lebensmittel steht danach obenan',
      () async {
        final b = behaelter();
        abonniereTreffer(b.container);
        final erfassen = b.container.read(erfassenProvider.notifier);

        await erfassen.legeLebensmittelAn(
          const LebensmittelVorlage(name: 'Apfel', je100g: haferflocken),
        );
        final skyrId = await erfassen.legeLebensmittelAn(
          const LebensmittelVorlage(name: 'Skyr Natur', je100g: haferflocken),
        );

        // #345: Ohne Suchtext stünde vorher nichts da. Ein Suchtext, den
        // beide Namen enthalten, zeigt dieselbe Reihenfolge wie früher
        // „zuletzt benutzt".
        b.container.read(suchtextProvider.notifier).setze('a');

        // Vorher: nie benutzt, also alphabetisch.
        expect((await treffer(b.container)).map((l) => l.name), [
          'Apfel',
          'Skyr Natur',
        ]);

        await erfassen.buche(
          BuchungsFormular.neu(
            vorlage: (await treffer(b.container))
                .firstWhere((l) => l.id == skyrId),
            tagesSchluessel: heute,
            jetzt: jetzt,
          ),
        );

        expect((await treffer(b.container)).map((l) => l.name), [
          'Skyr Natur',
          'Apfel',
        ]);

        // Und ohne Suchtext steht jetzt genau das Gebuchte da.
        b.container.read(suchtextProvider.notifier).setze('');
        expect((await treffer(b.container)).map((l) => l.name), ['Skyr Natur']);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Nährwerte sind eingefroren', () {
    /// Legt an, bucht 250 g und gibt beides zurück.
    Future<({int id, Eintrag eintrag})> gebucht(
      ProviderContainer container,
    ) async {
      final erfassen = container.read(erfassenProvider.notifier);
      final id = await erfassen.legeLebensmittelAn(
        const LebensmittelVorlage(
          name: 'Haferflocken kernig',
          je100g: haferflocken,
        ),
      );
      final vorlage = (await container
          .read(lebensmittelRepositoryProvider)
          .lies(id))!;

      await erfassen.buche(
        BuchungsFormular.neu(
          vorlage: vorlage,
          tagesSchluessel: heute,
          jetzt: jetzt,
        ).mitMenge('250'),
      );

      return (
        id: id,
        eintrag: (await container.read(eigeneEintraegeProvider(heute).future))
            .single,
      );
    }

    test('wird das Lebensmittel danach geändert, bleibt der Eintrag, wie er '
        'war', () async {
      final b = behaelter();
      final g = await gebucht(b.container);
      expect(g.eintrag.naehrwerte.kcal, closeTo(930, 1e-9));

      await b.container
          .read(lebensmittelRepositoryProvider)
          .aendere(
            LebensmittelVorlage(
              id: g.id,
              name: 'Haferflocken kernig',
              je100g: const Naehrwerte.je100g(kcal: 999),
            ),
          );

      final wieder = (await eintraegeAm(b.container, heute)).single;
      expect(wieder.naehrwerte.kcal, closeTo(930, 1e-9));
      expect(wieder.naehrwerte.eiweissG, closeTo(33.75, 1e-9));
    });

    test(
      'auch die Menge zu ändern zieht die neuen Zahlen nicht herein',
      () async {
        final b = behaelter();
        final g = await gebucht(b.container);

        await b.container
            .read(lebensmittelRepositoryProvider)
            .aendere(
              LebensmittelVorlage(
                id: g.id,
                name: 'Haferflocken kernig',
                je100g: const Naehrwerte.je100g(kcal: 999),
              ),
            );

        await b.container
            .read(erfassenProvider.notifier)
            .aendere(BuchungsFormular.fuer(g.eintrag).mitMenge('300'));

        final wieder = (await eintraegeAm(b.container, heute)).single;
        // 372 kcal je 100 g waren eingefroren — 300 g davon sind 1116,
        // nicht 2997.
        expect(wieder.naehrwerte.kcal, closeTo(1116, 1e-6));
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ändern und Löschen', () {
    Future<Eintrag> einEintrag(ProviderContainer container) async {
      await container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                name: 'Haferflocken kernig',
                je100g: haferflocken,
              ),
              tagesSchluessel: heute,
              jetzt: jetzt,
            ).mitMenge('250'),
          );
      return (await container.read(eigeneEintraegeProvider(heute).future))
          .single;
    }

    test('ändern ersetzt und legt nicht neu an', () async {
      final b = behaelter();
      final eintrag = await einEintrag(b.container);

      await b.container
          .read(erfassenProvider.notifier)
          .aendere(BuchungsFormular.fuer(eintrag).mitMenge('300'));

      final danach = await eintraegeAm(b.container, heute);
      expect(danach.length, 1);
      expect(danach.single.id, eintrag.id);
      expect(danach.single.mengeG, 300);
    });

    test('der Tag-Schirm zeigt nach dem Ändern die neue Summe', () async {
      final b = behaelter();
      final eintrag = await einEintrag(b.container);
      expect((await summeAm(b.container, heute))!.kcal, closeTo(930, 1e-9));

      await b.container
          .read(erfassenProvider.notifier)
          .aendere(BuchungsFormular.fuer(eintrag).mitMenge('300'));

      expect((await summeAm(b.container, heute))!.kcal, closeTo(1116, 1e-6));
    });

    test(
      'die Mahlzeit umzuhängen schiebt den Eintrag in die andere Zeile',
      () async {
        final b = behaelter();
        final eintrag = await einEintrag(b.container);

        await b.container
            .read(erfassenProvider.notifier)
            .aendere(
              BuchungsFormular.fuer(eintrag).mitMahlzeit(Mahlzeit.fruehstueck),
            );

        final zeilen = (await tagVon(b.container, heute)).mahlzeiten;
        expect(
          zeilen
              .firstWhere((z) => z.mahlzeit == Mahlzeit.fruehstueck)
              .eigene
              .length,
          1,
        );
        expect(
          zeilen.firstWhere((z) => z.mahlzeit == Mahlzeit.mittag).eigene,
          isEmpty,
        );
      },
    );

    test('löschen nimmt den Eintrag weg', () async {
      final b = behaelter();
      final eintrag = await einEintrag(b.container);

      await b.container.read(erfassenProvider.notifier).loesche(eintrag);

      expect(await eintraegeAm(b.container, heute), isEmpty);
    });

    test('der Tag-Schirm zeigt nach dem Löschen die neue Summe', () async {
      final b = behaelter();
      final eintrag = await einEintrag(b.container);

      await b.container.read(erfassenProvider.notifier).loesche(eintrag);

      // Nicht `null` und nicht „keine Daten": Ein Tag ohne Einträge hat
      // nachweislich 0 gegessen — für Tims eigene Daten heißt leer
      // schlicht leer (`ernaehrung_provider.dart`, `_leereSumme`).
      expect((await summeAm(b.container, heute))!.kcal, 0);
    });

    test('löschen nimmt nur den einen Eintrag weg', () async {
      final b = behaelter();
      final erfassen = b.container.read(erfassenProvider.notifier);
      final eintrag = await einEintrag(b.container);
      await erfassen.buche(
        BuchungsFormular.neu(
          vorlage: const LebensmittelVorlage(
            name: 'Banane',
            je100g: haferflocken,
          ),
          tagesSchluessel: heute,
          jetzt: jetzt,
        ).mitMahlzeit(Mahlzeit.snack),
      );

      await erfassen.loesche(eintrag);

      final danach = await eintraegeAm(b.container, heute);
      expect(danach.map((e) => e.name), ['Banane']);
    });

    test('aktualisiere ohne Schlüssel wirft — ein Eintrag ohne Schlüssel ist '
        'nicht gebucht', () async {
      final b = behaelter();

      await expectLater(
        b.container
            .read(ernaehrungRepositoryProvider)
            .aktualisiere(
              Eintrag(
                tagesSchluessel: heute,
                mahlzeit: Mahlzeit.mittag,
                zeitpunkt: jetzt,
                name: 'Ohne Schlüssel',
                naehrwerte: const Naehrwerte(kcal: 100),
              ),
            ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('aktualisiere rührt keinen anderen Eintrag an', () async {
      final b = behaelter();
      final repo = b.container.read(ernaehrungRepositoryProvider);
      final eins = await einEintrag(b.container);
      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                name: 'Banane',
                je100g: haferflocken,
              ),
              tagesSchluessel: heute,
              jetzt: jetzt,
            ).mitMahlzeit(Mahlzeit.snack),
          );

      await repo.aktualisiere(
        Eintrag(
          id: eins.id,
          tagesSchluessel: eins.tagesSchluessel,
          mahlzeit: eins.mahlzeit,
          zeitpunkt: eins.zeitpunkt,
          lebensmittelId: eins.lebensmittelId,
          name: 'Umbenannt',
          mengeG: eins.mengeG,
          naehrwerte: eins.naehrwerte,
        ),
      );

      final danach = await repo.eintraegeAmTag(heute);
      expect(danach.length, 2);
      expect(danach.firstWhere((e) => e.id != eins.id).name, 'Banane');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ein fehlender Nährwert bleibt fehlend — bis in die Tagessumme', () {
    test(
      'ein Lebensmittel ohne Eiweißangabe macht die Summe null, nicht 0',
      () async {
        final b = behaelter();

        await b.container
            .read(erfassenProvider.notifier)
            .buche(
              BuchungsFormular.neu(
                vorlage: const LebensmittelVorlage(
                  name: 'Nur Kalorien bekannt',
                  je100g: Naehrwerte.je100g(kcal: 200),
                ),
                tagesSchluessel: heute,
                jetzt: jetzt,
              ).mitMenge('100'),
            );

        final summe = (await summeAm(b.container, heute))!;
        expect(summe.kcal, closeTo(200, 1e-9));
        // `#232` in neuer Verpackung: 0 g Eiweiß hieße „enthält kein
        // Eiweiß", und das hat niemand gemessen.
        expect(summe.eiweissG, isNull);
        expect(summe.fettG, isNull);
      },
    );

    test('ein Eintrag **mit** Angabe trägt die Summe allein — er wird nicht '
        'von einem fehlenden Wert weggewischt', () async {
      final b = behaelter();
      final erfassen = b.container.read(erfassenProvider.notifier);

      await erfassen.buche(
        BuchungsFormular.neu(
          vorlage: const LebensmittelVorlage(
            name: 'Mit Eiweiß',
            je100g: Naehrwerte.je100g(kcal: 100, eiweissG: 20),
          ),
          tagesSchluessel: heute,
          jetzt: jetzt,
        ).mitMenge('100'),
      );
      await erfassen.buche(
        BuchungsFormular.neu(
          vorlage: const LebensmittelVorlage(
            name: 'Ohne Eiweiß',
            je100g: Naehrwerte.je100g(kcal: 100),
          ),
          tagesSchluessel: heute,
          jetzt: jetzt,
        ).mitMenge('100').mitMahlzeit(Mahlzeit.snack),
      );

      final summe = (await summeAm(b.container, heute))!;
      expect(summe.kcal, closeTo(200, 1e-9));
      expect(summe.eiweissG, closeTo(20, 1e-9));
    });

    test('eine eingetragene 0 verschwindet nicht', () async {
      final b = behaelter();

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                name: 'Mineralwasser',
                je100g: Naehrwerte.je100g(kcal: 0, eiweissG: 0),
                fluessig: true,
              ),
              tagesSchluessel: heute,
              jetzt: jetzt,
            ).mitMenge('500'),
          );

      final eintrag = (await eintraegeAm(b.container, heute)).single;
      expect(eintrag.naehrwerte.kcal, 0);
      expect(eintrag.naehrwerte.eiweissG, 0);
      expect(eintrag.naehrwerte.fettG, isNull);
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}
