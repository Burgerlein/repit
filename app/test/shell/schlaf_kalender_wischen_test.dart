import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für **das Blättern im Monatsraster durch Wischen** (#241) —
/// `lib/shell/schlaf_kalenderblatt.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Tim am 03.11.2026 auf dem Gerät: „oben die Pfeile gehen, aber in der
/// Monatsansicht will ich gerne blättern können."
///
/// Es fehlt also keine Grenze und keine Freischaltung — die Pfeile im
/// Monatskopf tun seit #177, was sie sollen. Es fehlt **die Geste im
/// Raster**: Wer einen Monatskalender vor sich hat, wischt ihn, statt einen
/// 44 Punkt breiten Pfeil zu treffen.
///
/// ## Die drei Anforderungen
///
/// 1. **Wisch nach rechts → der Monat davor, nach links → der danach.**
///    Dieselbe Richtung wie die Wischgeste über dem Nachtbereich (#127) und
///    wie in Fotos und Apple Health; die Pfeile im Kopf zeigen in dieselben
///    Richtungen.
/// 2. **Wisch und Pfeil meinen dieselbe Menge.** Wo der Pfeil aus ist,
///    passiert auch beim Wischen nichts — kein leerer Januar, in den sich
///    nichts eintragen ließe (#177). Genau an dieser Spaltung ist am
///    29.10.2026 schon einmal etwas zerbrochen (`4a51775`): Der Pfeil wies
///    auf einen Tag und das Drücken führte an ihm vorbei. Hier wird deshalb
///    **beides zusammen** geprüft: der Zustand des Pfeils und das Ergebnis
///    des Wischs, im selben Testfall.
/// 3. **Die linke Bildschirmkante gehört dem System.** iOS blättert von
///    dort im Navigationsstapel zurück. Ein Zug, der im linken Streifen
///    aufsetzt, darf das Raster nicht bewegen.
///
/// ## Und der Tipper bleibt ein Tipper
///
/// Im Raster liegt auf jedem Tag schon eine Geste: Antippen wählt den Tag
/// und schließt das Blatt (#92, #177). Eine Wischgeste darüber darf sie
/// nicht auffressen — und umgekehrt. Deshalb zieht jeder Wisch hier **von
/// der Mitte einer Tageszelle aus**, nicht von einer Lücke dazwischen: Das
/// ist der Fall, der schiefgehen kann.
///
/// ## Was hier nicht geprüft wird
///
/// - **Die Haptik am Rand.** Ein Widget-Test sieht keinen
///   Vibrationsmotor; nachprüfbar ist nur, dass kein Monatswechsel
///   stattfindet (`CLAUDE.md`, „Was ein Widget-Test nicht sehen kann").
/// - **Schwellwerte.** Ab welcher Strecke oder welchem Tempo ein Zug als
///   Wisch gilt, ist Abstimmung am Gerät. Gezogen wird deutlich: 240
///   Punkte auf einem 900 Punkte breiten Schirm.
/// - **Eine Animation.** Der Entwurf sieht keine vor; der Monat wechselt.
///
/// ## Die Monate dieser Datei
///
/// Heute ist der 20.08.2027, der gelesene Zeitraum beginnt am 01.02.2027.
/// Damit sind Februar bis August erreichbar, davor und danach nichts —
/// zwei Ränder in einer Hülle. Alle Zahlen sind erfunden (`CLAUDE.md`).
void main() {
  // Freitag, 20.08.2027, 09:00 Berlin (MESZ, +2).
  final jetzt = DateTime.utc(2027, 8, 20, 7);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Sieben Stunden Kernschlaf — damit der Schirm überhaupt etwas zeigt.
  SleepNight nachtVon(int jahr, int monat, int tag) {
    final ende = tagesbeginn(jahr, monat, tag);
    final beginn = ende.subtract(const Duration(hours: 1));
    return SleepNight(
      date: ende,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(const Duration(hours: 7)),
          ),
        ],
      ),
      naps: const [],
    );
  }

  Widget huelle() {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dataWindowProvider.overrideWith(
          (ref) => DataWindow(start: tagesbeginn(2027, 2, 1)),
        ),
        healthProvider.overrideWithValue(_LeereQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              [
                // Die Nacht vom 1. Februar hält den frühesten Tag dort
                // fest — eine Nacht, die oben stehen kann, muss auch
                // anwählbar sein.
                nachtVon(2027, 2, 1),
                nachtVon(2027, 8, 19),
                nachtVon(2027, 8, 20),
              ],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(home: SchlafSeite(router: router)),
    );
  }

  /// Öffnet den Schirm und darauf das Kalenderblatt.
  Future<void> oeffne(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(huelle());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
    await tester.pumpAndSettle();
  }

  Finder tag(String schluessel) =>
      find.byKey(Key('schlaf-kalender-tag-$schluessel'));

  /// Welcher Monat gerade im Raster steht — abgelesen am 15., den jeder
  /// Monat hat.
  String gezeigterMonat(WidgetTester tester) {
    for (final kandidat in const [
      '2027-01',
      '2027-02',
      '2027-03',
      '2027-04',
      '2027-05',
      '2027-06',
      '2027-07',
      '2027-08',
      '2027-09',
    ]) {
      if (tag('$kandidat-15').evaluate().isNotEmpty) return kandidat;
    }
    return 'kein Monat im Raster';
  }

  /// Die Höhe der Rasterzeile, in der der 15. steht. Die trifft in jedem
  /// Monat lauter volle Tageszellen — der 15. liegt immer in der dritten
  /// Zeile, und die beginnt frühestens beim 8.
  double rasterhoehe(WidgetTester tester) =>
      tester.getCenter(tag('${gezeigterMonat(tester)}-15')).dy;

  /// Ein deutlicher waagerechter Zug **über einer Tageszelle** — aus der
  /// Mitte des Schirms heraus, also über dem Tag in der mittleren Spalte
  /// jener Zeile.
  ///
  /// Positives [weite] heißt nach rechts — zum Monat davor.
  Future<void> wische(WidgetTester tester, double weite) async {
    await tester.dragFrom(Offset(450, rasterhoehe(tester)), Offset(weite, 0));
    await tester.pumpAndSettle();
  }

  /// `null` heißt: Der Pfeil ist aus.
  VoidCallback? pfeil(WidgetTester tester, String richtung) => tester
      .widget<CupertinoButton>(
        find.byKey(Key('schlaf-kalender-monat-$richtung')),
      )
      .onPressed;

  // ═════════════════════════════════════════════════════════════════════
  // 1 — Im Raster wischen blättert
  // ═════════════════════════════════════════════════════════════════════

  group('Wischen im Monatsraster', () {
    testWidgets('nach rechts führt in den Monat davor', (tester) async {
      await oeffne(tester);
      expect(gezeigterMonat(tester), '2027-08');

      await wische(tester, 240);

      expect(
        gezeigterMonat(tester),
        '2027-07',
        reason:
            'Ein Wisch nach rechts führt zum Monat davor — dieselbe '
            'Richtung wie der linke Pfeil im Monatskopf und wie die '
            'Wischgeste über dem Nachtbereich (#127).',
      );
      expect(
        tag('2027-07-31'),
        findsOneWidget,
        reason: 'Der Juli 2027 hat 31 Tage.',
      );
    });

    testWidgets('nach links wieder zurück', (tester) async {
      await oeffne(tester);

      await wische(tester, 240);
      expect(gezeigterMonat(tester), '2027-07');

      await wische(tester, -240);

      expect(gezeigterMonat(tester), '2027-08');
    });

    testWidgets('und mehrmals hintereinander trägt es bis zum Februar', (
      tester,
    ) async {
      await oeffne(tester);

      for (var i = 0; i < 6; i++) {
        await wische(tester, 240);
      }

      expect(gezeigterMonat(tester), '2027-02');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Wisch und Pfeil meinen dieselbe Menge
  // ═════════════════════════════════════════════════════════════════════

  group('An der Grenze tut der Wisch nichts', () {
    testWidgets(
      'am frühesten Monat ist der Pfeil aus — und der Wisch läuft nicht in '
      'einen leeren Januar',
      (tester) async {
        await oeffne(tester);
        for (var i = 0; i < 6; i++) {
          await wische(tester, 240);
        }
        expect(gezeigterMonat(tester), '2027-02');

        expect(
          pfeil(tester, 'frueher'),
          isNull,
          reason:
              'Der gelesene Zeitraum beginnt am 01.02.2027 — weiter zurück '
              'gibt es keinen Tag, der etwas sagen könnte (#177).',
        );

        await wische(tester, 240);

        expect(
          gezeigterMonat(tester),
          '2027-02',
          reason:
              'Wisch und Pfeil müssen dieselbe Menge meinen. Ist der Pfeil '
              'aus, darf die Geste nicht trotzdem weiterblättern — sonst '
              'steht ein Januar da, in dem kein einziger Tag antippbar ist.',
        );
        expect(tag('2027-01-15'), findsNothing);
      },
    );

    testWidgets(
      'am heutigen Monat ist der Pfeil nach vorn aus — und der Wisch nach '
      'links bleibt stehen',
      (tester) async {
        await oeffne(tester);
        expect(gezeigterMonat(tester), '2027-08');

        expect(
          pfeil(tester, 'spaeter'),
          isNull,
          reason: 'Nach heute kommt nichts, was man eintragen könnte.',
        );

        await wische(tester, -240);

        expect(gezeigterMonat(tester), '2027-08');
        expect(tag('2027-09-15'), findsNothing);
      },
    );

    testWidgets('dazwischen sind beide Pfeile an und beide Richtungen gehen', (
      tester,
    ) async {
      await oeffne(tester);
      await wische(tester, 240);

      expect(pfeil(tester, 'frueher'), isNotNull);
      expect(pfeil(tester, 'spaeter'), isNotNull);
    });

    testWidgets(
      'Wisch und Pfeil kommen über dieselbe Strecke zum selben Monat',
      (tester) async {
        await oeffne(tester);
        for (var i = 0; i < 3; i++) {
          await wische(tester, 240);
        }
        final ueberDenWisch = gezeigterMonat(tester);

        // Mit dem Pfeil wieder vor, dann mit dem Pfeil wieder zurück.
        for (var i = 0; i < 3; i++) {
          await tester.tap(
            find.byKey(const Key('schlaf-kalender-monat-spaeter')),
          );
          await tester.pumpAndSettle();
        }
        expect(
          gezeigterMonat(tester),
          '2027-08',
          reason: 'Pfeil und Wisch sind dieselbe Bewegung, nur andersherum.',
        );

        for (var i = 0; i < 3; i++) {
          await tester.tap(
            find.byKey(const Key('schlaf-kalender-monat-frueher')),
          );
          await tester.pumpAndSettle();
        }

        expect(gezeigterMonat(tester), ueberDenWisch);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3 — Die linke Kante gehört dem System
  // ═════════════════════════════════════════════════════════════════════

  group('Der Zurück-Wisch von der linken Kante', () {
    testWidgets('ein Zug, der an der linken Kante beginnt, blättert nicht', (
      tester,
    ) async {
      await oeffne(tester);
      final hoehe = rasterhoehe(tester);

      await tester.dragFrom(Offset(4, hoehe), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(
        gezeigterMonat(tester),
        '2027-08',
        reason:
            'Ein Zeiger im linken Systemstreifen darf gar nicht erst in die '
            'Gestenarena kommen — sonst ist der Zurück-Wisch verloren.',
      );
    });

    testWidgets('dicht daneben blättert er sehr wohl', (tester) async {
      await oeffne(tester);
      final hoehe = rasterhoehe(tester);

      await tester.dragFrom(Offset(40, hoehe), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(
        gezeigterMonat(tester),
        '2027-07',
        reason:
            'Der Streifen ist 20 Punkte breit, nicht die halbe Kachel. Wäre '
            'er breiter, bliebe die erste Rasterspalte tot.',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4 — Der Tipper bleibt ein Tipper
  // ═════════════════════════════════════════════════════════════════════

  group('Wischen und Antippen fressen einander nicht', () {
    testWidgets('ein Tipp auf einen Tag wählt ihn und schließt das Blatt', (
      tester,
    ) async {
      await oeffne(tester);

      await tester.tap(tag('2027-08-15'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('schlaf-kalenderblatt')),
        findsNothing,
        reason:
            'Das Antippen eines Tages ist seit #92 die Tür zu diesem Tag. '
            'Eine Wischgeste darüber darf sie nicht auffressen.',
      );
    });

    testWidgets('und ein Wisch von derselben Zelle aus wählt keinen Tag', (
      tester,
    ) async {
      await oeffne(tester);

      await wische(tester, 240);

      expect(
        find.byKey(const Key('schlaf-kalenderblatt')),
        findsOneWidget,
        reason:
            'Ein Wisch ist kein Tipp — er blättert, er schließt das Blatt '
            'nicht und wählt keinen Tag aus.',
      );
      expect(gezeigterMonat(tester), '2027-07');
    });
  });
}

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

/// Liefert nichts — Puls und Atmung sind hier nicht der Gegenstand.
class _LeereQuelle extends HealthReadingAttrappe {}
