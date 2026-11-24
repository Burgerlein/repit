import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/glas_abstand.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../ki/ki_zugang_view.dart';
import '../koerper/umfaenge_eintragen.dart';
import '../uebernahme/uebernahme_view.dart';
import '../ziele/ziele_view.dart';
import '../zyklus/zyklus_einrichten_view.dart';
import '../zyklus/zyklus_texte.dart';
import '../zyklus/zyklus_view.dart';
import '../zyklus/zyklus_zustand.dart';
import 'aenderungen.dart';
import 'ausdauer_view.dart';
import 'erholung_view.dart';
import 'healthkit_test_view.dart';
import 'koerper_view.dart';
// `ziele.dart` (AppTarget) kommt über den Re-Export von `aenderungen.dart`
// mit — ein eigener Import daneben wäre `unnecessary_import`.
import 'router.dart';
import 'vorlaeufige_werte_view.dart';

/// Ein Ziel im Mehr-Menü — Dart-Entsprechung der Fälle aus
/// `Sources/Features/Shell/MoreView.swift` (`MoreDestination`/`MoreRow`),
/// hier flach als ein einziges Enum statt zweier verschränkter Typen: Die
/// Swift-Vorlage trennt `.more(MoreDestination)`/`.body(BodyDestination)`,
/// weil „Umfänge messen" technisch ein Körper-Schirm ist. Diese Flutter-
/// Fassung kennt bisher nur das Mehr-Menü selbst (kein `BodyDestination`
/// existiert noch), daher reicht ein Fall pro Zeile.
enum MehrZiel {
  plan,
  ziele,
  aktivitaeten,
  umfaengeMessen,
  koerper,
  erholung,
  ausdauer,
  coach,
  datenUndEinstellungen,
  datenUebernehmen,
  healthKitTest,
  vorlaeufigeWerte,
  kiZugang,
}

/// Eine Zeile im Mehr-Menü: Titel, Untertitel, Symbolname (aus
/// `Symbole.tabelle`), Akzentfarbe und ob sie schon irgendwohin führt.
class _Eintrag {
  const _Eintrag({
    required this.ziel,
    required this.titel,
    required this.untertitel,
    required this.symbol,
    required this.akzent,
    this.istAktiv = false,
  });

  final MehrZiel ziel;
  final String titel;

  /// Rein beschreibend und zahlenfrei — anders als die Swift-Vorlage, deren
  /// Untertitel echte Trainings-/Gesundheitswerte von Tim enthalten
  /// (`MoreView.swift:12-85`). `CLAUDE.md` verbietet solche Werte im
  /// Quelltext ausdrücklich, auch „nur zum Ansehen".
  final String untertitel;
  final String symbol;
  final Color akzent;

  /// `true` für `plan`, `ziele`, `umfaengeMessen`, `koerper`, `erholung`,
  /// `datenUebernehmen`, `healthKitTest`, `vorlaeufigeWerte` und
  /// `kiZugang` — die Zeilen, die irgendwohin führen. „Körper" kam mit #82
  /// dazu, „Vorläufige Werte" mit #307, „KI-Zugang" mit #339, „Ziele" mit
  /// #448, „Umfänge messen" mit #477, „Daten übernehmen" mit #59 (siehe
  /// Klassenkommentar `MehrView`).
  final bool istAktiv;
}

/// Hängt an jede nicht fertige Zeile denselben Hinweis — sichtbar statt
/// stumm nichts zu tun beim Antippen (Task-Brief Schritt 3). Der Hinweis
/// wird an den jeweils schon eigenen, unterschiedlichen Untertitel
/// angehängt statt als eigener, überall gleicher Text zu stehen: Ein
/// einzelner, zehnmal wiederholter Satz wäre in der Oberfläche redundant
/// und ließe sich zudem nicht von neun verschiedenen Stellen im Baum
/// unterscheiden.
const _nochNichtHinweis = ' — folgt in einer späteren Aufgabe.';

