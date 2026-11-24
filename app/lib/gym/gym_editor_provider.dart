// Der Zustand des Training-Editors (#534 unter #531, Task 3.4; Spec 9.2, 22
// Nr. 3, 27): Quelle, Stand und der Notifier, der alles hält, die Schätzung
// einmal je Änderung rechnet und den Stand selbst sichert.
//
// API und Verhalten sind durch `app/test/gym/gym_editor_provider_test.dart`,
// `app/test/data/gym_training_entwurf_test.dart` und den Kopf von
// `app/test/gym/gym_editor_support.dart` verbindlich vorgegeben — diese Datei
// darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **Kein `Messwert<T>`** (`CLAUDE.md`, Spec 5.6a): Das sind Tims eigene Daten,
// es gibt keinen Lauf, der leer ausgehen kann. Aber auch hier darf „wird
// gelesen" nicht wie „leeres Training" aussehen (Fehler `01`): Der Stand
// trägt [GymEditorStand.laedt], und solange es gilt, ist `probleme` leer —
// aus nichts Gelesenem folgt kein Grund —, und Eingaben werden nicht
// angenommen (sie würden vom gelesenen Stand überschrieben).
//
// **Der Stand liegt im Notifier, nicht im Widget** (Fehler `32`): Er übersteht
// das Öffnen und Schließen von Einstellblatt und Auswahl. Der Provider ist
// `autoDispose` — nichts überlebt das Schließen des Editors, **außer einem
// Entwurf in der Datenbank**.
//
// **Selbstsicherung** (Tim, 19.11.2026, Spec 22 Nr. 3, schlägt 9.6, 17.14 und
// 17.15): Sobald etwas geändert ist, schreibt der Editor seinen Stand 1,5
// Sekunden nach der **letzten** Änderung als Entwurf, und sofort beim Schließen
// ([schreibeSofort]). Ein nur geöffneter Editor hinterlässt nichts. Gleicht der
// Stand wieder dem Ausgang, geht die Zeile weg (Plan 4) — **außer bei der
// Quelle `entwurf`** (Spec 27 Nr. 3): Dort ist der Ausgang selbst ein bewusst
// behaltener Entwurf, und die Zeile trägt danach wieder den gespeicherten
// Stand.
//
// - `neu`, `kopie`: Der Entwurf hat die Kennung dieser Sitzung (eine neue
//   Kennung aus `gymIdProvider`, **eine je Sitzung**) und wird beim Speichern
//   zum fertigen Eigenen unter derselben Kennung.
// - `bearbeite`: Der Zwischenstand hängt am Training (`entwurf_von`), ersetzt
//   es erst beim Speichern — vollständig und in einer Transaktion
//   (`uebernimmZwischenstand`) — und ist keine eigene Kachel (Spec 27 Nr. 2).
// - `entwurf`: dieselbe Zeile, bis sie fertig oder verworfen ist.
//
// **Die Invalidierung steht beim Schreiber** (Spec 6.3): Wer schreibt, sagt es
// den Quellen — keine drift-Streams. Dafür hält der Notifier den
// `ProviderContainer` fest: Das letzte Schreiben beim Schließen läuft, wenn der
// Notifier schon entsorgt ist, und `ref` wäre dann nicht mehr benutzbar.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/gym_training_repository.dart';
import 'gym_log_provider.dart' show gymIdProvider;
import 'gym_trainings_provider.dart';

/// Wie lange nach der **letzten** Änderung gewartet wird, bis der Stand als
/// Entwurf geschrieben wird: **1,5 Sekunden** (Plan 5) — dieselbe Pause wie
/// beim Zwischenstand der Erfassung.
const kGymEditorSicherungsPause = Duration(milliseconds: 1500);

/// Woher der Editor kommt.
///
/// Werttyp mit [==] und [hashCode] je Fall — Schlüssel der Familie.
sealed class GymEditorQuelle {
  const GymEditorQuelle();

  /// Ein neues, leeres Training.
  const factory GymEditorQuelle.neu() = GymEditorNeu;

  /// Ein bestehendes **Eigenes** bearbeiten.
  const factory GymEditorQuelle.bearbeite(String id) = GymEditorBearbeite;

  /// Die Kopie eines **Templates** — angelegt wird erst beim Speichern.
  const factory GymEditorQuelle.kopie(String vonId) = GymEditorKopie;

