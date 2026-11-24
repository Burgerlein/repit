import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/messungen_view.dart';
import 'package:repit/shell/router.dart';
import '../health/health_reading_attrappe.dart';

/// Das Blatt „Gewicht eintragen" und sein Weg hinein (#270) —
/// `lib/shell/gewicht_eintragen.dart` und die beiden Türen auf dem
/// Messungen-Schirm.
///
/// Grundlage sind
/// `docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md` und die
/// Entwürfe `docs/screens/screens/gewicht-eintragen.js` (Varianten `neu`,
/// `bearbeiten`, `keine-freigabe`) und `messungen.js` (Nachtrag vom
/// 03.11.2026).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": Zustände und Übergänge, nicht Layout und
/// Beschriftung. Kein Fall hier prüft, wie ein Knopf heißt. Geprüft werden
/// die Zusagen, deren Bruch das Feature auch dann wertlos machte, wenn es
/// läuft — die „Anti-Ziele" der Spec:
///
/// 1. **Ein Wert, der als gespeichert gilt und es nicht ist.** Fehlt die
///    Schreibfreigabe oder scheitert das Schreiben, wird **nichts**
///    gespeichert und nichts gelöscht. Geprüft wird das am Mock, nicht am
///    Text: Ein Hinweis, unter dem trotzdem geschrieben wurde, bestünde
///    jede Textprüfung.
/// 2. **Ein versehentlich wiederholter Wert.** Der Platzhalter zeigt den
///    letzten bekannten Wert; „Sichern" bleibt grau, bis etwas Gültiges
///    im Feld steht.
/// 3. **Eine „manuell"-Markierung aus eigener Buchhaltung.** Welche Zeile
///    eine Tür ist, entscheidet `WeightSample.wasUserEntered` — und sonst
///    nichts.
///
/// ## Festgelegte öffentliche API
///
/// ### `lib/shell/gewicht_eintragen.dart` — **vorgeschlagen, nicht erzwungen**
///
/// Diese Datei ruft das Blatt nie unmittelbar auf, sondern immer über die
/// Oberfläche; verbindlich sind deshalb das Verhalten und die Schlüssel
/// unten, nicht dieser Name. Er steht hier, weil der Schnitt sonst beim
/// Bauen neu erfunden werden müsste:
///
/// ```dart
/// /// Öffnet das Blatt über dem aktuellen Schirm. [probe] gesetzt heißt
/// /// „ändern" (der alte Wert steht **im** Feld, es gibt „Eintrag
/// /// löschen"), [probe] `null` heißt „neu" (das Feld ist leer, der
/// /// letzte bekannte Wert steht als Platzhalter dahinter).
/// Future<void> zeigeGewichtEintragen(
///   BuildContext context, {
///   WeightSample? probe,
/// });
/// ```
///
/// Es ist ein **Blatt, kein Schirm** (`showCupertinoModalPopup`, Spec) —
/// `AppRouter` ist nicht beteiligt, `router.nimmBefehl()` bleibt in jedem
/// Fall `null`. Dieselbe Form wie `zeigeSchlafEintragen` (#131).
///
/// ### `lib/health/health_reading.dart` — vier neue Methoden
///
/// ```dart
/// /// Fragt die **Schreib**freigabe für Gewicht an und sagt, was dabei
/// /// herauskam. Lesen und Schreiben sind in HealthKit getrennte
/// /// Freigaben; diese hier fragt **nur**
/// /// `HKQuantityTypeIdentifierBodyMass` ab (Spec, „Nicht-Ziele").
/// ///
/// /// Eine Methode, nicht zwei: Anfragen und Status sind auf dem Weg
/// /// durch den Kanal eine Bewegung — `requestAuthorization(toShare:)`
/// /// liefert selbst keine Auskunft, `authorizationStatus(for:)`
/// /// unmittelbar danach schon (Spec, „Den Schreibstatus verrät Apple").
/// /// Zwei Kanalmethoden ließen dazwischen einen Zustand zu, den es nicht
/// /// gibt.
/// Future<WriteAuthorization> requestWeightWriteAuthorization();
///
/// /// Schreibt eine Gewichtsprobe und liefert ihre HealthKit-UUID.
/// Future<String> writeWeight({required double kg, required DateTime at});
///
/// /// Löscht eine Probe, die diese App geschrieben hat.
/// Future<void> deleteWeight(String id);
///
/// /// Die Gewichtsproben im Zeitraum — mit Uhrzeit, UUID und
/// /// Kennzeichen. Die **zusätzliche** Abfrage neben
/// /// `DailyMetrics.weightKg`, die unverändert bleibt (Spec).
/// Future<List<WeightSample>> weightSamples(DateTime from, DateTime through);
/// ```
///
/// ### `lib/health/health_types.dart`
///
/// ```dart
/// /// Was Apple über die **Schreib**freigabe sagt. Anders als beim Lesen
/// /// ist die Auskunft belastbar — das ist der eine Ort, an dem die
/// /// Hausregel „keine Daten und nicht erlaubt sind nicht
/// /// unterscheidbar" nicht gilt (Spec, „Rahmen").
/// enum WriteAuthorization { granted, denied, notDetermined }
/// ```
///
/// `notDetermined` steht mit da, weil HealthKit es hergibt (der Dialog
/// lässt sich wegwischen). Für das Blatt verhält es sich wie `denied`:
/// **Nur `granted` darf schreiben.** Beide Fälle werden unten geprüft.
///
/// `WeightSample` selbst ist in
/// `app/test/health/weight_sample_codec_test.dart` festgelegt.
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `messungen-eintragen` | „Eintragen ›" über „Letzte Messungen" |
/// | `messungen-waegung-<uuid>` | eine Zeile in „Letzte Messungen" |
/// | `gewicht-blatt` | das Blatt selbst |
/// | `gewicht-blatt-feld` | das Feld „Kilogramm" |
/// | `gewicht-blatt-sichern` | „Sichern" |
/// | `gewicht-blatt-abbrechen` | „Abbrechen" |
/// | `gewicht-blatt-loeschen` | „Eintrag löschen" |
/// | `gewicht-blatt-freigabe` | der Hinweis aus Zustand `keine-freigabe` |
///
/// **Je eine Zeile je Probe, nicht je Tag.** Die Spec nennt als Grund für
/// die Probenabfrage ausdrücklich „Sortierung innerhalb eines Tages" — zwei
/// Wägungen an einem Tag sind zwei Zeilen, und die UUID im Schlüssel ist
/// das, was eine Zeile eindeutig macht.
///
/// **`gewicht-blatt-feld` sitzt auf dem `CupertinoTextField` selbst**, nicht
/// auf einer Hülle: Der Platzhalter ist eine Eigenschaft dieses Widgets, und
/// ohne Zugriff darauf ließe sich „der Platzhalter zählt nicht als Eingabe"
/// nicht aussprechen. **`gewicht-blatt-sichern` sitzt auf einem
/// `CupertinoButton`** — „inaktiv" heißt `onPressed == null`, und das ist
/// die Form, die der Entwurf als `<span class="off">` zeichnet und die
/// `schlaf_eintragen.dart` nebenan schon benutzt.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Die Gestalt des Datumswählers.** Die Spec überlässt sie dem
///   Bauenden („`CupertinoDatePicker` inline oder aufklappend"). Geprüft
///   wird nur, dass der geschriebene Zeitpunkt der der Uhr ist — also aus
///   `clockProvider` kommt und nicht aus `DateTime.now()`.
/// - **„nicht in der Zukunft, nicht vor `earliestPermittedDate`".** Ohne
///   festgelegten Wähler gibt es keinen Weg, ein Datum einzustellen, ohne
///   seine Gestalt mitzubestimmen. Das bleibt der Handprüfung.
/// - **Der Wortlaut des Freigabe-Hinweises** und jede andere
///   Beschriftung.
/// - **Welcher Provider die Probenreihe hält.** Die Spec lässt das offen;
///   diese Tests fassen deshalb `HealthReading` an und nicht den Provider.
///   Aus demselben Grund nimmt die Quelle unten **jeden** Zeitraum an und
///   liefert immer alle Proben: Ein geprüftes Fenster wäre ein Fenster,
///   das diese Datei entschieden hat.
///
/// ## Erfundene Zahlen
///
/// Jedes Gewicht und jede UUID hier ist ausgedacht. Echte Gesundheitswerte
/// stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie
  // in `messungen_view_test.dart`. Bewusst weit weg vom Tag, an dem dieser
  // Test läuft: Nur so fällt auf, wenn jemand `DateTime.now()` statt
  // `clockProvider` benutzt.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  DateTime zeitpunktVor(int tage, {int stundeUtc = 5, int minute = 20}) =>
      BerlinCalendar.addDays(
        heute,
        -tage,
      ).add(Duration(hours: stundeUtc, minutes: minute));

  /// Tageswerte, damit die vier Verlaufskarten etwas zu zeigen haben. Die
  /// Zeilen von „Letzte Messungen" kommen **nicht** von hier, sondern aus
  /// den Proben unten.
  List<DailyMetrics> tageMitWaegung() => [
    DailyMetrics(tag: schluesselVor(4), weightKg: 58.1, restingHR: 55),
    DailyMetrics(tag: schluesselVor(2), weightKg: 58.4, restingHR: 56),
    DailyMetrics(tag: schluesselVor(0), weightKg: 58.6, restingHR: 57),
  ];

  /// Drei Wägungen: die jüngste von Hand eingetragen, die beiden älteren
  /// von der Waage. Nur die erste ist eine Tür.
  List<WeightSample> dreiProben() => [
    WeightSample(
      id: 'probe-von-hand',
      date: zeitpunktVor(0),
      kg: 58.6,
      wasUserEntered: true,
    ),
    WeightSample(
      id: 'probe-waage-a',
      date: zeitpunktVor(2),
      kg: 58.4,
      wasUserEntered: false,
    ),
    WeightSample(
      id: 'probe-waage-b',
      date: zeitpunktVor(4),
      kg: 58.1,
      wasUserEntered: false,
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, _Quelle quelle, Widget app})
  harness({
    Messwert<List<DailyMetrics>>? tageswerte,
    List<WeightSample>? proben,
    WriteAuthorization freigabe = WriteAuthorization.granted,
    bool schreibenScheitert = false,
    bool loeschenScheitert = false,
  }) {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final quelle = _Quelle(
      proben: proben ?? dreiProben(),
      freigabe: freigabe,
      schreibenScheitert: schreibenScheitert,
      loeschenScheitert: loeschenScheitert,
    );

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>(
                  tageMitWaegung(),
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
      router: router,
      quelle: quelle,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: MessungenSeite(router: router)),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Ein hoher Schirm, damit nichts zu scrollen ist — dasselbe Mittel wie
    // in `messungen_view_test.dart`.
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  Finder blatt() => find.byKey(const Key('gewicht-blatt'));
  Finder feld() => find.byKey(const Key('gewicht-blatt-feld'));
  Key waegung(String id) => Key('messungen-waegung-$id');

  /// Was im Feld **steht** — nicht, was als Platzhalter dahinter liegt.
  String feldText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: feld(), matching: find.byType(EditableText)),
      )
      .controller
      .text;

  bool sichernAktiv(WidgetTester tester) =>
      tester
          .widget<CupertinoButton>(
            find.byKey(const Key('gewicht-blatt-sichern')),
          )
          .onPressed !=
      null;

  Future<void> tippeIns(WidgetTester tester, String text) async {
    await tester.enterText(feld(), text);
    await tester.pumpAndSettle();
  }

  Future<void> oeffneNeu(WidgetTester tester) async {
    await tippe(tester, const Key('messungen-eintragen'));
    expect(blatt(), findsOneWidget, reason: 'das Blatt muss aufgehen');
  }

  // ───────────────────────────────────────────────────────────────────────
  // „Eintragen" hängt nicht an Daten
  // ───────────────────────────────────────────────────────────────────────

  group('„Eintragen" steht in jedem Zustand', () {
    testWidgets('mit Werten', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messungen-eintragen')), findsOneWidget);
    });

    testWidgets('ohne jede Wägung — gerade dann', (tester) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        proben: const [],
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('messungen-eintragen')),
        findsOneWidget,
        reason:
            'Der Weg steht auch im Zustand „keine Waagenwerte" zur '
            'Verfügung — gerade dann (Spec)',
      );
    });

    testWidgets('während geladen wird', (tester) async {
      final h = harness(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        proben: const [],
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('messungen-eintragen')),
        findsOneWidget,
        reason:
            '„Eintragen ›" hängt nicht an Daten (Spec, „Leer- und '
            'Ladezustände") — eine Anzeige, die es gibt, hat genau eine '
            'Form',
      );
    });

    testWidgets('und öffnet ein Blatt, keinen Schirm', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await oeffneNeu(tester);

      expect(
        h.router.nimmBefehl(),
        isNull,
        reason: 'ein Blatt landet in keinem Navigationsstapel',
      );
    });

    testWidgets('auch ohne Wägung führt es ins Blatt', (tester) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        proben: const [],
      );
      await zeige(tester, h.app);

      await oeffneNeu(tester);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // „Sichern" bleibt grau, bis etwas Gültiges dasteht
  // ───────────────────────────────────────────────────────────────────────

  group('„Sichern" ist inaktiv, solange der Wert nicht trägt', () {
    testWidgets('frisch geöffnet ist das Feld leer und „Sichern" grau', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      expect(feldText(tester), isEmpty);
      expect(sichernAktiv(tester), isFalse);
      expect(h.quelle.geschrieben, isEmpty);
    });

    testWidgets('der Platzhalter zählt nicht als Eingabe', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      final platzhalter = tester.widget<CupertinoTextField>(feld()).placeholder;
      expect(
        platzhalter,
        isNotNull,
        reason:
            'Der Platzhalter zeigt den letzten bekannten Wert und damit die '
            'Größenordnung — ein vertipptes 584 fällt so sofort auf '
            '(Entwurf)',
      );
      expect(RegExp(r'\d').hasMatch(platzhalter!), isTrue);

      // Und trotzdem: Wer nur „Sichern" tippt, trüge den letzten Wert als
      // heutigen ein und behauptete einen Trend, den es nicht gibt (Spec,
      // „Anti-Ziele").
      expect(sichernAktiv(tester), isFalse);
      await tippe(tester, const Key('gewicht-blatt-sichern'));
      expect(h.quelle.geschrieben, isEmpty);
      expect(blatt(), findsOneWidget);
    });

    testWidgets('ein gültiger Wert macht ihn aktiv', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58,4');

      expect(sichernAktiv(tester), isTrue);
    });

    testWidgets('ein Punkt statt eines Kommas ebenso', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58.4');

      expect(
        sichernAktiv(tester),
        isTrue,
        reason: 'Komma **und** Punkt werden angenommen (Spec)',
      );
    });

    testWidgets('oberhalb der Grenze bleibt er grau', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '584');

      expect(sichernAktiv(tester), isFalse);
      await tippe(tester, const Key('gewicht-blatt-sichern'));
      expect(
        h.quelle.geschrieben,
        isEmpty,
        reason:
            'Ein vertipptes 584 darf auch dann nicht nach Health wandern, '
            'wenn jemand den grauen Knopf trifft',
      );
    });

    testWidgets('unterhalb der Grenze ebenso', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '29,9');

      expect(sichernAktiv(tester), isFalse);
    });

    testWidgets('mit zwei Nachkommastellen ebenso', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58,45');

      expect(
        sichernAktiv(tester),
        isFalse,
        reason:
            'Höchstens eine Nachkommastelle (Spec) — stillschweigend zu '
            'runden hieße, eine Zahl zu sichern, die niemand eingetippt '
            'hat',
      );
    });

    testWidgets('Müll ebenso', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, 'abc');

      expect(sichernAktiv(tester), isFalse);
    });

    testWidgets('und wieder leer macht ihn wieder grau', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58,4');
      expect(sichernAktiv(tester), isTrue, reason: 'sonst prüft das nichts');

      await tippeIns(tester, '');

      expect(sichernAktiv(tester), isFalse);
    });

    testWidgets('beim Ändern ist er von Anfang an aktiv', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));

      expect(blatt(), findsOneWidget);
      expect(
        sichernAktiv(tester),
        isTrue,
        reason:
            'Beim Ändern steht der alte Wert **im** Feld, nicht als '
            'Platzhalter (Spec)',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ohne Schreibfreigabe wird nichts gespeichert
  // ───────────────────────────────────────────────────────────────────────

  group('Fehlt die Schreibfreigabe', () {
    testWidgets('gefragt wird erst beim Sichern, nicht beim Öffnen', (
      tester,
    ) async {
      final h = harness(freigabe: WriteAuthorization.denied);
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      expect(
        h.quelle.freigabeAnfragen,
        0,
        reason:
            'Der Systemdialog gehört an „Sichern" (Spec, „Was beim Sichern '
            'passiert", Schritt 1) — allein das Öffnen des Blattes darf '
            'ihn nicht auslösen',
      );
      expect(
        find.byKey(const Key('gewicht-blatt-freigabe')),
        findsNothing,
        reason: 'sonst prüft der Fall darunter nichts',
      );
    });

    testWidgets(
      'bei Verweigerung bleibt das Blatt offen, der Hinweis steht da — '
      'und nichts wird geschrieben',
      (tester) async {
        final h = harness(freigabe: WriteAuthorization.denied);
        await zeige(tester, h.app);
        await oeffneNeu(tester);

        await tippeIns(tester, '58,4');
        await tippe(tester, const Key('gewicht-blatt-sichern'));

        expect(blatt(), findsOneWidget, reason: 'das Blatt bleibt offen');
        expect(find.byKey(const Key('gewicht-blatt-freigabe')), findsOneWidget);
        expect(
          h.quelle.geschrieben,
          isEmpty,
          reason:
              'Lieber gar nicht gesichert als scheinbar gesichert (Spec, '
              '„Anti-Ziele") — und das steht am Mock, nicht am Text',
        );
        expect(h.quelle.geloescht, isEmpty);
      },
    );

    testWidgets('ein weggewischter Dialog zählt wie eine Verweigerung', (
      tester,
    ) async {
      final h = harness(freigabe: WriteAuthorization.notDetermined);
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58,4');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(blatt(), findsOneWidget);
      expect(find.byKey(const Key('gewicht-blatt-freigabe')), findsOneWidget);
      expect(
        h.quelle.geschrieben,
        isEmpty,
        reason: 'Nur `granted` darf schreiben',
      );
    });

    testWidgets('auch beim Ändern wird dann nichts gelöscht', (tester) async {
      final h = harness(freigabe: WriteAuthorization.denied);
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));
      await tippeIns(tester, '58,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(h.quelle.geschrieben, isEmpty);
      expect(
        h.quelle.geloescht,
        isEmpty,
        reason:
            'Die alte Probe ist das Einzige, was noch da ist — sie darf '
            'nicht verschwinden, wenn der Ersatz nie geschrieben wurde',
      );
      expect(blatt(), findsOneWidget);
    });

    testWidgets('mit Freigabe steht der Hinweis nie da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '58,4');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(find.byKey(const Key('gewicht-blatt-freigabe')), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Sichern
  // ───────────────────────────────────────────────────────────────────────

  group('Nach erfolgreichem Sichern', () {
    testWidgets('schließt das Blatt und der Schirm liest neu', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);
      final laeufeVorher = h.quelle.probenLaeufe;

      await tippeIns(tester, '57,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(blatt(), findsNothing, reason: 'das Blatt schließt');
      expect(h.quelle.geschrieben.length, 1);
      expect(h.quelle.geschrieben.single.kg, closeTo(57.9, 1e-9));
      expect(
        h.quelle.probenLaeufe,
        greaterThan(laeufeVorher),
        reason:
            'Der neue Wert erscheint, weil Health ihn liefert — nicht, '
            'weil die App ihn sich gemerkt hat (Spec)',
      );
      expect(
        find.byKey(waegung('neu-1')),
        findsOneWidget,
        reason: 'und er steht danach in „Letzte Messungen"',
      );
    });

    testWidgets('der Zeitpunkt ist „jetzt" aus der Uhr der App', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '57,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(
        h.quelle.geschrieben.single.at.difference(jetzt).abs(),
        lessThan(const Duration(minutes: 1)),
        reason:
            'Vorbelegt ist jetzt (Spec) — und „jetzt" kommt aus '
            '`clockProvider`, nicht aus `DateTime.now()`',
      );
    });

    testWidgets('ein Punkt im Feld ergibt dasselbe Gewicht wie ein Komma', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '57.9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(h.quelle.geschrieben.single.kg, closeTo(57.9, 1e-9));
    });

    testWidgets('„Abbrechen" schreibt nichts und schließt', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneNeu(tester);

      await tippeIns(tester, '57,9');
      await tippe(tester, const Key('gewicht-blatt-abbrechen'));

      expect(blatt(), findsNothing);
      expect(h.quelle.geschrieben, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Zeilen von „Letzte Messungen"
  // ───────────────────────────────────────────────────────────────────────

  group('Nur die manuelle Zeile ist eine Tür', () {
    testWidgets('jede Probe bekommt ihre eigene Zeile', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      for (final probe in dreiProben()) {
        expect(find.byKey(waegung(probe.id)), findsOneWidget, reason: probe.id);
      }
    });

    testWidgets('zwei Wägungen an einem Tag sind zwei Zeilen', (tester) async {
      final h = harness(
        proben: [
          WeightSample(
            id: 'morgens',
            date: zeitpunktVor(0, stundeUtc: 5),
            kg: 58.6,
            wasUserEntered: true,
          ),
          WeightSample(
            id: 'abends',
            date: zeitpunktVor(0, stundeUtc: 18),
            kg: 58.9,
            wasUserEntered: true,
          ),
        ],
      );
      await zeige(tester, h.app);

      expect(find.byKey(waegung('morgens')), findsOneWidget);
      expect(
        find.byKey(waegung('abends')),
        findsOneWidget,
        reason:
            'Genau dafür ist die Probenabfrage da: „Sortierung innerhalb '
            'eines Tages" (Spec)',
      );
    });

    testWidgets('eine Zeile mit `wasUserEntered` öffnet das Blatt mit ihrem '
        'Wert', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));

      expect(blatt(), findsOneWidget);
      expect(
        feldText(tester),
        matches(RegExp(r'58[.,]6')),
        reason:
            'Der alte Wert steht **im** Feld, nicht als Platzhalter (Spec). '
            'Ob mit Komma oder Punkt, ist eine Frage der Schreibweise und '
            'hier nicht festgelegt',
      );
      expect(h.router.nimmBefehl(), isNull, reason: 'ein Blatt, kein Schirm');
    });

    testWidgets('eine Zeile ohne Kennzeichen ist keine Tür', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-waage-a'));

      expect(
        blatt(),
        findsNothing,
        reason:
            'Apple gibt fremde Proben nicht frei — eine Tür, hinter der '
            'nichts geht, wäre ein Versprechen, das die App nicht halten '
            'kann (Spec)',
      );
      expect(h.router.nimmBefehl(), isNull);
    });

    testWidgets('das Kennzeichen kommt aus der Probe, nicht aus einer '
        'eigenen Buchhaltung', (tester) async {
      // Dieselbe UUID, nur das Kennzeichen anders: Eine Markierung, die aus
      // unserer Buchhaltung käme, wäre nach dem ersten Eintrag in der
      // Health-App falsch (Spec, „Anti-Ziele").
      final h = harness(
        proben: [
          WeightSample(
            id: 'aus-der-health-app',
            date: zeitpunktVor(1),
            kg: 58.5,
            wasUserEntered: true,
          ),
        ],
      );
      await zeige(tester, h.app);

      await tippe(tester, waegung('aus-der-health-app'));

      expect(
        blatt(),
        findsOneWidget,
        reason:
            'Diese Probe hat **diese App** nie geschrieben, trägt aber '
            '`wasUserEntered` — sie ist trotzdem eine Tür',
      );
    });

    testWidgets('ohne Wägung bleibt der Abschnitt stehen', (tester) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        proben: const [],
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('messungen-letzte')),
        findsOneWidget,
        reason:
            '„Letzte Messungen" behält Höhe und Platz, wenn es keine '
            'Wägung gibt (Spec)',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Ändern ist Löschen plus Neuschreiben — in dieser Reihenfolge
  // ───────────────────────────────────────────────────────────────────────

  group('Ändern', () {
    testWidgets('schreibt zuerst und löscht erst danach', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));
      await tippeIns(tester, '58,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(h.quelle.geschrieben.single.kg, closeTo(58.9, 1e-9));
      expect(h.quelle.geloescht, ['probe-von-hand']);
      expect(
        h.quelle.protokoll,
        ['schreiben', 'loeschen'],
        reason:
            'HealthKit kennt kein Ändern; die Reihenfolge ist erst '
            'schreiben, dann löschen (Spec)',
      );
      expect(blatt(), findsNothing);
    });

    testWidgets('scheitert das Schreiben, wird die alte Probe nicht gelöscht', (
      tester,
    ) async {
      final h = harness(schreibenScheitert: true);
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));
      await tippeIns(tester, '58,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(
        h.quelle.geloescht,
        isEmpty,
        reason:
            'Sonst wäre der alte Wert weg und der neue nie angekommen — '
            'der schlimmste Ausgang (Spec)',
      );
      expect(
        find.byKey(waegung('probe-von-hand')),
        findsOneWidget,
        reason: 'und die Zeile steht weiter da',
      );
      expect(
        blatt(),
        findsOneWidget,
        reason:
            'Ein Blatt, das sich schließt, behauptet, es sei gesichert '
            'worden',
      );
    });

    testWidgets('„Eintrag löschen" gibt es nur beim Ändern', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await oeffneNeu(tester);
      expect(
        find.byKey(const Key('gewicht-blatt-loeschen')),
        findsNothing,
        reason: 'ein neuer Eintrag hat nichts zu löschen',
      );

      await tippe(tester, const Key('gewicht-blatt-abbrechen'));
      await tippe(tester, waegung('probe-von-hand'));

      expect(find.byKey(const Key('gewicht-blatt-loeschen')), findsOneWidget);
    });

    testWidgets('Löschen entfernt genau diese Probe und schließt das Blatt', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));
      await tippe(tester, const Key('gewicht-blatt-loeschen'));

      expect(h.quelle.geloescht, [
        'probe-von-hand',
      ], reason: 'ohne Rückfrage (Spec, „Was beim Löschen passiert")');
      expect(h.quelle.geschrieben, isEmpty);
      expect(blatt(), findsNothing);
      expect(find.byKey(waegung('probe-von-hand')), findsNothing);
      expect(
        find.byKey(waegung('probe-waage-a')),
        findsOneWidget,
        reason: 'die fremden Proben bleiben, wo sie sind',
      );
    });

    testWidgets('scheitert das Löschen, bleibt das Blatt offen', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);

      await tippe(tester, waegung('probe-von-hand'));
      await tippe(tester, const Key('gewicht-blatt-loeschen'));

      expect(
        blatt(),
        findsOneWidget,
        reason:
            'Ein geschlossenes Blatt behauptete, die Probe sei weg — sie '
            'steht aber noch in Health',
      );
      expect(find.byKey(waegung('probe-von-hand')), findsOneWidget);
    });
  });
}