/// Das *Mehr*-Menü — Dart-Entsprechung von `MoreView.swift`.
///
/// Zeigt alle geplanten Punkte aus `MoreView.swift:138-144`, in derselben
/// Reihenfolge und denselben vier Gruppen (**Festlegen**, **Erfassen**,
/// **Auswerten**, **Verwalten**). **Plan** und **HealthKit-Test** führen
/// irgendwohin (Task 14 liefert den eigentlichen HealthKit-Test-Zielschirm;
/// bis dahin je ein Platzhalter, aber der Weg über
/// `AppRouter.open(AppTarget.aktuell(...))` — auf den Stapel des *aktuell*
/// gewählten Tabs, nicht fest auf einen anderen Tab, siehe `CLAUDE.md`).
///
/// **Die Zeile „Plan" (task-navbar, 26.10.2026):** Der Tableisten-Umbau
/// nimmt dem Plan seinen eigenen Reiter (`docs/screens/components.js:158` —
/// „die Plätze waren voll"). `docs/screens/screens/mehr.js` setzt ihn
/// seitdem hier an die erste Stelle der Gruppe „Festlegen", vor „Ziele" —
/// „von allen hier ist er der, den man am häufigsten sucht". Die größere
/// Neuordnung des übrigen Mehr-Menüs, die `mehr.js` sonst noch zeigt
/// (neue Gruppennamen, gerechnete Untertitel), ist eine eigene Aufgabe
/// (#86, „Flutter · Mehr — das Menü") — hier wandert nur die eine
/// Zeile, die restlichen vier Gruppen bleiben unverändert.
///
/// Die übrigen acht Zeilen sind sichtbar, abgeblendet und sagen, dass sie
/// noch nicht da sind — eine Zeile, die aussieht wie ein Knopf und beim
/// Tippen schweigt, ist genau der Fehler, den `docs/screens/pruefen.mjs`
/// für die Web-Entwürfe eigens sucht.
///
/// **„Daten exportieren" fehlt bewusst** (`MoreView.swift:146`, `.export`):
/// Diese Flutter-App importiert Trainingsdaten, sie exportiert nichts — die
/// Zeile hätte hier keine Gegenstelle.
///
/// Bringt weder einen eigenen `Navigator` noch ein eigenes Scaffold mit —
/// den stellt `RootView` für den *Mehr*-Tab, parallel zu `PlatzhalterTab`
/// (Hausregel aus `CLAUDE.md`: „Eine Ansicht, die gepusht wird, bringt
/// niemals ihren eigenen Navigationsstapel mit").
class MehrView extends StatelessWidget {
  const MehrView({super.key, required this.router, this.zyklusAn = false});

  final AppRouter router;

  /// Ob die Zeile „Zyklus" steht (#573, Spec 7). Gelesen wird
  /// [zyklusAnProvider] **eine Ebene höher**, in [MehrSeite] — diese
  /// Klasse bleibt ohne `ref`: Drei bestehende Testdateien pumpen sie ohne
  /// `ProviderScope` (`mehr_view_test.dart`, `mehr_attribution_test.dart`,
  /// `vorlaeufige_werte_test.dart`), und eine `ConsumerWidget` an dieser
  /// Stelle machte sie alle rot.
  ///
  /// Vorgabe `false`: Der Kalender ist in der Vorbelegung aus
  /// ([ZyklusEinstellungen.vorbelegung]), und wer diese Ansicht ohne
  /// Behälter baut, bekommt denselben Stand.
  final bool zyklusAn;

  /// Der Name der Gruppe, an deren Ende „Zyklus einrichten" hängt.
  static const String _verwalten = 'Verwalten';