  /// Ein frei stehender Entwurf.
  const factory GymEditorQuelle.entwurf(String id) = GymEditorEntwurf;
}

final class GymEditorNeu extends GymEditorQuelle {
  const GymEditorNeu();

  @override
  bool operator ==(Object other) => other is GymEditorNeu;

  @override
  int get hashCode => (GymEditorNeu).hashCode;

  @override
  String toString() => 'GymEditorQuelle.neu()';
}

final class GymEditorBearbeite extends GymEditorQuelle {
  const GymEditorBearbeite(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is GymEditorBearbeite && other.id == id;

  @override
  int get hashCode => Object.hash(GymEditorBearbeite, id);

  @override
  String toString() => 'GymEditorQuelle.bearbeite($id)';
}

final class GymEditorKopie extends GymEditorQuelle {
  const GymEditorKopie(this.vonId);

  final String vonId;

  @override
  bool operator ==(Object other) =>
      other is GymEditorKopie && other.vonId == vonId;

  @override
  int get hashCode => Object.hash(GymEditorKopie, vonId);

  @override
  String toString() => 'GymEditorQuelle.kopie($vonId)';
}

final class GymEditorEntwurf extends GymEditorQuelle {
  const GymEditorEntwurf(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is GymEditorEntwurf && other.id == id;

  @override
  int get hashCode => Object.hash(GymEditorEntwurf, id);

  @override
  String toString() => 'GymEditorQuelle.entwurf($id)';
}

/// Wie ein Speichern ausgegangen ist.
enum GymEditorErgebnis {
  /// Fertig gespeichert, der Editor darf schließen.
  gespeichert,

  /// `probleme` ist nicht leer — nichts geschrieben.
  nichtSpeicherbar,

  /// Die Erfassung trägt das Training (Spec 4.7) — nichts geändert.
  gesperrt,

  /// Die Ablage hat geworfen — der Stand bleibt.
  fehlgeschlagen,
}

/// Alles, was der Editor-Schirm zeigt — einmal gerechnet, vom Schirm nur
/// gelesen.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`); die
/// Listen werden inhaltlich verglichen.
@immutable
class GymEditorStand {
  const GymEditorStand({
    required this.laedt,
    required this.name,
    required this.tags,
    this.dauerEingetragen,
    this.schaetzung,
    required this.uebungen,
    required this.geaendert,
    required this.probleme,
    this.kopieVon,
  });

  /// Noch nichts gelesen: leerer Inhalt ohne Aussage, **kein** Grund.
  const GymEditorStand.laedt()
    : laedt = true,
      name = '',
      tags = const [],
      dauerEingetragen = null,
      schaetzung = null,
      uebungen = const [],
      geaendert = false,
      probleme = const [],
      kopieVon = null;

  /// `true`, bis die Ablage geantwortet hat. Solange es gilt, ist
  /// [probleme] leer und der Stand nicht „leeres Training" (Fehler `01`).
  final bool laedt;

  /// Roh, wie getippt — getrimmt wird beim Speichern.
  final String name;

  final List<String> tags;

  /// Die eigenen Minuten, `null` heißt „geschätzt". Eine eingetragene Dauer
  /// wird nicht nachgerechnet, wenn sich Übungen ändern (Spec 9.3).
  final int? dauerEingetragen;

  /// Die Schätzung des Kerns, **einmal je Änderung gerechnet**; `null` ohne
  /// Übung — nie 0 (Fehler `01`).
  final int? schaetzung;

  final List<WorkoutExercise> uebungen;

  /// Ob der **inhaltliche** Stand vom Ausgang abweicht: Ändern und
  /// Zurückändern heißt nichts geändert (Spec 9.2).
  final bool geaendert;

  /// `WorkoutRules.check` über den Stand als **fertiges** Training; leer
  /// heißt speicherbar. Leer, solange [laedt] gilt.
  final List<WorkoutProblem> probleme;

  /// Der Name des Templates, nur bei der Quelle `kopie`.
  final String? kopieVon;

  @override
  bool operator ==(Object other) =>
      other is GymEditorStand &&
      other.laedt == laedt &&
      other.name == name &&
      listEquals(other.tags, tags) &&
      other.dauerEingetragen == dauerEingetragen &&
      other.schaetzung == schaetzung &&
      listEquals(other.uebungen, uebungen) &&
      other.geaendert == geaendert &&
      listEquals(other.probleme, probleme) &&
      other.kopieVon == kopieVon;

