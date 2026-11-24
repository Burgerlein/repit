// Der Planer einer Umfänge-Übernahme aus der alten App (#498, unter #59 und
// #88): **die eine Stelle, an der entschieden wird, welche übernommenen
// Umfänge geschrieben werden dürfen.** Spec:
// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte
// 3, 4 und 15; Tests: `test/umfangs_import_test.dart`.
//
// Das Gegenstück zu `GymSessionImport.plan`, nur eine Ebene feiner: Dort ist
// die Sitzung die Einheit, hier der **einzelne Wert**. Eine Messung trägt
// nur die Maße, die an dem Tag wirklich gemessen wurden; zwei Quellen können
// denselben Tag mit verschiedenen Maßen füllen, und keine darf die andere
// wegnehmen.
//
// Es gilt dieselbe Regel wie bei den Trainings, **maßweise**: Die Übernahme
// schreibt nur dazu. Was schon dasteht, bleibt — auch dann, wenn die Datei
// für dasselbe Maß desselben Tages eine andere Zahl trägt. Ohne diese Regel
// zöge ein zweiter Lauf einer alten Datei korrigierte Werte wieder zurück.

import 'berlin_calendar.dart';
import 'umfang.dart';
import 'umfangs_merge.dart';

/// Was der Planer entschieden hat. Beide Listen sind **tagweise gefaltet**
/// und stehen **aufsteigend nach Berliner Tag**; der `zeitpunkt` ist der
/// Berliner Tagesbeginn, genau wie bei [UmfangsMerge.messungen].
///
/// Die Ablage kennt nur den Tag, nicht die Uhrzeit — eine Uhrzeit im Plan
/// behauptete eine Genauigkeit, die danach niemand mehr hat.
final class UmfangsImportPlan {
  const UmfangsImportPlan({
    required this.toWrite,
    required this.alreadyPresent,
  });

  /// Je Tag **nur die neuen Maße**. Ein Tag ohne neue Maße steht nicht
  /// darin, auch nicht leer.
  final List<Umfangsmessung> toWrite;

  /// Je Tag die Maße, die als Import schon dastanden — mit dem Wert aus der
  /// Datei, damit der Bericht sagen kann, was er nicht geschrieben hat.
  final List<Umfangsmessung> alreadyPresent;

  @override
  String toString() =>
      'UmfangsImportPlan(${toWrite.length} schreiben, '
      '${alreadyPresent.length} schon da)';
}

abstract final class UmfangsImport {
  /// Plant eine Übernahme von Umfängen.
  ///
  /// [existing] sind die Zeilen der Quelle `import`, **nicht** die
  /// getippten: Ein von Hand eingetragener Wert steht in der Ablage daneben
  /// und gewinnt erst beim Lesen ([UmfangsMerge]); er hindert die Übernahme
  /// nicht daran, ihre eigene Zeile zu schreiben. Sonst verschwände der
  /// importierte Wert für immer.
  ///
  /// Innerhalb von [incoming] gewinnt je Maß der **spätere** Eintrag der
  /// Liste — dieselbe Regel, nach der [UmfangsMerge.messungen] faltet. Die
  /// Reihenfolge legt der Leser fest, nicht die Uhrzeit.
  ///
  /// Eine reine Funktion: In die übergebenen Messungen wird nie
  /// hineingeschrieben.
  static UmfangsImportPlan plan({
    required List<Umfangsmessung> existing,
    required List<Umfangsmessung> incoming,
  }) {
    // Vom Vorhandenen zählt nur, **welche** Maße dastehen — der Wert nicht:
    // Eine Korrektur in der alten Datei darf den Stand nicht zurückziehen.
    final vorhanden = <DateTime, Set<Umfang>>{};
    for (final messung in existing) {
      final tag = BerlinCalendar.startOfDay(messung.zeitpunkt);
      (vorhanden[tag] ??= <Umfang>{}).addAll(messung.werte.keys);
    }

    // Je Tag eine **neue** Map; in die der Quelle zu schreiben änderte den
    // Stand eines fremden Aufrufers.
    final gefaltet = <DateTime, Map<Umfang, double>>{};
    for (final messung in incoming) {
      final tag = BerlinCalendar.startOfDay(messung.zeitpunkt);
      (gefaltet[tag] ??= <Umfang, double>{}).addAll(messung.werte);
    }

    final neu = <Umfangsmessung>[];
    final schon = <Umfangsmessung>[];
    for (final tag in gefaltet.keys.toList()..sort()) {
      final werte = gefaltet[tag]!;
      final schonDa = vorhanden[tag] ?? const <Umfang>{};

      final neueWerte = <Umfang, double>{};
      final alteWerte = <Umfang, double>{};
      for (final eintrag in werte.entries) {
        (schonDa.contains(eintrag.key) ? alteWerte : neueWerte)[eintrag.key] =
            eintrag.value;
      }

      if (neueWerte.isNotEmpty) {
        neu.add(Umfangsmessung(zeitpunkt: tag, werte: neueWerte));
      }
      if (alteWerte.isNotEmpty) {
        schon.add(Umfangsmessung(zeitpunkt: tag, werte: alteWerte));
      }
    }

    return UmfangsImportPlan(toWrite: neu, alreadyPresent: schon);
  }
}
