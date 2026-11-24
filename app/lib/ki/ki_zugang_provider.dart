// Der Zustand des Schirms „KI-Zugang" (#339). Spec
// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Der Schlüssel",
// „Modellwahl", „Verbrauch und Limit", „Zustände und die eine Form".
//
// API und Verhalten sind durch `app/test/ki/ki_zugang_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`).
//
// **Kein Zustand hält den Schlüssel.** Er wird für jeden Aufruf frisch aus
// dem Speicher gelesen, als lokale Variable an den Anbieter gereicht und
// vergessen. Der Zustand kennt nur die letzten vier Zeichen.
//
// **`Messwert<T>` gilt hier nicht** — Einstellungen und Verbrauch sind
// Tims eigene Daten, die Prüfung ist eine Netzanfrage mit eigenem,
// versiegeltem Zustand. Und `AsyncValue` gelangt nicht in die Ansicht:
// Der Notifier ist synchron und beginnt mit [KiZugangLaedt].
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'gemini_client.dart';
import 'gemini_preise.dart';
import 'ki_repository.dart';
import 'ki_schluessel.dart';

/// Der Verbrauch dieser App im laufenden Berliner Kalendermonat, samt
/// Limit und Preis — die Gruppe „Verbrauch dieser App".
///
/// Steht in **jedem** Zustand, auch ohne Schlüssel: Entfernen löscht den
/// Schlüssel, nicht den gezählten Verbrauch.
@immutable
class KiTopf {
  const KiTopf({
    required this.summe,
    required this.zuletzt,
    required this.limitUsd,
    required this.preisModell,
    required this.preis,
    required this.limitEnde,
  });

  /// Selbstzählung des laufenden Monats.
  final MonatsSumme summe;

  /// Die jüngste Anfrage überhaupt (UTC); `null` heißt „noch keine".
  final DateTime? zuletzt;

  /// Das Monatslimit in US-Dollar — Tims Wert oder die Vorgabe.
  final double limitUsd;

  /// Das Modell, für das [preis] gilt.
  final String preisModell;

  /// `null` heißt „kein Preis bekannt", die Anzeige sagt `–/–`, nie `0 $`.
  final KiPreis? preis;

  /// Wann das Limit dieses Monats endet: der Erste des Folgemonats, 00:00
  /// Berliner Zeit, als UTC-Zeitpunkt.
  final DateTime limitEnde;

  /// `summe >= limit` — die Bremse dieser App, keine Sperre bei Google.
  bool get erreicht => limitErreicht(summe, limitUsd);

  @override
  bool operator ==(Object other) =>
      other is KiTopf &&
      other.summe == summe &&
      other.zuletzt == zuletzt &&
      other.limitUsd == limitUsd &&
      other.preisModell == preisModell &&
      other.preis == preis &&
      other.limitEnde == limitEnde;

  @override
  int get hashCode =>
      Object.hash(summe, zuletzt, limitUsd, preisModell, preis, limitEnde);
}

/// Das Ergebnis der letzten Schlüsselprüfung, so wie es in
/// `ki_einstellungen` steht.
@immutable
class KiPruefung {
  const KiPruefung({required this.am, required this.ergebnis});

  /// UTC.
  final DateTime am;

  /// `gueltig`, `abgelehnt` oder `kontingent`.
  final String ergebnis;

  @override
  bool operator ==(Object other) =>
      other is KiPruefung && other.am == am && other.ergebnis == ergebnis;

  @override
  int get hashCode => Object.hash(am, ergebnis);
}

/// Wie der Nachlauf beim Öffnen ausgegangen ist.
///
/// **Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg**: Bei
/// [keinNetz] und [gestoert] bleibt [MitSchluessel.pruefung] stehen, wie
/// sie war.
enum KiNachlauf {
  /// Die Modellliste wird gerade abgerufen.
  laeuft,

  /// Google hat geantwortet — gültig, abgelehnt oder Kontingent; das
  /// Ergebnis steht in [MitSchluessel.pruefung].
  fertig,

