import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart';

/// Gemeinsame Hilfen und der **Vertrag** der Widget-Tests zu **`MuskelFigur`**
/// (#533 unter #531, Task 2.1 des Plans `docs/superpowers/plans/2026-11-19-
/// eigene-trainings-plan.md`; Spec 7.2, 7.5, 8.1).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Dateien dürfen ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Woher die Anforderung kommt
///
/// Spec 8.1 legt die Form des Bausteins fest — `MuskelFigur(gefaerbt:,
/// seite:, semantik:)`, `seite: null` zeigt beide Hälften — und sagt:
/// „**Testbar ohne Pixel:** Der Painter trägt die gefärbte Menge als
/// Eigenschaft; der Test liest sie, vergleicht keine Bilder." Die Pfaddaten
/// stehen in `docs/screens/figure-data.js` (maschinell aus
/// `MuscleFigureData.swift` gezogen, nicht abgetippt); **diese Tests lesen
/// dieselbe Datei**, um zu wissen, welcher Muskel auf welcher Seite liegt und
/// wie viele Pfade er dort hat — Test und Implementierung sprechen so von
/// derselben Quelle (Plan, Lücke 8). `MuskelSeite` gibt es seit Task 1.9.
///
/// ## Der Vertrag — **Festlegung des Test-Agenten, Tim hat sie nicht gesehen**
///
/// Die Spec nennt die Form des Widgets, **nicht** den Painter und nicht die
/// Schlüssel. Damit sich „der Painter trägt die gefärbte Menge" prüfen lässt,
/// legen diese Tests fest:
///
/// ```dart
/// // app/lib/design/muskel_figur.dart
/// class MuskelFigur extends StatelessWidget {          // Spec 8.1
///   const MuskelFigur({
///     super.key,
///     required Map<Muscle, Color> gefaerbt,   // fehlt ein Muskel: Linienton
///     MuskelSeite? seite,                     // null = beide Hälften
///     required String semantik,               // vom Aufrufer gerechnet
///   });
/// }
///
/// /// Eine Zeichenfläche je gezeigte Seite.
/// class MuskelFigurPainter extends CustomPainter {
///   MuskelFigurPainter({required this.gefaerbt, required this.seite});
///   final Map<Muscle, Color> gefaerbt;
///   final MuskelSeite seite;
///
///   /// Je Muskel die Zahl seiner Pfade auf [seite] — **eine Körperhälfte**,
///   /// die Spiegelung zählt nicht doppelt; Haut (ohne Zuordnung) steht nicht
///   /// darin. Ein Muskel ohne Pfad auf dieser Seite fehlt in der Map.
///   static Map<Muscle, int> pfadeJeMuskel(MuskelSeite seite);
///
///   /// Die Muskeln, die dieser Painter wirklich färbt: [gefaerbt] ∩ die
///   /// Muskeln mit mindestens einem Pfad auf [seite].
///   Set<Muscle> get gefaerbteMuskeln;
///
///   /// Wie viele Pfade (eine Körperhälfte) dieser Painter färbt — die Summe
///   /// von [pfadeJeMuskel] über [gefaerbteMuskeln].
///   int get gefaerbtePfade;
///
///   // ==/hashCode über [gefaerbt] (inhaltlich, samt Farben) und [seite];
///   // shouldRepaint(alt) == (alt != this).
/// }
/// ```
///
/// **Schlüssel:** `muskel-figur-vorne` und `muskel-figur-hinten` stehen auf
/// dem **`CustomPaint`** je gezeigter Hälfte ([kMuskelFigurSeite]); wer
/// `seite: vorne` übergibt, hat nur den ersten, wer `null` übergibt, beide.
/// `CustomPaint.painter` ist ein [MuskelFigurPainter].
///
/// **Der Vorlesetext ist der des Aufrufers** ([MuskelFigur.semantik]): Der
/// Baustein trägt ihn als **einen** `Semantics`-Knoten und schließt seine
/// Kinder aus (die Beschriftungen „VORNE"/„HINTEN" lesen sich nicht einzeln
/// vor). Welche Muskeln der Text nennt, rechnet der Aufrufer — geprüft wird
/// das in den Tests der Übersicht und des Details, nicht hier.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Pixel und Farben** der Bilder. Auch nicht, *welche* Farbe ein Muskel
///   bekommt: Die Zuordnung wählt der Aufrufer (Spec 8.1: „eine zweite
///   Farblogik wäre eine falsche Auskunft").
/// - **Die Beschriftung „VORNE"/„HINTEN"** — Beschriftung, kein Verhalten.
/// - **Die Pfadgeometrie.** Die Daten sind erzeugt, nicht abgetippt; der
///   Generator hat seinen eigenen Prüfpunkt (Plan 2.1).
///
/// **Alle Farben hier sind erfunden.**

