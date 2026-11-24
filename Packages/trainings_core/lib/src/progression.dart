// Double Progression, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Progression.swift` (#91).

import 'dart:math' as math;

import 'exercise.dart';

/// Ein ausgeführter Satz: Gewicht und Wiederholungen.
///
/// Werttyp mit [==] und [hashCode] (`CLAUDE.md`, Fehler `03`): Sätze hängen
/// als Abhängigkeit an abgeleiteten Werten, und ohne inhaltlichen Vergleich
/// liefe jede Ableitung bei jedem Neubau neu.
final class CompletedSet {
  const CompletedSet({
    required this.weight,
    required this.reps,
    this.recordedAt,
  });

  /// Kilogramm. **Negativ bedeutet Unterstützung:** −27 sind 27 kg Hilfe von
  /// der Maschine, nicht ein negatives Gewicht. Der schwerere Satz ist
  /// deshalb der, der näher an null liegt.
  final double weight;

  /// Wiederholungen — bei Zeitübungen ([Exercise.isTimed]) Sekunden.
  final int reps;

  /// Wann der Satz **eingetragen** wurde, nicht wann gehoben wurde (#78,
  /// Spec 11.4). Eine spätere Korrektur verschiebt ihn nicht; ein Satz, der
  /// geleert und neu gefüllt wird, ist ein neuer Satz und bekommt einen
  /// neuen Zeitpunkt. Beides ist Verhalten der Erfassung — **der Kern
  /// erfindet keinen Zeitpunkt und überschreibt keinen.**
  ///
  /// `null` heißt „nicht erfasst", und das ist der **Hauptfall**: Die
  /// Übernahme aus der alten App (#59) bringt Tims gesamten bisherigen
  /// Verlauf, und dort gibt es keine Satzzeiten. Ein erfundener Zeitstempel
  /// behauptete, der Satz sei zu dieser Minute entstanden.
  ///
  /// Wie überall im Paket ein UTC-Zeitpunkt, der eine Berliner Wanduhrzeit
  /// bezeichnet. [==] vergleicht streng, ohne vorher umzurechnen: Eine
  /// Ortszeit ist hier kein anderer Anstrich desselben Moments, sondern ein
  /// Wert, den `BerlinCalendar` falsch liest — dass sie ungleich bleibt, ist
  /// das Signal für ein vergessenes `.toUtc()` (#427).
  final DateTime? recordedAt;

  @override
  bool operator ==(Object other) =>
      other is CompletedSet &&
      other.weight == weight &&
      other.reps == reps &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(weight, reps, recordedAt);

  @override
  String toString() => recordedAt == null
      ? 'CompletedSet($weight, $reps)'
      : 'CompletedSet($weight, $reps, $recordedAt)';
}

/// Was beim nächsten Mal ansteht.
///
/// Der Vorschlag trägt **nur Zahlen**. Wie daraus ein Satz wird, entscheidet
/// die Ansicht — im Kern stehen keine Nutzertexte.
///
/// Swifts `enum Suggestion` mit assoziierten Werten wird in Dart eine
/// sealed class: Der `switch` über sie muss vollständig sein, und käme ein
/// siebter Fall dazu, meldet der Analyzer jede Stelle, die ihn nicht
/// behandelt.
///
/// **Zwei verschiedene Fälle mit denselben Zahlen sind nie gleich.** „Halten
/// bei 52,5" und „Reduzieren auf 52,5" sind verschiedene Auskünfte; ein
/// gemeinsames [==] auf der Oberklasse würde sie verwechseln.
sealed class Suggestion {
  const Suggestion();
}

/// Noch kein Verlauf: Es gibt kein Gewicht vorzuschlagen, nur das Ziel.
final class FirstTime extends Suggestion {
  const FirstTime({required this.targetReps});

  /// Die untere Grenze des Wiederholungsbereichs.
  final int targetReps;

  @override
  bool operator ==(Object other) =>
      other is FirstTime && other.targetReps == targetReps;

  @override
  int get hashCode => Object.hash(FirstTime, targetReps);

  @override
  String toString() => 'FirstTime(targetReps: $targetReps)';
}

