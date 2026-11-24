import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/design/zahlen.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/koerper/umfang_detail_view.dart';

import '../design/support.dart' show textOf;
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für die **Seitendifferenz-Zeile** des Verlaufsschirms je Maß
/// (#493 unter #88, Scheibe 3) — die Zahl, die man sonst im Kopf ausrechnet.
///
/// Neue Testdatei neben `umfang_detail_test.dart`, das vom Test-Agenten
/// stammt und nicht verändert wird. Diese Fälle entstanden **vor** der
/// Implementierung und wurden rot gesehen; ab dem Commit bewacht sie der
/// Pre-Commit-Haken (`CLAUDE.md`, „Widget-Tests für Zustände und Übergänge:
/// ein Agent genügt").
///
/// ## Woher die Anforderung kommt
///
/// Issue #493: Der Schirm bezieht die Zahl aus dem Kern
/// (`UmfangsFortschritt.seitendifferenz`), `app/lib/` enthält keine Rechnung
/// dafür. Entwurf `docs/screens/screens/umfang-detail.js` (Zeile
/// „Seitendifferenz" in der Karte „Veränderung"); Totzone und Richtung legt
/// `Packages/trainings_core/test/umfangs_seitendifferenz_test.dart` fest.
///
/// ## Die Zustände, auf die es ankommt
///
/// 1. **Beide Seiten haben Werte, außerhalb der Totzone:** Die Zeile zeigt
///    den Betrag aus dem Kern und eine Richtung. Vom anderen Maß aus gesehen
///    dreht sich die Richtung — derselbe Betrag, eine andere Auskunft.
/// 2. **Innerhalb der Totzone:** „gleich", nicht eine Richtung, die die
///    Messgenauigkeit nicht trägt.
/// 3. **Die Gegenseite hat keinen Wert:** `–/–` in derselben Geometrie — die
///    Zeile verschwindet nicht (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat
///    genau eine Form").
/// 4. **Das Maß hat keine Gegenseite** (Brust, Schultern, Taille, Hals,
///    Hüfte): Die Zeile gibt es gar nicht erst. Das ist keine fehlende
///    Datenlage, sondern ein Maß ohne Gegenseite (#493) — eine Zeile, die
///    sich nie füllen kann, wäre eine Funktion, die es nicht gibt.
///
/// ## Der Schlüssel, auf den sich diese Datei festlegt
///
/// `umfang-detail-seite` — die ganze Zeile, nicht nur ihr Wert (die Zeile
/// färbt sich nicht ein; `umfang-detail-trend` sitzt aus einem Farb-Grund
/// auf dem Wert allein).
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag ist ausgedacht und liegt im Jahr 2099. Keine
/// Zahl stammt aus `docs/screens/` und keine aus `Exporte/`.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);
  const tag1 = '2099-01-05';
  const tag2 = '2099-02-16';

  final seite = find.byKey(const Key('umfang-detail-seite'));
  final trend = find.byKey(const Key('umfang-detail-trend'));
  final werte = find.byKey(const Key('umfang-detail-werte'));

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> lege(String tag, Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: tag, werte: werte);

  /// Die Messungen, wie der Kern sie sieht — für Erwartungswerte, die
  /// gerechnet und nicht abgeschrieben sind.
  Future<List<Umfangsmessung>> ausDerAblage() =>
      UmfaengeRepository(db, uhr: () => jetzt).messungen();

  /// Der Schirm **eines** Maßes, direkt gepumpt. Der Weg über die Übersicht
  /// ist in `umfang_detail_test.dart` bewiesen; hier geht es um eine Zeile.
  Future<void> zeige(WidgetTester tester, Umfang mass) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: UmfangDetailSeite(mass: mass)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Eine Zahl, wie sie auf dem Schirm steht — ohne Vorzeichen, damit kein
  /// Fall an „−" gegen „-" hängt.
  String zahl(double wert) => formatNumber(wert.abs(), nachkommastellen: 1);

  String zeilentext(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: seite, matching: find.byType(Text), matchRoot: true),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  group('Beide Seiten haben Werte', () {
    testWidgets('die Zeile zeigt den Betrag aus dem Kern, nicht –/–', (
      tester,
    ) async {
      await lege(tag1, {
        Umfang.oberarmRechtsAngespannt: 36.4,
        Umfang.oberarmLinksAngespannt: 35.9,
      });
      await lege(tag2, {
        Umfang.oberarmRechtsAngespannt: 38.6,
        Umfang.oberarmLinksAngespannt: 37.8,
      });

      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        await ausDerAblage(),
      )!;
      expect(
        differenz.vergleich,
        SeitenVergleich.diesesGroesser,
        reason: 'Vorbedingung: 38,6 gegen 37,8 liegt außerhalb der Totzone',
      );

      await zeige(tester, Umfang.oberarmRechtsAngespannt);

      expect(
        seite,
        findsOneWidget,
        reason:
            'Die Seitendifferenz steht als Zeile da (#493, Entwurf '
            '`umfang-detail.js`, Karte „Veränderung")',
      );
      final text = zeilentext(tester);
      expect(
        text,
        contains(zahl(differenz.delta)),
        reason:
            'Die Zahl kommt aus `UmfangsFortschritt.seitendifferenz`, nicht '
            'aus einer zweiten Rechnung in `app/lib/` (#493)',
      );
      expect(
        text,
        isNot(contains(ohneWert)),
        reason: 'Beide Seiten haben Werte — hier fehlt nichts',
      );
      expect(
        text.toLowerCase(),
        isNot(contains('gleich')),
        reason: '0,8 cm sind keine Totzone — die Seiten sind nicht gleich',
      );
    });

    testWidgets('vom anderen Maß aus gesehen dreht sich die Richtung', (
      tester,
    ) async {
      // Der Schirm zeigt immer ein Maß: Dieselbe Datenlage heißt auf dem
      // rechten Schirm „dieses Maß ist größer" und auf dem linken das
      // Gegenteil — derselbe Betrag, eine andere Auskunft.
      await lege(tag2, {
        Umfang.oberarmRechtsAngespannt: 38.6,
        Umfang.oberarmLinksAngespannt: 37.8,
      });

      await zeige(tester, Umfang.oberarmRechtsAngespannt);
      final rechts = zeilentext(tester);

      await zeige(tester, Umfang.oberarmLinksAngespannt);
      final links = zeilentext(tester);

      expect(
        rechts,
        contains(zahl(0.8)),
        reason: 'Vorbedingung: Der Betrag steht auf dem rechten Schirm',
      );
      expect(
        links,
        contains(zahl(0.8)),
        reason: 'Derselbe Betrag auf dem linken Schirm — das Maß dreht nur '
            'die Richtung, nicht die Zahl',
      );
      expect(
        links,
        isNot(rechts),
        reason:
            'Die Richtung gehört zur Auskunft: „dieses Maß ist größer" und '
            '„die Gegenseite ist größer" sind zwei verschiedene Sätze '
            '(`SeitenVergleich`)',
      );
    });
  });

  group('Innerhalb der Totzone', () {
    testWidgets('heißt es „gleich", nicht eine Richtung', (tester) async {
      await lege(tag2, {Umfang.wadeRechts: 38.0, Umfang.wadeLinks: 37.9});

      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.wadeRechts,
        await ausDerAblage(),
      )!;
      expect(
        differenz.vergleich,
        SeitenVergleich.gleich,
        reason: 'Vorbedingung: 0,1 cm liegen in der Totzone von 0,2 cm',
      );

      await zeige(tester, Umfang.wadeRechts);

      expect(seite, findsOneWidget);
      expect(
        zeilentext(tester).toLowerCase(),
        contains('gleich'),
        reason:
            'Unter der Totzone trägt die Messgenauigkeit keine Richtung — '
            '„beide Seiten gleich" ist die Auskunft (#493, Swift-Vorlage '
            '`differenceText`)',
      );
    });
  });

  group('Die Gegenseite hat keinen Wert', () {
    testWidgets('die Zeile bleibt stehen und sagt –/–', (tester) async {
      // Der rechte Oberschenkel ist gemessen, der linke nie. Das ist eine
      // Datenlage, keine fehlende Funktion — die Zeile verschwindet nicht
      // (`CLAUDE.md`, „Eine Anzeige, die es gibt, hat genau eine Form").
      await lege(tag2, {Umfang.oberschenkelRechts: 58.6});

      await zeige(tester, Umfang.oberschenkelRechts);

      expect(
        seite,
        findsOneWidget,
        reason:
            'Die Zeile steht ungefüllt da, statt zu fehlen — sonst wüchse '
            'der Schirm, sobald die linke Seite zum ersten Mal gemessen wird',
      );
      expect(
        zeilentext(tester),
        contains(ohneWert),
        reason:
            '`UmfangsFortschritt.seitendifferenz` gibt ohne Wert einer Seite '
            '`null`, und `null` heißt `–/–`, nie `0` (`CLAUDE.md`)',
      );
    });
  });

  group('Ein Maß ohne Gegenseite', () {
    testWidgets('hat die Zeile gar nicht — und sonst fehlt nichts', (
      tester,
    ) async {
      // Brust, Schultern, Taille, Hals und Hüfte gibt es nur einmal am
      // Körper. Eine Zeile, die sich nie füllen kann, wäre keine leere
      // Anzeige, sondern eine Funktion, die es nicht gibt (#493).
      await lege(tag1, {Umfang.brust: 101.0});
      await lege(tag2, {Umfang.brust: 103.5});

      await zeige(tester, Umfang.brust);

      expect(
        seite,
        findsNothing,
        reason:
            '„Dieses Maß gibt es einmal" ist keine Datenlage — die Frage '
            'nach der Seitendifferenz stellt sich nicht (`Umfang.partner`)',
      );
      for (final teil in [trend, werte]) {
        expect(
          teil,
          findsOneWidget,
          reason:
              'Alles übrige steht genauso da wie bei einem Maß mit Partner '
              '(`umfang_detail_test.dart`, „sieht sonst nicht anders aus")',
        );
      }
    });
  });
}
