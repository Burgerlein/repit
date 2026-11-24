import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/formatierung.dart';
import '../design/glas.dart';
import '../design/palette.dart';
import '../design/symbole.dart';
import '../ernaehrung/erfassen_weg.dart';
import '../ernaehrung/ernaehrung_kalender.dart';
import '../ernaehrung/ernaehrung_view.dart';
import '../ernaehrung/kamera_seite.dart';
import '../gym/gym_view.dart';
import '../health/health_provider.dart';
import 'erfassen_knopf.dart';
import 'heute_view.dart';
import 'mehr_view.dart';
import 'platzhalter_tab.dart';
import 'router.dart';
import 'ziele.dart';

export 'erfassen_knopf.dart';

/// Tab-Gerüst der App — Dart-Entsprechung von `RootView.swift`, seit dem
/// Tableisten-Umbau (task-navbar, 26.10.2026) nach
/// `docs/screens/components.js` ab Zeile 158: **Home · Ernährung · (+) ·
/// Gym · Mehr** statt der fünf Reiter der Swift-Vorlage.
///
/// `CupertinoTabScaffold` + `CupertinoTabView` gibt jedem der vier Tabs von
/// sich aus einen eigenen `Navigator` mit eigenem Stapel (Entwurf Abschnitt
/// 6.7 — genau das Modell aus `RootView.swift:65`, samt der Hausregel
/// „jeder Tab führt seinen eigenen Navigationsstapel". Der (+) ist dabei
/// **kein** Tab — er schwebt als eigener Baustein ([ErfassenKnopf]) über
/// der ganzen `CupertinoTabScaffold`, in einem `Stack`, der beide
/// zusammenhält.
///
/// Vier Dinge gibt Cupertino dabei **nicht** von selbst (Task-Brief):
///  - Ein Tipp auf den schon aktiven Tab räumt dessen Stapel ab
///    ([_onTabBarTap], über `popUntil`).
///  - Ein Abzeichen am Tab-Symbol ([TabBadge], als `Stack`-Overlay) — seit
///    diesem Umbau nur noch für die Glocke in der Navigationsleiste
///    benutzt, nicht mehr für die Tab-Symbole selbst (siehe `_TabIcon`).
///  - Etwas über alle Tabs schieben (`Navigator.of(context, rootNavigator:
///    true)`) — in M1 noch nicht gebraucht, da `AppTarget` nur `.aktuell`
///    und `.detail` kennt, beide innerhalb eines Tab-Stapels.
///  - Der (+)/(×)-Knopf mit Bogenmenü selbst ([ErfassenKnopf], ausgelagert
///    nach `erfassen_knopf.dart` — CLAUDE.md: „Views bleiben klein").
///
/// `AppRouter` ist der Zustand; `RootView` hört auf ihn (`addListener`),
/// damit ein `router.open(...)`, das von außerhalb des Baums aufgerufen
/// wird, tatsächlich wirkt. Die eigentliche Bildschirmaktualisierung beim
/// Tab-Wechsel übernimmt danach `CupertinoTabScaffold` selbst, sobald
/// `_tabController` einen neuen Index bekommt — dafür muss `RootView`
/// nicht neu bauen (`setState`), und tut es auch nicht: `CupertinoTabView`
/// warnt ausdrücklich davor, den Navigationsstapel eines Tabs über einen
/// neuen `builder` von außen aktualisieren zu wollen (Entwurf Abschnitt
/// 6.7) — Pushes laufen hier deshalb ausschließlich über die
/// `GlobalKey<NavigatorState>` je Tab, nicht über neue Widget-Instanzen.
class RootView extends StatefulWidget {
  const RootView({super.key, this.router, this.erfassungLaeuft = false});

  /// Ohne `router` baut sich `RootView` selbst einen (Produktionsfall, siehe
  /// `main.dart`). Mit `router` übernimmt sie die übergebene Instanz
  /// (Testfall) — dieselbe Instanz bleibt danach erreichbar, damit ein Test
  /// über sie weiter navigieren kann.
  final AppRouter? router;

