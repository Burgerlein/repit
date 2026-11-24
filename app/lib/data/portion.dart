// Eine **Portion** eines Lebensmittels (#325, Karte #395): „Portion" und
// „Packung" aus Open Food Facts, dazu eigene wie „Bon" oder „Schale".
//
// API und Vertrag sind durch
// `app/test/ernaehrung/off_client_portionen_test.dart` vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
import 'package:flutter/foundation.dart';

import 'lebensmittel_repository.dart';

/// Eine Portion — Name und Menge **in der Einheit des Lebensmittels**
/// (g bzw. ml).
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Portionen stehen
/// in `OffProdukt` und `LebensmittelVorlage`, beide Abhängigkeit von
/// Providern; ohne Wertgleichheit liefe jeder abgeleitete Wert neu —
/// Fehler `03`.
@immutable
class Portion {
  const Portion({
    this.id,
    required this.name,
    required this.mengeG,
    this.herkunft = Herkunft.eigen,
  });

  /// Der Schlüssel in `portionen` — `null` heißt „noch nicht
  /// gespeichert", etwa bei Portionen frisch aus Open Food Facts.
  final int? id;

  /// Zum Beispiel „Portion", „Packung", „Bon".
  final String name;

  /// Die Menge je Portion in g bzw. ml.
  final double mengeG;

  /// Woher die Portion stammt. Ohne Angabe [Herkunft.eigen].
  final Herkunft herkunft;

  /// Dieselbe Portion mit anderem Namen oder anderer Menge — Schlüssel
  /// und Herkunft bleiben.
  Portion mit({String? name, double? mengeG}) => Portion(
    id: id,
    name: name ?? this.name,
    mengeG: mengeG ?? this.mengeG,
    herkunft: herkunft,
  );

  @override
  bool operator ==(Object other) =>
      other is Portion &&
      other.id == id &&
      other.name == name &&
      other.mengeG == mengeG &&
      other.herkunft == herkunft;

  @override
  int get hashCode => Object.hash(id, name, mengeG, herkunft);

  @override
  String toString() =>
      'Portion(id: $id, name: $name, mengeG: $mengeG, '
      'herkunft: ${herkunft.name})';
}
