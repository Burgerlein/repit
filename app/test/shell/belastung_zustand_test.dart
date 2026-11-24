import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/belastung_zustand.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/erholung_zustand.dart';

/// Tests für den **Zustand** des Belastungs-Schirms (#94) —
/// `lib/shell/belastung_zustand.dart`. Die Oberfläche liegt in
/// `belastung_view_test.dart`, die Diagrammrechnung in
/// `diagramm_zeitraum_test.dart`.
///
/// Derselbe Schnitt wie bei `erholung_zustand_test.dart` /
/// `erholung_view_test.dart` und aus demselben Grund.
///
/// ## Festgelegte öffentliche API (`lib/shell/belastung_zustand.dart`)
///
/// ```dart
/// /// Die Stufen dieses Schirms: **W M 6M, kein J.**
/// const List<DiagrammStufe> belastungsStufen = [
///   DiagrammStufe.woche, DiagrammStufe.monat, DiagrammStufe.halbjahr,
/// ];
///
/// /// Das Tagesziel, aus dem sich das Wochenziel rechnet.
/// @immutable
/// class BelastungDaten {
///   const BelastungDaten({
///     required double? wochenminuten,
///     required double wochenziel,
///     required double? anteil,
///     required double? vorwochenminuten,
///     required double? veraenderung,
///     required List<({DateTime tag, double wert})> tagesminuten,
///     required int signale,
///   });
/// }
///
/// @immutable
/// class BelastungZustand {
///   const BelastungZustand({
///     required Messwert<BelastungDaten> daten,
///     required Ziele ziele,
///   });
/// }
///
/// BelastungZustand belastungZustandAus({required ErholungZustand erholung});
///
/// final belastungProvider = Provider<BelastungZustand>(...);
/// ```
///
/// ## Warum dieser Schnitt
///
/// - **Der Schirm leitet aus `erholungProvider` ab, statt Health ein zweites
///   Mal zu fragen.** Belastung und Erholung stehen nebeneinander, weil erst
///   beide zusammen etwas sagen: Der Einordnungssatz zählt die Warnsignale,
///   und die hängen an Schlaf, Ruhepuls, HRV **und** Atemfrequenz — also an
///   beiden Health-Hälften. Ein zweiter Ladeweg wäre eine zweite Stelle, an
///   der `docs/todo/01` entstehen kann; ein abgeleiteter Provider rechnet
///   neu, wenn sich seine Abhängigkeit ändert, und sonst nie (Hausregel 2).
///   **Der Schirm lädt trotzdem selbst**: `erholungProvider` beobachtet
///   `dailyMetricsProvider` und `sleepProvider`, und wer ihn liest, stößt sie
///   an — niemand muss vorher auf Erholung gewesen sein.
/// - **Die Reihe ist deshalb auf das Rechenfenster beschränkt** (30 Tage,
///   `rechenfensterProvider`). Genau wie in Swift, wo `LoadDetailView` aus
///   `snapshot.days` zeichnet. `6M` ist damit heute dünn besetzt — und
///   genau deshalb hat dieser Schirm **kein `J`**: Ein Jahresfenster wäre
///   leer (`LoadDetailView.swift:66–68`, `DataWindow.swift`).
/// - **`anteil` und `veraenderung` sind Felder, keine berechneten
///   Eigenschaften.** Eine berechnete Eigenschaft rechnet je Bild; das war
///   `docs/todo/03`. Hier wird einmal gerechnet und gehalten.
/// - **Das Wochenziel steht als Feld in den Daten, nicht nur in `ziele`.**
///   Damit kann der Schirm die Zahl nicht aus einer Konstante nehmen: Sie
///   kommt an genau einer Stelle herein, und `Ziele.vorbelegung` ist die
///   einzige Stelle im Quelltext, die „210" kennt.
///
/// ## Am 02.11.2026 nachgezogen (#193, Stufe 4)
///
/// Ruhepuls, HRV und Atemfrequenz kommen seit Stufe 4 aus dem Nachtfenster
/// statt aus `DailyMetrics` — Tims Entscheidung vom 02.11.2026, begründet
/// im Kopf von `erholung_nachtwerte_test.dart`. Diese Datei prüft nicht,
/// **woher** die drei Werte kommen; sie braucht sie nur als Vorlage.
/// Deshalb setzt die Hülle den `RecoverySnapshot` seither selbst ein
/// (`schnappschussAus`), statt ihn über `DailyMetrics` erzeugen zu lassen.
/// Die **Zustandsart** kommt weiter aus `erholungZustandAus`.
///
/// **Was damit hier nicht mehr mitgeprüft wird:** dass die Werte dieses
/// Schirms tatsächlich durch `erholungZustandAus` hindurchlaufen. Das
/// prüft `erholung_nachtwerte_test.dart` — und zwar genauer, als es hier
/// je geschah.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Wortlaut.** Wo ein Text eine Regel trägt, prüft die Regel der
///   View-Test.
/// - **`==`/`hashCode` auf `BelastungDaten`.** `RecoverySnapshot` hat laut
///   eigenem Vertrag keine Wertgleichheit; eine darüber wäre eine Zusage,
///   die der Code nicht einlöst. Geprüft wird statt dessen, dass der Zustand
///   **gehalten** wird.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? atem = 13,
    double? trainingsminuten = 20,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atem,
    exerciseMinutes: trainingsminuten,
  );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, tag, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: const [],
    );
  }

  /// Die laufende Woche beginnt am Montag, 12.10. — sie besteht also aus
  /// genau einem Tag, dem heutigen. Die Vorwoche ist Mo 05.10. bis So
  /// 11.10.
  List<DailyMetrics> tage({
    double? heute = 60,
    double? vorwoche = 20,
    double? hrv = 60,
  }) => [
    for (var t = 5; t <= 11; t++)
      tagwert(t, hrv: hrv, trainingsminuten: vorwoche),
    tagwert(12, hrv: hrv, trainingsminuten: heute),
  ];

  List<SleepNight> naechte({double heuteStunden = 7}) => [
    for (var t = 5; t <= 11; t++) nachtVon(t),
    nachtVon(12, stunden: heuteStunden),
  ];

  /// Der Schnappschuss aus den Vorlagen dieser Datei — **mit den drei
  /// Erholungswerten, die der Fall vorgibt.**
  ///
  /// Seit #193, Stufe 4 (02.11.2026) kommen Ruhepuls, HRV und Atemfrequenz
  /// aus dem Nachtfenster und nicht mehr aus `DailyMetrics`;
  /// `erholungZustandAus` nimmt sie als eigenen Parameter entgegen. Diese
  /// Datei prüft aber nicht, **woher** die drei Werte stammen — das prüft
  /// `erholung_nachtwerte_test.dart`. Hier sind sie nur Vorlage, und
  /// deshalb setzt die Hülle den Schnappschuss selbst ein, statt ihn über
  /// den Umweg über `DailyMetrics` zu erzeugen.
  RecoverySnapshot schnappschussAus(
    Messwert<List<DailyMetrics>> tageswerte,
    Messwert<List<SleepNight>> schlaf,
    Ziele ziele,
  ) {
    final tage = tageswerte is Bekannt<List<DailyMetrics>>
        ? tageswerte.wert
        : const <DailyMetrics>[];
    final naechte = schlaf is Bekannt<List<SleepNight>>
        ? schlaf.wert
        : const <SleepNight>[];
    return RecoverySnapshot.make(
      days: [
        for (final tag in tage)
          RecoveryDay(
            date: datumAusTag(tag.tag),
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
            exerciseMinutes: tag.exerciseMinutes,
          ),
      ],
      nights: [for (final nacht in naechte) alsRecoveryNacht(nacht)],
      today: jetzt,
      sleepGoalHours: ziele.schlafzielMinuten / Duration.minutesPerHour,
      bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
        hour: ziele.schlafenszeitMinuten ~/ Duration.minutesPerHour,
        minute: ziele.schlafenszeitMinuten % Duration.minutesPerHour,
      ),
      alcoholDays: AlcoholDays.from([
        for (final tag in tage)
          (date: datumAusTag(tag.tag), drinks: tag.alcoholicDrinks),
      ]),
      window: DataWindow(start: tagesbeginn(1)),
    );
  }

  /// Die Zustandsart kommt weiter aus `erholungZustandAus` — nur der
  /// Schnappschuss darin wird ersetzt (siehe [schnappschussAus]).
  ErholungZustand erholungAus({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    Ziele ziele = Ziele.vorbelegung,
  }) {
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false);
    final schlafWert =
        schlaf ??
        Bekannt<List<SleepNight>>(naechte(), stand: jetzt, laeuft: false);
    final roh = erholungZustandAus(
      tageswerte: tagesWert,
      naechte: schlafWert,
      ziele: ziele,
      fenster: DataWindow(start: tagesbeginn(1)),
      jetzt: jetzt,
    );
    final daten = roh.daten;
    if (daten is! Bekannt<ErholungDaten>) return roh;
    return ErholungZustand(
      daten: Bekannt<ErholungDaten>(
        ErholungDaten(
          schnappschuss: schnappschussAus(tagesWert, schlafWert, ziele),
          nacht: daten.wert.nacht,
          wochenminuten: daten.wert.wochenminuten,
        ),
        stand: daten.stand,
        laeuft: daten.laeuft,
      ),
      ziele: roh.ziele,
    );
  }

  BelastungDaten daten({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    Ziele ziele = Ziele.vorbelegung,
  }) {
    final zustand = belastungZustandAus(
      erholung: erholungAus(
        tageswerte: tageswerte,
        schlaf: schlaf,
        ziele: ziele,
      ),
    );
    return (zustand.daten as Bekannt<BelastungDaten>).wert;
  }

  // ─────────────────────────────────────────────────────────────────────

  group('Die Stufen', () {
    test('W M 6M — die einzige Folge der App ohne J', () {
      expect(belastungsStufen, const [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
      ]);
      expect(
        belastungsStufen.contains(DiagrammStufe.jahr),
        isFalse,
        reason:
            'Der Store lädt 31 Tage, ein Jahresfenster wäre leer. Wer '
            '„überall dieselben Stufen" vereinheitlicht, erzeugt ein leeres '
            'Jahr (`LoadDetailView.swift:66–68`)',
      );
    });

    test('und die Startstufe ist damit W (#7)', () {
      expect(startStufe(belastungsStufen), DiagrammStufe.woche);
    });
  });

  group('Das Wochenziel kommt aus den Zielen', () {
    test('die Vorbelegung ist 210 — aber aus `Ziele`, nicht aus dem Schirm', () {
      expect(daten().wochenziel, 210);
      expect(
        Ziele.vorbelegung.wochenzielTrainingsminuten,
        210,
        reason:
            'Die einzige Stelle im Quelltext, an der diese Zahl steht. Steht '
            'sie ein zweites Mal im Schirm, ändert ein geändertes Ziel die '
            'Kopfzeile nicht mit',
      );
    });

    test('ein geändertes Ziel ändert das Wochenziel mit', () {
      final gesetzt = daten(
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 140),
      );
      expect(gesetzt.wochenziel, 140);
    });
  });

  group('Die Wochenzahlen', () {
    test('die Minuten dieser Woche sind die Summe über ihre Tage', () {
      // Heute ist Montag, die Woche besteht aus einem Tag.
      expect(daten().wochenminuten, 60);
    });

    test('der Anteil ist Minuten durch Ziel', () {
      expect(daten().anteil, closeTo(60 / 210, 1e-9));
    });

    test('ein Ziel von 0 gibt keinen Anteil, sondern `null`', () {
      final ohneZiel = daten(
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 0),
      );
      expect(
        ohneZiel.anteil,
        isNull,
        reason:
            'Durch null geteilt wird nirgends, und „unendlich Prozent '
            'erreicht" ist keine Auskunft',
      );
    });

    test('die Vorwoche ist die Summe über Montag bis Sonntag davor', () {
      // Sieben Tage à 20 Minuten.
      expect(daten().vorwochenminuten, 140);
    });

    test('die Veränderung ist der Vergleich beider Summen in Prozent', () {
      // 60 gegen 140 — ein Rückgang um gut 57 %.
      expect(daten().veraenderung, closeTo((60 - 140) / 140 * 100, 1e-9));
    });

    test('eine Vorwoche von 0 Minuten gibt keine Veränderung', () {
      final ohne = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(vorwoche: 0),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(
        ohne.vorwochenminuten,
        0,
        reason: 'gemessene Null — sieben Tage ohne Bewegung sind ein Befund',
      );
      expect(
        ohne.veraenderung,
        isNull,
        reason: '„unendlich Prozent mehr als nichts" ist keine Aussage',
      );
    });
  });

  group('„Nicht gemessen" ist nicht „gemessene Null"', () {
    test('keine Aufzeichnung diese Woche gibt `null`, nicht 0', () {
      final ohne = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: null),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(
        ohne.wochenminuten,
        isNull,
        reason:
            'Eine 0 behauptete, du hättest dich diese Woche nicht bewegt — '
            'das weiß niemand, wenn nichts aufgezeichnet wurde',
      );
      expect(ohne.anteil, isNull);
      expect(ohne.veraenderung, isNull);
    });

    test('eine echte Null bleibt 0', () {
      final null0 = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: 0),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(null0.wochenminuten, 0);
      expect(null0.anteil, 0);
      expect(
        null0.veraenderung,
        closeTo(-100, 1e-9),
        reason: 'von 140 auf 0 ist ein Rückgang um 100 %, keine Lücke',
      );
    });

    test('eine Vorwoche ohne Aufzeichnung gibt `null`, nicht 0', () {
      final ohne = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(vorwoche: null),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(ohne.vorwochenminuten, isNull);
      expect(ohne.veraenderung, isNull);
    });

    test('liegt die Vorwoche außerhalb des Fensters, gibt es sie nicht', () {
      final nurHeute = belastungZustandAus(
        erholung: erholungZustandAus(
          tageswerte: Bekannt<List<DailyMetrics>>(
            [tagwert(12)],
            stand: jetzt,
            laeuft: false,
          ),
          naechte: Bekannt<List<SleepNight>>(
            [nachtVon(12)],
            stand: jetzt,
            laeuft: false,
          ),
          ziele: Ziele.vorbelegung,
          fenster: DataWindow(start: tagesbeginn(12)),
          jetzt: jetzt,
        ),
      );
      expect(
        (nurHeute.daten as Bekannt<BelastungDaten>).wert.vorwochenminuten,
        isNull,
      );
    });
  });

  group('Die Reihe für das Diagramm', () {
    test('ein Punkt je Tag mit Trainingsminuten, aufsteigend', () {
      final reihe = daten().tagesminuten;
      expect(reihe, hasLength(8));
      expect(reihe.first.tag, tagesbeginn(5));
      expect(reihe.last.tag, tagesbeginn(12));
      expect(reihe.last.wert, 60);
    });

    test('ein Tag ohne Trainingsminuten fehlt — Lücken bleiben Lücken', () {
      final reihe = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: null),
          stand: jetzt,
          laeuft: false,
        ),
      ).tagesminuten;
      expect(
        reihe.map((p) => p.tag).contains(tagesbeginn(12)),
        isFalse,
        reason:
            'Ein Tag ohne Wert ist kein Tag mit 0 Minuten. Als Balken der '
            'Höhe 0 gezeichnet wäre er eine Behauptung',
      );
    });

    test('eine gemessene Null bleibt ein Punkt', () {
      final reihe = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(heute: 0),
          stand: jetzt,
          laeuft: false,
        ),
      ).tagesminuten;
      expect(reihe.last.tag, tagesbeginn(12));
      expect(reihe.last.wert, 0);
    });

    test('die Tage tragen Berliner Tagesgrenzen', () {
      for (final punkt in daten().tagesminuten) {
        expect(punkt.tag, BerlinCalendar.startOfDay(punkt.tag));
      }
    });
  });

  group('Der Einordnungssatz zählt die Warnsignale', () {
    test('ruhige Werte: kein Signal', () {
      expect(daten().signale, 0);
    });

    test('eine kurze Nacht ist ein Signal', () {
      final kurz = daten(
        schlaf: Bekannt<List<SleepNight>>(
          naechte(heuteStunden: 4),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(
        kurz.signale,
        1,
        reason:
            'Schlaf unter sechs Stunden, feste Schwelle aus '
            '`RecoveryTrafficLight` — der Satz dieses Schirms hängt an beiden '
            'Health-Hälften, nicht nur an den Tageswerten',
      );
    });

    test('zwei Signale sind der Fall, den der Entwurf gelb färbt', () {
      final zwei = daten(
        tageswerte: Bekannt<List<DailyMetrics>>(
          [
            for (var t = 5; t <= 11; t++) tagwert(t),
            // HRV weit unter dem Median der Tage davor.
            tagwert(12, hrv: 20),
          ],
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechte(heuteStunden: 4),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(zwei.signale, 2);
    });
  });

  group('Die vier Messwert-Zustände reicht der Schirm durch', () {
    test('noch nie etwas gesehen', () {
      final zustand = belastungZustandAus(
        erholung: erholungAus(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        ),
      );
      expect(zustand.daten, isA<NochNie<BelastungDaten>>());
    });

    test('ein fertiger Lauf ohne Treffer', () {
      final zustand = belastungZustandAus(
        erholung: erholungAus(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        ),
      );
      expect(zustand.daten, isA<LeerNachLauf<BelastungDaten>>());
    });

    test('ein gescheiterter Lauf ohne Cache', () {
      final zustand = belastungZustandAus(
        erholung: erholungAus(
          tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
        ),
      );
      expect(zustand.daten, isA<Fehlgeschlagen<BelastungDaten>>());
    });

    test(
      'ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg',
      () {
        final zustand = belastungZustandAus(
          erholung: erholungAus(
            tageswerte: Bekannt<List<DailyMetrics>>(
              tage(),
              stand: jetzt,
              laeuft: false,
            ),
            schlaf: Fehlgeschlagen<List<SleepNight>>(
              fehler: 'kaputt',
              gelaufen: jetzt,
            ),
          ),
        );
        expect(
          zustand.daten,
          isA<Bekannt<BelastungDaten>>(),
          reason:
              'Tims Beschwerde ist, dass Werte verschwinden — die eine Hälfte '
              'ist da, also stehen die Minuten da',
        );
      },
    );

    test('`laeuft` reicht bis hierher durch', () {
      final zustand = belastungZustandAus(
        erholung: erholungAus(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tage(),
            stand: jetzt,
            laeuft: true,
          ),
        ),
      );
      final bekannt = zustand.daten as Bekannt<BelastungDaten>;
      expect(bekannt.laeuft, isTrue);
      expect(bekannt.stand, jetzt);
    });
  });

  group('Der Provider', () {
    /// Die Nachtwerte der Provider-Hülle — sie **spiegeln** die Tageswerte
    /// (#193, Stufe 4). Die Quelle wechselt, die Vorlage nicht.
    Messwert<Map<String, NightVitals>> nachtwerteAus(
      Messwert<List<DailyMetrics>> tageswerte,
    ) => switch (tageswerte) {
      Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
        Bekannt<Map<String, NightVitals>>({
          for (final tag in wert)
            tag.tag: NightVitals(
              restingHeartRate: tag.restingHR?.toDouble(),
              hrv: tag.hrvMs,
              respiratoryRate: tag.respRate,
            ),
        }, stand: stand, laeuft: laeuft),
      NochNie<List<DailyMetrics>>() =>
        const NochNie<Map<String, NightVitals>>(),
      LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
        LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
      Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
        Fehlgeschlagen<Map<String, NightVitals>>(
          fehler: fehler,
          gelaufen: gelaufen,
        ),
    };

    ProviderContainer behaelter({
      Messwert<List<DailyMetrics>>? tageswerte,
      Ziele ziele = Ziele.vorbelegung,
    }) {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(
              tageswerte ??
                  Bekannt<List<DailyMetrics>>(
                    tage(),
                    stand: jetzt,
                    laeuft: false,
                  ),
            ),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(naechte(), stand: jetzt, laeuft: false),
            ),
          ),
          // #193, Stufe 4: `erholungProvider` beobachtet seit der
          // Umstellung auch die Nachtwerte.
          nachtWerteProvider.overrideWith(
            () => _Nachtwerte(
              nachtwerteAus(
                tageswerte ??
                    Bekannt<List<DailyMetrics>>(
                      tage(),
                      stand: jetzt,
                      laeuft: false,
                    ),
              ),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(ziele)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('liefert den Zustand, ohne dass jemand vorher Erholung geöffnet hat', () async {
      final container = behaelter();
      // Ein Durchlauf der Mikrotasks: Die beiden `AsyncNotifier` sind dann
      // fertig, ohne dass der Test etwas über ihre Innereien wissen muss.
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);

      final zustand = container.read(belastungProvider);
      expect(zustand.daten, isA<Bekannt<BelastungDaten>>());
      expect(
        (zustand.daten as Bekannt<BelastungDaten>).wert.wochenziel,
        210,
      );
    });

    test('hält seinen Zustand, statt ihn bei jedem Zugriff zu rechnen', () async {
      final container = behaelter();
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);

      expect(
        identical(
          container.read(belastungProvider),
          container.read(belastungProvider),
        ),
        isTrue,
        reason:
            'Hausregel 2: Was ein Provider einer Ansicht anbietet, wird '
            'gehalten. Eine berechnete Eigenschaft rechnet je Bild — das war '
            '`docs/todo/03`',
      );
    });

    test('ein geändertes Ziel rechnet den Zustand neu', () async {
      final container = behaelter();
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);
      final vorher = container.read(belastungProvider);

      await container
          .read(zieleProvider.notifier)
          .setze(Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 140));

      final nachher = container.read(belastungProvider);
      expect(identical(vorher, nachher), isFalse);
      expect(
        (nachher.daten as Bekannt<BelastungDaten>).wert.wochenziel,
        140,
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  Ziele wert;

  @override
  Future<Ziele> build() async => wert;

  @override
  Future<void> setze(Ziele neu) async {
    // `await future` zuerst — genau wie der echte `ZieleNotifier.setze`
    // (`lib/data/ziele.dart:188`). Ohne diese Zeile rennt ein `setze` direkt
    // nach dem ersten, synchronen `read` mit dem noch laufenden `build()` um
    // die Reihenfolge, und der frisch gesetzte Wert wird vom älteren
    // Lesevorgang wieder überschrieben. Der Mock hatte die Race, gegen die
    // der Quellcode ausdrücklich gebaut ist.
    await future;
    wert = neu;
    state = AsyncData(neu);
  }
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
