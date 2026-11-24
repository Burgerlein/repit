// Die Ablage der eigenen Trainings (Schema v25, #532 unter #531): Lesen,
// Speichern, Kopie, Löschen (Tombstone), Zwischenstand des Editors, die
// gespeicherte Rotation und die Startbefüllung. Die Tabellen liegen in
// `gym_training_tabellen.dart`, die Migration in `cache.dart`.
//
// API und Vertrag sind durch `app/test/data/gym_training_repository_test.dart`,
// `gym_training_rotation_test.dart`, `gym_training_zwischenstand_test.dart`
// und `schema_v25_test.dart` verbindlich vorgegeben (siehe deren Dateiköpfe) —
// diese Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`).
// Spec: `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
// Abschnitt 4 und 6 und die Nachträge 22 bis 25.
//
// Derselbe Schnitt wie `GymRepository`: SQL hier, Riverpod nebenan.
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.** Das
// sind Tims eigene Daten; leer heißt leer, und es gibt keinen Lauf, der leer
// ausgehen könnte.
//
// **Gefiltert wird in SQL** (Entwürfe, Tombstones), nie nach dem Laden in
// Dart (Hausregel 2).
//
// **Die Reihenfolge hängt nie an der Zeilenfolge der Abfrage.** Übungen und
// Tags werden nach `pos` gelesen, die Trainings nach Kategorie, `reihenfolge`
// und `id`.
//
// **Geschrieben wird je Training in einer Transaktion**: Zeile, Übungen und
// Tags ersetzen einander vollständig, und es gibt keinen Zwischenzustand mit
// doppelter `pos`, den `UNIQUE (training_id, pos)` ablehnen müsste. Eine
// Rotation, die auf ein gelöschtes Training zeigt, gibt es nie — Löschen nimmt
// das Training in derselben Transaktion heraus (Spec 24 Nr. 1).
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart' show appCacheProvider;
import 'cache.dart';

class GymTrainingRepository {
  GymTrainingRepository(this._db);

  final AppCache _db;

  // --- Lesen -------------------------------------------------------------

  /// Alle lebenden Trainings (nicht gelöscht), Templates zuerst, je Kategorie
  /// nach `reihenfolge`, dann nach `id`. [mitEntwuerfen] `false` lässt
  /// Entwürfe und Zwischenstände weg.
  Future<List<WorkoutDefinition>> alle({bool mitEntwuerfen = true}) => _lese(
    mitEntwuerfen ? 't.geloescht = 0' : 't.geloescht = 0 AND t.ist_entwurf = 0',
  );

  /// Das lebende Training, `null` wenn es keines gibt oder es gelöscht ist.
  /// Ein Entwurf ist ein lebendes Training.
  Future<WorkoutDefinition?> training(String id) async {
    final gelesen = await _lese('t.geloescht = 0 AND t.id = ?', [
      Variable<String>(id),
    ]);
    return gelesen.isEmpty ? null : gelesen.single;
  }

  /// Auch ein Tombstone — nur für die Namensauflösung und
  /// [spieleTemplatesEin].
  Future<WorkoutDefinition?> trainingAuchGeloescht(String id) async {
    final gelesen = await _lese('t.id = ?', [Variable<String>(id)]);
    return gelesen.isEmpty ? null : gelesen.single;
  }

  /// Benutzte Tags mit ihrer Häufigkeit: die Tags lebender Trainings.
  /// **Entwürfe zählen mit, Tombstones nicht.**
  Future<Map<String, int>> benutzteTags() async {
    final zeilen = await _db
        .customSelect(
          'SELECT g.tag AS tag, COUNT(*) AS n FROM gym_training_tags g '
          'JOIN gym_trainings t ON t.id = g.training_id '
          'WHERE t.geloescht = 0 GROUP BY g.tag;',
        )
        .get();
    return {for (final z in zeilen) z.read<String>('tag'): z.read<int>('n')};
  }

