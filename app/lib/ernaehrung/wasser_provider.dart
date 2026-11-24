// Wasser eintragen (#311): das Wasser eines Tages, Eintragen, Ändern,
// Löschen und die Kopie nach Apple Health. Die Tabelle liegt in
// `lib/data/wasser_tabellen.dart`, das SQL in
// `lib/data/wasser_repository.dart`.
//
// API und Vertrag sind durch `app/test/ernaehrung/wasser_eintragen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **Kein `Messwert`.** Eingetragenes Wasser sind Tims eigene Daten; leer
// heißt leer.
//
// **Ändern und Löschen auf dem Schirm** laufen über das Blatt „Wasser
// heute" (#360, `wasser_blatt.dart`), das die Wasserzeile öffnet.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart' show HealthStand;
import '../data/wach_belege.dart';
import '../data/wasser_repository.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import '../tag/laufender_tag_provider.dart';
import 'erfassen_provider.dart' show healthSchreibHinweisProvider;

/// Unter diesem Namen geht ein Glas nach Apple Health.
const _healthName = 'Wasser';

/// Das Wasser eines Tages, nach Zeitpunkt aufsteigend.
final wasserProvider =
    AsyncNotifierProvider.family<WasserNotifier, List<WasserEintrag>, String>(
      WasserNotifier.new,
    );

class WasserNotifier extends AsyncNotifier<List<WasserEintrag>> {
  WasserNotifier(this.tagesSchluessel);

  final String tagesSchluessel;

  @override
  Future<List<WasserEintrag>> build() =>
      ref.watch(wasserRepositoryProvider).wasserAmTag(tagesSchluessel);

  /// Trägt [mengeMl] auf **diesen** Tag ein, zur Uhrzeit des Trackens
  /// (#328): auf dem **laufenden** Tag jetzt (V15), an einem geblätterten
  /// Tag dieselbe Berliner Wanduhrzeit, gelegt wie im Buchungsblatt
  /// (`zeitpunktImTag`, `normal`, V14). Danach ein Wachbeleg (V13) und die
  /// Kopie nach Health — **gebucht wird immer**, auch ohne Freigabe; fehlt
  /// sie, schlägt derselbe Hinweis an wie beim Essen.
  ///
  /// **Verglichen wird mit dem laufenden Tag, nicht mit dem Kalendertag von
  /// jetzt** — sonst gälte um Di 01:30 der laufende Montag als
  /// geblättert, und das Glas trüge Mo 01:30, vor dem Beginn des Tages, auf
  /// dem es steht (Befund „Die Falle beim Umstellen“).
  Future<void> trageEin(double mengeMl) async {
    final jetzt = ref.read(clockProvider)();
    final DateTime zeitpunkt;
    if (ref.read(laufenderTagProvider).tag == tagesSchluessel) {
      zeitpunkt = jetzt;
    } else {
      final (stunde, minute) = BerlinCalendar.wallClock(jetzt);
      zeitpunkt = zeitpunktImTag(
        tag: tagesSchluessel,
        minuten: stunde * Duration.minutesPerHour + minute,
      );
    }
    await ref
        .read(wasserRepositoryProvider)
        .trageEin(
          WasserEintrag(
            tagesSchluessel: tagesSchluessel,
            zeitpunkt: zeitpunkt,
            mengeMl: mengeMl,
          ),
        );
    await _nachSchreiben();
    await ref.read(wasserHealthProvider.notifier).kopiere(hinweis: true);
    await _neuLesen();
  }

  /// Setzt die Menge neu. **Dieselbe Zeile**, kein zweites Glas. Die Kopie
  /// in Health wird ersetzt, nicht geändert — HealthKit kennt kein Ändern:
  /// Der Eintrag steht danach wieder auf `offen` und behält die alte
  /// Kennung als Merker, damit der Nachlauf die veraltete Probe wegräumt,
  /// bevor er die neue schreibt.
  Future<void> aendere(WasserEintrag eintrag, double mengeMl) async {
    final id = eintrag.id;
    if (id == null) throw ArgumentError.notNull('eintrag.id');
    await ref
        .read(wasserRepositoryProvider)
        .aendere(
          WasserEintrag(
            id: id,
            tagesSchluessel: eintrag.tagesSchluessel,
            zeitpunkt: eintrag.zeitpunkt,
            mengeMl: mengeMl,
            healthUuid: eintrag.healthUuid,
          ),
        );
    await _nachSchreiben();
    await ref.read(wasserHealthProvider.notifier).kopiere(hinweis: true);
    await _neuLesen();
  }

  /// Nimmt das Glas weg und löscht seine Kopie in Health. Scheitert das
  /// Löschen dort, ist das kein Fehler für Tim (Spec, „Löschen"): Der
  /// eigene Eintrag ist weg, und das ist die Wahrheit.
  Future<void> loesche(WasserEintrag eintrag) async {
    final id = eintrag.id;
    if (id == null) throw ArgumentError.notNull('eintrag.id');
    await ref
        .read(wasserHealthProvider.notifier)
        .loescheMitKopie(id, eintrag.healthUuid);
    await _nachSchreiben();
  }

