// Die Ampelfarbe eines Vitalwerts — **einmal**, für jeden Schirm, der sie
// zeigt (#308).
//
// Tim am 04.11.2026 auf dem Gerät: „Schlaf-Dauer 6:18 h auf dem Home-Screen
// grün, im Erholungs-Tab gelb. Sollte einheitlich behandelt werden, die
// Einfärbung." Zwei Funktionen entschieden dasselbe mit verschieden vielen
// Stufen — `verlaufsTon` auf Erholung mit dreien, `_tonFuer` auf Heute mit
// zweien. Die dreistufige Fassung gilt seither überall.
//
// **Warum im Design-System und nicht in einem der beiden Schirme:** Läge
// sie in `erholung_zustand.dart` und `heute_view.dart` importierte sie,
// hinge ein Schirm am anderen. Nutzertexte trägt sie keine, nur die
// Zuordnung Wert → Stufe → Farbe.
//
// **Warum nicht in `trainings_core`:** Die Schwellen stehen längst dort
// (`RecoveryTrafficLight`) und werden hier nur gelesen. Was hinzukommt,
// ist die mittlere Stufe — eine Aussage über die Darstellung, keine Formel
// aus `docs/SPEC.md`.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import 'palette.dart';

/// Was die Ampel über einen Vitalwert gesagt hat — der `tone` aus dem
/// Entwurf (`docs/screens/screens/heute-kombi.js` und
/// `docs/screens/screens/erholung.js`).
///
/// **Ein fachlicher Zustand, keine `Color`** (#254). Gäbe ein Werttyp eine
/// Farbe weiter, entschiede jeder Aufrufer neu, was „gelb" heißt.
///
/// **Vier Stufen, nicht drei plus `null`** (#308). `verlaufsTon` gab bisher
/// `null` zurück, wo es nichts zu sagen gab; [VitalTon] kannte denselben
/// Zustand als `unbeurteilt`. Zwei Schreibweisen für denselben Zustand sind
/// der Zwilling, den dieses Ticket abgeschafft hat — also bleibt eine.
///
/// `farbe` ist die Palette-Zuordnung, **unaufgelöst**: Aufgelöst wird beim
/// Zeichnen ([vitalTonFarbe]), sonst bliebe eine `CupertinoDynamicColor` im
/// Dunkelmodus auf ihrer hellen Variante stehen.
enum VitalTon {
  /// Die Ampel hat über diesen Wert **nichts** gesagt — er fehlt, es gibt
  /// keinen Median, mit dem er sich vergleichen ließe, oder sie ruht nach
  /// der OP (`rated` in `RecoveryEvaluation`). Dann wird auch keine Farbe
  /// behauptet: Grün hieße „im Normalbereich", und das hat niemand gesagt.
  unbeurteilt(null),

  /// Beurteilt, kein Warnsignal, und auch nicht nah daran.
  normal(Palette.ok),

  /// Kein Warnsignal, aber **die halbe Strecke** zur Schwelle ist
  /// überschritten. Die einzige Stufe, die in der Oberfläche entsteht und
  /// nicht im Kern.
  nahAmSignal(Palette.low),

  /// Die Ampel führt den Wert als Warnsignal (`signals`). **Rot und
  /// Warnsignal sind dasselbe:** Ein roter Wert steht zugleich oben im
  /// Hinweiskasten.
  warnsignal(Palette.warn);

  const VitalTon(this.farbe);

  /// `null` heißt „keine eigene Farbe" — dann gilt die gewöhnliche
  /// Schriftfarbe des Schirms.
  final CupertinoDynamicColor? farbe;
}

/// Die **eine** Stelle, an der aus einer Stufe eine Farbe wird.
///
/// `ink` ist die Schriftfarbe, die ohne Ampel gälte. Sie kommt vom
/// Aufrufer, weil die Schirme sie verschieden wählen: Auf der
/// Erholungskarte steht ein unbeurteilter Wert in gewöhnlicher Schrift
/// (**nicht grau** — grau heißt dort „kein Wert", und ein gemessener, nur
/// unverglichener Wert darf nicht wie ein fehlender aussehen), in den
/// Verlaufszeilen steht er gedämpft, wie der Entwurf es führt.
Color vitalTonFarbe(VitalTon ton, BuildContext context, Color ink) =>
    switch (ton.farbe) {
      null => ink,
      final farbe => CupertinoDynamicColor.resolve(farbe, context),
    };

