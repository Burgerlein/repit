// Der Planer einer Übernahme aus der alten App (#59 Teil 1, mit #482):
// **die eine Stelle, an der entschieden wird, was eine Übernahme schreiben
// darf.** Spec: `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
// Abschnitte 3 und 4; Tests: `test/gym_session_import_test.dart`.
//
// `GymRepository.legeAb` ersetzt eine Sitzung, wenn Tag und Workout gleich
// sind, und fragt nicht, woher die vorhandene stammt. Beim Nachtragen eines
// eigenen Trainings ist das richtig, bei einer Übernahme wäre es Datenverlust
// ohne Meldung — das Gerät ist Tims einzige Kopie, und ein im Neubau
// eingetragenes Training trägt Satz-Uhrzeiten und Aufwärmen, die die alte
// App gar nicht kennt. Der Planer legt deshalb fest: **Eine Übernahme
// schreibt nur dazu. Was schon da ist, bleibt**, gleich ob selbst
// eingetragen oder früher übernommen.

import 'gym_session.dart';
import 'gym_session_merge.dart';

/// Warum eine Sitzung der Datei nicht geschrieben wird.
enum GymImportSkipReason {
  /// Die Kennung steht schon in der Ablage. Der Inhalt wird weder
  /// verglichen noch nachgezogen: Ohne Herkunftsangabe ließe sich nicht
  /// sagen, ob die Zeile seit der Übernahme von Hand geändert wurde.
  alreadyPresent,

  /// Ein anderes Training steht schon an diesem Berliner Tag mit diesem
  /// Workout. **Der Name behauptet kein „eigen"** — die Ablage weiß nicht,
  /// ob es selbst eingetragen oder früher übernommen wurde.
  dayAndWorkoutTaken,

  /// In der Datei selbst steht dasselbe Training mehrfach; eine andere
  /// Fassung davon wird geschrieben.
  duplicateInFile,
}

/// Eine Sitzung der Datei, die **nicht** geschrieben wird — samt der
/// Sitzung selbst, damit der Schirm Tag und Workout nennen kann.
final class GymImportSkip {
  const GymImportSkip({required this.session, required this.reason});

  final ImportedSession session;
  final GymImportSkipReason reason;

  @override
  bool operator ==(Object other) =>
      other is GymImportSkip &&
      other.session == session &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(session, reason);

  @override
  String toString() => 'GymImportSkip(${session.id}, ${reason.name})';
}

/// Was der Planer entschieden hat: Jede eingehende Sitzung steht genau
/// einmal in [toWrite] **oder** in [skipped].
final class GymImportPlan {
  const GymImportPlan({required this.toWrite, required this.skipped});

  /// Die Sitzungen, die geschrieben werden dürfen, in der Reihenfolge der
  /// Datei und unverändert.
  final List<ImportedSession> toWrite;

  /// Alle übrigen, in der Reihenfolge der Datei.
  final List<GymImportSkip> skipped;

  @override
  String toString() =>
      'GymImportPlan(${toWrite.length} schreiben, ${skipped.length} '
      'überspringen)';
}

