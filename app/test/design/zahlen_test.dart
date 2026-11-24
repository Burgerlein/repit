import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/zahlen.dart';

/// Tests für `formatNumber` (`lib/design/zahlen.dart`) — deutsche
/// Zahlenschreibweise ohne `intl`-Zahlensymbole: Komma als Dezimaltrenner,
/// Punkt als Tausendertrennzeichen.
///
/// Die Funktion war bis #137 privat in `heute_view.dart` und ist jetzt
/// öffentlich. Der Schritt nach draußen ist der Moment für einen Test: Ab
/// jetzt ruft sie nicht mehr nur der eine Schirm, der sie mitgebracht hat,
/// sondern jeder, der eine Zahl anzeigt.
///
/// **Dieser Test ist von Anfang an grün.** `CLAUDE.md` lässt das
/// ausdrücklich zu („Ein Wächtertest ist von Anfang an grün"): Er prüft
/// eine Behauptung über bestehendes Verhalten, nicht ein noch zu bauendes.
/// Was er festhält, ist die Schreibweise selbst — niemand soll sie später
/// beiläufig ändern, wenn eine zweite Ansicht andere Erwartungen mitbringt.
///
/// Alle Zahlen erfunden und ohne Bezug zu Tims Werten (`CLAUDE.md`).
void main() {
  group('ganze Zahlen', () {
    test('unter tausend bleibt ohne Trennzeichen', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(7), '7');
      expect(formatNumber(842), '842');
    });

    test('genau tausend bekommt den Punkt — die Grenze, an der eine '
        'Gruppierung um eins danebenliegen kann', () {
      expect(formatNumber(999), '999');
      expect(formatNumber(1000), '1.000');
      expect(formatNumber(1001), '1.001');
    });

    test('vier-, fünf- und sechsstellig wird von rechts gruppiert', () {
      expect(formatNumber(4128), '4.128');
      expect(formatNumber(52170), '52.170');
      expect(formatNumber(431902), '431.902');
    });

    test('siebenstellig bekommt zwei Trennzeichen', () {
      expect(formatNumber(3254100), '3.254.100');
    });
  });

  group('Nachkommastellen', () {
    test('eine Nachkommastelle wird mit Komma geschrieben, nicht mit Punkt', () {
      expect(formatNumber(57.2, nachkommastellen: 1), '57,2');
    });

    test('Komma und Tausenderpunkt treffen in derselben Zahl aufeinander', () {
      expect(formatNumber(4128.5, nachkommastellen: 1), '4.128,5');
    });

    test('mehr Nachkommastellen als die Zahl hat, werden aufgefüllt', () {
      expect(formatNumber(3, nachkommastellen: 2), '3,00');
    });

    test('nachkommastellen: 0 auf einem Wert mit Nachkomma rundet, statt '
        'abzuschneiden — und hängt kein leeres Komma an', () {
      expect(formatNumber(57.2), '57');
      expect(formatNumber(57.8), '58');
    });

    test('gerundet wird auch über eine Tausendergrenze hinweg richtig '
        'gruppiert', () {
      expect(formatNumber(999.6), '1.000');
    });
  });

  group('Vorzeichen', () {
    test('das Minus steht vor der ersten Ziffer, nicht vor dem Punkt', () {
      expect(formatNumber(-5), '-5');
      expect(formatNumber(-4128), '-4.128');
      expect(formatNumber(-431902), '-431.902');
    });

    test('negativ mit Nachkommastelle', () {
      expect(formatNumber(-0.4, nachkommastellen: 1), '-0,4');
      expect(formatNumber(-1234.5, nachkommastellen: 1), '-1.234,5');
    });

  });

  // Nicht geprüft, weil heute niemand so aufruft und ein Test die
  // Entscheidung vorwegnähme: `formatNumber(-0.2)` ergibt „-0". Ein
  // gerundetes Nichts mit Vorzeichen liest sich wie ein Messfehler — wenn
  // einmal eine Ansicht kleine negative Werte ohne Nachkommastelle zeigt
  // (ein Gewichtstrend etwa), gehört das entschieden und dann hierher.
}
