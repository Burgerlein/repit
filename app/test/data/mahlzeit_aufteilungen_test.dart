import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für die **Historie der Aufteilung des Tagesziels auf die
/// Mahlzeiten** (#432 unter #374) — Repository und Provider in
/// `lib/data/mahlzeit_aufteilungen.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbarn: `schema_v21_test.dart` (die Tabelle, Stufe 21),
/// `ernaehrung/ernaehrung_tag_aufteilung_test.dart` (die Wirkung auf den
/// Ernährungstag). Der Werttyp `MahlzeitAufteilung`, `AufteilungAb` und
/// `geltendeAufteilung` stehen im Kern und werden dort geprüft
/// (`Packages/trainings_core/test/mahlzeit_aufteilung_test.dart`).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Repository und Provider", und Plan
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Task 3.
/// Von Tim am 10.11.2026 übernommen:
///
/// - **Entscheidung 1:** Der Startwert 25 · 35 · 30 · 10 gilt erst, wenn
///   Tim einmal sichert. Lesen legt keine Zeile an.
/// - **Entscheidung 5:** Eine neue Aufteilung gilt ab heute, frühere Tage
///   behalten ihre.
/// - **V1:** Gespeichert werden nur Frühstück, Mittag und Abend, in drei
///   nullbaren Spalten. **Gelesen werden nur vollständige Zeilen.**
/// - **V2:** „Ab heute" ist der Berliner Kalendertag aus `clockProvider`.
///   Ein zweites Sichern am selben Tag ersetzt die Zeile dieses Tages.
/// - **V3:** Eine Aufteilung, die die Regeln verletzt, wirft
///   `ArgumentError`, **auch beim Lesen aus der Tabelle**.
///
/// ## API — aus dem Plan (Task 3, „Interfaces")
///
/// ```dart
/// class MahlzeitAufteilungRepository {
///   MahlzeitAufteilungRepository(AppCache db);
///   Future<List<AufteilungAb>> alle();      // aufsteigend nach ab_tag
///   Future<void> setze(AufteilungAb a);     // ersetzt am selben Tag
/// }
/// final mahlzeitAufteilungRepositoryProvider =
///     Provider<MahlzeitAufteilungRepository>(…);
/// final mahlzeitAufteilungenProvider = AsyncNotifierProvider<
///     MahlzeitAufteilungenNotifier, List<AufteilungAb>>(…);
/// class MahlzeitAufteilungenNotifier
///     extends AsyncNotifier<List<AufteilungAb>> {
///   Future<void> setzeAbHeute(MahlzeitAufteilung a);
/// }
/// ```
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Eine Zeile mit einem verbotenen Wert (z. B. 27 %) lässt `alle()`
///   scheitern**, statt still übersprungen zu werden. V3 sagt „wirft, auch
///   beim Lesen"; dass der Fehler aus `alle()` herauskommt und nicht nur
///   die eine Zeile verschluckt, ist die Lesart dieser Datei.
/// - **Ein zweites Sichern mit derselben Aufteilung bewegt keinen
///   Beobachter.** Die Spec sagt „gesetzt wird nur, wenn sich etwas
///   geändert hat" (wie `KalorienzieleNotifier._uebernimm`); geprüft wird
///   das hier über die Zahl der Benachrichtigungen.
///
/// **Alle Zahlen und Daten hier sind erfunden**, Zeitpunkte im Jahr 2099.
void main() {
  late AppCache db;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  final startwertArt = MahlzeitAufteilung(
    fruehstueck: 25,
    mittag: 35,
    abend: 30,
  );
  final andere = MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30);
  final ohneSnack = MahlzeitAufteilung(fruehstueck: 30, mittag: 35, abend: 35);

  final ab0301 = AufteilungAb(abTag: '2099-03-01', aufteilung: startwertArt);
  final ab0305 = AufteilungAb(abTag: '2099-03-05', aufteilung: andere);
  final ab0310 = AufteilungAb(abTag: '2099-03-10', aufteilung: ohneSnack);

  Future<List<Map<String, Object?>>> rohzeilen() async => [
    for (final z
        in await db
            .customSelect(
              'SELECT * FROM mahlzeit_aufteilungen ORDER BY ab_tag;',
            )
            .get())
      z.data,
  ];

  Future<void> rohEinfuegen(
    String abTag,
    String fruehstueck,
    String mittag,
    String abend,
  ) => db.customStatement(
    'INSERT INTO mahlzeit_aufteilungen '
    '(ab_tag, fruehstueck_pct, mittag_pct, abend_pct) '
    "VALUES ('$abTag', $fruehstueck, $mittag, $abend);",
  );

  group('Das Repository', () {
    test('eine leere Tabelle ist eine leere Historie', () async {
      expect(await MahlzeitAufteilungRepository(db).alle(), isEmpty);
    });

    test('was abgelegt wird, kommt gleich zurück', () async {
      final repo = MahlzeitAufteilungRepository(db);
      await repo.setze(ab0301);

      expect(await repo.alle(), [ab0301]);
    });

    test('in der Tabelle stehen die drei Prozent als ganze Zahlen — der '
        'Snack ist der Rest und steht nirgends (V1)', () async {
      await MahlzeitAufteilungRepository(db).setze(ab0301);

      final zeile = (await rohzeilen()).single;
      expect(zeile['ab_tag'], '2099-03-01');
      expect(zeile['fruehstueck_pct'], 25);
      expect(zeile['mittag_pct'], 35);
      expect(zeile['abend_pct'], 30);
    });

    test(
      'aufsteigend nach ab_tag, egal in welcher Reihenfolge abgelegt',
      () async {
        final repo = MahlzeitAufteilungRepository(db);
        await repo.setze(ab0310);
        await repo.setze(ab0301);
        await repo.setze(ab0305);

        expect(await repo.alle(), [ab0301, ab0305, ab0310]);
      },
    );

    test('eine Zeile mit NULL in einer Prozentspalte erscheint nicht — '
        'gelesen werden nur vollständige Zeilen (V1)', () async {
      final repo = MahlzeitAufteilungRepository(db);
      await repo.setze(ab0301);
      await rohEinfuegen('2099-03-04', '25', 'NULL', '30');
      await rohEinfuegen('2099-03-06', 'NULL', '35', '30');
      await rohEinfuegen('2099-03-08', '25', '35', 'NULL');
      await repo.setze(ab0310);

      expect(
        await repo.alle(),
        [ab0301, ab0310],
        reason:
            'eine halbe Aufteilung hätte keinen Snack, der stimmt — die '
            'vollständigen Zeilen davor und danach bleiben',
      );
    });

    test('eine zweite Aufteilung für denselben Tag ersetzt die erste — je '
        'Tag gilt höchstens eine (V2)', () async {
      final repo = MahlzeitAufteilungRepository(db);
      await repo.setze(ab0301);
      final ersatz = AufteilungAb(abTag: '2099-03-01', aufteilung: andere);
      await repo.setze(ersatz);

      expect(await repo.alle(), [ersatz]);
      expect(await rohzeilen(), hasLength(1));
    });

    test('eine spätere Aufteilung lässt die frühere stehen — das ist die '
        'Historie (Entscheidung 5)', () async {
      final repo = MahlzeitAufteilungRepository(db);
      await repo.setze(ab0301);
      await repo.setze(ab0305);

      expect(await repo.alle(), [ab0301, ab0305]);
    });

    test('ein verbotener Wert in der Tabelle wirft beim Lesen, statt still '
        'eine Aufteilung zu werden (V3)', () async {
      await rohEinfuegen('2099-03-02', '27', '35', '30');

      await expectLater(
        MahlzeitAufteilungRepository(db).alle(),
        throwsArgumentError,
      );
    });

    test('eine Summe über 100 in der Tabelle wirft beim Lesen (V3)', () async {
      await rohEinfuegen('2099-03-02', '40', '40', '30');

      await expectLater(
        MahlzeitAufteilungRepository(db).alle(),
        throwsArgumentError,
      );
    });
  });

  group('Der Provider', () {
    ProviderContainer behaelter(DateTime jetzt) {
      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // Mittwoch, 11.03.2099, 11:00 Berliner Zeit (MEZ, +1).
    final mittag0311 = DateTime.utc(2099, 3, 11, 10);

    test('das Repository steht als Provider bereit', () {
      final c = behaelter(mittag0311);
      expect(
        c.read(mahlzeitAufteilungRepositoryProvider),
        isA<MahlzeitAufteilungRepository>(),
      );
    });

    test('liest die Historie aus der Tabelle', () async {
      await MahlzeitAufteilungRepository(db).setze(ab0305);
      await MahlzeitAufteilungRepository(db).setze(ab0301);
      final c = behaelter(mittag0311);

      expect(await c.read(mahlzeitAufteilungenProvider.future), [
        ab0301,
        ab0305,
      ]);
    });

    test('ohne gesicherte Aufteilung: leer, kein Fehler — und das Lesen legt '
        'keinen Startwert an (Entscheidung 1)', () async {
      final c = behaelter(mittag0311);

      expect(await c.read(mahlzeitAufteilungenProvider.future), isEmpty);
      expect(await rohzeilen(), isEmpty);
    });

    test('setzeAbHeute legt die Aufteilung ab heute ab und lässt frühere '
        'stehen', () async {
      await MahlzeitAufteilungRepository(db).setze(ab0301);
      final c = behaelter(mittag0311);
      await c.read(mahlzeitAufteilungenProvider.future);

      await c.read(mahlzeitAufteilungenProvider.notifier).setzeAbHeute(andere);

      final erwartet = AufteilungAb(abTag: '2099-03-11', aufteilung: andere);
      expect(await MahlzeitAufteilungRepository(db).alle(), [ab0301, erwartet]);
      expect(c.read(mahlzeitAufteilungenProvider).value, [
        ab0301,
        erwartet,
      ], reason: 'der Provider steht ohne Neustart auf dem neuen Stand');
    });

    test(
      'setzeAbHeute nimmt den Berliner Tag, nicht den UTC-Tag (V2)',
      () async {
        // 23:30 UTC am 10.03.2099 ist in Berlin (MEZ, +1) schon 00:30 am
        // 11.03. — UTC-Tag und Berliner Tag fallen auseinander.
        final c = behaelter(DateTime.utc(2099, 3, 10, 23, 30));
        await c.read(mahlzeitAufteilungenProvider.future);

        await c
            .read(mahlzeitAufteilungenProvider.notifier)
            .setzeAbHeute(startwertArt);

        expect((await rohzeilen()).single['ab_tag'], '2099-03-11');
        expect(
          (await MahlzeitAufteilungRepository(db).alle()).single.abTag,
          '2099-03-11',
        );
      },
    );

    test('zweimal am selben Tag gesichert: eine Zeile, die zweite gilt '
        '(V2)', () async {
      final c = behaelter(mittag0311);
      await c.read(mahlzeitAufteilungenProvider.future);
      final notifier = c.read(mahlzeitAufteilungenProvider.notifier);

      await notifier.setzeAbHeute(startwertArt);
      await notifier.setzeAbHeute(andere);

      final erwartet = [AufteilungAb(abTag: '2099-03-11', aufteilung: andere)];
      expect(await MahlzeitAufteilungRepository(db).alle(), erwartet);
      expect(await rohzeilen(), hasLength(1));
      expect(c.read(mahlzeitAufteilungenProvider).value, erwartet);
    });

    test('setzeAbHeute direkt nach dem Anlegen, bevor das erste Lesen fertig '
        'ist, geht nicht verloren', () async {
      final c = behaelter(mittag0311);
      c.listen(mahlzeitAufteilungenProvider, (_, _) {});

      await c
          .read(mahlzeitAufteilungenProvider.notifier)
          .setzeAbHeute(startwertArt);

      final erwartet = [
        AufteilungAb(abTag: '2099-03-11', aufteilung: startwertArt),
      ];
      expect(await MahlzeitAufteilungRepository(db).alle(), erwartet);
      expect(c.read(mahlzeitAufteilungenProvider).value, erwartet);
    });

    test('dieselbe Aufteilung noch einmal gesichert bewegt keinen '
        'Beobachter', () async {
      final c = behaelter(mittag0311);
      await c.read(mahlzeitAufteilungenProvider.future);
      final notifier = c.read(mahlzeitAufteilungenProvider.notifier);
      await notifier.setzeAbHeute(startwertArt);

      var meldungen = 0;
      c.listen(mahlzeitAufteilungenProvider, (_, _) => meldungen++);

      await notifier.setzeAbHeute(
        MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30),
      );

      expect(meldungen, 0);
      expect(await rohzeilen(), hasLength(1));
    });
  });
}
