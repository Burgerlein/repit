// Die Schlüssel des Erfassen-Schirms (#78) — an einer Stelle, damit Schirm
// und Widget-Tests (`app/test/gym/log_support.dart`) von denselben
// Zeichenketten sprechen. Die Namen stehen dort als API-Tabelle.
//
// `<id>` ist `Exercise.id`, `<n>` die **sichtbare Satznummer, ab 1**. Die
// Satzschlüssel gelten in Erfassung und Vollbild gleich: Beide stehen nie
// zugleich im Baum, denn die Erfassung ist unter dem Vollbild `Offstage`.
import 'package:flutter/widgets.dart';
import 'package:trainings_core/trainings_core.dart';

const kGymLogFortschritt = Key('gym-log-fortschritt');
const kGymLogGespeichert = Key('gym-log-gespeichert');
const kGymLogBilanz = Key('gym-log-bilanz');
const kGymLogHinweis = Key('gym-log-hinweis');
const kGymLogFussnote = Key('gym-log-fussnote');
const kGymLogVollbildOeffnen = Key('gym-log-vollbild');
const kGymEckdaten = Key('gym-eckdaten');
const kGymEckdatenDauer = Key('gym-eckdaten-dauer');
const kGymEckdatenNotiz = Key('gym-eckdaten-notiz');
const kGymZwischenspeichern = Key('gym-zwischenspeichern');
const kGymAbschliessen = Key('gym-abschliessen');
const kGymAbbrechen = Key('gym-abbrechen');
const kGymVerwerfenFrage = Key('gym-verwerfen-frage');
const kGymVerwerfenBestaetigen = Key('gym-verwerfen-bestaetigen');
const kGymVerwerfenWeiter = Key('gym-verwerfen-weiter');
const kGymLaufendesFrage = Key('gym-laufendes-frage');
const kGymLaufendesErsetzen = Key('gym-laufendes-ersetzen');
const kGymLaufendesWeiter = Key('gym-laufendes-weiter');

Key kGymUebung(String id) => Key('gym-uebung-$id');
Key kGymUebungKopf(String id) => Key('gym-uebung-kopf-$id');
Key kGymZusammenfassung(String id) => Key('gym-uebung-zusammenfassung-$id');
Key kGymVorschlag(String id) => Key('gym-vorschlag-$id');
Key kGymUmschalter(String id) => Key('gym-umschalter-$id');
Key kGymUmschalterZusatz(String id) => Key('gym-umschalter-$id-zusatz');
Key kGymUmschalterUnterstuetzung(String id) =>
    Key('gym-umschalter-$id-unterstuetzung');
Key kGymFeldGewicht(String id, int n) => Key('gym-satz-gewicht-$id-$n');
Key kGymFeldWdh(String id, int n) => Key('gym-satz-wdh-$id-$n');
Key kGymPlatzhalterGewicht(String id, int n) =>
    Key('gym-satz-platzhalter-gewicht-$id-$n');
Key kGymPlatzhalterWdh(String id, int n) =>
    Key('gym-satz-platzhalter-wdh-$id-$n');
Key kGymEinheitGewicht(String id, int n) =>
    Key('gym-satz-einheit-gewicht-$id-$n');
Key kGymEinheitWdh(String id, int n) => Key('gym-satz-einheit-wdh-$id-$n');
Key kGymTrend(String id, int n) => Key('gym-satz-trend-$id-$n');
Key kGymHaken(String id, int n) => Key('gym-satz-haken-$id-$n');
Key kGymMinus(String id, int n) => Key('gym-satz-entfernen-$id-$n');
Key kGymSatzHinzu(String id) => Key('gym-satz-hinzu-$id');
Key kGymSoGehts(String id) => Key('gym-so-gehts-$id');

/// Das ganze Bewegungsbild samt Attribution und Hinweis — **nur** im Baum,
/// wenn die Übung eines hat.
Key kGymBild(String id) => Key('gym-bild-$id');

/// `<n>` = 1: die quadratische Fläche des Bildes. `<n>` = 2: die obere Lage
/// mit dem Endbild, die ein- und ausblendet — nur im Baum bei zwei Bildern
/// und ohne reduzierte Bewegung.
Key kGymBildFrame(String id, int n) => Key('gym-bild-$id-$n');
Key kGymBildAttribution(String id) => Key('gym-bild-attribution-$id');

/// „Das Bild zeigt nicht genau diese Übung" samt `Uebungsbild.note` — nur
/// da, wenn es etwas zu sagen gibt.
Key kGymBildHinweis(String id) => Key('gym-bild-hinweis-$id');

const kGymAufwaermen = Key('gym-aufwaermen');
const kGymAufwaermenArt = Key('gym-aufwaermen-art');
const kGymAufwaermenMinuten = Key('gym-aufwaermen-minuten');
const kGymAufwaermenKm = Key('gym-aufwaermen-km');
const kGymAufwaermenUeberspringen = Key('gym-aufwaermen-ueberspringen');
Key kGymAufwaermenArtWahl(WarmUpKind art) =>
    Key('gym-aufwaermen-art-${art.code}');

const kGymPause = Key('gym-pause');
const kGymPauseStart = Key('gym-pause-start');
const kGymPauseZeit = Key('gym-pause-zeit');

const kGymVollbild = Key('gym-vollbild');
const kGymVollbildSchliessen = Key('gym-vollbild-schliessen');
const kGymVollbildWeiter = Key('gym-vollbild-weiter');
const kGymVollbildAbschliessen = Key('gym-vollbild-abschliessen');
