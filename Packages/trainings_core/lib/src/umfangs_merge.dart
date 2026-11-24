/// Das Zusammenführen der beiden Umfangsquellen (#88, #475): Die Importdatei
/// gehört dem Dashboard, die eingetippten Werte der App.
///
/// Verbindlich festgelegt durch
/// `Packages/trainings_core/test/umfangs_merge_test.dart` (siehe dessen
/// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// **Zusammengeführt wird beim Lesen, nicht beim Schreiben.** In der Tabelle
/// steht die Quelle im Primärschlüssel; sonst überschriebe der nächste
/// Importlauf den getippten Wert, und hier gäbe es nichts mehr zu
/// entscheiden.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/CircumferenceMerge.swift`.
library;

import 'berlin_calendar.dart';
import 'umfang.dart';

/// Eine Messung: ein Tag und die Maße, die an ihm gemessen wurden.
///
/// Ein Wörterbuch und nicht fünfzehn Optionale: Leere Felder werden nicht
/// gespeichert, ein fehlendes Maß fehlt — es steht nicht mit `0` da.
///
/// Werttyp mit [==] und [hashCode] **über den Inhalt** der Map, weil eine
/// Liste davon Abhängigkeit eines Providers ist: Ohne Wertgleichheit wäre
/// jede neu gelesene Liste ungleich der vorigen und jeder abgeleitete Wert
/// liefe neu (`CLAUDE.md`, Fehler `03`). Darts `Map` vergleicht selbst nur
/// die Identität, das muss die Klasse tun.
///
/// Nicht `const`-fähig, und das liegt an [DateTime]: `DateTime.utc(…)` ist
/// kein konstanter Ausdruck.
class Umfangsmessung {
  Umfangsmessung({required this.zeitpunkt, required this.werte});

  /// UTC-Zeitpunkt, der einen Berliner Tag bezeichnet. Was aus
  /// [UmfangsMerge.messungen] kommt, trägt immer den **Tagesbeginn**.
  final DateTime zeitpunkt;

  /// Die gemessenen Maße. Wird als unveränderlich behandelt — wer sie
  /// weiterverarbeitet, kopiert.
  final Map<Umfang, double> werte;

  @override
  bool operator ==(Object other) =>
      other is Umfangsmessung &&
      other.zeitpunkt == zeitpunkt &&
      _werteGleich(other.werte, werte);

  @override
  int get hashCode => Object.hash(zeitpunkt, _werteHash(werte));

  @override
  String toString() => 'Umfangsmessung(zeitpunkt: $zeitpunkt, werte: $werte)';

  static bool _werteGleich(
    Map<Umfang, double> eine,
    Map<Umfang, double> andere,
  ) {
    if (eine.length != andere.length) return false;
    for (final eintrag in eine.entries) {
      final gegenueber = andere[eintrag.key];
      if (gegenueber == null || gegenueber != eintrag.value) return false;
    }
    return true;
  }

  /// Über die Maße in ihrer festen Reihenfolge, nicht über die der Map: Zwei
  /// inhaltsgleiche Messungen, verschieden herum eingetragen, müssen
  /// denselben Wert ergeben.
  static int _werteHash(Map<Umfang, double> werte) => Object.hashAll([
    for (final mass in Umfang.values)
      if (werte.containsKey(mass)) ...[mass, werte[mass]],
  ]);
}

abstract final class UmfangsMerge {
  /// Tagweise **und maßweise** zusammengeführt, aufsteigend nach Tag.
  ///
  /// Steht ein Maß in beiden Quellen, gilt der eingetippte Wert. Maßweise und
  /// nicht eintragsweise: Wer abends nur die Taille nachträgt, löscht damit
  /// nicht Hals und Brust vom Morgen.
  ///
  /// Entschieden wird nach der **Quelle**, nicht nach der Uhrzeit — der
  /// Import trägt die Uhrzeit des Exports, und die sagt nichts darüber, wann
  /// gemessen wurde.
  static List<Umfangsmessung> messungen({
    required List<Umfangsmessung> importiert,
    required List<Umfangsmessung> getippt,
  }) {
    // Je Tag eine **neue** Map. In die der Quelle hineinzuschreiben änderte
    // den Stand einer fremden Quelle, und das fiele erst beim zweiten Lesen
    // auf.
    final nachTag = <DateTime, Map<Umfang, double>>{};

    // Import zuerst, eingetippt danach: Die zweite Runde überschreibt je Maß.
    // Innerhalb einer Quelle gewinnt der spätere Eintrag — SPEC 4.6, „Eine
    // zweite Eingabe am selben Tag ändert die erste".
    for (final messung in [...importiert, ...getippt]) {
      final tag = BerlinCalendar.startOfDay(messung.zeitpunkt);
      (nachTag[tag] ??= <Umfang, double>{}).addAll(messung.werte);
    }

    final tage = nachTag.keys.toList()..sort();
    return [
      for (final tag in tage)
        // Ein Tag ohne Werte ist keine Messung und gehört in keine Liste. Ein
        // leerer Eintrag ist dabei kein Löschbefehl: Er fügt nichts hinzu und
        // nimmt nichts weg.
        if (nachTag[tag]!.isNotEmpty)
          Umfangsmessung(zeitpunkt: tag, werte: nachTag[tag]!),
    ];
  }
}
