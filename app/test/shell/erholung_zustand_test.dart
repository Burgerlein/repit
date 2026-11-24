import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_zustand.dart';

/// Tests für den **Zustand** des Erholung-Schirms (#115) —
/// `lib/shell/erholung_zustand.dart`. Die Oberfläche selbst liegt in
/// `erholung_view_test.dart`.
///
/// Die Trennung ist dieselbe wie bei `heute_zustand_test.dart` /
/// `heute_view_test.dart` und aus demselben Grund: Zwischen Providern und
/// View gehört ein eigener Zustandstyp. Dann sind die Zustände ohne Widget
/// prüfbar — und die 16 Kreuzungen aus zwei `Messwert`-Hälften (Tageswerte
/// × Nächte), auf denen Fehler `01` lebt, lassen sich als Tabelle prüfen
/// statt als sechzehn gepumpte Schirme.
///
/// ## Festgelegte öffentliche API (`lib/shell/erholung_zustand.dart`)
///
/// ```dart
/// /// Die Health-Hälfte des Schirms, einmal gerechnet.
/// @immutable
/// class ErholungDaten {
///   const ErholungDaten({
///     required RecoverySnapshot schnappschuss,
///     required SleepNight? nacht,
///     required double? wochenminuten,
///   });
/// }
///
/// /// Alles, was der Schirm zeigt.
/// @immutable
/// class ErholungZustand {
///   const ErholungZustand({
///     required Messwert<ErholungDaten> daten,
///     required Ziele ziele,
///   });
/// }
///
/// ErholungZustand erholungZustandAus({
///   required Messwert<List<DailyMetrics>> tageswerte,
///   required Messwert<List<SleepNight>> naechte,
///   // Seit #193, Stufe 4 (02.11.2026): Ruhepuls, HRV und Atemfrequenz
///   // kommen aus dem Nachtfenster, nachgeschlagen unter dem
///   // ISO-Tagesschlüssel. Der Vertrag dieses Parameters steht in
///   // `erholung_nachtwerte_test.dart`, nicht hier.
///   Messwert<Map<String, NightVitals>> nachtwerte =
///       const NochNie<Map<String, NightVitals>>(),
///   required Ziele ziele,
///   required DataWindow fenster,
///   required DateTime jetzt,
/// });
///
/// final erholungProvider = Provider<ErholungZustand>(...);
///
/// // Seit #193, Stufe 4 (02.11.2026) nimmt `alsRecoveryDay` die drei
/// // Erholungswerte aus dem Nachtfenster entgegen; `exerciseMinutes`
/// // bleibt Tageswert. Der Vertrag dieses Parameters steht in
/// // `erholung_nachtwerte_test.dart`, nicht hier.
/// RecoveryDay alsRecoveryDay(DailyMetrics tag, {NightVitals? nachtwerte});
/// RecoveryNight alsRecoveryNacht(SleepNight nacht);
///
/// @immutable
/// class ErholungHinweis {
///   const ErholungHinweis({
///     required List<String> signale,
///     required List<String> absaetze,
///     required CupertinoDynamicColor kante,
///     required bool zeigtHealthEinstellungen,
///   });
/// }
///
/// ErholungHinweis? erholungHinweis({
///   required RecoveryEvaluation bewertung,
///   required RecoveryReading messwerte,
///   required RecoveryBaseline baseline,
/// });
/// ```
///
/// ## Warum dieser Schnitt
///
/// - **`Messwert` liegt um die Health-Hälfte, nicht um den ganzen Zustand.**
///   `Ziele` sind Tims eigene Daten; für sie gibt es keinen Lauf, der leer
///   ausgehen kann (`CLAUDE.md`). Sie stehen deshalb unverpackt neben
///   `Messwert<ErholungDaten>` — und genau deshalb darf der Schirm
///   Datumszeile, Tipps und Fußnote auch dann zeigen, wenn Apple Health
///   noch nichts geliefert hat.
/// - **`ErholungDaten` trägt die Nacht *zusätzlich* zum Schnappschuss.**
///   `RecoverySnapshot.night` ist ein `RecoveryNight` und kennt keine
///   Abschnitte; das Hypnogramm (#116) braucht aber die `SleepSession`, und
///   die Tagschlaf-Kachel braucht `SleepNight.naps`. Beides aus dem Kern
///   herauszureichen hieße, `SleepSegment` in `trainings_core` zu ziehen —
///   die Rechnung braucht es nicht, das Bild schon.
/// - **`wochenminuten` ist nullbar und wird hier entschieden, nicht in der
///   View.** `TrainingLoad.weekMinutes` liefert `0.0`, wenn kein Tag der
///   Woche `exerciseMinutes` trägt — und `0` heißt auf dem Ring „diese Woche
///   nichts trainiert", was ohne Aufzeichnung niemand weiß (#114). Die
///   Unterscheidung braucht die Tagesliste, also fällt sie dort, wo die
///   Liste liegt.
/// - **`erholungHinweis` ist eine reine Funktion, kein Widget.** Die Regeln
///   des Hinweiskastens (fällt bei `calm` weg; nennt bei fehlenden Daten
///   beide Möglichkeiten; Knopf nur bei `noData`; Kantenfarbe je Verdikt)
///   sind Entscheidungen, keine Darstellung. Als Funktion sind sie auch für
///   `postOperative` prüfbar — ein Verdikt, das der Schirm heute gar nicht
///   erzeugen *kann* (Spec Abschnitt 9: kein Ereignisdatum im Quelltext),
///   dessen Text aber bereits festliegt.
///
/// ## Warum `NochNie` `laeuft` wahr macht (#193, Stufe 4)
///
/// Seit dem 02.11.2026 stammen drei der vier Spalten der Erholungskarte —
/// Ruhepuls, HRV und Atemfrequenz — aus den Nachtwerten. Sind die
/// unbekannt, **läuft der Zustand**: `NochNie` ist in dieser App der
/// Ladezustand (`CLAUDE.md`, „Der Platzhalter gehört allein in
/// `NochNie`"). Stünde `laeuft` auf `false`, während die Nachtwerte noch
/// unterwegs sind, läge „Stand 14:32" über drei leeren Spalten und
/// behauptete einen abgeschlossenen Lauf — die Nachbarschaft von Fehler
/// `01`, also genau das, wogegen die Tabelle in der Gruppe „Zwei Hälften,
/// ein Messwert" geschrieben ist.
///
/// **Zwei Fälle dieser Datei standen dadurch kurz gegen ihren eigenen
/// Vertrag.** „beide Hälften fertig: Bekannt mit dem früheren der beiden
/// Stände" und „eine Hälfte da, die andere leer nach Lauf" prüfen **auch**
/// `laeuft == false` — und ihre Eingabe war am 02.11.2026 mit der des
/// Nachtwerte-Falls in `erholung_nachtwerte_test.dart` wortgleich, bei
/// entgegengesetzter Erwartung: Ein weggelassener Parameter ist in Dart von
/// einem ausdrücklichen `NochNie` nicht zu unterscheiden.
///
/// **Keine der beiden Erwartungen ist deshalb gestrichen worden.**
/// Geändert hat sich die **Eingabe**: [zustand] gibt die Nachtwerte jetzt
/// immer mit, also ist in beiden Fällen tatsächlich nichts mehr unterwegs,
/// und `laeuft == false` bleibt geprüft — an einer Eingabe, die den Satz
/// auch trägt. Beide Fälle handeln ohnehin von der Stand-Minimierung und
/// vom Stehenbleiben eines Werts; `laeuft` ist dort die Zugabe, nicht die
/// Aussage. Wer den Ladezustand prüfen will, setzt ihn ausdrücklich — eine
/// Zusicherung, die an einem Vorgabewert hängt, ist keine.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Wortlaut.** Wo ein Text eine Regel trägt, wird die Regel geprüft
///   (beide Möglichkeiten genannt, eine Zahl steht drin, zwei Räte sind
///   verschieden), nie der ganze Satz — `CLAUDE.md`, „nur für Zustände und
///   Übergänge".
/// - **`==`/`hashCode` auf `ErholungZustand`/`ErholungDaten`.**
///   `RecoverySnapshot` hat laut eigenem Vertrag (#109/#112) keine
///   Wertgleichheit; ein `==` darüber wäre eine Zusicherung, die der Code
///   nicht einlösen kann. Statt dessen prüft die Provider-Gruppe unten, dass
///   der Zustand **gehalten** wird (dieselbe Instanz bei zweimaligem Lesen)
///   — das ist die Eigenschaft, um die es in Hausregel 2 geht, nicht die
///   Gleichheit selbst.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden. Keine stammt aus einem Export, einem Screenshot oder
/// `docs/screens/` (`CLAUDE.md`, Spec Abschnitt 12).
void main() {
  // Montag, 12.10.2026, 09:15 Berlin — CEST (+2), weit vor der Umstellung
  // am 25.10. Montag, damit die Trainingswoche an diesem Tag beginnt und
  // `TrainingLoad.weekBounds` nur den heutigen Tag enthält.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? atmung = 13,
    double? trainingsminuten = 20,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atmung,
    exerciseMinutes: trainingsminuten,
  );

  /// Eine Nacht, die um 06:00 Berliner Zeit endet und [stunden] lang ist.
  /// Bei 7 Stunden beginnt sie also um 23:00 des Vortags.
  SleepNight nachtVon(
    int tag, {
    double stunden = 7,
    List<SleepSession> naps = const [],
  }) {
    final ende = DateTime.utc(2026, 10, tag, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: naps,
    );
  }

  List<DailyMetrics> tagereihe({
    int? ruhepulsHeute = 52,
    double? trainingsminuten = 20,
  }) => [
    for (var t = 3; t <= 11; t++) tagwert(t, trainingsminuten: trainingsminuten),
    tagwert(12, ruhepuls: ruhepulsHeute, trainingsminuten: trainingsminuten),
  ];

  List<SleepNight> nachtreihe({double heuteStunden = 7}) => [
    for (var t = 3; t <= 11; t++) nachtVon(t),
    nachtVon(12, stunden: heuteStunden),
  ];

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4). Die Quelle wechselt, die Vorlage nicht; der `Messwert`-Zustand
  /// wandert mit, damit ein gescheiterter Tageslauf hier auch einen
  /// gescheiterten Nachtlauf bedeutet.
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
    NochNie<List<DailyMetrics>>() => const NochNie<Map<String, NightVitals>>(),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
      LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<Map<String, NightVitals>>(
        fehler: fehler,
        gelaufen: gelaufen,
      ),
  };

  /// **Die Nachtwerte werden immer mitgegeben** — seit #193, Stufe 4, sind
  /// sie eine Eingabe dieser Rechnung, und wer sie weglässt, bekommt
  /// `NochNie`, also den **Ladezustand**. Das ist kein neutraler
  /// Vorgabewert: `laeuft` wird davon wahr, und zwar mit Absicht (siehe
  /// „Warum `NochNie` `laeuft` wahr macht" im Kopf dieser Datei). Die
  /// Tabelle unten handelt aber von den beiden bestehenden Hälften; ein
  /// drittes, stillschweigend ladendes Feld hätte jede ihrer Zeilen
  /// verschoben.
  ErholungZustand zustand({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? naechte,
    Messwert<Map<String, NightVitals>>? nachtwerte,
    Ziele ziele = Ziele.vorbelegung,
    DataWindow? fenster,
  }) {
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tagereihe(), stand: jetzt, laeuft: false);
    return erholungZustandAus(
      tageswerte: tagesWert,
      naechte:
          naechte ??
          Bekannt<List<SleepNight>>(nachtreihe(), stand: jetzt, laeuft: false),
      nachtwerte: nachtwerte ?? nachtwerteAus(tagesWert),
      ziele: ziele,
      fenster: fenster ?? DataWindow.unlimited,
      jetzt: jetzt,
    );
  }

  ErholungDaten datenAus(ErholungZustand z) {
    final daten = z.daten;
    if (daten is! Bekannt<ErholungDaten>) {
      fail('erwartet war Bekannt, da stand $daten');
    }
    return daten.wert;
  }

  group('alsRecoveryDay / alsRecoveryNacht — die Brücke in den Kern', () {
    // **Am 02.11.2026 zurückgeschnitten (#193, Stufe 4).** Dieser Fall prüfte
    // bis dahin auch, dass Ruhepuls (52), HRV (60) und Atemfrequenz (13)
    // **aus dem Tageswert** herüberwandern. Genau das gilt nicht mehr: Die
    // drei kommen seit Stufe 4 aus dem Nachtfenster, `alsRecoveryDay` nimmt
    // sie als `NightVitals` entgegen. Geprüft wird hier nur noch, was
    // unverändert weitergilt — das Datum und die Trainingsminuten.
    // **`exerciseMinutes` bleibt Tageswert: Training ist keine Nacht.**
    //
    // Die neue Quelle prüft `erholung_nachtwerte_test.dart`; dort steht auch
    // Tims Entscheidung vom 02.11.2026 samt der Messung, die sie trägt.
    test(
      'ein Tageswert wandert als Datum und mit seinem Training herüber',
      () {
        final kern = alsRecoveryDay(tagwert(12));

        expect(kern.date, tagesbeginn(12));
        expect(
          kern.exerciseMinutes,
          20.0,
          reason: 'Training ist keine Nacht und bleibt Tageswert',
        );
      },
    );

    test('ein fehlender Wert bleibt null und wird nie zu 0', () {
      final kern = alsRecoveryDay(
        const DailyMetrics(tag: '2026-10-12', steps: 4321),
      );

      expect(kern.restingHeartRate, isNull);
      expect(kern.hrv, isNull);
      expect(kern.respiratoryRate, isNull);
      expect(kern.exerciseMinutes, isNull);
    });

    test(
      'Schlafminuten zählen jeden Abschnitt außer awake, auch unspecified '
      '(ältere Uhren und das iPhone liefern Schlaf ohne Phasenangabe)',
      () {
        final nacht = SleepNight(
          date: tagesbeginn(12),
          session: SleepSession(
            segments: [
              SleepSegment(
                stage: SleepStage.unspecified,
                start: DateTime.utc(2026, 10, 11, 21),
                end: DateTime.utc(2026, 10, 11, 22),
              ),
              SleepSegment(
                stage: SleepStage.deep,
                start: DateTime.utc(2026, 10, 11, 22),
                end: DateTime.utc(2026, 10, 11, 23),
              ),
            ],
          ),
        );

        expect(alsRecoveryNacht(nacht).asleepMinutes, 120);
      },
    );

    test(
      'die Einschlafzeit ist der Beginn des ersten Schlafabschnitts, nicht '
      'der des Wachliegens davor',
      () {
        final nacht = SleepNight(
          date: tagesbeginn(12),
          session: SleepSession(
            segments: [
              SleepSegment(
                stage: SleepStage.awake,
                start: DateTime.utc(2026, 10, 11, 20, 30),
                end: DateTime.utc(2026, 10, 11, 21),
              ),
              SleepSegment(
                stage: SleepStage.core,
                start: DateTime.utc(2026, 10, 11, 21),
                end: DateTime.utc(2026, 10, 12, 4),
              ),
            ],
          ),
        );

        expect(alsRecoveryNacht(nacht).bedtime, DateTime.utc(2026, 10, 11, 21));
      },
    );

    test(
      'Wachliegen vor dem Einschlafen und nach dem Aufwachen ist keine '
      'Unterbrechung, Wachliegen dazwischen schon',
      () {
        final nacht = SleepNight(
          date: tagesbeginn(12),
          session: SleepSession(
            segments: [
              SleepSegment(
                stage: SleepStage.awake,
                start: DateTime.utc(2026, 10, 11, 20, 30),
                end: DateTime.utc(2026, 10, 11, 21),
              ),
              SleepSegment(
                stage: SleepStage.core,
                start: DateTime.utc(2026, 10, 11, 21),
                end: DateTime.utc(2026, 10, 12, 0),
              ),
              SleepSegment(
                stage: SleepStage.awake,
                start: DateTime.utc(2026, 10, 12, 0),
                end: DateTime.utc(2026, 10, 12, 0, 20),
              ),
              SleepSegment(
                stage: SleepStage.rem,
                start: DateTime.utc(2026, 10, 12, 0, 20),
                end: DateTime.utc(2026, 10, 12, 4),
              ),
              SleepSegment(
                stage: SleepStage.awake,
                start: DateTime.utc(2026, 10, 12, 4),
                end: DateTime.utc(2026, 10, 12, 4, 40),
              ),
            ],
          ),
        );

        final kern = alsRecoveryNacht(nacht);
        expect(kern.wakeCount, 1, reason: 'nur das Wachliegen dazwischen');
        expect(kern.awakeMinutes, 20);
      },
    );

    test('eine reine Wachnacht hat keine Schlafminuten und keine Bedtime', () {
      final nacht = SleepNight(
        date: tagesbeginn(12),
        session: SleepSession(
          segments: [
            SleepSegment(
              stage: SleepStage.awake,
              start: DateTime.utc(2026, 10, 11, 22),
              end: DateTime.utc(2026, 10, 12, 2),
            ),
          ],
        ),
      );

      final kern = alsRecoveryNacht(nacht);
      expect(kern.asleepMinutes, 0);
      expect(kern.bedtime, isNull);
    });
  });

  group('Zwei Hälften, ein Messwert — die Tabelle, auf der Fehler 01 lebt', () {
    test('beide Hälften noch ohne alles: NochNie', () {
      final z = zustand(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        naechte: const NochNie<List<SleepNight>>(),
      );

      expect(z.daten, isA<NochNie<ErholungDaten>>());
    });

    test(
      'beide Hälften fertig: Bekannt mit dem FRÜHEREN der beiden Stände — '
      '„Stand 14:32" darf nicht neuer behaupten, als die ältere Hälfte ist',
      () {
        final frueh = DateTime.utc(2026, 10, 12, 6, 0);
        final spaet = DateTime.utc(2026, 10, 12, 7, 0);

        final z = zustand(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tagereihe(),
            stand: spaet,
            laeuft: false,
          ),
          naechte: Bekannt<List<SleepNight>>(
            nachtreihe(),
            stand: frueh,
            laeuft: false,
          ),
        );

        final daten = z.daten;
        expect(daten, isA<Bekannt<ErholungDaten>>());
        expect((daten as Bekannt<ErholungDaten>).stand, frueh);
        expect(daten.laeuft, isFalse);
      },
    );

    test(
      'eine Hälfte da, die andere noch unterwegs: Bekannt mit laeuft:true — '
      'niemals ein Leerstand, während noch gelesen wird (docs/todo/01)',
      () {
        final z = zustand(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tagereihe(),
            stand: jetzt,
            laeuft: false,
          ),
          naechte: const NochNie<List<SleepNight>>(),
        );

        final daten = z.daten;
        expect(daten, isA<Bekannt<ErholungDaten>>());
        expect(
          (daten as Bekannt<ErholungDaten>).laeuft,
          isTrue,
          reason: 'die Schlaf-Hälfte ist noch unterwegs',
        );
      },
    );

    test('läuft eine der beiden Hälften nach, läuft der ganze Zustand', () {
      final z = zustand(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tagereihe(),
          stand: jetzt,
          laeuft: true,
        ),
        naechte: Bekannt<List<SleepNight>>(
          nachtreihe(),
          stand: jetzt,
          laeuft: false,
        ),
      );

      expect((z.daten as Bekannt<ErholungDaten>).laeuft, isTrue);
    });

    test(
      'eine Hälfte da, die andere leer nach Lauf: der Wert bleibt stehen',
      () {
        final z = zustand(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tagereihe(),
            stand: jetzt,
            laeuft: false,
          ),
          naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );

        final daten = z.daten;
        expect(daten, isA<Bekannt<ErholungDaten>>());
        expect((daten as Bekannt<ErholungDaten>).laeuft, isFalse);
      },
    );

    test(
      'eine Hälfte da, die andere gescheitert: der sichtbare Wert bleibt — '
      'ein gescheiterter Nachlauf nimmt nichts weg',
      () {
        final z = zustand(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tagereihe(),
            stand: jetzt,
            laeuft: false,
          ),
          naechte: Fehlgeschlagen<List<SleepNight>>(
            fehler: Exception('Kanal nicht erreichbar'),
            gelaufen: jetzt,
          ),
        );

        expect(z.daten, isA<Bekannt<ErholungDaten>>());
      },
    );

    test(
      'eine Hälfte noch unterwegs, die andere leer: NochNie — solange '
      'irgendetwas läuft, steht kein „keine Daten"-Grund',
      () {
        final z = zustand(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );

        expect(z.daten, isA<NochNie<ErholungDaten>>());
      },
    );

    test('eine Hälfte noch unterwegs, die andere gescheitert: NochNie', () {
      final z = zustand(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        naechte: Fehlgeschlagen<List<SleepNight>>(
          fehler: Exception('Kanal nicht erreichbar'),
          gelaufen: jetzt,
        ),
      );

      expect(z.daten, isA<NochNie<ErholungDaten>>());
    });

    test(
      'eine Hälfte leer, die andere gescheitert: Fehlgeschlagen gewinnt — '
      'ein Fehler ist keine Aussage über die Datenlage',
      () {
        final z = zustand(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          naechte: Fehlgeschlagen<List<SleepNight>>(
            fehler: Exception('Kanal nicht erreichbar'),
            gelaufen: jetzt,
          ),
        );

        expect(z.daten, isA<Fehlgeschlagen<ErholungDaten>>());
      },
    );

    test('beide leer nach Lauf: LeerNachLauf mit dem SPÄTEREN Zeitpunkt', () {
      final frueh = DateTime.utc(2026, 10, 12, 6, 0);
      final spaet = DateTime.utc(2026, 10, 12, 7, 0);

      final z = zustand(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: frueh),
        naechte: LeerNachLauf<List<SleepNight>>(gelaufen: spaet),
      );

      final daten = z.daten;
      expect(daten, isA<LeerNachLauf<ErholungDaten>>());
      expect((daten as LeerNachLauf<ErholungDaten>).gelaufen, spaet);
    });
  });

  group('Der Schnappschuss aus den beiden Hälften', () {
    test('nur Tageswerte: der Schnappschuss steht, aber ohne Nacht', () {
      final z = zustand(
        naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
      );
      final daten = datenAus(z);

      expect(daten.schnappschuss.days, isNotEmpty);
      expect(daten.schnappschuss.night, isNull);
      expect(daten.schnappschuss.score, isNull);
      expect(daten.nacht, isNull);
    });

    test('nur Nächte: der Schnappschuss steht, aber ohne Tageswerte', () {
      final z = zustand(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      final daten = datenAus(z);

      expect(daten.schnappschuss.days, isEmpty);
      expect(daten.schnappschuss.night, isNotNull);
      expect(daten.nacht, isNotNull);
    });

    test('`nacht` ist die Nacht von heute, nicht irgendeine aus dem Fenster', () {
      final daten = datenAus(zustand());

      expect(daten.nacht, isNotNull);
      expect(daten.nacht!.date, tagesbeginn(12));
    });

    test('ohne Nacht von heute bleibt `nacht` null, auch mit älteren Nächten', () {
      final z = zustand(
        naechte: Bekannt<List<SleepNight>>(
          [for (var t = 3; t <= 11; t++) nachtVon(t)],
          stand: jetzt,
          laeuft: false,
        ),
      );

      expect(datenAus(z).nacht, isNull);
    });

    test(
      'das Schlafziel kommt aus den Zielen und wirkt auf die Teilnote Dauer',
      () {
        final kurz = datenAus(
          zustand(
            ziele: Ziele.vorbelegung.kopieMit(schlafzielMinuten: 360), // 6 h
          ),
        ).schnappschuss.score!;
        final lang = datenAus(
          zustand(
            ziele: Ziele.vorbelegung.kopieMit(schlafzielMinuten: 600), // 10 h
          ),
        ).schnappschuss.score!;

        expect(
          kurz.duration,
          greaterThan(lang.duration),
          reason: 'dieselben sieben Stunden gegen ein kleineres Ziel geben '
              'mehr Punkte — wäre das Ziel eine Konstante im Quelltext, '
              'wären beide gleich',
        );
      },
    );

    test(
      'das Schlafenszeitziel kommt aus den Zielen und wird auf die '
      '18-Uhr-Skala umgerechnet, nicht als Minuten nach Mitternacht '
      'durchgereicht',
      () {
        // Die Nacht beginnt um 23:00 Berliner Zeit.
        final zumZiel = datenAus(
          zustand(
            ziele: Ziele.vorbelegung.kopieMit(
              schlafenszeitMinuten: 23 * 60, // 23:00, also genau pünktlich
            ),
          ),
        ).schnappschuss.score!;
        final zuSpaet = datenAus(
          zustand(
            ziele: Ziele.vorbelegung.kopieMit(
              schlafenszeitMinuten: 21 * 60, // 21:00, also zwei Stunden zu spät
            ),
          ),
        ).schnappschuss.score!;

        expect(
          zumZiel.bedtime,
          30,
          reason: 'pünktlich kostet nichts — volle Teilnote',
        );
        expect(
          zuSpaet.bedtime,
          lessThan(zumZiel.bedtime!),
          reason: 'wird das Ziel als Minuten nach Mitternacht (1350) statt '
              'auf der 18-Uhr-Skala (270) weitergereicht, liegt die '
              'Einschlafzeit immer davor und beide Werte sind gleich',
        );
      },
    );

    test(
      'der OP-Fall wird nicht erfunden: isPostOperative ist false, solange '
      'es keine Ereignis-Objekte gibt (Spec Abschnitt 9)',
      () {
        expect(datenAus(zustand()).schnappschuss.isPostOperative, isFalse);
      },
    );

    test(
      'ohne aufgezeichnete Trainingsminuten ist `wochenminuten` null, nicht 0 '
      '— eine gemessene Null ist eine Aussage, eine Lücke nicht',
      () {
        final ohne = zustand(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tagereihe(trainingsminuten: null),
            stand: jetzt,
            laeuft: false,
          ),
        );

        expect(datenAus(ohne).wochenminuten, isNull);
      },
    );

    test('eine gemessene Null bleibt 0', () {
      final null0 = zustand(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tagereihe(trainingsminuten: 0),
          stand: jetzt,
          laeuft: false,
        ),
      );

      expect(datenAus(null0).wochenminuten, 0);
    });

    test('mit Trainingsminuten zählt die laufende Woche', () {
      expect(datenAus(zustand()).wochenminuten, 20);
    });

    test(
      'der eingestellte Betrachtungszeitraum verkürzt das Fenster, '
      'verlängert es nie',
      () {
        final z = zustand(fenster: DataWindow(start: tagesbeginn(10)));

        expect(
          datenAus(z).schnappschuss.days.map((d) => d.date),
          [tagesbeginn(10), tagesbeginn(11), tagesbeginn(12)],
        );
      },
    );

    test('die Ziele liegen unverpackt neben dem Messwert', () {
      final z = zustand(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        naechte: const NochNie<List<SleepNight>>(),
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 123),
      );

      expect(
        z.daten,
        isA<NochNie<ErholungDaten>>(),
        reason: 'die Health-Hälfte weiß noch nichts …',
      );
      expect(
        z.ziele.wochenzielTrainingsminuten,
        123,
        reason: '… Tims eigene Daten stehen trotzdem',
      );
    });
  });

  group('erholungHinweis — der Kasten, der bei calm wegfällt', () {
    const ruhig = RecoveryEvaluation(
      verdict: RecoveryVerdict.calm,
      signals: [],
      measuredCount: 4,
    );
    const einSignal = RecoveryEvaluation(
      verdict: RecoveryVerdict.watch,
      signals: [RecoveryMetric.restingHeartRate],
      measuredCount: 4,
    );
    const zweiSignale = RecoveryEvaluation(
      verdict: RecoveryVerdict.stressed,
      signals: [RecoveryMetric.sleep, RecoveryMetric.restingHeartRate],
      measuredCount: 4,
    );
    const ohneWerte = RecoveryEvaluation(
      verdict: RecoveryVerdict.noData,
      signals: [],
      measuredCount: 0,
    );
    const nachOp = RecoveryEvaluation(
      verdict: RecoveryVerdict.postOperative,
      signals: [],
      measuredCount: 4,
    );

    const messwerte = RecoveryReading(
      sleepHours: 5,
      restingHeartRate: 60,
      hrv: 44,
      respiratoryRate: 15,
    );
    const median = RecoveryBaseline(
      sleepHours: 7,
      restingHeartRate: 52,
      hrv: 60,
      respiratoryRate: 13,
    );

    ErholungHinweis? hinweis(
      RecoveryEvaluation bewertung, {
      RecoveryReading werte = messwerte,
      RecoveryBaseline baseline = median,
    }) => erholungHinweis(
      bewertung: bewertung,
      messwerte: werte,
      baseline: baseline,
    );

    test('bei calm fällt der Kasten ganz weg', () {
      expect(hinweis(ruhig), isNull);
    });

    test('ein Warnsignal: ein benanntes Signal, Kante bib, kein Health-Knopf', () {
      final kasten = hinweis(einSignal)!;

      expect(kasten.signale, hasLength(1));
      expect(kasten.kante, Palette.bib);
      expect(kasten.zeigtHealthEinstellungen, isFalse);
    });

    test('zwei Warnsignale: zwei benannte Signale in Vertragsreihenfolge', () {
      final kasten = hinweis(zweiSignale)!;

      expect(kasten.signale, hasLength(2));
      expect(
        kasten.signale.first.toLowerCase(),
        contains('schlaf'),
        reason: 'Schlaf steht in RecoveryMetric vor dem Ruhepuls — dasselbe '
            'Ergebnis muss unabhängig vom Aufrufweg gleich dastehen',
      );
      expect(kasten.signale[1].toLowerCase(), contains('ruhepuls'));
    });

    test(
      'der Rat bei zwei Signalen ist ein anderer als bei einem — sonst wäre '
      'die Unterscheidung dekorativ',
      () {
        expect(hinweis(zweiSignale)!.absaetze, isNot(hinweis(einSignal)!.absaetze));
      },
    );

    test(
      'ein Signal trägt seine Zahl, wenn Wert und Median vorliegen',
      () {
        final kasten = hinweis(einSignal)!;

        expect(
          kasten.signale.single,
          contains('8'),
          reason: 'Ruhepuls 60 gegen Median 52 — acht Schläge darüber',
        );
      },
    );

    test(
      'fehlt der Median, steht das Signal ohne Zahl da statt mit einer '
      'erfundenen',
      () {
        final kasten = hinweis(einSignal, baseline: const RecoveryBaseline())!;

        expect(kasten.signale, hasLength(1));
        expect(
          RegExp(r'\d').hasMatch(kasten.signale.single),
          isFalse,
          reason: 'ohne Median gibt es keinen Abstand zu nennen',
        );
      },
    );

    test(
      'ohne Werte stehen BEIDE Möglichkeiten da und der Health-Knopf '
      'erscheint — Apple verrät den Lesestatus nicht',
      () {
        final kasten = hinweis(
          ohneWerte,
          werte: const RecoveryReading(),
          baseline: const RecoveryBaseline(),
        )!;

        final text = kasten.absaetze.join(' ').toLowerCase();
        expect(text, contains('aufgezeichnet'));
        expect(text, contains('freigegeben'));
        expect(kasten.zeigtHealthEinstellungen, isTrue);
        expect(kasten.kante, Palette.rest);
      },
    );

    test(
      'nach der OP: Kante warn, kein Health-Knopf, und der Text verweist auf '
      'ärztliche Stellen (CLAUDE.md, „keine Diagnosen")',
      () {
        final kasten = hinweis(nachOp)!;

        expect(kasten.kante, Palette.warn);
        expect(kasten.zeigtHealthEinstellungen, isFalse);
        expect(
          RegExp(
            'klinik|ärztlich|arzt',
            caseSensitive: false,
          ).hasMatch(kasten.absaetze.join(' ')),
          isTrue,
        );
      },
    );

    // **Umgekehrt am 27.10.2026, Entscheidung von Tim.** Bis dahin verlangte
    // dieser Fall das Gegenteil: „bei watch und stressed hängt der Hinweis auf
    // die Klinik vor der OP immer an". Der Satz „Kommen Fieber oder
    // Halsschmerzen dazu: vor der OP die Klinik anrufen" stand damit in
    // **jedem** Fall mit Warnsignal — und setzte fest voraus, dass eine OP
    // ansteht. Eine festverdrahtete Zusage über ein Ereignis ist nicht besser
    // als sein Datum im Quelltext, und genau das verbietet `CLAUDE.md`.
    //
    // Wenn so ein Hinweis kommt, dann vom KI-Coach, der die tatsächlichen
    // Ereignisse kennt. Der Hinweis zur ärztlichen Freigabe bleibt dort, wo er
    // hingehört: im Zustand `postOperative` — der greift nur, wenn wirklich
    // eine OP-Erholung läuft, und wird vom Fall darunter geprüft.
    test(
      'bei watch und stressed steht kein fester Hinweis auf eine OP',
      () {
        for (final bewertung in [einSignal, zweiSignale]) {
          final text = hinweis(bewertung)!.absaetze.join(' ');
          expect(
            RegExp('klinik|vor der op', caseSensitive: false).hasMatch(text),
            isFalse,
            reason: '$bewertung',
          );
        }
      },
    );

    test('nach der OP bleibt der Hinweis auf die aerztliche Freigabe', () {
      final text = hinweis(nachOp)!.absaetze.join(' ');
      expect(
        RegExp('ärztlichen Freigabe', caseSensitive: false).hasMatch(text),
        isTrue,
      );
      expect(RegExp('klinik', caseSensitive: false).hasMatch(text), isTrue);
    });

    test('der Health-Knopf erscheint ausschließlich bei noData', () {
      for (final bewertung in [einSignal, zweiSignale, nachOp]) {
        expect(
          hinweis(bewertung)!.zeigtHealthEinstellungen,
          isFalse,
          reason: '$bewertung',
        );
      }
    });
  });

  group('erholungProvider — gehalten, nicht je Zugriff gerechnet', () {
    ProviderContainer behaelter({
      Ziele ziele = Ziele.vorbelegung,
      DataWindow? betrachtung,
    }) {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet, sonst
      // hängt ein erzwungener Fehler in einem nichtdeterministischen
      // Zwischenzustand.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          if (betrachtung != null)
            dataWindowProvider.overrideWith((ref) => betrachtung),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(
              Bekannt<List<DailyMetrics>>(
                tagereihe(),
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(
                nachtreihe(),
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          // #193, Stufe 4: Seit die drei Erholungswerte aus dem
          // Nachtfenster kommen, beobachtet `erholungProvider` auch diesen
          // Provider. Ohne Überschreibung liefe er in die echte
          // drift-Datenbank, und „zweimal lesen gibt dieselbe Instanz"
          // hätte eine Abhängigkeit, die mitten im Lauf umspringt.
          nachtWerteProvider.overrideWith(
            () => _Nachtwerte(
              nachtwerteAus(
                Bekannt<List<DailyMetrics>>(
                  tagereihe(),
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

    test(
      'zweimal lesen gibt dieselbe Instanz — der Schnappschuss wird gehalten, '
      'nicht bei jedem Zugriff neu gerechnet (Hausregel 2, docs/todo/03)',
      () async {
        final container = behaelter();
        container.listen(erholungProvider, (_, _) {}, fireImmediately: true);
        await container.read(dailyMetricsProvider.future);
        await container.read(sleepProvider.future);

        final erstes = container.read(erholungProvider);
        final zweites = container.read(erholungProvider);

        expect(identical(erstes, zweites), isTrue);
      },
    );

    test('ändert sich eine Abhängigkeit, rechnet er neu', () async {
      final a = behaelter();
      a.listen(erholungProvider, (_, _) {}, fireImmediately: true);
      await a.read(dailyMetricsProvider.future);
      await a.read(sleepProvider.future);
      final mitVorbelegung = a.read(erholungProvider);

      final b = behaelter(
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 321),
      );
      b.listen(erholungProvider, (_, _) {}, fireImmediately: true);
      await b.read(dailyMetricsProvider.future);
      await b.read(sleepProvider.future);
      final mitEigenemZiel = b.read(erholungProvider);

      expect(
        mitVorbelegung.ziele.wochenzielTrainingsminuten,
        Ziele.vorbelegung.wochenzielTrainingsminuten,
      );
      expect(mitEigenemZiel.ziele.wochenzielTrainingsminuten, 321);
    });

    test(
      'der Schirm besorgt seine Daten selbst: ohne dass jemand vorher eine '
      'Übersicht geöffnet hat, steht der Schnappschuss',
      () async {
        final container = behaelter();
        container.listen(erholungProvider, (_, _) {}, fireImmediately: true);
        await container.read(dailyMetricsProvider.future);
        await container.read(sleepProvider.future);

        final z = container.read(erholungProvider);
        expect(z.daten, isA<Bekannt<ErholungDaten>>());
      },
    );

    test('das Wochenziel kommt aus den Zielen, nicht aus dem Quelltext', () async {
      final container = behaelter(
        ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 123),
      );
      container.listen(erholungProvider, (_, _) {}, fireImmediately: true);
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);

      expect(
        container.read(erholungProvider).ziele.wochenzielTrainingsminuten,
        123,
      );
    });

    // Hier stand bis zum 28.10.2026 der Wächter „ErholungTuer kennt die
    // sechs Türen dieses Schirms" (`ErholungTuer.values`, `hasLength(6)`).
    //
    // Er ist weggefallen, weil der Aufzählungstyp weggefallen ist: Seit
    // #92, #94 und #117 stehen, führt jede der sechs Türen auf ihren
    // echten Schirm, und `ErholungTuer` hatte danach keinen Leser mehr —
    // seine einzige Aufgabe war, dem Platzhalter `ErholungTuerPlatzhalter`
    // zu sagen, welche Überschrift er tragen soll. Die vollständige
    // Begründung steht in `erholung_view_test.dart`, Nachtrag vom
    // 28.10.2026 („`ErholungTuer` und `ErholungTuerPlatzhalter` fallen
    // weg").
    //
    // **Der Wächter ist nicht verschwunden, er ist umgezogen:** Der Fall
    // „sechs Türen, und jede landet auf einem gebauten Schirm" in
    // `erholung_view_test.dart` zählt sie jetzt am Schirm selbst — und das
    // ist die Stelle, an der die Zahl überhaupt eine Aussage trägt.
  });
}

/// Steuerbare Ableger der echten Notifier — wie `_GesteuerterNotifier` in
/// `heute_view_test.dart` und aus demselben Grund: Riverpods Provider-Typen
/// sind invariant, ein unabhängiger `AsyncNotifier` erfüllt die Signatur von
/// `overrideWith` nicht.
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

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