  static final List<(String, List<_Eintrag>)> _gruppen = [
    (
      'Festlegen',
      [
        const _Eintrag(
          ziel: MehrZiel.plan,
          titel: 'Plan',
          untertitel: 'Wochen und Phasen des Halbmarathon-Trainings',
          symbol: 'list.bullet',
          akzent: Palette.river2,
          istAktiv: true,
        ),
        // Erster Schnitt (#448 unter #404): nur die Auszeiten. Der
        // Untertitel sagt, was es schon gibt und was folgt (V18).
        const _Eintrag(
          ziel: MehrZiel.ziele,
          titel: 'Ziele',
          untertitel: 'Auszeiten eintragen — Wettkämpfe und Körperziel folgen',
          symbol: 'target',
          akzent: Palette.bib,
          istAktiv: true,
        ),
      ],
    ),
    (
      'Erfassen',
      [
        const _Eintrag(
          ziel: MehrZiel.aktivitaeten,
          titel: 'Aktivitäten',
          untertitel: 'Läufe, Gehen, Rad eintragen$_nochNichtHinweis',
          symbol: 'figure.run',
          akzent: Palette.river,
        ),
        // Scharfgeschaltet mit #477 (Scheibe 2): Der Schirm steht, und
        // diese Zeile führt unmittelbar aufs Formular — wer „Umfänge
        // messen" wählt, hat das Maßband in der Hand und will nicht erst
        // eine Übersicht durchqueren (Plan, Task 2.4).
        const _Eintrag(
          ziel: MehrZiel.umfaengeMessen,
          titel: 'Umfänge messen',
          untertitel: 'Maße mit dem Maßband erfassen',
          symbol: 'ruler',
          akzent: Palette.summer,
          istAktiv: true,
        ),
      ],
    ),
    (
      'Auswerten',
      [
        const _Eintrag(
          ziel: MehrZiel.koerper,
          titel: 'Körper',
          untertitel: 'Muskelkarte, Schritte, Messungen, Umfänge',
          symbol: 'figure.arms.open',
          akzent: Palette.iron,
          istAktiv: true,
        ),
        const _Eintrag(
          ziel: MehrZiel.erholung,
          titel: 'Erholung',
          untertitel: 'Ampel, Schlaf-Score und Verläufe',
          symbol: 'moon.zzz',
          akzent: Palette.bib,
          istAktiv: true,
        ),
        const _Eintrag(
          ziel: MehrZiel.ausdauer,
          titel: 'Ausdauer',
          untertitel: 'VO₂max, HM-Prognose und Herzfrequenz-Zonen',
          symbol: 'heart',
          akzent: Palette.ok,
          istAktiv: true,
        ),
        const _Eintrag(
          ziel: MehrZiel.coach,
          titel: 'Coach',
          untertitel: 'Hinweise zu Training und Erholung$_nochNichtHinweis',
          symbol: 'checkmark.seal',
          akzent: Palette.warn,
        ),
      ],
    ),
    (
      'Verwalten',
      [
        const _Eintrag(
          ziel: MehrZiel.datenUndEinstellungen,
          titel: 'Daten & Einstellungen',
          untertitel:
              'Betrachtungszeitraum und Daten neu lesen$_nochNichtHinweis',
          symbol: 'gearshape',
          akzent: Palette.muted,
        ),
        const _Eintrag(
          ziel: MehrZiel.datenUebernehmen,
          titel: 'Daten übernehmen',
          untertitel: 'Gym-Trainings aus der alten App einlesen',
          symbol: 'square.and.arrow.down',
          akzent: Palette.river,
          istAktiv: true,
        ),
        const _Eintrag(
          ziel: MehrZiel.healthKitTest,
          titel: 'HealthKit-Test',
          untertitel: 'Rohwerte aus Apple Health prüfen',
          symbol: 'stethoscope',
          akzent: Palette.deep,
          istAktiv: true,
        ),
        const _Eintrag(
          ziel: MehrZiel.vorlaeufigeWerte,
          titel: 'Vorläufige Werte',
          untertitel: 'Zielgewicht und Zieldatum eintragen',
          symbol: 'scalemass',
          akzent: Palette.bib,
          istAktiv: true,
        ),
        // Untertitel ohne Zahlen, wie alle hier: Die Zeile im Entwurf
        // (`einstellungen.js`, „Gemini-Schlüssel") rechnet Status und
        // Verbrauch hinein; das kommt mit dem Einstellungs-Schirm.
        const _Eintrag(
          ziel: MehrZiel.kiZugang,
          titel: 'KI-Zugang',
          untertitel: 'Gemini-Schlüssel, Modell und Verbrauch',
          symbol: 'checkmark.seal',
          akzent: Palette.bib,
          istAktiv: true,
        ),
      ],
    ),
  ];

