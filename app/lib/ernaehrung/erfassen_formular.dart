// Die **Rechnung hinter den beiden Blättern** des Eintragwegs (#285):
// „Lebensmittel anlegen" und „Portion wählen" / „Eintrag ändern". Ohne
// Widget und ohne Datenbank — die Oberfläche liegt in `anlegen_blatt.dart`
// und `buchungs_blatt.dart`, die Verdrahtung in `erfassen_provider.dart`.
//
// API und Vertrag sind durch
// `app/test/ernaehrung/erfassen_formular_test.dart` verbindlich vorgegeben
// (siehe dessen Dateikopf) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// Vorlage ist `docs/screens/screens/erfassen.js`, Zustände `anlegen`,
// `produkt` und `aendern`.
//
// **Die Felder sind Text, nicht Zahlen.** Was getippt wird, ist Text;
// „13," ist ein Zwischenzustand beim Tippen und kein Fehler. Ein Formular
// aus `double?` müsste den Zwischenzustand entweder wegwerfen oder doppelt
// führen.
import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';
import 'portions_abruf.dart';

/// Liest ein Eingabefeld als nichtnegative Zahl.
///
/// **Drei Fälle in zwei Feldern:** leer → `(wert: null, lesbar: true)`,
/// lesbar → `(wert: 13.5, lesbar: true)`, unlesbar →
/// `(wert: null, lesbar: false)`. Leer ist kein Fehler, unlesbar schon —
/// und beide ergeben `null`, deshalb reicht das Feld allein nicht.
///
/// **Komma und Punkt gelten beide**, weil eine deutsche Tastatur das eine
/// und ein Zehnerblock das andere liefert. Ein angefangenes
/// Dezimaltrennzeichen („13,") ist lesbar: Es als Fehler zu behandeln
/// ließe den Sichern-Knopf bei jedem zweiten Tastendruck aufblitzen.
///
/// **Negative Zahlen sind unlesbar** — es gibt keine -5 g Fett. Die
/// Prüfung steht an genau **einer** Stelle statt einmal im Formular und
/// einmal im Blatt; dieselbe Haltung wie bei `alsMesswert` (`CLAUDE.md`,
/// Hausregel 1).
({double? wert, bool lesbar}) liesZahl(String text) {
  final roh = text.trim();
  if (roh.isEmpty) return (wert: null, lesbar: true);

  final normalisiert = roh.replaceAll(',', '.');
  if (!_zahl.hasMatch(normalisiert)) return (wert: null, lesbar: false);

  // `13.` ist für `double.parse` kein Literal, für den Tippenden aber die
  // halbe Eingabe von `13,5`. Die angehängte Null macht daraus eine Zahl,
  // ohne eine Nachkommastelle zu erfinden.
  final lesbar = normalisiert.endsWith('.') ? '${normalisiert}0' : normalisiert;
  final wert = double.tryParse(lesbar);
  if (wert == null || !wert.isFinite) return (wert: null, lesbar: false);
  return (wert: wert, lesbar: true);
}

/// Ziffern mit höchstens einem Dezimalpunkt und **ohne Vorzeichen**. Das
/// fehlende Vorzeichen ist die Regel „keine negativen Zahlen"; dass nach
/// dem Punkt nichts stehen muss, ist der Zwischenzustand beim Tippen.
final _zahl = RegExp(r'^(\d+(\.\d*)?|\.\d+)$');

/// Der Zustand des Blattes „Lebensmittel anlegen" (`erfassen.js`, Zustand
/// `anlegen`).
///
/// **Pflicht sind nur Name und Kalorien.** Wer die Rückseite nicht zur
/// Hand hat, trägt nach, was er weiß; was fehlt, bleibt leer und wird
/// nicht zu `0` — eine Null behauptete „enthält keins davon".
@immutable
class AnlegenFormular {
  const AnlegenFormular({
    this.name = '',
    this.fluessig = false,
    this.kcal = '',
    this.eiweissG = '',
    this.kohlenhydrateG = '',
    this.fettG = '',
    this.zuckerG = '',
    this.gesaettigtG = '',
    this.ballaststoffeG = '',
    this.barcode,
    this.portionen = const [],
  });

  final String name;

  /// Ob in Millilitern gerechnet wird — **die Einheit entscheidet über g
  /// oder ml, sonst nichts.**
  final bool fluessig;

  /// Die Nährwerte **je 100 g**, als getippter Text. So steht es auf jeder
  /// Packung, und so rechnet das Buchungsblatt jede Menge daraus aus.
  final String kcal;
  final String eiweissG;
  final String kohlenhydrateG;
  final String fettG;
  final String zuckerG;
  final String gesaettigtG;
  final String ballaststoffeG;

  /// Der Strichcode, wenn das Blatt aus dem Scanner kommt (#324) — sonst
  /// `null`. **Kein Feld zum Tippen:** Er wird vorbelegt und unverändert
  /// mitgesichert, damit der nächste Scan dieselbe Packung wiedererkennt.
  final String? barcode;

  /// Die Portionen aus dem Abschnitt „Portionen · freiwillig" (#325). Sie
  /// gehen beim Sichern mit dem Lebensmittel in einer Transaktion in die
  /// Tabelle (`ErfassenNotifier.legeLebensmittelAn`), nicht über
  /// [alsVorlage].
  final List<Portion> portionen;

  /// Ändert genau die angegebenen Felder. Ein übergebener Leerstring
  /// **leert** das Feld — nur `null` heißt „unverändert".
  AnlegenFormular mit({
    String? name,
    bool? fluessig,
    String? kcal,
    String? eiweissG,
    String? kohlenhydrateG,
    String? fettG,
    String? zuckerG,
    String? gesaettigtG,
    String? ballaststoffeG,
  }) => AnlegenFormular(
    name: name ?? this.name,
    fluessig: fluessig ?? this.fluessig,
    kcal: kcal ?? this.kcal,
    eiweissG: eiweissG ?? this.eiweissG,
    kohlenhydrateG: kohlenhydrateG ?? this.kohlenhydrateG,
    fettG: fettG ?? this.fettG,
    zuckerG: zuckerG ?? this.zuckerG,
    gesaettigtG: gesaettigtG ?? this.gesaettigtG,
    ballaststoffeG: ballaststoffeG ?? this.ballaststoffeG,
    barcode: barcode,
    portionen: portionen,
  );

