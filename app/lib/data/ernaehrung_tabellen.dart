// Die fünf Ernährungstabellen (Schema v12, Ernährungsplan Task 3):
// `lebensmittel` und `portionen` als Vorlage, `eintraege` als Tatsache,
// `rezepte` und `rezept_zutaten` für das Gekochte
// (`docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, „Die
// Tabellen").
//
// API und Vertrag sind durch `app/test/data/schema_v12_test.dart` und
// `app/test/data/ernaehrung_repository_test.dart` verbindlich vorgegeben
// (siehe deren Dateiköpfe) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Eine eigene Datei und nicht `tables.dart`**, anders als bei
// `Stammdaten`. Dort erzwang eine Namenskollision die Trennung von
// Tabelle und Werttyp; hier gibt es keine — der Werttyp heißt `Eintrag`,
// die Tabelle `Eintraege`, die erzeugte Datenklasse `EintragRow`. Die
// eigene Datei ist schlicht das, was der Plan vorsieht und was der
// Dateikopf von `schema_v12_test.dart` wiederholt: fünf Tabellen, die
// zusammengehören und mit den acht alten nichts zu tun haben.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Hinter diesen Zeilen steht kein Lauf aus Apple Health, der leer
// ausgehen könnte, sondern Tim. Leer heißt leer, und ein `gelesen_am`
// hätte nichts zu tragen. Die Richtung ist seit dem 03.11.2026
// umgedreht: Die eigene Tabelle ist die Wahrheit, Apple Health bekommt
// eine Kopie.
//
// ## Was eine spätere Aufgabe hier anhängen darf
//
// `rezepte` und `rezept_zutaten` tragen vorerst nur ihren Schlüssel. Ihre
// Inhalte gehören den Aufgaben, die sie brauchen — die Rezepte in Task 8
// —, und eine Spalte hier wäre eine Entscheidung über Code, den niemand
// geschrieben hat.
//
// **`portionen` hat ihre Spalten seit Schema v17** (#393, unter #325),
// ebenso der Portions-Schnappschuss in `eintraege` und
// `lebensmittel.portionen_abgefragt_am`
// (`docs/superpowers/specs/2026-11-05-portionen-design.md`, „Die
// Datenschicht"). Festgelegt durch `app/test/data/schema_v17_test.dart`.
//
// **`lebensmittel` hat ihre Spalten seit Schema v13** (#285): Der
// vollständige Eintragweg ohne Barcode und ohne Open Food Facts braucht
// die Vorlagenhälfte, und damit braucht sie Inhalt. Festgelegt sind sie
// durch `app/test/data/schema_v13_test.dart` und
// `app/test/ernaehrung/lebensmittel_repository_test.dart`.
//
// **Wer eine Spalte nachträgt, macht sie nullbar oder gibt ihr einen
// Vorgabewert.** SQLite lehnt `ALTER TABLE … ADD COLUMN … NOT NULL` ohne
// Vorgabewert ab, unabhängig davon, ob Zeilen darin stehen — und genau
// diesen Weg nimmt `AppCache._reconcileSchema` (#233) auf einer Datei, in
// der die Tabelle von einem anderen Zweig schon steht. Das ist keine
// Stilfrage: Eine `NOT NULL`-Spalte ohne Vorgabewert lässt sich nur beim
// `CREATE TABLE` vergeben, und das ist auf einem Gerät, das die Tabelle
// schon hat, vorbei.
import 'package:drift/drift.dart';

/// Ein Lebensmittel als **Vorlage** (Schema v12).
///
/// Name und Nährwerte je 100 g kamen mit Schema v13 (#285), Strichcode
/// und Herkunft mit Schema v14 (#284, Open Food Facts),
/// [portionenAbgefragtAm] mit Schema v17 (#393). Die Standardportionen
/// liegen in [Portionen]. Die Marke (Hersteller) gehört laut Entwurf
/// ebenfalls hierher und kommt mit dem Code, der sie braucht.
///
/// **Die Vorlage ist nicht die Tatsache.** Wird ein Lebensmittel später
/// korrigiert oder gelöscht, ändert das keinen gebuchten Eintrag — der
/// hält seine eigenen Zahlen (siehe [Eintraege]).
@DataClassName('LebensmittelRow')
class Lebensmittel extends Table {
  /// Der Schlüssel, **mit `AUTOINCREMENT`** — aus demselben Grund wie bei
  /// [Eintraege.id]: `Eintraege.lebensmittelId` zeigt hierher, und eine
  /// nach einer Löschung erneut vergebene Zeilennummer hinge einen
  /// gebuchten Eintrag lautlos an eine fremde Vorlage.
  IntColumn get id => integer().autoIncrement()();

