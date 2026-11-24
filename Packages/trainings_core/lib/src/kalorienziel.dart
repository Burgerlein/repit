/// Ab diesem Grundumsatz gelten die Watch-Daten als ganztägig
/// (`docs/SPEC.md` 4.8). Darunter hat die Uhr einen Teil des Tages nicht
/// gemessen, und die gemessene Zahl wäre zu klein.
const double _ganztaegigAbKcal = 1400;

/// Aktivitätsfaktor auf den Grundbedarf nach Mifflin-St Jeor.
const double _aktivitaetsfaktor = 1.4;

/// Der Faustwert aus `docs/SPEC.md` 4.8: 7.700 kcal je Kilogramm
/// Körpermasse. Grob — Deckel und Trendkorrektur fangen das ab.
const double _kcalJeKg = 7700;

/// Untergrenze des Körperziel-Überschusses, sobald es einen gibt.
const double _ueberschussMinKcal = 100;

/// Obergrenze desselben.
const double _ueberschussMaxKcal = 400;

/// Das Kalorienziel eines Tages nach `docs/SPEC.md` 4.8.
///
/// Zwei Wege zum Verbrauch:
///
/// * **Ganztägige Watch-Daten** ([basalKcal] ≥ 1.400 **und** [aktivKcal]
///   vorhanden): Verbrauch = aktiv + Grundumsatz. [trainingsaufschlagKcal]
///   bleibt hier außen vor — „aktiv" enthält das Training schon, und
///   beides zu addieren zählte es doppelt.
/// * **Sonst Mifflin-St Jeor** (`10·kg + 6,25·cm − 5·Alter + 5`) mal 1,4,
///   plus [trainingsaufschlagKcal]. Fehlt der Aufschlag, ist er 0 — kein
///   Trainingseintrag ist kein fehlender Messwert.
///
/// Darauf kommt der Überschuss aus dem Körperziel (`docs/SPEC.md` 3.1):
/// nötige kg/Woche · 7.700 ÷ 7, begrenzt auf 100 bis 400 kcal am Tag. In
/// der OP-Erholung ist er 0.
///
/// `null` heißt **„kein Ziel berechenbar"**, nie `0`: Ohne Gewicht, Größe
/// oder Alter lässt sich auch der Mifflin-Rückfall nicht bilden, und ein
/// geschätztes Alter wäre eine stille Falschauskunft. Der Schirm führt in
/// diesem Fall auf die Einstellungen. Die Grenze ist `<= 0` wie bei
/// `ProteinTarget.grams` — ob eine Angabe plausibel ist, entscheidet nicht
/// der Kern.
double? kalorienziel({
  double? aktivKcal,
  double? basalKcal,
  double? gewichtKg,
  int? groesseCm,
  int? alter,
  double? zielgewichtKg,
  int? tageBisZiel,
  double? trainingsaufschlagKcal,
  bool inErholung = false,
  double? gewichtstrendKgProWoche,
}) {
  if (gewichtKg == null || gewichtKg <= 0) return null;
  if (groesseCm == null || groesseCm <= 0) return null;
  if (alter == null || alter <= 0) return null;

  final double verbrauch;
  if (_ganztaegig(basalKcal, aktivKcal)) {
    verbrauch = aktivKcal! + basalKcal!;
  } else {
    verbrauch =
        _grundbedarf(gewichtKg, groesseCm, alter) * _aktivitaetsfaktor +
        (trainingsaufschlagKcal ?? 0);
  }

  return verbrauch +
      _koerperzielUeberschuss(
        gewichtKg: gewichtKg,
        zielgewichtKg: zielgewichtKg,
        tageBisZiel: tageBisZiel,
        inErholung: inErholung,
        gewichtstrendKgProWoche: gewichtstrendKgProWoche,
      );
}

/// Ganztägige Watch-Daten: ein Grundumsatz ab 1.400 kcal **und** ein
/// Aktivwert. Die eine Stelle, an der [kalorienziel] und
/// [kalorienzielAnteile] den Weg wählen.
bool _ganztaegig(double? basalKcal, double? aktivKcal) =>
    basalKcal != null && basalKcal >= _ganztaegigAbKcal && aktivKcal != null;

/// Grundbedarf nach Mifflin-St Jeor: `10·kg + 6,25·cm − 5·Alter + 5`.
double _grundbedarf(double gewichtKg, int groesseCm, int alter) =>
    10 * gewichtKg + 6.25 * groesseCm - 5 * alter + 5;

/// Die drei Anteile eines Kalorienziels — die Herleitung „Woher das Ziel
/// kommt" auf dem Ernährungs-Tag (#314).
///
/// Ihre Summe ([summeKcal]) ist [kalorienziel] mit denselben Eingängen;
/// `kalorienziel_anteile_test.dart` hält das für jede Kombination der
/// Wege fest.
class KalorienzielAnteile {
  const KalorienzielAnteile({
    required this.grundumsatzKcal,
    required this.aktivKcal,
    required this.koerperzielKcal,
    required this.gemessen,
  });

  /// Ganztägige Watch-Daten: der gemessene Grundumsatz. Sonst der
  /// Grundbedarf nach Mifflin-St Jeor — eine **Schätzung**, siehe
  /// [gemessen].
  final double grundumsatzKcal;

  /// Ganztägige Watch-Daten: der gemessene Aktivverbrauch. Sonst der
  /// Planwert: der Teil des Faktors 1,4 über dem Grundbedarf plus
  /// Trainingsaufschlag.
  final double aktivKcal;

  /// Der Überschuss aus dem Körperziel; 0 ohne Körperziel.
  final double koerperzielKcal;

