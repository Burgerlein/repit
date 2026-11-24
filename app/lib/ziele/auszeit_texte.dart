// Die Texte der Auszeit (#448 unter #404): Titel je Art, Zeitraum, Stand,
// Wirkung und der Hinweis auf die ärztliche Freigabe. Wortlaut aus
// `docs/screens/screens/auszeit.js` und der Auszeit-Spec in
// `docs/superpowers/specs/` (V8, V9).
//
// **Nutzertexte gehören nicht in den Kern** (`CLAUDE.md`): Der Kern kennt
// `EreignisArt.op` und `EreignisStand.laeuft`, die Wörter dazu stehen hier.
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';

/// Der Hinweis auf die ärztliche Freigabe — **ungekürzt**, in der Liste und
/// im Formular derselbe (Spec, „Kein Rat, sondern eine Planungsannahme“).
const auszeitFreigabe =
    'Wie lange du dich erholst, ist eine Planungsannahme, keine Freigabe. '
    'Wann du wieder belasten und normal essen darfst, entscheidet deine '
    'Ärztin oder dein Arzt.';

/// Fuß unter dem Zeitraum einer OP.
const auszeitFussOp =
    'Vorbelegt mit 14 Tagen nach dem Eingriff. Eine Planungsannahme, keine '
    'Freigabe — ändere sie, sobald du mehr weißt.';

/// Fuß unter dem Zeitraum jeder anderen Art.
const auszeitFussSonst =
    'Das Ende brauchst du, sonst bliebe der Aufschlag für immer weg. '
    'Verlängern geht jederzeit.';

/// Die Erklärung in „Woher das Ziel kommt“, solange das Körperziel
/// pausiert (#449) — **ungekürzt**, mit dem Hinweis auf die ärztliche
/// Freigabe. Wortlaut für die OP aus dem Entwurf (`HERLEITUNG_PAUSIERT`),
/// für Krankheit und Verletzung aus V16. Urlaub pausiert nie; der Fall
/// steht nur, damit der `switch` vollständig ist.
String auszeitHerleitungFreigabe(EreignisArt art) => switch (art) {
  EreignisArt.op || EreignisArt.urlaub =>
    'Während der Erholung rechnet die App keinen Aufschlag fürs Zunehmen '
        'ein. Was und wie viel du nach der OP essen solltest, klär mit '
        'deiner Ärztin oder deinem Arzt — die Zahl oben ist eine grobe '
        'Schätzung, keine Empfehlung für die Erholung.',
  EreignisArt.krankheit || EreignisArt.verletzung =>
    'Während der Auszeit rechnet die App keinen Aufschlag fürs Zunehmen '
        'ein. Was und wie viel du jetzt essen solltest, klär mit deiner '
        'Ärztin oder deinem Arzt — die Zahl oben ist eine grobe Schätzung, '
        'keine Empfehlung für die Auszeit.',
};

/// Der Hinweis rechts in der Körperziel-Zeile, solange pausiert (V16):
/// „OP-Erholung bis 28.10.“, „Krankheit bis …“, „Verletzung bis …“.
String auszeitPauseBis(EreignisArt art, String bis) =>
    '${_pauseArt(art)} bis ${Format.tagMonat(auszeitAlsDatum(bis))}';

/// Derselbe Hinweis zum Vorlesen, das Ende als Wort: „OP-Erholung bis
/// 28. Oktober“.
String auszeitPauseBisVorlesen(EreignisArt art, String bis) =>
    '${_pauseArt(art)} bis '
    '${Format.tagMonatAusgeschrieben(auszeitAlsDatum(bis))}';

String _pauseArt(EreignisArt art) => switch (art) {
  EreignisArt.op => 'OP-Erholung',
  EreignisArt.krankheit => 'Krankheit',
  EreignisArt.verletzung => 'Verletzung',
  EreignisArt.urlaub => 'Urlaub',
};

/// Der Titel einer Zeile, wie gezeichnet.
String auszeitTitel(EreignisArt art) => switch (art) {
  EreignisArt.op => 'Operation',
  EreignisArt.krankheit => 'Krank / erkältet',
  EreignisArt.verletzung => 'Verletzung',
  EreignisArt.urlaub => 'Urlaub',
};

/// Die Beschriftung im Umschalter.
String auszeitArtKurz(EreignisArt art) => switch (art) {
  EreignisArt.op => 'OP',
  EreignisArt.krankheit => 'Krankheit',
  EreignisArt.verletzung => 'Verletzung',
  EreignisArt.urlaub => 'Urlaub',
};

/// Was die Art **heute schon** bewirkt. Kein Satz über den Plan, die
/// Erholungsampel oder Wettkämpfe — die gibt es noch nicht (Spec).
String auszeitWirkung(EreignisArt art) => switch (art) {
  EreignisArt.op =>
    'Für diese Tage setzt das Kalorienziel den Aufschlag fürs Körperziel '
        'aus. Grundbedarf und Training zählen weiter.',
  EreignisArt.krankheit || EreignisArt.verletzung =>
    'Wie bei der OP: kein Aufschlag fürs Körperziel, solange die Auszeit '
        'läuft.',
  EreignisArt.urlaub => 'Nur markiert. Das Kalorienziel bleibt, wie es ist.',
};

