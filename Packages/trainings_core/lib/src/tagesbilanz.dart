import 'naehrwerte.dart';

/// Wie ein Tag zu seinem Kalorienziel steht.
///
/// Hier stehen die Fälle, **keine Sätze**: „Im Ziel ✓" und „noch X kcal
/// offen" gehören in die View (`CLAUDE.md`). „Noch offen" ist dabei kein
/// eigener Zustand, sondern das umgekehrte Vorzeichen von
/// [Tagesbilanz.abweichungKcal] am laufenden Tag — ob heute ist, weiß der
/// Kern nicht und soll es nicht wissen.
enum Zielstatus {
  /// Kein Kalorienziel berechenbar. Ohne Ziel ist keine Einordnung
  /// möglich; der Schirm führt dann auf die Einstellungen. Dieser Fall
  /// gewinnt auch dann, wenn zugleich nichts erfasst ist.
  keinZiel,

  /// Nichts erfasst. Das ist **nicht** „0 gegessen" und damit auch nicht
  /// „zu wenig" — ein Ring, der daraus „1.200 kcal zu wenig" macht, ist
  /// Fehler `01` in neuer Verpackung.
  keineWerte,

  /// Unter dem Zielbereich.
  zuWenig,

  /// Im Zielbereich, Ränder eingeschlossen.
  imZiel,

  /// Über dem Zielbereich.
  ueberZiel,
}

/// Der Zielbereich reicht um diesen Anteil nach unten und oben
/// (`docs/SPEC.md` 4.8: „Zielbereich ±10 %").
const double _zielbereichAnteil = 0.1;

/// Die Tagesbilanz: gegessen, verbraucht, Ziel — und was daraus folgt.
///
/// Jede Zahl ist `double?`, und `null` heißt durchgehend „liegt nicht
/// vor", nie `0` (`CLAUDE.md`, Fehler `01`). Werttyp mit [==] und
/// [hashCode], weil er Abhängigkeit eines Providers ist (Fehler `03`).
class Tagesbilanz {
  const Tagesbilanz({
    required this.gegessenKcal,
    required this.verbrauchKcal,
    required this.differenzKcal,
    required this.zielKcal,
    required this.abweichungKcal,
    required this.untergrenzeKcal,
    required this.obergrenzeKcal,
    required this.status,
  });

  /// Die erfassten Kalorien des Tages.
  final double? gegessenKcal;

  /// Der Verbrauch des Tages.
  final double? verbrauchKcal;

  /// `gegessen − verbraucht`. Positiv ist Überschuss, negativ Defizit.
  /// `null`, sobald eine der beiden Zahlen fehlt.
  final double? differenzKcal;

  final double? zielKcal;

  /// `gegessen − Ziel`. Positiv heißt „über Ziel". Die View macht daraus
  /// am laufenden Tag „noch X kcal offen", indem sie das Vorzeichen dreht.
  final double? abweichungKcal;

  /// Ziel · 0,9. Steht auch dann, wenn nichts erfasst ist — der Balken
  /// zeichnet seinen Bereich, bevor der erste Eintrag da ist.
  final double? untergrenzeKcal;

  /// Ziel · 1,1, siehe [untergrenzeKcal].
  final double? obergrenzeKcal;

  final Zielstatus status;

  @override
  bool operator ==(Object other) =>
      other is Tagesbilanz &&
      other.gegessenKcal == gegessenKcal &&
      other.verbrauchKcal == verbrauchKcal &&
      other.differenzKcal == differenzKcal &&
      other.zielKcal == zielKcal &&
      other.abweichungKcal == abweichungKcal &&
      other.untergrenzeKcal == untergrenzeKcal &&
      other.obergrenzeKcal == obergrenzeKcal &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
    gegessenKcal,
    verbrauchKcal,
    differenzKcal,
    zielKcal,
    abweichungKcal,
    untergrenzeKcal,
    obergrenzeKcal,
    status,
  );

  @override
  String toString() =>
      'Tagesbilanz(gegessenKcal: $gegessenKcal, '
      'verbrauchKcal: $verbrauchKcal, differenzKcal: $differenzKcal, '
      'zielKcal: $zielKcal, abweichungKcal: $abweichungKcal, '
      'untergrenzeKcal: $untergrenzeKcal, obergrenzeKcal: $obergrenzeKcal, '
      'status: $status)';
}