  /// Eine Portion dazu, aufsteigend nach Menge einsortiert.
  AnlegenFormular mitNeuerPortion(Portion p) =>
      _mitPortionen(_sortiert([...portionen, p]));

  /// Ersetzt [alt] durch [neu].
  AnlegenFormular mitGeaenderterPortion(Portion alt, Portion neu) =>
      _mitPortionen(_sortiert([for (final p in portionen) p == alt ? neu : p]));

  /// Nimmt [p] heraus.
  AnlegenFormular ohnePortion(Portion p) => _mitPortionen([
    for (final q in portionen)
      if (q != p) q,
  ]);

  AnlegenFormular _mitPortionen(List<Portion> liste) => AnlegenFormular(
    name: name,
    fluessig: fluessig,
    kcal: kcal,
    eiweissG: eiweissG,
    kohlenhydrateG: kohlenhydrateG,
    fettG: fettG,
    zuckerG: zuckerG,
    gesaettigtG: gesaettigtG,
    ballaststoffeG: ballaststoffeG,
    barcode: barcode,
    portionen: List.unmodifiable(liste),
  );

  /// Ob „Sichern" offen ist.
  ///
  /// Name und Kalorien müssen dastehen — und **jedes** Feld muss lesbar
  /// sein, auch die freiwilligen. Ein Blatt, das bei unlesbarem Zucker
  /// sichert und den Zucker dabei fallen lässt, wirft eine Eingabe
  /// lautlos weg; der Nutzer sähe hinterher ein Lebensmittel ohne
  /// Zuckerangabe und hielte es für seine eigene Nachlässigkeit.
  ///
  /// **0 Kalorien sperren nicht** — Mineralwasser hat keine, und das ist
  /// eine Angabe.
  bool get kannSichern {
    if (name.trim().isEmpty) return false;
    if (liesZahl(kcal).wert == null) return false;
    return _felder.every((feld) => liesZahl(feld).lesbar);
  }

  /// Die Vorlage, die gesichert wird — `null`, solange [kannSichern]
  /// falsch ist.
  ///
  /// Der Schlüssel fehlt noch: Den vergibt die Datenbank. Und
  /// `zuletztBenutzt` fehlt ebenfalls — angelegt ist nicht benutzt.
  LebensmittelVorlage? alsVorlage() {
    if (!kannSichern) return null;
    return LebensmittelVorlage(
      name: name.trim(),
      fluessig: fluessig,
      je100g: Naehrwerte.je100g(
        kcal: liesZahl(kcal).wert,
        eiweissG: liesZahl(eiweissG).wert,
        kohlenhydrateG: liesZahl(kohlenhydrateG).wert,
        fettG: liesZahl(fettG).wert,
        zuckerG: liesZahl(zuckerG).wert,
        gesaettigtG: liesZahl(gesaettigtG).wert,
        ballaststoffeG: liesZahl(ballaststoffeG).wert,
      ),
      // Herkunft bleibt `eigen`, auch mit Strichcode: Die Werte hat Tim
      // von der Packung abgeschrieben, nicht aus Open Food Facts.
      barcode: barcode,
    );
  }

  List<String> get _felder => [
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    gesaettigtG,
    ballaststoffeG,
  ];
}

/// Der Zustand des Buchungsblattes — „Portion wählen" und „Eintrag ändern"
/// sind **derselbe** Zustand, einmal ohne und einmal mit [bearbeitetId].
///
/// Zwei Wege zur selben Menge laufen auseinander; der Entwurf zeigt
/// deshalb dasselbe Blatt (`erfassen.js`, Zustände `produkt` und
/// `aendern`).
///
/// **Portionen** (#325, #398): Neben „g" steht die Wahl einer Portion.
/// **Die Menge in g bzw. ml bleibt die Wahrheit des Eintrags** — mit
/// Portion ist sie `Anzahl × Portionsgramm`, die Portion selbst geht nur
/// als Schnappschuss mit. Die Vorgaben und Tests dazu stehen in
/// `app/test/ernaehrung/portions_formular_test.dart`.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Das Blatt
/// vergleicht Zustände; ohne Wertgleichheit wäre jedes `minus` bei 1 ein
/// neuer Zustand, obwohl sich nichts geändert hat.
@immutable
class BuchungsFormular {
  const BuchungsFormular({
    this.lebensmittelId,
    required this.name,
    required this.je100g,
    required this.tagesSchluessel,
    required this.mengeText,
    required this.mahlzeit,
    required this.minutenSeitMitternacht,
    this.grund = Tagesgrund.normal,
    this.fluessig = false,
    this.bearbeitetId,
    this.healthUuid,
    this.healthStand = HealthStand.offen,
    this.uebernahme,
    this.portionen = const [],
    this.portion,
    this.anzahlText = '1',
    this._mengeAusEintragG,
    this._fluessigUnbekannt = false,
    this._zeitpunktAusEintrag,
  });

