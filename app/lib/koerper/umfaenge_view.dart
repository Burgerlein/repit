// Die Übersicht „Umfänge" (#478 unter #88) — fünfzehn Maße mit Wert und
// Veränderung, darunter „Alle Messungen" als Weg zurück in einen alten Tag.
//
// API und Verhalten sind durch `app/test/shell/umfaenge_uebersicht_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/umfaenge.js`, Varianten `werte`,
// `erste` und `leer`.
//
// **Sortiert nach Wichtigkeit fürs Ziel**, nicht nach Körperregion: Wer
// hier nachsieht, will wissen, wie es steht. Das Formular sortiert
// umgekehrt — zwei Fragen, zwei Reihenfolgen.
//
// **Seit Scheibe 3 ist jede Maß-Zeile eine Tür** (#479): Sie öffnet den
// Verlauf **ihres** Maßes und trägt deshalb auch einen Winkel — der Winkel
// folgt der Tür (Tim, 27.10.2026). Dass sie ihr Maß mitträgt, ist der
// ganze Punkt: Ohne das öffneten alle fünfzehn Zeilen denselben Schirm.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/symbole.dart';
import '../design/zahlen.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../shell/router.dart';
import '../shell/ziele.dart';
import '../data/umfaenge_repository.dart';
import 'umfaenge_eintragen.dart';
import 'umfaenge_notiz.dart';
import 'umfaenge_trend.dart';
import 'umfaenge_provider.dart';
import 'umfang_detail_view.dart';
import 'umfang_loeschen.dart';

/// Öffnet die Übersicht auf dem Stapel des **aktuell gewählten** Tabs — die
/// eine Stelle, die das weiß. Von dort rufen Kachel und Zeile auf `koerper`.
void oeffneUmfaenge(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => UmfaengeSeite(router: router)));

