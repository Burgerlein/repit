import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/segment_ring.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_zustand.dart';
import 'package:repit/shell/tagschlaf_view.dart';
// `AppTarget` liegt in `shell/ziele.dart`, nicht in `shell/router.dart`.
import 'package:repit/shell/ziele.dart';

import '../design/support.dart' show textOf;

/// Tests für den **Schirm** `tagschlaf` (#92) —
/// `lib/shell/tagschlaf_view.dart`. Der Zustand darunter
/// (`tagschlafProvider`) liegt in `schlaf_zustand_test.dart`, der
/// Nacht-Schirm in `schlaf_view_test.dart`.
///
/// ## Warum das ein eigener Schirm ist und kein Abschnitt
///
/// `docs/SPEC.md` 4.6 führt den Tagschlaf **getrennt**: Er geht nicht in
/// Dauer, Score oder Wachzeit der Nacht ein. Der Entwurf
/// (`docs/screens/screens/tagschlaf.js`) zieht daraus die Folge für die
/// Oberfläche: „Hier steht bewusst **nichts von der Nacht**. Wer die Kachel
/// antippt, will wissen, was er am Tag geschlafen hat." Genau das ist die
/// Regel, die diese Datei prüft — ein Abschnitt auf dem Nacht-Schirm könnte
/// sie gar nicht einhalten.
///
/// ## Festgelegte öffentliche API (`lib/shell/tagschlaf_view.dart`)
///
/// ```dart
/// /// Öffnet den Tagschlaf-Schirm auf dem Stapel des **aktuell gewählten**
/// /// Tabs.
/// void oeffneTagschlaf(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste.
/// class TagschlafSeite extends StatelessWidget {
///   const TagschlafSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class TagschlafView extends ConsumerWidget {
///   const TagschlafView({super.key});
/// }
/// ```
///
/// **`TagschlafView` nimmt keinen Tag entgegen.** Welcher Tag gemeint ist,
/// entscheidet `tagschlafProvider` aus der Auswahl des Nacht-Schirms —
/// siehe die Begründung in `schlaf_zustand_test.dart`. Ein Parameter daneben
/// wäre eine zweite Wahrheit über denselben Tag, und der Schirm besorgte
/// seine Daten dann nicht mehr selbst.
///
/// Ein `AppRouter` steht trotzdem an [TagschlafSeite]: Der Schirm hat heute
/// keine eigene Tür, aber die Leiste gehört dem Gastgeber, und jeder andere
/// gepushte Schirm dieses Bereichs wird gleich gebaut.
///
/// ## Die Schlüssel
///
/// - `Key('tagschlaf-laden')` — der reine Ladezweig
/// - `Key('tagschlaf-keine-daten')` — fertiger Lauf, **gar keine**
///   Schlafdaten: beide Möglichkeiten werden genannt
/// - `Key('tagschlaf-fehler')` — gescheiterter Lauf ohne Cache
/// - `Key('tagschlaf-leer')` — Schlafdaten da, an diesem Tag aber kein
///   Nickerchen. **Etwas anderes** als `tagschlaf-keine-daten`
/// - `Key('tagschlaf-datum')` — die Datumszeile
/// - `Key('tagschlaf-summe')` — „AM TAG GESCHLAFEN", die Zahl, die man sucht
/// - `Key('tagschlaf-phase-0')`, `Key('tagschlaf-phase-1')`, … — je Phase
///   eine Karte, Index in zeitlicher Reihenfolge
/// - `Key('tagschlaf-fussnote')` — die Erklärung
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht Layout
/// und Beschriftung. Wo ein Text eine *Regel* trägt, wird die Regel geprüft:
///
/// - Hier steht **nichts von der Nacht**: kein Score, kein Ring, und die
///   Summe zählt ausschließlich Nickerchen.
/// - „Kein Nickerchen an diesem Tag" und „gar keine Schlafdaten" sind zwei
///   verschiedene Aussagen und haben zwei verschiedene Zweige. Nur der
///   zweite nennt beide Möglichkeiten.
/// - Während des Ladens steht **kein** Grund (`docs/todo/01`).
/// - Eine fehlende Summe steht nie als `0`.
/// - Jede Phase bekommt ihr **eigenes** Hypnogramm — nicht eines über alle.
///
/// **Nicht geprüft, bewusst:**
///
/// - **„Tagschlaf von Hand eintragen".** ENTWURF vom 26.10.2026
///   (`tagschlaf.js:15–36`), steht **nicht** in `docs/SPEC.md` und nicht im
///   Auftrag. Der Schirm baut es nicht, dieser Test verlangt es nicht — und
///   deshalb trägt die Navigationsleiste auch **keinen** (+)-Knopf, den der
///   Entwurf oben rechts zeigt. Ein Knopf, der nichts auslöst, wäre
///   derselbe Fehler wie eine stumme Zeile, die aussieht wie eine Tür.
/// - **Wohin der Erholung-Schirm springt.** Das legt
///   `erholung_view_test.dart` fest; hier wird nur [oeffneTagschlaf] für
///   sich geprüft.
///
///   *(Stand 28.10.2026: Bis dahin stand hier, die Tagschlaf-Kachel führe
///   noch auf `ErholungTuerPlatzhalter`. Seit dem Durchgang „die Türen
///   werden verdrahtet" führt sie auf `TagschlafSeite`, und der
///   Platzhalter ist weg. An dieser Datei ändert das nichts.)*
/// - Farben, Abstände, Schriften und die Reihenfolge der Abschnitte
///   untereinander.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  /// Eine Nacht, sieben Stunden ab 23:00 des Vortags.
  SleepNight nachtVon(int tag, {List<SleepSession> naps = const []}) =>
      SleepNight(
        date: tagesbeginn(tag),
        session: SleepSession(
          segments: [
            SleepSegment(
              stage: SleepStage.core,
              start: berlin(tag - 1, 23),
              end: berlin(tag, 6),
            ),
          ],
        ),
        naps: naps,
      );

  /// Ein Nickerchen mit Phasen — [von] ist Berliner Wanduhrzeit.
  SleepSession nickerchen({
    required DateTime von,
    List<(SleepStage, int)> phasen = const [
      (SleepStage.awake, 3),
      (SleepStage.core, 18),
      (SleepStage.deep, 9),
      (SleepStage.core, 5),
    ],
  }) {
    final abschnitte = <SleepSegment>[];
    var zeiger = von;
    for (final (phase, minuten) in phasen) {
      final ende = zeiger.add(Duration(minutes: minuten));
      abschnitte.add(SleepSegment(stage: phase, start: zeiger, end: ende));
      zeiger = ende;
    }
    return SleepSession(segments: abschnitte);
  }

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    Messwert<List<SleepNight>>? schlaf,
    TagschlafZustand? zustand,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  [
                    nachtVon(11),
                    nachtVon(12, naps: [nickerchen(von: berlin(12, 13, 40))]),
                  ],
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        if (zustand != null) tagschlafProvider.overrideWith((ref) => zustand),
      ],
    );
    addTearDown(container.dispose);

    final inhalt = mitSeite
        ? TagschlafSeite(router: router)
        : const TagschlafView();

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: inhalt,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  TagschlafZustand handZustand(Messwert<List<SleepSession>> phasen) =>
      TagschlafZustand(phasen: phasen, tag: tagesbeginn(12));

  // ───────────────────────────────────────────────────────────────────────
  // Hausordnung
  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets(
      'TagschlafView bringt weder Gerüst noch Leiste noch Navigator',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(find.byType(CupertinoPageScaffold), findsNothing);
        expect(find.byType(CupertinoNavigationBar), findsNothing);
        expect(
          find.descendant(
            of: find.byType(TagschlafView),
            matching: find.byType(Navigator),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('TagschlafSeite stellt beides — sie ist das Geschobene', (
      tester,
    ) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(TagschlafView), findsOneWidget);
    });

    testWidgets('der Inhalt scrollt und bekommt GlasAbstand als padding', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byType(TagschlafView),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      final padding = scroll.padding! as EdgeInsets;

      expect(padding.top, 47);
      expect(
        padding.bottom,
        greaterThanOrEqualTo(34 + GlasAbstand.fabUeberstand),
      );
    });

    testWidgets(
      'der Schirm besorgt seine Daten selbst — ohne jede Vorarbeit steht das '
      'Nickerchen da',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(find.byKey(const Key('tagschlaf-summe')), findsOneWidget);
        expect(find.byKey(const Key('tagschlaf-phase-0')), findsOneWidget);
      },
    );

    testWidgets('oeffneTagschlaf schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final router = AppRouter();
      router.open(AppTarget.gym());
      router.nimmBefehl();

      oeffneTagschlaf(router);
      final befehl = router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(befehl.tab, Tab.gym);
    });

    testWidgets(
      'die Navigationsleiste trägt das (+) des Entwurfs — und es löst '
      'etwas aus, statt bloß dazustehen',
      (tester) async {
        // **Bis #131 stand hier das Gegenteil** („trägt keinen (+)"), und
        // die Begründung war: ein Knopf, der nichts auslöst, ist schlimmer
        // als keiner. Die Begründung gilt unverändert — nur gibt es jetzt
        // etwas auszulösen, nämlich das Formular (`tagschlaf.js` zeigt das
        // (+) in jeder Variante). Geprüft wird deshalb nicht, dass ein
        // Knopf da ist, sondern dass er etwas öffnet.
        final h = harness(mitSeite: true);
        await zeige(tester, h.app);

        final vorher = find.byType(ModalBarrier).evaluate().length;

        await tester.tap(find.byKey(const Key('tagschlaf-plus')));
        await tester.pumpAndSettle();

        expect(
          find.byType(ModalBarrier).evaluate().length,
          greaterThan(vorher),
        );
        expect(
          h.router.nimmBefehl(),
          isNull,
          reason: 'das Formular ist ein Blatt, kein Eintrag im Stapel',
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Hier steht nichts von der Nacht
  // ───────────────────────────────────────────────────────────────────────

  group('Nichts von der Nacht', () {
    testWidgets('kein Score, kein Ring — der Tagschlaf hat keinen', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byType(SegmentRing), findsNothing);
      expect(alleTexte(tester), isNot(contains('score')));
    });

    testWidgets(
      'die Summe zählt ausschließlich Nickerchen — die sieben Stunden der '
      'Nacht stehen nirgends',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        // Das Nickerchen schläft 32 der 35 Minuten (drei davon wach).
        expect(textUnter(tester, const Key('tagschlaf-summe')), contains('32'));
        expect(alleTexte(tester), isNot(contains('7 std.')));
      },
    );

    testWidgets('Wachliegen im Nickerchen zählt nicht als Schlaf', (
      tester,
    ) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          [
            nachtVon(
              12,
              naps: [
                nickerchen(
                  von: berlin(12, 13, 40),
                  phasen: const [(SleepStage.awake, 10), (SleepStage.core, 20)],
                ),
              ],
            ),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final summe = textUnter(tester, const Key('tagschlaf-summe'));

      expect(summe, contains('20'));
      expect(summe, isNot(contains('30')));
    });

    testWidgets('die Datumszeile nennt den Tag, nicht die Nacht', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final datum = textUnter(tester, const Key('tagschlaf-datum'));

      // Über `Format` mit fest gesetzter Locale: Auf einem englisch
      // eingestellten Gerät stünde hier sonst „October" mitten im
      // deutschen Text (`CLAUDE.md`).
      expect(datum, contains('Oktober'));
      expect(datum, contains('12'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Phasen
  // ───────────────────────────────────────────────────────────────────────

  group('Je Phase eine Karte', () {
    testWidgets('eine Phase, eine Karte', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('tagschlaf-phase-0')), findsOneWidget);
      expect(find.byKey(const Key('tagschlaf-phase-1')), findsNothing);
    });

    testWidgets('zwei Phasen, zwei Karten', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          [
            nachtVon(
              12,
              naps: [
                nickerchen(von: berlin(12, 13, 40)),
                nickerchen(von: berlin(12, 18, 5)),
              ],
            ),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('tagschlaf-phase-0')), findsOneWidget);
      expect(find.byKey(const Key('tagschlaf-phase-1')), findsOneWidget);
      expect(find.byKey(const Key('tagschlaf-phase-2')), findsNothing);
    });

    testWidgets(
      'jede Karte trägt ihr **eigenes** Hypnogramm — nicht eines über alle '
      'Phasen, das die Stunden dazwischen als Schlaf zeichnete',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            [
              nachtVon(
                12,
                naps: [
                  nickerchen(von: berlin(12, 13, 40)),
                  nickerchen(von: berlin(12, 18, 5)),
                ],
              ),
            ],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byType(Hypnogramm), findsNWidgets(2));
        expect(
          find.descendant(
            of: find.byKey(const Key('tagschlaf-phase-0')),
            matching: find.byType(Hypnogramm),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('tagschlaf-phase-1')),
            matching: find.byType(Hypnogramm),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('die Karten stehen in zeitlicher Reihenfolge', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          [
            nachtVon(
              12,
              naps: [
                nickerchen(von: berlin(12, 18, 5)),
                nickerchen(von: berlin(12, 13, 40)),
              ],
            ),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final erste = tester.widget<Hypnogramm>(
        find.descendant(
          of: find.byKey(const Key('tagschlaf-phase-0')),
          matching: find.byType(Hypnogramm),
        ),
      );

      expect(erste.session.segments.first.start, berlin(12, 13, 40));
    });

    testWidgets('die Summe über zwei Phasen ist die Summe beider', (
      tester,
    ) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          [
            nachtVon(
              12,
              naps: [
                nickerchen(
                  von: berlin(12, 13, 40),
                  phasen: const [(SleepStage.core, 20)],
                ),
                nickerchen(
                  von: berlin(12, 18, 5),
                  phasen: const [(SleepStage.core, 25)],
                ),
              ],
            ),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      // 45 Minuten, und die Überschrift nennt die Zahl der Phasen.
      final summe = textUnter(tester, const Key('tagschlaf-summe'));
      expect(summe, contains('45'));
      expect(summe, contains('2'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die vier Zustände von Messwert
  // ───────────────────────────────────────────────────────────────────────

  group('Die vier Zustände von Messwert', () {
    testWidgets('NochNie: ein Ladehinweis und **kein** Grund (docs/todo/01)', (
      tester,
    ) async {
      final h = harness(schlaf: const NochNie<List<SleepNight>>());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('tagschlaf-laden')), findsOneWidget);
      expect(find.byKey(const Key('tagschlaf-leer')), findsNothing);
      expect(find.byKey(const Key('tagschlaf-keine-daten')), findsNothing);
      expect(find.byKey(const Key('tagschlaf-summe')), findsNothing);

      final texte = alleTexte(tester);
      expect(texte, isNot(contains('aufgezeichnet')));
      expect(texte, isNot(contains('freigegeben')));
    });

    testWidgets(
      'LeerNachLauf: gar keine Schlafdaten — beide Möglichkeiten werden '
      'genannt, denn Apple verrät den Lesestatus nicht',
      (tester) async {
        final h = harness(
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('tagschlaf-keine-daten')), findsOneWidget);
        final texte = alleTexte(tester);
        expect(texte, contains('aufgezeichnet'));
        expect(texte, contains('freigegeben'));
      },
    );

    testWidgets(
      'Fehlgeschlagen: der Schirm sagt, dass es nicht geklappt hat — und '
      'gerade nicht, dass es keine Daten gäbe',
      (tester) async {
        final h = harness(
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'Kanal weg',
            gelaufen: jetzt,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('tagschlaf-fehler')), findsOneWidget);
        expect(find.byKey(const Key('tagschlaf-keine-daten')), findsNothing);
        expect(find.byKey(const Key('tagschlaf-leer')), findsNothing);
        expect(alleTexte(tester), isNot(contains('freigegeben')));
      },
    );

    testWidgets(
      'Schlafdaten da, aber kein Nickerchen: ein **eigener** Zweig. Hier ist '
      'die Lücke eindeutig, also werden nicht beide Möglichkeiten genannt',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            [nachtVon(11), nachtVon(12)],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('tagschlaf-leer')), findsOneWidget);
        expect(find.byKey(const Key('tagschlaf-keine-daten')), findsNothing);
        expect(alleTexte(tester), isNot(contains('freigegeben')));
      },
    );

    testWidgets(
      'und dann steht dort keine Summe — eine fehlende Zahl ist nie eine '
      'gemessene Null',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            [nachtVon(12)],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('tagschlaf-summe')), findsNothing);
        expect(find.byKey(const Key('tagschlaf-phase-0')), findsNothing);
        final texte = alleTexte(tester);
        expect(texte, isNot(contains('0 std.')));
        expect(texte, isNot(contains('0:00')));
      },
    );

    testWidgets(
      'der leere Zweig behauptet nicht, am Tag sei nicht geschlafen worden — '
      'die Uhr erkennt Tagschlaf schlecht, und das sagt der Schirm',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            [nachtVon(12)],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final text = textUnter(tester, const Key('tagschlaf-leer'));

        expect(text.trim(), isNotEmpty);
        expect(text.toLowerCase(), contains('erkennt'));
      },
    );

    testWidgets('Bekannt mit laufendem Nachlauf zeigt die Phasen weiter — ein '
        'gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg', (
      tester,
    ) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          [
            nachtVon(12, naps: [nickerchen(von: berlin(12, 13, 40))]),
          ],
          stand: jetzt,
          laeuft: true,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('tagschlaf-phase-0')), findsOneWidget);
    });

    testWidgets('ein von Hand gebauter Zustand kommt unverändert durch', (
      tester,
    ) async {
      final h = harness(
        zustand: handZustand(
          Bekannt<List<SleepSession>>(
            [nickerchen(von: berlin(12, 13, 40))],
            stand: jetzt,
            laeuft: false,
          ),
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('tagschlaf-phase-0')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Fußnote
  // ───────────────────────────────────────────────────────────────────────

  group('Die Erklärung am Ende', () {
    testWidgets(
      'sie sagt, dass der Tagschlaf nicht in die Nacht zählt — das ist der '
      'ganze Grund für diesen Schirm',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final fuss = textUnter(
          tester,
          const Key('tagschlaf-fussnote'),
        ).toLowerCase();

        expect(fuss, contains('nicht'));
        expect(fuss, anyOf(contains('score'), contains('schlafdauer')));
      },
    );

    testWidgets('und sie ist als Schätzung gekennzeichnet, nie als Diagnose', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final fuss = textUnter(
        tester,
        const Key('tagschlaf-fussnote'),
      ).toLowerCase();

      expect(
        fuss,
        anyOf(contains('schätzung'), contains('keine medizinische')),
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — wie `_Naechte` in
/// `erholung_zustand_test.dart` und aus demselben Grund: Riverpods
/// Provider-Typen sind invariant, ein unabhängiger `AsyncNotifier` erfüllt
/// die Signatur von `overrideWith` nicht.
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
