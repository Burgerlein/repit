import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/zeitdiagramm_fenster.dart';
import 'package:repit/design/zeitdiagramm_zeichnung.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

/// Tests für #162 — die Beschriftung einer Ziellinie wird abgeschnitten.
///
/// ## Der Fehler
///
/// `zeitdiagramm_zeichnung.dart` setzt die Beschriftung einer Ziellinie
/// zwölf Punkt über die Linie. `Fensterstand.grenzen(…)` nimmt eine
/// Ziellinie als Ober- bzw. Untergrenze der y-Achse. **Liegt das Ziel über
/// allen Messwerten**, liegt die Linie damit genau auf der obersten
/// Rasterlinie, ihre Beschriftung bei y = −4, und das `clipRect` des Malers
/// schneidet sie weg.
///
/// Das ist kein Randfall, sondern der Normalfall eines **nicht erreichten**
/// Ziels: Das Schlafziel von 8:00 h liegt über jeder Nacht einer schwachen
/// Woche (#152), und bei Belastung gilt dasselbe, sobald das Tagesziel über
/// allen Balken liegt.
///
/// ## Zwei Hälften, zwei Gruppen
///
/// 1. **Luft** über einer Ziellinie, die über allen Messwerten liegt (und
///    unter einer, die darunter liegt). Das löst zugleich, dass die Linie
///    sonst mit der obersten Rasterlinie zusammenfällt.
/// 2. **Platzwechsel der Beschriftung**: Reicht der Platz über der Linie
///    trotzdem nicht, fällt sie darunter. Luft allein trägt das nicht — ein
///    Ziel dicht **unter** dem höchsten Messwert bestimmt die Achse nicht
///    und bekommt deshalb auch keine Luft, steht aber genauso weit oben.
///
/// ## Entscheidungen dieser Datei — vom Agenten von #162, nicht von Tim
///
/// 1. **Geprüft wird ein Anteil, keine Zahl.** Die Behauptung lautet „über
///    der Ziellinie bleibt genug Platz für ihre Beschriftung", und „genug"
///    ist ein Anteil der Achsenspanne, weil daraus die Punkte im Bild
///    folgen: Die Zeichenfläche ist 120 Punkt hoch (Bildhöhe 148 aus
///    `components.css`, minus 8 Punkt Luft oben und 20 für die Achse). Eine
///    Beschriftung in 9 Punkt beginnt zwölf Punkt über ihrer Linie, also
///    braucht sie **ein Zehntel der Achse**, um unter der obersten
///    Rasterlinie zu bleiben. Festgenagelt wird dieses Zehntel, nicht der
///    Wert, den die Umsetzung wählt — ein Test, der 0,15 festschreibt,
///    prüfte die Umsetzung statt die Anforderung. Nach oben bleibt ein
///    Viertel der Achse die Grenze: Mehr Luft drückte die Messwerte
///    zusammen, und die will man sehen.
///
/// 2. **Die Luft hängt an der Achsenspanne, nicht an der Messspanne.** Das
///    Entwurfsboard rechnet `rand = 0,18 · Messspanne`
///    (`lineChart` in `docs/screens/components.js`, gemessen: bei 0,12 schob
///    sich der Hof der Beschriftung noch über die oberste Rasterlinie), und
///    `spannenAchsenGrenzen` in `lib/shell/schlaf_spannen_achse.dart` macht
///    es mit 0,14 genauso. Beide halten das Versprechen aber nur, solange
///    die Linie **dicht** über den Messwerten liegt: Bei sieben Balken à 41
///    und einem Wochenziel von 250 sind 0,18 · 41 = 7,4 von 257 — drei
///    Punkte im Bild, und die Beschriftung ist wieder weg. Der Fall „das
///    Ziel liegt weit über den Werten" steht deshalb als eigener Fall da.
///    **Auf dem Beispiel, an dem das Board gemessen hat, fallen beide
///    Rechnungen praktisch zusammen** (Obergrenze 8,41 statt 8,31) — sie
///    gehen erst dort auseinander, wo die Board-Rechnung still versagt.
///    Dass das Board damit von der App abweicht, ist gemeldet und nicht
///    hier entschieden.
///
/// 3. **Die Beschriftungsart bleibt, wie sie ist.** Das Board schreibt den
///    Namen mit dem Wert links auf die Linie, die App nur den Namen
///    rechtsbündig darüber. Welche von beiden weicht, entscheidet Tim; hier
///    wird nur geprüft, dass die Beschriftung **im Bild** steht und nicht
///    auf ihrer eigenen Linie liegt.
///
/// 4. **Keine echten Gesundheitsdaten.** Alle Zahlen sind erfunden.
void main() {
  // ───────────────────────────────────────────────────────────────────────
  // Hülle — wie in `zeitdiagramm_fenster_test.dart`: weitergezählt wird mit
  // `BerlinCalendar.addDays`, nie über `montag.day + i`.
  // ───────────────────────────────────────────────────────────────────────

  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Eine volle Kalenderwoche ab dem 26.10.2026 mit den übergebenen Werten.
  Fensterstand stand(List<double> werte) => Fensterstand.aus(
    reihe: [
      for (var i = 0; i < werte.length; i++)
        (tag: BerlinCalendar.addDays(tag(2026, 10, 26), i), wert: werte[i]),
    ],
    stufe: DiagrammStufe.woche,
    verschiebung: 0,
  );

  /// Der Anteil der Achsenspanne, der **über** `ziel` frei bleibt.
  double luftUeber(
    Fensterstand s,
    double ziel, {
    required bool alsBalken,
    List<double> linien = const [],
  }) {
    final (unten, oben) = s.grenzen(
      linien: linien.isEmpty ? [ziel] : linien,
      alsBalken: alsBalken,
    );
    return (oben - ziel) / (oben - unten);
  }

  /// Der Anteil der Achsenspanne, der **unter** `ziel` frei bleibt.
  double luftUnter(
    Fensterstand s,
    double ziel, {
    required bool alsBalken,
    List<double> linien = const [],
  }) {
    final (unten, oben) = s.grenzen(
      linien: linien.isEmpty ? [ziel] : linien,
      alsBalken: alsBalken,
    );
    return (ziel - unten) / (oben - unten);
  }

  /// Ein Zehntel der Achse — zwölf von 120 Punkten, der Abstand, den die
  /// Beschriftung über ihrer Linie braucht.
  const noetig = 0.1;

  /// Ein Viertel der Achse: Mehr Luft staucht die Messwerte.
  const hoechstens = 0.25;

  // ═══════════════════════════════════════════════════════════════════════
  // 1 · Luft um eine Ziellinie außerhalb der Messwerte
  // ═══════════════════════════════════════════════════════════════════════

  group('Eine Ziellinie außerhalb der Messwerte bekommt Luft', () {
    test('ein Ziel über allen Werten klebt nicht am oberen Rand', () {
      // Sieben Nächte unter acht Stunden — der Fall aus #152.
      final s = stand(const [6.0, 7.1, 6.6, 5.7, 6.9, 7.4, 7.0]);

      final luft = luftUeber(s, 8, alsBalken: false);
      expect(
        luft,
        greaterThanOrEqualTo(noetig),
        reason:
            'Ohne Luft liegt die Ziellinie auf der obersten Rasterlinie, '
            'ihre Beschriftung bei y = −4 und das `clipRect` schneidet sie '
            'weg (#162). Ein Zehntel der Achse sind zwölf Punkt — genau der '
            'Abstand, den die Beschriftung über ihrer Linie braucht',
      );
      expect(
        luft,
        lessThanOrEqualTo(hoechstens),
        reason:
            'Luft ist kein Selbstzweck: Je mehr davon, desto flacher liegen '
            'die Nächte untereinander, und die will man vergleichen',
      );
    });

    test('wie weit das Ziel über den Werten liegt, ändert die Luft nicht', () {
      // Der Fall, an dem eine Luft aus der **Messspanne** auffliegt: Sie
      // schrumpft, je weiter die Ziellinie von den Werten wegrückt. Bei
      // einem Wochenziel über einer schwachen Woche ist sie dann wieder
      // weg, und genau das ist der gemeldete Fehler.
      final s = stand(const [41, 41, 41, 41, 41, 41, 41]);

      expect(
        luftUeber(s, 250, alsBalken: true),
        greaterThanOrEqualTo(noetig),
        reason:
            'Auch ein Ziel weit über den Balken braucht den Platz für seine '
            'Beschriftung — 0,18 · Messspanne wären hier 7,4 von 257, also '
            'drei Punkte im Bild',
      );
      expect(
        luftUeber(s, 250, alsBalken: true),
        closeTo(luftUeber(s, 60, alsBalken: true), 1e-9),
        reason:
            'Der Platz über der Linie ist eine Eigenschaft des Bildes, nicht '
            'der Daten. Er darf nicht davon abhängen, wie weit das Ziel über '
            'den Werten liegt',
      );
    });

    test('ein Ziel zwischen den Messwerten rückt die Achse nicht', () {
      final s = stand(const [12, 48, 0, 35, 61, 7, 22]);

      expect(
        s.grenzen(linien: const [30], alsBalken: true),
        (0.0, 61.0),
        reason:
            'Die Luft gilt der Beschriftung einer Linie am Rand. Liegt das '
            'Tagesziel zwischen den Balken, hat es Platz, und eine '
            'gestauchte Achse wäre nur ein verschenktes Bild',
      );
    });

    test('auch nach unten: ein Ziel unter allen Werten bekommt Luft', () {
      final s = stand(const [78, 78, 78, 78, 78, 78, 78]);

      expect(
        luftUnter(s, 60, alsBalken: false),
        greaterThanOrEqualTo(noetig),
        reason:
            'Unten fällt die Linie sonst mit der untersten Rasterlinie '
            'zusammen. Der Grund ist derselbe wie oben, also ist es auch '
            'dieselbe Luft',
      );
    });

    test('ein Ziel darüber und eines darunter bekommen beide Luft', () {
      final s = stand(const [78, 79, 80, 81, 80, 79, 78]);
      const linien = [60.0, 95.0];

      expect(
        luftUeber(s, 95, alsBalken: false, linien: linien),
        greaterThanOrEqualTo(noetig),
      );
      expect(
        luftUnter(s, 60, alsBalken: false, linien: linien),
        greaterThanOrEqualTo(noetig),
        reason:
            'Zwei Linien, zwei Beschriftungen, zweimal derselbe Platzbedarf. '
            'Die Luft der einen darf die der anderen nicht aufzehren',
      );
      final (unten, oben) = s.grenzen(linien: linien, alsBalken: false);
      expect(unten, lessThan(60.0), reason: 'Beide Linien bleiben im Bild');
      expect(oben, greaterThan(95.0));
    });

    test('bei Balken bleibt die Null der Boden, auch mit Luft', () {
      final s = stand(const [41, 41, 41, 41, 41, 41, 41]);

      final (unten, _) = s.grenzen(linien: const [250], alsBalken: true);
      expect(
        unten,
        0.0,
        reason:
            '„Balken wachsen aus der Null" (`lineChart` im Entwurfsboard). '
            'Die Luft gehört über die Ziellinie, nicht unter die Nulllinie — '
            'sonst schwebten die Balken',
      );
    });

    test('ohne einen einzigen Balken trägt die Ziellinie die Achse allein', () {
      const leer = Fensterstand.leer(DiagrammStufe.woche);

      final (unten, oben) = leer.grenzen(linien: const [120], alsBalken: true);
      expect(unten, 0.0);
      expect(
        (oben - 120) / (oben - unten),
        greaterThanOrEqualTo(noetig),
        reason:
            'Auch ohne Messwert steht die Linie im Bild und trägt ihre '
            'Beschriftung. Ganz oben am Rand wäre sie genauso abgeschnitten '
            'wie mit Balken darunter',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2 · Die Beschriftung weicht nach unten aus, wenn oben kein Platz ist
  //
  // Luft allein genügt nicht: Sie entsteht nur, wo eine Ziellinie das Ende
  // der Achse bestimmt. Ein Ziel dicht **unter** dem höchsten Messwert
  // bestimmt es nicht und steht trotzdem ganz oben.
  // ═══════════════════════════════════════════════════════════════════════

  group('Die Beschriftung einer Ziellinie bleibt im Bild', () {
    /// Die Höhe einer Beschriftung in 9 Punkt — knapp elf Punkt.
    const schrifthoehe = 11.0;

    test('mitten im Bild steht sie über der Linie, wie bisher', () {
      expect(
        ziellinienBeschriftungY(60),
        lessThan(60),
        reason:
            'Der gewohnte Platz bleibt der gewohnte. Diese Änderung behebt '
            'einen Anschnitt, sie gestaltet die Beschriftung nicht um',
      );
    });

    test('dicht unter dem oberen Rand fällt sie unter die Linie', () {
      expect(
        ziellinienBeschriftungY(10),
        greaterThan(10),
        reason:
            'Über einer Linie bei y = 10 ist kein Platz für zwölf Punkt '
            'Beschriftung. Unter ihr schon — und sichtbar unten ist besser '
            'als unsichtbar oben',
      );
    });

    test('keine Beschriftung rutscht aus der Zeichenfläche', () {
      // Die ganze Höhe durch, in halben Punkten: Es gibt keine Lage einer
      // Ziellinie, bei der das `clipRect` die Beschriftung wegschneidet.
      for (var linienY = 0.0; linienY <= 148; linienY += 0.5) {
        expect(
          ziellinienBeschriftungY(linienY),
          greaterThanOrEqualTo(0),
          reason: 'bei einer Linie auf y = $linienY',
        );
      }
    });

    test('und keine liegt auf ihrer eigenen Linie', () {
      // Die App zeichnet keinen Hof hinter die Schrift (anders als das
      // Entwurfsboard). Eine Beschriftung auf der gestrichelten Linie wäre
      // deshalb unlesbar — sie steht ganz darüber oder ganz darunter.
      for (var linienY = 0.0; linienY <= 148; linienY += 0.5) {
        final y = ziellinienBeschriftungY(linienY);
        expect(
          y + schrifthoehe <= linienY || y >= linienY,
          isTrue,
          reason:
              'bei einer Linie auf y = $linienY beginnt die Beschriftung bei '
              '$y und ist elf Punkt hoch',
        );
      }
    });
  });
}
