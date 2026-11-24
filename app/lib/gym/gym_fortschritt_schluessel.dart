// Die Schlüssel des Schirms „Fortschritt pro Übung" (#93) — an einer Stelle,
// damit Schirm und Widget-Tests (`app/test/gym/gym_fortschritt_support.dart`)
// von denselben Zeichenketten sprechen. Die Bedeutung jedes Schlüssels steht
// dort in der API-Tabelle.
//
// `<id>` ist `Exercise.id`.
import 'package:flutter/widgets.dart';

const kGymFortschrittAuswahl = Key('gym-fortschritt-auswahl');
const kGymFortschrittKachelHoechst = Key(
  'gym-fortschritt-kachel-hoechstgewicht',
);
const kGymFortschrittKachel1rm = Key('gym-fortschritt-kachel-1rm');
const kGymFortschrittWertHoechst = Key(
  'gym-fortschritt-kachel-hoechstgewicht-wert',
);
const kGymFortschrittWert1rm = Key('gym-fortschritt-kachel-1rm-wert');
const kGymFortschrittDiagramm = Key('gym-fortschritt-diagramm');
const kGymFortschrittDiagrammLeer = Key('gym-fortschritt-diagramm-leer');
const kGymFortschrittHinweis = Key('gym-fortschritt-hinweis');
const kGymFortschrittPlateau = Key('gym-fortschritt-plateau');
const kGymFortschrittFehler = Key('gym-fortschritt-fehler');
const kGymFortschrittUnterstuetzung = Key('gym-fortschritt-unterstuetzung');
const kGymFortschrittZeituebung = Key('gym-fortschritt-zeituebung');
const kGymFortschrittFussnote = Key('gym-fortschritt-fussnote');
const kGymFortschrittErneut = Key('gym-fortschritt-erneut');

/// Ein Eintrag im Menü der Auswahl.
Key kGymFortschrittWahl(String uebungId) =>
    Key('gym-fortschritt-auswahl-$uebungId');

/// Der eine Satz im Menü, wenn es außer der gerade gewählten Übung nichts
/// anzubieten gibt (#551, Nachtrag 17 Nr. 4) — nur, wo **bekannt** ist, dass
/// nichts trainiert wurde, nie beim Laden (Fehler `01`). Zeichenkette
/// festgelegt in `app/test/gym/gym_fortschritt_menue_test.dart`.
const kGymFortschrittWahlLeer = Key('gym-fortschritt-auswahl-leer');
