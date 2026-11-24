// Der Zustand des Prüfblatts der Foto-Schätzung (#341) — Spec
// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Foto-Schätzung
// als erste Aktion", Schritte 4–7; Entwurf `docs/screens/screens/
// erfassen.js`, Zustände `foto-schaetzt` bis `foto-kontingent`.
//
// Geprüft über `app/test/ernaehrung/ki_pruefblatt_test.dart` — diese Datei
// darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **`Messwert<T>` gilt hier nicht** (Spec, „Zustände und die eine Form"):
// Die Schätzung ist eine Netzanfrage mit eigenem, versiegeltem Zustand.
// Und `AsyncValue` gelangt nicht in die Ansicht — der Notifier ist synchron
// und beginnt mit [Laeuft].
//
// **Kein Zustand hält das Foto.** Es liegt in `kiFotoProvider` und wird
// für jede Anfrage dort gelesen, als lokale Variable an den Anbieter
// gereicht und vergessen (Review Focus 6). Ebenso der Schlüssel: frisch
// aus dem Speicher, nie im Zustand.
//
// **Ausgeführt wird hier nichts.** Der Vorschlag wird gehalten und
// bearbeitet; buchen tut allein der Knopf im Prüfblatt über
// `KiAktionen.fuehreAus` (Spec, „Die Aktionsliste").
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../health/health_provider.dart';
import '../ki/gemini_client.dart';
import '../ki/gemini_preise.dart';
import '../ki/ki_repository.dart';
import '../ki/ki_schluessel.dart';
import '../ki/ki_zugang_provider.dart';
import '../tag/laufender_tag_provider.dart';
import 'erfassen_formular.dart';
import 'ki_sucher.dart';

/// Wohin gebucht wird: Mahlzeit und Berliner Uhrzeit. Der Tag steht im
/// Auftrag und ist hier nicht änderbar — wie im Buchungsblatt.
@immutable
class KiZiel {
  const KiZiel({required this.mahlzeit, required this.minuten});

  final Mahlzeit mahlzeit;

  /// Minuten seit Mitternacht auf der Berliner Wanduhr.
  final int minuten;

  @override
  bool operator ==(Object other) =>
      other is KiZiel && other.mahlzeit == mahlzeit && other.minuten == minuten;

  @override
  int get hashCode => Object.hash(mahlzeit, minuten);
}

/// Was das Prüfblatt zeigt. Der `switch` darüber ist vollständig; käme ein
/// fünfter Zustand, zeigte der Analyzer jede Stelle, die ihn nicht kennt.
sealed class SchaetzungZustand {
  const SchaetzungZustand();
}

/// Die Anfrage läuft. **Kein Grund, kein Ergebnis** — nur graue Zeilen in
/// derselben Form (`01`). Mahlzeit und Uhrzeit stehen schon da, damit die
/// Knopfzeile nicht springt, wenn das Ergebnis kommt.
final class Laeuft extends SchaetzungZustand {
  const Laeuft(this.ziel);

  final KiZiel ziel;

  @override
  bool operator ==(Object other) => other is Laeuft && other.ziel == ziel;

  @override
  int get hashCode => Object.hash(Laeuft, ziel);
}

/// Ein Vorschlag liegt vor — nichts ist gebucht.
///
/// **Ohne inhaltliches `==`:** [KiVorschlag] trägt im Kern keine
/// Wertgleichheit. Das kostet hier nichts: Ein neuer Zustand entsteht nur
/// mit einer Antwort oder einer Änderung von Hand, nie bei einer Lesung,
/// und abgeleitet wird von ihm nichts (`03`).
final class Vorschlag extends SchaetzungZustand {
  const Vorschlag(
    this.vorschlag, {
    required this.geaendert,
    required this.geaenderteZeilen,
    this.notiz,
  });

  /// Die Aktion samt Herkunft. Hält **alle** Posten, auch die unsicheren;
  /// was gebucht wird, filtert `uebernommen` — im Ausführer, nicht hier.
  final KiVorschlag vorschlag;

  /// Ob Tim seit der letzten Antwort etwas geändert hat. Dann sind die
  /// Nährwerte nicht mehr die der Erkennung, und der Schirm sagt das.
  final bool geaendert;

