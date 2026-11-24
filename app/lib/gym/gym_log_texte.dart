// Die Sätze des Erfassen-Schirms und des Vollbilds (#78) — Dart-Entsprechung
// der Beschriftungen in `Sources/Features/Gym/GymLogView.swift`,
// `GymLogExerciseCard.swift`, `GymFocusPage.swift` und `RestTimer.swift`,
// nachgezogen auf den Entwurf `docs/screens/screens/gym-log.js`.
//
// **Warum diese Datei existiert:** `trainings_core` trägt keine Nutzertexte
// (`CLAUDE.md`); `WarmUpKind`, `Suggestion` und die Sitzung tragen Codes und
// Zahlen. Die Sätze entstehen in der Ansichtsschicht, und zwar an **genau
// einer Stelle je Vokabular** — so wie `gym_fokus_texte.dart` und
// `gym_vorschlag_texte.dart` es vormachen. Die Vorschlagszeile
// ([vorschlagKompaktText]) und die Gewichtszahl ([gymZahlText]) liegen in
// `gym_vorschlag_texte.dart`.
//
// Jede Datumsangabe läuft über [Format] mit fest gesetzter Sprache, jede
// Zahl über [gymZahlText] oder [formatNumber] — „62,5", nie „62.5".
//
// **Der Vorlesetext nennt den Zustand, nicht das Zeichen** (`CLAUDE.md`):
// „Satz 3, keine Werte", nicht „Satz 3 Strich".
//
// **Kein Ereignisdatum im Quelltext** (`CLAUDE.md`).
import 'package:flutter/widgets.dart' show Color;
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/palette.dart';
import '../design/zahlen.dart';
import 'gym_log_stand.dart';
import 'gym_vorschlag_texte.dart';

// --- Kopf und Eckdaten -------------------------------------------------------

/// „7 Übungen · ca. 70 min" — der hintere Teil der Lede unter dem Titel.
///
/// **Der vordere Teil fehlt hier noch:** Der Entwurf zeigt „Drücken" als
/// Titel und „Brust, Schulter, Trizeps + Bizeps" als Lede, und beides liefert
/// der Kern heute nicht (Spec 13.1 — `Workout.title` trägt noch die
/// Langfassung aus `SPEC.md`). Sobald das Feld dort steht, setzt die
/// Ansicht die Lede aus dem Feld und diesem Text zusammen.
///
/// [minuten] ist die wirksame Dauer des Trainings (`WorkoutDuration.effective`);
/// ohne sie — ein Training ohne bekannte Übung — steht nur die Zahl der
/// Übungen da, nie „ca. 0 min".
String gymKopfKennzahlen(int uebungen, int? minuten) => minuten == null
    ? '$uebungen Übungen'
    : '$uebungen Übungen · ca. $minuten min';

/// Wie das Training in Titeln und Rückfragen heißt: bei einem Enum-Fall
/// „Gym A" bzw. „Push", sonst der Kurzname aus der Definition („Push — …"
/// wird „Push"), ohne sie „Training".
String gymTrainingsLabel(
  TrainingKey schluessel,
  WorkoutDefinition? definition,
) {
  if (schluessel is Workout) return schluessel.label;
  final name = definition?.name;
  return name == null || name.trim().isEmpty
      ? 'Training'
      : WorkoutNaming.shortName(name);
}

/// Wie das laufende Training in der Rückfrage heißt.
String gymLaufendesName(GymLaufendes laufendes) {
  final fall = laufendes.workout;
  if (fall != null) return fall.label;
  final name = laufendes.name;
  return name == null || name.trim().isEmpty
      ? 'Training'
      : WorkoutNaming.shortName(name);
}