/// Die Bilanz eines Tages aus seinen Summen.
///
/// [gegessen] ist die Tagessumme als [Naehrwerte] und nicht eine blanke
/// Zahl, damit „nichts erfasst" dieselbe Gestalt hat wie überall sonst:
/// `kcal == null`. Eine erfasste `0` ist dagegen ein Wert und führt zu
/// [Zielstatus.zuWenig].
Tagesbilanz bilanz({
  required Naehrwerte gegessen,
  double? verbrauchKcal,
  double? zielKcal,
}) {
  final gegessenKcal = gegessen.kcal;
  final untergrenze = zielKcal == null
      ? null
      : zielKcal * (1 - _zielbereichAnteil);
  final obergrenze = zielKcal == null
      ? null
      : zielKcal * (1 + _zielbereichAnteil);

  return Tagesbilanz(
    gegessenKcal: gegessenKcal,
    verbrauchKcal: verbrauchKcal,
    differenzKcal: gegessenKcal == null || verbrauchKcal == null
        ? null
        : gegessenKcal - verbrauchKcal,
    zielKcal: zielKcal,
    abweichungKcal: gegessenKcal == null || zielKcal == null
        ? null
        : gegessenKcal - zielKcal,
    untergrenzeKcal: untergrenze,
    obergrenzeKcal: obergrenze,
    status: _status(gegessenKcal, zielKcal),
  );
}

Zielstatus _status(double? gegessenKcal, double? zielKcal) {
  if (zielKcal == null) return Zielstatus.keinZiel;
  if (gegessenKcal == null) return Zielstatus.keineWerte;
  if (gegessenKcal < zielKcal * (1 - _zielbereichAnteil)) {
    return Zielstatus.zuWenig;
  }
  if (gegessenKcal > zielKcal * (1 + _zielbereichAnteil)) {
    return Zielstatus.ueberZiel;
  }
  return Zielstatus.imZiel;
}

/// Die Zeile „Letzte 7 Tage: Ziel an X von Y Tagen getroffen, Ø ±Z kcal"
/// (`docs/SPEC.md` 4.8), ohne die Sätze.
///
/// Werttyp mit [==] und [hashCode] (`CLAUDE.md`, Fehler `03`).
class SiebenTage {
  const SiebenTage({
    required this.getroffen,
    required this.tageMitWerten,
    required this.mittlereAbweichungKcal,
  });

  /// `X` — beurteilbare Tage, an denen das Gegessene im Zielbereich lag.
  final int getroffen;

  /// `Y` — die Zahl der **beurteilbaren** Tage, nicht die Länge der
  /// übergebenen Liste. Ein Tag ohne Erfassung oder ohne Ziel zählt weder
  /// hier noch bei [getroffen]; sonst sänke die Quote, weil ein Tag fehlt,
  /// statt weil ein Ziel verfehlt wurde.
  final int tageMitWerten;

  /// `Z` — die mittlere Abweichung **mit Vorzeichen**, nicht der mittlere
  /// Betrag. So sagt die Zeile, ob systematisch darüber oder darunter
  /// gegessen wurde, und das ist die Hälfte, nach der gehandelt wird; die
  /// View setzt das Zeichen. `null`, wenn es keinen beurteilbaren Tag gibt
  /// — ein Mittel über nichts ist keine 0.
  final double? mittlereAbweichungKcal;

  @override
  bool operator ==(Object other) =>
      other is SiebenTage &&
      other.getroffen == getroffen &&
      other.tageMitWerten == tageMitWerten &&
      other.mittlereAbweichungKcal == mittlereAbweichungKcal;

  @override
  int get hashCode =>
      Object.hash(getroffen, tageMitWerten, mittlereAbweichungKcal);

  @override
  String toString() =>
      'SiebenTage(getroffen: $getroffen, tageMitWerten: $tageMitWerten, '
      'mittlereAbweichungKcal: $mittlereAbweichungKcal)';
}

/// Zählt über die übergebenen Tage.
///
/// **Gekürzt wird hier nicht.** Welche Tage das sind, entscheidet der
/// Aufrufer; der Name nennt den Zweck, nicht eine Längenprüfung.
///
/// Der Zielbereich ist derselbe wie in [bilanz] — dieselbe Funktion, nicht
/// dieselbe Regel zweimal geschrieben.
SiebenTage siebenTage(List<({double? gegessen, double? ziel})> tage) {
  var getroffen = 0;
  var beurteilbar = 0;
  var summeAbweichung = 0.0;

  for (final tag in tage) {
    final gegessen = tag.gegessen;
    final ziel = tag.ziel;
    if (gegessen == null || ziel == null) continue;

    beurteilbar++;
    summeAbweichung += gegessen - ziel;
    if (_status(gegessen, ziel) == Zielstatus.imZiel) getroffen++;
  }

  return SiebenTage(
    getroffen: getroffen,
    tageMitWerten: beurteilbar,
    mittlereAbweichungKcal: beurteilbar == 0
        ? null
        : summeAbweichung / beurteilbar,
  );
}