  /// Ein frisches Blatt für eine Vorlage.
  ///
  /// [jetzt] bestimmt Mahlzeit **und** Uhrzeit — die Berliner Wanduhrzeit
  /// des Trackens, auch auf einem geblätterten Tag (Tim, 04.11.2026: „immer
  /// die Uhrzeit, an der ich es tracke, man kann es ja manuell umstellen";
  /// #328). Vorher stand hier die Fenstermitte, und ein Scan um 17:30 zeigte
  /// 15:30. Der **Tag** bleibt [tagesSchluessel], nicht der von [jetzt].
  ///
  /// [mahlzeit] wählt die Mahlzeit vor — so vom Mahlzeiten-Schirm (#344).
  /// **Die Uhrzeit bleibt dann trotzdem die von [jetzt]**, anders als bei
  /// [mitMahlzeit]: Vorwählen ist keine Geste im Blatt, sondern der Ort,
  /// von dem man kam, und #328 gilt für jedes frische Blatt.
  ///
  /// [portionen] sind die Portionen eines gespeicherten Lebensmittels. Bei
  /// einem noch nicht übernommenen Produkt aus Open Food Facts kommen sie
  /// stattdessen aus [LebensmittelVorlage.offPortionen] — `[]`, solange
  /// nicht abgefragt.
  ///
  /// [vorwahl] wählt vor, was zuletzt gebucht wurde (Entscheidung 7):
  /// eine Portion samt Anzahl oder „g" samt Menge. Ohne Vorwahl, oder wenn
  /// die vorgewählte Portion nicht in der Liste steht, „g" mit 100.
  ///
  /// [grund] ist der Grund des **laufenden** Tages (#456, V14) — und nur
  /// dessen: Wer auf den laufenden Tag bucht, übergibt ihn, jeder andere
  /// Tag rechnet `normal`. Er legt fest, auf welchem Kalendertag die
  /// Uhrzeit liegt ([zeitpunkt]) und welche Mahlzeit vorgewählt ist
  /// (Entscheidung 6). Um Di 01:30 auf dem laufenden Montag heißt das:
  /// Abend, Di 01:30 — nicht Mo 01:30 (#373). Den Grund bestimmt
  /// `buchungsgrund` (`laufender_tag_provider.dart`).
  factory BuchungsFormular.neu({
    required LebensmittelVorlage vorlage,
    required String tagesSchluessel,
    required DateTime jetzt,
    Mahlzeit? mahlzeit,
    List<Portion> portionen = const [],
    PortionsVorwahl? vorwahl,
    Tagesgrund grund = Tagesgrund.normal,
  }) {
    final gewaehlt = vorgewaehlteMahlzeit(
      jetzt: jetzt,
      mahlzeit: mahlzeit,
      grund: grund,
    );
    final uebernahme = _zuUebernehmen(vorlage);
    final liste = uebernahme != null
        ? (vorlage.offPortionen ?? const <Portion>[])
        : portionen;
    final (:mengeText, :portion, :anzahlText) = _vorbelegung(vorwahl, liste);

    return BuchungsFormular(
      lebensmittelId: vorlage.id,
      name: vorlage.name,
      je100g: vorlage.je100g,
      tagesSchluessel: tagesSchluessel,
      mengeText: mengeText,
      mahlzeit: gewaehlt,
      minutenSeitMitternacht: _wanduhrMinuten(jetzt),
      grund: grund,
      fluessig: vorlage.fluessig,
      uebernahme: uebernahme,
      portionen: List.unmodifiable(liste),
      portion: portion,
      anzahlText: anzahlText,
    );
  }

  /// Dasselbe Blatt, vorbelegt aus einem **gebuchten** Eintrag.
  ///
  /// **Es kennt die Vorlage nicht, und das ist der Kern.** Gerechnet wird
  /// aus dem, was der Eintrag selbst trägt — sonst zöge jede
  /// Mengenkorrektur stillschweigend die heutigen Zahlen des Lebensmittels
  /// herein, und der Januar sähe nach jeder Korrektur anders aus als
  /// damals.
  ///
  /// **Dasselbe gilt für die Portion** (V12): Mit Schnappschuss ist genau
  /// diese eine Portion gewählt und die einzige in der Liste, so wie sie
  /// beim Buchen hieß und wog. Die Anzahl rechnet mit den Gramm des
  /// Schnappschusses ([anzahlAus]).
  ///
  /// **Unverändert gesichert bleiben die Gramm des Eintrags genau
  /// erhalten** — 10 g bleiben 10 g, auch wenn die gerundete Anzahl 3,33
  /// × 3 g nur 9,99 g ergäbe. Neu gerechnet wird erst, wenn Anzahl oder
  /// Einheit geändert werden. *Vorgabe des Koordinators, nicht Tims
  /// Entscheidung; der Test regelt den Fall nicht.*
  ///
  /// **Die Einheit kommt aus dem Schnappschuss [Eintrag.fluessig]** (#403),
  /// nicht aus der Vorlage. Steht dort `null` (ein Eintrag von vor der
  /// Stufe 20), rechnet das Blatt in Gramm und gibt beim Sichern wieder
  /// `null` weiter — es erfindet keinen Schnappschuss. Den Rückfall auf
  /// die Vorlage macht, wer das Blatt öffnet (`MahlzeitInhalt
  /// .inMillilitern`), indem er den Eintrag mit `fluessig` übergibt.
  ///
  /// **Der Zeitpunkt des Eintrags bleibt genau erhalten, solange die
  /// Uhrzeit nicht geändert wird** (#456). Das Blatt rechnet ihn nicht aus
  /// Tag und Uhrzeit zurück: Ein Eintrag um Di 05:10 auf dem verlängerten
  /// Montag läge sonst nach bloßem Öffnen und Sichern auf Mo 05:10, denn
  /// den Grund des damaligen Tages kennt der Eintrag nicht. Wird die
  /// Uhrzeit geändert, rechnet das Blatt `normal` (V14) — für einen
  /// Eintrag aus einem verlängerten Tag ist das offen, siehe #456.
  factory BuchungsFormular.fuer(Eintrag eintrag) {
    final menge = eintrag.mengeG;
    final portionName = eintrag.portionName;
    final portionG = eintrag.portionG;
    final schnappschuss =
        menge != null && portionName != null && portionG != null && portionG > 0
        ? Portion(id: eintrag.portionId, name: portionName, mengeG: portionG)
        : null;

    return BuchungsFormular(
      lebensmittelId: eintrag.lebensmittelId,
      name: eintrag.name,
      je100g: _zurueckGerechnet(eintrag),
      tagesSchluessel: eintrag.tagesSchluessel,
      mengeText: _alsText(menge),
      mahlzeit: eintrag.mahlzeit,
      minutenSeitMitternacht: _wanduhrMinuten(eintrag.zeitpunkt),
      zeitpunktAusEintrag: eintrag.zeitpunkt,
      fluessig: eintrag.fluessig ?? false,
      fluessigUnbekannt: eintrag.fluessig == null,
      bearbeitetId: eintrag.id,
      healthUuid: eintrag.healthUuid,
      healthStand: eintrag.healthStand,
      portionen: schnappschuss == null ? const [] : [schnappschuss],
      portion: schnappschuss,
      anzahlText: schnappschuss == null
          ? '1'
          : _anzahlAlsText(anzahlAus(mengeG: menge!, portionG: portionG!)),
      mengeAusEintragG: schnappschuss == null ? null : menge,
    );
  }

