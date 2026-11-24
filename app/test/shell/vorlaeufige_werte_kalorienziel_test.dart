// Das Feld **„Kalorienziel"** im Schirm „Vorläufige Werte" (#410).
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber **nicht verändert** werden — keine
// Zeile, kein Erwartungswert, kein Testname. Wer einen Fall für falsch
// hält, meldet ihn, statt ihn passend zu machen.
//
// ## Woher die Anforderung kommt
//
// Ticket #410 (Tim, 07.11.2026: das Kalorienziel ist fest und ändert sich
// nur noch, wenn jemand es ändert). Ausgestaltung als **Vorgabe des
// Koordinators**, Tim hat die Rückfrage dazu weggeklickt: Ändern geht von
// Hand in „Vorläufige Werte", mit einem neuen Feld „Kalorienziel"; jede
// Änderung gilt ab ihrem Tag, frühere Tage behalten den alten Wert. Später
// kommt der Coach dazu (Vorschlag mit Bestätigung) — nicht Teil dieses
// Tickets.
//
// Die Historie selbst prüft `data/kalorienziele_test.dart`, ihre Wirkung
// auf den Ernährungstag `ernaehrung/kalorienziel_fest_test.dart`. Diese
// Datei prüft nur den Eingang: was das Feld zeigt und was „Sichern"
// ablegt. `vorlaeufige_werte_test.dart` bleibt unverändert und gilt
// weiter.
//
// ## Festgelegt vom Test-Agenten — nicht von Tim freigegeben
//
// - **`Key('vorlaeufige-werte-kalorienziel-feld')`** auf einem
//   `CupertinoTextField` — eine Zahl über einen offenen Bereich, wie das
//   Zielgewicht. Wo im Schirm es steht, prüft niemand.
// - **Vorbelegt mit der Festlegung, die heute gilt**
//   (`geltendeFestlegung`), als ganze kcal. Ohne Festlegung ist das Feld
//   leer und zeigt `–/–` (`ohneWert`), **nicht** die gerechnete Zahl: Die
//   stünde sonst da wie ein festes Ziel, das es nicht gibt.
// - **Gesichert wird nur, was sich geändert hat.** Ein „Sichern", das nur
//   wegen des Zielgewichts gedrückt wird, darf aus einem berechneten Ziel
//   kein Ziel „von Hand" machen — die Herleitung behauptete sonst eine
//   Entscheidung, die niemand getroffen hat. Verglichen wird mit dem, was
//   im Feld **stand**, nicht mit der ungerundeten Zahl dahinter: 2.617,4
//   kcal stehen als „2617" da und dürfen nicht als Änderung gelten.
// - **Eine geänderte Zahl gilt ab heute** (Berliner Tag aus
//   `clockProvider`), Herkunft `hand`, ohne Anteile. Am selben Tag ersetzt
//   sie eine berechnete Festlegung (je Tag ein Ziel).
// - **Unlesbares und Zahlen ≤ 0 lassen sich nicht sichern** — wie beim
//   Zielgewicht. Ein Ziel von 0 kcal stünde sofort auf „erreicht".
// - **Was beim Leeren eines vorbelegten Felds passiert, ist offen** und
//   hier **nicht geprüft**: Ein Ziel zu löschen hieße, wieder täglich zu
//   rechnen — und gleich darauf legte die App von selbst neu fest. Das
//   entscheidet Tim, nicht dieser Test.
//
// ## Erfundene Zahlen
//
// Alle Werte sind erfunden. Der Schirm steht auf dem 02.01.2031 (wie in
// `vorlaeufige_werte_test.dart`), das Geburtsjahr wäre 1901.
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/vorlaeufige_werte_view.dart';

import '../health/health_reading_attrappe.dart';

