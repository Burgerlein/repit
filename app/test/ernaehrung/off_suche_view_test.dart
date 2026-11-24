import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/erfassen_weg.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;
import '../tag/behaelter_im_baum.dart';

/// Tests für die **Suche mit Open Food Facts** (#284) — Zustände
/// `suche-leer`, `suche-treffer` und `suche-ohne-netz` aus
/// `docs/screens/screens/erfassen.js`.
///
/// Der Client steht in `off_client_test.dart`, die Übernahme in die
/// eigene Tabelle in `lebensmittel_herkunft_test.dart`. Hier geht es um
/// das, was Tim sieht und antippt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// **Nachtrag #345** (Tims Entscheidung vom 04.11.2026): Ohne Suchtext
/// stehen unter „Zuletzt benutzt" nur gebuchte Lebensmittel. Die beiden
/// Fälle zur Namensnennung ohne Suchtext buchen ihr Lebensmittel deshalb
/// jetzt vorher (Benutzung gemerkt), damit es überhaupt dasteht — vom
/// Test-Agenten von #345 umgestellt, Tim hat die Änderung nicht gesehen.
///
/// **Nachtrag #440** (10.11.2026): Tim hat V26 bestätigt (Spec
/// `2026-11-10-mahlzeiten-aufteilung-design.md`): Nach einer Buchung über
/// das Blatt bleibt die Suche offen. Die beiden Fälle, die nach dem
/// ersten Buchen die Suche ein zweites Mal öffnen ('beim zweiten Mal
/// steht es als eigenes da …' und 'ohne Netz findet die Suche …'),
/// schließen die erste vorher über „Fertig" (`Key('erfassen-fertig')`,
/// V29) — sonst lägen zwei Suchen übereinander. Ihre Aussage bleibt. Vom
/// Test-Agenten von #440 umgestellt, Tim hat die Umstellung nicht
/// gesehen.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// - `offClientProvider` (in `lib/ernaehrung/off_client.dart`) ist der
///   **einzige** Weg der Suche zu Open Food Facts. Hier wird er mit einem
///   `OffClient` über einem `MockClient` ersetzt — kein Netz im Test.
/// - `SucheView` und `SucheSeite` behalten ihre Form
///   (`erfassen_view_test.dart`, `eintragweg_verdrahtung_test.dart`).
///   `SucheView.onGewaehlt` meldet für eine OFF-Zeile
///   `OffProdukt.alsVorlage()` — **ohne Schlüssel, Herkunft `off`, mit
///   Strichcode**. Übernommen wird erst beim Buchen.
///
/// ### Die Schlüssel
///
/// Neu, aus demselben Grund wie in `erfassen_view_test.dart` — für „ist da
/// / ist nicht da" gibt es sonst keine strukturelle Stelle im Baum:
///
/// - `Key('erfassen-off-<barcode>')` — eine Zeile aus Open Food Facts
/// - `Key('erfassen-off-grund-<barcode>')` — der Grund, warum diese Zeile
///   **nicht** buchbar ist. **In der Suche gibt es ihn seit dem
///   04.11.2026 nicht mehr:** Treffer ohne Kalorien werden verworfen
///   (siehe unten). Die Fälle hier prüfen nur noch, dass er nirgends
///   steht.
/// - `Key('erfassen-online-laedt')` — der Platzhalter, solange online
///   gesucht wird **oder die Suche noch entprellt**
/// - `Key('erfassen-online-leer')` — OFF hat nachgesehen und nichts
/// - `Key('erfassen-online-kein-netz')` — „Online nicht erreichbar"
/// - `Key('erfassen-odbl')` — die Namensnennung (ODbL)
/// - `Key('erfassen-abzeichen-eigen')` — das Abzeichen „eigen", **in** der
///   Zeile eines eigenen Lebensmittels (`erfassen-treffer-<id>`). Derselbe
///   Schlüssel steht in jeder eigenen Zeile; gesucht wird er immer
///   unterhalb einer bestimmten Zeile. (Neu seit dem 04.11.2026.)
///
/// Die bestehenden (`erfassen-suchfeld`, `erfassen-liste`,
/// `erfassen-treffer-<id>`, `erfassen-leer`, `buchung-sichern`) gelten
/// weiter. **`erfassen-liste` trägt seit dem 04.11.2026 auch die
/// Online-Zeilen** — es ist die eine Liste.
///
/// ## Vorgabe vom 04.11.2026: eine Liste, gleiche Produkte einmal
///
/// Aus dem Auftrag an den Test-Agenten, nicht von ihm entschieden. Tim auf
/// dem Gerät: „Die Suche muss überarbeitet werden, man findet direkt 8000
/// mal das gleiche, wenn ich nach Nutella suche." Und: „Eigene Treffer
/// sollen einfach mit den anderen gemischt werden, höchstens mit einem Tag
/// gekennzeichnet." Gezeichnet in `erfassen.js`, `suche-treffer` und
/// `suche-ohne-netz` (Commit `10d73ed`).
///
/// - **Gleiche Produkte erscheinen einmal:** gleicher normalisierter Name
///   und Kalorien innerhalb von 3 %, unabhängig von der Marke. Die Regel
///   selbst und ihre Grenzfälle prüft
///   `Packages/trainings_core/test/lebensmittel_dubletten_test.dart`; hier
///   wird nur geprüft, **dass** die Suche sie anwendet — unter Online-
///   Treffern und zwischen eigenen und Online-Treffern.
/// - **Eine Liste, keine Abschnitte.** Eigene stehen vorn, mit Abzeichen,
///   ohne eigene Überschrift; die Online-Treffer folgen in derselben
///   Liste. Geprüft über `erfassen-liste` und darüber, dass keine der
///   beiden alten Überschriften („Eigene Treffer", „Open Food Facts") mehr
///   dasteht — das ist die eine Beschriftung, die hier zählt, weil sie
///   genau das ist, was Tim weghaben wollte.
/// - **Ohne Netz** stehen die eigenen in derselben Liste, und **am Ende**
///   „Online nicht erreichbar".
/// - **Höchstens 25 Online-Zeilen, gezählt nach dem Zusammenfassen**;
///   gefragt werden 50 (`off_client_test.dart`).
///
/// ### Ergänzung vom 04.11.2026: verwerfen und umsortieren
///
/// Vom Koordinator nachgereicht, nach einem Vergleich mit der Suche einer
/// anderen App — nicht vom Test-Agenten entschieden:
///
/// - **Treffer ohne Kalorien werden verworfen**, nicht mehr ausgegraut
///   gezeigt. Das **ersetzt** die Vorgabe „erscheint, aber ausgegraut mit
///   Grund"; der Fall dazu ist umgebaut. Aus Kilojoule umgerechnete
///   Kalorien zählen als vorhanden.
/// - **Treffer über 900 kcal je 100 g werden verworfen** (reines Fett hat
///   rund 900; darüber ist es ein Datenfehler). 900 genau bleibt. **Eigene
///   Lebensmittel werden nicht gefiltert.**
/// - **Umsortieren nach Wortanfang:** Online-Treffer, bei denen jedes
///   Suchwort einen Wortanfang in Name oder Marke trifft, kommen nach vorn;
///   sonst bleibt die Reihenfolge der Antwort. Eigene stehen weiter vorn.
/// - **Reihenfolge der Schritte:** verwerfen → zusammenfassen →
///   umsortieren → auf 25 begrenzen. Begründet und mit je einem Fall
///   belegt im Kopf von `lebensmittel_dubletten_test.dart`; hier wird je
///   Regel nur geprüft, dass die Suche sie anwendet.
///
/// ### Entscheidung des Test-Agenten: eigene zählen nicht zu den 25
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung, an
/// den Koordinator gemeldet. Der Auftrag sagt „zeigt nach dem
/// Zusammenfassen höchstens 25", im Zusammenhang der Online-Abfrage. Die
/// eigenen Treffer sind fast immer gemeint und offline sofort da; sie
/// wegen Online-Treffern abzuschneiden, kehrte das um. Also: bis zu 25
/// Online-Zeilen **zusätzlich** zu den eigenen.
///
/// ## Entscheidung des Test-Agenten: 500 ms Entprellung
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
///
/// - **Open Food Facts begrenzt Suchanfragen** in seinen API-Regeln auf
///   wenige je Minute und IP. Eine Anfrage je Buchstabe brauchte das
///   Kontingent bei einem einzigen Wort auf.
/// - **Auf dem Telefon liegen zwischen zwei Buchstaben etwa 150–300 ms.**
///   Eine Pause von einer halben Sekunde heißt fast immer „Wort fertig".
/// - **Die Antwort selbst braucht ohnehin ein bis drei Sekunden.** 500 ms
///   davor fallen dagegen kaum ins Gewicht — und die eigenen Treffer
///   stehen sofort da, ungebremst.
///
/// Geprüft wird ein Fenster, nicht die genaue Zahl: 400 ms nach dem
/// letzten Buchstaben ist noch nichts gefragt, 600 ms danach genau einmal.
///
/// ## Entscheidung des Test-Agenten: zwei Zeichen, ohne Ränder gezählt
///
/// Brief: „Unter zwei Zeichen wird nicht online gesucht." Gezählt wird
/// nach dem Abschneiden der Leerzeichen — `" H "` ist ein Zeichen.
///
/// ## Entscheidung des Test-Agenten: der Platzhalter steht ab dem ersten
/// Buchstaben, nicht erst ab der Anfrage
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// Sobald zwei Zeichen dastehen, **gibt es** die Online-Anzeige. Stünde
/// sie während der Entprellung nicht da und danach als Platzhalter, spränge
/// der Schirm nach einer halben Sekunde — genau das, was „Eine Anzeige,
/// die es gibt, hat genau eine Form" verhindern soll (`CLAUDE.md`).
///
/// ## Entscheidung des Test-Agenten: die Namensnennung hängt an den Daten
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Die
/// Spec verlangt die ODbL-Nennung „auf jeden Produktschirm, dessen Daten
/// von dort stammen". Das sind OFF-Zeilen **und** übernommene Zeilen
/// (Herkunft `off`) — auch in „zuletzt benutzt". Ohne beides steht sie
/// **nicht** da: ein Hinweis auf eine Quelle, die nichts beigetragen hat,
/// wäre eine falsche Auskunft. Ihr Text muss „Open Food Facts" und „ODbL"
/// nennen — das ist die Lizenzpflicht, keine Beschriftung.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Ob „Online nicht erreichbar" in der Karte steht oder darunter.**
///   Geprüft wird seit dem 04.11.2026 nur, dass es **unter** den eigenen
///   Treffern steht — der Entwurf `suche-ohne-netz` zeichnet es dort, am
///   Ende der Liste.
/// - Wo Platzhalter und „nichts gefunden" in der einen Liste stehen.
/// - Wortlaut, Farben, Abstände, die Marke in der Zeile, der Text des
///   Abzeichens. Ob ein Online-Treffer ein Abzeichen `OFF` trägt (der
///   Entwurf zeichnet eins an einer Zeile) und welches Abzeichen ein
///   übernommenes Produkt (Herkunft `off`) trägt, legt diese Datei nicht
///   fest — nur, dass eine Online-Zeile **nicht** „eigen" heißt.
/// - Strichcode-Scanner (Kamera), Zurückmelden an OFF (#288).
///
/// Alle Produkte, Namen und Strichcodes hier sind **erfunden**.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const barcodeHafer = '0000000000017';
  const barcodeDrink = '0000000000024';
  const barcodeOhneName = '0000000000031';

  const eigenJe100g = Naehrwerte.je100g(kcal: 360, eiweissG: 11);

  Map<String, Object?> produkt({
    required String code,
    String? name,
    Map<String, Object?>? naehrwerte = const {
      'energy-kcal_100g': 371,
      'proteins_100g': 12.5,
    },
  }) => {'code': code, 'product_name': ?name, 'nutriments': ?naehrwerte};

  final hafer = produkt(code: barcodeHafer, name: 'Haferflocken Prüfmühle');
  final drink = produkt(
    code: barcodeDrink,
    name: 'Haferdrink Prüfhof',
    naehrwerte: const {'energy-kcal_100g': 45},
  );

  /// Die Antwort von `search.openfoodfacts.org/search` — Treffer unter
  /// `hits` (Vorgabe vom 04.11.2026, Kopf von `off_client_test.dart`).
  http.Response antwort(List<Map<String, Object?>> hits) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'count': hits.length,
        'is_count_exact': true,
        'page': 1,
        'page_count': 1,
        'page_size': 25,
        'timed_out': false,
        'hits': hits,
      }),
    ),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  ({ProviderContainer container, AppCache db, _Netz netz}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final netz = _Netz();

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: netz.client)),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, netz: netz);
  }

  Future<void> zeige(
    WidgetTester tester,
    ProviderContainer container,
    Widget inhalt,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: CupertinoPageScaffold(child: inhalt)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), text);
    await tester.pump();
  }

  /// Wartet die Entprellung ab und lässt die Antwort ankommen.
  Future<void> online(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Lässt jede noch laufende Frist verstreichen — Entprellung und die
  /// fünf Sekunden des Clients —, damit kein Zeitgeber über das Testende
  /// hinaus hängt.
  Future<void> ausklingen(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  }

  Future<int> legeEigenes(ProviderContainer container, String name) => container
      .read(erfassenProvider.notifier)
      .legeLebensmittelAn(LebensmittelVorlage(name: name, je100g: eigenJe100g));

  Future<int> anzahlLebensmittel(AppCache db) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS anzahl FROM lebensmittel;')
        .getSingle();
    return zeile.read<int>('anzahl');
  }

  Finder zeile(String schluessel) => find.byKey(Key(schluessel));

  Finder offZeilen() => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith('erfassen-off-') &&
        !k.value.startsWith('erfassen-off-grund-');
  });

  String textUnter(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map(textOf)
      .join(' ');

  /// Ein Treffer der Namenssuche mit Marken als **Liste** — so, wie
  /// `search.openfoodfacts.org` sie schickt. Ohne [kcal] fehlt der
  /// Schlüssel `energy-kcal_100g` ganz.
  Map<String, Object?> glas(
    String code,
    String name, {
    num? kcal,
    List<String> marken = const [],
  }) => {
    'code': code,
    'product_name': name,
    'brands': marken,
    'nutriments': {'energy-kcal_100g': ?kcal, 'proteins_100g': 6.3},
  };

  Future<int> legeEigenesMit(
    ProviderContainer container,
    String name,
    double kcal,
  ) => container
      .read(erfassenProvider.notifier)
      .legeLebensmittelAn(
        LebensmittelVorlage(
          name: name,
          je100g: Naehrwerte.je100g(kcal: kcal),
        ),
      );

  /// Das Abzeichen „eigen" **unterhalb** einer Zeile.
  Finder abzeichenIn(Finder wo) => find.descendant(
    of: wo,
    matching: find.byKey(const Key('erfassen-abzeichen-eigen')),
  );

  /// Die eine Liste.
  Finder inListe(Finder wo) => find.descendant(
    of: find.byKey(const Key('erfassen-liste')),
    matching: wo,
  );

  /// Eine der beiden Überschriften, die es bis zum 04.11.2026 gab — in
  /// welcher Schreibweise auch immer (die Kapitel stehen in Versalien).
  Finder alteUeberschrift() => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        const {
          'eigene treffer',
          'open food facts',
        }.contains(textOf(w).trim().toLowerCase()),
  );

  Finder gruende() => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('erfassen-off-grund-');
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Eigene zuerst, dann Open Food Facts', () {
    testWidgets('OFF-Treffer stehen unter den eigenen', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer, drink]);
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(zeile('erfassen-off-$barcodeHafer'), findsOneWidget);
      expect(zeile('erfassen-off-$barcodeDrink'), findsOneWidget);

      final obenEigen = tester.getTopLeft(zeile('erfassen-treffer-$eigen')).dy;
      for (final code in [barcodeHafer, barcodeDrink]) {
        expect(
          tester.getTopLeft(zeile('erfassen-off-$code')).dy,
          greaterThan(obenEigen),
          reason:
              'was man selbst angelegt oder gebucht hat, ist fast immer '
              'gemeint (Spec) — es steht oben',
        );
      }
      await ausklingen(tester);
    });

    testWidgets('während online gesucht wird, stehen die eigenen schon da — '
        'online ein Platzhalter, kein Grund (Fehler 01)', (tester) async {
      final b = behaelter(); // ohne Antwort: Die Anfrage hängt.
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Noch in der Entprellung.
      expect(b.netz.anfragen, isEmpty);
      expect(
        zeile('erfassen-treffer-$eigen'),
        findsOneWidget,
        reason: 'die eigenen Treffer warten nicht auf das Netz',
      );
      expect(
        zeile('erfassen-online-laedt'),
        findsOneWidget,
        reason:
            'die Online-Anzeige gibt es ab zwei Zeichen — erschiene sie erst '
            'nach der Entprellung, spränge der Schirm',
      );
      expect(zeile('erfassen-online-leer'), findsNothing);
      expect(zeile('erfassen-online-kein-netz'), findsNothing);

      // Die Anfrage läuft.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(b.netz.anfragen, hasLength(1));
      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(zeile('erfassen-online-laedt'), findsOneWidget);
      expect(
        zeile('erfassen-online-leer'),
        findsNothing,
        reason:
            'während gelesen wird, ist nichts entschieden — ein „nichts '
            'gefunden" hier wäre Fehler 01',
      );
      expect(zeile('erfassen-online-kein-netz'), findsNothing);
      expect(offZeilen(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('nach 5 Sekunden ohne Antwort: „Online nicht erreichbar", '
        'die eigenen bleiben', (tester) async {
      final b = behaelter(); // ohne Antwort: Die Anfrage hängt.
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(b.netz.anfragen, hasLength(1));

      // 4,9 s nach dem Buchstaben — die Anfrage läuft höchstens 4,5 s.
      await tester.pump(const Duration(milliseconds: 4300));
      await tester.pump();
      expect(zeile('erfassen-online-laedt'), findsOneWidget);
      expect(zeile('erfassen-online-kein-netz'), findsNothing);

      // 5,9 s nach dem Buchstaben — die Anfrage läuft mindestens 5,3 s.
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(zeile('erfassen-online-kein-netz'), findsOneWidget);
      expect(zeile('erfassen-online-laedt'), findsNothing);
      expect(zeile('erfassen-online-leer'), findsNothing);
      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Kein Netz und nichts gefunden werden nicht vermischt', () {
    testWidgets('ohne Netz: die eigenen stehen weiter da, dazu „Online nicht '
        'erreichbar"', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => throw const SocketException('weg (erfunden)');
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(zeile('erfassen-online-kein-netz'), findsOneWidget);
      expect(
        zeile('erfassen-online-leer'),
        findsNothing,
        reason:
            '„kein Netz" ist nicht „nichts gefunden" — dieselbe Regel wie '
            'bei fehlenden Health-Daten',
      );
      expect(zeile('erfassen-online-laedt'), findsNothing);
      expect(offZeilen(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('nichts gefunden: der Grund steht da, „kein Netz" nicht', (
      tester,
    ) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort(const []);
      await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-online-leer'), findsOneWidget);
      expect(zeile('erfassen-online-kein-netz'), findsNothing);
      expect(zeile('erfassen-online-laedt'), findsNothing);
      expect(offZeilen(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('ein Produkt ohne Namen erscheint nicht', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer, produkt(code: barcodeOhneName)]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-off-$barcodeHafer'), findsOneWidget);
      expect(zeile('erfassen-off-$barcodeOhneName'), findsNothing);

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ohne Kalorien kein Eintrag', () {
    // Bis zum 04.11.2026: „erscheint mit Grund und lässt sich nicht
    // wählen". Seit der Ergänzung vom selben Tag verworfen (Dateikopf).
    testWidgets('ein Treffer ohne Kalorien erscheint nicht — auch nicht '
        'ausgegraut', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        hafer,
        produkt(
          code: barcodeDrink,
          name: 'Haferdrink Prüfhof',
          naehrwerte: const {'proteins_100g': 1},
        ),
      ]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-off-$barcodeHafer'), findsOneWidget);
      expect(
        zeile('erfassen-off-$barcodeDrink'),
        findsNothing,
        reason:
            'ohne Kalorien kein Eintrag — und seit dem 04.11.2026 auch keine '
            'Zeile: sie war Rauschen',
      );
      expect(gruende(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('aus Kilojoule umgerechnete Kalorien zählen als vorhanden', (
      tester,
    ) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        produkt(
          code: barcodeDrink,
          name: 'Haferdrink Prüfhof',
          naehrwerte: const {'energy-kj_100g': 1674},
        ),
      ]);
      LebensmittelVorlage? gewaehlt;
      await zeige(
        tester,
        b.container,
        SucheView(onGewaehlt: (v) => gewaehlt = v),
      );

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-off-$barcodeDrink'), findsOneWidget);
      await tester.tap(zeile('erfassen-off-$barcodeDrink'));
      await tester.pumpAndSettle();
      // 1674 kJ / 4,184 = 400,1 kcal (`off_client_test.dart`).
      expect(gewaehlt?.je100g.kcal, closeTo(1674 / 4.184, 0.01));

      await ausklingen(tester);
    });

    testWidgets('ein Treffer mit Kalorien meldet die Vorlage zum Buchen — '
        'ohne Schlüssel, Herkunft off', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      LebensmittelVorlage? gewaehlt;
      await zeige(
        tester,
        b.container,
        SucheView(onGewaehlt: (v) => gewaehlt = v),
      );

      await tippe(tester, 'Hafer');
      await online(tester);
      await tester.tap(zeile('erfassen-off-$barcodeHafer'));
      await tester.pumpAndSettle();

      expect(gewaehlt, isNotNull);
      expect(
        gewaehlt!.id,
        isNull,
        reason: 'übernommen wird erst beim Buchen, nicht beim Antippen',
      );
      expect(gewaehlt!.herkunft, Herkunft.off);
      expect(gewaehlt!.barcode, barcodeHafer);
      expect(gewaehlt!.name, 'Haferflocken Prüfmühle');
      expect(gewaehlt!.je100g.kcal, 371);
      expect(gewaehlt!.je100g.fettG, isNull);
      expect(
        await anzahlLebensmittel(b.db),
        0,
        reason: 'angetippt ist nicht gebucht',
      );

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Doppelte erscheinen einmal, als eigene', () {
    testWidgets('ein Strichcode, der schon in der eigenen Tabelle liegt', (
      tester,
    ) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer, drink]);
      final id = await b.container
          .read(lebensmittelRepositoryProvider)
          .uebernimm(
            const LebensmittelVorlage(
              name: 'Haferflocken Prüfmühle',
              je100g: Naehrwerte.je100g(kcal: 371),
              barcode: barcodeHafer,
              herkunft: Herkunft.off,
            ),
          );
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-treffer-$id'), findsOneWidget);
      expect(
        zeile('erfassen-off-$barcodeHafer'),
        findsNothing,
        reason:
            'derselbe Strichcode zweimal sähe aus wie zwei Produkte — er '
            'steht einmal da, als eigener',
      );
      expect(zeile('erfassen-off-$barcodeDrink'), findsOneWidget);

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Tim, 04.11.2026: „man findet direkt 8000 mal das gleiche" und „eigene
  // Treffer sollen einfach mit den anderen gemischt werden, höchstens mit
  // einem Tag gekennzeichnet". Die Regel prüft der Kern
  // (`lebensmittel_dubletten_test.dart`); hier, dass die Suche sie anwendet.
  group('Eine Liste, gleiche Produkte einmal', () {
    // Ein erfundenes Glas in fünf Fassungen — die Form der Dubletten aus
    // der echten Suche, nicht das echte Produkt.
    const glasOhneKcal = '0000000001001';
    const glasErstes = '0000000001018';
    const glasZweites = '0000000001025';
    const glasDrittes = '0000000001032';
    const glasViertes = '0000000001049';
    const glasVariante = '0000000001056';

    final fuenfFassungen = [
      glas(glasOhneKcal, 'NUSSPRÜFCREME', marken: ['Prüfhaus']),
      glas(
        glasErstes,
        'Nussprüfcreme',
        kcal: 539,
        marken: ['Prüfhaus', 'Musterwerk'],
      ),
      glas(
        glasZweites,
        'nussprüfcreme',
        kcal: 544,
        marken: ['Musterwerk', 'Prüfhaus'],
      ),
      glas(
        glasDrittes,
        'Nussprüfcreme ',
        kcal: 546,
        marken: ['Glasmanufaktur Prüf'],
      ),
      glas(glasViertes, 'Nussprüfcreme', kcal: 539.0, marken: ['Musterwerk']),
    ];

    testWidgets('dasselbe Glas in fünf Fassungen steht einmal da — buchbar, '
        'vertreten vom ersten mit Kalorien', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort(fuenfFassungen);
      LebensmittelVorlage? gewaehlt;
      await zeige(
        tester,
        b.container,
        SucheView(onGewaehlt: (v) => gewaehlt = v),
      );

      await tippe(tester, 'Nussprüfcreme');
      await online(tester);

      expect(
        offZeilen(),
        findsOneWidget,
        reason:
            'gleicher Name, Kalorien innerhalb von 3 %, Marke egal — eine '
            'Zeile, nicht fünf',
      );
      expect(
        zeile('erfassen-off-$glasErstes'),
        findsOneWidget,
        reason:
            'Vertreter ist der erste Treffer in der Reihenfolge der Antwort, '
            'der nicht verworfen wird — der allererste hat keine Kalorien',
      );
      expect(
        gruende(),
        findsNothing,
        reason:
            'der Treffer ohne Kalorien wird verworfen und steht nicht '
            'ausgegraut daneben',
      );

      await tester.tap(zeile('erfassen-off-$glasErstes'));
      await tester.pumpAndSettle();
      expect(gewaehlt?.barcode, glasErstes);
      expect(gewaehlt?.je100g.kcal, 539);

      await ausklingen(tester);
    });

    testWidgets('eine Variante mit eigenem Namen bleibt eine eigene Zeile', (
      tester,
    ) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        ...fuenfFassungen,
        glas(
          glasVariante,
          'Nussprüfcreme B-fit',
          kcal: 520,
          marken: ['Prüfhaus'],
        ),
      ]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Nussprüfcreme');
      await online(tester);

      expect(offZeilen(), findsNWidgets(2));
      expect(zeile('erfassen-off-$glasErstes'), findsOneWidget);
      expect(zeile('erfassen-off-$glasVariante'), findsOneWidget);

      await ausklingen(tester);
    });

    testWidgets('gleicher Name, mehr als 3 % auseinander: zwei Zeilen', (
      tester,
    ) async {
      const leicht = '0000000001063';
      const schwer = '0000000001070';
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        glas(leicht, 'Prüfflocken', kcal: 370, marken: ['Prüfhaus']),
        glas(schwer, 'Prüfflocken', kcal: 400, marken: ['Prüfhaus']),
      ]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Prüfflocken');
      await online(tester);

      expect(zeile('erfassen-off-$leicht'), findsOneWidget);
      expect(zeile('erfassen-off-$schwer'), findsOneWidget);

      await ausklingen(tester);
    });

    testWidgets('ein eigenes Lebensmittel vertritt den Online-Treffer '
        'gleichen Namens — als eigenes, mit Abzeichen', (tester) async {
      const fastGleich = '0000000001087';
      const ohneKcal = '0000000001094';
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        glas(fastGleich, 'haferflocken', kcal: 370, marken: ['Prüfmühle']),
        glas(ohneKcal, 'Haferflocken', marken: ['Musterwerk']),
        drink,
      ]);
      final eigen = await legeEigenesMit(b.container, 'Haferflocken', 372);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Haferflocken');
      await online(tester);

      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(
        abzeichenIn(zeile('erfassen-treffer-$eigen')),
        findsOneWidget,
        reason: 'eigene tragen ein Abzeichen „eigen"',
      );
      expect(
        zeile('erfassen-off-$fastGleich'),
        findsNothing,
        reason:
            'gleicher Name, 370 statt 372 kcal — das eigene vertritt ihn, '
            'auch ohne gleichen Strichcode',
      );
      expect(
        zeile('erfassen-off-$ohneKcal'),
        findsNothing,
        reason: 'ohne Kalorien wird verworfen — es bleibt die eigene Zeile',
      );
      expect(zeile('erfassen-off-$barcodeDrink'), findsOneWidget);

      await ausklingen(tester);
    });

    testWidgets('eigene stehen vorn, in derselben Liste, ohne eigene '
        'Überschrift', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer, drink]);
      final brei = await legeEigenes(b.container, 'Haferbrei eigen');
      final keks = await legeEigenes(b.container, 'Haferkeks eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      final eigene = [
        zeile('erfassen-treffer-$brei'),
        zeile('erfassen-treffer-$keks'),
      ];
      final fremde = [
        zeile('erfassen-off-$barcodeHafer'),
        zeile('erfassen-off-$barcodeDrink'),
      ];

      for (final z in [...eigene, ...fremde]) {
        expect(
          inListe(z),
          findsOneWidget,
          reason: 'eine Liste, keine Abschnitte — $z',
        );
      }
      for (final z in eigene) {
        expect(abzeichenIn(z), findsOneWidget, reason: '$z');
      }
      for (final z in fremde) {
        expect(
          abzeichenIn(z),
          findsNothing,
          reason: 'ein Online-Treffer ist nicht „eigen" — $z',
        );
      }

      final untenEigene = eigene
          .map((z) => tester.getBottomLeft(z).dy)
          .reduce((a, b) => a > b ? a : b);
      for (final z in fremde) {
        expect(
          tester.getTopLeft(z).dy,
          greaterThanOrEqualTo(untenEigene),
          reason:
              'eigene stehen vorn — sie sind fast immer gemeint und offline '
              'sofort da',
        );
      }

      expect(
        alteUeberschrift(),
        findsNothing,
        reason:
            'Tim: „eigene Treffer sollen einfach mit den anderen gemischt '
            'werden" — keine Überschrift „Eigene Treffer", keine '
            '„Open Food Facts"',
      );

      await ausklingen(tester);
    });

    testWidgets('ohne Netz: die eigenen in derselben Liste, am Ende „Online '
        'nicht erreichbar"', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => throw const SocketException('weg (erfunden)');
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      final eigeneZeile = zeile('erfassen-treffer-$eigen');
      expect(inListe(eigeneZeile), findsOneWidget);
      expect(abzeichenIn(eigeneZeile), findsOneWidget);
      expect(zeile('erfassen-online-kein-netz'), findsOneWidget);
      expect(
        tester.getTopLeft(zeile('erfassen-online-kein-netz')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(eigeneZeile).dy),
        reason:
            'der Satz steht am Ende — dort, wo sonst die Online-Treffer '
            'folgten; oben ließe er den ganzen Schirm kaputt aussehen',
      );
      expect(alteUeberschrift(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('fragt 50 und zeigt höchstens 25 — gezählt nach dem '
        'Zusammenfassen', (tester) async {
      String code(int n) => '00000002${n.toString().padLeft(5, '0')}';
      // Zehn Gruppen zu je drei Fassungen (0–29), dann zwanzig
      // verschiedene (30–49). Zusammengefasst 30 Zeilen, gezeigt 25.
      // Würde vor dem Zusammenfassen auf 25 gekürzt, blieben neun.
      final hits = [
        for (var g = 0; g < 10; g++)
          for (final (i, kcal) in [(0, 200), (1, 202), (2, 199)])
            glas(code(3 * g + i), 'Prüfgruppe $g', kcal: kcal),
        for (var i = 30; i < 50; i++)
          glas(code(i), 'Prüfprodukt $i', kcal: 100),
      ];
      final b = behaelter();
      b.netz.antwort = (_) => antwort(hits);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Prüf');
      await online(tester);

      expect(b.netz.anfragen.single.url.queryParameters['page_size'], '50');
      expect(offZeilen(), findsNWidgets(25));
      final erwartet = [
        for (var g = 0; g < 10; g++) 3 * g,
        for (var i = 30; i < 45; i++) i,
      ];
      for (final n in erwartet) {
        expect(zeile('erfassen-off-${code(n)}'), findsOneWidget, reason: '$n');
      }

      await ausklingen(tester);
    });

    testWidgets('eigene zählen nicht zu den 25', (tester) async {
      String code(int n) => '00000003${n.toString().padLeft(5, '0')}';
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        for (var i = 0; i < 30; i++) glas(code(i), 'Prüfprodukt $i', kcal: 100),
      ]);
      final eigen = await legeEigenes(b.container, 'Prüfgericht eigen');
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Prüf');
      await online(tester);

      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(
        offZeilen(),
        findsNWidgets(25),
        reason:
            'Entscheidung des Test-Agenten (Dateikopf): die eigenen Treffer '
            'verbrauchen das Kontingent der Online-Zeilen nicht',
      );

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Ergänzung vom 04.11.2026 (Dateikopf). Die Grenzfälle und die
  // Reihenfolge der Schritte prüft der Kern; hier, dass die Suche sie
  // anwendet.
  group('Verworfen und umsortiert', () {
    testWidgets('über 900 kcal je 100 g wird verworfen, 900 genau bleibt — '
        'eigene werden nicht gefiltert', (tester) async {
      const zuViel = '0000000004001';
      const genau = '0000000004018';
      const weitDrueber = '0000000004025';
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        glas(zuViel, 'Prüföl Raffinat', kcal: 905, marken: ['Prüfhaus']),
        glas(genau, 'Prüfschmalz', kcal: 900, marken: ['Musterwerk']),
        glas(weitDrueber, 'Prüfbutter Rein', kcal: 3700),
      ]);
      final eigen = await legeEigenesMit(b.container, 'Prüföl eigen', 950);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Prüf');
      await online(tester);

      expect(
        zeile('erfassen-off-$zuViel'),
        findsNothing,
        reason:
            'reines Fett hat rund 900 kcal/100 g — darüber ist es ein '
            'Datenfehler in Open Food Facts',
      );
      expect(zeile('erfassen-off-$weitDrueber'), findsNothing);
      expect(zeile('erfassen-off-$genau'), findsOneWidget);
      expect(
        zeile('erfassen-treffer-$eigen'),
        findsOneWidget,
        reason: 'ein eigenes Lebensmittel hat Tim selbst eingetragen',
      );

      await ausklingen(tester);
    });

    testWidgets('Treffer, bei denen jedes Suchwort einen Wortanfang in Name '
        'oder Marke trifft, stehen vorn', (tester) async {
      const keineWorte = '0000000004032';
      const beideImGlas = '0000000004049';
      const nurEinWort = '0000000004056';
      const beideImRiegel = '0000000004063';
      final b = behaelter();
      b.netz.antwort = (_) => antwort([
        glas(keineWorte, 'Haselnusskekse', kcal: 480, marken: ['Musterwerk']),
        glas(beideImGlas, 'Nussprüfcreme', kcal: 539, marken: ['Prüfhaus']),
        glas(nurEinWort, 'Prüfhaus Müsli', kcal: 380, marken: ['Musterwerk']),
        glas(
          beideImRiegel,
          'Knusper Nussriegel',
          kcal: 450,
          marken: ['Prüfhaus'],
        ),
      ]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Prüfhaus Nuss');
      await online(tester);

      double oben(String code) =>
          tester.getTopLeft(zeile('erfassen-off-$code')).dy;
      final reihenfolge = [beideImGlas, beideImRiegel, keineWorte, nurEinWort];
      for (var i = 1; i < reihenfolge.length; i++) {
        expect(
          oben(reihenfolge[i]),
          greaterThan(oben(reihenfolge[i - 1])),
          reason:
              'erwartet ${reihenfolge.join(', ')} — vorn die, bei denen '
              '„prüfhaus" und „nuss" je einen Wortanfang treffen (die Marke '
              'zählt mit), danach der Rest in der Reihenfolge der Antwort',
        );
      }

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Nicht bei jedem Tastendruck', () {
    testWidgets('unter zwei Zeichen wird nicht online gesucht', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeige(tester, b.container, const SucheView());

      for (final text in ['H', ' H ']) {
        await tippe(tester, text);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(b.netz.anfragen, isEmpty, reason: '„$text"');
        expect(zeile('erfassen-online-laedt'), findsNothing, reason: text);
        expect(zeile('erfassen-online-leer'), findsNothing, reason: text);
        expect(zeile('erfassen-online-kein-netz'), findsNothing, reason: text);
        expect(offZeilen(), findsNothing, reason: text);
      }

      await ausklingen(tester);
    });

    testWidgets('schnelles Tippen ergibt eine Anfrage, nicht eine je '
        'Buchstabe', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeige(tester, b.container, const SucheView());

      for (final text in ['Ha', 'Haf', 'Hafe']) {
        await tippe(tester, text);
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tippe(tester, 'Hafer');

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        b.netz.anfragen,
        isEmpty,
        reason: '400 ms nach dem letzten Buchstaben tippt Tim vielleicht noch',
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(b.netz.anfragen, hasLength(1));
      expect(
        b.netz.anfragen.single.url.queryParameters['q'],
        'Hafer',
        reason: 'gefragt wird nach dem, was am Ende dasteht',
      );

      await ausklingen(tester);
      expect(b.netz.anfragen, hasLength(1));
    });

    testWidgets('eine veraltete Antwort überschreibt keine neuere', (
      tester,
    ) async {
      final b = behaelter(); // ohne Antwort: Die Anfragen hängen.
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tippe(tester, 'Haferdrink');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(b.netz.anfragen, hasLength(2));

      // Die jüngere kommt zuerst an, die ältere danach.
      b.netz.beantworte(1, antwort([drink]));
      await tester.pump();
      b.netz.beantworte(0, antwort([hafer]));
      await tester.pumpAndSettle();

      expect(zeile('erfassen-off-$barcodeDrink'), findsOneWidget);
      expect(
        zeile('erfassen-off-$barcodeHafer'),
        findsNothing,
        reason:
            'im Feld steht „Haferdrink" — die Antwort auf „Hafer" kam nur '
            'später an und gehört nicht mehr dazu',
      );

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Namensnennung (ODbL)', () {
    testWidgets('steht da, sobald OFF-Treffer gezeigt werden', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeige(tester, b.container, const SucheView());

      await tippe(tester, 'Hafer');
      await online(tester);

      expect(zeile('erfassen-odbl'), findsOneWidget);
      final text = textUnter(tester, zeile('erfassen-odbl'));
      expect(text, contains('Open Food Facts'));
      expect(text, contains('ODbL'));

      await ausklingen(tester);
    });

    testWidgets('steht nicht da, solange keine OFF-Daten zu sehen sind', (
      tester,
    ) async {
      final b = behaelter();
      final eigen = await legeEigenes(b.container, 'Haferbrei eigen');
      // #345: Ohne Suchtext steht nur Gebuchtes da. Gebucht, damit hier
      // wirklich ein eigenes Lebensmittel zu sehen ist.
      await b.container
          .read(lebensmittelRepositoryProvider)
          .merkeBenutzung(eigen, jetzt);
      await b.container.read(suchtrefferProvider.notifier).neuLesen();
      await zeige(tester, b.container, const SucheView());

      expect(zeile('erfassen-treffer-$eigen'), findsOneWidget);
      expect(
        zeile('erfassen-odbl'),
        findsNothing,
        reason:
            'nur eigene Lebensmittel, kein Suchtext — ein Hinweis auf eine '
            'Quelle, die nichts beigetragen hat, wäre eine falsche Auskunft',
      );
      expect(b.netz.anfragen, isEmpty);
    });

    testWidgets(
      'ein übernommenes Produkt in „zuletzt benutzt" bringt sie mit',
      (tester) async {
        final b = behaelter();
        final repo = b.container.read(lebensmittelRepositoryProvider);
        final id = await repo.uebernimm(
          const LebensmittelVorlage(
            name: 'Haferflocken Prüfmühle',
            je100g: Naehrwerte.je100g(kcal: 371),
            barcode: barcodeHafer,
            herkunft: Herkunft.off,
          ),
        );
        // #345: In „zuletzt benutzt" steht nur Gebuchtes — übernommen wird
        // beim Buchen, und Buchen merkt die Benutzung.
        await repo.merkeBenutzung(id, jetzt);
        await zeige(tester, b.container, const SucheView());

        expect(zeile('erfassen-treffer-$id'), findsOneWidget);
        expect(
          zeile('erfassen-odbl'),
          findsOneWidget,
          reason:
              'die Werte stammen aus Open Food Facts, auch wenn sie jetzt in '
              'der eigenen Tabelle liegen',
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Buchen aus der Suche', () {
    final navigator = GlobalKey<NavigatorState>();

    Future<void> zeigeSeite(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BehaelterImBaum(
          container: container,
          child: CupertinoApp(
            navigatorKey: navigator,
            home: const CupertinoPageScaffold(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> oeffneSuche(WidgetTester tester) async {
      unawaited(
        navigator.currentState!.push(
          CupertinoPageRoute<void>(
            builder: (_) => const SucheSeite(tagesSchluessel: heute),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// „Fertig" (#440, V29): Seit V26 bleibt die Suche nach dem Buchen
    /// offen; wer sie neu öffnen will, schließt sie erst.
    Future<void> fertig(WidgetTester tester) async {
      await tester.tap(zeile('erfassen-fertig'));
      await tester.pumpAndSettle();
      expect(find.byType(SucheView), findsNothing);
    }

    Future<List<Eintrag>> eintraegeHeute(AppCache db) =>
        ErnaehrungRepository(db).eintraegeAmTag(heute);

    testWidgets('ein OFF-Treffer wird beim Buchen übernommen — mit Strichcode '
        'und Herkunft off', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeigeSeite(tester, b.container);
      await oeffneSuche(tester);

      await tippe(tester, 'Hafer');
      await online(tester);
      await tester.tap(zeile('erfassen-off-$barcodeHafer'));
      await tester.pumpAndSettle();

      expect(find.byType(BuchungsBlatt), findsOneWidget);
      expect(
        await anzahlLebensmittel(b.db),
        0,
        reason: 'das Blatt ist offen, gebucht ist noch nichts',
      );

      await tester.tap(zeile('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(await anzahlLebensmittel(b.db), 1);
      final vorlage = await b.container
          .read(lebensmittelRepositoryProvider)
          .zuBarcode(barcodeHafer);
      expect(vorlage, isNotNull);
      expect(vorlage!.herkunft, Herkunft.off);
      expect(vorlage.name, 'Haferflocken Prüfmühle');

      final eintraege = await eintraegeHeute(b.db);
      expect(eintraege, hasLength(1));
      expect(eintraege.single.lebensmittelId, vorlage.id);

      await ausklingen(tester);
    });

    testWidgets('abgebrochen ist nicht gebucht — nichts wandert in die '
        'Tabelle', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeigeSeite(tester, b.container);
      await oeffneSuche(tester);

      await tippe(tester, 'Hafer');
      await online(tester);
      await tester.tap(zeile('erfassen-off-$barcodeHafer'));
      await tester.pumpAndSettle();
      expect(find.byType(BuchungsBlatt), findsOneWidget);

      // Neben das Blatt tippen — es nimmt 88 % der Höhe ein, oben bleibt
      // die Fläche, die es schließt. Kein Knopftext, keine Beschriftung.
      await tester.tapAt(const Offset(450, 40));
      await tester.pumpAndSettle();
      expect(find.byType(BuchungsBlatt), findsNothing);

      expect(await anzahlLebensmittel(b.db), 0);
      expect(await eintraegeHeute(b.db), isEmpty);

      await ausklingen(tester);
    });

    testWidgets('beim zweiten Mal steht es als eigenes da — und ein zweites '
        'Buchen legt kein zweites an', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeigeSeite(tester, b.container);

      // Das erste Mal: aus Open Food Facts.
      await oeffneSuche(tester);
      await tippe(tester, 'Hafer');
      await online(tester);
      await tester.tap(zeile('erfassen-off-$barcodeHafer'));
      await tester.pumpAndSettle();
      await tester.tap(zeile('buchung-sichern'));
      await tester.pumpAndSettle();
      await fertig(tester);
      await ausklingen(tester);

      final id =
          (await b.container
                  .read(lebensmittelRepositoryProvider)
                  .zuBarcode(barcodeHafer))!
              .id!;

      // Das zweite Mal: Open Food Facts liefert es wieder, es steht aber
      // einmal da — als eigenes.
      await oeffneSuche(tester);
      await tippe(tester, 'Hafer');
      await online(tester);
      expect(zeile('erfassen-treffer-$id'), findsOneWidget);
      expect(zeile('erfassen-off-$barcodeHafer'), findsNothing);

      await tester.tap(zeile('erfassen-treffer-$id'));
      await tester.pumpAndSettle();
      await tester.tap(zeile('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(await anzahlLebensmittel(b.db), 1);
      final eintraege = await eintraegeHeute(b.db);
      expect(eintraege, hasLength(2));
      expect(eintraege.map((e) => e.lebensmittelId).toSet(), {id});

      await ausklingen(tester);
    });

    testWidgets('ohne Netz findet die Suche ein einmal gebuchtes Produkt '
        'trotzdem', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => antwort([hafer]);
      await zeigeSeite(tester, b.container);

      await oeffneSuche(tester);
      await tippe(tester, 'Hafer');
      await online(tester);
      await tester.tap(zeile('erfassen-off-$barcodeHafer'));
      await tester.pumpAndSettle();
      await tester.tap(zeile('buchung-sichern'));
      await tester.pumpAndSettle();
      await fertig(tester);
      await ausklingen(tester);

      // Jetzt ist das Netz weg.
      b.netz.antwort = (_) => throw const SocketException('weg (erfunden)');
      final id =
          (await b.container
                  .read(lebensmittelRepositoryProvider)
                  .zuBarcode(barcodeHafer))!
              .id!;

      await oeffneSuche(tester);
      await tippe(tester, 'Hafer');
      await online(tester);

      expect(
        zeile('erfassen-treffer-$id'),
        findsOneWidget,
        reason: 'ab dem zweiten Mal offline da (#284)',
      );
      expect(zeile('erfassen-online-kein-netz'), findsOneWidget);

      await ausklingen(tester);
    });
  });
}

/// Ein Netz, das der Test in der Hand hat.
///
/// Mit [antwort] beantwortet es jede Anfrage sofort (oder wirft, was
/// [antwort] wirft). Ohne [antwort] **hängt** jede Anfrage, bis der Test
/// sie mit [beantworte] auflöst — die einzige zuverlässige Art, den
/// Zustand „online wird gesucht" festzuhalten.
class _Netz {
  final anfragen = <http.Request>[];
  final _offen = <Completer<http.Response>>[];

  http.Response Function(http.Request anfrage)? antwort;

  late final http.Client client = MockClient((anfrage) {
    anfragen.add(anfrage);
    final sofort = antwort;
    if (sofort != null) return Future.sync(() => sofort(anfrage));
    final offen = Completer<http.Response>();
    _offen.add(offen);
    return offen.future;
  });

  /// Löst die [nummer]-te hängende Anfrage (ab 0, in der Reihenfolge des
  /// Eintreffens) mit [mit] auf.
  void beantworte(int nummer, http.Response mit) =>
      _offen[nummer].complete(mit);
}
