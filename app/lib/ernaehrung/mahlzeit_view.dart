// Der Mahlzeiten-Schirm (#300, Ernährungsplan Task 9) — Kopf, Raster,
// Mahlzeitenziel, „Alle Nährwerte", Liste, Knopf, Fußtext. Der Zustand
// darunter liegt in `mahlzeit_provider.dart`, Raster, Balken und „Alle
// Nährwerte" in `mahlzeit_kopf.dart` (#442).
//
// API und Verhalten sind durch `app/test/mahlzeit/mahlzeit_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau, Beschriftung und Reihenfolge nach
// `docs/screens/screens/mahlzeit.js`, Zustände `voll`, `voll-werte`,
// `loeschen`, `rueckgaengig`, `laedt`, `leer` und `nur-health`; der Teil
// über der Liste nach `vorschlag-raster`, `vorschlag-raster-leer` und
// `vorschlag-raster-ohne-ziel` (#442).
//
// **Eine Anzeige, die es gibt, hat genau eine Form** (`CLAUDE.md`): Kopf,
// Werteblock, Liste, Knopf und Fuß stehen in jedem Zustand an derselben
// Stelle — nur die Füllung unterscheidet sich. Deshalb trägt die
// Kopfzeile immer genau eine Zeile Einordnung, und jeder Platzhalter im
// Raster ist so hoch wie die Zahl, die er ablöst.
//
// **Keine Makro-Ziele je Mahlzeit** (Entscheidung 11 der Aufteilungs-Spec).
// Ein Balken braucht ein Ziel, und ein Eiweißziel fürs Frühstück gibt es
// nicht. Der einzige Balken steht für die Kalorien, gegen den eingestellten
// Anteil am Tagesziel.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import '../health/health_types.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'aufteilung_view.dart';
import 'erfassen_provider.dart';
import 'ernaehrung_abschnitte.dart';
import 'kamera_seite.dart';
import 'mahlzeit_kopf.dart';
import 'mahlzeit_provider.dart';
import 'portions_text.dart';

/// Öffnet den Mahlzeiten-Schirm auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß (wie `oeffneErholung`).
///
/// Über `AppTarget.aktuell(...)`, nie über einen Tab-Wechsel: Sonst führte
/// „zurück" in ein Menü, das der Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneMahlzeit(
  AppRouter router, {
  required String tagesSchluessel,
  required Mahlzeit mahlzeit,
}) {
  router.open(
    AppTarget.aktuell(
      (context) => MahlzeitSeite(
        tagesSchluessel: tagesSchluessel,
        mahlzeit: mahlzeit,
        router: router,
      ),
    ),
  );
}

/// Der Rahmen: Gerüst und Navigationsleiste um genau eine [MahlzeitView].
///
/// Den stellt der Gastgeber, nicht der Schirm — Hausform von
/// `ErholungSeite` und `VorlaeufigeWerteSeite`. **Kein eigener
/// `Navigator`:** Diese Ansicht wird auf den Stapel eines Tabs geschoben,
/// der Stapel gehört weiter `RootView`.
class MahlzeitSeite extends StatelessWidget {
  const MahlzeitSeite({
    super.key,
    required this.tagesSchluessel,
    required this.mahlzeit,
    this.router,
  });

  final String tagesSchluessel;
  final Mahlzeit mahlzeit;

  /// Siehe [MahlzeitView.router].
  final AppRouter? router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(mahlzeitName(mahlzeit)),
      ),
      child: MahlzeitView(
        tagesSchluessel: tagesSchluessel,
        mahlzeit: mahlzeit,
        router: router,
      ),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([mahlzeitProvider]): Seit jeder
/// Schirm aus jedem Tab direkt erreichbar ist, kann niemand sich darauf
/// verlassen, dass eine Übersicht vorher geladen hat.
class MahlzeitView extends ConsumerWidget {
  const MahlzeitView({
    super.key,
    required this.tagesSchluessel,
    required this.mahlzeit,
    this.router,
  });