  /// Die Vorlage, aus der gebucht wird — `null` beim Schnelleintrag.
  final int? lebensmittelId;

  final String name;

  /// Die Nährwerte je 100 g, aus denen [naehrwerte] entsteht.
  final Naehrwerte je100g;

  /// Der **offene** Tag des Schirms dahinter, nicht „heute" und im Blatt
  /// nicht änderbar: Wer über ‹ › den Montag aufhat und bucht, meint den
  /// Montag.
  final String tagesSchluessel;

  /// Die getippte Menge, als Text — derselbe Grund wie bei
  /// [AnlegenFormular]. Gilt, solange „g" gewählt ist ([portion] `null`).
  final String mengeText;

  final Mahlzeit mahlzeit;

  /// Die Uhrzeit auf der **Berliner Wanduhr**. Auf welchem Kalendertag
  /// sie liegt, sagt [grund] ([zeitpunkt]).
  final int minutenSeitMitternacht;

  /// Der Grund des laufenden Tages, wenn auf ihn gebucht wird, sonst
  /// `normal` (V14). Bleibt beim Setzen der Uhrzeit stehen: Auf dem
  /// verlängerten Montag liegt 06:00 auf Dienstag, 09:00 auf Montag.
  final Tagesgrund grund;

  /// Ob in Millilitern gerechnet wird — beim neuen Blatt aus der Vorlage,
  /// im Ändern-Blatt aus dem Schnappschuss des Eintrags (#403). Geht beim
  /// Buchen als [Eintrag.fluessig] mit.
  final bool fluessig;

  /// Der Eintrag, aus dem das Blatt vorbelegt ist, trug kein `fluessig`
  /// (Stand vor der Stufe 20). [alsEintrag] schreibt dann `null` zurück,
  /// solange [fluessig] nicht geändert wurde: Ein Sichern erfindet keinen
  /// Schnappschuss.
  final bool _fluessigUnbekannt;

  /// Der Schlüssel des Eintrags, der geändert wird — `null`, wenn neu
  /// gebucht wird. Das eine Feld, an dem die beiden Zustände des Blattes
  /// auseinandergehen.
  final int? bearbeitetId;

  /// Was aus der Kopie nach Apple Health geworden ist — **unverändert
  /// durchgereicht.** Das Blatt erfindet keinen Stand und wirft keine UUID
  /// weg; was mit der Kopie geschieht, entscheidet der Nachlauf.
  final String? healthUuid;
  final HealthStand healthStand;

  /// Das Produkt aus Open Food Facts, das **beim Buchen** in die eigene
  /// Tabelle wandert (#284) — `null` bei allem, was schon dort steht.
  ///
  /// Übernommen wird erst beim Buchen, nicht beim Antippen: Ein
  /// angesehenes und wieder verworfenes Produkt landete sonst in der
  /// eigenen Suche, und die füllte sich mit allem, was Tim je angesehen
  /// und nicht gegessen hat.
  ///
  /// Seine [LebensmittelVorlage.offPortionen] hält dieselbe Liste wie
  /// [portionen], sobald Open Food Facts geantwortet hat (V3). Solange
  /// nicht, bleibt sie `null` — auch wenn im Blatt schon eine eigene
  /// Portion angelegt wurde; siehe [mitNeuerPortion].
  final LebensmittelVorlage? uebernahme;

  /// Die Portionen, die als Knöpfe neben „g" stehen — nie `null`; ohne
  /// Portion `[]`.
  final List<Portion> portionen;

  /// Die gewählte Portion — `null` heißt „g" ist gewählt.
  final Portion? portion;

  /// Die Anzahl der gewählten Portion, als Text wie [mengeText]: „2",
  /// „0,5". Gilt nur mit [portion].
  final String anzahlText;

  /// Die Menge des gebuchten Eintrags, solange im Ändern-Blatt weder
  /// Anzahl noch Einheit geändert wurden — siehe [BuchungsFormular.fuer].
  final double? _mengeAusEintragG;

  /// Der Zeitpunkt des gebuchten Eintrags, solange im Ändern-Blatt die
  /// Uhrzeit nicht geändert wurde — siehe [BuchungsFormular.fuer].
  final DateTime? _zeitpunktAusEintrag;

  /// Dasselbe Formular, nachdem [uebernahme] in der eigenen Tabelle
  /// angekommen ist: Es bucht auf die Zeile [lebensmittelId] und
  /// übernimmt nichts mehr. **Die Wahl bleibt** — die gewählte Portion
  /// hat danach noch keinen Schlüssel; den sucht `ErfassenNotifier.buche`.
  BuchungsFormular uebernommenAls(int lebensmittelId) =>
      _kopie(lebensmittelId: lebensmittelId, uebernahme: null);

  BuchungsFormular mitMenge(String text) => _kopie(mengeText: text);