  /// Google war nicht erreichbar.
  keinNetz,

  /// Google hat anders geantwortet als erwartet (5xx, unlesbare Antwort).
  gestoert,
}

/// Was der Schirm zeigt.
sealed class KiZugangZustand {
  const KiZugangZustand();
}

/// Speicher und Datenbank werden gelesen — einmal pro App-Sitzung. Der
/// Schirm steht in derselben Form da, mit grauen Werten.
final class KiZugangLaedt extends KiZugangZustand {
  const KiZugangLaedt();

  @override
  bool operator ==(Object other) => other is KiZugangLaedt;

  @override
  int get hashCode => (KiZugangLaedt).hashCode;
}

/// Kein Schlüssel hinterlegt — nach der Installation, nach dem Entfernen,
/// nach einem Gerätewechsel.
final class OhneSchluessel extends KiZugangZustand {
  const OhneSchluessel({required this.topf});

  final KiTopf topf;

  @override
  bool operator ==(Object other) =>
      other is OhneSchluessel && other.topf == topf;

  @override
  int get hashCode => Object.hash(OhneSchluessel, topf);
}

/// Ein Schlüssel liegt in der Keychain.
final class MitSchluessel extends KiZugangZustand {
  const MitSchluessel({
    required this.endung,
    required this.pruefung,
    required this.modell,
    required this.gemerktFehlt,
    required this.nachlauf,
    required this.topf,
  });

  /// Die letzten vier Zeichen — mehr kennt der Zustand nicht.
  final String endung;

  /// `null` heißt „nie geprüft".
  final KiPruefung? pruefung;

  /// Das Modell, das die Foto-Schätzung nutzt.
  final String modell;

  /// Das gemerkte Modell, das Google nicht mehr anbietet — dann gilt
  /// [modell] an seiner Stelle, und der Schirm sagt es. `null` heißt „nichts
  /// weggefallen".
  final String? gemerktFehlt;

  final KiNachlauf nachlauf;

  final KiTopf topf;

  MitSchluessel _mit({
    KiPruefung? pruefung,
    String? modell,
    String? Function()? gemerktFehlt,
    KiNachlauf? nachlauf,
    KiTopf? topf,
  }) => MitSchluessel(
    endung: endung,
    pruefung: pruefung ?? this.pruefung,
    modell: modell ?? this.modell,
    gemerktFehlt: gemerktFehlt != null ? gemerktFehlt() : this.gemerktFehlt,
    nachlauf: nachlauf ?? this.nachlauf,
    topf: topf ?? this.topf,
  );

  @override
  bool operator ==(Object other) =>
      other is MitSchluessel &&
      other.endung == endung &&
      other.pruefung == pruefung &&
      other.modell == modell &&
      other.gemerktFehlt == gemerktFehlt &&
      other.nachlauf == nachlauf &&
      other.topf == topf;

  @override
  int get hashCode =>
      Object.hash(endung, pruefung, modell, gemerktFehlt, nachlauf, topf);

  @override
  String toString() =>
      'MitSchluessel(endung: $endung, modell: $modell, nachlauf: $nachlauf)';
}

/// Wie „Sichern" ausgegangen ist.
enum KiSichern {
  /// Google hat ihn angenommen, er liegt in der Keychain.
  gesichert,

  /// 400 `API_KEY_INVALID`, 401, 403 — nichts gesichert.
  abgelehnt,

  /// Google nicht erreichbar — nichts gesichert, über den Schlüssel ist
  /// nichts bekannt.
  keinNetz,

  /// Alles andere — nichts gesichert.
  gestoert,
}

/// Wie die Wahl eines Modells ausgegangen ist (Testbild).
enum KiWahl {
  gewaehlt,
  abgelehnt,
  keinNetz,
  kontingent,

  /// Das Monatslimit ist erreicht — das Testbild ginge darüber.
  limit,
  gestoert,
}

