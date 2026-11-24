// Der laufende Tag als Provider (#455 unter #375): `laufenderTagProvider`
// hält den `Tagesstand`, `wachbelegProvider` schreibt eigene Wachbelege und
// stößt das Nachsehen an.
//
// API und Vertrag sind durch `app/test/tag/laufender_tag_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`). Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitte
// „`laufenderTagProvider`“ und „Eigene Belege schreiben“, dazu V9–V11,
// V13, V16, V17 und Entscheidung 9.
//
// **Kein `Messwert<T>`.** Der laufende Tag ist immer bestimmt: Ohne Belege
// und ohne Nächte ist er der Esstag (`esstag()` ist der Sonderfall von
// `laufenderTag`). Fehlende Eingaben machen ihn nicht unbekannt, sondern
// vorsichtig — ohne Beleg wird nicht verlängert (V11).
//
// Welcher Tag läuft, rechnet der Kern (`laufenderTag`). Diese Datei sammelt
// die Eingaben, hält das Ergebnis und entscheidet, wann neu gerechnet wird.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/wach_belege.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'tagesgrenze_eingaben.dart';

/// Welcher Tag gerade läuft, mit Grund, spätestem Ende und dem jüngsten
/// Wachbeleg.
///
/// `esstagProvider` und `offenerTagProvider` lesen ihn (V17). Ein neu
/// gerechneter, gleicher [Tagesstand] wird **nicht** gesetzt — sonst
/// rechnete alles Abgeleitete bei jedem Nachsehen neu (`03`).
final laufenderTagProvider = NotifierProvider<LaufenderTagNotifier, Tagesstand>(
  LaufenderTagNotifier.new,
);

class LaufenderTagNotifier extends Notifier<Tagesstand> {
  /// Stellt das nächste Nachsehen auf [Tagesstand.endetSpaetestens] (V9).
  Timer? _zeitgeber;

  /// Zählt die Läufe von [pruefe]. Ein Lauf, der nach einem jüngeren
  /// fertig wird, setzt nichts mehr: Er rechnete mit älteren Nächten oder
  /// ohne den gerade geschriebenen Beleg.
  var _lauf = 0;

  /// **Sofort ein Wert** (V10): aus der Uhr und den Nächten, die
  /// [sleepProvider] gerade hält — auch aus dem Cache, während Health noch
  /// nachliest. Ohne Belege: Die folgen im ersten [pruefe], angestoßen
  /// gleich nach dem Aufbau.
  ///
  /// **Bekannte Lücke (V10):** Startet die App kalt zwischen 04:00 und
  /// 08:00 in einem verlängerten Tag, steht bis zu diesem ersten Nachsehen
  /// der neue Tag da.
  @override
  Tagesstand build() {
    ref.onDispose(() => _zeitgeber?.cancel());
    // `listen`, nicht `watch`: Ein neuer Stand der Nächte soll nachsehen
    // lassen (V9), nicht den Notifier neu bauen — ein Neubau finge wieder
    // ohne Belege an, und der Tag spränge kurz auf den Kalendertag.
    final schlaf = ref.listen(sleepProvider, (_, _) => unawaited(pruefe()));
    final jetzt = ref.watch(clockProvider)().toUtc();

    final stand = laufenderTag(jetzt: jetzt, naechte: _naechte(schlaf.read()));
    // Auch hier gestellt, nicht erst in `pruefe`: Hängt das Lesen der
    // Belege, wechselt der Tag trotzdem zu seiner Zeit.
    _stelleZeitgeber(stand.endetSpaetestens, jetzt);
    Future.microtask(pruefe);
    return stand;
  }

  /// Sieht nach, welcher Tag läuft, und setzt den Zustand **nur bei einer
  /// Änderung** (V9).
  ///
  /// Liest die Uhr, die Nächte aus [sleepProvider] ([Bekannt], auch mit
  /// `laeuft: true`), die eigenen Belege und — nur zwischen 04:00 und
  /// 08:00 — Schritte und Trainings aus Health (V11). Stellt danach den
  /// Zeitgeber auf `endetSpaetestens`.
  ///
  /// Wirft nicht: Scheitert eine Quelle, zählt sie nicht. Das ist die
  /// vorsichtige Seite, ohne Beleg wird nicht verlängert (V11).
  Future<void> pruefe() async {
    if (!ref.mounted) return;
    final lauf = ++_lauf;
    final jetzt = ref.read(clockProvider)().toUtc();
    final naechte = _naechte(ref.read(sleepProvider));
    final belege = await _belege(jetzt);
    if (!ref.mounted || lauf != _lauf) return;

    final neu = laufenderTag(jetzt: jetzt, belege: belege, naechte: naechte);
    if (neu != state) state = neu;
    _stelleZeitgeber(neu.endetSpaetestens, jetzt);
  }

