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
import 'package:repit/ernaehrung/mahlzeit_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **das Ziel dieser Mahlzeit im Mahlzeit-Inhalt** (#442 unter
/// #385, Schnitt 3) — `MahlzeitInhalt` und `mahlzeitProvider` in
/// `lib/ernaehrung/mahlzeit_provider.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, wird das **gemeldet, nicht
/// korrigiert.**
///
/// Nachbarn: `mahlzeit_inhalt_test.dart` (Inhalt, Summe, `laedt` — bleibt
/// unberührt), `ernaehrung/ernaehrung_tag_aufteilung_test.dart` (Ziel und
/// Anteil je Mahlzeit am Tag). Gerechnet wird dort; hier geht es darum,
/// dass der Mahlzeit-Inhalt **dieselben** Zahlen weiterreicht und hält,
/// statt sie ein zweites Mal zu rechnen.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// „Der Tag kennt das Ziel je Mahlzeit" (letzter Punkt) und „Mahlzeit-Detail
/// (Schnitt 3)"; Plan `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`,
/// Task 13, Step 1. Von Tim am 10.11.2026 übernommen:
///
/// - **Entscheidung 1:** Ohne gesicherte Aufteilung hat keine Mahlzeit ein
///   Ziel. Kein Startwert als Ersatz.
/// - **Entscheidung 5:** Eine neue Aufteilung gilt ab heute.
/// - **V4:** Eine Mahlzeit mit 0 % hat kein Ziel; der Schirm sagt
///   „0 % deines Tagesziels — so eingestellt". Dafür braucht er die `0`.
/// - **V5:** Das Tagesziel ist `ErnaehrungsTag.zielKcal`.
/// - **V19:** Der Satz unter dem Balken nennt Prozent und Tagesziel, ohne
///   Tagesziel nur das Prozent, ohne Aufteilung den Weg zur Einstellung.
/// - **Regel 2 (`CLAUDE.md`):** gehalten, nicht je Bild gerechnet.
///
/// ## API — aus dem Plan (Task 13, „Interfaces")
///
/// ```dart
/// class MahlzeitInhalt {
///   final double? zielKcal;          // MahlzeitZeile.zielKcal
///   final int? prozent;              // Anteil dieser Mahlzeit in der
///                                    // geltenden Aufteilung
///   final double? tageszielKcal;     // ErnaehrungsTag.zielKcal (V5)
///   final bool aufteilungGesichert;  // ErnaehrungsTag.aufteilung != null
/// }
/// ```
///
/// Alle in `==` und `hashCode`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Ein fünftes Feld `bool zielLaedt`**, ebenfalls in `==` und
///   `hashCode`. Es ist `ErnaehrungsTag.mahlzeitenLaedt` (V9): Einträge,
///   Aufteilungen oder Tagesziel sind noch nicht gelesen. **Ohne dieses
///   Feld könnte der Schirm „Aufteilungen noch nicht gelesen" nicht von
///   „keine Aufteilung" unterscheiden** — `aufteilungGesichert` ist in
///   beiden Fällen `false`, `MahlzeitInhalt.laedt` liest nur die eigenen
///   Einträge (siehe dessen Doc-Kommentar) und bleibt dabei `false`. Der
///   Schirm zeigte dann während des Ladens „Aufteilung des Tagesziels
///   festlegen ›": Fehler `01`. `laedt` selbst wird **nicht** umgedeutet;
///   `mahlzeit_inhalt_test.dart` legt seine Bedeutung fest.
/// - **Die neuen Konstruktor-Parameter sind benannt.** Ob mit Vorgabe oder
///   `required`, lässt diese Datei offen — sie übergibt immer alle.
/// - **`tageszielKcal` steht auch ohne Aufteilung**, denn es ist das
///   Tagesziel und keine Rechnung über die Aufteilung (V5).
/// - **Solange die Aufteilungen nicht gelesen sind**, ist
///   `aufteilungGesichert` `false` und `prozent` `null` — der Tag trägt dann
///   keine Aufteilung („Laden gewinnt", Festlegung zu #432).
///
/// Wie gewartet wird: Das Tagesziel liegt als feste Festlegung von Hand in
/// der Tabelle (1.800 kcal), Stammdaten sind leer und Apple Health ist
/// durch, ohne Werte. Dann bestimmt allein die Tabelle, ob es ein Tagesziel
/// gibt, und nichts lädt von Health. Hausform:
/// `ernaehrung_tag_aufteilung_test.dart`, Gruppe „Im Riverpod-Baum".
///
/// **Alle Zahlen und Daten hier sind erfunden**, Zeitpunkte im Jahr 2099.
void main() {
  // Mittwoch, 11.03.2099, 11:00 Berliner Zeit (MEZ, +1).
  const heute = '2099-03-11';
  const gestern = '2099-03-10';
  final jetzt = DateTime.utc(2099, 3, 11, 10);

  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );

  final a = MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30);
  final b = MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30);
  final ohneSnack = MahlzeitAufteilung(fruehstueck: 30, mittag: 35, abend: 35);

  Eintrag eintrag({
    required Mahlzeit mahlzeit,
    required double kcal,
    String tag = heute,
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2099, 3, tag == heute ? 11 : 10, 7),
    name: 'Prüfgericht',
    naehrwerte: Naehrwerte(kcal: kcal),
  );

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
        stammdatenProvider.overrideWith(() => _Stammdaten(const Stammdaten())),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt)),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
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

  /// Legt Tagesziel, [aufteilungen] und [eigene] ab, **bevor** irgendein
  /// Provider liest.
  Future<ProviderContainer> vorbelegt({
    bool mitTagesziel = true,
    List<AufteilungAb> aufteilungen = const [],
    List<Eintrag> eigene = const [],
    bool aufteilungenAntwortenNie = false,
    bool eintraegeAntwortenNie = false,
  }) async {
    final b = behaelter(
      aufteilungenAntwortenNie: aufteilungenAntwortenNie,
      eintraegeAntwortenNie: eintraegeAntwortenNie,
    );
    if (mitTagesziel) await KalorienzielRepository(b.db).setze(ziel1800);
    final repo = MahlzeitAufteilungRepository(b.db);
    for (final x in aufteilungen) {
      await repo.setze(x);
    }
    final eintraege = ErnaehrungRepository(b.db);
    for (final e in eigene) {
      await eintraege.buche(e);
    }
    return b.container;
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

  /// Hört auf den Inhalt und wartet, bis der Tag nicht mehr lädt.
  Future<void> gelesen(ProviderContainer c, [String tag = heute]) async {
    for (final m in Mahlzeit.values) {
      c.listen(mahlzeitProvider((tag, m)), (_, _) {});
    }
    await bis(
      () =>
          c.read(eigeneEintraegeProvider(tag)).hasValue &&
          !c.read(ernaehrungsTagProvider(tag)).mahlzeitenLaedt,
    );
  }

  MahlzeitInhalt inhalt(
    ProviderContainer c,
    Mahlzeit m, [
    String tag = heute,
  ]) => c.read(mahlzeitProvider((tag, m)));

  // ═════════════════════════════════════════════════════════════════════

  group('Mit Aufteilung 25 · 35 · 30 · 10 und Tagesziel 1.800', () {
    test(
      'das Frühstück trägt Ziel 450, 25 %, Tagesziel 1.800, gesichert',
      () async {
        final c = await vorbelegt(
          aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
        );
        await gelesen(c);

        final f = inhalt(c, Mahlzeit.fruehstueck);
        expect(f.zielKcal, 450);
        expect(f.prozent, 25);
        expect(f.tageszielKcal, 1800);
        expect(f.aufteilungGesichert, isTrue);
        expect(f.zielLaedt, isFalse);
      },
    );

    test('jede Mahlzeit trägt ihr eigenes Ziel und ihr Prozent', () async {
      final c = await vorbelegt(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
      );
      await gelesen(c);

      expect(inhalt(c, Mahlzeit.mittag).zielKcal, 630);
      expect(inhalt(c, Mahlzeit.mittag).prozent, 35);
      expect(inhalt(c, Mahlzeit.abend).zielKcal, 540);
      expect(inhalt(c, Mahlzeit.abend).prozent, 30);
      expect(inhalt(c, Mahlzeit.snack).zielKcal, 180);
      expect(
        inhalt(c, Mahlzeit.snack).prozent,
        10,
        reason: 'der Snack ist der Rest (Entscheidung 2)',
      );
    });

    test('das Ziel ist dasselbe wie in der Zeile des Tages — gereicht, '
        'nicht neu gerechnet', () async {
      final c = await vorbelegt(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
        eigene: [eintrag(mahlzeit: Mahlzeit.fruehstueck, kcal: 426)],
      );
      await gelesen(c);

      final zeile = c
          .read(ernaehrungsTagProvider(heute))
          .mahlzeiten
          .singleWhere((z) => z.mahlzeit == Mahlzeit.fruehstueck);
      final f = inhalt(c, Mahlzeit.fruehstueck);
      expect(f.zielKcal, zeile.zielKcal);
      expect(f.zielKcal, 450, reason: 'ein Eintrag ändert das Ziel nicht');
      expect(f.summe?.kcal, 426);
    });

    test('gehalten, nicht bei jedem Zugriff neu gebaut (Regel 2)', () async {
      final c = await vorbelegt(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
      );
      await gelesen(c);

      expect(
        inhalt(c, Mahlzeit.fruehstueck),
        same(inhalt(c, Mahlzeit.fruehstueck)),
      );
    });
  });

  group('Ohne Aufteilung (Entscheidung 1)', () {
    test(
      'kein Ziel, kein Prozent, nicht gesichert — auch mit Tagesziel',
      () async {
        final c = await vorbelegt(
          eigene: [eintrag(mahlzeit: Mahlzeit.fruehstueck, kcal: 426)],
        );
        await gelesen(c);

        final f = inhalt(c, Mahlzeit.fruehstueck);
        expect(f.zielKcal, isNull, reason: 'kein Startwert als Ersatz');
        expect(f.prozent, isNull, reason: 'kein Startwert als Ersatz');
        expect(f.aufteilungGesichert, isFalse);
        expect(f.zielLaedt, isFalse, reason: 'gelesen, es gibt nur keine');
        expect(
          f.tageszielKcal,
          1800,
          reason: 'das Tagesziel ist keine Rechnung über die Aufteilung (V5)',
        );
      },
    );

    test('nach dem Sichern steht das Ziel ohne Neustart da', () async {
      final c = await vorbelegt();
      await gelesen(c);
      expect(inhalt(c, Mahlzeit.fruehstueck).aufteilungGesichert, isFalse);

      await c.read(mahlzeitAufteilungenProvider.notifier).setzeAbHeute(a);
      await bis(() => inhalt(c, Mahlzeit.fruehstueck).aufteilungGesichert);

      final f = inhalt(c, Mahlzeit.fruehstueck);
      expect(f.aufteilungGesichert, isTrue);
      expect(f.zielKcal, 450);
      expect(f.prozent, 25);
    });
  });

  group('Snack bei 0 % (V4)', () {
    test('kein Ziel, aber Prozent 0 und gesichert', () async {
      final c = await vorbelegt(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: ohneSnack)],
      );
      await gelesen(c);

      final s = inhalt(c, Mahlzeit.snack);
      expect(s.zielKcal, isNull);
      expect(
        s.prozent,
        0,
        reason: 'der Schirm sagt „0 % deines Tagesziels — so eingestellt"',
      );
      expect(s.aufteilungGesichert, isTrue);
      expect(s.tageszielKcal, 1800);
    });
  });

  group('Ohne Tagesziel, aber mit Aufteilung (V19)', () {
    test('Prozent ja, Ziel und Tagesziel nein, gesichert', () async {
      final c = await vorbelegt(
        mitTagesziel: false,
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
      );
      await gelesen(c);

      expect(
        c.read(ernaehrungsTagProvider(heute)).zielKcal,
        isNull,
        reason: 'Vorbedingung: kein Tagesziel',
      );
      final f = inhalt(c, Mahlzeit.fruehstueck);
      expect(f.zielKcal, isNull);
      expect(f.tageszielKcal, isNull);
      expect(
        f.prozent,
        25,
        reason: '„25 % deines Tagesziels — es gibt noch kein Kalorienziel"',
      );
      expect(f.aufteilungGesichert, isTrue);
      expect(f.zielLaedt, isFalse);
    });
  });

  group('Eine neue Aufteilung gilt ab heute (Entscheidung 5)', () {
    test(
      'A ab gestern, B ab heute: das Frühstück von gestern trägt A',
      () async {
        final c = await vorbelegt(
          aufteilungen: [
            AufteilungAb(abTag: gestern, aufteilung: a),
            AufteilungAb(abTag: heute, aufteilung: b),
          ],
        );
        await gelesen(c);
        await gelesen(c, gestern);

        expect(inhalt(c, Mahlzeit.fruehstueck).prozent, 20);
        expect(inhalt(c, Mahlzeit.fruehstueck).zielKcal, 360);
        expect(inhalt(c, Mahlzeit.fruehstueck, gestern).prozent, 25);
        expect(inhalt(c, Mahlzeit.fruehstueck, gestern).zielKcal, 450);
      },
    );
  });

  group('Laden sieht nicht aus wie „keine Aufteilung" (V9, `01`)', () {
    test('solange die Aufteilungen nicht gelesen sind: lädt, kein Ziel, '
        'kein Prozent', () async {
      final c = await vorbelegt(
        aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
        aufteilungenAntwortenNie: true,
      );
      c.listen(mahlzeitProvider((heute, Mahlzeit.fruehstueck)), (_, _) {});
      await bis(
        () =>
            c.read(kalorienzieleProvider).hasValue &&
            c.read(eigeneEintraegeProvider(heute)).hasValue,
      );
      await laufenLassen();

      final f = inhalt(c, Mahlzeit.fruehstueck);
      expect(f.laedt, isFalse, reason: 'Vorbedingung: die Einträge stehen');
      expect(
        f.zielLaedt,
        isTrue,
        reason:
            'Ohne dieses Feld sähe „noch nicht gelesen" aus wie „keine '
            'Aufteilung", und der Schirm böte das Festlegen an.',
      );
      expect(f.zielKcal, isNull);
      expect(f.prozent, isNull);
      expect(f.aufteilungGesichert, isFalse);
    });

    test(
      'solange die eigenen Einträge nicht gelesen sind: lädt, kein Ziel',
      () async {
        final c = await vorbelegt(
          aufteilungen: [AufteilungAb(abTag: gestern, aufteilung: a)],
          eintraegeAntwortenNie: true,
        );
        c.listen(mahlzeitProvider((heute, Mahlzeit.fruehstueck)), (_, _) {});
        await bis(
          () =>
              c.read(kalorienzieleProvider).hasValue &&
              c.read(mahlzeitAufteilungenProvider).hasValue,
        );
        await laufenLassen();

        final f = inhalt(c, Mahlzeit.fruehstueck);
        expect(f.laedt, isTrue);
        expect(f.zielLaedt, isTrue);
        expect(f.zielKcal, isNull);
      },
    );
  });

  group('Gleichheit', () {
    MahlzeitInhalt bau({
      double? zielKcal = 450,
      int? prozent = 25,
      double? tageszielKcal = 1800,
      bool aufteilungGesichert = true,
      bool zielLaedt = false,
    }) => MahlzeitInhalt(
      tagesSchluessel: heute,
      mahlzeit: Mahlzeit.fruehstueck,
      eigene: const [],
      fremde: const [],
      summe: null,
      laedt: false,
      zielKcal: zielKcal,
      prozent: prozent,
      tageszielKcal: tageszielKcal,
      aufteilungGesichert: aufteilungGesichert,
      zielLaedt: zielLaedt,
    );

    test('zwei gleich gebaute sind gleich, mit gleichem hashCode', () {
      expect(bau(), bau());
      expect(bau().hashCode, bau().hashCode);
    });

    test('jedes neue Feld zählt im Vergleich', () {
      expect(bau(zielKcal: 451), isNot(bau()));
      expect(bau(zielKcal: null), isNot(bau()));
      expect(bau(prozent: 30), isNot(bau()));
      expect(bau(prozent: null), isNot(bau()));
      expect(bau(tageszielKcal: 2000), isNot(bau()));
      expect(bau(tageszielKcal: null), isNot(bau()));
      expect(bau(aufteilungGesichert: false), isNot(bau()));
      expect(bau(zielLaedt: true), isNot(bau()));
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
