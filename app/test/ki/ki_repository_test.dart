// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/ki/gemini_preise.dart';
import 'package:repit/ki/ki_repository.dart';
import 'package:repit/ki/ki_schluessel.dart';

/// Tests für **`KiRepository`** und die **vorbelegten Preise** — Task 6 des
/// Plans `docs/superpowers/plans/2026-11-04-ki-zugang.md` (Karte #337),
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitte
/// „Verbrauch und Limit" und „Datenschicht — Schema 14 → 15". Die Tabellen
/// selbst und ihre Migration prüft `test/data/schema_v15_test.dart`; hier
/// geht es um das, was hinein- und wieder herauskommt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben
/// ohne den Code von `lib/ki/` gesehen zu haben — es gab ihn beim Schreiben
/// noch nicht.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// In `lib/ki/ki_repository.dart` (Namen aus dem Plan, Task 6):
///
/// ```dart
/// class KiRepository {
///   KiRepository(AppCache db);
///   Future<KiEinstellungenStand> einstellungen();
///   Future<void> setzeModell(String modell);
///   Future<void> setzeLimit(double limitUsd);
///   Future<void> setzePreis(String modell, KiPreis preis);
///   Future<void> setzePruefung(DateTime geprueftAm, String ergebnis);
///   Future<void> protokolliere({
///     required DateTime zeitpunkt,   // UTC
///     required String modell,
///     required String zweck,
///     required KiVerbrauch verbrauch,
///     double? kosten,                // null: kein Preis bekannt
///   });
///   Future<MonatsSumme> monat(String monatsSchluessel);
/// }
/// ```
///
/// In `lib/ki/gemini_preise.dart`:
///
/// ```dart
/// const String voreingestelltesModell = 'gemini-3.6-flash';
/// const Map<String, KiPreis> vorbelegtePreise = { … };
/// KiPreis? preisFuer(String modell, Map<String, KiPreis> eigene);
/// ```
///
/// `KiPreis`, `KiVerbrauch` und `MonatsSumme` kommen aus `trainings_core`.
///
/// ## Eigene Festlegungen dieser Datei — nicht von Tim freigegeben
///
/// Der Plan nennt Methodennamen, aber nicht alles. Was hier zusätzlich
/// festgelegt wird, sind Entscheidungen des Test-Agenten:
///
/// - **`einstellungen()` liefert `KiEinstellungenStand`**, einen Werttyp
///   mit den Feldern `modell` (`String?`), `limitUsd` (`double?`), `preise`
///   (`Map<String, KiPreis>`, leer statt `null`), `geprueftAm`
///   (`DateTime?`, UTC) und `pruefErgebnis` (`String?`). **`==` und
///   `hashCode` über alle Felder, `preise` inhaltlich verglichen** — der
///   Stand ist Abhängigkeit des KI-Zugang-Providers (`CLAUDE.md`, `03`).
///   Der Name `KiEinstellungenStand` ist gewählt, weil `KiEinstellungen`
///   die drift-Tabelle und `KiEinstellungenRow` ihre Datenklasse ist.
/// - **Der Parameter für den Verbrauch heißt `verbrauch`**; der Plan
///   schreibt nur den Typ.
/// - **`einstellungen()` legt keine Zeile an.** Lesen schreibt nicht;
///   dieselbe Regel wie für die Stufe 15.
/// - **Jedes `setze…` ändert nur sein Feld** und lässt die anderen stehen;
///   die Tabelle behält höchstens eine Zeile.
/// - **`protokolliere` rechnet den Monat selbst** aus `zeitpunkt`, in
///   Berliner Zeit (`monatsSchluessel` aus dem Kern) — der Aufrufer gibt
///   keinen Monat mit.
/// - **„In SQL gefiltert" wird am Ergebnis gemessen, nicht am Wortlaut:**
///   `monat()` darf aus `ki_anfragen` höchstens so viele Zeilen holen, wie
///   der Monat hat (eine Summe in SQL holt eine). Ein Laden aller Zeilen
///   mit anschließendem Filtern in Dart fällt damit auf, gleich wie die
///   Abfrage formuliert ist.
/// - **`vorbelegtePreise` enthält die Voreinstellung.** Sonst stünde bei
///   jeder Anfrage mit dem Standardmodell der Betrag als `–/–`.
/// - **In `gemini_preise.dart` steht kein Datum**, auch nicht als
///   `04.11.2026` im Kommentar (Spec: „Stand dieser App-Fassung", das Datum
///   gehört in die Commit-Nachricht).
///
/// ## Alle Werte hier sind erfunden
///
/// Keine echten Daten, kein echter Schlüssel (`CLAUDE.md`). Zeitpunkte
/// liegen im Jahr 2099, damit sie keinen Termin nachahmen; Modellnamen
/// außer der Voreinstellung sind als erfunden erkennbar; Beträge sind
/// binär exakt darstellbar (0,25 + 0,5), damit kein Rundungsrest einen
/// Vergleich kippt.
void main() {
  // --- Zeitpunkte ----------------------------------------------------
  //
  // November 2099 liegt in der Winterzeit, Berlin ist UTC+1.

  /// 2099-11-02, 11:00 Berliner Wanduhr — mitten im November.
  final novemberMitte = DateTime.utc(2099, 11, 2, 10);

  /// 2099-11-30, 23:30 Berliner Wanduhr — der letzte halbe Tag im November.
  final novemberEnde = DateTime.utc(2099, 11, 30, 22, 30);

  /// 2099-11-30, 23:30 **UTC** — in Berlin schon 00:30 am 1. Dezember.
  /// Gehört zum **Dezember** (Plan, „Review Focus" 3).
  final dezemberBeginn = DateTime.utc(2099, 11, 30, 23, 30);

  /// 2099-10-31, 23:00 Berliner Wanduhr — Oktober. Die Sommerzeit endet am
  /// letzten Oktobersonntag um 01:00 UTC; 22:00 UTC am 31. liegt danach.
  final oktoberEnde = DateTime.utc(2099, 10, 31, 22);

  const verbrauch = KiVerbrauch(eingabe: 111, ausgabe: 222, denken: 333);

  /// Erfunden, ohne `AIza`.
  const erfundenerSchluessel = 'erfunden-kein-echter-schluessel-R3v8';

  // --- Hilfsmittel ---------------------------------------------------

  AppCache frisch({QueryInterceptor? zaehler}) {
    final executor = zaehler == null
        ? NativeDatabase.memory()
        : NativeDatabase.memory().interceptWith(zaehler);
    final db = AppCache(executor);
    addTearDown(db.close);
    return db;
  }

  /// Wie viele Zeilen wirklich in einer Tabelle stehen — gefragt wird die
  /// Datei, nicht das Repository.
  Future<int> zeilen(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS anzahl FROM $tabelle;')
        .getSingle();
    return zeile.read<int>('anzahl');
  }

  Future<void> protokolliere(
    KiRepository repo,
    DateTime zeitpunkt,
    double? kosten, {
    String modell = 'erfundenes-modell-a',
  }) => repo.protokolliere(
    zeitpunkt: zeitpunkt,
    modell: modell,
    zweck: 'foto',
    verbrauch: verbrauch,
    kosten: kosten,
  );

  // ---------------------------------------------------------------------

  group('einstellungen() ohne Zeile — die Vorgabe greift in der Anzeige', () {
    test('Modell null, Limit null, keine Preise, nie geprüft', () async {
      final stand = await KiRepository(frisch()).einstellungen();

      expect(
        stand.modell,
        isNull,
        reason:
            'nichts gewählt heißt: die Voreinstellung der App gilt — '
            'das entscheidet die Anzeige, nicht die Datenbank',
      );
      expect(
        stand.limitUsd,
        isNull,
        reason:
            'null heißt „Vorgabe 10 \$", nicht 0 und keine Zahl, die '
            'niemand eingegeben hat',
      );
      expect(stand.preise, isEmpty);
      expect(stand.geprueftAm, isNull);
      expect(stand.pruefErgebnis, isNull);
    });

    test('Lesen legt keine Zeile an', () async {
      final db = frisch();
      await KiRepository(db).einstellungen();

      expect(
        await zeilen(db, 'ki_einstellungen'),
        0,
        reason:
            'eine beim Lesen angelegte Zeile behauptete eine '
            'Einstellung, die niemand getroffen hat',
      );
    });
  });

  group('setze… — was hineinging, kommt heraus', () {
    test('setzeModell', () async {
      final repo = KiRepository(frisch());
      await repo.setzeModell('erfundenes-modell-a');

      expect((await repo.einstellungen()).modell, 'erfundenes-modell-a');
    });

    test('setzeLimit', () async {
      final repo = KiRepository(frisch());
      await repo.setzeLimit(25.5);

      expect((await repo.einstellungen()).limitUsd, 25.5);
    });

    test('setzePreis — je Modell, ein zweites Setzen überschreibt', () async {
      final repo = KiRepository(frisch());
      const preisA = KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5);
      const preisA2 = KiPreis(eingabeJeMio: 0.25, ausgabeJeMio: 3);
      const preisB = KiPreis(eingabeJeMio: 2, ausgabeJeMio: 12);

      await repo.setzePreis('erfundenes-modell-a', preisA);
      await repo.setzePreis('erfundenes-modell-b', preisB);
      expect((await repo.einstellungen()).preise, {
        'erfundenes-modell-a': preisA,
        'erfundenes-modell-b': preisB,
      });

      await repo.setzePreis('erfundenes-modell-a', preisA2);
      expect((await repo.einstellungen()).preise, {
        'erfundenes-modell-a': preisA2,
        'erfundenes-modell-b': preisB,
      });
    });

    test('setzePruefung — geprueft_am kommt als UTC und gleich sich selbst '
        'zurück', () async {
      final repo = KiRepository(frisch());
      final geprueft = DateTime.utc(2099, 11, 3, 5, 48, 12);

      await repo.setzePruefung(geprueft, 'gueltig');
      final stand = await repo.einstellungen();

      expect(stand.geprueftAm, geprueft);
      expect(
        stand.geprueftAm!.isUtc,
        isTrue,
        reason:
            'als Ortszeit zurückgegeben wäre der Wert ungleich sich '
            'selbst (`storeDateTimeAsText`, CLAUDE.md)',
      );
      expect(stand.pruefErgebnis, 'gueltig');
    });

    test('eine zweite Prüfung ersetzt die erste', () async {
      final repo = KiRepository(frisch());
      await repo.setzePruefung(DateTime.utc(2099, 11, 3, 5), 'gueltig');
      final spaeter = DateTime.utc(2099, 11, 4, 7, 30);
      await repo.setzePruefung(spaeter, 'abgelehnt');

      final stand = await repo.einstellungen();
      expect(stand.geprueftAm, spaeter);
      expect(stand.pruefErgebnis, 'abgelehnt');
    });

    test('jedes setze… lässt die anderen Felder stehen, und es bleibt eine '
        'Zeile', () async {
      final db = frisch();
      final repo = KiRepository(db);
      const preis = KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5);
      final geprueft = DateTime.utc(2099, 11, 3, 5, 48);

      await repo.setzeModell('erfundenes-modell-a');
      await repo.setzeLimit(25.5);
      await repo.setzePreis('erfundenes-modell-a', preis);
      await repo.setzePruefung(geprueft, 'gueltig');
      await repo.setzeModell('erfundenes-modell-b');

      final stand = await repo.einstellungen();
      expect(stand.modell, 'erfundenes-modell-b');
      expect(stand.limitUsd, 25.5);
      expect(stand.preise, {'erfundenes-modell-a': preis});
      expect(stand.geprueftAm, geprueft);
      expect(stand.pruefErgebnis, 'gueltig');

      expect(
        await zeilen(db, 'ki_einstellungen'),
        1,
        reason:
            'Einstellungen sind kein Verlauf; eine zweite Zeile wäre '
            'ein zweiter, widersprechender Stand',
      );
    });
  });

  group(
    'KiEinstellungenStand ist ein Werttyp — Abhängigkeit eines Providers',
    () {
      test(
        'zwei Lesungen desselben Stands sind gleich, auch mit Preisen',
        () async {
          final repo = KiRepository(frisch());
          await repo.setzeModell('erfundenes-modell-a');
          await repo.setzeLimit(25.5);
          await repo.setzePreis(
            'erfundenes-modell-a',
            const KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5),
          );
          await repo.setzePruefung(DateTime.utc(2099, 11, 3, 5, 48), 'gueltig');

          final erste = await repo.einstellungen();
          final zweite = await repo.einstellungen();

          expect(
            identical(erste, zweite),
            isFalse,
            reason: 'sonst prüfte der Test nur die Identität',
          );
          expect(
            erste,
            zweite,
            reason:
                'ohne inhaltliches == rechnete jeder abgeleitete Provider '
                'bei jeder Lesung neu — das wäre 03 im neuen Code',
          );
          expect(erste.hashCode, zweite.hashCode);
        },
      );

      test('ein anderes Feld macht den Stand ungleich', () async {
        final repo = KiRepository(frisch());
        await repo.setzeModell('erfundenes-modell-a');
        final vorher = await repo.einstellungen();

        await repo.setzePreis(
          'erfundenes-modell-a',
          const KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5),
        );
        final nachher = await repo.einstellungen();

        expect(vorher == nachher, isFalse);
      });
    },
  );

  group('protokolliere — eine Zeile je Antwort in ki_anfragen', () {
    test(
      'Zeitpunkt UTC, Monat in Berliner Zeit, Token nicht vertauscht',
      () async {
        final db = frisch();
        final repo = KiRepository(db);

        await repo.protokolliere(
          zeitpunkt: dezemberBeginn,
          modell: 'erfundenes-modell-a',
          zweck: 'testbild',
          verbrauch: verbrauch,
          kosten: 0.25,
        );

        final zeile = (await db.select(db.kiAnfragen).get()).single;
        expect(zeile.zeitpunkt, dezemberBeginn);
        expect(zeile.zeitpunkt.isUtc, isTrue);
        expect(
          zeile.monat,
          '2099-12',
          reason: '23:30 UTC am 30.11. ist 00:30 Berliner Zeit am 1.12.',
        );
        expect(zeile.modell, 'erfundenes-modell-a');
        expect(zeile.zweck, 'testbild');
        expect(zeile.eingabeToken, 111);
        expect(zeile.ausgabeToken, 222);
        expect(zeile.denkToken, 333);
        expect(zeile.kostenUsd, 0.25);
      },
    );

    test('kosten: null bleibt null, nicht 0', () async {
      final db = frisch();
      await protokolliere(KiRepository(db), novemberMitte, null);

      final zeile = (await db.select(db.kiAnfragen).get()).single;
      expect(
        zeile.kostenUsd,
        isNull,
        reason: 'eine 0 senkte die Monatssumme still',
      );
    });
  });

  group('monat — Summe eines Berliner Kalendermonats', () {
    test("monat('2099-11') summiert nur November-Zeilen", () async {
      final repo = KiRepository(frisch());
      await protokolliere(repo, novemberMitte, 0.25);
      await protokolliere(repo, novemberEnde, 0.5);
      await protokolliere(repo, oktoberEnde, 1);
      await protokolliere(repo, dezemberBeginn, 2);

      expect(
        await repo.monat('2099-11'),
        const MonatsSumme(usd: 0.75, unvollstaendig: false, anfragen: 2),
      );
    });

    test('die Monatsgrenze ist Berliner Zeit, nicht UTC', () async {
      final repo = KiRepository(frisch());
      await protokolliere(repo, novemberEnde, 0.5);
      await protokolliere(repo, dezemberBeginn, 2);
      await protokolliere(repo, oktoberEnde, 1);

      expect(
        await repo.monat('2099-12'),
        const MonatsSumme(usd: 2, unvollstaendig: false, anfragen: 1),
        reason: '30.11. 23:30 UTC gehört zum Dezember (Review Focus 3)',
      );
      expect(
        await repo.monat('2099-10'),
        const MonatsSumme(usd: 1, unvollstaendig: false, anfragen: 1),
      );
    });

    test(
      'eine Zeile mit kosten: null macht die Summe unvollstaendig',
      () async {
        final repo = KiRepository(frisch());
        await protokolliere(repo, novemberMitte, 0.25);
        await protokolliere(repo, novemberEnde, 0.5);
        await protokolliere(
          repo,
          novemberMitte,
          null,
          modell: 'erfundenes-modell-ohne-preis',
        );

        expect(
          await repo.monat('2099-11'),
          const MonatsSumme(usd: 0.75, unvollstaendig: true, anfragen: 3),
          reason: 'die Anfrage ohne Betrag zählt als Anfrage, nicht als Geld',
        );
      },
    );

    test(
      'ein Monat ohne Anfragen ist 0 \$, vollständig, null Anfragen',
      () async {
        final repo = KiRepository(frisch());
        await protokolliere(repo, novemberMitte, 0.25);

        expect(
          await repo.monat('2099-09'),
          const MonatsSumme(usd: 0, unvollstaendig: false, anfragen: 0),
        );
      },
    );

    test('gefiltert wird in SQL — aus ki_anfragen kommen höchstens die '
        'Zeilen des Monats', () async {
      final zaehler = _ZeilenZaehler();
      final repo = KiRepository(frisch(zaehler: zaehler));

      // Drei im November, sechs daneben.
      await protokolliere(repo, novemberMitte, 0.25);
      await protokolliere(repo, novemberEnde, 0.5);
      await protokolliere(repo, novemberMitte, null);
      for (var tag = 1; tag <= 3; tag++) {
        await protokolliere(repo, DateTime.utc(2099, 10, tag, 12), 1);
        await protokolliere(repo, DateTime.utc(2099, 12, tag + 1, 12), 2);
      }

      zaehler.zuruecksetzen();
      final summe = await repo.monat('2099-11');

      expect(
        summe,
        const MonatsSumme(usd: 0.75, unvollstaendig: true, anfragen: 3),
      );
      expect(
        zaehler.zeilenAusKiAnfragen,
        lessThanOrEqualTo(3),
        reason:
            'mehr Zeilen als der Monat hat heißt: in Dart nachgefiltert '
            '(CLAUDE.md, Regel 2). Gelesene Abfragen: ${zaehler.abfragen}',
      );
    });
  });

  group('Der Schlüssel liegt nicht in der Datenbank', () {
    test('nach einem vollen Durchgang steht er in keiner Zelle', () async {
      // Ein Wächter: Das Repository nimmt den Schlüssel nirgends entgegen,
      // und so soll es bleiben. Die Datenbank wandert ins
      // iCloud-Gerätebackup, der Schlüssel nicht (Spec, „Datenschicht").
      final db = frisch();
      final repo = KiRepository(db);
      final speicher = AttrappenSchluesselSpeicher();

      await speicher.schreibe(erfundenerSchluessel);
      await repo.setzeModell('erfundenes-modell-a');
      await repo.setzeLimit(25.5);
      await repo.setzePreis(
        'erfundenes-modell-a',
        const KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5),
      );
      await repo.setzePruefung(DateTime.utc(2099, 11, 3, 5, 48), 'gueltig');
      await protokolliere(repo, novemberMitte, 0.25);
      await repo.einstellungen();
      await repo.monat('2099-11');

      final tabellen = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%';",
          )
          .get();
      expect(tabellen, isNotEmpty);

      for (final tabelle in tabellen) {
        final name = tabelle.read<String>('name');
        final inhalt = await db.customSelect('SELECT * FROM "$name";').get();
        for (final zeile in inhalt) {
          for (final wert in zeile.data.values) {
            expect(
              '$wert',
              isNot(contains(erfundenerSchluessel)),
              reason: 'Schlüssel in Tabelle $name',
            );
          }
        }
      }
    });
  });

  group('gemini_preise.dart — vorbelegte Preise und preisFuer', () {
    const eigen = KiPreis(eingabeJeMio: 0.125, ausgabeJeMio: 1.5);

    test("die Voreinstellung ist 'gemini-3.6-flash'", () {
      expect(voreingestelltesModell, 'gemini-3.6-flash');
    });

    test('die Voreinstellung hat einen vorbelegten Preis', () {
      expect(vorbelegtePreise, contains(voreingestelltesModell));
    });

    test('ohne eigenen Preis gilt der vorbelegte', () {
      expect(
        preisFuer(voreingestelltesModell, const {}),
        vorbelegtePreise[voreingestelltesModell],
      );
    });

    test('der eigene Preis geht vor dem vorbelegten', () {
      expect(
        vorbelegtePreise[voreingestelltesModell],
        isNot(eigen),
        reason: 'sonst bewiese der nächste Vergleich nichts',
      );
      expect(
        preisFuer(voreingestelltesModell, {voreingestelltesModell: eigen}),
        eigen,
      );
    });

    test('ein eigener Preis für ein anderes Modell ändert nichts', () {
      expect(
        preisFuer(voreingestelltesModell, {'erfundenes-modell-b': eigen}),
        vorbelegtePreise[voreingestelltesModell],
      );
    });

    test('ein Modell ohne vorbelegten Preis nimmt den eigenen', () {
      expect(
        preisFuer('erfundenes-modell-ohne-vorbelegung', {
          'erfundenes-modell-ohne-vorbelegung': eigen,
        }),
        eigen,
      );
    });

    test('unbekanntes Modell ohne eigenen Preis → null', () {
      expect(
        preisFuer('erfundenes-modell-ohne-preis', const {}),
        isNull,
        reason: 'kein Preis heißt Betrag –/–, nicht 0 \$ (Review Focus 7)',
      );
    });

    test('in gemini_preise.dart steht kein Datum', () {
      final quelle = File('lib/ki/gemini_preise.dart').readAsStringSync();

      expect(
        RegExp(r'20(2[6-9]|3[0-9])-[0-9]{2}-[0-9]{2}|DateTime\(20')
            .hasMatch(quelle),
        isFalse,
        reason: 'CLAUDE.md, „Keine hartcodierten Ereignisse"',
      );
      expect(
        RegExp(r'\b[0-3]?[0-9]\.[01]?[0-9]\.20[0-9]{2}\b').hasMatch(quelle),
        isFalse,
        reason:
            'der Preisstand steht als „Stand dieser App-Fassung", das '
            'Datum in der Commit-Nachricht (Spec, „Verbrauch und Limit")',
      );
    });
  });
}

/// Zählt, wie viele Zeilen Abfragen auf `ki_anfragen` zurückgeben.
class _ZeilenZaehler extends QueryInterceptor {
  int zeilenAusKiAnfragen = 0;
  final List<String> abfragen = [];

  void zuruecksetzen() {
    zeilenAusKiAnfragen = 0;
    abfragen.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final ergebnis = await executor.runSelect(statement, args);
    if (statement.contains('ki_anfragen')) {
      zeilenAusKiAnfragen += ergebnis.length;
      abfragen.add('$statement $args → ${ergebnis.length}');
    }
    return ergebnis;
  }
}
