// Die Schlüssel des Schirms „Daten übernehmen" (#59 Teil 1, Umfänge #498).
// Die Namen sind verbindlich: `app/test/uebernahme/uebernahme_support.dart`
// führt dieselben Zeichenketten, und der Entwurf
// `docs/screens/screens/import.js` nennt sie in seiner Tabelle.
import 'package:flutter/widgets.dart';

const kUebernahmeWaehlen = Key('uebernahme-waehlen');
const kUebernahmeUmfang = Key('uebernahme-umfang');
const kUebernahmeLeer = Key('uebernahme-leer');
const kUebernahmeLaeuft = Key('uebernahme-laeuft');
const kUebernahmeFertig = Key('uebernahme-fertig');
const kUebernahmeAbgelehnt = Key('uebernahme-abgelehnt');
const kUebernahmeGescheitert = Key('uebernahme-gescheitert');
const kUebernahmeErgebnis = Key('uebernahme-ergebnis');
const kUebernahmeUnbekannt = Key('uebernahme-unbekannt');
const kUebernahmeUngelesen = Key('uebernahme-ungelesen');
const kUebernahmeZeitzone = Key('uebernahme-zeitzone');

const kZahlInDatei = Key('uebernahme-zahl-in-datei');
const kZahlNeu = Key('uebernahme-zahl-neu');
const kZahlSchonDa = Key('uebernahme-zahl-schon-da');
const kZahlNichtUebernommen = Key('uebernahme-zahl-nicht-uebernommen');
const kZahlNichtLesbar = Key('uebernahme-zahl-nicht-lesbar');

// Die Umfänge stehen in einer **eigenen** Karte (#498): Die fünf Wertplätze
// darüber zählen Trainings, und „Neu übernommen" hieße in einer gemeinsamen
// Karte zweimal etwas anderes.
const kUebernahmeErgebnisUmfaenge = Key('uebernahme-ergebnis-umfaenge');

// Je Schlüssel genau eine Zahl. Werte und Tage stehen getrennt, weil eine
// Messung mit dreizehn Maßen **ein** Tag und **dreizehn** Werte ist — in
// einem Textknoten ließe sich keines von beidem prüfen.
const kZahlUmfaengeNeu = Key('uebernahme-zahl-umfaenge-neu');
const kTageUmfaengeNeu = Key('uebernahme-tage-umfaenge-neu');
const kZahlUmfaengeSchonDa = Key('uebernahme-zahl-umfaenge-schon-da');
const kTageUmfaengeSchonDa = Key('uebernahme-tage-umfaenge-schon-da');
const kZahlUmfaengeNichtLesbar = Key('uebernahme-zahl-umfaenge-nicht-lesbar');

/// Der Hinweis auf unbekannte Maße — er **nennt die Namen**, nicht ihre
/// Anzahl: Eine Zahl sagt nicht, welches Maß gefehlt hat, und nachsehen
/// kann man es hinterher nicht mehr.
const kUebernahmeUmfaengeUnbekannt = Key('uebernahme-umfaenge-unbekannt');

Key kUebernahmeAuslassung(String id) => Key('uebernahme-auslassung-$id');
Key kUebernahmeNichtLesbar(int index) => Key('uebernahme-nicht-lesbar-$index');

/// Je Zeile unter „Nicht lesbar" der Umfänge, wie [kUebernahmeNichtLesbar].
Key kUebernahmeUmfaengeNichtLesbar(int index) =>
    Key('uebernahme-umfaenge-nicht-lesbar-$index');
