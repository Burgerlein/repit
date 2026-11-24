// Der Zustand der Live-Aktivität (#368, Task 6 des Plans
// `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Spec
// `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`, „Die
// Dart-Seite → Zustand"): Esstag, Serie, was die Karte zeigen soll, und
// der eine Rufer der Anzeige.
//
// API und Vertrag sind durch `app/test/live/live_provider_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf). Diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **`Messwert<T>` gilt hier nicht.** Die Karte zeigt Tims eigene Daten,
// und dafür gibt es keinen Lauf, der leer ausgehen kann. Der einzige
// Ladezustand ist „noch nicht gelesen", und dann steht keine Karte (V10).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../ernaehrung/ernaehrung_provider.dart';
import '../health/health_provider.dart';
import '../tag/laufender_tag_provider.dart';
import 'live_anzeige.dart';
import 'live_types.dart';

// ───────────────────────────────────────────────────────────────────────
// Die Eingänge der Schiedsstelle in v1
// ───────────────────────────────────────────────────────────────────────

/// Ein laufendes Training kennt die App noch nicht — es kommt mit #78.
const _trainingLaeuft = false;

/// Einen offenen Kochlauf kennt die App noch nicht — er kommt mit #134.
const _kochlaufOffen = false;

/// Die Essen-Fassung ist in v1 immer an (V8). Einen Schalter dafür gibt es
/// noch nicht.
const _essenEin = true;

// ───────────────────────────────────────────────────────────────────────
// Esstag
// ───────────────────────────────────────────────────────────────────────

/// Der Esstag, auf den die Karte rechnet, als ISO-Tagesstring.
///
/// **Der laufende Tag** (#455, V17): der Tag aus [laufenderTagProvider].
/// Der Name bleibt, damit niemand umziehen muss, der ihn beobachtet oder
/// in einem Test überschreibt. `heutigerTagProvider` wechselt dagegen um
/// Mitternacht.
///
/// Über `select`: Ein neuer Grund oder ein neues spätestes Ende desselben
/// Tages ist kein neuer Esstag und baut nichts neu.
final esstagProvider = NotifierProvider<EsstagNotifier, String>(
  EsstagNotifier.new,
);

class EsstagNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(laufenderTagProvider.select((s) => s.tag));

  /// Lässt den laufenden Tag nachsehen ([LaufenderTagNotifier.pruefe]);
  /// der setzt nur bei einer Änderung, und erst dann zieht dieser Provider
  /// nach. Der Aufruf kommt aus der Rückkehr ([LiveSteuerung.beiRueckkehr]).
  Future<void> pruefe() => ref.read(laufenderTagProvider.notifier).pruefe();
}

// ───────────────────────────────────────────────────────────────────────
// Serie
// ───────────────────────────────────────────────────────────────────────

/// Die Serie zum Esstag: `heute` für jetzt, `abMorgen` für die Karte ab
/// 04:00, falls die App bis dahin nicht mehr läuft (V1).
///
/// Liest neu, sobald der Esstag wechselt, und nach jeder Buchung, Änderung
/// oder Löschung — dafür hört sie auf [eintraegeStandProvider], die eine
/// Stelle, an der jeder Schreibweg vorbeikommt.
final serieProvider =
    AsyncNotifierProvider<SerieNotifier, ({int heute, int abMorgen})>(
      SerieNotifier.new,
    );

class SerieNotifier extends AsyncNotifier<({int heute, int abMorgen})> {
  @override
  Future<({int heute, int abMorgen})> build() async {
    final tag = ref.watch(esstagProvider);
    ref.watch(eintraegeStandProvider);
    final repo = ref.watch(ernaehrungRepositoryProvider);
    final jeTag = await repo.mahlzeitenJeTag(bis: tag);
    return serie(mahlzeitenJeTag: jeTag, esstag: tag);
  }
}

// ───────────────────────────────────────────────────────────────────────
// Das Soll
// ───────────────────────────────────────────────────────────────────────

/// Was die Live-Aktivität gerade zeigen soll — `null`, solange es nichts
/// Verlässliches zu zeigen gibt.
///
/// **`null`, solange die Einträge des Esstags oder die Serie noch keinen
/// Wert haben** (V10, Review Focus 1) — **und solange die Mahlzeitenliste
/// des Esstags lädt** (`mahlzeitenLaedt`: Aufteilungen oder Tagesziel noch
/// nicht gelesen; #374, V16). Sonst ginge erst eine Karte nach V2 an iOS
/// und Sekunden später eine mit Anteil, und die Ringe sprängen.
///
/// Gelesen wird über `hasValue`, nicht über `.value ?? []`: Eine Karte mit
/// drei offenen Mahlzeiten während des Ladens behauptete „nichts
/// gegessen" — Fehler `01` auf dem Sperrbildschirm. `null` heißt für
/// `LiveSteuerung`: nichts tun.
///
/// Ein Soll ist ein Werttyp mit `==`. Ein neu gerechnetes, gleiches Soll
/// meldet Riverpod nicht weiter, und dann geht auch nichts an iOS
/// (Review Focus 4).
final liveSollProvider = Provider<LiveSoll?>(
  (ref) => ref.watch(_liveSollHalterProvider),
);