/// Steuerbarer Ableger des echten Notifiers — siehe `messungen_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

/// Ein kleines HealthKit im Gedächtnis: Es führt Buch über jeden Schreib-,
/// Lösch- und Lesezugriff **und** verhält sich dabei wie die echte Quelle —
/// eine geschriebene Probe taucht beim nächsten Lesen auf, eine gelöschte
/// nicht mehr. Nur so lässt sich „der Schirm liest neu" prüfen, ohne den
/// Provider festzulegen, der die Reihe hält.
///
/// **Der Zeitraum wird bewusst nicht beachtet.** Welches Fenster die App
/// abfragt, überlässt die Spec dem Bauenden; ein hier geprüftes Fenster
/// wäre ein Fenster, das der Test entschieden hat.
class _Quelle extends HealthReadingAttrappe {
  _Quelle({
    required List<WeightSample> proben,
    required this.freigabe,
    this.schreibenScheitert = false,
    this.loeschenScheitert = false,
  }) : _proben = [...proben];

  final List<WeightSample> _proben;
  final WriteAuthorization freigabe;
  final bool schreibenScheitert;
  final bool loeschenScheitert;

  /// Was geschrieben wurde — die Buchführung, an der „nichts wird
  /// gespeichert" hängt.
  final List<({double kg, DateTime at})> geschrieben = [];

