// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke für
// `IS NULL` in Abfragen) — die verdecken sonst die gleichnamigen
// `package:matcher`-Matcher, die `expect(..., isNull)` unten braucht.
// Dieselbe Begründung wie in `test/data/schema_v11_test.dart`, Zeile 1–4,
// nur um den zweiten Namen erweitert.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

/// Tests für den **Rundweg der Ernährungseinträge** — Task 3 des
/// Ernährungsplans (`docs/superpowers/plans/2026-11-03-ernaehrung.md`).
/// Die Tabellen und die Migration prüft `schema_v12_test.dart`; hier geht
/// es um das, was hinein- und wieder herauskommt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// In `lib/data/ernaehrung_repository.dart`:
///
/// ```dart
/// enum HealthStand { offen, geschrieben, nichtMoeglich }
///
/// @immutable
/// class Eintrag {
///   const Eintrag({
///     this.id,                       // null, bis gebucht ist
///     required this.tagesSchluessel, // ISO-Tagesstring, der **Esstag**
///     required this.mahlzeit,
///     required this.zeitpunkt,       // UTC
///     this.lebensmittelId,           // null beim Schnelleintrag
///     required this.name,
///     this.mengeG,                   // null beim Schnelleintrag
///     required this.naehrwerte,      // eingefroren, nicht verwiesen
///     this.healthUuid,
///     this.healthStand = HealthStand.offen,
///   });
///   // == und hashCode über alle Felder
/// }
///
/// class ErnaehrungRepository {
///   ErnaehrungRepository(AppCache db);
///   Future<List<Eintrag>> eintraegeAmTag(String tagesSchluessel);
///   Future<void> buche(Eintrag eintrag);
///   Future<void> loesche(int id);
///   Future<void> setzeHealthStand(int id, HealthStand stand);
///   Future<List<Eintrag>> offeneHealthEintraege();
/// }
/// ```
///
/// **`naehrwerte` ist ein `Naehrwerte` aus `trainings_core`** und deckt die
/// acht eingefrorenen Spalten **und** `extra` ab. Ein zweiter Typ für
/// dieselben acht Felder wäre eine zweite Stelle, an der `null` zu `0`
/// werden kann.
///
/// **`healthStand` hat einen Vorgabewert, `naehrwerte` nicht.** Ein frisch
/// gebuchter Eintrag steht auf `offen` — das ist der Normalfall und kein
/// Sonderfall, auch mit erteilter Freigabe (geschrieben wird danach).
/// Nährwerte dagegen vorzubelegen hieße, eine leere Mahlzeit stillschweigend
/// zu erlauben; wer nichts weiß, übergibt `const Naehrwerte()` und hat es
/// dann gesagt.
///
/// **Beide Listen kommen nach `zeitpunkt` aufsteigend.** Eine Entscheidung,
/// die Plan und Entwurf offenließen: Der Mahlzeitenschirm zeigt die
/// Einträge in der Reihenfolge, in der gegessen wurde, und der
/// Health-Nachlauf trägt das Älteste zuerst nach. Ohne feste Reihenfolge
/// hinge beides an der Vergabe der Zeilennummern.
///
/// **Was diese Datei nicht festlegt:** was `buche` mit einem Eintrag tut,
/// dessen `id` schon gesetzt ist. Bearbeiten ist Task 7; hier wird immer
/// mit `id: null` gebucht.
///
/// ## Die eigene Tabelle ist die Wahrheit
///
/// Das ist die Umkehrung vom 03.11.2026, und sie trägt zwei Regeln:
///
/// - **Gebucht wird immer**, auch ohne Health-Freigabe. `healthStand`
///   hält fest, was aus der Kopie geworden ist — `offen` heißt „noch
///   nicht geschrieben", nicht „nicht gespeichert".
/// - **Die Nährwerte sind eingefroren, nicht verwiesen.** Das Lebensmittel
///   ist Vorlage, der Eintrag ist Tatsache. Wird die Vorlage korrigiert
///   oder gelöscht, steht der Eintrag unverändert da.
///
/// ## Alle Werte hier sind erfunden
///
/// Keine echten Gesundheitsdaten, auch nicht in einem Test (`CLAUDE.md`).
/// Die Tagesschlüssel liegen im Jahr 2099, damit sie keinen Termin
/// nachahmen; die Zahlen sind erkennbar künstlich und ernährungsphysiologisch
/// Unsinn.
void main() {
  // --- Tage und Zeitpunkte -------------------------------------------

  const tagA = '2099-03-01';
  const tagB = '2099-03-02';
  const tagC = '2099-03-03';

  /// 2099-03-01, 12:30 Berliner Wanduhr. Im März gilt noch Winterzeit
  /// (die Umstellung liegt am letzten Sonntag des Monats), also UTC+1.
  final mittagA = DateTime.utc(2099, 3, 1, 11, 30);

  /// 2099-03-01, 19:00 Berliner Wanduhr.
  final abendA = DateTime.utc(2099, 3, 1, 18);

  /// 2099-03-02, 01:30 Berliner Wanduhr — der **Abend des 1. März**.
  /// Der Kalendertag dieses Zeitpunkts ist der 2., der Esstag der 1.
  final nachtsNachA = DateTime.utc(2099, 3, 2, 0, 30);

  // --- Hilfsmittel ---------------------------------------------------

  AppCache frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Eintrag eintrag({
    String tagesSchluessel = tagA,
    Mahlzeit mahlzeit = Mahlzeit.mittag,
    DateTime? zeitpunkt,
    int? lebensmittelId,
    String name = 'Grützwurst mit Kompott',
    double? mengeG = 333.3,
    Naehrwerte naehrwerte = const Naehrwerte(kcal: 1234.5),
    String? healthUuid,
    HealthStand healthStand = HealthStand.offen,
  }) => Eintrag(
    tagesSchluessel: tagesSchluessel,
    mahlzeit: mahlzeit,
    zeitpunkt: zeitpunkt ?? mittagA,
    lebensmittelId: lebensmittelId,
    name: name,
    mengeG: mengeG,
    naehrwerte: naehrwerte,
    healthUuid: healthUuid,
    healthStand: healthStand,
  );

  /// Wie viele Zeilen wirklich in `eintraege` stehen — gefragt wird die
  /// Datei, nicht das Repository. Sonst prüfte ein Test über „nichts
  /// gelöscht" nur, dass dieselbe Abfrage zweimal dasselbe sagt.
  Future<int> zeilenInsgesamt(AppCache db) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS anzahl FROM eintraege;')
        .getSingle();
    return zeile.read<int>('anzahl');
  }

  /// Der rohe Text einer Spalte, Zeile für Zeile — für die beiden Fälle, in
  /// denen die abgelegte Form selbst Vertrag ist.
  Future<List<String>> roherText(AppCache db, String spalte) async {
    final zeilen = await db
        .customSelect('SELECT $spalte AS wert FROM eintraege ORDER BY id;')
        .get();
    return zeilen.map((z) => z.read<String>('wert')).toList();
  }

  // ---------------------------------------------------------------------

  group('Buchen und Lesen — was hineinging, kommt heraus', () {
    test('ein vollständiger Eintrag kommt feldweise zurück', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: abendA,
          lebensmittelId: 4242,
          name: 'Grützwurst mit Kompott',
          mengeG: 333.3,
          naehrwerte: const Naehrwerte(
            kcal: 1234.5,
            eiweissG: 11.1,
            kohlenhydrateG: 22.2,
            fettG: 33.3,
            zuckerG: 44.4,
            ballaststoffeG: 55.5,
            gesaettigtG: 66.6,
            wasserMl: 77.7,
            extra: {'vitaminC': 2.0, 'eisenMg': 1.5},
          ),
          healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
          healthStand: HealthStand.geschrieben,
        ),
      );

      final gelesen = (await repo.eintraegeAmTag(tagA)).single;

      expect(
        gelesen.id,
        isNotNull,
        reason:
            'ohne id gibt es kein loesche und kein setzeHealthStand — der '
            'gelesene Eintrag trägt den Schlüssel, unter dem er steht',
      );
      expect(gelesen.tagesSchluessel, tagA);
      expect(gelesen.mahlzeit, Mahlzeit.abend);
      expect(
        gelesen.zeitpunkt,
        abendA,
        reason:
            'derselbe Zeitpunkt, und zwar als UTC. Driftets Standard gäbe '
            'ihn als Ortszeit zurück, und zwei DateTime desselben '
            'Zeitpunkts mit verschiedenem isUtc sind in Dart nicht gleich',
      );
      expect(gelesen.zeitpunkt.isUtc, isTrue);
      expect(gelesen.lebensmittelId, 4242);
      expect(gelesen.name, 'Grützwurst mit Kompott');
      expect(gelesen.mengeG, 333.3);
      expect(
        gelesen.naehrwerte,
        const Naehrwerte(
          kcal: 1234.5,
          eiweissG: 11.1,
          kohlenhydrateG: 22.2,
          fettG: 33.3,
          zuckerG: 44.4,
          ballaststoffeG: 55.5,
          gesaettigtG: 66.6,
          wasserMl: 77.7,
          extra: {'vitaminC': 2.0, 'eisenMg': 1.5},
        ),
        reason:
            'acht Spalten und die JSON-Spalte extra ergeben zusammen genau '
            'das, was gebucht wurde',
      );
      expect(gelesen.healthUuid, 'EFCE1111-2222-3333-4444-555566667777');
      expect(gelesen.healthStand, HealthStand.geschrieben);
    });

    test('mehrere Einträge eines Tages kommen nach Zeitpunkt sortiert', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(mahlzeit: Mahlzeit.abend, zeitpunkt: abendA, name: 'Abend'),
      );
      await repo.buche(
        eintrag(mahlzeit: Mahlzeit.mittag, zeitpunkt: mittagA, name: 'Mittag'),
      );

      expect(
        (await repo.eintraegeAmTag(tagA)).map((e) => e.name),
        ['Mittag', 'Abend'],
        reason:
            'die Reihenfolge ist die, in der gegessen wurde — nicht die, in '
            'der gebucht wurde. Sonst hinge der Mahlzeitenschirm an der '
            'Vergabe der Zeilennummern',
      );
    });

    test('ein Tag ohne Einträge antwortet mit einer leeren Liste', () async {
      final repo = ErnaehrungRepository(frisch());

      expect(
        await repo.eintraegeAmTag(tagA),
        isEmpty,
        reason:
            'nicht null. Für Tims eigene Daten gibt es keinen Lauf, der '
            'leer ausgehen kann — leer heißt hier schlicht leer '
            '(`CLAUDE.md`, „Messwert<T> gilt nur für Abgeleitetes aus '
            'Apple Health")',
      );
    });

    test('die Mahlzeit liegt als Name in der Datei, nicht als Zahl', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(
        eintrag(mahlzeit: Mahlzeit.fruehstueck, zeitpunkt: mittagA),
      );

      expect(
        await roherText(db, 'mahlzeit'),
        ['fruehstueck'],
        reason:
            'eine abgelegte Ordnungszahl verschiebt sich lautlos, sobald '
            'jemand die Reihenfolge der Enum-Fälle ändert — und auf dem '
            'iPhone liegt Tims einzige Kopie. Der Name überlebt das',
      );
    });
  });

  group('eintraegeAmTag filtert in SQL, nicht hinterher in Dart', () {
    test('nur der gefragte Tag kommt zurück, die anderen bleiben stehen', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A'));
      await repo.buche(eintrag(tagesSchluessel: tagB, name: 'B'));
      await repo.buche(eintrag(tagesSchluessel: tagC, name: 'C'));

      expect((await repo.eintraegeAmTag(tagB)).map((e) => e.name), ['B']);
      expect(
        await zeilenInsgesamt(db),
        3,
        reason: 'lesen ist lesen — eine Abfrage nimmt keine Zeile weg',
      );
    });

    test(
      'und die Abfrage gegen eintraege trägt den Tagesschlüssel bei sich',
      () async {
        final mitschrift = _Mitschrift();
        final db = AppCache(
          NativeDatabase.memory().interceptWith(mitschrift),
        );
        addTearDown(db.close);
        final repo = ErnaehrungRepository(db);

        await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A'));
        await repo.buche(eintrag(tagesSchluessel: tagB, name: 'B'));

        mitschrift.gelesen.clear();
        expect((await repo.eintraegeAmTag(tagA)).map((e) => e.name), ['A']);

        final gegenEintraege = mitschrift.gelesen
            .where((abfrage) => abfrage.sql.contains('eintraege'))
            .toList();

        expect(
          gegenEintraege,
          isNotEmpty,
          reason:
              'Vorbedingung: Die Mitschrift hat die Abfrage überhaupt '
              'gesehen. Sieht sie keine, prüft der Fall darunter nichts',
        );

        for (final abfrage in gegenEintraege) {
          expect(
            abfrage.args.contains(tagA) || abfrage.sql.contains(tagA),
            isTrue,
            reason:
                'gefiltert wird in SQL (`WHERE tages_schluessel = ?`). Eine '
                'Abfrage ohne den Tagesschlüssel holt jede jemals gebuchte '
                'Mahlzeit in den Speicher und wirft sie in Dart wieder weg '
                '— das wächst mit jedem Monat, den Tim die App benutzt, und '
                'ist Fehler 03 in der Datenschicht. Gefunden: '
                '${abfrage.sql}',
          );
        }
      },
    );
  });

  group('Der Schnelleintrag — ohne Lebensmittel und ohne Gewicht', () {
    test('lässt sich buchen und wieder lesen', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(
          lebensmittelId: null,
          mengeG: null,
          name: 'Kantine, geschätzt',
          naehrwerte: const Naehrwerte(kcal: 777.7),
        ),
      );

      final gelesen = (await repo.eintraegeAmTag(tagA)).single;
      expect(gelesen.name, 'Kantine, geschätzt');
      expect(
        gelesen.lebensmittelId,
        isNull,
        reason:
            'der Schnelleintrag „nur Kalorien" hat keines, und jede Abfrage '
            'muss das aushalten (Entwurf, „Schnelleintrag und Favoriten")',
      );
      expect(
        gelesen.mengeG,
        isNull,
        reason:
            'nicht 0. „0 g gegessen" ist eine Behauptung, kein fehlender '
            'Wert',
      );
      expect(gelesen.naehrwerte.kcal, 777.7);
      expect(gelesen.naehrwerte.eiweissG, isNull);
    });

    test('und steht den übrigen Abfragen genauso zur Verfügung', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(
          lebensmittelId: null,
          mengeG: null,
          name: 'Kantine, geschätzt',
          naehrwerte: const Naehrwerte(kcal: 777.7),
        ),
      );

      final offen = await repo.offeneHealthEintraege();
      expect(
        offen.map((e) => e.name),
        ['Kantine, geschätzt'],
        reason:
            'der Health-Nachlauf stolpert nicht über einen Eintrag ohne '
            'Lebensmittel — er schreibt Nährwerte, keine Vorlagen',
      );

      await repo.setzeHealthStand(offen.single.id!, HealthStand.geschrieben);
      expect(await repo.offeneHealthEintraege(), isEmpty);

      await repo.loesche(offen.single.id!);
      expect(await repo.eintraegeAmTag(tagA), isEmpty);
    });
  });

  group('Eine leere Liste löscht den Tag nicht (#142)', () {
    /// Die Altapp hatte beide Hälften des Fehlers: `schreibeErnaehrungsTage`
    /// verwarf die leere Liste, `schreibeMahlzeiten` leerte dafür den Tag.
    /// Der Schnitt hier macht das unausdrückbar — es gibt keinen Schreibweg,
    /// der einen ganzen Tag ersetzt, nur `buche` und `loesche(id)`. Die
    /// Tests halten fest, dass das so bleibt.
    test('ein leerer Tag nimmt dem Nachbartag nichts weg', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A1'));
      await repo.buche(
        eintrag(tagesSchluessel: tagA, zeitpunkt: abendA, name: 'A2'),
      );

      expect(await repo.eintraegeAmTag(tagB), isEmpty);
      expect(await repo.eintraegeAmTag(tagB), isEmpty);

      expect(
        (await repo.eintraegeAmTag(tagA)).map((e) => e.name),
        ['A1', 'A2'],
        reason:
            'ein Tag ohne Mahlzeiten ist ein Tag ohne Mahlzeiten und kein '
            'Auftrag, etwas zu leeren — genau das war #142 in der Altapp',
      );
      expect(await zeilenInsgesamt(db), 2);
    });

    test('und auf einen leeren Tag lässt sich danach buchen', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A1'));
      expect(await repo.eintraegeAmTag(tagB), isEmpty);

      await repo.buche(eintrag(tagesSchluessel: tagB, name: 'B1'));

      expect((await repo.eintraegeAmTag(tagB)).map((e) => e.name), ['B1']);
      expect((await repo.eintraegeAmTag(tagA)).map((e) => e.name), ['A1']);
      expect(await zeilenInsgesamt(db), 2);
    });

    test('loesche nimmt genau eine Zeile, nicht den Tag', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A1'));
      await repo.buche(
        eintrag(tagesSchluessel: tagA, zeitpunkt: abendA, name: 'A2'),
      );
      await repo.buche(eintrag(tagesSchluessel: tagB, name: 'B1'));

      final zuLoeschen = (await repo.eintraegeAmTag(tagA)).first;
      await repo.loesche(zuLoeschen.id!);

      expect((await repo.eintraegeAmTag(tagA)).map((e) => e.name), ['A2']);
      expect((await repo.eintraegeAmTag(tagB)).map((e) => e.name), ['B1']);
      expect(await zeilenInsgesamt(db), 2);
    });

    test('eine unbekannte id zu löschen ändert nichts', () async {
      final db = frisch();
      final repo = ErnaehrungRepository(db);

      await repo.buche(eintrag(tagesSchluessel: tagA, name: 'A1'));
      final bekannt = (await repo.eintraegeAmTag(tagA)).single.id!;

      await repo.loesche(bekannt + 999);

      expect(
        await zeilenInsgesamt(db),
        1,
        reason:
            'ein zweiter Druck auf „Löschen" oder ein Nachlauf auf einem '
            'längst gelöschten Eintrag darf nicht mehr wegnehmen als die '
            'eine Zeile, die es nicht mehr gibt',
      );
    });
  });

  group('Eingefrorene Nährwerte — der Eintrag ist Tatsache', () {
    test(
      'zwei Einträge desselben Lebensmittels behalten ihre eigenen Zahlen',
      () async {
        final repo = ErnaehrungRepository(frisch());

        await repo.buche(
          eintrag(
            lebensmittelId: 4242,
            zeitpunkt: mittagA,
            name: 'Grütze, alte Angabe',
            mengeG: 100,
            naehrwerte: const Naehrwerte(kcal: 111.1, eiweissG: 1.1),
          ),
        );
        await repo.buche(
          eintrag(
            lebensmittelId: 4242,
            zeitpunkt: abendA,
            name: 'Grütze, korrigiert',
            mengeG: 100,
            naehrwerte: const Naehrwerte(kcal: 999.9, eiweissG: 9.9),
          ),
        );

        final gelesen = await repo.eintraegeAmTag(tagA);
        expect(gelesen.map((e) => e.naehrwerte.kcal), [111.1, 999.9]);
        expect(
          gelesen.map((e) => e.name),
          ['Grütze, alte Angabe', 'Grütze, korrigiert'],
          reason:
              'beide zeigen auf dasselbe Lebensmittel und tragen trotzdem '
              'verschiedene Zahlen. Wer stattdessen verweist, kann das '
              'nicht — und der Januar sähe nach jeder Korrektur anders aus '
              'als damals',
        );
      },
    );

    test(
      'und ein Eintrag bleibt lesbar, wenn es sein Lebensmittel nicht mehr '
      'gibt',
      () async {
        final repo = ErnaehrungRepository(frisch());

        await repo.buche(
          eintrag(
            lebensmittelId: 999999,
            name: 'Grützwurst mit Kompott',
            naehrwerte: const Naehrwerte(kcal: 1234.5, eiweissG: 11.1),
          ),
        );

        final gelesen = (await repo.eintraegeAmTag(tagA)).single;
        expect(gelesen.lebensmittelId, 999999);
        expect(
          gelesen.name,
          'Grützwurst mit Kompott',
          reason:
              'zu dieser Nummer steht keine Zeile in `lebensmittel`. Wer '
              'den Namen oder die Nährwerte über einen Verbund holt, '
              'verliert hier den Eintrag — und der ist Tims Tatsache, nicht '
              'die Vorlage',
        );
        expect(gelesen.naehrwerte.kcal, 1234.5);
        expect(gelesen.naehrwerte.eiweissG, 11.1);
      },
    );
  });

  group('Fehlende Werte bleiben null, auch in extra (#232)', () {
    test('ein Eintrag ganz ohne Nährwerte hat achtmal null', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(eintrag(naehrwerte: const Naehrwerte()));

      final gelesen = (await repo.eintraegeAmTag(tagA)).single.naehrwerte;
      expect(
        gelesen,
        const Naehrwerte(),
        reason:
            'keine Angabe ist keine Angabe. Käme das als lauter Nullen '
            'zurück, stünde auf dem Ring „nichts gegessen" statt „nichts '
            'bekannt" — das ist 01 in neuer Verpackung',
      );
      expect(gelesen.kcal, isNull);
      expect(gelesen.ballaststoffeG, isNull);
      expect(gelesen.wasserMl, isNull);
      expect(gelesen.extra, isEmpty);
    });

    test(
      'ein einzelner fehlender Wert bleibt null, während die übrigen tragen',
      () async {
        final repo = ErnaehrungRepository(frisch());

        await repo.buche(
          eintrag(
            naehrwerte: const Naehrwerte(
              kcal: 1234.5,
              eiweissG: 11.1,
              kohlenhydrateG: 22.2,
              fettG: 33.3,
            ),
          ),
        );

        final gelesen = (await repo.eintraegeAmTag(tagA)).single.naehrwerte;
        expect(gelesen.kcal, 1234.5);
        expect(
          gelesen.ballaststoffeG,
          isNull,
          reason:
              'ein Lebensmittel ohne Ballaststoffangabe hat keine '
              'Ballaststoffe von null. Die Tagessumme darüber bleibt '
              'deshalb ebenfalls null (Review Focus 2 des Plans)',
        );
        expect(gelesen.zuckerG, isNull);
        expect(gelesen.gesaettigtG, isNull);
      },
    );

    test('eine gewogene Null ist etwas anderes als keine Angabe', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(naehrwerte: const Naehrwerte(kcal: 0, zuckerG: 0)),
      );

      final gelesen = (await repo.eintraegeAmTag(tagA)).single.naehrwerte;
      expect(
        gelesen.kcal,
        0,
        reason:
            'Mineralwasser hat 0 kcal, und das ist eine Messung. Ein '
            'Schreibweg, der 0 für „leer" hält, wirft genau diese Angabe weg',
      );
      expect(gelesen.zuckerG, 0);
      expect(gelesen.fettG, isNull);
    });

    test('und in extra bleibt ein bekannt-unbekannter Wert null', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(
          naehrwerte: const Naehrwerte(
            kcal: 1234.5,
            extra: {'vitaminC': 2.0, 'eisenMg': null},
          ),
        ),
      );

      final gelesen = (await repo.eintraegeAmTag(tagA)).single.naehrwerte;
      expect(gelesen.extra['vitaminC'], 2.0);
      expect(
        gelesen.extra.containsKey('eisenMg'),
        isTrue,
        reason:
            'der Schlüssel bleibt — „bekannt als unbekannt" ist eine andere '
            'Auskunft als „nie gefragt"',
      );
      expect(
        gelesen.extra['eisenMg'],
        isNull,
        reason:
            'das Austauschformat 4.11 schreibt in der Exportdatei 0 für '
            'nicht erfasste Werte. Das ist die Regel für die Datei, nicht '
            'für die Datenbank (Entwurf, „Die Tabellen")',
      );
    });
  });

  group('Der Health-Stand — gebucht wird immer', () {
    test('ein frisch gebuchter Eintrag steht auf offen, ohne UUID', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        Eintrag(
          tagesSchluessel: tagA,
          mahlzeit: Mahlzeit.mittag,
          zeitpunkt: mittagA,
          name: 'Grützwurst mit Kompott',
          naehrwerte: const Naehrwerte(kcal: 1234.5),
        ),
      );

      final gelesen = (await repo.eintraegeAmTag(tagA)).single;
      expect(
        gelesen.healthStand,
        HealthStand.offen,
        reason:
            'die eigene Tabelle ist die Wahrheit, Health die Kopie. Eine '
            'fehlende Kopie hält niemanden auf — sie bleibt offen, bis der '
            'Nachlauf sie nachträgt',
      );
      expect(gelesen.healthUuid, isNull);
    });

    test('offeneHealthEintraege findet genau die offenen, über alle Tage', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(tagesSchluessel: tagA, zeitpunkt: mittagA, name: 'offen 1'),
      );
      await repo.buche(
        eintrag(
          tagesSchluessel: tagA,
          zeitpunkt: abendA,
          name: 'geschrieben',
          healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
          healthStand: HealthStand.geschrieben,
        ),
      );
      await repo.buche(
        eintrag(
          tagesSchluessel: tagB,
          zeitpunkt: DateTime.utc(2099, 3, 2, 11, 30),
          name: 'nicht moeglich',
          healthStand: HealthStand.nichtMoeglich,
        ),
      );
      await repo.buche(
        eintrag(
          tagesSchluessel: tagC,
          zeitpunkt: DateTime.utc(2099, 3, 3, 11, 30),
          name: 'offen 2',
        ),
      );

      expect(
        (await repo.offeneHealthEintraege()).map((e) => e.name),
        ['offen 1', 'offen 2'],
        reason:
            'der Nachlauf fragt nicht nach einem Tag, sondern nach allem, '
            'was noch nicht drüben ist — und trägt das Älteste zuerst nach. '
            '`nicht_moeglich` ist nicht dabei: Den Typ hat HealthKit '
            'abgelehnt, der wird nicht endlos erneut versucht',
      );
    });

    test('setzeHealthStand schaltet um und nimmt den Eintrag aus der Liste', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(eintrag(name: 'A1'));
      await repo.buche(eintrag(zeitpunkt: abendA, name: 'A2'));

      final offen = await repo.offeneHealthEintraege();
      expect(offen, hasLength(2), reason: 'Vorbedingung');

      await repo.setzeHealthStand(offen.first.id!, HealthStand.geschrieben);

      expect(
        (await repo.offeneHealthEintraege()).map((e) => e.name),
        ['A2'],
      );
      final amTag = await repo.eintraegeAmTag(tagA);
      expect(amTag.first.healthStand, HealthStand.geschrieben);
      expect(
        amTag.last.healthStand,
        HealthStand.offen,
        reason:
            'umgeschaltet wird genau eine Zeile. Ein Update ohne '
            'WHERE id = ? setzte den Stand des ganzen Tages',
      );
    });

    test('nicht_moeglich bleibt stehen und wird nicht wieder offen', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(eintrag(name: 'A1'));
      final id = (await repo.eintraegeAmTag(tagA)).single.id!;

      await repo.setzeHealthStand(id, HealthStand.nichtMoeglich);

      expect((await repo.eintraegeAmTag(tagA)).single.healthStand,
          HealthStand.nichtMoeglich);
      expect(
        await repo.offeneHealthEintraege(),
        isEmpty,
        reason:
            'nicht_moeglich ist der Fall, in dem HealthKit den Typ '
            'abgelehnt hat. Käme er wieder in die Liste, liefe der Nachlauf '
            'bei jedem Start gegen dieselbe Wand',
      );
    });

    test(
      'die drei Stände liegen als die drei Wörter aus dem Entwurf in der '
      'Datei',
      () async {
        final db = frisch();
        final repo = ErnaehrungRepository(db);

        await repo.buche(eintrag(zeitpunkt: mittagA, name: 'A1'));
        await repo.buche(
          eintrag(
            zeitpunkt: abendA,
            name: 'A2',
            healthStand: HealthStand.geschrieben,
          ),
        );
        await repo.buche(
          eintrag(
            zeitpunkt: nachtsNachA,
            mahlzeit: Mahlzeit.abend,
            name: 'A3',
            healthStand: HealthStand.nichtMoeglich,
          ),
        );

        expect(
          await roherText(db, 'health_stand'),
          ['offen', 'geschrieben', 'nicht_moeglich'],
          reason:
              'so benennt der Entwurf die Spalte („Wenn die Schreibfreigabe '
              'fehlt"). Eine abgelegte Ordnungszahl verschöbe sich lautlos, '
              'sobald jemand die Reihenfolge der Enum-Fälle ändert — und '
              'auf dem iPhone liegt Tims einzige Kopie',
        );
      },
    );
  });

  group('Der Abend über Mitternacht', () {
    test('die Vorbedingung stimmt: 01:30 in Berlin ist der Abend davor', () {
      final (stunde, minute) = BerlinCalendar.wallClock(nachtsNachA);
      expect((stunde, minute), (1, 30), reason: 'im März gilt noch UTC+1');
      expect(
        Mahlzeitfenster.fuer(stunde * 60 + minute),
        Mahlzeit.abend,
        reason:
            'der Abend läuft bis 03:59 und umschließt Mitternacht. Diese '
            'Prüfung steht hier, damit der Fall unten nicht auf einem '
            'Zahlendreher der Vorlage steht — in den DataWindow-Tests '
            'paarten drei Fälle 00:05 mit 23:30 UTC und behaupteten '
            'denselben Berliner Tag',
      );
      expect(
        BerlinCalendar.dayKey(nachtsNachA),
        tagB,
        reason:
            'der Kalendertag dieses Zeitpunkts ist der 2. — der Esstag ist '
            'der 1., und genau deshalb gibt es beide Felder',
      );
    });

    test(
      'ein Eintrag um 01:30 steht beim Vortag, nicht beim Folgetag',
      () async {
        final repo = ErnaehrungRepository(frisch());

        await repo.buche(
          eintrag(
            tagesSchluessel: tagA,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: nachtsNachA,
            name: 'Grützwurst, spät',
          ),
        );

        expect(
          (await repo.eintraegeAmTag(tagA)).map((e) => e.name),
          ['Grützwurst, spät'],
          reason:
              'gefiltert wird über den Esstag. Wer stattdessen aus dem '
              'Zeitpunkt filtert, verschiebt jede späte Mahlzeit auf den '
              'Folgetag — und das fällt erst nach Wochen auf',
        );
        expect(await repo.eintraegeAmTag(tagB), isEmpty);

        final gelesen = (await repo.eintraegeAmTag(tagA)).single;
        expect(gelesen.mahlzeit, Mahlzeit.abend);
        expect(
          gelesen.zeitpunkt,
          nachtsNachA,
          reason:
              'der Zeitpunkt bleibt, wie er war — er wird nicht auf den '
              'Esstag zurückgebogen. Die beiden Felder sagen '
              'Verschiedenes, und beide stimmen',
        );
      },
    );

    test(
      'derselbe Zeitpunkt mit dem Folgetag als Schlüssel steht beim '
      'Folgetag — die Datenschicht rechnet den Esstag nicht aus',
      () async {
        final repo = ErnaehrungRepository(frisch());

        await repo.buche(
          eintrag(
            tagesSchluessel: tagB,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: nachtsNachA,
            name: 'auf den Folgetag gebucht',
          ),
        );

        expect(
          (await repo.eintraegeAmTag(tagB)).map((e) => e.name),
          ['auf den Folgetag gebucht'],
          reason:
              'der Esstag kommt vom Buchungsblatt — Tim kann die Mahlzeit '
              'dort auf einen anderen Tag legen, und wer über ‹ › einen '
              'Tag offen hat, meint diesen Tag. Eine Datenschicht, die ihn '
              'selbst ausrechnet, überstimmt das stillschweigend',
        );
        expect(await repo.eintraegeAmTag(tagA), isEmpty);
      },
    );

    test('und die späte Mahlzeit steht am Ende ihres Esstags', () async {
      final repo = ErnaehrungRepository(frisch());

      await repo.buche(
        eintrag(zeitpunkt: mittagA, name: 'Mittag'),
      );
      await repo.buche(
        eintrag(
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: nachtsNachA,
          name: 'Nachtisch um halb zwei',
        ),
      );
      await repo.buche(
        eintrag(mahlzeit: Mahlzeit.abend, zeitpunkt: abendA, name: 'Abend'),
      );

      expect(
        (await repo.eintraegeAmTag(tagA)).map((e) => e.name),
        ['Mittag', 'Abend', 'Nachtisch um halb zwei'],
        reason:
            'nach Zeitpunkt aufsteigend — und der späteste Zeitpunkt dieses '
            'Esstags liegt kalendarisch am nächsten Morgen',
      );
    });
  });

  group('Wertgleichheit — ohne sie rechnet Riverpod alles neu', () {
    Eintrag grund() => Eintrag(
      id: 7,
      tagesSchluessel: tagA,
      mahlzeit: Mahlzeit.abend,
      zeitpunkt: abendA,
      lebensmittelId: 4242,
      name: 'Grützwurst mit Kompott',
      mengeG: 333.3,
      naehrwerte: const Naehrwerte(kcal: 1234.5, extra: {'vitaminC': 2.0}),
      healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
      healthStand: HealthStand.geschrieben,
    );

    test('zwei Einträge mit denselben Werten sind gleich', () {
      expect(
        grund(),
        grund(),
        reason:
            'die Tagesliste ist Abhängigkeit eines Providers. Ohne '
            'Wertgleichheit baute jeder Lesevorgang neue, ungleiche Objekte, '
            'und Ring, Makros und Verlauf rechneten bei jedem Zugriff neu — '
            'Fehler 03, wortgleich, im neuen Code',
      );
      expect(grund().hashCode, grund().hashCode);
    });

    test('ein einziges abweichendes Feld macht sie ungleich', () {
      expect(
        grund(),
        isNot(
          Eintrag(
            id: 8,
            tagesSchluessel: tagA,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: abendA,
            lebensmittelId: 4242,
            name: 'Grützwurst mit Kompott',
            mengeG: 333.3,
            naehrwerte: const Naehrwerte(
              kcal: 1234.5,
              extra: {'vitaminC': 2.0},
            ),
            healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
            healthStand: HealthStand.geschrieben,
          ),
        ),
        reason: 'eine andere id ist ein anderer Eintrag',
      );

      expect(
        grund(),
        isNot(
          Eintrag(
            id: 7,
            tagesSchluessel: tagB,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: abendA,
            lebensmittelId: 4242,
            name: 'Grützwurst mit Kompott',
            mengeG: 333.3,
            naehrwerte: const Naehrwerte(
              kcal: 1234.5,
              extra: {'vitaminC': 2.0},
            ),
            healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
            healthStand: HealthStand.geschrieben,
          ),
        ),
      );

      expect(
        grund(),
        isNot(
          Eintrag(
            id: 7,
            tagesSchluessel: tagA,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: abendA,
            lebensmittelId: 4242,
            name: 'Grützwurst mit Kompott',
            mengeG: 333.3,
            naehrwerte: const Naehrwerte(
              kcal: 1234.5,
              extra: {'vitaminC': 1.5},
            ),
            healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
            healthStand: HealthStand.geschrieben,
          ),
        ),
        reason:
            'auch extra zählt mit — sonst wäre eine korrigierte '
            'Mikronährstoffangabe gleich der alten',
      );

      expect(
        grund(),
        isNot(
          Eintrag(
            id: 7,
            tagesSchluessel: tagA,
            mahlzeit: Mahlzeit.abend,
            zeitpunkt: abendA,
            lebensmittelId: 4242,
            name: 'Grützwurst mit Kompott',
            mengeG: 333.3,
            naehrwerte: const Naehrwerte(
              kcal: 1234.5,
              extra: {'vitaminC': 2.0},
            ),
            healthUuid: 'EFCE1111-2222-3333-4444-555566667777',
            healthStand: HealthStand.offen,
          ),
        ),
        reason:
            'der Health-Stand gehört zum Wert. Ohne ihn merkte der Schirm '
            'nicht, dass der Nachlauf durch ist',
      );
    });

    test('ein fehlendes Feld ist nicht dasselbe wie ein eingetragenes', () {
      final ohneMenge = Eintrag(
        tagesSchluessel: tagA,
        mahlzeit: Mahlzeit.mittag,
        zeitpunkt: mittagA,
        name: 'Kantine, geschätzt',
        naehrwerte: const Naehrwerte(kcal: 777.7),
      );
      final mitNullGramm = Eintrag(
        tagesSchluessel: tagA,
        mahlzeit: Mahlzeit.mittag,
        zeitpunkt: mittagA,
        name: 'Kantine, geschätzt',
        mengeG: 0,
        naehrwerte: const Naehrwerte(kcal: 777.7),
      );

      expect(
        ohneMenge,
        isNot(mitNullGramm),
        reason:
            'genau diese Unterscheidung trägt den ganzen Schirm: '
            '„nicht gewogen" ist nicht „0 g gegessen"',
      );
    });
  });
}

/// Schreibt jede Leseabfrage mit, die drift gegen die Datei absetzt.
///
/// Damit lässt sich prüfen, **wo** gefiltert wird — und das ist der Kern
/// von Hausregel 2 (`CLAUDE.md`): Was eine Ansicht braucht, wird gehalten
/// und in SQL eingegrenzt, nicht bei jedem Zugriff in Dart aussortiert.
/// Eine Dart-Filterung sähe von außen genauso aus, solange man nur die
/// Rückgabe ansieht; sie fällt erst auf, wenn man die abgesetzte Anweisung
/// liest.
class _Mitschrift extends QueryInterceptor {
  final List<({String sql, List<Object?> args})> gelesen = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    gelesen.add((sql: statement, args: args));
    return executor.runSelect(statement, args);
  }
}
