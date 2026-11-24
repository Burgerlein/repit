import 'dart:async';

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
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/ernaehrung/anlegen_blatt.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/portion_dialog.dart';
import 'package:repit/ernaehrung/portions_abruf.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;

/// Widget-Tests für **Portion anlegen, ändern, löschen** (#400, unter
/// #325) — der Dialog, seine Wege im Buchungsblatt und der Abschnitt
/// „Portionen · freiwillig" im Anlegen-Blatt.
///
/// Geschrieben nach Task 8 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md`, der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (V3, V10, V11,
/// Entscheidung 2) und dem Entwurf `docs/screens/screens/erfassen.js`
/// (`portion-anlegen`, `portion-aendern`, `anlegen-portionen`) — **bevor**
/// Dialog und Abschnitt gebaut waren. Ein Agent, Test zuerst, rot gesehen,
/// vor der Implementierung committet (`CLAUDE.md`). Diese Datei darf
/// ausgeführt, aber nicht verändert werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// ```dart
/// // lib/ernaehrung/portion_dialog.dart
/// sealed class PortionDialogErgebnis {}
/// final class PortionGesichert extends PortionDialogErgebnis {
///   const PortionGesichert(this.name, this.mengeG);  // == und hashCode
///   final String name;     // ohne Ränder
///   final double mengeG;
/// }
/// final class PortionGeloescht extends PortionDialogErgebnis {}
///
/// /// `null` heißt „Abbrechen".
/// Future<PortionDialogErgebnis?> zeigePortionDialog(
///   BuildContext context, {
///   required String lebensmittelName,
///   Portion? portion,      // ohne: „Portion anlegen", mit: „Portion ändern"
///   required bool fluessig,
/// });
/// ```
///
/// ## Die Schlüssel — Festlegung des Test-Agenten
///
/// Im Dialog: `portion-dialog-name`, `portion-dialog-menge` (die beiden
/// Felder), `portion-dialog-sichern`, `portion-dialog-abbrechen` und, nur
/// beim Ändern, `portion-dialog-loeschen` (je eine
/// `CupertinoDialogAction`; gesperrt heißt `onPressed == null`). Im
/// Anlegen-Blatt: `anlegen-portion-<index>` (eine Zeile je Portion, ab 0)
/// und `anlegen-portion-neu` („Portion hinzufügen"). Die Schlüssel des
/// Buchungsblatts stehen in `portionen_blatt_test.dart`.
///
/// Alle Produkte, Namen, Zahlen und Strichcodes sind **erfunden**, alle
/// Zeitpunkte liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 12:30 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 10, 30);
  const heute = '2099-04-07';

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 570,
    eiweissG: 7.6,
    kohlenhydrateG: 50,
    fettG: 38,
  );
  const haferJe100g = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
  );

  // --- Hilfsmittel ---------------------------------------------------

  ({ProviderContainer container, AppCache db, List<http.Request> anfragen})
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final anfragen = <http.Request>[];
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        // Kein Fall hier fragt Open Food Facts. Fragte doch einer, hinge
        // die Anfrage und fiele über die Zahl auf.
        offClientProvider.overrideWithValue(
          OffClient(
            client: MockClient((anfrage) {
              anfragen.add(anfrage);
              return Completer<http.Response>().future;
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, anfragen: anfragen);
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

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: CupertinoPageScaffold(child: inhalt)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder schluessel(String s) => find.byKey(Key(s));

  String textUnter(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: schluessel(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  String feldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: schluessel(key),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  bool aktionGesperrt(WidgetTester tester, String key) =>
      tester.widget<CupertinoDialogAction>(schluessel(key)).onPressed == null;

  Future<void> tippe(WidgetTester tester, String key) async {
    await tester.tap(schluessel(key));
    await tester.pumpAndSettle();
  }

  Future<void> schreibe(WidgetTester tester, String key, String text) async {
    await tester.enterText(schluessel(key), text);
    await tester.pumpAndSettle();
  }

  /// Füllt den offenen Dialog und sichert.
  Future<void> sichere(WidgetTester tester, String name, String menge) async {
    await schreibe(tester, 'portion-dialog-name', name);
    await schreibe(tester, 'portion-dialog-menge', menge);
    await tippe(tester, 'portion-dialog-sichern');
  }

  Future<int> zeilenIn(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS n FROM $tabelle')
        .getSingle();
    return zeile.read<int>('n');
  }

  Future<BuchungsFormular> oeffne(
    ProviderContainer c,
    LebensmittelVorlage vorlage,
  ) => c
      .read(erfassenProvider.notifier)
      .oeffneFormular(vorlage: vorlage, tagesSchluessel: heute, jetzt: jetzt);

  Future<LebensmittelVorlage> vorlage(ProviderContainer c, int id) async =>
      (await c.read(lebensmittelRepositoryProvider).lies(id))!;

  Future<List<Portion>> portionenVon(ProviderContainer c, int id) =>
      c.read(portionenRepositoryProvider).fuer(id);

  Future<List<Eintrag>> eintraegeAm(ProviderContainer c, String tag) =>
      c.read(ernaehrungRepositoryProvider).eintraegeAmTag(tag);

  /// Ein übernommenes Produkt mit „Portion" (5,9 g) und „Packung" (225 g)
  /// aus Open Food Facts, schon nachgefragt — es fragt nicht noch einmal.
  /// Mit [gebucht] steht ein Eintrag „[gebucht] × Portion" am Vortag, und
  /// die Portion ist beim Öffnen samt Anzahl vorgewählt.
  Future<({int id, int portionId})> uebernommen(
    ProviderContainer c, {
    int? gebucht,
  }) async {
    final id = await c
        .read(lebensmittelRepositoryProvider)
        .legeAn(
          LebensmittelVorlage(
            name: 'Prüf-Bons Erfundenwerk',
            je100g: bonsJe100g,
            barcode: '0000000000086',
            herkunft: Herkunft.off,
            portionenAbgefragtAm: DateTime.utc(2099, 3, 1),
          ),
          portionen: const [
            Portion(name: 'Portion', mengeG: 5.9, herkunft: Herkunft.off),
            Portion(name: 'Packung', mengeG: 225, herkunft: Herkunft.off),
          ],
        );
    final portion = (await portionenVon(
      c,
      id,
    )).firstWhere((p) => p.name == 'Portion');
    if (gebucht != null) {
      await c
          .read(ernaehrungRepositoryProvider)
          .buche(
            Eintrag(
              tagesSchluessel: '2099-04-06',
              mahlzeit: Mahlzeit.snack,
              zeitpunkt: DateTime.utc(2099, 4, 6, 14, 20),
              lebensmittelId: id,
              name: 'Prüf-Bons Erfundenwerk',
              mengeG: gebucht * 5.9,
              naehrwerte: bonsJe100g.fuerMenge(gebucht * 5.9),
              portionId: portion.id,
              portionName: 'Portion',
              portionG: 5.9,
            ),
          );
    }
    return (id: id, portionId: portion.id!);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Der Dialog', () {
    /// Ein Knopf, der den Dialog öffnet und das Ergebnis festhält.
    Widget oeffner(
      void Function(PortionDialogErgebnis? e) merke, {
      Portion? portion,
    }) => Builder(
      builder: (context) => CupertinoButton(
        key: const Key('oeffnen'),
        onPressed: () async => merke(
          await zeigePortionDialog(
            context,
            lebensmittelName: 'Prüf-Hafer kernig',
            portion: portion,
            fluessig: false,
          ),
        ),
        child: const Text('öffnen'),
      ),
    );

    testWidgets('„Sichern" ist gesperrt bei leerem Namen oder Gramm ≤ 0 '
        '(V10)', (tester) async {
      final b = behaelter();
      PortionDialogErgebnis? ergebnis;
      var gemeldet = false;
      await zeige(
        tester,
        b.container,
        oeffner((e) {
          ergebnis = e;
          gemeldet = true;
        }),
      );
      await tippe(tester, 'oeffnen');

      expect(aktionGesperrt(tester, 'portion-dialog-sichern'), isTrue);
      expect(
        schluessel('portion-dialog-loeschen'),
        findsNothing,
        reason: 'beim Anlegen gibt es nichts zu löschen',
      );

      await schreibe(tester, 'portion-dialog-name', 'Schale');
      expect(aktionGesperrt(tester, 'portion-dialog-sichern'), isTrue);

      await schreibe(tester, 'portion-dialog-menge', '0');
      expect(aktionGesperrt(tester, 'portion-dialog-sichern'), isTrue);

      await schreibe(tester, 'portion-dialog-menge', '7,5');
      expect(aktionGesperrt(tester, 'portion-dialog-sichern'), isFalse);

      await schreibe(tester, 'portion-dialog-name', '   ');
      expect(
        aktionGesperrt(tester, 'portion-dialog-sichern'),
        isTrue,
        reason: 'ohne Ränder leer ist leer',
      );

      await schreibe(tester, 'portion-dialog-name', ' Schale ');
      await tippe(tester, 'portion-dialog-sichern');

      expect(gemeldet, isTrue);
      expect(ergebnis, const PortionGesichert('Schale', 7.5));
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('„Abbrechen" meldet null, „Portion löschen" meldet das '
        'Löschen — ohne weitere Rückfrage', (tester) async {
      final b = behaelter();
      const bon = Portion(id: 3, name: 'Bon', mengeG: 5.9);
      final ergebnisse = <PortionDialogErgebnis?>[];
      await zeige(tester, b.container, oeffner(ergebnisse.add, portion: bon));

      await tippe(tester, 'oeffnen');
      expect(feldText(tester, 'portion-dialog-name'), 'Bon');
      expect(feldText(tester, 'portion-dialog-menge'), '5,9');
      expect(aktionGesperrt(tester, 'portion-dialog-sichern'), isFalse);
      await tippe(tester, 'portion-dialog-abbrechen');

      await tippe(tester, 'oeffnen');
      await tippe(tester, 'portion-dialog-loeschen');

      expect(ergebnisse, [null, const PortionGeloescht()]);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Im Buchungsblatt', () {
    testWidgets('„+ Portion" → Sichern: Die neue Portion ist gewählt, '
        'Anzahl 1, und steht in der Tabelle', (tester) async {
      final b = behaelter();
      final id = await b.container
          .read(lebensmittelRepositoryProvider)
          .legeAn(
            const LebensmittelVorlage(
              name: 'Prüf-Hafer kernig',
              je100g: haferJe100g,
            ),
          );
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, await vorlage(b.container, id)),
        ),
      );

      await tippe(tester, 'portion-neu');
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await sichere(tester, 'Schale', '60');

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(schluessel('portion-knopf-0'), findsOneWidget);
      expect(feldText(tester, 'portion-anzahl'), '1');

      final inTabelle = await portionenVon(b.container, id);
      expect(inTabelle, hasLength(1));
      expect(inTabelle.single.name, 'Schale');
      expect(inTabelle.single.mengeG, 60);

      await tippe(tester, 'buchung-sichern');
      final eintrag = (await eintraegeAm(b.container, heute)).single;
      expect(eintrag.mengeG, 60);
      expect(eintrag.portionId, inTabelle.single.id);
      expect(eintrag.portionName, 'Schale');
    });

    testWidgets('Langdruck auf „Portion (5,9 g)" → „Bon" sichern: Der Knopf '
        'heißt „Bon (5,9 g)" und bleibt gewählt', (tester) async {
      final b = behaelter();
      final (:id, :portionId) = await uebernommen(b.container, gebucht: 2);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, await vorlage(b.container, id)),
        ),
      );
      expect(feldText(tester, 'portion-anzahl'), '2');

      await tester.longPress(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(feldText(tester, 'portion-dialog-name'), 'Portion');
      await schreibe(tester, 'portion-dialog-name', 'Bon');
      await tippe(tester, 'portion-dialog-sichern');

      expect(textUnter(tester, 'portion-knopf-0'), 'Bon (5,9 g)');
      expect(
        feldText(tester, 'portion-anzahl'),
        '2',
        reason: 'V11: Geändert bleibt sie gewählt, samt Anzahl',
      );

      final inTabelle = await portionenVon(b.container, id);
      expect(
        inTabelle.firstWhere((p) => p.id == portionId).name,
        'Bon',
        reason: 'ein gespeichertes Lebensmittel ändert die Tabelle',
      );

      await tippe(tester, 'buchung-sichern');
      final eintrag = (await eintraegeAm(b.container, heute)).single;
      expect(eintrag.portionId, portionId);
      expect(eintrag.portionName, 'Bon');
      expect(eintrag.mengeG, closeTo(11.8, 1e-9));
    });

    testWidgets('„Portion löschen" auf die gewählte: „g" mit der bisherigen '
        'Menge, und der gebuchte Eintrag behält seinen Schnappschuss (V11)', (
      tester,
    ) async {
      final b = behaelter();
      final (:id, :portionId) = await uebernommen(b.container, gebucht: 2);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, await vorlage(b.container, id)),
        ),
      );

      await tester.longPress(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();
      await tippe(tester, 'portion-dialog-loeschen');

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(schluessel('portion-anzahl'), findsNothing);
      expect(feldText(tester, 'buchung-menge'), '11,8');
      expect(
        schluessel('portion-knopf-1'),
        findsNothing,
        reason: 'nur die Packung bleibt',
      );

      final inTabelle = await portionenVon(b.container, id);
      expect(inTabelle.map((p) => p.id), isNot(contains(portionId)));

      final alt = (await eintraegeAm(b.container, '2099-04-06')).single;
      expect(alt.portionId, portionId);
      expect(alt.portionName, 'Portion');
      expect(alt.portionG, 5.9);
    });

    testWidgets('auf „g" gibt es keinen Langdruck', (tester) async {
      final b = behaelter();
      final (:id, portionId: _) = await uebernommen(b.container);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, await vorlage(b.container, id)),
        ),
      );

      await tester.longPress(schluessel('portion-gramm'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets('ein noch nicht übernommener Treffer: Portion anlegen, dann '
        'abbrechen — keine Zeile in lebensmittel und portionen (V3)', (
      tester,
    ) async {
      final b = behaelter();
      // Gescannt: Die Antwort kam mit dem Scan und kannte keine Portion.
      const gescannt = LebensmittelVorlage(
        name: 'Prüf-Banane lose',
        je100g: Naehrwerte.je100g(kcal: 93),
        barcode: '0000000000093',
        herkunft: Herkunft.off,
        offPortionen: [],
      );
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, gescannt),
          abruf: brauchtAbruf(gescannt),
        ),
      );

      await tippe(tester, 'portion-neu');
      await sichere(tester, 'Stück', '120');

      expect(schluessel('portion-knopf-0'), findsOneWidget);
      expect(feldText(tester, 'portion-anzahl'), '1');
      expect(
        await zeilenIn(b.db, 'lebensmittel'),
        0,
        reason: 'übernommen wird erst beim Buchen (#284)',
      );
      expect(await zeilenIn(b.db, 'portionen'), 0);

      // „Abbrechen": Das Blatt geht, ohne zu buchen.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(await zeilenIn(b.db, 'lebensmittel'), 0);
      expect(await zeilenIn(b.db, 'portionen'), 0);
      expect(b.anfragen, isEmpty);
    });

    testWidgets('ein noch nicht übernommener Treffer: Portion anlegen, dann '
        'buchen — Lebensmittel, Portion und Eintrag stehen da', (tester) async {
      final b = behaelter();
      const gescannt = LebensmittelVorlage(
        name: 'Prüf-Banane lose',
        je100g: Naehrwerte.je100g(kcal: 93),
        barcode: '0000000000093',
        herkunft: Herkunft.off,
        offPortionen: [],
      );
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: await oeffne(b.container, gescannt)),
      );

      await tippe(tester, 'portion-neu');
      await sichere(tester, 'Stück', '120');
      await tippe(tester, 'buchung-sichern');

      final id =
          (await b.container
                  .read(lebensmittelRepositoryProvider)
                  .zuBarcode('0000000000093'))!
              .id!;
      final inTabelle = await portionenVon(b.container, id);
      expect(inTabelle.map((p) => p.name), ['Stück']);
      final eintrag = (await eintraegeAm(b.container, heute)).single;
      expect(eintrag.mengeG, 120);
      expect(eintrag.portionName, 'Stück');
      expect(eintrag.portionId, inTabelle.single.id);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Im Anlegen-Blatt', () {
    testWidgets('ohne Portion steht nur „Portion hinzufügen" da', (
      tester,
    ) async {
      final b = behaelter();
      await zeige(tester, b.container, const AnlegenBlatt());

      expect(schluessel('anlegen-portion-neu'), findsOneWidget);
      expect(schluessel('anlegen-portion-0'), findsNothing);
    });

    testWidgets('zwei Portionen anlegen und sichern — beide in der Tabelle, '
        'am neuen Lebensmittel', (tester) async {
      final b = behaelter();
      int? neu;
      await zeige(
        tester,
        b.container,
        AnlegenBlatt(onFertig: (id) => neu = id),
      );

      await schreibe(tester, 'anlegen-name', 'Prüf-Hafer kernig');
      await schreibe(tester, 'anlegen-kcal', '372');

      await tippe(tester, 'anlegen-portion-neu');
      await sichere(tester, 'Packung', '500');
      await tippe(tester, 'anlegen-portion-neu');
      await sichere(tester, 'Schale', '60');

      expect(schluessel('anlegen-portion-0'), findsOneWidget);
      expect(schluessel('anlegen-portion-1'), findsOneWidget);
      expect(schluessel('anlegen-portion-neu'), findsOneWidget);
      expect(
        await zeilenIn(b.db, 'portionen'),
        0,
        reason: 'vor dem Sichern liegt nichts in der Tabelle',
      );

      await tippe(tester, 'anlegen-sichern');

      expect(neu, isNotNull);
      final inTabelle = await portionenVon(b.container, neu!);
      expect(inTabelle.map((p) => (p.name, p.mengeG)), [
        ('Schale', 60.0),
        ('Packung', 500.0),
      ]);
    });

    testWidgets('eine Zeile antippen öffnet „Portion ändern" — umbenennen '
        'und löschen', (tester) async {
      final b = behaelter();
      int? neu;
      await zeige(
        tester,
        b.container,
        AnlegenBlatt(onFertig: (id) => neu = id),
      );
      await schreibe(tester, 'anlegen-name', 'Prüf-Hafer kernig');
      await schreibe(tester, 'anlegen-kcal', '372');
      await tippe(tester, 'anlegen-portion-neu');
      await sichere(tester, 'Schale', '60');
      await tippe(tester, 'anlegen-portion-neu');
      await sichere(tester, 'Packung', '500');

      // Die Schale (60 g) steht vorn: umbenennen.
      await tippe(tester, 'anlegen-portion-0');
      expect(feldText(tester, 'portion-dialog-name'), 'Schale');
      await schreibe(tester, 'portion-dialog-name', 'Becher');
      await tippe(tester, 'portion-dialog-sichern');

      // Die Packung löschen.
      await tippe(tester, 'anlegen-portion-1');
      await tippe(tester, 'portion-dialog-loeschen');

      expect(schluessel('anlegen-portion-1'), findsNothing);

      await tippe(tester, 'anlegen-sichern');
      final inTabelle = await portionenVon(b.container, neu!);
      expect(inTabelle.map((p) => (p.name, p.mengeG)), [('Becher', 60.0)]);
    });
  });
}
