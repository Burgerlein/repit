import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lebensmittel_repository.dart';
import 'erfassen_provider.dart';
import 'seed_datenbank.dart';

/// Ab wie vielen Zeichen der Seed gefragt wird.
///
/// Ein einzelner Buchstabe trifft tausende der 27.000 Zeilen, und keine
/// davon ist gemeint — dieselbe Grenze, die [onlineSucheProvider] für Open
/// Food Facts zieht.
const int _abZeichen = 2;

/// Die **zweite Suchstufe**: die mitgelieferte Seed-Datenbank aus
/// Bundeslebensmittelschlüssel und Open Food Facts (#543).
///
/// Sie steht zwischen den eigenen Lebensmitteln ([suchtrefferProvider])
/// und der Online-Suche ([onlineSucheProvider]) — so legt es
/// `docs/superpowers/specs/2026-11-03-ernaehrung-design.md` fest
/// („Die Suche läuft lokal zuerst"). Der Grund steht dort auch: Die
/// Namenssuche bei Open Food Facts fand für Grundnahrung nichts
/// Brauchbares, weil OFF nur Verpacktes führt; „Toast" und
/// „hartgekochtes Ei" sind Sache des BLS.
///
/// **Diese Stufe braucht kein Netz.** Die Datei liegt auf dem Gerät, die
/// Suche ist eine SQL-Abfrage. Fällt Stufe 3 aus, bleiben 1 und 2
/// vollständig stehen.
///
/// **Gehalten, nicht je Zugriff gerechnet** (Hausregel 2): Ein
/// abgeleiteter Provider rechnet neu, wenn sich der Suchtext ändert —
/// nicht bei jedem Lesen und schon gar nicht je Bild. Genau das war `03`.
///
/// **Die Rangfolge liegt nicht hier**, sondern in [SeedDatenbank.suche];
/// diese Stufe ordnet nicht um. Sie lässt nur weg, was schon in Stufe 1
/// steht.
final seedSucheProvider = Provider<List<SeedTreffer>>((ref) {
  final text = ref.watch(suchtextProvider).trim();
  if (text.length < _abZeichen) return const [];

  final treffer = ref.watch(seedDatenbankProvider).suche(text);
  if (treffer.isEmpty) return const [];

  final eigene =
      ref.watch(suchtrefferProvider).value ?? const <LebensmittelVorlage>[];
  if (eigene.isEmpty) return treffer;

  // Was in Stufe 1 steht, ist dieselbe Sache — zweimal dasselbe
  // Lebensmittel ist kein Treffer mehr, sondern eine Verwechslungsgefahr
  // beim Buchen. Verglichen wird über die Schlüssel, nicht über den Namen:
  // Zwei Zeilen „Haferflocken" können zwei Sorten sein, und ein
  // weggelassener echter Treffer ist der teurere Fehler.
  //
  // Zwei Felder, weil eine eigene Zeile auf zwei Wegen aus derselben
  // Quelle stammen kann: `quelleSchluessel` trägt BLS-Code oder EAN seit
  // Schema v25, `barcode` trägt die EAN auch an älteren Zeilen, die vor
  // dem Seed über den Strichcode-Scan hereinkamen.
  final bekannt = <String>{
    for (final e in eigene) ...[?e.quelleSchluessel, ?e.barcode],
  };
  if (bekannt.isEmpty) return treffer;

  return [
    for (final t in treffer)
      if (!bekannt.contains(t.schluessel)) t,
  ];
});
