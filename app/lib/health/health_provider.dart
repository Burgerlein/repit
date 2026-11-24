// Die Provider-Schicht aus Task 13 — der Punkt, an dem Tims gemeldeter
// Fehler verschwindet (#55, „Das Schritte-Detail hängt"): „Er sieht
// beim Start seine Schritte, navigiert herum, kommt zurück — und dort steht
// 0." Drei bereits gebaute Teile laufen hier zusammen (Spec 5.5 in
// `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md`):
// `Messwert<T>`/`alsMesswert` (Task 5), `CacheRepository`/`AppCache`
// (Task 6/13), `HealthReading` (Task 7/12).
//
// API und Verhalten sind durch `app/test/health/health_provider_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung) — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Nachtrag #113 (27.10.2026): `sleepProvider` ist jetzt gebaut.** Er
// fehlte, weil die Umbau-Spec für Schlaf weder Cache-Tabelle noch
// Ladereihenfolge festlegte — „wer ihn anlegt, entscheidet beides". Beides
// ist mit #113 entschieden: die Cache-Tabellen in `lib/data/tables.dart`
// (`Naechte`/`SchlafAbschnitte`, Schema v3), die Ladereihenfolge als die
// **wörtlich gleiche** wie bei `dailyMetricsProvider`. Ein zweiter Ladeweg
// neben dem bestehenden wäre eine zweite Stelle, an der Tims Fehler
// („Ladezustand als Leerstand") neu entstehen könnte; die Begründung jedes
// einzelnen Schritts steht deshalb nur einmal, unten bei
// `DailyMetricsNotifier`, und gilt für `SleepNotifier` unverändert.
//
// `workoutsProvider` und `nutritionProvider` aus `task-13-brief.md` fehlen
// weiterhin bewusst: Für sie gibt es keine Cache-Tabelle und kein Ticket,
// das eine entscheidet. Sie auf Verdacht zu bauen hieße, eine ungeprüfte
// Cache-Strategie für sie festzuschreiben. Siehe `task-13-report.md` für
// die ausführliche Begründung. Die Stundenschritte haben seit #84 ihren
// Provider ([stundenSchritteProvider], unten) — ohne drift-Cache, siehe
// dort.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` wurde in Riverpod 3 nach `legacy.dart` verschoben (nicht
// entfernt — weiterhin der richtige Baustein für einen schlichten
// veränderlichen Wert wie `DataWindow`, nur kein Teil des Hauptexports mehr).
import 'package:flutter_riverpod/legacy.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/async_bruecke.dart';
import '../core/messwert.dart';
import '../data/cache.dart';
import '../data/cache_repository.dart';
import 'health_reading.dart';
import 'health_types.dart';

/// Einzige Quelle für Gesundheitsdaten. Wirft ohne Override — nur
/// `main.dart` liefert die echte `HealthChannel`-Instanz (Spec 5). Jeder
/// Test überschreibt diesen Provider mit einer Fake-Quelle.
final healthProvider = Provider<HealthReading>(
  (ref) => throw UnimplementedError(
    'healthProvider muss in main.dart mit der echten HealthChannel-Instanz '
    'überschrieben werden.',
  ),
);

/// Die Lesefreigabe für Apple Health — **genau einmal pro Sitzung
/// angefragt**, und von jedem Lauf abgewartet, bevor er den Kanal fragt
/// (#183).
///
/// **Warum das hier steht und nicht auf einem Schirm:** Bis zum 02.11.2026
/// lief `requestAuthorization()` ausschließlich auf *Mehr ›
/// HealthKit-Test*. Wer diesen Diagnoseschirm nie öffnete, wurde nie
/// gefragt — und Apple liefert ohne Freigabe eine **leere Antwort ohne
/// Fehler**. Die Schirme sagten dann „nichts aufgezeichnet oder nicht
/// freigegeben", obwohl die App nur hätte fragen müssen. Genau so hat Tim
/// es am 02.11.2026 auf dem iPhone gesehen.
///
/// **Ein Dialog pro Installation** (`CLAUDE.md`): Der Provider hält sein
/// Ergebnis, also fragt auch ein zweiter, dritter Leser nicht erneut. Dass
/// iOS den Dialog beim zweiten Aufruf ohnehin nicht noch einmal zeigt,
/// ändert daran nichts — wir verlassen uns nicht darauf.
///
/// **Der erklärende Willkommensschritt fehlt noch.** Ein Systemdialog ist
/// eine Zusage, und der Nutzer sieht ihn einmal; der Entwurf dafür liegt
/// in `docs/screens/screens/erststart.js`. Tim hat am 02.11.2026
/// entschieden, zuerst den Zugriff zu bauen und den Schirm danach.
///
/// Die Anfrage selbst steht weiter unten: der beobachtbare Stand in
/// [freigabeProvider], der Auslöser in [freigabeAnfrageProvider].

/// Der drift-Cache auf der Platte. Wirft ohne Override — nur `main.dart`
/// liefert die über `AppCache.oeffnen()` geöffnete Instanz. Jeder Test
/// überschreibt diesen Provider mit einer In-Memory-`AppCache`.
final appCacheProvider = Provider<AppCache>(
  (ref) => throw UnimplementedError(
    'appCacheProvider muss in main.dart mit der über AppCache.oeffnen() '
    'geöffneten Instanz überschrieben werden.',
  ),
);

/// Die Lese-/Schreib-Brücke zu `TagesWerte`, siehe `cache_repository.dart`.
final cacheRepositoryProvider = Provider<CacheRepository>(
  (ref) => CacheRepository(ref.watch(appCacheProvider)),
);

/// Der Betrachtungszeitraum (Spec 5.2/5.7). Noch nicht an die persistente
/// Einstellung aus Task 11 (`DataWindowSettings`) angebunden — das ist eine
/// spätere Aufgabe, dieser Provider ist hier nur die Stelle, an der
/// `dailyMetricsProvider` seine Abhängigkeit bekommt. Default: kein Fenster.
final dataWindowProvider = StateProvider<DataWindow>(
  (ref) => DataWindow.unlimited,
);

/// Injizierbare Uhr, Gegenstück zum `jetzt`-Parameter von `alsMesswert`
/// (Spec 5.3b: deterministisch testbar, nie `DateTime.now()` direkt
/// aufrufen). Als Funktion, nicht als fester `DateTime`-Wert, damit sie bei
/// jedem Lauf frisch ausgewertet wird, nicht einmal pro Container
/// eingefroren ist.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Der Berliner Kalendertag, auf den die App gerade rechnet, als
/// Tagesbeginn (`BerlinCalendar.startOfDay`).
///
/// **Warum ein eigener Provider und nicht `clockProvider`:** Riverpod
/// rechnet Abgeleitetes neu, wenn sich eine **Abhängigkeit** ändert.
/// `clockProvider` trägt eine Funktion, und die ändert sich nie — wer den
/// Tag aus ihr zieht, friert ihn auf den Tag des ersten Zugriffs ein.
/// Läuft eine Sitzung über Mitternacht, rechnen Ampel und Diagramm weiter
/// auf dem Vortag und der Kanal wird mit einer Obergrenze von gestern
/// gefragt: die Nacht, die gerade hinter Tim liegt, kommt nie an. Das ist
/// Fehler `01` in einer weiteren Verkleidung.
///
/// Umgekehrt wäre ein Provider, der die **Uhrzeit** trägt, Fehler `03`:
/// jede Sekunde ein neuer Wert, jedes Bild eine neue Rechnung. Dieser hier
/// ist das Dazwischen — er ändert sich **nur** beim Kalendertagswechsel.
///
/// **Ein Begriff, ein Provider.** `rechenfensterProvider`,
/// `SleepNotifier` und `DailyMetricsNotifier` beobachten ihn; zwei
/// Stellen, die unabhängig voneinander bestimmen,
/// welcher Tag heute ist, waren genau die Bauart, aus der die Befunde C
/// und G entstanden sind.
///
/// `clockProvider` bleibt, wo er ist: Innerhalb eines Laufs wird weiter die
/// genaue Uhrzeit gebraucht (`jetzt` als obere Kanalgrenze, `gelesenAm` als
/// Stand).
final heutigerTagProvider = NotifierProvider<HeutigerTagNotifier, DateTime>(
  HeutigerTagNotifier.new,
);

class HeutigerTagNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => BerlinCalendar.startOfDay(ref.watch(clockProvider)());

  /// Liest die Uhr neu. Hat sich der Berliner Kalendertag geändert, ändert
  /// sich der Zustand — und alles, was ihn beobachtet, rechnet neu. Ist es
  /// derselbe Tag, passiert **nichts**: Eine Prüfung, die nichts findet,
  /// darf nichts auslösen, sonst fragt die App den Kanal bei jedem Tick neu.
  ///
  /// **Wer das aufruft, entscheidet die Widget-Schicht** —
  /// App-Lebenszyklus, Ticker, `WidgetsBindingObserver`. Hier steht nur der
  /// Weg, nicht wer ihn geht.
  void pruefeTageswechsel() {
    final heute = BerlinCalendar.startOfDay(ref.read(clockProvider)());
    if (heute != state) state = heute;
  }
}

/// Wie lange ein Lauf gilt, bevor die Rückkehr der App nach vorn einen
/// neuen anstößt (#309).
///
/// **Eine Entscheidung, keine Ableitung** (Tim, 04.11.2026) — deshalb
/// steht sie als benannte Konstante hier und nicht als Zahl mitten in
/// einer Bedingung: Wer sie ändern will, soll sie nicht suchen müssen.
///
/// **Warum eine Viertelstunde.** Nach unten begrenzt sie der Preis eines
/// Laufs: dreißig Tage über alle Typen, beim Puls Zehntausende Proben.
/// Bei *jeder* Rückkehr zu fragen hieße, für jeden Blick in eine andere
/// App einen vollen Lauf zu bezahlen — und der kurze Wechsel (eine
/// Nachricht beantworten, in den Kalender schauen) dauert Sekunden bis
/// wenige Minuten. Nach oben begrenzt sie der Fall, der dieses Ticket
/// ausgelöst hat: Der Schlaf der vergangenen Nacht wächst am Morgen noch
/// stundenlang weiter, und wer um 09:04 nachsieht, soll nicht den Stand
/// von 06:45 lesen. Eine Viertelstunde lässt höchstens vier Läufe je
/// Stunde zu und hält den Vormittag trotzdem aktuell.
const nachlaufSchwelle = Duration(minutes: 15);

/// Der zweite Anstoß neben dem Tageswechsel: Kommt die App nach vorn und
/// ist der letzte Lauf länger her als [nachlaufSchwelle], laufen die
/// Lade-Provider neu (#309).
///
/// **Warum es ihn braucht:** `pruefeTageswechsel()` tut nur etwas, wenn
/// sich der *Tag* geändert hat. Am selben Tag aus dem Hintergrund
/// zurückzukehren ließ bis hierher keinen einzigen Provider neu rechnen;
/// gelesen wurde nur beim Kaltstart und um Mitternacht. Am 04.11.2026
/// zeigte die App deshalb 6:18 h Schlaf, während Apple Health 7:53 h
/// hatte — die Rechnung war unschuldig, die App hatte nur nie gefragt.
///
/// **Kein eigener Zeitstempel.** Wann zuletzt gelaufen wurde, steht schon
/// in der Ausgabe der Lade-Provider (`Bekannt.stand` — die Zahl, die die
/// Stand-Zeile anzeigt). Ein zweiter Zeitstempel daneben wären zwei
/// Stellen, die dasselbe wissen, und die laufen auseinander. Der Zustand
/// hier ist deshalb nur ein Zähler: wie viele Nachläufe seit dem Start
/// angestoßen wurden. Er ist der beobachtbare Beleg dafür, dass es
/// passiert ist, und sonst nichts.
///
/// **Angestoßen mit `ref.invalidate(...)`, nicht beobachtet.** Ein von den
/// Lade-Providern beobachteter Wert wäre die schönere Richtung — nur kann
/// dieser Notifier dann ihren Stand nicht mehr lesen, ohne den er gar
/// nicht entscheiden kann: Riverpod erkennt das als Kreis
/// (`CircularDependencyError`), und zwar zu Recht. Also zeigt der Pfeil
/// hierher herum, und der Preis steht in der Liste unten: Wer einen
/// vierten Lade-Provider baut, trägt ihn dort nach. Dass dieser Preis
/// echt ist, zeigt `_NeuLadenKnopf` in `shell/healthkit_test_view.dart` —
/// er kennt `nachtWerteProvider` bis heute nicht.
final nachlaufProvider = NotifierProvider<NachlaufNotifier, int>(
  NachlaufNotifier.new,
);

class NachlaufNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Die Provider, die den Kanal fragen — **die eine Liste**, die beim
  /// Bau eines vierten nachzutragen ist.
  static final _ladeProvider = [
    dailyMetricsProvider,
    sleepProvider,
    nachtWerteProvider,
  ];

  /// Stößt einen neuen Lauf an — **nur**, wenn der letzte lange genug her
  /// ist und gerade keiner unterwegs ist. Trifft eine der Bedingungen
  /// nicht zu, passiert **nichts**: kein neuer Zustand, keine
  /// Benachrichtigung, nichts, was neu rechnet.
  ///
  /// **Wer das aufruft, entscheidet die Widget-Schicht** — hier steht wie
  /// bei [HeutigerTagNotifier.pruefeTageswechsel] nur der Weg, nicht wer
  /// ihn geht. Heute geht ihn `shell/tageswacht.dart`, und zwar
  /// **unmittelbar vor** `pruefeTageswechsel()`. Diese Reihenfolge ist
  /// Teil der Abmachung, siehe den Tageswechsel-Wächter unten.
  void pruefeNachlauf() {
    final jetzt = ref.read(clockProvider)();

    // **Der Tageswechsel hat Vorrang.** Ist inzwischen ein Berliner
    // Kalendertag vergangen, rechnet gleich ohnehin alles neu — der Ruf,
    // der das auslöst, folgt unmittelbar auf diesen hier. Ein Anstoß von
    // hier wäre dann ein zweiter neben dem, der sowieso kommt.
    if (BerlinCalendar.startOfDay(jetzt) != ref.read(heutigerTagProvider)) {
      return;
    }

    // **Nur Provider, die es schon gibt.** Wer keinen Leser hat, zeigt
    // nichts an, das veralten könnte — und ihn hier anzufassen, legte ihn
    // an und löste genau den Lauf aus, den die Schwelle verhindern soll.
    final lebende = _ladeProvider.where(ref.exists).toList();

    DateTime? letzter;
    for (final provider in lebende) {
      final zeit = _letzterLauf(ref.read(provider));
      // **Kein zweiter Lauf neben einem laufenden.** `null` heißt „kein
      // abgeschlossener Lauf, dessen Zeit man nennen könnte" — es läuft
      // gerade einer, oder es lief noch nie einer. Beides ist ein Grund,
      // nichts zu tun: Ein zweiter Lauf käme keine Sekunde früher an, er
      // nähme dem ersten nur seinen Platz weg.
      if (zeit == null) return;
      if (letzter == null || zeit.isAfter(letzter)) letzter = zeit;
    }
    // **Der jüngste gewinnt** — „der letzte Lauf" ist der letzte, nicht
    // der älteste. Die drei laufen ohnehin gemeinsam los; liefen sie
    // einmal auseinander, ist der vorsichtigere Wert der richtige.
    if (letzter == null) return;
    if (jetzt.difference(letzter) < nachlaufSchwelle) return;

    state = state + 1;
    for (final provider in lebende) {
      ref.invalidate(provider);
    }
  }
}

