// Die gemeinsamen Bausteine der drei Messwert-Schirme — `koerper` (#82),
// `messungen` (#85) und `messung-detail` (#203). Sie zeigen dieselben vier
// Messwerte in drei Anordnungen, also stehen Lagen, Zeilen, Notizflächen
// und die Schreibweise der Zahlen **einmal** hier und nicht dreimal in den
// Schirmen (Vorbild: `erholung_abschnitte.dart`).
//
// Die Abschnitte, die nur **ein** Schirm hat, stehen daneben:
// `koerper_abschnitte.dart` trägt Kopfkarte, Kacheln und Bereiche von
// `koerper`.
//
// Aufbau und Beschriftung nach den am 02.11.2026 von Tim freigegebenen
// Entwürfen `docs/screens/screens/koerper.js`, `messungen.js` und
// `messung-detail.js` sowie
// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
// Teil D.
//
// **Hier stehen die Nutzertexte, nicht im Zustand.** `koerper_zustand.dart`
// und `messung_detail_zustand.dart` liefern Zahlen, Tagesschlüssel und
// Enums; „zuletzt am 11.10." und die vier Trendsätze entstehen erst hier
// (`CLAUDE.md`, „Deutsch in der Oberfläche, Englisch im Code").
import 'package:flutter/cupertino.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import '../health/health_types.dart';

/// Das Zeichen für einen fehlenden Einzelwert in einer Zeile — wie in
/// `verlauf_view.dart`. **Nie `0`:** Eine Null behauptet eine Messung, die
/// es nicht gab (`CLAUDE.md`, Fehler `01`).
const String ohneEinzelwert = '—';

/// In welcher der vier Lagen ein Schirm gerade steht.
///
/// Eine Umsetzung von [Messwert] in das, was die Oberfläche unterscheiden
/// muss — und zwar an **einer** Stelle für drei Schirme. Käme ein fünfter
/// `Messwert`-Zustand, zeigte der Analyzer auf [messLageAus]; käme eine
/// fünfte Lage, auf jeden `switch` darüber.
enum MessLage {
  /// [NochNie] — noch kein Lauf, noch kein Cache-Treffer. Hier steht
  /// **nie** ein „keine Daten"-Grund (Fehler `01`), sondern die graue
  /// Fläche.
  laedt,

  /// [Bekannt] — es liegen Zahlen vor. Dass einzelne davon fehlen, ist
  /// keine andere Lage: Ein Schirm, der drei Werte hat und wegen des
  /// vierten „keine Daten" sagt, wäre Fehler `01`.
  werte,

  /// [LeerNachLauf] — der Lauf ist fertig und hat nichts gefunden. Der
  /// einzige Zustand neben einer fehlenden Wägung in [werte], der einen
  /// Grund anzeigen darf.
  leer,

  /// [Fehlgeschlagen] — und das ist **keine** Aussage über die Datenlage.
  fehler,
}

/// Die Lage eines Messwerts, vollständig über den sealed-Typ.
MessLage messLageAus<T>(Messwert<T> messwert) => switch (messwert) {
  NochNie<T>() => MessLage.laedt,
  Bekannt<T>() => MessLage.werte,
  LeerNachLauf<T>() => MessLage.leer,
  Fehlgeschlagen<T>() => MessLage.fehler,
};

/// Der Zeitpunkt, den eine Lage zu nennen hat — `null` bei [MessLage.laedt],
/// weil es dort noch keinen gibt.
DateTime? standAus<T>(Messwert<T> messwert) => switch (messwert) {
  NochNie<T>() => null,
  Bekannt<T>(:final stand) => stand,
  LeerNachLauf<T>(:final gelaufen) => gelaufen,
  Fehlgeschlagen<T>(:final gelaufen) => gelaufen,
};

// ─────────────────────────────────────────────────────────────────────────
// Die Zeile unter der Überschrift
// ─────────────────────────────────────────────────────────────────────────