/// Steigern: Alle Sätze lagen an der oberen Grenze.
///
/// Bei Unterstützung heißt steigern **weniger** Hilfe — [toWeight] liegt
/// dann näher an null als das zuletzt benutzte Gewicht.
final class Increase extends Suggestion {
  const Increase({
    required this.toWeight,
    required this.by,
    required this.targetReps,
  });

  final double toWeight;

  /// Die Schrittweite der Übung, nicht eine feste Zahl.
  final double by;

  /// Nach der Steigerung beginnt der Bereich wieder unten.
  final int targetReps;

  @override
  bool operator ==(Object other) =>
      other is Increase &&
      other.toWeight == toWeight &&
      other.by == by &&
      other.targetReps == targetReps;

  @override
  int get hashCode => Object.hash(Increase, toWeight, by, targetReps);

  @override
  String toString() =>
      'Increase(toWeight: $toWeight, by: $by, targetReps: $targetReps)';
}

/// Halten: dasselbe Gewicht, eine Wiederholung mehr anstreben.
final class Hold extends Suggestion {
  const Hold({required this.atWeight, required this.targetReps});

  final double atWeight;

  /// Der schwächste Satz am Höchstgewicht plus eins, gedeckelt auf die
  /// obere Grenze.
  final int targetReps;

  @override
  bool operator ==(Object other) =>
      other is Hold &&
      other.atWeight == atWeight &&
      other.targetReps == targetReps;

  @override
  int get hashCode => Object.hash(Hold, atWeight, targetReps);

  @override
  String toString() => 'Hold(atWeight: $atWeight, targetReps: $targetReps)';
}

/// Reduzieren: zweimal hintereinander unter der unteren Grenze.
///
/// Bei Unterstützung heißt leichter **mehr** Hilfe, der Betrag von
/// [toWeight] wächst also gegenüber [fromWeight].
final class Deload extends Suggestion {
  const Deload({
    required this.toWeight,
    required this.fromWeight,
    required this.targetReps,
  });

  final double toWeight;
  final double fromWeight;
  final int targetReps;

  @override
  bool operator ==(Object other) =>
      other is Deload &&
      other.toWeight == toWeight &&
      other.fromWeight == fromWeight &&
      other.targetReps == targetReps;

  @override
  int get hashCode => Object.hash(Deload, toWeight, fromWeight, targetReps);

  @override
  String toString() =>
      'Deload(toWeight: $toWeight, fromWeight: $fromWeight, '
      'targetReps: $targetReps)';
}

/// Zeitübung: länger halten.
final class IncreaseTime extends Suggestion {
  const IncreaseTime({required this.toSeconds});

  /// Gedeckelt auf die obere Grenze der Übung.
  final int toSeconds;

  @override
  bool operator ==(Object other) =>
      other is IncreaseTime && other.toSeconds == toSeconds;

  @override
  int get hashCode => Object.hash(IncreaseTime, toSeconds);

  @override
  String toString() => 'IncreaseTime(toSeconds: $toSeconds)';
}

/// Zeitübung an der Obergrenze: Länger halten bringt nichts mehr, es
/// braucht eine schwerere Variante. Trägt keine Zahlen.
final class HarderVariant extends Suggestion {
  const HarderVariant();

  @override
  bool operator ==(Object other) => other is HarderVariant;

  @override
  int get hashCode => Object.hash(HarderVariant, 0);

  @override
  String toString() => 'HarderVariant()';
}