/// Der Zeitpunkt des letzten **abgeschlossenen** Laufs eines
/// Lade-Providers — dieselbe Zahl, die die Stand-Zeile anzeigt
/// (`design/stand_zeile.dart`), und deshalb keine zweite Buchführung.
///
/// `null` heißt „gerade unterwegs oder noch nie gelaufen".
///
/// **Zwei Ladesignale, nicht eines.** Ohne Cache steht bis zum Ende des
/// Laufs Riverpods eigenes `AsyncLoading`. Mit Cache gibt der Provider
/// schon mitten im Lauf aus (`Bekannt(…, laeuft: true)`, „zuerst der
/// Cache, dann HealthKit") — dann ist `laeuft` das Signal und nicht
/// `isLoading`.
///
/// **Ein alter Stand nach einem leeren oder gescheiterten Lauf ist kein
/// Fehler dieser Funktion.** Ein Lauf, der nichts bringt, schreibt den
/// Cache nicht fort (#224), der Stand bleibt also stehen — und dann ist
/// Nachfragen bei der nächsten Rückkehr genau richtig, denn seit diesem
/// Stand hat kein Lauf etwas Neues gesehen.
DateTime? _letzterLauf(AsyncValue<Messwert<Object?>> ausgabe) {
  if (ausgabe.isLoading) return null;
  return switch (ausgabe.value) {
    // Der Rumpf selbst hat geworfen — die drei Lade-Provider fangen ihre
    // Kanal-Fehler ab, hierher kommt also nur ein Fehler des Ladewegs.
    // Auch das ist kein Lauf mit einer Zeit, die man nennen könnte.
    null => null,
    Bekannt(laeuft: true) => null,
    Bekannt(:final stand) => stand,
    LeerNachLauf(:final gelaufen) => gelaufen,
    Fehlgeschlagen(:final gelaufen) => gelaufen,
    // `alsMesswert` gibt `NochNie` nur aus, solange geladen wird.
    NochNie() => null,
  };
}

/// Ob der eine HealthKit-Freigabedialog dieser Installation beantwortet
/// ist.
///
/// Zwei Werte statt eines `bool`, weil „ungefragt" **nicht** „abgelehnt"
/// heißt: Apple verrät den Lesestatus nicht (`CLAUDE.md`). Die App weiß
/// nie, ob freigegeben wurde — nur, ob eine Antwort vorliegt.
enum Freigabestand {
  /// Noch kein Dialog. Der Zustand beim Start; die App erzwingt keinen.
  ungefragt,

  /// Der Dialog ist durch. Was angetippt wurde, weiß niemand; bekannt ist
  /// nur, dass ein Lesezugriff ab jetzt etwas anderes liefern kann als
  /// vorher.
  beantwortet,
}

/// Der Stand der einen Freigabe (#176).
///
/// **Warum die Lade-Provider das beobachten:** iOS fragt beim **ersten
/// Lesezugriff**, nicht beim Start. Dieser erste Zugriff läuft also vor
/// der Antwort und kommt leer zurück — ohne Lesefreigabe liefert Apple
/// Health keine Probe, die Abfrage scheitert nicht. Danach änderte sich
/// nichts, was Riverpod sehen konnte: Kein `watch` zeigte auf die
/// Freigabe, also rechnete kein Provider neu, und das leere Ergebnis
/// stand bis zum nächsten `ProviderContainer` — also bis zum nächsten
/// App-Start. Genau das war Tims Befund vom 29.10.2026.
final freigabeProvider = NotifierProvider<FreigabeNotifier, Freigabestand>(
  FreigabeNotifier.new,
);

/// Hält den Stand und fragt **auf Verlangen** nach, nicht von selbst:
/// `build()` hat keine Nebenwirkung, ein `ref.watch(freigabeProvider)`
/// löst also keinen Dialog aus. Nur so können die Lade-Provider den Stand
/// beobachten, ohne den Dialog in den App-Start zu ziehen — wo er
/// heute nicht hingehört und über den niemand entschieden hat.
class FreigabeNotifier extends Notifier<Freigabestand> {
  @override
  Freigabestand build() => Freigabestand.ungefragt;

  /// Fragt die Freigabe an und meldet die Antwort weiter — alles, was
  /// [freigabeProvider] beobachtet, läuft danach neu.
  ///
  /// Ein zweiter Aufruf nach beantworteter Freigabe tut nichts. Das spart
  /// den Weg über den Kanal; dass es **genau einen** Dialog pro
  /// Installation gibt, entscheidet iOS und nicht diese Zeile.
  ///
  /// Scheitert die Anfrage, bleibt der Stand `ungefragt` und der Fehler
  /// geht an den Aufrufer. Ein Nachlauf findet dann nicht statt — es hat
  /// sich auch nichts geändert, das einen rechtfertigte.
  Future<void> frageEinmal() async {
    if (state == Freigabestand.beantwortet) return;
    await ref.read(healthProvider).requestAuthorization();
    state = Freigabestand.beantwortet;
  }
}

/// Löst die eine Freigabe-Anfrage aus. Beobachtet wird er von den
/// **Schirmen**, nicht von den Lade-Providern: `HeuteView` (#183, der
/// erste Schirm nach dem Start) und `HealthKitTestView`.
///
/// **Warum nicht in den Lade-Providern**, wo der Lesezugriff ja
/// stattfindet: Diese Anfrage setzt den Stand aus [freigabeProvider], und
/// genau den beobachten `DailyMetricsNotifier` und `NachtWerteNotifier`
/// (#176). Ein Auslöser dort verwürfe mit seiner eigenen Antwort den Lauf,
/// der auf ihn wartet — der Lauf wird während des Ladens entsorgt und gibt
/// nie einen Wert aus. Gemessen am 03.11.2026 beim Zusammenführen (#251):
/// 36 rote Fälle in `test/health` mit Auslöser, 117 grüne ohne.
///
/// Dass ein reiner Lesezugriff **keinen** Dialog auslöst, ist deshalb
/// Zusage und nicht Zufall; `test/shell/healthkit_freigabe_test.dart`
/// bewacht sie.
///
/// Ein gewöhnlicher, nicht-autoDispose-Provider: Sein Rumpf läuft beim
/// allerersten `watch` und danach nie wieder, gleich wie oft der Schirm
/// neu baut oder verlassen und wieder geöffnet wird.
final freigabeAnfrageProvider = FutureProvider<void>(
  (ref) => ref.read(freigabeProvider.notifier).frageEinmal(),
);

/// Tageswerte aus Apple Health — **ein** Provider für alle Schirme (vorher:
/// `BodyStore` und `EnduranceStore` holten beide dieselben Tageswerte, siehe
/// Spec 5.1).
final dailyMetricsProvider =
    AsyncNotifierProvider<DailyMetricsNotifier, Messwert<List<DailyMetrics>>>(
      DailyMetricsNotifier.new,
    );

