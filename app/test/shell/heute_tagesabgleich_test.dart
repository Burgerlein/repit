import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';

/// Tests zum **Tagesabgleich des Heute-Schirms** (#196, Review-Befund aus
/// #194).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `heute_view.dart` nimmt den **letzten Eintrag des Cache-Fensters** als
/// „heute", ohne ihn gegen den tatsächlichen Kalendertag zu halten. Beim
/// ersten Kaltstart eines neuen Tages ist dieser Eintrag aber *gestern*:
/// Der letzte Lauf um 23:58 schrieb Zeilen bis einschließlich gestern,
/// `DailyMetricsNotifier.build()` gibt sie sofort als
/// `Bekannt(…, laeuft: true)` aus — und seit #194 tragen sie `weightKg`
/// und `exerciseMinutes`.
///
/// Der Ring steht damit morgens voll auf den Minuten von gestern, die
/// Überschrift darüber nennt das heutige Datum. Das ist die Hausregel aus
/// `CLAUDE.md` spiegelverkehrt: Ein Ring auf 0 behauptet „nichts getan",
/// ein Ring auf 47,5 behauptet „getan". Die zweite Auskunft ist die
/// unangenehmere, weil sie ein Training behauptet, das nicht stattfand.
///
/// `heute_view_test.dart` kann den Fall nicht fangen: Seine Fixtures sind
/// laut eigenem Dateikopf **absichtlich** so gebaut, dass der passende
/// Eintrag zugleich der letzte der Liste und der einzige mit passendem
/// `tag` ist — beide Strategien sind dort ununterscheidbar richtig. Genau
/// deshalb braucht der Abgleich eine eigene Fläche.
///
/// ## Entscheidungen dieser Testdatei
///
/// Das Ticket lässt den Wortlaut der Gewichtskachel offen („Welcher Text
/// dort richtig ist, ergibt sich aus `_waageZusatz`"). **Ich lege ihn hier
/// fest** — nicht Tim, nicht die Spec:
///
/// - Die Gewichtskachel sagt beim Kaltstart am Morgen **„gestern
///   gemessen"**, nicht „zuletzt gemessen". Begründung: `_waageZusatz`
///   kennt für 0, 1 und n Tage je eine genaue Auskunft und hält
///   „zuletzt gemessen" als **unbestimmten** Rückfall für den Fall bereit,
///   dass sich die beiden Tagesschlüssel nicht vergleichen lassen. Hier
///   lassen sie sich vergleichen: Der Tag der Messung steht in der
///   Cache-Zeile, der heutige Tag im `heutigerTagProvider`. Eine bekannte
///   Antwort gegen die unbestimmte zu tauschen, wäre weniger Auskunft als
///   vorhanden — und dieselbe Sorte Fehler wie die, gegen die dieser Test
///   gebaut ist, nur in die andere Richtung. Der Abgleich gehört also
///   gegen den **Kalendertag**, nicht gegen den letzten Cache-Eintrag.
/// - Der **Wert** der Gewichtskachel bleibt stehen. Tim wiegt sich nicht
///   täglich; der Rückgriff auf den jüngsten Wert im Fenster ist
///   ausdrücklich gewollt (`heute_anzeigen.dart`) und von #196 nicht
///   berührt. Falsch war nie die Zahl, sondern ihre Einordnung.
///
/// ## Was hier gelesen wird und warum
///
/// `heute_view_test.dart` prüft Kachelwerte bewusst am gezeichneten Text,
/// weil 2026-10 noch offen war, wie `KachelWert` „kein Wert" ausdrückt.
/// Seit #137 ist das entschieden (nullbares Feld, `kacheln.dart` trägt es
/// im Doc-Kommentar), deshalb liest diese Datei das Modell — das ordnet
/// Wert und Einordnung eindeutig **ihrer** Kachel zu, ohne Spaltenrechnen.
/// Dass ein fehlender Wert als `–/–` erscheint, prüft zusätzlich ein
/// Textfund im Kachelstreifen.
///
/// ## Was diese Datei nicht prüft
///
/// - Den Wortlaut der Schritte-Einordnung im Leerfall. Dass dort nicht
///   mehr „heute gezählt" steht, fällt mit dem fehlenden Wert von selbst
///   an; welcher der beiden bestehenden Sätze stattdessen richtig ist, ist
///   eine eigene Frage und nicht Teil von #196.
/// - Die Erholungskarte. Sie hängt seit #115 am `erholungProvider`, nicht
///   am Tageswert — `heute_erholungskarte_test.dart` ist ihre Fläche.
/// - Wie die Zustandsfolge zustande kommt (Cache, Kanal, Wiederholungen).
///   Das deckt `health_provider_test.dart` ab.
void main() {
  // Erfundene Zahlen, wie überall in diesen Tests (`CLAUDE.md`: keine
  // echten Gesundheitswerte im Quelltext). Kaltstart am Morgen des 28.,
  // der letzte Lauf endete am Abend des 27.
  final jetzt = DateTime.utc(2026, 10, 28, 6, 0);
  const heute = '2026-10-28';
  const gestern = '2026-10-27';
  const vorgestern = '2026-10-26';

  /// Der Stand, den der Cache beim Kaltstart hergibt: Zeilen bis gestern,
  /// und gestern wurde trainiert und gewogen.
  const bisGestern = <DailyMetrics>[
    DailyMetrics(tag: vorgestern, steps: 611, exerciseMinutes: 12),
    DailyMetrics(
      tag: gestern,
      steps: 842,
      restingHR: 55,
      hrvMs: 70,
      respRate: 14,
      weightKg: 58.4,
      exerciseMinutes: 47.5,
    ),
  ];

  /// Derselbe Satz, einen Tag weiter — der Kanal hat geantwortet.
  const bisHeute = <DailyMetrics>[
    DailyMetrics(tag: gestern, steps: 842, exerciseMinutes: 47.5),
    DailyMetrics(
      tag: heute,
      steps: 311,
      weightKg: 58.1,
      exerciseMinutes: 18,
    ),
  ];

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.** Der Zustand wandert mit — ein gescheiterter Tageslauf
  /// bedeutet hier auch einen gescheiterten Nachtlauf.
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

  ({ProviderContainer container, Widget app}) harness(
    Messwert<List<DailyMetrics>> zustand,
  ) {
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        dailyMetricsProvider.overrideWith(() => _Tageswerte(zustand)),
        clockProvider.overrideWithValue(() => jetzt),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(zustand)),
        ),
        // Ohne diese drei liefe ein Widget-Test in die echte
        // drift-Datenbank (siehe `heute_view_test.dart`).
        sleepProvider.overrideWith(_KeineNaechte.new),
        zieleProvider.overrideWith(_Ziele.new),
      ],
    );
    final app = UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(
        home: CupertinoPageScaffold(child: HeuteView()),
      ),
    );
    return (container: container, app: app);
  }

  Future<void> zeige(
    WidgetTester tester,
    ({ProviderContainer container, Widget app}) h,
  ) async {
    addTearDown(h.container.dispose);
    await tester.pumpWidget(h.app);
    await tester.pumpAndSettle();
  }

  KachelWert kachel(WidgetTester tester, String labelTeil) {
    final werte = tester.widget<Kacheln>(find.byType(Kacheln)).werte;
    return werte.firstWhere(
      (w) => w.label.toLowerCase().contains(labelTeil),
      orElse: () => throw TestFailure(
        'Die Kachel "$labelTeil" fehlt ganz. Eine Anzeige, die es gibt, '
        'hat genau eine Form — sie verschwindet nicht, weil ihr Wert '
        'fehlt (CLAUDE.md)',
      ),
    );
  }

  /// Der Trainingsring, gefunden über sein Label.
  ///
  /// **Umgestellt mit #358** (Tims Auftrag vom 04.11.2026, Ernährung auf
  /// Home): Bis dahin war er der einzige Ring (`.single`). Seitdem stehen
  /// Kalorien und Eiweiß daneben, und deren Ziel hängt an Gewicht und
  /// Stammdaten — nicht Gegenstand dieser Datei.
  RingZiel training(WidgetTester tester) => tester
      .widget<Ringe>(find.byType(Ringe))
      .ziele
      .firstWhere((z) => z.label == 'Training');

  /// Die gezeichneten Texte der **Trainingszeile** der Ring-Legende.
  ///
  /// Bis #358 die ganze Legende — sie trug nur diese eine Zeile. Seitdem
  /// sagt der Eiweißring in `bisGestern` zu Recht „noch … g" (das Gewicht
  /// von gestern gilt als letztes bekanntes), und die Ziffern dort haben
  /// mit dem Tagesabgleich nichts zu tun. Gemeint war immer der
  /// Trainingsring.
  String legende(WidgetTester tester) {
    final beschriftung = find.descendant(
      of: find.byType(RingLegende),
      matching: find.text('Training'),
    );
    final zeile = find
        .ancestor(of: beschriftung, matching: find.byType(Row))
        .first;
    return tester
        .widgetList<Text>(
          find.descendant(of: zeile, matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .join(' ');
  }

  group('Cache endet bei gestern, die Uhr steht auf heute', () {
    for (final fall in <(String, bool)>[
      ('der Kanal läuft noch (Kaltstart, Cache zuerst)', true),
      ('der Kanal ist dreimal gescheitert — der Wert bliebe sonst die '
          'ganze Sitzung stehen', false),
    ]) {
      final (name, laeuft) = fall;

      testWidgets('$name: der Trainingsring behauptet kein Training', (
        tester,
      ) async {
        await zeige(
          tester,
          harness(
            Bekannt<List<DailyMetrics>>(
              bisGestern,
              stand: DateTime.utc(2026, 10, 27, 21, 58),
              laeuft: laeuft,
            ),
          ),
        );

        expect(
          training(tester).wert,
          isNull,
          reason: 'die 47,5 Minuten sind von gestern. Ein gefüllter Ring '
              'behauptet ein Training, das heute nicht stattfand — '
              'dieselbe falsche Auskunft wie ein Ring auf 0, nur '
              'andersherum (CLAUDE.md)',
        );
        expect(
          legende(tester),
          contains(ohneWert),
          reason: 'die Anzeige bleibt stehen und sagt, dass sie keinen '
              'Wert hat — sie verschwindet nicht und zeigt keine 0',
        );
        expect(
          legende(tester),
          isNot(contains(RegExp('[0-9]'))),
          reason: 'weder der Stand von gestern noch ein daraus gerechneter '
              'Rest ("noch 00 min") gehört in die Beschriftung',
        );
      });

      testWidgets('$name: die Schritte-Kachel steht leer da', (tester) async {
        await zeige(
          tester,
          harness(
            Bekannt<List<DailyMetrics>>(
              bisGestern,
              stand: DateTime.utc(2026, 10, 27, 21, 58),
              laeuft: laeuft,
            ),
          ),
        );

        expect(
          kachel(tester, 'schritt').wert,
          isNull,
          reason: 'ein Schrittwert von gestern ist keine Auskunft über '
              'heute — das sagt `heute_anzeigen.dart` selbst, es galt nur '
              'nicht über die Tagesgrenze hinweg',
        );
        expect(
          find.descendant(
            of: find.byType(Kacheln),
            matching: find.text(ohneWert),
          ),
          findsOneWidget,
          reason: 'genau die Schritte-Kachel sagt "–/–"; das Gewicht darf '
              'seinen jüngsten bekannten Wert behalten',
        );
      });

      testWidgets('$name: die Gewichtskachel sagt "gestern gemessen"', (
        tester,
      ) async {
        await zeige(
          tester,
          harness(
            Bekannt<List<DailyMetrics>>(
              bisGestern,
              stand: DateTime.utc(2026, 10, 27, 21, 58),
              laeuft: laeuft,
            ),
          ),
        );

        final gewicht = kachel(tester, 'gewicht');
        expect(
          gewicht.wert,
          isNotNull,
          reason: 'Tim wiegt sich nicht täglich: Der Rückgriff auf den '
              'jüngsten Wert im Fenster bleibt. Falsch war nie die Zahl, '
              'sondern ihre Einordnung',
        );
        expect(
          gewicht.zusatz.toLowerCase(),
          isNot(contains('heute')),
          reason: 'der Wert ist von gestern — "heute gemessen" ist eine '
              'positive Behauptung über eine Messung, die es heute nicht '
              'gab',
        );
        expect(
          gewicht.zusatz.toLowerCase(),
          contains('gestern'),
          reason: 'Entscheidung dieser Datei (siehe Dateikopf): Der '
              'Abstand ist bekannt — Messtag aus der Cache-Zeile, heutiger '
              'Tag aus dem Provider. Die unbestimmte Beschriftung '
              '"zuletzt gemessen" gehört dem Fall, in dem er es nicht ist',
        );
      });
    }
  });

  group('der gute Fall bleibt gut', () {
    testWidgets('endet das Fenster auf heute, stehen die Werte da', (
      tester,
    ) async {
      await zeige(
        tester,
        harness(
          Bekannt<List<DailyMetrics>>(bisHeute, stand: jetzt, laeuft: false),
        ),
      );

      expect(
        training(tester).wert,
        18,
        reason: 'der heutige Eintrag trägt 18 Minuten — der Abgleich darf '
            'den richtigen Tag nicht mit verwerfen',
      );
      expect(kachel(tester, 'schritt').wert, isNotNull);
      expect(
        kachel(tester, 'gewicht').zusatz.toLowerCase(),
        contains('heute'),
        reason: 'heute gewogen heißt weiterhin "heute gemessen"',
      );
    });

    testWidgets(
      'ein Fenster ohne heutigen Eintrag nennt trotzdem keinen '
      '"keine Daten"-Grund, solange der Lauf läuft',
      (tester) async {
        await zeige(
          tester,
          harness(
            Bekannt<List<DailyMetrics>>(
              bisGestern,
              stand: DateTime.utc(2026, 10, 27, 21, 58),
              laeuft: true,
            ),
          ),
        );

        expect(
          find.textContaining('Lesezugriff'),
          findsNothing,
          reason: 'der Lauf läuft noch — ein "keine Daten"-Grund '
              'währenddessen ist Fehler 01 aus CLAUDE.md. Gesucht wird das '
              'Wort, das nur in diesem einen Grund steht: Die Erholungskarte '
              'führt ihren eigenen Leersatz und ist hier nicht gemeint',
        );
      },
    );
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `heute_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _KeineNaechte extends SleepNotifier {
  @override
  Future<Messwert<List<SleepNight>>> build() async =>
      LeerNachLauf<List<SleepNight>>(gelaufen: DateTime.utc(2026, 10, 28));
}

class _Ziele extends ZieleNotifier {
  @override
  Future<Ziele> build() async => Ziele.vorbelegung;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
