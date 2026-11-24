import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/section_header.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

import '../design/support.dart' show textOf;
import 'support.dart';

/// Tests für `MehrView` (Task 11, `lib/shell/mehr_view.dart`), nach
/// `Sources/Features/Shell/MoreView.swift`.
///
/// Die beiden Pflichtfälle stehen im Task-Brief wörtlich vor:
///   1. „alle geplanten Menuepunkte sind sichtbar"
///   2. „nur der HealthKit-Test fuehrt irgendwohin"
/// Fall 2 war im Brief nur als leerer Testkörper mit Kommentar vorgegeben
/// ("Jede andere Zeile ist sichtbar, aber nicht druckbar — und sagt das,
/// statt stumm nichts zu tun.") — die konkreten Zusicherungen unten sind
/// meine Ausarbeitung davon. Dazu kommen acht weitere Fälle, die der
/// Task-Brief ausdrücklich zusätzlich verlangt (Gruppenreihenfolge,
/// Stapel-Hausregel, Umfänge-Untertitel) oder die aus `CLAUDE.md` folgen
/// (keine echten Gesundheits-/Trainingsdaten im Quelltext).
///
/// ## Festgelegte API, an die sich die Implementierung halten muss
///
/// - `class MehrView extends Widget` — `lib/shell/mehr_view.dart`, mit
///   `required AppRouter router` (direkt oder benannt `router:`). Die Zeilen
///   selbst werden ausschließlich über sichtbaren Text identifiziert (siehe
///   `alleTitel` unten), nicht über ein `MehrZiel`-Feld — welche Gestalt
///   `enum MehrZiel` genau annimmt (Fallnamen, Felder), ist dem
///   Implementierenden überlassen; Test 'MehrZiel hat für jede Zeile genau
///   einen Fall' bindet nur die **Anzahl** der Fälle an die Anzahl der
///   Menüpunkte.
/// - **Tippbarkeit** wird strukturell geprüft: Ein Vorfahre der Zeile ist
///   entweder ein `GestureDetector` mit gesetztem `onTap` (wie `IconRow` aus
///   Task 9 es für `onTap != null` baut) oder ein `CupertinoButton` mit
///   gesetztem `onPressed`. Nur für die Zeilen aus `aktiveTitel` darf das
///   zutreffen.
///   Reicht die Implementierung onTap stattdessen über ein anderes
///   Widget durch, bitte melden statt den Test umzuschreiben.
/// - **Abgeblendet** (Task-Brief Schritt 3: „Die übrigen sind sichtbar,
///   abgeblendet") heißt hier: ein `Opacity`-Vorfahre mit `opacity < 1.0`.
/// - **„Benennen, dass sie noch nicht da ist"** wird nicht an einen exakten
///   Wortlaut gebunden (CLAUDE.md verbietet Beschriftungsprüfungen bei
///   Widget-Tests, siehe unten) — geprüft wird nur, dass irgendwo im Baum
///   so oft ein Text auftaucht, wie es inaktive Zeilen gibt, und dass er
///   nach einem der Muster „noch nicht", „bald", „später" oder „folgt"
///   klingt (unabhängig davon, ob er Teil des Untertitels ist oder ein
///   eigenes Element).
///
/// ## Warum diese Fälle und nicht andere
///
/// - **Reihenfolge der Gruppen und Zeilen** ist Teil der Pflichtangabe in
///   Schritt 3 des Briefs ("wörtlich aus MoreView.swift:138–144") — ein
///   Test, der nur die Anwesenheit prüft, ließe eine vertauschte Reihenfolge
///   grün durchlaufen.
/// - **Stapel-Hausregel** (Task 10/CLAUDE.md: "Sprünge laufen über
///   `Router.open`... ein Detailziel schiebt auf den Stapel des Tabs, in
///   dem man gerade ist"): Der Brief verlangt ausdrücklich, das hier
///   nachzuprüfen, weil `AppTarget.detail(Tab, ...)` optisch fast wie
///   `AppTarget.aktuell(...)` aussieht, sich aber grundverschieden verhält
///   (Stapel *ersetzen* statt *schieben*, Tab *wechseln* statt *beibehalten*).
/// - **Keine echten Trainingsdaten aus der Swift-Vorlage**: `MoreView.swift`
///   trägt in seinen Untertiteln echte, personenbezogene Zahlen. Das ist bereits bestehender
///   (eingefrorener) Swift-Code, nicht Gegenstand dieses Tasks — aber
///   Schritt 3 des Briefs sagt wörtlich, Titel *und Untertitel* seien aus
///   `MoreView.swift:12-85` zu "übernehmen". Genau das wäre ein Verstoß
///   gegen `CLAUDE.md` ("Echte Gesundheitsdaten stehen nie im Quelltext...
///   auch nicht 'nur zum Ansehen'") in einer gerade erst entstehenden Datei.
///   Dieser Test ist eine bewusste Sicherung dagegen — siehe
///   `task-11-tests-report.md` für die vollständige Begründung und meine
///   Entscheidung, was stattdessen in den Untertiteln stehen sollte.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - Symbol und Akzentfarbe je Zeile (Pixel/Darstellung, nicht Zustand).
/// - Der genaue Wortlaut der informativen Untertitel (z. B. was bei
///   "Aktivitäten" oder "Coach" steht) — das wäre eine Beschriftungsprüfung
///   ohne Verhaltenswert; nur die Umfänge-Zeile bekommt einen gezielten
///   Negativtest gegen ein erfundenes Datum, weil CLAUDE.md das ausdrücklich
///   verbietet.
/// - Ob `MehrView` tatsächlich in `RootView`/`_tabSeite` für den Mehr-Tab
///   eingehängt ist — das tut laut Plan **kein** Task in M1 (weder Task 11
///   noch 12–15 erwähnen `root_view.dart`). `MehrView` wird hier isoliert
///   geprüft, wie `PlatzhalterTab` und `TabBadge` in Task 10. Siehe Bericht.
///
/// ## Nachtrag (task-navbar, 26.10.2026): die Zeile „Plan"
///
/// Die Tableiste verliert ihren Plan-Reiter (`docs/screens/components.js`
/// ab Zeile 158, Kommentarkopf: „Plan ist kein Reiter mehr... Die Plätze
/// waren voll"). `docs/screens/screens/mehr.js:6-10` hält fest, dass der
/// Plan seitdem **hier** liegt, als **erster** Eintrag — „von allen hier
/// ist er der, den man am häufigsten sucht". Das Board baut dafür die
/// ganze Gruppenstruktur um (neue Gruppen „Training"/„App", eine
/// konsolidierte „Einstellungen"-Zeile) — das ist eine eigene, größere
/// Aufgabe und **nicht** Teil von task-navbar (dessen Auftrag für die
/// übrigen drei Reiter wörtlich sagt: „bleiben wie sie sind"). Diese Datei
/// nagelt deshalb nur das Minimum fest, das der Auftrag verlangt (Punkt 4:
/// „Plan ist aus dem Mehr-Menü erreichbar und landet im Mehr-Stapel"): eine
/// neue, aktive Zeile „Plan" — oben in der bestehenden Gruppe „Festlegen",
/// vor „Ziele" (das „an erster Stelle, meistgesucht" aus dem Board
/// übernommen, ohne die vier etablierten Gruppennamen anzutasten). Die
/// größere Mehr-Menü-Neuordnung bleibt ein offener Punkt für einen
/// eigenen Task — siehe Bericht.
///
/// Damit führen jetzt **zwei** Zeilen irgendwohin, nicht mehr nur eine:
/// `aktiveTitel` ersetzt das bisherige `aktiverTitel`, und jeder Test, der
/// vorher nur gegen `aktiverTitel`/`inaktiveTitel` prüfte, läuft jetzt über
/// beide. `MehrZiel` bekommt dafür einen elften Fall; der Test
/// 'MehrZiel hat fuer jede Zeile genau einen Fall' bindet die Anzahl
/// weiterhin nur an `alleTitel.length`, prüft also automatisch mit.
///
/// ## Nachtrag (#115, 27.10.2026): die Zeile „Erholung"
///
/// Der Erholung-Schirm ist gebaut (`lib/shell/erholung_view.dart`), also
/// wird seine Zeile scharfgeschaltet: `'Erholung'` wandert von
/// `inaktiveTitel` nach `aktiveTitel`. **Das ist eine Änderung an einer
/// bestehenden Testdatei durch den Test-Agenten von #115, nicht durch den
/// Umsetzenden** — die bisherigen Erwartungen („abgeblendet", „nicht
/// tippbar", „sagt, dass sie noch nicht da ist") schrieben das Gegenteil
/// dessen fest, was #115 verlangt; sie stehen zu lassen hieße, den
/// Umsetzenden zwischen einem roten Test und einem unerledigten Ticket zu
/// wählen zu lassen. Die drei betroffenen Fälle sind damit **rote Tests von
/// #115** und werden grün, sobald `MehrZiel.erholung` `istAktiv: true`
/// bekommt und über `oeffneErholung(router)` schiebt. Dass die Zeile dabei
/// auch ihren „folgt in einer späteren Aufgabe"-Zusatz verliert, prüft der
/// Fall 'jede inaktive Zeile sagt sichtbar, dass sie noch nicht da ist'
/// automatisch mit: Er verlangt nur noch acht Ankündigungen.
///
/// Wohin die Zeile führt, prüft nicht diese Datei, sondern
/// `erholung_view_test.dart` (Gruppe „Die beiden Eingänge") — dort steht
/// auch der zweite Eingang, die Erholungskarte auf Heute.
///
/// ## Nachtrag (#82, 02.11.2026): die Zeile „Körper"
///
/// Denselben Weg geht jetzt `'Körper'`: #82 baut den Schirm
/// (`lib/shell/koerper_view.dart`), die Zeile ist damit keine Ankündigung
/// mehr und wandert von `inaktiveTitel` nach `aktiveTitel`. **Das ist eine
/// Änderung an einer bestehenden Testdatei durch den Test-Agenten von #82,
/// nicht durch den Umsetzenden** — aus demselben Grund wie oben: Die
/// bisherigen Erwartungen („abgeblendet", „nicht tippbar", „sagt, dass sie
/// noch nicht da ist") schreiben das Gegenteil dessen fest, was #82
/// verlangt, und sie stehen zu lassen hieße, den Umsetzenden zwischen
/// einem roten Test und einem unerledigten Ticket wählen zu lassen. Die
/// Entscheidung stammt vom Test-Agenten; Tim hat sie nicht gesehen.
///
/// **Rote Tests von #82** sind damit genau diese drei; sie werden grün,
/// sobald `MehrZiel.koerper` `istAktiv: true` bekommt und über
/// `oeffneKoerper(router)` auf `KoerperSeite` schiebt:
///
/// 1. 'nur die aktiven Zeilen fuehren irgendwohin' — „Körper" braucht
///    einen Tipp-Handler.
/// 2. 'die aktiven Zeilen haengen am Stapel des aktuellen Tabs, nicht an
///    einem fremden' — der Tipp muss einen Befehl liefern, und zwar über
///    `AppTarget.aktuell`.
/// 3. 'die inaktiven Zeilen sind abgeblendet, HealthKit-Test nicht' —
///    „Körper" darf nicht mehr abgeblendet sein.
///
/// Der Fall 'jede inaktive Zeile sagt sichtbar, dass sie noch nicht da
/// ist' ist **nicht** darunter: Er bindet die erwartete Anzahl an
/// `inaktiveTitel.length` und bleibt deshalb vor wie nach der Umsetzung
/// grün — vorher trägt „Körper" eine Ankündigung zu viel, nachher gar
/// keine mehr, und beides erfüllt die Untergrenze.
///
/// Mit „Körper" führen vier Zeilen irgendwohin, nicht mehr drei. Deshalb
/// sind in diesem Zug auch zwei Testnamen und die Kommentare mitgewandert,
/// die noch „nur Plan und HealthKit-Test" bzw. „die beiden Zeilen" sagten
/// — ein Name, der das Gegenteil dessen behauptet, was der Fall prüft,
/// ist schlimmer als gar keiner. Harte Zahlen in der Prosa („neun
/// inaktive Zeilen") sind dabei durch Verweise auf `inaktiveTitel`
/// ersetzt: Sie sind schon zweimal veraltet, während die Erwartung selbst
/// immer an der Liste hing.
///
/// Wohin die Zeile führt, prüft nicht diese Datei, sondern
/// `koerper_view_test.dart`.
///
/// ## Nachtrag (#307, 04.11.2026): die Zeile „Vorläufige Werte"
///
/// #307 bringt einen **zwölften** Menüpunkt mit: „Vorläufige Werte",
/// aktiv, in der Gruppe „Verwalten", hinter „HealthKit-Test". Anders als
/// bei #115 und #82 wandert hier nichts von `inaktiveTitel` nach
/// `aktiveTitel` — die Zeile ist neu und von Anfang an lebendig. Nachgezogen
/// sind deshalb nur `alleTitel` und `aktiveTitel`; jeder Fall, der über eine
/// der beiden Listen läuft (Sichtbarkeit, Reihenfolge, Tippbarkeit,
/// Stapel-Hausregel, Opazität), prüft den neuen Punkt damit automatisch mit.
/// **Das ist eine Änderung an einer bestehenden Testdatei durch den
/// Test-Agenten von #307, nicht durch den Umsetzenden** — aus demselben
/// Grund wie in den beiden Nachträgen oben.
///
/// Zahlen hart tragen nur zwei Stellen, und beide sind Prosa: der Name des
/// Zählfalls und der des Reihenfolgefalls. Beide sagen jetzt „zwölf"; der
/// Reihenfolgefall hinkte mit „zehn" sogar zwei Stufen hinterher, und seine
/// `reason:`-Liste nannte noch die Titel von vor task-navbar — beides ist
/// mitgezogen. Die Erwartungen selbst hängen an `alleTitel` und bleiben
/// unangetastet.
///
/// Der Datums-Scan und die Verbotsliste echter Swift-Werte laufen ebenfalls
/// über den neuen Untertitel; er trägt weder ein `dd.MM.yyyy`-Datum noch
/// einen der Werte aus `MoreView.swift`.
///
/// ## Nachtrag (#339, 04.11.2026): die Zeile „KI-Zugang"
///
/// #339 bringt einen **dreizehnten** Menüpunkt mit: „KI-Zugang", aktiv, in
/// der Gruppe „Verwalten", hinter „Vorläufige Werte" (Plan
/// `2026-11-04-ki-zugang.md`, Task 8 — dort als benannte Abweichung vom
/// Board, das den Eingang unter Einstellungen zeichnet). Wie bei #307 ist
/// die Zeile neu und von Anfang an lebendig; nachgezogen sind nur
/// `alleTitel` und `aktiveTitel`, dazu die Zahl in den Namen von Zähl- und
/// Reihenfolgefall und die `reason:`-Liste des Reihenfolgefalls. **Das ist
/// eine Änderung an einer bestehenden Testdatei durch den Test-Agenten von
/// #339, nicht durch den Umsetzenden.**
///
/// ## Nachtrag (#448 unter #404, 10.11.2026): die Zeile „Ziele"
///
/// Der erste Schnitt des Ziele-Schirms (Auszeiten) macht die Zeile „Ziele"
/// lebendig (Spec `2026-11-10-auszeit-design.md`, V18). Sie wandert von
/// `inaktiveTitel` nach `aktiveTitel`, wie „Erholung" (#115) und „Körper"
/// (#82). **Das ist eine Änderung an einer bestehenden Testdatei durch den
/// Test-Agenten von #448, nicht durch den Umsetzenden** — sonst stünde der
/// Umsetzende zwischen einem roten Test und einem unerledigten Ticket. Dass
/// diese Datei schon jetzt nachgezogen wird statt erst auf Meldung des
/// Umsetzenden (Plan, Global Constraints), ist eine Festlegung des
/// Test-Agenten, nicht von Tim freigegeben.
///
/// **Rote Tests von #448** sind damit dieselben drei wie bei #82: 'nur die
/// aktiven Zeilen fuehren irgendwohin', 'die aktiven Zeilen haengen am
/// Stapel des aktuellen Tabs, nicht an einem fremden' und 'die inaktiven
/// Zeilen sind abgeblendet, HealthKit-Test nicht'. Wohin die Zeile führt,
/// prüft `test/ziele/ziele_view_test.dart` (Gruppe „Mehr › Ziele (V18)").
///
/// ## Nachtrag (#477 unter #88, 11.11.2026): die Zeile „Umfänge messen"
///
/// Scheibe 2 der Umfänge baut den Schirm „Umfänge messen"
/// (`docs/superpowers/plans/2026-11-11-umfaenge.md`, Task 2.2 und 2.3).
/// Damit wandert `'Umfänge messen'` von `inaktiveTitel` nach `aktiveTitel`
/// — denselben Weg wie „Erholung" (#115), „Körper" (#82) und „Ziele"
/// (#448). **Das ist eine Änderung an einer bestehenden Testdatei durch den
/// Test-Agenten von #477, nicht durch den Umsetzenden**: Die bisherigen
/// Erwartungen („abgeblendet", „nicht tippbar", „sagt, dass sie noch nicht
/// da ist") schreiben das Gegenteil dessen fest, was #477 verlangt, und sie
/// stehen zu lassen hieße, den Umsetzenden zwischen einem roten Test und
/// einem unerledigten Ticket wählen zu lassen. Die Entscheidung stammt vom
/// Test-Agenten; Tim hat sie nicht gesehen.
///
/// **Rote Tests von #477** sind damit dieselben drei wie bei #82 und #448:
/// 'nur die aktiven Zeilen fuehren irgendwohin', 'die aktiven Zeilen
/// haengen am Stapel des aktuellen Tabs, nicht an einem fremden' und 'die
/// inaktiven Zeilen sind abgeblendet, HealthKit-Test nicht'. Wohin die
/// Zeile führt, prüft `test/shell/umfaenge_tueren_test.dart` (Gruppe
/// „Mehr › Umfänge messen").
///
/// Der Fall 'die Umfaenge-Zeile nennt kein erfundenes Datum' bleibt
/// unverändert gültig und wird dadurch **wichtiger**: Ab jetzt steht
/// hinter der Zeile echte Datenlage, und ein gerechneter Untertitel wäre
/// genau das, was `CLAUDE.md` verbietet. Die Zahl der Maße in dieser Zeile
/// zu nennen, bliebe ebenfalls falsch — `verboteneSwiftWerte` führt „13
/// Maße" weiter auf, und fünfzehn wären dieselbe Art Zahl.
///
/// ## Nachtrag (#95 mit #16, 24.11.2026): die Zeile „Ausdauer"
///
/// Der Ausdauer-Schirm macht die Zeile „Ausdauer" lebendig
/// (`test/shell/ausdauer_view_test.dart`, dort steht die festgelegte API).
/// Sie wandert von `inaktiveTitel` nach `aktiveTitel` — denselben Weg wie
/// „Erholung" (#115), „Körper" (#82), „Ziele" (#448) und „Umfänge messen"
/// (#477), und aus demselben Grund: Die bisherigen Erwartungen
/// („abgeblendet", „nicht tippbar", „sagt, dass sie noch nicht da ist")
/// schreiben das Gegenteil dessen fest, was #95 verlangt. Rein
/// mechanischer Nachzug (TEST_AENDERN=1), kein Erwartungswert darüber
/// hinaus verschoben. Tim hat das Verschieben am 24.11.2026 ausdrücklich
/// freigegeben, ohne die Datei selbst zu sehen. Wohin die Zeile führt,
/// prüft `ausdauer_view_test.dart`.
///
/// **Rote Tests von #95** sind damit dieselben drei wie bei #82, #448 und
/// #477: 'nur die aktiven Zeilen fuehren irgendwohin', 'die aktiven
/// Zeilen haengen am Stapel des aktuellen Tabs, nicht an einem fremden'
/// und 'die inaktiven Zeilen sind abgeblendet, HealthKit-Test nicht'.
void main() {
  const alleTitel = [
    'Plan',
    'Ziele',
    'Aktivitäten',
    'Umfänge messen',
    'Körper',
    'Erholung',
    'Ausdauer',
    'Coach',
    'Daten & Einstellungen',
    'Daten übernehmen',
    'HealthKit-Test',
    'Vorläufige Werte',
    'KI-Zugang',
  ];

  // Die Zeilen, die irgendwohin führen — siehe Nachtrag oben und die
  // Nachträge #115, #82, #307, #339, #448 und #477 oben. Reihenfolge hier
  // ist ohne Bedeutung (nur `alleTitel` legt die Bildschirmreihenfolge
  // fest), sie folgt der von `alleTitel`.
  const aktiveTitel = [
    'Plan',
    'Ziele',
    'Umfänge messen',
    'Körper',
    'Erholung',
    'Ausdauer',
    'HealthKit-Test',
    'Vorläufige Werte',
    'KI-Zugang',
    // Seit #59 führt „Daten übernehmen" auf den Übernahme-Schirm und
    // liest Gym-Trainings aus einer Exportdatei der alten App ein.
    // (11.11.2026, TEST_AENDERN=1)
    'Daten übernehmen',
  ];

  const inaktiveTitel = [
    'Aktivitäten',
    'Coach',
    'Daten & Einstellungen',
  ];

  // „Über" kam mit #38 dazu (Quellenangabe zu den Bewegungsbildern) und ist
  // mit #606 wieder entfallen — Tims Entscheidung vom 24.11.2026; die Angabe
  // steht seitdem nur an den Bildern selbst. Nachgezogen mit TEST_AENDERN=1.
  const gruppenReihenfolge = [
    'Festlegen',
    'Erfassen',
    'Auswerten',
    'Verwalten',
  ];

  // Format.tag liefert "dd.MM.yyyy" (formatierung.dart) — das Muster eines
  // echten, aus einem Stand berechneten Datums. In M1 gibt es für die
  // Umfänge-Zeile keine Datenquelle, aus der ein echtes Datum kommen
  // könnte (siehe Klassenkommentar), also darf so etwas nirgends auftauchen.
  final datumsMuster = RegExp(r'\b\d{2}\.\d{2}\.\d{4}\b');

  // Wörtliche Zahlen/Phrasen aus MoreView.swift:12-85 — echte
  // Trainingsdaten aus Tims Swift-App, siehe Klassenkommentar.
  const verboteneSwiftWerte = [
    '76,0 kg',
    '39,2',
    '2:07 h',
    '3 Wettkämpfe',
    '5 im Oktober',
    '3 Hinweise',
    '13 Maße',
  ];

  final ankuendigungsMuster = RegExp(
    r'noch nicht|bald|später|folgt',
    caseSensitive: false,
  );

  /// Vergrößert die Testfläche, damit alle zehn Zeilen plus vier
  /// Gruppenköpfe gleichzeitig aufgebaut sind. Ohne das müsste jeder Test
  /// selbst scrollen — und bei einer lazy aufbauenden Liste (etwa
  /// `ListView.builder`) würden Zeilen außerhalb des sichtbaren Viewports
  /// gar nicht erst existieren, egal wie oft man `find.text(...)` aufruft.
  Future<void> pumpMehrView(
    WidgetTester tester, {
    required AppRouter router,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(huelle(MehrView(router: router)));
    await tester.pumpAndSettle();
  }

  /// `true`, wenn irgendein Vorfahre von [titelFinder] ein `GestureDetector`
  /// mit gesetztem `onTap` oder ein `CupertinoButton` mit gesetztem
  /// `onPressed` ist — die beiden Wege, über die diese rein-Cupertino-App
  /// (kein `material.dart`) eine Zeile tippbar machen kann. `IconRow` aus
  /// Task 9 baut bei `onTap != null` genau einen solchen `GestureDetector`
  /// und lässt ihn bei `onTap == null` ganz weg (siehe `icon_row.dart`).
  bool hatTippbarenVorfahren(WidgetTester tester, Finder titelFinder) {
    final vorfahren = tester.widgetList(
      find.ancestor(
        of: titelFinder,
        matching: find.byWidgetPredicate((_) => true),
      ),
    );
    for (final vorfahre in vorfahren) {
      if (vorfahre is GestureDetector && vorfahre.onTap != null) return true;
      if (vorfahre is CupertinoButton && vorfahre.onPressed != null)
        return true;
    }
    return false;
  }

  /// Produkt aller `Opacity.opacity`-Werte auf dem Weg von der Wurzel bis zu
  /// [titelFinder] — `1.0`, wenn kein `Opacity`-Vorfahre existiert.
  double opazitaetVon(WidgetTester tester, Finder titelFinder) {
    final opacities = tester.widgetList<Opacity>(
      find.ancestor(of: titelFinder, matching: find.byType(Opacity)),
    );
    if (opacities.isEmpty) return 1.0;
    return opacities.map((o) => o.opacity).reduce((a, b) => a * b);
  }

  testWidgets('alle geplanten Menuepunkte sind sichtbar', (tester) async {
    await pumpMehrView(tester, router: AppRouter());

    for (final titel in alleTitel) {
      expect(
        find.text(titel),
        findsOneWidget,
        reason: '"$titel" fehlt im Mehr-Menü.',
      );
    }
  });

  testWidgets('nur die aktiven Zeilen fuehren irgendwohin', (tester) async {
    final router = AppRouter();
    await pumpMehrView(tester, router: router);

    // Die uebrigen Zeilen (`inaktiveTitel`): sichtbar (siehe voriger Test),
    // aber nicht tippbar, und ein Tipp darauf loest nichts aus — stummes
    // Nichtstun waere genau der Fehler, den pruefen.mjs fuer die
    // Web-Entwuerfe eigens sucht ("Zeilen, die drueckbar aussehen und
    // nirgendwohin fuehren").
    for (final titel in inaktiveTitel) {
      final finder = find.text(titel);
      expect(
        hatTippbarenVorfahren(tester, finder),
        isFalse,
        reason:
            '"$titel" darf keinen Tipp-Handler haben — nur die Zeilen aus '
            'aktiveTitel fuehren irgendwohin.',
      );

      await tester.tap(finder, warnIfMissed: false);
      await tester.pump();

      expect(
        router.nimmBefehl(),
        isNull,
        reason: 'Ein Tipp auf "$titel" darf keine Navigation ausloesen.',
      );
      expect(tester.takeException(), isNull);
    }

    // `aktiveTitel`: die Zeilen, die tatsaechlich irgendwohin fuehren
    // (task-navbar brachte Plan, #115 die Erholung, #82 den Koerper — siehe
    // die Nachtraege im Klassenkommentar).
    for (final titel in aktiveTitel) {
      expect(
        hatTippbarenVorfahren(tester, find.text(titel)),
        isTrue,
        reason:
            '"$titel" muss tippbar sein — einer der lebendigen Punkte in M1.',
      );

      await tester.tap(find.text(titel));
      await tester.pumpAndSettle();

      expect(
        router.nimmBefehl(),
        isNotNull,
        reason:
            'Ein Tipp auf "$titel" muss router.open(...) aufrufen — sonst '
            'fuehrt es, entgegen dem Testnamen, auch nirgendwohin.',
      );
    }
  });

  testWidgets('die vier Gruppen stehen in der vorgeschriebenen Reihenfolge', (
    tester,
  ) async {
    // MoreView.swift:138-144: Festlegen, Erfassen, Auswerten, Verwalten —
    // wörtlich und in dieser Reihenfolge, laut Task-Brief Schritt 3.
    await pumpMehrView(tester, router: AppRouter());

    final koepfe = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .map((kopf) => kopf.title)
        .toList();

    expect(
      koepfe,
      gruppenReihenfolge,
      reason:
          'Reihenfolge/Beschriftung der Gruppen weicht ab — '
          'MoreView.swift:138-144; „Über" ist mit #606 entfallen.',
    );
  });

  testWidgets(
    'die dreizehn Zeilen stehen von oben nach unten in der vorgeschriebenen Reihenfolge',
    (tester) async {
      // Prüft die Reihenfolge über die Bildschirmposition statt über eine
      // Annahme zur Baumstruktur — bleibt so unabhängig davon, ob die
      // Implementierung eine Liste pro Gruppe oder eine einzige flache
      // Liste mit eingestreuten Köpfen baut.
      await pumpMehrView(tester, router: AppRouter());

      final positionen = alleTitel
          .map((titel) => tester.getTopLeft(find.text(titel)).dy)
          .toList();
      final sortiert = [...positionen]..sort();

      expect(
        positionen,
        sortiert,
        reason:
            'Die Zeilen muessen von oben nach unten in der Reihenfolge '
            'Plan, Ziele, Aktivitaeten, Umfaenge messen, Koerper, Erholung, '
            'Ausdauer, Coach, Daten & Einstellungen, Daten uebernehmen, '
            'HealthKit-Test, Vorlaeufige Werte, KI-Zugang stehen — '
            'MoreView.swift:138-144, erweitert um Plan (task-navbar, oben), '
            'Vorlaeufige Werte (#307) und KI-Zugang (#339, beide unten in '
            'Verwalten).',
      );
    },
  );

  testWidgets(
    'die aktiven Zeilen haengen am Stapel des aktuellen Tabs, nicht an '
    'einem fremden',
    (tester) async {
      // Hausregel aus CLAUDE.md/Task 10: Ein Menüpunkt, der irgendwo im Menü
      // unter einem bestimmten Tab einsortiert ist, schiebt trotzdem auf den
      // AKTUELLEN Stapel (AppTarget.aktuell) statt den Tab zu wechseln oder
      // dessen Stapel zu ersetzen (AppTarget.detail) — sonst führte „zurück"
      // in ein Menü, das der Nutzer nie geöffnet hat. In der echten App ist
      // der aktuelle Tab beim Anzeigen von MehrView immer „Mehr" selbst.
      // Gilt seit task-navbar für JEDE lebendige Zeile, nicht nur
      // HealthKit-Test — die übrigen bekämen sonst denselben Fehler, den
      // diese Hausregel gerade verhindern soll (ein Tab-Fall
      // `AppTarget.gym()`-artig wechselt den Tab, das wäre hier falsch).
      for (final titel in aktiveTitel) {
        final router = AppRouter();
        final tabVorher = router.tab;
        await pumpMehrView(tester, router: router);

        await tester.tap(find.text(titel));
        await tester.pumpAndSettle();

        expect(
          router.tab,
          tabVorher,
          reason: 'Ein Tipp auf "$titel" wechselt nie den Tab — auch '
              '"Mehr" selbst nicht.',
        );

        final befehl = router.nimmBefehl();
        expect(befehl, isNotNull, reason: titel);
        expect(
          befehl!.ersetztStapel,
          isFalse,
          reason:
              '"$titel": Es wird auf den Stapel GESCHOBEN '
              '(AppTarget.aktuell), nicht der ganze Stapel ersetzt '
              '(AppTarget.detail wäre der Fehler aus der Hausregel).',
        );
        expect(
          befehl.tab,
          router.tab,
          reason:
              '"$titel": Der Befehl zielt auf den aktuell gewählten Tab — '
              'in der echten App der Mehr-Tab — nicht fest auf einen '
              'anderen.',
        );
      }
    },
  );

  testWidgets('die inaktiven Zeilen sind abgeblendet, HealthKit-Test nicht', (
    tester,
  ) async {
    // Task-Brief Schritt 3, wörtlich: "Die übrigen sind sichtbar,
    // abgeblendet und benennen, dass sie noch nicht da sind."
    await pumpMehrView(tester, router: AppRouter());

    for (final titel in inaktiveTitel) {
      expect(
        opazitaetVon(tester, find.text(titel)),
        lessThan(1.0),
        reason: '"$titel" muss abgeblendet sein.',
      );
    }

    for (final titel in aktiveTitel) {
      expect(
        opazitaetVon(tester, find.text(titel)),
        1.0,
        reason: '"$titel" ist eine der funktionierenden Zeilen und darf '
            'nicht wie die inaktiven abgeblendet wirken.',
      );
    }
  });

  testWidgets('jede inaktive Zeile sagt sichtbar, dass sie noch nicht da ist', (
    tester,
  ) async {
    // "Benennen" ist hier bewusst nicht an einen exakten Wortlaut gebunden
    // (CLAUDE.md verbietet Beschriftungsprüfungen bei Widget-Tests) —
    // geprüft wird nur, dass mindestens so viele von den Zeilentiteln/
    // Gruppenköpfen verschiedene Texte im Baum existieren wie es inaktive
    // Zeilen gibt, und dass sie nach einer Ankündigung klingen ("noch
    // nicht", "bald", "später", "folgt").
    await pumpMehrView(tester, router: AppRouter());

    final bekannteBeschriftungen = {...alleTitel, ...gruppenReihenfolge};

    final treffer = tester
        .widgetList<Text>(find.byType(Text))
        .map(textOf)
        .where((text) => !bekannteBeschriftungen.contains(text))
        .where(ankuendigungsMuster.hasMatch)
        .toSet();

    expect(
      treffer.length,
      greaterThanOrEqualTo(inaktiveTitel.length),
      reason:
          'Jede der inaktiven Zeilen muss sichtbar sagen, dass sie '
          'noch nicht da ist — stummes Abblenden allein reicht nicht '
          '(Task-Brief Schritt 3; dieselbe Fehlerklasse, die '
          'docs/screens/pruefen.mjs für die Web-Entwürfe prüft).',
    );
  });

  testWidgets(
    'keine echten Trainingsdaten aus der Swift-Vorlage im Quelltext',
    (tester) async {
      // Siehe Klassenkommentar: MoreView.swift:12-85 trägt echte,
      // personenbezogene Zahlen aus Tims laufendem Training in seinen
      // Untertiteln. CLAUDE.md verbietet das im Quelltext ausdrücklich,
      // auch "nur zum Ansehen".
      await pumpMehrView(tester, router: AppRouter());

      for (final wert in verboteneSwiftWerte) {
        expect(
          find.textContaining(wert),
          findsNothing,
          reason:
              '"$wert" ist eine echte Zahl/Angabe aus Tims Swift-App '
              '(MoreView.swift) — CLAUDE.md verbietet echte Gesundheits-/'
              'Trainingsdaten im Quelltext, auch als Platzhalter.',
        );
      }
    },
  );

  testWidgets('die Umfaenge-Zeile nennt kein erfundenes Datum', (tester) async {
    // In M1 gibt es noch keine Körper-Datenquelle, aus der ein echtes
    // "zuletzt am ..." für die Umfänge-Zeile kommen könnte (anders als in
    // der Swift-App, wo `bodyStore.latestCircumferences` echte Werte
    // liefert). Ein erfundenes Datum wäre falsch — siehe Bericht für die
    // vollständige Begründung und den Vorschlag für den Untertitel.
    await pumpMehrView(tester, router: AppRouter());

    final texte = tester.widgetList<Text>(find.byType(Text)).map(textOf);
    for (final text in texte) {
      expect(
        datumsMuster.hasMatch(text),
        isFalse,
        reason:
            'Text "$text" enthält ein Datum im Format dd.MM.yyyy — in '
            'M1 kann das nur erfunden sein.',
      );
    }
  });

  testWidgets(
    'zeigt keinen Export-Punkt — die Flutter-App exportiert nichts, nur die Swift-App',
    (tester) async {
      // MoreView.swift:146 listet zusätzlich ".export" ("Daten
      // exportieren") unter Verwalten (seit Task 1). Diese Flutter-App
      // importiert ausschließlich (siehe "Daten übernehmen" oben); ein
      // Export-Punkt hätte hier keine Gegenstelle. Siehe Bericht für die
      // Begründung dieser Entscheidung.
      await pumpMehrView(tester, router: AppRouter());

      expect(find.text('Daten exportieren'), findsNothing);
    },
  );

  testWidgets(
    'MehrView bringt weder eigenen Navigator noch eigene Tab-Leiste mit',
    (tester) async {
      // Hausregel aus CLAUDE.md: Ein Schirm bringt seinen Navigationsrahmen
      // nicht selbst mit — den stellt der Gastgeber (hier: RootView, später,
      // siehe Bericht). `huelle()` liefert über `CupertinoApp` bereits genau
      // einen Navigator; ein zweiter aus MehrView selbst wäre der Fehler.
      await pumpMehrView(tester, router: AppRouter());

      expect(find.byType(Navigator), findsOneWidget);
      expect(find.byType(CupertinoTabScaffold), findsNothing);
    },
  );

  test('MehrZiel hat fuer jede der dreizehn Zeilen genau einen Fall', () {
    expect(MehrZiel.values.length, alleTitel.length);
  });

  testWidgets('baut ohne Ausnahme und ohne ErrorWidget', (tester) async {
    await pumpMehrView(tester, router: AppRouter());

    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
