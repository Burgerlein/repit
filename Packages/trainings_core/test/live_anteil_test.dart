import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **#435** — die Ringe der Essen-Karte als Anteil am Ziel der
/// Mahlzeit (Task 6 des Plans
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Spec
/// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Live-Aktivität: Ringe als Anteil, ersetzt V2", V6, V15).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das.
///
/// Nachbar: `live_aktivitaet_test.dart` prüft die Karte ohne Ziel (V2 der
/// Live-Spec). Er bleibt grün und unberührt — die neuen Parameter sind
/// optional, ihre Vorgabe ist `null`.
///
/// ## API — aus dem Plan (Task 6, „Interfaces")
///
/// ```dart
/// MahlzeitStand({required Mahlzeit mahlzeit, required bool hatEintrag,
///     required double? kcal, double? zielKcal});
/// MahlzeitRing({required Mahlzeit mahlzeit, required bool eintrag,
///     required int? kcal, double? anteil});
/// ```
///
/// `essenKarte` rechnet `anteil = mahlzeitAnteil(hatEintrag:, kcal:,
/// zielKcal:)`. Beide neuen Felder stehen in `==` und `hashCode`.
///
/// ## Die Regeln aus der Spec
///
/// - **Mit Ziel füllt sich der Ring mit dem Anteil**, gedeckelt auf drei
///   Runden (V6 über `mahlzeitAnteil`).
/// - **Ohne Ziel bleibt V2**: ohne Aufteilung, ohne Tagesziel, bei 0 %
///   oder bei einem Eintrag ohne Kalorienangabe ist `anteil` `null`.
/// - **Ohne Eintrag, aber mit Ziel, ist der Anteil 0** (V6).
/// - **Hell, ruhig und erledigt hängen weiter am Eintrag**, nicht am
///   Anteil. Eine Mahlzeit bei 40 % ist erledigt, nicht offen.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`essenKarte` gibt `MahlzeitStand.kcal` ungerundet an
///   `mahlzeitAnteil`**, nicht den gerundeten `MahlzeitRing.kcal`. Der
///   Plan nennt `mahlzeitAnteil(hatEintrag:, kcal:, zielKcal:)` mit den
///   Feldern des Stands; ein Fall unten unterscheidet beides.
/// - **Der Anteil ist eine Eigenschaft des Rings, nicht der Karte** — er
///   ändert `eintrag`, `kcal` und `ersteOffene` nicht.
///
/// **Alle Zahlen und Daten hier sind erfunden**, Zeitpunkte im Jahr 2099.
void main() {
  // Donnerstag, 15.01.2099, 12:00 Berliner Zeit (UTC+1).
  final mittags = DateTime.utc(2099, 1, 15, 11);
  const serie = (heute: 4, abMorgen: 4);

  MahlzeitStand stand(
    Mahlzeit m, {
    bool hatEintrag = false,
    double? kcal,
    double? zielKcal,
  }) => MahlzeitStand(
    mahlzeit: m,
    hatEintrag: hatEintrag,
    kcal: kcal,
    zielKcal: zielKcal,
  );

  /// Vier Mahlzeiten ohne Eintrag und ohne Ziel; [ersetze] tauscht
  /// einzelne aus.
  List<MahlzeitStand> tag([Map<Mahlzeit, MahlzeitStand> ersetze = const {}]) =>
      [for (final m in Mahlzeit.values) ersetze[m] ?? stand(m)];

  EssenKarte karte(List<MahlzeitStand> mahlzeiten) =>
      essenKarte(mahlzeiten: mahlzeiten, serie: serie, jetzt: mittags);

  MahlzeitRing ring(EssenKarte k, Mahlzeit m) =>
      k.ringe.singleWhere((r) => r.mahlzeit == m);

  // ─────────────────────────────────────────────────────────────────────
  group('Ohne Ziel bleibt V2', () {
    test('ohne zielKcal ist der Anteil jedes Rings null — mit und ohne '
        'Eintrag', () {
      final k = karte(
        tag({
          Mahlzeit.fruehstueck: stand(
            Mahlzeit.fruehstueck,
            hatEintrag: true,
            kcal: 686,
          ),
          Mahlzeit.snack: stand(Mahlzeit.snack, hatEintrag: true, kcal: 0),
        }),
      );

      for (final r in k.ringe) {
        expect(r.anteil, isNull, reason: '${r.mahlzeit.name}: kein Ziel');
      }
      expect(
        ring(k, Mahlzeit.fruehstueck).eintrag,
        isTrue,
        reason: 'V2: der Ring ist voll mit Eintrag',
      );
      expect(ring(k, Mahlzeit.fruehstueck).kcal, 686);
    });

    test('der Stand ohne zielKcal-Argument ist derselbe wie mit '
        'zielKcal: null', () {
      const ohne = MahlzeitStand(
        mahlzeit: Mahlzeit.mittag,
        hatEintrag: true,
        kcal: 512,
      );
      expect(ohne.zielKcal, isNull);
      expect(ohne, stand(Mahlzeit.mittag, hatEintrag: true, kcal: 512));
      expect(
        ohne.hashCode,
        stand(Mahlzeit.mittag, hatEintrag: true, kcal: 512).hashCode,
      );
    });

    test('der Ring ohne anteil-Argument trägt null, nicht 0', () {
      const r = MahlzeitRing(mahlzeit: Mahlzeit.abend, eintrag: true, kcal: 3);
      expect(r.anteil, isNull);
    });

    test('Eintrag ohne Kalorienangabe, aber mit Ziel → null, nicht 0 '
        '(V6, der Ring folgt V2)', () {
      final k = karte(
        tag({
          Mahlzeit.abend: stand(
            Mahlzeit.abend,
            hatEintrag: true,
            kcal: null,
            zielKcal: 540,
          ),
        }),
      );
      final abend = ring(k, Mahlzeit.abend);
      expect(abend.anteil, isNull);
      expect(abend.eintrag, isTrue);
      expect(abend.kcal, isNull);
    });

    test('ein Ziel von 0 ist kein Ziel → null (0 %, V4)', () {
      final k = karte(
        tag({
          Mahlzeit.snack: stand(
            Mahlzeit.snack,
            hatEintrag: true,
            kcal: 120,
            zielKcal: 0,
          ),
          Mahlzeit.mittag: stand(Mahlzeit.mittag, zielKcal: 0),
        }),
      );
      expect(ring(k, Mahlzeit.snack).anteil, isNull);
      expect(
        ring(k, Mahlzeit.mittag).anteil,
        isNull,
        reason: 'auch ohne Eintrag: ohne Ziel kein Anteil, auch keine 0',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Mit Ziel füllt sich der Ring mit dem Anteil (V15)', () {
    test('Ziel 600 und 686 kcal → 1.14', () {
      final k = karte(
        tag({
          Mahlzeit.fruehstueck: stand(
            Mahlzeit.fruehstueck,
            hatEintrag: true,
            kcal: 686,
            zielKcal: 600,
          ),
        }),
      );
      final f = ring(k, Mahlzeit.fruehstueck);
      expect(f.anteil, 1.14);
      expect(f.eintrag, isTrue);
      expect(f.kcal, 686, reason: 'das Label bleibt „686 kcal"');
    });

    test('ohne Eintrag mit Ziel → 0, und kcal bleibt null', () {
      final k = karte(
        tag({Mahlzeit.abend: stand(Mahlzeit.abend, zielKcal: 540)}),
      );
      final abend = ring(k, Mahlzeit.abend);
      expect(abend.anteil, 0);
      expect(abend.eintrag, isFalse);
      expect(abend.kcal, isNull, reason: 'eine offene Mahlzeit ist „–"');
    });

    test('ein Eintrag mit gewogenen 0 kcal und Ziel → 0 (der schwarze '
        'Kaffee)', () {
      final k = karte(
        tag({
          Mahlzeit.snack: stand(
            Mahlzeit.snack,
            hatEintrag: true,
            kcal: 0,
            zielKcal: 240,
          ),
        }),
      );
      final snack = ring(k, Mahlzeit.snack);
      expect(snack.anteil, 0);
      expect(snack.eintrag, isTrue);
      expect(snack.kcal, 0);
    });

    test('gedeckelt auf drei Runden', () {
      final k = karte(
        tag({
          Mahlzeit.mittag: stand(
            Mahlzeit.mittag,
            hatEintrag: true,
            kcal: 2950,
            zielKcal: 840,
          ),
        }),
      );
      expect(ring(k, Mahlzeit.mittag).anteil, 3.0);
    });

    test('jede Mahlzeit bekommt ihren eigenen Anteil', () {
      final k = karte([
        stand(Mahlzeit.fruehstueck, hatEintrag: true, kcal: 686, zielKcal: 600),
        stand(Mahlzeit.mittag, hatEintrag: true, kcal: 420, zielKcal: 840),
        stand(Mahlzeit.snack, zielKcal: 240),
        stand(Mahlzeit.abend, zielKcal: 720),
      ]);
      expect(ring(k, Mahlzeit.fruehstueck).anteil, 1.14);
      expect(ring(k, Mahlzeit.mittag).anteil, 0.5);
      expect(ring(k, Mahlzeit.snack).anteil, 0);
      expect(ring(k, Mahlzeit.abend).anteil, 0);
    });

    test('der Anteil ist genau mahlzeitAnteil der Eingänge des Stands', () {
      final staende = [
        stand(
          Mahlzeit.fruehstueck,
          hatEintrag: true,
          kcal: 451.3,
          zielKcal: 450,
        ),
        stand(Mahlzeit.mittag, hatEintrag: true, kcal: 712.8, zielKcal: 630),
        stand(Mahlzeit.snack, hatEintrag: true, kcal: null, zielKcal: 180),
        stand(Mahlzeit.abend, zielKcal: 540),
      ];
      final k = karte(staende);
      for (final s in staende) {
        expect(
          ring(k, s.mahlzeit).anteil,
          mahlzeitAnteil(
            hatEintrag: s.hatEintrag,
            kcal: s.kcal,
            zielKcal: s.zielKcal,
          ),
          reason: s.mahlzeit.name,
        );
      }
    });

    test('gerechnet wird mit den ungerundeten kcal des Stands, nicht mit '
        'dem gerundeten Label', () {
      // 0.4 kcal bei einem Ziel von 1: ungerundet 0.4, mit dem gerundeten
      // Label (0) wäre es 0.
      final k = karte(
        tag({
          Mahlzeit.mittag: stand(
            Mahlzeit.mittag,
            hatEintrag: true,
            kcal: 0.4,
            zielKcal: 1,
          ),
        }),
      );
      final mittag = ring(k, Mahlzeit.mittag);
      expect(mittag.kcal, 0);
      expect(mittag.anteil, 0.4);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Hell, ruhig und erledigt hängen am Eintrag, nicht am Anteil', () {
    test('ein Frühstück bei 40 % ist erledigt — erste offene ist Mittag', () {
      final k = karte([
        stand(Mahlzeit.fruehstueck, hatEintrag: true, kcal: 240, zielKcal: 600),
        stand(Mahlzeit.mittag, zielKcal: 840),
        stand(Mahlzeit.snack, zielKcal: 240),
        stand(Mahlzeit.abend, zielKcal: 720),
      ]);
      expect(ring(k, Mahlzeit.fruehstueck).anteil, 0.4);
      expect(ring(k, Mahlzeit.fruehstueck).eintrag, isTrue);
      expect(k.ersteOffene, Mahlzeit.mittag);
    });

    test('mit und ohne Ziel: eintrag, kcal und ersteOffene sind gleich', () {
      List<MahlzeitStand> staende({required bool mitZiel}) => [
        stand(
          Mahlzeit.fruehstueck,
          hatEintrag: true,
          kcal: 686,
          zielKcal: mitZiel ? 600 : null,
        ),
        stand(Mahlzeit.mittag, zielKcal: mitZiel ? 840 : null),
        stand(
          Mahlzeit.snack,
          hatEintrag: true,
          kcal: 95.5,
          zielKcal: mitZiel ? 240 : null,
        ),
        stand(Mahlzeit.abend, zielKcal: mitZiel ? 720 : null),
      ];
      final mit = karte(staende(mitZiel: true));
      final ohne = karte(staende(mitZiel: false));

      expect(mit.ersteOffene, ohne.ersteOffene);
      expect(mit.ersteOffene, Mahlzeit.mittag);
      for (final m in Mahlzeit.values) {
        expect(ring(mit, m).eintrag, ring(ohne, m).eintrag, reason: m.name);
        expect(ring(mit, m).kcal, ring(ohne, m).kcal, reason: m.name);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Gleichheit (sonst ginge jede Neuberechnung an iOS)', () {
    test('zwei Karten, die sich nur im Anteil unterscheiden, sind '
        'ungleich', () {
      List<MahlzeitStand> staende(double zielFruehstueck) => tag({
        Mahlzeit.fruehstueck: stand(
          Mahlzeit.fruehstueck,
          hatEintrag: true,
          kcal: 686,
          zielKcal: zielFruehstueck,
        ),
      });
      final a = karte(staende(600));
      final b = karte(staende(720));

      expect(ring(a, Mahlzeit.fruehstueck).anteil, 1.14);
      expect(ring(b, Mahlzeit.fruehstueck).anteil, 0.95);
      expect(a.ersteOffene, b.ersteOffene, reason: 'Vorbedingung');
      expect(ring(a, Mahlzeit.fruehstueck).kcal, 686, reason: 'Vorbedingung');
      expect(ring(b, Mahlzeit.fruehstueck).kcal, 686, reason: 'Vorbedingung');
      expect(a, isNot(b));
    });

    test('mit Ziel und ohne Ziel sind ungleich, auch wenn sonst alles '
        'gleich ist', () {
      final mit = karte(
        tag({Mahlzeit.abend: stand(Mahlzeit.abend, zielKcal: 720)}),
      );
      final ohne = karte(tag());
      expect(
        mit,
        isNot(ohne),
        reason: 'Anteil 0 und kein Anteil sind zwei verschiedene Ringe',
      );
    });

    test('dieselben Eingänge mit Ziel → gleiche Karte, gleicher hashCode', () {
      List<MahlzeitStand> staende() => tag({
        Mahlzeit.fruehstueck: stand(
          Mahlzeit.fruehstueck,
          hatEintrag: true,
          kcal: 686,
          zielKcal: 600,
        ),
        Mahlzeit.abend: stand(Mahlzeit.abend, zielKcal: 720),
      });
      final a = karte(staende());
      final b = karte(staende());
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('MahlzeitRing: nur der Anteil verschieden → ungleich; gleich → '
        'gleicher hashCode', () {
      const a = MahlzeitRing(
        mahlzeit: Mahlzeit.mittag,
        eintrag: true,
        kcal: 420,
        anteil: 0.5,
      );
      const b = MahlzeitRing(
        mahlzeit: Mahlzeit.mittag,
        eintrag: true,
        kcal: 420,
        anteil: 0.67,
      );
      const ohne = MahlzeitRing(
        mahlzeit: Mahlzeit.mittag,
        eintrag: true,
        kcal: 420,
      );
      expect(a, isNot(b));
      expect(a, isNot(ohne));
      expect(
        a,
        const MahlzeitRing(
          mahlzeit: Mahlzeit.mittag,
          eintrag: true,
          kcal: 420,
          anteil: 0.5,
        ),
      );
      expect(
        a.hashCode,
        const MahlzeitRing(
          mahlzeit: Mahlzeit.mittag,
          eintrag: true,
          kcal: 420,
          anteil: 0.5,
        ).hashCode,
      );
    });

    test('MahlzeitStand: nur das Ziel verschieden → ungleich', () {
      expect(
        stand(Mahlzeit.abend, hatEintrag: true, kcal: 500, zielKcal: 540),
        isNot(
          stand(Mahlzeit.abend, hatEintrag: true, kcal: 500, zielKcal: 600),
        ),
      );
      expect(
        stand(Mahlzeit.abend, hatEintrag: true, kcal: 500, zielKcal: 540),
        isNot(stand(Mahlzeit.abend, hatEintrag: true, kcal: 500)),
      );
      expect(
        stand(Mahlzeit.abend, zielKcal: 540).hashCode,
        stand(Mahlzeit.abend, zielKcal: 540).hashCode,
      );
    });
  });
}
