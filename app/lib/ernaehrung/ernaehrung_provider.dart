// Der Zustand des Ernährungs-Tag-Schirms (#282, Ernährungsplan Task 4) —
// alles, was der Schirm zeigt, einmal gerechnet und ohne Widget prüfbar.
// Die Oberfläche liegt in `ernaehrung_view.dart`.
//
// API und Vertrag sind durch `app/test/ernaehrung/ernaehrung_tag_test.dart`
// und `app/test/ernaehrung/ernaehrung_provider_test.dart` verbindlich
// vorgegeben (siehe deren Dateiköpfe) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die eigene Tabelle ist die Wahrheit, Health zählt dazu** (Tim,
// 03.11.2026). Daraus folgt der Schnitt dieser Datei: Tims Einträge
// stehen **ohne** `Messwert` da — für sie gibt es keinen Lauf, der leer
// ausgehen kann —, und nur die fremden Mahlzeiten aus Apple Health tragen
// einen. Der Ring zeigt deshalb sofort, was in der eigenen Tabelle steht,
// und zählt nach, was der Health-Lauf bringt.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/ereignisse.dart';
import '../data/ernaehrung_repository.dart';
import '../data/kalorienziele.dart';
import '../data/mahlzeit_aufteilungen.dart';
import '../data/stammdaten.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import '../tag/laufender_tag_provider.dart';

/// Eine fremde Mahlzeit aus Apple Health — eine, die **nicht** aus dieser
/// App stammt.
///
/// Die eigenen Proben sind auf der Swift-Seite des Kanals an ihrer Quelle
/// erkannt und übersprungen (Task 5), hier kommen also nur fremde an.
/// Trägt [Naehrwerte] aus `trainings_core` und nicht den Transporttyp des
/// Kanals: Ein zweiter Typ für dieselben acht Felder wäre eine zweite
/// Stelle, an der `null` zu `0` werden kann (#232).
@immutable
class FremdeMahlzeit {
  const FremdeMahlzeit({
    required this.zeitpunkt,
    required this.name,
    required this.naehrwerte,
  });

  /// Wann gegessen wurde, als UTC-Zeitpunkt.
  final DateTime zeitpunkt;

  final String name;

  final Naehrwerte naehrwerte;

  @override
  bool operator ==(Object other) =>
      other is FremdeMahlzeit &&
      other.zeitpunkt == zeitpunkt &&
      other.name == name &&
      other.naehrwerte == naehrwerte;

  @override
  int get hashCode => Object.hash(zeitpunkt, name, naehrwerte);

  @override
  String toString() =>
      'FremdeMahlzeit(zeitpunkt: $zeitpunkt, name: $name, '
      'naehrwerte: $naehrwerte)';
}

/// Eine der vier Mahlzeitenzeilen des Tages.
///
/// **Es sind immer vier.** Eine Zeile ohne Eintrag verschwindet nicht, sie
/// zeigt ein Plus (`docs/screens/screens/ernaehrung.js`, Zustand `leer`).
@immutable
class MahlzeitZeile {
  const MahlzeitZeile({
    required this.mahlzeit,
    required this.eigene,
    required this.fremde,
    required this.summe,
    this.zielKcal,
    this.anteil,
  });

  final Mahlzeit mahlzeit;

  /// Tims eigene Einträge dieser Mahlzeit, chronologisch.
  final List<Eintrag> eigene;

  /// Die fremden Mahlzeiten, die in das Zeitfenster dieser Mahlzeit
  /// fallen, chronologisch.
  final List<FremdeMahlzeit> fremde;

  /// Eigene und fremde zusammen. Eine leere Zeile trägt **acht Nullen**,
  /// keinen fehlenden Wert: „noch nichts eingetragen" ist eine Aussage,
  /// kein Loch.
  final Naehrwerte summe;

  /// Das Kalorienziel dieser Mahlzeit (#374), ungerundet (V5) — aus der
  /// an diesem Tag geltenden Aufteilung und dem Tagesziel
  /// (`mahlzeitZielKcal` im Kern).
  ///
  /// `null` ohne gesicherte Aufteilung (Entscheidung 1: kein Startwert als
  /// Ersatz), ohne Tagesziel, bei 0 % (V4) und solange
  /// [ErnaehrungsTag.mahlzeitenLaedt].
  final double? zielKcal;

  /// Wie weit die Mahlzeit ihr Ziel erreicht hat (`mahlzeitAnteil` im Kern,
  /// V6): `0` ohne Eintrag, `null` ohne Ziel oder mit Eintrag ohne
  /// Kalorienangabe — **nie `0` statt „fehlt"**. Über 1 heißt über dem
  /// Ziel. `null`, solange [ErnaehrungsTag.mahlzeitenLaedt].
  final double? anteil;

  bool get leer => eigene.isEmpty && fremde.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is MahlzeitZeile &&
      other.mahlzeit == mahlzeit &&
      _gleicheListe(other.eigene, eigene) &&
      _gleicheListe(other.fremde, fremde) &&
      other.summe == summe &&
      other.zielKcal == zielKcal &&
      other.anteil == anteil;

  @override
  int get hashCode => Object.hash(
    mahlzeit,
    Object.hashAll(eigene),
    Object.hashAll(fremde),
    summe,
    zielKcal,
    anteil,
  );

  @override
  String toString() =>
      'MahlzeitZeile(mahlzeit: $mahlzeit, eigene: ${eigene.length}, '
      'fremde: ${fremde.length}, summe: $summe, zielKcal: $zielKcal, '
      'anteil: $anteil)';
}

/// Der fertig gerechnete Tag — die eine Abhängigkeit des Schirms.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Ohne
/// Wertgleichheit rechnete Riverpod Ring, Makros und Verlauf bei jedem
/// Zugriff neu — Fehler `03`, wortgleich, im neuen Code (`CLAUDE.md`).
@immutable
class ErnaehrungsTag {
  const ErnaehrungsTag({
    required this.tagesSchluessel,
    required this.istHeute,
    required this.mahlzeiten,
    required this.gegessen,
    required this.zielKcal,
    required this.zielLaedt,
    required this.makroziele,
    required this.bilanz,
    this.zielFestlegung,
    this.aufteilung,
    this.mahlzeitenLaedt = false,
    this.pausiertDurch,
  });

  /// Der **Esstag** als ISO-Tagesstring.
  final String tagesSchluessel;

  final bool istHeute;

  /// Immer vier, in `Mahlzeit.values`-Reihenfolge.
  final List<MahlzeitZeile> mahlzeiten;

  /// Was heute auf dem Teller lag — eigene Einträge **plus** fremde
  /// Mahlzeiten aus Apple Health.
  final Messwert<Naehrwerte> gegessen;

  /// Das Kalorienziel dieses Tages. `null` heißt „nicht berechenbar"
  /// **oder** „noch nicht nachgesehen"; welches von beidem, sagt
  /// [zielLaedt].
  final double? zielKcal;

  /// **Trennt „noch nicht nachgesehen" von „nicht berechenbar".** Beides
  /// ergibt `zielKcal == null`, aber nur das zweite darf einen Grund
  /// anzeigen — sonst stünde während des Ladens „kein Ziel berechenbar"
  /// auf dem Schirm, und das ist Fehler `01` in neuer Verpackung.
  final bool zielLaedt;

  final Makroziele makroziele;

  final Tagesbilanz bilanz;