  /// Welche UUIDs gelöscht wurden.
  final List<String> geloescht = [];

  /// Beides in der Reihenfolge, in der es passiert ist: `'schreiben'` und
  /// `'loeschen'`. Die Spec legt die Reihenfolge fest, nicht nur die Menge.
  final List<String> protokoll = [];

  /// Wie oft die Probenreihe gelesen wurde.
  int probenLaeufe = 0;

  /// Wie oft der Schreibdialog angefragt wurde.
  int freigabeAnfragen = 0;

  int _naechsteId = 0;

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async {
    freigabeAnfragen += 1;
    return freigabe;
  }

  @override
  Future<String> writeWeight({required double kg, required DateTime at}) async {
    if (schreibenScheitert) {
      protokoll.add('schreiben-gescheitert');
      throw StateError('HealthKit nimmt die Probe nicht an');
    }
    protokoll.add('schreiben');
    geschrieben.add((kg: kg, at: at));
    _naechsteId += 1;
    final id = 'neu-$_naechsteId';
    _proben.add(WeightSample(id: id, date: at, kg: kg, wasUserEntered: true));
    return id;
  }

  @override
  Future<void> deleteWeight(String id) async {
    if (loeschenScheitert) {
      protokoll.add('loeschen-gescheitert');
      throw StateError('HealthKit gibt die Probe nicht frei');
    }
    protokoll.add('loeschen');
    geloescht.add(id);
    _proben.removeWhere((probe) => probe.id == id);
  }

  @override
  Future<List<WeightSample>> weightSamples(
    DateTime from,
    DateTime through,
  ) async {
    probenLaeufe += 1;
    return [..._proben]..sort((a, b) => a.date.compareTo(b.date));
  }
}