/// Der Rahmen: Gerüst und Navigationsleiste um [UmfaengeView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`. Die Leiste trägt
/// keinen Titel — der Schirm nennt sich eine Zeile tiefer selbst, groß
/// (dieselbe Entscheidung wie bei `KoerperSeite`).
class UmfaengeSeite extends StatelessWidget {
  const UmfaengeSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      key: const Key('umfaenge-uebersicht'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(),
      child: UmfaengeView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([umfaengeUebersichtProvider]): Jeder
/// Schirm ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen,
/// dass eine Übersicht vorher geladen hat.
class UmfaengeView extends ConsumerWidget {
  const UmfaengeView({super.key, required this.router});

  final AppRouter router;

  /// Der Satz, warum man überhaupt misst — er steht auch im leeren Zustand
  /// da, denn dort ist er die eigentliche Auskunft.
  static const _messhinweis =
      'Alle 2–4 Wochen, morgens nüchtern, immer an derselben Stelle messen. '
      'Für dein Ziel zählt vor allem: Oberarm angespannt, Brust, Taille.';

  /// **Keine Diagnose.** Ein halber Zentimeter ist noch kein Befund — der
  /// Hinweis steht hier, nicht erst im Verlauf je Maß (Plan, „Keine
  /// Diagnose").
  static const _abschluss =
      'Umfänge misst du selbst. Ein halber Zentimeter Unterschied kann auch '
      'an der Stelle oder der Spannung des Maßbands liegen — erst der '
      'Verlauf über mehrere Messungen sagt etwas. Die Waage verrät dir '
      'nicht, wo das Gewicht hingeht; das Maßband schon.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(umfaengeUebersichtProvider);
    // **Zustand und Nutzlast getrennt.** Ein `is … ? … : null` ebnete beide
    // in einem Schritt ein: „lädt" und „nicht lesbar" sähen gleich aus, und
    // die fünfzehn Zeilen bekämen dieselbe leere Liste wie nach einem
    // fertigen Lauf — fünfzehn Behauptungen über eine Datenlage, die noch
    // niemand kennt (`01`).
    final lage = umfaengeLageAus(zustand);
    final gelesen = uebersichtWerte(zustand);

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrosseUeberschrift('Umfänge', einordnung: _einordnung(lage, gelesen)),
          if (lage == UmfaengeLage.unlesbar)
            const UmfangsNotiz(
              key: Key('umfaenge-unlesbar'),
              ton: UmfangsNotizTon.warnung,
              text:
                  'Die gespeicherten Umfänge ließen sich nicht lesen. '
                  'Versuch es gleich noch einmal — eintragen kannst du '
                  'trotzdem.',
            ),
          // Während gelesen wird, steht keiner der beiden Hinweise da: Ob
          // etwas erfasst ist, weiß die App dann nicht (`01`).
          if (gelesen != null && gelesen.istLeer)
            const UmfangsNotiz(
              key: Key('umfaenge-leer'),
              ton: UmfangsNotizTon.neutral,
              text:
                  'Noch keine Umfänge erfasst. Mit dem Maßband siehst du, wo '
                  'das Gewicht hingeht — das verrät die Waage nicht. Das '
                  'Formular braucht fünf Minuten.',
            ),
          if (gelesen != null && gelesen.istErsteMessung)
            const UmfangsNotiz(
              key: Key('umfaenge-erste'),
              ton: UmfangsNotizTon.neutral,
              text:
                  'Erste Messung. Ab der zweiten zeigt die App Veränderung '
                  'und Verlauf.',
            ),
          const Hinweisfuss(_messhinweis),
          _MassGruppe(
            key: const Key('umfaenge-wichtig'),
            titel: 'Für dein Ziel am wichtigsten',
            zeilen: _zeilen(gelesen, wichtig: true),
            wichtig: true,
            lage: lage,
            aufMass: (mass) => oeffneUmfangDetail(router, mass),
          ),
          _MassGruppe(
            key: const Key('umfaenge-uebrige'),
            titel: 'Übrige Maße',
            zeilen: _zeilen(gelesen, wichtig: false),
            wichtig: false,
            lage: lage,
            aufMass: (mass) => oeffneUmfangDetail(router, mass),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _EintragenKnopf(
              onTap: () => oeffneUmfaengeEintragen(router),
            ),
          ),
          // **„Alle Messungen" fällt in keinem Zustand weg** — sonst wüchse
          // der Schirm bei der ersten Messung um eine ganze Gruppe, und
          // alles darunter rutschte (`CLAUDE.md`).
          _Messtage(
            key: const Key('umfaenge-messungen'),
            lage: lage,
            messtage: gelesen?.messtage ?? const [],
            aufTag: (tag) => oeffneUmfaengeEintragen(router, tag: tag),
            // Löschen ist Ablage, keine Rechnung: Der Schirm nimmt die
            // Zeile, das Repository die Daten, und [umfaengeNeuGelesenIm]
            // lässt Verlauf, Veränderung und Kennzahlen neu rechnen —
            // gehalten im Provider, nicht je Bild (Hausregel 2).
            //
            // **Der Behälter, nicht `ref`:** Wer löscht und sofort
            // zurückgeht, nimmt diesem Widget sein `ref` weg, bevor das
            // Löschen durch ist — die Invalidierung hängt deshalb am
            // Behälter, der weiterlebt, und der Schirm darunter zeigt den
            // neuen Stand. Ein Fehler wandert nach oben: Die Liste nimmt
            // dann den Merker zurück und sagt es.
            aufLoeschen: (tag) async {
              final behaelter = ProviderScope.containerOf(
                context,
                listen: false,
              );
              await ref.read(umfaengeRepositoryProvider).loescheMesstag(tag);
              umfaengeNeuGelesenIm(behaelter);
            },
          ),
          const Hinweisfuss(_abschluss),
        ],
      ),
    );
  }

  /// „Zuletzt gemessen am 08.03." — **kein Zählerstand.** „15 Maße" wäre
  /// eine Zahl über den Katalog, nicht über Tims Daten.
  ///
  /// Drei Lagen, drei Auskünfte: Ein gescheitertes Lesen läuft nicht mehr,
  /// und „Wird gelesen …" stünde dort für immer.
  String _einordnung(UmfaengeLage lage, UebersichtGelesen? gelesen) =>
      switch (lage) {
        UmfaengeLage.laedt => 'Wird gelesen …',
        UmfaengeLage.unlesbar => 'Lesen fehlgeschlagen',
        UmfaengeLage.gelesen => switch (gelesen!.letzterTag) {
          null => 'Noch keine Messung',
          final tag =>
            'Zuletzt gemessen am ${Format.tagMonat(datumZumAnzeigen(tag))}',
        },
      };

  /// Die Zeilen einer Gruppe. **Alle fünfzehn Maße stehen da**, auch die nie
  /// gemessenen und auch, solange gelesen wird — eine Anzeige, die es gibt,
  /// hat genau eine Form.
  List<UmfangsZeile> _zeilen(
    UebersichtGelesen? gelesen, {
    required bool wichtig,
  }) {
    final zeilen =
        gelesen?.zeilen ??
        [
          for (final mass in Umfang.values)
            UmfangsZeile(
              mass: mass,
              wert: null,
              veraenderung: null,
              vorigerTag: null,
            ),
        ];
    return [
      for (final zeile in zeilen)
        if (zeile.mass.istWichtig == wichtig) zeile,
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Die Maß-Zeilen
// ─────────────────────────────────────────────────────────────────────────

class _MassGruppe extends StatelessWidget {
  const _MassGruppe({
    super.key,
    required this.titel,
    required this.zeilen,
    required this.wichtig,
    required this.lage,
    required this.aufMass,
  });

  final String titel;
  final List<UmfangsZeile> zeilen;
  final UmfaengeLage lage;

  /// Die vier wichtigen stehen farbig, die elf übrigen in Grau — nicht alle
  /// fünfzehn sind gleich interessant (Entwurf `umfaenge.js`).
  final bool wichtig;

  /// Was ein Tipp auf eine Zeile öffnet — **ihr** Maß, nicht das erste.
  final void Function(Umfang mass) aufMass;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(titel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < zeilen.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Container(height: 1, color: line),
                    ),
                  _MassZeile(
                    zeile: zeilen[i],
                    wichtig: wichtig,
                    lage: lage,
                    onTap: () => aufMass(zeilen[i].mass),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Eine Maß-Zeile: Symbolkachel, Name, Veränderung, Wert, Winkel.
///
/// **In jeder Lage eine Tür**, auch während gelesen wird und nach einem
/// gescheiterten Lauf: Der Verlauf hängt am Maß, nicht an der Zahl daneben.
class _MassZeile extends StatelessWidget {
  const _MassZeile({
    required this.zeile,
    required this.wichtig,
    required this.lage,
    required this.onTap,
  });

  final UmfangsZeile zeile;
  final bool wichtig;
  final UmfaengeLage lage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final akzent = CupertinoDynamicColor.resolve(
      wichtig ? Palette.ok : Palette.muted,
      context,
    );
    final wert = zeile.wert;

    final wertStil = TextStyle(fontWeight: FontWeight.w600, color: ink);
    final trendStil = TextStyle(fontSize: 12, color: muted);

    return Semantics(
      // Der Vorlesetext nennt den **Zustand**, nicht das Zeichen: „–/–"
      // ergibt vorgelesen „Strich Schrägstrich Strich" (`CLAUDE.md`). Und
      // „keine Werte" ist eine Aussage über Tims Daten — solange gelesen
      // wird, hörte sie ein Screenreader fünfzehnmal, ohne dass sie jemand
      // kennt.
      label: switch (lage) {
        UmfaengeLage.laedt => '${zeile.mass.deutsch}, wird gelesen',
        UmfaengeLage.unlesbar => '${zeile.mass.deutsch}, nicht lesbar',
        UmfaengeLage.gelesen =>
          wert == null
              ? '${zeile.mass.deutsch}, keine Werte'
              : '${zeile.mass.deutsch}, '
                    '${formatNumber(wert, nachkommastellen: 1)} Zentimeter',
      },
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        // Der stabile Schlüssel des Maßes steht **im** Schlüssel der Zeile:
        // Eine Zeile, die ihr Maß nicht kennt, öffnet den Schirm eines
        // anderen.
        key: Key('umfaenge-mass-${zeile.mass.schluessel}'),
        // `opaque`, damit auch der leere Platz zwischen Name und Wert
        // trifft — eine Zeile, die nur auf dem Text reagiert, fühlt sich
        // kaputt an.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: akzent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Symbole.aufloesen('ruler'),
                  size: 15,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zeile.mass.deutsch,
                      style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _trend(context, trendStil, muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _wertfeld(wertStil),
              const SizedBox(width: 6),
              // **Der Winkel folgt der Tür** (Tim, 27.10.2026): Seit
              // Scheibe 3 führt diese Zeile wirklich irgendwohin, und ohne
              // Winkel sähe die Tür aus wie reine Anzeige.
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Der Wert rechts. Solange gelesen wird, steht dort die **graue Form**
  /// und nicht `–/–`: Der Platzhalter gehört allein in den Ladezustand
  /// (`CLAUDE.md`).
  Widget _wertfeld(TextStyle stil) {
    final wert = zeile.wert;
    if (wert != null) {
      return Text('${formatNumber(wert, nachkommastellen: 1)} cm', style: stil);
    }
    if (lage == UmfaengeLage.laedt) {
      return Platzhalter(beispiel: '000,0 cm', stil: stil);
    }
    return Text(ohneWert, style: stil);
  }

  /// Die Veränderungszeile. **Sie sagt erst etwas, wenn etwas bekannt
  /// ist** — „noch nicht gemessen" während des Lesens wäre `01`,
  /// fünfzehnmal.
  Widget _trend(BuildContext context, TextStyle stil, Color muted) {
    final schluessel = Key('umfaenge-trend-${zeile.mass.schluessel}');
    return switch (lage) {
      UmfaengeLage.laedt => Platzhalter(
        key: schluessel,
        beispiel: '+0,0 cm seit 00.00.',
        stil: stil,
      ),
      UmfaengeLage.unlesbar => Text(
        'nicht lesbar',
        key: schluessel,
        style: stil,
      ),
      UmfaengeLage.gelesen => Text(
        _trendtext(zeile),
        key: schluessel,
        style: stil.copyWith(
          color: umfangsTrendFarbe(context, zeile.veraenderung, muted),
        ),
      ),
    };
  }
}

/// „+0,6 cm seit 30.08." — oder der Satz, warum es keine Zahl gibt.
///
/// **Keine Null als Trend.** Mit einem Punkt gibt es keine Veränderung, auch
/// keine von null; „unverändert" behauptete einen Vergleich, den es nicht
/// gab.
String _trendtext(UmfangsZeile zeile) {
  final veraenderung = zeile.veraenderung;
  if (veraenderung == null) {
    return zeile.wert == null ? 'noch nicht gemessen' : 'erste Messung';
  }
  final seit = zeile.vorigerTag == null
      ? ''
      : ' seit ${Format.tagMonat(datumZumAnzeigen(zeile.vorigerTag!))}';
  // Zahl und Farbe stehen in `umfaenge_trend.dart` — dieselbe Schreibweise
  // wie auf dem Verlaufsschirm, nur hängt dort das Datum als Kennzeichen
  // daneben statt als „seit …" am Satz.
  return '${umfangsVeraenderungText(veraenderung)}$seit';
}

// ─────────────────────────────────────────────────────────────────────────
// „Alle Messungen"
// ─────────────────────────────────────────────────────────────────────────

/// Eine Zeile je Messtag, antippbar — sie öffnet das Formular für **genau
/// diesen** Tag. **Nach links wischen löscht ihn**, mit Rückfrage (#486):
/// Tippen bleibt die Tür ins Formular, Überschreiben der Normalfall; das
/// Wischen ist fürs Loswerden — der Fall „am falschen Tag eingetragen".
///
/// Ohne diese Liste führte der einzige Weg zu einem alten Tag über das
/// Datumsfeld, und dafür müsste man wissen, wann man gemessen hat (Tim,
/// 11.11.2026).
class _Messtage extends StatefulWidget {
  const _Messtage({
    super.key,
    required this.lage,
    required this.messtage,
    required this.aufTag,
    required this.aufLoeschen,
  });

  final UmfaengeLage lage;
  final List<UmfangsMesstag> messtage;
  final void Function(String tag) aufTag;

  /// Löscht den Tag in der Ablage und stößt das Neu-Lesen an. Läuft erst
  /// nach bestätigter Rückfrage.
  final Future<void> Function(String tag) aufLoeschen;

  @override
  State<_Messtage> createState() => _MesstageState();
}

class _MesstageState extends State<_Messtage> {
  /// Was weggewischt ist, verschwindet sofort aus der Liste — der Provider
  /// liefert bis zum Ende des Neu-Lesens noch den alten Stand, und ein
  /// weggewischtes `Dismissible`, das weiter im Baum steht, ist ein Fehler
  /// (dieselbe Form wie `_weggewischt` in `wasser_blatt.dart`).
  final Set<String> _weggewischt = {};

  /// Das Löschen ist gescheitert; die Zeile steht wieder da und der
  /// Hinweis sagt es. Eine Zeile, die verschwindet, während der Wert noch
  /// in der Ablage liegt, wäre eine falsche Auskunft — dasselbe Argument
  /// wie bei `_panne` in `gewicht_eintragen.dart`.
  bool _panne = false;

  /// Die Messtage ohne die schwebend gelöschten — was der Schirm wirklich
  /// zeigt. Auch die Rückfrage rechnet hiermit: „deine einzige Messung"
  /// muss zum sichtbaren Stand passen, nicht zum noch nicht nachgeladenen.
  List<UmfangsMesstag> get _sichtbar => [
    for (final messtag in widget.messtage)
      if (!_weggewischt.contains(messtag.tag)) messtag,
  ];

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // Steht ein Tag nicht mehr im gelesenen Stand, ist das Löschen
    // angekommen — der Merker hat ausgedient. Ohne das bliebe ein später
    // neu eingetragener gleicher Tag unsichtbar.
    _weggewischt.removeWhere(
      (tag) => !widget.messtage.any((messtag) => messtag.tag == tag),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Alle Messungen'),
        if (_panne)
          const UmfangsNotiz(
            key: Key('umfaenge-loeschen-panne'),
            ton: UmfangsNotizTon.warnung,
            text:
                'Die Messung ließ sich nicht löschen — sie steht unverändert '
                'in der Liste. Versuch es gleich noch einmal.',
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(child: _inhalt(context, line, muted)),
        ),
      ],
    );
  }

  /// Drei Lagen, drei Auskünfte. **„Noch keine Messung" erst nach dem
  /// Lauf:** Während gelesen wird, weiß niemand, ob etwas erfasst ist, und
  /// ein gescheitertes Lesen ist etwas anderes als eine leere Tabelle.
  Widget _inhalt(BuildContext context, Color line, Color muted) {
    final satzStil = TextStyle(fontSize: 13, height: 1.35, color: muted);
    final sichtbar = _sichtbar;

    return switch (widget.lage) {
      UmfaengeLage.laedt => Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Platzhalter(beispiel: '00.00.0000', stil: satzStil),
      ),
      UmfaengeLage.unlesbar => Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Text('Die Liste ließ sich nicht lesen.', style: satzStil),
      ),
      UmfaengeLage.gelesen when sichtbar.isEmpty => Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Text(
          'Noch keine Messung. Sobald du eine einträgst, steht sie hier '
          'und lässt sich wieder öffnen.',
          style: satzStil,
        ),
      ),
      UmfaengeLage.gelesen => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sichtbar.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Container(height: 1, color: line),
              ),
            _wischbareZeile(sichtbar[i]),
          ],
        ],
      ),
    };
  }

  Widget _wischbareZeile(UmfangsMesstag messtag) {
    final datum = Format.tag(datumZumAnzeigen(messtag.tag));
    return WischLoeschen(
      aktion: 'Messung vom $datum löschen',
      frage: (context) => umfangLoeschenFrage(
        context,
        titel: 'Messung vom $datum löschen?',
        text: _frageText(messtag),
      ),
      aufBestaetigt: () => _loesche(messtag.tag),
      child: _Messzeile(
        messtag: messtag,
        onTap: () => widget.aufTag(messtag.tag),
      ),
    );
  }

  /// Zeile sofort weg, dann die Ablage. **Scheitert die, kommt die Zeile
  /// zurück** — samt Hinweis: Ohne Satz tippt man wieder und wieder auf
  /// eine Geste, die nichts tut.
  Future<void> _loesche(String tag) async {
    setState(() {
      _weggewischt.add(tag);
      _panne = false;
    });
    try {
      await widget.aufLoeschen(tag);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weggewischt.remove(tag);
        _panne = true;
      });
    }
  }

  /// **Die Rückfrage nennt, was verschwindet** — „das eine Maß" oder „alle
  /// 13 Maße", und beim einzigen Messtag auch das (Entwurf `umfaenge.js`,
  /// Zustände `loeschen-tag` und `loeschen-letzter`). Gezählt wird der
  /// **sichtbare** Stand: Schwebt gerade eine andere Löschung, ist die
  /// verbleibende Zeile die einzige — und genau das soll die Rückfrage
  /// sagen.
  String _frageText(UmfangsMesstag messtag) {
    final anzahl = messtag.anzahlMasse;
    final menge = anzahl == 1
        ? 'Das eine Maß dieses Tages verschwindet'
        : 'Alle $anzahl Maße dieses Tages verschwinden';
    final folge = _sichtbar.length == 1
        ? ' aus jedem Verlauf. Es ist deine einzige Messung.'
        : ' aus jedem Verlauf und jeder Veränderung.';
    return '$menge$folge Das lässt sich nicht rückgängig machen.';
  }
}

