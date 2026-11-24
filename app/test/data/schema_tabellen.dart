/// Die Tabellenliste der Schema-Tests — **eine** Stelle statt sieben
/// (#304).
///
/// Vorher hielten `schema_v10_test.dart` bis `schema_v13_test.dart`,
/// `schema_abgleich_test.dart`, `schema_stufen_robust_test.dart` und
/// `schema_fremde_spalten_test.dart` je eine eigene Kopie, und jede Stufe,
/// die eine Tabelle anlegt, machte alle davon rot. Jetzt zieht die nächste
/// Stufe nur diese Datei nach.
///
/// **Wörtlich, nicht aus `AppCache.allTables` abgeleitet.** Ein Vergleich
/// gegen den Produktionscode wüchse zwar mit, merkte aber nicht, wenn eine
/// Tabelle versehentlich verschwindet (#304, „Die Abwägung"). Wer hier
/// eine Tabelle einträgt, behauptet, dass es sie nach der Migration gibt —
/// und die Tests, die gegen [tabellenHeute] auf Gleichheit prüfen, halten
/// ihn daran fest.
///
/// Aufgeteilt nach Stufen, damit ein Test, der vom Stand einer früheren
/// Stufe handelt, ihn als „Endstand minus neuere Tabellen" ausdrücken kann.
/// Nachgezogen vom Test-Agenten mit Stufe 15 (#332); die Aufteilung ist
/// eine Festlegung des Test-Agenten, nicht von Tim freigegeben.
library;

/// Die dreizehn Tabellen bis einschließlich Stufe 14. `tagesgefuehle` ist
/// seit #269 (Stufe 10) keine mehr, `stammdaten` kam mit Stufe 11, die fünf
/// Ernährungstabellen mit Stufe 12; Stufe 13 und 14 legten keine an.
const tabellenBisStufe14 = {
  'tages_werte',
  'stunden_schritte',
  'eigene_daten',
  'naechte',
  'schlaf_abschnitte',
  'ziel_werte',
  'schlaf_eintraege',
  'stammdaten',
  'lebensmittel',
  'portionen',
  'eintraege',
  'rezepte',
  'rezept_zutaten',
};

/// Die beiden, die Stufe 15 anlegt (KI-Zugang, #332) — verlangt in
/// `schema_v15_test.dart`.
const tabellenAusStufe15 = {'ki_einstellungen', 'ki_anfragen'};

/// Die eine, die Stufe 16 anlegt (eingetragenes Wasser, #311) — verlangt
/// in `schema_v16_test.dart`. Nachgezogen vom Test-Agenten, nicht von Tim
/// freigegeben.
const tabellenAusStufe16 = {'wasser_eintraege'};

/// Die drei, die Stufe 18 anlegt (Gym-Trainings, #78 mit #40) — verlangt
/// in `schema_v18_test.dart`. Stufe 17 legte keine an. Nachgezogen am
/// 10.11.2026 mit `TEST_AENDERN=1`, nicht von Tim freigegeben.
const tabellenAusStufe18 = {
  'gym_sitzungen',
  'gym_saetze',
  'gym_entwuerfe',
};

/// Die eine, die Stufe 19 anlegt (die Historie des festen Kalorienziels,
/// #410) — verlangt in `schema_v19_test.dart`. Beim Zusammenführen von
/// `umfaenge-88` und `main` am 11.11.2026 von 18 auf 19 gerückt, weil die
/// Gym-Stufe die 18 behält (#485). Nachgezogen vom Test-Agenten, nicht von
/// Tim freigegeben.
const tabellenAusStufe19 = {'kalorienziele'};

/// Die eine, die Stufe 21 anlegt (die Aufteilung des Tagesziels auf die
/// Mahlzeiten, #430 unter #374) — verlangt in `schema_v21_test.dart`.
/// Stufe 20 legte keine an. Beim Zusammenführen am 11.11.2026 von 20 auf
/// 21 gerückt (#485). Nachgezogen vom Test-Agenten, nicht von Tim
/// freigegeben.
const tabellenAusStufe21 = {'mahlzeit_aufteilungen'};

/// Die eine, die Stufe 22 anlegt (Ereignisse, zunächst die Auszeiten,
/// #444 unter #404) — verlangt in `schema_v22_test.dart`. Beim
/// Zusammenführen am 11.11.2026 von 21 auf 22 gerückt (#485). Nachgezogen
/// vom Test-Agenten, nicht von Tim freigegeben.
const tabellenAusStufe22 = {'ereignisse'};

/// Die eine, die Stufe 23 anlegt (Wachbelege für die Tagesgrenze, #451
/// unter #375) — verlangt in `schema_v23_test.dart`. Beim Zusammenführen
/// am 11.11.2026 von 22 auf 23 gerückt (#485). Nachgezogen vom
/// Test-Agenten, nicht von Tim freigegeben.
const tabellenAusStufe23 = {'wach_belege'};

/// Die eine, die Stufe 24 anlegt (Tims Maßband-Messungen, #476 unter #88)
/// — verlangt in `schema_v24_test.dart`. Beim Zusammenführen am
/// 11.11.2026 von 23 auf 24 gerückt (#485). Nachgezogen vom Test-Agenten,
/// **Tim hat die Änderung nicht gesehen**.
const tabellenAusStufe24 = {'umfaenge'};

/// Die drei, die Stufe 26 anlegt (der Zykluskalender, #592 unter #539) —
/// verlangt in `schema_v26_test.dart`. Nachgezogen vom Test-Agenten mit
/// `TEST_AENDERN=1`, **Tim hat die Änderung nicht gesehen**.
const tabellenAusStufe26 = {
  'zyklus_eintraege',
  'zyklus_health_spiegel',
  'zyklus_einstellungen',
};

/// Die vier, die Stufe 27 anlegt (eigene Trainings, #532 unter #531:
/// `gym_trainings`, `gym_training_uebungen`, `gym_training_tags`; dazu die
/// gespeicherte Rotation `gym_rotation`, vorgezogener Datenteil von #536) —
/// verlangt in `schema_v27_test.dart`. Die Stufe legt außerdem die Spalte
/// `gym_sitzungen.trainings_name` an; die steht hier nicht, weil diese
/// Datei nur Tabellen führt. Die Stufe hieß bis zum Zusammenführen der
/// beiden `main`-Stände am 24.11.2026 die 25. Nachgezogen vom
/// Test-Agenten, **Tim hat die Änderung nicht gesehen**.
const tabellenAusStufe27 = {
  'gym_trainings',
  'gym_training_uebungen',
  'gym_training_tags',
  'gym_rotation',
};

/// Alle Tabellen, die `AppCache` heute hat — nach jeder Migration, auf
/// jedem Weg.
const tabellenHeute = {
  ...tabellenBisStufe14,
  ...tabellenAusStufe15,
  ...tabellenAusStufe16,
  ...tabellenAusStufe18,
  ...tabellenAusStufe19,
  ...tabellenAusStufe21,
  ...tabellenAusStufe22,
  ...tabellenAusStufe23,
  ...tabellenAusStufe24,
  ...tabellenAusStufe26,
  ...tabellenAusStufe27,
};
