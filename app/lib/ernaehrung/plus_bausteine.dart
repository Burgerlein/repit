// Die Bausteine des „+" je Trefferzeile (#440, Schnitt 2 von #385) —
// `docs/screens/screens/erfassen.js`, `ZULETZT_PLUS`, `TREFFER_PLUS` und
// Zustand `vorschlag-gebucht`; `foodRow({knopf})` in
// `docs/screens/components.js`, `.foodrow .plus.rand` und `.note` in
// `components.css`. Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Entscheidung 10, V24–V28.
//
// Hier wird nur gezeichnet und gemeldet. Was gebucht, gezählt und
// zurückgenommen wird, hält `SucheSeite` (`erfassen_weg.dart`); die
// Trefferzeilen setzen den Knopf in `suche_view.dart` und
// `off_abschnitt.dart`.
//
// Verhalten und Schlüssel gibt `app/test/ernaehrung/erfassen_plus_test.dart`
// vor.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../design/palette.dart';

/// Wie ein Satz die Mahlzeit nennt: „zum Frühstück", „zu Mittag", „zu
/// Abend", „als Snack" — im Suchfeld (V23), im Band und im Vorlesetext
/// des „+".
String mahlzeitBezug(Mahlzeit mahlzeit) => switch (mahlzeit) {
  Mahlzeit.fruehstueck => 'zum Frühstück',
  Mahlzeit.mittag => 'zu Mittag',
  Mahlzeit.abend => 'zu Abend',
  Mahlzeit.snack => 'als Snack',
};

/// Was eine Suche mit „+" braucht: wohin gebucht wird, wie, und was in
/// dieser Sitzung schon gebucht ist.
///
/// Ohne [SuchePlus] zeigt die Suche keinen Knopf — so als Auswahl im
/// KI-Prüfblatt, die nichts bucht, sondern ein Lebensmittel zurückgibt.
@immutable
class SuchePlus {
  const SuchePlus({
    required this.mahlzeit,
    required this.aufPlus,
    required this.istGebucht,
  });

  /// Die Mahlzeit, auf die „+" bucht — nur für den Vorlesetext. Gebucht
  /// wird über `vorgewaehlteMahlzeit`, dieselbe Regel.
  final Mahlzeit mahlzeit;

  /// „+" oder der Haken an einer Zeile (V28: der Haken bucht noch einmal).
  final void Function(LebensmittelVorlage vorlage) aufPlus;

  /// Ob die Zeile dieser Vorlage in der Sitzung etwas gebucht hat (V27).
  final bool Function(LebensmittelVorlage vorlage) istGebucht;
}

/// Der Knopf rechts in der Trefferzeile: umrandetes „+", nach dem Buchen
/// ein gefüllter Haken (`.foodrow .plus.rand`, `.gebucht`).
///
/// [zeile] ist das Suffix des Zeilenschlüssels (`treffer-12`,
/// `off-<barcode>`). Der Knopf heißt `erfassen-plus-<zeile>` in beiden
/// Formen; den Haken trägt `erfassen-gebucht-<zeile>` darin.
class PlusKnopf extends StatelessWidget {
  const PlusKnopf({
    super.key,
    required this.zeile,
    required this.gebucht,
    required this.vorlesetext,
    required this.aufTippen,
  });

  final String zeile;
  final bool gebucht;
  final String vorlesetext;
  final VoidCallback aufTippen;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    return Semantics(
      button: true,
      label: vorlesetext,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('erfassen-plus-$zeile'),
        behavior: HitTestBehavior.opaque,
        onTap: aufTippen,
        // 44 Punkte Tippfläche um einen Kreis von 30 (`.plus.rand`).
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gebucht ? river : null,
                border: gebucht ? null : Border.all(color: river, width: 1.6),
              ),
              child: gebucht
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      key: Key('erfassen-gebucht-$zeile'),
                      size: 17,
                      color: surface,
                    )
                  : Icon(CupertinoIcons.add, size: 18, color: river),
            ),
          ),
        ),
      ),
    );
  }
}

/// Der Vorlesetext des Knopfs: „Haferflocken kernig, 80 Gramm zum
/// Frühstück buchen", nach dem Buchen „Haferflocken kernig, gebucht"
/// (Spec, „Vorlesetexte"). Die Einheiten werden ausgeschrieben, damit
/// nicht „80 g" buchstabiert wird.
String plusVorlesetext({
  required String name,
  required String? menge,
  required Mahlzeit mahlzeit,
  required bool gebucht,
}) {
  if (gebucht) return '$name, gebucht';
  final gesprochen = (menge ?? '')
      .replaceAllMapped(RegExp(r'(\d) g\b'), (m) => '${m[1]} Gramm')
      .replaceAllMapped(RegExp(r'(\d) ml\b'), (m) => '${m[1]} Milliliter');
  return gesprochen.isEmpty
      ? '$name ${mahlzeitBezug(mahlzeit)} buchen'
      : '$name, $gesprochen ${mahlzeitBezug(mahlzeit)} buchen';
}

/// Das Band nach einer Buchung: „Haferflocken kernig · 80 g zum Frühstück
/// gebucht." und „Rückgängig" (V26, V27) — dieselbe Geste wie
/// `mahlzeit-rueckgaengig`, gezeichnet als `.note` im Ton `good` wie im
/// Entwurf.
class ErfassenBand extends StatelessWidget {
  const ErfassenBand({
    super.key,
    required this.text,
    required this.aufRueckgaengig,
  });

  final String text;
  final VoidCallback aufRueckgaengig;

  @override
  Widget build(BuildContext context) {
    final ok = CupertinoDynamicColor.resolve(Palette.ok, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    // Die farbige Kante wird mit der Karte beschnitten, nicht selbst
    // abgerundet (`CLAUDE.md`, „Farbige Kanten an abgerundeten Karten").
    return ClipRRect(
      key: const Key('erfassen-band'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(ok.withValues(alpha: 0.07), surface),
          border: Border.all(color: ok.withValues(alpha: 0.22), width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: ok),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 11),
                  child: Text(
                    text,
                    // Zwei Zeilen fest: Ein langer Name bricht um, statt
                    // das Band je nach Lebensmittel springen zu lassen.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, height: 1.35, color: ink),
                  ),
                ),
              ),
              CupertinoButton(
                key: const Key('erfassen-rueckgaengig'),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                minimumSize: const Size(44, 44),
                onPressed: aufRueckgaengig,
                child: Text(
                  'Rückgängig',
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
      ),
    );
  }
}