  /// `true` nur auf dem Weg über ganztägige Watch-Daten. Auf dem
  /// Mifflin-Weg ist die Aufteilung eine Lesart des Faktors 1,4, keine
  /// Messung — und die Anzeige muss das sagen.
  final bool gemessen;

  double get summeKcal => grundumsatzKcal + aktivKcal + koerperzielKcal;

  @override
  bool operator ==(Object other) =>
      other is KalorienzielAnteile &&
      other.grundumsatzKcal == grundumsatzKcal &&
      other.aktivKcal == aktivKcal &&
      other.koerperzielKcal == koerperzielKcal &&
      other.gemessen == gemessen;

  @override
  int get hashCode =>
      Object.hash(grundumsatzKcal, aktivKcal, koerperzielKcal, gemessen);

  @override
  String toString() =>
      'KalorienzielAnteile(grundumsatz: $grundumsatzKcal, aktiv: $aktivKcal, '
      'koerperziel: $koerperzielKcal, gemessen: $gemessen)';
}

/// Die Anteile von [kalorienziel] — dieselben Eingänge, dieselben Wege.
/// `null` genau dann, wenn [kalorienziel] `null` ist.
///
/// Auf dem Mifflin-Weg ist der Grundumsatz der Grundbedarf, der Aktivwert
/// der Rest des Faktors 1,4 plus Trainingsaufschlag, und das Ergebnis
/// heißt nicht [KalorienzielAnteile.gemessen].
KalorienzielAnteile? kalorienzielAnteile({
  double? aktivKcal,
  double? basalKcal,
  double? gewichtKg,
  int? groesseCm,
  int? alter,
  double? zielgewichtKg,
  int? tageBisZiel,
  double? trainingsaufschlagKcal,
  bool inErholung = false,
  double? gewichtstrendKgProWoche,
}) {
  if (gewichtKg == null || gewichtKg <= 0) return null;
  if (groesseCm == null || groesseCm <= 0) return null;
  if (alter == null || alter <= 0) return null;

  final koerperziel = _koerperzielUeberschuss(
    gewichtKg: gewichtKg,
    zielgewichtKg: zielgewichtKg,
    tageBisZiel: tageBisZiel,
    inErholung: inErholung,
    gewichtstrendKgProWoche: gewichtstrendKgProWoche,
  );

  if (_ganztaegig(basalKcal, aktivKcal)) {
    return KalorienzielAnteile(
      grundumsatzKcal: basalKcal!,
      aktivKcal: aktivKcal!,
      koerperzielKcal: koerperziel,
      gemessen: true,
    );
  }
  final grundbedarf = _grundbedarf(gewichtKg, groesseCm, alter);
  return KalorienzielAnteile(
    grundumsatzKcal: grundbedarf,
    aktivKcal:
        grundbedarf * (_aktivitaetsfaktor - 1) + (trainingsaufschlagKcal ?? 0),
    koerperzielKcal: koerperziel,
    gemessen: false,
  );
}

/// Der Überschuss aus dem Körperziel, in kcal pro Tag. `0`, wenn es kein
/// Ziel gibt — **nicht** die Untergrenze 100: Der Deckel begrenzt eine
/// gerechnete Rate, und wo keine Rate existiert, gibt es nichts zu
/// begrenzen. Sonst äße der Nutzer täglich 100 kcal zu viel, nur weil er
/// kein Ziel eingetragen hat.
///
/// Kein Zuschlag entsteht bei:
///
/// * [inErholung] — so steht es in der Spec;
/// * fehlendem Zielgewicht **oder** fehlendem Zieldatum: eine Rate braucht
///   beides;
/// * `tageBisZiel <= 0` — das Zieldatum ist erreicht oder vorbei, und eine
///   Division durch null liefe als `Infinity` durch jeden Deckel;
/// * einem Zielgewicht auf oder unter dem heutigen. Ein Abnehmziel ist in
///   `docs/SPEC.md` 3.1 nicht beschrieben, und der Kern rät nicht.
///
/// **Die Trendkorrektur ist die volle Lücke:** Nötig 0,20 kg/Woche,
/// gemessen 0,10 → gerechnet wird mit 0,30. Die Spec sagt „korrigiert
/// nach", nicht um wie viel; das ist die einfachste Regel, die die Zielrate
/// wirklich wiederherstellt, und der Deckel fängt den Überschwung. Liegt
/// der gemessene Trend so weit über der nötigen Rate, dass die korrigierte
/// nicht mehr positiv ist, bleibt kein Überschuss.
double _koerperzielUeberschuss({
  required double gewichtKg,
  required double? zielgewichtKg,
  required int? tageBisZiel,
  required bool inErholung,
  required double? gewichtstrendKgProWoche,
}) {
  if (inErholung) return 0;
  if (zielgewichtKg == null || tageBisZiel == null) return 0;
  if (tageBisZiel <= 0) return 0;

  final fehlendeKg = zielgewichtKg - gewichtKg;
  if (fehlendeKg <= 0) return 0;

  final noetigProWoche = fehlendeKg / tageBisZiel * 7;
  final effektivProWoche = gewichtstrendKgProWoche == null
      ? noetigProWoche
      : noetigProWoche + (noetigProWoche - gewichtstrendKgProWoche);
  if (effektivProWoche <= 0) return 0;

  final kcalProTag = effektivProWoche * _kcalJeKg / 7;
  if (kcalProTag < _ueberschussMinKcal) return _ueberschussMinKcal;
  if (kcalProTag > _ueberschussMaxKcal) return _ueberschussMaxKcal;
  return kcalProTag;
}
