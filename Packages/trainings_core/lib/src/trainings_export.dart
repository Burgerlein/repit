// Der Leser der Datei, die die eingefrorene Swift-App herausgibt
// (`AppExport`, Format `trainingsexport`, Fassung 2) — soweit sie
// **Gym-Trainings** (#59 Teil 1) und **Körpermaße** (#498) trägt. Spec:
// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte 2,
// 6 und 15; Format: `Packages/TrainingsCore/Sources/TrainingsCore/Export/
// AppExport.swift` und `Circumference.swift`; Tests:
// `test/trainings_export_test.dart` und
// `test/trainings_export_umfaenge_test.dart`.
//
// Eine reine Funktion über **bereits dekodiertes** JSON. `dart:convert`
// kennt der Kern nicht (`test/import_boundary_test.dart`); `jsonDecode` ruft
// die App. Der Leser **wirft nie**: Was an der Datei nicht stimmt, kommt als
// Wert zurück — als [ExportRejected], wenn die ganze Datei nicht taugt, als
// [ExportSessionSkip], wenn eine Sitzung nicht taugt und die übrigen
// gelesen werden.
//
// **Nichts wird erfunden:** keine Satz-Uhrzeit, kein Aufwärmen, kein
// Zeitstempel. Was die alte App nicht kennt, bleibt `null`. **Nichts wird
// still verworfen:** Alles, was nicht gelesen wird, steht mit dem Grund im
// Ergebnis.

import 'exercise.dart';
import 'exercise_library.dart';
import 'gym_session.dart';
import 'progression.dart';
import 'umfang.dart';
import 'umfangs_eingabe.dart';
import 'umfangs_merge.dart';

/// Ergebnis von [TrainingsExport.read]: abgelehnt oder gelesen.
sealed class ExportReading {
  const ExportReading();
}

/// Die ganze Datei taugt nicht — mit dem Grund.
final class ExportRejected extends ExportReading {
  const ExportRejected(this.reason);

  final ExportRejection reason;

  @override
  String toString() => 'ExportRejected($reason)';
}

/// Die Datei wurde gelesen. Einzelne Sitzungen können darin übersprungen
/// sein ([skipped]); sie stehen mit Position und Grund da.
final class ExportRead extends ExportReading {
  const ExportRead({
    required this.generated,
    required this.timezone,
    required this.sessions,
    required this.skipped,
    required this.unknownExerciseIds,
    required this.unknownWorkoutCodes,
    required this.circumferences,
    required this.skippedMeasures,
    required this.unknownMeasureKeys,
    required this.unread,
  });

  /// Wann die Datei erzeugt wurde, UTC.
  final DateTime generated;

  /// Die Zone, die die Datei nennt. Eine andere als `Europe/Berlin` lehnt
  /// die Datei nicht ab — die Zeitpunkte sind Zeitpunkte; der Berliner Tag
  /// wird aus ihnen gerechnet. Der Schirm weist darauf hin.
  final String timezone;

  /// Die gelesenen Sitzungen in der Reihenfolge der Datei.
  final List<ImportedSession> sessions;

  /// Die Sitzungen, die nicht taugten.
  final List<ExportSessionSkip> skipped;

  /// Übungs-IDs der gelesenen Sitzungen, die der Katalog nicht kennt —
  /// sortiert, ohne Dubletten. Die Sätze bleiben in der Sitzung.
  final List<String> unknownExerciseIds;

  /// Workout-Codes der gelesenen Sitzungen, die der Kern nicht kennt —
  /// sortiert, ohne Dubletten. Die Sitzung wird mit `workout == null`
  /// gelesen.
  final List<String> unknownWorkoutCodes;