/// Die Steigerungslogik aus `docs/SPEC.md` 4.4 („Double Progression").
///
/// Entschieden wird **aus dem letzten Training**; die Sitzung davor zählt
/// nur mit, um einen zweiten Einbruch in Folge zu erkennen.
abstract final class Progression {
  /// Der Vorschlag für die nächste Einheit von [exercise].
  ///
  /// [history] sind die Sitzungen, **neueste zuerst**. Sätze mit null oder
  /// weniger Wiederholungen gelten als nicht ausgeführt und werden
  /// verworfen; bleibt von einer Sitzung nichts übrig, ist sie kein
  /// Trainingstag und verdeckt ihren Vorgänger nicht.
  static Suggestion suggest(
    Exercise exercise,
    List<List<CompletedSet>> history,
  ) {
    final sessions = <List<CompletedSet>>[];
    for (final session in history) {
      final ausgefuehrt = [
        for (final satz in session)
          if (satz.reps > 0) satz,
      ];
      if (ausgefuehrt.isNotEmpty) sessions.add(ausgefuehrt);
    }

    if (sessions.isEmpty) {
      return exercise.isTimed
          ? IncreaseTime(toSeconds: exercise.repLow)
          : FirstTime(targetReps: exercise.repLow);
    }
    final last = sessions.first;

    if (exercise.isTimed) {
      // Gerechnet wird mit dem **kürzesten** Satz: Er trägt das nächste
      // Ziel. Das Gewichtsfeld bleibt unangetastet — bei einer Zeitübung
      // steht dort nichts Sinnvolles.
      final shortest = last.map((s) => s.reps).reduce(math.min);
      if (shortest >= exercise.repHigh) return const HarderVariant();
      final next = math.min(
        shortest + exercise.increment.toInt(),
        exercise.repHigh,
      );
      return IncreaseTime(toSeconds: next);
    }

    // Der schwerste Satz. Bei Unterstützung ist der näher an null, und
    // genau das leistet das Maximum auch für negative Werte: −24,5 > −27.
    final top = last.map((s) => s.weight).reduce(math.max);
    final atTop = [
      for (final satz in last)
        if (satz.weight == top) satz,
    ];

    if (last.every((s) => s.reps >= exercise.repHigh)) {
      return Increase(
        toWeight: top + exercise.increment,
        by: exercise.increment,
        targetReps: exercise.repLow,
      );
    }

    final vorige = sessions.length > 1 ? sessions[1] : null;
    if (atTop.any((s) => s.reps < exercise.repLow) &&
        _belowLow(vorige, exercise)) {
      return Deload(
        toWeight: _deloadWeight(from: top, increment: exercise.increment),
        fromWeight: top,
        targetReps: exercise.repLow,
      );
    }

    // Halten und eine Wiederholung mehr anstreben, gedeckelt auf die
    // obere Grenze.
    final weakest = atTop.map((s) => s.reps).reduce(math.min);
    return Hold(
      atWeight: top,
      targetReps: math.min(weakest + 1, exercise.repHigh),
    );
  }

  /// Ob [session] an **ihrem eigenen** Höchstgewicht unter der unteren
  /// Grenze blieb. Ein schwacher Aufbausatz am leichteren Gewicht ist kein
  /// Einbruch.
  static bool _belowLow(List<CompletedSet>? session, Exercise exercise) {
    if (session == null || session.isEmpty) return false;
    final top = session.map((s) => s.weight).reduce(math.max);
    return session.any((s) => s.weight == top && s.reps < exercise.repLow);
  }

  /// Zehn Prozent leichter, gerundet auf die Schrittweite.
  ///
  /// Bei Unterstützung heißt leichter **mehr** Hilfe, der Betrag wächst
  /// also — deshalb dort 1,1 statt 0,9. `docs/SPEC.md` Z. 147 nennt nur
  /// „90 %" und meint den positiven Fall; Z. 149 („Bei Unterstützung
  /// bedeutet steigern: weniger Unterstützung") trägt die Richtung. 0,9 auf
  /// einen negativen Wert anzuwenden würde die Übung schwerer machen —
  /// genau falsch herum.
  static double _deloadWeight({
    required double from,
    required double increment,
  }) {
    final factor = from >= 0 ? 0.9 : 1.1;
    return _roundTo(from * factor, increment);
  }

  /// Auf ein Vielfaches von [increment] runden, damit das Gewicht an der
  /// Hantel einstellbar ist. Gerundet wird zur nächsten Stufe, bei genau
  /// einer halben von null weg — wie Swifts `rounded()`.
  static double _roundTo(double value, double increment) {
    if (increment <= 0) return value;
    return (value / increment).roundToDouble() * increment;
  }
}
