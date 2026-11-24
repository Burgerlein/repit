import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/formatierung.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/zeitdiagramm.dart';
// `Fensterstand` übersetzt einen Platz der Achse in seinen Kalendertag.
// Gebraucht wird das an genau einer Stelle (#150): um zu prüfen, dass
// Kopfzeile und Achse **denselben** Ausschnitt meinen, ohne dafür zwei
// verschiedene Datumsformate gegeneinander zu halten.
import 'package:repit/design/zeitdiagramm_fenster.dart';
// Der Maler trägt, was das Bauteil ihm übergibt: y-Grenzen und Achse. Das
// ist der einzige Weg, den gezeigten Ausschnitt während eines laufenden
// Zuges zu prüfen, ohne Pixel zu vergleichen (#147).
import 'package:repit/design/zeitdiagramm_zeichnung.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

import 'support.dart' show huelle, textOf;

/// Tests für das gemeinsame Diagramm-Bauteil (#130) —
/// `lib/design/zeitdiagramm.dart`. Die Rechnung darunter liegt in
/// `test/shell/diagramm_zeitraum_test.dart`, die beiden Abnehmer in
/// `test/shell/belastung_view_test.dart` und `verlauf_view_test.dart`.
///
/// ## Wofür diese Datei da ist: die zwei Gesten
///
/// Stufen, Startstufe, Ziellinien und Fußzeile prüfen die beiden
/// Schirmtests schon von außen mit. Was **nirgends** geprüft ist, sind die
/// beiden Gesten aus der Entwurfs-Spec
/// `2026-10-13-graphen-zeitraum-und-ablesen-design.md`:
///
/// 1. **Blättern.** Waagerecht wischen schiebt das Fenster in die
///    Vergangenheit, und es gibt kein Fenster vor dem ersten und keins nach
///    dem letzten Messwert.
/// 2. **Ablesen durch Halten.** Halten wählt einen Balken aus; die
///    Kopfzeile zeigt dann dessen Datum und Wert statt Durchschnitt und
///    Zeitraum und **springt beim Loslassen zurück**. Über einer Lücke
///    steht „keine Messung", nie der Nachbarwert.
///
/// Beide müssen sich vertragen. In SwiftUI ist genau das schiefgegangen:
/// „`.chartGesture` ersetzt die eingebauten Gesten des Diagramms
/// einschließlich des Scrollens" (Spec, „Der Rahmen") — mit eigener
/// Long-Press-Geste ließ sich der Graph nicht mehr schieben. In Flutter
/// steuern wir die Gesten selbst, also wird beides gegeneinander geprüft:
/// ein Halten verschiebt nichts, ein Wisch hinterlässt keine Auswahl.
///
/// ## Der Vertrag des Blätterns ist am 28.10.2026 ein anderer geworden
///
/// Bis heute stand hier: „Ein Wisch über die volle Breite ist genau ein
/// Fenster", und ein kürzerer Zug rundete auf **ganze** Rastschritte — bei
/// `W` also auf ganze Wochen. Der Fall „und landet auf einer ganzen Woche,
/// nicht mittendrin" hat das festgenagelt.
///
/// Tim hat die App am 28.10.2026 im Release-Build auf dem iPhone geprüft
/// und gesagt: *„das wischen reagiert komisch ich muss sehr weit wischen
/// und es fühlt sich nicht flüssig an"* (#145). Das ist die Folge dieser
/// Regel, nicht ein Fehler darin: Bei `W` ist eine Woche **ein einziger**
/// Rastschritt, also muss der Finger über die halbe Diagrammbreite laufen,
/// bevor sich überhaupt etwas bewegt — und dann springt es eine ganze
/// Woche weit.
///
/// **Die alte Regel war nicht dumm, sie war eine Entscheidung ohne Gerät.**
/// Begründet war sie mit „Ein Fenster, das mitten in der Woche beginnt,
/// lässt sich nicht mit dem Nachbarfenster vergleichen" (Entwurfs-Spec
/// `2026-10-13-graphen-zeitraum-und-ablesen-design.md`, „Einrasten").
/// Dieselbe Spec sagt eine Zeile weiter aber auch „**langsam gezogen**
/// bleibt stehen" — die Umsetzung hat das grobe Raster erzwungen, wo die
/// Spec beides nebeneinander vorsah.
///
/// Neu gilt, was Apple Health tut und was Tim erwartet: **Der Inhalt läuft
/// mit dem Finger mit, Platz für Platz, und rastet erst beim Loslassen
/// ein** — auf einen **Platz**, nicht auf ein Fenster. Ein Platz ist bei
/// `W` und `M` ein Kalendertag, ab `6M` ein Kalendermonat; so weit, wie ein
/// Balken breit ist, so weit blättert ein Zug. Ein Fenster darf damit
/// mitten in der Woche beginnen.
///
/// **Das Einrasten selbst bleibt.** Ein Zug, der unter einem halben Platz
/// bleibt, federt zurück; stehen bleibt das Fenster nie zwischen zwei
/// Tagen.
///
/// ## Zwei weitere Beanstandungen vom 28.10.2026
///
/// - **#147 — der Graph bricht beim Blättern aus.** Während des Zuges
///   werden die Nachbarpunkte mitgezeichnet, aber mit der y-Skala des
///   **alten** Fensters; die Linie schießt oben und unten aus dem Bild, und
///   von der Achse bleibt ein einzelnes „Mo." stehen. Geprüft wird das
///   unter „Während des Zuges stimmt der gezeigte Ausschnitt" — nicht an
///   Pixeln, sondern an dem, was das Bauteil dem Maler übergibt.
/// - **#146 — der Hinweis „Halten zeigt den Einzelwert" fällt weg.** Er
///   stand unter der Fußzeile, verschwand beim Ablesen und ließ alles
///   darunter springen. Tim: *„bitte entfern ihn komplett"*. **Ersatzlos**,
///   nicht als reservierter Platz — deshalb prüfen die beiden Fälle unter
///   „Unter der Fußzeile steht nichts" zweierlei: dass die Höhe sich beim
///   Ablesen nicht ändert **und** dass unter der Fußzeile nichts mehr
///   liegt. Der erste allein ließe sich mit reserviertem Platz erfüllen.
///
/// ## Festgelegte öffentliche API
///
/// Wörtlich aus dem Kopf von `test/shell/belastung_view_test.dart`
/// (Z. 42–77) übernommen; diese Datei widerspricht ihr nicht:
///
/// ```dart
/// class Zeitraumleiste extends StatelessWidget {
///   const Zeitraumleiste({
///     super.key,
///     required List<DiagrammStufe> stufen,
///     required DiagrammStufe gewaehlt,
///     required ValueChanged<DiagrammStufe> onWaehle,
///   });
/// }
///
/// @immutable
/// class Ziellinie {
///   const Ziellinie({
///     required String name,
///     required double wert,
///     required CupertinoDynamicColor farbe,
///   });
/// }
///
/// class Zeitdiagramm extends StatefulWidget {
///   const Zeitdiagramm({
///     super.key,
///     required List<({DateTime tag, double wert})> reihe,
///     required List<DiagrammStufe> stufen,
///     required String Function(DiagrammStufe stufe) fussnote,
///     bool alsBalken = true,
///     List<Ziellinie> linien = const [],
///   });
/// }
/// ```
///
/// Kopfzeile unter `Key('diagramm-kopfzeile')`, Fußzeile unter
/// `Key('diagramm-fussnote')`.
///
/// **Dazu kommen zwei Parameter, die es am 27.10.2026 noch nicht gibt** —
/// sie sind rein additiv, der Block oben bleibt wahr:
///
/// ```dart
///     String einheit = '',
///     String? einheitAbgelesen,
/// ```
///
/// ## Zwei Entscheidungen von Tim, 27.10.2026
///
/// 1. **Die Startstufe ist die kleinste angebotene**, nicht die erste.
///    Wortlaut: „immer das kleinste zuerst". Die Entwurfs-Spec ist
///    nachgezogen (`2026-10-13-graphen-zeitraum-und-ablesen-design.md`,
///    Z. 48). Die ausführliche Begründung steht im Kopf von
///    `test/shell/diagramm_zeitraum_test.dart`, wo die Funktion geprüft
///    wird; hier wird nur mitgeprüft, dass das Bauteil `startStufe` auch
///    wirklich fragt, statt `stufen.first` selbst zu lesen.
/// 2. **Die Kopfzeile bekommt eine Einheit.** Wortlaut: „ja min/tag". Das
///    Entwurfsboard zeigt sie längst (`docs/screens/components.js`,
///    `chartCard`: `<b>' + value + '</b><span>' + esc(unit) + '</span>`),
///    das Bauteil hatte bis heute keinen Parameter dafür.
///
/// ## Entscheidungen dieser Datei — vom Test-Agenten, nicht von Tim
///
/// Sieben Dinge stehen weder in der Spec noch im Board. Sie sind hier
/// entschieden, damit sie jemand findet:
///
/// 1. **Die Zahlen der Testreihen sind so gewählt, dass der
///    Fensterdurchschnitt auf keinem einzelnen Balken steht.** Eine Woche
///    aus sechsmal 300 und einmal 531 hat den Schnitt 333 — die Zeichenkette
///    „333" kann also nur aus der Kopfzeile ohne Auswahl stammen, nie aus
///    einem abgelesenen Balken. Ohne diesen Kniff wäre „nach dem Wisch steht
///    wieder der Durchschnitt" von „nach dem Wisch klebt noch eine Auswahl"
///    nicht zu unterscheiden.
/// 2. **Gedrückt wird in dem Band zwischen Kopfzeile und Fußzeile.** Dort
///    liegt der Graph, und nur diese beiden tragen einen festgelegten
///    Schlüssel. Jeder Test, der dieses Band benutzt, prüft vorher, dass es
///    eine Höhe hat — sonst drückte er ins Leere und wäre still grün.
/// 3. **Das Datum in der Kopfzeile wird nicht auf ein Format festgenagelt**
///    (`CLAUDE.md`: keine Beschriftungen). Dass überhaupt eines dasteht,
///    wird anders belegt: Bei einer Reihe aus lauter gleichen Werten müssen
///    zwei verschieden gehaltene Balken trotzdem **verschiedene** Kopfzeilen
///    ergeben. Der Unterschied kann dann nur vom Datum kommen.
/// 4. **„Der Wertebereich beginnt am Balken der ersten Messung, nicht an
///    deren Rastgrenze" (Spec) ist von außen nicht trennscharf prüfbar.**
///    Beide Grenzen liegen höchstens eine Rastperiode auseinander, und das
///    Fenster ist mindestens eine Rastperiode breit — es enthält den ersten
///    Balken so oder so. Geprüft wird deshalb die Folge, auf die es
///    ankommt: **Am linken Anschlag stehen noch Messwerte im Fenster**, und
///    ein weiterer Wisch ändert nichts mehr. Siehe Bericht.
/// 5. **Es sind zwei Einheiten, nicht eine — aber die zweite ist
///    optional.** Tim hat gesagt, dass eine Einheit hingehört, nicht wie
///    viele Beschriftungen es sind; das ist hier entschieden.
///
///    Die SwiftUI-Vorlage trägt zwei (`unitLabel: { _ in "Schritte / Tag"
///    }`, `pickedUnitLabel: "Schritte"`), und der Grund hält: Beim Ablesen
///    eines einzelnen Balkens wäre „9.096 Schritte **/ Tag**" falsch — das
///    ist der Wert *dieses* Tages, kein Durchschnitt pro Tag. Bei Belastung
///    dasselbe: Der Fensterschnitt ist „min / Tag", der einzelne Balken
///    schlicht „min". Eine einzige Beschriftung zwänge jeden Schirm, sich
///    für eine der beiden Lügen zu entscheiden.
///
///    **Zwei Pflichtfelder wären trotzdem falsch.** Bei `kg`, `ms` und
///    `bpm` — das sind drei der vier heutigen Abnehmer — ist die Einheit in
///    beiden Zuständen dieselbe, und ein Literal zweimal hinschreiben zu
///    müssen ist genau die Stelle, an der eines von beiden veraltet.
///    Deshalb: `einheit` gilt immer, `einheitAbgelesen` **ersetzt** sie
///    beim Ablesen und ist `null`, wenn es nichts zu ersetzen gibt. Der
///    Normalfall braucht ein Feld, der gefährliche Fall ist ausdrückbar.
///
///    Und es ist ein `String`, keine Funktion über die Stufe: Bei Belastung
///    heißt es auf `W` wie auf `6M` „min / Tag" (ab `6M` ist ein Balken der
///    **Tagesdurchschnitt** eines Monats, Spec „Verdichtung ab 6M"). Was
///    sich mit der Stufe ändert, ist die Fußzeile, und die ist schon ein
///    Rückruf.
/// 6. **Wo keine Zahl steht, steht auch keine Einheit.** Über einer Lücke
///    steht „keine Messung", bei leerer Reihe steht nichts — „keine Messung
///    min / Tag" ist kein Satz, und eine Einheit ohne Zahl behauptet eine
///    Messung, die es nicht gab. Dasselbe Muster wie „erfindet keinen
///    Durchschnitt" weiter unten (`docs/todo/01`).
/// 7. **Die Einheiten der Testfälle heißen „Minuten / Tag" und „Minuten",
///    nicht „min / Tag" und „min".** Ein Test, der `isNot(contains('min'))`
///    prüft, bricht an dem Tag, an dem ein Datumsformat die Buchstabenfolge
///    zufällig enthält. Der Wortlaut der echten Einheit gehört ohnehin in
///    den Schirm, nicht hierher.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Pixel, Achsen, Farben, Beschriftungen.** Golden-Tests gibt es im
///   Flutter-Zweig nicht; `CLAUDE.md` lässt Widget-Tests nur für Zustände
///   und Übergänge zu. Wo ein Text eine **Regel** trägt („keine Messung"
///   statt Nachbarwert, die Verdichtung in der Fußzeile), wird die Regel
///   geprüft, nie der ganze Satz.
/// - **Der Wortlaut der Fußzeile.** Den liefert der Schirm als Rückruf
///   (`fussnote`); das Bauteil kann ihn gar nicht kennen. Geprüft wird, dass
///   es den Rückruf mit der **gerade gewählten** Stufe fragt — mehr ist auf
///   dieser Ebene nicht wahr. Dass ab `6M` „Durchschnitt" darin vorkommt,
///   steht in den beiden Schirmtests.
/// - **Riverpod.** Das Bauteil bekommt seine Reihe als Parameter und liest
///   keinen Provider; es gibt hier keinen `ProviderContainer` abzuschalten.
void main() {
  // Alle Grenzen als Berliner Tagesbeginn, als UTC-Zeitpunkt — genau wie
  // `BerlinCalendar` und `diagramm_zeitraum_test.dart` es halten.
  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  ({DateTime tag, double wert}) wert(DateTime t, double v) => (tag: t, wert: v);

  // ───────────────────────────────────────────────────────────────────────
  // Reihen
  //
  // Montage im Oktober 2026: 21.09., 28.09., 05.10., 12.10.
  // ───────────────────────────────────────────────────────────────────────

  /// Eine Woche: sechs gleiche Tage und ein abweichender Sonntag, so
  /// gewählt, dass der Wochendurchschnitt auf **keinem** Balken steht.
  /// Entscheidung 1 im Kopf dieser Datei.
  ///
  /// **Weitergezählt wird mit `BerlinCalendar.addDays`, nie über
  /// `montag.day + i`.** `startOfDay` gibt einen UTC-*Zeitpunkt* zurück, der
  /// eine Berliner Mitternacht bezeichnet — in der Sommerzeit trägt dessen
  /// UTC-Datum den **Vortag**. Die erste Fassung dieser Hülle hat genau das
  /// getan und jede Woche um einen Tag verschoben; die Wochenschnitte waren
  /// dann 338,5 statt 333.
  List<({DateTime tag, double wert})> woche(
    DateTime montag, {
    required double werktags,
    required double sonntag,
  }) => [
    for (var i = 0; i < 6; i++)
      wert(BerlinCalendar.addDays(montag, i), werktags),
    wert(BerlinCalendar.addDays(montag, 6), sonntag),
  ];

  /// Drei volle Wochen mit den Durchschnitten 111, 222 und 333 — die
  /// jüngste zuletzt. 777/7 = 111, 1554/7 = 222, 2331/7 = 333.
  final dreiWochen = <({DateTime tag, double wert})>[
    ...woche(tag(2026, 9, 21), werktags: 100, sonntag: 177),
    ...woche(tag(2026, 9, 28), werktags: 200, sonntag: 354),
    ...woche(tag(2026, 10, 5), werktags: 300, sonntag: 531),
  ];

  /// Eine volle Woche, Schnitt 60, Balken 100 und 44 — keiner der drei
  /// Werte steckt als Zeichenkette in einem der anderen.
  /// (2 × 100 + 5 × 44) / 7 = 60.
  final eineWoche = <({DateTime tag, double wert})>[
    wert(tag(2026, 10, 5), 100),
    for (var t = 6; t <= 10; t++) wert(tag(2026, 10, t), 44),
    wert(tag(2026, 10, 11), 100),
  ];

  /// Dieselbe Woche, aber nur an den beiden Rändern gemessen. Die fünf
  /// Tage dazwischen sind eine Lücke — und Lücken bleiben Lücken.
  final wocheMitLuecke = <({DateTime tag, double wert})>[
    wert(tag(2026, 10, 5), 100),
    wert(tag(2026, 10, 11), 140),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  Widget diagramm({
    required List<({DateTime tag, double wert})> reihe,
    List<DiagrammStufe> stufen = const [DiagrammStufe.woche],
    String Function(DiagrammStufe stufe)? fussnote,
    bool alsBalken = true,
    List<Ziellinie> linien = const [],
    String einheit = '',
    String? einheitAbgelesen,
    String Function(double wert)? kopfzahl,
  }) => Zeitdiagramm(
    reihe: reihe,
    stufen: stufen,
    fussnote: fussnote ?? (s) => 'fuss-${s.name}',
    alsBalken: alsBalken,
    linien: linien,
    einheit: einheit,
    einheitAbgelesen: einheitAbgelesen,
    kopfzahl: kopfzahl,
  );

  Future<void> zeige(WidgetTester tester, Widget kind) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      huelle(SizedBox(width: 360, height: 400, child: kind)),
    );
    await tester.pumpAndSettle();
  }

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ');

  String kopf(WidgetTester tester) =>
      textUnter(tester, const Key('diagramm-kopfzeile'));

  String fuss(WidgetTester tester) =>
      textUnter(tester, const Key('diagramm-fussnote'));

  Zeitraumleiste leiste(WidgetTester tester) => tester.widget<Zeitraumleiste>(
    find.descendant(
      of: find.byType(Zeitdiagramm),
      matching: find.byType(Zeitraumleiste),
    ),
  );

  /// Das Band zwischen Kopfzeile und Fußzeile — dort liegt der Graph.
  /// Entscheidung 2 im Kopf dieser Datei.
  Rect graphband(WidgetTester tester) {
    final ganz = tester.getRect(find.byType(Zeitdiagramm));
    final oben = tester.getRect(find.byKey(const Key('diagramm-kopfzeile')));
    final unten = tester.getRect(find.byKey(const Key('diagramm-fussnote')));
    final band = Rect.fromLTRB(ganz.left, oben.bottom, ganz.right, unten.top);
    expect(
      band.height,
      greaterThan(0),
      reason:
          'Zwischen Kopfzeile und Fußzeile muss der Graph liegen. Ohne Band '
          'drückte jede Geste dieser Datei ins Leere und wäre still grün',
    );
    return band;
  }

  Offset amAnteil(WidgetTester tester, double anteil) {
    final band = graphband(tester);
    return Offset(band.left + band.width * anteil, band.center.dy);
  }

  /// Finger auf den Graphen legen und lange genug liegen lassen, dass eine
  /// Long-Press-Geste anschlägt — **ohne** `pumpAndSettle`, damit der
  /// Zwischenzustand „Finger liegt noch auf" prüfbar bleibt.
  Future<TestGesture> halte(WidgetTester tester, double anteil) async {
    final geste = await tester.startGesture(amAnteil(tester, anteil));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    return geste;
  }

  Future<void> lass(WidgetTester tester, TestGesture geste) async {
    await geste.up();
    await tester.pumpAndSettle();
  }

  /// Waagerecht wischen. Positives `anteil` schiebt den Inhalt nach rechts
  /// und damit das Fenster in die **Vergangenheit**.
  Future<void> wische(WidgetTester tester, double anteil) async {
    final band = graphband(tester);
    await tester.dragFrom(band.center, Offset(band.width * anteil, 0));
    await tester.pumpAndSettle();
  }

  /// Ziehen und den Finger **liegen lassen** — der Zustand mitten im Zug.
  /// Ohne das ließe sich #147 nicht prüfen: Kaputt ist allein der Übergang,
  /// der eingeschwungene Zustand war schon sauber.
  Future<TestGesture> zieheUndHalte(WidgetTester tester, double anteil) async {
    final band = graphband(tester);
    final geste = await tester.startGesture(band.center);
    await tester.pump(const Duration(milliseconds: 20));
    await geste.moveBy(Offset(band.width * anteil, 0));
    await tester.pump();
    return geste;
  }

  /// Der Maler des Graphen. Was das Bauteil ihm übergibt, ist das, was im
  /// Bild landet — y-Grenzen und Achsenbeschriftung.
  ZeitdiagrammPainter maler(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(Zeitdiagramm),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((anstrich) => anstrich.painter)
      .whereType<ZeitdiagrammPainter>()
      .single;

  // ═══════════════════════════════════════════════════════════════════════

  group('Zeitraumleiste', () {
    testWidgets('sie zeigt je angebotener Stufe einen Eintrag', (tester) async {
      const stufen = [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
      ];
      await zeige(
        tester,
        Zeitraumleiste(
          stufen: stufen,
          gewaehlt: stufen.first,
          onWaehle: (_) {},
        ),
      );

      expect(
        find.descendant(
          of: find.byType(Zeitraumleiste),
          matching: find.byType(Text),
        ),
        findsNWidgets(stufen.length),
        reason:
            'Eine Stufe ohne Eintrag ist nicht erreichbar, ein Eintrag ohne '
            'Stufe führt nirgendwohin',
      );
    });

    testWidgets('ein Tipp meldet die Stufe an dieser Stelle', (tester) async {
      const stufen = [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
      ];
      final gemeldet = <DiagrammStufe>[];
      await zeige(
        tester,
        Zeitraumleiste(
          stufen: stufen,
          gewaehlt: stufen.first,
          onWaehle: gemeldet.add,
        ),
      );

      // Über die **Reihenfolge** angetippt, nicht über die Beschriftung —
      // die ist Layout und wird hier nicht festgenagelt.
      final eintraege = find.descendant(
        of: find.byType(Zeitraumleiste),
        matching: find.byType(Text),
      );
      await tester.tap(eintraege.at(2));
      await tester.pumpAndSettle();
      await tester.tap(eintraege.at(1));
      await tester.pumpAndSettle();

      expect(gemeldet, [DiagrammStufe.halbjahr, DiagrammStufe.monat]);
    });

    testWidgets('ein Tipp auf die gewählte Stufe meldet keine andere', (
      tester,
    ) async {
      const stufen = [DiagrammStufe.woche, DiagrammStufe.monat];
      final gemeldet = <DiagrammStufe>[];
      await zeige(
        tester,
        Zeitraumleiste(
          stufen: stufen,
          gewaehlt: DiagrammStufe.woche,
          onWaehle: gemeldet.add,
        ),
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(Zeitraumleiste),
              matching: find.byType(Text),
            )
            .at(0),
      );
      await tester.pumpAndSettle();

      expect(
        gemeldet,
        anyOf(isEmpty, equals(const [DiagrammStufe.woche])),
        reason:
            'Ob die Leiste den Tipp auf das schon Gewählte schluckt oder '
            'durchreicht, ist ihre Sache — eine **andere** Stufe darf dabei '
            'nie herauskommen',
      );
    });
  });

  group('Ziellinie ist ein Werttyp', () {
    // Keine `const`-Ausdrücke: Dart kanonisiert die, und vier Mal dieselbe
    // Instanz zu vergleichen beweist nichts. Am 27.10.2026 ist genau das in
    // `recovery_snapshot_test.dart` passiert.
    Ziellinie linie({
      String name = 'Ziel',
      double wert = 30,
      CupertinoDynamicColor? farbe,
    }) => Ziellinie(
      name: name,
      wert: wert,
      farbe: farbe ?? CupertinoColors.systemBlue,
    );

    test('gleiche Felder sind gleich — sonst rechnet jedes Bild neu', () {
      final a = linie();
      final b = linie();

      expect(
        a,
        isNot(same(b)),
        reason:
            'Zwei getrennte Instanzen, sonst prüft der Vergleich nur die '
            'Kanonisierung des Compilers',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Wert macht sie ungleich', () {
      final a = linie(wert: 30);
      final b = linie(wert: 31);
      expect(a, isNot(same(b)));
      expect(a, isNot(b));
    });

    test('ein anderer Name macht sie ungleich', () {
      final a = linie(name: 'Ziel');
      final b = linie(name: 'Median');
      expect(a, isNot(same(b)));
      expect(a, isNot(b));
    });

    test('eine andere Farbe macht sie ungleich', () {
      final a = linie(farbe: CupertinoColors.systemBlue);
      final b = linie(farbe: CupertinoColors.systemRed);
      expect(a, isNot(same(b)));
      expect(
        a,
        isNot(b),
        reason:
            'Die Farbe unterscheidet Ziel von Median von Schwelle. Fällt sie '
            'aus `==`, bleibt die alte Linie stehen, wenn nur sie sich ändert',
      );
    });

    testWidgets('das Diagramm nimmt die Linien entgegen', (tester) async {
      final linien = [linie(name: 'Ziel'), linie(name: 'Median', wert: 44)];
      await zeige(tester, diagramm(reihe: eineWoche, linien: linien));

      expect(
        tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm)).linien,
        linien,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Startstufe und Startfenster (#7)', () {
    testWidgets('gewählt ist die **kleinste** angebotene Stufe', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(
          reihe: dreiWochen,
          stufen: const [
            DiagrammStufe.monat,
            DiagrammStufe.woche,
            DiagrammStufe.halbjahr,
          ],
        ),
      );

      expect(
        leiste(tester).gewaehlt,
        DiagrammStufe.woche,
        reason:
            'Tims Entscheidung vom 27.10.2026: „immer das kleinste zuerst" '
            '(`startStufe`). Steht hier `monat`, liest das Bauteil '
            '`stufen.first` selbst, statt die Regel zu fragen — und dann '
            'hängt die Startstufe wieder an der Reihenfolge einer Liste. '
            'Das ist #7, und es wird hier gelöst, nicht abgeschrieben',
      );
    });

    testWidgets('die Reihenfolge der angebotenen Stufen ändert nichts', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(
          reihe: dreiWochen,
          stufen: const [DiagrammStufe.halbjahr, DiagrammStufe.woche],
        ),
      );

      expect(
        leiste(tester).gewaehlt,
        DiagrammStufe.woche,
        reason:
            'Dieselbe Menge Stufen ergibt dieselbe Startstufe, in welcher '
            'Reihenfolge sie auch angemeldet werden. Vorher stand hier '
            '`halbjahr` — ein Schirm, der seine Leiste umsortiert, bekam '
            'still ein anderes Startfenster',
      );
    });

    testWidgets('das Startfenster enthält den jüngsten Wert', (tester) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      expect(
        kopf(tester),
        contains('333'),
        reason:
            'Der Schnitt der jüngsten Woche. Steht er nicht da, schlägt der '
            'Schirm auf einer älteren oder leeren Fläche auf — das ist #7, '
            'und er war echt',
      );
      expect(
        kopf(tester),
        isNot(contains('111')),
        reason: 'die älteste Woche ist nicht das Startfenster',
      );
    });

    testWidgets('auch wenn der jüngste Wert nicht auf einer Rastgrenze liegt', (
      tester,
    ) async {
      // Mittwoch, 07.10.2026 — mitten in der Woche.
      await zeige(tester, diagramm(reihe: [wert(tag(2026, 10, 7), 777)]));

      expect(
        kopf(tester),
        contains('777'),
        reason:
            'Das Fenster endet an der Rastgrenze **nach** dem jüngsten '
            'Wert, nicht an der davor — sonst läge der neueste Balken '
            'außerhalb',
      );
    });
  });

  group('Blättern: waagerecht wischen schiebt das Fenster', () {
    testWidgets('ein Wisch führt in die Vergangenheit', (tester) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      await wische(tester, 1.0);

      expect(
        kopf(tester),
        isNot(vorher),
        reason: 'Das Fenster hat sich nicht bewegt',
      );
      expect(
        kopf(tester),
        isNot(contains('333')),
        reason: 'die jüngste Woche liegt jetzt rechts außerhalb',
      );
    });

    testWidgets('ein Zug über die volle Breite blättert genau sieben Tage', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      await wische(tester, 1.0);

      expect(
        kopf(tester),
        contains('222'),
        reason:
            'Sieben Plätze zurück ist bei `W` genau eine Woche, und 222 ist '
            'der Schnitt der Vorwoche. Steht hier eine Mischzahl, läuft der '
            'Inhalt nicht mehr Platz für Platz mit dem Finger mit',
      );
      expect(
        kopf(tester),
        contains('28.09.'),
        reason: 'und das Fenster beginnt am Montag davor',
      );
    });

    testWidgets('vor dem ersten Messwert ist Schluss', (tester) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      for (var i = 0; i < 6; i++) {
        await wische(tester, 1.0);
      }
      final amAnschlag = kopf(tester);

      expect(
        amAnschlag,
        contains('111'),
        reason:
            'Die älteste Woche ist der linke Anschlag. Steht hier nichts '
            'mehr, ließe sich in leere Zeit vor dem ersten Messwert '
            'scrollen — „der Wertebereich beginnt am Balken der ersten '
            'Messung" (Entwurfs-Spec, „Der Rahmen")',
      );

      await wische(tester, 1.0);
      expect(
        kopf(tester),
        amAnschlag,
        reason: 'Noch ein Wisch darf nichts mehr verschieben',
      );
    });

    testWidgets('nach dem letzten Messwert auch', (tester) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      // Negativ: in die Zukunft, also über den jüngsten Wert hinaus.
      await wische(tester, -1.0);

      expect(
        kopf(tester),
        vorher,
        reason:
            'Das Startfenster ist schon das jüngste. Ließe es sich weiter '
            'schieben, stünde der Schirm auf leerer Fläche',
      );
      expect(kopf(tester), contains('333'));
    });

    testWidgets('zurückblättern führt wieder zur jüngsten Woche', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      await wische(tester, 1.0);
      expect(kopf(tester), isNot(vorher));

      for (var i = 0; i < 6; i++) {
        await wische(tester, -1.0);
      }

      expect(
        kopf(tester),
        vorher,
        reason:
            'Der Weg zurück zum Ausgangsfenster muss derselbe Zustand sein, '
            'sonst sieht der Nutzer nach zweimal Wischen etwas anderes als '
            'beim Aufschlagen',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #145 — der Zug läuft mit dem Finger mit, Platz für Platz
  //
  // Der Vertrag, der am 28.10.2026 ersetzt wurde: siehe den Kopf dieser
  // Datei. Ein Platz ist bei `W` ein Kalendertag und so breit, wie ein
  // Balken breit ist — ein Siebtel der Diagrammbreite. Genau so weit
  // blättert ein Zug über ein Siebtel.
  // ═══════════════════════════════════════════════════════════════════════

  group('Blättern: ein Zug blättert Plätze, nicht Fenster', () {
    /// Ein Platz der Wochenansicht als Anteil der Diagrammbreite.
    const einPlatz = 1 / 7;

    testWidgets('ein Zug über eine Balkenbreite blättert genau einen Tag', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      expect(
        kopf(tester),
        contains('05.10.'),
        reason: 'Das Startfenster ist die Woche ab Montag, dem 05.10.2026',
      );

      await wische(tester, einPlatz);

      expect(
        kopf(tester),
        contains('04.10.'),
        reason:
            'Einen Balken weit gezogen ist **ein Tag**, nicht eine Woche. '
            'Tim am 28.10.2026: „das wischen reagiert komisch ich muss sehr '
            'weit wischen und es fühlt sich nicht flüssig an" (#145)',
      );
      expect(
        kopf(tester),
        contains('10.10.'),
        reason: 'und das Fenster bleibt sieben Tage breit, es endet nur früher',
      );
    });

    testWidgets('und das Fenster darf dabei mitten in der Woche beginnen', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      await wische(tester, einPlatz);

      expect(
        kopf(tester),
        contains('307'),
        reason:
            'Sonntag 04.10. (354) und sechsmal 300 ergeben 307,7 — eine '
            'Mischzahl aus zwei Kalenderwochen. Genau die war bis zum '
            '28.10.2026 verboten; seither läuft der Inhalt tageweise mit '
            'dem Finger mit (#145)',
      );
      expect(
        kopf(tester),
        isNot(contains('333')),
        reason: 'die jüngste ganze Woche ist es nicht mehr',
      );
      expect(
        kopf(tester),
        isNot(contains('222')),
        reason:
            'und die davor auch nicht — ein Zug über einen Balken springt '
            'nicht auf die nächste Wochengrenze',
      );
    });

    testWidgets('ein Zug unter einem halben Balken federt zurück', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      await wische(tester, einPlatz * 0.4);

      expect(
        kopf(tester),
        vorher,
        reason:
            'Das Einrasten beim Loslassen bleibt — nur die Rastweite ist '
            'jetzt ein Platz statt eines Fensters. Zwischen zwei Tagen darf '
            'ein Fenster nie stehen bleiben',
      );
    });

    testWidgets('der linke Anschlag zählt jetzt in Tagen, nicht in Wochen', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      // Vierzehn Plätze zurück steht das Fenster auf der ältesten Woche;
      // weiter geht es nicht, denn dort liegt der erste Messwert.
      for (var i = 0; i < 14; i++) {
        await wische(tester, einPlatz);
      }

      expect(
        kopf(tester),
        contains('111'),
        reason:
            'Vierzehn Tagesschritte sind zwei Wochen — und zwei Wochen vor '
            'dem Startfenster liegt die älteste. Rechnete der Anschlag '
            'weiter in Wochen, wäre hier nach zwei Zügen Schluss',
      );
      expect(kopf(tester), contains('21.09.'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #147 — während des Zuges stimmt der gezeigte Ausschnitt
  //
  // Geprüft wird nicht am Pixel (Golden-Tests gibt es im Flutter-Zweig
  // nicht), sondern an dem, was das Bauteil dem Maler übergibt: y-Grenzen
  // und Achsenbeschriftung. Beide müssen zu dem Ausschnitt gehören, der
  // gerade im Bild steht, nicht zum Fenster vor dem Zug.
  // ═══════════════════════════════════════════════════════════════════════

  group('Während des Zuges stimmt der gezeigte Ausschnitt', () {
    /// Zwei Wochen: die jüngste flach, in der Woche davor ein Ausreißer am
    /// Donnerstag, dem 01.10.2026. Beim Ziehen wandert er ins Bild.
    final flachMitAusreisser = <({DateTime tag, double wert})>[
      for (var t = 28; t <= 30; t++) wert(tag(2026, 9, t), 41),
      wert(tag(2026, 10, 1), 900),
      for (var t = 2; t <= 4; t++) wert(tag(2026, 10, t), 41),
      for (var t = 5; t <= 11; t++) wert(tag(2026, 10, t), 41),
    ];

    testWidgets('die y-Skala nimmt den Ausreißer mit, sobald er im Bild ist', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(reihe: flachMitAusreisser, alsBalken: false),
      );

      expect(
        maler(tester).grenzen.$2,
        lessThan(100),
        reason:
            'Vor dem Zug steht nur die flache Woche im Bild; die 900 der '
            'Vorwoche gehört nicht auf diese Achse',
      );

      final geste = await zieheUndHalte(tester, 4.5 / 7);

      expect(
        maler(tester).versatz,
        greaterThan(0),
        reason:
            'Der Inhalt muss dem Finger folgen, sonst prüft der Fall nichts',
      );
      expect(
        maler(tester).grenzen.$2,
        greaterThanOrEqualTo(900),
        reason:
            'Der Ausreißer wird mitgezeichnet, sobald er ins Bild wandert. '
            'Bleibt die y-Skala die des alten Fensters, schießt die Linie '
            'oben aus dem Bild — Tims Video vom 28.10.2026 (#147)',
      );

      await geste.up();
      await tester.pumpAndSettle();
    });

    testWidgets('die Achse beschriftet die Tage, die im Bild stehen', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: flachMitAusreisser));

      expect(
        [for (final e in maler(tester).achse) e.platz],
        [0, 1, 2, 3, 4, 5, 6],
        reason: 'Vor dem Zug sind es die sieben Plätze des Fensters',
      );

      final geste = await zieheUndHalte(tester, 4.5 / 7);

      final plaetze = [for (final e in maler(tester).achse) e.platz];
      expect(
        plaetze.where((p) => p < 0),
        isNotEmpty,
        reason:
            'Vier Tage der Vorwoche stehen im Bild und brauchen ihre '
            'Beschriftung. Beschriftet die Achse weiter nur das alte '
            'Fenster, bleibt von ihr ein einzelnes „Mo." stehen (#147)',
      );
      expect(
        plaetze.length,
        greaterThanOrEqualTo(7),
        reason:
            'Es stehen nach wie vor sieben Tage im Bild, nur andere — die '
            'Achse darf dabei nicht ausdünnen',
      );

      await geste.up();
      await tester.pumpAndSettle();
    });

    testWidgets('nach dem Loslassen gehört beides wieder zum neuen Fenster', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: flachMitAusreisser));

      // Vier Plätze zurück: Das Fenster beginnt am 01.10., dem Tag des
      // Ausreißers, und endet am 07.10.
      await wische(tester, 4 / 7);

      expect(
        [for (final e in maler(tester).achse) e.platz],
        [0, 1, 2, 3, 4, 5, 6],
        reason:
            'Nach dem Einrasten liegt kein Versatz mehr an, und die Achse '
            'beschriftet wieder genau das Fenster',
      );
      expect(
        maler(tester).grenzen.$2,
        greaterThanOrEqualTo(900),
        reason: 'Der Ausreißer liegt jetzt im Fenster und gehört auf die Achse',
      );
      expect(kopf(tester), contains('01.10.'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #146 — der Hinweis unter der Fußzeile fällt ersatzlos weg
  // ═══════════════════════════════════════════════════════════════════════

  group('Unter der Fußzeile steht nichts', () {
    /// Dieselbe Hülle wie `zeige`, aber **ohne feste Höhe**: Nur so hat das
    /// Diagramm seine eigene Höhe, und nur die kann springen. In `zeige`
    /// füllt es einen 400 Punkt hohen Kasten, egal was darin steht.
    Future<void> zeigeLose(WidgetTester tester, Widget kind) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(huelle(SizedBox(width: 360, child: kind)));
      await tester.pumpAndSettle();
    }

    testWidgets('die Fußzeile ist das Unterste im Diagramm', (tester) async {
      await zeigeLose(tester, diagramm(reihe: eineWoche));

      expect(
        tester.getRect(find.byType(Zeitdiagramm)).bottom,
        tester.getRect(find.byKey(const Key('diagramm-fussnote'))).bottom,
        reason:
            'Tim am 28.10.2026 zum Hinweis „Halten zeigt den Einzelwert": '
            '„bitte entfern ihn komplett" (#146). **Ersatzlos** — bliebe '
            'der Platz reserviert, stünde dort weiter eine leere Zeile',
      );
    });

    testWidgets('und das Diagramm ist beim Ablesen genauso hoch wie ohne', (
      tester,
    ) async {
      await zeigeLose(tester, diagramm(reihe: eineWoche));
      final ohneAuswahl = tester.getSize(find.byType(Zeitdiagramm)).height;

      final geste = await halte(tester, 0.25);
      expect(
        kopf(tester),
        contains('44'),
        reason: 'ohne Auswahl prüfte der Fall nichts',
      );

      expect(
        tester.getSize(find.byType(Zeitdiagramm)).height,
        ohneAuswahl,
        reason:
            'Der Hinweis verschwand beim Ablesen und ließ alles darunter '
            'springen. Was es nicht gibt, kann nicht verschwinden (#146)',
      );

      await lass(tester, geste);
      expect(tester.getSize(find.byType(Zeitdiagramm)).height, ohneAuswahl);
    });
  });

  group('Ablesen durch Halten', () {
    testWidgets('die Kopfzeile zeigt den Wert des gehaltenen Balkens', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: eineWoche));
      final ohneAuswahl = kopf(tester);
      expect(
        ohneAuswahl,
        contains('60'),
        reason: 'ohne Auswahl der Durchschnitt des Fensters: 420 / 7 = 60',
      );

      final geste = await halte(tester, 0.25);

      expect(
        kopf(tester),
        contains('44'),
        reason:
            'Der gehaltene Balken trägt 44. Kein Balken dieser Woche trägt '
            '60 — der Durchschnitt kann es also nicht sein',
      );
      expect(
        kopf(tester),
        isNot(contains('60')),
        reason:
            'Beim Ablesen steht das Datum des Balkens da statt „Durchschnitt" '
            'und Zeitraum (Entwurfs-Spec, „Was gebaut wird")',
      );

      await lass(tester, geste);
    });

    testWidgets('und springt beim Loslassen zurück', (tester) async {
      await zeige(tester, diagramm(reihe: eineWoche));
      final ohneAuswahl = kopf(tester);

      final geste = await halte(tester, 0.25);
      expect(kopf(tester), isNot(ohneAuswahl));

      await lass(tester, geste);

      expect(
        kopf(tester),
        ohneAuswahl,
        reason:
            '„Sie springt beim Loslassen zurück" (Entwurfs-Spec). Eine '
            'Auswahl, die liegen bleibt, lässt den Schirm später eine '
            'einzelne Zahl zeigen, wo ein Durchschnitt stehen sollte',
      );
    });

    testWidgets('zwei verschiedene Balken ergeben zwei verschiedene Köpfe', (
      tester,
    ) async {
      // Alle sieben Tage tragen denselben Wert. Ein Unterschied zwischen
      // zwei Kopfzeilen kann dann nur vom **Datum** kommen — Entscheidung 3
      // im Kopf dieser Datei.
      await zeige(
        tester,
        diagramm(
          reihe: [for (var t = 5; t <= 11; t++) wert(tag(2026, 10, t), 44)],
        ),
      );

      final links = await halte(tester, 0.2);
      final kopfLinks = kopf(tester);
      await lass(tester, links);

      final rechts = await halte(tester, 0.8);
      final kopfRechts = kopf(tester);
      await lass(tester, rechts);

      expect(kopfLinks, contains('44'));
      expect(kopfRechts, contains('44'));
      expect(
        kopfLinks,
        isNot(kopfRechts),
        reason:
            'Bei gleichen Werten unterscheidet nur das Datum die beiden '
            'Balken. Steht keines da, liest man eine Zahl ohne zu wissen, '
            'von wann sie ist',
      );
    });

    testWidgets('über einer Lücke steht „keine Messung", nie der Nachbarwert', (
      tester,
    ) async {
      // Gemessen nur am 05.10. und am 11.10.; die fünf Tage dazwischen
      // sind eine Lücke.
      await zeige(tester, diagramm(reihe: wocheMitLuecke));

      final geste = await halte(tester, 0.5);
      final gehalten = kopf(tester).toLowerCase();

      expect(
        gehalten,
        contains('keine messung'),
        reason:
            '„Lücken bleiben Lücken. Beim Ablesen steht dort „keine '
            'Messung", nie der Nachbarwert" (Entwurfs-Spec, '
            'Entscheidungstabelle). Das ist eine Regel, kein Layout',
      );
      expect(
        gehalten,
        isNot(contains('100')),
        reason: 'der Nachbar links — kein Interpolieren über leere Tage',
      );
      expect(gehalten, isNot(contains('140')), reason: 'der Nachbar rechts');

      await lass(tester, geste);
      expect(
        kopf(tester).toLowerCase(),
        isNot(contains('keine messung')),
        reason: 'auch dieser Zustand springt beim Loslassen zurück',
      );
    });
  });

  group('Die beiden Gesten vertragen sich', () {
    testWidgets('ein Halten verschiebt das Fenster nicht', (tester) async {
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      final geste = await halte(tester, 0.5);
      await lass(tester, geste);

      expect(
        kopf(tester),
        vorher,
        reason:
            'Die Auswahlgeste darf das Fenster nicht mitnehmen — wer ablesen '
            'will, will nicht blättern',
      );
      expect(kopf(tester), contains('333'));
    });

    testWidgets('nach einem Wisch steht wieder ein Durchschnitt da', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: dreiWochen));

      await wische(tester, 1.0);

      expect(
        kopf(tester),
        anyOf(contains('222'), contains('111')),
        reason:
            '111 und 222 sind Fensterdurchschnitte und stehen auf keinem '
            'einzelnen Balken. Bliebe nach dem Wisch eine Auswahl hängen, '
            'stünde dort ein Balkenwert (100, 177, 200 oder 354)',
      );
      expect(
        kopf(tester).toLowerCase(),
        isNot(contains('keine messung')),
        reason: 'ein Wisch ist kein Ablesen',
      );
    });

    testWidgets('die Auswahlgeste frisst das Schieben nicht', (tester) async {
      // Der Fehler aus der Spec, wörtlich: „`.chartGesture` ersetzt die
      // eingebauten Gesten des Diagramms einschließlich des Scrollens" —
      // mit eigener Long-Press-Geste ließ sich der Graph nicht mehr
      // schieben. In Flutter steuern wir beides selbst, also wird beides
      // nacheinander geprüft.
      await zeige(tester, diagramm(reihe: dreiWochen));
      final vorher = kopf(tester);

      final geste = await halte(tester, 0.5);
      await lass(tester, geste);
      await wische(tester, 1.0);

      expect(
        kopf(tester),
        isNot(vorher),
        reason:
            'Nach einem Ablesen muss sich der Graph weiter schieben lassen. '
            'Genau daran ist der SwiftUI-Anlauf gescheitert',
      );
      expect(kopf(tester), anyOf(contains('222'), contains('111')));
    });

    testWidgets('und das Schieben frisst das Ablesen nicht', (tester) async {
      await zeige(tester, diagramm(reihe: eineWoche));

      await wische(tester, -1.0);
      final ohneAuswahl = kopf(tester);

      final geste = await halte(tester, 0.25);
      expect(kopf(tester), contains('44'));
      await lass(tester, geste);

      expect(kopf(tester), ohneAuswahl);
    });
  });

  group('Der Stufenwechsel', () {
    testWidgets('er ändert das Fenster', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: dreiWochen,
          stufen: const [DiagrammStufe.woche, DiagrammStufe.halbjahr],
        ),
      );
      final aufW = kopf(tester);

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(leiste(tester).gewaehlt, DiagrammStufe.halbjahr);
      expect(
        kopf(tester),
        isNot(aufW),
        reason:
            'Sechs Monate sind ein anderes Fenster als eine Woche, also ein '
            'anderer Durchschnitt und ein anderer Zeitraum. Bleibt der Kopf '
            'stehen, rechnet die Stufe nichts nach',
      );
    });

    testWidgets('er verdichtet die Punkte — der Jahresschnitt ist nicht der '
        'Wochenschnitt', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: dreiWochen,
          stufen: const [DiagrammStufe.woche, DiagrammStufe.halbjahr],
        ),
      );

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(
        kopf(tester),
        isNot(contains('333')),
        reason:
            'Ab `6M` ist ein Balken ein Kalendermonat mit dessen '
            'Tagesdurchschnitt; der Schnitt über September und Oktober kann '
            'nicht der Schnitt der jüngsten Woche sein',
      );
    });

    testWidgets('und er nimmt eine laufende Auswahl mit', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: eineWoche,
          stufen: const [DiagrammStufe.woche, DiagrammStufe.halbjahr],
        ),
      );

      final geste = await halte(tester, 0.25);
      expect(kopf(tester), contains('44'));

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(
        kopf(tester),
        isNot(contains('44')),
        reason:
            'Ein Balken aus der Wochenansicht hat im Halbjahr keine '
            'Entsprechung. Eine Auswahl, die den Stufenwechsel überlebt, '
            'zeigt einen Tag, den es in der neuen Stufe nicht gibt',
      );

      await lass(tester, geste);
      expect(tester.takeException(), isNull);
    });

    testWidgets('die Fußzeile nennt die Verdichtung der gewählten Stufe', (
      tester,
    ) async {
      final gefragt = <DiagrammStufe>[];
      await zeige(
        tester,
        diagramm(
          reihe: dreiWochen,
          stufen: const [DiagrammStufe.woche, DiagrammStufe.halbjahr],
          fussnote: (s) {
            gefragt.add(s);
            return 'fuss-${s.name}';
          },
        ),
      );

      expect(fuss(tester), contains('fuss-${DiagrammStufe.woche.name}'));

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();

      expect(
        fuss(tester),
        contains('fuss-${DiagrammStufe.halbjahr.name}'),
        reason:
            'Den Wortlaut liefert der Schirm; das Bauteil muss ihn mit der '
            'gerade gewählten Stufe erfragen. Fragt es immer mit der '
            'Startstufe, behauptet die Fußzeile auf `6M` weiter Tageswerte',
      );
      expect(gefragt, contains(DiagrammStufe.halbjahr));
    });
  });

  group('Die Einheit in der Kopfzeile', () {
    // „Minuten / Tag" statt „min / Tag" — Entscheidung 7 im Kopf dieser
    // Datei. Der Wortlaut der echten Einheit gehört in den Schirm.
    const proTag = 'Minuten / Tag';
    const amBalken = 'Minuten';

    testWidgets('sie steht neben dem Durchschnitt', (tester) async {
      await zeige(tester, diagramm(reihe: eineWoche, einheit: proTag));

      expect(kopf(tester), contains('60'));
      expect(
        kopf(tester),
        contains(proTag),
        reason:
            'Das Entwurfsboard zeigt die Einheit neben der Zahl '
            '(`chartCard`: `<b>value</b><span>unit</span>`), und Tim hat sie '
            'am 27.10.2026 ausdrücklich bestellt: „ja min/tag". Eine nackte '
            'Zahl über einem Diagramm sagt nicht, wovon sie 60 ist',
      );
    });

    testWidgets('ohne Einheit bleibt die Kopfzeile, wie sie war', (
      tester,
    ) async {
      String eng(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

      await zeige(tester, diagramm(reihe: eineWoche));
      final ohne = kopf(tester);

      await zeige(tester, diagramm(reihe: eineWoche, einheit: proTag));
      final mit = kopf(tester);

      expect(mit, isNot(ohne), reason: 'die Einheit steht sonst nirgends');
      expect(
        eng(mit.replaceAll(proTag, '')),
        eng(ohne),
        reason:
            'Die Einheit ist **additiv**: Sie kommt hinzu und ersetzt '
            'nichts. Müsste ein Schirm eine mitliefern, nur damit die '
            'Kopfzeile wieder stimmt, wäre der neue Parameter keine '
            'Ergänzung, sondern eine Änderung an allem, was es schon gibt',
      );
    });

    testWidgets('ohne zweite Beschriftung gilt sie auch beim Ablesen', (
      tester,
    ) async {
      // `kg`, `ms`, `bpm`: dieselbe Einheit in beiden Zuständen. Der
      // Normalfall darf ein Feld brauchen, nicht zwei.
      await zeige(tester, diagramm(reihe: eineWoche, einheit: 'kg'));

      final geste = await halte(tester, 0.25);
      expect(kopf(tester), contains('44'));
      expect(
        kopf(tester),
        contains('kg'),
        reason:
            'Ein Kilogramm bleibt ein Kilogramm, ob Fensterschnitt oder '
            'einzelner Balken. Verschwände die Einheit beim Halten, stünde '
            'dort eine Zahl ohne Maß',
      );

      await lass(tester, geste);
      expect(kopf(tester), contains('kg'));
    });

    testWidgets('eine eigene Beschriftung fürs Ablesen ersetzt sie', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(reihe: eineWoche, einheit: proTag, einheitAbgelesen: amBalken),
      );
      expect(kopf(tester), contains(proTag));

      final geste = await halte(tester, 0.25);

      expect(kopf(tester), contains('44'));
      expect(kopf(tester), contains(amBalken));
      expect(
        kopf(tester),
        isNot(contains(proTag)),
        reason:
            '„44 Minuten / Tag" wäre falsch: Das ist der Wert **dieses** '
            'Tages, kein Durchschnitt pro Tag. Genau dafür trägt die '
            'SwiftUI-Vorlage zwei Beschriftungen — `unitLabel` und '
            '`pickedUnitLabel` (Entwurfs-Spec, „Der Rahmen")',
      );

      await lass(tester, geste);
      expect(
        kopf(tester),
        contains(proTag),
        reason:
            'Die Kopfzeile springt beim Loslassen zurück — die Einheit '
            'gehört dazu, sonst steht über einem Fensterschnitt die '
            'Beschriftung eines einzelnen Balkens',
      );
    });

    testWidgets('über einer Lücke steht keine Einheit', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: wocheMitLuecke,
          einheit: proTag,
          einheitAbgelesen: amBalken,
        ),
      );

      final geste = await halte(tester, 0.5);
      final gehalten = kopf(tester).toLowerCase();

      expect(gehalten, contains('keine messung'));
      expect(
        gehalten,
        isNot(contains(amBalken.toLowerCase())),
        reason:
            '„keine Messung Minuten" ist kein Satz. Eine Einheit ohne Zahl '
            'behauptet eine Messung, die es an diesem Tag nicht gab — '
            'Entscheidung 6 im Kopf dieser Datei',
      );

      await lass(tester, geste);
      expect(kopf(tester), contains(proTag));
    });
  });

  group('Der abgelesene Wert steht in Flussblau', () {
    // „Bei Auswahl nennt der Kopf den Tag statt „Durchschnitt", und der
    // Wert steht in Flussblau" (`chartCard` in `docs/screens/components.js`,
    // `style="color:var(--river)"`). Das ist eine Regel des Entwurfs, keine
    // Beschriftung: Sie unterscheidet die beiden Zustände der Kopfzeile.

    /// Die Farbe, in der die Kopfzeile eine Zeichenkette zeigt — gelesen am
    /// gezeichneten Absatz, nicht am `Text`-Widget. Dann ist es gleich, ob
    /// die Farbe am `Text` selbst hängt oder an einem `DefaultTextStyle`
    /// darüber.
    Color kopfFarbe(WidgetTester tester, String teil) {
      final treffer = find.descendant(
        of: find.byKey(const Key('diagramm-kopfzeile')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && textOf(widget).contains(teil),
        ),
      );
      expect(
        treffer,
        findsOneWidget,
        reason:
            '„$teil" muss genau einmal in der Kopfzeile stehen — sonst '
            'liest dieser Test die Farbe irgendeiner anderen Zeile',
      );
      return tester.renderObject<RenderParagraph>(treffer).text.style?.color ??
          const Color(0x00000000);
    }

    Color flussblau(WidgetTester tester) => CupertinoDynamicColor.resolve(
      Palette.river,
      tester.element(find.byType(Zeitdiagramm)),
    );

    testWidgets('ohne Auswahl nicht', (tester) async {
      await zeige(tester, diagramm(reihe: eineWoche));

      expect(
        kopfFarbe(tester, '60'),
        isNot(flussblau(tester)),
        reason:
            'Stünde der Durchschnitt schon in Flussblau, unterschiede die '
            'Farbe die beiden Zustände nicht mehr',
      );
    });

    testWidgets('beim Ablesen schon — und zurück beim Loslassen', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: eineWoche));

      final geste = await halte(tester, 0.25);
      expect(kopfFarbe(tester, '44'), flussblau(tester));

      await lass(tester, geste);
      expect(kopfFarbe(tester, '60'), isNot(flussblau(tester)));
    });
  });

  group('Eine leere Reihe', () {
    testWidgets('stürzt nicht ab', (tester) async {
      await zeige(tester, diagramm(reihe: const []));

      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('und erfindet keinen Durchschnitt', (tester) async {
      await zeige(tester, diagramm(reihe: const []));

      expect(
        kopf(tester),
        isNot(matches(RegExp(r'\d'))),
        reason:
            'Ohne Messwert gibt es keinen Durchschnitt und keinen Zeitraum. '
            'Eine 0 behauptete eine Messung, die es nicht gab — dasselbe '
            'Muster wie „0 Schritte, obwohl Daten da sind" (docs/todo/01)',
      );
    });

    testWidgets('und keine Einheit', (tester) async {
      await zeige(tester, diagramm(reihe: const [], einheit: 'Minuten / Tag'));

      expect(
        kopf(tester).toLowerCase(),
        isNot(contains('minuten')),
        reason:
            'Die Einheit gehört zu einer Zahl. Ohne Messwert steht dort '
            'keine — „— Minuten / Tag" behauptete ein Maß für etwas, das '
            'nicht gemessen wurde. Dasselbe Muster wie „erfindet keinen '
            'Durchschnitt" eine Zeile darüber (docs/todo/01)',
      );
    });

    testWidgets('und hält auch eine Geste aus', (tester) async {
      await zeige(tester, diagramm(reihe: const []));

      final geste = await tester.startGesture(
        tester.getCenter(find.byType(Zeitdiagramm)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await geste.moveBy(const Offset(120, 0));
      await tester.pump();
      await geste.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        kopf(tester).toLowerCase(),
        isNot(contains('keine messung')),
        reason:
            'Ohne Reihe gibt es keinen Balken, über dem eine Messung fehlen '
            'könnte — „keine Messung" gehört zu einer Lücke **in** den Daten',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Nachtrag vom 28.10.2026: der Tagesversatz in der Kopfzeile
  //
  // Am 28.10.2026 im Simulator von Hand gefunden, von keinem der 1047
  // grünen Tests. Der HRV-Verlaufs-Schirm zeigte über dem Diagramm
  // „25.10. – 31.10."; richtig wäre „26.10. – 01.11.". **Jedes angezeigte
  // Datum des Diagramms war einen Tag zu früh.**
  //
  // **Die Rechnung ist nicht schuld.** `startFenster` liefert für den
  // 26.10.2026 korrekt Montag 26.10. bis Montag 02.11.; der Test „W rastet
  // auch über die Zeitumstellung richtig" in
  // `test/shell/diagramm_zeitraum_test.dart` ist grün. Falsch ist allein
  // die **Anzeige**: `Format.tagMonat` bekommt einen Berliner
  // Mitternachts-Zeitpunkt, wie ihn `BerlinCalendar` zurückgibt, und das
  // ist ein **UTC-Zeitpunkt**. Montag 26.10.2026 00:00 Berliner Zeit *ist*
  // der 25.10.2026 23:00 UTC, und `DateFormat` liest die UTC-Felder. Jede
  // andere Stelle der App geht deshalb durch `kalendertag(…)`
  // (`lib/shell/erholung_abschnitte.dart`): „Alles, was ein Datum
  // **anzeigt**, geht durch hier."
  //
  // Die Achsenbeschriftung ist derselbe Fehler an derselben Ursache; sie
  // wird dort geprüft, wo sie gerechnet wird — `achse()` in
  // `test/design/zeitdiagramm_fenster_test.dart`.
  //
  // **Entscheidungen dieser Ergänzung — vom Test-Agenten, nicht von Tim:**
  //
  // a) **Geprüft wird auf die Tagesangabe, nicht auf den ganzen Satz.**
  //    `CLAUDE.md` lässt keine Tests auf Beschriftungen zu. Ob zwischen den
  //    beiden Daten ein Gedankenstrich, ein Bindestrich oder das Wort „bis"
  //    steht, geht diesen Fehler nichts an; dass dort der 26.10. steht und
  //    nicht der 25.10., schon. Jeder Fall prüft deshalb beides: Die
  //    richtige Angabe **muss** dastehen, die um einen Tag verschobene
  //    **darf nicht**.
  //
  // b) **Drei Jahreszeiten.** Der Versatz ist im Winter (UTC+1) wie im
  //    Sommer (UTC+2) da, nur unterschiedlich groß. Ein Test, der nur die
  //    Zeitumstellung prüft, ließe die Ursache halb stehen.
  //
  // c) **Beim Ablesen wird mit `Format` verglichen, nicht mit einem
  //    Literal.** Der Wortlaut von `wochentagUndDatum` („Montag, 26.
  //    Oktober") ist eine Formatentscheidung; dass es der **Montag** ist
  //    und nicht der Sonntag davor, ist die Behauptung. Erwartet wird
  //    deshalb `Format.wochentagUndDatum` auf einem reinen Kalendertag —
  //    genau das, was `kalendertag(…)` liefern würde.
  // ═══════════════════════════════════════════════════════════════════════

  group('Der Zeitraum in der Kopfzeile nennt die Tage des Fensters', () {
    testWidgets('eine Woche ab Montag, dem 26.10.2026', (tester) async {
      // Der härteste Fall, den die Spec kennt: Die Sommerzeit endet am
      // Sonntag, 25.10.2026. Der 26.10. ist der Montag danach, und
      // `startFenster` rastet bei `W` auf den Montag.
      await zeige(
        tester,
        diagramm(
          reihe: [
            for (var i = 0; i < 7; i++)
              wert(BerlinCalendar.addDays(tag(2026, 10, 26), i), 41),
          ],
        ),
      );

      expect(
        kopf(tester),
        contains('26.10.'),
        reason:
            'Das Fenster beginnt am Montag, 26.10.2026. Im Simulator stand '
            'dort am 28.10.2026 „25.10." — der UTC-Zeitpunkt der Berliner '
            'Mitternacht trägt in UTC den Vortag',
      );
      expect(
        kopf(tester),
        contains('01.11.'),
        reason:
            'und es endet am Sonntag, 01.11.2026 (halboffen bis Montag, '
            'dem 02.11.). Im Simulator stand dort „31.10."',
      );
      expect(
        kopf(tester),
        isNot(contains('25.10.')),
        reason:
            'Der Sonntag davor gehört in das Fenster davor. Steht er hier, '
            'ist jedes angezeigte Datum des Diagramms einen Tag zu früh',
      );
    });

    testWidgets('mitten im Winter ist derselbe Versatz da (UTC+1)', (
      tester,
    ) async {
      // Keine Zeitumstellung weit und breit — und trotzdem liegt Berliner
      // Mitternacht in UTC auf dem Vortag.
      await zeige(
        tester,
        diagramm(
          reihe: [
            for (var i = 0; i < 7; i++)
              wert(BerlinCalendar.addDays(tag(2026, 1, 12), i), 41),
          ],
        ),
      );

      expect(kopf(tester), contains('12.01.'));
      expect(kopf(tester), contains('18.01.'));
      expect(
        kopf(tester),
        isNot(contains('11.01.')),
        reason: 'Montag 00:00 Berlin ist im Winter Sonntag 23:00 UTC',
      );
    });

    testWidgets('mitten im Sommer auch (UTC+2)', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: [
            for (var i = 0; i < 7; i++)
              wert(BerlinCalendar.addDays(tag(2026, 7, 13), i), 41),
          ],
        ),
      );

      expect(kopf(tester), contains('13.07.'));
      expect(kopf(tester), contains('19.07.'));
      expect(
        kopf(tester),
        isNot(contains('12.07.')),
        reason:
            'Montag 00:00 Berlin ist im Sommer Sonntag 22:00 UTC — derselbe '
            'Fehler, nur zwei Stunden tief',
      );
    });

    testWidgets('und auf `6M` stehen die Monatsgrenzen richtig', (
      tester,
    ) async {
      // Mai bis Oktober 2026, je ein Messwert. Das Fenster endet am 01.11.
      // (halboffen) und reicht sechs Monate zurück: 01.05. bis 31.10.
      await zeige(
        tester,
        diagramm(
          reihe: [for (var m = 5; m <= 10; m++) wert(tag(2026, m, 15), 41)],
          stufen: const [DiagrammStufe.halbjahr],
        ),
      );

      expect(
        kopf(tester),
        contains('01.05.'),
        reason:
            'Der Monatserste trägt seinen eigenen Tag. „30.04." fiele sogar '
            'in den Vormonat — die Kopfzeile behauptete einen Monat, der '
            'nicht im Fenster liegt',
      );
      expect(kopf(tester), contains('31.10.'));
      expect(kopf(tester), isNot(contains('30.04.')));
    });
  });

  group('Der abgelesene Balken nennt sein eigenes Datum', () {
    /// Der Wortlaut, den `Format` für einen **Kalendertag** liefert — also
    /// für ein reines Datum ohne Zeitzonenlast. Die Kopfzeile schreibt den
    /// Kicker groß, deshalb der Vergleich in Großbuchstaben.
    String kickerFuer(int jahr, int monat, int t) =>
        Format.wochentagUndDatum(DateTime.utc(jahr, monat, t)).toUpperCase();

    testWidgets('der erste Balken der Woche ab dem 26.10.2026 ist der Montag', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(
          reihe: [
            for (var i = 0; i < 7; i++)
              wert(BerlinCalendar.addDays(tag(2026, 10, 26), i), 41),
          ],
        ),
      );

      final geste = await halte(tester, 0.05);

      expect(
        kopf(tester),
        contains('41'),
        reason:
            'erst die Vorbedingung: Es ist wirklich ein Balken ausgewählt, '
            'sonst stünde dort der Durchschnitt',
      );
      expect(
        kopf(tester),
        contains(kickerFuer(2026, 10, 26)),
        reason:
            'Der ganz linke Balken ist der Montag, 26.10.2026 — der erste '
            'Platz des Fensters. Dieselbe Ursache wie beim Zeitraum: '
            '`abgelesen.beginn` ist der UTC-Zeitpunkt der Berliner '
            'Mitternacht, und formatiert steht dort der Vortag',
      );
      expect(
        kopf(tester),
        isNot(contains(kickerFuer(2026, 10, 25))),
        reason:
            'Der Sonntag davor liegt nicht im Fenster. Wer einen Wert '
            'abliest, muss wissen, von welchem Tag er ist',
      );

      await lass(tester, geste);
    });

    testWidgets('und im Sommer ebenso', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: [
            for (var i = 0; i < 7; i++)
              wert(BerlinCalendar.addDays(tag(2026, 7, 13), i), 41),
          ],
        ),
      );

      final geste = await halte(tester, 0.05);

      expect(kopf(tester), contains(kickerFuer(2026, 7, 13)));
      expect(kopf(tester), isNot(contains(kickerFuer(2026, 7, 12))));

      await lass(tester, geste);
    });

    testWidgets('auf `6M` nennt er seinen Monat, nicht den Vormonat', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(
          reihe: [for (var m = 5; m <= 10; m++) wert(tag(2026, m, 15), 41)],
          stufen: const [DiagrammStufe.halbjahr],
        ),
      );

      final geste = await halte(tester, 0.05);

      expect(
        kopf(tester).toUpperCase(),
        contains('MAI'),
        reason:
            'Der erste Platz ist der Mai 2026. Mit dem Versatz stünde dort '
            'der 30. April — ein Monat, der gar nicht im Fenster liegt, und '
            'auf dieser Stufe ist ein Platz ein ganzer Monat',
      );
      expect(kopf(tester).toUpperCase(), isNot(contains('APRIL')));

      await lass(tester, geste);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #150 — die Kopfzeile läuft beim Ziehen mit
  //
  // Seit #147 zeigen Achse und y-Skala während eines Zuges den
  // **verschobenen** Ausschnitt. Die Kopfzeile tat das nicht: Über einer
  // Achse, die längst den 21.10. nannte, stand weiter „Durchschnitt 333 ·
  // 05.10. – 11.10.". Tim hat das am 28.10.2026 auf dem Gerät gesehen und
  // entschieden, dass Durchschnitt und Zeitraum über denselben Ausschnitt
  // rechnen.
  //
  // Die Rechnung selbst steht in `zeitdiagramm_fenster_test.dart`
  // (`ueberblick()`); hier wird geprüft, dass das Bauteil sie auch fragt.
  //
  // **Entscheidungen dieser Ergänzung — vom Test-Agenten, nicht von Tim:**
  //
  // a) **Die Reihe ist so gebaut, dass drei Zahlen auseinanderfallen.** Die
  //    gezeigte Woche hat überall 500, die Vorwoche überall 900, und der
  //    Ausschnitt mitten im Zug ergibt 750 — eine Zahl, die in keiner der
  //    beiden Wochen als Balken vorkommt. „750" kann damit nur aus dem
  //    mitgelaufenen Durchschnitt stammen.
  // b) **Geprüft wird auf die Tagesangabe, nicht auf den ganzen Satz**
  //    (`CLAUDE.md`: keine Tests auf Beschriftungen) — wie schon im
  //    Nachtrag zum Tagesversatz weiter oben.
  // c) **Kopfzeile und Achse werden gegeneinander geprüft.** Dass beide
  //    sich bewegen, ist die halbe Sache; dass sie **denselben** Ausschnitt
  //    meinen, ist die andere. Ein Durchschnitt über acht Tage neben einer
  //    Achse über sieben wäre wieder eine falsche Auskunft, nur eine
  //    schwerer zu findende.
  // d) **Beim Ablesen bleibt es beim Balken.** Das ist keine neue Regel,
  //    sondern die alte — sie wird hier mitgeprüft, weil beide Zustände
  //    jetzt dieselbe Kopfzeile teilen und ein Umbau sie verwechseln
  //    könnte.
  // ═══════════════════════════════════════════════════════════════════════

  group('Die Kopfzeile läuft beim Ziehen mit', () {
    /// Zwei volle Wochen mit glatten, deutlich verschiedenen Werten: die
    /// gezeigte Woche ab Montag, dem 26.10.2026, die Vorwoche ab dem 19.10.
    final zweiWochen = <({DateTime tag, double wert})>[
      for (var i = 0; i < 7; i++)
        wert(BerlinCalendar.addDays(tag(2026, 10, 19), i), 900),
      for (var i = 0; i < 7; i++)
        wert(BerlinCalendar.addDays(tag(2026, 10, 26), i), 500),
    ];

    testWidgets('der Durchschnitt folgt dem Ausschnitt', (tester) async {
      await zeige(tester, diagramm(reihe: zweiWochen));

      expect(kopf(tester), contains('500'), reason: 'vor dem Zug die Woche');

      final geste = await zieheUndHalte(tester, 4.5 / 7);

      expect(
        maler(tester).versatz,
        greaterThan(0),
        reason:
            'Der Inhalt muss dem Finger folgen, sonst prüft der Fall nichts',
      );
      expect(
        kopf(tester),
        contains('750'),
        reason:
            'Im Bild stehen fünf Tage der 900er-Woche und drei der '
            '500er-Woche: (5 × 900 + 3 × 500) / 8 = 750. Bleibt die '
            'Kopfzeile stehen, behauptet sie einen Durchschnitt für Tage, '
            'die niemand mehr sieht (#150)',
      );
      expect(kopf(tester), isNot(contains('500')));

      await geste.up();
      await tester.pumpAndSettle();
    });

    testWidgets('der Zeitraum auch', (tester) async {
      await zeige(tester, diagramm(reihe: zweiWochen));

      expect(kopf(tester), contains('26.10.'));
      expect(kopf(tester), contains('01.11.'));

      final geste = await zieheUndHalte(tester, 4.5 / 7);

      expect(
        kopf(tester),
        contains('21.10.'),
        reason:
            'Fünf Plätze vor dem Fensterbeginn stehen im Bild; der erste '
            'davon ist der 21.10.2026',
      );
      expect(
        kopf(tester),
        isNot(contains('01.11.')),
        reason:
            'und der 01.11. ist aus dem Bild gewandert. Steht er noch da, '
            'nennt die Kopfzeile ein Fenster, das nicht mehr gezeigt wird',
      );

      await geste.up();
      await tester.pumpAndSettle();
    });

    testWidgets('und sie meint denselben Ausschnitt wie die Achse', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: zweiWochen));

      final geste = await zieheUndHalte(tester, 4.5 / 7);

      // Der Stand zu derselben Reihe, um die Plätze der Achse in Tage zu
      // übersetzen. Die Achse trägt bei `W` den Wochentag, die Kopfzeile
      // Tag und Monat — ein Vergleich der beiden Zeichenketten wäre ein
      // Vergleich zweier Formate, nicht zweier Ausschnitte.
      final stand = Fensterstand.aus(
        reihe: zweiWochen,
        stufe: DiagrammStufe.woche,
        verschiebung: 0,
      );
      final achse = maler(tester).achse;
      expect(
        achse,
        isNotEmpty,
        reason: 'ohne Achse prüfte der Vergleich nichts',
      );

      String tagMonatVon(int platz) =>
          Format.tagMonat(kalendertag(stand.platzBeginn(platz)!));

      expect(
        kopf(tester),
        contains(tagMonatVon(achse.first.platz)),
        reason:
            'Der erste beschriftete Platz der Achse ist zugleich der erste '
            'Tag des Zeitraums in der Kopfzeile. Rechnen die beiden über '
            'verschiedene Ausschnitte, fällt das sonst niemandem auf',
      );
      expect(
        kopf(tester),
        contains(tagMonatVon(achse.last.platz)),
        reason: 'und der letzte ebenso',
      );

      await geste.up();
      await tester.pumpAndSettle();
    });

    testWidgets('beim Ablesen gilt weiter der Balken, nicht der Ausschnitt', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: zweiWochen));

      final geste = await halte(tester, 0.5 / 7);

      expect(
        kopf(tester),
        contains('500'),
        reason:
            'Gehalten wird der erste Balken der gezeigten Woche — sein '
            'eigener Wert, kein Durchschnitt über irgendeinen Ausschnitt',
      );
      expect(
        kopf(tester).toUpperCase(),
        contains(
          Format.wochentagUndDatum(DateTime.utc(2026, 10, 26)).toUpperCase(),
        ),
        reason: 'und sein eigener Tag statt eines Zeitraums',
      );

      await lass(tester, geste);
    });

    testWidgets('nach dem Loslassen steht das eingerastete Fenster da', (
      tester,
    ) async {
      await zeige(tester, diagramm(reihe: zweiWochen));

      // Fünf Plätze zurück: Das Fenster beginnt am 21.10. und endet am 27.10.
      await wische(tester, 5 / 7);

      expect(
        kopf(tester),
        contains('21.10.'),
        reason: 'Nach dem Einrasten ist der Ausschnitt wieder das Fenster',
      );
      expect(kopf(tester), contains('27.10.'));
      expect(
        kopf(tester),
        isNot(contains('750')),
        reason:
            'Der Durchschnitt des angeschnittenen Ausschnitts darf nicht '
            'stehen bleiben — im Fenster liegen jetzt fünf Tage der '
            '900er-Woche und zwei der 500er-Woche',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // #151 — ein Formatierer-Haken für die Kopfzahl
  //
  // Die Kopfzahl läuft durch eine eingebaute, deutsch gruppierte
  // Zahlformatierung. Beim Schlaf steht dort „6,7"; richtig wäre „6:40" —
  // Stunden und Minuten. Tim hat am 28.10.2026 entschieden: ein
  // **optionaler** Haken am Bauteil, damit ein Schirm sein eigenes Format
  // mitgeben kann. Gegen die billigere Lösung (`einheit: 'h Schlaf /
  // Nacht'`) hat er sich ausdrücklich entschieden, weil „6,7 h" eben nicht
  // „6:40" ist.
  //
  // **Entscheidungen dieser Ergänzung — vom Test-Agenten, nicht von Tim:**
  //
  // a) **Der Haken gilt für beide Zustände.** Der Durchschnitt und der
  //    abgelesene Balken sind dieselbe Zahl an derselben Stelle; beim
  //    Schlaf wäre „6:45" über dem Fenster und „7,5" über einem Balken
  //    zwei Formate in einer Zeile. Die **Einheit** trennt die beiden
  //    Zustände bereits (`einheit`/`einheitAbgelesen`) — das ist die
  //    Stelle, an der ein Schirm unterscheiden kann, wenn er muss.
  // b) **Er bekommt die Zahl, nicht den fertigen Text.** Ein Haken, der
  //    einen String hereinbekommt, könnte nur noch anhängen; „6,7" lässt
  //    sich nicht mehr in „6:40" zurückrechnen.
  // c) **Wo keine Zahl steht, wird er nicht gefragt.** Über einer Lücke
  //    steht „keine Messung", bei leerer Reihe „—"; beides sind keine
  //    Zahlen. Würde der Haken dort mit einer erfundenen 0 gefragt, stünde
  //    beim Schlaf „0:00" statt „keine Messung" — `docs/todo/01` eine Ebene
  //    tiefer.
  // d) **Die Testwerte sind Schlafstunden, weil das der Auslöser ist**, und
  //    sie sind erfunden: 6,75 Stunden im Schnitt, ein Balken mit 7,5. Ohne
  //    Haken ergibt das „6,8" und „7,5", mit Haken „6:45" und „7:30" — vier
  //    Zeichenketten, von denen keine in einer anderen steckt.
  // ═══════════════════════════════════════════════════════════════════════

  group('Der Formatierer-Haken für die Kopfzahl', () {
    /// Eine Woche in Stunden: der erste Tag 7,5, die übrigen sechs 6,625.
    /// (7,5 + 6 × 6,625) / 7 = 6,75.
    final stundenWoche = <({DateTime tag, double wert})>[
      wert(tag(2026, 10, 5), 7.5),
      for (var t = 6; t <= 11; t++) wert(tag(2026, 10, t), 6.625),
    ];

    /// Stunden als „6:45" — was ein Schlafschirm mitgeben würde.
    String stundenMinuten(double stunden) {
      final minuten = (stunden * 60).round();
      return '${minuten ~/ 60}:${(minuten % 60).toString().padLeft(2, '0')}';
    }

    testWidgets('ohne Haken bleibt die Kopfzahl, wie sie war', (tester) async {
      await zeige(tester, diagramm(reihe: stundenWoche));

      expect(
        kopf(tester),
        contains('6,8'),
        reason:
            'Der Haken ist optional. Ohne ihn muss sich das Bauteil genau '
            'wie bisher verhalten — deutsch gruppiert, eine Nachkommastelle',
      );
    });

    testWidgets('mit Haken formt der Schirm den Durchschnitt', (tester) async {
      await zeige(
        tester,
        diagramm(reihe: stundenWoche, kopfzahl: stundenMinuten),
      );

      expect(
        kopf(tester),
        contains('6:45'),
        reason:
            'Der Fensterschnitt sind 6,75 Stunden. „6,7" ist keine Uhrzeit — '
            'genau Tims Beanstandung (#151)',
      );
      expect(kopf(tester), isNot(contains('6,8')));
    });

    testWidgets('und den abgelesenen Balken', (tester) async {
      await zeige(
        tester,
        diagramm(reihe: stundenWoche, kopfzahl: stundenMinuten),
      );

      final geste = await halte(tester, 0.5 / 7);

      expect(
        kopf(tester),
        contains('7:30'),
        reason:
            'Der gehaltene Balken trägt 7,5 Stunden. Liefe er am Haken '
            'vorbei, stünden zwei Formate in derselben Zeile',
      );
      expect(kopf(tester), isNot(contains('7,5')));

      await lass(tester, geste);
    });

    testWidgets('über einer Lücke wird er nicht gefragt', (tester) async {
      final gefragt = <double>[];

      await zeige(
        tester,
        diagramm(
          reihe: wocheMitLuecke,
          kopfzahl: (w) {
            gefragt.add(w);
            return 'ZAHL';
          },
        ),
      );
      gefragt.clear();

      // Mitten in der Woche liegt kein Messwert — Platz 3 von sieben.
      final geste = await halte(tester, 3.5 / 7);

      expect(
        kopf(tester).toLowerCase(),
        contains('keine messung'),
        reason: 'Über einer Lücke steht kein Wert, nie der Nachbarwert',
      );
      expect(
        gefragt,
        isEmpty,
        reason:
            'und der Haken wird gar nicht erst gefragt. Mit einer '
            'erfundenen 0 stünde beim Schlaf „0:00" statt „keine Messung"',
      );
      expect(kopf(tester), isNot(contains('ZAHL')));

      await lass(tester, geste);
    });

    testWidgets('bei leerer Reihe auch nicht', (tester) async {
      final gefragt = <double>[];

      await zeige(
        tester,
        diagramm(
          reihe: const [],
          kopfzahl: (w) {
            gefragt.add(w);
            return 'ZAHL';
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        gefragt,
        isEmpty,
        reason:
            'Ohne einen einzigen Messwert gibt es keine Zahl zu formen. Der '
            'Haken darf nicht mit einer erfundenen 0 gefragt werden',
      );
      expect(kopf(tester), isNot(contains('ZAHL')));
    });
  });
}
