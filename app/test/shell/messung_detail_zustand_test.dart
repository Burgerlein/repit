import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/messung_detail_zustand.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für den **Zustand** des Verlaufsschirms je Messwert (#202 Teil C,
/// Schirm #203) — `lib/shell/messung_detail_zustand.dart`. **Ein** Schirm
/// für vier Werte (Gewicht, Körperfett, fettfreie Masse, Ruhepuls); welcher
/// gemeint ist, trägt [MessArt] als Parameter, wie `VerlaufArt` bei den
/// Erholungs-Verläufen. Die Oberfläche bekommt eine eigene Testdatei.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Teil C, Abschnitt „Der Schnitt — präzisiert am 02.11.2026", und der
/// Entwurf `docs/screens/screens/messung-detail.js`. Vorbild für Schnitt
/// und Stil ist `verlauf_zustand.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/messung_detail_zustand.dart`)
///
/// ```dart
/// /// Die Stufen dieses Schirms: **W M 6M J**, Startstufe `W`.
/// const List<DiagrammStufe> messungsStufen = [...];
///
/// @immutable
/// class MessungDetailZustand {
///   const MessungDetailZustand({
///     required MessArt art,
///     required List<MeasurementPoint> reihe,
///     required double? aktuell,
///     required double? median30,
///     required ({double von, double bis})? spanne7,
///     required double? veraenderung6Wochen,
///     required double? anteilAmGewicht,
///     required double? navyProzent,
///   });
/// }
///
/// MessungDetailZustand messungDetailAus({
///   required MessArt art,
///   required List<MeasurementPoint> reihe,
///   required double? juengstesGewicht,
///   required DateTime jetzt,
/// });
///
/// /// Der Lade-Provider: liefert den **nackten** Zustand, darf `.future`
/// /// und darf scheitern. Name und Bauart sind **nicht** festgelegt —
/// /// kein Fall unten nennt ihn.
/// final /* … */ = FutureProvider.family<MessungDetailZustand, MessArt>(...);
///
/// /// Der **öffentliche** Provider, und der einzige, den die View liest.
/// final messungDetailProvider =
///     Provider.family<Messwert<MessungDetailZustand>, MessArt>(...);
/// ```
///
/// `MessungDetailZustand` trägt `==` und `hashCode` — er wird von einem
/// Provider gehalten und seine Reihe in ein Diagramm gereicht; geprüft über
/// ein `Set`, nicht nur über `==`.
///
/// ## Zwei Provider, und warum nicht einer
///
/// Ein einzelner `FutureProvider.family<Messwert<…>, MessArt>` wäre der
/// kürzere Weg und ist der falsche: Die View müsste ihn als
/// `ref.watch(…).value ?? const NochNie<…>()` lesen, und damit stünde ein
/// `AsyncValue`-Ausdruck in der Widget-Schicht. **Das verbietet Hausregel 1**
/// (`CLAUDE.md`): „Die Umsetzung `AsyncValue<T>` → `Messwert<T>` steht in
/// **genau einer** Funktion: `alsMesswert`." Eine Stelle, an der man es
/// richtig machen muss, statt acht, an denen man es falsch machen kann — das
/// war Fehler `01`.
///
/// Deshalb derselbe Schnitt wie bei `koerperWerteProvider`: Laden unten,
/// Übersetzen genau einmal in der Mitte, und oben sieht die View nur noch
/// `Messwert<MessungDetailZustand>`. Dass der öffentliche Provider **kein**
/// `.future` mehr hat, ist der Beweis und keine Unbequemlichkeit — die Fälle
/// unten lesen ihn deshalb über `listen` statt über `await`, genau wie die
/// View ihn lesen wird.
///
/// **Die Bauart des Lade-Providers ist nicht festgelegt**, nur sein
/// Ergebnis — dieselbe Zurückhaltung wie in `health_provider_test.dart`
/// gegenüber der Notifier-Klasse. Kein Fall unten greift auf ihn zu.
///
/// ## Was `istLeer` auf diesem Schirm heißt
///
/// **Leer ist, wenn die Reihe keinen einzigen Punkt trägt.** Dann gibt es
/// weder Kurve noch Einordnung: `aktuell`, `median30`, `spanne7`,
/// `veraenderung6Wochen` und `anteilAmGewicht` hängen alle an der Reihe und
/// sind samt und sonders `null`. Genau dafür gibt es `LeerNachLauf` — der
/// einzige Zustand, der einen Grund anzeigen darf, und der Schirm nennt dort
/// beide Möglichkeiten („keine Waagenwerte" **und** „kann an der Freigabe
/// liegen"), weil Apple den Lesestatus nicht verrät (`CLAUDE.md`).
///
/// **`navyProzent` löst dabei nichts aus.** Es ist immer `null`, und ein
/// `istLeer`, das „alle Felder sind `null`" prüfte, wäre damit für immer
/// wahr.
///
/// **Das weicht bewusst von `verlauf_zustand.dart` ab**, wo eine leere Reihe
/// *kein* Leerzustand ist — und die Abweichung hat einen Grund: Dort trägt
/// **ein** Zustand alle vier Werte, und „der Lauf fand nichts" wäre eine
/// Aussage über den ganzen Lauf, die nicht stimmt, solange drei andere Werte
/// dastehen. Hier ist der Provider **je Messart** gefächert; sein Lauf ist
/// die Reihe dieses einen Werts. Ist sie leer, hat der Lauf für diesen
/// Schirm tatsächlich nichts gefunden, und der Schirm darf das sagen.
/// *(Festlegung vom 02.11.2026; sie ersetzt die frühere Fassung dieser
/// Datei, die den Vorbildfall aus `verlauf_zustand.dart` übernommen hatte.)*
///
/// ## Warum dieser Schnitt
///
/// - **Der Zustand hält die Rohreihe und verdichtet nicht.** `Zeitdiagramm`
///   bekommt in `verlauf_view.dart:118–126` ebenfalls die Rohreihe und
///   rechnet Verdichtung, Startfenster und Kopfzahl selbst
///   (`Fensterstand.aus`, `lib/design/zeitdiagramm_fenster.dart`). Ein
///   Zustand, der dieselben Zahlen ein zweites Mal rechnet, ist eine
///   Verabredung zwischen zwei Fassungen — und die bricht beim nächsten
///   Umbau. Deshalb stehen hier **weder** `punkte` **noch** `kopfzahl`
///   **noch** `fenster`. Dass ab `6M` das **Mittel** gilt und nicht das
///   Maximum, bleibt richtig; geprüft wird es dort, wo es wohnt
///   (`chart_buckets`), nicht hier (Entscheidung vom 02.11.2026).
/// - **Deshalb ist der Familienschlüssel [MessArt] allein**, nicht
///   `(Art, Stufe)`: Ohne eigene Verdichtung gibt es nichts mehr, das je
///   Stufe verschieden wäre. Die Stufe lebt im Bauteil, so wie bei den
///   Erholungs-Verläufen.
/// - **`messungsStufen` bleibt trotzdem hier**, wie `verlaufsStufen` in
///   `verlauf_zustand.dart`: Welche Stufen ein Schirm anbietet, ist seine
///   Entscheidung, und er reicht die Liste ans Bauteil weiter.
/// - **Die Reihe trägt [MeasurementPoint]**, nicht `({DateTime tag, double
///   wert})`: So kommt sie aus `messReihe` heraus und so geht sie in
///   `BodyTrend` hinein — und so heißt sie schon in
///   `koerper_zustand.dart`. Die eine Umsetzung in die Form, die
///   `Zeitdiagramm` erwartet, macht die View.
/// - **Die Reihe kommt über `messReihe` aus dem Cache**, nicht aus
///   `dailyMetricsProvider`: Ein Jahresdiagramm braucht mehr als das
///   Rechenfenster, und `messReihe` filtert in SQL (Spec, Teil C;
///   `CLAUDE.md` Hausregel 2).
/// - **Keine Nutzertexte.** Der Zustand liefert Zahlen und Zeitpunkte; die
///   Einordnungszeilen, der Zielkorridor als Satz und die Fußnote stehen in
///   der View. Deshalb prüft diese Datei nirgends eine Beschriftung.
///
/// Was bleibt, ist genau das, was das Diagramm-Bauteil **nicht** kann:
/// `aktuell`, `median30`, `spanne7`, `veraenderung6Wochen`,
/// `anteilAmGewicht`, `navyProzent` — und die Reihe selbst.
///
/// ## `navyProzent` ist immer `null`, und das ist kein Fehler
///
/// Körperfett nach Navy braucht Taille und Hals vom Maßband; Umfänge gibt es
/// im Neubau nicht (#88). Das Feld steht trotzdem da: Eine Zeile, die später
/// nachgerüstet werden muss, wäre die schlechtere Lösung (Spec, Teil C). Die
/// View macht daraus „kein Maßband-Wert" — eine feste Zeile, keine Lücke.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Verdichtung, Blättern, Ablesen und Kopfzeile.** Sie liegen in
///   `ChartBuckets`, `diagramm_zeitraum.dart` und `zeitdiagramm_fenster.dart`
///   und haben dort ihre Tests.
/// - **Der `gelaufen`-Zeitstempel von `LeerNachLauf`.** Ob dort der Stand
///   des zugrunde liegenden `Bekannt` steht oder die Uhr, entscheidet die
///   Spec nicht; eine erfundene Erwartung wäre schlimmer als keine.
/// - **Der Zielkorridor (+0,10 bis +0,25 kg pro Woche).** Er hängt an keiner
///   Messung und steht auch ohne Werte da — eine Konstante der View, keine
///   Rechnung dieses Zustands.
/// - **Welche Einordnungszeilen welcher Wert zeigt.** Dass beim Ruhepuls
///   `median30` steht und bei der fettfreien Masse `anteilAmGewicht`, prüft
///   diese Datei an den Feldern; welche Zeile daraus wird, ist Sache der
///   View.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie in
  // `verlauf_zustand_test.dart` und `koerper_zustand_test.dart`.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  DateTime tagVor(int tage) => BerlinCalendar.addDays(heute, -tage);

  MeasurementPoint punktVor(int tage, double wert) =>
      MeasurementPoint(date: tagVor(tage), value: wert);

  MessungDetailZustand detail({
    MessArt art = MessArt.gewicht,
    List<MeasurementPoint> reihe = const [],
    double? juengstesGewicht,
  }) => messungDetailAus(
    art: art,
    reihe: reihe,
    juengstesGewicht: juengstesGewicht,
    jetzt: jetzt,
  );

  // ─────────────────────────────────────────────────────────────────────

  group('Die Stufen', () {
    test('W M 6M J — und kein T', () {
      expect(messungsStufen, const [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
        DiagrammStufe.jahr,
      ]);
      expect(
        messungsStufen,
        hasLength(4),
        reason:
            'Man wiegt sich nicht stündlich (Spec, Teil D) — `DiagrammStufe` '
            'kennt deshalb gar kein `T`',
      );
    });

    test('die Startstufe ist damit W (#7)', () {
      expect(startStufe(messungsStufen), DiagrammStufe.woche);
    });

    test('der Zustand weiß, zu welchem Wert er gehört', () {
      for (final art in MessArt.values) {
        expect(detail(art: art, reihe: [punktVor(0, 1)]).art, art);
      }
    });
  });

  group('Die Reihe', () {
    test('kommt roh durch — ein Punkt je Messung, aufsteigend', () {
      final zustand = detail(
        reihe: [punktVor(2, 80.0), punktVor(1, 81.0), punktVor(0, 82.4)],
      );

      expect(zustand.reihe.map((p) => p.value), [80.0, 81.0, 82.4]);
      expect(zustand.reihe.first.date, tagVor(2));
      expect(zustand.reihe.last.date, tagVor(0));
    });

    test(
      'der Zustand verdichtet **nicht** — zwei Messungen in einem Monat '
      'bleiben zwei Punkte',
      () {
        final zustand = detail(
          reihe: [punktVor(5, 10.0), punktVor(1, 20.0)],
        );

        expect(
          zustand.reihe,
          hasLength(2),
          reason:
              'Verdichtung und Kopfzahl rechnet `Zeitdiagramm` selbst '
              '(`Fensterstand.aus`). Zwei Fassungen derselben Zahl, die '
              '„exakt übereinstimmen müssen", brechen beim nächsten Umbau '
              '— Entscheidung vom 02.11.2026',
        );
      },
    );

    test('Lücken bleiben Lücken: zwischen zwei Messungen wird nichts '
        'aufgefüllt', () {
      final zustand = detail(reihe: [punktVor(30, 78.0), punktVor(0, 82.4)]);

      expect(zustand.reihe, hasLength(2));
      expect(
        zustand.reihe.map((p) => p.value),
        isNot(contains(0)),
        reason:
            'ein Tag ohne Messung ist kein Tag mit 0 kg — `messReihe` lässt '
            'ihn schon im `WHERE` heraus',
      );
    });

    test('die Punkte tragen Berliner Tagesgrenzen als UTC-Zeitpunkte', () {
      final zustand = detail(reihe: [punktVor(0, 82.4)]);
      expect(zustand.reihe.single.date, tagVor(0));
      expect(zustand.reihe.single.date.isUtc, isTrue);
    });
  });

  group('Die Einordnung', () {
    test('„Aktuell" ist der jüngste Wert, nicht der größte', () {
      final zustand = detail(
        reihe: [punktVor(2, 95.0), punktVor(1, 90.0), punktVor(0, 82.4)],
      );
      expect(zustand.aktuell, 82.4);
    });

    test('„Median 30 Tage" gibt es nur beim Ruhepuls', () {
      final reihe = [for (var t = 6; t >= 0; t--) punktVor(t, 50.0 + t)];

      final puls = detail(art: MessArt.ruhepuls, reihe: reihe);
      // Die Erwartung kommt aus dem Kern selbst, nicht aus einer zweiten
      // Medianformel hier.
      expect(
        puls.median30,
        HealthMedian.value([for (final punkt in reihe) punkt.value]),
      );
      expect(puls.median30, isNotNull);

      for (final art in const [
        MessArt.gewicht,
        MessArt.koerperfett,
        MessArt.fettfreieMasse,
      ]) {
        expect(
          detail(art: art, reihe: reihe).median30,
          isNull,
          reason:
              '$art: Der Entwurf zeigt den Median nur in der Ruhepuls-Spalte '
              '(Spec, Teil D) — ein Feld, das dort niemand anzeigt, wäre '
              'gerechnete Arbeit ohne Abnehmer',
        );
      }
    });

    test('ohne genug Werte gibt es keinen Median, sondern `null`', () {
      // `HealthMedian` verlangt mindestens fünf Werte.
      expect(
        detail(
          art: MessArt.ruhepuls,
          reihe: [punktVor(1, 55.0), punktVor(0, 57.0)],
        ).median30,
        isNull,
        reason: 'eine Schwelle aus zwei Werten wäre eine Behauptung',
      );
    });

    test('„Spanne 7 Tage" meint die jüngsten sieben **Werte**', () {
      final zustand = detail(
        reihe: [
          // Acht Werte: Der älteste trägt den Ausreißer und darf nicht in
          // der Spanne stehen — dieselbe Lesart wie in
          // `verlauf_zustand.dart`.
          punktVor(10, 200.0),
          for (var t = 6; t >= 1; t--) punktVor(t, 81.0),
          punktVor(0, 80.0),
        ],
      );

      expect(zustand.spanne7, isNotNull);
      expect(zustand.spanne7!.von, 80.0);
      expect(zustand.spanne7!.bis, 81.0);
    });

    test('ein einziger Wert gibt eine Spanne von sich zu sich', () {
      final zustand = detail(reihe: [punktVor(0, 82.4)]);
      expect(zustand.spanne7, isNotNull);
      expect(zustand.spanne7!.von, 82.4);
      expect(zustand.spanne7!.bis, 82.4);
    });

    test('„Veränderung 6 Wochen" ist jüngster minus ältester im Fenster', () {
      expect(
        detail(
          reihe: [
            punktVor(40, 80.0),
            punktVor(20, 83.0),
            punktVor(0, 82.0),
          ],
        ).veraenderung6Wochen,
        closeTo(2.0, 1e-9),
      );
    });

    test('`null` unter zwei Werten, und Älteres zählt nicht mit', () {
      expect(detail(reihe: [punktVor(0, 82.4)]).veraenderung6Wochen, isNull);
      expect(
        detail(
          reihe: [punktVor(70, 60.0), punktVor(0, 82.4)],
        ).veraenderung6Wochen,
        isNull,
        reason:
            'zehn Wochen alt liegt außerhalb des 6-Wochen-Fensters — im '
            'Fenster bleibt einer übrig',
      );
      expect(
        detail(
          reihe: [punktVor(42, 80.0), punktVor(0, 82.4)],
        ).veraenderung6Wochen,
        closeTo(2.4, 1e-9),
        reason: 'ein Punkt genau auf der Kante zählt mit (`>=`)',
      );
    });

    test('„Anteil am Gewicht" gibt es nur bei der fettfreien Masse', () {
      final reihe = [punktVor(0, 62.1)];

      final fettfrei = detail(
        art: MessArt.fettfreieMasse,
        reihe: reihe,
        juengstesGewicht: 82.4,
      );
      expect(
        fettfrei.anteilAmGewicht,
        closeTo(62.1 / 82.4, 1e-9),
        reason:
            'ein Anteil, keine Prozentzahl — ein Feld, das Prozent meint, '
            'heißt in diesem Zustand auch so (`navyProzent`). Die Prozentzahl '
            'macht die View',
      );

      for (final art in const [
        MessArt.gewicht,
        MessArt.koerperfett,
        MessArt.ruhepuls,
      ]) {
        expect(
          detail(art: art, reihe: reihe, juengstesGewicht: 82.4)
              .anteilAmGewicht,
          isNull,
          reason: '$art: „Anteil am Gewicht" steht nur in der Muskel-Spalte',
        );
      }
    });

    test('ohne Gewicht kein Anteil — nicht 0 und nicht 100 %', () {
      expect(
        detail(
          art: MessArt.fettfreieMasse,
          reihe: [punktVor(0, 62.1)],
        ).anteilAmGewicht,
        isNull,
      );
    });

    test('ohne Messwert steht keine Zahl da — und keine 0', () {
      for (final art in MessArt.values) {
        final leer = detail(art: art, juengstesGewicht: 82.4);

        expect(leer.reihe, isEmpty, reason: '$art');
        expect(leer.aktuell, isNull, reason: '$art');
        expect(
          leer.aktuell,
          isNot(0),
          reason:
              '$art: eine 0 stünde für eine Messung, die es nicht gab — das '
              'ist Fehler `01`',
        );
        expect(leer.spanne7, isNull, reason: '$art');
        expect(leer.veraenderung6Wochen, isNull, reason: '$art');
        expect(leer.median30, isNull, reason: '$art');
        expect(leer.anteilAmGewicht, isNull, reason: '$art');
        expect(
          leer.art,
          art,
          reason:
              'Leiste, Diagrammfläche und Einordnung bleiben stehen, nur die '
              'Zahlen fehlen (Spec, Teil D)',
        );
      }
    });
  });

  group('`navyProzent` ist immer `null`', () {
    test('bei allen vier Werten, mit und ohne Messreihe', () {
      for (final art in MessArt.values) {
        expect(
          detail(art: art, reihe: [punktVor(0, 22.5)]).navyProzent,
          isNull,
          reason: '$art: Umfänge gibt es im Neubau nicht (#88)',
        );
        expect(detail(art: art).navyProzent, isNull, reason: '$art, leer');
      }
    });
  });

  group('Gleichheit — über ein `Set`, nicht nur über `==`', () {
    List<MeasurementPoint> reihe(double juengster) => [
      punktVor(2, 80.0),
      punktVor(1, 81.0),
      punktVor(0, juengster),
    ];

    test('zwei gleich gerechnete Zustände sind einer', () {
      final a = detail(reihe: reihe(82.4));
      final b = detail(reihe: reihe(82.4));

      expect(a, b);
      expect(
        {a, b},
        hasLength(1),
        reason:
            'Ohne Wertgleichheit wäre jede neu gelesene Reihe ungleich der '
            'vorigen und das Diagramm liefe bei jedem Bild neu — das wäre '
            '`03`, wortgleich im neuen Code',
      );
    });

    test('ein anderer Wert oder eine andere Art nicht', () {
      final a = detail(reihe: reihe(82.4));
      expect({a, detail(reihe: reihe(83.0))}, hasLength(2));
      expect(
        {a, detail(art: MessArt.koerperfett, reihe: reihe(82.4))},
        hasLength(2),
      );
    });

    test('auch ein Unterschied, der nur in der Reihe steht, zählt', () {
      // Der älteste Punkt liegt **außerhalb** des 6-Wochen-Fensters: Er
      // ändert weder `aktuell` noch `veraenderung6Wochen` noch `spanne7`,
      // steht aber in der Reihe. Ohne `listEquals` in `==` fiele das durch.
      List<MeasurementPoint> mitAltem(double alt) => [
        punktVor(70, alt),
        punktVor(1, 81.0),
        punktVor(0, 82.4),
      ];

      final a = detail(reihe: mitAltem(60.0));
      final b = detail(reihe: mitAltem(61.0));

      expect(a.aktuell, b.aktuell);
      expect(a.veraenderung6Wochen, b.veraenderung6Wochen);
      expect(
        {a, b},
        hasLength(2),
        reason:
            'die Reihen unterscheiden sich — `==` muss die Liste Element '
            'für Element vergleichen, nicht ihre Identität',
      );
    });
  });

  group('Der Provider', () {
    /// Ein Behälter mit echtem In-Memory-Cache. Der Kanal liefert
    /// [antwort]; der Lauf von `dailyMetricsProvider` schreibt sie in den
    /// Cache, aus dem `messReihe` sie danach liest — derselbe Weg wie auf
    /// dem Gerät.
    ProviderContainer behaelterMit({
      required AppCache db,
      required FutureOr<List<DailyMetrics>> Function() antwort,
      DateTime? uhr,
    }) {
      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          healthProvider.overrideWithValue(
            _FakeHealthReading(dailyMetricsAntwort: antwort),
          ),
          clockProvider.overrideWithValue(() => uhr ?? jetzt),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    ProviderContainer behaelter(List<DailyMetrics> antwort) {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      return behaelterMit(db: db, antwort: () async => antwort);
    }

    DailyMetrics tageswert(
      int tageZurueck, {
      double? gewicht,
      double? fettfrei,
      int? ruhepuls,
    }) => DailyMetrics(
      tag: BerlinCalendar.dayKey(tagVor(tageZurueck)),
      restingHR: ruhepuls,
      weightKg: gewicht,
      leanKg: fettfrei,
    );

    /// Wie die View liest: über `listen`, **nicht** über `await`. Der
    /// öffentliche Provider trägt kein `.future` — und genau das ist der
    /// Beweis für Hausregel 1. Zurück kommt der zuletzt ausgegebene Stand.
    Future<Messwert<MessungDetailZustand>> gelesen(
      ProviderContainer container,
      MessArt art,
    ) async {
      final beobachtet = <Messwert<MessungDetailZustand>>[];
      container.listen(
        messungDetailProvider(art),
        (_, neu) => beobachtet.add(neu),
        fireImmediately: true,
      );
      await pumpEventQueue();
      return beobachtet.last;
    }

    test(
      'der öffentliche Provider trägt den `Messwert` selbst — die View sieht '
      'nie ein `AsyncValue`',
      () {
        final container = behaelter([tageswert(0, gewicht: 82.4)]);

        // Statisch geprüft, nicht nur zur Laufzeit: Wäre `messungDetailProvider`
        // ein `FutureProvider`, käme hier ein `AsyncValue<Messwert<…>>` heraus
        // und diese Zuweisung übersetzte nicht. Dann müsste die View
        // `ref.watch(…).value ?? const NochNie<…>()` schreiben — ein
        // `AsyncValue`-Ausdruck in der Widget-Schicht, und das verbietet
        // Hausregel 1 (`CLAUDE.md`): Die Übersetzung steht in **genau einer**
        // Funktion, `alsMesswert`.
        final Messwert<MessungDetailZustand> zustand = container.read(
          messungDetailProvider(MessArt.gewicht),
        );

        expect(zustand, isA<Messwert<MessungDetailZustand>>());
      },
    );

    test('solange geladen wird, steht der Platzhalter und kein Grund '
        '(`01`)', () {
      final container = behaelter([tageswert(0, gewicht: 82.4)]);

      // Der erste, synchrone Blick auf den Schirm: Der Lade-Provider läuft
      // noch, nichts ist bekannt.
      final sofort = container.read(messungDetailProvider(MessArt.gewicht));

      expect(sofort, isA<NochNie<MessungDetailZustand>>());
      expect(
        sofort,
        isNot(isA<LeerNachLauf<MessungDetailZustand>>()),
        reason:
            'Während des Ladens steht nie ein „keine Daten"-Grund — das ist '
            'Fehler `01`, und `LeerNachLauf` ist der einzige Zustand, der '
            'einen Grund anzeigen darf',
      );
      expect(sofort, isNot(isA<Fehlgeschlagen<MessungDetailZustand>>()));
    });

    test('liest die Reihe aus dem Cache', () async {
      final container = behaelter([
        tageswert(2, gewicht: 80.0),
        tageswert(1, gewicht: 81.0),
        tageswert(0, gewicht: 82.4),
      ]);

      final zustand = await gelesen(container, MessArt.gewicht);

      expect(zustand, isA<Bekannt<MessungDetailZustand>>());
      final wert = (zustand as Bekannt<MessungDetailZustand>).wert;
      expect(wert.aktuell, 82.4);
      expect(wert.reihe, hasLength(3));
    });

    test('die Reihe reicht mindestens ein Jahr zurück, nicht nur über das '
        'Rechenfenster', () async {
      final container = behaelter([
        tageswert(300, gewicht: 78.0),
        tageswert(0, gewicht: 82.4),
      ]);

      final zustand = await gelesen(container, MessArt.gewicht);

      final wert = (zustand as Bekannt<MessungDetailZustand>).wert;
      expect(
        wert.reihe.map((p) => p.date),
        contains(tagVor(300)),
        reason:
            'Das Rechenfenster sind 30 Tage; die Jahresstufe des Diagramms '
            'braucht mehr — deshalb `messReihe` statt '
            '`dailyMetricsProvider` (Spec, Teil C). Welche Stufe gerade '
            'gewählt ist, weiß der Zustand nicht und darf er nicht wissen: '
            'Sie wechselt im Bauteil, ohne dass neu geladen wird',
      );
    });

    test('der Anteil am Gewicht kommt aus derselben Datenlage', () async {
      final container = behaelter([
        tageswert(1, gewicht: 82.0, fettfrei: 61.0),
        tageswert(0, gewicht: 82.4, fettfrei: 62.1),
      ]);

      final zustand = await gelesen(container, MessArt.fettfreieMasse);

      final wert = (zustand as Bekannt<MessungDetailZustand>).wert;
      expect(wert.anteilAmGewicht, closeTo(62.1 / 82.4, 1e-9));
    });

    test('eine Reihe ohne einen einzigen Punkt ist `LeerNachLauf`', () async {
      // Ein fertiger Lauf, der gar nichts brachte.
      expect(
        await gelesen(behaelter(const []), MessArt.gewicht),
        isA<LeerNachLauf<MessungDetailZustand>>(),
      );

      // Und derselbe Fall je Messart: Gewicht und Ruhepuls stehen da,
      // Körperfett nicht. Für **diesen** Schirm hat der Lauf nichts
      // gefunden — anders als in `verlauf_zustand.dart`, wo ein Zustand
      // alle vier Werte trägt; die Begründung steht im Dateikopf.
      final container = behaelter([tageswert(0, gewicht: 82.4, ruhepuls: 57)]);
      expect(
        await gelesen(container, MessArt.koerperfett),
        isA<LeerNachLauf<MessungDetailZustand>>(),
        reason:
            'Ohne Punkt gibt es weder Kurve noch Einordnung — jede Zahl des '
            'Schirms hängt an der Reihe. Der Schirm darf dann sagen, dass '
            'nichts da ist, und dass es auch an der Freigabe liegen kann',
      );
      expect(
        await gelesen(container, MessArt.gewicht),
        isA<Bekannt<MessungDetailZustand>>(),
        reason:
            'und der Wert daneben bleibt davon unberührt — ein fehlender '
            'Wert schaltet nur seinen eigenen Schirm ab',
      );
    });

    test('ein gescheiterter Lauf ohne Werte ist `Fehlgeschlagen`, nicht '
        'leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final container = behaelterMit(
        db: db,
        antwort: () async => throw StateError('kaputt'),
      );

      final zustand = await gelesen(container, MessArt.gewicht);

      expect(
        zustand,
        isA<Fehlgeschlagen<MessungDetailZustand>>(),
        reason:
            '„Lauf gescheitert" ist nicht „Lauf fertig, nichts gefunden" '
            '(`messwert.dart`). Ein gescheiterter Lauf, der als '
            '`LeerNachLauf` erschiene, behauptete eine Auskunft, die der '
            'Lauf nie gegeben hat',
      );
    });

    test('ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg',
        () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // Erster Lauf: füllt den Cache.
      final ersterContainer = behaelterMit(
        db: db,
        antwort: () async => [tageswert(0, gewicht: 82.4)],
      );
      await ersterContainer.read(dailyMetricsProvider.future);

      // Kaltstart, und diesmal scheitert der Kanal. Die Reihe steht
      // trotzdem im Cache.
      final zweiterContainer = behaelterMit(
        db: db,
        antwort: () async => throw StateError('kaputt'),
        uhr: jetzt.add(const Duration(minutes: 5)),
      );

      final zustand = await gelesen(zweiterContainer, MessArt.gewicht);

      expect(
        zustand,
        isA<Bekannt<MessungDetailZustand>>(),
        reason:
            'Tims Beschwerde ist, dass Werte verschwinden: `Fehlgeschlagen` '
            'gilt nur, wenn nichts zwischengespeichert ist (`CLAUDE.md`)',
      );
      expect(
        (zustand as Bekannt<MessungDetailZustand>).wert.aktuell,
        82.4,
      );
    });

    test('je Messart ein eigener, gehaltener Eintrag', () async {
      final container = behaelter([tageswert(0, gewicht: 82.4, ruhepuls: 57)]);

      final gewicht = await gelesen(container, MessArt.gewicht);
      final puls = await gelesen(container, MessArt.ruhepuls);

      expect((gewicht as Bekannt<MessungDetailZustand>).wert.art,
          MessArt.gewicht);
      expect(gewicht.wert.aktuell, 82.4);
      expect((puls as Bekannt<MessungDetailZustand>).wert.art,
          MessArt.ruhepuls);
      expect(puls.wert.aktuell, 57);

      expect(
        identical(
          container.read(messungDetailProvider(MessArt.gewicht)),
          container.read(messungDetailProvider(MessArt.gewicht)),
        ),
        isTrue,
        reason: 'gehalten, nicht bei jedem Zugriff gerechnet — Hausregel 2',
      );
    });
  });
}

/// Steuerbarer Ableger der echten Quelle — wörtlich wie in
/// `test/health/health_provider_test.dart`.
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading({
    required FutureOr<List<DailyMetrics>> Function() dailyMetricsAntwort,
  }) : _dailyMetricsAntwort = dailyMetricsAntwort;

  final FutureOr<List<DailyMetrics>> Function() _dailyMetricsAntwort;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => await _dailyMetricsAntwort();
}