/// Der Schlüssel der Zeichenfläche einer Seite.
Key kMuskelFigurSeite(MuskelSeite seite) =>
    Key('muskel-figur-${seite == MuskelSeite.vorne ? 'vorne' : 'hinten'}');

/// Die Pfaddaten des Boards — dieselbe Datei, die der Generator liest.
///
/// Gelesen wird relativ zu `app/` (dort läuft `flutter test`).
Map<String, Object?> figurDaten() {
  final datei = File('../docs/screens/figure-data.js');
  expect(
    datei.existsSync(),
    isTrue,
    reason: '`docs/screens/figure-data.js` ist die Quelle der Pfade',
  );
  final text = datei.readAsStringSync();
  final anfang = text.indexOf('{', text.indexOf('export default'));
  final ende = text.lastIndexOf('}') + 1;
  return jsonDecode(text.substring(anfang, ende)) as Map<String, Object?>;
}

/// Je Muskel die Zahl der Pfade auf [seite], **eine Körperhälfte** — aus der
/// Datei gelesen, nicht aus der Implementierung. Haut zählt nicht.
Map<Muscle, int> erwartetePfade(MuskelSeite seite) {
  final daten = figurDaten();
  final rumpf =
      daten[seite == MuskelSeite.vorne ? 'front' : 'back']! as List<Object?>;
  final arm =
      daten[seite == MuskelSeite.vorne ? 'armFront' : 'armBack']!
          as List<Object?>;
  final ergebnis = <Muscle, int>{};
  for (final eintrag in [...rumpf, ...arm]) {
    final name = (eintrag! as List<Object?>).first as String?;
    if (name == null) continue;
    final muskel = Muscle.values.singleWhere((m) => m.german == name);
    ergebnis[muskel] = (ergebnis[muskel] ?? 0) + 1;
  }
  return ergebnis;
}

/// Wie viele Pfade auf [seite] Haut ohne Zuordnung sind (Rumpf und Arm).
int hautPfade(MuskelSeite seite) {
  final daten = figurDaten();
  final rumpf =
      daten[seite == MuskelSeite.vorne ? 'front' : 'back']! as List<Object?>;
  final arm =
      daten[seite == MuskelSeite.vorne ? 'armFront' : 'armBack']!
          as List<Object?>;
  return [
    ...rumpf,
    ...arm,
  ].where((e) => (e! as List<Object?>).first == null).length;
}

/// Die Muskeln mit mindestens einem Pfad auf [seite].
Set<Muscle> muskelnAuf(MuskelSeite seite) => erwartetePfade(seite).keys.toSet();

/// Zwei erfundene Farben.
const rot = Color(0xFFC0392B);
const blau = Color(0xFF2E86C1);

/// Alle Muskeln in einer Farbe.
Map<Muscle, Color> alleMuskeln([Color farbe = rot]) => {
  for (final m in Muscle.values) m: farbe,
};

/// Baut [figur] in einer Cupertino-App mit Platz.
Future<void> zeigeFigur(WidgetTester tester, Widget figur) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(child: Center(child: figur)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Der Painter der gezeigten Hälfte [seite].
MuskelFigurPainter painterVon(WidgetTester tester, MuskelSeite seite) {
  final flaeche = tester.widget<CustomPaint>(
    find.byKey(kMuskelFigurSeite(seite)),
  );
  expect(
    flaeche.painter,
    isA<MuskelFigurPainter>(),
    reason: 'Der Schlüssel steht auf dem `CustomPaint` mit dem Painter',
  );
  return flaeche.painter! as MuskelFigurPainter;
}

/// Ein `testWidgets` mit eingeschalteter Semantik. Das Handle wird **im**
/// Test freigegeben: Ein `addTearDown` liefe erst nach der Prüfung des
/// Testrahmens, und die verlangt, dass kein Handle mehr offen ist.
void testSemantik(
  String beschreibung,
  Future<void> Function(WidgetTester tester) test,
) => testWidgets(beschreibung, (tester) async {
  final handle = tester.ensureSemantics();
  try {
    await test(tester);
  } finally {
    handle.dispose();
  }
});