/// Der Zustand des KI-Zugangs.
///
/// **Bleibt über das Zurücknavigieren erhalten** (kein `autoDispose`):
/// Wer den Schirm verlässt und wiederkommt, sieht sofort, was dastand
/// (`32`), und der Nachlauf läuft nur einmal pro App-Sitzung.
final kiZugangProvider = NotifierProvider<KiZugangNotifier, KiZugangZustand>(
  KiZugangNotifier.new,
);

class KiZugangNotifier extends Notifier<KiZugangZustand> {
  /// Zählt jeden Lauf, der den Zustand setzt. Ein Nachlauf, der erst
  /// zurückkommt, nachdem jemand den Schlüssel ersetzt oder entfernt hat,
  /// schreibt nichts mehr.
  int _lauf = 0;

  @override
  KiZugangZustand build() {
    unawaited(_lade());
    return const KiZugangLaedt();
  }

  KiRepository get _repo => ref.read(kiRepositoryProvider);
  KiSchluesselSpeicher get _speicher => ref.read(kiSchluesselProvider);
  KiAnbieter get _anbieter => ref.read(kiAnbieterProvider);
  DateTime get _jetzt => ref.read(clockProvider)().toUtc();

  bool _aktuell(int lauf) => ref.mounted && lauf == _lauf;

  Future<void> _lade() async {
    final lauf = ++_lauf;
    final schluessel = await _speicher.lies();
    final einst = await _repo.einstellungen();
    final modell = einst.modell ?? voreingestelltesModell;
    final topf = await _topf(einst, modell);
    if (!_aktuell(lauf)) return;

    if (schluessel == null) {
      state = OhneSchluessel(topf: topf);
      return;
    }
    state = MitSchluessel(
      endung: endung(schluessel),
      pruefung: _pruefungAus(einst),
      modell: modell,
      gemerktFehlt: null,
      nachlauf: KiNachlauf.laeuft,
      topf: topf,
    );
    await _pruefe(schluessel, lauf);
  }

  /// Der Nachlauf: Modellliste abrufen. Das kostet nichts und ist zugleich
  /// der Schlüsseltest.
  Future<void> _pruefe(String schluessel, int lauf) async {
    try {
      final liste = await _anbieter.modelle(schluessel);
      if (!_aktuell(lauf)) return;
      await _repo.setzePruefung(_jetzt, 'gueltig');
      await _uebernimmListe(liste, lauf);
    } on SchluesselAbgelehnt {
      await _haltePruefungFest('abgelehnt', lauf);
    } on Kontingent {
      await _haltePruefungFest('kontingent', lauf);
    } on KeinNetz {
      _setzeNachlauf(KiNachlauf.keinNetz, lauf);
    } on KiFehler {
      _setzeNachlauf(KiNachlauf.gestoert, lauf);
    }
  }

  Future<void> _haltePruefungFest(String ergebnis, int lauf) async {
    if (!_aktuell(lauf)) return;
    await _repo.setzePruefung(_jetzt, ergebnis);
    final einst = await _repo.einstellungen();
    final jetzt = state;
    if (!_aktuell(lauf) || jetzt is! MitSchluessel) return;
    state = jetzt._mit(
      pruefung: _pruefungAus(einst),
      nachlauf: KiNachlauf.fertig,
    );
  }

  void _setzeNachlauf(KiNachlauf nachlauf, int lauf) {
    final jetzt = state;
    if (!_aktuell(lauf) || jetzt is! MitSchluessel) return;
    state = jetzt._mit(nachlauf: nachlauf);
  }

  /// Löst das gemerkte Modell gegen die frische Liste auf. Ist es
  /// weggefallen, **wird nichts umgeschrieben** — der Schirm sagt es, und
  /// Tim wählt selbst.
  Future<void> _uebernimmListe(List<KiModell> liste, int lauf) async {
    final einst = await _repo.einstellungen();
    final aufgeloest = loeseModell(
      liste: liste,
      gemerkt: einst.modell,
      voreinstellung: voreingestelltesModell,
    );
    final modell =
        aufgeloest.modell?.id ?? einst.modell ?? voreingestelltesModell;
    final topf = await _topf(einst, modell);
    final jetzt = state;
    if (!_aktuell(lauf) || jetzt is! MitSchluessel) return;
    state = jetzt._mit(
      pruefung: _pruefungAus(einst),
      modell: modell,
      gemerktFehlt: () => aufgeloest.gemerktFehlt ? einst.modell : null,
      nachlauf: KiNachlauf.fertig,
      topf: topf,
    );
  }

