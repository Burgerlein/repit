import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/health/health_provider.dart';
import 'package:repit/koerper/umfang_detail_view.dart';

import '../design/support.dart' show textOf;
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den **Wortlaut der drei Auskünfte** der
/// Seitendifferenz-Zeile (#493 unter #88) — Nachtrag zum Review vom
/// 17.11.2026.
///
/// Neue Testdatei neben `umfang_seitendifferenz_test.dart` (committet,
/// wird nicht verändert). Das Review fand zwei Löcher:
///
/// 1. **Der Rundungswiderspruch.** 29,49 − 29,3 ist 0,19 cm und liegt in
///    der Totzone; gerundet auf eine Nachkommastelle sind es „0,2 cm" —
///    dieselbe Anzeige wie eine **echte** Differenz von 0,2 cm, die eine
///    Richtung bekommt. Der Kern-Test warnt genau davor („Wer vorher auf
///    eine Nachkommastelle rundet, macht daraus 0,2 und behauptet eine
///    Differenz"). In der Totzone darf deshalb kein auf 0,2 gerundeter
///    Betrag stehen — dort steht „unter 0,2 cm".
/// 2. **Kein Fall verankerte die Kennzeichen.** Geprüft war nur `–/–`;
///    „es fehlt eine Seite" und der gleich-Wortlaut hingen in der Luft.
///
/// Diese Fälle entstanden **vor** dem Fix; der gleich-Fall wurde rot
/// gesehen (die übrigen verankern bereits Gebautes als Wächter). Ab dem
/// Commit bewacht sie der Pre-Commit-Haken.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag ist ausgedacht und liegt im Jahr 2099.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);
  const tag = '2099-02-16';

  final seite = find.byKey(const Key('umfang-detail-seite'));

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> lege(Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: tag, werte: werte);

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

  /// Kleingeschrieben: Das Kennzeichen wird in Kapitälchen gesetzt
  /// (`MessZeile`), und geprüft wird die Auskunft, nicht die Schreibung.
  String zeilentext(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(of: seite, matching: find.byType(Text), matchRoot: true),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();

  testWidgets('die Richtung steht als Auskunft an der Zeile — auf beiden '
      'Schirmen die ihre', (tester) async {
    await lege({
      Umfang.oberarmRechtsAngespannt: 38.6,
      Umfang.oberarmLinksAngespannt: 37.8,
    });

    await zeige(tester, Umfang.oberarmRechtsAngespannt);
    expect(
      zeilentext(tester),
      contains('dieses maß ist größer'),
      reason:
          'Der Schirm zeigt immer ein Maß — die Richtung heißt „dieses Maß", '
          'nicht „rechts" (`SeitenVergleich.diesesGroesser`, #493)',
    );

    await zeige(tester, Umfang.oberarmLinksAngespannt);
    expect(
      zeilentext(tester),
      contains('die gegenseite ist größer'),
      reason:
          'Dieselbe Datenlage, vom kleineren Maß aus gesehen '
          '(`SeitenVergleich.partnerGroesser`)',
    );
  });

  testWidgets('0,19 cm heißen „unter 0,2 cm", nicht „0,2 cm" mit Richtung', (
    tester,
  ) async {
    // Der Rundungswiderspruch: 29,49 − 29,3 = 0,19 liegt in der Totzone,
    // rundet aber auf „0,2 cm" — dieselbe Zahl wie die echte Differenz
    // 38,2 − 38,0, die eine Richtung bekommt. Beide Anzeigen müssen sich
    // unterscheiden, sonst behauptet die Totzonen-Zeile eine Differenz,
    // die die Messgenauigkeit nicht trägt (Kern-Test, „0,19 cm sind noch
    // gleich").
    await lege({
      Umfang.oberarmRechtsAngespannt: 29.49,
      Umfang.oberarmLinksAngespannt: 29.3,
      Umfang.wadeRechts: 38.2,
      Umfang.wadeLinks: 38.0,
    });

    await zeige(tester, Umfang.oberarmRechtsAngespannt);
    final gleich = zeilentext(tester);
    expect(
      gleich,
      contains('beide seiten gleich'),
      reason: '0,19 cm liegen in der Totzone — die Auskunft ist „gleich"',
    );
    expect(
      gleich,
      contains('unter 0,2 cm'),
      reason:
          'Statt des auf 0,2 gerundeten Betrags steht die ehrliche Grenze: '
          '„unter 0,2 cm" behauptet keine Differenz, die es nicht gibt',
    );
    expect(
      gleich,
      isNot(contains('größer')),
      reason: 'In der Totzone gibt es keine Richtung',
    );

    await zeige(tester, Umfang.wadeRechts);
    final echt = zeilentext(tester);
    expect(
      echt,
      contains('größer'),
      reason: 'Vorbedingung: 0,2 cm sind keine Totzone mehr (Kern-Test)',
    );
    expect(
      echt,
      isNot(gleich),
      reason:
          'Dieselben zwei Zehntel nach Rundung, zwei verschiedene Auskünfte '
          '— sonst wäre die Totzone der Anzeige nicht anzusehen',
    );
  });

  testWidgets('fehlt eine Seite, sagt die Zeile das — neben –/–', (
    tester,
  ) async {
    await lege({Umfang.oberschenkelRechts: 58.6});

    await zeige(tester, Umfang.oberschenkelRechts);

    final text = zeilentext(tester);
    expect(
      text,
      contains(ohneWert),
      reason: 'Ohne Wert einer Seite gibt es keine Differenz — `–/–`, nie 0',
    );
    expect(
      text,
      contains('es fehlt eine seite'),
      reason:
          '„Es fehlt eine Seite" ist eine andere Auskunft als „gleich" und '
          'eine andere als gar keine Zeile (Maß ohne Gegenseite) — der '
          'Entwurf nennt sie im Zustand `nie` wörtlich (`umfang-detail.js`)',
    );
  });
}
