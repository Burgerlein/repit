// Die Verlaufsseiten (#94) — **ein** Schirm für vier Werte (Schlaf, HRV,
// Ruhepuls, Atemfrequenz); welcher gemeint ist, trägt `VerlaufArt` als
// Parameter. Der Zustand darunter liegt in `verlauf_zustand.dart`.
//
// API und Verhalten sind durch `app/test/shell/verlauf_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/verlauf.js`: Diagramm, „Einordnung",
// Erklärsatz, Fußnote. **Der Erklärsatz ist der eigentliche Inhalt** — die
// Kurve zeigt, *dass* sich etwas bewegt, der Satz sagt, *was das bedeutet*
// (`verlauf.js:9–11`). Die vier Sätze stehen wörtlich in
// `TrendDetailView.swift:41–59`.
//
// **Die Tür hängt seit dem 28.10.2026:** Jede Verlaufszeile des
// Erholung-Schirms führt auf den Verlauf *ihres* Wertes, über
// [oeffneVerlauf]. Welche Zeile überhaupt eine Tür ist, entscheidet
// `verlaufArtZu` in `verlauf_zustand.dart` — die Alkohol-Zeile bekommt
// `null` und bleibt stumm, bis #119 die Eingabe baut.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/messwert.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/zeitdiagramm.dart';
import 'diagramm_zeitraum.dart';
import 'erholung_abschnitte.dart' show kommazahl, stundenText;
import 'router.dart';
import 'verlauf_zustand.dart';
import 'ziele.dart';

/// Öffnet den Verlauf einer Art auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Ein Schirm, der im Menü unter
/// einem bestimmten Tab einsortiert ist, wechselt trotzdem nie dorthin,
/// sonst führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat
/// (`CLAUDE.md`).
void oeffneVerlauf(AppRouter router, VerlaufArt art) =>
    router.open(AppTarget.aktuell((context) => VerlaufSeite(art: art)));

/// Der Rahmen: Gerüst und Navigationsleiste um [VerlaufView].
///
/// Den stellt der Gastgeber, nicht der Schirm. **Kein eigener `Navigator`:**
/// Diese Ansicht wird auf den Stapel eines Tabs geschoben, der Stapel
/// gehört weiter `RootView`.
class VerlaufSeite extends StatelessWidget {
  const VerlaufSeite({super.key, required this.art});

  final VerlaufArt art;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(middle: Text(_name(art))),
      child: VerlaufView(art: art),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([verlaufProvider]): Jeder Schirm ist
/// aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass eine
/// Übersicht vorher geladen hat.
class VerlaufView extends ConsumerWidget {
  const VerlaufView({super.key, required this.art});

  final VerlaufArt art;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(verlaufProvider(art));

    // Der `switch` über den sealed-Typ ist vollständig: Käme ein fünfter
    // Zustand, zeigte der Analyzer genau hierhin.
    final List<Widget> inhalt = switch (zustand.daten) {
      NochNie<VerlaufDaten>() => const [_Laden(key: Key('verlauf-laden'))],
      LeerNachLauf<VerlaufDaten>() => [
        _Leer(art: art, key: const Key('verlauf-leer')),
      ],
      Fehlgeschlagen<VerlaufDaten>() => const [
        _Fehler(key: Key('verlauf-fehler')),
      ],
      // **Eine leere Reihe ist kein Leerzustand.** Der Lauf hat etwas
      // geliefert, nur für diesen einen Wert nichts — der Satz hängt an
      // der leeren Reihe, nicht am Zustand.
      Bekannt<VerlaufDaten>(:final wert) =>
        wert.reihe.isEmpty
            ? [_Leer(art: art, key: const Key('verlauf-leer'))]
            : _verlauf(art, wert),
    };

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: inhalt,
      ),
    );
  }

  /// Diagramm, Einordnung, Erklärsatz, Fußnote — die Reihenfolge des
  /// Entwurfs (`verlauf.js`, `SCREEN`).
  List<Widget> _verlauf(VerlaufArt art, VerlaufDaten daten) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Zeitdiagramm(
        reihe: daten.reihe,
        stufen: verlaufsStufen,
        alsBalken: alsBalken(art),
        einheit: _einheit(art),
        einheitAbgelesen: _einheitAbgelesen(art),
        linien: _linien(daten),
        fussnote: (stufe) => _fussnote(art, stufe),
      ),
    ),
    const SectionHeader('Einordnung'),
    _Einordnung(key: const Key('verlauf-einordnung'), daten: daten),
    _Erklaerung(key: const Key('verlauf-erklaerung'), art: art),
    const Hinweisfuss(
      'Alle Werte stammen aus Apple Health und sind Schätzungen, keine '
      'medizinische Bewertung.',
    ),
  ];
}