/// Eine Zeile, die in **jeder** Lage dasteht und nur ihren Text wechselt —
/// „Stand 14:32 · wird aktualisiert" mit Werten, der Ladehinweis davor, der
/// Fehlersatz daneben.
///
/// Sie ist bewusst immer da: Eine Zeile, die nur beim Laden erscheint,
/// schiebt beim Verschwinden den ganzen Schirm nach oben — genau der
/// Sprung, gegen den „Eine Anzeige, die es gibt, hat genau eine Form"
/// gebaut ist. Den Schlüssel (`…-laden` bzw. `…-fehler`) setzt der Schirm
/// von außen, weil er sein eigenes Präfix kennt.
///
/// **Im Ladezustand steht hier kein Grund.** „Die Werte werden gelesen …"
/// ist eine Auskunft über den Lauf, keine über die Daten (Fehler `01`).
class LageZeile extends StatelessWidget {
  const LageZeile({
    super.key,
    required this.lage,
    required this.stand,
    required this.laeuft,
  });

  final MessLage lage;
  final DateTime? stand;

  /// Ob gerade nachgeladen wird — nur in [MessLage.werte] von Belang.
  final bool laeuft;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final zeitpunkt = stand;

    final text = switch (lage) {
      MessLage.laedt => 'Die Werte werden gelesen …',
      MessLage.werte =>
        zeitpunkt == null
            ? ''
            : laeuft
            ? 'Stand ${Format.uhrzeit(zeitpunkt)} · wird aktualisiert'
            : 'Stand ${Format.uhrzeit(zeitpunkt)}',
      MessLage.leer => 'Keine Werte von Waage oder Uhr',
      MessLage.fehler => 'Die Werte konnten gerade nicht geladen werden.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Text(text, style: TextStyle(fontSize: 13, color: muted)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Zeilen und Karten
// ─────────────────────────────────────────────────────────────────────────

/// Eine Zeile einer Werteliste — `statRow` aus
/// `docs/screens/components.js`: links der Name, rechts der Wert.
@immutable
class MessZeileDaten {
  const MessZeileDaten({
    required this.name,
    this.wert,
    this.schluessel,
    this.wertSchluessel,
    this.wertFarbe,
    this.platzhalter,
    this.namePlatzhalter,
    this.kennzeichen,
    this.aufTippen,
  });

  final Key? schluessel;

  /// Der Schlüssel **auf dem Wert allein**, nicht auf der Zeile.
  ///
  /// Für Zeilen, deren Wert sich einfärbt (`umfang-detail-trend`): Ein
  /// Schlüssel auf der ganzen Zeile ließe „die Taille ist grün, wenn sie
  /// fällt" nicht aussprechen, ohne über die Farbe der Beschriftung
  /// mitzuentscheiden.
  final Key? wertSchluessel;

  /// Die Farbe des Werts; ohne Angabe die graue Vorgabe.
  ///
  /// **Ein Vorzeichen allein färbt nichts ein** — ob eine Bewegung in die
  /// gewollte Richtung geht, entscheidet der Aufrufer, nicht diese Zeile.
  final Color? wertFarbe;

  final String name;

  /// Ein kleines Kennzeichen zwischen Name und Wert — „manuell" in „Letzte
  /// Messungen" (#270, `statRow(…, tag)` im Entwurf). Es beantwortet die
  /// Frage, die eine von Hand eingetragene Zeile sonst offenlässt: warum an
  /// diesem Tag keine weiteren Werte stehen.
  final String? kennzeichen;

  /// Macht die Zeile zur Tür. **Der Winkel folgt der Tür**: Er erscheint
  /// genau dann, wenn eine da ist. In „Letzte Messungen" haben das nur die
  /// eigenen Einträge — was von der Waage kommt, kann die App weder ändern
  /// noch löschen.
  final VoidCallback? aufTippen;

  /// `null` heißt „kein Wert": Steht ein [platzhalter] dabei, kommt die
  /// graue Fläche, sonst [ohneEinzelwert]. **Nie `0`.**
  final String? wert;

  /// Beispieltext für die graue Fläche des Werts (#24) — nur im
  /// Ladezustand gesetzt.
  final String? platzhalter;

  /// Dasselbe für den Namen. Im Ladezustand ist auch er noch unbekannt:
  /// Die Zeilen von „Letzte Messungen" tragen Datumsangaben, die erst mit
  /// den Werten dazukommen.
  final String? namePlatzhalter;
}

/// Eine [InsetCard] mit Zeilen und Trennlinien dazwischen — dieselbe Form
/// wie `_Einordnung` in `verlauf_view.dart`.
class MessKarte extends StatelessWidget {
  const MessKarte({super.key, required this.zeilen, this.huelle});

  final List<MessZeileDaten> zeilen;

  /// Umhüllt eine gebaute Zeile — etwa mit einer Wischgeste (#486, der
  /// Maß-Verlauf). Ohne Angabe steht die Zeile, wie sie ist. **Die
  /// Geometrie der Karte bleibt dieselbe:** Die Hülle legt sich um die
  /// Zeile, sie baut keine zweite Karte — sonst gäbe es die Kartenform
  /// zweimal, und die nächste Änderung träfe nur eine.
  final Widget Function(int index, Widget zeile)? huelle;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Über den Index, nicht über `zeile != zeilen.first`: Zwei
            // gleich gebaute `const`-Zeilen (drei graue Flächen im
            // Ladezustand) sind einander gleich, und dann fiele jede
            // Trennlinie weg.
            for (var i = 0; i < zeilen.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Container(height: 1, color: line),
                ),
              if (huelle case final huelle?)
                huelle(i, MessZeile(key: zeilen[i].schluessel, daten: zeilen[i]))
              else
                MessZeile(key: zeilen[i].schluessel, daten: zeilen[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Eine einzelne Zeile. Name und Wert stehen auf derselben Grundlinie, der
/// Platzhalter nimmt denselben Platz ein wie der Wert, der ihn ablöst.
class MessZeile extends StatelessWidget {
  const MessZeile({super.key, required this.daten});

  final MessZeileDaten daten;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final nameStil = TextStyle(fontSize: 15, color: ink);
    final wertStil = TextStyle(fontSize: 15, color: muted);

    final namePlatzhalter = daten.namePlatzhalter;
    final wertPlatzhalter = daten.platzhalter;

    final zeile = Semantics(
      // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
      label: _vorlesetext(daten),
      button: daten.aufTippen != null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: namePlatzhalter == null
                  ? Text(daten.name, style: nameStil)
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Platzhalter(
                        beispiel: namePlatzhalter,
                        stil: nameStil,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (daten.kennzeichen != null) ...[
              _Kennzeichen(daten.kennzeichen!),
              const SizedBox(width: 8),
            ],
            if (daten.wert == null && wertPlatzhalter != null)
              Platzhalter(
                key: daten.wertSchluessel,
                beispiel: wertPlatzhalter,
                stil: wertStil,
              )
            else
              Text(
                daten.wert ?? ohneEinzelwert,
                key: daten.wertSchluessel,
                style: daten.wertFarbe == null
                    ? wertStil
                    : wertStil.copyWith(color: daten.wertFarbe),
              ),
            if (daten.aufTippen != null) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 13, color: muted),
            ],
          ],
        ),
      ),
    );

    final aufTippen = daten.aufTippen;
    if (aufTippen == null) return zeile;
    return GestureDetector(
      // `opaque`, damit auch der leere Platz zwischen Name und Wert trifft —
      // eine Zeile, die nur auf dem Text reagiert, fühlt sich kaputt an.
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: zeile,
    );
  }

