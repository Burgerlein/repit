// Der Zustand des Verlaufsschirms je Messwert (#202 Teil C, Schirm #203) —
// **ein** Schirm für vier Werte (Gewicht, Körperfett, fettfreie Masse,
// Ruhepuls); welcher gemeint ist, trägt [MessArt] als Parameter, wie
// `VerlaufArt` bei den Erholungs-Verläufen. Die Oberfläche liegt in einer
// eigenen Datei.
//
// API und Vertrag sind durch
// `app/test/shell/messung_detail_zustand_test.dart` verbindlich vorgegeben
// (siehe dessen Dateikopf) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Der Zustand hält die Rohreihe und verdichtet nicht.** `Zeitdiagramm`
// bekommt in `verlauf_view.dart` ebenfalls die Rohreihe und rechnet
// Verdichtung, Startfenster und Kopfzahl selbst (`Fensterstand.aus` in
// `lib/design/zeitdiagramm_fenster.dart`). Deshalb stehen hier weder
// `punkte` noch `kopfzahl` noch `fenster` — zwei Fassungen derselben Zahl,
// die „exakt übereinstimmen müssen", brechen beim nächsten Umbau
// (Entscheidung vom 02.11.2026). Und deshalb ist der Familienschlüssel
// [MessArt] allein und nicht `(Art, Stufe)`: Ohne eigene Verdichtung gibt
// es nichts, das je Stufe verschieden wäre; die Stufe lebt im Bauteil.
//
// **Keine Nutzertexte.** Der Zustand liefert Zahlen; die Einordnungszeilen,
// der Zielkorridor als Satz und die Fußnote stehen in der View
// (`CLAUDE.md`).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/async_bruecke.dart';
import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'diagramm_zeitraum.dart';
import 'koerper_zustand.dart';
import 'navy_zustand.dart';