/// Setzt Spec 5.5 wörtlich um: `build()` liest zuerst den Cache, gibt sofort
/// einen Zwischenzustand aus, fragt dann den Kanal, schreibt das Ergebnis
/// zurück.
///
/// **Kein `guard !isLoading`, kein `if (state is Loading) return;`** — der
/// Swift-Fehler, den dieser Umbau beheben soll (Spec 5.1). Ein Provider ist
/// eine Instanz: Ein zweiter `ref.read(dailyMetricsProvider.future)`,
/// während dieser `build()`-Lauf noch läuft, hängt an genau derselben,
/// bereits laufenden Future — Riverpod leistet das selbst, ohne dass dieser
/// Code etwas dafür tun muss. Es gibt keinen zweiten Lauf, gegen den zu
/// schützen wäre, also auch keine Code-Zeile, die ihn verhindern müsste.
class DailyMetricsNotifier extends AsyncNotifier<Messwert<List<DailyMetrics>>> {
  @override
  Future<Messwert<List<DailyMetrics>>> build() async {
    // `ref` nur hier in `build` gelesen (Hausregel, Spec 5.4 Punkt 3) — drei
    // Abhängigkeiten, deren Änderung einen neuen Lauf auslösen soll
    // (`dataWindowProvider` tatsächlich beobachtet, siehe `DataWindow.==`
    // aus Task 4), zwei Werkzeuge, die während des Laufs gebraucht werden,
    // aber keinen eigenen Rebuild auslösen sollen (`healthProvider`,
    // `clockProvider` werden in Tests zwar auch überschrieben, ändern sich
    // in der echten App aber nie zur Laufzeit).
    final cacheRepo = ref.watch(cacheRepositoryProvider);
    final fenster = ref.watch(dataWindowProvider);
    // Beobachtet, nicht nur gelesen: Wechselt der Kalendertag, muss dieser
    // Lauf neu starten — sonst endet die obere Kanalgrenze weiter gestern
    // und die letzte Nacht kommt nie an.
    ref.watch(heutigerTagProvider);
    // Ebenso beobachtet, und aus demselben Grund: Ist die Freigabe
    // beantwortet, läuft dieser Lauf neu. Der Lauf davor fand ohne
    // Lesefreigabe statt und kam leer zurück; ohne diese Zeile stünde
    // dieses leere Ergebnis bis zum nächsten App-Start (#176).
    ref.watch(freigabeProvider);
    final uhr = ref.watch(clockProvider);
    final quelle = ref.watch(healthProvider);
    // **Angestoßen, nicht abgewartet** (#183 über #176): Bis hierher fragte
    // die App ausschließlich auf *Mehr › HealthKit-Test* nach der Freigabe
    // — wer den Schirm nie öffnete, wurde nie gefragt. Dieses `read` macht
    // den ersten Lesezugriff zum Auslöser.
    //
    // **Warum nicht `await`:** Die Antwort setzt den Stand, den die Zeile
    // darüber beobachtet. Ein `await` auf diese Future hinge an einem Lauf,
    // den ihr eigener Abschluss verwirft — der Lauf wird während des
    // Ladens entsorgt und die Future löst nie auf. Es braucht das `await`
    // auch nicht: Der beobachtete Stand holt den Lauf von selbst nach,
    // sobald der Dialog beantwortet ist. Der Lauf davor kommt leer zurück
    // — beim Erststart ohne Cache ist das `LeerNachLauf`, und genau dafür
    // gibt es ihn; liegt schon ein Cache vor, bleibt der stehen (#224).

    // Schritt 1: Cache lesen (schnell, auf dem DB-Isolate).
    final cacheZeile = await cacheRepo.liesTagesWerte(fenster);
    final cache = cacheZeile == null
        ? null
        : (wert: cacheZeile.werte, stand: cacheZeile.stand);

    // Schritt 2: sofort ausgeben, bevor der Kanal überhaupt gefragt wurde —
    // aber **nur, wenn es einen Cache gibt.** `alsMesswert` ist die
    // **einzige** Stelle, die `AsyncValue` in `Messwert` übersetzt
    // (Hausregel, Spec 5.4 Punkt 1) — auch hier für den Zwischenzustand,
    // nicht nur für das Endergebnis unten.
    //
    // **Warum nicht auch ohne Cache ausgeben (dann wäre es `NochNie`):**
    // Das ist kein Vertrags-Unterschied — `NochNie` UND „die Provider-Future
    // zeigt noch auf kein Ergebnis" bedeuten für jeden Beobachter dasselbe
    // (nichts Bekanntes bislang). Technisch ist es aber ein Unterschied:
    // Eine **manuelle** `state =`-Zuweisung während `build()` schließt bei
    // Riverpods `AsyncNotifier` die ursprüngliche, noch offene
    // `.future`-Vervollständigung endgültig ab (sie wird mit genau diesem
    // Zwischenwert erfüllt, nicht mit dem späteren Rückgabewert von
    // `build()`) — das ist Riverpods eigenes, dokumentiertes Verhalten
    // (`AsyncNotifier.future`: „If state is modified before build completes,
    // then future will resolve with that new state value."). Ohne Cache gibt
    // es nichts zu zeigen, das die zusätzliche Zuweisung rechtfertigt, und
    // sie würde jeden `ref.read(provider.future)`-Aufruf, der (wie bei zwei
    // gleichzeitigen Lesern, Pflichtfall 1/2) früh hereinkommt, unnötig auf
    // `NochNie` festnageln, statt auf das tatsächliche Endergebnis warten zu
    // lassen. **Mit** Cache nehmen wir diesen Kompromiss bewusst in Kauf
    // (siehe Bericht, Abschnitt zu Pflichtfall 3/„gescheiterter Nachlauf mit
    // Cache"): Ein `.future`-Leser, der schon vor dem Kanal-Ergebnis liest,
    // bekommt dann den Zwischenwert statt des Endergebnisses — das ist eine
    // bekannte, gemeldete Grenze dieses Ansatzes, keine vergessene.
    // **Erst fragen, dann lesen** (#183): Ohne Freigabe liefert Apple eine
    // leere Antwort ohne Fehler, und der Schirm behauptete dann „nichts
    // aufgezeichnet oder nicht freigegeben".
    //
    // **Hier und nicht später:** Zwischen dem Zwischenzustand unten und dem
    // Kanal darf kein `await` mehr liegen. Die manuelle `state`-Zuweisung
    // erfüllt die noch offene `.future` dieses Providers; wer darauf wartet,
    // wird dann geweckt, und ein `await` danach ließe ihn messen, bevor der
    // Kanal überhaupt gefragt wurde.
    //
    // **Ein Fehler hier hält den Lauf nicht auf.** Apple verrät den
    // Lesestatus ohnehin nicht; wer nach einer gescheiterten Anfrage gar
    // nicht erst liest, macht aus „vielleicht nichts da" ein sicheres
    // Nichts — und verlöre den Cache gleich mit.
    try {
    } catch (_) {
      // Bewusst verschluckt, siehe oben.
    }

    final jetzt = uhr();
    if (cache != null) {
      state = AsyncData(
        alsMesswert<List<DailyMetrics>>(
          const AsyncLoading(),
          cache: cache,
          jetzt: jetzt,
          istLeer: false,
        ),
      );
    }

    // Schritt 3: den Kanal fragen, mit einer Obergrenze von drei Versuchen.
    //
    // Riverpod wiederholt einen gescheiterten Provider standardmäßig von
    // selbst, mit wachsendem Abstand (Spec 5.3c) — das greift hier aber
    // nicht, weil dieser Codepfad den Fehler selbst abfängt und nie an
    // Riverpod zurückwirft (s.u., warum). Die Wiederholung muss deshalb hier
    // von Hand passieren, und zwar **begrenzt**: Eine verweigerte
    // HealthKit-Berechtigung sieht heute identisch aus wie ein
    // vorübergehender Fehler — der Kanal liefert dafür keinen eigenen
    // Fehlercode (siehe `health_channel.dart`). Ohne Obergrenze liefe die
    // App bei entzogener Freigabe endlos weiter und zeigte dauerhaft
    // `laeuft: true`/einen Platzhalter statt einer Aussage. Drei Versuche
    // fangen den vorübergehenden Fall ab; danach gilt das Ergebnis, und
    // `Fehlgeschlagen` darf sichtbar werden (sofern kein Cache einspringt,
    // s.u.). **Bewusst ohne künstliche Wartezeit zwischen den Versuchen:**
    // Eine entzogene Berechtigung scheitert bei jedem Versuch gleich
    // schnell und gleich sicher — eine Pause läge nur im Weg, ohne eine
    // echte vorübergehende Störung wahrscheinlicher zu beheben, und der
    // Nutzer sieht während der ganzen Zeit ohnehin schon `laeuft: true`
    // bzw. den Platzhalter.
    final von = fenster.queryStart(floor: quelle.earliestPermittedDate);
    const maxVersuche = 3;
    AsyncValue<List<DailyMetrics>> kanalErgebnis = const AsyncLoading();
    for (var versuch = 1; versuch <= maxVersuche; versuch++) {
      try {
        final werte = await quelle.dailyMetrics(von, jetzt);
        // Schritt 4 (Erfolg): zurückschreiben, `gelesenAm` je Zeile — die
        // Spalte aus Task 6 ist genau dafür da (Spec 5.3b).
        await cacheRepo.schreibeTagesWerte(werte, gelesenAm: jetzt);
        kanalErgebnis = AsyncData(werte);
        break;
      } catch (fehler, stack) {
        if (versuch >= maxVersuche) {
          kanalErgebnis = AsyncError(fehler, stack);
        }
        // sonst: nächster Versuch der Schleife.
      }
    }

    // Schritt 4 (Endergebnis): dieselbe eine Stelle wie beim Zwischenzustand
    // oben, jetzt mit dem tatsächlichen Kanal-Ergebnis statt `AsyncLoading`.
    // `istLeer` ist der eine Fall, für den sich `alsMesswert` laut seinem
    // eigenen Vertrag auf den Aufrufer verlässt (Spec 5.3d) — hier die
    // einzige Stelle für `dailyMetricsProvider`, die das entscheidet.
    return alsMesswert<List<DailyMetrics>>(
      kanalErgebnis,
      cache: cache,
      jetzt: jetzt,
      istLeer: kanalErgebnis is AsyncData<List<DailyMetrics>>
          ? kanalErgebnis.value.isEmpty
          : false,
    );
  }
}