  /// Wie die Vorlage heißt — das, wonach die Suche sucht.
  ///
  /// **`NOT NULL` mit Vorgabewert `''`.** `LebensmittelVorlage.name` ist
  /// ein nicht-nullbarer `String`, die treue Abbildung davon ist
  /// `NOT NULL`. Dann braucht die Spalte aber einen Vorgabewert, denn
  /// SQLite lehnt `ALTER TABLE … ADD COLUMN … NOT NULL` ohne ihn ab — und
  /// genau diesen Weg nimmt die Stufe 13 (siehe Dateikopf). Der leere Name
  /// ist dabei kein erfundener Name, sondern das Eingeständnis, dass
  /// keiner dasteht: Auf einem v12-Gerät gab es die Spalte nicht, also
  /// weiß niemand mehr, wie die Vorlage hieß.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Die acht Nährwerte **je 100 g** — benannt wie in [Eintraege], weil
  /// beide dasselbe halten: einen `Naehrwerte`-Satz. Zwei Schreibweisen
  /// für dasselbe Feld wären zwei Umwandlungen, die auseinanderlaufen
  /// können, und die Zahlen wandern beim Buchen von hier nach dort.
  ///
  /// Alle nullbar: Ein Lebensmittel ohne Ballaststoffangabe hat nicht 0 g
  /// davon, sondern keine Angabe (#232). Eine **gewogene** Null bleibt
  /// dagegen `0` — Mineralwasser hat 0 kcal, und das ist eine Messung.
  RealColumn get kcal => real().nullable()();
  RealColumn get eiweissG => real().named('eiweiss_g').nullable()();
  RealColumn get kohlenhydrateG =>
      real().named('kohlenhydrate_g').nullable()();
  RealColumn get fettG => real().named('fett_g').nullable()();
  RealColumn get zuckerG => real().named('zucker_g').nullable()();
  RealColumn get ballaststoffeG =>
      real().named('ballaststoffe_g').nullable()();
  RealColumn get gesaettigtG => real().named('gesaettigt_g').nullable()();
  RealColumn get wasserMl => real().named('wasser_ml').nullable()();

  /// Die übrigen Nährwerte als JSON-Objekt — dieselbe Spalte und derselbe
  /// Name wie bei [Eintraege.extra], und aus denselben Gründen:
  /// `Naehrwerte.extra` ist eine nicht-nullbare Map, das leere Objekt ist
  /// ihr genaues Abbild, und der Vorgabewert macht die Spalte nachtragbar.
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  /// Ob in Millilitern gerechnet wird statt in Gramm — **das ist alles,
  /// was dieses Feld entscheidet.** Ein Getränk wiegt man nicht, man
  /// schenkt es ein (`docs/screens/screens/erfassen.js`, Zustand
  /// `anlegen`).
  ///
  /// Vorgabe `false`: Ein Lebensmittel ohne Angabe ist fest, nicht
  /// unbekannt. `drift`s `boolean()` legt dafür eine `INTEGER`-Spalte mit
  /// `CHECK (… IN (0, 1))` an — SQLite kennt keinen Wahrheitstyp.
  BoolColumn get fluessig => boolean().withDefault(const Constant(false))();

  /// Wann die Vorlage zuletzt gebucht wurde — **nullbar**: Angelegt ist
  /// nicht benutzt.
  ///
  /// Ein Vorgabewert wäre hier ein erfundener Zeitpunkt, und „nie benutzt"
  /// ist in der Reihenfolge der Suche ein eigener Fall: zuletzt Benutztes
  /// zuerst, nie Benutztes danach alphabetisch.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT (`CLAUDE.md`).
  DateTimeColumn get zuletztBenutzt =>
      dateTime().named('zuletzt_benutzt').nullable()();

