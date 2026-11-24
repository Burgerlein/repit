import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/stammdaten.dart';
import '../design/erholungs_karte.dart';
import '../design/glas_abstand.dart';
import '../design/kachel_karte.dart';
import '../design/kacheln.dart';
import '../design/palette.dart';
import '../design/ringe.dart';
import '../design/section_header.dart';
import '../design/vital_ton.dart';
import '../ernaehrung/ernaehrung_abschnitte.dart' show ErnaehrungZielFehlt;
import '../ernaehrung/ernaehrung_provider.dart';
import '../gym/gym_provider.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'erholung_view.dart';
import 'erholung_zustand.dart';
import 'heute_anzeigen.dart';
import 'heute_training.dart';
import 'vital_texte.dart';
import 'router.dart';

/// Übersetzt den äußeren `AsyncValue`, den `dailyMetricsProvider` (ein
/// `AsyncNotifierProvider`) zwangsläufig mitbringt, auf den darunterliegenden
/// `Messwert` zurück — reines Durchreichen mit `NochNie`-Rückfall, siehe
/// `heute_zustand_test.dart` für die vollständige Begründung, warum das
/// **keine** zweite `alsMesswert`-Stelle ist.
Messwert<List<DailyMetrics>> heuteZustandAusProvider(
  AsyncValue<Messwert<List<DailyMetrics>>> zustand,
) => zustand.value ?? const NochNie();

/// Beide Möglichkeiten, die Apple nicht unterscheidet (CLAUDE.md,
/// Abschnitt HealthKit): „nichts aufgezeichnet" und „kein Lesezugriff".
/// Steht **einmal** über dem Gerüst, nicht in jedem einzelnen Feld.
const _ohneTreffer =
    'Für heute ist nichts aufgezeichnet, oder der Lesezugriff ist nicht '
    'freigegeben — das unterscheidet Apple Health nicht. Bitte in den '
    'Health-Einstellungen prüfen.';

/// Der Heute-Schirm — Entwurf `docs/screens/screens/heute-kombi.js` (siehe
/// dessen Kommentarkopf). Bringt bewusst **keinen** eigenen
/// `CupertinoPageScaffold`/keine `NavigationBar` mit, die stellt der Host
/// (`RootView`, Verdrahtung folgt in einer späteren Aufgabe).
///
/// **Seit #358 trägt Home die Ernährung:** Kalorien- und Eiweißring neben
/// dem Trainingsring, aus dem gehaltenen `ernaehrungsTagProvider` des
/// **heutigen** Tags — demselben gerechneten Tag wie auf dem
/// Ernährungs-Tab.
///
/// **Die Mahlzeitenlisten sind seit #501 weg** (Tim, 13.11.2026:
/// „Erledigt kann weg, heute noch offen auch"). Sie stehen auf dem
/// Ernährungs-Tab, dort gibt es sie; die Einheiten aus derselben Liste
/// deckt „Heute Training" ab. Mit ihnen ist `heute_ernaehrung.dart`
/// gefallen — es trug nichts anderes.
///
/// **Seit #376 aufgeräumt** (Tim, 05.11.2026): Die Makros sind weg („der
/// Ring oben gibt genug Infos"), ebenso der Hinweis, dass die
/// Trainingseinheiten noch nicht angebunden sind. Und alle Karten tragen
/// die Fläche der Erholungskarte — über [KachelKarte], nicht über Kopien.
///
/// **Eine Anzeige, die es gibt, hat genau eine Form** (Spec
/// `docs/superpowers/specs/2026-10-28-leerzustaende-design.md`, Ticket
/// #137): Ring, Kacheln und Erholungskarte stehen in `NochNie`, in
/// `Bekannt` mit fehlenden Feldern und in `LeerNachLauf` an derselben
/// Stelle in derselben Größe — nur die Füllung unterscheidet sich. Ein
/// fehlender Wert heißt `null` und wird zu `–/–`, nie zu `0`.
///
/// Nur `Fehlgeschlagen` fällt heraus: Dass ein Lauf scheiterte, ist eine
/// Aussage über den Lauf und gehört nicht in die Felder.
///
/// **Der optionale Router (#115).** `null` heißt „keine Tür": Die
/// Erholungskarte ist dann nicht antippbar und trägt kein Chevron. Optional
/// und nicht `required`, weil `heute_view_test.dart` `const HeuteView()`
/// pumpt; `RootView` übergibt immer einen.
class HeuteView extends ConsumerWidget {
  const HeuteView({super.key, this.router});