/// „Heute · 70 min · Notiz" — die Zusammenfassung der zugeklappten
/// Eckdaten (Spec 3.3).
///
/// [datum] ist der Zeitpunkt des Trainings, [jetzt] die Uhr. **Ob es
/// „Heute" ist, entscheidet der Berliner Kalendertag**, nicht der
/// UTC-Tag. Ein leeres Dauerfeld steht als „–" da, nicht als „0 min"; „Notiz"
/// steht, sobald eine da ist.
String gymEckdatenText({
  required DateTime datum,
  required DateTime jetzt,
  required String dauer,
  required String notiz,
}) {
  final tag = BerlinCalendar.dayKey(datum) == BerlinCalendar.dayKey(jetzt)
      ? 'Heute'
      : Format.tagMonat(kalendertag(datum));
  final minuten = dauer.trim().isEmpty ? '–' : dauer.trim();
  return notiz.trim().isEmpty
      ? '$tag · $minuten min'
      : '$tag · $minuten min · Notiz';
}

const gymEckdatenTitel = 'Eckdaten';
const gymDatumLabel = 'Datum';
const gymDauerLabel = 'Dauer';
const gymDauerEinheit = 'min';
const gymNotizLabel = 'Notiz';

// --- Fortschritt und Bilanz --------------------------------------------------

/// „14 / 21 Sätze" — die klebende Leiste oben (Spec 3.1). **Sätze, nicht
/// Übungen** (Tim, 10.11.2026).
String gymFortschrittText(int fertig, int gesamt) =>
    '$fertig / $gesamt ${gesamt == 1 ? 'Satz' : 'Sätze'}';

/// „14 / 21" — der Zähler im Kopf des Vollbilds (`fsHead`), wo der Platz
/// für das Wort fehlt.
String gymFortschrittKurz(int fertig, int gesamt) => '$fertig / $gesamt';

/// „14 von 21 Sätzen" — der Vorlesetext zu beiden.
String gymFortschrittVorlesetext(int fertig, int gesamt) =>
    '$fertig von $gesamt ${gesamt == 1 ? 'Satz' : 'Sätzen'}';

/// „6 Sätze · 2.410 kg Volumen" — die Bilanz in der Fußleiste (Spec 3.8).
///
/// Das Volumen ist eine **Schätzung** (`ImportedSession.volumeKg`:
/// unterstützte Sätze tragen nichts bei) und steht als allgemeine Zahl da.
String gymBilanzText(int saetze, double volumeKg) =>
    '${gymSaetzeText(saetze)} · ${formatNumber(volumeKg)} kg Volumen';

/// „1 Satz", „6 Sätze".
String gymSaetzeText(int anzahl) => anzahl == 1 ? '1 Satz' : '$anzahl Sätze';

/// Der Vorlesetext des Hakens neben dem Fortschritt. Ein Zeichen statt
/// eines Satzes: „Zwischengespeichert um 09:41" passt dort nicht hin.
const gymZwischengespeichertVorlesetext = 'Zwischengespeichert';

// --- Übungskarte -------------------------------------------------------------

/// „4 × 6–10 · +2,5 kg", bei einer Zeitübung „3 × 30–45 s · +5 s"
/// (Spec 8.2).
String gymZielzeile(Exercise uebung) {
  final einheit = uebung.isTimed ? ' s' : '';
  final schritt = gymZahlText(uebung.increment);
  return '${uebung.sets} × ${uebung.repLow}–${uebung.repHigh}$einheit · '
      '+$schritt${uebung.isTimed ? ' s' : ' kg'}';
}

/// „3 × 8–12" — die Zielzeile im Vollbild, ohne Schrittweite
/// (`GymFocusPage.title`), bei einer Zeitübung mit „s".
String gymZielzeileVollbild(Exercise uebung) =>
    '${uebung.sets} × ${uebung.repLow}–${uebung.repHigh}'
    '${uebung.isTimed ? ' s' : ''}';

/// „Übung 3 von 7" — die Zeile über dem Übungsnamen im Vollbild.
String gymUebungKicker(int nummer, int von) => 'Übung $nummer von $von';