  /// Die Kennungen der Rotation in der Reihenfolge der Plätze — **ohne
  /// Entwürfe und ohne Tombstones** (Spec 14.1: nicht einplanbar).
  ///
  /// **Eine Kennung, zu der es überhaupt keine Zeile gibt, wird
  /// durchgereicht**, nicht verschluckt: In dieser Stufe schreibt nur die
  /// Einspielung die Rotation, und eine unbekannte Kennung ist ein
  /// Programmierfehler, den der Provider sichtbar machen soll (Spec 24 Nr. 4).
  /// Verschwiegen würde er zu einer Rotation, die still kürzer ist, als sie
  /// ist.
  Future<List<String>> rotation() async {
    final zeilen = await _db
        .customSelect(
          'SELECT r.training_id AS training_id FROM gym_rotation r '
          'LEFT JOIN gym_trainings t ON t.id = r.training_id '
          'WHERE t.id IS NULL OR (t.geloescht = 0 AND t.ist_entwurf = 0) '
          'ORDER BY r.pos;',
        )
        .get();
    return [for (final z in zeilen) z.read<String>('training_id')];
  }

  /// Der Zwischenstand, der an [trainingId] hängt, oder `null`.
  Future<WorkoutDefinition?> zwischenstandVon(String trainingId) async {
    final gelesen = await _lese('t.geloescht = 0 AND t.entwurf_von = ?', [
      Variable<String>(trainingId),
    ]);
    return gelesen.isEmpty ? null : gelesen.single;
  }

  /// Die Kennungen aller lebenden **Zwischenstände** — der Zeilen, die an
  /// einem bestehenden Training hängen (`entwurf_von`). Gefiltert in SQL.
  ///
  /// Die Übersicht zeigt als Entwurfs-Kacheln nur **freie** Entwürfe (Spec 27
  /// Nr. 2): Ein Zwischenstand und sein Training wären zwei Kacheln für
  /// dieselbe Sache. [alle] liefert ihn weiter mit — wer die Kacheln baut,
  /// nimmt ihn mit dieser Menge heraus.
  Future<Set<String>> zwischenstandKennungen() async {
    final zeilen = await _db
        .customSelect(
          'SELECT id FROM gym_trainings '
          'WHERE geloescht = 0 AND entwurf_von IS NOT NULL;',
        )
        .get();
    return {for (final z in zeilen) z.read<String>('id')};
  }

  // --- Schreiben ---------------------------------------------------------

  /// Legt an oder ersetzt: Zeile, Übungen und Tags **vollständig**, in einer
  /// Transaktion.
  ///
  /// Wirft [ArgumentError] bei einem Verstoß gegen `WorkoutRules` (ein Entwurf
  /// wird nur auf seine Gestalt geprüft, ein fertiges Training braucht Namen
  /// und eine Übung) und [StateError], wenn
  ///
  /// - die Kategorie `template` ist — **der einzige Schreiber von Templates
  ///   ist [spieleTemplatesEin]** (Spec 4.5, 26 Nr. 1) —,
  /// - unter dieser Kennung ein Template steht (ein Eigenes darf es nicht
  ///   überschreiben),
  /// - ein Entwurf ein **fertiges** Training ersetzen würde (dafür gibt es
  ///   [speichereZwischenstand]: Sonst verschwände es aus der Rotation und
  ///   aus der Liste der startbaren Trainings),
  /// - die Erfassung dieses Training trägt (Spec 4.7: Ein Speichern, das eine
  ///   Übung entfernt, ließe dort eingetippte Sätze verschwinden).
  ///
  /// Ein neues Eigenes bekommt `reihenfolge = max(Eigene) + 1`, ein
  /// bestehendes behält seine. **Die Rotation fasst die Methode nie an.**
  ///
  /// `increment` wird geschrieben und gelesen, wie es ist: Die Spalte
  /// `steigerung` ist der Platz für #537, und eine Ablage, die einen Wert
  /// beim Rundweg still verwürfe, behauptete etwas anderes, als sie tut.
  /// Der Editor erzeugt bis dahin keinen.
  Future<void> speichere(WorkoutDefinition definition) async {
    if (definition.category == WorkoutCategory.template) {
      throw StateError(
        'Templates schreibt nur die Einspielung (${definition.id}); '
        'wer ein Template ändern will, speichert eine Kopie',
      );
    }
    _pruefe(definition);

    await _db.transaction(() async {
      final vorhanden = await _zeile(definition.id);
      if (vorhanden != null &&
          vorhanden.kategorie == WorkoutCategory.template.code) {
        throw StateError('Die Kennung ${definition.id} gehört einem Template');
      }
      if (vorhanden != null && !vorhanden.entwurf && definition.isDraft) {
        throw StateError(
          'Ein Entwurf ersetzt kein fertiges Training (${definition.id}); '
          'ein Zwischenstand an einem bestehenden Training heißt '
          '`speichereZwischenstand`',
        );
      }
      await _pruefeSperre(definition.id);

      await _schreibe(
        definition,
        reihenfolge: vorhanden?.reihenfolge ?? await _naechsteReihenfolge(),
        // Ein Zwischenstand bleibt an seinem Training hängen, auch wenn er
        // über diesen Weg erneut gesichert wird; ein fertiges Training hängt
        // an keinem.
        entwurfVon: definition.isDraft ? vorhanden?.entwurfVon : null,
      );
    });
  }

