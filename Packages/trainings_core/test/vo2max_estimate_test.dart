import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **eigene VO₂max-Schätzung** aus Ticket #95 — `docs/SPEC.md`
/// 4.7 („Eigene VO₂max-Schätzung aus jedem Lauf nach Daniels und Gilbert …
/// aus jeder Distanz-Zeit-Kombination ab 3 Minuten").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/VO2MaxEstimate.swift`
/// samt `Tests/TrainingsCoreTests/VO2MaxEstimateTests.swift` — die Doppelung
/// Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist Absicht").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class VO2MaxEstimate {
///   /// Unter dieser Laufdauer dominiert die anaerobe Leistung und die
///   /// Formel überschätzt grob.
///   static const double minimumMinutes = 3;
///
///   /// Geschätzte VO₂max in ml/kg/min aus [km] und [minutes], auf eine
///   /// Nachkommastelle gerundet (kaufmännisch, wie Swifts `rounded()`).
///   /// `null` bei km ≤ 0 oder minutes < [minimumMinutes].
///   static double? fromRun({required double km, required double minutes});
/// }
/// ```
///
/// Beide Werte — Watch und eigene Schätzung — sind Schätzungen, kein
/// Labortest. **Alle Zahlen hier sind erfunden**; die Halbmarathon-Zeiten
/// sind Stützstellen der Daniels-Tabelle, keine Trainingsdaten.
void main() {
  group('Gegenprobe gegen die Daniels-Tabelle', () {
    // Die VDOT-Tabelle in SPEC 4.7 sagt: VDOT 34 → 127,3 min, VDOT 40 →
    // 111,0 min auf dem Halbmarathon (21,0975 km). Wer diese Zeiten läuft,
    // muss also ungefähr diesen VDOT geschätzt bekommen.
    test('ein Halbmarathon in 127,3 min ergibt rund VDOT 34', () {
      final v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 127.3);
      expect(v, isNotNull);
      expect(v!, closeTo(34, 0.5));
    });

    test('ein Halbmarathon in 111 min ergibt rund VDOT 40', () {
      final v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 111.0);
      expect(v, isNotNull);
      expect(v!, closeTo(40, 0.5));
    });

    test('die Zielzeit 2:10 entspricht etwa VDOT 33', () {
      final v = VO2MaxEstimate.fromRun(km: 21.0975, minutes: 130);
      expect(v, isNotNull);
      expect(v!, closeTo(33.2, 0.6));
    });
  });

  group('Monotonie', () {
    test('schneller laufen ergibt einen höheren Wert', () {
      final slow = VO2MaxEstimate.fromRun(km: 10, minutes: 60)!;
      final fast = VO2MaxEstimate.fromRun(km: 10, minutes: 50)!;
      expect(fast, greaterThan(slow));
    });
  });

  group('Rundung auf eine Nachkommastelle', () {
    // Nachgerechnet mit den Daniels-Gilbert-Koeffizienten aus der
    // Swift-Vorlage: 10 km in 50 min → 40,012… → 40,0; 5 km in 30 min →
    // 30,82… → 30,8. Beide liegen weit weg von einer ,x5-Grenze, die
    // Erwartung hängt also nicht an der Rundungsrichtung.
    test('10 km in 50 Minuten ergeben genau 40,0', () {
      final v = VO2MaxEstimate.fromRun(km: 10, minutes: 50);
      expect(v, isNotNull);
      expect(v!, closeTo(40.0, 1e-9));
    });

    test('5 km in 30 Minuten ergeben genau 30,8', () {
      final v = VO2MaxEstimate.fromRun(km: 5, minutes: 30);
      expect(v, isNotNull);
      expect(v!, closeTo(30.8, 1e-9));
    });

    test('das Ergebnis trägt nie mehr als eine Nachkommastelle', () {
      for (final (km, minutes) in [(10.0, 50.0), (5.0, 30.0), (8.3, 47.7)]) {
        final v = VO2MaxEstimate.fromRun(km: km, minutes: minutes)!;
        expect(
          v * 10,
          closeTo((v * 10).roundToDouble(), 1e-9),
          reason: '$km km in $minutes min: $v hat mehr als eine '
              'Nachkommastelle',
        );
      }
    });
  });

  group('Unbrauchbare Eingaben ergeben nichts', () {
    test('ohne Distanz keine Schätzung', () {
      expect(VO2MaxEstimate.fromRun(km: 0, minutes: 30), isNull);
    });

    test('ohne Dauer keine Schätzung', () {
      expect(VO2MaxEstimate.fromRun(km: 5, minutes: 0), isNull);
    });

    test('eine negative Distanz ergibt nichts', () {
      expect(VO2MaxEstimate.fromRun(km: -5, minutes: 30), isNull);
    });
  });

  group('Die 3-Minuten-Grenze', () {
    // Zu kurze Läufe lässt Daniels bewusst aus: unter rund 3 min dominiert
    // die anaerobe Leistung und die Formel überschätzt grob (SPEC 4.7:
    // „ab 3 Minuten").
    test('ein sehr kurzer Lauf wird abgelehnt', () {
      expect(VO2MaxEstimate.fromRun(km: 0.4, minutes: 1.2), isNull);
    });

    test('knapp unter 3 Minuten wird abgelehnt', () {
      expect(VO2MaxEstimate.fromRun(km: 0.8, minutes: 2.999), isNull);
    });

    test('genau 3 Minuten sind erlaubt — „ab" heißt einschließlich', () {
      final v = VO2MaxEstimate.fromRun(km: 0.8, minutes: 3);
      expect(v, isNotNull);
      expect(v!, greaterThan(0));
    });

    test('die Grenze ist als Konstante benannt', () {
      expect(VO2MaxEstimate.minimumMinutes, 3);
    });
  });
}