/// Die zugeklappte Karte: „60 kg × 10  ·  62,5 kg × 9", bei Unterstützung
/// „27 kg U × 8", bei einer Zeitübung „35 s  ·  38 s" — nur die Sekunden,
/// das Gewichtsfeld ist dort gesperrt (Spec 8.2).
///
/// Die Zahlen gehen durch [gymZahlText]: Was als „62.5" getippt wurde,
/// steht als „62,5" da. Ein leeres Gewichtsfeld steht als „–" — ein Satz am
/// eigenen Körpergewicht ist gültig, und eine „0" behauptete ein Gewicht.
/// Wie die Zeitübung hier genau aussehen soll, ist offene Frage 10 der
/// Spec; gesetzt ist, was Swift zeigt.
String gymUebungZusammenfassung(
  Exercise uebung,
  List<RawSet> saetze, {
  required bool unterstuetzt,
}) => saetze
    .map((satz) {
      final wdh = satz.reps.trim().isEmpty ? '–' : satz.reps.trim();
      if (uebung.isTimed) return '$wdh s';
      final einheit = gymGewichtEinheit(
        unterstuetzt: unterstuetzt,
        zeit: false,
      );
      return '${_gewichtZahl(satz.weight, unterstuetzt)} $einheit × $wdh';
    })
    .join('  ·  ');

/// „kg", bei Unterstützung „kg U", bei einer Zeitübung nichts (Spec 3.5).
String gymGewichtEinheit({required bool unterstuetzt, required bool zeit}) =>
    zeit ? '' : (unterstuetzt ? 'kg U' : 'kg');

/// „Wdh", bei einer Zeitübung „Sek." (Spec 3.5, 8.2).
String gymWdhEinheit({required bool zeit}) => zeit ? 'Sek.' : 'Wdh';

/// Der Platzhalter im Gewichtsfeld: das Gewicht vom letzten Mal, bei
/// Unterstützung als Betrag — „–" ohne Verlauf oder ohne Satz an dieser
/// Stelle (Spec 3.4, 3.5). Bei einer Zeitübung ist das Feld gesperrt; dort
/// steht ebenfalls „–".
String gymPlatzhalterGewicht(CompletedSet? vorher, {required bool zeit}) =>
    (vorher == null || zeit)
    ? gymPlatzhalterLeer
    : gymZahlText(vorher.weight.abs());

/// Der Platzhalter im Wiederholungsfeld: die Wiederholungen (bei einer
/// Zeitübung Sekunden) vom letzten Mal, sonst „–".
String gymPlatzhalterWdh(CompletedSet? vorher) =>
    vorher == null ? gymPlatzhalterLeer : '${vorher.reps}';

/// Der Strich, wo es keinen Wert gibt. **Nur ohne Verlauf** — solange der
/// Verlauf gelesen wird, steht hier gar nichts (Spec 9.3).
const gymPlatzhalterLeer = '–';

/// „Satz 3" bzw. „Satz 3, keine Werte" — nicht „Strich" (Spec 14).
String gymSatzVorlesetext(int nummer, {required bool gefuellt}) =>
    gefuellt ? 'Satz $nummer' : 'Satz $nummer, keine Werte';

String gymSatzEntfernenVorlesetext(int nummer) => 'Satz $nummer entfernen';

const gymSatzHinzufuegen = '+ Satz';

// --- Unterstützung -----------------------------------------------------------

const gymZusatzgewicht = 'Zusatzgewicht';
const gymUnterstuetzung = 'Unterstützung';

/// Der Hinweis unter den Satzzeilen einer assistfähigen Übung, wörtlich aus
/// `GymLogExerciseCard.swift:208–212` (Spec 6.3).
const gymUnterstuetzungHinweis =
    'Zahl von der Maschine eintippen. Gespeichert wird sie negativ und als '
    '„27 kg U“ angezeigt. Steigern heißt hier: weniger Unterstützung.';

// --- So geht's ---------------------------------------------------------------

const gymSoGehts = "So geht's";

String gymHaeufigerFehler(String fehler) => 'Häufiger Fehler: $fehler';

