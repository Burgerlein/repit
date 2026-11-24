// Das laufende Training als Notifier (#78): der Entwurf, die
// 1,5-Sekunden-Ablage, das Verwerfen und das Abschließen.
//
// **Ein Notifier und keine Widget-Zustandsvariable** (Spec 9.2), aus drei
// Gründen, von denen jeder allein reichte:
//
// - **Fehler `32`.** Ein Wert, der dastand, steht nach dem Zurücknavigieren
//   wieder da. Läge der Entwurf in `State`, wäre er beim Öffnen und Schließen
//   des Vollbilds weg.
// - **Hausregel 3.** `ref` nur in `build` und in Notifiern. Die Wartezeit,
//   der Schreibauftrag und das Verwerfen sind Verhalten, kein Aufbau.
// - **#418 Punkt 4: „Der Zwischenstand ist von außen befüllbar."** Die
//   Methoden hier sind zugleich die Naht für die Uhr: Sie ruft später
//   dieselbe Methode wie das Textfeld ([setzeSatz]).
//
// **Kein `Messwert<T>`** (`CLAUDE.md`): Der Entwurf sind Tims eigene Daten.
// Das Lesen beim Öffnen trägt trotzdem sein [GymLogStand.laedt] (Spec 9.3).
//
// **Die Ablage kennt genau einen Entwurf** (Tim, 10.11.2026). Der Provider
// ist trotzdem je Training angelegt: Der Schirm kennt sein Training. Liegt in
// der Ablage der Zwischenstand eines **anderen**, schreibt dieser Notifier
// nichts und meldet es in [GymLogStand.laufendes]; die Rückfrage stellt der
// Schirm, die Antwort „ersetzen" ist [GymLogNotifier.ersetzeLaufendes].
//
// **Der Schlüssel ist ein [TrainingKey]** (Spec 15, #534): Ein [Workout] ist
// einer, ein eigenes Training trägt seine UUID in [CustomTrainingKey]. Der
// Notifier löst ihn zu einer [WorkoutDefinition] auf — die Zeile in
// `gym_trainings`, wo es eine gibt, sonst `WorkoutTemplates.fromEnum` für die
// Enum-Fälle ohne Zeile (Gym A–D) — und baut daraus Übungsliste und
// Reihenfolge, Zeilenzahl, Bereich und Dauer-Vorbelegung. **Ein Entwurf der
// Ablage für ein Training, das sich nicht lesen lässt, wird nie
// verworfen** (Spec 4.7, 27 Nr. 5): Der Notifier sperrt nur das Schreiben.
import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_repository.dart';
import '../data/gym_training_repository.dart';
import '../health/health_provider.dart' show clockProvider;
import 'gym_entwurf_provider.dart';
import 'gym_log_ansicht.dart' show letzteSaetzeVon;
import 'gym_log_entwurf.dart';
import 'gym_log_stand.dart';
import 'gym_pause_provider.dart';
import 'gym_verlauf_provider.dart';

/// Wie lange nach der letzten Eingabe gewartet wird, bis in die Ablage
/// geschrieben wird: **1,5 Sekunden** (`SPEC.md:136`). Nicht bei jedem
/// Tastendruck — ein Schreibvorgang je Zeichen, mitten im Training, auf dem
/// Weg zwischen zwei Sätzen.
const kGymZwischenstandPause = Duration(milliseconds: 1500);

/// Vergibt die UUID einer neuen Einheit (#418 Punkt 1).
///
/// Als Funktion im Provider, damit Tests eine feste Kennung einsetzen.
/// **Großbuchstaben**, wie Swifts `UUID().uuidString`: Die Uhr (#413) und
/// die Übernahme (#59) sprechen über dieselbe Kennung, und als Text
/// verglichen sind „ab12…" und „AB12…" zwei verschiedene.
final gymIdProvider = Provider<String Function()>((ref) => _neueUuid);

