// Die von Hand eingetragenen Nächte und Nickerchen, über die gemessenen
// gelegt (#131). Reine Funktionen, kein Provider, kein Widget — den
// Zustand darüber baut `schlaf_zustand.dart`.
//
// API und Vertrag sind durch `app/test/shell/schlaf_von_hand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die Regel ist eine einzige, und sie steht im Entwurf**
// (`docs/screens/screens/schlaf.js`, ENTWURF vom 26.10.2026): Die
// eingetragene Nacht „wird beim Lesen über die Health-Daten gelegt —
// dieselbe Regel wie bei den Umfängen (‚Eingetippte Werte schlagen
// importierte', SPEC 4.6)".
//
// **Beim Tagschlaf gilt sie nicht, und das ist kein Widerspruch.** Dort
// addiert sich der Eintrag (`tagschlaf.js`, Zustand `von-hand`: „Die Summe
// oben zählt beide Phasen"). Eine Nacht gibt es je Tag einmal — zwei
// Aussagen über dieselbe Nacht widersprechen sich, und die jüngere gilt.
// Ein Nickerchen gibt es mehrfach; ein eingetragenes ersetzt deshalb
// keines, es kommt dazu.
//
// **Seit #192 gilt „die jüngere Aussage gewinnt" nur noch, wenn es
// wirklich zwei Aussagen über dieselbe Nacht sind** (Tims Entscheidung
// vom 30.10.2026). Sein Schlaf von 19:00 bis 21:30 widerspricht der
// gemessenen Nacht nicht, er kommt dazu — dass die App es nicht
// unterscheiden konnte, lag allein an der Tagesgrenze: Nächte laufen von
// 18:00 bis 18:00, also fällt 19:00 in „die Nacht dieses Tages". Wo die
// Grenze zwischen „dieselbe Nacht" und „kommt dazu" liegt, rechnet
// `SleepMerge` im Kern.
import 'package:trainings_core/trainings_core.dart';

import '../data/schlaf_eintrag.dart';
import '../health/health_types.dart';
import 'schlaf_minuten.dart';

/// Wie der Eintrag eines Aufwachtags zur gemessenen Nacht steht (#192).
enum SchlafEintragLage {
  /// Er meint dieselbe Nacht und **ersetzt** sie — eine Korrektur.
  ersatz,

  /// Er meint eine andere Strecke desselben Tages und **kommt dazu**.
  ergaenzung,
}

/// Ob [eintrag] die gemessene Nacht [gemessen] korrigiert (`true`) oder zu
/// ihr dazukommt (`false`) — die Frage, an der #192 hing.
///
/// Die Regel selbst steht im Kern (`SleepMerge.corrects`, dort auch die
/// Begründung für die Fünf-Minuten-Grenze); hier wird nur übersetzt: Das
/// gemessene Fenster ist das über **alle** Abschnitte, auch die wachen —
/// die Uhr hat diese Strecke gesehen, ob darin geschlafen wurde oder
/// nicht. Beide Seiten zählen danach Minuten seit 18:00.
bool eintragKorrigiert({
  required SleepNight? gemessen,
  required SchlafEintrag eintrag,
}) {
  final (gemessenVon, gemessenBis) = gemessen == null
      ? (null, null)
      : schlafFensterVon(gemessen.session);
  final (eintragVon, eintragBis) = eintragFensterMinuten(eintrag);

  return SleepMerge.corrects(
    entryStart: eintragVon,
    entryEnd: eintragBis,
    measuredStart: gemessenVon == null
        ? null
        : EveningClock.minutesSinceEvening(gemessenVon),
    measuredEnd: gemessenBis == null
        ? null
        : EveningClock.minutesSinceEvening(gemessenBis),
  );
}

/// Der Nacht-Eintrag dieses Aufwachtags samt seiner Lage, oder `null`.
///
/// Die **eine** Stelle, an der „ersetzt oder kommt dazu" beantwortet wird:
/// [naechteMitEintraegen] entscheidet damit über die Abschnitte, der
/// Zustand darüber über Score und Schirm. Zwei Stellen liefen auseinander,
/// und dann zeigte der Schirm eine andere Nacht, als er bewertet.
({SchlafEintrag eintrag, SchlafEintragLage lage})? nachtEintragLage({
  required DateTime tag,
  required List<SleepNight> gemessen,
  required List<SchlafEintrag> eintraege,
}) {
  final eintrag = nachtEintragZu(tag, eintraege);
  if (eintrag == null) return null;

  SleepNight? nacht;
  for (final kandidat in gemessen) {
    if (kandidat.date == tag) {
      nacht = kandidat;
      break;
    }
  }

  return (
    eintrag: eintrag,
    lage: eintragKorrigiert(gemessen: nacht, eintrag: eintrag)
        ? SchlafEintragLage.ersatz
        : SchlafEintragLage.ergaenzung,
  );
}

/// Das Fenster eines Eintrags auf der 18-Uhr-Skala — `(null, null)` in der
/// Fassung „nur Dauer".
///
/// Beide Zeiten gehen **ohne Umweg über einen Zeitpunkt** auf die Skala,
/// aus demselben Grund wie bei [einschlafMinutenVon]: Der Eintrag trägt
/// Uhrzeiten, keine Momente.
(double?, double?) eintragFensterMinuten(SchlafEintrag eintrag) {
  final ende = eintrag.endeMinuten;
  return (
    einschlafMinutenVon(eintrag),
    ende == null
        ? null
        : EveningClock.minutesSinceEveningOfClock(
            hour: ende ~/ Duration.minutesPerHour,
            minute: ende % Duration.minutesPerHour,
          ),
  );
}

