// Das Änderungsblatt — „Was ist neu" (#89).
//
// Spec: `docs/superpowers/specs/2026-11-19-aenderungsblatt-design.md`,
// Abschnitt „Was der Test-Agent prüft", Prüffälle 1–4. Entwurf:
// `docs/screens/screens/aenderungen.js` (Freigabe Tim, 19.11.2026).
// Prüffall 5 (Wächtertest auf die echte Datei) steht in
// `test/aenderungen_datei_test.dart`.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden. Sie ist vor der
// Implementierung entstanden und zunächst rot (sie kompiliert nicht einmal,
// solange `lib/shell/aenderungen.dart` fehlt) — das ist Absicht.
//
// ## Festgelegte API, an die sich die Implementierung halten muss
//
// `app/lib/shell/aenderungen.dart` exportiert (vereinbarter Vertrag, der
// auch dem Implementierungs-Agenten vorliegt):
//
// - `class AenderungsEintrag { final String titel; final String text;
//   final String? ziel; }` — hier mit benannten Parametern konstruiert
//   (`AenderungsEintrag(titel: …, text: …, ziel: …)`), `ziel` optional.
// - `class Fassung { final String fassung; final String? stand;
//   final List<AenderungsEintrag> eintraege; }` — benannte Parameter,
//   `stand` optional.
// - `final aenderungenProvider = Provider<List<Fassung>>(…)` — in Tests per
//   `overrideWithValue` durch eine Testliste ersetzt.
// - `AppTarget? zielZuAppTarget(String ziel)` — unbekanntes Ziel → `null`.
// - `class AenderungsBlatt extends ConsumerWidget` — der Blatt-Inhalt; die
//   Tests finden das offene Blatt über `find.byType(AenderungsBlatt)` und
//   binden sich sonst nicht an seine innere Struktur.
// - Die Fußzeile liegt in `MehrView` und zeigt `Fassung <erste fassung>` —
//   den Wortlaut legt der Vertrag fest, deshalb darf `find.text(…)` ihn hier
//   ausnahmsweise exakt suchen (er ist der Tippbereich, keine Dekoration).
//
// Passt die Implementierung nicht zu einer dieser Annahmen (z. B. andere
// Konstruktorform), wird das **gemeldet, nicht der Test umgebogen**.
//
// ## Was absichtlich nicht geprüft wird
//
// - Wortlaut der Blatt-Überschrift, Darstellung des `stand`, Kartenform,
//   Winkel-Glyphe — Layout und Beschriftung, nicht Zustand (`CLAUDE.md`).
//   Ob ein Eintrag antippbar ist, wird strukturell geprüft (Tipp-Handler
//   im Baum), nicht am gezeichneten Winkel.
// - Kein Leerzustand: Das Blatt hat laut Spec genau einen Zustand; eine
//   leere Liste ist ein Programmierfehler, den der Wächtertest fängt.
//
// ## Erfundene Inhalte
//
// Alle Fassungsnamen, Titel, Sätze und `stand`-Werte unten sind erfunden
// (v9.x, 2031) — keine echten Gesundheits-/Trainingsdaten, kein echtes
// Ereignis-Datum. Als `ziel` benutzt der Test `'ernaehrung'`: das einzige
// Ziel, das die Spec selbst (Abschnitt „Die Datei", Beispiel) als Eintrag
// der Zuordnungstabelle vorgibt; ein eigener Fall nagelt das unten fest.

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/aenderungen.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';

/// Protokolliert jeden `open(…)`-Aufruf, bevor er normal weiterläuft.
///
/// Prüffall 4 verlangt, dass ein Eintrag mit `ziel` „einen Befehl am
/// `AppRouter` absetzt". `nimmBefehl()` allein sieht aber nur Push-Ziele
/// (`AppTarget.aktuell`/`.detail` tragen einen `builder`); ein reiner
/// Tab-Fall wie `AppTarget.ernaehrung()` hinterlässt keinen Befehl, sondern
/// wechselt `tab`. Die Zuordnungstabelle gehört der Implementierung — dieser
/// Test legt nicht fest, welche der beiden Formen `'ernaehrung'` ergibt,
/// und prüft deshalb die Hausregel selbst: Der Sprung läuft über
/// `AppRouter.open(…)`, nicht an ihm vorbei. Zusätzlich wird unten
/// festgehalten, dass der Aufruf auch am normalen Router-Zustand ablesbar
/// ist (Befehl **oder** Tab-Wechsel).
class _ProtokollRouter extends AppRouter {
  final List<AppTarget> geoeffnet = [];

