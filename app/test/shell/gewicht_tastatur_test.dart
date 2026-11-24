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

/// Die Tastatur muss mit dem Blatt verschwinden (#301).
///
/// **Tims Befund vom 03.11.2026, auf dem Gerät:** „ich war noch im Textfeld,
/// habe gespeichert, jetzt steht das Textfeld dauerhaft da." Der Wert war
/// gesichert und stand in der Liste — nur die Tastatur blieb über dem
/// Messungen-Schirm liegen und ging nicht mehr weg.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Warum das hier prüfbar ist
///
/// Die Tastatur gehört iOS, ihre Sichtbarkeit nicht. Was Flutter steuert,
/// ist die **Texteingabe-Verbindung**: `TextInput.show` und `TextInput.hide`
/// über den Platform-Channel `flutter/textinput`. `tester.testTextInput`
/// schneidet genau die mit, und `isVisible` sagt, ob zuletzt `show` oder
/// `hide` gesendet wurde. Bleibt sie nach dem Schließen des Blattes `true`,
/// hat niemand den Fokus losgelassen — und auf dem Gerät steht die Tastatur
/// dann da, bis man woanders hintippt.
///
/// Das ist kein Layout-Test und kein Beschriftungs-Test, sondern ein
/// Übergang: Blatt zu → Eingabe zu. Genau die Sorte, die `CLAUDE.md` für
/// Views vorsieht.
///
/// ## Der Verdacht, den diese Datei prüft
///
/// Das Feld trägt `autofocus: true`, und vor `Navigator.pop()` steht
/// nirgends ein `unfocus`. Deshalb prüfen die Fälle unten **jeden** Weg aus
/// dem Blatt heraus, nicht nur „Sichern": Ginge es allein um den
/// Sicherweg, wäre die Ursache eine andere als der Fokus.
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

  ({ProviderContainer container, _Quelle quelle, Widget app}) harness() {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final quelle = _Quelle(proben: [eigene()]);

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

  /// Öffnet das Blatt und tippt etwas ins Feld — danach ist die
  /// Texteingabe offen, so wie bei Tim.
  Future<void> oeffneUndTippe(WidgetTester tester, String text) async {
    await tippe(tester, const Key('messungen-eintragen'));
    await tester.enterText(find.byKey(const Key('gewicht-blatt-feld')), text);
    await tester.pumpAndSettle();
  }

  group('Beim Öffnen geht die Tastatur auf', () {
    testWidgets('sonst prüfen die Fälle darunter nichts', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(tester.testTextInput.isVisible, isFalse);

      await oeffneUndTippe(tester, '57,9');

      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason:
            'Das Feld trägt `autofocus` — ohne offene Eingabe wäre der '
            'Befund hier nicht nachstellbar',
      );
    });
  });

  group('Beim Schließen geht sie wieder zu', () {
    testWidgets('nach „Sichern" — Tims Fall', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneUndTippe(tester, '57,9');

      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(blatt(), findsNothing, reason: 'das Blatt schließt');
      expect(h.quelle.geschrieben.length, 1, reason: 'und der Wert ist drin');
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason:
            'Tim, 03.11.2026: Der Wert war gesichert, aber die Tastatur '
            'blieb über dem Messungen-Schirm liegen',
      );
    });

    testWidgets('nach „Abbrechen"', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await oeffneUndTippe(tester, '57,9');

      await tippe(tester, const Key('gewicht-blatt-abbrechen'));

      expect(blatt(), findsNothing);
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason:
            'Abbrechen geht denselben Weg hinaus — bliebe die Tastatur nur '
            'beim Sichern, läge die Ursache nicht am Fokus',
      );
    });

    testWidgets('nach „Eintrag löschen"', (tester) async {
      final h = harness();
      await zeige(tester, h.app);
      await tippe(tester, const Key('messungen-waegung-probe-von-hand'));
      await tester.enterText(
        find.byKey(const Key('gewicht-blatt-feld')),
        '58,9',
      );
      await tester.pumpAndSettle();

      await tippe(tester, const Key('gewicht-blatt-loeschen'));

      expect(blatt(), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });

  group('Beim Stehenbleiben bleibt sie offen', () {
    testWidgets('ein Fehler schließt die Eingabe nicht mit', (tester) async {
      // Der Gegenprobe-Fall: Würde die Behebung einfach immer die Tastatur
      // zumachen, fiele sie auch dann zu, wenn das Blatt offen bleibt —
      // und Tim müsste nach einem Fehler erst wieder ins Feld tippen, um
      // seinen Wert zu korrigieren.
      final h = harness();
      h.quelle.freigabe = WriteAuthorization.denied;
      await zeige(tester, h.app);
      await oeffneUndTippe(tester, '57,9');

      await tippe(tester, const Key('gewicht-blatt-sichern'));

      expect(blatt(), findsOneWidget, reason: 'das Blatt bleibt offen');
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'und damit auch die Tastatur — der Wert wird ja gleich '
            'weiterbearbeitet',
      );
    });
  });
}

/// Dasselbe kleine HealthKit wie nebenan, hier mit umschaltbarer Freigabe.
class _Quelle extends HealthReadingAttrappe {
  _Quelle({required List<WeightSample> proben}) : _proben = [...proben];

  final List<WeightSample> _proben;
  WriteAuthorization freigabe = WriteAuthorization.granted;

  final List<({double kg, DateTime at})> geschrieben = [];
  final List<String> geloescht = [];
  int _naechsteId = 0;

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async =>
      freigabe;

  @override
  Future<String> writeWeight({required double kg, required DateTime at}) async {
    geschrieben.add((kg: kg, at: at));
    _naechsteId += 1;
    final id = 'neu-$_naechsteId';
    _proben.add(WeightSample(id: id, date: at, kg: kg, wasUserEntered: true));
    return id;
  }

  @override
  Future<void> deleteWeight(String id) async {
    geloescht.add(id);
    _proben.removeWhere((probe) => probe.id == id);
  }

  @override
  Future<List<WeightSample>> weightSamples(
    DateTime from,
    DateTime through,
  ) async => [..._proben]..sort((a, b) => a.date.compareTo(b.date));
}