  /// Färbt **nur** den Gym-Tab-Eintrag ein (`Palette.iron`, kein Abzeichen —
  /// „ein Abzeichen neben dem Symbol verschob es sichtbar gegen die anderen
  /// vier", `components.css`). Die Naht für einen späteren Trainingszustand:
  /// M1 kennt keinen laufenden Trainingszustand, also setzt ihn **kein**
  /// Aufrufer (auch `main.dart` nicht) auf `true` — ein künftiger Task muss
  /// nur noch den Wert liefern, nicht erst diese Stelle finden.
  final bool erfassungLaeuft;

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  late final AppRouter _router = widget.router ?? AppRouter();
  late final CupertinoTabController _tabController = CupertinoTabController(
    initialIndex: _barIndexFuerTab(_router.tab),
  );

  final Map<Tab, GlobalKey<NavigatorState>> _navigatorSchluessel = {
    for (final tab in Tab.values) tab: GlobalKey<NavigatorState>(),
  };

  @override
  void initState() {
    super.initState();
    _router.addListener(_aufRouterAenderung);
  }

  @override
  void dispose() {
    _router.removeListener(_aufRouterAenderung);
    _tabController.dispose();
    super.dispose();
  }

  /// Reagiert auf `AppRouter.open(...)`, auch wenn der Aufruf von
  /// außerhalb des Baums kommt (z. B. aus einem Test). Der Tab-Index genügt
  /// `CupertinoTabScaffold` bereits, um sichtbar umzuschalten — dafür ist
  /// kein `setState` auf `RootView` selbst nötig, siehe Klassenkommentar.
  /// Ein ausstehender Push wird erst **nach** dem Frame abgearbeitet, in
  /// dem der Ziel-Tab sichtbar (und sein `Navigator` damit gebaut) wird.
  void _aufRouterAenderung() {
    // `_router.tab.index` zählt nur die vier echten Tabs (0..3) — die
    // Tableiste selbst hat seit task-layout-fixes fünf Spalten (die Lücke
    // für den (+), siehe `_barIndexFuerTab`/`_tabFuerBarIndex`), also muss
    // hier übersetzt werden, nicht der rohe Index durchgereicht werden.
    _tabController.index = _barIndexFuerTab(_router.tab);

    final befehl = _router.nimmBefehl();
    if (befehl == null) return;

    // Ohne `AppTarget.aktuell` ändert sich `_tabController.index` nicht
    // (derselbe Tab bleibt aktiv), also schedulet dessen Setter **keinen**
    // Frame — und ohne angeforderten Frame führt `pumpAndSettle` in Tests
    // gar keinen Durchlauf aus (`TestWidgetsFlutterBinding.pump` zeichnet
    // nur, wenn `hasScheduledFrame` wahr ist), wodurch der untenstehende
    // `addPostFrameCallback` nie abgearbeitet würde. `scheduleFrame()`
    // erzwingt deshalb ausdrücklich einen Frame, unabhängig davon, ob der
    // Tab-Wechsel selbst schon einen angefordert hat.
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorSchluessel[befehl.tab]?.currentState;
      if (navigator == null) return;
      if (befehl.ersetztStapel) {
        navigator.pushAndRemoveUntil(
          CupertinoPageRoute<void>(builder: befehl.builder),
          (route) => false,
        );
      } else {
        navigator.push(CupertinoPageRoute<void>(builder: befehl.builder));
      }
    });
  }

  /// `CupertinoTabScaffold` aktualisiert `_tabController.index` bei jedem
  /// Tipp bereits selbst (siehe `tab_scaffold.dart`) — und zwar **bevor**
  /// dieser Callback überhaupt läuft (`tab_scaffold.dart`: der Wrapper setzt
  /// `_controller.index = newIndex` und ruft erst danach `tabBar.onTap`).
  /// Trifft der Tipp die Lückenspalte ([_tabBarLueckenIndex], unter dem (+)),
  /// hat `_tabController.index` also schon kurz auf die Lücke gezeigt; dieser
  /// Callback dreht das im selben Durchlauf wieder zurück, bevor ein Frame
  /// gezeichnet wird — kein Tab-Wechsel, kein Rebuild auf einen Inhalt, den
  /// es für die Lücke gar nicht gibt (siehe `tabBuilder`). Trifft der Tipp
  /// einen echten Tab, hält dieser Callback zusätzlich `AppRouter` auf
  /// demselben Stand (einzige Quelle der Wahrheit für `router.tab`, siehe
  /// Tests) und verdrahtet die zweite iOS-Regel, die Cupertino nicht von
  /// selbst gibt: Ein Tipp auf den schon aktiven Tab räumt dessen Stapel bis
  /// zur Wurzel ab, statt nichts zu tun.
  void _onTabBarTap(int barIndex) {
    final ziel = _tabFuerBarIndex(barIndex);
    if (ziel == null) {
      // Die Lücke nimmt den Tipp entgegen und tut nichts — der (+) liegt
      // optisch darüber und bekommt seine eigenen Tipps über seinen eigenen
      // `GestureDetector` (siehe `build`), dieser Pfad hier fängt nur ab,
      // was daneben auf die Lückenspalte selbst trifft.
      _tabController.index = _barIndexFuerTab(_router.tab);
      return;
    }
    if (ziel == _router.tab) {
      _navigatorSchluessel[ziel]!.currentState?.popUntil(
        (route) => route.isFirst,
      );
      return;
    }
    _router.open(_zielFuer(ziel));
  }

  AppTarget _zielFuer(Tab tab) => switch (tab) {
    Tab.heute => AppTarget.heute(),
    Tab.ernaehrung => AppTarget.ernaehrung(),
    Tab.gym => AppTarget.gym(),
    Tab.mehr => AppTarget.mehr(),
  };

  // Die Tableiste hat fünf Spalten, nicht vier: vier gleich breite Punkte
  // und in der Mitte eine Lücke derselben Breite, unter der der (+) sitzt
  // (components.js: „Aufbau wie in der Flutter-Vorgabe... Dadurch sitzt der
  // Knopf mittig und die vier Punkte stehen symmetrisch, ohne eine einzige
  // feste Breite"). `CupertinoTabBar`/`CupertinoTabScaffold` kennen aber nur
  // durchnummerierte Spalten (siehe `tabBuilder`/`_onTabBarTap`), deshalb
  // übersetzen genau diese beiden Stellen zwischen Bar-Index (0..4, die
  // Lücke eingeschlossen) und `Tab` (0..3, ohne die Lücke) — eine
  // Entscheidung gegen den Kommentar des vorigen Agenten, der die 1:1-
  // Entsprechung zwischen `Tab.values` und den Bar-Einträgen für
  // wichtiger hielt als das Board: Das Board ist bindend (CLAUDE.md,
  // „Entwurfsübersicht"), die interne Bequemlichkeit einer 1:1-Zuordnung
  // nicht.
  static const _tabBarLueckenIndex = 2;

  int _barIndexFuerTab(Tab tab) =>
      tab.index >= _tabBarLueckenIndex ? tab.index + 1 : tab.index;

  Tab? _tabFuerBarIndex(int barIndex) {
    if (barIndex == _tabBarLueckenIndex) return null;
    final verschoben = barIndex > _tabBarLueckenIndex ? barIndex - 1 : barIndex;
    return Tab.values[verschoben];
  }

  @override
  Widget build(BuildContext context) {
    final hintergrund = CupertinoDynamicColor.resolve(Palette.bg, context);

    // Der (+) ist kein Tab, sondern schwebt über der ganzen Leiste
    // (components.css: „Der Knopf ragt 12 Punkt über die Leiste und
    // stanzt sich mit einem Schatten in der Farbe der Leiste frei"). Ein
    // `Stack` über `CupertinoTabScaffold` hält beides zusammen, ohne dass
    // `CupertinoTabBar` selbst eine ausgeschnittene Form bräuchte —
    // `clipBehavior: Clip.none`, weil der Knopf bewusst über die
    // Oberkante der Leiste hinausragt.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CupertinoTabScaffold(
          controller: _tabController,
          // flutter#179482 (iOS 26, Tastatur halbtransparent): Ohne ein
          // ausdrücklich gesetztes `backgroundColor` bliebe die Fläche, die
          // hinter der jetzt durchscheinenden Tastatur sichtbar wird, dem
          // nicht näher definierten Hintergrund des Scaffolds überlassen.
          // Jeder Scaffold in dieser Datei (hier und in `_tabSeite`) bekommt
          // deshalb durchgängig `Palette.bg` — "durchzeichnen statt
          // abschneiden": die Fläche ist überall dieselbe Farbe, es gibt
          // nirgends ein unbemaltes Loch, das die Tastatur freilegen könnte.
          backgroundColor: hintergrund,
          // Native Cupertino-Transluzenz (BackdropFilter), nicht `Glas` aus
          // Task 9: `CupertinoTabScaffold.tabBar` verlangt eine konkrete
          // `CupertinoTabBar`-Instanz, und `CupertinoTabScaffold` ruft bei
          // *jedem* Build `tabBar.copyWith(currentIndex:, onTap:)` auf (siehe
          // `tab_scaffold.dart`) — `copyWith` liefert dabei immer die
          // Basisklasse zurück, auch wenn man selbst von `CupertinoTabBar`
          // erbt. Eine eigene Unterklasse würde ihre `Glas`-Hülle also bei der
          // nächsten Gelegenheit wieder verlieren. Ein transluzentes
          // `backgroundColor` aktiviert stattdessen Cupertinos eingebauten
          // Weichzeichner (`bottom_tab_bar.dart:198-201`) — kein
          // `liquid_glass_widgets`-Shader, aber derselbe „durchscheinend statt
          // deckend"-Effekt an genau der Stelle. Siehe Bericht für die
          // Einordnung dieser Abweichung von der Vorgabe.
          tabBar: CupertinoTabBar(
            backgroundColor: hintergrund.withAlpha(217),
            onTap: _onTabBarTap,
            // Die Höhe aus components.css ab Zeile 77 (64 Punkt, ohne die
            // Gerätegeste) — ohne dieses Attribut nimmt `CupertinoTabBar`
            // seine iOS-10-Standardhöhe (50 Punkt), und `_fabAbstandVonUnten`
            // unten verlässt sich auf genau diesen Wert, um den Überstand des
            // (+) zu berechnen. Derselbe Wert bestimmt außerdem automatisch,
            // wie viel Platz `CupertinoPageScaffold`/`GlasAbstand` unten für
            // den Inhalt reservieren (`MediaQuery.padding.bottom`).
            height: _tabBarHoehe,
            // Fünf Spalten, nicht vier: vier gleich breite Punkte und in der
            // Mitte eine Lücke derselben Breite, unter der der (+) sitzt
            // (components.js/.css, siehe Klassenkommentar bei
            // `_tabBarLueckenIndex`). `CupertinoTabBar` verteilt seine
            // `items` von sich aus über gleich große `Expanded`-Spalten
            // (`bottom_tab_bar.dart`) — auch die Lückenspalte ist einfach ein
            // fünftes Element ohne sichtbaren Inhalt, keine Sonderbehandlung
            // im Layout nötig.
            items: [
              _item('target', 'Home'),
              _item('fork.knife', 'Ernährung'),
              _lueckenItem(),
              _item('dumbbell', 'Gym', live: widget.erfassungLaeuft),
              _item('ellipsis', 'Mehr'),
            ],
          ),
          tabBuilder: (context, barIndex) {
            final tab = _tabFuerBarIndex(barIndex);
            // Die Lückenspalte hat keinen Tab-Inhalt — `_onTabBarTap` dreht
            // `_tabController.index` zurück, bevor ein Frame mit diesem
            // Index gezeichnet wird (siehe dort), dieser Zweig ist also nur
            // eine harmlose Absicherung, kein erreichbarer Dauerzustand.
            if (tab == null) return const SizedBox.shrink();
            return CupertinoTabView(
              navigatorKey: _navigatorSchluessel[tab],
              builder: (context) => _tabSeite(tab),
            );
          },
        ),
        // Mittig über der ganzen Breite — dieselbe horizontale Mitte, die
        // die Lückenspalte in der fünfspaltigen Leiste ohne weiteres Zutun
        // ergibt (siehe Kommentar bei `tabBar` oben). `bottom` platziert den
        // Knopf so, dass sein oberer Rand 12 Punkt über der Leistenoberkante
        // liegt (components.css); Pixelmaße sind laut CLAUDE.md kein
        // Gegenstand von Widget-Tests — siehe Bericht für die
        // Prüfanleitung im Simulator.
        Positioned(
          left: 0,
          right: 0,
          bottom: _fabAbstandVonUnten(context),
          child: Center(
            child: ErfassenKnopf(
              eintraege: [
                // Die drei Wege laut Board. „Suchen" (#285) und „Barcode"
                // (#324) sind gebaut; Foto (#287) steht weiter ausgegraut
                // da und tut nichts.
                BogenEintrag(
                  titel: 'Suchen',
                  hinweis: 'Datenbank und zuletzt',
                  symbol: 'list.bullet',
                  onTap: () => oeffneSuche(_router),
                ),
                BogenEintrag(
                  titel: 'Barcode',
                  hinweis: 'Packung scannen',
                  symbol: 'expand',
                  onTap: () => oeffneKamera(_router),
                ),
                const BogenEintrag(
                  titel: 'Foto',
                  hinweis: 'Teller abschätzen',
                  symbol: 'photo',
                  verfuegbar: false,
                ),
              ],
              // Der (+) öffnet direkt die Kamera (`erfassen.js`, #324) —
              // „Suchen" liegt dort oben rechts. Auf den Stapel des Tabs,
              // in dem man gerade ist, und auf den offenen Tag des
              // Ernährungs-Schirms (`oeffneKamera`).
              onErfassen: () => oeffneKamera(_router),
            ),
          ),
        ),
      ],
    );
  }

  // Höhe der Tab-Leiste ohne Gerätegeste (components.css: 64 Punkt) — auch
  // an `CupertinoTabBar.height` oben gereicht, damit beide Stellen von
  // derselben Zahl ausgehen. Der Knopf soll 12 Punkt über die Leiste ragen
  // (components.css).
  static const _tabBarHoehe = 64.0;
  static const _fabUeberstand = 12.0;

  /// Abstand der **Unterkante** von [ErfassenKnopf] zur Unterkante des
  /// Stapels — nicht die Höhe des ganzen Bausteins samt Bogenfläche
  /// (`ErfassenKnopf` reserviert dafür eine 260 Punkt hohe, größtenteils
  /// leere Box, siehe dessen Klassenkommentar; der sichtbare Knopf selbst
  /// sitzt nur an deren Unterkante). Die vorige Fassung dieser Funktion
  /// benutzte `geste + _tabBarHoehe - _fabUeberstand` — das hätte nur
  /// gestimmt, wenn `ErfassenKnopf` nicht höher als sein eigener Knopf wäre.
  /// Weil die Box tatsächlich 260 Punkt hoch ist und der Knopf an **ihrer**
  /// Unterkante hängt, landete der sichtbare Knopf 34 Punkt zu hoch — mitten
  /// im Inhalt des Schirms statt 12 Punkt über der Leiste (Tims
  /// Beobachtung: „überdeckt er den Hinweisfuß").
  ///
  /// Richtig: Die Oberkante des Knopfs soll 12 Punkt über der Leistenoberkante
  /// liegen (`geste + _tabBarHoehe + _fabUeberstand`), seine Unterkante liegt
  /// einen Knopfdurchmesser darunter.
  double _fabAbstandVonUnten(BuildContext context) {
    final geste = MediaQuery.of(context).padding.bottom;
    return geste +
        _tabBarHoehe +
        _fabUeberstand -
        ErfassenKnopf.knopfDurchmesser;
  }

  BottomNavigationBarItem _item(
    String symbol,
    String label, {
    bool live = false,
  }) {
    return BottomNavigationBarItem(
      icon: _TabIcon(symbol: symbol, live: live),
      label: label,
    );
  }

  /// Die Lückenspalte unter dem (+) — ein `BottomNavigationBarItem` ohne
  /// sichtbaren Inhalt, nur damit `CupertinoTabBar` eine fünfte, gleich
  /// breite `Expanded`-Spalte anlegt (siehe Kommentar bei `tabBar` in
  /// `build`). `SizedBox.shrink()` statt eines leeren `Icon`, damit hier
  /// wirklich nichts gezeichnet wird — auch kein unsichtbares Symbol, das
  /// trotzdem Platz für sich beanspruchen oder Semantik tragen könnte.
  BottomNavigationBarItem _lueckenItem() {
    return const BottomNavigationBarItem(icon: SizedBox.shrink());
  }

  /// Wurzelschirm eines Tabs. **Jede Tab-Seite in `CupertinoPageScaffold`
  /// gewickelt**, sonst verliert `CupertinoSliverNavigationBar` die
  /// durchscheinende Leiste (flutter#166487) — hier betrifft es zwar nur
  /// die kleine `CupertinoNavigationBar`, nicht deren Sliver-Fassung, aber
  /// dieselbe Regel: ohne eigenen Scaffold kein verlässlicher Rahmen für
  /// Navigationsleiste und Inhalt.
  ///
  /// **Home zeigt seit task-navbar [HeuteView]**, nicht mehr
  /// [PlatzhalterTab] (Punkt 88 „Heute-Schirm verdrahten" — erledigt und im
  /// selben Commit gelöscht, nie ein Issue). Ernährung zeigt seit #282
  /// [ErnaehrungView], Gym seit #77 [GymView], Mehr seit Task 11 sein
  /// eigentliches Menü ([MehrView]). **Damit hängt [PlatzhalterTab] an
  /// keinem Tab mehr**; er bleibt als Baustein stehen, weil ein künftiger
  /// Schirm wieder einen ehrlichen Zwischenstand braucht.
  ///
  /// Alle vier teilen dieselbe Navigationsleiste mit der Hinweis-Glocke
  /// (`RootView.swift:70`, jeder Stapel bekommt denselben Knopf).
  Widget _tabSeite(Tab tab) {
    final Widget titel = switch (tab) {
      // **Der Wochentag, nicht „Heute"** (#514, Tim am 16.11.2026: „das
      // Home gegen den heutigen Tag austauschen — dann steht da Montag
      // z. B."). Bis dahin hieß die Leiste „Heute" (#501), das Datum
      // stand groß auf dem Schirm; beides ist dem Wochentag gewichen.
      // Das Label **in der Tableiste** bleibt „Home", so steht es seit
      // dem 26.10.2026 auf dem Board (`components.js:158`); der Reiter
      // heißt so, der Schirm heißt anders.
      //
      // Ein eigenes kleines Widget, kein in `build` gezogener String:
      // `CupertinoTabView` baut seine Route **einmal** — ein hier
      // gelesener Wert fröre auf den Tag des ersten Baus ein und stünde
      // nach Mitternacht falsch da (Fehler `01` im Titel). Das Widget
      // beobachtet den Tag selbst und geht beim Wechsel mit.
      Tab.heute => const _WochentagTitel(),
      Tab.ernaehrung => const Text('Ernährung'),
      Tab.gym => const Text('Gym'),
      Tab.mehr => const Text('Mehr'),
    };

    final body = switch (tab) {
      Tab.heute => HeuteView(router: _router),
      // Seit Task 4 des Ernährungsplans (#282) der Tag-Schirm statt des
      // Platzhalters. `ErnaehrungView` bringt kein eigenes Gerüst mit —
      // das stellt `_tabSeite` unten, wie für jeden Tab.
      // Der `router` ist seit #300 die Tür vom Tagesschirm auf den
      // Mahlzeiten-Schirm. Er bleibt optional: Der Bauvertrag
      // `const ErnaehrungView({super.key})` steht in einer Testdatei.
      Tab.ernaehrung => ErnaehrungView(router: _router),
      // Seit #77 der Gym-Übersichtsschirm statt des Platzhalters.
      // `GymView` bringt kein eigenes Gerüst mit — das stellt `_tabSeite`
      // unten, wie für jeden Tab. Der `router` ist die Naht für die
      // Detailschirme (#78, #79, #93, #533; die Muskelkarte #96 fehlt noch).
      Tab.gym => GymView(router: _router),
      // `MehrSeite` statt `MehrView`: Die Zeile „Zyklus" steht nur bei
      // eingeschaltetem Kalender (#573), und den Schalter liest die Hülle
      // — `MehrView` selbst bleibt ohne `ref` (siehe dort).
      Tab.mehr => MehrSeite(router: _router),
    };

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: _GlasNavigationBar(
        titel: titel,
        onGlockeTap: _zeigeHinweiseNochNicht,
        // Der Kalender des Ernährungs-Tags (#409) steht **neben** der
        // Glocke, wie beim Schlaf oben rechts — die Glocke bleibt auf
        // jedem Wurzelschirm.
        vorGlocke: tab == Tab.ernaehrung
            ? const ErnaehrungKalenderKnopf()
            : null,
      ),
      child: body,
    );
  }

  void _zeigeHinweiseNochNicht() {
    final context =
        _navigatorSchluessel[_router.tab]?.currentContext ?? this.context;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Hinweise'),
        content: const Text(
          'Hinweise sind noch nicht verfügbar. Diese Funktion kommt in '
          'einer späteren Aufgabe.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Symbol für ein Element der Tab-Leiste.
///
/// Seit task-navbar **ohne** [TabBadge]: Ein Abzeichen neben dem Symbol
/// verschob es sichtbar gegen die anderen drei, und dafür sagte es nichts,
/// was eine Farbe nicht auch sagt (`components.css`, Kommentar bei
/// `.tabbar .tab.live`). [TabBadge] bleibt als Baustein bestehen — er trägt
/// weiterhin die Glocke in der Navigationsleiste ([_GlasNavigationBar]) —,
/// wird hier aber nicht mehr verwendet.
///
/// [live] markiert **nur** den Gym-Eintrag, solange [RootView.erfassungLaeuft]
/// `true` ist: ein struktureller `Key('gym-live')`, keine geprüfte Farbe
/// (CLAUDE.md verbietet Farbwerte in Widget-Tests) — dieselbe Prüfidee wie
/// bei [TabBadge] selbst (da/nicht da, nie der Wert).
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.symbol, this.live = false});

  final String symbol;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Symbole.aufloesen(symbol));
    if (!live) return icon;

    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    return Icon(
      key: const Key('gym-live'),
      Symbole.aufloesen(symbol),
      color: iron,
    );
  }
}

