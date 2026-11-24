import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/formatierung.dart';
import 'package:repit/design/hypnogramm.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/health/health_types.dart';

import 'support.dart';

/// Tests für das Hypnogramm: `SchlafPhasen`, `HypnogrammGeometrie`,
/// `Hypnogramm` und `HypnogrammPainter` (Ticket #116, Vorlagen
/// `Sources/Features/Recovery/NightCharts.swift` und `SleepChart.swift`,
/// Aufbau und Beschriftung aus `docs/prototype/erholung-alles.html` und
/// `docs/screens/components.js` (`hypnogram`)).
///
/// ## Die öffentliche API, die diese Datei festschreibt
///
/// ```dart
/// /// Namen, Farben und Spuren der Schlafphasen.
/// abstract final class SchlafPhasen {
///   /// Reihenfolge wie bei Apple: wach oben, Tiefschlaf unten.
///   static const List<SleepStage> reihenfolge =
///       [SleepStage.awake, SleepStage.rem, SleepStage.core, SleepStage.deep];
///   static String name(SleepStage phase);              // Wach · REM · Kern · Tief · Schlaf
///   static CupertinoDynamicColor farbe(SleepStage);    // wach · iron · river · deep · river2
///   static int spurIndex(SleepStage phase);            // unspecified → Kern-Spur
/// }
///
/// /// Das Schlaffenster und die Lage eines Zeitpunkts darin — reine Rechnung.
/// class HypnogrammGeometrie {
///   HypnogrammGeometrie(SleepSession session);
///   DateTime? get von;        // Beginn des ersten Abschnitts
///   DateTime? get bis;        // Ende des spätesten Abschnitts
///   Duration get fenster;     // Dauer; ohne Abschnitte Duration.zero
///   bool get leer;            // keine Abschnitte oder Fenster ohne Dauer
///   double anteil(DateTime zeitpunkt);  // 0..1, geklemmt
/// }
///
/// class Hypnogramm extends StatelessWidget {
///   const Hypnogramm({super.key, required SleepSession session, bool kompakt = true});
/// }
///
/// class HypnogrammPainter extends CustomPainter {
///   HypnogrammPainter({
///     required List<SleepSegment> abschnitte,
///     required Map<SleepStage, Color> farben,  // **aufgelöst**, nicht dynamisch
///     required Color fensterFarbe,             // **aufgelöst**
///     required bool kompakt,
///   });
/// }
/// ```
///
/// ### Nachtrag 27.10.2026 — die Wach-Farbe ist `--wake`, nicht `--warn`
///
/// Diese Datei schrieb für `SleepStage.awake` ursprünglich `Palette.warn`
/// fest (#A33B3B hell, dunkles Backsteinrot). Das war falsch, und der
/// Umsetzende hat es richtig abgeschrieben: **Spec und Ticket #116 sagen an
/// dieser Stelle „Wach `--warn`" — beide irren.** Die beiden Vorlagen, die
/// der Prototyp und Swift sind, stimmen miteinander überein und sagen etwas
/// anderes:
///
/// | Quelle | Wert |
/// |---|---|
/// | `docs/prototype/erholung-alles.html:16,23` | `--wake:#E8735A`, hell **wie** dunkel |
/// | `Sources/Features/Recovery/SleepChart.swift:19` | `Color(red: 0.91, green: 0.45, blue: 0.35)` = #E8735A |
/// | `docs/prototype/erholung-alles.html:14,21` | `--warn:#A33B3B` hell, `#E07A7A` dunkel |
///
/// Aufgefallen ist es daran, dass `lib/design/ring_karte.dart` für
/// **denselben** Begriff bereits eine eigene private Konstante
/// `_wach = 0xFFE8735A` trug — das Unterbrechungs-Segment des Schlaf-Rings.
/// Auf dem Erholung-Schirm stand damit oben ein Lachston und direkt darunter
/// derselbe Begriff in Backsteinrot: **ein Schirm, ein Begriff, zwei
/// Farben.**
///
/// **Tims Entscheidung vom 27.10.2026: vereinheitlichen auf #E8735A.**
///
/// ### Wo der Ton lebt: `Palette.wach`
///
/// Entscheidung dieser Testdatei (`wach_farbe_test.dart` hält sie fest).
/// Das Gegenargument lautet, `Palette` sei die wörtliche Entsprechung von
/// `Palette.swift` und kenne den Ton nicht — so begründet es die private
/// Konstante in `ring_karte.dart` selbst. Es trägt nicht:
///
/// - **Der Prototyp ist die verbindliche Referenz für die Palette**
///   (`CLAUDE.md`, „Design"), und er deklariert `--wake` im selben
///   `:root`-Block wie `--warn`. Dort *ist* der Ton Teil der Palette.
/// - **Swift kennt den Ton sehr wohl** — nur zweimal hartcodiert
///   (`SleepChart.swift`, `RecoveryRings.swift`), weil es keinen
///   Palette-Eintrag dafür gibt. Das ist die Schwäche der Vorlage, kein
///   Vorbild.
/// - Eine gemeinsame Konstante **außerhalb** von `Palette` wäre auch in
///   Ordnung (`CLAUDE.md` verlangt nur *eine* Stelle), aber sie bräuchte ein
///   zweites Zuhause für genau einen Wert. Dafür gibt es keinen Grund.
///
/// Damit verschwindet `_wach` aus `ring_karte.dart`; beide Stellen lesen
/// `Palette.wach`. Der Ton ist in hell und dunkel **derselbe** — das ist
/// kein vergessener Dunkelmodus, sondern steht so im Prototyp.
///
/// ### Warum der Schnitt so ist
///
/// **Der Baustein nimmt `SleepSession` aus `lib/health/health_types.dart`
/// entgegen** und erfindet keinen eigenen Werttyp. Die Nächte kommen fertig
/// gruppiert aus dem Kanal; `SleepGrouping` wird nicht nach Dart portiert
/// (Spec Abschnitt 1). Ein Zwischentyp wäre eine zweite Wahrheit über
/// dieselbe Nacht.
///
/// **Der Painter ist öffentlich und bekommt bereits aufgelöste Farben.**
/// Nur so lässt sich prüfen, was `CLAUDE.md` verlangt — dass die Farben für
/// hell **und** dunkel aufgelöst sind —, ohne Pixel zu vergleichen. Eine
/// unaufgelöste `CupertinoDynamicColor` bliebe im Dunkelmodus auf ihrer
/// hellen Variante stehen, und das sieht man einem Testlauf ohne diese
/// Prüfung nicht an.
///
/// **Das Schlaffenster geht über *alle* Abschnitte, auch die wachen** —
/// anders als `SleepSession.start`/`.end` in Swift, die nur die
/// Schlafabschnitte zählen (Wachliegen am Rand gehört nicht zur
/// Schlafdauer). Für die **Dauer** ist das richtig, für das **Bild** nicht:
/// #116 verlangt, dass auch eine reine Wachnacht gezeichnet wird, und die
/// hätte nach der Schlafdefinition gar kein Fenster. Die Entscheidung ist
/// weder in Ticket noch Spec vorgegeben und steht deshalb hier.
///
/// **Die Striche für Uhrzeiten laufen über `Format`** (`lib/design/
/// formatierung.dart`), nicht über `DateFormat` oder `toString` — sonst
/// steht auf einem englisch eingestellten Gerät die falsche Sprache mitten
/// im deutschen Text.
///
/// Nicht hier, sondern in #115: die Nachtkarte darum herum (eine Zeile aus
/// Dauer, Bewertung und Schlaffenster, „Letzte Nacht · 5:35 h · Score 58").
///
/// ### Nachtrag 27.10.2026 (1) — die Blöcke sind abgerundet
///
/// **Das dreht die Entscheidung aus #116 um.** Der Umsetzende hat sie
/// damals so begründet, und die Begründung steht bis heute im Painter:
/// „Erst das Schlaffenster als abgerundete Säule, dann die Phasen
/// scharfkantig darauf: abgerundete Einzelsegmente werden sonst zur
/// Perlenkette, in der kein Block mehr an seiner Länge zu lesen ist."
///
/// Tim hat den gebauten Schirm gegen das Entwurfsboard gehalten und
/// **anders entschieden** (27.10.2026): Es gilt, was `hypnogram()` in
/// `docs/screens/components.js` zeichnet — eine durchgehende graue Spur je
/// Zeile (`var(--ink)` bei 5 % Deckkraft, über die volle Breite) und darauf
/// **abgerundete Einzelblöcke** mit `rx = block / 2`. Das Board ist die
/// Vorlage, nicht die Skizze; wo gebauter Schirm und Board sich
/// widersprechen, wird der Schirm nachgezogen.
///
/// Die Perlenketten-Sorge bleibt richtig und ist kein Gegenargument mehr:
/// Sie beschreibt, was passiert, wenn man *nur* die Blöcke rundet. Die Spur
/// darunter läuft durch und trägt die Zeile weiter, auch wo die Blöcke kurz
/// sind — deshalb gehören beide zusammen, und deshalb prüft der Test
/// **beides** in einem Zug.
///
/// Geprüft wird das über die Zeichenaufrufe (`paints`), nicht über Pixel:
/// **kein einziger `drawRect`** (jeder scharfkantige Block wäre einer), und
/// die Blöcke liegen als `RRect` mit halbem Balkenradius an ihrer Stelle.
///
/// ### Nachtrag 27.10.2026 (2) — „Tief" bleibt dunkler als „Kern"
///
/// Auf dem Board ist Tief fast schwarz und Kern graublau; in der App kippte
/// das im Dunkelmodus um, weil `SchlafPhasen.farbe(deep)` auf `Palette.deep`
/// zeigt und `--deep` im Dunkelmodus das **hellste** Blau der Palette ist
/// (`#9FE4FF`, heller als `--river` mit `#5CD2FF`). Eine Tiefenlesart, die
/// sich beim Umschalten umdreht, ist keine.
///
/// **Das ist ein echter Widerspruch zwischen zwei Vorgaben** und wird hier
/// entschieden: `palette_test.dart` nagelt `Palette.deep` auf den Wert aus
/// `tokens.css` fest (das gilt weiter, für Ringe und alles andere) — das
/// Hypnogramm bekommt dafür einen **eigenen** Ton für „Tief", der in beiden
/// Modi dunkler ist als „Kern". Das Board hält ihn bereits:
/// `--river-dark` ist hell `#173F54` (**derselbe** Wert, den `--deep` hell
/// trägt, im Hellmodus ändert sich also nichts) und dunkel `#06303F`.
/// Diese Datei schreibt die **Regel** fest, nicht den Token-Namen: Wer
/// stattdessen einen neuen Palette-Eintrag anlegt, erfüllt sie ebenso.
///
/// **Alle Zeiten und Phasen unten sind erfunden** — keine echten
/// Schlafdaten, auch nicht aus dem Demo-Datensatz.
void main() {
  // Eine erfundene Nacht mit allen vier Phasen, 22:40 bis 05:20.
  DateTime t(int stunde, int minute) => DateTime(2026, 3, 17, stunde, minute);
  DateTime t2(int stunde, int minute) => DateTime(2026, 3, 18, stunde, minute);

  SleepSession nachtMitVierPhasen() => SleepSession(
    segments: [
      SleepSegment(stage: SleepStage.awake, start: t(22, 40), end: t(22, 52)),
      SleepSegment(stage: SleepStage.core, start: t(22, 52), end: t(23, 47)),
      SleepSegment(stage: SleepStage.deep, start: t(23, 47), end: t2(0, 35)),
      SleepSegment(stage: SleepStage.core, start: t2(0, 35), end: t2(1, 10)),
      SleepSegment(stage: SleepStage.rem, start: t2(1, 10), end: t2(1, 38)),
      SleepSegment(stage: SleepStage.core, start: t2(1, 38), end: t2(2, 20)),
      SleepSegment(stage: SleepStage.deep, start: t2(2, 20), end: t2(2, 46)),
      SleepSegment(stage: SleepStage.awake, start: t2(2, 46), end: t2(2, 54)),
      SleepSegment(stage: SleepStage.core, start: t2(2, 54), end: t2(3, 32)),
      SleepSegment(stage: SleepStage.rem, start: t2(3, 32), end: t2(4, 6)),
      SleepSegment(stage: SleepStage.core, start: t2(4, 6), end: t2(5, 10)),
      SleepSegment(stage: SleepStage.awake, start: t2(5, 10), end: t2(5, 20)),
    ],
  );

  /// Eine Nacht, in der die Uhr nur Wachliegen aufgezeichnet hat. Kein
  /// Sonderfall zum Spaß: Genau das liefert eine Uhr, die am Handgelenk
  /// bleibt, während man wach liegt.
  SleepSession reineWachnacht() => SleepSession(
    segments: [
      SleepSegment(stage: SleepStage.awake, start: t(23, 5), end: t2(0, 20)),
      SleepSegment(stage: SleepStage.awake, start: t2(0, 40), end: t2(1, 55)),
    ],
  );

  SleepSession ohneAbschnitte() => SleepSession(segments: const []);

  Widget dunkleHuelle(Widget child) => CupertinoApp(
    theme: const CupertinoThemeData(brightness: Brightness.dark),
    home: CupertinoPageScaffold(child: Center(child: child)),
  );

  HypnogrammPainter? painterVon(WidgetTester tester) {
    final gemalt = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(Hypnogramm),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((flaeche) => flaeche.painter)
        .whereType<HypnogrammPainter>();
    return gemalt.isEmpty ? null : gemalt.first;
  }

  group('SchlafPhasen', () {
    test('Reihenfolge wie bei Apple: wach oben, Tiefschlaf unten', () {
      expect(SchlafPhasen.reihenfolge, [
        SleepStage.awake,
        SleepStage.rem,
        SleepStage.core,
        SleepStage.deep,
      ]);
    });

    test('jede Phase trägt ihren deutschen Namen', () {
      expect(SchlafPhasen.name(SleepStage.awake), 'Wach');
      expect(SchlafPhasen.name(SleepStage.rem), 'REM');
      expect(SchlafPhasen.name(SleepStage.core), 'Kern');
      expect(SchlafPhasen.name(SleepStage.deep), 'Tief');
      expect(SchlafPhasen.name(SleepStage.unspecified), 'Schlaf');
    });

    test('die Farben kommen aus der Palette, nicht aus eigenen Werten', () {
      // `wach`, nicht `warn` — siehe Nachtrag im Dateikopf. Backsteinrot
      // wäre der Ton der Warnsignale; Wachliegen ist kein Warnsignal.
      expect(SchlafPhasen.farbe(SleepStage.awake), Palette.wach);
      expect(SchlafPhasen.farbe(SleepStage.rem), Palette.iron);
      expect(SchlafPhasen.farbe(SleepStage.core), Palette.river);
      expect(SchlafPhasen.farbe(SleepStage.unspecified), Palette.river2);
    });

    group('„Tief" ist dunkler als „Kern" — in beiden Modi', () {
      /// Relative Helligkeit nach sRGB, 0 (schwarz) bis 1 (weiß). Grob
      /// genug für „dunkler als", und ohne jeden Pixelvergleich.
      double helligkeit(Color farbe) {
        double kanal(int acht) {
          final anteil = acht / 255;
          if (anteil <= 0.04045) return anteil / 12.92;
          return pow((anteil + 0.055) / 1.055, 2.4).toDouble();
        }

        final wert = farbe.toARGB32();
        return 0.2126 * kanal((wert >> 16) & 0xFF) +
            0.7152 * kanal((wert >> 8) & 0xFF) +
            0.0722 * kanal(wert & 0xFF);
      }

      test('hell — unverändert der Wert, den das Board für Tief hält', () {
        expect(
          SchlafPhasen.farbe(SleepStage.deep).color.toARGB32(),
          0xFF173F54,
          reason:
              '`--deep` hell und `--river-dark` hell tragen denselben Wert; '
              'im Hellmodus ändert sich durch den Nachtrag nichts',
        );
        expect(
          helligkeit(SchlafPhasen.farbe(SleepStage.deep).color),
          lessThan(helligkeit(SchlafPhasen.farbe(SleepStage.core).color)),
        );
      });

      test('dunkel — und genau hier kippte es um', () {
        expect(
          helligkeit(SchlafPhasen.farbe(SleepStage.deep).darkColor),
          lessThan(helligkeit(SchlafPhasen.farbe(SleepStage.core).darkColor)),
          reason:
              'auf dem Board ist Tief fast schwarz und Kern graublau. Eine '
              'Tiefenlesart, die sich beim Umschalten umdreht, ist keine',
        );
        expect(
          SchlafPhasen.farbe(SleepStage.deep).darkColor.toARGB32(),
          isNot(Palette.deep.darkColor.toARGB32()),
          reason:
              '`Palette.deep` ist im Dunkelmodus das hellste Blau der '
              'Palette (#9FE4FF) — richtig für Ringe und Flächen, falsch '
              'für die unterste Schlafspur',
        );
      });
    });

    // „Unspecified" liefern ältere Uhren und das iPhone: Schlaf ohne
    // Phasenangabe. Eine eigene fünfte Spur dafür wäre eine Phase, die
    // Apple nicht meldet — er liegt auf der Kern-Spur.
    test('unspezifizierter Schlaf liegt auf der Kern-Spur, nicht auf einer '
        'eigenen', () {
      expect(
        SchlafPhasen.spurIndex(SleepStage.unspecified),
        SchlafPhasen.spurIndex(SleepStage.core),
      );
      expect(SchlafPhasen.spurIndex(SleepStage.awake), 0);
      expect(SchlafPhasen.spurIndex(SleepStage.deep), 3);
    });
  });

  group('HypnogrammGeometrie', () {
    test('das Fenster reicht vom ersten bis zum letzten Abschnitt', () {
      final geometrie = HypnogrammGeometrie(nachtMitVierPhasen());

      expect(geometrie.von, t(22, 40));
      expect(geometrie.bis, t2(5, 20));
      expect(geometrie.fenster, const Duration(hours: 6, minutes: 40));
      expect(geometrie.leer, isFalse);
    });

    // Fängt die Nacht mit Wachliegen an, gehört das ins Bild — sonst
    // beginnt das Hypnogramm mitten im ersten Block.
    test('ein wacher Abschnitt am Rand zählt zum Fenster', () {
      final geometrie = HypnogrammGeometrie(reineWachnacht());

      expect(geometrie.von, t(23, 5));
      expect(geometrie.bis, t2(1, 55));
      expect(geometrie.leer, isFalse);
    });

    test('der Anteil eines Zeitpunkts ist sein Platz im Fenster', () {
      final geometrie = HypnogrammGeometrie(reineWachnacht());

      expect(geometrie.anteil(t(23, 5)), 0);
      expect(geometrie.anteil(t2(1, 55)), 1);
      // 23:05 bis 01:55 sind 170 Minuten, die Mitte liegt bei 00:30.
      expect(geometrie.anteil(t2(0, 30)), closeTo(0.5, 1e-9));
    });

    test('ein Zeitpunkt außerhalb des Fensters wird geklemmt, nicht '
        'hinausgezeichnet', () {
      final geometrie = HypnogrammGeometrie(reineWachnacht());

      expect(geometrie.anteil(t(20, 0)), 0);
      expect(geometrie.anteil(t2(9, 0)), 1);
    });

    test('ohne Abschnitte gibt es kein Fenster', () {
      final geometrie = HypnogrammGeometrie(ohneAbschnitte());

      expect(geometrie.leer, isTrue);
      expect(geometrie.von, isNull);
      expect(geometrie.bis, isNull);
      expect(geometrie.fenster, Duration.zero);
    });

    test('ein Fenster ohne Dauer teilt nicht durch null', () {
      final geometrie = HypnogrammGeometrie(
        SleepSession(
          segments: [
            SleepSegment(
              stage: SleepStage.core,
              start: t2(1, 0),
              end: t2(1, 0),
            ),
          ],
        ),
      );

      expect(geometrie.leer, isTrue);
      expect(geometrie.anteil(t2(1, 0)), 0);
      expect(geometrie.anteil(t2(2, 0)).isFinite, isTrue);
    });
  });

  group('Hypnogramm (Widget)', () {
    testWidgets('zeichnet eine Nacht mit allen vier Phasen', (tester) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: nachtMitVierPhasen())));

      expect(tester.takeException(), isNull);
      final painter = painterVon(tester);
      expect(painter, isNotNull);
      expect(painter!.abschnitte.length, 12);
    });

    testWidgets('zeichnet auch eine reine Wachnacht, statt sie wegzulassen', (
      tester,
    ) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: reineWachnacht())));

      expect(tester.takeException(), isNull);
      expect(painterVon(tester), isNotNull);
      expect(painterVon(tester)!.abschnitte.length, 2);
    });

    testWidgets('zeichnet unspezifizierten Schlaf, ohne zu scheitern', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          Hypnogramm(
            session: SleepSession(
              segments: [
                SleepSegment(
                  stage: SleepStage.unspecified,
                  start: t(23, 30),
                  end: t2(5, 5),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(painterVon(tester), isNotNull);
    });

    // Apple verrät den Lesestatus nicht: „nichts aufgezeichnet" und „nicht
    // freigegeben" sind von außen nicht zu unterscheiden. Beides wird
    // benannt — und zwar statt eines leeren Rahmens, der wie eine
    // schlaflose Nacht aussähe.
    testWidgets('ohne Abschnitte steht der Hinweis statt eines leeren Rahmens, '
        'und er nennt beide Möglichkeiten', (tester) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: ohneAbschnitte())));

      expect(painterVon(tester), isNull);
      expect(find.textContaining('aufgezeichnet'), findsOneWidget);
      expect(find.textContaining('freigegeben'), findsOneWidget);
    });

    testWidgets('zeigt im Hinweis keine Null und keine erfundene Dauer', (
      tester,
    ) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: ohneAbschnitte())));

      expect(find.text('0'), findsNothing);
      expect(find.text('0:00'), findsNothing);
      expect(find.text('0:00 h'), findsNothing);
    });

    testWidgets('beschriftet Anfang und Ende der Nacht über Format', (
      tester,
    ) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: nachtMitVierPhasen())));

      expect(find.text(Format.uhrzeit(t(22, 40))), findsOneWidget);
      expect(find.text(Format.uhrzeit(t2(5, 20))), findsOneWidget);
    });

    // Kompakt sitzt das Bild in der Nachtkarte, wo die vier Spurnamen nur
    // Platz kosten; in voller Breite (#92) tragen sie die Lesart.
    testWidgets('kompakt ohne Spurnamen', (tester) async {
      await tester.pumpWidget(
        huelle(Hypnogramm(session: nachtMitVierPhasen())),
      );

      expect(find.text('Wach'), findsNothing);
      expect(find.text('Tief'), findsNothing);
    });

    testWidgets('in voller Breite mit allen vier Spurnamen', (tester) async {
      await tester.pumpWidget(
        huelle(Hypnogramm(session: nachtMitVierPhasen(), kompakt: false)),
      );

      expect(find.text('Wach'), findsOneWidget);
      expect(find.text('REM'), findsOneWidget);
      expect(find.text('Kern'), findsOneWidget);
      expect(find.text('Tief'), findsOneWidget);
    });

    testWidgets('bringt keinen eigenen Navigator und kein eigenes Gerüst mit', (
      tester,
    ) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: nachtMitVierPhasen())));

      expect(
        find.descendant(
          of: find.byType(Hypnogramm),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(Hypnogramm),
          matching: find.byType(CupertinoPageScaffold),
        ),
        findsNothing,
      );
    });
  });

  group('Hypnogramm — aufgelöste Farben', () {
    testWidgets('im Hellmodus die hellen Varianten der Palette', (tester) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: nachtMitVierPhasen())));

      final farben = painterVon(tester)!.farben;
      expect(farben[SleepStage.deep]!.toARGB32(), Palette.deep.color.toARGB32());
      expect(farben[SleepStage.awake]!.toARGB32(), Palette.wach.color.toARGB32());
    });

    // Eine unaufgelöste `CupertinoDynamicColor` bleibt im Dunkelmodus auf
    // ihrer hellen Variante stehen — in `Palette.deep` ist das ein fast
    // schwarzes Blau auf dunklem Grund.
    testWidgets('im Dunkelmodus die dunklen Varianten', (tester) async {
      await tester.pumpWidget(
        dunkleHuelle(Hypnogramm(session: nachtMitVierPhasen())),
      );

      final farben = painterVon(tester)!.farben;
      expect(
        farben[SleepStage.deep]!.toARGB32(),
        SchlafPhasen.farbe(SleepStage.deep).darkColor.toARGB32(),
      );
      expect(
        farben[SleepStage.deep]!.toARGB32(),
        isNot(SchlafPhasen.farbe(SleepStage.deep).color.toARGB32()),
      );
      expect(
        farben[SleepStage.rem]!.toARGB32(),
        Palette.iron.darkColor.toARGB32(),
      );
    });

    testWidgets('auch das Schlaffenster darunter ist aufgelöst — hell und '
        'dunkel verschieden', (tester) async {
      await tester.pumpWidget(huelle(Hypnogramm(session: nachtMitVierPhasen())));
      final hell = painterVon(tester)!.fensterFarbe.toARGB32();

      await tester.pumpWidget(
        dunkleHuelle(Hypnogramm(session: nachtMitVierPhasen())),
      );
      final dunkel = painterVon(tester)!.fensterFarbe.toARGB32();

      expect(dunkel, isNot(hell));
    });
  });

  // Siehe Nachtrag (1) im Dateikopf: Tims Entscheidung vom 27.10.2026 dreht
  // die Formensprache aus #116 um. Geprüft werden die Zeichenaufrufe, nicht
  // Pixel — ein Golden-Test wäre hier der falsche Hebel, weil er bei jeder
  // Farbänderung mit ausschlägt.
  group('Die Formensprache des Entwurfs', () {
    // Zwei Blöcke auf zwei Spuren, die Nacht genau zweistündig: Jeder
    // Block ist damit exakt halb so breit wie die Fläche, und die
    // erwarteten Rechtecke lassen sich hinschreiben, statt sie
    // nachzurechnen.
    final zweiBloecke = [
      SleepSegment(stage: SleepStage.core, start: t(23, 0), end: t2(0, 0)),
      SleepSegment(stage: SleepStage.deep, start: t2(0, 0), end: t2(1, 0)),
    ];

    const flaeche = Size(320, 104); // vier Spuren à 26
    const balken = 13.0; // kompakt
    // **Fest 2, nicht die halbe Balkenhöhe** — am 28.10.2026 geändert
    // (#141). Hier stand `balken / 2`; das war Tims Entscheidung vom
    // 27.10.2026, und er hat sie am Gerät zurückgenommen: Bei
    // `rx = Balkenhöhe / 2` wird jeder Abschnitt, der schmaler ist als
    // hoch, zur Kapsel, und eine echte Nacht hat rund 25 Abschnitte.
    // Begründet steht die Umkehr am Bauteil `hypnogram()` in
    // `docs/screens/components.js`; die neuen Fälle liegen in
    // `hypnogramm_ablesen_test.dart`.
    const radius = Radius.circular(2);

    void Function(Canvas) gemalt(List<SleepSegment> abschnitte) {
      final painter = HypnogrammPainter(
        abschnitte: abschnitte,
        farben: {
          for (final phase in SleepStage.values)
            phase: const Color(0xFF123456),
        },
        fensterFarbe: const Color(0x0D15242A),
        kompakt: true,
      );
      return (canvas) => painter.paint(canvas, flaeche);
    }

    // Ein einziger Test für beides, weil `paints` eine **Reihenfolge**
    // prüft und die Reihenfolge hier Teil der Aussage ist: erst die vier
    // Spuren über die volle Breite, dann die Blöcke darauf. Umgekehrt läge
    // die graue Spur über den Blöcken.
    test('vier durchgehende Spuren, darauf die abgerundeten Blöcke', () {
      RRect gerundet(double links, double oben, double breite) =>
          RRect.fromRectAndRadius(
            Rect.fromLTWH(links, oben, breite, balken),
            radius,
          );

      expect(
        gemalt(zweiBloecke),
        paints
          // Die Spuren: eine je Zeile, `var(--ink)` bei 5 %, über die
          // volle Breite — auch dort, wo in dieser Nacht nichts liegt.
          ..rrect(rrect: gerundet(0, 0, 320))
          ..rrect(rrect: gerundet(0, 26, 320))
          ..rrect(rrect: gerundet(0, 52, 320))
          ..rrect(rrect: gerundet(0, 78, 320))
          // Die beiden Blöcke, je eine Stunde der zweistündigen Nacht.
          ..rrect(rrect: gerundet(0, 52, 160))
          ..rrect(rrect: gerundet(160, 78, 160)),
        reason:
            'components.js: Spur über die volle Breite, Blöcke mit festem '
            'Eckenradius darauf',
      );
    });

    test('und kein einziger Block bleibt scharfkantig', () {
      expect(
        gemalt(zweiBloecke),
        paintsExactlyCountTimes(#drawRect, 0),
        reason:
            'jeder `drawRect` wäre ein scharfkantiger Block — genau die '
            'Fassung, die Tim am 27.10.2026 umgedreht hat',
      );
    });

    test('ein sehr kurzer Abschnitt bleibt sichtbar, statt zu verschwinden', () {
      // Eine Minute in einer zweistündigen Nacht: 320 / 120 = 2,67 Punkte.
      // Seit dem 28.10.2026 (#141) gilt dafür eine ausgeschriebene
      // Mindestbreite statt der Rundung; wie breit sie ist, prüft
      // `hypnogramm_ablesen_test.dart`. Hier zählt nur, dass der kurze
      // Abschnitt überhaupt noch gezeichnet wird.
      expect(
        gemalt([
          SleepSegment(stage: SleepStage.core, start: t(23, 0), end: t2(0, 59)),
          SleepSegment(
            stage: SleepStage.awake,
            start: t2(0, 59),
            end: t2(1, 0),
          ),
        ]),
        paintsExactlyCountTimes(#drawRRect, 6),
        reason:
            'vier Spuren und zwei Blöcke — der kurze Abschnitt fällt nicht '
            'weg und wird auch nicht zu einem scharfkantigen Strich',
      );
    });
  });
}
