import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `zyklusVorhersage` — Abschnitt 3 der Spec
/// `docs/superpowers/specs/2026-11-23-zyklus-spec.md` (Bereich #539).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Alle Tage liegen in den Jahren 2098 bis 2101. Es sind erfundene
/// Kalenderangaben, keine Gesundheitsdaten einer realen Person.
///
/// ## API, die diese Tests voraussetzen (Spec, Abschnitt 5)
///
/// ```dart
/// enum Fruchtbarkeitssicherheit { natuerlich, unterHormonellerVerhuetung }
/// enum VorhersageGrund { zuWenigDaten, pausiertWegenTest }
/// class Zyklusfenster { final String von; final String bis; }
/// class Zyklusvorhersage {
///   final Zyklusfenster? kern, randVor, randNach, fruchtbar;
///   final String? eisprung;
///   final Fruchtbarkeitssicherheit sicherheit;
///   final int? erwarteteLaenge;
///   final VorhersageGrund? grund;
/// }
/// Zyklusvorhersage zyklusVorhersage({
///   required List<Periode> perioden,
///   required String heute,
///   required List<Zyklusfenster> krankheitstage,
///   required bool hormonell,
///   required bool pausiert,
/// });
/// ```
///
/// ## Woher die Erwartungen kommen
///
/// * **3.1:** Gerechnet wird aus den letzten bis zu **sechs abgeschlossenen**
///   Zyklen; der laufende zählt nicht. Unter zwei abgeschlossenen Zyklen
///   gibt es keine Vorhersage.
/// * **3.2:** Zyklen unter 15 oder über 60 Tagen fließen nicht in den Median
///   ein. Bleiben weniger als zwei übrig, gibt es keine Vorhersage.
/// * **3.3:** Ein Zyklus, den eine Krankheit um mindestens einen Tag
///   überlappt, fällt aus dem Median und macht das Band um einen Tag weiter.
/// * **3.4:** Median der verbleibenden Längen; bei gerader Anzahl das Mittel
///   der beiden mittleren Werte, **kaufmännisch gerundet**.
/// * **3.5:** Erwarteter Tag = letzter Periodenstart + erwartete Länge.
///   Band `b` = Spannweite der verwendeten Längen / 2, aufgerundet, mindestens
///   1, höchstens 5; dazu je ein Tag je Krankheitszyklus, in Summe höchstens
///   5. Kernfenster = erwarteter Tag und die folgenden `d − 1` Tage, `d` =
///   Median der Längen der letzten bis zu sechs Perioden, mindestens 3,
///   höchstens 8. Randfenster = die `b` Tage davor und die `b` Tage danach.
/// * **3.6:** Eisprung = erwarteter Tag − 14; fruchtbares Fenster von fünf
///   Tagen davor bis einen Tag danach (sieben Tage).
/// * **3.7:** Unter hormoneller Verhütung läuft die Blutungsvorhersage
///   unverändert, das Band wird nicht erweitert, Eisprung und fruchtbares
///   Fenster werden geliefert und mit
///   `Fruchtbarkeitssicherheit.unterHormonellerVerhuetung` gekennzeichnet.
/// * **3.8:** Ist pausiert, liefert der Kern für beide Fenster `null` und
///   `VorhersageGrund.pausiertWegenTest`.
/// * **Abschnitt 1:** Ein Zyklus läuft von einem Periodenstart bis zum Tag
///   **vor** dem nächsten.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Sie folgen aus der Spec, stehen dort aber nicht wörtlich:
///
/// 1. **Die Vorhersage hängt nicht von `heute` ab.** 3.5 setzt den erwarteten
///    Tag auf „letzter Periodenstart + erwartete Länge", und 3.6 sagt
///    ausdrücklich, dass ein zurückliegender Eisprung weiter angezeigt wird.
///    Es wird also nichts in die Zukunft weitergedreht.
/// 2. **Gibt es keine Vorhersage, sind auch `eisprung`, `fruchtbar` und
///    `erwarteteLaenge` `null`.** Unter zwei Zyklen gibt es keinen Median,
///    und „Geraten wird nicht" (3.1). Bei `pausiert` bleibt `erwarteteLaenge`
///    ungeprüft — dazu sagt die Spec nichts.
/// 3. **Liegt eine Vorhersage vor, ist `grund` `null`** („gesetzt, wenn
///    nichts vorliegt", Abschnitt 5).
/// 4. **Ohne hormonelle Verhütung ist `sicherheit`
///    `Fruchtbarkeitssicherheit.natuerlich`** — das Feld ist nicht nullbar.
/// 5. **Mehrere Krankheitszeiträume in **einem** Zyklus machen das Band um
///    **einen** Tag weiter**, nicht um zwei: 3.5 zählt „je ein Tag für jeden
///    Krankheits**zyklus**".
/// 6. **Eine Krankheit, die nur den laufenden Zyklus trifft, ändert nichts.**
///    Der laufende Zyklus geht nach 3.1 nicht in die Rechnung ein.
/// 7. **Die Reihenfolge der Perioden in der Liste spielt keine Rolle.**
/// 8. **`Zyklusfenster` ist ein Werttyp** mit `==` und `hashCode`
///    (`CLAUDE.md`), Konstruktor mit benannten Feldern.
void main() {
  Periode p(String von, String bis) => Periode(von: von, bis: bis);
  Zyklusfenster f(String von, String bis) => Zyklusfenster(von: von, bis: bis);

  /// `von..bis` — lesbare Erwartungen und lesbare Fehlermeldungen.
  String? spanne(Zyklusfenster? fenster) =>
      fenster == null ? null : '${fenster.von}..${fenster.bis}';

  Zyklusvorhersage vorhersage(
    List<Periode> perioden, {
    String heute = '2099-12-31',
    List<Zyklusfenster> krankheitstage = const [],
    bool hormonell = false,
    bool pausiert = false,
  }) => zyklusVorhersage(
    perioden: perioden,
    heute: heute,
    krankheitstage: krankheitstage,
    hormonell: hormonell,
    pausiert: pausiert,
  );

  // Drei Perioden zu je fünf Tagen im Abstand von 28 Tagen: zwei
  // abgeschlossene Zyklen von je 28 Tagen, Spannweite 0.
  final grundfall = [
    p('2099-01-05', '2099-01-09'),
    p('2099-02-02', '2099-02-06'),
    p('2099-03-02', '2099-03-06'),
  ];

  // Derselbe Takt, eine Periode länger — drei abgeschlossene Zyklen.
  final vierPerioden = [...grundfall, p('2099-03-30', '2099-04-03')];

  group('Zyklusfenster ist ein Werttyp', () {
    test('gleiche Grenzen sind gleich', () {
      expect(
        f('2099-03-30', '2099-04-03'),
        equals(f('2099-03-30', '2099-04-03')),
      );
      expect(
        f('2099-03-30', '2099-04-03').hashCode,
        equals(f('2099-03-30', '2099-04-03').hashCode),
      );
    });

    test('abweichende Grenzen sind ungleich', () {
      expect(
        f('2099-03-30', '2099-04-03'),
        isNot(equals(f('2099-03-29', '2099-04-03'))),
      );
      expect(
        f('2099-03-30', '2099-04-03'),
        isNot(equals(f('2099-03-30', '2099-04-04'))),
      );
    });
  });

  group('Der Grundfall — zwei abgeschlossene Zyklen zu 28 Tagen', () {
    test('erwartete Länge ist der Median, hier 28', () {
      expect(vorhersage(grundfall).erwarteteLaenge, 28);
    });

    test('das Kernfenster beginnt am erwarteten Tag und ist d Tage lang', () {
      // 2099-03-02 + 28 = 2099-03-30; die Perioden sind je fünf Tage lang.
      expect(spanne(vorhersage(grundfall).kern), '2099-03-30..2099-04-03');
    });

    test('die Randfenster sind bei Spannweite 0 je einen Tag breit', () {
      final v = vorhersage(grundfall);
      expect(spanne(v.randVor), '2099-03-29..2099-03-29');
      expect(spanne(v.randNach), '2099-04-04..2099-04-04');
    });

    test('der Eisprung liegt 14 Tage vor dem erwarteten Tag', () {
      expect(vorhersage(grundfall).eisprung, '2099-03-16');
    });

    test('das fruchtbare Fenster reicht von −5 bis +1 um den Eisprung', () {
      expect(spanne(vorhersage(grundfall).fruchtbar), '2099-03-11..2099-03-17');
    });

    test(
      'ohne Verhütung ist die Sicherheit natürlich und kein Grund gesetzt',
      () {
        final v = vorhersage(grundfall);
        expect(v.sicherheit, Fruchtbarkeitssicherheit.natuerlich);
        expect(v.grund, isNull);
      },
    );

    test('die Reihenfolge der Perioden in der Liste ändert nichts', () {
      final v = vorhersage([grundfall[2], grundfall[0], grundfall[1]]);
      expect(v.erwarteteLaenge, 28);
      expect(spanne(v.kern), '2099-03-30..2099-04-03');
    });

    test('heute verschiebt die Vorhersage nicht', () {
      for (final heute in ['2099-03-10', '2099-06-01', '2101-05-01']) {
        final v = vorhersage(grundfall, heute: heute);
        expect(
          spanne(v.kern),
          '2099-03-30..2099-04-03',
          reason: 'heute = $heute darf den erwarteten Tag nicht verschieben',
        );
        expect(v.eisprung, '2099-03-16', reason: 'heute = $heute');
      }
    });
  });

  group('Keine Vorhersage unter zwei abgeschlossenen Zyklen (3.1)', () {
    void erwarteKeineVorhersage(Zyklusvorhersage v) {
      expect(v.grund, VorhersageGrund.zuWenigDaten);
      expect(v.kern, isNull);
      expect(v.randVor, isNull);
      expect(v.randNach, isNull);
      expect(v.eisprung, isNull);
      expect(v.fruchtbar, isNull);
      expect(v.erwarteteLaenge, isNull);
    }

    test('ohne jede Periode', () {
      erwarteKeineVorhersage(vorhersage([]));
    });

    test('mit einer einzigen Periode — kein abgeschlossener Zyklus', () {
      erwarteKeineVorhersage(vorhersage([grundfall.first]));
    });

    test('mit zwei Perioden — nur ein abgeschlossener Zyklus', () {
      erwarteKeineVorhersage(vorhersage([grundfall[0], grundfall[1]]));
    });

    test('drei Perioden genügen — der laufende Zyklus zählt nicht mit', () {
      expect(vorhersage(grundfall).grund, isNull);
    });
  });

  group('Ausreißer (3.2)', () {
    test('ein Zyklus unter 15 Tagen fällt aus dem Median', () {
      // Längen 14, 28, 30. Ohne den 14er: Median 29, Spannweite 2 → Band 1.
      // Mit ihm wären es Median 28 und Band 5.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-19', '2099-01-23'),
        p('2099-02-16', '2099-02-20'),
        p('2099-03-18', '2099-03-22'),
      ]);
      expect(v.erwarteteLaenge, 29);
      expect(spanne(v.kern), '2099-04-16..2099-04-20');
      expect(spanne(v.randVor), '2099-04-15..2099-04-15');
      expect(spanne(v.randNach), '2099-04-21..2099-04-21');
    });

    test('genau 15 Tage zählen noch mit', () {
      // Längen 15, 28, 30 → Median 28. Ohne den 15er wären es 29.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-20', '2099-01-24'),
        p('2099-02-17', '2099-02-21'),
        p('2099-03-19', '2099-03-23'),
      ]);
      expect(v.erwarteteLaenge, 28);
    });

    test('ein Zyklus über 60 Tagen fällt aus dem Median', () {
      // Längen 61, 28, 30 → ohne den 61er Median 29.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-03-07', '2099-03-11'),
        p('2099-04-04', '2099-04-08'),
        p('2099-05-04', '2099-05-08'),
      ]);
      expect(v.erwarteteLaenge, 29);
    });

    test('genau 60 Tage zählen noch mit', () {
      // Längen 60, 28, 30 → Median 30. Ohne den 60er wären es 29.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-03-06', '2099-03-10'),
        p('2099-04-03', '2099-04-07'),
        p('2099-05-03', '2099-05-07'),
      ]);
      expect(v.erwarteteLaenge, 30);
    });

    test('bleibt nur ein Zyklus übrig, gibt es keine Vorhersage', () {
      // Längen 14, 14, 28 — es bleibt der 28er allein.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-19', '2099-01-23'),
        p('2099-02-02', '2099-02-06'),
        p('2099-03-02', '2099-03-06'),
      ]);
      expect(v.grund, VorhersageGrund.zuWenigDaten);
      expect(v.kern, isNull);
      expect(v.fruchtbar, isNull);
      expect(v.erwarteteLaenge, isNull);
    });
  });

  group('Nur die letzten sechs abgeschlossenen Zyklen zählen (3.1)', () {
    // Acht abgeschlossene Zyklen: 50, 50, 26, 26, 26, 30, 30, 30.
    // Die letzten sechs ergeben Median 28 und Spannweite 4 (Band 2);
    // alle acht ergäben Median 30 und Band 5.
    final achtZyklen = [
      p('2099-01-01', '2099-01-05'),
      p('2099-02-20', '2099-02-24'),
      p('2099-04-11', '2099-04-15'),
      p('2099-05-07', '2099-05-11'),
      p('2099-06-02', '2099-06-06'),
      p('2099-06-28', '2099-07-02'),
      p('2099-07-28', '2099-08-01'),
      p('2099-08-27', '2099-08-31'),
      p('2099-09-26', '2099-09-30'),
    ];

    test('die beiden ältesten Zyklen gehen nicht in den Median ein', () {
      expect(vorhersage(achtZyklen).erwarteteLaenge, 28);
    });

    test('sie gehen auch nicht in die Spannweite ein', () {
      final v = vorhersage(achtZyklen);
      expect(spanne(v.kern), '2099-10-24..2099-10-28');
      expect(spanne(v.randVor), '2099-10-22..2099-10-23');
      expect(spanne(v.randNach), '2099-10-29..2099-10-30');
    });
  });

  group('Median bei gerader Anzahl, kaufmännisch gerundet (3.4)', () {
    test('26, 27, 28, 31 ergeben 28 — 27,5 wird aufgerundet', () {
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-31', '2099-02-04'),
        p('2099-02-27', '2099-03-03'),
        p('2099-03-27', '2099-03-31'),
        p('2099-04-27', '2099-05-01'),
      ]);
      expect(v.erwarteteLaenge, 28);
      // 2099-04-27 + 28 = 2099-05-25, Spannweite 5 → Band 3.
      expect(spanne(v.kern), '2099-05-25..2099-05-29');
      expect(spanne(v.randVor), '2099-05-22..2099-05-24');
      expect(spanne(v.randNach), '2099-05-30..2099-06-01');
      expect(v.eisprung, '2099-05-11');
      expect(spanne(v.fruchtbar), '2099-05-06..2099-05-12');
    });

    test('26, 28, 30, 34 ergeben 29 — das Mittel der beiden mittleren', () {
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-31', '2099-02-04'),
        p('2099-02-28', '2099-03-04'),
        p('2099-03-30', '2099-04-03'),
        p('2099-05-03', '2099-05-07'),
      ]);
      expect(v.erwarteteLaenge, 29);
    });
  });

  group('Breite des Unsicherheitsbands (3.5)', () {
    test('Spannweite 0 ergibt die Mindestbreite 1', () {
      expect(spanne(vorhersage(grundfall).randVor), '2099-03-29..2099-03-29');
    });

    test('Spannweite 3 ergibt 2 — es wird aufgerundet', () {
      // Längen 28 und 31 → Median 29,5 → 30. 2099-03-05 + 30 = 2099-04-04.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-02-02', '2099-02-06'),
        p('2099-03-05', '2099-03-09'),
      ]);
      expect(v.erwarteteLaenge, 30);
      expect(spanne(v.kern), '2099-04-04..2099-04-08');
      expect(spanne(v.randVor), '2099-04-02..2099-04-03');
      expect(spanne(v.randNach), '2099-04-09..2099-04-10');
    });

    test('eine große Spannweite wird bei 5 Tagen gekappt', () {
      // Längen 20 und 45 → Median 32,5 → 33, Spannweite 25 → 13, gekappt 5.
      final v = vorhersage([
        p('2099-01-05', '2099-01-09'),
        p('2099-01-25', '2099-01-29'),
        p('2099-03-11', '2099-03-15'),
      ]);
      expect(v.erwarteteLaenge, 33);
      expect(spanne(v.kern), '2099-04-13..2099-04-17');
      expect(spanne(v.randVor), '2099-04-08..2099-04-12');
      expect(spanne(v.randNach), '2099-04-18..2099-04-22');
    });
  });

  group('Erwartete Blutungsdauer d bestimmt das Kernfenster (3.5)', () {
    test('d ist der Median der Periodenlängen', () {
      // Perioden von 3, 7 und 5 Tagen → Median 5.
      final v = vorhersage([
        p('2099-01-05', '2099-01-07'),
        p('2099-02-02', '2099-02-08'),
        p('2099-03-02', '2099-03-06'),
      ]);
      expect(spanne(v.kern), '2099-03-30..2099-04-03');
    });

    test('d ist mindestens 3 Tage', () {
      // Drei eintägige Perioden → Median 1, angehoben auf 3.
      final v = vorhersage([
        p('2099-01-05', '2099-01-05'),
        p('2099-02-02', '2099-02-02'),
        p('2099-03-02', '2099-03-02'),
      ]);
      expect(spanne(v.kern), '2099-03-30..2099-04-01');
      expect(spanne(v.randNach), '2099-04-02..2099-04-02');
    });

    test('d ist höchstens 8 Tage', () {
      // Drei zehntägige Perioden → Median 10, gekappt auf 8.
      final v = vorhersage([
        p('2099-01-05', '2099-01-14'),
        p('2099-02-02', '2099-02-11'),
        p('2099-03-02', '2099-03-11'),
      ]);
      expect(spanne(v.kern), '2099-03-30..2099-04-06');
      expect(spanne(v.randNach), '2099-04-07..2099-04-07');
    });

    test('nur die letzten sechs Perioden bestimmen d', () {
      // Sieben Perioden: die älteste ist 3 Tage lang, die letzten sechs sind
      // 4, 4, 4, 6, 6, 6 Tage → d = 5. Über alle sieben wäre d = 4.
      // Zykluslängen 31, 28, 31, 30, 31, 30 → Median 30,5 → 31.
      final v = vorhersage([
        p('2099-01-01', '2099-01-03'),
        p('2099-02-01', '2099-02-04'),
        p('2099-03-01', '2099-03-04'),
        p('2099-04-01', '2099-04-04'),
        p('2099-05-01', '2099-05-06'),
        p('2099-06-01', '2099-06-06'),
        p('2099-07-01', '2099-07-06'),
      ]);
      expect(v.erwarteteLaenge, 31);
      expect(spanne(v.kern), '2099-08-01..2099-08-05');
      expect(spanne(v.randVor), '2099-07-30..2099-07-31');
      expect(spanne(v.randNach), '2099-08-06..2099-08-07');
      expect(v.eisprung, '2099-07-18');
      expect(spanne(v.fruchtbar), '2099-07-13..2099-07-19');
    });
  });

  group('Krankheit (3.3)', () {
    // Ohne Krankheit: drei Zyklen zu 28 Tagen, Band 1.
    test('ohne Krankheit ist das Band einen Tag breit', () {
      final v = vorhersage(vierPerioden);
      expect(v.erwarteteLaenge, 28);
      expect(spanne(v.kern), '2099-04-27..2099-05-01');
      expect(spanne(v.randVor), '2099-04-26..2099-04-26');
      expect(spanne(v.randNach), '2099-05-02..2099-05-02');
    });

    test(
      'ein Krankheitszyklus fällt aus dem Median und macht das Band weiter',
      () {
        final v = vorhersage(
          vierPerioden,
          krankheitstage: [f('2099-02-10', '2099-02-12')],
        );
        expect(v.erwarteteLaenge, 28);
        expect(spanne(v.kern), '2099-04-27..2099-05-01');
        expect(spanne(v.randVor), '2099-04-25..2099-04-26');
        expect(spanne(v.randNach), '2099-05-02..2099-05-03');
      },
    );

    test('ein einziger Krankheitstag am letzten Tag des Zyklus genügt', () {
      // Der zweite Zyklus läuft vom 2099-02-02 bis zum 2099-03-01.
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [f('2099-03-01', '2099-03-01')],
      );
      expect(spanne(v.randVor), '2099-04-25..2099-04-26');
    });

    test('ein einziger Krankheitstag am ersten Tag des Zyklus genügt', () {
      // Der dritte Zyklus beginnt am 2099-03-02.
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [f('2099-03-02', '2099-03-02')],
      );
      expect(spanne(v.randVor), '2099-04-25..2099-04-26');
    });

    test('zwei Krankheitszeiträume im selben Zyklus zählen einmal', () {
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [
          f('2099-02-05', '2099-02-06'),
          f('2099-02-20', '2099-02-21'),
        ],
      );
      expect(spanne(v.randVor), '2099-04-25..2099-04-26');
      expect(spanne(v.randNach), '2099-05-02..2099-05-03');
    });

    test('Krankheit im laufenden Zyklus ändert nichts', () {
      // Der laufende Zyklus beginnt am 2099-03-30 und geht nicht ein.
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [f('2099-04-10', '2099-04-12')],
      );
      expect(spanne(v.randVor), '2099-04-26..2099-04-26');
    });

    test('Krankheit vor der ersten Periode ändert nichts', () {
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [f('2098-12-01', '2098-12-05')],
      );
      expect(spanne(v.randVor), '2099-04-26..2099-04-26');
    });

    test('bleiben weniger als zwei Zyklen übrig, gibt es keine Vorhersage', () {
      final v = vorhersage(
        vierPerioden,
        krankheitstage: [
          f('2099-01-10', '2099-01-11'),
          f('2099-02-10', '2099-02-11'),
        ],
      );
      expect(v.grund, VorhersageGrund.zuWenigDaten);
      expect(v.kern, isNull);
      expect(v.randVor, isNull);
      expect(v.randNach, isNull);
      expect(v.eisprung, isNull);
      expect(v.fruchtbar, isNull);
      expect(v.erwarteteLaenge, isNull);
    });

    test('auch mit Krankheitszyklen bleibt das Band bei höchstens 5 Tagen', () {
      // Fünf abgeschlossene Zyklen: 28, 28, 28, 24, 31. Die drei 28er sind
      // Krankheitszyklen; es bleiben 24 und 31 → Median 27,5 → 28,
      // Spannweite 7 → 4, dazu drei Tage → 7, gekappt auf 5.
      final v = vorhersage(
        [
          ...vierPerioden,
          p('2099-04-23', '2099-04-27'),
          p('2099-05-24', '2099-05-28'),
        ],
        krankheitstage: [
          f('2099-01-10', '2099-01-11'),
          f('2099-02-10', '2099-02-11'),
          f('2099-03-10', '2099-03-11'),
        ],
      );
      expect(v.erwarteteLaenge, 28);
      expect(spanne(v.kern), '2099-06-21..2099-06-25');
      expect(spanne(v.randVor), '2099-06-16..2099-06-20');
      expect(spanne(v.randNach), '2099-06-26..2099-06-30');
    });
  });

  group('Hormonelle Verhütung (3.7)', () {
    test('die Blutungsvorhersage läuft unverändert', () {
      final ohne = vorhersage(grundfall);
      final mit = vorhersage(grundfall, hormonell: true);
      expect(mit.erwarteteLaenge, ohne.erwarteteLaenge);
      expect(spanne(mit.kern), spanne(ohne.kern));
    });

    test('das Band wird nicht erweitert', () {
      final mit = vorhersage(grundfall, hormonell: true);
      expect(spanne(mit.randVor), '2099-03-29..2099-03-29');
      expect(spanne(mit.randNach), '2099-04-04..2099-04-04');
    });

    test('Eisprung und fruchtbares Fenster werden trotzdem geliefert', () {
      final mit = vorhersage(grundfall, hormonell: true);
      expect(mit.eisprung, '2099-03-16');
      expect(spanne(mit.fruchtbar), '2099-03-11..2099-03-17');
    });

    test('die Fruchtbarkeit ist als unter hormoneller Verhütung markiert', () {
      expect(
        vorhersage(grundfall, hormonell: true).sicherheit,
        Fruchtbarkeitssicherheit.unterHormonellerVerhuetung,
      );
      expect(vorhersage(grundfall, hormonell: true).grund, isNull);
    });
  });

  group('Pause nach positivem Test (3.8)', () {
    test('beide Fenster sind null und der Grund ist pausiertWegenTest', () {
      final v = vorhersage(grundfall, pausiert: true);
      expect(v.grund, VorhersageGrund.pausiertWegenTest);
      expect(v.kern, isNull);
      expect(v.randVor, isNull);
      expect(v.randNach, isNull);
      expect(v.eisprung, isNull);
      expect(v.fruchtbar, isNull);
    });

    test('die Pause gilt auch unter hormoneller Verhütung', () {
      final v = vorhersage(grundfall, hormonell: true, pausiert: true);
      expect(v.grund, VorhersageGrund.pausiertWegenTest);
      expect(v.kern, isNull);
      expect(v.fruchtbar, isNull);
    });

    test('ohne Pause bleibt die Vorhersage stehen', () {
      expect(vorhersage(grundfall, pausiert: false).grund, isNull);
    });
  });
}