  String _vorlesetext(MessZeileDaten daten) {
    final zusatz = daten.kennzeichen == null ? '' : ', ${daten.kennzeichen}';
    if (daten.namePlatzhalter != null) return 'wird geladen';
    if (daten.wert == null) {
      return daten.platzhalter == null
          ? '${daten.name}$zusatz, kein Wert'
          : '${daten.name}, wird geladen';
    }
    return '${daten.name}$zusatz, ${daten.wert}';
  }
}

/// Die Fläche mit farbiger Kante aus dem Entwurf (`noteBox`).
///
/// **Erst die Kante, dann der Schnitt auf der ganzen Karte**
/// (`CLAUDE.md`): [InsetCard] legt außen ein `ClipRRect`, der 4 Punkt
/// breite Balken läuft deshalb nicht über die runde Ecke hinaus.
///
/// [zeilen] reserviert die Höhe fest (#24) — **nötig, wo derselbe Kasten
/// seinen Text wechselt**, etwa der Einordnungssatz auf `messungen`
/// (Trendsatz oder „zu wenige Wägungen"). Wo der Text feststeht, wie beim
/// Erklärsatz, bleibt es `null`: Eine Zeilenzahl, die nichts stillhält,
/// schneidet nur Text ab.
class Notizflaeche extends StatelessWidget {
  const Notizflaeche({
    super.key,
    required this.text,
    this.zeilen,
    this.oben = 14,
    this.ton = Palette.bib,
    this.platzhalter = false,
  });