/// Die **eine** Stelle, an der aus Messwert und Urteil eine Stufe wird.
///
/// Geprüft wird in dieser Reihenfolge:
///
/// | Stufe | Regel |
/// |---|---|
/// | [VitalTon.unbeurteilt] | die Ampel hat über diese Metrik nichts gesagt (`rated`) |
/// | [VitalTon.warnsignal] | die Ampel führt sie als Warnsignal (`signals`) |
/// | [VitalTon.nahAmSignal] | kein Signal, aber **die halbe Strecke** zur Schwelle ist überschritten |
/// | [VitalTon.normal] | sonst |
///
/// **Rot und „nicht beurteilt" sagt der Kern, nicht die Oberfläche**
/// (#254). Hier entsteht allein die mittlere Stufe, weil es sie im Kern
/// nicht gibt und auch nicht geben soll: Sie ist eine Auskunft über die
/// Darstellung, kein Teil der Bewertung. Die Schwellen bleiben unverändert
/// (`docs/SPEC.md` 176).
///
/// **`rated`, nicht nur `signals`.** Ohne Median gibt es keinen Vergleich,
/// ohne Vergleich kein Warnsignal — und null Warnsignale sähen sonst aus
/// wie „alles im Normalbereich", eine Aussage, die niemand gemacht hat.
/// Genau daran hing der Fall, der beim Herauslösen am ehesten verloren
/// gegangen wäre: **Nach der OP ruht die Ampel**, `rated` ist leer, obwohl
/// Werte und Mediane vorliegen. Eine Funktion, die nur auf fehlende Zahlen
/// prüft — so rechnete `verlaufsTon` bis #308 —, färbte dort weiter und
/// behauptete eine Bewertung, die ausdrücklich ausgesetzt ist.
///
/// **Die halbe Strecke, nicht ein Viertel oder drei Viertel.** „Nah an der
/// Schwelle" ist eine Setzung; die Mitte ist die einzige Zahl, die sich
/// ohne weitere Begründung verteidigen lässt.
VitalTon vitalTon({
  required RecoveryMetric metrik,
  required RecoveryReading messwerte,
  required RecoveryBaseline baseline,
  required RecoveryEvaluation? bewertung,
}) {
  if (bewertung == null || !bewertung.rated.contains(metrik)) {
    return VitalTon.unbeurteilt;
  }
  if (bewertung.signals.contains(metrik)) return VitalTon.warnsignal;
  return _nahAmSignal(metrik, messwerte, baseline)
      ? VitalTon.nahAmSignal
      : VitalTon.normal;
}

/// Der Abstand zur festen Schlafgrenze, ab dem es die mittlere Stufe wird.
/// Die eine Zahl dieser Datei, die nicht aus `trainings_core` kommt — beim
/// Schlaf gibt es keine Strecke zum Median, zu der sich eine Mitte bilden
/// ließe.
///
/// **Der Schlaf braucht keinen Median:** Die Sechs-Stunden-Grenze steht
/// fest (`docs/SPEC.md` 4.6). Der Vergleichswert, der auf beiden Schirmen
/// daneben steht („Ø 6:40 h"), ist deshalb **nicht** die Grundlage dieser
/// Farbe — eine bekannte Schiefe, die aufzulösen eine eigene Entscheidung
/// wäre.
const double _schlafPuffer = 0.5;

/// Hat der Wert die halbe Strecke zur Schwelle hinter sich?
///
/// `false`, wo sich die Frage nicht stellt: Ohne Wert oder ohne Median
/// gibt es keine Strecke. Beurteilt ist die Metrik dann trotzdem — das hat
/// der Kern entschieden, und ihm wird hier nicht widersprochen.
bool _nahAmSignal(
  RecoveryMetric metrik,
  RecoveryReading messwerte,
  RecoveryBaseline baseline,
) {
  /// Je größer, desto schlechter: Ruhepuls und Atemfrequenz.
  bool ueberMitte(double? wert, double? median, double zuschlag) {
    if (wert == null || median == null) return false;
    return wert >= median + zuschlag / 2;
  }

  switch (metrik) {
    case RecoveryMetric.sleep:
      final wert = messwerte.sleepHours;
      if (wert == null) return false;
      return wert < RecoveryTrafficLight.minimumSleepHours + _schlafPuffer;

    case RecoveryMetric.restingHeartRate:
      return ueberMitte(
        messwerte.restingHeartRate,
        baseline.restingHeartRate,
        RecoveryTrafficLight.restingHeartRateMargin,
      );

    case RecoveryMetric.hrv:
      final wert = messwerte.hrv;
      final median = baseline.hrv;
      if (wert == null || median == null) return false;
      // Kleiner ist schlechter — die einzige Metrik, die nach unten kippt.
      return wert <= median * (1 + RecoveryTrafficLight.hrvFactor) / 2;

    case RecoveryMetric.respiratoryRate:
      return ueberMitte(
        messwerte.respiratoryRate,
        baseline.respiratoryRate,
        RecoveryTrafficLight.respiratoryRateMargin,
      );
  }
}