  /// Nach jedem Eintragen, Ändern und Löschen: ein Wachbeleg `buchung`
  /// (V13), dann neu lesen. Ein Fehler beim Beleg hält niemanden auf —
  /// eingetragen ist eingetragen.
  Future<void> _nachSchreiben() async {
    try {
      await ref.read(wachbelegProvider.notifier).merke(WachArt.buchung);
    } catch (fehler) {
      debugPrint('Wachbeleg nach Wasser: $fehler');
    }
    await _neuLesen();
  }

  Future<void> _neuLesen() async {
    final repo = ref.read(wasserRepositoryProvider);
    state = await AsyncValue.guard(() => repo.wasserAmTag(tagesSchluessel));
  }
}

/// Der **eine** Weg, auf dem Gläser nach Health kommen — für alle Tage
/// derselbe, deshalb nicht je Tag ([WasserNotifier] ist eine Familie).
///
/// Dieselben Regeln wie beim Essen (`ErfassenNotifier._kopiereNachHealth`):
/// Wer mit Freigabe einträgt, nimmt die älteren `offen`en Gläser mit; eine
/// endgültige Ablehnung durch HealthKit macht `nicht_moeglich` und wird
/// nicht endlos neu versucht; alles andere bleibt `offen`.
final wasserHealthProvider = NotifierProvider<WasserHealthNotifier, void>(
  WasserHealthNotifier.new,
);

class WasserHealthNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Nacheinander, nie überlappend: Zwei Läufe zugleich läsen dieselben
  /// offenen Gläser und schrieben jedes zweimal.
  Future<void> _kette = Future<void>.value();

  Future<void> _nacheinander(Future<void> Function() arbeit) {
    final lauf = _kette.then((_) => arbeit());
    _kette = lauf.catchError((Object _) {});
    return lauf;
  }

  /// Trägt alle offenen Gläser nach — **über alle Tage**. [hinweis] sagt,
  /// ob eine fehlende Freigabe den Hinweis „Nicht in Apple Health"
  /// auslöst; nur wer gerade selbst einträgt, bekommt ihn zu sehen.
  ///
  /// Wirft nicht: Eingetragen ist eingetragen.
  Future<void> kopiere({required bool hinweis}) => _nacheinander(() async {
    try {
      final repo = ref.read(wasserRepositoryProvider);
      final offene = await repo.offeneHealthEintraege();
      if (offene.isEmpty) return;

      final health = ref.read(healthProvider);
      final freigabe = await health.requestNutritionWriteAuthorization();
      if (freigabe != WriteAuthorization.granted) {
        if (hinweis) ref.read(healthSchreibHinweisProvider.notifier).zeige();
        return;
      }
      for (final eintrag in offene) {
        await _schreibe(eintrag);
      }
    } catch (fehler) {
      debugPrint('Wasser nach Health: $fehler');
    }
  });

  /// Nimmt ein Glas weg und löscht danach seine Kopie — in der Kette,
  /// damit kein Lauf gerade eine Probe für eine Zeile schreibt, die es
  /// nicht mehr gibt.
  Future<void> loescheMitKopie(int id, String? kopie) =>
      _nacheinander(() async {
        await ref.read(wasserRepositoryProvider).loesche(id);
        if (kopie != null) await _loescheKopie(kopie);
      });

  /// Schreibt **ein** Glas als reine Wasserprobe und hält fest, was daraus
  /// wurde.
  Future<void> _schreibe(WasserEintrag eintrag) async {
    final repo = ref.read(wasserRepositoryProvider);
    final health = ref.read(healthProvider);
    final id = eintrag.id!;

    var merker = eintrag.healthUuid;
    if (merker != null && await _loescheKopie(merker)) merker = null;

    try {
      final kopie = await health.writeMeal(
        // Nur Wasser, sonst nichts — kein 0-kcal-Eintrag in Health.
        werte: Naehrwerte(wasserMl: eintrag.mengeMl),
        name: _healthName,
        at: eintrag.zeitpunkt,
      );
      await repo.setzeHealthKopie(
        id,
        healthUuid: kopie,
        stand: HealthStand.geschrieben,
      );
    } on HealthWriteRejected catch (fehler) {
      debugPrint('Wasser nach Health abgelehnt: $fehler');
      await repo.setzeHealthKopie(
        id,
        healthUuid: null,
        stand: HealthStand.nichtMoeglich,
      );
    } catch (fehler) {
      debugPrint('Wasser nach Health, später erneut: $fehler');
      if (merker != eintrag.healthUuid) {
        await repo.setzeHealthKopie(
          id,
          healthUuid: merker,
          stand: HealthStand.offen,
        );
      }
    }
  }

  /// Löscht eine Kopie in Health; ein Fehlschlag ist kein Fehler für Tim.
  /// Sagt, ob es geklappt hat.
  Future<bool> _loescheKopie(String kennung) async {
    try {
      await ref.read(healthProvider).deleteMeal(kennung);
      return true;
    } catch (fehler) {
      debugPrint('Wasser-Kopie $kennung in Health nicht gelöscht: $fehler');
      return false;
    }
  }
}