  final String tagesSchluessel;
  final Mahlzeit mahlzeit;

  /// Der Weg von „Zu dieser Mahlzeit hinzufügen" in die Suche (#285).
  ///
  /// **Optional, wie bei `ErnaehrungView`:** Der Bauvertrag
  /// `MahlzeitView(tagesSchluessel:, mahlzeit:)` steht in einer Testdatei.
  /// Ohne Router sagt der Knopf, dass die Suche von hier aus nicht
  /// erreichbar ist — ein stummer Knopf wäre eine Tür, die keine ist.
  final AppRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inhalt = ref.watch(mahlzeitProvider((tagesSchluessel, mahlzeit)));
    return _Schirm(inhalt: inhalt, router: router);
  }
}

/// Der eigentliche Aufbau — **mit Zustand**, weil drei Dinge der
/// Oberfläche gehören und keinem Provider: ob die Nährwerte aufgeklappt
/// sind, welche Zeile gerade weggestrichen wurde und was das Rückgängig
/// zurückholen würde.
///
/// [MahlzeitView] bleibt dadurch ein `ConsumerWidget` (festgelegte API),
/// und dieser Zustand überlebt jedes Neurechnen des Providers — ein
/// Abschnitt, der beim nächsten Durchlauf wieder zufiele, wäre aus Sicht
/// des Nutzers Fehler `32`.
class _Schirm extends ConsumerStatefulWidget {
  const _Schirm({required this.inhalt, required this.router});

  final MahlzeitInhalt inhalt;
  final AppRouter? router;

  @override
  ConsumerState<_Schirm> createState() => _SchirmState();
}

class _SchirmState extends ConsumerState<_Schirm> {
  /// Die Kennungen weggestrichener Zeilen.
  ///
  /// **Sie verschwinden sofort, nicht erst nach dem Schreiben.** Ein
  /// `Dismissible`, der nach dem Wegwischen noch im Baum steht, lässt eine
  /// Lücke stehen, bis die Datenbank antwortet. Die Kennungen werden nie
  /// wiederverwendet (`AUTOINCREMENT`), also darf die Menge wachsen.
  final Set<int> _weggestrichen = {};

  /// Was das Rückgängig zurückholen würde — `null`, wenn gerade nichts
  /// gelöscht wurde.
  Eintrag? _geloescht;

  Timer? _uhr;

  bool _offen = false;

  @override
  void dispose() {
    // Nur der Timer, kein `ref`: `avoid_ref_inside_state_dispose`.
    _uhr?.cancel();
    super.dispose();
  }

  /// Streichen löscht sofort — **und hinterlässt einen Weg zurück.**
  ///
  /// Ohne ihn wäre ein Zug mit dem Daumen unwiderruflich, und das bei
  /// Daten, von denen es auf dem Gerät nur eine Kopie gibt
  /// (`mahlzeit.js`, Zustand `rueckgaengig`).
  ///
  /// **Über denselben Weg wie „Löschen" im Buchungsblatt** (#283): Die
  /// Kopie in Apple Health geht mit. Ginge das Streichen direkt an die
  /// Tabelle, bliebe die Probe drüben stehen, und andere Apps zählten
  /// eine Mahlzeit, die es nicht mehr gibt.
  Future<void> _loesche(Eintrag eintrag) async {
    final id = eintrag.id;
    if (id == null) return;

    setState(() {
      _weggestrichen.add(id);
      _geloescht = eintrag;
    });
    _starteUhr();

    await ref.read(erfassenProvider.notifier).loesche(eintrag);
  }

  Future<void> _nimmZurueck() async {
    final eintrag = _geloescht;
    if (eintrag == null) return;

    _uhr?.cancel();
    setState(() => _geloescht = null);

    // Ohne `id` und ohne die alte Kennung — die Probe in Health ist beim
    // Streichen gelöscht worden (siehe `ErfassenNotifier.stelleWiederHer`).
    await ref.read(erfassenProvider.notifier).stelleWiederHer(eintrag);
  }