  /// Die Festlegung, die an diesem Tag gilt (#410) — `null`, wenn das Ziel
  /// dieses Tages noch gerechnet ist (vor der ersten Festlegung). Die
  /// Herleitung liest daraus, woher die Zahl stammt und seit wann.
  final KalorienzielFestlegung? zielFestlegung;

  /// Die Aufteilung des Tagesziels, die an diesem Tag gilt (#374,
  /// `geltendeAufteilung`) — `null` vor der ersten gesicherten und solange
  /// die Historie gelesen wird. **Nie der Startwert** (Entscheidung 1).
  ///
  /// Steht auch ohne Tagesziel da: Daran erkennt die Liste, dass „Ziel je
  /// Mahlzeit festlegen" nicht gefragt ist, obwohl kein Ziel je Mahlzeit
  /// steht.
  final MahlzeitAufteilung? aufteilung;

  /// **Die Mahlzeitenliste lädt noch** (V9): die eigenen Einträge, die
  /// Aufteilungen oder das Tagesziel ([zielLaedt]) sind noch nicht
  /// gelesen. Solange steht in keiner Zeile ein Ziel oder ein Anteil — und
  /// die Liste zeigt weder „Ziel je Mahlzeit festlegen" noch „noch nichts
  /// eingetragen". Laden sieht nicht aus wie leer (Fehler `01`).
  final bool mahlzeitenLaedt;

  /// Die Auszeit, die an diesem Tag den Aufschlag fürs Körperziel aussetzt
  /// (#404, #447) — gesetzt genau dann, wenn die Pause am Ziel etwas ändert
  /// oder ändern würde: ein gerechneter Tag mit eingetragenem Körperziel
  /// oder ein fester, berechneter Tag. `null` ohne pausierende Auszeit, an
  /// einem Tag mit Ziel von Hand (V15), ohne Körperziel (Entscheidung 8)
  /// und solange die Ereignisse gelesen werden (V12).
  final AuszeitTage? pausiertDurch;

  @override
  bool operator ==(Object other) =>
      other is ErnaehrungsTag &&
      other.tagesSchluessel == tagesSchluessel &&
      other.istHeute == istHeute &&
      _gleicheListe(other.mahlzeiten, mahlzeiten) &&
      _gleicherMesswert(other.gegessen, gegessen) &&
      other.zielKcal == zielKcal &&
      other.zielLaedt == zielLaedt &&
      other.makroziele == makroziele &&
      other.bilanz == bilanz &&
      other.zielFestlegung == zielFestlegung &&
      other.aufteilung == aufteilung &&
      other.mahlzeitenLaedt == mahlzeitenLaedt &&
      other.pausiertDurch == pausiertDurch;

  @override
  int get hashCode => Object.hash(
    tagesSchluessel,
    istHeute,
    Object.hashAll(mahlzeiten),
    _messwertHash(gegessen),
    zielKcal,
    zielLaedt,
    makroziele,
    bilanz,
    zielFestlegung,
    aufteilung,
    mahlzeitenLaedt,
    pausiertDurch,
  );

  @override
  String toString() =>
      'ErnaehrungsTag(tagesSchluessel: $tagesSchluessel, '
      'istHeute: $istHeute, gegessen: $gegessen, zielKcal: $zielKcal, '
      'zielLaedt: $zielLaedt, zielFestlegung: $zielFestlegung, '
      'aufteilung: $aufteilung, mahlzeitenLaedt: $mahlzeitenLaedt, '
      'pausiertDurch: $pausiertDurch, bilanz: $bilanz)';
}

/// Die sichtbaren Nährwerte eines Tages — `null`, solange keine
/// dastehen.
///
/// Die eine Stelle, die den `Messwert` für die Anzeige auspackt: Wer
/// einen Wert sehen will, muss den Zustand erst unterscheiden, und das
/// soll nicht in jedem Abschnitt noch einmal stehen.
Naehrwerte? gegessenWerte(ErnaehrungsTag tag) => switch (tag.gegessen) {
  Bekannt<Naehrwerte>(:final wert) => wert,
  _ => null,
};

/// Die leere Summe: **acht Nullen**, kein fehlender Wert.
///
/// Das ist kein Verstoß gegen „`0` ist keine Antwort auf ‚kein Wert'",
/// sondern dessen Kehrseite: Für Tims eigene Daten gibt es keinen Lauf,
/// der leer ausgehen kann, und der Entwurf zeigt den Zustand `leer`
/// ausdrücklich mit dem vollen Tagesbudget.
const _leereSumme = Naehrwerte(
  kcal: 0,
  eiweissG: 0,
  kohlenhydrateG: 0,
  fettG: 0,
  zuckerG: 0,
  ballaststoffeG: 0,
  gesaettigtG: 0,
  wasserMl: 0,
);

