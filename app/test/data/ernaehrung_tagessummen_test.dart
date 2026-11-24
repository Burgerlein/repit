import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

/// Tests für **#312** — Tagessummen über einen Zeitraum, die Datengrundlage
/// des 14-Tage-Verlaufs auf dem Ernährungs-Tag.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// In `lib/data/ernaehrung_repository.dart`, an `ErnaehrungRepository`:
///
/// ```dart
/// /// Die Summen der eigenen Einträge je **Esstag** von [von] bis [bis],
/// /// beide eingeschlossen — **in SQL gefiltert und summiert**.
/// ///
/// /// Ein Tag ohne Eintrag fehlt in der Map; er steht nicht mit 0 drin.
/// /// Je Spalte gilt die Regel von `SUM` und von `Naehrwerte.+`: Fehlt der
/// /// Wert in allen Einträgen eines Tages, ist die Summe `null`; fehlt er
/// /// nur in einigen, zählen die vorhandenen. `extra` wird nicht summiert
/// /// und ist leer — die Summen tragen die acht Spalten, sonst nichts.
/// Future<Map<String, Naehrwerte>> tagessummen({
///   required String von,
///   required String bis,
/// });
/// ```
///
/// ## Warum so
///
/// - **In SQL** — Ticket und Hausregel 2 (`CLAUDE.md`): Was ein Provider
///   einer Ansicht anbietet, wird gehalten, nicht bei jedem Zugriff
///   gerechnet; vierzehn Einzelabfragen oder ein Laden aller Einträge mit
///   Filtern in Dart wüchse mit jedem Monat, den Tim die App benutzt. Wie
///   SQL geprüft wird: über einen `QueryInterceptor`, der jede Abfrage
///   mitschreibt. Verlangt ist, dass **jede** Abfrage dieses Aufrufs eine
///   `WHERE`-Klausel trägt und **eine** davon mit `GROUP BY` und `SUM(`
///   summiert. Nicht verlangt ist eine bestimmte Form der Abfrage.
/// - **Über den Tagesschlüssel**, nicht über den Zeitpunkt: Ein Eintrag um
///   01:30 gehört zum Abend davor (`Eintraege.tagesSchluessel`), und der
///   ISO-Tagesstring vergleicht lexikografisch richtig — auch über eine
///   Zeitumstellung (`CLAUDE.md`).
/// - **Ein Tag ohne Eintrag fehlt**, statt mit 0 dazustehen: „nichts
///   eingetragen" ist an einem vergangenen Tag keine Aussage über das
///   Gegessene, und die Siebentagezeile zählt solche Tage nicht mit
///   (`SiebenTage.tageMitWerten`). Eine 0 machte daraus „Ziel verfehlt".
/// - **`null` bleibt `null`, eine gewogene 0 bleibt 0** (#232).
///
/// Alle Zahlen und Namen sind erfunden.
void main() {
  Eintrag eintrag({
    required String tag,
    DateTime? zeitpunkt,
    double? kcal = 100,
    double? eiweissG,
    double? ballaststoffeG,
    double? wasserMl,
    int? lebensmittelId = 1,
    String name = 'Prüfgericht',
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: Mahlzeit.mittag,
    zeitpunkt: zeitpunkt ?? DateTime.parse('${tag}T10:00:00Z'),
    lebensmittelId: lebensmittelId,
    name: name,
    mengeG: 100,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      ballaststoffeG: ballaststoffeG,
      wasserMl: wasserMl,
    ),
  );

  ({AppCache db, ErnaehrungRepository repo, _Mitschnitt mitschnitt}) frisch() {
    final mitschnitt = _Mitschnitt();
    final db = AppCache(NativeDatabase.memory().interceptWith(mitschnitt));
    addTearDown(db.close);
    return (db: db, repo: ErnaehrungRepository(db), mitschnitt: mitschnitt);
  }

  group('Tagessummen über einen Zeitraum (#312)', () {
    test(
      'ein Zeitraum ohne Einträge ergibt eine leere Map — keine Nullen',
      () async {
        final h = frisch();
        await h.repo.buche(eintrag(tag: '2099-03-20'));

        expect(
          await h.repo.tagessummen(von: '2099-03-01', bis: '2099-03-14'),
          isEmpty,
        );
      },
    );

    test('je Tag eine Summe, die Grenzen eingeschlossen, nichts von '
        'außerhalb', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-02-28', kcal: 9999));
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 100));
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 250));
      await h.repo.buche(eintrag(tag: '2099-03-07', kcal: 400));
      await h.repo.buche(eintrag(tag: '2099-03-14', kcal: 50));
      await h.repo.buche(eintrag(tag: '2099-03-15', kcal: 9999));

      final summen = await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-14',
      );

      expect(summen.keys.toSet(), {'2099-03-01', '2099-03-07', '2099-03-14'});
      expect(summen['2099-03-01']!.kcal, 350);
      expect(summen['2099-03-07']!.kcal, 400);
      expect(summen['2099-03-14']!.kcal, 50);
    });

    test('ein einzelner Tag als Zeitraum', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 120));
      await h.repo.buche(eintrag(tag: '2099-03-02', kcal: 130));

      final summen = await h.repo.tagessummen(
        von: '2099-03-02',
        bis: '2099-03-02',
      );
      expect(summen.keys, ['2099-03-02']);
      expect(summen['2099-03-02']!.kcal, 130);
    });

    test(
      'gezählt wird der Esstag, nicht der Kalendertag des Zeitpunkts',
      () async {
        final h = frisch();
        // 01:30 Berliner Zeit am 02.03. gehört zum Abend des 01.03.
        await h.repo.buche(
          eintrag(
            tag: '2099-03-01',
            zeitpunkt: DateTime.utc(2099, 3, 2, 0, 30),
            kcal: 300,
          ),
        );

        final summen = await h.repo.tagessummen(
          von: '2099-03-01',
          bis: '2099-03-02',
        );
        expect(summen.keys, ['2099-03-01']);
        expect(summen['2099-03-01']!.kcal, 300);
      },
    );

    test('über die Zeitumstellung hinweg fehlt kein Tag', () async {
      final h = frisch();
      // Am 25.10.2099 endet die Sommerzeit (letzter Sonntag im Oktober).
      for (final tag in ['2099-10-24', '2099-10-25', '2099-10-26']) {
        await h.repo.buche(eintrag(tag: tag, kcal: 111));
      }
      final summen = await h.repo.tagessummen(
        von: '2099-10-24',
        bis: '2099-10-26',
      );
      expect(summen.keys.toSet(), {'2099-10-24', '2099-10-25', '2099-10-26'});
    });

    test('ein Schnelleintrag ohne Lebensmittel zählt mit', () async {
      final h = frisch();
      await h.repo.buche(
        eintrag(tag: '2099-03-01', kcal: 500, lebensmittelId: null),
      );
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 100));

      final summen = await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-01',
      );
      expect(summen['2099-03-01']!.kcal, 600);
    });
  });

  group('null bleibt null, 0 bleibt 0 (#232)', () {
    test(
      'fehlt ein Wert in allen Einträgen eines Tages, ist die Summe null',
      () async {
        final h = frisch();
        await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 100));
        await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 200));

        final summe = (await h.repo.tagessummen(
          von: '2099-03-01',
          bis: '2099-03-01',
        ))['2099-03-01']!;
        expect(
          summe.ballaststoffeG,
          isNull,
          reason: 'nicht deklariert ist nicht 0 g',
        );
        expect(summe.eiweissG, isNull);
      },
    );

    test('fehlt er nur in einigen, zählen die vorhandenen', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-03-01', ballaststoffeG: 3.5));
      await h.repo.buche(eintrag(tag: '2099-03-01'));
      await h.repo.buche(eintrag(tag: '2099-03-01', ballaststoffeG: 1.5));

      final summe = (await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-01',
      ))['2099-03-01']!;
      expect(summe.ballaststoffeG, 5.0);
    });

    test('dieselbe Regel wie Naehrwerte.+ — Summe aus der Datenbank gleich '
        'der Summe der gelesenen Einträge', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 100, eiweissG: 4));
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: null, eiweissG: 6));
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 250, wasserMl: 200));

      final gelesen = await h.repo.eintraegeAmTag('2099-03-01');
      final vonHand = gelesen.map((e) => e.naehrwerte).reduce((a, b) => a + b);
      final summe = (await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-01',
      ))['2099-03-01']!;

      expect(summe.kcal, vonHand.kcal);
      expect(summe.eiweissG, vonHand.eiweissG);
      expect(summe.kohlenhydrateG, vonHand.kohlenhydrateG);
      expect(summe.fettG, vonHand.fettG);
      expect(summe.zuckerG, vonHand.zuckerG);
      expect(summe.ballaststoffeG, vonHand.ballaststoffeG);
      expect(summe.gesaettigtG, vonHand.gesaettigtG);
      expect(summe.wasserMl, vonHand.wasserMl);
    });

    test('eine gewogene 0 bleibt 0, nicht null', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-03-01', kcal: 0, wasserMl: 0));

      final summe = (await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-01',
      ))['2099-03-01']!;
      expect(summe.kcal, 0);
      expect(summe.wasserMl, 0);
    });

    test('extra wird nicht summiert und ist leer', () async {
      final h = frisch();
      await h.repo.buche(eintrag(tag: '2099-03-01'));
      final summe = (await h.repo.tagessummen(
        von: '2099-03-01',
        bis: '2099-03-01',
      ))['2099-03-01']!;
      expect(summe.extra, isEmpty);
    });
  });

  group('Gefiltert und summiert wird in SQL (Hausregel 2)', () {
    test('jede Abfrage trägt ein WHERE, eine summiert mit GROUP BY', () async {
      final h = frisch();
      for (var i = 1; i <= 28; i++) {
        final tag = '2099-03-${i.toString().padLeft(2, '0')}';
        await h.repo.buche(eintrag(tag: tag));
        await h.repo.buche(eintrag(tag: tag));
      }

      h.mitschnitt.abfragen.clear();
      final summen = await h.repo.tagessummen(
        von: '2099-03-10',
        bis: '2099-03-23',
      );
      expect(summen, hasLength(14));

      final abfragen = [for (final a in h.mitschnitt.abfragen) a.toLowerCase()];
      expect(abfragen, isNotEmpty);
      for (final a in abfragen) {
        expect(
          a,
          contains('where'),
          reason:
              'eine Abfrage ohne Filter holte jede jemals gebuchte Mahlzeit '
              'in den Speicher: $a',
        );
      }
      expect(
        abfragen.where((a) => a.contains('group by') && a.contains('sum(')),
        isNotEmpty,
        reason: 'summiert wird in der Datenbank, nicht in Dart: $abfragen',
      );
    });

    test('die Zahl der Abfragen wächst nicht mit der Zahl der Tage', () async {
      final h = frisch();
      for (var i = 1; i <= 28; i++) {
        await h.repo.buche(
          eintrag(tag: '2099-03-${i.toString().padLeft(2, '0')}'),
        );
      }

      h.mitschnitt.abfragen.clear();
      await h.repo.tagessummen(von: '2099-03-01', bis: '2099-03-02');
      final kurz = h.mitschnitt.abfragen.length;

      h.mitschnitt.abfragen.clear();
      await h.repo.tagessummen(von: '2099-03-01', bis: '2099-03-28');
      final lang = h.mitschnitt.abfragen.length;

      expect(
        lang,
        kurz,
        reason: 'vierzehn Tage sind eine Abfrage, nicht vierzehn',
      );
    });
  });
}

/// Schreibt jede `SELECT`-Abfrage mit, die die Datenbank erreicht.
class _Mitschnitt extends QueryInterceptor {
  final abfragen = <String>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    abfragen.add(statement);
    return executor.runSelect(statement, args);
  }
}