  final AppRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **Hier fragt die App nach der Health-Freigabe** (#183). Bis zum
    // 02.11.2026 lief `requestAuthorization()` ausschließlich auf
    // *Mehr › HealthKit-Test*; wer den Schirm nie öffnete, wurde nie
    // gefragt und sah dauerhaft leere Werte. Heute ist der erste Schirm
    // der Auslöser.
    //
    // **Warum im Schirm und nicht in den Lade-Providern:** Der Auslöser
    // setzt den Stand, den `DailyMetricsNotifier` und `NachtWerteNotifier`
    // beobachten (dort begründet, #176). Stünde er in einem dieser
    // Provider, verwürfe seine eigene Antwort den Lauf, der auf ihn
    // wartet — der Lauf wird während des Ladens entsorgt und gibt nie
    // einen Wert aus. Von außen angestoßen passiert genau das Richtige:
    // Der erste Lauf kommt noch ohne Freigabe leer zurück, die
    // beantwortete Freigabe löst den zweiten aus.
    //
    // **Der erklärende Willkommensschritt fehlt noch** — ein Systemdialog
    // ist eine Zusage, und der Nutzer sieht ihn einmal pro Installation.
    // Sein Entwurf liegt in `docs/screens/screens/erststart.js`; Tim hat
    // am 02.11.2026 entschieden, zuerst den Zugriff zu bauen.
    ref.watch(freigabeAnfrageProvider);

    final zustand = heuteZustandAusProvider(ref.watch(dailyMetricsProvider));
    // Dieselbe Rechnung wie auf dem Erholung-Schirm, **gehalten** statt je
    // Bild gerechnet (Hausregel 2, `docs/todo/03`): Die Erholungskarte
    // zeigt Verdikt, Messwerte und Normalwerte, und zwei Quellen für
    // dieselbe Auskunft wären zwei Wahrheiten.
    final erholung = ref.watch(erholungProvider).daten;
    // Welcher Kalendertag gerade „heute" ist, sagt der Provider — nicht
    // der Cache (#196). `heutigerTagProvider` und nicht `clockProvider`,
    // weil nur er sich beim Tageswechsel ändert und alles mitzieht, was
    // ihn beobachtet (siehe seinen Doc-Kommentar).
    final heuteBeginn = ref.watch(heutigerTagProvider);
    final heuteTag = BerlinCalendar.dayKey(heuteBeginn);

    // **Derselbe gehaltene Tageszustand wie auf dem Gym-Tab** (#501).
    // Der Abschnitt „Heute Training" rechnet nichts selbst; zwei
    // Quellen für dieselbe Auskunft wären zwei Wahrheiten.
    final gym = ref.watch(gymTagProvider);

    // **Home stößt den Stammdaten-Lauf an**, wie der Ernährungs-Tab (Tims
    // Befund vom 04.11.2026): `stammdatenAusHealthProvider` ist ein
    // `FutureProvider`, und einer ohne Beobachter läuft nie. Ohne diese
    // Zeile stünde der Kalorienring nach einer Neuinstallation so lange
    // auf „kein Ziel", bis jemand den Ernährungs-Tab öffnet.
    ref.watch(stammdatenAusHealthProvider);
    // **Heute, nicht der geblätterte Tag des Ernährungs-Tabs**
    // (`offenerTagProvider`): Home zeigt immer den heutigen Tag.
    final ernaehrung = ref.watch(ernaehrungsTagProvider(heuteTag));
    // Nur für den Grund „kein Kalorienziel" — er nennt die Angabe, die
    // fehlt, und dafür braucht er Größe und Geburtsjahr einzeln.
    final stammdaten = stammdatenAusProvider(
      ref.watch(stammdatenProvider),
    ).stammdaten;

    // `SingleChildScrollView` statt `ListView`: Ein `ListView` baut seine
    // Kinder über Slivers nur innerhalb des sichtbaren Ausschnitts — ein
    // Widget-Test, der den ganzen Baum durchsucht (z. B. die Kacheln am
    // Fuß des Schirms), fände sie sonst nicht, obwohl sie "da" sind, nur
    // noch nicht gebaut.
    //
    // `padding` statt einer äußeren `Padding`: `GlasAbstand.of(context)`
    // rückt den Inhalt von der durchscheinenden Navigations- und Tableiste
    // ab (task-layout-fixes, Fehler 2 — die oberste Zeile saß vorher halb
    // unter der Navigationsleiste), ohne den Scroll-Viewport selbst zu
    // verkleinern (siehe `GlasAbstand`-Klassenkommentar).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // **Kein großer Kopf mehr** (#514, Tim am 16.11.2026): Den
          // Tag nennt die Navigationsleiste („Montag", `root_view.dart`),
          // und die Stand-Zeile ist mit ihm gefallen — der Schirm beginnt
          // mit dem Ringblock. Bis dahin stand hier groß das Datum (#501),
          // davor groß „Heute".
          ...switch (zustand) {
            NochNie<List<DailyMetrics>>() => _schirm(
              context,
              heuteTag: heuteTag,
              fenster: const [],
              grund: null,
              laedt: true,
              erholung: erholung,
              ernaehrung: ernaehrung,
              stammdaten: stammdaten,
              gym: gym,
              gymHeute: heuteBeginn,
              router: router,
            ),
            Bekannt<List<DailyMetrics>>(:final wert) => _schirm(
              context,
              heuteTag: heuteTag,
              fenster: wert,
              grund: wert.isEmpty ? _ohneTreffer : null,
              laedt: false,
              erholung: erholung,
              ernaehrung: ernaehrung,
              stammdaten: stammdaten,
              gym: gym,
              gymHeute: heuteBeginn,
              router: router,
            ),
            LeerNachLauf<List<DailyMetrics>>() => _schirm(
              context,
              heuteTag: heuteTag,
              fenster: const [],
              grund: _ohneTreffer,
              laedt: false,
              erholung: erholung,
              ernaehrung: ernaehrung,
              stammdaten: stammdaten,
              gym: gym,
              gymHeute: heuteBeginn,
              router: router,
            ),
            Fehlgeschlagen<List<DailyMetrics>>() => _fehlerInhalt(),
          },
        ],
      ),
    );
  }
}