  void _oeffnePlan() {
    router.open(AppTarget.aktuell((context) => const _PlanPlatzhalter()));
  }

  /// Der Eingang in den Körper-Schirm (#82) — die Drehscheibe für alles,
  /// was am Körper gemessen wird. Über `oeffneKoerper`, der einen Stelle,
  /// die weiß, dass auf den Stapel des aktuell gewählten Tabs geschoben
  /// wird.
  void _oeffneKoerper() => oeffneKoerper(router);

  /// Der erste der beiden Eingänge in den Erholung-Schirm (#115); der
  /// zweite ist die Erholungskarte auf Heute. Beide laufen über
  /// `oeffneErholung` — der einen Stelle, die weiß, dass auf den Stapel des
  /// aktuell gewählten Tabs geschoben wird.
  void _oeffneErholung() => oeffneErholung(router);

  /// Der Eingang in den Ausdauer-Schirm (#95, mit #16). Über
  /// `oeffneAusdauer` — auf den Stapel des aktuell gewählten Tabs.
  void _oeffneAusdauer() => oeffneAusdauer(router);

  /// Der Eingang in den Ziele-Schirm, erster Schnitt mit den Auszeiten
  /// (#448 unter #404). Über `oeffneZiele` — auf den Stapel des aktuell
  /// gewählten Tabs.
  void _oeffneZiele() => oeffneZiele(router);

  /// Der eine Eingang, der unmittelbar ins Formular führt (#477). Über
  /// `oeffneUmfaengeEintragen` — auf den Stapel des aktuell gewählten Tabs.
  void _oeffneUmfaengeMessen() => oeffneUmfaengeEintragen(router);

  void _oeffneHealthKitTest() {
    router.open(AppTarget.aktuell((context) => const _HealthKitTestSeite()));
  }

  /// Der einzige Eingang in „Vorläufige Werte" (#307) — der Schirm für
  /// Zielgewicht und Zieldatum, solange der Erststart (#102, #103) sie noch
  /// nicht abfragt. Er steht hier unter „Verwalten", neben dem
  /// HealthKit-Test: Dort liegt, was man einmal braucht und nicht täglich.
  ///
  /// **Eine benannte Abweichung vom Entwurfsboard:** Dort hängt er unter
  /// „Einstellungen" (`docs/screens/screens/vorlaeufige-werte.js`,
  /// `parent: 'einstellungen'`). Den Einstellungs-Schirm gibt es im
  /// Flutter-Neubau noch nicht; das Board nennt diese Abweichung selbst.
  void _oeffneVorlaeufigeWerte() => oeffneVorlaeufigeWerte(router);

  /// Der Eingang in den KI-Zugang (#339) — Gemini-Schlüssel, Modell und
  /// Verbrauch. **Dieselbe benannte Abweichung wie bei „Vorläufige
  /// Werte":** Das Board hängt ihn unter Mehr › Einstellungen
  /// (`docs/screens/screens/einstellungen.js`, `ki-zugang.js`); den
  /// Einstellungs-Schirm gibt es im Flutter-Neubau noch nicht.
  void _oeffneKiZugang() => oeffneKiZugang(router);

  /// Der Eingang in „Daten übernehmen" (#59 Teil 1) — Gym-Trainings aus der
  /// Exportdatei der alten App. **Dieselbe benannte Abweichung wie bei
  /// „Vorläufige Werte":** Das Board hängt den Schirm unter Mehr ›
  /// Einstellungen (`docs/screens/screens/import.js`); den Einstellungs-
  /// Schirm gibt es im Flutter-Neubau noch nicht. Über `oeffneUebernahme`,
  /// die eine Stelle, die weiß, dass auf den Stapel des aktuell gewählten
  /// Tabs geschoben wird.
  void _oeffneUebernahme() => oeffneUebernahme(router);