  /// Die gelesenen Umfangsmessungen, **in der Reihenfolge der Datei**:
  /// erst `dashboardImport[].circumferences`, dann `app.circumferences`.
  /// Sortiert wird hier nicht — das tut [UmfangsImport.plan].
  ///
  /// Der `zeitpunkt` ist der Zeitpunkt der Datei, roh und in UTC; den
  /// Berliner Tag rechnet erst der Planer, genauso wie bei den Trainings.
  ///
  /// **Die Reihenfolge ist eine Entscheidung des Test-Agenten** (#498):
  /// Beim tagweisen Falten gewinnt der spätere Eintrag, und gewinnen muss
  /// das in der Altapp selbst Erfasste — `CircumferenceMerge.swift`
  /// entscheidet dort genauso. Stünde der Dashboard-Import hinten,
  /// überschriebe er still die eigene Messung desselben Tages.
  final List<Umfangsmessung> circumferences;

  /// Einzelwerte und ganze Einträge, die nicht gelesen wurden — mit Quelle,
  /// Position und Grund. **Nichts wird geraten.**
  final List<ExportMeasureSkip> skippedMeasures;

  /// Maß-Schlüssel der Datei, die [Umfang.vonSchluessel] nicht kennt —
  /// sortiert, ohne Dubletten. **Kein Lesefehler:** Die Altapp kennt
  /// dreizehn Maße, der Neubau fünfzehn, und eine spätere Fassung kann
  /// Schlüssel tragen, die es hier nicht gibt.
  final List<String> unknownMeasureKeys;

  /// Was in der Datei steht und dieser Schritt nicht liest, als Anzahl,
  /// nur wenn größer als null: `swaps`, `drafts`, `dataWindow` und
  /// `dashboardImport.sessions`.
  ///
  /// `circumferences` steht seit #498 **nicht** mehr darin: Ein Bericht,
  /// der Gelesenes als ungelesen meldet, ist falsch.
  final Map<String, int> unread;

  /// Jede Sitzung der Datei zählt genau einmal: gelesen plus übersprungen.
  int get entryCount => sessions.length + skipped.length;

  @override
  String toString() =>
      'ExportRead(${sessions.length} gelesen, ${skipped.length} '
      'übersprungen)';
}

/// Warum die ganze Datei abgelehnt wird.
sealed class ExportRejection {
  const ExportRejection();
}

/// Schon das Dekodieren scheiterte. Baut die App, nicht der Leser.
final class NotJson extends ExportRejection {
  const NotJson(this.detail);

  final String detail;

  @override
  String toString() => 'NotJson($detail)';
}

/// Das JSON ist kein Objekt.
final class NotAnObject extends ExportRejection {
  const NotAnObject();

  @override
  String toString() => 'NotAnObject';
}

/// `format` ist nicht `trainingsexport` — [found] ist, was stattdessen
/// dastand (`null`, wenn nichts oder keine Zeichenkette).
final class WrongFormat extends ExportRejection {
  const WrongFormat(this.found);

  final String? found;

  @override
  String toString() => 'WrongFormat($found)';
}

/// `version` ist nicht 2 — [found] ist, was dastand.
final class UnsupportedVersion extends ExportRejection {
  const UnsupportedVersion(this.found);

  final Object? found;

  @override
  String toString() => 'UnsupportedVersion($found)';
}

/// Ein Pflichtfeld fehlt oder hat die falsche Gestalt.
final class MalformedField extends ExportRejection {
  const MalformedField(this.field);

  final String field;

  @override
  String toString() => 'MalformedField($field)';
}

/// Warum eine einzelne Sitzung nicht gelesen wurde.
enum ExportSkipReason {
  /// Ein Feld fehlt oder hat den falschen Typ; `detail` nennt es.
  malformed,

  /// Ein Satz mit `reps ≤ 0`; `detail` ist die Übungs-ID.
  repsNotPositive,

  /// Dieselbe Übung zweimal in der Sitzung; `detail` ist die Übungs-ID.
  duplicateExercise,
}

/// Eine Sitzung der Datei, die nicht gelesen wurde.
final class ExportSessionSkip {
  const ExportSessionSkip({
    required this.index,
    required this.id,
    required this.reason,
    required this.detail,
  });

