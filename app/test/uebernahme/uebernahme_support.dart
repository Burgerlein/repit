import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/health/health_provider.dart'
    show appCacheProvider;
import 'package:repit/uebernahme/export_datei.dart';
import 'package:repit/uebernahme/uebernahme_view.dart';

import '../gym/log_support.dart' show allesText, textVon;

/// Gemeinsame Hülle, Schlüssel und Fakes der Widget-Tests zum Schirm
/// **„Daten übernehmen"** (#59 Teil 1, mit #482),
/// `lib/uebernahme/uebernahme_view.dart`.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
/// Abschnitte 7 bis 9. Geschrieben **ohne** den späteren Schirm gesehen zu
/// haben. **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`): Diese Datei darf benutzt, aber nicht verändert werden.
///
/// ## Festgelegte öffentliche API — Entscheidung des Test-Agenten
///
/// ```dart
/// // lib/uebernahme/export_datei.dart
/// class ExportDatei { const ExportDatei({required String name, required Uint8List bytes}); }
/// abstract class ExportDateiWaehler { Future<ExportDatei?> waehle(); } // null = abgebrochen
/// final exportDateiWaehlerProvider = Provider<ExportDateiWaehler>(…);
///
/// // lib/uebernahme/uebernahme_view.dart
/// class UebernahmeSeite extends ConsumerWidget { const UebernahmeSeite({super.key}); }
/// void oeffneUebernahme(AppRouter router);   // AppTarget.aktuell
/// ```
///
/// Gelesen und geschrieben wird über `gymRepositoryProvider` (also
/// `GymRepository.uebernimm`); gewählt wird über `exportDateiWaehlerProvider`.
///
/// ### Schlüssel (verbindlich)
///
/// | Schlüssel | Was |
/// |---|---|
/// | `uebernahme-waehlen` | der Knopf „Exportdatei wählen" — **steht in jedem Zustand** |
/// | `uebernahme-umfang` | der Hinweis, was **nicht** übernommen wird — **steht in jedem Zustand** |
/// | `uebernahme-leer` | die Meldung „noch nichts übernommen" — nur vor dem ersten Lauf |
/// | `uebernahme-laeuft` | die Meldung „wird eingelesen" — nur während des Laufs |
/// | `uebernahme-fertig` | die Meldung „übernommen" — nur nach einem Lauf |
/// | `uebernahme-abgelehnt` | die Meldung mit dem Grund — nur nach einer abgelehnten Datei |
/// | `uebernahme-gescheitert` | die Meldung „konnte nicht geschrieben werden" — nur, wenn die Ablage scheiterte |
/// | `uebernahme-ergebnis` | die Karte mit den fünf Zahlen — **steht in jedem Zustand** |
/// | `uebernahme-zahl-in-datei` / `-neu` / `-schon-da` / `-nicht-uebernommen` / `-nicht-lesbar` | der **Wertplatz**: nur die Zahl, ohne Beschriftung; ungefüllt (`–/–`), solange es keinen Lauf gibt, der eine Zahl hergibt |
/// | `uebernahme-auslassung-<id>` | eine Zeile je Sitzung, die wegen **belegtem Tag und Workout** oder als **Dublette** nicht übernommen wurde |
/// | `uebernahme-nicht-lesbar-<n>` | eine Zeile je nicht lesbarer Sitzung, `<n>` ist die Position in der Datei ab 0 |
/// | `uebernahme-unbekannt` | der Hinweis auf Übungen/Workouts, die der Katalog nicht kennt — **nur**, wenn es welche gibt |
/// | `uebernahme-ungelesen` | der Hinweis auf Stände, die dieser Schritt nicht liest — **nur**, wenn die Datei welche trug |
/// | `uebernahme-zeitzone` | der Hinweis auf eine andere Zeitzone als Berlin — **nur**, wenn sie abweicht |
///
/// **Genau eine** der fünf Meldungen (`leer`, `laeuft`, `fertig`,
/// `abgelehnt`, `gescheitert`) steht zugleich da.

/* ---- Schlüssel ------------------------------------------------------- */

const kUebernahmeWaehlen = Key('uebernahme-waehlen');
const kUebernahmeUmfang = Key('uebernahme-umfang');
const kUebernahmeLeer = Key('uebernahme-leer');
const kUebernahmeLaeuft = Key('uebernahme-laeuft');
const kUebernahmeFertig = Key('uebernahme-fertig');
const kUebernahmeAbgelehnt = Key('uebernahme-abgelehnt');
const kUebernahmeGescheitert = Key('uebernahme-gescheitert');
const kUebernahmeErgebnis = Key('uebernahme-ergebnis');
const kUebernahmeUnbekannt = Key('uebernahme-unbekannt');
const kUebernahmeUngelesen = Key('uebernahme-ungelesen');
const kUebernahmeZeitzone = Key('uebernahme-zeitzone');

const kZahlInDatei = Key('uebernahme-zahl-in-datei');
const kZahlNeu = Key('uebernahme-zahl-neu');
const kZahlSchonDa = Key('uebernahme-zahl-schon-da');
const kZahlNichtUebernommen = Key('uebernahme-zahl-nicht-uebernommen');
const kZahlNichtLesbar = Key('uebernahme-zahl-nicht-lesbar');

const alleZahlen = [
  kZahlInDatei,
  kZahlNeu,
  kZahlSchonDa,
  kZahlNichtUebernommen,
  kZahlNichtLesbar,
];

const alleMeldungen = [
  kUebernahmeLeer,
  kUebernahmeLaeuft,
  kUebernahmeFertig,
  kUebernahmeAbgelehnt,
  kUebernahmeGescheitert,
];