  /// Lässt den Nachlauf noch einmal laufen, wenn der letzte nicht
  /// durchkam (kein Netz, Störung) — sonst nichts. Der alte Stand bleibt
  /// stehen, bis eine Antwort da ist; kein Hinweis blinkt dazwischen weg.
  void pruefeErneut() {
    final jetzt = state;
    if (jetzt is! MitSchluessel) return;
    if (jetzt.nachlauf != KiNachlauf.keinNetz &&
        jetzt.nachlauf != KiNachlauf.gestoert) {
      return;
    }
    final lauf = ++_lauf;
    unawaited(() async {
      final schluessel = await _speicher.lies();
      if (schluessel == null || !_aktuell(lauf)) return;
      await _pruefe(schluessel, lauf);
    }());
  }

  /// Prüft [wert] und sichert ihn nur, wenn Google ihn annimmt.
  ///
  /// **Ohne Netz wird nichts gesichert** — sonst stünde ein Schlüssel da,
  /// der beim ersten Foto scheitert. Der bisherige Schlüssel bleibt in
  /// jedem Fehlerfall unangetastet.
  Future<KiSichern> sichere(String wert) async {
    final schluessel = wert.trim();
    final List<KiModell> liste;
    try {
      liste = await _anbieter.modelle(schluessel);
    } on SchluesselAbgelehnt {
      return KiSichern.abgelehnt;
    } on KeinNetz {
      return KiSichern.keinNetz;
    } on KiFehler {
      return KiSichern.gestoert;
    }
    if (!ref.mounted) return KiSichern.gestoert;

    final lauf = ++_lauf;
    await _speicher.schreibe(schluessel);
    await _repo.setzePruefung(_jetzt, 'gueltig');
    final einst = await _repo.einstellungen();
    final topf = await _topf(einst, einst.modell ?? voreingestelltesModell);
    if (!_aktuell(lauf)) return KiSichern.gesichert;
    state = MitSchluessel(
      endung: endung(schluessel),
      pruefung: _pruefungAus(einst),
      modell: einst.modell ?? voreingestelltesModell,
      gemerktFehlt: null,
      nachlauf: KiNachlauf.laeuft,
      topf: topf,
    );
    await _uebernimmListe(liste, lauf);
    return KiSichern.gesichert;
  }

  /// Entfernt den Schlüssel aus der Keychain dieses iPhones. Bei Google
  /// bleibt er gültig; der gezählte Verbrauch bleibt stehen.
  Future<void> entferne() async {
    final lauf = ++_lauf;
    await _speicher.loesche();
    final einst = await _repo.einstellungen();
    final topf = await _topf(einst, einst.modell ?? voreingestelltesModell);
    if (!_aktuell(lauf)) return;
    state = OhneSchluessel(topf: topf);
  }

  /// Die Modellliste für das Blatt — **live**, nicht zwischengespeichert.
  /// Wirft [KiFehler]; ohne Schlüssel [SchluesselAbgelehnt].
  Future<List<KiModell>> ladeModelle() async {
    final schluessel = await _speicher.lies();
    if (schluessel == null) throw const SchluesselAbgelehnt();
    return _anbieter.modelle(schluessel);
  }

