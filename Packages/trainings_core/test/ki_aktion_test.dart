import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **feste Aktionsliste der KI** (#335, Muster aus #330) —
/// `KiAktion`, `EintraegeBuchen`, `KiHerkunft`, `KiVorschlag`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## Woher die Regeln kommen
///
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitte
/// „Die Aktionsliste (#330)" und „Datenschicht — Schema 14 → 15"
/// (`eintraege.vorschlag`); Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 4.
///
/// - **Die Liste ist der Typ.** Was die KI tun kann, steht als Unterklasse
///   von `sealed class KiAktion`; vorerst gibt es genau eine,
///   `EintraegeBuchen`. Ein `switch` mit diesem einen Fall ist vollständig —
///   kommt eine zweite dazu, meldet der Analyzer jede Stelle, die sie nicht
///   behandelt. Diese Datei ist eine solche Stelle, mit Absicht.
/// - **`KiVorschlag`** = eine Aktion + Herkunft. Er wird angezeigt, nie
///   selbst ausgeführt; ausgeführt wird in der App, nicht im Kern.
/// - **Die Herkunft wandert als JSON in `eintraege.vorschlag`**:
///   `{"anbieter":"gemini","modell":…,"zeitpunkt":…,"zweck":"foto"}`,
///   Zeitpunkt der Antwort in UTC.
///
/// Der Kern importiert nur `dart:core` und `dart:math`; `alsJson` liefert
/// deshalb eine Map, keinen Text — kodiert wird in der App. Alle Werte hier
/// sind **erfunden**; die Zeitpunkte sind Proben, keine Ereignisse.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neu in `Packages/trainings_core/lib/src/ki_aktion.dart`, exportiert über
/// `lib/trainings_core.dart`:
///
/// ```dart
/// sealed class KiAktion {}
///
/// final class EintraegeBuchen extends KiAktion {
///   EintraegeBuchen({
///     required this.posten,
///     required this.mahlzeit,
///     required this.tagesSchluessel,   // ISO-Tag, `yyyy-MM-dd`
///     required this.zeitpunkt,
///   });
///   final List<SchaetzPosten> posten;
///   final Mahlzeit mahlzeit;
///   final String tagesSchluessel;
///   final DateTime zeitpunkt;
/// }
///
/// class KiHerkunft {
///   KiHerkunft({
///     required this.anbieter,
///     required this.modell,
///     required this.zeitpunkt,
///     required this.zweck,
///   });
///   final String anbieter;
///   final String modell;
///   final DateTime zeitpunkt;
///   final String zweck;
///   Map<String, Object?> alsJson();
/// }
///
/// class KiVorschlag {
///   KiVorschlag({required this.aktion, required this.herkunft});
///   final KiAktion aktion;
///   final KiHerkunft herkunft;
/// }
/// ```
///
/// Ob die Konstruktoren `const` sind, legen diese Tests nicht fest.
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht von Tim freigegeben** — jede mit Begründung.
///
/// - **Alle Konstruktoren sind benannt und `required`.** `modell`,
///   `anbieter` und `zweck` sind drei Zeichenfolgen nebeneinander;
///   positionell vertauscht sähe man es keinem Eintrag an.
/// - **`zeitpunkt` in `alsJson` ist ISO 8601 mit `Z`**, auch wenn die
///   Herkunft mit einem lokalen `DateTime` gebaut wurde. Die Spec sagt
///   „Zeitpunkt der Antwort (UTC)"; ein lokaler Zeitstempel ohne Versatz
///   im JSON wäre auf einem anders eingestellten Gerät ein anderer
///   Zeitpunkt.
/// - **Alle Werte in `alsJson` sind Zeichenfolgen** — die Map geht ohne
///   weitere Umwandlung durch `jsonEncode`.
void main() {
  const posten = SchaetzPosten(
    name: 'Prüfhuhn, gegrillt',
    gramm: 140,
    werte: Naehrwerte(kcal: 231, eiweissG: 43.4, kohlenhydrateG: 0, fettG: 5),
    sicher: true,
    herkunft: PostenHerkunft.erkannt,
  );

  KiHerkunft herkunft({DateTime? zeitpunkt}) => KiHerkunft(
    anbieter: 'gemini',
    modell: 'gemini-3.6-flash',
    zeitpunkt: zeitpunkt ?? DateTime.utc(2026, 11, 4, 11, 42, 7),
    zweck: 'foto',
  );

  // ═════════════════════════════════════════════════════════════════════
  group('KiAktion', () {
    test('ein switch mit EintraegeBuchen allein ist vollständig', () {
      // Kompilierprobe: Wäre KiAktion nicht versiegelt oder gäbe es eine
      // zweite Unterklasse, kompilierte diese Funktion nicht.
      String art(KiAktion aktion) => switch (aktion) {
        EintraegeBuchen() => 'buchen',
      };

      final aktion = EintraegeBuchen(
        posten: const [posten],
        mahlzeit: Mahlzeit.mittag,
        tagesSchluessel: '2026-11-04',
        zeitpunkt: DateTime.utc(2026, 11, 4, 11, 30),
      );
      expect(art(aktion), 'buchen');
    });

    test('EintraegeBuchen trägt Posten, Mahlzeit, Tag und Zeitpunkt', () {
      final aktion = EintraegeBuchen(
        posten: const [posten],
        mahlzeit: Mahlzeit.abend,
        tagesSchluessel: '2026-11-04',
        zeitpunkt: DateTime.utc(2026, 11, 4, 18, 15),
      );
      expect(aktion, isA<KiAktion>());
      expect(aktion.posten, [posten]);
      expect(aktion.mahlzeit, Mahlzeit.abend);
      expect(aktion.tagesSchluessel, '2026-11-04');
      expect(aktion.zeitpunkt, DateTime.utc(2026, 11, 4, 18, 15));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('KiHerkunft.alsJson', () {
    test('enthält genau anbieter, modell, zeitpunkt und zweck', () {
      expect(herkunft().alsJson().keys.toSet(), {
        'anbieter',
        'modell',
        'zeitpunkt',
        'zweck',
      });
    });

    test('anbieter, modell und zweck stehen unverändert drin', () {
      final json = herkunft().alsJson();
      expect(json['anbieter'], 'gemini');
      expect(json['modell'], 'gemini-3.6-flash');
      expect(json['zweck'], 'foto');
    });

    test('zeitpunkt ist ein ISO-Text in UTC, der denselben Moment trifft', () {
      final zeitpunkt = DateTime.utc(2026, 11, 4, 11, 42, 7);
      final text = herkunft(zeitpunkt: zeitpunkt).alsJson()['zeitpunkt'];
      expect(text, isA<String>());
      expect(text as String, endsWith('Z'));
      final gelesen = DateTime.parse(text);
      expect(gelesen.isUtc, isTrue);
      expect(gelesen, zeitpunkt);
    });

    test('ein lokaler Zeitpunkt wird als UTC geschrieben', () {
      final utc = DateTime.utc(2026, 11, 4, 11, 42, 7);
      final text =
          herkunft(zeitpunkt: utc.toLocal()).alsJson()['zeitpunkt'] as String;
      expect(text, endsWith('Z'));
      expect(DateTime.parse(text), utc);
    });

    test('alle Werte sind Zeichenfolgen', () {
      for (final wert in herkunft().alsJson().values) {
        expect(wert, isA<String>());
      }
    });

    test('der Zweck testbild steht so drin', () {
      final json = KiHerkunft(
        anbieter: 'gemini',
        modell: 'gemini-3.7-pro-preview',
        zeitpunkt: DateTime.utc(2026, 11, 4, 9),
        zweck: 'testbild',
      ).alsJson();
      expect(json['zweck'], 'testbild');
      expect(json['modell'], 'gemini-3.7-pro-preview');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('KiVorschlag', () {
    test('trägt Aktion und Herkunft', () {
      final aktion = EintraegeBuchen(
        posten: const [posten],
        mahlzeit: Mahlzeit.mittag,
        tagesSchluessel: '2026-11-04',
        zeitpunkt: DateTime.utc(2026, 11, 4, 11, 30),
      );
      final h = herkunft();
      final vorschlag = KiVorschlag(aktion: aktion, herkunft: h);
      expect(vorschlag.aktion, same(aktion));
      expect(vorschlag.herkunft, same(h));
    });
  });
}
