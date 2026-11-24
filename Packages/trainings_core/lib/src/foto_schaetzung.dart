import 'naehrwerte.dart';

// Die Foto-Schätzung im Kern (#335): die Antwort der KI gegen das Schema
// prüfen, Posten auf Plausibilität sehen, eine Menge umrechnen und
// festlegen, was vorab übernommen ist.
//
// Alles hier ist **Schätzung**, keine Nährwertauskunft; die Kennzeichnung
// als solche ist Sache der Ansicht.

/// Woher eine Zeile im Prüfblatt stammt.
enum PostenHerkunft {
  /// Aus der Antwort der KI, unverändert.
  erkannt,

  /// Von Tim geändert, etwa in der Menge.
  vonDir,

  /// Von Tim über die Suche hinzugefügt.
  ergaenzt,
}

/// Ein Posten einer Schätzung: ein Lebensmittel mit Menge und Nährwerten
/// **für diese Menge**, nicht je 100 g.
///
/// [gramm] und jeder Nährwert dürfen `null` sein, und `null` bleibt `null`
/// — nie `0` (`CLAUDE.md`, Fehler `01`).
///
/// Werttyp mit [==] und [hashCode] über alle Felder (Fehler `03`).
class SchaetzPosten {
  /// Benannt und `required`, auch für das nullbare [gramm]: Ein vergessenes
  /// Gramm soll ein Kompilierfehler sein, kein stilles `null`.
  const SchaetzPosten({
    required this.name,
    required this.gramm,
    required this.werte,
    required this.sicher,
    required this.herkunft,
  });

  final String name;

  /// Die Menge in Gramm; `null`, wenn die KI sie nicht schätzen konnte.
  final double? gramm;

  /// Nährwerte für [gramm], nicht je 100 g.
  final Naehrwerte werte;

  /// Siehe [leseAntwort]: `confident`, mit Gramm, mit kcal und [plausibel].
  final bool sicher;

  final PostenHerkunft herkunft;

  @override
  bool operator ==(Object other) =>
      other is SchaetzPosten &&
      other.name == name &&
      other.gramm == gramm &&
      other.werte == werte &&
      other.sicher == sicher &&
      other.herkunft == herkunft;

  @override
  int get hashCode => Object.hash(name, gramm, werte, sicher, herkunft);

  @override
  String toString() =>
      'SchaetzPosten(name: $name, gramm: $gramm, werte: $werte, '
      'sicher: $sicher, herkunft: $herkunft)';
}

/// Die geprüfte Antwort der KI auf ein Foto.
sealed class SchaetzAntwort {
  const SchaetzAntwort();
}

/// Auf dem Foto ist Essen erkannt.
///
/// Ohne [==]: Der Typ ist ein Ergebnis von [leseAntwort], kein Werttyp.
final class Erkannt extends SchaetzAntwort {
  const Erkannt({required this.titel, required this.posten, this.notiz});

  /// `title` der Antwort.
  final String titel;

  /// Die Posten in der Reihenfolge der Antwort. Aus [leseAntwort] kommt
  /// eine unveränderliche Liste; wer [Erkannt] selbst baut, bestimmt das
  /// selbst.
  final List<SchaetzPosten> posten;

  /// `note` der Antwort; `null`, wenn sie fehlt.
  final String? notiz;
}

/// Kein Essen erkannt (`isFood: false`) — zu dunkel, unscharf oder kein
/// Teller.
final class KeinEssen extends SchaetzAntwort {
  const KeinEssen();
}

/// Prüft die **dekodierte** Antwort gegen das Schema und liest sie.
///
/// - `isFood` muss ein `bool` sein. `false` ergibt [KeinEssen], gleich, was
///   sonst in der Antwort steht — nichts zu buchen ist die vorsichtige
///   Lesart, wenn die KI sich widerspricht.
/// - Bei `isFood: true` müssen `title` Text und `items` eine Liste sein;
///   `note` ist Text oder fehlt.
/// - Je Posten: `name` Text, `confident` `bool`; `grams`, `kcal`,
///   `proteinG`, `carbsG`, `fatG` sind Zahlen oder `null`, und ein
///   fehlender Schlüssel gilt als `null`. `grams` darf nicht negativ sein.
///   Ganze Zahlen (`int`) sind Zahlen.
/// - Die übrigen Felder von [Naehrwerte] bleiben `null`; jeder Posten hat
///   die Herkunft [PostenHerkunft.erkannt].
/// - **Sicher** ist ein Posten bei `confident && gramm != null &&
///   kcal != null && plausibel`.
///
/// Jede Verletzung wirft eine [FormatException] und verwirft die ganze
/// Antwort, auch wenn nur ein Posten kaputt ist.
SchaetzAntwort leseAntwort(Map<String, Object?> json) {
  final isFood = json['isFood'];
  if (isFood is! bool) {
    throw FormatException('isFood ist kein bool', isFood);
  }
  if (!isFood) return const KeinEssen();

  final titel = json['title'];
  if (titel is! String) {
    throw FormatException('title ist kein Text', titel);
  }
  final notiz = json['note'];
  if (notiz != null && notiz is! String) {
    throw FormatException('note ist kein Text', notiz);
  }
  final items = json['items'];
  if (items is! List) {
    throw FormatException('items ist keine Liste', items);
  }

  return Erkannt(
    titel: titel,
    posten: List.unmodifiable([for (final item in items) _lesePosten(item)]),
    notiz: notiz as String?,
  );
}

