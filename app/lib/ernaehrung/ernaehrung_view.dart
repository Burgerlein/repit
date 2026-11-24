// Der Ernährungs-Tag-Schirm (#282, Ernährungsplan Task 4) — Übersicht
// (#406, statt der drei Ringe), vier Mahlzeiten (seit #434 mit Ring, Ziel
// und „+", `mahlzeiten_liste.dart`), Wasser, Rezepte,
// Verlauf, Herleitung, die vier Wege und der Fußtext, in genau dieser
// Reihenfolge (Tim, 04.11.2026). Der Zustand
// darunter liegt in `ernaehrung_provider.dart`, die einzelnen Abschnitte
// in `ernaehrung_abschnitte.dart`.
//
// API und Verhalten sind durch `app/test/ernaehrung/ernaehrung_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau, Beschriftung und Reihenfolge nach
// `docs/screens/screens/ernaehrung.js`, Zustände `tag`, `leer`, `laedt`,
// `kein-ziel` und `ueber`.
//
// Wasser eintragen (#311) steht in `ernaehrung_abschnitte.dart` und
// `wasser_provider.dart`, der 14-Tage-Verlauf (#312) in
// `ernaehrung_verlauf.dart` und `ernaehrung_verlauf_ansicht.dart`. Das
// Kohlenhydratziel ist seit #310 da und kommt aus dem Kern.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stammdaten.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../design/zahlen.dart';
import '../health/health_types.dart';
import '../shell/router.dart';
import 'aufteilung_view.dart';
import 'erfassen_weg.dart';
import 'kamera_seite.dart';
import 'ernaehrung_abschnitte.dart';
import 'ernaehrung_herleitung.dart';
import 'ernaehrung_uebersicht.dart';
import 'ernaehrung_provider.dart';
import 'ernaehrung_verlauf.dart';
import 'ernaehrung_verlauf_ansicht.dart';
import 'mahlzeit_view.dart';
import 'mahlzeiten_liste.dart';

/// Der Ernährungs-Tab.
///
/// **Bringt keinen eigenen `CupertinoPageScaffold` mit** — den stellt
/// `RootView` je Tab, dieselbe Regel wie bei `PlatzhalterTab`. Und keinen
/// eigenen `Navigator`: Der Stapel gehört dem Tab.
///
/// **Er besorgt seine Daten selbst** ([ernaehrungsTagProvider]): Seit jeder
/// Schirm aus jedem Tab direkt erreichbar ist, kann niemand sich darauf
/// verlassen, dass eine Übersicht vorher geladen hat.
class ErnaehrungView extends ConsumerStatefulWidget {
  const ErnaehrungView({super.key, this.router});

  /// Der Weg aus einer Mahlzeitenzeile auf den Mahlzeiten-Schirm (#300).
  ///
  /// **Optional, genau wie bei `RootView`** (`root_view.dart:58`): Der
  /// Bauvertrag `const ErnaehrungView({super.key})` ist durch
  /// `test/ernaehrung/ernaehrung_view_test.dart` festgelegt, und eine
  /// Testdatei ändert niemand, der die Implementierung schreibt
  /// (`CLAUDE.md`). Ohne Router bleibt der Hinweis stehen, dass der
  /// Schirm von hier aus nicht erreichbar ist — ein stummer Tipp wäre
  /// dasselbe wie eine Zeile, die aussieht wie eine Tür und keine ist.
  final AppRouter? router;

  @override
  ConsumerState<ErnaehrungView> createState() => _ErnaehrungViewZustand();
}

class _ErnaehrungViewZustand extends ConsumerState<ErnaehrungView> {
  /// „Details" in der Übersicht (#406) klappt die Herleitung auf …
  final _herleitungAuf = _Signal();

  /// … und rollt sie ins Bild. Am Abschnitt, nicht an der Karte: Der
  /// eigene Schlüssel des `KlappAbschnitt` hält dessen Zustand.
  final _herleitungStelle = GlobalKey();