  /// Der Strichcode (EAN) — **nullbar**: Ein selbst angelegtes
  /// Lebensmittel hat keinen (Schema v14, #284).
  ///
  /// Er ist das, woran die Tabelle ein übernommenes Produkt aus Open Food
  /// Facts wiedererkennt. Ohne ihn legte jedes Buchen desselben Produkts
  /// ein neues an, und die Suche könnte einen Online-Treffer nicht gegen
  /// die eigene Kopie abgleichen.
  ///
  /// **Kein `UNIQUE`-Index.** Dass ein Strichcode nur einmal übernommen
  /// wird, sichert `LebensmittelRepository.uebernimm` in einer Transaktion
  /// ab. Ein Index ließe sich über `_reconcileSchema` nicht nachziehen —
  /// der kennt Tabellen und Spalten, keine Indizes — und stünde damit auf
  /// manchen Geräten und auf anderen nicht.
  TextColumn get barcode => text().nullable()();

  /// Woher die Vorlage stammt: `'eigen'` oder `'off'` (Open Food Facts) —
  /// als Text, damit lesbar bleibt, was dasteht, wer die Datei mit einem
  /// SQLite-Werkzeug öffnet (dieselbe Haltung wie `eintraege.mahlzeit`).
  ///
  /// **`NOT NULL` mit Vorgabewert `'eigen'`.** Der Vorgabewert ist hier
  /// keine erfundene Angabe: Vor v14 gab es keinen Weg aus Open Food Facts
  /// in die Tabelle, jede ältere Zeile ist von Hand angelegt. Und SQLite
  /// lehnt `ADD COLUMN … NOT NULL` ohne ihn ab (Dateikopf).
  TextColumn get herkunft => text().withDefault(const Constant('eigen'))();

  /// Wann Open Food Facts zu diesem Produkt nach Portionen gefragt wurde
  /// und geantwortet hat (Schema v17, #393) — **nullbar und ohne
  /// Vorgabewert**.
  ///
  /// Ein Vorgabewert behauptete eine Anfrage, die es nie gab. Alte Zeilen
  /// bleiben `null`, und genau das löst die einmalige Nachfrage aus. Die
  /// Stufe 17 setzt die Spalte nirgends.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT und kommt als UTC zurück (`CLAUDE.md`).
  ///
  /// **Kein Index**, aus demselben Grund wie bei [barcode].
  DateTimeColumn get portionenAbgefragtAm =>
      dateTime().named('portionen_abgefragt_am').nullable()();

  /// Die Sync-Identität neben der Autoincrement-ID (Schema v25, #542).
  ///
  /// Später sollen eigene Vorlagen und Rezepte zwischen den Nutzer*innen
  /// geteilt werden; ein Autoincrement-Schlüssel taugt dafür nicht, weil
  /// zwei Geräte unabhängig dieselbe 7 vergeben. Die Spalte steht jetzt
  /// da, damit der Sync ein Anbau wird und kein Umbau.
  ///
  /// **Nullbar und ohne Vorgabewert** — wie alle vier Nachbarn unten.
  /// Vor v25 gab es keinen Sync, also hat niemand eine UUID vergeben;
  /// eine nachträglich erfundene behauptete das Gegenteil.
  ///
  /// **Kein `UNIQUE`**, aus demselben Grund wie bei [barcode]: Der
  /// Abgleich beim Öffnen kennt Tabellen und Spalten, keine Indizes, und
  /// eine Eindeutigkeit, die auf manchen Geräten gilt und auf anderen
  /// nicht, ist keine.
  TextColumn get uuid => text().nullable()();

  /// Wann die Zeile zuletzt geändert wurde (Schema v25, #542) — die
  /// Grundlage jedes späteren Abgleichs zweier Stände.
  ///
  /// Nullbar und ohne Vorgabewert: Ein Vorgabewert behauptete, jede alte
  /// Zeile sei eben erst geändert worden. TEXT und UTC wie überall
  /// (`storeDateTimeAsText`, `CLAUDE.md`).
  DateTimeColumn get geaendertAm =>
      dateTime().named('geaendert_am').nullable()();

  /// Der Löschmarker (Schema v25, #542): Ein gelöschtes Lebensmittel wird
  /// später markiert statt entfernt, sonst kehrt es beim nächsten Abgleich
  /// vom anderen Gerät zurück.
  ///
  /// **Gelöscht wird bis auf Weiteres gar nicht** — das Repository kennt
  /// keinen Weg dorthin. Die Spalte hält den Platz frei; sie ist leer,
  /// und das ist die Wahrheit.
  DateTimeColumn get geloeschtAm =>
      dateTime().named('geloescht_am').nullable()();

