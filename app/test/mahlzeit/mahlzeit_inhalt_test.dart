import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für den **Zustand** hinter dem Mahlzeiten-Schirm (#300, Task 9
/// des Ernährungsplans) — `lib/ernaehrung/mahlzeit_provider.dart`.
///
/// Der Schirm selbst liegt in `mahlzeit_view_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. Hält der Implementierende einen Fall für falsch, wird das
/// **gemeldet, nicht korrigiert.**
///
/// ## Festgelegte öffentliche API (`lib/ernaehrung/mahlzeit_provider.dart`)
///
/// ```dart
/// /// Was zu einer Mahlzeit eines Esstags eingetragen ist.
/// ///
/// /// Werttyp mit `==`/`hashCode` über alle Felder — er ist Abhängigkeit
/// /// eines Providers, und ohne Wertgleichheit liefe jeder abgeleitete
/// /// Wert bei jedem Zugriff neu (`CLAUDE.md`, Fehler `03`).
/// @immutable
/// class MahlzeitInhalt {
///   const MahlzeitInhalt({
///     required this.tagesSchluessel,
///     required this.mahlzeit,
///     required this.eigene,
///     required this.fremde,
///     required this.summe,
///     required this.laedt,
///   });
///
///   final String tagesSchluessel;
///   final Mahlzeit mahlzeit;
///
///   /// Tims eigene Einträge dieser Mahlzeit, chronologisch.
///   final List<Eintrag> eigene;
///
///   /// Die fremden Mahlzeiten aus Apple Health, chronologisch.
///   final List<FremdeMahlzeit> fremde;
///
///   /// Eigene und fremde zusammen — **`null` genau dann, wenn [leer]**.
///   final Naehrwerte? summe;
///
///   /// Die eigenen Einträge sind noch nicht gelesen.
///   final bool laedt;
///
///   bool get leer;      // eigene.isEmpty && fremde.isEmpty
///   bool get nurFremd;  // fremde.isNotEmpty && eigene.isEmpty
///   int get anzahl;     // eigene.length + fremde.length
/// }
///
/// /// Der Inhalt einer Mahlzeit, **gehalten** statt bei jedem Zugriff
/// /// gerechnet (`CLAUDE.md`, Hausregel 2).
/// final mahlzeitProvider =
///     Provider.family<MahlzeitInhalt, (String tagesSchluessel, Mahlzeit mahlzeit)>(…);
/// ```
///
/// ## Entscheidung des Test-Agenten: der Inhalt kommt aus dem Tag
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// [mahlzeitProvider] leitet aus [ernaehrungsTagProvider] ab und sucht
/// dort die [MahlzeitZeile] dieser Mahlzeit heraus, statt die Einteilung
/// ein zweites Mal zu rechnen. Der Fall „die Summe oben stimmt mit der
/// Liste überein" ist damit nicht bloß geprüft, sondern **dieselbe
/// Rechnung**: Ein eigener Eintrag steht in der Zeile, die er selbst
/// nennt; eine fremde Probe in der Zeile ihrer Uhrzeit auf der Berliner
/// Wanduhr. Eine zweite Einteilung hier liefe irgendwann auseinander, und
/// dann zeigten Tagesschirm und Mahlzeiten-Schirm verschiedene Summen für
/// dieselbe Mahlzeit.
///
/// Der Preis ist, dass der Provider auch dann neu läuft, wenn sich am Tag
/// etwas ändert, das diesen Schirm nichts angeht (ein Gewicht, ein Ziel).
/// Das kostet eine Listensuche auf einem gehaltenen Wert, und weil
/// [MahlzeitInhalt] `==` trägt, baut davon kein Widget neu.
///
/// **[laedt] kommt nicht von dort.** [ernaehrungsTagProvider] fällt auf
/// `const []` zurück, solange die eigenen Einträge nicht gelesen sind —
/// aus dem fertigen Tag ist „noch nicht gelesen" nicht mehr von „nichts
/// eingetragen" zu unterscheiden. Genau diese Verwechslung ist Fehler
/// `01`. [laedt] liest deshalb direkt am [eigeneEintraegeProvider] ab.
///
/// ## `summe` ist `null`, wenn nichts dasteht
///
/// [MahlzeitZeile.summe] trägt bei einer leeren Zeile **acht Nullen** —
/// auf dem Tagesschirm richtig, denn dort steht ein Plus und keine Zahl.
/// Dieser Schirm zeigt die Summe aber als Zahl an, und eine `0`
/// behauptete „nichts gegessen". Das ist etwas anderes als „nichts
/// eingetragen" (`mahlzeit.js`, Zustand `leer`). Darum `null`, und der
/// Schirm macht daraus `–/–`.
///
/// ## Was ein fehlender Nährwert in der Summe macht
///
/// **Die Regel steht im Kern und wird hier nicht neu erfunden**
/// (`Naehrwerte.operator +`): `null + null` bleibt `null`, `null + 6` ist
/// `6`, `0 + null` ist `0`. Für diesen Schirm heißt das:
///
/// - Deklariert **kein** Lebensmittel der Mahlzeit die Ballaststoffe, ist
///   die Summe dort `null` — nicht `0`. Das ist der Fall, auf den es
///   ankommt (#232): Zwei Lebensmittel ohne Angabe ergeben keine 0 g.
/// - Deklariert **eines von zweien** sie, ist die Summe dessen Wert. Das
///   ist die Entscheidung des Kerns, nicht die dieses Schirms, und der
///   Fall unten nagelt sie ausdrücklich fest, damit sie niemand
///   versehentlich hier umbaut.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und erkennbar künstlich — runde Zehner und Hunderter,
/// keine Werte aus `mahlzeit.js` und keine Werte von Tim (`CLAUDE.md`:
/// keine echten Gesundheitsdaten, auch nicht in Tests).
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) => DailyMetrics(
    tag: tag,
    activeKcal: 600,
    basalKcal: 1600,
    weightKg: 80,
  );

  /// Ein eigener Eintrag. Die Mahlzeit steht **am Eintrag** — die Uhrzeit
  /// ordnet ihn nicht zu (`ernaehrung_provider.dart`, `_zeilen`).
  Eintrag eintrag({
    required String name,
    Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
    int stundeUtc = 6,
    int minuteUtc = 0,
    double? kcal = 300,
    double? eiweissG = 10,
    double? kohlenhydrateG = 50,
    double? fettG = 6,
    double? ballaststoffeG = 8,
    String tag = heute,
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc, minuteUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      kohlenhydrateG: kohlenhydrateG,
      fettG: fettG,
      ballaststoffeG: ballaststoffeG,
    ),
  );

  /// Eine fremde Mahlzeit aus Apple Health. **Die Uhrzeit ordnet sie zu**,
  /// auf der Berliner Wanduhr: 06:00 UTC ist im Juli 08:00 in Berlin und
  /// damit Frühstück.
  FremdeMahlzeit fremdeMahlzeit({
    required String name,
    int stundeUtc = 6,
    int minuteUtc = 0,
    double? kcal = 400,
    double? eiweissG = 20,
    double? kohlenhydrateG = 40,
    double? fettG = 10,
    double? ballaststoffeG = 4,
  }) => FremdeMahlzeit(
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc, minuteUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      kohlenhydrateG: kohlenhydrateG,
      fettG: fettG,
      ballaststoffeG: ballaststoffeG,
    ),
  );

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Ein Container mit echter Datenbank und echtem [eigeneEintraegeProvider]
  /// — die eigenen Einträge gehen durch das Repository, damit Summe und
  /// Liste aus derselben Quelle kommen wie in der App.
  ///
  /// [eigeneLaufen] schaltet stattdessen auf einen Notifier um, der nie
  /// fertig wird: der einzige Zustand, in dem [MahlzeitInhalt.laedt] gilt.
  Future<ProviderContainer> behaelter({
    List<Eintrag> eigene = const [],
    Messwert<List<FremdeMahlzeit>>? fremde,
    bool eigeneLaufen = false,
  }) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = ErnaehrungRepository(db);
    for (final e in eigene) {
      await repo.buche(e);
    }

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        stammdatenProvider.overrideWith(() => _Stammdaten(vollstaendig)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>([
              tageswert(heute),
            ], stand: jetzt, laeuft: false),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            fremde ??
                Bekannt<List<FremdeMahlzeit>>(
                  const [],
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        if (eigeneLaufen)
          eigeneEintraegeProvider.overrideWith2(_NieFertig.new),
      ],
    );
    addTearDown(container.dispose);

    if (!eigeneLaufen) {
      await container.read(eigeneEintraegeProvider(heute).future);
    }
    // **Beide** Quellen abwarten, nicht nur die eigene: Auch
    // `fremdeMahlzeitenProvider` ist ein `AsyncNotifierProvider` mit
    // `async build()`. Wer ihn nicht abwartet, liest ihn beim synchronen
    // `read(mahlzeitProvider(…))` als `AsyncLoading`, und
    // `ernaehrungsTagProvider` fällt vorschriftsmäßig auf `NochNie`
    // zurück — jede fremde Mahlzeit wäre dann unsichtbar, ohne dass
    // etwas kaputt ist. Hausform: `ernaehrung_provider_test.dart`
    // wartet an derselben Stelle auf beide Futures.
    await container.read(fremdeMahlzeitenProvider(heute).future);
    return container;
  }

  MahlzeitInhalt inhalt(
    ProviderContainer container, [
    Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
    String tag = heute,
  ]) => container.read(mahlzeitProvider((tag, mahlzeit)));

  // ───────────────────────────────────────────────────────────────────────

  group('Die leere Mahlzeit', () {
    test('trägt keine Summe — `null`, nicht acht Nullen', () async {
      final container = await behaelter();
      final werte = inhalt(container);

      expect(werte.leer, isTrue);
      expect(werte.anzahl, 0);
      expect(
        werte.summe,
        isNull,
        reason:
            'Eine `0` behauptete „nichts gegessen"; der Schirm soll '
            '„nichts eingetragen" sagen können (mahlzeit.js, Zustand leer).',
      );
    });

    test('läuft nicht — der Lauf war da, es steht nur nichts drin', () async {
      final container = await behaelter();

      expect(inhalt(container).laedt, isFalse);
    });

    test('ist auch leer, wenn eine andere Mahlzeit etwas hat', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrot', mahlzeit: Mahlzeit.abend)],
      );

      expect(inhalt(container, Mahlzeit.abend).leer, isFalse);
      expect(inhalt(container, Mahlzeit.fruehstueck).leer, isTrue);
      expect(inhalt(container, Mahlzeit.fruehstueck).summe, isNull);
    });
  });

  group('Die Summe stimmt mit der Liste überein', () {
    test('zwei eigene Einträge werden feldweise addiert', () async {
      final container = await behaelter(
        eigene: [
          eintrag(name: 'Testbrei', kcal: 300, eiweissG: 10, fettG: 6),
          eintrag(
            name: 'Testquark',
            stundeUtc: 7,
            kcal: 200,
            eiweissG: 20,
            fettG: 4,
          ),
        ],
      );
      final werte = inhalt(container);

      expect(werte.eigene.length, 2);
      expect(werte.summe!.kcal, 500);
      expect(werte.summe!.eiweissG, 30);
      expect(werte.summe!.fettG, 10);
    });

    test('eine fremde Mahlzeit zählt mit', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrei', kcal: 300)],
        fremde: Bekannt<List<FremdeMahlzeit>>([
          fremdeMahlzeit(name: 'Fremdgericht', kcal: 400),
        ], stand: jetzt, laeuft: false),
      );
      final werte = inhalt(container);

      expect(werte.anzahl, 2);
      expect(werte.summe!.kcal, 700);
    });

    test('sie ist dieselbe Summe wie die der Tageszeile', () async {
      final container = await behaelter(
        eigene: [
          eintrag(name: 'Testbrei', kcal: 300),
          eintrag(name: 'Testquark', stundeUtc: 7, kcal: 200),
        ],
        fremde: Bekannt<List<FremdeMahlzeit>>([
          fremdeMahlzeit(name: 'Fremdgericht', kcal: 400),
        ], stand: jetzt, laeuft: false),
      );

      final tag = container.read(ernaehrungsTagProvider(heute));
      final zeile = tag.mahlzeiten.firstWhere(
        (z) => z.mahlzeit == Mahlzeit.fruehstueck,
      );

      expect(
        inhalt(container).summe,
        zeile.summe,
        reason:
            'Zwei Rechnungen an zwei Stellen gäben später zwei '
            'verschiedene Summen für dieselbe Mahlzeit.',
      );
    });
  });

  group('Ein fehlender Nährwert wird nicht zu `0`', () {
    test(
      'deklariert niemand die Ballaststoffe, ist die Summe dort `null`',
      () async {
        final container = await behaelter(
          eigene: [
            eintrag(name: 'Testbrei', ballaststoffeG: null),
            eintrag(name: 'Testquark', stundeUtc: 7, ballaststoffeG: null),
          ],
        );
        final werte = inhalt(container);

        expect(
          werte.summe!.ballaststoffeG,
          isNull,
          reason:
              'Zwei Lebensmittel ohne Angabe haben keine 0 g '
              'Ballaststoffe — sie haben keine Angabe (#232).',
        );
        expect(werte.summe!.kcal, 600);
      },
    );

    test(
      'deklariert eines von zweien sie, steht dessen Wert da (Regel des Kerns)',
      () async {
        final container = await behaelter(
          eigene: [
            eintrag(name: 'Testbrei', ballaststoffeG: 8),
            eintrag(name: 'Testquark', stundeUtc: 7, ballaststoffeG: null),
          ],
        );

        expect(
          inhalt(container).summe!.ballaststoffeG,
          8,
          reason:
              '`Naehrwerte.operator +`: `null + 6` ist `6`. Diese Regel '
              'liegt im Kern und wird hier nicht umgebaut.',
        );
      },
    );

    test('eine gewogene Null bleibt `0`', () async {
      final container = await behaelter(
        eigene: [
          eintrag(name: 'Testwasser', kcal: 0, eiweissG: 0, fettG: 0),
        ],
      );

      expect(inhalt(container).summe!.kcal, 0);
      expect(inhalt(container).summe!.fettG, 0);
    });
  });

  group('Was in welche Mahlzeit gehört', () {
    test('ein eigener Eintrag steht in der Mahlzeit, die er selbst nennt', () async {
      // 06:00 UTC ist im Juli 08:00 in Berlin und damit Frühstückszeit —
      // der Eintrag nennt trotzdem den Snack, und der gewinnt.
      final container = await behaelter(
        eigene: [
          eintrag(name: 'Testriegel', mahlzeit: Mahlzeit.snack, stundeUtc: 6),
        ],
      );

      expect(inhalt(container, Mahlzeit.snack).anzahl, 1);
      expect(inhalt(container, Mahlzeit.fruehstueck).anzahl, 0);
    });

    test('eine fremde Mahlzeit steht in der Zeile ihrer Berliner Uhrzeit', () async {
      final container = await behaelter(
        fremde: Bekannt<List<FremdeMahlzeit>>([
          // 06:00 UTC = 08:00 Berlin → Frühstück.
          fremdeMahlzeit(name: 'Fremdfruehstueck', stundeUtc: 6),
          // 10:30 UTC = 12:30 Berlin → Mittag.
          fremdeMahlzeit(name: 'Fremdmittag', stundeUtc: 10, minuteUtc: 30),
        ], stand: jetzt, laeuft: false),
      );

      expect(inhalt(container, Mahlzeit.fruehstueck).fremde.single.name,
          'Fremdfruehstueck');
      expect(inhalt(container, Mahlzeit.mittag).fremde.single.name,
          'Fremdmittag');
      expect(inhalt(container, Mahlzeit.snack).leer, isTrue);
    });

    test('die eigenen Einträge stehen chronologisch', () async {
      final container = await behaelter(
        eigene: [
          eintrag(name: 'Spaeter', stundeUtc: 8),
          eintrag(name: 'Frueher', stundeUtc: 6),
        ],
      );

      expect(
        inhalt(container).eigene.map((e) => e.name).toList(),
        ['Frueher', 'Spaeter'],
      );
    });
  });

  group('Nur aus einer anderen App', () {
    test('nurFremd gilt, wenn alles aus Apple Health kommt', () async {
      final container = await behaelter(
        fremde: Bekannt<List<FremdeMahlzeit>>([
          fremdeMahlzeit(name: 'Fremdgericht'),
        ], stand: jetzt, laeuft: false),
      );
      final werte = inhalt(container);

      expect(werte.nurFremd, isTrue);
      expect(werte.leer, isFalse);
      expect(werte.summe, isNotNull);
    });

    test('ein einziger eigener Eintrag hebt es auf', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrei')],
        fremde: Bekannt<List<FremdeMahlzeit>>([
          fremdeMahlzeit(name: 'Fremdgericht'),
        ], stand: jetzt, laeuft: false),
      );

      expect(inhalt(container).nurFremd, isFalse);
    });

    test('die leere Mahlzeit ist nicht „nur fremd"', () async {
      final container = await behaelter();

      expect(inhalt(container).nurFremd, isFalse);
    });
  });

  group('Während des Ladens (docs/todo/01)', () {
    test('laedt gilt, solange die eigenen Einträge nicht gelesen sind', () async {
      final container = await behaelter(eigeneLaufen: true);
      final werte = inhalt(container);

      expect(werte.laedt, isTrue);
      expect(
        werte.summe,
        isNull,
        reason:
            'Während des Laufs gibt es keine Summe — weder eine `0` noch '
            'eine halbe.',
      );
    });

    test('und fällt weg, sobald sie dastehen', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrei')],
      );

      expect(inhalt(container).laedt, isFalse);
    });
  });

  group('Werttyp und Hausregel 2', () {
    test('zwei gleich gebaute Inhalte sind gleich', () async {
      final erster = await behaelter(eigene: [eintrag(name: 'Testbrei')]);
      final zweiter = await behaelter(eigene: [eintrag(name: 'Testbrei')]);

      expect(inhalt(erster), inhalt(zweiter));
      expect(inhalt(erster).hashCode, inhalt(zweiter).hashCode);
    });

    test('ein anderer Eintrag macht sie ungleich', () async {
      final erster = await behaelter(eigene: [eintrag(name: 'Testbrei')]);
      final zweiter = await behaelter(
        eigene: [eintrag(name: 'Testbrei', kcal: 301)],
      );

      expect(inhalt(erster), isNot(inhalt(zweiter)));
    });

    test('eine andere Mahlzeit macht sie ungleich', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrei')],
      );

      expect(
        inhalt(container, Mahlzeit.fruehstueck),
        isNot(inhalt(container, Mahlzeit.mittag)),
      );
    });

    test('der Provider hält, was er anbietet, statt neu zu rechnen', () async {
      final container = await behaelter(
        eigene: [eintrag(name: 'Testbrei')],
      );

      expect(
        identical(inhalt(container), inhalt(container)),
        isTrue,
        reason:
            'Hausregel 2: Was ein Provider einer Ansicht anbietet, wird '
            'gehalten, nicht bei jedem Zugriff gerechnet (Fehler `03`).',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `ernaehrung_view_test.dart`:
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

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

/// Ein Lesevorgang, der nie zurückkommt — der einzige Zustand, in dem
/// „noch nicht gelesen" gilt. Ein `AsyncNotifier` behält seinen Wert beim
/// Nachlesen, also ist `laedt` danach für immer `false`.
class _NieFertig extends EigeneEintraegeNotifier {
  _NieFertig(super.tagesSchluessel);

  @override
  Future<List<Eintrag>> build() => Completer<List<Eintrag>>().future;
}
