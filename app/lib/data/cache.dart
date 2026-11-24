// Der drift-Cache auf der Platte (Task 6). Siehe `docs/superpowers/specs/
// 2026-10-23-flutter-rebuild-design.md`, Abschnitte 5.5, 5.6, 5.6a, und
// `app/test/data/migration_test.dart`, das Tabellen-, Spalten- und
// Methodennamen sowie `schemaVersion == 11` verbindlich vorgibt (siehe
// Dateikopf dort und dessen Nachtrag vom 27.10.2026 zur Begründung der
// Versionsnummern). Die Stufen v3 bis v5 prüft zusätzlich
// `app/test/data/schema_v3_test.dart`, die Stufe v6
// `app/test/data/schlaf_eintrag_test.dart`, die Stufe v7
// `app/test/data/schema_v7_test.dart`, die Stufe v8
// `app/test/data/schema_v8_test.dart`, die Stufe v9
// `app/test/data/schema_v9_test.dart`, die Stufe v10
// `app/test/data/schema_v10_test.dart`, die Stufe v11
// `app/test/data/schema_v11_test.dart`, die Stufe v12
// `app/test/data/schema_v12_test.dart`, die Stufe v13
// `app/test/data/schema_v13_test.dart`, die Stufe v14
// `app/test/data/schema_v14_test.dart`, die Stufe v15
// `app/test/data/schema_v15_test.dart`, die Stufe v16
// `app/test/data/schema_v16_test.dart`, die Stufe v17
// `app/test/data/schema_v17_test.dart`, die Stufe v18
// `app/test/data/schema_v18_test.dart`, die Stufe v19
// `app/test/data/schema_v19_test.dart`, die Stufe v20
// `app/test/data/schema_v20_test.dart`, die Stufe v21
// `app/test/data/schema_v21_test.dart`, die Stufe v22
// `app/test/data/schema_v22_test.dart`, die Stufe v23
// `app/test/data/schema_v23_test.dart`, die Stufe v24
// `app/test/data/schema_v24_test.dart`, die Stufe v25
// `app/test/data/migration_v25_test.dart`, die Stufe v26
// `app/test/data/schema_v26_test.dart`, die Stufe v27
// `app/test/data/schema_v27_test.dart` und die Stufe v28
// `app/test/data/schema_v28_test.dart`.
//
// ## `gym_sitzungen.workout` heißt jetzt Kennung (v27, #532)
//
// Die Spalte `gym_sitzungen.workout` (und `gym_entwuerfe.workout`) trägt ab
// Stufe 27 **die Kennung des Trainings**: für ein Training mit Enum-Fall wie
// bisher den `Workout.code`, für ein eigenes Training seine UUID. **Der Name
// der Spalte ist damit ungenau und bleibt** — `UNIQUE (tag, workout)` steht in
// `CREATE TABLE`, und ein Neubau der Tabelle ist das Risiko, das Tims einzige
// Kopie seiner Trainings nicht eingehen darf (Spec 4.6, `gym_tabellen.dart`).
//
// ## Warum es neben den Stufen einen Abgleich beim Öffnen gibt (#233)
//
// Auf Tims iPhone stand `Library/Application Support/cache.sqlite` am
// 02./03.11.2026 auf `PRAGMA user_version = 7` und hatte die beiden Spalten
// der Stufe 7 (`koerperfett_pct`, `fettfrei_kg`) **nicht**. Jeder
// Schreibversuch scheiterte mit `SqliteException(1): table tages_werte has
// no column named koerperfett_pct`; weil ein gescheiterter Nachlauf den
// zwischengespeicherten Stand stehen lässt (`CLAUDE.md`, und das ist
// richtig), sah der Schirm aus wie „keine neuen Daten" statt wie ein
// Fehler — er verdeckte also seinen eigenen.
//
// Ursache ist die Nummer: `onUpgrade` prüft `if (from < 7)`, und steht die
// Datei schon auf 7, läuft die Stufe nie, auch wenn ihre Spalten fehlen.
// Auf 7 gehoben hat sie ein **anderer Zweig** — alle Zweige bauen unter
// derselben Bundle-ID und benutzen dieselbe Datei. Bei mehreren parallelen
// Arbeitssträngen ist das kein Ausnahmefall, sondern trifft jeden künftigen
// Zweigwechsel wieder.
//
// Der Abgleich (`_reconcileSchema`) läuft deshalb **zusätzlich** zu den
// Stufen, beim Öffnen und auch dann, wenn `onUpgrade` gar nicht lief. Seine
// Grenzen und der Maßstab „im Normalfall wird nichts angefasst" stehen in
// `app/test/data/schema_abgleich_test.dart`.
//
// ## Und warum die Stufen selbst nachsehen, bevor sie eine Spalte anhängen
// (#234)
//
// Derselbe Zweigwechsel geht auch andersherum: Nummer zu niedrig, Spalten
// schon da. Dann läuft die Stufe und stirbt an `duplicate column name` —
// beim Öffnen, also ist die Datenbank danach gar nicht mehr zu benutzen.
// Der Abgleich kann das nicht auffangen: Er hängt an `beforeOpen` und kommt
// nie an die Reihe, weil `onUpgrade` vorher wirft. Robust werden müssen
// deshalb die Stufen; das tut `_addColumnIfMissing`, und zwar mit derselben
// Prüfung, die auch der Abgleich benutzt. Geprüft in
// `app/test/data/schema_fremde_spalten_test.dart`. (Der Zweig, aus dem
// diese Prüfung stammt, trug sie als `schema_stufen_robust_test.dart` —
// dieselbe Anforderung, gegen seine eigene Stufennummerierung
// geschrieben. Beim Zusammenführen am 03.11.2026 ist die Datei oben
// geblieben und das Duplikat entfallen.)
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'aufteilung_tabelle.dart';
import 'ereignis_tabelle.dart';
import 'ernaehrung_tabellen.dart';
import 'gym_training_repository.dart';
import 'gym_training_tabellen.dart';
import 'gym_tabellen.dart';
import 'kalorienziel_tabelle.dart';
import 'ki_tabellen.dart';
import 'tables.dart';
import 'wach_beleg_tabelle.dart';
import 'wasser_tabellen.dart';
import 'zyklus_tabelle.dart';

part 'cache.g.dart';

/// Die Cache-Datenbank: Tageswerte, Stundenwerte und Nächte aus Apple
/// Health (Spec 5.5/5.6), dazu Tims eigene Daten — `EigeneDaten` als
/// Platzhalter-Repräsentant der zweiten Tabellengruppe aus Spec 5.6a,
/// `ZielWerte` (#111), `SchlafEintraege` (#131), `Stammdaten` und die
/// fünf Ernährungstabellen aus `ernaehrung_tabellen.dart` und die beiden
/// KI-Tabellen aus `ki_tabellen.dart`, `WasserEintraege` und
/// `Kalorienziele` (#410), `MahlzeitAufteilungen` (#374), `Ereignisse`
/// (#404), `WachBelege` (#375), `Umfaenge` (#476) und die vier Tabellen der
/// eigenen Trainings (#532, `gym_training_tabellen.dart`) als die echten
/// Tabellen dieser Gruppe.
@DriftDatabase(
  tables: [
    TagesWerte,
    StundenSchritte,
    EigeneDaten,
    Naechte,
    SchlafAbschnitte,
    ZielWerte,
    SchlafEintraege,
    Stammdaten,
    Lebensmittel,
    Portionen,
    Eintraege,
    Rezepte,
    RezeptZutaten,
    KiEinstellungen,
    KiAnfragen,
    WasserEintraege,
    GymSitzungen,
    GymSaetze,
    GymEntwuerfe,
    Kalorienziele,
    MahlzeitAufteilungen,
    Ereignisse,
    WachBelege,
    Umfaenge,
    ZyklusEintraege,
    ZyklusHealthSpiegel,
    ZyklusEinstellungen,
    GymTrainings,
    GymTrainingUebungen,
    GymTrainingTags,
    GymRotation,
  ],
)
class AppCache extends _$AppCache {
  AppCache(super.executor);