  /// Hängt die Mahlzeit um — **und zieht die Uhrzeit auf die neue Mitte.**
  ///
  /// Die Mahlzeit zu wechseln ist die grobe Geste, die Uhrzeit zu setzen
  /// die feine. Ohne das Mitziehen trüge ein umgehängtes Frühstück die
  /// Uhrzeit 19:00.
  BuchungsFormular mitMahlzeit(Mahlzeit mahlzeit) => _kopie(
    mahlzeit: mahlzeit,
    minutenSeitMitternacht: Mahlzeitfenster.mitteInMinuten(mahlzeit),
  );

  /// Setzt die Uhrzeit — und **lässt die Mahlzeit stehen**, auch über die
  /// Fenstergrenze hinweg.
  ///
  /// Die Gegenrichtung zu [mitMahlzeit] und gewollt: Die Mahlzeit steht am
  /// Eintrag, nicht an seiner Uhrzeit. Ein spätes Frühstück um 11:30
  /// bleibt ein Frühstück.
  BuchungsFormular mitUhrzeit(int minutenSeitMitternacht) =>
      _kopie(minutenSeitMitternacht: minutenSeitMitternacht);

  /// Die Anzahl der gewählten Portion — `null`, wenn leer oder unlesbar.
  double? get anzahl => liesZahl(anzahlText).wert;

  /// Die Menge in Gramm (bzw. Milliliter) — `null`, wenn das Feld leer
  /// oder unlesbar ist. Mit Portion `Anzahl × Portionsgramm`.
  double? get mengeG => _mengeAus(
    mengeText: mengeText,
    portion: portion,
    anzahlText: anzahlText,
    unveraendertG: _mengeAusEintragG,
  );

  /// Ob „Buchen" offen ist. **Die Menge muss größer als 0 sein:** Die
  /// Portion ist die eigentliche Frage dieses Blattes, und 0 g ist keine
  /// Portion. Mit Portion heißt das: eine Anzahl größer 0 (V7).
  ///
  /// Das ist kein Widerspruch zu „eine gewogene 0 bleibt 0" — das gilt für
  /// Nährwerte, nicht für die Menge.
  bool get kannBuchen {
    final menge = mengeG;
    return menge != null && menge > 0;
  }

  /// Die gerechneten Nährwerte dieser Portion.
  ///
  /// Ohne lesbare Menge sind sie **leer**, nicht Null: Eine Null
  /// behauptete, die Portion enthalte nichts.
  Naehrwerte get naehrwerte {
    final menge = mengeG;
    return menge == null ? const Naehrwerte() : je100g.fuerMenge(menge);
  }

  /// Der Zeitpunkt des Eintrags, als UTC: [minutenSeitMitternacht] auf dem
  /// Kalendertag, auf den sie an [tagesSchluessel] mit [grund] fällt
  /// (`zeitpunktImTag`, V14). Vor 04:00 ist das der Folgetag — um 01:30 auf
  /// Montag gebucht heißt Di 01:30.
  ///
  /// Im Ändern-Blatt bei unveränderter Uhrzeit der gespeicherte Zeitpunkt
  /// ([BuchungsFormular.fuer]).
  DateTime get zeitpunkt =>
      _zeitpunktAusEintrag ??
      zeitpunktImTag(
        tag: tagesSchluessel,
        minuten: minutenSeitMitternacht,
        grund: grund,
      );

  // --- Portionen ------------------------------------------------------

  /// Wählt eine Portion — mit **Anzahl 1** (Entscheidung 9).
  BuchungsFormular waehlePortion(Portion p) =>
      _kopie(portion: p, anzahlText: '1', mengeAusEintragG: null);

  /// Wählt „g" — und **übernimmt die aktuelle Menge** (Entscheidung 9):
  /// Aus 2 Bons werden 11,8 g. Höchstens eine Nachkommastelle, damit kein
  /// Rechenrauschen im Feld steht; die Gramm eines unveränderten Eintrags
  /// stehen genau da.
  BuchungsFormular waehleGramm() {
    if (portion == null) return this;
    final unveraendert = _mengeAusEintragG;
    final menge = mengeG;
    return _kopie(
      portion: null,
      mengeText: unveraendert != null
          ? _alsText(unveraendert)
          : menge == null
          ? ''
          : _mengeAlsText(menge),
      mengeAusEintragG: null,
    );
  }

  /// Setzt die Anzahl, wie sie im Ziffernblock steht („0,5").
  BuchungsFormular mitAnzahl(String text) => text == anzahlText
      ? this
      : _kopie(anzahlText: text, mengeAusEintragG: null);

  /// + addiert 1 (V7). Eine unlesbare Anzahl wird zu 1.
  BuchungsFormular plus() {
    if (portion == null) return this;
    final a = anzahl;
    final neu = a == null ? 1.0 : anzahlPlus(a);
    return _kopie(anzahlText: _anzahlAlsText(neu), mengeAusEintragG: null);
  }

  /// − zieht 1 ab, nie unter 1 (V7). Bei 1 oder weniger ändert es nichts
  /// und gibt **dasselbe** Formular zurück.
  BuchungsFormular minus() {
    if (portion == null) return this;
    final a = anzahl;
    if (a == null) return this;
    final neu = anzahlMinus(a);
    if (neu == null) return this;
    return _kopie(anzahlText: _anzahlAlsText(neu), mengeAusEintragG: null);
  }

  /// Ersetzt die Liste der Portionen (V11).
  ///
  /// Steht die gewählte Portion noch darin — gleiche `id`, bei einer
  /// ungespeicherten gleicher Name und gleiche Menge —, bleibt sie gewählt,
  /// mit den neuen Werten, und die Anzahl bleibt. Sonst springt die Wahl
  /// auf „g" mit der aktuellen Menge (wie [waehleGramm]).
  BuchungsFormular mitPortionen(List<Portion> portionen) {
    final liste = List<Portion>.unmodifiable(portionen);
    final gewaehlt = portion;
    if (gewaehlt == null) return _kopie(portionen: liste);
    final wieder = _finde(liste, gewaehlt);
    if (wieder == null) return waehleGramm()._kopie(portionen: liste);
    return _kopie(
      portionen: liste,
      portion: wieder,
      mengeAusEintragG: wieder == gewaehlt ? _mengeAusEintragG : null,
    );
  }

