import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_verlauf.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **#410 — das Kalorienziel ist fest** und ändert sich nicht
/// mehr täglich.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbarn: `data/kalorienziele_test.dart` (Werttyp, Repository,
/// `kalorienzieleProvider`), `data/schema_v19_test.dart` (die Tabelle),
/// `kalorienziel_herleitung_quelle_test.dart` (die Zeile „woher die Zahl
/// stammt") und `shell/vorlaeufige_werte_kalorienziel_test.dart` (das Feld
/// zum Ändern von Hand).
///
/// ## Was verlangt wird
///
/// Ticket #410, Tim am 07.11.2026: „Das Kalorienziel soll **fest** sein und
/// sich nicht täglich ändern — außer der Coach passt es an." Die
/// Ausgestaltung ist eine **Vorgabe des Koordinators**; Tim hat die
/// Rückfrage dazu weggeklickt, also weder bestätigt noch verworfen:
///
/// 1. Das Ziel wird **einmal** mit der heutigen Formel berechnet und
///    **gespeichert** — sobald es berechenbar ist und noch keins
///    gespeichert ist.
/// 2. Danach gilt der gespeicherte Wert **ab dem Tag seines Festlegens für
///    alle folgenden Tage.** Keine tägliche Neuberechnung mehr.
/// 3. **Tage vor dem Festlegen** behalten ihr damaliges, berechnetes Ziel —
///    der Verlauf springt nicht rückwirkend.
/// 4. Jede Änderung (von Hand, später über den Coach) gilt **ab ihrem
///    Tag**; frühere Tage behalten den alten Wert.
/// 5. **Makroziele leiten sich vom festen Ziel ab.**
///
/// Das widerspricht `docs/SPEC.md` 4.8 („Kalorienziel pro Tag"); laut
/// Ticket wird die SPEC nachgezogen.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// In `lib/ernaehrung/ernaehrung_provider.dart` kommen **benannte,
/// optionale** Parameter dazu, Vorgabe `const []` — die bestehenden
/// Aufrufe und Tests bleiben damit gültig, und „keine Festlegung" heißt
/// „gerechnet wie bisher":
///
/// ```dart
/// ErnaehrungsTag ernaehrungsTagAus({…, List<KalorienzielFestlegung>
///     kalorienziele = const []});
/// double? zielKcalAm({…, List<KalorienzielFestlegung> kalorienziele =
///     const []});
/// KalorienzielAnteile? kalorienzielAnteileAm({…,
///     List<KalorienzielFestlegung> kalorienziele = const []});
///
/// class ErnaehrungsTag {
///   const ErnaehrungsTag({…, this.zielFestlegung}); // optional
///   /// Die Festlegung, die an diesem Tag gilt — `null`, wenn das Ziel
///   /// dieses Tages noch gerechnet ist (vor der ersten Festlegung).
///   final KalorienzielFestlegung? zielFestlegung;   // Teil von ==/hashCode
/// }
/// ```
///
/// `ernaehrungsTagProvider`, `ernaehrungsHerleitungProvider` und
/// `ernaehrungsVerlaufProvider` lesen die Historie aus
/// `kalorienzieleProvider` (`lib/data/kalorienziele.dart`).
///
/// **Das Festlegen** passiert, sobald jemand `ernaehrungsTagProvider` für
/// **heute** beobachtet und das Ziel für heute berechenbar ist, aber noch
/// keine Festlegung in der Tabelle steht. Home und der Ernährungs-Tab
/// beobachten genau diesen Provider, also passiert es beim ersten Start mit
/// vollständigen Angaben. **Wie** — eigener Provider, Notifier, Seiteneffekt
/// — legt diese Datei nicht fest; sie prüft nur die Tabelle danach.
///
/// ## Weitere Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **„Die heutige Formel" ist die für heute** (#229): Mifflin-St Jeor
///   ohne den bisher gemessenen Watch-Verbrauch, plus Körperziel. Die
///   Anteile werden mitgespeichert, damit die Herleitung an einem festen
///   Tag noch erklärt, woher die Zahl stammt, und ihre Summe die Zahl im
///   Ring bleibt (#314).
/// - **An einem festen Tag lädt das Ziel nicht.** Es steht in der eigenen
///   Tabelle, nicht in Apple Health: `zielLaedt` ist `false`, auch solange
///   der Health-Lauf noch aussteht („Zuerst der Cache", `CLAUDE.md`). Und
///   es steht auch ohne Stammdaten — gerechnet wird ja nicht mehr.
/// - **Festgelegt wird nur auf einen fertigen Stand.** Solange der
///   Health-Lauf noch nie etwas geliefert hat (`NochNie`), ist das Ziel
///   nicht berechenbar, und es wird nichts gespeichert. Ein Ziel aus
///   halben Angaben wäre fest — und bliebe falsch.
/// - **„Noch keins gespeichert" heißt: die Tabelle ist leer.** Steht eine
///   Festlegung da, egal welcher Herkunft, legt die App nie wieder von
///   selbst fest.
/// - **Die Eiweiß- und Fettziele hängen weiter am Gewicht des Tages**
///   (g/kg); nur das Kohlenhydratziel — der Rest des Budgets — folgt dem
///   festen Kalorienziel.
///
/// ## Bestehende Tests
///
/// Die Fälle in `ernaehrung_tag_test.dart`, `ernaehrung_herleitung_test
/// .dart` und `ernaehrung_verlauf_test.dart`, die das tägliche Rechnen
/// zeigen (#229: „heute der Planwert, vergangene Tage der gemessene
/// Verbrauch"), bleiben richtig: Sie laufen ohne Festlegung, und **vor**
/// der ersten Festlegung wird weiter so gerechnet. Deshalb ist keiner
/// davon umgestellt.
///
/// **Alle Zahlen erfunden** — runde Werte, keine aus dem Entwurf.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit — ohne Bezug zu irgendeinem
  // Ereignis.
  const heute = '2026-07-14';
  const gestern = '2026-07-13';
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(
    String tag, {
    int? aktiv = 600,
    int? basal = 1600,
    double? gewicht = 80,
  }) => DailyMetrics(
    tag: tag,
    activeKcal: aktiv,
    basalKcal: basal,
    weightKg: gewicht,
  );

  Messwert<List<DailyMetrics>> tageswerteDa(List<DailyMetrics> liste) =>
      Bekannt<List<DailyMetrics>>(liste, stand: jetzt, laeuft: false);

  final standardWerte = tageswerteDa([tageswert(gestern), tageswert(heute)]);

  /// Das Ziel für heute nach der heutigen Formel (#229) — ohne gemessenen
  /// Verbrauch, aus dem Kern.
  double formelHeute({double gewicht = 80, Stammdaten s = vollstaendig}) =>
      kalorienziel(
        gewichtKg: gewicht,
        groesseCm: s.groesseCm,
        alter: s.alterAm(datumAusTag(heute)),
        zielgewichtKg: s.zielgewichtKg,
        tageBisZiel: BerlinCalendar.daysBetween(from: heute, to: s.zieldatum!),
      )!;

  KalorienzielAnteile anteileHeute() => kalorienzielAnteile(
    gewichtKg: 80,
    groesseCm: vollstaendig.groesseCm,
    alter: vollstaendig.alterAm(datumAusTag(heute)),
    zielgewichtKg: vollstaendig.zielgewichtKg,
    tageBisZiel: BerlinCalendar.daysBetween(
      from: heute,
      to: vollstaendig.zieldatum!,
    ),
  )!;

  /// Eine Festlegung von früher, deutlich anders als das, was die Formel
  /// heute ergäbe (~2.600 kcal) — sonst bewiese „bleibt fest" nichts.
  const festeAnteile = KalorienzielAnteile(
    grundumsatzKcal: 1900,
    aktivKcal: 800,
    koerperzielKcal: 300,
    gemessen: false,
  );
  const festSeit0710 = KalorienzielFestlegung(
    abTag: '2026-07-10',
    kcal: 3000,
    herkunft: KalorienzielHerkunft.berechnet,
    anteile: festeAnteile,
  );
  const handSeit0712 = KalorienzielFestlegung(
    abTag: '2026-07-12',
    kcal: 3300,
    herkunft: KalorienzielHerkunft.hand,
  );

  // ═════════════════════════════════════════════════════════════════════
  // Die reine Funktion
  // ═════════════════════════════════════════════════════════════════════

  ErnaehrungsTag tag({
    String tagesSchluessel = heute,
    Messwert<List<DailyMetrics>>? tageswerte,
    Stammdaten stammdaten = vollstaendig,
    List<KalorienzielFestlegung> kalorienziele = const [],
  }) => ernaehrungsTagAus(
    tagesSchluessel: tagesSchluessel,
    heute: heute,
    eigene: const [],
    fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
    tageswerte: tageswerte ?? standardWerte,
    stammdaten: stammdaten,
    jetzt: jetzt,
    kalorienziele: kalorienziele,
  );

  group('Ohne Festlegung wird gerechnet wie bisher', () {
    test('keine Festlegung: das Ziel ist das gerechnete, und es trägt keine '
        'Festlegung', () {
      final t = tag();
      expect(t.zielKcal, closeTo(formelHeute(), 1e-9));
      expect(t.zielFestlegung, isNull);
    });
  });

  group('An einem festen Tag gilt die gespeicherte Zahl', () {
    test('ab ihrem Tag — auch heute — steht die Festlegung im Ring', () {
      final t = tag(kalorienziele: const [festSeit0710]);
      expect(t.zielKcal, 3000);
      expect(t.zielFestlegung, festSeit0710);
      expect(t.bilanz.zielKcal, 3000);
    });

    test('der Tag des Festlegens selbst trägt sie schon', () {
      final t = tag(
        tagesSchluessel: '2026-07-10',
        tageswerte: tageswerteDa([tageswert('2026-07-10')]),
        kalorienziele: const [festSeit0710],
      );
      expect(t.zielKcal, 3000);
    });

    test('keine tägliche Neuberechnung: anderes Gewicht, anderer '
        'Verbrauch, andere Stammdaten — dieselbe Zahl', () {
      final anders = tag(
        tageswerte: tageswerteDa([
          tageswert(heute, aktiv: 1400, basal: 1900, gewicht: 70),
        ]),
        stammdaten: const Stammdaten(
          groesseCm: 160,
          geburtsjahr: 1960,
          zielgewichtKg: 95,
          zieldatum: '2026-09-01',
        ),
        kalorienziele: const [festSeit0710],
      );
      expect(
        anders.zielKcal,
        3000,
        reason:
            'das Ziel ändert sich nur durch eine neue Festlegung, nicht '
            'durch neue Messwerte (Tim, 07.11.2026)',
      );
    });

    test('auch ein vergangener, ganztägig gemessener Tag nach dem Festlegen '
        'nimmt die feste Zahl, nicht den Verbrauch', () {
      final t = tag(
        tagesSchluessel: gestern,
        tageswerte: tageswerteDa([tageswert(gestern, aktiv: 1200)]),
        kalorienziele: const [festSeit0710],
      );
      expect(t.zielKcal, 3000);
    });

    test('das feste Ziel lädt nicht, auch wenn Health noch nachsieht — es '
        'steht in der eigenen Tabelle', () {
      final t = tag(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        kalorienziele: const [festSeit0710],
      );
      expect(t.zielKcal, 3000);
      expect(t.zielLaedt, isFalse);
    });

    test(
      'und es steht auch ohne Stammdaten — gerechnet wird ja nicht mehr',
      () {
        final t = tag(
          stammdaten: const Stammdaten(),
          kalorienziele: const [festSeit0710],
        );
        expect(t.zielKcal, 3000);
        expect(t.bilanz.status, isNot(Zielstatus.keinZiel));
      },
    );
  });

  group('Vor dem Festlegen: der Verlauf springt nicht rückwirkend', () {
    test('ein Tag vor der ersten Festlegung behält sein gerechnetes Ziel — '
        'dasselbe wie ganz ohne Festlegung', () {
      const frueher = '2026-07-09';
      final werte = tageswerteDa([tageswert(frueher, aktiv: 500)]);

      final mit = tag(
        tagesSchluessel: frueher,
        tageswerte: werte,
        kalorienziele: const [festSeit0710],
      );
      final ohne = tag(tagesSchluessel: frueher, tageswerte: werte);

      expect(ohne.zielKcal, isNotNull, reason: 'Vorbedingung');
      expect(mit.zielKcal, ohne.zielKcal);
      expect(
        mit.zielKcal,
        isNot(3000),
        reason: 'eine Festlegung gilt ab ihrem Tag, nicht davor',
      );
      expect(mit.zielFestlegung, isNull);
    });
  });

  group('Eine Änderung gilt ab ihrem Tag', () {
    const historie = [festSeit0710, handSeit0712];

    test('ab dem Tag der Änderung die neue Zahl, davor die alte, vor der '
        'ersten die gerechnete', () {
      final werte = tageswerteDa([
        for (final t in ['2026-07-09', '2026-07-11', '2026-07-12', heute])
          tageswert(t),
      ]);
      ErnaehrungsTag am(String t) =>
          tag(tagesSchluessel: t, tageswerte: werte, kalorienziele: historie);

      expect(am(heute).zielKcal, 3300);
      expect(am(heute).zielFestlegung, handSeit0712);
      expect(am('2026-07-12').zielKcal, 3300);
      expect(am('2026-07-11').zielKcal, 3000);
      expect(am('2026-07-11').zielFestlegung, festSeit0710);
      expect(am('2026-07-09').zielFestlegung, isNull);
      expect(am('2026-07-09').zielKcal, isNot(anyOf(3000, 3300)));
    });

    test('die Reihenfolge der Historie spielt keine Rolle', () {
      final t = tag(kalorienziele: const [handSeit0712, festSeit0710]);
      expect(t.zielKcal, 3300);
    });
  });

  group('Die Makroziele folgen dem festen Ziel', () {
    test('das Kohlenhydratziel ist der Rest des festen Budgets', () {
      final t = tag(kalorienziele: const [festSeit0710]);
      final erwartet = makrozieleFuer(gewichtKg: 80, kalorienzielKcal: 3000);

      expect(t.makroziele.kohlenhydrateZielG, erwartet.kohlenhydrateZielG);
      expect(
        t.makroziele.kohlenhydrateZielG,
        isNot(
          makrozieleFuer(
            gewichtKg: 80,
            kalorienzielKcal: formelHeute(),
          ).kohlenhydrateZielG,
        ),
        reason:
            'aus der Formel gerechnet wäre es ein anderes — das Ziel ist '
            'aber das feste',
      );
    });

    test('Eiweiß und Fett hängen weiter am Gewicht des Tages', () {
      final t = tag(
        tageswerte: tageswerteDa([tageswert(heute, gewicht: 70)]),
        kalorienziele: const [festSeit0710],
      );
      final erwartet = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 3000);
      expect(t.makroziele.eiweissMinG, erwartet.eiweissMinG);
      expect(t.makroziele.fettMinG, erwartet.fettMinG);
      expect(t.makroziele.kohlenhydrateZielG, erwartet.kohlenhydrateZielG);
    });
  });

  group('Wertgleichheit — die Herleitung muss mitbekommen, woher die Zahl '
      'stammt', () {
    test('gleiche Zahl, andere Herkunft: zwei verschiedene Tage', () {
      const berechnet3300 = KalorienzielFestlegung(
        abTag: '2026-07-12',
        kcal: 3300,
        herkunft: KalorienzielHerkunft.berechnet,
      );
      final a = tag(kalorienziele: const [handSeit0712]);
      final b = tag(kalorienziele: const [berechnet3300]);
      expect(a.zielKcal, b.zielKcal, reason: 'Vorbedingung');
      expect(a, isNot(b));
    });

    test('gleiche Eingaben: zwei gleiche Tage', () {
      final a = tag(kalorienziele: const [festSeit0710]);
      final b = tag(kalorienziele: const [festSeit0710]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Ziel für den Verlauf und Herleitung aus denselben Quellen', () {
    const historie = [festSeit0710, handSeit0712];
    final werte = tageswerteDa([
      for (final t in ['2026-07-09', '2026-07-11', heute]) tageswert(t),
    ]);

    test('zielKcalAm ist dieselbe Zahl wie der Tag', () {
      for (final t in ['2026-07-09', '2026-07-11', heute]) {
        expect(
          zielKcalAm(
            tagesSchluessel: t,
            heute: heute,
            tageswerte: werte,
            stammdaten: vollstaendig,
            kalorienziele: historie,
          ),
          tag(
            tagesSchluessel: t,
            tageswerte: werte,
            kalorienziele: historie,
          ).zielKcal,
          reason: '$t: eine zweite Zielrechnung liefe auseinander',
        );
      }
    });

    test('kalorienzielAnteileAm: an einem berechnet festgelegten Tag die '
        'gespeicherten Anteile — ihre Summe ist die Zahl im Ring', () {
      final a = kalorienzielAnteileAm(
        tagesSchluessel: '2026-07-11',
        heute: heute,
        tageswerte: werte,
        stammdaten: vollstaendig,
        kalorienziele: historie,
      );
      expect(a, festeAnteile);
      expect(a!.summeKcal, 3000);
    });

    test('kalorienzielAnteileAm: von Hand gibt es keine Anteile', () {
      expect(
        kalorienzielAnteileAm(
          tagesSchluessel: heute,
          heute: heute,
          tageswerte: werte,
          stammdaten: vollstaendig,
          kalorienziele: historie,
        ),
        isNull,
        reason:
            'Anteile, die nicht zur Zahl gehören, wären eine Herleitung, '
            'die etwas anderes erklärt als den Ring (#314)',
      );
    });

    test(
      'kalorienzielAnteileAm: vor der ersten Festlegung die gerechneten',
      () {
        final ohne = kalorienzielAnteileAm(
          tagesSchluessel: '2026-07-09',
          heute: heute,
          tageswerte: werte,
          stammdaten: vollstaendig,
        );
        expect(ohne, isNotNull, reason: 'Vorbedingung');
        expect(
          kalorienzielAnteileAm(
            tagesSchluessel: '2026-07-09',
            heute: heute,
            tageswerte: werte,
            stammdaten: vollstaendig,
            kalorienziele: historie,
          ),
          ohne,
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // Im Riverpod-Baum, mit echter Datenbank
  // ═════════════════════════════════════════════════════════════════════

  group('Festlegen und Halten im Riverpod-Baum', () {
    ({ProviderContainer container, AppCache db}) behaelter({
      Stammdaten stammdaten = vollstaendig,
      Messwert<List<DailyMetrics>>? tageswerte,
    }) {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(tageswerte ?? standardWerte),
          ),
          fremdeMahlzeitenProvider.overrideWith2(
            (tag) =>
                _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, db: db);
    }

    /// Legt [vorher] ab, **bevor** irgendein Provider liest.
    Future<({ProviderContainer container, AppCache db})> mitHistorie(
      List<KalorienzielFestlegung> vorher, {
      Stammdaten stammdaten = vollstaendig,
      Messwert<List<DailyMetrics>>? tageswerte,
    }) async {
      final b = behaelter(stammdaten: stammdaten, tageswerte: tageswerte);
      final repo = KalorienzielRepository(b.db);
      for (final f in vorher) {
        await repo.setze(f);
      }
      return b;
    }

    /// Lässt die Läufe arbeiten — ohne festzulegen, wie viele Schritte
    /// das Festlegen braucht.
    Future<void> laufenLassen() async {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    /// Wartet, bis [bedingung] gilt, höchstens eine Weile.
    Future<void> bis(bool Function() bedingung) async {
      for (var i = 0; i < 300 && !bedingung(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    void beobachte(ProviderContainer c, String tagesSchluessel) =>
        c.listen(ernaehrungsTagProvider(tagesSchluessel), (_, _) {});

    test('sobald berechenbar und noch keins gespeichert: einmal festgelegt, '
        'ab heute, mit der Formel für heute', () async {
      final b = behaelter();
      beobachte(b.container, heute);
      await bis(
        () =>
            b.container.read(kalorienzieleProvider).value?.isNotEmpty ?? false,
      );
      await laufenLassen();

      final alle = await KalorienzielRepository(b.db).alle();
      expect(alle, hasLength(1), reason: 'genau eine Festlegung');
      final f = alle.single;
      expect(f.abTag, heute);
      expect(f.herkunft, KalorienzielHerkunft.berechnet);
      expect(
        f.kcal,
        closeTo(formelHeute(), 1e-9),
        reason:
            'die Formel für heute (#229) — nicht der bisher gemessene '
            'Verbrauch, der heute 2.200 kcal wäre',
      );
      expect(f.anteile, anteileHeute());

      final t = b.container.read(ernaehrungsTagProvider(heute));
      expect(t.zielKcal, f.kcal);
      expect(t.zielFestlegung, f);
    });

    test('nicht berechenbar (Stammdaten fehlen): nichts festgelegt', () async {
      final b = behaelter(stammdaten: const Stammdaten());
      beobachte(b.container, heute);
      await laufenLassen();

      expect(await KalorienzielRepository(b.db).alle(), isEmpty);
      expect(b.container.read(ernaehrungsTagProvider(heute)).zielKcal, isNull);
    });

    test('solange Health noch nie geliefert hat, wird nichts festgelegt — '
        'ein Ziel aus halben Angaben bliebe falsch', () async {
      final b = behaelter(tageswerte: const NochNie<List<DailyMetrics>>());
      beobachte(b.container, heute);
      await laufenLassen();

      expect(await KalorienzielRepository(b.db).alle(), isEmpty);
    });

    test('wird es berechenbar, wird es in dem Moment festgelegt', () async {
      final b = behaelter(stammdaten: const Stammdaten());
      beobachte(b.container, heute);
      await laufenLassen();
      expect(
        await KalorienzielRepository(b.db).alle(),
        isEmpty,
        reason: 'Vorbedingung',
      );

      await b.container.read(stammdatenProvider.notifier).setze(vollstaendig);
      await bis(
        () =>
            b.container.read(kalorienzieleProvider).value?.isNotEmpty ?? false,
      );
      await laufenLassen();

      final f = (await KalorienzielRepository(b.db).alle()).single;
      expect(f.abTag, heute);
      expect(f.kcal, closeTo(formelHeute(), 1e-9));
    });

    test('steht schon eine Festlegung da, legt die App nie wieder von selbst '
        'fest — auch wenn die Formel heute etwas anderes ergäbe', () async {
      final b = await mitHistorie(const [festSeit0710]);
      beobachte(b.container, heute);
      await laufenLassen();

      expect(await KalorienzielRepository(b.db).alle(), [festSeit0710]);
      await bis(
        () =>
            b.container.read(ernaehrungsTagProvider(heute)).zielFestlegung !=
            null,
      );
      expect(b.container.read(ernaehrungsTagProvider(heute)).zielKcal, 3000);
    });

    test('auch eine Festlegung von Hand verhindert das Festlegen', () async {
      final b = await mitHistorie(const [handSeit0712]);
      beobachte(b.container, heute);
      await laufenLassen();

      expect(await KalorienzielRepository(b.db).alle(), [handSeit0712]);
    });

    test('keine tägliche Neuberechnung: nach dem Festlegen ändern sich '
        'Stammdaten und Gewicht, das Ziel bleibt', () async {
      final b = behaelter();
      beobachte(b.container, heute);
      await bis(
        () =>
            b.container.read(kalorienzieleProvider).value?.isNotEmpty ?? false,
      );
      await laufenLassen();
      final fest = b.container.read(ernaehrungsTagProvider(heute)).zielKcal;
      expect(fest, closeTo(formelHeute(), 1e-9), reason: 'Vorbedingung');

      await b.container
          .read(stammdatenProvider.notifier)
          .setze(vollstaendig.kopieMit(zielgewichtKg: 95));
      (b.container.read(dailyMetricsProvider.notifier) as _Tageswerte).setze(
        tageswerteDa([tageswert(gestern), tageswert(heute, gewicht: 70)]),
      );
      await laufenLassen();

      expect(
        formelHeute(gewicht: 70, s: vollstaendig.kopieMit(zielgewichtKg: 95)),
        isNot(closeTo(fest!, 1)),
        reason: 'Vorbedingung: die Formel ergäbe jetzt etwas anderes',
      );
      expect(b.container.read(ernaehrungsTagProvider(heute)).zielKcal, fest);
      expect(
        await KalorienzielRepository(b.db).alle(),
        hasLength(1),
        reason: 'neue Messwerte sind keine neue Festlegung',
      );
    });

    test(
      'Tage vor dem Festlegen behalten ihr damals gerechnetes Ziel',
      () async {
        final b = behaelter();
        beobachte(b.container, heute);
        beobachte(b.container, gestern);
        await bis(
          () =>
              b.container.read(kalorienzieleProvider).value?.isNotEmpty ??
              false,
        );
        await laufenLassen();

        final g = b.container.read(ernaehrungsTagProvider(gestern));
        expect(g.zielFestlegung, isNull);
        expect(
          g.zielKcal,
          kalorienziel(
            aktivKcal: 600,
            basalKcal: 1600,
            gewichtKg: 80,
            groesseCm: vollstaendig.groesseCm,
            alter: vollstaendig.alterAm(datumAusTag(gestern)),
            zielgewichtKg: vollstaendig.zielgewichtKg,
            tageBisZiel: BerlinCalendar.daysBetween(
              from: gestern,
              to: vollstaendig.zieldatum!,
            ),
          ),
          reason:
              'gestern lag vor dem Festlegen: gemessener Verbrauch plus '
              'Körperziel, wie bisher (#229)',
        );
      },
    );

    test('eine Änderung von Hand gilt ab heute, frühere Tage behalten den '
        'alten Wert', () async {
      final b = await mitHistorie(const [festSeit0710]);
      beobachte(b.container, heute);
      beobachte(b.container, '2026-07-11');
      beobachte(b.container, '2026-07-09');
      await b.container.read(kalorienzieleProvider.future);

      await b.container.read(kalorienzieleProvider.notifier).setzeVonHand(3300);
      await laufenLassen();

      final h = b.container.read(ernaehrungsTagProvider(heute));
      expect(h.zielKcal, 3300);
      expect(h.zielFestlegung?.herkunft, KalorienzielHerkunft.hand);
      expect(h.zielFestlegung?.abTag, heute);
      expect(
        b.container.read(ernaehrungsTagProvider('2026-07-11')).zielKcal,
        3000,
      );
      expect(
        b.container.read(ernaehrungsTagProvider('2026-07-09')).zielFestlegung,
        isNull,
      );
      expect(await KalorienzielRepository(b.db).alle(), hasLength(2));
    });

    test('die Makroziele im Baum folgen dem festen Ziel', () async {
      final b = await mitHistorie(const [festSeit0710]);
      beobachte(b.container, heute);
      await bis(
        () =>
            b.container.read(ernaehrungsTagProvider(heute)).zielFestlegung !=
            null,
      );

      expect(
        b.container
            .read(ernaehrungsTagProvider(heute))
            .makroziele
            .kohlenhydrateZielG,
        makrozieleFuer(
          gewichtKg: 80,
          kalorienzielKcal: 3000,
        ).kohlenhydrateZielG,
      );
    });

    test(
      'die Herleitung im Baum: gespeicherte Anteile am festen Tag',
      () async {
        final b = await mitHistorie(const [festSeit0710]);
        b.container.listen(ernaehrungsHerleitungProvider(heute), (_, _) {});
        await bis(
          () =>
              b.container.read(ernaehrungsHerleitungProvider(heute)) ==
              festeAnteile,
        );

        expect(
          b.container.read(ernaehrungsHerleitungProvider(heute)),
          festeAnteile,
        );
      },
    );

    test('der Verlauf zieht je Tag dieselbe Zahl wie der Tag-Schirm — '
        'gerechnet vor, fest ab der Festlegung', () async {
      final werte = tageswerteDa([
        for (final t in verlaufFenster(heute)) tageswert(t),
      ]);
      final b = await mitHistorie(const [
        festSeit0710,
        handSeit0712,
      ], tageswerte: werte);
      b.container.listen(ernaehrungsVerlaufProvider(heute), (_, _) {});
      for (final t in verlaufFenster(heute)) {
        beobachte(b.container, t);
      }
      await bis(
        () =>
            b.container
                .read(ernaehrungsVerlaufProvider(heute))
                .tage
                .last
                .zielKcal ==
            3300,
      );
      await laufenLassen();

      final v = b.container.read(ernaehrungsVerlaufProvider(heute));
      for (final t in v.tage) {
        final erwartet = t.tag.compareTo('2026-07-12') >= 0
            ? 3300.0
            : t.tag.compareTo('2026-07-10') >= 0
            ? 3000.0
            : null;
        if (erwartet != null) {
          expect(t.zielKcal, erwartet, reason: t.tag);
        } else {
          expect(
            t.zielKcal,
            isNot(anyOf(3000.0, 3300.0)),
            reason: '${t.tag} liegt vor der ersten Festlegung',
          );
        }
        expect(
          t.zielKcal,
          b.container.read(ernaehrungsTagProvider(t.tag)).zielKcal,
          reason: '${t.tag}: eine zweite Zielrechnung liefe auseinander',
        );
      }
    });
  });
}

/// Steuerbare Ableger der echten Notifier — wie in
/// `ernaehrung_provider_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;

  /// Ein neuer Lauf mit anderen Werten.
  void setze(Messwert<List<DailyMetrics>> neu) => state = AsyncData(neu);
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}
