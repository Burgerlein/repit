/* ======================================================================
   Die Zeilen der **zweiten Suchstufe** — der mitgelieferten
   Seed-Datenbank aus Bundeslebensmittelschlüssel und Open Food Facts
   (#543).

   Aufbau und Maße folgen `off_abschnitt.dart`: Beide Stufen stehen in
   derselben Liste untereinander, und zwei Zeilen, die dasselbe sagen,
   sehen gleich aus. Was sie unterscheidet, ist das Abzeichen — und das
   ist Absicht (Entwurf `erfassen.js`): Man soll sehen, woher eine Zahl
   kommt.
   ====================================================================== */

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lebensmittel_repository.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import 'erfassen_provider.dart';
import 'plus_bausteine.dart';
import 'seed_datenbank.dart';

/// Die Treffer aus dem Seed als Zeilen — leer, wenn es keine gibt.
///
/// **Kein Ladezustand und kein Leerstand.** Die Suche ist eine lokale
/// SQL-Abfrage; sie ist fertig, bevor ein Bild gezeichnet wird. Ein
/// Platzhalter, der dabei aufblitzt, wäre genau das Flackern, gegen das
/// die Leerzustandsregel gebaut ist. „Nichts gefunden" sagt weiterhin
/// genau eine Stelle — der Leerstand der ganzen Liste.
List<Widget> seedZeilen(
  List<SeedTreffer> treffer, {
  void Function(LebensmittelVorlage vorlage)? onGewaehlt,
  SuchePlus? plus,
}) => [
  for (final t in treffer)
    _SeedZeile(
      key: Key('erfassen-seed-${t.quelle}-${t.schluessel}'),
      treffer: t,
      aufTippen: () => onGewaehlt?.call(t.alsVorlage()),
      plus: plus,
    ),
];

class _SeedZeile extends ConsumerWidget {
  const _SeedZeile({
    super.key,
    required this.treffer,
    required this.aufTippen,
    required this.plus,
  });

  final SeedTreffer treffer;
  final VoidCallback aufTippen;
  final SuchePlus? plus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final vorlage = treffer.alsVorlage();
    // Dieselbe Rechnung wie an der eigenen und an der Online-Zeile, damit
    // alle drei dasselbe sagen.
    final anzeige = ref.watch(trefferVorwahlProvider(vorlage));
    final menge = anzeige?.menge ?? ohneWert;
    final kcal = anzeige?.kcal;
    final plus = this.plus;

    // Das Abzeichen nennt die Herkunft (Entwurf `erfassen.js`): „BLS" bei
    // Grundnahrung aus dem Bundeslebensmittelschlüssel, sonst die Marke.
    // Eine BLS-Zeile hat keine Marke — „Hühnerei gekocht" stammt von
    // keinem Hersteller.
    final quelle = treffer.quelle == 'bls' ? 'BLS' : treffer.marke;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 11, plus == null ? 14 : 4, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    treffer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Eine Zeile, feste Zahl: Der Text unter einem Wert ist
                  // der eigentliche Übeltäter, wenn eine Liste springt.
                  Text(
                    quelle == null ? menge : '$quelle · $menge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // `–/–` und nicht `0`: keine Angabe ist keine Null.
            Text(
              kcal == null ? ohneWert : '${formatNumber(kcal)} kcal',
              style: TextStyle(color: muted),
            ),
            if (plus != null) ...[
              const SizedBox(width: 2),
              PlusKnopf(
                zeile: 'seed-${treffer.quelle}-${treffer.schluessel}',
                gebucht: plus.istGebucht(vorlage),
                vorlesetext: plusVorlesetext(
                  name: treffer.name,
                  menge: anzeige?.menge,
                  mahlzeit: plus.mahlzeit,
                  gebucht: plus.istGebucht(vorlage),
                ),
                aufTippen: () => plus.aufPlus(vorlage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
