import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/schlaf_zustand.dart';

/// Tests für die **Menge, über die geblättert wird** (#177) —
/// `SchlafAuswahlNotifier.blaettere` in `lib/shell/schlaf_auswahl.dart`
/// gegen `SchlafDaten.frueher`/`.spaeter` aus `lib/shell/schlaf_zustand.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Die Anforderung
///
/// Pfeil und Wischgeste sind **dieselben Rückrufe** — das steht so im
/// Quelltext beider Seiten und in `schlaf_wischen_test.dart`: „Dieselbe
/// Grenze wie die Pfeile: über alle geladenen Nächte." Woran beide hängen,
/// ist `SchlafDaten.frueher`/`.spaeter`: Ist das Feld `null`, ist der Knopf
/// aus und die Geste stößt an; trägt es ein Datum, führen beide dorthin.
///
/// Daraus folgt eine Zusicherung, die bisher nirgends geprüft ist:
///
/// > **Was der Zustand als Nachbarn ausweist, ist genau das, wohin
/// > `blaettere` geht.**
///
/// Eine Blätterleiste, deren Pfeil aktiv aussieht und beim Drücken
/// woandershin springt, ist schlimmer als ein blasser Pfeil — genau die
/// Begründung, mit der `SchlafBlaetterleiste` ihre beiden Pfeile immer
/// stehen lässt.
///
/// ## Warum das an einer **von Hand eingetragenen** Nacht hängt
///
/// Seit #131 rechnet der Schirm auf den gemessenen Nächten **mit den
/// eingetragenen darüber** (`naechteMitEintraegen`); der Dateikopf von
/// `schlaf_zustand.dart` sagt es ausdrücklich: „Ab hier rechnet der ganze
/// Schirm auf dieser Liste — Auswahl, Nachbarn und Score sollen dieselbe
/// Reihe sehen, sonst führte das Blättern an einer eingetragenen Nacht
/// vorbei."
///
/// Genau dieser Satz ist hier die Anforderung. Eine eingetragene Nacht an
/// einem Tag **ohne** gemessene Nacht ist der Fall, in dem die beiden
/// Mengen auseinanderfallen können — und zugleich der Normalfall des
/// Tickets, für das es die Eingabe überhaupt gibt: die Nacht, in der die
/// Uhr auf dem Nachttisch lag.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Ob leere Tage erreichbar sein sollten.** Das ist die andere Hälfte
///   von #177 und eine Entwurfsfrage (`schlaf.js` kennt `leer` als Zustand
///   des ganzen Schirms, nicht eines einzelnen Tages). Hier steht nur,
///   dass die beiden Mengen, die es heute gibt, dieselbe sein müssen.
/// - **Das Kalenderblatt.** Es hat seine eigene Menge (die Schlüssel von
///   `SchlafDaten.scores`) und seine eigene Begründung.
/// - **Die Haptik am Rand.** Ein Widget-Test sieht keinen Vibrationsmotor.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt. Keine stammt aus einem Health-Export
/// oder einem Screenshot (`CLAUDE.md`).
void main() {
  // Donnerstag, 29.10.2026, 09:00 Berlin (CET seit dem 25.10., also +1).
  final jetzt = DateTime.utc(2026, 10, 29, 8);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  /// Eine schlichte Nacht: ein Kern-Abschnitt von sieben Stunden, der um
  /// 23:00 Berliner Zeit des Vortags beginnt.
  SleepNight nachtVon(int tag) {
    final ende = tagesbeginn(tag);
    final beginn = ende.subtract(const Duration(hours: 1));
    return SleepNight(
      date: ende,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(const Duration(hours: 7)),
          ),
        ],
      ),
      naps: const [],
    );
  }

  /// Gemessen sind der 26., 27. und 28.; der **29.** kommt gleich von Hand
  /// dazu und hat keine gemessene Entsprechung.
  final gemessen = [nachtVon(26), nachtVon(27), nachtVon(28)];

  /// Der Behälter samt Ablage: `schlafEintraegeProvider` schreibt durch bis
  /// in die Datenbank, also bekommt er eine — überschrieben wird er nicht,
  /// sonst prüfte der Test seine eigene Attrappe.
  ({ProviderContainer container, AppCache db}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(gemessen, stand: jetzt, laeuft: false),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  /// Alles geladen **und** die Nacht auf den 29. von Hand eingetragen.
  Future<ProviderContainer> mitEingetragenerNacht() async {
    final (:container, :db) = behaelter();
    container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
    await container.read(sleepProvider.future);
    await container.read(zieleProvider.future);
    await container.read(schlafEintraegeProvider.future);
    await container
        .read(schlafEintraegeProvider.notifier)
        .setzeNacht(
          tag: '2026-10-29',
          schlafMinuten: 400,
          beginnMinuten: 23 * 60 + 30,
          endeMinuten: 6 * 60 + 10,
        );
    return container;
  }

  SchlafDaten datenVon(ProviderContainer container) =>
      (container.read(schlafProvider).daten as Bekannt<SchlafDaten>).wert;

  group('Blättern und Zustand kennen dieselbe Menge (#177)', () {
    test('die eingetragene Nacht steht oben, und davor liegt die gemessene '
        'Nacht vom Vortag', () async {
      final container = await mitEingetragenerNacht();
      final daten = datenVon(container);

      // Vorbedingung, damit die beiden Tests darunter das prüfen, was sie
      // zu prüfen vorgeben: Der Schirm zeigt den 29.
      expect(daten.nacht!.nacht.date, tagesbeginn(29));
      expect(daten.nacht!.vonHand, isNotNull);
      expect(daten.frueher, tagesbeginn(28));
      expect(daten.spaeter, isNull);
    });

    test('blaettere(frueher) geht dorthin, wohin SchlafDaten.frueher zeigt — '
        'nicht eine Nacht daran vorbei', () async {
      final container = await mitEingetragenerNacht();
      final ziel = datenVon(container).frueher;

      container
          .read(schlafAuswahlProvider.notifier)
          .blaettere(SchlafBlaettern.frueher);

      expect(
        datenVon(container).nacht!.nacht.date,
        ziel,
        reason:
            'Der Pfeil wies auf den 28.; gelandet ist der Schirm '
            'woanders. Pfeil und Geste hängen an SchlafDaten.frueher, '
            'blaettere rechnet seine Nachbarn über eine andere Liste.',
      );
    });

    test('und von dort führt blaettere(spaeter) auf die eingetragene Nacht '
        'zurück — sie ist keine Sackgasse', () async {
      final container = await mitEingetragenerNacht();
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.frueher);
      final zurueck = datenVon(container).spaeter;
      expect(
        zurueck,
        tagesbeginn(29),
        reason:
            'Von der gemessenen Nacht des 28. aus muss die eingetragene '
            'Nacht des 29. der nächste Nachbar sein.',
      );

      notifier.blaettere(SchlafBlaettern.spaeter);

      expect(datenVon(container).nacht!.nacht.date, tagesbeginn(29));
    });
  });
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