/// Die Länge des Rechenfensters aus `docs/SPEC.md` Abschnitt 3: **30 Tage**,
/// der heutige Tag eingeschlossen. Keine Jahreszahl und kein Ereignis, nur
/// eine Spanne.
const rechenfensterTage = 30;

/// Das Rechenfenster des Erholung-Schirms (#113, Spec 8): 30 Tage
/// einschließlich heute, Beginn auf `BerlinCalendar.startOfDay`. Der
/// eingestellte Betrachtungszeitraum (`dataWindowProvider`) kann es
/// **verkürzen, nie verlängern**.
///
/// **Warum ein eigener Provider und nicht `dataWindowProvider` selbst:** Der
/// ist der vom Nutzer eingestellte Betrachtungszeitraum und steht
/// standardmäßig auf `unlimited` — Schlaf würde damit die ganze Historie
/// holen, obwohl SPEC 3 über 30 Tage rechnet. Ihn umgekehrt app-weit auf 30
/// Tage zu kappen beträfe auch Gewicht und Schritte, die weiter
/// zurückschauen dürfen; `dailyMetricsProvider` bleibt deshalb unangetastet
/// (ein Provider für alle Schirme, Spec 5.1), und der Erholung-Schirm
/// schneidet seine Tageswerte mit diesem Fenster selbst zu.
final rechenfensterProvider = Provider<DataWindow>((ref) {
  // Der Tag kommt aus `heutigerTagProvider`, nicht aus der Uhr: Nur so
  // rückt das Fenster über Mitternacht mit, und nur so bleibt es am selben
  // Kalendertag **dasselbe Objekt** — ein Fenster, das sich bei jedem
  // Zugriff neu baut, wäre für Riverpod eine Änderung und ließe jeden
  // abgeleiteten Wert neu laufen (Fehler `03`).
  final heute = ref.watch(heutigerTagProvider);
  final eingestellt = ref.watch(dataWindowProvider).start;
  final beginn = _tageZurueck(heute, rechenfensterTage - 1);

  // „Verkürzen, nie verlängern": Es gewinnt der **spätere** der beiden
  // Beginne. Ein Betrachtungszeitraum von zehn Monaten darf aus dem
  // Rechenfenster keine zehn Monate machen — sonst rechnen Diagramm und
  // Ampel mit verschiedenen Nächten.
  if (eingestellt != null && eingestellt.isAfter(beginn)) {
    return DataWindow(start: eingestellt);
  }
  return DataWindow(start: beginn);
});

/// Berliner Tagesbeginn des Kalendertags, der [tage] Kalendertage vor dem
/// Tag von [jetzt] liegt.
///
/// **Kalendertage, keine 24-Stunden-Schritte.**
/// `jetzt.subtract(const Duration(days: 29))` landet über eine
/// Zeitumstellung hinweg einen Tag zu früh — vom 20.04.2026 aus auf dem
/// 21.03. statt dem 22.03., weil die Nacht zum 29.03. nur 23 Stunden hat.
/// `DateTime.utc` normalisiert einen negativen Tageswert korrekt über
/// Monats- und Jahresgrenzen; `BerlinCalendar.startOfDay` setzt danach die
/// Tagesgrenze.
DateTime _tageZurueck(DateTime jetzt, int tage) {
  final teile = BerlinCalendar.dayKey(jetzt).split('-').map(int.parse).toList();
  return BerlinCalendar.startOfDay(
    DateTime.utc(teile[0], teile[1], teile[2] - tage),
  );
}

/// Die Nächte aus Apple Health über das Rechenfenster (#113).
///
/// Hängt an **keinem** Provider, der selbst den Kanal fragt — deshalb laufen
/// Tageswerte und Nächte von selbst parallel statt nacheinander (Spec 8).
/// Über 30 Tage verdoppelte ein Nacheinander die Wartezeit beim Öffnen des
/// Schirms.
final sleepProvider =
    AsyncNotifierProvider<SleepNotifier, Messwert<List<SleepNight>>>(
      SleepNotifier.new,
    );

/// Dieselbe Ladereihenfolge wie `DailyMetricsNotifier`, Schritt für Schritt:
/// Cache lesen → **nur bei vorhandenem Cache** sofort `Bekannt(laeuft: true)`
/// ausgeben → Kanal fragen, höchstens drei Versuche → zurückschreiben →
/// `alsMesswert`. Jede dieser Entscheidungen ist dort ausführlich begründet
/// und wird hier nicht wiederholt; sie gilt unverändert.
class SleepNotifier extends AsyncNotifier<Messwert<List<SleepNight>>> {
  @override
  Future<Messwert<List<SleepNight>>> build() async {
    final cacheRepo = ref.watch(cacheRepositoryProvider);
    final fenster = ref.watch(rechenfensterProvider);
    // Wie bei `DailyMetricsNotifier` ausdrücklich beobachtet. Dass
    // `rechenfensterProvider` seinerseits am Tag hängt, reicht als
    // Begründung nicht: Wer hier den Tag braucht, sagt es.
    ref.watch(heutigerTagProvider);
    // Wie bei `DailyMetricsNotifier`, dort begründet: Nach der
    // beantworteten Freigabe liest der Erholung-Schirm neu, statt auf dem
    // leeren Ergebnis von vor dem Dialog stehen zu bleiben (#176).
    ref.watch(freigabeProvider);
    final uhr = ref.watch(clockProvider);
    final quelle = ref.watch(healthProvider);
    // Angestoßen, nicht abgewartet — dieselbe Begründung wie in
    // `DailyMetricsNotifier.build`.

    final cacheZeile = await cacheRepo.liesNaechte(fenster);
    final cache = cacheZeile == null
        ? null
        : (wert: cacheZeile.werte, stand: cacheZeile.stand);

    // **Erst fragen, dann lesen** (#183): Ohne Freigabe liefert Apple eine
    // leere Antwort ohne Fehler, und der Schirm behauptete dann „nichts
    // aufgezeichnet oder nicht freigegeben".
    //
    // **Hier und nicht später:** Zwischen dem Zwischenzustand unten und dem
    // Kanal darf kein `await` mehr liegen. Die manuelle `state`-Zuweisung
    // erfüllt die noch offene `.future` dieses Providers; wer darauf wartet,
    // wird dann geweckt, und ein `await` danach ließe ihn messen, bevor der
    // Kanal überhaupt gefragt wurde.
    //
    // **Ein Fehler hier hält den Lauf nicht auf.** Apple verrät den
    // Lesestatus ohnehin nicht; wer nach einer gescheiterten Anfrage gar
    // nicht erst liest, macht aus „vielleicht nichts da" ein sicheres
    // Nichts — und verlöre den Cache gleich mit.
    try {
    } catch (_) {
      // Bewusst verschluckt, siehe oben.
    }

    final jetzt = uhr();
    if (cache != null) {
      state = AsyncData(
        alsMesswert<List<SleepNight>>(
          const AsyncLoading(),
          cache: cache,
          jetzt: jetzt,
          istLeer: false,
        ),
      );
    }

    final von = fenster.queryStart(floor: quelle.earliestPermittedDate);
    const maxVersuche = 3;
    AsyncValue<List<SleepNight>> kanalErgebnis = const AsyncLoading();
    for (var versuch = 1; versuch <= maxVersuche; versuch++) {
      try {
        final naechte = await quelle.sleepSessions(von, jetzt);
        await cacheRepo.schreibeNaechte(naechte, gelesenAm: jetzt);
        kanalErgebnis = AsyncData(naechte);
        break;
      } catch (fehler, stack) {
        if (versuch >= maxVersuche) {
          kanalErgebnis = AsyncError(fehler, stack);
        }
      }
    }

    return alsMesswert<List<SleepNight>>(
      kanalErgebnis,
      cache: cache,
      jetzt: jetzt,
      istLeer: kanalErgebnis is AsyncData<List<SleepNight>>
          ? kanalErgebnis.value.isEmpty
          : false,
    );
  }
}

