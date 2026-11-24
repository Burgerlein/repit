import 'dart:math' show Random;

import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `SpanBuckets` — Ticket #148.
///
/// **Die Spec ist das Entwurfsboard.** `docs/screens/screens/schlaf.js`,
/// Abschnitte `PULS` („Herzfrequenz im Schlaf") und `ATMUNG`
/// („Atemfrequenz im Schlaf"), gezeichnet von `minMaxChart` in
/// `docs/screens/components.js`. Beide übergeben dort **acht** Tripel der
/// Form `['23:30', 58, 71]` — Uhrzeit, Tiefst-, Höchstwert; je Abschnitt
/// **eine** Spanne.
///
/// Die gebaute Fassung zeichnet stattdessen jede Einzelmessung als eigene
/// Kapsel — im Bildschirmfoto rund achtzehn nebeneinander, teils zwei Punkt
/// breit. Tim am Gerät: „die sind nicht lesbar. da fehlen auch die spitzen
/// werte aus dem design". Es fehlt also eine **Verdichtung**: aus vielen
/// Einzelmessungen wenige Abschnitte, je Abschnitt Tiefst- und Höchstwert.
///
/// Das ist eine Rechnung und gehört deshalb in den Kern, nicht in die
/// Shell (`CLAUDE.md`: „Eine Formel, deren Test in `app/test/` landet,
/// beweist die Importgrenze nicht mehr mit"). Diese Datei beschreibt die
/// Rechnung, nicht das Zeichnen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert** — die Entscheidung trifft Tim oder der Test-Agent.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/span_buckets.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart` — diese Datei importiert das Barrel, also ist
/// der Export Teil des Vertrags.
///
/// ```dart
/// /// Die Spanne über einem Abschnitt der Nacht. Werttyp.
/// final class ValueSpan {
///   /// Ein Abschnitt mit mindestens einer Messung.
///   const ValueSpan({
///     required this.start,
///     required this.end,
///     required double this.min,
///     required double this.max,
///   });
///
///   /// Ein Abschnitt ohne Messung. `min` und `max` sind `null` —
///   /// niemals `0`.
///   const ValueSpan.empty({required this.start, required this.end})
///       : min = null,
///         max = null;
///
///   /// Beginn des Abschnitts, einschließlich.
///   final DateTime start;
///
///   /// Ende des Abschnitts, ausschließlich — außer beim letzten, der
///   /// `to` einschließt.
///   final DateTime end;
///
///   /// Tiefster bzw. höchster Messwert des Abschnitts; `null`, wenn
///   /// keiner darin lag.
///   final double? min;
///   final double? max;
///
///   /// Wahr genau dann, wenn im Abschnitt keine Messung lag.
///   bool get isEmpty;
///
///   // `==` und `hashCode` über alle vier Felder.
/// }
///
/// abstract final class SpanBuckets {
///   /// Verdichtet Einzelmessungen auf `sectionCount` gleich lange
///   /// Abschnitte zwischen `from` und `to`.
///   static List<ValueSpan> spans({
///     required List<ChartSample> samples,
///     required DateTime from,
///     required DateTime to,
///     required int sectionCount,
///   });
/// }
/// ```
///
/// ## Sechs Entscheidungen dieses Test-Agenten, mit Begründung
///
/// Keine davon ist mit Tim abgestimmt. Sie stehen hier, damit der
/// Implementierende weiß, woran er sich hält — und damit sie jemand
/// findet, der sie umstoßen will.
///
/// ### 1 · Die Eingabe ist `ChartSample`, kein neuer Typ
///
/// `ChartSample` ist bereits „ein Messwert: Zeitpunkt und Zahl", liegt im
/// Barrel und ist ein Werttyp mit `==`. Ein zweiter Typ mit denselben zwei
/// Feldern wäre eine Kopie ohne Gewinn, und die Shell müsste zwischen
/// beiden umpacken.
///
/// ### 2 · Der Aufrufer bestimmt die **Zahl** der Abschnitte, nicht ihre Länge
///
/// Die Fläche, auf die gezeichnet wird, ist fest: `minMaxChart` teilt ihre
/// Breite durch `buckets.length`. Eine feste Abschnitts**länge** gäbe bei
/// fünf Stunden fünf breite und bei neun Stunden neun schmale Kapseln —
/// also genau die Schwankung, deren Extremfall das Ticket ist. Eine feste
/// **Zahl** hält die Kapselbreite konstant und lässt die Abschnittslänge
/// mit der Nacht wachsen.
///
/// Wer trotzdem ungefähr-Stundenabschnitte will, rechnet sich seine Zahl
/// aus der Nachtlänge aus (`(dauer.inMinutes / 60).round()`) — das ist eine
/// Entscheidung der Ansicht über ihre Lesbarkeit, keine Rechnung.
///
/// Darum gibt es **keine** zweite Fassung mit `Duration sectionLength`.
/// Zwei Wege zum selben Ergebnis sind zwei Wege, die auseinanderlaufen
/// können.
///
/// ### 3 · Ein leerer Abschnitt bleibt stehen und ist ausdrücklich leer …
///
/// Nicht „er fehlt". Die Ansicht zeichnet ein Raster mit fester
/// Abschnittszahl und beschriftet jeden zweiten Abschnitt mit seiner
/// Uhrzeit (`minMaxChart`, `i % 2`). Fiele ein Abschnitt ohne Messung aus
/// der Liste, verrutschte ab dort die ganze Achse und die Beschriftung
/// löge. Der Abschnitt steht deshalb an seinem Platz, trägt `start` und
/// `end` für die Beschriftung und hat `min == null` und `max == null`.
///
/// `null` und nicht `0`: Eine Kapsel bei 0 bpm wäre eine Behauptung über
/// den Nutzer, die niemand gemessen hat — dasselbe Muster wie `01`
/// („Schritte stehen auf 0, obwohl Daten da sind"). Eine Lücke bleibt eine
/// Lücke.
///
/// ### 4 · … aber eine Nacht ohne jede Messung gibt eine **leere Liste**
///
/// Liegt **kein einziger** Messwert im Fenster, ist das Ergebnis leer statt
/// `sectionCount` leerer Abschnitte. Sonst zeichnete die Ansicht ein
/// vollständiges, leeres Raster und behauptete damit, es gäbe eine Nacht
/// mit Daten, die zufällig alle fehlen. Eine leere Liste ist für die
/// Ansicht das Zeichen, `LeerNachLauf` zu zeigen und auf die
/// Health-Einstellungen zu verweisen.
///
/// Die Regel ist eine einzige, nicht zwei: **Kein Messwert im Fenster →
/// leere Liste.** „Leere Eingabe" ist davon nur der häufigste Fall.
///
/// ### 5 · Der letzte Abschnitt schließt `to` ein
///
/// Alle Abschnitte sind halboffen `[start, end)`, damit ein Messwert genau
/// auf einer Grenze nicht in zwei Abschnitten zählt. Der **letzte** ist
/// `[start, to]`: Die letzte Messung einer Nacht liegt typisch genau auf
/// dem Aufwachzeitpunkt, und sie wegfallen zu lassen nähme dem Diagramm
/// den Spitzenwert — also genau das, was das Ticket beklagt.
///
/// ### 6 · Hier steht keine Kalendergrenze — mit Absicht
///
/// `BerlinCalendar` taucht in der Rechnung nicht auf, und das ist kein
/// Verstoß gegen „jede Tagesgrenze über `BerlinCalendar`": Diese Rechnung
/// **braucht** keine Tagesgrenze. Sie teilt eine vom Aufrufer gegebene
/// Spanne in gleich lange Teile; die Teilung läuft über **verstrichene**
/// Zeit, nicht über die Wanduhr.
///
/// Das ist auch die inhaltlich richtige Antwort: In der Nacht zum
/// 25.10.2026 wird die Uhr zurückgestellt, die Nacht ist physisch eine
/// Stunde länger, und die Spannen sollen diese Stunde zeigen statt sie in
/// einen doppelt belegten „02:00"-Abschnitt zu falten. Wer hier auf
/// Wanduhrstunden zuschnitte, bekäme einen Abschnitt von zwei Stunden oder
/// zwei Abschnitte mit derselben Beschriftung.
///
/// Die Wanduhrzeit kommt genau einmal ins Spiel: wenn die Ansicht
/// `span.start` beschriftet, über `BerlinCalendar.wallClock`. Die Gruppe
/// „Die Zeitumstellung" unten prüft beides zusammen.
///
/// ## Was diese Tests nicht festlegen
///
/// Einen Zuschnitt feiner als eine Mikrosekunde (`sectionCount` größer als
/// die Länge des Fensters in Mikrosekunden). Dazu sagen sie nichts, weil es
/// keinen Abnehmer gibt — und eine ungeprüfte Zusicherung ist schlimmer als
/// gar keine.
void main() {
  // --------------------------------------------------------------------
  // Fixtures
  //
  // Alle Zahlen sind **erfunden** und bewusst so gewählt, dass keine als
  // Zeichenkette in einer anderen steckt — ein fehlgeschlagener Vergleich
  // soll eindeutig auf seinen Messwert zeigen.
  // --------------------------------------------------------------------

  /// Berliner Ortszeit als UTC-Zeitpunkt.
  ///
  /// **Gilt nur an Tagen ohne Umstellung.** „Stunden nach dem Berliner
  /// Tagesbeginn" ist an den beiden Umstellungstagen nicht die
  /// Wanduhrzeit; dort stehen die UTC-Zeitpunkte unten im Klartext da und
  /// werden mit `BerlinCalendar.wallClock` gegengeprüft.
  DateTime berlin(int jahr, int monat, int tag, int stunde, [int minute = 0]) =>
      BerlinCalendar.startOfDay(
        DateTime.utc(jahr, monat, tag),
      ).add(Duration(hours: stunde, minutes: minute));

  // Eine Nacht ohne Umstellung: 23:00 bis 07:00 Berliner Zeit, acht
  // verstrichene Stunden.
  final nachtVon = berlin(2026, 11, 2, 23);
  final nachtBis = berlin(2026, 11, 3, 7);

  /// Ein Messwert `minuten` nach Beginn der Nacht.
  ///
  /// `Duration` ist hier richtig und nicht verboten: Es wird **keine
  /// Kalendergrenze** gesucht, sondern verstrichene Zeit ab einem
  /// gegebenen Zeitpunkt abgetragen — dieselbe Größe, in der die Rechnung
  /// ihre Abschnitte bildet.
  ChartSample nachts(int minuten, double wert) =>
      ChartSample(date: nachtVon.add(Duration(minutes: minuten)), value: wert);

  /// Vierzehn Einzelmessungen über acht Stunden — die Lage, die der
  /// Entwurf auf acht Spannen verdichtet. Der vierte Abschnitt
  /// (02:00–03:00) bleibt **ohne** Messung; die letzte Messung liegt genau
  /// auf dem Aufwachzeitpunkt.
  List<ChartSample> nachtmessungen() => [
    nachts(5, 68), nachts(20, 73), nachts(55, 61), // 23:00–00:00
    nachts(61, 57), nachts(119, 66), //               00:00–01:00
    nachts(150, 49), //                               01:00–02:00
    //                                                02:00–03:00: nichts
    nachts(241, 54), nachts(270, 46), nachts(299, 59), // 03:00–04:00
    nachts(300, 83), nachts(359, 77), //               04:00–05:00
    nachts(400, 91), //                                05:00–06:00
    nachts(420, 42), nachts(480, 95), //               06:00–07:00
  ];

  List<ValueSpan> achtAbschnitte() => SpanBuckets.spans(
    samples: nachtmessungen(),
    from: nachtVon,
    to: nachtBis,
    sectionCount: 8,
  );

  List<DateTime> beginne(List<ValueSpan> spannen) => [
    for (final s in spannen) s.start,
  ];
  List<DateTime> enden(List<ValueSpan> spannen) => [
    for (final s in spannen) s.end,
  ];
  List<double?> tiefst(List<ValueSpan> spannen) => [
    for (final s in spannen) s.min,
  ];
  List<double?> hoechst(List<ValueSpan> spannen) => [
    for (final s in spannen) s.max,
  ];
  List<Duration> laengen(List<ValueSpan> spannen) => [
    for (final s in spannen) s.end.difference(s.start),
  ];

  group('Der Zuschnitt', () {
    test('vierzehn Einzelmessungen werden zu acht Spannen', () {
      expect(
        achtAbschnitte(),
        hasLength(8),
        reason:
            'Das ist der ganze Ticketinhalt: Der Entwurf zeigt acht '
            'Spannen, die gebaute Fassung zeichnete jede Messung einzeln',
      );
    });

    test('die erste Spanne beginnt bei `from`, die letzte endet bei `to`', () {
      final spannen = achtAbschnitte();
      expect(spannen.first.start, nachtVon);
      expect(
        spannen.last.end,
        nachtBis,
        reason:
            'Aufsummieren einer gerundeten Abschnittslänge verfehlt `to` — '
            'das Ende muss exakt stimmen',
      );
    });

    test('die Abschnitte stoßen lückenlos aneinander', () {
      final spannen = achtAbschnitte();
      for (var i = 1; i < spannen.length; i++) {
        expect(
          spannen[i].start,
          spannen[i - 1].end,
          reason: 'Abschnitt $i beginnt nicht, wo Abschnitt ${i - 1} endet',
        );
      }
    });

    test('acht Stunden auf acht Abschnitte sind acht Stunden-Abschnitte', () {
      expect(
        laengen(achtAbschnitte()),
        List.filled(8, const Duration(hours: 1)),
      );
    });

    test('die Beginne liegen auf den vollen Stunden der Nacht', () {
      expect(beginne(achtAbschnitte()), [
        for (var i = 0; i < 8; i++) nachtVon.add(Duration(hours: i)),
      ]);
      expect(enden(achtAbschnitte()), [
        for (var i = 1; i <= 8; i++) nachtVon.add(Duration(hours: i)),
      ]);
    });

    test('`sectionCount` bestimmt den Zuschnitt — dieselbe Nacht in vier', () {
      final spannen = SpanBuckets.spans(
        samples: nachtmessungen(),
        from: nachtVon,
        to: nachtBis,
        sectionCount: 4,
      );
      expect(spannen, hasLength(4));
      expect(laengen(spannen), List.filled(4, const Duration(hours: 2)));
      expect(
        tiefst(spannen),
        [57, 49, 46, 42],
        reason: 'Zwei Stundenabschnitte fallen zu einem zusammen',
      );
      expect(hoechst(spannen), [73, 49, 83, 95]);
    });

    test('eine fünfstündige Nacht bekommt ebenfalls acht Abschnitte', () {
      final von = berlin(2026, 11, 9, 1);
      final bis = berlin(2026, 11, 9, 6);
      final spannen = SpanBuckets.spans(
        samples: [ChartSample(date: von.add(const Duration(minutes: 7)), value: 64)],
        from: von,
        to: bis,
        sectionCount: 8,
      );
      expect(spannen, hasLength(8));
      expect(
        laengen(spannen),
        List.filled(8, const Duration(minutes: 37, seconds: 30)),
        reason: 'Fünf Stunden durch acht sind 37,5 Minuten — nicht gerundet',
      );
    });

    test('eine neunstündige Nacht bekommt ebenfalls acht Abschnitte', () {
      final von = berlin(2026, 11, 9, 21);
      final bis = berlin(2026, 11, 10, 6);
      final spannen = SpanBuckets.spans(
        samples: [ChartSample(date: von.add(const Duration(minutes: 7)), value: 64)],
        from: von,
        to: bis,
        sectionCount: 8,
      );
      expect(spannen, hasLength(8));
      expect(
        laengen(spannen),
        List.filled(8, const Duration(minutes: 67, seconds: 30)),
        reason:
            'Die Kapselbreite bleibt gleich, die Abschnittslänge wächst mit '
            'der Nacht — Entscheidung 2',
      );
    });
  });

  group('Spanne je Abschnitt', () {
    test('jeder Abschnitt trägt seinen tiefsten und seinen höchsten Wert', () {
      final spannen = achtAbschnitte();
      expect(tiefst(spannen), [61, 57, 49, null, 46, 77, 91, 42]);
      expect(hoechst(spannen), [73, 66, 49, null, 59, 83, 91, 95]);
    });

    test('eine einzige Messung im Abschnitt: Tiefst gleich Höchstwert', () {
      final spannen = achtAbschnitte();
      expect(spannen[2].min, 49);
      expect(spannen[2].max, 49);
      expect(spannen[6].min, 91);
      expect(spannen[6].max, 91);
      expect(
        spannen[2].isEmpty,
        isFalse,
        reason: 'Eine Messung ist eine Messung, auch wenn die Spanne null ist',
      );
    });

    test('lauter gleiche Werte ergeben eine Spanne ohne Breite', () {
      final spannen = SpanBuckets.spans(
        samples: [nachts(10, 86), nachts(30, 86), nachts(50, 86)],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(spannen.first.min, 86);
      expect(spannen.first.max, 86);
    });

    test('die Reihenfolge der Eingabe ändert nichts', () {
      final verdreht = nachtmessungen().reversed.toList();
      final spannen = SpanBuckets.spans(
        samples: verdreht,
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(tiefst(spannen), tiefst(achtAbschnitte()));
      expect(hoechst(spannen), hoechst(achtAbschnitte()));
    });

    test('die übergebene Liste wird nicht verändert', () {
      final eingabe = nachtmessungen().reversed.toList();
      final vorher = List<ChartSample>.of(eingabe);
      SpanBuckets.spans(
        samples: eingabe,
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(
        eingabe,
        vorher,
        reason:
            'Hält ein Provider die Reihe, wäre ein Sortieren an Ort und '
            'Stelle eine sichtbare Nebenwirkung',
      );
    });

    test('Messwerte vor `from` und nach `to` zählen nicht', () {
      final spannen = SpanBuckets.spans(
        samples: [
          ChartSample(date: nachtVon.subtract(const Duration(minutes: 1)), value: 38),
          ...nachtmessungen(),
          ChartSample(date: nachtBis.add(const Duration(minutes: 1)), value: 112),
        ],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(tiefst(spannen), [61, 57, 49, null, 46, 77, 91, 42]);
      expect(
        hoechst(spannen),
        [73, 66, 49, null, 59, 83, 91, 95],
        reason:
            'Ein Wert vom Vorabend oder aus dem Vormittag ist kein Schlafwert '
            'und darf die Spanne der Nacht nicht aufreißen',
      );
    });

    test('ein Wert genau auf einer Grenze gehört zum späteren Abschnitt', () {
      final spannen = SpanBuckets.spans(
        samples: [nachts(60, 44)],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(
        spannen[0].isEmpty,
        isTrue,
        reason: 'Die Abschnitte sind halboffen `[start, end)`',
      );
      expect(spannen[1].min, 44);
      expect(spannen[1].max, 44);
    });

    test('ein Wert genau auf `to` gehört in den letzten Abschnitt', () {
      final spannen = SpanBuckets.spans(
        samples: [ChartSample(date: nachtBis, value: 95)],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(
        spannen.last.max,
        95,
        reason:
            'Der letzte Abschnitt schließt `to` ein — die letzte Messung '
            'liegt typisch genau auf dem Aufwachzeitpunkt, und sie ist oft '
            'der Spitzenwert (Entscheidung 5)',
      );
      expect(spannen.last.min, 95);
    });

    test('ein Wert genau auf `from` gehört in den ersten Abschnitt', () {
      final spannen = SpanBuckets.spans(
        samples: [ChartSample(date: nachtVon, value: 68)],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(spannen.first.min, 68);
      expect(spannen.first.max, 68);
    });
  });

  group('Eine Lücke bleibt eine Lücke', () {
    test('der Abschnitt ohne Messung steht an seinem Platz', () {
      final spannen = achtAbschnitte();
      expect(spannen, hasLength(8));
      expect(spannen[3].start, nachtVon.add(const Duration(hours: 3)));
      expect(spannen[3].end, nachtVon.add(const Duration(hours: 4)));
      expect(
        spannen[3].isEmpty,
        isTrue,
        reason:
            'Fiele er aus der Liste, verrutschte ab dort die Achse und die '
            'Beschriftung jedes folgenden Abschnitts löge',
      );
    });

    test('ein leerer Abschnitt ist `null`, niemals `0`', () {
      final leer = achtAbschnitte()[3];
      expect(leer.min, isNull);
      expect(leer.max, isNull);
      expect(
        leer.min,
        isNot(0),
        reason:
            'Eine Kapsel bei 0 bpm behauptete eine Messung, die es nicht '
            'gibt — dasselbe Muster wie `01`',
      );
    });

    test('`isEmpty` ist genau bei den Abschnitten ohne Messung wahr', () {
      expect([for (final s in achtAbschnitte()) s.isEmpty], [
        false, false, false, true, false, false, false, false,
      ]);
    });

    test('eine leere Messreihe gibt eine leere Liste', () {
      expect(
        SpanBuckets.spans(
          samples: const [],
          from: nachtVon,
          to: nachtBis,
          sectionCount: 8,
        ),
        isEmpty,
        reason:
            'Kein Absturz und auch kein vollständiges leeres Raster — ein '
            'leeres Ergebnis ist das Zeichen für `LeerNachLauf`',
      );
    });

    test('liegen alle Messwerte außerhalb des Fensters, ist die Liste leer', () {
      expect(
        SpanBuckets.spans(
          samples: [
            ChartSample(date: nachtVon.subtract(const Duration(hours: 2)), value: 38),
            ChartSample(date: nachtBis.add(const Duration(hours: 2)), value: 112),
          ],
          from: nachtVon,
          to: nachtBis,
          sectionCount: 8,
        ),
        isEmpty,
        reason:
            'Die Regel ist eine einzige: kein Messwert im Fenster → leere '
            'Liste (Entscheidung 4)',
      );
    });

    test('eine einzige Messung hält alle acht Abschnitte am Leben', () {
      final spannen = SpanBuckets.spans(
        samples: [nachts(330, 53)],
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect(spannen, hasLength(8));
      expect([for (final s in spannen) s.isEmpty], [
        true, true, true, true, true, false, true, true,
      ]);
      expect(spannen[5].min, 53);
      expect(spannen[5].max, 53);
    });
  });

  group('Die Zeitumstellung', () {
    // Die Umstellungen des Jahres 2026 liegen am 29.03. und am 25.10.,
    // jeweils um 01:00 UTC. Die UTC-Zeitpunkte stehen hier im Klartext,
    // weil „Stunden nach dem Tagesbeginn" an diesen Tagen nicht die
    // Wanduhrzeit ist — und sie werden unten gegengeprüft, statt geglaubt.

    // Nacht zum 25.10.2026: Die Uhr geht von 03:00 MESZ auf 02:00 MEZ
    // zurück, die Nacht ist neun verstrichene Stunden lang.
    final herbstVon = DateTime.utc(2026, 10, 24, 21); // 23:00 MESZ
    final herbstBis = DateTime.utc(2026, 10, 25, 6); //  07:00 MEZ

    // Nacht zum 29.03.2026: Die Uhr springt von 02:00 MEZ auf 03:00 MESZ,
    // die Nacht ist sieben verstrichene Stunden lang.
    final fruehjahrVon = DateTime.utc(2026, 3, 28, 22); // 23:00 MEZ
    final fruehjahrBis = DateTime.utc(2026, 3, 29, 5); //  07:00 MESZ

    List<(int, int)> wanduhren(List<ValueSpan> spannen) => [
      for (final s in spannen) BerlinCalendar.wallClock(s.start),
    ];

    test('Vorprüfung: die vier Fixtures liegen, wo behauptet', () {
      expect(BerlinCalendar.wallClock(herbstVon), (23, 0));
      expect(BerlinCalendar.wallClock(herbstBis), (7, 0));
      expect(herbstBis.difference(herbstVon), const Duration(hours: 9));
      expect(BerlinCalendar.wallClock(fruehjahrVon), (23, 0));
      expect(BerlinCalendar.wallClock(fruehjahrBis), (7, 0));
      expect(fruehjahrBis.difference(fruehjahrVon), const Duration(hours: 7));
    });

    test('die längere Nacht bekommt neun gleich lange Stunden', () {
      final spannen = SpanBuckets.spans(
        samples: [
          for (var i = 0; i < 9; i++)
            ChartSample(
              date: herbstVon.add(Duration(minutes: 60 * i + 30)),
              value: [34, 76, 45, 62, 87, 29, 58, 93, 41][i].toDouble(),
            ),
        ],
        from: herbstVon,
        to: herbstBis,
        sectionCount: 9,
      );
      expect(spannen, hasLength(9));
      expect(laengen(spannen), List.filled(9, const Duration(hours: 1)));
      expect(
        wanduhren(spannen),
        [(23, 0), (0, 0), (1, 0), (2, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0)],
        reason:
            'Die Wanduhr zeigt 02:00 zweimal — die Stunde ist wirklich '
            'zweimal vergangen. Wer auf Wanduhrstunden zuschnitte, '
            'bekäme hier acht Abschnitte und einen doppelt belegten',
      );
      expect(tiefst(spannen), [34, 76, 45, 62, 87, 29, 58, 93, 41]);
    });

    test('die doppelte Stunde trennt in zwei Abschnitte', () {
      // 00:30 UTC ist noch MESZ, 01:30 UTC schon MEZ — beide zeigen 02:30
      // auf der Wanduhr und sind trotzdem eine Stunde auseinander.
      final frueh = DateTime.utc(2026, 10, 25, 0, 30);
      final spaet = DateTime.utc(2026, 10, 25, 1, 30);
      expect(BerlinCalendar.wallClock(frueh), (2, 30));
      expect(BerlinCalendar.wallClock(spaet), (2, 30));

      final spannen = SpanBuckets.spans(
        samples: [
          ChartSample(date: frueh, value: 62),
          ChartSample(date: spaet, value: 87),
        ],
        from: herbstVon,
        to: herbstBis,
        sectionCount: 9,
      );
      expect(spannen[3].max, 62);
      expect(spannen[4].max, 87);
      expect(
        spannen[3].max,
        isNot(spannen[4].max),
        reason:
            'Zwei Messungen derselben Wanduhrzeit gehören in verschiedene '
            'Abschnitte, sonst verschwindet eine Stunde Nacht',
      );
    });

    test('die kürzere Nacht bekommt sieben gleich lange Stunden', () {
      final spannen = SpanBuckets.spans(
        samples: [
          for (var i = 0; i < 7; i++)
            ChartSample(
              date: fruehjahrVon.add(Duration(minutes: 60 * i + 30)),
              value: [36, 82, 47, 69, 55, 28, 94][i].toDouble(),
            ),
        ],
        from: fruehjahrVon,
        to: fruehjahrBis,
        sectionCount: 7,
      );
      expect(spannen, hasLength(7));
      expect(laengen(spannen), List.filled(7, const Duration(hours: 1)));
      expect(
        wanduhren(spannen),
        [(23, 0), (0, 0), (1, 0), (3, 0), (4, 0), (5, 0), (6, 0)],
        reason: 'Die Wanduhr überspringt 02:00 — die Stunde gab es nicht',
      );
      expect(hoechst(spannen), [36, 82, 47, 69, 55, 28, 94]);
    });

    test('acht Abschnitte über die lange Nacht sind 67,5 Minuten lang', () {
      final spannen = SpanBuckets.spans(
        samples: [ChartSample(date: herbstVon.add(const Duration(minutes: 5)), value: 34)],
        from: herbstVon,
        to: herbstBis,
        sectionCount: 8,
      );
      expect(
        laengen(spannen),
        List.filled(8, const Duration(minutes: 67, seconds: 30)),
        reason:
            'Neun verstrichene Stunden durch acht — nicht acht Stunden plus '
            'ein Rest, und schon gar nicht acht Wanduhrstunden',
      );
      expect(spannen.last.end, herbstBis);
    });
  });

  group('Ungleiche Teilung', () {
    // Hundert Minuten auf sieben Abschnitte gehen nicht glatt auf. Was
    // dann gilt, steht hier als Eigenschaft und nicht als ausgerechnete
    // Mikrosekunde: Jede Verteilung, die die Enden trifft und sich um
    // höchstens eine Mikrosekunde unterscheidet, ist richtig.
    final von = berlin(2026, 11, 2, 23);
    final bis = von.add(const Duration(minutes: 100));

    List<ValueSpan> sieben() => SpanBuckets.spans(
      samples: [ChartSample(date: von.add(const Duration(minutes: 50)), value: 72)],
      from: von,
      to: bis,
      sectionCount: 7,
    );

    test('die Enden stimmen exakt', () {
      final spannen = sieben();
      expect(spannen, hasLength(7));
      expect(spannen.first.start, von);
      expect(
        spannen.last.end,
        bis,
        reason:
            'Sieben gerundete Längen aufzusummieren verfehlt `to` um bis zu '
            'sieben Mikrosekunden',
      );
    });

    test('die Abschnitte stoßen lückenlos aneinander', () {
      final spannen = sieben();
      for (var i = 1; i < spannen.length; i++) {
        expect(spannen[i].start, spannen[i - 1].end);
      }
    });

    test('die Längen unterscheiden sich um höchstens eine Mikrosekunde', () {
      final mikro = [for (final d in laengen(sieben())) d.inMicroseconds];
      final kuerzeste = mikro.reduce((a, b) => a < b ? a : b);
      final laengste = mikro.reduce((a, b) => a > b ? a : b);
      expect(laengste - kuerzeste, lessThanOrEqualTo(1));
      expect(
        mikro.reduce((a, b) => a + b),
        bis.difference(von).inMicroseconds,
        reason: 'Zusammen sind die Abschnitte genau das Fenster',
      );
    });
  });

  group('Unmögliche Zuschnitte werden gemeldet', () {
    // Ein falscher Zuschnitt ist ein Programmierfehler im Aufrufer, keine
    // Datenlage. Er wirft, statt still etwas Plausibles zurückzugeben —
    // sonst steht später ein leeres Diagramm da und niemand weiß, warum.

    test('`sectionCount` null ist ein Fehler', () {
      expect(
        () => SpanBuckets.spans(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtBis,
          sectionCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('ein negativer `sectionCount` ist ein Fehler', () {
      expect(
        () => SpanBuckets.spans(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtBis,
          sectionCount: -3,
        ),
        throwsArgumentError,
      );
    });

    test('ein Fenster ohne Länge ist ein Fehler', () {
      expect(
        () => SpanBuckets.spans(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
      );
    });

    test('ein rückwärts laufendes Fenster ist ein Fehler', () {
      expect(
        () => SpanBuckets.spans(
          samples: nachtmessungen(),
          from: nachtBis,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
      );
    });

    test('auch bei leerer Messreihe wird der Zuschnitt geprüft', () {
      expect(
        () => SpanBuckets.spans(
          samples: const [],
          from: nachtVon,
          to: nachtBis,
          sectionCount: 0,
        ),
        throwsArgumentError,
        reason:
            'Der Zuschnitt wird vor den Daten geprüft — sonst verdeckt eine '
            'leere Nacht den Programmierfehler bis zur ersten vollen',
      );
    });
  });

  group('ValueSpan ist ein Werttyp', () {
    // Aus demselben Grund wie `ChartPoint`: Die Reihe der Spannen ist die
    // Abhängigkeit, aus der die Ansicht ihr Diagramm ableitet. Ohne `==`
    // ist jede neu gebaute Liste ungleich der vorigen und alles
    // Abgeleitete läuft neu — das wäre `03`, wortgleich, im neuen Code.
    ValueSpan spanne(double min, double max) => ValueSpan(
      start: nachtVon,
      end: nachtVon.add(const Duration(hours: 1)),
      min: min,
      max: max,
    );

    ValueSpan leere() => ValueSpan.empty(
      start: nachtVon,
      end: nachtVon.add(const Duration(hours: 1)),
    );

    test('gleiche Felder sind gleich', () {
      final a = spanne(61, 73);
      final b = spanne(61, 73);
      expect(
        b,
        isNot(same(a)),
        reason:
            'Testvoraussetzung: wirklich zwei Objekte, sonst beweist der '
            'Vergleich nichts',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('jedes abweichende Feld macht ungleich', () {
      final a = spanne(61, 73);
      expect(a, isNot(spanne(57, 73)));
      expect(a, isNot(spanne(61, 66)));
      expect(
        a,
        isNot(
          ValueSpan(
            start: nachtVon.add(const Duration(hours: 1)),
            end: nachtVon.add(const Duration(hours: 2)),
            min: 61,
            max: 73,
          ),
        ),
      );
    });

    test('eine leere Spanne ist nicht gleich einer mit Werten', () {
      expect(leere(), isNot(spanne(61, 73)));
      expect(leere().isEmpty, isTrue);
      expect(spanne(61, 73).isEmpty, isFalse);
    });

    test('zwei leere Spannen über demselben Abschnitt sind gleich', () {
      final a = leere();
      final b = leere();
      expect(b, isNot(same(a)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('`hashCode` trennt die Varianten', () {
      final spannen = [
        spanne(61, 73),
        spanne(61, 73),
        spanne(57, 73),
        spanne(61, 66),
        leere(),
      ];
      expect(spannen[1], isNot(same(spannen[0])));
      expect(
        spannen.toSet(),
        hasLength(4),
        reason:
            'Ein `Set` geht über `hashCode` **und** `==`. Fehlt `hashCode`, '
            'bleiben fünf Einträge stehen',
      );
    });
  });

  // ======================================================================
  // `SpanBuckets.means` — Ticket #515
  //
  // Spec: `docs/superpowers/specs/2026-11-16-gym-puls-design.md`,
  // Abschnitt 18. Die Linie im Gym-Verlauf läuft über der Pulsfläche; die
  // Fläche ist `spans`, die Linie ist `means`. Liegen die beiden nicht auf
  // denselben Grenzen, liegt die Linie neben ihrer Fläche.
  //
  // Verbindlich vorgegeben:
  //
  // ```dart
  // static List<double?> means({
  //   required List<ChartSample> samples,
  //   required DateTime from,
  //   required DateTime to,
  //   required int sectionCount,
  // });
  // ```
  //
  // Alle erwarteten Mittel unten sind **von Hand ausgerechnet** und stehen
  // als Literal da (bei Brüchen als `closeTo` mit vier Stellen), nicht als
  // nachgebaute Formel.
  //
  // **Kein Messwert im Fenster → leere Liste**, genau wie bei `spans`
  // (Spec Abschnitt 18, Entscheidung des Koordinators vom 16.11.2026): Die
  // leere Liste ist für die Ansicht das Zeichen, den Leerzustand zu
  // zeigen, statt ein vollständiges leeres Raster zu zeichnen. Zwei
  // verschiedene Längen für denselben Fall wären eine Abweichung, die
  // später jemand für einen Fehler hält (Gruppe „Keine Stichprobe, kein
  // Mittel").
  // ======================================================================

  /// Kurzform, damit die Fälle lesbar bleiben.
  List<double?> mittel(
    List<ChartSample> samples, {
    DateTime? von,
    DateTime? bis,
    int abschnitte = 8,
  }) => SpanBuckets.means(
    samples: samples,
    from: von ?? nachtVon,
    to: bis ?? nachtBis,
    sectionCount: abschnitte,
  );

  group('means: Mittel je Abschnitt', () {
    test('die acht Stundenabschnitte der Nacht, von Hand gerechnet', () {
      // 23:00 (68+73+61)/3 · 00:00 (57+66)/2 · 01:00 49 · 02:00 nichts ·
      // 03:00 (54+46+59)/3 · 04:00 (83+77)/2 · 05:00 91 · 06:00 (42+95)/2.
      // Die 83 liegt genau auf der Grenze 04:00 (Minute 300), die 42 genau
      // auf 06:00 (Minute 420) — beide gehören in den Abschnitt, der dort
      // beginnt.
      final m = mittel(nachtmessungen());
      expect(m, hasLength(8));
      expect(m[0], closeTo(67.3333, 0.0001));
      expect(m[1], closeTo(61.5, 1e-9));
      expect(m[2], closeTo(49, 1e-9));
      expect(m[3], isNull);
      expect(m[4], closeTo(53, 1e-9));
      expect(m[5], closeTo(80, 1e-9));
      expect(m[6], closeTo(91, 1e-9));
      expect(m[7], closeTo(68.5, 1e-9));
    });

    test('gleiche Form wie `spans`: dieselbe Länge, Eintrag i ist Abschnitt i', () {
      final m = mittel(nachtmessungen());
      final s = achtAbschnitte();
      expect(m, hasLength(s.length));
      expect(m, hasLength(8));
      for (var i = 0; i < 8; i++) {
        expect(
          m[i] == null,
          s[i].isEmpty,
          reason: 'Abschnitt $i: Mittel und Spanne müssen gleichzeitig leer sein',
        );
      }
    });

    test('dieselbe Nacht in vier Abschnitten', () {
      // 0–2 h: (68+73+61+57+66)/5 = 65 · 2–4 h: nur die 49 · 4–6 h bleibt
      // nicht leer: (54+46+59+83+77)/5 = 63,8 · 6–8 h: (91+42+95)/3 = 76.
      // Achtung: 54, 46, 59 liegen bei Minute 241, 270, 299 — also im
      // dritten Viertel (240–360), nicht im zweiten.
      final m = mittel(nachtmessungen(), abschnitte: 4);
      expect(m, hasLength(4));
      expect(m[0], closeTo(65, 1e-9));
      expect(m[1], closeTo(49, 1e-9));
      expect(m[2], closeTo(63.8, 1e-9));
      expect(m[3], closeTo(76, 1e-9));
    });

    test('ein einziger Abschnitt: das Mittel aller vierzehn Werte', () {
      // 921 / 14 = 65,7857…; die Mitte zwischen 42 und 95 wäre 68,5.
      final m = mittel(nachtmessungen(), abschnitte: 1);
      expect(m, hasLength(1));
      expect(m.single, closeTo(65.7857, 0.0001));
    });

    test('eine einzige Messung im Abschnitt: Mittel gleich dieser Messung', () {
      final m = mittel(nachtmessungen());
      expect(m[2], 49);
      expect(m[6], 91);
    });

    test('eine einzige Messung hält alle Abschnitte am Leben, nur einer hat ein Mittel', () {
      final m = mittel([nachts(330, 53)]);
      expect(m, hasLength(8));
      expect(m, [null, null, null, null, null, 53, null, null]);
    });
  });

  group('means: das einfache Mittel, nicht etwas Ähnliches', () {
    // Ein Abschnitt, fünf Stichproben, davon vier dicht beieinander und
    // eine weit weg. Das einfache Mittel (40+41+42+43+100)/5 = 53,2.
    // Die Mitte zwischen min und max wäre 70, ein zeitgewichtetes Mittel
    // (die vier tiefen Werte liegen in den ersten vier Minuten, der hohe in
    // Minute 59) läge irgendwo dazwischen, aber nicht bei 53,2.
    final von = nachtVon;
    final bis = nachtVon.add(const Duration(hours: 1));
    final schief = [
      ChartSample(date: von.add(const Duration(minutes: 1)), value: 40),
      ChartSample(date: von.add(const Duration(minutes: 2)), value: 41),
      ChartSample(date: von.add(const Duration(minutes: 3)), value: 42),
      ChartSample(date: von.add(const Duration(minutes: 4)), value: 43),
      ChartSample(date: von.add(const Duration(minutes: 59)), value: 100),
    ];

    test('schiefe Verteilung: 53,2, nicht 70', () {
      final m = mittel(schief, von: von, bis: bis, abschnitte: 1);
      expect(m.single, closeTo(53.2, 1e-9));
      expect(m.single, isNot(closeTo(70, 1)));
    });

    test('der Abstand zwischen den Stichproben zählt nicht', () {
      // Dieselben fünf Werte, anders über die Stunde verteilt: dieselbe Zahl.
      final anders = [
        ChartSample(date: von.add(const Duration(minutes: 10)), value: 40),
        ChartSample(date: von.add(const Duration(minutes: 11)), value: 100),
        ChartSample(date: von.add(const Duration(minutes: 30)), value: 41),
        ChartSample(date: von.add(const Duration(minutes: 31)), value: 42),
        ChartSample(date: von.add(const Duration(minutes: 55)), value: 43),
      ];
      final m = mittel(anders, von: von, bis: bis, abschnitte: 1);
      expect(m.single, closeTo(53.2, 1e-9));
    });

    test('gleiche Werte, mehrfach: jede Stichprobe zählt einmal', () {
      // 60, 60, 60, 90 → 67,5 (nicht 75, wie das Mittel der Werte 60 und 90).
      final m = mittel(
        [
          ChartSample(date: von.add(const Duration(minutes: 5)), value: 60),
          ChartSample(date: von.add(const Duration(minutes: 6)), value: 60),
          ChartSample(date: von.add(const Duration(minutes: 7)), value: 60),
          ChartSample(date: von.add(const Duration(minutes: 8)), value: 90),
        ],
        von: von,
        bis: bis,
        abschnitte: 1,
      );
      expect(m.single, closeTo(67.5, 1e-9));
    });
  });

  group('means: dieselben Grenzen wie spans, mikrosekundengenau', () {
    // Hundert Minuten auf sieben Abschnitte gehen nicht glatt auf:
    // 6 000 000 000 µs / 7. Die Grenze i liegt bei `total * i ~/ 7`
    // (abgerundet) Mikrosekunden nach `from`; ausgerechnet:
    //   b1 = 857 142 857   b2 = 1 714 285 714   b3 = 2 571 428 571
    //   b4 = 3 428 571 428 b5 = 4 285 714 285   b6 = 5 142 857 142
    // Abschnitt k ist `[bk, b(k+1))`, der letzte schließt `to` ein.
    final von = berlin(2026, 11, 2, 23);
    final bis = von.add(const Duration(minutes: 100));
    const grenzMikro = [
      0,
      857142857,
      1714285714,
      2571428571,
      3428571428,
      4285714285,
      5142857142,
    ];
    DateTime grenze(int i) => von.add(Duration(microseconds: grenzMikro[i]));
    const mikro = Duration(microseconds: 1);

    test('Vorprüfung: die Literale sind total·i ~/ 7', () {
      const total = 6000000000;
      expect(bis.difference(von).inMicroseconds, total);
      for (var i = 0; i < 7; i++) {
        expect(grenzMikro[i], total * i ~/ 7, reason: 'Grenze $i');
      }
    });

    test('eine Mikrosekunde vor der Grenze: alter Abschnitt; auf der Grenze: neuer', () {
      // Abschnitt k bekommt zwei Stichproben: eine genau auf seinem Beginn
      // (Wert 10k+10) und eine eine Mikrosekunde vor seinem Ende
      // (Wert 10k+11). Mittel: 10k+10,5. Der letzte (k=6) bekommt statt der
      // zweiten eine genau auf `to` (71).
      // Wer die Grenze aufrundet statt abrundet, schiebt die Stichprobe
      // auf b2, b4, b5, b6 in den Vorgängerabschnitt.
      final samples = [
        for (var k = 0; k < 7; k++)
          ChartSample(date: grenze(k), value: 10.0 * k + 10),
        for (var k = 0; k < 6; k++)
          ChartSample(date: grenze(k + 1).subtract(mikro), value: 10.0 * k + 11),
        ChartSample(date: bis, value: 71),
      ];
      final m = mittel(samples, von: von, bis: bis, abschnitte: 7);
      expect(m, [10.5, 20.5, 30.5, 40.5, 50.5, 60.5, 70.5]);
    });

    test('eine Stichprobe genau auf jeder Grenze: Mittel gleich Spanne gleich Wert', () {
      // Genau eine Stichprobe je Abschnitt, jede auf dem Beginn. Dann sind
      // min, max und Mittel dieselbe Zahl — die Linie muss auf der Fläche
      // liegen, nicht daneben.
      final samples = [
        for (var k = 0; k < 7; k++)
          ChartSample(date: grenze(k), value: 50.0 + k),
      ];
      final s = SpanBuckets.spans(
        samples: samples,
        from: von,
        to: bis,
        sectionCount: 7,
      );
      final m = mittel(samples, von: von, bis: bis, abschnitte: 7);
      expect(m, [50, 51, 52, 53, 54, 55, 56]);
      for (var k = 0; k < 7; k++) {
        expect(s[k].min, 50.0 + k, reason: 'spans, Abschnitt $k');
        expect(m[k], s[k].min, reason: 'means, Abschnitt $k');
        expect(m[k], s[k].max, reason: 'means, Abschnitt $k');
      }
    });

    test('eine Stichprobe genau auf `from` gehört in den ersten Abschnitt', () {
      final m = mittel([ChartSample(date: von, value: 77)], von: von, bis: bis, abschnitte: 7);
      expect(m, [77, null, null, null, null, null, null]);
    });

    test('eine Stichprobe genau auf `to` gehört in den letzten Abschnitt', () {
      // Der letzte Abschnitt schließt `to` ein — sonst fehlte der
      // Spitzenwert beim Aufwachen.
      final m = mittel([ChartSample(date: bis, value: 88)], von: von, bis: bis, abschnitte: 7);
      expect(m, [null, null, null, null, null, null, 88]);
      final s = SpanBuckets.spans(
        samples: [ChartSample(date: bis, value: 88)],
        from: von,
        to: bis,
        sectionCount: 7,
      );
      expect(s.last.max, 88, reason: 'dieselbe Zuordnung wie bei spans');
    });

    test('eine Mikrosekunde vor einer Grenze und auf ihr trennen sich auch bei glatter Teilung', () {
      // Acht Stundenabschnitte: Grenze 04:00 = Minute 300 der Nacht.
      final davor = ChartSample(
        date: nachtVon.add(const Duration(minutes: 300)).subtract(mikro),
        value: 60,
      );
      final drauf = ChartSample(
        date: nachtVon.add(const Duration(minutes: 300)),
        value: 80,
      );
      final m = mittel([davor, drauf]);
      expect(m, [null, null, null, null, 60, 80, null, null]);
    });

    test('eine Mikrosekunde nach `to` zählt nicht mehr', () {
      final m = mittel([
        ChartSample(date: nachtBis.add(mikro), value: 150),
        ChartSample(date: nachtBis, value: 90),
      ]);
      expect(m.last, 90);
    });
  });

  group('means: Fenster', () {
    test('Stichproben außerhalb von [from, to] zählen nicht mit', () {
      final aussen = [
        ChartSample(date: nachtVon.subtract(const Duration(hours: 2)), value: 38),
        ChartSample(date: nachtVon.subtract(const Duration(microseconds: 1)), value: 39),
        ChartSample(date: nachtBis.add(const Duration(microseconds: 1)), value: 112),
        ChartSample(date: nachtBis.add(const Duration(hours: 2)), value: 113),
      ];
      final m = mittel([...nachtmessungen(), ...aussen]);
      expect(m, mittel(nachtmessungen()));
      expect(m[0], closeTo(67.3333, 0.0001));
      expect(m[7], closeTo(68.5, 1e-9));
    });

    test('`from` und `to` selbst zählen mit', () {
      final m = mittel(
        [
          ChartSample(date: nachtVon.subtract(const Duration(microseconds: 1)), value: 1000),
          ChartSample(date: nachtVon, value: 10),
          ChartSample(date: nachtBis, value: 20),
          ChartSample(date: nachtBis.add(const Duration(microseconds: 1)), value: 2000),
        ],
        abschnitte: 1,
      );
      expect(m, [15]);
    });
  });

  group('means: Keine Stichprobe, kein Mittel', () {
    test('der Abschnitt ohne Stichprobe ist `null`, niemals `0`', () {
      final m = mittel(nachtmessungen());
      expect(m[3], isNull);
      expect(
        m[3],
        isNot(0),
        reason: 'Eine Null hieße „Herz stand still" — niemand hat das gemessen',
      );
    });

    test('`null` genau dort, wo `spans` ein `ValueSpan.empty` liefert', () {
      final m = mittel(nachtmessungen());
      final s = achtAbschnitte();
      expect([for (final x in m) x == null], [for (final x in s) x.isEmpty]);
      expect([for (final x in m) x == null], [
        false, false, false, true, false, false, false, false,
      ]);
    });

    test('eine leere Messreihe gibt eine leere Liste, wie `spans`', () {
      expect(mittel(const []), isEmpty);
      expect(
        SpanBuckets.spans(
          samples: const [],
          from: nachtVon,
          to: nachtBis,
          sectionCount: 8,
        ),
        isEmpty,
        reason: 'Vorprüfung: so verhält sich `spans`',
      );
    });

    test('liegen alle Stichproben außerhalb des Fensters, ist die Liste leer', () {
      final aussen = [
        ChartSample(date: nachtVon.subtract(const Duration(hours: 2)), value: 38),
        ChartSample(date: nachtBis.add(const Duration(hours: 2)), value: 112),
      ];
      expect(mittel(aussen), isEmpty);
      expect(
        SpanBuckets.spans(
          samples: aussen,
          from: nachtVon,
          to: nachtBis,
          sectionCount: 8,
        ),
        isEmpty,
        reason: 'Vorprüfung: so verhält sich `spans`',
      );
    });

    test('Stichproben nur 1 µs außerhalb des Fensters: ebenfalls leer', () {
      expect(
        mittel([
          ChartSample(
            date: nachtVon.subtract(const Duration(microseconds: 1)),
            value: 60,
          ),
          ChartSample(
            date: nachtBis.add(const Duration(microseconds: 1)),
            value: 70,
          ),
        ]),
        isEmpty,
      );
    });
  });

  group('means: Zeitpunkte, nie `==` auf DateTime', () {
    // Der Kanal liefert Ortszeit, `recordedAt` und die Fenster sind UTC.
    // `toLocal()` ändert den Zeitpunkt nicht, wohl aber `isUtc` — und damit
    // `==`. Unabhängig davon, in welcher Zeitzone der Test läuft.
    DateTime ortszeit(DateTime utc) => utc.toLocal();

    test('Vorprüfung: derselbe Zeitpunkt, aber nicht `==`', () {
      final utc = nachtVon;
      final lokal = ortszeit(utc);
      expect(lokal.isUtc, isFalse);
      expect(utc.isUtc, isTrue);
      expect(lokal.isAtSameMomentAs(utc), isTrue);
      expect(lokal == utc, isFalse, reason: 'die Falle, um die es geht');
    });

    final erwartet = [
      closeTo(67.3333, 0.0001),
      closeTo(61.5, 1e-9),
      closeTo(49, 1e-9),
      isNull,
      closeTo(53, 1e-9),
      closeTo(80, 1e-9),
      closeTo(91, 1e-9),
      closeTo(68.5, 1e-9),
    ];

    test('Stichproben in Ortszeit, Fenster in UTC', () {
      final m = mittel([
        for (final s in nachtmessungen())
          ChartSample(date: ortszeit(s.date), value: s.value),
      ]);
      expect(m, orderedEquals(erwartet));
    });

    test('Stichproben in UTC, Fenster in Ortszeit', () {
      final m = mittel(
        nachtmessungen(),
        von: ortszeit(nachtVon),
        bis: ortszeit(nachtBis),
      );
      expect(m, orderedEquals(erwartet));
    });

    test('alles in Ortszeit', () {
      final m = mittel(
        [
          for (final s in nachtmessungen())
            ChartSample(date: ortszeit(s.date), value: s.value),
        ],
        von: ortszeit(nachtVon),
        bis: ortszeit(nachtBis),
      );
      expect(m, orderedEquals(erwartet));
    });

    test('Stichproben genau auf `from`, einer Grenze und `to`, gemischt UTC und Ortszeit', () {
      // Beginn der Abschnitte 0, 4 und das Ende: je einmal als UTC, einmal
      // als Ortszeit, gegen ein Fenster in der jeweils anderen Form.
      final samples = [
        ChartSample(date: ortszeit(nachtVon), value: 11),
        ChartSample(date: nachtVon.add(const Duration(hours: 4)), value: 44),
        ChartSample(date: ortszeit(nachtBis), value: 88),
      ];
      final erwartetM = [11, null, null, null, 44, null, null, 88];
      expect(mittel(samples), erwartetM);
      expect(mittel(samples, von: ortszeit(nachtVon), bis: nachtBis), erwartetM);
      expect(mittel(samples, von: nachtVon, bis: ortszeit(nachtBis)), erwartetM);
      final spans = SpanBuckets.spans(
        samples: samples,
        from: nachtVon,
        to: nachtBis,
        sectionCount: 8,
      );
      expect([for (final s in spans) s.isEmpty], [
        for (final x in erwartetM) x == null,
      ]);
    });

    test('ein Fenster, dessen Enden nur als Zeitpunkt gleich sind, hat keine Länge', () {
      expect(
        () => SpanBuckets.means(
          samples: nachtmessungen(),
          from: nachtVon,
          to: ortszeit(nachtVon),
          sectionCount: 8,
        ),
        throwsArgumentError,
        reason: 'Gleicher Zeitpunkt ist keine Länge, auch wenn `==` etwas anderes sagt',
      );
    });
  });

  group('means: die Zeitumstellung', () {
    // Nacht zum 25.10.2026, neun verstrichene Stunden (Fixtures wie oben,
    // hier im Klartext wiederholt, weil jede Gruppe für sich lesbar sein soll).
    final herbstVon = DateTime.utc(2026, 10, 24, 21); // 23:00 MESZ
    final herbstBis = DateTime.utc(2026, 10, 25, 6); //  07:00 MEZ

    test('02:30 gibt es zweimal — und die beiden landen in verschiedenen Abschnitten', () {
      // 00:30 UTC = 02:30 MESZ (3,5 h nach Beginn → Abschnitt 3),
      // 01:30 UTC = 02:30 MEZ  (4,5 h nach Beginn → Abschnitt 4).
      // Auf der Wanduhr wären es dieselben „02:30"; in verstrichener Zeit
      // nicht.
      final m = SpanBuckets.means(
        samples: [
          ChartSample(date: DateTime.utc(2026, 10, 25, 0, 30), value: 50),
          ChartSample(date: DateTime.utc(2026, 10, 25, 1, 30), value: 100),
        ],
        from: herbstVon,
        to: herbstBis,
        sectionCount: 9,
      );
      expect(m, [null, null, null, 50, 100, null, null, null, null]);
    });

    test('die Stichprobe genau in der Umstellungsminute fällt in den Abschnitt, der dort beginnt', () {
      // 01:00 UTC ist genau 4 h nach Beginn: Grenze zwischen Abschnitt 3
      // und 4. 00:59:59,999999 UTC ist noch Abschnitt 3.
      final m = SpanBuckets.means(
        samples: [
          ChartSample(
            date: DateTime.utc(2026, 10, 25, 0, 59, 59, 999, 999),
            value: 60,
          ),
          ChartSample(date: DateTime.utc(2026, 10, 25, 1), value: 90),
        ],
        from: herbstVon,
        to: herbstBis,
        sectionCount: 9,
      );
      expect(m, [null, null, null, 60, 90, null, null, null, null]);
    });
  });

  group('means: Fehler vor den Daten', () {
    test('`sectionCount` null ist ein Fehler', () {
      expect(
        () => SpanBuckets.means(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtBis,
          sectionCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('ein negativer `sectionCount` ist ein Fehler', () {
      expect(
        () => SpanBuckets.means(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtBis,
          sectionCount: -3,
        ),
        throwsArgumentError,
      );
    });

    test('ein Fenster ohne Länge ist ein Fehler', () {
      expect(
        () => SpanBuckets.means(
          samples: nachtmessungen(),
          from: nachtVon,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
      );
    });

    test('ein rückwärts laufendes Fenster ist ein Fehler', () {
      expect(
        () => SpanBuckets.means(
          samples: nachtmessungen(),
          from: nachtBis,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
      );
    });

    test('auch bei leerer Messreihe: `sectionCount` null wird gemeldet', () {
      expect(
        () => SpanBuckets.means(
          samples: const [],
          from: nachtVon,
          to: nachtBis,
          sectionCount: 0,
        ),
        throwsArgumentError,
        reason: 'Der Zuschnitt wird vor den Daten geprüft',
      );
    });

    test('auch bei leerer Messreihe: ein rückwärts laufendes Fenster wird gemeldet', () {
      expect(
        () => SpanBuckets.means(
          samples: const [],
          from: nachtBis,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
        reason: 'Eine leere Nacht darf den Programmierfehler nicht verdecken',
      );
    });

    test('auch bei Stichproben nur außerhalb des Fensters wird der Zuschnitt gemeldet', () {
      expect(
        () => SpanBuckets.means(
          samples: [
            ChartSample(date: nachtVon.subtract(const Duration(hours: 5)), value: 50),
          ],
          from: nachtVon,
          to: nachtVon,
          sectionCount: 8,
        ),
        throwsArgumentError,
      );
    });

    test('`spans` und `means` melden dieselben Fehler', () {
      for (final (von, bis, n) in [
        (nachtVon, nachtBis, 0),
        (nachtVon, nachtBis, -1),
        (nachtVon, nachtVon, 8),
        (nachtBis, nachtVon, 8),
      ]) {
        expect(
          () => SpanBuckets.spans(samples: const [], from: von, to: bis, sectionCount: n),
          throwsArgumentError,
          reason: 'Vorprüfung: spans wirft bei $n Abschnitten',
        );
        expect(
          () => SpanBuckets.means(samples: const [], from: von, to: bis, sectionCount: n),
          throwsArgumentError,
          reason: 'means wirft bei $n Abschnitten wie spans',
        );
      }
    });
  });

  group('means: die Eingabe', () {
    test('die übergebene Liste bleibt unverändert', () {
      final eingabe = nachtmessungen().reversed.toList();
      final kopie = List<ChartSample>.of(eingabe);
      mittel(eingabe);
      expect(eingabe, hasLength(kopie.length));
      for (var i = 0; i < kopie.length; i++) {
        expect(identical(eingabe[i], kopie[i]), isTrue, reason: 'Eintrag $i');
      }
    });

    test('eine unveränderliche Liste ist erlaubt', () {
      expect(
        () => mittel(List<ChartSample>.unmodifiable(nachtmessungen())),
        returnsNormally,
      );
    });

    test('die Reihenfolge der Eingabe ändert nichts', () {
      final erwartet = mittel(nachtmessungen());
      expect(mittel(nachtmessungen().reversed.toList()), erwartet);
      final gemischt = nachtmessungen()..shuffle(Random(515));
      expect(mittel(gemischt), erwartet);
      expect(erwartet[0], closeTo(67.3333, 0.0001), reason: 'Vorprüfung');
    });

    test('zwei Aufrufe mit denselben Daten geben dasselbe', () {
      expect(mittel(nachtmessungen()), mittel(nachtmessungen()));
    });
  });

  group('means: Eigenschaften über viele erzeugte Fälle', () {
    // Feste Saat, damit ein roter Lauf reproduzierbar ist. Werte sind
    // ganze Zahlen (als double), damit Summen exakt sind und „Mittel liegt
    // zwischen min und max" nicht an einem Rundungsrest scheitert.
    test('Mittel in [min, max], null genau bei leerem Abschnitt, Zuordnung wie spans', () {
      final rng = Random(515);
      for (var fall = 0; fall < 300; fall++) {
        final abschnitte = 1 + rng.nextInt(40);
        final von = DateTime.utc(
          2026,
          11,
          2,
          22,
        ).add(Duration(microseconds: rng.nextInt(1000000)));
        final bis = von.add(
          Duration(minutes: rng.nextInt(600), microseconds: 1 + rng.nextInt(1000000)),
        );

        // Referenzgrenzen: aus `spans` selbst, mit einer Sonde auf `from`.
        final sonde = SpanBuckets.spans(
          samples: [ChartSample(date: von, value: 1)],
          from: von,
          to: bis,
          sectionCount: abschnitte,
        );
        expect(sonde, hasLength(abschnitte), reason: 'Fall $fall: Vorprüfung');

        final samples = <ChartSample>[];
        final anzahl = rng.nextInt(60);
        for (var j = 0; j < anzahl; j++) {
          final art = rng.nextInt(5);
          DateTime wann;
          switch (art) {
            case 0: // genau auf einer Grenze (oder `to`)
              final k = rng.nextInt(abschnitte + 1);
              wann = k == abschnitte ? bis : sonde[k].start;
            case 1: // eine Mikrosekunde daneben
              final k = rng.nextInt(abschnitte + 1);
              final grenze = k == abschnitte ? bis : sonde[k].start;
              wann = rng.nextBool()
                  ? grenze.add(const Duration(microseconds: 1))
                  : grenze.subtract(const Duration(microseconds: 1));
            case 2: // außerhalb
              wann = rng.nextBool()
                  ? von.subtract(Duration(microseconds: 1 + rng.nextInt(1000000)))
                  : bis.add(Duration(microseconds: 1 + rng.nextInt(1000000)));
            default: // irgendwo im Fenster
              wann = von.add(
                Duration(
                  microseconds: (bis.difference(von).inMicroseconds * rng.nextDouble())
                      .floor(),
                ),
              );
          }
          if (rng.nextBool()) wann = wann.toLocal();
          samples.add(
            ChartSample(date: wann, value: (40 + rng.nextInt(141)).toDouble()),
          );
        }

        final spans = SpanBuckets.spans(
          samples: samples,
          from: von,
          to: bis,
          sectionCount: abschnitte,
        );
        final m = SpanBuckets.means(
          samples: samples,
          from: von,
          to: bis,
          sectionCount: abschnitte,
        );

        if (spans.isEmpty) {
          expect(m, isEmpty, reason: 'Fall $fall: keine Stichprobe im Fenster');
          continue;
        }
        expect(m, hasLength(spans.length), reason: 'Fall $fall: Länge');
        for (var i = 0; i < spans.length; i++) {
          final s = spans[i];
          final letzter = i == spans.length - 1;
          // Erwartung aus den Grenzen von `spans`, mit der einfachsten
          // Zuordnung, die es gibt: halboffen, der letzte schließt `to` ein.
          final dazu = [
            for (final p in samples)
              if (!p.date.isBefore(s.start) &&
                  (p.date.isBefore(s.end) || (letzter && !p.date.isAfter(s.end))))
                p.value,
          ];
          final grund = 'Fall $fall, Abschnitt $i von ${spans.length}';
          expect(m[i] == null, s.isEmpty, reason: '$grund: null genau bei leer');
          expect(dazu.isEmpty, s.isEmpty, reason: '$grund: Vorprüfung der Zuordnung');
          if (s.isEmpty) continue;
          final mw = m[i]!;
          expect(mw, greaterThanOrEqualTo(s.min!), reason: '$grund: Mittel unter min');
          expect(mw, lessThanOrEqualTo(s.max!), reason: '$grund: Mittel über max');
          final summe = dazu.fold<double>(0, (a, b) => a + b);
          expect(
            mw,
            closeTo(summe / dazu.length, 1e-9),
            reason: '$grund: Mittel der Stichproben, die `spans` diesem Abschnitt zuordnet',
          );
        }
      }
    });
  });
}