  /// Legt eine Portion im Blatt an und wählt sie mit Anzahl 1 — für ein
  /// noch nicht übernommenes Produkt (V3). Sie geht beim Buchen mit der
  /// Übernahme in die Tabelle; „Abbrechen" verwirft sie.
  ///
  /// **Hat Open Food Facts noch nicht geantwortet** (Abruf läuft oder ist
  /// gescheitert), bleibt [LebensmittelVorlage.offPortionen] `null`, und
  /// die Portion steht nur in [portionen]. `ErfassenNotifier.buche` bucht
  /// sie trotzdem mit, als `eigen`, setzt aber `portionen_abgefragt_am`
  /// nicht — sonst fragte das Produkt nie wieder, obwohl nie eine Antwort
  /// kam (V4). *Vorgabe des Koordinators, nicht Tims Entscheidung; der
  /// Test regelt den Fall nicht.*
  BuchungsFormular mitNeuerPortion(Portion p) =>
      _mitListe(_sortiert([...portionen, p]))
          ._kopie(portion: p, anzahlText: '1', mengeAusEintragG: null);

  /// Ersetzt [alt] durch [neu] — in [portionen] und, soweit gesetzt, in
  /// den Portionen der Übernahme. War [alt] gewählt, ist es danach [neu],
  /// die Anzahl bleibt, die Gramm folgen (V11).
  BuchungsFormular mitGeaenderterPortion(Portion alt, Portion neu) {
    final liste = _sortiert([for (final p in portionen) p == alt ? neu : p]);
    final f = _mitListe(liste);
    return portion == alt ? f._kopie(portion: neu, mengeAusEintragG: null) : f;
  }

  /// Nimmt [p] heraus — aus [portionen] und, soweit gesetzt, aus den
  /// Portionen der Übernahme. War [p] gewählt, springt die Wahl auf „g"
  /// mit der aktuellen Menge (V11).
  BuchungsFormular ohnePortion(Portion p) {
    final liste = [
      for (final q in portionen)
        if (q != p) q,
    ];
    final f = portion == p ? waehleGramm() : this;
    return f._mitListe(liste);
  }

  /// Die Antwort von Open Food Facts ist da (V6). **Die Wahl bleibt** —
  /// wer schon 30 g getippt hat, behält 30 g.
  ///
  /// Bei einem gespeicherten Lebensmittel ersetzt sie [portionen] (die
  /// Liste kommt aus der Tabelle). Bei einem noch nicht übernommenen
  /// Treffer führt sie die im Blatt angelegten Portionen mit den
  /// abgerufenen zusammen, aufsteigend nach Menge, und setzt die
  /// Übernahme mit diesen Portionen und `fluessig`.
  ///
  /// `fluessig` wechselt nur von `false` auf `true`, nie zurück (V5, V6);
  /// die Zahl im Mengenfeld bleibt stehen. Das gilt auch für ein
  /// gespeichertes Lebensmittel, dessen Nachfrage `ml` ergab. *Vorgabe des
  /// Koordinators für den gespeicherten Fall, nicht Tims Entscheidung.*
  BuchungsFormular mitAbruf(AbrufFertig abruf) {
    final fl = fluessig || abruf.fluessig;
    final ueb = uebernahme;
    if (ueb == null) {
      return mitPortionen(abruf.portionen)._kopie(fluessig: fl);
    }
    final liste = _sortiert([
      for (final p in portionen)
        if (p.herkunft == Herkunft.eigen) p,
      ...abruf.portionen,
    ]);
    return mitPortionen(liste)._kopie(
      fluessig: fl,
      uebernahme: _vorlageMit(
        ueb,
        offPortionen: liste,
        fluessig: ueb.fluessig || abruf.fluessig,
      ),
    );
  }

  /// Was gebucht bzw. geschrieben wird.
  ///
  /// [Eintrag.id] ist [bearbeitetId] — beim neuen Blatt also `null`. Daran
  /// erkennt der Schreibweg, ob er anlegt oder ersetzt.
  ///
  /// Mit Portion geht der **Schnappschuss** mit: `portion_id`,
  /// `portion_name`, `portion_g` (Entscheidung 8). Mit „g" sind alle drei
  /// `null` (V12). Eine ungespeicherte Portion hat noch keine `id`.
  Eintrag alsEintrag() => Eintrag(
    id: bearbeitetId,
    tagesSchluessel: tagesSchluessel,
    mahlzeit: mahlzeit,
    zeitpunkt: zeitpunkt,
    lebensmittelId: lebensmittelId,
    name: name,
    mengeG: mengeG,
    naehrwerte: naehrwerte,
    healthUuid: healthUuid,
    healthStand: healthStand,
    portionId: portion?.id,
    portionName: portion?.name,
    portionG: portion?.mengeG,
    fluessig: _fluessigUnbekannt ? null : fluessig,
  );

  /// Setzt [portionen] und — nur wenn Open Food Facts schon geantwortet
  /// hat — die Portionen der Übernahme auf dieselbe Liste.
  BuchungsFormular _mitListe(List<Portion> liste) {
    final ueb = uebernahme;
    final offPortionen = ueb?.offPortionen;
    return _kopie(
      portionen: List.unmodifiable(liste),
      uebernahme: ueb == null || offPortionen == null
          ? ueb
          : _vorlageMit(ueb, offPortionen: List.unmodifiable(liste)),
    );
  }

