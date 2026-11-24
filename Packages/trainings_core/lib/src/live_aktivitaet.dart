import 'esstag.dart';
import 'mahlzeit.dart';
import 'mahlzeit_aufteilung.dart';

/// Die Fassungen der Live-Aktivität, in ihrer Rangfolge: Training schlägt
/// Kochen schlägt Essen.
enum LiveFassung { training, kochen, essen }

/// Die Schiedsstelle: welche Fassung läuft, oder `null`, wenn keine läuft.
///
/// Feste Rangfolge **Training > Kochen > Essen**. Gemerkt wird nichts
/// (Entscheidung 3, Tim 05.11.2026): Die untere Fassung kommt von selbst
/// zurück, sobald die obere wegfällt — in dem Moment, in dem die App diese
/// Funktion neu auswertet.
LiveFassung? waehleFassung({
  required bool trainingLaeuft,
  required bool kochlaufOffen,
  required bool essenEin,
}) {
  if (trainingLaeuft) return LiveFassung.training;
  if (kochlaufOffen) return LiveFassung.kochen;
  if (essenEin) return LiveFassung.essen;
  return null;
}

/// Der Eingang der Essen-Karte, je Mahlzeit: ob sie einen Eintrag hat, wie
/// viele Kalorien und — seit #374 — ihr Kalorienziel.
///
/// [kcal] `null` heißt „unbekannt", nicht „null Kalorien" — auch bei einer
/// Mahlzeit mit Eintrag.
final class MahlzeitStand {
  const MahlzeitStand({
    required this.mahlzeit,
    required this.hatEintrag,
    required this.kcal,
    this.zielKcal,
  });

  final Mahlzeit mahlzeit;

  /// Eigene oder fremde Einträge.
  final bool hatEintrag;

  final double? kcal;

  /// Das Kalorienziel dieser Mahlzeit, ungerundet (`mahlzeitZielKcal`).
  /// `null` heißt „kein Ziel" — dann gilt für den Ring weiter V2 der
  /// Live-Spec.
  final double? zielKcal;

  @override
  bool operator ==(Object other) =>
      other is MahlzeitStand &&
      other.mahlzeit == mahlzeit &&
      other.hatEintrag == hatEintrag &&
      other.kcal == kcal &&
      other.zielKcal == zielKcal;

  @override
  int get hashCode => Object.hash(mahlzeit, hatEintrag, kcal, zielKcal);

  @override
  String toString() =>
      'MahlzeitStand(${mahlzeit.name}, hatEintrag: $hatEintrag, kcal: $kcal, '
      'zielKcal: $zielKcal)';
}

/// Ein Ring der Essen-Karte, so wie er auf dem Sperrbildschirm steht.
///
/// **Mit Ziel füllt sich der Ring mit [anteil]** (#374, V15 der
/// Aufteilungs-Spec), bis zu drei Runden. **Nur ohne Ziel gilt noch V2**
/// der Live-Spec: Dann ist [anteil] `null`, und der Ring ist voll, sobald
/// die Mahlzeit einen Eintrag hat. [kcal] ist gerundet; `null` bleibt
/// `null` und steht auf der Karte als „–".
final class MahlzeitRing {
  const MahlzeitRing({
    required this.mahlzeit,
    required this.eintrag,
    required this.kcal,
    this.anteil,
  });

  final Mahlzeit mahlzeit;
  final bool eintrag;
  final int? kcal;

  /// `mahlzeitAnteil` des Stands: `0` ohne Eintrag, `null` ohne Ziel oder
  /// bei einem Eintrag ohne Kalorienangabe — **nie `0` statt „fehlt"**.
  /// Hell, ruhig und erledigt hängen weiter an [eintrag], nicht hieran.
  final double? anteil;

  @override
  bool operator ==(Object other) =>
      other is MahlzeitRing &&
      other.mahlzeit == mahlzeit &&
      other.eintrag == eintrag &&
      other.kcal == kcal &&
      other.anteil == anteil;

  @override
  int get hashCode => Object.hash(mahlzeit, eintrag, kcal, anteil);

  @override
  String toString() =>
      'MahlzeitRing(${mahlzeit.name}, eintrag: $eintrag, kcal: $kcal, '
      'anteil: $anteil)';
}

/// Der Inhalt der Essen-Karte.
///
/// Werttyp mit `==` und `hashCode`: Ohne sie wäre jede neu gerechnete Karte
/// ungleich der vorigen, und jede Neuberechnung ginge als Update an iOS —
/// das Update-Budget und Fehler `03` zugleich. Verglichen wird, was auf der
/// Karte steht; `jetzt` geht nur über [verfaelltUm] ein, das innerhalb
/// eines Esstags gleich bleibt.
final class EssenKarte {
  /// [ringe] wird als unveränderliche Kopie gehalten, damit Gleichheit und
  /// [hashCode] sich nicht hinterrücks ändern.
  EssenKarte({
    required List<MahlzeitRing> ringe,
    required this.ersteOffene,
    required this.serie,
    required this.serieAbMorgen,
    required this.verfaelltUm,
  }) : ringe = List.unmodifiable(ringe);