  /// Wählt [modell] für die Foto-Schätzung — erst, wenn es das Testbild
  /// mit 200 beantwortet. Sonst bleibt das alte gewählt. Die Token des
  /// Testbilds zählen in den Verbrauch.
  Future<KiWahl> waehleModell(String modell) async {
    final vorher = state;
    if (vorher is MitSchluessel && vorher.topf.erreicht) return KiWahl.limit;
    final schluessel = await _speicher.lies();
    if (schluessel == null) return KiWahl.abgelehnt;

    final KiVerbrauch verbrauch;
    try {
      verbrauch = await _anbieter.testbild(
        schluessel: schluessel,
        modell: modell,
      );
    } on SchluesselAbgelehnt {
      return KiWahl.abgelehnt;
    } on KeinNetz {
      return KiWahl.keinNetz;
    } on Kontingent {
      return KiWahl.kontingent;
    } on KiFehler {
      return KiWahl.gestoert;
    }
    if (!ref.mounted) return KiWahl.gestoert;

    final lauf = ++_lauf;
    final bisher = await _repo.einstellungen();
    final preis = preisFuer(modell, bisher.preise);
    await _repo.protokolliere(
      zeitpunkt: _jetzt,
      modell: modell,
      zweck: 'testbild',
      verbrauch: verbrauch,
      kosten: preis == null ? null : kostenUsd(verbrauch, preis),
    );
    await _repo.setzeModell(modell);
    final einst = await _repo.einstellungen();
    final topf = await _topf(einst, modell);
    final jetzt = state;
    if (!_aktuell(lauf) || jetzt is! MitSchluessel) return KiWahl.gewaehlt;
    state = jetzt._mit(modell: modell, gemerktFehlt: () => null, topf: topf);
    return KiWahl.gewaehlt;
  }

  /// Setzt das Monatslimit in US-Dollar.
  Future<void> setzeLimit(double limitUsd) async {
    await _repo.setzeLimit(limitUsd);
    await _aktualisiereTopf();
  }

  /// Setzt Tims Preis für das Modell, das die Foto-Schätzung gerade nutzt.
  Future<void> setzePreis(KiPreis preis) async {
    final modell = switch (state) {
      MitSchluessel(:final modell) => modell,
      OhneSchluessel(:final topf) => topf.preisModell,
      KiZugangLaedt() => null,
    };
    if (modell == null) return;
    await _repo.setzePreis(modell, preis);
    await _aktualisiereTopf();
  }

  /// Liest den Verbrauch neu, nachdem anderswo eine Antwort gezählt wurde
  /// — die Foto-Schätzung (#341) protokolliert selbst und sagt dann
  /// Bescheid. Ohne das stünde im KI-Zugang und im Sucher der Stand von
  /// vor der Anfrage, und das Limit griffe erst nach einem Neustart.
  Future<void> aktualisiereVerbrauch() => _aktualisiereTopf();

  Future<void> _aktualisiereTopf() async {
    final lauf = ++_lauf;
    final einst = await _repo.einstellungen();
    final jetzt = state;
    final modell = switch (jetzt) {
      MitSchluessel(:final modell) => modell,
      _ => einst.modell ?? voreingestelltesModell,
    };
    final topf = await _topf(einst, modell);
    if (!_aktuell(lauf)) return;
    state = switch (state) {
      final MitSchluessel m => m._mit(topf: topf),
      OhneSchluessel() => OhneSchluessel(topf: topf),
      final KiZugangLaedt l => l,
    };
  }

  Future<KiTopf> _topf(KiEinstellungenStand einst, String modell) async {
    final jetzt = _jetzt;
    final summe = await _repo.monat(monatsSchluessel(jetzt));
    final zuletzt = await _repo.letzteAnfrage();
    return KiTopf(
      summe: summe,
      zuletzt: zuletzt,
      limitUsd: einst.limitUsd ?? standardLimitUsd,
      preisModell: modell,
      preis: preisFuer(modell, einst.preise),
      limitEnde: naechsterMonatsbeginn(jetzt),
    );
  }

  static KiPruefung? _pruefungAus(KiEinstellungenStand einst) {
    final am = einst.geprueftAm;
    final ergebnis = einst.pruefErgebnis;
    if (am == null || ergebnis == null) return null;
    return KiPruefung(am: am, ergebnis: ergebnis);
  }
}