  @override
  int get hashCode => Object.hash(
    laedt,
    name,
    Object.hashAll(tags),
    dauerEingetragen,
    schaetzung,
    Object.hashAll(uebungen),
    geaendert,
    Object.hashAll(probleme),
    kopieVon,
  );

  @override
  String toString() =>
      'GymEditorStand(laedt: $laedt, "$name", ${uebungen.length} Übungen, '
      'geaendert: $geaendert, probleme: $probleme)';
}

/// Der Editor je Quelle. **`autoDispose`:** Nichts überlebt das Schließen,
/// außer einem Entwurf in der Datenbank.
final gymEditorProvider = NotifierProvider.autoDispose
    .family<GymEditorNotifier, GymEditorStand, GymEditorQuelle>(
      GymEditorNotifier.new,
    );

class GymEditorNotifier extends Notifier<GymEditorStand> {
  GymEditorNotifier(this.quelle);

  final GymEditorQuelle quelle;

  // Alles Folgende ist **ohne `ref` benutzbar**: Das letzte Schreiben läuft,
  // wenn der Notifier schon entsorgt ist.
  late GymTrainingRepository _trainings;
  late ProviderContainer _container;

  /// Die Kennung dieser Sitzung: der Entwurf bei `neu`/`kopie`, der
  /// Zwischenstand bei `bearbeite` (und dort, wo schon einer liegt, dessen
  /// Kennung).
  late String _kennung;

  Timer? _timer;
  bool _entsorgt = false;

  /// Hat die Ablage geantwortet? Vorher wird nichts angenommen und nichts
  /// geschrieben.
  bool _gelesen = false;

  /// Ob etwas geschrieben werden darf. Falsch, wenn das Training nicht (mehr)
  /// da ist: Ein Schreiben bei unbekanntem Stand überschriebe, was dort liegt.
  bool _darfSchreiben = true;

  /// Zählt, wie oft der Lauf neu begann — beim Verwerfen, Speichern und
  /// Löschen. Ein Schreibauftrag merkt sich die Zahl, mit der er entstand,
  /// und tut nichts, wenn sie nicht mehr stimmt.
  int _epoche = 0;

  /// Schreibvorgänge laufen **nacheinander**, nie überlappend.
  Future<void> _kette = Future<void>.value();

  Future<void> _bereit = Future<void>.value();

  /// Ob **dieser Editor** eine Zeile angelegt hat (oder eine fand), die
  /// beim Zurückändern wieder weg muss.
  bool _geschrieben = false;

  /// Verworfen, gespeichert oder gelöscht: danach schreibt nichts mehr.
  bool _abgeschlossen = false;

  late WorkoutDefinition _ausgang;
  late WorkoutDefinition _inhalt;
  String? _kopieVon;

  /// Fertig, sobald gelesen ist ([GymEditorStand.laedt] ist dann `false`).
  Future<void> get bereit => _bereit;

  @override
  GymEditorStand build() {
    _trainings = ref.watch(gymTrainingRepositoryProvider);
    _container = ref.container;
    _kennung = ref.watch(gymIdProvider)();
    _entsorgt = false;
    ref.onDispose(() {
      final ausstehend = _timer?.isActive ?? false;
      _entsorgt = true;
      _timer?.cancel();
      _timer = null;
      // „Beim Schließen": Was noch auf den Takt wartete, geht jetzt in die
      // Ablage.
      if (ausstehend) unawaited(_sichere(_epoche));
    });

    _ausgang = _leer();
    _inhalt = _ausgang;
    switch (quelle) {
      case GymEditorNeu():
        // Nichts zu lesen: der unberührte Stand ist leer.
        _gelesen = true;
        return _stand();
      case GymEditorKopie() || GymEditorBearbeite() || GymEditorEntwurf():
        _bereit = _lade();
        return const GymEditorStand.laedt();
    }
  }

  // --- Lesen ---------------------------------------------------------------

  WorkoutDefinition _leer() => WorkoutDefinition(
    id: _kennung,
    name: '',
    category: WorkoutCategory.own,
    tags: const [],
    exercises: const [],
  );