abstract final class GymSessionImport {
  /// Plant eine Übernahme. Geprüft wird in dieser Reihenfolge:
  ///
  /// 1. Die Kennung steht in [existing] → `alreadyPresent`.
  /// 2. Berliner Tag und Workout sind durch [existing] belegt →
  ///    `dayAndWorkoutTaken` — **auch** wenn die Übernahme der neuere
  ///    Zeitpunkt wäre.
  /// 3. Unter den Übrigen teilen sich mehrere Kennung oder Tag und Workout →
  ///    es gewinnt der spätere `date`, bei Gleichstand die größere Kennung,
  ///    bei völliger Gleichheit die erste Fundstelle; die anderen sind
  ///    `duplicateInFile`.
  /// 4. Sonst wird geschrieben.
  ///
  /// Der Schlüssel in 2 und 3 ist derselbe wie in [GymSessionMerge.merge]
  /// ([GymSessionMerge.sessionKey]); der Konsistenztest bindet beide
  /// aneinander. **Die Reihenfolge der Datei ändert das Ergebnis nicht:**
  /// Fall 3 bildet Gruppen über gemeinsame Kennungen und Schlüssel, statt
  /// Paare in Dateireihenfolge zu vergleichen.
  static GymImportPlan plan({
    required List<ImportedSession> existing,
    required List<ImportedSession> incoming,
  }) {
    final vorhandeneIds = {for (final s in existing) s.id};
    final belegt = {for (final s in existing) GymSessionMerge.sessionKey(s)};

    final grund = <int, GymImportSkipReason>{};
    final kandidaten = <int>[];
    for (var i = 0; i < incoming.length; i++) {
      final s = incoming[i];
      if (vorhandeneIds.contains(s.id)) {
        grund[i] = GymImportSkipReason.alreadyPresent;
      } else if (belegt.contains(GymSessionMerge.sessionKey(s))) {
        grund[i] = GymImportSkipReason.dayAndWorkoutTaken;
      } else {
        kandidaten.add(i);
      }
    }

    // Gruppen: zwei Kandidaten gehören zusammen, wenn sie Kennung oder
    // Schlüssel teilen — und was über eine Kette zusammenhängt, auch.
    final gruppe = <int, int>{for (final i in kandidaten) i: i};
    int wurzel(int i) {
      var r = i;
      while (gruppe[r] != r) {
        r = gruppe[r]!;
      }
      return r;
    }

    void verbinde(int a, int b) {
      final ra = wurzel(a);
      final rb = wurzel(b);
      if (ra == rb) return;
      // Die kleinere Position wird Wurzel; das Ergebnis hängt nicht an der
      // Reihenfolge, in der verbunden wird.
      if (ra < rb) {
        gruppe[rb] = ra;
      } else {
        gruppe[ra] = rb;
      }
    }

    final jeId = <String, int>{};
    final jeSchluessel = <String, int>{};
    for (final i in kandidaten) {
      final s = incoming[i];
      final nachId = jeId[s.id];
      if (nachId == null) {
        jeId[s.id] = i;
      } else {
        verbinde(nachId, i);
      }
      final schluessel = GymSessionMerge.sessionKey(s);
      final nachSchluessel = jeSchluessel[schluessel];
      if (nachSchluessel == null) {
        jeSchluessel[schluessel] = i;
      } else {
        verbinde(nachSchluessel, i);
      }
    }

    final sieger = <int, int>{};
    for (final i in kandidaten) {
      final w = wurzel(i);
      final bisher = sieger[w];
      if (bisher == null || _schlaegt(incoming[i], incoming[bisher])) {
        sieger[w] = i;
      }
    }
    final gewinner = sieger.values.toSet();
    for (final i in kandidaten) {
      if (!gewinner.contains(i)) {
        grund[i] = GymImportSkipReason.duplicateInFile;
      }
    }

    return GymImportPlan(
      toWrite: [
        for (var i = 0; i < incoming.length; i++)
          if (!grund.containsKey(i)) incoming[i],
      ],
      skipped: [
        for (var i = 0; i < incoming.length; i++)
          if (grund[i] != null)
            GymImportSkip(session: incoming[i], reason: grund[i]!),
      ],
    );
  }

  /// `true`, wenn [neu] [alt] aussticht: der spätere Zeitpunkt, bei
  /// Gleichstand die größere Kennung. Bei völliger Gleichheit `false` — die
  /// erste Fundstelle bleibt.
  static bool _schlaegt(ImportedSession neu, ImportedSession alt) {
    final nachZeit = neu.date.compareTo(alt.date);
    if (nachZeit != 0) return nachZeit > 0;
    return neu.id.compareTo(alt.id) > 0;
  }
}
