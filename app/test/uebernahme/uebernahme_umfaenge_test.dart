import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;
import 'package:repit/health/health_provider.dart'
    show appCacheProvider;
import 'package:repit/koerper/umfaenge_provider.dart'
    show umfaengeMessungenProvider;
import 'package:repit/uebernahme/export_datei.dart';
import 'package:repit/uebernahme/trainingsexport_uebernahme.dart';
import 'package:repit/uebernahme/uebernahme_provider.dart';

import 'export_fixtur.dart';
import 'uebernahme_support.dart' show FakeWaehler;

/// **Der echte Weg** der Umfänge-Übernahme (#498): dass der Lauf, den der
/// Schirm anstößt, die Umfänge wirklich schreibt — und dass die Ansichten
/// sie danach sehen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum es diese Datei gibt
///
/// `uebernimmTrainingsexport` bekommt die Umfänge-Ablage als **benannten,
/// nicht verlangten** Parameter (Begründung im Kopf von
/// `test/data/umfaenge_uebernahme_test.dart`: ein Pflichtparameter bräche
/// fünfundzwanzig bestehende Aufrufe). Damit niemand sie stillschweigend
/// weglassen kann, ist hier festgenagelt, dass der Weg über
/// `uebernahmeProvider` sie mitgibt. Das ist die eine Stelle, an der es
/// richtig sein muss.
///
/// Dazu die zweite Hälfte von Spec 7.3: Nach einem Lauf wird invalidiert,
/// was am Stand hängt. Für die Trainings ist das `gymSitzungenProvider`; für
/// die Umfänge ist es `umfaengeMessungenProvider` — sonst zeigte die
/// Umfänge-Übersicht „noch nichts gemessen", obwohl die Übernahme gerade
/// Werte gemeldet hat. Das ist Fehler `01` in neuer Verkleidung.
///
/// Geprüft wird über den Provider, nicht über den Schirm: Wo die Zahlen auf
/// dem Schirm stehen, ist noch nicht entworfen (`docs/screens/screens/
/// import.js` kennt die Umfänge nicht) — und was nicht entworfen ist, wird
/// nicht in einem Test erfunden.
///
/// Alle Zahlen und Zeitpunkte sind **erfunden**, Jahr 2099.
void main() {
  late AppCache db;
  late FakeWaehler waehler;
  late ProviderContainer container;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    waehler = FakeWaehler();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        exportDateiWaehlerProvider.overrideWithValue(waehler),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  void waehleDatei(Object? json) {
    waehler.naechste = ExportDatei(
      name: 'trainingsexport.json',
      bytes: alsBytes(json),
    );
  }

  /// Eine Datei mit einem Training und einer Messung über zwei Maße.
  Object? dateiMitBeidem() => exportDatei(
    sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
    uebrige: {
      'circumferences': [
        {
          'date': zeit(14),
          'values': {'waist': 81.0, 'thigh': 61.0},
        },
      ],
    },
  );

  TrainingsexportUebernommen fertig() {
    final stand = container.read(uebernahmeProvider);
    expect(stand, isA<UebernahmeFertig>(), reason: '$stand');
    return (stand as UebernahmeFertig).ergebnis;
  }

  test('Der Lauf über den Provider schreibt die Umfänge wirklich', () async {
    waehleDatei(dateiMitBeidem());

    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();

    final messungen = await UmfaengeRepository(db).messungen();
    expect(messungen, hasLength(1));
    expect(messungen.single.werte, {
      Umfang.taille: 81.0,
      Umfang.oberschenkelRechts: 61.0,
    });
    expect(BerlinCalendar.dayKey(messungen.single.zeitpunkt), '2099-01-14');
  });

  test('Der Bericht nennt die Umfänge neben den Trainings', () async {
    waehleDatei(dateiMitBeidem());

    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();

    final ergebnis = fertig();
    expect(ergebnis.neu, 1);
    expect(ergebnis.umfaengeNeu, 2);
    expect(ergebnis.umfaengeTage, 1);
  });

  test('Nach dem Lauf sehen die Umfänge-Ansichten den neuen Stand', () async {
    final vorher = await container.read(umfaengeMessungenProvider.future);
    expect(vorher, isEmpty, reason: 'Vor dem Lauf steht nichts da');

    waehleDatei(dateiMitBeidem());
    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();

    final nachher = await container.read(umfaengeMessungenProvider.future);
    expect(
      nachher,
      hasLength(1),
      reason: 'Ohne `ref.invalidate(umfaengeMessungenProvider)` stünde hier '
          'weiter der alte, leere Stand',
    );
    expect(await container.read(gymSitzungenProvider.future), hasLength(1));
  });

  test('Eine abgelehnte Datei schreibt keine Umfänge', () async {
    waehleDatei(fassungEins());

    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();

    expect(container.read(uebernahmeProvider), isA<UebernahmeAbgelehnt>());
    expect(await UmfaengeRepository(db).messungen(), isEmpty);
  });

  test('Zweimal dieselbe Datei verdoppelt nichts', () async {
    waehleDatei(dateiMitBeidem());
    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();
    waehleDatei(dateiMitBeidem());
    await container.read(uebernahmeProvider.notifier).waehleUndUebernimm();

    expect(fertig().umfaengeNeu, 0);
    expect(fertig().umfaengeSchonDa, 2);
    expect((await UmfaengeRepository(db).messungen()).single.werte, hasLength(2));
  });
}