  /// Die Kopie nach Spec 4.5, **sofort abgelegt**, und zurückgegeben: ein
  /// neues Eigenes unter [neueId], Name `'… (Kopie)'`, Tags, Übungen und
  /// eingetragene Dauer des Originals.
  ///
  /// Wirft [StateError], wenn es [vonId] nicht (mehr) gibt, und
  /// [ArgumentError], wenn [neueId] schon vergeben ist — das hieße, ein
  /// anderes Training zu überschreiben. Der Editor legt die Kopie erst beim
  /// Speichern an (`copyAsOwn` allein legt nichts ab); diese Methode ist der
  /// Weg für alles, was die Kopie sofort braucht.
  Future<WorkoutDefinition> kopiereAlsEigenes(
    String vonId, {
    required String neueId,
  }) => _db.transaction(() async {
    final original = await training(vonId);
    if (original == null) {
      throw StateError('Es gibt kein Training $vonId, das sich kopieren ließe');
    }
    if (await _zeile(neueId) != null) {
      throw ArgumentError.value(
        neueId,
        'neueId',
        'Die Kennung ist schon vergeben',
      );
    }
    final kopie = original.copyAsOwn(id: neueId);
    _pruefe(kopie);
    await _schreibe(
      kopie,
      reihenfolge: await _naechsteReihenfolge(),
      entwurfVon: null,
    );
    return kopie;
  });

  /// Löscht ein **Eigenes** oder einen Entwurf: Zeile, Übungen und Tags werden
  /// **wirklich entfernt**, ebenso der Zwischenstand, der an einem Eigenen
  /// hängt (sonst bliebe eine Geisterkachel „Änderung an X" für ein X, das es
  /// nicht mehr gibt). Unbekannt: nichts.
  ///
  /// **Templates sind nicht löschbar** (Spec 26 Nr. 1): Die Methode wirft dort
  /// [StateError], wie [speichere], und ändert nichts — weder Zeile noch
  /// Rotation. Die Tombstone-Spalte `geloescht` bleibt im Schema, es gibt nur
  /// keinen Weg mehr, sie zu setzen.
  ///
  /// Das Training verlässt **in derselben Transaktion** die Rotation, und die
  /// Plätze rücken ohne Lücke nach (Spec 24 Nr. 1, Plan 17). Ein Training, das
  /// nicht eingeplant ist, lässt die Rotation unberührt.
  ///
  /// Wirft außerdem [StateError], wenn die Erfassung dieses Training trägt
  /// (Spec 4.7); dann ändert sich nichts, auch nicht die Rotation. Der Verlauf
  /// hängt an keiner Zeile und bleibt unverändert (Spec 4.6).
  Future<void> loesche(String id) => _db.transaction(() async {
    final zeile = await _zeile(id);
    if (zeile == null) return;
    if (zeile.kategorie == WorkoutCategory.template.code) {
      throw StateError('Templates sind nicht löschbar ($id)');
    }
    await _pruefeSperre(id);

    final zwischenstaende = await _db
        .customSelect(
          'SELECT id FROM gym_trainings WHERE entwurf_von = ?;',
          variables: [Variable<String>(id)],
        )
        .get();
    for (final z in zwischenstaende) {
      await _entferne(z.read<String>('id'));
    }
    await _entferne(id);
    await _nimmAusRotation(id);
  });

