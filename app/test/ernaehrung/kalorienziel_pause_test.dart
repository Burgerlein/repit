import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ereignisse.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_verlauf.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **das Kalorienziel in der Auszeit** (#447 unter #404): An
/// jedem Tag einer OP, Krankheit oder Verletzung lässt das Kalorienziel
/// den Aufschlag fürs Körperziel weg — auch rückwirkend im Verlauf.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// Nachbarn: `trainings_core/test/auszeit_test.dart` (welche Auszeit an
/// einem Tag pausiert, `festesZielPausiert`), `data/ereignisse_test.dart`
/// (Ablage, `auszeitenProvider`), `kalorienziel_fest_test.dart` (das feste
/// Ziel aus #410) und später `herleitung_pausiert_test.dart` (die Anzeige).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitt
/// „Wo die Pause wirkt“, dazu Tims Entscheidungen 3, 5, 7 und 8 und die
/// Vorgaben V12–V15. Die Vorgaben hat der Planende formuliert; Tim hat sie
/// am 10.11.2026 übernommen („Ja, so bauen“). V15 hat Tim ausdrücklich
/// beantwortet: **Ein von Hand gesetztes Kalorienziel bleibt in der
/// Auszeit unverändert.** Die Schnittstelle steht im Plan
/// `docs/superpowers/plans/2026-11-10-auszeit.md`, Task 4:
///
/// ```dart
/// ErnaehrungsTag ernaehrungsTagAus({…, List<AuszeitTage> auszeiten =
///     const [], bool auszeitenLaden = false});
/// double? zielKcalAm({…, List<AuszeitTage> auszeiten = const [],
///     bool auszeitenLaden = false});
/// KalorienzielAnteile? kalorienzielAnteileAm({…, List<AuszeitTage>
///     auszeiten = const [], bool auszeitenLaden = false});
///
/// class ErnaehrungsTag { final AuszeitTage? pausiertDurch; } // ==, hashCode
/// ```
///
/// `ernaehrungsTagProvider`, `ernaehrungsHerleitungProvider` und
/// `ernaehrungsVerlaufProvider` beobachten `auszeitenProvider`;
/// `kalorienzielFestlegenProvider` **nicht** (V13).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`auszeitenLaden` gewinnt auch über einen festen Tag.** V12 sagt
///   „Solange die Ereignisse nicht gelesen sind, steht kein Ziel da“, ohne
///   Ausnahme; ein fester, berechneter Tag kann ja in einer Pause liegen.
///   Dasselbe gilt für `zielKcalAm` und `kalorienzielAnteileAm`: `null`.
/// - **Während `auszeitenLaden` sind auch die Mahlzeiten „lädt“**
///   (`mahlzeitenLaedt`), und die Bilanz nennt keinen Grund
///   (`Zielstatus.keinZiel` steht nicht da) — dieselbe Folge wie bei jedem
///   anderen `zielLaedt` (Fehler `01`).
/// - **An einem festen Tag in der Pause bleibt `zielFestlegung` die
///   geltende Festlegung.** Die Pause ändert die Zahl, nicht, woher sie
///   stammt.
/// - **Die Anteile in der Pause summieren sich zum pausierten Ziel**, auch
///   am festen Tag (#314: Die Herleitung erklärt die Zahl im Ring).
/// - **`pausiertDurch` steht in `toString`** (Plan, Task 4) — geprüft wird
///   nur, dass der Name darin vorkommt, nicht die Form.
/// - **Der Verlauf wird nur über `ernaehrungsVerlaufProvider` geprüft.**
///   Wie `ernaehrungsVerlaufAus` die Auszeiten bekommt, legt diese Datei
///   nicht fest.
/// - **Der Lesefehler und das Hängen der Ereignisse werden über einen
///   überschriebenen `ereignisseProvider` erzwungen.** `auszeitenProvider`
///   bleibt der echte.
///
/// **Alle Zahlen und Tage sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“). Die Stammdaten sind so gewählt, dass der
/// Aufschlag fürs Körperziel am Deckel steht: 400 kcal.
void main() {
  const heute = '2099-06-17';
  const gestern = '2099-06-16';
  final jetzt = DateTime.utc(2099, 6, 17, 10);

  /// Körperziel 95 kg bis Mitte Dezember bei 80 kg: Die nötige Rate liegt
  /// weit über dem Deckel, der Aufschlag ist also genau 400 kcal.
  const mitKoerperziel = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 2069,
    zielgewichtKg: 95,
    zieldatum: '2099-12-15',
  );

  /// Dieselben Angaben ohne Körperziel (Entscheidung 8).
  const ohneKoerperziel = Stammdaten(groesseCm: 180, geburtsjahr: 2069);

  const aufschlag = 400.0;

  DailyMetrics tageswert(String tag) =>
      DailyMetrics(tag: tag, activeKcal: 600, basalKcal: 1600, weightKg: 80);

  Messwert<List<DailyMetrics>> tageswerteDa(List<DailyMetrics> liste) =>
      Bekannt<List<DailyMetrics>>(liste, stand: jetzt, laeuft: false);

  final standardWerte = tageswerteDa([tageswert(gestern), tageswert(heute)]);

  /// Das Ziel für heute aus dem Kern (#229: ohne gemessenen Verbrauch).
  double formelHeute({
    Stammdaten s = mitKoerperziel,
    bool inErholung = false,
  }) => kalorienziel(
    gewichtKg: 80,
    groesseCm: s.groesseCm,
    alter: s.alterAm(datumAusTag(heute)),
    zielgewichtKg: s.zielgewichtKg,
    tageBisZiel: s.zieldatum == null
        ? null
        : BerlinCalendar.daysBetween(from: heute, to: s.zieldatum!),
    inErholung: inErholung,
  )!;

  KalorienzielAnteile anteileHeute({bool inErholung = false}) =>
      kalorienzielAnteile(
        gewichtKg: 80,
        groesseCm: mitKoerperziel.groesseCm,
        alter: mitKoerperziel.alterAm(datumAusTag(heute)),
        zielgewichtKg: mitKoerperziel.zielgewichtKg,
        tageBisZiel: BerlinCalendar.daysBetween(
          from: heute,
          to: mitKoerperziel.zieldatum!,
        ),
        inErholung: inErholung,
      )!;

  // Die Auszeiten. Ids und Zeiträume erfunden.
  const opUeberHeute = AuszeitTage(
    id: 1,
    art: EreignisArt.op,
    von: '2099-06-10',
    bis: '2099-06-24',
  );
  const urlaubUeberHeute = AuszeitTage(
    id: 2,
    art: EreignisArt.urlaub,
    von: '2099-06-10',
    bis: '2099-06-24',
  );
  const opVorbei = AuszeitTage(
    id: 3,
    art: EreignisArt.op,
    von: '2099-06-01',
    bis: '2099-06-15',
  );

  // Zwei feste Ziele aus #410, deutlich anders als die Formel.
  const festBerechnet = KalorienzielFestlegung(
    abTag: '2099-06-01',
    kcal: 3000,
    herkunft: KalorienzielHerkunft.berechnet,
    anteile: KalorienzielAnteile(
      grundumsatzKcal: 1900,
      aktivKcal: 700,
      koerperzielKcal: 400,
      gemessen: false,
    ),
  );
  const festVonHand = KalorienzielFestlegung(
    abTag: '2099-06-01',
    kcal: 3300,
    herkunft: KalorienzielHerkunft.hand,
  );

  ErnaehrungsTag tag({
    String tagesSchluessel = heute,
    Stammdaten stammdaten = mitKoerperziel,
    List<KalorienzielFestlegung> kalorienziele = const [],
    List<AuszeitTage> auszeiten = const [],
    bool auszeitenLaden = false,
  }) => ernaehrungsTagAus(
    tagesSchluessel: tagesSchluessel,
    heute: heute,
    eigene: const [],
    fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
    tageswerte: standardWerte,
    stammdaten: stammdaten,
    jetzt: jetzt,
    kalorienziele: kalorienziele,
    auszeiten: auszeiten,
    auszeitenLaden: auszeitenLaden,
  );

  test('Vorbedingung: Die erfundenen Stammdaten ergeben 400 kcal '
      'Aufschlag', () {
    expect(anteileHeute().koerperzielKcal, aufschlag);
    expect(anteileHeute(inErholung: true).koerperzielKcal, 0);
  });

  // ═════════════════════════════════════════════════════════════════════
  // ernaehrungsTagAus
  // ═════════════════════════════════════════════════════════════════════

  group('ernaehrungsTagAus', () {
    test('ohne Auszeit: das Ziel wie bisher, nichts pausiert', () {
      final t = tag();
      expect(t.zielKcal, closeTo(formelHeute(), 1e-9));
      expect(t.pausiertDurch, isNull);
    });

    test('eine OP, die vor dem Tag endet, pausiert nichts', () {
      final t = tag(auszeiten: const [opVorbei]);
      expect(t.zielKcal, closeTo(formelHeute(), 1e-9));
      expect(t.pausiertDurch, isNull);
    });

    test('OP über den Tag, kein fester Tag: das Ziel ist 400 kcal niedriger, '
        'pausiert durch die OP, die Makroziele folgen', () {
      final t = tag(auszeiten: const [opUeberHeute]);
      expect(t.zielKcal, closeTo(formelHeute() - aufschlag, 1e-9));
      expect(t.zielKcal, closeTo(formelHeute(inErholung: true), 1e-9));
      expect(t.pausiertDurch, opUeberHeute);
      expect(t.zielFestlegung, isNull);
      expect(
        t.makroziele.kohlenhydrateZielG,
        makrozieleFuer(
          gewichtKg: 80,
          kalorienzielKcal: formelHeute() - aufschlag,
        ).kohlenhydrateZielG,
        reason: 'das Kohlenhydratziel ist der Rest des pausierten Ziels',
      );
      expect(t.bilanz.zielKcal, closeTo(formelHeute() - aufschlag, 1e-9));
    });

    test('Krankheit und Verletzung pausieren wie die OP '
        '(Entscheidung 3)', () {
      for (final art in [EreignisArt.krankheit, EreignisArt.verletzung]) {
        final auszeit = AuszeitTage(
          id: 7,
          art: art,
          von: '2099-06-10',
          bis: '2099-06-24',
        );
        final t = tag(auszeiten: [auszeit]);
        expect(
          t.zielKcal,
          closeTo(formelHeute() - aufschlag, 1e-9),
          reason: art.name,
        );
        expect(t.pausiertDurch, auszeit, reason: art.name);
      }
    });

    test('Urlaub über den Tag: das Ziel bleibt, nichts pausiert', () {
      final t = tag(auszeiten: const [urlaubUeberHeute]);
      expect(t.zielKcal, closeTo(formelHeute(), 1e-9));
      expect(t.pausiertDurch, isNull);
    });

    test('OP über den Tag, aber kein Körperziel eingetragen: das Ziel '
        'bleibt, nichts pausiert (Entscheidung 8)', () {
      final ohne = tag(stammdaten: ohneKoerperziel);
      expect(
        ohne.zielKcal,
        closeTo(formelHeute(s: ohneKoerperziel), 1e-9),
        reason: 'Vorbedingung',
      );

      final t = tag(
        stammdaten: ohneKoerperziel,
        auszeiten: const [opUeberHeute],
      );
      expect(t.zielKcal, ohne.zielKcal);
      expect(t.pausiertDurch, isNull);
    });

    test('fester, berechneter Tag in der OP: gespeichertes Ziel minus '
        'gespeicherter Körperziel-Anteil (V14)', () {
      final t = tag(
        kalorienziele: const [festBerechnet],
        auszeiten: const [opUeberHeute],
      );
      expect(t.zielKcal, 2600);
      expect(t.pausiertDurch, opUeberHeute);
      expect(t.zielFestlegung, festBerechnet);
      expect(t.zielLaedt, isFalse);
      expect(
        t.makroziele.kohlenhydrateZielG,
        makrozieleFuer(
          gewichtKg: 80,
          kalorienzielKcal: 2600,
        ).kohlenhydrateZielG,
      );
    });

    test('fester Tag von Hand in der OP: die Zahl von Hand bleibt, nichts '
        'pausiert (V15, Tim)', () {
      final t = tag(
        kalorienziele: const [festVonHand],
        auszeiten: const [opUeberHeute],
      );
      expect(t.zielKcal, 3300);
      expect(t.pausiertDurch, isNull);
      expect(t.zielFestlegung, festVonHand);
    });

    test('solange die Ereignisse nicht gelesen sind, steht kein Ziel da — '
        'und kein Grund (V12)', () {
      final t = tag(auszeitenLaden: true);
      expect(t.zielKcal, isNull);
      expect(t.zielLaedt, isTrue);
      expect(t.pausiertDurch, isNull);
      expect(t.mahlzeitenLaedt, isTrue);
      expect(t.bilanz.status, isNot(Zielstatus.keinZiel));
    });

    test('auch an einem festen Tag steht während des Lesens kein Ziel da '
        '(V12) — sonst spränge der Ring auf „pausiert“', () {
      final t = tag(kalorienziele: const [festBerechnet], auszeitenLaden: true);
      expect(t.zielKcal, isNull);
      expect(t.zielLaedt, isTrue);
    });

    test('pausiertDurch gehört zum Wert: ==, hashCode, toString', () {
      final a = tag(auszeiten: const [opUeberHeute]);
      final b = tag(auszeiten: const [opUeberHeute]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      const andere = AuszeitTage(
        id: 9,
        art: EreignisArt.krankheit,
        von: '2099-06-10',
        bis: '2099-06-24',
      );
      final c = tag(auszeiten: const [andere]);
      expect(c.zielKcal, a.zielKcal, reason: 'Vorbedingung: gleiche Zahl');
      expect(c, isNot(a), reason: 'nur pausiertDurch unterscheidet sie');

      expect(a.toString(), contains('pausiertDurch'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // zielKcalAm — der Verlauf
  // ═════════════════════════════════════════════════════════════════════

  group('zielKcalAm', () {
    double? ziel({
      String tagesSchluessel = gestern,
      List<KalorienzielFestlegung> kalorienziele = const [],
      List<AuszeitTage> auszeiten = const [],
      bool auszeitenLaden = false,
    }) => zielKcalAm(
      tagesSchluessel: tagesSchluessel,
      heute: heute,
      tageswerte: standardWerte,
      stammdaten: mitKoerperziel,
      kalorienziele: kalorienziele,
      auszeiten: auszeiten,
      auszeitenLaden: auszeitenLaden,
    );

    test('ein vergangener Tag in einer nachträglich eingetragenen OP rechnet '
        'ohne Aufschlag (Entscheidung 5)', () {
      expect(
        ziel(),
        closeTo(600 + 1600 + aufschlag, 1e-9),
        reason: 'Vorbedingung: gemessen plus Aufschlag (#229)',
      );
      expect(ziel(auszeiten: const [opUeberHeute]), closeTo(2200, 1e-9));
      expect(
        ziel(auszeiten: const [opUeberHeute]),
        tag(tagesSchluessel: gestern, auszeiten: const [opUeberHeute]).zielKcal,
        reason: 'dieselbe Zahl wie der Tag-Schirm',
      );
    });

    test('Urlaub ändert nichts', () {
      expect(ziel(auszeiten: const [urlaubUeberHeute]), ziel());
    });

    test('fester, berechneter Tag in der OP: ohne den gespeicherten '
        'Anteil', () {
      expect(
        ziel(
          kalorienziele: const [festBerechnet],
          auszeiten: const [opUeberHeute],
        ),
        2600,
      );
    });

    test('fester Tag von Hand in der OP: die Zahl von Hand', () {
      expect(
        ziel(
          kalorienziele: const [festVonHand],
          auszeiten: const [opUeberHeute],
        ),
        3300,
      );
    });

    test('solange die Ereignisse nicht gelesen sind: null', () {
      expect(ziel(auszeitenLaden: true), isNull);
      expect(
        ziel(kalorienziele: const [festBerechnet], auszeitenLaden: true),
        isNull,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // kalorienzielAnteileAm — die Herleitung
  // ═════════════════════════════════════════════════════════════════════

  group('kalorienzielAnteileAm', () {
    KalorienzielAnteile? anteile({
      String tagesSchluessel = heute,
      Stammdaten stammdaten = mitKoerperziel,
      List<KalorienzielFestlegung> kalorienziele = const [],
      List<AuszeitTage> auszeiten = const [],
      bool auszeitenLaden = false,
    }) => kalorienzielAnteileAm(
      tagesSchluessel: tagesSchluessel,
      heute: heute,
      tageswerte: standardWerte,
      stammdaten: stammdaten,
      kalorienziele: kalorienziele,
      auszeiten: auszeiten,
      auszeitenLaden: auszeitenLaden,
    );

    test('in der OP ist der Körperziel-Anteil 0, Grundumsatz und Aktiv '
        'bleiben', () {
      final ohne = anteile()!;
      expect(ohne.koerperzielKcal, aufschlag, reason: 'Vorbedingung');

      final mit = anteile(auszeiten: const [opUeberHeute])!;
      expect(mit.koerperzielKcal, 0);
      expect(mit.grundumsatzKcal, ohne.grundumsatzKcal);
      expect(mit.aktivKcal, ohne.aktivKcal);
      expect(
        mit.summeKcal,
        closeTo(tag(auszeiten: const [opUeberHeute]).zielKcal!, 1e-9),
        reason: 'die Herleitung erklärt die Zahl im Ring (#314)',
      );
    });

    test('ein vergangener Tag in der OP: ebenfalls 0', () {
      expect(
        anteile(
          tagesSchluessel: gestern,
          auszeiten: const [opUeberHeute],
        )!.koerperzielKcal,
        0,
      );
    });

    test('Urlaub ändert nichts', () {
      expect(anteile(auszeiten: const [urlaubUeberHeute]), anteile());
    });

    test('fester, berechneter Tag in der OP: die gespeicherten Anteile, '
        'Körperziel 0', () {
      final a = anteile(
        kalorienziele: const [festBerechnet],
        auszeiten: const [opUeberHeute],
      );
      expect(
        a,
        const KalorienzielAnteile(
          grundumsatzKcal: 1900,
          aktivKcal: 700,
          koerperzielKcal: 0,
          gemessen: false,
        ),
      );
      expect(a!.summeKcal, 2600);
    });

    test('fester Tag von Hand in der OP: keine Anteile', () {
      expect(
        anteile(
          kalorienziele: const [festVonHand],
          auszeiten: const [opUeberHeute],
        ),
        isNull,
      );
    });

    test('solange die Ereignisse nicht gelesen sind: null', () {
      expect(anteile(auszeitenLaden: true), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Im Riverpod-Baum, mit echter Datenbank
  // ═════════════════════════════════════════════════════════════════════

  group('Im Riverpod-Baum', () {
    ({ProviderContainer container, AppCache db}) behaelter({
      Messwert<List<DailyMetrics>>? tageswerte,
      EreignisseNotifier Function()? ereignisse,
    }) {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          stammdatenProvider.overrideWith(() => _Stammdaten(mitKoerperziel)),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(tageswerte ?? standardWerte),
          ),
          fremdeMahlzeitenProvider.overrideWith2(
            (tag) =>
                _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
          ),
          if (ereignisse != null) ereignisseProvider.overrideWith(ereignisse),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, db: db);
    }

    /// Legt eine OP ab, **bevor** irgendein Provider liest.
    Future<int> legeOpAn(AppCache db, {required String von, String? bis}) =>
        EreignisRepository(
          db,
          uhr: () => jetzt,
        ).legeAn(Ereignis(art: EreignisArt.op, von: von, bis: bis ?? von));

    Future<void> laufenLassen() async {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    Future<void> bis(bool Function() bedingung) async {
      for (var i = 0; i < 300 && !bedingung(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    void beobachte(ProviderContainer c, String tagesSchluessel) =>
        c.listen(ernaehrungsTagProvider(tagesSchluessel), (_, _) {});

    test('Festlegen in einer laufenden OP speichert den vollen Aufschlag — '
        'die Pause wirkt beim Anzeigen, nie beim Speichern (V13)', () async {
      final b = behaelter();
      await legeOpAn(b.db, von: '2099-06-10', bis: '2099-06-24');
      beobachte(b.container, heute);
      await bis(
        () =>
            b.container.read(kalorienzieleProvider).value?.isNotEmpty ?? false,
      );
      await laufenLassen();

      final f = (await KalorienzielRepository(b.db).alle()).single;
      expect(f.abTag, heute);
      expect(f.herkunft, KalorienzielHerkunft.berechnet);
      expect(f.kcal, closeTo(formelHeute(), 1e-9));
      expect(f.anteile, anteileHeute());
      expect(f.anteile!.koerperzielKcal, aufschlag);

      final t = b.container.read(ernaehrungsTagProvider(heute));
      expect(t.zielKcal, closeTo(f.kcal - aufschlag, 1e-9));
      expect(t.pausiertDurch?.art, EreignisArt.op);
      expect(t.zielFestlegung, f);
    });

    test('eine OP anlegen senkt das Ziel des Tages ohne Neustart, löschen '
        'hebt es wieder', () async {
      final b = behaelter();
      beobachte(b.container, gestern);
      await bis(
        () =>
            b.container.read(ernaehrungsTagProvider(gestern)).zielKcal != null,
      );
      await laufenLassen();
      expect(
        b.container.read(ernaehrungsTagProvider(gestern)).zielKcal,
        closeTo(2600, 1e-9),
        reason: 'Vorbedingung: gemessen plus Aufschlag',
      );

      final id = await b.container
          .read(ereignisseProvider.notifier)
          .legeAn(
            const Ereignis(
              art: EreignisArt.op,
              von: '2099-06-15',
              bis: '2099-06-29',
            ),
          );
      await laufenLassen();

      final pausiert = b.container.read(ernaehrungsTagProvider(gestern));
      expect(pausiert.zielKcal, closeTo(2200, 1e-9));
      expect(pausiert.pausiertDurch?.id, id);

      await b.container.read(ereignisseProvider.notifier).loesche(id);
      await laufenLassen();

      final wieder = b.container.read(ernaehrungsTagProvider(gestern));
      expect(wieder.zielKcal, closeTo(2600, 1e-9));
      expect(wieder.pausiertDurch, isNull);
    });

    test('die Herleitung im Baum: Körperziel 0 in der OP', () async {
      final b = behaelter();
      await legeOpAn(b.db, von: gestern);
      b.container.listen(ernaehrungsHerleitungProvider(gestern), (_, _) {});
      await bis(
        () =>
            b.container
                .read(ernaehrungsHerleitungProvider(gestern))
                ?.koerperzielKcal ==
            0,
      );

      final a = b.container.read(ernaehrungsHerleitungProvider(gestern));
      expect(a?.koerperzielKcal, 0);
      expect(a?.summeKcal, closeTo(2200, 1e-9));
    });

    test(
      'der Verlauf rechnet die Tage einer nachträglich eingetragenen OP '
      'ohne Aufschlag, beide Enden eingeschlossen (Entscheidung 5)',
      () async {
        final b = behaelter(
          tageswerte: tageswerteDa([
            for (final t in verlaufFenster(gestern)) tageswert(t),
            tageswert(heute),
          ]),
        );
        await legeOpAn(b.db, von: '2099-06-10', bis: '2099-06-12');
        b.container.listen(ernaehrungsVerlaufProvider(gestern), (_, _) {});
        await bis(
          () => b.container
              .read(ernaehrungsVerlaufProvider(gestern))
              .tage
              .any((t) => t.zielKcal == 2200),
        );
        await laufenLassen();

        final v = b.container.read(ernaehrungsVerlaufProvider(gestern));
        for (final t in v.tage) {
          final inOp =
              t.tag.compareTo('2099-06-10') >= 0 &&
              t.tag.compareTo('2099-06-12') <= 0;
          expect(t.zielKcal, closeTo(inOp ? 2200 : 2600, 1e-9), reason: t.tag);
        }
      },
    );

    test('solange die Ereignisse nicht gelesen sind, steht im Baum kein Ziel '
        '— auch wenn Health und Historie längst da sind (V12)', () async {
      final b = behaelter(ereignisse: _HaengendeEreignisse.new);
      beobachte(b.container, gestern);
      b.container.listen(ernaehrungsHerleitungProvider(gestern), (_, _) {});
      await bis(() => b.container.read(kalorienzieleProvider).hasValue);
      await laufenLassen();

      final t = b.container.read(ernaehrungsTagProvider(gestern));
      expect(t.zielKcal, isNull);
      expect(t.zielLaedt, isTrue);
      expect(t.pausiertDurch, isNull);
      expect(b.container.read(ernaehrungsHerleitungProvider(gestern)), isNull);
    });

    test('scheitert das Lesen der Ereignisse, wird ohne Pause gerechnet '
        '(V12)', () async {
      final b = behaelter(ereignisse: _KaputteEreignisse.new);
      beobachte(b.container, gestern);
      await bis(
        () =>
            b.container.read(ernaehrungsTagProvider(gestern)).zielKcal != null,
      );
      await laufenLassen();

      final t = b.container.read(ernaehrungsTagProvider(gestern));
      expect(t.zielKcal, closeTo(2600, 1e-9));
      expect(t.zielLaedt, isFalse);
      expect(t.pausiertDurch, isNull);
    });
  });
}

/// Steuerbare Ableger der echten Notifier — wie in
/// `kalorienziel_fest_test.dart`.
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

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

/// Ereignisse, deren erstes Lesen nie fertig wird.
class _HaengendeEreignisse extends EreignisseNotifier {
  @override
  Future<List<Ereignis>> build() => Completer<List<Ereignis>>().future;
}

/// Ereignisse, deren Lesen scheitert.
class _KaputteEreignisse extends EreignisseNotifier {
  @override
  Future<List<Ereignis>> build() async =>
      throw StateError('Tabelle nicht lesbar');
}