/// Median und Schwelle als waagerechte Linien — **nur, wenn es sie gibt.**
/// Eine Linie auf einer erfundenen Zahl wäre schlimmer als keine.
List<Ziellinie> _linien(VerlaufDaten daten) => [
  if (daten.median case final median?)
    Ziellinie(
      name: 'Normal',
      wert: median,
      // **Der Name trägt den Wert** (#178, `lineChart` im Entwurfsboard).
      // Hier liegen zwei Linien in derselben Einheit dicht beieinander —
      // beim Schlaf Median 6:41 h und feste Grenze 6:00 h, elf Punkt auf
      // einer 120 Punkt hohen Fläche. Ohne die Zahl sind „Normal" und
      // „Warnsignal" zwei gestrichelte Striche, bei denen man raten muss.
      // Geschrieben wie überall sonst auf diesem Schirm, nicht zweimal
      // gerechnet.
      wertText: _wert(daten.art, median),
      farbe: Palette.muted,
    ),
  if (daten.signalAb case final schwelle?)
    Ziellinie(
      name: 'Warnsignal',
      wert: schwelle,
      wertText: _wert(daten.art, schwelle),
      farbe: Palette.warn,
    ),
];

// ─────────────────────────────────────────────────────────────────────────
// Die Abschnitte
// ─────────────────────────────────────────────────────────────────────────

/// Die vier Zeilen des Entwurfs: Aktuell · Median 30 Tage · Signal ab ·
/// Spanne 7 Tage (`verlauf.js`, `werte`).
///
/// Der aktuelle Wert steht **hier** als eigene Zeile und nicht in der
/// Kopfzeile des Diagramms: Die zeigt den Fensterschnitt, wie auf jedem
/// anderen Schirm auch (`TrendDetailView.swift:100–103`). Beides in der
/// großen Zeile ginge nicht; dann wäre sie keine Kopfzeile mehr.
class _Einordnung extends StatelessWidget {
  const _Einordnung({super.key, required this.daten});

  final VerlaufDaten daten;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final art = daten.art;

    final zeilen = <({Key? schluessel, String name, String wert})>[
      (
        schluessel: const Key('verlauf-aktuell'),
        name: 'Aktuell',
        wert: _wert(art, daten.aktuell),
      ),
      (
        schluessel: null,
        name: 'Median 30 Tage',
        wert: _wert(art, daten.median),
      ),
      (schluessel: null, name: 'Signal ab', wert: _schwellentext(art, daten)),
      (schluessel: null, name: 'Spanne 7 Tage', wert: _spannentext(art, daten)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final zeile in zeilen) ...[
              if (zeile != zeilen.first)
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Container(height: 1, color: line),
                ),
              _Zeile(key: zeile.schluessel, name: zeile.name, wert: zeile.wert),
            ],
          ],
        ),
      ),
    );
  }
}

/// `statRow` aus `docs/screens/components.js`: links der Name, rechts der
/// Wert.
class _Zeile extends StatelessWidget {
  const _Zeile({super.key, required this.name, required this.wert});

  final String name;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 15, color: ink)),
          ),
          const SizedBox(width: 8),
          Text(wert, style: TextStyle(fontSize: 15, color: muted)),
        ],
      ),
    );
  }
}

/// Der Erklärsatz, in der Fläche mit farbiger Kante (`noteBox('neutral')`).
///
/// **Erst die Kante, dann der Schnitt auf der ganzen Karte** (`CLAUDE.md`):
/// [InsetCard] legt außen ein `ClipRRect`, der 4 Punkt breite Balken läuft
/// deshalb nicht über die runde Ecke hinaus.
class _Erklaerung extends StatelessWidget {
  const _Erklaerung({super.key, required this.art});

  final VerlaufArt art;

  @override
  Widget build(BuildContext context) =>
      _Notiz(text: _erklaerung(art), oben: 16);
}