/// Rechnet einen Esstag aus Tims Einträgen, den fremden Mahlzeiten und den
/// Tageswerten aus Apple Health.
///
/// Reine Funktion: Alles, was sie braucht, kommt herein — auch [jetzt] und
/// [heute]. Die Verdrahtung in den Riverpod-Baum liegt in
/// [ernaehrungsTagProvider].
///
/// **Das feste Ziel (#410).** Gilt an [tagesSchluessel] eine Festlegung
/// aus [kalorienziele], ist sie das Ziel — keine Rechnung, kein Laden, auch
/// ohne Stammdaten. Ohne Festlegung (vor der ersten, oder [kalorienziele]
/// leer) wird gerechnet wie bisher.
///
/// [kalorienzieleLaden]: Die Historie ist noch nicht gelesen. Dann steht
/// **kein** Ziel da und [ErnaehrungsTag.zielLaedt] ist `true` — sonst
/// zeigte der Ring kurz die gerechnete Zahl und spränge dann auf die feste
/// (Vorgabe des Koordinators zu #410, nicht von Tim entschieden; Hausregel
/// „Der Platzhalter gehört allein in `NochNie`").
///
/// **Das Ziel je Mahlzeit (#374).** Gilt an [tagesSchluessel] eine
/// Aufteilung aus [aufteilungen], bekommt jede Zeile ihr Ziel und ihren
/// Anteil — einmal hier gerechnet und mit dem Tag gehalten (Regel 2),
/// nicht je Bild in der Zeile. Die Rechnungen stehen im Kern
/// (`mahlzeitZielKcal`, `mahlzeitAnteil`).
///
/// [aufteilungenLaden], [eintraegeLaden]: Aufteilungen bzw. eigene
/// Einträge sind noch nicht gelesen. Zusammen mit [ErnaehrungsTag.zielLaedt]
/// ergeben sie [ErnaehrungsTag.mahlzeitenLaedt] (V9); solange steht weder
/// eine Aufteilung noch ein Ziel oder Anteil da.
///
/// **Die Auszeit (#404, #447).** Liegt [tagesSchluessel] in einer OP,
/// Krankheit oder Verletzung aus [auszeiten], fällt der Aufschlag fürs
/// Körperziel weg — die Fallunterscheidung steht einmal, in [_zielLage],
/// und gilt für [zielKcalAm] und [kalorienzielAnteileAm] genauso.
/// [auszeitenLaden]: Die Ereignisse sind noch nicht gelesen. Dann steht
/// **kein** Ziel da, auch nicht an einem festen Tag — sonst zeigte der Ring
/// kurz das Ziel mit Aufschlag und spränge auf „pausiert“ (V12).
ErnaehrungsTag ernaehrungsTagAus({
  required String tagesSchluessel,
  required String heute,
  required List<Eintrag> eigene,
  required Messwert<List<FremdeMahlzeit>> fremde,
  required Messwert<List<DailyMetrics>> tageswerte,
  required Stammdaten stammdaten,
  required DateTime jetzt,
  List<KalorienzielFestlegung> kalorienziele = const [],
  bool kalorienzieleLaden = false,
  List<AufteilungAb> aufteilungen = const [],
  bool aufteilungenLaden = false,
  bool eintraegeLaden = false,
  List<AuszeitTage> auszeiten = const [],
  bool auszeitenLaden = false,
}) {
  final fremdeListe = fremde is Bekannt<List<FremdeMahlzeit>>
      ? fremde.wert
      : const <FremdeMahlzeit>[];

  final zeilen = _zeilen(eigene: eigene, fremde: fremdeListe);
  final gegessen = _gegessen(
    eigene: eigene,
    fremde: fremde,
    fremdeListe: fremdeListe,
    jetzt: jetzt,
  );

  final tage = tageswerte is Bekannt<List<DailyMetrics>>
      ? tageswerte.wert
      : const <DailyMetrics>[];
  final tagDaten = _tageswertAm(tage, tagesSchluessel);
  final gewicht = _letztesGewicht(tage, tagesSchluessel);
  final istHeute = tagesSchluessel == heute;

  final lage = kalorienzieleLaden
      ? null
      : _zielLage(
          tagesSchluessel: tagesSchluessel,
          stammdaten: stammdaten,
          kalorienziele: kalorienziele,
          auszeiten: auszeiten,
        );
  final festlegung = lage?.festlegung;
  // V12: Solange die Ereignisse nicht gelesen sind, ist nicht entschieden,
  // ob der Tag pausiert — also steht weder Zahl noch Pause da.
  final zielKcal = lage == null || auszeitenLaden
      ? null
      : _zielKcalIn(
          lage,
          tagesSchluessel: tagesSchluessel,
          istHeute: istHeute,
          tagDaten: tagDaten,
          gewicht: gewicht,
          stammdaten: stammdaten,
        );
  final pausiertDurch = auszeitenLaden ? null : lage?.pause;

  // **Der Verbrauch ist immer der gemessene**, auch heute: Er ist eine
  // Messung und keine Vorgabe; nur das Ziel wird für heute ruhiggestellt
  // (#229). Fehlt eine der beiden Hälften, ist er `null` — eine halbe
  // Summe wäre eine falsche Zahl, kein Teilwert.
  final aktiv = tagDaten?.activeKcal;
  final basal = tagDaten?.basalKcal;
  final verbrauch = aktiv == null || basal == null
      ? null
      : (aktiv + basal).toDouble();

  // „Noch nicht nachgesehen" ist genau der eine Zustand, in dem der
  // Health-Lauf noch aussteht — **oder** die eigene Historie oder die
  // Ereignisse noch nicht gelesen sind. Ein festes Ziel lädt nicht von
  // Health: Es steht in der eigenen Tabelle („Zuerst der Cache").
  final zielLaedt =
      kalorienzieleLaden ||
      auszeitenLaden ||
      (festlegung == null && tageswerte is NochNie<List<DailyMetrics>>);

  // V9: Solange eine der drei Quellen lädt, steht in keiner Zeile ein Ziel
  // oder ein Anteil — kein „Abend 0" vor dem ersten Lesen.
  final mahlzeitenLaedt = eintraegeLaden || aufteilungenLaden || zielLaedt;
  // „Laden" gewinnt, wie beim festen Ziel: Eine halb gelesene Historie
  // gäbe eine Aufteilung, die gleich wieder verschwände.
  final aufteilung = aufteilungenLaden
      ? null
      : geltendeAufteilung(aufteilungen, tagesSchluessel);
  final mahlzeiten = mahlzeitenLaedt
      ? zeilen
      : _mitZiel(zeilen, aufteilung: aufteilung, tageszielKcal: zielKcal);

  return ErnaehrungsTag(
    tagesSchluessel: tagesSchluessel,
    istHeute: istHeute,
    mahlzeiten: mahlzeiten,
    gegessen: gegessen,
    zielKcal: zielKcal,
    zielLaedt: zielLaedt,
    // **Das Kohlenhydratziel kommt aus dem Kern** (#310): Es ist der Rest
    // des Kalorienbudgets, nachdem die Mindestmengen Eiweiß und Fett
    // abgezogen sind. Hier ist die einzige Stelle, an der Gewicht und
    // Kalorienziel zusammenkommen — der Schirm rechnet es deshalb nicht
    // nach, sondern liest es ab. Zwei Rechnungen an zwei Stellen gäben
    // später zwei verschiedene Kohlenhydratziele.
    //
    // Am festen Tag folgt nur das Kohlenhydratziel dem festen Ziel; Eiweiß
    // und Fett hängen weiter am Gewicht des Tages (g/kg) — Festlegung des
    // Test-Agenten zu #410, nicht von Tim.
    makroziele: gewicht == null
        ? const Makroziele()
        : makrozieleFuer(gewichtKg: gewicht, kalorienzielKcal: zielKcal),
    zielFestlegung: festlegung,
    aufteilung: aufteilung,
    mahlzeitenLaedt: mahlzeitenLaedt,
    pausiertDurch: pausiertDurch,
    bilanz: _bilanzDesTages(
      // Solange nichts dasteht, trägt die Bilanz keinen Wert — und keine
      // `0`: Ein Ring auf 0 behauptete „nichts gegessen" (Fehler `01`).
      gegessen: gegessen is Bekannt<Naehrwerte>
          ? gegessen.wert
          : const Naehrwerte(),
      verbrauchKcal: verbrauch,
      zielKcal: zielKcal,
      zielLaedt: zielLaedt,
    ),
  );
}

/// Die Tagesbilanz — und **während des Laufs ohne Grund.**
///
/// [Zielstatus.keinZiel] heißt „kein Kalorienziel berechenbar"; der Schirm
/// nennt dann den Grund und führt in die Einstellungen. Solange der
/// Health-Lauf aussteht, ist aber nichts entschieden: Es gibt noch kein
/// Gewicht, also auch noch kein Ziel, und „nicht berechenbar" wäre eine
/// Behauptung über eine Datenlage, die niemand gesehen hat — Fehler `01`
/// in neuer Verpackung.
///
/// [Zielstatus.keineWerte] ist in diesem Fall die einzige Antwort, die
/// nichts behauptet: Sie trägt keinen Grund und keine Einordnung. Alle
/// Zahlen der Bilanz bleiben dieselben, die `bilanz` aus dem Kern
/// errechnet — es ändert sich ausschließlich der Status.
Tagesbilanz _bilanzDesTages({
  required Naehrwerte gegessen,
  required double? verbrauchKcal,
  required double? zielKcal,
  required bool zielLaedt,
}) {
  final gerechnet = bilanz(
    gegessen: gegessen,
    verbrauchKcal: verbrauchKcal,
    zielKcal: zielKcal,
  );
  if (!zielLaedt || gerechnet.status != Zielstatus.keinZiel) return gerechnet;
  return Tagesbilanz(
    gegessenKcal: gerechnet.gegessenKcal,
    verbrauchKcal: gerechnet.verbrauchKcal,
    differenzKcal: gerechnet.differenzKcal,
    zielKcal: gerechnet.zielKcal,
    abweichungKcal: gerechnet.abweichungKcal,
    untergrenzeKcal: gerechnet.untergrenzeKcal,
    obergrenzeKcal: gerechnet.obergrenzeKcal,
    status: Zielstatus.keineWerte,
  );
}