  /// Wer die Vorlage angelegt hat (Schema v25, #542) — gefüllt erst, wenn
  /// es mehr als ein Gerät gibt.
  ///
  /// Nullbar und ohne Vorgabewert: Ein Vorgabe-Autor behauptete, jede
  /// alte Vorlage stamme von ihm.
  TextColumn get autor => text().nullable()();

  /// Der Schlüssel in der Quelle, aus der die Vorlage übernommen wurde
  /// (Schema v25, #542): der BLS-Code bei Grundnahrung aus dem
  /// Bundeslebensmittelschlüssel, die EAN bei einem Produkt aus Open Food
  /// Facts.
  ///
  /// Warum nicht [barcode]: Ein BLS-Code ist kein Strichcode, und
  /// `zuBarcode` sucht Produkte, die man scannen kann. Ein BLS-Eintrag im
  /// Barcode-Feld träfe bei jedem Scan daneben.
  ///
  /// Nullbar und ohne Vorgabewert: Vor dem Seed gab es keine Herkunft,
  /// die einen Schlüssel hätte.
  TextColumn get quelleSchluessel =>
      text().named('quelle_schluessel').nullable()();
}

/// Die Portionen eines Lebensmittels — „Portion" und „Packung" aus Open
/// Food Facts, eigene wie „Bon" oder „Schale" (Schema v12 mit Schlüssel,
/// Spalten seit Schema v17, #393).
///
/// **Die Portion ist Vorlage, nicht Tatsache.** Ein gebuchter Eintrag
/// merkt sich Name und Gramm als Schnappschuss ([Eintraege.portionName],
/// [Eintraege.portionG]) und liest sie nie von hier. Eine umbenannte oder
/// gelöschte Portion ändert keinen Eintrag.
///
/// **Kein Index**, auch nicht über [lebensmittelId]: `_reconcileSchema`
/// kennt Tabellen und Spalten, keine Indizes. Ein Index stünde auf
/// manchen Geräten und auf anderen nicht — dieselbe Abwägung wie bei
/// `lebensmittel.barcode`.
@DataClassName('PortionRow')
class Portionen extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Das Lebensmittel, zu dem die Portion gehört — **ohne
  /// Fremdschlüssel**, wie [Eintraege.lebensmittelId].
  ///
  /// Nullbar ist sie nur, weil sie nachgetragen wird: SQLite lehnt
  /// `ADD COLUMN … NOT NULL` ohne Vorgabewert ab, und für eine
  /// Lebensmittel-ID gibt es keinen ehrlichen. Das Repository schreibt
  /// immer eine ID und liest nur Zeilen mit ID.
  IntColumn get lebensmittelId =>
      integer().named('lebensmittel_id').nullable()();

  /// Wie die Portion heißt, etwa „Portion", „Packung", „Bon" oder
  /// „Schale".
  ///
  /// **`NOT NULL` mit Vorgabewert `''`**, wie `lebensmittel.name`: Der
  /// leere Name ist das Eingeständnis, dass keiner dasteht, und der
  /// Vorgabewert macht die Spalte nachtragbar (Dateikopf).
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Die Menge je Portion **in der Einheit des Lebensmittels**
  /// (`fluessig`), nach derselben Konvention wie [Eintraege.mengeG] —
  /// nullbar und ohne Vorgabewert.
  ///
  /// Eine Vorgabe `0` wäre eine Portion von 0 g. Gelesen werden nur Zeilen
  /// mit `menge_g > 0`, denn eine Portion ohne Gramm ist keine.
  RealColumn get mengeG => real().named('menge_g').nullable()();

  /// Woher die Portion stammt: `'eigen'` oder `'off'`, als Wort wie bei
  /// [Lebensmittel.herkunft].
  ///
  /// **`NOT NULL` mit Vorgabewert `'eigen'`.** Vor v17 gab es keinen Weg
  /// aus Open Food Facts in diese Tabelle.
  TextColumn get herkunft => text().withDefault(const Constant('eigen'))();
}