  /// Die Wachbelege, die über den laufenden Tag entscheiden können.
  ///
  /// **Eigene Belege:** Vor 08:00 kann noch der Vortag laufen, also ab
  /// Vortag 04:00 — dem Beginn seines Fensters (V12). Ab 08:00 läuft
  /// sicher der Kalendertag, also ab dessen 04:00. Bis `jetzt`.
  ///
  /// **Health (V11):** nur zwischen 04:00 und 08:00. Schritte ab 03:00:
  /// Jede Kette, die über 04:00 reicht, hat dort einen Beleg. Trainings ab
  /// Mitternacht, weil ein Training eine Spanne ist (V2) — eines, das vor
  /// 03:00 begann und über 04:00 lief, fiele mit einem Fenster ab 03:00
  /// heraus.
  Future<List<Wachbeleg>> _belege(DateTime jetzt) async {
    final kalendertag = BerlinCalendar.dayKey(jetzt);
    final vortag = BerlinCalendar.dayKey(BerlinCalendar.addDays(jetzt, -1));
    final tagesbeginn = wanduhrZeitpunkt(
      kalendertag,
      Mahlzeitfenster.tagesbeginnInMinuten,
    );
    final obergrenze = wanduhrZeitpunkt(kalendertag, tagesObergrenzeInMinuten);
    final vorObergrenze = jetzt.isBefore(obergrenze);

    final eigeneAb = vorObergrenze
        ? wanduhrZeitpunkt(vortag, Mahlzeitfenster.tagesbeginnInMinuten)
        : tagesbeginn;
    // Alle angestoßen, bevor auf einen gewartet wird.
    final eigene = _ohneFehler(
      () => ref.read(wachbelegRepositoryProvider).zwischen(eigeneAb, jetzt),
    );

    if (jetzt.isBefore(tagesbeginn) || !vorObergrenze) return eigene;

    // `ref.read(healthProvider)` steht in der Abfrage: Ist keine Quelle
    // da, geht die Abfrage leer aus wie eine gescheiterte.
    final schritte = _ohneFehler(
      () => ref
          .read(healthProvider)
          .hourlySteps(
            wanduhrZeitpunkt(kalendertag, _schritteAbInMinuten),
            jetzt,
          ),
    );
    final trainings = _ohneFehler(
      () => ref
          .read(healthProvider)
          .workouts(BerlinCalendar.startOfDay(jetzt), jetzt),
    );
    return [
      ...await eigene,
      ...belegeAusSchritten(await schritte),
      ...belegeAusTrainings(await trainings),
    ];
  }

  void _stelleZeitgeber(DateTime endetSpaetestens, DateTime jetzt) {
    _zeitgeber?.cancel();
    final bis = endetSpaetestens.difference(jetzt);
    _zeitgeber = Timer(
      bis.isNegative ? Duration.zero : bis,
      () => unawaited(pruefe()),
    );
  }
}

/// Mit welchem Grund auf [tag] gebucht wird (V14, #456): mit dem des
/// laufenden Tages, wenn [tag] der laufende ist — sonst `normal`.
///
/// **Die eine Stelle dieser Regel.** Buchungsblatt, „+" der Trefferzeile,
/// Foto-Schätzung und der Kopf der Erfassen-Seiten fragen hier. Ein
/// geblätterter Tag bekäme sonst den Grund eines anderen Tages: Auf Sonntag
/// gebucht, um Di 05:10 im verlängerten Montag, läge 05:10 dann auf Montag
/// statt auf Sonntag.
Tagesgrund buchungsgrund(Tagesstand stand, String tag) =>
    stand.tag == tag ? stand.grund : Tagesgrund.normal;

/// Ab wann Health für den laufenden Tag nach Schritten gefragt wird: 03:00
/// der Berliner Wanduhr, in Minuten seit Mitternacht (V11).
const _schritteAbInMinuten = 3 * 60;

/// Die Hauptnächte aus dem Stand von [sleepProvider]. Gezählt wird nur ein
/// [Bekannt] — auch während Health nachliest. Alles andere heißt: keine
/// Nacht, und dann entscheidet die Uhr.
List<GemeldeteNacht> _naechte(AsyncValue<Messwert<List<SleepNight>>> schlaf) =>
    switch (schlaf.value) {
      Bekannt(:final wert) => [for (final n in wert) ?nachtAus(n)],
      _ => const [],
    };

/// Eine Abfrage, die bei einem Fehler leer ausgeht. Gefangen wird je
/// Quelle, damit ein gescheitertes Lesen der Schritte die eigenen Belege
/// nicht mitnimmt.
Future<List<T>> _ohneFehler<T>(Future<List<T>> Function() frage) async {
  try {
    return await frage();
  } on Object {
    return const [];
  }
}

/// Schreibt eigene Wachbelege (V13).
final wachbelegProvider = NotifierProvider<WachbelegNotifier, void>(
  WachbelegNotifier.new,
);

class WachbelegNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Legt einen Beleg der Art [art] mit der Uhr aus [clockProvider] ab und
  /// sieht danach nach, welcher Tag läuft — fertig ist der Aufruf erst,
  /// wenn [LaufenderTagNotifier.pruefe] den neuen Beleg gesehen hat.
  ///
  /// **Nachgesehen wird nur, wenn den laufenden Tag schon jemand hält.**
  /// Sonst gibt es niemanden, dem ein neuer Stand etwas sagte, und wer ihn
  /// später zum ersten Mal liest, sieht in seinem ersten Nachsehen den
  /// Beleg ohnehin. Ein Buchen legt so keinen Provider samt Zeitgeber an,
  /// den nichts liest (#456).
  ///
  /// Aufrufer (V13): `Tageswacht` beim Aufbau und bei jeder Rückkehr nach
  /// vorn, Buchungen von Essen und Wasser. Ein Fehler beim Schreiben geht
  /// an den Aufrufer.
  Future<void> merke(WachArt art) async {
    final jetzt = ref.read(clockProvider)();
    await ref.read(wachbelegRepositoryProvider).merke(art, jetzt);
    if (!ref.mounted || !ref.exists(laufenderTagProvider)) return;
    await ref.read(laufenderTagProvider.notifier).pruefe();
  }
}
