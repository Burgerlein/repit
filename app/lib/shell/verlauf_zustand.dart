// Der Zustand der Verlaufsseiten (#94) — **ein** Schirm für vier Werte
// (Schlaf, HRV, Ruhepuls, Atemfrequenz); welcher gemeint ist, trägt
// [VerlaufArt] als Parameter. Die Oberfläche liegt in `verlauf_view.dart`.
//
// API und Vertrag sind durch `app/test/shell/verlauf_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung des Schnitts) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Keine Schwelle steht hier als Zahl.** Jede Grenze rechnet mit
// [RecoveryTrafficLight]; in Swift stehen 6, 5, 0,8 und 1,5 mehrfach im
// Quelltext, einmal als Wahrheit und sonst als Beschriftung.
//
// **Keine Nutzertexte.** Namen, Einheiten, Erklärsätze und Fußnoten stehen
// in der View (`CLAUDE.md`). Hier stehen Zahlen, Daten und Enums.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import 'diagramm_zeitraum.dart';
import 'erholung_zustand.dart';

/// Die vier Verläufe. **Ohne Alkohol:** Für eine Ja/Nein-Angabe gibt es
/// keine Kurve, und eine Eingabe dafür ist nicht gebaut.
///
/// Ein eigenes Enum und nicht [RecoveryTrendKind]: Der Kern kennt fünf
/// Verlaufszeilen, und die fünfte hätte zur Laufzeit abgelehnt werden
/// müssen. Mit vier Fällen ist der Fall unausdrückbar.
enum VerlaufArt { schlaf, hrv, ruhepuls, atemfrequenz }

/// Höhere Werte sind besser — bestimmt, auf welcher Seite die
/// Signalschwelle liegt.
///
/// Zwei der vier sind andersherum (`TrendDetailView.swift:38–39`): Eine
/// Einfärbung nach „unter der Linie ist rot" wäre für Ruhepuls und
/// Atemfrequenz falsch.
bool hoeherIstBesser(VerlaufArt art) =>
    art == VerlaufArt.schlaf || art == VerlaufArt.hrv;

/// Schlaf wird als Balken gezeichnet, die übrigen drei als Linie
/// (`TrendDetailView.swift:109`).
bool alsBalken(VerlaufArt art) => art == VerlaufArt.schlaf;

/// Die Verlaufszeile des Erholung-Schirms → ihr Schirm. `null` für die
/// Alkohol-Zeile: Sie führt nirgendwohin.
///
/// Die **eine** Stelle, an der diese Zuordnung steht.
VerlaufArt? verlaufArtZu(RecoveryTrendKind art) => switch (art) {
  RecoveryTrendKind.sleep => VerlaufArt.schlaf,
  RecoveryTrendKind.hrv => VerlaufArt.hrv,
  RecoveryTrendKind.restingHeartRate => VerlaufArt.ruhepuls,
  RecoveryTrendKind.respiratoryRate => VerlaufArt.atemfrequenz,
  // Ein Zähler über etwas, das niemand eintragen kann, wäre eine
  // Behauptung — und ein Diagramm darüber erst recht.
  RecoveryTrendKind.alcoholDays => null,
};

