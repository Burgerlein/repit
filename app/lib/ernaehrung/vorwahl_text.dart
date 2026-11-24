// Die **zweite Zeile eines Suchtreffers**: was „+" bucht, als Text, und
// die Kalorien genau dieser Menge (#438, V24). Sie ersetzt „je 100 g".
//
// API und Vertrag sind durch `app/test/ernaehrung/direkt_buchen_test.dart`
// vorgegeben (siehe dessen Dateikopf) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die Zeile sagt, was „+" bucht.** Deshalb rechnet sie nicht selbst,
// sondern aus derselben Vorwahl ([portionsVorwahl], #325) und derselben
// Vorbelegung ([vorgewaehlteMenge]) wie das Blatt, das
// `ErfassenNotifier.bucheDirekt` unverändert bucht. Die Wörter kommen aus
// `portions_text.dart`, damit „2 Bon (11,8 g)" in der Suche genauso
// aussieht wie auf dem Mahlzeiten-Schirm.
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';
import 'erfassen_formular.dart';
import 'portions_text.dart';

/// Was „+" für [vorlage] bucht: die Menge als Text und die Kalorien dieser
/// Menge.
///
/// - Zuletzt mit Portion gebucht und die Portion gibt es noch: „2 Bon
///   (11,8 g)".
/// - Zuletzt in Gramm, oder die Portion gibt es nicht mehr: „80 g" bzw.
///   „250 ml" — die Menge, mit der das Blatt „g" vorwählt.
/// - Nie gebucht, und jeder Online-Treffer (ohne ID): „100 g" bzw.
///   „100 ml".
///
/// [letzte] ist die jüngste Buchung des Lebensmittels, wie sie
/// `letztePortionenProvider` hält. Bei einem Treffer ohne ID zählt sie
/// nicht — das Blatt kennt dann auch keine.
///
/// [portionen] sind die Portionen, die das Blatt aus der Tabelle bekäme.
/// **Ohne sie gilt der Schnappschuss von [letzte]**: Die Portion zählt als
/// vorhanden, mit dem Namen und den Gramm von damals. Ist sie inzwischen
/// gelöscht oder geändert, wählt das Blatt anders vor als diese Zeile —
/// wer die Portionen kennt, gibt sie deshalb mit. *Festlegung des
/// Implementierungs-Agenten, nicht von Tim: Plan und Test kennen den
/// Parameter nicht.*
///
/// **`kcal` ist `null`, wenn die Vorlage keine Kalorien kennt**, nicht
/// `0` (`CLAUDE.md`, „0 ist keine Antwort auf ‚kein Wert'").
({String menge, double? kcal}) vorwahlAnzeige({
  required LebensmittelVorlage vorlage,
  Eintrag? letzte,
  List<Portion>? portionen,
}) {
  // Wie `ErfassenNotifier.oeffneFormular`: Ohne ID gibt es keine Vorwahl,
  // sonst rechnet sie [portionsVorwahl] über die vorhandenen Portionen.
  final eigen = vorlage.id != null;
  final liste = eigen
      ? (portionen ?? _ausSchnappschuss(letzte))
      : const <Portion>[];
  final vorwahl = eigen
      ? portionsVorwahl(
          letzte: letzte == null
              ? null
              : LetzteBuchung(
                  mengeG: letzte.mengeG,
                  portionId: letzte.portionId,
                  portionG: letzte.portionG,
                ),
          vorhandenePortionen: {
            for (final p in liste)
              if (p.id != null) p.id!,
          },
        )
      : null;

  final (:mengeG, :portion) = vorgewaehlteMenge(
    vorwahl: vorwahl,
    portionen: liste,
  );
  // Aus einer Vorwahl entsteht immer eine lesbare Menge; fehlte sie doch,
  // steht ein Strich da und keine erfundene Zahl.
  if (mengeG == null) return (menge: '–', kcal: null);

  final fluessig = vorlage.fluessig;
  final text = portion == null
      ? portionsMenge(mengeG, fluessig: fluessig)
      : gebuchtePortion(
          mengeG: mengeG,
          name: portion.name,
          portionG: portion.mengeG,
          fluessig: fluessig,
        );
  return (menge: text, kcal: vorlage.je100g.fuerMenge(mengeG).kcal);
}

/// Die Portion aus dem Schnappschuss der letzten Buchung als Liste — leer,
/// wenn ohne Portion gebucht wurde oder der Schnappschuss unvollständig
/// ist.
List<Portion> _ausSchnappschuss(Eintrag? letzte) {
  final id = letzte?.portionId;
  final name = letzte?.portionName;
  final g = letzte?.portionG;
  if (id == null || name == null || g == null || g <= 0) return const [];
  return [Portion(id: id, name: name, mengeG: g)];
}