/// Ein gebuchter Eintrag: was zu welcher Mahlzeit auf dem Teller lag
/// (Schema v12).
///
/// **Die einzige der fünf Tabellen, deren Spalten jetzt schon feststehen**
/// — `schema_v12_test.dart` legt sie fest, weil Task 3 sie schreibt und
/// liest. Der Werttyp dazu ist `Eintrag` in `ernaehrung_repository.dart`.
///
/// ## Eingefrorene Nährwerte, kein Verweis
///
/// Die acht Nährwertspalten und [extra] halten die Zahlen, die **beim
/// Buchen galten**. Das Lebensmittel ist Vorlage, der Eintrag ist
/// Tatsache: Zwei Einträge desselben Lebensmittels dürfen verschiedene
/// Werte tragen, und ein Eintrag bleibt vollständig lesbar, wenn seine
/// Vorlage längst weg ist. Wer stattdessen über einen Verbund liest,
/// verliert genau dann den Eintrag — und der Januar sähe nach jeder
/// Korrektur anders aus als damals.
///
/// ## Fehlende Werte sind `null`, nie `0`
///
/// Jede Nährwertspalte ist nullbar. Ein Lebensmittel ohne
/// Ballaststoffangabe hat keine 0 g Ballaststoffe, sondern keine Angabe;
/// `#232` („Mahlzeit mit fehlendem Nährwert erscheint mit 0 kcal") ist
/// genau dieser Fehler in der Altapp. Eine **gewogene** Null bleibt
/// dagegen `0` — Mineralwasser hat 0 kcal, und das ist eine Messung.
@DataClassName('EintragRow')
class Eintraege extends Table {
  /// Der Schlüssel, **mit `AUTOINCREMENT`** und nicht bloß
  /// `INTEGER PRIMARY KEY`.
  ///
  /// Ohne `AUTOINCREMENT` vergibt SQLite nach einer Löschung dieselbe
  /// Zeilennummer erneut. Der Health-Nachlauf merkt sich die IDs offener
  /// Einträge und ruft später `setzeHealthStand(id, …)` — eine
  /// wiederverwendete ID setzte den Stand eines **fremden** Eintrags, und
  /// zwar lautlos. `drift`s `autoIncrement()` schreibt genau diese Form.
  IntColumn get id => integer().autoIncrement()();

  /// Der **Esstag** als ISO-Tagesschlüssel (`YYYY-MM-DD`), wie
  /// `TagesWerte.tag` — nicht der Kalendertag von [zeitpunkt].
  ///
  /// Der Abend läuft bis 03:59 und umschließt Mitternacht
  /// (`Mahlzeitfenster`): Ein Eintrag um 01:30 gehört zum Abend davor.
  /// Die beiden Felder weichen dann um einen Tag voneinander ab, und
  /// genau deshalb gibt es beide. Gefiltert wird über **diese** Spalte,
  /// lexikografisch und damit über jede Zeitumstellung hinweg
  /// (`CLAUDE.md`, „Der Datumsschlüssel ist der ISO-Tagesstring").
  TextColumn get tagesSchluessel => text().named('tages_schluessel')();

  /// `Mahlzeit.name` — `fruehstueck`, `mittag`, `snack` oder `abend`.
  ///
  /// Der **Name**, nicht der Index: Eine abgelegte Ordnungszahl
  /// verschiebt sich lautlos, sobald jemand die Reihenfolge der
  /// Enum-Fälle ändert — dieselbe Regel, nach der
  /// `SchlafAbschnitte.phase` den `SleepStage.name` trägt. Und auf dem
  /// iPhone liegt Tims einzige Kopie.
  TextColumn get mahlzeit => text()();

  /// Wann gegessen wurde, als UTC-Zeitpunkt.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT. Drifts Standard (Unix-Sekunden) gäbe den Zeitpunkt als
  /// **lokale** Zeit zurück, und ein als UTC abgelegter Wert wäre danach
  /// ungleich sich selbst (`CLAUDE.md`).
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Die Vorlage, aus der der Eintrag entstand — **nullbar**.
  ///
  /// Der Schnelleintrag „nur Kalorien" hat keine (Entwurf, „Schnelleintrag
  /// und Favoriten"), und jede Abfrage muss das aushalten. Bewusst **ohne
  /// Fremdschlüssel**: Ein Eintrag bleibt gültig, wenn seine Vorlage
  /// gelöscht wird; er ist Tims Tatsache, nicht ihr Anhängsel.
  IntColumn get lebensmittelId =>
      integer().named('lebensmittel_id').nullable()();