/// Die Stufen dieses Schirms: **W M 6M J** (`docs/SPEC.md` 4.6).
///
/// Kein `T`: Eine Nacht hat keine Stundenwerte. Welche davon beim
/// Aufschlagen gewählt ist, entscheidet `startStufe` — die kleinste.
const List<DiagrammStufe> verlaufsStufen = [
  DiagrammStufe.woche,
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// Wie viele der jüngsten Werte die Spanne trägt — „Spanne 7 Tage".
const int _spanneWerte = 7;

/// Alles, was der Schirm an Zahlen zeigt, einmal gerechnet.
///
/// Werttyp mit `==` und `hashCode`: Er wird von einem Provider gehalten und
/// an [Zeitdiagramm] weitergereicht. Ohne Gleichheit wäre jede neu gebaute
/// Fassung ungleich der vorigen, und jedes Bild rechnete neu — das wäre
/// `docs/todo/03`, wortgleich im neuen Code.
@immutable
class VerlaufDaten {
  const VerlaufDaten({
    required this.art,
    required this.reihe,
    required this.aktuell,
    required this.median,
    required this.signalAb,
    required this.spanne,
  });

  final VerlaufArt art;

  /// Ein Punkt je gemessenem Tag, ältester zuerst. **Lücken bleiben
  /// Lücken:** Ein Tag ohne diesen Wert fehlt, er steht nicht mit 0 darin.
  final List<({DateTime tag, double wert})> reihe;

  /// Der jüngste Wert der Reihe, nicht ihr Schnitt — der Fensterschnitt
  /// steht in der Kopfzeile des Diagramms.
  final double? aktuell;

  /// Der eigene Median **ohne heute** ([RecoveryBaseline]). `null` heißt
  /// „nicht genug Werte"; eine erfundene Zahl wäre schlimmer als gar keine.
  final double? median;

  /// Die Schwelle als Zahl, nicht als Satz — „unter" gehört in die View.
  /// Nur der Schlaf hat eine, die nicht am Median hängt.
  final double? signalAb;

  /// Kleinster und größter der jüngsten sieben Werte.
  final ({double von, double bis})? spanne;

  /// Ob dieser Wert ein Warnsignal ist — **wortgleich mit der Ampel**.
  ///
  /// Die Seite allein genügt nicht: Der Schlaf ist **strikt** kleiner
  /// (genau sechs Stunden sind kein Signal), die HRV kleiner **oder
  /// gleich** (genau 80 % des Medians sind eines). Jede Zeile steht so auch
  /// in [RecoveryTrafficLight.evaluate]; zwei Fassungen derselben Regel
  /// driften.
  bool istSignal(double wert) {
    final schwelle = signalAb;
    // Ohne Vergleichswert gibt es kein Signal — nicht „alles ist rot" und
    // nicht „alles ist grün mit Begründung".
    if (schwelle == null) return false;
    return switch (art) {
      VerlaufArt.schlaf => wert < schwelle,
      VerlaufArt.hrv => wert <= schwelle,
      VerlaufArt.ruhepuls => wert >= schwelle,
      VerlaufArt.atemfrequenz => wert >= schwelle,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VerlaufDaten &&
      other.art == art &&
      listEquals(other.reihe, reihe) &&
      other.aktuell == aktuell &&
      other.median == median &&
      other.signalAb == signalAb &&
      other.spanne == spanne;

  @override
  int get hashCode => Object.hash(
    art,
    Object.hashAll(reihe),
    aktuell,
    median,
    signalAb,
    spanne,
  );
}

/// Der Zustand eines Verlaufsschirms.
@immutable
class VerlaufZustand {
  const VerlaufZustand({required this.art, required this.daten});

  final VerlaufArt art;

  /// Die vier Zustände reicht der Schirm durch. **Eine leere Reihe ist
  /// kein Leerzustand:** Der Lauf hat etwas geliefert, nur für diesen einen
  /// Wert nichts — der Satz „keine Werte" hängt an der leeren Reihe, nicht
  /// am Zustand.
  final Messwert<VerlaufDaten> daten;

  @override
  bool operator ==(Object other) =>
      other is VerlaufZustand && other.art == art && other.daten == daten;

  @override
  int get hashCode => Object.hash(art, daten);
}

/// Rechnet den Verlauf einer Art aus dem Zustand des Erholung-Schirms.
///
/// **Aus [ErholungZustand] und nicht aus den Rohdaten**, weil dort der
/// [RecoverySnapshot] schon liegt: Fenster, Tagesgrenzen, Mediane und die
/// Regel „der heutige Wert gehört nicht in seinen eigenen Median" stehen
/// damit genau einmal. Ein zweiter Schnappschuss neben dem ersten wäre eine
/// zweite Wahrheit über dieselben Zahlen.
VerlaufZustand verlaufZustandAus({
  required VerlaufArt art,
  required ErholungZustand erholung,
}) => VerlaufZustand(
  art: art,
  // Vollständig über den sealed-Typ: Käme ein fünfter Zustand, zeigte der
  // Analyzer genau hierhin.
  daten: switch (erholung.daten) {
    NochNie<ErholungDaten>() => const NochNie<VerlaufDaten>(),
    LeerNachLauf<ErholungDaten>(:final gelaufen) => LeerNachLauf<VerlaufDaten>(
      gelaufen: gelaufen,
    ),
    Fehlgeschlagen<ErholungDaten>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<VerlaufDaten>(fehler: fehler, gelaufen: gelaufen),
    Bekannt<ErholungDaten>(:final wert, :final stand, :final laeuft) =>
      Bekannt<VerlaufDaten>(
        _daten(art, wert.schnappschuss),
        stand: stand,
        laeuft: laeuft,
      ),
  },
);

VerlaufDaten _daten(VerlaufArt art, RecoverySnapshot schnappschuss) {
  final reihe = _reihe(art, schnappschuss);
  final median = _median(art, schnappschuss.baseline);
  final jungste = reihe.length <= _spanneWerte
      ? reihe
      : reihe.sublist(reihe.length - _spanneWerte);

  return VerlaufDaten(
    art: art,
    reihe: reihe,
    aktuell: reihe.isEmpty ? null : reihe.last.wert,
    median: median,
    signalAb: _signalAb(art, median),
    spanne: jungste.isEmpty
        ? null
        : (
            von: jungste
                .map((punkt) => punkt.wert)
                .reduce((a, b) => math.min(a, b)),
            bis: jungste
                .map((punkt) => punkt.wert)
                .reduce((a, b) => math.max(a, b)),
          ),
  );
}

/// Ein Punkt je gemessenem Tag, ältester zuerst.
///
/// `days` und `nights` kommen aus [RecoverySnapshot] bereits sortiert und
/// auf den Berliner Tagesbeginn gezogen — ein Diagramm, das daraus seine
/// x-Achse baut, bekommt damit gleich lange Abstände.
List<({DateTime tag, double wert})> _reihe(
  VerlaufArt art,
  RecoverySnapshot schnappschuss,
) => switch (art) {
  VerlaufArt.schlaf => [
    for (final nacht in schnappschuss.nights)
      (tag: nacht.date, wert: nacht.asleepHours),
  ],
  VerlaufArt.hrv => _ausTagen(schnappschuss, (tag) => tag.hrv),
  VerlaufArt.ruhepuls => _ausTagen(
    schnappschuss,
    (tag) => tag.restingHeartRate,
  ),
  VerlaufArt.atemfrequenz => _ausTagen(
    schnappschuss,
    (tag) => tag.respiratoryRate,
  ),
};

/// Ein fehlender Wert lässt den Tag **ausfallen** — er zieht weder die
/// eigene noch eine andere Reihe mit herunter.
List<({DateTime tag, double wert})> _ausTagen(
  RecoverySnapshot schnappschuss,
  double? Function(RecoveryDay tag) feld,
) => [
  for (final tag in schnappschuss.days)
    if (feld(tag) case final wert?) (tag: tag.date, wert: wert),
];

double? _median(VerlaufArt art, RecoveryBaseline baseline) => switch (art) {
  VerlaufArt.schlaf => baseline.sleepHours,
  VerlaufArt.hrv => baseline.hrv,
  VerlaufArt.ruhepuls => baseline.restingHeartRate,
  VerlaufArt.atemfrequenz => baseline.respiratoryRate,
};

/// Die Schwelle, ab der ein Wert als Warnsignal zählt.
///
/// **Der Schlaf hat seine auch ohne Median:** Die Sechs-Stunden-Grenze
/// steht fest (`docs/SPEC.md` 4.6) und hängt weder am Median noch am
/// Schlafziel. Die übrigen drei fallen ohne Median weg — ein fehlender
/// Median schaltet nur seine eigene Metrik ab.
double? _signalAb(VerlaufArt art, double? median) => switch (art) {
  VerlaufArt.schlaf => RecoveryTrafficLight.minimumSleepHours,
  VerlaufArt.hrv =>
    median == null ? null : median * RecoveryTrafficLight.hrvFactor,
  VerlaufArt.ruhepuls =>
    median == null
        ? null
        : median + RecoveryTrafficLight.restingHeartRateMargin,
  VerlaufArt.atemfrequenz =>
    median == null ? null : median + RecoveryTrafficLight.respiratoryRateMargin,
};

/// Der Zustand **einer** Art, gehalten statt bei jedem Zugriff gerechnet
/// (Hausregel 2, `docs/todo/03`).
///
/// Eine Familie und nicht vier Kopien: Der Schirm gibt es viermal, die
/// Rechnung einmal. Jeder Schlüssel bekommt seinen eigenen Eintrag, der
/// so lange steht, bis sich [erholungProvider] ändert.
///
/// Der Schirm besorgt seine Daten damit selbst: Er ist aus jedem Tab
/// erreichbar, niemand darf sich darauf verlassen, dass eine Übersicht
/// vorher geladen hat.
final verlaufProvider = Provider.family<VerlaufZustand, VerlaufArt>(
  (ref, art) =>
      verlaufZustandAus(art: art, erholung: ref.watch(erholungProvider)),
);
