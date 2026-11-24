import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/messung_detail_view.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Der Tag, an dem die erfundenen Werte liegen — oben, weil die Attrappe
/// unten ihn auch braucht.
const _heute = '2099-02-16';
const _gestern = '2099-02-15';

/// Widget-Tests für den **Navy-Wert im Messung-Detail** (#479 unter #88) —
/// die Zeile „Nach Maßband (Navy)" neben dem Waagenwert.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// `docs/SPEC.md` 4.6 („Körperfett nach Navy-Methode … neben dem
/// Waagenwert"), `docs/superpowers/plans/2026-11-11-umfaenge.md`, Scheibe
/// 3, und #479: „Hier wird `navyProzent` endlich gefüllt. Das Feld liegt
/// seit #203 in `app/lib/shell/messung_detail_zustand.dart:122` und trägt
/// den Kommentar ‚immer `null`, und das ist kein Fehler (#88)'."
///
/// Die Rechnung selbst ist fertig und geprüft
/// (`Packages/trainings_core/lib/src/navy_koerperfett.dart`,
/// `navy_koerperfett_test.dart`). **Diese Datei prüft die Verdrahtung, nicht
/// die Formel** — kein Fall hier rechnet eine Prozentzahl von Hand nach;
/// die Erwartung kommt aus `NavyKoerperfett.prozent`.
///
/// ## Worauf diese Datei zielt
///
/// 1. **Liegen Taille, Hals und Körpergröße vor, steht die Zahl da** —
///    dieselbe, die der Kern rechnet.
/// 2. **Fehlt eines, steht das da, statt eine Zahl zu schätzen** (#479).
///    Und es steht **was** fehlt: „kein Halsmaß" ist eine andere Auskunft
///    als „keine Körpergröße", und beide sind etwas anderes als „noch gar
///    nicht gemessen".
/// 3. **Die Körpergröße kommt aus den Stammdaten**, nicht aus dem
///    Quelltext. Eine Konstante im Code wäre eine Angabe über den Nutzer,
///    die niemand gemacht hat — dasselbe Argument wie
///    bei `Stammdaten.alterAm` („`null`, nicht `0`").
/// 4. **Während die Umfänge gelesen werden, behauptet die Zeile nichts** —
///    weder eine Zahl noch „kein Maßband-Wert" (`01`, #489).
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `messung-detail-navy` | die Zeile „Nach Maßband (Navy)" |
///
/// Der Schlüssel ist **nicht neu**: Er steht seit #203 in
/// `messung_detail_view.dart` und ist in `messung_detail_view_test.dart`
/// festgelegt. Diese Datei füllt ihn, sie erfindet ihn nicht.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Zeile bleibt eine feste Zeile, in jeder Lage.** Das ist die
///   bestehende Zusage aus #203 („feste Zeile, keine Lücke") und die
///   Hausregel „Eine Anzeige, die es gibt, hat genau eine Form".
/// - **Welcher Satz genau dasteht, legt diese Datei nicht fest** — nur,
///   dass die vier Lagen (Zahl · Hals fehlt · Größe fehlt · nichts
///   gemessen) vier unterscheidbare Auskünfte geben und dass in dreien
///   keine Prozentzahl steht.
/// - **Keine neue Erwartung an `messungDetailAus`.** Welchen Weg die drei
///   Zahlen in den Zustand nehmen, ist Sache der Implementierung; die
///   bestehende Erwartung „ohne Umfänge ist `navyProzent` `null`"
///   (`messung_detail_zustand_test.dart`) bleibt gültig und **darf nicht
///   gebrochen werden** — die neuen Angaben gehören also als optionale
///   Parameter hinein, nicht als verpflichtende.
///
/// ## Erfundene Zahlen
///
/// Taille, Hals, Größe und Körperfett hier sind ausgedacht und liegen im
/// Jahr 2099. **Die Körpergröße ist absichtlich keine echte**: Stünde die
/// echte im Test, bestünde er auch gegen eine Konstante im Quelltext.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);

  /// Keine echte Größe — siehe Dateikopf.
  const groesse = 176;
  const taille = 84.0;
  const hals = 39.5;

  final navyZeile = find.byKey(const Key('messung-detail-navy'));

  late AppCache db;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> legeUmfaenge(Map<Umfang, double> werte) =>
      UmfaengeRepository(db, uhr: () => jetzt)
          .schreibeGetippt(tag: _heute, werte: werte);

  Future<void> legeGroesse(int? cm) =>
      StammdatenRepository(db).schreibe(Stammdaten(groesseCm: cm));

  ({ProviderContainer container, Widget app}) harness({
    UmfaengeRepository? repo,
  }) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(const _Waage()),
        if (repo != null) umfaengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: MessungDetailView(art: MessArt.koerperfett),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, {bool warte = true}) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness().app);
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> zeigeMit(
    WidgetTester tester,
    UmfaengeRepository repo, {
    bool warte = true,
  }) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(repo: repo).app);
    if (warte) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  String navyText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: navyZeile,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool traegtZahl(String text) => RegExp(r'\d').hasMatch(text);

  // ───────────────────────────────────────────────────────────────────────

  group('Mit Taille, Hals und Körpergröße', () {
    testWidgets('steht die Zahl da, die der Kern rechnet', (tester) async {
      await legeUmfaenge({Umfang.taille: taille, Umfang.hals: hals});
      await legeGroesse(groesse);

      final erwartet = NavyKoerperfett.prozent(
        tailleCm: taille,
        halsCm: hals,
        groesseCm: groesse.toDouble(),
      );
      expect(
        erwartet,
        isNotNull,
        reason:
            'Vorbedingung: Aus diesen drei Zahlen ergibt sich ein Wert. '
            'Ergäbe er `null`, prüfte der Fall darunter nichts',
      );

      await zeige(tester);

      expect(navyZeile, findsOneWidget);
      expect(
        navyText(tester),
        contains(formatNumber(erwartet!, nachkommastellen: 1)),
        reason:
            'Das Feld `navyProzent` liegt seit #203 da und war „immer '
            '`null`, und das ist kein Fehler (#88)". Mit Scheibe 3 ist es '
            'ein Fehler — die Rechnung steht fertig in '
            '`navy_koerperfett.dart`, es fehlte die Verdrahtung',
      );
    });

    testWidgets('und sie ist als Schätzung benannt, nicht als Befund', (
      tester,
    ) async {
      await legeUmfaenge({Umfang.taille: taille, Umfang.hals: hals});
      await legeGroesse(groesse);
      await zeige(tester);

      final texte = tester
          .widgetList<Text>(find.byType(Text))
          .map(textOf)
          .join(' ')
          .toLowerCase();
      expect(
        texte,
        contains('schätzung'),
        reason:
            '„Keine Diagnose" (`CLAUDE.md`): Der Navy-Wert hat dieselbe Art '
            'Fehler wie der Waagenwert, nur andere. Zwei grobe Schätzungen, '
            'die sich gegenseitig einordnen',
      );
    });
  });

  group('Fehlt eine der drei Angaben', () {
    testWidgets('ohne Halsmaß steht keine Zahl da', (tester) async {
      await legeUmfaenge({Umfang.taille: taille});
      await legeGroesse(groesse);
      await zeige(tester);

      expect(
        navyZeile,
        findsOneWidget,
        reason: 'Die Zeile bleibt eine feste Zeile, keine Lücke (#203)',
      );
      expect(
        traegtZahl(navyText(tester)),
        isFalse,
        reason:
            'Navy braucht Taille **und** Hals. Fehlt eines, steht das da, '
            'statt eine Zahl zu schätzen — und die Rechnung gibt ohnehin '
            '`null` (#479). Gefunden: „${navyText(tester)}"',
      );
    });

    testWidgets('ohne Taillenmaß ebenfalls nicht', (tester) async {
      await legeUmfaenge({Umfang.hals: hals});
      await legeGroesse(groesse);
      await zeige(tester);

      expect(navyZeile, findsOneWidget);
      expect(
        traegtZahl(navyText(tester)),
        isFalse,
        reason: 'Gefunden: „${navyText(tester)}"',
      );
    });

    testWidgets('ohne Körpergröße auch dann nicht, wenn beide Maße da sind', (
      tester,
    ) async {
      await legeUmfaenge({Umfang.taille: taille, Umfang.hals: hals});
      // Kein `legeGroesse` — die Stammdaten sind leer.
      await zeige(tester);

      expect(navyZeile, findsOneWidget);
      expect(
        traegtZahl(navyText(tester)),
        isFalse,
        reason:
            'Die Größe kommt aus den Stammdaten und sonst nirgendwoher. '
            'Steht sie als Konstante im Quelltext, rechnet dieser Fall eine '
            'Zahl aus — und zwar für einen Menschen, dessen Größe niemand '
            'eingetragen hat. Gefunden: „${navyText(tester)}"',
      );
    });

    testWidgets('und die Auskünfte sind unterscheidbar', (tester) async {
      await legeGroesse(groesse);
      await legeUmfaenge({Umfang.taille: taille});
      await zeige(tester);
      final ohneHals = navyText(tester);

      await legeUmfaenge({Umfang.taille: taille, Umfang.hals: hals});
      await legeGroesse(null);
      await zeige(tester);
      final ohneGroesse = navyText(tester);

      expect(
        ohneHals,
        isNot(ohneGroesse),
        reason:
            '„Fehlt eines, steht das da" (#479) — welches, gehört dazu. '
            'Sonst sucht Tim das Maßband, obwohl die Körpergröße fehlt',
      );
    });
  });

  group('Während die Umfänge gelesen werden', () {
    testWidgets('behauptet die Zeile weder eine Zahl noch „kein '
        'Maßband-Wert"', (tester) async {
      await legeUmfaenge({Umfang.taille: taille, Umfang.hals: hals});
      await legeGroesse(groesse);

      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeMit(tester, _HaengendesRepo(db, antwort), warte: false);

      expect(
        navyZeile,
        findsOneWidget,
        reason: 'Die Zeile steht in jeder Lage da',
      );
      final text = navyText(tester);
      expect(
        traegtZahl(text),
        isFalse,
        reason: 'Noch ist nichts gelesen. Gefunden: „$text"',
      );
      expect(
        RegExp(
          r'kein maßband|nicht gemessen|keine umfänge',
          caseSensitive: false,
        ).hasMatch(text),
        isFalse,
        reason:
            'Ob Taille und Hals vorliegen, weiß die App jetzt nicht — das '
            'ist `01`, und in dieser Scheibe schon zweimal das Loch '
            'gewesen (#489). Gefunden: „$text"',
      );

      antwort.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('ist der Lauf durch, darf die Auskunft kommen', (
      tester,
    ) async {
      // Die Gegenprobe: Der Fall oben darf sich nicht dadurch erledigen
      // lassen, dass die Auskunft ganz verschwindet.
      final antwort = Completer<List<Umfangsmessung>>();
      await zeigeMit(tester, _HaengendesRepo(db, antwort), warte: false);
      final beimLaden = navyText(tester);

      antwort.complete(const []);
      await tester.pumpAndSettle();

      expect(
        navyText(tester),
        isNot(beimLaden),
        reason:
            'Jetzt ist bekannt, dass kein Maßband-Wert vorliegt — und jetzt '
            'gehört es auch dagestanden',
      );
    });
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt.
class _HaengendesRepo extends UmfaengeRepository {
  _HaengendesRepo(super.db, this.antwort);

  final Completer<List<Umfangsmessung>> antwort;

  @override
  Future<List<Umfangsmessung>> messungen({String? abTag, String? bisTag}) =>
      antwort.future;

  @override
  Future<String?> letzterMesstag() async => null;
}

/// Eine Waage mit erfundenen Körperfettwerten — damit der Schirm nicht im
/// Ladezustand steht und die Navy-Zeile neben einem Waagenwert liegt, so
/// wie `docs/SPEC.md` 4.6 es verlangt.
class _Waage extends HealthReadingAttrappe {
  const _Waage();

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => [
    DailyMetrics(tag: _gestern, weightKg: 71.4, bodyFatPct: 18.3),
    DailyMetrics(tag: _heute, weightKg: 71.1, bodyFatPct: 18.1),
  ];
}
