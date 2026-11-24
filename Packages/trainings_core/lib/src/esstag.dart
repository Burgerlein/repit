import 'tagesgrenze.dart';

// **Der Sonderfall von [laufenderTag]**, ohne Wachbelege und ohne gemeldete
// Nächte (`docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`,
// Entscheidung 11). Beide Funktionen rechnen über [laufenderTag]; die Regel
// steht nur dort. Wer Belege oder Nächte hat, fragt [laufenderTag] selbst —
// ohne sie bleibt der Esstag bei der festen Grenze 04:00.

/// Der Esstag, zu dem ein Zeitpunkt gehört, als ISO-Tag (`2026-10-23`).
///
/// Ist es auf der **Berliner Wanduhr** vor 04:00, ist es der Kalendertag
/// davor, sonst der Kalendertag selbst. Die Grenze 04:00 gehört dem neuen
/// Tag. Sie kommt aus `Mahlzeitfenster.tagesbeginnInMinuten`, der
/// Untergrenze des Frühstücks: Ein Abendessen um 01:30 steht auf dem Tag
/// davor, und der Esstag muss genau dort enden, wo der Abend endet.
///
/// Entschieden wird an der Wanduhr, nicht an der UTC-Uhrzeit: 02:30 UTC ist
/// im Winter 03:30 (Vortag), im Sommer 04:30 (neuer Tag).
String esstag(DateTime utc) => laufenderTag(jetzt: utc).tag;

/// Die nächste Berliner 04:00 **nach** [utc], als UTC-Zeitpunkt. Um genau
/// 04:00 ist das die des Folgetags. Ohne Belege ist das
/// [Tagesstand.endetSpaetestens].
///
/// Über den Kalender gerechnet, nie über `+ 24 h`: Am Tag der Umstellung im
/// März liegen zwischen zwei 04:00 23 Stunden, im Oktober 25.
DateTime naechsterEsstagBeginn(DateTime utc) =>
    laufenderTag(jetzt: utc).endetSpaetestens;
