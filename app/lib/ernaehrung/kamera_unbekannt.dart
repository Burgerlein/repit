// Zustand `unbekannt` des Kamera-Schirms (#324) —
// `docs/screens/screens/erfassen.js`. Die Abläufe liegen in
// `kamera_seite.dart`.
import 'package:flutter/cupertino.dart';

import '../design/glas_abstand.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import 'erfassen_bausteine.dart';
import 'kamera_bausteine.dart';

/// Zustand `unbekannt` — **kein Fehler, sondern eine Einladung**
/// (`erfassen.js`): anlegen oder stattdessen suchen.
class UnbekanntAnsicht extends StatelessWidget {
  const UnbekanntAnsicht({
    super.key,
    required this.lage,
    required this.aufAbbrechen,
    required this.aufAnlegen,
    required this.aufSuchen,
  });

  final Unbekannt lage;
  final VoidCallback aufAbbrechen;
  final VoidCallback aufAnlegen;
  final VoidCallback aufSuchen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final name = lage.name;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const Key('kamera-abbrechen'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 36),
          onPressed: aufAbbrechen,
          child: const Text('Abbrechen'),
        ),
        middle: const Text('Strichcode unbekannt'),
      ),
      // Erst unterhalb des Gerüsts zählt `MediaQuery.padding.top` die
      // durchscheinende Navigationsleiste mit; mit dem äußeren `context`
      // begänne die erste Karte hinter der Leiste (#351, wie #348).
      child: Builder(
        builder: (innen) => SingleChildScrollView(
          key: const Key('kamera-unbekannt'),
          padding:
              GlasAbstand.of(innen) + const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsetCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    name == null
                        ? 'Strichcode ${lage.code} ist in Open Food Facts nicht '
                              'hinterlegt. Das kommt vor — die Datenbank wird '
                              'von Nutzern gepflegt.'
                        : 'Open Food Facts kennt Strichcode ${lage.code} als '
                              '„$name", aber ohne Kalorienangabe. Ohne sie '
                              'lässt es sich nicht buchen — sie steht auf der '
                              'Packung.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: ink),
                  ),
                ),
              ),
              const ErfassenKapitel('Was du tun kannst'),
              InsetCard(
                child: Column(
                  children: [
                    _Weg(
                      key: const Key('kamera-unbekannt-anlegen'),
                      symbol: CupertinoIcons.plus_circle,
                      farbe: Palette.river,
                      titel: 'Produkt anlegen',
                      untertitel: 'Name und Nährwerte von der Packung',
                      aufTippen: aufAnlegen,
                    ),
                    const ErfassenTrenner(),
                    // **Angekündigt, nicht versteckt** (Tim, 18.11.2026):
                    // Genau hier müsste man sonst die Nährwerttabelle
                    // abtippen, und genau hier soll später das Foto
                    // stehen. Eine fehlende Zeile sähe aus wie eine
                    // Funktion, die es nicht gibt — die Regel aus
                    // `CLAUDE.md` („Noch nicht angefangene Features ...
                    // dort steht ein Satz, bis das Feature dran ist").
                    // Braucht den KI-Zugang (#287), deshalb nicht jetzt.
                    const _Weg(
                      key: Key('kamera-unbekannt-foto'),
                      symbol: CupertinoIcons.camera,
                      farbe: Palette.bib,
                      titel: 'Nährwerttabelle abfotografieren',
                      untertitel: 'kommt später — dann füllt sich das '
                          'Formular von selbst',
                      aufTippen: null,
                    ),
                    const ErfassenTrenner(),
                    _Weg(
                      key: const Key('kamera-unbekannt-suchen'),
                      symbol: CupertinoIcons.list_bullet,
                      farbe: Palette.deep,
                      titel: 'Stattdessen suchen',
                      untertitel:
                          'vielleicht steht es unter einem anderen Namen drin',
                      aufTippen: aufSuchen,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  'Was du anlegst, landet in deiner eigenen Datenbank auf '
                  'diesem Gerät.',
                  style: TextStyle(fontSize: 12, height: 1.35, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine Zeile unter „Was du tun kannst" — dieselbe Form wie
/// „Lebensmittel anlegen" in der Suche.
class _Weg extends StatelessWidget {
  const _Weg({
    super.key,
    required this.symbol,
    required this.farbe,
    required this.titel,
    required this.untertitel,
    required this.aufTippen,
  });

  final IconData symbol;
  final CupertinoDynamicColor farbe;
  final String titel;
  final String untertitel;

  /// `null` bei einem Weg, den es noch nicht gibt: Die Zeile steht da,
  /// abgeblendet, und reagiert nicht. Ein Winkel wäre eine Tür, hinter
  /// der nichts liegt.
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    // Aufgelöst, nicht geerbt: Eine unaufgelöste dynamische Farbe malt
    // Flutter mit ihrem Hellwert — schwarz auf der dunklen Karte (siehe
    // `_AnlegenZeile` in `suche_view.dart`).
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    // Ein Weg, den es noch nicht gibt, steht abgeblendet da und trägt
    // keinen Winkel: Der Winkel folgt der Tür — dieselbe Regel wie im
    // Entwurfsboard.
    final kommtNoch = aufTippen == null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Opacity(
          opacity: kommtNoch ? 0.55 : 1,
          child: Row(
            children: [
              Icon(
                symbol,
                size: 20,
                color: CupertinoDynamicColor.resolve(farbe, context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titel,
                      style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      untertitel,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              if (!kommtNoch)
                Icon(CupertinoIcons.chevron_forward, size: 14, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
