// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke für
// `IS NULL` in Abfragen) — die verdecken sonst die gleichnamigen
// `package:matcher`-Matcher, die `expect(..., isNull)` unten braucht.
// Dieselbe Begründung wie in `test/data/ernaehrung_repository_test.dart`,
// Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/lebensmittel_repository.dart';

/// Tests für die **Vorlagenhälfte** der Ernährung — Lebensmittel anlegen,
/// wiederfinden, ändern (#285, zugeschnitten auf den vollständigen
/// Eintragweg **ohne** Barcode, Open Food Facts und Foto).
///
/// Die Tatsachenhälfte (`eintraege`) prüft
/// `test/data/ernaehrung_repository_test.dart`; hier geht es um das, was
/// die Suche findet und was das Buchungsblatt als Vorlage bekommt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/data/lebensmittel_repository.dart`:
///
/// ```dart
/// /// Ein Lebensmittel als **Vorlage** — Nährwerte je 100 g.
/// @immutable
/// class LebensmittelVorlage {
///   const LebensmittelVorlage({
///     this.id,                     // null, bis angelegt ist
///     required this.name,
///     required this.je100g,        // Naehrwerte, als Je-100-g-Angabe
///     this.fluessig = false,       // g oder ml — sonst nichts
///     this.zuletztBenutzt,         // UTC, null bis zum ersten Buchen
///   });
///   // == und hashCode über alle Felder
/// }
///
/// class LebensmittelRepository {
///   LebensmittelRepository(AppCache db);
///   Future<int> legeAn(LebensmittelVorlage vorlage);
///   Future<LebensmittelVorlage?> lies(int id);
///   Future<List<LebensmittelVorlage>> suche(String text, {int grenze = 25});
///   Future<void> aendere(LebensmittelVorlage vorlage);
///   Future<void> merkeBenutzung(int id, DateTime zeitpunkt);
/// }
///
/// final lebensmittelRepositoryProvider = Provider<LebensmittelRepository>(
///   (ref) => LebensmittelRepository(ref.watch(appCacheProvider)),
/// );
/// ```
///
/// Dafür bekommt `lebensmittel` in `lib/data/ernaehrung_tabellen.dart` die
/// Spalten, die der Entwurf ihr seit jeher zuschreibt: `name`, die acht
/// Nährwertspalten je 100 g, `extra`, `fluessig`, `zuletzt_benutzt`.
///
/// ## Entscheidung des Test-Agenten: der Werttyp heißt `LebensmittelVorlage`
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Bei
/// `Eintrag`/`Eintraege` trennt der Numerus Werttyp und Tabelle; bei
/// `Lebensmittel` gibt es keinen Numerus, der das könnte, und die Tabelle
/// trägt den Namen bereits (`schema_v12_test.dart` nagelt ihn fest). Zwei
/// gleichnamige Typen in einer Datei, die beide importiert, wären ein
/// Namenskonflikt. `Vorlage` ist dabei kein Hilfswort, sondern das Wort
/// des Entwurfs: „Das Lebensmittel ist Vorlage, der Eintrag ist Tatsache"
/// (`2026-11-03-ernaehrung-design.md`, „Eingefrorene Nährwerte").
///
/// ## Entscheidung des Test-Agenten: eine Suchmethode, nicht zwei
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Der
/// Entwurf verlangt zweierlei: Treffer zum Suchtext und, ohne Eingabe,
/// „zuletzt benutzt" statt einer leeren Seite (`erfassen.js`, `SUCHE`).
/// Das ist **dieselbe Liste in derselben Reihenfolge**, einmal gefiltert
/// und einmal nicht. Zwei Methoden wären zwei Sortierregeln, die
/// auseinanderlaufen können; `suche('')` ist die ungefilterte Fassung und
/// damit die Antwort auf beides.
///
/// Die Reihenfolge, einmal festgelegt und für beide Fälle gültig:
/// **zuletzt benutzt zuerst** (das Jüngste oben), **nie benutzte danach,
/// alphabetisch**. Was man schon einmal gegessen hat, isst man wieder;
/// was nie dran war, hat keine Rangfolge außer dem Namen.
///
/// ## Nachtrag #345: ohne Suchtext nur Gebuchtes, höchstens 10
///
/// **Tims Entscheidung vom 04.11.2026.** `suche('')` ist seitdem nicht
/// mehr die ungefilterte Fassung: Ohne Suchtext kommen nur Vorlagen mit
/// `zuletztBenutzt`, höchstens 10, das Jüngste oben. Mit Suchtext gilt
/// alles oben unverändert. Die Einzelheiten — samt der Prüfung, dass in
/// SQL gefiltert wird — stehen in `zuletzt_benutzt_test.dart`. **Geändert
/// vom Test-Agenten von #345**; die Fälle unten, die sich auf nie
/// benutzte Vorlagen ohne Suchtext stützten, sind so umgestellt, dass sie
/// ihre Aussage behalten.
///
/// ## Gefiltert wird in SQL
///
/// `CLAUDE.md`, Hausregel 2 und „Der Datumsschlüssel ist der
/// ISO-Tagesstring": Gefiltert wird in SQL, nicht nach dem Laden in Dart.
/// Der Fall „die Grenze schneidet nach dem Filtern ab, nicht davor"
/// beweist das von außen: Steht der einzige Treffer in der Reihenfolge
/// hinter der Grenze, findet ihn nur, wer `WHERE` vor `LIMIT` setzt.
///
/// ## Grenze: Groß-/Kleinschreibung gilt für ASCII
///
/// SQLites `LIKE` vergleicht ASCII-Buchstaben ohne Rücksicht auf die
/// Schreibweise, Umlaute aber **nicht**: „müsli" findet „Müsli" nicht.
/// Das ist hier bewusst nicht geprüft und bewusst nicht behauptet — eine
/// Zusicherung, die der Code nicht durchsetzt, ist schlimmer als gar keine
/// (`CLAUDE.md`). Wer das will, braucht `unicode61` oder eine
/// Normalspalte; das ist ein eigenes Ticket.
///
/// Zahlen und Namen in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  final gestern = DateTime.utc(2026, 7, 13, 10);
  final vorgestern = DateTime.utc(2026, 7, 12, 10);

  /// Die Zahlen von der Rückseite einer erfundenen Packung.
  const haferflocken = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
    ballaststoffeG: 10,
  );

  ({AppCache db, LebensmittelRepository repo}) aufbau() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return (db: db, repo: LebensmittelRepository(db));
  }

  LebensmittelVorlage vorlage({
    String name = 'Haferflocken kernig',
    Naehrwerte je100g = haferflocken,
    bool fluessig = false,
  }) => LebensmittelVorlage(name: name, je100g: je100g, fluessig: fluessig);

  // ─────────────────────────────────────────────────────────────────────
  group('Anlegen und wiederfinden', () {
    test(
      'legeAn vergibt einen Schlüssel und lies findet damit wieder',
      () async {
        final a = aufbau();

        final id = await a.repo.legeAn(vorlage());
        expect(id, greaterThan(0));

        final gelesen = await a.repo.lies(id);
        expect(gelesen, isNotNull);
        expect(gelesen!.id, id);
        expect(gelesen.name, 'Haferflocken kernig');
        expect(gelesen.je100g, haferflocken);
      },
    );

    test('zwei Lebensmittel bekommen verschiedene Schlüssel', () async {
      final a = aufbau();

      final eins = await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
      final zwei = await a.repo.legeAn(vorlage(name: 'Haferflocken zart'));

      expect(eins, isNot(zwei));
    });

    test('lies auf einen unbekannten Schlüssel ergibt null, keinen leeren '
        'Datensatz', () async {
      final a = aufbau();
      expect(await a.repo.lies(4711), isNull);
    });

    test(
      'ein frisch angelegtes Lebensmittel ist noch nie benutzt worden',
      () async {
        final a = aufbau();
        final id = await a.repo.legeAn(vorlage());

        // Nicht `DateTime(0)` und nicht „jetzt": Angelegt ist nicht benutzt.
        expect((await a.repo.lies(id))!.zuletztBenutzt, isNull);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Fehlende Werte bleiben null, nie 0', () {
    test('ein leer gelassenes Feld kommt als null zurück', () async {
      final a = aufbau();
      // Nur Name und Kalorien — der Pflichtteil des Blattes „anlegen".
      final id = await a.repo.legeAn(
        vorlage(je100g: const Naehrwerte.je100g(kcal: 372)),
      );

      final gelesen = (await a.repo.lies(id))!.je100g;
      expect(gelesen.kcal, 372);
      expect(gelesen.eiweissG, isNull);
      expect(gelesen.kohlenhydrateG, isNull);
      expect(gelesen.fettG, isNull);
      expect(gelesen.zuckerG, isNull);
      expect(gelesen.ballaststoffeG, isNull);
      expect(gelesen.gesaettigtG, isNull);
      expect(gelesen.wasserMl, isNull);
    });

    test(
      'eine eingetragene 0 bleibt 0 — Mineralwasser hat keine Kalorien',
      () async {
        final a = aufbau();
        final id = await a.repo.legeAn(
          vorlage(
            name: 'Mineralwasser',
            je100g: const Naehrwerte.je100g(
              kcal: 0,
              eiweissG: 0,
              kohlenhydrateG: 0,
              fettG: 0,
            ),
            fluessig: true,
          ),
        );

        final gelesen = (await a.repo.lies(id))!.je100g;
        expect(gelesen.kcal, 0);
        expect(gelesen.eiweissG, 0);
        expect(gelesen.kohlenhydrateG, 0);
        expect(gelesen.fettG, 0);
        // Und was nicht dastand, steht auch jetzt nicht da.
        expect(gelesen.zuckerG, isNull);
      },
    );

    test('ein Schlüssel in extra mit Wert null überlebt als null', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(
        vorlage(
          je100g: const Naehrwerte.je100g(
            kcal: 372,
            extra: {'eisenMg': 4.2, 'vitaminCMg': null},
          ),
        ),
      );

      final gelesen = (await a.repo.lies(id))!.je100g;
      expect(gelesen.extra['eisenMg'], 4.2);
      expect(gelesen.extra.containsKey('vitaminCMg'), isTrue);
      expect(gelesen.extra['vitaminCMg'], isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die Einheit entscheidet über g oder ml — sonst nichts', () {
    test(
      'fluessig steht vorgabemäßig auf falsch und überlebt den Rundweg',
      () async {
        final a = aufbau();

        final fest = await a.repo.legeAn(vorlage());
        final getraenk = await a.repo.legeAn(
          vorlage(name: 'Haferdrink', fluessig: true),
        );

        expect((await a.repo.lies(fest))!.fluessig, isFalse);
        expect((await a.repo.lies(getraenk))!.fluessig, isTrue);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die Suche', () {
    test(
      'findet über ein Teilwort und ohne Rücksicht auf die Schreibweise',
      () async {
        final a = aufbau();
        await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
        await a.repo.legeAn(vorlage(name: 'Hähnchenbrustfilet'));

        expect((await a.repo.suche('flocken')).map((l) => l.name), [
          'Haferflocken kernig',
        ]);
        expect((await a.repo.suche('HAFERFLOCKEN')).map((l) => l.name), [
          'Haferflocken kernig',
        ]);
      },
    );

    test('findet nichts, wenn nichts passt — und das ist eine leere Liste, '
        'nicht null', () async {
      final a = aufbau();
      await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));

      expect(await a.repo.suche('Lakritz'), isEmpty);
    });

    test('filtert in SQL: die Grenze schneidet nach dem Filtern ab, nicht '
        'davor', () async {
      final a = aufbau();
      // Vier Lebensmittel ohne Treffer stehen alphabetisch **vor** dem
      // einen Treffer. Wer erst `LIMIT 2` holt und danach in Dart filtert,
      // findet ihn nicht.
      for (final name in ['Apfel', 'Banane', 'Clementine', 'Dattel']) {
        await a.repo.legeAn(vorlage(name: name));
      }
      await a.repo.legeAn(vorlage(name: 'Zwieback'));

      final treffer = await a.repo.suche('Zwieback', grenze: 2);
      expect(treffer.map((l) => l.name), ['Zwieback']);
    });

    test('die Grenze begrenzt, was zurückkommt', () async {
      final a = aufbau();
      for (final name in ['Hafer A', 'Hafer B', 'Hafer C']) {
        await a.repo.legeAn(vorlage(name: name));
      }

      expect((await a.repo.suche('Hafer', grenze: 2)).length, 2);
    });

    test('Leerzeichen am Rand zählen nicht mit', () async {
      final a = aufbau();
      await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));

      expect((await a.repo.suche('  flocken ')).length, 1);
    });

    test('Prozent und Unterstrich sind Zeichen, keine Platzhalter', () async {
      final a = aufbau();
      await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
      await a.repo.legeAn(vorlage(name: 'Joghurt 3,5 %'));

      // Ohne Maskierung fände `%` jedes Lebensmittel — und das sähe aus
      // wie ein Treffer, wo keiner ist.
      expect((await a.repo.suche('%')).map((l) => l.name), ['Joghurt 3,5 %']);
      expect(await a.repo.suche('_'), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Ohne Eingabe steht „zuletzt benutzt" da, keine leere Seite', () {
    // #345: ohne Suchtext nur Gebuchtes. Bis dahin hieß dieser Fall
    // „leerer Suchtext liefert alles".
    test('leerer Suchtext liefert alles Gebuchte — und nur das', () async {
      final a = aufbau();
      final hafer = await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
      final skyr = await a.repo.legeAn(vorlage(name: 'Skyr Natur'));
      await a.repo.legeAn(vorlage(name: 'Banane'));

      await a.repo.merkeBenutzung(hafer, gestern);
      await a.repo.merkeBenutzung(skyr, vorgestern);

      expect((await a.repo.suche('')).length, 2);
    });

    test('ein Suchtext aus lauter Leerzeichen ist kein Suchtext', () async {
      final a = aufbau();
      final hafer = await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
      await a.repo.merkeBenutzung(hafer, jetzt);
      // Nie gebucht — ohne Suchtext steht es nicht da (#345). Und wäre
      // „   " ein Suchtext, fände `LIKE '%   %'` auch das Gebuchte nicht.
      await a.repo.legeAn(vorlage(name: 'Skyr Natur'));

      expect((await a.repo.suche('   ')).map((l) => l.name), [
        'Haferflocken kernig',
      ]);
    });

    test('eine leere Tabelle antwortet mit einer leeren Liste', () async {
      final a = aufbau();
      expect(await a.repo.suche(''), isEmpty);
    });

    // #345: Bis dahin standen nie Benutzte ohne Suchtext alphabetisch
    // hinter den benutzten. Seitdem fehlen sie ohne Suchtext; die
    // Reihenfolge „benutzt vor nie benutzt, nie benutzte alphabetisch"
    // gilt weiter, aber nur mit Suchtext — geprüft im Fall darunter und
    // in `zuletzt_benutzt_test.dart`.
    test('das zuletzt Benutzte steht oben, nie Benutztes steht ohne '
        'Suchtext nicht da', () async {
      final a = aufbau();
      final skyr = await a.repo.legeAn(vorlage(name: 'Skyr Natur'));
      final hafer = await a.repo.legeAn(vorlage(name: 'Haferflocken kernig'));
      await a.repo.legeAn(vorlage(name: 'Banane'));
      await a.repo.legeAn(vorlage(name: 'Apfel'));

      await a.repo.merkeBenutzung(skyr, vorgestern);
      await a.repo.merkeBenutzung(hafer, jetzt);

      expect((await a.repo.suche('')).map((l) => l.name), [
        'Haferflocken kernig', // zuletzt benutzt: heute
        'Skyr Natur', // zuletzt benutzt: vorgestern
      ]);
    });

    test('dieselbe Reihenfolge gilt für Treffer', () async {
      final a = aufbau();
      final alt = await a.repo.legeAn(vorlage(name: 'Hafer alt'));
      final neu = await a.repo.legeAn(vorlage(name: 'Hafer neu'));
      await a.repo.legeAn(vorlage(name: 'Hafer nie'));

      await a.repo.merkeBenutzung(alt, gestern);
      await a.repo.merkeBenutzung(neu, jetzt);

      expect((await a.repo.suche('Hafer')).map((l) => l.name), [
        'Hafer neu',
        'Hafer alt',
        'Hafer nie',
      ]);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('merkeBenutzung', () {
    test('schreibt den Zeitpunkt an das Lebensmittel', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(vorlage());

      await a.repo.merkeBenutzung(id, jetzt);

      expect((await a.repo.lies(id))!.zuletztBenutzt, jetzt);
    });

    test('ein zweiter Aufruf hebt es wieder nach oben', () async {
      final a = aufbau();
      final eins = await a.repo.legeAn(vorlage(name: 'Eins'));
      final zwei = await a.repo.legeAn(vorlage(name: 'Zwei'));

      await a.repo.merkeBenutzung(eins, vorgestern);
      await a.repo.merkeBenutzung(zwei, gestern);
      expect((await a.repo.suche('')).map((l) => l.name), ['Zwei', 'Eins']);

      await a.repo.merkeBenutzung(eins, jetzt);
      expect((await a.repo.suche('')).map((l) => l.name), ['Eins', 'Zwei']);
    });

    test('rührt kein anderes Lebensmittel an', () async {
      final a = aufbau();
      final eins = await a.repo.legeAn(vorlage(name: 'Eins'));
      final zwei = await a.repo.legeAn(vorlage(name: 'Zwei'));

      await a.repo.merkeBenutzung(eins, jetzt);

      expect((await a.repo.lies(zwei))!.zuletztBenutzt, isNull);
    });

    test('ein unbekannter Schlüssel ändert nichts und wirft nicht', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(vorlage());

      await a.repo.merkeBenutzung(4711, jetzt);

      // #345: Ohne Suchtext steht nur Gebuchtes da — deshalb über den
      // Namen gezählt und am Lebensmittel selbst nachgesehen.
      expect((await a.repo.suche('Hafer')).length, 1);
      expect((await a.repo.lies(id))!.zuletztBenutzt, isNull);
      expect(
        await a.repo.suche(''),
        isEmpty,
        reason: 'der unbekannte Schlüssel hat nichts als gebucht markiert',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Ändern', () {
    test('schreibt die neuen Werte und behält den Schlüssel', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(vorlage());

      await a.repo.aendere(
        LebensmittelVorlage(
          id: id,
          name: 'Haferflocken zart',
          je100g: const Naehrwerte.je100g(kcal: 370, eiweissG: 13),
        ),
      );

      final gelesen = (await a.repo.lies(id))!;
      expect(gelesen.name, 'Haferflocken zart');
      expect(gelesen.je100g.kcal, 370);
      // Was vorher dastand und jetzt fehlt, ist danach **weg** und nicht
      // stehengeblieben: Ändern ersetzt die Vorlage, es ergänzt sie nicht.
      expect(gelesen.je100g.ballaststoffeG, isNull);
    });

    test('legt kein zweites Lebensmittel an', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(vorlage());

      await a.repo.aendere(
        LebensmittelVorlage(id: id, name: 'Anders', je100g: haferflocken),
      );

      // #345: Ohne Suchtext steht nur Gebuchtes da, und Ändern ist kein
      // Benutzen — gezählt wird deshalb direkt in der Tabelle.
      final zeile = await a.db
          .customSelect('SELECT COUNT(*) AS anzahl FROM lebensmittel;')
          .getSingle();
      expect(zeile.read<int>('anzahl'), 1);
    });

    test('lässt zuletztBenutzt in Ruhe — Ändern ist kein Benutzen', () async {
      final a = aufbau();
      final id = await a.repo.legeAn(vorlage());
      await a.repo.merkeBenutzung(id, gestern);

      await a.repo.aendere(
        LebensmittelVorlage(id: id, name: 'Anders', je100g: haferflocken),
      );

      expect((await a.repo.lies(id))!.zuletztBenutzt, gestern);
    });

    test('ohne Schlüssel wirft — das ist ein Programmierfehler, keine '
        'Datenlage', () async {
      final a = aufbau();

      await expectLater(
        a.repo.aendere(vorlage()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('LebensmittelVorlage ist ein Werttyp', () {
    // `CLAUDE.md`: Ein Werttyp, der Abhängigkeit eines Providers ist,
    // braucht `==` und `hashCode` — sonst rechnet Riverpod jedes
    // Abgeleitete neu, sobald die Suche ein zweites Mal gelesen hat
    // (Fehler `03`).
    test('zwei gleich gefüllte Vorlagen sind gleich', () {
      const a = LebensmittelVorlage(id: 1, name: 'Hafer', je100g: haferflocken);
      const b = LebensmittelVorlage(id: 1, name: 'Hafer', je100g: haferflocken);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('jedes Feld zählt mit', () {
      final jetztUtc = DateTime.utc(2026, 7, 14, 10);
      final grund = LebensmittelVorlage(
        id: 1,
        name: 'Hafer',
        je100g: haferflocken,
        fluessig: false,
        zuletztBenutzt: jetztUtc,
      );

      expect(
        grund,
        isNot(
          LebensmittelVorlage(
            id: 2,
            name: 'Hafer',
            je100g: haferflocken,
            zuletztBenutzt: jetztUtc,
          ),
        ),
      );
      expect(
        grund,
        isNot(
          LebensmittelVorlage(
            id: 1,
            name: 'Anders',
            je100g: haferflocken,
            zuletztBenutzt: jetztUtc,
          ),
        ),
      );
      expect(
        grund,
        isNot(
          LebensmittelVorlage(
            id: 1,
            name: 'Hafer',
            je100g: const Naehrwerte.je100g(kcal: 1),
            zuletztBenutzt: jetztUtc,
          ),
        ),
      );
      expect(
        grund,
        isNot(
          LebensmittelVorlage(
            id: 1,
            name: 'Hafer',
            je100g: haferflocken,
            fluessig: true,
            zuletztBenutzt: jetztUtc,
          ),
        ),
      );
      expect(
        grund,
        isNot(
          const LebensmittelVorlage(id: 1, name: 'Hafer', je100g: haferflocken),
        ),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die Spalten kommen auf einer bestehenden Datei nach', () {
    /// Der Altstand: `lebensmittel` so, wie Schema v12 sie angelegt hat —
    /// nur der Schlüssel. Die übrigen zwölf Tabellen fehlen absichtlich;
    /// `_reconcileSchema` legt sie beim Öffnen an (#233), und der Fall
    /// hier fragt nach dieser einen Tabelle.
    ///
    /// **Dieser Fall nagelt das Ergebnis fest, nicht den Weg dorthin.** Ob
    /// die neuen Spalten von der Migrationsstufe oder vom Abgleich kommen,
    /// prüft er nicht — die Stufe selbst gehört in
    /// `test/data/schema_v13_test.dart`, und das liegt außerhalb des
    /// Verzeichnisses, in dem dieser Auftrag schreiben darf (siehe Bericht
    /// an den Koordinator).
    QueryExecutor altstand() => NativeDatabase.memory(
      setup: (Database roh) {
        roh.execute(
          'CREATE TABLE lebensmittel ('
          'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT);',
        );
        roh.execute('INSERT INTO lebensmittel (id) VALUES (7);');
        roh.execute('PRAGMA user_version = 12;');
      },
    );

    test(
      'eine Datei aus Schema v12 lässt sich öffnen und beschreiben',
      () async {
        final db = AppCache(altstand());
        addTearDown(db.close);
        final repo = LebensmittelRepository(db);

        final id = await repo.legeAn(
          const LebensmittelVorlage(name: 'Neu', je100g: haferflocken),
        );

        expect((await repo.lies(id))!.name, 'Neu');
      },
    );

    test('die alte Zeile überlebt — ohne erfundene Werte', () async {
      final db = AppCache(altstand());
      addTearDown(db.close);
      final repo = LebensmittelRepository(db);

      final alt = await repo.lies(7);
      expect(alt, isNotNull);
      // Ein Vorgabewert für `name` ist nötig, weil SQLite
      // `ADD COLUMN … NOT NULL` ohne ihn ablehnt
      // (`ernaehrung_tabellen.dart`, Dateikopf). Er darf aber nichts
      // behaupten: Eine Migration füllt alte Zeilen nicht mit erfundenen
      // Angaben (`CLAUDE.md`).
      expect(alt!.name, '');
      expect(alt.je100g.kcal, isNull);
      expect(alt.je100g.eiweissG, isNull);
      expect(alt.zuletztBenutzt, isNull);
      expect(alt.fluessig, isFalse);
    });
  });
}
