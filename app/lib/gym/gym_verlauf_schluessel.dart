// Die Schlüssel des Schirms „Letzte Trainings" (#79) — an einer Stelle,
// damit Schirm und Widget-Tests (`app/test/gym/verlauf_support.dart`) von
// denselben Zeichenketten sprechen. Die Namen stehen dort als API-Tabelle.
//
// `<id>` ist `ImportedSession.id`, `<uid>` ist `Exercise.id`, `<n>` die
// sichtbare Satznummer ab 1.
//
// Die Kartenschlüssel haben **bewusst keinen gemeinsamen Anfang
// untereinander** (`karte-`, `kopf-`, `inhalt-`), damit sich die Karten
// zählen lassen, ohne Kopf und Inhalt mitzuzählen.
import 'package:flutter/widgets.dart';

const kGymVerlaufKennzahlen = Key('gym-verlauf-kennzahlen');
const kGymVerlaufKachelTrainings = Key('gym-verlauf-kachel-trainings');
const kGymVerlaufKachelVolumen = Key('gym-verlauf-kachel-volumen');
const kGymVerlaufWertTrainings = Key('gym-verlauf-wert-trainings');
const kGymVerlaufWertVolumen = Key('gym-verlauf-wert-volumen');
const kGymVerlaufKartenLaedt = Key('gym-verlauf-karten-laedt');
const kGymVerlaufLeer = Key('gym-verlauf-leer');
const kGymVerlaufFehler = Key('gym-verlauf-fehler');
const kGymVerlaufHinweis = Key('gym-verlauf-hinweis');

Key kGymVerlaufKarte(String id) => Key('gym-verlauf-karte-$id');
Key kGymVerlaufKopf(String id) => Key('gym-verlauf-kopf-$id');
Key kGymVerlaufInhalt(String id) => Key('gym-verlauf-inhalt-$id');
Key kGymVerlaufUebung(String id, String uid) =>
    Key('gym-verlauf-uebung-$id-$uid');
Key kGymVerlaufSatz(String id, String uid, int n) =>
    Key('gym-verlauf-satz-$id-$uid-$n');
Key kGymVerlaufAufwaermen(String id) => Key('gym-verlauf-aufwaermen-$id');
Key kGymVerlaufNotiz(String id) => Key('gym-verlauf-notiz-$id');

// --- Puls und Übungsband (#512) ----------------------------------------------
//
// Festgelegt in `app/test/gym/gym_puls_support.dart`. `<n>` ist die Position
// der Übung in der Sitzung, ab 1 — nicht die Zahl der Übungen mit Abschnitt.

/// Der Pulsblock als Ganzes — **auch der `Semantics`-Knoten** —, in jeder
/// offenen Karte und in jedem der vier Zustände.
Key kGymPuls(String id) => Key('gym-puls-$id');
Key kGymPulsWert(String id) => Key('gym-puls-wert-$id');
Key kGymPulsBereich(String id) => Key('gym-puls-bereich-$id');
Key kGymPulsFlaeche(String id) => Key('gym-puls-flaeche-$id');

/// Der Grund — **nur** bei `LeerNachLauf`.
Key kGymPulsGrund(String id) => Key('gym-puls-grund-$id');

/// Der Hinweis — **nur** bei `Fehlgeschlagen`, nie der Grund von
/// `LeerNachLauf`.
Key kGymPulsFehler(String id) => Key('gym-puls-fehler-$id');

/// Das Band, dessen Breite die ganze Trainingsdauer ist — **nur**, wo
/// mindestens ein Abschnitt entsteht.
Key kGymVerlaufBand(String id) => Key('gym-verlauf-band-$id');
Key kGymVerlaufBandAbschnitt(String id, int n) =>
    Key('gym-verlauf-band-$id-$n');

/// Der Satz, warum es kein Band gibt — **nur** bei `Bekannt` ohne Abschnitt.
Key kGymVerlaufBandGrund(String id) => Key('gym-verlauf-bandgrund-$id');

/// Die Ziffer vor der Übungszeile — **nur** bei Abschnitt.
Key kGymVerlaufNr(String id, String uid) => Key('gym-verlauf-nr-$id-$uid');

/// Das Ø rechts in der Übungszeile — **nur** bei Abschnitt.
Key kGymVerlaufUebungsPuls(String id, String uid) =>
    Key('gym-verlauf-uebungspuls-$id-$uid');
