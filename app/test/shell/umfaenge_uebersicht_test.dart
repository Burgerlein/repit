import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für die **Übersicht „Umfänge"** (#478 unter #88) —
/// `lib/koerper/umfaenge_view.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Entwurf `docs/screens/screens/umfaenge.js` (Varianten `werte`, `erste`,
/// `leer`, am 11.11.2026 um „Alle Messungen" ergänzt, `7ad3abf`) und
/// `docs/superpowers/plans/2026-11-11-umfaenge.md`, Task 2.3. Die
/// Übersicht ist am 11.11.2026 in Scheibe 2 vorgezogen worden, weil es
/// sonst keinen Ort gäbe, an dem Messungen als Liste stehen — Tim: „ich
/// muss irgendwo gespeicherte Datensätze andrücken und bearbeiten können."
/// Der einzige Weg zu einem alten Tag wäre sonst das Datumsfeld, und dafür
/// müsste man wissen, wann man gemessen hat.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Die vier Zusagen:
///
/// 1. **Jede Zeile in „Alle Messungen" trägt ihren eigenen Tag** und öffnet
///    ihn. Ohne das öffnen fünf Zeilen denselben Tag, und das sieht man dem
///    Schirm nicht an — es fällt erst auf, wenn ein falscher Tag
///    überschrieben ist.
/// 2. ~~**Die Maß-Zeilen öffnen in dieser Scheibe nichts.**~~ Abgelaufen
///    mit Scheibe 3 (#479): Seit dem 11.11.2026 öffnet jede Zeile den
///    Verlauf ihres Maßes, geprüft in `umfang_detail_test.dart`. Siehe
///    den Vermerk weiter unten, wo die beiden Fälle standen.
/// 3. **Drei Zustände, drei verschiedene Auskünfte** — und „noch nie
///    gemessen" ist etwas anderes als „erst einmal gemessen". Bei der
///    ersten Messung gibt es keinen Trend, also steht auch keine Null da.
/// 4. **Bei der Taille ist weniger der Fortschritt.** Ein Vorzeichen allein
///    färbt nichts ein.
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `umfaenge-uebersicht` | der Schirm selbst |
/// | `umfaenge-wichtig` | die Gruppe „Für dein Ziel am wichtigsten" |
/// | `umfaenge-uebrige` | die Gruppe „Übrige Maße" |
/// | `umfaenge-messungen` | die Gruppe „Alle Messungen" |
/// | `umfaenge-mass-<schluessel>` | je Maß die Zeile |
/// | `umfaenge-trend-<schluessel>` | je Maß die Veränderung darunter |
/// | `umfaenge-messung-<tag>` | je Messtag die Zeile, `<tag>` ISO |
/// | `umfaenge-erste` | der Hinweis „Erste Messung …" |
/// | `umfaenge-leer` | der Hinweis „Noch keine Umfänge erfasst …" |
/// | `umfaenge-eintragen-knopf` | „Maße eintragen" |
///
/// **`umfaenge-messung-<tag>` trägt den ISO-Tagesschlüssel**, nicht einen
/// laufenden Index. Das ist die Zusage aus Punkt 1, in einen Schlüssel
/// gegossen: Eine Zeile, die ihren Tag nicht kennt, kann ihn nicht öffnen.
///
/// **`umfaenge-trend-<schluessel>` sitzt auf dem Text der Veränderung**,
/// nicht auf der ganzen Zeile — sonst ließe sich „die Taille ist grün, wenn
/// sie fällt" nicht aussprechen, ohne über die Farbe des Maßnamens
/// mitzuentscheiden.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Der Weg auf die Übersicht läuft über `Körper › Umfänge`** und einen
///   Gastgeber, der die Befehle des `AppRouter` auf einen `Navigator`
///   schiebt — wie `RootView` es tut. So legt diese Datei weder
///   Klassennamen noch Konstruktor der Übersicht fest. Dass die Kachel
///   dorthin führt, prüft `umfaenge_tueren_test.dart`.
/// - **Die Reihenfolge der vier wichtigen Maße ist festgenagelt**, die der
///   elf übrigen nicht. Vier ist die Reihenfolge von `Umfang.values`,
///   gefiltert über `istWichtig` — dieselbe, die der Entwurf zeichnet. Für
///   die elf gibt weder Spec noch Entwurf einen Grund her, eine
///   Reihenfolge zu erzwingen; geprüft wird nur, dass **alle** darunter
///   stehen.
/// - **„Keine Null als Trend"** heißt hier: Im Zustand „erste Messung"
///   taucht nirgends ein `0,0`-Trend und nirgends das Wort „unverändert"
///   auf. Mit einem Punkt gibt es keine Veränderung, auch keine von null —
///   „unverändert" behauptete einen Vergleich, den es nicht gab.
/// - **Die Farbe wird aus dem gerenderten `RichText` gelesen**, nicht aus
///   einem `TextStyle` im Baum. Setzt die Ansicht gar keine Farbe, sind
///   beide Seiten `null` und die Fälle unten gehen durch — sie schlagen
///   gezielt bei dem einen Fehler an, um den es geht: `delta > 0` grün zu
///   färben und damit eine fallende Taille rot.
///
/// ## Was hier absichtlich **nicht** geprüft wird
///
/// - **Die Rechtecke der Keine-Daten-Ansicht gegen die der gefüllten.**
///   Eine leere Liste hat weniger Zeilen als eine volle; ein
///   Rechteckvergleich wäre dort nicht aussprechbar. Stattdessen wird
///   geprüft, dass **die Gruppe „Alle Messungen" in jedem Zustand
///   dasteht** — das ist der Teil der Regel, der hier greift: Sonst wüchse
///   der Schirm bei der ersten Messung um eine ganze Gruppe.
/// - **Der Zählerstand je Messzeile** („13 Maße"). Weder Spec noch Plan
///   legen ihn fest, und die Zahlen im Entwurf sind erfunden.
/// - Der Wortlaut von Hinweisen, Überschriften und Knöpfen, Farben als
///   Zahlen, Abstände.
///
/// ## Nachtrag (11.11.2026): zwei Löcher eine Ebene tiefer
///
/// Die erste Fassung dieser Datei hat `01` am **Grund-Kasten** abgefangen:
/// Während des Lesens steht weder „Noch keine Umfänge erfasst" noch „Erste
/// Messung". Darunter ging es weiter — die fünfzehn Maß-Zeilen sagten
/// „noch nicht gemessen" und „Alle Messungen" sagte „Noch keine Messung",
/// weil beide aus `gelesen == null` dieselbe leere Liste bekamen. Fünfzehn
/// Behauptungen über eine Datenlage, die noch niemand kennt.
///
/// Dazu ein zweites: Der sealed-Typ `UmfaengeUebersicht` hat **drei**
/// Fälle, die Ansicht unterschied nur `UebersichtGelesen` von „alles
/// andere". Nach einem gescheiterten Lesen stand „Wird gelesen …"
/// dauerhaft da, und nichts benannte den Fehler. Damit trug der sealed-Typ
/// nichts mehr — genau dafür gibt es in `Messwert<T>` den Unterschied
/// zwischen `LeerNachLauf` und `Fehlgeschlagen`.
///
/// Die beiden neuen Gruppen unten suchen deshalb **Muster**, keine
/// einzelnen Beschriftungen (`leerBehauptung`, `ladeBehauptung`): Welcher
/// Satz genau dasteht, ist Sache der Ansicht; dass er nichts über Tims
/// Daten behauptet, solange niemand sie kennt, ist es nicht. Dazu ein
/// neuer Schlüssel, `umfaenge-unlesbar`.
///
/// **Keine bestehende Erwartung ist verschoben** — die neuen Fälle stehen
/// daneben. Einer von ihnen ist eine Gegenprobe: Ist der Lauf durch, *muss*
/// die leere Auskunft kommen; der Ladefall darf sich nicht dadurch
/// erledigen lassen, dass sie ganz verschwindet.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag hier ist ausgedacht und liegt im Jahr 2099.
/// **Keine Zahl stammt aus `docs/screens/`** — die dortigen sind erfunden
/// und wären als Erwartungswert ein Scheinbeweis.
void main() {
  /// 12:00 Berliner Zeit am 15.03.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 3, 15, 11);
  const heute = '2099-03-15';
  const tagAlt = '2099-02-20';
  const tagMitte = '2099-03-01';
  const tagNeu = '2099-03-08';

  /// Wonach eine Aussage über Tims Datenlage klingt. Während gelesen wird
  /// und nachdem das Lesen gescheitert ist, darf nichts davon dastehen —
  /// weder im Grund-Kasten noch in einer der fünfzehn Zeilen noch unter
  /// „Alle Messungen".
  final leerBehauptung = RegExp(
    r'noch nicht gemessen|noch keine messung|noch keine umfänge|'
    r'erste messung|nichts gemessen|nichts erfasst|keine werte',
    caseSensitive: false,
  );

  /// Wonach „es läuft noch" klingt. Nach einem gescheiterten Lauf läuft
  /// nichts mehr.
  final ladeBehauptung = RegExp(
    r'wird gelesen|wird geladen|lädt',
    caseSensitive: false,
  );

  final uebersicht = find.byKey(const Key('umfaenge-uebersicht'));
  final formular = find.byKey(const Key('umfaenge-eintragen'));
  final wichtig = find.byKey(const Key('umfaenge-wichtig'));
  final uebrige = find.byKey(const Key('umfaenge-uebrige'));
  final messungen = find.byKey(const Key('umfaenge-messungen'));
  final ersteHinweis = find.byKey(const Key('umfaenge-erste'));
  final leerHinweis = find.byKey(const Key('umfaenge-leer'));
  final unlesbar = find.byKey(const Key('umfaenge-unlesbar'));
  final eintragenKnopf = find.byKey(const Key('umfaenge-eintragen-knopf'));
  final kachel = find.byKey(const Key('koerper-kachel-umfaenge'));

  Finder massZeile(Umfang mass) =>
      find.byKey(Key('umfaenge-mass-${mass.schluessel}'));
  Finder trend(Umfang mass) =>
      find.byKey(Key('umfaenge-trend-${mass.schluessel}'));
  Finder messZeile(String tag) => find.byKey(Key('umfaenge-messung-$tag'));
  Finder feld(Umfang mass) =>
      find.byKey(Key('umfaenge-feld-${mass.schluessel}'));

  /// Die vier aus „Für dein Ziel am wichtigsten", in der Reihenfolge des
  /// Kerns — nicht abgeschrieben, sondern abgeleitet: Käme ein fünftes
  /// dazu, zieht dieser Test mit, statt falsch zu werden.
  final vierWichtige = [
    for (final mass in Umfang.values)
      if (mass.istWichtig) mass,
  ];
  final elfUebrige = [
    for (final mass in Umfang.values)
      if (!mass.istWichtig) mass,
  ];

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> lege(String tag, Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: tag, werte: werte);

  /// Drei Messtage. Brust **steigt**, Taille **fällt** — beides ist
  /// Fortschritt, und genau daran hängt die letzte Gruppe.
  Future<void> dreiMesstage() async {
    await lege(tagAlt, {
      Umfang.oberarmRechtsAngespannt: 37.0,
      Umfang.oberarmLinksAngespannt: 36.6,
      Umfang.brust: 101.0,
      Umfang.taille: 86.0,
    });
    await lege(tagMitte, {Umfang.brust: 102.0, Umfang.taille: 85.0});
    await lege(tagNeu, {
      Umfang.oberarmRechtsAngespannt: 38.2,
      Umfang.oberarmLinksAngespannt: 37.8,
      Umfang.brust: 103.5,
      Umfang.taille: 84.0,
      Umfang.hals: 39.5,
    });
  }

  ProviderContainer behaelter({UmfaengeRepository? repo}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_Quelle()),
        if (repo != null) umfaengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Eine Sekunde in Zehntelschritten — für die Fälle, in denen nichts zur
  /// Ruhe kommen darf: Ein hängendes Lesen (und ein Ladezeichen, das sich
  /// dreht) brächte `pumpAndSettle` zum Überlaufen.
  Future<void> pumpe(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Der Gastgeber: der Körper-Schirm auf einem Navigator, der jeden
  /// Befehl des [AppRouter] schiebt — wie `RootView` es für den Stapel
  /// eines Tabs tut. Danach steht die Übersicht auf dem Stapel.
  Future<void> zeigeUebersicht(
    WidgetTester tester, {
    UmfaengeRepository? repo,
    bool warte = true,
  }) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    final router = AppRouter();
    void schiebe() {
      final befehl = router.nimmBefehl();
      if (befehl == null) return;
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: befehl.builder),
      );
    }

    router.addListener(schiebe);
    addTearDown(() => router.removeListener(schiebe));

    await tester.pumpWidget(
      BehaelterImBaum(
        container: behaelter(repo: repo),
        child: CupertinoApp(
          navigatorKey: navigator,
          home: CupertinoPageScaffold(child: KoerperView(router: router)),
        ),
      ),
    );
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      await pumpe(tester);
    }

    await tester.ensureVisible(kachel);
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      await pumpe(tester);
    }
    await tester.tap(kachel);
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      await pumpe(tester);
    }

    expect(
      uebersicht,
      findsOneWidget,
      reason: 'Körper › Umfänge führt auf die Übersicht (Plan, Task 2.4).',
    );
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    expect(ziel, findsOneWidget, reason: 'Siehe „Die Schlüssel" im Kopf.');
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  String textUnter(WidgetTester tester, Finder wurzel) => tester
      .widgetList<Text>(
        find.descendant(of: wurzel, matching: find.byType(Text), matchRoot: true),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Was im Feld des Formulars **steht**, zurückgelesen über die Prüfung
  /// des Kerns — so hängt kein Fall an der Schreibweise.
  double? wertImFeld(WidgetTester tester, Umfang mass) {
    final text = tester
        .widget<EditableText>(
          find.descendant(of: feld(mass), matching: find.byType(EditableText)),
        )
        .controller
        .text;
    return switch (UmfangsEingabe.parse(text)) {
      UmfangOk(:final zentimeter) => zentimeter,
      _ => null,
    };
  }

  /// Die gerenderte Farbe der Veränderungszeile eines Maßes.
  Color? trendFarbe(WidgetTester tester, Umfang mass) => tester
      .widget<RichText>(
        find
            .descendant(
              of: trend(mass),
              matching: find.byType(RichText),
              matchRoot: true,
            )
            .first,
      )
      .text
      .style
      ?.color;

  // ───────────────────────────────────────────────────────────────────────
  // „Alle Messungen" — eine Zeile je Messtag, und jede kennt ihren Tag
  // ───────────────────────────────────────────────────────────────────────

  group('„Alle Messungen"', () {
    testWidgets('eine Zeile je Messtag, die jüngste zuerst', (tester) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(messungen, findsOneWidget);
      for (final tag in [tagNeu, tagMitte, tagAlt]) {
        expect(messZeile(tag), findsOneWidget, reason: '$tag fehlt.');
      }
      expect(
        tester.getRect(messZeile(tagNeu)).top,
        lessThan(tester.getRect(messZeile(tagMitte)).top),
        reason: 'absteigend: die jüngste Messung steht oben',
      );
      expect(
        tester.getRect(messZeile(tagMitte)).top,
        lessThan(tester.getRect(messZeile(tagAlt)).top),
      );
    });

    testWidgets('ein Tag ohne Messung bekommt keine Zeile', (tester) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(
        messZeile('2099-03-05'),
        findsNothing,
        reason:
            'Gelistet werden Messtage, nicht Kalendertage — Umfänge misst '
            'man alle zwei bis vier Wochen',
      );
      expect(messZeile(heute), findsNothing);
    });

    testWidgets('ein Tipp öffnet das Formular für genau diesen Tag, mit '
        'dessen Werten', (tester) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      await tippe(tester, messZeile(tagMitte));

      expect(
        formular,
        findsOneWidget,
        reason:
            'Tim am 11.11.2026: „ich muss irgendwo gespeicherte Datensätze '
            'andrücken und bearbeiten können"',
      );
      expect(wertImFeld(tester, Umfang.brust), 102.0);
      expect(wertImFeld(tester, Umfang.taille), 85.0);
      expect(
        wertImFeld(tester, Umfang.hals),
        isNull,
        reason:
            'Am 01.03. wurde der Hals nicht gemessen — sein Feld bleibt '
            'leer, der Wert vom 20.02. steht höchstens blass dahinter',
      );
    });

    testWidgets('und zwei Zeilen öffnen zwei verschiedene Tage', (
      tester,
    ) async {
      // Der Fehler, gegen den das geschrieben ist: Alle Zeilen tragen
      // denselben Tag — zum Beispiel immer den jüngsten. Das sieht man dem
      // Schirm nicht an, es fällt erst auf, wenn ein falscher Tag
      // überschrieben ist.
      await dreiMesstage();

      await zeigeUebersicht(tester);
      await tippe(tester, messZeile(tagNeu));
      expect(wertImFeld(tester, Umfang.taille), 84.0);

      await zeigeUebersicht(tester);
      await tippe(tester, messZeile(tagAlt));
      expect(wertImFeld(tester, Umfang.taille), 86.0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Maß-Zeilen sind seit Scheibe 3 Türen
  // ───────────────────────────────────────────────────────────────────────
  //
  // **Hier standen zwei Fälle**, die das Gegenteil festhielten: „ein Tipp
  // auf ein Maß ändert nichts" und „keine Maß-Zeile trägt einen Winkel".
  // Beide waren ausdrücklich auf Scheibe 2 datiert („Den Verlauf je Maß
  // gibt es erst in Scheibe 3"), und genau die ist mit #479 dran. Sie sind
  // am 11.11.2026 vom Test-Agenten entfernt worden — nicht vom
  // Implementierenden, und nicht, weil sie unbequem geworden wären:
  // Stehen bleiben durften sie nicht, weil ein Test, der eine abgelaufene
  // Scheibe beschreibt, die nächste blockiert.
  //
  // Ihre Nachfolger stehen in `umfang_detail_test.dart`: Jede der
  // fünfzehn Zeilen öffnet den Verlauf **ihres** Maßes, und jede trägt
  // jetzt einen Winkel — der Winkel folgt der Tür (Tim, 27.10.2026).

  // ───────────────────────────────────────────────────────────────────────
  // Die vier wichtigen zuerst
  // ───────────────────────────────────────────────────────────────────────

  group('Die vier wichtigen Maße stehen zuerst', () {
    testWidgets('in der Reihenfolge des Kerns', (tester) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(wichtig, findsOneWidget);
      expect(
        vierWichtige,
        hasLength(4),
        reason: 'Vorbedingung: `istWichtig` nennt genau vier Maße.',
      );

      var vorigesOben = double.negativeInfinity;
      for (final mass in vierWichtige) {
        final oben = tester.getRect(massZeile(mass)).top;
        expect(
          oben,
          greaterThan(vorigesOben),
          reason:
              '${mass.schluessel} steht nicht unter seinem Vorgänger. Die '
              'Übersicht sortiert nach Wichtigkeit fürs Ziel — wer '
              'nachsieht, will wissen, wie es steht (SPEC 4.6)',
        );
        vorigesOben = oben;
      }
    });

    testWidgets('und alle elf übrigen darunter', (tester) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(uebrige, findsOneWidget);
      final unterkanteDerVier = vierWichtige
          .map((mass) => tester.getRect(massZeile(mass)).bottom)
          .reduce((a, b) => a > b ? a : b);

      for (final mass in elfUebrige) {
        expect(
          massZeile(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel} fehlt ganz. Fünfzehn Maße, fünfzehn '
              'Zeilen — auch die nie gemessenen stehen da und sagen das',
        );
        expect(
          tester.getRect(massZeile(mass)).top,
          greaterThanOrEqualTo(unterkanteDerVier),
          reason:
              '${mass.schluessel} steht zwischen den vier wichtigen. Ihre '
              'Reihenfolge untereinander ist frei, ihre Lage nicht',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Drei Zustände
  // ───────────────────────────────────────────────────────────────────────

  group('Drei Zustände, drei verschiedene Auskünfte', () {
    testWidgets('mit Messungen: weder „erste Messung" noch „noch nichts"', (
      tester,
    ) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(ersteHinweis, findsNothing);
      expect(leerHinweis, findsNothing);
      expect(trend(Umfang.taille), findsOneWidget);
    });

    testWidgets('erste Messung: der Hinweis steht da — und keine Null als '
        'Trend', (tester) async {
      await lege(tagNeu, {
        Umfang.brust: 102.3,
        Umfang.taille: 84.4,
        Umfang.oberarmRechtsAngespannt: 37.6,
      });
      await zeigeUebersicht(tester);

      expect(
        ersteHinweis,
        findsOneWidget,
        reason:
            'Ein Punkt ist kein Verlauf. „Ab der zweiten zeigt die App '
            'Veränderung und Verlauf" (Entwurf, Variante `erste`)',
      );
      expect(leerHinweis, findsNothing);

      final texte = alleTexte(tester);
      expect(
        RegExp(r'[+\-−±]\s?0[,.]0').hasMatch(texte),
        isFalse,
        reason:
            'Eine Null als Trend behauptet einen Vergleich, den es nicht '
            'gab — dasselbe Muster wie `01`. Gefunden in: „$texte"',
      );
      expect(
        RegExp(r'\b0[,.]0\s?cm').hasMatch(texte),
        isFalse,
        reason: 'auch nicht ohne Vorzeichen. Gefunden in: „$texte"',
      );
      expect(
        texte.toLowerCase(),
        isNot(contains('unverändert')),
        reason:
            '„unverändert" ist eine Aussage über zwei Messungen. Mit einer '
            'gibt es keine. Gefunden in: „$texte"',
      );
    });

    testWidgets('noch nichts erfasst: der andere Hinweis, und kein Wert', (
      tester,
    ) async {
      await zeigeUebersicht(tester);

      expect(leerHinweis, findsOneWidget);
      expect(ersteHinweis, findsNothing);
      expect(
        RegExp(r'\d+[,.]\d\s?cm').hasMatch(alleTexte(tester)),
        isFalse,
        reason:
            'Ohne Messung gibt es keinen Zentimeterwert — jeder hier wäre '
            'erfunden (`CLAUDE.md`)',
      );
    });

    testWidgets('„noch nie gemessen" und „erst einmal gemessen" sind zwei '
        'verschiedene Texte', (tester) async {
      await zeigeUebersicht(tester);
      final leerText = textUnter(tester, leerHinweis);
      expect(leerText, isNotEmpty);

      await lege(tagNeu, {Umfang.taille: 84.4});
      await zeigeUebersicht(tester);
      final ersterText = textUnter(tester, ersteHinweis);
      expect(ersterText, isNotEmpty);

      expect(
        ersterText,
        isNot(leerText),
        reason:
            '„Noch nie gemessen" ist etwas anderes als „erst einmal '
            'gemessen" (Plan, Task 2.3). Derselbe Satz in beiden Fällen '
            'ließe den Nutzer raten, ob seine Messung angekommen ist',
      );
    });

    testWidgets('„Alle Messungen" fällt in keinem Zustand weg', (
      tester,
    ) async {
      await zeigeUebersicht(tester);
      expect(
        messungen,
        findsOneWidget,
        reason:
            'Sonst wächst der Schirm bei der ersten Messung um eine ganze '
            'Gruppe, und alles darunter rutscht (`CLAUDE.md`)',
      );

      await lege(tagNeu, {Umfang.taille: 84.4});
      await zeigeUebersicht(tester);
      expect(messungen, findsOneWidget);
      expect(messZeile(tagNeu), findsOneWidget);
    });

    testWidgets('und „Maße eintragen" steht in jedem Zustand und öffnet '
        'einen leeren Tag', (tester) async {
      await zeigeUebersicht(tester);
      expect(
        eintragenKnopf,
        findsOneWidget,
        reason:
            'Gerade ohne Messung ist der Knopf der einzige sinnvolle '
            'nächste Schritt (Entwurf, Variante `leer`)',
      );

      await dreiMesstage();
      await zeigeUebersicht(tester);
      await tippe(tester, eintragenKnopf);

      expect(formular, findsOneWidget);
      expect(
        wertImFeld(tester, Umfang.taille),
        isNull,
        reason:
            '„Maße eintragen" meint heute, und heute wurde nicht gemessen '
            '— die Felder sind leer, der Vorwert steht blass dahinter',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der Ladezustand behauptet keine Datenlage (`01`, eine Ebene tiefer)
  // ───────────────────────────────────────────────────────────────────────

  group('Während des Lesens sagt keine Zeile, dass nichts gemessen ist '
      '(`01`)', () {
    testWidgets('weder eine Maß-Zeile noch „Alle Messungen"', (tester) async {
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeUebersicht(
        tester,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );

      // Die Geometrie bleibt: fünfzehn Zeilen, beide Gruppen, „Alle
      // Messungen". Ungefüllt, nicht weg.
      for (final mass in Umfang.values) {
        expect(
          massZeile(mass),
          findsOneWidget,
          reason:
              '${mass.schluessel}: Der Ladezustand ist kein Leerstand — die '
              'Zeile steht da, grau und ungefüllt',
        );
      }
      expect(wichtig, findsOneWidget);
      expect(uebrige, findsOneWidget);
      expect(messungen, findsOneWidget);

      final texte = alleTexte(tester);
      expect(
        leerBehauptung.hasMatch(texte),
        isFalse,
        reason:
            'Während gelesen wird, weiß die App nicht, ob etwas erfasst '
            'ist. Eine Zeile, die „noch nicht gemessen" sagt, behauptet '
            'eine Datenlage — und zwar fünfzehnmal plus einmal unter „Alle '
            'Messungen". Das ist Fehler `01`, eine Ebene unter dem '
            'Grund-Kasten. Gefunden in: „$texte"',
      );
      expect(leerHinweis, findsNothing);
      expect(ersteHinweis, findsNothing);

      antwort.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('und auch der Vorlesetext nicht', (tester) async {
      // Wer vorlesen lässt, bekäme sonst fünfzehnmal „keine Werte" zu
      // hören, während noch gelesen wird. Der Vorlesetext nennt den
      // Zustand (`CLAUDE.md`) — und der heißt hier „wird gelesen", nicht
      // „keine Werte".
      //
      // **Kein eigenes `tester.ensureSemantics()` hier.** `testWidgets`
      // schaltet die Semantik selbst ein (`semanticsEnabled: true`) und
      // zählt am **Ende des Testrumpfs** die offenen `SemanticsHandle` —
      // also bevor `package:test` die `addTearDown`-Rückrufe abarbeitet.
      // Ein über `addTearDown(handle.dispose)` aufgeräumtes zweites Handle
      // ist zu diesem Zeitpunkt noch offen, und der Fall scheitert an
      // „A SemanticsHandle was active at the end of the test", ohne dass
      // eine einzige Zusicherung fehlschlägt. `tester.getSemantics(…)`
      // braucht ohnehin keines. Dieselbe Falle steht in
      // `heute_view_test.dart:867`, `icon_row_test.dart:105` und
      // `mahlzeit_view_test.dart:981` — hier ist sie zum vierten Mal
      // aufgelaufen.
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeUebersicht(
        tester,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );

      for (final mass in [Umfang.taille, Umfang.brust]) {
        final label = tester.getSemantics(massZeile(mass)).label.toLowerCase();
        expect(
          label,
          isNot(contains('keine werte')),
          reason:
              '${mass.schluessel}: „keine Werte" ist eine Aussage über Tims '
              'Daten, und die liegt noch nicht vor. Gefunden: „$label"',
        );
      }

      antwort.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('ist der Lauf durch, darf die Auskunft kommen', (
      tester,
    ) async {
      // Die Gegenprobe: Der Fall oben darf sich nicht dadurch erledigen
      // lassen, dass die Auskunft ganz verschwindet.
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeUebersicht(
        tester,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );
      antwort.complete(const []);
      await tester.pumpAndSettle();

      expect(leerHinweis, findsOneWidget);
      expect(
        leerBehauptung.hasMatch(alleTexte(tester)),
        isTrue,
        reason:
            'Jetzt ist bekannt, dass nichts erfasst ist — und jetzt gehört '
            'es auch dagestanden',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Gescheitertes Lesen ist etwas anderes als laufendes
  // ───────────────────────────────────────────────────────────────────────

  group('Ein gescheitertes Lesen benennt sich (`UebersichtUnlesbar`)', () {
    testWidgets('der Schirm sagt, dass das Lesen gescheitert ist', (
      tester,
    ) async {
      await zeigeUebersicht(tester, repo: _KaputtesRepo(db));

      expect(
        unlesbar,
        findsOneWidget,
        reason:
            'Der sealed-Typ hat drei Fälle. Wird der dritte mit '
            '`is UebersichtGelesen ? … : null` eingeebnet, trägt er nichts '
            'mehr — genau dafür gibt es in `Messwert<T>` den Unterschied '
            'zwischen `LeerNachLauf` und `Fehlgeschlagen`',
      );
    });

    testWidgets('und sagt weder „wird gelesen" noch „noch keine Messung"', (
      tester,
    ) async {
      await zeigeUebersicht(tester, repo: _KaputtesRepo(db));

      final texte = alleTexte(tester);
      expect(
        ladeBehauptung.hasMatch(texte),
        isFalse,
        reason:
            'Ein gescheitertes Lesen läuft nicht mehr. „Wird gelesen …" '
            'stünde dort für immer, und niemand erführe, was los ist. '
            'Gefunden in: „$texte"',
      );
      expect(
        leerBehauptung.hasMatch(texte),
        isFalse,
        reason:
            '„Keine Daten" und „nicht lesbar" sind zwei verschiedene '
            'Auskünfte. Gefunden in: „$texte"',
      );
      expect(leerHinweis, findsNothing);
      expect(ersteHinweis, findsNothing);
    });

    testWidgets('die Geometrie bleibt auch hier', (tester) async {
      await zeigeUebersicht(tester, repo: _KaputtesRepo(db));

      for (final mass in Umfang.values) {
        expect(massZeile(mass), findsOneWidget, reason: mass.schluessel);
      }
      expect(wichtig, findsOneWidget);
      expect(uebrige, findsOneWidget);
      expect(
        messungen,
        findsOneWidget,
        reason: '„Alle Messungen" fällt in keinem Zustand weg',
      );
      expect(
        eintragenKnopf,
        findsOneWidget,
        reason:
            'Dass die Tabelle sich nicht lesen ließ, hindert niemanden am '
            'Messen',
      );
    });

    testWidgets('lädt, unlesbar und leer sind drei unterscheidbare '
        'Auskünfte', (tester) async {
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeUebersicht(
        tester,
        repo: _HaengendesRepo(db, antwort),
        warte: false,
      );
      final beimLaden = alleTexte(tester);
      antwort.complete(const []);
      await tester.pumpAndSettle();

      await zeigeUebersicht(tester, repo: _KaputtesRepo(db));
      final beimFehler = alleTexte(tester);

      await zeigeUebersicht(tester);
      final beimLeeren = alleTexte(tester);

      expect(
        beimFehler,
        isNot(beimLaden),
        reason:
            'Heute sind beide Zustände wortgleich: Der Schirm unterscheidet '
            'nur `UebersichtGelesen` von „alles andere". Dann steht „Wird '
            'gelesen …" dauerhaft da',
      );
      expect(beimFehler, isNot(beimLeeren));
      expect(beimLaden, isNot(beimLeeren));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Bei der Taille ist weniger der Fortschritt
  // ───────────────────────────────────────────────────────────────────────

  group('Ein Vorzeichen allein färbt nichts ein', () {
    testWidgets('Brust hoch und Taille runter sind beides Fortschritt', (
      tester,
    ) async {
      await dreiMesstage();
      await zeigeUebersicht(tester);

      expect(
        UmfangsFortschritt.veraenderung(Umfang.taille, [
          Umfangsmessung(
            zeitpunkt: BerlinCalendar.startOfDay(DateTime.utc(2099, 3, 1, 12)),
            werte: const {Umfang.taille: 85.0},
          ),
          Umfangsmessung(
            zeitpunkt: BerlinCalendar.startOfDay(DateTime.utc(2099, 3, 8, 12)),
            werte: const {Umfang.taille: 84.0},
          ),
        ])?.istFortschritt,
        isTrue,
        reason:
            'Vorbedingung: Der Kern nennt eine fallende Taille Fortschritt '
            '(`wenigerIstBesser`). Sagt er das nicht, prüft der Fall '
            'darunter nichts',
      );

      expect(
        trendFarbe(tester, Umfang.taille),
        trendFarbe(tester, Umfang.brust),
        reason:
            'Die Taille fällt um 1,0 cm, die Brust steigt um 1,5 cm — '
            'beides ist Fortschritt. Wer nach dem Vorzeichen färbt, malt '
            'Tims bestes Ergebnis rot an',
      );
    });

    testWidgets('Brust runter und Taille hoch sind beides Rückschritt', (
      tester,
    ) async {
      await lege(tagMitte, {Umfang.brust: 103.5, Umfang.taille: 84.0});
      await lege(tagNeu, {Umfang.brust: 102.0, Umfang.taille: 85.0});
      await zeigeUebersicht(tester);

      expect(
        trendFarbe(tester, Umfang.taille),
        trendFarbe(tester, Umfang.brust),
        reason:
            'Umgekehrt genauso: Die Taille wächst um 1,0 cm, die Brust '
            'fällt um 1,5 cm — beides geht in die falsche Richtung',
      );
    });

    testWidgets('und die Hüfte zählt nicht zur Taille', (tester) async {
      // `wenigerIstBesser` gilt nur für die Taille: Die Hüfte misst mit,
      // was am Gesäß aufgebaut wird (Kopf von `umfang.dart`).
      await lege(tagMitte, {Umfang.huefte: 98.0, Umfang.brust: 102.0});
      await lege(tagNeu, {Umfang.huefte: 98.9, Umfang.brust: 103.5});
      await zeigeUebersicht(tester);

      expect(
        trendFarbe(tester, Umfang.huefte),
        trendFarbe(tester, Umfang.brust),
        reason:
            'Beide wachsen, beide sind Fortschritt. Die Hüfte als zweite '
            'Taille zu behandeln färbte Aufbau als Rückschritt',
      );
    });
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt —
/// der Zustand `UebersichtLaedt`.
class _HaengendesRepo extends UmfaengeRepository {
  _HaengendesRepo(super.db, this.antwort);

  final Completer<List<Umfangsmessung>> antwort;

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) =>
      antwort.future;

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Ein Repository, dessen Lesen scheitert — der Zustand
/// `UebersichtUnlesbar`. **Schreiben bleibt möglich:** Dass die Tabelle
/// sich nicht lesen ließ, hindert niemanden am Messen, und ein Stumpf, der
/// auch dabei würfe, prüfte eine andere Frage.
class _KaputtesRepo extends UmfaengeRepository {
  _KaputtesRepo(super.db);

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) =>
      Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Eine Quelle mit erfundenen Tageswerten, damit der Körper-Schirm nicht im
/// Ladezustand stehen bleibt. Die Umfänge kommen nicht von hier, sondern
/// aus der Tabelle.
class _Quelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => [
    DailyMetrics(tag: '2099-03-14', steps: 7200, weightKg: 77.3),
    DailyMetrics(tag: '2099-03-15', steps: 410),
  ];
}