  /// Verwirft einen Entwurf oder Zwischenstand: Zeile, Übungen, Tags. Eine
  /// unbekannte Kennung ändert nichts. **Ein fertiges Training und ein
  /// Template werden nie angefasst** — die Methode tut dort nichts. Die
  /// Rotation steht nie in Frage: Ein Entwurf ist nie darin.
  Future<void> verwirfEntwurf(String id) => _db.transaction(() async {
    final zeile = await _zeile(id);
    if (zeile == null || !zeile.entwurf) return;
    await _entferne(id);
  });

  /// Sichert [stand] als **Zwischenstand** an dem bestehenden Training [von]
  /// (Spec 22 Nr. 3): Zeile mit `ist_entwurf = 1` und `entwurf_von = von`.
  /// [WorkoutDefinition.id] des [stand] ist die Kennung der **Entwurfszeile**,
  /// nicht [von]. Das Training [von] ändert sich nicht. Ein zweiter
  /// Zwischenstand für dasselbe [von] **ersetzt** den ersten samt dessen
  /// Übungen und Tags.
  ///
  /// Ein Zwischenstand darf unfertig sein (Name leer, keine Übung). Wirft
  /// [ArgumentError], wenn [stand] kein Entwurf ist oder gegen die Gestalt
  /// verstößt, und [StateError], wenn [von] kein lebendes **eigenes**
  /// Training ist (ein Template öffnet den Editor nie direkt, Spec 4.5) oder
  /// die Kennung des [stand] einem anderen Training gehört.
  ///
  /// Die Erfassung sperrt hier nicht: Der Zwischenstand ändert das Training
  /// nicht. Erst [uebernimmZwischenstand] tut es.
  Future<void> speichereZwischenstand(
    WorkoutDefinition stand, {
    required String von,
  }) async {
    if (!stand.isDraft) {
      throw ArgumentError.value(
        stand,
        'stand',
        'Ein Zwischenstand ist ein Entwurf (isDraft)',
      );
    }
    if (stand.category != WorkoutCategory.own) {
      throw StateError('Ein Zwischenstand ist ein eigenes Training');
    }
    _pruefe(stand);

    await _db.transaction(() async {
      final ziel = await _zeile(von);
      if (ziel == null ||
          ziel.geloescht ||
          ziel.kategorie != WorkoutCategory.own.code) {
        throw StateError(
          'Ein Zwischenstand hängt an einem eigenen Training; $von ist keins',
        );
      }
      // Der bisherige Zwischenstand geht, auch unter anderer Kennung.
      final bisherige = await _db
          .customSelect(
            'SELECT id FROM gym_trainings WHERE entwurf_von = ?;',
            variables: [Variable<String>(von)],
          )
          .get();
      for (final z in bisherige) {
        await _entferne(z.read<String>('id'));
      }
      if (await _zeile(stand.id) != null) {
        throw StateError(
          'Die Kennung ${stand.id} gehört einem anderen Training',
        );
      }
      await _schreibe(
        stand,
        reihenfolge: await _naechsteReihenfolge(),
        entwurfVon: von,
      );
    });
  }