  /// Der Inhalt, wie er verglichen wird: immer unter der Kennung dieser
  /// Sitzung, immer ein Eigenes, nie ein Entwurf.
  WorkoutDefinition _norm(WorkoutDefinition d) => WorkoutDefinition(
    id: _kennung,
    name: d.name,
    category: WorkoutCategory.own,
    tags: List.of(d.tags),
    exercises: List.of(d.exercises),
    enteredMinutes: d.enteredMinutes,
  );

  Future<void> _lade() async {
    WorkoutDefinition? ausgang;
    WorkoutDefinition? inhalt;
    try {
      switch (quelle) {
        case GymEditorKopie(:final vonId):
          final template = await _trainings.training(vonId);
          if (template != null) {
            ausgang = _norm(template.copyAsOwn(id: _kennung));
            _kopieVon = template.name;
          }
        case GymEditorBearbeite(:final id):
          final training = await _trainings.training(id);
          final zwischenstand = await _trainings.zwischenstandVon(id);
          if (training != null) {
            ausgang = _norm(training);
            if (zwischenstand != null) {
              // Der Ausgang ist das Training, nicht der Zwischenstand.
              _kennung = zwischenstand.id;
              _geschrieben = true;
              inhalt = _norm(zwischenstand);
              ausgang = _norm(training);
            }
          }
        case GymEditorEntwurf(:final id):
          final entwurf = await _trainings.training(id);
          if (entwurf != null) {
            _kennung = id;
            ausgang = _norm(entwurf);
          }
        case GymEditorNeu():
          break;
      }
    } on Object {
      ausgang = null;
    }
    if (_entsorgt) return;
    if (ausgang == null) {
      // Das Training gibt es nicht (mehr) oder es ließ sich nicht lesen: leer,
      // und **nichts wird geschrieben** — ein Schreiben überschriebe, was dort
      // vielleicht liegt.
      _darfSchreiben = false;
      _gelesen = true;
      state = _stand();
      return;
    }
    _ausgang = ausgang;
    _inhalt = inhalt ?? ausgang;
    _gelesen = true;
    state = _stand();
  }

  // --- Eingaben ------------------------------------------------------------
  //
  // Jede Eingabe während des Lesens wird **nicht angenommen** — sie würde vom
  // gelesenen Stand überschrieben, sobald er eintrifft.

  /// Der Name, roh, wie getippt.
  void setzeName(String name) => _aendere(_mit(name: name));

  /// Fügt einen Tag hinzu: normalisiert, ohne Doppelte (ohne Beachtung der
  /// Schreibweise), höchstens [WorkoutTags.maxCount] — über
  /// [WorkoutTags.add].
  void fuegeTagHinzu(String roh) =>
      _aendere(_mit(tags: WorkoutTags.add(_inhalt.tags, roh)));

  /// Entfernt einen Tag, ohne Beachtung der Schreibweise.
  void entferneTag(String tag) {
    final schluessel = tag.toLowerCase();
    _aendere(
      _mit(
        tags: [
          for (final t in _inhalt.tags)
            if (t.toLowerCase() != schluessel) t,
        ],
      ),
    );
  }

  /// Trägt eigene Minuten ein.
  void setzeDauer(int minuten) => _aendere(_mit(minuten: minuten));

  /// „Zurück zur Schätzung".
  void dauerZuruecksetzen() => _aendere(_mit(minuten: null));

  /// Hängt die Übung am Ende an, vorbelegt aus der Bibliothek (#551,
  /// Spec 8.2). **Eine Übung steht nur einmal im Training** (Spec 4.1): Ein
  /// zweites Hinzufügen ändert nichts, eine Kennung, die auch die Bibliothek
  /// nicht kennt, auch nicht.
  void fuegeUebungHinzu(String uebungId) {
    final katalog = ExerciseLibrary.byId(uebungId);
    if (katalog == null) return;
    if (_inhalt.exercises.any((e) => e.exerciseId == uebungId)) return;
    _aendere(
      _mit(
        uebungen: [..._inhalt.exercises, WorkoutExercise.fromCatalog(katalog)],
      ),
    );
  }

  void entferneUebung(String uebungId) => _aendere(
    _mit(
      uebungen: [
        for (final e in _inhalt.exercises)
          if (e.exerciseId != uebungId) e,
      ],
    ),
  );

