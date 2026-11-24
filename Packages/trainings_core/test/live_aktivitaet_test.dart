import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/live_aktivitaet.dart` — Task 2
/// des Umsetzungsplans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`
/// (#364), Spec `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitte „Schiedsstelle" und „Die Essen-Karte".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// enum LiveFassung { training, kochen, essen }
///
/// LiveFassung? waehleFassung({
///   required bool trainingLaeuft,
///   required bool kochlaufOffen,
///   required bool essenEin,
/// });
///
/// class MahlzeitStand {   // Eingang; ==, hashCode, toString
///   MahlzeitStand({required Mahlzeit mahlzeit, required bool hatEintrag,
///       required double? kcal});   // oder kcal optional, siehe unten
///   final Mahlzeit mahlzeit;
///   final bool hatEintrag;
///   final double? kcal;
/// }
///
/// class MahlzeitRing {    // Ausgang; ==, hashCode, toString
///   final Mahlzeit mahlzeit;
///   final bool eintrag;
///   final int? kcal;
/// }
///
/// class EssenKarte {      // ==, hashCode, toString
///   final List<MahlzeitRing> ringe;  // immer vier, Mahlzeit.values-Folge
///   final Mahlzeit? ersteOffene;
///   final int serie;
///   final int serieAbMorgen;
///   final DateTime verfaelltUm;      // UTC, naechsterEsstagBeginn(jetzt)
/// }
///
/// EssenKarte essenKarte({
///   required List<MahlzeitStand> mahlzeiten,
///   required ({int heute, int abMorgen}) serie,
///   required DateTime jetzt,
/// });
/// ```
///
/// ## Die Regeln aus der Spec
///
/// - Rangfolge **Training > Kochen > Essen**, nichts davon → `null`.
///   Gemerkt wird nichts (Tim, 05.11.2026, Entscheidung 3).
/// - **Offen** ist eine Hauptmahlzeit (Frühstück, Mittag, Abend) ohne
///   Eintrag. **Ein Snack ist nie offen.** `ersteOffene` folgt der
///   Reihenfolge Frühstück, Mittag, Abend, **nicht der Uhrzeit**.
/// - V2 (Tim, 05.11.2026): Der Ring ist voll, sobald die Mahlzeit einen
///   Eintrag hat — `eintrag` spiegelt `hatEintrag`.
/// - `kcal` wird kaufmännisch gerundet, `null` bleibt `null`, auch bei
///   einer Mahlzeit mit Eintrag.
/// - Weniger oder mehr als vier Mahlzeiten oder eine doppelte →
///   `ArgumentError`.
/// - `==` und `hashCode` auf allen drei Werttypen, sonst ginge jede
///   Neuberechnung als Update an iOS.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Konstruktor von `MahlzeitStand`:** benannte Parameter `mahlzeit:`,
///   `hatEintrag:`, `kcal:`. Die Spec zeigt nur die Felder. `kcal:` wird
///   hier **immer** ausdrücklich übergeben, auch als `null` — so passt der
///   Test zu `required double? kcal` ebenso wie zu einem optionalen
///   Parameter.
/// - `MahlzeitRing` und `EssenKarte` werden **nicht** im Test gebaut,
///   sondern nur über `essenKarte` erzeugt und über ihre Felder geprüft.
///   Ihre Konstruktoren legt dieser Test nicht fest.
/// - „Kaufmännisch" heißt hier: `.5` rundet weg von null (`2.5 → 3`),
///   nicht zur geraden Zahl. Ein echter Wert `0.0` bleibt `0` — er ist ein
///   Wert, kein fehlender.
/// - Zwei Karten mit derselben Rundung (`685.3` und `685.4`) sind gleich:
///   Verglichen wird, was auf der Karte steht.
/// - Zwei Aufrufe mit demselben Esstag, aber verschiedenem `jetzt`, ergeben
///   dieselbe Karte, weil `verfaelltUm` gleich bleibt. Sonst ginge jede
///   Neuberechnung im Lauf eines Tages als Update raus (Review Focus 4).
/// - `toString` wird nur darauf geprüft, dass es nicht Dart's Vorgabe
///   „Instance of …" ist. Die Form ist frei.
/// - Eine leere Liste wirft ebenfalls `ArgumentError`.
void main() {
  MahlzeitStand stand(Mahlzeit m, {bool eintrag = false, double? kcal}) =>
      MahlzeitStand(mahlzeit: m, hatEintrag: eintrag, kcal: kcal);

  /// Alle vier ohne Eintrag, in `Mahlzeit.values`-Reihenfolge.
  List<MahlzeitStand> leer() => [for (final m in Mahlzeit.values) stand(m)];

  /// Vier Stände aus einer Teilmenge mit Eintrag; die übrigen leer.
  List<MahlzeitStand> mit(Map<Mahlzeit, double?> eintraege) => [
    for (final m in Mahlzeit.values)
      eintraege.containsKey(m)
          ? stand(m, eintrag: true, kcal: eintraege[m])
          : stand(m),
  ];

  const ohneSerie = (heute: 0, abMorgen: 0);

  // 14.01.2027 12:00 Berlin = 11:00 UTC. Frei gewählt.
  final mittags = DateTime.utc(2027, 1, 14, 11, 0);
  // 14.01.2027 20:00 Berlin = 19:00 UTC.
  final abends = DateTime.utc(2027, 1, 14, 19, 0);

  EssenKarte karte(
    List<MahlzeitStand> m, {
    ({int heute, int abMorgen}) serie = ohneSerie,
    DateTime? jetzt,
  }) => essenKarte(mahlzeiten: m, serie: serie, jetzt: jetzt ?? mittags);

  MahlzeitRing ring(EssenKarte k, Mahlzeit m) =>
      k.ringe.singleWhere((r) => r.mahlzeit == m);

  group('waehleFassung — die acht Kombinationen', () {
    // Unabhängig hingeschrieben, nicht ausgerechnet.
    const tabelle = <(bool, bool, bool), LiveFassung?>{
      (false, false, false): null,
      (false, false, true): LiveFassung.essen,
      (false, true, false): LiveFassung.kochen,
      (false, true, true): LiveFassung.kochen,
      (true, false, false): LiveFassung.training,
      (true, false, true): LiveFassung.training,
      (true, true, false): LiveFassung.training,
      (true, true, true): LiveFassung.training,
    };

    for (final MapEntry(key: (t, k, e), value: erwartet) in tabelle.entries) {
      test('training $t, kochen $k, essen $e → $erwartet', () {
        expect(
          waehleFassung(trainingLaeuft: t, kochlaufOffen: k, essenEin: e),
          erwartet,
        );
      });
    }

    test('die drei Fassungen in dieser Reihenfolge', () {
      expect(LiveFassung.values, [
        LiveFassung.training,
        LiveFassung.kochen,
        LiveFassung.essen,
      ]);
    });
  });

  group('waehleFassung — kommt von selbst zurück', () {
    test('Training verdrängt Essen, danach ist Essen wieder da', () {
      expect(
        waehleFassung(
          trainingLaeuft: true,
          kochlaufOffen: false,
          essenEin: true,
        ),
        LiveFassung.training,
      );
      expect(
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: true,
        ),
        LiveFassung.essen,
      );
    });

    test('gemerkt wird nichts: Reihenfolge der Aufrufe ist gleichgültig', () {
      final folge = [
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: true,
        ),
        waehleFassung(
          trainingLaeuft: true,
          kochlaufOffen: false,
          essenEin: true,
        ),
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: true,
        ),
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: true,
          essenEin: true,
        ),
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: true,
        ),
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: false,
        ),
        waehleFassung(
          trainingLaeuft: false,
          kochlaufOffen: false,
          essenEin: true,
        ),
      ];
      expect(folge, [
        LiveFassung.essen,
        LiveFassung.training,
        LiveFassung.essen,
        LiveFassung.kochen,
        LiveFassung.essen,
        null,
        LiveFassung.essen,
      ]);
    });
  });

  group('essenKarte — ersteOffene', () {
    test('keine Einträge: alles leer, ersteOffene ist das Frühstück', () {
      final k = karte(leer());
      expect(k.ersteOffene, Mahlzeit.fruehstueck);
      for (final m in Mahlzeit.values) {
        expect(ring(k, m).eintrag, isFalse, reason: '$m');
        expect(ring(k, m).kcal, isNull, reason: '$m');
      }
    });

    test('Frühstück und Mittag erledigt, Abend offen → abend', () {
      final k = karte(mit({Mahlzeit.fruehstueck: 500, Mahlzeit.mittag: 700}));
      expect(k.ersteOffene, Mahlzeit.abend);
    });

    test('alle drei Hauptmahlzeiten erledigt, Snack leer → null', () {
      final k = karte(
        mit({
          Mahlzeit.fruehstueck: 500,
          Mahlzeit.mittag: 700,
          Mahlzeit.abend: 900,
        }),
      );
      expect(k.ersteOffene, isNull);
      expect(ring(k, Mahlzeit.snack).eintrag, isFalse);
    });

    test('alle vier erledigt → null', () {
      final k = karte(
        mit({
          Mahlzeit.fruehstueck: 500,
          Mahlzeit.mittag: 700,
          Mahlzeit.snack: 200,
          Mahlzeit.abend: 900,
        }),
      );
      expect(k.ersteOffene, isNull);
    });

    test('der Snack ist nie ersteOffene, auch als einziger leer', () {
      final k = karte(
        mit({
          Mahlzeit.fruehstueck: 500,
          Mahlzeit.mittag: 700,
          Mahlzeit.abend: 900,
        }),
      );
      expect(k.ersteOffene, isNot(Mahlzeit.snack));
    });

    test('nur der Snack erledigt → ersteOffene ist das Frühstück', () {
      final k = karte(mit({Mahlzeit.snack: 200}));
      expect(k.ersteOffene, Mahlzeit.fruehstueck);
    });

    test('Frühstück offen, Mittag erledigt → fruehstueck', () {
      final k = karte(mit({Mahlzeit.mittag: 700}));
      expect(k.ersteOffene, Mahlzeit.fruehstueck);
    });

    test('die Reihenfolge zählt, nicht die Uhrzeit von jetzt', () {
      // 20:00 Berlin — nach der Uhr wäre der Abend dran.
      final k = karte(mit({Mahlzeit.mittag: 700}), jetzt: abends);
      expect(k.ersteOffene, Mahlzeit.fruehstueck);
    });

    test('Frühstück erledigt, Mittag offen, Abend erledigt → mittag', () {
      final k = karte(mit({Mahlzeit.fruehstueck: 500, Mahlzeit.abend: 900}));
      expect(k.ersteOffene, Mahlzeit.mittag);
    });
  });

  group('essenKarte — Ringe', () {
    test('eintrag spiegelt hatEintrag, je Mahlzeit (V2)', () {
      final k = karte(mit({Mahlzeit.mittag: 700, Mahlzeit.snack: 150}));
      expect(ring(k, Mahlzeit.fruehstueck).eintrag, isFalse);
      expect(ring(k, Mahlzeit.mittag).eintrag, isTrue);
      expect(ring(k, Mahlzeit.snack).eintrag, isTrue);
      expect(ring(k, Mahlzeit.abend).eintrag, isFalse);
    });

    test('immer vier Ringe in Mahlzeit.values-Reihenfolge', () {
      final k = karte(leer());
      expect(k.ringe.map((r) => r.mahlzeit), Mahlzeit.values);
    });

    test('die Reihenfolge der Eingabe spielt keine Rolle', () {
      final eingabe = [
        stand(Mahlzeit.abend, eintrag: true, kcal: 900),
        stand(Mahlzeit.snack),
        stand(Mahlzeit.fruehstueck, eintrag: true, kcal: 500),
        stand(Mahlzeit.mittag),
      ];
      final k = karte(eingabe);
      expect(k.ringe.map((r) => r.mahlzeit), Mahlzeit.values);
      expect(k.ringe.map((r) => r.eintrag), [true, false, false, true]);
      expect(k.ringe.map((r) => r.kcal), [500, null, null, 900]);
      expect(k, karte(mit({Mahlzeit.fruehstueck: 500, Mahlzeit.abend: 900})));
    });
  });

  group('essenKarte — kcal', () {
    test('685.5 → 686', () {
      final k = karte(mit({Mahlzeit.fruehstueck: 685.5}));
      expect(ring(k, Mahlzeit.fruehstueck).kcal, 686);
    });

    test('685.49 → 685', () {
      final k = karte(mit({Mahlzeit.fruehstueck: 685.49}));
      expect(ring(k, Mahlzeit.fruehstueck).kcal, 685);
    });

    test('2.5 → 3: kaufmännisch, nicht zur geraden Zahl', () {
      final k = karte(mit({Mahlzeit.snack: 2.5}));
      expect(ring(k, Mahlzeit.snack).kcal, 3);
    });

    test('kcal null mit Eintrag → eintrag true, kcal null, nie 0', () {
      final k = karte(mit({Mahlzeit.mittag: null}));
      final r = ring(k, Mahlzeit.mittag);
      expect(r.eintrag, isTrue);
      expect(r.kcal, isNull);
      expect(k.ersteOffene, Mahlzeit.fruehstueck);
    });

    test('kcal null mit Eintrag zählt als erledigt, nicht als offen', () {
      final k = karte(
        mit({
          Mahlzeit.fruehstueck: null,
          Mahlzeit.mittag: null,
          Mahlzeit.abend: null,
        }),
      );
      expect(k.ersteOffene, isNull);
    });

    test('ohne Eintrag bleibt kcal null', () {
      final k = karte(leer());
      expect(k.ringe.map((r) => r.kcal), [null, null, null, null]);
    });

    test('ein echter Wert 0.0 bleibt 0', () {
      final k = karte(mit({Mahlzeit.snack: 0.0}));
      expect(ring(k, Mahlzeit.snack).eintrag, isTrue);
      expect(ring(k, Mahlzeit.snack).kcal, 0);
    });
  });

  group('essenKarte — falsche Eingabe ist ein Programmierfehler', () {
    test('drei Mahlzeiten → ArgumentError', () {
      expect(
        () => karte([
          stand(Mahlzeit.fruehstueck),
          stand(Mahlzeit.mittag),
          stand(Mahlzeit.abend),
        ]),
        throwsArgumentError,
      );
    });

    test('fünf Mahlzeiten (eine doppelt) → ArgumentError', () {
      expect(
        () => karte([...leer(), stand(Mahlzeit.mittag)]),
        throwsArgumentError,
      );
    });

    test('vier, aber eine doppelt und eine fehlt → ArgumentError', () {
      expect(
        () => karte([
          stand(Mahlzeit.fruehstueck),
          stand(Mahlzeit.mittag),
          stand(Mahlzeit.mittag, eintrag: true, kcal: 300),
          stand(Mahlzeit.abend),
        ]),
        throwsArgumentError,
      );
    });

    test('keine Mahlzeit → ArgumentError', () {
      expect(() => karte(const []), throwsArgumentError);
    });
  });

  group('essenKarte — Serie und Verfall', () {
    test('serie und serieAbMorgen werden durchgereicht', () {
      final k = karte(leer(), serie: (heute: 10, abMorgen: 0));
      expect(k.serie, 10);
      expect(k.serieAbMorgen, 0);
    });

    test('verfaelltUm ist naechsterEsstagBeginn(jetzt) — mittags', () {
      final k = karte(leer(), jetzt: mittags);
      expect(k.verfaelltUm, naechsterEsstagBeginn(mittags));
      // 15.01.2027 04:00 Berlin = 03:00 UTC
      expect(k.verfaelltUm, DateTime.utc(2027, 1, 15, 3, 0));
    });

    test('verfaelltUm vor 04:00 ist dieselbe Nacht', () {
      // 15.01.2027 01:30 Berlin = 00:30 UTC
      final nachts = DateTime.utc(2027, 1, 15, 0, 30);
      final k = karte(leer(), jetzt: nachts);
      expect(k.verfaelltUm, naechsterEsstagBeginn(nachts));
      expect(k.verfaelltUm, DateTime.utc(2027, 1, 15, 3, 0));
    });

    test('verfaelltUm im Sommer', () {
      // 14.07.2027 21:00 Berlin = 19:00 UTC → 15.07. 04:00 = 02:00 UTC
      final sommer = DateTime.utc(2027, 7, 14, 19, 0);
      expect(
        karte(leer(), jetzt: sommer).verfaelltUm,
        DateTime.utc(2027, 7, 15, 2, 0),
      );
    });
  });

  group('Gleichheit — keine Karte ist ungleich sich selbst', () {
    test('zwei Aufrufe mit gleichen Eingängen sind gleich', () {
      final a = karte(
        mit({Mahlzeit.fruehstueck: 685.5, Mahlzeit.mittag: 813}),
        serie: (heute: 10, abMorgen: 10),
      );
      final b = karte(
        mit({Mahlzeit.fruehstueck: 685.5, Mahlzeit.mittag: 813}),
        serie: (heute: 10, abMorgen: 10),
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('die Ringe zweier gleicher Karten sind einzeln gleich', () {
      final a = karte(mit({Mahlzeit.mittag: 813}));
      final b = karte(mit({Mahlzeit.mittag: 813}));
      for (var i = 0; i < 4; i++) {
        expect(a.ringe[i], b.ringe[i]);
        expect(a.ringe[i].hashCode, b.ringe[i].hashCode);
      }
    });

    test('ein Unterschied in genau einem kcal → ungleich', () {
      final a = karte(mit({Mahlzeit.fruehstueck: 686, Mahlzeit.mittag: 813}));
      final b = karte(mit({Mahlzeit.fruehstueck: 686, Mahlzeit.mittag: 814}));
      expect(a, isNot(b));
      expect(ring(a, Mahlzeit.mittag), isNot(ring(b, Mahlzeit.mittag)));
    });

    test('kcal, die gleich gerundet werden, ergeben gleiche Karten', () {
      final a = karte(mit({Mahlzeit.mittag: 685.3}));
      final b = karte(mit({Mahlzeit.mittag: 685.4}));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('kcal null und kcal 0 sind ungleich', () {
      final a = karte(mit({Mahlzeit.mittag: null}));
      final b = karte(mit({Mahlzeit.mittag: 0}));
      expect(a, isNot(b));
    });

    test('ein Unterschied im Eintrag → ungleich', () {
      expect(karte(mit({Mahlzeit.snack: null})), isNot(karte(leer())));
    });

    test('ein Unterschied in der Serie → ungleich', () {
      expect(
        karte(leer(), serie: (heute: 3, abMorgen: 0)),
        isNot(karte(leer(), serie: (heute: 4, abMorgen: 0))),
      );
      expect(
        karte(leer(), serie: (heute: 3, abMorgen: 0)),
        isNot(karte(leer(), serie: (heute: 3, abMorgen: 3))),
      );
    });

    test('derselbe Esstag, andere Uhrzeit → gleiche Karte', () {
      expect(karte(leer(), jetzt: mittags), karte(leer(), jetzt: abends));
      expect(
        karte(leer(), jetzt: mittags).hashCode,
        karte(leer(), jetzt: abends).hashCode,
      );
    });

    test('über 04:00 hinweg → ungleich, weil verfaelltUm wandert', () {
      // 15.01.2027 03:59 und 04:00 Berlin
      final vorher = DateTime.utc(2027, 1, 15, 2, 59);
      final nachher = DateTime.utc(2027, 1, 15, 3, 0);
      expect(
        karte(leer(), jetzt: vorher),
        isNot(karte(leer(), jetzt: nachher)),
      );
    });

    test('MahlzeitStand: gleiche Felder → gleich, sonst ungleich', () {
      final a = stand(Mahlzeit.mittag, eintrag: true, kcal: 700);
      final b = stand(Mahlzeit.mittag, eintrag: true, kcal: 700);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(stand(Mahlzeit.mittag, eintrag: true, kcal: 701)));
      expect(a, isNot(stand(Mahlzeit.mittag, eintrag: true, kcal: null)));
      expect(a, isNot(stand(Mahlzeit.mittag, eintrag: false, kcal: 700)));
      expect(a, isNot(stand(Mahlzeit.abend, eintrag: true, kcal: 700)));
    });

    test('MahlzeitStand trägt seine Felder', () {
      final s = stand(Mahlzeit.snack, eintrag: true, kcal: 12.5);
      expect(s.mahlzeit, Mahlzeit.snack);
      expect(s.hatEintrag, isTrue);
      expect(s.kcal, 12.5);
    });
  });

  group('toString', () {
    test('keiner der drei Typen zeigt „Instance of …"', () {
      final s = stand(Mahlzeit.mittag, eintrag: true, kcal: 700);
      final k = karte(mit({Mahlzeit.mittag: 700}));
      expect(s.toString(), isNot(startsWith('Instance of')));
      expect(k.ringe.first.toString(), isNot(startsWith('Instance of')));
      expect(k.toString(), isNot(startsWith('Instance of')));
    });
  });
}