/// Die vier Zeilen, immer alle vier.
///
/// **Ein eigener Eintrag steht in der Zeile, die er selbst nennt.** Die
/// Mahlzeit steht am Eintrag, nicht an seiner Uhrzeit: Tim darf sie im
/// Buchungsblatt umhängen, und eine zweite Zuordnung hier überstimmte das
/// stillschweigend.
///
/// **Eine fremde Mahlzeit landet in der Zeile ihrer Uhrzeit.** Fremde
/// Proben tragen keine Mahlzeit, nur einen Zeitpunkt; die Einteilung ist
/// [Mahlzeitfenster.fuer] auf der Berliner Wanduhr — und der Abend
/// umschließt Mitternacht.
List<MahlzeitZeile> _zeilen({
  required List<Eintrag> eigene,
  required List<FremdeMahlzeit> fremde,
}) {
  final eigeneSortiert = [...eigene]
    ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
  final fremdeSortiert = [...fremde]
    ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));

  return [
    for (final mahlzeit in Mahlzeit.values)
      () {
        final eigeneZeile = [
          for (final eintrag in eigeneSortiert)
            if (eintrag.mahlzeit == mahlzeit) eintrag,
        ];
        final fremdeZeile = [
          for (final mahl in fremdeSortiert)
            if (_mahlzeitVon(mahl.zeitpunkt) == mahlzeit) mahl,
        ];
        return MahlzeitZeile(
          mahlzeit: mahlzeit,
          eigene: eigeneZeile,
          fremde: fremdeZeile,
          summe: _summe([
            for (final eintrag in eigeneZeile) eintrag.naehrwerte,
            for (final mahl in fremdeZeile) mahl.naehrwerte,
          ]),
        );
      }(),
  ];
}

/// Die [zeilen] mit Ziel und Anteil je Mahlzeit (#374).
///
/// Ohne [aufteilung] bleiben sie, wie sie sind: kein Ziel, kein Anteil, und
/// **kein Startwert als Ersatz** (Entscheidung 1). „Eingetragen" heißt
/// eigene **oder** fremde Mahlzeit in der Zeile — dieselbe Summe, die die
/// Zeile anzeigt.
List<MahlzeitZeile> _mitZiel(
  List<MahlzeitZeile> zeilen, {
  required MahlzeitAufteilung? aufteilung,
  required double? tageszielKcal,
}) {
  if (aufteilung == null) return zeilen;
  return [
    for (final z in zeilen)
      () {
        final ziel = mahlzeitZielKcal(
          tageszielKcal: tageszielKcal,
          aufteilung: aufteilung,
          mahlzeit: z.mahlzeit,
        );
        return MahlzeitZeile(
          mahlzeit: z.mahlzeit,
          eigene: z.eigene,
          fremde: z.fremde,
          summe: z.summe,
          zielKcal: ziel,
          anteil: mahlzeitAnteil(
            hatEintrag: !z.leer,
            kcal: z.summe.kcal,
            zielKcal: ziel,
          ),
        );
      }(),
  ];
}

/// Die Mahlzeit eines Zeitpunkts — über die **Berliner Wanduhr**, nicht
/// über UTC: 22:30 UTC ist im Juli in Berlin schon 00:30 und gehört zum
/// Abend davor.
Mahlzeit _mahlzeitVon(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  return Mahlzeitfenster.fuer(stunde * Duration.minutesPerHour + minute);
}

/// Das Gegessene über die vier `Messwert`-Zustände der Health-Hälfte.
///
/// Die Tabelle, auf der Fehler `01` lebt:
///
/// | fremde | eigene da | eigene leer |
/// |---|---|---|
/// | `NochNie` | `Bekannt(eigene, laeuft: true)` | `NochNie` |
/// | `Bekannt` | `Bekannt(eigene + fremde)` | `Bekannt(0)` bzw. `Bekannt(fremde)` |
/// | `LeerNachLauf` | `Bekannt(eigene)` | `Bekannt(0)` |
/// | `Fehlgeschlagen` | `Bekannt(eigene)` | `Fehlgeschlagen` |
///
/// Zwei Zeilen darin sind Entscheidungen, keine Mechanik:
///
/// - **Ein fertiger Lauf ohne fremde Mahlzeiten ist kein Leerstand.**
///   Health hat nachgesehen und nichts Fremdes gefunden; an einem eigenen
///   Tag heißt das schlicht „nichts gegessen". `LeerNachLauf` wäre hier
///   falsch.
/// - **Ein gescheiterter Lauf nimmt keinen sichtbaren Wert weg — und
///   erfindet auch keinen.** Ohne eigenen Eintrag und ohne gelungenen Lauf
///   wäre „0 gegessen" eine Behauptung über etwas, das niemand gesehen
///   hat.
Messwert<Naehrwerte> _gegessen({
  required List<Eintrag> eigene,
  required Messwert<List<FremdeMahlzeit>> fremde,
  required List<FremdeMahlzeit> fremdeListe,
  required DateTime jetzt,
}) {
  final eigeneSumme = _summe([for (final e in eigene) e.naehrwerte]);

  switch (fremde) {
    case NochNie<List<FremdeMahlzeit>>():
      if (eigene.isEmpty) return const NochNie<Naehrwerte>();
      // Die eigenen Einträge stehen sofort da; der Health-Lauf kann
      // nachzählen.
      return Bekannt<Naehrwerte>(eigeneSumme, stand: jetzt, laeuft: true);

    case Bekannt<List<FremdeMahlzeit>>(:final stand, :final laeuft):
      return Bekannt<Naehrwerte>(
        _summe([
          for (final e in eigene) e.naehrwerte,
          for (final f in fremdeListe) f.naehrwerte,
        ]),
        stand: stand,
        laeuft: laeuft,
      );

    case LeerNachLauf<List<FremdeMahlzeit>>(:final gelaufen):
      return Bekannt<Naehrwerte>(eigeneSumme, stand: gelaufen, laeuft: false);

    case Fehlgeschlagen<List<FremdeMahlzeit>>(:final fehler, :final gelaufen):
      if (eigene.isEmpty) {
        return Fehlgeschlagen<Naehrwerte>(fehler: fehler, gelaufen: gelaufen);
      }
      return Bekannt<Naehrwerte>(eigeneSumme, stand: gelaufen, laeuft: false);
  }
}

/// Feldweise Summe. Eine **leere** Liste ergibt [_leereSumme], sonst gilt
/// die Regel von `Naehrwerte.operator +`: Ein Lebensmittel ohne
/// Ballaststoffangabe macht die Tagessumme dort `null`, nicht `0` (#232).
/// Der Unterschied ist der zwischen „nichts gegessen" und „nicht
/// deklariert".
Naehrwerte _summe(List<Naehrwerte> werte) {
  if (werte.isEmpty) return _leereSumme;
  return werte.reduce((a, b) => a + b);
}

DailyMetrics? _tageswertAm(List<DailyMetrics> tage, String tagesSchluessel) {
  for (final tag in tage) {
    if (tag.tag == tagesSchluessel) return tag;
  }
  return null;
}

/// Das letzte bekannte Gewicht **bis einschließlich** dieses Tages.
///
/// Tim wiegt sich nicht täglich. Gäbe es das Ziel nur an Wiegetagen,
/// stünde der Ring an fünf von sieben Tagen auf „kein Ziel".
double? _letztesGewicht(List<DailyMetrics> tage, String tagesSchluessel) {
  String? bester;
  double? gewicht;
  for (final tag in tage) {
    final wert = tag.weightKg;
    if (wert == null) continue;
    if (tag.tag.compareTo(tagesSchluessel) > 0) continue;
    if (bester == null || tag.tag.compareTo(bester) > 0) {
      bester = tag.tag;
      gewicht = wert;
    }
  }
  return gewicht;
}

