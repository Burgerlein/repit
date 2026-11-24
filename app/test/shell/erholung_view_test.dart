import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/grosse_ueberschrift.dart';
import 'package:repit/design/hinweisfuss.dart';
import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/icon_row.dart';
import 'package:repit/design/ring_karte.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/design/vital_ton.dart';
import 'package:repit/shell/belastung_view.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_view.dart';
import 'package:repit/shell/erholung_werte_view.dart';
import 'package:repit/shell/erholung_zustand.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/tagschlaf_view.dart';
import 'package:repit/shell/verlauf_view.dart';
import 'package:repit/shell/verlauf_zustand.dart';

import '../design/support.dart' show textOf;

/// Tests für den **Schirm** `erholung` (#115) — `lib/shell/erholung_view.dart`.
/// Der Zustand darunter liegt in `erholung_zustand_test.dart`; die Trennung
/// ist dieselbe wie bei `heute_view_test.dart`/`heute_zustand_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/erholung_view.dart`)
///
/// ```dart
/// /// Öffnet den Erholung-Schirm auf dem Stapel des **aktuell gewählten**
/// /// Tabs. Die eine Stelle, die das weiß — MehrView und die
/// /// Erholungskarte auf Heute rufen beide hierher.
/// void oeffneErholung(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [ErholungView].
/// class ErholungSeite extends StatelessWidget {
///   const ErholungSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class ErholungView extends ConsumerWidget {
///   const ErholungView({super.key, required AppRouter router});
/// }
///
/// ```
///
/// **`ErholungTuerPlatzhalter` und `ErholungTuer` stehen hier nicht mehr.**
/// Beide fallen weg — siehe den Nachtrag vom 28.10.2026 am Ende dieses
/// Kopfes.
///
/// Dazu in `lib/shell/heute_view.dart`: **`HeuteView` bekommt einen
/// optionalen Router** — `const HeuteView({super.key, this.router})`,
/// `final AppRouter? router`. `null` heißt „keine Tür": Die Erholungskarte
/// ist dann nicht antippbar und trägt kein Chevron. Der Parameter ist
/// optional und nicht `required`, weil `heute_view_test.dart` eine fremde
/// Testdatei ist, die dieser Auftrag nicht anfassen soll und die
/// `const HeuteView()` pumpt. `RootView` übergibt immer einen.
///
/// ## Acht Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt (dieselbe Begründung wie bei den
/// Hinweis-Schlüsseln in `heute_view_test.dart`). Jeder sitzt auf einem
/// **Vorfahren** der Texte, nicht auf einem `Text` selbst:
///
/// - `Key('erholung-datumszeile')` — Abschnitt 1 (seit 27.10., siehe unten)
/// - `Key('erholung-laden')` — der reine Ladezweig
/// - `Key('erholung-hinweiskasten')` — Abschnitt 3, fällt bei `calm` weg
/// - `Key('erholung-health-einstellungen')` — Abschnitt 3b, nur bei `noData`
/// - `Key('erholung-schlaf-nachtragen')` — der zweite Knopf daneben,
///   ebenfalls nur bei `noData` (seit 27.10., siehe die Gruppe „Zwei
///   Knöpfe, keiner hervorgehoben")
/// - `Key('erholung-nachtkarte')` — Abschnitt 5
/// - `Key('erholung-nacht-kopf')` — der Kopf darin: Schlafdauer, Score und
///   Zeitfenster. Bis zum 03.11.2026 war er die zweite Tür auf den
///   Schlaf-Schirm, seit #259 ist er stumm. Der Schlüssel bleibt, weil
///   „dieser Kopf" sonst keine strukturelle Stelle im Baum hat
/// - `Key('erholung-tagschlaf')` — Abschnitt 5b, nur mit Tagschlaf
/// - `Key('erholung-verlaeufe')` — Abschnitt 6
/// - `Key('erholung-tipps')` — Abschnitt 7
/// - `Key('erholung-tipps-kopf')` — die Zeile, die auf- und zuklappt (27.10.)
/// - `Key('erholung-tipps-inhalt')` — die vier Punkte, **nur aufgeklappt**
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht Layout
/// und Beschriftung. Kein Test in dieser Datei schreibt einen Satz fest.
/// Wo ein Text eine *Regel* trägt, wird die Regel geprüft:
///
/// - Bei fehlenden Health-Daten kommen **beide** Wörter vor („aufgezeichnet"
///   und „freigegeben") — Apple verrät den Lesestatus nicht.
/// - Ein fehlender Einzelwert steht als „—", nie als „0".
/// - Der Hinweiskasten fehlt bei `calm` und steht bei `watch`/`stressed`/
///   `noData`.
/// - Der Knopf „Health-Einstellungen öffnen" erscheint nur, wo nichts da ist.
/// - **Jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren** — die
///   Regel, die `docs/screens/pruefen.mjs` am Entwurfsboard durchsetzt,
///   einmal für den fertigen Schirm.
///
/// **Nicht geprüft, bewusst:**
///
/// - Dass der Health-Knopf tatsächlich `x-apple-health://` öffnet. `app/`
///   hat kein `url_launcher`; wie der Knopf das macht, entscheidet der
///   Umsetzende. Ein Widget-Test könnte einen geöffneten URL ohnehin nicht
///   sehen — das gehört in die Prüfanleitung fürs Gerät. Der Knopf wird
///   deshalb auch nicht angetippt.
/// - Der `postOperative`-Zweig. Der Schirm kann ihn heute nicht erzeugen
///   (Spec Abschnitt 9: kein Ereignisdatum im Quelltext, #41 fehlt). Sein
///   Text ist in `erholung_zustand_test.dart` über `erholungHinweis`
///   geprüft, ohne Widget.
/// - Farben, Abstände, Schriften und die Reihenfolge der Abschnitte
///   untereinander.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`, Spec Abschnitt 12).
///
/// ## Nachtrag 27.10.2026 — die Buchführung im Test zu `docs/todo/32`
///
/// Die letzte Zusicherung dieses Tests verlangte ursprünglich, dass in
/// **keiner** beobachteten Ausgabe `NochNie` vorkommt. Das war nicht
/// erfüllbar, und zwar unabhängig von der Umsetzung: `listen(…,
/// fireImmediately: true)` ruft den Beobachter **synchron beim Anmelden**
/// auf, und das geschieht vor `zeige(tester, …)`. In diesem Augenblick hat
/// niemand `dailyMetricsProvider` oder `sleepProvider` gelesen; beide sind
/// `AsyncNotifier` mit `Future<…> build() async` und stehen zwangsläufig auf
/// `AsyncLoading` ohne Wert. `erholungProvider` kann daraus nichts anderes
/// bauen als `NochNie` — genau das schreibt `erholung_zustand_test.dart`
/// („beide Hälften noch ohne alles: `NochNie`") selbst fest. Die allererste
/// Ausgabe **muss** also `NochNie` sein.
///
/// Gemeint war nie „nie `NochNie`", sondern das, was `docs/todo/32`
/// beschreibt: **Ein Wert, der einmal dastand, verschwindet nicht wieder.**
/// Die Zusicherung zählt deshalb jetzt erst **ab der ersten Ausgabe, die
/// kein `NochNie` ist** (`skipWhile`), und verlangt, dass danach keines mehr
/// folgt. Zusätzlich wird geprüft, dass es diese erste Ausgabe überhaupt
/// gab — sonst wäre die Liste leer und die Zusicherung sagte nichts.
///
/// **Warum `skipWhile` und nicht `fireImmediately: false` oder ein
/// Anmelden nach `zeige(...)`:** Beides machte den Test schwächer. Wer erst
/// nach dem Laden anmeldet, sieht einen Rückfall nach `NochNie`, der
/// **während** des Ladens passiert, überhaupt nicht mehr — und der wäre
/// ebenfalls Fehler `32`. `skipWhile` wirft nur den Vorlauf weg, den die
/// Bauart erzwingt, und behält die ganze übrige Geschichte.
///
/// Gemeldet vom Umsetzenden von #115, statt den Test passend zu machen —
/// so sieht die Rollentrennung aus `CLAUDE.md` aus, wenn sie funktioniert.
///
/// ## Nachtrag 27.10.2026 — das Board ist die Vorlage, nicht die Skizze
///
/// Tim hat den fertigen Schirm gegen `docs/screens/screens/erholung.js`
/// gehalten und Abweichungen gefunden. Die Regel dazu steht seit heute in
/// `CLAUDE.md` („Entwurfsübersicht"): Wo gebauter Schirm und Board sich
/// widersprechen, **wird der Schirm nachgezogen.** Diese Datei zieht die
/// betroffenen Zusicherungen nach. Was sich ändert, und warum es jeweils
/// ein Zustand und keine Beschriftung ist:
///
/// 1. **Die große Überschrift „Erholung" entfällt.** Der Entwurf hat sie
///    nicht — die Navigationsleiste nennt den Schirm bereits, und zweimal
///    derselbe Titel übereinander ist kein Aufbau, sondern ein Versehen.
///    Übrig bleibt die Datumszeile, jetzt unter `Key('erholung-datumszeile')`.
///    Ein Test auf die *Abwesenheit* einer Zeile, die es gar nicht geben
///    soll, ist billig und richtig.
/// 2. **Oben steht nur noch das Datum.** Zuerst sollte der Nachtbezug nur
///    an Tagen mit Nacht stehen; mit Tims Entscheidung vom 27.10.2026
///    („lass uns das Datum mittig hin platzieren, so 27.Oktober.2026. Aber
///    den Text drum rum nicht.") ist die Frage erledigt: **Wochentag und
///    Nachtbezug entfallen beide.** Spec 10a Punkt 2 ist damit
///    zurückgenommen, und der Test darauf ebenfalls — er stünde sonst als
///    Zusage herum, die nicht mehr gilt.
///
///    Übrig bleibt „12. Oktober 2026". Dafür braucht `Format` eine neue
///    Methode: `wochentagUndDatum` liefert „Montag, 12. Oktober" und passt
///    nicht mehr, `tag` liefert „12.10.2026" und ist das Ziffernformat.
///    **Verlangt wird `Format.datumAusgeschrieben(DateTime)`**, festgelegt
///    in `test/design/formatierung_test.dart`; hier wird nur geprüft, dass
///    die Zeile sie benutzt. Eigene Formatierung im Schirm wäre ein
///    Verstoß gegen `CLAUDE.md` („Datumsangaben laufen über einen
///    gemeinsamen Formatierer mit fest gesetzter Sprache").
///
///    **Dass die Zeile zentriert steht, bekommt keinen Test** (Layout,
///    `CLAUDE.md`) — es steht in der Prüfanleitung und im Bericht.
/// 3. **Die Nachtkarte** (Entwurf: `nightCard`): Gruppenkopf „Schlaf" ohne
///    Knopf; rechts der Score **gegen seine erreichbare Punktzahl**
///    („82 / 100", „48 / 70"), nicht die nackte Zahl mit „Score" darunter;
///    darunter Datum **vor** den Uhrzeiten („Mo 12.10. · 23:10–06:15",
///    Tims Entscheidung vom 27.10., das Board ist mitgezogen). Und: **die
///    Karte ist seit #259 keine Tür mehr** — weder ihr Kopf noch das
///    Hypnogramm darunter führen irgendwohin. **Ohne Tür auch kein
///    Winkel:** Das „›" hinter dem Zeitfenster fällt mit der Tippfläche
///    weg, sonst sieht die Zeile drückbar aus und führt nirgendwohin.
/// 4. **Die Verlaufszeilen tragen keine Symbole** (der Entwurf hat keine),
///    färben ihren Wert nach der Ampel und führen weiter. Dazu gleich mehr.
/// 5. **Die Tipps stehen eingeklappt** und gehen beim Antippen auf. Zustand
///    und Übergang, also genau das, was ein Widget-Test prüfen soll.
///
/// ### Die Verlaufszeilen: Wert, Vergleichswert, Farbe
///
/// Der Entwurf zeigt je Zeile **drei** Dinge: den Titel, darunter Fenster
/// und Vergleichswert („7 Tage · Median 58 ms"), rechts den Wert („61 ms").
/// Der Wert ist damit **der heutige Messwert**, nicht der Durchschnitt über
/// das Fenster — der steht links in der Zeile. Gebaut war es umgekehrt (der
/// Durchschnitt als Wert, kein Vergleichswert), und ohne diese Umstellung
/// hinge die neue Ampel in der Luft: Sie vergleicht Messwert und
/// Vergleichswert, und beide müssen in derselben Zeile stehen, damit die
/// Farbe lesbar ist.
///
/// Die Zuordnung Wert → Farbe liegt als reine Funktion in
/// `erholung_zustand.dart` und ist in `erholung_verlaufston_test.dart`
/// festgeschrieben (dort auch die vollständige Begründung der Schwellen).
/// Hier wird nur geprüft, dass die Zeile sie trägt.
///
/// ### Die Verlaufszeilen führen weiter — alle vier
///
/// Tims Befund vom 27.10.2026: „Bei der Atemfrequenz fehlt der Pfeil."
/// Bisher trug **keine** Zeile einen Winkel, mit der Begründung, die
/// Verlaufsseiten gebe es noch nicht (Spec 11, `TimeChart`). Das dreht
/// sich um: Die vier Messwert-Zeilen bekommen Winkel **und** Ziel, und
/// zwar beides zusammen — ein Winkel ohne Tür wäre genau der Fehler, den
/// `docs/screens/pruefen.mjs` am Board verhindert, und eine Tür ohne
/// Winkel findet niemand.
///
/// Das Ziel war an diesem Tag noch ein Platzhalter
/// (`ErholungTuer.verlauf`), wie `opens: 'verlauf'` im Entwurf; dass alle
/// vier auf denselben führten, war Absicht für den Platzhalter und
/// ausdrücklich **keine** Aussage darüber, wie die fertige Verlaufsseite
/// ihre Metrik erfährt. **Seit dem 28.10.2026 ist diese Frage
/// entschieden** — jede Zeile führt auf den Verlauf *ihres* Wertes. Siehe
/// den Nachtrag unten.
///
/// **Die Alkohol-Zeile bleibt davon unberührt:** weder Winkel noch Ziel,
/// solange die Eingabe nicht gebaut ist. Ein Zähler über etwas, das
/// niemand eintragen kann, wäre eine Behauptung.
///
/// ### Widerspruch, den diese Datei entscheidet
///
/// Das Board zeigt in den Verläufen **vier** Zeilen, der Schirm hat
/// **fünf** — die Alkohol-Zeile („trägst du selbst ein") steht dort als
/// stummer Platzhalter. Sie bleibt: Sie ist nicht gegen den Entwurf
/// entstanden, sondern vor ihm, und sie zu entfernen wäre eine eigene
/// Entscheidung, die niemand getroffen hat. Gemeldet ist sie.
///
/// ## Nachtrag 28.10.2026 — die sechs Türen werden umgehängt
///
/// #92 (Schlaf, Tagschlaf), #117 (Erholung-Werte) und #94 (Belastung,
/// Verläufe) stehen. Damit fällt der Grund weg, aus dem alle sechs Türen
/// dieses Schirms auf einen Platzhalter zeigten. Ab heute verlangt diese
/// Datei:
///
/// | Tür | Ziel |
/// |---|---|
/// | Ring „SCHLAF" | `SchlafSeite` |
/// | Tagschlaf-Kachel | `TagschlafSeite` |
/// | Ring „ERHOLUNG" | `ErholungWerteSeite` |
/// | Ring „BELASTUNG" | `BelastungSeite` |
/// | eine Verlaufszeile | `VerlaufSeite(art: …)` — die Art dieser Zeile |
///
/// Die Zuordnung ist nicht erfunden, sie steht im Entwurf
/// (`docs/screens/screens/erholung.js` und `docs/screens/components.js`):
/// die drei Ringspalten tragen `opens: 'schlaf'`, `'erholung-werte'` und
/// `'belastung'`, `nightCard` trägt seit #259 `opens = null` als Vorgabe,
/// `napCard` `opens = 'tagschlaf'`, und die vier `trendRow` tragen `opens:
/// 'verlauf'`.
///
/// **Die Nachtkarte ist keine Tür mehr** (Tim, 03.11.2026: „auf die
/// Schlaf-Seite nur noch über den Ring oben auf der Erholungsseite
/// kommen", #259). Bis dahin führte ihr Kopf auf denselben Schirm wie der
/// Schlaf-Ring, begründet mit „zwei Fragen, ein Ziel". Das war Absicht und
/// ist jetzt umgekehrt: Der Ring ist der benannte Weg, und die Karte sagt
/// nicht, dass sie zum selben Ort führt. Dauer, Fenster und Score bleiben
/// stehen — sie tragen Auskunft; weg fällt nur die Tippfläche samt Winkel.
/// Die Tagschlaf-Kachel bleibt eine Tür und führt ausdrücklich **nicht**
/// auf den Schlaf-Schirm — die Begründung steht an `napCard` selbst
/// („Zuerst führte sie auf den Schlaf-Schirm; dort stand dann die Nacht
/// oben und der Tagschlaf weit unten").
///
/// ### `ErholungTuer` und `ErholungTuerPlatzhalter` fallen weg
///
/// **Entscheidung des Test-Agenten dieses Durchgangs, mit Begründung —
/// nicht mit Tim abgestimmt, nicht freigegeben.**
///
/// Beide Typen hatten genau einen Zweck: Ein Schirm, den es noch nicht
/// gab, brauchte einen Namen und eine leere Seite. Beides ist erledigt.
/// Ein öffentlicher Aufzählungstyp, den danach niemand mehr liest, ist
/// toter Code, und sein Doc-Kommentar („Dass alle vier auf denselben
/// führen, ist Absicht für den Platzhalter") wäre ab heute eine Zusage,
/// die nicht mehr stimmt.
///
/// Dazu kommt, dass `ErholungTuer` die neue Lage gar nicht mehr ausdrücken
/// kann: `verlauf` ist nicht *eine* Tür, sondern vier, und welche gemeint
/// ist, trägt `VerlaufArt`. Ein gemeinsamer Trichter
/// `_oeffneTuer(ErholungTuer)` müsste für genau diesen Fall eine Ausnahme
/// bauen — dann trägt er nichts mehr.
///
/// An seine Stelle treten die Funktionen, die es ohnehin schon gibt und
/// die jede für sich geprüft sind: `oeffneSchlaf`, `oeffneTagschlaf`,
/// `oeffneBelastung`, `oeffneVerlauf` — und `oeffneErholungWerte`, das
/// **neu dazukommt**, weil `erholung_werte_view.dart` als einziges Ziel
/// keine solche Stelle hat (festgelegt in `erholung_werte_view_test.dart`,
/// dort auch die Begründung). Jede von ihnen ist „die eine Stelle, die
/// weiß, wie dieser Schirm geöffnet wird", und jede benutzt
/// `AppTarget.aktuell`.
///
/// **Der Wächter wandert mit.** `erholung_zustand_test.dart` hielt bisher
/// fest, dass es sechs Türen gibt (`ErholungTuer.values`, `hasLength(6)`).
/// Ohne den Aufzählungstyp ist die Zahl nur noch am Schirm selbst
/// ablesbar; der Fall „sechs Türen, und jede landet auf einem gebauten
/// Schirm" weiter unten übernimmt das.
///
/// ### Welche Verlaufszeile eine Tür ist — und wie eine Nicht-Tür aussieht
///
/// **Entscheidung des Test-Agenten, mit Begründung.** `RecoveryTrendKind`
/// hat fünf Einträge, `VerlaufArt` vier. Die Lücke ist `alcoholDays`: Die
/// Zeile trägt laut Vertrag des Kerns immer `average: null`, und eine
/// Eingabe dafür ist nicht gebaut (#119). Ein Diagramm über etwas, das
/// niemand eintragen kann, wäre eine Behauptung.
///
/// Entschieden wird das **nicht** am Titel der Zeile und **nicht** als
/// Sonderfall im Schirm, sondern an der einen Stelle, die diese Zuordnung
/// schon trägt: `verlaufArtZu(RecoveryTrendKind)` in
/// `lib/shell/verlauf_zustand.dart` liefert `null`, und `null` heißt „keine
/// Tür". Kommt eine sechste Verlaufszeile dazu, steht die Entscheidung
/// weiter an einer Stelle statt an zweien.
///
/// **So sieht eine Nicht-Tür aus:** kein `onTap`, kein Winkel, kein
/// tippbarer Vorfahre — aber der Winkelplatz bleibt reserviert, sonst
/// springt die Wertspalte. Geprüft wird das von den beiden Fällen, die es
/// schon gibt („ein Winkel steht genau an den Zeilen, die weiterführen"
/// und „jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren"),
/// und neu von der Gruppe „Die Verlaufszeilen tragen ihre Art".
///
/// ### Der neue Vertrag von `ErholungVerlaeufe.onVerlauf`
///
/// ```dart
/// class ErholungVerlaeufe extends StatelessWidget {
///   const ErholungVerlaeufe({
///     super.key,
///     required List<RecoveryTrend> trends,
///     required RecoveryReading messwerte,
///     required RecoveryBaseline baseline,
///     required void Function(VerlaufArt art) onVerlauf,
///   });
/// }
/// ```
///
/// Statt `VoidCallback`. Der Rückruf trägt die Art, und zwar **nicht** als
/// `VerlaufArt?`: Eine Zeile ohne Art ruft gar nicht erst. Damit ist „eine
/// Zeile, die drückbar aussieht und nirgendwohin führt" im Vertrag
/// unausdrückbar, statt nur unterlassen.
///
/// ### Wie die Tür-Fälle ihr Ziel lesen
///
/// Früher wurde das Ziel gepumpt und `ErholungTuerPlatzhalter.tuer`
/// abgelesen. Das geht nicht mehr: Die echten Ziele sind `ConsumerWidget`s
/// mit eigenem Unterbau, und ihn hier nachzubauen hieße, fünf fremde
/// Schirme in dieser Datei mitzupflegen. Stattdessen wird der
/// `WidgetBuilder` des Befehls nur **aufgerufen** (`schirmHinter`) und das
/// entstandene Widget auf seinen Typ geprüft. Ob die Ziele danach richtig
/// aussehen, steht in ihren eigenen Dateien.
///
/// **Eine Ausnahme, mit Absicht:** Der Fall zu `docs/todo/32` schiebt ein
/// echtes Ziel auf einen echten `Navigator` und geht wieder zurück. Dafür
/// ist `ErholungWerteSeite` ausgewählt — sie kommt mit genau den
/// Providern aus, die diese Hülle ohnehin setzt. Ein Ziel, das nur gebaut
/// und nie gehängt wird, könnte beim Hängen immer noch werfen.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? trainingsminuten = 20,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: 13,
    exerciseMinutes: trainingsminuten,
  );

  SleepNight nachtVon(
    int tag, {
    double stunden = 7,
    List<SleepSession> naps = const [],
  }) {
    final ende = DateTime.utc(2026, 10, tag, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: naps,
    );
  }

  /// Ein Tagschlaf von 40 Minuten am Nachmittag.
  SleepSession tagschlaf() => SleepSession(
    segments: [
      SleepSegment(
        stage: SleepStage.core,
        start: DateTime.utc(2026, 10, 12, 12),
        end: DateTime.utc(2026, 10, 12, 12, 40),
      ),
    ],
  );

  /// `hrv` gilt für die neun Tage davor **und**, wenn `hrvHeute` fehlt,
  /// für heute. Getrennt, weil die Ampel der Verlaufszeilen heute gegen
  /// den Median der Tage davor vergleicht: Mit einem einzigen Wert für
  /// alle Tage sind die drei Farben nicht auseinanderzuhalten.
  List<DailyMetrics> tage({
    bool mitHeute = true,
    int? ruhepulsHeute = 52,
    double? hrv = 60,
    double? hrvHeute,
    double? trainingsminuten = 20,
  }) => [
    for (var t = 3; t <= 11; t++)
      tagwert(t, hrv: hrv, trainingsminuten: trainingsminuten),
    if (mitHeute)
      tagwert(
        12,
        ruhepuls: ruhepulsHeute,
        hrv: hrvHeute ?? hrv,
        trainingsminuten: trainingsminuten,
      ),
  ];

  List<SleepNight> naechte({
    bool mitHeute = true,
    double heuteStunden = 7,
    List<SleepSession> naps = const [],
  }) => [
    for (var t = 3; t <= 11; t++) nachtVon(t),
    if (mitHeute) nachtVon(12, stunden: heuteStunden, naps: naps),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.** Der Zustand wandert mit — ein gescheiterter Tageslauf
  /// bedeutet hier auch einen gescheiterten Nachtlauf.
  Messwert<Map<String, NightVitals>> nachtwerteAus(
    Messwert<List<DailyMetrics>> tageswerte,
  ) => switch (tageswerte) {
    Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in wert)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: stand, laeuft: laeuft),
    NochNie<List<DailyMetrics>>() => const NochNie<Map<String, NightVitals>>(),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
      LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<Map<String, NightVitals>>(
        fehler: fehler,
        gelaufen: gelaufen,
      ),
  };

  ({ProviderContainer container, AppRouter router, Widget app})
  harness({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
    Ziele ziele = Ziele.vorbelegung,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(() => _Tageswerte(tagesWert)),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster. Ohne diese Überschreibung liefe ein Widget-Test in
        // die echte drift-Datenbank — und die drei Werte blieben leer.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(tagesWert)),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  naechte(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(ziele)),
      ],
    );
    addTearDown(container.dispose);

    final inhalt = mitSeite
        ? ErholungSeite(router: router)
        : ErholungView(router: router);

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              // Entspricht der durchscheinenden Navigations- und Tableiste:
              // Nur mit echten Rändern hat `GlasAbstand` etwas zu tun.
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: inhalt,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist und kein
    // Test selbst scrollen muss.
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  RingKartenDaten ringe(WidgetTester tester) =>
      tester.widget<RingKarte>(find.byType(RingKarte)).daten;

  /// `true`, wenn irgendein Vorfahre dieses Elements ein `GestureDetector`
  /// mit gesetztem `onTap` oder ein `CupertinoButton` mit gesetztem
  /// `onPressed` ist — die beiden Wege, über die diese reine
  /// Cupertino-App etwas antippbar macht (wörtlich wie in
  /// `mehr_view_test.dart`).
  bool tippbar(Element element) {
    var gefunden = false;
    element.visitAncestorElements((vorfahre) {
      final widget = vorfahre.widget;
      if (widget is GestureDetector && widget.onTap != null) {
        gefunden = true;
        return false;
      }
      if (widget is CupertinoButton && widget.onPressed != null) {
        gefunden = true;
        return false;
      }
      return true;
    });
    return gefunden;
  }

  /// Seit dem 27.10.2026 **keine** `IconRow` mehr: Der Entwurf zeigt in
  /// den Verläufen keine Symbole, und `IconRow` ohne `symbol`/`accent`
  /// gibt es nicht. Die Zeile ist ein eigener Baustein.
  List<ErholungVerlaufsZeile> verlaufszeilen(WidgetTester tester) => tester
      .widgetList<ErholungVerlaufsZeile>(
        find.descendant(
          of: find.byKey(const Key('erholung-verlaeufe')),
          matching: find.byType(ErholungVerlaufsZeile),
        ),
      )
      .toList();

  ErholungVerlaufsZeile zeileMit(WidgetTester tester, String teil) =>
      verlaufszeilen(
        tester,
      ).firstWhere((z) => z.titel.toLowerCase().contains(teil));

  String datumszeile(WidgetTester tester) =>
      textUnter(tester, const Key('erholung-datumszeile'));

  String nachtText(WidgetTester tester) =>
      textUnter(tester, const Key('erholung-nachtkarte'));

  /// Alle Gruppenköpfe des Schirms, Titel und Zusatz.
  List<SectionHeader> gruppenkoepfe(WidgetTester tester) =>
      tester.widgetList<SectionHeader>(find.byType(SectionHeader)).toList();

  /// Baut das Ziel eines abgeholten Router-Befehls — **ohne es zu hängen.**
  ///
  /// `builder` ist ein `WidgetBuilder`; mit dem Kontext des gerade
  /// stehenden Schirms aufgerufen liefert er genau das Widget, das auf den
  /// Stapel käme. Es nur zu bauen genügt für „welcher Schirm ist das" und
  /// erspart dieser Datei den Provider-Unterbau von fünf fremden Schirmen
  /// (siehe Nachtrag im Dateikopf). Der aktuelle Baum bleibt stehen.
  Widget schirmHinter(WidgetTester tester, AppRouterBefehl befehl) =>
      befehl.builder(tester.element(find.byType(ErholungView)));

  // ───────────────────────────────────────────────────────────────────────

  group('Die vier Zustände', () {
    testWidgets(
      'während des Ladens steht nirgends ein „keine Daten"-Grund '
      '(docs/todo/01)',
      (tester) async {
        final h = harness(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        );
        await zeige(tester, h.app);

        expect(find.byKey(const Key('erholung-laden')), findsOneWidget);
        expect(find.byType(RingKarte), findsNothing);
        expect(find.byType(Hypnogramm), findsNothing);
        expect(find.byKey(const Key('erholung-verlaeufe')), findsNothing);
        expect(
          find.byKey(const Key('erholung-health-einstellungen')),
          findsNothing,
        );

        final texte = alleTexte(tester);
        expect(
          texte,
          isNot(contains('aufgezeichnet')),
          reason: 'der Grund gehört zu einem FERTIGEN Lauf ohne Treffer',
        );
        expect(texte, isNot(contains('freigegeben')));
      },
    );

    testWidgets(
      'was keine Health-Daten braucht, steht auch während des Ladens: '
      'Datumszeile, Tipps, Fußnote',
      (tester) async {
        final h = harness(
          tageswerte: const NochNie<List<DailyMetrics>>(),
          schlaf: const NochNie<List<SleepNight>>(),
        );
        await zeige(tester, h.app);

        expect(
          find.byKey(const Key('erholung-datumszeile')),
          findsOneWidget,
          reason: 'Abschnitt 1 hängt nicht an Apple Health',
        );
        expect(find.byKey(const Key('erholung-tipps')), findsOneWidget);
        expect(find.byType(Hinweisfuss), findsOneWidget);
      },
    );

    testWidgets('mit Werten stehen Ringkarte, Nachtkarte und Verläufe', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byType(RingKarte), findsOneWidget);
      expect(find.byKey(const Key('erholung-nachtkarte')), findsOneWidget);
      expect(find.byType(Hypnogramm), findsOneWidget);
      expect(verlaufszeilen(tester), hasLength(5));
      expect(find.byKey(const Key('erholung-laden')), findsNothing);
    });

    testWidgets(
      'nach einem fertigen Lauf ohne Treffer stehen beide Möglichkeiten und '
      'der Weg in die Health-Einstellungen',
      (tester) async {
        final h = harness(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        expect(texte, contains('aufgezeichnet'));
        expect(texte, contains('freigegeben'));
        expect(
          find.byKey(const Key('erholung-health-einstellungen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('erholung-schlaf-nachtragen')),
          findsOneWidget,
          reason:
              'seit dem 27.10.2026 stehen hier zwei Wege nebeneinander — '
              'siehe die Gruppe „Zwei Knöpfe, keiner hervorgehoben"',
        );
      },
    );

    testWidgets(
      'ein gescheiterter Lauf behauptet nicht, es gäbe keine Daten — ein '
      'Fehler ist keine Aussage über die Datenlage',
      (tester) async {
        final h = harness(
          tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
            fehler: Exception('Kanal nicht erreichbar'),
            gelaufen: jetzt,
          ),
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: Exception('Kanal nicht erreichbar'),
            gelaufen: jetzt,
          ),
        );
        await zeige(tester, h.app);

        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('aufgezeichnet')));
        expect(texte, isNot(contains('freigegeben')));
        expect(
          find.byKey(const Key('erholung-health-einstellungen')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Tageswerte da, Schlaf noch unterwegs: die Nachtkarte nennt keinen '
      'Grund, solange der Lauf läuft',
      (tester) async {
        final h = harness(schlaf: const NochNie<List<SleepNight>>());
        await zeige(tester, h.app);

        expect(find.byType(RingKarte), findsOneWidget);
        final nacht = textUnter(
          tester,
          const Key('erholung-nachtkarte'),
        ).toLowerCase();
        expect(nacht, isNot(contains('aufgezeichnet')));
        expect(nacht, isNot(contains('freigegeben')));
      },
    );
  });

  group('Der Hinweiskasten', () {
    testWidgets('an einem ruhigen Tag fällt er weg, die Ringe bleiben', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        ringe(tester).erholung.mitte,
        '0',
        reason: 'keine Signale — sonst prüft dieser Test den falschen Fall',
      );
      expect(find.byKey(const Key('erholung-hinweiskasten')), findsNothing);
      expect(find.byType(RingKarte), findsOneWidget);
    });

    testWidgets('bei einem Warnsignal steht er da', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          naechte(heuteStunden: 5),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(ringe(tester).erholung.mitte, '1');
      expect(find.byKey(const Key('erholung-hinweiskasten')), findsOneWidget);
      expect(
        find.byKey(const Key('erholung-health-einstellungen')),
        findsNothing,
        reason: 'der Knopf gehört zu „keine Werte", nicht zu „Warnsignal"',
      );
    });

    testWidgets('bei zwei Warnsignalen ebenso', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(ruhepulsHeute: 60),
          stand: jetzt,
          laeuft: false,
        ),
        schlaf: Bekannt<List<SleepNight>>(
          naechte(heuteStunden: 5),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(ringe(tester).erholung.mitte, '2');
      expect(find.byKey(const Key('erholung-hinweiskasten')), findsOneWidget);
      expect(
        find.byKey(const Key('erholung-health-einstellungen')),
        findsNothing,
      );
    });

    testWidgets(
      'liegen heute gar keine Werte vor, nennt der Kasten beide '
      'Möglichkeiten und der Health-Knopf erscheint',
      (tester) async {
        final h = harness(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tage(mitHeute: false),
            stand: jetzt,
            laeuft: false,
          ),
          schlaf: Bekannt<List<SleepNight>>(
            naechte(mitHeute: false),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        expect(
          ringe(tester).erholung.caption,
          'keine Werte',
          reason: 'der Erholungsring kennt den noData-Fall aus #114',
        );
        expect(find.byKey(const Key('erholung-hinweiskasten')), findsOneWidget);

        final kasten = textUnter(
          tester,
          const Key('erholung-hinweiskasten'),
        ).toLowerCase();
        expect(kasten, contains('aufgezeichnet'));
        expect(kasten, contains('freigegeben'));
        expect(
          find.byKey(const Key('erholung-health-einstellungen')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('erholung-schlaf-nachtragen')),
          findsOneWidget,
        );
      },
    );
  });

  // ## Zwei Knöpfe, keiner hervorgehoben (Nachtrag 27.10.2026)
  //
  // Tim hat den Entwurf freigegeben (`docs/screens/screens/erholung.js`,
  // Zustand `keine-daten`): Unter dem Hinweiskasten stehen jetzt **zwei**
  // Knöpfe nebeneinander statt einem.
  //
  // - `Key('erholung-health-einstellungen')` — gibt es schon.
  // - `Key('erholung-schlaf-nachtragen')` — neu, „Schlaf manuell
  //   hinzufügen".
  //
  // **Warum beide gleich gewichtet sind, und warum das ein Zustand ist
  // und keine Gestaltung:** Der Satz darüber sagt ausdrücklich „Beides
  // sieht von hier gleich aus" — die App kann nicht unterscheiden, ob die
  // Uhr nichts aufgezeichnet hat oder ob sie nicht lesen darf. Einen der
  // beiden Knöpfe hervorzuheben wäre eine Vermutung darüber, welcher der
  // beiden Fälle vorliegt, und genau die weiß die App nicht. Der Test
  // prüft deshalb nicht Farbe oder Abstand, sondern die eine strukturelle
  // Eigenschaft, die „hervorgehoben" in Cupertino ausmacht: ein
  // `CupertinoButton` mit gesetztem `color` (das ist `CupertinoButton.
  // filled`) gegen einen ohne.
  //
  // ### Was der neue Knopf heute tut — festgelegt, nicht offen gelassen
  //
  // **Er öffnet einen Hinweis auf diesem Schirm und navigiert nirgendwo
  // hin.** Begründung:
  //
  // - Das Eintrage-Formular ist laut Entwurf kein eigener Schirm, sondern
  //   ein *Zustand* von `schlaf`. Auf dem Board hat der Knopf deshalb den
  //   grauen Punkt: kein Ziel.
  // - Ihn auf den Schlaf-Schirm zu legen wäre schlimmer als nichts — der
  //   sagt „Schlaf" und kein Wort über das Nachtragen. Wer ihn drückt,
  //   landete auf einer Seite, die seine Frage nicht beantwortet, und
  //   hielte sie für die Funktion.
  //
  //   *(Stand 28.10.2026: Am 27.10. stand hier zusätzlich, den
  //   Schlaf-Schirm gebe es noch gar nicht. Es gibt ihn jetzt — das
  //   Formular darin aber nicht, das ist #131. Die Begründung trägt also
  //   unverändert weiter, nur ihr erster Halbsatz ist weggefallen.)*
  // - Ein Knopf, der gar nichts tut, ist unehrlich; ein Hinweis, der
  //   sagt, dass es die Funktion noch nicht gibt, ist es nicht. Genau
  //   diesen Weg geht der Health-Knopf bereits (`app/` hat kein
  //   `url_launcher`, also nennt er den Weg in Worten statt
  //   `x-apple-health://` zu öffnen) — zwei Knöpfe nebeneinander, die
  //   sich verschieden verhalten, wären die schlechtere Antwort.
  //
  // Verlangt wird also: `h.router.nimmBefehl()` bleibt `null`, und es
  // geht etwas auf. **Welcher Satz im Hinweis steht, ist nicht geprüft**
  // (`CLAUDE.md`: keine Beschriftungstests) — aber *dass* der Knopf
  // beschriftet ist und nicht bloß ein Zeichen trägt, schon: Ein
  // unbeschrifteter Knopf an dieser Stelle wäre genau das Plus, das der
  // Entwurf von der Nachtkarte entfernt hat.
  group('Zwei Knöpfe, keiner hervorgehoben (27.10.2026)', () {
    Messwert<List<DailyMetrics>> tageswerteOhneHeute() =>
        Bekannt<List<DailyMetrics>>(
          tage(mitHeute: false),
          stand: jetzt,
          laeuft: false,
        );

    Messwert<List<SleepNight>> naechteOhneHeute() => Bekannt<List<SleepNight>>(
      naechte(mitHeute: false),
      stand: jetzt,
      laeuft: false,
    );

    /// Der `CupertinoButton` unter (oder auf) diesem Schlüssel. `matchRoot`,
    /// weil nicht Sache dieses Tests ist, ob der Schlüssel auf dem Knopf
    /// selbst oder einen Schritt darüber sitzt.
    CupertinoButton knopf(WidgetTester tester, Key schluessel) =>
        tester.widget<CupertinoButton>(
          find
              .descendant(
                of: find.byKey(schluessel),
                matching: find.byType(CupertinoButton),
                matchRoot: true,
              )
              .first,
        );

    testWidgets('bei „keine Werte" stehen beide nebeneinander', (tester) async {
      final h = harness(
        tageswerte: tageswerteOhneHeute(),
        schlaf: naechteOhneHeute(),
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('erholung-health-einstellungen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('erholung-schlaf-nachtragen')),
        findsOneWidget,
      );
    });

    testWidgets('der neue Knopf ist beschriftet, nicht bloß ein Zeichen', (
      tester,
    ) async {
      final h = harness(
        tageswerte: tageswerteOhneHeute(),
        schlaf: naechteOhneHeute(),
      );
      await zeige(tester, h.app);

      final text = textUnter(
        tester,
        const Key('erholung-schlaf-nachtragen'),
      ).trim();
      expect(text, isNotEmpty);
      expect(
        text.toLowerCase(),
        contains('schlaf'),
        reason:
            'der Knopf sagt, worum es geht — der genaue Satz ist nicht '
            'festgeschrieben',
      );
    });

    testWidgets(
      'keiner der beiden ist hervorgehoben — das wäre eine Vermutung '
      'darüber, welcher der beiden Fälle vorliegt',
      (tester) async {
        final h = harness(
          tageswerte: tageswerteOhneHeute(),
          schlaf: naechteOhneHeute(),
        );
        await zeige(tester, h.app);

        for (final schluessel in const [
          Key('erholung-health-einstellungen'),
          Key('erholung-schlaf-nachtragen'),
        ]) {
          expect(
            knopf(tester, schluessel).color,
            isNull,
            reason:
                '$schluessel: ein gesetztes `color` ist '
                '`CupertinoButton.filled` — der gefüllte Knopf ist der '
                'hervorgehobene. „Beides sieht von hier gleich aus"',
          );
        }
      },
    );

    testWidgets(
      'der neue Knopf löst etwas aus und springt dabei in keinen anderen '
      'Schirm — die Funktion gibt es noch nicht (#92)',
      (tester) async {
        final h = harness(
          mitSeite: true,
          tageswerte: tageswerteOhneHeute(),
          schlaf: naechteOhneHeute(),
        );
        await zeige(tester, h.app);

        final vorher = find.byType(ModalBarrier).evaluate().length;

        await tester.tap(find.byKey(const Key('erholung-schlaf-nachtragen')));
        await tester.pumpAndSettle();

        expect(
          h.router.nimmBefehl(),
          isNull,
          reason:
              'ein Schirm zum Eintragen einer Nacht existiert nicht '
              '(#131); ein Sprung auf den Schlaf-Schirm sähe aus wie die '
              'Funktion und wäre keine',
        );
        expect(
          find.byType(ModalBarrier).evaluate().length,
          greaterThan(vorher),
          reason:
              'ein Knopf, der nichts tut, ist derselbe Fehler wie eine '
              'stumme Zeile, die aussieht wie eine Tür',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'und er steht nur, wo nichts da ist — nicht an einem ruhigen Tag, '
      'nicht bei einem Warnsignal, nicht während des Laufs, nicht nach '
      'einem Fehler',
      (tester) async {
        final faelle = <String, Messwert<List<SleepNight>>?>{
          'ruhig': null,
          'Warnsignal': Bekannt<List<SleepNight>>(
            naechte(heuteStunden: 5),
            stand: jetzt,
            laeuft: false,
          ),
          'noch unterwegs': const NochNie<List<SleepNight>>(),
          'gescheitert': Fehlgeschlagen<List<SleepNight>>(
            fehler: Exception('Kanal nicht erreichbar'),
            gelaufen: jetzt,
          ),
        };

        for (final fall in faelle.entries) {
          final h = harness(schlaf: fall.value);
          await zeige(tester, h.app);

          expect(
            find.byKey(const Key('erholung-schlaf-nachtragen')),
            findsNothing,
            reason:
                '${fall.key}: der Knopf gehört zu „keine Werte", genau wie '
                'der Health-Knopf daneben',
          );
        }
      },
    );
  });

  group('Die Nachtkarte folgt dem Entwurf (27.10.2026)', () {
    testWidgets('der Gruppenkopf heißt „Schlaf" und trägt keinen Knopf', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final koepfe = gruppenkoepfe(tester);
      final schlaf = koepfe.where((k) => k.title == 'Schlaf');
      expect(
        schlaf,
        hasLength(1),
        reason: 'der Entwurf schreibt `groupHead(\'Schlaf\')`',
      );
      expect(
        schlaf.single.zusatz,
        isNull,
        reason:
            'kein „ganze Nacht ›" — der Entwurf hat dort nichts, und auf '
            'den Schlaf-Schirm führt seit #259 nur noch der Ring',
      );
      expect(
        koepfe.where((k) => k.title == 'Letzte Nacht'),
        isEmpty,
        reason: 'der alte Titel',
      );
    });

    testWidgets(
      'rechts steht der Score gegen seine erreichbare Punktzahl, nicht die '
      'nackte Zahl mit „Score" darunter',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        // Dieselbe Zahl, die der Schlafring in der Mitte trägt — so hängt
        // der Test an keiner erfundenen Punktzahl.
        final gesamt = ringe(tester).schlaf.mitte;
        expect(
          nachtText(tester),
          contains('$gesamt / 100'),
          reason:
              'der Entwurf zeigt „82 / 100". Diese Nacht hat eine '
              'Einschlafzeit, also sind 100 Punkte erreichbar',
        );
        expect(
          nachtText(tester),
          isNot(contains('Score')),
          reason: 'die Bezugsgröße steht jetzt in der Zahl selbst',
        );
      },
    );

    testWidgets(
      'darunter steht das Datum vor den Uhrzeiten — ohne Chevron, seit die '
      'Karte keine Tür mehr ist (#259)',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final zeile = nachtText(tester);
        // Die Nacht von So 11.10. auf Mo 12.10. Genannt wird der **Abend**,
        // an dem sie begann (Entwurfskommentar vom 27.10.): „Gemeint ist
        // die Nacht, die die Datumszeile oben als ‚Nacht von So auf Mo'
        // führt, und zwei verschiedene Daten für dieselbe Nacht auf einem
        // Schirm wären schlimmer als gar keins."
        final abend = DateTime.utc(2026, 10, 11);
        expect(zeile, contains(Format.wochentagKurz(abend)));
        expect(zeile, contains('11.10.'));
        expect(
          zeile,
          isNot(contains('12.10.')),
          reason: 'der Morgen danach ist nicht gemeint',
        );

        final uhrzeit = RegExp(r'\d{2}:\d{2}').firstMatch(zeile);
        expect(uhrzeit, isNotNull, reason: 'die Uhrzeiten stehen weiter da');
        expect(
          zeile.indexOf('11.10.'),
          lessThan(uhrzeit!.start),
          reason: 'Datum, dann Uhrzeiten — Tims Entscheidung vom 27.10.',
        );
        expect(
          zeile,
          isNot(contains('›')),
          reason:
              'ohne Tür kein Winkel — ein „›" hinter dem Zeitfenster '
              'verspräche einen Sprung, den es seit #259 nicht mehr gibt',
        );
      },
    );

    testWidgets(
      'auch eine Nacht, in der das Einschlafen nach Mitternacht lag, trägt '
      'das Datum des Abends',
      (tester) async {
        // 01:10 bis 06:00 Berliner Zeit am 12.10. — die Nacht beginnt
        // kalendarisch am 12., gehört aber zum Abend des 11.
        final spaet = SleepNight(
          date: tagesbeginn(12),
          session: SleepSession(
            segments: [
              SleepSegment(
                stage: SleepStage.core,
                start: DateTime.utc(2026, 10, 11, 23, 10),
                end: DateTime.utc(2026, 10, 12, 4),
              ),
            ],
          ),
        );
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>([
            for (var t = 3; t <= 11; t++) nachtVon(t),
            spaet,
          ], stand: jetzt, laeuft: false),
        );
        await zeige(tester, h.app);

        expect(nachtText(tester), contains('11.10.'));
        expect(nachtText(tester), isNot(contains('12.10.')));
      },
    );

    testWidgets(
      'an der Nachtkarte ist nichts antippbar — weder der Kopf noch das '
      'Hypnogramm (#259)',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final bild = find.byType(Hypnogramm).evaluate().single;
        expect(
          tippbar(bild),
          isFalse,
          reason:
              'wer in ein Diagramm tippt, will es lesen — nicht '
              'wegnavigieren',
        );

        final kopf = find.byKey(const Key('erholung-nacht-kopf'));
        expect(
          kopf,
          findsOneWidget,
          reason:
              'der Kopf bleibt stehen — Dauer, Zeitfenster und Score '
              'tragen Auskunft. Weg fällt nur die Tür',
        );
        // Über die Texte **in** der Fläche, nicht über die Fläche selbst:
        // `tippbar` sieht nur Vorfahren, und ob der Schlüssel auf dem
        // `Padding` oder einen Schritt darüber sitzt, ist nicht Sache
        // dieses Tests.
        final texte = find
            .descendant(of: kopf, matching: find.byType(Text))
            .evaluate();
        expect(
          texte,
          isNotEmpty,
          reason: 'Schlafdauer, Score und das Zeitfenster stehen da',
        );
        for (final text in texte) {
          expect(
            tippbar(text),
            isFalse,
            reason:
                'auf den Schlaf-Schirm führt seit #259 nur noch der Ring '
                'oben (Tim, 03.11.2026)',
          );
        }
      },
    );
  });

  group('Die Nachtkarte und der Tagschlaf', () {
    testWidgets(
      'ohne Nacht steht „—" und beide Möglichkeiten, nie eine Null',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            naechte(mitHeute: false),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final nacht = textUnter(tester, const Key('erholung-nachtkarte'));
        expect(nacht, contains('—'));
        expect(nacht.toLowerCase(), contains('aufgezeichnet'));
        expect(nacht.toLowerCase(), contains('freigegeben'));
        expect(
          RegExp(r'(^|\D)0(\D|$)').hasMatch(nacht),
          isFalse,
          reason: 'ein fehlender Einzelwert steht als „—", nie als „0"',
        );
        expect(find.byType(Hypnogramm), findsNothing);
        expect(
          ringe(tester).schlaf.mitte,
          '—',
          reason: 'auch der Schlafring erfindet keine Null',
        );
      },
    );

    testWidgets('ohne Tagschlaf gibt es keine Tagschlaf-Kachel', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('erholung-tagschlaf')), findsNothing);
    });

    testWidgets('mit Tagschlaf erscheint sie', (tester) async {
      final h = harness(
        schlaf: Bekannt<List<SleepNight>>(
          naechte(naps: [tagschlaf()]),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('erholung-tagschlaf')), findsOneWidget);
    });

    testWidgets(
      'die Tagschlaf-Kachel führt nach `tagschlaf`, nicht nach `schlaf`',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            naechte(naps: [tagschlaf()]),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('erholung-tagschlaf')));
        await tester.pump();

        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull);
        expect(befehl!.ersetztStapel, isFalse);
        expect(befehl.tab, h.router.tab);

        final ziel = schirmHinter(tester, befehl);
        expect(ziel, isA<TagschlafSeite>());
        expect(
          ziel,
          isNot(isA<SchlafSeite>()),
          reason:
              'die Kachel führt auf den Tagschlaf, nicht in die Nacht — auf '
              'dem Schlaf-Schirm stünde die Nacht oben und das Nickerchen '
              'weit unten, also das Gegenteil von dem, was man beim '
              'Antippen sucht (`napCard` im Entwurf)',
        );
      },
    );
  });

  group('Türen', () {
    testWidgets(
      'die drei Ringe führen auf drei verschiedene Schirme, jeder über '
      'AppTarget.aktuell und ohne Tabwechsel',
      (tester) async {
        final gefunden = <Widget>[];

        for (final beschriftung in const [
          'SCHLAF',
          'ERHOLUNG',
          'BELASTUNG',
        ]) {
          final h = harness();
          await zeige(tester, h.app);
          final tabVorher = h.router.tab;

          // Eingegrenzt auf die Ringkarte: Seit der Gruppenkopf „Schlaf"
          // heißt und `SectionHeader` ihn groß schreibt, steht „SCHLAF"
          // zweimal auf dem Schirm — einmal als Ringspalte, einmal als
          // Kopf. Beide sind richtig; gemeint ist hier die Spalte.
          await tester.tap(
            find.descendant(
              of: find.byType(RingKarte),
              matching: find.text(beschriftung),
            ),
          );
          await tester.pump();

          final befehl = h.router.nimmBefehl();
          expect(befehl, isNotNull, reason: beschriftung);
          expect(
            h.router.tab,
            tabVorher,
            reason: '"$beschriftung" wechselt nie den Tab — jeder Tab führt '
                'seinen eigenen Stapel',
          );
          expect(
            befehl!.ersetztStapel,
            isFalse,
            reason: '"$beschriftung": geschoben, nicht ersetzt',
          );
          expect(befehl.tab, h.router.tab, reason: beschriftung);

          gefunden.add(schirmHinter(tester, befehl));
        }

        expect(gefunden[0], isA<SchlafSeite>(), reason: 'SCHLAF');
        expect(gefunden[1], isA<ErholungWerteSeite>(), reason: 'ERHOLUNG');
        expect(gefunden[2], isA<BelastungSeite>(), reason: 'BELASTUNG');
        expect(
          gefunden.map((schirm) => schirm.runtimeType).toSet(),
          hasLength(3),
          reason: 'drei Ringe, drei verschiedene Schirme',
        );
      },
    );

    testWidgets('die Nachtkarte führt nirgendwohin — der Ring ist der '
        'einzige Weg auf den Schlaf-Schirm (#259)', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      // Auf den Kopf der Karte, nicht auf die ganze Karte: Dort lag bis
      // zum 03.11.2026 die zweite Tür, und genau sie soll weg sein.
      await tester.tap(
        find.byKey(const Key('erholung-nacht-kopf')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(
        h.router.nimmBefehl(),
        isNull,
        reason:
            'Tim am 03.11.2026: „auf die Schlaf-Seite nur noch über den '
            'Ring oben auf der Erholungsseite kommen". Wer die Karte '
            'antippt, landete sonst überraschend auf einem Schirm, den er '
            'über den Ring kennt',
      );
    });

    testWidgets(
      'das Fragezeichen ist keine Tür, tut aber etwas — ein Knopf, der '
      'nichts auslöst, ist derselbe Fehler wie eine stumme Zeile',
      (tester) async {
        final h = harness(mitSeite: true);
        await zeige(tester, h.app);

        final vorher = find.byType(ModalBarrier).evaluate().length;

        await tester.tap(find.text('?'));
        await tester.pumpAndSettle();

        expect(
          h.router.nimmBefehl(),
          isNull,
          reason: 'die Hilfe ist kein Sprung in einen anderen Schirm',
        );
        expect(
          find.byType(ModalBarrier).evaluate().length,
          greaterThan(vorher),
          reason: 'etwas ist aufgegangen',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren — '
      'eine Zeile, die drückbar aussieht und nirgendwohin führt, ist ein '
      'Fehler (docs/screens/pruefen.mjs)',
      (tester) async {
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            naechte(naps: [tagschlaf()]),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final pfeile = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
        );
        for (final element in pfeile.evaluate()) {
          expect(
            tippbar(element),
            isTrue,
            reason: 'ein Chevron ohne Tür dahinter',
          );
        }

        final pfeilTexte = find.byWidgetPredicate(
          (w) => w is Text && textOf(w).contains('›'),
        );
        for (final element in pfeilTexte.evaluate()) {
          expect(
            tippbar(element),
            isTrue,
            reason: '„${textOf(element.widget as Text)}" sieht aus wie eine '
                'Tür, ist aber keine',
          );
        }
      },
    );

    testWidgets(
      'die vier Messwert-Zeilen führen weiter, die Alkohol-Zeile nicht',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        for (final zeile in verlaufszeilen(tester)) {
          final istAlkohol = zeile.titel.toLowerCase().contains('alkohol');
          expect(
            zeile.onTap,
            istAlkohol ? isNull : isNotNull,
            reason:
                '"${zeile.titel}": die Alkohol-Zeile bleibt stumm, bis die '
                'Eingabe gebaut ist — die vier Messwerte führen auf ihren '
                'Verlauf',
          );
        }
      },
    );

    testWidgets(
      'auch die Atemfrequenz — Winkel und Tür gehören zusammen',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          zeileMit(tester, 'atem').onTap,
          isNotNull,
          reason:
              'Tims Befund vom 27.10.2026: „Bei der Atemfrequenz fehlt der '
              'Pfeil." Ein Pfeil ohne Ziel wäre die falsche Hälfte der '
              'Abhilfe',
        );
      },
    );

    testWidgets(
      'ein Winkel steht genau an den Zeilen, die weiterführen',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final mitTuer = verlaufszeilen(
          tester,
        ).where((z) => z.onTap != null).length;
        final winkel = find.descendant(
          of: find.byKey(const Key('erholung-verlaeufe')),
          matching: find.byWidgetPredicate(
            (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
          ),
        );

        expect(
          winkel.evaluate(),
          hasLength(mitTuer),
          reason:
              'keiner zu wenig (Tims Befund zur Atemfrequenz) und keiner '
              'zu viel (eine Zeile, die drückbar aussieht und nirgendwohin '
              'führt, ist ein Fehler)',
        );
      },
    );

    testWidgets(
      'und hinter dem Winkel liegt der Verlauf — der *dieser* Zeile',
      (tester) async {
        const erwartet = <String, VerlaufArt>{
          'hrv': VerlaufArt.hrv,
          'ruhepuls': VerlaufArt.ruhepuls,
          'atem': VerlaufArt.atemfrequenz,
          'schlaf': VerlaufArt.schlaf,
        };

        for (final fall in erwartet.entries) {
          final h = harness();
          await zeige(tester, h.app);
          final tabVorher = h.router.tab;

          zeileMit(tester, fall.key).onTap!();
          await tester.pump();

          final befehl = h.router.nimmBefehl();
          expect(befehl, isNotNull, reason: fall.key);
          expect(befehl!.ersetztStapel, isFalse, reason: fall.key);
          expect(befehl.tab, tabVorher, reason: fall.key);

          final ziel = schirmHinter(tester, befehl);
          expect(ziel, isA<VerlaufSeite>(), reason: fall.key);
          expect(
            (ziel as VerlaufSeite).art,
            fall.value,
            reason:
                '„${fall.key}": wer die HRV-Zeile antippt, will den '
                'HRV-Verlauf sehen und nicht irgendeinen. Alle vier auf '
                'denselben Schirm zu schicken war die Platzhalter-Lösung',
          );
        }
      },
    );

    // Dieser Fall übernimmt den Wächter, der bis zum 28.10.2026 als
    // `ErholungTuer.values hasLength(6)` in `erholung_zustand_test.dart`
    // stand: Ohne den Aufzählungstyp ist die Zahl der Türen nur noch am
    // Schirm selbst ablesbar. Seit #259 (03.11.2026) sind es fünf statt
    // sechs — der Kopf der Nachtkarte ist keine Tür mehr. Er prüft
    // außerdem für **jede** Tür dasselbe
    // dreifache „auf den Stapel des aktuellen Tabs, geschoben statt
    // ersetzt" — die Hausregel aus `CLAUDE.md`, an der ein einzelner
    // vergessener Sprung sonst durchrutschte.
    testWidgets('fünf Türen, und jede landet auf einem gebauten Schirm', (
      tester,
    ) async {
      final tueren =
          <String, (Future<void> Function(WidgetTester), TypeMatcher<Widget>)>{
            'Ring SCHLAF': (
              (t) => t.tap(
                find.descendant(
                  of: find.byType(RingKarte),
                  matching: find.text('SCHLAF'),
                ),
              ),
              isA<SchlafSeite>(),
            ),
            'Ring ERHOLUNG': (
              (t) => t.tap(
                find.descendant(
                  of: find.byType(RingKarte),
                  matching: find.text('ERHOLUNG'),
                ),
              ),
              isA<ErholungWerteSeite>(),
            ),
            'Ring BELASTUNG': (
              (t) => t.tap(
                find.descendant(
                  of: find.byType(RingKarte),
                  matching: find.text('BELASTUNG'),
                ),
              ),
              isA<BelastungSeite>(),
            ),
            'Tagschlaf-Kachel': (
              (t) => t.tap(find.byKey(const Key('erholung-tagschlaf'))),
              isA<TagschlafSeite>(),
            ),
            'Verlaufszeile': (
              (t) async => zeileMit(t, 'hrv').onTap!(),
              isA<VerlaufSeite>(),
            ),
          };

      expect(
        tueren,
        hasLength(5),
        reason: 'fünf Türen führen von diesem Schirm weg',
      );

      for (final fall in tueren.entries) {
        // Mit Tagschlaf, sonst gibt es die Kachel gar nicht.
        final h = harness(
          schlaf: Bekannt<List<SleepNight>>(
            naechte(naps: [tagschlaf()]),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);
        final tabVorher = h.router.tab;

        await fall.value.$1(tester);
        await tester.pump();

        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull, reason: fall.key);
        expect(
          h.router.tab,
          tabVorher,
          reason: '${fall.key}: wechselt nie den Tab',
        );
        expect(
          befehl!.ersetztStapel,
          isFalse,
          reason: '${fall.key}: geschoben, nicht ersetzt',
        );
        expect(befehl.tab, tabVorher, reason: fall.key);
        expect(schirmHinter(tester, befehl), fall.value.$2, reason: fall.key);
      }
    });

    testWidgets(
      'eine Verlaufszeile ohne Werte zeigt „—", nicht „0"',
      (tester) async {
        final h = harness(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tage(hrv: null),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final hrv = zeileMit(tester, 'hrv');
        expect(hrv.wert, isNotNull);
        expect(hrv.wert, contains('—'));
        expect(hrv.wert, isNot(contains('0')));
      },
    );
  });

  // Siehe Nachtrag im Dateikopf, „Der neue Vertrag von
  // `ErholungVerlaeufe.onVerlauf`". Der Abschnitt wird hier **für sich**
  // gepumpt und nicht über den ganzen Schirm: Geprüft wird der Vertrag des
  // Bausteins, und der gilt unabhängig davon, wer ihn einsetzt. Dass der
  // Schirm ihn richtig verdrahtet, steht in der Gruppe „Türen".
  group('Die Verlaufszeilen tragen ihre Art (28.10.2026)', () {
    /// Alle fünf Zeilen, in der Reihenfolge von [RecoveryTrendKind] — die
    /// ist der Vertrag des Kerns („Die fünf Verlaufszeilen in der
    /// Reihenfolge von `RecoveryTrendKind`", `RecoverySnapshot.trends`).
    List<RecoveryTrend> alleTrends() => [
      for (final art in RecoveryTrendKind.values)
        RecoveryTrend(kind: art, average: null, count: 9),
    ];

    /// Erfundene Zahlen, wie alles in dieser Datei. Messwert und
    /// Vergleichswert gleich, damit keine Zeile aus einem anderen Grund
    /// als dem geprüften anders aussieht.
    const werte = RecoveryReading(
      sleepHours: 7,
      restingHeartRate: 52,
      hrv: 60,
      respiratoryRate: 13,
    );
    const mediane = RecoveryBaseline(
      sleepHours: 7,
      restingHeartRate: 52,
      hrv: 60,
      respiratoryRate: 13,
    );

    Widget abschnitt(void Function(VerlaufArt art) onVerlauf) => CupertinoApp(
      home: CupertinoPageScaffold(
        // Scrollend, damit fünf Zeilen auf der Standardfläche nicht
        // überlaufen — der Test liest Widgets, nicht Pixel.
        child: SingleChildScrollView(
          child: ErholungVerlaeufe(
            trends: alleTrends(),
            messwerte: werte,
            baseline: mediane,
            onVerlauf: onVerlauf,
          ),
        ),
      ),
    );

    List<ErholungVerlaufsZeile> zeilen(WidgetTester tester) => tester
        .widgetList<ErholungVerlaufsZeile>(
          find.byType(ErholungVerlaufsZeile),
        )
        .toList();

    testWidgets(
      'eine Zeile ist genau dann eine Tür, wenn `verlaufArtZu` eine Art '
      'kennt — entschieden wird das nicht am Titel',
      (tester) async {
        await tester.pumpWidget(abschnitt((_) {}));

        final arten = RecoveryTrendKind.values;
        expect(zeilen(tester), hasLength(arten.length));

        for (var i = 0; i < arten.length; i++) {
          final art = verlaufArtZu(arten[i]);
          expect(
            zeilen(tester)[i].onTap,
            art == null ? isNull : isNotNull,
            reason:
                '${arten[i].name}: `verlaufArtZu` liefert $art — `null` '
                'heißt „keine Tür", und das ist die eine Stelle, an der '
                'diese Entscheidung steht',
          );
        }
      },
    );

    testWidgets('und beim Antippen meldet sie genau ihre eigene Art', (
      tester,
    ) async {
      final gemeldet = <VerlaufArt>[];
      await tester.pumpWidget(abschnitt(gemeldet.add));

      for (final zeile in zeilen(tester)) {
        zeile.onTap?.call();
      }

      expect(
        gemeldet,
        const [
          VerlaufArt.schlaf,
          VerlaufArt.hrv,
          VerlaufArt.ruhepuls,
          VerlaufArt.atemfrequenz,
        ],
        reason:
            'der Rückruf trägt die Art, nicht nur „irgendeine Zeile wurde '
            'gedrückt" — und die Alkohol-Zeile meldet gar nichts, statt '
            'eine Art zu erfinden',
      );
    });

    testWidgets(
      'die stumme Zeile ist auch im Baum stumm: kein Winkel, kein '
      'tippbarer Vorfahre',
      (tester) async {
        await tester.pumpWidget(abschnitt((_) {}));

        final ohneTuer = zeilen(tester).where((z) => z.onTap == null);
        expect(ohneTuer, hasLength(1), reason: 'genau die Alkohol-Zeile');

        final winkel = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
        );
        expect(
          winkel.evaluate(),
          hasLength(zeilen(tester).length - 1),
          reason:
              'ein Winkel steht genau an den Zeilen, die weiterführen — '
              'eine Zeile, die drückbar aussieht und nirgendwohin führt, '
              'ist der Fehler, den `docs/screens/pruefen.mjs` sucht',
        );
      },
    );
  });

  // Siehe Nachtrag im Dateikopf, Punkt 4. Die Schwellen selbst stehen in
  // `erholung_verlaufston_test.dart`; hier geht es darum, dass die Zeile
  // Messwert, Vergleichswert und Farbe überhaupt trägt.
  group('Die Verlaufszeilen folgen dem Entwurf (27.10.2026)', () {
    testWidgets('keine Zeile trägt ein Symbol — der Entwurf hat keine', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byKey(const Key('erholung-verlaeufe')),
          matching: find.byType(IconRow),
        ),
        findsNothing,
        reason:
            '`IconRow` bringt eine farbige Symbolkachel mit; der Entwurf '
            'zeigt in `trendRow` Titel, Vergleichswert und Wert',
      );
      expect(verlaufszeilen(tester), hasLength(5));
    });

    testWidgets(
      'rechts steht der heutige Messwert, der Vergleichswert steht links '
      'in der Zeile',
      (tester) async {
        final h = harness(
          tageswerte: Bekannt<List<DailyMetrics>>(
            // Neun Tage mit 60, heute 80: Die beiden Zahlen sind
            // unterscheidbar, und nur so ist zu sehen, welche wo steht.
            tage(hrv: 60, hrvHeute: 80),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        final hrv = zeileMit(tester, 'hrv');
        expect(
          hrv.wert,
          contains('80'),
          reason: 'der Entwurf zeigt rechts „61 ms" — den heutigen Wert',
        );
        expect(
          hrv.wert,
          isNot(contains('60')),
          reason: 'der Durchschnitt gehört nicht in die Wertspalte',
        );
        expect(
          hrv.detail,
          contains('60'),
          reason:
              'der Entwurf zeigt links „7 Tage · Median 58 ms" — Fenster '
              'und Vergleichswert',
        );
      },
    );

    testWidgets('der Wert trägt die Ampel: gut, kritisch, schlecht', (
      tester,
    ) async {
      // Median der neun Tage davor: 60 ms. Schwelle für ein Warnsignal
      // ist `median * 0,8` = 48, die halbe Strecke dorthin liegt bei 54.
      final faelle = <double, VitalTon>{
        80: VitalTon.normal,
        50: VitalTon.nahAmSignal,
        40: VitalTon.warnsignal,
      };

      for (final fall in faelle.entries) {
        final h = harness(
          tageswerte: Bekannt<List<DailyMetrics>>(
            tage(hrv: 60, hrvHeute: fall.key),
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);

        expect(
          zeileMit(tester, 'hrv').ton,
          fall.value,
          reason: 'HRV ${fall.key} gegen den Median 60',
        );
      }
    });

    testWidgets('ohne Messwert gibt es keine Farbe, nur „—"', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(hrv: null),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final hrv = zeileMit(tester, 'hrv');
      expect(hrv.wert, contains('—'));
      expect(
        hrv.ton,
        VitalTon.unbeurteilt,
        reason:
            'eine Lücke ist weder gut noch schlecht. Eine Farbe darauf '
            'wäre eine Aussage über Daten, die es nicht gibt',
      );
    });

    testWidgets(
      'die Alkohol-Zeile bleibt stumm — ohne Auskunft, ohne Farbe, ohne Tür',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final alkohol = zeileMit(tester, 'alkohol');
        // Seit #268 trägt die Zeile eine Auskunft über den Vortag. Ohne
        // Daten ist sie „kein Wert" — die Lücke steht als „—" da, sie
        // verschwindet nicht, und „Nein" steht dort gerade **nicht**.
        expect(alkohol.wert, keinWert);
        expect(alkohol.ton, VitalTon.unbeurteilt);
        expect(alkohol.onTap, isNull);
      },
    );
  });

  group('Ziele und Datumszeile', () {
    testWidgets(
      'das Wochenziel kommt aus den Zielen, nicht als Zahl aus dem Quelltext',
      (tester) async {
        final h = harness(
          ziele: Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 123),
        );
        await zeige(tester, h.app);

        expect(ringe(tester).belastung.detail, contains('123'));
      },
    );

    testWidgets(
      'die große Überschrift „Erholung" entfällt — die Leiste nennt den '
      'Schirm bereits',
      (tester) async {
        final h = harness(mitSeite: true);
        await zeige(tester, h.app);

        expect(
          find.byType(GrosseUeberschrift),
          findsNothing,
          reason:
              'der Entwurf hat über der Datumszeile nichts; zweimal '
              'derselbe Titel übereinander ist kein Aufbau',
        );
        expect(
          find.text('Erholung'),
          findsOneWidget,
          reason:
              'genau einmal — in der Navigationsleiste. Die Ringspalte '
              'heißt „ERHOLUNG" und zählt hier nicht mit',
        );
        expect(find.byKey(const Key('erholung-datumszeile')), findsOneWidget);
      },
    );

    testWidgets(
      'oben steht nur das Datum — kein Wochentag, kein Nachtbezug',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          datumszeile(tester),
          Format.datumAusgeschrieben(DateTime.utc(2026, 10, 12)),
          reason:
              'Tims Entscheidung vom 27.10.2026: „lass uns das Datum '
              'mittig hin platzieren […] Aber den Text drum rum nicht."',
        );
        expect(
          datumszeile(tester).toLowerCase(),
          isNot(contains('nacht')),
          reason: 'der Nachtbezug aus Spec 10a Punkt 2 ist zurückgenommen',
        );
        expect(
          datumszeile(tester),
          isNot(contains('Montag')),
          reason: 'auch der Wochentag gehört zum „Text drum rum"',
        );
      },
    );

    testWidgets(
      'und zwar in jedem Health-Zustand gleich — das Datum hängt nicht an '
      'Apple Health',
      (tester) async {
        for (final schlaf in <Messwert<List<SleepNight>>>[
          const NochNie(),
          LeerNachLauf(gelaufen: jetzt),
          Fehlgeschlagen(fehler: Exception('x'), gelaufen: jetzt),
        ]) {
          final h = harness(schlaf: schlaf);
          await zeige(tester, h.app);

          expect(
            datumszeile(tester),
            Format.datumAusgeschrieben(DateTime.utc(2026, 10, 12)),
            reason: '$schlaf',
          );
        }
      },
    );
  });

  // Entwurf: `sectionCard({ title: 'Tipps', hint: '4 Punkte', open: false })`.
  // Tim am 27.10.2026: „unten die Tipps sollten default eingeklappt sein."
  group('Die Tipps klappen auf und zu', () {
    testWidgets('zuerst stehen sie eingeklappt da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('erholung-tipps')),
        findsOneWidget,
        reason: 'der Abschnitt selbst steht in jedem Zustand',
      );
      expect(
        find.byKey(const Key('erholung-tipps-inhalt')),
        findsNothing,
        reason:
            'die vier Punkte ändern sich von Tag zu Tag nicht — wer sie '
            'kennt, scrollt sonst jedes Mal an ihnen vorbei',
      );
    });

    testWidgets('ein Tipp auf den Kopf klappt sie auf, der nächste zu', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('erholung-tipps-inhalt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('erholung-tipps-inhalt')), findsNothing);
    });

    testWidgets('das Aufklappen ist kein Sprung in einen anderen Schirm', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
      await tester.pumpAndSettle();

      expect(h.router.nimmBefehl(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'aufgeklappt bleiben sie es auch, wenn sich die Health-Daten ändern',
      (tester) async {
        // Ein aufgeklappter Abschnitt ist ein Zustand der Oberfläche, kein
        // abgeleiteter Wert. Fiele er beim nächsten Durchlauf wieder zu,
        // wäre das aus Sicht des Nutzers dasselbe wie `docs/todo/32`.
        // Ausgelöst über die Tageswerte selbst: Ein neuer `Messwert`
        // lässt `erholungProvider` und mit ihm den ganzen Schirm neu
        // durchrechnen. Bis zum 03.11.2026 lief der Anstoß über die
        // Gefühlszeile; die gibt es seit #269 nicht mehr, die Anforderung
        // schon.
        final h = harness();
        await zeige(tester, h.app);

        await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('erholung-tipps-inhalt')), findsOneWidget);

        h.container.read(dailyMetricsProvider.notifier).state = AsyncData(
          Bekannt<List<DailyMetrics>>(
            tage(),
            stand: jetzt.add(const Duration(minutes: 5)),
            laeuft: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(RingKarte),
          findsOneWidget,
          reason: 'Vorbedingung: der Schirm hat neu gerechnet',
        );

        expect(find.byKey(const Key('erholung-tipps-inhalt')), findsOneWidget);
      },
    );
  });

  group('Rahmen und Hausordnung', () {
    testWidgets(
      'ErholungView bringt weder Gerüst noch Leiste noch Navigator mit — '
      'den Rahmen stellt der Gastgeber',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          find.descendant(
            of: find.byType(ErholungView),
            matching: find.byType(CupertinoPageScaffold),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ErholungView),
            matching: find.byType(CupertinoNavigationBar),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(ErholungView),
            matching: find.byType(Navigator),
          ),
          findsNothing,
        );
        expect(find.byType(CupertinoTabScaffold), findsNothing);
      },
    );

    testWidgets('ErholungSeite stellt genau diesen Rahmen', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(ErholungView), findsOneWidget);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets(
      'der Glas-Abstand liegt als padding im SingleChildScrollView, nicht '
      'als äußere Padding — sonst schrumpft der Viewport statt des Inhalts',
      (tester) async {
        final h = harness();
        await zeige(tester, h.app);

        final scroll = tester.widget<SingleChildScrollView>(
          find
              .descendant(
                of: find.byType(ErholungView),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        );
        final erwartet = GlasAbstand.of(tester.element(find.byType(ErholungView)));

        expect(scroll.padding, isNotNull);
        final padding = scroll.padding! as EdgeInsets;
        expect(padding.top, erwartet.top);
        expect(padding.bottom, greaterThanOrEqualTo(erwartet.bottom));
        expect(
          erwartet.top,
          greaterThan(0),
          reason: 'sonst prüft dieser Test gar nichts',
        );
        expect(
          find.descendant(
            of: find.byType(ErholungView),
            matching: find.byType(GlasRand),
          ),
          findsNothing,
          reason: 'GlasRand ist die Variante für nicht scrollende Schirme',
        );
      },
    );

    testWidgets(
      'ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(docs/todo/32)',
      (tester) async {
        final h = harness(mitSeite: true);
        final gesehen = <Messwert<ErholungDaten>>[];
        h.container.listen(
          erholungProvider,
          (_, next) => gesehen.add(next.daten),
          fireImmediately: true,
        );

        await zeige(tester, h.app);
        final vorher = ringe(tester).schlaf.mitte;
        expect(vorher, isNot('—'), reason: 'es stand ein echter Wert da');

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          CupertinoPageRoute<void>(
            builder: (_) => const CupertinoPageScaffold(
              child: Center(child: Text('woanders')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('woanders'), findsOneWidget);

        navigator.pop();
        await tester.pumpAndSettle();

        expect(ringe(tester).schlaf.mitte, vorher);
        expect(
          alleTexte(tester),
          isNot(contains('aufgezeichnet')),
          reason: 'nach dem Zurückkommen steht kein Leerstand da',
        );
        // Der Vorlauf vor dem ersten Wert ist bauartbedingt `NochNie`
        // (siehe Nachtrag im Dateikopf). Gezählt wird ab dem ersten
        // bekannten Wert — ab da ist jedes `NochNie` Fehler 32.
        final abErstemWert = gesehen
            .skipWhile((messwert) => messwert is NochNie<ErholungDaten>)
            .toList();
        expect(
          abErstemWert,
          isNotEmpty,
          reason:
              'Vorbedingung: irgendwann stand ein Wert da — sonst prüft die '
              'nächste Zeile nichts',
        );
        expect(
          abErstemWert.whereType<NochNie<ErholungDaten>>(),
          isEmpty,
          reason:
              'ein Wert, der einmal dastand, verschwindet nicht wieder — '
              'weder beim Wegnavigieren noch beim Zurückkommen',
        );
      },
    );

    // Der Fall darüber schiebt eine erfundene Seite auf den Stapel. Seit
    // die Türen auf echte Schirme führen (28.10.2026), ist derselbe Weg
    // über ein echtes Ziel mehr wert: Er zeigt zusätzlich, dass das Ziel
    // sich hängen lässt und nicht nur bauen. Ausgewählt ist
    // `ErholungWerteSeite`, weil sie mit genau den Providern auskommt, die
    // diese Hülle ohnehin setzt.
    testWidgets(
      'und auch über eine echte Tür: hin zum Erholung-Ring und zurück '
      '(docs/todo/32)',
      (tester) async {
        final h = harness(mitSeite: true);
        await zeige(tester, h.app);

        final vorher = ringe(tester).schlaf.mitte;
        expect(vorher, isNot('—'), reason: 'es stand ein echter Wert da');

        await tester.tap(
          find.descendant(
            of: find.byType(RingKarte),
            matching: find.text('ERHOLUNG'),
          ),
        );
        await tester.pump();

        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(CupertinoPageRoute<void>(builder: befehl!.builder));
        await tester.pumpAndSettle();

        expect(
          find.byType(ErholungWerteView),
          findsOneWidget,
          reason: 'dahinter liegt der gebaute Schirm, kein Platzhalter',
        );

        navigator.pop();
        await tester.pumpAndSettle();

        expect(ringe(tester).schlaf.mitte, vorher);
        expect(
          alleTexte(tester),
          isNot(contains('aufgezeichnet')),
          reason: 'nach dem Zurückkommen steht kein Leerstand da',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('baut ohne Ausnahme und ohne ErrorWidget', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Die beiden Eingänge', () {
    testWidgets(
      'oeffneErholung schiebt auf den Stapel des aktuell gewählten Tabs',
      (tester) async {
        final router = AppRouter();
        final tabVorher = router.tab;

        oeffneErholung(router);

        expect(router.tab, tabVorher);
        final befehl = router.nimmBefehl();
        expect(befehl, isNotNull);
        expect(befehl!.ersetztStapel, isFalse);
        expect(befehl.tab, router.tab);
      },
    );

    testWidgets('Mehr › Erholung öffnet den Schirm', (tester) async {
      final h = harness();
      tester.view.physicalSize = const Size(900, 4200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: MehrView(router: h.router)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Erholung'));
      await tester.pumpAndSettle();

      final befehl = h.router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErholungView), findsOneWidget);
    });

    testWidgets(
      'die Erholungskarte auf Heute öffnet den Schirm — und die Karte selbst '
      'bleibt ein Baustein ohne eigenes onTap',
      (tester) async {
        final h = harness();
        tester.view.physicalSize = const Size(900, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(
              home: CupertinoPageScaffold(child: HeuteView(router: h.router)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(ErholungsKarte),
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
          reason: 'der Schirm wird am Aufrufer antippbar gemacht, nicht am '
              'Baustein — ErholungsKarte bleibt unverändert',
        );

        await tester.tap(find.byType(ErholungsKarte), warnIfMissed: false);
        await tester.pump();

        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull);
        expect(befehl!.ersetztStapel, isFalse);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(home: Builder(builder: befehl.builder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ErholungView), findsOneWidget);
      },
    );
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `heute_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
