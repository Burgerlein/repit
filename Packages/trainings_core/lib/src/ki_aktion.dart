import 'foto_schaetzung.dart';
import 'mahlzeit.dart';

/// Was die KI tun kann — **die Liste ist der Typ** (#330, #335).
///
/// Jede Aktion ist eine Unterklasse; eine Aktion, die es nicht gibt, ist
/// nicht ausdrückbar. Vorerst gibt es genau eine, [EintraegeBuchen]. Kommt
/// eine zweite dazu, meldet der Analyzer jeden `switch`, der sie nicht
/// behandelt.
///
/// Der Kern führt nichts aus. Ausgeführt wird in der App, und nur auf
/// Tims Tipp.
sealed class KiAktion {
  const KiAktion();
}

/// Posten als Einträge einer Mahlzeit buchen.
final class EintraegeBuchen extends KiAktion {
  /// [posten] wird als unveränderliche Kopie gehalten.
  EintraegeBuchen({
    required List<SchaetzPosten> posten,
    required this.mahlzeit,
    required this.tagesSchluessel,
    required this.zeitpunkt,
  }) : posten = List.unmodifiable(posten);

  final List<SchaetzPosten> posten;

  final Mahlzeit mahlzeit;

  /// Der ISO-Tag (`yyyy-MM-dd`), auf den gebucht wird. Ob er zu
  /// [zeitpunkt] passt, prüft hier niemand.
  final String tagesSchluessel;

  /// Die Uhrzeit der Einträge.
  final DateTime zeitpunkt;
}

/// Woher ein Vorschlag stammt; wandert als JSON in `eintraege.vorschlag`.
class KiHerkunft {
  /// [zeitpunkt] wird als UTC gehalten, gleich, wie er übergeben wird.
  KiHerkunft({
    required this.anbieter,
    required this.modell,
    required DateTime zeitpunkt,
    required this.zweck,
  }) : zeitpunkt = zeitpunkt.toUtc();

  /// Etwa `gemini`.
  final String anbieter;

  /// Die Modell-id ohne `models/`.
  final String modell;

  /// Zeitpunkt der Antwort, in UTC.
  final DateTime zeitpunkt;

  /// Etwa `foto` oder `testbild`.
  final String zweck;

  /// `{anbieter, modell, zeitpunkt, zweck}`, alle Werte als Text;
  /// [zeitpunkt] als ISO 8601 mit `Z`.
  ///
  /// Eine Map, kein JSON-Text: Der Kern importiert kein `dart:convert`,
  /// kodiert wird in der App.
  Map<String, Object?> alsJson() => {
    'anbieter': anbieter,
    'modell': modell,
    'zeitpunkt': zeitpunkt.toIso8601String(),
    'zweck': zweck,
  };
}

/// Eine Aktion mit ihrer Herkunft. Wird angezeigt, nie selbst ausgeführt.
class KiVorschlag {
  KiVorschlag({required this.aktion, required this.herkunft});

  final KiAktion aktion;

  final KiHerkunft herkunft;
}
