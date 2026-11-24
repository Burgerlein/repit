import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/tagesbilanz.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/SPEC.md` 4.8:
///
/// > Anzeige als Balken mit Zielbereich ±10 % und Status („Im Ziel ✓",
/// > „X kcal zu wenig", „über Ziel", heute „noch X kcal offen"), dazu die
/// > Herleitung. Zeile „Letzte 7 Tage: Ziel an X von Y Tagen getroffen,
/// > Ø ±Z kcal".
/// > Bilanz gegessen / verbraucht / Überschuss oder Defizit.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// enum Zielstatus { keinZiel, keineWerte, zuWenig, imZiel, ueberZiel }
///
/// class Tagesbilanz {
///   final double? gegessenKcal;
///   final double? verbrauchKcal;
///   /// gegessen − verbraucht. Positiv ist Überschuss.
///   final double? differenzKcal;
///   final double? zielKcal;
///   /// gegessen − Ziel. Positiv heißt „über Ziel".
///   final double? abweichungKcal;
///   final double? untergrenzeKcal; // Ziel · 0,9
///   final double? obergrenzeKcal;  // Ziel · 1,1
///   final Zielstatus status;
///   // Wertgleichheit: == und hashCode.
/// }
///
/// Tagesbilanz bilanz({
///   required Naehrwerte gegessen,
///   double? verbrauchKcal,
///   double? zielKcal,
/// });
///
/// class SiebenTage {
///   final int getroffen;      // X
///   final int tageMitWerten;  // Y
///   final double? mittlereAbweichungKcal; // Z
///   // Wertgleichheit: == und hashCode.
/// }
///
/// SiebenTage siebenTage(List<({double? gegessen, double? ziel})> tage);
/// ```
///
/// **Keine Nutzertexte.** „Im Ziel ✓" und „noch X kcal offen" sind Sätze
/// und gehören in die View (`CLAUDE.md`); hier stehen die Fälle und die
/// Zahlen, aus denen die View sie baut. „Noch offen" ist dabei kein eigener
/// Zustand, sondern `−abweichungKcal` am laufenden Tag — ob heute ist,
/// weiß der Kern nicht und soll es nicht wissen.
///
/// ## Entscheidungen des Test-Agenten, wo die Spec Spielraum lässt
///
/// 1. **Der Zielbereich schließt seine Ränder ein.** Bei 2.000 kcal Ziel
///    sind 1.800 und 2.200 „im Ziel". Ein offener Rand hieße, dass eine
///    Zahl, die der Schirm als Bereichsende zeichnet, selbst nicht
///    dazugehört.
/// 2. **`keineWerte` ist ein eigener Zustand.** Ist `gegessen.kcal` `null`,
///    wurde nichts erfasst — das ist nicht „0 gegessen" und damit auch
///    nicht „zu wenig". Ein Ring, der daraus „1.200 kcal zu wenig" macht,
///    ist Fehler `01` in neuer Verpackung.
/// 3. **Fehlt das Ziel, gewinnt `keinZiel`**, auch wenn zugleich nichts
///    erfasst ist: Ohne Ziel ist überhaupt keine Einordnung möglich, und
///    der Schirm führt dann auf die Einstellungen.
/// 4. **`Z` ist die mittlere Abweichung mit Vorzeichen**, nicht der
///    mittlere Betrag. „Ø ±Z" liest sich als beides; mit Vorzeichen sagt
///    die Zeile, ob Tim systematisch darüber oder darunter liegt, und das
///    ist die Hälfte, nach der gehandelt wird. Die View setzt das Zeichen.
/// 5. **`Y` ist die Zahl der beurteilbaren Tage**, nicht die Länge der
///    Liste. Ein Tag ohne Erfassung oder ohne Ziel zählt weder bei `X` noch
///    bei `Y` — sonst sänke die Quote, weil ein Tag fehlt, statt weil ein
///    Ziel verfehlt wurde.
/// 6. **Die Funktion kürzt nicht auf sieben.** Sie zählt, was sie bekommt;
///    welche Tage das sind, entscheidet der Aufrufer. Der Name nennt den
///    Zweck, nicht eine Längenprüfung.
///
/// ## Alle Zahlen hier sind erfunden
void main() {
  group('bilanz — gegessen, verbraucht, Differenz', () {
    test('gegessen kommt aus den Nährwerten', () {
      final b = bilanz(
        gegessen: const Naehrwerte(kcal: 2400),
        verbrauchKcal: 2200,
        zielKcal: 2300,
      );

      expect(b.gegessenKcal, closeTo(2400, 1e-9));
      expect(b.verbrauchKcal, closeTo(2200, 1e-9));
      expect(b.zielKcal, closeTo(2300, 1e-9));
    });

    test('mehr gegessen als verbraucht ist ein Überschuss', () {
      final b = bilanz(
        gegessen: const Naehrwerte(kcal: 2400),
        verbrauchKcal: 2200,
      );

      expect(b.differenzKcal, closeTo(200, 1e-9));
    });

    test('weniger gegessen als verbraucht ist ein Defizit', () {
      final b = bilanz(
        gegessen: const Naehrwerte(kcal: 2000),
        verbrauchKcal: 2200,
      );

      expect(b.differenzKcal, closeTo(-200, 1e-9));
    });

    test('ohne Verbrauch gibt es keine Differenz — und nicht 0', () {
      final b = bilanz(gegessen: const Naehrwerte(kcal: 2000));

      expect(b.verbrauchKcal, isNull);
      expect(b.differenzKcal, isNull);
    });

    test('ohne erfasste Kalorien gibt es keine Differenz', () {
      final b = bilanz(
        gegessen: const Naehrwerte(eiweissG: 40),
        verbrauchKcal: 2200,
      );

      expect(b.gegessenKcal, isNull);
      expect(b.differenzKcal, isNull);
    });
  });

  group('bilanz — Zielbereich ±10 %', () {
    Tagesbilanz mitZiel(double gegessen) => bilanz(
      gegessen: Naehrwerte(kcal: gegessen),
      zielKcal: 2000,
    );

    test('die Grenzen liegen bei 1.800 und 2.200', () {
      final b = mitZiel(2000);

      expect(b.untergrenzeKcal, closeTo(1800, 1e-9));
      expect(b.obergrenzeKcal, closeTo(2200, 1e-9));
    });

    test('mitten im Bereich', () {
      expect(mitZiel(2000).status, Zielstatus.imZiel);
      expect(mitZiel(2000).abweichungKcal, closeTo(0, 1e-9));
    });

    test('die Ränder gehören dazu', () {
      expect(mitZiel(1800).status, Zielstatus.imZiel);
      expect(mitZiel(2200).status, Zielstatus.imZiel);
    });

    test('knapp darunter ist zu wenig', () {
      final b = mitZiel(1799);

      expect(b.status, Zielstatus.zuWenig);
      expect(b.abweichungKcal, closeTo(-201, 1e-9));
    });

    test('knapp darüber ist über Ziel', () {
      final b = mitZiel(2201);

      expect(b.status, Zielstatus.ueberZiel);
      expect(b.abweichungKcal, closeTo(201, 1e-9));
    });

    test('der frühe Tag ist zu wenig, nicht „keine Werte"', () {
      // 480 kcal um zehn Uhr morgens: erfasst, nur eben noch weit unter
      // dem Ziel. Die View macht daraus „noch 1.520 kcal offen".
      final b = mitZiel(480);

      expect(b.status, Zielstatus.zuWenig);
      expect(b.abweichungKcal, closeTo(-1520, 1e-9));
    });
  });

  group('bilanz — wenn etwas fehlt', () {
    test('ohne Ziel gibt es keinen Bereich und keine Abweichung', () {
      final b = bilanz(gegessen: const Naehrwerte(kcal: 2000));

      expect(b.status, Zielstatus.keinZiel);
      expect(b.untergrenzeKcal, isNull);
      expect(b.obergrenzeKcal, isNull);
      expect(b.abweichungKcal, isNull);
    });

    test('nichts erfasst ist nicht „zu wenig"', () {
      final b = bilanz(gegessen: const Naehrwerte(), zielKcal: 2000);

      expect(b.status, Zielstatus.keineWerte);
      expect(b.gegessenKcal, isNull);
      expect(b.abweichungKcal, isNull);
    });

    test('der Bereich steht auch dann, wenn nichts erfasst ist', () {
      final b = bilanz(gegessen: const Naehrwerte(), zielKcal: 2000);

      expect(b.untergrenzeKcal, closeTo(1800, 1e-9));
      expect(b.obergrenzeKcal, closeTo(2200, 1e-9));
    });

    test('fehlt beides, gewinnt „kein Ziel"', () {
      final b = bilanz(gegessen: const Naehrwerte());

      expect(b.status, Zielstatus.keinZiel);
    });

    test('eine erfasste Null ist ein Wert', () {
      final b = bilanz(gegessen: const Naehrwerte(kcal: 0), zielKcal: 2000);

      expect(b.status, Zielstatus.zuWenig);
      expect(b.gegessenKcal, 0);
      expect(b.abweichungKcal, closeTo(-2000, 1e-9));
    });
  });

  group('bilanz — Wertgleichheit', () {
    test('gleich gerechnete Tage sind gleich', () {
      final a = bilanz(
        gegessen: const Naehrwerte(kcal: 2000),
        verbrauchKcal: 2200,
        zielKcal: 2300,
      );
      final b = bilanz(
        gegessen: const Naehrwerte(kcal: 2000),
        verbrauchKcal: 2200,
        zielKcal: 2300,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Tag ist ungleich', () {
      final a = bilanz(gegessen: const Naehrwerte(kcal: 2000), zielKcal: 2300);
      final b = bilanz(gegessen: const Naehrwerte(kcal: 2001), zielKcal: 2300);

      expect(a, isNot(b));
    });
  });

  group('siebenTage', () {
    test('die Zeile aus der Spec: getroffen, beurteilbar, Ø Abweichung', () {
      final z = siebenTage(const [
        (gegessen: 1800.0, ziel: 2000.0), // −200, am unteren Rand: getroffen
        (gegessen: 2200.0, ziel: 2000.0), // +200, am oberen Rand: getroffen
        (gegessen: 2300.0, ziel: 2000.0), // +300, verfehlt
        (gegessen: 2100.0, ziel: 2000.0), // +100, getroffen
        (gegessen: 2100.0, ziel: 2000.0), // +100, getroffen
        (gegessen: 2100.0, ziel: 2000.0), // +100, getroffen
        (gegessen: null, ziel: 2000.0), // nichts erfasst
        (gegessen: 1900.0, ziel: null), // kein Ziel
      ]);

      expect(z.getroffen, 5);
      expect(z.tageMitWerten, 6);
      expect(z.mittlereAbweichungKcal, closeTo(100, 1e-9));
    });

    test('die mittlere Abweichung trägt ihr Vorzeichen', () {
      final z = siebenTage(const [
        (gegessen: 1800.0, ziel: 2000.0), // −200
        (gegessen: 1700.0, ziel: 2000.0), // −300
      ]);

      expect(z.getroffen, 1);
      expect(z.tageMitWerten, 2);
      expect(z.mittlereAbweichungKcal, closeTo(-250, 1e-9));
    });

    test('ein Tag ohne Erfassung senkt die Quote nicht', () {
      final nurErfasst = siebenTage(const [
        (gegessen: 2000.0, ziel: 2000.0),
      ]);
      final mitLuecke = siebenTage(const [
        (gegessen: 2000.0, ziel: 2000.0),
        (gegessen: null, ziel: 2000.0),
      ]);

      expect(mitLuecke.getroffen, nurErfasst.getroffen);
      expect(mitLuecke.tageMitWerten, nurErfasst.tageMitWerten);
      expect(mitLuecke.mittlereAbweichungKcal, nurErfasst.mittlereAbweichungKcal);
    });

    test('ohne beurteilbaren Tag gibt es keine mittlere Abweichung', () {
      final z = siebenTage(const [
        (gegessen: null, ziel: 2000.0),
        (gegessen: 1900.0, ziel: null),
      ]);

      expect(z.getroffen, 0);
      expect(z.tageMitWerten, 0);
      expect(z.mittlereAbweichungKcal, isNull);
    });

    test('eine leere Liste wirft nicht', () {
      final z = siebenTage(const []);

      expect(z.getroffen, 0);
      expect(z.tageMitWerten, 0);
      expect(z.mittlereAbweichungKcal, isNull);
    });

    test('gezählt wird, was übergeben wird — auch wenn es nicht sieben sind', () {
      final z = siebenTage(const [
        (gegessen: 2000.0, ziel: 2000.0),
        (gegessen: 2000.0, ziel: 2000.0),
        (gegessen: 1000.0, ziel: 2000.0),
      ]);

      expect(z.getroffen, 2);
      expect(z.tageMitWerten, 3);
    });

    test('dieselbe Bereichsregel wie in bilanz, Ränder eingeschlossen', () {
      final z = siebenTage(const [
        (gegessen: 1800.0, ziel: 2000.0),
        (gegessen: 2200.0, ziel: 2000.0),
        (gegessen: 1799.0, ziel: 2000.0),
        (gegessen: 2201.0, ziel: 2000.0),
      ]);

      expect(z.getroffen, 2);
      expect(z.tageMitWerten, 4);
    });

    test('eine erfasste Null zählt als verfehlter Tag, nicht als Lücke', () {
      final z = siebenTage(const [
        (gegessen: 0.0, ziel: 2000.0),
      ]);

      expect(z.getroffen, 0);
      expect(z.tageMitWerten, 1);
      expect(z.mittlereAbweichungKcal, closeTo(-2000, 1e-9));
    });

    test('Wertgleichheit', () {
      final a = siebenTage(const [(gegessen: 2000.0, ziel: 2000.0)]);
      final b = siebenTage(const [(gegessen: 2000.0, ziel: 2000.0)]);
      final c = siebenTage(const [(gegessen: 1000.0, ziel: 2000.0)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