/// Der Eintrag des Fensters, der auf den Tagesschlüssel [heuteTag] fällt —
/// `null`, wenn das Fenster ihn nicht enthält (#196).
///
/// Rein und ohne `ref`: Welcher Tag heute ist, entscheidet `build`
/// (`CLAUDE.md`, Hausregel 3); hier wird nur verglichen. Verglichen werden
/// ISO-Tagesstrings, nicht Zeitpunkte — ein Tag ist eine Kalenderangabe und
/// kein Zeitpunkt, und ein Stringvergleich übersteht jede Zeitumstellung.
DailyMetrics? _tageswertAm(List<DailyMetrics> fenster, String heuteTag) {
  for (final tageswert in fenster) {
    if (tageswert.tag == heuteTag) return tageswert;
  }
  return null;
}

/// Ein gescheiterter Lauf ohne Cache. Wortlaut bewusst nicht festgelegt
/// (siehe `heute_view_test.dart`), nur: nicht abstürzen.
List<Widget> _fehlerInhalt() => const [
  Padding(
    padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Text('Die Werte konnten gerade nicht geladen werden.'),
  ),
];

/// Der Schirm — **ein** Aufbau für alle drei Zustände, die Werte zeigen
/// können. Was fehlt, fehlt im einzelnen Feld; die Anzeige bleibt stehen.
///
/// [fenster] ist der geladene Zeitraum, „heute" darin der Eintrag mit dem
/// Tagesschlüssel [heuteTag] — **nicht** einfach der letzte (#196). Beim
/// ersten Kaltstart eines neuen Tages ist der letzte Eintrag gestern, und
/// seit #194 trägt er Trainingsminuten und Gewicht: Der Ring stand morgens
/// voll auf dem Training von gestern, die Gewichtskachel sagte „heute
/// gemessen". Ein gefüllter Ring behauptet ein Training, das nicht
/// stattfand — dieselbe falsche Auskunft wie ein Ring auf 0, nur
/// andersherum. [grund] ist die
/// eine Zeile über dem Gerüst, die einen ergebnislosen Lauf erklärt.
///
/// **Die Stand-Zeile gab es hier bis #514** („Stand 14:32 · wird
/// aktualisiert", samt Platzhalter ihrer Höhe). Tim hat sie am 16.11.2026
/// mit dem großen Datum zusammen gestrichen; der Ladezustand bleibt an
/// den Anzeigen selbst ablesbar.
///
/// [erholung] und [router] gehen unverändert an [_erholungsblock] weiter:
/// Die Erholungskarte hängt seit #115 am `erholungProvider`, nicht am
/// Tageswert — dieselbe Auskunft wie auf dem Erholung-Schirm, und in
/// jedem der drei Fälle dieselbe Tür.
List<Widget> _schirm(
  BuildContext context, {
  required String heuteTag,
  required List<DailyMetrics> fenster,
  required String? grund,
  required bool laedt,
  required Messwert<ErholungDaten> erholung,
  required ErnaehrungsTag ernaehrung,
  required Stammdaten stammdaten,
  // Der Tageszustand des Gym-Tabs und der Berliner Tagesbeginn, aus dem
  // „heute erledigt" von „gestern erledigt" zu unterscheiden ist.
  required GymTag gym,
  required DateTime gymHeute,
  required AppRouter? router,
}) {
  final heute = _tageswertAm(fenster, heuteTag);
  // `RINGE` im Entwurf, von außen nach innen: Kalorien, Eiweiß, Training.
  // Die Reihenfolge ist die Zuordnung Ring → Wert, keine Beschriftung.
  final ringe = [
    ...ernaehrungsRinge(context, ernaehrung),
    ...trainingsring(context, heute, laedt: laedt),
  ];
  // Der Grund „kein Kalorienziel" gehört zu einem **fertigen** Lauf ohne
  // Treffer — während des Ladens ist nichts entschieden (Fehler `01`). Er
  // steht **einmal**, unter den Ringen, nicht in der schmalen Legende.
  final zielFehlt = ernaehrung.zielKcal == null && !ernaehrung.zielLaedt;

  return [
    if (grund != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(grund),
      ),
    // Der Ringblock ist eine Karte (`.ringhero` im Entwurf) — seit #376 auf
    // der Fläche der Erholungskarte, wie jede Karte auf Home.
    //
    // **Seitlich knapper als der Entwurf** (14 statt 18, Abstand 14 statt
    // 17): Jeder Punkt Innenrand fehlt der Legende, und `RingLegende` teilt
    // ihre Breite hälftig zwischen Name und Rest — „noch 2.451 kcal"
    // (erfundenes Beispiel) schrumpfte sonst sichtbar kleiner als die
    // Zeilen darunter (Bildschirmfoto zu #376).
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: KachelKarte(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ringe(ringe),
              const SizedBox(width: 14),
              Expanded(child: RingLegende(ringe)),
            ],
          ),
        ),
      ),
    ),
    if (zielFehlt)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ErnaehrungZielFehlt(
          tag: ernaehrung,
          stammdaten: stammdaten,
          kachelKarte: true,
        ),
      ),
    // **Zwischen Ringblock und Erholung steht die heutige Einheit**
    // (#501, Tim am 13./16.11.2026) — an der Stelle, an der bis dahin
    // „Heute noch offen" stand. Was der Abschnitt zeigt, steht in
    // `heute_training.dart`.
    HeuteTraining(tag: gym, heute: gymHeute, router: router),
    // **Hier steht der Block dieses Zweigs, nicht `erholungsKarte` aus
    // `heute_anzeigen.dart`.** `main` baute die Karte aus `DailyMetrics`,
    // weil es dort keinen Erholung-Schirm und keinen `erholungProvider`
    // gab. Den gibt es hier — er trägt Verdikt, Normalwerte und den
    // Schlaf, und die Karte ist die Tür zum Erholung-Schirm (#115). Die
    // Form aus #137 bleibt dabei gewahrt: Alle vier Spalten entstehen
    // immer, ein fehlender Wert ist `null` und wird zu `ohneWert`.
    _erholungsblock(context, erholung, router),
    const SectionHeader('Zahlen'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Kacheln(
        zahlenKacheln(
          context,
          heute,
          fenster,
          heuteTag: heuteTag,
          laedt: laedt,
          // Macht die Gewichtskachel zur Tür auf den Gewichtsverlauf
          // (#239). Ohne Router bleibt sie reine Anzeige — dieselbe Regel
          // wie beim Erholungsblock.
          router: router,
        ),
      ),
    ),
    // **Kein Fußtext mehr** (#516, Tim am 16.11.2026): „unten den Info-Text
    // noch weg, dann ist der Screen richtig schlicht". Die
    // Schätzungs-Kennzeichnung, die `CLAUDE.md` verlangt, trägt damit nicht
    // mehr Home, sondern der Erholung-Schirm und die Detailschirme — dort
    // steht sie weiter, und dorthin führen die Karten von hier.
  ];
}

