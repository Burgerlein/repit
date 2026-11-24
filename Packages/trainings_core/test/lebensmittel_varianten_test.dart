import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **Varianten in der Trefferliste der Lebensmittelsuche** (#327)
/// — Packungsgrößen und Produkte derselben Marke mit denselben Nährwerten,
/// die nach #284 noch als eigene Zeilen stehen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Sie ergänzt
/// `lebensmittel_dubletten_test.dart` (#284), die unverändert weiter gilt.
///
/// ## Anlass
///
/// Tim auf dem Gerät, nach #284: Die Suche nach einer Nusscreme zeigt
/// dasselbe Glas weiter mehrfach — als „…, mini", „… klein", „… Coppette
/// X6", als zweite Zeile gleichen Namens 3,3 % neben der ersten (knapp über
/// der 3-%-Grenze) und als Keks derselben Marke unter anderem Namen neben
/// dem Keks, der genauso viel hat. Der Koordinator hat die beiden Regeln
/// unten live gegen die Schnittstelle gemessen: Die Nusscreme-Suche geht
/// von 16 auf 9 Zeilen, Haferflocken, Skyr und Joghurt werden nicht
/// schlechter.
///
/// ## Die Regeln
///
/// **Vorgabe des Koordinators, nicht von Tim freigegeben.**
///
/// 1. **Vergleichsname.** [LebensmittelDubletten.vergleichsName] nimmt den
///    `normalerName` (unverändert, siehe #284), zerlegt ihn an den
///    Leerzeichen und streicht:
///    - **Größen- und Packungswörter**, genau diese (nach der
///      Normalisierung): `mini, klein, kleine, kleines, maxi, gross, groß,
///      große, großes, xl, xxl, familienpackung, vorteilspackung, glas,
///      becher, dose, packung, pack, portion, portionen, coppette`.
///    - **Mengenangaben:** ein Wort `^\d+(g|gr|kg|ml|cl|l)$` („450g"); ein
///      Paar aus Zahl und Einheit `g|gr|kg|ml|cl|l` („450 g"); `^x\d+$`
///      („x6") und `^\d+x$` („6x"); ein Paar „Zahl x" („6 x") bzw. „x
///      Zahl" („x 6"). **Eine Zahl ohne Einheit bleibt** — „Prüfmilch 3,5 %"
///      und „Prüfmilch 1,5 %" sind zwei Milchsorten, keine zwei Packungen.
///    - **Bleibt nichts übrig, ist der Vergleichsname der `normalerName`.**
///      Ein Produkt, das nur „Mini" heißt, heißt weiter „mini" — sonst wären
///      „Mini" und „Maxi" derselbe leere Name.
///
///    Die übrigen Wörter, wieder mit **einem** Leerzeichen verbunden. Die
///    Namensregel aus #284 (gleicher Name, Kalorien innerhalb von 3 %)
///    vergleicht ab jetzt **Vergleichsnamen** — in `gleich`, in
///    `onlineVertreter`, in `zeilen`, auch zwischen eigenen und Online-
///    Treffern.
///
/// 2. **Gleiche Marke, gleiche Nährwerte.** Ein Online-Treffer gehört auch
///    dann zu einer bestehenden Online-Gruppe, wenn — **gleich, wie er
///    heißt** —
///    - (a) seine Marke (über `normalerName`, **nicht leer**) in der
///      **Markenmenge der Gruppe** liegt: den normalisierten Marken aller
///      bisherigen Mitglieder einschließlich des Vertreters. Wer per
///      Namensregel zur Gruppe stößt, bringt seine Marke mit ein; **und**
///    - (b) Kalorien, Eiweiß, Kohlenhydrate und Fett **alle vier** auf
///      beiden Seiten vorhanden sind und je nah am **Vertreter** liegen:
///      Kalorien `|a − b| ≤ 0,05 · max(a, b)`; Eiweiß, Kohlenhydrate, Fett
///      je `|a − b| ≤ max(0,05 · max(a, b), 0,5)` in Gramm. Die 0,5 g fangen
///      kleine Werte ab: 0,1 und 0,2 g Fett sind dasselbe.
///
///    Ohne Marke oder ohne einen der vier Werte greift Regel 2 nie. **Nur
///    zwischen Online-Treffern** — eigene Lebensmittel vertreten weiterhin
///    nur über die Namensregel (mit Vergleichsname); ihr Record trägt weder
///    Marke noch Makros.
///
/// Verglichen wird immer mit dem **Vertreter**, der erste passende
/// Vertreter in Reihenfolge gewinnt. Verwerfen → Zusammenfassen →
/// Umsortieren → Begrenzen bleiben wie in #284.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Die bestehenden Signaturen aus #284 bleiben und kompilieren mit den
/// Records der alten Testdatei. Weil ein Record keine optionalen Felder
/// hat, kommt der volle Record über eine **neue Methode** herein:
///
/// ```dart
/// abstract final class LebensmittelDubletten {
///   // … normalerName, gleich, trifftWortanfaenge, onlineVertreter wie in #284
///
///   /// normalerName ohne Größen-/Packungswörter und Mengenangaben;
///   /// bleibt nichts, der normalerName.
///   static String vergleichsName(String name);
///
///   /// Wie onlineVertreter, mit Marke und Makros für Regel 2.
///   static List<int> zeilen({
///     required String suchtext,
///     required List<({String name, double? kcal})> eigene,
///     required List<({
///       String name,
///       String? marke,
///       double? kcal,
///       double? eiweissG,
///       double? kohlenhydrateG,
///       double? fettG,
///     })> online,
///     int hoechstens = 25,
///   });
/// }
/// ```
///
/// `onlineVertreter` ist danach `zeilen` mit fehlenden Makros — Regel 2
/// greift dort nie, die Namensregel mit Vergleichsname schon.
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — jede mit Begründung.
///
/// - **Die Wortliste gilt Wort für Wort, nicht als Wortteil.** „Glasur",
///   „Minis", „Dosenprüfbrot" bleiben, wie sie sind. Sonst verlöre ein
///   Name Bedeutung, die gar keine Packung beschreibt.
/// - **Ein einzelnes „x" und eine einzelne Einheit bleiben**, wenn keine
///   Zahl daneben steht („Prüfeier L", „Prüfkeks X Nuss"). Gestrichen
///   werden nur die Formen, die die Vorgabe aufzählt.
/// - **„Bisherige" Mitglieder heißt: in einem Durchgang.** Ein Treffer, der
///   **vor** dem Mitglied steht, das die Marke in die Gruppe bringt, wird
///   nicht nachträglich hineingezogen. Das folgt aus „bisherige" und hält
///   die Regel in derselben Reihenfolge wie die Namensregel aus #284.
///
/// Alle Produktnamen und Marken hier sind **erfunden**.
void main() {
  ({String name, double? kcal}) k(String name, [double? kcal]) =>
      (name: name, kcal: kcal);

  ({String name, String? marke, double? kcal}) o(
    String name, [
    double? kcal,
    String? marke,
  ]) => (name: name, marke: marke, kcal: kcal);

  ({
    String name,
    String? marke,
    double? kcal,
    double? eiweissG,
    double? kohlenhydrateG,
    double? fettG,
  })
  p(
    String name, {
    String? marke,
    double? kcal,
    double? e,
    double? kh,
    double? f,
  }) => (
    name: name,
    marke: marke,
    kcal: kcal,
    eiweissG: e,
    kohlenhydrateG: kh,
    fettG: f,
  );

  List<int> zeilen(
    List<
      ({
        String name,
        String? marke,
        double? kcal,
        double? eiweissG,
        double? kohlenhydrateG,
        double? fettG,
      })
    >
    online, {
    String suchtext = '',
    List<({String name, double? kcal})> eigene = const [],
    int? hoechstens,
  }) => hoechstens == null
      ? LebensmittelDubletten.zeilen(
          suchtext: suchtext,
          eigene: eigene,
          online: online,
        )
      : LebensmittelDubletten.zeilen(
          suchtext: suchtext,
          eigene: eigene,
          online: online,
          hoechstens: hoechstens,
        );

  List<int> vertreter(
    List<({String name, String? marke, double? kcal})> online, {
    String suchtext = '',
    List<({String name, double? kcal})> eigene = const [],
  }) => LebensmittelDubletten.onlineVertreter(
    suchtext: suchtext,
    eigene: eigene,
    online: online,
  );

  String vn(String name) => LebensmittelDubletten.vergleichsName(name);

  // ═════════════════════════════════════════════════════════════════════
  group('vergleichsName — Größen- und Packungswörter', () {
    test('jedes Wort der Liste fällt weg', () {
      for (final wort in [
        'mini',
        'klein',
        'kleine',
        'kleines',
        'maxi',
        'gross',
        'groß',
        'große',
        'großes',
        'xl',
        'xxl',
        'familienpackung',
        'vorteilspackung',
        'glas',
        'becher',
        'dose',
        'packung',
        'pack',
        'portion',
        'portionen',
        'coppette',
      ]) {
        expect(vn('Nussprüfcreme $wort'), 'nussprüfcreme', reason: '„$wort"');
      }
    });

    test('Schreibweise und Satzzeichen zählen wie im normalerName', () {
      expect(vn('Nussprüfcreme, mini'), 'nussprüfcreme');
      expect(vn('NUSSPRÜFCREME KLEIN'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme (Groß)'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme GROSS'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme - XXL'), 'nussprüfcreme');
    });

    test(
      'egal an welcher Stelle, und es bleibt ein Leerzeichen dazwischen',
      () {
        expect(vn('Mini Nussprüfcreme'), 'nussprüfcreme');
        expect(vn('Nussprüfcreme mini Kakao'), 'nussprüfcreme kakao');
        expect(vn('Prüfjoghurt Becher Vanille Glas'), 'prüfjoghurt vanille');
      },
    );

    test('mehrere Wörter auf einmal', () {
      expect(vn('Nussprüfcreme Coppette X6'), 'nussprüfcreme');
      expect(vn('Prüfflocken Vorteilspackung XL'), 'prüfflocken');
    });

    test('nur ganze Wörter — ein Wortteil bleibt', () {
      expect(vn('Nussprüfcreme Glasur'), 'nussprüfcreme glasur');
      expect(vn('Prüfriegel Minis'), 'prüfriegel minis');
      expect(vn('Dosenprüfbrot'), 'dosenprüfbrot');
      expect(vn('Kleinprüfgebäck'), 'kleinprüfgebäck');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('vergleichsName — Mengenangaben', () {
    test('Zahl und Einheit in einem Wort', () {
      expect(vn('Nussprüfcreme 450g'), 'nussprüfcreme');
      expect(vn('Prüfkekse 200gr'), 'prüfkekse');
      expect(vn('Prüfmehl 1kg'), 'prüfmehl');
      expect(vn('Prüfdrink 330ml'), 'prüfdrink');
      expect(vn('Prüfdrink 33cl'), 'prüfdrink');
      expect(vn('Prüfsaft 1L'), 'prüfsaft');
    });

    test('Zahl und Einheit als Paar', () {
      expect(vn('Nussprüfcreme 450 g'), 'nussprüfcreme');
      expect(vn('Prüfkekse 200 gr'), 'prüfkekse');
      expect(vn('Prüfmehl 1 kg'), 'prüfmehl');
      expect(vn('Prüfdrink 330 ml'), 'prüfdrink');
      expect(vn('Prüfdrink 33 cl'), 'prüfdrink');
      expect(vn('Prüfsaft, 1 l'), 'prüfsaft');
    });

    test('Stückzahlen: x6, 6x, 6 x, x 6', () {
      expect(vn('Nussprüfcreme x6'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme 6x'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme 6 x'), 'nussprüfcreme');
      expect(vn('Nussprüfcreme x 6'), 'nussprüfcreme');
    });

    test('Stückzahl und Menge zusammen', () {
      expect(vn('Prüfriegel 6 x 20 g'), 'prüfriegel');
      expect(vn('Prüfriegel x6 20g'), 'prüfriegel');
    });

    test(
      'eine Zahl ohne Einheit bleibt — Milch 3,5 % ist nicht Milch 1,5 %',
      () {
        expect(vn('Prüfmilch 3,5 %'), 'prüfmilch 3 5');
        expect(vn('Prüfmilch 1,5 %'), 'prüfmilch 1 5');
        expect(vn('Prüfmüsli 5 Korn'), 'prüfmüsli 5 korn');
        expect(vn('Prüfprodukt 12'), 'prüfprodukt 12');
      },
    );

    test('die Packung fällt weg, der Fettgehalt bleibt', () {
      expect(vn('Prüfmilch 3,5 % 1 l'), 'prüfmilch 3 5');
      expect(vn('Prüfmilch 1,5 % 1 l'), 'prüfmilch 1 5');
    });

    test('ein einzelnes x und eine einzelne Einheit bleiben', () {
      expect(vn('Prüfeier L'), 'prüfeier l');
      expect(vn('Prüfkeks X Nuss'), 'prüfkeks x nuss');
      expect(vn('Prüfvitamin B12'), 'prüfvitamin b12');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('vergleichsName — bleibt nichts, gilt der normalerName', () {
    test('ein Produkt, das nur „Mini" heißt, heißt weiter „mini"', () {
      expect(vn('Mini'), 'mini');
      expect(vn('  MAXI '), 'maxi');
      expect(vn('Mini 6x'), 'mini 6x');
      expect(vn('450 g'), '450 g');
    });

    test('ohne Größenwort bleibt es der normalerName', () {
      for (final name in [
        'Nussprüfcreme',
        'Nussprüfcreme B-fit',
        '  Prüfmilch,  3,5 % ',
        'Prüf-Grieß',
      ]) {
        expect(
          vn(name),
          LebensmittelDubletten.normalerName(name),
          reason: '„$name"',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('gleich — vergleicht Vergleichsnamen', () {
    test('Packungsgrößen desselben Glases sind gleich', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme', 539),
          k('Nussprüfcreme, mini', 539),
        ),
        isTrue,
      );
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme klein', 544),
          k('Nussprüfcreme Coppette X6', 539),
        ),
        isTrue,
      );
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme 450 g', 539),
          k('Nussprüfcreme', 541),
        ),
        isTrue,
      );
    });

    test('die 3 % gelten weiter', () {
      // 521 liegt 3,3 % unter 539.
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme', 539),
          k('Nussprüfcreme mini', 521),
        ),
        isFalse,
      );
    });

    test('eine Zahl ohne Einheit trennt weiter', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Prüfmilch 3,5 %', 64),
          k('Prüfmilch 1,5 %', 64),
        ),
        isFalse,
      );
      expect(
        LebensmittelDubletten.gleich(
          k('Prüfmilch 3,5 % 1 l', 64),
          k('Prüfmilch 3,5 %', 64),
        ),
        isTrue,
      );
    });

    test('„Mini" und „Maxi" sind nicht derselbe leere Name', () {
      expect(
        LebensmittelDubletten.gleich(k('Mini', 400), k('Maxi', 400)),
        isFalse,
      );
      expect(
        LebensmittelDubletten.gleich(k('Mini', 400), k('MINI', 400)),
        isTrue,
      );
    });

    test('ist in beide Richtungen dasselbe', () {
      final paare = [
        (k('Nussprüfcreme', 539), k('Nussprüfcreme, mini', 539)),
        (k('Nussprüfcreme', 539), k('Nussprüfcreme mini', 521)),
        (k('Prüfmilch 3,5 %', 64), k('Prüfmilch 1,5 % 1 l', 64)),
        (k('Mini', 400), k('Nussprüfcreme mini', 400)),
      ];
      for (final (a, b) in paare) {
        expect(
          LebensmittelDubletten.gleich(a, b),
          LebensmittelDubletten.gleich(b, a),
          reason: '$a / $b',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Namensregel mit Vergleichsname — Online-Treffer', () {
    test('Packungsgrößen fallen in eine Zeile — in zeilen', () {
      expect(
        zeilen([
          p('Nussprüfcreme', marke: 'Prüfhaus', kcal: 539),
          p('Nussprüfcreme, mini', marke: 'Prüfhaus', kcal: 539),
          p('Nussprüfcreme klein', marke: 'prüfhaus', kcal: 544),
          p('Nussprüfcreme Coppette X6', marke: 'Prüfhaus', kcal: 539),
          p('Nussprüfcreme 450 g', marke: 'Musterwerk', kcal: 541),
          p('Prüfbrot', kcal: 250),
        ]),
        [0, 5],
      );
    });

    test('… und genauso in onlineVertreter', () {
      expect(
        vertreter([
          o('Nussprüfcreme', 539, 'Prüfhaus'),
          o('Nussprüfcreme, mini', 539, 'Prüfhaus'),
          o('Nussprüfcreme 450 g', 541),
          o('Prüfbrot', 250),
        ]),
        [0, 3],
      );
    });

    test('Vertreter bleibt der erste der Antwort — auch wenn er „mini" '
        'heißt', () {
      expect(
        zeilen([
          p('Nussprüfcreme mini', kcal: 539),
          p('Nussprüfcreme', kcal: 539),
        ]),
        [0],
      );
    });

    test('gleicher Vergleichsname, mehr als 3 % auseinander: zwei Zeilen', () {
      expect(
        zeilen([
          p('Nussprüfcreme', kcal: 539),
          p('Nussprüfcreme mini', kcal: 521),
        ]),
        [0, 1],
      );
    });

    test('Milch mit anderem Fettgehalt bleibt eine eigene Zeile', () {
      expect(
        zeilen([
          p('Prüfmilch 3,5 % 1 l', kcal: 64),
          p('Prüfmilch 1,5 % 1 l', kcal: 64),
          p('Prüfmilch 3,5 %', kcal: 64),
        ]),
        [0, 1],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Namensregel mit Vergleichsname — eigene vertreten', () {
    test('ein eigenes vertritt den „…, mini"-Online-Treffer — in zeilen', () {
      expect(
        zeilen(
          [
            p('Nussprüfcreme, mini', marke: 'Prüfhaus', kcal: 539),
            p('Prüfbrot', kcal: 250),
          ],
          eigene: [k('Nussprüfcreme', 539)],
        ),
        [1],
      );
    });

    test('… und in onlineVertreter', () {
      expect(
        vertreter(
          [o('Nussprüfcreme, mini', 539, 'Prüfhaus'), o('Prüfbrot', 250)],
          eigene: [k('Nussprüfcreme', 539)],
        ),
        [1],
      );
    });

    test('auch umgekehrt: ein eigenes „… 450 g" vertritt das Glas ohne '
        'Mengenangabe', () {
      expect(
        zeilen(
          [p('Nussprüfcreme', kcal: 541), p('Prüfbrot', kcal: 250)],
          eigene: [k('Nussprüfcreme 450 g', 539)],
        ),
        [1],
      );
    });

    test('mehr als 3 % vom eigenen entfernt: der Online-Treffer bleibt', () {
      expect(
        zeilen(
          [p('Nussprüfcreme mini', kcal: 521)],
          eigene: [k('Nussprüfcreme', 539)],
        ),
        [0],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Grundfall für Regel 2: Vertreter 0, Kandidat 1 mit anderem Namen.
  group('Regel 2 — gleiche Marke, gleiche Nährwerte', () {
    test('anderer Name, gleiche Marke, gleiche Nährwerte: eine Zeile', () {
      expect(
        zeilen([
          p(
            'Prüfkekse Nuss',
            marke: 'Prüfhaus',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 26,
          ),
          p(
            'Knusprige Kekse mit cremigem Kern',
            marke: 'PRÜFHAUS ',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 26,
          ),
          p('Prüfbrot', kcal: 250),
        ]),
        [0, 2],
      );
    });

    test('nah heißt: Kalorien innerhalb von 5 %, Makros innerhalb von 5 % '
        'oder 0,5 g', () {
      // 530 liegt 2,8 % über 515; Eiweiß 0,3 g (< 0,5 g), Kohlenhydrate
      // 2,5 g (≤ 5 % von 62,5), Fett 1,2 g (≤ 5 % von 27,2).
      expect(
        zeilen([
          p(
            'Prüfkekse Nuss',
            marke: 'Prüfhaus',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 26,
          ),
          p(
            'Prüfkekse Knusperkern',
            marke: 'Prüfhaus',
            kcal: 530,
            e: 7.3,
            kh: 62.5,
            f: 27.2,
          ),
        ]),
        [0],
      );
    });

    test('Kalorien: genau 5 % gehören dazu, knapp darüber nicht', () {
      // |500 − 475| = 25 = 0,05 · 500.
      expect(
        zeilen([
          p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 10, kh: 50, f: 25),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 475, e: 10, kh: 50, f: 25),
        ]),
        [0],
      );
      // |500 − 474,9| = 25,1 > 25.
      expect(
        zeilen([
          p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 10, kh: 50, f: 25),
          p(
            'Prüfriegel B',
            marke: 'Prüfhaus',
            kcal: 474.9,
            e: 10,
            kh: 50,
            f: 25,
          ),
        ]),
        [0, 1],
      );
    });

    test('Kalorien: 5 % vom größeren Wert', () {
      // |500 − 526| = 26 ≤ 0,05 · 526 = 26,3 — aber > 0,05 · 500.
      expect(
        zeilen([
          p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 10, kh: 50, f: 25),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 526, e: 10, kh: 50, f: 25),
        ]),
        [0],
      );
    });

    test('der Kandidat bleibt Vertreter seiner eigenen Zeile, wenn er nicht '
        'passt — und stößt dann nichts an', () {
      expect(
        zeilen([
          p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 10, kh: 50, f: 25),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 532, e: 10, kh: 50, f: 25),
          p('Prüfriegel C', marke: 'Prüfhaus', kcal: 532, e: 10, kh: 50, f: 25),
        ]),
        [0, 1],
        reason: 'C liegt 6 % neben A, aber gleich auf mit B',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Regel 2 — greift nicht', () {
    ({
      String name,
      String? marke,
      double? kcal,
      double? eiweissG,
      double? kohlenhydrateG,
      double? fettG,
    })
    vertreterA() =>
        p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 50, f: 25);

    test('andere Marke', () {
      expect(
        zeilen([
          vertreterA(),
          p(
            'Prüfriegel B',
            marke: 'Musterwerk',
            kcal: 500,
            e: 20,
            kh: 50,
            f: 25,
          ),
        ]),
        [0, 1],
      );
    });

    test('ohne Marke — beim Kandidaten oder beim Vertreter', () {
      expect(
        zeilen([
          vertreterA(),
          p('Prüfriegel B', kcal: 500, e: 20, kh: 50, f: 25),
        ]),
        [0, 1],
      );
      expect(
        zeilen([
          p('Prüfriegel A', kcal: 500, e: 20, kh: 50, f: 25),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 50, f: 25),
        ]),
        [0, 1],
      );
    });

    test('zwei leere Marken sind keine gleiche Marke', () {
      for (final marke in ['', '  ', ' - ']) {
        expect(
          zeilen([
            p('Prüfriegel A', marke: marke, kcal: 500, e: 20, kh: 50, f: 25),
            p('Prüfriegel B', marke: marke, kcal: 500, e: 20, kh: 50, f: 25),
          ]),
          [0, 1],
          reason: 'Marke „$marke"',
        );
      }
    });

    test('ein Makro fehlt — beim Kandidaten', () {
      for (final kandidat in [
        p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, kh: 50, f: 25),
        p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 20, f: 25),
        p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 50),
      ]) {
        expect(zeilen([vertreterA(), kandidat]), [0, 1], reason: '$kandidat');
      }
    });

    test('ein Makro fehlt — beim Vertreter', () {
      for (final v in [
        p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, kh: 50, f: 25),
        p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 20, f: 25),
        p('Prüfriegel A', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 50),
      ]) {
        expect(
          zeilen([
            v,
            p(
              'Prüfriegel B',
              marke: 'Prüfhaus',
              kcal: 500,
              e: 20,
              kh: 50,
              f: 25,
            ),
          ]),
          [0, 1],
          reason: '$v',
        );
      }
    });

    test('Kalorien 6 % weg', () {
      // |500 − 532| = 32 > 0,05 · 532 = 26,6.
      expect(
        zeilen([
          vertreterA(),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 532, e: 20, kh: 50, f: 25),
        ]),
        [0, 1],
      );
    });

    test('Eiweiß: genau 5 % gehören dazu, knapp darüber nicht', () {
      // |20 − 21| = 1 ≤ 0,05 · 21 = 1,05.
      expect(
        zeilen([
          vertreterA(),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 21, kh: 50, f: 25),
        ]),
        [0],
      );
      // |20 − 21,1| = 1,1 > 0,05 · 21,1 = 1,055.
      expect(
        zeilen([
          vertreterA(),
          p(
            'Prüfriegel B',
            marke: 'Prüfhaus',
            kcal: 500,
            e: 21.1,
            kh: 50,
            f: 25,
          ),
        ]),
        [0, 1],
      );
    });

    test('Kohlenhydrate und Fett mehr als 5 % weg', () {
      // Kohlenhydrate |50 − 53| = 3 > 2,65.
      expect(
        zeilen([
          vertreterA(),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 53, f: 25),
        ]),
        [0, 1],
      );
      // Fett |25 − 27| = 2 > 1,35.
      expect(
        zeilen([
          vertreterA(),
          p('Prüfriegel B', marke: 'Prüfhaus', kcal: 500, e: 20, kh: 50, f: 27),
        ]),
        [0, 1],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Regel 2 — die 0,5-g-Untergrenze', () {
    List<int> mitFett(double fettA, double fettB) => zeilen([
      p('Prüfdrink A', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5, f: fettA),
      p('Prüfdrink B', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5, f: fettB),
    ]);

    test('0,1 und 0,2 g Fett sind dasselbe', () {
      // 5 % wären 0,01 g — die 0,5 g greifen.
      expect(mitFett(0.1, 0.2), [0]);
    });

    test('genau 0,5 g Abstand gehören dazu', () {
      expect(mitFett(1.0, 1.5), [0]);
    });

    test('0,6 g Abstand bei kleinen Werten: zwei Zeilen', () {
      expect(mitFett(0.2, 0.8), [0, 1]);
    });

    test('die Untergrenze gilt für jedes Makro', () {
      // Eiweiß 3 vs 3,6, Kohlenhydrate 5 vs 5,6: je 0,6 g > max(5 %, 0,5 g).
      expect(
        zeilen([
          p('Prüfdrink A', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5, f: 1),
          p('Prüfdrink B', marke: 'Prüfhaus', kcal: 40, e: 3.6, kh: 5, f: 1),
        ]),
        [0, 1],
      );
      expect(
        zeilen([
          p('Prüfdrink A', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5, f: 1),
          p('Prüfdrink B', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5.6, f: 1),
        ]),
        [0, 1],
      );
      // Je 0,4 g: dasselbe.
      expect(
        zeilen([
          p('Prüfdrink A', marke: 'Prüfhaus', kcal: 40, e: 3, kh: 5, f: 1),
          p(
            'Prüfdrink B',
            marke: 'Prüfhaus',
            kcal: 40,
            e: 3.4,
            kh: 5.4,
            f: 1.4,
          ),
        ]),
        [0],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Regel 2 — die Markenmenge der Gruppe', () {
    test('ein per Name hinzugekommenes Mitglied bringt seine Marke mit', () {
      // 0 ist Vertreter (Marke Prüfhaus). 1 stößt per Name dazu und bringt
      // die Marke „Nussprüfmarke" mit. 2 heißt ganz anders, trägt die
      // Marke „Nussprüfmarke" und dieselben Nährwerte wie der Vertreter —
      // die Marke liegt jetzt in der Menge der Gruppe.
      final online = [
        p('Nussprüfkekse', marke: 'Prüfhaus', kcal: 515, e: 7, kh: 60, f: 27),
        p('Nussprüfkekse', marke: 'Nussprüfmarke', kcal: 516),
        p(
          'Knusprige Kekse mit cremigem Kern',
          marke: 'Nussprüfmarke',
          kcal: 515,
          e: 7,
          kh: 60,
          f: 27,
        ),
      ];

      expect(zeilen(online), [0]);
    });

    test('ohne das Mitglied fehlt die Marke — zwei Zeilen', () {
      expect(
        zeilen([
          p('Nussprüfkekse', marke: 'Prüfhaus', kcal: 515, e: 7, kh: 60, f: 27),
          p(
            'Knusprige Kekse mit cremigem Kern',
            marke: 'Nussprüfmarke',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 27,
          ),
        ]),
        [0, 1],
      );
    });

    test('nur bisherige Mitglieder zählen — wer vorher steht, wird nicht '
        'nachträglich hineingezogen', () {
      expect(
        zeilen([
          p('Nussprüfkekse', marke: 'Prüfhaus', kcal: 515, e: 7, kh: 60, f: 27),
          p(
            'Knusprige Kekse mit cremigem Kern',
            marke: 'Nussprüfmarke',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 27,
          ),
          p('Nussprüfkekse', marke: 'Nussprüfmarke', kcal: 516),
        ]),
        [0, 1],
      );
    });

    test('die Marke eines Mitglieds wird normalisiert verglichen', () {
      expect(
        zeilen([
          p('Nussprüfkekse', marke: 'Prüfhaus', kcal: 515, e: 7, kh: 60, f: 27),
          p('Nussprüfkekse', marke: 'Nuss-Prüfmarke', kcal: 516),
          p(
            'Knusprige Kekse mit cremigem Kern',
            marke: 'nuss prüfmarke',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 27,
          ),
        ]),
        [0],
      );
    });

    test('die Nährwerte kommen vom Vertreter, nicht vom Mitglied, das die '
        'Marke gebracht hat', () {
      // 1 bringt die Marke und trägt Kekswerte; der Vertreter 0 trägt
      // andere. 2 gleicht 1, nicht 0 — eigene Zeile.
      expect(
        zeilen([
          p('Nussprüfkekse', marke: 'Prüfhaus', kcal: 515, e: 5, kh: 70, f: 22),
          p(
            'Nussprüfkekse',
            marke: 'Nussprüfmarke',
            kcal: 516,
            e: 7,
            kh: 60,
            f: 27,
          ),
          p(
            'Knusprige Kekse mit cremigem Kern',
            marke: 'Nussprüfmarke',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 27,
          ),
        ]),
        [0, 2],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Regel 2 — verglichen wird mit dem Vertreter', () {
    test('418 geht in 400 auf, 436 nicht — obwohl es 4,1 % neben 418 '
        'liegt', () {
      // 436 liegt 8,3 % über dem Vertreter 400.
      expect(
        zeilen([
          p(
            'Prüfriegel Kakao',
            marke: 'Prüfhaus',
            kcal: 400,
            e: 10,
            kh: 50,
            f: 15,
          ),
          p(
            'Prüfriegel Schoko',
            marke: 'Prüfhaus',
            kcal: 418,
            e: 10,
            kh: 50,
            f: 15,
          ),
          p(
            'Prüfriegel Nougat',
            marke: 'Prüfhaus',
            kcal: 436,
            e: 10,
            kh: 50,
            f: 15,
          ),
        ]),
        [0, 2],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Regel 2 — nur zwischen Online-Treffern', () {
    test('ein eigenes mit anderem Namen vertritt nichts, auch bei gleichen '
        'Kalorien', () {
      expect(
        zeilen(
          [
            p(
              'Knusprige Kekse mit cremigem Kern',
              marke: 'Prüfhaus',
              kcal: 515,
              e: 7,
              kh: 60,
              f: 27,
            ),
          ],
          eigene: [k('Prüfkekse Nuss', 515)],
        ),
        [0],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — Regel 2 bleibt aus', () {
    test('gleiche Marke, gleiche Kalorien, anderer Name: zwei Zeilen', () {
      expect(
        vertreter([
          o('Prüfkekse Nuss', 515, 'Prüfhaus'),
          o('Knusprige Kekse mit cremigem Kern', 515, 'Prüfhaus'),
        ]),
        [0, 1],
      );
    });

    test('zeilen ohne Makros verhält sich genauso', () {
      expect(
        zeilen([
          p('Prüfkekse Nuss', marke: 'Prüfhaus', kcal: 515),
          p('Knusprige Kekse mit cremigem Kern', marke: 'Prüfhaus', kcal: 515),
        ]),
        [0, 1],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('zeilen — die Schritte aus #284 gelten weiter', () {
    test('verwerfen vor dem Zusammenfassen: ohne Kalorien oder über 900 '
        'führt keine Gruppe an', () {
      expect(
        zeilen([
          p('Prüföl', marke: 'Prüfhaus', kcal: 905, e: 0, kh: 0, f: 100),
          p('Prüföl Flasche', marke: 'Prüfhaus', e: 0, kh: 0, f: 100),
          p('Prüfspeiseöl', marke: 'Prüfhaus', kcal: 899, e: 0, kh: 0, f: 99.9),
        ]),
        [2],
      );
    });

    test('umsortiert wird nach dem Vertreter', () {
      // 0 und 1 sind per Regel 2 eine Zeile, Vertreter 0. „nuss" trifft
      // nur den Namen von 1, den Tim nicht sieht.
      expect(
        zeilen([
          p(
            'Prüfkekse Kakao',
            marke: 'Prüfhaus',
            kcal: 515,
            e: 7,
            kh: 60,
            f: 27,
          ),
          p('Nusskekse', marke: 'Prüfhaus', kcal: 515, e: 7, kh: 60, f: 27),
          p('Nussprüfcreme', marke: 'Musterwerk', kcal: 539),
        ], suchtext: 'nuss'),
        [2, 0],
      );
    });

    test('die Grenze ist einstellbar', () {
      expect(
        zeilen(
          [for (var i = 0; i < 10; i++) p('Prüfprodukt $i', kcal: 100)],
          suchtext: 'Prüf',
          hoechstens: 3,
        ),
        [0, 1, 2],
      );
    });

    test('begrenzt werden Zeilen nach beiden Regeln, nicht Treffer', () {
      // Zehn Gruppen zu je drei Treffern (0–29): der Vertreter, eine
      // „mini"-Fassung (Namensregel) und eine Variante anderen Namens mit
      // derselben Marke und denselben Nährwerten (Regel 2). Jede Gruppe hat
      // eine eigene Marke, damit Regel 2 keine Gruppen verbindet. Dann
      // zwanzig verschiedene ohne Marke (30–49). Zusammengefasst sind das
      // 30 Zeilen, gezeigt werden 25.
      final online = [
        for (var g = 0; g < 10; g++) ...[
          p(
            'Prüfgruppe $g',
            marke: 'Prüfmarke $g',
            kcal: 200,
            e: 10,
            kh: 20,
            f: 8,
          ),
          p('Prüfgruppe $g, mini', marke: 'Prüfmarke $g', kcal: 202),
          p(
            'Prüfvariante $g',
            marke: 'Prüfmarke $g',
            kcal: 199,
            e: 10.2,
            kh: 20.4,
            f: 8.1,
          ),
        ],
        for (var i = 0; i < 20; i++) p('Prüfprodukt $i', kcal: 100),
      ];

      expect(zeilen(online, suchtext: 'Prüf'), [
        for (var g = 0; g < 10; g++) 3 * g,
        for (var i = 30; i < 45; i++) i,
      ]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('zeilen — die Suche aus dem Anlass, mit erfundenen Namen', () {
    test('Packungsgrößen, die Fassung 3,3 % daneben und der Keks unter '
        'anderem Namen fallen in ihre Zeilen', () {
      final online = [
        // Gruppe 0: das Glas.
        p(
          'Nussprüfcreme',
          marke: 'Prüfhaus',
          kcal: 539,
          e: 6.3,
          kh: 57.5,
          f: 30.9,
        ),
        p('Nussprüfcreme, mini', marke: 'Prüfhaus', kcal: 539),
        p('Nussprüfcreme klein', marke: 'prüfhaus', kcal: 544),
        p('Nussprüfcreme Coppette X6', marke: 'Prüfhaus', kcal: 539),
        // 3,3 % unter dem Vertreter: per Name nicht, per Regel 2 schon.
        p(
          'Nussprüfcreme',
          marke: 'Prüfhaus',
          kcal: 521,
          e: 6.0,
          kh: 56.0,
          f: 29.5,
        ),
        // Gruppe 5: der Keks — Eiweiß 0,9 g neben dem Glas, eigene Zeile.
        p(
          'Nussprüfkekse',
          marke: 'Prüfhaus',
          kcal: 515,
          e: 7.2,
          kh: 62.0,
          f: 26.0,
        ),
        // Per Name zum Keks; bringt die Marke „Nussprüfcreme" mit.
        p('Nussprüfkekse', marke: 'Nussprüfcreme', kcal: 516),
        // Per Regel 2 zum Keks, über die mitgebrachte Marke.
        p(
          'Knusprige Kekse mit cremigem Kern',
          marke: 'Nussprüfcreme',
          kcal: 515,
          e: 7.2,
          kh: 62.0,
          f: 26.0,
        ),
        p('Prüfmüsli Nuss', marke: 'Musterwerk', kcal: 420),
      ];

      expect(zeilen(online), [0, 5, 8]);
    });
  });
}
