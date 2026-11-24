// Der Verlaufsschirm je Messwert (#203) — **ein** Schirm für vier Werte
// (Gewicht, Körperfett, fettfreie Masse, Ruhepuls); welcher gemeint ist,
// trägt [MessArt] als Parameter, wie `VerlaufArt` bei den
// Erholungs-Verläufen. Der Zustand darunter liegt in
// `messung_detail_zustand.dart`.
//
// API und Verhalten sind durch `app/test/shell/messung_detail_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/messung-detail.js`: Diagramm mit
// Zeitleiste W M 6M J, „Einordnung", Erklärsatz, Fußnote. **Der Erklärsatz
// ist der eigentliche Inhalt** — die Kurve zeigt, *dass* sich etwas bewegt,
// der Satz sagt, *was das bedeutet*, und bei Körperfett und fettfreier
// Masse vor allem, wie grob die Waage schätzt.
//
// **Was dieser Schirm anders macht als `verlauf`:** Die Diagrammfläche
// bleibt im Leerzustand stehen. `verlauf_view.dart` nimmt sie weg („eine
// leere Fläche mit Achsen behauptet, es gäbe eine Kurve"); hier verlangt
// der Entwurf ausdrücklich das Gegenteil — „Leiste, Diagrammfläche,
// Einordnung und Satz bleiben stehen; nur die Zahlen fehlen" (Spec, Teil
// D).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/zahlen.dart';
import '../design/zeitdiagramm.dart';
import 'diagramm_zeitraum.dart';
import 'mess_abschnitte.dart';
import 'koerper_zustand.dart';
import 'messung_detail_zustand.dart';
import 'navy_zustand.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet den Verlauf eines Messwerts auf dem Stapel des **aktuell
/// gewählten** Tabs — gerufen aus `koerper` und aus `messungen`.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des
/// Tabs, aus dem man kommt, sonst führte „zurück" in ein Menü, das der
/// Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneMessungDetail(AppRouter router, MessArt art) =>
    router.open(AppTarget.aktuell((context) => MessungDetailSeite(art: art)));

/// Der Rahmen: Gerüst und Navigationsleiste um [MessungDetailView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
///
/// Die Leiste nennt den **Wert**, nicht „Verlauf" wie der Entwurfstitel:
/// Den Schirm gibt es viermal, und vier gleich beschriftete Leisten sagen
/// nicht, auf welchem man steht — dieselbe Entscheidung wie bei
/// `VerlaufSeite`.
class MessungDetailSeite extends StatelessWidget {
  const MessungDetailSeite({super.key, required this.art});

  final MessArt art;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(middle: Text(messName(art))),
      child: MessungDetailView(art: art),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([messungDetailProvider]): Jeder Schirm
/// ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen, dass
/// eine Übersicht vorher geladen hat.
class MessungDetailView extends ConsumerWidget {
  const MessungDetailView({super.key, required this.art});

  final MessArt art;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kein `.value`, kein `??`: [messungDetailProvider] liefert den
    // `Messwert` selbst. Die Übersetzung aus `AsyncValue` steht eine Ebene
    // tiefer in `alsMesswert` — der einen Stelle, an der sie stehen darf
    // (`CLAUDE.md`, Hausregel 1).
    final messwert = ref.watch(messungDetailProvider(art));
    final lage = messLageAus(messwert);
    final zustand = messwert is Bekannt<MessungDetailZustand>
        ? messwert.wert
        : null;

    // Die Steigung pro Woche steht nicht im Detailzustand, sondern einmal
    // in `KoerperWerte` — dieselbe Rechnung aus derselben Quelle, gehalten
    // statt hier je Bild gerechnet (Hausregel 2).
    final koerper = ref.watch(koerperWerteProvider);
    final trendProWoche = koerper is Bekannt<KoerperWerte>
        ? koerper.wert.gewichtsTrendProWoche
        : null;

    // Die Navy-Zeile hängt am Maßband und an den Stammdaten, nicht am Lauf
    // der Waage: Sie hat ihre eigenen drei Lagen und wird deshalb eigens
    // gelesen. Nur das Körperfett zeigt sie.
    final navy = art == MessArt.koerperfett
        ? ref.watch(navyStandProvider)
        : const NavyLaedt();