  BuchungsFormular _kopie({
    Object? lebensmittelId = _bleibt,
    String? mengeText,
    Mahlzeit? mahlzeit,
    int? minutenSeitMitternacht,
    bool? fluessig,
    Object? uebernahme = _bleibt,
    List<Portion>? portionen,
    Object? portion = _bleibt,
    String? anzahlText,
    Object? mengeAusEintragG = _bleibt,
  }) => BuchungsFormular(
    lebensmittelId: identical(lebensmittelId, _bleibt)
        ? this.lebensmittelId
        : lebensmittelId as int?,
    name: name,
    je100g: je100g,
    tagesSchluessel: tagesSchluessel,
    mengeText: mengeText ?? this.mengeText,
    mahlzeit: mahlzeit ?? this.mahlzeit,
    minutenSeitMitternacht:
        minutenSeitMitternacht ?? this.minutenSeitMitternacht,
    grund: grund,
    fluessig: fluessig ?? this.fluessig,
    bearbeitetId: bearbeitetId,
    healthUuid: healthUuid,
    healthStand: healthStand,
    uebernahme: identical(uebernahme, _bleibt)
        ? this.uebernahme
        : uebernahme as LebensmittelVorlage?,
    portionen: portionen ?? this.portionen,
    portion: identical(portion, _bleibt) ? this.portion : portion as Portion?,
    anzahlText: anzahlText ?? this.anzahlText,
    mengeAusEintragG: identical(mengeAusEintragG, _bleibt)
        ? _mengeAusEintragG
        : mengeAusEintragG as double?,
    // Wer die Einheit wechselt, hat sie festgelegt — dann ist sie bekannt.
    fluessigUnbekannt:
        _fluessigUnbekannt && (fluessig == null || fluessig == this.fluessig),
    // Wer die Uhrzeit ändert, hat einen neuen Zeitpunkt gewählt.
    zeitpunktAusEintrag:
        minutenSeitMitternacht == null ||
            minutenSeitMitternacht == this.minutenSeitMitternacht
        ? _zeitpunktAusEintrag
        : null,
  );

  @override
  bool operator ==(Object other) =>
      other is BuchungsFormular &&
      other.lebensmittelId == lebensmittelId &&
      other.name == name &&
      other.je100g == je100g &&
      other.tagesSchluessel == tagesSchluessel &&
      other.mengeText == mengeText &&
      other.mahlzeit == mahlzeit &&
      other.minutenSeitMitternacht == minutenSeitMitternacht &&
      other.grund == grund &&
      other.fluessig == fluessig &&
      other.bearbeitetId == bearbeitetId &&
      other.healthUuid == healthUuid &&
      other.healthStand == healthStand &&
      other.uebernahme == uebernahme &&
      listEquals(other.portionen, portionen) &&
      other.portion == portion &&
      other.anzahlText == anzahlText &&
      other._mengeAusEintragG == _mengeAusEintragG &&
      other._fluessigUnbekannt == _fluessigUnbekannt &&
      other._zeitpunktAusEintrag == _zeitpunktAusEintrag;

  @override
  int get hashCode => Object.hash(
    lebensmittelId,
    name,
    je100g,
    tagesSchluessel,
    mengeText,
    mahlzeit,
    minutenSeitMitternacht,
    grund,
    fluessig,
    bearbeitetId,
    healthUuid,
    healthStand,
    uebernahme,
    Object.hashAll(portionen),
    portion,
    anzahlText,
    _mengeAusEintragG,
    _fluessigUnbekannt,
    _zeitpunktAusEintrag,
  );
}

/// Markiert in `_kopie` „unverändert" bei Feldern, die `null` werden
/// dürfen.
const _bleibt = Object();

/// Findet [gesucht] in [liste] wieder: über die `id`, bei einer
/// ungespeicherten Portion über Name und Menge.
Portion? _finde(List<Portion> liste, Portion gesucht) {
  for (final p in liste) {
    final passt = gesucht.id != null
        ? p.id == gesucht.id
        : p.name == gesucht.name && p.mengeG == gesucht.mengeG;
    if (passt) return p;
  }
  return null;
}

/// Aufsteigend nach Menge, **stabil**: Gleich große Portionen behalten
/// ihre Reihenfolge, wie in der Tabelle (`ORDER BY menge_g, id`).
/// `List.sort` verspricht das nicht.
List<Portion> _sortiert(List<Portion> liste) {
  final mitStelle = [for (var i = 0; i < liste.length; i++) (i, liste[i])];
  mitStelle.sort((a, b) {
    final n = a.$2.mengeG.compareTo(b.$2.mengeG);
    return n != 0 ? n : a.$1.compareTo(b.$1);
  });
  return List.unmodifiable([for (final (_, p) in mitStelle) p]);
}

/// Dieselbe Vorlage mit anderen Portionen bzw. anderem `fluessig`.
LebensmittelVorlage _vorlageMit(
  LebensmittelVorlage v, {
  required List<Portion> offPortionen,
  bool? fluessig,
}) => LebensmittelVorlage(
  id: v.id,
  name: v.name,
  je100g: v.je100g,
  fluessig: fluessig ?? v.fluessig,
  zuletztBenutzt: v.zuletztBenutzt,
  barcode: v.barcode,
  herkunft: v.herkunft,
  offPortionen: offPortionen,
  portionenAbgefragtAm: v.portionenAbgefragtAm,
);

/// Eine Menge als Feldtext mit **höchstens einer Nachkommastelle** und
/// ohne Tausenderpunkt — ein Punkt im Feld hieße für [liesZahl] Komma.
String _mengeAlsText(double menge) => _feldText(menge, 1);

/// Eine Anzahl als Feldtext mit höchstens zwei Nachkommastellen: „2",
/// „0,5", „3,33".
String _anzahlAlsText(double anzahl) => _feldText(anzahl, 2);

