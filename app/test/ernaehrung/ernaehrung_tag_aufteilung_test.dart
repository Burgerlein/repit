import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **das Ziel und den Anteil je Mahlzeit am Ernährungstag**
/// (#432 unter #374) — `ernaehrungsTagAus` und `ernaehrungsTagProvider` in
/// `lib/ernaehrung/ernaehrung_provider.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbarn: `data/mahlzeit_aufteilungen_test.dart` (Repository und
/// `mahlzeitAufteilungenProvider`), `ernaehrung_tag_test.dart` (der Tag
/// ohne Aufteilung — bleibt grün und unberührt). Die Rechnungen selbst
/// (`geltendeAufteilung`, `mahlzeitZielKcal`, `mahlzeitAnteil`) prüft der
/// Kern; hier geht es darum, dass der Tag sie **mit den richtigen
/// Eingängen** aufruft und das Ergebnis hält.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Der Tag kennt das Ziel je Mahlzeit", und Plan Task 3. Von Tim
/// am 10.11.2026 übernommen:
///
/// - **Entscheidung 1:** Ohne gesicherte Aufteilung hat keine Mahlzeit ein
///   Ziel. Kein Startwert als Ersatz.
/// - **Entscheidung 5:** Eine neue Aufteilung gilt ab heute, frühere Tage
///   behalten ihre.
/// - **V4:** Eine Mahlzeit mit 0 % hat kein Ziel.
/// - **V5:** Das Tagesziel ist `ErnaehrungsTag.zielKcal`, gerechnet wird
///   ungerundet.
/// - **V6:** Ohne Eintrag ist der Anteil 0, mit Eintrag ohne
///   Kalorienangabe `null`.
/// - **V9:** Die Liste lädt (`mahlzeitenLaedt`), solange die eigenen
///   Einträge oder die Aufteilungen keinen Wert haben oder das Tagesziel
///   lädt. Solange ist jedes `zielKcal` und jedes `anteil` `null`.
/// - **Regel 2 (`CLAUDE.md`):** Ziel und Anteil rechnet der Provider und
///   hält sie, nicht die Zeile je Bild.
///
/// ## API — aus dem Plan (Task 3, „Interfaces")
///
/// ```dart
/// ErnaehrungsTag ernaehrungsTagAus({…,
///     List<AufteilungAb> aufteilungen = const [],
///     bool aufteilungenLaden = false,
///     bool eintraegeLaden = false});
/// class ErnaehrungsTag {
///   final MahlzeitAufteilung? aufteilung;   // Vorgabe null
///   final bool mahlzeitenLaedt;             // Vorgabe false
/// }
/// class MahlzeitZeile {
///   final double? zielKcal;                 // Vorgabe null
///   final double? anteil;                   // Vorgabe null
/// }
/// ```
///
/// Alle neuen Felder stehen in `==` und `hashCode`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Lädt die Aufteilung, ist `ErnaehrungsTag.aufteilung` `null`, auch
///   wenn eine Liste mit hereingegeben wird** — „laden" gewinnt, wie
///   `kalorienzieleLaden` beim festen Ziel. Die Spec sagt „`null` ohne oder
///   solange geladen wird".
/// - **Ohne Kalorienziel, aber mit Aufteilung, steht die Aufteilung am Tag**
///   (`aufteilung != null`), nur die Ziele je Mahlzeit fehlen. Daran
///   erkennt die Liste nach V9, dass „Ziel je Mahlzeit festlegen" **nicht**
///   stehen soll.
/// - **Die Provider-Fälle legen das Tagesziel als feste Festlegung von Hand
///   ab** (1.800 kcal), damit das Ziel nicht lädt und genau eine Quelle das
///   Laden der Liste bestimmt.
///
/// **Alle Zahlen und Daten hier sind erfunden**, Zeitpunkte im Jahr 2099.
void main() {
  // Mittwoch, 11.03.2099, 11:00 Berliner Zeit (MEZ, +1).
  const heute = '2099-03-11';
  const gestern = '2099-03-10';
  const vorgestern = '2099-03-09';
  final jetzt = DateTime.utc(2099, 3, 11, 10);

  /// Ein festes Tagesziel von Hand, gültig lange vor allen Tagen hier —
  /// damit `zielKcal` genau 1.800 ist und nicht lädt.
  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );

  final a = MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30);
  final b = MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30);
  final ohneSnack = MahlzeitAufteilung(fruehstueck: 30, mittag: 35, abend: 35);

  final aAbGestern = AufteilungAb(abTag: gestern, aufteilung: a);
  final bAbHeute = AufteilungAb(abTag: heute, aufteilung: b);

  Eintrag eintrag({
    required int id,
    required Mahlzeit mahlzeit,
    required double? kcal,
    String tag = heute,
    int stundeUtc = 8,
  }) => Eintrag(
    id: id,
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2099, 3, 11, stundeUtc),
    name: 'Testgericht $id',
    naehrwerte: Naehrwerte(kcal: kcal),
  );

  ErnaehrungsTag tag({
    String tagesSchluessel = heute,
    List<Eintrag> eigene = const [],
    List<AufteilungAb> aufteilungen = const [],
    bool aufteilungenLaden = false,
    bool eintraegeLaden = false,
    List<KalorienzielFestlegung> kalorienziele = const [ziel1800],
    bool kalorienzieleLaden = false,
    Messwert<List<DailyMetrics>>? tageswerte,
  }) => ernaehrungsTagAus(
    tagesSchluessel: tagesSchluessel,
    heute: heute,
    eigene: eigene,
    fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
    tageswerte: tageswerte ?? LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
    stammdaten: const Stammdaten(),
    jetzt: jetzt,
    kalorienziele: kalorienziele,
    kalorienzieleLaden: kalorienzieleLaden,
    aufteilungen: aufteilungen,
    aufteilungenLaden: aufteilungenLaden,
    eintraegeLaden: eintraegeLaden,
  );

  MahlzeitZeile zeile(ErnaehrungsTag t, Mahlzeit m) =>
      t.mahlzeiten.singleWhere((z) => z.mahlzeit == m);

  void keinZielNirgends(ErnaehrungsTag t, {String? reason}) {
    for (final z in t.mahlzeiten) {
      expect(z.zielKcal, isNull, reason: '${z.mahlzeit.name}: $reason');
      expect(z.anteil, isNull, reason: '${z.mahlzeit.name}: $reason');
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // Die reine Funktion
  // ═════════════════════════════════════════════════════════════════════

  group('Ohne Aufteilung (Entscheidung 1)', () {
    test('keine Mahlzeit hat ein Ziel oder einen Anteil — auch mit '
        'Tagesziel und Eintrag', () {
      final t = tag(
        eigene: [eintrag(id: 1, mahlzeit: Mahlzeit.fruehstueck, kcal: 426)],
      );

      expect(t.zielKcal, 1800, reason: 'Vorbedingung: das Tagesziel steht');
      expect(t.aufteilung, isNull);
      expect(t.mahlzeitenLaedt, isFalse);
      keinZielNirgends(t, reason: 'kein Startwert als Ersatz');
    });

    test('wer die neuen Parameter nicht übergibt, bekommt denselben Tag — '
        'die Vorgaben sind „keine Aufteilung, lädt nicht"', () {
      final t = ernaehrungsTagAus(
        tagesSchluessel: heute,
        heute: heute,
        eigene: const [],
        fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        stammdaten: const Stammdaten(),
        jetzt: jetzt,
        kalorienziele: const [ziel1800],
      );

      expect(t.aufteilung, isNull);
      expect(t.mahlzeitenLaedt, isFalse);
      keinZielNirgends(t, reason: 'Vorgabe ohne Aufteilung');
    });

    test('eine Zeile ohne die neuen Felder trägt null, nicht 0', () {
      const z = MahlzeitZeile(
        mahlzeit: Mahlzeit.abend,
        eigene: [],
        fremde: [],
        summe: Naehrwerte(kcal: 0),
      );
      expect(z.zielKcal, isNull);
      expect(z.anteil, isNull);
    });
  });

  group('Mit Aufteilung 25 · 35 · 30 · 10 und Tagesziel 1.800', () {
    test('jede Mahlzeit hat ihr Ziel aus dem Tagesziel', () {
      final t = tag(aufteilungen: [aAbGestern]);

      expect(t.aufteilung, a);
      expect(t.mahlzeitenLaedt, isFalse);
      expect(zeile(t, Mahlzeit.fruehstueck).zielKcal, 450);
      expect(zeile(t, Mahlzeit.mittag).zielKcal, 630);
      expect(zeile(t, Mahlzeit.abend).zielKcal, 540);
      expect(zeile(t, Mahlzeit.snack).zielKcal, 180);
    });

    test('Frühstück mit 426 kcal aus zwei Einträgen: Anteil 0,95', () {
      final t = tag(
        aufteilungen: [aAbGestern],
        eigene: [
          eintrag(id: 1, mahlzeit: Mahlzeit.fruehstueck, kcal: 200),
          eintrag(id: 2, mahlzeit: Mahlzeit.fruehstueck, kcal: 226),
        ],
      );

      expect(zeile(t, Mahlzeit.fruehstueck).anteil, 0.95);
    });

    test('Abend ohne Eintrag: Anteil 0, nicht null — das Ziel steht, '
        'gegessen ist nichts (V6)', () {
      final t = tag(aufteilungen: [aAbGestern]);

      expect(zeile(t, Mahlzeit.abend).zielKcal, 540);
      expect(zeile(t, Mahlzeit.abend).anteil, 0);
    });

    test('über dem Ziel geht der Anteil über 1: Mittag 672 / 630 → 1,07', () {
      final t = tag(
        aufteilungen: [aAbGestern],
        eigene: [eintrag(id: 1, mahlzeit: Mahlzeit.mittag, kcal: 672)],
      );

      expect(zeile(t, Mahlzeit.mittag).anteil, 1.07);
    });

    test('mit Eintrag ohne Kalorienangabe: Ziel ja, Anteil null (V6)', () {
      final t = tag(
        aufteilungen: [aAbGestern],
        eigene: [eintrag(id: 1, mahlzeit: Mahlzeit.mittag, kcal: null)],
      );

      expect(zeile(t, Mahlzeit.mittag).zielKcal, 630);
      expect(zeile(t, Mahlzeit.mittag).anteil, isNull);
    });

    test('Snack bei 0 %: kein Ziel, kein Anteil — auch mit Eintrag (V4)', () {
      final t = tag(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: ohneSnack)],
        eigene: [eintrag(id: 1, mahlzeit: Mahlzeit.snack, kcal: 162)],
      );

      expect(zeile(t, Mahlzeit.snack).zielKcal, isNull);
      expect(zeile(t, Mahlzeit.snack).anteil, isNull);
      expect(zeile(t, Mahlzeit.abend).zielKcal, 630);
    });

    test('das Tagesziel ist ErnaehrungsTag.zielKcal und wird ungerundet '
        'geteilt (V5)', () {
      final t = tag(
        aufteilungen: [aAbGestern],
        kalorienziele: const [
          KalorienzielFestlegung(
            abTag: '2099-01-01',
            kcal: 2617,
            herkunft: KalorienzielHerkunft.hand,
          ),
        ],
      );

      expect(t.zielKcal, 2617);
      expect(zeile(t, Mahlzeit.mittag).zielKcal, closeTo(915.95, 1e-9));
    });

    test('ohne Tagesziel, aber mit Aufteilung: die Aufteilung steht am Tag, '
        'kein Ziel je Mahlzeit, und es lädt nichts', () {
      final t = tag(aufteilungen: [aAbGestern], kalorienziele: const []);

      expect(t.zielKcal, isNull, reason: 'Vorbedingung: kein Tagesziel');
      expect(t.zielLaedt, isFalse, reason: 'Vorbedingung: Health ist durch');
      expect(t.aufteilung, a);
      expect(t.mahlzeitenLaedt, isFalse);
      keinZielNirgends(t, reason: 'ohne Tagesziel kein Ziel je Mahlzeit');
    });
  });

  group('Eine neue Aufteilung gilt ab heute (Entscheidung 5)', () {
    test('A ab gestern, B ab heute: gestern rechnet mit A, heute mit B — '
        'auch unsortiert übergeben', () {
      final historie = [bAbHeute, aAbGestern];

      final g = tag(tagesSchluessel: gestern, aufteilungen: historie);
      expect(g.aufteilung, a);
      expect(zeile(g, Mahlzeit.fruehstueck).zielKcal, 450);

      final h = tag(tagesSchluessel: heute, aufteilungen: historie);
      expect(h.aufteilung, b);
      expect(zeile(h, Mahlzeit.fruehstueck).zielKcal, 360);
    });

    test('ein Tag vor der ersten Aufteilung hat keine — nicht die heutige, '
        'nicht den Startwert', () {
      final t = tag(
        tagesSchluessel: vorgestern,
        aufteilungen: [aAbGestern, bAbHeute],
      );

      expect(t.aufteilung, isNull);
      keinZielNirgends(t, reason: 'vor der ersten Aufteilung');
    });
  });

  group('Laden sieht nicht aus wie leer (V9)', () {
    test('Aufteilungen noch nicht gelesen: lädt, keine Aufteilung, kein '
        'Ziel, kein Anteil', () {
      final t = tag(aufteilungen: [aAbGestern], aufteilungenLaden: true);

      expect(t.mahlzeitenLaedt, isTrue);
      expect(t.aufteilung, isNull);
      keinZielNirgends(
        t,
        reason: 'während des Ladens steht kein Ziel und keine 0',
      );
    });

    test('eigene Einträge noch nicht gelesen: lädt, kein Ziel, kein '
        'Anteil — kein „Abend 0" vor dem ersten Lesen', () {
      final t = tag(aufteilungen: [aAbGestern], eintraegeLaden: true);

      expect(t.mahlzeitenLaedt, isTrue);
      keinZielNirgends(t, reason: 'Einträge laden noch');
    });

    test('Tagesziel lädt (Kalorienziele noch nicht gelesen): lädt', () {
      final t = tag(aufteilungen: [aAbGestern], kalorienzieleLaden: true);

      expect(t.zielLaedt, isTrue, reason: 'Vorbedingung');
      expect(t.mahlzeitenLaedt, isTrue);
      keinZielNirgends(t, reason: 'das Tagesziel lädt');
    });

    test('Tagesziel lädt (Health noch nie gelaufen, kein festes Ziel): '
        'lädt', () {
      final t = tag(
        aufteilungen: [aAbGestern],
        kalorienziele: const [],
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );

      expect(t.zielLaedt, isTrue, reason: 'Vorbedingung');
      expect(t.mahlzeitenLaedt, isTrue);
      keinZielNirgends(t, reason: 'das Tagesziel lädt');
    });

    test('alles gelesen: lädt nicht', () {
      expect(tag(aufteilungen: [aAbGestern]).mahlzeitenLaedt, isFalse);
      expect(tag().mahlzeitenLaedt, isFalse);
    });
  });

  group('Gleichheit', () {
    test('zwei gleich gebaute Tage sind gleich, samt hashCode', () {
      ErnaehrungsTag bau() => tag(
        aufteilungen: [aAbGestern],
        eigene: [eintrag(id: 1, mahlzeit: Mahlzeit.fruehstueck, kcal: 426)],
      );

      expect(bau(), bau());
      expect(bau().hashCode, bau().hashCode);
    });

    test('nur die Aufteilung verschieden → ungleich', () {
      // Ohne Tagesziel sind alle Zeilen gleich (kein Ziel, kein Anteil) —
      // der Unterschied steckt allein in `aufteilung`.
      final mitA = tag(aufteilungen: [aAbGestern], kalorienziele: const []);
      final mitB = tag(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: b)],
        kalorienziele: const [],
      );

      expect(mitA.mahlzeiten, mitB.mahlzeiten, reason: 'Vorbedingung');
      expect(mitA, isNot(mitB));
    });

    test('nur mahlzeitenLaedt verschieden → ungleich', () {
      final fertig = tag();
      final laedt = tag(eintraegeLaden: true);

      expect(fertig.mahlzeiten, laedt.mahlzeiten, reason: 'Vorbedingung');
      expect(fertig, isNot(laedt));
    });

    test('Zeilen vergleichen über zielKcal und anteil', () {
      MahlzeitZeile z({double? zielKcal, double? anteil}) => MahlzeitZeile(
        mahlzeit: Mahlzeit.fruehstueck,
        eigene: const [],
        fremde: const [],
        summe: const Naehrwerte(kcal: 0),
        zielKcal: zielKcal,
        anteil: anteil,
      );

      expect(z(zielKcal: 450, anteil: 0), z(zielKcal: 450, anteil: 0));
      expect(
        z(zielKcal: 450, anteil: 0).hashCode,
        z(zielKcal: 450, anteil: 0).hashCode,
      );
      expect(z(zielKcal: 450, anteil: 0), isNot(z(zielKcal: 540, anteil: 0)));
      expect(z(zielKcal: 450, anteil: 0), isNot(z(zielKcal: 450, anteil: 1)));
      expect(z(zielKcal: 450, anteil: 0), isNot(z(zielKcal: 450)));
      expect(z(), isNot(z(zielKcal: 450)));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Im Riverpod-Baum, mit echter Datenbank
  // ═════════════════════════════════════════════════════════════════════

  group('Im Riverpod-Baum', () {
    ({ProviderContainer container, AppCache db}) behaelter({
      bool aufteilungenAntwortenNie = false,
      bool eintraegeAntwortenNie = false,
    }) {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          stammdatenProvider.overrideWith(
            () => _Stammdaten(const Stammdaten()),
          ),
          dailyMetricsProvider.overrideWith(
            () =>
                _Tageswerte(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt)),
          ),
          fremdeMahlzeitenProvider.overrideWith2(
            (tag) =>
                _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
          ),
          if (aufteilungenAntwortenNie)
            mahlzeitAufteilungenProvider.overrideWith(_NieAufteilungen.new),
          if (eintraegeAntwortenNie)
            eigeneEintraegeProvider.overrideWith2(_NieEintraege.new),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, db: db);
    }

    /// Legt das feste Tagesziel und [aufteilungen] ab, **bevor** irgendein
    /// Provider liest.
    Future<({ProviderContainer container, AppCache db})> vorbelegt({
      List<AufteilungAb> aufteilungen = const [],
      bool aufteilungenAntwortenNie = false,
      bool eintraegeAntwortenNie = false,
    }) async {
      final b = behaelter(
        aufteilungenAntwortenNie: aufteilungenAntwortenNie,
        eintraegeAntwortenNie: eintraegeAntwortenNie,
      );
      await KalorienzielRepository(b.db).setze(ziel1800);
      final repo = MahlzeitAufteilungRepository(b.db);
      for (final x in aufteilungen) {
        await repo.setze(x);
      }
      return b;
    }

    /// Wartet, bis [bedingung] gilt, höchstens eine Weile.
    Future<void> bis(bool Function() bedingung) async {
      for (var i = 0; i < 300 && !bedingung(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    /// Lässt die Läufe arbeiten, ohne festzulegen, wie viele Schritte sie
    /// brauchen.
    Future<void> laufenLassen() async {
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    ErnaehrungsTag lies(ProviderContainer c) =>
        c.read(ernaehrungsTagProvider(heute));

    test('solange die Aufteilungen nicht gelesen sind, lädt die Liste — '
        'kein Ziel, kein Anteil (V9)', () async {
      final b = await vorbelegt(
        aufteilungen: [aAbGestern],
        aufteilungenAntwortenNie: true,
      );
      final c = b.container;
      c.listen(ernaehrungsTagProvider(heute), (_, _) {});

      await bis(
        () =>
            c.read(kalorienzieleProvider).hasValue &&
            c.read(eigeneEintraegeProvider(heute)).hasValue,
      );
      await laufenLassen();

      final t = lies(c);
      expect(
        t.zielLaedt,
        isFalse,
        reason: 'Vorbedingung: das Tagesziel steht, nur die Aufteilung fehlt',
      );
      expect(t.zielKcal, 1800, reason: 'Vorbedingung');
      expect(t.mahlzeitenLaedt, isTrue);
      expect(t.aufteilung, isNull);
      keinZielNirgends(t, reason: 'die Aufteilungen sind nicht gelesen');
    });

    test('solange die eigenen Einträge nicht gelesen sind, lädt die Liste '
        '(V9)', () async {
      final b = await vorbelegt(
        aufteilungen: [aAbGestern],
        eintraegeAntwortenNie: true,
      );
      final c = b.container;
      c.listen(ernaehrungsTagProvider(heute), (_, _) {});

      await bis(
        () =>
            c.read(kalorienzieleProvider).hasValue &&
            c.read(mahlzeitAufteilungenProvider).hasValue,
      );
      await laufenLassen();

      final t = lies(c);
      expect(t.zielLaedt, isFalse, reason: 'Vorbedingung');
      expect(t.mahlzeitenLaedt, isTrue);
      keinZielNirgends(t, reason: 'die Einträge sind nicht gelesen');
    });

    test(
      'ist alles gelesen, steht das Ziel je Mahlzeit aus der Tabelle',
      () async {
        final b = await vorbelegt(aufteilungen: [aAbGestern]);
        final c = b.container;
        c.listen(ernaehrungsTagProvider(heute), (_, _) {});

        await bis(() => !lies(c).mahlzeitenLaedt);

        final t = lies(c);
        expect(t.mahlzeitenLaedt, isFalse);
        expect(t.aufteilung, a);
        expect(zeile(t, Mahlzeit.fruehstueck).zielKcal, 450);
        expect(zeile(t, Mahlzeit.abend).zielKcal, 540);
        expect(
          zeile(t, Mahlzeit.abend).anteil,
          0,
          reason: 'gelesen und nichts eingetragen',
        );
      },
    );

    test('ohne gesicherte Aufteilung kein Ziel — nach dem Sichern steht es '
        'ohne Neustart da, ab heute', () async {
      final b = await vorbelegt();
      final c = b.container;
      c.listen(ernaehrungsTagProvider(heute), (_, _) {});

      await bis(() => !lies(c).mahlzeitenLaedt);
      final vorher = lies(c);
      expect(vorher.mahlzeitenLaedt, isFalse);
      expect(vorher.aufteilung, isNull);
      keinZielNirgends(vorher, reason: 'kein Startwert als Ersatz');

      await c.read(mahlzeitAufteilungenProvider.notifier).setzeAbHeute(a);
      await bis(() => lies(c).aufteilung != null);

      final nachher = lies(c);
      expect(nachher.aufteilung, a);
      expect(zeile(nachher, Mahlzeit.fruehstueck).zielKcal, 450);
      expect(
        lies(c),
        same(nachher),
        reason: 'gehalten, nicht bei jedem Zugriff neu gebaut (Regel 2)',
      );
      expect(
        c.read(ernaehrungsTagProvider(gestern)).aufteilung,
        isNull,
        reason: 'ab heute — gestern behält, was es hatte (Entscheidung 5)',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — Riverpods Provider-Typen sind
/// invariant, ein eigenständiger `AsyncNotifier` erfüllt die
/// `overrideWith`-Signatur nicht (siehe `ernaehrung_provider_test.dart`).
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

/// Eine Attrappe, die nie antwortet: Die Aufteilungen bleiben „noch nicht
/// gelesen".
class _NieAufteilungen extends MahlzeitAufteilungenNotifier {
  @override
  Future<List<AufteilungAb>> build() => Completer<List<AufteilungAb>>().future;
}

/// Eine Attrappe, die nie antwortet: Die eigenen Einträge bleiben „noch
/// nicht gelesen".
class _NieEintraege extends EigeneEintraegeNotifier {
  _NieEintraege(super.tagesSchluessel);

  @override
  Future<List<Eintrag>> build() => Completer<List<Eintrag>>().future;
}
