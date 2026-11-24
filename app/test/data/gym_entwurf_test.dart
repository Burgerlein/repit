// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';

/// Tests für den **Zwischenstand eines laufenden Trainings** (#78) — den
/// Entwurf.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die Tabelle
/// und ihre Migration prüft `schema_v18_test.dart`, die abgeschlossenen
/// Sitzungen `gym_ablage_test.dart`.
///
/// Geschrieben aus
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`
/// (Abschnitt 9 und 10.2) und Tims Entscheidungen vom 10.11.2026,
/// **ohne** den späteren Code gesehen zu haben.
///
/// Hier geht es **nicht** um die 1,5 Sekunden Wartezeit und nicht um den
/// Haken in der Leiste — beides ist Verhalten des Notifiers und gehört in
/// die Widget-Tests. Hier geht es um die Ablage darunter: Was übersteht
/// einen Neustart, was passiert bei einem zweiten Training, und was
/// passiert, wenn das Abschließen scheitert.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Ergänzt `lib/data/gym_repository.dart` (die übrige API steht im Kopf
/// von `gym_ablage_test.dart`):
///
/// ```dart
/// /// Der Zwischenstand eines angefangenen Trainings. Werttyp mit ==
/// /// und hashCode über alle Felder (Fehler `03`).
/// class GymEntwurf {
///   const GymEntwurf({
///     required this.workout,
///     required this.sitzungId,     // die UUID der künftigen Sitzung
///     required this.zeitpunkt,     // das eingestellte Datum, UTC
///     this.dauer,                  // roher Text, so wie getippt
///     this.notiz,
///     required this.gespeichertAm, // UTC
///     required this.felder,        // JSON-Text, roh
///   });
/// }
///
/// class GymRepository {
///   /// Der eine Entwurf, oder `null`.
///   Future<GymEntwurf?> entwurf();
///
///   /// Schreibt den Entwurf. Liegt bereits einer für ein **anderes**
///   /// Workout, wirft die Methode `StateError` und ändert nichts — die
///   /// Rückfrage stellt der Schirm, nicht die Ablage.
///   Future<void> speichereEntwurf(GymEntwurf entwurf);
///
///   /// Nimmt den Entwurf weg. Gibt es keinen, passiert nichts.
///   Future<void> verwirfEntwurf();
///
///   /// Legt die Sitzung ab **und** verwirft danach den Entwurf.
///   /// Scheitert das Ablegen, bleibt der Entwurf stehen und der Fehler
///   /// kommt heraus.
///   Future<void> schliesseAb(ImportedSession sitzung);
/// }
/// ```
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. Es gibt genau einen Entwurf** (Tim, 10.11.2026, Punkt 5: „Ein
/// Entwurf, nicht sieben. Wer ein zweites Training anfängt, bekommt eine
/// Rückfrage."). Das steht auch im Kern so: `GymDayPlanner.day` nimmt ein
/// einzelnes `GymDraft?`, und die Fokus-Karte kann nur einen zeigen.
///
/// **2. Ein zweiter überschreibt nicht stillschweigend.** Ein Entwurf für
/// ein anderes Workout wird abgewiesen, nicht ersetzt. Swifts
/// `ActiveTraining.refresh` nimmt bei mehreren willkürlich den ersten —
/// genau das soll nicht passieren. Wer wirklich wechseln will, verwirft
/// erst; so bleibt die Rückfrage dort, wo sie hingehört.
///
/// **3. Der Entwurf übersteht einen Neustart der App.** Geprüft, indem
/// dieselbe Datei geschlossen und neu geöffnet wird.
///
/// **4. Scheitert das Ablegen, bleibt der Entwurf stehen.** Die alte App
/// schluckt den Fehler und löscht ihn trotzdem
/// (`GymLogDraft.swift:288–290`); **das wird ausdrücklich nicht
/// portiert.** Das iPhone ist Tims einzige Kopie dieser Werte, und ein
/// verlorenes Training ist nicht wiederherstellbar.
///
/// Das beantwortet die **offene Frage 11** der Spec. Sie stand dort als
/// unentschieden; entschieden hat sie der Auftrag vom 10.11.2026.
/// **Gemeldet, nicht nebenbei entschieden.**
///
/// **5. Der Entwurf trägt rohen Text.** Er ist Schmierzettel, kein
/// Datensatz: „62,", „abc", ein halb getippter Wert. `dauer` und die
/// Satzzeilen in `felder` gehen unverändert hin und zurück.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`StateError` als Fehler für „es läuft schon ein anderes
///   Training".** Eine eigene Ausnahmeklasse wäre genauer zu fangen; für
///   eine Bedingung, die der Schirm vor dem Aufruf ohnehin prüft, ist sie
///   Aufwand ohne Gegenwert. Wer es anders sieht, soll es sagen.
/// - **`verwirfEntwurf` auf einer leeren Ablage ist kein Fehler.** Das
///   Verwerfen läuft nach dem Abschließen und nach „Training verwerfen",
///   und beides kann doppelt ankommen (der Debounce-Timer aus Abschnitt
///   3.6).
/// - **Dass das Ablegen scheitert, wird über eine Sitzung erzwungen, die
///   die Ablage ablehnt** — eine Übung ohne Satz, wie in
///   `gym_ablage_test.dart` festgelegt. Ein anderer Weg stünde dem
///   Test-Agenten nicht offen, ohne in den Code zu sehen.
///
/// **Alle Zahlen, Namen und Zeitpunkte sind erfunden**, im Jahr 2099.
void main() {
  // --- Hilfsmittel -------------------------------------------------------

  /// Die **eine** Stelle, an der der Name des Satz-Zeitpunkts steht —
  /// siehe den Kopf von `gym_ablage_test.dart`.
  CompletedSet satz(double gewichtKg, int wdh, [DateTime? um]) =>
      CompletedSet(weight: gewichtKg, reps: wdh, recordedAt: um);

  GymEntwurf entwurf({
    Workout workout = Workout.a,
    String sitzungId = 'pruef-uuid-1',
    DateTime? zeitpunkt,
    String? dauer = '70',
    String? notiz,
    DateTime? gespeichertAm,
    String felder =
        '{"pruef-bank":{"assist":false,'
        '"saetze":[{"kg":"62,5","wdh":"10"}]}}',
  }) => GymEntwurf(
    workout: workout,
    sitzungId: sitzungId,
    zeitpunkt: zeitpunkt ?? DateTime.utc(2099, 3, 2, 16, 30),
    dauer: dauer,
    notiz: notiz,
    gespeichertAm: gespeichertAm ?? DateTime.utc(2099, 3, 2, 16, 41, 12),
    felder: felder,
  );

  ({AppCache db, GymRepository repo}) frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return (db: db, repo: GymRepository(db));
  }

  /// Dieselbe Datei zweimal öffnen — der Neustart der App, ohne Gerät.
  ({Database datei, AppCache db, GymRepository repo}) aufDatei() {
    final datei = sqlite3.openInMemory();
    addTearDown(datei.close);
    final db = AppCache(
      NativeDatabase.opened(datei, closeUnderlyingOnClose: false),
    );
    return (datei: datei, db: db, repo: GymRepository(db));
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Hin und zurück', () {
    test('eine frische Ablage kennt keinen Entwurf', () async {
      final h = frisch();
      expect(await h.repo.entwurf(), isNull);
    });

    test('was geschrieben wird, kommt gleich zurück', () async {
      final h = frisch();
      final e = entwurf();
      await h.repo.speichereEntwurf(e);

      expect(await h.repo.entwurf(), e);
    });

    test('der rohe Text bleibt roh — der Entwurf ist Schmierzettel, kein '
        'Datensatz', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(
        entwurf(
          dauer: '7o',
          felder: '{"pruef-bank":{"saetze":[{"kg":"62,","wdh":"abc"}]}}',
        ),
      );

      final gelesen = await h.repo.entwurf();
      expect(gelesen!.dauer, '7o');
      expect(
        gelesen.felder,
        '{"pruef-bank":{"saetze":[{"kg":"62,","wdh":"abc"}]}}',
        reason:
            'was darin steht, ist noch nicht geprüft — eine Spalte '
            '`gewicht REAL` könnte es gar nicht aufnehmen (Spec 10.2)',
      );
    });

    test('eine fehlende Notiz bleibt `null` und wird nicht zur leeren '
        'Zeichenkette', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(entwurf(notiz: null, dauer: null));

      final gelesen = await h.repo.entwurf();
      expect(gelesen!.notiz, isNull);
      expect(gelesen.dauer, isNull);
    });

    test(
      'die Zeitpunkte kommen als UTC und gleich sich selbst zurück',
      () async {
        final h = frisch();
        // Kurz vor Mitternacht UTC: in Berlin schon der Folgetag.
        final datum = DateTime.utc(2099, 10, 24, 22, 30, 15, 123);
        final gespeichert = DateTime.utc(2099, 10, 24, 22, 41, 2, 7);
        await h.repo.speichereEntwurf(
          entwurf(zeitpunkt: datum, gespeichertAm: gespeichert),
        );

        final gelesen = await h.repo.entwurf();
        expect(gelesen!.zeitpunkt, datum);
        expect(gelesen.zeitpunkt.isUtc, isTrue);
        expect(gelesen.gespeichertAm, gespeichert);
        expect(gelesen.gespeichertAm.isUtc, isTrue);
      },
    );

    test('die Kennung der künftigen Sitzung wird mitgeführt', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(entwurf(sitzungId: 'pruef-uuid-42'));

      expect((await h.repo.entwurf())!.sitzungId, 'pruef-uuid-42');
    });
  });

  group('Ein Entwurf, nicht sieben', () {
    test(
      'zweimal dasselbe Workout: der zweite Stand ersetzt den ersten',
      () async {
        final h = frisch();
        await h.repo.speichereEntwurf(entwurf(dauer: '70'));
        await h.repo.speichereEntwurf(
          entwurf(dauer: '72', gespeichertAm: DateTime.utc(2099, 3, 2, 16, 45)),
        );

        final gelesen = await h.repo.entwurf();
        expect(gelesen!.dauer, '72');
        expect(
          await h.db.customSelect('SELECT * FROM gym_entwuerfe;').get(),
          hasLength(1),
          reason: 'alle 1,5 Sekunden eine Zeile ersetzen, keine anhängen',
        );
      },
    );

    test('ein Entwurf für ein anderes Workout wird abgewiesen, nicht '
        'stillschweigend überschrieben', () async {
      final h = frisch();
      final erster = entwurf(workout: Workout.a, sitzungId: 'pruef-uuid-1');
      await h.repo.speichereEntwurf(erster);

      await expectLater(
        () => h.repo.speichereEntwurf(
          entwurf(workout: Workout.c, sitzungId: 'pruef-uuid-2'),
        ),
        throwsStateError,
      );
      expect(
        await h.repo.entwurf(),
        erster,
        reason:
            '„Wer ein zweites Training anfängt, bekommt eine Rückfrage" '
            '(Tim, 10.11.2026). Die Rückfrage stellt der Schirm — die '
            'Ablage darf den ersten Stand nicht vorher wegwerfen',
      );
    });

    test('nach dem Verwerfen lässt sich das andere Workout anfangen', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(entwurf(workout: Workout.a));
      await h.repo.verwirfEntwurf();

      final zweiter = entwurf(workout: Workout.c, sitzungId: 'pruef-uuid-2');
      await h.repo.speichereEntwurf(zweiter);
      expect(await h.repo.entwurf(), zweiter);
    });

    test('die Datenbank selbst lässt keine zweite Zeile zu', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(entwurf());

      await expectLater(
        h.db.customInsert(
          'INSERT INTO gym_entwuerfe (workout, sitzung_id, zeitpunkt, '
          "gespeichert_am, felder) VALUES ('C', 'pruef-uuid-9', "
          "'2099-03-02T16:00:00.000Z', '2099-03-02T16:00:00.000Z', '{}');",
        ),
        throwsA(anything),
        reason:
            '„Ein Entwurf, nicht sieben" ist eine Eigenschaft der '
            'Datenbank und nicht nur eine Regel im Dart-Code — der '
            'Schlüssel `id` mit Vorgabe 0 lässt nur eine Zeile zu, '
            'dasselbe Muster wie `ziel_werte` und `stammdaten`',
      );
    });

    test('verwerfen, wo nichts ist, ist kein Fehler', () async {
      final h = frisch();
      await h.repo.verwirfEntwurf();
      await h.repo.verwirfEntwurf();
      expect(await h.repo.entwurf(), isNull);
    });
  });

  group('Der Entwurf übersteht einen Neustart', () {
    test('nach dem Schließen und Öffnen derselben Datei steht er wieder '
        'da', () async {
      final h = aufDatei();
      final e = entwurf();
      await h.repo.speichereEntwurf(e);
      await h.db.close();

      final zweiteSitzung = AppCache(
        NativeDatabase.opened(h.datei, closeUnderlyingOnClose: false),
      );
      addTearDown(zweiteSitzung.close);

      expect(
        await GymRepository(zweiteSitzung).entwurf(),
        e,
        reason:
            'ein angefangenes Training, das ein Kaltstart wegnimmt, wäre '
            'derselbe Verlust wie ein verlorenes abgeschlossenes',
      );
    });

    test(
      'ein verworfener Entwurf kommt nach dem Neustart nicht zurück',
      () async {
        final h = aufDatei();
        await h.repo.speichereEntwurf(entwurf());
        await h.repo.verwirfEntwurf();
        await h.db.close();

        final zweiteSitzung = AppCache(
          NativeDatabase.opened(h.datei, closeUnderlyingOnClose: false),
        );
        addTearDown(zweiteSitzung.close);

        expect(await GymRepository(zweiteSitzung).entwurf(), isNull);
      },
    );
  });

  group('Abschließen', () {
    ImportedSession fertige({String id = 'pruef-uuid-1'}) => ImportedSession(
      id: id,
      date: DateTime.utc(2099, 3, 2, 17, 30),
      workout: Workout.a,
      minutes: 70,
      note: null,
      exercises: [
        ImportedExercise(
          exerciseId: 'pruef-bank',
          sets: [satz(62.5, 10, DateTime.utc(2099, 3, 2, 16, 41))],
        ),
      ],
    );

    /// Eine Sitzung, die die Ablage ablehnt: eine Übung ohne Satz
    /// (`gym_ablage_test.dart`).
    ImportedSession unablegbare() => ImportedSession(
      id: 'pruef-uuid-1',
      date: DateTime.utc(2099, 3, 2, 17, 30),
      workout: Workout.a,
      minutes: 70,
      note: null,
      exercises: const [ImportedExercise(exerciseId: 'pruef-bank', sets: [])],
    );

    test(
      'die Sitzung steht danach in der Ablage und der Entwurf ist weg',
      () async {
        final h = frisch();
        await h.repo.speichereEntwurf(entwurf());

        await h.repo.schliesseAb(fertige());

        expect(await h.repo.sitzung('pruef-uuid-1'), isNotNull);
        expect(
          await h.repo.entwurf(),
          isNull,
          reason: 'ein abgeschlossenes Training ist kein laufendes mehr',
        );
      },
    );

    test('scheitert das Ablegen, bleibt der Entwurf stehen', () async {
      final h = frisch();
      final e = entwurf();
      await h.repo.speichereEntwurf(e);

      await expectLater(
        () => h.repo.schliesseAb(unablegbare()),
        throwsArgumentError,
      );

      expect(
        await h.repo.entwurf(),
        e,
        reason:
            'die alte App schluckt den Fehler und löscht den Entwurf '
            'trotzdem (GymLogDraft.swift:288–290). Das wird nicht '
            'portiert: Das iPhone ist Tims einzige Kopie dieser Werte',
      );
    });

    test('und es steht danach auch keine halbe Sitzung da', () async {
      final h = frisch();
      await h.repo.speichereEntwurf(entwurf());

      await expectLater(
        () => h.repo.schliesseAb(unablegbare()),
        throwsArgumentError,
      );

      expect(
        await h.repo.sitzungen(),
        isEmpty,
        reason: 'entweder ganz abgelegt oder gar nicht',
      );
    });

    test('abschließen ohne Entwurf geht trotzdem', () async {
      final h = frisch();
      await h.repo.schliesseAb(fertige());

      expect(await h.repo.sitzung('pruef-uuid-1'), isNotNull);
      expect(await h.repo.entwurf(), isNull);
    });

    test(
      'ein danach angefangenes Training sieht den alten Entwurf nicht',
      () async {
        final h = frisch();
        await h.repo.speichereEntwurf(entwurf());
        await h.repo.schliesseAb(fertige());

        final neuer = entwurf(
          workout: Workout.c,
          sitzungId: 'pruef-uuid-2',
          zeitpunkt: DateTime.utc(2099, 3, 5, 16, 30),
          gespeichertAm: DateTime.utc(2099, 3, 5, 16, 35),
        );
        await h.repo.speichereEntwurf(neuer);
        expect(await h.repo.entwurf(), neuer);
      },
    );
  });
}
