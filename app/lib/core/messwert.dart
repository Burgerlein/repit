/// Der fachliche Zustand eines aus Apple Health abgeleiteten Werts.
///
/// `AsyncValue` allein reicht nicht: Es kennt keinen Stand-Zeitstempel, und
/// „nie gelaufen" und „gelaufen, nichts gefunden" sind beide `AsyncData([])`
/// — genau die Verwechslung, die als #55 („Das Schritte-Detail hängt")
/// gemeldet ist. `Messwert<T>` macht sie unmöglich, weil es keinen nullbaren
/// Wert anbietet: Wer einen Wert sehen will, muss den Zustand erst
/// unterscheiden.
///
/// Siehe Spec 5.3/5.3a/5.3b in
/// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md`.
sealed class Messwert<T> {
  const Messwert();
}

/// Nie geladen, kein Cache. Platzhalter in Wertgröße.
final class NochNie<T> extends Messwert<T> {
  const NochNie();
}

/// Es gibt einen Wert — aus dem Cache oder frisch.
final class Bekannt<T> extends Messwert<T> {
  const Bekannt(this.wert, {required this.stand, required this.laeuft});

  /// Soll nie leer sein — ein Vertrag des Aufrufers, nicht einer, den dieser
  /// Typ oder `alsMesswert` erzwingen kann: Bei generischem `T` ist „leer"
  /// nicht entscheidbar. `alsMesswert` **verlässt sich** auf das von außen
  /// übergebene `istLeer`, es **prüft** `wert` nicht. Ruft jemand mit
  /// `istLeer: false` auf, obwohl der Wert leer ist, entsteht `Bekannt([])`.
  final T wert;

  /// Woher die Zahl stammt, z. B. „Stand 14:32".
  final DateTime stand;

  /// Wird gerade aktualisiert, der Wert ist also ggf. nicht mehr aktuell.
  final bool laeuft;
}

/// Ein Lauf ist fertig, hat nichts gebracht — und es lag auch nichts im
/// Cache. Der einzige Zustand, der einen „keine Daten"-Grund anzeigen darf.
///
/// **Der Zusatz „und es lag nichts im Cache" ist seit #224 Teil der
/// Bedingung** (Tim, 03.11.2026): Mit Cache bleibt der alte Wert stehen,
/// genauso wie bei einem gescheiterten Lauf. Begründet in `alsMesswert`.
final class LeerNachLauf<T> extends Messwert<T> {
  const LeerNachLauf({required this.gelaufen});

  /// Zeitpunkt des Laufs — es gibt keine Daten, die einen eigenen Stand
  /// hätten.
  final DateTime gelaufen;
}

/// Der Lauf ist gescheitert. Nicht dasselbe wie „nichts gefunden".
final class Fehlgeschlagen<T> extends Messwert<T> {
  const Fehlgeschlagen({required this.fehler, required this.gelaufen});

  final Object fehler;

  /// Zeitpunkt des gescheiterten Laufs.
  final DateTime gelaufen;
}
