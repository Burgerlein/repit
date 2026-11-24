// Der Ziele-Schirm, erster Schnitt (#448 unter #404): nur der Abschnitt
// „Ereignisse“ mit den Auszeiten. Wettkämpfe und Körperziel stehen als ein
// Satz da, bis #41 sie baut — der Ort ist damit der endgültige.
//
// Verhalten durch `app/test/ziele/ziele_view_test.dart` vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`). Aufbau nach `docs/screens/screens/auszeit.js`
// (`LISTE`, `LEER`), Begründungen in der Auszeit-Spec in
// `docs/superpowers/specs/` (V8–V11, V18).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'auszeit_blatt.dart';
import 'auszeit_texte.dart';
import 'ziele_bausteine.dart';
import 'ziele_zustand.dart';

/// Schiebt den Ziele-Schirm auf den Stapel des **aktuell gewählten** Tabs
/// (V18) — ein Menüpunkt wechselt nie den Tab (`CLAUDE.md`).
void oeffneZiele(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const ZieleSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste mit dem „+“.
///
/// **Kein eigener `Navigator`** — den stellt der Gastgeber. Zwei
/// verschachtelte Stapel schließen die gepushte Seite sofort wieder
/// (`CLAUDE.md`).
class ZieleSeite extends StatelessWidget {
  const ZieleSeite({super.key});

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
    navigationBar: CupertinoNavigationBar(
      // `Builder`, damit das Blatt einen Kontext **unter** dem Navigator
      // bekommt.
      trailing: Builder(
        builder: (context) => CupertinoButton(
          key: const Key('ziele-plus'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 36),
          onPressed: () => zeigeAuszeitBlatt(context),
          child: const Icon(
            CupertinoIcons.plus_circle,
            size: 24,
            semanticLabel: 'Auszeit eintragen',
          ),
        ),
      ),
    ),
    child: const ZieleView(),
  );
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([zieleEreignisseProvider]): Jeder
/// Schirm ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen,
/// dass eine Übersicht vorher geladen hat.
class ZieleView extends ConsumerWidget {
  const ZieleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ereignisse = ref.watch(zieleEreignisseProvider);

    // Vollständig über den sealed-Typ: Käme ein Zustand dazu, zeigte der
    // Analyzer genau hier hin.
    final List<Widget> abschnitt = switch (ereignisse) {
      // Solange gelesen wird, steht der Kopf da und darunter nichts. Das
      // dauert Millisekunden; ein „Keine Auszeit eingetragen“ wäre `01`.
      EreignisseLaden() => const [],
      EreignisseUnlesbar() => const [
        ZieleNotiz(
          key: Key('ziele-unlesbar'),
          ton: ZieleTon.neutral,
          text:
              'Die eingetragenen Auszeiten ließen sich gerade nicht lesen. '
              'Solange rechnet das Kalorienziel ohne Pause.',
        ),
      ],
      EreignisseGelesen(zeilen: []) => const [_Leer(key: Key('ziele-leer'))],
      EreignisseGelesen(:final zeilen, :final freigabe) => [
        _Liste(zeilen: zeilen),
        if (freigabe)
          const ZieleNotiz(
            key: Key('ziele-freigabe'),
            ton: ZieleTon.warnung,
            text: auszeitFreigabe,
          ),
      ],
    };

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift(
            'Ziele',
            einordnung:
                'Wettkämpfe, Körperziel und Ereignisse · steuern den Plan',
          ),
          // Was #41 bringt, steht als Satz da — kein leerer Abschnitt, der
          // wie eine kaputte Funktion aussähe. Wortlaut wie gezeichnet,
          // auch wenn „Vorläufige Werte“ in der App heute unter Mehr ›
          // Verwalten hängt (Spec; die Abweichung gehört zu #307).
          const ZieleNotiz(
            ton: ZieleTon.neutral,
            text:
                'Wettkämpfe kommen mit dem Ziele-Schirm (#41). Dein '
                'Körperziel trägst du bis dahin unter Einstellungen › '
                'Vorläufige Werte ein.',
          ),
          Column(
            key: const Key('ziele-ereignisse'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const ZieleAbschnittKopf('Ereignisse'), ...abschnitt],
          ),
        ],
      ),
    );
  }
}

/// Kein Ereignis eingetragen. **Nennt die Folge, nicht den Mangel.**
class _Leer extends StatelessWidget {
  const _Leer({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ZieleNotiz(
        ton: ZieleTon.neutral,
        rand: EdgeInsets.symmetric(horizontal: 14),
        text:
            'Keine Auszeit eingetragen. Trägst du eine OP oder Krankheit '
            'ein, setzt das Kalorienziel für diese Tage den Aufschlag fürs '
            'Körperziel aus.',
      ),
      Hinweisfuss(
        'Nichts davon steht im Quelltext. Was hier nicht eingetragen ist, '
        'kennt die App nicht.',
      ),
    ],
  );
}

/// Die Liste der Ereignisse, eine Karte, Zeilen mit Trennlinie.
class _Liste extends StatelessWidget {
  const _Liste({required this.zeilen});

  final List<AuszeitZeile> zeilen;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < zeilen.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: 1, color: linie),
                ),
              _Zeile(zeile: zeilen[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({required this.zeile});

  final AuszeitZeile zeile;

  @override
  Widget build(BuildContext context) {
    final e = zeile.ereignis;
    final (symbol, kachel, symbolFarbe) = _kachel(e.art);
    // Der Vorlesetext nennt den Zustand, nicht die Zeichen.
    return Semantics(
      key: Key('auszeit-zeile-${e.id}'),
      label: zeile.vorlesen,
      button: true,
      excludeSemantics: true,
      child: IconRow(
        title: zeile.titel,
        subtitle: zeile.untertitel,
        symbol: symbol,
        accent: kachel,
        symbolFarbe: symbolFarbe,
        onTap: () => zeigeAuszeitBlatt(context, ereignis: e),
      ),
    );
  }

  /// Symbol, Kachel und Symbolfarbe je Art, wie in `auszeit.js`.
  /// Verletzung nimmt den Verbandskasten auf der Farbe der Krankheit,
  /// Urlaub den Kalender auf `bib` wie das „nur markiert“ in `ziele.js` —
  /// so gebaut und von Tim am 10.11.2026 ins Board übernommen (#465).
  static (String, Color, Color?) _kachel(EreignisArt art) => switch (art) {
    EreignisArt.op => ('calendar', Palette.rest, Palette.ink),
    EreignisArt.krankheit => ('checkmark', Palette.warn, null),
    EreignisArt.verletzung => ('cross.case', Palette.warn, null),
    EreignisArt.urlaub => ('calendar', Palette.bib, Palette.ink),
  };
}