/// Gruppenkopf und Karte zusammen — der Kopf trägt seit #516 **keinen
/// Verweis** mehr (Tim, 16.11.2026: „den blauen Button Gym und Details
/// ebenfalls weg — stören mich"). Die Tür bleibt: Die ganze Gruppe hängt
/// an einem `GestureDetector`, und das Chevron der Karte zeigt sie an.
/// Dass hier beides zusammensteht, ist der Grund für die gemeinsame
/// Funktion — ein Kopf ohne Tippfläche über einer Karte mit wäre genau
/// die halb drückbare Zeile, die `docs/screens/pruefen.mjs` meldet.
///
/// Ohne Router gibt es keine Tür — dann ist die Gruppe reine Anzeige.
///
/// Die Tür wird **am Aufrufer** aufgemacht, nicht am Baustein:
/// `ErholungsKarte` nimmt fertige Strings und hat kein `onTap` (#115).
///
/// **Sie rechnet auch seit #254 nichts aus.** Dazugekommen ist je Wert ein
/// [VitalTon] — der fachliche Zustand, den die Ampel vergeben hat, nicht
/// eine Farbe. Welche Farbe daraus wird, entscheidet die Karte an einer
/// Stelle; wer bewertet, ist weiterhin `RecoveryTrafficLight` im Kern.
Widget _erholungsblock(
  BuildContext context,
  Messwert<ErholungDaten> erholung,
  AppRouter? router,
) {
  final schnappschuss = erholung is Bekannt<ErholungDaten>
      ? erholung.wert.schnappschuss
      : null;
  final (ueberschrift, satz, akzent) = _verdikt(schnappschuss);

  final block = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader('Erholung'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ErholungsKarte(
          ueberschrift: ueberschrift,
          satz: satz,
          akzent: CupertinoDynamicColor.resolve(akzent, context),
          vitalwerte: _vitalwerte(schnappschuss),
        ),
      ),
    ],
  );

  if (router == null) return block;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => oeffneErholung(router),
    child: block,
  );
}

