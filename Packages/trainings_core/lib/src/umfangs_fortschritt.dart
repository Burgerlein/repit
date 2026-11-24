/// Richtung, Verlauf und Kennzahlen je Maß für den Umfänge-Schirm (#88,
/// #475).
///
/// Verbindlich festgelegt durch
/// `Packages/trainings_core/test/umfangs_fortschritt_test.dart` (siehe dessen
/// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// **Jede Funktion sammelt zuerst die Werte dieses einen Maßes.** Ein Tag, an
/// dem nur die Taille nachgemessen wurde, ist für den Oberarm keine Messung —
/// sonst verglichen die Zeilen untereinander verschiedene Zeiträume, ohne
/// dass man es sähe. Eine Lücke wird nicht gefüllt, schon gar nicht mit `0`
/// (`CLAUDE.md`: „`0` ist keine Antwort auf ‚kein Wert'").
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/CircumferenceProgress.swift`.
library;

import 'berlin_calendar.dart';
import 'umfang.dart';
import 'umfangs_merge.dart';

/// Wohin sich ein Maß bewegt hat. [unveraendert] heißt „innerhalb der
/// Totzone", nicht „exakt gleich".
enum UmfangsRichtung { hoch, runter, unveraendert }

/// Was sich seit der vorigen Messung dieses Maßes getan hat.
///
/// Werttyp mit [==] und [hashCode] über alle drei Felder, weil er
/// Abhängigkeit eines Providers ist (`CLAUDE.md`, Fehler `03`).
class UmfangsVeraenderung {
  UmfangsVeraenderung({
    required this.delta,
    required this.richtung,
    required this.istFortschritt,
  });

  /// Vorzeichenbehaftet. Den Betrag für „↑ 0,4" bildet die Ansicht.
  final double delta;

  /// Steht neben [delta], damit die Ansicht den Pfeil nicht aus dem
  /// Vorzeichen ableiten muss — die Totzone sieht man dem Vorzeichen nicht
  /// an.
  final UmfangsRichtung richtung;

  /// Ob die Bewegung in die Richtung geht, die das Maß anstrebt. Die Regel
  /// steckt als [Umfang.wenigerIstBesser] im Maß und nicht in der Farbe der
  /// Ansicht.
  final bool istFortschritt;

  @override
  bool operator ==(Object other) =>
      other is UmfangsVeraenderung &&
      other.delta == delta &&
      other.richtung == richtung &&
      other.istFortschritt == istFortschritt;

  @override
  int get hashCode => Object.hash(delta, richtung, istFortschritt);

  @override
  String toString() =>
      'UmfangsVeraenderung(delta: $delta, richtung: $richtung, '
      'istFortschritt: $istFortschritt)';
}

/// Wer von beiden Seiten größer ist. [gleich] heißt „innerhalb der
/// Totzone", nicht „exakt gleich".
enum SeitenVergleich { diesesGroesser, partnerGroesser, gleich }

/// Wie weit dieses Maß von seinem Gegenstück entfernt liegt (#493).
///
/// Werttyp mit [==] und [hashCode] über beide Felder, weil er Abhängigkeit
/// eines Providers ist (`CLAUDE.md`, Fehler `03`).
class UmfangsSeitendifferenz {
  UmfangsSeitendifferenz({required this.delta, required this.vergleich});

  /// Dieses Maß minus Partner, vorzeichenbehaftet — der Schirm zeigt immer
  /// ein Maß, die Richtung ist also eindeutig. Den Betrag für „0,4 cm"
  /// bildet die Ansicht. Trägt **immer** die echte Differenz, auch
  /// innerhalb der Totzone — die entscheidet nur über [vergleich].
  final double delta;

  /// Steht neben [delta], damit die Ansicht „beide Seiten gleich" nicht
  /// aus dem Vorzeichen ableiten muss — die Totzone sieht man dem
  /// Vorzeichen nicht an (derselbe Grund wie bei [UmfangsVeraenderung]).
  final SeitenVergleich vergleich;

  @override
  bool operator ==(Object other) =>
      other is UmfangsSeitendifferenz &&
      other.delta == delta &&
      other.vergleich == vergleich;

  @override
  int get hashCode => Object.hash(delta, vergleich);

  @override
  String toString() =>
      'UmfangsSeitendifferenz(delta: $delta, vergleich: $vergleich)';
}

/// Ein Messpunkt eines einzelnen Maßes: der Tag und der Wert an ihm.
class _Punkt {
  const _Punkt(this.zeitpunkt, this.wert);

  final DateTime zeitpunkt;
  final double wert;
}

abstract final class UmfangsFortschritt {
  /// Maßband, Zugspannung und Messstelle streuen zu stark, als dass ein
  /// Zehntel eine Aussage wäre. Die Grenze selbst gehört zur Bewegung: unter
  /// 0,2 ein Strich, ab 0,2 ein Pfeil.
  static const double totzone = 0.2;

  /// Ein mittlerer Monat. Auf den Tag genau zu rechnen hieße, dem Maßband
  /// eine Genauigkeit zu unterstellen, die es nicht hat.
  static const double _tageProMonat = 30.44;

  /// Richtung und Betrag gegen die vorige Messung **dieses Maßes**, oder
  /// `null`, solange es keinen zweiten Punkt gibt.
  ///
  /// „Erste Messung" ist kein „±0,0": Die Veränderung gibt es, ihr fehlt nur
  /// der zweite Punkt, und das sagt der Schirm auch so.
  static UmfangsVeraenderung? veraenderung(
    Umfang mass,
    List<Umfangsmessung> messungen,
  ) {
    final reihe = _reihe(mass, messungen);
    if (reihe.length < 2) return null;

    final delta = reihe[reihe.length - 1].wert - reihe[reihe.length - 2].wert;

    // Ungerundet vergleichen: 0,19 würde sonst zu 0,2 und bekäme einen Pfeil,
    // den die Messgenauigkeit nicht trägt.
    //
    // Das Epsilon ist kein Schönheitsfehler, sondern nötig: Umfänge haben
    // eine Nachkommastelle, und 33,8 − 33,6 ergibt in Double
    // 0,19999999999999574, 40,2 − 40,0 dagegen 0,20000000000000284. Ohne die
    // Toleranz bekäme dieselbe Differenz von zwei Zehnteln einmal einen Pfeil
    // und einmal einen Strich, je nachdem, welche Zahlen sie bilden.
    final richtung = delta.abs() < totzone - 1e-9
        ? UmfangsRichtung.unveraendert
        : (delta > 0 ? UmfangsRichtung.hoch : UmfangsRichtung.runter);

    // Was im Rauschen liegt, ist kein Erfolg — auch nicht bei der Taille.
    final istFortschritt = switch (richtung) {
      UmfangsRichtung.unveraendert => false,
      UmfangsRichtung.hoch => !mass.wenigerIstBesser,
      UmfangsRichtung.runter => mass.wenigerIstBesser,
    };

    return UmfangsVeraenderung(
      delta: delta,
      richtung: richtung,
      istFortschritt: istFortschritt,
    );
  }

  /// Wie weit dieses Maß von seinem Gegenstück ([Umfang.partner]) entfernt
  /// liegt — „die Zahl, die man sonst im Kopf ausrechnet" (#493).
  ///
  /// `null` heißt „es gibt keine Seitendifferenz": Das Maß hat keinen
  /// Partner, oder einer der beiden Seiten fehlt jeder Wert. Beides sagt
  /// der Schirm verschieden, unterscheiden kann er es an [Umfang.partner].
  ///
  /// Verglichen werden die **jüngsten** Werte beider Seiten, je Seite
  /// unabhängig: Wer die linke Seite zuletzt vor drei Wochen gemessen hat,
  /// vergleicht den heutigen rechten Wert mit dem von vor drei Wochen —
  /// nicht mit nichts. Sortiert wird hier selbst ([_reihe]); die Ablage
  /// liest absteigend, und wer blind das letzte Element nähme, verglich
  /// alte Werte.
  static UmfangsSeitendifferenz? seitendifferenz(
    Umfang mass,
    List<Umfangsmessung> messungen,
  ) {
    final partner = mass.partner;
    if (partner == null) return null;

    final eigene = _reihe(mass, messungen);
    final gegenseite = _reihe(partner, messungen);
    if (eigene.isEmpty || gegenseite.isEmpty) return null;

    // Dieses Maß minus Partner: Der Schirm zeigt immer ein Maß, die
    // Richtung ist also eindeutig (#493).
    final delta = eigene.last.wert - gegenseite.last.wert;

    // Dieselbe Totzone samt Epsilon wie bei [veraenderung] — die Begründung
    // steht dort: 33,8 − 33,6 ergibt in Double 0,19999999999999574, 40,2 −
    // 40,0 dagegen 0,20000000000000284; ohne Toleranz hießen dieselben zwei
    // Zehntel einmal „gleich" und einmal „größer".
    final vergleich = delta.abs() < totzone - 1e-9
        ? SeitenVergleich.gleich
        : (delta > 0
              ? SeitenVergleich.diesesGroesser
              : SeitenVergleich.partnerGroesser);

    return UmfangsSeitendifferenz(delta: delta, vergleich: vergleich);
  }

  /// Veränderung gegenüber der ersten Messung dieses Maßes; `null`, solange
  /// die erste die aktuelle ist.
  ///
  /// Ohne Totzone: Die Spalte „seit Start" nennt die Zahl, der Strich gilt
  /// dem Pfeil daneben.
  static double? seitStart(Umfang mass, List<Umfangsmessung> messungen) {
    final reihe = _reihe(mass, messungen);
    if (reihe.length < 2) return null;
    return reihe.last.wert - reihe.first.wert;
  }

  /// Zentimeter pro Monat zwischen erster und letzter Messung dieses Maßes.
  static double? proMonat(Umfang mass, List<Umfangsmessung> messungen) {
    final reihe = _reihe(mass, messungen);
    if (reihe.length < 2) return null;

    // Kalendertage, keine 86400 Sekunden: Zwischen dem 20.03. und dem
    // 03.04.2026 liegt die Umstellung auf Sommerzeit, die beiden Berliner
    // Tagesbeginne sind 13 Tage und 23 Stunden auseinander — `inDays`
    // schnitte ab und teilte durch 13.
    final tage = BerlinCalendar.daysBetween(
      from: BerlinCalendar.dayKey(reihe.first.zeitpunkt),
      to: BerlinCalendar.dayKey(reihe.last.zeitpunkt),
    );
    // Kein Nenner null: Zwei Messungen desselben Tages ergäben sonst
    // „inf cm pro Monat".
    if (tage == null || tage <= 0) return null;

    return (reihe.last.wert - reihe.first.wert) / tage * _tageProMonat;
  }

  /// Kleinster und größter Wert über **alle** Messungen dieses Maßes — nicht
  /// nur Anfang und Ende. Eine einzelne Messung ist ihr eigener kleinster und
  /// größter Wert.
  static (double niedrigster, double hoechster)? spanne(
    Umfang mass,
    List<Umfangsmessung> messungen,
  ) {
    final reihe = _reihe(mass, messungen);
    if (reihe.isEmpty) return null;

    var niedrigster = reihe.first.wert;
    var hoechster = reihe.first.wert;
    for (final punkt in reihe.skip(1)) {
      if (punkt.wert < niedrigster) niedrigster = punkt.wert;
      if (punkt.wert > hoechster) hoechster = punkt.wert;
    }
    return (niedrigster, hoechster);
  }

  /// Wann die nächste Messung sinnvoll ist: jüngste Messung plus vierzehn
  /// Kalendertage, auf den Berliner Tagesbeginn.
  ///
  /// Es zählt jede Messung, gleich welches Maß sie trägt — gemessen wird der
  /// ganze Körper auf einmal. Tage und keine 86400 Sekunden: In der Nacht zum
  /// 25.10.2026 endet die Sommerzeit, vierzehnmal 86400 Sekunden landeten
  /// deshalb am 26.10. um 23 Uhr.
  static DateTime? naechsteFaellig(List<Umfangsmessung> messungen) {
    if (messungen.isEmpty) return null;

    var juengste = messungen.first.zeitpunkt;
    for (final messung in messungen.skip(1)) {
      if (messung.zeitpunkt.isAfter(juengste)) juengste = messung.zeitpunkt;
    }
    return BerlinCalendar.addDays(juengste, 14);
  }

  /// Die Werte dieses Maßes, aufsteigend nach Zeitpunkt. Messungen ohne das
  /// Maß fallen weg, ihre Lücke wird nicht gefüllt.
  ///
  /// **Hier wird selbst sortiert.** Die Ablage liest absteigend nach Tag; wer
  /// blind die letzten beiden Elemente nähme, bekäme das Vorzeichen falsch
  /// herum.
  static List<_Punkt> _reihe(Umfang mass, List<Umfangsmessung> messungen) {
    final sortiert = [...messungen]
      ..sort((eine, andere) => eine.zeitpunkt.compareTo(andere.zeitpunkt));
    return [
      for (final messung in sortiert)
        if (messung.werte[mass] case final wert?)
          _Punkt(messung.zeitpunkt, wert),
    ];
  }
}