  /// Der Weg zurück verschwindet von selbst — er ist ein Hinweis, kein
  /// Abschnitt des Schirms.
  void _starteUhr() {
    _uhr?.cancel();
    _uhr = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _geloescht = null);
    });
  }

  Future<void> _oeffneBearbeiten(Eintrag eintrag) async {
    final oeffner = ref.read(bearbeitenOeffnerProvider);
    // Ein alter Eintrag ohne Schnappschuss, dessen Vorlage flüssig ist
    // (#403): Das Blatt rechnet in ml wie die Zeile darüber. Ein Blatt in
    // Gramm unter einer Zeile in Millilitern widerspräche sich. Wer sichert,
    // legt die Einheit damit fest, die er gesehen hat.
    final inMl =
        eintrag.fluessig == null && widget.inhalt.inMillilitern(eintrag);
    await oeffner(
      context,
      inMl ? eintrag.copyWith(fluessig: () => true) : eintrag,
    );
  }

  /// „Zu dieser Mahlzeit hinzufügen": derselbe Einstieg wie der (+), die
  /// Kamera (#344) — und das Buchungsblatt kommt mit **dieser** Mahlzeit
  /// und **diesem** Tag vorgewählt, nach dem Scan wie über „Suchen". Nicht
  /// mit der Mahlzeit, die die Uhrzeit ergäbe, und nicht mit heute; die
  /// Uhrzeit selbst bleibt die des Trackens (#328).
  void _hinzufuegen() {
    final router = widget.router;
    if (router == null) {
      _nichtErreichbar();
      return;
    }
    oeffneKamera(
      router,
      tagesSchluessel: widget.inhalt.tagesSchluessel,
      mahlzeit: widget.inhalt.mahlzeit,
    );
  }

  /// „Aufteilung des Tagesziels festlegen ›" (V19): der Schirm
  /// „Aufteilung", auf dem Stapel des Tabs, in dem man gerade ist
  /// (`AppTarget.aktuell`, kein Tab-Wechsel).
  void _aufteilung() {
    final router = widget.router;
    if (router == null) {
      _nichtErreichbar(
        'Die Aufteilung ist von hier aus gerade nicht '
        'erreichbar.',
      );
      return;
    }
    oeffneAufteilung(router);
  }

  void _nichtErreichbar([
    String text = 'Das Erfassen ist von hier aus gerade nicht erreichbar.',
  ]) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(mahlzeitName(widget.inhalt.mahlzeit)),
        content: Text(text),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inhalt = widget.inhalt;
    final eigene = [
      for (final eintrag in inhalt.eigene)
        if (!_weggestrichen.contains(eintrag.id)) eintrag,
    ];
    final geloescht = _geloescht;

    return SingleChildScrollView(
      // `padding` statt einer äußeren `Padding`: Eine äußere verkleinerte
      // den Scroll-Viewport, statt den Inhalt darin einzurücken.
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrosseUeberschrift(
            key: const Key('mahlzeit-kopf'),
            mahlzeitName(inhalt.mahlzeit),
            einordnung: _einordnung(inhalt),
          ),
          MahlzeitKopf(
            inhalt: inhalt,
            offen: _offen,
            onKlappen: () => setState(() => _offen = !_offen),
            onAufteilung: _aufteilung,
          ),
          _Liste(
            inhalt: inhalt,
            eigene: eigene,
            onTippen: _oeffneBearbeiten,
            onLoeschen: _loesche,
          ),
          if (inhalt.nurFremd)
            const _Notiz(
              key: Key('mahlzeit-nur-health'),
              text:
                  'Diese Mahlzeit stammt vollständig aus einer anderen App. '
                  'Du kannst hier etwas hinzufügen, die vorhandenen Zeilen '
                  'aber nur dort ändern, wo sie eingetragen wurden.',
            ),
          if (geloescht != null)
            GestureDetector(
              key: const Key('mahlzeit-rueckgaengig'),
              behavior: HitTestBehavior.opaque,
              onTap: _nimmZurueck,
              child: _Notiz(
                text: '${geloescht.name} gelöscht.',
                aktion: 'Rückgängig',
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CupertinoButton(
              key: const Key('mahlzeit-hinzufuegen'),
              color: CupertinoDynamicColor.resolve(Palette.river, context),
              onPressed: _hinzufuegen,
              child: const Text('Zu dieser Mahlzeit hinzufügen'),
            ),
          ),
          Hinweisfuss(
            key: const Key('mahlzeit-fuss'),
            _fussFuer(
              ki: eigene.any((eintrag) => eintrag.vorschlag != null),
              fremd: inhalt.fremde.isNotEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Fußtext, wörtlich aus `docs/screens/screens/mahlzeit.js` — der zu
/// „Apple Health" (`voll`) und, sobald eine Zeile aus einer Foto-Schätzung
/// stammt, der zu „KI-Schätzung" (`ki-eintraege`, #341). Stehen nur
/// KI-Zeilen da, entfällt der Satz zu Apple Health, wie gezeichnet.
String _fussFuer({required bool ki, required bool fremd}) =>
    [if (ki) _fussKi, if (!ki || fremd) _fuss].join(' ');

const _fussKi =
    'Zeilen mit „KI-Schätzung" stammen aus einem Foto und sind geschätzt, '
    'nicht gewogen.';

const _fuss =
    'Zeilen mit „Apple Health" stammen aus einer anderen App. Sie zählen '
    'mit, lassen sich hier aber nicht ändern — Apple gibt fremde Einträge '
    'nicht frei.';

/// Die eine Zeile unter dem Namen der Mahlzeit.
///
/// **Immer genau eine Zeile**, in jedem Zustand: Fiele sie weg oder bräche
/// sie um, rutschte der ganze Schirm, sobald ein Wert eintrifft.
///
/// **Während des Laufs steht dort kein Grund.** „Nichts eingetragen" wäre
/// eine Behauptung über eine Datenlage, die noch niemand kennt (Fehler
/// `01`) — dann steht nur das Datum da.
String _einordnung(MahlzeitInhalt inhalt) {
  final datum = Format.wochentagUndDatum(datumAusTag(inhalt.tagesSchluessel));
  if (inhalt.laedt) return datum;
  if (inhalt.leer) return '$datum · nichts eingetragen';

  final erste = _ersterZeitpunkt(inhalt);
  final zahl = inhalt.anzahl == 1 ? '1 Eintrag' : '${inhalt.anzahl} Einträge';
  return erste == null ? '$datum · $zahl' : '$datum · $erste · $zahl';
}

String? _ersterZeitpunkt(MahlzeitInhalt inhalt) {
  final zeitpunkte = [
    for (final eintrag in inhalt.eigene) eintrag.zeitpunkt,
    for (final fremd in inhalt.fremde) fremd.zeitpunkt,
  ]..sort();
  return zeitpunkte.isEmpty ? null : _uhrzeit(zeitpunkte.first);
}

/// Ein Zeitpunkt als Uhrzeit auf der **Berliner Wanduhr**.
///
/// Über [Format] gesetzt (`CLAUDE.md`: jede Zeitangabe läuft über den
/// gemeinsamen Formatierer) und über [BerlinCalendar], nicht über den
/// rohen UTC-Zeitpunkt: 22:30 UTC ist im Juli in Berlin schon 00:30.
String _uhrzeit(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  // Ein beliebiger Kalendertag als Träger: Gesetzt wird nur die Uhrzeit.
  return Format.uhrzeit(DateTime.utc(2000, 1, 1, stunde, minute));
}

// ─────────────────────────────────────────────────────────────────────────
// Die Liste
// ─────────────────────────────────────────────────────────────────────────

/// „Eingetragen": die eigenen Zeilen, dann die fremden.
///
/// **Die Liste beginnt in jedem Zustand an derselben Stelle** — alles
/// darüber hat eine feste Höhe. Fiele hier etwas weg, wüchse der Schirm,
/// sobald ein Wert eintrifft, und alles darunter rutschte.
class _Liste extends StatelessWidget {
  const _Liste({
    required this.inhalt,
    required this.eigene,
    required this.onTippen,
    required this.onLoeschen,
  });

  final MahlzeitInhalt inhalt;

  /// Die eigenen Zeilen **ohne** die gerade weggestrichenen.
  final List<Eintrag> eigene;

  final void Function(Eintrag) onTippen;
  final void Function(Eintrag) onLoeschen;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final zeilen = <Widget>[];

    void trenner() {
      if (zeilen.isNotEmpty) zeilen.add(Container(height: 1, color: line));
    }

    if (inhalt.laedt) {
      // Dieselbe Form in Grau. **Kein Grund steht da, solange noch gelesen
      // wird** — „nichts eingetragen" wäre eine Behauptung über eine
      // Datenlage, die noch niemand kennt (Fehler `01`).
      for (var i = 0; i < 2; i++) {
        trenner();
        zeilen.add(const _LadeZeile());
      }
    } else if (inhalt.leer) {
      zeilen.add(
        IconRow(
          key: const Key('mahlzeit-leer'),
          title: 'Noch nichts eingetragen',
          subtitle: 'Barcode, KI-Foto oder suchen',
          symbol: 'plus.circle',
          accent: CupertinoDynamicColor.resolve(Palette.river, context),
        ),
      );
    } else {
      for (final eintrag in eigene) {
        trenner();
        zeilen.add(
          Dismissible(
            key: Key('mahlzeit-eintrag-${eintrag.id}'),
            direction: DismissDirection.endToStart,
            // **Ohne Nachschrumpfen**: Die Zeile verschwindet, weil der
            // Schirm sie beim nächsten Bauen weglässt, nicht weil der
            // `Dismissible` sie zusammenfaltet. Eine Zeile, die nach dem
            // Wegwischen noch im Baum steht, bricht beim nächsten Neubau.
            resizeDuration: null,
            secondaryBackground: const _Loeschfeld(),
            background: const SizedBox.shrink(),
            onDismissed: (_) => onLoeschen(eintrag),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTippen(eintrag),
              child: _Essenszeile(
                name: eintrag.name,
                einordnung: _einordnungDerZeile(
                  eintrag,
                  fluessig: inhalt.inMillilitern(eintrag),
                ),
                kcal: eintrag.naehrwerte.kcal,
                fremd: false,
                // **Bleibt nach dem Ändern** (Spec, „Was gebucht ist,
                // bleibt als Schätzung erkennbar"): `vorschlag` hängt am
                // Eintrag, nicht an seiner Menge.
                ki: eintrag.vorschlag != null,
              ),
            ),
          ),
        );
      }
      for (var i = 0; i < inhalt.fremde.length; i++) {
        final fremd = inhalt.fremde[i];
        trenner();
        // **Keine Geste, kein Winkel.** Apple gibt fremde Proben nicht
        // frei; eine Zeile, die aussieht wie die eigenen und nichts tut,
        // ist eine kaputte Zeile.
        zeilen.add(
          _Essenszeile(
            key: Key('mahlzeit-fremd-$i'),
            name: fremd.name,
            einordnung: _uhrzeit(fremd.zeitpunkt),
            kcal: fremd.naehrwerte.kcal,
            fremd: true,
          ),
        );
      }
      if (zeilen.isEmpty) {
        // Alles weggestrichen, der Provider hat noch nicht nachgezogen —
        // die Karte bleibt trotzdem gefüllt, damit nichts springt.
        zeilen.add(const _LadeZeile());
      }
    }

    return Column(
      key: const Key('mahlzeit-liste'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader('Eingetragen'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InsetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: zeilen,
            ),
          ),
        ),
      ],
    );
  }
}