String _neueUuid() {
  final zufall = Random.secure();
  final b = List<int>.generate(16, (_) => zufall.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // Version 4
  b[8] = (b[8] & 0x3f) | 0x80; // Variante
  String hex(int von, int bis) =>
      [for (var i = von; i < bis; i++) b[i].toRadixString(16).padLeft(2, '0')]
          .join()
          .toUpperCase();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Das laufende Training dieses Schlüssels.
///
/// **Nicht `autoDispose`:** Das Vollbild und die Erfassung teilen sich den
/// Stand, und er soll das Schließen des einen überleben (Fehler `32`). Es
/// gibt so viele davon, wie Trainings angefangen wurden. Nach Abschließen
/// und Verwerfen steht in ihm wieder ein frisches Training.
///
/// **Für ein Training gibt es genau einen Schlüssel:** [TrainingKey.fromId]
/// liefert den Enum-Fall, wo es einen gibt — `gymLogProvider(Workout.push)`
/// und `gymLogProvider(TrainingKey.fromId('Push'))` sind derselbe Provider.
final gymLogProvider =
    NotifierProvider.family<GymLogNotifier, GymLogStand, TrainingKey>(
      GymLogNotifier.new,
    );

class GymLogNotifier extends Notifier<GymLogStand> {
  GymLogNotifier(this.schluessel);

  final TrainingKey schluessel;

  /// Der Enum-Fall des Schlüssels, `null` bei einem Training ohne.
  Workout? get workout {
    final s = schluessel;
    return s is Workout ? s : null;
  }

  Timer? _timer;
  bool _entsorgt = false;

  /// Zählt, wie oft der Lauf neu begann — beim Aufbau, beim Verwerfen und
  /// beim Abschließen. Ein Schreibauftrag merkt sich die Zahl, mit der er
  /// entstand, und **tut nichts**, wenn sie nicht mehr stimmt. Das ist der
  /// Schutz vor Swifts `onDisappear`-Falle (`GymLogDraft.swift:42–44`): Die
  /// Wartezeit läuft noch, wenn der Entwurf gerade gelöscht wurde, und
  /// legte ihn sonst neu an.
  int _epoche = 0;

  /// Schreibvorgänge laufen **nacheinander**, nie überlappend: Zwei
  /// Schreibvorgänge zugleich landen in beliebiger Reihenfolge, und der
  /// ältere Stand könnte den jüngeren überschreiben — oder das Verwerfen
  /// den Entwurf löschen, bevor ein früherer Auftrag ihn neu anlegt.
  Future<void> _kette = Future<void>.value();

  Future<void> _bereit = Future<void>.value();

  /// Fertig, sobald die Ablage geantwortet hat ([GymLogStand.laedt] ist
  /// dann `false`). Für alles, was von außen kommt und nicht auf den
  /// Schirm schaut — die Uhr (#413), Tests.
  Future<void> get bereit => _bereit;

  @override
  GymLogStand build() {
    // `watch` statt `read`: Alle drei sind Konstanten des Baums, und
    // `ref.read` in `build` meldet riverpod_lint.
    final repo = ref.watch(gymRepositoryProvider);
    final jetzt = ref.watch(clockProvider)();
    final neueId = ref.watch(gymIdProvider)();

    _timer?.cancel();
    _timer = null;
    final epoche = ++_epoche;
    _entsorgt = false;
    ref.onDispose(() {
      _entsorgt = true;
      _timer?.cancel();
      _timer = null;
    });

    final start = _frischerEntwurf(
      workout == null ? null : WorkoutTemplates.fromEnum(workout!),
      sitzungId: neueId,
      jetzt: jetzt,
    );
    _bereit = _lade(
      repo,
      ref.watch(gymTrainingRepositoryProvider),
      epoche,
      start,
    );
    // Ein Enum-Fall hat seine Definition von Anfang an (die Netz-Fassung, bis
    // die Zeile gelesen ist), damit der Platzhalter dieselbe Form hat wie der
    // Inhalt; ein Training ohne Enum-Fall kennt seine Übungen erst nach dem
    // Lesen.
    return GymLogStand.laedt(
      start,
      training: workout == null ? null : WorkoutTemplates.fromEnum(workout!),
    );
  }

  // --- Lesen ---------------------------------------------------------------

  Future<void> _lade(
    GymRepository repo,
    GymTrainingRepository trainings,
    int epoche,
    GymLogEntwurf start,
  ) async {
    GymLogStand ergebnis;
    GymLogEntwurf frisch = start;
    WorkoutDefinition? definition;
    try {
      definition = await _definition(trainings);
      frisch = _frischerEntwurf(
        definition,
        sitzungId: start.sitzungId,
        jetzt: start.datum,
      );

      final gespeichert = await repo.entwurf();
      if (definition == null) {
        // Das Training gibt es nicht (mehr) oder es ist ein Entwurf des
        // Editors — weder startbar noch einplanbar. **Nichts wird geschrieben
        // und nichts verworfen:** Ein Entwurf der Erfassung für dieses
        // Training ist Tims Zwischenstand und das Gerät die einzige Kopie
        // (Spec 4.7). `entwurfNichtGelesen` sperrt das Schreiben.
        ergebnis = GymLogStand(
          entwurf: frisch,
          hinweis: GymLogHinweis.entwurfNichtGelesen,
        );
      } else if (gespeichert == null) {
        ergebnis = GymLogStand(entwurf: frisch, training: definition);
      } else if (gespeichert.kennung != schluessel.id) {
        // Ein anderes Training läuft. Gelesen wird es nur, um zu sagen, was
        // beim Ersetzen verloren ginge — und wie es heißt.
        final fremdeId = gespeichert.trainingId;
        WorkoutDefinition? fremdeDefinition;
        if (fremdeId != null) {
          try {
            fremdeDefinition = await trainings.trainingAuchGeloescht(fremdeId);
          } on Object {
            // Ohne Namen: Die Rückfrage nennt dann „Training".
          }
        }
        final fremd = GymLogEntwurf.ausAblage(
          gespeichert,
          definition: fremdeDefinition,
        );
        ergebnis = GymLogStand(
          entwurf: frisch,
          training: definition,
          laufendes: GymLaufendes(
            workout: gespeichert.workout,
            trainingId: fremdeId,
            name: fremdeDefinition?.name,
            saetze: fremd?.alsSitzung()?.setCount ?? 0,
          ),
        );
      } else {
        final gelesen = GymLogEntwurf.ausAblage(
          gespeichert,
          definition: definition,
        );
        ergebnis = gelesen == null
            ? GymLogStand(
                entwurf: frisch,
                training: definition,
                hinweis: GymLogHinweis.entwurfUnlesbar,
              )
            : GymLogStand(
                entwurf: gelesen,
                training: definition,
                gespeichertAm: gespeichert.gespeichertAm,
              );
      }
    } on StateError {
      // `GymRepository.entwurf` wirft, wenn die Zeile ein Training nennt, das
      // es nicht (mehr) gibt. **Die Zeile bleibt liegen** (Spec 4.7, 27
      // Nr. 5): Tims Zwischenstand wird nicht verworfen, nur weil der Schirm
      // ihn nicht deuten kann. Das Schreiben ist gesperrt, der Schirm sagt
      // es — bisher wurde die Zeile hier gelöscht, und das war ein Fehler.
      ergebnis = GymLogStand(
        entwurf: frisch,
        training: definition,
        hinweis: GymLogHinweis.entwurfNichtGelesen,
      );
    } on Object {
      ergebnis = GymLogStand(
        entwurf: frisch,
        training: definition,
        hinweis: GymLogHinweis.entwurfNichtGelesen,
      );
    }
    if (_entsorgt || epoche != _epoche) return;
    state = ergebnis;
    // Nur ein **frisches** Training bekommt den zuletzt benutzten Modus; ein
    // gelesener Zwischenstand trägt seinen eigenen.
    if (ergebnis.hinweis == null && ergebnis.entwurf == frisch) {
      await _modusNachtragen(epoche, frisch);
    }
  }

  /// Die Definition des Trainings, `null` wenn es sich nicht starten lässt.
  ///
  /// - **Ein Enum-Fall:** die Zeile in `gym_trainings`, sonst
  ///   `WorkoutTemplates.fromEnum` — für Gym A–D, die keine Zeile haben, und
  ///   für jedes Enum-Training ohne. (Templates sind nicht löschbar,
  ///   Spec 26 Nr. 1; der Rückfall ist also ein Netz, kein Weg.)
  /// - **Ein Training ohne Enum-Fall:** die lebende Zeile. Ein Entwurf des
  ///   Editors ([WorkoutDefinition.isDraft]) ist weder startbar noch
  ///   einplanbar (Spec 9.6) — an der Schicht, die es sagt, nicht nur im
  ///   Knopf.
  Future<WorkoutDefinition?> _definition(
    GymTrainingRepository trainings,
  ) async {
    final zeile = await trainings.training(schluessel.id);
    final fall = workout;
    if (fall != null) {
      return zeile == null || zeile.isDraft
          ? WorkoutTemplates.fromEnum(fall)
          : zeile;
    }
    return zeile == null || zeile.isDraft ? null : zeile;
  }

  /// Ein frisches Training: aus der [definition], wo es eine gibt; sonst —
  /// bei einem Training ohne Enum-Fall, das sich nicht lesen ließ — ohne
  /// Übungen.
  GymLogEntwurf _frischerEntwurf(
    WorkoutDefinition? definition, {
    required String sitzungId,
    required DateTime jetzt,
  }) {
    if (definition != null) {
      return GymLogEntwurf.ausDefinition(
        definition: definition,
        workout: workout,
        sitzungId: sitzungId,
        jetzt: jetzt,
      );
    }
    return GymLogEntwurf(
      workout: workout,
      trainingId: workout == null ? schluessel.id : null,
      sitzungId: sitzungId,
      datum: jetzt.toUtc(),
      dauer: '',
      notiz: '',
      uebungen: const [],
      aufwaermen: GymLogAufwaermen.nichts,
    );
  }

  /// „Der Modus wird fürs nächste Mal übernommen" (`SPEC.md:135`, Spec
  /// 13.3): Sobald der Verlauf da ist, bekommt ein **noch unberührtes**
  /// Training den zuletzt benutzten Unterstützungsmodus je Übung.
  ///
  /// Nachgetragen statt abgewartet: Der Schirm wartet nicht auf den Verlauf,
  /// um Felder anzubieten. Hat jemand inzwischen etwas angefasst, bleibt
  /// seine Eingabe, wie sie ist — das ist keine Eingabe, die wir
  /// überschreiben dürfen. Das Nachtragen **schreibt nichts**: Ein
  /// Training, das nur seinen Modus bekam, ist kein Training.
  Future<void> _modusNachtragen(int epoche, GymLogEntwurf start) async {
    final List<ImportedSession> sitzungen;
    try {
      sitzungen = await ref.read(gymSitzungenProvider.future);
    } on Object {
      return; // Ohne Verlauf gilt der Vorgabewert.
    }
    if (_entsorgt || epoche != _epoche) return;
    if (state.laedt || state.entwurf != start) return;
    final angepasst = start.mitLetztemModus(GymSessionMerge.history(sitzungen));
    if (angepasst != start) state = state.copyWith(entwurf: angepasst);
  }

  // --- Eingaben ------------------------------------------------------------
  //
  // Jede Eingabe während des Lesens wird **nicht angenommen** — sie würde vom
  // gespeicherten Zwischenstand überschrieben, sobald er eintrifft. Der
  // Schirm bietet in dieser Zeit keine Felder an ([GymLogStand.laedt]);
  // wer von außen kommt, wartet auf [bereit].

  /// Setzt Gewicht und/oder Wiederholungen einer Zeile. `null` lässt das
  /// Feld, wie es ist. Der **Zeitpunkt** des Satzes entsteht hier
  /// (Spec 11.4) — siehe [GymLogEntwurf.mitSatz].
  void setzeSatz(String uebungId, int index, {String? gewicht, String? wdh}) =>
      _aendere(
        (e, jetzt) => e.mitSatz(
          uebungId,
          index,
          gewicht: gewicht,
          wdh: wdh,
          jetzt: jetzt,
        ),
      );

  /// Hängt eine Zeile an, die das Gewicht der letzten erbt.
  void haengeSatzAn(String uebungId) =>
      _aendere((e, _) => e.mitSatzAngehaengt(uebungId));

  /// Entfernt eine **leere** Zeile, nie die letzte der Übung — siehe
  /// [GymLogEntwurf.satzEntfernbar]. Sonst passiert nichts.
  void entferneSatz(String uebungId, int index) =>
      _aendere((e, _) => e.ohneSatz(uebungId, index));

  /// Schaltet „Zusatzgewicht | Unterstützung" einer Übung um.
  void setzeUnterstuetzung(String uebungId, {required bool an}) =>
      _aendere((e, _) => e.mitUnterstuetzung(uebungId, an: an));

  /// Verstellt den **Tag** des Trainings und behält die Uhrzeit — zwei
  /// Trainings an einem Tag sollen sich unterscheiden lassen.
  ///
  /// [tag] ist das, was der Datumswähler liefert: Es zählen nur Jahr, Monat
  /// und Tag, **als Berliner Kalendertag**. Die Wanduhrzeit kommt aus dem
  /// bisherigen Datum; die Rechnung über `wanduhrZeitpunkt` aus dem Kern
  /// ist dieselbe wie beim Wasser und übersteht die Zeitumstellung. (Bis
  /// zum Zusammenführen mit `umfaenge-88` hieß der Aufruf hier
  /// `berlinerZeitpunkt` — ein Hülle um genau diese Funktion, die mit
  /// #456 entfallen ist.)
  void setzeDatum(DateTime tag) => _aendere((e, _) {
    final schluessel =
        '${tag.year.toString().padLeft(4, '0')}-'
        '${tag.month.toString().padLeft(2, '0')}-'
        '${tag.day.toString().padLeft(2, '0')}';
    final (stunde, minute) = BerlinCalendar.wallClock(e.datum);
    return e.copyWith(
      datum: wanduhrZeitpunkt(
        schluessel,
        stunde * Duration.minutesPerHour + minute,
      ),
    );
  });

  /// Die Dauer in Minuten, roher Text.
  void setzeDauer(String text) => _aendere((e, _) => e.copyWith(dauer: text));

  void setzeNotiz(String text) => _aendere((e, _) => e.copyWith(notiz: text));

  /// Setzt das Aufwärmen als Ganzes — „nichts", „übersprungen" oder
  /// ausgefüllt. Wer ein Feld ändert, baut das Neue mit
  /// [GymLogAufwaermen.copyWith] aus dem Alten.
  void setzeAufwaermen(GymLogAufwaermen aufwaermen) =>
      _aendere((e, _) => e.copyWith(aufwaermen: aufwaermen));

  void _aendere(GymLogEntwurf Function(GymLogEntwurf, DateTime jetzt) f) {
    if (state.laedt) return;
    final neu = f(state.entwurf, ref.read(clockProvider)());
    if (neu == state.entwurf) return;
    state = state.copyWith(entwurf: neu);
    _beruehre();
  }

  // --- Zwischenstand -------------------------------------------------------

  /// Jede Änderung setzt „wird gespeichert" und startet die Wartezeit neu
  /// (Spec 9.1 Punkt 1).
  void _beruehre() {
    if (!state.darfSchreiben) return;
    state = state.copyWith(speichert: true);
    _timer?.cancel();
    _timer = Timer(kGymZwischenstandPause, () {
      _timer = null;
      unawaited(_schreibe());
    });
  }

  /// „Zwischenspeichern" und „beim Verlassen des Schirms": schreibt sofort
  /// (Spec 9.1 Punkte 3 und 5). `true`, wenn geschrieben (oder, bei leerem
  /// Entwurf, gelöscht) wurde.
  Future<bool> schreibeSofort() async {
    await _bereit;
    _timer?.cancel();
    _timer = null;
    return _schreibe();
  }

  Future<bool> _schreibe() {
    final epoche = _epoche;
    return _nacheinander<bool>(() async {
      if (_entsorgt || epoche != _epoche) return false;
      final vorher = state;
      if (!vorher.darfSchreiben) return false;

      final repo = ref.read(gymRepositoryProvider);
      final jetzt = ref.read(clockProvider)().toUtc();
      final inhalt = vorher.entwurf.hatInhalt;
      try {
        if (inhalt) {
          await repo.speichereEntwurf(
            vorher.entwurf.alsAblage(gespeichertAm: jetzt),
          );
        } else {
          // Ein leerer Entwurf wird gelöscht, nicht geschrieben.
          await repo.verwirfEntwurf();
        }
      } on Object {
        if (_entsorgt || epoche != _epoche) return false;
        state = state.copyWith(
          speichert: false,
          gespeichertAm: null,
          hinweis: GymLogHinweis.zwischenspeichernFehlgeschlagen,
        );
        return false;
      }
      // Die Gym-Übersicht liest dieselbe Ablage: Sie muss erfahren, dass
      // ein Training läuft — oder keins mehr.
      if (!_entsorgt) ref.invalidate(gymEntwurfProvider);
      if (_entsorgt || epoche != _epoche) return true;
      state = state.copyWith(
        // Kam während des Schreibens eine weitere Eingabe, läuft die
        // Wartezeit schon wieder — dann bleibt „wird gespeichert" stehen.
        speichert: _timer?.isActive ?? false,
        gespeichertAm: inhalt ? jetzt : null,
        hinweis: state.hinweis == GymLogHinweis.zwischenspeichernFehlgeschlagen
            ? null
            : state.hinweis,
      );
      return true;
    });
  }

  // --- Verwerfen und Abschließen -------------------------------------------

  /// „Training abbrechen" (nach der Rückfrage): Der Entwurf verschwindet aus
  /// der Ablage, sonst öffnete „Training starten" das Versehen beim nächsten
  /// Mal wieder (Spec 3.6).
  ///
  /// **Danach wird nichts mehr geschrieben:** Die Wartezeit wird abgebrochen,
  /// und ein Schreibauftrag, der schon unterwegs oder in der Schlange ist,
  /// merkt über [_epoche], dass er veraltet ist. Der Stand ist danach ein
  /// frisches Training.
  Future<void> verwirf() async {
    await _bereit;
    _timer?.cancel();
    _timer = null;
    final epoche = ++_epoche;
    ref.read(gymPauseProvider.notifier).stoppe();
    final fremd = state.laufendes;
    state = _frisch(laufendes: fremd);
    unawaited(_modusNachtragen(epoche, state.entwurf));
    // **Liegt der Zwischenstand eines anderen Trainings in der Ablage,
    // gehört er nicht zu diesem hier** — verwerfen löschte ihn mit. Er wird
    // nur über [ersetzeLaufendes] angefasst, nach der Rückfrage.
    if (fremd != null) return;
    try {
      await _nacheinander<void>(
        () => ref.read(gymRepositoryProvider).verwirfEntwurf(),
      );
    } on Object {
      if (_entsorgt || epoche != _epoche) return;
      state = state.copyWith(hinweis: GymLogHinweis.verwerfenFehlgeschlagen);
      return;
    }
    if (!_entsorgt) ref.invalidate(gymEntwurfProvider);
  }

  /// Die Antwort „ersetzen" auf die Rückfrage, wenn schon ein **anderes**
  /// Training läuft ([GymLogStand.laufendes]): Dessen Zwischenstand wird
  /// verworfen, und dieses Training darf schreiben. Läuft keins, passiert
  /// nichts.
  Future<void> ersetzeLaufendes() async {
    await _bereit;
    if (state.laufendes == null) return;
    try {
      await _nacheinander<void>(
        () => ref.read(gymRepositoryProvider).verwirfEntwurf(),
      );
    } on Object {
      if (_entsorgt) return;
      state = state.copyWith(hinweis: GymLogHinweis.verwerfenFehlgeschlagen);
      return;
    }
    if (_entsorgt) return;
    ref.invalidate(gymEntwurfProvider);
    state = state.copyWith(laufendes: null, hinweis: null);
  }

  /// „Training abschließen": Das fertige Training wird abgelegt und der
  /// Zwischenstand verschwindet — **in einer Transaktion**
  /// (`GymRepository.schliesseAb`).
  ///
  /// **Scheitert das Ablegen, bleibt der Zwischenstand stehen** und
  /// [GymLogStand.hinweis] sagt es (Tim, 10.11.2026). Die alte App löscht
  /// ihn trotzdem; das wird nicht portiert.
  ///
  /// Zählt kein einziger Satz, wird nichts abgelegt und nichts gelöscht
  /// ([GymAbschluss.nichtsZuAblegen]). Läuft ein anderes Training, ebenso:
  /// Abschließen löschte sonst dessen Zwischenstand.
  Future<GymAbschluss> schliesseAb() async {
    await _bereit;
    if (state.laufendes != null || state.laedt) {
      return GymAbschluss.nichtsZuAblegen;
    }
    _timer?.cancel();
    _timer = null;
    // Ein leeres Gewichtsfeld heißt „wie letztes Mal" (Tim, 10.11.2026):
    // Abgelegt wird der Wert vom letzten Mal, gelesen aus dem Verlauf, wie
    // ihn der Platzhalter zeigt. Ist der Verlauf nicht lesbar, steht auch
    // kein Platzhalter da — dann heißt leer 0 kg.
    var letzte = const <String, List<CompletedSet>>{};
    try {
      final sitzungen = await ref.read(gymSitzungenProvider.future);
      letzte = letzteSaetzeVon(
        GymVerlauf(verlauf: GymSessionMerge.history(sitzungen)),
      );
    } on Object {
      // siehe oben
    }
    if (_entsorgt) return GymAbschluss.nichtsZuAblegen;
    final trainingName = await _trainingsName();
    if (_entsorgt) return GymAbschluss.nichtsZuAblegen;
    final sitzung = state.entwurf
        .copyWithUebungen(
          GymLogEntwurf.uebernommen(state.entwurf.uebungen, letzte),
        )
        .alsSitzung(trainingName: trainingName);
    if (sitzung == null) {
      // Die Wartezeit ist abgebrochen, der Stand nicht geschrieben.
      _beruehre();
      return GymAbschluss.nichtsZuAblegen;
    }

    // Ein Schreibauftrag aus der Schlange darf den Entwurf nicht neu
    // anlegen, nachdem `schliesseAb` ihn gelöscht hat.
    final epoche = ++_epoche;
    try {
      await _nacheinander<void>(
        () => ref.read(gymRepositoryProvider).schliesseAb(sitzung),
      );
    } on Object {
      if (!_entsorgt && epoche == _epoche) {
        state = state.copyWith(
          speichert: false,
          hinweis: GymLogHinweis.ablegenFehlgeschlagen,
        );
        // Der Zwischenstand steht noch — und was seit dem letzten
        // Schreiben dazukam, steht dort noch nicht.
        _beruehre();
      }
      return GymAbschluss.fehlgeschlagen;
    }
    if (_entsorgt) return GymAbschluss.abgelegt;

    // Das Training gehört jetzt zum Verlauf: Vorschlag und Platzhalter der
    // nächsten Übung rechnen auf dem neuen Stand.
    ref.invalidate(gymSitzungenProvider);
    ref.invalidate(gymEntwurfProvider);
    ref.read(gymPauseProvider.notifier).stoppe();
    state = _frisch();
    unawaited(_modusNachtragen(_epoche, state.entwurf));
    return GymAbschluss.abgelegt;
  }

  /// Der Name, den die Sitzung beim Abschließen einfriert (Spec 4.6): **der
  /// Name des Trainings in diesem Augenblick**, nie nachträglich
  /// aktualisiert.
  ///
  /// Er kommt aus der Zeile in `gym_trainings`, wo es eine gibt (Push, Pull,
  /// Legs, jedes eigene Training — und, wo Tim es umbenannt hat, mit dem
  /// neuen Namen; auch ein Tombstone trägt noch seinen), und sonst aus
  /// `WorkoutTemplates.fromEnum` — also für Gym A bis D, die keine Zeile
  /// haben, und für jedes Enum-Training ohne Zeile. Nie aus dem Zufall: Beides
  /// ist `'${label} — ${title}'`, die Zeichenkette, die die Schirme heute
  /// zusammensetzen.
  ///
  /// **Scheitert das Lesen der Zeile, scheitert das Abschließen nicht:** Ein
  /// Training, das sich nicht ablegen ließe, nur weil sich sein Name nicht
  /// nachschlagen lässt, wäre der schlimmere Fehler. Es gilt dann der Name
  /// des Enums — derselbe, den eine Sitzung ohne Zeile ohnehin bekäme — oder,
  /// bei einem Training ohne Enum-Fall, der Name, mit dem es gelesen wurde.
  Future<String?> _trainingsName() async {
    try {
      final zeile = await ref
          .read(gymTrainingRepositoryProvider)
          .trainingAuchGeloescht(schluessel.id);
      if (zeile != null) return zeile.name;
    } on Object {
      // siehe oben
    }
    final fall = workout;
    return fall == null
        ? state.training?.name
        : WorkoutTemplates.fromEnum(fall).name;
  }

  // --- Innenleben ----------------------------------------------------------

  GymLogStand _frisch({GymLaufendes? laufendes}) => GymLogStand(
    entwurf: _frischerEntwurf(
      state.training,
      sitzungId: ref.read(gymIdProvider)(),
      jetzt: ref.read(clockProvider)(),
    ),
    training: state.training,
    laufendes: laufendes,
  );

  Future<T> _nacheinander<T>(Future<T> Function() arbeit) {
    final lauf = _kette.then((_) => arbeit());
    _kette = lauf.then<void>((_) {}, onError: (Object _) {});
    return lauf;
  }
}
