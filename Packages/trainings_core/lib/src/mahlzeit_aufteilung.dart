import 'dart:math' as math;

import 'mahlzeit.dart';

// Rechnungen zur Aufteilung des Tagesziels auf die Mahlzeiten (#374).
//
// Grundlage ist die Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Die Rechnungen im Kern": Tims Entscheidungen 1 bis 5 vom
// 10.11.2026 und die Vorgaben V3 bis V7, die Tim am selben Tag übernommen
// hat. Hier stehen nur Zahlen, keine Sätze — die Beschriftungen gehören in
// die Views.

/// Um wie viele Prozentpunkte „−" und „+" eine Mahlzeit verschieben
/// (Entscheidung 3). Jede gespeicherte Zahl ist ein Vielfaches davon (V3).
const int aufteilungSchritt = 5;

/// Wie viele Runden ein Ring höchstens dreht (#386; als Deckel auch für
/// die Mahlzeitenringe in Entscheidung 4 vom 10.11.2026 freigegeben). Bei
/// 300 % ist Schluss — darüber steht, wie weit es ist, in der
/// Beschriftung, nicht im Ring.
const int rundenHoechstens = 3;

/// Wie sich das Tagesziel auf die vier Mahlzeiten verteilt, in ganzen
/// Prozent.
///
/// **Eingestellt werden nur Frühstück, Mittag und Abend; der Snack ist der
/// Rest** (Entscheidung 2). Die Summe stimmt dadurch immer, einen
/// Fehlerzustand „ergibt nicht 100" gibt es nicht.
///
/// Der Konstruktor prüft V3: jede der drei Zahlen mindestens 0 und ein
/// Vielfaches von [aufteilungSchritt], die Summe höchstens 100. Was das
/// verletzt, wirft `ArgumentError` — auch beim Lesen aus der Tabelle, denn
/// dort ist es ein Programmierfehler, keine Datenlage.
final class MahlzeitAufteilung {
  MahlzeitAufteilung({
    required this.fruehstueck,
    required this.mittag,
    required this.abend,
  }) {
    _pruefe(fruehstueck, 'fruehstueck');
    _pruefe(mittag, 'mittag');
    _pruefe(abend, 'abend');
    final summe = fruehstueck + mittag + abend;
    if (summe > 100) {
      throw ArgumentError(
        'Frühstück, Mittag und Abend ergeben $summe %, höchstens 100 % '
        'sind erlaubt (V3).',
      );
    }
  }

  /// Der Startwert 25 · 35 · 30 · 10 (Entscheidung 1). **Er ist ein
  /// Vorschlag fürs Formular, kein Ersatz:** Solange keine Aufteilung
  /// gesichert ist, hat keine Mahlzeit ein Ziel ([geltendeAufteilung] gibt
  /// dann `null`, [mahlzeitZielKcal] ebenso).
  static final MahlzeitAufteilung startwert = MahlzeitAufteilung(
    fruehstueck: 25,
    mittag: 35,
    abend: 30,
  );

  final int fruehstueck;
  final int mittag;
  final int abend;

  /// Der Rest bis 100 (Entscheidung 2).
  int get snack => 100 - fruehstueck - mittag - abend;

  /// Der Anteil von [m] am Tagesziel, in Prozent.
  int prozent(Mahlzeit m) => switch (m) {
    Mahlzeit.fruehstueck => fruehstueck,
    Mahlzeit.mittag => mittag,
    Mahlzeit.abend => abend,
    Mahlzeit.snack => snack,
  };

  /// Ob „+" bei [m] geht: nie beim Snack (er ist der Rest, Entscheidung 2),
  /// sonst nur, solange der Rest noch einen Schritt hergibt (V3).
  bool kannPlus(Mahlzeit m) =>
      m != Mahlzeit.snack && snack >= aufteilungSchritt;

  /// Ob „−" bei [m] geht: nie beim Snack, sonst nur über 0 % (V3).
  bool kannMinus(Mahlzeit m) =>
      m != Mahlzeit.snack && prozent(m) >= aufteilungSchritt;

  /// Eine neue Aufteilung, in der [m] einen Schritt mehr hat. Das Original
  /// bleibt, wie es ist. Wirft `StateError`, wenn [kannPlus] `false` ist —
  /// der Knopf ist dann gesperrt, ein Aufruf ein Programmierfehler.
  MahlzeitAufteilung plus(Mahlzeit m) {
    if (!kannPlus(m)) {
      throw StateError('„+" ist für ${m.name} gesperrt ($this).');
    }
    return _verschiebe(m, aufteilungSchritt);
  }

  /// Eine neue Aufteilung, in der [m] einen Schritt weniger hat. Wirft
  /// `StateError`, wenn [kannMinus] `false` ist.
  MahlzeitAufteilung minus(Mahlzeit m) {
    if (!kannMinus(m)) {
      throw StateError('„−" ist für ${m.name} gesperrt ($this).');
    }
    return _verschiebe(m, -aufteilungSchritt);
  }

  MahlzeitAufteilung _verschiebe(Mahlzeit m, int um) => MahlzeitAufteilung(
    fruehstueck: fruehstueck + (m == Mahlzeit.fruehstueck ? um : 0),
    mittag: mittag + (m == Mahlzeit.mittag ? um : 0),
    abend: abend + (m == Mahlzeit.abend ? um : 0),
  );

