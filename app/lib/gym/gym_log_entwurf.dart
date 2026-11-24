// Das laufende Training als Werttyp (#78): welches Workout, die
// eingetippten Sätze je Übung, der Unterstützungs-Schalter je Übung, das
// Aufwärmen, Datum, Dauer und Notiz — und die Umwandlung von und zur
// Ablage (`GymEntwurf`).
//
// **Schmierzettel, kein Datensatz** (Spec 10.2): Was hier steht, ist
// Formularzustand. „62,", „abc" und ein halb getippter Wert sind gültige
// Inhalte dieses Typs; ob etwas ein Satz ist, entscheidet allein der Kern
// (`GymSessionBuilder`). Die Regel steht dort und wird hier **nicht noch
// einmal geschrieben** — [GymLogEntwurf.satzZaehlt] fragt den Builder,
// statt `int.tryParse` nachzubauen. Damit zählen Fortschritt, Bilanz und
// Ablage nach derselben Regel (Spec 3.8).
//
// **Werttypen mit [==] und [hashCode] über alle Felder** (`CLAUDE.md`,
// Fehler `03`): Der Entwurf ist die Abhängigkeit, an der jeder abgeleitete
// Wert des Schirms hängt. Darts [==] auf [List] ist Identität; die
// Vergleiche stehen deshalb von Hand da.
//
// **Keine Nutzertexte.** Beschriftungen stehen in `gym_log_texte.dart`.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart' show GymEntwurf;

/// Die Satzzeilen einer Übung und ihr Unterstützungs-Schalter.
///
/// Die Sätze sind der Kern-Typ [RawSet]: roher Text plus der Zeitpunkt, an
/// dem der Satz vollständig wurde (Spec 11.4). Es gibt **immer mindestens
/// eine Zeile** — eine Übung ohne Zeile hätte kein Feld, in das man tippen
/// könnte (Spec 3.5).
@immutable
class GymLogUebung {
  const GymLogUebung({
    required this.id,
    required this.saetze,
    required this.unterstuetzt,
  });

  /// Die [Exercise.id] aus dem Katalog.
  final String id;

  /// Die Zeilen in der Reihenfolge, in der sie auf dem Schirm stehen.
  final List<RawSet> saetze;

  /// „Unterstützung" statt „Zusatzgewicht". Eingetippt wird die Zahl von
  /// der Maschine, positiv; **negativ wird erst beim Ablegen** (Spec 8.1,
  /// `GymSessionBuilder`).
  final bool unterstuetzt;

  /// Ob die Zeile sich entfernen lässt (Spec 3.5): **nicht die letzte** der
  /// Übung, und **nur, solange sie leer ist** — wer einen gefüllten Satz
  /// loswerden will, leert ihn erst. Leer heißt: kein Wiederholungstext.
  bool zeileEntfernbar(int index) =>
      index >= 0 &&
      index < saetze.length &&
      saetze.length > 1 &&
      saetze[index].reps.trim().isEmpty;

  GymLogUebung copyWith({List<RawSet>? saetze, bool? unterstuetzt}) =>
      GymLogUebung(
        id: id,
        saetze: saetze ?? this.saetze,
        unterstuetzt: unterstuetzt ?? this.unterstuetzt,
      );

  @override
  bool operator ==(Object other) =>
      other is GymLogUebung &&
      other.id == id &&
      other.unterstuetzt == unterstuetzt &&
      _gleicheSaetze(other.saetze, saetze);

  @override
  int get hashCode => Object.hash(id, unterstuetzt, Object.hashAll(saetze));

  @override
  String toString() =>
      'GymLogUebung($id, ${saetze.length} Zeilen'
      '${unterstuetzt ? ', unterstützt' : ''})';
}

/// Das Aufwärmen im Formular (#40) — **drei Zustände**, nicht zwei:
/// nichts eingetragen, übersprungen, ausgefüllt.
///
/// „Übersprungen" ist eine Antwort und kein leeres Feld (Tim, 10.11.2026);
/// [uebersprungen] ist deshalb ein eigenes Feld und nicht aus den anderen
/// ableitbar. Ist es gesetzt, gelten die übrigen Felder nicht — sie bleiben
/// stehen, damit „doch nicht überspringen" die Eingabe zurückbringt.
///
/// **Formularzustand:** [minuten] und [km] sind roher Text. Erst
/// [alsWarmUp] macht daraus den Kern-Typ.
@immutable
class GymLogAufwaermen {
  const GymLogAufwaermen({
    this.art,
    this.minuten = '',
    this.km = '',
    this.uebersprungen = false,
  });

  /// Nichts eingetragen, nichts übersprungen.
  static const nichts = GymLogAufwaermen();

