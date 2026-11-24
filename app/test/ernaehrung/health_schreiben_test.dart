import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import 'health_schreiben_attrappe.dart';

/// Die Kopie nach Apple Health, verdrahtet (#283, mit #232) — Buchen,
/// Ändern, Löschen und der Nachlauf für `offen`e Einträge.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. Hält der Implementierende einen Fall für falsch, wird das
/// **gemeldet, nicht korrigiert**.
///
/// ## Woher die Regeln kommen
///
/// - `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`:
///   „Die eigene Tabelle ist die Wahrheit, Apple Health bekommt eine
///   Kopie", „Wenn die Schreibfreigabe fehlt" (gebucht wird immer; ein
///   Hinweis einmal, nicht je Eintrag; Nachlauf trägt alles `offen`e nach;
///   `nicht_moeglich` wird nicht endlos versucht), „Löschen" (ein
///   fehlgeschlagenes Löschen ist kein Fehler für den Nutzer), „Der
///   Ernährungs-Dialog erscheint beim ersten Buchen, nicht beim Start —
///   wer nie etwas einträgt, wird nie gefragt".
/// - `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Task 5 und Review
///   Focus 2 (fehlende Ballaststoffe bleiben `null`).
/// - `CLAUDE.md`: `nil` wird nie `0`; in Tests ist Riverpods Wiederholung
///   abgeschaltet.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// In `lib/health/health_reading.dart`, **im Protokoll `HealthReading`**
/// (Plan, Task 5, „Interfaces"; Spec: „in demselben Protokoll" wie
/// `writeWeight`):
///
/// ```dart
/// Future<WriteAuthorization> requestNutritionWriteAuthorization();
/// Future<String> writeMeal({
///   required Naehrwerte werte,
///   required String name,
///   required DateTime at,
/// });
/// Future<void> deleteMeal(String id);
/// ```
///
/// In `lib/health/health_types.dart`:
///
/// ```dart
/// /// HealthKit hat die Mahlzeit endgültig abgelehnt — der Eintrag wird
/// /// `nicht_moeglich` und nicht erneut versucht. Jeder andere Fehler aus
/// /// `writeMeal` lässt ihn `offen`.
/// class HealthWriteRejected implements Exception {
///   HealthWriteRejected([this.message]);   // darf auch `const` sein
///   final String? message;
/// }
/// ```
///
/// In `lib/ernaehrung/erfassen_provider.dart`:
///
/// ```dart
/// class ErfassenNotifier extends Notifier<void> {
///   // bestehend: buche, aendere, loesche — sie schreiben jetzt auch die
///   // Kopie, und zwar **abgewartet**: Nach `await buche(…)` steht fest,
///   // was aus der Kopie geworden ist.
///
///   /// Trägt alle Einträge mit `HealthStand.offen` nach — über alle Tage.
///   /// Fragt die Freigabe **nur**, wenn es etwas nachzutragen gibt.
///   Future<void> healthNachlauf();
/// }
///
/// /// Ob der Hinweis „Health-Schreiben nicht erlaubt" ansteht.
/// final healthSchreibHinweisProvider =
///     NotifierProvider<HealthSchreibHinweisNotifier, bool>(…);
///
/// class HealthSchreibHinweisNotifier extends Notifier<bool> {
///   @override
///   bool build() => false;
///   /// Der Hinweis wurde gezeigt; er kommt in diesem Lauf nicht wieder.
///   void gesehen();
/// }
/// ```
///
/// Wie und wo der Hinweis **aussieht**, legt diese Datei nicht fest: Der
/// Entwurf `erfassen` hat den Zustand `keine-freigabe` noch nicht (Spec:
/// „das Erfassen bekommt den gleichen" wie `gewicht-eintragen`). Das gehört
/// erst aufs Board.
///
/// ## Festlegungen dieser Datei — nicht von Tim freigegeben
///
/// - **Die Kopie wird abgewartet.** `buche`, `aendere` und `loesche`
///   kehren erst zurück, wenn der Health-Teil durch ist. Sonst könnte kein
///   Test sagen, wann „geschrieben" gilt, und ein Nachlauf liefe gegen
///   einen halb geschriebenen Eintrag.
/// - **Nur `HealthWriteRejected` macht `nicht_moeglich`.** Die Spec: „der
///   Fall, in dem HealthKit den Typ abgelehnt hat. Der wird nicht endlos
///   erneut versucht." Alles andere — fehlende Freigabe, gesperrtes Gerät,
///   ein unbekannter Fehler — bleibt `offen` und wird beim nächsten
///   Nachlauf wieder versucht. `nicht_moeglich` ist endgültig, und eine für
///   immer aufgegebene Kopie ist teurer als ein Versuch zu viel. Welche
///   HealthKit-Fehler auf der Swift-Seite als endgültig gelten, legt
///   `HealthNutritionWritingTests.swift` fest.
/// - **Ein Eintrag ohne einen einzigen schreibbaren Nährwert wird
///   `nicht_moeglich`**, ohne Schreibversuch. Es gibt nichts zu kopieren,
///   und `offen` hieße, dass der Nachlauf ihn bei jedem Start erneut
///   anfasst. (Die Swift-Seite lehnt so eine Mahlzeit als `badArgs` ab.)
/// - **Der Hinweis kommt einmal je App-Lauf** — genauer: je
///   `ProviderContainer`. Nach `gesehen()` kommt er nicht wieder, auch
///   wenn weiter ohne Freigabe gebucht wird. Ob er nach einem Neustart
///   wiederkommen soll, ist offen; die Spec sagt nur „nicht bei jedem
///   Eintrag".
/// - **Wer mit Freigabe bucht, nimmt die älteren `offen`en Einträge mit.**
///   Die Spec: „Wird die Freigabe später erteilt, trägt ein Nachlauf alles
///   `offen`e nach." Der Moment, in dem die App das erfährt, ist die
///   nächste Anfrage mit `granted` — und die nächste Anfrage ist das
///   nächste Buchen. Ob zusätzlich beim Start nachgetragen wird, bleibt dem
///   Implementierenden; dann gilt der Fall „nichts offen → keine Anfrage".
/// - **Ändern löscht die alte Probe und schreibt eine neue.** HealthKit
///   kennt kein Ändern. Schlägt das Löschen fehl, wird trotzdem
///   geschrieben (die Probe ist meist schon weg). Fehlt beim Ändern die
///   Freigabe, steht der Eintrag wieder auf `offen` und **behält die alte
///   UUID** als Merker: Drüben liegt eine veraltete Kopie, und der Nachlauf
///   räumt sie weg, bevor er die neue schreibt — sonst stünde dieselbe
///   Mahlzeit zweimal in Health.
///
/// ## #320 — die Attrappen
///
/// Die rund 36 Attrappen der Form `class … implements HealthReading` unter
/// `app/test/` erben seit diesem Zweig von einer gemeinsamen Basis,
/// `test/health/health_reading_attrappe.dart` (Entscheidung des
/// Koordinators, nicht Tims). Die drei neuen Methoden stehen dort schon
/// und werfen; eine weitere neue Methode macht künftig **eine** Datei rot
/// statt sechsunddreißig.
///
/// Zahlen, Namen und Daten in dieser Datei sind erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  /// Ein Brei **ohne Ballaststoffangabe** (Review Focus 2) und ohne
  /// Zucker, gesättigte Fette und Wasser.
  const brei = Naehrwerte.je100g(
    kcal: 120,
    eiweissG: 4,
    kohlenhydrateG: 20,
    fettG: 2,
  );

  late SchreibAttrappe health;
  late AppCache db;
  late ProviderContainer container;
  late ErnaehrungRepository repo;

  setUp(() {
    health = SchreibAttrappe();
    db = AppCache(NativeDatabase.memory());
    repo = ErnaehrungRepository(db);
    container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(health),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ErfassenNotifier erfassen() => container.read(erfassenProvider.notifier);

  BuchungsFormular formular({
    String name = 'Testbrei',
    String menge = '100',
    Naehrwerte je100g = brei,
    String tag = heute,
    int minuten = 8 * 60,
  }) => BuchungsFormular(
    name: name,
    je100g: je100g,
    tagesSchluessel: tag,
    mengeText: menge,
    mahlzeit: Mahlzeit.fruehstueck,
    minutenSeitMitternacht: minuten,
  );

  /// Ein Eintrag direkt in der Tabelle — für Lagen, die vor dem Fall
  /// entstanden sind (gebucht ohne Freigabe, schon geschrieben, …).
  Future<Eintrag> liegtSchon({
    String name = 'Testbrei',
    String tag = heute,
    int stundeUtc = 6,
    Naehrwerte naehrwerte = const Naehrwerte(kcal: 300, eiweissG: 10),
    String? healthUuid,
    HealthStand healthStand = HealthStand.offen,
  }) async {
    final teile = tag.split('-').map(int.parse).toList();
    await repo.buche(
      Eintrag(
        tagesSchluessel: tag,
        mahlzeit: Mahlzeit.fruehstueck,
        zeitpunkt: DateTime.utc(teile[0], teile[1], teile[2], stundeUtc),
        name: name,
        naehrwerte: naehrwerte,
        healthUuid: healthUuid,
        healthStand: healthStand,
      ),
    );
    return (await repo.eintraegeAmTag(tag)).singleWhere((e) => e.name == name);
  }

  Future<Eintrag> einziger([String tag = heute]) async =>
      (await repo.eintraegeAmTag(tag)).single;

  Future<Eintrag> namens(String name, [String tag = heute]) async =>
      (await repo.eintraegeAmTag(tag)).singleWhere((e) => e.name == name);

  // ───────────────────────────────────────────────────────────────────────

  group('Buchen schreibt die Kopie nach Health', () {
    test('mit Freigabe: genau eine Mahlzeit, und ihre Kennung steht am '
        'Eintrag', () async {
      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(health.geschrieben, hasLength(1));
      expect(eintrag.healthUuid, health.geschrieben.single.id);
      expect(eintrag.healthStand, HealthStand.geschrieben);
    });

    test('geschrieben werden Name, Zeitpunkt und die eingefrorenen Werte '
        'des Eintrags', () async {
      await erfassen().buche(formular(menge: '250'));

      final eintrag = await einziger();
      final kopie = health.geschrieben.single;
      expect(kopie.name, 'Testbrei');
      expect(kopie.at.isAtSameMomentAs(eintrag.zeitpunkt), isTrue);
      expect(kopie.werte, eintrag.naehrwerte);
      expect(kopie.werte.kcal, closeTo(300, 1e-9));
    });

    test('eine fehlende Ballaststoffangabe geht als null hinüber, nicht '
        'als 0', () async {
      await erfassen().buche(formular());

      final werte = health.geschrieben.single.werte;
      expect(werte.ballaststoffeG, isNull);
      expect(werte.zuckerG, isNull);
      expect(werte.gesaettigtG, isNull);
      expect(werte.wasserMl, isNull);
    });

    test('ein Eintrag ganz ohne schreibbaren Nährwert wird nicht_moeglich, '
        'ohne Schreibversuch', () async {
      await erfassen().buche(formular(je100g: const Naehrwerte.je100g()));

      final eintrag = await einziger();
      expect(eintrag.healthStand, HealthStand.nichtMoeglich);
      expect(health.schreibVersuche, isEmpty);
    });

    test('ein endgültig abgelehnter Eintrag ist gebucht und '
        'nicht_moeglich', () async {
      health.schreibFehlerFuer['Testbrei'] = HealthWriteRejected();

      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(eintrag.healthStand, HealthStand.nichtMoeglich);
      expect(eintrag.healthUuid, isNull);
    });
  });

  group('Ohne Freigabe wird trotzdem gebucht', () {
    test('verweigert: der Eintrag steht da, offen, ohne Kennung', () async {
      health.freigabe = WriteAuthorization.denied;

      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(eintrag.name, 'Testbrei');
      expect(eintrag.healthStand, HealthStand.offen);
      expect(eintrag.healthUuid, isNull);
      expect(health.schreibVersuche, isEmpty);
    });

    test('weggewischter Dialog zählt wie verweigert', () async {
      health.freigabe = WriteAuthorization.notDetermined;

      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(eintrag.healthStand, HealthStand.offen);
      expect(health.schreibVersuche, isEmpty);
    });

    test('wirft die Anfrage, wird trotzdem gebucht und buche wirft '
        'nicht', () async {
      health.anfrageFehler = StateError('HealthKit nicht verfügbar');

      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(eintrag.healthStand, HealthStand.offen);
    });

    test('scheitert das Schreiben vorübergehend, bleibt der Eintrag offen '
        'und buche wirft nicht', () async {
      health.schreibFehlerFuer['Testbrei'] = StateError('Gerät gesperrt');

      await erfassen().buche(formular());

      final eintrag = await einziger();
      expect(eintrag.healthStand, HealthStand.offen);
      expect(eintrag.healthUuid, isNull);
    });

    test('der Hinweis steht nach dem ersten Buchen ohne Freigabe an', () async {
      health.freigabe = WriteAuthorization.denied;
      expect(container.read(healthSchreibHinweisProvider), isFalse);

      await erfassen().buche(formular());

      expect(container.read(healthSchreibHinweisProvider), isTrue);
    });

    test('der Hinweis kommt einmal, nicht je Eintrag', () async {
      health.freigabe = WriteAuthorization.denied;
      final abo = container.listen(healthSchreibHinweisProvider, (_, _) {});
      addTearDown(abo.close);

      await erfassen().buche(formular(name: 'Erster'));
      expect(container.read(healthSchreibHinweisProvider), isTrue);
      container.read(healthSchreibHinweisProvider.notifier).gesehen();
      expect(container.read(healthSchreibHinweisProvider), isFalse);

      await erfassen().buche(formular(name: 'Zweiter'));
      await erfassen().buche(formular(name: 'Dritter'));

      expect(
        container.read(healthSchreibHinweisProvider),
        isFalse,
        reason: 'Spec: „einmal ein Hinweis — nicht bei jedem Eintrag"',
      );
      expect(await repo.eintraegeAmTag(heute), hasLength(3));
    });

    test('mit Freigabe steht kein Hinweis an', () async {
      await erfassen().buche(formular());

      expect(container.read(healthSchreibHinweisProvider), isFalse);
    });
  });

  group('Ändern eines geschriebenen Eintrags', () {
    test('alte Probe löschen, neue schreiben, neue Kennung', () async {
      await erfassen().buche(formular());
      final vorher = await einziger();
      final alteUuid = vorher.healthUuid!;

      await erfassen().aendere(BuchungsFormular.fuer(vorher).mitMenge('200'));

      final nachher = await einziger();
      expect(nachher.id, vorher.id, reason: 'dieselbe Zeile, kein zweites Buchen');
      expect(health.loeschVersuche, [alteUuid]);
      expect(health.geschrieben, hasLength(2));
      expect(nachher.healthUuid, health.geschrieben.last.id);
      expect(nachher.healthUuid, isNot(alteUuid));
      expect(nachher.healthStand, HealthStand.geschrieben);
      expect(health.geschrieben.last.werte, nachher.naehrwerte);
      expect(health.geschrieben.last.werte.kcal, closeTo(240, 1e-9));
    });

    test('scheitert das Löschen der alten Probe, wird trotzdem neu '
        'geschrieben und aendere wirft nicht', () async {
      await erfassen().buche(formular());
      final vorher = await einziger();
      health.loeschFehler = StateError('Probe schon weg');

      await erfassen().aendere(BuchungsFormular.fuer(vorher).mitMenge('200'));

      final nachher = await einziger();
      expect(nachher.mengeG, 200);
      expect(nachher.healthStand, HealthStand.geschrieben);
      expect(nachher.healthUuid, health.geschrieben.last.id);
      expect(nachher.healthUuid, isNot(vorher.healthUuid));
    });

    test('ohne Freigabe: offen, die alte Kennung bleibt als Merker', () async {
      await erfassen().buche(formular());
      final vorher = await einziger();
      health.freigabe = WriteAuthorization.denied;

      await erfassen().aendere(BuchungsFormular.fuer(vorher).mitMenge('200'));

      final nachher = await einziger();
      expect(nachher.mengeG, 200);
      expect(nachher.healthStand, HealthStand.offen);
      expect(nachher.healthUuid, vorher.healthUuid);
      expect(health.geschrieben, hasLength(1));
    });

    test('scheitert das neue Schreiben, steht der Eintrag nicht auf '
        'geschrieben', () async {
      await erfassen().buche(formular());
      final vorher = await einziger();
      health.schreibFehlerFuer['Testbrei'] = StateError('Gerät gesperrt');

      await erfassen().aendere(BuchungsFormular.fuer(vorher).mitMenge('200'));

      final nachher = await einziger();
      expect(nachher.mengeG, 200);
      expect(nachher.healthStand, HealthStand.offen);
    });
  });

  group('Löschen', () {
    test('ein geschriebener Eintrag nimmt seine Probe mit', () async {
      await erfassen().buche(formular());
      final eintrag = await einziger();

      await erfassen().loesche(eintrag);

      expect(health.loeschVersuche, [eintrag.healthUuid]);
      expect(await repo.eintraegeAmTag(heute), isEmpty);
    });

    test('scheitert das Löschen in Health, ist der Eintrag trotzdem weg '
        'und loesche wirft nicht', () async {
      await erfassen().buche(formular());
      final eintrag = await einziger();
      health.loeschFehler = StateError('Freigabe entzogen');

      await erfassen().loesche(eintrag);

      expect(health.loeschVersuche, hasLength(1));
      expect(await repo.eintraegeAmTag(heute), isEmpty);
    });

    test('ein Eintrag ohne Kopie wird gelöscht, ohne Health zu '
        'fragen', () async {
      final eintrag = await liegtSchon();

      await erfassen().loesche(eintrag);

      expect(health.loeschVersuche, isEmpty);
      expect(await repo.eintraegeAmTag(heute), isEmpty);
    });
  });

  group('Der Nachlauf', () {
    test('ohne offene Einträge fragt er nicht nach der Freigabe', () async {
      // Spec: „wer nie etwas einträgt, wird nie gefragt".
      await liegtSchon(
        name: 'Schon drüben',
        healthUuid: 'C0FFEE00-0000-0000-0000-0000000000AA',
        healthStand: HealthStand.geschrieben,
      );

      await erfassen().healthNachlauf();

      expect(health.anfragen, 0);
      expect(health.schreibVersuche, isEmpty);
    });

    test('sobald die Freigabe da ist, trägt er alles Offene nach — über '
        'alle Tage', () async {
      await liegtSchon(name: 'Gestern', tag: gestern);
      await liegtSchon(name: 'Heute früh', stundeUtc: 5);
      await liegtSchon(name: 'Heute später', stundeUtc: 9);

      await erfassen().healthNachlauf();

      expect(health.geschrieben, hasLength(3));
      expect(await repo.offeneHealthEintraege(), isEmpty);
      for (final (name, tag) in [
        ('Gestern', gestern),
        ('Heute früh', heute),
        ('Heute später', heute),
      ]) {
        final eintrag = await namens(name, tag);
        expect(eintrag.healthStand, HealthStand.geschrieben, reason: name);
        final kopie = health.geschrieben.singleWhere((k) => k.name == name);
        expect(eintrag.healthUuid, kopie.id, reason: name);
        expect(kopie.werte, eintrag.naehrwerte, reason: name);
      }
    });

    test('ohne Freigabe schreibt er nichts, alles bleibt offen', () async {
      health.freigabe = WriteAuthorization.denied;
      await liegtSchon(name: 'Eins');
      await liegtSchon(name: 'Zwei', stundeUtc: 7);

      await erfassen().healthNachlauf();

      expect(health.schreibVersuche, isEmpty);
      expect(await repo.offeneHealthEintraege(), hasLength(2));
    });

    test('ein endgültig abgelehnter wird nicht_moeglich, die anderen '
        'werden geschrieben', () async {
      await liegtSchon(name: 'Abgelehnt');
      await liegtSchon(name: 'Gut', stundeUtc: 7);
      health.schreibFehlerFuer['Abgelehnt'] = HealthWriteRejected();

      await erfassen().healthNachlauf();

      expect((await namens('Abgelehnt')).healthStand, HealthStand.nichtMoeglich);
      expect((await namens('Gut')).healthStand, HealthStand.geschrieben);
    });

    test('ein vorübergehend gescheiterter bleibt offen, die anderen '
        'werden geschrieben', () async {
      await liegtSchon(name: 'Wackelt');
      await liegtSchon(name: 'Gut', stundeUtc: 7);
      health.schreibFehlerFuer['Wackelt'] = StateError('Gerät gesperrt');

      await erfassen().healthNachlauf();

      expect((await namens('Wackelt')).healthStand, HealthStand.offen);
      expect((await namens('Gut')).healthStand, HealthStand.geschrieben);
    });

    test('nicht_moeglich wird nicht erneut versucht', () async {
      await liegtSchon(name: 'Aufgegeben', healthStand: HealthStand.nichtMoeglich);
      await liegtSchon(name: 'Offen', stundeUtc: 7);

      await erfassen().healthNachlauf();

      expect(health.schreibVersuche, ['Offen']);
      expect(
        (await namens('Aufgegeben')).healthStand,
        HealthStand.nichtMoeglich,
      );
    });

    test('ein Eintrag ohne schreibbaren Nährwert wird nicht_moeglich, ohne '
        'Schreibversuch', () async {
      await liegtSchon(
        name: 'Nur Extra',
        naehrwerte: const Naehrwerte(extra: {'natriumMg': 120}),
      );

      await erfassen().healthNachlauf();

      expect(health.schreibVersuche, isEmpty);
      expect((await namens('Nur Extra')).healthStand, HealthStand.nichtMoeglich);
    });

    test('eine veraltete Kopie wird erst weggeräumt, dann neu '
        'geschrieben', () async {
      const veraltet = 'C0FFEE00-0000-0000-0000-0000000000BB';
      await liegtSchon(name: 'Geändert', healthUuid: veraltet);

      await erfassen().healthNachlauf();

      final eintrag = await namens('Geändert');
      expect(health.loeschVersuche, [veraltet]);
      expect(eintrag.healthStand, HealthStand.geschrieben);
      expect(eintrag.healthUuid, health.geschrieben.single.id);
    });

    test('zweimal hintereinander schreibt nichts doppelt', () async {
      await liegtSchon(name: 'Eins');

      await erfassen().healthNachlauf();
      await erfassen().healthNachlauf();

      expect(health.geschrieben, hasLength(1));
    });

    test('wer mit Freigabe bucht, nimmt die älteren offenen Einträge '
        'mit', () async {
      health.freigabe = WriteAuthorization.denied;
      await erfassen().buche(formular(name: 'Ohne Freigabe', tag: gestern));
      expect((await namens('Ohne Freigabe', gestern)).healthStand, HealthStand.offen);

      health.freigabe = WriteAuthorization.granted;
      await erfassen().buche(formular(name: 'Mit Freigabe'));

      expect(
        (await namens('Ohne Freigabe', gestern)).healthStand,
        HealthStand.geschrieben,
      );
      expect((await namens('Mit Freigabe')).healthStand, HealthStand.geschrieben);
      expect(health.geschrieben.map((k) => k.name).toSet(), {
        'Ohne Freigabe',
        'Mit Freigabe',
      });
    });
  });
}