void main() {
  const heute = '2031-01-02';

  final feld = find.byKey(const Key('vorlaeufige-werte-kalorienziel-feld'));
  final gewichtsFeld = find.byKey(
    const Key('vorlaeufige-werte-zielgewicht-feld'),
  );
  final sichernKnopf = find.byKey(const Key('vorlaeufige-werte-sichern'));

  /// Eine berechnete Festlegung von gestern, mit Nachkommastellen — die
  /// Anzeige rundet, die Tabelle nicht.
  const berechnetGestern = KalorienzielFestlegung(
    abTag: '2031-01-01',
    kcal: 2617.4,
    herkunft: KalorienzielHerkunft.berechnet,
    anteile: KalorienzielAnteile(
      grundumsatzKcal: 1750.4,
      aktivKcal: 700,
      koerperzielKcal: 167,
      gemessen: false,
    ),
  );

  /// Eine ältere, die von der gestrigen abgelöst wurde.
  const aelter = KalorienzielFestlegung(
    abTag: '2030-12-01',
    kcal: 2500,
    herkunft: KalorienzielHerkunft.hand,
  );

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_LeereQuelle()),
        clockProvider.overrideWithValue(() => DateTime.utc(2031, 1, 2, 9)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Baut den Schirm auf, jedes Mal mit **frischem** Behälter über
  /// derselben Datenbank: Was dann dasteht, kam aus der Tabelle.
  Future<void> zeige(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: behaelter(),
        child: const CupertinoApp(home: VorlaeufigeWerteSeite()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> legeAb(List<KalorienzielFestlegung> historie) async {
    final repo = KalorienzielRepository(db);
    for (final f in historie) {
      await repo.setze(f);
    }
  }

  Future<List<KalorienzielFestlegung>> historie() =>
      KalorienzielRepository(db).alle();

  CupertinoTextField kcalFeld(WidgetTester tester) {
    expect(
      feld,
      findsOneWidget,
      reason: 'Das Feld fehlt — siehe Schlüssel im Dateikopf.',
    );
    return tester.widget<CupertinoTextField>(
      find
          .descendant(
            of: feld,
            matching: find.byType(CupertinoTextField),
            matchRoot: true,
          )
          .first,
    );
  }

  String kcalText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: feld, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  /// Nur die Ziffern — ob die Anzeige „2617" oder „2.617" schreibt, ist
  /// Beschriftung, nicht Zustand.
  String ziffern(String text) => text.replaceAll(RegExp(r'\D'), '');

  Future<void> tippe(WidgetTester tester, Finder ziel, String text) async {
    await tester.enterText(ziel, text);
    await tester.pumpAndSettle();
  }

  Future<void> sichere(WidgetTester tester) async {
    await tester.tap(sichernKnopf);
    await tester.pumpAndSettle();
  }

  bool sichernMoeglich(WidgetTester tester) =>
      tester.widget<CupertinoButton>(sichernKnopf).onPressed != null;

  group('Was das Feld zeigt', () {
    testWidgets('ohne Festlegung: leer, mit –/– — nicht 0 und nicht die '
        'gerechnete Zahl', (tester) async {
      await zeige(tester);

      expect(kcalText(tester), isEmpty);
      expect(kcalFeld(tester).placeholder, ohneWert);
    });

    testWidgets('mit Festlegung: die, die heute gilt, in ganzen kcal', (
      tester,
    ) async {
      await legeAb(const [aelter, berechnetGestern]);
      await zeige(tester);

      expect(
        ziffern(kcalText(tester)),
        '2617',
        reason: 'die jüngste Festlegung bis heute, gerundet auf ganze kcal',
      );
    });
  });

  group('Was „Sichern" ablegt', () {
    testWidgets('ohne Eingabe und ohne Festlegung: nichts', (tester) async {
      await zeige(tester);
      await sichere(tester);

      expect(
        await historie(),
        isEmpty,
        reason: 'kein Ziel aus dem Nichts — auch nicht als 0',
      );
    });

    testWidgets('unverändert: nichts Neues — ein berechnetes Ziel wird nicht '
        'stillschweigend eins von Hand', (tester) async {
      await legeAb(const [berechnetGestern]);
      await zeige(tester);

      // „Sichern" wegen des Zielgewichts — das Kalorienziel bleibt, wie es
      // dastand.
      await tippe(tester, gewichtsFeld, '82');
      await sichere(tester);

      expect(await historie(), [berechnetGestern]);
      expect(
        (await StammdatenRepository(db).lies()).zielgewichtKg,
        82,
        reason: 'Vorbedingung: gesichert wurde tatsächlich',
      );
    });

    testWidgets('eine neue Zahl gilt ab heute, von Hand — die früheren '
        'bleiben stehen', (tester) async {
      await legeAb(const [aelter, berechnetGestern]);
      await zeige(tester);

      await tippe(tester, feld, '2650');
      await sichere(tester);

      expect(await historie(), const [
        aelter,
        berechnetGestern,
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 2650,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ]);
    });

    testWidgets('ohne frühere Festlegung: die erste kommt von Hand', (
      tester,
    ) async {
      await zeige(tester);

      await tippe(tester, feld, '2650');
      await sichere(tester);

      expect(await historie(), const [
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 2650,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ]);
    });

    testWidgets('am selben Tag wie eine berechnete: die von Hand ersetzt sie', (
      tester,
    ) async {
      await legeAb(const [
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 2617.4,
          herkunft: KalorienzielHerkunft.berechnet,
        ),
      ]);
      await zeige(tester);

      await tippe(tester, feld, '2700');
      await sichere(tester);

      expect(await historie(), const [
        KalorienzielFestlegung(
          abTag: heute,
          kcal: 2700,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ]);
    });

    testWidgets('Zielgewicht und Kalorienziel zusammen: beide landen', (
      tester,
    ) async {
      await zeige(tester);

      await tippe(tester, gewichtsFeld, '82');
      await tippe(tester, feld, '2650');
      await sichere(tester);

      expect((await StammdatenRepository(db).lies()).zielgewichtKg, 82);
      expect((await historie()).single.kcal, 2650);
    });
  });

  group('Was sich nicht sichern lässt', () {
    testWidgets('Unlesbares', (tester) async {
      await zeige(tester);
      await tippe(tester, feld, 'abc');
      expect(sichernMoeglich(tester), isFalse);
    });

    testWidgets('null kcal — ein Ziel von 0 stünde sofort auf „erreicht"', (
      tester,
    ) async {
      await zeige(tester);
      await tippe(tester, feld, '0');
      expect(sichernMoeglich(tester), isFalse);
    });

    testWidgets('und eine lesbare Zahl lässt sich sichern', (tester) async {
      await zeige(tester);
      await tippe(tester, feld, '2650');
      expect(sichernMoeglich(tester), isTrue);
    });
  });

  group('Eingetragenes überlebt', () {
    testWidgets('nach dem Sichern steht die neue Zahl auch nach dem '
        'Neuaufbau da', (tester) async {
      await zeige(tester);
      await tippe(tester, feld, '2650');
      await sichere(tester);

      await tester.pumpWidget(const SizedBox());
      await zeige(tester);

      expect(ziffern(kcalText(tester)), '2650');
    });
  });
}

/// Eine Quelle, die nichts hergibt — der Schirm fragt Apple Health nicht.
class _LeereQuelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);
}
