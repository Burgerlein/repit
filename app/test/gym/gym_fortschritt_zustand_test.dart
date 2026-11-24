import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/gym/gym_fortschritt_provider.dart';
import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;

import 'gym_fortschritt_support.dart'
    show FortschrittAblage, bank, idBank, idDips, morgens, sitzung, fJetzt;

/// Tests für den **Zustand** des Schirms „Fortschritt pro Übung" (#93) —
/// `lib/gym/gym_fortschritt_provider.dart`. Die Oberfläche darüber steht in
/// `gym_fortschritt_view_test.dart` und `gym_fortschritt_leerzustaende_test.dart`.
///
/// Grundlage: `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`,
/// Abschnitte 4 bis 6. Die festgelegte API steht im Kopf von
/// `gym_fortschritt_support.dart`.
///
/// ## Worauf diese Datei zielt
///
/// **Kein `Messwert<T>`**: Die Trainings sind Tims eigene Daten
/// (`CLAUDE.md`). Aber auch hier gilt: Zwischen dem Öffnen und dem
/// Eintreffen der Antwort liegt ein Lesevorgang, und in diesem Moment darf
/// **nicht** „keine Trainings" und **nicht** „Erstes Mal" gelten (Fehler
/// `01`). Der Zustand trägt deshalb `laedt` und `fehlgeschlagen`, und
/// `vorschlag` ist in beiden Fällen `null` statt `FirstTime`.
///
/// **Gehalten, nicht gerechnet** (Fehler `03`): zwei Lesungen geben dieselbe
/// Instanz; und ein Neulesen mit gleichem Inhalt gibt einen **gleichen**
/// Wert, damit nichts, was daran hängt, neu rechnet.
///
/// **Ein Nachlauf nimmt keinen sichtbaren Wert weg:** Wird neu gelesen
/// (`ref.invalidate(gymSitzungenProvider)` — so macht es
/// `GymLogNotifier.schliesseAb`), steht der alte Stand weiter da, bis der
/// neue eintrifft; scheitert der Nachlauf, bleibt er stehen.
///
/// Alle Daten sind erfunden.
void main() {
  late AppCache db;
  late FortschrittAblage ablage;
  late GymRepository schreiber;
  late ProviderContainer container;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    ablage = FortschrittAblage(db);
    schreiber = GymRepository(db);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        gymRepositoryProvider.overrideWithValue(ablage),
        clockProvider.overrideWithValue(() => fJetzt),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Hält den Zustand am Leben und lässt die Ablage antworten.
  Future<GymFortschritt> lies(String uebungId) async {
    final abo = container.listen(gymFortschrittProvider(uebungId), (_, _) {});
    addTearDown(abo.close);
    await pumpEventQueue(times: 200);
    return abo.read();
  }

  Future<void> lege(List<ImportedSession> liste) async {
    for (final s in liste) {
      await schreiber.legeAb(s);
    }
  }

  group('Vor der Antwort', () {
    test(
      '„noch nicht gelesen" ist kein „nichts da" und kein „Erstes Mal"',
      () async {
        ablage.tor = Completer<void>();
        final abo = container.listen(gymFortschrittProvider(idBank), (_, _) {});
        addTearDown(abo.close);
        await pumpEventQueue(times: 50);

        final z = abo.read();
        expect(z.laedt, isTrue);
        expect(z.fehlgeschlagen, isFalse);
        expect(z.bekannt, isFalse);
        expect(
          z.vorschlag,
          isNull,
          reason:
              '`Progression.suggest` gäbe mit leerem Verlauf `FirstTime` — '
              'während des Ladens wäre das eine Aussage über Trainings, die '
              'vielleicht da sind (Fehler `01`)',
        );
        expect(z.reihe, isEmpty);
        expect(z.plateau, isFalse);

        ablage.tor!.complete();
      },
    );

    test('der Zustand kennt die Übung auch beim Laden', () async {
      ablage.tor = Completer<void>();
      final abo = container.listen(gymFortschrittProvider(idDips), (_, _) {});
      addTearDown(abo.close);
      await pumpEventQueue(times: 50);

      expect(abo.read().uebung, ExerciseCatalog.all[idDips]);
      ablage.tor!.complete();
    });
  });

  group('Ohne Trainings', () {
    test('bekannt, leer, mit dem Vorschlag „erstes Mal"', () async {
      final z = await lies(idBank);

      expect(z.laedt, isFalse);
      expect(z.fehlgeschlagen, isFalse);
      expect(z.bekannt, isTrue);
      expect(z.reihe, isEmpty);
      expect(z.plateau, isFalse);
      expect(z.vorschlag, isA<FirstTime>());
    });
  });

  group('Mit Trainings', () {
    test(
      'die Reihe ist, was `ExerciseProgress` aus den Trainings macht',
      () async {
        await lege([
          sitzung('S1', morgens(3, 2), {
            idBank: [(60, 10), (62.5, 8)],
          }),
          sitzung('S2', morgens(3, 9), {
            idBank: [(65, 6)],
          }),
        ]);

        final z = await lies(idBank);

        expect(
          z.reihe,
          ExerciseProgress.points(
            exercise: ExerciseCatalog.all[idBank]!,
            sessions: [
              ExerciseSession(
                date: morgens(3, 2),
                sets: const [
                  CompletedSet(weight: 60, reps: 10),
                  CompletedSet(weight: 62.5, reps: 8),
                ],
              ),
              ExerciseSession(
                date: morgens(3, 9),
                sets: const [CompletedSet(weight: 65, reps: 6)],
              ),
            ],
          ),
        );
        expect(z.reihe.map((p) => p.top), [62.5, 65.0]);
        expect(z.reihe.map((p) => p.oneRepMax), [80.0, 78.0]);
      },
    );

    test('nur die Sätze dieser Übung', () async {
      await lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idDips: [(-20, 8)],
        }),
      ]);

      final bankZ = await lies(idBank);
      final dipsZ = await lies(idDips);

      expect(bankZ.reihe.map((p) => p.top), [60.0]);
      expect(dipsZ.reihe.map((p) => p.top), [-20.0]);
      expect(dipsZ.reihe.single.oneRepMax, isNull);
    });

    test('eine Übung, die nie trainiert wurde, hat eine leere Reihe', () async {
      await lege([bank('S1', morgens(3, 2), 60, 10)]);
      final z = await lies(idDips);
      expect(z.bekannt, isTrue);
      expect(z.reihe, isEmpty);
      expect(z.vorschlag, isA<FirstTime>());
    });

    test('der Vorschlag ist der aus `Progression.suggest`, neueste Sitzung '
        'zuerst', () async {
      // Alle Sätze an der oberen Grenze (10) → Steigern.
      await lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10), (60, 10)],
        }),
        sitzung('S2', morgens(3, 9), {
          idBank: [(62.5, 10), (62.5, 10)],
        }),
      ]);

      final z = await lies(idBank);

      expect(
        z.vorschlag,
        Progression.suggest(ExerciseCatalog.all[idBank]!, const [
          [
            CompletedSet(weight: 62.5, reps: 10),
            CompletedSet(weight: 62.5, reps: 10),
          ],
          [
            CompletedSet(weight: 60, reps: 10),
            CompletedSet(weight: 60, reps: 10),
          ],
        ]),
      );
      expect(z.vorschlag, isA<Increase>());
    });
  });

  group('Plateau — kein Anstieg des geschätzten 1RM über vier Trainings', () {
    test('vier gleiche Trainings sind ein Plateau', () async {
      await lege([
        for (var i = 0; i < 4; i++) bank('S$i', morgens(2, 9 + 7 * i), 60, 10),
      ]);
      expect((await lies(idBank)).plateau, isTrue);
    });

    test('drei gleiche Trainings sind keins — vier werden gebraucht', () async {
      await lege([
        for (var i = 0; i < 3; i++) bank('S$i', morgens(2, 16 + 7 * i), 60, 10),
      ]);
      expect((await lies(idBank)).plateau, isFalse);
    });

    test('ein Anstieg über die vier Trainings ist keins', () async {
      await lege([
        bank('S0', morgens(2, 9), 57.5, 10),
        bank('S1', morgens(2, 16), 60, 10),
        bank('S2', morgens(2, 23), 62.5, 10),
        bank('S3', morgens(3, 2), 65, 10),
      ]);
      expect((await lies(idBank)).plateau, isFalse);
    });

    test('ohne Trainings und beim Laden gibt es kein Plateau', () async {
      expect((await lies(idBank)).plateau, isFalse);
    });
  });

  group('Gescheitertes Lesen', () {
    test('ist `fehlgeschlagen`, nicht „leer" und nicht „Erstes Mal"', () async {
      await lege([bank('S1', morgens(3, 2), 60, 10)]);
      ablage.fehler = StateError('Platte nicht lesbar (vom Test erzwungen)');

      final z = await lies(idBank);

      expect(z.fehlgeschlagen, isTrue);
      expect(z.laedt, isFalse);
      expect(z.bekannt, isFalse);
      expect(
        z.vorschlag,
        isNull,
        reason:
            'Ein Vorschlag „Erstes Mal" wäre eine Aussage über Daten, die '
            'vielleicht da sind',
      );
      expect(z.reihe, isEmpty);
    });
  });

  group('Nachlauf', () {
    test('ein neues Training erscheint, sobald die Ablage es sagt', () async {
      await lege([
        bank('S1', morgens(3, 2), 60, 10),
        bank('S2', morgens(3, 9), 62.5, 10),
      ]);
      expect((await lies(idBank)).reihe, hasLength(2));

      await schreiber.legeAb(bank('S3', morgens(3, 10), 65, 10));
      container.invalidate(gymSitzungenProvider);
      await pumpEventQueue(times: 200);

      final z = container.read(gymFortschrittProvider(idBank));
      expect(z.reihe.map((p) => p.top), [60.0, 62.5, 65.0]);
    });

    test(
      'während des Neulesens steht der alte Stand da, kein Ladezustand',
      () async {
        await lege([
          bank('S1', morgens(3, 2), 60, 10),
          bank('S2', morgens(3, 9), 62.5, 10),
        ]);
        final vorher = await lies(idBank);

        ablage.tor = Completer<void>();
        container.invalidate(gymSitzungenProvider);
        await pumpEventQueue(times: 100);

        final waehrend = container.read(gymFortschrittProvider(idBank));
        expect(
          waehrend.laedt,
          isFalse,
          reason:
              'Der Platzhalter gehört allein in den Ladezustand: Ein Wert, '
              'der dastand, bleibt stehen (`CLAUDE.md`)',
        );
        expect(waehrend.reihe, vorher.reihe);
        expect(waehrend.vorschlag, vorher.vorschlag);

        ablage.tor!.complete();
      },
    );

    test(
      'ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg',
      () async {
        await lege([
          bank('S1', morgens(3, 2), 60, 10),
          bank('S2', morgens(3, 9), 62.5, 10),
        ]);
        final vorher = await lies(idBank);
        expect(vorher.reihe, isNotEmpty);

        ablage.fehler = StateError('Platte nicht lesbar (vom Test erzwungen)');
        container.invalidate(gymSitzungenProvider);
        await pumpEventQueue(times: 200);

        final danach = container.read(gymFortschrittProvider(idBank));
        expect(danach.fehlgeschlagen, isFalse);
        expect(
          danach.reihe,
          vorher.reihe,
          reason: 'Tims Beschwerde ist, dass Werte verschwinden',
        );
      },
    );
  });

  group('Gehalten, nicht gerechnet (Hausregel 2, Fehler 03)', () {
    test('zwei Lesungen geben dieselbe Instanz', () async {
      await lege([bank('S1', morgens(3, 2), 60, 10)]);
      await lies(idBank);

      expect(
        identical(
          container.read(gymFortschrittProvider(idBank)),
          container.read(gymFortschrittProvider(idBank)),
        ),
        isTrue,
      );
    });

    test('das Ergebnis liest die Ablage nicht bei jedem Zugriff neu', () async {
      await lege([bank('S1', morgens(3, 2), 60, 10)]);
      await lies(idBank);
      final gelesen = ablage.lesungen;

      for (var i = 0; i < 5; i++) {
        container.read(gymFortschrittProvider(idBank));
      }
      await pumpEventQueue(times: 50);

      expect(ablage.lesungen, gelesen);
    });

    test(
      'ein Neulesen mit gleichem Inhalt gibt einen **gleichen** Wert',
      () async {
        await lege([
          bank('S1', morgens(3, 2), 60, 10),
          bank('S2', morgens(3, 9), 62.5, 10),
        ]);
        final vorher = await lies(idBank);

        container.invalidate(gymSitzungenProvider);
        await pumpEventQueue(times: 200);
        final nachher = container.read(gymFortschrittProvider(idBank));

        expect(
          nachher,
          vorher,
          reason:
              'Riverpod rechnet Abgeleitetes neu, sobald die Abhängigkeit '
              'ungleich ist — ohne `==` läuft alles, was am Zustand hängt, '
              'bei jedem Neulesen neu',
        );
        expect(nachher.hashCode, vorher.hashCode);
      },
    );

    test(
      'zwei Übungen sind zwei Zustände, die einander nicht stören',
      () async {
        await lege([
          sitzung('S1', morgens(3, 2), {
            idBank: [(60, 10)],
            idDips: [(-20, 8)],
          }),
        ]);
        final a = await lies(idBank);
        final b = await lies(idDips);

        expect(a, isNot(b));
        expect(a.uebung.id, idBank);
        expect(b.uebung.id, idDips);
      },
    );
  });

  group('Unbekannte Übung', () {
    test('ist ein Programmierfehler und wirft', () {
      expect(
        () => container.read(gymFortschrittProvider('gibtEsNicht')),
        throwsA(anything),
        reason:
            'Eine Übung, die der Katalog nicht kennt, gibt es nicht — '
            'dieselbe Regel wie bei `gymVorschlagProvider`',
      );
    });
  });
}