  /// Geänderte, ergänzte und gestrichene Zeilen seit der letzten Antwort.
  final int geaenderteZeilen;

  /// `note` der Antwort — was der KI unsicher war. Nie leer: Eine leere
  /// oder nur aus Leerraum bestehende `note` kommt hier als `null` an
  /// (#354).
  final String? notiz;

  /// Die eine Aktion, die es gibt. Kommt eine zweite in den Kern, zeigt
  /// der Analyzer hierher.
  EintraegeBuchen get aktion => switch (vorschlag.aktion) {
    final EintraegeBuchen a => a,
  };

  KiZiel get ziel {
    final (stunde, minute) = BerlinCalendar.wallClock(aktion.zeitpunkt);
    return KiZiel(
      mahlzeit: aktion.mahlzeit,
      minuten: stunde * Duration.minutesPerHour + minute,
    );
  }
}

/// Das Modell hat kein Essen erkannt (`isFood: false`) — eine gültige
/// Antwort, kein Fehler.
final class NichtsErkannt extends SchaetzungZustand {
  const NichtsErkannt();

  @override
  bool operator ==(Object other) => other is NichtsErkannt;

  @override
  int get hashCode => (NichtsErkannt).hashCode;
}

/// Die Anfrage ist gescheitert. Gebucht werden kann nichts.
final class Gescheitert extends SchaetzungZustand {
  const Gescheitert(this.fehler);

  final KiFehler fehler;

  @override
  bool operator ==(Object other) =>
      other is Gescheitert && other.fehler == fehler;

  @override
  int get hashCode => Object.hash(Gescheitert, fehler);
}

/// Die Schätzung zu einem Auftrag. Startet von selbst, sobald das
/// Prüfblatt sie liest.
///
/// `autoDispose`: Schließt das Blatt, ist der Vorschlag weg. Eine Antwort,
/// die danach noch eintrifft, wird gezählt, aber nicht mehr gezeigt.
final kiSchaetzungProvider = NotifierProvider.autoDispose
    .family<KiSchaetzungNotifier, SchaetzungZustand, KiAuftrag>(
      KiSchaetzungNotifier.new,
    );

class KiSchaetzungNotifier extends Notifier<SchaetzungZustand> {
  KiSchaetzungNotifier(this.auftrag);

  final KiAuftrag auftrag;

  late KiZiel _ziel;

  /// Der Grund des laufenden Tages, wenn der Auftrag auf ihn bucht, sonst
  /// `normal` (V14) — wie im Buchungsblatt. Bleibt beim Umstellen von
  /// Mahlzeit und Uhrzeit stehen.
  late Tagesgrund _grund;

  /// Tims Hinweis an die KI, aus dem Prüfblatt. Die erste Anfrage geht
  /// ohne (#355: kein Blatt vor der Schätzung). **Wird nie gespeichert.**
  String? _hinweis;

  /// Die Zeilen, wie Tim sie gerade sieht — auch über einen gescheiterten
  /// Nachlauf hinweg: „Nochmal versuchen" schickt seine Änderungen wieder
  /// mit, statt sie wegzuwerfen.
  List<SchaetzPosten> _posten = const [];

  KiHerkunft? _herkunft;
  String? _notiz;

  /// Änderungen von Hand seit der letzten Antwort.
  int _geaendert = 0;

  /// Zählt die Läufe. Eine Antwort, die erst nach einem neueren Lauf
  /// zurückkommt, wird gezählt, aber nicht mehr gezeigt.
  int _lauf = 0;

  @override
  SchaetzungZustand build() {
    final jetzt = ref.read(clockProvider)();
    final (stunde, minute) = BerlinCalendar.wallClock(jetzt);
    final minuten = stunde * Duration.minutesPerHour + minute;
    _grund = buchungsgrund(
      ref.read(laufenderTagProvider),
      auftrag.tagesSchluessel,
    );
    // Wie beim Buchungsblatt (#328, #456): die Uhrzeit des Trackens; die
    // Mahlzeit aus dem Auftrag, sonst dieselbe Vorwahl wie im Blatt.
    _ziel = KiZiel(
      mahlzeit: vorgewaehlteMahlzeit(
        jetzt: jetzt,
        mahlzeit: auftrag.mahlzeit,
        grund: _grund,
      ),
      minuten: minuten,
    );
    unawaited(_schaetze(ausBuild: true));
    return Laeuft(_ziel);
  }