  /// Verschiebt die Übung an Platz [von] (ab 0) an Platz [nach]; [nach] ist
  /// der Index **in der Liste danach** („↑" ist `verschiebeUebung(i, i - 1)`).
  void verschiebeUebung(int von, int nach) {
    final liste = [..._inhalt.exercises];
    if (von < 0 || von >= liste.length || nach < 0 || nach >= liste.length) {
      return;
    }
    if (von == nach) return;
    liste.insert(nach, liste.removeAt(von));
    _aendere(_mit(uebungen: liste));
  }

  /// Setzt Sätze und/oder Wiederholungsbereich einer Übung; was nicht genannt
  /// ist, bleibt.
  void setzeUmfang(String uebungId, {int? saetze, int? wdhVon, int? wdhBis}) {
    _aendere(
      _mit(
        uebungen: [
          for (final e in _inhalt.exercises)
            if (e.exerciseId == uebungId)
              WorkoutExercise(
                exerciseId: e.exerciseId,
                sets: saetze ?? e.sets,
                repLow: wdhVon ?? e.repLow,
                repHigh: wdhBis ?? e.repHigh,
                increment: e.increment,
              )
            else
              e,
        ],
      ),
    );
  }

  static const Object _unveraendert = Object();

  WorkoutDefinition _mit({
    String? name,
    List<String>? tags,
    Object? minuten = _unveraendert,
    List<WorkoutExercise>? uebungen,
  }) => WorkoutDefinition(
    id: _inhalt.id,
    name: name ?? _inhalt.name,
    category: WorkoutCategory.own,
    tags: tags ?? _inhalt.tags,
    exercises: uebungen ?? _inhalt.exercises,
    enteredMinutes: identical(minuten, _unveraendert)
        ? _inhalt.enteredMinutes
        : minuten as int?,
  );

  void _aendere(WorkoutDefinition neu) {
    if (!_gelesen || state.laedt || _abgeschlossen) return;
    if (neu == _inhalt) return;
    _inhalt = neu;
    state = _stand();
    _planeSicherung();
  }

  /// Der Stand aus dem Inhalt — **hier** wird die Schätzung gerechnet, einmal
  /// je Änderung, nicht im `build` des Schirms.
  GymEditorStand _stand() => GymEditorStand(
    laedt: false,
    name: _inhalt.name,
    tags: List.unmodifiable(_inhalt.tags),
    dauerEingetragen: _inhalt.enteredMinutes,
    schaetzung: WorkoutDuration.estimate(_inhalt.exercises),
    uebungen: List.unmodifiable(_inhalt.exercises),
    geaendert: _inhalt != _ausgang,
    probleme: List.unmodifiable(WorkoutRules.check(_inhalt)),
    kopieVon: _kopieVon,
  );

  // --- Selbstsicherung -----------------------------------------------------

  /// Jede Änderung startet die Wartezeit neu — gewartet wird auf die
  /// **letzte**.
  void _planeSicherung() {
    if (!_darfSchreiben || _abgeschlossen) return;
    _timer?.cancel();
    final epoche = _epoche;
    _timer = Timer(kGymEditorSicherungsPause, () {
      _timer = null;
      unawaited(_sichere(epoche));
    });
  }

  /// „Beim Schließen / beim Wechsel in den Hintergrund": schreibt einen
  /// geänderten Stand sofort, nicht erst nach 1,5 Sekunden. Ein nur
  /// geöffneter Editor schreibt nichts.
  Future<void> schreibeSofort() async {
    await _bereit;
    _timer?.cancel();
    _timer = null;
    await _sichere(_epoche);
  }

  /// „Als Entwurf behalten": sichert den geänderten Stand sofort. Seit der
  /// Selbstsicherung benennt das nur noch, was ohnehin gesichert wird
  /// (Spec 22 Nr. 3).
  Future<void> behalteAlsEntwurf() => schreibeSofort();

  Future<T> _nacheinander<T>(Future<T> Function() arbeit) {
    final lauf = _kette.then((_) => arbeit());
    _kette = lauf.then<void>((_) {}, onError: (Object _) {});
    return lauf;
  }

  /// Der Inhalt als Entwurf — unter [id], mit der Kategorie „eigene".
  WorkoutDefinition _alsEntwurf(WorkoutDefinition d, String id) =>
      WorkoutDefinition(
        id: id,
        name: d.name,
        category: WorkoutCategory.own,
        tags: d.tags,
        exercises: d.exercises,
        enteredMinutes: d.enteredMinutes,
        isDraft: true,
      );