  @override
  void dispose() {
    _herleitungAuf.dispose();
    super.dispose();
  }

  void _zurHerleitung() {
    _herleitungAuf.feuere();
    // Nach dem nächsten Bild: Erst dann steht der aufgeklappte Inhalt da,
    // und das Rollen nimmt seine Höhe mit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ziel = _herleitungStelle.currentContext;
      if (ziel == null || !ziel.mounted) return;
      Scrollable.ensureVisible(
        ziel,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = widget.router;
    // **Der Lauf läuft nur, weil hier jemand hinsieht** (Tims Befund vom
    // 04.11.2026). `stammdatenAusHealthProvider` ist ein `FutureProvider`,
    // und ein `FutureProvider` ohne Beobachter läuft **nie**: Größe und
    // Geburtsjahr landeten nie in der Tabelle, `kalorienziel` lieferte
    // `null`, und die Zeile „Kein Kalorienziel" blieb stehen, egal was Tim
    // eintrug. Der Wert selbst (`void`) wird nicht gebraucht — das
    // Beobachten ist der Zweck.
    ref.watch(stammdatenAusHealthProvider);

    final tagesSchluessel = ref.watch(offenerTagProvider);
    final tag = ref.watch(ernaehrungsTagProvider(tagesSchluessel));
    // Für den Grund „kein Kalorienziel": Er nennt genau die Angabe, die
    // fehlt, und dafür braucht er Größe und Geburtsjahr einzeln — der
    // gerechnete Tag trägt nur deren Ergebnis.
    final stammdaten = stammdatenAusProvider(ref.watch(stammdatenProvider))
        .stammdaten;
    final blaettern = ref.read(offenerTagProvider.notifier);

    // Der Grund „kein Ziel berechenbar" gehört zu einem **fertigen** Lauf
    // ohne Treffer. Solange nachgesehen wird, ist nichts entschieden
    // (Fehler `01`).
    final zielFehlt = tag.zielKcal == null && !tag.zielLaedt;

    return SingleChildScrollView(
      // `padding` statt einer äußeren `Padding`: Eine äußere verkleinerte
      // den Scroll-Viewport, statt den Inhalt darin einzurücken — dann
      // liefe er nicht mehr sichtbar unter der Leiste durch.
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Datumszeile(
            tagesSchluessel: tagesSchluessel,
            istHeute: tag.istHeute,
            // Das Blättern begrenzt der Notifier, nicht diese Zeile: Ein
            // zweiter Ort für dieselbe Regel liefe irgendwann auseinander.
            onZurueck: () => blaettern.blaettere(-1),
            onVor: () => blaettern.blaettere(1),
          ),
          ErnaehrungUebersicht(tag: tag, onDetails: _zurHerleitung),
          if (zielFehlt)
            ErnaehrungZielFehlt(
              key: const Key('ernaehrung-ziel-fehlt'),
              tag: tag,
              stammdaten: stammdaten,
            ),
          MahlzeitenListe(
            tag: tag,
            onMahlzeit: (mahlzeit) {
              if (router == null) {
                _nochNicht(
                  context,
                  mahlzeitName(mahlzeit),
                  'Der Mahlzeiten-Schirm ist von hier aus gerade nicht '
                  'erreichbar.',
                );
                return;
              }
              oeffneMahlzeit(
                router,
                tagesSchluessel: tagesSchluessel,
                mahlzeit: mahlzeit,
              );
            },
            // V12: In die Kamera, mit dieser Mahlzeit und dem **offenen**
            // Tag. Eine schon offene Kamera bleibt die einzige (#326).
            onPlus: (mahlzeit) {
              if (router == null) {
                _nochNicht(
                  context,
                  mahlzeitName(mahlzeit),
                  'Die Kamera ist von hier aus gerade nicht erreichbar.',
                );
                return;
              }
              oeffneKamera(
                router,
                tagesSchluessel: tagesSchluessel,
                mahlzeit: mahlzeit,
              );
            },
            onAufteilung: () {
              if (router == null) {
                _nochNicht(
                  context,
                  'Aufteilung',
                  'Die Aufteilung ist von hier aus gerade nicht erreichbar.',
                );
                return;
              }
              oeffneAufteilung(router);
            },
          ),
          ErnaehrungWasser(tag: tag),
          Padding(
            key: const Key('ernaehrung-rezepte'),
            padding: EdgeInsets.zero,
            child: const ErnaehrungRezepte(),
          ),
          KlappAbschnitt(
            key: const Key('ernaehrung-verlauf'),
            titel: 'Verlauf',
            kopfSchluessel: const Key('ernaehrung-verlauf-kopf'),
            inhaltSchluessel: const Key('ernaehrung-verlauf-inhalt'),
            // Der Durchschnitt in der Kopfzeile wie im Entwurf; neu gebaut
            // wird nur, wenn sich dieser Text ändert.
            hinweis: ref.watch(
              ernaehrungsVerlaufProvider(tagesSchluessel)
                  .select(verlaufHinweis),
            ),
            inhalt: () => ErnaehrungVerlaufInhalt(bis: tagesSchluessel),
          ),
          KeyedSubtree(
            key: _herleitungStelle,
            child: KlappAbschnitt(
              key: const Key('ernaehrung-herleitung'),
              aufklappen: _herleitungAuf,
              titel: 'Woher das Ziel kommt',
              // In der Auszeit sagt es die Kurzfassung auch zugeklappt
              // (#449): „1.680 kcal · pausiert“. Der Kopf bleibt einzeilig.
              hinweis: tag.zielKcal == null
                  ? null
                  : tag.pausiertDurch == null
                  ? '${formatNumber(tag.zielKcal!)} kcal'
                  : '${formatNumber(tag.zielKcal!)} kcal · pausiert',
              kopfSchluessel: const Key('ernaehrung-herleitung-kopf'),
              inhaltSchluessel: const Key('ernaehrung-herleitung-inhalt'),
              inhalt: () => ErnaehrungHerleitung(tag: tag),
            ),
          ),
          ErnaehrungWege(
            onWeg: (weg) => _nochNicht(
              context,
              weg,
              'Dieser Weg kommt in einer späteren Aufgabe. Bis dahin findest '
              'du deine Lebensmittel über „Suchen".',
            ),
            // In die Kamera (#324), mit dem **offenen** Tag — wie die
            // Suche darunter.
            onBarcode: () {
              if (router == null) {
                _nochNicht(
                  context,
                  'Barcode',
                  'Die Kamera ist von hier aus gerade nicht erreichbar.',
                );
                return;
              }
              oeffneKamera(router, tagesSchluessel: tagesSchluessel);
            },
            // In die Suche, mit dem **offenen** Tag: Wer über ‹ › gestern
            // aufhat und bucht, meint gestern (`erfassen.js`).
            onSuchen: () {
              if (router == null) {
                _nochNicht(
                  context,
                  'Suchen',
                  'Die Suche ist von hier aus gerade nicht erreichbar.',
                );
                return;
              }
              oeffneSuche(router, tagesSchluessel: tagesSchluessel);
            },
            onFoto: () => _nochNicht(
              context,
              'Foto',
              'Den Teller abzuschätzen braucht einen KI-Zugang, den es noch '
                  'nicht gibt.',
            ),
          ),
          const Hinweisfuss(_fuss),
        ],
      ),
    );
  }
}