  /// Position in `app.sessions`, ab 0 — gezählt in der Datei, nicht unter
  /// den Gelesenen.
  final int index;

  /// Die Kennung, wo sie bekannt ist.
  final String? id;

  final ExportSkipReason reason;
  final String detail;

  @override
  String toString() =>
      'ExportSessionSkip(#$index, $id, ${reason.name}, '
      '$detail)';
}

/// Warum ein Umfangswert — oder ein ganzer Eintrag — nicht gelesen wurde.
enum ExportMeasureSkipReason {
  /// Der Eintrag taugt nicht; `detail` nennt das Feld.
  malformed,

  /// Der Wert ist keine Zahl.
  notANumber,

  /// Die Zahl liegt außerhalb von [UmfangsEingabe.minCm] bis
  /// [UmfangsEingabe.maxCm]. **`0` und negative Zahlen gehören dazu** — eine
  /// `0` ist kein gemessener Umfang, sondern `01` in neuer Verpackung.
  implausible,
}

/// Ein Umfangswert der Datei, der nicht gelesen wurde.
final class ExportMeasureSkip {
  const ExportMeasureSkip({
    required this.source,
    required this.index,
    required this.measure,
    required this.reason,
    required this.detail,
  });

  /// `app.circumferences` oder `dashboardImport.circumferences`.
  final String source;

  /// Position in der Liste **dieser Quelle**, ab 0.
  final int index;

  /// Der Rohschlüssel des Maßes; `null`, wenn der ganze Eintrag nicht taugt.
  final String? measure;

  final ExportMeasureSkipReason reason;

  /// Was dastand bzw. welches Feld fehlt — nie leer.
  final String detail;

  @override
  String toString() =>
      'ExportMeasureSkip($source#$index, $measure, ${reason.name}, $detail)';
}

abstract final class TrainingsExport {
  /// Der Formatname, wörtlich wie in `AppExport.swift`.
  static const String formatName = 'trainingsexport';

  /// Die einzige Fassung, die dieser Leser kennt. Fassung 1 trägt keine
  /// Gym-Trainings in einer Gestalt, die zu lesen nicht Raten hieße.
  static const int currentVersion = 2;

  /// Liest eine dekodierte Datei. **Wirft nie.**
  ///
  /// Geprüft wird in dieser Reihenfolge: Objekt, Format, Fassung,
  /// `generated`, `timezone`, `app`, `app.sessions`. Die Fassung steht vor
  /// dem Inhalt, damit sich Fassung 1 als `UnsupportedVersion(1)` meldet und
  /// nicht als „`app` fehlt".
  ///
  /// **Fehlend ist nicht leer:** `app.sessions: []` ist eine gültige Datei,
  /// ein fehlender Block eine kaputte.
  static ExportReading read(Object? decoded) {
    if (decoded is! Map) return const ExportRejected(NotAnObject());

    final format = decoded['format'];
    if (format != formatName) {
      return ExportRejected(WrongFormat(format is String ? format : null));
    }

    final version = decoded['version'];
    if (version is! int || version != currentVersion) {
      return ExportRejected(UnsupportedVersion(version));
    }

    final generated = zeitpunktAus(decoded['generated']);
    if (generated == null) {
      return const ExportRejected(MalformedField('generated'));
    }

    final timezone = decoded['timezone'];
    if (timezone is! String) {
      return const ExportRejected(MalformedField('timezone'));
    }

    final app = decoded['app'];
    if (app is! Map) return const ExportRejected(MalformedField('app'));

    final rohSitzungen = app['sessions'];
    if (rohSitzungen is! List) {
      return const ExportRejected(MalformedField('app.sessions'));
    }

    final sessions = <ImportedSession>[];
    final skipped = <ExportSessionSkip>[];
    final unbekannteUebungen = <String>{};
    final unbekannteWorkouts = <String>{};

    for (var i = 0; i < rohSitzungen.length; i++) {
      final ergebnis = _liesSitzung(i, rohSitzungen[i]);
      switch (ergebnis) {
        case _Gelesen(:final sitzung, :final unbekannteWorkoutCode):
          sessions.add(sitzung);
          if (unbekannteWorkoutCode != null) {
            unbekannteWorkouts.add(unbekannteWorkoutCode);
          }
          for (final uebung in sitzung.exercises) {
            if (!ExerciseLibrary.all.containsKey(uebung.exerciseId)) {
              unbekannteUebungen.add(uebung.exerciseId);
            }
          }
        case _Uebersprungen(:final skip):
          skipped.add(skip);
      }
    }

    final umfaenge = _UmfangsLese();
    // Der Dashboard-Import **zuerst**: Beim tagweisen Falten gewinnt der
    // spätere Eintrag, und gewinnen muss das in der Altapp selbst Erfasste.
    final dashboard = app['dashboardImport'];
    if (dashboard is List) {
      for (final eintrag in dashboard) {
        if (eintrag is! Map) continue;
        umfaenge.liesListe(
          eintrag['circumferences'],
          'dashboardImport.circumferences',
        );
      }
    }
    umfaenge.liesListe(app['circumferences'], 'app.circumferences');

    return ExportRead(
      generated: generated,
      timezone: timezone,
      sessions: sessions,
      skipped: skipped,
      unknownExerciseIds: unbekannteUebungen.toList()..sort(),
      unknownWorkoutCodes: unbekannteWorkouts.toList()..sort(),
      circumferences: umfaenge.messungen,
      skippedMeasures: umfaenge.skips,
      unknownMeasureKeys: umfaenge.unbekannteSchluessel.toList()..sort(),
      unread: _ungelesen(app),
    );
  }

