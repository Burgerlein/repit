// Die Typen der Live-Aktivität auf der Dart-Seite (#367, Task 5 des Plans
// `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Spec
// `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`, „Der
// Kanal" und „Die Dart-Seite").
//
// API und Vertrag sind durch `app/test/live/live_anzeige_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf). Diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

/// Was aus einem `zeige` geworden ist.
///
/// **`zeige` wirft nicht** (Spec). Eine Karte, die nicht aufgeht, darf
/// weder Buchen noch Öffnen aufhalten, deshalb steht jeder Ausgang hier
/// als Wert und nicht als Ausnahme.
sealed class LiveErgebnis {
  const LiveErgebnis();
}

/// Swift hat die Aktivität neu gestartet (`"gestartet"`).
final class LiveGestartet extends LiveErgebnis {
  const LiveGestartet();
}

/// Swift hat die laufende Aktivität aktualisiert (`"aktualisiert"`).
final class LiveAktualisiert extends LiveErgebnis {
  const LiveAktualisiert();
}

/// Tim hat Live-Aktivitäten in den Einstellungen abgeschaltet
/// (`"abgeschaltet"`, V7). Kein Fehler, sondern seine Entscheidung.
final class LiveAbgeschaltet extends LiveErgebnis {
  const LiveAbgeschaltet();
}

/// ActivityKit oder der Kanal ist gescheitert — oder Swift hat etwas
/// geantwortet, das keines der drei Wörter ist.
///
/// Eine unbekannte oder fehlende Antwort landet **hier** und nicht still
/// bei [LiveGestartet]: Als Erfolg zu gelten, wäre genau die stille
/// Umdeutung, die `CLAUDE.md` für den Kanal verbietet.
final class LiveFehlgeschlagen extends LiveErgebnis {
  const LiveFehlgeschlagen(this.meldung);

  final String? meldung;
}

/// Auf dieser Plattform gibt es keine Gegenseite
/// (`MissingPluginException`) — etwa in Tests ohne Attrappe oder auf
/// einer Plattform ohne ActivityKit.
final class LiveNichtVerfuegbar extends LiveErgebnis {
  const LiveNichtVerfuegbar();
}

/// Wohin ein Tipp auf die Karte führen soll.
///
/// Ein unbekannter Host im Link ergibt kein Ziel, sondern `null`.
enum LiveZiel {
  /// `repit://mahlzeit-eintragen` — öffnet dasselbe wie (+).
  mahlzeitEintragen,
}

/// Was die Live-Aktivität gerade zeigen soll.
///
/// **`==` und `hashCode` sind Pflicht.** Ein unverändertes Soll darf keinen
/// Aufruf an iOS auslösen (Review Focus 4); ohne Wertgleichheit wäre jedes
/// neu gerechnete Soll ungleich dem vorigen, und jede Neuberechnung ginge
/// als Update an die Aktivität — das Update-Budget und Fehler `03`
/// zugleich.
///
/// Später kommen `TrainingLive` (#78) und `KochenLive` (#134) dazu.
@immutable
sealed class LiveSoll {
  const LiveSoll();
}

/// Keine Fassung ist dran (`waehleFassung` liefert `null`): Jede laufende
/// Aktivität wird beendet.
final class KeineLive extends LiveSoll {
  const KeineLive();

  @override
  bool operator ==(Object other) => other is KeineLive;

  @override
  int get hashCode => (KeineLive).hashCode;

  @override
  String toString() => 'KeineLive()';
}

/// Die Essen-Fassung mit dieser [karte].
final class EssenLive extends LiveSoll {
  const EssenLive(this.karte);

  final EssenKarte karte;

  @override
  bool operator ==(Object other) => other is EssenLive && other.karte == karte;

  @override
  int get hashCode => Object.hash(EssenLive, karte);

  @override
  String toString() => 'EssenLive($karte)';
}

/// Die vollständigen Argumente von `zeige`, buchstabengleich zur Spec
/// („Dart → Swift").
///
/// **Fehlt ein Wert, fehlt der Schlüssel.** Er steht weder als `null` noch
/// als `0` in der Map (`CLAUDE.md`: „`nil` darf auf dem Weg durch den Kanal
/// niemals zu `0` werden"). Im Einzelnen:
///
/// - Eine Mahlzeit **ohne Eintrag** schickt nie `kcal`, egal was im Ring
///   steht — eine offene Mahlzeit ist nicht „0 kcal" (Festlegung des
///   Koordinators, siehe Testkopf).
/// - Eine Mahlzeit mit Eintrag und `kcal: null` schickt ebenfalls keinen
///   Schlüssel; sie steht auf der Karte erledigt da, mit „–".
/// - Eine **gewogene `0`** einer Mahlzeit mit Eintrag geht als `0` mit
///   (der schwarze Kaffee), und eine Serie von `0` ebenso (V11).
/// - `anteil` (#374, V15) steht **nur bei einer Mahlzeit mit Eintrag**
///   und nur, wenn der Ring einen trägt. Ohne Eintrag fehlt er immer, wie
///   `kcal` — auch wenn der Ring `0` trägt. Ohne Ziel fehlt er ebenfalls;
///   nur dann zeichnet die Karte noch nach V2. Ein Anteil von genau `0`
///   bei Eintrag geht als `0` mit. Er geht als `double`.
/// - `ersteOffene` fehlt, wenn keine Hauptmahlzeit offen ist.
///
/// `verfaelltUm` geht als Millisekunden seit 1970, UTC.
Map<String, Object?> essenKarteAlsMap(
  EssenKarte karte, {
  required bool frisch,
}) {
  final ersteOffene = karte.ersteOffene;
  return {
    'fassung': 'essen',
    'frisch': frisch,
    'verfaelltUm': karte.verfaelltUm.millisecondsSinceEpoch,
    'essen': {
      'mahlzeiten': [
        for (final ring in karte.ringe) _ringAlsMap(ring),
      ],
      'ersteOffene': ?ersteOffene?.name,
      'serie': karte.serie,
      'serieAbMorgen': karte.serieAbMorgen,
    },
  };
}

Map<String, Object?> _ringAlsMap(MahlzeitRing ring) {
  final kcal = ring.eintrag ? ring.kcal : null;
  final anteil = ring.eintrag ? ring.anteil : null;
  return {
    'mahlzeit': ring.mahlzeit.name,
    'eintrag': ring.eintrag,
    'kcal': ?kcal,
    'anteil': ?anteil,
  };
}