  /// Übersprungen.
  static const ausgelassen = GymLogAufwaermen(uebersprungen: true);

  final WarmUpKind? art;
  final String minuten;
  final String km;
  final bool uebersprungen;

  /// `true`, wenn das Aufwärmen nichts enthält — weder eine Antwort noch
  /// eine Eingabe.
  bool get leer =>
      !uebersprungen &&
      art == null &&
      minuten.trim().isEmpty &&
      km.trim().isEmpty;

  /// Der Kern-Typ dazu, `null` für „nichts eingetragen".
  ///
  /// - [uebersprungen] → [WarmUpSkipped].
  /// - Eine **Art und lesbare Minuten über null** → [WarmUpDone]. Eine
  ///   halbe Eingabe (Art ohne Minuten, Minuten ohne Art) wird **nicht
  ///   geraten**, sondern bleibt `null` — dasselbe Verhalten wie ein Satz
  ///   ohne lesbare Wiederholungen.
  /// - Die Strecke ist echt nullbar: Leer oder unlesbar oder nicht über
  ///   null ergibt `null`, nie `0` (`CLAUDE.md`: „`0` ist keine Antwort
  ///   auf ‚kein Wert‘"). Komma und Punkt werden beide gelesen.
  WarmUp? get alsWarmUp {
    if (uebersprungen) return const WarmUpSkipped();
    final art = this.art;
    if (art == null) return null;
    final min = int.tryParse(minuten.trim());
    if (min == null || min <= 0) return null;
    final text = km.trim().replaceAll(',', '.');
    final gelesen = text.isEmpty ? null : double.tryParse(text);
    // Bei Mobility gibt es keine Strecke. Wer erst eine Strecke tippt und
    // dann die Art wechselt, legt keine ab — sie bleibt im Feld stehen, damit
    // der Weg zurück sie wiederbringt.
    final strecke =
        (art != WarmUpKind.mobility &&
            gelesen != null &&
            gelesen.isFinite &&
            gelesen > 0)
        ? gelesen
        : null;
    return WarmUpDone(kind: art, minutes: min, km: strecke);
  }

  /// [art] lässt sich mit `null` zurücksetzen — daher kein `??` auf dem
  /// Feld, sondern ein eigener Schalter.
  GymLogAufwaermen copyWith({
    WarmUpKind? art,
    bool artLoeschen = false,
    String? minuten,
    String? km,
    bool? uebersprungen,
  }) => GymLogAufwaermen(
    art: artLoeschen ? null : (art ?? this.art),
    minuten: minuten ?? this.minuten,
    km: km ?? this.km,
    uebersprungen: uebersprungen ?? this.uebersprungen,
  );

  @override
  bool operator ==(Object other) =>
      other is GymLogAufwaermen &&
      other.art == art &&
      other.minuten == minuten &&
      other.km == km &&
      other.uebersprungen == uebersprungen;

  @override
  int get hashCode => Object.hash(art, minuten, km, uebersprungen);

  @override
  String toString() => uebersprungen
      ? 'GymLogAufwaermen(übersprungen)'
      : 'GymLogAufwaermen(${art?.code}, "$minuten" min, "$km" km)';
}

/// Die Satzbilanz — „6 Sätze · 2.410 kg Volumen".
///
/// **Aus dem Entwurf gewonnen, indem er durch [GymSessionBuilder.session]
/// geschickt und das Ergebnis gefragt wird** (Spec 3.8): [saetze] ist
/// `ImportedSession.setCount`, [volumeKg] `ImportedSession.volumeKg`. Eine
/// Rechnung, eine Zahl — ein vertippter Satz steht weder hier noch
/// hinterher in der Ablage.
@immutable
class GymBilanz {
  const GymBilanz({required this.saetze, required this.volumeKg});

  /// Nichts gezählt. **Kein verbotener Nullwert** (Spec 14): Es ist die
  /// richtige Antwort auf „wie viel habe ich heute gehoben" — solange der
  /// Entwurf gelesen ist. Wer ihn noch nicht gelesen hat, zeigt das nicht.
  static const keine = GymBilanz(saetze: 0, volumeKg: 0);

  final int saetze;
  final double volumeKg;

  @override
  bool operator ==(Object other) =>
      other is GymBilanz &&
      other.saetze == saetze &&
      other.volumeKg == volumeKg;

  @override
  int get hashCode => Object.hash(saetze, volumeKg);

  @override
  String toString() => 'GymBilanz($saetze Sätze, $volumeKg kg)';
}

/// Das laufende Training.
@immutable
class GymLogEntwurf {
  const GymLogEntwurf({
    this.workout,
    this.trainingId,
    required this.sitzungId,
    required this.datum,
    required this.dauer,
    required this.notiz,
    required this.uebungen,
    required this.aufwaermen,
  }) : assert(
         workout != null || trainingId != null,
         'Ein Training hat einen Enum-Fall oder eine Kennung',
       );