  /// „Speichern" beim Bearbeiten: Der Inhalt des Zwischenstands [entwurfId]
  /// ersetzt das Training, an dem er hängt, **vollständig** (Name, Tags,
  /// Übungen, eingetragene Dauer). Das Training behält Kennung und
  /// `reihenfolge` — und seinen Platz in der Rotation — und ist danach
  /// fertig; die Entwurfszeile samt Übungen und Tags ist weg. Alles in einer
  /// Transaktion.
  ///
  /// Wirft [ArgumentError], wenn der **fertige** Stand gegen `WorkoutRules`
  /// verstößt (Name und mindestens eine Übung sind jetzt Pflicht; nichts
  /// ändert sich), und [StateError], wenn [entwurfId] kein Zwischenstand ist,
  /// sein Training nicht mehr da ist oder die Erfassung es trägt (Spec 4.7).
  Future<void> uebernimmZwischenstand(String entwurfId) => _db.transaction(
    () async {
      final entwurfZeile = await _zeile(entwurfId);
      final von = entwurfZeile?.entwurfVon;
      if (entwurfZeile == null || von == null) {
        throw StateError('$entwurfId ist kein Zwischenstand');
      }
      final ziel = await _zeile(von);
      if (ziel == null ||
          ziel.geloescht ||
          ziel.kategorie != WorkoutCategory.own.code) {
        throw StateError(
          'Das Training $von, an dem der Zwischenstand hängt, gibt es '
          'nicht mehr',
        );
      }
      final stand = (await _lese('t.id = ?', [
        Variable<String>(entwurfId),
      ])).single;
      final fertig = WorkoutDefinition(
        id: von,
        name: stand.name,
        category: WorkoutCategory.own,
        tags: stand.tags,
        exercises: stand.exercises,
        enteredMinutes: stand.enteredMinutes,
      );
      _pruefe(fertig);
      await _pruefeSperre(von);

      await _entferne(entwurfId);
      await _schreibe(fertig, reihenfolge: ziel.reihenfolge, entwurfVon: null);
    },
  );

  // --- Startbefüllung ----------------------------------------------------

  /// Legt **jedes Template an, dessen `id` in der Tabelle weder lebt noch
  /// einen Tombstone trägt** (`WorkoutTemplates.missing`, Spec 4.3) — und
  /// **fasst nie eine vorhandene Zeile an**: nicht den Namen, nicht die
  /// Dauer, nicht Übungen oder Tags. Ein Tombstone kommt nie zurück.
  ///
  /// Läuft in `AppCache.beforeOpen`, in einer Transaktion, und ist
  /// idempotent. Sie braucht keine Uhr — deshalb darf sie dort stehen.
  Future<void> spieleTemplatesEin() => _db.transaction(() async {
    final bekannte = await _db
        .customSelect('SELECT id FROM gym_trainings;')
        .get();
    final fehlende = WorkoutTemplates.missing({
      for (final z in bekannte) z.read<String>('id'),
    });
    for (final template in fehlende) {
      await _schreibe(
        template,
        // Der Platz in der Startbefüllung, ab 1 (Spec 4.1).
        reihenfolge:
            WorkoutTemplates.all.indexWhere((t) => t.id == template.id) + 1,
        entwurfVon: null,
      );
    }
  });

  /// Der Merker „die Startrotation ist einmal eingespielt": **`PRAGMA
  /// application_id` der Datenbankdatei** — der ASCII-Text „GYMR".
  ///
  /// **Warum dort und nirgends sonst.** Löschen kann die Rotation leeren, und
  /// „füllen, wenn leer" erweckte Gelöschtes beim nächsten Öffnen wieder —
  /// dasselbe Muster wie der Template-Tombstone, nur ohne eine Zeile, an der
  /// er hängen könnte (Spec 24 Nr. 3). Der Merker gehört deshalb in die
  /// **Datei**, nicht in die Rotation: Er überlebt jede Veränderung der
  /// Rotation, wandert wie die Tabellen mit dem iCloud-Gerätebackup und
  /// braucht — wie die Migrationstests es fixieren (Spec 25 Nr. 3) — weder
  /// eine fünfte Tabelle noch eine Spalte in einer bestehenden, die die
  /// Abgleichsprüfung (`schema_v25_test.dart`) als fremd meldete.
  ///
  /// `application_id` ist ein 32-Bit-Wert im Kopf der SQLite-Datei, den SQLite
  /// selbst nie liest und den in diesem Repository niemand sonst benutzt
  /// (Stand 19.11.2026). Er wird mit der Rotation in **einer Transaktion**
  /// gesetzt. **Die Ablage ist eine Folgerung des Bauens, nicht von Tim
  /// entschieden.** Nimmt später jemand `application_id` für etwas anderes,
  /// muss der Merker umziehen — sonst gälte die Startrotation auf jedem Gerät
  /// als nicht eingespielt und füllte eine geleerte Rotation wieder.
  static const int rotationMerker = 0x47594D52;