/// Abzeichen auf einem Symbol — es gibt kein `.badge`-Gegenstück in
/// Cupertino (anders als SwiftUIs `.badge(_:)` in `RootView.swift:73`), also
/// wird der Hinweis als `Stack`-Overlay auf dem Symbol selbst gezeichnet.
///
/// Bewusst ein eigener, öffentlicher, generischer Baustein statt in eine
/// private Tab-Aufbaufunktion verwoben — nur so lässt er sich isoliert
/// prüfen (`tab_badge_test.dart`), parallel zu `IconRow`/`Glas` aus Task 9.
///
/// Seit task-navbar (26.10.2026) nur noch an **einer** Stelle verwendet —
/// der Glocke in der Navigationsleiste ([_GlasNavigationBar]) —, nicht mehr
/// an den Tab-Symbolen selbst (siehe [_TabIcon]). Trotzdem keine tote
/// Klasse: `navbar()` in `docs/screens/components.js` trägt weiterhin ein
/// `hints`-Abzeichen auf der Glocke, unverändert gegenüber vorher —
/// Entscheidung, nicht Versehen (siehe `root_view_test.dart`,
/// Klassenkommentar „Was mit TabBadge passiert").
class TabBadge extends StatelessWidget {
  const TabBadge({super.key, required this.symbol, this.wert});

