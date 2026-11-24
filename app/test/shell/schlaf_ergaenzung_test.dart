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
import '../health/health_reading_attrappe.dart';

/// Tests für die **eingetragene Nacht, die zur gemessenen dazukommt**
/// (#192) — `naechteMitEintraegen` und `schlafZustandAus` in
/// `lib/shell/schlaf_von_hand.dart` und `lib/shell/schlaf_zustand.dart`,
/// dazu, was der Schirm daraus macht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Die Entscheidung, um die es hier geht
///
/// Tim am 30.10.2026 am Gerät: „ich will einen schlaf nachtragen von
/// gestern. ich habe von 19-21:30 geschlafen wenn ich das mache wird die
/// nacht überschrieben". Nächte laufen von 18:00 bis 18:00, also fällt
/// 19:00 in „die Nacht dieses Tages" — und die Regel aus #131 („Der
/// Eintrag gewinnt, und zwar ganz") warf die gemessene Nacht samt
/// Hypnogramm, Puls- und Atemspannen weg.
///
/// Tims Entscheidung vom 30.10.2026: **Addieren, wenn es sich nicht
/// überlappt.** Ein Eintrag, der die gemessene Zeit **nicht** überlappt,
/// wird dazugezählt; nur ein Eintrag, der sie **überlappt**, gilt als
/// Korrektur und ersetzt sie — wie bisher. Die Grenze liegt bei **fünf
/// Minuten**, derselben Schwelle wie `kleinsteMessluecke` (#156) und aus
/// demselben Grund; gerechnet wird sie im Kern (`SleepMerge`,
/// `Packages/trainings_core/test/sleep_merge_test.dart`).
///
/// ## Was eine Ergänzung **nicht** ist
///
/// Sie ist **keine Korrektur**: Die gemessene Nacht bleibt vollständig
/// stehen, mit Phasen, Fenster, Wachminuten und Wachphasen. Und sie ist
/// **kein Tagschlaf**: Ihre Minuten zählen in die Nacht, nicht in die
/// Nickerchen-Zeile. Beides unterscheidet sie von den beiden Fällen, die
/// es schon gab.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_zustand.dart
///
/// class SchlafNacht {
///   /// Der Eintrag, wenn er die gemessene Nacht **ersetzt** (#131);
///   /// `null`, wenn er zu ihr dazukommt oder keiner vorliegt.
///   final SchlafEintrag? vonHand;
///
///   /// Der Eintrag, wenn er zur gemessenen Nacht **dazukommt** (#192);
///   /// `null` sonst. Nie zugleich mit [vonHand] gesetzt.
///   final SchlafEintrag? ergaenzung;
/// }
/// ```
///
/// Schlüssel, auf die sich diese Tests festlegen:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `schlaf-von-hand-hinweis` | der Kasten über der **ersetzten** Nacht |
/// | `schlaf-ergaenzung-hinweis` | der Kasten über der **ergänzten** Nacht |
/// | `schlaf-phasen` | das Hypnogramm |
void main() {
  final jetzt = DateTime.utc(2026, 10, 29, 9);
  DateTime tag(int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tagImMonat, 12));

  /// Eine gemessene Nacht: ein durchgehender Kernschlafabschnitt,
  /// [minuten] lang.
  ///
  /// [vonStunde] zählt Stunden ab dem Beginn des **Vortages** — 23 ist
  /// 23:00 am Abend, 28 ist 04:00 in der Früh des Aufwachtags.
  SleepNight gemesseneNacht(
    int tagImMonat, {
    int vonStunde = 23,
    int minuten = 420,
  }) {
    final beginn = BerlinCalendar.startOfDay(
      DateTime.utc(2026, 10, tagImMonat - 1, 12),
    ).add(Duration(hours: vonStunde));
    return SleepNight(
      date: tag(tagImMonat),
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(Duration(minutes: minuten)),
          ),
        ],
      ),
    );
  }

  /// Tims Fall: 19:00 bis 21:30, 150 Minuten, am Abend **vor** dem
  /// Aufwachtag — und damit in derselben 18-bis-18-Uhr-Nacht.
  SchlafEintrag abendEintrag(
    int tagImMonat, {
    int schlafMinuten = 150,
    int? beginnMinuten = 19 * 60,
    int? endeMinuten = 21 * 60 + 30,
  }) => SchlafEintrag(
    tag: BerlinCalendar.dayKey(tag(tagImMonat)),
    art: SchlafEintragArt.nacht,
    lfdNr: 0,
    schlafMinuten: schlafMinuten,
    beginnMinuten: beginnMinuten,
    endeMinuten: endeMinuten,
  );

  /// Derselbe Tag, aber über der gemessenen Nacht — eine Korrektur.
  SchlafEintrag korrekturEintrag(int tagImMonat) => SchlafEintrag(
    tag: BerlinCalendar.dayKey(tag(tagImMonat)),
    art: SchlafEintragArt.nacht,
    lfdNr: 0,
    schlafMinuten: 425,
    beginnMinuten: 23 * 60 + 10,
    endeMinuten: 6 * 60 + 15,
  );

  SchlafZustand zustandAus({
    required List<SleepNight> gemessen,
    List<SchlafEintrag> eintraege = const [],
    DateTime? gewaehlt,
  }) => schlafZustandAus(
    naechte: Bekannt<List<SleepNight>>(gemessen, stand: jetzt, laeuft: false),
    ziele: Ziele.vorbelegung,
    gewaehlt: gewaehlt,
    jetzt: jetzt,
    eintraege: eintraege,
  );

  SchlafDaten daten(SchlafZustand zustand) =>
      (zustand.daten as Bekannt<SchlafDaten>).wert;

  // ───────────────────────────────────────────────────────────────────────
  // Die gemessene Nacht bleibt stehen
  // ───────────────────────────────────────────────────────────────────────

  group('Ein Eintrag, der die Messung nicht überlappt, kommt dazu', () {
    test('die gemessene Nacht behält ihre Abschnitte', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [abendEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(
        nacht.nacht.session.segments,
        hasLength(1),
        reason:
            'Tims Beschwerde ist, dass die gemessene Nacht verschwindet — '
            'eine Ergänzung nimmt ihr nichts weg',
      );
    });

    test('der Eintrag steht als Ergänzung da, nicht als Ersatz', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [abendEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNull);
      expect(nacht.ergaenzung, isNotNull);
      expect(nacht.ergaenzung!.schlafMinuten, 150);
    });

    test('und die beiden schließen einander aus', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [korrekturEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNotNull);
      expect(nacht.ergaenzung, isNull);
    });

    test('ein überlappender Eintrag ersetzt weiterhin — die Begründung aus '
        '#131 trägt für eine Korrektur', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [korrekturEintrag(29)],
      );

      expect(daten(zustand).nacht!.nacht.session.segments, isEmpty);
    });

    test('ein Eintrag ohne Uhrzeiten ersetzt ebenfalls — eine Dauer lässt '
        'sich nicht auf die Uhr legen', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [abendEintrag(29, beginnMinuten: null, endeMinuten: null)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNotNull);
      expect(nacht.ergaenzung, isNull);
      expect(nacht.nacht.session.segments, isEmpty);
    });

    test('ohne gemessene Nacht ist der Eintrag die Nacht, wie bisher', () {
      final zustand = zustandAus(
        gemessen: const [],
        eintraege: [abendEintrag(29)],
      );

      final nacht = daten(zustand).nacht!;
      expect(nacht.vonHand, isNotNull);
      expect(nacht.ergaenzung, isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Score
  // ───────────────────────────────────────────────────────────────────────

  group('Was „addiert" für den Score heißt', () {
    SchlafNacht timsNacht() => daten(
      zustandAus(gemessen: [gemesseneNacht(29)], eintraege: [abendEintrag(29)]),
    ).nacht!;

    test('die Dauer zählt zusammen: 420 gemessene und 150 eingetragene '
        'Minuten sind 9:30 h', () {
      expect(timsNacht().kern.asleepMinutes, 570);
    });

    test('die Zubettgehzeit ist die der längeren Strecke — hier die '
        'gemessene', () {
      // 23:00 gegen das Ziel 22:30: clamp(30 − 30/15) = 28.
      expect(timsNacht().score.bedtime, 28);
    });

    test('ist der Eintrag die längere Strecke, zählt seine Einschlafzeit', () {
      final zustand = zustandAus(
        // Die Uhr kam erst um 04:00 ans Handgelenk und sah eine Stunde.
        gemessen: [gemesseneNacht(29, vonStunde: 28, minuten: 60)],
        eintraege: [
          abendEintrag(29, schlafMinuten: 390, endeMinuten: 1 * 60 + 30),
        ],
      );

      // 19:00 liegt vor dem Ziel — früher kostet nichts, also die vollen
      // 30 Punkte.
      expect(daten(zustand).nacht!.score.bedtime, 30);
    });

    test('die Unterbrechungen kommen aus der gemessenen Strecke und bleiben '
        'stehen — 100 erreichbare Punkte', () {
      final nacht = timsNacht();
      expect(nacht.score.interruptions, isNotNull);
      expect(
        nacht.score.maxTotal,
        100,
        reason:
            'die Phasen der gemessenen Nacht sind da; sie wegen eines '
            'Eintrags daneben entfallen zu lassen, würfe eine Messung weg',
      );
    });

    test('einmal durchgerechnet: 50 + 28 + 20 = 98 von 100, sehr gut', () {
      final score = timsNacht().score;
      expect(score.duration, 50);
      expect(score.bedtime, 28);
      expect(score.interruptions, 20);
      expect(score.total, 98);
      expect(score.rating, SleepRating.veryGood);
    });

    test('und derselbe Score steht im Kalenderblatt — zwei Wahrheiten über '
        'denselben Tag wären schlimmer als eine langsame', () {
      final d = daten(
        zustandAus(
          gemessen: [gemesseneNacht(29)],
          eintraege: [abendEintrag(29)],
        ),
      );

      expect(d.scores[tag(29)], d.nacht!.score);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Fenster
  // ───────────────────────────────────────────────────────────────────────

  group('Zwei Strecken, zwei Fenster', () {
    test('der Fenstertext nennt beide, die frühere zuerst', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [abendEintrag(29)],
      );

      expect(
        daten(zustand).nacht!.fensterText,
        '19:00–21:30 · 23:00–06:00',
        reason:
            '9:30 h neben einem einzigen Fenster von 7:00 h wäre eine '
            'Nacht, die sich nicht nachrechnen lässt',
      );
    });

    test('bei einer Korrektur bleibt es beim einen Fenster', () {
      final zustand = zustandAus(
        gemessen: [gemesseneNacht(29)],
        eintraege: [korrekturEintrag(29)],
      );

      expect(daten(zustand).nacht!.fensterText, '23:10–06:15');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Schirm
  // ───────────────────────────────────────────────────────────────────────

  group('Was der Schirm bei einer Ergänzung zeigt', () {
    ({ProviderContainer container, Widget app}) huelle({
      required List<SleepNight> gemessen,
    }) {
      final router = AppRouter();
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          appCacheProvider.overrideWithValue(db),
          // Ohne diese Zeile endet jedes `pumpAndSettle` in einer
          // Zeitschranke — derselbe Grund wie in `schlaf_eintragen_test`.
          healthProvider.overrideWithValue(_StilleQuelle()),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(gemessen, stand: jetzt, laeuft: false),
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

    Future<ProviderContainer> mitEintrag(
      WidgetTester tester, {
      required int beginnMinuten,
      required int endeMinuten,
      int schlafMinuten = 150,
    }) async {
      final h = huelle(gemessen: [gemesseneNacht(29)]);
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await h.container
          .read(schlafEintraegeProvider.notifier)
          .setzeNacht(
            tag: BerlinCalendar.dayKey(tag(29)),
            schlafMinuten: schlafMinuten,
            beginnMinuten: beginnMinuten,
            endeMinuten: endeMinuten,
          );
      await tester.pumpAndSettle();
      return h.container;
    }

    testWidgets('das Hypnogramm bleibt stehen — gemessen wurde ja etwas', (
      tester,
    ) async {
      await mitEintrag(
        tester,
        beginnMinuten: 19 * 60,
        endeMinuten: 21 * 60 + 30,
      );

      expect(find.byKey(const Key('schlaf-phasen')), findsOneWidget);
    });

    testWidgets('darüber steht ein eigener Kasten, nicht der von #131', (
      tester,
    ) async {
      await mitEintrag(
        tester,
        beginnMinuten: 19 * 60,
        endeMinuten: 21 * 60 + 30,
      );

      expect(
        find.byKey(const Key('schlaf-ergaenzung-hinweis')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('schlaf-von-hand-hinweis')), findsNothing);
    });

    testWidgets('und bei einer Korrektur bleibt es beim Kasten von #131 — ohne '
        'Hypnogramm', (tester) async {
      await mitEintrag(
        tester,
        beginnMinuten: 23 * 60 + 10,
        endeMinuten: 6 * 60 + 15,
        schlafMinuten: 425,
      );

      expect(find.byKey(const Key('schlaf-von-hand-hinweis')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-ergaenzung-hinweis')), findsNothing);
      expect(find.byKey(const Key('schlaf-phasen')), findsNothing);
    });
  });
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
