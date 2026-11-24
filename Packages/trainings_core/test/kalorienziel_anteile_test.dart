import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Anteile des Kalorienziels** — die Herleitung „Woher das
/// Ziel kommt" auf dem Ernährungs-Tag (#314).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// Der eingeklappte Abschnitt zeigt zwei Zeilen (Verbraucht, Tagesziel);
/// das Board zeichnet drei: **Grundumsatz, Aktiv heute, Körperziel**
/// (`docs/screens/screens/ernaehrung.js`, `HERLEITUNG`). Die drei gibt es
/// für heute nicht als drei getrennte Zahlen: Für heute fällt das Ziel auf
/// Mifflin-St Jeor zurück (#229), und dort existiert die Aufteilung nur
/// innerhalb von `kalorienziel`.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// ```dart
/// /// Die drei Anteile eines Kalorienziels.
/// class KalorienzielAnteile {
///   const KalorienzielAnteile({
///     required this.grundumsatzKcal,
///     required this.aktivKcal,
///     required this.koerperzielKcal,
///     required this.gemessen,
///   });
///
///   /// Ganztägige Watch-Daten: der gemessene Grundumsatz. Sonst der
///   /// Grundbedarf nach Mifflin-St Jeor (10·kg + 6,25·cm − 5·Alter + 5).
///   final double grundumsatzKcal;
///
///   /// Ganztägige Watch-Daten: der gemessene Aktivverbrauch. Sonst der
///   /// Planwert: Grundbedarf · 0,4 (der Teil des Faktors 1,4 über dem
///   /// Grundbedarf) plus Trainingsaufschlag.
///   final double aktivKcal;
///
///   /// Der Überschuss aus dem Körperziel; 0 ohne Körperziel.
///   final double koerperzielKcal;
///
///   /// `true` nur auf dem Weg über ganztägige Watch-Daten.
///   final bool gemessen;
///
///   double get summeKcal => grundumsatzKcal + aktivKcal + koerperzielKcal;
///   // == und hashCode über alle vier Felder
/// }
///
/// /// Dieselben Parameter wie [kalorienziel]; `null` genau dann, wenn
/// /// [kalorienziel] `null` ist.
/// KalorienzielAnteile? kalorienzielAnteile({…});
/// ```
///
/// **Warum im Kern und nicht als Provider mit zweitem `kalorienziel`-
/// Aufruf**, wie das Ticket vorschlägt: Der zweite Aufruf ohne Körperziel
/// liefert den Körperziel-Anteil sauber — aber den Rest teilt er nicht.
/// Auf dem Mifflin-Weg, also **heute immer**, bliebe für Grundumsatz und
/// Aktiv nur, den Faktor 1,4 in der App ein zweites Mal hinzuschreiben —
/// genau die zweite Rechnung, die das Ticket verhindern will. Im Kern steht
/// die Aufteilung neben der Formel, und der Fall „die Summe ist das Ziel"
/// unten bindet beide aneinander: Laufen sie je auseinander, wird diese
/// Datei rot, nicht der Schirm.
///
/// **Warum die Aufteilung auf dem Mifflin-Weg so aussieht:** Das Board
/// nennt den Aktivwert „Planwert … nicht gemessen", und SPEC 4.8 sagt
/// „Grundbedarf = Mifflin-St Jeor · 1,4, plus Training". Der Grundbedarf
/// ist der Grundumsatz, der Rest des Faktors ist die Aktivität, die der
/// Plan für einen gewöhnlichen Tag annimmt. Das ist eine Lesart, keine
/// Messung — und genau deshalb trägt das Ergebnis [gemessen].
///
/// Alle Zahlen sind erfunden und rund gewählt.
void main() {
  // Mifflin-St Jeor für 80 kg, 180 cm, 30 Jahre:
  // 10·80 + 6,25·180 − 5·30 + 5 = 800 + 1125 − 150 + 5 = 1780.
  const grundbedarf = 1780.0;

  group('kein Ziel, keine Anteile', () {
    test('ohne Gewicht, Größe oder Alter ist das Ergebnis null — wie bei '
        'kalorienziel', () {
      expect(kalorienzielAnteile(groesseCm: 180, alter: 30), isNull);
      expect(kalorienzielAnteile(gewichtKg: 80, alter: 30), isNull);
      expect(kalorienzielAnteile(gewichtKg: 80, groesseCm: 180), isNull);
      expect(
        kalorienzielAnteile(gewichtKg: 0, groesseCm: 180, alter: 30),
        isNull,
      );
    });
  });

  group('ganztägige Watch-Daten', () {
    test('Grundumsatz und Aktiv sind die gemessenen Werte', () {
      final a = kalorienzielAnteile(
        basalKcal: 1500,
        aktivKcal: 600,
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
      )!;
      expect(a.grundumsatzKcal, 1500);
      expect(a.aktivKcal, 600);
      expect(a.koerperzielKcal, 0);
      expect(a.gemessen, isTrue);
      expect(a.summeKcal, 2100);
    });

    test('der Trainingsaufschlag zählt dort nicht — „aktiv" enthält das '
        'Training schon', () {
      final a = kalorienzielAnteile(
        basalKcal: 1500,
        aktivKcal: 600,
        trainingsaufschlagKcal: 300,
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
      )!;
      expect(a.aktivKcal, 600);
      expect(a.gemessen, isTrue);
    });
  });

  group('Mifflin-St Jeor — heute immer (#229)', () {
    test('ohne Watch-Daten: Grundbedarf und Planwert, nicht gemessen', () {
      final a = kalorienzielAnteile(gewichtKg: 80, groesseCm: 180, alter: 30)!;
      expect(a.grundumsatzKcal, closeTo(grundbedarf, 1e-9));
      expect(a.aktivKcal, closeTo(grundbedarf * 0.4, 1e-9));
      expect(a.koerperzielKcal, 0);
      expect(
        a.gemessen,
        isFalse,
        reason: 'eine Schätzung darf sich nicht als Messung ausgeben',
      );
    });

    test('ein Grundumsatz unter 1.400 heißt: die Uhr hat nicht den ganzen '
        'Tag gemessen — Rückfall auf Mifflin', () {
      final a = kalorienzielAnteile(
        basalKcal: 900,
        aktivKcal: 300,
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
      )!;
      expect(a.grundumsatzKcal, closeTo(grundbedarf, 1e-9));
      expect(a.gemessen, isFalse);
    });

    test('ohne Aktivwert ebenso', () {
      final a = kalorienzielAnteile(
        basalKcal: 1500,
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
      )!;
      expect(a.grundumsatzKcal, closeTo(grundbedarf, 1e-9));
      expect(a.gemessen, isFalse);
    });

    test('der Trainingsaufschlag gehört zum Aktivwert', () {
      final a = kalorienzielAnteile(
        trainingsaufschlagKcal: 300,
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
      )!;
      expect(a.grundumsatzKcal, closeTo(grundbedarf, 1e-9));
      expect(a.aktivKcal, closeTo(grundbedarf * 0.4 + 300, 1e-9));
    });
  });

  group('Körperziel', () {
    test('der Anteil ist der Überschuss aus dem Körperziel', () {
      // 4 kg in 182 Tagen = 0,1538… kg/Woche · 7.700 ÷ 7 = 169,2… kcal —
      // zwischen den Grenzen 100 und 400.
      final mit = kalorienzielAnteile(
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
        zielgewichtKg: 84,
        tageBisZiel: 182,
      )!;
      expect(mit.koerperzielKcal, closeTo(4 / 182 * 7 * 7700 / 7, 1e-9));
      expect(mit.grundumsatzKcal, closeTo(grundbedarf, 1e-9));
    });

    test('in der OP-Erholung ist er 0', () {
      final a = kalorienzielAnteile(
        gewichtKg: 80,
        groesseCm: 180,
        alter: 30,
        zielgewichtKg: 84,
        tageBisZiel: 182,
        inErholung: true,
      )!;
      expect(a.koerperzielKcal, 0);
    });

    test('ohne Zielgewicht oder Zieldatum ist er 0', () {
      for (final a in [
        kalorienzielAnteile(
          gewichtKg: 80,
          groesseCm: 180,
          alter: 30,
          zielgewichtKg: 84,
        )!,
        kalorienzielAnteile(
          gewichtKg: 80,
          groesseCm: 180,
          alter: 30,
          tageBisZiel: 182,
        )!,
      ]) {
        expect(a.koerperzielKcal, 0);
      }
    });
  });

  group('Die Summe ist das Ziel — die Formel steht an einer Stelle', () {
    // Jede Kombination aus beiden Wegen, mit und ohne Körperziel, mit und
    // ohne Aufschlag, mit Deckel unten und oben. Laufen Anteile und Ziel
    // je auseinander, widerspricht die Herleitung der Zahl im Ring.
    final faelle =
        <String, (KalorienzielAnteile? Function(), double? Function())>{};
    for (final basal in [null, 900.0, 1400.0, 1650.0]) {
      for (final aktiv in [null, 0.0, 450.0]) {
        for (final ziel in [null, 80.5, 84.0, 95.0]) {
          for (final tage in [null, 0, 30, 400]) {
            for (final aufschlag in [null, 250.0]) {
              for (final erholung in [false, true]) {
                for (final trend in [null, 0.4]) {
                  final name =
                      'basal $basal, aktiv $aktiv, Ziel $ziel in $tage Tagen, '
                      'Aufschlag $aufschlag, Erholung $erholung, Trend $trend';
                  faelle[name] = (
                    () => kalorienzielAnteile(
                      basalKcal: basal,
                      aktivKcal: aktiv,
                      gewichtKg: 80,
                      groesseCm: 180,
                      alter: 30,
                      zielgewichtKg: ziel,
                      tageBisZiel: tage,
                      trainingsaufschlagKcal: aufschlag,
                      inErholung: erholung,
                      gewichtstrendKgProWoche: trend,
                    ),
                    () => kalorienziel(
                      basalKcal: basal,
                      aktivKcal: aktiv,
                      gewichtKg: 80,
                      groesseCm: 180,
                      alter: 30,
                      zielgewichtKg: ziel,
                      tageBisZiel: tage,
                      trainingsaufschlagKcal: aufschlag,
                      inErholung: erholung,
                      gewichtstrendKgProWoche: trend,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }

    test('für ${faelle.length} Kombinationen gleich kalorienziel', () {
      faelle.forEach((name, paar) {
        final (anteile, ziel) = paar;
        final a = anteile();
        final z = ziel();
        expect(z, isNotNull, reason: name);
        expect(a, isNotNull, reason: name);
        expect(a!.summeKcal, closeTo(z!, 1e-6), reason: name);
        expect(
          a.grundumsatzKcal + a.aktivKcal + a.koerperzielKcal,
          closeTo(z, 1e-6),
          reason: name,
        );
        expect(a.koerperzielKcal, greaterThanOrEqualTo(0), reason: name);
      });
    });

    test(
      'der Körperziel-Anteil ist die Differenz zum Ziel ohne Körperziel',
      () {
        final ohne = kalorienziel(gewichtKg: 80, groesseCm: 180, alter: 30)!;
        final mit = kalorienziel(
          gewichtKg: 80,
          groesseCm: 180,
          alter: 30,
          zielgewichtKg: 84,
          tageBisZiel: 182,
        )!;
        final a = kalorienzielAnteile(
          gewichtKg: 80,
          groesseCm: 180,
          alter: 30,
          zielgewichtKg: 84,
          tageBisZiel: 182,
        )!;
        expect(a.koerperzielKcal, closeTo(mit - ohne, 1e-9));
        expect(a.grundumsatzKcal + a.aktivKcal, closeTo(ohne, 1e-9));
      },
    );
  });

  group('Wertgleichheit', () {
    test('gleiche Eingaben, gleiche Anteile — == und hashCode', () {
      KalorienzielAnteile neu() =>
          kalorienzielAnteile(gewichtKg: 80, groesseCm: 180, alter: 30)!;
      expect(neu(), neu());
      expect(neu().hashCode, neu().hashCode);
      expect(
        neu(),
        isNot(
          kalorienzielAnteile(
            basalKcal: 1500,
            aktivKcal: 600,
            gewichtKg: 80,
            groesseCm: 180,
            alter: 30,
          ),
        ),
      );
    });
  });
}
