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
import 'package:repit/shell/koerper_zustand.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für den **Zustand** der Körper-Schirme (#202, Teil C) —
/// `lib/shell/koerper_zustand.dart`. Er trägt, was `koerper` (#82) und
/// `messungen` (#85) an Zahlen zeigen; die Oberflächen bekommen eigene
/// Testdateien.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Teil C, Abschnitt „Der Schnitt — präzisiert am 02.11.2026". Vorbild für
/// Schnitt und Stil ist `verlauf_zustand_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/koerper_zustand.dart`)
///
/// ```dart
/// /// Was Körper und Messungen zu **einer** Messart zeigen.
/// @immutable
/// class MessStand {
///   const MessStand({
///     required MessArt art,
///     required double? wert,
///     required String? tag,
///     required double? veraenderung6Wochen,
///     required List<MeasurementPoint> reihe,
///   });
/// }
///
/// @immutable
/// class KoerperWerte {
///   const KoerperWerte({
///     required MessStand gewicht,
///     required MessStand koerperfett,
///     required MessStand fettfreieMasse,
///     required MessStand ruhepuls,
///     required double? gewichtsTrendProWoche,
///     required TrendRating? trendEinordnung,
///     required (int, int)? eiweissZiel,
///     required int? schritteSchnitt7,
///   });
///
///   /// Die **eine** Zuordnung Messart → Stand; vier Karten, eine Rechnung.
///   MessStand stand(MessArt art);
/// }
///
/// Messwert<KoerperWerte> koerperWerteAus({
///   required Messwert<List<DailyMetrics>> tageswerte,
///   required DateTime jetzt,
/// });
///
/// final koerperWerteProvider = Provider<Messwert<KoerperWerte>>(...);
/// ```
///
/// Beide Typen tragen `==` und `hashCode` — sie werden von einem Provider
/// gehalten, und ohne Wertgleichheit liefe jeder abgeleitete Wert bei jedem
/// neuen Lauf neu (`CLAUDE.md`, Fehler `03`). Geprüft wird die Gleichheit
/// deshalb über ein `Set`, nicht nur über `==`: Ein `==` ohne passenden
/// `hashCode` fällt bei `==` nicht auf, im `Set` sofort.
///
/// ## Warum dieser Schnitt
///
/// - **Eine Quelle für Tageswerte.** `dailyMetricsProvider` liest bereits
///   Cache zuerst und dann den Kanal; Gewicht, Körperfett und fettfreie
///   Masse stehen seit Teil B darin. `koerperWerteAus` **leitet davon ab**
///   und fragt nichts selbst — in Swift holten `BodyStore` und
///   `EnduranceStore` beide dieselben Tageswerte, und genau das soll sich
///   nicht wiederholen (Spec, Teil C).
/// - **`MessStand` statt vier mal vier Feldern.** Die vier Karten auf
///   `messungen` und die vier Kacheln auf `koerper` unterscheiden sich in
///   der Messart, nicht in der Rechnung. `stand(MessArt)` ist die eine
///   Stelle, an der die Zuordnung steht — dasselbe Muster wie
///   `verlaufArtZu` nebenan.
/// - **Keine Nutzertexte.** Der Zustand liefert `TrendRating`, Zahlen und
///   Tagesschlüssel — nicht „zuletzt am 11.10." und nicht die vier
///   Trendsätze. Die stehen in der View (`CLAUDE.md`). Deshalb prüft diese
///   Datei nirgends eine Beschriftung; stünde eine im Zustand, wäre der
///   Schnitt falsch.
///
/// ## `null`, nie `0` — der Kern von Fehler `01`
///
/// Fehlt eine Messung, sind `wert` **und** `tag` `null`. Eine `0,0 %`
/// Körperfett oder ein Ring auf 0 behauptet „nichts gemessen", und das ist
/// `01` in neuer Verpackung (`CLAUDE.md`, „`0` ist keine Antwort auf ‚kein
/// Wert'"). Die Gruppe „Fehlt ein Wert" unten ist dafür da und prüft
/// ausdrücklich auch `isNot(0)`.
///
/// ## Zwei Festlegungen dieser Datei, die die Spec offen lässt
///
/// 1. **`istLeer` entscheidet nur über einen *fertigen* Lauf.** Die Spec
///    sagt: leer heißt, dass keine der vier Messarten einen Wert trägt.
///    Offen bleibt, was gilt, solange der Lauf noch läuft
///    (`Bekannt(…, laeuft: true)` aus dem Cache) und der Cache keinen der
///    vier Werte trägt. Hier gilt dann `NochNie` — der graue Platzhalter —
///    und **nicht** `LeerNachLauf`: „Während des Ladens steht nie ein
///    ‚keine Daten'-Grund" ist der Fehler `01`, auf den es laut Spec
///    („Tests") ankommt, und `LeerNachLauf` ist der einzige Zustand, der
///    einen Grund anzeigen darf (`messwert.dart`). Ist der Lauf fertig und
///    trägt keine der vier Arten einen Wert, ist es `LeerNachLauf`.
/// 2. **Der Zeitstempel von `LeerNachLauf` ist hier nicht festgenagelt.**
///    Ob dort der Stand des zugrunde liegenden `Bekannt` steht oder die
///    Uhr, entscheidet die Spec nicht; beides ist vertretbar. Geprüft wird
///    nur der Zustand selbst — eine erfundene Erwartung wäre schlimmer als
///    keine.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Körperfett nach Navy.** Ausdrückliches Nicht-Ziel (Spec,
///   „Nicht-Ziele"): Es braucht Taille und Hals vom Maßband (#88). Auf dem
///   Detailschirm steht dafür `navyProzent`, immer `null` — geprüft in
///   `messung_detail_zustand_test.dart`.
/// - **Das Körperziel.** `ZielWerte` kennt kein Zielgewicht (#41); ein
///   Zielabstand im Zustand wäre ein hartcodiertes Ereignis in Wartestellung.
/// - **Format und Einheit** („82,4 kg", „Ø 7 Tage"). Beschriftung, nicht
///   Regel.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie in
  // `verlauf_zustand_test.dart`. Als UTC-Zeitpunkt, der eine Berliner
  // Uhrzeit bezeichnet; gerechnet wird nirgends von Hand.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  /// Der Berliner Tagesbeginn von vor [tage] Tagen — über
  /// [BerlinCalendar.addDays], nie über `Duration(days: …)`: Die Nacht zum
  /// 25.10.2026 hat 25 Stunden.
  DateTime tagVor(int tage) => BerlinCalendar.addDays(heute, -tage);

  String schluesselVor(int tage) => BerlinCalendar.dayKey(tagVor(tage));

  DailyMetrics messung(
    int tageZurueck, {
    double? gewicht,
    double? fett,
    double? fettfrei,
    int? ruhepuls,
    int? schritte,
  }) => DailyMetrics(
    tag: schluesselVor(tageZurueck),
    steps: schritte,
    restingHR: ruhepuls,
    weightKg: gewicht,
    bodyFatPct: fett,
    leanKg: fettfrei,
  );

  /// Drei Tage mit allen vier Messarten, aufsteigend. Die Zahlen sind
  /// erfunden — die aus `docs/screens/` sind es auch und dürfen nie
  /// Erwartungswert sein (Spec, „Tests").
  List<DailyMetrics> alleVier() => [
    messung(3, gewicht: 80.0, fett: 20.0, fettfrei: 60.0, ruhepuls: 55),
    messung(1, gewicht: 81.0, fett: 21.0, fettfrei: 61.0, ruhepuls: 56),
    messung(0, gewicht: 82.4, fett: 22.5, fettfrei: 62.1, ruhepuls: 57),
  ];

  Messwert<KoerperWerte> zustandAus(
    List<DailyMetrics> tage, {
    bool laeuft = false,
  }) => koerperWerteAus(
    tageswerte: Bekannt<List<DailyMetrics>>(
      tage,
      stand: jetzt,
      laeuft: laeuft,
    ),
    jetzt: jetzt,
  );

  KoerperWerte werte(List<DailyMetrics> tage) =>
      (zustandAus(tage) as Bekannt<KoerperWerte>).wert;

  // ─────────────────────────────────────────────────────────────────────

  group('Die vier Messarten', () {
    test('jede trägt ihren jüngsten Wert und den Tag seiner Messung', () {
      final w = werte(alleVier());

      expect(w.stand(MessArt.gewicht).wert, 82.4);
      expect(w.stand(MessArt.gewicht).tag, schluesselVor(0));
      expect(w.stand(MessArt.koerperfett).wert, 22.5);
      expect(w.stand(MessArt.koerperfett).tag, schluesselVor(0));
      expect(w.stand(MessArt.fettfreieMasse).wert, 62.1);
      expect(w.stand(MessArt.fettfreieMasse).tag, schluesselVor(0));
      expect(
        w.stand(MessArt.ruhepuls).wert,
        57,
        reason:
            'auch der Ruhepuls kommt als `double` heraus — die Spalte ist '
            'eine Ganzzahlspalte, die Messreihe ist es nicht',
      );
      expect(w.stand(MessArt.ruhepuls).tag, schluesselVor(0));
    });

    test('`stand(art)` und die vier Felder sind dasselbe', () {
      final w = werte(alleVier());
      expect(w.stand(MessArt.gewicht), w.gewicht);
      expect(w.stand(MessArt.koerperfett), w.koerperfett);
      expect(w.stand(MessArt.fettfreieMasse), w.fettfreieMasse);
      expect(w.stand(MessArt.ruhepuls), w.ruhepuls);
      for (final art in MessArt.values) {
        expect(w.stand(art).art, art, reason: '$art kennt seine eigene Art');
      }
    });

    test(
      'der jüngste **gemessene** Tag zählt, nicht der jüngste Tag — eine '
      'Lücke bleibt eine Lücke',
      () {
        final w = werte([
          messung(3, gewicht: 80.0),
          // Der jüngste Tag trägt Schritte, aber keine Wägung: Die Waage
          // stand nicht jeden Morgen im Bad.
          messung(0, schritte: 9000),
        ]);

        expect(w.stand(MessArt.gewicht).wert, 80.0);
        expect(
          w.stand(MessArt.gewicht).tag,
          schluesselVor(3),
          reason:
              'der Tag gehört zum Wert, nicht zum Lauf — „zuletzt gemessen '
              'am" ist die Zeile, die daraus entsteht',
        );
      },
    );
  });

  group('Fehlt ein Wert, ist er `null` — nie `0` (Fehler `01`)', () {
    test('keine Waagenwerte: Wert, Tag, Veränderung und Reihe sind leer', () {
      // Nur Ruhepuls und Schritte, wie es der Cache einer App liefert, die
      // nie eine Waage gesehen hat.
      final w = werte([
        messung(2, ruhepuls: 55, schritte: 8000),
        messung(0, ruhepuls: 57, schritte: 9000),
      ]);

      for (final art in const [
        MessArt.gewicht,
        MessArt.koerperfett,
        MessArt.fettfreieMasse,
      ]) {
        final stand = w.stand(art);
        expect(stand.wert, isNull, reason: '$art');
        expect(
          stand.wert,
          isNot(0),
          reason:
              '$art: eine 0 behauptet eine Messung, die es nie gab — genau '
              'das ist Fehler `01` (`CLAUDE.md`, „`0` ist keine Antwort auf '
              '‚kein Wert\'")',
        );
        expect(stand.tag, isNull, reason: '$art: kein Wert, kein Tag');
        expect(stand.veraenderung6Wochen, isNull, reason: '$art');
        expect(stand.reihe, isEmpty, reason: '$art');
      }

      expect(
        w.gewichtsTrendProWoche,
        isNull,
        reason: 'ohne Wägung keine Steigung, und schon gar keine 0,0',
      );
      expect(w.trendEinordnung, isNull);
      expect(w.eiweissZiel, isNull, reason: 'ohne Gewicht kein Eiweißziel');
    });

    test('ein fehlender Wert zieht die anderen drei nicht mit herunter', () {
      final w = werte([
        messung(1, gewicht: 81.0, fettfrei: 61.0, ruhepuls: 56),
        messung(0, gewicht: 82.4, fettfrei: 62.1, ruhepuls: 57),
      ]);

      expect(w.stand(MessArt.koerperfett).wert, isNull);
      expect(w.stand(MessArt.gewicht).wert, 82.4);
      expect(w.stand(MessArt.fettfreieMasse).wert, 62.1);
      expect(w.stand(MessArt.ruhepuls).wert, 57);
    });
  });

  group('Leer heißt: **keine** der vier trägt einen Wert', () {
    test('drei Werte da, einer fehlt — trotzdem `Bekannt`', () {
      final zustand = zustandAus([
        messung(0, gewicht: 82.4, fettfrei: 62.1, ruhepuls: 57),
      ]);

      expect(
        zustand,
        isA<Bekannt<KoerperWerte>>(),
        reason:
            'Ein Schirm, der drei Werte hat und wegen des vierten „keine '
            'Daten" sagt, ist Fehler `01` (Spec, Teil C)',
      );
    });

    test('eine einzige der vier genügt — auch der Ruhepuls allein', () {
      for (final tag in [
        messung(0, gewicht: 82.4),
        messung(0, fett: 22.5),
        messung(0, fettfrei: 62.1),
        messung(0, ruhepuls: 57),
      ]) {
        expect(
          zustandAus([tag]),
          isA<Bekannt<KoerperWerte>>(),
          reason: 'trägt auch nur eine Messart einen Wert, ist es `Bekannt`',
        );
      }
    });

    test('ein fertiger Lauf ohne eine einzige der vier ist `LeerNachLauf`', () {
      // Schritte allein sind keine der vier Messarten — die Kachel
      // „Schritte Ø 7 Tage" hängt an ihnen, der Leerzustand nicht.
      final zustand = zustandAus([messung(0, schritte: 9000)]);

      expect(
        zustand,
        isA<LeerNachLauf<KoerperWerte>>(),
        reason:
            '`LeerNachLauf` ist der einzige Zustand, der einen „keine '
            'Daten"-Grund anzeigen darf (`messwert.dart`)',
      );
    });

    test(
      'während ein Lauf läuft steht **kein** Grund da, sondern der '
      'Platzhalter (`01`)',
      () {
        final zustand = zustandAus([
          messung(0, schritte: 9000),
        ], laeuft: true);

        expect(
          zustand,
          isA<NochNie<KoerperWerte>>(),
          reason:
              'Festlegung dieser Datei, siehe Dateikopf: Ein Lauf, der noch '
              'läuft, hat nichts gefunden — er sucht noch. „Während des '
              'Ladens steht nie ein ‚keine Daten\'-Grund" (Spec, „Tests")',
        );
        expect(zustand, isNot(isA<LeerNachLauf<KoerperWerte>>()));
      },
    );
  });

  group('Die vier Messwert-Zustände reicht der Zustand durch', () {
    test('noch nie etwas gesehen', () {
      expect(
        koerperWerteAus(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          jetzt: jetzt,
        ),
        isA<NochNie<KoerperWerte>>(),
      );
    });

    test('ein fertiger Lauf ohne Treffer', () {
      expect(
        koerperWerteAus(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          jetzt: jetzt,
        ),
        isA<LeerNachLauf<KoerperWerte>>(),
      );
    });

    test('ein gescheiterter Lauf ohne Cache', () {
      expect(
        koerperWerteAus(
          tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
          jetzt: jetzt,
        ),
        isA<Fehlgeschlagen<KoerperWerte>>(),
      );
    });

    test('ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg', () {
      // Genau das liefert `alsMesswert`, wenn der Kanal scheitert und ein
      // Cache vorliegt: `Bekannt` mit dem Cache-Stand und `laeuft: false`.
      final vorhin = jetzt.subtract(const Duration(minutes: 20));
      final zustand = koerperWerteAus(
        tageswerte: Bekannt<List<DailyMetrics>>(
          alleVier(),
          stand: vorhin,
          laeuft: false,
        ),
        jetzt: jetzt,
      );

      expect(zustand, isA<Bekannt<KoerperWerte>>());
      final bekannt = zustand as Bekannt<KoerperWerte>;
      expect(bekannt.wert.stand(MessArt.gewicht).wert, 82.4);
      expect(bekannt.laeuft, isFalse);
      expect(
        bekannt.stand,
        vorhin,
        reason:
            'der Stand gehört zu der Zahl, die dasteht — nicht zum '
            'gescheiterten Versuch von gerade eben',
      );
    });
  });

  group('Der Gewichtstrend', () {
    test('kommt aus `BodyTrend.perWeek` über die Gewichtsreihe', () {
      final tage = [
        messung(28, gewicht: 80.0),
        messung(21, gewicht: 80.4),
        messung(14, gewicht: 80.7),
        messung(7, gewicht: 81.2),
        messung(0, gewicht: 81.5),
      ];

      // Die Erwartung kommt aus dem Kern selbst, nicht aus einer zweiten
      // Formel hier — zwei Fassungen derselben Rechnung driften.
      final erwartet = BodyTrend.perWeek(
        [
          for (final tag in tage)
            MeasurementPoint(
              date: datumAusTag(tag.tag),
              value: tag.weightKg!,
            ),
        ],
        now: jetzt,
      );

      expect(erwartet, isNotNull);
      expect(werte(tage).gewichtsTrendProWoche, closeTo(erwartet!, 1e-9));
      expect(
        werte(tage).gewichtsTrendProWoche,
        greaterThan(0),
        reason: 'eine steigende Reihe steigt auch pro Woche',
      );
    });

    test('`null` bei weniger als zwei Wägungen im Fenster', () {
      final w = werte([messung(0, gewicht: 82.4)]);
      expect(
        w.gewichtsTrendProWoche,
        isNull,
        reason:
            'Eine Gerade durch einen Punkt hat keine Steigung — „0,00 kg pro '
            'Woche" wäre eine Zahl, die niemand gerechnet hat (Spec, Teil A)',
      );
      expect(w.trendEinordnung, isNull);
    });

    test('das Fenster sind sechs Wochen: Älteres zählt nicht mit', () {
      final imFenster = [messung(42, gewicht: 80.0), messung(0, gewicht: 81.2)];
      final mitAusreisser = [messung(70, gewicht: 20.0), ...imFenster];

      expect(
        werte(imFenster).gewichtsTrendProWoche,
        isNotNull,
        reason: 'ein Punkt genau auf der Kante zählt mit (`>=`)',
      );
      expect(
        werte(mitAusreisser).gewichtsTrendProWoche,
        closeTo(werte(imFenster).gewichtsTrendProWoche!, 1e-9),
        reason:
            'zehn Wochen alt liegt außerhalb des 6-Wochen-Fensters und darf '
            'die Steigung nicht verbiegen',
      );
    });

    test('die Einordnung kommt aus `BodyTrend.rating`', () {
      final tage = [messung(14, gewicht: 80.0), messung(0, gewicht: 80.4)];
      final w = werte(tage);

      expect(w.gewichtsTrendProWoche, isNotNull);
      expect(
        w.trendEinordnung,
        BodyTrend.rating(w.gewichtsTrendProWoche!),
        reason:
            'nicht eine zweite Schwellentabelle hier — die Grenzen stehen '
            'im Kern (Spec, Teil A)',
      );
    });
  });

  group('Das Eiweißziel', () {
    test('kommt aus `ProteinTarget.grams` über das jüngste Gewicht', () {
      final w = werte(alleVier());
      final erwartet = ProteinTarget.grams(82.4);

      expect(erwartet, isNotNull);
      expect(w.eiweissZiel, isNotNull);
      expect(w.eiweissZiel!.$1, erwartet!.$1);
      expect(
        w.eiweissZiel!.$2,
        erwartet.$2,
        reason:
            'positionelle Felder — `low`/`high` sind Dokumentation, '
            r'zugegriffen wird über `.$1` und `.$2` (Spec, Teil A)',
      );
      expect(
        w.eiweissZiel!.$1,
        lessThan(w.eiweissZiel!.$2),
        reason: '1,6 g/kg ist weniger als 2,0 g/kg',
      );
    });

    test('`null` ohne Gewicht, auch wenn die anderen drei dastehen', () {
      final w = werte([messung(0, fett: 22.5, fettfrei: 62.1, ruhepuls: 57)]);
      expect(w.eiweissZiel, isNull);
    });
  });

  group('Veränderung über sechs Wochen', () {
    test('jüngster minus ältester Wert im Fenster', () {
      final w = werte([
        messung(40, gewicht: 80.0, ruhepuls: 60),
        messung(20, gewicht: 83.0, ruhepuls: 50),
        messung(0, gewicht: 82.0, ruhepuls: 57),
      ]);

      expect(
        w.stand(MessArt.gewicht).veraenderung6Wochen,
        closeTo(2.0, 1e-9),
        reason:
            'jüngster (82,0) minus ältester (80,0) — nicht der größte '
            'Abstand und nicht die Steigung',
      );
      expect(
        w.stand(MessArt.ruhepuls).veraenderung6Wochen,
        closeTo(-3.0, 1e-9),
        reason: 'auch nach unten, und mit Vorzeichen',
      );
    });

    test('`null` unter zwei Werten im Fenster', () {
      expect(
        werte([messung(0, gewicht: 82.4)])
            .stand(MessArt.gewicht)
            .veraenderung6Wochen,
        isNull,
      );
      expect(
        werte([
          messung(70, gewicht: 80.0),
          messung(0, gewicht: 82.4),
        ]).stand(MessArt.gewicht).veraenderung6Wochen,
        isNull,
        reason:
            'der zehn Wochen alte Punkt liegt außerhalb — im Fenster bleibt '
            'einer übrig, und einer ist keine Veränderung',
      );
    });

    test('ein Punkt genau auf der Fensterkante zählt mit', () {
      expect(
        werte([
          messung(42, gewicht: 80.0),
          messung(0, gewicht: 82.4),
        ]).stand(MessArt.gewicht).veraenderung6Wochen,
        closeTo(2.4, 1e-9),
        reason:
            'dieselbe Kante wie bei `BodyTrend.perWeek`: 6 × 7 Kalendertage '
            'vor dem Berliner Tagesbeginn, Punkte darauf zählen mit',
      );
    });
  });

  group('Schritte Ø 7 Tage', () {
    test('das Mittel der sieben Tage **vor** heute', () {
      final w = werte([
        for (var t = 1; t <= 7; t++) messung(t, schritte: t * 1000),
        // Der laufende Tag bleibt außen vor — er ist noch nicht vorbei und
        // zöge jeden Durchschnitt nach unten
        // (`StepStatistics.swift:30–31`).
        //
        // **Der Ruhepuls steht hier nicht als Beiwerk**, sondern damit der
        // Zustand überhaupt `Bekannt` ist: Schritte sind keine der vier
        // Messarten (Gruppe „Leer heißt: **keine** der vier trägt einen
        // Wert"), eine Datenlage aus Schritten allein ist `LeerNachLauf`,
        // und `werte(...)` käme nicht an einen Wert heran. Auf den
        // Schrittschnitt wirkt er nicht. Wer ihn für überflüssig hält und
        // herausnimmt, macht diesen Fall rot.
        messung(0, schritte: 120, ruhepuls: 55),
      ]);

      expect(w.schritteSchnitt7, 4000);
    });

    test('Tage ohne Schrittwert zählen nicht in den Nenner', () {
      final w = werte([
        messung(1, schritte: 1000),
        messung(2, schritte: 1001),
        // Keine Schritte an den übrigen fünf Tagen: Das sind keine Tage mit
        // null Schritten (`StepStatistics.swift:11–12`).
        //
        // Dieser Tag trägt zugleich den Ruhepuls, der den Zustand erst zu
        // `Bekannt` macht — siehe den Fall darüber. Ohne ihn wäre die ganze
        // Datenlage `LeerNachLauf`, und dieser Fall prüfte nichts mehr.
        messung(3, ruhepuls: 55),
      ]);

      expect(
        w.schritteSchnitt7,
        1001,
        reason:
            'Mittel aus 1000 und 1001 ist 1000,5 und wird kaufmännisch '
            'gerundet — nicht durch sieben geteilt',
      );
    });

    test('`null`, wenn in den sieben Tagen nichts gemessen wurde', () {
      expect(werte(alleVier()).schritteSchnitt7, isNull);
      expect(
        // Auch hier trägt der Ruhepuls den Zustand nach `Bekannt` — mit
        // `messung(0, schritte: 9000)` allein wäre die Datenlage
        // `LeerNachLauf` (Gruppe „Leer heißt: **keine** der vier trägt
        // einen Wert"), und geprüft würde eine andere Frage als die hier
        // gemeinte. Auf den Schrittschnitt wirkt er nicht.
        werte([messung(0, schritte: 9000, ruhepuls: 55)]).schritteSchnitt7,
        isNull,
        reason:
            'heute allein ergibt keinen Sieben-Tage-Schnitt — und eine 0 '
            'behauptete einen',
      );
    });
  });

  group('Die Sparkline-Reihen', () {
    test('die jüngsten sieben Messpunkte, aufsteigend', () {
      // Neun Wägungen: Die beiden ältesten dürfen nicht in der Kurve stehen.
      final w = werte([
        for (var t = 8; t >= 0; t--) messung(t, gewicht: 80.0 + t),
      ]);
      final reihe = w.stand(MessArt.gewicht).reihe;

      expect(reihe, hasLength(7));
      expect(reihe.first.value, 80.0 + 6);
      expect(reihe.last.value, 80.0);
      for (var i = 1; i < reihe.length; i++) {
        expect(
          reihe[i].date.isAfter(reihe[i - 1].date),
          isTrue,
          reason: 'aufsteigend: eine Kurve läuft nach rechts',
        );
      }
    });

    test('weniger als sieben Punkte kommen vollständig durch', () {
      expect(werte(alleVier()).stand(MessArt.gewicht).reihe, hasLength(3));
    });

    test('jeder Punkt trägt den Berliner Tagesbeginn seines Tages', () {
      final reihe = werte(alleVier()).stand(MessArt.ruhepuls).reihe;
      expect(reihe.last.date, tagVor(0));
      expect(
        reihe.last.date.isUtc,
        isTrue,
        reason:
            'ein UTC-Zeitpunkt, der eine Berliner Tagesgrenze bezeichnet — '
            'die ganze Zeitrechnung läuft so (`CLAUDE.md`)',
      );
    });

    test('jede Messart hat ihre eigene Reihe', () {
      final w = werte([
        messung(2, gewicht: 80.0),
        messung(1, ruhepuls: 56),
        messung(0, gewicht: 82.4, ruhepuls: 57),
      ]);

      expect(w.stand(MessArt.gewicht).reihe.map((p) => p.value), [80.0, 82.4]);
      expect(w.stand(MessArt.ruhepuls).reihe.map((p) => p.value), [56.0, 57.0]);
      expect(w.stand(MessArt.koerperfett).reihe, isEmpty);
    });
  });

  group('Gleichheit — über ein `Set`, nicht nur über `==`', () {
    test('zwei gleich gerechnete Werte sind einer', () {
      final a = werte(alleVier());
      final b = werte(alleVier());

      expect(a, b);
      expect(
        {a, b},
        hasLength(1),
        reason:
            'Ohne passenden `hashCode` lägen hier zwei im Set, und jeder '
            'abgeleitete Wert liefe bei jedem Lauf neu — das wäre `03`, '
            'wortgleich im neuen Code (`CLAUDE.md`)',
      );
      expect({a.gewicht, b.gewicht}, hasLength(1));
    });

    test('ein geänderter Wert macht zwei daraus', () {
      final a = werte(alleVier());
      final b = werte([
        ...alleVier().sublist(0, 2),
        messung(0, gewicht: 99.0, fett: 22.5, fettfrei: 62.1, ruhepuls: 57),
      ]);

      expect(a, isNot(b));
      expect({a, b}, hasLength(2));
    });

    test('auch ein Unterschied, der nur in der Kurve steht, zählt', () {
      // Der älteste Punkt liegt **außerhalb** des 6-Wochen-Fensters: Er
      // ändert weder Trend noch Veränderung noch den jüngsten Wert, steht
      // aber in der Sparkline. Ohne `listEquals` in `==` fiele das durch.
      List<DailyMetrics> mitAltem(double alt) => [
        messung(70, gewicht: alt),
        messung(7, gewicht: 81.0),
        messung(0, gewicht: 82.4),
      ];

      final a = werte(mitAltem(60.0));
      final b = werte(mitAltem(61.0));

      expect(a.gewichtsTrendProWoche, b.gewichtsTrendProWoche);
      expect(
        a.stand(MessArt.gewicht).veraenderung6Wochen,
        b.stand(MessArt.gewicht).veraenderung6Wochen,
      );
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
    test('leitet aus `dailyMetricsProvider` ab und hält seinen Wert', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          healthProvider.overrideWithValue(
            _FakeHealthReading(dailyMetricsAntwort: () async => alleVier()),
          ),
          clockProvider.overrideWithValue(() => jetzt),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dailyMetricsProvider.future);

      final zustand = container.read(koerperWerteProvider);
      expect(zustand, isA<Bekannt<KoerperWerte>>());
      expect(
        (zustand as Bekannt<KoerperWerte>).wert.stand(MessArt.gewicht).wert,
        82.4,
      );

      expect(
        identical(
          container.read(koerperWerteProvider),
          container.read(koerperWerteProvider),
        ),
        isTrue,
        reason:
            'gehalten, nicht bei jedem Zugriff gerechnet — Hausregel 2, das '
            'war Fehler `03`',
      );
    });

    test(
      'ein gescheiterter Nachlauf lässt den Wert aus dem Cache stehen',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        // Erster Container: ein erfolgreicher Lauf füllt den Cache.
        final ersterContainer = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appCacheProvider.overrideWithValue(db),
            healthProvider.overrideWithValue(
              _FakeHealthReading(dailyMetricsAntwort: () async => alleVier()),
            ),
            clockProvider.overrideWithValue(() => jetzt),
          ],
        );
        addTearDown(ersterContainer.dispose);
        await ersterContainer.read(dailyMetricsProvider.future);

        // Zweiter Container == Kaltstart. Der Kanal scheitert, der Cache
        // steht.
        final spaeter = jetzt.add(const Duration(minutes: 5));
        final zweiterContainer = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appCacheProvider.overrideWithValue(db),
            healthProvider.overrideWithValue(
              _FakeHealthReading(
                dailyMetricsAntwort: () async => throw StateError('kaputt'),
              ),
            ),
            clockProvider.overrideWithValue(() => spaeter),
          ],
        );
        addTearDown(zweiterContainer.dispose);

        // Der Endzustand wird über den Listener gelesen, nicht über
        // `.future`: Bei vorhandenem Cache löst `.future` mit der
        // Zwischenausgabe auf (siehe Dateikopf von
        // `health_provider_test.dart`).
        final beobachtet = <Messwert<KoerperWerte>>[];
        zweiterContainer.listen(
          koerperWerteProvider,
          (_, neu) => beobachtet.add(neu),
          fireImmediately: true,
        );
        await pumpEventQueue();

        expect(beobachtet, isNotEmpty);
        expect(
          beobachtet.last,
          isA<Bekannt<KoerperWerte>>(),
          reason:
              'Tims Beschwerde ist, dass Werte verschwinden: `Fehlgeschlagen` '
              'gilt nur, wenn nichts zwischengespeichert ist (`CLAUDE.md`)',
        );
        final bekannt = beobachtet.last as Bekannt<KoerperWerte>;
        expect(bekannt.wert.stand(MessArt.gewicht).wert, 82.4);
        expect(bekannt.laeuft, isFalse);
      },
    );
  });
}

/// Steuerbarer Ableger der echten Quelle — wörtlich wie in
/// `test/health/health_provider_test.dart`, damit es nicht zwei Fassungen
/// derselben Attrappe gibt.
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
