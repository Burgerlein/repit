import 'berlin_calendar.dart';

// Auszeiten: welche Art das Körperziel pausiert, welche Auszeit an einem
// Tag gilt, das vorbelegte Ende einer OP, der Stand relativ zu einem Tag
// und das feste Ziel in der Pause.
//
// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, „Die
// Kern-Rechnungen“; Ticket #404, Karte #445. Die Entscheidungen 3 und 4
// stammen von Tim (10.11.2026). Die Vorgaben V2, V3, V8, V10 und V14 hat
// der Planende formuliert — von Tim am 10.11.2026 übernommen (Spec,
// „Vorgaben“).
//
// Alle Tage sind ISO-Tagesschlüssel (`JJJJ-MM-TT`, mit führenden Nullen,
// wie [BerlinCalendar.dayKey] sie erzeugt). Solche Schlüssel vergleichen
// lexikografisch in Kalenderreihenfolge; deshalb wird hier mit
// `compareTo` verglichen statt über Zeitpunkte, die eine Zeitumstellung
// verschieben könnte.

/// Die Art eines Ereignisses (V1).
///
/// **Die Namen sind Speicherformat:** Die Spalte `art` der Tabelle
/// `ereignisse` speichert `name`. Wer einen Wert umbenennt, macht jede
/// gespeicherte Zeile dieser Art unlesbar.
enum EreignisArt { op, krankheit, verletzung, urlaub }

/// Ob eine Auszeit dieser Art das Körperziel pausiert.
///
/// Entscheidung 3 (Tim): OP, Krankheit und Verletzung setzen den Aufschlag
/// aus, Urlaub wird nur markiert.
bool pausiertKoerperziel(EreignisArt art) => switch (art) {
  EreignisArt.op || EreignisArt.krankheit || EreignisArt.verletzung => true,
  EreignisArt.urlaub => false,
};

/// Die Tage einer Auszeit: [von] und [bis] als ISO-Tag, **beide
/// einschließlich** (V2).
///
/// Werttyp mit `==` und `hashCode` über alle vier Felder — ein Provider,
/// der eine Liste davon hält, soll nur neu rechnen, wenn sich wirklich
/// etwas geändert hat (`CLAUDE.md`, Werttypen als Abhängigkeit).
class AuszeitTage {
  const AuszeitTage({
    required this.id,
    required this.art,
    required this.von,
    required this.bis,
  });

  /// Die Zeilennummer in `ereignisse`; entscheidet bei gleichem [bis] (V3).
  final int id;

  final EreignisArt art;

  /// Erster Tag der Auszeit, einschließlich.
  final String von;

  /// Letzter Tag der Auszeit, einschließlich.
  final String bis;

  /// Ob [tag] zwischen [von] und [bis] liegt, beide einschließlich (V2).
  bool enthaelt(String tag) =>
      von.compareTo(tag) <= 0 && tag.compareTo(bis) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AuszeitTage &&
      other.id == id &&
      other.art == art &&
      other.von == von &&
      other.bis == bis;

  @override
  int get hashCode => Object.hash(id, art, von, bis);

  @override
  String toString() =>
      'AuszeitTage(id: $id, art: ${art.name}, von: $von, bis: $bis)';
}

/// Die Auszeit, die das Körperziel an [tag] pausiert — oder `null`.
///
/// * V2: [AuszeitTage.von] und [AuszeitTage.bis] gelten einschließlich.
/// * Entscheidung 3, V3: Urlaub pausiert nie, auch nicht, wenn er sich mit
///   einer OP überlappt — er nimmt an der Auswahl gar nicht teil.
/// * V3: Überlappen sich mehrere pausierende Auszeiten, gilt die mit dem
///   spätesten `bis`, bei Gleichstand die mit der höchsten `id`. Die
///   Ordnung ist vollständig; die Reihenfolge der Eingabe spielt keine
///   Rolle.
AuszeitTage? pausierendeAuszeitAm(Iterable<AuszeitTage> auszeiten, String tag) {
  AuszeitTage? gewinner;
  for (final auszeit in auszeiten) {
    if (!pausiertKoerperziel(auszeit.art) || !auszeit.enthaelt(tag)) continue;
    if (gewinner == null) {
      gewinner = auszeit;
      continue;
    }
    final vergleich = auszeit.bis.compareTo(gewinner.bis);
    if (vergleich > 0 || (vergleich == 0 && auszeit.id > gewinner.id)) {
      gewinner = auszeit;
    }
  }
  return gewinner;
}

/// Standardpause nach einer OP (`docs/SPEC.md` 1): 14 Tage.
const int opErholungTage = 14;

/// Das vorbelegte Ende einer OP: [opTag] + [opErholungTage] Kalendertage,
/// als ISO-Tag (Entscheidung 4, Tim: eine Regel, kein Datum).
///
/// Gerechnet über [BerlinCalendar.addDays], also über den Kalender — nie
/// über `14 · 24 h` auf einem Zeitpunkt, die über eine Zeitumstellung eine
/// Stunde zu kurz oder zu lang wären. Der Tag wird dafür als 12:00 UTC
/// gelesen: Das liegt bei +1 h wie bei +2 h sicher im Berliner Tag
/// desselben Datums.
///
/// Wirft eine [FormatException], wenn [opTag] kein lesbarer ISO-Tag ist —
/// das ist ein Programmierfehler beim Aufrufer, keine Datenlage.
String opErholungBis(String opTag) {
  final mittag = DateTime.parse('${opTag}T12:00:00Z');
  return BerlinCalendar.dayKey(BerlinCalendar.addDays(mittag, opErholungTage));
}

/// Der Stand eines Ereignisses relativ zu einem Tag (V8).
enum EreignisStand { geplant, laeuft, vorbei }

/// Der Stand des Ereignisses von [von] bis [bis] am Tag [heute] — vor
/// [von] `geplant`, nach [bis] `vorbei`, sonst `laeuft`; einschließlich an
/// beiden Enden (V2, V8). Welcher Tag „heute“ ist, entscheidet der Aufrufer
/// (V10: der Esstag).
EreignisStand ereignisStand({
  required String von,
  required String bis,
  required String heute,
}) {
  if (heute.compareTo(von) < 0) return EreignisStand.geplant;
  if (heute.compareTo(bis) > 0) return EreignisStand.vorbei;
  return EreignisStand.laeuft;
}

/// Das feste, berechnete Ziel eines Tags in der Pause (V14): das
/// gespeicherte Ziel [kcal] minus den gespeicherten Körperziel-Anteil
/// [koerperzielKcal], nie unter 0.
///
/// `null`, wenn kein Anteil gespeichert ist — ein Ziel von Hand hat keinen
/// getrennten Körperziel-Anteil, und hier wird keiner nachgerechnet (V15).
/// Was der Aufrufer dann anzeigt, entscheidet er; diese Funktion erfindet
/// keinen Wert.
double? festesZielPausiert({required double kcal, double? koerperzielKcal}) {
  if (koerperzielKcal == null) return null;
  final ziel = kcal - koerperzielKcal;
  return ziel < 0 ? 0 : ziel;
}