String _feldText(double wert, int stellen) {
  var t = wert.toStringAsFixed(stellen);
  if (t.contains('.')) {
    while (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  }
  return t.replaceAll('.', ',');
}

/// Was beim Buchen übernommen werden muss: eine Vorlage **ohne
/// Schlüssel, mit Herkunft `off` und mit Strichcode** — so, wie
/// `OffProdukt.alsVorlage` sie liefert. Alles andere steht schon in der
/// Tabelle oder ist ein Schnelleintrag.
LebensmittelVorlage? _zuUebernehmen(LebensmittelVorlage vorlage) =>
    vorlage.id == null &&
        vorlage.herkunft == Herkunft.off &&
        vorlage.barcode != null
    ? vorlage
    : null;

/// Die Vorgabemenge, **100 g und nicht 250 wie im Entwurfsbild**.
///
/// Die Nährwerte stehen je 100 g da; 100 ist die Menge, bei der die
/// gezeigten Zahlen genau die eingegebenen sind, und damit die einzige,
/// die nichts behauptet. Die 250 im Entwurf sind eine Beispielzahl — das
/// Board sagt das über alle seine Zahlen.
const _vorgabeMenge = '100';

/// Die Mahlzeit, die ein frisches Buchungsblatt vorwählt (V22): die
/// mitgegebene [mahlzeit], sonst die aus der Uhr ([jetzt], Berliner
/// Wanduhr) im Tag mit [grund] (`mahlzeitImTag`, Entscheidung 6) — im
/// verlängerten Tag um 05:10 also Abend, nicht Frühstück.
///
/// **Die eine Stelle dieser Regel.** [BuchungsFormular.neu] ruft sie, die
/// Foto-Schätzung auch, und wer außerhalb des Blatts zeigen will, welche
/// Mahlzeit es wählen würde (der Kopf der Erfassen-Seiten), ruft sie mit
/// demselben [grund] — sonst sagte der Kopf „Mittag", während das Blatt
/// auf „Frühstück" bucht.
Mahlzeit vorgewaehlteMahlzeit({
  required DateTime jetzt,
  Mahlzeit? mahlzeit,
  Tagesgrund grund = Tagesgrund.normal,
}) => mahlzeit ?? mahlzeitImTag(minuten: _wanduhrMinuten(jetzt), grund: grund);

/// Menge und Portion, die das Blatt beim Öffnen vorbelegt — ohne Blatt,
/// für die Trefferzeile der Suche (`vorwahl_text.dart`, V24).
///
/// **Dieselbe Rechnung wie [BuchungsFormular.neu] samt
/// [BuchungsFormular.mengeG]**, bis in die Rundung der Feldtexte: Eine
/// zuletzt gebuchte Menge von 80,25 g steht im Blatt als „80,3", und
/// gebucht werden 80,3 g. Wer die Menge hier anders rechnete, zeigte in der
/// Zeile eine Menge, die „+" nicht bucht.
///
/// [portionen] ist die Liste, die das Blatt bekäme. Eine vorgewählte
/// Portion, die dort fehlt, fällt auf 100 g zurück — wie im Blatt.
({double? mengeG, Portion? portion}) vorgewaehlteMenge({
  PortionsVorwahl? vorwahl,
  List<Portion> portionen = const [],
}) {
  final (:mengeText, :portion, :anzahlText) = _vorbelegung(vorwahl, portionen);
  return (
    mengeG: _mengeAus(
      mengeText: mengeText,
      portion: portion,
      anzahlText: anzahlText,
    ),
    portion: portion,
  );
}

/// Die Feldtexte eines frischen Blatts aus der Vorwahl: „g" samt Menge
/// oder eine Portion aus [liste] samt Anzahl. Ohne Vorwahl, oder wenn die
/// vorgewählte Portion nicht in [liste] steht, „g" mit 100.
({String mengeText, Portion? portion, String anzahlText}) _vorbelegung(
  PortionsVorwahl? vorwahl,
  List<Portion> liste,
) {
  switch (vorwahl) {
    case VorwahlGramm(:final menge):
      return (mengeText: _mengeAlsText(menge), portion: null, anzahlText: '1');
    case VorwahlPortion(:final portionId, :final anzahl):
      for (final p in liste) {
        if (p.id == portionId) {
          return (
            mengeText: _vorgabeMenge,
            portion: p,
            anzahlText: _anzahlAlsText(anzahl),
          );
        }
      }
    case null:
      break;
  }
  return (mengeText: _vorgabeMenge, portion: null, anzahlText: '1');
}

/// Die Menge aus den Feldtexten — mit Portion `Anzahl × Portionsgramm`,
/// sonst das Mengenfeld. [unveraendertG] sind die genauen Gramm eines
/// unverändert geöffneten Eintrags ([BuchungsFormular.fuer]).
double? _mengeAus({
  required String mengeText,
  required Portion? portion,
  required String anzahlText,
  double? unveraendertG,
}) {
  if (portion == null) return liesZahl(mengeText).wert;
  if (unveraendertG != null) return unveraendertG;
  final a = liesZahl(anzahlText).wert;
  return a == null ? null : a * portion.mengeG;
}

/// Die Minuten seit Mitternacht eines Zeitpunkts — über die **Berliner
/// Wanduhr**, nicht über UTC: 22:30 UTC ist im Juli in Berlin schon 00:30
/// und gehört zum Abend davor.
int _wanduhrMinuten(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  return stunde * Duration.minutesPerHour + minute;
}

/// Die eingefrorenen Nährwerte eines Eintrags zurück auf 100 g gerechnet.
///
/// `fuerMenge(g)` streckt um `g / 100`; gesucht ist der Faktor
/// `100 / menge`, also `fuerMenge(10000 / menge)`.
///
/// Ohne gewogene Menge (Schnelleintrag) gibt es nichts zurückzurechnen —
/// dann stehen die absoluten Werte da, und das Mengenfeld bleibt leer.
Naehrwerte _zurueckGerechnet(Eintrag eintrag) {
  final menge = eintrag.mengeG;
  if (menge == null || menge <= 0) return eintrag.naehrwerte;
  return eintrag.naehrwerte.fuerMenge(10000 / menge);
}

/// Eine Menge als Feldtext — deutsche Schreibweise, ohne nachgehängte
/// Null bei glatten Zahlen.
String _alsText(double? menge) {
  if (menge == null) return '';
  if (menge == menge.roundToDouble()) return menge.toStringAsFixed(0);
  return menge.toString().replaceAll('.', ',');
}