/// Rechnet das Soll und hält das bisherige, **solange eine der beiden
/// Quellen neu liest**.
///
/// Der Grund ist die Buchung: `neuLesen()` setzt die Einträge des Esstags
/// sofort, die Serie liest danach erst aus der Datenbank. Ohne das Halten
/// entstünde dazwischen eine Karte aus neuen Ringen und alter Serie, und
/// dieselbe Buchung ginge zweimal an iOS — einmal mit der falschen Serie.
/// Ein `null` dazwischen wäre nicht besser: Es ist kein neues Soll, nur
/// ein Zwischenstand.
///
/// Darum ein `Notifier` unter einem schlichten `Provider`: Nur er kommt im
/// `build()` an seinen bisherigen Wert ([stateOrNull]).
final _liveSollHalterProvider = NotifierProvider<_LiveSollHalter, LiveSoll?>(
  _LiveSollHalter.new,
);

class _LiveSollHalter extends Notifier<LiveSoll?> {
  @override
  LiveSoll? build() {
    final tag = ref.watch(esstagProvider);
    final eintraege = ref.watch(eigeneEintraegeProvider(tag));
    final serieStand = ref.watch(serieProvider);

    if (!eintraege.hasValue || !serieStand.hasValue) return null;
    if (eintraege.isLoading || serieStand.isLoading) return stateOrNull;

    switch (waehleFassung(
      trainingLaeuft: _trainingLaeuft,
      kochlaufOffen: _kochlaufOffen,
      essenEin: _essenEin,
    )) {
      case null:
        return const KeineLive();
      case LiveFassung.training || LiveFassung.kochen:
        // Kommen mit #78 und #134. Bis dahin sind beide Eingänge fest
        // `false`, dieser Zweig ist also nicht erreichbar.
        return const KeineLive();
      case LiveFassung.essen:
        final tagWerte = ref.watch(ernaehrungsTagProvider(tag));
        // V16: Ohne gelesene Aufteilungen und Tagesziel stünde kein Ziel in
        // den Zeilen, und die Karte fiele auf V2 zurück — nur bis es
        // gelesen ist. `mahlzeitenLaedt` hängt an `hasValue`, ein Nachlesen
        // setzt es also nicht wieder.
        if (tagWerte.mahlzeitenLaedt) return null;
        return EssenLive(
          essenKarte(
            mahlzeiten: [
              for (final zeile in tagWerte.mahlzeiten)
                MahlzeitStand(
                  mahlzeit: zeile.mahlzeit,
                  hatEintrag: !zeile.leer,
                  // Eine leere Zeile trägt in `summe` acht Nullen. Für
                  // die Karte heißt „nichts eingetragen" aber „kein
                  // Wert", nicht „0 kcal" (`CLAUDE.md`).
                  kcal: zeile.leer ? null : zeile.summe.kcal,
                  // Mit Ziel füllt sich der Ring mit dem Anteil (#374,
                  // V15); V2 gilt nur noch, wenn hier `null` steht.
                  zielKcal: zeile.zielKcal,
                ),
            ],
            serie: serieStand.requireValue,
            jetzt: ref.watch(clockProvider)(),
            // Entscheidung 9: Die Karte verfällt, wenn der laufende Tag
            // spätestens endet — nicht mehr fest um 04:00. Verlängert ein
            // Öffnen den Tag, verfällt auch die Karte später.
            verfaelltUm: ref.watch(
              laufenderTagProvider.select((s) => s.endetSpaetestens),
            ),
          ),
        );
    }
  }
}

// ───────────────────────────────────────────────────────────────────────
// Die Steuerung
// ───────────────────────────────────────────────────────────────────────

/// Der **einzige** Rufer von [LiveAnzeige].
final liveSteuerungProvider = NotifierProvider<LiveSteuerung, void>(
  LiveSteuerung.new,
);

class LiveSteuerung extends Notifier<void> {
  /// Ob das nächste Zeigen ein Neustart sein soll: beim ersten seit Start
  /// und beim ersten seit der letzten Rückkehr (V6).
  bool _naechstesFrisch = true;

  @override
  void build() {}

  /// Setzt [soll] auf der Anzeige um.
  ///
  /// `null` heißt „noch nicht gelesen" und löst nichts aus — auch kein
  /// Zeigen, das als erstes zählte. [KeineLive] beendet jede Aktivität.
  Future<void> nimm(LiveSoll? soll) async {
    final anzeige = ref.read(liveAnzeigeProvider);
    switch (soll) {
      case null:
        return;
      case KeineLive():
        await anzeige.beendeAlle();
      case EssenLive(:final karte):
        final frisch = _naechstesFrisch;
        _naechstesFrisch = false;
        await anzeige.zeige(karte, frisch: frisch);
    }
  }

  /// Die App kommt nach vorn: Esstag prüfen, das nächste Zeigen frisch,
  /// dann das aktuelle Soll zeigen.
  ///
  /// Ist das Soll noch nicht gelesen, geschieht nichts — und das nächste
  /// Zeigen bleibt frisch.
  ///
  /// Das Nachsehen des laufenden Tages wird angestoßen, nicht abgewartet:
  /// Wechselt der Tag, kommt das neue Soll über `LiveWacht` an die Anzeige.
  Future<void> beiRueckkehr() async {
    unawaited(ref.read(esstagProvider.notifier).pruefe());
    _naechstesFrisch = true;
    await nimm(ref.read(liveSollProvider));
  }

  /// Holt den angekommenen Link ab — einmal.
  Future<LiveZiel?> holeLink() => ref.read(liveAnzeigeProvider).nimmLink();
}