Key kUebernahmeAuslassung(String id) => Key('uebernahme-auslassung-$id');
Key kUebernahmeNichtLesbar(int index) => Key('uebernahme-nicht-lesbar-$index');

const kHuelleOeffnen = Key('uebernahme-huelle-oeffnen');
const kHuelleDetail = Key('uebernahme-huelle-detail');

final eineZiffer = RegExp(r'\d');

/* ---- Fakes ----------------------------------------------------------- */

/// Der Dateiwähler, den der Test steuert: Er liefert [naechste] (oder `null`
/// für „abgebrochen") und zählt, wie oft gefragt wurde. Ein [tor] hält ihn an.
class FakeWaehler implements ExportDateiWaehler {
  ExportDatei? naechste;
  int aufrufe = 0;
  Completer<void>? tor;

  @override
  Future<ExportDatei?> waehle() async {
    aufrufe++;
    await tor?.future;
    return naechste;
  }
}

/// Die echte Ablage mit Haken: [tor] hält das Schreiben an, [scheitert]
/// lässt es scheitern, [uebernahmen] zählt die Aufrufe.
class UebernahmeAblage extends GymRepository {
  UebernahmeAblage(super.db);

  Completer<void>? tor;
  bool scheitert = false;
  int uebernahmen = 0;

  @override
  Future<GymUebernahme> uebernimm(List<ImportedSession> sitzungen) async {
    uebernahmen++;
    await tor?.future;
    if (scheitert) {
      throw StateError('Die Platte ist voll (vom Test erzwungen)');
    }
    return super.uebernimm(sitzungen);
  }
}

/* ---- Hülle ----------------------------------------------------------- */

class UebernahmeHuelle {
  UebernahmeHuelle({
    required this.container,
    required this.db,
    required this.ablage,
    required this.waehler,
    required this.app,
  });

  final ProviderContainer container;
  final AppCache db;
  final UebernahmeAblage ablage;
  final FakeWaehler waehler;
  final Widget app;

  /// Was in der Ablage steht — über eine **eigene** Ablage gelesen.
  Future<List<ImportedSession>> sitzungen() => GymRepository(db).sitzungen();

  Future<void> fuelle(Iterable<ImportedSession> sitzungen) async {
    for (final s in sitzungen) {
      await GymRepository(db).legeAb(s);
    }
  }

  /// Stellt die Datei bereit, die der Wähler beim nächsten Tippen liefert.
  void waehleDatei(Uint8List bytes, {String name = 'trainingsexport.json'}) {
    waehler.naechste = ExportDatei(name: name, bytes: bytes);
  }
}

UebernahmeHuelle uebernahmeHuelle() {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final ablage = UebernahmeAblage(db);
  final waehler = FakeWaehler();

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      gymRepositoryProvider.overrideWithValue(ablage),
      exportDateiWaehlerProvider.overrideWithValue(waehler),
    ],
  );
  addTearDown(container.dispose);

  final app = UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
        child: child!,
      ),
      home: const _Uebersicht(),
    ),
  );

  return UebernahmeHuelle(
    container: container,
    db: db,
    ablage: ablage,
    waehler: waehler,
    app: app,
  );
}

class _Uebersicht extends StatelessWidget {
  const _Uebersicht();

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: CupertinoButton(
        key: kHuelleOeffnen,
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const UebernahmeSeite()),
        ),
        child: const Text('Übernahme'),
      ),
    ),
  );
}

/// Ein Test mit Hülle — **immer** sauber abgebaut.
void uebernahmeTest(
  String name,
  Future<void> Function(WidgetTester tester, UebernahmeHuelle h) body,
) {
  testWidgets(name, (tester) async {
    final h = uebernahmeHuelle();
    try {
      await body(tester, h);
    } finally {
      for (final tor in [h.ablage.tor, h.waehler.tor]) {
        if (tor != null && !tor.isCompleted) tor.complete();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      h.container.dispose();
    }
  });
}

/* ---- Bedienung ------------------------------------------------------- */

/// Pumpt die App auf einer iPhone-breiten, hohen Fläche und öffnet den
/// Schirm. **Nicht `pumpAndSettle`:** Solange ein Tor etwas hält, kann eine
/// Animation nie enden.
Future<void> zeigeUebernahme(WidgetTester tester, UebernahmeHuelle h) async {
  tester.view.physicalSize = const Size(402, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(h.app);
  await tester.pump();
  await tester.tap(find.byKey(kHuelleOeffnen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> verstreiche(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Tippt „Exportdatei wählen" und lässt alles ablaufen.
Future<void> waehle(WidgetTester tester) async {
  await tester.tap(find.byKey(kUebernahmeWaehlen));
  await verstreiche(tester);
  await verstreiche(tester);
}

/* ---- Lesehilfen ------------------------------------------------------ */

/// Welche der fünf Meldungen im Baum stehen.
List<Key> stehendeMeldungen() => [
  for (final k in alleMeldungen)
    if (find.byKey(k).evaluate().isNotEmpty) k,
];

String zahlText(WidgetTester tester, Key zahl) =>
    textVon(tester, zahl).trim();

String meldungText(WidgetTester tester, Key meldung) =>
    textVon(tester, meldung);

String alleTexte(WidgetTester tester) => allesText(tester);

/// Alle fünf Wertplätze tragen `–/–` und keine Ziffer.
void erwarteUngefuellt(WidgetTester tester, {String? warum}) {
  for (final z in alleZahlen) {
    expect(find.byKey(z), findsOneWidget, reason: '$z steht in jedem Zustand');
    expect(
      zahlText(tester, z),
      ohneWert,
      reason: '${warum ?? ''} $z: ungefüllt, keine Zahl',
    );
    expect(zahlText(tester, z), isNot(matches(eineZiffer)));
  }
}
