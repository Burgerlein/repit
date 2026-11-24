import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import 'health_schreiben_attrappe.dart';

/// Streichen in der Mahlzeitenzeile nimmt die Health-Kopie mit (#283).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Warum es diese Datei gibt
///
/// Löschen hat **zwei** Eingänge: „Löschen" im Buchungsblatt
/// (`ErfassenNotifier.loesche`, geprüft in `health_schreiben_test.dart`)
/// und das Streichen auf dem Mahlzeiten-Schirm. Der zweite ruft heute
/// `ErnaehrungRepository.loesche` direkt auf und ginge an jeder
/// Health-Logik vorbei — die Probe bliebe in Apple Health stehen, und
/// andere Apps zählten eine Mahlzeit, die es nicht mehr gibt.
///
/// Spec `2026-11-03-ernaehrung-design.md`, „Löschen": Ein gelöschter
/// Eintrag wird über seine gespeicherte UUID auch aus Health gelöscht;
/// schlägt das fehl, ist das **kein Fehler für den Nutzer**.
///
/// Geprüft werden nur **Zustände und Übergänge** — nicht, wie die Zeile
/// aussieht. Die Schlüssel `mahlzeit-eintrag-<id>` und
/// `mahlzeit-rueckgaengig` sind die aus `mahlzeit_view_test.dart`.
///
/// ## Festlegung dieser Datei — nicht von Tim freigegeben
///
/// **Nach „Rückgängig" behauptet die Zeile keine Kopie, die es nicht mehr
/// gibt.** Die alte Probe ist beim Streichen gelöscht worden. Steht die
/// Zeile danach mit der alten UUID auf `geschrieben`, glaubt die App an
/// eine Kopie, die fehlt, und der Nachlauf holt sie nie nach. Ob die Zeile
/// sofort neu geschrieben wird oder auf `offen` steht, bleibt offen.
///
/// Zahlen, Namen und Kennungen in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const alteUuid = 'C0FFEE00-0000-0000-0000-0000000000AA';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  Eintrag eintrag({String? healthUuid, HealthStand stand = HealthStand.offen}) =>
      Eintrag(
        tagesSchluessel: heute,
        mahlzeit: Mahlzeit.fruehstueck,
        zeitpunkt: DateTime.utc(2026, 7, 14, 6),
        name: 'Testbrei',
        naehrwerte: const Naehrwerte(kcal: 300, eiweissG: 10),
        healthUuid: healthUuid,
        healthStand: stand,
      );

  Future<({ProviderContainer container, ErnaehrungRepository repo, Widget app})>
  harness(SchreibAttrappe health, Eintrag vorhanden) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ErnaehrungRepository(db);
    await repo.buche(vorhanden);

    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(health),
        stammdatenProvider.overrideWith(() => _Stammdaten(vollstaendig)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(
              [
                const DailyMetrics(
                  tag: heute,
                  activeKcal: 600,
                  basalKcal: 1600,
                  weightKg: 80,
                ),
              ],
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
      repo: repo,
      app: UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            child: MahlzeitView(
              tagesSchluessel: heute,
              mahlzeit: Mahlzeit.fruehstueck,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> streiche(WidgetTester tester, int id) async {
    await tester.drag(
      find.byKey(Key('mahlzeit-eintrag-$id')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Streichen eines geschriebenen Eintrags löscht auch seine '
      'Probe in Health', (tester) async {
    final health = SchreibAttrappe();
    final h = await harness(
      health,
      eintrag(healthUuid: alteUuid, stand: HealthStand.geschrieben),
    );
    await zeige(tester, h.app);
    final id = (await h.repo.eintraegeAmTag(heute)).single.id!;

    await streiche(tester, id);

    expect(health.loeschVersuche, [alteUuid]);
    expect(await h.repo.eintraegeAmTag(heute), isEmpty);
  });

  testWidgets('scheitert das Löschen in Health, ist die Zeile trotzdem weg — '
      'ohne Ausnahme', (tester) async {
    final health = SchreibAttrappe()..loeschFehler = StateError('Probe schon weg');
    final h = await harness(
      health,
      eintrag(healthUuid: alteUuid, stand: HealthStand.geschrieben),
    );
    await zeige(tester, h.app);
    final id = (await h.repo.eintraegeAmTag(heute)).single.id!;

    await streiche(tester, id);

    expect(tester.takeException(), isNull);
    expect(find.byKey(Key('mahlzeit-eintrag-$id')), findsNothing);
    expect(await h.repo.eintraegeAmTag(heute), isEmpty);
  });

  testWidgets('ein Eintrag ohne Kopie wird gestrichen, ohne Health zu '
      'fragen', (tester) async {
    final health = SchreibAttrappe();
    final h = await harness(health, eintrag());
    await zeige(tester, h.app);
    final id = (await h.repo.eintraegeAmTag(heute)).single.id!;

    await streiche(tester, id);

    expect(health.loeschVersuche, isEmpty);
    expect(await h.repo.eintraegeAmTag(heute), isEmpty);
  });

  testWidgets('nach Rückgängig behauptet die Zeile keine gelöschte Kopie', (
    tester,
  ) async {
    final health = SchreibAttrappe();
    final h = await harness(
      health,
      eintrag(healthUuid: alteUuid, stand: HealthStand.geschrieben),
    );
    await zeige(tester, h.app);
    final id = (await h.repo.eintraegeAmTag(heute)).single.id!;

    await streiche(tester, id);
    await tester.tap(find.byKey(const Key('mahlzeit-rueckgaengig')));
    await tester.pumpAndSettle();

    final zurueck = (await h.repo.eintraegeAmTag(heute)).single;
    expect(zurueck.name, 'Testbrei');
    expect(
      zurueck.healthUuid == alteUuid &&
          zurueck.healthStand == HealthStand.geschrieben,
      isFalse,
      reason:
          'die Probe $alteUuid ist gelöscht; wer sie weiter als Kopie '
          'führt, holt sie nie nach',
    );
    if (zurueck.healthStand == HealthStand.geschrieben) {
      expect(
        health.geschrieben.map((k) => k.id),
        contains(zurueck.healthUuid),
        reason: 'geschrieben heißt: diese Kennung hat Health vergeben',
      );
    }
  });
}

/// Steuerbare Ableger der echten Notifier — dieselbe Bauart wie in
/// `mahlzeit_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}
