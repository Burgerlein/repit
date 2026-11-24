import 'berlin_calendar.dart';

// Kosten, Kalendermonat und Monatslimit des KI-Zugangs (#333).
//
// Alles hier ist **Selbstzählung**: Die App rechnet aus den Token, die
// Gemini je Antwort meldet, und aus Preisen, die sie selbst kennt. Was
// Google tatsächlich abrechnet, weiß der Kern nicht und behauptet es nicht.
// Beträge sind US-Dollar und werden hier **nie gerundet** — gerundet wird
// nur in der Anzeige.

/// Der Preis eines Modells in US-Dollar je 1.000.000 Token.
///
/// Welche Zahlen hier hineingehören, steht nicht im Kern, sondern in der
/// App (`app/lib/ki/gemini_preise.dart` und Tims Überschreibungen). Werttyp
/// mit [==] und [hashCode], weil ein Preis Abhängigkeit eines Providers ist
/// (`CLAUDE.md`, Fehler `03`).
class KiPreis {
  /// Benannt und `required`: Zwei Zahlen gleichen Typs nebeneinander wären
  /// positionell genau die Vertauschung, die man nicht sieht.
  const KiPreis({required this.eingabeJeMio, required this.ausgabeJeMio});

  /// US-Dollar je 1.000.000 Eingabe-Token.
  final double eingabeJeMio;

  /// US-Dollar je 1.000.000 Ausgabe-Token. Gilt auch für Denk-Token.
  final double ausgabeJeMio;

  @override
  bool operator ==(Object other) =>
      other is KiPreis &&
      other.eingabeJeMio == eingabeJeMio &&
      other.ausgabeJeMio == ausgabeJeMio;

  @override
  int get hashCode => Object.hash(eingabeJeMio, ausgabeJeMio);

  @override
  String toString() =>
      'KiPreis(eingabeJeMio: $eingabeJeMio, ausgabeJeMio: $ausgabeJeMio)';
}

/// Die Token einer Antwort, wie Gemini sie in `usageMetadata` meldet.
///
/// Anders als ein Messwert aus Apple Health ist das eine **Zählung**: `0`
/// Denk-Token heißt „keine gezählt", nicht „unbekannt". Darum stehen hier
/// `int`, nicht `int?`.
class KiVerbrauch {
  const KiVerbrauch({
    required this.eingabe,
    required this.ausgabe,
    required this.denken,
  });

  /// Liest die drei Zähler aus dem **dekodierten** `usageMetadata`.
  ///
  /// - `promptTokenCount` → [eingabe], `candidatesTokenCount` → [ausgabe],
  ///   `thoughtsTokenCount` → [denken].
  /// - Ein fehlender Zähler, ein Zähler mit `null` und ein fehlendes
  ///   `usageMetadata` (`null`) zählen `0`.
  /// - Ein Zähler, der kein `int` ist, wirft eine [FormatException] — das
  ///   ist ein Fehler im Kanal, keine Datenlage.
  /// - Alle übrigen Felder werden übergangen.
  factory KiVerbrauch.ausUsage(Map<String, Object?>? usage) {
    if (usage == null) {
      return const KiVerbrauch(eingabe: 0, ausgabe: 0, denken: 0);
    }
    return KiVerbrauch(
      eingabe: _zaehler(usage, 'promptTokenCount'),
      ausgabe: _zaehler(usage, 'candidatesTokenCount'),
      denken: _zaehler(usage, 'thoughtsTokenCount'),
    );
  }

  /// `promptTokenCount`.
  final int eingabe;

  /// `candidatesTokenCount`.
  final int ausgabe;

  /// `thoughtsTokenCount`. Wird zum Ausgabepreis berechnet.
  final int denken;

  @override
  bool operator ==(Object other) =>
      other is KiVerbrauch &&
      other.eingabe == eingabe &&
      other.ausgabe == ausgabe &&
      other.denken == denken;

  @override
  int get hashCode => Object.hash(eingabe, ausgabe, denken);

  @override
  String toString() =>
      'KiVerbrauch(eingabe: $eingabe, ausgabe: $ausgabe, denken: $denken)';
}