  /// Zählt, was in der Datei steht und dieser Schritt nicht liest. Ein
  /// falsch geformter Stand kippt die Datei nicht und zählt nicht.
  static Map<String, int> _ungelesen(Map<Object?, Object?> app) {
    final out = <String, int>{};
    for (final schluessel in const [
      // `circumferences` steht hier seit #498 nicht mehr: Was gelesen wird,
      // ist nicht ungelesen.
      'swaps',
      'drafts',
      'dataWindow',
    ]) {
      final wert = app[schluessel];
      if (wert is List && wert.isNotEmpty) out[schluessel] = wert.length;
    }

    final dashboard = app['dashboardImport'];
    if (dashboard is List) {
      var summe = 0;
      for (final eintrag in dashboard) {
        if (eintrag is Map) {
          final sitzungen = eintrag['sessions'];
          if (sitzungen is List) summe += sitzungen.length;
        }
      }
      if (summe > 0) out['dashboardImport.sessions'] = summe;
    }
    return out;
  }

  static _SitzungsErgebnis _liesSitzung(int index, Object? roh) {
    _Uebersprungen kaputt(String? id, String feld) => _Uebersprungen(
      ExportSessionSkip(
        index: index,
        id: id,
        reason: ExportSkipReason.malformed,
        detail: feld,
      ),
    );

    if (roh is! Map) return kaputt(null, 'Eintrag ist kein Objekt');

    final rohId = roh['id'];
    final id = rohId is String && rohId.isNotEmpty ? rohId : null;
    if (id == null) return kaputt(null, 'id');

    final date = zeitpunktAus(roh['date']);
    if (date == null) return kaputt(id, 'date');

    final rohWorkout = roh['workout'];
    if (rohWorkout != null && rohWorkout is! String) {
      return kaputt(id, 'workout');
    }
    final workout = rohWorkout == null
        ? null
        : Workout.fromCode(rohWorkout as String);
    final unbekannterCode = rohWorkout != null && workout == null
        ? rohWorkout as String
        : null;

    final rohMinuten = roh['minutes'];
    int? minuten;
    if (rohMinuten != null) {
      minuten = _ganzeZahl(rohMinuten);
      if (minuten == null) return kaputt(id, 'minutes');
    }

    final rohNotiz = roh['note'];
    if (rohNotiz != null && rohNotiz is! String) return kaputt(id, 'note');
    final notiz = rohNotiz is String && rohNotiz.isNotEmpty ? rohNotiz : null;

    final rohUebungen = roh['exercises'];
    if (rohUebungen is! List) return kaputt(id, 'exercises');

    // Erst die Gestalt der ganzen Sitzung, dann die Inhalte: Eine Sitzung,
    // die schon in ihrer Form nicht taugt, meldet sich als `malformed`,
    // nicht als „Wiederholungen".
    final uebungen = <ImportedExercise>[];
    for (var u = 0; u < rohUebungen.length; u++) {
      final rohUebung = rohUebungen[u];
      if (rohUebung is! Map) return kaputt(id, 'exercises[$u]');
      final uebungId = rohUebung['exerciseID'];
      if (uebungId is! String || uebungId.isEmpty) {
        return kaputt(id, 'exercises[$u].exerciseID');
      }
      final rohSaetze = rohUebung['sets'];
      if (rohSaetze is! List) return kaputt(id, 'exercises[$u].sets');

      final saetze = <CompletedSet>[];
      for (var s = 0; s < rohSaetze.length; s++) {
        final rohSatz = rohSaetze[s];
        final ort = 'exercises[$u].sets[$s]';
        if (rohSatz is! Map) return kaputt(id, ort);
        final gewicht = rohSatz['weight'];
        if (gewicht is! num) return kaputt(id, '$ort.weight');
        final wdh = _ganzeZahl(rohSatz['reps']);
        if (wdh == null) return kaputt(id, '$ort.reps');
        saetze.add(CompletedSet(weight: gewicht.toDouble(), reps: wdh));
      }
      // Eine Übung ohne Sätze wird weggelassen: Die Ablage kennt keine, und
      // es geht nichts verloren, was je trainiert wurde.
      if (saetze.isEmpty) continue;
      uebungen.add(ImportedExercise(exerciseId: uebungId, sets: saetze));
    }

    // Was `legeAb` und `uebernimm` mit `ArgumentError` ablehnen, liefert der
    // Leser nicht durch — sonst kippte eine einzige Sitzung den ganzen Lauf.
    final gesehen = <String>{};
    for (final uebung in uebungen) {
      if (!gesehen.add(uebung.exerciseId)) {
        return _Uebersprungen(
          ExportSessionSkip(
            index: index,
            id: id,
            reason: ExportSkipReason.duplicateExercise,
            detail: uebung.exerciseId,
          ),
        );
      }
      for (final satz in uebung.sets) {
        if (satz.reps <= 0) {
          return _Uebersprungen(
            ExportSessionSkip(
              index: index,
              id: id,
              reason: ExportSkipReason.repsNotPositive,
              detail: uebung.exerciseId,
            ),
          );
        }
      }
    }

    return _Gelesen(
      ImportedSession(
        id: id,
        date: date,
        workout: workout,
        minutes: minuten,
        note: notiz,
        exercises: uebungen,
      ),
      unbekannterCode,
    );
  }