  static void _pruefe(int wert, String name) {
    if (wert < 0) {
      throw ArgumentError.value(wert, name, 'darf nicht negativ sein (V3)');
    }
    if (wert % aufteilungSchritt != 0) {
      throw ArgumentError.value(
        wert,
        name,
        'muss ein Vielfaches von $aufteilungSchritt sein (V3)',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MahlzeitAufteilung &&
      other.fruehstueck == fruehstueck &&
      other.mittag == mittag &&
      other.abend == abend;

  @override
  int get hashCode => Object.hash(fruehstueck, mittag, abend);

  @override
  String toString() =>
      'MahlzeitAufteilung($fruehstueck · $mittag · $abend · $snack)';
}

/// Eine Aufteilung und der Berliner Kalendertag (`YYYY-MM-DD`), ab dem sie
/// gilt (Entscheidung 5: eine neue Aufteilung gilt ab heute, frühere Tage
/// behalten ihre).
final class AufteilungAb {
  const AufteilungAb({required this.abTag, required this.aufteilung});

  final String abTag;
  final MahlzeitAufteilung aufteilung;

  @override
  bool operator ==(Object other) =>
      other is AufteilungAb &&
      other.abTag == abTag &&
      other.aufteilung == aufteilung;

  @override
  int get hashCode => Object.hash(abTag, aufteilung);

  @override
  String toString() => 'AufteilungAb($abTag, $aufteilung)';
}

/// Die Aufteilung, die am Tag [tagesSchluessel] gilt: die mit dem spätesten
/// `abTag <= tagesSchluessel` (Entscheidung 5). Die [historie] muss nicht
/// sortiert sein.
///
/// Vor der ersten Aufteilung — und bei leerer Historie — ist das `null`,
/// **nie der Startwert** (Entscheidung 1). Die Tagesschlüssel sind
/// ISO-Tagesstrings und vergleichen lexikografisch richtig.
MahlzeitAufteilung? geltendeAufteilung(
  List<AufteilungAb> historie,
  String tagesSchluessel,
) {
  AufteilungAb? beste;
  for (final eintrag in historie) {
    if (eintrag.abTag.compareTo(tagesSchluessel) > 0) continue;
    if (beste == null || eintrag.abTag.compareTo(beste.abTag) > 0) {
      beste = eintrag;
    }
  }
  return beste?.aufteilung;
}

/// Das Kalorienziel der Mahlzeit [mahlzeit]: `tageszielKcal × prozent /
/// 100`, **ungerundet** (V5 — angezeigt wird in ganzen kcal, gerechnet
/// nicht).
///
/// `null`, wenn das Tagesziel oder die Aufteilung fehlt, das Tagesziel
/// nicht über 0 liegt oder die Mahlzeit 0 % hat (V4: dann hat sie kein
/// Ziel, statt eines von 0 kcal).
double? mahlzeitZielKcal({
  required double? tageszielKcal,
  required MahlzeitAufteilung? aufteilung,
  required Mahlzeit mahlzeit,
}) {
  if (tageszielKcal == null || aufteilung == null) return null;
  if (!(tageszielKcal > 0)) return null;
  final prozent = aufteilung.prozent(mahlzeit);
  if (prozent <= 0) return null;
  return tageszielKcal * prozent / 100;
}

/// Wie weit eine Mahlzeit ihr Ziel erreicht hat, als Anteil (V6): gegessene
/// kcal durch [zielKcal], negative kcal als 0, gedeckelt auf
/// [rundenHoechstens], auf 0,01 gerundet.
///
/// - Ohne Ziel (`null` oder nicht über 0): `null`.
/// - Ohne Eintrag: `0` — es gibt ein Ziel, und nichts ist gegessen.
/// - Mit Eintrag, aber ohne Kalorienangabe: `null`, **nicht 0**. Der Ring
///   folgt dann V2 der Live-Spec (voll mit Eintrag).
double? mahlzeitAnteil({
  required bool hatEintrag,
  required double? kcal,
  required double? zielKcal,
}) {
  if (zielKcal == null || !(zielKcal > 0)) return null;
  if (!hatEintrag) return 0;
  if (kcal == null) return null;
  final roh = math.min(
    math.max(kcal, 0) / zielKcal,
    rundenHoechstens.toDouble(),
  );
  return (roh * 100).roundToDouble() / 100;
}

/// Die Runden eines Rings zu [anteil] — je Runde eine Zahl von 0 bis 1, von
/// der ersten an. Alle bis auf die letzte sind voll; die letzte trägt den
/// Überhang. Höchstens [rundenHoechstens] Runden.
///
/// Erfundene Beispiele: `0.5` → `[0.5]`, `1` → `[1]` (die zweite Runde
/// beginnt erst beim Überschreiten), `1.3` → `[1, 0.3]`, `2.5` →
/// `[1, 1, 0.5]`, ab `3` → `[1, 1, 1]`. `null`, nicht über 0 und `NaN`
/// ergeben `[]` — dann zeichnet der Ring allein die Spur.
///
/// Die Rechnung steht nur hier (V7); `ringRunden` in
/// `app/lib/design/ringe.dart` rechnet Wert und Ziel um und ruft sie auf.
List<double> anteilRunden(double? anteil) {
  if (anteil == null || !(anteil > 0)) return const [];
  var rest = math.min(anteil, rundenHoechstens.toDouble());
  final runden = <double>[];
  while (rest > 0 && runden.length < rundenHoechstens) {
    runden.add(rest >= 1 ? 1.0 : rest);
    rest -= 1;
  }
  return runden;
}
