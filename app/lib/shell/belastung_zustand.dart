// Der Zustand des Belastungs-Schirms (#94) — alles, was der Schirm zeigt,
// einmal gerechnet und ohne Widget prüfbar. Die Oberfläche liegt in
// `belastung_view.dart`.
//
// API und Vertrag sind durch `app/test/shell/belastung_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung des Schnitts) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Der Schirm leitet aus `erholungProvider` ab, statt Health ein zweites
// Mal zu fragen.** Der Einordnungssatz zählt die Warnsignale, und die
// hängen an Schlaf, Ruhepuls, HRV **und** Atemfrequenz — also an beiden
// Health-Hälften. Ein zweiter Ladeweg wäre eine zweite Stelle, an der
// `docs/todo/01` entstehen kann. Der Schirm lädt trotzdem selbst: Wer
// `erholungProvider` liest, stößt `dailyMetricsProvider` und `sleepProvider`
// an — niemand muss vorher auf Erholung gewesen sein.
//
// **Die Rechnungen liegen im Kern.** Wochengrenzen und Wochensumme kommen
// aus `TrainingLoad`, die Tagesgrenzen aus `BerlinCalendar`, die
// Warnsignale aus `RecoveryTrafficLight` (über `RecoverySnapshot
// .evaluation`). Hier wird zusammengesetzt, nicht nachgerechnet.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ziele.dart';
import 'diagramm_zeitraum.dart';
import 'erholung_zustand.dart';

/// Die Stufen dieses Schirms: **W M 6M, kein J.**
///
/// Der Store hält dreißig Tage vor (`rechenfensterProvider`, `windowDays`
/// in `RecoverySnapshot.make`). Ein Jahresfenster wäre damit leer — wer
/// „überall dieselben Stufen" vereinheitlicht, baut genau das ein
/// (`LoadDetailView.swift:66–68`).
const List<DiagrammStufe> belastungsStufen = [
  DiagrammStufe.woche,
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
];

/// Was der Belastungs-Schirm aus Apple Health ableitet, einmal gerechnet.
///
/// **Alles sind Felder, keine berechneten Eigenschaften.** Eine berechnete
/// Eigenschaft rechnet je Bild; das war `docs/todo/03`. Hier wird einmal
/// gerechnet und gehalten.
///
/// Kein `==`/`hashCode`: `RecoverySnapshot`, aus dem diese Werte stammen,
/// hat laut eigenem Vertrag keine Wertgleichheit, und eine hier wäre eine
/// Zusage, die der Code darunter nicht einlöst. Gehalten wird der Zustand
/// trotzdem — dafür sorgt [belastungProvider], nicht ein `==`.
@immutable
class BelastungDaten {
  const BelastungDaten({
    required this.wochenminuten,
    required this.wochenziel,
    required this.anteil,
    required this.vorwochenminuten,
    required this.veraenderung,
    required this.tagesminuten,
    required this.signale,
  });

  /// Die Trainingsminuten der laufenden Woche (Montag bis Sonntag).
  ///
  /// `null` heißt „diese Woche ist nichts aufgezeichnet", `0` heißt „diese
  /// Woche nichts trainiert". Eine 0 für den ersten Fall behauptete, der
  /// Nutzer hätte sich nicht bewegt — das weiß niemand, wenn nichts
  /// aufgezeichnet wurde.
  final double? wochenminuten;

  /// Das Wochenziel aus [Ziele].
  ///
  /// **Als Feld in den Daten, nicht nur in `ziele`:** Damit kann der Schirm
  /// die Zahl nicht aus einer Konstante nehmen. `Ziele.vorbelegung` ist die
  /// einzige Stelle im Quelltext, die „210" kennt.
  final double wochenziel;

  /// [wochenminuten] geteilt durch [wochenziel], 1.0 ist „Ziel erreicht".
  ///
  /// `null` ohne Aufzeichnung **und** bei einem Ziel von 0: Durch null wird
  /// nirgends geteilt, und „unendlich Prozent erreicht" ist keine Auskunft.
  final double? anteil;

  /// Die Summe der Vorwoche (Montag bis Sonntag davor), `null` nach
  /// derselben Regel wie [wochenminuten]. Liegt die Vorwoche ganz außerhalb
  /// des Rechenfensters, gibt es sie nicht.
  final double? vorwochenminuten;

  /// Der Vergleich beider Summen in Prozent, negativ bei einem Rückgang.
  ///
  /// `null`, sobald eine der beiden Summen fehlt — und auch bei einer
  /// Vorwoche von genau 0 Minuten: „unendlich Prozent mehr als nichts" ist
  /// keine Aussage.
  final double? veraenderung;

  /// Ein Punkt je **gemessenem** Tag im Rechenfenster, aufsteigend, auf
  /// Berliner Tagesgrenzen.
  ///
  /// Lücken bleiben Lücken: Ein Tag ohne `exerciseMinutes` fehlt, er steht
  /// nicht mit 0 darin. Als Balken der Höhe 0 gezeichnet wäre er eine
  /// Behauptung.
  final List<({DateTime tag, double wert})> tagesminuten;

  /// Wie viele Warnsignale die Erholungsampel heute zählt (0 bis 4).
  ///
  /// Aus `RecoveryTrafficLight` über beide Health-Hälften — der
  /// Einordnungssatz dieses Schirms hängt an Schlaf, Ruhepuls, HRV und
  /// Atemfrequenz, nicht nur an den Tageswerten.
  final int signale;
}

