import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/messungen_view.dart';
import 'package:repit/shell/router.dart';
import '../health/health_reading_attrappe.dart';

/// Was passiert, wenn das Schreiben **trotz erteilter Freigabe** scheitert
/// (#270) — der Zustand, den `gewicht_eintragen_test.dart` offenlässt.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md`,
/// Abschnitt „Wenn es schiefgeht", und die Entwurfszustände
/// `schreiben-gescheitert` und `alter-wert-blieb` in
/// `docs/screens/screens/gewicht-eintragen.js`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Warum es die Datei gibt
///
/// Der Review zu #270 hat die Lücke gefunden: Scheiterte `writeWeight` oder
/// `deleteWeight` nach erteilter Freigabe, passierte **sichtbar nichts** —
/// das Blatt stand da wie vorher, „Sichern" wurde wieder blau, kein Grund
/// stand irgendwo. Richtig daran war, dass nichts als gespeichert galt;
/// falsch war der Weg, der sich daraus öffnete:
///
/// **Schreiben klappt, Löschen der alten Probe scheitert.** Dann steht der
/// neue Wert in Health und der alte auch. Wer „Sichern" noch einmal tippt,
/// schreibt eine **dritte** Probe. Genau dagegen wird der Knopf hier grau.
///
/// ## Die Schlüssel, auf die sich diese Datei festlegt
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gewicht-blatt-fehler` | der Hinweis beider Fehlerfälle |
///
/// Alles andere (`gewicht-blatt`, `-feld`, `-sichern`, `messungen-eintragen`,
/// `messungen-waegung-<uuid>`) ist in `gewicht_eintragen_test.dart`
/// festgelegt und wird hier nur benutzt.
///
/// **Ein gemeinsamer Schlüssel für beide Fälle, nicht zwei.** Sie teilen
/// sich den Platz im Blatt, sie erscheinen nie zugleich, und der
/// Unterschied steckt im Satz — nicht in der Anwesenheit eines Widgets.
/// Zwei Schlüssel zwängen den Bauenden zu zwei Kästen an derselben Stelle.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Der Wortlaut der beiden Sätze.** `CLAUDE.md`: Zustände und
///   Übergänge, nicht Beschriftung.
/// - **Der Freigabefall.** Der steht nebenan und hat seinen eigenen
///   Schlüssel.
///
/// ## Erfundene Zahlen
///
/// Jedes Gewicht und jede UUID hier ist ausgedacht (`CLAUDE.md`).
void main() {
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  WeightSample eigene() => WeightSample(
    id: 'probe-von-hand',
    date: heute.add(const Duration(hours: 5, minutes: 20)),
    kg: 58.6,
    wasUserEntered: true,
  );

  ({ProviderContainer container, _Quelle quelle, Widget app}) harness({
    bool schreibenScheitert = false,
    bool loeschenScheitert = false,
  }) {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final quelle = _Quelle(
      proben: [eigene()],
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
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      quelle: quelle,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: MessungenSeite(router: router)),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
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
  Finder fehler() => find.byKey(const Key('gewicht-blatt-fehler'));

  bool sichernAktiv(WidgetTester tester) =>
      tester
          .widget<CupertinoButton>(
            find.byKey(const Key('gewicht-blatt-sichern')),
          )
          .onPressed !=
      null;

  Future<void> sichere(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('gewicht-blatt-feld')), text);
    await tester.pumpAndSettle();
    await tippe(tester, const Key('gewicht-blatt-sichern'));
  }

  group('Im guten Fall steht nie ein Fehler da', () {
    testWidgets('frisch geöffnet nicht', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-eintragen'));

      expect(fehler(), findsNothing);
    });

    testWidgets('und nach erfolgreichem Sichern auch nicht', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-eintragen'));

      await sichere(tester, '57,9');

      expect(blatt(), findsNothing, reason: 'das Blatt schließt');
      expect(h.quelle.geschrieben.length, 1);
    });
  });

  group('Schreiben gescheitert', () {
    testWidgets('der Hinweis steht da und das Blatt bleibt offen', (
      tester,
    ) async {
      final h = harness(schreibenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-eintragen'));

      await sichere(tester, '57,9');

      expect(blatt(), findsOneWidget);
      expect(
        fehler(),
        findsOneWidget,
        reason:
            'Ohne Satz sähe das Blatt aus wie vorher, und niemand wüsste, '
            'warum nichts passiert ist',
      );
    });

    testWidgets('„Sichern" bleibt aktiv — noch einmal tippen ist richtig', (
      tester,
    ) async {
      final h = harness(schreibenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-eintragen'));

      await sichere(tester, '57,9');

      expect(
        sichernAktiv(tester),
        isTrue,
        reason: 'Es ist nichts in Health gelandet, ein zweiter Versuch ist '
            'gefahrlos',
      );
    });

    testWidgets('und es ist nichts gespeichert', (tester) async {
      final h = harness(schreibenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-eintragen'));

      await sichere(tester, '57,9');

      expect(h.quelle.geschrieben, isEmpty);
      expect(h.quelle.geloescht, isEmpty);
    });
  });

  group('Geschrieben, aber der alte Wert blieb stehen', () {
    testWidgets('der Hinweis steht da und das Blatt bleibt offen', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));

      await sichere(tester, '58,9');

      expect(blatt(), findsOneWidget);
      expect(fehler(), findsOneWidget);
    });

    testWidgets('„Sichern" wird grau — sonst entstünde eine dritte Probe', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));

      await sichere(tester, '58,9');

      expect(
        sichernAktiv(tester),
        isFalse,
        reason:
            'Der neue Wert ist bereits in Health — ein zweiter Tipp '
            'schriebe eine dritte Probe',
      );
    });

    testWidgets('ein zweiter Tipp schreibt tatsächlich nichts nach', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));

      await sichere(tester, '58,9');
      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(
        h.quelle.geschrieben.length,
        1,
        reason: 'genau eine Probe, nicht zwei',
      );
    });

    testWidgets('die Liste wird trotzdem neu gelesen — beide Werte stehen da', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);
      final laeufeVorher = h.quelle.probenLaeufe;

      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));
      await sichere(tester, '58,9');

      expect(
        h.quelle.probenLaeufe,
        greaterThan(laeufeVorher),
        reason:
            'Der neue Wert ist in Health; stünde er nicht in der Liste, '
            'sähe es aus, als wäre gar nichts passiert',
      );
      expect(
        find.byKey(const Key('messungen-waegung-probe-von-hand')),
        findsOneWidget,
        reason: 'der alte steht noch da — und hat dort seine eigene Tür',
      );
    });
  });

  group('Löschen gescheitert', () {
    testWidgets('auch dort steht der Hinweis, nicht nur Stille', (
      tester,
    ) async {
      final h = harness(loeschenScheitert: true);
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));

      await tippe(tester, const Key('gewicht-blatt-loeschen'));

      expect(blatt(), findsOneWidget);
      expect(
        fehler(),
        findsOneWidget,
        reason:
            'Sonst tippt man wieder und wieder auf einen Knopf, der nichts '
            'tut — etwa weil die Probe in der Health-App schon weg ist',
      );
    });
  });
}

/// Dasselbe kleine HealthKit wie in `gewicht_eintragen_test.dart`, auf die
/// Fehlerfälle zugeschnitten. Die Freigabe ist hier **immer** erteilt —
/// darum geht es gerade: was passiert, wenn es trotzdem schiefgeht.
class _Quelle extends HealthReadingAttrappe {
  _Quelle({
    required List<WeightSample> proben,
    this.schreibenScheitert = false,
    this.loeschenScheitert = false,
  }) : _proben = [...proben];

  final List<WeightSample> _proben;
  final bool schreibenScheitert;
  final bool loeschenScheitert;

  final List<({double kg, DateTime at})> geschrieben = [];
  final List<String> geloescht = [];
  int probenLaeufe = 0;
  int _naechsteId = 0;

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async =>
      WriteAuthorization.granted;

  @override
  Future<String> writeWeight({required double kg, required DateTime at}) async {
    if (schreibenScheitert) {
      throw StateError('HealthKit nimmt die Probe nicht an');
    }
    geschrieben.add((kg: kg, at: at));
    _naechsteId += 1;
    final id = 'neu-$_naechsteId';
    _proben.add(WeightSample(id: id, date: at, kg: kg, wasUserEntered: true));
    return id;
  }

  @override
  Future<void> deleteWeight(String id) async {
    if (loeschenScheitert) {
      throw StateError('HealthKit gibt die Probe nicht frei');
    }
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