  /// Spielt die Startrotation ein — **einmal je Installation**, nicht bei
  /// jedem Öffnen (Spec 24 Nr. 3).
  ///
  /// - Ist der Merker gesetzt: nichts.
  /// - Sonst, bei **leerer** Rotation: die Kennungen von
  ///   `WorkoutTemplates.initialRotation` in dieser Reihenfolge, Plätze ab 1
  ///   — **nur die, deren Template lebt und kein Entwurf ist**. Ein Template
  ///   mit Tombstone kommt nie hinein, auf keinem Weg (Spec 25 Nr. 3), und die
  ///   Plätze bleiben ohne Lücke.
  /// - Sonst (eine Rotation ist schon da, etwa von einem anderen Zweig
  ///   angelegt): **die Einspielung ergänzt nichts** und fasst keine Zeile an.
  /// - In jedem Fall setzt sie danach den Merker.
  ///
  /// Muss **nach** [spieleTemplatesEin] laufen: Die Rotation verweist auf die
  /// Templates. Idempotent.
  Future<void> spieleRotationEin() => _db.transaction(() async {
    final merker = await _db.customSelect('PRAGMA application_id;').getSingle();
    if (merker.read<int>('application_id') == rotationMerker) return;

    final schonDa = await _db
        .customSelect('SELECT COUNT(*) AS n FROM gym_rotation;')
        .getSingle();
    if (schonDa.read<int>('n') == 0) {
      final lebende = {
        for (final z
            in await _db
                .customSelect(
                  'SELECT id FROM gym_trainings '
                  'WHERE geloescht = 0 AND ist_entwurf = 0;',
                )
                .get())
          z.read<String>('id'),
      };
      var pos = 1;
      for (final id in WorkoutTemplates.initialRotation) {
        if (!lebende.contains(id)) continue;
        await _db.customStatement(
          'INSERT INTO gym_rotation (pos, training_id) VALUES (?, ?);',
          [pos++, id],
        );
      }
    }
    await _db.customStatement('PRAGMA application_id = $rotationMerker;');
  });

  // --- Innenleben --------------------------------------------------------

  /// Wirft [ArgumentError] bei einem Verstoß gegen `WorkoutRules` und bei
  /// leerer Kennung — bevor irgendetwas geschrieben wird.
  void _pruefe(WorkoutDefinition definition) {
    if (definition.id.isEmpty) {
      throw ArgumentError.value(definition.id, 'id', 'Die Kennung ist leer');
    }
    final probleme = WorkoutRules.check(definition);
    if (probleme.isNotEmpty) {
      throw ArgumentError.value(
        definition,
        'definition',
        'verstößt gegen die Regeln: ${probleme.join(', ')}',
      );
    }
  }

  /// Wirft [StateError], solange die Erfassung (`gym_entwuerfe`) dieses
  /// Training trägt (Spec 4.7). **Die Spalte `workout` trägt dort die
  /// Kennung**, bei einem Enum-Fall also auch `Push` — auch ein Template ist
  /// gesperrt, solange sein Training läuft.
  Future<void> _pruefeSperre(String id) async {
    final laeuft = await _db
        .customSelect(
          'SELECT 1 FROM gym_entwuerfe WHERE workout = ?;',
          variables: [Variable<String>(id)],
        )
        .get();
    if (laeuft.isNotEmpty) {
      throw StateError(
        'Das Training $id läuft gerade — erst abschließen oder verwerfen',
      );
    }
  }