  /// Eine ganze Zahl — `10` und `10.0`, nicht `10.5`, nicht `"10"`.
  static int? _ganzeZahl(Object? wert) {
    if (wert is int) return wert;
    if (wert is double && wert.isFinite && wert == wert.truncateToDouble()) {
      return wert.toInt();
    }
    return null;
  }

  /// ISO-8601 **mit Zone**, als UTC-Zeitpunkt.
  ///
  /// Nicht privat, weil der Umfangsleser denselben Zeitpunktbegriff braucht:
  /// Zwei Fassungen davon hießen zwei Gelegenheiten, eine Zone zu raten.
  ///
  /// Ein Zeitpunkt ohne Zone wird nicht geraten: `DateTime.parse` läse ihn
  /// als Ortszeit des Geräts, und der Berliner Tag hinge an der Einstellung
  /// des Telefons.
  static DateTime? zeitpunktAus(Object? wert) {
    if (wert is! String) return null;
    if (!_mitZone.hasMatch(wert)) return null;
    return DateTime.tryParse(wert)?.toUtc();
  }

  static final RegExp _mitZone = RegExp(
    r'^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?'
    r'([Zz]|[+-]\d{2}(:?\d{2})?)$',
  );
}

sealed class _SitzungsErgebnis {
  const _SitzungsErgebnis();
}