SchaetzPosten _lesePosten(Object? item) {
  if (item is! Map) {
    throw FormatException('Posten ist kein Objekt', item);
  }
  final name = item['name'];
  if (name is! String) {
    throw FormatException('name ist kein Text', name);
  }
  final confident = item['confident'];
  if (confident is! bool) {
    throw FormatException('confident ist kein bool', confident);
  }
  final gramm = _zahlOderNull(item, 'grams');
  if (gramm != null && gramm < 0) {
    throw FormatException('grams ist negativ', gramm);
  }
  final werte = Naehrwerte(
    kcal: _zahlOderNull(item, 'kcal'),
    eiweissG: _zahlOderNull(item, 'proteinG'),
    kohlenhydrateG: _zahlOderNull(item, 'carbsG'),
    fettG: _zahlOderNull(item, 'fatG'),
  );
  return SchaetzPosten(
    name: name,
    gramm: gramm,
    werte: werte,
    sicher:
        confident && gramm != null && werte.kcal != null && plausibel(werte),
    herkunft: PostenHerkunft.erkannt,
  );
}

double? _zahlOderNull(Map<Object?, Object?> item, String schluessel) {
  final wert = item[schluessel];
  if (wert == null) return null;
  if (wert is num) return wert.toDouble();
  throw FormatException('$schluessel ist keine Zahl', wert);
}

/// Ob die Kalorien eines Postens zu seinen Makros passen.
///
/// `false`, wenn kcal, Eiweiß, Kohlenhydrate oder Fett fehlt. Sonst
/// plausibel bei `|kcal − (4·E + 4·K + 9·F)| ≤ 0,2·kcal + 10` — die Grenze
/// selbst ist plausibel. `0` ist eine Angabe: Ein Posten mit lauter Nullen
/// ist plausibel. Die übrigen Felder spielen keine Rolle.
bool plausibel(Naehrwerte w) {
  final kcal = w.kcal;
  final eiweiss = w.eiweissG;
  final kohlenhydrate = w.kohlenhydrateG;
  final fett = w.fettG;
  if (kcal == null ||
      eiweiss == null ||
      kohlenhydrate == null ||
      fett == null) {
    return false;
  }
  final ausMakros = 4 * eiweiss + 4 * kohlenhydrate + 9 * fett;
  return (kcal - ausMakros).abs() <= 0.2 * kcal + 10;
}

/// [p] mit einer neuen Menge [gramm]; die Herkunft ist danach
/// [PostenHerkunft.vonDir].
///
/// Jeder Nährwert skaliert linear mit `gramm / p.gramm`, auch die in
/// [Naehrwerte.extra]; was fehlte, fehlt weiter, und `0 g` ergeben `0`.
///
/// Ist `p.gramm` `null` oder `0`, gibt es kein Verhältnis: Dann sind
/// **alle** Nährwerte `null`, auch wenn die KI welche geliefert hat — ein
/// Wert zu einer unbekannten Menge ist kein Wert für die neue.
///
/// [SchaetzPosten.sicher] bleibt, wie es war; ob eine geänderte Zeile
/// übernommen ist, entscheidet ihre Herkunft (siehe [uebernommen]).
SchaetzPosten mitMenge(SchaetzPosten p, double gramm) {
  final basis = p.gramm;
  final Naehrwerte werte;
  if (basis == null || basis == 0) {
    werte = const Naehrwerte();
  } else {
    double? skaliert(double? wert) =>
        wert == null ? null : wert * gramm / basis;
    final w = p.werte;
    werte = Naehrwerte(
      kcal: skaliert(w.kcal),
      eiweissG: skaliert(w.eiweissG),
      kohlenhydrateG: skaliert(w.kohlenhydrateG),
      fettG: skaliert(w.fettG),
      zuckerG: skaliert(w.zuckerG),
      ballaststoffeG: skaliert(w.ballaststoffeG),
      gesaettigtG: skaliert(w.gesaettigtG),
      wasserMl: skaliert(w.wasserMl),
      extra: {
        for (final eintrag in w.extra.entries)
          eintrag.key: skaliert(eintrag.value),
      },
    );
  }
  return SchaetzPosten(
    name: p.name,
    gramm: gramm,
    werte: werte,
    sicher: p.sicher,
    herkunft: PostenHerkunft.vonDir,
  );
}

/// Die Posten, die vorab übernommen sind, in ihrer Reihenfolge: alle
/// sicheren, alle, die Tim berührt hat ([PostenHerkunft.vonDir],
/// [PostenHerkunft.ergaenzt]), und seit #407 auch unsichere mit Menge
/// (Tim, 07.11.2026: unsicher soll nicht heißen „erst anfassen, dann
/// buchen“). Ihr Abzeichen „unsicher“ hängt an [SchaetzPosten.sicher] und
/// bleibt. Es fehlen nur unsichere, unberührte Posten **ohne** Menge — die
/// lassen sich nicht buchen.
List<SchaetzPosten> uebernommen(List<SchaetzPosten> posten) => [
  for (final p in posten)
    if (p.sicher || p.herkunft != PostenHerkunft.erkannt || p.gramm != null)
      p,
];