  /// Der Tipp-Handler je Zeile — eine Stelle statt eines Felds mit
  /// Funktionstyp auf `_Eintrag`: Jede `_Eintrag`-Instanz in `_gruppen` ist
  /// `const`, kann also keine an `router`/`this` gebundene Closure tragen.
  VoidCallback? _handlerFuer(MehrZiel ziel) => switch (ziel) {
    MehrZiel.plan => _oeffnePlan,
    MehrZiel.ziele => _oeffneZiele,
    MehrZiel.umfaengeMessen => _oeffneUmfaengeMessen,
    MehrZiel.koerper => _oeffneKoerper,
    MehrZiel.erholung => _oeffneErholung,
    MehrZiel.ausdauer => _oeffneAusdauer,
    MehrZiel.healthKitTest => _oeffneHealthKitTest,
    MehrZiel.vorlaeufigeWerte => _oeffneVorlaeufigeWerte,
    MehrZiel.kiZugang => _oeffneKiZugang,
    MehrZiel.datenUebernehmen => _oeffneUebernahme,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    // `padding` statt einer äußeren `Padding` — aus demselben Grund wie in
    // `HeuteView`: `GlasAbstand.of(context)` rückt den Inhalt von der
    // durchscheinenden Navigations- und Tableiste ab, ohne den
    // Scroll-Viewport selbst zu verkleinern. Vorher endete die letzte
    // Zeile („HealthKit-Test") unerreichbar unter der Tableiste samt (+)
    // (task-layout-fixes, Fehler 3).
    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (titel, eintraege) in _gruppen) ...[
            SectionHeader(titel),
            InsetCard(
              child: _gruppenSpalte(context, [
                for (final eintrag in eintraege) ...[
                  // „Zyklus" steht in „Auswerten", vor „Coach"
                  // (`docs/screens/screens/mehr.js`).
                  if (eintrag.ziel == MehrZiel.coach && zyklusAn)
                    _zyklusZeile(),
                  _zeile(eintrag),
                ],
                if (titel == _verwalten) _zyklusEinrichtenZeile(),
              ]),
            ),
          ],
          // Die Fußzeile ist der Zugang zum Änderungsblatt (#89): Die
          // Versionsnummer allein beantwortet „was ist neu" nicht —
          // Antippen öffnet das Blatt. Endgültig wandert der Zugang
          // zusätzlich in die Einstellungen, sobald es sie im Neubau gibt.
          FassungsFusszeile(router: router),
        ],
      ),
    );
  }

  Widget _gruppenSpalte(BuildContext context, List<Widget> zeilen) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Column(
      children: [
        for (var i = 0; i < zeilen.length; i++) ...[
          zeilen[i],
          if (i < zeilen.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Container(height: 1, color: line),
            ),
        ],
      ],
    );
  }

  /// Die Zeile „Zyklus" (#573) — **nur, wenn der Kalender eingeschaltet
  /// ist** (Spec 7). Was aus ist, verschwindet ganz; ein abgeblendeter
  /// Eintrag sähe aus wie etwas, das noch kommt (`mehr.js`).
  ///
  /// **Untertitel ohne Zahlen**, wie bei jeder Zeile hier: Der Entwurf
  /// rechnet dort „Zyklustag 12 · nächste Blutung ab 3.12." hinein, und
  /// das wären Tims Werte im Quelltext dieser Zeile (`CLAUDE.md`,
  /// dieselbe Begründung wie bei „Umfänge messen" und „KI-Zugang").
  Widget _zyklusZeile() => IconRow(
    key: const Key('mehr-zyklus'),
    title: zyklusMehrZeile,
    subtitle: zyklusMehrUnterzeile,
    symbol: 'drop',
    accent: Palette.blut,
    onTap: () => oeffneZyklus(router),
  );

  /// Die Zeile „Zyklus einrichten" (#573) — **immer da**, auch bei
  /// ausgeschaltetem Kalender: Sie ist der einzige Ort, an dem er sich
  /// einschalten lässt, und darf deshalb nicht an seinem eigenen Schalter
  /// hängen.
  ///
  /// **Dieselbe benannte Abweichung wie bei „Vorläufige Werte":** Das
  /// Board hängt den Schirm unter Mehr › Einstellungen
  /// (`zyklus-einrichten.js`, `parent: 'einstellungen'`); den
  /// Einstellungs-Schirm gibt es im Flutter-Neubau noch nicht.
  Widget _zyklusEinrichtenZeile() => IconRow(
    key: const Key('mehr-zyklus-einrichten'),
    title: zyklusEinrichtenZeile,
    subtitle: zyklusEinrichtenUnterzeile,
    symbol: 'gearshape',
    accent: Palette.blut,
    onTap: () => oeffneZyklusEinrichten(router),
  );

  Widget _zeile(_Eintrag eintrag) {
    final row = IconRow(
      title: eintrag.titel,
      subtitle: eintrag.untertitel,
      symbol: eintrag.symbol,
      accent: eintrag.akzent,
      onTap: _handlerFuer(eintrag.ziel),
    );

    if (eintrag.istAktiv) return row;

    return Opacity(opacity: 0.5, child: row);
  }
}