/// „250 g · 07:10" wenn gewogen, „2 Bon (11,8 g) · 16:20" wenn mit einer
/// Portion gebucht (#325, V9), sonst die Uhrzeit. Ein Getränk ([fluessig])
/// steht in ml: „330 ml · 16:20", „2 Glas (500 ml) · 16:20" (#403).
///
/// **Nicht „0 g"**: `mengeG == null` heißt „nicht gewogen" (Schnelleintrag
/// „nur Kalorien"), und das ist etwas anderes als eine gewogene Null.
///
/// **Die Portion kommt aus dem Schnappschuss des Eintrags**, nie aus
/// `portionen` (Entscheidung 8): Wer „Bon" später umbenennt, ändert diese
/// Zeile nicht. Darauf verlässt sich der Satz im Dialog „Portion ändern",
/// „Gebuchte Einträge behalten ihre Gramm".
String _einordnungDerZeile(Eintrag eintrag, {required bool fluessig}) {
  final zeit = _uhrzeit(eintrag.zeitpunkt);
  final mengeG = eintrag.mengeG;
  if (mengeG == null) return zeit;
  final name = eintrag.portionName;
  final portionG = eintrag.portionG;
  if (name != null && portionG != null) {
    final portion = gebuchtePortion(
      mengeG: mengeG,
      name: name,
      portionG: portionG,
      fluessig: fluessig,
    );
    return '$portion · $zeit';
  }
  return '${formatNumber(mengeG)} ${fluessig ? 'ml' : 'g'} · $zeit';
}

