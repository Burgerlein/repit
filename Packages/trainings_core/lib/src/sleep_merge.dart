// Korrektur oder Ergänzung: Wie eine von Hand eingetragene Nacht zur
// gemessenen steht, und was aus den Eingaben des Score wird, wenn sie
// dazukommt (#192).
//
// Der Vertrag und seine Begründungen stehen im Kopf von
// `test/sleep_merge_test.dart`; diese Datei setzt ihn um und erfindet
// nichts dazu.
import 'dart:math';

import 'sleep_scoring.dart';

/// Ob ein eingetragener Schlaf die gemessene Nacht **korrigiert** oder zu
/// ihr **dazukommt** — und was dann aus Dauer, Zubettgehzeit und
/// Unterbrechungen wird.
///
/// **Warum es die Unterscheidung gibt.** Die Regel aus #131 lautete „Ein
/// Tag mit beidem: Der Eintrag gewinnt, und zwar ganz". Ihre Begründung
/// trägt für eine **Korrektur**: Eine aus gemessener Dauer und
/// eingetippter Einschlafzeit zusammengesetzte Nacht hätte es so nie
/// gegeben, und niemand könnte hinterher sagen, welche Zahl woher kommt.
/// Für eine **Ergänzung** ist sie falsch — Schlaf von 19:00 bis 21:30
/// korrigiert die Nacht nicht, er kommt dazu. Dass die App es nicht
/// unterscheiden konnte, lag an der Tagesgrenze: Nächte laufen von 18:00
/// bis 18:00, also fällt 19:00 in „die Nacht dieses Tages".
///
/// Alle Uhrzeiten zählen **Minuten seit 18:00** ([EveningClock]) — die
/// Skala, auf der eine Nacht durchgehend vorwärts läuft. Ein Zeitpunkt
/// käme hier nicht durch: Der Eintrag trägt eine Wanduhrzeit, keinen
/// Moment.
abstract final class SleepMerge {
  /// Ab so vielen Minuten Überschneidung gilt ein Eintrag als Korrektur.
  ///
  /// **Fünf Minuten, und die Entscheidung ist meine — Tim hat die Zahl
  /// nicht gesehen.** Er hat „addieren, wenn es sich nicht überlappt"
  /// entschieden; wo „überlappt" anfängt, stand noch offen. Es ist
  /// dieselbe Schwelle wie `kleinsteMessluecke` im Hypnogramm (#156) und
  /// dieselbe Haltung dahinter:
  ///
  /// 1. Ein getipptes Fenster ist minutengenau und aus der Erinnerung, ein
  ///    gemessenes sekundengenau von der Uhr. Was sich davon an den
  ///    Rändern berührt, sind Abtast- und Rundungsgrenzen — **nicht** die
  ///    Aussage, dass beide denselben Schlaf meinen. Jede solche Berührung
  ///    als Korrektur zu lesen hieße, aus einer Rundung eine Entscheidung
  ///    zu machen.
  /// 2. Die Richtung des Irrtums ist in beide Seiten teuer, aber
  ///    verschieden: Darunter zu ersetzen wirft eine ganze gemessene Nacht
  ///    für eine Berührung weg — genau der Fehler, gegen den #192
  ///    geschrieben ist. Darüber zu addieren zählt einmal geschlafene
  ///    Minuten zweimal. Die Schwelle muss also klein sein, aber nicht
  ///    null.
  /// 3. Fünf Minuten sind auf diesem Schirm schon begründet und belegt.
  ///    Zwei verschiedene Zahlen für „ein paar Minuten zählen nicht"
  ///    müsste man an zwei Stellen erklären und würden irgendwann
  ///    auseinanderlaufen.
  static const double minimumOverlapMinutes = 5;