/// Puls, HRV und Atemfrequenz **je Nacht** des Rechenfensters (#193,
/// Stufe 3), abgelegt unter dem ISO-Tagesschlüssel des Aufwachtags —
/// derselbe wie in `Naechte.tag`. Ein Tag ist eine Kalenderangabe, kein
/// Zeitpunkt (`CLAUDE.md`).
///
/// **Warum es diesen Provider gibt:** Apples `RestingHeartRate` ist ein
/// Tageswert, der im Lauf des Tages mitwächst, und HRV wie Atemfrequenz hat
/// die App bisher über den ganzen Kalendertag gemittelt. Beides beantwortet
/// die Frage „wie war die Nacht?" nicht — am 12.10. lief die angezeigte HRV
/// allein durch Tagesmessungen von 38 auf 60 und zurück auf 53. Die
/// Rechnung selbst steht im Kern (`NightVitals`), hier steht nur, woher
/// ihre Eingaben kommen und wo das Ergebnis bleibt.
///
/// Eine Nacht, für die keine der drei Reihen eine Probe im Fenster hat,
/// steht **nicht** in der Karte: Ein `NightVitals` mit drei `null`-Feldern
/// wäre dieselbe Auskunft wie ein fehlender Eintrag, nur mit mehr Zeilen.
/// Bleibt die Karte dadurch leer, ist das Ergebnis nie `Bekannt({})` — die
/// eine Stelle, an der dieser Provider die Pflicht aus `alsMesswert`s
/// Vertrag einlöst, dass `Bekannt.wert` nie leer ist. Ohne Cache heißt das
/// `LeerNachLauf`; liegt ein Cache vor, bleibt dessen Karte mit ihrem Stand
/// stehen (#224, begründet bei `alsMesswert`).
final nachtWerteProvider =
    AsyncNotifierProvider<
      NachtWerteNotifier,
      Messwert<Map<String, NightVitals>>
    >(NachtWerteNotifier.new);

/// Dieselbe Ladereihenfolge wie `DailyMetricsNotifier` und `SleepNotifier`:
/// Cache lesen → **nur bei vorhandenem Cache** sofort `Bekannt(laeuft: true)`
/// ausgeben → Kanal fragen, höchstens drei Versuche → zurückschreiben →
/// `alsMesswert`. Die Begründung jedes einzelnen Schritts steht bei
/// `DailyMetricsNotifier` und gilt hier unverändert; ein dritter Ladeweg
/// neben den beiden bestehenden wäre eine dritte Stelle, an der Tims Fehler
/// („Ladezustand als Leerstand") neu entstehen könnte.
class NachtWerteNotifier
    extends AsyncNotifier<Messwert<Map<String, NightVitals>>> {
  @override
  Future<Messwert<Map<String, NightVitals>>> build() async {
    final cacheRepo = ref.watch(cacheRepositoryProvider);
    final fenster = ref.watch(rechenfensterProvider);
    ref.watch(heutigerTagProvider);
    ref.watch(freigabeProvider);
    final uhr = ref.watch(clockProvider);
    final quelle = ref.watch(healthProvider);
    // Die Nächte tragen die Fenster, über die gerechnet wird — deshalb hängt
    // dieser Provider an `sleepProvider` und fragt den Kanal nicht selbst
    // nach Schlaf. Zwei Stellen, die unabhängig voneinander bestimmen,
    // welche Nächte es gibt, wären zwei Wahrheiten.
    //
    // **Gewartet wird auf die abschließende Ausgabe, nicht auf die erste.**
    // `sleepProvider` gibt bei vorhandenem Schlaf-Cache zweimal aus: erst
    // den Zwischenstand aus dem Cache (`laeuft: true`), dann das Ergebnis
    // des Laufs. Riverpod 3.4.3 lässt `.future` mit der **zuerst**
    // ausgegebenen Ausgabe auflösen und friert sie ein; wer sie beobachtet,
    // rechnet auf den Nächten aus dem Cache und läuft ein zweites Mal,
    // sobald die frischen eintreffen.
    //
    // Dieser zweite Lauf läse den Cache erneut — und zu diesem Zeitpunkt hat
    // der Schlaflauf `naechte.gelesen_am` längst auf seinen eigenen
    // Zeitpunkt gesetzt. Die drei Werte in der Zeile sind dieselben alten,
    // ihr Stand stünde aber auf „jetzt": eine Standzeile, die für diese
    // Werte einen Lauf behauptet, den es nie gab. Ein Lauf, eine Karte, ein
    // Stand — deshalb hier `ref.listen` auf die fertige Ausgabe statt
    // `ref.watch(sleepProvider.future)`.
    //
    // Dass `ref.listen` keinen neuen Lauf auslöst, kostet hier nichts:
    // Jede Abhängigkeit, die `SleepNotifier` neu laufen lässt, steht oben
    // auch in dieser Liste.
    final schlafFertig = Completer<AsyncValue<Messwert<List<SleepNight>>>>();
    ref.listen<AsyncValue<Messwert<List<SleepNight>>>>(sleepProvider, (
      _,
      ausgabe,
    ) {
      if (schlafFertig.isCompleted) return;
      // `isLoading` fängt auch die Ausgabe ab, die beim Neulauf den
      // vorigen Wert noch mitführt — die wäre sonst ein Ergebnis von
      // vorhin, ausgegeben als das von jetzt.
      if (ausgabe.isLoading) return;
      final messwert = ausgabe.value;
      // `laeuft: true` heißt: Der Lauf ist noch unterwegs, das hier ist der
      // Zwischenstand aus dem Schlaf-Cache.
      if (messwert is Bekannt<List<SleepNight>> && messwert.laeuft) return;
      schlafFertig.complete(ausgabe);
    }, fireImmediately: true);

    // Schritt 1: Cache lesen.
    final cacheZeile = await cacheRepo.liesNachtWerte(fenster);
    final cache = cacheZeile == null
        ? null
        : (wert: cacheZeile.werte, stand: cacheZeile.stand);

    // Schritt 2: sofort ausgeben, **nur wenn es einen Cache gibt** — und
    // zwar vor dem Warten auf den Schlaflauf: Was im Cache liegt, gilt
    // unabhängig davon, was der neue Lauf findet.
    final jetzt = uhr();
    if (cache != null) {
      state = AsyncData(
        alsMesswert<Map<String, NightVitals>>(
          const AsyncLoading(),
          cache: cache,
          jetzt: jetzt,
          istLeer: false,
        ),
      );
    }

    // Schritt 3: die Nächte. Was `sleepProvider` meldet, kommt hier als
    // derselbe Zustand wieder heraus — „gescheitert" ist nicht „nichts
    // gemessen", und ohne Nächte gibt es keine Fenster.
    final schlafAusgabe = await schlafFertig.future;
    final schlafWert = schlafAusgabe.value;
    if (schlafWert == null) {
      // `SleepNotifier` fängt seine Fehler selbst ab und meldet sie als
      // `Fehlgeschlagen`; hierher kommt also nur ein Fehler aus dem
      // Provider-Rumpf. Er wird weitergereicht und nicht geworfen —
      // `AsyncValue` endet an `alsMesswert`.
      return alsMesswert<Map<String, NightVitals>>(
        AsyncError(
          schlafAusgabe.error ?? StateError('sleepProvider ohne Ergebnis'),
          schlafAusgabe.stackTrace ?? StackTrace.empty,
        ),
        cache: cache,
        jetzt: jetzt,
        istLeer: false,
      );
    }

    final List<SleepNight> naechte;
    switch (schlafWert) {
      case Bekannt(:final wert):
        naechte = wert;
      case LeerNachLauf():
        naechte = const [];
      case Fehlgeschlagen(:final fehler):
        // Ohne Nächte gibt es keine Fenster, und „nichts gefunden" wäre
        // dann die falsche Auskunft. `alsMesswert` entscheidet von hier an
        // wie überall: ohne Cache `Fehlgeschlagen`, mit Cache bleibt der
        // sichtbare Wert stehen. Der Stack des ursprünglichen Fehlers ist
        // in `Fehlgeschlagen` nicht aufgehoben — der Fehler selbst schon,
        // und nur er wird weitergereicht.
        return alsMesswert<Map<String, NightVitals>>(
          AsyncError(fehler, StackTrace.empty),
          cache: cache,
          jetzt: jetzt,
          istLeer: false,
        );
      case NochNie():
        // Unerreichbar, solange `SleepNotifier` jeden Lauf zu Ende führt:
        // `alsMesswert` gibt `NochNie` nur zurück, während noch geladen
        // wird. Der `switch` über den sealed-Typ muss trotzdem vollständig
        // sein, und „noch nichts" ehrlich weitergereicht heißt „lädt" —
        // nicht „leer" und nicht „gescheitert".
        return alsMesswert<Map<String, NightVitals>>(
          const AsyncLoading(),
          cache: cache,
          jetzt: jetzt,
          istLeer: false,
        );
    }

    // Schritt 4: der Kanal — **drei Abfragen insgesamt**, eine je Messreihe
    // über das ganze Fenster, danach die Zuordnung in Dart. Je Nacht gefragt
    // wären es bei dreißig Nächten neunzig.
    //
    // Ohne Nacht wird gar nicht gefragt: Es gäbe kein Fenster, in das eine
    // Probe fiele, und die drei Abfragen holten für dreißig Tage rund 24.000
    // Pulsproben für ein Ergebnis, das in jedem Fall leer ist.
    final grenzen = _kanalgrenzen(naechte);
    AsyncValue<Map<String, NightVitals>> kanalErgebnis = const AsyncData(
      <String, NightVitals>{},
    );
    if (grenzen != null) {
      const maxVersuche = 3;
      for (var versuch = 1; versuch <= maxVersuche; versuch++) {
        try {
          // Nacheinander, nicht über `Future.wait`: Scheitert dort eine der
          // drei Abfragen, bleiben die Fehler der übrigen unbehandelt
          // stehen, und ein unbehandelter Fehler beendet in Tests den
          // ganzen Lauf.
          final proben = <VitalKind, List<VitalSample>>{};
          for (final art in VitalKind.values) {
            final roh = await quelle.quantitySamples(
              art,
              grenzen.von,
              grenzen.bis,
            );
            // Einmal je Messreihe umgesetzt, nicht einmal je Nacht:
            // `QuantitySample` ist die Nutzlast des Kanals, `VitalSample`
            // der Eingabetyp des Kerns. Bei dreißig Nächten wäre das sonst
            // dreißigmal dieselbe Liste.
            proben[art] = [
              for (final probe in roh)
                VitalSample(time: probe.date, value: probe.value),
            ];
          }
          final karte = _nachtWerte(naechte, proben);
          await cacheRepo.schreibeNachtWerte(karte, gelesenAm: jetzt);
          kanalErgebnis = AsyncData(karte);
          break;
        } catch (fehler, stack) {
          if (versuch >= maxVersuche) {
            kanalErgebnis = AsyncError(fehler, stack);
          }
          // sonst: nächster Versuch der Schleife.
        }
      }
    }

    return alsMesswert<Map<String, NightVitals>>(
      kanalErgebnis,
      cache: cache,
      jetzt: jetzt,
      istLeer: kanalErgebnis is AsyncData<Map<String, NightVitals>>
          ? kanalErgebnis.value.isEmpty
          : false,
    );
  }
}

