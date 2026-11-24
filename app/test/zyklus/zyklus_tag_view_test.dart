import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/zyklus_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/zyklus/zyklus_symptome.dart';
import 'package:repit/zyklus/zyklus_tag_view.dart';
import 'package:repit/zyklus/zyklus_texte.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den Schirm **„Tag eintragen"** (#572 unter #539,
/// Stufe 6 des Umsetzungsplans), `lib/zyklus/zyklus_tag_view.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. Hält der Implementierende einen Fall für falsch, **meldet**
/// er ihn, statt ihn passend zu machen.
///
/// ## Woher die Anforderung kommt
///
/// - Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`: 4.1 (was
///   ein Tageseintrag trägt), **4.3.2** („ohne jeden Wert" heißt
///   gelöscht), 3.8 (ein positiver Test pausiert die Vorhersage), 5.1
///   (`zyklusTagProvider(tag)` liefert `ZyklusEintrag?`), 7.
/// - Entwurfsboard `docs/screens/screens/zyklus-tag.js`, Varianten
///   `leer`, `periodentag`, `test-positiv` und `hilfe`.
/// - Plan `docs/superpowers/plans/2026-11-23-zyklus-umsetzung.md`,
///   Stufe 6: „Eintragen und Ändern, für jeden Tag".
///
/// Der Code des Schirms existierte beim Schreiben dieser Datei nicht.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Dass der Knopf „Sichern" heißt, prüft hier nichts.
/// Geprüft wird:
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (`01`) —
///    „nichts gewählt" ist so ein Grund: Er behauptet etwas über den
///    Tag, bevor feststeht, was abgelegt ist.
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder
///    da** (`32`) — und zwar nachweislich, nicht nur sichtbar: Wer den
///    Schirm ein zweites Mal öffnet und **ein anderes** Feld ändert,
///    darf die übrigen nicht verlieren. Der Schirm schreibt den ganzen
///    Tag (`zyklus_repository_test.dart`), also nimmt eine fehlende
///    Vorbelegung alles mit, was sie nicht kennt.
/// 3. Die vier Zustände des Entwurfs: nichts eingetragen, Werte
///    eintragen, alles leeren, positiver Test.
///
/// ## Die API, auf die sich diese Datei festlegt
///
/// Spec und Entwurf nennen keine Dart-Namen. **Nicht von Tim
/// freigegeben:**
///
/// | Was | Wo |
/// |---|---|
/// | `ZyklusTagSeite({required String tag})` | `lib/zyklus/zyklus_tag_view.dart` |
/// | `void oeffneZyklusTag(AppRouter router, {required String tag})` | ebenda |
///
/// `tag` ist der ISO-Tagesstring des Tages, der eingetragen wird — nie
/// „heute": Jeder Kalendertag ist eine Tür, und welcher gemeint ist,
/// entscheidet der Aufrufer (Spec 7).
///
/// Schlüssel:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `zyklus-tag` | der Schirm selbst |
/// | `zyklus-tag-abschnitt-<name>` | je Abschnitt Kopf **und** Karte zusammen |
/// | `zyklus-tag-blutung-<stufe>` | die Wahl der Blutungsstärke |
/// | `zyklus-tag-zwischenblutung` | der Schalter |
/// | `zyklus-tag-schmerz-<stufe>` | die Wahl der Schmerzstärke |
/// | `zyklus-tag-symptom-<schluessel>` | je Symptom ein Druckfeld |
/// | `zyklus-tag-sex` | der Schalter „Sex gehabt" |
/// | `zyklus-tag-verhuetet` | der Schalter „Verhütet" |
/// | `zyklus-tag-test` | die Zeile mit dem Ergebnis |
/// | `zyklus-tag-test-<wert>` | die Wahl des Ergebnisses |
/// | `zyklus-tag-test-wirkung` | „Pausiert die Vorhersage im Kalender" |
/// | `zyklus-tag-notiz` | die Zeile mit der Notiz |
/// | `zyklus-tag-sichern` | „Sichern", auf einem `CupertinoButton` |
///
/// `<name>` ist `blutung`, `schmerzen`, `symptome`, `sex`, `test`,
/// `notiz` — die sechs Abschnitte des Entwurfs. `<stufe>` ist
/// `Blutungsstaerke.name` bzw. `Schmerzstaerke.name`, dazu `keine` für
/// „nichts"; `<wert>` ist `Testergebnis.name`, dazu `keins`. `<keine>`
/// und `<keins>` sind **Wahlmöglichkeiten, keine Werte**: Sie nehmen
/// zurück, was gewählt war (Entwurf: „Löschen heißt leeren").
///
/// **Der Schlüssel des Symptoms ist `ZyklusSymptom.schluessel`**, nicht
/// sein deutscher Name: Derselbe Schlüssel steht in der Tabelle, und
/// zwei Schreibweisen für dasselbe Symptom liefen auseinander.
///
/// Weitere Festlegungen mit ihrem Grund:
///
/// - **Die Wahl des Testergebnisses darf hinter der Zeile
///   `zyklus-tag-test` liegen** (Blatt, Menü) oder offen danebenstehen
///   — [waehleTest] kommt mit beidem zurecht. Der Entwurf zeigt eine
///   Zeile; welche Form sie aufklappt, entscheidet die Ansicht.
/// - **„Sichern" ist aus, solange es nichts zu sichern gibt**, und an,
///   sobald der Schirm etwas anderes zeigt als das, was abgelegt ist.
///   Der Entwurf zeigt den Knopf auf dem leeren Tag grau. Das ist
///   dieselbe Regel, nur zu Ende gedacht: **Wer alles abwählt, hat
///   etwas zu sichern** — ohne das ließe sich ein Tag nie leeren, und
///   Spec 4.3.2 wäre über diesen Schirm nicht erreichbar.
/// - **Gesichert heißt fertig: der Schirm geht zu.** Dieselbe Form wie
///   `umfaenge_eintragen.dart`.
/// - **Während gelesen wird, ist „Sichern" aus.** Ein Sichern, das
///   schreibt, bevor feststeht, was abgelegt ist, überschriebe den Tag
///   mit Leere — und bei einem leeren Tag heißt das: gelöscht.
/// - **Die Notiz wird hier nur gelesen, nicht getippt.** Der Entwurf
///   zeigt eine Zeile („Freitext"), nicht, was sie aufklappt. Was
///   ungeklärt ist, wird nicht nebenbei im Test entschieden; die Zeile
///   muss nur zeigen, was abgelegt ist.
/// - **`ZyklusRepository` bleibt erweiterbar** (nicht `final`, nicht
///   `sealed`) — sonst ist der Ladezustand nicht erzeugbar.
///
/// ## Erfundene Daten
///
/// Jeder Tag, jede Blutung, jedes Symptom und jede Notiz hier ist
/// ausgedacht und liegt im Jahr 2099 (`CLAUDE.md`, „Niemals tun").
void main() {
  // 12:00 Berliner Zeit am 17.11.2099. Der Schirm wird für den **14.**
  // geöffnet: Verwechselt ihn jemand mit heute, fällt es auf.
  final jetzt = DateTime.utc(2099, 11, 17, 11);
  const heute = '2099-11-17';
  const tag = '2099-11-14';

  // Die laufende Periode — damit der Kopf einen Zyklustag nennen kann.
  const periode = ['2099-11-06', '2099-11-07', '2099-11-08', '2099-11-09'];

  final krampf = zyklusSymptome.first.schluessel;
  final muedigkeit = zyklusSymptome[6].schluessel;

  /// Wonach eine Aussage über die Datenlage des Tages klingt. Solange
  /// nicht feststeht, was abgelegt ist, darf nichts davon dastehen
  /// (`01`).
  final leerMuster = RegExp(
    '$zyklusNichtsGewaehlt|$zyklusTestNichtGemacht|'
    '$zyklusNichtsNotiert|nichts eingetragen|noch keine',
    caseSensitive: false,
  );

  final schirm = find.byKey(const Key('zyklus-tag'));
  final sichern = find.byKey(const Key('zyklus-tag-sichern'));
  final zwischenblutung = find.byKey(const Key('zyklus-tag-zwischenblutung'));
  final sexSchalter = find.byKey(const Key('zyklus-tag-sex'));
  final verhuetetSchalter = find.byKey(const Key('zyklus-tag-verhuetet'));
  final testZeile = find.byKey(const Key('zyklus-tag-test'));
  final testWirkung = find.byKey(const Key('zyklus-tag-test-wirkung'));
  final notizZeile = find.byKey(const Key('zyklus-tag-notiz'));

  const abschnitte = [
    'blutung',
    'schmerzen',
    'symptome',
    'sex',
    'test',
    'notiz',
  ];

  Finder abschnitt(String name) =>
      find.byKey(Key('zyklus-tag-abschnitt-$name'));
  Finder blutungsWahl(Blutungsstaerke? stufe) =>
      find.byKey(Key('zyklus-tag-blutung-${stufe?.name ?? 'keine'}'));
  Finder schmerzWahl(Schmerzstaerke? stufe) =>
      find.byKey(Key('zyklus-tag-schmerz-${stufe?.name ?? 'keine'}'));
  Finder testWahl(Testergebnis? ergebnis) =>
      find.byKey(Key('zyklus-tag-test-${ergebnis?.name ?? 'keins'}'));
  Finder symptomWahl(String schluessel) =>
      find.byKey(Key('zyklus-tag-symptom-$schluessel'));

  late AppCache db;
  late ZyklusRepository repo;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() async {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    repo = ZyklusRepository(db, uhr: () => jetzt);
    await repo.schreibeEinstellungen(
      ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true),
    );
    for (final blutungstag in periode) {
      await repo.schreibe(
        ZyklusEintrag(tag: blutungstag, blutung: Blutungsstaerke.mittel),
      );
    }
  });

  /// Liest unmittelbar aus der Tabelle, nicht über den Schirm: Was hier
  /// steht, hat den Schirm überlebt.
  Future<ZyklusEintrag?> abgelegt(String welcher) =>
      ZyklusRepository(db).lies(welcher);

  ProviderContainer behaelter({ZyklusRepository? ersatz}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
        if (ersatz != null) zyklusRepositoryProvider.overrideWithValue(ersatz),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Öffnet den Schirm über eine Tür auf einem `Navigator` — so wie ihn
  /// der Kalender öffnet, und so, dass „zurück" einen Ort hat.
  Future<GlobalKey<NavigatorState>> zeigeTag(
    WidgetTester tester, {
    String welcher = tag,
    ProviderContainer? container,
    bool warten = true,
  }) async {
    // Hoch genug für sechs Abschnitte und zwölf Symptome, damit nichts
    // erst gescrollt werden muss.
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      BehaelterImBaum(
        container: container ?? behaelter(),
        child: CupertinoApp(
          navigatorKey: navigator,
          home: _Tuer(tag: welcher),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tuer')));
    if (warten) {
      await tester.pumpAndSettle();
      expect(schirm, findsOneWidget, reason: 'Die Tür führt auf den Schirm.');
    }
    return navigator;
  }

  /// Noch einmal auf — nach dem Sichern steht man wieder auf der Tür.
  Future<void> nochmalAuf(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tuer')));
    await tester.pumpAndSettle();
    expect(schirm, findsOneWidget);
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Ob irgendwo auf dem Schirm dieser Text steht — **ohne Rücksicht auf
  /// Groß- und Kleinschreibung**: `HilfeKopf` setzt Marken in Versalien,
  /// und das ist Gestaltung, kein Inhalt.
  bool nennt(WidgetTester tester, String text) =>
      alleTexte(tester).toUpperCase().contains(text.toUpperCase());

  /// Dasselbe, aber nur innerhalb eines Abschnitts.
  bool abschnittNennt(WidgetTester tester, String name, String text) => tester
      .widgetList<Text>(
        find.descendant(of: abschnitt(name), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ')
      .toUpperCase()
      .contains(text.toUpperCase());

  bool sichernIstAn(WidgetTester tester) =>
      tester.widget<CupertinoButton>(sichern).onPressed != null;

  bool schalterSteht(WidgetTester tester, Finder zeile) => tester
      .widget<CupertinoSwitch>(
        find.descendant(of: zeile, matching: find.byType(CupertinoSwitch)),
      )
      .value;

  Future<void> tippe(WidgetTester tester, Finder was) async {
    await tester.tap(was);
    await tester.pumpAndSettle();
  }

  /// Wählt ein Testergebnis — gleich, ob die Wahl offen danebensteht
  /// oder erst hinter der Zeile aufklappt.
  Future<void> waehleTest(WidgetTester tester, Testergebnis? ergebnis) async {
    if (testWahl(ergebnis).evaluate().isEmpty) {
      await tippe(tester, testZeile);
    }
    await tippe(tester, testWahl(ergebnis));
  }

  Future<void> sichere(WidgetTester tester) async {
    await tester.tap(sichern);
    await tester.pumpAndSettle();
  }

  /// Ein Tag mit allem, was sich über diesen Schirm wieder abwählen
  /// lässt — **ohne Notiz**: Die Notiz wird hier nicht getippt, und ein
  /// Tag, der sich nicht ganz leeren lässt, taugte für 4.3.2 nicht.
  const voll = ZyklusEintrag(
    tag: tag,
    blutung: Blutungsstaerke.mittel,
    schmerz: Schmerzstaerke.leicht,
    symptome: ['kraempfe', 'muedigkeit'],
    sex: true,
    verhuetet: true,
    test: Testergebnis.negativ,
  );

  // ───────────────────────────────────────────────────────────────────
  // Nichts eingetragen (Entwurf, Variante `leer`)
  // ───────────────────────────────────────────────────────────────────

  group('Nichts eingetragen', () {
    testWidgets('alle Abschnitte stehen vollständig da', (tester) async {
      await zeigeTag(tester);

      for (final name in abschnitte) {
        expect(
          abschnitt(name),
          findsOneWidget,
          reason:
              'Abschnitt „$name" fehlt. Es ist derselbe Schirm wie mit '
              'Werten, nur ungefüllt — eine Anzeige, die es gibt, hat '
              'genau eine Form (`CLAUDE.md`)',
        );
      }
    });

    testWidgets('nichts ist vorbelegt', (tester) async {
      await zeigeTag(tester);

      expect(
        abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt),
        isTrue,
        reason:
            'ein Tag ohne Eintrag heißt „nicht eingetragen", nicht „keine '
            'Beschwerden" — nur das zweite wäre eine Behauptung über den '
            'Tag (Entwurf)',
      );
      expect(
        abschnittNennt(tester, 'schmerzen', zyklusNichtsGewaehlt),
        isTrue,
      );
      expect(schalterSteht(tester, zwischenblutung), isFalse);
      expect(schalterSteht(tester, sexSchalter), isFalse);
      expect(nennt(tester, zyklusTestNichtGemacht), isTrue);
      expect(nennt(tester, zyklusNichtsNotiert), isTrue);
      expect(
        testWirkung,
        findsNothing,
        reason: 'ohne positiven Test wirkt nichts auf den Kalender',
      );
    });

    testWidgets('„Verhütet" steht erst, wenn „Sex gehabt" an ist', (
      tester,
    ) async {
      await zeigeTag(tester);

      expect(
        verhuetetSchalter,
        findsNothing,
        reason:
            'Spec 4.1: „nur sinnvoll, wenn sex". Ein Schalter, der ohne '
            'seinen Anlass dasteht, fragt etwas, das niemand beantworten '
            'kann',
      );

      await tippe(tester, sexSchalter);

      expect(verhuetetSchalter, findsOneWidget);
      expect(schalterSteht(tester, verhuetetSchalter), isFalse);
    });

    testWidgets('„Sichern" ist aus, solange es nichts zu sichern gibt', (
      tester,
    ) async {
      await zeigeTag(tester);

      expect(
        sichernIstAn(tester),
        isFalse,
        reason:
            'der Entwurf zeigt den Knopf grau, solange nichts gewählt ist',
      );

      await tippe(tester, blutungsWahl(Blutungsstaerke.leicht));

      expect(
        sichernIstAn(tester),
        isTrue,
        reason: 'jetzt gibt es etwas zu sichern',
      );
    });

    testWidgets('der Schirm nennt den Tag, für den er geöffnet wurde — '
        'nicht heute', (tester) async {
      await zeigeTag(tester);

      expect(nennt(tester, '14.'), isTrue);
      expect(nennt(tester, 'November'), isTrue);
      expect(
        nennt(tester, 'Zyklustag 9'),
        isTrue,
        reason:
            'der 06.11. ist Tag 1 (Spec 1), also ist der 14.11. Tag 9. Die '
            'Zahl kommt aus dem Kern, nicht aus einer zweiten Rechnung',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Werte eintragen (Entwurf, Variante `periodentag`)
  // ───────────────────────────────────────────────────────────────────

  group('Eintragen und sichern', () {
    testWidgets('was gewählt wurde, liegt danach im Repository', (
      tester,
    ) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.mittel));
      await tippe(tester, schmerzWahl(Schmerzstaerke.leicht));
      await tippe(tester, symptomWahl(krampf));
      await tippe(tester, symptomWahl(muedigkeit));
      await tippe(tester, sexSchalter);
      await tippe(tester, verhuetetSchalter);
      await waehleTest(tester, Testergebnis.negativ);
      await sichere(tester);

      final eintrag = await abgelegt(tag);
      expect(eintrag, isNotNull, reason: 'der Tag ist abgelegt');
      expect(eintrag!.blutung, Blutungsstaerke.mittel);
      expect(eintrag.schmerz, Schmerzstaerke.leicht);
      expect(eintrag.symptome, containsAll(<String>[krampf, muedigkeit]));
      expect(eintrag.sex, isTrue);
      expect(eintrag.verhuetet, isTrue);
      expect(eintrag.test, Testergebnis.negativ);
    });

    testWidgets('geschrieben wird der geöffnete Tag, nicht heute', (
      tester,
    ) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.stark));
      await sichere(tester);

      expect((await abgelegt(tag))!.blutung, Blutungsstaerke.stark);
      expect(
        await abgelegt(heute),
        isNull,
        reason:
            'wer am Mittwoch den Dienstag nachträgt, trägt nicht auf '
            'Mittwoch ein. Das fängt zugleich ein `DateTime.now()` im '
            'Rumpf',
      );
    });

    testWidgets('der Zeitstempel kommt aus clockProvider', (tester) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.leicht));
      await sichere(tester);

      expect(
        (await abgelegt(tag))!.geaendert,
        jetzt,
        reason:
            'die Uhr des Repositorys kommt aus dem Provider — sonst wäre '
            'der Zeitstempel in keinem Test prüfbar',
      );
    });

    testWidgets('gesichert heißt fertig: der Schirm geht zu', (tester) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.leicht));
      await sichere(tester);

      expect(schirm, findsNothing);
    });

    testWidgets('ein abgelegter Tag kommt gefüllt wieder hoch', (
      tester,
    ) async {
      await repo.schreibe(voll);
      await zeigeTag(tester);

      expect(
        abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt),
        isFalse,
        reason:
            'hier ist etwas gewählt — die Marke „nichts gewählt" wäre '
            'jetzt falsch',
      );
      expect(abschnittNennt(tester, 'schmerzen', zyklusNichtsGewaehlt), isFalse);
      expect(schalterSteht(tester, sexSchalter), isTrue);
      expect(verhuetetSchalter, findsOneWidget);
      expect(schalterSteht(tester, verhuetetSchalter), isTrue);
      expect(
        sichernIstAn(tester),
        isFalse,
        reason:
            'nichts geändert heißt nichts zu sichern — derselbe graue '
            'Knopf wie auf dem leeren Tag, aus demselben Grund',
      );
    });

    testWidgets('eine abgelegte Notiz steht da, statt „nichts notiert"', (
      tester,
    ) async {
      await repo.schreibe(
        const ZyklusEintrag(tag: tag, notiz: 'Pruefnotiz 2099'),
      );
      await zeigeTag(tester);

      expect(
        tester
            .widgetList<Text>(
              find.descendant(of: notizZeile, matching: find.byType(Text)),
            )
            .map(textOf)
            .join(' '),
        contains('Pruefnotiz 2099'),
      );
      expect(nennt(tester, zyklusNichtsNotiert), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Alles leeren hinterlässt keinen Tag (Spec 4.3.2)
  // ───────────────────────────────────────────────────────────────────

  group('Löschen heißt leeren', () {
    testWidgets('wer alles abwählt und sichert, hinterlässt keinen Tag', (
      tester,
    ) async {
      await repo.schreibe(voll);
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(null));
      await tippe(tester, schmerzWahl(null));
      await tippe(tester, symptomWahl(krampf));
      await tippe(tester, symptomWahl(muedigkeit));
      await tippe(tester, sexSchalter);
      await waehleTest(tester, null);

      expect(
        sichernIstAn(tester),
        isTrue,
        reason:
            'wer alles abwählt, hat etwas zu sichern — sonst ließe sich '
            'ein Tag über diesen Schirm nie zurücknehmen, und es gibt '
            'keinen zweiten Weg („Löschen heißt leeren")',
      );

      await sichere(tester);

      expect(
        await abgelegt(tag),
        isNull,
        reason:
            'Spec 4.1: „Ein leerer Tag ist ein Tag ohne Zeile." Bliebe '
            'die Zeile stehen, zählte sie im Kalender weiter als „etwas '
            'eingetragen"',
      );
    });

    testWidgets('das Leeren nimmt nur diesen Tag mit', (tester) async {
      await repo.schreibe(voll);
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(null));
      await tippe(tester, schmerzWahl(null));
      await tippe(tester, symptomWahl(krampf));
      await tippe(tester, symptomWahl(muedigkeit));
      await tippe(tester, sexSchalter);
      await waehleTest(tester, null);
      await sichere(tester);

      expect(
        (await abgelegt(periode.first))!.blutung,
        Blutungsstaerke.mittel,
        reason: 'die Nachbartage gehen niemanden etwas an',
      );
    });

    testWidgets('ein einzelnes zurückgenommenes Feld verschwindet, der '
        'Rest bleibt', (tester) async {
      await repo.schreibe(voll);
      await zeigeTag(tester);

      await tippe(tester, schmerzWahl(null));
      await sichere(tester);

      final eintrag = await abgelegt(tag);
      expect(
        eintrag!.schmerz,
        isNull,
        reason:
            'ein Schmerz, den die Nutzerin wegnimmt, bleibt sonst für '
            'immer stehen',
      );
      expect(eintrag.blutung, Blutungsstaerke.mittel);
      expect(eintrag.symptome, containsAll(<String>[krampf, muedigkeit]));
      expect(eintrag.sex, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Der positive Test wirkt sichtbar (Spec 3.8, Entwurf `test-positiv`)
  // ───────────────────────────────────────────────────────────────────

  group('Positiver Schwangerschaftstest', () {
    testWidgets('die Wirkung steht sofort da, noch vor dem Sichern', (
      tester,
    ) async {
      await zeigeTag(tester);
      expect(testWirkung, findsNothing, reason: 'Vorbedingung');

      await waehleTest(tester, Testergebnis.positiv);

      expect(
        testWirkung,
        findsOneWidget,
        reason:
            'eine Wirkung auf einen anderen Schirm hinter einem '
            'Fragezeichen wäre eine verschwiegene Wirkung — und eine '
            'Vorhersage, die stillschweigend aufhört, ein Fehler, den '
            'niemand findet (Entwurf)',
      );
      expect(nennt(tester, zyklusTestWirkung), isTrue);
    });

    testWidgets('gesichert liegt das Ergebnis im Repository', (tester) async {
      await zeigeTag(tester);

      await waehleTest(tester, Testergebnis.positiv);
      await sichere(tester);

      expect((await abgelegt(tag))!.test, Testergebnis.positiv);
    });

    testWidgets('ein abgelegtes positives Ergebnis zeigt die Wirkung beim '
        'Öffnen', (tester) async {
      await repo.schreibe(
        const ZyklusEintrag(tag: tag, test: Testergebnis.positiv),
      );
      await zeigeTag(tester);

      expect(testWirkung, findsOneWidget);
    });

    testWidgets('ein negatives Ergebnis wirkt nicht', (tester) async {
      await repo.schreibe(
        const ZyklusEintrag(tag: tag, test: Testergebnis.negativ),
      );
      await zeigeTag(tester);

      expect(
        testWirkung,
        findsNothing,
        reason: 'nur das positive Ergebnis pausiert die Vorhersage (Spec 3.8)',
      );
    });

    testWidgets('gedeutet wird nichts', (tester) async {
      await zeigeTag(tester);
      await waehleTest(tester, Testergebnis.positiv);

      expect(
        RegExp(
          r'du bist schwanger|Schwangerschaft bestät|wahrscheinlich '
          r'schwanger|Glückwunsch',
          caseSensitive: false,
        ).hasMatch(alleTexte(tester)),
        isFalse,
        reason:
            'keine Diagnosen (`CLAUDE.md`): Vermerkt wird das Ergebnis, '
            'gedeutet wird es nicht',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Während des Lesens steht kein „keine Daten"-Grund (`01`)
  // ───────────────────────────────────────────────────────────────────

  group('Während des Lesens steht kein „keine Daten"-Grund (`01`)', () {
    testWidgets('die Abschnitte stehen schon da, der Grund nicht', (
      tester,
    ) async {
      final antwort = Completer<void>();
      await zeigeTag(
        tester,
        container: behaelter(ersatz: _HaengendesRepo(db, antwort)),
        warten: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(schirm, findsOneWidget, reason: 'Der Schirm steht, er lädt nur.');
      for (final name in abschnitte) {
        expect(
          abschnitt(name),
          findsOneWidget,
          reason:
              'Abschnitt „$name": Der Ladezustand ist kein Leerstand — '
              'dieselbe Form, nur ungefüllt',
        );
      }
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          leerMuster.hasMatch(textOf(text)),
          isFalse,
          reason:
              'Text „${textOf(text)}" behauptet, der Tag sei leer, während '
              'noch gelesen wird. Steht dort gleich ein Wert, blitzt die '
              'Marke vorher auf — das ist Fehler `01`',
        );
      }
      expect(
        sichernIstAn(tester),
        isFalse,
        reason:
            'ein Sichern, bevor feststeht, was abgelegt ist, überschriebe '
            'den Tag mit Leere — und leer heißt gelöscht (Spec 4.1)',
      );

      antwort.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('erst wenn der Lauf fertig ist, darf er sagen, dass nichts '
        'gewählt ist', (tester) async {
      final antwort = Completer<void>();
      await zeigeTag(
        tester,
        container: behaelter(ersatz: _HaengendesRepo(db, antwort)),
        warten: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      antwort.complete();
      await tester.pumpAndSettle();

      expect(schirm, findsOneWidget);
      for (final name in abschnitte) {
        expect(abschnitt(name), findsOneWidget);
      }
      expect(
        abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt),
        isTrue,
        reason: 'jetzt steht fest, dass nichts abgelegt ist',
      );
    });

    testWidgets('ein gelesener Wert füllt den Schirm, sobald er da ist', (
      tester,
    ) async {
      await repo.schreibe(voll);
      final antwort = Completer<void>();
      await zeigeTag(
        tester,
        container: behaelter(ersatz: _LangsamesRepo(db, antwort, jetzt)),
        warten: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      antwort.complete();
      await tester.pumpAndSettle();

      expect(
        schalterSteht(tester, sexSchalter),
        isTrue,
        reason:
            'was abgelegt war, steht im Formular — ein Schirm, der den '
            'gelesenen Wert verwirft, hätte ihn beim nächsten Sichern '
            'gelöscht',
      );
      expect(abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Ein Wert, der dastand, steht wieder da (`32`)
  // ───────────────────────────────────────────────────────────────────

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('eingetragen, zurück, wieder auf — die Werte sind da', (
      tester,
    ) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.mittel));
      await tippe(tester, symptomWahl(krampf));
      await sichere(tester);
      await nochmalAuf(tester);

      expect(
        abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt),
        isFalse,
        reason:
            'der Wert war weg, wenn der Schirm ihn beim zweiten Öffnen '
            'nicht mehr zeigt (`32`)',
      );
      expect(
        sichernIstAn(tester),
        isFalse,
        reason: 'nichts geändert, nichts zu sichern',
      );
    });

    testWidgets('ein zweites Sichern nimmt nicht mit, was es nicht '
        'angefasst hat', (tester) async {
      await zeigeTag(tester);

      await tippe(tester, blutungsWahl(Blutungsstaerke.mittel));
      await tippe(tester, symptomWahl(krampf));
      await tippe(tester, sexSchalter);
      await sichere(tester);

      await nochmalAuf(tester);
      await tippe(tester, schmerzWahl(Schmerzstaerke.stark));
      await sichere(tester);

      final eintrag = await abgelegt(tag);
      expect(eintrag!.schmerz, Schmerzstaerke.stark);
      expect(
        eintrag.blutung,
        Blutungsstaerke.mittel,
        reason:
            'der Schirm schreibt den ganzen Tag. Eine fehlende '
            'Vorbelegung nähme beim zweiten Sichern alles mit, was sie '
            'nicht kennt — das ist `32` in seiner teuersten Form: Der '
            'Wert verschwindet nicht nur von der Anzeige, er ist weg',
      );
      expect(eintrag.symptome, contains(krampf));
      expect(eintrag.sex, isTrue);
    });

    testWidgets('ein Tag, der am Schirm vorbei dazukommt, steht beim '
        'nächsten Öffnen da', (tester) async {
      final navigator = await zeigeTag(tester);
      expect(abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt), isTrue);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await repo.schreibe(voll);
      await nochmalAuf(tester);

      expect(
        abschnittNennt(tester, 'blutung', zyklusNichtsGewaehlt),
        isFalse,
        reason:
            'der Schirm besorgt seine Daten selbst und liest sie beim '
            'Öffnen neu (`CLAUDE.md`)',
      );
    });
  });
}

/// Die Tür, durch die der Schirm geschoben wird — der Platzhalter für
/// den Kalender, damit „zurück" in dieser Datei einen Ort hat.
class _Tuer extends StatelessWidget {
  const _Tuer({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: Center(
      child: CupertinoButton(
        key: const Key('tuer'),
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => ZyklusTagSeite(tag: tag)),
        ),
        child: const Text('auf'),
      ),
    ),
  );
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt.
///
/// **Kein `super.db`:** Diese Datei legt sich auf einen ersten
/// positionellen Parameter fest, nicht auf dessen Namen.
class _HaengendesRepo extends ZyklusRepository {
  _HaengendesRepo(AppCache db, this.antwort) : super(db);

  final Completer<void> antwort;

  @override
  Future<ZyklusEintrag?> lies(String tag) async {
    await antwort.future;
    return null;
  }

  @override
  Future<List<ZyklusEintrag>> imZeitraum({
    required String von,
    required String bis,
  }) async {
    await antwort.future;
    return const [];
  }

  @override
  Future<ZyklusEinstellungen> liesEinstellungen() async {
    await antwort.future;
    return ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true);
  }
}

/// Dasselbe, aber die Antwort ist die **echte** Tabelle: der Fall, in
/// dem während des Lesens etwas abgelegt ist.
class _LangsamesRepo extends ZyklusRepository {
  _LangsamesRepo(AppCache db, this.antwort, DateTime jetzt)
    : _echt = ZyklusRepository(db, uhr: (() => jetzt)),
      super(db);

  final Completer<void> antwort;
  final ZyklusRepository _echt;

  @override
  Future<ZyklusEintrag?> lies(String tag) async {
    await antwort.future;
    return _echt.lies(tag);
  }

  @override
  Future<List<ZyklusEintrag>> imZeitraum({
    required String von,
    required String bis,
  }) async {
    await antwort.future;
    return _echt.imZeitraum(von: von, bis: bis);
  }

  @override
  Future<ZyklusEinstellungen> liesEinstellungen() async {
    await antwort.future;
    return _echt.liesEinstellungen();
  }
}