/// Überschrift, Untertitel und Akzent nach dem Verdikt der Ampel.
///
/// **Nie das generische „Erholung":** Die Zeile trägt die Auskunft, und
/// eine Überschrift, die in jedem Zustand dieselbe ist, trägt keine.
///
/// **Die Sätze sind auf zwei Zeilen gekürzt** — dieselbe Begründung wie bei
/// `RECOVERY_LEER` in `docs/screens/screens/heute-kombi.js`: Die Karte
/// reserviert seit #137 genau zwei Zeilen für den Satz, und ein längerer
/// wurde auf Gerätebreite gekappt (`heute_schmal_test.dart`). Beim
/// Leerfall stehen trotzdem beide Möglichkeiten drin, das verlangt
/// `CLAUDE.md`.
(String, String, CupertinoDynamicColor) _verdikt(
  RecoverySnapshot? schnappschuss,
) {
  if (schnappschuss == null) {
    return (
      'Noch keine Werte',
      'Die Werte aus Apple Health werden geladen.',
      Palette.rest,
    );
  }

  final bewertung = schnappschuss.evaluation;
  return switch (bewertung.verdict) {
    RecoveryVerdict.calm => (
      'Gut erholt',
      'Alle vier Werte liegen im Normalbereich.',
      Palette.ok,
    ),
    RecoveryVerdict.watch => (
      'Achte auf dich',
      'Ein Wert liegt außerhalb deines Normalbereichs.',
      Palette.bib,
    ),
    RecoveryVerdict.stressed => (
      'Achte auf dich',
      '${bewertung.signals.length} Werte liegen außerhalb deines '
          'Normalbereichs.',
      Palette.bib,
    ),
    // Apple verrät den Lesestatus nicht — beide Möglichkeiten werden
    // benannt, nie „nichts getrackt" (`CLAUDE.md`).
    // **Der Satz ist beim Zusammenführen kürzer geworden**, und das ist
    // eine Entscheidung, keine Nebenwirkung. Dieser Zweig schrieb hier
    // „Entweder hat die Uhr nichts aufgezeichnet, oder der Lesezugriff ist
    // nicht freigegeben. Beides sieht von hier gleich aus." — auf
    // Flutters 800-Punkte-Testfläche passt das, auf 393 Punkt
    // Gerätebreite wird es von `maxLines: 2` gekappt, und dann fehlt
    // genau die zweite Möglichkeit. Gemessen hat das `main` mit
    // `heute_schmal_test.dart`; dieselbe Kürzung steht aus demselben
    // Grund im Board (`RECOVERY_LEER` in `heute-kombi.js`).
    //
    // Der Wortlaut ist weder der eine noch der andere: Das Board schreibt
    // „kein Lesezugriff", `heute_erholungskarte_test.dart` verlangt das
    // Wort „freigegeben", und beides zusammen passte wieder nicht in zwei
    // Zeilen. Geblieben ist die kürzeste Fassung, die beide Möglichkeiten
    // benennt — das verlangt `CLAUDE.md`, und mehr trägt die Zeile nicht.
    // Die Überschrift bleibt die dieses Zweigs; das Board führt sie so.
    RecoveryVerdict.noData => (
      'Keine Werte von der Uhr',
      'Nichts aufgezeichnet, oder nicht freigegeben.',
      Palette.rest,
    ),
    RecoveryVerdict.postOperative => (
      'Erholung nach der OP',
      'Bis zur ärztlichen Freigabe keine Bewertung.',
      Palette.warn,
    ),
  };
}