  /// Was auf dem Teller lag, als Text — auch der Schnelleintrag trägt
  /// einen Namen. Eingefroren wie die Nährwerte: Eine spätere Korrektur
  /// der Vorlage benennt den gebuchten Eintrag nicht um.
  TextColumn get name => text()();

  /// Die gegessene Menge in Gramm — **nullbar**.
  ///
  /// Der Schnelleintrag trägt „einen Namen und seine eingefrorenen
  /// Nährwerte und sonst nichts"; er wiegt nichts. Eine
  /// `NOT NULL`-Spalte zwänge dort zu einer `0`, und „0 g gegessen" ist
  /// eine Behauptung, kein fehlender Wert (`CLAUDE.md`, „`0` ist keine
  /// Antwort auf ‚kein Wert'").
  ///
  /// `RealColumn`, nicht `IntColumn`: 33,5 g sind eine Menge, und Runden
  /// wäre eine stille Veränderung von Tims Wert.
  RealColumn get mengeG => real().named('menge_g').nullable()();

  /// Die acht eingefrorenen Nährwerte — `Naehrwerte` im Kern, acht
  /// `double?`, also acht nullbare `RealColumn`.
  RealColumn get kcal => real().nullable()();
  RealColumn get eiweissG => real().named('eiweiss_g').nullable()();
  RealColumn get kohlenhydrateG =>
      real().named('kohlenhydrate_g').nullable()();
  RealColumn get fettG => real().named('fett_g').nullable()();
  RealColumn get zuckerG => real().named('zucker_g').nullable()();
  RealColumn get ballaststoffeG =>
      real().named('ballaststoffe_g').nullable()();
  RealColumn get gesaettigtG => real().named('gesaettigt_g').nullable()();
  RealColumn get wasserMl => real().named('wasser_ml').nullable()();

  /// Die übrigen Nährwerte als JSON-Objekt — die 26 Mikronährstoffe des
  /// Austauschformats. So ist der spätere Vitamin-Schirm eine Ansicht und
  /// keine Migration.
  ///
  /// **`NOT NULL` mit Vorgabewert `{}`, nicht nullbar.** `Naehrwerte.extra`
  /// ist eine nicht-nullbare Map; das leere Objekt ist ihr genaues Abbild.
  /// Wäre die Spalte nullbar, gäbe es zwei Schreibweisen für „keine
  /// weiteren Werte" — dieselbe Überlegung, aus der `SchlafEintraege.notiz`
  /// genau eine hat. Der Vorgabewert erlaubt außerdem, die Spalte auf
  /// einer Datei nachzutragen, in der die Tabelle von einem anderen Zweig
  /// schon steht (#233).
  ///
  /// **Ein Schlüssel mit Wert `null` bleibt drin.** „Bekannt als
  /// unbekannt" ist eine andere Auskunft als „nie gefragt"; das
  /// Austauschformat 4.11 schreibt in der Exportdatei `0` für nicht
  /// erfasste Werte, und das ist die Regel für die **Datei**, nicht für
  /// die Datenbank.
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  /// Die UUID der Probe in Apple Health — **nullbar**: Die kennt erst, wer
  /// geschrieben hat. Gebucht wird aber immer, auch ohne Freigabe.
  TextColumn get healthUuid => text().named('health_uuid').nullable()();

  /// Was aus der Kopie nach Apple Health geworden ist: `offen`,
  /// `geschrieben` oder `nicht_moeglich` (Entwurf, „Wenn die
  /// Schreibfreigabe fehlt").
  ///
  /// `NOT NULL` — jeder Eintrag hat einen der drei Stände, ein leeres Feld
  /// wäre ein vierter, unbenannter. Als **Wort**, nicht als Ordnungszahl,
  /// aus demselben Grund wie bei [mahlzeit].
  ///
  /// **Der Vorgabewert `offen` ist keine Erfindung, sondern die Wahrheit
  /// über eine Zeile, deren Stand niemand festgehalten hat:** Sie ist
  /// nicht nach Health geschrieben worden. Er macht die Spalte zugleich
  /// nachtragbar (#233) — anders als [name] oder [tagesSchluessel], für
  /// die es keinen ehrlichen Vorgabewert gibt.
  TextColumn get healthStand =>
      text().named('health_stand').withDefault(const Constant('offen'))();

