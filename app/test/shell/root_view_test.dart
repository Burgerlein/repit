import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/platzhalter_tab.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

import '../ernaehrung/kamera_attrappe.dart';

/// Tests für das Tab-Gerüst nach dem Umbau der Tableiste (task-navbar,
/// 26.10.2026) — Nachfolger der Task-10-Fassung dieser Datei.
///
/// ## Warum diese Datei neu geschrieben wird, nicht nur ergänzt
///
/// Tim hat die Tableiste neu entworfen (Board-Commits `e02b765`, `a9cfcc3`,
/// `3b087f4`): **Home · Ernährung · (+) · Gym · Mehr** statt **Heute · Plan ·
/// Gym · Ernährung · Mehr**. Das ist keine kosmetische Änderung an einer
/// bestehenden Struktur, sondern eine andere Zahl von Tabs (vier statt fünf),
/// ein entfallener Tab (Plan), ein neues Element, das kein Tab ist (der
/// (+)), und eine neue Bedingung für eine Farbe (Gym bei laufender
/// Erfassung) statt eines Abzeichens. Die alte Datei an jeder dieser Stellen
/// zu flicken wäre unübersichtlicher als neu zu beginnen — und `CLAUDE.md`
/// erlaubt dem Test-Agenten ausdrücklich, Dateien anzupassen, die durch den
/// Umbau erwartbar rot werden (hier: diese Datei und `main_test.dart`).
///
/// Verbindliche Quelle: `docs/screens/components.js` ab Zeile 158 (`TABS`,
/// `TAB_SCREEN`, `tabbar()`, `tabMenu()`, samt Kommentarköpfen) und
/// `docs/screens/components.css` ab Zeile 77 für die Maße (hier nicht
/// geprüft — CLAUDE.md: Widget-Tests prüfen Zustände und Übergänge, keine
/// Pixelmaße). Ein Beispiel mit aufgefahrenem Bogen:
/// `docs/screens/screens/ernaehrung.js:160`.
///
/// ## Festgelegte API, an die sich die Implementierung halten muss
///
/// - **`enum Tab` schrumpft auf vier Werte**, in dieser Reihenfolge:
///   `{ heute, ernaehrung, gym, mehr }` — `lib/shell/router.dart`. Kein
///   `Tab.plan` mehr. Der Name `Tab.heute` bleibt unverändert (siehe
///   Begründung unten, Abschnitt „Warum `Tab.heute` nicht zu `Tab.home`
///   wird"), auch wenn das sichtbare Label auf dem Board „Home" heißt.
/// - **`AppTarget.plan()` entfällt ersatzlos** (`lib/shell/ziele.dart`) —
///   es gibt keinen Plan-Tab mehr, zu dem es wechseln könnte. Wer den
///   Plan-Schirm erreichen will, tut das über `MehrView` mit
///   `AppTarget.aktuell(...)`, genau wie bisher „HealthKit-Test" (siehe
///   `mehr_view_test.dart`, Nachtrag „die Zeile Plan"). Die übrigen vier
///   Fabrikmethoden (`.heute()`, `.ernaehrung()`, `.gym()`, `.mehr()`) und
///   `.aktuell(...)`/`.detail(...)` bleiben unverändert.
/// - **`class RootView`** bekommt einen dritten, optionalen Konstruktor-
///   Parameter: `const RootView({super.key, AppRouter? router,
///   bool erfassungLaeuft = false})`. Siehe Abschnitt „Gym färbt sich" unten
///   für die Begründung von Name und Default.
/// - **`class ErfassenKnopf`** und **`class BogenEintrag`** —
///   `lib/shell/root_view.dart`, der (+)/(×)-Knopf samt Bogenmenü. Isoliert
///   spezifiziert in `erfassen_knopf_test.dart`; diese Datei prüft nur, dass
///   `RootView` ihn tatsächlich auf jedem Tab-Stapel zeigt und mit den drei
///   M1-Einträgen aus dem Board verdrahtet (`Suchen`, `Barcode`, `Foto`) —
///   in M1 alle `verfuegbar: false` und ein Tipp wie die Glocke. **Seit
///   #285 ist `Suchen` verfügbar und ein Tipp öffnet die Suche**; `Barcode`
///   und `Foto` bleiben `verfuegbar: false` (Nachtrag unten).
/// - **Tab-Symbole** (`Symbole.tabelle`, alle schon vorhanden, keine neuen
///   Einträge nötig): Home → `'target'`, Ernährung → `'fork.knife'`,
///   Gym → `'dumbbell'`, Mehr → `'ellipsis'` — wörtlich `TABS` in
///   `components.js:174-177`. **Home benutzt also nicht mehr `'calendar'`.**
/// - **`Key('erfassen-knopf')`** auf dem (+)/(×)-Knopf selbst (für
///   `find.byKey(...)` unabhängig vom aktuellen Dreh-/Beschriftungszustand).
/// - **`Key('gym-live')`** markiert den Gym-Tab-Eintrag in der `CupertinoTabBar`
///   genau dann, wenn `erfassungLaeuft == true` — sonst nirgends im Baum.
///
/// ## Warum `Tab.heute` nicht zu `Tab.home` wird
///
/// Das sichtbare Label des ersten Reiters heißt auf dem Board „Home" (ein
/// im Deutschen gängiges Lehnwort, siehe `TABS[0]`), aber der interne Name
/// ist keine Oberflächenbeschriftung (CLAUDE.md: „Deutsch in der Oberfläche,
/// Englisch im Code" gilt für Beschriftungen, nicht für jeden Bezeichner).
/// `Tab.heute`, `AppTarget.heute()` und `HeuteView` umzubenennen hieße,
/// zehn Tasks Code anzufassen, ohne dass sich am Verhalten etwas ändert —
/// dieselbe Abwägung, die Task 10 schon einmal getroffen hat (siehe
/// `progress.md`, Task 10: „Die REGEL wird präzisiert, nicht der Bestand
/// umbenannt"). Diese Datei bindet den ersten Tab deshalb weiterhin über
/// `Tab.heute`, identifiziert ihn in der Oberfläche aber über sein neues
/// Symbol (`'target'`), nicht über ein Label — wie schon vorher wird hier
/// nie Beschriftungstext zur Testidentität (CLAUDE.md).
///
/// ## Gym färbt sich nur bei laufender Erfassung — die Naht für später
///
/// Punkt 7 des Auftrags verlangt, die Stelle „so fest zu nageln, dass ein
/// späterer Task nur den Wert setzen muss" — aber **ohne** einen
/// Trainingszustand zu erfinden, den es in M1 nicht gibt. Die ehrliche
/// Antwort: `RootView` bekommt einen Parameter (`erfassungLaeuft`), und
/// M1 setzt ihn nirgends auf `true` — weder `main.dart` noch sonst ein
/// Aufrufer. Das wird unten dreifach geprüft: ohne den Parameter, mit
/// `erfassungLaeuft: false` ausdrücklich, und mit `erfassungLaeuft: true`
/// (wofür sich etwas sichtbar ändern **muss**, sonst wäre der Parameter nur
/// Attrappe). Bewusst **keine Farbwerte geprüft** (CLAUDE.md verbietet das
/// für Widget-Tests ausdrücklich) — stattdessen ein struktureller Marker
/// (`Key('gym-live')`), der nur dann im Baum steht. Das ist dieselbe
/// Prüfidee wie bei `TabBadge` (`Key('tab-badge')` da/nicht da, nie die
/// Farbe selbst), nur ohne eigenen Baustein, weil hier kein Abzeichen
/// entsteht — nur eine Markierung am bestehenden Tab-Eintrag.
///
/// ## Was mit `TabBadge` passiert — Entscheidung, nicht gelöscht
///
/// Der Auftrag erlaubt, `tab_badge_test.dart` zu löschen, wenn der Entwurf
/// das Abzeichen „wirklich fallen lässt und nicht nur verschiebt". Prüfung
/// am Board (nicht am Gefühl): `tabbar()` in `components.js` verliert sein
/// Abzeichen tatsächlich (Kommentar dort: „Ein Abzeichen daneben verschob
/// das Symbol gegen die anderen vier... Die zweite Runde liegt..." — nein,
/// wörtlich: „Ein Abzeichen neben dem Symbol verschob es sichtbar gegen die
/// anderen vier, und dafür sagte es nichts, was die Farbe nicht auch
/// sagt."). **Aber** `navbar()` — eine andere Funktion, für die
/// Navigationsleiste, nicht die Tableiste — trägt weiterhin ein
/// `hints`-Abzeichen auf der Glocke (`components.js`, `navbar()`:
/// `(hints ? '<span class="badge">' + hints + '</span>' : '')`), unverändert
/// gegenüber vorher. Das heutige `root_view.dart` benutzt `TabBadge` bereits
/// **nur** für zwei Stellen: die fünf (künftig vier) Tab-Symbole (dort nie
/// mit einem Wert — M1 kennt keinen Badge-Inhalt) und die Glocke (ebenfalls
/// nie mit einem Wert). Die erste Stelle fällt mit diesem Umbau weg (eigene
/// Icons/der Live-Marker ersetzen sie), die zweite — die Glocke — bleibt
/// strukturell bestehen und bleibt ein plausibler künftiger Ort für das
/// `hints`-Abzeichen aus `navbar()`. **Entscheidung: `TabBadge` und
/// `tab_badge_test.dart` bleiben.** Das Abzeichen ist nicht „ersatzlos weg",
/// sondern auf die eine Stelle beschränkt, die es im Board immer noch gibt.
/// Diese Datei prüft deshalb zusätzlich (Regressionstest unten), dass kein
/// Tab-Symbol mehr einen `Key('tab-badge')` trägt — die alte Verwendung ist
/// weg —, während die Glocke unverändert bleibt.
///
/// ## Nachtrag (#282, 04.11.2026): Ernährung ist kein Platzhalter mehr
///
/// Seit `dea8016` zeigt der Ernährungs-Reiter `ErnaehrungView`. Der Fall
/// 'Ernaehrung und Gym zeigen weiterhin einen ehrlichen Platzhalter' lief
/// über beide Reiter und verlangte je einen `PlatzhalterTab`; er heißt
/// jetzt 'Gym zeigt weiterhin einen ehrlichen Platzhalter' und deckt nur
/// noch Gym ab. **Das war keine falsche Erwartung, sondern eine Zusage,
/// die eingelöst ist** — für Gym steht sie unverändert weiter. Ein
/// Ersatzfall für Ernährung entsteht hier bewusst nicht: Was der Schirm
/// zeigt, prüft `test/ernaehrung/ernaehrung_view_test.dart`; diese Datei
/// prüft das Tab-Gerüst. Dass der Reiter `ErnaehrungView` baut und dabei
/// nicht wirft, decken die Fälle über alle vier Reiter weiterhin ab
/// (Glocke, Erfassen-Knopf, „baut ohne Ausnahme").
///
/// Mitgezogen: die Testhülle, siehe Begründung bei `huelle(...)`.
///
/// **Geändert vom Test-Agenten von #282, nicht vom Implementierenden.
/// Tim hat diese Änderung nicht gesehen und nicht freigegeben** — sie
/// zieht nach, was die Implementierung wahr gemacht hat, und entscheidet
/// nichts. Dieselbe Form wie die Nachträge in `mehr_view_test.dart`
/// (#115, #82, #307).
///
/// ## Nachtrag (#285, 04.11.2026): Der (+) öffnet die Suche
///
/// Seit der Eintragweg verdrahtet ist (#285, #300), öffnet ein Tipp auf
/// den (+) die Suche, und im Bogen ist „Suchen" verfügbar. Barcode und
/// Foto bleiben ausgegraut — sie warten auf #284 und #287. Zwei Fälle
/// verlangten das M1-Verhalten:
///
/// - 'Tippen auf den Erfassen-Knopf sagt wie die Glocke, dass es das noch
///   nicht gibt' erwartete einen `CupertinoAlertDialog`. Er heißt jetzt
///   'Tippen auf den Erfassen-Knopf oeffnet die Suche' und prüft den
///   Übergang: `SucheView` steht da, kein Dialog.
/// - 'alle drei Bogeneintraege sind in M1 ausgegraut und tun nichts —
///   keiner verschwindet' tippte auch „Suchen" an. Er heißt jetzt
///   'Barcode und Foto sind ausgegraut und tun nichts — keiner
///   verschwindet' und läuft nur noch über diese beiden. Neu darin:
///   Nach dem Tipp steht keine `SucheView` da. `router.nimmBefehl()`
///   allein bewiese das nicht mehr, seit es einen Weg in die Suche gibt.
///
/// **Das waren keine falschen Erwartungen, sondern Zusagen, die eingelöst
/// sind** — dieselbe Lage wie im Nachtrag davor. Ein Ersatzfall für den
/// ganzen Eintragweg entsteht hier bewusst nicht: Dass „Suchen" im Bogen
/// in die Suche führt, dass der (+) im Tab bleibt und „zurück" dorthin
/// führt, prüft `test/ernaehrung/eintragweg_verdrahtung_test.dart`.
///
/// **Geändert vom Test-Agenten, nicht vom Implementierenden. Tim hat
/// diese Änderung nicht gesehen und nicht freigegeben** — sie zieht nach,
/// was die Implementierung wahr gemacht hat, und entscheidet nichts.
///
/// ## Nachtrag (#324, 04.11.2026): Der (+) öffnet die Kamera
///
/// Mit Barcode scannen (#324) öffnet ein Tipp auf den (+) die Kamera, wie
/// der Entwurf es seit dem 03.11. zeichnet (`erfassen.js`, Kopfkommentar);
/// die Suche liegt dort oben rechts unter „Suchen". Und der Bogeneintrag
/// „Barcode" ist freigeschaltet — **entschieden vom Koordinator am
/// 04.11.2026, nicht von Tim**. Foto bleibt ausgegraut (#287).
///
/// - 'Tippen auf den Erfassen-Knopf oeffnet die Suche' heißt jetzt
///   'Tippen auf den Erfassen-Knopf oeffnet die Kamera' und prüft
///   `Key('kamera')` statt `SucheView` — und dass die Suche **nicht** direkt
///   aufgeht.
/// - 'Barcode und Foto sind ausgegraut und tun nichts — keiner
///   verschwindet' heißt jetzt 'Foto ist ausgegraut und tut nichts —
///   verschwindet nicht' und läuft nur noch über Foto. Neu darin: Nach dem
///   Tipp steht auch keine Kamera da.
/// - Neu: 'der Bogeneintrag Barcode oeffnet die Kamera'.
/// - **Die Hülle setzt `TestLeser` über `strichcodeLeserProvider` ein**
///   (`test/ernaehrung/kamera_attrappe.dart`). Ohne sie baute der
///   Vorgabewert ein echtes `MobileScanner`, und jeder Fall nach dem (+)
///   scheiterte am fehlenden Plugin statt an seinem Gegenstand.
///
/// Was die Kamera selbst tut, prüft `test/ernaehrung/barcode_kamera_test
/// .dart`; diese Datei prüft das Tab-Gerüst.
///
/// **Geändert vom Test-Agenten von #324, nicht vom Implementierenden. Tim
/// hat diese Änderung nicht gesehen und nicht freigegeben.**
void main() {
  /// Icon je Tab, aus `Symbole.tabelle` — jetzt `TABS` in
  /// `components.js:174-177`, nicht mehr `RootView.swift:29-40` (dessen
  /// Satz von fünf Tabs mit dem Board-Umbau vom 26.10. überholt ist).
  const homeSymbol = 'target';
  const ernaehrungSymbol = 'fork.knife';
  const gymSymbol = 'dumbbell';
  const mehrSymbol = 'ellipsis';

  Finder tabBarIcon(String symbol) => find.descendant(
    of: find.byType(CupertinoTabBar),
    matching: find.byIcon(Symbole.aufloesen(symbol)),
  );

  Future<void> tippeTab(WidgetTester tester, String symbol) async {
    await tester.tap(tabBarIcon(symbol));
    await tester.pumpAndSettle();
  }

  /// Testhuelle für `RootView`: Anders als die generische `huelle(...)` aus
  /// `shell/support.dart` (die kein `ProviderScope` mitbringt) **braucht**
  /// jeder Aufbau hier einen, weil der Home-Tab seit diesem Umbau sofort
  /// `HeuteView` baut — eine `ConsumerWidget`, die `dailyMetricsProvider`
  /// liest (`ref.watch`). Ohne Override riefe das den echten
  /// `healthProvider` auf, der ohne Override wirft
  /// (`UnimplementedError`, siehe `health_provider.dart`) — in Produktion
  /// absichtlich, hier aber unerwünscht für einen Test, der nicht die
  /// Heute-Daten, sondern nur das Tab-Gerüst prüft. `_StillerNotifier`
  /// liefert stattdessen sofort `LeerNachLauf`, ohne Kanal/Cache
  /// anzufassen — `HeuteView` rendert dann ihren „keine Daten"-Zweig, was
  /// hier reicht: Diese Datei prüft nicht den Inhalt von `HeuteView`
  /// (das tut `heute_view_test.dart`), nur dass **sie** es ist, die der
  /// Home-Tab zeigt.
  ///
  /// Seit #282 braucht sie ein Zweites: Der Ernährungs-Tab baut
  /// `ErnaehrungView`, und die liest über `eigeneEintraegeProvider` und
  /// `stammdatenProvider` am `appCacheProvider`. Der **wirft** ohne
  /// Override (`health_provider.dart`) — nicht etwa greift er auf Tims
  /// echte Datei zu —, aber beide Leser sind `AsyncNotifier`, und
  /// `ernaehrungsTagProvider` nimmt ihren Wert mit `.value ?? …`. Der
  /// Wurf verschwände also lautlos in einem `AsyncError`: Der Schirm
  /// stünde in einem Fehlerzustand da, und ausgerechnet der Fall „baut
  /// ohne Ausnahme, auf jedem Tab" wäre grün, ohne etwas zu beweisen.
  /// Eine **echte, leere** Datenbank im Speicher (Muster:
  /// `ernaehrung_provider_test.dart`) kostet nichts und macht den Tab
  /// ehrlich leer statt stillschweigend kaputt. Was `ErnaehrungView`
  /// daraus macht, prüft diese Datei nicht — das tut
  /// `ernaehrung_view_test.dart`.
  Widget huelle(RootView rootView) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    return ProviderScope(
      overrides: [
        appCacheProvider.overrideWithValue(db),
        dailyMetricsProvider.overrideWith(_StillerNotifier.new),
        // #324: Der (+) öffnet die Kamera — ohne Attrappe baute der
        // Vorgabewert ein echtes `MobileScanner` (Nachtrag im Dateikopf).
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
      ],
      child: CupertinoApp(home: rootView),
    );
  }

  test('Tab kennt genau vier Werte, in der Reihenfolge des Boards', () {
    expect(
      Tab.values,
      [Tab.heute, Tab.ernaehrung, Tab.gym, Tab.mehr],
      reason:
          'kein Tab.plan mehr — Plan ist kein Reiter mehr, siehe '
          'components.js:158-172 und mehr_view_test.dart.',
    );
  });

  testWidgets('startet auf dem Home-Tab', (tester) async {
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    expect(router.tab, Tab.heute);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jeder Tab fuehrt seinen eigenen Stapel', (tester) async {
    // Kern der Hausregel (CLAUDE.md): Ohne eigenen Stapel führte in der
    // Swift-App „zurück" aus einem Detailschirm in den Mehr-Tab statt
    // dorthin, wo man hergekommen ist. Hier: In „Mehr" einen Detailschirm
    // öffnen, zu „Home" wechseln, zurück zu „Mehr" — der Detailschirm muss
    // noch oben liegen, nicht verschwunden und nicht auf einem fremden
    // Stapel gelandet.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tippeTab(tester, mehrSymbol);
    expect(router.tab, Tab.mehr);

    const marker = Key('detailschirm-mehr');
    router.open(
      AppTarget.aktuell(
        (context) => const CupertinoPageScaffold(
          child: Center(child: Text('Detailschirm', key: marker)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(marker).hitTestable(), findsOneWidget);

    await tippeTab(tester, homeSymbol);
    expect(router.tab, Tab.heute);
    // Nicht mehr sichtbar, solange ein anderer Tab aktiv ist — aber auch
    // nicht spurlos verschwunden, siehe nächste Zeile nach dem Zurückwechseln.
    expect(find.byKey(marker).hitTestable(), findsNothing);

    await tippeTab(tester, mehrSymbol);
    expect(router.tab, Tab.mehr);
    expect(
      find.byKey(marker).hitTestable(),
      findsOneWidget,
      reason:
          'Der Mehr-Stapel muss den Detailschirm nach dem Tab-Wechsel weg '
          'und zurück noch zeigen — sonst teilen sich alle Tabs einen '
          'Stapel statt je einen eigenen zu führen.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home zeigt den Heute-Schirm, nicht mehr den Platzhalter', (
    tester,
  ) async {
    // Der eigentliche Auftrag dieses Tasks (Punkt 3): HeuteView ist seit
    // Commit bde6e3d gebaut und getestet, hing bisher aber nirgends.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    expect(router.tab, Tab.heute);
    expect(find.byType(HeuteView).hitTestable(), findsOneWidget);
    expect(
      find.byType(PlatzhalterTab),
      findsNothing,
      reason: 'Home zeigt keinen Platzhalter mehr.',
    );
    // flutter#166487: Ohne eigenen CupertinoPageScaffold je Tab-Seite
    // verliert CupertinoSliverNavigationBar/CupertinoNavigationBar die
    // durchscheinende Leiste.
    expect(
      find.ancestor(
        of: find.byType(HeuteView),
        matching: find.byType(CupertinoPageScaffold),
      ),
      findsOneWidget,
    );
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gym zeigt den Gym-Schirm, nicht mehr den Platzhalter', (
    tester,
  ) async {
    // Bis #282 stand hier „Ernaehrung und Gym" und lief über beide Reiter;
    // für Ernährung wurde die Zusage damals eingelöst. Mit #77 ist auch der
    // Gym-Tab verdrahtet, und damit hängt [PlatzhalterTab] an keinem Tab
    // mehr. Die Zusage dahinter gilt unverändert — kein leerer Schirm und
    // keine 0 —, sie wird jetzt von [GymView] eingelöst statt von einem
    // Platzhalter. Nachgezogen am 10.11.2026 mit TEST_AENDERN=1.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tippeTab(tester, gymSymbol);
    expect(router.tab, Tab.gym);

    final gymFinder = find.byType(GymView).hitTestable();
    expect(
      gymFinder,
      findsOneWidget,
      reason: '${Tab.gym} muss den Gym-Schirm zeigen.',
    );
    expect(
      find.byType(PlatzhalterTab),
      findsNothing,
      reason: 'Der Platzhalter ist mit #77 verschwunden.',
    );

    expect(
      find.ancestor(
        of: gymFinder,
        matching: find.byType(CupertinoPageScaffold),
      ),
      findsOneWidget,
    );

    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mehr zeigt weiterhin sein Menue', (tester) async {
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tippeTab(tester, mehrSymbol);

    expect(find.byType(MehrView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tipp auf den aktiven Tab raeumt dessen Stapel ab', (
    tester,
  ) async {
    // Cupertino gibt das nicht von selbst: ein erneuter Tipp auf den schon
    // ausgewählten Tab muss dessen Stapel bis zur Wurzel abräumen
    // (`popUntil`), nicht nichts tun.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tippeTab(tester, mehrSymbol);

    const marker = Key('tiefer-schirm');
    router.open(
      AppTarget.aktuell(
        (context) => const CupertinoPageScaffold(
          child: Center(child: Text('Tief', key: marker)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(marker).hitTestable(), findsOneWidget);

    // Derselbe Tab, der schon aktiv ist, wird erneut angetippt.
    await tippeTab(tester, mehrSymbol);

    expect(
      router.tab,
      Tab.mehr,
      reason: 'Der Tipp bleibt im selben Tab, er wechselt nicht weg.',
    );
    expect(
      find.byKey(marker).hitTestable(),
      findsNothing,
      reason:
          'Der zweite Tipp auf den aktiven Tab muss dessen Stapel bis zur '
          'Wurzel abräumen.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ein Tab-Wechsel wechselt wirklich den Tab, nicht nur den Stapel',
    (tester) async {
      // Der Fehler, den dieser Test ausschließt: eine Implementierung, die
      // „Tab wechseln" als Push einer neuen Seite auf den *gleichen* Stapel
      // umsetzt, statt tatsächlich zwischen den Navigatoren von
      // CupertinoTabView umzuschalten.
      final router = AppRouter();
      await tester.pumpWidget(huelle(RootView(router: router)));
      await tester.pump();

      expect(router.tab, Tab.heute);
      expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);

      await tippeTab(tester, gymSymbol);

      expect(router.tab, Tab.gym);
      expect(
        find.byType(CupertinoNavigationBarBackButton),
        findsNothing,
        reason:
            'Ein Tab-Wechsel landet auf der Wurzel eines eigenen Stapels — '
            'kein Zurück-Chevron.',
      );
      expect(
        find.byType(GymView).hitTestable(),
        findsOneWidget,
        reason: 'Genau ein Gym-Schirm ist sichtbar — der des aktiven Tabs.',
      );
    },
  );

  testWidgets('nur die Tab-Faelle von AppTarget wechseln den Tab', (
    tester,
  ) async {
    // Hausregel aus CLAUDE.md: Ein Detailziel schiebt auf den aktuellen
    // Stapel, nicht in den Tab, unter dem es im Menü einsortiert ist.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    expect(router.tab, Tab.heute);

    const marker = Key('direktziel-heute');
    router.open(
      AppTarget.aktuell(
        (context) => const CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(),
          child: Center(child: Text('Direktziel', key: marker)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.tab,
      Tab.heute,
      reason: 'Ein Detailziel wechselt den Tab nicht.',
    );
    expect(find.byKey(marker).hitTestable(), findsOneWidget);
    expect(
      find.byType(CupertinoNavigationBarBackButton),
      findsOneWidget,
      reason: 'Es wurde geschoben, nicht gewechselt — also gibt es ein Zurück.',
    );

    router.open(AppTarget.ernaehrung());
    await tester.pumpAndSettle();

    expect(
      router.tab,
      Tab.ernaehrung,
      reason: 'Ein Tab-Fall von AppTarget wechselt dagegen den Tab.',
    );
  });

  testWidgets('die Glocke haengt weiterhin an jedem Tab-Stapel', (
    tester,
  ) async {
    // RootView.swift:70 — jeder Stapel bekommt denselben Hinweis-Knopf in
    // der Navigationsleiste, nicht nur „Mehr". Vier statt fünf Tabs, sonst
    // unverändert gegenüber Task 10.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    for (final symbol in const [
      homeSymbol,
      ernaehrungSymbol,
      gymSymbol,
      mehrSymbol,
    ]) {
      await tippeTab(tester, symbol);
      expect(
        find.byKey(const Key('glocke')).hitTestable(),
        findsOneWidget,
        reason: 'Tab mit Symbol "$symbol" zeigt keine Glocke.',
      );
    }
  });

  testWidgets('der Erfassen-Knopf haengt an jedem Tab-Stapel', (
    tester,
  ) async {
    // Der (+) ist kein Tab-Inhalt, sondern Teil der Leiste selbst — er muss
    // deshalb unabhängig vom gerade aktiven Tab sichtbar bleiben, genau wie
    // die Glocke.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    for (final symbol in const [
      homeSymbol,
      ernaehrungSymbol,
      gymSymbol,
      mehrSymbol,
    ]) {
      await tippeTab(tester, symbol);
      expect(
        find.byKey(const Key('erfassen-knopf')).hitTestable(),
        findsOneWidget,
        reason: 'Tab mit Symbol "$symbol" zeigt keinen Erfassen-Knopf.',
      );
    }
  });

  testWidgets(
    'kein Tab-Symbol traegt mehr ein TabBadge-Abzeichen (Regression)',
    (tester) async {
      // TabBadge bleibt als Baustein bestehen (siehe Klassenkommentar), aber
      // seine bisherige Verwendung an den Tab-Symbolen entfällt mit diesem
      // Umbau — ersetzt durch eigene Icons und den Live-Marker am Gym-Tab.
      final router = AppRouter();
      await tester.pumpWidget(huelle(RootView(router: router)));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.byKey(const Key('tab-badge')),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Tippen auf den Erfassen-Knopf oeffnet die Kamera', (
    tester,
  ) async {
    // Bis #285 sagte der (+) wie die Glocke, dass es das noch nicht gibt;
    // bis #324 öffnete er übergangsweise die Suche (Nachträge im
    // Dateikopf). Jetzt öffnet er die Kamera. Was sie tut, prüft
    // `barcode_kamera_test.dart`.
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('erfassen-knopf')));
    await tester.pumpAndSettle();

    expect(
      find.byType(CupertinoAlertDialog),
      findsNothing,
      reason: 'der (+) sagt nicht mehr „kommt später"',
    );
    expect(find.byKey(const Key('kamera')), findsOneWidget);
    expect(
      find.byType(SucheView),
      findsNothing,
      reason: 'die Suche liegt in der Kamera hinter „Suchen", nicht davor',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Langdruecken auf den Erfassen-Knopf faehrt den Bogen mit genau den '
    'drei Board-Eintraegen auf',
    (tester) async {
      // Die drei Einträge laut Board (Auftrag, wörtlich): „Suchen ·
      // Datenbank und zuletzt", „Barcode · Packung scannen", „Foto · Teller
      // abschätzen" — hier nur über die drei Titel geprüft (das sind
      // Menü-Identitäten wie Tab-Namen, keine Fließtext-Untertitel; die
      // Untertitel selbst prüft diese Datei bewusst nicht, CLAUDE.md).
      final router = AppRouter();
      await tester.pumpWidget(huelle(RootView(router: router)));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('erfassen-knopf')));
      await tester.pumpAndSettle();

      for (final titel in const ['Suchen', 'Barcode', 'Foto']) {
        expect(find.text(titel), findsOneWidget, reason: titel);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('der Bogeneintrag Barcode oeffnet die Kamera', (tester) async {
    // Seit #324 freigeschaltet (Nachtrag im Dateikopf).
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tester.longPress(find.byKey(const Key('erfassen-knopf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barcode'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(find.byKey(const Key('kamera')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Foto ist ausgegraut und tut nichts — verschwindet nicht',
    (tester) async {
      // Bis #285 lief dieser Fall über alle drei Einträge, bis #324 über
      // Barcode und Foto (Nachträge im Dateikopf). „Suchen" und „Barcode"
      // sind seitdem verfügbar; Foto (#287) bleibt ausgegraut.
      final router = AppRouter();
      await tester.pumpWidget(huelle(RootView(router: router)));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('erfassen-knopf')));
      await tester.pumpAndSettle();

      for (final titel in const ['Foto']) {
        await tester.tap(find.text(titel), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          find.text(titel),
          findsOneWidget,
          reason:
              '"$titel" darf nach dem Tipp nicht verschwunden sein — '
              'ausgegraut steht es weiter da, nicht weggelassen.',
        );
      }

      expect(
        router.nimmBefehl(),
        isNull,
        reason: 'Foto darf keine Navigation ausloesen.',
      );
      expect(
        find.byType(SucheView),
        findsNothing,
        reason:
            'Seit es einen Weg in die Suche gibt, bewiese nimmBefehl() allein '
            'nicht mehr, dass ein ausgegrauter Eintrag nichts tut.',
      );
      expect(
        find.byKey(const Key('kamera')),
        findsNothing,
        reason: 'Foto ist nicht Barcode — es öffnet keine Kamera.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nach dem Auffahren ist der Schliesszustand erreichbar', (
    tester,
  ) async {
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    await tester.longPress(find.byKey(const Key('erfassen-knopf')));
    await tester.pumpAndSettle();
    expect(find.text('Suchen'), findsOneWidget);

    // Derselbe Knopf, jetzt als (×) — kein zweiter Knopf.
    await tester.tap(find.byKey(const Key('erfassen-knopf')));
    await tester.pumpAndSettle();

    expect(
      find.text('Suchen'),
      findsNothing,
      reason: 'Ein erneuter Tipp auf denselben Knopf schliesst den Bogen.',
    );
    expect(tester.takeException(), isNull);
  });

  group('Gym faerbt sich nur bei laufender Erfassung — Naht fuer spaeter', () {
    testWidgets(
      'ohne den Parameter (Produktionsfall) ist Gym nicht eingefaerbt — M1 '
      'kennt keinen laufenden Trainingszustand',
      (tester) async {
        final router = AppRouter();
        await tester.pumpWidget(huelle(RootView(router: router)));
        await tester.pump();

        expect(find.byKey(const Key('gym-live')), findsNothing);
      },
    );

    testWidgets('erfassungLaeuft: false verhaelt sich wie das Weglassen', (
      tester,
    ) async {
      final router = AppRouter();
      await tester.pumpWidget(
        huelle(RootView(router: router, erfassungLaeuft: false)),
      );
      await tester.pump();

      expect(find.byKey(const Key('gym-live')), findsNothing);
    });

    testWidgets(
      'erfassungLaeuft: true markiert genau den Gym-Eintrag in der '
      'Tableiste, keine andere Stelle',
      (tester) async {
        final router = AppRouter();
        await tester.pumpWidget(
          huelle(RootView(router: router, erfassungLaeuft: true)),
        );
        await tester.pump();

        final marker = find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.byKey(const Key('gym-live')),
        );
        expect(
          marker,
          findsOneWidget,
          reason:
              'genau eine Markierung in der Tableiste — kein Abzeichen, '
              'keine zweite Stelle (siehe Tabelle im Auftrag: „nur der '
              'Gym-Eintrag färbt sich").',
        );

        // Beweis, dass die Markierung wirklich am GYM-Eintrag sitzt, nicht
        // zufällig an einem anderen: ein Tipp darauf muss zum Gym-Tab
        // führen.
        await tester.tap(marker.hitTestable());
        await tester.pumpAndSettle();

        expect(router.tab, Tab.gym);
      },
    );
  });

  testWidgets('baut ohne Ausnahme, auf jedem Tab und mit offenem Bogen', (
    tester,
  ) async {
    final router = AppRouter();
    await tester.pumpWidget(huelle(RootView(router: router)));
    await tester.pump();

    for (final symbol in const [
      homeSymbol,
      ernaehrungSymbol,
      gymSymbol,
      mehrSymbol,
    ]) {
      await tippeTab(tester, symbol);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    }

    await tester.longPress(find.byKey(const Key('erfassen-knopf')));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Hält `HeuteView` während dieser Tab-Gerüst-Tests harmlos — siehe
/// Begründung bei `huelle(...)` oben. Parallel zu `_GesteuerterNotifier` in
/// `heute_view_test.dart`, hier aber ohne jede Steuerbarkeit: Diese Datei
/// prüft nicht, was `HeuteView` mit verschiedenen Zustandsfolgen anzeigt
/// (das deckt `heute_view_test.dart` ab), nur dass sie überhaupt an der
/// richtigen Stelle hängt.
class _StillerNotifier extends DailyMetricsNotifier {
  @override
  Future<Messwert<List<DailyMetrics>>> build() async =>
      LeerNachLauf<List<DailyMetrics>>(gelaufen: DateTime.utc(2026, 1, 1));
}