  /// Immer vier, in `Mahlzeit.values`-Reihenfolge, wenn über [essenKarte]
  /// gebaut.
  final List<MahlzeitRing> ringe;

  /// Die erste Hauptmahlzeit (Frühstück, Mittag, Abend) ohne Eintrag, in
  /// dieser Reihenfolge — nicht nach der Uhrzeit. Ein Snack ist nie offen.
  final Mahlzeit? ersteOffene;

  final int serie;

  /// Was ab 04:00 gilt, wenn die App bis dahin nicht mehr läuft.
  final int serieAbMorgen;

  /// UTC. Ohne Vorgabe `naechsterEsstagBeginn(jetzt)`; die App übergibt
  /// `Tagesstand.endetSpaetestens` (Tagesgrenze-Spec, Entscheidung 9).
  final DateTime verfaelltUm;

  @override
  bool operator ==(Object other) {
    if (other is! EssenKarte ||
        other.ersteOffene != ersteOffene ||
        other.serie != serie ||
        other.serieAbMorgen != serieAbMorgen ||
        other.verfaelltUm != verfaelltUm ||
        other.ringe.length != ringe.length) {
      return false;
    }
    for (var i = 0; i < ringe.length; i++) {
      if (other.ringe[i] != ringe[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(ringe),
    ersteOffene,
    serie,
    serieAbMorgen,
    verfaelltUm,
  );

  @override
  String toString() =>
      'EssenKarte(ringe: $ringe, ersteOffene: ${ersteOffene?.name}, '
      'serie: $serie, serieAbMorgen: $serieAbMorgen, '
      'verfaelltUm: ${verfaelltUm.toIso8601String()})';
}

/// Die Hauptmahlzeiten, in der Reihenfolge, in der [EssenKarte.ersteOffene]
/// sie prüft. Der Snack fehlt mit Absicht: Ohne Eintrag ist er „ruhig",
/// nie offen.
const _hauptmahlzeiten = [
  Mahlzeit.fruehstueck,
  Mahlzeit.mittag,
  Mahlzeit.abend,
];

/// Rechnet die Essen-Karte aus dem Stand der vier Mahlzeiten.
///
/// [mahlzeiten] muss jede Mahlzeit genau einmal enthalten, in beliebiger
/// Reihenfolge; alles andere wirft `ArgumentError` — ein Programmierfehler,
/// keine Datenlage. `kcal` wird kaufmännisch gerundet (`.5` weg von null),
/// `null` bleibt `null`. Der Anteil ist `mahlzeitAnteil` aus den
/// **ungerundeten** kcal des Stands und seinem Ziel; ohne Ziel ist er
/// `null`, und der Ring folgt V2.
///
/// [verfaelltUm] ist optional und additiv (Tagesgrenze-Spec,
/// „Live-Aktivität“): Fehlt er oder ist er `null`, gilt
/// `naechsterEsstagBeginn(jetzt)`. Die App übergibt
/// `Tagesstand.endetSpaetestens`, damit ein verlängerter Tag nicht um 04:00
/// verfällt.
EssenKarte essenKarte({
  required List<MahlzeitStand> mahlzeiten,
  required ({int heute, int abMorgen}) serie,
  required DateTime jetzt,
  DateTime? verfaelltUm,
}) {
  final jeMahlzeit = {for (final s in mahlzeiten) s.mahlzeit: s};
  if (mahlzeiten.length != Mahlzeit.values.length ||
      jeMahlzeit.length != Mahlzeit.values.length) {
    throw ArgumentError.value(
      mahlzeiten,
      'mahlzeiten',
      'jede der ${Mahlzeit.values.length} Mahlzeiten genau einmal',
    );
  }

  final ringe = [
    for (final m in Mahlzeit.values)
      MahlzeitRing(
        mahlzeit: m,
        eintrag: jeMahlzeit[m]!.hatEintrag,
        kcal: jeMahlzeit[m]!.kcal?.round(),
        anteil: mahlzeitAnteil(
          hatEintrag: jeMahlzeit[m]!.hatEintrag,
          kcal: jeMahlzeit[m]!.kcal,
          zielKcal: jeMahlzeit[m]!.zielKcal,
        ),
      ),
  ];

  Mahlzeit? ersteOffene;
  for (final m in _hauptmahlzeiten) {
    if (!jeMahlzeit[m]!.hatEintrag) {
      ersteOffene = m;
      break;
    }
  }

  return EssenKarte(
    ringe: ringe,
    ersteOffene: ersteOffene,
    serie: serie.heute,
    serieAbMorgen: serie.abMorgen,
    verfaelltUm: verfaelltUm ?? naechsterEsstagBeginn(jetzt),
  );
}
