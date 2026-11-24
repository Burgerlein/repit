// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke für
// `IS NULL` in Abfragen) — die verdecken sonst die gleichnamigen
// `package:matcher`-Matcher. Dieselbe Begründung wie in
// `lebensmittel_repository_test.dart`, Zeile 1–5.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;

/// Tests für **„Zuletzt benutzt"** in der Suche (#345).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Die Regel (Tim, 04.11.2026)
///
/// Ohne Suchtext zeigt die Suche unter „Zuletzt benutzt" **nur
/// Lebensmittel, die schon gebucht wurden** (`zuletzt_benutzt` gesetzt),
/// **höchstens 10**, das Jüngste oben. Nie Gebuchtes steht erst da, wenn
/// man danach sucht (`erfassen.js`, Zustand `suche-zuletzt`).
///
/// **Mit Suchtext bleibt alles, wie es war:** Treffer auch unter nie
/// Benutztem, Grenze 25, Reihenfolge benutzt → jüngste → Name.
///
/// **Noch nichts gebucht** ist ein eigener Zustand (`erfassen.js`,
/// `suche-leer`): Die Karte unter „Zuletzt benutzt" bleibt stehen und trägt
/// einen Satz statt Zeilen — „Eine Anzeige, die es gibt, hat genau eine
/// Form" (`CLAUDE.md`). „Außerdem" mit „Lebensmittel anlegen" bleibt an
/// seiner Stelle.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// - `LebensmittelRepository.suche('')` (und jeder Text aus lauter
///   Leerzeichen) liefert nur Vorlagen mit `zuletztBenutzt != null`,
///   höchstens 10, das Jüngste zuerst. Die Signatur bleibt
///   `suche(String text, {int grenze = 25})`; **was `grenze` ohne Suchtext
///   bewirkt, legt diese Datei nicht fest** — kein Fall hier übergibt sie
///   dort.
/// - **Gefiltert und begrenzt wird in SQL** (`CLAUDE.md`, Hausregel 2).
///   Von außen sieht eine Filterung in Dart genauso aus, solange man nur
///   die Rückgabe ansieht. Deshalb liest ein `QueryInterceptor` mit, was
///   die Datenbank tatsächlich herausgibt: höchstens 10 Zeilen und keine
///   nie benutzte — dasselbe Muster wie `_Mitschrift` in
///   `test/data/ernaehrung_repository_test.dart`.
/// - Neuer Schlüssel `Key('zuletzt-leer')` — der Satz „noch nichts
///   gebucht", **innerhalb** von `Key('erfassen-liste')`.
///
/// ## Entscheidung des Test-Agenten: ohne Suchtext gibt es nur einen Leerstand
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Bis
/// #345 stand ohne Suchtext bei leerer Tabelle `Key('erfassen-leer')`
/// („kein eigenes Lebensmittel angelegt"). Der Entwurf kennt ohne Suchtext
/// seitdem genau einen leeren Zustand, `suche-leer` = „Noch nichts
/// gebucht" — und der gilt, ob die Tabelle leer ist oder nur nichts
/// gebucht wurde. Zwei Schlüssel für dieselbe Stelle im selben Zustand
/// wären zwei Formen. Deshalb: **ohne Suchtext `zuletzt-leer`, nie
/// `erfassen-leer`; mit Suchtext ohne Treffer `erfassen-leer`, nie
/// `zuletzt-leer`.**
///
/// Zahlen und Namen in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  const werte = Naehrwerte.je100g(kcal: 360, eiweissG: 11);

  LebensmittelVorlage vorlage(String name) =>
      LebensmittelVorlage(name: name, je100g: werte);

  /// Der Zeitpunkt der [n]-ten Buchung: `n = 0` ist die jüngste, jede
  /// weitere liegt eine Stunde früher.
  DateTime vorStunden(int n) => jetzt.subtract(Duration(hours: n));

  // ═════════════════════════════════════════════════════════════════════
  group('Repository: ohne Suchtext nur Gebuchtes', () {
    ({AppCache db, LebensmittelRepository repo, _Mitschrift mitschrift})
    aufbau() {
      final mitschrift = _Mitschrift();
      final db = AppCache(NativeDatabase.memory().interceptWith(mitschrift));
      addTearDown(db.close);
      return (db: db, repo: LebensmittelRepository(db), mitschrift: mitschrift);
    }

    test('nie Gebuchtes fehlt, Gebuchtes steht da', () async {
      final a = aufbau();
      final skyr = await a.repo.legeAn(vorlage('Skyr Natur'));
      await a.repo.legeAn(vorlage('Apfel'));
      final hafer = await a.repo.legeAn(vorlage('Haferflocken kernig'));
      await a.repo.legeAn(vorlage('Banane'));

      await a.repo.merkeBenutzung(skyr, vorStunden(3));
      await a.repo.merkeBenutzung(hafer, vorStunden(1));

      final zuletzt = await a.repo.suche('');
      expect(zuletzt.map((l) => l.name), [
        'Haferflocken kernig', // vor einer Stunde
        'Skyr Natur', // vor drei Stunden
      ]);
      expect(
        zuletzt.every((l) => l.zuletztBenutzt != null),
        isTrue,
        reason: '„Zuletzt benutzt" heißt gebucht, nicht angelegt',
      );
    });

    test('das Jüngste steht oben — egal, in welcher Reihenfolge angelegt '
        'oder gebucht wurde', () async {
      final a = aufbau();
      final c = await a.repo.legeAn(vorlage('C'));
      final a1 = await a.repo.legeAn(vorlage('A'));
      final b = await a.repo.legeAn(vorlage('B'));

      // Gebucht in anderer Reihenfolge als angelegt, und keine der beiden
      // stimmt mit dem Alphabet oder der Zeit überein.
      await a.repo.merkeBenutzung(a1, vorStunden(5));
      await a.repo.merkeBenutzung(c, vorStunden(0));
      await a.repo.merkeBenutzung(b, vorStunden(2));

      expect((await a.repo.suche('')).map((l) => l.name), ['C', 'B', 'A']);
    });

    test('höchstens 10 — die zehn jüngsten, das Jüngste zuerst', () async {
      final a = aufbau();
      // Zwölf gebuchte, absichtlich in umgekehrter Zeitfolge angelegt:
      // Wer nach Schlüssel oder Anlegezeit sortiert, bekommt die falschen
      // zehn.
      for (var n = 11; n >= 0; n--) {
        final id = await a.repo.legeAn(vorlage('Gebucht $n'));
        await a.repo.merkeBenutzung(id, vorStunden(n));
      }

      final zuletzt = await a.repo.suche('');
      expect(zuletzt, hasLength(10));
      expect(zuletzt.map((l) => l.name), [
        for (var n = 0; n < 10; n++) 'Gebucht $n',
      ]);
    });

    test('genau 10 bei genau 10, alle bei weniger', () async {
      final a = aufbau();
      for (var n = 0; n < 10; n++) {
        final id = await a.repo.legeAn(vorlage('Gebucht $n'));
        await a.repo.merkeBenutzung(id, vorStunden(n));
      }
      expect(await a.repo.suche(''), hasLength(10));

      final b = aufbau();
      for (var n = 0; n < 3; n++) {
        final id = await b.repo.legeAn(vorlage('Gebucht $n'));
        await b.repo.merkeBenutzung(id, vorStunden(n));
      }
      expect(await b.repo.suche(''), hasLength(3));
    });

    test(
      'nie Gebuchtes füllt nicht auf, wenn weniger als 10 gebucht sind',
      () async {
        final a = aufbau();
        final eins = await a.repo.legeAn(vorlage('Gebucht'));
        await a.repo.merkeBenutzung(eins, jetzt);
        for (final name in ['Apfel', 'Banane', 'Clementine', 'Dattel']) {
          await a.repo.legeAn(vorlage(name));
        }

        expect((await a.repo.suche('')).map((l) => l.name), ['Gebucht']);
      },
    );

    test(
      'nichts gebucht → eine leere Liste, auch wenn Lebensmittel da sind',
      () async {
        final a = aufbau();
        for (final name in ['Apfel', 'Banane', 'Clementine']) {
          await a.repo.legeAn(vorlage(name));
        }

        expect(await a.repo.suche(''), isEmpty);
      },
    );

    test('ein Suchtext aus lauter Leerzeichen ist kein Suchtext', () async {
      final a = aufbau();
      final gebucht = await a.repo.legeAn(vorlage('Haferflocken kernig'));
      await a.repo.merkeBenutzung(gebucht, jetzt);
      await a.repo.legeAn(vorlage('Haferbrei'));

      expect((await a.repo.suche('   ')).map((l) => l.name), [
        'Haferflocken kernig',
      ]);
    });

    test('gefiltert und begrenzt wird in SQL: aus der Datenbank kommen '
        'höchstens 10 Zeilen und keine nie gebuchte', () async {
      final a = aufbau();
      // Zwanzig nie gebuchte, alphabetisch **vor** den gebuchten, und
      // fünfzehn gebuchte. Wer alles holt oder die alte Abfrage mit
      // Grenze 25 nimmt und danach in Dart filtert und kürzt, bekommt
      // dieselbe Rückgabe — aber nicht dieselben Zeilen aus SQLite.
      for (var n = 0; n < 20; n++) {
        await a.repo.legeAn(vorlage('Aa nie $n'));
      }
      for (var n = 0; n < 15; n++) {
        final id = await a.repo.legeAn(vorlage('Zz gebucht $n'));
        await a.repo.merkeBenutzung(id, vorStunden(n));
      }

      a.mitschrift.gelesen.clear();
      final zuletzt = await a.repo.suche('');
      expect(zuletzt, hasLength(10));

      final gegenLebensmittel = a.mitschrift.gelesen
          .where((abfrage) => abfrage.sql.contains('lebensmittel'))
          .toList();
      expect(
        gegenLebensmittel,
        isNotEmpty,
        reason:
            'Vorbedingung: Die Mitschrift hat die Abfrage überhaupt '
            'gesehen. Sieht sie keine, prüft der Fall darunter nichts',
      );

      for (final abfrage in gegenLebensmittel) {
        expect(
          abfrage.zeilen.length,
          lessThanOrEqualTo(10),
          reason:
              'LIMIT 10 steht in SQL. Holt die Abfrage mehr und kürzt in '
              'Dart, wächst die Arbeit mit jedem Lebensmittel, das Tim je '
              'angelegt hat — Fehler `03` in der Datenschicht.\n'
              'SQL: ${abfrage.sql}',
        );
        for (final zeile in abfrage.zeilen) {
          final spalte = zeile.keys.where((k) => k.endsWith('zuletzt_benutzt'));
          expect(
            spalte,
            isNotEmpty,
            reason:
                'jede Zeile trägt `zuletzt_benutzt` — sonst lässt sich '
                'nicht prüfen, ob nie Gebuchtes mitkam.\nSQL: ${abfrage.sql}',
          );
          expect(
            zeile[spalte.first],
            isNot(equals(null)),
            reason:
                '`WHERE zuletzt_benutzt IS NOT NULL` steht in SQL. Eine nie '
                'gebuchte Zeile, die aus der Datenbank kommt und erst in '
                'Dart wegfällt, ist in Dart gefiltert.\nSQL: ${abfrage.sql}',
          );
        }
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Repository: mit Suchtext bleibt alles, wie es war', () {
    ({AppCache db, LebensmittelRepository repo}) aufbau() {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      return (db: db, repo: LebensmittelRepository(db));
    }

    test('nie Gebuchtes wird gefunden', () async {
      final a = aufbau();
      await a.repo.legeAn(vorlage('Haferflocken kernig'));

      expect((await a.repo.suche('Hafer')).map((l) => l.name), [
        'Haferflocken kernig',
      ]);
    });

    test('die Grenze ist ohne Angabe 25, nicht 10', () async {
      final a = aufbau();
      for (var n = 0; n < 30; n++) {
        final id = await a.repo.legeAn(
          vorlage('Hafer ${n.toString().padLeft(2, '0')}'),
        );
        // Die Hälfte gebucht, damit „nur Gebuchtes" hier sichtbar falsch
        // wäre: Es gäbe 15, nicht 25.
        if (n.isEven) await a.repo.merkeBenutzung(id, vorStunden(n));
      }

      expect(await a.repo.suche('Hafer'), hasLength(25));
    });

    test('Reihenfolge: benutzt vor nie benutzt, das Jüngste zuerst, nie '
        'Benutztes nach dem Namen', () async {
      final a = aufbau();
      await a.repo.legeAn(vorlage('Hafer Zett nie'));
      final alt = await a.repo.legeAn(vorlage('Hafer alt'));
      await a.repo.legeAn(vorlage('Hafer Ah nie'));
      final neu = await a.repo.legeAn(vorlage('Hafer neu'));

      await a.repo.merkeBenutzung(alt, vorStunden(5));
      await a.repo.merkeBenutzung(neu, vorStunden(1));

      expect((await a.repo.suche('Hafer')).map((l) => l.name), [
        'Hafer neu',
        'Hafer alt',
        'Hafer Ah nie',
        'Hafer Zett nie',
      ]);
    });

    test('mehr als 10 gebuchte Treffer werden nicht auf 10 gekürzt', () async {
      final a = aufbau();
      for (var n = 0; n < 12; n++) {
        final id = await a.repo.legeAn(vorlage('Skyr $n'));
        await a.repo.merkeBenutzung(id, vorStunden(n));
      }

      expect(await a.repo.suche('Skyr'), hasLength(12));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Suchschirm', () {
    /// [trefferHaengen] hält den Ladezustand fest (siehe [_NieFertig]).
    ({ProviderContainer container, AppCache db}) behaelter({
      bool trefferHaengen = false,
    }) {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // Kein Fall hier fragt online; eine Antwort ohne Treffer, damit ein
      // getippter Text nie ins echte Netz geht.
      final netz = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'count': 0, 'hits': <Object?>[]})),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          offClientProvider.overrideWithValue(OffClient(client: netz)),
          if (trefferHaengen) suchtrefferProvider.overrideWith(_NieFertig.new),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, db: db);
    }

    Future<void> zeige(
      WidgetTester tester,
      ProviderContainer container, {
      bool warten = true,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CupertinoApp(
            home: CupertinoPageScaffold(child: SucheView()),
          ),
        ),
      );
      if (warten) await tester.pumpAndSettle();
    }

    /// Legt an und bucht — **vor** dem ersten Lesen der Suche, damit kein
    /// Provider einen älteren Stand hält.
    Future<int> gebucht(AppCache db, String name, DateTime wann) async {
      final repo = LebensmittelRepository(db);
      final id = await repo.legeAn(vorlage(name));
      await repo.merkeBenutzung(id, wann);
      return id;
    }

    Future<int> nurAngelegt(AppCache db, String name) =>
        LebensmittelRepository(db).legeAn(vorlage(name));

    Finder trefferZeilen() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('erfassen-treffer-');
    });

    Finder inListe(Finder wo) => find.descendant(
      of: find.byKey(const Key('erfassen-liste')),
      matching: wo,
    );

    String textUnter(WidgetTester tester, Key key) => tester
        .widgetList<Text>(
          find.descendant(of: find.byKey(key), matching: find.byType(Text)),
        )
        .map(textOf)
        .join(' ');

    testWidgets('nichts gebucht: in der Karte steht ein Satz statt Zeilen — '
        'auch wenn Lebensmittel angelegt sind', (tester) async {
      final b = behaelter();
      final angelegt = await nurAngelegt(b.db, 'Haferflocken kernig');
      await zeige(tester, b.container);

      expect(
        inListe(find.byKey(const Key('zuletzt-leer'))),
        findsOneWidget,
        reason:
            'die Karte unter „Zuletzt benutzt" bleibt stehen und trägt den '
            'Leerzustand — keine leere Karte, keine fehlende Karte',
      );
      expect(textUnter(tester, const Key('zuletzt-leer')).trim(), isNotEmpty);
      expect(
        find.byKey(Key('erfassen-treffer-$angelegt')),
        findsNothing,
        reason: 'angelegt ist nicht gebucht',
      );
      expect(trefferZeilen(), findsNothing);
      expect(
        find.byKey(const Key('erfassen-leer')),
        findsNothing,
        reason: 'ohne Suchtext gibt es genau einen Leerstand (Dateikopf)',
      );
    });

    testWidgets(
      'nichts gebucht und gar nichts angelegt: derselbe Leerzustand',
      (tester) async {
        final b = behaelter();
        await zeige(tester, b.container);

        expect(inListe(find.byKey(const Key('zuletzt-leer'))), findsOneWidget);
        expect(find.byKey(const Key('erfassen-leer')), findsNothing);
      },
    );

    testWidgets('„Lebensmittel anlegen" bleibt im Leerzustand an seiner '
        'Stelle', (tester) async {
      final b = behaelter();
      await zeige(tester, b.container);

      expect(find.byKey(const Key('erfassen-anlegen')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('erfassen-anlegen'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('erfassen-liste'))).dy,
        ),
        reason: '„Außerdem" steht unter der Karte, nicht an ihrer Stelle',
      );
    });

    testWidgets('während gelesen wird, steht der Leerzustand nicht da '
        '(Fehler 01)', (tester) async {
      final b = behaelter(trefferHaengen: true);
      await zeige(tester, b.container, warten: false);
      await tester.pump();

      expect(
        find.byKey(const Key('zuletzt-leer')),
        findsNothing,
        reason:
            '„noch nichts gebucht" ist eine Auskunft — während gelesen '
            'wird, weiß der Schirm das noch nicht',
      );
      expect(find.byKey(const Key('erfassen-leer')), findsNothing);
      expect(
        find.byKey(const Key('erfassen-liste')),
        findsOneWidget,
        reason: 'die Karte steht schon da, nur ungefüllt',
      );
    });

    testWidgets('mit Gebuchtem: die Zeilen stehen da, der Leerzustand nicht', (
      tester,
    ) async {
      final b = behaelter();
      final hafer = await gebucht(b.db, 'Haferflocken kernig', vorStunden(1));
      final skyr = await gebucht(b.db, 'Skyr Natur', vorStunden(0));
      final nie = await nurAngelegt(b.db, 'Apfel');
      await zeige(tester, b.container);

      expect(find.byKey(Key('erfassen-treffer-$skyr')), findsOneWidget);
      expect(find.byKey(Key('erfassen-treffer-$hafer')), findsOneWidget);
      expect(find.byKey(Key('erfassen-treffer-$nie')), findsNothing);
      expect(find.byKey(const Key('zuletzt-leer')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(Key('erfassen-treffer-$skyr'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(Key('erfassen-treffer-$hafer'))).dy,
        ),
        reason: 'das Jüngste oben',
      );
    });

    testWidgets('höchstens 10 Zeilen', (tester) async {
      final b = behaelter();
      for (var n = 0; n < 12; n++) {
        await gebucht(b.db, 'Gebucht $n', vorStunden(n));
      }
      await zeige(tester, b.container);

      expect(trefferZeilen(), findsNWidgets(10));
    });

    testWidgets('das erste Buchen füllt die Karte — ohne Neustart', (
      tester,
    ) async {
      final b = behaelter();
      final id = await nurAngelegt(b.db, 'Haferflocken kernig');
      await zeige(tester, b.container);
      expect(find.byKey(const Key('zuletzt-leer')), findsOneWidget);

      await b.container
          .read(lebensmittelRepositoryProvider)
          .merkeBenutzung(id, jetzt);
      await b.container.read(suchtrefferProvider.notifier).neuLesen();
      await tester.pumpAndSettle();

      expect(find.byKey(Key('erfassen-treffer-$id')), findsOneWidget);
      expect(find.byKey(const Key('zuletzt-leer')), findsNothing);
    });

    testWidgets('mit Suchtext gilt der Leerzustand von „Zuletzt benutzt" '
        'nicht — dort findet die Suche auch nie Gebuchtes', (tester) async {
      final b = behaelter();
      final nie = await nurAngelegt(b.db, 'Haferflocken kernig');
      await zeige(tester, b.container);
      expect(find.byKey(const Key('zuletzt-leer')), findsOneWidget);

      // Ein Zeichen: Die Online-Suche beginnt erst bei zwei, und um sie
      // geht es hier nicht.
      await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'H');
      await tester.pumpAndSettle();

      expect(find.byKey(Key('erfassen-treffer-$nie')), findsOneWidget);
      expect(find.byKey(const Key('zuletzt-leer')), findsNothing);

      await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'Q');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('erfassen-leer')),
        findsOneWidget,
        reason: 'mit Suchtext ohne Treffer: der Leerstand der Suche',
      );
      expect(find.byKey(const Key('zuletzt-leer')), findsNothing);
    });
  });
}

/// Liest mit, welche `SELECT`s abgesetzt werden **und was zurückkommt**.
///
/// Die Rückgabe der Datenbank ist der Beweis, dass in SQL gefiltert und
/// begrenzt wurde: Eine Filterung in Dart sähe von außen genauso aus,
/// solange man nur die Rückgabe des Repositorys ansieht.
class _Mitschrift extends QueryInterceptor {
  final List<({String sql, List<Map<String, Object?>> zeilen})> gelesen = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final zeilen = await executor.runSelect(statement, args);
    gelesen.add((sql: statement, zeilen: zeilen));
    return zeilen;
  }
}

/// Ein Suchtreffer-Notifier, der nie fertig wird — die einzige
/// zuverlässige Art, den Ladezustand festzuhalten (dieselbe Begründung wie
/// in `erfassen_view_test.dart`).
class _NieFertig extends SuchtrefferNotifier {
  @override
  Future<List<LebensmittelVorlage>> build() =>
      Completer<List<LebensmittelVorlage>>().future;
}