/// Eine Tipp-Zeile im aufgeklappten „So geht's" (#551, Spec 9.7,
/// Entscheidung 7) — die `tips` der Bibliotheksübungen. **Wortlaut ist
/// Vorschlag der Spec.**
String gymTipp(String tipp) => 'Tipp: $tipp';

/// Vorspann, wenn das Bild die Übung nicht genau zeigt (`Uebungsbild.
/// approximate`). Der Satz dahinter ist `Uebungsbild.note`.
const gymBildUngefaehr = 'Das Bild zeigt nicht genau diese Übung.';

/// Vorlesetext des Bewegungsbilds: Name der Übung und was zu sehen ist.
String gymBildVorlesetext(String name, {required bool zweiBilder}) => zweiBilder
    ? 'Bewegungsablauf $name, Start und Umkehrpunkt'
    : 'Bewegungsablauf $name';

/// Hinweis für den Screenreader, wenn „Animationen reduzieren“ an ist und
/// ein Tippen zwischen den beiden Bildern wechselt.
const gymBildWechselnHinweis = 'Zwischen Start und Umkehrpunkt wechseln';

/// Wenn die Bilddatei sich nicht lesen lässt, obwohl die Zuordnung sie
/// nennt. Die Anleitung darunter bleibt vollständig.
const gymBildNichtLesbar = 'Bild nicht lesbar';

const gymVideoSuchen = 'Video-Anleitung auf YouTube suchen';

// --- Aufwärmen ---------------------------------------------------------------

const gymAufwaermenTitel = 'Aufwärmen';

/// Die Zeile über dem Titel auf der Aufwärm-Seite des Vollbilds — dort, wo
/// bei den Übungen „Übung 3 von 7" steht.
const gymAufwaermenKicker = 'Vor der ersten Übung';
const gymAufwaermenUeberspringen = 'Überspringen';
const gymAufwaermenUebersprungen = 'Übersprungen';
const gymAufwaermenMinutenLabel = 'Minuten';
const gymAufwaermenMinutenEinheit = 'min';
const gymAufwaermenStreckeLabel = 'Strecke';
const gymAufwaermenStreckeEinheit = 'km';
const gymAufwaermenArtLabel = 'Art';
const gymAufwaermenWiederEintragen = 'Übersprungen — wieder eintragen';
const gymAufwaermenAbbrechenAuswahl = 'Abbrechen';

/// Der Fuß der Aufwärm-Karte. **Ohne** den Zusatz „— sie kommen aus Apple
/// Health", den der Entwurf noch trägt: Das Zuordnen der Health-Workouts
/// ist nicht gebaut (#414), und „Keine Zusage stehen lassen, die nicht mehr
/// stimmt" (`CLAUDE.md`). Wer #414 baut, setzt den Satz mit ihm zurück.
const gymAufwaermenFuss = 'Zone und Puls trägst du nicht ein.';

/// Die Beschriftung der sechs Aufwärm-Arten. `WarmUpKind` trägt nur Codes
/// (`CLAUDE.md`).
String aufwaermArtText(WarmUpKind art) => switch (art) {
  WarmUpKind.bike => 'Rad',
  WarmUpKind.treadmill => 'Laufband',
  WarmUpKind.rowing => 'Rudern',
  WarmUpKind.crossTrainer => 'Crosstrainer',
  WarmUpKind.jumpRope => 'Seilspringen',
  WarmUpKind.mobility => 'Mobility',
};

/// „10 min Rad · 3,4 km", „Übersprungen" — `null` für „nichts
/// eingetragen". Die Strecke steht nur, wo es eine gibt.
String? gymAufwaermenZusammenfassung(WarmUp? aufwaermen) =>
    switch (aufwaermen) {
      null => null,
      WarmUpSkipped() => gymAufwaermenUebersprungen,
      WarmUpDone(:final kind, :final minutes, :final km) =>
        '$minutes min ${aufwaermArtText(kind)}'
            '${km == null ? '' : ' · ${gymZahlText(km)} km'}',
    };

