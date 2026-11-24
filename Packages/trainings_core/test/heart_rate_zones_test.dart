import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Herzfrequenz-Zonen nach Karvonen** aus Ticket #95 —
/// `docs/SPEC.md` 4.7 („Herzfrequenz-Zonen nach Karvonen
/// (Herzfrequenzreserve) mit HFmax 205 und Ruhepuls …: Zone 1 50–60 %,
/// 2 60–70 %, 3 70–80 %, 4 80–90 %, 5 90–100 %").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Plan/HeartRateZones.swift`
/// samt `Tests/TrainingsCoreTests/HeartRateZonesTests.swift` — die Doppelung
/// Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist Absicht").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// /// Eine Zone, Grenzen in bpm, kaufmännisch gerundet.
/// class HeartRateZone {
///   const HeartRateZone({
///     required int number,
///     required int lower,
///     required int upper,
///   });
///   final int number;
///   final int lower;
///   final int upper;
///   // == und hashCode nach Wert — Werttypen, die Provider-Abhängigkeit
///   // werden, brauchen beides (`CLAUDE.md`, Datenschicht).
/// }
///
/// class HeartRateZoning {
///   const HeartRateZoning({
///     required List<HeartRateZone> zones,
///     required bool clamped,
///   });
///   final List<HeartRateZone> zones;
///   /// true, wenn der Ruhepuls zu nah an der HFmax lag und geklemmt werden
///   /// musste. Die Oberfläche muss das benennen, sonst sehen unbrauchbare
///   /// Zonen völlig plausibel aus.
///   final bool clamped;
///   // == und hashCode nach Wert, die Zonenliste elementweise.
/// }
///
/// abstract final class HeartRateZones {
///   /// Mindestabstand zwischen Ruhepuls und HFmax, damit die Zonen bei
///   /// Fehleingaben nicht invertieren.
///   static const int minimumReserve = 20;
///
///   static HeartRateZoning zoning({required int hrMax, required int hrRest});
/// }
/// ```
///
/// Karvonen: Grenze = Ruhepuls + Reserve · Anteil, Zone *n* von
/// (n+4)/10 bis (n+5)/10. **Die Zonen sind eine Schätzung, kein Labortest.**
/// Die Pulswerte unten sind die Beispielwerte aus SPEC 4.7 (HFmax 205)
/// beziehungsweise erfunden — keine Messwerte.
void main() {
  group('Zonengrenzen für HFmax 205 und Ruhepuls 62', () {
    // Reserve 143. Von Hand: 62 + 143·0,5 = 133,5 → 134; ·0,6 = 147,8 → 148;
    // ·0,7 = 162,1 → 162; ·0,8 = 176,4 → 176; ·0,9 = 190,7 → 191; ·1,0 = 205.
    final r = HeartRateZones.zoning(hrMax: 205, hrRest: 62);

    test('fünf Zonen, nicht geklemmt', () {
      expect(r.zones, hasLength(5));
      expect(r.clamped, isFalse);
    });

    test('die Grenzen stimmen mit der Handrechnung überein', () {
      expect(r.zones[0].lower, 134);
      expect(r.zones[0].upper, 148);
      expect(r.zones[1].lower, 148);
      expect(r.zones[1].upper, 162);
      expect(r.zones[2].upper, 176);
      expect(r.zones[3].upper, 191);
      expect(r.zones[4].upper, 205);
    });

    test('die Zonen sind 1 bis 5 nummeriert', () {
      expect(r.zones.map((z) => z.number), [1, 2, 3, 4, 5]);
    });

    test('Zone 5 endet genau an der HFmax', () {
      expect(r.zones.last.upper, 205);
    });
  });

  group('Klemmung bei unbrauchbaren Eingaben', () {
    test('Zonen bleiben geordnet, wenn der Ruhepuls über der HFmax liegt', () {
      final r = HeartRateZones.zoning(hrMax: 150, hrRest: 160);
      expect(
        r.clamped,
        isTrue,
        reason: 'Die Klemmung muss sichtbar sein, damit die Oberfläche '
            'warnen kann',
      );
      for (final zone in r.zones) {
        expect(
          zone.lower,
          lessThanOrEqualTo(zone.upper),
          reason: 'Zone ${zone.number} ist invertiert',
        );
      }
      for (var i = 1; i < r.zones.length; i++) {
        expect(r.zones[i - 1].upper, lessThanOrEqualTo(r.zones[i].lower));
      }
    });

    test('geklemmt wird auf HFmax minus minimumReserve', () {
      // safeRest = min(160, 150 − 20) = 130, Reserve 20:
      // Zone 1 = 140–142, … Zone 5 = 148–150.
      final r = HeartRateZones.zoning(hrMax: 150, hrRest: 160);
      expect(r.zones[0].lower, 140);
      expect(r.zones[4].upper, 150);
    });

    test('genau minimumReserve Abstand gilt noch als unklemmt', () {
      final r = HeartRateZones.zoning(hrMax: 205, hrRest: 185);
      expect(r.clamped, isFalse);
    });

    test('ein bpm weniger Abstand klemmt', () {
      final r = HeartRateZones.zoning(hrMax: 205, hrRest: 186);
      expect(r.clamped, isTrue);
    });

    test('die Mindestreserve ist als Konstante benannt', () {
      expect(HeartRateZones.minimumReserve, 20);
    });
  });

  group('Werttypen vergleichen nach Wert', () {
    // `CLAUDE.md`, Datenschicht: Ein Werttyp, der Abhängigkeit eines
    // Providers ist, braucht == und hashCode — sonst ist jedes neu gebaute
    // Zoning ungleich dem vorigen und jeder abgeleitete Wert läuft neu.
    test('zwei gleich gebaute Zonen sind gleich', () {
      const a = HeartRateZone(number: 1, lower: 134, upper: 148);
      final b = HeartRateZone(number: 1, lower: 134, upper: 148);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('eine andere Grenze macht ungleich', () {
      const a = HeartRateZone(number: 1, lower: 134, upper: 148);
      final b = HeartRateZone(number: 1, lower: 134, upper: 149);
      expect(a == b, isFalse);
    });

    test('zwei Rechnungen mit denselben Eingaben ergeben gleiche Zonings', () {
      final a = HeartRateZones.zoning(hrMax: 205, hrRest: 62);
      final b = HeartRateZones.zoning(hrMax: 205, hrRest: 62);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Ruhepuls macht die Zonings ungleich', () {
      final a = HeartRateZones.zoning(hrMax: 205, hrRest: 62);
      final b = HeartRateZones.zoning(hrMax: 205, hrRest: 70);
      expect(a == b, isFalse);
    });
  });
}
