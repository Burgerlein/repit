// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das kollidiert mit `package:matcher`s `isNull`-Matcher, den
// `expect(..., isNull)` unten braucht. Keiner dieser Tests baut einen
// `IS NULL`-Ausdruck von Hand, daher wird drifts Variante ausgeblendet.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/tables.dart';

/// Tests für `AppCache` (drift, Task 6) — den Cache auf der Platte aus Spec
/// 5.5/5.6/5.6a in
/// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md`.
///
/// **Warum es diesen Cache überhaupt gibt:** Tim sieht beim Start seine
/// Schritte, navigiert herum, kommt zurück — und da steht 0. Diagnose dazu
/// in #55 („Das Schritte-Detail hängt"): Der Ladezustand wird als
/// Leerstand dargestellt, weil beim erneuten Öffnen eines Schirms noch
/// nichts vorliegt und frisch aus HealthKit gelesen wird. Spec 5.5 löst das
/// über eine Ladereihenfolge, die **zuerst** diesen drift-Cache liest (schnell,
/// auf dem DB-Isolate) und erst danach HealthKit fragt — `Messwert<T>`
/// (Task 5, `lib/core/messwert.dart`) trägt den Cache-Stand als `Bekannt`
/// weiter. Dieser Test prüft die andere Hälfte: dass der Cache selbst
/// zuverlässig ist — insbesondere, dass er bei einer Schemaänderung nicht
/// stillschweigend verworfen wird (Review-Focus 5 des Umsetzungsplans) und
/// dass sein Tagesschlüssel so funktioniert, wie `DataWindow.clip(...)` es
/// als `WHERE tag >= ?` voraussetzt (Spec 5.6, letzter Punkt).
///
/// **Entscheidung — die zweite Schemaversion für den Migrationstest
/// (task-6-brief.md verlangt das explizit, es gibt noch keine v2; im Verlauf
/// der Umsetzung getroffen, Protokoll und Begründung in
/// task-6-tests-report.md — Tim hat diese Entscheidung nicht gesehen und ihr
/// nicht zugestimmt):** Eine zusätzliche nullbare
/// Spalte `gelesenAm` (`DateTime?`) auf `TagesWerte` — **nicht** eine neue
/// Health-Metrik wie zuerst erwogen (verworfen: Schlaf kommt in dieser App
/// nicht als Tagessumme, sondern als `SleepNight` mit Phasen; eine Spalte
/// einzubauen, die niemand will, wäre Gerüst, das für immer stehen bleibt).
/// `gelesenAm` trägt, **wann diese Zeile aus Apple Health geholt wurde** —
/// je Zeile, nicht als ein globaler Zeitstempel für den ganzen Cache. Das
/// ist Spec 5.3b wörtlich: `stand` („woher die Zahl stammt") ist je
/// `Messwert`-Instanz verschieden, und ein Provider in Task 13 muss für
/// `Bekannt(…, stand: …)` wissen, wie alt **die jeweilige** Zeile ist, nicht
/// nur, dass der Cache insgesamt irgendwann zuletzt lief. Diese Spalte wird
/// dadurch wirklich gebraucht, nicht nur erfunden, damit die Migration
/// etwas zu tun hat — der Schnitt „v1 hat die Messwerte, v2 weiß zusätzlich,
/// wann wir sie geholt haben" ist zugegeben etwas künstlich, aber bewusst so
/// gewählt: Er macht die Migration echt statt synthetisch, und die Spalte
/// bleibt nützlich, falls man diesen Schnitt später vergisst.
///
/// Daraus folgt zwingend, dass `AppCache.schemaVersion == 2` ist, **nicht**
/// `1` — die Zahl `1` aus den Interfaces von task-6-brief.md war geschrieben,
/// bevor klar war, dass der Migrationstest eine echte zweite Version
/// braucht, um überhaupt etwas zu prüfen, und dass dieser Pfad vom ersten
/// Tag an geprüft sein soll, nicht erst bei der ersten echten
/// Schemaänderung. Die Tests hier sind bindend, nicht die ursprüngliche
/// Zahl im Brief.
///
/// **Wie der Migrationstest gebaut ist, und warum nicht über
/// `drift_dev schema dump`/`SchemaVerifier`:** Dieser offizielle Weg (siehe
/// `package:drift_dev/api/migrations_native.dart`) setzt voraus, dass
/// `lib/data/tables.dart` schon existiert, einmal gebaut wurde und ihr
/// Schema per `dart run drift_dev schema dump` als JSON unter
/// `drift_schemas/` eingefroren ist — Henne-Ei-Problem für eine Testdatei,
/// die genau dieser Implementierung vorausgeht und sie nicht selbst anlegen
/// darf. Stattdessen wird Schema v1 von Hand nachgebaut: eine
/// `NativeDatabase.memory()` bekommt über ihren `setup`-Callback rohes SQL
/// (`CREATE TABLE`, `INSERT`) **und** `PRAGMA user_version = 1` — ohne dieses
/// Pragma sähe drift beim Öffnen Version 0 und riefe `onCreate` statt
/// `onUpgrade` auf (bestätigt in
/// `package:drift/src/runtime/executor/helpers/engines.dart`,
/// `_runMigrations`: `oldVersion` kommt aus `PRAGMA user_version`, und der
/// `setup`-Callback von `NativeDatabase` läuft nachweislich vor dieser
/// Prüfung). Erst danach wird `AppCache` auf genau dieser Verbindung
/// geöffnet; ihr `migration`-Getter muss die Version 1→2 behandeln, damit
/// die Zeile aus Schema v1 erhalten bleibt. Für eine rein additive, nullbare
/// Spalte reicht `Migrator.addColumn(tagesWerte, tagesWerte.gelesenAm)`
/// auf der **aktuellen** Tabellendefinition — eine historische
/// Schema-Snapshot-Datei ist dafür nicht nötig. Sollte eine künftige
/// Migration Spalten umbenennen, Typen ändern oder Tabellen umbauen, reicht
/// das nicht mehr; dann wird die `drift_schemas/`-Pipeline aus Spec 5.6
/// nötig. Das ist bewusst keine Festlegung dieses Tasks, nur ein Hinweis für
/// später.
///
/// **API, die diese Tests von `lib/data/tables.dart` und `lib/data/cache.dart`
/// verlangen (verbindlich für den Implementierenden, da diese Datei nicht
/// verändert werden darf):**
///
/// - `class TagesWerte extends Table` mit `@DataClassName('TagesWerteRow')`,
///   SQL-Tabelle `tages_werte` (drifts Standard-Snake-Case der Klasse —
///   keine eigene `tableName`-Überschreibung nötig oder erwartet):
///   - `tag` (`TextColumn`, Primärschlüssel, ISO-Tagesschlüssel)
///   - `schritte` (`IntColumn`, nullable)
///   - `ruhepulsBpm` (`IntColumn`, nullable) → SQL-Spalte `ruhepuls_bpm`
///   - `gelesenAm` (`DateTimeColumn`, nullable) → SQL-Spalte `gelesen_am`
///     — **die v2-Spalte dieser Entscheidung**: wann diese Zeile aus Apple
///     Health geholt wurde (Spec 5.3b, `stand` je Zeile statt global)
/// - `class StundenSchritte extends Table` mit
///   `@DataClassName('StundenSchritteRow')`, SQL-Tabelle
///   `stunden_schritte`:
///   - `tag` (`TextColumn`), `stunde` (`IntColumn`, 0–23), beide zusammen
///     Primärschlüssel
///   - `schritte` (`IntColumn`, nullable)
/// - `class EigeneDaten extends Table` mit
///   `@DataClassName('EigeneDatenRow')`, SQL-Tabelle `eigene_daten` — **gilt
///   nicht als Messwert-Gruppe** (Spec 5.6a: „leer heißt dort leer"), hier
///   als ein Platzhalter-Repräsentant der zweiten Tabellengruppe aus Spec
///   5.6a (die konkreten Tabellen für Gym-Trainings, Umfänge und
///   Tagestausch sind nicht Gegenstand dieses Tasks):
///   - `id` (`IntColumn`, `autoIncrement()`)
///   - `tag` (`TextColumn`, **nicht** nullable — ein eigener Eintrag, der
///     existiert, hat immer einen Tag)
///   - `inhalt` (`TextColumn`, **nicht** nullable)
/// - `class AppCache extends _$AppCache`:
///   - Konstruktor `AppCache(QueryExecutor executor)` (drifts
///     Standardkonstruktor für die generierte Basisklasse) — zusätzlich zur
///     in task-6-brief.md genannten Fabrik `AppCache.oeffnen()` über
///     `drift_flutter`, die dieser Test nicht anspricht (sie bräuchte
///     `path_provider`/Plattform-Kanäle, siehe „ohne Gerät" im Aufrag).
///   - `schemaVersion => 2`
///   - `migration`: `onCreate: (m) => m.createAll()`,
///     `onUpgrade` behandelt `from < 2` mit
///     `m.addColumn(tagesWerte, tagesWerte.gelesenAm)`.
///
/// **Nachtrag vom 27.10.2026 — die Schemaversion ist auf 5 gestiegen.**
/// Drei Tickets der Erholung legen nacheinander etwas ab, jedes mit einer
/// eigenen Version und einem eigenen Migrationsschritt (ausführliche
/// Begründung im Dateikopf von `test/data/schema_v3_test.dart`, das die
/// Migration v2 → aktuell prüft):
///
/// - **v3** (#113, Spec `2026-10-26-erholung-flutter-design.md` Abschnitt
///   10a Punkt 3): drei nullbare Spalten in `TagesWerte` (`hrv_ms`,
///   `resp_rate`, `recovery_hr_drop`) und die beiden Schlaf-Tabellen
///   `naechte` / `schlaf_abschnitte`.
/// - **v4** (#111): `ziel_werte` — Schlafziel, Schlafenszeitziel, Wochenziel
///   Trainingsminuten.
/// - **v5** (#118): `tagesgefuehle` — Tagesgefühl 1–5, ein Eintrag je Tag.
///
/// **Nachtrag vom 02.11.2026 — die Schemaversion steigt auf 7.** Zwei
/// Zweige hoben sie unabhängig voneinander auf 6; beim Zusammenführen hat
/// #194 die 7 bekommen, #131 die 6 behalten.
///
/// - **v6** (#131): `schlaf_eintraege` — die von Hand eingetragenen Nächte
///   und Tagschläfe. Geprüft in `test/data/schlaf_eintrag_test.dart`.
/// - **v7** (#194, Spec `2026-10-31-194-tageswechsel-und-cachespalten.md`
///   Abschnitt 2): zwei nullbare Spalten in `TagesWerte` (`gewicht_kg`,
///   `trainings_minuten`), additiv und ohne Rückschreiben. Geprüft in
///   `test/data/schema_v7_test.dart`.
///
/// **Warum herum, entscheidet der Bestand auf dem Gerät, nicht das Datum
/// der Tickets.** Dort steht `user_version = 6`, und die 6 bedeutet dort
/// „`schlaf_eintraege` ist angelegt" — die Tabelle existiert, mit
/// Einträgen darin. Bekäme #131 die 7 und #194 die 6, liefe die Stufe
/// `from < 6` auf diesem Gerät nie, die Datei spränge trotzdem auf 7, und
/// die beiden Spalten kämen dort nie an — stumm, denn `createTable`
/// schreibt `CREATE TABLE IF NOT EXISTS`. So herum läuft genau die eine
/// Stufe nach, die das Gerät noch nicht kennt.
///
/// **Nachtrag vom 03.11.2026 — die Schemaversion steigt auf 9.**
///
/// - **v8** (#193): `ruhepuls_bpm`, `hrv_ms` und `resp_rate` auf `naechte`
///   — die drei Werte **einer Nacht**, gerechnet über das Schlaffenster
///   statt über den Kalendertag. Additiv und ohne Rückschreiben. Geprüft
///   in `test/data/schema_v8_test.dart`.
/// - **v9** (#202): zwei nullbare Spalten in `TagesWerte`
///   (`koerperfett_pct`, `fettfrei_kg`), additiv und ohne Rückschreiben.
///   Geprüft in `test/data/schema_v9_test.dart`.
///
/// **Nachtrag vom 03.11.2026 — die Schemaversion steigt auf 10.** Die
/// erste Stufe, die etwas **wegnimmt**:
///
/// - **v10** (#269): `tagesgefuehle` wird gelöscht. Tim hat das Tagesgefühl
///   abbestellt und das Mitlöschen der Tabelle ausdrücklich entschieden;
///   seine bisherigen Einträge sind damit endgültig weg. Die v5-Stufe
///   bleibt trotzdem stehen — ein Gerät von v4 läuft durch v5 und erst
///   danach durch v10. Geprüft in `test/data/schema_v10_test.dart`.
///
/// **Warum #202 die v9 bekam und nicht die v7**, die es im eigenen Zweig
/// trug (#235, entschieden beim Zusammenführen am 03.11.2026, nicht von
/// Tim): dieselbe Überlegung wie eine Absatzlänge weiter oben, nur ein
/// Zweig später. `koerper-datenkette` zweigte ab, bevor #194 und #193 auf
/// `main` lagen, und zählte seine Stufe 7 unabhängig weiter — dieselbe
/// Nummer, zwei Bedeutungen. Behielte #202 die 7, liefe seine Stufe auf
/// jedem Gerät, das schon auf 8 steht, nie, und die beiden Spalten kämen
/// dort nie an. Die nächste freie Nummer ist die einzige, die das nicht
/// tut.
///
/// Die einzige Zeile, die diese Nachträge an dieser Datei ändern, ist die
/// erwartete Zahl in Pflichtfall 1. Jede andere Zusicherung hier gilt
/// unverändert weiter — insbesondere die aus Schema v1 migrierte Zeile, die
/// jetzt über acht Versionen hinweg erhalten bleiben muss statt über eine.
///
/// **Was absichtlich nicht geprüft wird:**
/// - `AppCache.oeffnen()` selbst (drift_flutter/`getApplicationSupportDirectory`
///   brauchen eine echte Plattform — das ist laut Aufgabenstellung „ohne
///   Gerät" zu testen; ein Verzeichnis-Pfadtest ohne echten I/O-Zugriff
///   würde nur die Tippfehlerfreiheit eines Strings belegen).
/// - `StundenSchritte` bekommt nur den einen Nullbarkeits-Test unten, keine
///   eigene Bereichs- oder Sortierprüfung — die Tagesschlüssel-Mechanik ist
///   an `TagesWerte` stellvertretend für beide Tabellen geprüft, eine zweite
///   Kopie derselben Prüfung auf einer zweiten Tabelle belegt nichts Neues.
/// - Die konkreten Tabellen für Gym-Trainings/Umfänge/Tagestausch aus Spec
///   5.6a — nur das Gruppenprinzip (Messwert gilt nicht, leer heißt leer)
///   wird stellvertretend an `EigeneDaten` geprüft.
/// - Das `*.sqlite`/`*.db`-Verbot aus `.gitignore`: Jeder Test hier läuft
///   ausschließlich über `NativeDatabase.memory()` — es entsteht nie eine
///   Datei, die versehentlich committet werden könnte.
void main() {
  group('Pflichtfall 1 (task-6-brief.md) — Datenbank öffnet, aktuelle Schemaversion', () {
    test(
      'ein frischer Cache legt alle drei Tabellen an und meldet '
      'Schemaversion 28 (v2 wegen der Migrationsspalte, v3/v4/v5 wegen der '
      'drei Erholungs-Tickets, v6 wegen der eigenen Schlafeinträge, v7 '
      'wegen der Gewichts- und Trainingsspalte, v8 wegen der Nachtwerte, '
      'v9 wegen Körperfett und fettfreier Masse, v10 wegen der Löschung '
      'des Tagesgefühls, v11 wegen der Stammdaten, v12 wegen der fünf '
      'Ernährungstabellen, v13 wegen der Spalten von lebensmittel, v14 '
      'wegen Strichcode und Herkunft, v15 wegen des KI-Zugangs, v16 wegen '
      'des eingetragenen Wassers, v17 wegen der Portionen, v18 wegen der '
      'drei Gym-Tabellen, v19 wegen des festen Kalorienziels, v20 wegen '
      'eintraege.fluessig, v21 wegen der Aufteilung je Mahlzeit, v22 '
      'wegen der Ereignisse, v23 wegen der Wachbelege, v24 wegen der '
      'Umfänge, v25 wegen der Sync-Felder, v26 wegen der drei '
      'Zyklus-Tabellen, v27 wegen der eigenen Trainings, v28 wegen der '
      'VO₂max-Spalte — siehe Nachträge im Dateikopf)',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        // Ein Zugriff je Tabellengruppe stellt sicher, dass `onCreate`
        // tatsächlich lief (das Öffnen selbst ist bei drift lazy) — und
        // dass alle drei aus den Interfaces von task-6-brief.md geforderten
        // Tabellen existieren, nicht nur die erste.
        expect(await db.select(db.tagesWerte).get(), isEmpty);
        expect(await db.select(db.stundenSchritte).get(), isEmpty);
        expect(await db.select(db.eigeneDaten).get(), isEmpty);

        // Die 28 steht hier seit dem 24.11.2026, Grund: #95 (mit #16)
        // gibt `tages_werte` die Spalte `vo2max`, damit der
        // Ausdauer-Schirm VO₂max aus dem Cache zeigen kann — verlangt in
        // `test/data/schema_v28_test.dart`.
        //
        // Die 27 steht hier seit demselben Tag, Grund: #532 (unter #531)
        // legt für die eigenen Trainings die Tabellen `gym_trainings`,
        // `gym_training_uebungen`, `gym_training_tags` und `gym_rotation`
        // an und gibt `gym_sitzungen` die Spalte `trainings_name` —
        // verlangt in `test/data/schema_v27_test.dart`.
        //
        // **Beide sind beim Zusammenführen der zwei `main`-Stände am
        // 24.11.2026 von 25 und 26 auf 27 und 28 gerückt.** Die Stände
        // waren am 17.11.2026 auseinandergelaufen und hatten vom
        // gemeinsamen Stand 24 aus unabhängig je eine 25 und eine 26
        // vergeben. Die Nummern des gepushten Standes bleiben, die
        // hiesigen rücken hoch — eine Nummer sagt, was ein Gerät schon
        // ausgeführt hat (#485, dieselbe Auflösung wie bei v18, v24 und
        // v26).
        //
        // Die 25 steht hier seit dem 23.11.2026, Grund: #542 (unter #543)
        // hängt `lebensmittel` und `rezepte` die Sync-Felder an — `uuid`,
        // `geaendert_am`, `geloescht_am`, `autor`, bei `lebensmittel` dazu
        // `quelle_schluessel`; verlangt in
        // `test/data/migration_v25_test.dart`.
        //
        // Die 26 steht hier seit dem 24.11.2026, Grund: #592 (unter #539)
        // legt für den Zykluskalender die drei Tabellen
        // `zyklus_eintraege`, `zyklus_health_spiegel` und
        // `zyklus_einstellungen` an — verlangt in
        // `test/data/schema_v26_test.dart`. Nachgezogen vom Test-Agenten
        // mit `TEST_AENDERN=1`; **Tim hat die Änderung nicht gesehen.**
        //
        // Davor stand hier die 24 (seit dem 11.11.2026), Grund: Beim
        // Zusammenführen von `umfaenge-88` und `main` (#485) trafen zwei
        // unabhängig vergebene Stufen 18 aufeinander. Die Gym-Stufe (#78)
        // behält die 18 — sie ist auf Tims iPhone schon gelaufen und dort
        // in der Datei vermerkt —, die Stufen dieses Zweigs sind um eins
        // nach oben gerückt: das feste Kalorienziel auf 19,
        // `eintraege.fluessig` auf 20, die Aufteilung je Mahlzeit auf 21,
        // die Ereignisse auf 22, die Wachbelege auf 23 und die Umfänge
        // auf 24. Die Stufen-Tests sind mitgewandert; die Einträge
        // darunter nennen die Dateinamen, die zu ihrem jeweiligen
        // Zeitpunkt galten. Nachgezogen vom Test-Agenten; **Tim hat die
        // Änderung nicht gesehen.**
        //
        // Davor stand hier die 22 (seit dem 10.11.2026), Grund: #451 (unter #375)
        // legt für die Tagesgrenze die Tabelle `wach_belege` an — verlangt
        // in `test/data/schema_v22_test.dart`. Nachgezogen vom
        // Test-Agenten; Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 21 (seit dem 10.11.2026), Grund: #444 (unter #404)
        // legt für die Auszeiten die Tabelle `ereignisse` an — verlangt in
        // `test/data/schema_v21_test.dart`. Nachgezogen vom Test-Agenten;
        // Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 20 (seit dem 10.11.2026), Grund: #430 (unter #374)
        // legt für die Aufteilung des Tagesziels auf die Mahlzeiten die
        // Tabelle `mahlzeit_aufteilungen` an — verlangt in
        // `test/data/schema_v20_test.dart`. Nachgezogen vom Test-Agenten;
        // Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 19 (seit dem 10.11.2026), Grund: #403 (unter #275)
        // gibt `eintraege` die Spalte `fluessig`, den Schnappschuss „in
        // Millilitern gebucht" — verlangt in `test/data/schema_v19_test.dart`.
        // Die 18 gehört der Stufe, die parallel auf dem Zweig `ziel-fest`
        // entstand (#410, Absatz darunter; Begründung im Kopf von
        // `schema_v19_test.dart`). Beim Zusammenführen galt die höhere Zahl.
        // Nachgezogen vom Test-Agenten; Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 22 (seit dem 10.11.2026), Grund: #451 (unter
        // #375) legt für die Tagesgrenze die Tabelle `wach_belege` an —
        // verlangt in `test/data/schema_v22_test.dart`. Jetzt die 23
        // (11.11.2026), Grund: #476 (unter #88) legt für Tims
        // Maßband-Messungen die Tabelle `umfaenge` an — verlangt in
        // `test/data/schema_v23_test.dart`. Nachgezogen vom Test-Agenten;
        // **Tim hat die Änderung nicht gesehen.**
        //
        // Davor stand hier die 18 (seit dem 10.11.2026), Grund: #410 (unter
        // #275) legt für das feste Kalorienziel die Tabelle `kalorienziele`
        // an — verlangt in `test/data/schema_v18_test.dart`. Nachgezogen vom
        // Test-Agenten; Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 17 (seit dem 05.11.2026), Grund: #393 (unter #325)
        // gibt `portionen` ihre Spalten, `eintraege` den Schnappschuss der
        // gebuchten Portion und `lebensmittel` die Marke
        // `portionen_abgefragt_am` — verlangt in
        // `test/data/schema_v17_test.dart`. Nachgezogen vom Test-Agenten;
        // Tim hat die Änderung nicht gesehen.
        //
        // Davor stand hier die 16 (seit dem 04.11.2026, Nacht-Runde), Grund:
        // #311 legt für eingetragenes Wasser die Tabelle `wasser_eintraege`
        // an — verlangt in `test/data/schema_v16_test.dart`.
        //
        // Davor stand hier die 15, vorher die 14 (und davor,
        // am selben Tag, die 13, die 12, die 11 und die 10). Grund: #332
        // legt für den KI-Zugang die Tabellen `ki_einstellungen` und
        // `ki_anfragen` an und gibt `eintraege` die Spalte `vorschlag`, in
        // einer eigenen, additiven Stufe — verlangt in
        // `test/data/schema_v15_test.dart`.
        // Nachgezogen vom Test-Agenten, nicht von dem, der die
        // Implementierung schreibt; der darf eine bestehende Erwartung
        // nicht passend machen (`CLAUDE.md`, Rollentrennung). Tim hat die
        // Änderung nicht gesehen.
        expect(
          db.schemaVersion,
          28,
          reason:
              'v2 brachte `gelesen_am` (Entscheidung oben), v3 die drei '
              'Erholungs-Spalten und die Schlaf-Tabellen (#113), v4 die '
              'Ziele (#111), v5 das Tagesgefühl (#118), v6 die von Hand '
              'eingetragenen Schlafphasen (#131), v7 `gewicht_kg` und '
              '`trainings_minuten` (#194), v8 die drei Nachtwerte auf '
              '`naechte` (#193), v9 `koerperfett_pct` und `fettfrei_kg` '
              '(#202), v10 die Löschung von `tagesgefuehle` (#269), v11 '
              'die Tabelle `stammdaten` (Task 1 des Ernährungsplans), v12 '
              'die fünf Ernährungstabellen (Task 3), v13 die zwölf Spalten '
              'von `lebensmittel` (#285), v14 `barcode` und `herkunft` an '
              '`lebensmittel` (#284), v15 die Tabellen `ki_einstellungen` '
              'und `ki_anfragen` und `eintraege.vorschlag` (#332), v16 die '
              'Tabelle `wasser_eintraege` (#311), v17 die Spalten von '
              '`portionen`, den Portions-Schnappschuss in `eintraege` und '
              '`lebensmittel.portionen_abgefragt_am` (#393), v18 die drei '
              'Gym-Tabellen `gym_sitzungen`, `gym_saetze` und '
              '`gym_entwuerfe` (#78 mit #40), v19 die Tabelle '
              '`kalorienziele` (#410), v20 `eintraege.fluessig` (#403), '
              'v21 die Tabelle `mahlzeit_aufteilungen` (#430), v22 die '
              'Tabelle `ereignisse` (#444), v23 die Tabelle `wach_belege` '
              '(#451), v24 die Tabelle `umfaenge` (#476), v25 die '
              'Sync-Felder an `lebensmittel` und `rezepte` (#542), v26 '
              'die drei Zyklus-Tabellen `zyklus_eintraege`, '
              '`zyklus_health_spiegel` und `zyklus_einstellungen` (#592), '
              'v27 die vier Tabellen der eigenen Trainings samt '
              '`gym_rotation` und die Spalte '
              '`gym_sitzungen.trainings_name` (#532), v28 die Spalte '
              '`vo2max` an `tages_werte` (#95 mit #16). '
              'Diese Zeile zählt die Stufen mit; die '
              'Stufen selbst prüfen `schlaf_eintrag_test.dart`, '
              '`schema_v7_test.dart`, `schema_v8_test.dart`, '
              '`schema_v9_test.dart`, `schema_v10_test.dart`, '
              '`schema_v11_test.dart`, `schema_v12_test.dart`, '
              '`schema_v13_test.dart`, `schema_v14_test.dart`, '
              '`schema_v15_test.dart`, `schema_v16_test.dart`, '
              '`schema_v17_test.dart`, `schema_v18_test.dart`, '
              '`schema_v19_test.dart`, `schema_v20_test.dart`, '
              '`schema_v21_test.dart`, `schema_v22_test.dart`, '
              '`schema_v23_test.dart`, `schema_v24_test.dart`, '
              '`migration_v25_test.dart`, `schema_v26_test.dart`, '
              '`schema_v27_test.dart` und `schema_v28_test.dart`. Die '
              'Stufen-Tests vergleichen den abgelegten Stand seit #193 '
              'gegen `AppCache.schemaVersion` statt gegen eine eigene '
              'Zahl — sonst fiel bei jeder neuen Stufe auch ein Fall, der '
              'von einer alten handelt. Seit dem 04.11.2026 ist dies die '
              'einzige Stelle mit der absoluten Zahl: '
              '`schlaf_eintrag_test.dart` war die zweite und steht jetzt '
              'auf `greaterThanOrEqualTo(6)`, `schema_v11_test.dart` ist '
              'mit der Stufe 12 auf `greaterThanOrEqualTo(11)` gefolgt, '
              '`schema_v12_test.dart` mit der Stufe 13 auf '
              '`greaterThanOrEqualTo(12)`, `schema_v13_test.dart` mit der '
              'Stufe 14 auf `greaterThanOrEqualTo(13)` — alle vier handeln '
              'von ihrer Stufe und nicht von der heutigen Zahl (#208)',
        );
      },
    );
  });

  group(
    'Pflichtfall 2 (task-6-brief.md) / Review-Focus 5 — '
    'eine Migration verwirft keine Daten',
    () {
      test(
        'ein Cache der Vorversion (Schema v1) wird migriert, nicht '
        'verworfen — die Zeile bleibt mit ihren Werten erhalten',
        () async {
          final executor = NativeDatabase.memory(
            setup: (Database raw) {
              // Handgebautes Schema v1 — vor der v2-Spalte `gelesen_am`.
              // Siehe Dateikopf: der offizielle `drift_dev
              // schema dump`-Weg setzt eine bereits gebaute `tables.dart`
              // voraus, die es für diese Testdatei noch nicht geben darf.
              raw.execute('''
                CREATE TABLE tages_werte (
                  tag TEXT NOT NULL PRIMARY KEY,
                  schritte INTEGER,
                  ruhepuls_bpm INTEGER
                );
              ''');
              raw.execute(
                "INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm) "
                "VALUES ('2026-10-20', 8042, 51);",
              );
              // Ohne dieses Pragma meldet SQLite Version 0, und drift ruft
              // `onCreate` statt `onUpgrade` auf — der Migrationspfad bliebe
              // ungeprüft. Das simuliert einen Nutzer, dessen Cache bereits
              // unter Schema v1 lief.
              raw.execute('PRAGMA user_version = 1;');
            },
          );

          final db = AppCache(executor);
          addTearDown(db.close);

          final zeilen = await db.select(db.tagesWerte).get();
          expect(
            zeilen,
            hasLength(1),
            reason:
                'die Zeile aus Schema v1 darf nicht verschwinden — ein '
                'still verworfener Cache wäre Tims gemeldeter Schmerzpunkt '
                'neu gebaut',
          );

          final zeile = zeilen.single;
          expect(zeile.tag, '2026-10-20', reason: 'Werte, nicht nur Zeilenzahl');
          expect(zeile.schritte, 8042);
          expect(zeile.ruhepulsBpm, 51);
          expect(
            zeile.gelesenAm,
            isNull,
            reason:
                'die in v2 neu hinzugekommene Spalte existiert in den '
                'v1-Daten nicht — für diese Zeile ist schlicht unbekannt, '
                'wann sie geholt wurde, also null, nicht ein erfundener '
                'Zeitstempel. Eine Migration, die alte Zeilen mit einem '
                'ausgedachten "jetzt" füllte, würde behaupten, die Daten '
                'seien frisch, obwohl das niemand weiß',
          );
        },
      );
    },
  );

  group(
    'Pflichtfall 3 (task-6-brief.md) — der Tagesschlüssel ist ein '
    'ISO-String, kein Zeitstempel',
    () {
      test(
        "WHERE tag >= '2026-10-01' AND tag <= '2026-10-31' liefert genau "
        'die Oktobertage, auch über die Zeitumstellung am 25.10.2026 '
        'hinweg (Spec 5.6: lexikografischer Vergleich übersteht jede '
        'Umstellung, ein Zeitstempelvergleich nicht zwingend)',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          // Schlüssel kommen aus `BerlinCalendar.dayKey`, genau wie sie im
          // echten Cache entstünden — nicht von Hand als String getippt.
          final septemberTag = BerlinCalendar.dayKey(
            DateTime.utc(2026, 9, 30, 12),
          );
          final oktoberTage = List<String>.generate(
            31,
            (i) => BerlinCalendar.dayKey(DateTime.utc(2026, 10, i + 1, 12)),
          );
          final novemberTag = BerlinCalendar.dayKey(
            DateTime.utc(2026, 11, 1, 12),
          );

          for (final tag in [septemberTag, ...oktoberTage, novemberTag]) {
            await db.into(db.tagesWerte).insert(
              TagesWerteCompanion.insert(tag: tag),
            );
          }

          final treffer =
              await (db.select(db.tagesWerte)..where(
                    (t) =>
                        t.tag.isBiggerOrEqualValue('2026-10-01') &
                        t.tag.isSmallerOrEqualValue('2026-10-31'),
                  ))
                  .get();

          expect(
            treffer.map((z) => z.tag).toSet(),
            oktoberTage.toSet(),
            reason:
                'genau die 31 Oktobertage — weder der 30.09. noch der '
                '01.11. — unabhängig davon, dass die Uhr am 25.10. '
                'zwischen den gespeicherten Tagen umgestellt wird',
          );
          expect(treffer, hasLength(31));
        },
      );
    },
  );

  group('Reihenfolge — sortiert zurück, auch wenn unsortiert geschrieben', () {
    test(
      'Tage kommen beim Lesen aufsteigend sortiert, unabhängig von der '
      'Schreibreihenfolge',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        for (final tag in [
          '2026-10-15',
          '2026-10-01',
          '2026-10-31',
          '2026-10-03',
        ]) {
          await db.into(db.tagesWerte).insert(
            TagesWerteCompanion.insert(tag: tag),
          );
        }

        final ergebnis =
            await (db.select(db.tagesWerte)
                  ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
                .get();

        expect(ergebnis.map((z) => z.tag).toList(), [
          '2026-10-01',
          '2026-10-03',
          '2026-10-15',
          '2026-10-31',
        ]);
      },
    );
  });

  group('Schreiben und Wiederlesen desselben Tages', () {
    test(
      'ein zweiter Schreibvorgang auf denselben Tag überschreibt die Zeile '
      '— es entstehen keine zwei Zeilen',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await db.into(db.tagesWerte).insertOnConflictUpdate(
          const TagesWerteCompanion(
            tag: Value('2026-10-20'),
            schritte: Value(1000),
          ),
        );
        await db.into(db.tagesWerte).insertOnConflictUpdate(
          const TagesWerteCompanion(
            tag: Value('2026-10-20'),
            schritte: Value(9000),
          ),
        );

        final zeilen = await db.select(db.tagesWerte).get();
        expect(
          zeilen,
          hasLength(1),
          reason: 'derselbe Tag darf nur eine Zeile ergeben, keine zweite',
        );
        expect(
          zeilen.single.schritte,
          9000,
          reason: 'der zweite Schreibvorgang gewinnt',
        );
      },
    );
  });

  group('Ein Tag, der nicht existiert', () {
    test(
      'eine Abfrage nach einem nicht geschriebenen Tag liefert ein leeres '
      'Ergebnis, keinen Absturz',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await db.into(db.tagesWerte).insert(
          TagesWerteCompanion.insert(tag: '2026-10-20'),
        );

        final einzeln =
            await (db.select(
              db.tagesWerte,
            )..where((t) => t.tag.equals('2026-01-01'))).getSingleOrNull();
        expect(einzeln, isNull);

        final liste =
            await (db.select(
              db.tagesWerte,
            )..where((t) => t.tag.equals('2026-01-01'))).get();
        expect(liste, isEmpty);
      },
    );
  });

  group(
    'Jede Metrikspalte ist nullbar (task-6-brief.md, Global Constraint)',
    () {
      test(
        'ein nicht gelieferter Wert in TagesWerte bleibt null, kommt nicht '
        'als 0 zurück',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          await db.into(db.tagesWerte).insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              schritte: const Value(5000),
              // ruhepulsBpm und gelesenAm absichtlich nicht gesetzt.
            ),
          );

          final zeile =
              await (db.select(
                db.tagesWerte,
              )..where((t) => t.tag.equals('2026-10-20'))).getSingle();
          expect(zeile.schritte, 5000);
          expect(
            zeile.ruhepulsBpm,
            isNull,
            reason: 'kein Messwert ist nicht 0 bpm',
          );
          expect(
            zeile.gelesenAm,
            isNull,
            reason:
                'kein mitgeschriebener Zeitpunkt ist nicht irgendein '
                'Datum, sondern "unbekannt, wann geholt"',
          );
        },
      );

      test(
        'dasselbe gilt für StundenSchritte — eine Stunde ohne Wert bleibt '
        'null, nicht 0 Schritte',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          await db.into(db.stundenSchritte).insert(
            StundenSchritteCompanion.insert(tag: '2026-10-20', stunde: 7),
          );

          final zeile =
              await (db.select(db.stundenSchritte)..where(
                    (t) => t.tag.equals('2026-10-20') & t.stunde.equals(7),
                  ))
                  .getSingle();
          expect(zeile.schritte, isNull);
        },
      );
    },
  );

  group(
    'TagesWerte.gelesenAm — der Zeilenstand aus Spec 5.3b, je Zeile statt '
    'global (Task-13-Vorbedingung, Begründung der v2-Entscheidung oben)',
    () {
      test(
        'eine Zeile kann gelesenAm tragen und bekommt genau diesen '
        'Zeitpunkt zurück — nicht nur null ist ein gültiger Zustand',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          // Keine Millisekunden/Mikrosekunden: drift darf DateTime-Spalten
          // je nach Fassung als Unix-Sekunden oder als Text speichern: ein
          // Wert mit Sub-Sekunden-Anteil wäre für diesen Test ein falscher
          // Streitpunkt über Rundung, nicht über das, was geprüft werden
          // soll.
          final geholt = DateTime.utc(2026, 10, 20, 14, 32);

          await db.into(db.tagesWerte).insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              schritte: const Value(8000),
              gelesenAm: Value(geholt),
            ),
          );

          final zeile =
              await (db.select(
                db.tagesWerte,
              )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

          expect(
            zeile.gelesenAm,
            geholt,
            reason:
                'Spec 5.3b: "stand" ist je Messwert-Instanz verschieden — '
                'ein Provider (Task 13) braucht genau diesen Zeitpunkt je '
                'Zeile, nicht einen globalen Cache-Zeitstempel',
          );
        },
      );
    },
  );

  group(
    'Spec 5.6a — zwei Tabellengruppen in einer Datenbank, '
    'Messwert gilt nur für die erste',
    () {
      test(
        'TagesWerte (Cache-Gruppe) und EigeneDaten (eigene Daten) '
        'existieren unabhängig nebeneinander',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          await db.into(db.tagesWerte).insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              schritte: const Value(4000),
            ),
          );
          await db.into(db.eigeneDaten).insert(
            EigeneDatenCompanion.insert(
              tag: '2026-10-20',
              inhalt: 'Rückentag, Kreuzheben 4x10',
            ),
          );

          final cacheZeile =
              await (db.select(
                db.tagesWerte,
              )..where((t) => t.tag.equals('2026-10-20'))).getSingle();
          final eigeneZeile =
              await (db.select(
                db.eigeneDaten,
              )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

          expect(cacheZeile.schritte, 4000);
          expect(eigeneZeile.inhalt, 'Rückentag, Kreuzheben 4x10');
        },
      );

      test(
        'ein Tag ohne eigenen Eintrag ist in EigeneDaten schlicht leer — '
        'kein Messwert-Zustand, keine Platzhalterzeile (Spec 5.6a: '
        '"leer heißt dort leer")',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);

          final treffer =
              await (db.select(
                db.eigeneDaten,
              )..where((t) => t.tag.equals('2026-10-20'))).get();
          expect(
            treffer,
            isEmpty,
            reason:
                'Messwert<T> gilt laut Spec 5.6a nicht für eigene Daten — '
                'eine leere Liste ist hier die ganze Aussage, nicht '
                'NochNie oder LeerNachLauf',
          );
        },
      );
    },
  );
}