  /// „Neu berechnen" bzw. „Nochmal versuchen": dasselbe Foto, der Hinweis
  /// [hinweis], und die von Tim geänderten Zeilen als Vorgabe.
  ///
  /// **Nur auf Tipp** — ein zweiter Lauf kostet Geld und rechnet nie von
  /// selbst.
  void neuBerechnen(String? hinweis) {
    final text = hinweis?.trim();
    _hinweis = text == null || text.isEmpty ? null : text;
    unawaited(_schaetze());
  }

  /// [ausBuild]: aus `build` gerufen, wo `state` noch nicht gesetzt ist —
  /// dort gibt `build` selbst [Laeuft] zurück.
  Future<void> _schaetze({bool ausBuild = false}) async {
    final lauf = ++_lauf;
    if (!ausBuild) state = Laeuft(_ziel);

    // Alles, was nach dem `await` noch gebraucht wird, vorher holen: Die
    // Antwort wird gezählt, auch wenn das Blatt inzwischen zu ist.
    final foto = ref.read(kiFotoProvider);
    final repo = ref.read(kiRepositoryProvider);
    final anbieter = ref.read(kiAnbieterProvider);
    final uhr = ref.read(clockProvider);
    final zugang = ref.read(kiZugangProvider.notifier);
    final gemerkt = switch (ref.read(kiZugangProvider)) {
      MitSchluessel(:final modell) => modell,
      _ => null,
    };
    final schluessel = await ref.read(kiSchluesselProvider).lies();
    final einst = await repo.einstellungen();
    final modell = gemerkt ?? einst.modell ?? voreingestelltesModell;
    final feste = [
      for (final p in _posten)
        if (p.herkunft != PostenHerkunft.erkannt) p,
    ];

    if (foto == null) return; // verworfen — das Blatt schließt gerade
    if (schluessel == null) {
      // Entfernt, während das Blatt offen war: derselbe Weg wie ein
      // abgelehnter Schlüssel — in den KI-Zugang.
      _setze(lauf, const Gescheitert(SchluesselAbgelehnt()));
      return;
    }

    Future<void> zaehle(KiVerbrauch verbrauch) async {
      final preis = preisFuer(modell, einst.preise);
      await repo.protokolliere(
        zeitpunkt: uhr(),
        modell: modell,
        zweck: 'foto',
        verbrauch: verbrauch,
        kosten: preis == null ? null : kostenUsd(verbrauch, preis),
      );
      await zugang.aktualisiereVerbrauch();
    }

    try {
      final ergebnis = await anbieter.schaetze(
        schluessel: schluessel,
        modell: modell,
        jpeg: foto,
        hinweis: _hinweis,
        feste: feste,
      );
      await zaehle(ergebnis.verbrauch);
      if (!_aktuell(lauf)) return;

      switch (ergebnis.antwort) {
        case KeinEssen():
          _setze(lauf, const NichtsErkannt());
        case Erkannt(:final posten, :final notiz):
          _herkunft = KiHerkunft(
            anbieter: 'gemini',
            modell: modell,
            zeitpunkt: uhr(),
            zweck: 'foto',
          );
          _posten = _mitVorgabe(feste, posten);
          // Gemini schickt `"note": ""`, wenn es nichts anzumerken gibt
          // (#354). Leer ist keine Notiz — sonst stünde im Prüfblatt ein
          // Kasten ohne Text.
          _notiz = notiz == null || notiz.trim().isEmpty ? null : notiz;
          _geaendert = 0;
          _setze(lauf, _vorschlag());
      }
    } on AntwortUnbrauchbar catch (fehler) {
      final verbrauch = fehler.verbrauch;
      if (verbrauch != null) await zaehle(verbrauch);
      _setze(lauf, Gescheitert(fehler));
    } on KiFehler catch (fehler) {
      _setze(lauf, Gescheitert(fehler));
    }
  }

  bool _aktuell(int lauf) => ref.mounted && lauf == _lauf;

