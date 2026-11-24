import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **Kosten, Kalendermonat und Monatslimit** des KI-Zugangs (#333).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## Woher die Regeln kommen
///
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitt
/// „Verbrauch und Limit", und Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 2 samt „Review
/// Focus" 2, 3 und 7.
///
/// - **Kosten** = Eingabe × Preis_ein + (Ausgabe + Denken) × Preis_aus, je
///   Million Token, in US-Dollar. **Denk-Token werden als Ausgabe
///   berechnet.** Gerundet wird nur in der Anzeige, nie hier.
/// - **Fehlt ein Zähler in `usageMetadata`, zählt er `0`.** Das ist eine
///   Zählung, kein Messwert — `0` Denk-Token heißt „keine gezählt".
///   Ein Zähler mit falschem Typ ist ein Fehler im Kanal und wirft.
/// - **Kalendermonat in Berliner Zeit**, Schlüssel `yyyy-MM`. Eine Anfrage
///   am 30.11. um 23:30 UTC ist 00:30 Berlin am 1.12. und gehört zum
///   Dezember.
/// - **Das Limit endet am Ersten des Folgemonats, 00:00 Berliner Zeit.**
/// - **Ein Betrag ohne Preis (`null`) zählt als Anfrage, nicht als Geld**,
///   und macht die Summe unvollständig.
/// - **Erreicht heißt `summe >= limit`.** Vorgabe 10 $ (Tim, 04.11.2026).
///
/// ## Die Preise in dieser Datei sind Eingaben, keine Auskunft
///
/// Jeder Preis hier ist eine **erfundene Zahl**, an der sich die Formel
/// nachrechnen lässt. Keiner behauptet, was ein Modell bei Google kostet —
/// die vorbelegten Preise gehören in `app/lib/ki/gemini_preise.dart` und
/// werden dort nicht von diesen Tests geprüft. Die Zeitpunkte sind
/// Kalenderproben für die Monatsgrenze, keine Ereignisse.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neu in `Packages/trainings_core/lib/src/ki_kosten.dart`, exportiert über
/// `lib/trainings_core.dart`:
///
/// ```dart
/// class KiPreis {
///   const KiPreis({required this.eingabeJeMio, required this.ausgabeJeMio});
///   final double eingabeJeMio;   // US-Dollar je 1.000.000 Eingabe-Token
///   final double ausgabeJeMio;   // US-Dollar je 1.000.000 Ausgabe-Token
///   // == und hashCode über beide Felder
/// }
///
/// class KiVerbrauch {
///   const KiVerbrauch({
///     required this.eingabe,
///     required this.ausgabe,
///     required this.denken,
///   });
///   final int eingabe;  // promptTokenCount
///   final int ausgabe;  // candidatesTokenCount
///   final int denken;   // thoughtsTokenCount
///   factory KiVerbrauch.ausUsage(Map<String, Object?>? usage);
/// }
///
/// double kostenUsd(KiVerbrauch v, KiPreis p);
/// String monatsSchluessel(DateTime utc);
/// DateTime naechsterMonatsbeginn(DateTime utc);
///
/// class MonatsSumme {
///   final double usd;
///   final bool unvollstaendig;
///   final int anfragen;
///   // == und hashCode über alle drei Felder
/// }
/// MonatsSumme summiere(Iterable<double?> kosten);
/// bool limitErreicht(MonatsSumme s, double limitUsd);
/// const double standardLimitUsd = 10;
/// ```
///
/// Der Konstruktor von [MonatsSumme] ist frei; diese Tests bauen Summen
/// ausschließlich über [summiere].
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht von Tim freigegeben** — jede mit Begründung.
///
/// - **Die Konstruktoren von [KiPreis] und [KiVerbrauch] sind benannt und
///   `required`.** Zwei bzw. drei Zahlen gleichen Typs nebeneinander sind
///   positionell genau die Vertauschung, die man nicht sieht — Eingabe-
///   und Ausgabepreis unterscheiden sich um ein Vielfaches.
/// - **[MonatsSumme] hat `==` und `hashCode`.** Der Plan verlangt es nur für
///   [KiPreis]. Die Summe steht aber im Zustand des KI-Zugangs
///   (`MitSchluessel.summe`) und wird je Anfrage neu gerechnet; ohne
///   Wertgleichheit wäre jede neu gerechnete, inhaltsgleiche Summe ein
///   neuer Zustand (`CLAUDE.md`, „Ein Werttyp, der Abhängigkeit eines
///   Providers ist, braucht `==` und `hashCode`").
/// - **Unbekannte Felder in `usageMetadata` werden übergangen.** Die echte
///   Antwort trägt weitere Felder (`totalTokenCount`,
///   `promptTokensDetails` als Liste …); an ihnen darf die Kostenrechnung
///   nicht scheitern.
/// - **Eine leere Summe ist `0 $`, vollständig, null Anfragen** — es fehlt
///   kein Betrag, es gab keinen.
/// - **Limit `0` ist sofort erreicht.** Das folgt aus `>=` und ist der
///   einzige Weg, die KI über das Limit ganz abzuschalten.
void main() {
  // ═════════════════════════════════════════════════════════════════════
  group('KiPreis', () {
    test('Wertgleichheit über beide Felder', () {
      const a = KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75);
      const b = KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('ungleich, sobald ein Feld abweicht', () {
      const a = KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75);
      expect(a, isNot(const KiPreis(eingabeJeMio: 0.80, ausgabeJeMio: 3.75)));
      expect(a, isNot(const KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.80)));
    });

    test('Eingabe- und Ausgabepreis sind nicht vertauschbar', () {
      expect(
        const KiPreis(eingabeJeMio: 1, ausgabeJeMio: 2),
        isNot(const KiPreis(eingabeJeMio: 2, ausgabeJeMio: 1)),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('KiVerbrauch.ausUsage', () {
    test('liest die drei Zähler', () {
      final v = KiVerbrauch.ausUsage({
        'promptTokenCount': 1200,
        'candidatesTokenCount': 340,
        'thoughtsTokenCount': 560,
      });
      expect(v.eingabe, 1200);
      expect(v.ausgabe, 340);
      expect(v.denken, 560);
    });

    test('ein leeres usageMetadata zählt überall 0', () {
      final v = KiVerbrauch.ausUsage({});
      expect(v.eingabe, 0);
      expect(v.ausgabe, 0);
      expect(v.denken, 0);
    });

    test('ohne usageMetadata (null) zählt überall 0', () {
      final v = KiVerbrauch.ausUsage(null);
      expect(v.eingabe, 0);
      expect(v.ausgabe, 0);
      expect(v.denken, 0);
    });

    test('fehlende Denk-Token zählen 0, die übrigen bleiben', () {
      // Ein Modell ohne Denkschritt schickt `thoughtsTokenCount` nicht mit.
      final v = KiVerbrauch.ausUsage({
        'promptTokenCount': 800,
        'candidatesTokenCount': 120,
      });
      expect(v.eingabe, 800);
      expect(v.ausgabe, 120);
      expect(v.denken, 0);
    });

    test('unbekannte Felder werden übergangen', () {
      final v = KiVerbrauch.ausUsage({
        'promptTokenCount': 10,
        'candidatesTokenCount': 20,
        'thoughtsTokenCount': 30,
        'totalTokenCount': 60,
        'promptTokensDetails': [
          {'modality': 'IMAGE', 'tokenCount': 4},
          {'modality': 'TEXT', 'tokenCount': 6},
        ],
      });
      expect(v.eingabe, 10);
      expect(v.ausgabe, 20);
      expect(v.denken, 30);
    });

    test('Zahl als Text in promptTokenCount wirft', () {
      expect(
        () => KiVerbrauch.ausUsage({'promptTokenCount': '12'}),
        throwsFormatException,
      );
    });

    test('Zahl als Text in candidatesTokenCount wirft', () {
      expect(
        () => KiVerbrauch.ausUsage({'candidatesTokenCount': '12'}),
        throwsFormatException,
      );
    });

    test('Zahl als Text in thoughtsTokenCount wirft', () {
      expect(
        () => KiVerbrauch.ausUsage({'thoughtsTokenCount': '12'}),
        throwsFormatException,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('kostenUsd', () {
    test('Pflichtfall: 1 Mio. Eingabe, je 0,5 Mio. Ausgabe und Denken', () {
      const v = KiVerbrauch(eingabe: 1000000, ausgabe: 500000, denken: 500000);
      const p = KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75);
      expect(kostenUsd(v, p), closeTo(0.75 + 3.75, 1e-12));
    });

    test('Denk-Token kosten den Ausgabepreis, nicht den Eingabepreis', () {
      // Review Focus 2: Wer Denk-Token vergisst oder als Eingabe rechnet,
      // bekommt hier 0 bzw. 1 statt 10.
      const v = KiVerbrauch(eingabe: 0, ausgabe: 0, denken: 1000000);
      const p = KiPreis(eingabeJeMio: 1, ausgabeJeMio: 10);
      expect(kostenUsd(v, p), closeTo(10, 1e-12));
    });

    test('Ausgabe-Token kosten den Ausgabepreis', () {
      const v = KiVerbrauch(eingabe: 0, ausgabe: 2000000, denken: 0);
      const p = KiPreis(eingabeJeMio: 1, ausgabeJeMio: 10);
      expect(kostenUsd(v, p), closeTo(20, 1e-12));
    });

    test('Eingabe-Token kosten den Eingabepreis', () {
      const v = KiVerbrauch(eingabe: 3000000, ausgabe: 0, denken: 0);
      const p = KiPreis(eingabeJeMio: 1, ausgabeJeMio: 10);
      expect(kostenUsd(v, p), closeTo(3, 1e-12));
    });

    test('kein Verbrauch kostet nichts', () {
      const v = KiVerbrauch(eingabe: 0, ausgabe: 0, denken: 0);
      const p = KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75);
      expect(kostenUsd(v, p), 0);
    });

    test('kleine Beträge werden nicht auf Cent gerundet', () {
      // 1.290 Eingabe zu 0,5 $ + 210 Ausgabe + 400 Denken zu 2 $:
      // 0,000645 + 0,00122 = 0,001865 $ — gerundet hieße das 0,00 $.
      const v = KiVerbrauch(eingabe: 1290, ausgabe: 210, denken: 400);
      const p = KiPreis(eingabeJeMio: 0.5, ausgabeJeMio: 2);
      expect(kostenUsd(v, p), closeTo(0.001865, 1e-12));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('monatsSchluessel', () {
    test('mitten im Monat', () {
      expect(monatsSchluessel(DateTime.utc(2026, 11, 15, 12)), '2026-11');
    });

    test('Monat ist zweistellig', () {
      expect(monatsSchluessel(DateTime.utc(2027, 2, 10, 12)), '2027-02');
    });

    test('30.11. 23:30 UTC ist 00:30 Berlin am 1.12. — Dezember', () {
      // Review Focus 3.
      expect(monatsSchluessel(DateTime.utc(2026, 11, 30, 23, 30)), '2026-12');
    });

    test('30.11. 22:59 UTC ist 23:59 Berlin — noch November', () {
      expect(monatsSchluessel(DateTime.utc(2026, 11, 30, 22, 59)), '2026-11');
    });

    test('Monatswechsel genau um 00:00 Berlin (Winterzeit)', () {
      expect(monatsSchluessel(DateTime.utc(2026, 11, 30, 23)), '2026-12');
    });

    test('31.03. 22:30 UTC ist 00:30 Berlin am 1.4. — April (Sommerzeit)', () {
      expect(monatsSchluessel(DateTime.utc(2026, 3, 31, 22, 30)), '2026-04');
    });

    test('31.03. 21:59 UTC ist 23:59 Berlin — noch März (Sommerzeit)', () {
      expect(monatsSchluessel(DateTime.utc(2026, 3, 31, 21, 59)), '2026-03');
    });

    test('Ende Oktober gilt nach der Umstellung wieder UTC+1', () {
      // Die Sommerzeit endet am letzten Oktobersonntag; am 31.10. abends
      // ist Berlin UTC+1. 22:30 UTC ist 23:30 Berlin, 23:00 UTC ist
      // Mitternacht.
      expect(monatsSchluessel(DateTime.utc(2026, 10, 31, 22, 30)), '2026-10');
      expect(monatsSchluessel(DateTime.utc(2026, 10, 31, 23)), '2026-11');
    });

    test('Silvester 23:30 UTC gehört schon zum Januar des Folgejahres', () {
      expect(monatsSchluessel(DateTime.utc(2026, 12, 31, 23, 30)), '2027-01');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('naechsterMonatsbeginn', () {
    test('Mitte November → 1.12. 00:00 Berlin = 30.11. 23:00 UTC', () {
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 11, 15)),
        DateTime.utc(2026, 11, 30, 23),
      );
    });

    test('das Ergebnis ist ein UTC-Zeitpunkt', () {
      expect(naechsterMonatsbeginn(DateTime.utc(2026, 11, 15)).isUtc, isTrue);
    });

    test('Mitte März → 1.4. 00:00 Berlin = 31.3. 22:00 UTC (Sommerzeit)', () {
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 3, 15)),
        DateTime.utc(2026, 3, 31, 22),
      );
    });

    test('Mitte Oktober → 1.11. 00:00 Berlin = 31.10. 23:00 UTC', () {
      // Der Oktober beginnt in Sommerzeit und endet in Winterzeit; maßgeblich
      // ist der Versatz am Zielzeitpunkt.
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 10, 15)),
        DateTime.utc(2026, 10, 31, 23),
      );
    });

    test('Dezember → 1.1. des Folgejahres', () {
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 12, 10)),
        DateTime.utc(2026, 12, 31, 23),
      );
    });

    test('30.11. 23:30 UTC liegt schon im Dezember → 1.1.', () {
      // Dieselbe Grenze wie bei monatsSchluessel: maßgeblich ist der
      // Berliner Monat, nicht der UTC-Monat.
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 11, 30, 23, 30)),
        DateTime.utc(2026, 12, 31, 23),
      );
    });

    test('genau am Monatsbeginn → der Beginn des nächsten, nicht derselbe', () {
      expect(
        naechsterMonatsbeginn(DateTime.utc(2026, 11, 30, 23)),
        DateTime.utc(2026, 12, 31, 23),
      );
    });

    test('passt zu monatsSchluessel: die Grenze trennt die beiden Monate', () {
      for (final zeitpunkt in [
        DateTime.utc(2026, 1, 20, 8),
        DateTime.utc(2026, 3, 3, 3),
        DateTime.utc(2026, 6, 30, 21, 59),
        DateTime.utc(2026, 10, 1, 0, 30),
        DateTime.utc(2026, 11, 30, 22, 59),
      ]) {
        final grenze = naechsterMonatsbeginn(zeitpunkt);
        final davor = grenze.subtract(const Duration(microseconds: 1));
        expect(
          monatsSchluessel(davor),
          monatsSchluessel(zeitpunkt),
          reason: 'kurz vor der Grenze noch der Monat von $zeitpunkt',
        );
        expect(
          monatsSchluessel(grenze),
          isNot(monatsSchluessel(zeitpunkt)),
          reason: 'an der Grenze schon der Folgemonat von $zeitpunkt',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('summiere', () {
    test('ein Betrag ohne Preis zählt als Anfrage, nicht als Geld', () {
      // Review Focus 7.
      final s = summiere([1.0, null, 2.0]);
      expect(s.usd, closeTo(3.0, 1e-12));
      expect(s.unvollstaendig, isTrue);
      expect(s.anfragen, 3);
    });

    test('nur bekannte Beträge → vollständig', () {
      final s = summiere([0.5, 0.25]);
      expect(s.usd, closeTo(0.75, 1e-12));
      expect(s.unvollstaendig, isFalse);
      expect(s.anfragen, 2);
    });

    test('nur unbekannte Beträge → 0 \$, unvollständig', () {
      final s = summiere([null, null]);
      expect(s.usd, 0);
      expect(s.unvollstaendig, isTrue);
      expect(s.anfragen, 2);
    });

    test('keine Anfragen → 0 \$, vollständig, 0 Anfragen', () {
      final s = summiere(const []);
      expect(s.usd, 0);
      expect(s.unvollstaendig, isFalse);
      expect(s.anfragen, 0);
    });

    test('ein Betrag von 0 \$ ist ein Betrag, keine Lücke', () {
      final s = summiere([0.0]);
      expect(s.usd, 0);
      expect(s.unvollstaendig, isFalse);
      expect(s.anfragen, 1);
    });

    test('nimmt jedes Iterable, nicht nur Listen', () {
      final s = summiere(
        Iterable<double?>.generate(4, (i) => i.isEven ? 1.5 : null),
      );
      expect(s.usd, closeTo(3.0, 1e-12));
      expect(s.unvollstaendig, isTrue);
      expect(s.anfragen, 4);
    });

    test('Wertgleichheit über alle drei Felder', () {
      expect(summiere([1.0, null]), equals(summiere([1.0, null])));
      expect(summiere([1.0, null]).hashCode, summiere([1.0, null]).hashCode);
      expect(summiere([1.0, null]), isNot(summiere([1.0])));
      expect(summiere([1.0, 0.0]), isNot(summiere([1.0])));
      expect(summiere([1.0]), isNot(summiere([2.0])));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('limitErreicht', () {
    test('die Vorgabe ist 10 \$', () {
      expect(standardLimitUsd, 10);
    });

    test('genau am Limit ist erreicht', () {
      expect(limitErreicht(summiere([10.0]), 10), isTrue);
    });

    test('knapp darunter ist nicht erreicht', () {
      expect(limitErreicht(summiere([9.999]), 10), isFalse);
    });

    test('darüber ist erreicht', () {
      expect(limitErreicht(summiere([6.0, 4.5]), 10), isTrue);
    });

    test('Anfragen ohne Preis bringen niemanden ans Limit', () {
      final s = summiere([9.0, null, null, null]);
      expect(limitErreicht(s, 10), isFalse);
    });

    test('ein geändertes Limit gilt', () {
      expect(limitErreicht(summiere([3.0]), 2.5), isTrue);
      expect(limitErreicht(summiere([3.0]), 25), isFalse);
    });

    test('Limit 0 ist sofort erreicht', () {
      expect(limitErreicht(summiere(const []), 0), isTrue);
    });
  });
}