/// Beschriftung der Zeile „Beginn“ im Formular.
String auszeitVonTitel(EreignisArt art) =>
    art == EreignisArt.op ? 'OP am' : 'Von';

/// Beschriftung der Zeile „Ende“ im Formular.
String auszeitBisTitel(EreignisArt art) =>
    art == EreignisArt.op ? 'Erholung bis' : 'Bis';

/// Der Untertitel einer Zeile: „Zeitraum · Stand“ (V8).
String auszeitUntertitel({
  required EreignisArt art,
  required String von,
  required String bis,
  required String heute,
}) {
  final stand = switch (ereignisStand(von: von, bis: bis, heute: heute)) {
    EreignisStand.laeuft when pausiertKoerperziel(art) =>
      'läuft · Körperziel pausiert',
    EreignisStand.laeuft => 'läuft · nur markiert',
    EreignisStand.geplant => 'geplant',
    EreignisStand.vorbei => 'vorbei',
  };
  return '${auszeitZeitraum(von: von, bis: bis, heute: heute)} · $stand';
}

/// Der Vorlesetext einer Zeile — er nennt den Zustand, nicht die Zeichen
/// („Operation, 14. bis 28. Oktober, läuft, Körperziel pausiert“).
String auszeitVorlesen({
  required EreignisArt art,
  required String von,
  required String bis,
  required String heute,
}) {
  final titel = art == EreignisArt.krankheit
      ? 'Krank oder erkältet'
      : auszeitTitel(art);
  final stand = switch (ereignisStand(von: von, bis: bis, heute: heute)) {
    EreignisStand.laeuft when pausiertKoerperziel(art) =>
      'läuft, Körperziel pausiert',
    EreignisStand.laeuft => 'läuft, nur markiert',
    EreignisStand.geplant => 'geplant',
    EreignisStand.vorbei => 'vorbei',
  };
  return '$titel, ${_zeitraumVorlesen(von, bis, heute)}, $stand';
}

/// Der Zeitraum (V9): „Mi 14.10.–Mi 28.10.“, ein einzelner Tag
/// „Mi 14.10.“. Liegt der Beginn nicht im Jahr von [heute], stehen beide
/// Daten mit Jahr.
String auszeitZeitraum({
  required String von,
  required String bis,
  required String heute,
}) {
  final mitJahr = !_imJahr(von, heute);
  final anfang = _tagKurz(von, mitJahr: mitJahr);
  if (von == bis) return anfang;
  return '$anfang–${_tagKurz(bis, mitJahr: mitJahr)}';
}

/// Ein Tag in einer Formularzeile, wie gezeichnet: „Mi, 14.10.“, außerhalb
/// des Jahres von [heute] mit Jahr.
String auszeitFormDatum(String tag, {required String heute}) {
  final datum = auszeitAlsDatum(tag);
  final wochentag = _ohnePunkt(Format.wochentagKurz(datum));
  return _imJahr(tag, heute)
      ? '$wochentag, ${Format.tagMonat(datum)}'
      : '$wochentag, ${Format.tag(datum)}';
}

/// Ein ISO-Tag als UTC-Mitternacht — nur für die Formatierung, deren
/// Felder es unverändert liest. Kein Zeitpunkt.
DateTime auszeitAlsDatum(String tag) => DateTime.parse('${tag}T00:00:00Z');

String _tagKurz(String tag, {required bool mitJahr}) {
  final datum = auszeitAlsDatum(tag);
  final wochentag = _ohnePunkt(Format.wochentagKurz(datum));
  return '$wochentag ${mitJahr ? Format.tag(datum) : Format.tagMonat(datum)}';
}

String _zeitraumVorlesen(String von, String bis, String heute) {
  final mitJahr = !_imJahr(von, heute);
  final a = auszeitAlsDatum(von);
  final b = auszeitAlsDatum(bis);
  String lang(DateTime d) => mitJahr
      ? Format.datumAusgeschrieben(d)
      : Format.tagMonatAusgeschrieben(d);
  if (von == bis) return lang(a);
  if (a.year == b.year && a.month == b.month) return '${a.day}. bis ${lang(b)}';
  return '${lang(a)} bis ${lang(b)}';
}

bool _imJahr(String tag, String heute) =>
    tag.substring(0, 4) == heute.substring(0, 4);

/// „Mi.“ → „Mi“ — der Entwurf schreibt den Wochentag ohne Punkt.
String _ohnePunkt(String wochentag) => wochentag.endsWith('.')
    ? wochentag.substring(0, wochentag.length - 1)
    : wochentag;