/// Die Grenzen der drei Kanalabfragen: vom frühesten Nachtbeginn bis zum
/// spätesten Nachtende. `null`, wenn keine Nacht ein Fenster hergibt.
///
/// **Nicht `fenster.queryStart(...)`.** Das Rechenfenster beginnt auf einem
/// Berliner **Tagesbeginn**; die Nacht dieses Tages beginnt am Abend
/// **davor**. Wer ab dem Fensterbeginn fragt, verliert von der ersten Nacht
/// alles vor Mitternacht — bei einer Nacht von 21:00 bis 06:00 drei der
/// neun Stunden, und beim Ruhepuls liegt in ihnen der Tiefpunkt. Die Zahl
/// fehlte dann nicht, sie wäre still falsch: Fehler `01` **unterhalb** von
/// `Messwert<T>`, wo der sealed-Typ ihn nicht mehr sehen kann.
///
/// **Keine Kappung auf `earliestPermittedDate`.** Die Nächte stammen selbst
/// aus der Quelle und können deshalb nicht älter sein, als sie hergibt;
/// eine Kappung könnte die untere Grenze also nur nach hinten schieben und
/// genau den Verlust bewirken, gegen den diese Funktion gebaut ist.
({DateTime von, DateTime bis})? _kanalgrenzen(List<SleepNight> naechte) {
  DateTime? von;
  DateTime? bis;
  for (final nacht in naechte) {
    final fenster = _nachtfenster(nacht);
    if (fenster == null) continue;
    if (von == null || fenster.von.isBefore(von)) von = fenster.von;
    if (bis == null || fenster.bis.isAfter(bis)) bis = fenster.bis;
  }
  if (von == null || bis == null) return null;
  return (von: von, bis: bis);
}

/// Das Fenster **einer** Nacht: vom frühesten Beginn bis zum spätesten Ende
/// ihrer Abschnitte. `null` ohne Abschnitt — dann gibt es keine Zeitspanne,
/// in die eine Probe fallen könnte.
///
/// **Ein Fenster je Nacht, nicht eines je Abschnitt.** Wer je Abschnitt
/// zuordnet, verliert jede Probe aus einer Wachphase zwischen zwei
/// Abschnitten — und bei zwei bis sechs HRV-Proben je Nacht ist das schnell
/// die einzige.
///
/// **Nur `session`, nicht `naps`:** SPEC 4.6 zählt Tagschlaf nicht zur
/// Nacht.
({DateTime von, DateTime bis})? _nachtfenster(SleepNight nacht) {
  final abschnitte = nacht.session.segments;
  if (abschnitte.isEmpty) return null;
  var von = abschnitte.first.start;
  var bis = abschnitte.first.end;
  for (final abschnitt in abschnitte.skip(1)) {
    if (abschnitt.start.isBefore(von)) von = abschnitt.start;
    if (abschnitt.end.isAfter(bis)) bis = abschnitt.end;
  }
  return (von: von, bis: bis);
}

/// Rechnet je Nacht die drei Werte aus den Proben des ganzen Laufs — die
/// Zuordnung Probe → Nacht, die nach den drei Kanalabfragen in Dart
/// passiert.
///
/// Nächte ohne jeden der drei Werte bleiben draußen, siehe
/// [nachtWerteProvider].
Map<String, NightVitals> _nachtWerte(
  List<SleepNight> naechte,
  Map<VitalKind, List<VitalSample>> proben,
) {
  const keine = <VitalSample>[];
  final karte = <String, NightVitals>{};
  for (final nacht in naechte) {
    final fenster = _nachtfenster(nacht);
    if (fenster == null) continue;
    final werte = NightVitals.from(
      heartRate: proben[VitalKind.heartRate] ?? keine,
      hrv: proben[VitalKind.heartRateVariability] ?? keine,
      respiratoryRate: proben[VitalKind.respiratoryRate] ?? keine,
      from: fenster.von,
      through: fenster.bis,
    );
    if (werte.restingHeartRate == null &&
        werte.hrv == null &&
        werte.respiratoryRate == null) {
      continue;
    }
    karte[BerlinCalendar.dayKey(nacht.date)] = werte;
  }
  return karte;
}