/// Was in der Vorschlagszeile steht, wenn der Verlauf sich nicht lesen
/// ließ. **Kein „Erstes Mal":** Das behauptete, die Übung sei nie gemacht
/// worden, und der Verlauf ist vielleicht da (Spec 9.3).
const gymVerlaufNichtGelesen = 'Der Verlauf ließ sich nicht lesen.';

// --- Pausenuhr ---------------------------------------------------------------

const gymPauseTitel = 'Pause';

/// „2:30" — Minuten und Sekunden, auch für die laufende Uhr
/// (`RestTimer.label`).
String gymPauseLabel(int sekunden) =>
    '${sekunden ~/ 60}:${(sekunden % 60).toString().padLeft(2, '0')}';

/// „empfohlen 2:30 min" — eine **allgemeine Empfehlung**
/// (`RestGuidance`), keine Vorgabe.
String gymPauseEmpfehlung(Exercise uebung) =>
    'empfohlen ${gymPauseLabel(RestGuidance.seconds(uebung))} min';

/// „Pause läuft" vor Ablauf, „über der Pause" danach.
String gymPauseStatus({required bool vorbei}) =>
    vorbei ? 'über der Pause' : 'Pause läuft';

/// Der Ton der Pausenzeile: Ruhe `river`, läuft `iron`, vorbei `ok`
/// (`GymFocusPage.tone`).
Color gymPauseTon({required bool laeuft, required bool vorbei}) =>
    !laeuft ? Palette.river : (vorbei ? Palette.ok : Palette.iron);

/// Die Mitteilung „Pause vorbei" — eine **lokale** Benachrichtigung, kein
/// Push (Spec 7.3). Die Schicht, die sie stellt, ist ein eigener Schritt;
/// die Texte stehen hier, damit sie an einer Stelle liegen.
const gymPauseMitteilungTitel = 'Pause vorbei';
const gymPauseMitteilungText = 'Weiter mit dem nächsten Satz.';

/// Die Kennung der Mitteilung. Wer die Uhr stoppt, zieht die geplante
/// Mitteilung unter dieser Kennung zurück — sonst klingelt es zweimal.
const gymPauseMitteilungKennung = 'gym.rest';

// --- Aktionen ----------------------------------------------------------------

const gymAbschliessen = 'Training abschließen';
const gymZwischenspeichern = 'Zwischenspeichern';
const gymAbbrechen = 'Training abbrechen';
const gymVerwerfen = 'Training verwerfen';
const gymWeiterTrainieren = 'Weiter trainieren';

/// „Gym A verwerfen?" — die Überschrift der Rückfrage (Spec 3.6).
String gymVerwerfenTitel(String name) => '$name verwerfen?';

/// Die Rückfrage vor dem Verwerfen: nennt, wie viele Sätze verloren gehen,
/// und sagt, dass es nicht rückgängig zu machen ist (Spec 3.6). Zählt kein
/// Satz, geht trotzdem der Zwischenstand verloren — und das steht da.
String gymVerwerfenText(int saetze) {
  final verloren = switch (saetze) {
    0 => 'Der Zwischenstand geht',
    1 => '1 eingetragener Satz und der Zwischenstand gehen',
    _ => '$saetze eingetragene Sätze und der Zwischenstand gehen',
  };
  return '$verloren verloren. Das lässt sich nicht rückgängig machen.';
}

/// Die Fußnote unter den Karten.
///
/// **Der dritte Satz der Vorlage fehlt mit Absicht.** Swift und der Entwurf
/// sagen dort: „Beim nächsten App-Start prüft die App, ob für diesen Tag
/// schon ein Kraft-Workout von der Watch in Apple Health steht — nur wenn
/// nicht, trägt sie eines nach." Das ist eine Zusage, und der Lückenfüller,
/// der sie einlöst, ist nicht gebaut (Spec 3.7, 12; offene Frage 4).
/// „Keine Zusage stehen lassen, die nicht mehr stimmt" (`CLAUDE.md`). Wer
/// den Lückenfüller baut, setzt den Satz mit ihm zurück.
const gymFussnote =
    'Gewicht in kg pro Satz, bei Kurzhanteln je Hand. Aufwärmsätze trägst du '
    'nicht ein.';

