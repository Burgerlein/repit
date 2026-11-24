import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/naehrwerte.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/SPEC.md` 4.8 und `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Importiert wird das Barrel `package:trainings_core/trainings_core.dart`:
/// Der Plan verlangt die Ausfuhr aus `lib/trainings_core.dart` ausdrücklich
/// („Modify: `Packages/trainings_core/lib/trainings_core.dart` (exportieren)"),
/// ein vergessener Export fiele sonst erst der App auf.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class Naehrwerte {
///   const Naehrwerte({
///     double? kcal,
///     double? eiweissG,
///     double? kohlenhydrateG,
///     double? fettG,
///     double? zuckerG,
///     double? ballaststoffeG,
///     double? gesaettigtG,
///     double? wasserMl,
///     Map<String, double?> extra = const {},
///   });
///
///   /// Dieselben Felder, aber als Angabe **je 100 Gramm** zu lesen.
///   const Naehrwerte.je100g({ … dieselben Parameter … });
///
///   final double? kcal, eiweissG, kohlenhydrateG, fettG, zuckerG,
///       ballaststoffeG, gesaettigtG, wasserMl;
///   final Map<String, double?> extra;
///
///   /// Skaliert eine Je-100-g-Angabe auf [gramm].
///   Naehrwerte fuerMenge(double gramm);
///
///   Naehrwerte operator +(Naehrwerte andere);
///   // Wertgleichheit: == und hashCode, einschließlich [extra].
/// }
/// ```
///
/// Der **allgemeine Konstruktor** steht hier, weil die Summe absoluter Werte
/// ihn braucht: Ein Tageseintrag trägt 180 g eines Lebensmittels, nicht
/// „180 g je 100 g". `je100g` ist der benannte Sonderfall für den Weg aus
/// Open Food Facts.
///
/// ## Die eine Regel, um die es hier geht
///
/// **Ein fehlender Wert ist `null`, nie `0`** (`CLAUDE.md`, Fehler `01`;
/// Review Focus 2 des Plans). Daraus folgt für die Summe:
///
/// * beide Seiten `null` → `null`. Zwei Lebensmittel ohne Ballaststoffangabe
///   ergeben nicht „0 g Ballaststoffe gegessen".
/// * genau eine Seite `null` → der vorhandene Wert, unverändert.
/// * beide vorhanden → die Summe.
///
/// Und `0.0` ist **kein** fehlender Wert: `0.0 + null` ist `0.0`, nicht
/// `null`. Wasser mit 0 kcal ist eine Messung.
///
/// ## Alle Zahlen hier sind erfunden
///
/// Kein Wert stammt aus Tims Gesundheitsdaten oder aus einer echten
/// Nährwerttabelle. Gewählt sind glatte Zahlen, die sich im Kopf nachrechnen
/// lassen.
void main() {
  /// Ein Werteträger, in dem **jedes** Feld besetzt ist. Die Zahlen sind
  /// absichtlich alle verschieden, damit ein vertauschtes Feldpaar in der
  /// Implementierung auffällt.
  const voll = Naehrwerte(
    kcal: 100,
    eiweissG: 10,
    kohlenhydrateG: 20,
    fettG: 5,
    zuckerG: 3,
    ballaststoffeG: 4,
    gesaettigtG: 2,
    wasserMl: 50,
    extra: {'vitaminCMg': 12},
  );

  const leer = Naehrwerte();

  /// Jedes Feld einmal, mit Namen — so prüft ein Fall alle acht, und die
  /// Fehlermeldung nennt das Feld, an dem es hängt.
  final felder = <(String, double? Function(Naehrwerte))>[
    ('kcal', (n) => n.kcal),
    ('eiweissG', (n) => n.eiweissG),
    ('kohlenhydrateG', (n) => n.kohlenhydrateG),
    ('fettG', (n) => n.fettG),
    ('zuckerG', (n) => n.zuckerG),
    ('ballaststoffeG', (n) => n.ballaststoffeG),
    ('gesaettigtG', (n) => n.gesaettigtG),
    ('wasserMl', (n) => n.wasserMl),
  ];

  group('Summe', () {
    test('zwei fehlende Werte bleiben fehlend — in jedem Feld', () {
      final summe = leer + leer;

      for (final (name, lies) in felder) {
        expect(lies(summe), isNull, reason: '$name muss null bleiben');
      }
    });

    test('ein fehlender Wert links lässt den vorhandenen stehen', () {
      final summe = leer + voll;

      for (final (name, lies) in felder) {
        expect(lies(summe), lies(voll), reason: name);
      }
    });

    test('ein fehlender Wert rechts lässt den vorhandenen stehen', () {
      final summe = voll + leer;

      for (final (name, lies) in felder) {
        expect(lies(summe), lies(voll), reason: name);
      }
    });

    test('zwei vorhandene Werte werden addiert', () {
      final summe = voll + voll;

      for (final (name, lies) in felder) {
        expect(lies(summe), closeTo(lies(voll)! * 2, 1e-9), reason: name);
      }
    });

    test('die eine Zeile aus Review Focus 2: Ballaststoffe', () {
      const mitAngabe = Naehrwerte(kcal: 250, ballaststoffeG: 6);
      const ohneAngabe = Naehrwerte(kcal: 150);

      expect((mitAngabe + ohneAngabe).ballaststoffeG, closeTo(6, 1e-9));
      expect((ohneAngabe + ohneAngabe).ballaststoffeG, isNull);
      expect((ohneAngabe + ohneAngabe).kcal, closeTo(300, 1e-9));
    });

    test('eine gemessene Null ist kein fehlender Wert', () {
      const null0 = Naehrwerte(kcal: 0, zuckerG: 0);

      expect((null0 + leer).kcal, 0);
      expect((null0 + leer).zuckerG, 0);
      expect((leer + null0).kcal, 0);
      expect((null0 + voll).kcal, closeTo(100, 1e-9));
    });

    test('die Summe ist vertauschbar', () {
      const andere = Naehrwerte(kcal: 7, fettG: 1, extra: {'eisenMg': 2});

      expect(voll + andere, andere + voll);
    });

    test('extra wird feldweise nach derselben Regel summiert', () {
      const a = Naehrwerte(extra: {'eisenMg': 3, 'zinkMg': null});
      const b = Naehrwerte(extra: {'eisenMg': 4, 'zinkMg': null, 'jodUg': 20});

      final summe = (a + b).extra;

      expect(summe['eisenMg'], closeTo(7, 1e-9));
      expect(summe['zinkMg'], isNull, reason: 'beide Seiten fehlen');
      expect(summe['jodUg'], closeTo(20, 1e-9), reason: 'nur eine Seite hat ihn');
      expect(summe.keys.toSet(), {'eisenMg', 'zinkMg', 'jodUg'});
    });

    test('extra einer leeren Angabe ist leer, nicht null', () {
      expect(leer.extra, isEmpty);
      expect((leer + leer).extra, isEmpty);
    });
  });

  group('fuerMenge', () {
    const je100g = Naehrwerte.je100g(
      kcal: 200,
      eiweissG: 10,
      fettG: 4,
      wasserMl: 60,
      extra: {'eisenMg': 2, 'zinkMg': null},
    );

    test('250 Gramm sind das Zweieinhalbfache', () {
      final menge = je100g.fuerMenge(250);

      expect(menge.kcal, closeTo(500, 1e-9));
      expect(menge.eiweissG, closeTo(25, 1e-9));
      expect(menge.fettG, closeTo(10, 1e-9));
      expect(menge.wasserMl, closeTo(150, 1e-9));
    });

    test('was nicht angegeben ist, bleibt auch nach der Rechnung fehlend', () {
      final menge = je100g.fuerMenge(250);

      expect(menge.kohlenhydrateG, isNull);
      expect(menge.zuckerG, isNull);
      expect(menge.ballaststoffeG, isNull);
      expect(menge.gesaettigtG, isNull);
    });

    test('100 Gramm geben die Angabe unverändert zurück', () {
      final menge = je100g.fuerMenge(100);

      expect(menge.kcal, closeTo(200, 1e-9));
      expect(menge.eiweissG, closeTo(10, 1e-9));
      expect(menge.extra['eisenMg'], closeTo(2, 1e-9));
    });

    test('extra wird mitskaliert, fehlende Einträge bleiben fehlend', () {
      final menge = je100g.fuerMenge(50);

      expect(menge.extra['eisenMg'], closeTo(1, 1e-9));
      expect(menge.extra['zinkMg'], isNull);
    });

    test('null Gramm sind null Kalorien — und nicht „unbekannt"', () {
      final menge = je100g.fuerMenge(0);

      expect(menge.kcal, 0, reason: 'gewogene Null, kein fehlender Wert');
      expect(menge.eiweissG, 0);
      expect(menge.zuckerG, isNull, reason: 'war nie angegeben');
    });
  });

  group('Wertgleichheit', () {
    test('gleiche Werte sind gleich und haben denselben hashCode', () {
      const a = Naehrwerte(kcal: 100, eiweissG: 10, extra: {'eisenMg': 3});
      const b = Naehrwerte(kcal: 100, eiweissG: 10, extra: {'eisenMg': 3});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein unterschiedliches Feld macht ungleich', () {
      const a = Naehrwerte(kcal: 100, eiweissG: 10);
      const b = Naehrwerte(kcal: 100, eiweissG: 11);

      expect(a, isNot(b));
    });

    test('fehlend und null sind nicht dasselbe', () {
      const fehlt = Naehrwerte(kcal: 100);
      const istNull = Naehrwerte(kcal: 100, eiweissG: 0);

      expect(fehlt, isNot(istNull));
    });

    test('extra zählt zur Gleichheit — gleicher Inhalt, andere Map', () {
      final a = Naehrwerte(kcal: 100, extra: {'eisenMg': 3, 'jodUg': 20});
      final b = Naehrwerte(kcal: 100, extra: {'jodUg': 20, 'eisenMg': 3});
      const ohne = Naehrwerte(kcal: 100);

      expect(a, b, reason: 'Inhaltsgleichheit, nicht Identität der Map');
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(ohne));
    });

    test('Wertgleichheit trägt über die Summe hinweg', () {
      // Riverpod rechnet Abgeleitetes neu, sobald die Abhängigkeit ungleich
      // ist. Zwei gleich gerechnete Tagessummen müssen gleich sein, sonst
      // läuft jeder abgeleitete Wert je Bild neu — das wäre `03`.
      expect(voll + leer, voll);
      expect((voll + leer).hashCode, voll.hashCode);
    });
  });
}