// ─────────────────────────────────────────────────────────────────────────
// Stundenschritte (#84)
// ─────────────────────────────────────────────────────────────────────────

/// Schritte je Stunde aus Apple Health (`HealthReading.hourlySteps`) —
/// die Reihe hinter der Stufe `T` des Schritte-Schirms.
///
/// **Noch ohne Abnehmer:** Die T-Stufe wartet auf Tims Entscheidung (#92,
/// gepinnt in `schlaf_zustand_test.dart`), und solange sie niemand
/// beobachtet, läuft dieser Rumpf nie — Riverpod baut einen Provider erst
/// beim ersten `watch`. Der Schirm der Vier-Stufen-Fassung liest ihn
/// nicht.
///
/// **Ohne drift-Cache (`cache: null`)**, wie [gewichtsProbenProvider]: Die
/// Tabelle `StundenSchritte` trägt kein `gelesen_am`, und ein Cache ohne
/// Stand müsste seinen Zeitstempel erfinden — genau das verbietet die
/// Stand-Regel (Spec 5.3b). Die Cache-Kette kommt als Folgearbeit
/// **zusammen mit der T-Stufe**; die Schemastufe dafür vergibt der
/// Koordinator zentral (Stufe 25 gehört den eigenen Trainings, Stufe 26
/// dem Ausdauer-Zweig — zwei Zweige mit derselben Nummer waren Fund
/// #485, und genau das ist zwischen diesen beiden am 24.11.2026 noch
/// einmal passiert).
///
/// Das Fenster ist das Rechenfenster (30 Tage): Weiter zurück liefert
/// HealthKit ohnehin keine Stundenwerte (`StepsView.swift:118–120`), und
/// die Fußnote der T-Stufe sagt das, statt die Kurve stillschweigend
/// flach werden zu lassen.
///
/// **Wer dieser Reihe einen Abnehmer gibt, trägt den Provider in
/// `NachlaufNotifier._ladeProvider` nach** — die eine Liste, siehe dort.
final stundenSchritteProvider =
    AsyncNotifierProvider<
      StundenSchritteNotifier,
      Messwert<List<QuantitySample>>
    >(StundenSchritteNotifier.new);

/// Ohne Cache ist der Ladeweg der von [GewichtsProbenNotifier], nicht der
/// der drei Cache-Ketten: ein Lauf, `AsyncValue.guard`, `alsMesswert` —
/// der Fehler bleibt hier drin, sonst griffe Riverpods Wiederholung, und
/// ein gescheiterter Lauf wäre von „nichts gefunden" nicht zu
/// unterscheiden (Fehler `01`).
class StundenSchritteNotifier
    extends AsyncNotifier<Messwert<List<QuantitySample>>> {
  @override
  Future<Messwert<List<QuantitySample>>> build() async {
    final fenster = ref.watch(rechenfensterProvider);
    // Beobachtet, aus denselben Gründen wie bei den drei Cache-Ketten:
    // Tageswechsel und beantwortete Freigabe stoßen einen neuen Lauf an.
    ref.watch(heutigerTagProvider);
    ref.watch(freigabeProvider);
    final uhr = ref.watch(clockProvider);
    final quelle = ref.watch(healthProvider);

    final jetzt = uhr();
    final von = fenster.queryStart(floor: quelle.earliestPermittedDate);
    final ergebnis = await AsyncValue.guard(
      () => quelle.hourlySteps(von, jetzt),
    );

    return alsMesswert<List<QuantitySample>>(
      ergebnis,
      cache: null,
      jetzt: jetzt,
      istLeer: (ergebnis.value ?? const <QuantitySample>[]).isEmpty,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Gewichtsproben (#270)
// ─────────────────────────────────────────────────────────────────────────

/// Wie weit „Letzte Messungen" zurückschaut.
///
/// Ein Jahr, nicht das ganze Leben: Die Liste zeigt die jüngsten Wägungen,
/// und eine Abfrage über zehn Jahre kostet Zeit für Zeilen, die niemand
/// sieht. Wer weiter zurück will, geht auf den Verlauf.
const _gewichtsFenster = Duration(days: 365);

/// Die einzelnen Wägungen aus Apple Health — mit Uhrzeit, UUID und
/// Kennzeichen.
///
/// **Warum neben `dailyMetricsProvider` und nicht darin:** Die Tageswerte
/// kommen aus einer Statistik, die keines der drei Dinge trägt. Sie
/// trotzdem hier mitzuführen hieße, `DailyMetrics` um Felder zu erweitern,
/// die nur ein Abschnitt eines Schirms braucht.
///
/// **Ohne drift-Cache**, anders als die Tageswerte. Der Cache gibt es,
/// damit Home beim Kaltstart nicht 0 zeigt; diese Liste steht weit unten
/// auf einem gepushten Schirm, und eine zweite Ablage für Werte, deren
/// einzige Quelle Health ist, wäre genau die zweite Wahrheit, die die Spec
/// ausschließt.
final gewichtsProbenProvider =
    AsyncNotifierProvider<
      GewichtsProbenNotifier,
      Messwert<List<WeightSample>>
    >(GewichtsProbenNotifier.new);

/// Dasselbe, aber **gehalten** und ohne `AsyncValue` — das ist, was die
/// Widget-Schicht sieht (Hausregel 1 und 2).
///
/// `.value` trägt beim Nachlauf noch den vorigen [Messwert]: `invalidateSelf`
/// macht daraus `AsyncLoading.copyWithPrevious(…)`, und genau deshalb bleibt
/// `Bekannt` stehen, statt auf den Platzhalter zurückzufallen. Läse der
/// Schirm stattdessen `isLoading` und `value` selbst, blitzte nach jedem
/// Sichern, jedem Löschen und jedem Tageswechsel die graue Fläche auf —
/// genau das Flackern, gegen das `CLAUDE.md` den Platzhalter auf [NochNie]
/// beschränkt.
final gewichtsReiheProvider = Provider<Messwert<List<WeightSample>>>(
  (ref) =>
      ref.watch(gewichtsProbenProvider).value ??
      const NochNie<List<WeightSample>>(),
);

class GewichtsProbenNotifier
    extends AsyncNotifier<Messwert<List<WeightSample>>> {
  @override
  Future<Messwert<List<WeightSample>>> build() async {
    final quelle = ref.watch(healthProvider);
    final uhr = ref.watch(clockProvider);
    // Beobachtet, aus demselben Grund wie bei den Tageswerten: Wechselt der
    // Kalendertag, endet die obere Grenze sonst weiter gestern.
    ref.watch(heutigerTagProvider);

    final jetzt = uhr();
    // **Der Fehler bleibt hier drin**, er verlässt den Notifier nicht als
    // `AsyncError`: Sonst griffe Riverpods Wiederholung, und der Abschnitt
    // pendelte mit Backoff zwischen Platzhalter und „keine Wägung". Und
    // ein gescheiterter Lauf wäre drüben nicht von „nichts gefunden" zu
    // unterscheiden — das ist Fehler `01`.
    final ergebnis = await AsyncValue.guard(
      () => quelle.weightSamples(jetzt.subtract(_gewichtsFenster), jetzt),
    );

    // `alsMesswert` ist die einzige Stelle, die `AsyncValue` in `Messwert`
    // übersetzt (Hausregel 1). `cache: null`, weil es für diese Liste
    // bewusst keinen drift-Cache gibt: Ihre einzige Quelle ist Health.
    return alsMesswert<List<WeightSample>>(
      ergebnis,
      cache: null,
      jetzt: jetzt,
      istLeer: (ergebnis.value ?? const <WeightSample>[]).isEmpty,
    );
  }

  /// Nach dem Schreiben oder Löschen: neu lesen.
  ///
  /// **Nicht den eigenen Zustand fortschreiben.** Der neue Wert erscheint,
  /// weil Health ihn liefert — nicht, weil die App ihn sich gemerkt hat.
  /// Eine Liste, die wir selbst ergänzen, behauptete einen Stand in
  /// HealthKit, den nur wir kennen.
  void neuLaden() => ref.invalidateSelf();
}