  /// Name aus `Symbole.tabelle`, z. B. `"dumbbell"`.
  final String symbol;

  /// `null` oder leer: kein Abzeichen, auch kein leerer Kreis. M1 hat keinen
  /// Tab mit einem echten Wert — genau deshalb prüft `tab_badge_test.dart`
  /// ausdrücklich, dass „kein Wert" auch wirklich nichts zusätzlich
  /// zeichnet.
  final String? wert;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Symbole.aufloesen(symbol));

    final zeigeAbzeichen = wert != null && wert!.isNotEmpty;
    if (!zeigeAbzeichen) return icon;

    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -6,
          right: -8,
          child: Container(
            key: const Key('tab-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: warn,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              wert!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Navigationsleiste mit `Glas`-Hintergrund statt der deckenden
/// Standardfarbe von `CupertinoNavigationBar` — anders als bei der
/// Tab-Leiste (siehe Kommentar in `RootView.build`) lässt `navigationBar:`
/// in `CupertinoPageScaffold` jeden `ObstructingPreferredSizeWidget` zu,
/// nicht nur eine konkrete Klasse. Deshalb kann hier die echte
/// `CupertinoNavigationBar` (Titel-Layout, automatischer Zurück-Chevron,
/// Trailing-Slot) wiederverwendet werden, nur mit transparentem eigenem
/// Hintergrund, und `Glas` übernimmt das Zeichnen dahinter.
///
/// flutter#192372 (Blur-Band über der Statusleiste beim Scrollen, von
/// keinem Test sichtbar): `border: null` entfernt die haarfeine
/// Trennlinie unter der Leiste, damit hier keine harte Farbkante entsteht,
/// an der sich das System-Blur-Band bricht — die Fläche bleibt bis zum
/// Rand durchscheinend, ohne zusätzliche Kontur.
class _GlasNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  _GlasNavigationBar({
    required this.titel,
    required this.onGlockeTap,
    Widget? vorGlocke,
  }) : _bar = CupertinoNavigationBar(
         middle: titel,
         backgroundColor: const Color(0x00000000),
         border: null,
         trailing: _rechts(
           vorGlocke,
           CupertinoButton(
             padding: EdgeInsets.zero,
             onPressed: onGlockeTap,
             child: TabBadge(key: const Key('glocke'), symbol: 'bell'),
           ),
         ),
       );

  static Widget _rechts(Widget? vorGlocke, Widget glocke) => vorGlocke == null
      ? glocke
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [vorGlocke, const SizedBox(width: 6), glocke],
        );

  /// Die Mitte der Leiste — meist ein fester `Text`, auf Home der
  /// selbst beobachtende [_WochentagTitel].
  final Widget titel;
  final VoidCallback onGlockeTap;
  final CupertinoNavigationBar _bar;

  @override
  Size get preferredSize => _bar.preferredSize;

  @override
  bool shouldFullyObstruct(BuildContext context) =>
      _bar.shouldFullyObstruct(context);

  @override
  Widget build(BuildContext context) => Glas(child: _bar);
}

/// Der Leistentitel von Home: der Wochentag des heutigen Berliner Tages
/// (#514).
///
/// Beobachtet `heutigerTagProvider` — er ändert sich **nur** beim
/// Kalendertagswechsel (dort begründet), also rechnet dieser Titel weder
/// je Bild (Fehler `03`) noch friert er auf den Starttag ein (Fehler `01`).
/// `kalendertag` vor dem Formatierer: Der Provider trägt den UTC-Moment
/// des Berliner Tagesbeginns, und der liegt am Vortagsdatum.
class _WochentagTitel extends ConsumerWidget {
  const _WochentagTitel();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(Format.wochentag(kalendertag(ref.watch(heutigerTagProvider))));
}
