import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_uebersicht.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für die **Übersicht** oben auf dem Ernährungs-Tag (#406) —
/// `lib/ernaehrung/ernaehrung_uebersicht.dart`, eingebaut in
/// `ErnaehrungView`.
///
/// Vorlage ist Tims YAZIO-Bild vom 07.11.2026 (gilt als freigegebener
/// Entwurf), gezeichnet in `docs/screens/screens/ernaehrung.js`,
/// `UEBERSICHT`, Zustände `tag`, `leer`, `laedt`, `kein-ziel` und `ueber`.
///
/// Ein Agent schreibt Test und Implementierung (`CLAUDE.md`: Widget-Tests
/// für Zustände und Übergänge) — deshalb steht diese Datei **vor** der
/// Implementierung, wird einmal rot gesehen und committet. Ab dann bewacht
/// sie der pre-commit-Haken.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// /// Der Bogen über 270°, Öffnung nach unten.
/// class UebersichtBogen extends StatelessWidget {
///   const UebersichtBogen({super.key, required this.anteil, this.ueber = false});
///   /// Gefüllter Anteil, 0 bis 1. `null` heißt ungefüllt — kein Ziel oder
///   /// noch nicht gelesen. **Nie** eine erfundene `0`.
///   final double? anteil;
///   /// Über dem Ziel: der Bogen ist voll und färbt sich um.
///   final bool ueber;
/// }
///
/// /// Ein Makrobalken der Übersicht: Name, Balken, „gegessen / Ziel g".
/// class MakroSaeule extends StatelessWidget {
///   final String label;
///   /// `null`, wenn es kein Ziel gibt oder noch gelesen wird.
///   final double? wert;
///   final double? ziel;
///   /// Beispieltext der grauen Form — gesetzt allein beim Laden.
///   final String? platzhalter;
/// }
/// ```
///
/// ## Die Schlüssel
///
/// - `Key('ernaehrung-uebersicht')` — die Karte
/// - `Key('ernaehrung-uebersicht-details')` — der Link „Details"
/// - `Key('ernaehrung-uebersicht-bogen')` — der [UebersichtBogen]
/// - `Key('ernaehrung-uebersicht-uebrig')` — Zahl und Beschriftung im
///   Bogen, mit dem Vorlesetext des Zustands
/// - `Key('ernaehrung-uebersicht-gegessen')` /
///   `Key('ernaehrung-uebersicht-verbrannt')` — links und rechts
/// - `Key('ernaehrung-uebersicht-kohlenhydrate' | '-eiweiss' | '-fett')` —
///   die drei [MakroSaeule]
///
/// ## Was hier geprüft wird
///
/// Zustände und Übergänge, nicht Layout und Beschriftung — mit den
/// Ausnahmen, die der Zustand selbst ist: „Übrig" gegen „über Ziel", und
/// `–/–` gegen eine Zahl. Dazu die Regel „Eine Anzeige, die es gibt, hat
/// genau eine Form" als Geometrie über **Zustände**: Die Karte steht in
/// jedem Zustand an derselben Stelle in derselben Größe.
///
/// **Verbrannt** ist nur der Trainingszuschlag (#389/#390, Vorgabe des
/// Koordinators). Den gibt es noch nicht; geprüft wird, dass dort `–/–`
/// steht und **nie** `0`, und dass „Übrig" ohne ihn rechnet.
///
/// Alle Zahlen erfunden — runde Hunderter, keine echten Werte.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) => DailyMetrics(
    tag: tag,
    activeKcal: 600,
    basalKcal: 1600,
    weightKg: 80,
  );

  Eintrag eintrag({double kcal = 1200}) => Eintrag(
    tagesSchluessel: heute,
    mahlzeit: Mahlzeit.mittag,
    zeitpunkt: DateTime.utc(2026, 7, 14, 10),
    name: 'Testgericht',
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: 100,
      kohlenhydrateG: 150,
      fettG: 40,
    ),
  );

  ({ProviderContainer container, AppCache db, Widget app}) harness({
    Messwert<List<FremdeMahlzeit>>? fremde,
    Messwert<List<DailyMetrics>>? tageswerte,
    Stammdaten stammdaten = vollstaendig,
  }) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_StilleQuelle()),
        stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>([
                  tageswert(gestern),
                  tageswert(heute),
                ], stand: jetzt, laeuft: false),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            fremde ??
                Bekannt<List<FremdeMahlzeit>>(
                  const [],
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      db: db,
      app: BehaelterImBaum(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: ErnaehrungView()),
        ),
      ),
    );
  }

  ({ProviderContainer container, AppCache db, Widget app}) laedt() => harness(
    fremde: const NochNie<List<FremdeMahlzeit>>(),
    tageswerte: const NochNie<List<DailyMetrics>>(),
  );

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String karte(WidgetTester tester) =>
      textUnter(tester, const Key('ernaehrung-uebersicht'));
  String uebrig(WidgetTester tester) =>
      textUnter(tester, const Key('ernaehrung-uebersicht-uebrig'));

  UebersichtBogen bogen(WidgetTester tester) => tester.widget<UebersichtBogen>(
    find.byKey(const Key('ernaehrung-uebersicht-bogen')),
  );

  MakroSaeule saeule(WidgetTester tester, String name) =>
      tester.widget<MakroSaeule>(
        find.byKey(Key('ernaehrung-uebersicht-$name')),
      );

  double ziel(({ProviderContainer container, AppCache db, Widget app}) h) =>
      h.container.read(ernaehrungsTagProvider(heute)).zielKcal!;

  // ───────────────────────────────────────────────────────────────────────

  group('Die Übersicht ersetzt die drei Ringe', () {
    testWidgets('die Karte steht da, Ringe gibt es auf dem Schirm keine', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-uebersicht')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ErnaehrungView),
          matching: find.byType(Ringe),
        ),
        findsNothing,
        reason: 'die Übersicht ersetzt die drei Ringe (Tim, 07.11.2026)',
      );
      for (final key in const [
        Key('ernaehrung-uebersicht-details'),
        Key('ernaehrung-uebersicht-bogen'),
        Key('ernaehrung-uebersicht-uebrig'),
        Key('ernaehrung-uebersicht-gegessen'),
        Key('ernaehrung-uebersicht-verbrannt'),
        Key('ernaehrung-uebersicht-kohlenhydrate'),
        Key('ernaehrung-uebersicht-eiweiss'),
        Key('ernaehrung-uebersicht-fett'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const Key('ernaehrung-uebersicht')),
            matching: find.byKey(key),
          ),
          findsOneWidget,
          reason: '$key gehört in die Karte',
        );
      }
    });

    testWidgets('die Balken stehen in der Reihenfolge des Bilds: '
        'Kohlenhydrate, Eiweiß, Fett', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag());
      await zeige(tester, h.app);

      final links = [
        for (final name in const ['kohlenhydrate', 'eiweiss', 'fett'])
          tester
              .getTopLeft(find.byKey(Key('ernaehrung-uebersicht-$name')))
              .dx,
      ];
      expect(links[0], lessThan(links[1]));
      expect(links[1], lessThan(links[2]));
    });
  });

  group('Die Rechnung „Übrig"', () {
    testWidgets('ist Ziel minus gegessen — Verbrannt gibt es noch nicht', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 1200));
      await zeige(tester, h.app);

      final z = ziel(h);
      expect(
        z,
        greaterThan(1200),
        reason: 'Vorbedingung: der Fall liegt unter dem Ziel',
      );
      expect(uebrig(tester), contains(formatNumber(z - 1200)));
      expect(uebrig(tester), contains('übrig'));
      expect(uebrig(tester), isNot(contains('über ziel')));
      expect(
        textUnter(tester, const Key('ernaehrung-uebersicht-gegessen')),
        contains(formatNumber(1200)),
      );
    });

    testWidgets('der Bogen füllt sich mit dem verbrauchten Teil des Budgets', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 1200));
      await zeige(tester, h.app);

      expect(bogen(tester).anteil, closeTo(1200 / ziel(h), 1e-9));
      expect(bogen(tester).ueber, isFalse);
    });

    testWidgets('morgens ist das ganze Ziel übrig und der Bogen leer', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(uebrig(tester), contains(formatNumber(ziel(h))));
      expect(uebrig(tester), contains('übrig'));
      expect(
        bogen(tester).anteil,
        0,
        reason:
            'für Tims eigene Einträge ist „nichts eingetragen" eine '
            'Aussage — der Bogen ist leer, nicht ungefüllt',
      );
    });

    testWidgets('Verbrannt steht als `–/–` da, nie als 0', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag());
      await zeige(tester, h.app);

      final verbrannt = textUnter(
        tester,
        const Key('ernaehrung-uebersicht-verbrannt'),
      );
      expect(verbrannt, contains(ohneWert));
      expect(
        verbrannt,
        isNot(contains(RegExp(r'(^|\s)0(\s|$)'))),
        reason:
            'den Trainingszuschlag gibt es noch nicht (#389/#390) — eine 0 '
            'behauptete „nicht trainiert"',
      );
      expect(
        find.bySemanticsLabel(RegExp('Verbrannt[^,]*, *keine Werte')),
        findsOneWidget,
        reason: 'der Vorlesetext nennt den Zustand, nicht das Zeichen',
      );
    });
  });

  group('Über dem Ziel', () {
    testWidgets('steht dort „über Ziel" mit dem Betrag, und der Bogen ist '
        'voll', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 4000));
      await zeige(tester, h.app);

      final z = ziel(h);
      expect(z, lessThan(4000), reason: 'Vorbedingung: über dem Ziel');
      expect(uebrig(tester), contains('über ziel'));
      expect(uebrig(tester), contains(formatNumber(4000 - z)));
      expect(uebrig(tester), isNot(contains('übrig')));
      expect(
        uebrig(tester),
        isNot(contains('-')),
        reason: 'der Betrag steht ohne Vorzeichen, das Wort sagt die Richtung',
      );
      expect(bogen(tester).anteil, 1, reason: 'gedeckelt, keine zweite Runde');
      expect(bogen(tester).ueber, isTrue);
    });
  });

  group('Ohne Ziel', () {
    testWidgets('dieselbe Form, ungefüllt, `–/–` statt 0', (tester) async {
      final h = harness(stammdaten: const Stammdaten());
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 1200));
      await zeige(tester, h.app);

      expect(uebrig(tester), contains(ohneWert));
      expect(bogen(tester).anteil, isNull, reason: 'ungefüllt, nicht auf 0');
      expect(
        textUnter(tester, const Key('ernaehrung-uebersicht-gegessen')),
        contains(formatNumber(1200)),
        reason: 'gegessen ist trotzdem bekannt',
      );

      final kh = saeule(tester, 'kohlenhydrate');
      expect(
        kh.ziel,
        isNull,
        reason: 'ohne Kalorienziel gibt es kein Kohlenhydratziel (#310)',
      );
      expect(kh.wert, isNull);
      expect(
        textUnter(tester, const Key('ernaehrung-uebersicht-kohlenhydrate')),
        contains(ohneWert),
      );
      expect(saeule(tester, 'eiweiss').wert, 100);
      expect(saeule(tester, 'fett').wert, 40);
    });

    testWidgets('der Grund steht einmal, unter der Karte, nicht in ihr', (
      tester,
    ) async {
      final h = harness(stammdaten: const Stammdaten());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-ziel-fehlt')), findsOneWidget);
      final text = karte(tester);
      for (final wort in const ['berechenbar', 'apple health', 'kein ziel']) {
        expect(
          text,
          isNot(contains(wort)),
          reason:
              'ein Hinweis in der Karte stünde zum zweiten Mal da und '
              'machte sie höher, sobald das Ziel fehlt',
        );
      }
      expect(
        find.bySemanticsLabel(RegExp('Übrig[^,]*, *keine Werte')),
        findsOneWidget,
      );
    });

    testWidgets('ohne Gewicht stehen alle drei Balken mit `–/–`', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      await ErnaehrungRepository(h.db).buche(eintrag());
      await zeige(tester, h.app);

      for (final name in const ['kohlenhydrate', 'eiweiss', 'fett']) {
        expect(saeule(tester, name).wert, isNull, reason: name);
        expect(saeule(tester, name).platzhalter, isNull, reason: name);
        expect(
          textUnter(tester, Key('ernaehrung-uebersicht-$name')),
          contains(ohneWert),
          reason: name,
        );
      }
    });
  });

  group('Während des Ladens (Fehler 01)', () {
    testWidgets('steht kein „keine Daten"-Grund und kein `–/–` in der Karte', (
      tester,
    ) async {
      final h = laedt();
      await zeige(tester, h.app);

      final text = karte(tester);
      expect(text, isNot(contains(ohneWert)));
      expect(text, isNot(contains('kein')));
      expect(text, isNot(contains('berechenbar')));
      expect(find.byKey(const Key('ernaehrung-ziel-fehlt')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.byType(Platzhalter),
        ),
        findsWidgets,
      );
      expect(bogen(tester).anteil, isNull);
      for (final name in const ['kohlenhydrate', 'eiweiss', 'fett']) {
        expect(saeule(tester, name).platzhalter, isNotNull, reason: name);
        expect(saeule(tester, name).wert, isNull, reason: name);
      }
      expect(
        find.bySemanticsLabel(RegExp('Übrig[^,]*, *wird geladen')),
        findsOneWidget,
      );
      // Nur in der Karte: Die Wasserzeile darunter zeigt Tims eigene
      // Einträge, und für die heißt leer schlicht leer.
      expect(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.bySemanticsLabel(RegExp('keine Werte')),
        ),
        findsNothing,
        reason: '„keine Werte" wäre eine Aussage über einen Lauf, der läuft',
      );
    });

    testWidgets('ein nachladender Wert bleibt stehen — kein Platzhalter', (
      tester,
    ) async {
      final h = harness(
        fremde: Bekannt<List<FremdeMahlzeit>>(
          const [],
          stand: jetzt,
          laeuft: true,
        ),
      );
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 1200));
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
      );
      expect(uebrig(tester), contains('übrig'));
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets('die Karte steht in jedem Zustand gleich groß an derselben '
        'Stelle', (tester) async {
      Future<Rect> stelle(
        ({ProviderContainer container, AppCache db, Widget app}) h, {
        double? kcal,
      }) async {
        if (kcal != null) {
          await ErnaehrungRepository(h.db).buche(eintrag(kcal: kcal));
        }
        await zeige(tester, h.app);
        return tester.getRect(find.byKey(const Key('ernaehrung-uebersicht')));
      }

      final mitWerten = await stelle(harness(), kcal: 1200);
      expect(await stelle(harness()), mitWerten, reason: 'leer');
      expect(await stelle(laedt()), mitWerten, reason: 'lädt');
      expect(
        await stelle(harness(stammdaten: const Stammdaten()), kcal: 1200),
        mitWerten,
        reason: 'ohne Ziel',
      );
      expect(await stelle(harness(), kcal: 4000), mitWerten, reason: 'über');
    });
  });

  group('Details', () {
    testWidgets('führt zur Herleitung und klappt sie auf', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag());
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        findsNothing,
        reason: 'Vorbedingung: die Herleitung ist eingeklappt',
      );
      await tester.tap(find.byKey(const Key('ernaehrung-uebersicht-details')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        findsOneWidget,
      );
    });
  });

  group('Der Schirm hält, was er zeigt (Fehler 32)', () {
    testWidgets('nach dem Zurücknavigieren steht die Übersicht wieder da', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(kcal: 1200));
      await zeige(tester, h.app);

      final vorher = uebrig(tester);
      expect(vorher, contains('übrig'));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('woanders')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      // Ein einziges Bild nach dem Zurück — ein Platzhalter, der erst
      // nach dem Nachladen verschwände, stünde genau hier.
      await tester.pump();

      expect(uebrig(tester), vorher);
      expect(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(uebrig(tester), vorher);
    });
  });
}

class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

class _StilleQuelle extends HealthReadingAttrappe {}