/// Die Eingänge des Kalorienziels für einen Tag — **an einer Stelle**,
/// damit Ziel ([_zielKcalIn]) und Herleitung ([kalorienzielAnteileAm]) nie
/// aus verschiedenen Zahlen rechnen. Sonst widerspräche die Herleitung
/// der Zahl im Ring (#314).
///
/// **#229: Das Ziel für heute bewegt sich nicht.** Für den heutigen Tag
/// gehen `aktivKcal`/`basalKcal` nicht mit — der Kern fällt damit auf
/// Mifflin-St Jeor zurück, den „Planwert für heute" aus der Spec. Für
/// vergangene Tage zählt der gemessene Verbrauch: Ein vergangener Tag ist
/// abgeschlossen, dort ist die Messung die bessere Zahl als eine
/// Schätzung. Ohne das wüchse das Ziel über den Tag und stünde morgens
/// anders da als abends.
///
/// **Seit #410 gilt das nur noch vor der ersten Festlegung.** Ab dann
/// steht das feste Ziel da, und gerechnet wird hier nur noch einmal: beim
/// Festlegen selbst ([kalorienzielFestlegenProvider]).
typedef _ZielEingang = ({
  double? aktivKcal,
  double? basalKcal,
  double? gewichtKg,
  int? groesseCm,
  int? alter,
  double? zielgewichtKg,
  int? tageBisZiel,
});

_ZielEingang _zielEingang({
  required String tagesSchluessel,
  required bool istHeute,
  required DailyMetrics? tagDaten,
  required double? gewicht,
  required Stammdaten stammdaten,
}) {
  final zieldatum = stammdaten.zieldatum;
  return (
    aktivKcal: istHeute ? null : tagDaten?.activeKcal?.toDouble(),
    basalKcal: istHeute ? null : tagDaten?.basalKcal?.toDouble(),
    gewichtKg: gewicht,
    groesseCm: stammdaten.groesseCm,
    // Das Alter **am gezeigten Tag**, nicht am heutigen: Ein Blick auf
    // einen Tag im Vorjahr soll mit dem Alter rechnen, das damals galt.
    alter: stammdaten.alterAm(datumAusTag(tagesSchluessel)),
    zielgewichtKg: stammdaten.zielgewichtKg,
    tageBisZiel: zieldatum == null
        ? null
        : BerlinCalendar.daysBetween(from: tagesSchluessel, to: zieldatum),
  );
}

/// Was an einem Tag über das Ziel entscheidet: die geltende Festlegung
/// (#410) und die Auszeit, die den Aufschlag fürs Körperziel aussetzt
/// (#447). **Die eine Fallunterscheidung** aus der Spec („Wo die Pause
/// wirkt“) — [ernaehrungsTagAus], [zielKcalAm] und [kalorienzielAnteileAm]
/// lesen sie von hier, damit Ring, Verlauf und Herleitung nie verschiedene
/// Zahlen zeigen (#314).
///
/// [_ZielLage.pause] ist gesetzt, wenn die Pause am Ziel etwas ändert oder
/// ändern würde:
///
/// | Lage | pause |
/// |---|---|
/// | keine OP, Krankheit oder Verletzung am Tag | `null` |
/// | fester Tag von Hand | `null` (V15: die Zahl von Hand bleibt) |
/// | kein Körperziel eingetragen | `null` (Entscheidung 8) |
/// | sonst | die Auszeit aus `pausierendeAuszeitAm` |
///
/// „Kein Körperziel“ heißt wie in der Herleitung: Zielgewicht oder
/// Zieldatum fehlen — an einem festen Tag zusätzlich ein gespeicherter
/// Körperziel-Anteil von 0. Ein gespeicherter Aufschlag von damals wird
/// also auch dann ausgesetzt, wenn die Stammdaten seither kein Körperziel
/// mehr tragen (Festlegung des Implementierenden, nicht von Tim; dieselbe
/// Regel, nach der `ernaehrung_herleitung.dart` „kein Körperziel
/// eingetragen“ zeigt).
typedef _ZielLage = ({KalorienzielFestlegung? festlegung, AuszeitTage? pause});

_ZielLage _zielLage({
  required String tagesSchluessel,
  required Stammdaten stammdaten,
  required List<KalorienzielFestlegung> kalorienziele,
  required List<AuszeitTage> auszeiten,
}) {
  final festlegung = geltendeFestlegung(kalorienziele, tagesSchluessel);
  final auszeit = pausierendeAuszeitAm(auszeiten, tagesSchluessel);
  if (auszeit == null) return (festlegung: festlegung, pause: null);

  final ohneKoerperziel =
      stammdaten.zielgewichtKg == null || stammdaten.zieldatum == null;
  final AuszeitTage? pause;
  if (festlegung == null) {
    pause = ohneKoerperziel ? null : auszeit;
  } else {
    final anteile = festlegung.anteile;
    pause = anteile == null || (anteile.koerperzielKcal == 0 && ohneKoerperziel)
        ? null
        : auszeit;
  }
  return (festlegung: festlegung, pause: pause);
}

/// Das Kalorienziel des Tages in der [lage].
///
/// - Fester Tag: die gespeicherte Zahl, in der Pause ohne den gespeicherten
///   Körperziel-Anteil (V14, `festesZielPausiert` im Kern).
/// - Sonst gerechnet aus [_zielEingang], in der Pause mit `inErholung`.
double? _zielKcalIn(
  _ZielLage lage, {
  required String tagesSchluessel,
  required bool istHeute,
  required DailyMetrics? tagDaten,
  required double? gewicht,
  required Stammdaten stammdaten,
}) {
  final fest = lage.festlegung;
  if (fest != null) {
    if (lage.pause == null) return fest.kcal;
    // `_zielLage` setzt die Pause an einem festen Tag nur mit gespeicherten
    // Anteilen — `festesZielPausiert` ist hier also nie `null`.
    return festesZielPausiert(
          kcal: fest.kcal,
          koerperzielKcal: fest.anteile?.koerperzielKcal,
        ) ??
        fest.kcal;
  }
  final e = _zielEingang(
    tagesSchluessel: tagesSchluessel,
    istHeute: istHeute,
    tagDaten: tagDaten,
    gewicht: gewicht,
    stammdaten: stammdaten,
  );
  return kalorienziel(
    aktivKcal: e.aktivKcal,
    basalKcal: e.basalKcal,
    gewichtKg: e.gewichtKg,
    groesseCm: e.groesseCm,
    alter: e.alter,
    zielgewichtKg: e.zielgewichtKg,
    tageBisZiel: e.tageBisZiel,
    inErholung: lage.pause != null,
  );
}