class _Messzeile extends StatelessWidget {
  const _Messzeile({required this.messtag, required this.onTap});

  final UmfangsMesstag messtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final anzahl = messtag.anzahlMasse;

    return GestureDetector(
      // Der Tagesschlüssel steht **im** Schlüssel der Zeile: Eine Zeile, die
      // ihren Tag nicht kennt, kann ihn nicht öffnen.
      key: Key('umfaenge-messung-${messtag.tag}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                Format.tag(datumZumAnzeigen(messtag.tag)),
                style: TextStyle(color: ink),
              ),
            ),
            Text(
              anzahl == 1 ? 'ein Maß' : '$anzahl Maße',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(width: 8),
            // Der Winkel folgt der Tür: Diese Zeile führt wirklich
            // irgendwohin.
            Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: muted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// „Maße eintragen" — in jedem Zustand da. Gerade ohne Messung ist er der
/// einzige sinnvolle nächste Schritt.
class _EintragenKnopf extends StatelessWidget {
  const _EintragenKnopf({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: const Key('umfaenge-eintragen-knopf'),
      color: CupertinoDynamicColor.resolve(Palette.river, context),
      padding: const EdgeInsets.symmetric(vertical: 12),
      borderRadius: BorderRadius.circular(12),
      onPressed: onTap,
      child: const Text(
        'Maße eintragen',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