/// Die gemessenen Nächte, über die die eingetragenen gelegt sind —
/// aufsteigend nach Aufwachtag.
///
/// Ein Tag, dessen Eintrag die gemessene Nacht **korrigiert**, verliert
/// seine gemessenen Abschnitte: Oben steht dann die eingetragene Nacht,
/// und zwar ganz. Eine aus gemessener Dauer und eingetippter
/// Einschlafzeit zusammengesetzte Nacht hätte es so nie gegeben, und
/// niemand könnte hinterher sagen, welche Zahl woher kommt.
///
/// **Ein Eintrag, der die gemessene Zeit nicht überlappt, nimmt ihr
/// nichts weg** (#192). Er beschreibt eine andere Strecke desselben
/// Tages; die Abschnitte bleiben stehen, und der Zustand darüber legt
/// beide Strecken zusammen.
///
/// **Die Nickerchen desselben Tages bleiben immer stehen** — sie sind eine
/// eigene Aussage und gehen ohnehin nicht in die Nacht ein (SPEC 4.6).
///
/// Ein Tag, für den es nur einen Eintrag gibt, kommt als Nacht **ohne
/// Abschnitte** dazu. Der Schirm baut ihre Zahlen aus dem Eintrag; eine
/// erfundene Phasenliste gäbe es hier nicht einmal als Versuchung.
///
/// Ohne Einträge wird die übergebene Liste unverändert zurückgegeben —
/// kein neues, ungleiches Objekt, das jeden abgeleiteten Wert neu rechnen
/// ließe (Fehler `03`).
List<SleepNight> naechteMitEintraegen({
  required List<SleepNight> gemessen,
  required List<SchlafEintrag> eintraege,
}) {
  // Nach `tag` nachschlagbar, und bei einer doppelten Zeile gilt die
  // erste — dieselbe Wahl wie in [nachtEintragZu], damit die beiden nie
  // verschiedene Einträge meinen.
  final nachtEintraege = <String, SchlafEintrag>{};
  for (final eintrag in eintraege) {
    if (eintrag.art != SchlafEintragArt.nacht) continue;
    nachtEintraege.putIfAbsent(eintrag.tag, () => eintrag);
  }
  if (nachtEintraege.isEmpty) return gemessen;

  final gemischt = <SleepNight>[];
  final getroffen = <String>{};
  for (final nacht in gemessen) {
    final tag = BerlinCalendar.dayKey(nacht.date);
    final eintrag = nachtEintraege[tag];
    if (eintrag == null) {
      gemischt.add(nacht);
      continue;
    }
    getroffen.add(tag);
    if (!eintragKorrigiert(gemessen: nacht, eintrag: eintrag)) {
      // Eine Ergänzung lässt die Messung unangetastet — sonst wäre sie
      // genau der Ersatz, gegen den #192 geschrieben ist.
      gemischt.add(nacht);
      continue;
    }
    gemischt.add(
      SleepNight(
        date: nacht.date,
        session: SleepSession(segments: const []),
        naps: nacht.naps,
      ),
    );
  }

  for (final tag in nachtEintraege.keys) {
    if (getroffen.contains(tag)) continue;
    gemischt.add(
      SleepNight(
        date: datumAusTag(tag),
        session: SleepSession(segments: const []),
        naps: const [],
      ),
    );
  }

  gemischt.sort((a, b) => a.date.compareTo(b.date));
  return gemischt;
}

/// Der eingetragene Nacht-Eintrag dieses Aufwachtags, oder `null`.
SchlafEintrag? nachtEintragZu(DateTime tag, List<SchlafEintrag> eintraege) {
  final schluessel = BerlinCalendar.dayKey(tag);
  for (final eintrag in eintraege) {
    if (eintrag.art == SchlafEintragArt.nacht && eintrag.tag == schluessel) {
      return eintrag;
    }
  }
  return null;
}

/// Die eingetragenen Nickerchen dieses Tages, nach Beginn sortiert.
///
/// Ein Nickerchen ohne Zeiten hat keinen Beginn und steht deshalb hinten —
/// der Entwurf sagt dasselbe („Ohne Zeiten wird die Phase an das Ende des
/// Tages gesetzt"), ohne dafür eine Uhrzeit zu erfinden.
List<SchlafEintrag> tagschlafEintraegeZu(
  DateTime tag,
  List<SchlafEintrag> eintraege,
) {
  final schluessel = BerlinCalendar.dayKey(tag);
  final gefunden = [
    for (final eintrag in eintraege)
      if (eintrag.art == SchlafEintragArt.tagschlaf &&
          eintrag.tag == schluessel)
        eintrag,
  ];
  gefunden.sort((a, b) {
    final aVon = a.beginnMinuten;
    final bVon = b.beginnMinuten;
    if (aVon == null && bVon == null) return a.lfdNr.compareTo(b.lfdNr);
    if (aVon == null) return 1;
    if (bVon == null) return -1;
    return aVon.compareTo(bVon);
  });
  return gefunden;
}

/// Die Einschlafzeit eines Eintrags auf der 18-Uhr-Skala, oder `null`.
///
/// **Ohne Umweg über einen Zeitpunkt.** Der Eintrag trägt eine Uhrzeit
/// („23:10"), keinen Moment; ein daraus gebauter `DateTime` müsste raten,
/// auf welchen Kalendertag die Uhrzeit fällt, und läge an einer
/// Zeitumstellung daneben. [EveningClock] nimmt die Wanduhr direkt.
double? einschlafMinutenVon(SchlafEintrag eintrag) {
  final beginn = eintrag.beginnMinuten;
  if (beginn == null) return null;
  return EveningClock.minutesSinceEveningOfClock(
    hour: beginn ~/ Duration.minutesPerHour,
    minute: beginn % Duration.minutesPerHour,
  );
}