// --- Vollbild ----------------------------------------------------------------

/// „Nächste Übung", auf der letzten „Training abschließen" (Spec 4.2).
String gymVollbildWeiter({required bool letzte}) =>
    letzte ? gymAbschliessen : 'Nächste Übung';

/// „Wischen geht auch", auf der letzten Übung „Letzte Übung".
String gymVollbildHinweis({required bool letzte}) =>
    letzte ? 'Letzte Übung' : 'Wischen geht auch';

const gymVollbildVerlassenVorlesetext = 'Vollbild verlassen';

// --- Hinweise und Rückfragen -------------------------------------------------

/// Was dem Nutzer gesagt wird, wenn etwas schiefging ([GymLogHinweis]).
///
/// **Der Wortlaut ist neu geschrieben**, die Spec nennt die Fälle, nicht die
/// Sätze (Spec 10.2, offene Frage 11). Jeder sagt, was mit dem Zwischenstand
/// ist — bei Tims einziger Datenkopie die Frage, auf die es ankommt.
String gymHinweisText(GymLogHinweis hinweis) => switch (hinweis) {
  GymLogHinweis.entwurfUnlesbar =>
    'Der Zwischenstand dieses Trainings ließ sich nicht lesen und wurde '
        'verworfen.',
  GymLogHinweis.entwurfNichtGelesen =>
    'Der Zwischenstand ließ sich nicht lesen. Neue Eingaben werden nicht '
        'zwischengespeichert — öffne das Training später noch einmal.',
  GymLogHinweis.zwischenspeichernFehlgeschlagen =>
    'Zwischenspeichern hat nicht geklappt. Deine Eingaben stehen noch hier, '
        'sind aber noch nicht gesichert.',
  GymLogHinweis.ablegenFehlgeschlagen =>
    'Das Training ließ sich nicht ablegen. Der Zwischenstand ist noch da — '
        'versuch es gleich noch einmal.',
  GymLogHinweis.verwerfenFehlgeschlagen =>
    'Der Zwischenstand ließ sich nicht löschen und taucht beim nächsten '
        'Öffnen wieder auf.',
};

/// Die Rückfrage, wenn schon ein **anderes** Training läuft (Tim,
/// 10.11.2026: ein Entwurf, nicht sieben). Der Wortlaut ist neu
/// geschrieben; die Spec verlangt die Rückfrage, nicht ihren Satz.
String gymLaufendesTitel(GymLaufendes laufendes) =>
    '${gymLaufendesName(laufendes)} läuft noch';

String gymLaufendesText(GymLaufendes laufendes, String neu) {
  final saetze = switch (laufendes.saetze) {
    0 => 'sein Zwischenstand geht',
    1 => '1 eingetragener Satz und sein Zwischenstand gehen',
    final n => '$n eingetragene Sätze und ihr Zwischenstand gehen',
  };
  return '${gymLaufendesName(laufendes)} ist angefangen. Beginnst du '
      '$neu, $saetze verloren. Das lässt sich nicht rückgängig '
      'machen.';
}

String gymLaufendesErsetzen(String neu) => '$neu beginnen';

String gymLaufendesWeiter(GymLaufendes laufendes) =>
    'Weiter mit ${gymLaufendesName(laufendes)}';

// --- Hilfen ------------------------------------------------------------------

/// Die Gewichtszahl der Zusammenfassung: lokalisiert, bei Unterstützung als
/// Betrag, „–" für ein leeres Feld. Unlesbares bleibt, wie getippt.
String _gewichtZahl(String text, bool unterstuetzt) {
  final roh = text.trim();
  if (roh.isEmpty) return gymPlatzhalterLeer;
  final gelesen = double.tryParse(roh.replaceAll(',', '.'));
  if (gelesen == null || !gelesen.isFinite) return roh;
  return gymZahlText(unterstuetzt ? gelesen.abs() : gelesen);
}