/// Die vier Werte — **Schlaf · Ruhepuls · HRV · Atemfrequenz**, jeder mit
/// seiner Einheit und darunter „Normal …" (#501, Tim am 13.11.2026:
/// „Zeit, bpm, HRV und dann Atemfrequenz, genauso wie es da gebaut ist").
///
/// **Die Reihenfolge steht nicht hier, sondern im Kern.** Sie kommt aus
/// [RecoveryMetric.values] — dort ist sie seit jeher
/// `sleep, restingHeartRate, hrv, respiratoryRate`, in Dart wie in Swift.
/// Bis zum 16.11.2026 zählte diese Funktion die vier von Hand auf und
/// kam dabei auf eine andere; über die Aufzählung zu laufen macht den
/// Unterschied unausdrückbar. Käme ein fünfter Wert dazu, stünde er ohne
/// Zutun in der Karte, statt lautlos zu fehlen.
///
/// **Ohne Median keine Bildunterschrift.** Der Normalwert ist der Median
/// der Tage *vor* heute; liegen zu wenige vor, gibt es ihn nicht, und eine
/// Zahl, die niemand gemessen hat, ist schlimmer als keine.
///
/// Ein fehlender Messwert bleibt `null` — `ErholungsKarte` zeigt dafür
/// einen Strich, nie eine stillschweigende Null.
///
/// **Die Ampelfarbe kommt aus der Bewertung, nicht aus einer zweiten
/// Rechnung** (#254). Bis zum 03.11.2026 wurde `evaluation` hier gar nicht
/// angefasst: Die Auskunft lag vor und fiel auf dem Weg zur Karte weg.
/// Entschieden hat `RecoveryTrafficLight` im Kern; dieser Schirm reicht
/// das Urteil nur durch.
List<VitalWert> _vitalwerte(RecoverySnapshot? schnappschuss) {
  final messwerte = schnappschuss?.reading ?? const RecoveryReading();
  final median = schnappschuss?.baseline ?? const RecoveryBaseline();
  final bewertung = schnappschuss?.evaluation;

  return [
    for (final metrik in RecoveryMetric.values)
      VitalWert(
        name: vitalName(metrik),
        wert: switch (vitalMesswert(metrik, messwerte)) {
          final double wert => vitalWertText(metrik, wert),
          _ => null,
        },
        hinweis: switch (vitalMedian(metrik, median)) {
          final double wert => vitalNormalText(metrik, wert),
          _ => null,
        },
        // **Dieselbe Funktion wie auf dem Erholungs-Schirm** (#308). Bis
        // dahin stand hier eine eigene, gröbere Fassung: Warnsignal,
        // beurteilt, sonst nichts — und 6:18 h Schlaf standen deshalb
        // hier grün und dort gelb. Die mittlere Stufe („nah an der
        // Schwelle") gilt seither auf beiden Schirmen, entschieden wird
        // sie in `vitalTon`.
        ton: vitalTon(
          metrik: metrik,
          messwerte: messwerte,
          baseline: median,
          bewertung: bewertung,
        ),
      ),
  ];
}
