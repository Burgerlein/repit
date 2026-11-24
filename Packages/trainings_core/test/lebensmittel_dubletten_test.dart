import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Trefferliste der Lebensmittelsuche** (#284) — welche
/// Online-Treffer neben den eigenen Lebensmitteln stehen, und in welcher
/// Reihenfolge.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## Woher die Regeln kommen
///
/// Tim auf dem Gerät, 04.11.2026: „Die Suche muss überarbeitet werden, man
/// findet direkt 8000 mal das gleiche, wenn ich nach Nutella suche." Die
/// Regeln stehen im Auftrag an den Test-Agenten, die Dublettenregel
/// zusätzlich im Entwurf `docs/screens/screens/erfassen.js` (Kommentar an
/// `SUCHE`, Commit `10d73ed`). Am selben Tag ergänzt, nach einem Vergleich
/// mit der Suche einer anderen App: Verwerfen und Umsortieren.
///
/// - **Verwerfen.** Online-Treffer **ohne Kalorien** erscheinen nicht —
///   auch nicht ausgegraut (das ersetzt die Vorgabe vom Vormittag).
///   Kalorien, die der Client aus Kilojoule umgerechnet hat, sind
///   Kalorien. Online-Treffer mit **mehr als 900 kcal je 100 g**
///   erscheinen ebenfalls nicht: Reines Fett hat rund 900, alles darüber
///   ist ein Datenfehler in Open Food Facts. **900 genau bleibt.** Eigene
///   Lebensmittel werden nicht gefiltert — Tim hat sie selbst eingetragen.
/// - **Zusammenfassen.** Gleicher normalisierter Name **und** Kalorien
///   innerhalb von 3 % → eine Zeile, **unabhängig von der Marke**.
///   Normalisieren: Kleinbuchstaben, alles außer Buchstaben und Ziffern
///   (Umlaute und ß sind Buchstaben) zu einem Leerzeichen, Ränder weg.
///   3 %: `|a − b| ≤ 0,03 · max(a, b)`. **Vertreter** ist der erste Treffer
///   der Gruppe in Reihenfolge der Antwort. Gemessen am 04.11.2026:
///   „Nutella" 25 → 12 Zeilen, „Haferflocken" 25 → 14; eine Regel, die
///   zusätzlich nach Marke trennte, ließ acht Zeilen „Haferflocken" stehen.
///   **Die Regel gilt auch zwischen eigenen und Online-Treffern:** Ein
///   Online-Treffer, der einem eigenen Lebensmittel gleicht, erscheint
///   nicht — das eigene vertritt ihn.
/// - **Umsortieren.** Nach vorn kommen die Online-Treffer, bei denen
///   **jedes** Suchwort einen **Wortanfang** in Name oder Marke trifft;
///   danach der Rest. Innerhalb beider Gruppen bleibt die Reihenfolge der
///   Antwort. Der Grund: Die Schnittstelle sortiert nach Relevanz,
///   gewichtet Marken aber kaum — ohne das stünde ein Keks, dessen Marke
///   zufällig passt, vor dem Glas, nach dem gesucht wurde.
/// - **Begrenzen.** Höchstens 25 Online-Zeilen. Gefragt werden 50
///   (`app/test/ernaehrung/off_client_test.dart`), damit nach dem
///   Zusammenfassen genug übrig ist.
///
/// ## Die Reihenfolge der Schritte
///
/// **Verwerfen → Zusammenfassen → Umsortieren → Begrenzen.** Vom
/// Koordinator so vorgegeben, damit die Fälle eindeutig sind; begründet
/// ist jeder Übergang, und je einer hat hier einen Fall, der nur mit
/// dieser Reihenfolge aufgeht:
///
/// 1. **Verwerfen vor dem Zusammenfassen.** Ein verworfener Treffer darf
///    keine Gruppe anführen. Sonst nähme ein Datenfehler mit 905 kcal die
///    richtige Fassung mit 899 kcal mit in den Abgrund — oder ein Treffer
///    ohne Kalorien wäre Vertreter einer Zeile, die man nicht buchen kann.
/// 2. **Zusammenfassen vor dem Umsortieren.** Vertreter ist der erste
///    Treffer **in der Reihenfolge der Antwort**, also der relevanteste;
///    das Umsortieren darf ihn nicht austauschen. Die Zeile wird danach
///    nach ihrem **Vertreter** einsortiert (Name und Marke, die Tim sieht),
///    nicht nach einem Mitglied, das er nicht sieht.
/// 3. **Umsortieren vor dem Begrenzen.** Sonst schnitte die Grenze genau
///    die Treffer ab, die das Umsortieren nach vorn holen soll — die
///    Schnittstelle hat sie ja weit hinten einsortiert.
/// 4. **Begrenzen zuletzt**, damit 25 Zeilen dastehen und nicht 25
///    Treffer, aus denen zwölf Zeilen werden.
///
/// ## Entscheidung des Test-Agenten: die Regeln wohnen im Kern
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
///
/// Sie sind Rechnungen über Namen, Marken und Zahlen, ohne Flutter, ohne
/// Netz, ohne Datenbank — genau das, was `trainings_core` trägt. Im Kern
/// sind sie **ohne Mocks** prüfbar (Daten rein, Indizes raus), und die
/// Importgrenze beweist mit, dass sie nichts aus der App brauchen. In
/// `app/` hinge jeder Grenzfall an einem `ProviderContainer`, einem
/// `MockClient` und einem Widget-Test. `app/test/ernaehrung/
/// off_suche_view_test.dart` prüft nur noch, **dass** die Suche die
/// Regeln anwendet.
///
/// Online-Produkte und eigene Lebensmittel sind in der App zwei Typen
/// (`OffProdukt`, `LebensmittelVorlage`). Die Regeln sehen deshalb nur, was
/// sie brauchen, als Record, und geben **Indizes** zurück, keine Objekte.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neu in `Packages/trainings_core/lib/src/lebensmittel_dubletten.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// abstract final class LebensmittelDubletten {
///   /// Der Name, so wie die Regeln ihn vergleichen: Kleinbuchstaben, jede
///   /// Folge von Zeichen, die weder Buchstabe noch Ziffer sind, wird
///   /// **ein** Leerzeichen, Ränder weg.
///   static String normalerName(String name);
///
///   /// Dasselbe Lebensmittel: gleicher [normalerName] **und** beide
///   /// Kalorien vorhanden **und** `|a − b| ≤ 0,03 · max(a, b)`.
///   static bool gleich(
///     ({String name, double? kcal}) a,
///     ({String name, double? kcal}) b,
///   );
///
///   /// Ob **jedes** Wort aus [suchtext] einen Wortanfang in [name] oder
///   /// [marke] trifft. Suchtext, Name und Marke werden wie in
///   /// [normalerName] normalisiert und an den Leerzeichen in Wörter
///   /// zerlegt; ein Suchwort trifft, wenn ein Wort aus Name oder Marke
///   /// mit ihm beginnt.
///   static bool trifftWortanfaenge(
///     String suchtext, {
///     required String name,
///     String? marke,
///   });
///
///   /// Die Online-Treffer, die in der Liste stehen — ihre Indizes in
///   /// [online], **in der Reihenfolge, in der sie angezeigt werden**,
///   /// höchstens [hoechstens] viele. Verwerfen → Zusammenfassen →
///   /// Umsortieren → Begrenzen.
///   static List<int> onlineVertreter({
///     required String suchtext,
///     required List<({String name, double? kcal})> eigene,
///     required List<({String name, String? marke, double? kcal})> online,
///     int hoechstens = 25,
///   });
/// }
/// ```
///
/// Ein `typedef` für die Records ist erlaubt, aber nicht verlangt — die
/// Tests bauen sie als Literale.
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — jede mit Begründung.
///
/// - **„Zu einem Leerzeichen" heißt: eine Folge wird ein Leerzeichen.**
///   „Prüfmilch, 3,5 %" und „Prüfmilch 3 5" sind derselbe Name. Sonst
///   trennte ein doppeltes Leerzeichen, das man auf keinem Schirm sieht,
///   zwei Zeilen, die gleich aussehen.
/// - **Verglichen wird mit dem Vertreter, nicht mit irgendeinem Mitglied.**
///   370, 380, 391 kcal: 380 geht in 370 auf, 391 liegt 5,4 % über 370 und
///   bildet eine eigene Zeile, obwohl es nur 2,8 % über 380 liegt. Die
///   Zeile zeigt die Kalorien des Vertreters; so liegt alles, wofür sie
///   steht, innerhalb von 3 % der Zahl, die Tim sieht.
/// - **Umsortiert wird nach dem Vertreter** (Schritt 2 oben).
/// - **Wortanfang heißt: nach der Normalisierung.** „Nussprüfcreme B-fit"
///   hat die Wörter `nussprüfcreme`, `b`, `fit` — „fit" trifft, „creme"
///   nicht. Ein Suchtext „B-fit" wird genauso zerlegt.
/// - **Ohne Suchwort bleibt die Reihenfolge der Antwort.**
/// - **Eigene Lebensmittel werden nie zusammengefasst** — weder
///   untereinander noch weg. Sie sind Tims eigene Daten, jedes mit eigenem
///   Schlüssel; eins zu verstecken machte es in der Suche unerreichbar.
///   Darum gibt [onlineVertreter] nur Online-Indizes zurück.
/// - **Ein eigenes Lebensmittel ohne Kalorien** (aus einer migrierten
///   Zeile) **vertritt nichts.** Es ist nicht buchbar; den buchbaren
///   Online-Treffer gleichen Namens zu verstecken, ließe nichts zum Buchen
///   übrig. Das folgt aus `gleich`, das ohne Kalorien `false` ist.
/// - **Die 25 zählen nur Online-Zeilen.** Eigene Treffer verbrauchen das
///   Kontingent nicht: Sie sind fast immer gemeint, und sie wegen
///   Online-Treffern abzuschneiden, kehrte das um.
///
/// Alle Produktnamen und Marken hier sind **erfunden**. „Nussprüfcreme"
/// steht für das Glas, nach dem Tim gesucht hat — das Muster ist die Form
/// der Dubletten, nicht das echte Produkt.
void main() {
  ({String name, double? kcal}) k(String name, [double? kcal]) =>
      (name: name, kcal: kcal);

  ({String name, String? marke, double? kcal}) o(
    String name, [
    double? kcal,
    String? marke,
  ]) => (name: name, marke: marke, kcal: kcal);

  List<int> vertreter(
    List<({String name, String? marke, double? kcal})> online, {
    String suchtext = '',
    List<({String name, double? kcal})> eigene = const [],
    int? hoechstens,
  }) => hoechstens == null
      ? LebensmittelDubletten.onlineVertreter(
          suchtext: suchtext,
          eigene: eigene,
          online: online,
        )
      : LebensmittelDubletten.onlineVertreter(
          suchtext: suchtext,
          eigene: eigene,
          online: online,
          hoechstens: hoechstens,
        );

  // ═════════════════════════════════════════════════════════════════════
  group('normalerName', () {
    test('Schreibweise und Ränder zählen nicht', () {
      for (final name in [
        'Nussprüfcreme',
        'nussprüfcreme',
        'Nussprüfcreme ',
        '  NUSSPRÜFCREME',
      ]) {
        expect(
          LebensmittelDubletten.normalerName(name),
          'nussprüfcreme',
          reason: '„$name"',
        );
      }
    });

    test('Satzzeichen werden zu einem Leerzeichen — eine Variante bleibt '
        'eine Variante', () {
      expect(
        LebensmittelDubletten.normalerName('Nussprüfcreme B-fit'),
        'nussprüfcreme b fit',
      );
      expect(
        LebensmittelDubletten.normalerName('Nussprüfcreme-Eis'),
        'nussprüfcreme eis',
      );
    });

    test('Umlaute und ß sind Buchstaben, keine Trenner', () {
      expect(LebensmittelDubletten.normalerName('Prüf-Grieß'), 'prüf grieß');
      expect(LebensmittelDubletten.normalerName('ÖLPRÜFUNG'), 'ölprüfung');
    });

    test('Ziffern bleiben, eine Folge von Trennern wird ein Leerzeichen', () {
      expect(
        LebensmittelDubletten.normalerName('  Prüfmilch,  3,5 % '),
        'prüfmilch 3 5',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('gleich', () {
    test('gleicher Name, Kalorien innerhalb von 3 % — egal in welcher '
        'Schreibweise', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme', 539),
          k('nussprüfcreme ', 546),
        ),
        isTrue,
      );
    });

    test('ein anderer Name ist ein anderes Lebensmittel — auch bei gleichen '
        'Kalorien', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme', 539),
          k('Nussprüfcreme B-fit', 539),
        ),
        isFalse,
      );
    });

    test('mehr als 3 % auseinander sind zwei Lebensmittel', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Prüfflocken', 370),
          k('Prüfflocken', 400),
        ),
        isFalse,
      );
    });

    test('genau 3 % gehören noch dazu, knapp darüber nicht', () {
      // |300 − 291| = 9 = 0,03 · 300.
      expect(
        LebensmittelDubletten.gleich(k('Prüfbrot', 300), k('Prüfbrot', 291)),
        isTrue,
      );
      // |300 − 290,9| = 9,1 > 9.
      expect(
        LebensmittelDubletten.gleich(k('Prüfbrot', 300), k('Prüfbrot', 290.9)),
        isFalse,
      );
    });

    test('3 % vom größeren Wert, nicht vom kleineren', () {
      // |100 − 103,05| = 3,05 ≤ 0,03 · 103,05 = 3,0915 — aber > 0,03 · 100.
      expect(
        LebensmittelDubletten.gleich(k('Prüfsaft', 100), k('Prüfsaft', 103.05)),
        isTrue,
      );
    });

    test('ist in beide Richtungen dasselbe', () {
      final paare = [
        (k('Prüfsaft', 100), k('Prüfsaft', 103.05)),
        (k('Prüfbrot', 300), k('Prüfbrot', 290.9)),
        (k('Prüfflocken', 370), k('prüfflocken', 372)),
        (k('Nussprüfcreme', 539), k('Nussprüfcreme B-fit', 539)),
      ];
      for (final (a, b) in paare) {
        expect(
          LebensmittelDubletten.gleich(a, b),
          LebensmittelDubletten.gleich(b, a),
          reason: '$a / $b',
        );
      }
    });

    test('0 und 0 kcal sind gleich, 0 und 1 nicht', () {
      expect(
        LebensmittelDubletten.gleich(k('Prüfwasser', 0), k('Prüfwasser', 0)),
        isTrue,
      );
      expect(
        LebensmittelDubletten.gleich(k('Prüfwasser', 0), k('Prüfwasser', 1)),
        isFalse,
      );
    });

    test('ohne Kalorien auf einer Seite: nicht gleich — die 3-%-Regel '
        'braucht zwei Zahlen', () {
      expect(
        LebensmittelDubletten.gleich(
          k('Nussprüfcreme', 539),
          k('Nussprüfcreme'),
        ),
        isFalse,
      );
      expect(
        LebensmittelDubletten.gleich(k('Nussprüfcreme'), k('Nussprüfcreme')),
        isFalse,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('trifftWortanfaenge', () {
    bool trifft(String suchtext, String name, [String? marke]) =>
        LebensmittelDubletten.trifftWortanfaenge(
          suchtext,
          name: name,
          marke: marke,
        );

    test('ein Suchwort am Anfang des Namens trifft', () {
      expect(trifft('nuss', 'Nussprüfcreme'), isTrue);
      expect(trifft('Nussprüfcreme', 'Nussprüfcreme'), isTrue);
    });

    test('mitten im Wort trifft nicht', () {
      expect(trifft('creme', 'Nussprüfcreme'), isFalse);
      expect(trifft('nuss', 'Haselnusskekse'), isFalse);
    });

    test('Schreibweise zählt nicht', () {
      expect(trifft('NUSS', 'nussprüfcreme'), isTrue);
      expect(trifft('prüf', 'PRÜFHAUS RIEGEL'), isTrue);
    });

    test('ein Wortanfang hinter einem Satzzeichen ist ein Wortanfang', () {
      expect(trifft('fit', 'Nussprüfcreme B-fit'), isTrue);
      expect(trifft('B-fit', 'Nussprüfcreme B-fit'), isTrue);
      expect(trifft('b fit', 'Nussprüfcreme B-fit'), isTrue);
    });

    test('die Marke zählt wie der Name', () {
      expect(trifft('prüfhaus', 'Nussprüfcreme', 'Prüfhaus'), isTrue);
      expect(trifft('prüfhaus', 'Nussprüfcreme'), isFalse);
    });

    test('jedes Suchwort muss treffen — in Name oder Marke, gleich wo', () {
      expect(
        trifft('Prüfhaus Nuss', 'Nussprüfcreme', 'Prüfhaus'),
        isTrue,
        reason: '„nuss" im Namen, „prüfhaus" in der Marke',
      );
      expect(
        trifft('Prüfhaus Nuss', 'Prüfhaus Müsli', 'Musterwerk'),
        isFalse,
        reason: '„nuss" trifft nirgends',
      );
      expect(
        trifft('Prüfhaus Nuss', 'Haselnusskekse', 'Prüfhaus'),
        isFalse,
        reason: '„nuss" steht nur mitten im Wort',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — verwerfen', () {
    test('ohne Kalorien wird verworfen — auch ohne buchbaren gleichen '
        'Namens', () {
      expect(vertreter([o('Prüftee'), o('Prüfbrot', 250)]), [1]);
    });

    test('mehr als 900 kcal je 100 g wird verworfen, 900 genau bleibt', () {
      expect(
        vertreter([
          o('Prüföl', 900.5),
          o('Prüfschmalz', 900),
          o('Prüfbutter', 3700),
        ]),
        [1],
        reason:
            'reines Fett hat rund 900 kcal/100 g — darüber ist es ein '
            'Datenfehler, keine Angabe',
      );
    });

    test('nur Verworfenes: nichts', () {
      expect(vertreter([o('Prüftee'), o('Prüföl', 950)]), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — zusammenfassen', () {
    test('dasselbe Glas in fünf Fassungen ist eine Zeile — vertreten vom '
        'ersten mit Kalorien', () {
      // Die Marken wechseln in der Antwort ihre Reihenfolge; die Regel
      // fragt nicht nach ihnen. Der erste Treffer hat keine Kalorien und
      // wird verworfen.
      final online = [
        o('NUSSPRÜFCREME', null, 'Prüfhaus'),
        o('Nussprüfcreme', 539, 'Prüfhaus'),
        o('nussprüfcreme', 544, 'Musterwerk'),
        o('Nussprüfcreme ', 546, 'Glasmanufaktur Prüf'),
        o('Nussprüfcreme', 539, 'Musterwerk'),
      ];

      expect(vertreter(online, suchtext: 'Nussprüfcreme'), [1]);
    });

    test('eine Variante mit eigenem Namen bleibt eine eigene Zeile', () {
      expect(
        vertreter([o('Nussprüfcreme', 539), o('Nussprüfcreme B-fit', 520)]),
        [0, 1],
      );
    });

    test('gleicher Name, mehr als 3 % auseinander: zwei Zeilen', () {
      expect(vertreter([o('Prüfflocken', 370), o('Prüfflocken', 400)]), [0, 1]);
    });

    test('die Reihenfolge der Antwort bleibt — sie ist die Relevanz', () {
      expect(
        vertreter([
          o('Prüfbrot', 250),
          o('Prüfkäse', 350),
          o('prüfbrot', 252),
          o('Prüfwurst', 300),
          o('Prüfkäse', 349),
        ]),
        [0, 1, 3],
      );
    });

    test('verglichen wird mit dem Vertreter, nicht mit irgendeinem '
        'Mitglied', () {
      // 380 liegt 2,6 % über 370 und geht auf. 391 liegt 2,8 % über 380,
      // aber 5,4 % über dem Vertreter 370 — eigene Zeile.
      expect(
        vertreter([
          o('Prüfmüsli', 370),
          o('Prüfmüsli', 380),
          o('Prüfmüsli', 391),
        ]),
        [0, 2],
      );
    });

    test('nichts rein, nichts raus', () {
      expect(vertreter(const []), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — eigene vertreten Online-Treffer', () {
    test('ein eigenes Lebensmittel vertritt den Online-Treffer gleichen '
        'Namens und gleicher Kalorien', () {
      expect(
        vertreter(
          [o('haferflocken', 370), o('Prüfdrink Hafer', 45)],
          eigene: [k('Haferflocken', 372)],
        ),
        [1],
      );
    });

    test('mehr als 3 % vom eigenen entfernt: der Online-Treffer bleibt', () {
      expect(
        vertreter([o('Haferflocken', 400)], eigene: [k('Haferflocken', 372)]),
        [0],
      );
    });

    test('eine ganze Online-Gruppe, die dem eigenen gleicht, fällt weg', () {
      expect(
        vertreter(
          [o('haferflocken', 370), o('Haferflocken', 375), o('Prüfskyr ', 64)],
          eigene: [k('Prüfskyr', 63), k('Haferflocken', 372)],
        ),
        isEmpty,
      );
    });

    test('ein eigenes mit anderem Namen vertritt nichts', () {
      expect(
        vertreter(
          [o('Haferflocken', 372)],
          eigene: [k('Haferflocken kernig', 372)],
        ),
        [0],
      );
    });

    test('ein eigenes ohne Kalorien vertritt nichts — es ist nicht '
        'buchbar', () {
      expect(vertreter([o('Prüfcreme', 500)], eigene: [k('Prüfcreme')]), [0]);
    });

    test(
      'eigene werden nicht gefiltert — auch über 900 kcal vertreten sie',
      () {
        // Ein eigenes mit 905 kcal hat Tim selbst eingetragen; es ist kein
        // Datenfehler. Es vertritt den Online-Treffer mit 899 kcal (0,7 %
        // daneben). Würde das eigene mit verworfen, bliebe der Online-Treffer
        // stehen.
        expect(
          vertreter(
            [o('Prüföl', 899), o('Prüfbrot', 250)],
            eigene: [k('Prüföl', 905)],
          ),
          [1],
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — umsortieren', () {
    test('Treffer am Wortanfang nach vorn, der Rest danach — je in der '
        'Reihenfolge der Antwort', () {
      expect(
        vertreter([
          o('Haselnusskekse', 480), //               „nuss" mitten im Wort
          o('Nussprüfcreme', 539), //                trifft
          o('Kekse mit Prüffüllung', 470), //        trifft nicht
          o('Nussriegel Knusper', 450), //           trifft
        ], suchtext: 'nuss'),
        [1, 3, 0, 2],
      );
    });

    test('jedes Suchwort muss treffen, in Name oder Marke', () {
      expect(
        vertreter([
          o('Haselnusskekse', 480, 'Musterwerk'), // keins
          o('Nussprüfcreme', 539, 'Prüfhaus'), //   beide
          o('Prüfhaus Müsli', 380, 'Musterwerk'), // nur „prüfhaus"
          o('Knusper Nussriegel', 450, 'Prüfhaus'), // beide
        ], suchtext: 'Prüfhaus Nuss'),
        [1, 3, 0, 2],
      );
    });

    test('ohne Suchwort bleibt die Reihenfolge der Antwort', () {
      expect(
        vertreter([o('Prüfbrot', 250), o('Prüfkäse', 350)], suchtext: '  '),
        [0, 1],
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('onlineVertreter — höchstens 25', () {
    test('ohne Angabe höchstens 25, die ersten in Reihenfolge der Antwort', () {
      final online = [for (var i = 0; i < 40; i++) o('Prüfprodukt $i', 100)];

      expect(vertreter(online, suchtext: 'Prüf'), [
        for (var i = 0; i < 25; i++) i,
      ]);
    });

    test('die Grenze ist einstellbar', () {
      final online = [for (var i = 0; i < 10; i++) o('Prüfprodukt $i', 100)];

      expect(vertreter(online, suchtext: 'Prüf', hoechstens: 3), [0, 1, 2]);
    });

    test('eigene verbrauchen das Kontingent nicht', () {
      expect(
        vertreter(
          [for (var i = 0; i < 30; i++) o('Prüfprodukt $i', 100)],
          suchtext: 'Prüf',
          eigene: [
            for (var i = 0; i < 5; i++) k('Eigenes Prüfgericht $i', 300),
          ],
        ),
        hasLength(25),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Jeder Fall hier geht nur mit der Reihenfolge Verwerfen →
  // Zusammenfassen → Umsortieren → Begrenzen auf (Dateikopf).
  group('onlineVertreter — die Reihenfolge der Schritte', () {
    test('verwerfen vor dem Zusammenfassen: ein Datenfehler führt keine '
        'Gruppe an', () {
      // 905 und 899 lägen innerhalb von 3 %. Erst zusammengefasst, wäre
      // 905 Vertreter — und mit ihm verschwände die richtige Fassung.
      expect(vertreter([o('Prüföl', 905), o('Prüföl', 899)]), [1]);
    });

    test('verwerfen vor dem Zusammenfassen: ein Treffer ohne Kalorien führt '
        'keine Gruppe an', () {
      expect(vertreter([o('Prüfcreme'), o('Prüfcreme', 500)]), [1]);
    });

    test('zusammenfassen vor dem Umsortieren: Vertreter bleibt der erste der '
        'Antwort, einsortiert wird nach ihm', () {
      // 0 und 1 sind eine Gruppe, Vertreter 0. Seine Marke trifft
      // „prüfhaus" nicht — die von 1 schon, aber 1 sieht Tim nicht.
      // Erst umsortiert, wäre 1 der Vertreter und stünde vorn.
      expect(
        vertreter([
          o('Prüfcreme', 500, 'Musterwerk'),
          o('Prüfcreme', 505, 'Prüfhaus'),
          o('Prüfhaus Riegel', 450),
        ], suchtext: 'prüfhaus'),
        [2, 0],
      );
    });

    test('zusammenfassen vor dem Begrenzen: 25 Zeilen, nicht 25 Treffer', () {
      // 50 Treffer, wie die Suche sie abfragt: zehn Gruppen zu je drei
      // Fassungen (0–29), dann zwanzig verschiedene (30–49). Zusammengefasst
      // sind das 30 Zeilen, gezeigt werden 25. Würde vorher abgeschnitten,
      // blieben aus den ersten 25 Treffern neun Zeilen.
      final online = [
        for (var g = 0; g < 10; g++)
          for (final kcal in [200.0, 202.0, 199.0]) o('Prüfgruppe $g', kcal),
        for (var i = 0; i < 20; i++) o('Prüfprodukt $i', 100),
      ];

      expect(vertreter(online, suchtext: 'Prüf'), [
        for (var g = 0; g < 10; g++) 3 * g,
        for (var i = 30; i < 45; i++) i,
      ]);
    });

    test('umsortieren vor dem Begrenzen: was nach vorn gehört, fällt nicht '
        'der Grenze zum Opfer', () {
      // 30 Treffer, die „nuss" nur mitten im Wort tragen, dann fünf, die
      // es am Wortanfang tragen. Erst begrenzt, kämen die fünf nie an.
      final online = [
        for (var i = 0; i < 30; i++) o('Haselnussprüfling $i', 400),
        for (var i = 0; i < 5; i++) o('Nussprüfling $i', 500),
      ];

      expect(vertreter(online, suchtext: 'nuss'), [
        for (var i = 30; i < 35; i++) i,
        for (var i = 0; i < 20; i++) i,
      ]);
    });
  });
}