/// Alles, was der Schirm zeigt.
///
/// `Messwert` liegt nur um die Health-Hälfte: [Ziele] sind Tims eigene
/// Daten, für sie gibt es keinen Lauf, der leer ausgehen kann
/// (`CLAUDE.md`). Deshalb steht das Wochenziel auch dann fest, wenn Apple
/// Health noch nichts geliefert hat.
@immutable
class BelastungZustand {
  const BelastungZustand({required this.daten, required this.ziele});

  final Messwert<BelastungDaten> daten;

  /// Tims eigene Ziele — nie ein Leerzustand, nie eine Konstante im
  /// Quelltext des Schirms.
  final Ziele ziele;
}

/// Leitet den Belastungs-Zustand aus dem Erholungs-Zustand ab.
///
/// Die vier `Messwert`-Zustände werden unverändert durchgereicht: Was für
/// die Erholung „noch nie gesehen", „leer nach Lauf" oder „gescheitert"
/// ist, ist es hier auch — und ein gescheiterter Nachlauf, der eine Hälfte
/// stehen lässt, nimmt auch hier keinen sichtbaren Wert weg.
BelastungZustand belastungZustandAus({required ErholungZustand erholung}) {
  final ziele = erholung.ziele;

  // Der `switch` über den sealed-Typ ist vollständig: Käme ein fünfter
  // Zustand, zeigte der Analyzer genau hier hin.
  final Messwert<BelastungDaten> daten = switch (erholung.daten) {
    NochNie<ErholungDaten>() => const NochNie<BelastungDaten>(),
    LeerNachLauf<ErholungDaten>(:final gelaufen) =>
      LeerNachLauf<BelastungDaten>(gelaufen: gelaufen),
    Fehlgeschlagen<ErholungDaten>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<BelastungDaten>(fehler: fehler, gelaufen: gelaufen),
    Bekannt<ErholungDaten>(:final wert, :final stand, :final laeuft) =>
      Bekannt<BelastungDaten>(
        _daten(wert, ziele),
        stand: stand,
        laeuft: laeuft,
      ),
  };

  return BelastungZustand(daten: daten, ziele: ziele);
}

BelastungDaten _daten(ErholungDaten erholung, Ziele ziele) {
  final schnappschuss = erholung.schnappschuss;
  final ziel = ziele.wochenzielTrainingsminuten.toDouble();
  final wochenminuten = erholung.wochenminuten;

  // Die Vorwoche über denselben Kernaufruf wie die laufende Woche, nur mit
  // einem Tag aus der Woche davor als Anker. Eine eigene Grenzrechnung wäre
  // die Doppelung, die `TrainingLoad.weekBounds` gerade abnimmt.
  final vorwochenminuten = _wochensumme(
    tage: schnappschuss.days,
    inDerWoche: BerlinCalendar.addDays(
      schnappschuss.today,
      -DateTime.daysPerWeek,
    ),
  );

  return BelastungDaten(
    wochenminuten: wochenminuten,
    wochenziel: ziel,
    anteil: wochenminuten == null || ziel <= 0 ? null : wochenminuten / ziel,
    vorwochenminuten: vorwochenminuten,
    veraenderung:
        wochenminuten == null ||
            vorwochenminuten == null ||
            vorwochenminuten == 0
        ? null
        : (wochenminuten - vorwochenminuten) / vorwochenminuten * 100,
    tagesminuten: [
      for (final tag in schnappschuss.days)
        if (tag.exerciseMinutes case final minuten?)
          (tag: tag.date, wert: minuten),
    ],
    signale: schnappschuss.evaluation.signals.length,
  );
}

/// Die Trainingsminuten der Woche, in der [inDerWoche] liegt — `null`,
/// wenn in dieser Woche kein einziger Tag `exerciseMinutes` trägt.
///
/// `TrainingLoad.weekMinutes` liefert für „nichts aufgezeichnet" und „nichts
/// trainiert" dasselbe `0.0`; die Unterscheidung braucht die Tagesliste.
/// Dieselbe Trennung wie in `erholung_zustand.dart` für die laufende Woche,
/// und aus demselben Grund.
double? _wochensumme({
  required List<RecoveryDay> tage,
  required DateTime inDerWoche,
}) {
  final (von, bis) = TrainingLoad.weekBounds(containing: inDerWoche);
  final gemessen = tage.any(
    (tag) =>
        !tag.date.isBefore(von) &&
        tag.date.isBefore(bis) &&
        tag.exerciseMinutes != null,
  );
  if (!gemessen) return null;
  return TrainingLoad.weekMinutes(days: tage, containing: inDerWoche);
}

/// Der Zustand des Belastungs-Schirms, **gehalten** statt bei jedem Zugriff
/// gerechnet (Hausregel 2, `docs/todo/03`).
///
/// Ein abgeleiteter Provider rechnet neu, wenn sich seine Abhängigkeit
/// ändert, und sonst nie. `AsyncValue` taucht hier nicht auf — es endet
/// bereits in [erholungProvider].
final belastungProvider = Provider<BelastungZustand>(
  (ref) => belastungZustandAus(erholung: ref.watch(erholungProvider)),
);