  void _setze(int lauf, SchaetzungZustand neu) {
    if (_aktuell(lauf)) state = neu;
  }

  /// Die Vorgabe bleibt, wie Tim sie gesetzt hat; aus der Antwort kommt
  /// dazu, was nicht schon als Vorgabe dasteht — auch wenn das Modell sie
  /// entgegen dem Prompt noch einmal aufführt.
  static List<SchaetzPosten> _mitVorgabe(
    List<SchaetzPosten> feste,
    List<SchaetzPosten> antwort,
  ) {
    final namen = {for (final p in feste) p.name.trim().toLowerCase()};
    return [
      ...feste,
      for (final p in antwort)
        if (!namen.contains(p.name.trim().toLowerCase())) p,
    ];
  }

  Vorschlag _vorschlag() => Vorschlag(
    KiVorschlag(
      aktion: EintraegeBuchen(
        posten: _posten,
        mahlzeit: _ziel.mahlzeit,
        tagesSchluessel: auftrag.tagesSchluessel,
        zeitpunkt: zeitpunktImTag(
          tag: auftrag.tagesSchluessel,
          minuten: _ziel.minuten,
          grund: _grund,
        ),
      ),
      herkunft: _herkunft!,
    ),
    geaendert: _geaendert > 0,
    geaenderteZeilen: _geaendert,
    notiz: _notiz,
  );

  /// Nur, solange ein Vorschlag dasteht — sonst gibt es nichts zu ändern.
  void _aendere(List<SchaetzPosten> posten) {
    if (state is! Vorschlag) return;
    _posten = List.unmodifiable(posten);
    _geaendert++;
    state = _vorschlag();
  }

  /// Menge ändern: Die Nährwerte skalieren linear aus dem geschätzten
  /// Posten (`mitMenge`), die Zeile heißt danach „von dir".
  void aendereMenge(int index, double gramm) {
    if (index < 0 || index >= _posten.length) return;
    _aendere([..._posten]..[index] = mitMenge(_posten[index], gramm));
  }

  /// Lebensmittel austauschen: dieselbe Menge, die Nährwerte aus der
  /// eigenen Datenbank (`Naehrwerte.fuerMenge`). Ohne geschätzte Menge
  /// gelten 100 g — wie im Buchungsblatt.
  void tausche(int index, LebensmittelVorlage vorlage) {
    if (index < 0 || index >= _posten.length) return;
    final gramm = _posten[index].gramm ?? 100;
    _aendere(
      [..._posten]
        ..[index] = _ausVorlage(vorlage, gramm, PostenHerkunft.vonDir),
    );
  }

  void streiche(int index) {
    if (index < 0 || index >= _posten.length) return;
    _aendere([..._posten]..removeAt(index));
  }

  /// „Zeile hinzufügen": 100 g des gewählten Lebensmittels, „ergänzt".
  void ergaenze(LebensmittelVorlage vorlage) => _aendere([
    ..._posten,
    _ausVorlage(vorlage, 100, PostenHerkunft.ergaenzt),
  ]);

  static SchaetzPosten _ausVorlage(
    LebensmittelVorlage vorlage,
    double gramm,
    PostenHerkunft herkunft,
  ) => SchaetzPosten(
    name: vorlage.name,
    gramm: gramm,
    werte: vorlage.je100g.fuerMenge(gramm),
    sicher: true,
    herkunft: herkunft,
  );

  /// **Umhängen zieht die Uhrzeit mit** — wie im Buchungsblatt.
  void setzeMahlzeit(Mahlzeit mahlzeit) => _setzeZiel(
    KiZiel(
      mahlzeit: mahlzeit,
      minuten: Mahlzeitfenster.mitteInMinuten(mahlzeit),
    ),
  );

  /// Die Mahlzeit bleibt stehen, auch über die Fenstergrenze.
  void setzeUhrzeit(int minuten) =>
      _setzeZiel(KiZiel(mahlzeit: _ziel.mahlzeit, minuten: minuten));

  void _setzeZiel(KiZiel ziel) {
    _ziel = ziel;
    state = switch (state) {
      Laeuft() => Laeuft(ziel),
      Vorschlag() => _vorschlag(),
      final andere => andere,
    };
  }
}