  /// Ob der Eintrag die gemessene Nacht **korrigiert** (`true`) und damit
  /// ersetzt, oder zu ihr **dazukommt** (`false`).
  ///
  /// Drei Lagen gelten als Korrektur, weil sich der Eintrag gar nicht auf
  /// die Uhr legen lässt und die Lesart aus #131 dann die einzig ehrliche
  /// ist:
  ///
  /// - **Ohne Uhrzeiten** (Formularfassung „nur Dauer"). Eine Dauer sagt
  ///   nicht, wann sie lag; sie irgendwo hinzusetzen wäre eine erfundene
  ///   Uhrzeit.
  /// - **Mit einem Fenster, das nicht vorwärts läuft** ([entryEnd] nicht
  ///   nach [entryStart]). Es bezeichnet keine Strecke.
  /// - **Ohne gemessene Nacht** — oder mit einem gemessenen Fenster, das
  ///   nicht vorwärts läuft. Im ersten Fall gibt es nichts zu ergänzen,
  ///   der Eintrag ist die Nacht; im zweiten lässt sich nicht sagen,
  ///   wogegen zu prüfen wäre. Die Abendskala kann eine Nacht, die über
  ///   den Mittag hinausläuft, nicht ausdrücken (siehe
  ///   [EveningClock.wrapHour]) — dann lieber bei der engeren Lesart aus
  ///   #131 bleiben als Minuten doppelt zu zählen.
  static bool corrects({
    required double? entryStart,
    required double? entryEnd,
    required double? measuredStart,
    required double? measuredEnd,
  }) {
    if (entryStart == null || entryEnd == null) return true;
    if (entryEnd <= entryStart) return true;
    if (measuredStart == null || measuredEnd == null) return true;
    if (measuredEnd <= measuredStart) return true;

    final overlap = min(entryEnd, measuredEnd) - max(entryStart, measuredStart);
    return overlap >= minimumOverlapMinutes;
  }

  /// Die Eingaben des Score für eine Nacht aus **zwei** Strecken — einer
  /// gemessenen mit Phasen und einer eingetragenen ohne.
  ///
  /// Drei Entscheidungen stecken darin, und jede erfindet ausdrücklich
  /// nichts:
  ///
  /// - **Die Dauer zählt zusammen.** Beide Strecken sind eine Aussage über
  ///   geschlafene Minuten, und zwei solche Aussagen addieren sich — so
  ///   wie der Tagschlaf es längst tut („Die Summe oben zählt beide
  ///   Phasen").
  /// - **Die Zubettgehzeit ist die der längeren Strecke**, bei gleicher
  ///   Länge die frühere; eine Strecke ohne Uhrzeit ist dabei nie die
  ///   frühere. Die Teilnote fragt, wann die Nacht begann — von zwei
  ///   Strecken ist die lange die Nacht und die kurze das, was dazukam.
  ///   **Hat die gewählte Strecke keine Uhrzeit, entfällt die Teilnote**
  ///   (`null`), statt auf die andere auszuweichen: Das behauptete einen
  ///   Nachtbeginn, den niemand kennt.
  /// - **Die Unterbrechungen kommen unverändert aus der gemessenen
  ///   Strecke.** Der Eintrag zählt keine Wachphasen; aus ihm welche
  ///   abzuleiten wäre eine Zahl ohne Messung. Die gemessenen dagegen sind
  ///   gemessen — sie wegzuwerfen, nur weil daneben etwas eingetragen
  ///   wurde, wäre derselbe Fehler mit umgekehrtem Vorzeichen. Dass sie
  ///   nur den gemessenen Teil der Nacht beschreiben, sagt der Schirm.
  static ({
    double asleepMinutes,
    double? bedtimeMinutes,
    double awakeMinutes,
    int wakeCount,
  })
  combined({
    required double measuredAsleepMinutes,
    required double? measuredBedtimeMinutes,
    required double measuredAwakeMinutes,
    required int measuredWakeCount,
    required double entryAsleepMinutes,
    required double? entryBedtimeMinutes,
  }) {
    final bool entrySetsBedtime;
    if (entryAsleepMinutes > measuredAsleepMinutes) {
      entrySetsBedtime = true;
    } else if (entryAsleepMinutes < measuredAsleepMinutes) {
      entrySetsBedtime = false;
    } else if (measuredBedtimeMinutes == null) {
      // Gleich lang: die frühere zählt — und eine Strecke ohne Uhrzeit
      // ist nie die frühere.
      entrySetsBedtime = entryBedtimeMinutes != null;
    } else {
      entrySetsBedtime =
          entryBedtimeMinutes != null &&
          entryBedtimeMinutes < measuredBedtimeMinutes;
    }

    return (
      asleepMinutes: measuredAsleepMinutes + entryAsleepMinutes,
      bedtimeMinutes: entrySetsBedtime
          ? entryBedtimeMinutes
          : measuredBedtimeMinutes,
      awakeMinutes: measuredAwakeMinutes,
      wakeCount: measuredWakeCount,
    );
  }
}
