import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/auszeit.dart` — Task 2 (#445)
/// des Umsetzungsplans `docs/superpowers/plans/2026-11-10-auszeit.md`, Spec
/// `docs/superpowers/specs/2026-11-10-auszeit-design.md` (Entscheidungen 3,
/// 4, 5; Vorgaben V2, V3, V8, V10, V14), Ticket #404.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Alle Tage liegen in den Jahren 2099 bis 2104. Es sind erfundene
/// Kalenderangaben, kein Ereignis aus Tims Leben (`CLAUDE.md`, „Keine
/// hartcodierten Ereignisse").
///
/// ## API, die diese Tests voraussetzen (aus der Spec, „Die Kern-Rechnungen")
///
/// ```dart
/// enum EreignisArt { op, krankheit, verletzung, urlaub }
/// bool pausiertKoerperziel(EreignisArt art);
/// class AuszeitTage {
///   const AuszeitTage({required int id, required EreignisArt art,
///       required String von, required String bis});
///   // id, art, von, bis; ==, hashCode, toString
/// }
/// AuszeitTage? pausierendeAuszeitAm(Iterable<AuszeitTage> auszeiten,
///     String tag);
/// const int opErholungTage = 14;
/// String opErholungBis(String opTag);
/// enum EreignisStand { geplant, laeuft, vorbei }
/// EreignisStand ereignisStand({required String von, required String bis,
///     required String heute});
/// double? festesZielPausiert({required double kcal,
///     double? koerperzielKcal});
/// ```
///
/// ## Woher die Erwartungen kommen
///
/// * **Entscheidung 3 (Tim, 10.11.2026):** OP, Krankheit und Verletzung
///   setzen den Aufschlag aus, Urlaub wird nur markiert.
/// * **Entscheidung 4 (Tim):** Das Ende einer OP ist mit OP-Tag + 14 Tagen
///   vorbelegt — eine Regel, kein Datum.
/// * **V2:** `von` und `bis` gelten einschließlich.
/// * **V3:** Bei Überlappung gilt das späteste `bis`, bei Gleichstand die
///   höchste `id`. Urlaub pausiert nie, auch nicht überlappend.
/// * **V8, V10:** Der Stand (geplant, läuft, vorbei) bezieht sich auf einen
///   Tag `heute`, einschließlich an beiden Enden.
/// * **V14:** Ein fester, berechneter Tag verliert in der Pause den
///   gespeicherten Körperziel-Anteil; nie unter 0. Ohne gespeicherten
///   Anteil (Ziel von Hand, V15 — Tim: bleibt unverändert) gibt es nichts
///   abzuziehen, das Ergebnis ist `null`.
/// * **Spec, Tabelle `ereignisse`:** Die Spalte `art` speichert den Namen
///   aus `EreignisArt` (`op`, `krankheit`, `verletzung`, `urlaub`). Die
///   Namen sind damit Speicherformat.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Sie folgen aus der Spec, stehen dort aber nicht wörtlich:
///
/// 1. **Die Reihenfolge der Eingabe spielt für `pausierendeAuszeitAm` keine
///    Rolle.** V3 ordnet vollständig (spätestes `bis`, dann höchste `id`);
///    jeder Fall wird deshalb in beiden Reihenfolgen geprüft.
/// 2. **Ein Urlaub mit späterem `bis` verdrängt die überlappende OP nicht.**
///    Folgt aus „Urlaub pausiert nie" (V3).
/// 3. **Eine eintägige Auszeit (`von == bis`) pausiert genau diesen Tag**
///    und hat an diesem Tag den Stand `laeuft`. Folgt aus V2.
/// 4. **`AuszeitTage` ist in jedem der vier Felder ein Werttyp:** Weicht
///    eines ab, sind zwei Werte ungleich.
/// 5. **`toString` nennt `id`, Art, `von` und `bis`.** Der Plan verlangt
///    `toString`, sagt aber nicht, was darin steht; eine Fehlermeldung, die
///    „Instance of 'AuszeitTage'" sagt, hilft beim Suchen nicht.
/// 6. **Tage sind ISO-Tage mit führenden Nullen** (`2099-01-15`), auch in
///    der Ausgabe von `opErholungBis`. Folgt aus `CLAUDE.md`
///    („Der Datumsschlüssel ist der ISO-Tagesstring").
/// 7. **`opErholungBis` kennt Schaltjahre**, auch die Ausnahme 2100 (kein
///    Schaltjahr). Eine Rechnung über „14 · 24 h" auf einem Zeitpunkt oder
///    über eine eigene Monatstabelle fiele hier auf.
/// 8. **`festesZielPausiert` zieht genau ab**, auch bei Nachkommastellen;
///    ist der Anteil gleich dem Ziel, ist das Ergebnis 0.
void main() {
  // Die OP aus dem Plan: 14. bis 28. Oktober, beide einschließlich.
  const op = AuszeitTage(
    id: 1,
    art: EreignisArt.op,
    von: '2099-10-14',
    bis: '2099-10-28',
  );

  group('EreignisArt', () {
    test('die Namen sind die gespeicherten Werte der Spalte art', () {
      expect(EreignisArt.op.name, 'op');
      expect(EreignisArt.krankheit.name, 'krankheit');
      expect(EreignisArt.verletzung.name, 'verletzung');
      expect(EreignisArt.urlaub.name, 'urlaub');
    });
  });

  group('pausiertKoerperziel (Entscheidung 3)', () {
    test('OP pausiert', () {
      expect(pausiertKoerperziel(EreignisArt.op), isTrue);
    });

    test('Krankheit pausiert', () {
      expect(pausiertKoerperziel(EreignisArt.krankheit), isTrue);
    });

    test('Verletzung pausiert', () {
      expect(pausiertKoerperziel(EreignisArt.verletzung), isTrue);
    });

    test('Urlaub pausiert nicht, er wird nur markiert', () {
      expect(pausiertKoerperziel(EreignisArt.urlaub), isFalse);
    });
  });

  group('pausierendeAuszeitAm — einschließlich an beiden Enden (V2)', () {
    test('pausiert am OP-Tag selbst', () {
      expect(pausierendeAuszeitAm([op], '2099-10-14'), equals(op));
    });

    test('pausiert am letzten Tag der Erholung', () {
      expect(pausierendeAuszeitAm([op], '2099-10-28'), equals(op));
    });

    test('pausiert an einem Tag dazwischen', () {
      expect(pausierendeAuszeitAm([op], '2099-10-20'), equals(op));
    });

    test('pausiert nicht am Tag vor der OP', () {
      expect(pausierendeAuszeitAm([op], '2099-10-13'), isNull);
    });

    test('pausiert nicht am Tag nach dem Ende', () {
      expect(pausierendeAuszeitAm([op], '2099-10-29'), isNull);
    });

    test('pausiert über einen Monatswechsel hinweg', () {
      const ueberMonat = AuszeitTage(
        id: 2,
        art: EreignisArt.op,
        von: '2099-10-25',
        bis: '2099-11-08',
      );
      expect(
        pausierendeAuszeitAm([ueberMonat], '2099-10-31'),
        equals(ueberMonat),
      );
      expect(
        pausierendeAuszeitAm([ueberMonat], '2099-11-01'),
        equals(ueberMonat),
      );
      expect(pausierendeAuszeitAm([ueberMonat], '2099-11-09'), isNull);
    });

    test('pausiert über einen Jahreswechsel hinweg', () {
      const ueberJahr = AuszeitTage(
        id: 3,
        art: EreignisArt.krankheit,
        von: '2099-12-28',
        bis: '2100-01-03',
      );
      expect(
        pausierendeAuszeitAm([ueberJahr], '2099-12-31'),
        equals(ueberJahr),
      );
      expect(
        pausierendeAuszeitAm([ueberJahr], '2100-01-01'),
        equals(ueberJahr),
      );
      expect(pausierendeAuszeitAm([ueberJahr], '2099-12-27'), isNull);
      expect(pausierendeAuszeitAm([ueberJahr], '2100-01-04'), isNull);
    });

    test('eine eintägige Auszeit pausiert genau diesen Tag '
        '(Festlegung 3, nicht von Tim freigegeben)', () {
      const eintaegig = AuszeitTage(
        id: 4,
        art: EreignisArt.verletzung,
        von: '2099-06-10',
        bis: '2099-06-10',
      );
      expect(
        pausierendeAuszeitAm([eintaegig], '2099-06-10'),
        equals(eintaegig),
      );
      expect(pausierendeAuszeitAm([eintaegig], '2099-06-09'), isNull);
      expect(pausierendeAuszeitAm([eintaegig], '2099-06-11'), isNull);
    });
  });

  group('pausierendeAuszeitAm — welche Art pausiert (Entscheidung 3)', () {
    test('Krankheit über den Tag pausiert', () {
      const krank = AuszeitTage(
        id: 5,
        art: EreignisArt.krankheit,
        von: '2099-10-14',
        bis: '2099-10-28',
      );
      expect(pausierendeAuszeitAm([krank], '2099-10-20'), equals(krank));
    });

    test('Verletzung über den Tag pausiert', () {
      const verletzt = AuszeitTage(
        id: 6,
        art: EreignisArt.verletzung,
        von: '2099-10-14',
        bis: '2099-10-28',
      );
      expect(pausierendeAuszeitAm([verletzt], '2099-10-20'), equals(verletzt));
    });

    test('Urlaub über denselben Zeitraum pausiert nicht', () {
      const urlaub = AuszeitTage(
        id: 7,
        art: EreignisArt.urlaub,
        von: '2099-10-14',
        bis: '2099-10-28',
      );
      expect(pausierendeAuszeitAm([urlaub], '2099-10-14'), isNull);
      expect(pausierendeAuszeitAm([urlaub], '2099-10-20'), isNull);
      expect(pausierendeAuszeitAm([urlaub], '2099-10-28'), isNull);
    });

    test('leere Liste ergibt null', () {
      expect(pausierendeAuszeitAm(const <AuszeitTage>[], '2099-10-20'), isNull);
    });

    test('nimmt jedes Iterable, nicht nur eine Liste', () {
      expect(pausierendeAuszeitAm({op}, '2099-10-20'), equals(op));
      expect(
        pausierendeAuszeitAm([op].where((_) => true), '2099-10-20'),
        equals(op),
      );
    });
  });

  group('pausierendeAuszeitAm — Überlappung (V3)', () {
    test('OP und Urlaub überlappend: die OP', () {
      const urlaub = AuszeitTage(
        id: 8,
        art: EreignisArt.urlaub,
        von: '2099-10-10',
        bis: '2099-10-24',
      );
      expect(pausierendeAuszeitAm([op, urlaub], '2099-10-20'), equals(op));
      expect(pausierendeAuszeitAm([urlaub, op], '2099-10-20'), equals(op));
    });

    test('ein Urlaub mit späterem Ende verdrängt die OP nicht '
        '(Festlegung 2, nicht von Tim freigegeben)', () {
      const urlaub = AuszeitTage(
        id: 9,
        art: EreignisArt.urlaub,
        von: '2099-10-15',
        bis: '2099-11-30',
      );
      expect(pausierendeAuszeitAm([op, urlaub], '2099-10-20'), equals(op));
      expect(pausierendeAuszeitAm([urlaub, op], '2099-10-20'), equals(op));
      // Nach dem Ende der OP läuft nur noch der Urlaub — keine Pause.
      expect(pausierendeAuszeitAm([op, urlaub], '2099-10-29'), isNull);
    });

    test('zwei OPs überlappend: die mit dem späteren Ende', () {
      const frueheresEnde = AuszeitTage(
        id: 20,
        art: EreignisArt.op,
        von: '2099-10-14',
        bis: '2099-10-28',
      );
      const spaeteresEnde = AuszeitTage(
        id: 10,
        art: EreignisArt.op,
        von: '2099-10-18',
        bis: '2099-11-01',
      );
      // Die spätere hat bewusst die niedrigere id: Das Ende entscheidet
      // vor der id.
      expect(
        pausierendeAuszeitAm([frueheresEnde, spaeteresEnde], '2099-10-20'),
        equals(spaeteresEnde),
      );
      expect(
        pausierendeAuszeitAm([spaeteresEnde, frueheresEnde], '2099-10-20'),
        equals(spaeteresEnde),
      );
    });

    test('zwei OPs mit gleichem Ende: die mit der höheren id', () {
      const niedrig = AuszeitTage(
        id: 11,
        art: EreignisArt.op,
        von: '2099-10-14',
        bis: '2099-10-28',
      );
      const hoch = AuszeitTage(
        id: 12,
        art: EreignisArt.op,
        von: '2099-10-16',
        bis: '2099-10-28',
      );
      expect(pausierendeAuszeitAm([niedrig, hoch], '2099-10-20'), equals(hoch));
      expect(pausierendeAuszeitAm([hoch, niedrig], '2099-10-20'), equals(hoch));
    });

    test('OP und Krankheit überlappend: das spätere Ende, über die Art '
        'hinweg', () {
      const krank = AuszeitTage(
        id: 13,
        art: EreignisArt.krankheit,
        von: '2099-10-19',
        bis: '2099-11-02',
      );
      expect(pausierendeAuszeitAm([op, krank], '2099-10-20'), equals(krank));
      expect(pausierendeAuszeitAm([krank, op], '2099-10-20'), equals(krank));
    });

    test('nur die Auszeiten, die den Tag enthalten, zählen', () {
      // Eine OP mit späterem Ende, die den Tag aber nicht enthält, gewinnt
      // nicht.
      const spaeter = AuszeitTage(
        id: 14,
        art: EreignisArt.op,
        von: '2099-11-10',
        bis: '2099-11-24',
      );
      expect(pausierendeAuszeitAm([op, spaeter], '2099-10-20'), equals(op));
      expect(pausierendeAuszeitAm([spaeter, op], '2099-10-20'), equals(op));
    });
  });

  group('opErholungBis (Entscheidung 4)', () {
    test('die Standardpause sind 14 Tage', () {
      expect(opErholungTage, 14);
    });

    test('OP-Tag + 14 Tage', () {
      expect(opErholungBis('2099-10-14'), '2099-10-28');
    });

    test('über den Beginn der Sommerzeit (29.03.2099)', () {
      expect(opErholungBis('2099-03-20'), '2099-04-03');
    });

    test('über das Ende der Sommerzeit (25.10.2099)', () {
      expect(opErholungBis('2099-10-20'), '2099-11-03');
    });

    test('über den Jahreswechsel', () {
      expect(opErholungBis('2099-12-25'), '2100-01-08');
    });

    test('mit führenden Nullen (Festlegung 6, nicht von Tim freigegeben)', () {
      expect(opErholungBis('2099-01-01'), '2099-01-15');
    });

    test('kennt Schaltjahre (Festlegung 7, nicht von Tim freigegeben)', () {
      // 2099: kein Schaltjahr.
      expect(opErholungBis('2099-02-20'), '2099-03-06');
      // 2104: Schaltjahr, der 29.02. zählt mit.
      expect(opErholungBis('2104-02-20'), '2104-03-05');
      // 2100: durch 100, nicht durch 400 teilbar — kein Schaltjahr.
      expect(opErholungBis('2100-02-20'), '2100-03-06');
    });
  });

  group('ereignisStand (V8, V10)', () {
    const von = '2099-10-14';
    const bis = '2099-10-28';

    test('heute vor dem Beginn: geplant', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2099-10-13'),
        EreignisStand.geplant,
      );
    });

    test('heute am Beginn: läuft', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2099-10-14'),
        EreignisStand.laeuft,
      );
    });

    test('heute dazwischen: läuft', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2099-10-20'),
        EreignisStand.laeuft,
      );
    });

    test('heute am Ende: läuft', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2099-10-28'),
        EreignisStand.laeuft,
      );
    });

    test('heute nach dem Ende: vorbei', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2099-10-29'),
        EreignisStand.vorbei,
      );
    });

    test('weit vorher und weit nachher, über Jahresgrenzen', () {
      expect(
        ereignisStand(von: von, bis: bis, heute: '2098-12-31'),
        EreignisStand.geplant,
      );
      expect(
        ereignisStand(von: von, bis: bis, heute: '2100-01-01'),
        EreignisStand.vorbei,
      );
    });

    test('über den Jahreswechsel: läuft an Silvester und an Neujahr', () {
      expect(
        ereignisStand(
          von: '2099-12-28',
          bis: '2100-01-03',
          heute: '2099-12-31',
        ),
        EreignisStand.laeuft,
      );
      expect(
        ereignisStand(
          von: '2099-12-28',
          bis: '2100-01-03',
          heute: '2100-01-01',
        ),
        EreignisStand.laeuft,
      );
    });

    test('eintägig: läuft genau an diesem Tag '
        '(Festlegung 3, nicht von Tim freigegeben)', () {
      expect(
        ereignisStand(
          von: '2099-06-10',
          bis: '2099-06-10',
          heute: '2099-06-09',
        ),
        EreignisStand.geplant,
      );
      expect(
        ereignisStand(
          von: '2099-06-10',
          bis: '2099-06-10',
          heute: '2099-06-10',
        ),
        EreignisStand.laeuft,
      );
      expect(
        ereignisStand(
          von: '2099-06-10',
          bis: '2099-06-10',
          heute: '2099-06-11',
        ),
        EreignisStand.vorbei,
      );
    });
  });

  group('festesZielPausiert (V14, V15)', () {
    test('zieht den gespeicherten Körperziel-Anteil ab', () {
      expect(festesZielPausiert(kcal: 2300, koerperzielKcal: 400), 1900);
    });

    test('ohne gespeicherten Anteil (Ziel von Hand): null', () {
      expect(festesZielPausiert(kcal: 2300, koerperzielKcal: null), isNull);
      expect(festesZielPausiert(kcal: 2300), isNull);
    });

    test('ein gespeicherter Anteil 0 lässt das Ziel stehen', () {
      expect(festesZielPausiert(kcal: 2300, koerperzielKcal: 0), 2300);
    });

    test('nie unter 0', () {
      expect(festesZielPausiert(kcal: 300, koerperzielKcal: 400), 0);
    });

    test('Anteil gleich Ziel ergibt 0 '
        '(Festlegung 8, nicht von Tim freigegeben)', () {
      expect(festesZielPausiert(kcal: 400, koerperzielKcal: 400), 0);
    });

    test('zieht genau ab, auch mit Nachkommastellen '
        '(Festlegung 8, nicht von Tim freigegeben)', () {
      expect(
        festesZielPausiert(kcal: 2250.5, koerperzielKcal: 312.25),
        closeTo(1938.25, 1e-9),
      );
    });
  });

  group('AuszeitTage ist ein Werttyp', () {
    // Nicht const gebaut: Zwei const-Ausdrücke mit gleichen Feldern wären
    // dasselbe Objekt, und der Test bewiese nichts über ==.
    AuszeitTage bau({
      int id = 1,
      EreignisArt art = EreignisArt.op,
      String von = '2099-10-14',
      String bis = '2099-10-28',
    }) => AuszeitTage(id: id, art: art, von: von, bis: bis);

    test('trägt die vier Felder', () {
      final a = bau();
      expect(a.id, 1);
      expect(a.art, EreignisArt.op);
      expect(a.von, '2099-10-14');
      expect(a.bis, '2099-10-28');
    });

    test('zwei gleich gebaute sind == und haben denselben hashCode', () {
      final a = bau();
      final b = bau();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('ist der const-Wert gleich einem gleich gebauten', () {
      expect(bau(), equals(op));
      expect(bau().hashCode, op.hashCode);
    });

    test('weicht ein Feld ab, sind sie ungleich '
        '(Festlegung 4, nicht von Tim freigegeben)', () {
      final a = bau();
      expect(a, isNot(equals(bau(id: 2))));
      expect(a, isNot(equals(bau(art: EreignisArt.krankheit))));
      expect(a, isNot(equals(bau(von: '2099-10-15'))));
      expect(a, isNot(equals(bau(bis: '2099-10-29'))));
    });

    test('toString nennt id, Art, von und bis '
        '(Festlegung 5, nicht von Tim freigegeben)', () {
      final text = bau(id: 42, art: EreignisArt.verletzung).toString();
      expect(text, contains('42'));
      expect(text, contains('verletzung'));
      expect(text, contains('2099-10-14'));
      expect(text, contains('2099-10-28'));
    });
  });
}