/// Eine Zeile der Liste — `foodRow` in `docs/screens/components.js`.
///
/// **Die Herkunft steht an der Zeile**, nicht nur im Fuß: Das muss man
/// sehen, bevor man darauf tippt.
class _Essenszeile extends StatelessWidget {
  const _Essenszeile({
    super.key,
    required this.name,
    required this.einordnung,
    required this.kcal,
    required this.fremd,
    this.ki = false,
  });

  final String name;
  final String einordnung;
  final double? kcal;
  final bool fremd;

  /// Aus einer Foto-Schätzung gebucht — dasselbe Abzeichen wie „Apple
  /// Health", aber die Zeile bleibt antippbar: Es ist Tims eigener Eintrag
  /// (`mahlzeit.js`, `ki-eintraege`).
  final bool ki;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    einordnung,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
          ),
          if (fremd || ki)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  fremd ? 'Apple Health' : 'KI-Schätzung',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            kcal == null ? ohneWert : formatNumber(kcal!),
            style: Typografie.tabularNumbers(
              Typografie.numeric(TypografieGroesse.callout)
                  .copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dieselbe Zeile in Grau — die graue Form gehört in den ersten Schritt,
/// das Animieren ist #24.
class _LadeZeile extends StatelessWidget {
  const _LadeZeile();

  @override
  Widget build(BuildContext context) {
    const nameStil = TextStyle(fontWeight: FontWeight.w600);
    const einordnungStil = TextStyle(fontSize: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Platzhalter(beispiel: 'Haferflocken kernig', stil: nameStil),
                SizedBox(height: 3),
                Platzhalter(beispiel: '80 g · 07:10', stil: einordnungStil),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Platzhalter(
            beispiel: '298',
            stil: Typografie.numeric(TypografieGroesse.callout),
          ),
        ],
      ),
    );
  }
}

/// Das Löschfeld, das **unter** der Zeile hervorkommt — nicht oben drauf,
/// sonst verdeckte es, was man gerade löscht (`mahlzeit.js`, Zustand
/// `loeschen`).
class _Loeschfeld extends StatelessWidget {
  const _Loeschfeld();

  @override
  Widget build(BuildContext context) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return ColoredBox(
      color: warn,
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Löschen',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ein Hinweiskasten — `noteBox('neutral', …)` in
/// `docs/screens/components.js`.
class _Notiz extends StatelessWidget {
  const _Notiz({super.key, required this.text, this.aktion});

  final String text;

  /// Das Wort, das wie ein Weg aussieht („Rückgängig"). Die Geste liegt
  /// beim Aufrufer — dieser Kasten malt nur.
  final String? aktion;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final aktion = this.aktion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: line.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, color: muted, height: 1.35),
              ),
            ),
            if (aktion != null)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  aktion,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: river,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