/// Das Kalorienziel an [tagesSchluessel] — **dieselbe Zahl**, die
/// [ernaehrungsTagProvider] für diesen Tag hält, aus denselben Eingängen
/// ([_zielEingang]) und derselben Fallunterscheidung ([_zielLage]). Für
/// den 14-Tage-Verlauf (#312): Eine zweite Zielrechnung dort liefe früher
/// oder später auseinander.
///
/// Gilt an dem Tag eine Festlegung aus [kalorienziele] (#410), ist sie die
/// Zahl — wie in [ernaehrungsTagAus]. Liegt der Tag in einer Auszeit aus
/// [auszeiten], fällt der Aufschlag fürs Körperziel weg, auch rückwirkend
/// (Entscheidung 5). `null`, solange [auszeitenLaden] (V12).
///
/// Das Festlegen ([kalorienzielFestlegenProvider]) ruft diese Funktion
/// **ohne** Auszeiten auf: Gespeichert wird immer der volle Aufschlag (V13).
double? zielKcalAm({
  required String tagesSchluessel,
  required String heute,
  required Messwert<List<DailyMetrics>> tageswerte,
  required Stammdaten stammdaten,
  List<KalorienzielFestlegung> kalorienziele = const [],
  List<AuszeitTage> auszeiten = const [],
  bool auszeitenLaden = false,
}) {
  if (auszeitenLaden) return null;
  final tage = tageswerte is Bekannt<List<DailyMetrics>>
      ? tageswerte.wert
      : const <DailyMetrics>[];
  return _zielKcalIn(
    _zielLage(
      tagesSchluessel: tagesSchluessel,
      stammdaten: stammdaten,
      kalorienziele: kalorienziele,
      auszeiten: auszeiten,
    ),
    tagesSchluessel: tagesSchluessel,
    istHeute: tagesSchluessel == heute,
    tagDaten: _tageswertAm(tage, tagesSchluessel),
    gewicht: _letztesGewicht(tage, tagesSchluessel),
    stammdaten: stammdaten,
  );
}

/// Die drei Anteile des Kalorienziels an [tagesSchluessel] — aus
/// `kalorienzielAnteile` im Kern, mit genau den Eingängen, aus denen
/// [ernaehrungsTagAus] das Ziel rechnet. `null`, wenn kein Ziel
/// berechenbar ist. Reine Funktion; gehalten wird sie von
/// [ernaehrungsHerleitungProvider].
///
/// **An einem festen Tag (#410) die gespeicherten Anteile**, nicht die von
/// heute: Ihre Summe bleibt die Zahl im Ring (#314). Ein Ziel von Hand hat
/// keine — `null`; Anteile, die nicht zur Zahl gehören, erklärten etwas
/// anderes als den Ring.
///
/// **In der Auszeit (#447)** ist der Körperziel-Anteil 0 — gerechnet mit
/// `inErholung`, am festen Tag die gespeicherten Anteile mit Körperziel 0
/// (V14). Die Summe ist so immer die Zahl im Ring. `null`, solange
/// [auszeitenLaden] (V12).
KalorienzielAnteile? kalorienzielAnteileAm({
  required String tagesSchluessel,
  required String heute,
  required Messwert<List<DailyMetrics>> tageswerte,
  required Stammdaten stammdaten,
  List<KalorienzielFestlegung> kalorienziele = const [],
  List<AuszeitTage> auszeiten = const [],
  bool auszeitenLaden = false,
}) {
  if (auszeitenLaden) return null;
  final lage = _zielLage(
    tagesSchluessel: tagesSchluessel,
    stammdaten: stammdaten,
    kalorienziele: kalorienziele,
    auszeiten: auszeiten,
  );
  final fest = lage.festlegung;
  if (fest != null) {
    final gespeichert = fest.anteile;
    if (gespeichert == null || lage.pause == null) return gespeichert;
    return KalorienzielAnteile(
      grundumsatzKcal: gespeichert.grundumsatzKcal,
      aktivKcal: gespeichert.aktivKcal,
      koerperzielKcal: 0,
      gemessen: gespeichert.gemessen,
    );
  }
  final tage = tageswerte is Bekannt<List<DailyMetrics>>
      ? tageswerte.wert
      : const <DailyMetrics>[];
  final e = _zielEingang(
    tagesSchluessel: tagesSchluessel,
    istHeute: tagesSchluessel == heute,
    tagDaten: _tageswertAm(tage, tagesSchluessel),
    gewicht: _letztesGewicht(tage, tagesSchluessel),
    stammdaten: stammdaten,
  );
  return kalorienzielAnteile(
    aktivKcal: e.aktivKcal,
    basalKcal: e.basalKcal,
    gewichtKg: e.gewichtKg,
    groesseCm: e.groesseCm,
    alter: e.alter,
    zielgewichtKg: e.zielgewichtKg,
    tageBisZiel: e.tageBisZiel,
    inErholung: lage.pause != null,
  );
}

// ───────────────────────────────────────────────────────────────────────
// Wertgleichheit
// ───────────────────────────────────────────────────────────────────────

/// Inhaltsgleichheit zweier Listen. `package:collection` wäre der kurze
/// Weg; hier reicht die Handvoll Zeilen, und die Abhängigkeitsliste von
/// `app/` bleibt, wie sie ist.
bool _gleicheListe<T>(List<T> links, List<T> rechts) {
  if (identical(links, rechts)) return true;
  if (links.length != rechts.length) return false;
  for (var i = 0; i < links.length; i++) {
    if (links[i] != rechts[i]) return false;
  }
  return true;
}

/// Wertgleichheit zweier [Messwert] — **hier und nicht auf dem Typ
/// selbst.**
///
/// `Bekannt` und seine Geschwister vergleichen über die Instanz; ein `==`
/// dort nachzurüsten änderte das Neurechnen jedes Providers, der heute
/// schon einen `Messwert` hält (Erholung, Schlaf, Körper). Diese Datei
/// braucht die Gleichheit nur für [ErnaehrungsTag], also steht sie hier.
bool _gleicherMesswert(
  Messwert<Naehrwerte> links,
  Messwert<Naehrwerte> rechts,
) {
  return switch ((links, rechts)) {
    (NochNie<Naehrwerte>(), NochNie<Naehrwerte>()) => true,
    (
      Bekannt<Naehrwerte>(wert: final a, stand: final sa, laeuft: final la),
      Bekannt<Naehrwerte>(wert: final b, stand: final sb, laeuft: final lb),
    ) =>
      a == b && sa == sb && la == lb,
    (
      LeerNachLauf<Naehrwerte>(gelaufen: final a),
      LeerNachLauf<Naehrwerte>(gelaufen: final b),
    ) =>
      a == b,
    (
      Fehlgeschlagen<Naehrwerte>(fehler: final fa, gelaufen: final ga),
      Fehlgeschlagen<Naehrwerte>(fehler: final fb, gelaufen: final gb),
    ) =>
      fa == fb && ga == gb,
    _ => false,
  };
}

int _messwertHash(Messwert<Naehrwerte> messwert) => switch (messwert) {
  NochNie<Naehrwerte>() => 0,
  Bekannt<Naehrwerte>(:final wert, :final stand, :final laeuft) => Object.hash(
    wert,
    stand,
    laeuft,
  ),
  LeerNachLauf<Naehrwerte>(:final gelaufen) => Object.hash('leer', gelaufen),
  Fehlgeschlagen<Naehrwerte>(:final fehler, :final gelaufen) => Object.hash(
    fehler,
    gelaufen,
  ),
};

// ───────────────────────────────────────────────────────────────────────
// Der Riverpod-Baum
// ───────────────────────────────────────────────────────────────────────

/// Der Tag, den der Schirm gerade zeigt — als ISO-Tagesstring.
///
/// Steht zu Beginn auf dem **laufenden Tag** ([laufenderTagProvider],
/// #455, V17), nicht auf dem Kalendertag: Um 01:30 ist das noch der Vortag.
final offenerTagProvider = NotifierProvider<OffenerTagNotifier, String>(
  OffenerTagNotifier.new,
);