final class _Gelesen extends _SitzungsErgebnis {
  const _Gelesen(this.sitzung, this.unbekannteWorkoutCode);

  final ImportedSession sitzung;
  final String? unbekannteWorkoutCode;
}

final class _Uebersprungen extends _SitzungsErgebnis {
  const _Uebersprungen(this.skip);

  final ExportSessionSkip skip;
}

/// Sammelt beim Lesen der Umfangsblöcke. Eine Klasse und keine fünf
/// durchgereichten Listen: Jede Quelle schreibt in dieselben drei Töpfe,
/// und die Reihenfolge der Quellen entscheidet.
///
/// **Wirft nie** — auch nicht für einen tief verschachtelten Unsinn.
final class _UmfangsLese {
  final List<Umfangsmessung> messungen = [];
  final List<ExportMeasureSkip> skips = [];
  final Set<String> unbekannteSchluessel = {};

  /// Liest eine der beiden Listen. Ein falsch geformter Block kippt die
  /// Datei nicht und zählt auch nicht als Lesefehler — da war nichts, was
  /// sich übersprungen nennen ließe.
  void liesListe(Object? roh, String quelle) {
    if (roh is! List) return;
    for (var i = 0; i < roh.length; i++) {
      _liesEintrag(roh[i], quelle, i);
    }
  }

  void _liesEintrag(Object? roh, String quelle, int index) {
    void kaputt(String feld) => skips.add(
      ExportMeasureSkip(
        source: quelle,
        index: index,
        measure: null,
        reason: ExportMeasureSkipReason.malformed,
        detail: feld,
      ),
    );

    if (roh is! Map) return kaputt('Eintrag ist kein Objekt');

    final zeitpunkt = TrainingsExport.zeitpunktAus(roh['date']);
    if (zeitpunkt == null) return kaputt('date');

    final rohWerte = roh['values'];
    if (rohWerte is! Map) return kaputt('values');

    final werte = <Umfang, double>{};
    for (final eintrag in rohWerte.entries) {
      final schluessel = eintrag.key;
      if (schluessel is! String) continue;

      final mass = Umfang.vonSchluessel(schluessel);
      if (mass == null) {
        // Kein Lesefehler: gezählt und benannt, nicht als Fehler gemeldet.
        unbekannteSchluessel.add(schluessel);
        continue;
      }

      void uebersprungen(ExportMeasureSkipReason grund, String detail) =>
          skips.add(
            ExportMeasureSkip(
              source: quelle,
              index: index,
              measure: schluessel,
              reason: grund,
              detail: detail,
            ),
          );

      final wert = eintrag.value;
      if (wert is! num || !wert.toDouble().isFinite) {
        uebersprungen(ExportMeasureSkipReason.notANumber, '$wert');
        continue;
      }

      // Gegen die Konstanten des Formulars, nicht gegen Literale — sonst
      // liefen Import und Eingabe auseinander.
      final zentimeter = wert.toDouble();
      if (zentimeter < UmfangsEingabe.minCm ||
          zentimeter > UmfangsEingabe.maxCm) {
        uebersprungen(ExportMeasureSkipReason.implausible, '$zentimeter');
        continue;
      }

      werte[mass] = zentimeter;
    }

    // Eine Messung ohne lesbares Maß ist keine Messung. Leere `values` sind
    // dabei kein Fehler — da war nichts einzutragen.
    if (werte.isEmpty) return;
    messungen.add(Umfangsmessung(zeitpunkt: zeitpunkt, werte: werte));
  }
}