  /// Ein frisches Training des Enum-Falls [workout]: die Definition aus
  /// `WorkoutTemplates.fromEnum` (die Netz-Fassung für Gym A–D und jedes
  /// Enum-Training ohne Zeile). Wer eine gespeicherte Definition hat,
  /// nimmt [GymLogEntwurf.ausDefinition].
  factory GymLogEntwurf.neu({
    required Workout workout,
    required String sitzungId,
    required DateTime jetzt,
  }) => GymLogEntwurf.ausDefinition(
    definition: WorkoutTemplates.fromEnum(workout),
    workout: workout,
    sitzungId: sitzungId,
    jetzt: jetzt,
  );

  /// Ein frisches Training aus seiner [definition] (Spec 15.2): die Übungen
  /// **in ihrer Reihenfolge** und je Übung so viele leere Zeilen, wie
  /// [WorkoutExercise.sets] **des Trainings** sagt (nicht die des Katalogs),
  /// die Dauer vorbelegt mit `WorkoutDuration.effective` (Spec 3.3, 15.2),
  /// Unterstützung nach [Exercise.allowsAssist].
  ///
  /// [workout] ist der Enum-Fall, wo es einen gibt; ohne ihn trägt der
  /// Entwurf die Kennung der Definition ([trainingId]).
  ///
  /// **Das Gewicht wird nicht vorbelegt.** Platzhalter sind die Werte vom
  /// letzten Mal, kein Inhalt (Spec 3.4, Abweichung 3) — die Swift-Fassung
  /// belegte es mit dem Vorschlag vor, die neue tut es bewusst nicht.
  ///
  /// Eine Übung, die der Katalog nicht (mehr) kennt, bekommt keine Zeilen:
  /// Sie hätte weder Muskeln noch Bereich, und ein Satz auf ihr ließe sich
  /// nicht ablegen (`GymSessionBuilder`).
  factory GymLogEntwurf.ausDefinition({
    required WorkoutDefinition definition,
    Workout? workout,
    required String sitzungId,
    required DateTime jetzt,
  }) => GymLogEntwurf(
    workout: workout,
    trainingId: workout == null ? definition.id : null,
    sitzungId: sitzungId,
    datum: jetzt.toUtc(),
    dauer: _vorgabeDauer(definition),
    notiz: '',
    uebungen: _frischeUebungen(definition.exercises),
    aufwaermen: GymLogAufwaermen.nichts,
  );

  /// Der Enum-Fall, `null` bei einem Training ohne.
  final Workout? workout;

  /// Die Kennung eines Trainings **ohne** Enum-Fall (Spec 4.7), sonst `null`.
  final String? trainingId;

  /// Die gespeicherte Kennung: `Workout.code` oder die UUID.
  String get kennung => trainingId ?? workout!.code;

  /// Die UUID der künftigen Sitzung (#418 Punkt 1). Sie steht ab dem
  /// ersten Zwischenstand fest und überlebt Neustarts.
  final String sitzungId;

  /// Das eingestellte Datum **samt Uhrzeit**, UTC. Die Uhrzeit bleibt, wenn
  /// der Datumswähler den Tag verstellt — zwei Trainings an einem Tag sollen
  /// sich unterscheiden lassen (`ImportedSession.date`).
  final DateTime datum;

  /// Die getippte Dauer in Minuten, roher Text.
  final String dauer;

  final String notiz;

  /// Die Übungen in der Reihenfolge des Trainings.
  final List<GymLogUebung> uebungen;

  final GymLogAufwaermen aufwaermen;