/// Die Stufen dieses Schirms: **W M 6M J** (Spec, Teil D).
///
/// Kein `T`: Man wiegt sich nicht stündlich — [DiagrammStufe] kennt deshalb
/// gar kein `T`. Welche davon beim Aufschlagen gewählt ist, entscheidet
/// `startStufe` (die kleinste, also `W`).
///
/// Die Liste steht hier und nicht im Bauteil, wie `verlaufsStufen` nebenan:
/// Welche Stufen ein Schirm anbietet, ist seine Entscheidung; er reicht sie
/// weiter.
const List<DiagrammStufe> messungsStufen = [
  DiagrammStufe.woche,
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// Wie viele der jüngsten Werte die Spanne trägt — „Spanne 7 Tage".
/// Gemeint sind Werte, nicht Kalendertage: Zwischen zwei Wägungen können
/// Tage liegen, und eine Spanne über Lücken hinweg wäre keine.
const int _spanneWerte = 7;

/// Alles, was der Schirm an Zahlen zeigt, einmal gerechnet.
///
/// Werttyp mit `==` und `hashCode`: Er wird von einem Provider gehalten und
/// seine Reihe in ein Diagramm gereicht. Ohne Wertgleichheit wäre jede neu
/// gelesene Reihe ungleich der vorigen und das Diagramm liefe bei jedem
/// Bild neu — das wäre Fehler `03`, wortgleich im neuen Code.
@immutable
class MessungDetailZustand {
  const MessungDetailZustand({
    required this.art,
    required this.reihe,
    required this.aktuell,
    required this.median30,
    required this.spanne7,
    required this.veraenderung6Wochen,
    required this.anteilAmGewicht,
    required this.navyProzent,
  });

  /// Zu welchem der vier Werte dieser Schirm gehört.
  final MessArt art;

  /// Ein Punkt je Messung, ältester zuerst — **roh**, nicht verdichtet.
  /// Lücken bleiben Lücken: Ein Tag ohne Messung fehlt, er steht nicht mit
  /// `0` darin.
  ///
  /// [MeasurementPoint] und nicht `({DateTime tag, double wert})`: So kommt
  /// die Reihe aus `CacheRepository.messReihe` heraus und so geht sie in
  /// [BodyTrend] hinein. Die eine Umsetzung in die Form, die `Zeitdiagramm`
  /// erwartet, macht die View.
  final List<MeasurementPoint> reihe;

  /// Der jüngste Wert der Reihe, nicht ihr größter und nicht ihr Schnitt —
  /// der Fensterschnitt steht in der Kopfzeile des Diagramms und wird dort
  /// gerechnet.
  final double? aktuell;

  /// Der eigene Median ([HealthMedian]) — **nur beim Ruhepuls**. Der
  /// Entwurf zeigt ihn nur in dieser Spalte; ein Feld, das niemand anzeigt,
  /// wäre gerechnete Arbeit ohne Abnehmer.
  ///
  /// `null` unter fünf Werten: Eine Schwelle aus zwei Werten wäre eine
  /// Behauptung.
  final double? median30;

  /// Kleinster und größter der jüngsten [_spanneWerte] Werte; `null` ohne
  /// eine einzige Messung.
  final ({double von, double bis})? spanne7;

  /// Jüngster minus ältester Wert im 6-Wochen-Fenster; `null` unter zwei
  /// Werten darin. Dieselbe Rechnung und dieselbe Kante wie auf dem
  /// Körper-Schirm — sie steht einmal, in `koerper_zustand.dart`.
  final double? veraenderung6Wochen;

  /// Der Anteil der fettfreien Masse am jüngsten Gewicht, als **Anteil**
  /// (0…1), nicht als Prozentzahl — die macht die View. Nur bei
  /// [MessArt.fettfreieMasse], und `null`, solange eines von beidem fehlt:
  /// Ohne Wägung ist der Anteil weder 0 noch 100 %.
  final double? anteilAmGewicht;

  /// Körperfett nach der Navy-Formel aus Taille, Hals und Körpergröße —
  /// `null`, solange eine der drei Zahlen fehlt.
  ///
  /// **Seit #479 ist das Feld gefüllt.** Bis dahin war es „immer `null`,
  /// und das ist kein Fehler": Die Formel braucht Taille und Hals vom
  /// Maßband, und Umfänge gab es im Neubau nicht (#88). Das Feld stand
  /// trotzdem schon da, weil eine Zeile, die später nachgerüstet werden
  /// muss, die schlechtere Lösung wäre (Spec, Teil C) — mit Scheibe 3 ist
  /// aus der Zusage eine Zahl geworden.
  ///
  /// **Die Einordnungszeile liest es nicht**, sondern
  /// [navyStandProvider]: Sie muss „wird gelesen", „nicht lesbar" und
  /// „welche der drei Zahlen fehlt" unterscheiden, und das trägt ein
  /// `double?` nicht. Dieselbe Zahl, über dieselbe Rechnung
  /// ([navyProzentAus]) — hier, weil der Zustand die Zahlen dieses Schirms
  /// vollständig beschreibt und über `==` dafür sorgt, dass ein neu
  /// eingetragenes Maßband ihn ungleich macht.
  final double? navyProzent;

  @override
  bool operator ==(Object other) =>
      other is MessungDetailZustand &&
      other.art == art &&
      // Element für Element, nicht nach Identität: Zwei gleich gelesene
      // Reihen sind dieselbe Kurve.
      listEquals(other.reihe, reihe) &&
      other.aktuell == aktuell &&
      other.median30 == median30 &&
      other.spanne7 == spanne7 &&
      other.veraenderung6Wochen == veraenderung6Wochen &&
      other.anteilAmGewicht == anteilAmGewicht &&
      other.navyProzent == navyProzent;

  @override
  int get hashCode => Object.hash(
    art,
    Object.hashAll(reihe),
    aktuell,
    median30,
    spanne7,
    veraenderung6Wochen,
    anteilAmGewicht,
    navyProzent,
  );
}

/// Rechnet den Detailzustand einer Messart aus ihrer Reihe.
///
/// [reihe] kommt **aufsteigend** herein — so liefert sie
/// `CacheRepository.messReihe` (`ORDER BY tag`). [juengstesGewicht] braucht
/// allein der Anteil der fettfreien Masse; für die übrigen drei Werte darf
/// es `null` sein.
///
/// [tailleCm], [halsCm] und [groesseCm] sind **optional**: Die Reihe dieses
/// Schirms kommt aus dem Cache, das Maßband aus einer anderen Tabelle und
/// die Körpergröße aus den Stammdaten. Wer nur die Zahlen der Waage
/// umrechnen will, lässt sie weg — dann ist [MessungDetailZustand.navyProzent]
/// `null`, so wie es `messung_detail_zustand_test.dart` festhält.
MessungDetailZustand messungDetailAus({
  required MessArt art,
  required List<MeasurementPoint> reihe,
  required double? juengstesGewicht,
  required DateTime jetzt,
  double? tailleCm,
  double? halsCm,
  double? groesseCm,
}) {
  final aktuell = reihe.isEmpty ? null : reihe.last.value;
  final juengste = juengstePunkte(reihe, _spanneWerte);
  final werte = [for (final punkt in juengste) punkt.value];

  return MessungDetailZustand(
    art: art,
    reihe: reihe,
    aktuell: aktuell,
    // [HealthMedian] zählt Werte, keine Kalendertage — die Lücken sind
    // vorher heraus. Die ganze Reihe geht hinein, das Fenster von 30
    // Werten zieht der Kern selbst.
    median30: art == MessArt.ruhepuls
        ? HealthMedian.value([for (final punkt in reihe) punkt.value])
        : null,
    spanne7: werte.isEmpty
        ? null
        : (
            von: werte.reduce((a, b) => math.min(a, b)),
            bis: werte.reduce((a, b) => math.max(a, b)),
          ),
    veraenderung6Wochen: veraenderungImFenster(reihe, jetzt: jetzt),
    anteilAmGewicht: _anteilAmGewicht(art, aktuell, juengstesGewicht),
    navyProzent: navyProzentAus(
      tailleCm: tailleCm,
      halsCm: halsCm,
      groesseCm: groesseCm,
    ),
  );
}

/// „Anteil am Gewicht" steht nur in der Muskel-Spalte — und nur, wenn beide
/// Zahlen dastehen. Ein Anteil ohne Wägung wäre erfunden, und `0` oder
/// `100 %` wären beides Behauptungen (Fehler `01`).
double? _anteilAmGewicht(MessArt art, double? wert, double? gewicht) {
  if (art != MessArt.fettfreieMasse) return null;
  if (wert == null || gewicht == null || gewicht <= 0) return null;
  return wert / gewicht;
}

/// Der Zustand **einer** Messart, gehalten statt bei jedem Zugriff
/// gerechnet (Hausregel 2, Fehler `03`).
///
/// Eine Familie und nicht vier Kopien: Den Schirm gibt es viermal, die
/// Rechnung einmal. Jeder Schlüssel bekommt seinen eigenen Eintrag.
///
/// **Die Reihe kommt über `messReihe` aus dem Cache**, nicht aus
/// [dailyMetricsProvider]: Das Rechenfenster sind 30 Tage, die Jahresstufe
/// des Diagramms braucht mehr — und `messReihe` filtert in SQL statt nach
/// dem Laden (Spec, Teil C; Hausregel 2). Welche Stufe gerade gewählt ist,
/// weiß dieser Zustand nicht und darf er nicht wissen: Sie wechselt im
/// Bauteil, ohne dass neu geladen wird.
///
/// **Der `Messwert`-Zustand kommt trotzdem von den Tageswerten.** Ob
/// überhaupt je ein Lauf stattgefunden hat, ob er leer ausging oder
/// scheiterte, weiß der Cache nicht — eine leere Reihe ist **kein**
/// Leerzustand, sondern ein Lauf, der für diesen einen Wert nichts
/// geliefert hat. Deshalb wird [dailyMetricsProvider] abgewartet und sein
/// Zustand durchgereicht; nebenbei ist das die Stelle, an der der Lauf
/// angestoßen wird, der den Cache füllt.
///
/// Der Schirm besorgt seine Daten damit selbst: Er ist aus jedem Tab
/// erreichbar, niemand darf sich darauf verlassen, dass eine Übersicht
/// vorher geladen hat.
///
/// **Dieser Provider ist der Lade-Teil und liefert den nackten Zustand.**
/// Den `Messwert` daraus macht [messungDetailProvider] weiter unten, über
/// `alsMesswert` — die eine Stelle, an der ein `AsyncValue` übergeht
/// (Hausregel 1). Eine frühere Fassung lieferte hier schon den `Messwert`;
/// die View musste ihn dann als `ref.watch(…).value ?? NochNie` auspacken,
/// und damit stand ein `AsyncValue`-Ausdruck in der Widget-Schicht.
///
/// **Geworfen wird nur, wenn nichts zwischengespeichert ist.** Scheitert
/// der Lauf, während die Reihe im Cache steht, kommt der Cache-Zustand
/// zurück und der Schirm zeigt ihn weiter — Tims Beschwerde ist, dass
/// Werte verschwinden (`CLAUDE.md`). Ein Wurf wäre hier `Fehlgeschlagen`
/// und nähme ihm den sichtbaren Wert weg.
final _messungDetailLadenProvider =
    FutureProvider.family<MessungDetailZustand, MessArt>((ref, art) async {
      // Alle Abhängigkeiten vor dem ersten `await`: Was danach käme, wäre
      // je nach Reihenfolge der Läufe mal beobachtet und mal nicht.
      final cacheRepo = ref.watch(cacheRepositoryProvider);
      final fenster = ref.watch(dataWindowProvider);
      final quelle = ref.watch(healthProvider);
      final heute = ref.watch(heutigerTagProvider);
      final jetzt = ref.watch(clockProvider)();
      // **Nur beim Körperfett**: Die Navy-Zeile gibt es nur dort
      // (`messung-detail.js`), und ein `watch` in den übrigen drei Schirmen
      // ließe sie bei jedem neu eingetragenen Maßband neu laden.
      final navy = art == MessArt.koerperfett
          ? navyWerte(ref.watch(navyStandProvider))
          : null;
      final tageswerte = await ref.watch(dailyMetricsProvider.future);

      // Dieselbe untere Kante wie beim Lauf, der den Cache gefüllt hat:
      // so weit zurück, wie die Quelle überhaupt etwas hergibt, verkürzt
      // durch den eingestellten Betrachtungszeitraum. Eine eigene Zahl
      // („ein Jahr") wäre eine zweite Festlegung neben dieser.
      final von = BerlinCalendar.dayKey(
        fenster.queryStart(floor: quelle.earliestPermittedDate),
      );
      // Bis heute, nicht offen: Ein Tagesschlüssel aus der Zukunft gehört
      // in kein Diagramm.
      final bis = BerlinCalendar.dayKey(heute);

      // **Noch nie gelaufen heißt: noch kein Ergebnis.** Eine Future, die
      // hier aufgelöst würde, hieße „fertig" — und weil der Cache dann
      // leer ist, stünde auf dem Schirm „keine Waagenwerte", während in
      // Wahrheit noch gar nichts gefragt wurde. Das ist Fehler `01`.
      // Bleibt sie offen, meldet `alsMesswert` `NochNie`, also den
      // Platzhalter. Ändert sich der Zustand der Tageswerte, läuft dieser
      // Provider ohnehin neu — `dailyMetricsProvider` ist beobachtet.
      if (tageswerte is NochNie<List<DailyMetrics>>) {
        return Completer<MessungDetailZustand>().future;
      }

      // Der Cache wird in jedem Fall gelesen — auch nach einem gescheiterten
      // Lauf. Was dort steht, ist das, was der Schirm weiter zeigen darf.
      final zustand = await _ausCache(
        cacheRepo,
        art: art,
        von: von,
        bis: bis,
        jetzt: jetzt,
        navy: navy,
      );

      // Gescheitert **und** nichts da: Das ist `Fehlgeschlagen`, und nur
      // ein Wurf bringt `alsMesswert` auf diesen Pfad. „Lauf gescheitert"
      // ist nicht „Lauf fertig, nichts gefunden" — ein gescheiterter Lauf,
      // der als `LeerNachLauf` erschiene, behauptete eine Auskunft, die der
      // Lauf nie gegeben hat.
      if (tageswerte is Fehlgeschlagen<List<DailyMetrics>> &&
          zustand.reihe.isEmpty) {
        throw tageswerte.fehler;
      }

      return zustand;
    });

/// Der **öffentliche** Provider, und der einzige, den die View liest: Sie
/// sieht `Messwert<MessungDetailZustand>` und nie ein `AsyncValue`.
///
/// **Leer heißt hier: die Reihe trägt keinen einzigen Punkt.** Dann gibt es
/// weder Kurve noch Einordnung — `aktuell`, `median30`, `spanne7`,
/// `veraenderung6Wochen` und `anteilAmGewicht` hängen alle an ihr. Das
/// weicht von `verlauf_zustand.dart` ab, wo eine leere Reihe *kein*
/// Leerzustand ist: Dort trägt **ein** Zustand alle vier Werte, hier ist
/// der Provider je Messart gefächert. Sein Lauf ist die Reihe dieses einen
/// Werts; ist sie leer, hat er für diesen Schirm tatsächlich nichts
/// gefunden.
///
/// **`navyProzent` löst dabei nichts aus.** Es hängt am Maßband und nicht
/// am Lauf der Waage: Ein Schirm, der eine Navy-Zahl hätte und deswegen
/// nicht mehr „keine Waagenwerte" sagte, verschwiege, dass die Waage nichts
/// geliefert hat. Umgekehrt nimmt eine fehlende Navy-Zahl dem Schirm
/// nichts — die Zeile daneben sagt selbst, warum sie leer ist.
final messungDetailProvider =
    Provider.family<Messwert<MessungDetailZustand>, MessArt>((ref, art) {
      final jetzt = ref.watch(clockProvider)();
      final geladen = ref.watch(_messungDetailLadenProvider(art));
      final zustand = geladen.value;

      // Was im Cache steht, bleibt bei einem gescheiterten Nachlauf stehen.
      // Eine leere Reihe ist dabei kein Zwischenspeicher: Sie zeigte nichts
      // und verdeckte nur den Grund.
      final cache = (zustand != null && zustand.reihe.isNotEmpty)
          ? (wert: zustand, stand: jetzt)
          : null;

      return alsMesswert<MessungDetailZustand>(
        geladen,
        cache: cache,
        jetzt: jetzt,
        istLeer: zustand == null || zustand.reihe.isEmpty,
      );
    });

Future<MessungDetailZustand> _ausCache(
  CacheRepository cacheRepo, {
  required MessArt art,
  required String von,
  required String bis,
  required DateTime jetzt,
  NavyGelesen? navy,
}) async {
  final reihe = await cacheRepo.messReihe(art, von: von, bis: bis);
  // Die Gewichtsreihe wird nur geholt, wo sie gebraucht wird: Eine zweite
  // Abfrage je Schirmaufruf, die drei von vier Werten nichts nützt, ist
  // Arbeit ohne Abnehmer.
  final gewicht = art == MessArt.fettfreieMasse
      ? await cacheRepo.messReihe(MessArt.gewicht, von: von, bis: bis)
      : const <MeasurementPoint>[];

  return messungDetailAus(
    art: art,
    reihe: reihe,
    juengstesGewicht: gewicht.isEmpty ? null : gewicht.last.value,
    jetzt: jetzt,
    tailleCm: navy?.tailleCm,
    halsCm: navy?.halsCm,
    groesseCm: navy?.groesseCm,
  );
}