/// Blättert über `‹` und `›` — und **nie über den laufenden Tag hinaus**
/// (V16).
///
/// **Wechselt der laufende Tag, steht der Schirm auf dem neuen** (V16),
/// auch wenn Tim gerade geblättert hatte: [build] beobachtet nur den Tag
/// des laufenden Tages, baut also genau dann neu.
///
/// Ein Tag nach heute kann nichts zeigen als vier leere Mahlzeiten und ein
/// Ziel für einen Tag, der nicht stattgefunden hat; der Schlaf-Schirm
/// begrenzt sein Blättern aus demselben Grund (`fruehesterSchlaftag`,
/// #177). [setze] bleibt davon unberührt — wer ausdrücklich einen Tag
/// nennt, meint ihn.
class OffenerTagNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(laufenderTagProvider.select((s) => s.tag));

  /// `‹` ist `-1`, `›` ist `+1`.
  ///
  /// **Über den Kalender, nicht über 86.400 Sekunden:** Der 29.03.2026 hat
  /// 23 Stunden; wer `+ 86400` rechnet, landet auf dem 29. statt auf dem
  /// 30.
  void blaettere(int tage) {
    final laufend = ref.read(laufenderTagProvider).tag;
    final neu = BerlinCalendar.dayKey(
      BerlinCalendar.addDays(datumAusTag(state), tage),
    );
    state = neu.compareTo(laufend) > 0 ? laufend : neu;
  }

  void setze(String tagesSchluessel) => state = tagesSchluessel;
}

/// Zählt mit, wie oft ein Esstag nach einer Buchung, Änderung oder
/// Löschung neu gelesen wurde ([EigeneEintraegeNotifier.neuLesen]).
///
/// Wer über **mehrere** Tage summiert — die Tagessummen des Verlaufs
/// (#312) —, hört hierauf: Die eine Stelle, an der jeder Schreibweg
/// vorbeikommt, statt vierzehn Tageslisten zu beobachten, die dafür erst
/// geladen werden müssten.
final eintraegeStandProvider = NotifierProvider<EintraegeStand, int>(
  EintraegeStand.new,
);

class EintraegeStand extends Notifier<int> {
  @override
  int build() => 0;

  void weiter() => state++;
}

/// Die eigenen Einträge eines Esstags.
///
/// **Kein `Messwert`** — für Tims eigene Daten gibt es keinen Lauf, der
/// leer ausgehen kann. Leer heißt hier schlicht leer.
final eigeneEintraegeProvider =
    AsyncNotifierProvider.family<
      EigeneEintraegeNotifier,
      List<Eintrag>,
      String
    >(EigeneEintraegeNotifier.new);

class EigeneEintraegeNotifier extends AsyncNotifier<List<Eintrag>> {
  EigeneEintraegeNotifier(this.tagesSchluessel);

  final String tagesSchluessel;

  @override
  Future<List<Eintrag>> build() =>
      ref.watch(ernaehrungRepositoryProvider).eintraegeAmTag(tagesSchluessel);

  /// Der Weg, den das Buchungsblatt aus Task 7 nimmt: Es schreibt und sagt
  /// dann Bescheid. Ohne ihn stünde der Eintrag erst nach einem Neustart
  /// da.
  Future<void> neuLesen() async {
    final repo = ref.read(ernaehrungRepositoryProvider);
    state = await AsyncValue.guard(() => repo.eintraegeAmTag(tagesSchluessel));
    // Was über mehrere Tage summiert (der Verlauf, #312), liest danach
    // ebenfalls neu — sonst stünde eine Buchung dort erst nach einem
    // Neustart.
    ref.read(eintraegeStandProvider.notifier).weiter();
  }
}

/// Die fremden Mahlzeiten eines Esstags aus Apple Health.
///
/// **Den Lesezugriff gibt es noch nicht** — er entsteht mit Task 5 des
/// Ernährungsplans, zusammen mit dem Quellenfilter, der die eigenen Proben
/// an ihrer Bundle-ID erkennt und überspringt. Bis dahin antwortet dieser
/// Notifier mit [LeerNachLauf]: Es gibt nichts Fremdes zu zählen, und die
/// eigene Tabelle ist die Wahrheit.
///
/// **Nicht `NochNie`**, obwohl niemand nachgesehen hat: Ein Zustand, der
/// nie endet, ließe den Ladeplatzhalter für immer stehen — und das wäre
/// dieselbe falsche Auskunft wie ein Leerstand während des Laufs, nur
/// andersherum. Und nicht `Bekannt([])`: `Bekannt` soll nie leer sein.
class FremdeMahlzeitenNotifier
    extends AsyncNotifier<Messwert<List<FremdeMahlzeit>>> {
  FremdeMahlzeitenNotifier(this.tagesSchluessel);

  final String tagesSchluessel;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async {
    final jetzt = ref.watch(clockProvider)();
    return LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt);
  }
}

final fremdeMahlzeitenProvider =
    AsyncNotifierProvider.family<
      FremdeMahlzeitenNotifier,
      Messwert<List<FremdeMahlzeit>>,
      String
    >(FremdeMahlzeitenNotifier.new);

/// Der fertig gerechnete Tag, **gehalten** statt bei jedem Zugriff
/// gerechnet (Hausregel 2, Fehler `03`).
///
/// Synchron und ohne `AsyncValue`: Die Widget-Schicht bekommt einen Wert,
/// keinen Ladezustand — der Ladezustand steckt in [ErnaehrungsTag.gegessen]
/// und [ErnaehrungsTag.zielLaedt], wo der `switch` über den sealed-Typ ihn
/// vollständig abfragt.
///
/// `?? const NochNie(...)` und `?? const []` sind dieselben Rückfälle wie
/// im `erholungProvider`: Solange ein `AsyncNotifier` noch kein Ergebnis
/// hat, heißt das „noch nicht nachgesehen" — und bei Tims eigenen
/// Einträgen „noch keine gelesen", nicht „keine da".
///
/// **Wer heute beobachtet, stößt das Festlegen an** (#410): Für den
/// heutigen Tag beobachtet dieser Provider [kalorienzielFestlegenProvider].
/// Home und der Ernährungs-Tab lesen genau diesen Provider, also passiert
/// es beim ersten Start mit vollständigen Angaben.
final ernaehrungsTagProvider = Provider.family<ErnaehrungsTag, String>((
  ref,
  tagesSchluessel,
) {
  final jetzt = ref.watch(clockProvider)();
  final heute = BerlinCalendar.dayKey(jetzt);
  if (tagesSchluessel == heute) ref.watch(kalorienzielFestlegenProvider);
  final (:laden, :historie) = kalorienzielHistorie(
    ref.watch(kalorienzieleProvider),
  );
  final eigene = ref.watch(eigeneEintraegeProvider(tagesSchluessel));
  final aufteilungen = ref.watch(mahlzeitAufteilungenProvider);
  // Ändert sich nur, wenn sich an den Auszeiten etwas ändert
  // (`AuszeitenNotifier`) — eine neue Notiz rechnet keinen Tag neu.
  final auszeiten = ref.watch(auszeitenProvider);
  return ernaehrungsTagAus(
    tagesSchluessel: tagesSchluessel,
    heute: heute,
    eigene: eigene.value ?? const [],
    fremde:
        ref.watch(fremdeMahlzeitenProvider(tagesSchluessel)).value ??
        const NochNie<List<FremdeMahlzeit>>(),
    tageswerte:
        ref.watch(dailyMetricsProvider).value ??
        const NochNie<List<DailyMetrics>>(),
    stammdaten: stammdatenAusProvider(ref.watch(stammdatenProvider)).stammdaten,
    jetzt: jetzt,
    kalorienziele: historie,
    kalorienzieleLaden: laden,
    // Über `hasValue`, nicht über `.value ?? []` (Spec, „Der Tag kennt das
    // Ziel je Mahlzeit"): Eine noch nicht gelesene Liste ist kein „nichts
    // eingetragen" und keine „keine Aufteilung" (V9).
    //
    // **Ein Lesefehler lädt nicht ewig** (#434, Hinweis aus #432): Wie beim
    // festen Kalorienziel ([kalorienzielHistorie]) gilt eine unlesbare
    // Tabelle als „keine Aufteilung". Eine Liste, die für immer grau
    // bleibt, wäre die schlechtere Auskunft. Ein Fehler nach einem
    // gelesenen Stand behält diesen Stand (`hasValue`).
    aufteilungen: aufteilungen.hasValue ? aufteilungen.value! : const [],
    aufteilungenLaden: !aufteilungen.hasValue && !aufteilungen.hasError,
    eintraegeLaden: !eigene.hasValue,
    auszeiten: auszeiten.auszeiten,
    auszeitenLaden: auszeiten.laden,
  );
});