int _zaehler(Map<String, Object?> usage, String schluessel) {
  final wert = usage[schluessel];
  if (wert == null) return 0;
  if (wert is int) return wert;
  throw FormatException(
    '$schluessel ist kein int, sondern ${wert.runtimeType}',
    wert,
  );
}

/// Die Kosten einer Antwort in US-Dollar, ungerundet:
/// `(eingabe · Preis_ein + (ausgabe + denken) · Preis_aus) / 1.000.000`.
///
/// **Denk-Token kosten den Ausgabepreis.**
double kostenUsd(KiVerbrauch v, KiPreis p) =>
    (v.eingabe * p.eingabeJeMio + (v.ausgabe + v.denken) * p.ausgabeJeMio) /
    1e6;

/// Der Berliner Kalendermonat von [utc] als Schlüssel `yyyy-MM`.
///
/// Maßgeblich ist die Berliner Wanduhr, nicht der UTC-Monat: 30.11. 23:30
/// UTC ist 00:30 am 1.12. in Berlin und gehört zum Dezember.
String monatsSchluessel(DateTime utc) =>
    BerlinCalendar.dayKey(utc).substring(0, 7);

/// Wann das Limit des Monats von [utc] endet: der Erste des Folgemonats,
/// 00:00 Berliner Zeit, als UTC-Zeitpunkt.
///
/// Liegt [utc] genau auf einem Monatsbeginn, ist das Ergebnis der Beginn
/// des **nächsten** Monats — der Zeitpunkt gehört schon zum neuen.
DateTime naechsterMonatsbeginn(DateTime utc) =>
    BerlinCalendar.addMonths(utc, 1);

/// Die Kosten eines Monats, summiert über alle Anfragen.
///
/// Werttyp mit [==] und [hashCode] über alle drei Felder: Die Summe steht
/// im Zustand des KI-Zugangs und wird je Anfrage neu gerechnet (`CLAUDE.md`,
/// Fehler `03`).
class MonatsSumme {
  const MonatsSumme({
    required this.usd,
    required this.unvollstaendig,
    required this.anfragen,
  });

  /// Summe aller **bekannten** Beträge in US-Dollar, ungerundet.
  final double usd;

  /// Mindestens eine Anfrage hatte keinen Betrag (kein Preis für ihr
  /// Modell). [usd] ist dann eine Untergrenze.
  final bool unvollstaendig;

  /// Alle Anfragen, mit und ohne Betrag.
  final int anfragen;

  @override
  bool operator ==(Object other) =>
      other is MonatsSumme &&
      other.usd == usd &&
      other.unvollstaendig == unvollstaendig &&
      other.anfragen == anfragen;

  @override
  int get hashCode => Object.hash(usd, unvollstaendig, anfragen);

  @override
  String toString() =>
      'MonatsSumme(usd: $usd, unvollstaendig: $unvollstaendig, '
      'anfragen: $anfragen)';
}

/// Summiert die Beträge eines Monats.
///
/// Ein Betrag `null` (kein Preis bekannt) zählt als Anfrage, nicht als
/// Geld, und macht die Summe [MonatsSumme.unvollstaendig]. Eine leere
/// Folge ist `0 $`, vollständig, null Anfragen — es fehlt kein Betrag, es
/// gab keinen.
MonatsSumme summiere(Iterable<double?> kosten) {
  var usd = 0.0;
  var unvollstaendig = false;
  var anfragen = 0;
  for (final betrag in kosten) {
    anfragen++;
    if (betrag == null) {
      unvollstaendig = true;
    } else {
      usd += betrag;
    }
  }
  return MonatsSumme(
    usd: usd,
    unvollstaendig: unvollstaendig,
    anfragen: anfragen,
  );
}

/// Ob das Monatslimit erreicht ist: `summe >= limit`.
///
/// Gezählt werden nur bekannte Beträge; Anfragen ohne Preis bringen
/// niemanden ans Limit. Ein Limit von `0` ist damit sofort erreicht.
bool limitErreicht(MonatsSumme s, double limitUsd) => s.usd >= limitUsd;

/// Das Monatslimit, solange Tim kein anderes eingestellt hat, in US-Dollar.
const double standardLimitUsd = 10;