/// „Keine Werte" — **beide Möglichkeiten**, und nie eine Null.
///
/// Apple verrät den Lesestatus nicht, also sind „nichts aufgezeichnet" und
/// „nicht freigegeben" nicht unterscheidbar; beides muss dastehen
/// (`CLAUDE.md`). Der Satz nennt außerdem, um **welchen** Wert es geht —
/// vier Schirme mit demselben Satz sagen nicht, welcher von ihnen leer ist.
///
/// Kein Diagramm daneben: Eine leere Fläche mit Achsen behauptet, es gäbe
/// eine Kurve.
class _Leer extends StatelessWidget {
  const _Leer({super.key, required this.art});

  final VerlaufArt art;

  @override
  Widget build(BuildContext context) => _Notiz(
    text:
        'Für ${_name(art)} liegen keine Werte vor. Entweder hat die Uhr '
        'nichts aufgezeichnet oder die App darf den Wert nicht lesen — '
        'Apple verrät den Unterschied nicht.',
    oben: 14,
  );
}

/// Während des Ladens steht nirgends ein „keine Daten"-Grund
/// (`docs/todo/01`).
class _Laden extends StatelessWidget {
  const _Laden({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        'Die Werte werden gelesen …',
        style: TextStyle(fontSize: 13, color: muted),
      ),
    );
  }
}

/// **Ein Fehler ist keine Aussage über die Datenlage.** Der Satz sagt
/// deshalb nicht, dass nichts vorliegt.
class _Fehler extends StatelessWidget {
  const _Fehler({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Text(
        'Die Werte konnten nicht gelesen werden. Das sagt nichts darüber, '
        'ob welche vorliegen — es hat nur gerade nicht geklappt. Später '
        'noch einmal versuchen.',
        style: TextStyle(fontSize: 13, height: 1.4, color: muted),
      ),
    );
  }
}

/// Die Fläche mit farbiger Kante aus dem Entwurf (`noteBox`), Ton
/// `neutral`.
class _Notiz extends StatelessWidget {
  const _Notiz({required this.text, required this.oben});