  /// Die Herkunft eines gebuchten KI-Vorschlags als JSON (Schema v15,
  /// #332) — `{"anbieter":"gemini","modell":…,"zeitpunkt":…,
  /// "zweck":"foto"}`.
  ///
  /// **Nullbar und ohne Vorgabewert.** Ein von Hand gebuchter Eintrag hat
  /// keine KI-Herkunft, und eine Vorgabe wäre eine Herkunft, die jeder
  /// Eintrag erbte. Alte Zeilen bleiben `null` — eine Migration erfindet
  /// keine Herkunft.
  TextColumn get vorschlag => text().nullable()();

  /// Die Portion, mit der gebucht wurde (Schema v17, #393) — **ohne
  /// Fremdschlüssel**. Über sie findet die Vorwahl die Portion wieder,
  /// auch nachdem sie umbenannt wurde.
  ///
  /// Darf `null` sein, während [portionName] und [portionG] gesetzt sind:
  /// Die Portion hatte beim Buchen keine Zeile in [Portionen]. Die Vorwahl
  /// fällt dann auf „g" zurück.
  IntColumn get portionId => integer().named('portion_id').nullable()();

  /// Name und Gramm der Portion als **Schnappschuss beim Buchen**,
  /// eingefroren wie die Nährwerte (Schema v17, #393). Ändern-Blatt und
  /// Mahlzeitenzeile lesen sie von hier, nie aus [Portionen].
  ///
  /// Beide stehen nur gemeinsam da. **Ohne Portion gebucht heißt: alle drei
  /// `null`** — das gilt auch für jeden alten Eintrag, und es stimmt, denn
  /// alle alten Einträge sind in Gramm gebucht. Kein Vorgabewert: Ein
  /// `portion_g` von `0` wäre eine Portion von 0 g statt „ohne Portion".
  ///
  /// **Keine Spalte für die Anzahl.** Sie ist `menge_g / portion_g`, und
  /// eine zweite Spalte könnte der ersten widersprechen. Kein Index.
  TextColumn get portionName => text().named('portion_name').nullable()();
  RealColumn get portionG => real().named('portion_g').nullable()();

  /// Ob in Millilitern gebucht wurde — ein **Schnappschuss** von
  /// [Lebensmittel.fluessig] beim Buchen (Schema v19, #403), eingefroren
  /// wie die Nährwerte. Wird die Vorlage später fest oder flüssig gestellt
  /// oder gelöscht, bleibt die Einheit des Eintrags.
  ///
  /// **Nullbar und ohne Vorgabewert.** `NULL` heißt „unbekannt" — so steht
  /// es in jedem Eintrag von vor der Stufe 20, und die Anzeige fällt dann
  /// auf die Vorlage zurück. Eine Vorgabe `0` behauptete für jedes alte
  /// Getränk „in Gramm gebucht". Kein Index.
  BoolColumn get fluessig => boolean().nullable()();
}

/// Ein Rezept (Schema v12) — Name, Portionen, Bild und das gewogene
/// Topfgewicht gehören **Task 8**.
@DataClassName('RezeptRow')
class Rezepte extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Die Sync-Identität neben der Autoincrement-ID (Schema v25, #542).
  /// Begründung und Form wie bei [Lebensmittel.uuid]; geteilt werden
  /// später beide, Vorlagen wie Rezepte.
  TextColumn get uuid => text().nullable()();

  /// Wann das Rezept zuletzt geändert wurde (Schema v25, #542) — wie
  /// [Lebensmittel.geaendertAm].
  DateTimeColumn get geaendertAm =>
      dateTime().named('geaendert_am').nullable()();

  /// Der Löschmarker (Schema v25, #542) — wie [Lebensmittel.geloeschtAm].
  DateTimeColumn get geloeschtAm =>
      dateTime().named('geloescht_am').nullable()();

  /// Wer das Rezept angelegt hat (Schema v25, #542) — wie
  /// [Lebensmittel.autor].
  TextColumn get autor => text().nullable()();
}

/// Eine Zutat eines Rezepts (Schema v12) — Rezept, Lebensmittel, Menge und
/// Einheit gehören **Task 8**.
@DataClassName('RezeptZutatRow')
class RezeptZutaten extends Table {
  IntColumn get id => integer().autoIncrement()();
}