  /// Öffnet den Cache in `getApplicationSupportDirectory()` — **nicht**
  /// `Documents` (bei aktiviertem File Sharing nutzersichtbar), **nicht**
  /// `Caches` (iOS darf das unter Speicherdruck löschen, dann ist der Cache
  /// beim Kaltstart weg: genau der gemeldete Fehler aus #55). `drift_flutter`
  /// legt die Verbindung auf einem eigenen Isolate an.
  factory AppCache.oeffnen() {
    return AppCache(
      driftDatabase(
        name: 'cache',
        native: DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    );
  }

  /// Einundzwanzig Versionen über v1 hinaus, jede mit genau einem Ticket
  /// dahinter:
  ///
  /// - **v2**: `TagesWerte.gelesenAm` (siehe `migration_test.dart`,
  ///   Dateikopf, zur Begründung dieser zweiten Version und warum sie keine
  ///   erfundene Zahl ist).
  /// - **v3** (#113): die drei Erholungs-Spalten in `TagesWerte` und die
  ///   beiden Schlaf-Tabellen.
  /// - **v4** (#111): die Ziele.
  /// - **v5** (#118): das Tagesgefühl. **Die Tabelle gibt es seit v10
  ///   nicht mehr** (#269) — diese Stufe legt sie trotzdem weiter an,
  ///   siehe unten.
  /// - **v6** (#131): die von Hand eingetragenen Schlafphasen.
  /// - **v7** (#194): `gewichtKg` und `trainingsMinuten` in `TagesWerte` —
  ///   beide kamen aus dem Cache bis dahin immer `null` zurück, weil es
  ///   keine Spalte für sie gab.
  /// - **v8** (#193): `ruhepulsBpm`, `hrvMs` und `respRate` in `Naechte` —
  ///   die drei Werte **einer Nacht**, gerechnet über das Schlaffenster
  ///   statt über den Kalendertag. Additiv wie jede Stufe und **ohne
  ///   Rückschreiben**: Eine migrierte Nacht bekommt keinen Wert, und die
  ///   Versuchung, hier den gleichnamigen Tageswert aus `tages_werte`
  ///   herüberzuschreiben, wäre genau der falsche Wert, dessentwegen es
  ///   #193 gibt.
  ///
  /// **Warum #194 die v7 bekam und nicht die v6**, obwohl beide Zweige
  /// unabhängig voneinander auf 6 gingen (entschieden beim Zusammenführen
  /// am 02.11.2026, nicht von Tim): Eine Versionsnummer sagt nicht, welches
  /// Ticket zuerst fertig war, sondern **was ein Gerät schon ausgeführt
  /// hat**. Auf dem Gerät steht `user_version = 6` für „`schlaf_eintraege`
  /// ist angelegt" — die Tabelle gibt es dort, mit von Hand eingetragenen
  /// Nächten darin.
  ///
  /// Bekäme #131 die 7 und #194 die 6, liefe auf diesem Gerät die Stufe
  /// `from < 6` **nie** — es steht ja schon auf 6 —, und die beiden Spalten
  /// kämen dort nie an. Die Datei spränge trotzdem auf 7, und damit wäre
  /// der Zustand endgültig: Gewicht und Trainingsminuten blieben für immer
  /// `null`, also genau der Fehler, den #194 behebt, nur dauerhaft. Es
  /// knallte dabei nicht einmal — `Migrator.createTable` schreibt
  /// `CREATE TABLE IF NOT EXISTS` (drift 2.35.2,
  /// `query_builder/migration.dart:319`), die doppelte Stufe liefe also
  /// stumm durch. Ein stiller Verlust ist hier das schlechtere Ende als ein
  /// lauter.
  ///
  /// So herum läuft auf diesem Gerät genau die eine Stufe, die es noch
  /// nicht kennt — die beiden Spalten, additiv, ohne die Einträge
  /// anzufassen.
  ///
  /// - **v9** (#202): `koerperfettPct` und `fettfreiKg` in `TagesWerte` —
  ///   dieselbe Lücke wie bei v7, zwei Felder weiter: Körperfett und
  ///   fettfreie Masse liegen seit Task 12 vollständig im Kanal, hatten
  ///   aber keine Spalte und kamen aus dem Cache immer `null` zurück.
  ///
  /// **Warum #202 die v9 bekam und nicht die v7**, die es im eigenen Zweig
  /// trug (entschieden beim Zusammenführen am 03.11.2026, nicht von Tim):
  /// Genau dieselbe Überlegung wie eine Absatzlänge weiter oben, nur ein
  /// Zweig später. `koerper-datenkette` zweigte ab, bevor #194 und #193 auf
  /// `main` lagen, und zählte seine Stufe 7 unabhängig weiter — dieselbe
  /// Nummer, zwei Bedeutungen (#235). Auf Tims Gerät stand die Datei
  /// zwischenzeitlich auf 7 **ohne** die beiden Körperspalten; genau dieser
  /// Zustand ist der Anlass für #233. Behielte #202 die 7, liefe seine
  /// Stufe auf jedem Gerät, das schon auf 8 steht, nie, und die beiden
  /// Spalten kämen dort nie an. Die nächste freie Nummer ist die einzige,
  /// die das nicht tut.
  ///
  /// - **v10** (#269): `tagesgefuehle` wird **gelöscht**. Tim hat das
  ///   Tagesgefühl am 03.11.2026 abbestellt („lass das weg und bau das
  ///   aus — auch aus dem Design") und das Mitlöschen der Tabelle
  ///   ausdrücklich entschieden; dass seine bisherigen Einträge damit
  ///   endgültig weg sind, stand in der Frage, und auf dem iPhone liegt
  ///   die einzige Kopie. Die erste Stufe, die etwas **wegnimmt**.
  ///
  /// **Warum die v5-Stufe trotzdem stehenbleibt**, obwohl sie eine
  /// Tabelle anlegt, die am Ende wieder verschwindet: Die Stufen bilden
  /// den Weg ab, den ein Gerät genommen hat, nicht den Endzustand. Ein
  /// Gerät auf v4 läuft durch v5 und erst danach durch v10 — ohne die
  /// v5-Stufe fehlte zwischendrin eine Tabelle, die der Rest des
  /// Durchlaufs vorfinden können muss. Dass `deleteTable` ein
  /// `DROP TABLE IF EXISTS` absetzt (drift 2.35.2,
  /// `query_builder/migration.dart:465`), macht die umgekehrte Richtung
  /// harmlos: Eine Datei, die die Tabelle nie hatte, stolpert nicht
  /// darüber.
  ///
  /// **Und `tagesgefuehle` verschwindet aus dem Schema, nicht nur aus der
  /// Datei.** Bliebe die Tabelle in `@DriftDatabase` stehen, zöge
  /// [_reconcileSchema] sie bei jedem Öffnen wieder nach — er legt an,
  /// was die Datei gegenüber dem heutigen Schema vermissen lässt. Die
  /// Löschung wäre dann wirkungslos, und zwar lautlos. Geprüft in
  /// `test/data/schema_v10_test.dart` an einem zweiten Öffnen derselben
  /// Datei.
  ///
  /// - **v11** (Ernährungsplan Task 1): die Tabelle `stammdaten` —
  ///   Körpergröße, Geburtsjahr, Zielgewicht und Zieldatum. Ohne diese
  ///   vier Angaben gibt es kein Kalorienziel, und sie kommen nicht aus
  ///   Apple Health, sondern von Tim. Die Stufe legt die Tabelle an und
  ///   **keine Zeile**: Eine vorab eingefügte Zeile behauptete, Tim habe
  ///   etwas eingetragen, und jeder Vorgabewert wäre eine erfundene
  ///   Angabe über ihn.
  ///
  /// **Warum die 11 und nicht eine Nummer, die der Zweig für sich
  /// zählt:** Dieselbe Überlegung wie bei #194 und #202 oben. Die Nummer
  /// wurde am 04.11.2026 aus dieser Datei **gelesen** und um eins erhöht
  /// (#235) — sie sagt nicht, welches Ticket zuerst fertig war, sondern
  /// was ein Gerät schon ausgeführt hat.
  ///
  /// - **v12** (Ernährungsplan Task 3): die fünf Ernährungstabellen —
  ///   `lebensmittel` und `portionen` als Vorlage, `eintraege` als
  ///   Tatsache, `rezepte` und `rezept_zutaten` für das Gekochte. Am
  ///   03.11.2026 hat Tim die Richtung umgedreht: Die eigene Tabelle ist
  ///   die Wahrheit, Apple Health bekommt eine Kopie — damit braucht der
  ///   Ernährungsschirm einen eigenen Speicher. **Spaltengenau
  ///   festgelegt ist nur `eintraege`**; die übrigen vier kommen mit
  ///   ihrem Schlüssel und bekommen ihre Spalten von den Aufgaben, die
  ///   sie brauchen (Task 6 und Task 8).
  ///
  ///   Additiv und **ohne eine einzige Zeile**: Eine vorab eingefügte
  ///   Zeile behauptete, Tim habe etwas gegessen, und ein nachgelegter
  ///   Zeitstempel behauptete, wann.
  ///
  /// **Warum die 12:** Dieselbe Überlegung wie bei #194, #202 und #235.
  /// Die Nummer wurde am 04.11.2026 aus dieser Datei **gelesen** und um
  /// eins erhöht — sie sagt nicht, welches Ticket zuerst fertig war,
  /// sondern was ein Gerät schon ausgeführt hat.
  ///
  /// **Je eine Stufe, keine Sammelversion** (Begründung im Dateikopf von
  /// `test/data/schema_v3_test.dart`): Ein Gerät, das zwischen zwei dieser
  /// Tickets aktualisiert wurde, muss den Rest nachholen können. Mit einer
  /// einzigen Sammelversion gäbe es Geräte mit „v3, aber schon mit
  /// Zieltabelle", und die wären von außen nicht mehr unterscheidbar.
  /// - **v13** (#285): `lebensmittel` bekommt ihre Spalten — `name`, die
  ///   acht Nährwerte je 100 g, `extra`, `fluessig` und
  ///   `zuletzt_benutzt`. Die Tabelle steht seit v12, trug aber nur ihren
  ///   Schlüssel; der vollständige Eintragweg ohne Barcode und ohne Open
  ///   Food Facts braucht die Vorlagenhälfte, und damit braucht sie
  ///   Inhalt.
  ///
  ///   **Additiv:** Die Stufe hängt Spalten an, baut die Tabelle nicht
  ///   neu, legt **keine Zeile** an und füllt **kein Feld**. `name`
  ///   bekommt den Vorgabewert `''`, weil SQLite `ADD COLUMN … NOT NULL`
  ///   ohne ihn ablehnt; `zuletzt_benutzt` bekommt **keinen** — ein
  ///   Vorgabewert wäre dort ein erfundener Zeitpunkt und behauptete,
  ///   Tim habe etwas gegessen, und sagte auch noch wann.
  ///
  /// **Warum die 13:** Dieselbe Überlegung wie bei #194, #202, #235 und
  /// v12. Die Nummer wurde am 04.11.2026 aus dieser Datei **gelesen** und
  /// um eins erhöht — sie sagt nicht, welches Ticket zuerst fertig war,
  /// sondern was ein Gerät schon ausgeführt hat.
  ///
  /// - **v14** (#284): `lebensmittel` bekommt `barcode` (nullbar) und
  ///   `herkunft` (`TEXT NOT NULL DEFAULT 'eigen'`). Ein Treffer aus Open
  ///   Food Facts wird beim Buchen mit Herkunft `off` übernommen, und ein
  ///   zweites Buchen desselben Produkts darf kein zweites anlegen — dafür
  ///   muss die Tabelle den Strichcode kennen.
  ///
  ///   **Additiv:** Alte Zeilen behalten jeden Wert und stehen danach auf
  ///   `herkunft = 'eigen'`, `barcode = NULL`. `eigen` ist dabei nicht
  ///   erfunden, sondern die einzige Möglichkeit — vor v14 gab es keinen
  ///   Weg aus Open Food Facts in die Tabelle.
  ///
  /// **Warum die 14:** Dieselbe Überlegung wie bei den Stufen davor. Die
  /// Nummer wurde am 04.11.2026 aus dieser Datei **gelesen** und um eins
  /// erhöht.
  ///
  /// - **v15** (#332, KI-Zugang): die Tabellen `ki_einstellungen` und
  ///   `ki_anfragen` (`ki_tabellen.dart`) und die Spalte
  ///   `eintraege.vorschlag` — die Herkunft eines gebuchten
  ///   KI-Vorschlags.
  ///
  ///   **Additiv und ohne eine einzige Zeile:** Eine vorab eingefügte
  ///   Einstellungszeile behauptete eine Einstellung, die niemand getroffen
  ///   hat (dieselbe Regel wie bei `stammdaten`), eine Anfragezeile einen
  ///   Verbrauch, den es nie gab. Alte Einträge behalten jeden Wert und
  ///   bekommen `vorschlag = NULL` — eine Migration erfindet keine
  ///   Herkunft.
  ///
  /// **Warum die 15:** Dieselbe Überlegung wie bei den Stufen davor. Die
  /// Nummer wurde am 04.11.2026 aus dieser Datei **gelesen** und um eins
  /// erhöht.
  ///
  /// - **v16** (#311): die Tabelle `wasser_eintraege`
  ///   (`wasser_tabellen.dart`) — eingetragene Gläser Wasser, getrennt von
  ///   den Mahlzeiten.
  ///
  ///   **Additiv und ohne eine einzige Zeile:** Auch nicht aus
  ///   `eintraege.wasser_ml` — das ist Wasser in einem Lebensmittel, kein
  ///   eingetragenes Glas, und eine Migration erfindet keine Einträge.
  ///
  /// **Warum die 16:** Dieselbe Überlegung wie bei den Stufen davor. Die
  /// Nummer wurde am 05.11.2026 aus dieser Datei **gelesen** und um eins
  /// erhöht.
  ///
  /// - **v17** (#325, #393): `portionen` bekommt ihre Spalten
  ///   (`lebensmittel_id`, `name`, `menge_g`, `herkunft`), `eintraege` den
  ///   Schnappschuss der gebuchten Portion (`portion_id`, `portion_name`,
  ///   `portion_g`) und `lebensmittel` die Marke `portionen_abgefragt_am`.
  ///
  ///   **Additiv:** Die Stufe legt keine Portion an, auch nicht aus alten
  ///   Einträgen, setzt kein `portionen_abgefragt_am` und setzt
  ///   `fluessig` nicht neu. Alte Einträge tragen danach in allen drei
  ///   Schnappschuss-Spalten `NULL` — sie sind alle in Gramm gebucht, und
  ///   eine Migration erfindet nichts. Kein Index, weil
  ///   [_reconcileSchema] keine Indizes kennt.
  ///
  /// **Warum die 17:** Dieselbe Überlegung wie bei den Stufen davor. Die
  /// Nummer wurde am 05.11.2026 aus dieser Datei **gelesen** und um eins
  /// erhöht.
  ///
  /// - **v18** (#78, mit #40 und #418): die drei Gym-Tabellen
  ///   (`gym_tabellen.dart`) — `gym_sitzungen` samt dem Aufwärmen in
  ///   eigenen Spalten, `gym_saetze` mit der nullbaren Satz-Uhrzeit und
  ///   `gym_entwuerfe` für den Zwischenstand eines laufenden Trainings.
  ///
  ///   **Additiv und ohne eine einzige Zeile.** Es gibt keine Gym-Daten
  ///   vor dieser Stufe; was Tim bisher trainiert hat, liegt in der alten
  ///   Swift-App und kommt mit der Übernahme (#59), nicht aus einer
  ///   Migration. Auch nicht aus `eigene_daten` — dort steht nichts
  ///   dergleichen, und eine Stufe, die eine Zeile erfände, erfände auch
  ///   ihren Zeitstempel.
  ///
  ///   Kein eigener Index: Die Eindeutigkeit über `(tag, workout)` steht
  ///   als `UNIQUE` im Tabellenkopf und wandert damit auf beiden Wegen mit
  ///   der Tabelle — über die Stufe wie über [_reconcileSchema], der
  ///   Indizes nicht kennt.
  ///
  /// **Warum die 18:** Dieselbe Überlegung wie bei den Stufen davor. Die
  /// Nummer wurde am 10.11.2026 aus dieser Datei **gelesen** und um eins
  /// erhöht. Der Zweig `umfaenge-88` hat am selben Tag unabhängig
  /// dieselbe 18 für `kalorienziele` vergeben; beim Zusammenführen am
  /// 11.11.2026 ist sie **hier** geblieben, weil diese Stufe auf Tims
  /// iPhone schon gelaufen und in der Datei vermerkt ist. Verschöbe man
  /// sie, liefe sie dort nie wieder, und `gym_sitzungen` — seine einzige
  /// Kopie der Trainings — hinge allein am Abgleich beim Öffnen (#485).
  ///
  /// - **v19** (#410): die Tabelle `kalorienziele`
  ///   (`kalorienziel_tabelle.dart`) — die Historie des festen
  ///   Kalorienziels, je Tag höchstens eine Festlegung.
  ///
  ///   **Additiv und ohne eine einzige Zeile**, auch wenn Stammdaten und
  ///   Gewicht ein Ziel berechenbar machten: Das erste Ziel legt die App
  ///   fest, an dem Tag, an dem sie es rechnet. Eine Migration kennt weder
  ///   das Gewicht aus Apple Health noch den heutigen Tag, und eine Zeile
  ///   „ab dem Tag der Migration" erfände einen Zeitpunkt.
  ///
  /// **Warum die 19:** Ursprünglich die 18 auf `umfaenge-88` — die Nummer
  /// wurde am 10.11.2026 aus dieser Datei und den offenen Zweigen
  /// **gelesen** (alle auf 17) und um eins erhöht. Dieselbe 18 hatte #78
  /// unabhängig für die Gym-Tabellen belegt und auf Tims iPhone bereits
  /// ausgeführt; beim Zusammenführen am 11.11.2026 blieb die Gym-Stufe
  /// die 18, und diese Stufe und alle darüber sind um eins nach oben
  /// gerückt (#485, siehe v18).
  ///
  /// - **v20** (#403): `eintraege.fluessig`, der Schnappschuss „in
  ///   Millilitern gebucht" am Eintrag — nullbar, ohne Vorgabewert.
  ///
  ///   **Additiv, ohne Rückschreiben:** Alte Einträge tragen danach
  ///   `NULL`, auch die, deren Vorlage flüssig ist. Was die Vorlage heute
  ///   sagt, ist nicht, was beim Buchen galt, und eine Migration erfindet
  ///   keinen Schnappschuss; die Anzeige fällt bei `NULL` auf die Vorlage
  ///   zurück. Kein Index, weil [_reconcileSchema] keine Indizes kennt.
  ///
  /// **Warum die 20:** Ursprünglich die 19. Die Stufe entstand parallel
  /// zur damaligen 18 auf einem eigenen Zweig (`getraenke-ml`) und nahm
  /// die übernächste Nummer, damit beide Zweige nicht dieselbe Stufe 18
  /// belegen (Kopf von `schema_v20_test.dart`); beim Zusammenführen am
  /// 11.11.2026 um eins nach oben gerückt (#485, siehe v18).
  ///
  /// - **v21** (#374, #430): die Tabelle `mahlzeit_aufteilungen`
  ///   (`aufteilung_tabelle.dart`) — die Historie der Aufteilung des
  ///   Tagesziels auf Frühstück, Mittag und Abend, je Tag höchstens eine.
  ///   Der Snack ist der Rest und hat keine Spalte.
  ///
  ///   **Additiv und ohne eine einzige Zeile**, auch nicht der Startwert
  ///   25 · 35 · 30 · 10: Der gilt erst, wenn Tim einmal sichert
  ///   (Entscheidung 1 der Spec). Kein Index, weil [_reconcileSchema]
  ///   keine Indizes kennt.
  ///
  /// **Warum die 21:** Ursprünglich die 20. Die Nummer wurde am
  /// 10.11.2026 aus dieser Datei in `main` **gelesen** (19) und um eins
  /// erhöht; die damalige 21 und 22 waren von parallel geplanten Stufen
  /// belegt (Kopf von `schema_v21_test.dart`). Beim Zusammenführen am
  /// 11.11.2026 um eins nach oben gerückt (#485, siehe v18).
  ///
  /// - **v22** (#404, #444): die Tabelle `ereignisse`
  ///   (`ereignis_tabelle.dart`) — die Auszeiten (OP, Krankheit,
  ///   Verletzung, Urlaub), mit #389 auch der Spieltag.
  ///
  ///   **Additiv und ohne eine einzige Zeile**, auch keine OP „aus der
  ///   alten App": Kein Datum eines Ereignisses steht im Quelltext
  ///   (`CLAUDE.md`). Kein Index, weil [_reconcileSchema] keine Indizes
  ///   kennt.
  ///
  /// **Warum die 22:** Ursprünglich die 21. Die Nummer wurde getrennt
  /// vergeben neben #374 (damals 20) und #375 (damals 22), damit keine
  /// Nummer zwei Bedeutungen bekommt (Spec
  /// `2026-11-10-auszeit-design.md`, „Schemastufe: 21"). Beim Bau am
  /// 10.11.2026 aus dieser Datei in `main` **gelesen**: 20, also frei;
  /// beim Zusammenführen am 11.11.2026 um eins nach oben gerückt (#485,
  /// siehe v18).
  ///
  /// - **v23** (#375, #451): die Tabelle `wach_belege`
  ///   (`wach_beleg_tabelle.dart`) — die Belege für die Tagesgrenze: wann
  ///   Tim die App geöffnet oder etwas gebucht hat. Die Tabelle wird nie
  ///   geleert.
  ///
  ///   **Additiv und ohne eine einzige Zeile**, auch kein Beleg „jetzt":
  ///   Ein Beleg mit dem Zeitpunkt der Migration behauptete, Tim sei in
  ///   diesem Moment wach gewesen. Kein Index, weil [_reconcileSchema]
  ///   keine Indizes kennt.
  ///
  /// **Warum die 23:** Ursprünglich die 22. Die Nummer wurde getrennt
  /// vergeben neben #374 (damals 20) und #404 (damals 21), damit keine
  /// Nummer zwei Bedeutungen bekommt (Spec
  /// `2026-11-10-tagesgrenze-design.md`, „Schemastufe: 22"). Beim Bau am
  /// 10.11.2026 aus dieser Datei in `main` **gelesen**: 21, also frei;
  /// beim Zusammenführen am 11.11.2026 um eins nach oben gerückt (#485,
  /// siehe v18).
  ///
  /// - **v24** (#476, unter #88): die Tabelle `umfaenge` (`tables.dart`) —
  ///   Tims Maßband-Messungen, **eine Zeile je Tag und Maß**. Kein
  ///   Textklumpen je Tag: Der bräuchte einen eigenen Codec mit eigenen
  ///   Tests, wäre mit keiner Abfrage erreichbar und bei der nächsten
  ///   Schemaänderung nur zu verwerfen — dieselbe Überlegung wie bei
  ///   `naechte` und `schlaf_abschnitte`.
  ///
  ///   **Die Quelle steht im Schlüssel** (`tag`, `mass`, `quelle`). Ohne
  ///   sie überschriebe der Import beim nächsten Lauf den getippten Wert;
  ///   das Zusammenführen passiert beim **Lesen**, nicht beim Schreiben,
  ///   und dafür müssen der getippte und der importierte Wert
  ///   nebeneinander liegen bleiben. `tag` steht vorn, weil der Index
  ///   hinter dem Primärschlüssel eine Bereichsabfrage nur über seine
  ///   erste Spalte trägt und nach Zeitraum gefiltert wird, nie nach Maß
  ///   allein.
  ///
  ///   **Additiv und ohne eine einzige Zeile.** Vor dieser Stufe lagen
  ///   Tims Umfänge nicht in dieser Datenbank, es gibt also nichts
  ///   umzuschreiben; eine Zeile mit dem Zeitpunkt der Migration
  ///   behauptete eine Messung, die niemand gemacht hat. Die erste Zeile
  ///   schreibt der Eintragen-Schirm oder die Übernahme, nicht das Schema.
  ///   Kein Index, weil [_reconcileSchema] keine Indizes kennt.
  ///
  /// **Warum die 24:** Ursprünglich die 23. Die Nummer wurde am
  /// 11.11.2026 aus dieser Datei in `main` **gelesen** (22) und um eins
  /// erhöht — sie sagt nicht, welches Ticket zuerst fertig war, sondern
  /// was ein Gerät schon ausgeführt hat. Beim Zusammenführen am
  /// 11.11.2026 um eins nach oben gerückt (#485, siehe v18).
  ///
  /// - **v25** (#542, unter #275): die Sync-Felder an `lebensmittel` und
  ///   `rezepte` — UUID, Änderungszeitpunkt, Löschmarker, Autor, an
  ///   `lebensmittel` zusätzlich der Quellschlüssel (BLS-Code oder EAN).
  ///   Alle nullbar und ohne Vorgabewert: Keine Bestandszeile soll eine
  ///   Herkunft, einen Autor oder eine frische Änderung behaupten, die es
  ///   nie gab.
  ///
  /// - **v26** (#592 unter #539): die drei Tabellen des Zykluskalenders
  ///   (`zyklus_tabelle.dart`) — `zyklus_eintraege` mit einem Tageseintrag
  ///   je Kalendertag, `zyklus_health_spiegel` mit je einer Zeile pro
  ///   geschriebenem HealthKit-Sample und `zyklus_einstellungen` als die
  ///   eine Einstellungszeile.
  ///
  ///   **Additiv und ohne eine einzige Zeile** — auch ohne die
  ///   Einstellungszeile. Vor dieser Stufe lagen keine Zyklusdaten in
  ///   dieser Datenbank, es gibt also nichts umzuschreiben; eine vorab
  ///   eingefügte Zeile behauptete einen Tageseintrag, ein geschriebenes
  ///   Sample oder eine getroffene Einstellung, die es nicht gab (dieselbe
  ///   Regel wie bei `stammdaten` und `ki_einstellungen`). Die Vorbelegung
  ///   der Einstellungen ist eine Dart-Konstante
  ///   (`ZyklusEinstellungen.vorbelegung`); stünde sie zusätzlich als
  ///   Zeile da, wäre einer der beiden Orte irgendwann der falsche. Die
  ///   erste Zeile schreibt der Eintragen-Schirm oder der Erstimport,
  ///   nicht das Schema. Kein Index, weil [_reconcileSchema] keine
  ///   Indizes kennt, und **kein `CHECK`** auf den offenen Wortschätzen
  ///   (`blutung`, `schmerz`, `test`, `quelle`, `sicht`,
  ///   `verhuetung_art`) — eine spätere Fassung schreibt dort einen Wert,
  ///   den es heute nicht gibt, und eine ältere soll die Datei trotzdem
  ///   öffnen.
  ///
  /// **Warum die 26:** Ursprünglich die 25, am 23.11.2026 aus dieser Datei
  /// gelesen (24) und um eins erhöht. Beim Zusammenführen am 24.11.2026 um
  /// eins nach oben gerückt, weil `main` die 25 inzwischen an die
  /// Sync-Felder (#542) vergeben hatte.
  /// - **v27** (#532, unter #531): die Tabellen der eigenen Trainings
  ///   (`gym_training_tabellen.dart`) — `gym_trainings`,
  ///   `gym_training_uebungen`, `gym_training_tags` und die gespeicherte
  ///   Rotation `gym_rotation` — und die Spalte `gym_sitzungen.trainings_name`,
  ///   der eingefrorene Name einer abgeschlossenen Sitzung. **`gym_sitzungen.
  ///   workout` heißt jetzt Kennung:** Sie trägt für ein Training ohne
  ///   Enum-Fall eine UUID statt eines Codes. Der Name der Spalte ist damit
  ///   ungenau und bleibt; ein Tabellenneubau, um sie umzubenennen, ist das
  ///   Risiko, das Tims einzige Kopie der Trainings nicht eingehen darf
  ///   (Spec 4.6).
  ///
  ///   **Additiv und ohne eine einzige Zeile.** Die Stufe schreibt kein
  ///   Template, keinen Namen in alte Sitzungen und keinen Platz der Rotation:
  ///   Eine alte Sitzung bekommt keinen erfundenen Namen (`NULL` bleibt
  ///   `NULL`), und Tims Trainings unter den Codes `A` bis `D` werden nicht
  ///   zu Zeilen der neuen Tabelle. Was beim Öffnen eingespielt wird — die
  ///   Templates Push, Pull, Legs und die Rotation —, tut `beforeOpen`, nicht
  ///   die Stufe ([GymTrainingRepository.spieleTemplatesEin],
  ///   [GymTrainingRepository.spieleRotationEin]); so erreicht es frische
  ///   Installationen, Geräte von v24 und Geräte, deren Tabellen der Abgleich
  ///   nachgelegt hat, auf demselben Weg. Kein Index, weil
  ///   [_reconcileSchema] keine Indizes kennt, und kein `DROP`.
  ///
  /// **Warum die 27:** Ursprünglich die 25, am 19.11.2026 aus dieser Datei
  /// und den offenen Zweigen gelesen (alle auf 24) und um eins erhöht. Beim
  /// Zusammenführen der beiden `main`-Stände am 24.11.2026 um zwei nach
  /// oben gerückt: `origin/main` hatte die 25 und die 26 bereits vergeben.
  ///
  /// - **v28** (#95, mit #16): die Spalte `vo2max` in `tages_werte`
  ///   (`tables.dart`) — `DailyMetrics.vo2max` bekommt eine Spalte, die
  ///   geerbte Schemagrenze aus Task 6 schrumpft von vier auf drei Felder.
  ///   Ohne sie stünde die VO₂max-Anzeige des Ausdauer-Schirms nach jedem
  ///   Kaltstart erst leer da, bis HealthKit antwortet — Ladezustand als
  ///   Leerstand, derselbe Fehler, den #194 für die Gewichtskachel und
  ///   #202 für Körperfett abgeräumt haben.
  ///
  ///   **Additiv, ohne Rückschreiben:** Bestandszeilen behalten jede
  ///   Spalte wortgleich, `vo2max` steht dort auf NULL — nicht auf `0`,
  ///   nicht auf einem erfundenen Wert.
  ///
  /// **Warum die 28:** Ursprünglich die 25, am 17.11.2026 gelesen und
  /// erhöht; dann die 26, weil #532 die 25 bekam. Beim Zusammenführen der
  /// beiden `main`-Stände am 24.11.2026 um zwei weiter nach oben gerückt:
  /// `origin/main` hatte 25 und 26 bereits an die Sync-Felder (#542) und
  /// den Zykluskalender (#592) vergeben. Zwei verschiedene Stufen unter
  /// derselben Nummer gibt es nicht — ein Gerät, das die eine ausgeführt
  /// hat, führte die andere nie aus. Dieselbe Auflösung wie bei v18, v24
  /// und v26 (#485): **die jüngere Stufe rückt hoch.** Die vo2max-Stufe
  /// steht deshalb **nach** der Gym-Stufe.
  ///
  @override
  int get schemaVersion => 28;

  /// `gelesenAm` ist ein UTC-`DateTime` (Spec 5.3b). Driftets Standard
  /// speichert Datumswerte als Unix-Sekunden und liest sie als **lokale**
  /// Zeit zurück — derselbe Zeitpunkt, aber mit `isUtc == false`. Zwei
  /// `DateTime`-Werte desselben Zeitpunkts mit unterschiedlichem `isUtc`
  /// sind in Dart **nicht** `==`-gleich, was den Rundweg-Test von
  /// `gelesenAm` sonst fehlschlagen ließe. Text-Speicherung erhält den
  /// ursprünglichen UTC-Zeitpunkt originalgetreu.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// Jede Stufe einzeln, additiv und ohne Rückschreiben: Keine Migration
  /// füllt eine neue Spalte mit einem Wert und keine legt eine
  /// Platzhalterzeile an. Eine migrierte Zeile, die plötzlich eine HRV
  /// trüge, behauptete eine Messung, die es nie gab — derselbe Fehler wie
  /// ein erfundener Zeitstempel, nur eine Spalte weiter.
  ///
  /// Jedes `addColumn` geht über [_addColumnIfMissing] (#234, siehe
  /// Dateikopf): Die Stufe tut, was sie immer tat, stirbt aber nicht mehr
  /// an einer Spalte, die ein anderer Zweig schon angelegt hat. Die
  /// `createTable`-Aufrufe bleiben, wie sie sind — drifts `createTable`
  /// setzt `CREATE TABLE IF NOT EXISTS` ab und ist damit schon robust. Ein
  /// vorsorgliches `DROP TABLE IF EXISTS` davor wäre eine Stufe, die nie
  /// scheitert und trotzdem Tims von Hand eingetragene Nächte löscht.
  ///
  /// **Die Ausnahme ist die Stufe 10**, und sie ist genau deshalb eine
  /// eigene: Dort ist das Wegnehmen die Anforderung und keine
  /// Nebenwirkung.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.gelesenAm);
      }
      if (from < 3) {
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.hrvMs);
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.respRate);
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.recoveryHrDrop);
        await m.createTable(naechte);
        await m.createTable(schlafAbschnitte);
      }
      if (from < 4) {
        await m.createTable(zielWerte);
      }
      // Als rohes SQL und nicht über `createTable`: Die Tabelle steht seit
      // #269 nicht mehr im Schema, es gibt also kein `TableInfo`, auf das
      // sich zeigen ließe. Ihre Form ist trotzdem festgelegt — so sah sie
      // 2026 aus, und ein Altstand ändert sich nicht mehr. `IF NOT EXISTS`
      // wie bei `Migrator.createTable`, damit die Stufe auf einem Gerät,
      // das die Tabelle von einem anderen Zweig hat, nicht stirbt (#234).
      if (from < 5) {
        await customStatement(
          'CREATE TABLE IF NOT EXISTS tagesgefuehle ('
          'tag TEXT NOT NULL, '
          'wert INTEGER NOT NULL, '
          'PRIMARY KEY (tag));',
        );
      }
      if (from < 6) {
        await m.createTable(schlafEintraege);
      }
      if (from < 7) {
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.gewichtKg);
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.trainingsMinuten);
      }
      // Früher stand hier `from >= 3 && from < 8`. Die Einschränkung sollte
      // verhindern, dass ein Gerät von v1 oder v2 `ALTER TABLE` auf eine
      // Spalte bekommt, die die v3-Stufe gerade erst mitgebracht hat —
      // `naechte` entsteht dort aus der **heutigen** Definition. Das war
      // eine Antwort über die Versionsnummer, und die trägt nicht: Auf Tims
      // iPhone stand am 03.11.2026 `user_version = 7` und `naechte` hatte
      // die drei Spalten trotzdem schon, angelegt von einem anderen Zweig
      // (#240, Duplikat von #234). Die Nummer sagt nichts darüber, was
      // wirklich in der Datei steht — also fragt jetzt jede Spalte die
      // Datei, und die Stufe darf wieder schlicht `from < 8` heißen.
      if (from < 8) {
        await _addColumnIfMissing(m, naechte, naechte.ruhepulsBpm);
        await _addColumnIfMissing(m, naechte, naechte.hrvMs);
        await _addColumnIfMissing(m, naechte, naechte.respRate);
      }
      if (from < 9) {
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.koerperfettPct);
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.fettfreiKg);
      }
      // Der Name steht als Zeichenkette da und nicht als `TableInfo`: Die
      // Tabelle gibt es im heutigen Schema nicht mehr, also gibt es auch
      // kein Objekt, auf das sich zeigen ließe. Das ist bei einer
      // löschenden Stufe die Regel, nicht die Ausnahme.
      if (from < 10) {
        await m.deleteTable('tagesgefuehle');
      }
      if (from < 11) {
        await m.createTable(stammdaten);
      }
      if (from < 12) {
        await m.createTable(lebensmittel);
        await m.createTable(portionen);
        await m.createTable(eintraege);
        await m.createTable(rezepte);
        await m.createTable(rezeptZutaten);
      }
      // Je Spalte über [_addColumnIfMissing], nicht je Stufe: Ein anderer
      // Zweig kann `name` und `kcal` unter derselben Bundle-ID schon
      // angelegt haben, während die Nummer noch auf 12 steht. Eine Stufe,
      // die beim ersten vorhandenen Stück abbräche, ließe die halb
      // gelaufene Stufe für immer halb.
      if (from < 13) {
        // Erst die Tabelle, dann die Spalten. Ein Gerät, dessen
        // `user_version` schon 12 sagt, dem `lebensmittel` aber fehlt (ein
        // Zweigwechsel, #233), liefe sonst an `no such table` auf — genau
        // die Stufe, die an einem fremden Zwischenstand stirbt, gegen die
        // #234 gebaut ist. `createTable` setzt `CREATE TABLE IF NOT EXISTS`
        // ab und tut auf einer vollständigen Datei nichts.
        await m.createTable(lebensmittel);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.name);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.kcal);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.eiweissG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.kohlenhydrateG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.fettG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.zuckerG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.ballaststoffeG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.gesaettigtG);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.wasserMl);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.extra);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.fluessig);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.zuletztBenutzt);
      }
      if (from < 14) {
        // Erst die Tabelle, dann die Spalten — derselbe Grund wie in
        // Stufe 13: Ein Gerät mit fremdem Zwischenstand darf nicht an
        // `no such table` sterben.
        //
        // **Beide Spalten über [_addColumnIfMissing].** Wer von v12 kommt,
        // hat in diesem Lauf gerade die Stufe 13 hinter sich, und deren
        // `createTable` legt `lebensmittel` aus der **heutigen**
        // Definition an — mit `barcode` und `herkunft`. Ohne die Prüfung
        // stürbe diese Stufe dann an `duplicate column name`.
        await m.createTable(lebensmittel);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.barcode);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.herkunft);
      }
      if (from < 15) {
        // `createTable` setzt `CREATE TABLE IF NOT EXISTS` ab: Hat ein
        // anderer Zweig `ki_anfragen` unter derselben Bundle-ID schon
        // angelegt, bleibt sie stehen — samt gezähltem Verbrauch. Ein
        // Neubau setzte das Monatslimit still zurück.
        await m.createTable(kiEinstellungen);
        await m.createTable(kiAnfragen);
        // Erst die Tabelle, dann die Spalte — derselbe Grund wie in den
        // Stufen 13 und 14. Und die Spalte über [_addColumnIfMissing]: Wer
        // von v11 oder früher kommt, hat in diesem Lauf `eintraege` aus der
        // **heutigen** Definition bekommen, `vorschlag` steht dann schon da.
        await m.createTable(eintraege);
        await _addColumnIfMissing(m, eintraege, eintraege.vorschlag);
      }
      if (from < 16) {
        // `CREATE TABLE IF NOT EXISTS`: Hat ein anderer Zweig unter
        // derselben Bundle-ID `wasser_eintraege` schon angelegt, bleibt sie
        // samt ihren Gläsern stehen (#234/#240).
        await m.createTable(wasserEintraege);
      }
      if (from < 17) {
        // Erst die Tabellen, dann die Spalten — derselbe Grund wie in den
        // Stufen 13 bis 15: Ein Gerät mit fremdem Zwischenstand darf nicht
        // an `no such table` sterben.
        //
        // **Jede Spalte über [_addColumnIfMissing].** Wer von v11 oder
        // früher kommt, hat in diesem Lauf `lebensmittel`, `portionen` und
        // `eintraege` aus der **heutigen** Definition bekommen; die
        // Spalten stehen dann schon da, und ohne die Prüfung stürbe die
        // Stufe an `duplicate column name`.
        await m.createTable(lebensmittel);
        await m.createTable(portionen);
        await m.createTable(eintraege);
        await _addColumnIfMissing(m, portionen, portionen.lebensmittelId);
        await _addColumnIfMissing(m, portionen, portionen.name);
        await _addColumnIfMissing(m, portionen, portionen.mengeG);
        await _addColumnIfMissing(m, portionen, portionen.herkunft);
        await _addColumnIfMissing(m, eintraege, eintraege.portionId);
        await _addColumnIfMissing(m, eintraege, eintraege.portionName);
        await _addColumnIfMissing(m, eintraege, eintraege.portionG);
        await _addColumnIfMissing(
          m,
          lebensmittel,
          lebensmittel.portionenAbgefragtAm,
        );
      }
      if (from < 18) {
        // `createTable` setzt `CREATE TABLE IF NOT EXISTS` ab: Hat ein
        // anderer Zweig die Gym-Tabellen unter derselben Bundle-ID schon
        // angelegt, bleiben sie samt ihren Trainings stehen (#234/#240).
        // Ein vorsorgliches `DROP` davor wäre eine Stufe, die nie
        // scheitert und trotzdem Tims einzige Kopie löscht.
        //
        // **Keine Spalte wird nachgetragen und keine Zeile geschrieben**:
        // Vor dieser Stufe gibt es keine Gym-Daten, also gibt es auch
        // nichts zu füllen.
        await m.createTable(gymSitzungen);
        await m.createTable(gymSaetze);
        await m.createTable(gymEntwuerfe);
      }
      if (from < 19) {
        // `CREATE TABLE IF NOT EXISTS`: Hat ein anderer Zweig unter
        // derselben Bundle-ID `kalorienziele` schon angelegt, bleibt sie
        // samt ihren Festlegungen stehen (#234/#240).
        await m.createTable(kalorienziele);
      }
      if (from < 20) {
        // Über [_addColumnIfMissing]: Hat ein anderer Zweig unter derselben
        // Bundle-ID die Spalte schon angelegt, bleiben ihre Werte (#234/#240).
        await _addColumnIfMissing(m, eintraege, eintraege.fluessig);
      }
      if (from < 21) {
        // CREATE TABLE IF NOT EXISTS: Hat ein anderer Zweig die Tabelle
        // schon angelegt, bleibt sie samt Zeilen (#234/#240).
        await m.createTable(mahlzeitAufteilungen);
      }
      if (from < 22) {
        // CREATE TABLE IF NOT EXISTS: Hat ein anderer Zweig unter
        // derselben Bundle-ID `ereignisse` schon angelegt, bleibt sie
        // samt ihren Zeilen stehen (#234/#240).
        await m.createTable(ereignisse);
      }
      if (from < 23) {
        // CREATE TABLE IF NOT EXISTS: Hat ein anderer Zweig unter
        // derselben Bundle-ID `wach_belege` schon angelegt, bleibt sie
        // samt ihren Zeilen stehen (#234/#240).
        await m.createTable(wachBelege);
      }
      if (from < 24) {
        // CREATE TABLE IF NOT EXISTS: Hat ein anderer Zweig unter
        // derselben Bundle-ID `umfaenge` schon angelegt, bleibt sie samt
        // ihren Messungen stehen (#234/#240). Kein vorsorgliches
        // `DROP TABLE IF EXISTS` davor — eine Stufe, die nie scheitert und
        // dabei Tims von Hand eingetragene Umfänge löscht, ist die
        // schlechtere Stufe.
        await m.createTable(umfaenge);
      }
      if (from < 25) {
        // Die Sync-Felder (#542): UUID, Änderungszeitpunkt, Löschmarker,
        // Autor — an `lebensmittel` zusätzlich der Quellschlüssel (BLS-Code
        // oder EAN). Alle nullbar und ohne Vorgabewert, damit keine
        // Bestandszeile eine Herkunft, einen Autor oder eine frische
        // Änderung behauptet, die es nie gab.
        //
        // Über [_addColumnIfMissing], nicht über `addColumn`: Ein v11-Stand
        // läuft durch Stufe 12, und die legt beide Tabellen aus der
        // **heutigen** Definition an — also samt dieser Spalten. Ohne die
        // Prüfung stürbe die Stufe hier an `duplicate column name`
        // (#234/#240).
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.uuid);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.geaendertAm);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.geloeschtAm);
        await _addColumnIfMissing(m, lebensmittel, lebensmittel.autor);
        await _addColumnIfMissing(
            m, lebensmittel, lebensmittel.quelleSchluessel);
        await _addColumnIfMissing(m, rezepte, rezepte.uuid);
        await _addColumnIfMissing(m, rezepte, rezepte.geaendertAm);
        await _addColumnIfMissing(m, rezepte, rezepte.geloeschtAm);
        await _addColumnIfMissing(m, rezepte, rezepte.autor);
      }
      // **Die Zyklus-Stufe ist beim Zusammenführen von 25 auf 26
      // gerückt** (24.11.2026). Beide Zweige hatten sie als 25
      // gebaut: `main` die Sync-Felder (#542), der Zyklus-Zweig die
      // drei Tabellen (#592). Eine Versionsnummer sagt nicht, welches
      // Ticket zuerst fertig war, sondern **was ein Gerät schon
      // ausgeführt hat** — gerückt wird deshalb nach oben, nie
      // verschoben. Ein Gerät, das die Sync-Felder als 25 hinter sich
      // hat, bekäme die Zyklustabellen sonst nie.
      if (from < 26) {
        // CREATE TABLE IF NOT EXISTS: Hat ein anderer Zweig unter
        // derselben Bundle-ID die drei Zyklustabellen schon angelegt,
        // bleiben sie samt ihren Zeilen stehen (#234/#240). Kein
        // vorsorgliches `DROP TABLE IF EXISTS` davor — eine Stufe, die
        // nie scheitert und dabei eingetragene Zyklustage löscht, ist die
        // schlechtere Stufe, und es sind Gesundheitsdaten.
        await m.createTable(zyklusEintraege);
        await m.createTable(zyklusHealthSpiegel);
        await m.createTable(zyklusEinstellungen);

      }
      // **Die Gym-Stufe und die vo2max-Stufe sind beim Zusammenführen der
      // beiden `main`-Stände am 24.11.2026 von 25 und 26 auf 27 und 28
      // gerückt.** Beide Seiten hatten vom gemeinsamen Stand 24 aus
      // unabhängig eine 25 und eine 26 vergeben: `origin/main` die
      // Sync-Felder (#542) und die Zyklustabellen (#592), der hiesige
      // Stand die Trainings-Tabellen (#532) und `vo2max` (#95). Eine
      // Versionsnummer sagt nicht, welches Ticket zuerst fertig war,
      // sondern **was ein Gerät schon ausgeführt hat** — gerückt wird
      // deshalb nach oben, nie verschoben. Die Nummern von `origin/main`
      // bleiben, weil dieser Stand gepusht war und auf einem Gerät
      // gelaufen sein kann; die hiesigen waren es nie.
      if (from < 27) {
        // Erst die Tabellen, dann die Spalte — derselbe Grund wie in den
        // Stufen 13 bis 17: Ein Gerät mit fremdem Zwischenstand darf nicht
        // an `no such table` sterben. `createTable` setzt `CREATE TABLE IF
        // NOT EXISTS` ab: Hat ein anderer Zweig unter derselben Bundle-ID
        // eine der vier Tabellen schon angelegt, bleibt sie samt ihren
        // Zeilen stehen (#234/#240). Kein vorsorgliches `DROP TABLE IF
        // EXISTS` davor — eine Stufe, die nie scheitert und dabei Tims
        // Trainings löscht, ist die schlechtere Stufe.
        await m.createTable(gymTrainings);
        await m.createTable(gymTrainingUebungen);
        await m.createTable(gymTrainingTags);
        await m.createTable(gymRotation);
        // **Nur wenn `gym_sitzungen` in der Datei steht.** Eine Datei auf
        // 19 oder 20 trägt die Gym-Tabellen noch nicht (die Stufe 18 lief
        // dort nie, oder ein fremder Zwischenstand hat sie nie angelegt);
        // `_addColumnIfMissing` stürbe dort an `no such table` — beim
        // Öffnen, und danach wäre die Datenbank nicht mehr zu benutzen.
        // Fehlt die Tabelle, legt `_reconcileSchema` sie danach aus der
        // **heutigen** Definition an, und damit samt Spalte.
        if ((await _existingTableNames()).contains('gym_sitzungen')) {
          await _addColumnIfMissing(
            m,
            gymSitzungen,
            gymSitzungen.trainingsName,
          );
        }
      }
      if (from < 28) {
        // Erst die Tabelle, dann die Spalte — derselbe Grund wie in den
        // Stufen 13 bis 17: Ein Gerät mit fremdem Zwischenstand, dem
        // `tages_werte` fehlt (etwa eine v12-Datei, die nur `lebensmittel`
        // trägt), darf nicht an `no such table` sterben. `createTable`
        // setzt `CREATE TABLE IF NOT EXISTS` ab und tut auf einer
        // vollständigen Datei nichts.
        //
        // Die Spalte über [_addColumnIfMissing]: Hat ein anderer Zweig
        // unter derselben Bundle-ID die Spalte schon angelegt, bleiben
        // ihre Werte (#234/#240).
        await m.createTable(tagesWerte);
        await _addColumnIfMissing(m, tagesWerte, tagesWerte.vo2max);
      }
    },
    // Läuft nach `onCreate` und nach `onUpgrade` — und, anders als beide,
    // **bei jedem** Öffnen, auch wenn die Nummer schon stimmt. Genau dieser
    // Fall lag auf Tims Gerät vor (Dateikopf). Nach `onUpgrade` und nicht
    // davor, weil ein vorgezogener Abgleich den Stufen die Arbeit wegnähme
    // und sie danach mit `duplicate column name` scheitern ließe.
    beforeOpen: (_) async {
      await _reconcileSchema();
      // **Nach** dem Abgleich — erst dann stehen die Tabellen — und in dieser
      // Reihenfolge: Die Rotation verweist auf die Templates.
      await _spieleStartbefuellungEin();
    },
  );

  /// Spielt beim Öffnen ein, was die App selbst mitbringt: die Templates und
  /// die Startrotation (Spec 4.3, 23, 24, 25).
  ///
  /// **Aus `beforeOpen` und nicht aus der Stufe**, damit es jeden der drei
  /// Wege erreicht: frische Installation (`onCreate`), Gerät von v24 (nach
  /// der Stufe) und ein Gerät, dessen Tabellen der Abgleich nachgelegt hat.
  /// Beides braucht keine Uhr — deshalb darf es dort stehen. Beides ist
  /// idempotent und fasst keine vorhandene Zeile an.
  Future<void> _spieleStartbefuellungEin() async {
    final trainings = GymTrainingRepository(this);
    await trainings.spieleTemplatesEin();
    await trainings.spieleRotationEin();
  }

  /// Hängt [column] an [table] an — aber nur, wenn die Spalte in der Datei
  /// wirklich fehlt (#234).
  ///
  /// **Warum eine Stufe das überhaupt nachsehen muss.** Alle Zweige bauen
  /// unter derselben Bundle-ID und benutzen dieselbe Datei. Ein Zweig, der
  /// die v7-Spalten schon anlegt, hinterlässt eine `tages_werte` **mit**
  /// `koerperfett_pct` und `fettfrei_kg`; steht in der Datei trotzdem
  /// `user_version = 6`, weil der andere Zweig seine eigene Nummerierung
  /// führt, läuft `if (from < 7)` und stirbt an
  /// `SqliteException(1): duplicate column name: koerperfett_pct`. Und
  /// zwar beim **Öffnen** — danach ist die Datenbank unbenutzbar, kein
  /// Lesen, kein Schreiben. Das ist die Gegenrichtung zu #233 und die
  /// schlimmere: Dort blieb der zwischengespeicherte Stand wenigstens
  /// lesbar stehen.
  ///
  /// Der Abgleich aus #233 hilft hier nicht. Er hängt an `beforeOpen` und
  /// käme nie an die Reihe, weil `onUpgrade` vorher wirft — und fände auch
  /// dann nichts zu tun, denn es **fehlt** ja nichts.
  ///
  /// **Nachsehen statt den Fehler fangen.** Beides ergäbe dasselbe
  /// Ergebnis, aber nur das Nachsehen liest wie das, was gemeint ist: Die
  /// Stufe fragt die Datei, was dasteht, statt eine Ausnahme als
  /// Normalfall zu behandeln. Gefragt wird mit [_existingColumnNames] —
  /// derselben Prüfung, die [_reconcileSchema] benutzt. Eine zweite
  /// Stelle, die dasselbe anders prüft, wäre die nächste Fehlerquelle.
  ///
  /// **Je Spalte, nicht je Stufe.** Dass die erste Spalte einer Stufe schon
  /// dasteht, sagt nichts über die zweite: Eine Stufe, die beim ersten
  /// Treffer den ganzen Block überspränge, ließe die halb gelaufene Stufe
  /// für immer halb.
  ///
  /// Angefasst wird nichts, was schon da ist — kein Leeren einer
  /// vorhandenen Spalte, kein Tabellenneubau. Ein vorhandener Wert ist
  /// Tims Wert, und ein stiller Verlust wäre schlimmer als der Absturz,
  /// den diese Prüfung behebt.
  ///
  /// **Fehlt die ganze Tabelle, wird nichts angehängt.** `ALTER TABLE …
  /// ADD COLUMN` auf eine Tabelle, die es nicht gibt, ist kein
  /// Sonderfall, sondern ein Absturz („no such table"), und genau dieser
  /// Stand lag auf Tims Gerät vor (#233): Nummer stimmt, Tabelle fehlt.
  /// Bis zur Stufe 25 fiel das niemandem auf, weil `onUpgrade` auf einer
  /// Datei mit passender Nummer gar nicht erst läuft — die erste Stufe
  /// **nach** jenem Stand deckte es auf. Zuständig ist hier
  /// [_reconcileSchema]: Es legt die fehlende Tabelle anschließend
  /// vollständig an, also samt dieser Spalte. Eine leere Spaltenliste ist
  /// das sichere Signal dafür — eine Tabelle ohne Spalten gibt es in
  /// SQLite nicht.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final existingColumns = await _existingColumnNames(table.actualTableName);
    if (existingColumns.isEmpty) return;
    if (existingColumns.contains(column.name)) return;

    await m.addColumn(table, column);
  }

  /// Zieht nach, was die Datei gegenüber dem heutigen Schema vermissen
  /// lässt: fehlende Tabellen und fehlende Spalten.
  ///
  /// **Gefragt wird die Datei, nicht die Nummer.** `PRAGMA table_info` und
  /// `sqlite_master` sagen, was wirklich dasteht; die Nummer kann lügen,
  /// und auf Tims Gerät tat sie es.
  ///
  /// **Erst nachsehen, dann — nur bei Bedarf — ändern.** Im Normalfall
  /// setzt diese Methode kein einziges `CREATE` oder `ALTER` ab, und das
  /// ist nachweisbar: SQLite erhöht `PRAGMA schema_version` bei jedem
  /// `CREATE`, `ALTER` und `DROP` und sonst nie. Ein Abgleich, der
  /// vorsorglich bei jedem Start Statements absetzte, wäre kein Abgleich
  /// mehr, sondern ein Umbau bei jedem Öffnen — und der träfe jedes Gerät,
  /// nicht nur das kaputte.
  ///
  /// **Generisch über die Schema-Entitäten von drift**, nicht über eine von
  /// Hand gepflegte Liste von Namen: Eine solche Liste wäre beim nächsten
  /// Schema wieder die eine Stelle, die jemand vergisst — und genau davon
  /// handelt dieses Ticket.
  ///
  /// Was er **nicht** kann: eine vorhandene Spalte mit falschem Typ oder
  /// falschem `NOT NULL` reparieren (SQLite verlangt dafür einen
  /// Tabellenneubau mit Umkopieren, und der kann Zeilen verlieren), eine
  /// fehlende `NOT NULL`-Spalte ohne Vorgabewert in eine Tabelle mit Zeilen
  /// einfügen (`ALTER TABLE … ADD COLUMN` lehnt das ab, und es gäbe keinen
  /// ehrlichen Wert für die Lücke), und verlorene Daten zurückholen: Eine
  /// nachgelegte Tabelle kommt leer, eine nachgezogene Spalte steht auf
  /// `NULL`. Erfundene Zeilen und erfundene Nullwerte wären schlimmer als
  /// die Lücke — ein fehlender Messwert ist nicht `0` (Fehler `01`).
  ///
  /// Die Gegenrichtung — Nummer zu niedrig, Spalten schon da, `onUpgrade`
  /// scheitert mit `duplicate column name` — gehört den Stufen und liegt
  /// seit #234 bei [_addColumnIfMissing].
  Future<void> _reconcileSchema() async {
    final migrator = createMigrator();
    final existingTables = await _existingTableNames();

    for (final table in allTables) {
      if (!existingTables.contains(table.actualTableName)) {
        await migrator.createTable(table);
        continue;
      }

      final existingColumns = await _existingColumnNames(table.actualTableName);
      for (final column in table.$columns) {
        if (!existingColumns.contains(column.name)) {
          await migrator.addColumn(table, column);
        }
      }
    }
  }

  /// Die Tabellen, die wirklich in der Datei stehen. `sqlite_%` sind die
  /// internen Tabellen von SQLite (etwa `sqlite_sequence` hinter
  /// `AUTOINCREMENT`); die gehören niemandes Schema.
  Future<Set<String>> _existingTableNames() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%';",
    ).get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  /// Die Spalten einer Tabelle, so wie sie wirklich in der Datei stehen.
  /// Genau diese Auskunft fehlte `onUpgrade`.
  ///
  /// `PRAGMA` nimmt keine Platzhalter, der Name steht deshalb im Text. Er
  /// stammt aus `allTables` — aus dem erzeugten Schema, nie aus einer
  /// Eingabe.
  Future<Set<String>> _existingColumnNames(String table) async {
    final rows = await customSelect('PRAGMA table_info($table);').get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }
}