/// Der Fußtext, wörtlich aus `docs/screens/screens/ernaehrung.js`.
///
/// **Eine Zusage, keine Beschreibung:** Seit dem 03.11.2026 ist die eigene
/// Tabelle die Wahrheit und Health bekommt eine Kopie — der Satz sagt
/// genau das, und zwar bevor jemand ihn glaubt.
const _fuss =
    'Deine Einträge liegen in dieser App; eine Kopie geht nach Apple '
    'Health. Mahlzeiten, die du in anderen Apps erfasst, zählen zusätzlich '
    'mit. Das Eiweißziel rechnet sich aus deinem Gewicht (1,6–2,0 g pro kg) '
    'und ist eine allgemeine Empfehlung, keine medizinische Bewertung. '
    'Das Wasserziel ist eine Schätzung nach einer allgemeinen Faustregel '
    '(35 ml pro kg, ohne Gewicht 2 l). '
    'Produktdaten von Open Food Facts (ODbL).';

/// #312: Den 14-Tage-Verlauf gibt es noch nicht.
///
/// **Der Abschnitt bleibt trotzdem stehen** — eine fehlende Zeile sähe aus
/// wie eine Funktion, die es nicht gibt. Gebaut wird der Inhalt erst beim
/// Aufklappen ([KlappAbschnitt.inhalt] ist eine Funktion), er kostet also
/// nichts, solange niemand hinschaut.
/// Ein Dialog statt eines stummen Knopfs. Wo ein Schirm noch fehlt, sagt
/// die App das — ein Knopf, der nichts auslöst, ist derselbe Fehler wie
/// eine Zeile, die aussieht wie eine Tür und keine ist.
void _nochNicht(BuildContext context, String titel, String text) {
  showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(titel),
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

/// Der Kopf: `‹`, das Datum, `›`.
///
/// Beide Pfeile bleiben antippbar, auch auf heute — begrenzt wird im
/// [OffenerTagNotifier]. Ein Winkel, der nicht antippbar ist, sähe aus wie
/// eine Tür und wäre keine; dass `›` auf heute nichts bewirkt, sagt seine
/// blasse Farbe.
class _Datumszeile extends StatelessWidget {
  const _Datumszeile({
    required this.tagesSchluessel,
    required this.istHeute,
    required this.onZurueck,
    required this.onVor,
  });

  final String tagesSchluessel;
  final bool istHeute;
  final VoidCallback onZurueck;
  final VoidCallback onVor;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      key: const Key('ernaehrung-datumszeile'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          _Pfeil(
            schluessel: const Key('ernaehrung-zurueck'),
            symbol: CupertinoIcons.chevron_left,
            vorlesetext: 'Tag zurück',
            farbe: ink,
            onTap: onZurueck,
          ),
          Expanded(
            child: Text(
              // Formatiert ausschließlich über `Format` (`CLAUDE.md`) und
              // über den **Kalendertag**, nicht über den rohen
              // UTC-Zeitpunkt: Der trüge kurz nach Berliner Mitternacht
              // das Vortagsdatum.
              Format.wochentagUndDatum(
                kalendertag(datumAusTag(tagesSchluessel)),
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: muted),
            ),
          ),
          _Pfeil(
            schluessel: const Key('ernaehrung-vor'),
            symbol: CupertinoIcons.chevron_right,
            vorlesetext: 'Tag vor',
            farbe: istHeute ? ink.withValues(alpha: 0.3) : ink,
            onTap: onVor,
          ),
        ],
      ),
    );
  }
}

class _Pfeil extends StatelessWidget {
  const _Pfeil({
    required this.schluessel,
    required this.symbol,
    required this.vorlesetext,
    required this.farbe,
    required this.onTap,
  });

  final Key schluessel;
  final IconData symbol;
  final String vorlesetext;
  final Color farbe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: vorlesetext,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: schluessel,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(symbol, size: 18, color: farbe),
        ),
      ),
    );
  }
}

/// Ein Signal ohne Wert — „jetzt aufklappen". Ein `ValueNotifier<bool>`
/// meldete den zweiten Tipp auf „Details" nicht mehr, weil sein Wert schon
/// `true` wäre.
class _Signal extends ChangeNotifier {
  void feuere() => notifyListeners();
}