  final String text;
  final double oben;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kante = CupertinoDynamicColor.resolve(Palette.bib, context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, oben, 20, 0),
      child: InsetCard(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.4, color: muted),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Nutzertexte
// ─────────────────────────────────────────────────────────────────────────

/// Der Name des Werts — Überschrift der Leiste und Teil des Leersatzes.
String _name(VerlaufArt art) => switch (art) {
  VerlaufArt.schlaf => 'Schlaf',
  VerlaufArt.hrv => 'HRV',
  VerlaufArt.ruhepuls => 'Ruhepuls',
  VerlaufArt.atemfrequenz => 'Atemfrequenz',
};

/// Die vier Sätze, wörtlich aus `TrendDetailView.swift:41–59`.
///
/// **Beim Schlaf trägt der Satz eine Regel**, keinen Wortlaut: Die
/// Schwelle liegt fest bei sechs Stunden und hängt **nicht** am Schlafziel
/// (`docs/SPEC.md` 4.6). Wer das wegkürzt, lädt die Verwechslung ein.
String _erklaerung(VerlaufArt art) => switch (art) {
  VerlaufArt.schlaf =>
    'Gezählt wird die Zeit ohne Wachphasen, nicht die Zeit im Bett. Die '
        'Schwelle der Ampel liegt fest bei sechs Stunden und hängt nicht am '
        'Schlafziel.',
  VerlaufArt.hrv =>
    'Herzfrequenzvariabilität: der Abstand zwischen zwei Herzschlägen ist '
        'nie exakt gleich, und diese Schwankung misst die Uhr vor allem '
        'nachts. Viel Schwankung heißt meist erholt, wenig heißt, der Körper '
        'arbeitet noch. Absolute Zahlen taugen nicht zum Vergleich mit '
        'anderen — nur dein eigener Normalwert zählt.',
  VerlaufArt.ruhepuls =>
    'Der tiefste Puls in Ruhe, meist nachts gemessen. Er sinkt mit besserer '
        'Ausdauer. Mehrere Tage deutlich über dem Normalwert heißen oft: zu '
        'wenig Erholung oder ein beginnender Infekt.',
  VerlaufArt.atemfrequenz =>
    'Atemzüge pro Minute im Schlaf. Sie ist von Nacht zu Nacht erstaunlich '
        'stabil; steigt sie über mehrere Nächte, ist das eines der vier '
        'Warnsignale.',
};

/// Die Fußzeile unter dem Diagramm. Ab `6M` trägt ein Punkt einen ganzen
/// Monat — das muss dastehen, sonst liest man einen Monatsschnitt als
/// Tageswert (`TrendDetailView.swift:114–118`).
String _fussnote(VerlaufArt art, DiagrammStufe stufe) {
  if (stufe == DiagrammStufe.halbjahr || stufe == DiagrammStufe.jahr) {
    return 'Je Punkt ein Monat, gezeigt wird der Monatsdurchschnitt.';
  }
  return switch (art) {
    VerlaufArt.schlaf =>
      'Je Punkt eine Nacht. Der Balken zeigt die Zeit im Schlaf, nicht die '
          'Zeit im Bett.',
    VerlaufArt.hrv => 'Je Punkt eine Nacht. Gemessen wird im Schlaf.',
    VerlaufArt.ruhepuls =>
      'Je Punkt eine Nacht. Der tiefste Wert der Nacht kommt dem Ruhepuls '
          'am nächsten.',
    VerlaufArt.atemfrequenz => 'Je Punkt eine Nacht. Gemessen wird im Schlaf.',
  };
}

/// Die Einheit neben dem Fensterschnitt in der Kopfzeile des Diagramms.
String _einheit(VerlaufArt art) => switch (art) {
  // „Schlaf / Nacht" wie auf dem Schlaf-Schirm (`schlaf.js`, `VERLAUF`):
  // Der Schnitt ist eine Rate, der abgelesene Balken ist es nicht.
  VerlaufArt.schlaf => 'Schlaf / Nacht',
  VerlaufArt.hrv => 'ms',
  VerlaufArt.ruhepuls => 'bpm',
  VerlaufArt.atemfrequenz => '/min',
};

/// Die Einheit beim Ablesen eines einzelnen Punktes. `null` heißt
/// „dieselbe" — bei `ms`, `bpm` und `/min` ändert sich nichts, und ein
/// Literal zweimal hinzuschreiben ist genau die Stelle, an der eines
/// veraltet.
String? _einheitAbgelesen(VerlaufArt art) =>
    art == VerlaufArt.schlaf ? 'Schlaf' : null;

/// „unter 46 ms" bzw. „71 bpm" — die Seite steht nur dort, wo der Wert
/// nach **unten** kippt (`verlauf.js`, `werte`).
String _schwellentext(VerlaufArt art, VerlaufDaten daten) {
  final schwelle = daten.signalAb;
  if (schwelle == null) return _ohneWert;
  final wert = _wert(art, schwelle);
  return hoeherIstBesser(art) ? 'unter $wert' : wert;
}

/// „44–61 ms" — die Einheit steht einmal, am Ende.
String _spannentext(VerlaufArt art, VerlaufDaten daten) {
  final spanne = daten.spanne;
  if (spanne == null) return _ohneWert;
  return '${_zahl(art, spanne.von)}–${_wert(art, spanne.bis)}';
}

/// Zahl und Einheit. `null` wird **nie** zu 0 — ein fehlender Wert heißt
/// „—".
String _wert(VerlaufArt art, double? wert) =>
    wert == null ? _ohneWert : '${_zahl(art, wert)}${_einheitHinten(art)}';

/// Die Zahl allein, in der Schreibweise dieses Werts
/// (`TrendDetailView.swift`, `format`).
String _zahl(VerlaufArt art, double wert) => switch (art) {
  // `stundenText` liefert „6:40 h"; die Einheit hängt diese Datei selbst
  // an, damit die Spanne sie nur einmal trägt. Dieselbe Rundung wie überall
  // sonst im Schirmsatz — eine zweite Stunden-Rechnung driftet.
  VerlaufArt.schlaf => stundenText(wert).split(' ').first,
  VerlaufArt.hrv || VerlaufArt.ruhepuls => '${wert.round()}',
  VerlaufArt.atemfrequenz => kommazahl(wert),
};

/// Mit Leerzeichen, außer bei „/min" — das hängt an der Zahl.
String _einheitHinten(VerlaufArt art) => switch (art) {
  VerlaufArt.schlaf => ' h',
  VerlaufArt.hrv => ' ms',
  VerlaufArt.ruhepuls => ' bpm',
  VerlaufArt.atemfrequenz => '/min',
};

const String _ohneWert = '—';