/// Das *Mehr*-Menü mit dem einen Stand, den es aus Providern braucht
/// (#573): ob der Zykluskalender eingeschaltet ist.
///
/// **Eine eigene Hülle und keine `ConsumerWidget` aus [MehrView]:** Drei
/// bestehende Testdateien pumpen [MehrView] ohne `ProviderScope`, und ein
/// `ref` in ihr machte sie alle rot. Hier liest es eine Ebene höher — die
/// Stelle, die `RootView` baut und die immer in einem Behälter steht.
///
/// Bringt weder `Navigator` noch Scaffold mit, genau wie [MehrView].
class MehrSeite extends ConsumerWidget {
  const MehrSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      MehrView(router: router, zyklusAn: ref.watch(zyklusAnProvider));
}

/// Platzhalter für den Plan-Schirm — der eigentliche Schirm (Spec 9.1,
/// Diagramm-Startseite mit Wochen und Phasen) ist nicht Teil von
/// task-navbar. Bis dahin reicht ein ehrlicher Hinweis statt eines leeren
/// oder fehlerhaft aussehenden Schirms, parallel zu
/// `_HealthKitTestPlatzhalter`.
///
/// Eigenes `CupertinoPageScaffold`, aber **kein** eigener `Navigator`:
/// Diese Ansicht wird auf den Stapel des *aktuell* gewählten Tabs
/// geschoben (siehe `_oeffnePlan`), der Stapel selbst gehört weiter
/// `RootView`.
class _PlanPlatzhalter extends StatelessWidget {
  const _PlanPlatzhalter();

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Plan')),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Dieser Bereich ist noch nicht fertig. Der Trainingsplan '
                'mit Wochen und Phasen kommt in einer späteren Aufgabe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.35, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hängt den echten HealthKit-Test-Schirm ([HealthKitTestView]) in Rahmen
/// ein — `CupertinoPageScaffold` und Navigationsleiste stellt diese Stelle,
/// nicht [HealthKitTestView] selbst (Hausregel, siehe dessen
/// Klassenkommentar): Ein `router.open(AppTarget.aktuell(...))`-Push landet
/// direkt im `Navigator` des Tabs, ohne dass der Router selbst einen Rahmen
/// mitgibt — anders als die vier Tab-Wurzeln, die `RootView._tabSeite`
/// einrahmt.
///
/// **Kein** eigener `Navigator`: Diese Ansicht wird auf den Stapel des
/// *Mehr*-Tabs geschoben (siehe `_oeffneHealthKitTest`), der Stapel selbst
/// gehört weiter `RootView`.
class _HealthKitTestSeite extends StatelessWidget {
  const _HealthKitTestSeite();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('HealthKit-Test'),
      ),
      child: const HealthKitTestView(),
    );
  }
}