  Future<_Zeile?> _zeile(String id) async {
    final z = await _db
        .customSelect(
          'SELECT kategorie, geloescht, ist_entwurf, reihenfolge, entwurf_von '
          'FROM gym_trainings WHERE id = ?;',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (z == null) return null;
    return _Zeile(
      kategorie: z.read<String>('kategorie'),
      geloescht: z.read<int>('geloescht') == 1,
      entwurf: z.read<int>('ist_entwurf') == 1,
      reihenfolge: z.read<int>('reihenfolge'),
      entwurfVon: z.read<String?>('entwurf_von'),
    );
  }

  /// Die nächste freie Zahl **unter den Eigenen**: größte vorhandene + 1,
  /// nicht Anzahl + 1 — ein gelöschtes Eigenes ließe sonst eine Zahl
  /// doppelt vergeben, und die Templates zählen nicht mit.
  Future<int> _naechsteReihenfolge() async {
    final z = await _db
        .customSelect(
          'SELECT COALESCE(MAX(reihenfolge), 0) + 1 AS n FROM gym_trainings '
          "WHERE kategorie = 'eigene';",
        )
        .getSingle();
    return z.read<int>('n');
  }

  /// Schreibt Zeile, Übungen und Tags **vollständig**: erst die Kinder weg,
  /// dann die Zeile angelegt oder ersetzt, dann die Kinder neu. Aufrufer
  /// stehen in einer Transaktion.
  Future<void> _schreibe(
    WorkoutDefinition d, {
    required int reihenfolge,
    required String? entwurfVon,
  }) async {
    await _entferneKinder(d.id);
    await _db
        .into(_db.gymTrainings)
        .insertOnConflictUpdate(
          GymTrainingsCompanion.insert(
            id: d.id,
            name: d.name,
            kategorie: d.category.code,
            dauerEingetragenMin: Value(d.enteredMinutes),
            istEntwurf: Value(d.isDraft),
            geloescht: const Value(false),
            reihenfolge: reihenfolge,
            entwurfVon: Value(entwurfVon),
          ),
        );
    for (var i = 0; i < d.exercises.length; i++) {
      final e = d.exercises[i];
      await _db
          .into(_db.gymTrainingUebungen)
          .insert(
            GymTrainingUebungenCompanion.insert(
              trainingId: d.id,
              pos: i + 1,
              uebungId: e.exerciseId,
              saetze: e.sets,
              wdhVon: e.repLow,
              wdhBis: e.repHigh,
              steigerung: Value(e.increment),
            ),
          );
    }
    for (var i = 0; i < d.tags.length; i++) {
      await _db
          .into(_db.gymTrainingTags)
          .insert(
            GymTrainingTagsCompanion.insert(
              trainingId: d.id,
              pos: i + 1,
              tag: d.tags[i],
            ),
          );
    }
  }

  Future<void> _entferneKinder(String id) async {
    await _db.customStatement(
      'DELETE FROM gym_training_uebungen WHERE training_id = ?;',
      [id],
    );
    await _db.customStatement(
      'DELETE FROM gym_training_tags WHERE training_id = ?;',
      [id],
    );
  }

  /// Entfernt Zeile, Übungen und Tags — **wirklich**, kein Tombstone.
  Future<void> _entferne(String id) async {
    await _entferneKinder(id);
    await _db.customStatement('DELETE FROM gym_trainings WHERE id = ?;', [id]);
  }

  /// Nimmt [id] aus der Rotation, **und die Plätze rücken ohne Lücke nach**.
  /// Steht [id] nicht darin, bleibt die Rotation unberührt.
  ///
  /// Neu nummeriert wird über Lesen und Neuschreiben statt über ein
  /// `UPDATE … SET pos = pos - 1`: Das träfe `PRIMARY KEY (pos)` je Zeile
  /// einzeln, und ob SQLite sie dabei in einer Reihenfolge anfasst, die keinen
  /// Platz zweimal belegt, ist keine Zusage.
  Future<void> _nimmAusRotation(String id) async {
    final vorher = await _db
        .customSelect('SELECT training_id FROM gym_rotation ORDER BY pos;')
        .get();
    final kennungen = [for (final z in vorher) z.read<String>('training_id')];
    if (!kennungen.contains(id)) return;

    await _db.customStatement('DELETE FROM gym_rotation;');
    var pos = 1;
    for (final kennung in kennungen) {
      if (kennung == id) continue;
      await _db.customStatement(
        'INSERT INTO gym_rotation (pos, training_id) VALUES (?, ?);',
        [pos++, kennung],
      );
    }
  }

  /// Liest die Trainings, auf die die Bedingung [wo] (über den Alias `t` für
  /// `gym_trainings`) passt — **gefiltert in SQL**. Übungen und Tags kommen
  /// über dieselbe Bedingung, nicht über eine `IN`-Liste, und nach `pos`
  /// sortiert, nie nach Zeilenfolge.
  Future<List<WorkoutDefinition>> _lese(
    String wo, [
    List<Variable> variables = const [],
  ]) async {
    final trainings = await _db
        .customSelect(
          'SELECT t.* FROM gym_trainings t WHERE $wo '
          "ORDER BY CASE t.kategorie WHEN 'template' THEN 0 ELSE 1 END, "
          't.reihenfolge, t.id;',
          variables: variables,
        )
        .get();
    if (trainings.isEmpty) return const [];

    final uebungen = await _db
        .customSelect(
          'SELECT u.* FROM gym_training_uebungen u '
          'JOIN gym_trainings t ON t.id = u.training_id WHERE $wo '
          'ORDER BY u.training_id, u.pos;',
          variables: variables,
        )
        .get();
    final tags = await _db
        .customSelect(
          'SELECT g.* FROM gym_training_tags g '
          'JOIN gym_trainings t ON t.id = g.training_id WHERE $wo '
          'ORDER BY g.training_id, g.pos;',
          variables: variables,
        )
        .get();

    final uebungenJe = <String, List<WorkoutExercise>>{};
    for (final z in uebungen) {
      (uebungenJe[z.read<String>('training_id')] ??= []).add(
        WorkoutExercise(
          exerciseId: z.read<String>('uebung_id'),
          sets: z.read<int>('saetze'),
          repLow: z.read<int>('wdh_von'),
          repHigh: z.read<int>('wdh_bis'),
          increment: z.read<double?>('steigerung'),
        ),
      );
    }
    final tagsJe = <String, List<String>>{};
    for (final z in tags) {
      (tagsJe[z.read<String>('training_id')] ??= []).add(z.read<String>('tag'));
    }

    return [
      for (final z in trainings)
        WorkoutDefinition(
          id: z.read<String>('id'),
          name: z.read<String>('name'),
          category: WorkoutCategory.fromCode(z.read<String>('kategorie'))!,
          tags: tagsJe[z.read<String>('id')] ?? const [],
          exercises: uebungenJe[z.read<String>('id')] ?? const [],
          enteredMinutes: z.read<int?>('dauer_eingetragen_min'),
          isDraft: z.read<int>('ist_entwurf') == 1,
        ),
    ];
  }
}

/// Was die Ablage über die Zeile eines Trainings wissen muss, ohne seine
/// Übungen zu lesen.
class _Zeile {
  const _Zeile({
    required this.kategorie,
    required this.geloescht,
    required this.entwurf,
    required this.reihenfolge,
    required this.entwurfVon,
  });

  final String kategorie;
  final bool geloescht;
  final bool entwurf;
  final int reihenfolge;
  final String? entwurfVon;
}

/// Die Brücke zum Riverpod-Baum — dieselbe Form wie `gymRepositoryProvider`.
final gymTrainingRepositoryProvider = Provider<GymTrainingRepository>(
  (ref) => GymTrainingRepository(ref.watch(appCacheProvider)),
);