  final String text;
  final int? zeilen;
  final double oben;

  /// Steht hier (noch) kein Satz, treten graue Balken an seine Stelle,
  /// statt die Karte leer zu lassen.
  ///
  /// Eine leere Fläche mit farbiger Kante sagt gar nichts — sie sieht aus
  /// wie ein Fehler im Aufbau, nicht wie „hier kommt gleich ein Satz".
  /// Aufgefallen bei der Handprüfung im Simulator am 02.11.2026, im
  /// Fehlerzustand von `messungen`. Die Höhe ändert sich dabei nicht:
  /// Sie kommt in beiden Fällen aus [zeilen].
  final bool platzhalter;

  /// Die Farbe der Kante — `NOTE_TONE` im Entwurfsboard: `bib` für
  /// `neutral`, `ok` für `good`, `warn` für `warning`.
  final CupertinoDynamicColor ton;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kante = CupertinoDynamicColor.resolve(ton, context);
    final stil = TextStyle(fontSize: 13, height: 1.4, color: muted);
    final zeilen = this.zeilen;

    Widget inhalt = platzhalter
        // Zwei Balken statt drei: Ein voller Block grauer Zeilen sähe aus
        // wie Text, der nicht lädt. Zwei sagen „hier steht ein Satz".
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Platzhalter(beispiel: 'Ein Satz über die Einordnung', stil: stil),
              const SizedBox(height: 6),
              Platzhalter(beispiel: 'der Werte, kurz gehalten', stil: stil),
            ],
          )
        : Text(
            text,
            maxLines: zeilen,
            overflow: zeilen == null
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
            style: stil,
          );
    if (zeilen != null) {
      inhalt = FesteZeilen(zeilen: zeilen, stil: stil, child: inhalt);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, oben, 20, 0),
      child: InsetCard(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(padding: const EdgeInsets.all(13), child: inhalt),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Nutzertexte
// ─────────────────────────────────────────────────────────────────────────

/// Der Name eines Messwerts, wie er im Entwurf steht.
String messName(MessArt art) => switch (art) {
  MessArt.gewicht => 'Gewicht',
  MessArt.koerperfett => 'Körperfett',
  // „Muskel / fettfreie Masse" — der Entwurf nennt beides, weil die Waage
  // das eine misst und das andere behauptet (`messungen.js`).
  MessArt.fettfreieMasse => 'Muskel / fettfreie Masse',
  MessArt.ruhepuls => 'Ruhepuls',
};

/// Die Einheit hinter der Zahl.
String messEinheit(MessArt art) => switch (art) {
  MessArt.gewicht || MessArt.fettfreieMasse => 'kg',
  MessArt.koerperfett => '%',
  MessArt.ruhepuls => 'bpm',
};

/// Die Zahl allein, in der Schreibweise dieses Werts: eine
/// Nachkommastelle, beim Ruhepuls keine — ein halber Herzschlag ist keine
/// Auskunft.
String messZahl(MessArt art, double wert) => switch (art) {
  MessArt.ruhepuls => formatNumber(wert),
  _ => formatNumber(wert, nachkommastellen: 1),
};

/// Zahl und Einheit. `null` wird **nie** zu `0` — ein fehlender Wert heißt
/// [ohneEinzelwert].
String messWert(MessArt art, double? wert) => wert == null
    ? ohneEinzelwert
    : '${messZahl(art, wert)} ${messEinheit(art)}';

/// Ein Beispieltext für die graue Fläche, aus dem Breite und Höhe
/// entstehen (#24) — in der Stellenzahl des echten Werts.
String messBeispiel(MessArt art) => switch (art) {
  MessArt.ruhepuls => '00',
  _ => '00,0',
};

/// „+0,16" bzw. „−1,10" — mit Vorzeichen, auch beim Plus, und mit dem
/// echten Minuszeichen statt des Bindestrichs.
String mitVorzeichen(double wert, {int nachkommastellen = 1}) {
  final zahl = formatNumber(wert, nachkommastellen: nachkommastellen);
  if (zahl.startsWith('-')) return '−${zahl.substring(1)}';
  return '+$zahl';
}

/// „+0,16 kg pro Woche" — die Steigung der Gewichtsreihe.
///
/// Zwei Nachkommastellen wie in `MeasurementsView.swift:165`: Bei einer
/// stünde „+0,2 kg pro Woche" für alles zwischen 0,15 und 0,25, und der
/// Zielkorridor endet bei 0,25.
String gewichtsTrendText(double proWoche) =>
    '${mitVorzeichen(proWoche, nachkommastellen: 2)} kg pro Woche';

/// Die Veränderung über sechs Wochen — „−1,1 % in 6 Wochen".
String veraenderungText(MessArt art, double veraenderung) =>
    '${mitVorzeichen(veraenderung)} ${messEinheit(art)} in 6 Wochen';

/// Was dasteht, wo ein Wert fehlt — je Lage.
///
/// **Im Ladezustand nichts**, denn dort gibt es keinen Grund zu nennen
/// (Fehler `01`), und bei einem Fehler auch nichts: Er ist keine Aussage
/// über die Datenlage.
String ohneWertZusatz(MessLage lage, {required String grund}) => switch (lage) {
  MessLage.laedt || MessLage.fehler => '',
  MessLage.werte || MessLage.leer => grund,
};

/// „Keine Waagenwerte in Apple Health" (`koerper.js`, `messungen.js`).
const String keineWaagenwerte = 'Keine Waagenwerte in Apple Health';

/// Der Grund, **einmal** je Schirm: Apple verrät den Lesestatus nicht,
/// also stehen beide Möglichkeiten da (`CLAUDE.md`).
const String waagenGrund =
    'Noch keine Waagenwerte. Die App liest sie aus Apple Health; dorthin '
    'schreibt die Waagen-App. Fehlen sie trotzdem, kann es auch an der '
    'Freigabe liegen — Apple verrät den Unterschied nicht.';

/// Die Fußnote der drei Schirme. Sie nennt die Herkunft und kennzeichnet
/// jeden Wert als Schätzung — **keine Diagnose** (`CLAUDE.md`).
const String messungenFuss =
    'Gewicht, Körperfett und fettfreie Masse kommen von der Waage über '
    'Apple Health, der Ruhepuls von der Uhr. Alles Schätzungen, keine '
    'medizinische Bewertung.';

/// Eine Zeile, deren Wert im Ladezustand zur grauen Fläche wird und sonst
/// den Text trägt — die eine Stelle, an der „laden" und „Wert" einander
/// ablösen.
///
/// Zeilen ohne Datenbezug (der Zielkorridor, „kein Maßband-Wert") gehen
/// **nicht** hier durch: Sie stehen in jeder Lage gleich da, eine graue
/// Fläche an ihrer Stelle behauptete einen Wert, der nie kommt.
MessZeileDaten zeileMitLage(
  MessLage lage, {
  Key? schluessel,
  required String name,
  required String wert,
  required String beispiel,
}) => MessZeileDaten(
  schluessel: schluessel,
  name: name,
  wert: lage == MessLage.laedt ? null : wert,
  platzhalter: lage == MessLage.laedt ? beispiel : null,
);

/// Der Tagesschlüssel (`2026-10-12`) als reines Datum zum **Anzeigen**.
///
/// Nicht `datumAusTag` allein: Das liefert den UTC-Zeitpunkt der Berliner
/// Mitternacht (im Sommer 22:00 des Vortags) — formatiert stünde dort der
/// falsche Tag. Alles, was ein Datum anzeigt, geht durch `kalendertag`
/// (siehe dessen Kommentar in `design/formatierung.dart`).
DateTime datumZumAnzeigen(String tag) => kalendertag(datumAusTag(tag));

/// Das kleine Kennzeichen „manuell" — `.statrow .tag` im Entwurf.
class _Kennzeichen extends StatelessWidget {
  const _Kennzeichen(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: muted,
        ),
      ),
    );
  }
}