  @override
  void open(AppTarget target) {
    geoeffnet.add(target);
    super.open(target);
  }
}

void main() {
  /// Zwei erfundene Fassungen, neueste zuerst — die Normalform der Datei.
  ///
  /// Der erste Eintrag trägt ein `ziel`, der zweite keins: Beide Zweige von
  /// Prüffall 4 kommen aus derselben Liste. Die zweite Fassung hat keinen
  /// `stand` — er ist laut Spec optional, und das Blatt muss auch ohne ihn
  /// bauen.
  List<Fassung> zweiFassungen() => [
    Fassung(
      fassung: 'v9.9',
      stand: '2031-01-02',
      eintraege: [
        AenderungsEintrag(
          titel: 'Erfundene Suche',
          text: 'Ein erfundener Satz, den auch Nicht-Informatiker verstehen.',
          ziel: 'ernaehrung',
        ),
        AenderungsEintrag(
          titel: 'Erfundene Striche',
          text: 'Ein erfundener Satz ohne Sprungziel.',
        ),
      ],
    ),
    Fassung(
      fassung: 'v9.8',
      eintraege: [
        AenderungsEintrag(
          titel: 'Erfundenes Vollbild',
          text: 'Noch ein erfundener Satz.',
        ),
      ],
    ),
  ];

  /// Dieselben zwei Fassungen, absichtlich verkehrt herum (ältere zuerst).
  ///
  /// Die Spec sagt: „Die Reihenfolge der Datei ist die Reihenfolge im Blatt
  /// — es wird nicht sortiert" und „Die laufende Fassung ist der erste
  /// Eintrag". Eine Implementierung, die nach Fassungsnamen sortiert, fällt
  /// nur mit einer unsortierten Eingabe auf.
  List<Fassung> verkehrtHerum() => [
    Fassung(
      fassung: 'v9.8',
      eintraege: [
        AenderungsEintrag(
          titel: 'Erfundenes Vollbild',
          text: 'Noch ein erfundener Satz.',
        ),
      ],
    ),
    Fassung(
      fassung: 'v9.9',
      stand: '2031-01-02',
      eintraege: [
        AenderungsEintrag(
          titel: 'Erfundene Suche',
          text: 'Ein erfundener Satz, den auch Nicht-Informatiker verstehen.',
          ziel: 'ernaehrung',
        ),
      ],
    ),
  ];

  /// Baut die Mehr-Seite mit eingeschleuster Testliste auf.
  ///
  /// `UncontrolledProviderScope` + `ProviderContainer(retry: (_, _) => null)`
  /// ist die Hauskonvention (CLAUDE.md: In Tests wird Riverpods Wiederholung
  /// abgeschaltet). Die große Testfläche macht die Fußzeile ohne Scrollen
  /// erreichbar — bei einer lazy bauenden Liste existierte sie sonst gar
  /// nicht erst.
  Future<void> pumpMehr(
    WidgetTester tester, {
    required List<Fassung> fassungen,
    required AppRouter router,
  }) async {
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [aenderungenProvider.overrideWithValue(fassungen)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: MehrView(router: router)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Öffnet das Blatt über die Fußzeile — der einzige Zugang laut Spec.
  Future<void> oeffneBlatt(WidgetTester tester, String fusszeile) async {
    await tester.tap(find.text(fusszeile));
    await tester.pumpAndSettle();
    expect(
      find.byType(AenderungsBlatt),
      findsOneWidget,
      reason: 'Antippen der Fußzeile muss das Änderungsblatt öffnen.',
    );
  }

  /// Ein Finder, der nur **im Blatt** sucht — die Mehr-Seite darunter zeigt
  /// die laufende Fassung ebenfalls (Fußzeile), und die soll hier nicht
  /// mitzählen.
  Finder imBlatt(Finder matching) =>
      find.descendant(of: find.byType(AenderungsBlatt), matching: matching);

  /// `true`, wenn ein Vorfahre von [finder] ein `GestureDetector` mit
  /// gesetztem `onTap` oder ein `CupertinoButton` mit gesetztem `onPressed`
  /// ist — dieselbe strukturelle Tippbarkeitsprüfung wie in
  /// `mehr_view_test.dart` (rein-Cupertino-App, kein `material.dart`).
  /// Reicht die Implementierung onTap über ein anderes Widget durch, bitte
  /// melden statt den Test umzuschreiben.
  bool hatTippbarenVorfahren(WidgetTester tester, Finder finder) {
    final vorfahren = tester.widgetList(
      find.ancestor(of: finder, matching: find.byWidgetPredicate((_) => true)),
    );
    for (final vorfahre in vorfahren) {
      if (vorfahre is GestureDetector && vorfahre.onTap != null) return true;
      if (vorfahre is CupertinoButton && vorfahre.onPressed != null) {
        return true;
      }
    }
    return false;
  }

  group('Prüffall 1 — die Mehr-Fußzeile', () {
    testWidgets('zeigt die Fassung aus dem ersten Eintrag der Liste', (
      tester,
    ) async {
      await pumpMehr(tester, fassungen: zweiFassungen(), router: AppRouter());

      expect(
        find.text('Fassung v9.9'),
        findsOneWidget,
        reason:
            'Die Fußzeile zeigt „Fassung <erste fassung>" — die eine Quelle '
            'des Fassungsnamens ist der erste Eintrag der Datei.',
      );
      expect(
        find.textContaining('v9.8'),
        findsNothing,
        reason:
            'Ältere Fassungen gehören ins Blatt, nicht auf die Mehr-Seite.',
      );
    });

    testWidgets('ist nicht hartcodiert — eine andere Liste, eine andere Zeile', (
      tester,
    ) async {
      // Hier steht v9.8 vorn (verkehrtHerum) — die Fußzeile muss dem ersten
      // Eintrag folgen, nicht dem größten Fassungsnamen und keinem fest
      // einprogrammierten Wert.
      await pumpMehr(tester, fassungen: verkehrtHerum(), router: AppRouter());

      expect(
        find.text('Fassung v9.8'),
        findsOneWidget,
        reason:
            'Die laufende Fassung ist der ERSTE Eintrag der Liste — auch '
            'dann, wenn ein anderer Name „neuer" aussähe.',
      );
      expect(find.text('Fassung v9.9'), findsNothing);
    });
  });

  group('Prüffall 2 — Öffnen, „Fertig", und die Mehr-Seite danach', () {
    testWidgets('Antippen der Fußzeile öffnet das Blatt', (tester) async {
      await pumpMehr(tester, fassungen: zweiFassungen(), router: AppRouter());

      expect(find.byType(AenderungsBlatt), findsNothing);
      await oeffneBlatt(tester, 'Fassung v9.9');
    });

    testWidgets(
      '„Fertig" schließt das Blatt; die Mehr-Seite steht wieder so da wie vorher',
      (tester) async {
        // Regel `32` aus CLAUDE.md: Ein Wert, der dastand, steht nach dem
        // Zurücknavigieren wieder da.
        final router = AppRouter();
        final tabVorher = router.tab;
        await pumpMehr(tester, fassungen: zweiFassungen(), router: router);

        // Zwei Anker von vorher: die Fußzeile selbst und eine bekannte
        // Menüzeile.
        expect(find.text('Fassung v9.9'), findsOneWidget);
        expect(find.text('Plan'), findsOneWidget);

        await oeffneBlatt(tester, 'Fassung v9.9');
        await tester.tap(imBlatt(find.text('Fertig')));
        await tester.pumpAndSettle();

        expect(
          find.byType(AenderungsBlatt),
          findsNothing,
          reason: '„Fertig" muss das Blatt schließen.',
        );
        expect(
          find.text('Fassung v9.9'),
          findsOneWidget,
          reason: 'Die Fußzeile steht nach dem Schließen wieder da.',
        );
        expect(
          find.text('Plan'),
          findsOneWidget,
          reason: 'Die Mehr-Seite steht nach dem Schließen unverändert da.',
        );
        expect(
          router.nimmBefehl(),
          isNull,
          reason:
              'Öffnen und Schließen des Blatts sind keine Navigation über '
              'den AppRouter — „Fertig" darf keinen Befehl hinterlassen.',
        );
        expect(
          router.tab,
          tabVorher,
          reason: '„Fertig" wechselt keinen Tab.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Prüffall 3 — Inhalt des Blatts', () {
    testWidgets('je Eintrag stehen Titel und Satz im Blatt', (tester) async {
      await pumpMehr(tester, fassungen: zweiFassungen(), router: AppRouter());
      await oeffneBlatt(tester, 'Fassung v9.9');

      const erwartet = [
        'Erfundene Suche',
        'Ein erfundener Satz, den auch Nicht-Informatiker verstehen.',
        'Erfundene Striche',
        'Ein erfundener Satz ohne Sprungziel.',
        'Erfundenes Vollbild',
        'Noch ein erfundener Satz.',
      ];
      for (final text in erwartet) {
        expect(
          imBlatt(find.text(text)),
          findsOneWidget,
          reason: '"$text" muss im Blatt stehen (Titel bzw. der eine Satz).',
        );
      }
    });

    testWidgets('zeigt die Fassungen in Dateireihenfolge — es wird nicht sortiert', (
      tester,
    ) async {
      // Absichtlich die unsortierte Liste: v9.8 steht in der Datei VORN und
      // muss deshalb auch im Blatt OBEN stehen. Eine Implementierung, die
      // nach Fassungsnamen sortiert, kippt hier.
      await pumpMehr(tester, fassungen: verkehrtHerum(), router: AppRouter());
      await oeffneBlatt(tester, 'Fassung v9.8');

      // Die Reihenfolge wird über die Bildschirmposition geprüft, nicht über
      // die Baumstruktur — und über die Einträge, nicht die Überschriften:
      // Deren genauer Wortlaut („Fassung v9.8 · …") ist Beschriftung und
      // bleibt frei. Jeder Fassung gehört genau ein Eintragstitel, also
      // trägt die Position der Titel dieselbe Aussage.
      final obererTitel = tester.getTopLeft(
        imBlatt(find.text('Erfundenes Vollbild')),
      );
      final untererTitel = tester.getTopLeft(
        imBlatt(find.text('Erfundene Suche')),
      );

      expect(
        obererTitel.dy,
        lessThan(untererTitel.dy),
        reason:
            'Die Fassung, die in der Liste zuerst steht (v9.8 mit '
            '„Erfundenes Vollbild"), muss im Blatt über der zweiten (v9.9 '
            'mit „Erfundene Suche") stehen — Dateireihenfolge, keine '
            'Sortierung.',
      );
    });

    testWidgets('innerhalb einer Fassung stehen die Einträge in Reihenfolge', (
      tester,
    ) async {
      await pumpMehr(tester, fassungen: zweiFassungen(), router: AppRouter());
      await oeffneBlatt(tester, 'Fassung v9.9');

      final positionen = [
        'Erfundene Suche',
        'Erfundene Striche',
        'Erfundenes Vollbild',
      ].map((titel) => tester.getTopLeft(imBlatt(find.text(titel))).dy).toList();
      final sortiert = [...positionen]..sort();

      expect(
        positionen,
        sortiert,
        reason:
            'Die Einträge stehen von oben nach unten in Dateireihenfolge — '
            'nach Wirkung sortiert ist die DATEI, nicht das Blatt.',
      );
    });
  });

  group('Prüffall 4 — Sprungziel', () {
    testWidgets(
      'ein Eintrag mit ziel schließt das Blatt und öffnet über den AppRouter',
      (tester) async {
        final router = _ProtokollRouter();
        final tabVorher = router.tab;
        await pumpMehr(tester, fassungen: zweiFassungen(), router: router);
        await oeffneBlatt(tester, 'Fassung v9.9');

        expect(
          hatTippbarenVorfahren(tester, imBlatt(find.text('Erfundene Suche'))),
          isTrue,
          reason: 'Ein Eintrag mit ziel muss tippbar sein.',
        );

        await tester.tap(imBlatt(find.text('Erfundene Suche')));
        await tester.pumpAndSettle();

        expect(
          router.geoeffnet,
          hasLength(1),
          reason:
              'Der Sprung läuft über AppRouter.open(…) — Views setzen weder '
              'Tab noch Pfad direkt (Hausregel).',
        );
        expect(
          find.byType(AenderungsBlatt),
          findsNothing,
          reason: 'Antippen eines Eintrags mit ziel schließt das Blatt.',
        );
        // Und der Aufruf ist am Router-Zustand ablesbar — als abholbarer
        // Befehl (Push-Ziel, nimmBefehl) oder als Tab-Wechsel (Tab-Ziel).
        // Welche der beiden Formen die Zuordnungstabelle für 'ernaehrung'
        // wählt, gehört der Implementierung; siehe Kommentar an
        // _ProtokollRouter.
        final befehl = router.nimmBefehl();
        expect(
          befehl != null || router.tab != tabVorher,
          isTrue,
          reason:
              'Nach dem Tipp muss der Router etwas zu tun haben: ein Befehl '
              'liegt zur Abholung bereit oder der Tab hat gewechselt — ein '
              'open(…), das beides nicht bewirkt, hat nicht navigiert.',
        );
      },
    );

    testWidgets('ein Eintrag ohne ziel tut beim Antippen nichts', (
      tester,
    ) async {
      final router = _ProtokollRouter();
      await pumpMehr(tester, fassungen: zweiFassungen(), router: router);
      await oeffneBlatt(tester, 'Fassung v9.9');

      expect(
        hatTippbarenVorfahren(tester, imBlatt(find.text('Erfundene Striche'))),
        isFalse,
        reason:
            'Ein Eintrag ohne ziel ist reine Anzeige — kein Tipp-Handler '
            '(der Winkel folgt der Tür).',
      );

      await tester.tap(
        imBlatt(find.text('Erfundene Striche')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(AenderungsBlatt),
        findsOneWidget,
        reason: 'Das Blatt bleibt offen — der Tipp war keine Handlung.',
      );
      expect(
        router.geoeffnet,
        isEmpty,
        reason: 'Ein Eintrag ohne ziel löst keine Navigation aus.',
      );
      expect(router.nimmBefehl(), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('Die Zuordnungstabelle', () {
    test('zielZuAppTarget liefert null für ein unbekanntes Ziel', () {
      expect(
        zielZuAppTarget('voellig-unbekanntes-testziel'),
        isNull,
        reason:
            'Ein unbekanntes ziel ist ein Programmierfehler, kein '
            'Laufzeitfall — die Funktion wirft nicht, sie liefert null, und '
            'der Wächtertest macht daraus einen roten Build.',
      );
    });

    test('kennt das Ziel aus dem Spec-Beispiel ("ernaehrung")', () {
      // Die Spec gibt in ihrem Dateibeispiel genau ein ziel vor:
      // "ernaehrung". Dieser Fall ankert die Tabelle daran — und sichert
      // zugleich, dass der Prüffall-4-Test oben ein echtes Ziel benutzt.
      expect(
        zielZuAppTarget('ernaehrung'),
        isNotNull,
        reason:
            'Das ziel "ernaehrung" aus dem Spec-Beispiel muss in der '
            'Zuordnungstabelle stehen.',
      );
    });
  });
}