    // **Eine leere Reihe ist kein Leerzustand** — der Lauf hat etwas
    // geliefert, nur für diesen einen Wert nichts
    // (`messung_detail_zustand.dart`). Der Grund hängt deshalb an der
    // Reihe, nicht allein an der Lage.
    final ohneReihe = zustand == null || zustand.reihe.isEmpty;

    // `padding` statt einer äußeren `Padding`: Eine äußere `Padding`
    // verkleinerte den Scroll-Viewport, statt den Inhalt darin einzurücken
    // — dann liefe er nicht mehr sichtbar unter der Leiste durch
    // (`GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LageZeile(
            key: switch (lage) {
              MessLage.laedt => const Key('messung-detail-laden'),
              MessLage.fehler => const Key('messung-detail-fehler'),
              MessLage.werte || MessLage.leer => null,
            },
            lage: lage,
            stand: standAus(messwert),
            laeuft:
                messwert is Bekannt<MessungDetailZustand> && messwert.laeuft,
          ),
          Padding(
            key: const Key('messung-detail-diagramm'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Zeitdiagramm(
              reihe: [
                for (final punkt
                    in zustand?.reihe ?? const <MeasurementPoint>[])
                  (tag: punkt.date, wert: punkt.value),
              ],
              stufen: messungsStufen,
              // Linie, kein Balken: Gewicht, Fett, Masse und Puls sind
              // Stände, keine Mengen — der Entwurf zeichnet sie alle vier
              // als Kurve (`messung-detail.js`, `lineChart`).
              alsBalken: false,
              einheit: messEinheit(art),
              fussnote: (stufe) => _fussnote(art, stufe),
            ),
          ),
          const SectionHeader('Einordnung'),
          _Einordnung(
            key: const Key('messung-detail-einordnung'),
            art: art,
            lage: lage,
            zustand: zustand,
            trendProWoche: trendProWoche,
            navy: navy,
          ),
          // Der Grund, **einmal** — und nur dort, wo er etwas aussagt:
          // nicht während des Laufs (Fehler `01`) und nicht nach einem
          // Fehler (der sagt nichts über die Datenlage).
          if (ohneReihe && (lage == MessLage.werte || lage == MessLage.leer))
            const Notizflaeche(text: waagenGrund, oben: 16),
          Notizflaeche(
            key: const Key('messung-detail-erklaerung'),
            text: _erklaerung(art),
            oben: 16,
          ),
          const Hinweisfuss(messungenFuss),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Die Einordnung
// ─────────────────────────────────────────────────────────────────────────

/// Die Zeilen je Wert — sie **stehen im Entwurf und gelten wörtlich**
/// (Spec, Teil D; `messung-detail.js`, `werte`).
///
/// Zeilen ohne Datenbezug stehen in jeder Lage gleich da: Der Zielkorridor
/// hängt an der Regel aus `docs/SPEC.md`, nicht an einer Messung, und „kein
/// Maßband-Wert" ist eine **feste Zeile, keine Lücke** (Spec,
/// „Nicht-Ziele") — Umfänge gibt es im Neubau nicht (#88).
class _Einordnung extends StatelessWidget {
  const _Einordnung({
    super.key,
    required this.art,
    required this.lage,
    required this.zustand,
    required this.trendProWoche,
    required this.navy,
  });

  final MessArt art;
  final MessLage lage;
  final MessungDetailZustand? zustand;
  final double? trendProWoche;

  /// Der Stand der Maßband-Zeile — nur beim Körperfett von Belang.
  final NavyStand navy;

  @override
  Widget build(BuildContext context) => MessKarte(zeilen: _zeilen());

  List<MessZeileDaten> _zeilen() {
    final aktuell = zeileMitLage(
      lage,
      schluessel: const Key('messung-detail-aktuell'),
      // Beim Körperfett nennt der Entwurf die Quelle mit, weil daneben die
      // zweite stünde, sobald es Umfänge gibt.
      name: art == MessArt.koerperfett ? 'Aktuell · Waage' : 'Aktuell',
      wert: messWert(art, zustand?.aktuell),
      beispiel: messBeispiel(art),
    );
    final spanne = zeileMitLage(
      lage,
      name: 'Spanne 7 Tage',
      wert: _spannentext(art, zustand?.spanne7),
      beispiel: messBeispiel(art),
    );
    final veraenderung = zeileMitLage(
      lage,
      name: 'Veränderung 6 Wochen',
      wert: zustand?.veraenderung6Wochen == null
          ? ohneEinzelwert
          : veraenderungText(art, zustand!.veraenderung6Wochen!),
      beispiel: messBeispiel(art),
    );

    return switch (art) {
      MessArt.gewicht => [
        aktuell,
        zeileMitLage(
          lage,
          name: 'Trend 6 Wochen',
          wert: trendProWoche == null
              ? ohneEinzelwert
              : gewichtsTrendText(trendProWoche!),
          beispiel: messBeispiel(art),
        ),
        // Die Grenzen stehen als Nutzertext da, damit „guter Bereich"
        // nachprüfbar ist (`messung-detail.js`). Gerechnet wird mit ihnen
        // im Kern (`BodyTrend.rating`), nicht hier.
        const MessZeileDaten(
          name: 'Zielkorridor',
          wert: '+0,10 bis +0,25 kg pro Woche',
        ),
        spanne,
      ],
      MessArt.koerperfett => [aktuell, _navyZeile(navy), veraenderung, spanne],
      MessArt.fettfreieMasse => [
        aktuell,
        veraenderung,
        zeileMitLage(
          lage,
          name: 'Anteil am Gewicht',
          wert: zustand?.anteilAmGewicht == null
              ? ohneEinzelwert
              : '${formatNumber(zustand!.anteilAmGewicht! * 100, nachkommastellen: 1)} %',
          beispiel: '00,0',
        ),
        spanne,
      ],
      MessArt.ruhepuls => [
        aktuell,
        zeileMitLage(
          lage,
          name: 'Median 30 Tage',
          wert: messWert(art, zustand?.median30),
          beispiel: messBeispiel(art),
        ),
        spanne,
      ],
    };
  }
}

/// Die Zeile „Nach Maßband (Navy)" — **eine feste Zeile, keine Lücke**
/// (#203), in jeder der drei Lagen.
///
/// **Drei Lagen, drei unterscheidbare Auskünfte** (#489), gelesen über den
/// `switch` über den sealed-Typ: Während die Umfänge gelesen werden, steht
/// hier die graue Form und kein „kein Maßband-Wert" — ob Taille und Hals
/// vorliegen, weiß die App dann nicht (`01`).
///
/// **Und fehlt eine der drei Zahlen, steht da welche.** „kein Halsmaß" ist
/// eine andere Auskunft als „keine Körpergröße"; eine gemeinsame schickte
/// Tim das Maßband suchen, obwohl die Körpergröße fehlt (#479).
MessZeileDaten _navyZeile(NavyStand navy) {
  const schluessel = Key('messung-detail-navy');
  const name = 'Nach Maßband (Navy)';

  return switch (navy) {
    NavyLaedt() => const MessZeileDaten(
      schluessel: schluessel,
      name: name,
      platzhalter: '00,0 %',
    ),
    NavyUnlesbar() => const MessZeileDaten(
      schluessel: schluessel,
      name: name,
      wert: 'nicht lesbar',
    ),
    NavyGelesen(:final prozent?) => MessZeileDaten(
      schluessel: schluessel,
      name: name,
      wert: '${formatNumber(prozent, nachkommastellen: 1)} %',
    ),
    NavyGelesen(:final grund) => MessZeileDaten(
      schluessel: schluessel,
      name: name,
      wert: _navyGrund(grund),
    ),
  };
}

/// Warum keine Zahl dasteht — ein Satz je Grund.
///
/// `null` kann hier nicht vorkommen: [NavyGelesen] trägt entweder eine Zahl
/// oder einen Grund, und die Zahl ist eine Zeile höher abgefangen. Fiele
/// das je auseinander, stünde dort die ehrlichste Auskunft, die bleibt.
String _navyGrund(NavyGrund? grund) => switch (grund) {
  NavyGrund.ohneMass || null => 'kein Maßband-Wert',
  NavyGrund.ohneHals => 'kein Halsmaß',
  NavyGrund.ohneTaille => 'kein Taillenmaß',
  NavyGrund.ohneGemeinsameMessung => 'Taille und Hals aus einer Messung nötig',
  NavyGrund.ohneGroesse => 'keine Körpergröße',
  NavyGrund.unplausibel => 'Maße passen nicht zusammen',
};

/// „57,5–58,4 kg" — die Einheit steht einmal, am Ende.
String _spannentext(MessArt art, ({double von, double bis})? spanne) {
  if (spanne == null) return ohneEinzelwert;
  return '${messZahl(art, spanne.von)}–${messWert(art, spanne.bis)}';
}

// ─────────────────────────────────────────────────────────────────────────
// Nutzertexte
// ─────────────────────────────────────────────────────────────────────────

/// Die vier Erklärsätze, wörtlich aus `messung-detail.js`.
///
/// Vier verschiedene, nicht viermal derselbe: „Der Erklärsatz ist der
/// eigentliche Inhalt" — vier gleiche wären vier leere.
String _erklaerung(MessArt art) => switch (art) {
  MessArt.gewicht =>
    'Eine einzelne Wägung schwankt um bis zu ein Kilo — Wasser, Essen, '
        'Tageszeit. Aussagekräftig ist erst die Linie über mehrere Wochen; '
        'sie entsteht als lineare Regression über die letzten sechs. Am '
        'besten morgens nüchtern wiegen, zwei- bis dreimal die Woche.',
  // **Keine Zusage stehen lassen, die nicht mehr stimmt** (`CLAUDE.md`):
  // Bis #479 stand hier „Sobald Taille und Hals unter Umfänge eingetragen
  // sind, steht der Wert nach der Navy-Formel daneben" — ein Versprechen
  // auf etwas, das es noch nicht gab. Jetzt gibt es das, und der Satz
  // beschreibt, statt zu versprechen.
  MessArt.koerperfett =>
    'Die Waage schätzt über Bioimpedanz und schwankt mit dem '
        'Flüssigkeitshaushalt — der Verlauf taugt mehr als der einzelne '
        'Wert. Daneben steht der Wert nach der Navy-Formel aus Taille, Hals '
        'und Körpergröße; zwei grobe Schätzungen, die sich gegenseitig '
        'einordnen.',
  MessArt.fettfreieMasse =>
    'Die fettfreie Masse enthält Wasser, Organe und Knochen, nicht nur '
        'Muskeln — ein Kilo mehr nach einem salzigen Abend ist Wasser. Über '
        'Wochen gelesen ist die Richtung trotzdem brauchbar, besonders '
        'zusammen mit dem Oberarmumfang.',
  MessArt.ruhepuls =>
    'Der Ruhepuls sinkt mit besserer Ausdauer, über Monate, nicht über '
        'Tage. Liegt er mehrere Tage deutlich über dem Median, ist das eher '
        'ein Zeichen für fehlende Erholung oder einen beginnenden Infekt — '
        'eingeordnet wird das unter Erholung.',
};

/// Die Fußzeile unter dem Diagramm. Ab `6M` trägt ein Punkt einen ganzen
/// Monat — das muss dastehen, sonst liest man einen Monatsschnitt als
/// Einzelmessung (Spec, Teil C).
String _fussnote(MessArt art, DiagrammStufe stufe) {
  if (stufe == DiagrammStufe.halbjahr || stufe == DiagrammStufe.jahr) {
    return 'Je Punkt ein Monat, gezeigt wird der Monatsdurchschnitt.';
  }
  return switch (art) {
    MessArt.gewicht =>
      'Je Punkt eine Wägung. Ab 6M ist ein Punkt das Monatsmittel — eine '
          'einzelne Wägung verschwindet dort also.',
    MessArt.koerperfett ||
    MessArt.fettfreieMasse => 'Je Punkt eine Messung der Waage.',
    MessArt.ruhepuls =>
      'Je Punkt eine Nacht. Der tiefste Wert der Nacht kommt dem Ruhepuls '
          'am nächsten.',
  };
}
