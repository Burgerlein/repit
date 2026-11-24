// Die Formularlogik der Auszeit (#448 unter #404): Vorbelegung, Nachziehen
// des Endes, Notiz und der Weg zum `Ereignis` — ohne Widget prüfbar.
//
// API und Vertrag sind durch `app/test/ziele/auszeit_formular_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`). Spec: die Auszeit-Spec in
// `docs/superpowers/specs/`, V4, V5 und V6.
import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ereignisse.dart';

/// Was im Blatt „Auszeit eintragen“/„Auszeit ändern“ gerade steht.
///
/// **Werttyp:** Jede `mit…`-Methode gibt ein neues Formular zurück und
/// lässt dieses unverändert; `==` und `hashCode` gehen über den Inhalt.
@immutable
class AuszeitFormular {
  const AuszeitFormular._({
    required this.art,
    required this.von,
    required this.bis,
    required this.notiz,
    required this.bisVonHand,
  });

  /// Ein neues Formular (V4): OP, Beginn am Esstag [heute], Ende vorbelegt
  /// mit der Regel aus dem Kern (`opErholungBis`) — kein Datum im
  /// Quelltext.
  factory AuszeitFormular.neu({required String heute}) => AuszeitFormular._(
    art: EreignisArt.op,
    von: heute,
    bis: _vorbelegtesEnde(EreignisArt.op, heute),
    notiz: null,
    bisVonHand: false,
  );

  /// Das Ändern-Blatt (V7): vorbelegt mit [e]. **Das Ende gilt als von
  /// Hand gesetzt** (V4) — es steht so in der Tabelle, weil jemand es so
  /// gewollt hat.
  factory AuszeitFormular.fuer(Ereignis e) => AuszeitFormular._(
    art: e.art,
    von: e.von,
    bis: e.bis,
    notiz: _bereinigt(e.notiz),
    bisVonHand: true,
  );

  final EreignisArt art;

  /// Erster Tag, einschließlich, als ISO-Tag.
  final String von;

  /// Letzter Tag, einschließlich, als ISO-Tag. Liegt nie vor [von] (V5).
  final String bis;

  /// Getrimmt; leer heißt `null` (V6).
  final String? notiz;

  /// Ob das Ende von Hand gesetzt ist. Solange nicht, zieht es mit Art und
  /// Beginn nach (V4).
  final bool bisVonHand;

  /// Eine andere Art. Zieht das Ende nach, solange es nicht von Hand
  /// gesetzt ist.
  AuszeitFormular mitArt(EreignisArt art) => AuszeitFormular._(
    art: art,
    von: von,
    bis: bisVonHand ? bis : _vorbelegtesEnde(art, von),
    notiz: notiz,
    bisVonHand: bisVonHand,
  );

  /// Ein anderer Beginn. Zieht das Ende nach, solange es nicht von Hand
  /// gesetzt ist; sonst nimmt er es nur mit, wenn er dahinter rückt (V5).
  /// **Das Ende bleibt dabei „von Hand“** — dass V5 es verschoben hat,
  /// macht es nicht wieder zur Vorbelegung.
  AuszeitFormular mitVon(String von) => AuszeitFormular._(
    art: art,
    von: von,
    bis: bisVonHand ? _nichtVor(bis, von) : _vorbelegtesEnde(art, von),
    notiz: notiz,
    bisVonHand: bisVonHand,
  );

  /// Ein Ende von Hand. Vor dem Beginn wird es der Beginn (V5).
  AuszeitFormular mitBis(String bis) => AuszeitFormular._(
    art: art,
    von: von,
    bis: _nichtVor(bis, von),
    notiz: notiz,
    bisVonHand: true,
  );

  /// Die Notiz, getrimmt; leer heißt keine (V6).
  AuszeitFormular mitNotiz(String notiz) => AuszeitFormular._(
    art: art,
    von: von,
    bis: bis,
    notiz: _bereinigt(notiz),
    bisVonHand: bisVonHand,
  );

  /// Das Ereignis zum Ablegen. `geaendert` bleibt `null`: Den Zeitstempel
  /// einer Änderung setzt das Repository, nicht das Formular.
  Ereignis alsEreignis({int? id, DateTime? angelegt}) => Ereignis(
    id: id,
    art: art,
    von: von,
    bis: bis,
    notiz: notiz,
    angelegt: angelegt,
  );

  /// Bei der OP Beginn + 14 (Kern), sonst der Beginn selbst (V4).
  static String _vorbelegtesEnde(EreignisArt art, String von) =>
      art == EreignisArt.op ? opErholungBis(von) : von;

  /// [bis], aber nie vor [von]. ISO-Tage vergleichen lexikografisch wie
  /// der Kalender, auch über einen Jahreswechsel.
  static String _nichtVor(String bis, String von) =>
      bis.compareTo(von) < 0 ? von : bis;

  static String? _bereinigt(String? text) {
    final getrimmt = text?.trim();
    return getrimmt == null || getrimmt.isEmpty ? null : getrimmt;
  }

  @override
  bool operator ==(Object other) =>
      other is AuszeitFormular &&
      other.art == art &&
      other.von == von &&
      other.bis == bis &&
      other.notiz == notiz &&
      other.bisVonHand == bisVonHand;

  @override
  int get hashCode => Object.hash(art, von, bis, notiz, bisVonHand);

  @override
  String toString() =>
      'AuszeitFormular(art: ${art.name}, von: $von, bis: $bis, '
      'notiz: $notiz, bisVonHand: $bisVonHand)';
}