/// Übersetzt den Zustand der Historie — die eine Stelle dafür, damit Tag,
/// Herleitung und Verlauf dieselbe Antwort geben.
///
/// - **Noch nicht gelesen:** `laden`. Kein Ziel, keine gerechnete Zahl
///   (siehe [ernaehrungsTagAus]).
/// - **Gelesen:** die Historie.
/// - **Lesen gescheitert:** eine leere Historie — es wird gerechnet wie vor
///   #410, und festgelegt wird nichts ([kalorienzielFestlegenProvider]
///   sieht den Fehler). Ein Ring, der wegen einer unlesbaren Tabelle für
///   immer lädt, wäre die schlechtere Auskunft.
({bool laden, List<KalorienzielFestlegung> historie}) kalorienzielHistorie(
  AsyncValue<List<KalorienzielFestlegung>> zustand,
) {
  if (zustand.hasValue) return (laden: false, historie: zustand.value!);
  if (zustand.hasError) return (laden: false, historie: const []);
  return (laden: true, historie: const []);
}

/// Legt das Kalorienziel **einmal** fest (#410) — sobald es für heute
/// berechenbar ist und noch keins in der Tabelle steht.
///
/// Die Ausgestaltung ist eine **Vorgabe des Koordinators**, Tim hat die
/// Rückfrage weggeklickt; die Einzelheiten unten sind Festlegungen des
/// Test-Agenten (`test/ernaehrung/kalorienziel_fest_test.dart`), nicht von
/// Tim:
///
/// - **Mit der Formel für heute** (#229): Mifflin-St Jeor ohne den bisher
///   gemessenen Verbrauch, plus Körperziel. Die Anteile gehen mit, damit
///   die Herleitung später erklärt, woher die Zahl stammt.
/// - **Nur auf einen fertigen Stand.** Solange der Health-Lauf läuft oder
///   noch nie geliefert hat, wird nichts gespeichert: Ein Ziel aus halben
///   Angaben wäre fest — und bliebe falsch. Dasselbe gilt für Stammdaten,
///   die noch gelesen werden.
/// - **„Noch keins gespeichert" heißt: die Tabelle ist leer.** Steht eine
///   Festlegung da, egal welcher Herkunft, legt die App nie wieder von
///   selbst fest.
///
/// - **Ohne Auszeiten** (V13): Fiele das erste Festlegen in eine OP, stünde
///   sonst für alle Zeit ein Ziel ohne Aufschlag in der Tabelle. Die Pause
///   wirkt je Tag beim Anzeigen, nie beim Speichern — dieser Provider
///   beobachtet `auszeitenProvider` deshalb nicht.
///
/// Beobachtet wird er von [ernaehrungsTagProvider] für heute. Geschrieben
/// wird **nach** dem Aufbau (`Future.microtask`): Ein Provider darf einen
/// anderen nicht während seines eigenen Aufbaus ändern.
final kalorienzielFestlegenProvider = Provider<void>((ref) {
  final historie = ref.watch(kalorienzieleProvider);
  final stammdaten = ref.watch(stammdatenProvider);
  final tageswerte = ref.watch(dailyMetricsProvider).value;
  final heute = BerlinCalendar.dayKey(ref.watch(clockProvider)());

  if (!historie.hasValue || historie.hasError) return;
  if (historie.value!.isNotEmpty) return;
  if (!stammdaten.hasValue || stammdaten.isLoading) return;
  if (tageswerte is! Bekannt<List<DailyMetrics>> || tageswerte.laeuft) return;

  final s = stammdaten.value!;
  final kcal = zielKcalAm(
    tagesSchluessel: heute,
    heute: heute,
    tageswerte: tageswerte,
    stammdaten: s,
  );
  final anteile = kalorienzielAnteileAm(
    tagesSchluessel: heute,
    heute: heute,
    tageswerte: tageswerte,
    stammdaten: s,
  );
  if (kcal == null || anteile == null) return;

  final notifier = ref.read(kalorienzieleProvider.notifier);
  Future.microtask(() async {
    try {
      await notifier.legeErstesFest(
        KalorienzielFestlegung(
          abTag: heute,
          kcal: kcal,
          herkunft: KalorienzielHerkunft.berechnet,
          anteile: anteile,
        ),
      );
    } catch (fehler) {
      // Niemand wartet auf diesen Lauf, also fängt ihn auch niemand. Ein
      // gescheitertes Festlegen lässt die Tabelle leer; bis zum nächsten
      // Anlauf (beim nächsten Aufbau dieses Providers) wird gerechnet wie
      // vor #410 — eine Zahl steht trotzdem da.
      debugPrint('Kalorienziel festlegen: $fehler');
    }
  });
});

/// Die drei Anteile des Kalorienziels am Esstag (#314) — `null`, wenn kein
/// Ziel berechenbar ist. **Gehalten**, nicht bei jedem Zugriff gerechnet
/// (Hausregel 2); gelesen wird er erst, wenn „Woher das Ziel kommt"
/// aufgeklappt ist, denn `KlappAbschnitt` baut seinen Inhalt erst dann.
///
/// Dieselben Quellen wie [ernaehrungsTagProvider]; `KalorienzielAnteile`
/// hat `==`, ein neu gerechneter, gleicher Wert löst also nichts aus.
final ernaehrungsHerleitungProvider =
    Provider.family<KalorienzielAnteile?, String>((ref, tagesSchluessel) {
      final jetzt = ref.watch(clockProvider)();
      final (:laden, :historie) = kalorienzielHistorie(
        ref.watch(kalorienzieleProvider),
      );
      final auszeiten = ref.watch(auszeitenProvider);
      // Solange Historie oder Ereignisse nicht gelesen sind, gibt es keine
      // Anteile — dieselbe Antwort wie beim Ziel selbst (V12).
      if (laden || auszeiten.laden) return null;
      return kalorienzielAnteileAm(
        tagesSchluessel: tagesSchluessel,
        heute: BerlinCalendar.dayKey(jetzt),
        tageswerte:
            ref.watch(dailyMetricsProvider).value ??
            const NochNie<List<DailyMetrics>>(),
        stammdaten: stammdatenAusProvider(ref.watch(stammdatenProvider))
            .stammdaten,
        kalorienziele: historie,
        auszeiten: auszeiten.auszeiten,
      );
    });
