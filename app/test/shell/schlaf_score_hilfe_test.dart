import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für **#429, Vorschlag A** — die Score-Karte des Schlaf-Schirms ist
/// für jede Nacht gleich hoch.
///
/// Tim am 10.11.2026: Bei einer von Hand eingetragenen Nacht sprang die
/// Karte, weil unter den Teilnoten ein Satz „Erreichbar sind hier 80
/// Punkte: …" erschien, den eine gemessene Nacht nicht hat. Dazu stand der
/// Kasten „Diese Nacht hast du selbst eingetragen" **über** der Karte und
/// schob sie beim Blättern um seine eigene Höhe nach unten. Tim hat
/// Vorschlag A gewählt (Kommentar in #429, Entwurf `schlaf.js`, Zustände
/// „Vorschlag #429 — A …"):
///
/// - In der Zeile „SCHLAFDAUER" steht rechts **immer** ein „?".
/// - Bei einer von Hand eingetragenen Nacht steht dort zusätzlich die
///   Marke „VON HAND" — keine neue Zeile.
/// - Der Satz unter der Karte fällt weg; was er sagte, steht im Blatt
///   hinter dem „?".
/// - Der Kasten zur eingetragenen Nacht steht **unter** der Karte.
///
/// `CLAUDE.md`: Widget-Tests prüfen Zustände und Übergänge, nicht Layout
/// und Beschriftung. Geprüft wird deshalb die **Regel** — gleiche Höhe,
/// gleiche Stelle, Marke nur bei der eingetragenen Nacht, der Grund im
/// Blatt und nicht unter der Karte —, nicht der Wortlaut.
///
/// ## Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `schlaf-scorekarte` | die Karte (besteht) |
/// | `schlaf-score-hilfe` | das „?" in der Zeile „SCHLAFDAUER" |
/// | `schlaf-score-marke` | die Marke „VON HAND" |
/// | `schlaf-score-blatt` | das Blatt hinter dem „?" |
/// | `schlaf-score-blatt-fertig` | „Fertig" im Kopf des Blatts |
/// | `schlaf-von-hand-hinweis` | der Kasten zur ersetzten Nacht (besteht) |
/// | `schlaf-ergaenzung-hinweis` | der Kasten zur ergänzten Nacht (besteht) |
///
/// **Die Ergänzung (#192) ist mitgenommen**, obwohl #429 nur den Kasten
/// zur ersetzten Nacht nennt: Es ist derselbe Kasten mit anderem Text
/// (`_EintragHinweis`), er stand an derselben Stelle über der Karte und
/// schob sie genauso. Eine Ergänzung ist aber **gemessen** — sie trägt
/// deshalb keine Marke „VON HAND", und erreichbar bleiben 100 Punkte.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`).
void main() {
  // Donnerstag, 29.10.2026, 10:00 Berlin (CET).
  final jetzt = DateTime.utc(2026, 10, 29, 9);

  DateTime tag(int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tagImMonat, 12));

  /// Eine gemessene Nacht ab 23:00 des Vortags: Kernschlaf, eine kurze
  /// Wachphase, wieder Kernschlaf — damit „Unterbrechungen" etwas zu
  /// zählen hat.
  SleepNight gemesseneNacht(int tagImMonat) {
    final beginn = BerlinCalendar.startOfDay(
      DateTime.utc(2026, 10, tagImMonat - 1, 12),
    ).add(const Duration(hours: 23));
    final a = beginn.add(const Duration(minutes: 200));
    final b = a.add(const Duration(minutes: 10));
    final c = b.add(const Duration(minutes: 210));
    return SleepNight(
      date: tag(tagImMonat),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: a),
          SleepSegment(stage: SleepStage.awake, start: a, end: b),
          SleepSegment(stage: SleepStage.core, start: b, end: c),
        ],
      ),
    );
  }

  ({ProviderContainer container, Widget app}) huelle() {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              [gemesseneNacht(28), gemesseneNacht(29)],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: SchlafSeite(router: router)),
      ),
    );
  }

  /// Zeigt den Schirm. Die Nacht vom 28. ist **von Hand eingetragen**,
  /// wenn [eintrag] gesetzt ist; die vom 29. bleibt gemessen, außer
  /// [ergaenzung29] legt ihr einen Abendschlaf dazu.
  Future<ProviderContainer> zeige(
    WidgetTester tester, {
    _Eintrag? eintrag,
    bool ergaenzung29 = false,
  }) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist.
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = huelle();
    await tester.pumpWidget(h.app);
    await tester.pumpAndSettle();

    final eintraege = h.container.read(schlafEintraegeProvider.notifier);
    if (eintrag != null) {
      // Überlappt die gemessene Nacht vom 28. — eine Korrektur, die sie
      // ersetzt (#131, #192).
      await eintraege.setzeNacht(
        tag: BerlinCalendar.dayKey(tag(28)),
        schlafMinuten: 425,
        beginnMinuten: eintrag.mitZeiten ? 23 * 60 + 10 : null,
        endeMinuten: eintrag.mitZeiten ? 6 * 60 + 15 : null,
      );
    }
    if (ergaenzung29) {
      // 19:00 bis 21:30 am Abend davor — überlappt nicht, kommt dazu.
      await eintraege.setzeNacht(
        tag: BerlinCalendar.dayKey(tag(29)),
        schlafMinuten: 150,
        beginnMinuten: 19 * 60,
        endeMinuten: 21 * 60 + 30,
      );
    }
    await tester.pumpAndSettle();
    return h.container;
  }

  Future<void> zurNachtDavor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('schlaf-frueher')));
    await tester.pumpAndSettle();
  }

  final karte = find.byKey(const Key('schlaf-scorekarte'));

  String textUnter(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  Finder inDerKarte(Key key) =>
      find.descendant(of: karte, matching: find.byKey(key));

  // ───────────────────────────────────────────────────────────────────────
  // Eine Form
  // ───────────────────────────────────────────────────────────────────────

  group('Die Karte hat für jede Nacht dieselbe Form', () {
    testWidgets(
      'eine gemessene und eine von Hand eingetragene Nacht machen die '
      'Karte gleich hoch',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));

        final gemessen = tester.getSize(karte).height;
        await zurNachtDavor(tester);
        final vonHand = tester.getSize(karte).height;

        expect(
          vonHand,
          gemessen,
          reason:
              'Tims Beobachtung vom 10.11.2026: Die Karte wurde bei einer '
              'eingetragenen Nacht höher — „Eine Anzeige, die es gibt, hat '
              'genau eine Form"',
        );
      },
    );

    testWidgets(
      'auch ohne Uhrzeiten — wenn Zubettgehzeit **und** Unterbrechungen '
      'entfallen — bleibt die Karte gleich hoch',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: false));

        final gemessen = tester.getSize(karte).height;
        await zurNachtDavor(tester);

        expect(tester.getSize(karte).height, gemessen);
      },
    );

    testWidgets(
      'beim Blättern auf die eingetragene Nacht steht die Karte an '
      'derselben Stelle — der Kasten schiebt sie nicht mehr nach unten',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));

        final obenGemessen = tester.getTopLeft(karte).dy;
        await zurNachtDavor(tester);

        expect(tester.getTopLeft(karte).dy, obenGemessen);
      },
    );

    testWidgets(
      'und beim Blättern zurück auf die gemessene Nacht ebenso',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));

        await zurNachtDavor(tester);
        final obenVonHand = tester.getTopLeft(karte).dy;
        final hoeheVonHand = tester.getSize(karte).height;

        await tester.tap(find.byKey(const Key('schlaf-spaeter')));
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(karte).dy, obenVonHand);
        expect(tester.getSize(karte).height, hoeheVonHand);
      },
    );

    testWidgets(
      'eine ergänzte Nacht (#192) steht ebenfalls an derselben Stelle und '
      'ist gleich hoch',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
        await zurNachtDavor(tester);
        final oben = tester.getTopLeft(karte).dy;
        final hoehe = tester.getSize(karte).height;

        // Ein zweiter Schirm, auf dem die Nacht vom 29. ergänzt ist.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await zeige(tester, ergaenzung29: true);

        expect(
          find.byKey(const Key('schlaf-ergaenzung-hinweis')),
          findsOneWidget,
        );
        expect(tester.getTopLeft(karte).dy, oben);
        expect(tester.getSize(karte).height, hoehe);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Kasten
  // ───────────────────────────────────────────────────────────────────────

  group('Der Kasten zur eingetragenen Nacht steht unter der Karte', () {
    testWidgets('bei der ersetzten Nacht', (tester) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
      await zurNachtDavor(tester);

      final kasten = find.byKey(const Key('schlaf-von-hand-hinweis'));
      expect(kasten, findsOneWidget);
      expect(
        tester.getTopLeft(kasten).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(karte).dy),
      );
    });

    testWidgets('bei der ergänzten Nacht', (tester) async {
      await zeige(tester, ergaenzung29: true);

      final kasten = find.byKey(const Key('schlaf-ergaenzung-hinweis'));
      expect(kasten, findsOneWidget);
      expect(
        tester.getTopLeft(kasten).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(karte).dy),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // „?" und Marke
  // ───────────────────────────────────────────────────────────────────────

  group('Das „?" und die Marke', () {
    testWidgets('das „?" steht bei der gemessenen Nacht in der Karte', (
      tester,
    ) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));

      expect(inDerKarte(const Key('schlaf-score-hilfe')), findsOneWidget);
    });

    testWidgets('und bei der eingetragenen Nacht ebenso', (tester) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
      await zurNachtDavor(tester);

      expect(inDerKarte(const Key('schlaf-score-hilfe')), findsOneWidget);
    });

    testWidgets('die Marke steht nur bei der eingetragenen Nacht', (
      tester,
    ) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));

      expect(find.byKey(const Key('schlaf-score-marke')), findsNothing);

      await zurNachtDavor(tester);

      expect(inDerKarte(const Key('schlaf-score-marke')), findsOneWidget);
      expect(
        textUnter(tester, find.byKey(const Key('schlaf-score-marke'))),
        contains('von hand'),
      );
    });

    testWidgets(
      'eine ergänzte Nacht ist gemessen und trägt deshalb keine Marke',
      (tester) async {
        await zeige(tester, ergaenzung29: true);

        expect(find.byKey(const Key('schlaf-score-marke')), findsNothing);
        expect(inDerKarte(const Key('schlaf-score-hilfe')), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Kein Satz unter der Karte
  // ───────────────────────────────────────────────────────────────────────

  group('Unter den Teilnoten steht kein Satz mehr', () {
    testWidgets(
      'bei der eingetragenen Nacht nennt die Karte die erreichbare '
      'Punktzahl nur in der Caption — kein „erreichbar", kein „bewertet '
      'wird"',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
        await zurNachtDavor(tester);

        final text = textUnter(tester, karte);
        expect(text, isNot(contains('erreichbar')));
        expect(text, isNot(contains('bewertet wird')));
      },
    );

    testWidgets('und ohne Uhrzeiten genauso', (tester) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: false));
      await zurNachtDavor(tester);

      final text = textUnter(tester, karte);
      expect(text, isNot(contains('erreichbar')));
      expect(text, isNot(contains('bewertet wird')));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Blatt
  // ───────────────────────────────────────────────────────────────────────

  group('Das „?" öffnet das Blatt mit dem Grund', () {
    final blatt = find.byKey(const Key('schlaf-score-blatt'));

    Future<void> oeffne(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('schlaf-score-hilfe')));
      await tester.pumpAndSettle();
    }

    testWidgets('vorher ist kein Blatt da, nach dem Tippen eins', (
      tester,
    ) async {
      await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
      await zurNachtDavor(tester);

      expect(blatt, findsNothing);
      await oeffne(tester);
      expect(blatt, findsOneWidget);
    });

    testWidgets(
      'bei der eingetragenen Nacht nennt es die erreichbare Punktzahl und '
      'den Grund: von Hand, die Unterbrechungen entfallen',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
        await zurNachtDavor(tester);
        await oeffne(tester);

        final text = textUnter(tester, blatt);
        expect(text, contains('80'));
        expect(text, contains('von hand'));
        expect(text, contains('unterbrechungen'));
        expect(text, contains('anteil'));
      },
    );

    testWidgets(
      'ohne Uhrzeiten nennt es beide Gründe — die fehlende Einschlafzeit '
      'und die Unterbrechungen',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: false));
        await zurNachtDavor(tester);
        await oeffne(tester);

        final text = textUnter(tester, blatt);
        expect(text, contains('50'));
        expect(text, contains('einschlafzeit'));
        expect(text, contains('unterbrechungen'));
      },
    );

    testWidgets(
      'bei der gemessenen Nacht erklärt es den Score, aber nennt keinen '
      'Grund für weniger Punkte',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
        await oeffne(tester);

        expect(blatt, findsOneWidget);
        final text = textUnter(tester, blatt);
        expect(text, contains('anteil'));
        expect(text, isNot(contains('von hand')));
      },
    );

    testWidgets('„Fertig" schließt das Blatt, die Nacht bleibt dieselbe', (
      tester,
    ) async {
      final container = await zeige(
        tester,
        eintrag: const _Eintrag(mitZeiten: true),
      );
      await zurNachtDavor(tester);
      await oeffne(tester);

      await tester.tap(find.byKey(const Key('schlaf-score-blatt-fertig')));
      await tester.pumpAndSettle();

      expect(blatt, findsNothing);
      final daten = container.read(schlafProvider).daten;
      expect(
        (daten as Bekannt<SchlafDaten>).wert.nacht!.nacht.date,
        tag(28),
      );
    });

    testWidgets(
      'der Pflichthinweis „keine medizinische Bewertung" steht weiter auf '
      'der Seite, nicht nur im Blatt',
      (tester) async {
        await zeige(tester, eintrag: const _Eintrag(mitZeiten: true));
        await zurNachtDavor(tester);

        expect(
          textUnter(tester, find.byKey(const Key('schlaf-fussnote'))),
          contains('keine medizinische bewertung'),
        );
      },
    );
  });
}

class _Eintrag {
  const _Eintrag({required this.mitZeiten});

  final bool mitZeiten;
}

/// Eine Quelle, die auf alles mit „nichts" antwortet — die Nächte kommen
/// aus dem überschriebenen `sleepProvider`.
class _StilleQuelle extends HealthReadingAttrappe {}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}
