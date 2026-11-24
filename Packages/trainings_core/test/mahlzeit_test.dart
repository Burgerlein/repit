import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/mahlzeit.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, Abschnitt
/// „Welche Mahlzeit — und auf welchem Tag".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// enum Mahlzeit { fruehstueck, mittag, snack, abend }
///
/// abstract final class Mahlzeitfenster {
///   /// Zu welcher Mahlzeit eine Uhrzeit gehört, gegeben als Minuten seit
///   /// Mitternacht der Berliner Wanduhr (0 … 1439).
///   static Mahlzeit fuer(int minutenSeitMitternacht);
///
///   /// Die Vorgabe-Uhrzeit einer Mahlzeit, als Minuten seit Mitternacht.
///   static int mitteInMinuten(Mahlzeit mahlzeit);
/// }
/// ```
///
/// ## Die Grenzen
///
/// | Mahlzeit | Von | Bis |
/// |---|---|---|
/// | Frühstück | 04:00 | 10:59 |
/// | Mittagessen | 11:00 | 14:59 |
/// | Snack | 15:00 | 17:59 |
/// | Abendessen | 18:00 | **03:59** |
///
/// **Der Abend umschließt Mitternacht.** Ein Eintrag um 01:30 gehört zum
/// Abend **davor** — und damit auf den Tag davor. Eine erste Fassung des
/// Entwurfs hatte vier Fenster ohne Umschlag; dort wäre 01:30 ein Snack
/// geworden, auf dem falschen Tag.
///
/// **Achtung, widersprüchliche Quelle:** „Review Focus 1" desselben Plans
/// sagt für 00:30 noch `snack` („fällt in keinen der drei Zeiträume"). Das
/// ist ein stehengebliebener Satz aus dem abgelösten Entwurf mit drei
/// Fenstern. Maßgeblich ist die Tabelle oben und Step 1 des Plans
/// (`fuer(90) == Mahlzeit.abend`); 00:30 ist damit **Abend**, nicht Snack.
///
/// **Jede Grenze gehört dem späteren Fenster.** 10:59 ist noch Frühstück,
/// 11:00 schon Mittag — die Minute, die die Grenze nennt, beginnt das neue
/// Fenster.
///
/// ## Die Vorgabe-Uhrzeiten
///
/// Aus demselben Abschnitt des Entwurfs: „die Uhrzeit ist nicht ‚jetzt‘,
/// sondern die Mitte der erkannten Mahlzeit (Frühstück 08:00, Mittag 12:30,
/// Abend 19:00, Snack 15:30)". Sie ist eine reine Rechnung auf dem
/// Mahlzeitfenster und gehört damit in den Kern — Task 7 des Plans führt sie
/// unter „Consumes" als `mahlzeitZurUhrzeit` aus Task 2, die
/// Interface-Liste von Task 2 nennt sie nicht. Vier Uhrzeiten, die sonst in
/// einer View stünden, wären vier hartcodierte Zahlen außerhalb jeder
/// Prüfung.
void main() {
  /// Die Tabelle des Entwurfs, noch einmal unabhängig von der
  /// Implementierung hingeschrieben. Dass sie hier als Kette von Vergleichen
  /// steht und drüben womöglich als Rechnung, ist Absicht: Zwei Wege zum
  /// selben Ergebnis fangen den Zahlendreher, den ein Weg allein durchlässt.
  Mahlzeit ausDerTabelle(int minuten) {
    if (minuten >= 240 && minuten <= 659) return Mahlzeit.fruehstueck;
    if (minuten >= 660 && minuten <= 899) return Mahlzeit.mittag;
    if (minuten >= 900 && minuten <= 1079) return Mahlzeit.snack;
    return Mahlzeit.abend; // 1080 … 1439 und 0 … 239
  }

  group('Mahlzeit', () {
    test('die vier Fälle stehen in der Reihenfolge des Tag-Schirms', () {
      expect(Mahlzeit.values, [
        Mahlzeit.fruehstueck,
        Mahlzeit.mittag,
        Mahlzeit.snack,
        Mahlzeit.abend,
      ]);
    });
  });

  group('Mahlzeitfenster.fuer', () {
    test('01:30 gehört zum Abend davor, nicht zum Frühstück danach', () {
      expect(Mahlzeitfenster.fuer(90), Mahlzeit.abend);
    });

    test('00:30 gehört ebenfalls zum Abend', () {
      // Review Focus 1 des Plans nennt genau diesen Eintrag; die Tabelle des
      // Entwurfs macht daraus Abend, nicht Snack. Siehe Kopf dieser Datei.
      expect(Mahlzeitfenster.fuer(30), Mahlzeit.abend);
    });

    test('Mitternacht und die letzte Minute des Tages werfen nicht', () {
      expect(Mahlzeitfenster.fuer(0), Mahlzeit.abend);
      expect(Mahlzeitfenster.fuer(1439), Mahlzeit.abend);
    });

    test('jede Grenze gehört dem späteren Fenster', () {
      expect(Mahlzeitfenster.fuer(239), Mahlzeit.abend, reason: '03:59');
      expect(Mahlzeitfenster.fuer(240), Mahlzeit.fruehstueck, reason: '04:00');

      expect(Mahlzeitfenster.fuer(659), Mahlzeit.fruehstueck, reason: '10:59');
      expect(Mahlzeitfenster.fuer(660), Mahlzeit.mittag, reason: '11:00');

      expect(Mahlzeitfenster.fuer(899), Mahlzeit.mittag, reason: '14:59');
      expect(Mahlzeitfenster.fuer(900), Mahlzeit.snack, reason: '15:00');

      expect(Mahlzeitfenster.fuer(1079), Mahlzeit.snack, reason: '17:59');
      expect(Mahlzeitfenster.fuer(1080), Mahlzeit.abend, reason: '18:00');
    });

    test('ein paar Uhrzeiten aus der Mitte der Fenster', () {
      expect(Mahlzeitfenster.fuer(480), Mahlzeit.fruehstueck, reason: '08:00');
      expect(Mahlzeitfenster.fuer(750), Mahlzeit.mittag, reason: '12:30');
      expect(Mahlzeitfenster.fuer(930), Mahlzeit.snack, reason: '15:30');
      expect(Mahlzeitfenster.fuer(1140), Mahlzeit.abend, reason: '19:00');
    });

    test('jede Minute des Tages trifft die Tabelle', () {
      for (var minute = 0; minute < 1440; minute++) {
        expect(
          Mahlzeitfenster.fuer(minute),
          ausDerTabelle(minute),
          reason: 'Minute $minute',
        );
      }
    });

    test('der Abend ist das einzige Fenster, das Mitternacht umschließt', () {
      // 1080 … 1439 und 0 … 239 — zusammen 600 Minuten, und kein anderes
      // Fenster liegt beiderseits der Grenze.
      final abendMinuten = [
        for (var m = 0; m < 1440; m++)
          if (Mahlzeitfenster.fuer(m) == Mahlzeit.abend) m,
      ];

      expect(abendMinuten.length, 600);
      expect(abendMinuten.first, 0);
      expect(abendMinuten.last, 1439);
    });
  });

  group('Mahlzeitfenster.mitteInMinuten', () {
    test('die vier Vorgabe-Uhrzeiten aus dem Entwurf', () {
      expect(Mahlzeitfenster.mitteInMinuten(Mahlzeit.fruehstueck), 480);
      expect(Mahlzeitfenster.mitteInMinuten(Mahlzeit.mittag), 750);
      expect(Mahlzeitfenster.mitteInMinuten(Mahlzeit.snack), 930);
      expect(Mahlzeitfenster.mitteInMinuten(Mahlzeit.abend), 1140);
    });

    test('die Vorgabe-Uhrzeit liegt in ihrem eigenen Fenster', () {
      // Sonst bucht der Schirm einen Eintrag, dessen Uhrzeit auf eine andere
      // Mahlzeit zeigt als die, unter der er steht.
      for (final mahlzeit in Mahlzeit.values) {
        final mitte = Mahlzeitfenster.mitteInMinuten(mahlzeit);

        expect(mitte, inInclusiveRange(0, 1439), reason: '$mahlzeit');
        expect(Mahlzeitfenster.fuer(mitte), mahlzeit, reason: '$mahlzeit');
      }
    });
  });
}
