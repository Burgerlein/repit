import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für die **Ziele** (#111): Schlafziel, Schlafenszeitziel und
/// Wochenziel Trainingsminuten.
///
/// **Warum das ein eigenes Ticket ist.** `docs/SPEC.md` Abschnitt 3 nennt
/// Schlafziel 8 h und übliche Schlafenszeit 22:30. Im Swift-Code greift das
/// Schlafziel nur als Vorbelegung `= 8` an zwei Stellen, ein
/// Schlafenszeitziel gibt es überhaupt nicht, und das Wochenziel von 210
/// Minuten steht als Konstante im Quelltext. Die neue
/// Zubettgehzeit-Formel (#110) rechnet gegen das Schlafenszeitziel — ohne
/// Ablage ist sie nicht umsetzbar.
///
/// **Tims Entscheidung vom 27.10.2026** (Spec
/// `2026-10-26-erholung-flutter-design.md`, Abschnitt 10a Punkt 4): „Das
/// Wochenziel Trainingsminuten wird abgelegt, Vorbelegung 210, zusammen mit
/// Schlafziel und Schlafenszeitziel in #111. Keine Zielkonstante im
/// Quelltext — #41 liest später auf denselben Wert. Bis dahin gibt es keinen
/// Schirm dafür; der Wert steht und ist änderbar, nur noch nicht bedienbar."
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Entscheidung: Minuten als Einheit, eine Zeile, Vorbelegung in Dart
///
/// - **Beide Zeiten liegen als ganze Minuten in der Datenbank.** Das
///   Schlafziel als Minuten (8 h = 480), damit „7:30 h" ausdrückbar bleibt
///   ohne Gleitkommarundung; das Schlafenszeitziel als **Minuten nach
///   Mitternacht** (22:30 = 1350). Nicht als Minuten seit 18:00, obwohl die
///   Zubettgehzeit-Formel (#110) auf dieser Skala rechnet: Die Ablage soll
///   lesbar sein, ohne die Formel zu kennen, und Tims Entscheidung vom
///   27.10. erlaubt dort ausdrücklich negative Werte — eine Umrechnung, die
///   in die Ablage gehört, hätte genau an dieser Kante ein Vorzeichen zu
///   viel.
/// - **Keine `DateTime`-Spalte für die Schlafenszeit.** 22:30 ist eine
///   Tageszeit, kein Zeitpunkt. Ein Datum daran wäre ein erfundenes
///   Ereignis im Quelltext (`CLAUDE.md`, „Keine hartcodierten Ereignisse").
/// - **Genau eine Zeile** (`id == 0`, `withDefault`). Ziele sind kein
///   Verlauf; eine zweite Zeile wäre ein zweiter, widersprechender Stand.
/// - **Die Vorbelegung steht in Dart** (`Ziele.vorbelegung`), nicht als
///   vorab eingefügte Zeile. Sonst gäbe es sie an zwei Orten — in der
///   Migration und im Code —, und einer von beiden wäre irgendwann der
///   falsche. Eine leere Tabelle heißt: Tim hat noch nichts eingestellt.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// In `lib/data/tables.dart` (Schema **v4**, siehe
/// `test/data/schema_v3_test.dart` zur Versionszählung):
///
/// ```dart
/// @DataClassName('ZielWerteRow')
/// class ZielWerte extends Table {
///   IntColumn get id => integer().withDefault(const Constant(0))();
///   IntColumn get schlafzielMinuten => integer().named('schlafziel_minuten')();
///   IntColumn get schlafenszeitMinuten =>
///       integer().named('schlafenszeit_minuten')();
///   IntColumn get wochenzielTrainingsminuten =>
///       integer().named('wochenziel_trainingsminuten')();
///   @override Set<Column> get primaryKey => {id};
/// }
/// ```
///
/// In `lib/data/ziele.dart` (neue Datei — **nicht** `lib/shell/ziele.dart`,
/// das ist `AppTarget` und bleibt unberührt):
///
/// ```dart
/// @immutable
/// class Ziele {
///   const Ziele({
///     required this.schlafzielMinuten,
///     required this.schlafenszeitMinuten,
///     required this.wochenzielTrainingsminuten,
///   });
///   final int schlafzielMinuten;           // 8 h  = 480
///   final int schlafenszeitMinuten;        // 22:30 = 1350 nach Mitternacht
///   final int wochenzielTrainingsminuten;  // 210
///
///   /// Die **einzige** Stelle im Quelltext, an der diese drei Zahlen
///   /// stehen (SPEC 3 und Spec 10a Punkt 4).
///   static const Ziele vorbelegung = Ziele(...);
///
///   Ziele kopieMit({
///     int? schlafzielMinuten,
///     int? schlafenszeitMinuten,
///     int? wochenzielTrainingsminuten,
///   });
///   // == und hashCode über alle drei Felder.
/// }
///
/// class ZieleRepository {
///   ZieleRepository(AppCache db);
///
///   /// `Ziele.vorbelegung`, solange nichts abgelegt ist — `Messwert<T>`
///   /// gilt hier **nicht** (Spec 5.6a): Das sind Tims eigene Daten, kein
///   /// Lauf, der leer ausgehen könnte.
///   Future<Ziele> lies();
///
///   /// Wirft `ArgumentError` bei unmöglichen Werten; schreibt sonst die
///   /// eine Zeile, überschreibend.
///   Future<void> schreibe(Ziele ziele);
/// }
///
/// final zieleRepositoryProvider = Provider<ZieleRepository>(...);
///
/// final zieleProvider =
///     AsyncNotifierProvider<ZieleNotifier, Ziele>(ZieleNotifier.new);
///
/// class ZieleNotifier extends AsyncNotifier<Ziele> {
///   @override Future<Ziele> build();
///   Future<void> setze(Ziele ziele);
/// }
///
/// /// Übersetzt den äußeren `AsyncValue` für die Oberfläche — dasselbe
/// /// Muster wie `heuteZustandAusProvider` in `lib/shell/heute_view.dart`,
/// /// damit `AsyncValue` in der Widget-Schicht nicht auftaucht (Spec 5.4).
/// /// `laedt` sagt „noch nicht nachgesehen", **nicht** „nichts da".
/// ({bool laedt, Ziele ziele}) zieleAusProvider(AsyncValue<Ziele> zustand);
/// ```
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Einstellungs-Schirm.** Er kommt aus #31; dieses Ticket legt nur
///   ab und macht lesbar.
/// - **Dass die drei Zahlen nirgends sonst im Quelltext stehen.** Das ist
///   eine `grep`-Frage für den Review, keine, die `flutter test` stellen
///   kann.
/// - **Der Schlaf-Score.** Dass er diese Werte statt einer Vorbelegung
///   liest, ist #110 und bekommt dort seine eigenen Tests.
void main() {
  group('Die Vorbelegung steht an genau einer Stelle (SPEC 3, Spec 10a)', () {
    test('8 h Schlaf, 22:30 zu Bett, 210 Minuten in der Woche', () {
      expect(
        Ziele.vorbelegung.schlafzielMinuten,
        480,
        reason: 'SPEC 3: Schlafziel 8 h',
      );
      expect(
        Ziele.vorbelegung.schlafenszeitMinuten,
        1350,
        reason: 'SPEC 3: übliche Schlafenszeit 22:30, also 22·60 + 30',
      );
      expect(
        Ziele.vorbelegung.wochenzielTrainingsminuten,
        210,
        reason:
            'Spec 10a Punkt 4 — bis #41 die Ziele bringt, liegt der Wert '
            'hier und nirgends sonst',
      );
    });

    test('zwei Ziele mit denselben Werten sind gleich', () {
      expect(
        const Ziele(
          schlafzielMinuten: 450,
          schlafenszeitMinuten: 1320,
          wochenzielTrainingsminuten: 180,
        ),
        const Ziele(
          schlafzielMinuten: 450,
          schlafenszeitMinuten: 1320,
          wochenzielTrainingsminuten: 180,
        ),
        reason:
            'ohne Wertgleichheit baute jeder Lesevorgang ein neues, '
            'ungleiches Objekt — und jeder Beobachter rechnete neu, obwohl '
            'sich nichts geändert hat (derselbe Grund wie bei DataWindow)',
      );
      expect(
        const Ziele(
          schlafzielMinuten: 450,
          schlafenszeitMinuten: 1320,
          wochenzielTrainingsminuten: 180,
        ).hashCode,
        const Ziele(
          schlafzielMinuten: 450,
          schlafenszeitMinuten: 1320,
          wochenzielTrainingsminuten: 180,
        ).hashCode,
      );
    });

    test('kopieMit ändert genau ein Feld und lässt die anderen stehen', () {
      final geaendert = Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: 1290);

      expect(geaendert.schlafenszeitMinuten, 1290, reason: '21:30');
      expect(geaendert.schlafzielMinuten, 480);
      expect(geaendert.wochenzielTrainingsminuten, 210);
    });
  });

  group('Ablage — leer heißt Vorbelegung, nicht Messwert (Spec 5.6a)', () {
    test(
      'ohne abgelegte Zeile liefert lies() die Vorbelegung, nicht null und '
      'keinen Leerzustand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        expect(await ZieleRepository(db).lies(), Ziele.vorbelegung);
        expect(
          await db.select(db.zielWerte).get(),
          isEmpty,
          reason:
              'die Vorbelegung kommt aus Dart, nicht aus einer vorab '
              'eingefügten Zeile — sonst stünde sie an zwei Orten',
        );
      },
    );

    test('ein geschriebenes Ziel kommt unverändert zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ZieleRepository(db);

      const eigene = Ziele(
        schlafzielMinuten: 450,
        schlafenszeitMinuten: 1335,
        wochenzielTrainingsminuten: 240,
      );
      await repo.schreibe(eigene);

      expect(await repo.lies(), eigene);
    });

    test(
      'ein zweites Schreiben überschreibt — es entsteht keine zweite Zeile '
      'und kein zweiter, widersprechender Stand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = ZieleRepository(db);

        await repo.schreibe(Ziele.vorbelegung.kopieMit(schlafzielMinuten: 420));
        await repo.schreibe(Ziele.vorbelegung.kopieMit(schlafzielMinuten: 510));

        expect(await db.select(db.zielWerte).get(), hasLength(1));
        expect((await repo.lies()).schlafzielMinuten, 510);
      },
    );

    test(
      'ein geschriebenes Ziel überlebt den Neustart der App — eine zweite '
      'Brücke auf dieselbe Datenbank findet es wieder',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await ZieleRepository(
          db,
        ).schreibe(Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: 1290));

        expect((await ZieleRepository(db).lies()).schlafenszeitMinuten, 1290);
      },
    );
  });

  group('Unmögliche Werte kommen nicht in die Ablage', () {
    Future<void> pruefeAbgelehnt(Ziele ziele, String warum) async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await expectLater(
        ZieleRepository(db).schreibe(ziele),
        throwsArgumentError,
        reason: warum,
      );
    }

    test('ein Schlafziel von 0 Minuten wird abgewiesen', () async {
      await pruefeAbgelehnt(
        Ziele.vorbelegung.kopieMit(schlafzielMinuten: 0),
        'ein Schlafziel von null Minuten ließe den Schlaf-Score durch null '
        'teilen oder jede Nacht als perfekt gelten',
      );
    });

    test('ein Schlafziel über 24 Stunden wird abgewiesen', () async {
      await pruefeAbgelehnt(
        Ziele.vorbelegung.kopieMit(schlafzielMinuten: 1441),
        'mehr als ein Tag Schlaf je Nacht ist kein Ziel, sondern ein '
        'Tippfehler',
      );
    });

    test(
      'eine Schlafenszeit außerhalb eines Tages wird abgewiesen — oben '
      'wie unten',
      () async {
        await pruefeAbgelehnt(
          Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: 1440),
          '24:00 gibt es nicht; 0 bis 1439 ist der ganze Tag',
        );
        await pruefeAbgelehnt(
          Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: -1),
          'eine negative Tageszeit gibt es nicht — die negative Skala der '
          'Zubettgehzeit-Formel (#110) entsteht erst beim Rechnen, nicht in '
          'der Ablage',
        );
      },
    );

    test('ein negatives Wochenziel wird abgewiesen', () async {
      await pruefeAbgelehnt(
        Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: -30),
        'weniger als keine Minute Training gibt es nicht',
      );
    });

    test(
      'ein Wochenziel von 0 ist dagegen erlaubt — eine bewusste Pause ist '
      'kein Fehler',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = ZieleRepository(db);

        await repo.schreibe(
          Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 0),
        );

        expect((await repo.lies()).wochenzielTrainingsminuten, 0);
      },
    );
  });

  group('Der Provider — die Ziele sind lesbar und änderbar', () {
    ProviderContainer behaelter(AppCache db) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [appCacheProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('ohne abgelegte Zeile liefert er die Vorbelegung', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await behaelter(db).read(zieleProvider.future),
        Ziele.vorbelegung,
      );
    });

    test(
      'setze schreibt durch bis in die Datenbank und aktualisiert den '
      'Zustand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final container = behaelter(db);
        await container.read(zieleProvider.future);

        await container
            .read(zieleProvider.notifier)
            .setze(Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: 1290));

        expect(
          container.read(zieleProvider).value?.schlafenszeitMinuten,
          1290,
          reason: 'der Zustand zeigt den neuen Wert sofort',
        );
        expect(
          (await ZieleRepository(db).lies()).schlafenszeitMinuten,
          1290,
          reason:
              'und die Datenbank auch — sonst wäre es wieder ein @State, '
              'das beim Verlassen des Schirms vergisst',
        );
      },
    );

    test(
      'ein neuer Container (Neustart der App) sieht den geänderten Wert, '
      'nicht die Vorbelegung',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await behaelter(db)
            .read(zieleProvider.notifier)
            .setze(Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 300));

        final nachNeustart = await behaelter(db).read(zieleProvider.future);
        expect(nachNeustart.wochenzielTrainingsminuten, 300);
      },
    );
  });

  group('zieleAusProvider — AsyncValue bleibt aus der Widget-Schicht', () {
    test(
      'während des Ladens steht die Vorbelegung da, und laedt sagt, dass '
      'es noch ein Ladezustand ist',
      () {
        final zustand = zieleAusProvider(const AsyncLoading<Ziele>());

        expect(zustand.ziele, Ziele.vorbelegung);
        expect(
          zustand.laedt,
          isTrue,
          reason:
              'Ladezustand ist kein Leerstand: Wer die Zeile „Schlafziel '
              '8:00 h" zeichnet, soll wissen, dass noch nicht nachgesehen '
              'wurde',
        );
      },
    );

    test('mit geladenem Wert gewinnt der Wert, und laedt ist falsch', () {
      const eigene = Ziele(
        schlafzielMinuten: 450,
        schlafenszeitMinuten: 1290,
        wochenzielTrainingsminuten: 300,
      );

      final zustand = zieleAusProvider(const AsyncData<Ziele>(eigene));

      expect(zustand.ziele, eigene);
      expect(zustand.laedt, isFalse);
    });

    test(
      'auch ein gescheiterter Lesevorgang zeigt die Vorbelegung, nicht '
      'eine leere Zeile',
      () {
        final zustand = zieleAusProvider(
          AsyncError<Ziele>(Exception('Datenbank nicht lesbar'), StackTrace.empty),
        );

        expect(zustand.ziele, Ziele.vorbelegung);
        expect(zustand.laedt, isFalse);
      },
    );
  });
}
