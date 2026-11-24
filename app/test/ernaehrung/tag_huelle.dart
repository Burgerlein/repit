import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Die Hülle um den Ernährungs-Tag-Schirm für die Tests der Nacht-Runde
/// vom 04.11.2026 (#311 Wasser, #312 Verlauf, #314 Herleitung, #359
/// Rezepte) — **Testhilfe, kein Test.**
///
/// Dieselbe Bauart wie die Hülle in `ernaehrung_view_test.dart`, aber als
/// eigene Datei: Jene ist eine Testvorgabe und hält ihre Hülle privat. Vier
/// neue Dateien mit je einer Kopie wären vier Stellen, die auseinanderlaufen.
///
/// Geschrieben vom Test-Agenten; nicht von Tim gesehen.
///
/// **Alle Zahlen erfunden** — runde Werte, keine aus dem Entwurf.
typedef TagHuelle = ({ProviderContainer container, AppCache db, Widget app});

/// Vollständige Stammdaten, damit ein Kalorienziel berechenbar ist.
const huelleStammdaten = Stammdaten(
  groesseCm: 180,
  geburtsjahr: 1990,
  zielgewichtKg: 84,
  zieldatum: '2027-01-14',
);

/// Baut die Hülle.
///
/// - [quelle]: die Health-Quelle; ohne Angabe eine, die nichts liefert
///   und nichts kann außer den Zeitraum-Methoden.
/// - [tageswerte]: was `dailyMetricsProvider` liefert. Ohne Angabe
///   `Bekannt([])` — ein fertiger Lauf ohne Tageswerte.
/// - [router]: ohne ihn baut `ErnaehrungView` ohne Türen.
/// - [zusaetzlich]: weitere Overrides, nach den eigenen.
TagHuelle tagHuelle({
  required DateTime jetzt,
  Messwert<List<DailyMetrics>>? tageswerte,
  Stammdaten stammdaten = huelleStammdaten,
  HealthReading? quelle,
  AppCache? datenbank,
  AppRouter? router,
  List<Override> zusaetzlich = const [],
}) {
  final db = datenbank ?? AppCache(NativeDatabase.memory());
  if (datenbank == null) addTearDown(db.close);

  // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => jetzt),
      healthProvider.overrideWithValue(quelle ?? const HealthReadingAttrappe()),
      stammdatenProvider.overrideWith(() => HuelleStammdaten(stammdaten)),
      dailyMetricsProvider.overrideWith(
        () => HuelleTageswerte(
          tageswerte ??
              Bekannt<List<DailyMetrics>>(
                const [],
                stand: jetzt,
                laeuft: false,
              ),
        ),
      ),
      fremdeMahlzeitenProvider.overrideWith2(
        (tag) =>
            HuelleFremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
      ),
      ...zusaetzlich,
    ],
  );
  addTearDown(container.dispose);

  return (
    container: container,
    db: db,
    app: BehaelterImBaum(
      container: container,
      child: CupertinoApp(
        home: CupertinoPageScaffold(child: ErnaehrungView(router: router)),
      ),
    ),
  );
}

/// Pumpt [app] auf einer Fläche, auf der der ganze Schirm auf einmal
/// gebaut ist — kein Fall muss selbst scrollen.
Future<void> zeigeTag(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// `true`, wenn ein Vorfahre ein `GestureDetector` mit `onTap` oder ein
/// `CupertinoButton` mit `onPressed` ist — wörtlich wie in
/// `ernaehrung_view_test.dart`.
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

/// Alle Texte unter [key], zusammengefügt — auch `Text.rich`.
String texteUnter(WidgetTester tester, Key key) => [
  for (final element
      in find
          .descendant(of: find.byKey(key), matching: find.byType(RichText))
          .evaluate())
    (element.widget as RichText).text.toPlainText(),
].join(' ');

/// Was VoiceOver an der Stelle [key] vorliest — aus dem **Semantikbaum**,
/// nicht aus den `Semantics`-Widgets: Ein äußeres `Semantics` mit
/// `excludeSemantics: true` verdeckt die inneren, und nur der Baum zeigt,
/// was tatsächlich ankommt. Zusammengeführte Kinder zählen mit.
Future<String> vorlesetext(WidgetTester tester, Key key) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final knoten = tester.getSemantics(find.byKey(key));
    final teile = <String>[knoten.label];
    knoten.visitChildren((kind) {
      teile.add(kind.label);
      return true;
    });
    return teile.where((t) => t.isNotEmpty).join(' | ');
  } finally {
    handle.dispose();
  }
}

class HuelleTageswerte extends DailyMetricsNotifier {
  HuelleTageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class HuelleStammdaten extends StammdatenNotifier {
  HuelleStammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class HuelleFremde extends FremdeMahlzeitenNotifier {
  HuelleFremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}