  /// Die Übung mit dieser ID, `null` wenn sie nicht zum Workout gehört.
  GymLogUebung? uebung(String id) {
    for (final u in uebungen) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Wie viele Zeilen es auf dem Schirm gibt — der Nenner des Fortschritts.
  /// Er wächst mit „+ Satz" und schrumpft mit dem Minus.
  int get gesamtSaetze =>
      uebungen.fold<int>(0, (summe, u) => summe + u.saetze.length);

  /// Ob etwas **eingetragen** wurde: eine Wiederholungszahl in irgendeiner
  /// Zeile oder eine Antwort beim Aufwärmen. Das fragt die Rückfrage vor
  /// „Training abbrechen" (Spec 3.6) — der Fall „aus Versehen gestartet"
  /// soll nicht nachfragen müssen.
  ///
  /// Das Gewicht allein zählt nicht: Ein angehängter Satz erbt das Gewicht
  /// des letzten, und niemand hat dort etwas eingetragen.
  bool get hatEintraege =>
      !aufwaermen.leer ||
      uebungen.any((u) => u.saetze.any((s) => s.reps.trim().isNotEmpty));

  /// Ob das Training **frisch** ist: kein Satz mit Wiederholungen und das
  /// Aufwärmen weder ausgefüllt noch übersprungen. Dann geht das Vollbild auf
  /// der Aufwärm-Seite auf, sonst bei der ersten offenen Übung.
  ///
  /// Eine halbe Eingabe beim Aufwärmen (Art ohne Minuten) ist **keine
  /// Antwort** ([GymLogAufwaermen.alsWarmUp] ist dann `null`) — das Training
  /// gilt weiter als frisch, denn das Aufwärmen steht noch offen.
  bool get frisch =>
      aufwaermen.alsWarmUp == null &&
      !uebungen.any((u) => u.saetze.any((s) => s.reps.trim().isNotEmpty));

  /// Ob es etwas zu **schreiben** gibt. Ein leerer Entwurf wird gelöscht,
  /// nicht geschrieben (Spec 9.1 Punkt 4): Sonst sähe die Gym-Übersicht ein
  /// angefangenes Training, wo keines ist.
  bool get hatInhalt => hatEintraege || notiz.trim().isNotEmpty;

  /// Der Index der ersten Übung, die noch nicht steht — dort geht das
  /// Vollbild auf und dort steht die Pausenuhr (Spec 4.3, 7.1). Stehen alle,
  /// ist es `0`, wie in Swift (`firstUnfinishedIndex`).
  ///
  /// Eine Übung **steht**, wenn jede ihrer Zeilen zählt.
  int get ersteOffeneUebung {
    for (var i = 0; i < uebungen.length; i++) {
      if (!uebungErledigt(uebungen[i])) return i;
    }
    return 0;
  }

  /// Ob alle Zeilen der Übung zählen — dann ist sie erledigt und darf
  /// zuklappen (Spec 3.4). Eine Übung ohne Zeile gibt es nicht.
  static bool uebungErledigt(GymLogUebung uebung) =>
      uebung.saetze.isNotEmpty &&
      uebung.saetze.every(
        (s) => satzZaehlt(
          s,
          uebungId: uebung.id,
          unterstuetzt: uebung.unterstuetzt,
        ),
      );

  /// Ob ein Satz zählt — **gefragt, nicht gerechnet.** Der Satz geht
  /// allein durch den Builder; kommt etwas heraus, zählt er. Die Regel
  /// (lesbare Wiederholungen über null, leeres Gewicht heißt null Kilo,
  /// unlesbares Gewicht lässt den Satz fallen) steht in
  /// `GymSessionBuilder` und nirgends sonst.
  ///
  /// [unterstuetzt] ändert das Ergebnis nicht (nur das Vorzeichen), steht
  /// hier trotzdem, damit der Aufruf dieselbe Form hat wie die Ablage.
  static bool satzZaehlt(
    RawSet satz, {
    required String uebungId,
    required bool unterstuetzt,
  }) =>
      GymSessionBuilder.session(
        id: '',
        // Wird vom Ergebnis nicht gelesen; die Frage betrifft allein den
        // Satz.
        date: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        workout: Workout.a,
        entries: {
          uebungId: [satz],
        },
        assist: {uebungId: unterstuetzt},
      ) !=
      null;

  /// Die Bilanz aus den Übungen — siehe [GymBilanz]. Statisch und nur von
  /// den Übungen abhängig, damit ein Provider sie über `select` auf
  /// [uebungen] halten kann, ohne bei Notiz, Dauer oder Datum neu zu
  /// rechnen.
  static GymBilanz bilanzVon(List<GymLogUebung> uebungen) {
    final sitzung = _alsSitzung(
      workout: Workout.a,
      uebungen: uebungen,
      id: '',
      date: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      minuten: null,
      notiz: null,
      aufwaermen: null,
    );
    return sitzung == null
        ? GymBilanz.keine
        : GymBilanz(saetze: sitzung.setCount, volumeKg: sitzung.volumeKg);
  }

  /// Die Übungen, wie sie **abgelegt** würden: Ein leeres Gewichtsfeld heißt
  /// „wie letztes Mal" (Tim, 10.11.2026) und trägt dort den Wert vom
  /// letzten Mal ein, wo [letzte] einen kennt — siehe
  /// [gymUebernommenesGewicht].
  ///
  /// [letzte] ist je Übung die Satzliste der jüngsten Sitzung. Der
  /// Zwischenstand bleibt davon unberührt: Im Entwurf bleibt das Feld leer
  /// und der Platzhalter grau.
  static List<GymLogUebung> uebernommen(
    List<GymLogUebung> uebungen,
    Map<String, List<CompletedSet>> letzte,
  ) {
    return [
      for (final u in uebungen)
        () {
          final uebung = ExerciseLibrary.byId(u.id);
          final vorher = letzte[u.id] ?? const <CompletedSet>[];
          if (uebung == null || uebung.isTimed || vorher.isEmpty) return u;
          return u.copyWith(
            saetze: [
              for (var i = 0; i < u.saetze.length; i++)
                () {
                  final satz = u.saetze[i];
                  final gewicht = gymUebernommenesGewicht(
                    satz.weight,
                    i < vorher.length ? vorher[i] : null,
                    zeit: false,
                  );
                  return gewicht == null
                      ? satz
                      : RawSet(
                          weight: gewicht,
                          reps: satz.reps,
                          recordedAt: satz.recordedAt,
                        );
                }(),
            ],
          );
        }(),
    ];
  }

  /// Ein frisches Training mit dem **zuletzt benutzten Unterstützungsmodus**
  /// je Übung (`SPEC.md:135`, Spec 13.3) — [AssistMode.lastUsed]. Ohne
  /// Verlauf gilt der Vorgabewert, also ändert sich nichts.
  GymLogEntwurf mitLetztemModus(Map<String, List<List<CompletedSet>>> verlauf) {
    var neu = this;
    for (final u in uebungen) {
      final uebung = ExerciseLibrary.byId(u.id);
      if (uebung == null || !uebung.allowsAssist) continue;
      neu = neu.mitUnterstuetzung(
        u.id,
        an: AssistMode.lastUsed(
          uebung,
          verlauf[u.id] ?? const <List<CompletedSet>>[],
        ),
      );
    }
    return neu;
  }

  /// Die fertige Sitzung, `null` wenn kein einziger Satz zählt.
  ///
  /// Die Dauer ist `null`, wenn sie nicht lesbar oder nicht über null ist:
  /// „nicht erfasst" ist nicht „null Minuten" (`ImportedSession.minutes`).
  ///
  /// [trainingName] ist der Name des Trainings **zu diesem Zeitpunkt**, den
  /// die Sitzung einfriert (Spec 4.6). Nur beim Abschließen gesetzt; wer
  /// bloß fragt, ob etwas zählt, lässt ihn weg.
  ///
  /// Bei einem Training **ohne Enum-Fall** geht seine Kennung als
  /// `trainingId` hinein, und die Übungen stehen in der Reihenfolge des
  /// Trainings (`trainingOrder`, Spec 25 Nr. 1), nicht alphabetisch.
  ImportedSession? alsSitzung({String? trainingName}) => _alsSitzung(
    workout: workout,
    trainingId: trainingId,
    uebungen: uebungen,
    id: sitzungId,
    date: datum,
    minuten: _minuten(dauer),
    notiz: notiz,
    aufwaermen: aufwaermen.alsWarmUp,
    trainingName: trainingName,
  );

  // --- Änderungen ----------------------------------------------------------

  /// Setzt Gewicht und/oder Wiederholungen einer Zeile. `null` lässt das
  /// Feld, wie es ist. Gibt `this` zurück, wenn nichts zu ändern ist.
  ///
  /// **Der Satzzeitpunkt** (Spec 11.4): Wird die Zeile durch diese Eingabe
  /// vollständig, bekommt sie [jetzt]. Eine spätere Korrektur verschiebt
  /// ihn nicht. Wird sie wieder leer, fällt er weg — ein geleerter und neu
  /// gefüllter Satz ist ein neuer Satz. „Vollständig" heißt: der Satz
  /// **zählt** ([satzZaehlt]) — Tim, 10.11.2026: sobald Wiederholungen
  /// dastehen, das Gewicht ist nicht nötig.
  GymLogEntwurf mitSatz(
    String uebungId,
    int index, {
    String? gewicht,
    String? wdh,
    required DateTime jetzt,
  }) {
    final u = uebung(uebungId);
    if (u == null || index < 0 || index >= u.saetze.length) return this;
    final alt = u.saetze[index];
    final war = satzZaehlt(
      alt,
      uebungId: uebungId,
      unterstuetzt: u.unterstuetzt,
    );
    var neu = RawSet(
      weight: gewicht ?? alt.weight,
      reps: wdh ?? alt.reps,
      recordedAt: alt.recordedAt,
    );
    final ist = satzZaehlt(
      neu,
      uebungId: uebungId,
      unterstuetzt: u.unterstuetzt,
    );
    if (!ist) {
      neu = RawSet(weight: neu.weight, reps: neu.reps);
    } else if (!war) {
      neu = RawSet(
        weight: neu.weight,
        reps: neu.reps,
        recordedAt: jetzt.toUtc(),
      );
    }
    if (neu == alt) return this;
    final saetze = [...u.saetze]..[index] = neu;
    return _mitUebung(u.copyWith(saetze: saetze));
  }

  /// Hängt eine Zeile an, die das **Gewicht der letzten erbt** — man tippt
  /// sonst bei jedem Zusatzsatz dieselbe Zahl noch einmal (Spec 3.4). Die
  /// Wiederholungen bleiben leer, der Zeitpunkt auch.
  GymLogEntwurf mitSatzAngehaengt(String uebungId) {
    final u = uebung(uebungId);
    if (u == null) return this;
    final letzter = u.saetze.isEmpty ? null : u.saetze.last;
    return _mitUebung(
      u.copyWith(
        saetze: [
          ...u.saetze,
          RawSet(weight: letzter?.weight ?? '', reps: ''),
        ],
      ),
    );
  }

  /// Ob die Zeile sich entfernen lässt — siehe
  /// [GymLogUebung.zeileEntfernbar].
  bool satzEntfernbar(String uebungId, int index) =>
      uebung(uebungId)?.zeileEntfernbar(index) ?? false;

  /// Entfernt die Zeile, wenn [satzEntfernbar]; sonst `this`.
  GymLogEntwurf ohneSatz(String uebungId, int index) {
    if (!satzEntfernbar(uebungId, index)) return this;
    final u = uebung(uebungId)!;
    return _mitUebung(u.copyWith(saetze: [...u.saetze]..removeAt(index)));
  }

  GymLogEntwurf mitUnterstuetzung(String uebungId, {required bool an}) {
    final u = uebung(uebungId);
    if (u == null || u.unterstuetzt == an) return this;
    return _mitUebung(u.copyWith(unterstuetzt: an));
  }

  GymLogEntwurf copyWith({
    DateTime? datum,
    String? dauer,
    String? notiz,
    GymLogAufwaermen? aufwaermen,
  }) => GymLogEntwurf(
    workout: workout,
    trainingId: trainingId,
    sitzungId: sitzungId,
    datum: datum ?? this.datum,
    dauer: dauer ?? this.dauer,
    notiz: notiz ?? this.notiz,
    uebungen: uebungen,
    aufwaermen: aufwaermen ?? this.aufwaermen,
  );

  /// Dasselbe Training mit anderen Zeilen — für [uebernommen], das nur die
  /// Rechnung vor dem Ablegen ist und nie in den Zwischenstand gelangt.
  GymLogEntwurf copyWithUebungen(List<GymLogUebung> uebungen) => GymLogEntwurf(
    workout: workout,
    trainingId: trainingId,
    sitzungId: sitzungId,
    datum: datum,
    dauer: dauer,
    notiz: notiz,
    uebungen: uebungen,
    aufwaermen: aufwaermen,
  );

  GymLogEntwurf _mitUebung(GymLogUebung neu) => GymLogEntwurf(
    workout: workout,
    trainingId: trainingId,
    sitzungId: sitzungId,
    datum: datum,
    dauer: dauer,
    notiz: notiz,
    uebungen: [for (final u in uebungen) u.id == neu.id ? neu : u],
    aufwaermen: aufwaermen,
  );

  // --- Ablage --------------------------------------------------------------

  /// Die Form für `GymRepository.speichereEntwurf`.
  ///
  /// [dauer] und [felder] tragen **rohen Text**; eine leere Notiz wird
  /// `null` (nie die leere Zeichenkette), eine geleerte Dauer bleibt dagegen
  /// leer stehen — sonst käme sie beim nächsten Öffnen als „70" zurück, und
  /// wer sie bewusst geleert hat, sähe seinen Eingriff verschwinden.
  GymEntwurf alsAblage({required DateTime gespeichertAm}) => GymEntwurf(
    workout: workout,
    trainingId: trainingId,
    sitzungId: sitzungId,
    zeitpunkt: datum,
    dauer: dauer,
    notiz: notiz.isEmpty ? null : notiz,
    gespeichertAm: gespeichertAm,
    felder: jsonEncode({
      'version': 1,
      'uebungen': [
        for (final u in uebungen)
          {
            'id': u.id,
            'unterstuetzt': u.unterstuetzt,
            'saetze': [
              for (final s in u.saetze)
                {
                  'g': s.weight,
                  'w': s.reps,
                  't': s.recordedAt?.toUtc().toIso8601String(),
                },
            ],
          },
      ],
      'aufwaermen': {
        'art': aufwaermen.art?.code,
        'min': aufwaermen.minuten,
        'km': aufwaermen.km,
        'uebersprungen': aufwaermen.uebersprungen,
      },
    }),
  );

  /// Der Entwurf aus der Ablage, `null` wenn er sich nicht lesen lässt.
  ///
  /// **Die Übungen kommen aus der [definition], die Eingaben aus der
  /// Ablage.** Was die Ablage zu einer Übung nicht kennt, bekommt frische
  /// Zeilen; was sie zu einer Übung führt, die das Training nicht (mehr) hat,
  /// entfällt. Ohne [definition] gilt bei einem Enum-Fall die Netz-Fassung
  /// (`WorkoutTemplates.fromEnum`); bei einem Training **ohne** Enum-Fall,
  /// das es nicht mehr gibt, stehen die Übungen so da, wie die Ablage sie
  /// führt — der Entwurf wird nie unsichtbar, nur weil sein Training fehlt
  /// (Spec 4.7). Ein unlesbarer Klumpen ergibt `null` — der Aufrufer
  /// **sagt das**, statt still leer zu starten (Spec 10.2).
  static GymLogEntwurf? ausAblage(
    GymEntwurf ablage, {
    WorkoutDefinition? definition,
  }) {
    final workout = ablage.workout;
    try {
      final wurzel = jsonDecode(ablage.felder);
      if (wurzel is! Map<String, dynamic>) return null;
      final gespeichert = <String, Map<String, dynamic>>{};
      for (final eintrag in (wurzel['uebungen'] as List? ?? const [])) {
        final karte = eintrag as Map<String, dynamic>;
        gespeichert[karte['id'] as String] = karte;
      }

      final WorkoutDefinition? massgeblich =
          definition ??
          (workout == null ? null : WorkoutTemplates.fromEnum(workout));
      final uebungen = <GymLogUebung>[];
      if (massgeblich != null) {
        for (final geplant in massgeblich.exercises) {
          final uebung = ExerciseLibrary.byId(geplant.exerciseId);
          if (uebung == null) continue;
          final karte = gespeichert[uebung.id];
          final saetze = <RawSet>[
            for (final s in (karte?['saetze'] as List? ?? const []))
              _satzAus(s as Map<String, dynamic>),
          ];
          if (karte == null || saetze.isEmpty) {
            uebungen.add(_frischeUebung(geplant, uebung));
          } else {
            uebungen.add(
              GymLogUebung(
                id: uebung.id,
                saetze: saetze,
                unterstuetzt:
                    karte['unterstuetzt'] as bool? ?? uebung.allowsAssist,
              ),
            );
          }
        }
      } else {
        // Das Training gibt es nicht mehr: Die Ablage ist die einzige
        // Auskunft, in der Reihenfolge, in der sie geschrieben wurde.
        for (final karte in gespeichert.values) {
          final uebung = ExerciseLibrary.byId(karte['id'] as String);
          if (uebung == null) continue;
          final saetze = <RawSet>[
            for (final s in (karte['saetze'] as List? ?? const []))
              _satzAus(s as Map<String, dynamic>),
          ];
          uebungen.add(
            GymLogUebung(
              id: uebung.id,
              saetze: saetze.isEmpty
                  ? [const RawSet(weight: '', reps: '')]
                  : saetze,
              unterstuetzt:
                  karte['unterstuetzt'] as bool? ?? uebung.allowsAssist,
            ),
          );
        }
      }

      final warm = wurzel['aufwaermen'] as Map<String, dynamic>?;
      final artCode = warm?['art'] as String?;
      final art = artCode == null ? null : WarmUpKind.fromCode(artCode);
      if (artCode != null && art == null) return null;

      return GymLogEntwurf(
        workout: workout,
        trainingId: ablage.trainingId,
        sitzungId: ablage.sitzungId,
        datum: ablage.zeitpunkt.toUtc(),
        dauer:
            ablage.dauer ??
            (massgeblich == null ? '' : _vorgabeDauer(massgeblich)),
        notiz: ablage.notiz ?? '',
        uebungen: uebungen,
        aufwaermen: warm == null
            ? GymLogAufwaermen.nichts
            : GymLogAufwaermen(
                art: art,
                minuten: warm['min'] as String? ?? '',
                km: warm['km'] as String? ?? '',
                uebersprungen: warm['uebersprungen'] as bool? ?? false,
              ),
      );
    } on Object {
      // Jeder Fehlertyp ist hier derselbe Befund: Der Klumpen ist nicht,
      // was wir geschrieben haben.
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GymLogEntwurf &&
      other.workout == workout &&
      other.trainingId == trainingId &&
      other.sitzungId == sitzungId &&
      other.datum == datum &&
      other.dauer == dauer &&
      other.notiz == notiz &&
      other.aufwaermen == aufwaermen &&
      _gleicheUebungen(other.uebungen, uebungen);

  @override
  int get hashCode => Object.hash(
    workout,
    trainingId,
    sitzungId,
    datum,
    dauer,
    notiz,
    aufwaermen,
    Object.hashAll(uebungen),
  );

  @override
  String toString() =>
      'GymLogEntwurf($kennung, $sitzungId, $gesamtSaetze Zeilen)';
}

// --- Hilfen -----------------------------------------------------------------

/// Was ein **leeres Gewichtsfeld** heißt: „wie letztes Mal" (Tim,
/// 10.11.2026).
///
/// Gibt den Text zurück, der abgelegt wird — das Gewicht [vorher] als
/// **Betrag** (die Unterstützung wird erst beim Ablegen negativ, Spec 8.1)
/// —, oder `null`, wenn nichts zu übernehmen ist:
///
/// - das Feld ist **nicht leer** (auch eine ausdrücklich getippte `0` nicht:
///   sie heißt null Kilo und verdrängt den Platzhalter),
/// - es gibt keinen Satz an dieser Stelle vom letzten Mal (dann heißt leer
///   0 kg, und es wird auch nicht der des Nachbarsatzes geliehen),
/// - die Übung ist eine Zeitübung (dort ist das Gewichtsfeld gesperrt).
///
/// Die **eine** Stelle für diese Regel: Platzhalter, Bilanz, Zusammenfassung
/// und Ablage fragen alle hier.
String? gymUebernommenesGewicht(
  String eingabe,
  CompletedSet? vorher, {
  required bool zeit,
}) {
  if (zeit || vorher == null || eingabe.trim().isNotEmpty) return null;
  final betrag = vorher.weight.abs();
  return betrag == betrag.roundToDouble()
      ? betrag.toStringAsFixed(0)
      : '$betrag';
}

/// Die Vorbelegung des Dauerfelds: die wirksame Dauer des Trainings
/// (`WorkoutDuration.effective`, Spec 15.2) als Text, leer bei einem
/// Training ohne bekannte Übung — dort gibt es nichts zu schätzen.
String _vorgabeDauer(WorkoutDefinition definition) {
  final minuten = WorkoutDuration.effective(
    entered: definition.enteredMinutes,
    exercises: definition.exercises,
  );
  return minuten == null ? '' : '$minuten';
}

List<GymLogUebung> _frischeUebungen(List<WorkoutExercise> geplant) => [
  for (final e in geplant)
    if (ExerciseLibrary.byId(e.exerciseId) case final uebung?)
      _frischeUebung(e, uebung),
];

/// Frische Zeilen für eine geplante Übung: so viele, wie das **Training**
/// vorsieht — mindestens eine, denn eine Übung ohne Zeile hätte kein Feld,
/// in das man tippen könnte (Spec 3.5).
GymLogUebung _frischeUebung(WorkoutExercise geplant, Exercise uebung) =>
    GymLogUebung(
      id: uebung.id,
      saetze: List.generate(
        geplant.sets < 1 ? 1 : geplant.sets,
        (_) => const RawSet(weight: '', reps: ''),
        growable: false,
      ),
      unterstuetzt: uebung.allowsAssist,
    );

RawSet _satzAus(Map<String, dynamic> karte) {
  final zeit = karte['t'] as String?;
  return RawSet(
    weight: karte['g'] as String? ?? '',
    reps: karte['w'] as String? ?? '',
    recordedAt: zeit == null ? null : DateTime.parse(zeit).toUtc(),
  );
}

/// Minuten aus dem Dauerfeld, `null` für „nicht erfasst". Null oder weniger
/// Minuten sind keine Dauer.
int? _minuten(String dauer) {
  final gelesen = int.tryParse(dauer.trim());
  return (gelesen == null || gelesen <= 0) ? null : gelesen;
}

ImportedSession? _alsSitzung({
  Workout? workout,
  String? trainingId,
  required List<GymLogUebung> uebungen,
  required String id,
  required DateTime date,
  required int? minuten,
  required String? notiz,
  required WarmUp? aufwaermen,
  String? trainingName,
}) => GymSessionBuilder.session(
  id: id,
  date: date,
  workout: workout,
  trainingId: trainingId,
  trainingName: trainingName,
  minutes: minuten,
  note: notiz,
  entries: {for (final u in uebungen) u.id: u.saetze},
  assist: {for (final u in uebungen) u.id: u.unterstuetzt},
  warmUp: aufwaermen,
  // Die Reihenfolge des Trainings gilt nur dort, wo es keinen Enum-Fall
  // gibt: Für diesen steht sie im Katalog, und eine bestehende Sitzung
  // ändert sich nicht (Spec 25 Nr. 1).
  trainingOrder: trainingId == null ? null : [for (final u in uebungen) u.id],
);

bool _gleicheSaetze(List<RawSet> a, List<RawSet> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _gleicheUebungen(List<GymLogUebung> a, List<GymLogUebung> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