  /// Schreibt den Stand als Entwurf — oder nimmt die Zeile weg, wenn er dem
  /// Ausgang wieder gleicht. **Scheitert das, bleibt der Stand im Speicher
  /// und der nächste Takt versucht es erneut:** Eine Selbstsicherung, die
  /// den Editor stört, wäre schlimmer als eine, die einmal aussetzt.
  Future<void> _sichere(int epoche) => _nacheinander(() async {
    if (epoche != _epoche || _abgeschlossen) return;
    if (!_gelesen || !_darfSchreiben) return;
    final inhalt = _inhalt;
    final geaendert = inhalt != _ausgang;
    try {
      switch (quelle) {
        case GymEditorNeu() || GymEditorKopie():
          if (geaendert) {
            await _trainings.speichere(_alsEntwurf(inhalt, _kennung));
            _geschrieben = true;
          } else if (_geschrieben) {
            await _trainings.verwirfEntwurf(_kennung);
            _geschrieben = false;
          } else {
            return;
          }
        case GymEditorBearbeite(:final id):
          if (geaendert) {
            await _trainings.speichereZwischenstand(
              _alsEntwurf(inhalt, _kennung),
              von: id,
            );
            _geschrieben = true;
          } else if (_geschrieben) {
            await _trainings.verwirfEntwurf(_kennung);
            _geschrieben = false;
          } else {
            return;
          }
        case GymEditorEntwurf():
          if (geaendert) {
            await _trainings.speichere(_alsEntwurf(inhalt, _kennung));
            _geschrieben = true;
          } else if (_geschrieben) {
            // Zurückgeändert: Die Zeile bleibt (Spec 27 Nr. 3) und trägt
            // wieder den gespeicherten Stand.
            await _trainings.speichere(_alsEntwurf(_ausgang, _kennung));
            _geschrieben = false;
          } else {
            return;
          }
      }
    } on Object {
      return;
    }
    _sageEs();
  });

  /// Die Übersicht liest dieselbe Ablage: Sie muss erfahren, dass sich
  /// etwas geändert hat (Spec 6.3). Nach dem Entsorgen des Containers gibt es
  /// niemanden mehr, der es erfahren müsste.
  void _sageEs() {
    try {
      _container
        ..invalidate(gymTrainingsQuelleProvider)
        ..invalidate(gymTrainingProvider(_kennung));
      switch (quelle) {
        case GymEditorBearbeite(:final id):
          _container.invalidate(gymTrainingProvider(id));
        case GymEditorEntwurf(:final id):
          _container.invalidate(gymTrainingProvider(id));
        case GymEditorNeu() || GymEditorKopie():
          break;
      }
    } on Object {
      // Container entsorgt.
    }
  }

  // --- Verwerfen, Speichern, Löschen ----------------------------------------

  /// „Verwerfen": wirft den Stand weg **und löscht auch den gesicherten**.
  /// Danach schreibt nichts mehr — weder die Wartezeit noch ein Auftrag aus
  /// der Zeit davor.
  Future<void> verwirf() async {
    await _bereit;
    _timer?.cancel();
    _timer = null;
    _epoche++;
    _abgeschlossen = true;
    if (!_darfSchreiben) return;
    await _nacheinander(() async {
      try {
        // `verwirfEntwurf` fasst nie ein fertiges Training oder ein Template
        // an: Bei `bearbeite` geht nur der Zwischenstand.
        await _trainings.verwirfEntwurf(_kennung);
      } on Object {
        return;
      }
      _sageEs();
    });
  }

