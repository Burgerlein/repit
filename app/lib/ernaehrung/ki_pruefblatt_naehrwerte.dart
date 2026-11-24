// Die Nährwerte im Prüfblatt der Foto-Schätzung (#392, Tim, 05.11.2026):
// Eiweiß, Kohlenhydrate und Fett je Posten und die Summe des Vorschlags.
// Vorlage: `docs/screens/screens/erfassen.js` (`SUMME`, `foodRow` mit
// `makros`).
//
// Verhalten durch `app/test/ernaehrung/ki_pruefblatt_naehrwerte_test.dart`
// vorgegeben — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// **Ein fehlender Wert steht als `–`, nie als 0** (`CLAUDE.md`, „0 ist
// keine Antwort").
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';

/// Eiweiß, Kohlenhydrate, Fett in einer Zeile (#392): `E 43 g · KH 0 g ·
/// F 5 g`. **Ein fehlender Wert steht als `–`, nie als 0** (`01`); eine
/// gemessene Null bleibt eine Null. [mindestens] stellt „mind." vor einen
/// Wert, zu dem nicht jeder Summand etwas wusste.
String makroText(Naehrwerte w, {Set<String> mindestens = const {}}) {
  String wert(String kurz, double? g) => g == null
      ? '$kurz –'
      : '$kurz ${mindestens.contains(kurz) ? 'mind. ' : ''}'
            '${formatNumber(g)} g';
  return [
    wert('E', w.eiweissG),
    wert('KH', w.kohlenhydrateG),
    wert('F', w.fettG),
  ].join(' · ');
}

/// Dasselbe zum Vorlesen — der Zustand, nicht das Zeichen (`CLAUDE.md`).
String makroVorlesen(Naehrwerte w, {Set<String> mindestens = const {}}) {
  String wert(String name, String kurz, double? g) => g == null
      ? '$name ohne Wert'
      : '$name ${mindestens.contains(kurz) ? 'mindestens ' : ''}'
            '${formatNumber(g)} Gramm';
  return [
    wert('Eiweiß', 'E', w.eiweissG),
    wert('Kohlenhydrate', 'KH', w.kohlenhydrateG),
    wert('Fett', 'F', w.fettG),
  ].join(', ');
}

/// Die Makrozeile unter Name und Menge — einzeilig, damit die Zeile in
/// jedem Zustand gleich hoch ist.
class PruefMakros extends StatelessWidget {
  const PruefMakros(this.text, {super.key, required this.vorlesen});

  final String text;
  final String vorlesen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Semantics(
      label: vorlesen,
      excludeSemantics: true,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: CupertinoDynamicColor.resolve(Palette.muted, context),
        ),
      ),
    ),
  );
}

/// Die Summe des Vorschlags (#392) — **was gebucht würde**: die
/// übernommenen Posten, dieselben, die „N Einträge buchen" zählt.
///
/// **Steht oben in der Karte**, über den Posten: Dort springt sie nicht,
/// wenn eine Zeile dazukommt, gestrichen wird oder ihre Menge ändert.
/// Während geschätzt wird, steht dieselbe Form ohne Zahl
/// ([PruefSumme.laeuft]).
///
/// Wusste nicht jeder übernommene Posten einen Wert, steht „mind." davor —
/// die Summe der bekannten ist dann eine Untergrenze, keine Antwort.
class PruefSumme extends StatelessWidget {
  const PruefSumme({super.key, required List<SchaetzPosten> this.posten});

  /// Während geschätzt wird: Beschriftung, graue Formen, keine Zahl.
  const PruefSumme.laeuft({super.key}) : posten = null;

  /// Die übernommenen Posten; `null`, solange geschätzt wird.
  final List<SchaetzPosten>? posten;

  static const _kcalStil = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const _makroStil = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final posten = this.posten;

    final String titel;
    final Widget kcal;
    final Widget makros;
    if (posten == null) {
      titel = 'Summe';
      kcal = const Platzhalter(beispiel: '1.234', stil: _kcalStil);
      // Derselbe Abstand wie in `PruefMakros` — dieselbe Höhe in beiden
      // Zuständen.
      makros = const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Platzhalter(
          beispiel: 'E 48 g · KH 51 g · F 5 g',
          stil: _makroStil,
        ),
      );
    } else {
      final summe = posten.fold(
        const Naehrwerte(),
        (summe, p) => summe + p.werte,
      );
      // Ein Wert, den ein Summand nicht kennt, macht die Summe zur
      // Untergrenze — sofern überhaupt einer etwas wusste.
      bool luecke(double? Function(Naehrwerte) feld) =>
          feld(summe) != null && posten.any((p) => feld(p.werte) == null);
      final mindestens = {
        if (luecke((w) => w.eiweissG)) 'E',
        if (luecke((w) => w.kohlenhydrateG)) 'KH',
        if (luecke((w) => w.fettG)) 'F',
      };
      final n = posten.length;
      titel = switch (n) {
        0 => 'Summe · nichts übernommen',
        1 => 'Summe · 1 Eintrag',
        _ => 'Summe · $n Einträge',
      };
      final k = summe.kcal;
      kcal = Text(
        k == null
            ? ohneWert
            : '${luecke((w) => w.kcal) ? 'mind. ' : ''}${formatNumber(k)}',
        style: _kcalStil.copyWith(color: ink),
      );
      makros = PruefMakros(
        makroText(summe, mindestens: mindestens),
        vorlesen: makroVorlesen(summe, mindestens: mindestens),
      );
    }

    return Padding(
      key: const Key('ki-pruef-summe'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                ),
              ),
              kcal,
            ],
          ),
          // Volle Breite unter der Zeile, damit auch „mind." vor jedem
          // Wert in eine Zeile passt.
          makros,
        ],
      ),
    );
  }
}
