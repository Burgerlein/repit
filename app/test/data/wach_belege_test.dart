import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/wach_belege.dart';
import 'package:repit/health/health_provider.dart';

import '../tag/berliner_wanduhr.dart';

/// Tests für das **Repository der Wachbelege** (#454 unter #375,
/// Tagesgrenze) — `WachArt`, `WachbelegRepository` und
/// `wachbelegRepositoryProvider` in `lib/data/wach_belege.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// Die Tabelle selbst (Spalten, Stufe 23) prüft `schema_v23_test.dart`, die
/// Regeln der Tagesgrenze der Kern (`trainings_core/test/tagesgrenze_test.dart`).
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`,
/// Abschnitte „Tabelle `wach_belege`“ und „Repository“, dazu V13 (eigene
/// Belege `oeffnen` und `buchung`, die Tabelle wird nie geleert). Die
/// Vorgaben V1–V18 hat der Planende formuliert; Tim hat sie laut Spec am
/// 10.11.2026 übernommen. Schnittstelle und Pflichtfälle stehen im Plan
/// `docs/superpowers/plans/2026-11-10-tagesgrenze.md`, Task 4:
///
/// - `enum WachArt { oeffnen, buchung }`.
/// - `WachbelegRepository(AppCache db)` mit
///   `Future<void> merke(WachArt art, DateTime zeitpunkt)` und
///   `Future<List<Wachbeleg>> zwischen(DateTime von, DateTime bis)` (beide
///   Grenzen einschließlich; `oeffnen` → `WachQuelle.app`, `buchung` →
///   `WachQuelle.eintrag`).
/// - `merke` schreibt UTC; `zwischen` liefert genau die Belege im Fenster,
///   sortiert, **auch über die Zeitumstellung im Oktober**; eine Zeile mit
///   unbekannter `art` wird übergangen. Gefiltert wird **in SQL**.
///
/// **Warum die Zeitumstellung:** drift legt mit `storeDateTimeAsText` einen
/// UTC-Zeitpunkt als `…Z` ab, eine Ortszeit dagegen als Wanduhr mit
/// angehängtem Versatz (`… +02:00`). Der Vergleich in SQL ist ein
/// Textvergleich. Mit Ortszeiten läge das zweite 02:30 (`+01:00`)
/// lexikografisch vor dem ersten (`+02:00`) — die Spec verlangt den
/// Nachweis durch diesen Test, nicht durch eine Annahme.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Plan und Spec lassen die folgenden Punkte offen; diese Datei legt sie
/// fest:
///
/// - **In der Spalte `art` steht der Name des Enum-Werts** (`oeffnen`,
///   `buchung`) — so beschreibt es der Doc-Kommentar der Tabelle
///   (`wach_beleg_tabelle.dart`), der Plan sagt es nicht ausdrücklich.
/// - **`merke` nimmt auch eine Ortszeit an** und legt sie als denselben
///   Zeitpunkt in UTC ab (Rohtext endet auf `Z`).
/// - **`zwischen` nimmt auch Grenzen in Ortszeit an** und liefert dasselbe
///   wie mit den UTC-Grenzen desselben Zeitpunkts.
/// - **`zwischen` liefert Zeitpunkte als UTC** (`isUtc`), sortiert
///   aufsteigend; ein Beleg ist ein Zeitpunkt (`bis == von`).
/// - **`wachbelegRepositoryProvider` ist ein `Provider<WachbelegRepository>`**
///   über `appCacheProvider`.
///
/// **Alle Zeitpunkte hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“), als Berliner Wanduhr formuliert und über
/// [berlin] gebildet. Die Umstellungstage 2099 sind der 29.03. und der
/// 25.10.
void main() {
  late AppCache db;
  late WachbelegRepository repo;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    repo = WachbelegRepository(db);
  });

  Future<List<WachBelegRow>> zeilen() => (db.select(
    db.wachBelege,
  )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<String>> rohzeitpunkte() async => (await db
          .customSelect('SELECT zeitpunkt FROM wach_belege ORDER BY id')
          .get())
      .map((z) => z.read<String>('zeitpunkt'))
      .toList();

  group('merke', () {
    test('schreibt eine Zeile mit Zeitpunkt in UTC und dem Namen der Art',
        () async {
      final t = berlin('2099-01-12', 23, 10);

      await repo.merke(WachArt.buchung, t);

      final z = (await zeilen()).single;
      expect(z.art, 'buchung');
      expect(z.zeitpunkt, t);
      expect(z.zeitpunkt.isUtc, isTrue);
      expect((await rohzeitpunkte()).single, endsWith('Z'));
    });

    test('oeffnen steht als „oeffnen“ in der Tabelle', () async {
      await repo.merke(WachArt.oeffnen, berlin('2099-01-12', 7, 0));

      expect((await zeilen()).single.art, 'oeffnen');
    });

    test('eine Ortszeit wird als derselbe Zeitpunkt in UTC abgelegt',
        () async {
      final t = berlin('2099-07-15', 1, 30);

      await repo.merke(WachArt.oeffnen, t.toLocal());

      final z = (await zeilen()).single;
      expect(z.zeitpunkt.isUtc, isTrue);
      expect(z.zeitpunkt, t);
      expect(
        (await rohzeitpunkte()).single,
        endsWith('Z'),
        reason: 'Ein Versatz wie „+02:00“ im Text brächte den Vergleich in '
            'SQL über die Zeitumstellung durcheinander',
      );
    });

    test('jeder Aufruf ist eine eigene Zeile, nichts wird ersetzt (V13)',
        () async {
      final t = berlin('2099-01-12', 12, 0);
      await repo.merke(WachArt.oeffnen, t);
      await repo.merke(WachArt.oeffnen, t);
      await repo.merke(WachArt.buchung, t);

      expect(await zeilen(), hasLength(3));
    });
  });

  group('zwischen', () {
    test('liefert genau die Belege im Fenster, beide Grenzen eingeschlossen',
        () async {
      final vorher = berlin('2099-01-12', 3, 59);
      final von = berlin('2099-01-12', 4, 0);
      final mitte = berlin('2099-01-12', 18, 0);
      final bis = berlin('2099-01-13', 8, 0);
      final nachher = berlin('2099-01-13', 8, 1);

      await repo.merke(WachArt.oeffnen, nachher);
      await repo.merke(WachArt.buchung, mitte);
      await repo.merke(WachArt.oeffnen, vorher);
      await repo.merke(WachArt.oeffnen, bis);
      await repo.merke(WachArt.buchung, von);

      expect(await repo.zwischen(von, bis), [
        Wachbeleg(von: von, quelle: WachQuelle.eintrag),
        Wachbeleg(von: mitte, quelle: WachQuelle.eintrag),
        Wachbeleg(von: bis, quelle: WachQuelle.app),
      ]);
    });

    test('oeffnen wird WachQuelle.app, buchung WachQuelle.eintrag', () async {
      final a = berlin('2099-01-12', 9, 0);
      final b = berlin('2099-01-12', 9, 5);
      await repo.merke(WachArt.oeffnen, a);
      await repo.merke(WachArt.buchung, b);

      final belege = await repo.zwischen(a, b);
      expect(belege.map((b) => b.quelle), [WachQuelle.app, WachQuelle.eintrag]);
    });

    test('ein Beleg ist ein Zeitpunkt in UTC (bis == von)', () async {
      final t = berlin('2099-01-12', 22, 15);
      await repo.merke(WachArt.buchung, t.toLocal());

      final beleg = (await repo.zwischen(t, t)).single;
      expect(beleg.von, t);
      expect(beleg.von.isUtc, isTrue);
      expect(beleg.bis, beleg.von);
    });

    test('ohne Belege im Fenster: leere Liste', () async {
      await repo.merke(WachArt.oeffnen, berlin('2099-01-10', 12, 0));

      expect(
        await repo.zwischen(
          berlin('2099-01-12', 4, 0),
          berlin('2099-01-13', 8, 0),
        ),
        isEmpty,
      );
    });

    test('über die Zeitumstellung im Oktober: 01:30, beide 02:30, 03:30 — '
        'genau diese, in zeitlicher Reihenfolge', () async {
      const tag = '2099-10-25';
      final vorher = berlin(tag, 0, 30);
      final a = berlin(tag, 1, 30);
      final b1 = berlin(tag, 2, 30);
      final b2 = berlin(tag, 2, 30, zweites: true);
      final c = berlin(tag, 3, 30);
      final nachher = berlin(tag, 4, 30);
      // Selbstprüfung der Testhilfe: Die doppelte Stunde liegt eine echte
      // Stunde auseinander.
      expect(b2.difference(b1), const Duration(hours: 1));

      // Durcheinander geschrieben, teils als Ortszeit.
      await repo.merke(WachArt.oeffnen, c.toLocal());
      await repo.merke(WachArt.buchung, b2);
      await repo.merke(WachArt.oeffnen, nachher);
      await repo.merke(WachArt.buchung, b1.toLocal());
      await repo.merke(WachArt.oeffnen, vorher.toLocal());
      await repo.merke(WachArt.oeffnen, a);

      expect(await repo.zwischen(a, c), [
        Wachbeleg(von: a, quelle: WachQuelle.app),
        Wachbeleg(von: b1, quelle: WachQuelle.eintrag),
        Wachbeleg(von: b2, quelle: WachQuelle.eintrag),
        Wachbeleg(von: c, quelle: WachQuelle.app),
      ]);
    });

    test('das Fenster kann mitten in der doppelten Stunde enden', () async {
      const tag = '2099-10-25';
      final b1 = berlin(tag, 2, 30);
      final b2 = berlin(tag, 2, 30, zweites: true);
      await repo.merke(WachArt.oeffnen, b1);
      await repo.merke(WachArt.oeffnen, b2);

      // Bis zum ersten 02:45 (Sommerzeit) liegt nur das erste 02:30.
      expect(await repo.zwischen(berlin(tag, 0, 0), berlin(tag, 2, 45)), [
        Wachbeleg(von: b1, quelle: WachQuelle.app),
      ]);
    });

    test('über die Zeitumstellung im März', () async {
      const tag = '2099-03-29';
      final a = berlin(tag, 1, 30); // Winterzeit
      final b = berlin(tag, 3, 30); // Sommerzeit
      await repo.merke(WachArt.oeffnen, b.toLocal());
      await repo.merke(WachArt.buchung, a.toLocal());
      await repo.merke(WachArt.oeffnen, berlin(tag, 4, 0));

      expect(await repo.zwischen(berlin(tag, 1, 0), berlin(tag, 3, 45)), [
        Wachbeleg(von: a, quelle: WachQuelle.eintrag),
        Wachbeleg(von: b, quelle: WachQuelle.app),
      ]);
    });

    test('Grenzen in Ortszeit wirken wie dieselben Zeitpunkte in UTC',
        () async {
      const tag = '2099-10-25';
      final a = berlin(tag, 1, 30);
      final b2 = berlin(tag, 2, 30, zweites: true);
      final c = berlin(tag, 3, 30);
      await repo.merke(WachArt.oeffnen, a);
      await repo.merke(WachArt.oeffnen, b2);
      await repo.merke(WachArt.oeffnen, c);

      expect(
        await repo.zwischen(b2.toLocal(), c.toLocal()),
        await repo.zwischen(b2, c),
      );
      expect(await repo.zwischen(b2.toLocal(), c.toLocal()), hasLength(2));
    });

    test('eine Zeile mit unbekannter Art wird übergangen', () async {
      final von = berlin('2099-01-12', 4, 0);
      final bis = berlin('2099-01-13', 8, 0);
      final t1 = berlin('2099-01-12', 9, 0);
      final t2 = berlin('2099-01-12', 10, 0);
      final t3 = berlin('2099-01-12', 11, 0);

      await repo.merke(WachArt.oeffnen, t1);
      await db
          .into(db.wachBelege)
          .insert(WachBelegeCompanion.insert(zeitpunkt: t2, art: 'puls'));
      await repo.merke(WachArt.buchung, t3);

      expect(await repo.zwischen(von, bis), [
        Wachbeleg(von: t1, quelle: WachQuelle.app),
        Wachbeleg(von: t3, quelle: WachQuelle.eintrag),
      ]);
    });
  });

  group('wachbelegRepositoryProvider', () {
    test('schreibt und liest in den Cache aus appCacheProvider', () async {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [appCacheProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final ausProvider = container.read(wachbelegRepositoryProvider);
      final t = berlin('2099-01-12', 6, 30);
      await ausProvider.merke(WachArt.oeffnen, t);

      expect((await zeilen()).single.zeitpunkt, t);
      expect(await repo.zwischen(t, t), [
        Wachbeleg(von: t, quelle: WachQuelle.app),
      ]);
    });
  });
}
