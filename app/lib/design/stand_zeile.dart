import 'package:flutter/cupertino.dart';

import '../core/messwert.dart';
import 'formatierung.dart';
import 'palette.dart';

/// „Stand 14:32“, bei laufender Aktualisierung „Stand 14:32 · wird
/// aktualisiert“ — Tims Wunsch vom 23.10., siehe Entwurf Abschnitt 7.3 und
/// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md:667` für den
/// genauen Wortlaut.
///
/// **Seit #200 nennt sie das Datum mit**, sobald der Stand nicht vom
/// selben Kalendertag ist: „Stand gestern 21:58", „Stand 27.10., 21:58".
/// Ohne das sah ein Stand von gestern Abend am Morgen danach nach *heute
/// Abend* aus — nach einem Zeitpunkt, der noch gar nicht war. Den
/// Wortlaut baut `Format.standZeitpunkt`; hier steht nur das Wort
/// „Stand" und der Lauf-Hinweis davor und dahinter.
///
/// Nimmt ausdrücklich ein `Bekannt<dynamic>`, kein `Messwert<dynamic>`: Die
/// anderen drei Zustände (`NochNie`, `LeerNachLauf`, `Fehlgeschlagen`) haben
/// keinen Datenstand, den man als „Stand" lesen könnte — `NochNie` gar
/// keinen Zeitstempel, die anderen beiden nur den Zeitpunkt eines
/// ergebnislosen bzw. gescheiterten Laufs. Ein Aufrufer, der über
/// `Messwert<T>` schaltet, entscheidet selbst, was er für diese drei Fälle
/// stattdessen zeigt — das ist nicht Sache dieses Bausteins (siehe
/// `task-9-tests-report.md`).
class StandZeile extends StatelessWidget {
  const StandZeile(this.messwert, {required this.jetzt, super.key});

  final Bekannt<dynamic> messwert;

  /// Der Bezugspunkt für „heute" und „gestern" — von außen, nie aus
  /// `DateTime.now()`, wie überall sonst in dieser App (`clockProvider`).
  ///
  /// **Verpflichtend, nicht vorbelegt.** Ein Vorgabewert `DateTime.now()`
  /// sähe bequemer aus und wäre die Rückkehr von #200: Wer ihn vergisst,
  /// bekommt eine Zeile, die sich richtig verhält, solange man sie am
  /// selben Tag ansieht — und falsch, sobald es darauf ankommt. Ein
  /// Pflichtparameter lässt sich nicht vergessen.
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final zeitpunkt = Format.standZeitpunkt(messwert.stand, jetzt: jetzt);
    final text = messwert.laeuft
        ? 'Stand $zeitpunkt · wird aktualisiert'
        : 'Stand $zeitpunkt';

    return Text(text, style: TextStyle(fontSize: 12, color: muted));
  }
}
