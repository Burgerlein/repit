import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/wasser_repository.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_types.dart';

import 'health_schreiben_attrappe.dart';
import 'tag_huelle.dart';

/// Widget-Tests für **#360 — Wasser: Gläser ändern und löschen**.
///
/// Nur Zustände und Übergänge, nicht Layout und Beschriftung (`CLAUDE.md`,
/// „Tests"). Ein Agent schreibt Tests und Implementierung; die Tests
/// entstehen zuerst, werden rot gesehen und committet, bevor gebaut wird.
/// Ab dann bewacht sie `.githooks/pre-commit`.
///
/// Grundlage: `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`,
/// Abschnitt „Gläser ändern und löschen (#360)", und der Entwurf
/// `docs/screens/screens/wasser.js` (Zustände `liste`, `wischen`,
/// `aendern`, `menge`, `leer`), von Tim am 05.11.2026 freigegeben.
///
/// ## Festgelegte Schlüssel — Entscheidung des Test-Agenten, nicht von Tim
///
/// - `Key('wasser-zeile')` — die Wasserzeile auf dem Tag-Schirm, die Tür.
/// - `Key('wasser-blatt')` — das Blatt.
/// - `Key('wasser-blatt-fertig')` — „Fertig", schließt das Blatt.
/// - `Key('wasser-glas-<id>')` — eine Glaszeile, wischbar und tippbar.
/// - `Key('wasser-kein-glas')` — „Noch kein Glas", der Leerzustand.
/// - `Key('wasser-aus-essen')` — „Aus Lebensmitteln".
/// - `Key('wasser-menge-feld')`, `Key('wasser-menge-eintragen')` — das Feld
///   „Menge …" und sein Knopf (ein `CupertinoButton`; grau heißt
///   `onPressed == null`).
/// - `Key('wasser-blatt-plus-250')`, `Key('wasser-blatt-plus-500')` — die
///   schnellen Knöpfe im Blatt. Eigene Schlüssel, weil die auf dem Schirm
///   darunter weiter im Baum stehen.
/// - `Key('wasser-aendern')` — „Glas ändern" im selben Blatt, darin
///   `Key('wasser-aendern-feld')`, `Key('wasser-aendern-uhrzeit')`,
///   `Key('wasser-aendern-abbrechen')`, `Key('wasser-aendern-sichern')`
///   und `Key('wasser-aendern-loeschen')`.
///
/// Alle Zahlen und Kennungen erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, UTC+2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  // 07:30 und 11:15 Berliner Zeit.
  final frueh = DateTime.utc(2026, 7, 14, 5, 30);
  final mittags = DateTime.utc(2026, 7, 14, 9, 15);
  // Gestern, 20:00 Berliner Zeit.
  final gesternAbend = DateTime.utc(2026, 7, 13, 18);

  const kopieFrueh = 'C0FFEE00-0000-0000-0000-0000000000AA';

  /// Legt ein Glas direkt in die Datenbank, vor dem ersten Bild.
  Future<int> glas(
    TagHuelle h, {
    required String tag,
    required DateTime zeitpunkt,
    required double ml,
    String? kopie,
  }) => WasserRepository(h.db).trageEin(
    WasserEintrag(
      tagesSchluessel: tag,
      zeitpunkt: zeitpunkt,
      mengeMl: ml,
      healthUuid: kopie,
      healthStand: kopie == null ? HealthStand.offen : HealthStand.geschrieben,
    ),
  );

  Future<List<WasserEintrag>> gespeichert(TagHuelle h, String tag) =>
      WasserRepository(h.db).wasserAmTag(tag);

  /// Hülle mit steuerbarer Health-Quelle. [vorher] füllt die Datenbank,
  /// bevor der Schirm das erste Mal gebaut wird.
  Future<(TagHuelle, SchreibAttrappe)> starte(
    WidgetTester tester, {
    Future<void> Function(TagHuelle h)? vorher,
  }) async {
    final quelle = SchreibAttrappe();
    final h = tagHuelle(jetzt: jetzt, quelle: quelle);
    if (vorher != null) await vorher(h);
    await zeigeTag(tester, h.app);
    return (h, quelle);
  }

  Future<void> tippe(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> oeffneBlatt(WidgetTester tester) =>
      tippe(tester, const Key('wasser-zeile'));

  Finder imBlatt(Finder finder) =>
      find.descendant(of: find.byKey(const Key('wasser-blatt')), matching: finder);

  String blatt(WidgetTester tester) =>
      texteUnter(tester, const Key('wasser-blatt'));

  String wasserzeile(WidgetTester tester) =>
      texteUnter(tester, const Key('ernaehrung-wasser')).toLowerCase();

  CupertinoButton knopf(WidgetTester tester, Key key) =>
      tester.widget<CupertinoButton>(find.byKey(key));

  Future<void> wische(WidgetTester tester, int id) async {
    await tester.drag(find.byKey(Key('wasser-glas-$id')), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Die Wasserzeile ist eine Tür (#360)', () {
    testWidgets('sie öffnet das Blatt', (tester) async {
      await starte(
        tester,
        vorher: (h) => glas(h, tag: heute, zeitpunkt: frueh, ml: 300),
      );
      expect(find.byKey(const Key('wasser-blatt')), findsNothing);

      await oeffneBlatt(tester);

      expect(find.byKey(const Key('wasser-blatt')), findsOneWidget);
    });

    testWidgets('auch ohne ein einziges Glas — die Tür hängt nicht am Wert', (
      tester,
    ) async {
      await starte(tester);

      await oeffneBlatt(tester);

      expect(find.byKey(const Key('wasser-blatt')), findsOneWidget);
    });

    testWidgets('„Fertig" schließt das Blatt wieder', (tester) async {
      await starte(tester);
      await oeffneBlatt(tester);

      await tippe(tester, const Key('wasser-blatt-fertig'));

      expect(find.byKey(const Key('wasser-blatt')), findsNothing);
    });

    testWidgets('die Knöpfe + 250 / + 500 bleiben auf dem Schirm und tragen '
        'ein, ohne das Blatt zu öffnen', (tester) async {
      final (h, _) = await starte(tester);

      await tippe(tester, const Key('wasser-plus-250'));

      expect(find.byKey(const Key('wasser-blatt')), findsNothing);
      expect((await gespeichert(h, heute)).map((e) => e.mengeMl), [250]);
    });
  });

  group('Die Gläser des offenen Tages (#360)', () {
    testWidgets('heute: jedes Glas mit Uhrzeit und Menge, nach Zeit '
        'aufsteigend', (tester) async {
      late int idFrueh, idMittags;
      await starte(
        tester,
        vorher: (h) async {
          // Absichtlich in umgekehrter Reihenfolge eingetragen.
          idMittags = await glas(h, tag: heute, zeitpunkt: mittags, ml: 500);
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );

      await oeffneBlatt(tester);

      final zeileFrueh = find.byKey(Key('wasser-glas-$idFrueh'));
      final zeileMittags = find.byKey(Key('wasser-glas-$idMittags'));
      expect(imBlatt(zeileFrueh), findsOneWidget);
      expect(imBlatt(zeileMittags), findsOneWidget);
      expect(
        tester.getRect(zeileFrueh).top,
        lessThan(tester.getRect(zeileMittags).top),
        reason: '07:30 steht über 11:15',
      );
      final frueheZeile = texteUnter(tester, Key('wasser-glas-$idFrueh'));
      expect(frueheZeile, contains('07:30'), reason: 'Berliner Uhrzeit');
      expect(frueheZeile, contains('300'));
      expect(texteUnter(tester, Key('wasser-glas-$idMittags')), contains('11:15'));
      expect(find.byKey(const Key('wasser-kein-glas')), findsNothing);
    });

    testWidgets('auf einem geblätterten Tag die Gläser dieses Tages, nicht '
        'die von heute', (tester) async {
      late int idHeute, idGestern;
      await starte(
        tester,
        vorher: (h) async {
          idHeute = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
          idGestern = await glas(
            h,
            tag: gestern,
            zeitpunkt: gesternAbend,
            ml: 500,
          );
        },
      );
      await tippe(tester, const Key('ernaehrung-zurueck'));

      await oeffneBlatt(tester);

      expect(imBlatt(find.byKey(Key('wasser-glas-$idGestern'))), findsOneWidget);
      expect(find.byKey(Key('wasser-glas-$idHeute')), findsNothing);
      expect(texteUnter(tester, Key('wasser-glas-$idGestern')), contains('20:00'));
    });

    testWidgets('„Aus Lebensmitteln" zeigt das Wasser gebuchter Lebensmittel '
        'und ist keine Tür', (tester) async {
      final (h, _) = await starte(
        tester,
        vorher: (h) async {
          await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
          await ErnaehrungRepository(h.db).buche(
            Eintrag(
              tagesSchluessel: heute,
              mahlzeit: Mahlzeit.mittag,
              zeitpunkt: mittags,
              name: 'Prüfsuppe',
              mengeG: 250,
              naehrwerte: const Naehrwerte(kcal: 100, wasserMl: 200),
            ),
          );
        },
      );
      await h.container.read(eigeneEintraegeProvider(heute).notifier).neuLesen();
      await tester.pumpAndSettle();

      await oeffneBlatt(tester);

      final ausEssen = texteUnter(tester, const Key('wasser-aus-essen'));
      expect(ausEssen, contains('0,2'));
      expect(ausEssen, isNot(contains(ohneWertZeichen)));
      final text = find
          .descendant(
            of: find.byKey(const Key('wasser-aus-essen')),
            matching: find.byType(RichText),
          )
          .evaluate()
          .first;
      expect(
        tippbar(text),
        isFalse,
        reason: 'ändern lässt sich das nur am Eintrag in der Mahlzeit',
      );
    });
  });

  group('Wischen löscht (#360)', () {
    testWidgets('das Glas ist weg, in der Datenbank und im Blatt', (
      tester,
    ) async {
      late int idFrueh;
      final (h, _) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
          await glas(h, tag: heute, zeitpunkt: mittags, ml: 500);
        },
      );
      await oeffneBlatt(tester);

      await wische(tester, idFrueh);

      expect((await gespeichert(h, heute)).map((e) => e.mengeMl), [500]);
      expect(find.byKey(Key('wasser-glas-$idFrueh')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Kopie in Apple Health wird mit gelöscht', (tester) async {
      late int idFrueh;
      final (_, quelle) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(
            h,
            tag: heute,
            zeitpunkt: frueh,
            ml: 300,
            kopie: kopieFrueh,
          );
        },
      );
      await oeffneBlatt(tester);

      await wische(tester, idFrueh);

      expect(quelle.loeschVersuche, [kopieFrueh]);
    });

    testWidgets('scheitert das Löschen in Health, ist das Glas trotzdem weg', (
      tester,
    ) async {
      late int idFrueh;
      final (h, quelle) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(
            h,
            tag: heute,
            zeitpunkt: frueh,
            ml: 300,
            kopie: kopieFrueh,
          );
        },
      );
      quelle.loeschFehler = StateError('Probe in Health schon gelöscht');
      await oeffneBlatt(tester);

      await wische(tester, idFrueh);

      expect(await gespeichert(h, heute), isEmpty);
      expect(find.byKey(Key('wasser-glas-$idFrueh')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nach dem letzten Glas steht „Noch kein Glas" da — keine '
        'leere Karte', (tester) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );
      await oeffneBlatt(tester);

      await wische(tester, idFrueh);

      expect(imBlatt(find.byKey(const Key('wasser-kein-glas'))), findsOneWidget);
    });
  });

  group('Tippen ändert die Menge (#360)', () {
    testWidgets('Tippen öffnet „Glas ändern" mit der bisherigen Menge im '
        'Feld', (tester) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );
      await oeffneBlatt(tester);

      await tippe(tester, Key('wasser-glas-$idFrueh'));

      expect(imBlatt(find.byKey(const Key('wasser-aendern'))), findsOneWidget);
      final feld = tester.widget<CupertinoTextField>(
        find.byKey(const Key('wasser-aendern-feld')),
      );
      expect(feld.controller?.text, '300');
    });

    testWidgets('Sichern ändert dasselbe Glas, ersetzt die Kopie in Health '
        'und führt zurück in die Liste', (tester) async {
      late int idFrueh;
      final (h, quelle) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(
            h,
            tag: heute,
            zeitpunkt: frueh,
            ml: 300,
            kopie: kopieFrueh,
          );
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      await tester.enterText(find.byKey(const Key('wasser-aendern-feld')), '330');
      await tester.pump();
      await tippe(tester, const Key('wasser-aendern-sichern'));

      final neu = (await gespeichert(h, heute)).single;
      expect(neu.id, idFrueh, reason: 'dasselbe Glas, kein zweites');
      expect(neu.mengeMl, 330);
      expect(neu.zeitpunkt, frueh, reason: 'die Uhrzeit bleibt');
      expect(quelle.loeschVersuche, contains(kopieFrueh));
      expect(quelle.geschrieben.last.werte.wasserMl, 330);

      expect(find.byKey(const Key('wasser-aendern')), findsNothing);
      expect(imBlatt(find.byKey(Key('wasser-glas-$idFrueh'))), findsOneWidget);
      expect(texteUnter(tester, Key('wasser-glas-$idFrueh')), contains('330'));
    });

    testWidgets('die Uhrzeit steht als Angabe da, nicht als Feld', (
      tester,
    ) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      expect(
        texteUnter(tester, const Key('wasser-aendern-uhrzeit')),
        contains('07:30'),
      );
      final aendern = find.byKey(const Key('wasser-aendern'));
      expect(
        find.descendant(of: aendern, matching: find.byType(CupertinoTextField)),
        findsOneWidget,
        reason: 'nur die Menge ist ein Feld',
      );
      expect(
        find.descendant(of: aendern, matching: find.byType(CupertinoDatePicker)),
        findsNothing,
      );
    });

    testWidgets('Abbrechen lässt das Glas, wie es war', (tester) async {
      late int idFrueh;
      final (h, quelle) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      await tester.enterText(find.byKey(const Key('wasser-aendern-feld')), '999');
      await tester.pump();
      await tippe(tester, const Key('wasser-aendern-abbrechen'));

      expect((await gespeichert(h, heute)).single.mengeMl, 300);
      expect(quelle.geschrieben, isEmpty);
      expect(find.byKey(const Key('wasser-aendern')), findsNothing);
      expect(imBlatt(find.byKey(Key('wasser-glas-$idFrueh'))), findsOneWidget);
    });

    testWidgets('ohne gültige Menge ist „Sichern" grau', (tester) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      for (final eingabe in const ['', '0', 'abc', '50000']) {
        await tester.enterText(
          find.byKey(const Key('wasser-aendern-feld')),
          eingabe,
        );
        await tester.pump();
        expect(
          knopf(tester, const Key('wasser-aendern-sichern')).onPressed,
          isNull,
          reason: '„$eingabe" ist keine Menge',
        );
      }
    });

    testWidgets('„Glas löschen" löscht das Glas samt Kopie und führt zurück', (
      tester,
    ) async {
      late int idFrueh;
      final (h, quelle) = await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(
            h,
            tag: heute,
            zeitpunkt: frueh,
            ml: 300,
            kopie: kopieFrueh,
          );
          await glas(h, tag: heute, zeitpunkt: mittags, ml: 500);
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      await tippe(tester, const Key('wasser-aendern-loeschen'));

      expect((await gespeichert(h, heute)).map((e) => e.mengeMl), [500]);
      expect(quelle.loeschVersuche, [kopieFrueh]);
      expect(find.byKey(const Key('wasser-aendern')), findsNothing);
      expect(find.byKey(Key('wasser-glas-$idFrueh')), findsNothing);
      expect(find.byKey(const Key('wasser-blatt')), findsOneWidget);
    });
  });

  group('„Menge …" trägt eine freie Menge ein (#360)', () {
    testWidgets('ohne Eingabe ist „Eintragen" grau — und steht trotzdem da', (
      tester,
    ) async {
      await starte(tester);
      await oeffneBlatt(tester);

      expect(imBlatt(find.byKey(const Key('wasser-menge-feld'))), findsOneWidget);
      expect(
        knopf(tester, const Key('wasser-menge-eintragen')).onPressed,
        isNull,
      );

      for (final eingabe in const ['0', 'abc', '50000']) {
        await tester.enterText(find.byKey(const Key('wasser-menge-feld')), eingabe);
        await tester.pump();
        expect(
          knopf(tester, const Key('wasser-menge-eintragen')).onPressed,
          isNull,
          reason: '„$eingabe" ist keine Menge',
        );
      }
    });

    testWidgets('330 getippt: „Eintragen" bucht 330 ml auf heute, jetzt, und '
        'leert das Feld', (tester) async {
      final (h, quelle) = await starte(tester);
      await oeffneBlatt(tester);

      await tester.enterText(find.byKey(const Key('wasser-menge-feld')), '330');
      await tester.pump();
      expect(
        knopf(tester, const Key('wasser-menge-eintragen')).onPressed,
        isNotNull,
      );
      await tippe(tester, const Key('wasser-menge-eintragen'));

      final e = (await gespeichert(h, heute)).single;
      expect(e.mengeMl, 330);
      expect(e.zeitpunkt, jetzt);
      expect(quelle.geschrieben.single.werte.wasserMl, 330);
      final feld = tester.widget<CupertinoTextField>(
        find.byKey(const Key('wasser-menge-feld')),
      );
      expect(feld.controller?.text, isEmpty);
      expect(imBlatt(find.byKey(Key('wasser-glas-${e.id}'))), findsOneWidget);
      expect(find.byKey(const Key('wasser-blatt')), findsOneWidget);
    });

    testWidgets('auf einem geblätterten Tag landet die Menge auf diesem Tag', (
      tester,
    ) async {
      final (h, _) = await starte(tester);
      await tippe(tester, const Key('ernaehrung-zurueck'));
      await oeffneBlatt(tester);

      await tester.enterText(find.byKey(const Key('wasser-menge-feld')), '330');
      await tester.pump();
      await tippe(tester, const Key('wasser-menge-eintragen'));

      expect(await gespeichert(h, heute), isEmpty);
      final e = (await gespeichert(h, gestern)).single;
      expect(e.mengeMl, 330);
      expect(BerlinCalendar.dayKey(e.zeitpunkt), gestern);
    });

    testWidgets('die schnellen Knöpfe im Blatt tragen ebenfalls ein', (
      tester,
    ) async {
      final (h, _) = await starte(tester);
      await oeffneBlatt(tester);

      await tippe(tester, const Key('wasser-blatt-plus-250'));
      await tippe(tester, const Key('wasser-blatt-plus-500'));

      expect(
        (await gespeichert(h, heute)).map((e) => e.mengeMl).toList()..sort(),
        [250, 500],
      );
      expect(find.byKey(const Key('wasser-kein-glas')), findsNothing);
    });
  });

  group('Leer hat dieselbe Form (#360)', () {
    testWidgets('ohne Glas: „Noch kein Glas" und „Aus Lebensmitteln" sagen '
        '–/–, Feld und Knöpfe stehen da', (tester) async {
      await starte(tester);
      await oeffneBlatt(tester);

      expect(imBlatt(find.byKey(const Key('wasser-kein-glas'))), findsOneWidget);
      expect(
        texteUnter(tester, const Key('wasser-kein-glas')),
        contains(ohneWertZeichen),
      );
      expect(imBlatt(find.byKey(const Key('wasser-aus-essen'))), findsOneWidget);
      expect(
        texteUnter(tester, const Key('wasser-aus-essen')),
        contains(ohneWertZeichen),
      );
      // Nicht `contains('0 ml')`: Das stünde auch in „+ 250 ml".
      expect(
        blatt(tester),
        isNot(matches(RegExp(r'(^|\s)0 ml|0,0 l'))),
        reason: '–/–, nicht 0',
      );
      expect(imBlatt(find.byKey(const Key('wasser-menge-feld'))), findsOneWidget);
      expect(
        imBlatt(find.byKey(const Key('wasser-blatt-plus-250'))),
        findsOneWidget,
      );
    });

    testWidgets('das erste Glas tritt an die Stelle von „Noch kein Glas" — '
        'gleich hoch, und das Blatt springt nicht', (tester) async {
      final (h, _) = await starte(tester);
      await oeffneBlatt(tester);
      final blattVorher = tester.getRect(find.byKey(const Key('wasser-blatt')));
      final leer = tester.getRect(find.byKey(const Key('wasser-kein-glas')));
      final ausEssenVorher = tester.getRect(
        find.byKey(const Key('wasser-aus-essen')),
      );

      await tippe(tester, const Key('wasser-blatt-plus-250'));

      final id = (await gespeichert(h, heute)).single.id;
      final zeile = tester.getRect(find.byKey(Key('wasser-glas-$id')));
      expect(zeile.height, leer.height);
      expect(zeile.top, leer.top);
      expect(
        tester.getRect(find.byKey(const Key('wasser-blatt'))),
        blattVorher,
        reason: 'das Blatt hat eine feste Höhe',
      );
      expect(
        tester.getRect(find.byKey(const Key('wasser-aus-essen'))),
        ausEssenVorher,
        reason: 'darunter rutscht nichts, solange ein Glas dasteht',
      );
    });

    testWidgets('der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
    ) async {
      await starte(tester);
      await oeffneBlatt(tester);

      final text = await vorlesetext(tester, const Key('wasser-kein-glas'));
      expect(text, isNot(contains(ohneWertZeichen)));
      expect(text.toLowerCase(), contains('kein glas'));
    });
  });

  group('Die Summe auf dem Tag-Schirm folgt ohne Neustart (#360)', () {
    testWidgets('nach dem Wischen, noch bei offenem Blatt und danach', (
      tester,
    ) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
          await glas(h, tag: heute, zeitpunkt: mittags, ml: 500);
        },
      );
      expect(wasserzeile(tester), contains('0,8'));
      await oeffneBlatt(tester);

      await wische(tester, idFrueh);
      expect(wasserzeile(tester), contains('0,5'));

      await tippe(tester, const Key('wasser-blatt-fertig'));
      expect(wasserzeile(tester), contains('0,5'));
    });

    testWidgets('nach dem Ändern', (tester) async {
      late int idFrueh;
      await starte(
        tester,
        vorher: (h) async {
          idFrueh = await glas(h, tag: heute, zeitpunkt: frueh, ml: 300);
          await glas(h, tag: heute, zeitpunkt: mittags, ml: 500);
        },
      );
      await oeffneBlatt(tester);
      await tippe(tester, Key('wasser-glas-$idFrueh'));

      await tester.enterText(find.byKey(const Key('wasser-aendern-feld')), '600');
      await tester.pump();
      await tippe(tester, const Key('wasser-aendern-sichern'));

      expect(wasserzeile(tester), contains('1,1'));
    });

    testWidgets('nach „Menge …"', (tester) async {
      await starte(tester);
      await oeffneBlatt(tester);

      await tester.enterText(find.byKey(const Key('wasser-menge-feld')), '700');
      await tester.pump();
      await tippe(tester, const Key('wasser-menge-eintragen'));

      expect(wasserzeile(tester), contains('0,7'));
    });
  });
}

/// `–/–` — wörtlich, nicht über die Konstante der App: Der Test prüft,
/// was auf dem Schirm steht.
const ohneWertZeichen = '–/–';