  /// „Speichern": legt ein **fertiges Eigenes** an (oder ersetzt das
  /// bearbeitete vollständig) und löscht den Entwurf. Aus, solange
  /// `probleme` nicht leer ist.
  Future<GymEditorErgebnis> speichere() async {
    await _bereit;
    if (!_gelesen ||
        !_darfSchreiben ||
        _abgeschlossen ||
        state.laedt ||
        state.probleme.isNotEmpty) {
      return GymEditorErgebnis.nichtSpeicherbar;
    }
    _timer?.cancel();
    _timer = null;
    final epoche = ++_epoche;
    final inhalt = _inhalt;

    final ergebnis = await _nacheinander<GymEditorErgebnis>(() async {
      try {
        switch (quelle) {
          case GymEditorNeu() || GymEditorKopie() || GymEditorEntwurf():
            await _trainings.speichere(
              WorkoutDefinition(
                id: _kennung,
                name: inhalt.name.trim(),
                category: WorkoutCategory.own,
                tags: inhalt.tags,
                exercises: inhalt.exercises,
                enteredMinutes: inhalt.enteredMinutes,
              ),
            );
          case GymEditorBearbeite(:final id):
            await _trainings.speichereZwischenstand(
              _alsEntwurf(
                WorkoutDefinition(
                  id: _kennung,
                  name: inhalt.name.trim(),
                  category: WorkoutCategory.own,
                  tags: inhalt.tags,
                  exercises: inhalt.exercises,
                  enteredMinutes: inhalt.enteredMinutes,
                ),
                _kennung,
              ),
              von: id,
            );
            _geschrieben = true;
            try {
              await _trainings.uebernimmZwischenstand(_kennung);
            } on StateError {
              // Spec 4.7: Die Erfassung trägt das Training. Der
              // Zwischenstand bleibt gesichert, das Training unverändert.
              return GymEditorErgebnis.gesperrt;
            }
        }
      } on StateError {
        return GymEditorErgebnis.gesperrt;
      } on Object {
        return GymEditorErgebnis.fehlgeschlagen;
      }
      return GymEditorErgebnis.gespeichert;
    });

    if (ergebnis == GymEditorErgebnis.gespeichert) {
      _abgeschlossen = true;
      _geschrieben = false;
      _sageEs();
    } else if (epoche == _epoche && !_entsorgt) {
      // Nichts geschrieben: Die Selbstsicherung läuft weiter.
      _planeSicherung();
    }
    return ergebnis;
  }

  /// „Training löschen" — nur bei `bearbeite`. Das Eigene ist weg, samt
  /// Zwischenstand und Rotationsplatz; eingetragene Sitzungen bleiben
  /// (Spec 4.6). Gesperrt, solange die Erfassung es trägt.
  Future<GymLoeschErgebnis> loesche() async {
    final q = quelle;
    if (q is! GymEditorBearbeite) return GymLoeschErgebnis.fehlgeschlagen;
    await _bereit;
    if (!_gelesen || !_darfSchreiben || _abgeschlossen) {
      return GymLoeschErgebnis.fehlgeschlagen;
    }
    _timer?.cancel();
    _timer = null;
    final epoche = ++_epoche;
    GymLoeschErgebnis ergebnis;
    try {
      await _nacheinander(() => _trainings.loesche(q.id));
      ergebnis = GymLoeschErgebnis.geloescht;
    } on StateError {
      ergebnis = GymLoeschErgebnis.laeuft;
    } on Object {
      ergebnis = GymLoeschErgebnis.fehlgeschlagen;
    }
    if (ergebnis == GymLoeschErgebnis.geloescht) {
      _abgeschlossen = true;
      _geschrieben = false;
      try {
        _container
          ..invalidate(gymTrainingsQuelleProvider)
          ..invalidate(gymRotationQuelleProvider)
          ..invalidate(gymTrainingProvider(q.id))
          ..invalidate(gymTrainingProvider(_kennung));
      } on Object {
        // Container entsorgt.
      }
    } else if (epoche == _epoche && !_entsorgt && state.geaendert) {
      _planeSicherung();
    }
    return ergebnis;
  }
}

/// Welche Muskeln die Übungen des Editors **gerade** treffen
/// (`WorkoutMuscles.trained`, Spec 28 Nr. 3, #554) — für die Muskelfigur.
///
/// **Gehalten, nicht je Bild gerechnet** (Fehler `03`): Der Provider hört nur
/// auf einen Schlüssel aus Übung und Sätzen. Tippen im Namensfeld, Tags und
/// Dauer ändern den Stand, aber nicht diesen Schlüssel — gerechnet wird dann
/// nicht, und die Figur baut sich nicht neu.
///
/// Leer, solange nichts gelesen ist oder keine Übung drin ist: Ein leerer
/// Stand färbt nichts und behauptet nichts.
final gymEditorMuskelnProvider = Provider.autoDispose
    .family<Set<Muscle>, GymEditorQuelle>((ref, quelle) {
      ref.watch(
        gymEditorProvider(quelle).select(
          (s) =>
              [for (final e in s.uebungen) '${e.exerciseId}:${e.sets}']
                  .join('|'),
        ),
      );
      return WorkoutMuscles.trained(
        ref.read(gymEditorProvider(quelle)).uebungen,
      );
    });
