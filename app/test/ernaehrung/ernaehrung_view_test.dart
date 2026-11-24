import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/hinweisfuss.dart';
import 'package:repit/design/makro_balken.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_uebersicht.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für den **Schirm** `ernaehrung` (#282, Task 4 des
/// Ernährungsplans) — `lib/ernaehrung/ernaehrung_view.dart`.
///
/// Der Zustand darunter liegt in `ernaehrung_tag_test.dart`, die
/// Verdrahtung in `ernaehrung_provider_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Festgelegte öffentliche API (`lib/ernaehrung/ernaehrung_view.dart`)
///
/// ```dart
/// /// Der Ernährungs-Tab: Übersicht, vier Mahlzeiten, Wasser, Rezepte,
/// /// Verlauf, Herleitung, die vier Wege, Fußtext.
/// ///
/// /// Bringt **keinen** eigenen `CupertinoPageScaffold` mit — den stellt
/// /// `RootView` je Tab (dieselbe Regel wie bei `PlatzhalterTab`).
/// class ErnaehrungView extends ConsumerWidget {
///   const ErnaehrungView({super.key});
/// }
/// ```
///
/// ## Die Schlüssel
///
/// Weil es für „dieser Abschnitt ist da / ist nicht da" sonst keine
/// strukturelle Stelle im Baum gibt (dieselbe Begründung wie in
/// `erholung_view_test.dart`). Jeder sitzt auf einem **Vorfahren** der
/// Texte, nicht auf einem `Text` selbst:
///
/// - `Key('ernaehrung-datumszeile')` — der Kopf mit dem Datum
/// - `Key('ernaehrung-zurueck')` / `Key('ernaehrung-vor')` — ‹ und ›
/// - `Key('ernaehrung-uebersicht')` — die Karte „Übersicht" oben (seit
///   dem 07.11.2026, siehe unten); darin
///   `Key('ernaehrung-uebersicht-uebrig')` — die große Zahl im Bogen und
///   ihr Wort — und `Key('ernaehrung-uebersicht-kohlenhydrate' |
///   '-eiweiss' | '-fett')` — die drei Makrobalken. Festgelegt sind sie in
///   `ernaehrung_uebersicht_test.dart`; hier werden sie nur benutzt.
/// - `Key('ernaehrung-mahlzeiten')` — der Mahlzeiten-Abschnitt
/// - `Key('ernaehrung-mahlzeit-fruehstueck' | '-mittag' | '-snack' |
///   '-abend')` — die vier Zeilen, **immer alle vier**
/// - `Key('ernaehrung-wasser')` — der Wasser-Abschnitt
/// - `Key('ernaehrung-rezepte')` — Rezepte und Einkauf
/// - `Key('ernaehrung-verlauf-kopf')` / `Key('ernaehrung-verlauf-inhalt')`
/// - `Key('ernaehrung-herleitung-kopf')` /
///   `Key('ernaehrung-herleitung-inhalt')`
/// - `Key('ernaehrung-wege')` — die vier gleich großen Wege unten
/// - `Key('ernaehrung-ziel-fehlt')` — die Zeile mit dem Grund, **nur** im
///   Zustand „kein Ziel berechenbar"
///
/// ## Umbau vom 04.11.2026: drei Ringe, neue Reihenfolge (Tim)
///
/// Das Entwurfsboard ist seit `eab3818` umgebaut
/// (`docs/screens/screens/ernaehrung.js`). Drei Dinge ändern sich, und
/// alle drei stehen unten als Fälle:
///
/// 1. **Drei Ringe statt zwei** — Eiweiß, Kohlenhydrate, Fett, in dieser
///    Reihenfolge. Die Kalorien bleiben die große Zahl in der Mitte und
///    haben **keinen** eigenen Ring mehr.
/// 2. **Der eigene Makroblock entfällt ersatzlos.** Dieselben drei Zahlen
///    standen zweimal auf dem Schirm und kosteten eine halbe
///    Bildschirmhöhe.
/// 3. **Neue Reihenfolge:** Ring → Mahlzeiten → Wasser → Rezepte →
///    Verlauf → Herleitung → Erfassen-Leiste.
///
/// ### Entscheidung des Test-Agenten: die Makro-Schlüssel fallen weg
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// `Key('ernaehrung-makros')` und `Key('ernaehrung-makro-eiweiss' |
/// '-kohlenhydrate' | '-fett')` wandern **nicht** auf die Ringlegende,
/// sie verschwinden. Ein Schlüssel ist hier die strukturelle Stelle für
/// „dieser Abschnitt ist da"; dieselben Schlüssel über einem Ring
/// weiterzuführen behauptete, es gäbe den Abschnitt noch — und genau das
/// ist die Aussage, die der Umbau zurücknimmt. Die drei Makros haben seit
/// dem Umbau eine bessere Stelle als einen Schlüssel: Sie waren die drei
/// `RingZiel` im Ringblock und sind seit dem 07.11.2026 die drei
/// `MakroSaeule` der Übersicht, mit Wert, Ziel und Vorlesetext. Der Fall
/// „den eigenen Makroblock gibt es nicht mehr" nagelt das Verschwinden
/// ausdrücklich fest, damit der Block nicht einfach unbeachtet stehen
/// bleibt.
///
/// ## Umbau vom 07.11.2026: die Übersicht ersetzt die drei Ringe (Tim)
///
/// **Tims Entscheidung**, mit seinem YAZIO-Bild als Vorlage (#406, gilt
/// als freigegebener Entwurf; gezeichnet in `ernaehrung.js`,
/// `UEBERSICHT`): Die drei Ringe oben werden ersetzt durch die Karte
/// „Übersicht" — in der Mitte ein Bogen mit „Übrig", links „Gegessen",
/// rechts „Verbrannt", darunter drei Makrobalken Kohlenhydrate, Eiweiß,
/// Fett. Die Karte steht an der Stelle der Ringe; die übrige Reihenfolge
/// vom 04.11.2026 bleibt.
///
/// **Umgestellt hat der Test-Agent** (10.11.2026), nicht Tim, und nicht
/// der Agent, der die Übersicht gebaut hat. Jede Aussage, die die Fälle
/// über den Schirm machten, ist erhalten — nur liest sie jetzt an der
/// Übersicht ab statt an den Ringen: Laden ohne „keine Daten"-Grund
/// (`01`), Werte nach dem Zurück wieder da (`32`), beim Blättern der
/// richtige Tag, die Reihenfolge mit der Übersicht oben, beim Aufklappen
/// springt nichts. Abgelesen wird am Eiweißbalken, wo vorher der
/// Eiweißring stand.
///
/// Was nur die Ringe selbst betraf, ist auf die Entsprechung der
/// Übersicht umgestellt (drei Balken statt drei Ringe; über dem Ziel ein
/// voller Bogen statt einer zweiten Runde) — oder gestrichen, wo
/// `ernaehrung_uebersicht_test.dart` dieselbe Aussage schon trifft:
///
/// - „ohne Kalorienziel gibt es keinen Kohlenhydratring" — dort „Ohne
///   Ziel: dieselbe Form, ungefüllt, `–/–` statt 0" (Kohlenhydratbalken
///   ohne Ziel und Wert mit `–/–`, Eiweiß und Fett stehen weiter).
/// - „ohne Gewicht steht jeder der drei Ringe trotzdem, mit `–/–`" — dort
///   „ohne Gewicht stehen alle drei Balken mit `–/–`", samt „kein
///   Platzhalter nach dem Lauf".
///
/// Eine Aussage fällt dabei weg, weil sie nicht mehr stimmt: „ohne Ziel
/// steht das Wort ‚übrig' nicht da". In der Übersicht ist „Übrig" die
/// Beschriftung unter der Zahl und steht in jeder Form — dass es ohne
/// Ziel keinen Rest gibt, sagen jetzt `–/–` und der ungefüllte Bogen.
///
/// Der Ring-Baustein selbst (`Ringe`, `RingLegende`) lebt auf Home weiter
/// und wird von den Design-Tests geprüft, nicht hier.
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht
/// Layout und Beschriftung. Kein Test schreibt eine Knopfbeschriftung
/// fest. Wo ein Text einen *Zustand* trägt, wird der Zustand geprüft:
///
/// - Die große Zahl wechselt von „Übrig" auf „über Ziel" — das ist die
///   Aussage der Übersicht, nicht ihre Beschriftung, und der Entwurf legt
///   beide Wörter wörtlich fest (`ernaehrung.js`, `UEBERSICHT`).
/// - „kein Ziel berechenbar" steht nur im Zustand `kein-ziel` und
///   **nie** während des Ladens (Fehler `01`).
///
/// **Zwei Geometrie-Zusicherungen gibt es trotzdem**, und sie sind keine
/// Layout-Tests: „Eine Anzeige, die es gibt, hat genau eine Form" ist eine
/// Regel über **Zustände** — Werte da, keine Werte, lädt müssen dieselbe
/// Höhe und dieselbe Stelle haben, sonst springt der Schirm, sobald ein
/// Wert eintrifft. Geprüft wird deshalb, dass der Abschnitt **unter** der
/// Übersicht in allen drei Zuständen an derselben Stelle steht, und dass
/// Aufklappen weiter unten nichts darüber verschiebt. Welche Höhe das ist,
/// prüft niemand.
///
/// **Nicht geprüft, bewusst:**
///
/// - Die Zahlen der Herleitung und der Inhalt des Verlaufsdiagramms. Beide
///   liegen in eingeklappten Abschnitten; geprüft wird, dass sie
///   eingeklappt sind und aufgehen.
/// - Wohin die Türen führen. Mahlzeiten-Schirm (Task 9), Erfassen
///   (Task 7) und Rezepte (Task 8) gibt es noch nicht. Geprüft wird
///   stattdessen die Regel, die `docs/screens/pruefen.mjs` am Board
///   durchsetzt: **jedes sichtbare Chevron sitzt unter einem tippbaren
///   Vorfahren** — keine Zeile, die drückbar aussieht und nirgendwohin
///   führt. *(Eine Ausnahme: Beim Grund „kein Ziel berechenbar" wird
///   geprüft, dass sein **Text** keinen Ort nennt, den es nicht gibt —
///   siehe unten. Wohin er navigiert, prüft auch dort niemand.)*
/// - Farben, Abstände, Schriften und Schriftgrößen.
///
/// **Die Reihenfolge ist die eine Ausnahme von „kein Layout".** Sie ist
/// Tims ausdrückliche Vorgabe vom 04.11.2026 und wird deshalb geprüft —
/// aber über die **Reihenfolge der Schlüssel im Widget-Baum**, nicht über
/// Pixel: Der Fall „die Abschnitte stehen in der Reihenfolge des
/// Entwurfs" sammelt die Schlüssel in Baumreihenfolge ein und vergleicht
/// die Liste. Kein Abstand, keine Höhe, keine Koordinate.
///
/// ## Der Schirm stößt den Stammdaten-Lauf an
///
/// Tims Befund auf dem Gerät, 04.11.2026: Er hat Zielgewicht und
/// Zieldatum eingetragen, und der Schirm verlangte sie weiter. Die
/// Ursache liegt nicht am Körperziel, sondern eine Ebene
/// tiefer: `stammdatenAusHealthProvider` (#306) wurde von **niemandem**
/// beobachtet. Ein `FutureProvider` ohne Beobachter läuft nie; Größe und
/// Geburtsjahr landeten nie in der Stammdaten-Tabelle, `kalorienziel`
/// lieferte `null`, und die Zeile „Ziel fehlt" blieb stehen — egal was
/// Tim eintrug.
///
/// Festgenagelt wird das **am Verhalten**, nicht daran, dass irgendwo
/// `ref.watch` im Quelltext steht: Der Schirm wird gebaut, und danach ist
/// der Kanal nach den Körpermerkmalen gefragt worden und die gelesenen
/// Werte stehen in der Tabelle. Dasselbe Muster wie „HeuteView löst die
/// Anfrage aus" in `test/health/freigabe_test.dart` — dort zählt eine
/// Mitschnitt-Quelle die Aufrufe, hier auch.
///
/// ## Was der Grund „kein Ziel berechenbar" leisten muss
///
/// Die Zeile hieß „Größe, Geburtsjahr und Körperziel" und schickte nach
/// *Einstellungen ▸ Über dich*. Beides war falsch, und beides ist eine
/// **Zusage**, keine Beschreibung (`CLAUDE.md`: „Keine Zusage stehen
/// lassen, die nicht mehr stimmt"). Geprüft wird deshalb, was der Text
/// leisten muss — nicht sein Wortlaut:
///
/// 1. **Er nennt genau die Angaben, die wirklich fehlen**, und keine
///    weitere. Welche das sind, hängt an der Datenlage; die Fälle
///    variieren sie einzeln.
/// 2. **Das Körperziel ist kein Grund.** Ohne Zielgewicht und Zieldatum
///    ist der Überschuss schlicht `0`, und das Ziel steht trotzdem — der
///    Fall „ohne Körperziel gibt es trotzdem ein Ziel" beweist es, statt
///    es zu behaupten.
/// 3. **Er nennt die Herkunft und lässt beide Möglichkeiten offen.**
///    Größe, Geburtsjahr und Gewicht kommen aus Apple Health; „dort nicht
///    hinterlegt" und „nicht freigegeben" sind nicht unterscheidbar, weil
///    Apple den Lesestatus nicht verrät (`CLAUDE.md`). Ein Text, der nur
///    die erste Hälfte nennt, behauptet die zweite als ausgeschlossen.
/// 4. **Er behauptet nicht, es sei nichts getrackt worden** — dieselbe
///    Regel, nur andersherum.
/// 5. **Er nennt keinen Ort, den es nicht gibt.** *Über dich* gibt es
///    nicht; was es gibt, ist *Mehr ▸ Vorläufige Werte*
///    (`lib/shell/vorlaeufige_werte_view.dart`), und der führt **nur**
///    zum Körperziel.
///
/// **Die Prüfung ist absichtlich zweigeteilt**: Verboten ist etwas nur im
/// engen Bereich — in der Zeile selbst und in dem Dialog, den ein Tipp
/// darauf öffnet. Gefordert ist es im weiten — alles, was nach dem Tipp
/// zu sehen ist. Sonst scheiterte ein Schirm, der statt eines Dialogs
/// tatsächlich nach *Vorläufige Werte* navigiert, an den Wörtern
/// „Zielgewicht" und „Zieldatum", die dort zu Recht stehen.
///
/// ## Die Mahlzeitenzeilen sind vom Ladezustand ausgenommen
///
/// Sie zeigen Tims **eigene** Einträge, und die kommen aus der eigenen
/// Tabelle. Dort gibt es keinen Lauf, der leer ausgehen kann: „noch nichts
/// eingetragen" ist eine Aussage und kein Grund. Ein Ladeplatzhalter steht
/// deshalb nur in der Übersicht (Bogen, große Zahl, drei Balken) — also
/// genau dort, wo Apple Health mitredet. Dasselbe Muster wie
/// `erholungProvider`/`schlafEintraegeProvider` (`.value ?? const []`).
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und erkennbar künstlich — runde Hunderter, keine Werte
/// aus `ernaehrung.js` (`CLAUDE.md`: keine echten Gesundheitsdaten, auch
/// nicht in Tests).
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  DailyMetrics tageswert(String tag) => DailyMetrics(
    tag: tag,
    activeKcal: 600,
    basalKcal: 1600,
    weightKg: 80,
  );

  Eintrag eintrag({
    required String tag,
    Mahlzeit mahlzeit = Mahlzeit.mittag,
    int stundeUtc = 10,
    String name = 'Testgericht',
    double kcal = 1200,
    double eiweissG = 100,
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      kohlenhydrateG: 150,
      fettG: 40,
    ),
  );

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die Hülle um den Schirm.
  ///
  /// **[quelle] ist nicht optional, auch wenn sie hier meist nichts tut.**
  /// `healthProvider` wirft ohne Override (`health_provider.dart`), und der
  /// Schirm stößt seit dem 04.11.2026 den Stammdaten-Lauf an — jeder Fall
  /// braucht also eine Quelle. Die Vorgabe [_StilleQuelle] kann das zweite
  /// Protokoll **nicht**: Sie lässt den Lauf durch, ohne etwas zu füllen,
  /// und lässt damit jeden Fall unberührt, der mit den Stammdaten nichts
  /// zu tun hat.
  ///
  /// **[eigeneStammdaten] schaltet den `stammdatenProvider`-Override ab.**
  /// Die Fälle zum Lauf brauchen den echten Notifier auf der echten
  /// Datenbank — nur dort ist zu sehen, ob der Lauf etwas hinterlässt.
  ({ProviderContainer container, AppCache db, Widget app}) harness({
    Messwert<List<FremdeMahlzeit>>? fremde,
    Messwert<List<DailyMetrics>>? tageswerte,
    Stammdaten stammdaten = vollstaendig,
    bool eigeneStammdaten = false,
    HealthReading? quelle,
    AppCache? datenbank,
  }) {
    final db = datenbank ?? AppCache(NativeDatabase.memory());
    if (datenbank == null) addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(quelle ?? _StilleQuelle()),
        if (!eigeneStammdaten)
          stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>([
                  tageswert(gestern),
                  tageswert(heute),
                ], stand: jetzt, laeuft: false),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            fremde ??
                Bekannt<List<FremdeMahlzeit>>(
                  const [],
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      db: db,
      app: BehaelterImBaum(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: ErnaehrungView()),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    // Groß genug, damit der ganze Schirm gleichzeitig gebaut ist und kein
    // Test selbst scrollen muss.
    tester.view.physicalSize = const Size(900, 4800);
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

  /// Die drei Makrobalken der Übersicht, über ihre Schlüssel — die
  /// Zuordnung Balken → Nährwert steht im Schlüssel, nicht in der
  /// Reihenfolge (die prüft `ernaehrung_uebersicht_test.dart`).
  const makros = ['kohlenhydrate', 'eiweiss', 'fett'];

  MakroSaeule saeule(WidgetTester tester, String name) => tester
      .widget<MakroSaeule>(find.byKey(Key('ernaehrung-uebersicht-$name')));

  MakroSaeule eiweiss(WidgetTester tester) => saeule(tester, 'eiweiss');
  MakroSaeule kohlenhydrate(WidgetTester tester) =>
      saeule(tester, 'kohlenhydrate');
  MakroSaeule fett(WidgetTester tester) => saeule(tester, 'fett');

  UebersichtBogen bogen(WidgetTester tester) => tester.widget<UebersichtBogen>(
    find.byKey(const Key('ernaehrung-uebersicht-bogen')),
  );

  /// Die große Zahl im Bogen und ihr Wort, klein geschrieben. **Wirft der
  /// Schlüssel nichts aus, scheitert der Aufruf** — eine leere Zeichenkette
  /// ließe jedes `isNot(contains(…))` unbemerkt durchgehen.
  String grosseZahl(WidgetTester tester) {
    final stelle = find.byKey(const Key('ernaehrung-uebersicht-uebrig'));
    expect(stelle, findsOneWidget);
    return textUnter(
      tester,
      const Key('ernaehrung-uebersicht-uebrig'),
    ).toLowerCase();
  }

  /// Der gerechnete Tag, so wie der Schirm ihn gerade sieht — die Stelle,
  /// an der ein Fall ein Ziel mit dem Kern vergleichen kann, ohne dessen
  /// Formel ein zweites Mal hinzuschreiben.
  ErnaehrungsTag gezeigterTag(
    ({ProviderContainer container, AppCache db, Widget app}) h,
  ) => h.container.read(
    ernaehrungsTagProvider(h.container.read(offenerTagProvider)),
  );

  /// `true`, wenn irgendein Vorfahre dieses Elements ein `GestureDetector`
  /// mit gesetztem `onTap` oder ein `CupertinoButton` mit gesetztem
  /// `onPressed` ist — die beiden Wege, über die diese reine
  /// Cupertino-App etwas antippbar macht (wörtlich wie in
  /// `erholung_view_test.dart` und `mehr_view_test.dart`).
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

  const mahlzeitSchluessel = {
    Mahlzeit.fruehstueck: Key('ernaehrung-mahlzeit-fruehstueck'),
    Mahlzeit.mittag: Key('ernaehrung-mahlzeit-mittag'),
    Mahlzeit.snack: Key('ernaehrung-mahlzeit-snack'),
    Mahlzeit.abend: Key('ernaehrung-mahlzeit-abend'),
  };

  /// Die Abschnitte in der Reihenfolge, die Tim am 04.11.2026 vorgegeben
  /// hat: Ring → Mahlzeiten → Wasser → Rezepte → Verlauf → Herleitung →
  /// Erfassen-Leiste. Seit dem 07.11.2026 steht die Übersicht an der
  /// Stelle des Rings. Die Datumszeile steht als Kopf davor.
  const reihenfolge = [
    Key('ernaehrung-datumszeile'),
    Key('ernaehrung-uebersicht'),
    Key('ernaehrung-mahlzeiten'),
    Key('ernaehrung-wasser'),
    Key('ernaehrung-rezepte'),
    Key('ernaehrung-verlauf-kopf'),
    Key('ernaehrung-herleitung-kopf'),
    Key('ernaehrung-wege'),
  ];

  /// Sammelt die Schlüssel aus [reihenfolge] in **Baumreihenfolge** ein.
  ///
  /// Über den Elementbaum und nicht über Koordinaten: Die Reihenfolge ist
  /// Tims Vorgabe, die Pixel sind es nicht. `visitChildElements` läuft die
  /// Kinder in Baufolge ab, und das ist bei einer `Column` genau die
  /// Reihenfolge von oben nach unten.
  List<Key> schluesselInBaumfolge(WidgetTester tester) {
    final gefunden = <Key>[];
    void besuche(Element element) {
      final key = element.widget.key;
      if (key != null && reihenfolge.contains(key)) gefunden.add(key);
      element.visitChildElements(besuche);
    }

    besuche(tester.element(find.byType(ErnaehrungView)));
    return gefunden;
  }

  /// Der Text der Zeile „kein Ziel berechenbar", klein geschrieben.
  String grundzeile(WidgetTester tester) =>
      textUnter(tester, const Key('ernaehrung-ziel-fehlt')).toLowerCase();

  /// Was ein Dialog sagt, wenn nach dem Tipp einer da ist — sonst der
  /// leere String. Der **enge** Bereich der Prüfung: Hier darf nichts
  /// Falsches stehen.
  String dialogtext(WidgetTester tester) {
    final dialog = find.byType(CupertinoAlertDialog);
    if (dialog.evaluate().isEmpty) return '';
    return tester
        .widgetList<Text>(
          find.descendant(of: dialog, matching: find.byType(Text)),
        )
        .map(textOf)
        .join(' ')
        .toLowerCase();
  }

  // ───────────────────────────────────────────────────────────────────────

  group('Während des Ladens (docs/todo/01)', () {
    testWidgets('steht nirgends ein „keine Daten"-Grund', (tester) async {
      final h = harness(
        fremde: const NochNie<List<FremdeMahlzeit>>(),
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(
        texte,
        isNot(contains('kein ziel')),
        reason:
            'der Grund gehört zu einem FERTIGEN Lauf ohne Treffer — '
            'während des Laufs ist nichts entschieden',
      );
      expect(texte, isNot(contains('berechenbar')));
      expect(
        find.byKey(const Key('ernaehrung-ziel-fehlt')),
        findsNothing,
        reason: 'der Weg in die Einstellungen gehört zum Zustand kein-ziel',
      );
      expect(
        grosseZahl(tester),
        isNot(contains(ohneWert)),
        reason: '`–/–` ist die Antwort auf „gelesen, kein Wert"',
      );
    });

    testWidgets('steht an der Stelle der Werte der Ladeplatzhalter', (
      tester,
    ) async {
      final h = harness(
        fremde: const NochNie<List<FremdeMahlzeit>>(),
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );
      await zeige(tester, h.app);

      expect(find.byType(Platzhalter), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.byType(MakroSaeule),
        ),
        findsNWidgets(3),
        reason: 'auch während des Ladens sind es drei Balken',
      );
      expect(
        bogen(tester).anteil,
        isNull,
        reason: 'ungefüllt, nicht auf 0 — gelesen ist noch nichts',
      );
      for (final name in makros) {
        final balken = saeule(tester, name);
        expect(balken.wert, isNull, reason: name);
        expect(
          balken.platzhalter,
          isNotNull,
          reason:
              '$name: nur mit gesetztem `platzhalter` zeichnet '
              '`MakroSaeule` die graue Form statt des Textes — und nur dann '
              'sagt der Vorlesetext „wird geladen" statt „keine Werte"',
        );
      }
    });

    testWidgets('was nicht an Apple Health hängt, steht trotzdem schon da', (
      tester,
    ) async {
      final h = harness(
        fremde: const NochNie<List<FremdeMahlzeit>>(),
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-datumszeile')), findsOneWidget);
      expect(find.byKey(const Key('ernaehrung-mahlzeiten')), findsOneWidget);
      expect(find.byKey(const Key('ernaehrung-verlauf-kopf')), findsOneWidget);
      expect(
        find.byKey(const Key('ernaehrung-herleitung-kopf')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ernaehrung-rezepte')), findsOneWidget);
      expect(find.byKey(const Key('ernaehrung-wasser')), findsOneWidget);
      expect(find.byKey(const Key('ernaehrung-wege')), findsOneWidget);
      expect(find.byType(Hinweisfuss), findsOneWidget);
    });

    testWidgets(
      'der Platzhalter gehört allein in NochNie — ein nachladender Wert '
      'bleibt stehen',
      (tester) async {
        final h = harness(
          fremde: Bekannt<List<FremdeMahlzeit>>(
            const [],
            stand: jetzt,
            laeuft: true,
          ),
        );
        await ErnaehrungRepository(h.db).buche(eintrag(tag: heute, kcal: 1200));
        await zeige(tester, h.app);

        expect(
          find.byType(Platzhalter),
          findsNothing,
          reason:
              'ein Platzhalter, der bei jedem Zug von oben aufblitzt, ist '
              'genau das Flackern, gegen das die Regel gebaut ist',
        );
        expect(eiweiss(tester).wert, isNotNull);
        expect(grosseZahl(tester), contains('übrig'));
      },
    );
  });

  group('Die Übersicht (statt der drei Ringe, Tim, 07.11.2026)', () {
    testWidgets('drei Balken, und die Kalorien sind keiner davon', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      final balken = tester.widgetList<MakroSaeule>(
        find.descendant(
          of: find.byKey(const Key('ernaehrung-uebersicht')),
          matching: find.byType(MakroSaeule),
        ),
      );
      expect(
        balken,
        hasLength(3),
        reason:
            'Kohlenhydrate, Eiweiß, Fett (`ernaehrung.js`, `UEBERSICHT`). '
            'Die Kalorien stehen im Bogen, nicht als Balken',
      );
      expect(
        balken.map((saeule) => saeule.label.toLowerCase()),
        everyElement(isNot(contains('kalorien'))),
        reason:
            'ein Kalorienbalken unter den dreien stünde doppelt da — die '
            'Kalorien sind „Übrig", „Gegessen" und der Bogen',
      );
    });

    testWidgets('mit Werten zeigen die Balken das Gegessene gegen das Ziel', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(
        h.db,
      ).buche(eintrag(tag: heute, kcal: 1200, eiweissG: 100));
      await zeige(tester, h.app);

      // `eintrag` trägt 150 g Kohlenhydrate und 40 g Fett — erfundene,
      // runde Zahlen aus dem Kopf dieser Datei.
      expect(eiweiss(tester).wert, 100);
      expect(kohlenhydrate(tester).wert, 150);
      expect(fett(tester).wert, 40);
      for (final name in makros) {
        expect(saeule(tester, name).ziel, greaterThan(0), reason: name);
      }
      expect(
        grosseZahl(tester),
        contains('übrig'),
        reason: 'unter dem Ziel nennt die große Zahl den Rest',
      );
      expect(find.byType(Platzhalter), findsNothing);
    });

    testWidgets(
      'das Kohlenhydratziel ist das gerechnete aus dem Tag (#310)',
      (tester) async {
        final h = harness();
        await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
        await zeige(tester, h.app);

        final gerechnet = gezeigterTag(h).makroziele.kohlenhydrateZielG;
        expect(
          gerechnet,
          isNotNull,
          reason:
              'Vorbedingung: mit Gewicht und Kalorienziel gibt es eines — '
              'sonst prüft die nächste Zeile nichts',
        );
        expect(
          kohlenhydrate(tester).ziel,
          gerechnet,
          reason:
              'der Balken zeigt, was `makrozieleFuer(gewichtKg:, '
              'kalorienzielKcal:)` ausgerechnet hat. Eine eigene Zahl im '
              'Schirm wäre eine zweite Rechnung, die der ersten '
              'widersprechen kann',
        );
      },
    );

    // Gestrichen (Test-Agent, 10.11.2026): „ohne Kalorienziel gibt es
    // keinen Kohlenhydratring — ungefüllt, nicht auf 0". Dieselbe Aussage
    // für den Balken trifft `ernaehrung_uebersicht_test.dart`, „Ohne Ziel:
    // dieselbe Form, ungefüllt, `–/–` statt 0".

    testWidgets(
      'ohne Ziel steht in der großen Zahl `–/–` und nicht `0`',
      (tester) async {
        final h = harness(stammdaten: const Stammdaten());
        await ErnaehrungRepository(h.db).buche(eintrag(tag: heute, kcal: 1200));
        await zeige(tester, h.app);

        final gross = grosseZahl(tester);
        expect(gross, contains(ohneWert));
        expect(
          gross,
          isNot(contains(RegExp(r'(^|\s)0(\s|$)'))),
          reason: 'eine 0 behauptete „nichts übrig"',
        );
        // „Übrig" ist seit dem 07.11.2026 die Beschriftung unter der Zahl
        // und steht in jeder Form; dass es ohne Ziel keinen Rest gibt,
        // sagen `–/–` und der ungefüllte Bogen.
        expect(
          bogen(tester).anteil,
          isNull,
          reason: 'ohne Ziel gibt es keinen Rest — ungefüllt, nicht auf 0',
        );
        expect(
          find.byKey(const Key('ernaehrung-ziel-fehlt')),
          findsOneWidget,
          reason:
              'der Schirm sagt nicht nur, dass etwas fehlt, er führt '
              'dorthin',
        );
      },
    );

    testWidgets(
      'über dem Ziel läuft der Bogen nicht weiter, er ist voll — und die '
      'große Zahl wechselt',
      (tester) async {
        final h = harness();
        await ErnaehrungRepository(
          h.db,
        ).buche(eintrag(tag: heute, kcal: 4000, eiweissG: 200));
        await zeige(tester, h.app);

        expect(
          bogen(tester).anteil,
          1,
          reason:
              'gedeckelt — eine zweite Runde wie am Ring gibt es im Bogen '
              'nicht',
        );
        expect(bogen(tester).ueber, isTrue);

        final balken = eiweiss(tester);
        expect(
          balken.wert,
          greaterThan(balken.ziel!),
          reason:
              'der Balken bekommt das Gegessene, nicht ein auf das Ziel '
              'gekapptes — nur so kann er zeigen, dass es darüber ist',
        );

        final gross = grosseZahl(tester);
        expect(gross, contains('über ziel'));
        expect(gross, isNot(contains('übrig')));
      },
    );

    // Gestrichen (Test-Agent, 10.11.2026): „ohne Gewicht steht jeder der
    // drei Ringe trotzdem, mit `–/–`". Dieselbe Aussage für die Balken —
    // Wert `null`, `–/–`, kein Platzhalter nach dem Lauf — trifft
    // `ernaehrung_uebersicht_test.dart`, „ohne Gewicht stehen alle drei
    // Balken mit `–/–`".

    testWidgets('der Vorlesetext nennt den Zustand, nicht das Zeichen', (
      tester,
    ) async {
      final h = harness(stammdaten: const Stammdaten());
      await zeige(tester, h.app);

      expect(
        // `[^,]*` hält die Prüfung bei **einem** Balken: Lägen die drei
        // Vorlesetexte je in einem Label zusammen, ließe ein loses `.*`
        // „Eiweiß …, Kohlenhydrate, keine Werte" als Treffer für jeden der
        // drei durchgehen.
        find.bySemanticsLabel(RegExp('Kohlenhydrate[^,]*, *keine Werte')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(ohneWert))),
        findsNothing,
        reason:
            'VoiceOver läse „Strich Schrägstrich Strich" vor — ein '
            'ausdrückliches Anti-Ziel der Leerzustands-Spec',
      );
    });

    testWidgets('und während des Ladens sagt jeder „wird geladen"', (
      tester,
    ) async {
      final h = harness(
        fremde: const NochNie<List<FremdeMahlzeit>>(),
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );
      await zeige(tester, h.app);

      for (final name in const ['Eiweiß', 'Kohlenhydrate', 'Fett']) {
        expect(
          find.bySemanticsLabel(RegExp('$name[^,]*, *wird geladen')),
          findsOneWidget,
          reason: '$name: während des Laufs ist nichts entschieden',
        );
        expect(
          find.bySemanticsLabel(RegExp('$name[^,]*, *keine Werte')),
          findsNothing,
          reason: '$name: „keine Werte" wäre eine Aussage über den Lauf',
        );
      }
    });

    testWidgets('den eigenen Makroblock gibt es nicht mehr', (tester) async {
      // Tim, 04.11.2026: „dann brauchen wir das danach nicht mehr und
      // sparen Platz". Dieselben drei Zahlen standen zweimal auf dem
      // Schirm und kosteten eine halbe Bildschirmhöhe.
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      for (final key in const [
        Key('ernaehrung-makros'),
        Key('ernaehrung-makro-eiweiss'),
        Key('ernaehrung-makro-kohlenhydrate'),
        Key('ernaehrung-makro-fett'),
      ]) {
        expect(
          find.byKey(key),
          findsNothing,
          reason:
              'der Block ist **ersatzlos** entfallen; derselbe Schlüssel '
              'über einem Balken der Übersicht behauptete, es gäbe ihn '
              'noch',
        );
      }
      expect(
        find.byType(MakroBalken),
        findsNothing,
        reason: 'die Balken waren der Block — ohne ihn gibt es keine',
      );
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets(
      'Werte da, keine Werte und lädt stehen an derselben Stelle',
      (tester) async {
        // Gemessen wird der Abschnitt **unter** der Übersicht: Wächst oder
        // schrumpft die Karte zwischen den Zuständen, rutscht alles
        // darunter — genau der Sprung, den die Regel verhindern soll.
        Future<Rect> stelleBei(
          ({ProviderContainer container, AppCache db, Widget app}) h,
        ) async {
          await zeige(tester, h.app);
          // Seit dem Umbau vom 04.11.2026 stehen die Mahlzeiten direkt
          // unter dem Ring, seit dem 07.11.2026 unter der Übersicht; der
          // Makroblock, der hier vorher gemessen wurde, ist entfallen.
          return tester.getRect(find.byKey(const Key('ernaehrung-mahlzeiten')));
        }

        final mitWerten = harness();
        await ErnaehrungRepository(mitWerten.db).buche(eintrag(tag: heute));
        final a = await stelleBei(mitWerten);

        final ohneWerte = harness();
        final b = await stelleBei(ohneWerte);

        final laedt = harness(
          fremde: const NochNie<List<FremdeMahlzeit>>(),
          tageswerte: const NochNie<List<DailyMetrics>>(),
        );
        final c = await stelleBei(laedt);

        expect(b, a, reason: 'ohne Werte darf nichts springen');
        expect(c, a, reason: 'und während des Ladens auch nicht');
      },
    );

    testWidgets('die vier Mahlzeitenzeilen stehen in jedem Zustand', (
      tester,
    ) async {
      Future<void> pruefe(
        ({ProviderContainer container, AppCache db, Widget app}) h,
        String zustand,
      ) async {
        await zeige(tester, h.app);
        for (final key in mahlzeitSchluessel.values) {
          expect(
            find.byKey(key),
            findsOneWidget,
            reason:
                '$zustand: eine Mahlzeitenzeile ohne Eintrag verschwindet '
                'nicht, sie zeigt ein Plus',
          );
        }
      }

      await pruefe(harness(), 'leer');
      await pruefe(
        harness(
          fremde: const NochNie<List<FremdeMahlzeit>>(),
          tageswerte: const NochNie<List<DailyMetrics>>(),
        ),
        'lädt',
      );
      await pruefe(harness(stammdaten: const Stammdaten()), 'kein Ziel');

      final mitWerten = harness();
      await ErnaehrungRepository(mitWerten.db).buche(eintrag(tag: heute));
      await pruefe(mitWerten, 'Tag läuft');
    });

    testWidgets(
      'eine Mahlzeitenzeile ohne Eintrag sagt es — und zwar nicht mit 0',
      (tester) async {
        final h = harness();
        await ErnaehrungRepository(
          h.db,
        ).buche(eintrag(tag: heute, mahlzeit: Mahlzeit.mittag));
        await zeige(tester, h.app);

        expect(
          find.bySemanticsLabel(RegExp('Snack.*nichts eingetragen')),
          findsOneWidget,
          reason:
              'der Vorlesetext nennt den Zustand — Spec: „Frühstück, '
              'nichts eingetragen"',
        );
      },
    );
  });

  group('Blättern über ‹ ›', () {
    testWidgets('‹ wechselt den Tag, und der Schirm lädt ihn selbst', (
      tester,
    ) async {
      final h = harness();
      final repo = ErnaehrungRepository(h.db);
      await repo.buche(eintrag(tag: heute, kcal: 1200, eiweissG: 100));
      await repo.buche(eintrag(tag: gestern, kcal: 900, eiweissG: 200));
      await zeige(tester, h.app);

      // Abgelesen am Eiweißbalken der Übersicht (bis 07.11.2026 am
      // Eiweißring): Die große Zahl nennt den **Rest**, der
      // zwischen den beiden Tagen auch am Ziel hängt (#229).
      expect(eiweiss(tester).wert, 100);
      final kopfVorher = textUnter(tester, const Key('ernaehrung-datumszeile'));

      await tester.tap(find.byKey(const Key('ernaehrung-zurueck')));
      await tester.pumpAndSettle();

      expect(h.container.read(offenerTagProvider), gestern);
      expect(
        eiweiss(tester).wert,
        200,
        reason: 'der Schirm besorgt sich die Daten des neuen Tages selbst',
      );
      expect(
        textUnter(tester, const Key('ernaehrung-datumszeile')),
        isNot(kopfVorher),
      );
    });

    testWidgets('› führt wieder zurück nach heute', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute, kcal: 1200));
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('ernaehrung-zurueck')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ernaehrung-vor')));
      await tester.pumpAndSettle();

      expect(h.container.read(offenerTagProvider), heute);
      expect(eiweiss(tester).wert, 100);
    });
  });

  group('Verlauf und Herleitung', () {
    testWidgets('beide stehen eingeklappt da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-verlauf-kopf')), findsOneWidget);
      expect(find.byKey(const Key('ernaehrung-verlauf-inhalt')), findsNothing);
      expect(
        find.byKey(const Key('ernaehrung-herleitung-kopf')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        findsNothing,
      );
    });

    testWidgets('ein Tipp klappt auf, der nächste wieder zu', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      await tester.tap(find.byKey(const Key('ernaehrung-herleitung-kopf')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('ernaehrung-herleitung-kopf')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ernaehrung-herleitung-inhalt')),
        findsNothing,
      );
    });

    testWidgets('beim Aufklappen des Verlaufs springt nichts darüber', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      // Alles, was nach Tims Reihenfolge über dem Verlauf steht.
      const darueber = [
        Key('ernaehrung-uebersicht'),
        Key('ernaehrung-mahlzeiten'),
        Key('ernaehrung-wasser'),
        Key('ernaehrung-rezepte'),
      ];
      final vorher = {
        for (final key in darueber) key: tester.getRect(find.byKey(key)),
      };
      final herleitungVorher = tester.getRect(
        find.byKey(const Key('ernaehrung-herleitung-kopf')),
      );

      await tester.tap(find.byKey(const Key('ernaehrung-verlauf-kopf')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ernaehrung-verlauf-inhalt')), findsOneWidget);
      for (final key in darueber) {
        expect(
          tester.getRect(find.byKey(key)),
          vorher[key],
          reason:
              '$key steht über dem Verlauf — aufklappen schiebt nur, was '
              'darunter liegt',
        );
      }
      expect(
        tester.getRect(find.byKey(const Key('ernaehrung-herleitung-kopf'))).top,
        greaterThan(herleitungVorher.top),
        reason:
            'die Herleitung steht darunter und rutscht mit — stünde sie '
            'oben, bewegte sie sich nicht',
      );
    });

    testWidgets(
      'und beim Aufklappen der Herleitung erst recht nicht — sie steht '
      'ganz unten',
      (tester) async {
        // Die Herleitung ist seit dem 04.11.2026 der letzte Abschnitt vor
        // der Erfassen-Leiste. Über ihr darf sich beim Aufklappen nichts
        // mehr bewegen, auch der Verlauf nicht.
        final h = harness();
        await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
        await zeige(tester, h.app);

        const darueber = [
          Key('ernaehrung-uebersicht'),
          Key('ernaehrung-mahlzeiten'),
          Key('ernaehrung-wasser'),
          Key('ernaehrung-rezepte'),
          Key('ernaehrung-verlauf-kopf'),
        ];
        final vorher = {
          for (final key in darueber) key: tester.getRect(find.byKey(key)),
        };

        await tester.tap(find.byKey(const Key('ernaehrung-herleitung-kopf')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('ernaehrung-herleitung-inhalt')),
          findsOneWidget,
        );
        for (final key in darueber) {
          expect(
            tester.getRect(find.byKey(key)),
            vorher[key],
            reason: '$key steht über der Herleitung',
          );
        }
      },
    );
  });

  group('Der Schirm hält, was er zeigt (docs/todo/32)', () {
    testWidgets('ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute, kcal: 1200));

      final gesehen = <Messwert<Naehrwerte>>[];
      h.container.listen(
        ernaehrungsTagProvider(heute),
        (_, next) => gesehen.add(next.gegessen),
        fireImmediately: true,
      );

      await zeige(tester, h.app);
      expect(eiweiss(tester).wert, 100);
      final zahlVorher = grosseZahl(tester);
      expect(zahlVorher, contains('übrig'));

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

      expect(eiweiss(tester).wert, 100);
      expect(
        grosseZahl(tester),
        zahlVorher,
        reason: 'der Rest in der Übersicht steht nach dem Zurück wieder da',
      );
      expect(find.byType(Platzhalter), findsNothing);
      expect(
        alleTexte(tester),
        isNot(contains('kein ziel')),
        reason: 'nach dem Zurückkommen steht kein Leerstand da',
      );

      // Der Vorlauf vor dem ersten Wert ist bauartbedingt `NochNie`
      // (dieselbe Begründung wie im Kopf von `erholung_view_test.dart`:
      // `fireImmediately` ruft synchron, bevor irgendein `AsyncNotifier`
      // durch ist). Gezählt wird ab dem ersten bekannten Wert — ab da ist
      // jedes `NochNie` Fehler 32.
      final abErstemWert = gesehen
          .skipWhile((messwert) => messwert is NochNie<Naehrwerte>)
          .toList();
      expect(
        abErstemWert,
        isNotEmpty,
        reason:
            'Vorbedingung: irgendwann stand ein Wert da — sonst prüft die '
            'nächste Zeile nichts',
      );
      expect(
        abErstemWert.whereType<NochNie<Naehrwerte>>(),
        isEmpty,
        reason:
            'ein Wert, der einmal dastand, verschwindet nicht wieder — '
            'weder beim Wegnavigieren noch beim Zurückkommen',
      );
    });
  });

  group('Keine Zeile, die drückbar aussieht und nirgendwohin führt', () {
    testWidgets('jedes sichtbare Chevron sitzt unter einem tippbaren Vorfahren', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      final chevrons = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
      );
      expect(
        chevrons,
        findsWidgets,
        reason: 'sonst prüft dieser Test gar nichts',
      );
      for (final element in chevrons.evaluate()) {
        expect(
          tippbar(element),
          isTrue,
          reason:
              'ein Winkel ohne Tür ist genau der Fehler, den '
              '`docs/screens/pruefen.mjs` am Board verhindert',
        );
      }
    });

    testWidgets('baut ohne Ausnahme und ohne ErrorWidget', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Die Reihenfolge der Abschnitte (Tim, 04.11. und 07.11.2026)', () {
    testWidgets(
      'Übersicht, Mahlzeiten, Wasser, Rezepte, Verlauf, Herleitung, '
      'Erfassen',
      (tester) async {
        final h = harness();
        await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
        await zeige(tester, h.app);

        expect(
          schluesselInBaumfolge(tester),
          reihenfolge,
          reason:
              'Tims Vorgabe vom 04.11.2026, nachgezogen im Entwurfsboard '
              '(`docs/screens/screens/ernaehrung.js`, Commit eab3818), '
              'seit dem 07.11.2026 mit der Übersicht an der Stelle des '
              'Rings: '
              'oben, was man zehnmal am Tag sucht; unten, was man einmal '
              'nachschlägt. Wasser gehört zum Eingetragenen und damit '
              'neben die Mahlzeiten, die Herleitung ganz nach unten',
        );
      },
    );

    testWidgets('auch wenn der Grund zwischen Übersicht und Mahlzeiten '
        'steht', (
      tester,
    ) async {
      final h = harness(stammdaten: const Stammdaten());
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-ziel-fehlt')), findsOneWidget);
      expect(schluesselInBaumfolge(tester), reihenfolge);
    });

    testWidgets('und während des Ladens', (tester) async {
      final h = harness(
        fremde: const NochNie<List<FremdeMahlzeit>>(),
        tageswerte: const NochNie<List<DailyMetrics>>(),
      );
      await zeige(tester, h.app);

      expect(schluesselInBaumfolge(tester), reihenfolge);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Der Schirm stößt den Stammdaten-Lauf an (Tim, 04.11.2026)', () {
    /// Die Quelle, die Größe und Geburtsjahr kennt. Beide Zahlen sind
    /// erfunden (`CLAUDE.md`: keine echten Gesundheitsdaten in Tests).
    _Merkmalsquelle merkmalsquelle() => _Merkmalsquelle(
      const BodyCharacteristics(heightCm: 180, birthYear: 1990),
    );

    testWidgets('er fragt den Kanal, ohne dass jemand ihn von Hand liest', (
      tester,
    ) async {
      final quelle = merkmalsquelle();
      final h = harness(eigeneStammdaten: true, quelle: quelle);
      await zeige(tester, h.app);

      expect(
        h.container.exists(stammdatenAusHealthProvider),
        isTrue,
        reason:
            'ein `FutureProvider`, den niemand anfordert, läuft nie — '
            'genau das war der Fehler vom 04.11.2026',
      );
      expect(
        quelle.anfragen,
        1,
        reason:
            'der Lauf ist angelaufen, weil der Schirm steht. Einmal, nicht '
            'bei jedem Bauen: Es gibt nichts mehr zu holen, sobald beide '
            'Werte abgelegt sind',
      );
    });

    testWidgets('und der Lauf hinterlässt seine Werte in der Tabelle', (
      tester,
    ) async {
      final h = harness(eigeneStammdaten: true, quelle: merkmalsquelle());
      await zeige(tester, h.app);

      expect(
        await StammdatenRepository(h.db).lies(),
        const Stammdaten(groesseCm: 180, geburtsjahr: 1990),
        reason:
            'ohne Größe und Geburtsjahr rechnet `kalorienziel` nichts — '
            'das ist die Kette, an der Tims Befund hing',
      );
    });

    testWidgets('danach steht ein Ziel da statt des Grundes', (tester) async {
      final h = harness(eigeneStammdaten: true, quelle: merkmalsquelle());
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('ernaehrung-ziel-fehlt')),
        findsNothing,
        reason:
            'genau das sah Tim: Er trug etwas ein, und die Zeile blieb '
            'stehen',
      );
      expect(gezeigterTag(h).zielKcal, isNotNull);
      expect(grosseZahl(tester), contains('übrig'));
      expect(
        kohlenhydrate(tester).ziel,
        greaterThan(0),
        reason:
            'mit dem Kalorienziel steht auch das gerechnete '
            'Kohlenhydratziel (#310)',
      );
    });

    testWidgets('eine Quelle ohne Körpermerkmale sprengt den Schirm nicht', (
      tester,
    ) async {
      // `HealthReading` verlangt `bodyCharacteristics()` nicht; eine
      // Quelle ohne das zweite Protokoll ist ein Normalfall. Der Schirm
      // steht dann ohne Ziel da — aber er steht.
      final h = harness(eigeneStammdaten: true);
      await zeige(tester, h.app);

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byKey(const Key('ernaehrung-ziel-fehlt')), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('Was der Grund „kein Ziel berechenbar" leisten muss', () {
    /// Die drei Angaben, an denen das Ziel hängt — mit dem Muster, an dem
    /// man sie im Text wiedererkennt. Die Alternativen stehen da, damit
    /// der Text nicht auf einen Wortlaut festgenagelt ist: „Geburtsjahr",
    /// „Geburtsdatum" und „Alter" sind dieselbe Auskunft.
    const muster = {
      'Größe': r'größe|grösse|groesse',
      // `\b` um „alter", damit „Alternativ" kein Treffer ist.
      'Geburtsjahr': r'geburtsjahr|geburtsdatum|\balter\b',
      'Gewicht': r'gewicht',
    };

    /// Prüft, dass der Grund **genau** [fehlt] nennt und nichts darüber
    /// hinaus — und dass er die Zusagen aus dem Dateikopf hält.
    Future<void> pruefeGrund(
      WidgetTester tester,
      ({ProviderContainer container, AppCache db, Widget app}) h,
      Set<String> fehlt,
    ) async {
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('ernaehrung-ziel-fehlt')),
        findsOneWidget,
        reason: 'Vorbedingung: ohne $fehlt gibt es kein Ziel',
      );

      final zeile = grundzeile(tester);
      await tester.tap(find.byKey(const Key('ernaehrung-ziel-fehlt')));
      await tester.pumpAndSettle();

      // Der **enge** Bereich: die Zeile und der Dialog, den sie öffnet.
      final eng = '$zeile ${dialogtext(tester)}';
      // Der **weite**: alles, was nach dem Tipp zu sehen ist. Siehe
      // Dateikopf — ein Schirm, der wirklich nach „Vorläufige Werte"
      // navigiert, darf dort „Zielgewicht" sagen.
      final weit = '$eng ${alleTexte(tester)}';

      for (final wort in const ['körperziel', 'zielgewicht', 'zieldatum']) {
        expect(
          eng,
          isNot(contains(wort)),
          reason:
              '„$wort": Das Körperziel ist kein Grund — ohne es ist der '
              'Überschuss schlicht 0, und das Ziel steht trotzdem (siehe '
              'den Fall darüber)',
        );
      }
      expect(
        eng,
        isNot(contains('über dich')),
        reason:
            '*Über dich* gibt es nicht. Was es gibt, ist '
            '*Mehr ▸ Vorläufige Werte* — und der führt nur zum Körperziel',
      );
      for (final behauptung in const [
        'nicht getrackt',
        'nichts getrackt',
        'nicht erfasst',
        'nichts erfasst',
        'nicht gemessen',
      ]) {
        expect(
          eng,
          isNot(contains(behauptung)),
          reason:
              '„$behauptung": „in Health nicht hinterlegt" und „Lesen '
              'verweigert" sind nicht unterscheidbar — Apple verrät den '
              'Lesestatus nicht (`CLAUDE.md`)',
        );
      }

      muster.forEach((angabe, regex) {
        final genannt = RegExp(regex).hasMatch(eng);
        expect(
          genannt,
          fehlt.contains(angabe),
          reason: fehlt.contains(angabe)
              ? '$angabe fehlt und muss genannt werden'
              : '$angabe steht da — ein Grund, der sie trotzdem aufzählt, '
                    'schickt Tim auf die Suche nach einem Wert, der nicht '
                    'fehlt',
        );
      });

      expect(
        RegExp('health').hasMatch(eng),
        isTrue,
        reason:
            'die fehlenden Angaben kommen aus Apple Health — wer das nicht '
            'sagt, lässt Tim in der App danach suchen. Im **engen** '
            'Bereich, sonst genügte der Fußtext des Schirms, der Apple '
            'Health ohnehin nennt',
      );
      expect(
        RegExp('freigab|freigeg|erlaub|berechtig|zugriff').hasMatch(weit),
        isTrue,
        reason:
            'beide Möglichkeiten benennen: „dort nicht hinterlegt" **und** '
            '„nicht freigegeben". Ein Text, der nur die erste nennt, '
            'behauptet die zweite als ausgeschlossen (`CLAUDE.md`)',
      );
    }

    testWidgets('ohne Körperziel gibt es trotzdem ein Ziel', (tester) async {
      // Der Beweis statt der Behauptung: Zielgewicht und Zieldatum fehlen,
      // Größe, Geburtsjahr und Gewicht stehen — und das Ziel steht auch.
      final h = harness(
        stammdaten: const Stammdaten(groesseCm: 180, geburtsjahr: 1990),
      );
      await ErnaehrungRepository(h.db).buche(eintrag(tag: heute));
      await zeige(tester, h.app);

      expect(gezeigterTag(h).zielKcal, isNotNull);
      expect(
        find.byKey(const Key('ernaehrung-ziel-fehlt')),
        findsNothing,
        reason:
            'ohne Körperziel ist der Überschuss 0, nicht „kein Ziel '
            'berechenbar"',
      );
      expect(grosseZahl(tester), isNot(contains(ohneWert)));
    });

    testWidgets('fehlen Größe und Geburtsjahr, nennt er beide', (
      tester,
    ) async {
      await pruefeGrund(tester, harness(stammdaten: const Stammdaten()), {
        'Größe',
        'Geburtsjahr',
      });
    });

    testWidgets('fehlt nur die Größe, nennt er nur sie', (tester) async {
      await pruefeGrund(
        tester,
        harness(stammdaten: const Stammdaten(geburtsjahr: 1990)),
        {'Größe'},
      );
    });

    testWidgets('fehlt nur das Geburtsjahr, nennt er nur das', (tester) async {
      await pruefeGrund(
        tester,
        harness(stammdaten: const Stammdaten(groesseCm: 180)),
        {'Geburtsjahr'},
      );
    });

    testWidgets('fehlt nur das Gewicht, nennt er das Gewicht', (tester) async {
      // Größe und Geburtsjahr stehen; was fehlt, ist die Wägung aus Apple
      // Health. Ein Grund, der hier „Größe und Geburtsjahr" sagt, schickt
      // Tim an die falsche Stelle.
      await pruefeGrund(
        tester,
        harness(tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt)),
        {'Gewicht'},
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

/// Eine Quelle, die die sieben Zeitraum-Methoden kann und sonst nichts —
/// das zweite Protokoll erfüllt sie **nicht**. Die Vorgabe der Testhülle:
/// `healthProvider` wirft ohne Override, und ein Fall, der mit den
/// Stammdaten nichts zu tun hat, soll vom Lauf auch nichts merken.
///
/// Wörtlich dieselbe Attrappe wie in `test/data/stammdaten_aus_health_test.dart`
/// — eine geteilte Hilfsdatei wäre der kürzere Weg, aber beide Dateien sind
/// Testvorgaben, und eine gemeinsame Datei zu ändern änderte stillschweigend
/// auch die andere.
class _StilleQuelle extends HealthReadingAttrappe {}

/// Dieselbe Quelle, die zusätzlich Körpermerkmale liefert — und mitzählt,
/// wie oft sie danach gefragt wurde. Der Zähler ist der Beweis, dass der
/// Lauf überhaupt angelaufen ist (Vorbild: `_MitschnittReading` in
/// `test/health/freigabe_test.dart`).
class _Merkmalsquelle extends _StilleQuelle
    implements BodyCharacteristicsReading {
  _Merkmalsquelle(this.merkmale);

  final BodyCharacteristics merkmale;

  int anfragen = 0;

  @override
  Future<BodyCharacteristics> bodyCharacteristics() async {
    anfragen += 1;
    return merkmale;
  }
}
